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

    message.setHandler("namje_swap_ships", function(_, _, slot)
        local ship_swap, err = pcall(namje_byos.swap_ships, slot, swap_promise)
        if not ship_swap then
            sb.logInfo("namje_sail // ship swap failed: %s", err)
            interface.queueMessage("^red;There was an error while swapping ships")
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
