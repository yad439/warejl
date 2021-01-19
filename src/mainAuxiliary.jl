using DataStructures

include("auxiliary.jl")
include("structures.jl")
include("utility.jl")

function computeTimeGetOnly(timetable,machineCount,jobLengths,itemsNeeded,carCount,carTravelTime)
	carNeeded=length.(itemsNeeded)
	sums=fill(zero(eltype(jobLengths)),machineCount)
	times=similar(jobLengths)
	assignment=similar(jobLengths,Int)
	inUseCars=EventQueue()
	carHistory=Tuple{eltype(jobLengths),Int}[]
	carsAvailable=carCount
	availableFromTime=0
	for job ∈ timetable.permutation
		lastDeliverTime=0
		itemsLeft=carNeeded[job]
		while itemsLeft>0
			availableAtEnd=carsAvailable
			for event ∈ inUseCars
				event[1]≥availableFromTime+carTravelTime && break
				availableAtEnd+=event[2]
			end
			realAvailable=min(carsAvailable,availableAtEnd)
			carsUsed=min(realAvailable,itemsLeft)
			carsAvailable-=carsUsed
			realAvailable-=carsUsed
			push!(inUseCars,availableFromTime+carTravelTime,carsUsed)
			push!(carHistory,(availableFromTime,carsUsed))
			itemsLeft-=carsUsed
			lastDeliverTime=availableFromTime
			while realAvailable≤0
				availableFromTime,carChange=popfirst!(inUseCars)
				carsAvailable+=carChange
				@assert carsAvailable≥0
				carsAvailable==0 && continue
				availableAtEnd=carsAvailable
				for event ∈ inUseCars
					event[1]≥availableFromTime+carTravelTime && break
					availableAtEnd+=event[2]
				end
				realAvailable=min(carsAvailable,availableAtEnd)
			end
		end
		machine=selectMachine(job,timetable,sums)
		assignment[job]=machine
		startTime=max(sums[machine],lastDeliverTime+carTravelTime)
		times[job]=startTime
		sums[machine]=startTime+jobLengths[job]
	end
	Schedule(assignment,times),maximum(sums),carHistory
end

function computeTimeGetOnlyWaitOne(timetable,machineCount,jobLengths,itemsNeeded,carCount,carTravelTime)
	sums=fill(zero(eltype(jobLengths)),machineCount)
	times=similar(jobLengths)
	assignment=similar(jobLengths,Int)
	inUseCars=EventQueue()
	carHistory=Tuple{eltype(jobLengths),Int}[]
	carsAvailable=carCount
	availableFromTime=0
	prevItems=BitSet()
	for job ∈ timetable.permutation
		lastDeliverTime=0
		itemsLeft=setdiff(itemsNeeded[job],prevItems) |> length
		while itemsLeft>0
			availableAtEnd=carsAvailable
			for event ∈ inUseCars
				event[1]≥availableFromTime+carTravelTime && break
				availableAtEnd+=event[2]
			end
			realAvailable=min(carsAvailable,availableAtEnd)
			carsUsed=min(realAvailable,itemsLeft)
			carsAvailable-=carsUsed
			realAvailable-=carsUsed
			push!(inUseCars,availableFromTime+carTravelTime,carsUsed)
			push!(carHistory,(availableFromTime,carsUsed))
			itemsLeft-=carsUsed
			lastDeliverTime=availableFromTime
			while realAvailable≤0
				availableFromTime,carChange=popfirst!(inUseCars)
				carsAvailable+=carChange
				@assert carsAvailable≥0
				carsAvailable==0 && continue
				availableAtEnd=carsAvailable
				for event ∈ inUseCars
					event[1]≥availableFromTime+carTravelTime && break
					availableAtEnd+=event[2]
				end
				realAvailable=min(carsAvailable,availableAtEnd)
			end
		end
		prevItems=itemsNeeded[job]
		machine=selectMachine(job,timetable,sums)
		assignment[job]=machine
		startTime=max(sums[machine],lastDeliverTime+carTravelTime)
		times[job]=startTime
		sums[machine]=startTime+jobLengths[job]
	end
	Schedule(assignment,times),maximum(sums),carHistory
