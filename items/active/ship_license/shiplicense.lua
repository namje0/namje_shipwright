require "/scripts/messageutil.lua"

function init()
	message.setHandler("confirm_swap", localHandler(swap_ships))
end

function activate()
	if player then
		if world.entityType(activeItem.ownerEntityId()) ~= "player" then
			return
		end

		if player.worldId() ~= player.ownShipWorldId() then
			world.sendEntityMessage(activeItem.ownerEntityId(), "queueRadioMessage", "namje_ship_invalidowner")
			return
		end

		if not world.getProperty("fu_byos") then
			world.sendEntityMessage(activeItem.ownerEntityId(), "queueRadioMessage", "namje_ship_invalidbyos")
			return
		end
		animator.playSound("activate")

		activeItem.interact("ScriptPane", "/interface/scripted/ship_license/namje_ship_swap_confirm.config", entity.id())
	end
end

function swap_ships()
	local ship_type = config.getParameter("shipType")
	local cinematic = "/cinematics/upgrading/shipupgrade.cinematic"
	world.spawnStagehand({1024, 1024}, "ship_handler")
	world.sendEntityMessage("ship_handler", "swap_ship", activeItem.ownerEntityId(), ship_type)
	player.playCinematic(cinematic)
	world.sendEntityMessage(activeItem.ownerEntityId(), "queueRadioMessage", "namje_ship_noescape", 5.0)
	item.consume(1)
end