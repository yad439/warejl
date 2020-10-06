using Random
using DataStructures

include("$(@__DIR__)/common.jl")

maxTime(jobs::TwoVectorEncoding,jobLengths,machineCount)=maxTime(jobs.assignment,jobLengths,machineCount)
maxTime(jobs::PermutationEncoding,jobLengths,machineCount)=timeOfPermutation(jobs.permutation,jobLengths,machineCount)
computeTimes(jobs::TwoVectorEncoding,jobLengths,machineCount)=computeTimes(jobs.assignment,jobLengths,machineCount)
computeTimes(jobs::PermutationEncoding,jobLengths,machineCount)=computeTimesOfPermutation(jobs.permutation,jobLengths,machineCount)

function maxTime(tasks::Vector{Int},p,m)
	@assert(length(p)==length(tasks))
	sums=fill(zero(eltype(p)),m)
	for (i,task)∈Iterators.enumerate(tasks)
		sums[task]+=p[i]
	end
	maximum(sums)
end

function maxTimeWithCars(jobs::TwoVectorEncoding,jobLengths,carNeeded,machineCount,carCount,carTravelTime)
	sums=fill(zero(eltype(jobLengths)),machineCount)
	inUseCars=Queue{Tuple{eltype(jobLengths),Int}}()
	carsAvailable=carCount
	availableFromTime=0
	for job ∈ jobs.permutation
		# currentTime=availableFromTime
		itemsDelivered=carsAvailable
		if carsAvailable>carNeeded[job]
			carsAvailable-=carNeeded[job]
			enqueue!(inUseCars,(availableFromTime+carTravelTime,carNeeded[job]))
		else
			if carsAvailable≠0
				enqueue!(inUseCars,(availableFromTime+carTravelTime,carsAvailable))
			end
			carsAvailable=0
		end
		currentTime=availableFromTime+carTravelTime
		while itemsDelivered<carNeeded[job]
			(availableFromTime,carsFreed)=dequeue!(inUseCars)

			if carsFreed>carNeeded[job]-itemsDelivered
				carsAvailable=carsFreed-carNeeded[job]+itemsDelivered
				availableFromTime=currentTime
				enqueue!(inUseCars,(currentTime+carTravelTime,carNeeded[job]-itemsDelivered))
			else
				enqueue!(inUseCars,(currentTime+carTravelTime,carsFreed))
			end
			itemsDelivered+=carsFreed
			currentTime=availableFromTime+carTravelTime
		end
		machine=jobs.assignment[job]
		sums[machine]=max(sums[machine],currentTime)+p[job]
	end
	maximum(sums)
end

function maxTimeWithCars(jobs::TwoVectorEncoding,jobLengths,carNeeded,machineCount,carCount,carTravelTime)
	sums=fill(zero(eltype(jobLengths)),machineCount)
	inUseCars=Queue{Tuple{eltype(jobLengths),Int}}()
	carsAvailable=carCount
	availableFromTime=0
	for job ∈ jobs.permutation
		# currentTime=availableFromTime
		itemsDelivered=carsAvailable
		if carsAvailable>carNeeded[job]
			carsAvailable-=carNeeded[job]
			enqueue!(inUseCars,(availableFromTime+carTravelTime,carNeeded[job]))
		else
			if carsAvailable≠0
				enqueue!(inUseCars,(availableFromTime+carTravelTime,carsAvailable))
			end
			carsAvailable=0
		end
		currentTime=availableFromTime+carTravelTime
		while itemsDelivered<carNeeded[job]
			(availableFromTime,carsFreed)=dequeue!(inUseCars)

			if carsFreed>carNeeded[job]-itemsDelivered
				carsAvailable=carsFreed-carNeeded[job]+itemsDelivered
				availableFromTime=currentTime
				enqueue!(inUseCars,(currentTime+carTravelTime,carNeeded[job]-itemsDelivered))
			else
				enqueue!(inUseCars,(currentTime+carTravelTime,carsFreed))
			end
			itemsDelivered+=carsFreed
			currentTime=availableFromTime+carTravelTime
		end
		machine=argmin(sums)
		sums[machine]=max(sums[machine],currentTime)+p[job]
	end
	maximum(sums)
end

