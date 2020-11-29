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
##
model=Model(Gurobi.Optimizer)
@variable(model,t[1:n]≥0)

@variable(model,ord[1:n,1:n],Bin)
@constraint(model,[i=1:n,j=1:n],t[i]≥t[j]+p[j]-M*(1-ord[j,i]))
@variable(model,first[1:n],Bin)
@constraint(model,[i=1:n],sum(ord[:,i])≥1-first[i])
@constraint(model,[i=1:n,j=1:n,k=1:n; i≠j],ord[i,j]+ord[j,i]≥ord[k,i]+ord[k,j]-1)
@constraint(model,sum(first)≤m)
##
@variable(model,timeSlotItem[1:carNum,1:T,1:itemCount],Bin)
@variable(model,timeSlotTime[1:carNum,1:T]≥0)
@variable(model,isAdd[1:carNum,1:T],Bin)
@constraint(model,[c=1:carNum,τ=1:T],sum(timeSlotItem[c,τ,:])≤1)
@constraint(model,[c=1:carNum,τ=1:T-1],timeSlotTime[c,τ]+travelTime≤timeSlotTime[c,τ+1])

@variable(model,doneStart[1:n,1:carNum,1:T],Bin)
# @constraint(model,[i=1:n,c=1:carNum,τ=1:2:T],t[i]≤timeSlotTime[c,τ]+travelTime-1+M*done[i,c,τ])
# @constraint(model,[i=1:n,c=1:carNum,τ=1:2:T],t[i]≥timeSlotTime[c,τ]+travelTime-M*(1-done[i,c,τ]))
@constraint(model,[i=1:n,c=1:carNum,τ=2:2:T],t[i]+p[i]≤timeSlotTime[c,τ]+M*doneStart[i,c,τ])
# @constraint(model,[i=1:n,c=1:carNum,τ=1:T],t[i]≥timeSlotTime[c,τ]-M*(1-doneStart[i,c,τ]))

@variable(model,doneEnd[1:n,1:carNum,1:T],Bin)
@constraint(model,[i=1:n,c=1:carNum,τ=1:T],t[i]≥timeSlotTime[c,τ]+travelTime-M*(1-doneEnd[i,c,τ]))
# @constraint(model,[i=1:n,c=1:carNum,τ=1:2:T],t[i]≤timeSlotTime[c,τ]+travelTime-1+M*doneEnd[i,c,τ])

# @variable(model,inTime[1:n,1:carNum,1:T],Bin)
# @variable(model,inTimeG[1:n,1:carNum,1:T],Bin)
# @variable(model,inTimeL[1:n,1:carNum,1:T],Bin)
# @constraint(model,[i=1:n,c=1:carNum,τ=1:T],timeSlotTime[c,τ]≤t[i]-1+M*inTimeG[i,c,τ])
# @constraint(model,[i=1:n,c=1:carNum,τ=1:T],timeSlotTime[c,τ]≥t[i]+p[i]+1-M*inTimeL[i,c,τ])
# @constraint(model,[i=1:n,c=1:carNum,τ=1:T],inTime[i,c,τ]≥inTimeG[i,c,τ]+inTimeL[i,c,τ]-1)

@variable(model,doneItemAdd[i=1:n,1:carNum,1:T,itemsNeeded[i]],Bin)
@constraints(model,begin
	[i=1:n,c=1:carNum,τ=1:T,item in itemsNeeded[i]],doneItemAdd[i,c,τ,item]≤timeSlotItem[c,τ,item]
	[i=1:n,c=1:carNum,τ=1:T,item in itemsNeeded[i]],doneItemAdd[i,c,τ,item]≤doneEnd[i,c,τ]
	[i=1:n,c=1:carNum,τ=1:T,item in itemsNeeded[i]],doneItemAdd[i,c,τ,item]≤isAdd[c,τ]
	# [i=1:n,c=1:carNum,τ=1:T,item in itemsNeeded[i]],doneItem[i,c,τ,item]≥timeSlotItem[c,τ,item]+done[i,c,τ]-1
end)
@variable(model,doneItemRemove[i=1:n,1:carNum,1:T,itemsNeeded[i]],Bin)
@constraints(model,begin
	[i=1:n,c=1:carNum,τ=1:T,item in itemsNeeded[i]],doneItemRemove[i,c,τ,item]≥timeSlotItem[c,τ,item]+doneEnd[i,c,τ]+(1-isAdd[c,τ])-2
end)
@constraint(model,[i=1:n,item in itemsNeeded[i]],sum(doneItemAdd[i,c,τ,item] for c=1:carNum,τ=1:T)-sum(doneItemRemove[i,c,τ,item] for c=1:carNum,τ=1:T)≥1)

