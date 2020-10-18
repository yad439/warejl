using DataStructures
using Plots

include("common.jl")

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

maxTimeWithCars(jobs::TwoVectorEncoding,jobLengths,carNeeded,machineCount,carCount,carTravelTime)=computeTimeWithCars(jobs::TwoVectorEncoding,jobLengths,carNeeded,machineCount,carCount,carTravelTime)[2]
function computeTimeWithCars(jobs::TwoVectorEncoding,jobLengths,carNeeded,machineCount,carCount,carTravelTime)
	sums=fill(zero(eltype(jobLengths)),machineCount)
	times=similar(jobLengths)
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
		startTime=max(sums[machine],currentTime)
		times[job]=startTime
		sums[machine]=startTime+jobLengths[job]
	end
	Schedule(jobs.assignment,times),maximum(sums)
end

maxTimeWithCars(jobs::PermutationEncoding,jobLengths,carNeeded,machineCount,carCount,carTravelTime)=computeTimeWithCars(jobs::TwoVectorEncoding,jobLengths,carNeeded,machineCount,carCount,carTravelTime)[2]
function computeTimeWithCars(jobs::PermutationEncoding,jobLengths,carNeeded,machineCount,carCount,carTravelTime)
	sums=fill(zero(eltype(jobLengths)),machineCount)
	times=similar(jobLengths)
	assignment=similar(jobLengths,Int)
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
		assignment[job]=machine
		startTime=max(sums[machine],currentTime)
		times[job]=startTime
		sums[machine]=startTime+jobLengths[job]
	end
	times,maximum(sums)
end

maxTimeWithCarsUnoptimized(jobs::TwoVectorEncoding,jobLengths,carsNeeded,machineCount,carCount,carTravelTime)=computeTimeWithCarsUnoptimized(jobs::TwoVectorEncoding,jobLengths,carsNeeded,machineCount,carCount,carTravelTime)[2]
function computeTimeWithCarsUnoptimized(jobs::TwoVectorEncoding,jobLengths,carsNeeded,machineCount,carCount,carTravelTime)
	machineTimes=fill(zero(eltype(jobLengths)),machineCount)
	times=similar(jobLengths)
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
		times[job]=startTime
		machineTimes[machine]=startTime+jobLengths[job]
	end
	Schedule(jobs.assignment,times),maximum(machineTimes)
end

maxTimeWithCarsUnoptimized(jobs::PermutationEncoding,jobLengths,carsNeeded,machineCount,carCount,carTravelTime)=computeTimeWithCarsUnoptimized(jobs::PermutationEncoding,jobLengths,carsNeeded,machineCount,carCount,carTravelTime)[2]
function computeTimeWithCarsUnoptimized(jobs::PermutationEncoding,jobLengths,carsNeeded,machineCount,carCount,carTravelTime)
	machineTimes=fill(zero(eltype(jobLengths)),machineCount)
	times=similar(jobLengths)
	assignment=similar(jobLengths,Int)
	inUseCars=Queue{Tuple{eltype(jobLengths),Int}}()
	carsAvailable=carCount
	carTime=0
	for job ∈ jobs.permutation
		while carsAvailable<carsNeeded[job]
			(carTime,carsFreed)=dequeue!(inUseCars)
			carsAvailable+=carsFreed
		end
		machine=argmin(machineTimes)
		assignment[job]=machine
		startTime=max(machineTimes[machine],carTime)
		carsAvailable-=carsNeeded[job]
		enqueue!(inUseCars,(startTime+carTravelTime,carsNeeded[job]))
		times[job]=startTime
		machineTimes[machine]=startTime+jobLengths[job]
	end
	Schedule(assignment,times),maximum(machineTimes)
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

struct Schedule
	assignment::Vector{Int}
	times::Vector{Int}
end

@recipe function scheduleToGantt(jobs::Schedule,jobLengths)
	n=length(jobs.assignment)
	@assert length(jobs.times)==n
	@assert length(jobLengths)==n
	shapes=[
		Shape([
			(jobs.times[i],jobs.assignment[i]-1),
			(jobs.times[i],jobs.assignment[i]),
			(jobs.times[i]+jobLengths[i],jobs.assignment[i]),
			(jobs.times[i]+jobLengths[i],jobs.assignment[i]-1)
		])
	for i=1:n]
	#label:=["job $i" for i=1:n]
	shapes
end