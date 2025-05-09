require "/scripts/vec2.lua"
require "/scripts/util.lua"
require "/scripts/namje_byos.lua"

function init()
    message.setHandler("namje_saveShip", function(_, _, ply, exclude_items)
        local ship = namje_byos.ship_to_table(exclude_items)
        world.sendEntityMessage(ply, "namje_getSavedShip", ship)
        stagehand.die()
    end)
end