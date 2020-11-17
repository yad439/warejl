using DataStructures

include("auxiliary.jl")
include("structures.jl")

function computeTimeGetOnly(timetable::PermutationEncoding,machineCount,jobLengths,itemsNeeded,carCount,carTravelTime)
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
		machine=argmin(sums)
		assignment[job]=machine
		startTime=max(sums[machine],lastDeliverTime+carTravelTime)
		times[job]=startTime
		sums[machine]=startTime+jobLengths[job]
	end
	Schedule(assignment,times),maximum(sums),carHistory
end

function computeTimeNoWait(timetable::PermutationEncoding,machineCount,jobLengths,itemsNeeded,carCount,carTravelTime)
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
			carsUsed=min(realAvailable,itemsLeft)
			carsAvailable-=carsUsed
			realAvailable-=carsUsed
			push!(inUseCars,availableFromTime+carTravelTime,carsUsed)
			push!(carHistory,(availableFromTime,(job,carsUsed,true)))
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
		machine=argmin(sums)
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