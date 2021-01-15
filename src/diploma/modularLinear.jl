using JuMP,Gurobi

include("hardLinear.jl")
include("simplifiedLinears.jl")

@enum MachineModelType ORDER_FIRST ASSIGNMENT_ONLY
@enum CarModelType TIME_SLOTS SEPARATE_EVENTS GENERAL_EVENTS DELIVER_ONLY NO_CARS

struct ModelWrapper{machineType,carType}
	inner
end

function buildModel(problem,machineModelType=ORDER_FIRST,carModelType=TIME_SLOTS)
	jobCount=problem.jobCount
	itemsNeeded=problem.itemsNeeded

	itemsCount=itemsNeeded |> Iterators.flatten |> maximum
	allItemsCount=sum(length.(itemsNeeded))
	T=ceil(Int,allItemsCount/carCount)
	M=problem.carTravelTime+sum(problem.jobLengths)

	model=Model(Gurobi.Optimizer)
	@variable(model,startTime[1:jobCount]≥0)
	@variable(model,res)

	if machineModelType≡ORDER_FIRST
		machinesModel(model,problem,M)
	elseif machineModelType≡ASSIGNMENT_ONLY
		simpleMachines(model,problem.jobLengths,problem.machineCount)
	else
		@assert false
	end
	if carModelType≡TIME_SLOTS
		carsModel1(model,problem,T,M)
	elseif carModelType≡SEPARATE_EVENTS
		carsModel2(model,problem,T,M)
	elseif carModelType≡GENERAL_EVENTS
		carsModel3(model,problem,T,M)
	elseif carModelType≡DELIVER_ONLY
		moderateCars(model,problem.itemsNeeded,problem.carCount,problem.carTravelTime)
	else
		@assert carModelType≡NO_CARS
	end

	@constraint(model,[i=1:jobCount],res≥startTime[i])
	@objective(model,Min,res)

	ModelWrapper{machineModelType,carModelType}(model)
end

function runModel(model,timeout=300)
	timeout≠0 && set_time_limit_sec(model.inner,timeout)
	optimize!(model.inner)
	(has_values(model.inner) ? objective_value(model.inner) : missing,objective_bound(model.inner))
end