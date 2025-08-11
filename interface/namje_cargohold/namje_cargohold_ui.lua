require "/scripts/namje_byos.lua"
require "/interface/namje_cargohold/namje_item_manager.lua"

local SLOT_LIST = "cargo_scroll.slots"

local item_grid, cargo_size, cargo_content

--TODO: make world property for last time cargo hold was checked, compare the seconds and increment the timeToRot for every food item, replacing with rotten food if 0

function init()
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
    cargo_content = ship_stats.cargo_hold

    item_grid = namje_item_manager.new(cargo_size, cargo_content, SLOT_LIST)
    item_grid:populate_grid("")
end

function update(dt)
end

function shiftItemFromInventory(item)
    if not item_grid then
        return
    end
    local add = item_grid:add_item(item)
    return add or true
end

function filter()
    if not item_grid then
        return
    end
    local text = string.gsub(widget.getText("filter"), "%s+", "")
    item_grid:populate_grid(text)
end

function sort()
    if not item_grid then
        return
    end
    item_grid:sort()
end
