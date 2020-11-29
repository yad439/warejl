include("mainAuxiliary.jl");
include("moderateAuxiliary.jl");
include("utility.jl");
include("modularTabu.jl");
include("modularLocal.jl");
include("modularAnnealing.jl");
include("modularGenetic.jl");

using Random
##
Random.seed!(439)
n=10
m=3
p=rand(5:20,n)
itemCount=16
itemsNeeded=[randsubseq(1:itemCount,0.2) for _=1:n]
tt=10
c=4
k=length.(itemsNeeded)
##
sf1(jobs)=maxTimeWithCars(jobs,p,k,m,c,tt)
sf5(jobs)=maxTimeWithCarsUnoptimized(jobs,p,k,m,c,tt)
sf2(jobs)=computeTimeGetOnly(jobs,m,p,itemsNeeded,c,tt)[2]
sf3(jobs)=computeTimeGetOnlyWaitOne(jobs,m,p,itemsNeeded,c,tt)[2]
sf4(jobs)=computeTimeCancelReturn(jobs,m,p,itemsNeeded,c,tt)[2]
sf=sf5
##
st1=rand(EncodingSample{PermutationEncoding}(n,m))
st2=rand(EncodingSample{TwoVectorEncoding}(n,m))
##
sol1=computeTimeWithCars(st1,p,k,m,c,tt)
sol2=computeTimeGetOnly(st1,m,p,itemsNeeded,c,tt)
##
localRes1=modularLocalSearch(LocalSearchSettings(changeIterator(st1),false),sf,copy(st1))
localRes2=modularLocalSearch(LocalSearchSettings(changeIterator(st2),false),sf,copy(st2))

tabuRes1=modularTabuSearch(TabuSearchSettings(1000,1000,1000),sf,copy(st1))
tabuRes2=modularTabuSearch(TabuSearchSettings(1000,1000,1000),sf,copy(st2))

tmp=copy(st1)
annealingRes1=modularAnnealing(AnnealingSettings(10000,maxDif(tmp,sf),it->it*0.995,(old,new,threshold)->new-old<threshold),sf,tmp)
tmp=copy(st2)
annealingRes2=modularAnnealing(AnnealingSettings(10000,maxDif(tmp,sf),it->it*0.995,(old,new,threshold)->new-old<threshold),sf,tmp)
tmp=copy(st1)
annealingRes3=modularAnnealing(AnnealingSettings(10000,maxDif(tmp,sf),it->it*0.995,(old,new,threshold)->rand()<exp((old-new)/threshold)),sf,tmp)
tmp=copy(st2)
annealingRes4=modularAnnealing(AnnealingSettings(10000,maxDif(tmp,sf),it->it*0.995,(old,new,threshold)->rand()<exp((old-new)/threshold)),sf,tmp)
tmp=copy(st1)
annealingRes5=modularAnnealing(AnnealingSettings(10000,sf(tmp)*2,it->it*0.995,(old,new,threshold)->rand()<exp((old-new)/threshold)),sf,tmp)
tmp=copy(st2)
annealingRes6=modularAnnealing(AnnealingSettings(10000,sf(tmp)*2,it->it*0.995,(old,new,threshold)->rand()<exp((old-new)/threshold)),sf,tmp)

popul=rand(EncodingSample{PermutationEncoding}(n,m),1000) |> (x->(map(val->GeneticEntity(val,sf(val)),x))) |> sort!
crossw=(p1,p2)->PermutationEncoding(pmxCrossover(p1.permutation,p2.permutation))
mutate(val)=val->rand()>0.3 && randomChange!(val,it->true)
geneticRes1=modularGenetic(GeneticSettings(10000,2,crossw,mutate),sf,popul)

popul=rand(EncodingSample{TwoVectorEncoding}(n,m),1000) |> (x->(map(val->GeneticEntity(val,sf(val)),x))) |> sort!
crossw=(p1,p2)->TwoVectorEncoding(p1.machineCount,elementviseCrossover(p1.assignment,p2.assignment),pmxCrossover(p1.permutation,p2.permutation))
geneticRes2=modularGenetic(GeneticSettings(10000,2,crossw,mutate),sf,popul)
##
ress=[localRes1,localRes2,tabuRes1,tabuRes2,annealingRes1,annealingRes2,annealingRes3,annealingRes4,annealingRes5,annealingRes6,geneticRes1,geneticRes2]
rrs=["local 1","local 2","tabu 1","tabu 2","anealing 1","anealing 2","anealing 3","anealing 4","anealing 5","anealing 6","genetic 1","genetic 2"]
foreach((a,b)->println(b,": ",a[1]),ress,rrs)
##
theme(:dark)
##
sol=computeTimeGetOnlyWaitOne(tabuRes1[2],m,p,itemsNeeded,c,tt)
pl1=gantt(sol[1],p,false,string.(itemsNeeded))
pl2=plotCarUsage(sol[3],tt,(0,sol[2]))
plr=plot(pl1,pl2,layout=(2,1))
##
plot(tabuRes1[3][1:10],label=false)
##
sol=computeTimeCancelReturn(st1,m,p,itemsNeeded,c,tt)
cars=normalizeHistory(sol[3],tt)
pl1=gantt(sol[1],p,false,string.(itemsNeeded))
pl2=plotDetailedCarUsage(cars,tt,c,(0,sol[2]))
plr=plot(pl1,pl2,layout=(2,1))