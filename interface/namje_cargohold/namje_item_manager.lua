require "/scripts/namje_byos.lua"
require "/scripts/namje_util.lua"

namje_item_manager = {}
local mt = {__index = namje_item_manager}

local function shift_held()
    if not input then
        return nil
    end
    return input.key("LShift") or input.key("RShift") 
end

function namje_item_manager.new(size, content, list)
    local new_grid = {}
    setmetatable(new_grid, mt)
    
    new_grid.cargo_size = size
    new_grid.cargo_content = content
    new_grid.list = list
    new_grid.slots = {}
    new_grid.filter = ""
    return new_grid
end

function namje_item_manager:update_capacity_text()
    local amount = namje_util.dict_size(self.cargo_content)
    widget.setText("count", string.format("CAPACITY %s/%s", amount, self.cargo_size))
end

function namje_item_manager:update_stats()
    local ship_slot = player.getProperty("namje_current_ship", 1)
    local ship_stats = namje_byos.get_stats(ship_slot)
    if not ship_stats then
        sb.logInfo("namje // no ship stats found for slot %s", ship_slot)
        return
    end

    local stats = namje_byos.set_stats(ship_slot, {["cargo_hold"] = namje_util.deep_copy(self.cargo_content)})
    self:update_capacity_text()
end

function namje_item_manager:populate_grid(filter)
    self:give_excess()

    self.filter = filter
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

function namje_item_manager:items_match(index, item)
    if not item then
        return
    end

    return root.itemDescriptorsMatch(self.cargo_content["slot_" .. index], item, true)
end

function namje_item_manager:stack_items(index, item)
    if item and not self:items_match(index, item) then 
        return 
    end
    local item_count = self.cargo_content["slot_" .. index].count

    self.cargo_content["slot_" .. index].count = item_count + item.count
    local slot = self.slots[index]
    widget.setItemSlotItem(slot.name .. ".slot", self.cargo_content["slot_" .. index])
end

function namje_item_manager:add_item(item)
    local new_item
    if not item then
        return
    end

    for i = 1, self.cargo_size do
        local cargo_slot = self.cargo_content["slot_" .. i]
        if self:items_match(i, item) then
            local default_max_stack = 1000
            local max_stack = item.parameters.maxStack or root.itemConfig(item).config.maxStack or default_max_stack
            local slot_item = self:get_item(i)
            if item.count + slot_item.count < max_stack then
                self:stack_items(i, {name = item.name, parameters = item.parameters, count = item.count})
                self:update_stats()
                return
            elseif slot_item.count ~= max_stack then
                local remainder = (slot_item.count + item.count) % max_stack 

                item.count = item.count - remainder
                self:stack_items(i, {name = item.name, parameters = item.parameters, count = item.count})
                self:update_stats()

                if remainder <= 0 then
                    return
                end

                new_item = {name = item.name, parameters = item.parameters, count = remainder}
                self:add_item(new_item)
                return
            end
        end
    end
    for i = 1, self.cargo_size do
        local cargo_slot = self.cargo_content["slot_" .. i]
        if not cargo_slot then
            sb.logInfo("set into slot %s for %s", i, item)
            self.cargo_content["slot_" .. i] = {name = item.name, parameters = item.parameters, count = item.count}
            if self.slots[i] then
                self:set_item(self.slots[i], {name = item.name, parameters = item.parameters, count = item.count})
                widget.setItemSlotItem(self.slots[i].name .. ".slot", {name = item.name, parameters = item.parameters, count = item.count})
            end
            self:update_stats()
            return
        end
    end
    return new_item
end

function namje_item_manager:get_item(index)
    return self.cargo_content["slot_" .. index] or nil
end

function namje_item_manager:set_item(slot, item)
    local prev_item = self:get_item(slot.index)
    if prev_item then
        
    end

    widget.setItemSlotItem(slot.name .. ".slot", item)
    self.cargo_content["slot_" .. slot.index] = item

    self:update_stats()
end

function namje_item_manager:lmb_slot(slot)
    local item = player.swapSlotItem()
    if not self.cargo_content then
        return
    end
    local slot_item = self.cargo_content["slot_" .. slot.index]

    if slot_item and shift_held() then
        self:set_item(slot, nil)
        player.giveItem(slot_item)
        return
    end

    self:set_item(slot, item or nil)
    player.setSwapSlotItem(slot_item or nil)
end

function namje_item_manager:rmb_slot(slot)
    sb.logInfo("rmb from %s", slot)
end

function namje_item_manager:give_excess()
    local amount = namje_util.dict_size(self.cargo_content)
    if amount <= self.cargo_size then
        return
    end
    local items = {}
    
    for k, v in pairs(self.cargo_content) do
        local num = tonumber(k:match("slot_(%d+)"))
        if num > self.cargo_size then
            if v then
                table.insert(items, v)
                self.cargo_content[k] = nil
            end
        end
    end

    local cargo_box = {
        name = "namje_cargobox",
        parameters = {
            loot = items
        },
        amount = 1
    }
    player.giveItem(cargo_box)
    interface.queueMessage("Excess items have been given to you as ^orange;Leftover Cargo")
    self:update_stats()
end