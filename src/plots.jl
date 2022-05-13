#=using Plots
import Plots.center

include("problemStructures.jl")

struct GanttJob
	assignment::Int
	startTime::Int
	duration::Int
end

@recipe plotGanttJob(::Type{GanttJob}, job::GanttJob) = toShape(job)
toShape(job::GanttJob) = Shape([
	(job.startTime, job.assignment - 1),
	(job.startTime, job.assignment),
	(job.startTime + job.duration, job.assignment),
	(job.startTime + job.duration, job.assignment - 1)
])
center(job::GanttJob) = (job.startTime + job.duration / 2, job.assignment - 0.5)

@recipe function scheduleToGantt(jobs::Schedule, jobLengths)
	n = length(jobs.assignment)
	@assert length(jobs.times) == n
	@assert length(jobLengths) == n
	shapes = [
		GanttJob(jobs.assignment[i], jobs.times[i], jobLengths[i])
		for i = 1:n]
	# label:=["job $i" for i=1:n]
	shapes
end

function gantt(jobs, jobLengths, useLabel = length(jobLengths) ≤ 10, text = nothing; bw = false)
	pl = plot(xlims = (0, :auto))
	for i = 1:length(jobLengths)
		job = GanttJob(jobs.assignment[i], jobs.times[i], jobLengths[i])
		cent = center(job)
		plot!(pl, job, label = (useLabel ? "job $i" : nothing), annotations = (text ≢ nothing ? (cent..., Plots.text(text[i], 8)) : nothing), fillalpha = (bw ? 0 : 1))
	end
	pl
end

function plotCarUsage(carHistory, carTravelTime, xlims = :auto)
	endings = map(it -> (it[1] + carTravelTime, -it[2]), carHistory)
	allEvents = vcat(carHistory, endings)
	sort!(allEvents, by = first)
	fixedHistory = [(zero(carHistory[1][1]), 0)]
	curTime = fixedHistory[1][1]
	for event ∈ allEvents
		if event[1] == curTime
			fixedHistory[end] = (curTime, fixedHistory[end][2] + event[2])
		else
			curTime = event[1]
			push!(fixedHistory, event)
		end
	end
	carsInUse = 0
	line = [(0, 0)]
	for event ∈ fixedHistory
		push!(line, (event[1], carsInUse))
		carsInUse += event[2]
		push!(line, (event[1], carsInUse))
	end
	plot(line, label = false, xlims = xlims)
end

function plotDetailedCarUsage(carHistory, carTravelTime, carNumber, xlims = :auto; bw = false, text = true)
	maxTime = zeros(carNumber)
	jobs = map(carHistory) do event
			   map(event.items) do item
				   car = findfirst(≤(event.time), maxTime)
				   job = GanttJob(car, event.time, carTravelTime)
				   maxTime[car] = event.time + carTravelTime
				   job, item
			   end
		   end |> Iterators.flatten |> collect
	plt = plot(label = false, xlims = xlims)
	adds = filter(job -> job[2][2], jobs)
	removes = filter(job -> !job[2][2], jobs)
	addsShapes = map(toShape ∘ first, adds)
	addsAnnotations = map(job -> (center(job[1])..., Plots.text(string(job[2][1]), 8)), adds)
	removesShapes = map(toShape ∘ first, removes)
	removesAnnotations = map(job -> (center(job[1])..., Plots.text(string(job[2][1]), 8)), removes)
	plot!(plt, addsShapes, annotations = (text ? addsAnnotations : []), label = "Add", fillalpha = (bw ? 0 : 1))
	plot!(plt, removesShapes, annotations = (text ? removesAnnotations : []), label = "Remove", fillalpha = (bw ? 0 : 1))
	plt
end

function plotDetailedBufferUsage(carHistory, carTravelTime, bufferSize, xlims; bw = false)
	itemsInBuffer = Tuple{Int,Int,Int}[]
	for event ∈ carHistory
		for item ∈ event.items
			if item[2]
				upcoming = filter(it -> it.time > event.time + carTravelTime, carHistory)
				endEvent = findfirst(ev -> ev.items ∋ (item[1], false), upcoming)
				endTime = endEvent ≢ nothing ? upcoming[endEvent].time : xlims[2]
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
	plt = plot(label = false, xlims = xlims)
	foreach(job -> plot!(plt, job[1], label = false, annotations = (center(job[1])..., Plots.text(string(job[2]), 8)), fillalpha = (bw ? 0 : 1)), jobs)
	plt
end=#