local ini = init or function() end

local items_per_row = 10
local cargo_size

--TODO: make world property for last time cargo hold was checked, compare the seconds and increment the timeToRot for every food item, replacing with rotten food if 0

function init() ini()
    widget.registerMemberCallback("cargoHoldScrollArea.itemList", "take_item", receive_item)
    widget.registerMemberCallback("cargoHoldScrollArea.itemList", "take_item.right", receive_item)

    cargo_size = world.getProperty("namje_cargo_size", 0)
end

function update(dt)
    local item = world.containerItemAt(pane.containerEntityId(), 0)
    local cargo_hold = world.getProperty("namje_cargo_hold") or {}
    if item and #cargo_hold < cargo_size then
        world.sendEntityMessage(pane.containerEntityId(), "namje_cargohold_insert", item)
    end
    create_grid()
end

function create_grid()
    widget.clearListItems("cargoHoldScrollArea.itemList")
    
    local num_items = 1
    local rows = {}
    local list = "cargoHoldScrollArea.itemList"
    local cargo_hold = world.getProperty("namje_cargo_hold") or {}
 
    local color = #cargo_hold >= cargo_size and "red" or #cargo_hold > cargo_size*.7 and "orange" or "white"
    widget.setText("count", "CAPACITY ^" .. color .. ";" .. #cargo_hold .. "/" .. cargo_size .. "^reset;")

    if #cargo_hold == 0 then
        return
    end

    local num_rows = math.ceil(#cargo_hold/items_per_row)
    for i = 1, num_rows do
        rows[i] = string.format("%s.%s", list, widget.addListItem(list))
    end

    for i = 1, #rows do
        for j = 1, items_per_row do
            local item = cargo_hold[num_items] or nil
            if item then
                widget.setItemSlotItem(rows[i] .. ".slot" .. j, { name = item.name, count = item.count, parameters = item.parameters })
                widget.setData(rows[i] .. ".slot" .. j, item)
                num_items = num_items + 1
            else
                widget.setItemSlotItem(rows[i] .. ".slot" .. j, nil)
            end
        end
    end
end

function receive_item(_, data)
    if not data then
        return
    end

    --local pos = mcontroller.position()
    local pos = world.entityPosition(player.id())

    world.sendEntityMessage(pane.containerEntityId(), "namje_receive_item", {data, pos})
end