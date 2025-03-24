
require "/scripts/vec2.lua"
require "/scripts/util.lua"

function init()
    message.setHandler("swap_ship", swap_ship)
end

function swap_ship(_, _, ply, ship_type)
    sb.logInfo("start ship swapping process")
    local ship_items = get_ship_items()
    create_ship(ply, ship_type)
    give_cargo(ply, ship_items)

    local players = world.players()
    for _, player in ipairs (players) do
        world.sendEntityMessage(player, "fs_respawn")
    end

    stagehand.die()
end

-- returns a list of every item stored in containers in the ship. Hopefully...
--TODO: Fix radius, its too short range? Doesn't grab all items
function get_ship_items()
    local items = {}
    local locker
    local objects = world.objectQuery(entity.position(), 500)
    for _, v in ipairs (objects) do
        local is_container = world.containerSize(v) ~= nil
        if is_container then
            local shiplocker = string.find(world.entityName(v), "fuwallsafe")
            if shiplocker then
                locker = v
            end
            local container_items = world.containerItems(v)
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
    sb.logInfo("create namjeship")

    local ship_config = root.assetJson("/frackinship/configs/ships.config")

    local ship_dungeon_id = config.getParameter("shipDungeonId", 10101)
    local selected_ship = ship_config[ship_type]
    local replace_mode = {dungeon = "fu_byosblankquarter", size = {512, 512}}

    if selected_ship then
		selected_ship.offset = selected_ship.offset or {-6, 12}
		selected_ship.offset[1] = math.min(selected_ship.offset[1], -1)
		selected_ship.offset[2] = math.max(selected_ship.offset[2], 1)
		world.placeDungeon(replace_mode.dungeon, getReplaceModePosition(replace_mode.size))
		world.placeDungeon(selected_ship.ship, vec2.add({1024, 1024}, selected_ship.offset), ship_dungeon_id)
	else
        sb.logInfo("cant find namjeship")
    end
end

--from FU
function getReplaceModePosition(size)
	local position = {1024, 1024}
	local halfSize = vec2.div(size, 2)
	position[1] = position[1] - halfSize[1]
	position[2] = position[2] + halfSize[2] + 1

	return position
end