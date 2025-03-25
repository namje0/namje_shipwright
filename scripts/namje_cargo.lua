local ini = init or function() end

function init() ini()
    player.setUniverseFlag("outpost_namje_shipbroker")
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
end