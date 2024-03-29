using DataStructures

include("structures.jl")

function computeSolutionLazyReturn(permutation, problem::Problem)::Solution
    machineCount = problem.machineCount
    jobLengths = problem.jobLengths
    itemsNeeded = problem.itemsNeeded
    robotCount = problem.robotCount
    travelTime = problem.travelTime
    bufferSize = problem.bufferSize

    sums = fill(zero(eltype(jobLengths)), machineCount)
    times = similar(jobLengths)
    assignments = similar(jobLengths, Int)
    inUseCars = EventQueue()
    robotHistory = EventQueue4()
    carsAvailable = robotCount
    availableFromTime = 0 # points at last add travel start
    bufferState = BitSet()
    lockTime = Dict{Int,Int}()
    for (ind, job) ∈ Iterators.enumerate(permutation)
        itemsLeft = setdiff(itemsNeeded[job], bufferState)
        while !isempty(itemsLeft)
            while carsAvailable ≤ 0
                @assert carsAvailable ≥ 0
                (availableFromTime, carChange) = popfirst!(inUseCars)
                carsAvailable += carChange
                @assert carsAvailable ≥ 0
            end
            if length(bufferState) < bufferSize
                carsUsed = min(carsAvailable, bufferSize - length(bufferState), length(itemsLeft))
                toAdd = Iterators.take(itemsLeft, carsUsed)
                carsAvailable -= carsUsed
                push!(inUseCars, availableFromTime + travelTime, carsUsed)
                push!(robotHistory, availableFromTime + travelTime, toAdd, nothing)
                @assert isdisjoint(bufferState, toAdd)
                @assert toAdd ⊆ itemsLeft
                union!(bufferState, toAdd)
                setdiff!(itemsLeft, toAdd)
            else
                activeLocks = [(it, lockTime[it]) for it ∈ bufferState if it ∉ itemsNeeded[job]]
                minLockTime = max(minimum(lock[2] for lock ∈ activeLocks), availableFromTime + travelTime)
                while !isempty(inUseCars) && first(inUseCars)[1] ≤ minLockTime - travelTime
                    (availableFromTime, carChange) = popfirst!(inUseCars)
                    carsAvailable += carChange
                end
                availableFromTime = max(availableFromTime, minLockTime - travelTime)
                minLocks = [it[1] for it ∈ activeLocks if it[2] ≤ minLockTime]
                nexts = Iterators.map(item -> findnext(jb -> item ∈ itemsNeeded[jb], permutation, ind + 1), minLocks) |> fmap(it -> it ≡ nothing ? typemax(Int) : it)
                nextsDict = Dict(Iterators.zip(minLocks, nexts))
                sort!(minLocks, by=it -> nextsDict[it], rev=true)
                changesNum = min(carsAvailable, length(minLocks), length(itemsLeft))
                toRemove = Iterators.take(minLocks, changesNum)
                toAdd = Iterators.take(itemsLeft, changesNum)
                for item ∈ toRemove
                    delete!(lockTime, item)
                end
                carsAvailable -= changesNum
                push!(inUseCars, availableFromTime + 2travelTime, changesNum)
                push!(robotHistory, availableFromTime + travelTime, toAdd, toRemove)
                @assert toRemove ⊆ bufferState
                @assert isdisjoint(bufferState, toAdd)
                @assert toAdd ⊆ itemsLeft
                setdiff!(bufferState, toRemove)
                union!(bufferState, toAdd)
                setdiff!(itemsLeft, toAdd)
            end
            @assert length(bufferState) ≤ bufferSize
            @assert carsAvailable ≥ 0
        end
        machine = 0
        for i = 1:machineCount
            if sums[i] ≤ availableFromTime + travelTime
                machine = i
                break
            end
        end
        assignments[job] = machine ≠ 0 ? machine : argmin(sums)
        startTime = max(sums[machine], availableFromTime + travelTime)
        times[job] = startTime
        sums[machine] = startTime + jobLengths[job]
        for item ∈ itemsNeeded[job]
            lockTime[item] = max(get(lockTime, item, 0), startTime + jobLengths[job])
        end
    end
    Solution(times, assignments, robotHistory.data)
end

