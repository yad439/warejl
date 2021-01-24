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

modularTabuSearch(settings,scoreFunction,startTimeTable)=modularTabuSearch(settings,scoreFunction,startTimeTable,Queue{Tuple{changeType(startTimeTable),Int,Int}}(),tabuAdd!,tabuCanChange)
modularTabuSearch2(settings,scoreFunction,startTimeTable)=modularTabuSearch(settings,scoreFunction,startTimeTable,Queue{Int}(),tabuAdd2!,tabuCanChange2)

function modularTabuSearch(settings,scoreFunction,startTimeTable,tabuInit,tabuAdd!,tabuCanChange)
	progress=ProgressUnknown("Local tabu search:")

	timeTable=startTimeTable
	tabu=tabuInit
	minval=scoreFunction(timeTable)
	minsol=copy(timeTable)
	counter=0

	history=QHistory(typeof(minval))
	push!(history,minval)
	while counter<settings.searchTries
		newTimeTableChange=modularTabuImprove(timeTable,tabu,settings.neighbourhoodSize,scoreFunction,tabuCanChange)
		restoreChange=change!(timeTable,newTimeTableChange)
		tabuAdd!(tabu,newTimeTableChange,restoreChange,timeTable)
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
		ProgressMeter.next!(progress,showvalues=(("Score",score),))
	end
	ProgressMeter.finish!(progress)
	(score=minval,solution=minsol,history=history)
end

function modularTabuImprove(timeTable,tabu,neighbourhoodSize::Int,scoreFunction,canChange)
	minval=typemax(Int)
	toApply=(defaultChange(timeTable),0,0)
	for _=1:neighbourhoodSize
		newChange,restoreChange=randomChange!(timeTable,change->canChange(timeTable,change,tabu))
		score=scoreFunction(timeTable)
		change!(timeTable,restoreChange)
		if score<minval
			minval=score
			toApply=newChange
		end
	end
	toApply
end

function modularTabuImprove(timetable,tabu,neighbourhoodProbability::Float64,scoreFunction,canChange)
	minval=typemax(Int)
	toApply=(0,0,0)
	for change ∈ changeIterator(timetable)
		rand() > neighbourhoodProbability && continue
		canChange(timetable,change,tabu) || continue
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

function tabuAdd!(tabu,newChange,restoreChange,solution)
	enqueue!(tabu,restoreChange)
end
function tabuAdd2!(tabu,newChange,restoreChange,solution)
	if newChange[1]≡PERMUTATION_MOVE
			enqueue!(tabu,newChange[2])
	elseif newChange[1]≡PERMUTATION_SWAP
			enqueue!(tabu,newChange[2])
			enqueue!(tabu,newChange[3])
	end
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

function tabuCanChange2(::PermutationEncoding,change,tabu)
	if change[1]==PERMUTATION_MOVE
		return change[2] ∉ tabu
	elseif change[1]==PERMUTATION_SWAP
		return change[2] ∉ tabu && change[3] ∉ tabu
	end
	@assert(false)
end