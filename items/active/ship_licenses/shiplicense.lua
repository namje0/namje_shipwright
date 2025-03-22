function activate()
	if player then
		sb.logInfo("ship test: player activated license")

		if world.entityType(activeItem.ownerEntityId()) ~= "player" then
			return
		end

		animator.playSound("activate")
		world.spawnStagehand({1024, 1024}, "ship_handler")
		item.consume(1)
	end
end