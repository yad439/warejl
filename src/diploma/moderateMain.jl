include("moderateLinear.jl")
include("modularLocal.jl")
include("modularTabu.jl")
include("modularAnnealing.jl")
include("modularGenetic.jl")
include("moderateAuxiliary.jl")

using Plots
using Printf
using Statistics
##
n=10
m=3
p=rand(5:20,n)
k=rand(1:3,n)
tt=10
c=4

# scoreFun=jobs->maxTimeWithCarsUnoptimized(jobs,p,k,m,c,tt)
scoreFun=jobs->maxTimeWithCars(jobs,p,k,m,c,tt)
##
exactRes=moderateExact(n,m,c,p,k,tt,300)
exactRes2=moderateExact2(n,m,c,p,k,tt,300)
localRes1=modularLocalSearch(LocalSearchSettings(changeIterator(randomTwoVectorEncoding(n,m)),false),scoreFun,randomTwoVectorEncoding(n,m))
localRes2=modularLocalSearch(LocalSearchSettings(randomChangeIterator(randomTwoVectorEncoding(n,m),100),false),scoreFun,randomTwoVectorEncoding(n,m))
localRes3=modularLocalSearch(LocalSearchSettings(changeIterator(randomPermutationEncoding(n)),false),scoreFun,randomPermutationEncoding(n))
tabuRes1=modularTabuSearch(TabuSearchSettings(100,100,100),scoreFun,randomTwoVectorEncoding(n,m))
tabuRes2=modularTabuSearch(TabuSearchSettings(100,100,100),scoreFun,randomPermutationEncoding(n))
tabuRes3=modularTabuSearch(TabuSearchSettings2(100,100,0.1),scoreFun,randomTwoVectorEncoding(n,m))
tabuRes4=modularTabuSearch(TabuSearchSettings2(100,100,0.1),scoreFun,randomPermutationEncoding(n))
tmp=randomPermutationEncoding(n)
annealingRes1=modularAnnealing(AnnealingSettings(1000,maxDif(tmp,scoreFun),it->it*0.99,(old,new,threshold)->new-old<threshold),scoreFun,tmp)
tmp=randomTwoVectorEncoding(n,m)
annealingRes2=modularAnnealing(AnnealingSettings(1000,maxDif(tmp,scoreFun),it->it*0.99,(old,new,threshold)->new-old<threshold),scoreFun,tmp)
tmp=randomPermutationEncoding(n)
annealingRes3=modularAnnealing(AnnealingSettings(1000,maxDif(tmp,scoreFun),it->it*0.99,(old,new,threshold)->rand()<exp((old-new)/threshold)),scoreFun,tmp)
tmp=randomTwoVectorEncoding(n,m)
annealingRes4=modularAnnealing(AnnealingSettings(1000,maxDif(tmp,scoreFun),it->it*0.99,(old,new,threshold)->rand()<exp((old-new)/threshold)),scoreFun,tmp)
popul=[begin
	val=randomPermutationEncoding(n)
	score=scoreFun(val)
	GeneticEntity(val,score)
end for _=1:100] |> sort!
crossw=(p1,p2)->PermutationEncoding(pmxCrossover(p1.permutation,p2.permutation))
mutate(val)=val->rand()>0.2 && randomChange!(val,it->true)
geneticRes1=modularGenetic(GeneticSettings(1000,2,crossw,mutate),scoreFun,popul)
popul=[begin
	val=randomTwoVectorEncoding(n,m)
	score=scoreFun(val)
	GeneticEntity(val,score)
end for _=1:100] |> sort!
crossw=(p1,p2)->TwoVectorEncoding(p1.machineCount,elementviseCrossover(p1.assignment,p2.assignment),pmxCrossover(p1.permutation,p2.permutation))
geneticRes2=modularGenetic(GeneticSettings(1000,2,crossw,mutate),scoreFun,popul)
##
sol=computeTimeWithCars(localRes3[2],p,k,m,c,tt)
pl1=plotGantt(sol[1],p)
pl2=plotCarUsage(sol[3],tt,(0,sol[2]))
plr=plot(pl1,pl2,layout=(2,1))