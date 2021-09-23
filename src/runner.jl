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
#=
let
	instance = createInstance(20,4,['A'],missing,6,30,6)
	problem=instanceToProblem(instance)
	samp = EncodingSample{PermutationEncoding}(problem.jobCount, problem.machineCount)
	sf(jobs) = computeTimeLazyReturn(jobs, problem, Val(false), true)
	tabuSettings = TabuSearchSettings(500, 60, 5000)
	solution = modularTabuSearch5(tabuSettings, sf, rand(samp), true)
	println(solution.score)
end
=#
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