using JuMP,Gurobi
using LinearAlgebra

include("auxiliary.jl")

function moderateExact(jobCount,machineCount,carCount,jobLengths,carsNeeded,carTravelTime,timeLimit=0)
	M=sum(jobLengths)+jobCount*carTravelTime

	model=Model(Gurobi.Optimizer)
	timeLimit==0 || set_time_limit_sec(model,timeLimit)
	@variable(model,t[1:jobCount]≥0)

	@variable(model,ord[1:jobCount,1:jobCount],Bin)
	@constraint(model,[i=1:jobCount,j=1:jobCount],t[i]≥t[j]+jobLengths[j]-M*(1-ord[j,i]))
	@variable(model,first[1:jobCount],Bin)
	@constraint(model,[i=1:jobCount],sum(ord[:,i])≥1-first[i])
	@constraint(model,[i=1:jobCount,j=1:jobCount,k=1:jobCount; i≠j],ord[i,j]+ord[j,i]≥ord[k,i]+ord[k,j]-1)
	@constraint(model,sum(first)≤machineCount)

	@variable(model,justBefore[1:jobCount,1:jobCount],Bin)
	@variable(model,before[1:jobCount,1:jobCount],Bin)
	@constraint(model,[i=1:jobCount,j=1:jobCount],t[j]-M*justBefore[j,i]≤t[i]-carTravelTime)
	@constraint(model,[i=1:jobCount,j=1:jobCount],t[j]+(M+1)*before[j,i]≥t[i]+1)
	@variable(model,needCar[1:jobCount,1:jobCount],Bin)
	@constraint(model,[i=1:jobCount,j=1:jobCount],needCar[j,i]≥justBefore[j,i]+before[j,i]-1)
	@constraint(model,[i=1:jobCount],needCar[:,i]⋅carsNeeded≤carCount)

	@variable(model,res)
	@constraint(model,[i=1:jobCount],res≥t[i]+jobLengths[i])
	@objective(model,Min,res)

	optimize!(model)

	objective_value(model),objective_bound(model),(times=value.(t),order=value.(ord))
end

function moderateExact2(jobCount,machineCount,carCount,jobLengths,carsNeeded,carTravelTime,timeLimit=0)
	T=ceil(Int,sum(carsNeeded)/carCount)
	M=sum(jobLengths)+T*carTravelTime

	model=Model(Gurobi.Optimizer)
	timeLimit==0 || set_time_limit_sec(model,timeLimit)
	@variable(model,time[1:jobCount]≥0)

	@variables(model,begin
		ord[1:jobCount,1:jobCount],Bin
		first[1:jobCount],Bin
	end)
	@constraints(model,begin
		[i=1:jobCount,j=1:jobCount],time[i]≥time[j]+jobLengths[j]-M*(1-ord[j,i])
		[i=1:jobCount],sum(ord[:,i])≥1-first[i]
		[i=1:jobCount,j=1:jobCount,k=1:jobCount; i≠j],ord[i,j]+ord[j,i]≥ord[k,i]+ord[k,j]-1
		sum(first)≤machineCount
	end)

	@variables(model,begin
		timeSlot[1:carCount,1:T,1:jobCount],Bin
	end)
	@constraints(model,begin
		[i=1:jobCount,t=1:T],time[i]≥(carsNeeded[i]-sum(timeSlot[:,1:t,i]))t*carTravelTime
		[i=1:carCount,t=1:T],sum(timeSlot[i,t,:])==1
	end)


	@variable(model,res)
	@constraint(model,[i=1:jobCount],res≥time[i]+jobLengths[i])
	@objective(model,Min,res)

	optimize!(model)

	objective_value(model),objective_bound(model),(times=value.(time),order=value.(ord))
end

function exactSolutionToSchedule(solution,jobLengths,machineCount)
	times=round.(Int,solution.times)
	Schedule(timesToAssignment(times,jobLengths,machineCount),times)
end

function timesToAssignment(times,jobLengths,machineCount)
	@assert length(times)==length(jobLengths)
	sums=fill(zero(eltype(jobLengths)),machineCount)
	order=sortperm(times)
	assignment=Vector{Int}(undef,length(times))
	for job ∈ order
		machine=argmin(sums)
		@assert sums[machine]≤times[job]
		assignment[job]=machine
		sums[machine]+=jobLengths[job]
	end
	assignment
end