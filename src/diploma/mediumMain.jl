include("simpleLinear.jl")
include("mediumLocal.jl")
include("modularTabu.jl")

using Plots
using Printf
using Statistics

n=100
m=5
# p=rand(n)*1000
# p=rand(n)*4 .+1
p=rand(1:100,n)

exactSol=exact(n,m,p)
localRes1=localTabu2(n,m,p,TabuSearchSettings(100,10,100))
localRes2=localTabu3(n,m,p,TabuSearchSettings(100,10,100))
localRes3=modularTabuSearch(n,m,TabuSearchSettings(100,10,100),jobs->maxTime(jobs,p,m),randomPermutationEncoding(n))
localRes4=modularTabuSearch(n,m,TabuSearchSettings(100,10,100),jobs->maxTime(jobs,p,m),randomTwoVectorEncoding(n,m))

@printf("Local tabu (permutation): %f%%\n",100(localRes1[2]/exactSol[2])-100)
@printf("Local tabu (double): %f%%\n",100(localRes2[2]/exactSol[2])-100)
@printf("Local tabu (permutation): %f%%\n",100(localRes3[2]/exactSol[2])-100)
@printf("Local tabu (double): %f%%\n",100(localRes4[2]/exactSol[2])-100)

plot(localRes1[3])
plot(localRes2[3])
plot(localRes3[3])
plot(localRes4[3])

plot(neededCarCountHistory(computeTimesOfPermutation(localRes1[1],p,m),50))
plot(neededCarCountHistory(computeTimes(localRes2[1],p,m),50))
plot(neededCarCountHistory(computeTimes(localRes3[1],p,m),50))
plot(neededCarCountHistory(computeTimes(localRes4[1],p,m),50))

rep=map(1:10) do _
	pl=rand(n)*10
	exactSoll=exact(n,m,pl)
	localRes1l=localTabu2(n,m,pl,TabuSearchSettings(200,50,1000))
	localRes2l=localTabu3(n,m,pl,TabuSearchSettings(200,50,1000))
	100(localRes1l[2]/exactSoll[2])-100,100(localRes2l[2]/exactSoll[2])-100
end
