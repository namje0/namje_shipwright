local ini = init or function() end

function init() ini()
    message.setHandler("namje_give_cargo", function(_, _, items) 
        sb.logInfo("recieved cargo request")

        local cargo_box = {
            name = "namje_cargo_box",
            parameters = {
                loot = items
            },
            amount = 1
        }

        player.giveItem(cargo_box)

        --[[for _, item in ipairs(items) do
            player.giveItem(item)
        end]]
    end)
end