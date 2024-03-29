using LinearAlgebra

struct DeSettings
    iterationLimit::Int
    moveCoefficient::Float64
    crossoverIntensity::Float64
    normalize::Bool
end

struct GeneticSettings
    iterationLimit::Int
end

struct GeneticSettings2
    iterationLimit::Int
    generationSize::Int
end

struct DeEncoding
    data::Vector{Float64}
    score::Int
end

struct PermEncoding
    solution::Vector{Int}
    score::Int
end

function differentialEvolution(settings::DeSettings, scoreFunction, startingPopulation, selector, crossover, replacer)
    if settings.normalize
        foreach(normalize!, startingPopulation)
    end
    population = [DeEncoding(sol, scoreFunction(sol)) for sol ∈ startingPopulation]
    for t = 1:settings.iterationLimit
        target = rand(1:length(population))
        candidate = selector(target, population, settings.moveCoefficient)
        crossover(candidate, target, population, settings.crossoverIntensity)
        if settings.normalize
            normalize!(candidate)
        end
        newSol = DeEncoding(candidate, scoreFunction(candidate))
        replacer(newSol, target, population, t / settings.iterationLimit)
    end
    minimum(sol.score for sol ∈ population)
end

function stationaryGenetic(settings, scoreFunction, selector, crossover, mutator, replacer, population)
    for t = 1:settings.iterationLimit
        s₁, s₂ = selector(population, t / settings.iterationLimit)
        newSol = crossover(s₁, s₂)
        mutator(newSol)
        sₙ = PermEncoding(newSol, scoreFunction(newSol))
        replacer(population, s₁, s₂, sₙ)
    end
    minimum(sol.score for sol ∈ population)
end

function genrationalGenetic(settings, scoreFunction, selector, crossover, mutator, truncator, population)
    candidates = Vector{eltype(population)}(undef, settings.generationSize)
    for t = 1:settings.iterationLimit
        for (i, (s₁, s₂)) ∈ enumerate(selector(population, length(candidates), t / settings.iterationLimit))
            newSol = crossover(s₁, s₂)
            mutator(newSol)
            candidates[i] = PermEncoding(newSol, scoreFunction(newSol))
        end
        for (i, s) ∈ enumerate(truncator(population, candidates, t / settings.iterationLimit))
            population[i] = s
        end
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

function uniformCrosover(candadate, target, population, crossoverIntensity)
    for i ∈ eachindex(candadate)
        if rand() < (1 - crossoverIntensity)
            candadate[i] = population[target].data[i]
        end
    end
end

function improveReplacer(candidate, target, population, _)
    if candidate.score ≤ population[target].score
        population[target] = candidate
    end
end

worstImproveReplacer(candidate, _, population, p) = improveReplacer(candidate, argargmax(e -> e.score, population), population, p)

function worstReplacer(candidate, _, population, _)
    population[argargmax(e -> e.score, population)] = candidate
    nothing
end

function annealingReplacer(candidate, target, population, progress, opts)
    if rand() < exp((population[target].score - candidate.score) / (opts.start * (opts.endC^progress)))
        population[target] = candidate
    end
end

function tournamentSelectorHelper(population, num)
    cands = randchoice(population, num)
    argmin(s -> s.score, cands)
end

function worstReplacer2(population, _, _, sol)
    population[argargmax(e -> e.score, population)] = sol
    nothing
end

extremeSelectorHelper(population, _, best) = best ? argmin(s -> s.score, population) : argmax(s -> s.score, population)

batchSelectorAdaptor(selector, population, generationSize, progress) = (selector(population, progress) for _ = 1:generationSize)

function bestTruncator(population, generationSize, _)
    sorted = sort(population, by=s -> s.score)
    view(sorted, 1:generationSize)
end

function truncatorExtAdapter(truncator, population, candidates, usePrevious, useBest, progress)
    if usePrevious
        wholePop = [population; candidates]
        if useBest
            best = argmin(s -> s.score, wholePop)
            rest = truncator(wholePop, length(population) - 1, progress)
            return push!(collect(rest), best)
        else
            return truncator(wholePop, length(population), progress)
        end
    else
        if useBest
            best = argmin(s -> s.score, population)
            rest = truncator(candidates, length(population) - 1, progress)
            return push!(collect(rest), best)
        else
            return truncator(candidates, length(population), progress)
        end
    end
end