end

function computeTimeNoWait(timetable,machineCount,jobLengths,itemsNeeded,carCount,carTravelTime)
	carNeeded=length.(itemsNeeded)
	sums=fill(zero(eltype(jobLengths)),machineCount)
	times=similar(jobLengths)
	assignment=similar(jobLengths,Int)
	inUseCars=EventQueue()
	carHistory=Tuple{eltype(jobLengths),Tuple{Int,Int,Bool}}[]
	carsAvailable=carCount
	availableFromTime=0
	for job ∈ timetable.permutation
		lastDeliverTime=0
		itemsLeft=carNeeded[job]
		while itemsLeft>0
			availableAtEnd=carsAvailable
			for event ∈ inUseCars
				event[1]≥availableFromTime+carTravelTime && break
				availableAtEnd+=event[2]
			end
			realAvailable=min(carsAvailable,availableAtEnd)
			while realAvailable≤0
				@assert realAvailable==0
				availableFromTime,carChange=popfirst!(inUseCars)
				carsAvailable+=carChange
				@assert carsAvailable≥0
				carsAvailable==0 && continue
				availableAtEnd=carsAvailable
				for event ∈ inUseCars
					event[1]≥availableFromTime+carTravelTime && break
					availableAtEnd+=event[2]
				end
				realAvailable=min(carsAvailable,availableAtEnd)
			end
			carsUsed=min(realAvailable,itemsLeft)
			carsAvailable-=carsUsed
			push!(inUseCars,availableFromTime+carTravelTime,carsUsed)
			push!(carHistory,(availableFromTime,(job,carsUsed,true)))
			itemsLeft-=carsUsed
			lastDeliverTime=availableFromTime
		end
		machine=selectMachine(job,timetable,sums)
		assignment[job]=machine
		startTime=max(sums[machine],lastDeliverTime+carTravelTime)
		times[job]=startTime
		sums[machine]=startTime+jobLengths[job]

		backAvailableFrom=startTime+jobLengths[job]
		itemsLeft=carNeeded[job]
		backAvailable=carsAvailable
		inUseCars2=copy(inUseCars)
		while !isempty(inUseCars2) && first(inUseCars2)[1]<backAvailableFrom
			backAvailable+=popfirst!(inUseCars2)[2]
		end
		while itemsLeft>0
			availableAtEnd=backAvailable
			for event ∈ inUseCars2
				event[1]≥backAvailableFrom+carTravelTime && break
				availableAtEnd+=event[2]
			end
			realAvailable=min(backAvailable,availableAtEnd)
			carsUsed=min(realAvailable,itemsLeft)
			backAvailable-=carsUsed
			realAvailable-=carsUsed
			push!(inUseCars,backAvailableFrom,-carsUsed)
			push!(inUseCars,backAvailableFrom+carTravelTime,carsUsed)
			push!(inUseCars2,backAvailableFrom+carTravelTime,carsUsed)
			push!(carHistory,(backAvailableFrom,(job,carsUsed,false)))
			itemsLeft-=carsUsed
			itemsLeft==0 && break
			while realAvailable==0
				backAvailableFrom,carChange=popfirst!(inUseCars2)
				backAvailable+=carChange
				@assert backAvailable≥0
				backAvailable==0 && continue
				availableAtEnd=backAvailable
				for event ∈ inUseCars2
					event[1]≥backAvailable+carTravelTime && break
					availableAtEnd+=event[2]
				end
				realAvailable=min(backAvailable,availableAtEnd)
			end
		end
	end
	Schedule(assignment,times),maximum(sums),carHistory
end

