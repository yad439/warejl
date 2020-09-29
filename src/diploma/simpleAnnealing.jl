include("$(@__DIR__)/simpleCommon.jl")

using ProgressMeter

function annealing(n,m,p)
	tasks=rand(1:m,n)
	thres=2maxDif(tasks,p,m)
	annealingUni(n,m,p,tasks,Float64(thres),(new,old,threshold)->new-old<threshold,it->0.99)
end
function annealing2(n,m,p)
	tasks=rand(1:m,n)
	thres=2maxDif(tasks,p,m)
	annealingUni(n,m,p,tasks,Float64(thres),(new,old,threshold)->rand()<exp((old-new)/threshold),it->it*0.99)
end
function annealing3(n,m,p)
	tasks=rand(1:m,n)
	thres=maxTime(tasks,p,m)
	annealingUni(n,m,p,tasks,Float64(thres),(new,old,threshold)->new<=threshold,it->it-thres/1000)
end

function annealingUni(n,m,p,tasks,threshold,accept,update)
	iterationLimit=1000

	progress=ProgressThresh(zero(threshold),"Annealing:")
	history=Vector{eltype(p)}(undef,0)

	# tasks=start
	current=maxTime(tasks,p,m)
	# threshold=start
	minval=maxTime(tasks,p,m)
	minsol=copy(tasks)
	count=0

	push!(history,minval)
	while count<iterationLimit
		changed=false
		if rand()<=1/n
			index=rand(1:n)
			value=rand(1:m)
			oldvalue=tasks[index]
			tasks[index]=value
			score=maxTime(tasks,p,m)
			if score<current
				count=0
				current=score
			else
				count+=1
				if accept(score,current,threshold)
					current=score
				else
					tasks[index]=oldvalue
				end
			end
		else
			i=rand(1:n)
			j=rand(1:n)
			tasks[i],tasks[j]=tasks[j],tasks[i]
			score=maxTime(tasks,p,m)
			if score<current
				count=0
				current=score
			else
				count+=1
				if accept(score,current,threshold)
					current=score
				else
					tasks[i],tasks[j]=tasks[j],tasks[i]
				end
			end
		end
		push!(history,current)
		if score<minval
			# changed=true
			minval=score
			copy!(minsol,tasks)
		end
		threshold=update(threshold)

		ProgressMeter.update!(progress,threshold,showvalues =[(:minval,minval),(:count,count)])
	end
	ProgressMeter.finish!(progress)
	minsol,minval,history
end

function maxDif(tasks,p,m)
	n=length(tasks)
	val0=maxTime(tasks,p,m)
	res=zero(eltype(p))
	for i=1:n
		tmp=tasks[i]
		for j=1:m
			if j≠tasks[i]
				tasks[i]=j
				current=maxTime(tasks,p,m)
				abs(val0-current)>res && (res=abs(val0-current))
			end
		end
		tasks[i]=tmp
	end
	for i=1:n
		for j=1:i-1
			if i≠j
				tasks[i],tasks[j]=tasks[j],tasks[i]
				current=maxTime(tasks,p,m)
				abs(val0-current)>res && (res=abs(val0-current))
				tasks[i],tasks[j]=tasks[j],tasks[i]
			end
		end
	end
	res
end


