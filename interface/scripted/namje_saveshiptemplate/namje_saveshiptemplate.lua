require "/scripts/namje_byos.lua"

local exclude_npcs = true
local exclude_mons = true
local exclude_items = true

function init()
  local hideExpansionSlots = config.getParameter("hideExpansionSlots")
  widget.setChecked("btnHideExpansionSlots", hideExpansionSlots)
end

function confirm()
  if not namje_byos.is_on_own_ship() then
    return
  end

  local excludes = {
    npcs = exclude_npcs and true or nil,
    monsters = exclude_mons and true or nil,
    container_items = exclude_items and true or nil,
  }

  world.spawnStagehand({1024, 1024}, "namje_saveShip_stagehand")
  local current_slot = player.getProperty("namje_current_ship", 1)
  world.sendEntityMessage("namje_saveShip_stagehand", "namje_save_ship", player.id(), current_slot, 2, excludes)
  pane.dismiss()
end

function set_npcs(widgetName, widgetData)
  exclude_npcs = widget.getChecked(widgetName)
end

function set_mons(widgetName, widgetData)
  exclude_mons = widget.getChecked(widgetName)
end

function set_items(widgetName, widgetData)
  exclude_items = widget.getChecked(widgetName)
end