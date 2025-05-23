require("/scripts/namje_byos.lua")

local ini = init or function() end

function init() ini()
    message.setHandler("namje_give_bill", function(_, _, ship) 
        player.setProperty("namje_last_ship", ship)
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
            end
        end
    end
end