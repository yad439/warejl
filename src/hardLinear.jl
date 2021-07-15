using JuMP

include("auxiliary.jl")
include("utility.jl")

function machinesModel(model,problem,M=2sum(problem.jobLengths))
	jobLengths=problem.jobLengths
	machineCount=problem.machineCount
	t=model[:startTime]
	n=problem.jobCount
	@assert length(t)==n

	@variable(model,ord[i=1:n,j=1:n;i≠j],Bin)
	@constraint(model,[i=1:n,j=1:n;i≠j],t[i]≥t[j]+jobLengths[j]-M*(1-ord[j,i]))
	@variable(model,isFirst[1:n],Bin)
	@constraint(model,[i=1:n],sum(ord[j,i] for j=1:n if i≠j)≥1-isFirst[i])
	@constraint(model,[i=1:n,j=1:n,k=1:n; i≠j && i≠k && j≠k],ord[i,j]+ord[j,i]≥ord[k,i]+ord[k,j]-1)
	@constraint(model,sum(isFirst)≤machineCount);
end
function machinesModel2(model,problem,M=2sum(problem.jobLengths))
	jobLengths=problem.jobLengths
	machineCount=problem.machineCount
	t=model[:startTime]
	n=problem.jobCount
	@assert length(t)==n

	@variable(model,ord[i=1:n,j=1:n;i≠j],Bin)
	@constraint(model,[i=1:n,j=1:n;i≠j],t[i]≥t[j]+jobLengths[j]-M*(1-ord[j,i]))
	@variable(model,isFirst[1:n],Bin)
	@constraint(model,[i=1:n],sum(ord[j,i] for j=1:n if i≠j)≥1-isFirst[i])
	@constraint(model,[i=1:n],sum(ord[i,j] for j=1:n if i≠j)≤1)
	@constraint(model,sum(isFirst)≤machineCount);
end
function fromMachinesModel(model)
	isFirst=Bool.(round.(Int,value.(model[:isFirst])))
	n=length(model[:startTime])
	m=sum(isFirst)
	assignment=Vector{Union{Int,Missing}}(missing,n)
	assignment[filter(i->isFirst[i],1:m)]=1:m
	ord=Bool.(round.(Int,value.(model[:ord])))
	for _=1:n
		for i=1:n
			if ismissing(assignment[i])
				for j=1:n
					if i≠j && ord[j,i] && !ismissing(assignment[j])
						assignment[i]=assignment[j]
						break
					end
				end
			end
		end
	end
	convert(Vector{Int},assignment)
end
function toMachinesModel(model,schedule)
	n=length(schedule.assignment)
	m=maximum(schedule.assignment)

	chains=[Int[] for _=1:m]
	foreach(i->push!(chains[schedule.assignment[i]],i),sortperm(schedule.times))

	isFirst=model[:isFirst]
	ord=model[:ord]
	firsts=map(first,chains)
	foreach(i->set_start_value(isFirst[i],i ∈ firsts),1:n)
	for i=1:n,j=1:n
		i==j && continue
		if schedule.assignment[i]≠schedule.assignment[j]
			set_start_value(ord[i,j],0)
			continue
		end
		posi=findfirst(==(i),chains[schedule.assignment[i]])
		posj=findfirst(==(j),chains[schedule.assignment[j]])
		set_start_value(ord[i,j],posi==posj-1)
	end
end

function carsModel1(model,problem,T=2ceil(Int,sum(length.(problem.itemsNeeded))/carCount),M=T*problem.travelTime)
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

