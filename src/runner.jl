include("mainAuxiliary.jl");
# include("utility.jl");
# include("auxiliary.jl")
include("tabu.jl");
# include("local.jl");
include("annealing.jl");
include("realDataUtility.jl");
include("linear.jl");
include("extendedRandoms.jl");
include("simlpeHeuristic.jl");
include("utility.jl");
include("experimentUtils.jl")

using Random
# using ThreadTools
using ThreadsX
using DataFrames
using CSV
using Statistics
using ProgressMeter
using DelimitedFiles
import JSON
# using Plots
#=
probSize = 50
probNum = 1
machineCount = 6
carCount = 30
bufferSize = 5
problem = Problem(parseRealData("res/benchmark - automatic warehouse", probSize, probNum), machineCount, carCount, bufferSize, box -> box.lineType == "A")
@assert isValid(problem)
@assert problem.bufferSize ≥ maximum(length, problem.itemsNeeded)
sf = let problem = problem
	jobs -> computeTimeLazyReturn(jobs, problem, Val(false), true)
end
sf2 = let problem = problem
	jobs -> computeTimeLazyReturn(jobs, problem, Val(false), false)
end
sample1 = EncodingSample{PermutationEncoding}(problem.jobCount, problem.machineCount)
sample2 = EncodingSample{TwoVectorEncoding}(problem.jobCount, problem.machineCount);
println(problem.jobCount)

st1 = rand(sample1)
sol1 = computeTimeLazyReturn(st1, problem, Val(true))
# annealingSettings=AnnealingSettings(10^6,true,1,500,it->it*0.99999,(old,new,threshold)->rand()<exp((old-new)/threshold))
# sol2=computeTimeLazyReturn(modularAnnealing(annealingSettings,sf,deepcopy(st1)).solution,problem,Val(true))
T1 = sol1.schedule.carTasks |> ffilter(e -> e.isAdd) |> fmap(e -> e.time) |> unique |> length
# T2=sol2.schedule.carTasks |> ffilter(e->e.isAdd) |> fmap(e->e.time) |> unique |> length
# println(T1,' ',T2)
# T=max(T1,T2)
# T=max(T,problem.jobCount)
T = T1
M = sol1.time
println(M,' ',T)

exactModel = buildModel(problem, ORDER_FIRST_STRICT, BUFFER_ONLY, T, M)
# setStartValues(exactModel,sol1.schedule,problem)
set_optimizer_attribute(exactModel.inner,"MIPFocus",3)
# exactRes=runModel(exactModel,60*60)
exactRes = runModel(exactModel, 60 * 60) .+ problem.carTravelTime =#
#=
ress=progress_map(mapfun=ThreadsX.map,1:1_000_000) do _
	st=rand(sample1)
	sf(st),sf2(st)
end
writedlm("out/random_500_1.tsv",ress) =#
#=
df=CSV.File("exp/tabuRes.tsv") |> DataFrame
starts=rand(sample1,10)
sizes=[2000,5000,10_000,20_000,40_000]
#sizes=[2000,5000,10_000]
#sizes=[20_000,40_000]
prog=Progress(10*length(sizes))
res=map(sizes) do tabuSize
	@show tabuSize
	tabuSettings=TabuSearchSettings(2000,tabuSize,1000)
	ress2=ThreadsX.map(1:10) do i
		println("Start $i")
		sc=modularTabuSearch5(tabuSettings,sf,deepcopy(starts[i]),i==1)
		#ProgressMeter.next!(prog)
		println("End $i")
		sc.score,length(sc.history)
	end
	ress=map(first,ress2)
	iters=map(secondElement,ress2)
	push!(df,(probSize,probNum,"A",missing,problem.jobCount,machineCount,carCount,bufferSize,false,5,tabuSettings.searchTries,tabuSettings.tabuSize,tabuSettings.neighbourhoodSize,0.5,"none",minimum(ress),maximum(ress),mean(ress),minimum(iters),maximum(iters),mean(iters)))
	tabuSize,minimum(ress),maximum(ress),mean(ress)
