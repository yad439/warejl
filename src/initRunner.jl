include("jsonExt.jl")
include("simpleHeuristic.jl")

import JSON

function addWorkers(procs, threads)
	started = addprocs(procs, exeflags = ["-O3", "--min-optlevel=3", "-t$threads", "-g0", "--math-mode=fast", "--project"])
	@everywhere started begin
		include("hybridTabu.jl")
		include("scoreFunctions.jl")
		include("randomUtils.jl")
	end
end

const resFile = "exp/results.json"

# const probSize = 20
# const probNum = 1
# const machineCount = 4
# const carCount = 40
# const bufferSize = 8

const results = fromJson(Vector{ProblemInstance}, JSON.parsefile(resFile))
const experiments = [3, 13, 6, 7, 9, 16, 17, 19, 5, 15, 4, 14, 48, 49, 8, 18, 2, 12, 1, 11, 25, 22, 26, 23, 27, 21, 47, 24, 20, 45, 46, 33, 39, 38, 32, 37, 31, 30, 43, 44];