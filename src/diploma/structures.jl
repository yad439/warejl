using DataStructures
import Base.eltype,Base.length,Base.iterate,Base.push!,Base.pop!,Base.copy,Base.first,Base.isempty,Base.popfirst!,Base.append!

struct EventQueue
	data::SortedDict{Int,Int}
end
EventQueue()=EventQueue(SortedDict{Int,Int}())
eltype(::Type{EventQueue})=Pair{Int,Int}
length(queue::EventQueue)=length(queue.data)
iterate(queue::EventQueue)=iterate(queue.data)
iterate(queue::EventQueue,state)=iterate(queue.data,state)
function push!(queue::EventQueue,time,number)
	st=searchsortedfirst(queue.data,time)
	if st==pastendsemitoken(queue.data) || deref_key((queue.data,st))≠time
		queue.data[time]=number
	else
		queue.data[st]=deref_value((queue.data,st))+number;
	end
end
function popfirst!(queue::EventQueue)
	st=startof(queue.data)
	ret=deref((queue.data,st))
	delete!((queue.data,st))
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
function push!(queue::EventQueue2,time,new,add::Bool,item::Int)
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
function push!(queue::EventQueue2,time,new,entry::EventEntry,dup::Bool=false)
	if haskey(queue.data,(time,new))
		if dup
			@assert queue.data[(time,new)]≡entry
		else
			@assert isdisjoint(queue.data[(time,new)].add,entry.add)
			@assert isdisjoint(queue.data[(time,new)].remove,entry.remove)
			union!(queue.data[(time,new)].add,entry.add)
			union!(queue.data[(time,new)].remove,entry.remove)
		end
	else
		insert!(queue.data,(time,new),entry)
	end
	queue.data[(time,new)]
end
function append!(queue::EventQueue2,time,new,add,items)
	if haskey(queue.data,(time,new))
		if add
			@assert isdisjoint(queue.data[(time,new)].add,items)
			union!(queue.data[(time,new)].add,items)
		else
			@assert isdisjoint(queue.data[(time,new)].remove,items)
			union!(queue.data[(time,new)].remove,items)
		end
	else
		entry=add ? EventEntry(BitSet(items),BitSet()) : EventEntry(BitSet(),BitSet(items))
		insert!(queue.data,(time,new),entry)
	end
end
function popfirst!(queue::EventQueue2)
	ret=first(queue.data)
	pop!(queue.data,ret[1])
	ret
end
copy(queue::EventQueue2)=EventQueue2(copy(queue.data))
first(queue::EventQueue2)=first(queue.data)
isempty(queue::EventQueue2)=isempty(queue.data)
length(entry::EventEntry)=length(entry.add)+length(entry.remove)
copy(entry::EventEntry)=EventEntry(copy(entry.add),copy(entry.remove))

struct EventEntry3
	startAdd::Nothing
	startRemove::BitSet
	endAdd::BitSet
	endRemove::BitSet
end
EventEntry3()=EventEntry3(nothing,BitSet(),BitSet(),BitSet())
struct EventQueue3
	data::SortedDict{Int,EventEntry3}
end
EventQueue3()=EventQueue3(SortedDict{Int,EventEntry3}())
eltype(::Type{EventQueue3})=Pair{Int,EventEntry3}
length(queue::EventQueue3)=length(queue.data)
iterate(queue::EventQueue3)=iterate(queue.data)
iterate(queue::EventQueue3,state)=iterate(queue.data,state)
function push!(queue::EventQueue3,time,new,add::Bool,item::Int)
	entry=get!(queue.data,time,EventEntry3())
	if add
		if new
			@assert false
			@assert entry.startAdd ∌ item
			push!(entry.startAdd,item)
		else
			@assert entry.endAdd ∌ item
			push!(entry.endAdd,item)
		end
	else
		if new
			@assert entry.startRemove ∌ item
			push!(entry.startRemove,item)
		else
			@assert entry.endRemove ∌ item
			push!(entry.endRemove,item)
		end
	end
end
function append!(queue::EventQueue3,time,new,add::Bool,items)
	entry=get!(queue.data,time,EventEntry3())
	if add
		if new
			@assert false
			@assert isdisjoint(entry.startAdd,items)
			union!(entry.startAdd,items)
		else
			@assert isdisjoint(entry.endAdd,items)
			union!(entry.endAdd,items)
		end
	else
		if new
			@assert isdisjoint(entry.startRemove,items)
			union!(entry.startRemove,items)
		else
			@assert isdisjoint(entry.endRemove,items)
			union!(entry.endRemove,items)
		end
	end
end
function popfirst!(queue::EventQueue3)
	ret=first(queue.data)
	pop!(queue.data,ret[1])
	ret
end