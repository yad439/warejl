using DataStructures
using ProgressMeter
using ValueHistories

include("common.jl")
include("utility.jl")

struct TabuSearchSettings
	searchTries::Int
	tabuSize::Int
	neighbourhoodSize::Int
end
struct TabuSearchSettings2
	searchTries::Int
	tabuSize::Int
	neighbourhoodSize::Float64
end
struct TabuSearchSettings3
	searchTries::Int
	tabuSize::Int
	neighbourhoodSize::Int
	wavePeriod::Int
	waveMultiplier::Float64
end
struct TabuSearchSettings4{T}
	searchTries::Int
	tabuSize::Int
	neighbourhoodIterator::T
end

modularTabuSearch(settings, scoreFunction, startTimeTable, showProgress = true) = modularTabuSearch(settings, scoreFunction, startTimeTable, OrderedSet{Tuple{changeType(startTimeTable),Int,Int}}(), tabuAdd!, tabuCanChange, showProgress)
modularTabuSearch2(settings, scoreFunction, startTimeTable, showProgress = true) = modularTabuSearch(settings, scoreFunction, startTimeTable, OrderedSet{Int}(), tabuAdd2!, tabuCanChange2, showProgress)
modularTabuSearch3(settings, scoreFunction, startTimeTable::PermutationEncoding, showProgress = true) = modularTabuSearch(settings, scoreFunction, startTimeTable, OrderedSet{Tuple{Int,Int}}(), tabuAdd3!, tabuCanChange3, showProgress)
modularTabuSearch3(settings, scoreFunction, startTimeTable::TwoVectorChange, showProgress = true) = modularTabuSearch(settings, scoreFunction, startTimeTable, OrderedSet{Tuple{Bool,Int,Int}}(), tabuAdd3!, tabuCanChange3, showProgress)
modularTabuSearch4(settings, scoreFunction, startTimeTable::PermutationEncoding, showProgress = true) = modularTabuSearch(settings, scoreFunction, startTimeTable, OrderedSet{Tuple{Int,Int}}(), tabuAdd4!, tabuCanChange3, showProgress)
modularTabuSearch4(settings, scoreFunction, startTimeTable::TwoVectorChange, showProgress = true) = modularTabuSearch(settings, scoreFunction, startTimeTable, OrderedSet{Tuple{Bool,Int,Int}}(), tabuAdd4!, tabuCanChange3, showProgress)
modularTabuSearch5(settings, scoreFunction, startTimeTable::PermutationEncoding, showProgress = true) = modularTabuSearch(settings, scoreFunction, startTimeTable, OrderedSet{Tuple{Int,Int}}(), tabuAdd5!, tabuCanChange3, showProgress)
modularTabuSearch5(settings, scoreFunction, startTimeTable::TwoVectorChange, showProgress = true) = modularTabuSearch(settings, scoreFunction, startTimeTable, OrderedSet{Tuple{Bool,Int,Int}}(), tabuAdd5!, tabuCanChange3, showProgress)

function modularTabuSearch(settings, scoreFunction, startTimeTable, tabuInit, tabuAdd!, tabuCanChange, showProgress = true)
	progress = ProgressUnknown("Local tabu search:")

	timeTable = startTimeTable
	tabu = tabuInit
	minval = scoreFunction(timeTable)
	minsol = copy(timeTable)
	counter = 0

	history = QHistory(typeof(minval))
	push!(history, minval)
	while counter < settings.searchTries
		newTimeTableChange = modularTabuImprove(timeTable, tabu, settings, scoreFunction, tabuCanChange)
		restoreChange = change!(timeTable, newTimeTableChange)
		tabuAdd!(tabu, newTimeTableChange, restoreChange, timeTable)
		score = scoreFunction(timeTable)
		push!(history, score)
		if score < minval
			counter = 0
			minval = score
			copy!(minsol, timeTable)
		else
			counter += 1
		end
		while length(tabu) > settings.tabuSize
			delete!(tabu.dict, first(tabu))
		end
		showProgress && ProgressMeter.next!(progress, showvalues = (("Score", score), ("Min score", minval)))
	end
	ProgressMeter.finish!(progress)
	(score = minval, solution = minsol, history = history)