function carsModel2(model,problem,T=2ceil(Int,sum(length.(problem.itemsNeeded))/carCount),M=T*problem.travelTime)
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
		addEventBeforeItem[1:T,i=1:n,itemsNeeded[i]],Bin
		removeEventBeforeItem[1:T,i=1:n,itemsNeeded[i]],Bin
	end)
	@constraints(model,begin
		[τ=1:T,i=1:n,it in itemsNeeded[i]],addEventBeforeItem[τ,i,it]≤addEventItems[it,τ]
		[τ=1:T,i=1:n,it in itemsNeeded[i]],addEventBeforeItem[τ,i,it]≤addEventBefore[τ,i]
		[τ=1:T,i=1:n,it in itemsNeeded[i]],removeEventBeforeItem[τ,i,it]≥removeEventItems[it,τ]+removeEventBefore[τ,i]-1
	end)
	@constraint(model,[i=1:n,item in itemsNeeded[i]],sum(addEventBeforeItem[τ,i,item] for τ=1:T)-sum(removeEventBeforeItem[τ,i,item] for τ=1:T)≥1)
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
		[t0=1:T,it=1:itemCount],sum(addBeforeRemoveItem[it,:,t0])-sum(removeEventItems[it,1:t0])≥0
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
		addJustBeforeItem[1:itemCount,t0=1:T,1:t0-1],Bin
		removeJustBeforeItem[1:itemCount,t0=1:T,1:t0-1],Bin
		removeJustBeforeAddItem[1:itemCount,1:T,1:T],Bin
		addJustBeforeRemoveItem[1:itemCount,1:T,1:T],Bin
	end)
	@constraints(model,begin
		[i=1:itemCount,t0=1:T,τ=1:t0-1],addJustBeforeItem[i,t0,τ]≥addEventItems[i,τ]+addJustBefore[t0,τ]-1
		[i=1:itemCount,t0=1:T,τ=1:t0-1],removeJustBeforeItem[i,t0,τ]≥removeEventItems[i,τ]+removeJustBefore[t0,τ]-1
		[i=1:itemCount,t0=1:T,τ=1:T],removeJustBeforeAddItem[i,t0,τ]≥removeEventItems[i,τ]+removeBeforeAdd2[t0,τ]+removeJustBeforeAdd[t0,τ]-2
		[i=1:itemCount,t0=1:T,τ=1:T],addJustBeforeRemoveItem[i,t0,τ]≥addEventItems[i,τ]+addBeforeRemove2[t0,τ]+addJustBeforeRemove[t0,τ]-2
	end)
	@constraints(model,begin
		[t0=1:T],sum(addJustBeforeItem[it,t0,τ] for it=1:itemCount,τ=1:t0-1)+sum(removeJustBeforeAddItem[:,t0,:])+sum(addEventItems[:,t0])≤carCount
		[t0=1:T],sum(removeJustBeforeItem[it,t0,τ] for it=1:itemCount,τ=1:t0-1)+sum(addJustBeforeRemoveItem[:,t0,:])+sum(removeEventItems[:,t0])≤carCount
	end);
end
function fromCarsModel2(model)
	addEventItems=Bool.(round.(Int,value.(model[:addEventItems])))
	removeEventItems=Bool.(round.(Int,value.(model[:removeEventItems])))
	addEventTime=value.(model[:addEventTime])
	removeEventTime=value.(model[:removeEventTime])

	@assert all(x->isapprox(x,round(x),atol=0.01),addEventTime)
	@assert all(x->isapprox(x,round(x),atol=0.01),removeEventTime)

	events=@NamedTuple{time::Int,item::Int,isAdd::Bool}[]
	for t ∈ eachindex(addEventTime)
		for i ∈ eachindex(addEventItems[:,t])
			if addEventItems[i,t]
				push!(events,(time=round(Int,addEventTime[t]),item=i,isAdd=true))
			end
			if removeEventItems[i,t]
				push!(events,(time=round(Int,removeEventTime[t]),item=i,isAdd=false))
			end
		end
	end
	sort(events,by=first)
