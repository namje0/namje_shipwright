require("/scripts/namje_byos.lua")

function activate()
  if player.getProperty("namje_outpostvoucher", false) then
    interface.queueMessage("You already used an outpost parking pass.")
    return
  end
  local slots_added = namje_byos.add_ship_slots(1)
  if slots_added then
    player.setProperty("namje_outpostvoucher", true)
    interface.queueMessage("You gained an extra ship slot.")
    item.consume(1)
  else
    interface.queueMessage("You are full capacity on ship slots.")
  end
end