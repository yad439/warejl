using CSV, DataFrames
using Statistics

include("problemStructures.jl")

struct Item
    id::String
    transportTime::Int
end

struct Box
    id::Int
    lineType::String
    pickingTime::Float64
    packingTime::Float64
    weighingTime::Float64
    items::Vector{Item}
end

struct Order
    id::Int
    endDate::String
    boxes::Vector{Box}
end

struct Batch
    id::String
    orders::Vector{Order}
end

function parseRealData(batchInfo, boxInfo, boxProcessingTime, itemInfo, itemProcessingTime)
    items = Dict(it.ITEM_ID => Item(it.ITEM_ID, it.WAREHOUSE_TO_PICK_TIME) for it ∈ eachrow(itemProcessingTime))
    boxes = Iterators.map(eachrow(innerjoin(boxInfo, boxProcessingTime, on=:BOX_ID))) do box
        box.BOX_ID => Box(
            box.BOX_ID,
            box.PRODUCTION_LINE_TYPE,
            box.PICKING_TIME,
            box.PACKING_TIME,
            box.WEIGHING_TIME,
            Item[]
        )
    end |> Dict
    @assert length(boxes) == size(boxInfo, 1) == size(boxProcessingTime, 1)
    for entry ∈ eachrow(itemInfo)
        push!(boxes[entry.BOX_ID].items, items[entry.ITEM_ID])
    end
    orders = Iterators.map(eachrow(batchInfo)) do order
        order.ORDER_ID => Order(
            order.ORDER_ID,
            order.END_ESTIMATED_PACKAGE_DATE,
            Box[]
        )
    end |> Dict
    for entry ∈ eachrow(boxInfo)
        push!(orders[entry.ORDER_ID].boxes, boxes[entry.BOX_ID])
    end
    batches = batchInfo.BATCH_ID |> unique |> ifmap(i -> i => Batch(i, Order[])) |> Dict
    for entry ∈ eachrow(batchInfo)
        push!(batches[entry.BATCH_ID].orders, orders[entry.ORDER_ID])
    end
    collect(values(batches))
end

function parseRealData(directory, instanceSize, instanceNum)
    dir = "$directory/$instanceSize/$instanceNum"
    data = ["batch_info",
               "box_info",
               "box_processing_time",
               "item_info",
               "item_processing_time"] |>
           ifmap(i -> "$dir/$(instanceSize)_$(instanceNum)_$i.csv") |>
           ifmap(CSV.File ▷ DataFrame)
    parseRealData(data...)
end

function toModerateJobs(batches, boxFilter=_ -> true, boxLimit=typemax(Int))
    orders = Iterators.map(batch -> batch.orders, batches) |> Iterators.flatten
    boxes = Iterators.map(order -> order.boxes, orders) |> Iterators.flatten |> iffilter(boxFilter) |> Base.Fix2(Iterators.take, boxLimit) |> collect
    jobLengths = map(box -> Int(box.packingTime), boxes)
    itemIds = Iterators.map(box -> box.items, boxes) |> Iterators.flatten |> ifmap(i -> i.id) |> unique
    itemMapping = Iterators.enumerate(itemIds) |> ifmap(x -> (x[2], x[1])) |> Dict
    itemsForJob = [[itemMapping[item.id] for item ∈ box.items] for box ∈ boxes]
    carTravelTime = Iterators.map(box -> box.items, boxes) |> Iterators.flatten |> ifmap(i -> i.transportTime) |> mean |> x -> round(Int, x)
    (lengths=jobLengths, itemsForJob, carTravelTime)
end

function Problem(batches::AbstractVector{Batch}, machineCount, carsCount, bufferSize, boxFilter=_ -> true, boxLimit=typemax(Int))
    jobs = toModerateJobs(batches, boxFilter, boxLimit)
    Problem(length(jobs.lengths), machineCount, carsCount, jobs.carTravelTime, maximum(Iterators.flatten(jobs.itemsForJob)), bufferSize, jobs.lengths, BitSet.(jobs.itemsForJob))
end

function parseInstance(filename)
    open(filename) do file
        jobCount, machineCount, robotCount, bufferSize, itemCount, travelTime = (parse(Int, s) for s ∈ split(readline(file)))
        jobLengths = [parse(Int, s) for s ∈ split(readline(file))]
        itemsNeeded = [BitSet(parse(Int, itm) + 1 for itm ∈ Iterators.drop(split(readline(file)), 1)) for _ = 1:jobCount]
        Problem(jobCount, machineCount, robotCount, travelTime, itemCount, bufferSize, jobLengths, itemsNeeded)
    end
end