require "/scripts/namje_byos.lua"

function confirm()
  local slot = config.getParameter("slot")
  if tonumber(slot) == tonumber(player.getProperty("namje_current_ship", 1)) then
    sb.logInfo("namje // tried to salvage the equipped ship slot %s", slot)
    pane.dismiss()
    return
  end
  local ply_ships = namje_byos.get_ship_data()
  local ship_data = ply_ships["slot_"..slot]

  if not ship_data then
    sb.logInfo("namje // no ship data for slot %s", slot)
    return
  end

  namje_byos.salvage_ship(ship_data, namje_byos.get_ship_content(slot), namje_byos.get_cargo_hold(slot))

  local fuel_amount = ship_data.stats.fuel_amount
  if fuel_amount > 0 then
    interface.queueMessage("^pink;Fuel from your ship has been returned to you.")
    local full_stacks = math.floor(fuel_amount / 1000)
    local remainder = fuel_amount % 1000
    for i = 1, full_stacks do
        local item = {
            name = "liquidfuel",
            count = 1000 
        }
        player.giveItem(item)
    end
    
    if remainder > 0 then
        local item = {
            name = "liquidfuel",
            count = remainder
        }
        player.giveItem(item)
    end
  end

  namje_byos.set_ship_content(slot, "")
  namje_byos.set_cargo_hold(slot, nil)
  ply_ships["slot_"..slot] = {}
  namje_byos.set_ship_data(ply_ships)
  pane.dismiss()
end

function cancel()
  pane.dismiss()
end