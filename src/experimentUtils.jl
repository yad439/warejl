include("realDataUtility.jl");
include("linear.jl");

include("annealing.jl");
include("tabu.jl");
include("hybridTabu.jl");

using Statistics
using Distributed

using ThreadsX
using DataFrames

if nprocs() > 1
	@everywhere begin
		#import Pkg;
		#Pkg.activate(".");

		include("mainAuxiliary.jl")
		include("annealing.jl")
		include("tabu.jl")
		include("hybridTabu.jl")
	end
end


const ModelResult = @NamedTuple {solution::Union{Float32,Missing}, bound::Union{Float32,Missing}}

mutable struct ModelResults
	fullModel::Union{ModelResult,Nothing}
	bufferOnly::Union{ModelResult,Nothing}
	transportOnly::Union{ModelResult,Nothing}
	assignmentOnly::Union{ModelResult,Nothing}
end

struct TabuResult
	startSolution::Vector{UInt16}
	solution::Vector{UInt16}
	foundIteration::UInt32
end

struct TabuExperiment
	sortReturns::Bool
	algorithmType::UInt8
	baseIterations::UInt16
	tabuSize::UInt16
	neigborhoodSize::UInt16
	moveProbability::Float16
	other::Set{String}
	type::String
	results::Vector{TabuResult}
end

struct AnnealingResult
	startSolution::Vector{UInt16}
	solution::Vector{UInt16}
	foundIteration::UInt32
end

struct AnnealingExperiment
	sortReturns::Bool
	iterationCount::UInt32
	dynamic::Bool
	sameTemperatureIterations::UInt32
	startThreshold::Float32
	power::Float64
	moveProbability::Float16
	other::Set{String}
	type::String
	results::Vector{AnnealingResult}
end

struct HybridResult1
	startSolution::Vector{UInt16}
	solution::Vector{UInt16}
	foundIteration::UInt16
end

struct HybridExperiment1
	sortReturns::Bool
	version::UInt8
	baseIterations::UInt16
	tabuSize::UInt16
	neigborhoodSize::UInt16
	annealingIterations::UInt32
	sameTemperatureIterations::UInt32
	startThreshold::Float32
	power::Float64
	restarts::UInt8
	other::Set{String}
	type::String
	results::Vector{TabuResult}
end

struct HybridExperiment2
	sortReturns::Bool
	version::UInt8
	baseIterations::UInt16
	tabuSize::UInt16
	neigborhoodSize1::UInt16
	neigborhoodSize2::UInt16
	size2Iterations::UInt16
	restarts::UInt8
	other::Set{String}
	type::String
	results::Vector{TabuResult}
end

struct HybridExperiment3
	sortReturns::Bool
	version::UInt8
	baseIterations::UInt16
	tabuSize::UInt16
	neigborhoodSizes::Vector{UInt16}
	other::Set{String}
	type::String
	results::Vector{TabuResult}
end

struct HybridExperiment13
	sortReturns::Bool
	version::UInt8
	baseIterations::UInt16
	tabuSize::UInt16
	neigborhoodSizes::Vector{UInt16}
	annealingIterations::UInt32
	sameTemperatureIterations::UInt32
	startThreshold::Float32
	power::Float64
	restarts::UInt8
	other::Set{String}
	type::String
	results::Vector{TabuResult}
end

@enum OtherTypes::UInt8 HYBRID1_TYPE = 1 HYBRID2_TYPE HYBRID3_TYPE HYBRID13_TYPE

struct OtherResult
	type::OtherTypes
	result::Union{HybridExperiment1,HybridExperiment2,HybridExperiment3,HybridExperiment13}
end

struct ProblemInstance
	problemSize::UInt16
	problemNumber::UInt8
	lineTypes::Set{Char}
	boxLimit::Union{UInt16,Missing}
	machineCount::UInt8
	carCount::UInt8
	bufferSize::UInt8
	skipZeros::Bool
	modelResults::ModelResults
	tabuResults::Vector{TabuExperiment}
	annealingResults::Vector{AnnealingExperiment}
	otherResults::Vector{OtherResult}
