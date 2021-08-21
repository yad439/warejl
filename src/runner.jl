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

let
	resFile = "exp/results.json"

	probSize = 100
	# probNum = 1
	machineCount = 16
	carCount = 30
	bufferSize = 8

	results = fromJson(Vector{ProblemInstance}, JSON.parsefile(resFile))
	try
		for probNum = [4, 8] # [1, 4, 8] [2, 7, 10]
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
					instanceToProblem(instance, skipZeros=true)
				catch e
					println(stderr, "Can't parse problem ", probNum)
					continue
				end
				problem::Problem
				if !isValid(problem)
					println(stderr, "Problem ", probNum, " is invalid!")
					continue
				end
				
				if instance.modelResults.bufferOnly !== nothing
					continue
				end

				# res = runLinear(problem, ORDER_FIRST_STRICT, SHARED_EVENTS, timeLimit=60 * 60, startSolution=true)
				# instance.modelResults.fullModel = (solution = res[1], bound = res[2])

				res = runLinear(problem, ORDER_FIRST_STRICT, BUFFER_ONLY, timeLimit=60 * 60)
				instance.modelResults.bufferOnly = (solution = res[1], bound = res[2])
				
				# res = runLinear(problem, ASSIGNMENT_ONLY_SHARED, NO_CARS, timeLimit=60 * 60)
				# instance.modelResults.assignmentOnly = (solution = res[1], bound = res[2])

				# samp = EncodingSample{PermutationEncoding}(problem.jobCount, problem.machineCount)
				# sf(jobs) = computeTimeLazyReturn(jobs, problem, Val(false), true)
				# starts = rand(samp, 10)
				# goodStarts = [PermutationEncoding(likehoodBased(jobDistance(problem.itemsNeeded), i)) for i = 1:problem.jobCount]
				# bestInd = argmin(map(sf, goodStarts))
				# bestStart = goodStarts[bestInd]
				# starts = fill(bestStart, 10)


				# dif = maxDif(starts[1], sf)
				# res = runAnnealing(problem, starts, 2*10^6, problem.jobCount^2, dif / 2)
				# push!(instance.annealingResults, res)

				# res = runTabu(problem, starts, 1000, problem.jobCount, min(2 * problem.jobCount^2,5000),improvements=["bestStart"])
				# res = runTabu(problem, starts, 2000, 600, 1000, distribution="item_count", improvements=["itemCountBased"], type="itemCount")
				# push!(instance.tabuResults, res)
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