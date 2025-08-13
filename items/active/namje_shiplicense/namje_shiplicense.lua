require "/scripts/messageutil.lua"
require "/scripts/namje_byos.lua"

function init()
	--message.setHandler("namje_confirmSwap", localHandler(swap_ships))
	message.setHandler("namje_confirmSlot", localHandler(function(slot_num, name, icon) 
		local ship_type = config.getParameter("shipType")
		local ship_list = player.getProperty("namje_ships", {})
		local ship_config = namje_byos.get_ship_config(ship_type)
		local slot = ship_list[slot_num]
		if not ship_config then
			error("namje // ship config not found for " .. ship_type)
		end
		if not slot then
			sb.logInfo("namje // slot %s not found in ship list", slot_num)
			return
		end

		name = string.len(name) > 0 and name or ship_config.name
		local ship = namje_byos.register_new_ship(tonumber(slot_num:match("slot_(%d+)")), ship_type, name, icon)

		interface.queueMessage("Interact with your ^orange;S.A.I.L.^reset; to swap to your new ship.")
		interface.queueMessage("^orange;" .. name .. "^reset; is now registered in your name.")
		item.consume(1)
	end))
end

function activate()
	if player then
		if world.entityType(activeItem.ownerEntityId()) ~= "player" then
			return
		end

		if not namje_byos.is_on_own_ship() then
			world.sendEntityMessage(activeItem.ownerEntityId(), "queueRadioMessage", "namje_ship_invalidowner")
			return
		end

		animator.playSound("activate")

		--activeItem.interact("ScriptPane", "/interface/scripted/namje_shiplicense/namje_ship_swap_confirm.config", entity.id())
		activeItem.interact("ScriptPane", "/interface/namje_shipslotselect/namje_shipslotselect.config", entity.id())
	end
end

function swap_ships()
	local ship_type = config.getParameter("shipType")
	local cinematic = "/cinematics/namje/shipswap.cinematic"
	--world.sendEntityMessage("ship_handler", "swap_ship", activeItem.ownerEntityId(), ship_type)

	namje_byos.change_ships_from_config(ship_type, false)

	player.playCinematic(cinematic)
	world.sendEntityMessage(activeItem.ownerEntityId(), "queueRadioMessage", "namje_ship_noescape", 7.0)
	item.consume(1)
end