using JuMP

#=function moderateCars(model,itemsNeeded,carCount,carTravelTime,T=ceil(Int,maximum(Iterators.flatten(itemsNeeded))/carCount))
	itemCount=maximum(Iterators.flatten(itemsNeeded))
	jobCount=length(itemsNeeded)
	time=model[:startTime]
	@assert length(time)==jobCount
	@variables(model,begin
		timeSlot[1:T,1:itemCount],Bin
		delivered[1:T,1:itemCount],Bin
	end)
	@constraints(model,begin
		[t=1:T,i=1:itemCount],delivered[t,i]≤sum(timeSlot[1:t,i])
		[i=1:jobCount,j in itemsNeeded[i]],time[i]≥sum(1 .- delivered[:,j])carTravelTime+carTravelTime
		[i=1:carCount,t=1:T],sum(timeSlot[t,:])≤carCount
	end);
end=#

#=function simpleMachines(model,jobLengths,machineCount)
	res=model[:res]
	p=jobLengths
	n=length(jobLengths)
	m=machineCount

	@variable(model,x[1:m,1:n],Bin)
	@constraint(model,[i=1:n],sum(x[:,i])==1)
	@constraint(model,[i=1:m],res≥p⋅x[i,:])
	nothing
end=#

function sharedTimesMachines(model,jobLengths,machineCount)
	res=model[:res]
	# p=jobLengths
	# n=length(jobLengths)
	m=machineCount
	times=unique(jobLengths)
	# tl=length(times)
	numbers=Dict(time=>0 for time ∈ times)
	foreach(jobLengths) do time
		numbers[time]+=1
	end

	@variable(model,0≤x[1:m,i in times]≤numbers[i],Int)
	@constraint(model,[i in times],sum(x[:,i])≥numbers[i])
	@constraint(model,[i=1:m],res≥sum(j*x[i,j] for j in times))
	nothing
end

function bufferOnlyCars(model,problem,M)
	t=model[:startTime]
	p=problem.jobLengths
	n=problem.jobCount
	ic=problem.itemCount
	ineed=problem.itemsNeeded
	bs=problem.bufferSize

	@variables(model,begin
		later[i=1:n,j=1:n;i≠j],Bin
		beforeEnd[i=1:n,j=1:n;i≠j],Bin
	end)
	@constraints(model,begin
		[i=1:n,j=1:n;i≠j],t[i]≤t[j]-1+M*later[i,j]
		[i=1:n,j=1:n;i≠j],t[i]≥t[j]+p[j]-M*beforeEnd[i,j]
	end)
	@variable(model,bufferItem[i=1:n,l=1:ic;l ∉ ineed[i]],Bin)
	@constraints(model,begin
		[i=1:n,j=1:n;i≠j && !issetequal(ineed[j],ineed[i])],sum(bufferItem[i,l] for l ∈ ineed[j] if l ∉ ineed[i])≥(later[i,j]+beforeEnd[i,j]-1)*length(setdiff(ineed[j],ineed[i]))
		[i=1:n],sum(bufferItem[i,l] for l=1:ic if l ∉ ineed[i])+length(ineed[i])≤bs
	end)
	nothing
end