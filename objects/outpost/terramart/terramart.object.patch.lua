function patch(config)
  local items = assets.byExtension("activeitem")
  for _, v in pairs(items) do
    local item = assets.json(v)
    if item.namjePetType then
      table.insert(config.interactData.items, {item = item.itemName})
    end
  end

  return config
end