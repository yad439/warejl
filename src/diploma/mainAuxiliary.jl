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
	carHistory=Tuple{eltype(jobLengths),Tuple{Int,Int,Bool}}[]
	carsAvailable=carCount
	availableFromTime=0
	for job ∈ timetable.permutation
		lastDeliverTime=0
		itemsLeft=copy(itemsNeeded[job])
		while length(itemsLeft)>0
			availableAtEnd=carsAvailable
			for event ∈ inUseCars
				event[1][1]>availableFromTime+carTravelTime && break
				inter=intersect(itemsLeft,event[2].remove)
				setdiff!(itemsLeft,inter)
				setdiff!(event[2].remove,inter)
				event[1][1]==availableFromTime+carTravelTime && break
				availableAtEnd-=length(event[2])*(2Int(event[1][2])-1)
			end
			realAvailable=min(carsAvailable,availableAtEnd)
			while realAvailable≤0
				@assert realAvailable==0
				(availableFromTime,isNew),carChange=pop!(inUseCars)
				carsAvailable-=length(carChange)*(2Int(isNew)-1)
				@assert carsAvailable≥0
				carsAvailable==0 && continue
				availableAtEnd=carsAvailable
				for event ∈ inUseCars
					event[1][1]>availableFromTime+carTravelTime && break
					inter=intersect(itemsLeft,event[2].remove)
					setdiff!(itemsLeft,inter)
					setdiff!(event[2].remove,inter)
					event[1][1]==availableFromTime+carTravelTime && break
					availableAtEnd-=length(event[2])*(2Int(event[1][2])-1)
				end
				realAvailable=min(carsAvailable,availableAtEnd)
			end
			carsUsed=min(realAvailable,length(itemsLeft))
			carsAvailable-=carsUsed
			items=Iterators.take(itemsLeft,carsUsed)
			for item ∈ items
				push!(inUseCars,availableFromTime+carTravelTime,false,true,item)
			end
			push!(carHistory,(availableFromTime,(job,carsUsed,true)))
			setdiff!(itemsLeft,items)
			lastDeliverTime=availableFromTime
		end
		machine=selectMachine(job,timetable,sums)
		assignment[job]=machine
		startTime=max(sums[machine],lastDeliverTime+carTravelTime)
		times[job]=startTime
		sums[machine]=startTime+jobLengths[job]

		backAvailableFrom=startTime+jobLengths[job]
		itemsLeft=copy(itemsNeeded[job])
		backAvailable=carsAvailable
		inUseCars2=copy(inUseCars)
		while !isempty(inUseCars2) && first(inUseCars2)[1][1]<backAvailableFrom
			event=pop!(inUseCars2)
			backAvailable-=length(event[2])*(2Int(event[1][2])-1)
		end
		while length(itemsLeft)>0
			availableAtEnd=backAvailable
			for event ∈ inUseCars2
				event[1][1]≥availableFromTime+carTravelTime && break
				availableAtEnd-=length(event[2])*(2Int(event[1][2])-1)
			end
			realAvailable=min(backAvailable,availableAtEnd)
			while realAvailable≤0
				@assert realAvailable==0
				(backAvailableFrom,isNew),carChange=pop!(inUseCars2)
				backAvailable-=length(carChange)*(2Int(isNew)-1)
				@assert backAvailable≥0
				backAvailable==0 && continue
				availableAtEnd=backAvailable
				for event ∈ inUseCars2
					event[1][1]≥backAvailable+carTravelTime && break
					availableAtEnd-=length(event[2])*(2Int(event[1][2])-1)
				end
				@assert availableAtEnd≥0
				realAvailable=min(backAvailable,availableAtEnd)
			end
			carsUsed=min(realAvailable,length(itemsLeft))
			backAvailable-=carsUsed
			items=Iterators.take(itemsLeft,carsUsed)
			entry=EventEntry(BitSet(),BitSet(items))
			push!(inUseCars,backAvailableFrom,true,entry)
			push!(inUseCars,backAvailableFrom+carTravelTime,false,entry)
			push!(inUseCars2,backAvailableFrom+carTravelTime,false,entry)
			push!(carHistory,(backAvailableFrom,(job,carsUsed,false)))
			setdiff!(itemsLeft,items)
		end
	end
	Schedule(assignment,times),maximum(sums),carHistory
end