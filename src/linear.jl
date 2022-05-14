using JuMP

include("hardLinear.jl")
include("simplifiedLinears.jl")

@enum MachineModelType ORDER_FIRST ORDER_FIRST_STRICT ASSIGNMENT_ONLY ASSIGNMENT_ONLY_SHARED
@enum CarModelType TIME_SLOTS SEPARATE_EVENTS SEPARATE_EVENTS_QUAD GENERAL_EVENTS SHARED_EVENTS SHARED_EVENTS_QUAD DELIVER_ONLY BUFFER_ONLY NO_CARS

struct ModelWrapper
    machineType::MachineModelType
    carType::CarModelType
    inner::Model
    travelTime::Int
end

function buildModel(problem::Problem, machineModelType, carModelType, T=0, M=0; optimizer=nothing)
    jobCount = problem.jobCount
    itemsNeeded = problem.itemsNeeded

    # itemsCount = itemsNeeded |> Iterators.flatten |> maximum
    allItemsCount = sum(length.(itemsNeeded))
    TR = T == 0 ? ceil(Int, allItemsCount / problem.robotCount) : T
    TE = T == 0 ? max(TR, jobCount, ceil(Int, allItemsCount / problem.bufferSize)) : T
    M = M == 0 ? problem.travelTime + sum(problem.jobLengths) : M

    model = optimizer ≢ nothing ? Model(optimizer) : Model()
    @variable(model, res)

    if machineModelType ≢ ASSIGNMENT_ONLY_SHARED && machineModelType ≢ ASSIGNMENT_ONLY
        @variable(model, startTime[1:jobCount] ≥ 0)
        @constraint(model, [i = 1:jobCount], res ≥ startTime[i] + problem.jobLengths[i])
    end

    @objective(model, Min, res)

    if machineModelType ≡ ORDER_FIRST
        # machinesModel(model, problem, M)
        @assert false
    elseif machineModelType ≡ ORDER_FIRST_STRICT
        machinesModel2(model, problem, M)
    elseif machineModelType ≡ ASSIGNMENT_ONLY
        # simpleMachines(model, problem.jobLengths, problem.machineCount)
        @assert false
    elseif machineModelType ≡ ASSIGNMENT_ONLY_SHARED
        sharedTimesMachines(model, problem.jobLengths, problem.machineCount)
    else
        @assert false
    end
    if carModelType ≡ TIME_SLOTS
        # carsModel1(model, problem, TR, M)
        @assert false
    elseif carModelType ≡ SEPARATE_EVENTS
        # carsModel2(model, problem, TE, M)
        @assert false
    elseif carModelType ≡ SEPARATE_EVENTS_QUAD
        # carsModel2Q(model, problem, TE, M)
        @assert false
    elseif carModelType ≡ GENERAL_EVENTS
        # carsModel3(model, problem, TE, M)
        @assert false
    elseif carModelType ≡ SHARED_EVENTS
        carsModel4(model, problem, TE, M)
    elseif carModelType ≡ SHARED_EVENTS_QUAD
        # carsModel4Q(model, problem, TE, M)
        @assert false
    elseif carModelType ≡ DELIVER_ONLY
        # moderateCars(model, problem.itemsNeeded, problem.carCount, problem.carTravelTime)
        @assert false
    elseif carModelType ≡ BUFFER_ONLY
        bufferOnlyCars(model, problem, M)
    else
        @assert carModelType ≡ NO_CARS
    end

    ModelWrapper(machineModelType, carModelType, model, problem.travelTime)
end

function runModel(model, timeout=0; attributes=[])
    timeout ≠ 0 && set_time_limit_sec(model.inner, timeout)
    for attr ∈ attributes
        set_optimizer_attribute(model.inner, attr[1], attr[2])
    end
    optimize!(model.inner)
    (has_values(model.inner) ? objective_value(model.inner) + model.travelTime : missing, objective_bound(model.inner) + model.travelTime)
end

function setStartValues(model, schedule::Solution, problem::Problem)
    set_start_value.(model.inner[:startTime], schedule.startTimes .- problem.travelTime)
    set_start_value(model.inner[:res], maximum(schedule.startTimes .+ problem.jobLengths) - problem.travelTime)
    if model.machineType ≡ ORDER_FIRST || model.machineType ≡ ORDER_FIRST_STRICT
        toMachinesModel(model.inner, schedule)
    else
        @assert false
    end
    if model.carType ≡ SEPARATE_EVENTS
        # toCarsModel2(model.inner, schedule, problem)
        @assert false
    elseif model.carType ≡ SHARED_EVENTS
        toCarsModel4(model.inner, schedule, problem)
    elseif model.carType ≡ SHARED_EVENTS_QUAD
        # toCarsModel4Q(model.inner, schedule, problem)
        @assert false
    else
        @assert false
    end
    nothing
end

function writeMIPStart(model, filename)
    open(filename, "w") do file
        for variable ∈ all_variables(model)
            println(file, name(variable), ' ', start_value(variable))
        end
    end
    nothing
end