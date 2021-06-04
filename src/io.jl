using JSON

toSnakeCase(str) = mapreduce(c -> isuppercase(c) ? "_$(lowercase(c))" : "$c", *, collect(str))

function toJson(file, problem)
	d = Dict(map(field -> toSnakeCase(string(field)) => getfield(problem, field), fieldnames(typeof(problem))))
	d["items_needed"] = map(d["items_needed"]) do items
		map(x -> x - 1, collect(items))
	end
	write(file, JSON.json(d))
	nothing
end