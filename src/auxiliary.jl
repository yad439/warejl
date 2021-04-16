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
	for task ∈ solution.carTasks
		count(t->task.time-problem.carTravelTime<t.time≤task.time,solution.carTasks) ≤ problem.carCount || return false
	end
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