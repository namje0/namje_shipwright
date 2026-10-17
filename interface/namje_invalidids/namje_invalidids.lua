require "/scripts/namje_byos.lua"

local ID_TYPES = {
  {key = "tiles", label = "Tile"},
  {key = "mods", label = "Tile mod"},
  {key = "objects", label = "Object"}
}

function init()
  populate_id_list(config.getParameter("invalid_ids", {}))
end

function populate_id_list(invalid_ids)
  local list = "id_list.id_item_list"
  widget.clearListItems(list)

  for _, id_type in ipairs(ID_TYPES) do
    local ids = invalid_ids[id_type.key] or {}

    local sorted_names = {}
    for name, _ in pairs(ids) do
      table.insert(sorted_names, name)
    end
    table.sort(sorted_names)

    for _, name in ipairs(sorted_names) do
      local list_item = list .. "." .. widget.addListItem(list)
      widget.setText(list_item .. ".name", name)
      widget.setText(list_item .. ".type", string.format("%s x%s - %s", id_type.label, ids[name], id_type.key == "tiles" and "^yellow;will be replaced with dirt" or "^red;will be skipped"))
    end
  end
end

function ok()
  local import = config.getParameter("import")
  if import then
    namje_byos.import_ship(import.slot, import.code, import.name, import.icon, import.price)
  end
  pane.dismiss()
end

function cancel()
  pane.dismiss()
end