end
function toCarsModel2(model,schedule,problem)
	addEvents,removeEvents=generalEvents(schedule.carTasks) |> fmap(e->((e.time,e.add),(e.time,e.remove))) |> unzip
	filter!(e->!isempty(e[2]),addEvents)
	filter!(e->!isempty(e[2]),removeEvents)
	w=problem.carTravelTime

	addEventItems=model[:addEventItems]
	removeEventItems=model[:removeEventItems]
	addEventTime=model[:addEventTime]
	removeEventTime=model[:removeEventTime]

	eta=map(t->get(addEvents,t,(addEvents[end][1],))[1],eachindex(addEventTime))
	etr=map(t->get(removeEvents,t,(removeEvents[end][1],))[1],eachindex(removeEventTime))
	eia=[get(addEvents,t,(nothing,[]))[2] ∋ it for (it,t) ∈ Tuple.(CartesianIndices(addEventItems))]
	eir=[get(removeEvents,t,(nothing,[]))[2] ∋ it for (it,t) ∈ Tuple.(CartesianIndices(removeEventItems))]
	set_start_value.(addEventTime,eta)
	set_start_value.(removeEventTime,etr)
	set_start_value.(addEventItems,eia)
	set_start_value.(removeEventItems,eir)

	ba=map(((t,i),)->schedule.times[i]≥eta[t]+w,Tuple.(CartesianIndices(model[:addEventBefore])))
	set_start_value.(model[:addEventBefore],ba)
	br=map(((t,i),)->schedule.times[i]+problem.jobLengths[i]>etr[t],Tuple.(CartesianIndices(model[:removeEventBefore])))
	set_start_value.(model[:removeEventBefore],br)

	foreach(((t,i,it),)->set_start_value(model[:addEventBeforeItem][t,i,it],eia[it,t]&&ba[t,i]),eachindex(model[:addEventBeforeItem]))
	foreach(((t,i,it),)->set_start_value(model[:removeEventBeforeItem][t,i,it],eir[it,t]&&br[t,i]),eachindex(model[:removeEventBeforeItem]))

	ar=map(((t1,t2),)->eta[t1]+w≤etr[t2],Tuple.(CartesianIndices(model[:addBeforeRemove])))
	ra=map(((t1,t2),)->etr[t1]≤eta[t2]+w,Tuple.(CartesianIndices(model[:removeBeforeAdd])))
	set_start_value.(model[:addBeforeRemove],ar)
	set_start_value.(model[:removeBeforeAdd],ra)

	ari=map(((i,t1,t2),)->eia[i,t1]&&ar[t1,t2],Tuple.(CartesianIndices(model[:addBeforeRemoveItem])))
	rai=map(((i,t1,t2),)->eir[i,t1]&&ra[t1,t2],Tuple.(CartesianIndices(model[:removeBeforeAddItem])))
	set_start_value.(model[:addBeforeRemoveItem],ari)
	set_start_value.(model[:removeBeforeAddItem],rai)

	T=length(addEventTime)
	ξa=zeros(Bool,1:T,1:T)
	ξr=zeros(Bool,1:T,1:T)
	foreach(((t0,t),)->ξa[t0,t]=eta[t]>eta[t0]-w,eachindex(model[:addJustBefore]))
	foreach(((t0,t),)->ξr[t0,t]=etr[t]>etr[t0]-w,eachindex(model[:removeJustBefore]))
	ξar=map(((t0,t),)->etr[t0]-w<eta[t],Tuple.(CartesianIndices(model[:addJustBeforeRemove])))
	ξra=map(((t0,t),)->eta[t0]-w<etr[t],Tuple.(CartesianIndices(model[:removeJustBeforeAdd])))
	ηar=map(((t0,t),)->eta[t]≤etr[t0],Tuple.(CartesianIndices(model[:addBeforeRemove2])))
	ηra=map(((t0,t),)->etr[t]≤eta[t0],Tuple.(CartesianIndices(model[:removeBeforeAdd2])))
	foreach(((t0,t),)->set_start_value(model[:addJustBefore][t0,t],ξa[t0,t]),eachindex(model[:addJustBefore]))
	foreach(((t0,t),)->set_start_value(model[:removeJustBefore][t0,t],ξr[t0,t]),eachindex(model[:removeJustBefore]))
	set_start_value.(model[:addJustBeforeRemove],ξar)
	set_start_value.(model[:removeJustBeforeAdd],ξra)
	set_start_value.(model[:addBeforeRemove2],ηar)
	set_start_value.(model[:removeBeforeAdd2],ηra)

	foreach(((i,t0,t),)->set_start_value(model[:addJustBeforeItem][i,t0,t],ξa[t0,t]&&eia[i,t]),eachindex(model[:addJustBeforeItem]))
	foreach(((i,t0,t),)->set_start_value(model[:removeJustBeforeItem][i,t0,t],ξr[t0,t]&&eir[i,t]),eachindex(model[:removeJustBeforeItem]))
	foreach(((i,t0,t),)->set_start_value(model[:removeJustBeforeAddItem][i,t0,t],ξra[t0,t]&&ηra[t0,t]&&eir[i,t]),Tuple.(CartesianIndices(model[:removeJustBeforeAddItem])))
	foreach(((i,t0,t),)->set_start_value(model[:addJustBeforeRemoveItem][i,t0,t],ξar[t0,t]&&ηar[t0,t]&&eia[i,t]),Tuple.(CartesianIndices(model[:addJustBeforeRemoveItem])))
