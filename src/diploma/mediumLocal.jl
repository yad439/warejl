include("mediumAuxiliary.jl")

using DataStructures
using ProgressMeter
using Random

const NONE=0
const MOVE=1
const SWAP=2

const MOVE_MACHINE=3
const SWAP_MACHINE=4
const MOVE_ORDER=5
const SWAP_ORDER=6

struct TabuSearchSettings
	searchTries::Int
	tabuSize::Int
	neighbourhoodSize::Int
end

function localTabu2(n,m,p,settings)
	# tabuSize=floor(Int,0.6n)

	progress=ProgressThresh(0.0,"Local tabu search (permutation):")
	history=Vector{eltype(p)}(undef,0)

	tasks=shuffle(1:n)
	tabu=Queue{Tuple{Int,Int,Int}}()
	minval=timeOfPermutation(tasks,p,m)
	minsol=copy(tasks)
	count=0

	push!(history,minval)
	while count<settings.searchTries
		new=randomLocalTabuImprovePermutation(tasks,p,m,tabu,settings.neighbourhoodSize)
		@assert new[1]≠NONE
		if new[1]==MOVE
			val=tasks[new[2]]
			deleteat!(tasks,new[2])
			insert!(tasks,new[3],val)
		else
			tasks[new[2]],tasks[new[3]]=tasks[new[3]],tasks[new[2]]
		end
		enqueue!(tabu,new)
		score=timeOfPermutation(tasks,p,m)
		push!(history,score)
		if score<minval
			count=0
			minval=score
			copy!(minsol,tasks)
		else
			count+=1
		end
		while length(tabu)>settings.tabuSize
			dequeue!(tabu)
		end
		ProgressMeter.update!(progress,minval,showvalues=[(:count,count)])
	end
	ProgressMeter.finish!(progress)
	minsol,minval,history
end

function localTabu3(n,m,p,settings)
	@assert length(p)==n
	# tabuSize=floor(Int,n)

	progress=ProgressThresh(0.0,"Local tabu search (double):")
	history=Vector{eltype(p)}(undef,0)

	assignment=rand(1:m,n)
	order=shuffle(1:n)
	tabu=Queue{Tuple{Int,Int,Int}}()
	minval=maxTime(assignment,p,m)
	minsol=copy(assignment)
	count=0

	push!(history,minval)
	while count<settings.searchTries
		new=randomLocalTabuImprove(assignment,order,p,m,tabu,settings.neighbourhoodSize)
		if new[1]==MOVE_MACHINE
			assignment[new[2]]=new[3]
		elseif new[1]==SWAP_MACHINE
			assignment[new[2]],assignment[new[3]]=assignment[new[3]],assignment[new[2]]
		elseif new[1]==MOVE_ORDER
			val=order[new[2]]
			deleteat!(order,new[2])
			insert!(order,new[3],val)
		elseif new[1]==SWAP_ORDER
			order[new[2]],order[new[3]]=order[new[3]],order[new[2]]
		else
			@assert(false)
		end
		enqueue!(tabu,new)
		score=maxTime(assignment,p,m)
		push!(history,score)
		if score<minval
			count=0
			minval=score
			copy!(minsol,assignment)
		else
			count+=1
		end
		while length(tabu)>settings.tabuSize
			dequeue!(tabu)
		end
		ProgressMeter.update!(progress,minval,showvalues=[(:count,count)])
		end
	ProgressMeter.finish!(progress)
	minsol,minval,history
end

function randomLocalTabuImprovePermutation(tasks,p,m,tabu,triesCount)
	n=length(tasks)
	minval=Inf
	type=NONE
	val1=0
	val2=0
	count=0
	while count<triesCount
		pos1=rand(1:n)
		pos2=rand(1:n)
		pos1==pos2 && continue
		if rand()<0.5
			(MOVE,pos1,pos2) ∈ tabu && continue
			val=tasks[pos1]
			deleteat!(tasks,pos1)
			insert!(tasks,pos2,val)
			current=timeOfPermutation(tasks,p,m)
			if current<minval
				minval=current
				val1=pos1
				val2=pos2
				type=MOVE
			end
			deleteat!(tasks,pos2)
			insert!(tasks,pos1,val)
		else
			(SWAP,pos1,pos2) ∈ tabu && continue
			(SWAP,pos2,pos1) ∈ tabu && continue
			tasks[pos1],tasks[pos2]=tasks[pos2],tasks[pos1]
			current=timeOfPermutation(tasks,p,m)
			if current<minval
				minval=current
				val1=pos1
				val2=pos2
				type=SWAP
			end
			tasks[pos1],tasks[pos2]=tasks[pos2],tasks[pos1]
		end
		count+=1
	end
	type,val1,val2
end

function randomLocalTabuImprove(assignment,permutation,p,m,tabu,triesCount)
	n=length(assignment)
	@assert length(permutation)==n
	minval=Inf
	type=NONE
	val1=0
	val2=0
	count=0
	while count<triesCount
		if rand()<0.5
			if rand()<0.5
				task=rand(1:n)
				machine=rand(1:m)
				old=assignment[task]
				machine==old && continue
				(MOVE_MACHINE,task,machine) ∈ tabu && continue
				assignment[task]=machine
				current=maxTime(assignment,p,m)
				if current<minval
					minval=current
					val1=task
					val2=machine
					type=MOVE_MACHINE
				end
				assignment[task]=old
			else
				task1=rand(1:n)
				task2=rand(1:n)
				assignment[task1]==assignment[task2] && continue
				(SWAP_MACHINE,task1,task2) ∈ tabu && continue
				(SWAP_MACHINE,task2,task1) ∈ tabu && continue
				assignment[task1],assignment[task2]=assignment[task2],assignment[task1]
				current=maxTime(assignment,p,m)
				if current<minval
					minval=current
					val1=task1
					val2=task2
					type=SWAP_MACHINE
				end
				assignment[task1],assignment[task2]=assignment[task2],assignment[task1]
			end
		else
			pos1=rand(1:n)
			pos2=rand(1:n)
			pos1==pos2 && continue
			if rand()<0.5
				(MOVE_ORDER,pos1,pos2) ∈ tabu && continue
				val=permutation[pos1]
				deleteat!(permutation,pos1)
				insert!(permutation,pos2,val)
				current=maxTime(assignment,p,m)
				if current<minval
					minval=current
					val1=pos1
					val2=pos2
					type=MOVE_ORDER
				end
				deleteat!(permutation,pos2)
				insert!(permutation,pos1,val)
			else
				(SWAP_ORDER,pos1,pos2) ∈ tabu && continue
				(SWAP_ORDER,pos2,pos1) ∈ tabu && continue
				permutation[pos1],permutation[pos2]=permutation[pos2],permutation[pos1]
				current=maxTime(assignment,p,m)
				if current<minval
					minval=current
					val1=pos1
					val2=pos2
					type=SWAP_ORDER
				end
				permutation[pos1],permutation[pos2]=permutation[pos2],permutation[pos1]
			end
		end
		count+=1
	end
	type,val1,val2
end