end

createInstance(problemSize, problemNumber, lineTypes, boxLimit, machineCount, carCount, bufferSize, skipZeros = true)::ProblemInstance =
	ProblemInstance(
		problemSize,
		problemNumber,
		Set(lineTypes),
		boxLimit,
		machineCount,
		carCount,
		bufferSize,
		skipZeros,
		ModelResults(nothing, nothing, nothing, nothing),
		TabuExperiment[],
		AnnealingExperiment[],
		OtherResult[]
	)

function findInstance(data, problemSize, problemNumber, lineTypes, boxLimit, machineCount, carCount, bufferSize, skipZeros = nothing)::Union{ProblemInstance,Nothing}
	lineTypeSet = Set(lineTypes)

	ind = findfirst(it ->
			it.problemSize == problemSize
				&& it.problemNumber == problemNumber
				&& it.lineTypes == lineTypeSet
				&& isequal(it.boxLimit, boxLimit)
				&& it.machineCount == machineCount
				&& it.carCount == carCount
				&& it.bufferSize == bufferSize
				&& (skipZeros ≢ nothing ? it.skipZeos == skipZeros : true), data)
	ind ≡ nothing ? nothing : data[ind]
end

function instanceToProblem(instance::ProblemInstance)::Problem
	limitCounter = instance.boxLimit ≢ missing ? Counter(instance.boxLimit) : () -> true
	Problem(
		parseRealData("res/benchmark - automatic warehouse", instance.problemSize, instance.problemNumber),
		instance.machineCount,
		instance.carCount,
		instance.bufferSize,
		box -> box.lineType[1] ∈ instance.lineTypes && !isempty(box.items) && (!instance.skipZeros || box.packingTime ≠ 0) && limitCounter()
	)
end

function problemStats(problemSize::Int, problemNum::Int, lineTypes::Vector{Char})::@NamedTuple {jobCount::Int, items::Int, maxItems::Int, travelTime::Int}
	lineTypesSet = Set(lineTypes)
	data = toModerateJobs(parseRealData("res/benchmark - automatic warehouse", problemSize, problemNum), box -> box.lineType[1] ∈ lineTypesSet && !isempty(box.items))
	(
		jobCount = length(data.lengths),
		items = maximum(maximum, data.itemsForJob),
		maxItems = maximum(length, data.itemsForJob),
		travelTime = data.carTravelTime
	)
end

function resultsToTable(results::Vector{ProblemInstance})
	df = DataFrame(
		probSize = Int[],
		probNum = Int[],
		jobCount = Int[],
		machineCount = Int[],
		carCount = Int[],
		bufSize = Int[],
		fullSol = Union{Float64,Missing}[],
		fullLB = Union{Float64,Missing}[],
		bufferSol = Union{Float64,Missing}[],
		bufferLB = Union{Float64,Missing}[],
		carsSol = Union{Float64,Missing}[],
		carsLB = Union{Float64,Missing}[],
		simpleSol = Union{Float64,Missing}[],
		simpleLB = Union{Float64,Missing}[],
		annMin = Union{Int,Missing}[],
		annMean = Union{Float64,Missing}[],
		tabuMin = Union{Int,Missing}[],
		tabuMean = Union{Float64,Missing}[]
	)
	for instance ∈ results
		problem = instanceToProblem(instance)
		scoreFunction(sol) = computeTimeLazyReturn(PermutationEncoding(sol), problem, Val(false), true)
		annRess = map(r -> map(t -> scoreFunction(t.solution), r.results), instance.annealingResults)
		tabuRess = map(r -> map(t -> scoreFunction(t.solution), r.results), instance.tabuResults)
		annMean = isempty(annRess) ? missing : minimum(mean, annRess)
		tabuMean = isempty(tabuRess) ? missing : minimum(mean, tabuRess)
		annMin = isempty(annRess) ? missing : minimum(minimum, annRess)
		tabuMin = isempty(tabuRess) ? missing : minimum(minimum, tabuRess)
		push!(df, (
			instance.problemSize,
			instance.problemNumber,
			problem.jobCount,
			instance.machineCount,
			instance.carCount,
			instance.bufferSize,
			instance.modelResults.fullModel ≢ nothing ? instance.modelResults.fullModel.solution : missing,
			instance.modelResults.fullModel ≢ nothing ? instance.modelResults.fullModel.bound : missing,
			instance.modelResults.bufferOnly ≢ nothing ? instance.modelResults.bufferOnly.solution : missing,
			instance.modelResults.bufferOnly ≢ nothing ? instance.modelResults.bufferOnly.bound : missing,
			instance.modelResults.transportOnly ≢ nothing ? instance.modelResults.transportOnly.solution : missing,
			instance.modelResults.transportOnly ≢ nothing ? instance.modelResults.transportOnly.bound : missing,
			instance.modelResults.assignmentOnly ≢ nothing ? instance.modelResults.assignmentOnly.solution : missing,
			instance.modelResults.assignmentOnly ≢ nothing ? instance.modelResults.assignmentOnly.bound : missing,
			annMin,
			annMean,
			tabuMin,
			tabuMean
		))
	end
	df
