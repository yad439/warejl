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
problem=Problem(parseRealData("res/benchmark - automatic warehouse",50,1),machineCount,carCount,bufferSize,box->box.lineType=="A")
@assert isValid(problem)
sf=let problem=problem
	jobs->computeTimeLazyReturn(jobs,problem,Val(false))
end
sample1=EncodingSample{PermutationEncoding}(problem.jobCount,problem.machineCount)
sample2=EncodingSample{TwoVectorEncoding}(problem.jobCount,problem.machineCount);

st1=rand(sample1)
#sol=computeTimeLazyReturn(st1,problem,Val(true))
#T=sol.schedule.carTasks |> ffilter(e->e.isAdd) |> fmap(e->e.time) |> unique |> length

#exactModel=buildModel(problem,ORDER_FIRST,SEPARATE_EVENTS,T)
#exactRes=runModel(exactModel,1800)
df=CSV.File("test/tabuRes.tsv") |> DataFrame
starts=rand(sample1,10)
sizes=[50,100,200,400,800,1200,1400,1600]
prog=Progress(10*length(sizes))
res=map(sizes) do tabuSize
	#println("Size: ",tabuSize)
	tabuSettings=TabuSearchSettings(1500,tabuSize,1000)
	ress=ThreadsX.map(1:10) do i
		sc=modularTabuSearch5(tabuSettings,sf,deepcopy(starts[i]),false).score
		ProgressMeter.next!(prog)
		sc
	end
	push!(df,(50,1,"A",missing,problem.jobCount,machineCount,carCount,bufferSize,5,1500,tabuSize,1000,minimum(ress),maximum(ress),mean(ress)))
	tabuSize,minimum(ress),maximum(ress),mean(ress)
end
ProgressMeter.finish!(prog);
#println(minimum(res),' ',maximum(res),' ',mean(res))