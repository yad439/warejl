include("mainAuxiliary.jl");
include("tabu.jl");
include("annealing.jl");
include("realDataUtility.jl");
include("linear.jl");
include("extendedRandoms.jl");
include("simlpeHeuristic.jl");
include("utility.jl");
include("experimentUtils.jl")
include("json.jl")

using Random
import JSON

##
#=
let
	resFile = "exp/results.json"

	probSize = 20
	# probNum = 1
	machineCount = 4
	carCount = 40
	bufferSize = 8

	results = fromJson(Vector{ProblemInstance}, JSON.parsefile(resFile))
	try
		for probNum = [4] # [1, 4, 8] [2, 7, 10]
		# for _ = [0]
			println("Instance ", probNum)
			let
				# bufferSize = problemStats(probSize, probNum, ['A']).maxItems

				instance = findInstance(
									results,probSize,probNum,['A'],
									missing,machineCount,carCount,bufferSize
							)
				if instance ≡ nothing
					instance = createInstance(
									probSize,probNum,['A'],
									missing,machineCount,carCount,bufferSize
							)
					push!(results, instance)
				end
				instance::ProblemInstance

				problem = try
					instanceToProblem(instance, skipZeros=false)
				catch e
					println(stderr, "Can't parse problem ", probNum)
					continue
				end
				problem::Problem
				if !isValid(problem)
					println(stderr, "Problem ", probNum, " is invalid!")
					continue
				end

				# if instance.modelResults.fullModel !== nothing
				#	continue
				# end

				# res = runLinear(problem, ORDER_FIRST_STRICT, SHARED_EVENTS, timeLimit=60 * 60, startSolution=true)
				# instance.modelResults.fullModel = (solution = res[1], bound = res[2])
				# if !ismissing(res[1])
				#	instance.modelResults.fullModel = (solution = res[1], bound = res[2])
				# end

				# res = runLinear(problem, ORDER_FIRST_STRICT, BUFFER_ONLY, timeLimit=60 * 60)
				# instance.modelResults.bufferOnly = (solution = res[1], bound = res[2])

				# res = runLinear(problem, ASSIGNMENT_ONLY_SHARED, NO_CARS, timeLimit=60 * 60)
				# instance.modelResults.assignmentOnly = (solution = res[1], bound = res[2])

				samp = EncodingSample{PermutationEncoding}(problem.jobCount, problem.machineCount)
				sf(jobs) = computeTimeLazyReturn(jobs, problem, Val(false), true)
				starts = rand(samp, 10)
				# goodStarts = [PermutationEncoding(likehoodBased(jobDistance(problem.itemsNeeded), i)) for i = 1:problem.jobCount]
				# bestInd = argmin(map(sf, goodStarts))
				# bestStart = goodStarts[bestInd]
				# starts = fill(bestStart, 10)

				dif = maxDif(starts[1], sf)
				res = runAnnealing(problem, starts, 10^7, problem.jobCount^2, dif / 2, uniform=true, fast=false)
				push!(instance.annealingResults, res)

				res = runTabu(problem, starts, 1000, 3 * problem.jobCount, min(2 * problem.jobCount^2, 5000))
				# res = runTabu(problem, starts, 2000, 600, 5000, distribution="item",fast=true, improvements=["itemBased","bestStart","fast"])
				push!(instance.tabuResults, res)
			end
			GC.gc()
		end
	finally
		open(resFile, "w") do file
			toJson(file, results);
		end;
	end
end
GC.gc()
=#

# let
# 	instance = createInstance(20,4,['A'],missing,6,30,6)
# 	problem=instanceToProblem(instance)
# 	samp = EncodingSample{PermutationEncoding}(problem.jobCount, problem.machineCount)
# 	sf(jobs) = computeTimeLazyReturn(jobs, problem, Val(false), true)
# 	# annealingSettings=AnnealingSettings(10^7,false,1,1000,it -> it * 0.9999990885007308, (old, new, threshold) -> rand() < exp((old - new) / threshold))
# 	# res=@timed modularAnnealing(annealingSettings,sf,rand(samp),false)
# 	tabuSettings = TabuSearchSettings(1000,4*27, 1458)
# 	res=@timed modularTabuSearch3(tabuSettings,sf,rand(samp),false)
# 	solution=res.value
# 	# tabuSettings = TabuSearchSettings(500, 60, 5000)
# 	# solution = modularTabuSearch5(tabuSettings, sf, rand(samp), true)
# 	println(solution.score,' ',res.time)
# end

#=
probSize = 200
probNum = 6
machineCount = 4
carCount = 30
bufferSize = 6
problem = Problem(parseRealData("res/benchmark - automatic warehouse", probSize, probNum), machineCount, carCount, bufferSize, box -> box.lineType == "A")
@assert isValid(problem)
@assert problem.bufferSize ≥ maximum(length, problem.itemsNeeded)
sf = let problem = problem
	jobs -> computeTimeLazyReturn(jobs, problem, Val(false), true)
end
sf2 = let problem = problem
	jobs -> computeTimeLazyReturn(jobs, problem, Val(false), false)