end

function resultsToArtTable(results::Vector{ProblemInstance})
	df = DataFrame(
		jobCount = Int[],
		tabuBest = Union{Int,Missing}[],
		tabuWorst = Union{Int,Missing}[],
		tabuMean = Union{Float64,Missing}[],
		annBest = Union{Int,Missing}[],
		annWorst = Union{Int,Missing}[],
		annMean = Union{Float64,Missing}[],
		hyb1Best = Union{Int,Missing}[],
		hyb1Worst = Union{Int,Missing}[],
		hyb1Mean = Union{Float64,Missing}[],
		fullSol = Union{Int,Missing}[],
		fullLB = Union{Int,Missing}[],
		bestLB = Int[]
	)
	for instance ∈ results
		problem = instanceToProblem(instance)
		scoreFunction(sol) = computeTimeLazyReturn(PermutationEncoding(sol), problem, Val(false), true)
		annRess = map(r -> map(t -> scoreFunction(t.solution), r.results), instance.annealingResults)
		tabuRess = map(r -> map(t -> scoreFunction(t.solution), r.results), instance.tabuResults)
		hybrid1Res = [[scoreFunction(r.solution) for r ∈ res.result.results] for res ∈ instance.otherResults if res.type ≡ HYBRID1_TYPE]
		annMean = missing
		annBest = missing
		annWorst = missing
		tabuMean = missing
		tabuBest = missing
		tabuWorst = missing
		hyb1Mean = missing
		hyb1Best = missing
		hyb1Worst = missing
		if !isempty(annRess)
			means = map(mean, annRess)
			i = argmin(means)
			annBest = minimum(annRess[i])
			annWorst = maximum(annRess[i])
			annMean = mean(annRess[i])
		end
		if !isempty(tabuRess)
			means = map(mean, tabuRess)
			i = argmin(means)
			tabuBest = minimum(tabuRess[i])
			tabuWorst = maximum(tabuRess[i])
			tabuMean = mean(tabuRess[i])
		end
		if !isempty(hybrid1Res)
			means = map(mean, hybrid1Res)
			i = argmin(means)
			hyb1Best = minimum(hybrid1Res[i])
			hyb1Worst = maximum(hybrid1Res[i])
			hyb1Mean = mean(hybrid1Res[i])
		end
		bestLB = 0
		if instance.modelResults.fullModel ≢ nothing && instance.modelResults.fullModel.bound > bestLB
			bestLB = instance.modelResults.fullModel.bound
		end
		if instance.modelResults.bufferOnly ≢ nothing && instance.modelResults.bufferOnly.bound > bestLB
			bestLB = instance.modelResults.bufferOnly.bound
		end
		if instance.modelResults.transportOnly ≢ nothing && instance.modelResults.transportOnly.bound > bestLB
			bestLB = instance.modelResults.transportOnly.bound
		end
		if instance.modelResults.assignmentOnly ≢ nothing && instance.modelResults.assignmentOnly.bound > bestLB
			bestLB = instance.modelResults.assignmentOnly.bound
		end
		push!(df, (
			problem.jobCount,
			tabuBest,
			tabuWorst,
			tabuMean,
			annBest,
			annWorst,
			annMean,
			hyb1Best,
			hyb1Worst,
			hyb1Mean,
			instance.modelResults.fullModel ≢ nothing ? round(Int, instance.modelResults.fullModel.solution) : missing,
			instance.modelResults.fullModel ≢ nothing ? ceil(Int, instance.modelResults.fullModel.bound) : missing,
			ceil(Int, bestLB)
		))
	end
	df
