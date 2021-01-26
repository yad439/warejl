include("mainAuxiliary.jl");
include("moderateAuxiliary.jl");
include("utility.jl");
include("auxiliary.jl")
include("modularTabu.jl");
include("modularLocal.jl");
include("modularAnnealing.jl");
include("modularGenetic.jl");
include("realDataUtility.jl");
include("modularLinear.jl");

using Random
using DataFrames
using CSV
##
Random.seed!(4350)
n=10
m=3
p=rand(5:20,n)
itemCount=14
itemsNeeded=[randsubseq(1:itemCount,0.1) for _=1:n]
itemsNeeded=map(BitSet,itemsNeeded)
tt=10
c=6
k=length.(itemsNeeded)
bs=4
@assert bs≥maximum(length.(itemsNeeded))
##
rdata=parseRealData("res/benchmark - automatic warehouse",20,4)
rdt=toModerateJobs(rdata,box->box.lineType=="A")
n=length(rdt[1])
m=6
p=rdt[1]
itemsNeeded=rdt[2]
itemsNeeded=map(BitSet,itemsNeeded)
tt=rdt[3]
c=20
bs=6
@assert bs≥maximum(length.(itemsNeeded))
##
m=6
c=20
bs=6
problem=Problem(parseRealData("res/benchmark - automatic warehouse",20,4),m,c,bs,box->box.lineType=="A")
##
sf1(jobs)=maxTimeWithCars(jobs,p,k,m,c,tt)
sf5(jobs)=maxTimeWithCarsUnoptimized(jobs,p,k,m,c,tt)
sf2(jobs)=computeTimeGetOnly(jobs,m,p,itemsNeeded,c,tt)[2]
sf3(jobs)=computeTimeGetOnlyWaitOne(jobs,m,p,itemsNeeded,c,tt)[2]
sf4(jobs)=computeTimeCancelReturn(jobs,m,p,itemsNeeded,c,tt,bs)[2]
sf6(jobs)=computeTimeLazyReturn(jobs,problem,Val(false))
sf=sf6
##
sf=let problem=problem
	jobs->computeTimeLazyReturn(jobs,problem,Val(false))
end
##
# Random.seed!(4350)
st1=rand(EncodingSample{PermutationEncoding}(n,m))
st2=rand(EncodingSample{TwoVectorEncoding}(n,m))
##
sol1=computeTimeWithCars(st1,p,k,m,c,tt)
sol2=computeTimeGetOnly(st1,m,p,itemsNeeded,c,tt)
##
localRes1=modularLocalSearch(LocalSearchSettings(changeIterator(st1),false),sf,copy(st1))
localRes2=modularLocalSearch(LocalSearchSettings(changeIterator(st2),false),sf,copy(st2))

tabuRes1=modularTabuSearch(TabuSearchSettings(250,1000,2000),sf,copy(st1))
tabuRes2=modularTabuSearch(TabuSearchSettings(100,1000,100),sf,copy(st2))

tmp=copy(st1)
annealingRes1=modularAnnealing(AnnealingSettings(100000,maxDif(tmp,sf),it->it*0.9999,(old,new,threshold)->new-old<threshold),sf,tmp)

tmp=copy(st2)
annealingRes2=modularAnnealing(AnnealingSettings(10000,maxDif(tmp,sf),it->it*0.995,(old,new,threshold)->new-old<threshold),sf,tmp)

tmp=copy(st1)
annealingRes3=modularAnnealing(AnnealingSettings(10000,maxDif(tmp,sf),it->it*0.995,(old,new,threshold)->rand()<exp((old-new)/threshold)),sf,tmp)

tmp=copy(st2)
annealingRes4=modularAnnealing(AnnealingSettings(10000,maxDif(tmp,sf),it->it*0.995,(old,new,threshold)->rand()<exp((old-new)/threshold)),sf,tmp)

tmp=copy(st1)
annealingRes5=modularAnnealing(AnnealingSettings(100000,sf(tmp)*2,it->it*0.9999,(old,new,threshold)->rand()<exp((old-new)/threshold)),sf,tmp)

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
sol=computeTimeLazyReturn(tabuRes1[2],m,p,itemsNeeded,c,tt,bs,Val(true));
##
sol=computeTimeLazyReturn(st1,m,p,itemsNeeded,c,tt,bs,Val(true))
@assert sol[2]==computeTimeLazyReturn(st1,m,p,itemsNeeded,c,tt,bs,Val(false))
##
cars=normalizeHistory(sol[3],tt)
pl1=gantt(sol[1],p,false,string.(collect.(itemsNeeded)))
pl2=plotDetailedCarUsage(cars,tt,c,(0,sol[2]))
pl3=plotDetailedBufferUsage(cars,tt,bs,(0,sol[2]))
plr=plot(pl1,pl3,pl2,layout=(3,1),size=(1500,400))
##
for i=1:length(sol[4])
	cars=normalizeHistory(sol[4][i],tt)
	pl1=gantt(sol[1],p,false,string.(itemsNeeded))
	pl2=plotDetailedCarUsage(cars,tt,c,(0,sol[2]))
	plr=plot(pl1,pl2,layout=(2,1))
	# png(plr,"out/fopt_$i")
	display(plr)
