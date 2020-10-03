using JuMP,Gurobi
using LinearAlgebra
using Plots

n=7
m=3
p=rand(5:20,n)
carCount=rand(1:2,n)
travelTime=40
carNum=6

M=sum(p)+n*travelTime+1e-1

model=Model(Gurobi.Optimizer)
@variable(model,t[1:n]≥0)

# machines
@variable(model,onMachine[1:n,1:m],Bin)
@variable(model,ord[1:n,1:n],Bin)
@constraint(model,[i=1:n,j=1:n],t[i]≥t[j]+p[j]-M*(1-ord[j,i]))
@constraint(model,[i=1:n,j=1:i-1,k=1:m],ord[i,j]+ord[j,i]≥onMachine[i,k]+onMachine[j,k]-1)
@constraint(model,[i=1:n],sum(onMachine[i,:])==1)

@variable(model,onMachine[1:n,1:m],Bin)
@variable(model,ord[1:n,1:n],Bin)
@constraint(model,[i=1:n,j=1:n,k=1:m],t[i]≥t[j]+p[j]-M*(1-ord[j,i]-onMachine[i,k]-onMachine[j,k]+2))
@constraint(model,[i=1:n,j=1:i-1,k=1:m],ord[i,j]+ord[j,i]==1)
@constraint(model,[i=1:n],sum(onMachine[i,:])==1)

@variable(model,ord[0:n,1:n],Bin)
@constraint(model,[i=1:n,j=1:n],t[i]≥t[j]+p[j]-M*(1-ord[j,i]))
@constraint(model,[i=1:n],sum(ord[:,i])==1)
@constraint(model,[i=1:n],sum(ord[i,:])≤1)
@constraint(model,sum(ord[0,:])≤m)

@variable(model,ord[1:n,1:n],Bin)
@constraint(model,[i=1:n,j=1:n],t[i]≥t[j]+p[j]-M*(1-ord[j,i]))
@variable(model,first[1:n],Bin)
@constraint(model,[i=1:n],sum(ord[:,i])≥1-first[i])
@constraint(model,[i=1:n,j=1:n,k=1:n; i≠j],ord[i,j]+ord[j,i]≥ord[k,i]+ord[k,j]-1)
@constraint(model,sum(first)≤m)

# cars
@variable(model,justBefore[1:n,1:n],Bin)
@variable(model,before[1:n,1:n],Bin)
@constraint(model,[i=1:n,j=1:n],t[j]-M*justBefore[j,i]≤t[i]-travelTime)
@constraint(model,[i=1:n,j=1:n],t[j]+M*before[j,i]≥t[i]+1e-1)
@variable(model,needCar[1:n,1:n],Bin)
@constraint(model,[i=1:n,j=1:n],needCar[j,i]≥justBefore[j,i]+before[j,i]-1)
@constraint(model,[i=1:n],needCar[:,i]⋅carCount≤carNum)


@variable(model,res)
@constraint(model,[i=1:n],res≥t[i]+p[i])
@objective(model,Min,res)

onMachNum=[sum((1:m).*value.(onMachine[i,:])) for i=1:n]
@assert all(it->1≤it≤m,onMachNum)
@assert all(Iterators.product(1:n,1:n)) do (i,j)
	if i≠j && onMachNum[i]≈onMachNum[j]
		if value(ord[i,j])≈1
			value(t[i])+p[i]-value(t[j])≤1e-8
		else
			value(ord[j,i])≈1 && value(t[j])+p[j]-value(t[i])≤1e-8
		end
	else
		true
	end
end

plt=plot()
for i=1:n
	plot!(plt,Shape([(value(t[i]),onMachNum[i]-1),(value(t[i]),onMachNum[i]),(value(t[i])+p[i],onMachNum[i]),(value(t[i])+p[i],onMachNum[i]-1)]),label="task $i")
end
