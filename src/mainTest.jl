include("singleInclude.jl")
##
results = fromJson(Vector{ProblemInstance}, JSON.parsefile("exp/results.json"));
##
cnt = 0
function flt(box)
	if box.lineType != "A"
		return false
	end
	global cnt += 1
	if cnt <= 10
		return true
	else
		return false
	end
	return false
end
##
limitCounter = Counter(10)
probSize = 20
probNum = 4
machineCount = 6
carCount = 30
bufferSize = 6
problem = Problem(parseRealData("res/benchmark - automatic warehouse", probSize, probNum), machineCount, carCount, bufferSize, box -> box.lineType == "A")
# problem=Problem(parseRealData("res/benchmark - automatic warehouse",probSize,probNum),machineCount,carCount,bufferSize,box->box.lineType=="A" && !isempty(box.items) && limitCounter())
@assert bufferSize ≥ maximum(length, problem.itemsNeeded)
@assert isValid(problem)
sf = let problem = problem
	jobs -> computeTimeLazyReturn(jobs, problem, Val(false), true)
end
sf2 = let problem = problem
	jobs -> computeTimeLazyReturn(jobs, problem, Val(false), false)
end
sample1 = EncodingSample{PermutationEncoding}(problem.jobCount, problem.machineCount)
sample2 = EncodingSample{TwoVectorEncoding}(problem.jobCount, problem.machineCount);
##
tab = resultsToTable(results)
CSV.write("out/results.tsv", tab, delim = '\t')
##
tab2 = resultsToArtTable(results)
open(f -> show(f, MIME("text/latex"), sort(tab2, :jobCount)), "out/results.tex", "w")
##
ress = []
cnt = 1
for instance ∈ results
	prob = instanceToProblem(instance)
	println("Instance ", cnt)
	cnt += 1
	if prob.jobLengths ∋ 0
		println("invalid")
		continue
	end

	c2 = 1
	for exp ∈ instance.annealingResults
		println("annealing ", c2)
		c2 += 1
		for res ∈ exp.results
			perm = res.solution
			sol = computeTimeLazyReturn(PermutationEncoding(perm), prob, Val(true)).schedule
			sol2 = improveSolution(sol, prob)
			tm = maximum(i -> sol.times[i] + prob.jobLengths[i], 1:prob.jobCount)
			tm2 = maximum(i -> sol2.times[i] + prob.jobLengths[i], 1:prob.jobCount)
			push!(ress, (tm, tm2))
		end
	end
	c2 = 1
	for exp ∈ instance.tabuResults
		println("tabu ", c2)
		c2 += 1
		for res ∈ exp.results
			perm = res.solution
			sol = computeTimeLazyReturn(PermutationEncoding(perm), prob, Val(true)).schedule
			sol2 = improveSolution(sol, prob)
			tm = maximum(i -> sol.times[i] + prob.jobLengths[i], 1:prob.jobCount)
			tm2 = maximum(i -> sol2.times[i] + prob.jobLengths[i], 1:prob.jobCount)
			push!(ress, (tm, tm2))
		end
	end
end
count(r -> r[1] ≠ r[2], ress)
##
group1 = [1:9; 20:23; 31:33; 43:43]
group2 = [11:19; 24:27; 37:39]
group3 = [30:30; 44:49]
groups = [group1, group2, group3]
allExp = collect(Iterators.flatten(groups))
allSorted = [3, 13, 6, 7, 9, 16, 17, 19, 5, 15, 4, 14, 48, 49, 8, 18, 2, 12, 1, 11, 25, 22, 26, 23, 27, 21, 47, 24, 20, 45, 46, 33, 39, 38, 32, 37, 31, 30, 43, 44]
##
for gr = 1:3
	folder = "out/export/group$gr"
	mkpath(folder)
	names = Set{String}()
	open("$folder/results.tsv", "w") do mins
		for instance ∈ results[groups[gr]]
			problem = instanceToProblem(instance)
			scoreFunction(sol) = computeTimeLazyReturn(PermutationEncoding(sol), problem, Val(false), true)
			annRess = map(r -> map(t -> scoreFunction(t.solution), r.results), instance.annealingResults)
			tabuRess = map(r -> map(t -> scoreFunction(t.solution), r.results), instance.tabuResults)
			bestAnn = argmin(map(mean, annRess))
			bestTabu = argmin(map(mean, tabuRess))
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
			counter = findfirst(i -> "$(problem.jobCount)_$(problem.machineCount)_$(problem.carCount)_$(problem.bufferSize)_$i" ∉ names, 1:10)
			name = "$(problem.jobCount)_$(problem.machineCount)_$(problem.carCount)_$(problem.bufferSize)_$counter"
			push!(names, name)
			fld = "$folder/$name"
			mkpath(fld)
			open("$fld/data_$name.txt", "w") do file
				println(file, problem.jobCount, ' ', problem.machineCount, ' ', problem.carCount, ' ', problem.bufferSize, ' ', problem.itemCount, ' ', problem.carTravelTime)
				for p ∈ problem.jobLengths
					print(file, p, ' ')
				end
				println(file)
				for s ∈ problem.itemsNeeded
					for it ∈ s
						print(file, it, ' ')
					end
					println(file)
				end
			end
			write("$fld/tabu_$name.txt", join(tabuRess[bestTabu], ' '))
			write("$fld/annealing_$name.txt", join(annRess[bestAnn], ' '))
			println(mins, problem.jobCount, '\t', problem.machineCount, '\t', problem.carCount, '\t', problem.bufferSize, '\t', "$name.zip", '\t', min(minimum(minimum, annRess), minimum(minimum, tabuRess)), '\t', bestLB)
		end
	end
