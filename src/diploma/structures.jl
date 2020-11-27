using DataStructures
import Base.eltype,Base.length,Base.iterate,Base.push!,Base.pop!,Base.copy,Base.first,Base.isempty

struct EventQueue
	data::SortedDict{Int,Int}
end
EventQueue()=EventQueue(SortedDict{Int,Int}())
eltype(::Type{EventQueue})=Pair{Int,Int}
length(queue::EventQueue)=length(queue.data)
iterate(queue::EventQueue)=iterate(queue.data)
iterate(queue::EventQueue,state)=iterate(queue.data,state)
function push!(queue::EventQueue,time,number)
	queue.data[time]=get(queue.data,time,0)+number;
end
function pop!(queue::EventQueue)
	ret=first(queue.data)
	pop!(queue.data,ret[1])
	ret
end
copy(queue::EventQueue)=EventQueue(copy(queue.data))
first(queue::EventQueue)=first(queue.data)
isempty(queue::EventQueue)=isempty(queue.data)

struct EventEntry
	add::BitSet
	remove::BitSet
end
EventEntry()=EventEntry(BitSet(),BitSet())
struct EventQueue2
	data::SortedDict{Tuple{Int,Bool},EventEntry}
end
EventQueue2()=EventQueue2(SortedDict{Tuple{Int,Bool},EventEntry}())
eltype(::Type{EventQueue2})=Pair{Tuple{Int,Bool},EventEntry}
length(queue::EventQueue2)=length(queue.data)
iterate(queue::EventQueue2)=iterate(queue.data)
iterate(queue::EventQueue2,state)=iterate(queue.data,state)
function push!(queue::EventQueue2,time,new,add,item)
	if haskey(queue.data,(time,new))
		if add
			@assert queue.data[(time,new)].add ∌ item
			push!(queue.data[(time,new)].add,item)
		else
			@assert queue.data[(time,new)].remove ∌ item
			push!(queue.data[(time,new)].remove,item)
		end
	else
		entry=add ? EventEntry(BitSet((item,)),BitSet()) : EventEntry(BitSet(),BitSet((item,)))
		insert!(queue.data,(time,new),entry)
	end
end
function push!(queue::EventQueue2,time,new,entry)
	if haskey(queue.data,(time,new))
		@assert isdisjoint(queue.data[(time,new)].add,entry.add)
		@assert isdisjoint(queue.data[(time,new)].remove,entry.remove)
		union!(queue.data[(time,new)].add,entry.add)
		union!(queue.data[(time,new)].remove,entry.remove)
	else
		insert!(queue.data,(time,new),entry)
	end
end
function pop!(queue::EventQueue2)
	ret=first(queue.data)
	pop!(queue.data,ret[1])
	ret
end
copy(queue::EventQueue2)=EventQueue2(copy(queue.data))
first(queue::EventQueue2)=first(queue.data)
isempty(queue::EventQueue2)=isempty(queue.data)
length(entry::EventEntry)=length(entry.add)+length(entry.remove)
copy(entry::EventEntry)=EventEntry(copy(entry.add),copy(entry.remove))