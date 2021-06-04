using CSV,DataFrames
using Statistics

include("realDataUtility.jl")
##
instanceSize = 500
instanceNum = 1
folder = "G:\\test\\benchmark - automatic warehouse\\$instanceSize\\$instanceNum"
boxInfo = CSV.File("$folder\\$(instanceSize)_$(instanceNum)_box_info.csv") |> DataFrame
itemInfo = CSV.File("$folder\\$(instanceSize)_$(instanceNum)_item_info.csv") |> DataFrame

allOrders = boxInfo.ORDER_ID |> unique
allBoxes = boxInfo.BOX_ID |> unique
allItems = itemInfo.ITEM_ID |> unique

boxesInOrder = [boxInfo[boxInfo.ORDER_ID .== order,:BOX_ID] for order ∈ allOrders]
boxesInOrderDict = Dict(zip(allOrders, boxesInOrder))
itemsInBox = [itemInfo[itemInfo.BOX_ID .== box,:ITEM_ID] for box ∈ allBoxes]
itemsInBoxDict = Dict(zip(allBoxes, itemsInBox))
itemsInOrder = map(boxesInOrder) do order
	[itemsInBoxDict[box] for box ∈ order] |> Iterators.flatten |> collect
end
println("boxes in order")
println(length.(boxesInOrder) |> minimum)
println(length.(boxesInOrder) |> maximum)
println(length.(boxesInOrder) |> mean)

println("items in box")
println(length.(itemsInBox) |> minimum)
println(length.(itemsInBox) |> maximum)
println(length.(itemsInBox) |> mean)

println("items in order")
println(length.(itemsInOrder) |> minimum)
println(length.(itemsInOrder) |> maximum)
println(length.(itemsInOrder) |> mean)

boxCountInOrder = [count(it -> it ∋ box, boxesInOrder) for box ∈ allBoxes]
itemCountInBox = [count(it -> it ∋ item, itemsInBox) for item ∈ allItems]
itemCountInOrder = [count(it -> it ∋ item, itemsInOrder) for item ∈ allItems]

println("orders for box")
println(minimum(boxCountInOrder))
println(maximum(boxCountInOrder))
println(mean(boxCountInOrder))

println("boxes for item")
println(minimum(itemCountInBox))
println(maximum(itemCountInBox))
println(mean(itemCountInBox))

println("orders for item")
println(minimum(itemCountInOrder))
println(maximum(itemCountInOrder))
println(mean(itemCountInOrder))
##
MInt = Union{Missing,Int}
MFloat = Union{Missing,Float64}
df = DataFrame(problemSize=Int[], problemNum=Int[], lineType=String[], jobCount=Int[], minLen=MInt[], maxLen=MInt[], meanLen=MFloat[], minItems=MInt[], maxItems=MInt[], meanItems=MFloat[])
for batchSize ∈ [20,50,100,200,500],batchNum in 1:10
	try
		batches = parseRealData("res/benchmark - automatic warehouse", batchSize, batchNum)
		orders = map(batch -> batch.orders, batches) |> Iterators.flatten
		boxes = map(order -> order.boxes, orders) |> Iterators.flatten |> collect
		@assert all(box -> box.lineType ∈ ["A","B","E","T"], boxes)
		for lineType ∈ ["A","B","E","T"]
			fboxes = filter(box -> box.lineType == lineType, boxes)
			jobLengths = map(box -> box.packingTime, fboxes)
			items = map(box -> length(box.items), fboxes)
			isempty(jobLengths) && (jobLengths = [missing])
			isempty(items) && (items = [missing])
			push!(df, (batchSize, batchNum, lineType, length(fboxes), minimum(jobLengths), maximum(jobLengths), mean(jobLengths), minimum(items), maximum(items), mean(items)))
		end
	catch e
		println(stderr, "Problem $batchSize/$batchNum is invalid: $e")
	end
end