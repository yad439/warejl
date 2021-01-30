using Plots
import Plots.center

include("common.jl")
include("structures.jl")
include("utility.jl")

struct Problem
	jobCount::Int
	machineCount::Int
	carCount::Int
	carTravelTime::Int
	itemCount::Int
	bufferSize::Int
	jobLengths::Vector{Int}
	itemsNeeded::Vector{BitSet}
end

struct Schedule
	assignment::Vector{Int}
	times::Vector{Int}
	carTasks::Vector{@NamedTuple{time::Int,item::Int,isAdd::Bool}}
end

struct GanttJob
	assignment::Int
	startTime::Int
	duration::Int
end

@recipe plotGanttJob(::Type{GanttJob},job::GanttJob)=toShape(job)
toShape(job::GanttJob)=Shape([
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

function gantt(jobs,jobLengths,useLabel=length(jobLengths)≤10,text=nothing;bw=false)
	pl=plot(xlims=(0,:auto))
	for i=1:length(jobLengths)
		job=GanttJob(jobs.assignment[i],jobs.times[i],jobLengths[i])
		cent=center(job)
		plot!(pl,job,label=(useLabel ? "job $i" : nothing),annotations=(text≢nothing ? (cent...,Plots.text(text[i],8)) : nothing),fillalpha=(bw ? 0 : 1))
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

function plotDetailedCarUsage(carHistory,carTravelTime,carNumber,xlims=:auto;text=true)
	maxTime=zeros(carNumber)
	jobs=map(carHistory) do event
		map(event.items) do item
			car=findfirst(≤(event.time),maxTime)
			job=GanttJob(car,event.time,carTravelTime)
			maxTime[car]=event.time+carTravelTime
			job,item
		end
	end |> Iterators.flatten |> collect
	plt=plot(label=false,xlims=xlims)
	adds=filter(job->job[2][2],jobs)
	removes=filter(job->!job[2][2],jobs)
	addsShapes=map(toShape∘first,adds)
	addsAnnotations=map(job->(center(job[1])...,Plots.text(string(job[2][1]),8)),adds)
	removesShapes=map(toShape∘first,removes)
	removesAnnotations=map(job->(center(job[1])...,Plots.text(string(job[2][1]),8)),removes)
	plot!(plt,addsShapes,annotations=(text ? addsAnnotations : nothing),label="Add")
	plot!(plt,removesShapes,annotations=(text ? removesAnnotations : nothing),label="Remove")
	plt
end

function plotDetailedBufferUsage(carHistory,carTravelTime,bufferSize,xlims;bw=false)
	itemsInBuffer=Tuple{Int,Int,Int}[]
	for event ∈ carHistory
		for item ∈ event.items
			if item[2]
				upcoming=filter(it->it.time>event.time+carTravelTime,carHistory)
				endEvent=findfirst(ev->ev.items ∋ (item[1],false),upcoming)
				endTime=endEvent≢nothing ? upcoming[endEvent].time : xlims[2]
				push!(itemsInBuffer,(item[1],event.time+carTravelTime,endTime))
			end
		end
	end
	maxTime=zeros(bufferSize)
	jobs=map(itemsInBuffer) do item
		car=findfirst(≤(item[2]),maxTime)
		job=GanttJob(car,item[2],item[3]-item[2])
		maxTime[car]=item[3]
		job,item[1]
	end
	plt=plot(label=false,xlims=xlims)
	foreach(job->plot!(plt,job[1],label=false,annotations=(center(job[1])...,Plots.text(string(job[2]),8)),fillalpha=(bw ? 0 : 1)),jobs)
	plt
end

function countCars(history,carTravelTime)
	carChangeHistory=history|>fmap(event->(event.time,length(event.items)))
	endings=carChangeHistory|>fmap(it->(it[1]+carTravelTime,-it[2]))
	allEvents=vcat(carChangeHistory,endings)
	sort!(allEvents,by=first)
	fixedHistory=[(zero(carChangeHistory[1][1]),0)]
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
	res=[(0,0)]
	for event ∈ fixedHistory
		carsInUse+=event[2]
		push!(res,(event[1],carsInUse))
	end
	res
end

scheduleToEncoding(::Type{PermutationEncoding},schedule)=schedule.times|>sortperm|>PermutationEncoding

selectMachine(job,timetable::PermutationEncoding,sums)=argmin(sums)
selectMachine(job,timetable::TwoVectorEncoding,sums)=timetable.assignment[job]

function normalizeHistory(history::AbstractVector{Tuple{Tuple{Int,Bool},EventEntry}},carTravelTime)
	onlyStart=history |> it->filter(x->!x[1][2],it) |> it->map(x->(x[1][1]-carTravelTime,x[2]),it)
	map(onlyStart) do event
		items=Iterators.flatten((
			map(x->(x,true),collect(event[2].add)),
			map(x->(x,false),collect(event[2].remove))
		))|>collect
		(time=event[1],items=items)
	end |> it->filter(x->!isempty(x.items),it)
end
function normalizeHistory(history::AbstractVector{Tuple{Int,EventEntry3}},carTravelTime)
	map(history) do event
		items=Iterators.flatten((
			map(x->(x,true),collect(event[2].endAdd)),
			map(x->(x,false),collect(event[2].endRemove))
		))|>collect
		(time=event[1]-carTravelTime,items=items)
	end |> it->filter(x->!isempty(x.items),it)
end
separateEvents(history)=map(event->map(it->(time=event.time,item=it[1],isAdd=it[2]),event.items),history)|>Iterators.flatten
function generalEvents(history)
	eventDict=Dict()
	foreach(history) do event
		entry=get!(()->(Int[],Int[]),eventDict,event.time)
		list=event.isAdd ? entry[1] : entry[2]
		push!(list,event.item)
	end
	sort(map(entry->(time=entry[1],add=entry[2][1],remove=entry[2][2]),collect(eventDict)),by=e->e.time)
end

function isValid(problem::Problem)
	res = length(problem.jobLengths) == problem.jobCount && length(problem.itemsNeeded) == problem.jobCount
	res &= Set(Iterators.flatten(problem.itemsNeeded)) == Set(1:problem.itemCount)
	for items ∈ problem.itemsNeeded
		res &= length(items) ≤ problem.bufferSize
	end
	res
end

function isValid(solution::Schedule,problem)
	bufferEvents = map(solution.carTasks) do task
		task.isAdd ? (time=task.time+problem.carTravelTime,task.item,task.isAdd) : task
	end
	sort!(bufferEvents;by=event->event.time)
	bufferStates = [(0,Set{Int}())]
	for event ∈ bufferEvents
		@assert event.time ≥ bufferStates[end][1]
		event.time > bufferStates[end][1] && push!(bufferStates,(event.time,copy(bufferStates[end][2])))
		items=bufferStates[end][2]
		if event.isAdd
			event.item ∉ items || return false
			push!(items,event.item)
		else
			event.item ∈ items || return false
			delete!(items,event.item)
		end
	end
	all(state->length(state[2])≤problem.bufferSize,bufferStates) || return false
	order = sortperm(solution.times)
	sums = zeros(Int,problem.machineCount)
	for job ∈ order
		sums[solution.assignment[job]] ≤ solution.times[job] || return false
		stateInd = searchsortedlast(bufferStates,solution.times[job]; by = first)
		problem.itemsNeeded[job] ⊆ bufferStates[stateInd][2] || return false
		sums[solution.assignment[job]] = solution.times[job] + problem.jobLengths[job]
	end
	true
end