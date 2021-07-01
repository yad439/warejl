include("realDataUtility.jl");
include("linear.jl");
include("mainAuxiliary.jl");

using ThreadsX


const ModelResult = @NamedTuple{solution::Union{Float32,Missing},bound::Union{Float32,Missing}}

mutable struct ModelResults
	fullModel::Union{ModelResult,Nothing}
	bufferOnly::Union{ModelResult,Nothing}
	transportOnly::Union{ModelResult,Nothing}
	assignmentOnly::Union{ModelResult,Nothing}
end

struct TabuResult
	startSolution::Vector{UInt16}
	solution::Vector{UInt16}
	iterations::UInt16
end

struct TabuExperiment
	sortReturns::Bool
	algorithmType::UInt8
	baseIterations::UInt16
	tabuSize::UInt16
	neigborhoodSize::UInt16
	moveProbability::Float16
	other::Vector{String}
	type::String
	results::Vector{TabuResult}
end

struct AnnealingResult
	startSolution::Vector{UInt16}
	solution::Vector{UInt16}
	iterations::UInt32
end

struct AnnealingExperiment
	sortReturns::Bool
	iterationCount::UInt32
	dynamic::Bool
	sameTemperatureIterations::UInt32
	startThreshold::Float32
	power::Float64
	moveProbability::Float16
	other::Vector{String}
	type::String
	results::Vector{AnnealingResult}
end

struct ProblemInstance
	problemSize::UInt16
	problemNumber::UInt8
	lineTypes::Set{Char}
	boxLimit::Union{UInt16,Missing}
	machineCount::UInt8
	carCount::UInt8
	bufferSize::UInt8
	modelResults::ModelResults
	tabuResults::Vector{TabuExperiment}
	annealingResults::Vector{AnnealingExperiment}
end

createInstance(problemSize,problemNumber,lineTypes,boxLimit,machineCount,carCount,bufferSize)::ProblemInstance =
	ProblemInstance(
		problemSize,
		problemNumber,
		Set(lineTypes),
		boxLimit,
		machineCount,
		carCount,
		bufferSize,
		ModelResults(nothing, nothing, nothing, nothing),
		TabuExperiment[],
		AnnealingExperiment[]
	)

function findInstance(data, problemSize, problemNumber, lineTypes, boxLimit, machineCount, carCount, bufferSize)::Union{ProblemInstance,Nothing}
	lineTypeSet = Set(lineTypes)

	ind = findfirst(it ->
		it.problemSize == problemSize
		&& it.problemNumber == problemNumber
		&& it.lineTypes == lineTypeSet
		&& isequal(it.boxLimit, boxLimit)
		&& it.machineCount == machineCount
		&& it.carCount == carCount
		&& it.bufferSize == bufferSize
	,data)
	ind ≡ nothing ? nothing : data[ind]
end

function instanceToProblem(instance::ProblemInstance)::Problem
	limitCounter = instance.boxLimit ≢ missing ? Counter(instance.boxLimit) : () -> true
	Problem(
		parseRealData("res/benchmark - automatic warehouse", instance.problemSize, instance.problemNumber),
		instance.machineCount,
		instance.carCount,
		instance.bufferSize,
		box -> box.lineType[1] ∈ instance.lineTypes && !isempty(box.items)  && limitCounter()
	)
end

function problemStats(problemSize::Int, problemNum::Int, lineTypes::Vector{Char})::@NamedTuple{jobCount::Int,items::Int,maxItems::Int,travelTime::Int}
	lineTypesSet = Set(lineTypes)
	data = toModerateJobs(parseRealData("res/benchmark - automatic warehouse", problemSize, problemNum), box -> box.lineType[1] ∈ lineTypesSet && !isempty(box.items))
	(
		jobCount = length(data.lengths),
		items = maximum(maximum, data.itemsForJob),
		maxItems = maximum(length, data.itemsForJob),
		travelTime = data.carTravelTime
	)
end

function runLinear(problem::Problem, machineType::MachineModelType, carType::CarModelType;timeLimit::Int=0,startSolution::Union{Bool,PermutationEncoding}=false)
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

function runAnnealing(problem::Problem, starts::Vector{PermutationEncoding}, steps::Int, same::Int, temp::Float64;uniform::Bool=true,fast::Bool=false,improvements::Vector{String}=String[],type::String="")
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
				length(sol.history)
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
			improvements,
			type,
			results
		)
	end
	@assert false
	AnnealingExperiment(false, 0, false, 0, 0.0, 0.0, 0.0, String[], "", AnnealingResult[])
end

function fromJson(T, data)
	@assert isstructtype(T)
	fields = fieldnames(T)
	types = fieldtypes(T)
	arguments = broadcast((field, type) -> fromJson(type, data[string(field)]), fields, types)
	T(arguments...)
end
function fromJson(::Type{T}, data) where {T <: NamedTuple}
	fields = fieldnames(T)
	types = fieldtypes(T)
	arguments = broadcast((field, type) -> fromJson(type, data[string(field)]), fields, types)
	T(arguments)
end
fromJson(::Type{Union{T,Nothing}},data) where {T} = data ≡ nothing ? nothing : fromJson(T, data)
fromJson(::Type{Union{T,Missing}},data) where {T} = data ≡ nothing ? missing : fromJson(T, data)
fromJson(::Type{Vector{T}},data) where {T} = map(it -> fromJson(T, it), data)
fromJson(::Type{Set{T}},data) where {T} = Set(Iterators.map(it -> fromJson(T, it), data))
fromJson(::Type{T},data) where {T <: Number} = convert(T, data)
fromJson(::Type{String},data) = data
fromJson(::Type{Char},data) = (@assert(length(data) == 1);data[1])