end

function hybrid1Table(results::Vector{ProblemInstance})
	dataframe = DataFrame(
		probSize = Int[],
		probNum = Int[],
		machines = Int[],
		carCount = Int[],
		bufSize = Int[],
		baseIter = Int[],
		tabuSize = Int[],
		neigh = Int[],
		annIter = Int[],
		sameTemp = Int[],
		threshold = Float64[],
		power = Float64[],
		restarts = Int[],
		type = String[],
		best = Int[],
		worst = Int[],
		mean = Float64[],
		minIter = Int[],
		maxIter = Int[],
		meanIter = Float64[]
	)
	for instance ∈ results
		actual = map(x -> x.result, Iterators.filter(x -> x.type ≡ HYBRID1_TYPE, instance.otherResults))
		isempty(actual) && continue
		problem = instanceToProblem(instance)
		scoreFunction(sol) = computeTimeLazyReturn(PermutationEncoding(sol), problem, Val(false), true)
		for result ∈ actual
			scores = map(it -> scoreFunction(it.solution), result.results)
			iterations = map(it -> it.foundIteration, result.results)
			push!(dataframe, (
				instance.problemSize,
				instance.problemNumber,
				instance.machineCount,
				instance.carCount,
				instance.bufferSize,
				result.baseIterations,
				result.tabuSize,
				result.neigborhoodSize,
				result.annealingIterations,
				result.sameTemperatureIterations,
				result.startThreshold,
				result.power,
				result.restarts,
				result.type,
				minimum(scores),
				maximum(scores),
				mean(scores),
				minimum(iterations),
				maximum(iterations),
				mean(iterations)
			))
		end
	end
	dataframe
end

function hybrid2Table(results::Vector{ProblemInstance})
	dataframe = DataFrame(
		probSize = Int[],
		probNum = Int[],
		machines = Int[],
		carCount = Int[],
		bufSize = Int[],
		baseIter = Int[],
		otherIter = Int[],
		tabuSize = Int[],
		neigh = Int[],
		otherNeigh = Int[],
		restarts = Int[],
		type = String[],
		best = Int[],
		worst = Int[],
		mean = Float64[],
		minIter = Int[],
		maxIter = Int[],
		meanIter = Float64[]
	)
	for instance ∈ results
		actual = map(x -> x.result, Iterators.filter(x -> x.type ≡ HYBRID2_TYPE, instance.otherResults))
		isempty(actual) && continue
		problem = instanceToProblem(instance)
		scoreFunction(sol) = computeTimeLazyReturn(PermutationEncoding(sol), problem, Val(false), true)
		for result ∈ actual
			scores = map(it -> scoreFunction(it.solution), result.results)
			iterations = map(it -> it.foundIteration, result.results)
			push!(dataframe, (
				instance.problemSize,
				instance.problemNumber,
				instance.machineCount,
				instance.carCount,
				instance.bufferSize,
				result.baseIterations,
				result.size2Iterations,
				result.tabuSize,
				result.neigborhoodSize1,
				result.neigborhoodSize2,
				result.restarts,
				result.type,
				minimum(scores),
				maximum(scores),
				mean(scores),
				minimum(iterations),
				maximum(iterations),
				mean(iterations)
			))
		end
	end
	dataframe
