using Random

jobDistance(itemsNeeded) = map(((i, j),) -> length(symdiff(i, j)), Iterators.product(itemsNeeded, itemsNeeded))

function randchoice(list, count)
	notChosen = BitSet(1:length(list))
	res = Vector{eltype(list)}(undef, count)
	for i = 1:count
		val = rand(notChosen)
		res[i] = list[val]
		delete!(notChosen, val)
	end
	res
end

function tmap(f, x)
	type = Base.return_types(f, (eltype(x),))
	@assert length(type) == 1
	result = similar(x, first(type))
	Threads.@threads for i ∈ eachindex(x)
		result[i] = f(x[i])
	end
	result
end

▷(f, g) = g ∘ f
fmap(f) = x -> map(f, x)
ffilter(f) = x -> filter(f, x)
ifmap(f) = x -> Iterators.map(f, x)
iffilter(f) = x -> Iterators.filter(f, x)
secondElement(x) = x[2]
unzip(a) = map(x -> getfield.(a, x), fieldnames(eltype(a)))

for n = 0:5
	structName = Expr(:curly, Symbol(:Func, n), :R, (Symbol(:A, i) for i = 1:n)...)
	structDef = quote
		struct $structName
			f::Function
		end
	end
	invokeSign = Expr(:call, :(func::$structName), (:($(Symbol(:x, i))::$(Symbol(:A, i))) for i = 1:n)...)
	fCall = Expr(:call, :(func.f), (Symbol(:x, i) for i = 1:n)...)
	fBody = Expr(:block, :($fCall::R))
	whereDef = Expr(:where, invokeSign, :R, (Symbol(:A, i) for i = 1:n)...)
	invokeDef = :($whereDef = $fBody)
	inlined = :(@inline $invokeDef)

	eval(structDef)
	eval(inlined)
end