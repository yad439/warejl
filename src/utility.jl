using Random
import Base.iterate,Base.eltype
import Random.rand
using OffsetArrays
using ResumableFunctions

include("common.jl")

function randchoice(list,count)
	notChosen=BitSet(1:length(list))
	res=Vector{eltype(list)}(undef,count)
	for i=1:count
		val=rand(notChosen)
		res[i]=list[val]
		delete!(notChosen,val)
	end
	res
end

struct EncodingSample{T}
	jobCount::Int
	machineCount::Int
	itemCount::Int
end
EncodingSample{T}(jobCount,machineCount) where{T}=EncodingSample{T}(jobCount,machineCount,0)
eltype(::Type{EncodingSample{T}}) where {T}=T
rand(rng::AbstractRNG, d::Random.SamplerTrivial{EncodingSample{PermutationEncoding}})=PermutationEncoding(shuffle(rng,1:d[].jobCount))
rand(rng::AbstractRNG, d::Random.SamplerTrivial{EncodingSample{TwoVectorEncoding}})=TwoVectorEncoding(d[].machineCount,rand(rng,1:d[].machineCount,d[].jobCount),shuffle(rng,1:d[].jobCount))
function rand(rng::AbstractRNG, d::Random.SamplerTrivial{EncodingSample{StateEncoding{T}}}) where{T}
	jobs=rand(EncodingSample{T}(d[].jobCount,d[].machineCount))
	states=rand(Bool,(d[].itemCount,d[].jobCount))|>BitMatrix
	StateEncoding(jobs,states)
end

changeIterator(jobs::PermutationEncoding)=((type,arg1,arg2) for type ∈ [PERMUTATION_SWAP,PERMUTATION_MOVE],arg1=1:length(jobs.permutation),arg2=1:length(jobs.permutation) if arg1≠arg2)
changeIterator(jobs::TwoVectorEncoding)=Iterators.flatten((
	((TWO_VECTOR_MOVE_ASSIGNMENT,arg1,arg2) for arg1=1:length(jobs.permutation),arg2=1:jobs.machineCount),
	((type,arg1,arg2) for type ∈ [TWO_VECTOR_SWAP_ASSIGNMENT,TWO_VECTOR_SWAP_ORDER,TWO_VECTOR_MOVE_ORDER],arg1=1:length(jobs.permutation),arg2=1:length(jobs.permutation) if arg1≠arg2)
))
changeIterator(timetable::StateEncoding{T}) where{T}=Iterators.flatten((
	changeIterator(timetable.machineEncoding),
	((STATE_BITFLIP,arg1,arg2) for arg1=axes(timetable.states,1),arg2=axes(timetable.states,2))
))
randomChangeIterator(jobs,count::Int)=(randomChange(jobs) for _=1:count)
randomChangeIterator(jobs,probability::Float64)=Iterators.filter(_->rand()<probability,changeIterator(jobs))
randomChangeIterator(jobs,count::Int,canDo)=(randomChange(jobs,canDo) for _=1:count)

distance(jobs1::PermutationEncoding,jobs2::PermutationEncoding,)=damerauLevenshteinDistance(jobs1.permutation,jobs2.permutation)
distance(jobs1::TwoVectorEncoding,jobs2::TwoVectorEncoding)=assignmentDistance(jobs1.assignment,jobs2.assignment,jobs1.machineCount)+damerauLevenshteinDistance(jobs1.permutation,jobs2.permutation)
distance(timetable1::StateEncoding{T},timetable2::StateEncoding{T}) where{T}=distance(timetable1.machineEncoding,timetable2.machineEncoding)+hammingDistance(timetable1.states,timetable2.states)
normalizedDistance(jobs1::PermutationEncoding,jobs2::PermutationEncoding)=2distance(jobs1,jobs2)/length(jobs1)
normalizedDistance(jobs1::TwoVectorEncoding,jobs2::TwoVectorEncoding)=distance(jobs1,jobs2)/2length(jobs1)
normalizedDistance(timetable1::StateEncoding{T},timetable2::StateEncoding{T}) where{T}=normalizedDistance(timetable1.machineEncoding,timetable2.machineEncoding)/2+hammingDistance(timetable1.states,timetable2.states)/2length(timetable1.states)

