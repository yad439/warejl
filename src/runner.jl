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

machineCount=6
carCount=30
bufferSize=6
problem=Problem(parseRealData("res/benchmark - automatic warehouse",20,4),machineCount,carCount,bufferSize,box->box.lineType=="A")
@assert isValid(problem)
sf=let problem=problem
	jobs->computeTimeLazyReturn(jobs,problem,Val(false))
end
sample1=EncodingSample{PermutationEncoding}(problem.jobCount,problem.machineCount)
sample2=EncodingSample{TwoVectorEncoding}(problem.jobCount,problem.machineCount);

#st1=rand(sample1)
#sol=computeTimeLazyReturn(st1,problem,Val(true))
#T=sol.schedule.carTasks |> ffilter(e->e.isAdd) |> fmap(e->e.time) |> unique |> length
#T=max(T,problem.jobCount)
#M=sol.time
#println(M,' ',T)

#exactModel=buildModel(problem,ORDER_FIRST_STRICT,SHARED_EVENTS_QUAD,T,M)
#exactRes=runModel(exactModel,30*60)
df=CSV.File("test/tabuRes.tsv") |> DataFrame
starts=rand(sample1,10)
sizes=[10,100,500,1000,1400]
prog=Progress(10*length(sizes))
res=map(sizes) do neiSize
	#println("Size: ",tabuSize)
	tabuSettings=TabuSearchSettings(1500,100,neiSize)
	ress=ThreadsX.map(1:10) do i
		sc=modularTabuSearch5(tabuSettings,sf,deepcopy(starts[i]),false).score
		ProgressMeter.next!(prog)
		sc
	end
	push!(df,(20,4,"A",missing,problem.jobCount,machineCount,carCount,bufferSize,5,1500,100,neiSize,minimum(ress),maximum(ress),mean(ress)))
	neiSize,minimum(ress),maximum(ress),mean(ress)
end
ProgressMeter.finish!(prog);
#println(minimum(res),' ',maximum(res),' ',mean(res))