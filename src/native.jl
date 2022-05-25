include("problemStructures.jl")

mutable struct NativeInstance
	ptr::Ptr{Cvoid}

	function NativeInstance(instance::Problem)
		itemCounts=map(Cint∘length,instance.itemsNeeded)
		itemsNeeded=[[trunc(Cint,it-1) for it ∈ job] for job ∈ instance.itemsNeeded]
		new(ccall((:allocateProblem,"warehousing"),cdecl,Ptr{Cvoid},(Cint,Cint,Cint,Cint,Cint,Cint,Ref{Cint},Ref{Cint},Ref{Ptr{Cint}}),))
	end
 end