function computeTimeLazyReturn(permutation, problem::Problem, sortRemoves=true)
    machineCount = problem.machineCount
    jobLengths = problem.jobLengths
    itemsNeeded = problem.itemsNeeded
    carCount = problem.robotCount
    carTravelTime = problem.travelTime
    bufferSize = problem.bufferSize

    sums = fill(zero(eltype(jobLengths)), machineCount)
    inUseCars = EventQueue()
    carsAvailable = carCount
    availableFromTime = 0 # points at last add travel start
    bufferState = BitSet()
    itemNum = problem.itemCount
    lockTime = zeros(Int, itemNum)
    nexts = zeros(Int, itemNum)
    minLocks = Vector{Int}(undef, bufferSize)
    itemsLeft = BitSet()
    sizehint!(itemsLeft, itemNum)
    for (ind, job) ∈ Iterators.enumerate(permutation)
        setdiff!(itemsLeft, itemsLeft)
        union!(itemsLeft, itemsNeeded[job])
        setdiff!(itemsLeft, bufferState)
        while !isempty(itemsLeft)
            while carsAvailable ≤ 0
                (availableFromTime, carChange) = popfirst!(inUseCars)
                carsAvailable += carChange
            end
            if length(bufferState) < bufferSize
                carsUsed = min(carsAvailable, bufferSize - length(bufferState), length(itemsLeft))
                toAdd = Iterators.take(itemsLeft, carsUsed)
                carsAvailable -= carsUsed
                push!(inUseCars, availableFromTime + carTravelTime, carsUsed)
                union!(bufferState, toAdd)
                setdiff!(itemsLeft, toAdd)
            else
                minLocksLen = 0
                minLockTime = typemax(Int)
                @inbounds for item ∈ bufferState
                    item ∉ itemsNeeded[job] || continue
                    if lockTime[item] < minLockTime && minLockTime > availableFromTime + carTravelTime
                        minLockTime = lockTime[item]
                        minLocksLen = 1
                        minLocks[1] = item
                    elseif lockTime[item] == minLockTime || lockTime[item] ≤ availableFromTime + carTravelTime
                        minLocksLen += 1
                        @inbounds minLocks[minLocksLen] = item
                        if lockTime[item] > minLockTime
                            minLockTime = lockTime[item]
                        end
                    end
                end
                if sortRemoves
                    for i = 1:minLocksLen
                        item = minLocks[i]
                        if nexts[item] ≤ ind
                            nxt = findnext(jb -> item ∈ itemsNeeded[jb], permutation, ind + 1)
                            nexts[item] = nxt ≡ nothing ? length(permutation) + 1 : nxt
                        end
                    end
                    sort!(view(minLocks, 1:minLocksLen), by=it -> nexts[it], rev=true)
                end
                while !isempty(inUseCars) && first(inUseCars)[1] ≤ minLockTime - carTravelTime
                    (availableFromTime, carChange) = popfirst!(inUseCars)
                    carsAvailable += carChange
                end
                availableFromTime = max(availableFromTime, minLockTime - carTravelTime)
                changesNum = min(carsAvailable, minLocksLen, length(itemsLeft))
                toRemove = Iterators.take(minLocks, changesNum)
                toAdd = Iterators.take(itemsLeft, changesNum)
                carsAvailable -= changesNum
                push!(inUseCars, availableFromTime + 2carTravelTime, changesNum)
                setdiff!(bufferState, toRemove)
                union!(bufferState, toAdd)
                setdiff!(itemsLeft, toAdd)
            end
        end
        machine = 0
        minSum = typemax(Int)
        for i = 1:machineCount
            if sums[i] ≤ availableFromTime + carTravelTime
                machine = i
                break
            end
            if sums[i] < minSum
                minSum = sums[i]
                machine = i
            end
        end
        startTime = max(sums[machine], availableFromTime + carTravelTime)
        sums[machine] = startTime + jobLengths[job]
        @inbounds for item ∈ itemsNeeded[job]
            @inbounds lockTime[item] = max(lockTime[item], startTime + jobLengths[job])
        end
    end
    maximum(sums)
end

