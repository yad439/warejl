using JuMP

function machinesModel(model,problem,M=2sum(jobLengths))
	jobLengths=problem.jobLengths
	machineCount=problem.machineCount
	t=model[:startTime]
	n=problem.jobCount
	@assert length(t)==n

	@variable(model,ord[1:n,1:n],Bin)
	@constraint(model,[i=1:n,j=1:n],t[i]≥t[j]+jobLengths[j]-M*(1-ord[j,i]))
	@variable(model,isFirst[1:n],Bin)
	@constraint(model,[i=1:n],sum(ord[:,i])≥1-isFirst[i])
	@constraint(model,[i=1:n,j=1:n,k=1:n; i≠j],ord[i,j]+ord[j,i]≥ord[k,i]+ord[k,j]-1)
	@constraint(model,sum(isFirst)≤machineCount);
end

function carsModel1(model,problem,T=2ceil(Int,sum(length.(itemsNeeded))/carCount),M=T*travelTime)
	itemsNeeded=problem.itemsNeeded
	carCount=problem.carCount
	travelTime=problem.carTravelTime
	storageSize=problem.bufferSize
	t=model[:startTime]
	n=problem.jobCount
	p=problem.jobLengths
	@assert length(t)==n
	itemCount=maximum(Iterators.flatten(itemsNeeded))
	T*=2

	@variable(model,timeSlotItem[1:carCount,1:T,1:itemCount],Bin)
	@variable(model,timeSlotTime[1:carCount,1:T]≥0)
	@variable(model,isAdd[1:carCount,1:T],Bin)
	@constraint(model,[c=1:carCount,τ=1:T],sum(timeSlotItem[c,τ,:])≤1)
	@constraint(model,[c=1:carCount,τ=1:T-1],timeSlotTime[c,τ]+travelTime≤timeSlotTime[c,τ+1])

	@variable(model,doneStart[1:n,1:carCount,1:T],Bin)
	@constraint(model,[i=1:n,c=1:carCount,τ=2:2:T],t[i]+p[i]≤timeSlotTime[c,τ]+M*doneStart[i,c,τ])#toto not enough?

	@variable(model,doneEnd[1:n,1:carCount,1:T],Bin)
	@constraint(model,[i=1:n,c=1:carCount,τ=1:T],t[i]≥timeSlotTime[c,τ]+travelTime-M*(1-doneEnd[i,c,τ]))

	@variable(model,doneItemAdd[i=1:n,1:carCount,1:T,itemsNeeded[i]],Bin)
	@constraints(model,begin
		[i=1:n,c=1:carCount,τ=1:T,item in itemsNeeded[i]],doneItemAdd[i,c,τ,item]≤timeSlotItem[c,τ,item]
		[i=1:n,c=1:carCount,τ=1:T,item in itemsNeeded[i]],doneItemAdd[i,c,τ,item]≤doneEnd[i,c,τ]
		[i=1:n,c=1:carCount,τ=1:T,item in itemsNeeded[i]],doneItemAdd[i,c,τ,item]≤isAdd[c,τ]
	end)
	@variable(model,doneItemRemove[i=1:n,1:carCount,1:T,itemsNeeded[i]],Bin)
	@constraints(model,begin
		[i=1:n,c=1:carCount,τ=1:T,item in itemsNeeded[i]],doneItemRemove[i,c,τ,item]≥timeSlotItem[c,τ,item]+doneEnd[i,c,τ]+(1-isAdd[c,τ])-2
	end)
	@constraint(model,[i=1:n,item in itemsNeeded[i]],sum(doneItemAdd[i,c,τ,item] for c=1:carCount,τ=1:T)-sum(doneItemRemove[i,c,τ,item] for c=1:carCount,τ=1:T)≥1)

	@variable(model,doneAdd[1:carCount,1:T,1:carCount,1:T],Bin)
	@constraint(model,[c0=1:carCount,i=1:T,c=1:carCount,τ=2:2:T],timeSlotTime[c0,i]≤timeSlotTime[c,τ]-1+M*doneAdd[c0,i,c,τ])

	@variable(model,doneRemove[1:carCount,1:T,1:carCount,1:T],Bin)
	@constraint(model,[c0=1:carCount,i=1:T,c=1:carCount,τ=1:T],timeSlotTime[c0,i]+travelTime≥timeSlotTime[c,τ]-M*(1-doneRemove[c0,i,c,τ]))

	@variable(model,doneItemAdd2[1:carCount,1:T,1:carCount,1:T],Bin)
	@constraints(model,begin
		[c0=1:carCount,i=1:T,c=1:carCount,τ=1:T],doneItemAdd2[c0,i,c,τ]≥doneAdd[c0,i,c,τ]+isAdd[c,τ]-1
	end)
	@variable(model,doneItemRemove2[1:carCount,1:T,1:carCount,1:T],Bin)
	@constraints(model,begin
		[c0=1:carCount,i=1:T,c=1:carCount,τ=1:T],doneItemRemove2[c0,i,c,τ]≤doneRemove[c0,i,c,τ]
		[c0=1:carCount,i=1:T,c=1:carCount,τ=1:T],doneItemRemove2[c0,i,c,τ]≤1-isAdd[c,τ]
		[c0=1:carCount,i=1:T,c=1:carCount,τ=1:T],doneItemRemove2[c0,i,c,τ]≤sum(timeSlotItem[c,τ,:])
	end)

	@constraint(model,[c0=1:carCount,i=1:T],sum(doneItemAdd2[c0,i,:,:])-sum(doneItemRemove2[c0,i,:,:])≤storageSize)

	@variable(model,doneAdd2[1:carCount,1:T,1:carCount,1:T],Bin)
	@constraint(model,[c0=1:carCount,i=1:T,c=1:carCount,τ=2:2:T],timeSlotTime[c0,i]≥timeSlotTime[c,τ]+travelTime-M*(1-doneAdd2[c0,i,c,τ]))

	@variable(model,doneRemove2[1:carCount,1:T,1:carCount,1:T],Bin)
	@constraint(model,[c0=1:carCount,i=1:T,c=1:carCount,τ=1:T],timeSlotTime[c0,i]+1≤timeSlotTime[c,τ]+M*doneRemove2[c0,i,c,τ])

	@variable(model,doneItemAdd3[1:carCount,1:T,1:carCount,1:T,1:itemCount],Bin)
	@constraints(model,begin
		[c0=1:carCount,i=1:T,c=1:carCount,τ=1:T,it=1:itemCount],doneItemAdd3[c0,i,c,τ,it]≤doneAdd2[c0,i,c,τ]
		[c0=1:carCount,i=1:T,c=1:carCount,τ=1:T,it=1:itemCount],doneItemAdd3[c0,i,c,τ,it]≤timeSlotItem[c,τ,it]
		[c0=1:carCount,i=1:T,c=1:carCount,τ=1:T,it=1:itemCount],doneItemAdd3[c0,i,c,τ,it]≤isAdd[c,τ]
	end)
	@variable(model,doneItemRemove3[1:carCount,1:T,1:carCount,1:T,1:itemCount],Bin)
	@constraints(model,begin
		[c0=1:carCount,i=1:T,c=1:carCount,τ=1:T,it=1:itemCount],doneItemRemove3[c0,i,c,τ,it]≥doneRemove2[c0,i,c,τ]+timeSlotItem[c,τ,it]+(1-isAdd[c,τ])-2
	end)

	@constraint(model,[c0=1:carCount,i=1:T,it=1:itemCount],sum(doneItemAdd3[c0,i,:,:,it])-sum(doneItemRemove3[c0,i,:,:,it])≥0);
