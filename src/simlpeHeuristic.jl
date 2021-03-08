function likehoodBased(difference, firstJob=1)
	n = size(difference, 1)
	@assert size(difference, 2) == n

	perm = Vector{Int}(undef, n)
	left = collect(1:n)
	perm[1] = firstJob
	deleteat!(left, firstJob)
	for i = 2:n
		j = argmin([difference[perm[i - 1],k] for k ∈ left])
		perm[i] = left[j]
		deleteat!(left, j)
	end
	@assert Set(1:n) == Set(perm)
	perm
end