#=function computeTimeLazyReturn(timetable, problem, ::Val{0.5}, sortRemoves = true)
	machineCount = problem.machineCount
	jobLengths = problem.jobLengths
	itemsNeeded = problem.itemsNeeded
	carCount = problem.carCount
	carTravelTime = problem.carTravelTime
	bufferSize = problem.bufferSize

	sums = fill(zero(eltype(jobLengths)), machineCount)
	idles = Tuple{Int,Int}[]
	inUseCars = EventQueue()
	carsAvailable = carCount
	availableFromTime = 0 # points at last add travel start
	bufferState = BitSet()
	itemNum = problem.itemCount
	lockTime = zeros(Int, itemNum)
	nexts = similar(lockTime)
	minLocks = Vector{Int}(undef, bufferSize)
	itemsLeft = BitSet()
	sizehint!(itemsLeft, itemNum)
	for (ind, job) ∈ Iterators.enumerate(timetable.permutation)
		setdiff!(itemsLeft, itemsLeft)
		union!(itemsLeft, itemsNeeded[job])
		setdiff!(itemsLeft, bufferState)
		while !isempty(itemsLeft)
			while carsAvailable ≤ 0
				(availableFromTime, carChange) = popfirst!(inUseCars)
				carsAvailable += carChange
			end
			if length(bufferState) < bufferSize
				carsUsed = min(carsAvailable, bufferSize - length(bufferState), length(itemsLeft))
				toAdd = Iterators.take(itemsLeft, carsUsed)
				carsAvailable -= carsUsed
				push!(inUseCars, availableFromTime + carTravelTime, carsUsed)
				union!(bufferState, toAdd)
				setdiff!(itemsLeft, toAdd)
			else
				minLocksLen = 0
				minLockTime = typemax(Int)
				@inbounds for item ∈ bufferState
					item ∉ itemsNeeded[job] || continue
					if lockTime[item] < minLockTime && minLockTime > availableFromTime + carTravelTime
						minLockTime = lockTime[item]
						minLocksLen = 1
						minLocks[1] = item
					elseif lockTime[item] == minLockTime || lockTime[item] ≤ availableFromTime + carTravelTime
						minLocksLen += 1
						@inbounds minLocks[minLocksLen] = item
						if lockTime[item] > minLockTime
							minLockTime = lockTime[item]
						end
					end
				end
				if sortRemoves
					for i = 1:minLocksLen
						item = minLocks[i]
						nxt = findnext(jb -> item ∈ itemsNeeded[jb], timetable.permutation, ind + 1)
						nexts[item] = nxt ≡ nothing ? typemax(Int) : nxt
					end
					sort!(view(minLocks, 1:minLocksLen), by = it -> nexts[it], rev = true)
				end
				while !isempty(inUseCars) && first(inUseCars)[1] ≤ minLockTime - carTravelTime
					(availableFromTime, carChange) = popfirst!(inUseCars)
					carsAvailable += carChange
				end
				availableFromTime = max(availableFromTime, minLockTime - carTravelTime)
				changesNum = min(carsAvailable, minLocksLen, length(itemsLeft))
				toRemove = Iterators.take(minLocks, changesNum)
				toAdd = Iterators.take(itemsLeft, changesNum)
				carsAvailable -= changesNum
				push!(inUseCars, availableFromTime + 2carTravelTime, changesNum)
				setdiff!(bufferState, toRemove)
				union!(bufferState, toAdd)
				setdiff!(itemsLeft, toAdd)
			end
		end
		machine = selectMachine(job, timetable, sums)
		startTime = max(sums[machine], availableFromTime + carTravelTime)
		idle = availableFromTime + carTravelTime - sums[machine]
		if idle > 0
			push!(idles, (ind, idle))
		end
		sums[machine] = startTime + jobLengths[job]
		@inbounds for item ∈ itemsNeeded[job]
			@inbounds lockTime[item] = max(lockTime[item], startTime + jobLengths[job])
		end
	end
	maximum(sums), idles
end=#

