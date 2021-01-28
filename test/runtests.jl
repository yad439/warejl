using Test
using Random

include("../src/utility.jl")
include("../src/mainAuxiliary.jl")

Random.seed!(1234)
@testset "Score function tests" begin
	@testset "Lazy return time computing of $enc" for enc in [PermutationEncoding,TwoVectorEncoding]
		for n=[5,10,20,40],m=[1,2,3,5,10],c=[1,2,5,10,20]
			samp=EncodingSample{enc}(n,m)
			p=rand(5:20,n)
			itemCount=14
			itemsNeeded=[randchoice(1:itemCount,rand(1:8)) for _=1:n]
			itemsNeeded=map(BitSet,itemsNeeded)
			tt=20
			k=length.(itemsNeeded)
			bs=maximum(length.(itemsNeeded))+rand(0:4)
			problem=Problem(n,m,c,tt,itemCount,bs,p,itemsNeeded)
			s=rand(samp)
			sol=@inferred computeTimeLazyReturn(s,problem,Val(true))
			@test sol.time==@inferred computeTimeLazyReturn(s,problem,Val(false))
		end
	end
end