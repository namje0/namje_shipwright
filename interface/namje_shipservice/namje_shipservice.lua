require "/scripts/namje_byos.lua"
require "/scripts/namje_serialization/namje_shipValidator.lua"

local IMPORT_PRICES = {
  base = 10000,
  tile = 10,
  object_multiplier = 2.5,
  item_multiplier = 4,
  final_multiplier = 1.5
}
local CHANGE_PRICES = {
  name = {500, 0},
  icon = {250, 0},
  upgrade = {5000, 1}
}
local UPGRADE_CAP = 5
local UPGRADE_SCALING = {6, 5.5}
local MODULE_SLOT_LIST = "module_slots"
local MODULE_DISABLED_LIST = "disabled_mod_slots"
local INFO_AREA = {
  "lbl_ship_name",
  "tb_ship_name",
  "img_ship_name",
  "lbl_icon",
  "img_icon",
  "spin_count",
  "lbl_stats_1",
  "lbl_stats_2",
  "lbl_stats_1_num",
  "lbl_stats_2_num"
}
local STATS_AREA = {
  "lbl_stats_1",
  "lbl_stats_2",
  "lbl_stats_1_num",
  "lbl_stats_2_num"
}
local IMPORT_AREA = {
  "tb_import_code",
  "lbl_import_name",
  "tb_import_name",
  "img_import_name",
  "lbl_import_status",
  "lbl_import_stats",
  "lbl_import_stats_num"
}
-- shift icons down a bit for imports to make room for code textbox
local IMPORT_SHIFTED = {
  "lbl_icon",
  "img_icon",
  "spin_count"
}
local UPG_BUTTONS = {
  "btn_upg_max_fuel",
  "btn_upg_fuel_efficiency",
  "btn_upg_ship_speed",
  "btn_upg_cargo_size",
  "btn_upg_crew_size",
  "btn_upg_modules"
}

local money_total = 0
local upg_total = 0
local confirm_checkout = false
local ship_changes = {}
local selected_ship = {
  slot = nil,
  ship_info = {},
  upgrades = {},
  ship_config = {}
}
--TODO: grab all icons in path instead of hardcoded presets
local icons
local icon_index = 1
local icon = "/namje_ships/ship_icons/generic_1.png"
local module_slots = {}
local importing = false
local decoded_ship = {}
local default_positions = {}
local code_ship_stats = nil
local awaiting_import = false
local import_price = 0
-- the empty slot being imported into
local import_slot = nil

