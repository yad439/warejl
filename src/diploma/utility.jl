using Random
import Base.iterate,Base.eltype
using OffsetArrays

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

changeIterator(::PermutationEncoding,jobCount,_)=((type,arg1,arg2) for type ∈ [PERMUTATION_SWAP,PERMUTATION_MOVE],arg1=1:jobCount,arg2=1:jobCount if arg1≠arg2)
changeIterator(::TwoVectorEncoding,jobCount,machineCount)=IteratorSum(
	((TWO_VECTOR_MOVE_ASSIGNMENT,arg1,arg2) for arg1=1:jobCount,arg2=1:machineCount),
	((type,arg1,arg2) for type ∈ [TWO_VECTOR_SWAP_ASSIGNMENT,TWO_VECTOR_SWAP_ORDER,TWO_VECTOR_MOVE_ORDER],arg1=1:jobCount,arg2=1:jobCount if arg1≠arg2)
)

struct IteratorSum{T1,T2}
	iter1::T1
	iter2::T2
end
function iterate(iter::IteratorSum{T1,T2}) where {T1,T2}
	ret=iterate(iter.iter1)
	ret[1],(1,ret[2])
end
function iterate(iter::IteratorSum{T1,T2},state) where {T1,T2}
	if state[1]==1
		ret=iterate(iter.iter1,state[2])
		if ret≡nothing
			ret=iterate(iter.iter2)
			return ret[1],(2,ret[2])
		end
		return ret[1],(1,ret[2])
	else
		ret=iterate(iter.iter2,state[2])
		return ret≡nothing ? nothing : (ret[1],(2,ret[2]))
	end
end
eltype(iter::IteratorSum{T1,T2}) where {T1,T2}=eltype(iter.iter1)

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
				cost = maxdist
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