function patch(config)
  local ships = assets.byExtension("namjeship")
  for i = 1, #ships do
    local ship = assets.json(ships[i])
    local create_license = ship.auto_create_license and ship.auto_create_license == true or false
    local add_to_bay = ship.add_to_penguin_bay and ship.add_to_penguin_bay == true or false

    if create_license and add_to_bay then
        local license_id = "shiplicense_" .. ship.id
        local license_formatted = {item = license_id}
        table.insert(config.interactData.items, {item = license_id})
    end
  end

  return config
end