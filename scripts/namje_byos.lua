require "/scripts/vec2.lua"
require "/scripts/util.lua"

--utility module used for ship stuff

namje_byos = {}

function namje_byos.change_ships(ship_type, init)
    sb.logInfo("namje // changing ship to " .. ship_type)
    local ship_config = root.assetJson("/atelier_ships/ships/".. ship_type .."/ship.config")
    if not ship_config then
        error("namje // ship config not found for " .. ship_type)
    end
    if ship_config.ship ~= ship_type then
        error("namje // ship config does not match ship type " .. ship_type)
    end

    sb.logInfo(sb.printJson(ship_config))

    local is_server = world.isServer()
    if is_server then
        sb.logInfo("namje // changing ship on server")
    else
        sb.logInfo("namje // changing ship on client")

        if player.worldId() ~= player.ownShipWorldId() then
            error("namje // tried to change ship on client while player world id is not their ship world id")
        end

        world.spawnStagehand({1024, 1024}, "namje_ship_stagehand")
        world.sendEntityMessage("namje_ship_stagehand", "swap_ship", player.id(), ship_type)
    end
end

function namje_byos.spawn_ship(ship_config)
    if world.getProperty("fu_byos") then 
        namje_byos.reset_fu_stats() 
    end
    local ship_dungeon_id = config.getParameter("shipDungeonId", 10101)
    local replace_mode = {dungeon = "namje_void", size = {512, 512}}

    local teleporter_offset = ship_config.atelier_stats.teleporter_position
    local ship_position = vec2.sub({1024, 1024}, {teleporter_offset[1], -teleporter_offset[2]})

    --TODO: send entity message for this
    --player.upgradeShip({capabilities = ship_config.capabilities, maxFuel = ship_config.maxFuel, fuelEfficiency = ship_config.fuelEfficiency, shipSpeed = ship_config.shipSpeed, crewSize = ship_config.crewSize})

    world.placeDungeon(replace_mode.dungeon, getReplaceModePosition(replace_mode.size))
    world.placeDungeon(ship_config.ship, ship_position, ship_dungeon_id)
end

function namje_byos.is_fu()
    local status, err = pcall(function()
        local fu = root.assetJson("/frackinship/configs/ships.config")
        if fu then
            return true
        end
    end)
    return false
end

function namje_byos.reset_fu_stats()
    if not namje_byos.is_fu() then return end

    local ship_stats = {
        "shipSpeed",
        "fuelEfficiency",
        "maxFuel",
        "crewSize"
    }

    local ship_capabilities = {
        "systemTravel",
        "planetTravel"
    }

    for _, stat in ipairs(ship_stats) do
        world.setProperty("fu_byos." .. stat, 0)
    end

    for _, capability in ipairs(ship_capabilities) do
        world.setProperty("fu_byos." .. capability, 0)
    end

    world.setProperty("fu_byos.group.ftlDrive", 0)
end

--taken from Frackin Universe
function getReplaceModePosition(size)
	local position = {1024, 1024}
	local halfSize = vec2.div(size, 2)
	position[1] = position[1] - halfSize[1]
	position[2] = position[2] + halfSize[2] + 1

	return position
end