end
sample1 = EncodingSample{PermutationEncoding}(problem.jobCount, problem.machineCount)
sts=rand(sample1,10^3)
tabuSettings=TabuSearchSettings(100,100,100)
annealingSettings=AnnealingSettings(10^3,false,1,1000,it->it*0.999,(old,new,threshold)->rand()<exp((old-new)/threshold))
foreach(sf,sts)
foreach(sf2,sts)
modularTabuSearch5(tabuSettings,sf,deepcopy(sts[1]),false)
modularAnnealing(annealingSettings,sf,deepcopy(sts[1]),false)
modularTabuSearch5(tabuSettings,sf2,deepcopy(sts[1]),false)
modularAnnealing(annealingSettings,sf2,deepcopy(sts[1]),false)
sts=rand(sample1,10^6)
tabuSettings=TabuSearchSettings(1000,100,1000)
annealingSettings=AnnealingSettings(10^6,false,1,1000,it->it*0.99999,(old,new,threshold)->rand()<exp((old-new)/threshold))
println("Timing")
prog=Progress(6)
time0=(@timed foreach(sf,sts)).time/10^6
ProgressMeter.next!(prog)
time1=(@timed foreach(sf2,sts)).time/10^6
ProgressMeter.next!(prog)
res2=@timed modularTabuSearch5(tabuSettings,sf,deepcopy(sts[1]),false)
time2=res2.time/length(res2.value.history)/1000
ProgressMeter.next!(prog)
time3=(@timed modularAnnealing(annealingSettings,sf,deepcopy(sts[1]),false)).time/10^6
ProgressMeter.next!(prog)
res4=@timed modularTabuSearch5(tabuSettings,sf2,deepcopy(sts[1]),false)
time4=res4.time/length(res4.value.history)/1000
ProgressMeter.next!(prog)
time5=(@timed modularAnnealing(annealingSettings,sf2,deepcopy(sts[1]),false)).time/10^6
ProgressMeter.next!(prog)
ProgressMeter.finish!(prog)
println("$time0 $time2 $time3")
println("$time1 $time4 $time5")
df=CSV.File("exp/times.tsv")|>DataFrame
push!(df,(problem.jobCount,gethostname(),time0,time2,time3,time1,time4,time5))
CSV.write("exp/times.tsv",df,delim='\t')
=#

let
	results = fromJson(Vector{ProblemInstance}, JSON.parsefile("exp/results.json"))
	group1 = [1:9; 20:23; 31:33; 43:43]
	group2 = [11:19; 24:27; 37:39]
	group3 = [30:30; 44:49]
	groups = [group1, group2, group3]

	names = Set{String}()
	for instance ∈ results[collect(Iterators.flatten(groups))]
		GC.gc()
		problem = instanceToProblem(instance, skipZeros = instance.problemSize ≥ 50 && !(
		# (instance.problemSize == 200 && instance.problemNumber == 6)
			(instance.problemSize == 100 && instance.problemNumber == 1 && instance.machineCount == 8 && instance.carCount == 20 && instance.bufferSize == 5)
		))
		counter = findfirst(i -> "$(instance.problemSize)_$(instance.problemNumber)_$(problem.machineCount)_$(problem.carCount)_$(problem.bufferSize)_$i" ∉ names, 1:10)
		prefix = "$(instance.problemSize)_$(instance.problemNumber)_$(problem.machineCount)_$(problem.carCount)_$(problem.bufferSize)_$counter"
		push!(names, prefix)
		println(prefix)
		prefix = "out/models/" * prefix
		samp = EncodingSample{PermutationEncoding}(problem.jobCount, problem.machineCount)
		minS = let
			scoreFunction(sol) = computeTimeLazyReturn(PermutationEncoding(sol), problem, Val(false), true)
			solutions = Iterators.flatten((
				Iterators.flatten(Iterators.map(r -> Iterators.map(t -> t.solution, r.results), instance.annealingResults)),
				Iterators.flatten(Iterators.map(r -> Iterators.map(t -> t.solution, r.results), instance.tabuResults))
			)) |> collect
			best = argmin(map(scoreFunction, solutions))
			solutions[best]
		end
		sol = let s = computeTimeLazyReturn(rand(samp), problem, Val(true))
			(schedule = s.schedule, time = s.time)
		end
		sol2 = let s = computeTimeLazyReturn(PermutationEncoding(minS), problem, Val(true))
			(schedule = s.schedule, time = s.time)
		end
		T1 = sol.schedule.carTasks |> ffilter(e -> e.isAdd) |> fmap(e -> e.time) |> unique |> length
		T2 = sol2.schedule.carTasks |> ffilter(e -> e.isAdd) |> fmap(e -> e.time) |> unique |> length
		T = max(T1, T2)
		M = sol.time
		GC.gc()

		if problem.jobCount < 400 && !isfile(prefix * "_full.mps.bz2")
			model = buildModel(problem, ORDER_FIRST_STRICT, SHARED_EVENTS, T, M, optimizer = nothing)
			write_to_file(model.inner, prefix * "_full.mps.bz2")
			setStartValues(model, sol.schedule, problem)
			writeMIPStart(model.inner, prefix * "_full.mst")
			setStartValues(model, sol2.schedule, problem)
			writeMIPStart(model.inner, prefix * "_full_best.mst")
		end
		GC.gc()

		if problem.jobCount < 400 && !isfile(prefix * "_buffer.mps.bz2")
			model = buildModel(problem, ORDER_FIRST_STRICT, BUFFER_ONLY, T, M, optimizer = nothing)
			write_to_file(model.inner, prefix * "_buffer.mps.bz2")
		end
		GC.gc()

		if problem.jobCount < 400 && !isfile(prefix * "_deliver.mps.bz2")
			model = buildModel(problem, ORDER_FIRST_STRICT, DELIVER_ONLY, T, M, optimizer = nothing)
			write_to_file(model.inner, prefix * "_deliver.mps.bz2")
		end
		GC.gc()

		if !isfile(prefix * "_assign.mps.bz2")
			model = buildModel(problem, ASSIGNMENT_ONLY_SHARED, NO_CARS, T, M, optimizer = nothing)
			write_to_file(model.inner, prefix * "_assign.mps.bz2")
		end
	end
end