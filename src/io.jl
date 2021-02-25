using JSON

toSnakeCase(str)=mapreduce(c->isuppercase(c) ? "_$(lowercase(c))" : "$c",*,collect(str))

function toJson(file,problem)
	d=Dict(map(field->toSnakeCase(string(field))=>getfield(problem,field),fieldnames(typeof(problem))))
	write(file,JSON.json(d))
	nothing
end