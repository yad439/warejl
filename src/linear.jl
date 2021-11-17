using JuMP, Gurobi

include("hardLinear.jl")
include("simplifiedLinears.jl")

@enum MachineModelType ORDER_FIRST ORDER_FIRST_STRICT ASSIGNMENT_ONLY ASSIGNMENT_ONLY_SHARED
@enum CarModelType TIME_SLOTS SEPARATE_EVENTS SEPARATE_EVENTS_QUAD GENERAL_EVENTS SHARED_EVENTS SHARED_EVENTS_QUAD DELIVER_ONLY BUFFER_ONLY NO_CARS

struct ModelWrapper
	machineType
	carType
	inner
end

function buildModel(problem, machineModelType, carModelType, T = 0, M = 0; optimizer = Gurobi.Optimizer)
	jobCount = problem.jobCount
	itemsNeeded = problem.itemsNeeded

	itemsCount = itemsNeeded |> Iterators.flatten |> maximum
	allItemsCount = sum(length.(itemsNeeded))
	TR = T == 0 ? ceil(Int, allItemsCount / carCount) : T
	TE = T == 0 ? max(TR, jobCount, ceil(Int, allItemsCount / problem.bufferSize)) : T
	M = M == 0 ? problem.carTravelTime + sum(problem.jobLengths) : M

	model = optimizer ≢ nothing ? Model(optimizer) : Model()
	@variable(model, startTime[1:jobCount] ≥ 0)
	@variable(model, res)

	if machineModelType ≡ ORDER_FIRST
		machinesModel(model, problem, M)
	elseif machineModelType ≡ ORDER_FIRST_STRICT
		machinesModel2(model, problem, M)
	elseif machineModelType ≡ ASSIGNMENT_ONLY
		simpleMachines(model, problem.jobLengths, problem.machineCount)
	elseif machineModelType ≡ ASSIGNMENT_ONLY_SHARED
		sharedTimesMachines(model, problem.jobLengths, problem.machineCount)
	else
		@assert false
	end
	if carModelType ≡ TIME_SLOTS
		carsModel1(model, problem, TR, M)
	elseif carModelType ≡ SEPARATE_EVENTS
		carsModel2(model, problem, TE, M)
	elseif carModelType ≡ SEPARATE_EVENTS_QUAD
		carsModel2Q(model, problem, TE, M)
	elseif carModelType ≡ GENERAL_EVENTS
		carsModel3(model, problem, TE, M)
	elseif carModelType ≡ SHARED_EVENTS
		carsModel4(model, problem, TE, M)
	elseif carModelType ≡ SHARED_EVENTS_QUAD
		carsModel4Q(model, problem, TE, M)
	elseif carModelType ≡ DELIVER_ONLY
		moderateCars(model, problem.itemsNeeded, problem.carCount, problem.carTravelTime)
	elseif carModelType ≡ BUFFER_ONLY
		bufferOnlyCars(model, problem, M)
	else
		@assert carModelType ≡ NO_CARS
	end

	@constraint(model, [i = 1:jobCount], res ≥ startTime[i] + problem.jobLengths[i])
	@objective(model, Min, res)

	ModelWrapper(machineModelType, carModelType, model)
end

function runModel(model, timeout = 0; attributes = [])
	timeout ≠ 0 && set_time_limit_sec(model.inner, timeout)
	for attr ∈ attributes
		set_optimizer_attribute(model.inner, attr[1], attr[2])
	end
	optimize!(model.inner)
	(has_values(model.inner) ? objective_value(model.inner) : missing, objective_bound(model.inner))
end

function setStartValues(model, schedule, problem)
	set_start_value.(model.inner[:startTime], schedule.times)
	set_start_value(model.inner[:res], maximum(schedule.times .+ problem.jobLengths))
	if model.machineType ≡ ORDER_FIRST || model.machineType ≡ ORDER_FIRST_STRICT
		toMachinesModel(model.inner, schedule)
	else
		@assert false
	end
	if model.carType ≡ SEPARATE_EVENTS
		toCarsModel2(model.inner, schedule, problem)
	elseif model.carType ≡ SHARED_EVENTS
		toCarsModel4(model.inner, schedule, problem)
	elseif model.carType ≡ SHARED_EVENTS_QUAD
		toCarsModel4Q(model.inner, schedule, problem)
	else
		@assert false
	end
end

function writeMIPStart(model, filename)
	open(filename, "w") do file
		for variable ∈ all_variables(model)
			println(file, name(variable), ' ', start_value(variable))
		end
	end
end