using ProgressMeter
import Base.isless,Base.isequal

include("$(@__DIR__)/common.jl")

struct GeneticSettings
	searchTries::Int
	choiceCount::Int
	crossover::Function
	mutation!::Function
end

function modularGenetic(jobCount,machineCount,settings,scoreFunction,startPopulation)
	progress=ProgressUnknown("Genetic:")
	history=Vector{eltype(p)}(undef,0)

	population=startPopulation
	count=0

	push!(history,population[1].score)
	while count<settings.searchTries
		parent1=randchoice(population,settings.choiceCount) |> minimum
		parent2=randchoice(population,settings.choiceCount) |> minimum

		child=settings.crossover(parent1.jobs,parent2.jobs)
		settings.mutation!(child)

		score=scoreFunction(child)
		if score≥population[1].score
			count+=1
		else
			count=0
		end
		pop!(population)
		insertSorted!(population,GeneticEntity(child,score))

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
isequal(ent1::GeneticEntity,ent2::GeneticEntity)=ent1.score==ent2.score

function pmxCrossover(list1,list2)
	n=length(list1)
	@assert length(list2)==n
	startIndex,endIndex=minmax(rand(1:n+1),rand(1:n+1))
	endIndex-=1
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
