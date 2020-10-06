using DataStructures
using ProgressMeter

include("$(@__DIR__)/common.jl")

struct TabuSearchSettings
	searchTries::Int
	tabuSize::Int
	neighbourhoodSize::Int
end

function modularTabuSearch(jobCount,machineCount,settings,scoreFunction,startTimeTable)
	progress=ProgressUnknown("Local tabu search:")
	history=Vector{eltype(p)}(undef,0)

	timeTable=startTimeTable
	tabu=Queue{Tuple{Int,Int,Int}}()
	minval=scoreFunction(timeTable)
	minsol=copy(timeTable)
	count=0

	push!(history,minval)
	while count<settings.searchTries
		newTimeTableChange=modularTabuImprove(timeTable,jobCount,machineCount,tabu,settings.neighbourhoodSize,scoreFunction)
		change!(timeTable,newTimeTableChange)
		enqueue!(tabu,newTimeTableChange)
		score=scoreFunction(timeTable)
		push!(history,score)
		if score<minval
			count=0
			minval=score
			copy!(minsol,timeTable)
		else
			count+=1
		end
		while length(tabu)>settings.tabuSize
			dequeue!(tabu)
		end
		ProgressMeter.next!(progress,showvalues=[("Min score",minval)])
	end
	ProgressMeter.finish!(progress)
	minval,minsol,history
end

function modularTabuImprove(timeTable,jobCount,machineCount,tabu,neighbourhoodSize,scoreFunction)
	minval=typemax(Int)
	toApply=(0,0,0)
	for _=1:neighbourhoodSize
		newChange,restoreChange=randomChange!(timeTable,change->tabuCanChange(timeTable,change,tabu),jobCount,machineCount)
		score=scoreFunction(timeTable)
		change!(timeTable,restoreChange)
		if score<minval
			minval=score
			toApply=newChange
		end
	end
	toApply
end

function tabuCanChange(_::TwoVectorEncoding,change,tabu)
	if change[1]==TWO_VECTOR_MOVE_ORDER || change[1]==TWO_VECTOR_MOVE_ASSIGNMENT
		return change ∉ tabu
	elseif change[1]==TWO_VECTOR_SWAP_ORDER || change[1]==TWO_VECTOR_SWAP_ASSIGNMENT
		return (change[1],change[2],change[3]) ∉ tabu && (change[1],change[3],change[2]) ∉ tabu
	end
	@assert(false)
end

function tabuCanChange(_::PermutationEncoding,change,tabu)
	if change[1]==PERMUTATION_MOVE
		return change ∉ tabu
	elseif change[1]==PERMUTATION_SWAP
		return (PERMUTATION_SWAP,change[2],change[3]) ∉ tabu && (PERMUTATION_SWAP,change[3],change[2]) ∉ tabu
	end
	@assert(false)
end
