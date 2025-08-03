require "/scripts/namje_byos.lua"

local CHANGE_PRICES = {
  name = {500, 0},
  icon = {250, 0},
  upgrade = {5000, 1}
}
local UPGRADE_CAP = 5
local UPGRADE_SCALING = {6, 5.5}
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
local UPG_BUTTONS = {
  "btn_upg_max_fuel",
  "btn_upg_fuel_efficiency",
  "btn_upg_ship_speed",
  "btn_upg_cargo_size",
  "btn_upg_crew_size"
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
local icon_path = "/namje_ships/ship_icons/generic_%s.png"
local icon_index = 1
local icon = "/namje_ships/ship_icons/generic_1.png"
local max_icons = 6

spin_count = {}
spin_count.up = function()
  icon_index = (icon_index % max_icons) + 1
  icon = string.format(icon_path, icon_index)
  widget.setImage("img_icon", icon)
  if selected_ship.ship_info then
    local icon_num = string.match(selected_ship.ship_info.icon, "/namje_ships/ship_icons/generic_(%d)%.png")
    if icon_index == tonumber(icon_num) then
      ship_changes["icon"] = nil
    else
      ship_changes["icon"] = icon_index
    end
  end
end
spin_count.down = function()
  icon_index = (icon_index - 1 - 1 + max_icons) % max_icons + 1
  icon = string.format(icon_path, icon_index)
  widget.setImage("img_icon", icon)
  if selected_ship.ship_info then
    local icon_num = string.match(selected_ship.ship_info.icon, "/namje_ships/ship_icons/generic_(%d)%.png")
    if icon_index == tonumber(icon_num) then
      ship_changes["icon"] = nil
    else
      ship_changes["icon"] = icon_index
    end
  end
end

local function update_checkout()
  --TODO: make checkout free for admins
  upg_total = 0
  money_total = 0

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
    widget.setButtonOverlayImage(UPG_BUTTONS[i], "/interface/namje_shipservice/".. UPG_BUTTONS[i] ..".png")
  end
end

local function update_info_stats(ship_config, ship_upgrades)
  local stats = {
    fuel_efficiency = nil,
    max_fuel = nil,
    ship_speed = nil,
    crew_size = nil,
    cargo_size = nil
  }

  for k, v in pairs(ship_upgrades) do
    if v > 0 then
      stats[k] = "^orange;" .. (k == "fuel_efficiency" and math.floor(ship_config.stat_upgrades[k][v].stat*100) or ship_config.stat_upgrades[k][v].stat)
    end
  end

  for k, v in pairs(ship_changes) do
    if k ~= "icon" and k ~= "name" then
      if v > 0 then
        if k == "fuel_efficiency" then
          stats[k] = "^yellow;" .. math.floor(ship_config.stat_upgrades[k][v].stat*100)
        else
          stats[k] = "^yellow;" .. ship_config.stat_upgrades[k][v].stat
        end
      end
    end
  end

  local stats_1 = string.format(
    "^white;%s%%\n%s\n%s", 
    stats["fuel_efficiency"] or "^white;" .. math.floor(ship_config.base_stats.fuel_efficiency*100),
    stats["max_fuel"] or "^white;" .. ship_config.base_stats.max_fuel,
    stats["ship_speed"] or "^white;" .. ship_config.base_stats.ship_speed
  )
  local stats_2 = string.format(
    "^white;%s\n%s", 
    stats["crew_size"] or "^white;" .. ship_config.base_stats.crew_size, 
    stats["cargo_size"] or "^white;" .. ship_config.atelier_stats.cargo_size
  )
  widget.setText("lbl_stats_1_num", stats_1)
  widget.setText("lbl_stats_2_num", stats_2)
end

local function reset_slot(slot_num)
  local ship_info = namje_byos.get_ship_info(slot_num)
  if not ship_info then
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

  for k, v in pairs(ship_upgrades) do
    widget.setImage("bar_" .. k, "/interface/namje_shipservice/stat_" .. v .. ".png")
  end

  update_info_stats(ship_config, ship_upgrades)

  widget.setText("tb_ship_name", ship_info.name)
  widget.setText("lbl_upg_info", "Select an upgrade to view its benefits")
  local icon_num = string.match(ship_info.icon, "/namje_ships/ship_icons/generic_(%d)%.png")
  widget.setImage("img_icon", ship_info.icon)
  icon_index = tonumber(icon_num)

  return true
end

function init()
    populate_ship_list()
    toggle_info(false)
    widget.setButtonEnabled("btn_checkout", false)
    toggle_shipstats(false)
end

function update(dt)
  update_checkout()
  update_gui()
end

function createTooltip(screen_pos)
  for i = 1, #UPG_BUTTONS do
    if widget.inMember(UPG_BUTTONS[i], screen_pos) then
      local upgrade_name, _ = string.match(UPG_BUTTONS[i], "btn_upg_(.+)")
      local config = selected_ship.ship_config
      if not config then
        return
      end

      local upgrades = config.stat_upgrades
      local upgrade = upgrades[upgrade_name]
      local level = math.min(math.max((ship_changes[upgrade_name] or selected_ship.upgrades[upgrade_name]) + 1, 1), UPGRADE_CAP + 1)
      local desc = level > UPGRADE_CAP and "Stat fully upgraded." or upgrade[level].description
      widget.setText("lbl_upg_info", desc)

      return
    end
  end
  widget.setText("lbl_upg_info", "Select an upgrade to view its benefits")
end

function populate_ship_list()
  local ship_list = player.getProperty("namje_ships", {})
  local scroll_area = "slot_list.slot_item_list"
  widget.clearListItems(scroll_area)

  --table order gets messed up, sort it
  local sorted_slots = {}
  for slot_name, _ in pairs(ship_list) do
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
    local ship = ship_list[slot]
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

  local player_ships = player.getProperty("namje_ships", {})
  --local ship_data = player_ships[ship_slot]
  if not reset_slot(slot_num) then
    toggle_info(false)
    widget.setButtonEnabled("btn_checkout", false)
  else
    widget.setButtonEnabled("btn_checkout", true)
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

function tb_revert()
  local text = widget.getText("tb_ship_name")
  if #text <= 0 then
    if selected_ship.ship_info then
      widget.setText("tb_ship_name", selected_ship.ship_info.name)
    end
  end
end

function select_upgrade(button_name)
  local upgrade_name, _ = string.match(button_name, "btn_upg_(.+)")
  if isEmpty(selected_ship.upgrades) then
    return
  end

  if selected_ship.upgrades[upgrade_name] >= UPGRADE_CAP then
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
  else
    local level = (ship_changes[upgrade_name] + 1) > UPGRADE_CAP and -1 or ship_changes[upgrade_name] + 1
    if level == -1 then
      ship_changes[upgrade_name] = nil
      widget.setImage("bar_" .. upgrade_name, "/interface/namje_shipservice/stat_" .. selected_ship.upgrades[upgrade_name] .. ".png")
    else
      ship_changes[upgrade_name] = level
      widget.setImage("bar_" .. upgrade_name, "/interface/namje_shipservice/stat_" .. level .. ".png")
    end
  end

  update_info_stats(selected_ship.ship_config, selected_ship.upgrades)
end

function checkout()
  if not confirm_checkout then
    confirm_checkout = true
    widget.setText("btn_checkout", "CONFIRM")
    return
  end

  local module_count = player.hasCountOfItem("upgrademodule")
  local money_count = player.currency("money")

  if module_count < upg_total or money_count < money_total then
    sb.logInfo("namje // not enough modules or money to checkout")
    return
  end

  sb.logInfo("checked out")
  if player.consumeItem({name = "upgrademodule", count = upg_total}) and player.consumeCurrency("money", money_total) then
    if ship_changes.icon then
      ship_changes.icon = string.format(icon_path, icon_index) 
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