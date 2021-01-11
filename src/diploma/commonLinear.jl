using JuMP,Gurobi

include("hardLinear.jl")
include("simplifiedLinears.jl")

@enum MachineModelType ORDER_FIRST ASSIGNMENT_ONLY
@enum CarModelType TIME_SLOTS SEPARATE_EVENTS GENERAL_EVENTS DELIVER_ONLY NO_CARS

struct ModelWrapper{machineType,carType}
	inner
end

function buildModel(jobLengths,machineCount,itemsNeeded,carCount,carTravelTime,bufferSize,machineModelType=ORDER_FIRST,carModelType=TIME_SLOTS)
	jobCount=length(jobLengths)
	@assert length(itemsNeeded)==jobCount

	model=Model(Gurobi.Optimizer)
	@variable(model,startTime[1:jobCount]≥0)
	@variable(model,res)

	if machineModelType≡ORDER_FIRST
		machinesModel(model,jobLengths,machineCount)
	elseif machineModelType≡ASSIGNMENT_ONLY
		simpleMachines(model,jobLengths,machineCount)
	else
		@assert false
	end
	if carModelType≡TIME_SLOTS
		carsModel1(model,itemsNeeded,carCount,carTravelTime,bufferSize)
	elseif carModelType≡SEPARATE_EVENTS
		carsModel2(model,itemsNeeded,carCount,carTravelTime,bufferSize)
	elseif carModelType≡GENERAL_EVENTS
		carsModel2(model,itemsNeeded,carCount,carTravelTime,bufferSize)
	elseif carModelType≡DELIVER_ONLY
		moderateCars(model,itemsNeeded,carCount,carTravelTime)
	else
		@assert carModelType≡NO_CARS
	end

	@constraint(model,[i=1:jobCount],res≥startTime[i])
	@objective(model,Min,res)

	ModelWrapper{machineModelType,carModelType}(model)
end

function runModel(model,timeout=300)
	timeout!=0 && set_time_limit_sec(model.inner,timeout)
	optimize!(model.inner)
	(has_values(model.inner) ? objective_value(model.inner) : missing,objective_bound(model.inner))
end