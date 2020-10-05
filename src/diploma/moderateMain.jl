include("$(@__DIR__)/moderateLinear.jl")
include("$(@__DIR__)/modularLocal.jl")
include("$(@__DIR__)/auxiliary.jl.jl")

using Plots
using Printf
using Statistics

n=5
m=2
p=rand(5:20,n)
k=rand(1:2,n)
tt=20
c=4

exactRes=moderateExact(n,m,c,p,k,tt)
localRes1=modularTabuSearch(n,m,TabuSearchSettings(100,10,10),jobs->maxTimeWithCarsUnoptimized(jobs,p,k,m,c,tt),randomTwoVectorEncoding(n,m))
localRes2=modularTabuSearch(n,m,TabuSearchSettings(100,10,10),jobs->maxTimeWithCarsUnoptimized(jobs,p,k,m,c,tt),randomPermutationEncoding(n))
