include("mainAuxiliary.jl");
#include("moderateAuxiliary.jl");
#include("utility.jl");
#include("auxiliary.jl")
include("modularTabu.jl");
#include("modularLocal.jl");
include("modularAnnealing.jl");
#include("modularGenetic.jl");
include("realDataUtility.jl");
include("modularLinear.jl");

using Random
#using ThreadTools
using ThreadsX
using DataFrames
using CSV
using Statistics
#using ProgressMeter

machineCount=8
carCount=20
bufferSize=5
problem=Problem(parseRealData("res/benchmark - automatic warehouse",100,1),machineCount,carCount,bufferSize,box->box.lineType=="A")
@assert isValid(problem)
@assert problem.bufferSize>=maximum(length,problem.itemsNeeded)
sf=let problem=problem
	jobs->computeTimeLazyReturn(jobs,problem,Val(false))
end
sample1=EncodingSample{PermutationEncoding}(problem.jobCount,problem.machineCount)
sample2=EncodingSample{TwoVectorEncoding}(problem.jobCount,problem.machineCount);
println(problem.jobCount)
#st1=rand(sample1)
#sol=computeTimeLazyReturn(st1,problem,Val(true))
#T=sol.schedule.carTasks |> ffilter(e->e.isAdd) |> fmap(e->e.time) |> unique |> length
#T=max(T,problem.jobCount)
#M=sol.time
#println(M,' ',T)

#exactModel=buildModel(problem,ORDER_FIRST_STRICT,SHARED_EVENTS,T,M)
#exactRes=runModel(exactModel,30*60)
df=CSV.File("test/tabuRes.tsv") |> DataFrame
starts=rand(sample1,10)
sizes=[50,100,500,1000,2000]
#prog=Progress(10*length(sizes))
res=map(sizes) do tabuSize
	println("Size: ",tabuSize)
	tabuSettings=TabuSearchSettings(2000,tabuSize,1000)
	ress=ThreadsX.map(1:10) do i
		println("Start $i")
		sc=modularTabuSearch5(tabuSettings,sf,deepcopy(starts[i]),i==1).score
		#ProgressMeter.next!(prog)
		println("End $i")
		sc
	end
	push!(df,(100,1,"A",missing,problem.jobCount,machineCount,carCount,bufferSize,5,2000,tabuSize,1000,minimum(ress),maximum(ress),mean(ress)))
	tabuSize,minimum(ress),maximum(ress),mean(ress)
end
#ProgressMeter.finish!(prog);
#println(minimum(res),' ',maximum(res),' ',mean(res))