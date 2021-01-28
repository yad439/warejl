using JuMP
using LinearAlgebra

function moderateCars(model,itemsNeeded,carCount,carTravelTime,T=ceil(Int,maximum(Iterators.flatten(itemsNeeded))/carCount))
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
		[i=1:jobCount,j in itemsNeeded[i],t=1:T],time[i]≥(1-delivered[t,j])*t*carTravelTime+carTravelTime
		[i=1:carCount,t=1:T],sum(timeSlot[t,:])≤carCount
	end);
end

function simpleMachines(model,jobLengths,machineCount)
	res=model[:res]
	p=jobLengths
	n=length(jobLengths)
	m=machineCount

	@variable(model,x[1:m,1:n],Bin)
	@constraint(model,[i=1:n],sum(x[:,i])==1)
	@constraint(model,[i=1:m],res≥p⋅x[i,:]);
end

function sharedTimesMachines(model,jobLengths,machineCount)
	res=model[:res]
	p=jobLengths
	n=length(jobLengths)
	m=machineCount
	times=unique(jobLengths)
	tl=length(times)
	numbers=Dict(time=>0 for time ∈ times)
	foreach(jobLengths) do time
		numbers[time]+=1
	end

	@variable(model,x[1:m,times]≥0,Int)
	@constraint(model,[i in times],sum(x[:,i])≥numbers[i])
	@constraint(model,[i=1:m],res≥sum(j*x[i,j] for j in times));
end