end
CSV.write("exp/tabuRes.tsv",df,delim='\t') =#
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
# ProgressMeter.finish!(prog);
# println(minimum(res),' ',maximum(res),' ',mean(res))
#=
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
savefig(histogram(rat,label=false),"out/hist_$(probSize)_$(probNum)_$(machineCount)$(carCount)$(bufferSize).svg") =#
#=
df=CSV.File("exp/annRes.tsv") |> DataFrame
starts=rand(sample1,10)
#st4=PermutationEncoding(likehoodBased(jobDistance(getfield(problem,:itemsNeeded)),argmin([sf(PermutationEncoding(likehoodBased(jobDistance(getfield(problem,:itemsNeeded)),i))) for i=1:getfield(problem,:jobCount)])));
#starts=fill(st4,10)
#power=1-10^-4
# prog=Progress(10*length(pows))
dif=maxDif(starts[1],sf)
temps=[5,10,20,50,100,500,dif]
dyn=false
#sames=[10_000,20_000,40_000,80_000,160_000]
same=1
steps=10^7
res=map(temps) do temp
	#println("Same: ",same)
	@show temp
	#steps=round(Int,-log(power,-2dif*log(10^-3)))
	#steps=round(Int,stepsBase/)
	power=(-temp*log(10^-3))^(-1/(steps/same))
	annealingSettings=AnnealingSettings(steps,dyn,same,temp,it->it*power,(old,new,threshold)->rand()<exp((old-new)/threshold))
	ress=tmap(1:10) do i
		println("Start $i")
		sc=modularAnnealing(annealingSettings,sf,deepcopy(starts[i]),false).score
		#ProgressMeter.next!(prog)
		println("End $i")
		sc
	end
	push!(df,(probSize,probNum,"A",missing,problem.jobCount,machineCount,carCount,bufferSize,true,annealingSettings.searchTries,dyn,annealingSettings.sameTemperatureTries,dif,annealingSettings.startTheshold,power,0.5,"none",minimum(ress),maximum(ress),mean(ress)))
	temp,minimum(ress),maximum(ress),mean(ress)
end
CSV.write("exp/annRes.tsv",df,delim='\t') =#
#=
df=CSV.File("exp/tabuRes.tsv") |> DataFrame
#starts=rand(sample1,10)
st4=PermutationEncoding(likehoodBased(jobDistance(getfield(problem,:itemsNeeded)),argmin([sf(PermutationEncoding(likehoodBased(jobDistance(getfield(problem,:itemsNeeded)),i))) for i=1:getfield(problem,:jobCount)])));
starts=fill(st4,10)
tabuSize=1038
baseIter=3000
#neighSize=round(Int,1500*2.077168272078332/1.3165544511496166)
neighSize=5000
tabuSettings=TabuSearchSettings(baseIter,tabuSize,neighSize)
#rdm=PermutationRandomIterable(problem.jobCount,neighSize,0.5,jobDistance(problem.itemsNeeded))
#tabuSettings=TabuSearchSettings4(baseIter,tabuSize,rdm)
ress2=progress_map(mapfun=ThreadsX.map,1:10) do i
	#println("Start $i")
	sc=modularTabuSearch5(tabuSettings,sf2,deepcopy(starts[i]),i==1)
	#ProgressMeter.next!(prog)
	#println("End $i")
	sf(sc.solution),length(sc.history)
end
ress=map(first,ress2)
iters=map(secondElement,ress2)
push!(df,(probSize,probNum,"A",missing,problem.jobCount,machineCount,carCount,bufferSize,false,5,tabuSettings.searchTries,tabuSettings.tabuSize,neighSize,0.5,"bestStart",minimum(ress),maximum(ress),mean(ress),minimum(iters),maximum(iters),mean(iters)))
CSV.write("exp/tabuRes.tsv",df,delim='\t') =#
#=
prob=Problem(9,3,2,2,8,3,[10,2,8,5,6,6,4,2,1],BitSet.([[1],[2],[2],[3],[4],[5],[6],[6,7],[6,7,8]]))
@assert isValid(prob)