# @constraint(model,[i=1:n,item in itemsNeeded[i]],sum((-1)^(τ+1)*timeSlotItem[c,τ,item]*done[i,c,τ] for c=1:carNum,τ=1:T)≥1)
# @constraint(model,[τ0=1:T],sum((-1)^(τ+1)*timeSlotItem[c,τ,item] for c=1:carNum,τ=1:τ0,item=1:itemCount)≤storageSize)
# @constraint(model,[τ0=1:T,item=1:itemCount],sum((-1)^(τ+1)*timeSlotItem[c,τ,item] for c=1:carNum,τ=1:τ0)≥0)

# @constraint(model,[c=1:carNum,τ=2:2:T,i=1:n,item in itemsNeeded[i]],timeSlotItem[c,τ,item]≤1-inTime[i,c,τ])

@variable(model,doneAdd[1:carNum,1:T,1:carNum,1:T],Bin)
@constraint(model,[c0=1:carNum,i=1:T,c=1:carNum,τ=2:2:T],timeSlotTime[c0,i]≤timeSlotTime[c,τ]-1+M*doneAdd[c0,i,c,τ])

@variable(model,doneRemove[1:carNum,1:T,1:carNum,1:T],Bin)
@constraint(model,[c0=1:carNum,i=1:T,c=1:carNum,τ=1:T],timeSlotTime[c0,i]+travelTime≥timeSlotTime[c,τ]-M*(1-doneRemove[c0,i,c,τ]))

@variable(model,doneItemAdd2[1:carNum,1:T,1:carNum,1:T],Bin)
@constraints(model,begin
	[c0=1:carNum,i=1:T,c=1:carNum,τ=1:T],doneItemAdd2[c0,i,c,τ]≥doneAdd[c0,i,c,τ]+isAdd[c,τ]-1
end)
@variable(model,doneItemRemove2[1:carNum,1:T,1:carNum,1:T],Bin)
@constraints(model,begin
	[c0=1:carNum,i=1:T,c=1:carNum,τ=1:T],doneItemRemove2[c0,i,c,τ]≤doneRemove[c0,i,c,τ]
	[c0=1:carNum,i=1:T,c=1:carNum,τ=1:T],doneItemRemove2[c0,i,c,τ]≤1-isAdd[c,τ]
	[c0=1:carNum,i=1:T,c=1:carNum,τ=1:T],doneItemRemove2[c0,i,c,τ]≤sum(timeSlotItem[c,τ,:])
end)

@constraint(model,[c0=1:carNum,i=1:T],sum(doneItemAdd2[c0,i,:,:])-sum(doneItemRemove2[c0,i,:,:])≤storageSize)

@variable(model,doneAdd2[1:carNum,1:T,1:carNum,1:T],Bin)
@constraint(model,[c0=1:carNum,i=1:T,c=1:carNum,τ=2:2:T],timeSlotTime[c0,i]≥timeSlotTime[c,τ]+travelTime-M*(1-doneAdd2[c0,i,c,τ]))

@variable(model,doneRemove2[1:carNum,1:T,1:carNum,1:T],Bin)
@constraint(model,[c0=1:carNum,i=1:T,c=1:carNum,τ=1:T],timeSlotTime[c0,i]+1≤timeSlotTime[c,τ]+M*doneRemove2[c0,i,c,τ])

@variable(model,doneItemAdd3[1:carNum,1:T,1:carNum,1:T,1:itemCount],Bin)
@constraints(model,begin
	[c0=1:carNum,i=1:T,c=1:carNum,τ=1:T,it=1:itemCount],doneItemAdd3[c0,i,c,τ,it]≤doneAdd2[c0,i,c,τ]
	[c0=1:carNum,i=1:T,c=1:carNum,τ=1:T,it=1:itemCount],doneItemAdd3[c0,i,c,τ,it]≤timeSlotItem[c,τ,it]
	[c0=1:carNum,i=1:T,c=1:carNum,τ=1:T,it=1:itemCount],doneItemAdd3[c0,i,c,τ,it]≤isAdd[c,τ]
end)
@variable(model,doneItemRemove3[1:carNum,1:T,1:carNum,1:T,1:itemCount],Bin)
@constraints(model,begin
	[c0=1:carNum,i=1:T,c=1:carNum,τ=1:T,it=1:itemCount],doneItemRemove3[c0,i,c,τ,it]≥doneRemove2[c0,i,c,τ]+timeSlotItem[c,τ,it]+(1-isAdd[c,τ])-2
end)

@constraint(model,[c0=1:carNum,i=1:T,it=1:itemCount],sum(doneItemAdd3[c0,i,:,:,it])-sum(doneItemRemove3[c0,i,:,:,it])≥0)
##
@variable(model,res)
@constraint(model,[i=1:n],res≥t[i]+p[i])
@objective(model,Min,res)
##
optimize!(model)