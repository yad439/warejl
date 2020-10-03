using Random
using DataStructures

include("$(@__DIR__)/common.jl")

function maxTime(tasks,p,m)
	@assert(length(p)==length(tasks))
	sums=fill(zero(eltype(p)),m)
	for (i,task)∈Iterators.enumerate(tasks)
		sums[task]+=p[i]
	end
	maximum(sums)
end

function maxTimeWithCars(jobs::TwoVectorEncoding,jobLengths,carNeeded,machineCount,carCount,carTravelTime)
	sums=fill(zero(eltype(jobLengths)),machineCount)
	inUseCars=Queue{Tuple{eltype(times),Int}}()
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
		sums[machine]=max(sums[machine],currentTime)+p[i]
	end
	maximum(sums)
end

function timeOfPermutation(tasks,p,m)
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

function computeTimes(tasks,p,m)
	sums=fill(zero(eltype(p)),m)
	times=Vector{eltype(p)}(undef,length(tasks))
	for (i,task)∈Iterators.enumerate(tasks)
		times[i]=sums[task]
		sums[task]+=p[i]
	end
	times
end

function computeTimesOfPermutation(tasks,p,m)
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
		push!(history,length(inUseTimes)
	end
	history
end

function randchoice(rng,list,count)
	notChosen=BitSet(1:length(list))
	res=Vector{eltype(list)}(undef,count)
	for i=1:count
		val=rand(rng,notChosen)
		res[i]=val
		delete!(notChosen,val)
	end
	res
end

randchoice(list,count)=randchoice(Random.GLOBAL_RNG,list,count)