model=buildModel(prob,ORDER_FIRST_STRICT,SHARED_EVENTS,12,20)
addItems=model.inner[:addItems]
removeItems=model.inner[:removeItems]
@constraint(model.inner,[τ=1:12],sum(addItems[τ,:])≥sum(removeItems[τ,:]))
res=runModel(model) .+ 2 =#
#=
df=CSV.File("exp/tabuRes.tsv") |> DataFrame
starts=rand(sample1,10)
st4=PermutationEncoding(likehoodBased(jobDistance(getfield(problem,:itemsNeeded)),argmin([sf(PermutationEncoding(likehoodBased(jobDistance(getfield(problem,:itemsNeeded)),i))) for i=1:getfield(problem,:jobCount)])));
#starts=fill(st4,10)
tabuSize=600
baseIter=2000
neighSize=1000
ratios=[0,0.2,0.5,0.8,1]
for rat in ratios
	@show rat
	#tabuSettings=TabuSearchSettings(baseIter,tabuSize,neighSize)
	rdm=PermutationRandomIterable(problem.jobCount,neighSize,rat,fill(1,problem.jobCount,problem.jobCount))
	tabuSettings=TabuSearchSettings4(baseIter,tabuSize,rdm)
	ress2=progress_map(mapfun=ThreadsX.map,1:10) do i
		println("Start $i")
		sc=modularTabuSearch5(tabuSettings,sf,deepcopy(starts[i]),false)
		#ProgressMeter.next!(prog)
		println("End $i")
		sf(sc.solution),length(sc.history)
	end
	ress=map(first,ress2)
	iters=map(secondElement,ress2)
	push!(df,(probSize,probNum,"A",missing,problem.jobCount,machineCount,carCount,bufferSize,true,5,tabuSettings.searchTries,tabuSettings.tabuSize,neighSize,rat,"none",minimum(ress),maximum(ress),mean(ress),minimum(iters),maximum(iters),mean(iters)))
end
CSV.write("exp/tabuRes.tsv",df,delim='\t') =#
#=
df=CSV.File("exp/annRes.tsv") |> DataFrame
dist=jobDistance(problem.itemsNeeded)
starts=rand(sample1,10)
#st4=PermutationEncoding(likehoodBased(jobDistance(getfield(problem,:itemsNeeded)),argmin([sf(PermutationEncoding(likehoodBased(jobDistance(getfield(problem,:itemsNeeded)),i))) for i=1:getfield(problem,:jobCount)])));
#starts=fill(st4,10)
#power=1-10^-4
# prog=Progress(10*length(pows))
dif=maxDif(starts[1],sf2)
temp=dif/2
dyn=false
same=100_000
steps=2*10^7
#steps=round(Int,10^6*7.2321310304/3.4153597199)
#steps=round(Int,-log(power,-2dif*log(10^-3)))
#steps=round(Int,stepsBase/)
power=(-temp*log(10^-3))^(-1/(steps/same))
# annealingSettings=AnnealingSettings(steps,dyn,same,temp,it->it*power,(old,new,threshold)->rand()<exp((old-new)/threshold))
rdm=let dist=dist
	jobs->controlledPermutationRandom(jobs,0.5,dist)
end
annealingSettings=AnnealingSettings2(steps,false,same,dif/2,it->it*power,(old,new,threshold)->rand()<exp((old-new)/threshold),rdm)
ress=ThreadsX.map(1:10) do i
	println("Start $i")
	sc=modularAnnealing(annealingSettings,sf2,deepcopy(starts[i]),false)
	#ProgressMeter.next!(prog)
	println("End $i")
	sf(sc.solution)
