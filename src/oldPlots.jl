
#=include("annealing.jl")
include("randomUtils.jl")
include("realDataUtility.jl")
include("scoreFunctions.jl")
include("plots.jl")
using DataFrames, CSV, Plots
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
	xformatter = x -> round(Int, x),
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
# ress1 = readdlm("out/random_100_1.tsv")
# ress2 = readdlm("out/random_500_1.tsv")
# rat1 = ress1[:, 2] ./ ress1[:, 1]
# rat2 = ress2[:, 2] ./ ress2[:, 1]
##
# plt1 = histogram(rat1, label = false, normalize = :pdf, xlabel = "f'(s)/f(s)")
# plt2 = histogram(rat2, label = false, normalize = :pdf, xlabel = "f'(s)/f(s)")
# plt = plot(plt1, plt2, size = (800, 480))
# savefig(plt, "out/hist_alt_double.svg")
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

plr = plot(pl1, pl3, pl2, layout = (3, 1), size = (720, 480), xlabel = "Time")=#