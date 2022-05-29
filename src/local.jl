include("encodings.jl")

struct LocalSearchSettings{T}
    iterator::T
    acceptFirst::Bool
end

struct LocalSearchSettings2
    iterationCount::Int
    acceptFirst::Bool
end

function modularLocalSearch(settings::LocalSearchSettings, scoreFunction, startTimeTable)
    timeTable = startTimeTable
    score = scoreFunction(timeTable)

    while true
        minScore = score
        minChange = (0, 0, 0)
        for change ∈ settings.iterator
            restore = change!(timeTable, change)
            val = scoreFunction(timeTable)
            if val < minScore
                minScore = val
                minChange = change
                settings.acceptFirst && break
            end
            change!(timeTable, restore)
        end
        minScore == score && break
        change!(timeTable, minChange)
        score = minScore
    end
    (score=score, solution=timeTable)
end

function modularLocalSearch(settings::LocalSearchSettings2, iterator, scoreFunction, startTimeTable)
    timeTable = startTimeTable
    score = scoreFunction(timeTable)

    for _ = 1:settings.iterationCount
        minScore = typemax(Int)
        minChange = (0, 0, 0)
        for change ∈ iterator()
            restore = change!(timeTable, change)
            val = scoreFunction(timeTable)
            if val < minScore
                minScore = val
                minChange = change
                settings.acceptFirst && break
            end
            change!(timeTable, restore)
        end
        change!(timeTable, minChange)
        score = minScore
    end
    (score=score, solution=timeTable)
end