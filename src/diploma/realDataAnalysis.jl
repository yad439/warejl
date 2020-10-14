using CSV,DataFrames
using Statistics

instanceSize=500
instanceNum=1
folder="G:\\test\\benchmark - automatic warehouse\\$instanceSize\\$instanceNum"
boxInfo=CSV.File("$folder\\$(instanceSize)_$(instanceNum)_box_info.csv")|>DataFrame
itemInfo=CSV.File("$folder\\$(instanceSize)_$(instanceNum)_item_info.csv")|>DataFrame

allOrders=boxInfo.ORDER_ID |> unique
allBoxes=boxInfo.BOX_ID |> unique
allItems=itemInfo.ITEM_ID |> unique

boxesInOrder=[boxInfo[boxInfo.ORDER_ID.==order,:BOX_ID] for order ∈ allOrders]
boxesInOrderDict=Dict(zip(allOrders,boxesInOrder))
itemsInBox=[itemInfo[itemInfo.BOX_ID.==box,:ITEM_ID] for box ∈ allBoxes]
itemsInBoxDict=Dict(zip(allBoxes,itemsInBox))
itemsInOrder=map(boxesInOrder) do order
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

boxCountInOrder=[count(it->it∋box,boxesInOrder) for box ∈ allBoxes]
itemCountInBox=[count(it->it∋item,itemsInBox) for item ∈ allItems]
itemCountInOrder=[count(it->it∋item,itemsInOrder) for item ∈ allItems]

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
