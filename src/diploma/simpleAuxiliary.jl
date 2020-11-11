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


function timeOfPermutation(tasks::Vector{Int},p,m)
	sums=fill(zero(eltype(p)),m)
	for i ∈ tasks
		minimal=argmin(sums)
		sums[minimal]+=p[i]
	end
	maximum(sums)
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