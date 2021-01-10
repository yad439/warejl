using JuMP,Gurobi

include("hardLinear.jl")

@enum MachineModelType ORDER_FIRST
@enum CarModelType TIME_SLOTS SEPARATE_EVENTS GENERAL_EVENTS

struct ModelWrapper{machineType,carType}
	inner
end

function buildModel(jobLengths,machineCount,itemsNeeded,carCount,carTravelTime,machineModelType=ORDER_FIRST,carModelType=TIME_SLOTS)
	jobCount=length(jobLengths)
	@assert length(itemsNeeded)==jobCount

	model=Model(Gurobi.Optimizer)
	@variable(model,startTime[1:jobCount]≥0)

	machinesModel(model,jobLengths,machineCount)
	if carModelType≡TIME_SLOTS
		carsModel1(model,itemsNeeded,carCount,carTravelTime)
	elseif carModelType≡SEPARATE_EVENTS
		carsModel2(model,itemsNeeded,carCount,carTravelTime)
	elseif carModelType≡GENERAL_EVENTS
		carsModel2(model,itemsNeeded,carCount,carTravelTime)
	else
		@assert false
	end

	@variable(model,res)
	@constraint(model,[i=1:jobCount],res≥startTime[i])
	@objective(model,Min,res)

	ModelWrapper{machineModelType,carModelType}(model)
end

function runModel(model,timeout=300)
	timeout!=0 && set_time_limit_sec(model.inner,timeout)
	optimize!(model.inner)
	(has_values(model.inner) ? objective_value(model.inner) : missing,objective_bound(model.inner))
end