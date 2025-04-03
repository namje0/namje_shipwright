require "/scripts/vec2.lua"
require "/scripts/util.lua"

namje_byos = {}

function namje_byos.change_ships(ship_type)
    sb.logInfo("namje // changing ship to " .. ship_type)
    --if called on server, change the ship directly.
    --if called on client, create the stagehand that will handle changing the ship
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

function namje_byos.spawn_ship(ship_type)
    if world.getProperty("fu_byos") then 
        namje_byos.reset_fu_stats() 
    end

    local ship_dungeon_id = config.getParameter("shipDungeonId", 10101)
    local replace_mode = {dungeon = "namje_void", size = {512, 512}}

    world.placeDungeon(replace_mode.dungeon, getReplaceModePosition(replace_mode.size))
    world.placeDungeon(ship_type, vec2.add({1024, 1024}, {-6, 12}), ship_dungeon_id)
end

function namje_byos.reset_fu_stats()
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