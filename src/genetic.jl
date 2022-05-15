using LinearAlgebra

struct DeSettings
    iterationLimit::Int
    moveCoefficient::Float64
end

struct Encoding
    data::Vector{Float64}
    score::Int
end

function differentialEvolution(settings, scoreFunction, startingPopulation, selector, crosser, replacer)
    population = [Encoding(normalize(sol), scoreFunction(sol)) for sol ∈ startingPopulation]
    for t = 1:settings.iterationLimit
        target = rand(1:length(population))
        candadate = normalize(selector(target, population, settings.moveCoefficient))
        crosser(candadate, target, population)
        newSol = Encoding(candadate, scoreFunction(candadate))
        replacer(newSol, target, population)
    end
    minimum(sol.score for sol ∈ population)
end

function allRandomSelector(target, population, moveCoefficient)
    set = BitSet(1:length(population))
    delete!(set, target)
    mutator = rand(set)
    delete!(set, mutator)
    solution₁ = rand(set)
    delete!(set, solution₁)
    solution₂ = rand(set)

    population[mutator].data + moveCoefficient * (population[solution₁].data - population[solution₂].data)
end

function randomToBestSelector(target, population, moveCoefficient)
    set = BitSet(1:length(population))
    delete!(set, target)
    best = argargmin(e -> e.score, population)
    delete!(set, best)
    mutator = rand(set)
    delete!(set, mutator)
    solution₂ = rand(set)

    population[mutator].data + moveCoefficient * (population[best].data - population[solution₂].data)
end

function uniformCrosover(candadate, target, population)
    for i ∈ eachindex(candadate)
        if rand() < 0.5
            candadate[i] = population[target].data[i]
        end
    end
end

function improveReplacer(candidate, target, population)
    if candidate.score ≤ population[target].score
        population[target] = candidate
    end
end

worstImproveReplacer(candidate, _, population)=improveReplacer(candidate,argargmax(e->e.score,population),population)

function worstReplacer(candidate, _, population)
    population[argargmax(e->e.score,population)]=candidate
    nothing
end