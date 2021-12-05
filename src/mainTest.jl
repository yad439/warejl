include("mainAuxiliary.jl");
include("utility.jl");
include("auxiliary.jl")
include("tabu.jl");
include("local.jl");
include("annealing.jl");
include("hybridTabu.jl");
include("realDataUtility.jl");
include("linear.jl");
include("extendedRandoms.jl");
include("simlpeHeuristic.jl");
include("plots.jl");
include("experimentUtils.jl");
include("json.jl");

using Random
using Printf
using DelimitedFiles

using DataFrames
using CSV
using ThreadsX
using JuMP
using JSON
##
results = fromJson(Vector{ProblemInstance}, JSON.parsefile("exp/results.json"))
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
sol = computeTimeLazyReturn(rand(sample1), problem, Val(true))
T = sol.schedule.carTasks |> ffilter(e -> e.isAdd) |> fmap(e -> e.time) |> unique |> length
# T=max(T,problem.jobCount)
M = sol.time
##
exactModel = buildModel(problem, ASSIGNMENT_ONLY_SHARED, NO_CARS)
exactRes = runModel(exactModel, 30 * 60) .+ problem.carTravelTime
##
exactModel = buildModel(problem, ORDER_FIRST, DELIVER_ONLY)
exactRes = runModel(exactModel, 30 * 60)
##
exactModel = buildModel(problem, ORDER_FIRST, BUFFER_ONLY)
exactRes = runModel(exactModel, 30 * 60)
##
exactModel = buildModel(problem, ORDER_FIRST_STRICT, BUFFER_ONLY)
exactRes = runModel(exactModel, 30 * 60) .+ problem.carTravelTime
##
exactModel = buildModel(problem, ORDER_FIRST_STRICT, SEPARATE_EVENTS, T, M)
exactRes = runModel(exactModel, 30 * 60)
##
exactModel = buildModel(problem, ORDER_FIRST_STRICT, SHARED_EVENTS, T, M)
exactRes = runModel(exactModel, 10)
##
exactModel = buildModel(problem, ORDER_FIRST_STRICT, SHARED_EVENTS_QUAD, T, M)
exactRes = runModel(exactModel, 10)
##
exactRes[1] + problem.carTravelTime, exactRes[2] + problem.carTravelTime
##
st1 = rand(sample1)
st2 = rand(sample2);
##
st3 = problem.itemsNeeded |> jobDistance |> likehoodBased |> PermutationEncoding;
st4 = PermutationEncoding(likehoodBased(jobDistance(getfield(problem, :itemsNeeded)), argmin([sf(PermutationEncoding(likehoodBased(jobDistance(getfield(problem, :itemsNeeded)), i))) for i = 1:getfield(problem, :jobCount)])));
##
dist = jobDistance(problem.itemsNeeded)
# tabuSettings=TabuSearchSettings(700,600,1500)
# tabuSettings=TabuSearchSettings3(1000,600,500,200,20)
rdm = PermutationRandomIterable(problem.jobCount, 100, 0.5, jobDistance(problem.itemsNeeded))
tabuSettings = TabuSearchSettings4(1000, 100, (_, cd) -> randomChangeIterator(st1, 100, cd))
tabuSettings = TabuSearchSettings4(1000, 100, rdm)
localSettings = LocalSearchSettings(changeIterator(st1), true)
dif = maxDif(st1, sf)
# steps=round(Int,-log(0.99999,-2dif*log(10^-3))*1.5)
# α=(-dif*log(p))^(-1/10^6)
steps = 10^6
same = 1
power = (-2dif * log(10^-3))^(-1 / (steps / same))
annealingSettings = AnnealingSettings(steps, true, 1, 2dif, it -> it * 0.99999, (old, new, threshold) -> rand() < exp((old - new) / threshold))
annealingSettings = AnnealingSettings2(steps, false, same, 2dif, it -> it * power, (old, new, threshold) -> rand() < exp((old - new) / threshold), jobs -> controlledPermutationRandom(jobs, 0.5, dist))

