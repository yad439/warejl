using DataStructures
import Base.eltype,Base.length,Base.iterate,Base.push!,Base.pop!

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