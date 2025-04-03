require("/scripts/namje_byos.lua")
require "/scripts/vec2.lua"

local ini = init or function() end

function init() ini()
    --TODO: FU Compability - don't use this handler if FU is detected
    message.setHandler("namje_moveToShipSpawn", move_to_ship_spawn)
end

function update(dt)

end

function move_to_ship_spawn()
    sb.logInfo("namje === move to ship spawn")
    local spawn = world.getProperty("namje_ship_spawn", {1024, 1024})
    mcontroller.setPosition(vec2.add(spawn, {0, 2}))
end