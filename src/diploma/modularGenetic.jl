using ProgressMeter
import Base.isless,Base.isequal,Base.==

include("common.jl")
include("utility.jl")

struct GeneticSettings
	searchTries::Int
	choiceCount::Int
	crossover::Function
	mutation!::Function
end

function modularGenetic(jobCount,machineCount,settings,scoreFunction,startPopulation)
	progress=ProgressUnknown("Genetic:")

	population=startPopulation
	counter=0

	history=Vector{typeof(population[1].score)}(undef,0)
	push!(history,population[1].score)
	while counter<settings.searchTries
		parent1=randchoice(population,settings.choiceCount) |> minimum
		parent2=randchoice(population,settings.choiceCount) |> minimum

		child=settings.crossover(parent1.jobs,parent2.jobs)
		settings.mutation!(child)

		score=scoreFunction(child)
		if score≥population[1].score
			counter+=1
		else
			counter=0
		end
		if child ∉ population
			pop!(population)
			insertSorted!(population,GeneticEntity(child,score))
		end

		push!(history,score)
		ProgressMeter.next!(progress,showvalues=[("Min score",population[1].score)])
	end
	ProgressMeter.finish!(progress)
	population[1].score,population[1].jobs,history
end

struct GeneticEntity{T}
	jobs::T
	score::Int
end
isless(ent1::GeneticEntity,ent2::GeneticEntity)=ent1.score<ent2.score
# isequal(ent1::GeneticEntity,ent2::GeneticEntity)=ent1.score==ent2.score
==(ent1::GeneticEntity,ent2::GeneticEntity)=ent1.jobs==ent2.jobs

function pmxCrossover(list1,list2)
	n=length(list1)
	@assert length(list2)==n
	startIndex,endIndex=minmax(rand(1:n+1),rand(1:n+1))
	endIndex-=1
	pmxCrossover(list1,list2,startIndex,endIndex)
end

function pmxCrossover(list1,list2,startIndex,endIndex)
	n=length(list1)
	@assert length(list2)==n

	child=similar(list1)

	child[startIndex:endIndex]=list1[startIndex:endIndex]
	copied=BitVector(undef,n)
	fill!(copied,false)
	for i=startIndex:endIndex
		copied[list1[i]]=true
	end
	for i=startIndex:endIndex
		val=list2[i]
		copied[val] && continue
		index=i
		cont=true
		while cont
			val2=list1[index]
			index2=findfirst(==(val2),list2)
			if index2 ∈ startIndex:endIndex
				val=val2
				index=index2
				continue
			end
			child[index2]=list2[i]
			copied[list2[i]]=true
			cont=false
		end
	end
	for i=1:n
		copied[list2[i]] || (child[i]=list2[i])
	end
	@assert all(∈(child),1:n)
	child
end

function order1Crossover(list1,list2)
	n=length(list1)
	@assert length(list2)==n
	startIndex,endIndex=minmax(rand(1:n+1),rand(1:n+1))
	endIndex-=1
	order1Crossover(list1,list2,startIndex,endIndex)
end

function order1Crossover(list1,list2,startIndex,endIndex)
	n=length(list1)
	@assert length(list2)==n

	child=similar(list1)

	child[startIndex:endIndex]=list1[startIndex:endIndex]
	copied=fill!(BitVector(undef,n),false)
	copied[list1[startIndex:endIndex]].=true
	ind=startIndex≠1 ? 1 : endIndex+1
	for i=1:n
		copied[list2[i]] && continue
		child[ind]=list2[i]
		ind+=1
		ind==startIndex && (ind=endIndex+1)
	end
	@assert all(∈(child),1:n)
	child
end

function cycleCrossover(list1,list2)
	n=length(list1)
	@assert length(list2)==n

	child=similar(list1)
	copied=BitVector(undef,n)
	copied.=false
	takeFirst=true
	for i=1:n
		copied[i] && continue
		child[i]=takeFirst ? list1[i] : list2[i]
		copied[i]=true
		ind=findfirst(==(list2[i]),list1)
		while ind≠i
			@assert !copied[ind]
			child[ind]=takeFirst ? list1[ind] : list2[ind]
			copied[ind]=true
		end
		takeFirst=!takeFirst
	end
	@assert all(copied)
	@assert all(∈(child),1:n)
	child
end

function elementviseCrossover(list1,list2)
	child=similar(list1)
	for i ∈ eachindex(list1)
		if rand()>0.5
			child[i]=list1[i]
		else
			child[i]=list2[i]
		end
	end
	child
end

function insertSorted!(list,value)
	pos=searchsortedlast(list,value)
	insert!(list,pos+1,value)
end