end
function modularTabuSearch(settings::TabuSearchSettings3, scoreFunction, startTimeTable, tabuInit, tabuAdd!, tabuCanChange, showProgress = true)
	progress = ProgressUnknown("Local tabu search:")

	timeTable = startTimeTable
	waveCenter = deepcopy(timeTable)
	tabu = tabuInit
	minval = scoreFunction(timeTable)
	minsol = copy(timeTable)
	counter = 0
	waveCounter = 1

	history = QHistory(typeof(minval))
	push!(history, minval)
	while counter < settings.searchTries
		newTimeTableChange = modularTabuImprove(timeTable, tabu, settings.neighbourhoodSize, scoreFunction, tabuCanChange, waveCenter, waveCounter * settings.waveMultiplier)
		restoreChange = change!(timeTable, newTimeTableChange)
		tabuAdd!(tabu, newTimeTableChange, restoreChange, timeTable)
		score = scoreFunction(timeTable)
		push!(history, score)
		if score < minval
			counter = 0
			minval = score
			copy!(minsol, timeTable)
		else
			counter += 1
		end
		while length(tabu) > settings.tabuSize
			delete!(tabu.dict, first(tabu))
		end
		if waveCounter < settings.wavePeriod
			waveCounter += 1
		else
			waveCenter = deepcopy(timeTable)
			waveCounter = 1
		end
		showProgress && ProgressMeter.next!(progress, showvalues = (("Score", score), ("Min score", minval)))
	end
	ProgressMeter.finish!(progress)
	(score = minval, solution = minsol, history = history)
end

function modularTabuImprove(timeTable, tabu, settings::TabuSearchSettings, scoreFunction, canChange, ::Val{true} = Val{true}())
	nthreads = Threads.nthreads()
	minval = fill(typemax(Int), nthreads)
	toApply = fill((defaultChange(timeTable), 0, 0), nthreads)
	tables = [deepcopy(timeTable) for _ = 1:nthreads]
	Threads.@threads for _ = 1:settings.neighbourhoodSize
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

function modularTabuImprove(timeTable, tabu, settings::TabuSearchSettings, scoreFunction, canChange, ::Val{false})
	minval = typemax(Int)
	toApply = (defaultChange(timeTable), 0, 0)
	for _ = 1:settings.neighbourhoodSize
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

function modularTabuImprove(timetable, tabu, settings::TabuSearchSettings2, scoreFunction, canChange)
	minval = typemax(Int)
	toApply = (0, 0, 0)
	for change ∈ changeIterator(timetable)
		rand() > settings.neighbourhoodSize && continue
		canChange(timetable, change, tabu) || continue
		restoreChange = change!(timetable, change)
		score = scoreFunction(timetable)
		change!(timetable, restoreChange)
		if score < minval
			minval = score
			toApply = change
		end
	end
	toApply
end

function modularTabuImprove(timeTable, tabu, settings::TabuSearchSettings3, scoreFunction, canChange, center, coef)
	minval = typemax(Float64)
	toApply = (defaultChange(timeTable), 0, 0)
	for _ = 1:settings.neighbourhoodSize
		newChange, restoreChange = randomChange!(timeTable, change -> canChange(timeTable, change, tabu))
		score = scoreFunction(timeTable) + coef / distance(center, timeTable)
		change!(timeTable, restoreChange)
		if score < minval
			minval = score
			toApply = newChange
		end
	end
	toApply
end

function modularTabuImprove(timeTable, tabu, settings::TabuSearchSettings4{T}, scoreFunction, canChange) where {T}
	minval = typemax(Int)
	toApply = (defaultChange(timeTable), 0, 0)
	for newChange ∈ settings.neighbourhoodIterator(timeTable, change -> canChange(timeTable, change, tabu))
		restoreChange = change!(timeTable, newChange)
		score = scoreFunction(timeTable)
		change!(timeTable, restoreChange)
		if score < minval
			minval = score
			toApply = newChange
		end
	end
	updateCounter(settings.neighbourhoodIterator, timeTable, toApply)
	toApply
end

function tabuAdd!(tabu, newChange, restoreChange, solution)
	push!(tabu, restoreChange)
end
function tabuAdd2!(tabu, newChange, restoreChange, solution)
	if newChange[1] ≡ PERMUTATION_MOVE
		push!(tabu, newChange[2])
	elseif newChange[1] ≡ PERMUTATION_SWAP
		push!(tabu, newChange[2])
		push!(tabu, newChange[3])
	end
end
function tabuAdd3!(tabu, newChange, restoreChange, solution::PermutationEncoding)
	if restoreChange[1] ≡ PERMUTATION_MOVE
		push!(tabu, (solution.permutation[restoreChange[2]], restoreChange[3]))
	elseif restoreChange[1] ≡ PERMUTATION_SWAP
		push!(tabu, (solution.permutation[restoreChange[2]], restoreChange[3]))
		push!(tabu, (solution.permutation[restoreChange[3]], restoreChange[2]))
	else
		@assert false
	end
