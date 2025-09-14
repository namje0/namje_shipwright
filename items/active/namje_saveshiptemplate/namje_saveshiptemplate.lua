require "/scripts/namje_byos.lua"

function uninit()
	root.setConfigurationPath("namje_ship_template", {})
end

function activate()
	local mode = activeItem.fireMode()
	if player then
		if world.entityType(activeItem.ownerEntityId()) ~= "player" then
			return
		end
		
		if player.worldId() ~= player.ownShipWorldId() then
			world.sendEntityMessage(activeItem.ownerEntityId(), "queueRadioMessage", "namje_ship_invalidowner")
			return
		end
		local save_containers = false
		if mode == "alt" then
			save_containers = true
		end

		animator.playSound("activate")
		world.spawnStagehand({1024, 1024}, "namje_saveShip_stagehand")
		local current_slot = player.getProperty("namje_current_ship", 1)
		world.sendEntityMessage("namje_saveShip_stagehand", "namje_save_ship", player.id(), current_slot, 2)
	end
end
