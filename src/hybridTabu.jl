include("tabu.jl")
include("annealing.jl")

struct HybridTabuSettings1
	tabuSettings::TabuSearchSettings
	annealingSettings::AnnealingSettings
	maxRestarts::Int
end

function hybridTabuSearch(settings, scoreFunction, startTimeTable, showProgress = true)
	tabuSettings = settings.tabuSettings
	progress = ProgressUnknown("Local tabu search:")

	timeTable = startTimeTable
	tabu = OrderedSet{Tuple{Int,Int}}()
	minval = scoreFunction(timeTable)
	minsol = copy(timeTable)
	restartCouner = 0
	innerCounter = 0

	history = QHistory(typeof(minval))
	push!(history, minval)
	while restartCouner ≤ settings.maxRestarts
		newTimeTableChange = modularTabuImprove(timeTable, tabu, tabuSettings, scoreFunction, tabuCanChange3)
		restoreChange = change!(timeTable, newTimeTableChange)
		tabuAdd5!(tabu, newTimeTableChange, restoreChange, timeTable)
		score = scoreFunction(timeTable)
		push!(history, score)
		if score < minval
			innerCounter = 0
			restartCouner = 0
			minval = score
			copy!(minsol, timeTable)
		else
			innerCounter += 1
			if innerCounter > tabuSettings.searchTries
				timeTable = modularAnnealing(settings.annealingSettings, scoreFunction, timeTable, false).solution
				empty!(tabu)
				innerCounter = 0
				restartCouner += 1
			end
		end
		while length(tabu) > tabuSettings.tabuSize
			delete!(tabu.dict, first(tabu))
		end
		showProgress && ProgressMeter.next!(progress, showvalues = (("Score", score), ("Min score", minval)))
	end
	ProgressMeter.finish!(progress)
	(score = minval, solution = minsol, history = history)
end