end

function hybrid13Table(results::Vector{ProblemInstance})
	dataframe = DataFrame(
		probSize = Int[],
		probNum = Int[],
		machines = Int[],
		carCount = Int[],
		bufSize = Int[],
		baseIter = Int[],
		tabuSize = Int[],
		neighs = Vector{Int}[],
		annIter = Int[],
		sameTemp = Int[],
		threshold = Float64[],
		power = Float64[],
		restarts = Int[],
		type = String[],
		best = Int[],
		worst = Int[],
		mean = Float64[],
		minIter = Int[],
		maxIter = Int[],
		meanIter = Float64[]
	)
	for instance ∈ results
		actual = map(x -> x.result, Iterators.filter(x -> x.type ≡ HYBRID13_TYPE, instance.otherResults))
		isempty(actual) && continue
		problem = instanceToProblem(instance)
		scoreFunction(sol) = computeTimeLazyReturn(PermutationEncoding(sol), problem, Val(false), true)
		for result ∈ actual
			scores = map(it -> scoreFunction(it.solution), result.results)
			iterations = map(it -> it.foundIteration, result.results)
			push!(dataframe, (
				instance.problemSize,
				instance.problemNumber,
				instance.machineCount,
				instance.carCount,
				instance.bufferSize,
				result.baseIterations,
				result.tabuSize,
				result.neigborhoodSizes,
				result.annealingIterations,
				result.sameTemperatureIterations,
				result.startThreshold,
				result.power,
				result.restarts,
				result.type,
				minimum(scores),
				maximum(scores),
				mean(scores),
				minimum(iterations),
				maximum(iterations),
				mean(iterations)
			))
		end
	end
	dataframe
end

function runLinear(problem::Problem, machineType::MachineModelType, carType::CarModelType; timeLimit::Int = 0, startSolution::Union{Bool,PermutationEncoding} = false)
	sample = EncodingSample{PermutationEncoding}(problem.jobCount, problem.machineCount)
	sol = computeTimeLazyReturn(isa(startSolution, PermutationEncoding) ? startSolution : rand(sample), problem, Val(true))
	T = sol.schedule.carTasks |> ffilter(e -> e.isAdd) |> fmap(e -> e.time) |> unique |> length
	M = sol.time

	exactModel = buildModel(problem, machineType, carType, T, M)
	if isa(startSolution, PermutationEncoding) || startSolution
		setStartValues(exactModel, sol.schedule, problem)
	end
	res = runModel(exactModel, timeLimit)

	if carType ∈ [BUFFER_ONLY, NO_CARS]
		res = res .+ problem.carTravelTime
	end
	res
end

function runAnnealing(problem::Problem, starts::Vector{PermutationEncoding}, steps::Int, same::Int, temp::Float64; uniform::Bool = true, fast::Bool = false, improvements::Vector{String} = String[], type::String = "")
	sf(jobs) = computeTimeLazyReturn(jobs, problem, Val(false), !fast)
	sf2(jobs) = computeTimeLazyReturn(jobs, problem, Val(false), true)

	power = (-temp * log(10^-3))^(-1 / (steps / same))
	if uniform
		annealingSettings = AnnealingSettings(steps, false, same, temp, it -> it * power, (old, new, threshold) -> rand() < exp((old - new) / threshold))
		ress = ThreadsX.map(1:length(starts)) do i
			println("Start $i")
			solution = modularAnnealing(annealingSettings, sf, deepcopy(starts[i]), false)
			println("End $i")
			solution
		end
		results = map(starts, ress) do st, sol
			AnnealingResult(
				st.permutation,
				sol.solution.permutation,
				argmin(get(sol.history)[2])
			)
		end
		return AnnealingExperiment(
			!fast,
			steps,
			false,
			same,
			temp,
			power,
			0.5,
			Set(improvements),
			type,
			results
		)
	else
		dist = jobDistance(problem.itemsNeeded)
		rdm = jobs -> controlledPermutationRandom(jobs, 0.5, dist)
		annealingSettings = AnnealingSettings2(steps, false, same, temp, it -> it * power, (old, new, threshold) -> rand() < exp((old - new) / threshold), rdm)
		ress = ThreadsX.map(1:length(starts)) do i
			println("Start $i")
			solution = modularAnnealing(annealingSettings, sf, deepcopy(starts[i]), false)
			println("End $i")
			solution
		end
		results = map(starts, ress) do st, sol
			AnnealingResult(
				st.permutation,
				sol.solution.permutation,
				argmin(get(sol.history)[2])
			)
		end
		return AnnealingExperiment(
			!fast,
			steps,
			false,
			same,
			temp,
			power,
			0.5,
			Set(improvements),
			type,
			results
		)
	end
	@assert false
	AnnealingExperiment(false, 0, false, 0, 0.0, 0.0, 0.0, Set{String}(), "", AnnealingResult[])
