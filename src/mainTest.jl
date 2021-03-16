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
include("extendedRandoms.jl");
include("io.jl");
include("simlpeHeuristic.jl");

using Random
using DataFrames
using CSV
using ThreadsX
using JuMP
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
	if cnt<=10
		return true
	else
		return false
	end
	return false
end
##
limitCounter=Counter(10)
machineCount=8
carCount=20
bufferSize=5
problem=Problem(parseRealData("res/benchmark - automatic warehouse",100,1),machineCount,carCount,bufferSize,box->box.lineType=="A")
@assert bufferSize≥maximum(length,problem.itemsNeeded)
@assert isValid(problem)
sf=let problem=problem
	jobs->computeTimeLazyReturn(jobs,problem,Val(false),false)
end
sample1=EncodingSample{PermutationEncoding}(problem.jobCount,problem.machineCount)
sample2=EncodingSample{TwoVectorEncoding}(problem.jobCount,problem.machineCount);
##
sol=computeTimeLazyReturn(rand(sample1),problem,Val(true))
T=sol.schedule.carTasks |> ffilter(e->e.isAdd) |> fmap(e->e.time) |> unique |> length
# T=max(T,problem.jobCount)
M=sol.time
##
exactModel=buildModel(problem,ASSIGNMENT_ONLY_SHARED,NO_CARS)
exactRes=runModel(exactModel,30*60).+problem.carTravelTime
##
exactModel=buildModel(problem,ORDER_FIRST,DELIVER_ONLY)
exactRes=runModel(exactModel,30*60)
##
exactModel=buildModel(problem,ORDER_FIRST,BUFFER_ONLY)
exactRes=runModel(exactModel,30*60)
##
exactModel=buildModel(problem,ORDER_FIRST_STRICT,BUFFER_ONLY)
exactRes=runModel(exactModel,30*60).+problem.carTravelTime
##
exactModel=buildModel(problem,ORDER_FIRST_STRICT,SEPARATE_EVENTS,T,M)
exactRes=runModel(exactModel,30*60)
##
exactModel=buildModel(problem,ORDER_FIRST_STRICT,SHARED_EVENTS,T,M)
exactRes=runModel(exactModel,10)
##
exactModel=buildModel(problem,ORDER_FIRST_STRICT,SHARED_EVENTS_QUAD,T,M)
exactRes=runModel(exactModel,10)
##
exactRes[1]+problem.carTravelTime,exactRes[2]+problem.carTravelTime
##
st1=rand(sample1)
st2=rand(sample2);
##
st3=problem.itemsNeeded |> jobDistance |> likehoodBased |> PermutationEncoding;
st4=PermutationEncoding(likehoodBased(jobDistance(getfield(problem,:itemsNeeded)),argmin([sf(PermutationEncoding(likehoodBased(jobDistance(getfield(problem,:itemsNeeded)),i))) for i=1:getfield(problem,:jobCount)])));
##
dist=jobDistance(problem.itemsNeeded)
# tabuSettings=TabuSearchSettings(700,600,1500)
# tabuSettings=TabuSearchSettings3(1000,600,500,200,20)
rdm=PermutationRandomIterable(problem.jobCount,100,0.5,jobDistance(problem.itemsNeeded))
tabuSettings=TabuSearchSettings4(1000,100,(_,cd)->randomChangeIterator(st1,100,cd))
tabuSettings=TabuSearchSettings4(1000,100,rdm)
localSettings=LocalSearchSettings(changeIterator(st1),false)
dif=maxDif(st1,sf)
# steps=round(Int,-log(0.99999,-2dif*log(10^-3))*1.5)
#α=(-dif*log(p))^(-1/10^6)
steps=10^6
same=1
power=(-2dif*log(10^-3))^(-1/(steps/same))
# annealingSettings=AnnealingSettings(steps,true,1,2dif,it->it*0.99999,(old,new,threshold)->rand()<exp((old-new)/threshold))
annealingSettings=AnnealingSettings2(steps,false,same,2dif,it->it*power,(old,new,threshold)->rand()<exp((old-new)/threshold),jobs->controlledPermutationRandom(jobs,0.5,dist))

