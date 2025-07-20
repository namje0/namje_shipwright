require "/scripts/messageutil.lua"
require "/scripts/namje_byos.lua"

function uninit()
	root.setConfigurationPath("namje_ship_template", {})
end

function init()
	message.setHandler("namje_get_saved_ship", function(_, _, ship)
		sb.logInfo("namje // saved current shipworld on client")
		root.setConfigurationPath("namje_ship_template", ship)
		interface.queueMessage("^orange;namje_ship_template^reset; will be cleared on item unload, so copy it beforehand")
		interface.queueMessage("For info on how to use it in a ship file, check the github page")
		interface.queueMessage("Template saved to starbound.config as ^orange;namje_ship_template")
	end)
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

		if mode == "alt" then
			animator.playSound("activate")
			world.spawnStagehand({500, 500}, "namje_saveShip_stagehand")
			world.sendEntityMessage("namje_saveShip_stagehand", "namje_save_ship", player.id(), true)
		else
			animator.playSound("activate")
			world.spawnStagehand({500, 500}, "namje_saveShip_stagehand")
			world.sendEntityMessage("namje_saveShip_stagehand", "namje_save_ship", player.id(), false)
		end
	end
end
