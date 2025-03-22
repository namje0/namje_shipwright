
require "/scripts/vec2.lua"
require "/scripts/util.lua"

function init()
    sb.logInfo("stagehand created")
    create_ship()
    stagehand.die()
end

function create_ship()
    sb.logInfo("create namjeship")

    local ship_config = root.assetJson("/frackinship/configs/ships.config")

    local ship_dungeon_id = config.getParameter("shipDungeonId", 10101)
    local selected_ship = ship_config["namje_testship"]
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