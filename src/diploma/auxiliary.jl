using Plots
import Plots.center

include("common.jl")

struct Schedule
	assignment::Vector{Int}
	times::Vector{Int}
end

struct GanttJob
	assignment::Int
	startTime::Int
	duration::Int
end

@recipe plotGanttJob(::Type{GanttJob},job::GanttJob)=Shape([
	(job.startTime,job.assignment-1),
	(job.startTime,job.assignment),
	(job.startTime+job.duration,job.assignment),
	(job.startTime+job.duration,job.assignment-1)
])
center(job::GanttJob)=(job.startTime+job.duration/2,job.assignment-0.5)

@recipe function scheduleToGantt(jobs::Schedule,jobLengths)
	n=length(jobs.assignment)
	@assert length(jobs.times)==n
	@assert length(jobLengths)==n
	shapes=[
		GanttJob(jobs.assignment[i],jobs.times[i],jobLengths[i])
	for i=1:n]
	#label:=["job $i" for i=1:n]
	shapes
end

function gantt(jobs,jobLengths,useLabel=length(jobLengths)≤10,text=nothing)
	pl=plot(xlims=(0,:auto))
	for i=1:length(jobLengths)
		job=GanttJob(jobs.assignment[i],jobs.times[i],jobLengths[i])
		cent=center(job)
		plot!(pl,job,label=(useLabel ? "job $i" : nothing),annotations=(text≢nothing ? (cent...,text[i]) : nothing))
	end
	pl
end

function plotCarUsage(carHistory,carTravelTime,xlims=:auto)
	endings=map(it->(it[1]+carTravelTime,-it[2]),carHistory)
	allEvents=vcat(carHistory,endings)
	sort!(allEvents,by=first)
	fixedHistory=[(zero(carHistory[1][1]),0)]
	curTime=fixedHistory[1][1]
	for event ∈ allEvents
		if event[1]==curTime
			fixedHistory[end]=(curTime,fixedHistory[end][2]+event[2])
		else
			curTime=event[1]
			push!(fixedHistory,event)
		end
	end
	carsInUse=0
	line=[(0,0)]
	for event ∈ fixedHistory
		push!(line,(event[1],carsInUse))
		carsInUse+=event[2]
		push!(line,(event[1],carsInUse))
	end
	plot(line,label=false,xlims=xlims)
end

function plotDetailedCarUsage(carHistory,carTravelTime,carNumber,xlims=:auto)
	maxTime=zeros(carNumber)
	jobs=map(carHistory) do event
		map(event.items) do item
			car=findfirst(≤(event.time),maxTime)
			job=GanttJob(car,event.time,carTravelTime)
			maxTime[car]=event.time+carTravelTime
			job,event.item,event.isAdd
		end
	end |> Iterators.flatten
	plt=plot(label=false,xlims=xlims)
	foreach(job->plot!(plt,job[1],annotations=(center(job[1])...,job[2])),jobs)
end

scheduleToEncoding(::Type{PermutationEncoding},schedule)=schedule.times|>sortperm|>PermutationEncoding

selectMachine(job,timetable::PermutationEncoding,sums)=argmin(sums)
selectMachine(job,timetable::TwoVectorEncoding,sums)=timetable.assignment[job]