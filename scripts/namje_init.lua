require("/scripts/namje_byos.lua")

local ini = init or function() end

function init() ini()
    message.setHandler("namje_give_cargo", function(_, _, items) 
        local cargo_box = {
            name = "namje_cargo_box",
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
            namje_byos.change_ships("namje_startershuttle", true)
            player.setProperty("namje_byos_setup", true)
        end
    end
end