end

function runTabu(problem::Problem, starts::Vector{PermutationEncoding}, steps::Int, tabuLength::Int, neigborhoodSize::Int; distribution::String = "uniform", fast::Bool = false, improvements::Vector{String} = String[], type::String = "")
	sf(jobs) = computeTimeLazyReturn(jobs, problem, Val(false), !fast)
	sf2(jobs) = computeTimeLazyReturn(jobs, problem, Val(false), true)

	if distribution == "uniform"
		tabuSettings = TabuSearchSettings(steps, tabuLength, neigborhoodSize)
		ress = ThreadsX.map(1:length(starts)) do i
			println("Start $i")
			solution = modularTabuSearch5(tabuSettings, sf, deepcopy(starts[i]), false)
			println("End $i")
			solution
		end
		results = map(starts, ress) do st, sol
			TabuResult(
				st.permutation,
				sol.solution.permutation,
				argmin(get(sol.history)[2])
			)
		end
		return TabuExperiment(
			!fast,
			5,
			steps,
			tabuLength,
			neigborhoodSize,
			0.5,
			Set(improvements),
			type,
			results
		)
	elseif distribution == "item"
		ress = ThreadsX.map(1:length(starts)) do i
			rdm = PermutationRandomIterable(problem.jobCount, neigborhoodSize, 0.5, jobDistance(problem.itemsNeeded))
			tabuSettings = TabuSearchSettings4(steps, tabuLength, rdm)
			println("Start $i")
			solution = modularTabuSearch5(tabuSettings, sf, deepcopy(starts[i]), false)
			println("End $i")
			solution
		end
		results = map(starts, ress) do st, sol
			TabuResult(
				st.permutation,
				sol.solution.permutation,
				argmin(get(sol.history)[2])
			)
		end
		return TabuExperiment(
			!fast,
			5,
			steps,
			tabuLength,
			neigborhoodSize,
			0.5,
			Set(improvements),
			type,
			results
		)
	elseif distribution == "count"
		ress = ThreadsX.map(1:length(starts)) do i
			rdm = PermutationRandomIterable2(problem.jobCount, neigborhoodSize, 0.5, zeros(Int, problem.jobCount, problem.jobCount))
			tabuSettings = TabuSearchSettings4(steps, tabuLength, rdm)
			println("Start $i")
			solution = modularTabuSearch5(tabuSettings, sf, deepcopy(starts[i]), false)
			println("End $i")
			solution
		end
		results = map(starts, ress) do st, sol
			TabuResult(
				st.permutation,
				sol.solution.permutation,
				argmin(get(sol.history)[2])
			)
		end
		return TabuExperiment(
			!fast,
			5,
			steps,
			tabuLength,
			neigborhoodSize,
			0.5,
			Set(improvements),
			type,
			results
		)
	elseif distribution == "item_count"
		ress = ThreadsX.map(1:length(starts)) do i
			rdm = PermutationRandomIterable3(problem.jobCount, neigborhoodSize, 0.5, jobDistance(problem.itemsNeeded), zeros(Int, problem.jobCount, problem.jobCount))
			tabuSettings = TabuSearchSettings4(steps, tabuLength, rdm)
			println("Start $i")
			solution = modularTabuSearch5(tabuSettings, sf, deepcopy(starts[i]), false)
			println("End $i")
			solution
		end
		results = map(starts, ress) do st, sol
			TabuResult(
				st.permutation,
				sol.solution.permutation,
				argmin(get(sol.history)[2])
			)
		end
		return TabuExperiment(
			!fast,
			5,
			steps,
			tabuLength,
			neigborhoodSize,
			0.5,
			Set(improvements),
			type,
			results
		)
	else
		@assert false
	end
	@assert false
	TabuExperiment(false, 0, 0, 0, 0, 0.0, Set{String}(), "", TabuResult[])