end
push!(df,(probSize,probNum,"A",missing,problem.jobCount,machineCount,carCount,bufferSize,false,annealingSettings.searchTries,dyn,annealingSettings.sameTemperatureTries,dif,annealingSettings.startTheshold,power,0.5,"itemBased",minimum(ress),maximum(ress),mean(ress)))
CSV.write("exp/annRes.tsv",df,delim='\t') =#
#=
sts=rand(sample1,10^3)
tabuSettings=TabuSearchSettings(100,100,100)
annealingSettings=AnnealingSettings(10^3,false,1,1000,it->it*0.999,(old,new,threshold)->rand()<exp((old-new)/threshold))
foreach(sf,sts)
foreach(sf2,sts)
modularTabuSearch5(tabuSettings,sf,deepcopy(sts[1]),false)
modularAnnealing(annealingSettings,sf,deepcopy(sts[1]),false)
modularTabuSearch5(tabuSettings,sf2,deepcopy(sts[1]),false)
modularAnnealing(annealingSettings,sf2,deepcopy(sts[1]),false)
sts=rand(sample1,10^6)
tabuSettings=TabuSearchSettings(1000,100,1000)
annealingSettings=AnnealingSettings(10^6,false,1,1000,it->it*0.99999,(old,new,threshold)->rand()<exp((old-new)/threshold))
println("Timing")
prog=Progress(6)
time0=(@timed foreach(sf,sts)).time/10^6
ProgressMeter.next!(prog)
time1=(@timed foreach(sf2,sts)).time/10^6
ProgressMeter.next!(prog)
res2=@timed modularTabuSearch5(tabuSettings,sf,deepcopy(sts[1]),false)
time2=res2.time/length(res2.value.history)/1000
ProgressMeter.next!(prog)
time3=(@timed modularAnnealing(annealingSettings,sf,deepcopy(sts[1]),false)).time/10^6
ProgressMeter.next!(prog)
res4=@timed modularTabuSearch5(tabuSettings,sf2,deepcopy(sts[1]),false)
time4=res4.time/length(res4.value.history)/1000
ProgressMeter.next!(prog)
time5=(@timed modularAnnealing(annealingSettings,sf2,deepcopy(sts[1]),false)).time/10^6
ProgressMeter.next!(prog)
ProgressMeter.finish!(prog)
println("$time0 $time2 $time3")
println("$time1 $time4 $time5")
df=CSV.File("exp/times.tsv")|>DataFrame
push!(df,(problem.jobCount,gethostname(),time0,time2,time3,time1,time4,time5))
CSV.write("exp/times.tsv",df,delim='\t') =#
#=
res=progress_map(1:10^4,mapfun=ThreadsX.map) do _
	st=rand(sample1)
	sol,=computeTimeLazyReturn(st,problem,Val(true))
	sol2=improveSolution(sol,problem)
	#validate(sol2,problem)
	l1=maximum(((t,p),)->t+p,zip(sol.times,problem.jobLengths))
	l2=maximum(((t,p),)->t+p,zip(sol2.times,problem.jobLengths))
	imp=sol.times-sol2.times
	l2/l1,count(≠(0),imp),sum(imp),mean(imp),mean(filter(≠(0),imp))
end =#

let
	resFile = "exp/results.json"

	probSize = 20
	# probNum = 4
	machineCount = 6
	carCount = 30
	#bufferSize = 8

	results = fromJson(Vector{ProblemInstance}, JSON.parsefile(resFile))
	try
		for probNum = 5:9
			println("Instance ", probNum)
			let
				bufferSize = problemStats(probSize, probNum, ['A']).maxItems

				instance = findInstance(
									results,probSize,probNum,['A'],
									missing,machineCount,carCount,bufferSize
							)
				if instance ≡ nothing
					instance = createInstance(
									probSize,probNum,['A'],
									missing,machineCount,carCount,bufferSize
							)
					push!(results, instance)
				end
				instance::ProblemInstance

				problem = try
					instanceToProblem(instance)
				catch e
					println(stderr, "Can't parse problem ", probNum)
					continue
				end
				problem::Problem
				if !isValid(problem)
					println(stderr, "Problem ", probNum, " is invalid!")
					continue
				end

				res = runLinear(problem, ORDER_FIRST_STRICT, SHARED_EVENTS, timeLimit=60 * 60, startSolution=true)
				instance.modelResults.fullModel = (solution = res[1], bound = res[2])

				# samp = EncodingSample{PermutationEncoding}(problem.jobCount, problem.machineCount)
				# sf(jobs) = computeTimeLazyReturn(jobs, problem, Val(false), true)
				# starts = rand(samp, 10)
				# dif = maxDif(starts[1], sf)
				# res = runAnnealing(problem, starts, 10^6, 1, dif / 2)
				# push!(instance.annealingResults, res)
			end
			GC.gc()
		end
	finally
		open(resFile, "w") do file
			JSON.print(file, results, 4);
		end;
	end
end
GC.gc()