require "/scripts/namje_byos.lua"

local MODULE_SLOT_LIST = "module_slots"
local MODULE_DISABLED_LIST = "disabled_mod_slots"

local module_slots = {}
local before_changes = {}

function init()
  if not namje_byos.is_on_own_ship() then
    interface.queueMessage("^yellow;You can only manage ship modules on ships you own.")
    pane.dismiss()
    return
  end

  widget.registerMemberCallback(MODULE_SLOT_LIST, "slot", function(_, index)
    if not index then
      return
    end
    local slot = module_slots[index]
    if slot then
        module_slot(index)
    end
  end)
  widget.registerMemberCallback(MODULE_SLOT_LIST, "slot.right", function() end)

  local current_slot = player.getProperty("namje_current_ship", 1)
  local ship_stats = namje_byos.get_stats(current_slot)
  local ship_modules = ship_stats.modules
  local ship_upg = namje_byos.get_upgrades(current_slot)
  if not ship_upg and not ship_upg.modules then
    interface.queueMessage("^red;Error grabbing ship modules.")
    pane.dismiss()
    return
  end

  widget.clearListItems(MODULE_SLOT_LIST)
  widget.clearListItems(MODULE_DISABLED_LIST)

  for i = 1, 5 do
    module_slots[i] = MODULE_SLOT_LIST.."."..widget.addListItem(MODULE_SLOT_LIST)
    local disabled_slot = MODULE_DISABLED_LIST.."."..widget.addListItem(MODULE_DISABLED_LIST)

    widget.setData(module_slots[i] .. ".slot", i)
    if i > ship_upg.modules then
      widget.setVisible(disabled_slot .. ".slot", true)
      widget.setVisible(module_slots[i] .. ".slot", false)
    end
  end

  for k, v in pairs(ship_modules) do
    local slot_number = tonumber(k:match("slot_(%d+)"))
    if v then
      local item = {name = v, count = 1}
      widget.setItemSlotItem(module_slots[slot_number] .. ".slot", item)
      before_changes["slot_" .. slot_number] = v
    end
  end
end

function module_slot(index)
  if not namje_byos.is_on_own_ship() then
    return
  end

  local current_slot = player.getProperty("namje_current_ship", 1)
  local ship_stats = namje_byos.get_stats(current_slot)
  local ship_modules = ship_stats.modules
  local existing_module = ship_modules["slot_" .. index]
  local item = player.swapSlotItem()
  if item then
    local config = root.itemConfig(item.name).config
    if config.isNamjeModule then
      if not current_slot then
        return
      end

      for k, v in pairs(ship_modules) do
        if v and v == item.name then
          interface.queueMessage("Duplicate modules cannot be slotted in.")
          pane.playSound("/sfx/interface/clickon_error.ogg", 0, 1.5)
          return
        end
      end

      ship_modules["slot_" .. index] = item.name
      namje_byos.set_stats(current_slot, {modules = ship_modules})

      if existing_module then
        local item = {name = existing_module, count = 1}
        player.setSwapSlotItem(item)
      else
        player.setSwapSlotItem(nil)
      end

      widget.setItemSlotItem(module_slots[index] .. ".slot", item)
    else
      pane.playSound("/sfx/interface/clickon_error.ogg", 0, 1.5)
      return
    end
  else
    if existing_module then
      local item = {name = existing_module, count = 1}
      player.setSwapSlotItem(item)
      ship_modules["slot_" .. index] = nil
      namje_byos.set_stats(current_slot, {modules = ship_modules})
      widget.setItemSlotItem(module_slots[index] .. ".slot", nil)
    end
  end
end

function confirm()
  local current_slot = player.getProperty("namje_current_ship", 1)
  local ship_stats = namje_byos.get_stats(current_slot)
  local ship_modules = ship_stats.modules
  local changes_made = false

  for k, v in pairs(ship_modules) do
    if before_changes[k] ~= v then
      changes_made = true
    end
  end

  for k, v in pairs(before_changes) do
    if ship_modules[k] ~= v then
      changes_made = true
    end
  end

  if changes_made then
    player.interact("ScriptPane", "/interface/scripted/namje_sailmodules/namje_refresh.config")
    pane.dismiss()
  else
    pane.dismiss()
  end
end