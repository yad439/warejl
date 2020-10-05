using JuMP,Gurobi
using LinearAlgebra

function moderateExact(jobCount,machineCount,carCount,jobLengths,carsNeeded,carTravelTime)
	M=sum(p)+n*carTravelTime
	# M2=M+0.5

	model=Model(Gurobi.Optimizer)
	@variable(model,t[1:n]≥0)

	@variable(model,ord[1:n,1:n],Bin)
	@constraint(model,[i=1:n,j=1:n],t[i]≥t[j]+p[j]-M*(1-ord[j,i]))
	@variable(model,first[1:n],Bin)
	@constraint(model,[i=1:n],sum(ord[:,i])≥1-first[i])
	@constraint(model,[i=1:n,j=1:n,k=1:n; i≠j],ord[i,j]+ord[j,i]≥ord[k,i]+ord[k,j]-1)
	@constraint(model,sum(first)≤m)

	@variable(model,justBefore[1:n,1:n],Bin)
	@variable(model,before[1:n,1:n],Bin)
	@constraint(model,[i=1:n,j=1:n],t[j]-M*justBefore[j,i]≤t[i]-carTravelTime)
	@constraint(model,[i=1:n,j=1:n],t[j]+(M+1)*before[j,i]≥t[i]+1)
	@variable(model,needCar[1:n,1:n],Bin)
	@constraint(model,[i=1:n,j=1:n],needCar[j,i]≥justBefore[j,i]+before[j,i]-1)
	@constraint(model,[i=1:n],needCar[:,i]⋅carsNeeded≤carCount)

	@variable(model,res)
	@constraint(model,[i=1:n],res≥t[i]+p[i])
	@objective(model,Min,res)

	optimize!(model)

	objective_value(model)
end