function damerauLevenshteinDistanceOSA(perm1,perm2)
	len=length(perm1)
	@assert length(perm2)==len
	d=OffsetMatrix(Matrix{Int}(undef,len+1,len+1),0:len,0:len)
	d[:,0]=0:len
	d[0,:]=0:len
	for i ∈ eachindex(perm1), j ∈ eachindex(perm2)
		cost=Int(perm1[i]≠perm2[j])
		d[i,j]=min(
			d[i-1,j] + 1, # deletion
			d[i,j-1] + 1, # insertion
			d[i-1,j-1] + cost, # substitution
		)
		if i>1 && j>1 && perm1[i]==perm2[j-1] && perm1[i-1]==perm2[j]
			d[i, j]=min(d[i, j],d[i-2, j-2] + 1)# transposition
		end
	end
	d[len,len]
end

function damerauLevenshteinDistance(a,b)
	n=length(a)
	@assert length(b)==n

	da=zeros(Int,n)
	d=OffsetMatrix(Matrix{Float64}(undef,n+2,n+2),-1:n,-1:n)

	maxdist = 2n
	d[-1, -1]=maxdist
	for i=0:n
		d[i, -1]=maxdist
		d[i, 0]=i/2
		d[-1, i]=maxdist
		d[0, i]=i/2
	end

	for i=1:n
		db = 0
		for j=1:n
			k = da[b[j]]
			l = db
			if a[i] == b[j]
				cost = 0
				db = j
			else
				cost = 0.5
			end
			d[i, j] = min(d[i-1, j-1] + cost,#substitution
							d[i,   j-1] + 0.5,#insertion
							d[i-1, j  ] + 0.5,#deletion
							d[k-1, l-1] + (i-k-1) + 1 + (j-l-1))#transposition
		end
		da[a[i]]=i
	end
	d[n, n]
end

function assignmentDistance(list1,list2,machineCount)
	swap=[Vector{Int}(undef,0) for _=1:machineCount]
	dist=0
	for i ∈ eachindex(list1)
		list1[i]==list2[i] && continue
		ind=findlast(==(list1[i]),swap[list2[i]])
		if ind≡nothing
			dist+=1
			push!(swap[list1[i]],list2[i])
		else
			deleteat!(swap[list2[i]],ind)
		end
	end
	dist
end
hammingDistance(vec1,vec2)=count(it->it[1]≠it[2],Iterators.zip(vec1,vec2))

jobDistance(itemsNeeded)=map(((i,j),)->length(symdiff(i,j)),Iterators.product(itemsNeeded,itemsNeeded))

@resumable function allPermutations(n)
	a=Vector{Int}(1:n)
	p=Vector{Int}(0:n)
	@yield copy(a)
	i=1
	j=0
	while i<n
		p[i+1]-=1
		j=i%2 * p[i+1]
		a[i+1],a[j+1]=a[j+1],a[i+1]
		@yield copy(a)
		i=1
		while p[i+1]==0
			p[i+1]=i
			i+=1
		end
	end
end

function tmap(f,x)
	type=Base.return_types(f,(eltype(x),))
	@assert length(type)==1
	result=similar(x,first(type))
	Threads.@threads for i ∈ eachindex(x)
		result[i]=f(x[i])
	end
	result
end

▷(f,g)=g∘f
fmap(f)=x->map(f,x)
ffilter(f)=x->filter(f,x)
ifmap(f)=x->Iterators.map(f,x)
iffilter(f)=x->Iterators.filter(f,x)
secondElement(x)=x[2]
unzip(a)=map(x->getfield.(a, x), fieldnames(eltype(a)))