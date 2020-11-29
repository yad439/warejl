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
n=250
m=3
p=rand(5:20,n)
k=rand(1:5,n)
tt=10
c=5

scoreFun=jobs->maxTimeWithCarsUnoptimized(jobs,p,k,m,c,tt)
# scoreFun=jobs->maxTimeWithCars(jobs,p,k,m,c,tt)
##
stsol1=rand(EncodingSample{PermutationEncoding}(n,m))
stsol2=rand(EncodingSample{TwoVectorEncoding}(n,m))
##
# exactRes=moderateExact(n,m,c,p,k,tt,300)
# exactRes2=moderateExact2(n,m,c,p,k,tt,300)
localRes1=modularLocalSearch(LocalSearchSettings(changeIterator(stsol1),false),scoreFun,copy(stsol1))
# localRes2=modularLocalSearch(LocalSearchSettings(randomChangeIterator(stsol1,100),false),scoreFun,copy(stsol1))
localRes3=modularLocalSearch(LocalSearchSettings(changeIterator(stsol2),false),scoreFun,copy(stsol2))
tabuRes1=modularTabuSearch(TabuSearchSettings(1000,1000,100),scoreFun,copy(stsol2))
tabuRes2=modularTabuSearch(TabuSearchSettings(1000,1000,100),scoreFun,copy(stsol1))
# tabuRes3=modularTabuSearch(TabuSearchSettings2(1000,1000,0.1),scoreFun,copy(stsol2))
# tabuRes4=modularTabuSearch(TabuSearchSettings2(1000,1000,0.1),scoreFun,copy(stsol1))
tmp=copy(stsol1)
annealingRes1=modularAnnealing(AnnealingSettings(10000,maxDif(tmp,scoreFun),it->it*0.99,(old,new,threshold)->new-old<threshold),scoreFun,tmp)
tmp=copy(stsol2)
annealingRes2=modularAnnealing(AnnealingSettings(10000,maxDif(tmp,scoreFun),it->it*0.99,(old,new,threshold)->new-old<threshold),scoreFun,tmp)
tmp=copy(stsol1)
annealingRes3=modularAnnealing(AnnealingSettings(10000,maxDif(tmp,scoreFun),it->it*0.99,(old,new,threshold)->rand()<exp((old-new)/threshold)),scoreFun,tmp)
tmp=copy(stsol2)
annealingRes4=modularAnnealing(AnnealingSettings(10000,maxDif(tmp,scoreFun),it->it*0.99,(old,new,threshold)->rand()<exp((old-new)/threshold)),scoreFun,tmp)
tmp=copy(stsol1)
annealingRes5=modularAnnealing(AnnealingSettings(10000,scoreFun(tmp)*2,it->it*0.99,(old,new,threshold)->rand()<exp((old-new)/threshold)),scoreFun,tmp)
tmp=copy(stsol2)
annealingRes6=modularAnnealing(AnnealingSettings(10000,scoreFun(tmp)*2,it->it*0.99,(old,new,threshold)->rand()<exp((old-new)/threshold)),scoreFun,tmp)
popul=[begin
	val=randomPermutationEncoding(n)
	score=scoreFun(val)
	GeneticEntity(val,score)
end for _=1:1000] |> sort!
crossw=(p1,p2)->PermutationEncoding(pmxCrossover(p1.permutation,p2.permutation))
mutate(val)=val->rand()>0.2 && randomChange!(val,it->true)
geneticRes1=modularGenetic(GeneticSettings(1000,2,crossw,mutate),scoreFun,popul)
popul=[begin
	val=randomTwoVectorEncoding(n,m)
	score=scoreFun(val)
	GeneticEntity(val,score)
end for _=1:1000] |> sort!
crossw=(p1,p2)->TwoVectorEncoding(p1.machineCount,elementviseCrossover(p1.assignment,p2.assignment),pmxCrossover(p1.permutation,p2.permutation))
geneticRes2=modularGenetic(GeneticSettings(1000,2,crossw,mutate),scoreFun,popul)
##
ress=[localRes1,localRes3,tabuRes1,tabuRes2,annealingRes1,annealingRes2,annealingRes3,annealingRes4,annealingRes5,annealingRes6,geneticRes1,geneticRes2]
rrs=["local 1","local 3","tabu 1","tabu 2","anealing 1","anealing 2","anealing 3","anealing 4","anealing 5","anealing 6","genetic 1","genetic 2"]
foreach((a,b)->println(b,": ",a[1]),ress,rrs)
##
sol=computeTimeWithCars(tabuRes1[2],p,k,m,c,tt)
pl1=gantt(sol[1],p,false)
pl2=plotCarUsage(sol[3],tt,(0,sol[2]))
plr=plot(pl1,pl2,layout=(2,1))