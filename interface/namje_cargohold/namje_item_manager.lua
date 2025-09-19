require "/scripts/namje_byos.lua"
require "/scripts/namje_util.lua"

--TODO: kind of spaghetti so refactor later

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
    self:update_capacity_text()
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
                self:set_item(slot, item, true)
            end
        end
    end
end

function namje_item_manager:items_match(index, item)
    if not item then
        return false
    end

    return root.itemDescriptorsMatch(self.cargo_content["slot_" .. index], item, true)
end

function namje_item_manager:get_max_stack(item)
    local default = 1000
    return item.parameters.maxStack or root.itemConfig(item).config.maxStack or default
end

function namje_item_manager:stack_items(index, new_count)
    if new_count <= 0 then
        self.cargo_content["slot_" .. index] = nil
        local slot = self.slots[index]
        if slot then
            widget.setItemSlotItem(slot.name .. ".slot", nil)
        end
        return
    end
    self.cargo_content["slot_" .. index].count = new_count
    local slot = self.slots[index]
    if slot then
        widget.setItemSlotItem(slot.name .. ".slot", self.cargo_content["slot_" .. index])
    end
end

function namje_item_manager:add_item(item)
    if not item or item.count <= 0 then
        return
    end
    local empty_slot_index = nil

    for i = 1, self.cargo_size do
        local slot_item = self:get_item(i)
        
        if slot_item and self:items_match(i, item) then
            local space_available = self:get_max_stack(item) - slot_item.count
            if space_available > 0 then
                local amount_to_add = math.min(item.count, space_available)
                local new_count = slot_item.count + amount_to_add
                
                self:stack_items(i, new_count)
                
                item.count = item.count - amount_to_add
                if item.count <= 0 then
                    self:update_stats()
                    return
                end
            end
        elseif not empty_slot_index and not slot_item then
            empty_slot_index = i
        end
    end

    if item.count > 0 and empty_slot_index then
        local item_to_add = {
            name = item.name,
            parameters = item.parameters,
            count = item.count
        }
        
        self.cargo_content["slot_" .. empty_slot_index] = item_to_add
        if self.slots[empty_slot_index] then
            self:set_item(self.slots[empty_slot_index], item_to_add, false)
            widget.setItemSlotItem(self.slots[empty_slot_index].name .. ".slot", item_to_add)
        end
        self:update_stats()
        return
    end
    
    self:update_stats()
    return item
end

function namje_item_manager:sort()
    --TODO: stack duplicate items
    local rarity_order = {
        ["common"] = 1,
        ["uncommon"] = 2,
        ["rare"] = 3,
        ["legendary"] = 4,
        ["essential"] = 5
    }

    local sorted_items = {}
    for i = 1, self.cargo_size do
        local slot_item = self:get_item(i)
        if slot_item then
            table.insert(sorted_items, slot_item)
        end
    end

    table.sort(sorted_items, function(a, b)
        local config_a = root.itemConfig(a)
        local config_b = root.itemConfig(b)
        local a_rarity = (a.parameters.rarity or config_a.config.rarity):lower() or "common"
        local b_rarity = (b.parameters.rarity or config_b.config.rarity):lower() or "common"
        if rarity_order[a_rarity] ~= rarity_order[b_rarity] then
            return rarity_order[a_rarity] > rarity_order[b_rarity]
        else
            local a_name = (a.parameters.itemName or config_a.config.itemName)
            local b_name = (b.parameters.itemName or config_b.config.itemName)
            return a_name < b_name
        end
    end)

    for i = 1, self.cargo_size do
        self.cargo_content["slot_" .. i] = sorted_items[i]
    end

    self:update_stats()
    self:populate_grid("")
end

function namje_item_manager:get_item(index)
    return self.cargo_content["slot_" .. index] or nil
end

function namje_item_manager:set_item(slot, item, init)
    local prev_item = self:get_item(slot.index)
    if prev_item then
        
    end

    widget.setItemSlotItem(slot.name .. ".slot", item)
    self.cargo_content["slot_" .. slot.index] = item

    if not init then
        self:update_stats()
    end
end

function namje_item_manager:lmb_slot(slot)
    if not self.cargo_content then
        return
    end
    local item = player.swapSlotItem()
    local slot_item = self.cargo_content["slot_" .. slot.index]
    local has_matching = self:items_match(slot.index, item)

    if slot_item then
        if shift_held() then
            self:set_item(slot, nil, false)
            player.giveItem(slot_item)
            return
        end

        if has_matching then
            local space_available = self:get_max_stack(item) - slot_item.count
            if space_available <= 0 then
                return
            end
            local amount_to_add = math.min(item.count, space_available)
            local new_count = slot_item.count + amount_to_add
            
            self:stack_items(slot.index, new_count)
            
            local new_item = {
                name = item.name,
                parameters = item.parameters,
                count = item.count - amount_to_add
            }

            if new_item.count <= 0 then
                player.setSwapSlotItem(nil)
                self:update_stats()
                return
            end
            player.setSwapSlotItem(new_item)
            return
        end
    end

    self:set_item(slot, item or nil, false)
    player.setSwapSlotItem(slot_item or nil)
end

function namje_item_manager:rmb_slot(slot)
    if not self.cargo_content then
        return
    end
    local item = player.swapSlotItem()
    local slot_item = self.cargo_content["slot_" .. slot.index]

    if slot_item then
        local has_matching = self:items_match(slot.index, item)
        if item and not has_matching then
            return
        end
        if item and item.count >= self:get_max_stack(item) then
            return
        end

        local count = slot_item.count
        local items_to_move = shift_held() and (count == 1 and 1 or math.floor(count / 2)) or 1
        local new_item = {
            name = slot_item.name,
            parameters = slot_item.parameters,
            count = has_matching and item.count + items_to_move or items_to_move
        }
        self:stack_items(slot.index, count - items_to_move)
        player.setSwapSlotItem(new_item)
        self:update_stats()
        return
    end
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