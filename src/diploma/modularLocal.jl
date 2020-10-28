include("utility.jl")

struct LocalSearchSettings{T}
	iterator::T
	acceptFirst::Bool
end

function modularLocalSearch(settings,scoreFunction,startTimeTable)
	timeTable=startTimeTable
	score=scoreFunction(timeTable)

	while true
		minScore=score
		minChange=(0,0,0)
		for change ∈ settings.iterator
			restore=change!(timeTable,change)
			val=scoreFunction(timeTable)
			if val<minScore
				minScore=val
				minChange=change
				settings.acceptFirst && break
			end
			change!(timeTable,restore)
		end
		minScore==score && break
		change!(timeTable,minChange)
		score=minScore
	end
	score,timeTable
end