require "/scripts/namje_byos.lua"

local exclude_npcs = true
local exclude_mons = true
local exclude_items = true

function init()
  if not namje_byos.is_on_own_ship() then
    interface.queueMessage("^yellow;You can only manage ship pets on ships you own.")
    pane.dismiss()
  end

  local current_slot = player.getProperty("namje_current_ship", 1)
  local ship_stats = namje_byos.get_stats(current_slot)
  local pet = ship_stats.pet

  if pet and pet.item and pet.id and pet.seed then
    widget.setItemSlotItem("slot", pet.item)
    widget.setText("lbl_pet", "Pet: " .. pet.id)
    widget.setText("lbl_seed", "Seed: " .. pet.seed)
  else
    widget.setText("lbl_pet", "Pet: none")
    widget.setText("lbl_seed", "Seed: N/A")
  end
  
end

function randomize()
  local current_slot = player.getProperty("namje_current_ship", 1)
  local ship_stats = namje_byos.get_stats(current_slot)
  local existing_pet = ship_stats.pet

  if not existing_pet or not existing_pet.id or not existing_pet.item or not existing_pet.seed then
    pane.playSound("/sfx/interface/clickon_error.ogg", 0, 1.5)
    return
  end

  local seed = generateSeed()
  existing_pet.seed = seed
  namje_byos.set_stats(current_slot, {pet = existing_pet})
  world.setProperty("namje_ship_pet", {existing_pet.id, seed})
  widget.setText("lbl_seed", "Seed: " .. seed)
end

function slot()
  if not namje_byos.is_on_own_ship() then
    return
  end

  local current_slot = player.getProperty("namje_current_ship", 1)
  local ship_stats = namje_byos.get_stats(current_slot)
  local existing_pet = ship_stats.pet

  local item = player.swapSlotItem()
  if item then
    local config = root.itemConfig(item.name).config
    local pet = config.namjePetType

    if not pet then
      pane.playSound("/sfx/interface/clickon_error.ogg", 0, 1.5)
      return
    end


    local seed = generateSeed()
    widget.setItemSlotItem("slot", item)
    namje_byos.set_stats(current_slot, {pet = {item = item.name, id = pet, seed = seed}})
    world.setProperty("namje_ship_pet", {pet, seed})
    widget.setText("lbl_pet", "Pet: " .. pet)
    widget.setText("lbl_seed", "Seed: " .. seed)

    if existing_pet and existing_pet.id and existing_pet.item and existing_pet.seed then
      local item = {name = existing_pet.item, count = 1}
      player.setSwapSlotItem(item)
    else
      player.setSwapSlotItem(nil)
    end
  else
    if existing_pet and existing_pet.id and existing_pet.item and existing_pet.seed then
      local item = {name = existing_pet.item, count = 1}
      player.setSwapSlotItem(item)
      widget.setItemSlotItem("slot", nil)
      namje_byos.set_stats(current_slot, {pet = {}})
      world.setProperty("namje_ship_pet", nil)
      widget.setText("lbl_pet", "Pet: none")
      widget.setText("lbl_seed", "Seed: N/A")
    end
  end
end