localRes1 = modularLocalSearch(localSettings, sf, deepcopy(st1))
tabuRes1 = modularTabuSearch5(tabuSettings, sf, deepcopy(st1))
annealingRes = modularAnnealing(annealingSettings, sf, deepcopy(st1))
##
tabuSettings = TabuSearchSettings(200, 60, 2 * 27^2)
annealingSettings = AnnealingSettings(200, false, 1, 500, it -> it * 0.99999, (old, new, threshold) -> rand() < exp((old - new) / threshold))
hybridSettings = HybridTabuSettings1(tabuSettings, annealingSettings, 5)
res = hybridTabuSearch(hybridSettings, sf, deepcopy(st1), true)
##
hybridSettings = HybridTabuSettings2(100, 60, 2 * 27^2, 5, 100, 10)
res = hybridTabuSearch(hybridSettings, sf, deepcopy(st1), true)
##
tmap = Threads.nthreads() > 1 ? (f, x) -> ThreadsX.map(f, 10 ÷ Threads.nthreads(), x) : map
##
df = CSV.File("exp/tabuRes.tsv") |> DataFrame
##
CSV.write("exp/tabuRes.tsv", df, delim = '\t')
##
rest = tmap(1:10) do _
	modularTabuSearch5(tabuSettings, sf, rand(sample1)).score
end
##
resa = map(1:10) do _
	st = rand(sample1)
	modularAnnealing(annealingSettings, sf, st).score
end
##
resl = map(1:10) do _
	modularLocalSearch(localSettings, sf, rand(sample1)).score
end
##
println(minimum(rest), ' ', maximum(rest), ' ', mean(rest))
println(minimum(resa), ' ', maximum(resa), ' ', mean(resa))
##
starts = rand(sample1, 10);
starts = fill(st4, 10)
starts = [PermutationEncoding(likehoodBased(jobDistance(problem.itemsNeeded), rand(1:problem.jobCount))) for _ = 1:10]
##
ress = ThreadsX.map(1:10) do i
	println("Start $i")
	sc = modularTabuSearch5(tabuSettings, sf, deepcopy(starts[i]), i == 1).score
	# ProgressMeter.next!(prog)
	println("End $i")
	sc
end
push!(df, (20, 4, "A", missing, problem.jobCount, machineCount, carCount, bufferSize, false, 5, tabuSettings.searchTries, tabuSettings.tabuSize, 1458, minimum(ress), maximum(ress), mean(ress)))
println((minimum(ress), maximum(ress), mean(ress)))
##
baseIter = 1500
tabuSize = 300
neighSize = 2000
tabuSettings = TabuSearchSettings(baseIter, tabuSize, neighSize)
# rdm=PermutationRandomIterable(problem.jobCount,neighSize,0.5,jobDistance(problem.itemsNeeded))
# tabuSettings=TabuSearchSettings4(baseIter,tabuSize,rdm)
ress2 = progress_map(mapfun = ThreadsX.map, 1:10) do i
	# println("Start $i")
	sc = modularTabuSearch5(tabuSettings, sf, deepcopy(starts[i]), i == 1)
	# ProgressMeter.next!(prog)
	# println("End $i")
	sc.score, length(sc.history)
