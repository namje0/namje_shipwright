require "/scripts/namje_byos.lua"
require "/scripts/namje_util.lua"

namje_item_manager = {}
local mt = {__index = namje_item_manager}

function namje_item_manager.new(size, content, list)
    local new_grid = {}
    setmetatable(new_grid, mt)
    
    new_grid.cargo_size = size
    new_grid.cargo_content = content
    new_grid.list = list
    new_grid.slots = {}
    return new_grid
end

function namje_item_manager:populate_grid(filter)
    widget.clearListItems(self.list)

    local function create_callback(method_name)
        return function(_, index)
            local slot = self.slots[index]
            if slot then
                self[method_name](self, slot)
            end
        end
    end

    widget.registerMemberCallback(self.list, "slot", create_callback("lmb_slot"))
    widget.registerMemberCallback(self.list, "slot.right", create_callback("rmb_slot"))

    filter = string.lower(filter)
    local has_filter = filter ~= ""

    for i = 1, self.cargo_size do
        local item = self.cargo_content["slot_" .. i]
        local item_config = item and root.itemConfig(item) or nil
        local friendly_name = item_config and string.lower(item_config.config.shortdescription) or nil
        if not has_filter or (item and string.find(item.name, filter) or item and string.find(friendly_name, filter)) then
            local slot = {
                index = i
            }
            slot.slot = widget.addListItem(self.list)
            slot.name = self.list .. "." .. slot.slot
            self.slots[i] = slot
            widget.setData(slot.name .. ".slot", slot.index)

            if item then
                self:set_item(slot, item)
            end
        end
    end
end

function namje_item_manager:get_item(slot)
    return self.cargo_content["slot_" .. slot.index] or nil
end

function namje_item_manager:set_item(slot, item)
    local prev_item = self:get_item(slot)
    if prev_item then
        
    end

    widget.setItemSlotItem(slot.name .. ".slot", item)
    self.cargo_content["slot_" .. slot.index] = item

    local ship_slot = player.getProperty("namje_current_ship", 1)
    local ship_stats = namje_byos.get_stats(ship_slot)
    if not ship_stats then
        sb.logInfo("namje // no ship stats found for slot %s", ship_slot)
        return
    end

    local stats = namje_byos.set_stats(ship_slot, {["cargo_hold"] = namje_util.deep_copy(self.cargo_content)})
end

function namje_item_manager:lmb_slot(slot)
    local item = player.swapSlotItem()

    if not self.cargo_content then
        return
    end
    local slot_item = self.cargo_content["slot_" .. slot.index]

    self:set_item(slot, item or nil)
    player.setSwapSlotItem(slot_item or nil)
end

function namje_item_manager:rmb_slot(slot)
    sb.logInfo("rmb from %s", slot)
end