include("genetic.jl");
include("dataUtility.jl");
include("utility.jl");
include("scoreFunctions.jl");

using Sockets
using JSON3

const WARE_DATA = ENV["WARE_DATA"]

function serve(client, instance)
    try
        sz = ntoh(read(client, Int16))
        request = JSON3.read(String(read(client, sz)))
        population = [rand(instance.jobCount) for _ = 1:64]
        settings = DeSettings(2_000_000, request.moveCoef, request.crossInt, request.normalize)
        result = differentialEvolution(settings, s -> computeTimeLazyReturn(sortperm(s), instance), population, randomToBestSelector, uniformCrosover, improveReplacer)
        println(client, result)
    catch e
        println(stderr, e)
    finally
        close(client)
    end
end

let
    instance = parseInstance("$WARE_DATA/data/instances/26.dat")
    server = listen(7681)
    try
        while true
            client = accept(server)
            Threads.@spawn serve($client, $instance)
        end
    catch e
        println(stderr, e)
    finally
        close(server)
    end
end