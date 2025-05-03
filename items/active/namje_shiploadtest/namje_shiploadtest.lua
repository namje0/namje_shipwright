require "/scripts/messageutil.lua"
require "/scripts/namje_byos.lua"

function init()
	message.setHandler("namje_getSavedShip", function(_, _, ship)
		sb.logInfo("namje // saved current shipworld on client")
		player.setProperty("current_ship", ship)
		interface.queueMessage("ship successfully saved")
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

		--[[if not world.getProperty("fu_byos") then
			world.sendEntityMessage(activeItem.ownerEntityId(), "queueRadioMessage", "namje_ship_invalidbyos")
			return
		end]]
		if mode == "alt" then
			animator.playSound("activate")
			local ship_type = config.getParameter("shipType")
			local cinematic = "/cinematics/upgrading/shipupgrade.cinematic"

			namje_byos.change_ships_from_save(nil)
			player.playCinematic(cinematic)
			interface.queueMessage("ship successfully loaded")
		else
			animator.playSound("activate")
			world.spawnStagehand({1024, 1024}, "namje_saveShip_stagehand")
			world.sendEntityMessage("namje_saveShip_stagehand", "namje_saveShip", player.id())
		end
	end
end