end
function carsModel2Q(model,problem,T=2ceil(Int,sum(length.(problem.itemsNeeded))/carCount),M=T*problem.travelTime)
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
	@constraint(model,[i=1:n,item in itemsNeeded[i]],sum(addEventBefore[:,i].*addEventItems[item,:])-sum(removeEventBefore[:,i].*removeEventItems[item,:])≥1)
	@variables(model,begin
		removeBeforeAdd[1:T,1:T],Bin
		addBeforeRemove[1:T,1:T],Bin
	end)
	@constraints(model,begin
		[τ=1:T,t0=1:T],removeEventTime[τ]≤addEventTime[t0]+travelTime+M*(1-removeBeforeAdd[τ,t0])
		[τ=1:T,t0=1:T],addEventTime[τ]+travelTime≤removeEventTime[t0]+M*(1-addBeforeRemove[τ,t0])
	end)
	@constraints(model,begin
		[t0=1:T],sum(addEventItems[:,1:t0])-sum(removeBeforeAdd[τ,t0]*removeEventItems[i,τ] for i=1:itemCount,τ=1:T)≤storageSize
		[t0=1:T,it=1:itemCount],sum(addBeforeRemove[:,t0].*addEventItems[it,:])-sum(removeEventItems[it,1:t0])≥0
	end)
	@variables(model,begin
		addJustBefore[t0=1:T,1:t0-1],Bin
		removeJustBefore[t0=1:T,1:t0-1],Bin
		removeBeforeAdd2[1:T,1:T],Bin
		addBeforeRemove2[1:T,1:T],Bin
		removeJustBeforeOrAfterAdd[1:T,1:T],Bin
		addJustBeforeOrAfterRemove[1:T,1:T],Bin
	end)
	@constraints(model,begin
		[t0=1:T,τ=1:t0-1],addEventTime[τ]+travelTime≤addEventTime[t0]+M*addJustBefore[t0,τ]
		[t0=1:T,τ=1:t0-1],removeEventTime[τ]+travelTime≤removeEventTime[t0]+M*removeJustBefore[t0,τ]
		[t0=1:T,τ=1:T],removeEventTime[τ]+travelTime≤addEventTime[t0]+M*removeJustBeforeOrAfterAdd[t0,τ]
		[t0=1:T,τ=1:T],addEventTime[τ]+travelTime≤removeEventTime[t0]+M*addJustBeforeOrAfterRemove[t0,τ]
		[t0=1:T,τ=1:T],removeEventTime[τ]≥addEventTime[t0]+1-M*removeBeforeAdd2[t0,τ]
		[t0=1:T,τ=1:T],addEventTime[τ]≥removeEventTime[t0]+1-M*addBeforeRemove2[t0,τ]
	end)
	@variables(model,begin
		removeJustBeforeAdd[1:T,1:T],Bin
		addJustBeforeRemove[1:T,1:T],Bin
	end)
	@constraints(model,begin
		[t0=1:T,τ=1:T],removeJustBeforeAdd[t0,τ]≥removeBeforeAdd2[t0,τ]+removeJustBeforeOrAfterAdd[t0,τ]-1
		[t0=1:T,τ=1:T],addJustBeforeRemove[t0,τ]≥addBeforeRemove2[t0,τ]+addJustBeforeOrAfterRemove[t0,τ]-1
	end)
	@constraints(model,begin
		[t0=1:T],sum(addEventItems[i,τ]addJustBefore[t0,τ] for i=1:itemCount,τ=1:t0-1)+sum(removeEventItems[i,τ]removeJustBeforeAdd[t0,τ] for i=1:itemCount,τ=1:T)+sum(addEventItems[:,t0])≤carCount
		[t0=1:T],sum(removeEventItems[i,τ]removeJustBefore[t0,τ] for i=1:itemCount,τ=1:t0-1)+sum(addEventItems[i,τ]addJustBeforeRemove[t0,τ] for i=1:itemCount,τ=1:T)+sum(removeEventItems[:,t0])≤carCount
	end);
end

