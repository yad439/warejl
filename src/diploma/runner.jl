#include("mainAuxiliary.jl");
#include("moderateAuxiliary.jl");
#include("utility.jl");
#include("auxiliary.jl")
#include("modularTabu.jl");
#include("modularLocal.jl");
#include("modularAnnealing.jl");
#include("modularGenetic.jl");
include("realDataUtility.jl");
include("modularLinear.jl");

#using Random
#using DataFrames
#using CSV

machineCount=6
carCount=40
bufferSize=6
problem=Problem(parseRealData("res/benchmark - automatic warehouse",20,4),machineCount,carCount,bufferSize,box->box.lineType=="A")
#sf=let problem=problem
#	jobs->computeTimeLazyReturn(jobs,problem,Val(false))
#end
#sample1=EncodingSample{PermutationEncoding}(problem.jobCount,problem.machineCount)
#sample2=EncodingSample{TwoVectorEncoding}(problem.jobCount,problem.machineCount);

exactModel=buildModel(problem,ORDER_FIRST,SEPARATE_EVENTS)
exactRes=runModel(exactModel,1800)