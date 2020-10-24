using CSV,DataFrames
using Lazy
using Dates

struct Batch
	id
	orders
end

struct Order
	id
	endDate
	boxes
end

struct Box
	id
	lineType
	pickingTime
	packingTime
	weighingTime
	items
end

struct Item
	id
	transportTime
end

function parseRealData(batchInfo,boxInfo,boxProcessingTime,itemInfo,itemProcessingTime)
	items=map(it->it.ITEM_ID=>Item(it.ITEM_ID,it.WAREHOUSE_TO_PICK_TIME),eachrow(itemProcessingTime)) |> Dict
	boxes=map(innerjoin(boxInfo,boxProcessingTime,on=:BOX_ID)|>eachrow) do box
		box.BOX_ID=>Box(
			box.BOX_ID,
			box.PRODUCTION_LINE_TYPE,
			box.PICKING_TIME,
			box.PACKING_TIME,
			box.WEIGHING_TIME,
			Item[]
		)
	end |>Dict
	@assert length(boxes)==size(boxInfo,1)==size(boxProcessingTime,1)
	foreach(eachrow(itemInfo)) do entry
		push!(boxes[entry.BOX_ID].items,items[entry.ITEM_ID])
	end
	orders=map(eachrow(batchInfo)) do order
		order.ORDER_ID => Order(
			order.ORDER_ID,
			order.END_ESTIMATED_PACKAGE_DATE,
			Box[]
		)
	end|>Dict
	foreach(eachrow(boxInfo)) do entry
		push!(orders[entry.ORDER_ID].boxes,boxes[entry.BOX_ID])
	end
	batches=batchInfo.BATCH_ID |> unique |> (it->map(i->i=>Batch(i,Order[]),it)) |> Dict
	foreach(eachrow(batchInfo)) do entry
		push!(batches[entry.BATCH_ID].orders,orders[entry.ORDER_ID])
	end
	batches
end

function parseRealData(directory,instanceSize,instanceNum)
	dir="$directory/$instanceSize/$instanceNum"
	data=@>> ["batch_info","box_info","box_processing_time","item_info","item_processing_time"] map(x->"$dir/$(instanceSize)_$(instanceNum)_$x.csv") map(CSV.File) map(DataFrame)
	transform!(data[1],:END_ESTIMATED_PACKAGE_DATE=>(it->DateTime.(it,"y-m-d H:M:S"))=>:END_ESTIMATED_PACKAGE_DATE)
	parseRealData(data...)
end