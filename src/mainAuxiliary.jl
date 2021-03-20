using DataStructures

include("auxiliary.jl")
include("structures.jl")
include("utility.jl")

function computeTimeLazyReturn(timetable,problem,::Val{true})
	machineCount=problem.machineCount
	jobLengths=problem.jobLengths
	itemsNeeded=problem.itemsNeeded
	carCount=problem.carCount
	carTravelTime=problem.carTravelTime
	bufferSize=problem.bufferSize

	sums=fill(zero(eltype(jobLengths)),machineCount)
	times=similar(jobLengths)
	assignment=similar(jobLengths,Int)
	inUseCars=EventQueue3()
	carHistory=Tuple{Int,EventEntry3}[]
	bigHistory=Vector{Pair{Int,EventEntry3}}[]
	carsAvailable=carCount
	availableFromTime=0 # points at last add travel start
	bufferState=BitSet()
	lockTime=Dict{Int,Int}()
	for (ind,job) ∈ Iterators.enumerate(timetable.permutation)
		itemsLeft=setdiff(itemsNeeded[job],bufferState)
		while !isempty(itemsLeft)
			while carsAvailable≤0
				@assert carsAvailable≥0
				(availableFromTime,carChange)=popfirst!(inUseCars)
				carsAvailable+=length(carChange.endAdd)+length(carChange.endRemove)-length(carChange.startRemove)
				push!(carHistory,(availableFromTime,carChange))
				@assert carsAvailable≥0
			end
			if length(bufferState)<bufferSize
				carsUsed=min(carsAvailable,bufferSize-length(bufferState),length(itemsLeft))
				toAdd=Iterators.take(itemsLeft,carsUsed)
				carsAvailable-=carsUsed
				append!(inUseCars,availableFromTime+carTravelTime,false,true,toAdd)
				@assert isdisjoint(bufferState,toAdd)
				@assert toAdd ⊆ itemsLeft
				union!(bufferState,toAdd)
				setdiff!(itemsLeft,toAdd)
			else
				activeLocks=Iterators.map(it->(it,lockTime[it]),Iterators.filter(it->it∉itemsNeeded[job],bufferState))
				minLockTime=max(minimum(lock[2] for lock ∈ activeLocks),availableFromTime+carTravelTime)
				while !isempty(inUseCars) && first(inUseCars)[1]≤minLockTime-carTravelTime
					(availableFromTime,carChange)=popfirst!(inUseCars)
					carsAvailable+=length(carChange.endAdd)+length(carChange.endRemove)-length(carChange.startRemove)
					push!(carHistory,(availableFromTime,carChange))
				end
				availableFromTime=max(availableFromTime,minLockTime-carTravelTime)
				minLocks=Iterators.map(first,Iterators.filter(it->it[2] ≤ minLockTime,activeLocks)) |> collect
				nexts=map(item->findnext(jb->item ∈ itemsNeeded[jb],timetable.permutation,ind+1),minLocks) |> fmap(it->it≡nothing ? typemax(Int) : it)
				nextsDict=Dict(Iterators.zip(minLocks,nexts))
				sort!(minLocks,by=it->nextsDict[it],rev=true)
				changesNum=min(carsAvailable,length(minLocks),length(itemsLeft))
				toRemove=Iterators.take(minLocks,changesNum)
				toAdd=Iterators.take(itemsLeft,changesNum)
				for item ∈ toRemove
					delete!(lockTime,item)
				end
				carsAvailable-=changesNum
				append!(inUseCars,availableFromTime+carTravelTime,false,true,toAdd)
				append!(inUseCars,availableFromTime+carTravelTime,true,false,toRemove)
				append!(inUseCars,availableFromTime+2carTravelTime,false,false,toRemove)
				@assert toRemove ⊆ bufferState
				@assert isdisjoint(bufferState,toAdd)
				@assert toAdd ⊆ itemsLeft
				setdiff!(bufferState,toRemove)
				union!(bufferState,toAdd)
				setdiff!(itemsLeft,toAdd)
			end
			@assert length(bufferState)≤bufferSize
			@assert carsAvailable≥0
		end
		machine=selectMachine(job,timetable,sums)
		assignment[job]=machine
		startTime=max(sums[machine],availableFromTime+carTravelTime)
		times[job]=startTime
		sums[machine]=startTime+jobLengths[job]
		for item ∈ itemsNeeded[job]
			lockTime[item]=max(get(lockTime,item,0),startTime+jobLengths[job])
		end
		push!(bigHistory,deepcopy(inUseCars|>collect))
	end
	foreach(event->push!(carHistory,(event[1],event[2])),inUseCars)
	normHistory=normalizeHistory(carHistory,carTravelTime) |> separateEvents |> collect
	(schedule=Schedule(assignment,times,normHistory),time=maximum(sums),history=carHistory,bigHistory=bigHistory)
end