end

function carsModel2(model,problem,T=2ceil(Int,sum(length.(itemsNeeded))/carCount),M=T*travelTime)
	itemsNeeded=problem.itemsNeeded
	carCount=problem.carCount
	travelTime=problem.carTravelTime
	storageSize=problem.bufferSize
	t=model[:startTime]
	n=length(itemsNeeded)
	p=problem.jobLengths
	@assert length(t)==n
	itemCount=maximum(Iterators.flatten(itemsNeeded))

	@variable(model,addEventItems[1:itemCount,1:T],Bin)
	@variable(model,removeEventItems[1:itemCount,1:T],Bin)
	@variable(model,addEventTime[1:T]≥0)
	@variable(model,removeEventTime[1:T]≥0)
	@constraint(model,[τ=1:T-1],addEventTime[τ]≤addEventTime[τ+1])
	@constraint(model,[τ=1:T-1],removeEventTime[τ]≤removeEventTime[τ+1])

	@variables(model,begin
		addEventBefore[1:T,1:n],Bin
		removeEventBefore[1:T,1:n],Bin
	end)
	@constraints(model,begin
		[τ=1:T,i=1:n],t[i]≥addEventTime[τ]+travelTime-M*(1-addEventBefore[τ,i])
		[τ=1:T,i=1:n],t[i]+p[i]≤removeEventTime[τ]+M*removeEventBefore[τ,i]
	end)
	@variables(model,begin
		addEventBeforeItem[1:itemCount,1:T,1:n],Bin
		removeEventBeforeItem[1:itemCount,1:T,1:n],Bin
	end)
	@constraints(model,begin
		[it=1:itemCount,τ=1:T,i=1:n],addEventBeforeItem[it,τ,i]≤addEventItems[it,τ]
		[it=1:itemCount,τ=1:T,i=1:n],addEventBeforeItem[it,τ,i]≤addEventBefore[τ,i]
		[it=1:itemCount,τ=1:T,i=1:n],removeEventBeforeItem[it,τ,i]≥removeEventItems[it,τ]+removeEventBefore[τ,i]-1
	end)
	@constraint(model,[i=1:n,item in itemsNeeded[i]],sum(addEventBeforeItem[item,:,i])-sum(removeEventBeforeItem[item,:,i])≥1)
	@variables(model,begin
		removeBeforeAdd[1:T,1:T],Bin
		addBeforeRemove[1:T,1:T],Bin
	end)
	@constraints(model,begin
		[τ=1:T,t0=1:T],removeEventTime[τ]≤addEventTime[t0]+travelTime+M*(1-removeBeforeAdd[τ,t0])
		[τ=1:T,t0=1:T],addEventTime[τ]+travelTime≤removeEventTime[t0]+M*(1-addBeforeRemove[τ,t0])
	end)
	@variables(model,begin
		removeBeforeAddItem[1:itemCount,1:T,1:T],Bin
		addBeforeRemoveItem[1:itemCount,1:T,1:T],Bin
	end)
	@constraints(model,begin
		[it=1:itemCount,t0=1:T,τ=1:T],removeBeforeAddItem[it,τ,t0]≤removeEventItems[it,τ]
		[it=1:itemCount,t0=1:T,τ=1:T],removeBeforeAddItem[it,τ,t0]≤removeBeforeAdd[τ,t0]
		[it=1:itemCount,t0=1:T,τ=1:T],addBeforeRemoveItem[it,τ,t0]≤addEventItems[it,τ]
		[it=1:itemCount,t0=1:T,τ=1:T],addBeforeRemoveItem[it,τ,t0]≤addBeforeRemove[τ,t0]
	end)
	@constraints(model,begin
		[t0=1:T],sum(addEventItems[:,1:t0])-sum(removeBeforeAddItem[:,:,t0])≤storageSize
		[t0=1:T],sum(addBeforeRemoveItem[:,:,t0])-sum(removeEventItems[:,1:t0])≥0
	end)
	@variables(model,begin
		addJustBefore[t0=1:T,1:t0-1],Bin
		removeJustBefore[t0=1:T,1:t0-1],Bin
		removeBeforeAdd2[1:T,1:T],Bin
		addBeforeRemove2[1:T,1:T],Bin
		removeJustBeforeAdd[1:T,1:T],Bin
		addJustBeforeRemove[1:T,1:T],Bin
	end)
	@constraints(model,begin
		[t0=1:T,τ=1:t0-1],addEventTime[τ]+travelTime≤addEventTime[t0]+M*addJustBefore[t0,τ]
		[t0=1:T,τ=1:t0-1],removeEventTime[τ]+travelTime≤removeEventTime[t0]+M*removeJustBefore[t0,τ]
		[t0=1:T,τ=1:T],removeEventTime[τ]+travelTime≤addEventTime[t0]+M*removeJustBeforeAdd[t0,τ]
		[t0=1:T,τ=1:T],addEventTime[τ]+travelTime≤removeEventTime[t0]+M*addJustBeforeRemove[t0,τ]
		[t0=1:T,τ=1:T],removeEventTime[τ]≥addEventTime[t0]+1-M*removeBeforeAdd2[t0,τ]
		[t0=1:T,τ=1:T],addEventTime[τ]≥removeEventTime[t0]+1-M*addBeforeRemove2[t0,τ]
	end)
	@variables(model,begin
		removeJustBeforeAddItem[1:itemCount,1:T,1:T],Bin
		addJustBeforeRemoveItem[1:itemCount,1:T,1:T],Bin
	end)
	@constraints(model,begin
		[i=1:itemCount,t0=1:T,τ=1:T],removeJustBeforeAddItem[i,t0,τ]≥removeEventItems[i,τ]+removeBeforeAdd2[t0,τ]+removeJustBeforeAdd[t0,τ]-2
		[i=1:itemCount,t0=1:T,τ=1:T],addJustBeforeRemoveItem[i,t0,τ]≥addEventItems[i,τ]+addBeforeRemove2[t0,τ]+addJustBeforeRemove[t0,τ]-2
	end)
	@constraints(model,begin
		[t0=1:T],sum(addEventItems[it,τ]*addJustBefore[t0,τ] for it=1:itemCount,τ=1:t0-1)+sum(removeJustBeforeAddItem[:,t0,:])+sum(addEventItems[:,t0])≤carCount#todo linearize
		[t0=1:T],sum(removeEventItems[it,τ]*removeJustBefore[t0,τ] for it=1:itemCount,τ=1:t0-1)+sum(addJustBeforeRemoveItem[:,t0,:])+sum(removeEventItems[:,t0])≤carCount
	end);
