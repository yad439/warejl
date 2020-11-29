using DataStructures

include("auxiliary.jl")
include("structures.jl")

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
				availableFromTime,carChange=pop!(inUseCars)
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
				availableFromTime,carChange=pop!(inUseCars)
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
				availableFromTime,carChange=pop!(inUseCars)
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
			backAvailable+=pop!(inUseCars2)[2]
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
				backAvailableFrom,carChange=pop!(inUseCars2)
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

function computeTimeCancelReturn(timetable,machineCount,jobLengths,itemsNeeded,carCount,carTravelTime)
	sums=fill(zero(eltype(jobLengths)),machineCount)
	times=similar(jobLengths)
	assignment=similar(jobLengths,Int)
	inUseCars=EventQueue2()
	carHistory=Tuple{Tuple{Int,Bool},EventEntry}[]
	carsAvailable=carCount
	availableFromTime=0 # points at last add travel start
	bufferState=BitSet()
	currentStart=nothing
	for job ∈ timetable.permutation
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
		while length(itemsLeft)>0
			availableAtEnd=carsAvailable
			realAvailable=carsAvailable
			for event ∈ inUseCars
				event[1][1]>availableFromTime+carTravelTime && break
				event[1][2] && setdiff!(event[2].remove,itemsNeeded[job]) # cancel remove start
				event[1][1]==availableFromTime+carTravelTime && break
				availableAtEnd-=length(event[2])*(2Int(event[1][2])-1)
				@assert 0≤availableAtEnd≤carCount "Cars availavle at end: $availableAtEnd"
				availableAtEnd≤realAvailable && (realAvailable=availableAtEnd)
			end
			# realAvailable=min(carsAvailable,availableAtEnd)
			while realAvailable≤0 || (!isempty(inUseCars) && first(inUseCars)[1][1]==availableFromTime)
				@assert realAvailable==0
				(availableFromTime,isNew),carChange=pop!(inUseCars)
				isNew && setdiff!(carChange.remove,itemsNeeded[job]) # cancel remove start
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
				for event ∈ inUseCars
					event[1][1]>availableFromTime+carTravelTime && break
					event[1][2] && setdiff!(event[2].remove,itemsNeeded[job]) # cancel remove start
					event[1][1]==availableFromTime+carTravelTime && break
					availableAtEnd-=length(event[2])*(2Int(event[1][2])-1)
					@assert 0≤availableAtEnd≤carCount "Cars availavle at end: $availableAtEnd"
					availableAtEnd≤realAvailable && (realAvailable=availableAtEnd)
				end
				# realAvailable=min(carsAvailable,availableAtEnd)
			end
			carsUsed=min(realAvailable,length(itemsLeft))
			carsAvailable-=carsUsed
			items=Iterators.take(itemsLeft,carsUsed)
			for item ∈ items #todo optimize
				push!(inUseCars,availableFromTime+carTravelTime,false,true,item)
			end
			currentStart≡nothing && (currentStart=EventEntry(BitSet(),BitSet()))
			union!(currentStart.add,items)# todo optimize
			setdiff!(itemsLeft,items)
		end
		machine=selectMachine(job,timetable,sums)
		assignment[job]=machine
		startTime=max(sums[machine],availableFromTime+carTravelTime)
		times[job]=startTime
		sums[machine]=startTime+jobLengths[job]

		backAvailableFrom=startTime+jobLengths[job]
		backAvailable=carsAvailable
		inUseCars2=copy(inUseCars)
		while !isempty(inUseCars2) && first(inUseCars2)[1][1]<backAvailableFrom
			event=pop!(inUseCars2)
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
				availableAtEnd≤realAvailable && (realAvailable=availableAtEnd)
			end
			# realAvailable=min(backAvailable,availableAtEnd)
			while realAvailable≤0
				@assert realAvailable==0
				(backAvailableFrom,isNew),carChange=pop!(inUseCars2)
				backAvailable-=length(carChange)*(2Int(isNew)-1)
				@assert 0≤backAvailable≤carCount "Cars availavle: $backAvailable"
				backAvailable==0 && continue
				availableAtEnd=backAvailable
				realAvailable=backAvailable
				for event ∈ inUseCars2
					event[1][1]≥backAvailable+carTravelTime && break
					availableAtEnd-=length(event[2])*(2Int(event[1][2])-1)
					@assert 0≤availableAtEnd≤carCount "Cars availavle at end: $availableAtEnd"
					availableAtEnd≤realAvailable && (realAvailable=availableAtEnd)
				end
				@assert availableAtEnd≥0
				# realAvailable=min(backAvailable,availableAtEnd)
			end
			carsUsed=min(realAvailable,length(itemsLeft))
			backAvailable-=carsUsed
			items=Iterators.take(itemsLeft,carsUsed)
			entry=EventEntry(BitSet(),BitSet(items))
			entry=push!(inUseCars,backAvailableFrom+carTravelTime,false,entry)
			push!(inUseCars,backAvailableFrom,true,entry,true)
			push!(inUseCars2,backAvailableFrom+carTravelTime,false,entry,true)
			setdiff!(itemsLeft,items)
		end
	end
	foreach(event->push!(carHistory,(event[1],event[2])),inUseCars)
	Schedule(assignment,times),maximum(sums),carHistory
end