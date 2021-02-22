include("mainAuxiliary.jl");
#include("moderateAuxiliary.jl");
#include("utility.jl");
#include("auxiliary.jl")
# include("modularTabu.jl");
#include("modularLocal.jl");
# include("modularAnnealing.jl");
#include("modularGenetic.jl");
include("realDataUtility.jl");
# include("modularLinear.jl");

using Random
#using ThreadTools
using ThreadsX
using DataFrames
using CSV
using Statistics
using ProgressMeter
using Plots

probSize=200
probNum=1
machineCount=8
carCount=20
bufferSize=8
problem=Problem(parseRealData("res/benchmark - automatic warehouse",probSize,probNum),machineCount,carCount,bufferSize,box->box.lineType=="A")
@assert isValid(problem)
@assert problem.bufferSize≥maximum(length,problem.itemsNeeded)
sf=let problem=problem
	jobs->computeTimeLazyReturn(jobs,problem,Val(false),false)
end
sf2=let problem=problem
	jobs->computeTimeLazyReturn(jobs,problem,Val(false),true)
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
# df=CSV.File("exp/tabuRes.tsv") |> DataFrame
# starts=rand(sample1,10)
# sizes=[50,100,500,1000,2000]
#prog=Progress(10*length(sizes))
#res=map(sizes) do tabuSize
#	println("Size: ",tabuSize)
#	tabuSettings=TabuSearchSettings(2000,tabuSize,1000)
#	ress=ThreadsX.map(1:10) do i
#		println("Start $i")
#		sc=modularTabuSearch5(tabuSettings,sf,deepcopy(starts[i]),i==1).score
#		#ProgressMeter.next!(prog)
#		println("End $i")
#		sc
#	end
#	push!(df,(100,1,"A",missing,problem.jobCount,machineCount,carCount,bufferSize,true,5,tabuSettings.searchTries,tabuSettings.tabuSize,tabuSettings.neighbourhoodSize,minimum(ress),maximum(ress),mean(ress)))
#	tabuSize,minimum(ress),maximum(ress),mean(ress)
#end
# tabuSettings=TabuSearchSettings(2000,500,1000)
# ress=ThreadsX.map(1:10) do i
# 	println("Start $i")
# 	sc=modularTabuSearch5(tabuSettings,sf,deepcopy(starts[i]),i==1).score
# 	#ProgressMeter.next!(prog)
# 	println("End $i")
# 	sc
# end
# push!(df,(100,1,"A",missing,problem.jobCount,machineCount,carCount,bufferSize,false,5,tabuSettings.searchTries,tabuSettings.tabuSize,tabuSettings.neighbourhoodSize,minimum(ress),maximum(ress),mean(ress)))
# CSV.write("exp/tabuRes.tsv",df,delim='\t')
# println((minimum(ress),maximum(ress),mean(ress)))
#ProgressMeter.finish!(prog);
#println(minimum(res),' ',maximum(res),' ',mean(res))

ress=progress_map(mapfun=ThreadsX.map,1:1_000_000) do _
	st=rand(sample1)
	sf(st),sf2(st)
end
df=CSV.File("exp/sortOrNotToSort.tsv") |> DataFrame
rat=map(r->r[1]/r[2],ress)
println((maximum(rat),minimum(rat),mean(rat)))
res1=map(first,ress)
res2=map(secondElement,ress)
mn1=argmin(res1)
mn2=argmin(res2)
println(mn1==mn2)
println((ress[mn1],ress[mn2]))
push!(df,(probSize,probNum,"A",missing,machineCount,carCount,bufferSize,minimum(res2),minimum(res1),maximum(rat),minimum(rat),mean(rat),res2[mn1]/res2[mn2]))
CSV.write("exp/sortOrNotToSort.tsv",df,delim='\t')
savefig(histogram(rat,label=false),"out/hist_$(probSize)_$(probNum)_$(machineCount)$(carCount)$(bufferSize).svg")