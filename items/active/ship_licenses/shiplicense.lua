function activate()
	if player then
		if world.entityType(activeItem.ownerEntityId()) ~= "player" then
			return
		end

		if not world.getProperty("fu_byos") then
			world.sendEntityMessage(activeItem.ownerEntityId(), "queueRadioMessage", "namje_invalid_ship_swap", 5.0)
			return
		end

		local ship_type = config.getParameter("shipType")

		animator.playSound("activate")
		world.spawnStagehand({1024, 1024}, "ship_handler")
		world.sendEntityMessage("ship_handler", "swap_ship", activeItem.ownerEntityId(), ship_type)
		item.consume(1)
	end
end