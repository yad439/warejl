using Random
using DataStructures

function maxTime(tasks,p,m)
	@assert(length(p)==length(tasks))
	sums=fill(zero(eltype(p)),m)
	for (i,task)∈Iterators.enumerate(tasks)
		sums[task]+=p[i]
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