#=function computeTimeBufferOnly(timetable, problem)
	sums = fill(zero(eltype(problem.jobLengths)), problem.machineCount)
	bufferState = BitSet()
	lockTimes = zeros(Int, problem.itemCount)
	minLocks = Vector{Int}(undef, problem.bufferSize)
	itemsLeft = BitSet()
	sizehint!(itemsLeft, problem.itemCount)
	for job ∈ timetable.permutation
		machine = selectMachine(job, timetable, sums)
		machineTime = sums[machine]
		lockTime = 0

		setdiff!(itemsLeft, itemsLeft)
		union!(itemsLeft, problem.itemsNeeded[job])
		setdiff!(itemsLeft, bufferState)

		if length(bufferState) < problem.bufferSize
			add = Iterators.take(itemsLeft, problem.bufferSize - length(bufferState))
			union!(bufferState, add)
			setdiff!(itemsLeft, add)
		end

		while !isempty(itemsLeft)
			minLocksLen = 0
			minLockTime = typemax(Int)
			@inbounds for item ∈ bufferState
				item ∉ problem.itemsNeeded[job] || continue
				if lockTimes[item] < minLockTime && minLockTime > machineTime
					minLockTime = lockTimes[item]
					minLocksLen = 1
					minLocks[1] = item
				elseif lockTimes[item] == minLockTime || lockTimes[item] ≤ machineTime
					minLocksLen += 1
					@inbounds minLocks[minLocksLen] = item
					if lockTimes[item] > minLockTime
						minLockTime = lockTimes[item]
					end
				end
			end
			changeNum = min(minLocksLen, length(itemsLeft))
			remove = Iterators.take(minLocks, changeNum)
			add = Iterators.take(itemsLeft, changeNum)
			setdiff!(bufferState, remove)
			union!(bufferState, add)
			setdiff!(itemsLeft, add)
			lockTime = minLockTime
		end
		startTime = max(machineTime, lockTime)
		sums[machine] = startTime + problem.jobLengths[job]
		@inbounds for item ∈ problem.itemsNeeded[job]
			@inbounds lockTimes[item] = max(lockTimes[item], startTime + problem.jobLengths[job])
		end
	end
	maximum(sums)
end=#