function computeTimeLazyReturn(timetable,problem,::Val{false},sortRemoves=true)
	machineCount=problem.machineCount
	jobLengths=problem.jobLengths
	itemsNeeded=problem.itemsNeeded
	carCount=problem.carCount
	carTravelTime=problem.carTravelTime
	bufferSize=problem.bufferSize

	sums=fill(zero(eltype(jobLengths)),machineCount)
	inUseCars=EventQueue()
	carsAvailable=carCount
	availableFromTime=0 # points at last add travel start
	bufferState=BitSet()
	itemNum=problem.itemCount
	lockTime=zeros(Int,itemNum)
	nexts=similar(lockTime)
	minLocks=Vector{Int}(undef,bufferSize)
	itemsLeft=BitSet()
	sizehint!(itemsLeft,itemNum)
	for (ind,job) ∈ Iterators.enumerate(timetable.permutation)
		setdiff!(itemsLeft,itemsLeft)
		union!(itemsLeft,itemsNeeded[job])
		setdiff!(itemsLeft,bufferState)
		while !isempty(itemsLeft)
			while carsAvailable≤0
				(availableFromTime,carChange)=popfirst!(inUseCars)
				carsAvailable+=carChange
			end
			if length(bufferState)<bufferSize
				carsUsed=min(carsAvailable,bufferSize-length(bufferState),length(itemsLeft))
				toAdd=Iterators.take(itemsLeft,carsUsed)
				carsAvailable-=carsUsed
				push!(inUseCars,availableFromTime+carTravelTime,carsUsed)
				union!(bufferState,toAdd)
				setdiff!(itemsLeft,toAdd)
			else
				minLocksLen=0
				minLockTime=typemax(Int)
				@inbounds for item ∈ bufferState
					item∉itemsNeeded[job] || continue
					if lockTime[item]<minLockTime && minLockTime > availableFromTime+carTravelTime
						minLockTime=lockTime[item]
						minLocksLen=1
						minLocks[1]=item
					elseif lockTime[item]==minLockTime || lockTime[item] ≤ availableFromTime+carTravelTime
						minLocksLen+=1
						@inbounds minLocks[minLocksLen]=item
						if lockTime[item] > minLockTime
							minLockTime = lockTime[item]
						end
					end
				end
				if sortRemoves
					for i=1:minLocksLen
						item=minLocks[i]
						nxt=findnext(jb->item ∈ itemsNeeded[jb],timetable.permutation,ind+1)
						nexts[item]= nxt≡nothing ? typemax(Int) : nxt
					end
					sort!(view(minLocks,1:minLocksLen),by=it->nexts[it],rev=true)
				end
				while !isempty(inUseCars) && first(inUseCars)[1]≤minLockTime-carTravelTime
					(availableFromTime,carChange)=popfirst!(inUseCars)
					carsAvailable+=carChange
				end
				availableFromTime=max(availableFromTime,minLockTime-carTravelTime)
				changesNum=min(carsAvailable,minLocksLen,length(itemsLeft))
				toRemove=Iterators.take(minLocks,changesNum)
				toAdd=Iterators.take(itemsLeft,changesNum)
				carsAvailable-=changesNum
				push!(inUseCars,availableFromTime+2carTravelTime,changesNum)
				setdiff!(bufferState,toRemove)
				union!(bufferState,toAdd)
				setdiff!(itemsLeft,toAdd)
			end
		end
		machine=selectMachine(job,timetable,sums)
		startTime=max(sums[machine],availableFromTime+carTravelTime)
		sums[machine]=startTime+jobLengths[job]
		@inbounds for item ∈ itemsNeeded[job]
			@inbounds lockTime[item]=max(lockTime[item],startTime+jobLengths[job])
		end
	end
	maximum(sums)
end

function computeTimeBufferOnly(timetable,problem)
	sums=fill(zero(eltype(problem.jobLengths)),problem.machineCount)
	bufferState=BitSet()
	lockTimes=zeros(Int,problem.itemCount)
	minLocks=Vector{Int}(undef,problem.bufferSize)
	itemsLeft=BitSet()
	sizehint!(itemsLeft,problem.itemCount)
	for job ∈ timetable.permutation
		machine=selectMachine(job,timetable,sums)
		machineTime=sums[machine]
		lockTime=0

		setdiff!(itemsLeft,itemsLeft)
		union!(itemsLeft,problem.itemsNeeded[job])
		setdiff!(itemsLeft,bufferState)

		if length(bufferState)<problem.bufferSize
			add=Iterators.take(itemsLeft,problem.bufferSize-length(bufferState))
			union!(bufferState,add)
			setdiff!(itemsLeft,add)
		end

		while !isempty(itemsLeft)
			minLocksLen=0
			minLockTime=typemax(Int)
			@inbounds for item ∈ bufferState
				item ∉ problem.itemsNeeded[job] || continue
				if lockTimes[item] < minLockTime && minLockTime > machineTime
					minLockTime=lockTimes[item]
					minLocksLen=1
					minLocks[1]=item
				elseif lockTimes[item]==minLockTime || lockTimes[item] ≤ machineTime
					minLocksLen+=1
					@inbounds minLocks[minLocksLen]=item
					if lockTimes[item] > minLockTime
						minLockTime = lockTimes[item]
					end
				end
			end
			changeNum=min(minLocksLen,length(itemsLeft))
			remove=Iterators.take(minLocks,changeNum)
			add=Iterators.take(itemsLeft,changeNum)
			setdiff!(bufferState,remove)
			union!(bufferState,add)
			setdiff!(itemsLeft,add)
			lockTime=minLockTime
		end
		startTime=max(machineTime,lockTime)
		sums[machine]=startTime+problem.jobLengths[job]
		@inbounds for item ∈ problem.itemsNeeded[job]
			@inbounds lockTimes[item]=max(lockTimes[item],startTime+problem.jobLengths[job])
		end
	end
	maximum(sums)
end