function carsModel3(model,problem,T=2ceil(Int,sum(length.(problem.itemsNeeded))/carCount),M=T*problem.travelTime)
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
		addEventBeforeItem[1:2T,i=1:n,itemsNeeded[i]],Bin
		removeEventBeforeItem[1:2T,i=1:n,itemsNeeded[i]],Bin
	end)
	@constraints(model,begin
		[τ=1:2T,i=1:n,it in itemsNeeded[i]],addEventBeforeItem[τ,i,it]≤eventItems[it,τ]
		[τ=1:2T,i=1:n,it in itemsNeeded[i]],addEventBeforeItem[τ,i,it]≤addEventBefore[τ,i]
		[τ=1:2T,i=1:n,it in itemsNeeded[i]],addEventBeforeItem[τ,i,it]≤isAdd[τ]
		[τ=1:2T,i=1:n,it in itemsNeeded[i]],removeEventBeforeItem[τ,i,it]≥eventItems[it,τ]+removeEventBefore[τ,i]+(1-isAdd[τ])-2
	end)
	@constraint(model,[i=1:n,item in itemsNeeded[i]],sum(addEventBeforeItem[:,i,item])-sum(removeEventBeforeItem[:,i,item])≥1)

	@variable(model,itemsBefore[τ=1:2T,τ+1:2T],Int)

	@variable(model,justBefore[τ=1:2T,τ+1:2T],Bin)
	@constraint(model,[t0=1:2T,τ=1:t0-1],eventTime[τ]+travelTime≤eventTime[t0]+M*justBefore[τ,t0])
	@constraint(model,[t0=1:2T,τ=1:t0-1],itemsBefore[τ,t0]≥sum(eventItems[:,τ])-itemCount*(1-justBefore[τ,t0]))
	@constraint(model,[t0=1:2T],sum(itemsBefore[τ,t0] for τ=1:t0-1)+sum(eventItems[:,t0])≤carCount)

	@variable(model,startBeforeEnd[t0=1:2T,t0+1:2T],Bin)
	@constraints(model,begin
		[t0=1:2T,τ=t0+1:2T],eventTime[τ]≤eventTime[t0]+travelTime+M*(1-startBeforeEnd[t0,τ])
		[t0=1:2T,τ=t0+1:2T],eventTime[τ]≥eventTime[t0]+travelTime+1-M*startBeforeEnd[t0,τ]
	end)
	@variables(model,begin
		removeItemsBeforeStart[1:itemCount,t0=1:2T,1:2T],Bin
		addItems[1:itemCount,1:2T],Bin
	end)
	@constraints(model,begin
		[i=1:itemCount,t0=1:2T,τ=1:2T],removeItemsBeforeStart[i,t0,τ]≤eventItems[i,τ]
		[i=1:itemCount,t0=1:2T,τ=1:2T],removeItemsBeforeStart[i,t0,τ]≤1-isAdd[τ]
		[i=1:itemCount,t0=1:2T,τ=t0+1:2T],removeItemsBeforeStart[i,t0,τ]≤startBeforeEnd[t0,τ]
		[i=1:itemCount,t0=1:2T,τ=1:t0],removeItemsBeforeStart[i,t0,τ]≥eventItems[i,τ]+(1-isAdd[τ])-1
		[i=1:itemCount,t0=1:2T,τ=t0+1:2T],removeItemsBeforeStart[i,t0,τ]≥eventItems[i,τ]+(1-isAdd[τ])+startBeforeEnd[t0,τ]-2
		[i=1:itemCount,τ=1:2T],addItems[i,τ]≤eventItems[i,τ]
		[i=1:itemCount,τ=1:2T],addItems[i,τ]≤isAdd[τ]
		[i=1:itemCount,τ=1:2T],addItems[i,τ]≥eventItems[i,τ]+isAdd[τ]-1
	end)
	@constraints(model,begin
		[t0=1:2T],sum(addItems[i,τ] for i=1:itemCount,τ=1:t0)-sum(removeItemsBeforeStart[i,t0,τ] for i=1:itemCount,τ=1:2T)≤storageSize
		[t0=1:2T,i=1:itemCount],sum(addItems[i,τ] for τ=1:t0)-sum(removeItemsBeforeStart[i,t0,τ] for τ=1:2T)≥0
	end);
end