#=function improveSolution(solution, problem)
    if any(==(0), problem.jobLengths)
        @warn "Zero-length job"
        return solution
    end
    jobs = [Job(
        solution.times[i],
        solution.times[i] + problem.jobLengths[i]
    ) for i = 1:problem.jobCount]
    tasks = [CarTask(t.time,
        t.time + problem.carTravelTime,
        t.item, t.isAdd
    ) for t ∈ solution.carTasks]
    fullTime = max(
        maximum(i -> i.endTime, jobs),
        maximum(t -> t.endTime, tasks)
    )
    changed = true
    machineUsage = OffsetVector(zeros(Int, fullTime + 1), 0:fullTime)
    for job ∈ jobs
        machineUsage[job.startTime:job.endTime-1] .+= 1
    end
    @assert all(≤(problem.machineCount), machineUsage)
    carUsage = OffsetVector(zeros(Int, fullTime + 1), 0:fullTime)
    for task ∈ tasks
        for t = task.startTime:task.endTime-1
            carUsage[t] += 1
        end
    end
    @assert all(≤(problem.carCount), carUsage)
    itemLocks = OffsetMatrix(falses(fullTime + 1, problem.itemCount), 0:fullTime, :)
    for j = 1:problem.jobCount
        for i ∈ problem.itemsNeeded[j]
            for t = jobs[j].startTime:jobs[j].endTime-1
                itemLocks[t, i] = true
            end
        end
    end
    bufferUsage = OffsetVector(zeros(Int, fullTime + 1), 0:fullTime)
    for task ∈ tasks
        if task.isAdd
            bufferUsage[task.endTime:end] .+= 1
        else
            bufferUsage[task.startTime:end] .-= 1
        end
    end
    @assert all(≥(0), bufferUsage)
    @assert all(≤(problem.bufferSize), bufferUsage)
    bufferItems = OffsetMatrix(falses(fullTime + 1, problem.itemCount), 0:fullTime, :)
    for task ∈ tasks
        if task.isAdd
            bufferItems[task.endTime:end, task.item] .= true
        else
            bufferItems[task.startTime:end, task.item] .= false
        end
    end
    @assert all(t -> sum(bufferItems[t, :]) ≤ problem.bufferSize, 0:fullTime)
    while changed
        changed = false
        for task ∈ tasks
            task.isAdd && continue
            itemFreed = findprev(itemLocks[:, task.item], task.startTime - 1) + 1
            @assert !isnothing(itemFreed)
            itemFreed ≥ task.startTime && continue
            carFreed = something(findprev(==(problem.carCount), carUsage, task.startTime - 1), -1) + 1
            carFreed ≥ task.startTime && continue

            newTime = max(itemFreed, carFreed)
            for t = newTime:task.startTime-1
                bufferUsage[t] -= 1
                bufferItems[t, task.item] = false
            end
            for t = task.startTime:task.endTime-1
                carUsage[t] -= 1
            end
            task.startTime = newTime
            task.endTime = newTime + problem.carTravelTime
            for t = task.startTime:task.endTime-1
                carUsage[t] += 1
            end
            changed = true
        end
        for task ∈ tasks
            task.isAdd || continue
            carFreed = something(findprev(==(problem.carCount), carUsage, task.startTime - 1), -1) + 1
            carFreed ≥ task.startTime && continue
            bufferFreed = something(findprev(==(problem.bufferSize), bufferUsage, task.endTime - 1), -1) + 1

            if bufferFreed ≥ task.endTime
                nextTask = nothing
                minNext = typemax(Int)
                for task2 ∈ tasks
                    (task2.isAdd || task2.startTime ≠ task.endTime) && continue
                    itemFreed = findprev(itemLocks[:, task2.item], task2.startTime - 1) + 1
                    if itemFreed < minNext
                        nextTask = task2
                        minNext = itemFreed
                    end
                end
                @assert nextTask ≢ nothing
                minNext < task.endTime || continue
                newTime = max(carFreed, minNext - problem.carTravelTime)
                for t = newTime+problem.carTravelTime:task.endTime-1
                    bufferUsage[t] += 1
                    bufferItems[t, task.item] = true
                end
                for t = newTime+problem.carTravelTime:nextTask.startTime-1
                    bufferUsage[t] -= 1
                    bufferItems[t, nextTask.item] = false
                end
                for t = task.startTime:nextTask.endTime-1
                    carUsage[t] -= 1
                end
                task.startTime = newTime
                task.endTime = newTime + problem.carTravelTime
                nextTask.startTime = newTime + problem.carTravelTime
                nextTask.endTime = newTime + 2problem.carTravelTime
                for t = task.startTime:nextTask.endTime-1
                    carUsage[t] += 1
                end
            else
                newTime = max(bufferFreed - problem.carTravelTime, carFreed)
                for t = newTime+problem.carTravelTime:task.endTime-1
                    bufferUsage[t] += 1
                    bufferItems[t, task.item] = true
                end
                for t = task.startTime:task.endTime-1
                    carUsage[t] -= 1
                end
                task.startTime = newTime
                task.endTime = newTime + problem.carTravelTime
                for t = task.startTime:task.endTime-1
                    carUsage[t] += 1
                end
            end

            changed = true
        end
        for (j, job) ∈ enumerate(jobs)
            machineFreed = something(findprev(==(problem.machineCount), machineUsage, job.startTime - 1), -1) + 1
            machineFreed ≥ job.startTime && continue
            itemsAvailable = maximum(
                findprev(==(false), bufferItems[:, i], job.startTime - 1) + 1
                for i ∈ problem.itemsNeeded[j])
            itemsAvailable ≥ job.startTime && continue

            newTime = max(machineFreed, itemsAvailable)
            for t = job.startTime:job.endTime-1
                machineUsage[t] -= 1
            end
            for t in job.startTime:job.endTime-1, i ∈ problem.itemsNeeded[j]
                itemLocks[t, i] = reduce((a, b) -> a || b, (jb.startTime ≤ t < job.endTime for jb ∈ jobs if jb ≢ job))
            end
            job.startTime = newTime
            job.endTime = newTime + problem.jobLengths[j]
            for t = job.startTime:job.endTime-1
                machineUsage[t] += 1
            end
            for t in job.startTime:job.endTime-1, i ∈ problem.itemsNeeded[j]
                itemLocks[t, i] = true
            end
            changed = true
        end
    end

    newPerm = sortperm(map(j -> j.startTime, jobs))
    sums = zeros(Int, problem.machineCount)
    newAssignment = similar(solution.assignment)
    for j ∈ newPerm
        machine = findfirst(≤(jobs[j].startTime), sums)
        @assert machine ≢ nothing
        newAssignment[j] = machine
        sums[machine] = jobs[j].endTime
    end
    Schedule(
        newAssignment,
        map(j -> j.startTime, jobs),
        map(t -> (time=t.startTime, item=t.item, isAdd=t.isAdd), tasks)
    )
end

mutable struct Job
    startTime::Int
    endTime::Int
end

mutable struct CarTask
    startTime::Int
    endTime::Int
    item::Int
    isAdd::Bool
end=#