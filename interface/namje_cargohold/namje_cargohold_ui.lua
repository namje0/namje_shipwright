require "/scripts/namje_byos.lua"

local slot_list = "cargo_scroll.slots"
local items_per_row = 10
local cargo_size

--TODO: make world property for last time cargo hold was checked, compare the seconds and increment the timeToRot for every food item, replacing with rotten food if 0

function init()
    widget.registerMemberCallback(slot_list, "take_item", receive_item)
    widget.registerMemberCallback(slot_list, "take_item.right", receive_item)
    if not namje_byos.is_on_ship() then
        pane.dismiss()
        return
    end

    local current_slot = player.getProperty("namje_current_ship", 1)
    local ship_stats = namje_byos.get_stats(current_slot)
    local ship_info = namje_byos.get_ship_info(current_slot)
    local ship_upgrades = namje_byos.get_upgrades(current_slot)

    if not ship_stats or not ship_info or not ship_upgrades then
        sb.logInfo("namje // could not get ship information")
        pane.dismiss()
        return
    end

    local ship_config = namje_byos.get_ship_config(ship_info.ship_id)
    if not ship_config then
        sb.logInfo("namje // could not get ship_config ")
        pane.dismiss()
        return
    end

    cargo_size = ship_upgrades.cargo_size > 0 and ship_config.stat_upgrades["cargo_size"][ship_upgrades.cargo_size].stat or ship_config.namje_stats.cargo_size
end

function update(dt)
    populate_grid()
end

function populate_grid()
    widget.clearListItems(slot_list)
    for i = 1, cargo_size do
        local item = widget.addListItem(slot_list)
        widget.setItemSlotItem(item, { name = "dirtmaterial", count = 5 })
    end
end

function receive_item(_, data)
    if not data then
        return
    end

    --local pos = mcontroller.position()
    --local pos = world.entityPosition(player.id())

    --world.sendEntityMessage(pane.containerEntityId(), "namje_receive_item", {data, pos}, player.worldId())
end