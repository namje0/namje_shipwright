require "/scripts/messageutil.lua"
require "/scripts/namje_byos.lua"

function init()
	message.setHandler("namje_confirmSwap", localHandler(swap_ships))
end

function activate()
	if player then
		if world.entityType(activeItem.ownerEntityId()) ~= "player" then
			return
		end

		if player.worldId() ~= player.ownShipWorldId() then
			world.sendEntityMessage(activeItem.ownerEntityId(), "queueRadioMessage", "namje_ship_invalidowner_bill")
			return
		end

		animator.playSound("activate")

		activeItem.interact("ScriptPane", "/interface/scripted/namje_shipbill/namje_bill_swap_confirm.config", entity.id())
	end
end

function swap_ships()
	local ship_type = player.getProperty("namje_last_ship", {})
	if #ship_type == 0 then
		interface.queueMessage("You don't have a previous ship to revert back to!")
		return
	end
	local cinematic = "/cinematics/upgrading/shipupgrade.cinematic"

	namje_byos.change_ships_from_table(ship_type)
	player.setProperty("namje_last_ship", {})

	player.playCinematic(cinematic)
	item.consume(1)
end