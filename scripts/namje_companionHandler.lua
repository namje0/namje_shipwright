require "/scripts/namje_byos.lua"
require "/scripts/util.lua"

local stat_lang = {
    fuelEfficiency = "fuel_efficiency",
    maxFuel = "max_fuel",
    shipSpeed = "ship_speed",
    crewSize = "crew_size"
}
local config_cache = {}

local ini = init or function() end
local original_upd = update or function(dt) end
local original_ship_upgrades = updateShipUpgrades or function() end
local on_own_ship = false

function init() ini()
    message.setHandler("namje_return_crew", function() 
        return playerCompanions.getCompanions("crew")
    end)
    message.setHandler("namje_dismiss_crew", function(_, _, uuid) 
        local recruit = recruitSpawner:getRecruit(uuid)
        recruitSpawner:dismiss(uuid)
        recordEvent(entity.id(), "dismissCrewMember", recruitSpawner:eventFields(), recruit:eventFields())
    end)

    if namje_byos.is_on_own_ship() then
        on_own_ship = true
    else
        on_own_ship = false
    end
end

function update(dt) original_upd(dt)
    if not on_own_ship then
        return
    end
    --TODO: get_stats every second may be performance decrease based on cargo_hold content?
    --upd crew, fuel in info
    local player_ships = namje_byos.get_ship_data()
    local slot = player.getProperty("namje_current_ship", 1)
    local ship_stats = namje_byos.get_stats(slot)
    if not ship_stats then
        return
    end
    local crew_amt = #playerCompanions.getCompanions("crew")
    local fuel = world.getProperty("ship.fuel")
    local to_change = {}

    if ship_stats.fuel_amount ~= fuel then
        to_change["fuel_amount"] = fuel
    end
    if ship_stats.crew_amount ~= crew_amt then
        to_change["crew_amount"] = crew_amt
    end
    if not isEmpty(to_change) then
        namje_byos.set_stats(slot, to_change)
    end
end

--thanks to Silver Sokolova for assistance
function updateShipUpgrades() original_ship_upgrades()
    local slot = player.getProperty("namje_current_ship", 1)
    local ship_info = namje_byos.get_ship_info(slot)
    if not ship_info then
        return
    end
    local ship_upgrades = namje_byos.get_upgrades(slot)
    local ship_config = config_cache[ship_info.ship_id] or namje_byos.get_ship_config(ship_info.ship_id)
    if not ship_config then
        --TODO: check if the player has the BYOS enabling item, then give them it if they dont
        return
    end
    if config_cache[ship_info.ship_id] == nil then
        config_cache[ship_info.ship_id] = ship_config
    end

    local crew_upgrades = recruitSpawner:getShipUpgrades()
    local ship_base_stats = ship_config.base_stats
    local stats = {
        capabilities = namje_byos.is_fu() and {} or ship_base_stats.capabilities,
        fuel_efficiency = ship_base_stats.fuel_efficiency,
        max_fuel = ship_base_stats.max_fuel,
        ship_speed = ship_base_stats.ship_speed,
        crew_size = ship_base_stats.crew_size
    }

    for k, v in pairs(ship_upgrades) do
        if k ~= "modules" then
            if v > 0 then
                stats[k] = ship_config.stat_upgrades[k][v].stat
            end
        end
    end

    for i = 1, #crew_upgrades do
        local upgrade = crew_upgrades[i]
        for stat, v in pairs(upgrade) do
            local stat_name = stat_lang[stat]
            if stats[stat_name] then
                stats[stat_name] = stats[stat_name] + v
            end
        end
    end

    player.upgradeShip({
        capabilities = stats.capabilities,
        maxFuel = stats.max_fuel,
        fuelEfficiency = stats.fuel_efficiency,
        shipSpeed = stats.ship_speed,
        crewSize = stats.crew_size
    })
end