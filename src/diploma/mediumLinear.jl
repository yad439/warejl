using JuMP,Gurobi

# n=10
# m=3
# p=rand(n)
M=sum(p)

model1=Model(Gurobi.Optimizer)
@variable(model1,t[1:n]≥0)
@variable(model1,onMachine[1:n,1:m],Bin)
@variable(model1,ord[1:n,1:n],Bin)
@constraint(model1,[i=1:n,j=1:n,k=1:m],t[i]≥t[j]+p[j]-M*(1-ord[j,i]-onMachine[i,k]-onMachine[j,k]+2))
@constraint(model1,[i=1:n,j=1:i-1,k=1:m],ord[i,j]+ord[j,i]==1)
@constraint(model1,[i=1:n],sum(onMachine[i,:])==1)
@variable(model1,res)
@constraint(model1,[i=1:n],res≥t[i]+p[i])
@objective(model1,Min,res)

model2=Model(Gurobi.Optimizer)
@variable(model2,t[1:n]≥0)
@variable(model2,onMachine[1:n,1:m],Bin)
@variable(model2,ord[1:n,1:n],Bin)
@constraint(model2,[i=1:n,j=1:n],t[i]≥t[j]+p[j]-M*(1-ord[j,i]))
@constraint(model2,[i=1:n,j=1:i-1,k=1:m],ord[i,j]+ord[j,i]≥onMachine[i,k]+onMachine[j,k]-1)
@constraint(model2,[i=1:n],sum(onMachine[i,:])==1)
@variable(model2,res)
@constraint(model2,[i=1:n],res≥t[i]+p[i])
@objective(model2,Min,res)

model3=Model(Gurobi.Optimizer)
@variable(model3,t[1:n]≥0)
@variable(model3,ord[1:n+1,1:n],Bin)
@constraint(model3,[i=1:n,j=1:n],t[i]≥t[j]+p[j]-M*(1-ord[j,i]))
# @variable(model3,first[1:n],Bin)
@constraint(model3,[i=1:n],sum(ord[:,i])==1)
@constraint(model3,[i=1:n],sum(ord[i,:])≤1)
@constraint(model3,sum(ord[n+1,:])≤m)
# @constraint(model3,sum(first)≤m)
@variable(model3,res)
@constraint(model3,[i=1:n],res≥t[i]+p[i])
@objective(model3,Min,res)

model4=Model(Gurobi.Optimizer)
@variable(model4,t[1:n]≥0)
@variable(model4,ord[1:n,1:n],Bin)
@constraint(model4,[i=1:n,j=1:n],t[i]≥t[j]+p[j]-M*(1-ord[j,i]))
@variable(model4,first[1:n],Bin)
@constraint(model4,[i=1:n],sum(ord[:,i])≥1-first[i])
@constraint(model4,[i=1:n,j=1:n,k=1:n; i≠j],ord[i,j]+ord[j,i]≥ord[k,i]+ord[k,j]-1)
@constraint(model4,sum(first)≤m)
@variable(model4,res)
@constraint(model4,[i=1:n],res≥t[i]+p[i])
@objective(model4,Min,res)

onMachNum=[sum((1:m).*value.(onMachine[i,:])) for i=1:n]
onMachNum=[sum((1:m).*[sum(value(ord[j,i,k]) for j=1:n+1) for k=1:m]) for i=1:n]
@assert all(it->1≤it≤m,onMachNum)
@assert all(Iterators.product(1:n,1:n)) do (i,j)
	if i!=j && onMachNum[i]≈onMachNum[j]
		if value(ord[i,j])≈1
			value(t[i])+p[i]-value(t[j])≤1e8
		else
			value(ord[j,i])≈1 && value(t[j])+p[j]-value(t[i])≤1e8
		end
	else
		true
	end
end

plt=plot()
for i=1:n
	plot!(plt,Shape([(value(t[i]),onMachNum[i]-1),(value(t[i]),onMachNum[i]),(value(t[i])+p[i],onMachNum[i]),(value(t[i])+p[i],onMachNum[i]-1)]),label="task $i")
end
