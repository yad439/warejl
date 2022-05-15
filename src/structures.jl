using DataStructures
import Base.eltype, Base.push!, Base.first, Base.isempty, Base.popfirst!

include("problemStructures.jl")

struct EventQueue
    data::Deque{Tuple{Int,Int}}
end
EventQueue() = EventQueue(Deque{Tuple{Int,Int}}(128))
eltype(::Type{EventQueue}) = Tuple{Int,Int}
# length(queue::EventQueue) = length(queue.data)
# iterate(queue::EventQueue) = iterate(queue.data)
# iterate(queue::EventQueue, state) = iterate(queue.data, state)
function push!(queue::EventQueue, time, number)
    if !isempty(queue.data) && last(queue.data)[1] == time
        prevNum = pop!(queue.data)[2]
        push!(queue.data, (time, prevNum + number))
    else
        push!(queue.data, (time, number))
    end
end
popfirst!(queue::EventQueue) = popfirst!(queue.data)
# copy(queue::EventQueue) = EventQueue(copy(queue.data))
first(queue::EventQueue) = first(queue.data)
isempty(queue::EventQueue) = isempty(queue.data)

struct EventQueue4
    data::Vector{BufferEvent}
end
EventQueue4() = EventQueue4(Deque{BufferEvent}())
eltype(::Type{EventQueue4}) = BufferEvent
function push!(queue::EventQueue4,time::Int,toAdd,toRemove)
	if !isempty(queue.data) && last(queue.data).time==time
		event=last(queue.data)
		if toAdd≢nothing
			@assert isdisjoint(event.toAdd,toAdd)
			union!(event.toAdd,toAdd)
		end
		if toRemove≢nothing
			@assert isdisjoint(event.toRemove,toRemove)
			union!(event.toRemove,toRemove)
		end
	else
		if toAdd≢nothing
			toAddSet=BitSet(toAdd)
		else
			toAddSet=BitSet()
		end
		if toRemove ≢ nothing
			toRemoveSet = BitSet(toRemove)
		else
			toRemoveSet = BitSet()
		end
    	push!(queue.data, BufferEvent(time,toAddSet,toRemoveSet))
	end
end