localRes1=modularLocalSearch(localSettings,sf,deepcopy(st1))
tabuRes1=modularTabuSearch5(tabuSettings,sf,deepcopy(st1))
annealingRes=modularAnnealing(annealingSettings,sf,deepcopy(st1))
##
tmap=Threads.nthreads()>1 ? (f,x)->ThreadsX.map(f,10÷Threads.nthreads(),x) : map
##
df=CSV.File("exp/tabuRes.tsv") |> DataFrame
##
CSV.write("exp/tabuRes.tsv",df,delim='\t')
##
rest=tmap(1:10) do _
	modularTabuSearch5(tabuSettings,sf,rand(sample1)).score
end
##
resa=map(1:10) do _
	st=rand(sample1)
	modularAnnealing(annealingSettings,sf,st).score
end
##
println(minimum(rest),' ',maximum(rest),' ',mean(rest))
println(minimum(resa),' ',maximum(resa),' ',mean(resa))
##
starts=rand(sample1,10);
##
ress=ThreadsX.map(1:10) do i
		println("Start $i")
		sc=modularTabuSearch5(tabuSettings,sf,deepcopy(starts[i]),i==1).score
		#ProgressMeter.next!(prog)
		println("End $i")
		sc
	end
push!(df,(20,4,"A",missing,problem.jobCount,machineCount,carCount,bufferSize,false,5,tabuSettings.searchTries,tabuSettings.tabuSize,1458,minimum(ress),maximum(ress),mean(ress)))
println((minimum(ress),maximum(ress),mean(ress)))
##
sol=computeTimeLazyReturn(st1,problem,Val(true));
##
sol=computeTimeLazyReturn(annealingRes.solution,problem,Val(true));
##
exactModel=buildModel(problem,ORDER_FIRST,SEPARATE_EVENTS)
setStartValues(exactModel,sol.schedule,problem)
exactRes=runModel(exactModel,10)
##
cars=normalizeHistory(sol[3],problem.carTravelTime)
pl1=gantt(sol[1],problem.jobLengths,false,string.(collect.(problem.itemsNeeded)),bw=false)
pl2=plotDetailedCarUsage(cars,problem.carTravelTime,problem.carCount,(0,sol[2]),bw=false,text=false)
pl3=plotDetailedBufferUsage(cars,problem.carTravelTime,problem.bufferSize,(0,sol[2]),bw=false)
plr=plot(pl1,pl3,pl2,layout=(3,1),size=(640,360))
##
addEventBeforeItem=start_value.(exactModel.inner[:addEventBeforeItem])
removeEventBeforeItem=start_value.(exactModel.inner[:removeEventBeforeItem])
T=length(exactModel.inner[:addEventTime])
for i=1:problem.jobCount,item in problem.itemsNeeded[i]
	@assert sum(addEventBeforeItem[τ,i,item] for τ=1:T)-sum(removeEventBeforeItem[τ,i,item] for τ=1:T)≥1 (i,item)
end
##
res=map(prm->(computeTimeLazyReturn(prm,problem,Val(false),false),computeTimeLazyReturn(prm,problem,Val(false),true)),rand(sample1,100000))
res2=map(r->r[1]/r[2],res)
println((maximum(res2),minimum(res2),mean(res2)))
mn1=argmin(map(first,res))
mn2=argmin(map(secondElement,res))
println(mn1==mn2)
println((res[mn1],res[mn2]))
##
prob=Problem(9,3,2,2,8,3,[10,2,8,5,6,6,4,2,1],BitSet.([[1],[2],[2],[3],[4],[5],[6],[6,7],[6,7,8]]))
@assert isValid(prob)
##
model=buildModel(prob,ORDER_FIRST_STRICT,SHARED_EVENTS,12,20)
addItems=model.inner[:addItems]
removeItems=model.inner[:removeItems]
@constraint(model.inner,[τ=1:12],sum(addItems[τ,:])≥sum(removeItems[τ,:]))
res=runModel(model,60*60)
##
res=minimum(1:2factorial(9)) do _
	enc=PermutationEncoding(shuffle(1:9))
	min(computeTimeLazyReturn(enc,prob,Val(false),false),computeTimeLazyReturn(enc,prob,Val(false),true))
end
##
toJson("out/problem.json",problem)