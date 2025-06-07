require("/scripts/namje_byos.lua")

local ini = init or function() end

function init() ini()
    message.setHandler("namje_save_prev_ship", function(_, _, ship) 
        player.setProperty("namje_last_ship", {ship, namje_byos.get_ship_info()})
        local bill = {
            name = "namje_shipreceipt",
            parameters = {},
            amount = 1
        }
        player.giveItem(bill)
    end)

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

    message.setHandler("namje_upd_shipinfo", function(_, _, ship_id) 
        local ship_info = namje_byos.get_ship_info()
        local new_ship_info = {
            ship_id = ship_id,
            stats = {
                crew_amount = ship_info.stats.crew_amount,
                cargo_amount = ship_info.stats.cargo_amount,
                fuel_amount = ship_info.stats.fuel_amount
            },
            upgrades = {
                fuel_efficiency = 0,
                max_fuel = 0,
                ship_speed = 0,
                crew_size = 0
            }
        }
        player.setProperty("namje_ship_info", new_ship_info)
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
            local existing_char = player.hasCompletedQuest("bootship")
            if existing_char then
                --being used on an existing character, show interface disclaimer thing and give the player an item to 
                --enable byos systems and a starter shiplicense
                player.interact("scriptPane", "/interface/scripted/namje_existingchar/namje_existingchar.config")
                player.giveItem("namje_enablebyositem")
                player.setProperty("namje_byos_setup", true)
            else
                namje_byos.change_ships_from_config("namje_startership", true)
                player.setProperty("namje_byos_setup", true)
                player.giveItem("shiplicense_namje_aomkellion")
            end
        end
    end
end