end

function runHybrid1(problem::Problem, starts::Vector{PermutationEncoding}, tabuSteps::Int, annealingSteps::Int, restarts::Int, tabuLength::Int, neigborhoodSize::Int, annealingTemp::Float64, annealingPower::Float64 = (-annealingTemp * log(10^-3))^(-1 / (annealingSteps)); fast::Bool = false, improvements::Vector{String} = String[], type::String = "", threading::Symbol = :outer, distributed::Bool = false)
	sf(jobs) = computeTimeLazyReturn(jobs, problem, Val{false}(), !fast)
	sf2(jobs) = computeTimeLazyReturn(jobs, problem, Val{false}(), true)

	tabuSettings = TabuSearchSettings(tabuSteps, tabuLength, neigborhoodSize)
	annealingSettings = AnnealingSettings(annealingSteps, false, 1, annealingTemp, it -> it * annealingPower, (old, new, threshold) -> rand() < exp((old - new) / threshold))
	hybridSettings = HybridTabuSettings1(tabuSettings, annealingSettings, restarts)

	outerThreading = threading ∈ (:outer, :both)
	innerThreading = threading ∈ (:inner, :both)
	mapFunc = outerThreading ? distributed ? pmap : ThreadsX.map : map

	ress = mapFunc(1:length(starts)) do i
		println("Start $i")
		solution = hybridTabuSearch(hybridSettings, sf, deepcopy(starts[i]), false, threaded = Val(innerThreading))
		println("End $i")
		solution
	end
	results = map(starts, ress) do st, sol
		TabuResult(
			st.permutation,
			sol.solution.permutation,
			argmin(get(sol.history)[2])
		)
	end

	return OtherResult(
		HYBRID1_TYPE,
		HybridExperiment1(
			!fast,
			1,
			tabuSteps,
			tabuLength,
			neigborhoodSize,
			annealingSteps,
			1,
			annealingTemp,
			annealingPower,
			restarts,
			Set(improvements),
			type,
			results
		)
	)
end

function runHybrid2(problem::Problem, starts::Vector{PermutationEncoding}, tabuSteps::Int, anotherSteps::Int, restarts::Int, tabuLength::Int, neigborhoodSize1::Int, neigborhoodSize2::Int; fast::Bool = false, improvements::Vector{String} = String[], type::String = "", threading::Symbol = :outer, distributed::Bool = false)
	sf(jobs) = computeTimeLazyReturn(jobs, problem, Val{false}(), !fast)
	sf2(jobs) = computeTimeLazyReturn(jobs, problem, Val{false}(), true)

	hybridSettings = HybridTabuSettings2(tabuSteps, tabuLength, neigborhoodSize1, neigborhoodSize2, anotherSteps, restarts)

	outerThreading = threading ∈ (:outer, :both)
	innerThreading = threading ∈ (:inner, :both)
	mapFunc = outerThreading ? distributed ? pmap : ThreadsX.map : map

	ress = mapFunc(1:length(starts)) do i
		println("Start $i")
		solution = hybridTabuSearch(hybridSettings, sf, deepcopy(starts[i]), false, threaded = Val(innerThreading))
		println("End $i")
		solution
	end
	results = map(starts, ress) do st, sol
		TabuResult(
			st.permutation,
			sol.solution.permutation,
			argmin(get(sol.history)[2])
		)
	end

	return OtherResult(
		HYBRID2_TYPE,
		HybridExperiment2(
			!fast,
			1,
			tabuSteps,
			tabuLength,
			neigborhoodSize1,
			neigborhoodSize2,
			anotherSteps,
			restarts,
			Set(improvements),
			type,
			results
		)
	)
