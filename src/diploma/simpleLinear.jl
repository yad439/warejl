using JuMP,Gurobi,LinearAlgebra

function exact(n,m,p)
	model=Model(Gurobi.Optimizer)
	@variable(model,x[1:m,1:n],Bin)
	@constraint(model,[i=1:n],sum(x[:,i])==1)
	@variable(model,res)
	@constraint(model,[i=1:m],res≥p⋅x[i,:])
	@objective(model,Min,res)

	set_optimizer_attribute(model,"TimeLimit",120)
	optimize!(model)

	[round(Int,(1:m)⋅value.(x[:,i])) for i=1:n],objective_value(model)
end
