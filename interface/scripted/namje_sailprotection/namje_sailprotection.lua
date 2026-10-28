require "/scripts/namje_byos.lua"

local TIMEOUT = 3

local pending = nil
local pending_time = 0

local function update_status()
  local enabled = namje_byos.is_ship_protected()
  widget.setText("lbl_status", "Tile Protection: " .. (enabled and "^green;ENABLED" or "^red;DISABLED"))
  widget.setButtonEnabled("toggle", pending == nil)
end

function init()
  if not namje_byos.is_on_own_ship() then
    interface.queueMessage("^yellow;You can only manage ship protection on ships you own.")
    pane.dismiss()
    return
  end
  update_status()
end

function update(dt)
  if pending ~= nil then
    pending_time = pending_time + dt
    if namje_byos.is_ship_protected() == pending or pending_time >= TIMEOUT then
      pending = nil
    end
  end
  update_status()
end

function toggle()
  if pending ~= nil or not namje_byos.is_on_own_ship() then
    return
  end
  if world.getProperty("namje_ship_loading", false) then
    interface.queueMessage("^yellow;Cannot change ship protection while the ship is loading")
    pane.playSound("/sfx/interface/clickon_error.ogg", 0, 1.5)
    return
  end

  pending = not namje_byos.is_ship_protected()
  pending_time = 0
  world.spawnStagehand({1024, 1024}, "namje_tileProtection_stagehand")
  world.sendEntityMessage("namje_tileProtection_stagehand", "namje_set_tile_protection", pending)
  update_status()
end
