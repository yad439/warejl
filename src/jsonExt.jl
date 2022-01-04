include("json.jl")
include("experimentUtils.jl")

function fromJson(::Type{OtherResult}, data)
	resultType = data["type"]
	exactType = Nothing
	if resultType == Integer(HYBRID1_TYPE)
		exactType = HybridExperiment1
	elseif resultType == Integer(HYBRID2_TYPE)
		exactType = HybridExperiment2
	elseif resultType == Integer(HYBRID3_TYPE)
		exactType = HybridExperiment3
	elseif resultType == Integer(HYBRID13_TYPE)
		exactType = HybridExperiment13
	elseif resultType == Integer(HYBRID14_TYPE)
		exactType = HybridExperiment14
	elseif resultType == Integer(HYBRID145_TYPE)
		exactType = HybridExperiment145
	else
		@assert false resultType
	end
	OtherResult(OtherTypes(resultType), fromJson(exactType, data["result"]))
end