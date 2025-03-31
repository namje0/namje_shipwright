
require "/scripts/vec2.lua"
require "/scripts/util.lua"

function init()
    message.setHandler("swap_ship", swap_ship)
end

function swap_ship(_, _, ply, ship_type)
    local ship_items = get_ship_items()
    local ship_create, err = pcall(create_ship, ply, ship_type)
    if ship_create then
        give_cargo(ply, ship_items)

        local players = world.players()
        for _, player in ipairs (players) do
            world.sendEntityMessage(player, "fs_respawn")
        end
    else 
        sb.logInfo("namje === ship swap failed: " .. err)
    end

    stagehand.die()
end

-- returns a list of every item stored in containers in the ship
--TODO: some containers seem to be ignored?
function get_ship_items()
    local items = {}
    local objects = world.objectQuery({500, 500}, {1500, 1500})
    for _, v in ipairs (objects) do
        local container_items = world.containerItems(v)
        if container_items then
            for _, i in ipairs (container_items) do
                table.insert(items, i)
            end
        end
    end
    return items
end

function give_cargo(ply, items)
    --Honestly I have no clue if i can get the player from their id and give it normally, this is defeat
    --ply.giveItem(cargo_box)
    world.sendEntityMessage(ply, "namje_give_cargo", items)
end

function create_ship(ply, ship_type)
    local ship_dungeon_id = config.getParameter("shipDungeonId", 10101)
    local replace_mode = {dungeon = "fu_byosblankquarter", size = {512, 512}}

    --[[if not world.getProperty("fu_byos") then 
        return 
    end]]
    --reset any byos stats to their default
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

    --world.placeDungeon(replace_mode.dungeon, getReplaceModePosition(replace_mode.size))
    world.placeDungeon(ship_type, vec2.add({1024, 1024}, {-6, 12}), ship_dungeon_id)
	
end

--from FU
function getReplaceModePosition(size)
	local position = {1024, 1024}
	local halfSize = vec2.div(size, 2)
	position[1] = position[1] - halfSize[1]
	position[2] = position[2] + halfSize[2] + 1

	return position
end