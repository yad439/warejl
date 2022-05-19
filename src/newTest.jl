include("genetic.jl");
include("dataUtility.jl");
include("utility.jl");
include("scoreFunctions.jl");
##
include("annealing.jl");
##
const WARE_DATA = ENV["WARE_DATA"]
##
instance = parseInstance("$WARE_DATA/data/instances/26.dat");
##
population = [rand(instance.jobCount) for _ = 1:96];
settings = DeSettings(2_000_000, 0.3, 0.5, true);
result = differentialEvolution(settings,
    s -> computeTimeLazyReturn(sortperm(s), instance),
    population,
    randomToBestSelector,
    uniformCrosover,
    (c, t, po, pr) -> annealingReplacer(c, t, po, pr, (start=1000, endC=1e-5)))
##
enc = PermutationEncoding(shuffle(1:instance.jobCount));
sett = AnnealingSettings(1_000_000, 2, false, 1, 1000, FuncR{Float64}(t -> t * (-1000 * log(10^-3))^(-1 / 2_000_000)), FuncR{Bool}((old, new, threshold) -> rand() < exp((old - new) / threshold)));
res2, _ = modularAnnealing(sett, p -> computeTimeLazyReturn(p.permutation, instance), enc)
##
df=DataFrame(iterCount=Int[],nsize=Int[],score=Int[]);
lk=ReentrantLock();
for iterCount ∈ [1_024, 16_384, 131_072, 1_048_576], nsize ∈ [1, 2, 4, 8]
    @show iterCount nsize
    sett = AnnealingSettings(iterCount ÷ nsize, nsize, false, 1, 1000, FuncR{Float64}(t -> t * (-1000 * log(10^-3))^(-1 / (iterCount ÷ nsize))), FuncR{Bool}((old, new, threshold) -> rand() < exp((old - new) / threshold)))
    Threads.@threads for _ = 1:1
        enc = PermutationEncoding(shuffle(1:instance.jobCount))
        result, _ = modularAnnealing(sett, p -> computeTimeLazyReturn(p.permutation, instance), enc)
        lock(lk) do
            push!(df,(iterCount,nsize,result))
        end
    end
end