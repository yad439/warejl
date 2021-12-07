function likehoodBased(difference, firstJob = 1)
	n = size(difference, 1)
	@assert size(difference, 2) == n

	perm = Vector{Int}(undef, n)
	left = collect(1:n)
	perm[1] = firstJob
	deleteat!(left, firstJob)
	for i = 2:n
		j = argmin([difference[perm[i-1], k] for k ∈ left])
		perm[i] = left[j]
		deleteat!(left, j)
	end
	@assert Set(1:n) == Set(perm)
	perm
end

function greedyConstructive(problem, scoreFunction)
	result = [1]
	for len = 2:problem.jobCount
		ind = argmin(1:len) do i
			new = copy(result)
			insert!(new, i, len)
			scoreFunction(PermutationEncoding(new))
		end
		insert!(result, ind, len)
	end
	result
end