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
			bs=maximum(length,itemsNeeded)+rand(0:4)
			problem=Problem(n,m,c,tt,itemCount,bs,p,itemsNeeded)
			#@assert isValid(problem)
			s=rand(samp)
			sol=@inferred computeTimeLazyReturn(s,problem,Val(true))
			@test isValid(sol.schedule,problem)
			@test sol.time==@inferred computeTimeLazyReturn(s,problem,Val(false))
		end
	end
end

@testset "Solution improving" begin
	prob=Problem(9,3,2,2,8,3,[10,2,8,5,6,6,4,2,1],BitSet.([[1],[2],[2],[3],[4],[5],[6],[6,7],[6,7,8]]))
	@assert isValid(prob)
	sol,=computeTimeLazyReturn(PermutationEncoding(1:9),prob,Val(true))
	sol2=improveSolution(sol,prob)

	@test isValid(sol,prob)
	@test isValid(sol2,prob)
	@test maximum(((s,p),)->s+p,zip(sol2.times,prob.jobLengths))==17
end

@testset "Distance tests" begin
	@testset "Damerau–Levenshtein distance" begin
		@test abs(damerauLevenshteinDistance(1:10,1:10))<0.01
		@test abs(damerauLevenshteinDistance([2,7,1,5,9,3,8,6,4,10],[2,7,1,5,9,3,8,6,4,10]))<0.01
		@test damerauLevenshteinDistance(1:10,[1,9,3,4,5,6,7,8,2,10])≈1
		@test damerauLevenshteinDistance(1:10,[1,3,4,5,6,7,8,2,9,10])≈1
		@test damerauLevenshteinDistance(1:10,[1,9,3,10,5,6,7,8,2,4])≈2
		@test damerauLevenshteinDistance(1:10,[1,3,4,6,7,8,5,2,9,10])≈2
	end
	@testset "Permutation distance" begin
		ord=PermutationEncoding(1:10)
		@test abs(distance(ord,ord))<0.01
		@test abs(distance(PermutationEncoding([2,7,1,5,9,3,8,6,4,10]),PermutationEncoding([2,7,1,5,9,3,8,6,4,10])))<0.01
		@test distance(ord,PermutationEncoding([1,9,3,4,5,6,7,8,2,10]))≈1
		@test distance(ord,PermutationEncoding([1,3,4,5,6,7,8,2,9,10]))≈1
		@test distance(ord,PermutationEncoding([1,9,3,10,5,6,7,8,2,4]))≈2
		@test distance(ord,PermutationEncoding([1,3,4,6,7,8,5,2,9,10]))≈2
	end
end