include("encodings.jl")
include("utility.jl")

struct AnnealingSettings
	searchTries::Int
	isDynamic::Bool
	sameTemperatureTries::Int
	startTheshold::Float64
	decreasingFunction::FuncR{Float64}
	applyChange::FuncR{Bool}
end
struct AnnealingSettings2
	searchTries::Int
	isDynamic::Bool
	sameTemperatureTries::Int
	startTheshold::Float64
	decreasingFunction::Function
	applyChange::Function
	changeGenerator::Function
end

function modularAnnealing(settings::AnnealingSettings, scoreFunction::F, startTimeTable) where {F}
	timeTable = startTimeTable
	minval = scoreFunction(timeTable)
	minsol = copy(timeTable)
	counter = 0
	threshold = settings.startTheshold

	prevScore = minval
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
	end
	(score = minval, solution = minsol)
end

function modularAnnealing(settings::AnnealingSettings2, scoreFunction::F, startTimeTable) where {F}
	timeTable = startTimeTable
	minval = scoreFunction(timeTable)
	minsol = copy(timeTable)
	counter = 0
	threshold = settings.startTheshold

	prevScore = minval
	scounter = 1
	while counter < settings.searchTries
		newChange = settings.changeGenerator(timeTable)
		restoreChange = change!(timeTable, newChange)
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
	end
	(score = minval, solution = minsol)
end

function maxDif(jobs::PermutationEncoding, scoreFunction)
	minval = typemax(Int)
	maxval = typemin(Int)
	for type ∈ [PERMUTATION_MOVE, PERMUTATION_SWAP], arg1 in 1:length(jobs), arg2 in 1:length(jobs)
		arg1 == arg2 && continue
		restoreChange = change!(jobs, type, arg1, arg2)
		score = scoreFunction(jobs)
		change!(jobs, restoreChange)
		score < minval && (minval = score)
		score > maxval && (maxval = score)
	end
	maxval - minval
end

#=function maxDif(jobs::TwoVectorEncoding, scoreFunction)
	minval = typemax(Int)
	maxval = typemin(Int)
	for type ∈ [TWO_VECTOR_SWAP_ASSIGNMENT, TWO_VECTOR_MOVE_ORDER, TWO_VECTOR_SWAP_ORDER], arg1 in 1:length(jobs), arg2 in 1:length(jobs)
		arg1 == arg2 && continue
		restoreChange = change!(jobs, type, arg1, arg2)
		score = scoreFunction(jobs)
		change!(jobs, restoreChange)
		score < minval && (minval = score)
		score > maxval && (maxval = score)
	end
	for arg1 in 1:length(jobs), arg2 in 1:jobs.machineCount
		restoreChange = change!(jobs, TWO_VECTOR_MOVE_ASSIGNMENT, arg1, arg2)
		score = scoreFunction(jobs)
		change!(jobs, restoreChange)
		score < minval && (minval = score)
		score > maxval && (maxval = score)
	end
	maxval - minval
end=#
