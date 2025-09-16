require "/scripts/namje_byos.lua"
require "/scripts/namje_util.lua"

local cargo_config
local ini = init or function() end
local updat = update or function() end
local swap_promise

function init() ini()
    swap_promise = PromiseKeeper.new()
    message.setHandler("namje_give_cargo", function(_, _, items) 
        local cargo_box = {
            name = "namje_cargobox",
            parameters = {
                loot = items
            },
            amount = 1
        }
        player.giveItem(cargo_box)
    end)

    message.setHandler("namje_ship_loading", function()
        local cinematic = "/cinematics/namje/shiploading.cinematic"
        player.playCinematic(cinematic)
    end)

    message.setHandler("namje_ship_loading_end", function()
        local cinematic = "/cinematics/namje/shiploadingend.cinematic"
        player.playCinematic(cinematic)
    end)

    message.setHandler("namje_swap_ships", function(_, _, slot)
        local ship_swap, err = pcall(namje_byos.swap_ships, slot, swap_promise)
        if not ship_swap then
            sb.logInfo("namje_sail // ship swap failed: %s", err)
            interface.queueMessage("^red;There was an error while swapping ships")
        end
    end)

    message.setHandler("namje_receive_serialized_ship", function(_, _, result, slot, action, ...)
        local args = {...}
        if action == 1 then
            player.setProperty("namje_slot_" .. slot .. "_shipcontent", result)
            --interface.queueMessage("^orange;Ship for slot " .. slot .. " saved")
            local new_slot = args[1][1]

            if not new_slot then
                sb.logInfo("no new slot error")
                return
            end

            local player_ships = player.getProperty("namje_ships", {})
            local ship_data = player_ships["slot_" .. new_slot]
            if not ship_data then
                sb.logInfo("namje_byos.swap_ships // no ship data found for slot_%s. player ships: %s", new_slot, player_ships)
                return false
            end
            local ship_content = player.getProperty("namje_slot_" .. new_slot .. "_shipcontent", {})

            local ship_info = namje_byos.get_ship_info(new_slot)
            local ship_stats = namje_byos.get_stats(new_slot)
            local prev_ship_stats = namje_byos.get_stats(slot)
            if not ship_info or not ship_stats then
                error("namje_byos.swap_ships // could not find ship data for %s", new_slot)
            end

            local cinematic = "/cinematics/namje/shipswap.cinematic"
            --player.playCinematic(cinematic)

            local current_region_cache = world.getProperty("namje_region_cache", {})

            -- default to config ship if the ship content is empty
            if isEmpty(ship_content) then
                namje_byos.change_ships_from_config(ship_info.ship_id, false, current_region_cache)
            else
                namje_byos.change_ships_from_table(ship_content, current_region_cache)
            end
            
            local prev_cargo_hold = isEmpty(prev_ship_stats.cargo_hold) and {} or namje_util.deep_copy(prev_ship_stats.cargo_hold)
            if prev_ship_stats then
                namje_byos.set_stats(slot, {
                    ["cached_regions"] = current_region_cache,
                    ["fuel_amount"] = prev_ship_stats.fuel_amount, 
                    ["cargo_hold"] = prev_cargo_hold, 
                    ["celestial_pos"] = {["system"] = celestial.currentSystem(), ["location"] = celestial.shipLocation()}
                })
            end

            namje_byos.set_current_ship(new_slot)
            local new_dest = ship_stats.celestial_pos
            celestial.flyShip(new_dest.system.location, new_dest.location)
            world.setProperty("namje_region_cache", ship_stats.cached_regions or {})
            world.setProperty("ship.fuel", ship_stats.fuel_amount)
        elseif action == 2 then
            sb.logInfo("end result %s", result)
            root.setConfigurationPath("namje_ship_template", result)
		    interface.queueMessage("^orange;namje_ship_template^reset; will be cleared on item unload, so copy it beforehand")
            interface.queueMessage("For info on how to use it in a ship file, check the github page")
            interface.queueMessage("Template saved to starbound.config as ^orange;namje_ship_template")
        end
	end)

    message.setHandler("namje_cargohold_open", function() 
        local on_ship = namje_byos.is_on_own_ship()
        if on_ship then
            if not cargo_config then
                cargo_config = root.assetJson("/interface/namje_cargohold/namje_cargohold_ui.config")
            end
            player.interact("ScriptPane", cargo_config, player.id())
        end
        return on_ship
    end)
end

function update(dt) updat(dt)
    swap_promise:update()
    if player.introComplete() and not player.getProperty("namje_byos_setup") then
        if namje_byos.is_on_ship() then
            namje_byos.init_byos()
        end
    end
end