function computeTimeCancelReturn(timetable,machineCount,jobLengths,itemsNeeded,carCount,carTravelTime,bufferSize)
	sums=fill(zero(eltype(jobLengths)),machineCount)
	times=similar(jobLengths)
	assignment=similar(jobLengths,Int)
	inUseCars=EventQueue2()
	carHistory=Tuple{Tuple{Int,Bool},EventEntry}[]
	bigHistory=Vector{Pair{Tuple{Int,Bool},EventEntry}}[]
	carsAvailable=carCount
	availableFromTime=0 # points at last add travel start
	bufferState=BitSet()
	currentStart=nothing
	for job ∈ timetable.permutation
		addTime=0
		itemsLeft=setdiff(itemsNeeded[job],bufferState)
		if currentStart≢nothing
			inter=currentStart.remove ∩ itemsNeeded[job]
			setdiff!(currentStart.remove,inter)
			setdiff!(itemsLeft,inter)
			union!(bufferState,inter)
			carsAvailable+=length(inter)
			inter=currentStart.add ∩ itemsNeeded[job]
			setdiff!(itemsLeft,inter)
		end
		for event ∈ inUseCars
			if !event[1][2] && !isdisjoint(itemsLeft,event[2].add)
				setdiff!(itemsLeft,event[2].add)
				addTime=event[1][1]
			end
		end
		while length(itemsLeft)>0
			availableAtEnd=carsAvailable
			realAvailable=carsAvailable
			currentBufferSize=length(bufferState)
			for event ∈ inUseCars
				event[1][1]>availableFromTime+carTravelTime && break
				# event[1][2] && setdiff!(event[2].remove,itemsNeeded[job]) # cancel remove start
				if event[1][2]
					inter=event[2].remove ∩ itemsNeeded[job]
					if !isempty(inter)
						minch=currentBufferSize-bufferSize
						maxd=length(event[2].remove)-minch
						rm=Iterators.take(itemsNeeded[job],maxd)
						setdiff!(event[2].remove,rm)
					end
					currentBufferSize-=length(event[2].remove)
				else
					currentBufferSize+=length(event[2].add)
				end
				event[1][1]==availableFromTime+carTravelTime && continue
				availableAtEnd-=length(event[2])*(2Int(event[1][2])-1)
				@assert 0≤availableAtEnd≤carCount "Cars availavle at end: $availableAtEnd"
				availableAtEnd<realAvailable && (realAvailable=availableAtEnd)
			end
			@assert currentBufferSize≤bufferSize "Items in buffer: $currentBufferSize"
			while realAvailable≤0 || (!isempty(inUseCars) && first(inUseCars)[1][1]==availableFromTime)
				@assert realAvailable≥0
				(availableFromTime,isNew),carChange=popfirst!(inUseCars)
				# isNew && setdiff!(carChange.remove,itemsNeeded[job]) # cancel remove start
				if isNew
					inter=carChange.remove ∩ itemsNeeded[job]
					if !isempty(inter)
						minch=currentBufferSize-bufferSize
						maxd=length(carChange.remove)-minch
						rm=Iterators.take(itemsNeeded[job],maxd)
						setdiff!(carChange.remove,rm)
					end
				end
				carsAvailable-=length(carChange)*(2Int(isNew)-1)
				push!(carHistory,((availableFromTime,isNew),carChange))
				@assert 0≤carsAvailable≤carCount "Cars availavle: $carsAvailable"
				if isNew
					@assert carChange.remove ⊆ bufferState
					setdiff!(bufferState,carChange.remove)
				else
					@assert isdisjoint(bufferState,carChange.add)
					union!(bufferState,carChange.add)
				end
				if isNew
					currentStart=carChange
				else
					currentStart=nothing
				end
				carsAvailable==0 && continue
				availableAtEnd=carsAvailable
				realAvailable=carsAvailable
				currentBufferSize=length(bufferState)
				for event ∈ inUseCars
					event[1][1]>availableFromTime+carTravelTime && break
					# event[1][2] && setdiff!(event[2].remove,itemsNeeded[job]) # cancel remove start
					if event[1][2]
						inter=event[2].remove ∩ itemsNeeded[job]
					if !isempty(inter)
						minch=currentBufferSize-bufferSize
						maxd=length(event[2].remove)-minch
						rm=Iterators.take(itemsNeeded[job],maxd)
						setdiff!(event[2].remove,rm)
					end
						currentBufferSize-=length(event[2].remove)
					else
						currentBufferSize+=length(event[2].add)
					end
					event[1][1]==availableFromTime+carTravelTime && continue
					availableAtEnd-=length(event[2])*(2Int(event[1][2])-1)
					@assert 0≤availableAtEnd≤carCount "Cars availavle at end: $availableAtEnd"
					availableAtEnd<realAvailable && (realAvailable=availableAtEnd)
				end
				@assert currentBufferSize≤bufferSize
			end
			while currentBufferSize≥bufferSize
				currentBufferSize=length(bufferState)
				bufferFreeTime=0
				for event ∈ inUseCars
					# event[1][2] && setdiff!(event[2].remove,itemsNeeded[job]) # cancel remove start
					if event[1][2]
						inter=event[2].remove ∩ itemsNeeded[job]
					if !isempty(inter)
						minch=currentBufferSize-bufferSize
						maxd=length(event[2].remove)-minch
						rm=Iterators.take(itemsNeeded[job],maxd)
						setdiff!(event[2].remove,rm)
					end
						currentBufferSize-=length(event[2].remove)
					else
						currentBufferSize+=length(event[2].add)
					end
					bufferFreeTime=event[1][1]
					(currentBufferSize<bufferSize && bufferFreeTime≥availableFromTime+carTravelTime) && break
				end
				while !isempty(inUseCars) && first(inUseCars)[1][1]≤bufferFreeTime-carTravelTime
					event=popfirst!(inUseCars)
					# event[1][2] && setdiff!(event[2].remove,itemsNeeded[job]) # cancel remove start
					# if event[1][2]
					# 	inter=event[2].remove ∩ itemsNeeded[job]
					# 	if !isempty(inter)
					# 		minch=currentBufferSize-bufferSize
					# 		maxd=length(event[2].remove)-minch
					# 		rm=Iterators.take(itemsNeeded[job],maxd)
					# 		setdiff!(event[2].remove,rm)
					# 	end
					# end
					carsAvailable-=length(event[2])*(2Int(event[1][2])-1)
					@assert 0≤carsAvailable≤carCount "Cars availavle: $carsAvailable"
					if event[1][2]
						@assert event[2].remove ⊆ bufferState
						setdiff!(bufferState,event[2].remove)
					else
						@assert isdisjoint(bufferState,event[2].add)
						union!(bufferState,event[2].add)
					end
					if event[1][2]
						currentStart=event[2]
					else
						currentStart=nothing
					end
				end
				availableAtEnd=carsAvailable
				for event ∈ inUseCars
					event[1][1]≥availableFromTime+carTravelTime && continue
					availableAtEnd-=length(event[2])*(2Int(event[1][2])-1)
					@assert 0≤availableAtEnd≤carCount "Cars availavle at end: $availableAtEnd"
					availableAtEnd<realAvailable && (realAvailable=availableAtEnd)
				end
			end
			carsUsed=min(realAvailable,length(itemsLeft),bufferSize-currentBufferSize)
			@assert carsUsed>0
			carsAvailable-=carsUsed
			items=Iterators.take(itemsLeft,carsUsed)
			currentStart≢nothing && @assert isdisjoint(currentStart.add,items)
			append!(inUseCars,availableFromTime+carTravelTime,false,true,items)
			currentStart≡nothing && (currentStart=EventEntry(BitSet(),BitSet()))
			union!(currentStart.add,items)
			setdiff!(itemsLeft,items)
		end
		machine=selectMachine(job,timetable,sums)
		assignment[job]=machine
		startTime=max(sums[machine],availableFromTime+carTravelTime,addTime)
		times[job]=startTime
		sums[machine]=startTime+jobLengths[job]

		backAvailableFrom=startTime+jobLengths[job]
		backAvailable=carsAvailable
		inUseCars2=copy(inUseCars)
		while !isempty(inUseCars2) && first(inUseCars2)[1][1]<backAvailableFrom
			event=popfirst!(inUseCars2)
			event[1][2] && setdiff!(event[2].remove,itemsNeeded[job]) # cancel remove start
			backAvailable-=length(event[2])*(2Int(event[1][2])-1)
			@assert 0≤backAvailable≤carCount "Cars availavle: $backAvailable"
		end
		itemsLeft=copy(itemsNeeded[job])
		for event ∈ inUseCars2
			event[1][2] && setdiff!(itemsLeft,event[2].remove) # item is needed somewhere
		end
		while length(itemsLeft)>0
			availableAtEnd=backAvailable
			realAvailable=backAvailable
			for event ∈ inUseCars2
				event[1][1]≥backAvailableFrom+carTravelTime && break
				availableAtEnd-=length(event[2])*(2Int(event[1][2])-1)
				@assert 0≤availableAtEnd≤carCount "Cars availavle at end: $availableAtEnd"
				availableAtEnd<realAvailable && (realAvailable=availableAtEnd)
			end
			while realAvailable≤0 || (!isempty(inUseCars2) && first(inUseCars2)[1][1]==backAvailableFrom)
				@assert realAvailable≥0
				(backAvailableFrom,isNew),carChange=popfirst!(inUseCars2)
				backAvailable-=length(carChange)*(2Int(isNew)-1)
				@assert 0≤backAvailable≤carCount "Cars availavle: $backAvailable"
				backAvailable==0 && continue
				availableAtEnd=backAvailable
				realAvailable=backAvailable
				for event ∈ inUseCars2
					event[1][1]≥backAvailableFrom+carTravelTime && break
					availableAtEnd-=length(event[2])*(2Int(event[1][2])-1)
					@assert 0≤availableAtEnd≤carCount "Cars availavle at end: $availableAtEnd"
					availableAtEnd<realAvailable && (realAvailable=availableAtEnd)
				end
				@assert availableAtEnd≥0
			end
			carsUsed=min(realAvailable,length(itemsLeft))
			backAvailable-=carsUsed
			items=Iterators.take(itemsLeft,carsUsed)
			entry=EventEntry(BitSet(),BitSet(items))
			entry=push!(inUseCars,backAvailableFrom+carTravelTime,false,entry)
			push!(inUseCars,backAvailableFrom,true,entry,true)
			push!(inUseCars2,backAvailableFrom+carTravelTime,false,entry,true)
			setdiff!(itemsLeft,items)
			push!(bigHistory,deepcopy(inUseCars|>collect))
		end
	end
	foreach(event->push!(carHistory,(event[1],event[2])),inUseCars)
	Schedule(assignment,times),maximum(sums),carHistory,bigHistory