function carsModel4Q(model,problem,T,M)
	n=problem.jobCount
	p=problem.jobLengths
	ic=problem.itemCount
	tt=problem.carTravelTime
	t=model[:startTime]
	@variables(model,begin
		eventTime[1:T]≥problem.carTravelTime
		beforeStart[1:T,1:n],Bin
		beforeEnd[1:T,1:n],Bin
	end)
	@constraint(model,[τ=1:T-1],eventTime[τ]+1≤eventTime[τ+1])
	@constraints(model,begin
		[τ=1:T,i=1:n],t[i]≥eventTime[τ]-M*(1-beforeStart[τ,i])
		[τ=1:T,i=1:n],t[i]+p[i]≤eventTime[τ]+M*beforeEnd[τ,i]
	end)
	@variables(model,begin
		addItems[1:T,1:ic],Bin
		removeItems[1:T,1:ic],Bin
	end)
	@constraint(model,[i=1:n,it in problem.itemsNeeded[i]],beforeStart[:,i]⋅addItems[:,it]-beforeEnd[:,i]⋅removeItems[:,it]≥1)
	@constraints(model,begin
		[τ₀=1:T,it=1:ic],sum(addItems[1:τ₀,it])-sum(removeItems[1:τ₀,it])≥0
		[τ₀=1:T],sum(addItems[1:τ₀,:])-sum(removeItems[1:τ₀,:])≤problem.bufferSize
	end)
	@variables(model,begin
		in1[τ₀=1:T,1:τ₀-1],Bin
		in2[τ₀=1:T,1:τ₀-1],Bin
		in12[τ₀=1:T,1:τ₀-1],Bin
	end)
	@constraints(model,begin
		[τ₀=1:T,τ=1:τ₀-1],eventTime[τ]≤eventTime[τ₀]-tt+M*in1[τ₀,τ]
		[τ₀=1:T,τ=1:τ₀-1],eventTime[τ]≤eventTime[τ₀]-2tt+M*in2[τ₀,τ]
		[τ₀=1:T,τ=1:τ₀-1],in12[τ₀,τ]==(1-in1[τ₀,τ])in2[τ₀,τ]
	end)
	@constraints(model,begin
		[τ₀=1:T],sum(addItems[τ₀,:])+sum(addItems[τ,it]in1[τ₀,τ] for τ=1:τ₀-1,it=1:ic)+sum(removeItems[τ,it]in12[τ₀,τ] for τ=1:τ₀-1,it=1:ic)≤problem.carCount
		[τ₀=1:T],sum(addItems[τ,it]in1[τ,τ₀] for τ=τ₀+1:T,it=1:ic)+sum(removeItems[τ₀,:])+sum(removeItems[τ,it]in1[τ₀,τ] for τ=1:τ₀-1,it=1:ic)≤problem.carCount
	end);
end
function carsModel4(model,problem,T,M)
	n=problem.jobCount
	p=problem.jobLengths
	ic=problem.itemCount
	tt=problem.carTravelTime
	t=model[:startTime]
	@variables(model,begin
		eventTime[1:T]≥problem.carTravelTime
		beforeStart[1:T,1:n],Bin
		beforeEnd[1:T,1:n],Bin
	end)
	@constraint(model,[τ=1:T-1],eventTime[τ]≤eventTime[τ+1]-1)
	@constraints(model,begin
		[τ=1:T,i=1:n],t[i]≥eventTime[τ]-M*(1-beforeStart[τ,i])
		[τ=1:T,i=1:n],t[i]+p[i]≤eventTime[τ]+M*beforeEnd[τ,i]
	end)
	@variables(model,begin
		addItems[1:T,1:ic],Bin
		removeItems[1:T,1:ic],Bin
	end)
	@variables(model,begin
		beforeStartItem[1:T,i=1:n,problem.itemsNeeded[i]],Bin
		beforeEndItem[1:T,i=1:n,problem.itemsNeeded[i]],Bin
	end)
	@constraints(model,begin
		[τ=1:T,i=1:n,q in problem.itemsNeeded[i]],beforeStartItem[τ,i,q]≤beforeStart[τ,i]
		[τ=1:T,i=1:n,q in problem.itemsNeeded[i]],beforeStartItem[τ,i,q]≤addItems[τ,q]
		[τ=1:T,i=1:n,q in problem.itemsNeeded[i]],beforeEndItem[τ,i,q]≥beforeEnd[τ,i]+removeItems[τ,q]-1
	end)
	@constraint(model,[i=1:n,q in problem.itemsNeeded[i]],sum(beforeStartItem[τ,i,q] for τ=1:T)-sum(beforeEndItem[τ,i,q] for τ=1:T)≥1)
	@constraints(model,begin
		[τ₀=1:T,it=1:ic],sum(addItems[1:τ₀,it])-sum(removeItems[1:τ₀,it])≥0
		[τ₀=1:T],sum(addItems[1:τ₀,:])-sum(removeItems[1:τ₀,:])≤problem.bufferSize
	end)
	@variables(model,begin
		in1[τ₀=1:T,1:τ₀-1],Bin
		in2[τ₀=1:T,1:τ₀-1],Bin
	end)
	@constraints(model,begin
		[τ₀=1:T,τ=1:τ₀-1],eventTime[τ]≤eventTime[τ₀]-tt+M*in1[τ₀,τ]
		[τ₀=1:T,τ=1:τ₀-1],eventTime[τ]≤eventTime[τ₀]-2tt+M*in2[τ₀,τ]
	end)
	@variables(model,begin
		addItemsIn1[τ₀=1:T,1:τ₀-1]≥0,Int
		addItemsIn1R[τ₀=1:T,1:τ₀-1]≥0,Int
		removeItemsIn2[τ₀=1:T,1:τ₀-1]≥0,Int
		removeItemsIn1[τ₀=1:T,1:τ₀-1]≥0,Int
	end)
	@constraints(model,begin
		[τ₀=1:T,τ=1:τ₀-1],addItemsIn1[τ₀,τ]≥sum(addItems[τ,:])-(1-in1[τ₀,τ])ic
		[τ₀=1:T,τ=1:τ₀-1],addItemsIn1R[τ₀,τ]≥sum(addItems[τ₀,:])-(1-in1[τ₀,τ])ic
		[τ₀=1:T,τ=1:τ₀-1],removeItemsIn2[τ₀,τ]≥sum(removeItems[τ,:])-in1[τ₀,τ]ic-(1-in2[τ₀,τ])ic
		[τ₀=1:T,τ=1:τ₀-1],removeItemsIn1[τ₀,τ]≥sum(removeItems[τ,:])-(1-in1[τ₀,τ])ic
	end)
	@constraints(model,begin
		[τ₀=1:T],sum(addItems[τ₀,:])+sum(addItemsIn1[τ₀,τ] for τ=1:τ₀-1)+sum(removeItemsIn2[τ₀,τ] for τ=1:τ₀-1)≤problem.carCount
		[τ₀=1:T],sum(addItemsIn1R[τ,τ₀] for τ=τ₀+1:T)+sum(removeItems[τ₀,:])+sum(removeItemsIn1[τ₀,τ] for τ=1:τ₀-1)≤problem.carCount
	end);
