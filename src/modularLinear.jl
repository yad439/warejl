using JuMP,Gurobi

include("hardLinear.jl")
include("simplifiedLinears.jl")

@enum MachineModelType ORDER_FIRST ASSIGNMENT_ONLY
@enum CarModelType TIME_SLOTS SEPARATE_EVENTS SEPARATE_EVENTS_QUAD GENERAL_EVENTS DELIVER_ONLY NO_CARS

struct ModelWrapper
	machineType
	carType
	inner
end

function buildModel(problem,machineModelType,carModelType,T=0,M=0)
	jobCount=problem.jobCount
	itemsNeeded=problem.itemsNeeded

	itemsCount=itemsNeeded |> Iterators.flatten |> maximum
	allItemsCount=sum(length.(itemsNeeded))
	TR=T==0 ? ceil(Int,allItemsCount/carCount) : T
	TE=T==0 ? max(TR,jobCount,ceil(Int,allItemsCount/problem.bufferSize)) : T
	M=M==0 ? problem.carTravelTime+sum(problem.jobLengths) : M

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
		carsModel1(model,problem,TR,M)
	elseif carModelType≡SEPARATE_EVENTS
		carsModel2(model,problem,TE,M)
	elseif carModelType≡SEPARATE_EVENTS_QUAD
		carsModel2Q(model,problem,TE,M)
	elseif carModelType≡GENERAL_EVENTS
		carsModel3(model,problem,TE,M)
	elseif carModelType≡DELIVER_ONLY
		moderateCars(model,problem.itemsNeeded,problem.carCount,problem.carTravelTime)
	else
		@assert carModelType≡NO_CARS
	end

	@constraint(model,[i=1:jobCount],res≥startTime[i]+problem.jobLengths[i])
	@objective(model,Min,res)

	ModelWrapper(machineModelType,carModelType,model)
end

function runModel(model,timeout=0)
	timeout≠0 && set_time_limit_sec(model.inner,timeout)
	optimize!(model.inner)
	(has_values(model.inner) ? objective_value(model.inner) : missing,objective_bound(model.inner))
end