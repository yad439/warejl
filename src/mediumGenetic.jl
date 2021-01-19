# using GeneticAlgorithms
using Random
using DataStructures

import Base.isless

n=10
m=3
p=rand(n)

struct Entity
	tasks
	value
end

isless(ent1::Entity,ent2::Entity)=ent1.value<ent2.value

function tableToList(table)
	n=size(table,2)
	list=Vector{Tuple{Int,Int}}(undef,n)
	for i ∈	axes(table,1)
		j=1
		while table[i,j]≠0
			list[table[i,j]]=i,j
			j+=1
		end
	end
	list
end
function listToTable(list,m)
	table=fill(0,m,length(list))
	for (num,(i,j)) ∈ Iterators.enumerate(list)
		table[i,j]=num
	end
	table
end

function totalTime(taskLengths,list::Vector{Tuple{Int,Int}})
	lengths=zeros(m)
	for (i,task) in Iterators.enumerate(list)
		lengths[task[1]]+=taskLengths[i]
	end
	@assert sum(lengths)≈sum(taskLengths)
	maximum(lengths)
end
function totalTime(taskLengths,table::Matrix{Int})
	maxT=0.0
	for i ∈ axes(table,1)
		tmpSum=0.0
		j=1
		while table[i,j]≠0
			tmpSum+=taskLengths[table[i,j]]
			j+=1
		end
		(tmpSum>maxT) && (maxT=tmpSum)
	end
	maxT
end

function mutate(list::Vector{Tuple{Int,Int}})
    # let's go crazy and mutate 20% of the time
    rand(Float64) < 0.8 && return
	n=length(list)

    pos1=rand(1:n)
	pos2=rand(1:n)
    list[pos1],list[pos2]=list[pos2],list[pos1]
end

function mutate!(table::Matrix{Int})
	m,n=size(table)
	i1=rand(axes(table,1))
	i2=rand(axes(table,1))
	j1=rand(axes(table,2))
	j2=rand(axes(table,2))
	if table[i1,j1]≠0 && table[i2,j2]≠0
		table[i1,j1],table[i2,j2]=table[i2,j2],table[i1,j1]
	end
end

function crossover(parent1::Matrix{Int},parent2::Matrix{Int})
	@assert size(parent1)==size(parent2)
	m,n=size(parent1)
	fromFirst=rand(1:n)
	insertedCount=0
	inserted=BitSet()
	child=fill(0,m,n)
	for i ∈ eachindex(parent1)
		if parent1[i]!=0
			child[i]=parent1[i]
			insertedCount+=1
			push!(inserted,parent1[i])
			insertedCount≥fromFirst && break
		end
	end
	@assert length(inserted)==insertedCount
	firstZero=map(i->findfirst(==(0),child[i,:]),1:m)
	for i=1:m
		j=1
		while parent2[i,j]≠0
			if parent2[i,j] ∉ inserted
				child[i,firstZero[i]]=parent2[i,j]
				firstZero[i]+=1
			end
			j+=1
		end
	end
	@assert all(∈(child),1:n)
	child
end

function generateVectorEntity(n,m)
	tasks=BitSet(1:n)
	firstZero=fill(1,m)
	res=Vector{Tuple{Int,Int}}(undef,n)
	for i=1:n
		task=rand(tasks)
		delete!(tasks,task)
		machine=rand(1:m)
		res[task]=machine,firstZero[machine]
		firstZero[machine]+=1
	end
	res
end

function generateMatrixEntity(n,m)
	tasks=BitSet(1:n)
	firstZero=fill(1,m)
	res=fill(0,m,n)
	for i=1:n
		task=rand(tasks)
		delete!(tasks,task)
		machine=rand(1:m)
		res[machine,firstZero[machine]]=task
		firstZero[machine]+=1
	end
	@assert all(∈(res),1:n)
	res
end

function genetic(n,m,p,popSize)
	Random.seed!(12)
	population=map(1:popSize) do i
		tasks=generateMatrixEntity(n,m)
		score=totalTime(p,tasks)
		Entity(tasks,score)
	end
	for t=1:1000
		# toCross=randsubseq(population,0.3)
		toCross=rand(population,1)
		parent1=minimum(toCross)
		# toCross=randsubseq(population,0.3)
		toCross=rand(population,1)
		parent2=minimum(toCross)
		child=crossover(parent1.tasks,parent2.tasks)
		mutate!(child)
		mutate!(child)
		mutate!(child)
		mutate!(child)
		score=totalTime(p,child)
		maxi=argmax(population)
		deleteat!(population,maxi)
		push!(population,Entity(child,score))
	end
	population
end
