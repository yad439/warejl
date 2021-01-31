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

machineCount=4
carCount=30
bufferSize=6
problem=Problem(parseRealData("res/benchmark - automatic warehouse",20,4),machineCount,carCount,bufferSize,box->box.lineType=="A")
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
#df=DataFrame(problemSize=Int[],problemNum=Int[],bs=Int[],time=Int[],cars=Int[])
starts=rand(sample1,5)
res=map([50,100,200,400,800]) do tabuSize
	println("Size: ",tabuSize)
	tabuSettings=TabuSearchSettings(1000,tabuSize,1000)
	ress=ThreadsX.map(1:5,basesize=2) do i
		modularTabuSearch3(tabuSettings,sf,deepcopy(starts[i]),false).score
	end
	minimum(ress),maximum(ress),mean(ress)
end
#println(minimum(res),' ',maximum(res),' ',mean(res))