end

function carsModel3(model,problem,T=2ceil(Int,sum(length.(itemsNeeded))/carCount),M=T*travelTime)
	itemsNeeded=problem.itemsNeeded
	carCount=problem.carCount
	travelTime=problem.carTravelTime
	storageSize=problem.bufferSize
	t=model[:startTime]
	p=problem.jobLengths
	n=length(itemsNeeded)
	@assert length(t)==n
	itemCount=maximum(Iterators.flatten(itemsNeeded))

	@variable(model,eventItems[1:itemCount,1:2T],Bin)
	@variable(model,eventTime[1:2T]≥0)
	@constraint(model,[τ=1:2T-1],eventTime[τ]≤eventTime[τ+1])

	@variable(model,isAdd[1:2T],Bin)

	@variables(model,begin
		addEventBefore[1:2T,1:n],Bin
		removeEventBefore[1:2T,1:n],Bin
	end)
	@constraints(model,begin
		[τ=1:2T,i=1:n],t[i]≥eventTime[τ]+travelTime-M*(1-addEventBefore[τ,i])
		[τ=1:2T,i=1:n],t[i]+p[i]≤eventTime[τ]+M*removeEventBefore[τ,i]
	end)
	@variables(model,begin
		addEventBeforeItem[1:itemCount,1:2T,1:n],Bin
		removeEventBeforeItem[1:itemCount,1:2T,1:n],Bin
	end)
	@constraints(model,begin
		[it=1:itemCount,τ=1:2T,i=1:n],addEventBeforeItem[it,τ,i]≤eventItems[it,τ]
		[it=1:itemCount,τ=1:2T,i=1:n],addEventBeforeItem[it,τ,i]≤addEventBefore[τ,i]
		[it=1:itemCount,τ=1:2T,i=1:n],addEventBeforeItem[it,τ,i]≤isAdd[τ]
		[it=1:itemCount,τ=1:2T,i=1:n],removeEventBeforeItem[it,τ,i]≥eventItems[it,τ]+removeEventBefore[τ,i]+(1-isAdd[τ])-2
	end)
	@constraint(model,[i=1:n,item in itemsNeeded[i]],sum(addEventBeforeItem[item,:,i])-sum(removeEventBeforeItem[item,:,i])≥1)

	@variable(model,itemsBefore[1:2T,1:2T],Int)

	@variable(model,justBefore[1:2T,1:2T],Bin)
	@constraint(model,[t0=1:2T,τ=1:t0-1],eventTime[τ]+travelTime≤eventTime[t0]+M*justBefore[t0,τ])
	@constraint(model,[t0=1:2T,τ=1:2T],itemsBefore[t0,τ]≥sum(eventItems[:,τ])-itemCount*(1-justBefore[τ,t0]))
	@constraint(model,[t0=1:2T],sum(itemsBefore[t0,τ] for τ=1:t0-1)+sum(eventItems[:,t0])≤carCount)

	@variable(model,startBeforeEnd[1:2T,1:2T],Bin)
	@constraints(model,begin
		[t0=1:2T,τ=t0+1:2T],eventTime[τ]≤eventTime[t0]+travelTime+M*(1-startBeforeEnd[t0,τ])
		[t0=1:2T,τ=t0+1:2T],eventTime[τ]≥eventTime[t0]+travelTime+1-M*startBeforeEnd[t0,τ]
	end)
	@variables(model,begin
		removeItemsBeforeStart[1:itemCount,1:2T,1:2T],Bin
		addItems[1:itemCount,1:2T],Bin
	end)
	@constraints(model,begin
		[i=1:itemCount,t0=1:2T,τ=1:2T],removeItemsBeforeStart[i,t0,τ]≤eventItems[i,τ]
		[i=1:itemCount,t0=1:2T,τ=1:2T],removeItemsBeforeStart[i,t0,τ]≤1-isAdd[τ]
		[i=1:itemCount,t0=1:2T,τ=1:2T],removeItemsBeforeStart[i,t0,τ]≤startBeforeEnd[t0,τ]
		[i=1:itemCount,t0=1:2T,τ=1:2T],removeItemsBeforeStart[i,t0,τ]≥eventItems[i,τ]+(1-isAdd[τ])+startBeforeEnd[t0,τ]-2
		[i=1:itemCount,τ=1:2T],addItems[i,τ]≤eventItems[i,τ]
		[i=1:itemCount,τ=1:2T],addItems[i,τ]≤isAdd[τ]
		[i=1:itemCount,τ=1:2T],addItems[i,τ]≥eventItems[i,τ]+isAdd[τ]-1
	end)
	@constraints(model,begin
		[t0=1:2T],sum(addItems[i,τ] for i=1:itemCount,τ=1:t0)-sum(removeItemsBeforeStart[i,t0,τ] for i=1:itemCount,τ=1:2T)≤storageSize
		[t0=1:2T,i=1:itemCount],sum(addItems[i,τ] for τ=1:t0)-sum(removeItemsBeforeStart[i,t0,τ] for τ=1:2T)≥0
	end);
end