end
ress = map(first, ress2)
iters = map(secondElement, ress2)
push!(df, (50, 1, "A", missing, problem.jobCount, machineCount, carCount, bufferSize, true, 5, tabuSettings.searchTries, tabuSettings.tabuSize, neighSize, 0.5, "bestStart", minimum(ress), maximum(ress), mean(ress), minimum(iters), maximum(iters), mean(iters)))
##
sol = computeTimeLazyReturn(st1, problem, Val(true));
##
sol = computeTimeLazyReturn(annealingRes.solution, problem, Val(true));
##
exactModel = buildModel(problem, ORDER_FIRST_STRICT, SHARED_EVENTS)
setStartValues(exactModel, sol.schedule, problem)
exactRes = runModel(exactModel, 10)
##
cars = normalizeHistory(sol[3], problem.carTravelTime)
pl1 = gantt(sol[1], problem.jobLengths, false, string.(collect.(problem.itemsNeeded)), bw = false)
pl2 = plotDetailedCarUsage(cars, problem.carTravelTime, problem.carCount, (0, sol[2]), bw = false, text = false)
pl3 = plotDetailedBufferUsage(cars, problem.carTravelTime, problem.bufferSize, (0, sol[2]), bw = false)
plr = plot(pl1, pl3, pl2, layout = (3, 1), size = (640, 360))
##
res = progress_map(prm -> (computeTimeLazyReturn(prm, problem, Val(false), false), computeTimeLazyReturn(prm, problem, Val(false), true)), rand(sample1, 1_000_000))
res2 = map(r -> r[1] / r[2], res)
println((maximum(res2), minimum(res2), mean(res2)))
mn1 = argmin(map(first, res))
mn2 = argmin(map(secondElement, res))
println(mn1 == mn2)
println((res[mn1], res[mn2]))
##
prob = Problem(9, 3, 2, 2, 8, 3, [10, 2, 8, 5, 6, 6, 4, 2, 1], BitSet.([[1], [2], [2], [3], [4], [5], [6], [6, 7], [6, 7, 8]]))
@assert isValid(prob)
##
model = buildModel(prob, ORDER_FIRST_STRICT, SHARED_EVENTS, 12, 20)
addItems = model.inner[:addItems]
removeItems = model.inner[:removeItems]
@constraint(model.inner, [τ = 1:12], sum(addItems[τ, :]) ≥ sum(removeItems[τ, :]))
res = runModel(model, 60 * 60)
##
#=
res = minimum(allPermutations(prob.jobCount)) do perm
	enc = PermutationEncoding(perm)
	computeTimeLazyReturn(enc, prob, Val(false), true)
end
=#
##
res = nothing
score = 100
for _ = 1:2factorial(9)
	enc = PermutationEncoding(shuffle(1:9))
	sc = computeTimeLazyReturn(enc, prob, Val(false), true)
	if sc < score
		global score = sc
		global res = enc
	end
end
##
sol, = computeTimeLazyReturn(PermutationEncoding(1:9), prob, Val(true))
sol2 = improveSolution(sol, prob)
validate(sol2, prob)
##
sol, = computeTimeLazyReturn(st1, problem, Val(true))
sol2 = improveSolution(sol, problem)
validate(sol2, problem)
##
toJson("out/problem.json", problem)
##
sf2 = let problem = problem
	jobs -> computeTimeBufferOnly(jobs, problem)
end
##
starts = rand(sample1, 100000)
orig = @time map(sf, starts)
buffer = @time map(sf2, starts)
rat = orig ./ buffer
##
df = CSV.File("exp/annRes.tsv") |> DataFrame
##
CSV.write("exp/annRes.tsv", df, delim = '\t')
##
starts = fill(st4, 10)
dif = maxDif(st4, sf)
dyn = false
same = 1
steps = 10^6
power = (-2dif * log(10^-3))^(-1 / (steps / same))
annealingSettings = AnnealingSettings(steps, dyn, same, 2dif, it -> it * power, (old, new, threshold) -> rand() < exp((old - new) / threshold))
ress = ThreadsX.map(1:10) do i
	println("Start $i")
	sc = modularAnnealing(annealingSettings, sf, deepcopy(starts[i]), false).score
	# ProgressMeter.next!(prog)
	println("End $i")
	sc
end
push!(df, (100, 1, "A", missing, problem.jobCount, machineCount, carCount, bufferSize, true, annealingSettings.searchTries, dyn, annealingSettings.sameTemperatureTries, annealingSettings.startTheshold, power, 0.5, "bestStart", minimum(ress), maximum(ress), mean(ress)))
##
@time for change ∈ changeIterator(st1)
	restore = change!(st1, change)
	val = sf(st1)
	change!(st1, restore)
