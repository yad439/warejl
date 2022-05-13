include("encodings.jl")

using OffsetArrays

distance(jobs1::PermutationEncoding, jobs2::PermutationEncoding,) = damerauLevenshteinDistance(jobs1.permutation, jobs2.permutation)
# distance(jobs1::TwoVectorEncoding, jobs2::TwoVectorEncoding) = assignmentDistance(jobs1.assignment, jobs2.assignment, jobs1.machineCount) + damerauLevenshteinDistance(jobs1.permutation, jobs2.permutation)
normalizedDistance(jobs1::PermutationEncoding, jobs2::PermutationEncoding) = 2distance(jobs1, jobs2) / length(jobs1)
# normalizedDistance(jobs1::TwoVectorEncoding, jobs2::TwoVectorEncoding) = distance(jobs1, jobs2) / 2length(jobs1)

function damerauLevenshteinDistanceOSA(perm1, perm2)
	len = length(perm1)
	@assert length(perm2) == len
	d = OffsetMatrix(Matrix{Int}(undef, len + 1, len + 1), 0:len, 0:len)
	d[:, 0] = 0:len
	d[0, :] = 0:len
	for i ∈ eachindex(perm1), j ∈ eachindex(perm2)
		cost = Int(perm1[i] ≠ perm2[j])
		d[i, j] = min(
			d[i-1, j] + 1, # deletion
			d[i, j-1] + 1, # insertion
			d[i-1, j-1] + cost, # substitution
		)
		if i > 1 && j > 1 && perm1[i] == perm2[j-1] && perm1[i-1] == perm2[j]
			d[i, j] = min(d[i, j], d[i-2, j-2] + 1)# transposition
		end
	end
	d[len, len]
end

function damerauLevenshteinDistance(a, b)
	n = length(a)
	@assert length(b) == n

	da = zeros(Int, n)
	d = OffsetMatrix(Matrix{Float64}(undef, n + 2, n + 2), -1:n, -1:n)

	maxdist = 2n
	d[-1, -1] = maxdist
	for i = 0:n
		d[i, -1] = maxdist
		d[i, 0] = i / 2
		d[-1, i] = maxdist
		d[0, i] = i / 2
	end

	for i = 1:n
		db = 0
		for j = 1:n
			k = da[b[j]]
			l = db
			if a[i] == b[j]
				cost = 0
				db = j
			else
				cost = 0.5
			end
			d[i, j] = min(d[i-1, j-1] + cost,# substitution
				d[i, j-1] + 0.5,# insertion
				d[i-1, j] + 0.5,# deletion
				d[k-1, l-1] + (i - k - 1) + 1 + (j - l - 1))# transposition
		end
		da[a[i]] = i
	end
	d[n, n]
end

function assignmentDistance(list1, list2, machineCount)
	swap = [Vector{Int}(undef, 0) for _ = 1:machineCount]
	dist = 0
	for i ∈ eachindex(list1)
		list1[i] == list2[i] && continue
		ind = findlast(==(list1[i]), swap[list2[i]])
		if ind ≡ nothing
			dist += 1
			push!(swap[list1[i]], list2[i])
		else
			deleteat!(swap[list2[i]], ind)
		end
	end
	dist
end
hammingDistance(vec1, vec2) = count(it -> it[1] ≠ it[2], Iterators.zip(vec1, vec2))