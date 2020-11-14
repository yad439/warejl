include("mainAuxiliary.jl");
include("moderateAuxiliary.jl");
include("utility.jl");
##
n=10
m=3
p=rand(5:20,n)
itemCount=10
itemsNeeded=[randsubseq(1:itemCount,0.2) for _=1:n]
tt=10
c=4
k=length.(itemsNeeded)
##
sf1(jobs)=maxTimeWithCars(jobs,p,k,m,c,tt)
sf2(jobs)=computeTimeGetOnly(jobs,m,p,itemsNeeded,c,tt)[2]
##
st=rand(EncodingSample{PermutationEncoding}(n,m))
##
sol1=computeTimeWithCars(st,p,k,m,c,tt)
sol2=computeTimeGetOnly(st,m,p,itemsNeeded,c,tt)