using Random

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
		rand()
	end
	maximum(sums)
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