end
##
df=DataFrame(m=Int[],c=Int[],bs=Int[],time=Int[],cars=Int[])
lk=ReentrantLock()
Threads.@threads for c ∈ [10,20,30,40,50,60]
	for m ∈ [6,12], bs ∈ [10,12,14,16]
		sf=let m=m,p=p,itemsNeeded=itemsNeeded,c=c,tt=tt,bs=bs
			jobs->computeTimeLazyReturn(jobs,m,p,itemsNeeded,c,tt,bs,Val(false))
		end
		tabuRes1=modularTabuSearch(TabuSearchSettings(250,1000,2000),sf,copy(st1))
		sol=computeTimeLazyReturn(tabuRes1[2],m,p,itemsNeeded,c,tt,bs,Val(true));
		@assert tabuRes1.score==sol.time
		cars=normalizeHistory(sol[3],tt)
		lock(lk)
		pl1=gantt(sol[1],p,false,string.(collect.(itemsNeeded)))
		pl2=plotDetailedCarUsage(cars,tt,c,(0,sol[2]))
		pl3=plotDetailedBufferUsage(cars,tt,bs,(0,sol[2]))
		plr=plot(pl1,pl3,pl2,layout=(3,1),size=(1500,600))
		png(plr,"out/plt_short2_m$(m)_c$(c)_b$(bs)")
		push!(df,(m,c,bs,sol.time,countCars(cars,tt)|>fmap(secondElement)|>maximum))
		unlock(lk)
	end
end
CSV.write("out/short2.tsv",df,delim='\t')
##
# model=buildModel(p,m,itemsNeeded,c,tt,bs)
# runModel(model)
##
cnt=0
function flt(box)
	if box.lineType!="A"
		return false
	end
	global cnt+=1
	if cnt<=5
		return true
	else
		return false
	end
	return false
end
##
machineCount=6
carCount=30
bufferSize=6
problem=Problem(parseRealData("res/benchmark - automatic warehouse",20,4),machineCount,carCount,bufferSize,box->box.lineType=="A")
sf=let problem=problem
	jobs->computeTimeLazyReturn(jobs,problem,Val(false))
end
sample1=EncodingSample{PermutationEncoding}(problem.jobCount,problem.machineCount)
sample2=EncodingSample{TwoVectorEncoding}(problem.jobCount,problem.machineCount);
##
exactModel=buildModel(problem,ORDER_FIRST,DELIVER_ONLY)
exactRes=runModel(exactModel,300)
##
st1=rand(sample1)
st2=rand(sample2);
##
# tabuSettings=TabuSearchSettings(1000,900,500)
tabuSettings=TabuSearchSettings3(1000,600,500,200,20)
localSettings=LocalSearchSettings(changeIterator(st1),false)
annealingSettings=AnnealingSettings(1000000,2maxDif(st1,sf),it->it*0.99999,(old,new,threshold)->rand()<exp((old-new)/threshold))

# localRes1=modularLocalSearch(localSettings,sf,deepcopy(st1))
tabuRes1=modularTabuSearch5(tabuSettings,sf,deepcopy(st1))
annealingRes=modularAnnealing(annealingSettings,sf,deepcopy(st1))
##
res=[]
for _=1:10
	st=rand(sample1)
	tabuRes=modularTabuSearch(tabuSettings,sf,deepcopy(st))
	push!(res,tabuRes.score)
end
##
sol=computeTimeLazyReturn(st1,problem,Val(true));
##
exactModel=buildModel(problem,ORDER_FIRST,SEPARATE_EVENTS)
setStartValues(exactModel,sol.schedule,problem)
exactRes=runModel(exactModel,10)
##
cars=normalizeHistory(sol[3],problem.carTravelTime)
pl1=gantt(sol[1],problem.jobLengths,false,string.(collect.(problem.itemsNeeded)))
pl2=plotDetailedCarUsage(cars,problem.carTravelTime,problem.carCount,(0,sol[2]))
pl3=plotDetailedBufferUsage(cars,problem.carTravelTime,problem.bufferSize,(0,sol[2]))
plr=plot(pl1,pl3,pl2,layout=(3,1),size=(1500,400))
##
addEventBeforeItem=start_value.(exactModel.inner[:addEventBeforeItem])
removeEventBeforeItem=start_value.(exactModel.inner[:removeEventBeforeItem])
T=length(exactModel.inner[:addEventTime])
for i=1:problem.jobCount,item in problem.itemsNeeded[i]
	@assert sum(addEventBeforeItem[τ,i,item] for τ=1:T)-sum(removeEventBeforeItem[τ,i,item] for τ=1:T)≥1 (i,item)
end