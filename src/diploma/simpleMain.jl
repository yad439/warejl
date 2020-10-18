include("simpleLinear.jl")
include("simpleGenetic.jl")
include("simpleLocal.jl")
include("simpleAnnealing.jl")

using Plots
using Printf

n=100
m=5
# p=rand(n)*4 .+1
p=rand(1:10,n)

exactSol=exact(n,m,p)
geneticSol=genetic(n,m,p,16)
localSol=localSearch(n,m,p)
localTabuSol=localTabuSearch(n,m,p)
annealingSol=annealing(n,m,p)
annealingSol2=annealing2(n,m,p)
annealingSol3=annealing3(n,m,p)

@printf("Genetic: %f%%\n",100(geneticSol[2]/exactSol[2])-100)
@printf("Local: %f%%\n",100(localSol[2]/exactSol[2])-100)
@printf("Local tabu: %f%%\n",100(localTabuSol[2]/exactSol[2])-100)
@printf("Annealing 1: %f%%\n",100(annealingSol[2]/exactSol[2])-100)
@printf("Annealing 2: %f%%\n",100(annealingSol2[2]/exactSol[2])-100)
@printf("Annealing 3: %f%%\n",100(annealingSol3[2]/exactSol[2])-100)

plot(geneticSol[3])
plot(localTabuSol[3])
plot(annealingSol[3])
plot(annealingSol2[3])
plot(annealingSol3[3])
