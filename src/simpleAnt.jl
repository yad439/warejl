include("simpleAuxiliary.jl")

# using Distributions

function antColony(n,m,p)
	paths=fill(0.0,m,n)
	path=Vector{Int}(undef,n)
	minval=Inf
	minsol=Vector{Int}(undef,n)
	count=0
	while count<10000
		for i=1:n
			s=sum(paths[:,i])+m
			# dst=Categorical([(paths[j,i]+1)/s for j=1:m])
			dst=nothing
			k=rand(dst)
			path[i]=k
		end
		t=maxTime(path,p,m)
		for (i,j) ∈ enumerate(path)
			paths[j,i]+=3/t
		end
		paths*=0.9
		if t<minval
			minval=t
			copy!(minsol,path)
			p
		end
		count+=1
	end
	minsol,minval,paths
end
