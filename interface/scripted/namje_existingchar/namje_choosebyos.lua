require "/scripts/namje_byos.lua"

local upgrade_refunds = {
  [4] = 2,
  [5] = 6,
  [6] = 12,
  [7] = 20,
  [8] = 30,
}
local ship_configs = {

}
local available_ships = {
  "namje_asteroidship",
  "namje_shuttle",
  "namje_island",
  "namje_aomkellion"
}
local scroll_area = "ship_select.ship_list"
local current_template, ship_coroutine

function init()
  local ships = root.assetsByExtension("namjeship")
  for _, v in pairs(ships) do
    local config = root.assetJson(v)
    for _, k in pairs(available_ships) do
      if k == config.id then
        ship_configs[k] = config
      end
    end
  end
  populate_ship_list()
end

function update(dt)
  widget.setButtonEnabled("accept", current_template and true or false)
  if ship_coroutine then
    coroutine.resume(ship_coroutine)
  end
end

--TODO: detect fu_byos world property and is_fu, offer option to retain byos ship
function populate_ship_list()
  widget.clearListItems(scroll_area)

  for _, v in pairs(available_ships) do
    local list_item = scroll_area.."."..widget.addListItem(scroll_area)
    widget.setText(list_item..".item_name", ship_configs[v].name)
    widget.setData(list_item, {v})
  end
end

function select_ship()
  local selected_ship = widget.getListSelected(scroll_area)

  if not selected_ship then
      return
  end

  local ship_id = widget.getData(scroll_area .. "." .. selected_ship)[1]

  if not ship_id then
      return
  end

  current_template = ship_id
  local ship_config = ship_configs[ship_id]
  widget.setImage("ship_image", ship_config.preview)
  local stats_1 = string.format(
    "^white;%s%%\n%s\n%s", 
    "^white;" .. math.floor(ship_config.base_stats.fuel_efficiency*100),
    "^white;" .. ship_config.base_stats.max_fuel,
    "^white;" .. ship_config.base_stats.ship_speed
  )
  local stats_2 = string.format(
    "^white;%s\n%s\n%s", 
    "^white;" .. ship_config.base_stats.crew_size, 
    "^white;" .. ship_config.namje_stats.cargo_size, 
    "^white;0"
  )
  widget.setText("lbl_stats_1_num", stats_1)
  widget.setText("lbl_stats_2_num", stats_2)
end

function confirm()
  init_byos()
end

function init_byos()
  ship_coroutine = coroutine.create(function()
    local upgrades = player.shipUpgrades()
    player.giveItem({name = "upgrademodule", count = upgrade_refunds[math.min(8, upgrades.shipLevel)]})
    player.upgradeShip({shipLevel = 9})
    player.startQuest("namje_shipPassive")
    player.startQuest("namje_shipCache")
    if namje_byos.is_fu() then
      world.setProperty("fu_byos", true)
      player.startQuest("fu_shipupgrades")
    end
    util.wait(0.1)
    namje_byos.init_byos(current_template)
    pane.dismiss()
  end)
end

function menu()
  player.playCinematic("\n\n\n\n\n\n\n\n\n\n\nReturning to title screen.\n^yellow;If you would like to use your vanilla ship, uninstall namjeShipwright and relaunch\n\n\n\n\n\n\n\n\n\n\n")
  pane.dismiss()
end