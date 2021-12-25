include("common.jl")
include("utility.jl")

using LinearAlgebra
using Distributions

struct PermutationRandomIterable
	jobCount::Int
	tryCount::Int
	moveProbability::Float64
	jobDistances::Matrix{Int}
end

struct PermutationRandomIterable2
	jobCount::Int
	tryCount::Int
	moveProbability::Float64
	placedCount::Matrix{Int}
end

struct PermutationRandomIterable3
	jobCount::Int
	tryCount::Int
	moveProbability::Float64
	jobDistances::Matrix{Int}
	placedCount::Matrix{Int}
end

updateCounter(::PermutationRandomIterable, _, _) = nothing
function updateCounter(iterable::PermutationRandomIterable2, jobs::PermutationEncoding, toApply)
	if toApply[1] ≡ PERMUTATION_MOVE
		iterable.placedCount[jobs.permutation[toApply[2]], toApply[3]] += 1
	else
		iterable.placedCount[jobs.permutation[toApply[2]], toApply[3]] += 1
		iterable.placedCount[jobs.permutation[toApply[3]], toApply[2]] += 1
	end
end
function updateCounter(iterable::PermutationRandomIterable3, jobs::PermutationEncoding, toApply)
	if toApply[1] ≡ PERMUTATION_MOVE
		iterable.placedCount[jobs.permutation[toApply[2]], toApply[3]] += 1
	else
		iterable.placedCount[jobs.permutation[toApply[2]], toApply[3]] += 1
		iterable.placedCount[jobs.permutation[toApply[3]], toApply[2]] += 1
	end
end

function (settings::PermutationRandomIterable)(jobs, canDo)
	n = settings.jobCount
	prm = jobs.permutation
	swapProbabilities = [Float64(settings.jobDistances[prm[i], prm[j]]) for i = 1:n, j = 1:n]
	swapDists = [Categorical(normalize(i, 1)) for i ∈ eachcol(swapProbabilities)]
	moveProbabilities = map(Iterators.product(1:n, 1:n)) do (i, j)
		i == j && return 0.0
		j == 1 && return 1 / (settings.jobDistances[prm[i], prm[1]] + 1)
		j == n && return 1 / (settings.jobDistances[prm[i], prm[n]] + 1)
		1 / (settings.jobDistances[prm[i], prm[j-1]] + settings.jobDistances[prm[i], prm[j]] + 1)
	end
	moveDists = [Categorical(normalize(i, 1)) for i ∈ eachrow(moveProbabilities)]
	prob = settings.moveProbability
	count = settings.tryCount
	(controlledPermutationRandom(n, prob, moveDists, swapDists, canDo) for _ = 1:count)
end

function (settings::PermutationRandomIterable2)(jobs, canDo)
	n = settings.jobCount
	prm = jobs.permutation
	swapProbabilities = map(Iterators.product(1:n, 1:n)) do (i, j)
		i == j && return 0.0
		1 / (settings.placedCount[prm[i], j] + 1) / (settings.placedCount[prm[j], i] + 1)
	end
	swapDists = [Categorical(normalize(i, 1)) for i ∈ eachcol(swapProbabilities)]
	moveProbabilities = map(Iterators.product(1:n, 1:n)) do (i, j)
		i == j && return 0.0
		1 / (settings.placedCount[prm[i], j] + 1)
	end
	moveDists = [Categorical(normalize(i, 1)) for i ∈ eachrow(moveProbabilities)]
	prob = settings.moveProbability
	count = settings.tryCount
	(controlledPermutationRandom(n, prob, moveDists, swapDists, canDo) for _ = 1:count)
end

function (settings::PermutationRandomIterable3)(jobs, canDo)
	n = settings.jobCount
	prm = jobs.permutation
	swapProbabilities = map(Iterators.product(1:n, 1:n)) do (i, j)
		i == j && return 0.0
		settings.jobDistances[prm[i], prm[j]] / (settings.placedCount[prm[i], j] + 1) / (settings.placedCount[prm[j], i] + 1)
	end
	swapDists = [Categorical(normalize(i, 1)) for i ∈ eachcol(swapProbabilities)]
	moveProbabilities = map(Iterators.product(1:n, 1:n)) do (i, j)
		i == j && return 0.0
		j == 1 && return 1 / (settings.jobDistances[prm[i], prm[1]] + 1) / (settings.placedCount[prm[i], j] + 1)
		j == n && return 1 / (settings.jobDistances[prm[i], prm[n]] + 1) / (settings.placedCount[prm[i], j] + 1)
		1 / (settings.jobDistances[prm[i], prm[j-1]] + settings.jobDistances[prm[i], prm[j]] + 1) / (settings.placedCount[prm[i], j] + 1)
	end
	moveDists = [Categorical(normalize(i, 1)) for i ∈ eachrow(moveProbabilities)]
	prob = settings.moveProbability
	count = settings.tryCount
	(controlledPermutationRandom(n, prob, moveDists, swapDists, canDo) for _ = 1:count)
end

function controlledPermutationRandom(n, moveProbability, moveProbabilities, swapProbabilities, canDo)
	while true
		if rand() < moveProbability
			job = rand(1:n)
			place = rand(moveProbabilities[job])
			canDo((PERMUTATION_MOVE, job, place)) || continue
			return PERMUTATION_MOVE, job, place
		else
			job1 = rand(1:n)
			job2 = rand(swapProbabilities[job1])
			canDo((PERMUTATION_SWAP, job1, job2)) || continue
			return PERMUTATION_SWAP, job1, job2
		end
	end
end

function controlledPermutationRandom(jobs, moveProbability, jobDistances)
	prm = jobs.permutation
	n = length(prm)
	if rand() < moveProbability
		job = rand(1:n)
		probs = map(1:n) do i
			i == job && return 0.0
			i == 1 && return 1 / (jobDistances[prm[job], prm[1]] + 1)
			i == n && return 1 / (jobDistances[prm[job], prm[n]] + 1)
			1 / (jobDistances[prm[job], prm[i-1]] + jobDistances[prm[job], prm[i]] + 1)
		end
		normalize!(probs, 1)
		place = rand(Categorical(probs))
		return PERMUTATION_MOVE, job, place
	else
		job1 = rand(1:n)
		probs = [Float64(jobDistances[prm[i], prm[job1]]) for i = 1:n]
		normalize!(probs, 1)
		job2 = rand(Categorical(probs))
		return PERMUTATION_SWAP, job1, job2
	end
end

function idleBasedRandom(n, idles, coef)
	probs = fill(coef,n)
	for (i, len) ∈ idles
		probs[i] += len
	end
	normalize!(probs, 1)
	dst = Categorical(probs)
	timetable -> randomChange!(timetable, _ -> true, dst)
end