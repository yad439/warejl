using DataStructures

include("auxiliary.jl")

maxTimeWithCars(jobs::TwoVectorEncoding,jobLengths,carNeeded,machineCount,carCount,carTravelTime)=computeTimeWithCars(jobs::TwoVectorEncoding,jobLengths,carNeeded,machineCount,carCount,carTravelTime)[2]
function computeTimeWithCars(jobs::TwoVectorEncoding,jobLengths,carNeeded,machineCount,carCount,carTravelTime)
	sums=fill(zero(eltype(jobLengths)),machineCount)
	times=similar(jobLengths)
	inUseCars=Queue{Tuple{eltype(jobLengths),Int}}()
	carHistory=Tuple{eltype(jobLengths),Int}[]
	carsAvailable=carCount
	availableFromTime=0
	for job ∈ jobs.permutation
		# currentTime=availableFromTime
		itemsDelivered=carsAvailable
		if carsAvailable>carNeeded[job]
			carsAvailable-=carNeeded[job]
			enqueue!(inUseCars,(availableFromTime+carTravelTime,carNeeded[job]))
			push!(carHistory,(availableFromTime,carNeeded[job]))
		else
			if carsAvailable≠0
				enqueue!(inUseCars,(availableFromTime+carTravelTime,carsAvailable))
				push!(carHistory,(availableFromTime,carsAvailable))
			end
			carsAvailable=0
		end
		currentTime=availableFromTime+carTravelTime
		while itemsDelivered<carNeeded[job]
			(availableFromTime,carsFreed)=dequeue!(inUseCars)

			if carsFreed>carNeeded[job]-itemsDelivered
				carsAvailable=carsFreed-carNeeded[job]+itemsDelivered
				availableFromTime=currentTime
				enqueue!(inUseCars,(currentTime+carTravelTime,carNeeded[job]-itemsDelivered))
				push!(carHistory,(currentTime,carNeeded[job]-itemsDelivered))
			else
				enqueue!(inUseCars,(currentTime+carTravelTime,carsFreed))
				push!(carHistory,(currentTime,carsFreed))
			end
			itemsDelivered+=carsFreed
			currentTime=availableFromTime+carTravelTime
		end
		machine=jobs.assignment[job]
		startTime=max(sums[machine],currentTime)
		times[job]=startTime
		sums[machine]=startTime+jobLengths[job]
	end
	Schedule(jobs.assignment,times),maximum(sums),carHistory
end

maxTimeWithCars(jobs::PermutationEncoding,jobLengths,carNeeded,machineCount,carCount,carTravelTime)=computeTimeWithCars(jobs::TwoVectorEncoding,jobLengths,carNeeded,machineCount,carCount,carTravelTime)[2]
function computeTimeWithCars(jobs::PermutationEncoding,jobLengths,carNeeded,machineCount,carCount,carTravelTime)
	sums=fill(zero(eltype(jobLengths)),machineCount)
	times=similar(jobLengths)
	assignment=similar(jobLengths,Int)
	inUseCars=Queue{Tuple{eltype(jobLengths),Int}}()
	carHistory=Tuple{eltype(jobLengths),Int}[]
	carsAvailable=carCount
	availableFromTime=0
	for job ∈ jobs.permutation
		# currentTime=availableFromTime
		itemsDelivered=carsAvailable
		if carsAvailable>carNeeded[job]
			carsAvailable-=carNeeded[job]
			enqueue!(inUseCars,(availableFromTime+carTravelTime,carNeeded[job]))
			push!(carHistory,(availableFromTime,carNeeded[job]))
		else
			if carsAvailable≠0
				enqueue!(inUseCars,(availableFromTime+carTravelTime,carsAvailable))
				push!(carHistory,(availableFromTime,carsAvailable))
			end
			carsAvailable=0
		end
		currentTime=availableFromTime+carTravelTime
		while itemsDelivered<carNeeded[job]
			(availableFromTime,carsFreed)=dequeue!(inUseCars)

			if carsFreed>carNeeded[job]-itemsDelivered
				carsAvailable=carsFreed-carNeeded[job]+itemsDelivered
				availableFromTime=currentTime
				enqueue!(inUseCars,(currentTime+carTravelTime,carNeeded[job]-itemsDelivered))
				push!(carHistory,(currentTime,carNeeded[job]-itemsDelivered))
			else
				enqueue!(inUseCars,(currentTime+carTravelTime,carsFreed))
				push!(carHistory,(currentTime,carsFreed))
			end
			itemsDelivered+=carsFreed
			currentTime=availableFromTime+carTravelTime
		end
		machine=argmin(sums)
		assignment[job]=machine
		startTime=max(sums[machine],currentTime)
		times[job]=startTime
		sums[machine]=startTime+jobLengths[job]
	end
	times,maximum(sums),carHistory
