include("problemStructures.jl")

mutable struct NativeInstance
    ptr::Ptr{Cvoid}

    function NativeInstance(instance::Problem)::NativeInstance
        jobLengths = map(Cint, instance.jobLengths)
        itemCounts = map(Cint ∘ length, instance.itemsNeeded)
        itemsNeeded = [[trunc(Cint, it - 1) for it ∈ job] for job ∈ instance.itemsNeeded]
        res = new(ccall((:allocateProblem, "warehousing"), cdecl, Ptr{Cvoid},
            (Cint, Cint, Cint, Cint, Cint, Cint, Ref{Cint}, Ref{Cint}, Ref{Ptr{Cint}}),
            instance.jobCount, instance.machineCount, instance.robotCount, instance.bufferSize, instance.itemCount, instance.travelTime,
            jobLengths, itemCounts, itemsNeeded))
        finalizer(res) do x
            ccall((:deleteProblem, "warehousing"), cdecl, Cvoid, (Ptr{Cvoid},), x.ptr)
        end
        res
    end
end

computeScoreNative(instance::NativeInstance, permutation)::Cint = ccall((:computeScore, "warehousing"), cdecl, Cint, (Ptr{Cvoid}, Ref{Cint}), instance.ptr, [trunc(Cint, it - 1) for it ∈ permutation])