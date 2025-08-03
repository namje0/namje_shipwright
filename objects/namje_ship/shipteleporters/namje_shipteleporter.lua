require "/scripts/vec2.lua"
local ini = init or function() end

function init() ini()
    sb.logInfo("namje === ship teleporter init")
    local id = world.id()
    if string.find(id, "ClientShipWorld") then
        sb.logInfo("namje === ship teleporter found shipworld, setting pos of playerstart and namje_ship_spawn")
        world.setProperty("namje_ship_spawn", vec2.add(object.position(), {0, 1}))
        world.setPlayerStart(vec2.add(object.position(), {0, 1}))
    end
end