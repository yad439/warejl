include("tabu.jl")
include("annealing.jl")

struct HybridTabuSettings1
	tabuSettings::TabuSearchSettings
	annealingSettings::AnnealingSettings
	maxRestarts::Int
end

struct HybridTabuSettings2
	searchTries::Int
	tabuSize::Int
	neighbourhoodSize1::Int
	neighbourhoodSize2::Int
	anotherIterations::Int
	maxRestarts::Int
end

function hybridTabuSearch(settings::HybridTabuSettings1, scoreFunction, startTimeTable, showProgress = true; threaded = Val{true}())
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
	foundByAnnealing = false
	while restartCouner ≤ settings.maxRestarts
		newTimeTableChange = modularTabuImprove(timeTable, tabu, tabuSettings, scoreFunction, tabuCanChange3, threaded)
		restoreChange = change!(timeTable, newTimeTableChange)
		tabuAdd5!(tabu, newTimeTableChange, restoreChange, timeTable)
		score = scoreFunction(timeTable)
		push!(history, score)
		if score < minval
			innerCounter = 0
			restartCouner = 0
			minval = score
			copy!(minsol, timeTable)
			foundByAnnealing = false
		else
			innerCounter += 1
			if innerCounter > tabuSettings.searchTries
				annRes = randomAnnealing(settings.annealingSettings, scoreFunction, timeTable, false)
				timeTable = annRes.endSolution
				if annRes.bestScore < minval
					minval = annRes.bestScore
					minsol = annRes.bestSolution
					foundByAnnealing = true
				end
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
	(score = minval, solution = minsol, history, foundByAnnealing)
end

function hybridTabuSearch(settings::HybridTabuSettings2, scoreFunction, startTimeTable, showProgress = true; threaded = Val{true}())
	progress = ProgressUnknown("Local tabu search:")

	timeTable = startTimeTable
	tabu = OrderedSet{Tuple{Int,Int}}()
	minval = scoreFunction(timeTable)
	minsol = copy(timeTable)
	restartCouner = 0
	innerCounter = 0
	currentSize = settings.neighbourhoodSize1
	normalNeighborhood = true

	history = QHistory(typeof(minval))
	push!(history, minval)
	while restartCouner ≤ settings.maxRestarts
		newTimeTableChange = modularTabuImprove(timeTable, tabu, currentSize, scoreFunction, tabuCanChange3, threaded)
		restoreChange = change!(timeTable, newTimeTableChange)
		tabuAdd5!(tabu, newTimeTableChange, restoreChange, timeTable)
		score = scoreFunction(timeTable)
		push!(history, score)
		if score < minval
			innerCounter = 0
			restartCouner = 0
			normalNeighborhood = true
			minval = score
			copy!(minsol, timeTable)
		else
			innerCounter += 1
			if normalNeighborhood
				if innerCounter > settings.searchTries
					normalNeighborhood = false
					innerCounter = 0
					currentSize = settings.neighbourhoodSize2
				end
			else
				if innerCounter > settings.anotherIterations
					normalNeighborhood = true
					innerCounter = 0
					currentSize = settings.neighbourhoodSize1
					restartCouner += 1
				end
			end
		end
		while length(tabu) > settings.tabuSize
			delete!(tabu.dict, first(tabu))
		end
		showProgress && ProgressMeter.next!(progress, showvalues = (("Score", score), ("Min score", minval)))
	end
	ProgressMeter.finish!(progress)
	(score = minval, solution = minsol, history)
end

function randomAnnealing(settings::AnnealingSettings, scoreFunction, startTimeTable, showProgress = true)
	progress = ProgressUnknown("Annealing:")

	timeTable = startTimeTable
	minval = scoreFunction(timeTable)
	minsol = copy(timeTable)
	counter = 0
	threshold = settings.startTheshold

	prevScore = minval
	# history = QHistory(typeof(minval))
	# push!(history, minval)
	scounter = 1
	while counter < settings.searchTries
		newChange, restoreChange = randomChange!(timeTable, change -> true)
		score = scoreFunction(timeTable)
		if settings.applyChange(prevScore, score, threshold)
			prevScore = score
		else
			change!(timeTable, restoreChange)
		end
		if score < minval
			if settings.isDynamic
				counter = 0
			else
				counter += 1
			end
			minval = score
			copy!(minsol, timeTable)
		else
			counter += 1
		end
		if scounter ≥ settings.sameTemperatureTries
			threshold = settings.decreasingFunction(threshold)
			scounter = 1
		else
			scounter += 1
		end
		# push!(history, prevScore)
		showProgress && ProgressMeter.next!(progress, showvalues = (("Min score", minval),))
	end
	ProgressMeter.finish!(progress)
	(bestScore = minval, endSolution = timeTable, bestSolution = minsol)
end

function modularTabuImprove(timeTable, tabu, neighborhoodSize::Int, scoreFunction, canChange, ::Val{true} = Val{true}())
	nthreads = Threads.nthreads()
	minval = fill(typemax(Int), nthreads)
	toApply = fill((defaultChange(timeTable), 0, 0), nthreads)
	tables = [deepcopy(timeTable) for _ = 1:nthreads]
	Threads.@threads for _ = 1:neighborhoodSize
		thread = Threads.threadid()
		newChange, restoreChange = randomChange!(tables[thread], change -> canChange(tables[thread], change, tabu))
		score = scoreFunction(tables[thread])
		change!(tables[thread], restoreChange)
		if score < minval[thread]
			minval[thread] = score
			toApply[thread] = newChange
		end
	end
	toApply[argmin(minval)]
end

function modularTabuImprove(timeTable, tabu, neighborhoodSize::Int, scoreFunction, canChange, ::Val{false})
	minval = typemax(Int)
	toApply = (defaultChange(timeTable), 0, 0)
	for _ = 1:neighborhoodSize
		newChange, restoreChange = randomChange!(timeTable, change -> canChange(timeTable, change, tabu))
		score = scoreFunction(timeTable)
		change!(timeTable, restoreChange)
		if score < minval
			minval = score
			toApply = newChange
		end
	end
	toApply
end