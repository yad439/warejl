using Random
import Base.iterate,Base.eltype

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
