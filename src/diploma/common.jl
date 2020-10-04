using Random
import Base.copy,Base.copy!

struct TwoVectorEncoding
	assignment::Vector{Int}
	permutation::Vector{Int}
end

struct PermutationEncoding
	permutation::Vector{Int}
end

randomTwoVectorEncoding(jobCount,machineCount)=TwoVectorEncoding(rand(1:machineCount,jobCount),shuffle(1:jobCount))
randomPermutationEncoding(jobCount)=PermutationEncoding(shuffle(1:jobCount))
copy(jobs::TwoVectorEncoding)=TwoVectorEncoding(copy(jobs.assignment),copy(jobs.permutation))
copy(jobs::PermutationEncoding)=PermutationEncoding(copy(jobs.permutation))
copy!(dst::PermutationEncoding, src::PermutationEncoding)=copy!(dst.permutation,src.permutation)
function copy!(dst::TwoVectorEncoding, src::TwoVectorEncoding)
	copy!(dst.assignment,src.assignment)
	copy!(dst.permutation,src.permutation)
end

function randomChange!(jobs::TwoVectorEncoding,canDo,jobCount,machineCount)
	while true
		type=rand([TWO_VECTOR_MOVE_ASSIGNMENT,TWO_VECTOR_SWAP_ASSIGNMENT,TWO_VECTOR_MOVE_ORDER,TWO_VECTOR_SWAP_ORDER])
		arg1=rand(1:jobCount)
		arg2=rand(1:(type≠TWO_VECTOR_MOVE_ASSIGNMENT ? jobCount : machineCount))
		arg1==arg2 && type≠TWO_VECTOR_MOVE_ASSIGNMENT && continue
		type==TWO_VECTOR_MOVE_ASSIGNMENT && jobs.assignment[arg1]==arg2 && continue
		canDo((type,arg1,arg2)) || continue
		return (type,arg1,arg2),change!(jobs,type,arg1,arg2)
	end
end
function randomChange!(jobs::PermutationEncoding,canDo,jobCount,machineCount)
	while true
		type=rand([PERMUTATION_MOVE,PERMUTATION_SWAP])
		arg1=rand(1:jobCount)
		arg2=rand(1:jobCount)
		arg1==arg2 && continue
		canDo((type,arg1,arg2)) || continue
		return (type,arg1,arg2),change!(jobs,type,arg1,arg2)
	end
end
change!(jobs,(type,arg1,arg2))=change!(jobs,type,arg1,arg2)
function change!(jobs::TwoVectorEncoding,type,arg1,arg2)
	if type==TWO_VECTOR_MOVE_ASSIGNMENT
		old=jobs.assignment[arg1]
		jobs.assignment[arg1]=arg2
		return TWO_VECTOR_MOVE_ASSIGNMENT,arg1,old
	elseif type==TWO_VECTOR_SWAP_ASSIGNMENT
		jobs.assignment[pos1],jobs.assignment[pos2]=jobs.assignment[pos2],jobs.assignment[pos1]
		return TWO_VECTOR_SWAP_ASSIGNMENT,arg1,arg2
	elseif type==TWO_VECTOR_MOVE_ORDER
		val=jobs.permutation[arg1]
		deleteat!(jobs.permutation,arg1)
		insert!(jobs.permutation,arg2,val)
		return TWO_VECTOR_MOVE_ORDER,arg2,arg1
	elseif type==TWO_VECTOR_SWAP_ORDER
		jobs.permutation[pos1],jobs.permutation[pos2]=jobs.permutation[pos2],jobs.permutation[pos1]
		return TWO_VECTOR_SWAP_ORDER,arg1,arg2
	end
	@assert false type
end
function change!(jobs::PermutationEncoding,type,arg1,arg2)
	if type==PERMUTATION_MOVE
		val=jobs.permutation[arg1]
		deleteat!(jobs.permutation,arg1)
		insert!(jobs.permutation,arg2,val)
		return PERMUTATION_MOVE,arg2,arg1
	elseif type==PERMUTATION_SWAP
		jobs.permutation[arg1],jobs.permutation[arg2]=jobs.permutation[arg2],jobs.permutation[arg1]
		return PERMUTATION_SWAP,arg1,arg2
	end
	@assert false type
end

const PERMUTATION_MOVE=10
const PERMUTATION_SWAP=11
const TWO_VECTOR_MOVE_ASSIGNMENT=12
const TWO_VECTOR_SWAP_ASSIGNMENT=13
const TWO_VECTOR_MOVE_ORDER=14
const TWO_VECTOR_SWAP_ORDER=15