end

function runHybrid3(problem::Problem, starts::Vector{PermutationEncoding}, steps::Int, tabuLength::Int, neigborhoodSizes::Vector{Int}; fast::Bool = false, improvements::Vector{String} = String[], type::String = "", threading::Symbol = :outer, distributed::Bool = false)
	sf(jobs) = computeTimeLazyReturn(jobs, problem, Val{false}(), !fast)
	sf2(jobs) = computeTimeLazyReturn(jobs, problem, Val{false}(), true)

	hybridSettings = HybridTabuSettings3(steps, tabuLength, neigborhoodSizes)

	outerThreading = threading ∈ (:outer, :both)
	innerThreading = threading ∈ (:inner, :both)
	mapFunc = outerThreading ? distributed ? pmap : ThreadsX.map : map

	ress = mapFunc(1:length(starts)) do i
		println("Start $i")
		solution = hybridTabuSearch(hybridSettings, sf, deepcopy(starts[i]), false, threaded = Val(innerThreading))
		println("End $i")
		solution
	end
	results = map(starts, ress) do st, sol
		TabuResult(
			st.permutation,
			sol.solution.permutation,
			argmin(get(sol.history)[2])
		)
	end

	return OtherResult(
		HYBRID3_TYPE,
		HybridExperiment3(
			!fast,
			1,
			steps,
			tabuLength,
			neigborhoodSizes,
			Set(improvements),
			type,
			results
		)
	)
end

function runHybrid13(problem::Problem, starts::Vector{PermutationEncoding}, tabuSteps::Int, annealingSteps::Int, restarts::Int, tabuLength::Int, neigborhoodSizes::Vector{Int}, annealingTemp::Float64, annealingPower::Float64 = (-annealingTemp * log(10^-3))^(-1 / (annealingSteps)); fast::Bool = false, improvements::Vector{String} = String[], type::String = "", threading::Symbol = :outer, distributed::Bool = false)
	sf(jobs) = computeTimeLazyReturn(jobs, problem, Val{false}(), !fast)
	sf2(jobs) = computeTimeLazyReturn(jobs, problem, Val{false}(), true)

	annealingSettings = AnnealingSettings(annealingSteps, false, 1, annealingTemp, it -> it * annealingPower, (old, new, threshold) -> rand() < exp((old - new) / threshold))
	hybridSettings = HybridTabuSettings13(tabuSteps, tabuLength, neigborhoodSizes, annealingSettings, (), restarts)

	outerThreading = threading ∈ (:outer, :both)
	innerThreading = threading ∈ (:inner, :both)
	mapFunc = outerThreading ? distributed ? pmap : ThreadsX.map : map

	ress = mapFunc(1:length(starts)) do i
		println("Start $i")
		solution = hybridTabuSearch(hybridSettings, sf, deepcopy(starts[i]), false, threaded = Val(innerThreading))
		println("End $i")
		solution
	end
	results = map(starts, ress) do st, sol
		TabuResult(
			st.permutation,
			sol.solution.permutation,
			argmin(get(sol.history)[2])
		)
	end

	return OtherResult(
		HYBRID13_TYPE,
		HybridExperiment13(
			!fast,
			1,
			tabuSteps,
			tabuLength,
			neigborhoodSizes,
			annealingSteps,
			1,
			annealingTemp,
			annealingPower,
			restarts,
			Set(improvements),
			type,
			results
		)
	)
end