require "/scripts/vec2.lua"
require "/scripts/util.lua"
require "/scripts/namje_byos.lua"

function init()
    message.setHandler("namje_save_ship", function(_, _, ply, exclude_items)
        stagehand.die()
        local region = {0, 0, 1000, 1000}
        world.loadRegion(region)
        return namje_byos.ship_to_table(exclude_items)
    end)
end