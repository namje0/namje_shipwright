require("/scripts/namje_byos.lua")
require "/scripts/vec2.lua"

local fu_atmosphere = false
local initial_outside = false
local on_ship = false
local on_own_ship = false

function init()
    if namje_byos.is_fu() then
        fu_atmosphere = true
        sb.logInfo("namje // fu atmosphere detected")
    else
        message.setHandler("namje_moveToShipSpawn", move_to_ship_spawn)
    end
    if not namje_byos.is_on_ship() then
        on_ship = false
        mcontroller.clearControls()
        initial_outside = true
    else
        on_ship = true
    end
    if namje_byos.is_on_own_ship() then
        on_own_ship = true
    else
        on_own_ship = false
    end

    message.setHandler("namje_upgradeShip", function(_, _, ship_stats)
        sb.logInfo("namje // upgrading ship with stats")
        local capabilities = namje_byos.is_fu() and {} or ship_stats.capabilities
        player.upgradeShip({capabilities = capabilities, maxFuel = ship_stats.max_fuel, fuelEfficiency = ship_stats.fuel_efficiency, shipSpeed = ship_stats.ship_speed, crewSize = ship_stats.crew_size})
    end)
end

function update(dt)
    if fu_atmosphere then
        return
    end
    if not on_ship then
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

    if on_own_ship then
        --upd fuel in info
        local fuel = world.getProperty("ship.fuel")
        local slot = player.getProperty("namje_current_ship", 1)
        local ship_stats = namje_byos.get_stats(slot)
        if not ship_stats then
            return
        end
        if ship_stats.fuel_amount ~= fuel then
            namje_byos.set_stats(slot, {["fuel_amount"] = fuel})
        end
    end
end

function move_to_ship_spawn()
    sb.logInfo("namje === move to ship spawn")
    --[[local spawn = world.getProperty("namje_ship_spawn", {1024, 1024})
    mcontroller.setPosition(vec2.add(spawn, {0, 2}))]]
    player.warp("nowhere")
end