end

maxTimeWithCarsUnoptimized(jobs::TwoVectorEncoding,jobLengths,carsNeeded,machineCount,carCount,carTravelTime)=computeTimeWithCarsUnoptimized(jobs::TwoVectorEncoding,jobLengths,carsNeeded,machineCount,carCount,carTravelTime)[2]
function computeTimeWithCarsUnoptimized(jobs::TwoVectorEncoding,jobLengths,carsNeeded,machineCount,carCount,carTravelTime)
	machineTimes=fill(zero(eltype(jobLengths)),machineCount)
	times=similar(jobLengths)
	inUseCars=Queue{Tuple{eltype(jobLengths),Int}}()
	carHistory=Tuple{eltype(jobLengths),Int}[]
	carsAvailable=carCount
	carTime=0
	for job ∈ jobs.permutation
		while carsAvailable<carsNeeded[job]
			(carTime,carsFreed)=dequeue!(inUseCars)
			carsAvailable+=carsFreed
		end
		machine=jobs.assignment[job]
		startTime=max(machineTimes[machine],carTime)
		carsAvailable-=carsNeeded[job]
		enqueue!(inUseCars,(startTime+carTravelTime,carsNeeded[job]))
		push!(carHistory,(startTime,carsNeeded[job]))
		times[job]=startTime
		machineTimes[machine]=startTime+jobLengths[job]
	end
	Schedule(jobs.assignment,times),maximum(machineTimes),carHistory
end

maxTimeWithCarsUnoptimized(jobs::PermutationEncoding,jobLengths,carsNeeded,machineCount,carCount,carTravelTime)=computeTimeWithCarsUnoptimized(jobs::PermutationEncoding,jobLengths,carsNeeded,machineCount,carCount,carTravelTime)[2]
function computeTimeWithCarsUnoptimized(jobs::PermutationEncoding,jobLengths,carsNeeded,machineCount,carCount,carTravelTime)
	machineTimes=fill(zero(eltype(jobLengths)),machineCount)
	times=similar(jobLengths)
	assignment=similar(jobLengths,Int)
	inUseCars=Queue{Tuple{eltype(jobLengths),Int}}()
	carHistory=Tuple{eltype(jobLengths),Int}[]
	carsAvailable=carCount
	carTime=0
	for job ∈ jobs.permutation
		while carsAvailable<carsNeeded[job]
			(carTime,carsFreed)=dequeue!(inUseCars)
			carsAvailable+=carsFreed
		end
		machine=argmin(machineTimes)
		assignment[job]=machine
		startTime=max(machineTimes[machine],carTime)
		carsAvailable-=carsNeeded[job]
		enqueue!(inUseCars,(startTime+carTravelTime,carsNeeded[job]))
		push!(carHistory,(startTime,carsNeeded[job]))
		times[job]=startTime
		machineTimes[machine]=startTime+jobLengths[job]
	end
	Schedule(assignment,times),maximum(machineTimes),carHistory
end