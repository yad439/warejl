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

function plotGantt(jobs,jobLengths,useLabel=length(jobLengths)≤10,text=nothing)
	pl=plot(xlims=(0,:auto))
	for i=1:length(jobLengths)
		x1=jobs.times[i]
		x2=jobs.times[i]+jobLengths[i]
		y1=jobs.assignment[i]-1
		y2=jobs.assignment[i]
		plot!(pl,Shape([
			(x1,y1),
			(x1,y2),
			(x2,y2),
			(x2,y1)
		]),label=(useLabel ? "job $i" : nothing),annotations=(text≢nothing ? ((x1+x2)/2,(y1+y2)/2,text[i]) : nothing))
	end
	pl
end

function plotCarUsage(carHistory,carTravelTime,xlims=:auto)
	endings=map(it->(it[1]+carTravelTime,-it[2]),carHistory)
	allEvents=vcat(carHistory,endings)
	sort!(allEvents,by=first)
	fixedHistory=[(zero(carHistory[1][1]),0)]
	curTime=fixedHistory[1][1]
	for event ∈ allEvents
		if event[1]==curTime
			fixedHistory[end]=(curTime,fixedHistory[end][2]+event[2])
		else
			curTime=event[1]
			push!(fixedHistory,event)
		end
	end
	carsInUse=0
	line=[(0,0)]
	for event ∈ fixedHistory
		push!(line,(event[1],carsInUse))
		carsInUse+=event[2]
		push!(line,(event[1],carsInUse))
	end
	plot(line,label=false,xlims=xlims)
end

scheduleToEncoding(::Type{PermutationEncoding},schedule)=schedule.times|>sortperm|>PermutationEncoding