# function annealing(n,m,p)
# 	α=0.99
#
# 	progress=ProgressThresh(zero(eltype(p)),"Annealing:")
# 	history=Vector{eltype(p)}(undef,0)
#
# 	tasks=rand(1:m,n)
# 	current=maxTime(tasks,p,m)
# 	threshold=2maxDif(tasks,p,m)
# 	minval=maxTime(tasks,p,m)
# 	minsol=copy(tasks)
# 	count=0
#
# 	push!(history,minval)
# 	while count<1000
# 		changed=false
# 		if rand()<0.5
# 			index=rand(1:n)
# 			value=rand(1:m)
# 			oldvalue=tasks[index]
# 			tasks[index]=value
# 			score=maxTime(tasks,p,m)
# 			if score-current<threshold
# 				current=score
# 			else
# 				tasks[index]=oldvalue
# 			end
# 			if score<current
# 				count=0
# 			else
# 				count+=1
# 			end
# 		else
# 			i=rand(1:n)
# 			j=rand(1:n)
# 			tasks[i],tasks[j]=tasks[j],tasks[i]
# 			score=maxTime(tasks,p,m)
# 			if score-current<threshold
# 				current=score
# 			else
# 				tasks[i],tasks[j]=tasks[j],tasks[i]
# 			end
# 			if score<current
# 				count=0
# 			else
# 				count+=1
# 			end
# 		end
# 		push!(history,current)
# 		if score<minval
# 			# changed=true
# 			minval=score
# 			copy!(minsol,tasks)
# 		end
# 		threshold*=α
# 		# if !changed
# 		# 	count+=1
# 		# else
# 		# 	count=0
# 		# end
# 		ProgressMeter.update!(progress,threshold,showvalues =[(:minval,minval),(:count,count)])
# 	end
# 	ProgressMeter.finish!(progress)
# 	minsol,minval,history
# end
#
# function annealing2(n,m,p)
# 	α=0.99
#
# 	progress=ProgressThresh(zero(eltype(p)),"Stohastic annealing:")
# 	history=Vector{eltype(p)}(undef,0)
#
# 	tasks=rand(1:m,n)
# 	current=maxTime(tasks,p,m)
# 	threshold=2maxDif(tasks,p,m)
# 	minval=maxTime(tasks,p,m)
# 	minsol=copy(tasks)
# 	count=0
#
# 	push!(history,minval)
# 	while count<1000
# 		changed=false
# 		if rand()<0.5
# 			index=rand(1:n)
# 			value=rand(1:m)
# 			oldvalue=tasks[index]
# 			tasks[index]=value
# 			score=maxTime(tasks,p,m)
# 			if score<current
# 				count=0
# 				current=score
# 			else
# 				count+=1
# 				if rand()<exp((current-score)/threshold)
# 					current=score
# 				else
# 					tasks[index]=oldvalue
# 				end
# 			end
# 		else
# 			i=rand(1:n)
# 			j=rand(1:n)
# 			tasks[i],tasks[j]=tasks[j],tasks[i]
# 			score=maxTime(tasks,p,m)
# 			if score<current
# 				count=0
# 				current=score
# 			else
# 				count+=1
# 				if rand()<exp((current-score)/threshold)
# 					current=score
# 				else
# 					tasks[i],tasks[j]=tasks[j],tasks[i]
# 				end
# 			end
# 		end
# 		push!(history,current)
# 		if score<minval
# 			# changed=true
# 			minval=score
# 			copy!(minsol,tasks)
# 		end
# 		threshold*=α
#
# 		ProgressMeter.update!(progress,threshold,showvalues =[(:minval,minval),(:count,count)])
# 	end
# 	ProgressMeter.finish!(progress)
# 	minsol,minval,history
# end
#
# function annealing3(n,m,p)
# 	progress=ProgressThresh(zero(eltype(p)),"Limit annealing:")
# 	history=Vector{eltype(p)}(undef,0)
#
# 	tasks=rand(1:m,n)
# 	current=maxTime(tasks,p,m)
# 	threshold=2current
# 	δ=0.001threshold
# 	minval=maxTime(tasks,p,m)
# 	minsol=copy(tasks)
# 	count=0
#
# 	push!(history,minval)
# 	while count<1000
# 		changed=false
# 		if rand()<0.5
# 			index=rand(1:n)
# 			value=rand(1:m)
# 			oldvalue=tasks[index]
# 			tasks[index]=value
# 			score=maxTime(tasks,p,m)
# 			if score<current
# 				count=0
# 				current=score
# 			else
# 				count+=1
# 				if score<=threshold
# 					current=score
# 				else
# 					tasks[index]=oldvalue
# 				end
# 			end
# 		else
# 			i=rand(1:n)
# 			j=rand(1:n)
# 			tasks[i],tasks[j]=tasks[j],tasks[i]
# 			score=maxTime(tasks,p,m)
# 			if score<current
# 				count=0
# 				current=score
# 			else
# 				count+=1
# 				if score<=threshold
# 					current=score
# 				else
# 					tasks[i],tasks[j]=tasks[j],tasks[i]
# 				end
# 			end
# 		end
# 		push!(history,current)
# 		if score<minval
# 			# changed=true
# 			minval=score
# 			copy!(minsol,tasks)
# 		end
# 		threshold-=δ
#
# 		ProgressMeter.update!(progress,threshold,showvalues =[(:minval,minval),(:count,count)])
# 	end
# 	ProgressMeter.finish!(progress)
# 	minsol,minval,history
# end
