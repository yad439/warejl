using DataStructures
using ProgressMeter
using ValueHistories

include("common.jl")
include("utility.jl")

struct TabuSearchSettings
	searchTries::Int
	tabuSize::Int
	neighbourhoodSize::Int
end
struct TabuSearchSettings2
	searchTries::Int
	tabuSize::Int
	neighbourhoodSize::Float64
end

function modularTabuSearch(settings,scoreFunction,startTimeTable)
	progress=ProgressUnknown("Local tabu search:")

	timeTable=startTimeTable
	tabu=Queue{Tuple{changeType(startTimeTable),Int,Int}}()
	minval=scoreFunction(timeTable)
	minsol=copy(timeTable)
	counter=0

	history=QHistory(typeof(minval))
	push!(history,minval)
	while counter<settings.searchTries
		newTimeTableChange=modularTabuImprove(timeTable,tabu,settings.neighbourhoodSize,scoreFunction)
		restoreChange=change!(timeTable,newTimeTableChange)
		enqueue!(tabu,restoreChange)
		score=scoreFunction(timeTable)
		push!(history,score)
		if score<minval
			counter=0
			minval=score
			copy!(minsol,timeTable)
		else
			counter+=1
		end
		while length(tabu)>settings.tabuSize
			dequeue!(tabu)
		end
		ProgressMeter.next!(progress,showvalues=(("Min score",minval),))
	end
	ProgressMeter.finish!(progress)
	minval,minsol,history
end

function modularTabuImprove(timeTable,tabu,neighbourhoodSize::Int,scoreFunction)
	minval=typemax(Int)
	toApply=(0,0,0)
	for _=1:neighbourhoodSize
		newChange,restoreChange=randomChange!(timeTable,change->tabuCanChange(timeTable,change,tabu))
		score=scoreFunction(timeTable)
		change!(timeTable,restoreChange)
		if score<minval
			minval=score
			toApply=newChange
		end
	end
	toApply
end

function modularTabuImprove(timetable,tabu,neighbourhoodProbability::Float64,scoreFunction)
	minval=typemax(Int)
	toApply=(0,0,0)
	for change ∈ changeIterator(timetable)
		rand() > neighbourhoodProbability && continue
		tabuCanChange(timetable,change,tabu) || continue
		restoreChange=change!(timetable,change)
		score=scoreFunction(timetable)
		change!(timetable,restoreChange)
		if score<minval
			minval=score
			toApply=change
		end
	end
	toApply
end

function tabuCanChange(::TwoVectorEncoding,change,tabu)
	if change[1]==TWO_VECTOR_MOVE_ORDER || change[1]==TWO_VECTOR_MOVE_ASSIGNMENT
		return change ∉ tabu
	elseif change[1]==TWO_VECTOR_SWAP_ORDER || change[1]==TWO_VECTOR_SWAP_ASSIGNMENT
		return (change[1],change[2],change[3]) ∉ tabu && (change[1],change[3],change[2]) ∉ tabu
	end
	@assert(false)
end

function tabuCanChange(::PermutationEncoding,change,tabu)
	if change[1]==PERMUTATION_MOVE
		return change ∉ tabu
	elseif change[1]==PERMUTATION_SWAP
		return (PERMUTATION_SWAP,change[2],change[3]) ∉ tabu && (PERMUTATION_SWAP,change[3],change[2]) ∉ tabu
	end
	@assert(false)
end
