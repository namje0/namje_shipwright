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

		local last_ship = player.getProperty("namje_last_ship")
		if not last_ship[1] then
			interface.queueMessage("You don't have a previous ship to revert back to!")
			return
		end

		animator.playSound("activate")
		activeItem.interact("ScriptPane", "/interface/scripted/namje_shipbill/namje_bill_swap_confirm.config", entity.id())
	end
end

function swap_ships()
	local last_ship = player.getProperty("namje_last_ship")
	if not last_ship[1] then
		interface.queueMessage("You don't have a previous ship to revert back to!")
		return
	end
	local cinematic = "/cinematics/namje/shipswap.cinematic"

	namje_byos.change_ships_from_table(last_ship)
	player.setProperty("namje_last_ship", {})

	player.playCinematic(cinematic)
	item.consume(1)
end