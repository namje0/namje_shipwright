require("/scripts/namje_byos.lua")

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

    message.setHandler("namje_upd_cargoinfo", function(_, _, cargo_hold)
        function deep_copy(original_table)
            local copied_table = {}
            for key, value in pairs(original_table) do
                if type(value) == "table" then
                    copied_table[key] = deep_copy(value)
                else
                    copied_table[key] = value
                end
            end

            return copied_table
        end

        local slot = player.getProperty("namje_current_ship", 1)
        local ship_stats = namje_byos.get_stats(slot)
        if not ship_stats then
            sb.logInfo("namje // no ship stats found for slot %s", slot)
            return
        end
        namje_byos.set_stats(slot, {["cargo_hold"] = deep_copy(cargo_hold)})
    end)

    message.setHandler("namje_get_shipinfo", function(_, _, ship) 
        return namje_byos.get_ship_info(player.id())
    end)

    message.setHandler("namje_set_shipinfo", function(_, _, ship_info) 
        namje_byos.set_ship_info(player.id(), ship_info)
    end)

    if player.introComplete() and not player.getProperty("namje_byos_setup") then
        self.tick_test = 1
    end
end

function update(dt)
    --the player's inital spawn has their world set to "Nowhere"
    --just wait a few ticks until the player is in their ship world
    if player.introComplete() and not player.getProperty("namje_byos_setup") then
        self.tick_test = self.tick_test + 1
        if self.tick_test > 10 then
            namje_byos.init_byos()
        end
    end
end