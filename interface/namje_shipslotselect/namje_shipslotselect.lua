require "/scripts/namje_byos.lua"

function init()
  --local list_item = "scrollArea.bookmarkItemList."..widget.addListItem("scrollArea.bookmarkItemList")
  --local list_item2 = "scrollArea.bookmarkItemList."..widget.addListItem("scrollArea.bookmarkItemList")
  populate_ship_list()
  widget.setButtonEnabled("btn_register", false)
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
  local ship_list = player.getProperty("namje_ships", {})
  if not selected_slot then
    return 
  end
  local data = widget.getData("slot_list.slot_item_list." .. selected_slot)
  if not data then
      return
  end
  local slot = data[1]
  local ship_info = ship_list[slot].ship_info
  if ship_info then
    widget.setButtonEnabled("btn_register", not ship_info.favorited)
  else
    widget.setButtonEnabled("btn_register", true)
  end
end

function confirm_slot()
  local selected_slot = widget.getListSelected("slot_list.slot_item_list")
  local ship_list = player.getProperty("namje_ships", {})
  if not selected_slot then
    return 
  end
  local data = widget.getData("slot_list.slot_item_list." .. selected_slot)
  if not data then
      return
  end
  local slot = data[1]

  local register_pane
  if ship_list[slot].ship_info then
    register_pane = root.assetJson("/interface/namje_shipslotselect/namje_shipswapconfirm.config")
  else
    register_pane = root.assetJson("/interface/namje_shipslotselect/namje_registershipinfo.config")
  end
  register_pane.slot = slot
  player.interact("ScriptPane", register_pane, pane.sourceEntity())
end