function activate()
  local upgrades = player.shipUpgrades()
  if #upgrades.capabilities <= 1 then
    player.upgradeShip({capabilities = {"teleport", "planetTravel", "systemTravel"}})
    local cinematic = "/cinematics/upgrading/shipupgrade.cinematic"
    player.playCinematic(cinematic)
    item.consume(1)
  else
    interface.queueMessage("Your ship does not need repairs.")
  end
end