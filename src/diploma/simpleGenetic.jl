using Random
using DataStructures
using ProgressMeter
using Statistics

import Base.isless,Base.isequal

include("auxiliary.jl")

function genetic(n,m,p,popSize)
	progress=ProgressThresh(zero(eltype(p)),"Genetic:")
	history=Vector{Float64}(undef,0)

	# Random.seed!(12)
	population=map(1:popSize) do i
		tasks=rand(1:m,n)
		score=maxTime(tasks,p,m)
		Entity(tasks,score)
	end
	sort!(population)

	minCount=0

	push!(history,mean(map(it->it.value,population)))

	while minCount<500
		# toCross=randsubseq(population,0.3)
		toCross=rand(population,3)
		parent1=minimum(toCross)
		# toCross=randsubseq(population,0.3)
		toCross=rand(population,3)
		parent2=minimum(toCross)
		child=crossover(parent1.tasks,parent2.tasks)
		mutate!(child)
		score=maxTime(child,p,m)
		# maxi=argmax(population)
		# deleteat!(population,maxi)
		if score≥population[1].value
			minCount+=1
		else
			minCount=0
		end
		pop!(population)
		insertSorted!(population,Entity(child,score))

		push!(history,mean(map(it->it.value,population)))
		ProgressMeter.update!(progress,population[1].value,showvalues=[(:count,count)])
	end
	ProgressMeter.finish!(progress)
	population[1].tasks,population[1].value,history
end

struct Entity{T}
	tasks::Vector{Int}
	value::T
end
isless(ent1::Entity,ent2::Entity)=ent1.value<ent2.value
isequal(ent1::Entity,ent2::Entity)=ent1.value==ent2.value

function mutate!(tasks)
	rand() < 0.5 && return
	n=length(tasks)
	pos1=rand(1:n)
	pos2=rand(1:n)
	tasks[pos1],tasks[pos2]=tasks[pos2],tasks[pos1]
	nothing
end

function crossover(parent₁,parent₂)
	n=length(parent₁)
	@assert(length(parent₂)==n)

	mid=rand(0:n)
	child=similar(parent₁)
	child[1:mid]=parent₁[1:mid]
	child[mid+1:n]=parent₂[mid+1:n]
	child
end

function insertSorted!(list,value)
	pos=searchsortedfirst(list,value)
	insert!(list,pos,value)
end
