require "/scripts/namje_byos.lua"

local stat_lang = {
    fuelEfficiency = "fuel_efficiency",
    maxFuel = "max_fuel",
    shipSpeed = "ship_speed",
    crewSize = "crew_size"
}
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
    --upd crew in info
    local player_ships = player.getProperty("namje_ships", {})
    local slot = player.getProperty("namje_current_ship")
    local ship_stats = namje_byos.get_stats(slot)
    if not ship_stats then
        return
    end
    local crew_amt = #playerCompanions.getCompanions("crew")
    if ship_stats.crew_amount ~= crew_amt then
        namje_byos.set_stats(slot, {["crew_amount"] = crew_amt})
    end
end

--thanks to Silver Sokolova for assistance
function updateShipUpgrades() original_ship_upgrades()
    local slot = player.getProperty("namje_current_ship", 1)
    local ship_info = namje_byos.get_ship_info(slot)
    if not ship_info then
        return
    end
    local ship_config = namje_byos.get_ship_config(ship_info.ship_id)
    if not ship_config then
        --TODO: check if the player has the BYOS enabling item, then give them it if they dont
        return
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

    --TODO: byos upgrade modifiers

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