end

function fromCarsModel4(model,problem)
	eventTimes=value.(model[:eventTime])
	addItems=@. Bin(round(Int,value(model[:addItems])))
	removeItems=@. Bin(round(Int,value(model[:removeItems])))

	T=length(eventTimes)
	q=size(addItems,2)

	@assert length(eventTimes)==size(addItems,1)==length(removeItems,1)
	@assert size(addItems)==size(removeItems)
	events=Tuple{Int,Int,Bool}[]
	for t=1:T
		τ=eventTimes[t]
		for i=1:q
			if addItems[t,i]
				push!(events,(τ-problem.carTravelTime,i,true))
			end
			if removeItems[t,i]
				push!(events,(τ,i,false))
			end
		end
	end
	sort(events,by=first)
end
function toCarsModel4Q(model,solution,problem)
	events=Dict{Int,Tuple{Set{Int},Set{Int}}}()
	for task ∈ solution.carTasks
		if task.isAdd
			event=get!(events,task.time+problem.carTravelTime,(Set{Int}(),Set{Int}()))
			push!(event[1],task.item)
		else
			event=get!(events,task.time,(Set{Int}(),Set{Int}()))
			push!(event[2],task.item)
		end
	end

	T=length(model[:eventTime])

	eventVals=sort(collect(events),by=first)
	@assert T≥length(eventVals) (T,length(eventVals))
	tm=eventVals[end][1]+1
	while length(eventVals)<T
		push!(eventVals,tm=>(Set{Int}(),Set{Int}()))
		tm+=1
	end
	for t=1:T
		set_start_value(model[:eventTime][t],eventVals[t][1])
		for i=1:problem.itemCount
			set_start_value(model[:addItems][t,i],i ∈ eventVals[t][2][1])
			set_start_value(model[:removeItems][t,i],i ∈ eventVals[t][2][2])
		end
	end

	bs=map(((t,i),)->eventVals[t][1]≤solution.times[i],Tuple.(CartesianIndices(model[:beforeStart])))
	be=map(((t,i),)->eventVals[t][1]<solution.times[i]+problem.jobLengths[i],Tuple.(CartesianIndices(model[:beforeEnd])))
	set_start_value.(model[:beforeStart],bs)
	set_start_value.(model[:beforeEnd],be)

	in1=falses(1:T,1:T)
	in2=falses(1:T,1:T)
	foreach(((t0,t),)->in1[t0,t]=eventVals[t][1]+problem.carTravelTime>eventVals[t0][1],Tuple.(eachindex(model[:in1])))
	foreach(((t0,t),)->in2[t0,t]=eventVals[t][1]+2problem.carTravelTime>eventVals[t0][1],Tuple.(eachindex(model[:in2])))
	in12=@. !in1 & in2
	foreach(((t0,t),)->set_start_value(model[:in1][t0,t],in1[t0,t]),Tuple.(eachindex(model[:in1])))
	foreach(((t0,t),)->set_start_value(model[:in2][t0,t],in2[t0,t]),Tuple.(eachindex(model[:in2])))
	foreach(((t0,t),)->set_start_value(model[:in12][t0,t],in12[t0,t]),Tuple.(eachindex(model[:in12])))

	nothing