end

function computeTimeLazyReturn(timetable,machineCount,jobLengths,itemsNeeded,carCount,carTravelTime,bufferSize,::Val{true})
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
		while length(itemsLeft)>0
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
				minLockTime=minimum(lock[2] for lock ∈ activeLocks)
				while !isempty(inUseCars) && first(inUseCars)[1]≤minLockTime-carTravelTime
					(availableFromTime,carChange)=popfirst!(inUseCars)
					carsAvailable+=length(carChange.endAdd)+length(carChange.endRemove)-length(carChange.startRemove)
					push!(carHistory,(availableFromTime,carChange))
				end
				availableFromTime=max(availableFromTime,minLockTime-carTravelTime)
				minLocks=Iterators.map(first,Iterators.filter(it->it[2]==minLockTime,activeLocks)) |> collect
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

function computeTimeLazyReturn(timetable,problem,::Val{false})
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
		while length(itemsLeft)>0
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
				for item ∈ bufferState
					item∉itemsNeeded[job] || continue
					if lockTime[item]<minLockTime
						minLockTime=lockTime[item]
						minLocksLen=1
						minLocks[1]=item
					elseif lockTime[item]==minLockTime
						minLocksLen+=1
						minLocks[minLocksLen]=item
					end
				end
				for i=1:minLocksLen
					item=minLocks[i]
					nxt=findnext(jb->item ∈ itemsNeeded[jb],timetable.permutation,ind+1)
					nexts[item]= nxt≡nothing ? typemax(Int) : nxt
				end
				sort!(view(minLocks,1:minLocksLen),by=it->nexts[it],rev=true)
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
		for item ∈ itemsNeeded[job]
			lockTime[item]=max(lockTime[item],startTime+jobLengths[job])
		end
	end
	maximum(sums)
end

computeTimeLazyReturn(timetable,problem,debug)=computeTimeLazyReturn(timetable,problem.machineCount,problem.jobLengths,problem.itemsNeeded,problem.carCount,problem.carTravelTime,problem.bufferSize,debug)