include("encodings.jl")
include("structures.jl")
include("utility.jl")

struct Problem
    jobCount::Int
    machineCount::Int
    robotCount::Int
    travelTime::Int
    itemCount::Int
    bufferSize::Int
    jobLengths::Vector{Int}
    itemsNeeded::Vector{BitSet}
end

#=struct Schedule
    assignment::Vector{Int}
    times::Vector{Int}
    carTasks::Vector{@NamedTuple{time::Int, item::Int, isAdd::Bool}}
end=#

const BufferEvent = @NamedTuple begin
    time::Int
    added::BitSet
    removed::BitSet
end
BufferEvent(time::Int, added::BitSet, removed::BitSet)::BufferEvent = (; time, added, removed)

struct Solution
    startTimes::Vector{Int}
    assignments::Vector{Int}
    bufferEvents::Vector{BufferEvent}
end

# function countCars(history, carTravelTime)
#     carChangeHistory = history |> fmap(event -> (event.time, length(event.items)))
#     endings = carChangeHistory |> fmap(it -> (it[1] + carTravelTime, -it[2]))
#     allEvents = vcat(carChangeHistory, endings)
#     sort!(allEvents, by=first)
#     fixedHistory = [(zero(carChangeHistory[1][1]), 0)]
#     curTime = fixedHistory[1][1]
#     for event ∈ allEvents
#         if event[1] == curTime
#             fixedHistory[end] = (curTime, fixedHistory[end][2] + event[2])
#         else
#             curTime = event[1]
#             push!(fixedHistory, event)
#         end
#     end
#     carsInUse = 0
#     res = [(0, 0)]
#     for event ∈ fixedHistory
#         carsInUse += event[2]
#         push!(res, (event[1], carsInUse))
#     end
#     res
# end

scheduleToEncoding(::Type{PermutationEncoding}, schedule) = schedule.times |> sortperm |> PermutationEncoding

function isValid(problem::Problem)::Bool
    res = length(problem.jobLengths) == problem.jobCount && length(problem.itemsNeeded) == problem.jobCount
    res &= Set(Iterators.flatten(problem.itemsNeeded)) == Set(1:problem.itemCount)
    for items ∈ problem.itemsNeeded
        res &= length(items) ≤ problem.bufferSize
    end
    res
end

function isValid(solution::Solution, problem::Problem)::Bool
    for event ∈ solution.bufferEvents
        sum(length(e.added) + length(e.removed) for e ∈ solution.bufferEvents if event.time - problem.travelTime < e.time ≤ event.time) ≤ problem.robotCount || return false
    end
    all(>(0), diff([e.time for e in solution.bufferEvents])) || return false
    bufferStates = [(0, Set{Int}())]
    for event ∈ soluition.bufferEvents
        state = bufferStates[end][2]
        event.removed ⊆ state || return false
        isdisjoint(event.added, state) || return false
        newState = setdiff(state, event.removed)
        union!(newState, event.added)
        push!(bufferStates, (event.time, newState))
    end
    all(state -> length(state[2]) ≤ problem.bufferSize, bufferStates) || return false
    order = sortperm(solution.times)
    sums = zeros(Int, problem.machineCount)
    for job ∈ order
        sums[solution.assignment[job]] ≤ solution.times[job] || return false
        stateInd = searchsortedlast(bufferStates, solution.times[job]; by=first)
        problem.itemsNeeded[job] ⊆ bufferStates[stateInd][2] || return false
        sums[solution.assignment[job]] = solution.times[job] + problem.jobLengths[job]
    end
    true
end