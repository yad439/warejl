using ProgressMeter
using ValueHistories

include("common.jl")

struct AnnealingSettings
	searchTries::Int
	startTheshold::Float64
	decreasingFunction::Function
	applyChange::Function
end

function modularAnnealing(settings,scoreFunction,startTimeTable)
	progress=ProgressUnknown("Annealing:")

	timeTable=startTimeTable
	minval=scoreFunction(timeTable)
	minsol=copy(timeTable)
	counter=0
	threshold=settings.startTheshold

	prevScore=minval
	history=QHistory(typeof(minval))
	push!(history,minval)
	while counter<settings.searchTries
		newChange,restoreChange=randomChange!(timeTable,change->true)
		score=scoreFunction(timeTable)
		if settings.applyChange(prevScore,score,threshold)
			prevScore=score
		else
			change!(timeTable,restoreChange)
		end
		if score<minval
			counter=0
			minval=score
			copy!(minsol,timeTable)
		else
			counter+=1
		end
		threshold=settings.decreasingFunction(threshold)
		push!(history,prevScore)
		ProgressMeter.next!(progress,showvalues=(("Min score",minval),))
	end
	ProgressMeter.finish!(progress)
	(score=minval,solution=minsol,history=history)
end

function maxDif(jobs::PermutationEncoding,scoreFunction)
	minval=typemax(Int)
	maxval=typemin(Int)
	for type∈[PERMUTATION_MOVE,PERMUTATION_SWAP],arg1=1:length(jobs),arg2=1:length(jobs)
		arg1==arg2 && continue
		restoreChange=change!(jobs,type,arg1,arg2)
		score=scoreFunction(jobs)
		change!(jobs,restoreChange)
		score<minval && (minval=score)
		score>maxval && (maxval=score)
	end
	maxval-minval
end

function maxDif(jobs::TwoVectorEncoding,scoreFunction)
	minval=typemax(Int)
	maxval=typemin(Int)
	for type∈[TWO_VECTOR_SWAP_ASSIGNMENT,TWO_VECTOR_MOVE_ORDER,TWO_VECTOR_SWAP_ORDER],arg1=1:length(jobs),arg2=1:length(jobs)
		arg1==arg2 && continue
		restoreChange=change!(jobs,type,arg1,arg2)
		score=scoreFunction(jobs)
		change!(jobs,restoreChange)
		score<minval && (minval=score)
		score>maxval && (maxval=score)
	end
	for arg1=1:length(jobs),arg2=1:jobs.machineCount
		restoreChange=change!(jobs,TWO_VECTOR_MOVE_ASSIGNMENT,arg1,arg2)
		score=scoreFunction(jobs)
		change!(jobs,restoreChange)
		score<minval && (minval=score)
		score>maxval && (maxval=score)
	end
	maxval-minval
end