spin_count = {}
spin_count.up = function()
  icon_index = (icon_index % #icons) + 1
  icon = icons[icon_index]
  widget.setImage("img_icon", icon)
  if selected_ship.ship_info then
    ship_changes["icon"] = icons[icon_index]
  end
end
spin_count.down = function()
  icon_index = (icon_index - 1 - 1 + #icons) % #icons + 1
  icon = icons[icon_index]
  widget.setImage("img_icon", icon)
  if selected_ship.ship_info then
    ship_changes["icon"] = icons[icon_index]
  end
end

local function get_item_price(name, parameters)
  local success, item_config = pcall(root.itemConfig, {name = name, count = 1, parameters = parameters or {}})
  if not success or not item_config then
    return 0
  end
  return (parameters and parameters.price) or item_config.parameters.price or item_config.config.price or 0
end

local function count_tiles(runs)
  local count = 0
  for _, entry in ipairs(runs or {}) do
    local length, id = namje_binarySerializer.unpack_tile(type(entry) == "table" and entry[2] or entry)
    if id ~= 0 then
      count = count + length
    end
  end
  return count
end

local function get_code_ship_stats(ship_data)
  local ship_table = namje_binarySerializer.unpack_ship_data(ship_data)
  local material_cache = ship_table[1]
  local stats = {tiles = 0, objects = 0, objectvalue = 0, containeritems = {}}

  for _, chunk in ipairs(ship_table[2]) do
    local tiles = chunk.tiles or {}
    stats.tiles = stats.tiles + count_tiles(tiles.foreground) + count_tiles(tiles.background)

    for _, obj in ipairs(chunk.objs or {}) do
      local packed, params = obj, nil
      if type(obj) == "table" then
        packed, params = obj[1], obj[2]
      end
      local _, _, id = namje_binarySerializer.unpack_object(packed)
      local obj_name = material_cache[id]
      if obj_name then
        stats.objects = stats.objects + 1
        stats.objectvalue = stats.objectvalue + get_item_price(obj_name)
      end

      local container_items = params and params.namje_container_items
      if type(container_items) == "table" then
        for _, item in pairs(container_items) do
          if type(item) == "table" and item.name then
            local count = item.count or 1
            local entry = stats.containeritems[item.name] or {count = 0, value = 0}
            entry.count = entry.count + count
            entry.value = entry.value + get_item_price(item.name, item.parameters) * count
            stats.containeritems[item.name] = entry
          end
        end
      end
    end
  end

  return stats, ship_table
end

local function get_import_price(stats)
  local items_value = 0
  for _, item in pairs(stats.containeritems) do
    items_value = items_value + item.value
  end
  return math.floor(
    (
      IMPORT_PRICES.base 
      + stats.tiles * IMPORT_PRICES.tile 
      + stats.objectvalue * IMPORT_PRICES.object_multiplier 
      + items_value * IMPORT_PRICES.item_multiplier
    ) * IMPORT_PRICES.final_multiplier
  )
end

local function update_import_stats()
  if not code_ship_stats then
    widget.setText("lbl_import_stats_num", "^white;-\n-\n-")
    return
  end
  local item_count = 0
  for _, item in pairs(code_ship_stats.containeritems) do
    item_count = item_count + item.count
  end
  widget.setText("lbl_import_stats_num", string.format(
    "^white;%s\n%s\n%s",
    code_ship_stats.tiles,
    code_ship_stats.objects,
    item_count
  ))
end

local function toggle_imports(toggle)
  importing = toggle
  awaiting_import = false
  decoded_ship = {}
  code_ship_stats = nil
  import_price = 0
  widget.setButtonEnabled("btn_checkout", false)
  widget.setText("btn_checkout", importing and "IMPORT" or "CHECKOUT")
  widget.setText("lbl_ship_name", importing and "^gray;Code:" or "^gray;Name:")
  widget.setVisible("tb_ship_name", not importing)
  for i = 1, #IMPORT_AREA do
    widget.setVisible(IMPORT_AREA[i], importing)
  end
  for i = 1, #IMPORT_SHIFTED do
    local pos = default_positions[IMPORT_SHIFTED[i]]
    widget.setPosition(IMPORT_SHIFTED[i], importing and {pos[1], pos[2] - 14} or pos)
  end

  if importing then
    for i = 1, #INFO_AREA do
      widget.setVisible(INFO_AREA[i], INFO_AREA[i] ~= "tb_ship_name")
    end
    for i = 1, #STATS_AREA do
      widget.setVisible(STATS_AREA[i], false)
    end
    widget.setText("tb_import_code", "")
    widget.setText("tb_import_name", "")
    widget.setText("lbl_import_status", "")
    update_import_stats()
    icon_index = 1
    icon = icons[icon_index]
    widget.setImage("img_icon", icon)
  end
end

local function update_checkout()
  upg_total = 0
  money_total = 0

  if importing then
    money_total = import_price
    local money_count = player.currency("money")
    widget.setText("lbl_ply_money", money_count < money_total and "^red;" .. money_total or money_total)
    widget.setText("lbl_ply_upgmod", 0)
    widget.setButtonEnabled("btn_checkout", code_ship_stats ~= nil and (player.isAdmin() or money_count >= money_total))
    return
  end

  if isEmpty(selected_ship.ship_info) then
    return
  end

  if ship_changes.icon then
    money_total = money_total + CHANGE_PRICES.icon[1]
  end
  if ship_changes.name then
    money_total = money_total + CHANGE_PRICES.name[1]
  end

  for i = 1, #UPG_BUTTONS do
    local upgrade_name, _ = string.match(UPG_BUTTONS[i], "btn_upg_(.+)")
    if ship_changes[upgrade_name] then
      for i = selected_ship.upgrades[upgrade_name] + 1, ship_changes[upgrade_name] do
        money_total = money_total + math.floor(CHANGE_PRICES["upgrade"][1] * math.exp((i - 1) * math.log(math.exp(1/4 * math.log(UPGRADE_SCALING[1])))))
        upg_total = upg_total + math.floor(CHANGE_PRICES["upgrade"][2] * math.exp((i - 1) * math.log(math.exp(1/4 * math.log(UPGRADE_SCALING[2])))))
      end
    end
  end

  local module_count = player.hasCountOfItem("upgrademodule")
  local money_count = player.currency("money")

  widget.setText("lbl_ply_money", money_count < money_total and "^red;" .. money_total or money_total)
  widget.setText("lbl_ply_upgmod", module_count < upg_total and "^red;" .. upg_total or upg_total)

  if upg_total == 0 and money_total == 0 then
    widget.setButtonEnabled("btn_checkout", false)
  else
    if player.isAdmin() then
      widget.setButtonEnabled("btn_checkout", true)
      return
    end
    if module_count >= upg_total and money_count >= money_total then
      widget.setButtonEnabled("btn_checkout", true)
    else
      widget.setButtonEnabled("btn_checkout", false)
    end
  end
end

local function toggle_shipstats(toggle)
  widget.setVisible("upg_screen_visible", not toggle)
  for i = 1, #UPG_BUTTONS do
    widget.setVisible(UPG_BUTTONS[i], toggle)
  end
end

local function toggle_info(toggle)
  for i = 1, #INFO_AREA do
    widget.setVisible(INFO_AREA[i], toggle)
  end
end

local function update_gui()
  for i = 1, #UPG_BUTTONS do
    if UPG_BUTTONS[i] == "btn_upg_crew_size" and namje_byos.is_fu() then
      widget.setButtonOverlayImage(UPG_BUTTONS[i], "/interface/namje_shipservice/upgradelocked.png")
    else
      widget.setButtonOverlayImage(UPG_BUTTONS[i], "/interface/namje_shipservice/".. UPG_BUTTONS[i] ..".png")
    end
  end
end

local function update_info_stats(ship_config, ship_upgrades)
  local stats = {
    fuel_efficiency = nil,
    max_fuel = nil,
    ship_speed = nil,
    crew_size = nil,
    cargo_size = nil,
    modules = nil
  }

  for k, v in pairs(ship_upgrades) do
    if v > 0 then
      stats[k] = "^orange;" .. (k == "fuel_efficiency" and math.floor(ship_config.stat_upgrades[k][v].stat*100) or k == "modules" and v or ship_config.stat_upgrades[k][v].stat)
    end
  end

  for k, v in pairs(ship_changes) do
    if k ~= "icon" and k ~= "name" then
      if v > 0 then
        if k == "fuel_efficiency" then
          stats[k] = "^yellow;" .. math.floor(ship_config.stat_upgrades[k][v].stat*100)
        elseif k == "modules" then
          stats[k] = "^yellow;" .. v
        else
          stats[k] = "^yellow;" .. ship_config.stat_upgrades[k][v].stat
        end
      end
    end
  end

  local stats_1 = string.format(
    "^white;%s%%\n%s\n%s", 
    stats.fuel_efficiency or "^white;" .. math.floor(ship_config.base_stats.fuel_efficiency*100),
    stats.max_fuel or "^white;" .. ship_config.base_stats.max_fuel,
    stats.ship_speed or "^white;" .. ship_config.base_stats.ship_speed
  )
  local stats_2 = string.format(
    "^white;%s\n%s\n%s", 
    stats.crew_size or "^white;" .. ship_config.base_stats.crew_size, 
    stats.cargo_size or "^white;" .. ship_config.namje_stats.cargo_size, 
    stats.modules or "^white;0"
  )
  widget.setText("lbl_stats_1_num", stats_1)
  widget.setText("lbl_stats_2_num", stats_2)
end

local function is_equipped_slot(slot_num)
  return tonumber(slot_num) == tonumber(player.getProperty("namje_current_ship", 1))
end

local function update_salvage_button()
  local ship_info = selected_ship.ship_info
  local can_salvage = selected_ship.slot ~= nil and not isEmpty(ship_info) and not ship_info.favorited and not is_equipped_slot(selected_ship.slot)
  widget.setButtonEnabled("btn_salvage", can_salvage)
end

local function reset_slot(slot_num)
  local ship_info = namje_byos.get_ship_info(slot_num)
  if not ship_info then
    selected_ship = {
      slot = nil,
      ship_info = {},
      upgrades = {},
      ship_config = {}
    }
    update_salvage_button()
    return false
  end
  local ship_upgrades = namje_byos.get_upgrades(slot_num)

  toggle_info(true)
  toggle_shipstats(true)
  local ship_id = ship_info.ship_id
  local ship_config = namje_byos.get_ship_config(ship_id)

  selected_ship = {
    slot = slot_num,
    ship_info = ship_info,
    upgrades = ship_upgrades,
    ship_config = ship_config
  }
  update_salvage_button()

  for k, v in pairs(ship_upgrades) do
    local upgrade = selected_ship.ship_config.stat_upgrades[k]
    local upgrade_cap = type(upgrade)=="number" and upgrade or #upgrade
    if k == "modules" then
      add_module_slots(v)
    else
      widget.setImage("bar_" .. k, "/interface/namje_shipservice/stat_" .. v .. ".png")
      widget.setImage("cap_" .. k, "/interface/namje_shipservice/cap_" .. UPGRADE_CAP - upgrade_cap .. ".png")
    end
  end

  update_info_stats(ship_config, ship_upgrades)

  widget.setText("tb_ship_name", ship_info.name)
  widget.setText("lbl_upg_info", "Select an upgrade to view its benefits")
  icon_index = 1
  for i = 1, #icons do
    if icons[i] == ship_info.icon then
      icon_index = i
    end
  end
  widget.setImage("img_icon", ship_info.icon)

  return true
end

function init()
  if namje_byos.is_on_ship() then
    interface.queueMessage("^yellow;Technician unavailable on ships.")
    pane.dismiss()
    return
  end

  icons = root.assetJson("/namje_ships/ship_icons/icons.config").ship_icons
  for i = 1, #IMPORT_SHIFTED do
    default_positions[IMPORT_SHIFTED[i]] = widget.getPosition(IMPORT_SHIFTED[i])
  end
  populate_ship_list()
  toggle_info(false)
  widget.setButtonEnabled("btn_checkout", false)
  widget.setButtonEnabled("btn_salvage", false)
  toggle_shipstats(false)

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
end

function module_slot(index)
  local ship_stats = namje_byos.get_stats(selected_ship.slot)
  local ship_modules = ship_stats.modules
  local existing_module = ship_modules["slot_" .. index]
  local item = player.swapSlotItem()
  if item then
    local config = root.itemConfig(item.name).config
    if config.isNamjeModule then
      if not selected_ship.slot then
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
      namje_byos.set_stats(selected_ship.slot, {modules = ship_modules})

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
      namje_byos.set_stats(selected_ship.slot, {modules = ship_modules})
      widget.setItemSlotItem(module_slots[index] .. ".slot", nil)
    end
  end
end

local function finish_import()
  local slot = import_slot
  import_slot = nil
  populate_ship_list()
  reset_slot(slot)
  toggle_imports(false)
  widget.setButtonEnabled("btn_checkout", true)
  widget.setText("btn_checkout", "CHECKOUT")
end

function update(dt)
  if awaiting_import and import_slot and namje_byos.get_ship_info(import_slot) then
    finish_import()
  end
  update_checkout()
  update_gui()
end


function createTooltip(screen_pos)
  for i = 1, #UPG_BUTTONS do
    if widget.inMember(UPG_BUTTONS[i], screen_pos) then
      local config = selected_ship.ship_config
      if not config then
        return
      end
      local upgrades = config.stat_upgrades
      local upgrade_name, _ = string.match(UPG_BUTTONS[i], "btn_upg_(.+)")

      if upgrade_name == "crew_size" and namje_byos.is_fu() then
        widget.setText("lbl_upg_info", "^yellow;FU detected^reset; - Use crew beds for crew capacity.")
        return
      end

      if upgrade_name == "modules" then
        local level = math.min(math.max((ship_changes[upgrade_name] or selected_ship.upgrades[upgrade_name]) + 1, 1), upgrades.modules + 1)
        local desc = level > upgrades.modules and "Stat fully upgraded." or string.format("Increases the number of module slots to %s", level)
        widget.setText("lbl_upg_info", desc)
        return
      end

      local upgrade = upgrades[upgrade_name]
      local upgrade_cap = #upgrade
      local level = math.min(math.max((ship_changes[upgrade_name] or selected_ship.upgrades[upgrade_name]) + 1, 1), upgrade_cap + 1)
      local desc = upgrade_cap == 0 and "No upgrades for this stat." or level > upgrade_cap and "Stat fully upgraded." or upgrade[level].description
      widget.setText("lbl_upg_info", desc)

      return
    end
  end
  widget.setText("lbl_upg_info", "Select an upgrade to view its benefits")
end

function populate_ship_list()
  local player_ships = namje_byos.get_ship_data()
  local scroll_area = "slot_list.slot_item_list"
  widget.clearListItems(scroll_area)

  --table order gets messed up, sort it
  local sorted_slots = {}
  for slot_name, _ in pairs(player_ships) do
      local slot_number = tonumber(slot_name:match("slot_(%d+)"))
      if slot_number then
          table.insert(sorted_slots, slot_name)
      end
  end

  table.sort(sorted_slots, function(a, b)
    local num_a = tonumber(a:match("slot_(%d+)"))
    local num_b = tonumber(b:match("slot_(%d+)"))
    return num_a < num_b
  end)

  for i, slot in ipairs(sorted_slots) do
    local ship = player_ships[slot]
    if ship then
      local ship_info = ship.ship_info
      local ship_config = ship_info and namje_byos.get_ship_config(ship_info.ship_id) or nil
      local list_item = scroll_area.."."..widget.addListItem(scroll_area)
      widget.setText(list_item..".name", ship_info and ship_info.name .. (ship_info.favorited and " " or "") or "Empty Slot")
      widget.setText(list_item..".model", ship_config and ship_config.name or "")
      widget.setImage(list_item..".icon", ship_info and ship_info.icon or "")
      widget.setData(list_item, {slot})
    end
  end
end

function select_slot()
  local selected_slot = widget.getListSelected("slot_list.slot_item_list")
  if not selected_slot then
    return 
  end
  local data = widget.getData("slot_list.slot_item_list." .. selected_slot)
  if not data then
    return
  end

  toggle_shipstats(false)
  widget.setText("lbl_upg_info", "Select an upgrade to view its benefits")
  widget.setText("btn_checkout", "CHECKOUT")
  confirm_checkout = false
  ship_changes = {}

  local ship_slot = data[1]
  local slot_num = tonumber(ship_slot:match("slot_(%d+)"))

  if not reset_slot(slot_num) then
    import_slot = slot_num
    toggle_imports(true)
  else
    import_slot = nil
    toggle_imports(false)
    widget.setButtonEnabled("btn_checkout", true)
    widget.setText("btn_checkout", "CHECKOUT")
  end
end

function tb_ship_name()
  --TODO: add revert button
  local text = widget.getText("tb_ship_name")
  if selected_ship.ship_info then
    if text == selected_ship.ship_info.name then
      ship_changes["name"] = nil
    else
      ship_changes["name"] = text
    end
  end
end

function tb_import_code()
  decoded_ship = {}
  code_ship_stats = nil
  import_price = 0
  confirm_checkout = false

  widget.setText("btn_checkout", "IMPORT")
  local code = widget.getText("tb_import_code"):gsub("%s", "")
  if #code == 0 then
    widget.setText("lbl_import_status", "")
    update_import_stats()
    return
  end

  local regions, data = namje_shipCode.decode_ship_code(code)
  if regions and data then
    local success, stats, ship_table = pcall(get_code_ship_stats, data)
    if success and stats.tiles > 0 then
      decoded_ship = {regions = regions, data = data, code = code, ship_table = ship_table}
      code_ship_stats = stats
      import_price = get_import_price(stats)
    elseif not success then
      sb.logInfo("namje // failed to read imported ship data: %s", stats)
    end
  end

  widget.setText("lbl_import_status", code_ship_stats and "^green;Ship valid" or "^red;Invalid ship code")
  update_import_stats()
end

function tb_revert()
  local text = widget.getText("tb_ship_name")
  if #text <= 0 then
    if selected_ship.ship_info then
      widget.setText("tb_ship_name", selected_ship.ship_info.name)
    end
  end
end

function add_module_slots(level)
  if not selected_ship.upgrades and not selected_ship.upgrades.modules then
    return
  end
  local ship_stats = namje_byos.get_stats(selected_ship.slot)
  local ship_modules = ship_stats.modules

  widget.clearListItems(MODULE_SLOT_LIST)
  widget.clearListItems(MODULE_DISABLED_LIST)
  for i = 1, level do
    module_slots[i] = MODULE_SLOT_LIST.."."..widget.addListItem(MODULE_SLOT_LIST)
    local disabled_slot = MODULE_DISABLED_LIST.."."..widget.addListItem(MODULE_DISABLED_LIST)

    widget.setData(module_slots[i] .. ".slot", i)
    if i > selected_ship.upgrades.modules then
      widget.setVisible(disabled_slot .. ".slot", true)
      widget.setVisible(module_slots[i] .. ".slot", false)
    end
  end

  for k, v in pairs(ship_modules) do
    local slot_number = tonumber(k:match("slot_(%d+)"))
    if v then
      local item = {name = v, count = 1}
      widget.setItemSlotItem(module_slots[slot_number] .. ".slot", item)
    end
  end
end

function select_upgrade(button_name)
  local upgrade_name, _ = string.match(button_name, "btn_upg_(.+)")
  if isEmpty(selected_ship.upgrades) then
    return
  end

  local upgrade = selected_ship.ship_config.stat_upgrades[upgrade_name]
  local upgrade_cap = type(upgrade)=="number" and math.min(5, upgrade) or #upgrade

  if upgrade_name == "crew_size" and namje_byos.is_fu() then
    pane.playSound("/sfx/interface/clickon_error.ogg", 0, 1.5)
    return
  end

  if selected_ship.upgrades[upgrade_name] >= upgrade_cap then
    pane.playSound("/sfx/interface/clickon_error.ogg", 0, 1.5)
    return
  end

  if confirm_checkout then
    confirm_checkout = false
    widget.setText("btn_checkout", "CHECKOUT")
  end

  if not ship_changes[upgrade_name] then
    local level = selected_ship.upgrades[upgrade_name] + 1
    ship_changes[upgrade_name] = level
    widget.setImage("bar_" .. upgrade_name, "/interface/namje_shipservice/stat_" .. level .. ".png")
    if upgrade_name == "modules" then
      add_module_slots(level)
    end
  else
    local level = (ship_changes[upgrade_name] + 1) > upgrade_cap and -1 or ship_changes[upgrade_name] + 1
    if level == -1 then
      ship_changes[upgrade_name] = nil
      widget.setImage("bar_" .. upgrade_name, "/interface/namje_shipservice/stat_" .. selected_ship.upgrades[upgrade_name] .. ".png")
      if upgrade_name == "modules" then
        add_module_slots(selected_ship.upgrades[upgrade_name])
      end
    else
      ship_changes[upgrade_name] = level
      widget.setImage("bar_" .. upgrade_name, "/interface/namje_shipservice/stat_" .. level .. ".png")
      if upgrade_name == "modules" then
        add_module_slots(level)
      end
    end
  end

  update_info_stats(selected_ship.ship_config, selected_ship.upgrades)
end

function checkout()
  if importing then
    if isEmpty(decoded_ship) or not code_ship_stats or not import_slot then
      return
    end
    import_ship()
    return
  end

  if not confirm_checkout then
    confirm_checkout = true
    widget.setText("btn_checkout", "CONFIRM")
    return
  end

  local module_count = player.hasCountOfItem("upgrademodule")
  local money_count = player.currency("money")

  if module_count < upg_total and not player.isAdmin() or money_count < money_total and not player.isAdmin() then
    sb.logInfo("namje // not enough modules or money to checkout")
    return
  end

  if player.isAdmin() then
    upg_total = 0
    money_total = 0
  end

  if player.consumeItem({name = "upgrademodule", count = upg_total}) and player.consumeCurrency("money", money_total) then
    upg_total = 0
    money_total = 0

    if ship_changes.icon then
      ship_changes.icon = icons[icon_index]
    end

    namje_byos.set_upgrades(selected_ship.slot, ship_changes)
    namje_byos.set_ship_info(selected_ship.slot, ship_changes)
    ship_changes = {}
    widget.setText("btn_checkout", "CHECKOUT")
    confirm_checkout = false

    populate_ship_list()
    local cinematic = "/cinematics/upgrading/shipupgrade.cinematic"
    player.playCinematic(cinematic)

    reset_slot(selected_ship.slot)
  end
end

function salvage_ship()
  local slot = selected_ship.slot
  if not slot or isEmpty(selected_ship.ship_info) then
    return
  end
  if is_equipped_slot(slot) then
    sb.logInfo("namje // tried to salvage the equipped ship slot %s", slot)
    widget.setButtonEnabled("btn_salvage", false)
    pane.playSound("/sfx/interface/clickon_error.ogg", 0, 1.5)
    return
  end

  local salvage_pane = root.assetJson("/interface/namje_salvage/namje_salvage.config")
  salvage_pane.slot = slot
  player.interact("ScriptPane", salvage_pane, pane.sourceEntity())
  pane.dismiss()
end

function import_ship()
  local name = widget.getText("tb_import_name")

  if not confirm_checkout then
    -- mod incompat
    local invalid_ids = namje_shipValidator.get_invalid_ids(decoded_ship.ship_table)
    if namje_shipValidator.has_invalid_ids(invalid_ids) then
      local invalid_pane = root.assetJson("/interface/namje_invalidids/namje_invalidids.config")
      invalid_pane.invalid_ids = invalid_ids
      invalid_pane.import = {slot = import_slot, code = decoded_ship.code, name = name, icon = icon, price = import_price}
      player.interact("ScriptPane", invalid_pane)
      awaiting_import = true
      return
    end
    confirm_checkout = true
    widget.setText("btn_checkout", "CONFIRM")
    return
  end
  confirm_checkout = false
  widget.setText("btn_checkout", "IMPORT")

  if namje_byos.import_ship(import_slot, decoded_ship.code, name, icon, import_price) then
    finish_import()
  end
end
