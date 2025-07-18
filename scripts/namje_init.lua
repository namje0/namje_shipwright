require "/scripts/namje_byos.lua"
require "/scripts/namje_util.lua"

local ini = init or function() end

function init() ini()
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

    message.setHandler("namje_get_saved_ship", function(_, _, serialized_ship)
        sb.logInfo("get ship serialization on player")
        if not serialized_ship or isEmpty(serialized_ship) then
            error("namje // serialized_ship is empty or nil")
        end
        local current_slot = player.getProperty("namje_current_ship", 1)
        player.setProperty("namje_slot_" .. current_slot .. "_shipcontent", serialized_ship)
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

function update(dt)
    if player.introComplete() and not player.getProperty("namje_byos_setup") then
        if namje_byos.is_on_ship() then
            namje_byos.init_byos()
        end
    end
end