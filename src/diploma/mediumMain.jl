include("$(@__DIR__)/simpleLinear.jl")
include("$(@__DIR__)/mediumLocal.jl")

using Plots
using Printf
using Statistics

n=100
m=5
# p=rand(n)*1000
# p=rand(n)*4 .+1
p=rand(1:100,n)

exactSol=exact(n,m,p)
localRes1=localTabu2(n,m,p,0,1000)
localRes2=localTabu3(n,m,p,10,1000)

@printf("Local tabu (permutation): %f%%\n",100(localRes1[2]/exactSol[2])-100)
@printf("Local tabu (double): %f%%\n",100(localRes2[2]/exactSol[2])-100)

plot(localRes1[3])
plot(localRes2[3])

rep=map(1:10) do _
	pl=rand(1:100,n)
	exactSoll=exact(n,m,pl)
	localRes1l=localTabu2(n,m,pl,100,1000)
	100(localRes1l[2]/exactSoll[2])-100
end
