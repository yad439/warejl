using JuMP,Gurobi
using LinearAlgebra,Random
using Plots

n=8
m=3
p=rand(5:20,n)
itemCount=10
itemsNeeded=[randsubseq(1:itemCount,0.2) for _=1:n]
travelTime=40
carNum=4
storageSize=4

itemsNeededMatrix=[item ∈ itemsNeeded[job] for job=1:n,item=1:itemCount]

T=2ceil(Int,sum(length.(itemsNeeded))/carNum)
M=sum(p)+T*travelTime

model=Model(Gurobi.Optimizer)
@variable(model,t[1:n]≥0)

@variable(model,ord[1:n,1:n],Bin)
@constraint(model,[i=1:n,j=1:n],t[i]≥t[j]+p[j]-M*(1-ord[j,i]))
@variable(model,first[1:n],Bin)
@constraint(model,[i=1:n],sum(ord[:,i])≥1-first[i])
@constraint(model,[i=1:n,j=1:n,k=1:n; i≠j],ord[i,j]+ord[j,i]≥ord[k,i]+ord[k,j]-1)
@constraint(model,sum(first)≤m)

@variable(model,timeSlotItem[1:carNum,1:T,1:itemCount],Bin)
@variable(model,timeSlotTime[1:carNum,1:T]≥0)
@constraint(model,[c=1:carNum,τ=1:T],sum(timeSlotItem[c,τ,:])≤1)
@constraint(model,[c=1:carNum,τ=1:T-1],timeSlotTime[c,τ]+travelTime≤timeSlotTime[c,τ+1])
@variable(model,done[1:n,1:carNum,1:T],Bin)
@constraint(model,[i=1:n,c=1:carNum,τ=1:2:T],t[i]≤timeSlotTime[c,τ]+travelTime-1+M*done[i,c,τ])
@constraint(model,[i=1:n,c=1:carNum,τ=1:2:T],t[i]≥timeSlotTime[c,τ]+travelTime-M*(1-done[i,c,τ]))
@constraint(model,[i=1:n,c=1:carNum,τ=2:2:T],t[i]≤timeSlotTime[c,τ]-1+M*done[i,c,τ])
@constraint(model,[i=1:n,c=1:carNum,τ=2:2:T],t[i]≥timeSlotTime[c,τ]-M*(1-done[i,c,τ]))

@variable(model,doneItem[i=1:n,1:carNum,1:T,itemsNeeded[i]],Bin)
@constraints(model,begin
	[i=1:n,c=1:carNum,τ=1:T,item in itemsNeeded[i]],doneItem[i,c,τ,item]≤timeSlotItem[c,τ,item]
	[i=1:n,c=1:carNum,τ=1:T,item in itemsNeeded[i]],doneItem[i,c,τ,item]≤done[i,c,τ]
	[i=1:n,c=1:carNum,τ=1:T,item in itemsNeeded[i]],doneItem[i,c,τ,item]≥timeSlotItem[c,τ,item]+done[i,c,τ]-1
end)
@constraint(model,[i=1:n,item in itemsNeeded[i]],sum((-1)^(τ+1)*doneItem[i,c,τ,item] for c=1:carNum,τ=1:T)≥1)

# @constraint(model,[i=1:n,item in itemsNeeded[i]],sum((-1)^(τ+1)*timeSlotItem[c,τ,item]*done[i,c,τ] for c=1:carNum,τ=1:T)≥1)
@constraint(model,[τ0=1:T],sum((-1)^(τ+1)*timeSlotItem[c,τ,item] for c=1:carNum,τ=1:τ0,item=1:itemCount)≤storageSize)
@constraint(model,[τ0=1:T,item=1:itemCount],sum((-1)^(τ+1)*timeSlotItem[c,τ,item] for c=1:carNum,τ=1:τ0)≥0)

@variable(model,res)
@constraint(model,[i=1:n],res≥t[i]+p[i])
@objective(model,Min,res)

optimize!(model)