end
##
sols = rand(sample1, 10^5)
@time foreach(sf, sols)
@time foreach(sf2, sols)
##
df = CSV.File("exp/annRes.tsv") |> DataFrame
df2 = df[[6:10; 25:25; 111:111; 26:29], :]
df2 = df[[11:17; 30:34], :]
df2 = df[[18:24; 113:113; 112:112; 35:39], :]
theme(:dark)
berr = (df2[:, :mean] - df2[:, :best])
werr = (df2[:, :worst] - df2[:, :mean])
err = zip(berr, werr) |> collect
plot(df2[:, :sameTemperature], df2[:, :mean], xscale = :log10, marker = :circle, series_annotations = string.(df2[:, :sameTemperature]), yerror = err)
plot(df2[:, :sameTemperature], df2[:, :mean], xscale = :log10, marker = :circle, series_annotations = string.(df2[:, :sameTemperature]), label = false)
plot(df2[:, :sameTemperature], df2[:, :mean], xscale = :log10, marker = :circle, label = false, yerror = err)
plt = plot(
	df2[:, :sameTemperature],
	df2[:, :mean],
	xscale = :log10,
	marker = :circle,
	label = false,
	xlabel = "Iterations at the same temperature",
	ylabel = "Mean schedule length",
	# annotations=tuple.(df2[:,:sameTemperature],df2[:,:mean] .+ 1,string.(df2[:,:sameTemperature])),
	xticks = setdiff(df2[:, :sameTemperature], [5000, 20000, 80000]),
	xformatter = x -> true ? round(Int, x) : @sprintf("%.0e", x),
	# xtickfontsize=6,
	# palette=:grays,
	size = (600, 300)
)
# savefig(plt,"out/sameTemp_form_27.svg")
##
df = CSV.File("exp/tabuRes.tsv") |> DataFrame
df2 = df[22:28, :]
df2 = df[29:36, :]
df2 = df[46:50, :]
theme(:dark)
berr = (df2[:, :mean] - df2[:, :best])
werr = (df2[:, :worst] - df2[:, :mean])
err = zip(berr, werr) |> collect
plot(df2[:, :tabuSize], df2[:, :mean], xscale = :log10, xlabel = "l", ylabel = "Cmax", yerror = err)
plot(df2[:, :tabuSize], df2[:, :mean], xscale = :log10, xlabel = "l", ylabel = "Cmax", series_annotations = string.(df2[:, :tabuSize]))
##
ress = progress_map(mapfun = ThreadsX.map, 1:1_000_000) do _
	st = rand(sample1)
	sf(st), sf2(st)
end
rat = secondElement.(ress) ./ first.(ress)
##
ress1 = readdlm("out/random_100_1.tsv")
ress2 = readdlm("out/random_500_1.tsv")
rat1 = ress1[:, 2] ./ ress1[:, 1]
rat2 = ress2[:, 2] ./ ress2[:, 1]
##
plt1 = histogram(rat1, label = false, normalize = :pdf, xlabel = "f'(s)/f(s)")
plt2 = histogram(rat2, label = false, normalize = :pdf, xlabel = "f'(s)/f(s)")
plt = plot(plt1, plt2, size = (800, 480))
savefig(plt, "out/hist_alt_double.svg")
##
limitCounter = Counter(10)
probSize = 50
probNum = 2
machineCount = 6
carCount = 20
bufferSize = 6
problem = Problem(parseRealData("res/benchmark - automatic warehouse", probSize, probNum), machineCount, carCount, bufferSize, box -> box.lineType == "A" && !isempty(box.items) && limitCounter())
@assert bufferSize ≥ maximum(length, problem.itemsNeeded)
@assert isValid(problem)
sf = let problem = problem
	jobs -> computeTimeLazyReturn(jobs, problem, Val(false), true)
