require "/scripts/namje_byos.lua"

local chosen_slot = 0

function init()
  --local list_item = "scrollArea.bookmarkItemList."..widget.addListItem("scrollArea.bookmarkItemList")
  --local list_item2 = "scrollArea.bookmarkItemList."..widget.addListItem("scrollArea.bookmarkItemList")
  populate_ship_list()
end

function populate_ship_list()
  local ship_list = player.getProperty("namje_ships", {})

  local scroll_area = "slot_list.slot_item_list"
  widget.clearListItems(scroll_area)

  for slot, ship in pairs(ship_list) do
    local ship_info = ship.ship_info
    local ship_config = ship_info and namje_byos.get_ship_config(ship_info.ship_id) or nil
    local list_item = scroll_area.."."..widget.addListItem(scroll_area)
    widget.setText(list_item..".name", ship_info and ship_info.stats.name or "Empty Slot")
    widget.setText(list_item..".model", ship_config and ship_config.name or "")
    widget.setImage(list_item..".icon", ship_info and ship_info.stats.icon or "")
    widget.setData(list_item, {slot})
  end
end

function select_slot()
  local selected_slot = widget.getListSelected("slot_list.slot_item_list")
  local data = widget.getData("slot_list.slot_item_list." .. selected_slot)
  if not data then
      return
  end
  local slot = data[1]
  sb.logInfo("Selected slot: %s", slot)
end

function confirm_slot()
  sb.logInfo("confirm")
end