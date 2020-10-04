include("$(@__DIR__)/simpleauxiliary.jl")

using DataStructures
using ProgressMeter

const NONE=0
const MOVE=1
const SWAP=2

function localSearch(n,m,p)
	progress=ProgressUnknown("Local search:")
	tasks=rand(1:m,n)
	while true
		type,arg1,arg2=localImprove(tasks,p,m)
		if type==NONE
			ProgressMeter.finish!(progress)
			return tasks,maxTime(tasks,p,m)
		end
		if type==MOVE
			tasks[arg1]=arg2
		else
			tasks[arg1],tasks[arg2]=tasks[arg2],tasks[arg1]
		end
		ProgressMeter.next!(progress)
	end
end

function localTabuSearch(n,m,p)
	tabuSize=floor(Int,0.4n)

	progress=ProgressThresh(0.0,"Local tabu search:")
	history=Vector{eltype(p)}(undef,0)

	tasks=rand(1:m,n)
	tabu=Queue{Tuple{Int,Int,Int}}()
	minval=maxTime(tasks,p,m)
	minsol=copy(tasks)
	count=0

	push!(history,minval)
	while count<100
		type,arg1,arg2=localTabuImprove(tasks,p,m,tabu)
		if type==MOVE
			tasks[arg1]=arg2
			enqueue!(tabu,(type,arg1,arg2))
		elseif type==SWAP
			tasks[arg1],tasks[arg2]=tasks[arg2],tasks[arg1]
			enqueue!(tabu,(type,arg1,arg2))
		end

		score=type≠NONE ? maxTime(tasks,p,m) : Inf
		push!(history,score)
		if score<minval
			count=0
			minval=score
			copy!(minsol,tasks)
		else
			count+=1
		end
		while length(tabu)>tabuSize
			dequeue!(tabu)
		end
		ProgressMeter.update!(progress,minval,showvalues=[(:count,count)])
	end
	ProgressMeter.finish!(progress)
	minsol,minval,history
end

function localImprove(tasks,p,m)
	n=length(tasks)
	minval=maxTime(tasks,p,m)
	type=NONE
	moveIndex=0
	moveTo=0
	swap1=0
	swap2=0
	for i=1:n
		tmp=tasks[i]
		for j=1:m
			if j≠tasks[i]
				tasks[i]=j
				current=maxTime(tasks,p,m)
				if current<minval
					moveTo=j
					moveIndex=i
					type=MOVE
					minval=current
				end
			end
		end
		tasks[i]=tmp
	end
	for i=1:n
		for j=1:i-1
			if i≠j
				tasks[i],tasks[j]=tasks[j],tasks[i]
				current=maxTime(tasks,p,m)
				if current<minval
					swap2=j
					swap1=i
					type=SWAP
					minval=current
				end
				tasks[i],tasks[j]=tasks[j],tasks[i]
			end
		end
	end
	if type==NONE
		return NONE,0,0
	elseif type==MOVE
		return MOVE,moveIndex,moveTo
	else
		return SWAP,swap1,swap2
	end
end

function localTabuImprove(tasks,p,m,tabu)
	n=length(tasks)
	minval=Inf
	type=NONE
	moveIndex=0
	moveTo=0
	swap1=0
	swap2=0
	for i=1:n
		tmp=tasks[i]
		for j=1:m
			if j≠tasks[i] && (MOVE,i,j) ∉ tabu
				tasks[i]=j
				current=maxTime(tasks,p,m)
				if current<minval
					moveTo=j
					moveIndex=i
					type=MOVE
					minval=current
				end
			end
		end
		tasks[i]=tmp
	end
	for i=1:n
		for j=1:i-1
			if i≠j && (SWAP,i,j)∉tabu
				tasks[i],tasks[j]=tasks[j],tasks[i]
				current=maxTime(tasks,p,m)
				if current<minval
					swap2=j
					swap1=i
					type=SWAP
					minval=current
				end
				tasks[i],tasks[j]=tasks[j],tasks[i]
			end
		end
	end
	if type==NONE
		return NONE,0,0
	elseif type==MOVE
		return MOVE,moveIndex,moveTo
	else
		return SWAP,swap1,swap2
	end
end
