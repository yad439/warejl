function fromJson(T, data)
	@assert isstructtype(T)
	fields = fieldnames(T)
	types = fieldtypes(T)
	arguments = broadcast((field, type) -> fromJson(type, data[string(field)]), fields, types)
	T(arguments...)
end
function fromJson(::Type{T}, data) where {T<:NamedTuple}
	fields = fieldnames(T)
	types = fieldtypes(T)
	arguments = broadcast((field, type) -> fromJson(type, data[string(field)]), fields, types)
	T(arguments)
end
fromJson(::Type{Union{T,Nothing}}, data) where {T} = data ≡ nothing ? nothing : fromJson(T, data)
fromJson(::Type{Union{T,Missing}}, data) where {T} = data ≡ nothing ? missing : fromJson(T, data)
fromJson(::Type{Vector{T}}, data) where {T} = map(it -> fromJson(T, it), data)
fromJson(::Type{Set{T}}, data) where {T} = Set(Iterators.map(it -> fromJson(T, it), data))
fromJson(::Type{T}, data) where {T<:Number} = convert(T, data)
fromJson(::Type{String}, data) = data
fromJson(::Type{Char}, data) = (@assert(length(data) == 1); data[1])
fromJsom(type::Type{Enum{T}}, data) where {T} = type(data)

toJson(output::IO, object) = toJson(output, object, 0)
function toJson(output::IO, object, indent::Int)
	@assert isstructtype(typeof(object))
	print(output, "{\n")
	fields = fieldnames(typeof(object))
	firstField, rest = Iterators.peel(fields)
	print(output, repeat('\t', indent + 1), '"', string(firstField), "\": ")
	toJson(output, getfield(object, firstField), indent + 1)
	for field ∈ rest
		print(output, ",\n")
		print(output, repeat('\t', indent + 1), '"', string(field), "\": ")
		value = getfield(object, field)
		toJson(output, value, indent + 1)
	end
	print(output, '\n', repeat('\t', indent), '}')
	nothing
end
function toJson(output::IO, object::NamedTuple, indent::Int)
	print(output, "{\n")
	fields = fieldnames(typeof(object))
	firstField, rest = Iterators.peel(fields)
	print(output, repeat('\t', indent + 1), '"', string(firstField), "\": ")
	toJson(output, getfield(object, firstField), indent + 1)
	for field ∈ rest
		print(output, ",\n")
		print(output, repeat('\t', indent + 1), '"', string(field), "\": ")
		value = getfield(object, field)
		toJson(output, value, indent + 1)
	end
	print(output, '\n', repeat('\t', indent), '}')
	nothing
end

toJson(output::IO, object::AbstractVector, indent::Int) = toJsonCollection(output, object, indent)
toJson(output::IO, object::Vector{T}, indent::Int) where {T<:Number} = toJsonCollectionCompact(output, object, indent)
toJson(output::IO, object::Vector{T}, indent::Int) where {T<:AbstractString} = toJsonCollectionCompact(output, object, indent)
toJson(output::IO, object::AbstractSet, indent::Int) = toJsonCollection(output, object, indent)
toJson(output::IO, object::Set{T}, indent::Int) where {T<:AbstractChar} = toJsonCollectionCompact(output, object, indent)
toJson(output::IO, object::Set{T}, indent::Int) where {T<:AbstractString} = toJsonCollectionCompact(output, object, indent)

toJson(output::IO, object::AbstractString, ::Int) = (print(output, '"', object, '"'); nothing)
toJson(output::IO, object::AbstractChar, ::Int) = (print(output, '"', object, '"'); nothing)
toJson(output::IO, object::Number, ::Int) = (print(output, object); nothing)
toJson(output::IO, ::Missing, ::Int) = (print(output, "null"); nothing)
toJson(output::IO, ::Nothing, ::Int) = (print(output, "null"); nothing)

toJson(output::IO, object::Enum{T}, ::Int) where {T} = (print(output, Integer(object)); nothing)

function toJsonCollection(output::IO, object, indent::Int)
	if !isempty(object)
		print(output, "[\n", repeat('\t', indent + 1))
		first, rest = Iterators.peel(object)
		toJson(output, first, indent + 1)
		for elem ∈ rest
			print(output, ",\n", repeat('\t', indent + 1))
			toJson(output, elem, indent + 1)
		end
		print(output, '\n', repeat('\t', indent), ']')
	else
		print(output, "[]")
	end
	nothing
end
function toJsonCollectionCompact(output::IO, object, indent::Int)
	if !isempty(object)
		print(output, "[ ")
		first, rest = Iterators.peel(object)
		toJson(output, first, indent + 1)
		for elem ∈ rest
			print(output, ", ")
			toJson(output, elem, indent + 1)
		end
		print(output, " ]")
	else
		print(output, "[]")
	end
	nothing
end