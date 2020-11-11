using Plots

include("common.jl")

struct Schedule
	assignment::Vector{Int}
	times::Vector{Int}
end

@recipe function scheduleToGantt(jobs::Schedule,jobLengths)
	n=length(jobs.assignment)
	@assert length(jobs.times)==n
	@assert length(jobLengths)==n
	shapes=[
		Shape([
			(jobs.times[i],jobs.assignment[i]-1),
			(jobs.times[i],jobs.assignment[i]),
			(jobs.times[i]+jobLengths[i],jobs.assignment[i]),
			(jobs.times[i]+jobLengths[i],jobs.assignment[i]-1)
		])
	for i=1:n]
	#label:=["job $i" for i=1:n]
	shapes
end

function plotGantt(jobs,jobLengths)
	pl=plot()
	for i=1:length(jobLengths)
		plot!(pl,Shape([
			(jobs.times[i],jobs.assignment[i]-1),
			(jobs.times[i],jobs.assignment[i]),
			(jobs.times[i]+jobLengths[i],jobs.assignment[i]),
			(jobs.times[i]+jobLengths[i],jobs.assignment[i]-1)
		]),label=length(jobLengths)>10 ? nothing : "job $i")
	end
	pl
end