function maxTimeWithCarsUnoptimized(jobs::TwoVectorEncoding,jobLengths,carsNeeded,machineCount,carCount,carTravelTime)
	machineTimes=fill(zero(eltype(jobLengths)),machineCount)
	inUseCars=Queue{Tuple{eltype(jobLengths),Int}}()
	carsAvailable=carCount
	carTime=0
	for job ∈ jobs.permutation
		while carsAvailable<carsNeeded[job]
			(carTime,carsFreed)=dequeue!(inUseCars)
			carsAvailable+=carsFreed
		end
		machine=jobs.assignment[job]
		startTime=max(machineTimes[machine],carTime)
		carsAvailable-=carsNeeded[job]
		enqueue!(inUseCars,(startTime+carTravelTime,carsNeeded[job]))
		machineTimes[machine]=startTime+p[job]
	end
	maximum(machineTimes)
end

function maxTimeWithCarsUnoptimized(jobs::PermutationEncoding,jobLengths,carsNeeded,machineCount,carCount,carTravelTime)
	machineTimes=fill(zero(eltype(jobLengths)),machineCount)
	inUseCars=Queue{Tuple{eltype(jobLengths),Int}}()
	carsAvailable=carCount
	carTime=0
	for job ∈ jobs.permutation
		while carsAvailable<carsNeeded[job]
			(carTime,carsFreed)=dequeue!(inUseCars)
			carsAvailable+=carsFreed
		end
		machine=argmin(machineTimes)
		startTime=max(machineTimes[machine],carTime)
		carsAvailable-=carsNeeded[job]
		enqueue!(inUseCars,(startTime+carTravelTime,carsNeeded[job]))
		machineTimes[machine]=startTime+p[job]
	end
	maximum(machineTimes)
end

function timeOfPermutation(tasks::Vector{Int},p,m)
	sums=fill(zero(eltype(p)),m)
	for i ∈ tasks
		minimal=argmin(sums)
		sums[minimal]+=p[i]
	end
	maximum(sums)
end

function timeOfPermutationWithCarPenatly(tasks,p,m,carCount,carTravelTime,penalty)
	sums=fill(zero(eltype(p)),m)
	times=Vector{eltype(p)}(undef,length(tasks))
	for (i,task) ∈ Iterators.enumerate(tasks)
		minimal=argmin(sums)
		times[i]=sums[minimal]
		sums[minimal]+=p[task]
	end
	cars=neededCarCount(times,carTravelTime)
	maximum(sums)+(cars>carCount ? (cars-carCount)penalty : 0)
end

function computeTimes(tasks::Vector{Int},p,m)
	sums=fill(zero(eltype(p)),m)
	times=Vector{eltype(p)}(undef,length(tasks))
	for (i,task)∈Iterators.enumerate(tasks)
		times[i]=sums[task]
		sums[task]+=p[i]
	end
	times
end

function computeTimesOfPermutation(tasks::Vector{Int},p,m)
	sums=fill(zero(eltype(p)),m)
	times=Vector{eltype(p)}(undef,length(tasks))
	for (i,task) ∈ Iterators.enumerate(tasks)
		minimal=argmin(sums)
		times[i]=sums[minimal]
		sums[minimal]+=p[task]
	end
	times
end

function neededCarCount(times,carTravelTime)
	inUseTimes=Queue{eltype(times)}()
	maxUsed=0
	for time ∈ times
		while !isempty(inUseTimes) && first(inUseTimes)<time-carTravelTime
			dequeue!(inUseTimes)
		end
		enqueue!(inUseTimes,time)
		n=length(inUseTimes)
		n>maxUsed && (maxUsed=n)
	end
	maxUsed
end

function neededCarCountHistory(times,carTravelTime)
	inUseTimes=Queue{eltype(times)}()
	history=Vector{Int}(undef,0)
	for time ∈ times
		while !isempty(inUseTimes) && first(inUseTimes)<time-carTravelTime
			dequeue!(inUseTimes)
		end
		enqueue!(inUseTimes,time)
		push!(history,length(inUseTimes))
	end
	history
end

function randchoice(list,count)
	notChosen=BitSet(1:length(list))
	res=Vector{eltype(list)}(undef,count)
	for i=1:count
		val=rand(notChosen)
		res[i]=val
		delete!(notChosen,val)
	end
	res
end
