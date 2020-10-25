using CSV,DataFrames
using Dates,Statistics

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
	batches=batchInfo.BATCH_ID |> unique |> fmap(i->i=>Batch(i,Order[])) |> Dict
	foreach(eachrow(batchInfo)) do entry
		push!(batches[entry.BATCH_ID].orders,orders[entry.ORDER_ID])
	end
	values(batches)|>collect
end

function parseRealData(directory,instanceSize,instanceNum)
	dir="$directory/$instanceSize/$instanceNum"
	data=["batch_info",
		  "box_info",
		  "box_processing_time",
		  "item_info",
		  "item_processing_time"]|>
		fmap(i->"$dir/$(instanceSize)_$(instanceNum)_$i.csv") |>
		fmap(CSV.File ▷ DataFrame)
	transform!(data[1],:END_ESTIMATED_PACKAGE_DATE=>(it->DateTime.(it,"y-m-d H:M:S"))=>:END_ESTIMATED_PACKAGE_DATE)
	parseRealData(data...)
end

function toModerateJobs(batches)
	orders=map(batch->batch.orders,batches) |> Iterators.flatten
	boxes=map(order->order.boxes,orders) |> Iterators.flatten
	jobLengths=map(box->box.pickingTime+box.packingTime+box.weighingTime,boxes)
	itemIds=map(box->box.items,boxes) |> Iterators.flatten |> fmap(i->i.id) |> unique
	itemMapping=Iterators.enumerate(itemIds) |> fmap(x->(x[2],x[1])) |> Dict
	itemsForJob=[map(x->itemMapping[x.id],box.items) for box ∈ boxes]
	carTravelTime=map(box->box.items,boxes) |> Iterators.flatten |> fmap(i->i.transportTime) |> mean |> x->round(Int,x)
	Int.(jobLengths),itemsForJob,carTravelTime
end

▷(f,g)=g∘f
fmap(f)=x->map(f,x)