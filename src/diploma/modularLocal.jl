include("utility.jl")

function modularLocalSearch(settings,scoreFunction,startTimeTable)
	timeTable=startTimeTable
	score=scoreFunction(timeTable)

	while true
		minScore=score
		minChange=(0,0,0)
		for change ∈ changeIterator(timeTable)
			restore=change!(timeTable,change)
			val=scoreFunction(timeTable)
			if val<minScore
				minScore=val
				minChange=change
			end
			change!(timeTable,restore)
		end
		minScore==score && break
		change!(timeTable,minChange)
		score=minScore
	end
	score,timeTable
end