end
sample1 = EncodingSample{PermutationEncoding}(problem.jobCount, problem.machineCount)
# st1=rand(sample1)
st1 = PermutationEncoding([7, 9, 4, 10, 3, 5, 1, 2, 8, 6])
##
sol = computeTimeLazyReturn(st1, problem, Val(true))
annealingSettings = AnnealingSettings(10^6, true, 1, 1000, it -> it * 0.99999, (old, new, threshold) -> rand() < exp((old - new) / threshold))
sol = computeTimeLazyReturn(modularAnnealing(annealingSettings, sf, deepcopy(st1)).solution, problem, Val(true))
##
# theme(:binary)
cars = normalizeHistory(sol[3], problem.carTravelTime)
fnt = 8
# pl1=gantt(sol[1],problem.jobLengths,false,string.(collect.(problem.itemsNeeded)),bw=false)
pl1 = plot(xlims = (0, :auto), ylabel = "Machines")
jobs = sol[1]
useLabel = false
jobLengths = problem.jobLengths
bw = false
txt = string.(collect.(problem.itemsNeeded))
for i = 1:length(jobLengths)
	job = GanttJob(jobs.assignment[i], jobs.times[i], jobLengths[i])
	cent = center(job)
	if bw
		plot!(pl1, job, label = (useLabel ? "job $i" : nothing), annotations = (text ≢ nothing ? (cent..., Plots.text(txt[i], fnt)) : nothing), fillcolor = :lightgrey)
	else
		plot!(pl1, job, label = (useLabel ? "job $i" : nothing), annotations = (text ≢ nothing ? (cent..., Plots.text(txt[i], fnt)) : nothing), fillalpha = (bw ? 0 : 1))
	end
end

# pl2=plotDetailedCarUsage(cars,problem.carTravelTime,problem.carCount,(0,sol[2]),bw=false,text=false)
carNumber = problem.carCount
carHistory = cars
carTravelTime = problem.carTravelTime
# bw=false
txt = false
maxTime = zeros(carNumber)
jobs = map(carHistory) do event
		   map(event.items) do item
			   car = findfirst(≤(event.time), maxTime)
			   job = GanttJob(car, event.time, carTravelTime)
			   maxTime[car] = event.time + carTravelTime
			   job, item
		   end
	   end |> Iterators.flatten |> collect
pl2 = plot(label = false, xlims = (0, sol[2]), ylabel = "Robots")
adds = filter(job -> job[2][2], jobs)
removes = filter(job -> !job[2][2], jobs)
addsShapes = map(toShape ∘ first, adds)
addsAnnotations = map(job -> (center(job[1])..., Plots.text(string(job[2][1]), fnt)), adds)
removesShapes = map(toShape ∘ first, removes)
removesAnnotations = map(job -> (center(job[1])..., Plots.text(string(job[2][1]), fnt)), removes)
for i ∈ eachindex(addsShapes)
	if bw
		plot!(pl2, addsShapes[i], annotations = (txt ? addsAnnotations[i] : []), label = false, fillcolor = :grey)
	else
		plot!(pl2, addsShapes[i], annotations = (txt ? addsAnnotations[i] : []), label = false, fillalpha = (bw ? 0 : 1), fillcolor = theme_palette(:default)[1])
	end
end
for i ∈ eachindex(removesShapes)
	if bw
		plot!(pl2, removesShapes[i], annotations = (txt ? removesAnnotations[i] : []), label = false, fillcolor = :lightgrey)
	else
		plot!(pl2, removesShapes[i], annotations = (txt ? removesAnnotations[i] : []), label = false, fillalpha = (bw ? 0 : 1), fillcolor = theme_palette(:default)[2])
	end
end

# pl3=plotDetailedBufferUsage(cars,problem.carTravelTime,problem.bufferSize,(0,sol[2]),bw=false)
itemsInBuffer = Tuple{Int,Int,Int}[]
for event ∈ carHistory
	for item ∈ event.items
		if item[2]
			upcoming = filter(it -> it.time > event.time + carTravelTime, carHistory)
			endEvent = findfirst(ev -> ev.items ∋ (item[1], false), upcoming)
			endTime = endEvent ≢ nothing ? upcoming[endEvent].time : sol[2]
			push!(itemsInBuffer, (item[1], event.time + carTravelTime, endTime))
		end
	end
end
maxTime = zeros(bufferSize)
jobs = map(itemsInBuffer) do item
	car = findfirst(≤(item[2]), maxTime)
	job = GanttJob(car, item[2], item[3] - item[2])
	maxTime[car] = item[3]
	job, item[1]