end
function tabuAdd3!(tabu, newChange, restoreChange, solution::TwoVectorEncoding)
	if restoreChange[1] ≡ TWO_VECTOR_MOVE_ORDER
		push!(tabu, (true, solution.permutation[restoreChange[2]], restoreChange[3]))
	elseif restoreChange[1] ≡ TWO_VECTOR_SWAP_ORDER
		push!(tabu, (true, solution.permutation[restoreChange[2]], restoreChange[3]))
		push!(tabu, (true, solution.permutation[restoreChange[3]], restoreChange[2]))
	elseif restoreChange[1] ≡ TWO_VECTOR_MOVE_ASSIGNMENT
		push!(tabu, (false, restoreChange[2], restoreChange[3]))
	elseif restoreChange[1] ≡ TWO_VECTOR_SWAP_ASSIGNMENT
		push!(tabu, (false, restoreChange[2], solution.assignment[restoreChange[3]]))
		push!(tabu, (false, restoreChange[3], solution.assignment[restoreChange[2]]))
	else
		@assert false
	end
end
function tabuAdd4!(tabu, newChange, restoreChange, solution::PermutationEncoding)
	if newChange[1] ≡ PERMUTATION_MOVE
		push!(tabu, (solution.permutation[newChange[2]], newChange[2]))
	elseif newChange[1] ≡ PERMUTATION_SWAP
		push!(tabu, (solution.permutation[newChange[2]], newChange[2]))
		push!(tabu, (solution.permutation[newChange[3]], newChange[3]))
	else
		@assert false
	end
end
function tabuAdd4!(tabu, newChange, restoreChange, solution::TwoVectorEncoding)
	if newChange[1] ≡ TWO_VECTOR_MOVE_ORDER
		push!(tabu, (true, solution.permutation[newChange[2]], newChange[3]))
	elseif newChange[1] ≡ TWO_VECTOR_SWAP_ORDER
		push!(tabu, (true, solution.permutation[newChange[2]], newChange[3]))
		push!(tabu, (true, solution.permutation[newChange[3]], newChange[2]))
	elseif newChange[1] ≡ TWO_VECTOR_MOVE_ASSIGNMENT
		push!(tabu, (false, newChange[2], newChange[3]))
	elseif newChange[1] ≡ TWO_VECTOR_SWAP_ASSIGNMENT
		push!(tabu, (false, newChange[2], solution.assignment[newChange[3]]))
		push!(tabu, (false, newChange[3], solution.assignment[newChange[2]]))
	else
		@assert false
	end
end
function tabuAdd5!(tabu, newChange, restoreChange, solution)
	tabuAdd3!(tabu, newChange, restoreChange, solution)
	tabuAdd4!(tabu, newChange, restoreChange, solution)
end
function tabuCanChange(::TwoVectorEncoding, change, tabu)
	if change[1] == TWO_VECTOR_MOVE_ORDER || change[1] == TWO_VECTOR_MOVE_ASSIGNMENT
		return change ∉ tabu
	elseif change[1] == TWO_VECTOR_SWAP_ORDER || change[1] == TWO_VECTOR_SWAP_ASSIGNMENT
		return (change[1], change[2], change[3]) ∉ tabu && (change[1], change[3], change[2]) ∉ tabu
	end
	@assert(false)
end

function tabuCanChange(::PermutationEncoding, change, tabu)
	if change[1] == PERMUTATION_MOVE
		return change ∉ tabu
	elseif change[1] == PERMUTATION_SWAP
		return (PERMUTATION_SWAP, change[2], change[3]) ∉ tabu && (PERMUTATION_SWAP, change[3], change[2]) ∉ tabu
	end
	@assert(false)
end

function tabuCanChange2(::PermutationEncoding, change, tabu)
	if change[1] == PERMUTATION_MOVE
		return change[2] ∉ tabu
	elseif change[1] == PERMUTATION_SWAP
		return change[2] ∉ tabu && change[3] ∉ tabu
	end
	@assert(false)
end
function tabuCanChange3(solution::PermutationEncoding, change, tabu)
	if change[1] ≡ PERMUTATION_MOVE
		return (solution.permutation[change[2]], change[3]) ∉ tabu
	elseif change[1] ≡ PERMUTATION_SWAP
		return (solution.permutation[change[2]], change[3]) ∉ tabu && (solution.permutation[change[3]], change[2]) ∉ tabu
	end
	@assert(false)
end
function tabuCanChange3(solution::TwoVectorEncoding, change, tabu)
	if change[1] ≡ TWO_VECTOR_MOVE_ORDER
		return (true, solution.permutation[change[2]], change[3]) ∉ tabu
	elseif change[1] ≡ TWO_VECTOR_SWAP_ORDER
		return (true, solution.permutation[change[2]], change[3]) ∉ tabu && (solution.permutation[change[3]], change[2]) ∉ tabu
	elseif change[1] ≡ TWO_VECTOR_MOVE_ASSIGNMENT
		return (false, change[2], change[3]) ∉ tabu
	elseif change[1] ≡ TWO_VECTOR_SWAP_ASSIGNMENT
		return (false, change[2], solution.assignment[change[3]]) ∉ tabu && (false, change[3], solution.assignment[change[2]]) ∉ tabu
	end
	@assert(false)
end