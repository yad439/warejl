function pmxCrossover(list1, list2)
	n = length(list1)
	@assert length(list2) == n
	startIndex, endIndex = minmax(rand(1:n), rand(1:n))
	while startIndex == 1 && endIndex == n
		startIndex, endIndex = minmax(rand(1:n), rand(1:n))
	end

	child = similar(list1)

	child[startIndex:endIndex] = @view list1[startIndex:endIndex]
	copied = falses(n)
	copied[@view list1[startIndex:endIndex]] .= true
	for i = startIndex:endIndex
		copied[list2[i]] && continue
		index = i
		cont = true
		while cont
			val2 = list1[index]
			index2 = findfirst(==(val2), list2)::Int
			if index2 ∈ startIndex:endIndex
				index = index2
			else
				child[index2] = list2[i]
				copied[list2[i]] = true
				cont = false
			end
		end
	end
	for i = 1:n
		copied[list2[i]] || (child[i] = list2[i])
	end
	# @assert all(∈(child), 1:n)
	child
end

function order1Crossover(list1, list2)
	n = length(list1)
	@assert length(list2) == n
	startIndex, endIndex = minmax(rand(1:n), rand(1:n))
	while startIndex == 1 && endIndex == n
		startIndex, endIndex = minmax(rand(1:n), rand(1:n))
	end

	child = similar(list1)

	child[startIndex:endIndex] = @view list1[startIndex:endIndex]
	copied = falses(n)
	copied[@view list1[startIndex:endIndex]] .= true
	ind = startIndex ≠ 1 ? 1 : endIndex + 1
	for i = 1:n
		copied[list2[i]] && continue
		child[ind] = list2[i]
		ind += 1
		ind == startIndex && (ind = endIndex + 1)
	end
	# @assert all(∈(child), 1:n)
	child
end

function cycleCrossover(list1, list2)
	n = length(list1)
	@assert length(list2) == n

	child = similar(list1)
	copied = falses(n)
	takeFirst = rand(Bool)
	for i = 1:n
		copied[i] && continue
		child[i] = takeFirst ? list1[i] : list2[i]
		copied[i] = true
		ind = findfirst(==(list2[i]), list1)::Int
		while ind ≠ i
			@assert !copied[ind]
			child[ind] = takeFirst ? list1[ind] : list2[ind]
			copied[ind] = true
			ind = findfirst(==(list2[ind]), list1)::Int
		end
		takeFirst = !takeFirst
	end
	# @assert all(copied)
	# @assert all(∈(child), 1:n)
	child
end