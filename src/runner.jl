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
using ThreadTools
using ThreadsX
#using DataFrames
#using CSV

machineCount=6
carCount=30
bufferSize=6
problem=Problem(parseRealData("res/benchmark - automatic warehouse",20,4),machineCount,carCount,bufferSize,box->box.lineType=="A")
sf=let problem=problem
	jobs->computeTimeLazyReturn(jobs,problem,Val(false))
end
sample1=EncodingSample{PermutationEncoding}(problem.jobCount,problem.machineCount)
sample2=EncodingSample{TwoVectorEncoding}(problem.jobCount,problem.machineCount);

# st1=rand(sample1)
# sol=computeTimeLazyReturn(st1,problem,Val(true))
# T=sol.schedule.carsTasks |> ffilter(e->e.isAdd) |> fmap(e->e.time) |> unique |> length

# exactModel=buildModel(problem,ORDER_FIRST,SEPARATE_EVENTS_QUAD,T)
# exactRes=runModel(exactModel,1800)
tabuSettings=TabuSearchSettings(1000,300,500)

res=ThreadsX.map(1:10,basesize=10) do _
	modularTabuSearch4(tabuSettings,sf,rand(sample1)).score
end
println(minimum(res),' ',maximum(res),' ',mean(res))