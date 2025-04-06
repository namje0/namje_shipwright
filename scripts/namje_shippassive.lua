require("/scripts/namje_byos.lua")
require "/scripts/vec2.lua"

local ini = init or function() end
local initial_outside = false

function init() ini()
    --TODO: FU Compability - don't use this handler if FU is detected
    message.setHandler("namje_moveToShipSpawn", move_to_ship_spawn)

    message.setHandler("namje_upgradeShip", upgrade_ship)
end

function update(dt)
    if player.worldId() ~= player.ownShipWorldId() then
        if not initial_outside then
            mcontroller.clearControls()
            initial_outside = true
        end
        return
    end
    if not world.tileIsOccupied(mcontroller.position(), false) then
        mcontroller.controlParameters({gravityEnabled = false})
        if initial_outside then
            mcontroller.setVelocity({0, 0})
            initial_outside = false
        end
    else
        mcontroller.clearControls()
        initial_outside = true
    end
end

--TODO: this doesn't work on the initial ship spawn, only on ship change (aside from changing crew size?)
--this shouldn't matter much, just use the default ship stats for the initial spawn
function upgrade_ship(_, _, ship_stats)
    player.upgradeShip({capabilities = ship_stats.capabilities, maxFuel = ship_stats.max_fuel, fuelEfficiency = ship_stats.fuel_efficiency, shipSpeed = ship_stats.ship_speed, crewSize = ship_stats.crew_size})
end

function move_to_ship_spawn()
    sb.logInfo("namje === move to ship spawn")
    local spawn = world.getProperty("namje_ship_spawn", {1024, 1024})
    mcontroller.setPosition(vec2.add(spawn, {0, 2}))
end