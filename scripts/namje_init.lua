require "/scripts/namje_byos.lua"
require "/scripts/namje_util.lua"

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

    message.setHandler("namje_swap_ships", function(_, _, slot)
        local ship_swap, err = pcall(namje_byos.swap_ships, slot, swap_promise)
        if not ship_swap then
            sb.logInfo("namje_sail // ship swap failed: %s", err)
            interface.queueMessage("^red;There was an error while swapping ships")
        end
    end)

    message.setHandler("namje_upd_cargoinfo", function(_, _, cargo_hold)
        local slot = player.getProperty("namje_current_ship", 1)
        local ship_stats = namje_byos.get_stats(slot)
        if not ship_stats then
            sb.logInfo("namje // no ship stats found for slot %s", slot)
            return
        end
        namje_byos.set_stats(slot, {["cargo_hold"] = namje_util.deep_copy(cargo_hold)})
    end)

    message.setHandler("namje_get_shipinfo", function(_, _, ship) 
        return namje_byos.get_ship_info(player.id())
    end)

    message.setHandler("namje_set_shipinfo", function(_, _, ship_info) 
        namje_byos.set_ship_info(player.id(), ship_info)
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