end
##
instance = createInstance(200, 6, ['A'], missing, 4, 30, 6)
problem = instanceToProblem(instance)
open("out/data_$(problem.jobCount).txt", "w") do file
	println(file, problem.jobCount, ' ', problem.machineCount, ' ', problem.carCount, ' ', problem.bufferSize, ' ', problem.itemCount, ' ', problem.carTravelTime)
	for p ∈ problem.jobLengths
		print(file, p, ' ')
	end
	println(file)
	for s ∈ problem.itemsNeeded
		print(file, length(s), ' ')
		for it ∈ s
			print(file, it, ' ')
		end
		println(file)
	end
end
##
errs = map(results[allSorted]) do instance
	problem = instanceToProblem(instance)
	scoreFunction(sol) = computeTimeLazyReturn(PermutationEncoding(sol), problem, Val(false), true)
	annRess = map(r -> map(t -> scoreFunction(t.solution), r.results), instance.annealingResults)
	tabuRess = map(r -> map(t -> scoreFunction(t.solution), r.results), instance.tabuResults)
	hybridRess = [[scoreFunction(sol.solution) for sol ∈ res.result.results] for res ∈ instance.otherResults if res.type == HYBRID13_TYPE]
	bestAnn = argmin(map(mean, annRess))
	bestTabu = argmin(map(mean, tabuRess))
	bestHybrid = argmin(map(mean, hybridRess))
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
	(mean(annRess[bestAnn]) - bestLB) / bestLB, (mean(tabuRess[bestTabu]) - bestLB) / bestLB, (mean(hybridRess[bestHybrid]) - bestLB) / bestLB
end
##
let results = results, groups = groups
	names = Set{String}()
	for instance ∈ results[collect(Iterators.flatten(groups))]
		GC.gc()
		problem = instanceToProblem(instance)
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
		T = sol.schedule.carTasks |> ffilter(e -> e.isAdd) |> fmap(e -> e.time) |> unique |> length
		M = sol.time
		GC.gc()

		model = read_from_file(prefix * "_full.mps")
		setStartValues(ModelWrapper(ORDER_FIRST_STRICT, SHARED_EVENTS, model), sol2.schedule, problem)
		writeMIPStart(model.inner, prefix * "_full_best.mst")

		# if problem.jobCount < 400 && !isfile(prefix * "_full.mps")
		# 	model = buildModel(problem, ORDER_FIRST_STRICT, SHARED_EVENTS, T, M, optimizer = nothing)
		# 	setStartValues(model, sol.schedule, problem)
		# 	write_to_file(model.inner, prefix * "_full.mps")
		# 	writeMIPStart(model.inner, prefix * "_full.mst")
		# end
		# GC.gc()

		# if problem.jobCount < 400 && !isfile(prefix * "_buffer.mps")
		# 	model = buildModel(problem, ORDER_FIRST_STRICT, BUFFER_ONLY, T, M, optimizer = nothing)
		# 	write_to_file(model.inner, prefix * "_buffer.mps")
		# end
		# GC.gc()

		# if problem.jobCount < 400 && !isfile(prefix * "_deliver.mps")
		# 	model = buildModel(problem, ORDER_FIRST_STRICT, DELIVER_ONLY, T, M, optimizer = nothing)
		# 	write_to_file(model.inner, prefix * "_deliver.mps")
		# end
		# GC.gc()

		# if !isfile(prefix * "_assign.mps")
		# 	model = buildModel(problem, ASSIGNMENT_ONLY_SHARED, NO_CARS, T, M, optimizer = nothing)
		# 	write_to_file(model.inner, prefix * "_assign.mps")
		# end
	end
end
##
rss = results[collect(Iterators.flatten(groups))]
df = DataFrame(
	id = collect(eachindex(rss)),
	size = map(it -> it.problemSize, rss),
	num = map(it -> it.problemNumber, rss),
	jobs = map(it -> instanceToProblem(it).jobCount, rss),
	machines = map(it -> it.machineCount, rss),
	cars = map(it -> it.carCount, rss),
	buffer = map(it -> it.bufferSize, rss),
	time = map(it -> instanceToProblem(it).carTravelTime, rss)
)
##
open("out/resultsN.tex","w") do file
	for row ∈ eachrow(tab2)
		join(file,row," & ")
		println(file,"\\\\")
	end
end