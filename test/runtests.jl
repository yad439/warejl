using Test
using Random

include("../src/diploma/utility.jl")
include("../src/diploma/mainAuxiliary.jl")

Random.seed!(1234)

@testset "Lazy return time computing of $enc" for enc in [PermutationEncoding,TwoVectorEncoding]
	for n=1:40,m=1:10,c=1:10
		samp=EncodingSample{enc}(n,m)
		p=rand(5:20,n)
		itemCount=14
		itemsNeeded=[randchoice(1:itemCount,rand(1:8)) for _=1:n]
		itemsNeeded=map(BitSet,itemsNeeded)
		tt=20
		k=length.(itemsNeeded)
		bs=maximum(length.(itemsNeeded))+rand(0:4)
		s=rand(samp)
		sol=@inferred computeTimeLazyReturn(s,m,p,itemsNeeded,c,tt,bs,Val(true))
		@test sol.time==@inferred computeTimeLazyReturn(s,m,p,itemsNeeded,c,tt,bs,Val(false))
	end
end