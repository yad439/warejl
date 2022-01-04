using DataStructures
import Base.eltype, Base.length, Base.iterate, Base.push!, Base.pop!, Base.copy, Base.first, Base.isempty, Base.popfirst!, Base.append!

struct EventQueue
	data::Deque{Tuple{Int,Int}}
end
EventQueue() = EventQueue(Deque{Tuple{Int,Int}}(128))
eltype(::Type{EventQueue}) = Tuple{Int,Int}
length(queue::EventQueue) = length(queue.data)
iterate(queue::EventQueue) = iterate(queue.data)
iterate(queue::EventQueue, state) = iterate(queue.data, state)
function push!(queue::EventQueue, time, number)
	if !isempty(queue.data) && last(queue.data)[1] == time
		prevNum = pop!(queue.data)[2]
		push!(queue.data, (time, prevNum + number))
	else
		push!(queue.data, (time, number))
	end
end
popfirst!(queue::EventQueue) = popfirst!(queue.data)
copy(queue::EventQueue) = EventQueue(copy(queue.data))
first(queue::EventQueue) = first(queue.data)
isempty(queue::EventQueue) = isempty(queue.data)

struct EventEntry3
	startAdd::Nothing
	startRemove::BitSet
	endAdd::BitSet
	endRemove::BitSet
end
EventEntry3() = EventEntry3(nothing, BitSet(), BitSet(), BitSet())
struct EventQueue3
	data::SortedDict{Int,EventEntry3}
end
EventQueue3() = EventQueue3(SortedDict{Int,EventEntry3}())
eltype(::Type{EventQueue3}) = Pair{Int,EventEntry3}
length(queue::EventQueue3) = length(queue.data)
iterate(queue::EventQueue3) = iterate(queue.data)
iterate(queue::EventQueue3, state) = iterate(queue.data, state)
function push!(queue::EventQueue3, time, new, add::Bool, item::Int)
	entry = get!(queue.data, time, EventEntry3())
	if add
		if new
			@assert false
			@assert entry.startAdd ∌ item
			push!(entry.startAdd, item)
		else
			@assert entry.endAdd ∌ item
			push!(entry.endAdd, item)
		end
	else
		if new
			@assert entry.startRemove ∌ item
			push!(entry.startRemove, item)
		else
			@assert entry.endRemove ∌ item
			push!(entry.endRemove, item)
		end
	end
end
function append!(queue::EventQueue3, time, new, add::Bool, items)
	entry = get!(queue.data, time, EventEntry3())
	if add
		if new
			@assert false
			@assert isdisjoint(entry.startAdd, items)
			union!(entry.startAdd, items)
		else
			@assert isdisjoint(entry.endAdd, items)
			union!(entry.endAdd, items)
		end
	else
		if new
			@assert isdisjoint(entry.startRemove, items)
			union!(entry.startRemove, items)
		else
			@assert isdisjoint(entry.endRemove, items)
			union!(entry.endRemove, items)
		end
	end
end
function popfirst!(queue::EventQueue3)
	ret = first(queue.data)
	pop!(queue.data, ret[1])
	ret
end

mutable struct Counter
	counter::Int
end
function (c::Counter)()
	c.counter == 0 && return false
	c.counter -= 1
	true
end