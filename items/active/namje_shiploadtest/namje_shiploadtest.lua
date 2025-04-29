require "/scripts/messageutil.lua"
require "/scripts/namje_byos.lua"

function init()
	
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
		else
			animator.playSound("activate")
			local ship = namje_byos.ship_to_table()
			player.setProperty("current_ship", ship)
			--[[message.setHandler("namje_getSavedShip", function(_, _, ship)
				player.setProperty("current_ship", ship)
			end)]]
			--world.spawnStagehand({1024, 1024}, "namje_saveShip_stagehand")
		end
	end
end
