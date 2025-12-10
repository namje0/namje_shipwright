require "/scripts/namje_byos.lua"

function confirm()
  local slot = config.getParameter("slot")
  local ply_ships = namje_byos.get_ship_data()
  local ship_data = ply_ships["slot_"..slot]

  if not ship_data then
    sb.logInfo("namje // no ship data for slot %s", slot)
    return
  end

  local content = namje_byos.get_ship_content(slot)
  local previous_ship_content = #content > 0 and namje_binarySerializer.unpack_ship_data(content) or {}
  local items = {}

  if ship_data.stats then
    local modules = ship_data.stats.modules
    for _, v in pairs(modules) do
      local item = {name = v, count = 1}
      table.insert(items, item)
    end
  end

  if not isEmpty(previous_ship_content) then
    local obj_cache = {}
    for _, chunk in pairs (previous_ship_content[2]) do
      if chunk.objs and not isEmpty(chunk.objs) then
        for _, object in pairs (chunk.objs) do
          if type(object) == "table" then
            if not obj_cache[object[1]] then
              obj_cache[object[1]] = true
              local object_params = object[2]
              if object_params then
                local container_items = object_params.namje_container_items or nil
                if container_items then
                  for slot, item in pairs (container_items) do
                    table.insert(items, item)
                  end
                end
              end
            end
          end
        end
      end
    end
  end

  for _, v in pairs(ship_data.stats.cargo_hold) do
    table.insert(items, v)
  end

  if not isEmpty(items) then
    interface.queueMessage("^orange;Items left on your ship have been packaged for you.")
    world.sendEntityMessage(player.id(), "namje_give_cargo", items)
  end

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

  local ship_config = namje_byos.get_ship_config(ship_data.ship_info.ship_id)
  if not ship_config then
    return
  end

  --TODO: include upgrade levels in refund
  local refund = math.floor(ship_config.price * 0.25) or 0
  interface.queueMessage("You were given ^orange;" .. refund .. "^reset; pixels for your old ship.")
  player.addCurrency("money", refund)

  namje_byos.set_ship_content(slot, "")
  ply_ships["slot_"..slot] = {}
  namje_byos.set_ship_data(ply_ships)
  pane.dismiss()
end

function cancel()
  pane.dismiss()
end