end
pl3 = plot(label = false, xlims = (0, sol[2]), ylabel = "Buffer")
if bw
	foreach(job -> plot!(pl3, job[1], label = false, annotations = (center(job[1])..., Plots.text(string(job[2]), fnt)), fillcolor = :lightgrey), jobs)
else
	foreach(job -> plot!(pl3, job[1], label = false, annotations = (center(job[1])..., Plots.text(string(job[2]), fnt)), fillalpha = (bw ? 0 : 1)), jobs)
end

plr = plot(pl1, pl3, pl2, layout = (3, 1), size = (720, 480), xlabel = "Time")
##
resFile = "exp/results.json"
results = fromJson(Vector{ProblemInstance}, JSON.parsefile(resFile))
open(resFile, "w") do file
	JSON.print(file, results, 4)
end;
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
df = CSV.File("exp/tabuRes.tsv") |> DataFrame
for ins ∈ results
	prob = instanceToProblem(ins)
	for res ∈ ins.tabuResults
		if res.type == "count" || res.type == "itemCount"
			sols = [computeTimeLazyReturn(PermutationEncoding(result.solution), prob, Val(false)) for result ∈ res.results]
			itrs = [result.foundIteration for result ∈ res.results]
			push!(df, (
				ins.problemSize,
				ins.problemNumber,
				join(ins.lineTypes),
				ins.boxLimit,
				prob.jobCount,
				ins.machineCount,
				ins.carCount,
				ins.bufferSize,
				res.sortReturns,
				res.algorithmType,
				res.baseIterations,
				res.tabuSize,
				res.neigborhoodSize,
				res.moveProbability,
				join(res.other, "_"),
				minimum(sols),
				maximum(sols),
				mean(sols),
				minimum(itrs),
				maximum(itrs),
				mean(itrs)
			))
		end
	end
end
##
group1 = [1:9; 20:23; 31:33; 43:43]
group2 = [11:19; 24:27; 37:39]
group3 = [30:30; 44:49]
groups = [group1, group2, group3]
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
errs = map(results[collect(Iterators.flatten(groups))]) do instance
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
	(mean(annRess[bestAnn]) - bestLB) / bestLB, (mean(tabuRess[bestTabu]) - bestLB) / bestLB
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
oldRes = CSV.File("exp/results.tsv") |> DataFrame
##
for inst ∈ results[group3]
	for row ∈ eachrow(oldRes)
		if inst.problemSize == row.problemSize && inst.problemNumber == row.problemNum && inst.machineCount == row.machineCount && inst.carCount == row.carCount && inst.bufferSize == row.bufferSize
			if inst.modelResults.fullModel ≡ nothing && row.linSol ≢ missing && row.linLB ≢ missing
				inst.modelResults.fullModel = (solution = row.linSol, bound = row.linLB)
			end
			if inst.modelResults.bufferOnly ≡ nothing && row.bLinSol ≢ missing && row.bLinLB ≢ missing
				inst.modelResults.bufferOnly = (solution = row.bLinSol, bound = row.bLinLB)
			end
			if inst.modelResults.transportOnly ≡ nothing && row.dLinSol ≢ missing && row.dLinLB ≢ missing
				inst.modelResults.transportOnly = (solution = row.dLinSol, bound = row.dLinLB)
			end
			if inst.modelResults.assignmentOnly ≡ nothing && row.sLinSol ≢ missing && row.sLinLB ≢ missing
				inst.modelResults.assignmentOnly = (solution = row.sLinSol, bound = row.sLinLB)
			end
		end
	end
end
##
for inst ∈ results
	inst["otherResults"] = []
	inst["skipZeros"] = inst["problemSize"] ≥ 50 && !(
	# (instance.problemSize == 200 && instance.problemNumber == 6)
		(inst["problemSize"] == 100 && inst["problemNumber"] == 1 && inst["machineCount"] == 8 && inst["carCount"] == 20 && inst["bufferSize"] == 5)
	)
end