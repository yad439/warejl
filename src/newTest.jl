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
population = [rand(instance.jobCount) for _ = 1:64];
settings = DeSettings(2_000_000, 0.3, 0.5, true);
result = differentialEvolution(settings, s -> computeTimeLazyReturn(sortperm(s), instance), population, randomToBestSelector, uniformCrosover, worstReplacer)
println(result)
##
enc = PermutationEncoding(shuffle(1:instance.jobCount));
sett = AnnealingSettings(2_000_000, false, 1, 1000, FuncR{Float64}(t -> t * (-1000 * log(10^-3))^(-1 / 2_000_000)), FuncR{Bool}((old, new, threshold) -> rand() < exp((old - new) / threshold)));
res2, _ = modularAnnealing(sett, p -> computeTimeLazyReturn(p.permutation, instance), enc)