end
function toCarsModel4(model,solution,problem)
	n=problem.jobCount
	Q=problem.itemCount

	events=Dict{Int,Tuple{Set{Int},Set{Int}}}()
	for task ∈ solution.carTasks
		if task.isAdd
			event=get!(events,task.time+problem.carTravelTime,(Set{Int}(),Set{Int}()))
			push!(event[1],task.item)
		else
			event=get!(events,task.time,(Set{Int}(),Set{Int}()))
			push!(event[2],task.item)
		end
	end

	T=length(model[:eventTime])

	eventVals=sort(collect(events),by=first)
	@assert T≥length(eventVals) (T,length(eventVals))
	tm=eventVals[end][1]+1
	while length(eventVals)<T
		push!(eventVals,tm=>(Set{Int}(),Set{Int}()))
		tm+=1
	end
	for t=1:T
		set_start_value(model[:eventTime][t],eventVals[t][1])
		for i=1:problem.itemCount
			set_start_value(model[:addItems][t,i],i ∈ eventVals[t][2][1])
			set_start_value(model[:removeItems][t,i],i ∈ eventVals[t][2][2])
		end
	end

	bs=map(((t,i),)->eventVals[t][1]≤solution.times[i],Tuple.(CartesianIndices(model[:beforeStart])))
	be=map(((t,i),)->eventVals[t][1]<solution.times[i]+problem.jobLengths[i],Tuple.(CartesianIndices(model[:beforeEnd])))
	set_start_value.(model[:beforeStart],bs)
	set_start_value.(model[:beforeEnd],be)

	foreach(((t,i,q),)->set_start_value(model[:beforeStartItem][t,i,q],bs[t,i] && q ∈ eventVals[t][2][1]),Tuple.(eachindex(model[:beforeStartItem])))
	foreach(((t,i,q),)->set_start_value(model[:beforeEndItem][t,i,q],be[t,i] && q ∈ eventVals[t][2][2]),Tuple.(eachindex(model[:beforeEndItem])))


	in1=falses(T,T)
	in2=falses(T,T)
	foreach(((t0,t),)->in1[t0,t]=eventVals[t][1]+problem.carTravelTime>eventVals[t0][1],Tuple.(eachindex(model[:in1])))
	foreach(((t0,t),)->in2[t0,t]=eventVals[t][1]+2problem.carTravelTime>eventVals[t0][1],Tuple.(eachindex(model[:in2])))
	foreach(((t0,t),)->set_start_value(model[:in1][t0,t],in1[t0,t]),Tuple.(eachindex(model[:in1])))
	foreach(((t0,t),)->set_start_value(model[:in2][t0,t],in2[t0,t]),Tuple.(eachindex(model[:in2])))

	foreach(((t0,t),)->set_start_value(model[:addItemsIn1][t0,t],in1[t0,t]*length(eventVals[t][2][1])),Tuple.(eachindex(model[:addItemsIn1])))
	foreach(((t0,t),)->set_start_value(model[:addItemsIn1R][t0,t],in1[t0,t]*length(eventVals[t0][2][1])),Tuple.(eachindex(model[:addItemsIn1R])))
	foreach(((t0,t),)->set_start_value(model[:removeItemsIn2][t0,t],(!in1[t0,t])*in2[t0,t]*length(eventVals[t][2][2])),Tuple.(eachindex(model[:removeItemsIn2])))
	foreach(((t0,t),)->set_start_value(model[:removeItemsIn1][t0,t],in1[t0,t]*length(eventVals[t][2][2])),Tuple.(eachindex(model[:removeItemsIn1])))

	nothing
end