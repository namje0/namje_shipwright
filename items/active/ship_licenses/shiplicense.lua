--[[function init()
	world.spawnStagehand({1024, 1024}, "ship_handler")
end]]

function activate()
	if player then
		sb.logInfo("ship test: player activated license")

		if world.entityType(activeItem.ownerEntityId()) ~= "player" then
			return
		end

		local ship_type = config.getParameter("shipType")

		animator.playSound("activate")
		world.spawnStagehand({1024, 1024}, "ship_handler")
		sb.logInfo(ship_type)
		world.sendEntityMessage("ship_handler", "swap_ship", activeItem.ownerEntityId(), ship_type)
		item.consume(1)
	end
end