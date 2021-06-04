include("utility.jl")

using ProgressMeter
using ValueHistories

struct LocalSearchSettings{T}
	iterator::T
	acceptFirst::Bool
end

function modularLocalSearch(settings, scoreFunction, startTimeTable, showProgress=true)
	progress = ProgressUnknown("Local search:")

	timeTable = startTimeTable
	score = scoreFunction(timeTable)

	history = QHistory(typeof(score))
	push!(history, score)
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
		push!(history, score)
		showProgress && ProgressMeter.next!(progress, showvalues=(("Min score", score),))
	end
	(score = score, solution = timeTable, history = history)
end