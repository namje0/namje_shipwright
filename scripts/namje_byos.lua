--utility module for all ship related stuff

require "/scripts/vec2.lua"
require "/scripts/util.lua"
require "/scripts/rect.lua"
require "/scripts/messageutil.lua"
require "/scripts/namje_util.lua"

namje_byos = {}
namje_byos.current_ship = nil

--chunk size, for ship serialization purposes
local CHUNK_SIZE = 32
local VERSION_ID = "namjeShipwright"
--the upper limit of ships a player can have
--currently set to 1-3, as ship changing does not have wiring support yet. This will be changed on release to 5-8
local PLAYER_SHIP_CAP = 6

--- register a new ship for the player, overwriting/adding to a slot
--- @param slot number
--- @param ship_type string
--- @param name string
--- @param icon string
--- @return table
function namje_byos.register_new_ship(slot, ship_type, name, icon)
    if world.isServer() then
        error("namje_byos.register_new_ship // register_new_ship cannot be called on server")
    end

    local ship_config = namje_byos.get_ship_config(ship_type)
    local ships = player.getProperty("namje_ships")
    if not ships or not ship_config then
        error("namje_byos.register_new_ship // missing namje_ships property or namje_ship_config for " .. ship_type)
    end
    if ship_config.id ~= ship_type then
        error("namje_byos.register_new_ship // ship config does not match ship type " .. ship_type)
    end
    local ship_slot = ships["slot_" .. slot]
    if not ship_slot then
        error("namje_byos.register_new_ship // slot " .. slot .. " not found in namje_ships")
    end

    local old_stats, old_info
    if ship_slot.stats then
        old_stats = ship_slot.stats
    end
    if ship_slot.ship_info then
        old_info = ship_slot.ship_info
    end

    local ship_data = {
        ship_info = {
            ship_id = ship_config.id,
            name = name or "Unnamed Ship",
            icon = icon or "/namje_ships/ship_icons/generic_1.png",
            favorited = false
        },
        stats = {
            cached_regions = old_stats and old_stats.cached_regions or {},
            crew_amount = old_stats and old_stats.crew_amount or 0,
            cargo_hold = old_stats and old_stats.cargo_hold or {},
            fuel_amount = math.max(old_stats and old_stats.fuel_amount or 500, 500),
            celestial_pos = old_stats and old_stats.celestial_pos or {["system"] = celestial.currentSystem(), ["location"] = celestial.shipLocation()},
            modules = {}, -- return modules as items instead
        },
        upgrades = {
            fuel_efficiency = 0,
            max_fuel = 0,
            ship_speed = 0,
            crew_size = 0,
            cargo_size = 0,
            modules = 0,
        }
    }

    ships["slot_" .. slot] = ship_data

    player.setProperty("namje_ships", ships)
    if player.getProperty("namje_current_ship", 1) == slot then
        local intro = ship_config.id == "namje_startership" and true or false
        if not intro then
            local cinematic = "/cinematics/namje/shipswap.cinematic"
            player.playCinematic(cinematic)
        end
        local region_cache = world.getProperty("namje_region_cache", {})
        namje_byos.change_ships_from_config(ship_config.id, intro, region_cache)
    end

    --overwrite
    if old_info then
        local old_config = namje_byos.get_ship_config(old_info.ship_id)
        if not old_config then
            sb.logInfo("namje // error during overwrite: old ship config not found for " .. old_info.ship_id)
            return
        end

        local previous_ship_content = player.getProperty("namje_slot_" .. slot .. "_shipcontent", {})
        local items = {}

        if old_stats then
            local modules = old_stats.modules
            for _, v in pairs(modules) do
                local item = {name = v, count = 1}
                table.insert(items, item)
            end
        end

        if not isEmpty(previous_ship_content) then
            for _, chunk in pairs (previous_ship_content[2]) do
                if chunk.objs and not isEmpty(chunk.objs) then
                    for _, object in pairs (chunk.objs) do
                        if type(object) == "table" then
                            local object_extras = object[3]
                            if object_extras then
                                local container_items = object_extras.items or nil
                                if container_items then
                                    for slot, item in pairs (container_items) do
                                        table.insert(items, item)
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
        if not isEmpty(items) then
            interface.queueMessage("^orange;Items left on your ship have been packaged for you.")
            world.sendEntityMessage(player.id(), "namje_give_cargo", items)
        end
        --TODO: include upgrade levels in refund
        local refund = math.floor(old_config.price * 0.25) or 0
        interface.queueMessage("You were given ^orange;" .. refund .. "^reset; pixels for your old ship.")
        player.addCurrency("money", refund)
    end

    player.setProperty("namje_slot_" .. slot .. "_shipcontent", {})
    return ships["slot_" .. slot]
end

function namje_byos.swap_ships(new_slot)
    if world.isServer() then
        error("namje_byos.swap_ships // swap_ships cannot be called on server")
    end

    local current_slot = player.getProperty("namje_current_ship", 1)

    world.spawnStagehand({1024, 1024}, "namje_saveShip_stagehand")
    world.sendEntityMessage("namje_saveShip_stagehand", "namje_save_ship", player.id(), current_slot, 1, new_slot)
end

--- give the player num amount of ship slots, clamped to the PLAYER_SHIP_CAP. returns the adjusted ship slots table
--- @param num number
--- @return table
function namje_byos.add_ship_slots(num)
    local current_slots = player.getProperty("namje_ship_slots", 0)
    local ships = player.getProperty("namje_ships", {})

    local num_slots = math.min(current_slots + num, PLAYER_SHIP_CAP)
    player.setProperty("namje_ship_slots", num_slots)
    for i = 1, num_slots do
        local slot = "slot_" .. i
        if not ships[slot] then
            ships[slot] = {}
        end
    end
    player.setProperty("namje_ships", ships)
    player.setProperty("namje_slot_" .. num .. "_shipcontent", {})
    return ships
end

--- sets the current ship slot for the player
--- @param slot number
function namje_byos.set_current_ship(slot)
    local current_slots = player.getProperty("namje_ship_slots", 1)
    if slot > current_slots or slot < 1 then
        error("namje // tried to set current ship to slot " .. slot .. " but only " .. current_slots .. " slots are available")
    end
    return player.setProperty("namje_current_ship", slot)
end

--- returns the stats table for the ship in the given slot
--- @param slot number
--- @return table
function namje_byos.get_stats(slot)
    local ships = player.getProperty("namje_ships", {})
    if not ships or not ships["slot_" .. slot] then
        return nil
    end
    local ship = ships["slot_" .. slot]
    return ship.stats or nil
end

--- sets the stats for the given ship slot. stats should be a table with the keys matching the ship stats. returns the updated stats table or nil if the slot does not exist
--- @param slot number
--- @param stats table
--- @return table
function namje_byos.set_stats(slot, stats)
    local ship_stats = namje_byos.get_stats(slot)
    if not ship_stats then
        return nil
    end
    for stat, value in pairs(stats) do
        if ship_stats[stat] ~= nil then
            ship_stats[stat] = value
        end
    end
    local ships = player.getProperty("namje_ships", {})
    local ship = ships["slot_" .. slot]
    ship.stats = ship_stats
    player.setProperty("namje_ships", ships)
    return ship_stats
end

--- returns the upgrades table for the ship in the given slot
--- @param slot number
--- @return table
function namje_byos.get_upgrades(slot)
    local ships = player.getProperty("namje_ships", {})
    if not ships or not ships["slot_" .. slot] then
        return nil
    end
    local ship = ships["slot_" .. slot]
    return ship.upgrades or nil
end

--- sets the upgrades for the given ship slot. stats should be a table with the keys matching the ship upgrades. returns the updated upgrades table or nil if the slot does not exist
--- @param slot number
--- @param upgrades table
--- @return table
function namje_byos.set_upgrades(slot, upgrades)
    local ship_upgrades = namje_byos.get_upgrades(slot)
    if not ship_upgrades then
        return nil
    end
    for upgrade, value in pairs(upgrades) do
        if ship_upgrades[upgrade] ~= nil then
            ship_upgrades[upgrade] = value
        end
    end
    local ships = player.getProperty("namje_ships", {})
    local ship = ships["slot_" .. slot]
    ship.upgrades = ship_upgrades
    player.setProperty("namje_ships", ships)
    return ship_upgrades
end

--- returns the ship_info table for the ship in the given slot
--- @param slot number
--- @return table
function namje_byos.get_ship_info(slot)
    local ships = player.getProperty("namje_ships", {})
    if not ships or not ships["slot_" .. slot] then
        return nil
    end
    local ship = ships["slot_" .. slot]
    return ship.ship_info or nil
end

--- sets the ship_info for the given ship slot. ship_info should be a table with the keys matching the ship info. returns the updated ship_info table or nil if the slot does not exist
--- @param slot number
--- @param info table
--- @return table
function namje_byos.set_ship_info(slot, info)
    local ship_info = namje_byos.get_ship_info(slot)
    if not ship_info then
        return nil
    end
    for key, value in pairs(info) do
        if ship_info[key] ~= nil then
            ship_info[key] = value
        end
    end
    local ships = player.getProperty("namje_ships", {})
    local ship = ships["slot_" .. slot]
    ship.ship_info = ship_info
    player.setProperty("namje_ships", ships)
    return ship_info
end

--TODO: use region_cache instead
function namje_byos.despawn_ship_monsters()
    local entities = world.monsterQuery({0, 0}, {2048, 2048})
    for _, entity_id in ipairs(entities) do
        if entity_id > 0 then
            world.callScriptedEntity(entity_id, "monster.setDeathSound", nil)
            world.callScriptedEntity(entity_id, "monster.setDropPool", nil)
            world.callScriptedEntity(entity_id, "monster.setDeathParticleBurst", nil)
            world.callScriptedEntity(entity_id, "status.addEphemeralEffect", "monsterdespawn")
        end
    end
end

function namje_byos.move_all_to_ship_spawn()
    local players = world.players()
    for _, player in ipairs (players) do
        if namje_byos.is_fu() then
            world.sendEntityMessage(player, "fs_respawn")
        else
            world.sendEntityMessage(player, "namje_moveToShipSpawn")
        end
    end
    
    --TODO: use region_cache
    local ship_spawn = vec2.add(world.getProperty("namje_ship_spawn", {1024, 1024}), {0, 1})
    local entities = world.entityQuery({0, 0}, {2048, 2048}, {includedTypes = {"npc"}})
    for _, entity_id in ipairs(entities) do
        world.callScriptedEntity(entity_id, "mcontroller.setPosition", ship_spawn)
    end
end

function namje_byos.change_ships_from_config(ship_id, init, region)
    local ship_config = namje_byos.get_ship_config(ship_id)
    if not ship_config then
        error("namje // ship config not found for " .. ship_id)
    end
    if ship_config.id ~= ship_id then
        error("namje // ship config does not match ship type " .. ship_id)
    end
    --TODO: server is never used atm, but instead of ply argument do variable arg
    if world.isServer() then
        if not namje_byos.is_on_ship() then
            error("namje // tried to change ship on server while not on shipworld")
        end

        --world.spawnStagehand({1024, 1024}, "namje_shipFromConfig_stagehand")
        --world.sendEntityMessage("namje_shipFromConfig_stagehand", "namje_swap_ship", ply, ship_config, init)
    else
        --for the client, spawn the stagehand which will call this function on the server
        sb.logInfo("namje // changing ship using a save on client")

        if not namje_byos.is_on_own_ship() then
            error("namje // tried to change ship on client while player world id is not their ship world id")
        end
        if init then
            fill_shiplocker(player.species())
        end
        world.spawnStagehand({1024, 1024}, "namje_shipFromConfig_stagehand")
        world.sendEntityMessage("namje_shipFromConfig_stagehand", "namje_swap_ship", player.id(), ship_config, init, region)
    end
end

--- changes ship from a table, comprised of the ship_info and the serialized ship
--- @param ship table
function namje_byos.change_ships_from_table(ship, region)
    if isEmpty(ship) then
        error("namje // tried to change ship from save, but ship table is empty")
    end
    --TODO: server is never used atm, but instead of ply argument do variable arg
    if world.isServer() then
        if not namje_byos.is_on_ship() then
            error("namje // tried to change ship on server while not on shipworld")
        end

        world.spawnStagehand({1024, 1024}, "namje_shipFromSave_stagehand")
        world.sendEntityMessage("namje_shipFromSave_stagehand", "namje_swap_ship", player.id(), ship, region)
    else
        --for the client, spawn the stagehand which will call this function on the server
        sb.logInfo("namje // changing ship using a save on client")

        if not namje_byos.is_on_own_ship() then
            error("namje // tried to change ship on client while player world id is not their ship world id")
        end

        world.spawnStagehand({1024, 1024}, "namje_shipFromSave_stagehand")
        world.sendEntityMessage("namje_shipFromSave_stagehand", "namje_swap_ship", player.id(), ship, region)
    end
end

-- TODO: Duplicate objects being grabbed
function namje_byos.ship_to_table(...)
    if not world.isServer() then
        error("namje // saving ship to table is not supported on client")
    end

    local bit_range = 16
    local chunks
    local id_cache = {}
    local mat_to_id = {}
    local ship_chunks = {}
    local ship_wiring = {}
    local ship_liquids = {}
    local next_mat_id = 1

    local function get_cached_id(material_name)
        if not material_name or string.find(material_name, "metamaterial") then
            return nil
        end 

        if mat_to_id[material_name] then
            return mat_to_id[material_name]
        else
            local id = next_mat_id
            mat_to_id[material_name] = id
            id_cache[id] = material_name
            next_mat_id = next_mat_id + 1
            return id
        end
    end

    local function remove_duplicate_keys(table_1, table_2)
        local function find_in_table2(key_to_find, value_to_compare, search_table)
            for k, v in pairs(search_table) do
            if k == key_to_find and compare(v, value_to_compare) then
                return true
            end
            if type(v) == "table" then
                if find_in_table2(key_to_find, value_to_compare, v) then
                return true
                end
            end
            end
            return false
        end

        local keys_to_remove = {}

        for k, v in pairs(table_1) do
            if find_in_table2(k, v, table_2) then
            table.insert(keys_to_remove, k)
            end
        end

        for _, key in ipairs(keys_to_remove) do
            table_1[key] = nil
        end

        for k, v in pairs(table_1) do
            if type(v) == "table" then
            remove_duplicate_keys(v, table_2)
            end
        end

        return table_1
    end

    local function pack_pos(x, y)
        local packed_val1 = x
        local packed_val2 = y
        return packed_val1 | (packed_val2 << 11)
    end

    local function pack_wire(output_pos, output_node, input_pos, input_node)
        local output_x = output_pos[1] or 0
        local output_y = output_pos[2] or 0
        local output_node = output_node or 0
        local input_x = input_pos[1] or 0
        local input_y = input_pos[2] or 0
        local input_node = input_node or 0

        return (output_x) | (output_y << 11) | (output_node << 22) | (input_x << 26) | (input_y << 37) | (input_node << 48)
    end

    -- bit allocation: 14 bits, 10 bits, 4 bits, 4 bits
    -- total bits: 32
    local function pack_tile_vals(length, id, color, hue)
        local packed_length = length or 0
        local packed_id = id or 0
        local packed_color = color or 0
        local packed_hue = math.floor((hue or 0) + 0.5)
        return packed_length | (packed_id << 14) | (packed_color << 24) | (packed_hue << 28)
    end

    local function pack_liquid_vals(pos, id, level)
        local x = pos[1] or 0
        local y = pos[2] or 0
        local packed_id = id or 0
        local packed_level = math.floor((level or 0) * 1000000 + 0.5)
        return x | (y << 11) | (packed_id << 22) | (packed_level << 30)
    end
    
    -- bit allocation: 12 bits, 12 bits, 10 bits, 1 bits
    -- total bits: 35
    function pack_obj_vals(pos, id, direction)
        local x = pos[1] or 0
        local y = pos[2] or 0
        local packed_id = id or 0
        local packed_direction = direction or 0
        return x | (y << 12) | (packed_id << 24) | (packed_direction << 34)
    end

    local function process_run(current_id, current_color, current_hue, run_table, output_table, linear_pos)
        local is_same_color = (current_color == run_table.last_color)
        local is_same_hue = (current_hue == run_table.last_hue)
        local is_contiguous = run_table.last_pos == nil or linear_pos == run_table.last_pos + 1
        
        if current_id == run_table.last_id and is_same_color and is_same_hue and is_contiguous then
            run_table.length = run_table.length + 1
        else
            if run_table.start_pos then
                local packed_data = pack_tile_vals(run_table.length, run_table.last_id, run_table.last_color, run_table.last_hue)
                if run_table.is_first then
                    table.insert(output_table, {run_table.start_pos, packed_data})
                    run_table.is_first = false
                else
                    table.insert(output_table, packed_data)
                end
            end
            
            run_table.last_id = current_id
            run_table.last_color = current_color
            run_table.last_hue = current_hue
            run_table.start_pos = linear_pos
            run_table.length = 1
        end
        run_table.last_pos = linear_pos
    end

    local function finalize_run(run_table, output_table, chunk_width, total_tiles)
        local compacted_output = {}
        local empty_row_buffer = nil

        local function flush_empty_buffer()
            if empty_row_buffer then
                table.insert(compacted_output, empty_row_buffer)
                empty_row_buffer = nil
            end
        end

        if run_table.start_pos then
            local packed_data = pack_tile_vals(run_table.length, run_table.last_id, run_table.last_color, run_table.last_hue)
            if run_table.is_first then
                table.insert(output_table, {run_table.start_pos, packed_data})
            else
                table.insert(output_table, packed_data)
            end
        end

        -- remove tables with only empty spaces.
        if #output_table == 0 then return output_table end
        local empty_table = true
        for i = 1, #output_table do
            local entry = output_table[i]
            local data = (type(entry) == "table") and entry[2] or entry
            local length = data & 0x3FFF
            local id = (data >> 14) & 0x3FF
            if id ~= 0 then
                empty_table = false
            end
        end
        if empty_table then
            return {}
        end

        -- compact rows of empty spaces into one table
        for i = 1, #output_table do
            local entry = output_table[i]
            local data = (type(entry) == "table") and entry[2] or entry
            local length = data & 0x3FFF
            local id = (data >> 14) & 0x3FF

            if id == 0 and length == chunk_width then
                if not empty_row_buffer then
                    empty_row_buffer = entry
                else
                    local empty_row_data = (type(empty_row_buffer) == "table") and empty_row_buffer[2] or empty_row_buffer
                    local current_len = (empty_row_data & 0x3FFF)
                    local new_len = current_len + chunk_width
                    if type(empty_row_buffer) == "table" then
                        empty_row_buffer[2] = (empty_row_data & ~0x3FFF) | new_len
                    else
                        empty_row_buffer = (empty_row_data & ~0x3FFF) | new_len
                    end
                end
            else
                flush_empty_buffer()
                table.insert(compacted_output, entry)
            end
        end
        flush_empty_buffer()
        
        return compacted_output
    end

    local serialize_coroutine = coroutine.create(function()
        --get the cached bounds, then clear the area
        local region_cache = world.getProperty("namje_region_cache", {})
        local regions = {}
        local region_bounds
        if isEmpty(region_cache) then
            sb.logInfo("namje // region cache is empty, though it shouldn't be. using defaults")
            region_bounds = rect.fromVec2({974, 974}, {1074, 1074})
        else
            for region, _ in pairs(region_cache) do
                local chunk = namje_util.region_decode(region)
                table.insert(regions, chunk)
            end
            region_bounds = namje_util.get_chunk_rect(regions)
        end
        chunks = namje_util.get_filled_chunks(region_bounds)
        
        for _, chunk in ipairs (chunks) do
            local min_x = chunk.bottom_left[1]
            local max_x = chunk.top_right[1]
            local min_y = chunk.bottom_left[2]
            local max_y = chunk.top_right[2] 
            local chunk_width = max_x - min_x + 1
            local chunk_height = max_y - min_y + 1
            local total_tiles = chunk_width * chunk_height

            local foreground_tiles = {}
            local background_tiles = {}
            local objects = {}
            local monsters = {}
            local npcs = {}
            local foreground_mods = {}
            local background_mods = {}
            local fore_run = {
                last_id = nil,
                last_color = nil,
                last_hue = nil,
                start_pos = nil,
                length = 0,
                is_first = true,
                last_pos = nil
            }
            local back_run = {
                last_id = nil,
                last_color = nil,
                last_hue = nil,
                start_pos = nil,
                length = 0,
                is_first = true,
                last_pos = nil
            }
            local fore_mod_run = {
                last_id = nil,
                last_color = nil,
                last_hue = nil,
                start_pos = nil,
                length = 0,
                is_first = true,
                last_pos = nil
            }
            local back_mod_run = {
                last_id = nil,
                last_color = nil,
                last_hue = nil,
                start_pos = nil,
                length = 0,
                is_first = true,
                last_pos = nil
            }

            --process tiles
            for y = min_y, max_y do
                for x = min_x, max_x do
                    local liquid = world.liquidAt({x, y})
                    local foreground_material = world.material({x, y}, "foreground")
                    local background_material = world.material({x, y}, "background")
                    local fore_mod = world.mod({x, y}, "foreground")
                    local back_mod = world.mod({x, y}, "background")
                    local foreground_mat_id = get_cached_id(foreground_material)
                    local background_mat_id = get_cached_id(background_material)
                    local foreground_mod_id = get_cached_id(fore_mod)
                    local background_mod_id = get_cached_id(back_mod)

                    if liquid then
                        local packed_liquid = pack_liquid_vals({x, y}, liquid[1], liquid[2])
                        table.insert(ship_liquids, packed_liquid)
                    end

                    local linear_pos = (y << bit_range) | x
                    
                    local fore_color = foreground_mat_id and world.materialColor({x, y}, "foreground") or nil
                    local fore_hue = foreground_mat_id and world.materialHueShift({x, y}, "foreground") or nil
                    process_run(foreground_mat_id, fore_color, fore_hue, fore_run, foreground_tiles, linear_pos)
                    
                    local back_color = background_mat_id and world.materialColor({x, y}, "background") or nil
                    local back_hue = background_mat_id and world.materialHueShift({x, y}, "background") or nil
                    process_run(background_mat_id, back_color, back_hue, back_run, background_tiles, linear_pos)

                    local fore_mod_hue = foreground_mod_id and world.modHueShift({x, y}, "foreground") or nil
                    process_run(foreground_mod_id, nil, fore_mod_hue, fore_mod_run, foreground_mods, linear_pos)

                    local back_mod_hue = background_mod_id and world.modHueShift({x, y}, "background") or nil
                    process_run(background_mod_id, nil, back_mod_hue, back_mod_run, background_mods, linear_pos)
                end
            end

            foreground_tiles = finalize_run(fore_run, foreground_tiles, chunk_width, total_tiles)
            background_tiles = finalize_run(back_run, background_tiles, chunk_width, total_tiles)
            foreground_mods = finalize_run(fore_mod_run, foreground_mods, chunk_width, total_tiles)
            background_mods = finalize_run(back_mod_run, background_mods, chunk_width, total_tiles)

            -- process objects
            -- TODO: for some horrible reason, boundMode = position results in specifically 'wall objects' being excluded in the ship swap, even though its
            -- saying it placed. we'll just have to include the duplicate objects in the serialized ship for now.
            local chunk_objects = world.objectQuery({min_x, min_y}, {max_x, max_y})
            for i = 1, #chunk_objects do
                local object_extras = {}
                local object_id = chunk_objects[i]

                if object_id > 0 then
                    local pos = world.entityPosition(object_id)
                    local object_parameters = world.getObjectParameter(object_id,"")
                    local obj_name = object_parameters.objectName
                    local direction = world.callScriptedEntity(object_id, "object.direction") or 1
                    local packed_direction = (direction == 1) and 1 or 0
                    local packed_data = pack_obj_vals(pos, get_cached_id(obj_name), packed_direction)
                    local temp_obj_item = root.itemConfig(obj_name)
                    local old_parameters = temp_obj_item.config

                    local finalized_params = remove_duplicate_keys(object_parameters, old_parameters)

                    local object_upgrade_stage = world.callScriptedEntity(object_id, "currentStageData")
                    if object_upgrade_stage then
                        world.callScriptedEntity(object_id, "require", "/scripts/namje_entStorageGrabber.lua")
                        local current_stage = world.callScriptedEntity(object_id, "get_ent_storage", "currentStage")
                        finalized_params["startingUpgradeStage"] = current_stage or 0
                    end

                    if not exclude_items then
                        local container_items = world.containerItems(object_id)
                        if container_items and not isEmpty(container_items) then
                            object_extras["items"] = container_items
                        end
                    end

                    local farmable_stage = world.farmableStage(object_id)
                    if farmable_stage and farmable_stage > 0 then
                        finalized_params["startingStage"] = farmable_stage
                    end

                    if old_parameters.stages then
                        world.callScriptedEntity(object_id, "require", "/scripts/namje_entStorageGrabber.lua")
                        local durations = world.callScriptedEntity(object_id, "get_ent_storage", "durations")
                        local age = world.callScriptedEntity(object_id, "activeAge")
                        if age then
                            finalized_params["startingAge"] = age
                        end
                        if durations and not finalized_params["harvestable_durations"] then
                            finalized_params["harvestable_durations"] = durations
                        end
                    end

                    local output_nodes = world.callScriptedEntity(object_id, "object.outputNodeCount")
                    local input_nodes = world.callScriptedEntity(object_id, "object.inputNodeCount")
                    if output_nodes and output_nodes > 0 then
                        for i = 1, output_nodes do
                            local output_node = i - 1
                            if world.callScriptedEntity(object_id, "object.isOutputNodeConnected", output_node) then
                                local connected_ids = world.callScriptedEntity(object_id, "object.getOutputNodeIds", output_node)
                                if not isEmpty(connected_ids) then
                                    for connected_id, input_node in pairs(connected_ids) do
                                        local packed_wire = pack_wire(pos, output_node, world.entityPosition(connected_id), input_node)
                                        table.insert(ship_wiring, packed_wire)
                                    end
                                end
                            end
                        end
                    end

                    if input_nodes and input_nodes > 0 then
                        for i = 1, input_nodes do
                            local input_node = i - 1
                            if world.callScriptedEntity(object_id, "object.isInputNodeConnected", input_node) then
                                local connected_ids = world.callScriptedEntity(object_id, "object.getInputNodeIds", input_node)
                                if not isEmpty(connected_ids) then
                                    for connected_id, output_node in pairs(connected_ids) do
                                        local packed_wire = pack_wire(world.entityPosition(connected_id), output_node, pos, input_node)
                                        table.insert(ship_wiring, packed_wire)
                                    end
                                end
                            end
                        end
                    end

                    if input_nodes and input_nodes > 0 or output_nodes and output_nodes > 0 then
                        world.callScriptedEntity(object_id, "require", "/scripts/namje_entStorageGrabber.lua")
                        local current_state = world.callScriptedEntity(object_id, "get_ent_storage", "state")
                        object_extras["switch_state"] = current_state
                    end

                    local object_data = packed_data
                    if not isEmpty(finalized_params) then
                        object_data = {packed_data, finalized_params}
                    end

                    if not isEmpty(object_extras) then
                        if type(object_data) == table then
                            table.insert(object_data, object_extras)
                        else
                            object_data = {packed_data, {}, object_extras}
                        end
                    end

                    table.insert(objects, object_data)
                end
            end

            --process monsters
            local chunk_monsters = world.monsterQuery({min_x, min_y}, {max_x, max_y}, {boundMode  = "position"})
            for _, entity_id in ipairs (chunk_monsters) do
                if entity_id > 0 then
                    local duplicate_monster = false
                    local seed = world.callScriptedEntity(entity_id, "monster.seed")
                    local pos = world.callScriptedEntity(entity_id, "mcontroller.position")
                    local linear_pos = (math.floor(pos[2]) << bit_range) | math.floor(pos[1])
                    --[[
                        seems like mcontroller.pos is inbetween so its getting detected in multiple chunks, dont add if its a duplicate
                        not the most efficient way to check for duplicates cause I think there could be fringe scenarios where you have multiple cloned
                        animals in the exact same spot... but odds are low enough
                    ]]
                    for _, v in pairs(ship_chunks) do
                        if v.monsters then
                            for _, monster in pairs(v.monsters) do
                                local existing_seed = monster.parameters.seed
                                local existing_pos = monster.pos
                                if seed == existing_seed and existing_pos == linear_pos then
                                    duplicate_monster = true
                                end
                            end
                        end
                    end

                    if not duplicate_monster then
                        world.callScriptedEntity(entity_id, "require", "/scripts/namje_entStorageGrabber.lua")
                        local entity_storage = world.callScriptedEntity(entity_id, "get_ent_storage", "")
                        local monster_type = world.callScriptedEntity(entity_id, "monster.type")
                        local pet_info = {
                            type = get_cached_id(monster_type),
                            parameters = world.callScriptedEntity(entity_id, "monster.uniqueParameters"),
                            pos = linear_pos
                        }
                        pet_info.parameters.storage = entity_storage
                        pet_info.parameters.seed = seed

                        --remove redundant data
                        pet_info.parameters.storage["spawnPosition"] = nil
                        pet_info.parameters.storage["playSpawnAnimation"] = nil

                        table.insert(monsters, pet_info)
                    end
                end
            end

            --TODO: process npcs

            local ship_chunk = {pos = pack_pos(min_x, max_y), tiles = {foreground = foreground_tiles, background = background_tiles}, mods = {foreground = foreground_mods, background = background_mods}}
            if not isEmpty(objects) then
                ship_chunk["objs"] = objects
            end

            if not isEmpty(monsters) then
                ship_chunk["monsters"] = monsters
            end
            
            table.insert(ship_chunks, ship_chunk)
            coroutine.yield()
        end

        --remove duplicates from wiring table
        if not isEmpty(ship_wiring) then
            table.sort(ship_wiring)
            local w = 1
            while w < #ship_wiring do
                if ship_wiring[w] == ship_wiring[w + 1] then
                    table.remove(ship_wiring, w + 1)
                else
                    w = w + 1
                end
            end
        end

        return {id_cache, ship_chunks, ship_wiring, ship_liquids}
    end)
    return serialize_coroutine
end

function namje_byos.table_to_ship(ship_table, ship_region)
    if not world.isServer() then
        error("namje // loading ship from table is not supported on client")
    end

    --todo: probably move mat_cache and invalid_ids into coroutine
    local load_mat_cache = {}
    local invalid_ids = {}
    local id_cache = ship_table[1]
    local ship_chunks = ship_table[2]
    local bit_range = 16

    local function unpack_pos(packed_data)
        local x = packed_data % 2048 
        local y = math.floor(packed_data / 2048) 
        return {x, y}
    end

    local function unpack_wire(packed_data)
        local output_x = (packed_data) & 0x7FF
        local output_y = (packed_data >> 11) & 0x7FF
        local output_node = (packed_data >> 22) & 0xF
        local input_x = (packed_data >> 26) & 0x7FF
        local input_y = (packed_data >> 37) & 0x7FF
        local input_node = (packed_data >> 48) & 0xF
        
        return {output_x, output_y}, output_node, {input_x, input_y}, input_node
    end

    -- bit allocation: 14 bits, 10 bits, 4 bits, 4 bits
    -- total bits: 32
    local function unpack_tile_vals(packed_data)
        local length = packed_data & 0x3FFF
        local id = (packed_data >> 14) & 0x3FF
        local color = (packed_data >> 24) & 0xF
        local hue = (packed_data >> 28) & 0xF
        return length, id, color, hue
    end

    local function unpack_obj_vals(packed_data)
        local x = packed_data & 0xFFF
        local y = (packed_data >> 12) & 0xFFF
        local id = (packed_data >> 24) & 0x3FF
        local direction = (packed_data >> 34) & 1
        return {x, y}, id, direction
    end

    local function unpack_liquid_vals(packed_data)
        local x = packed_data & 0x7FF
        local y = (packed_data >> 11) & 0x7FF
        local id = (packed_data >> 22) & 0xFF
        local level = (packed_data >> 30) / 1000000
        return {x, y}, id, level
    end

    local function linear_to_pos(linear_pos)
        local x = linear_pos & ((1 << bit_range) - 1)
        local y = linear_pos >> bit_range
        return {tonumber(x), tonumber(y)}
    end

    local function place_tiles(tiles_data, layer_type, chunk_x)
        local current_pos_x, current_pos_y
        
        for i, entry in ipairs(tiles_data) do
            local start_pos, packed_data
            
            -- the first entry in the table is a pair {start_pos, packed_data}
            -- subsequent entries are just packed_data
            if type(entry) == "table" then
                start_pos = entry[1]
                packed_data = entry[2]
            else
                packed_data = entry
            end

            if start_pos then
                local pos = linear_to_pos(start_pos)
                current_pos_x = pos[1] 
                current_pos_y = pos[2]
            end
            
            local length, id, color, hue = unpack_tile_vals(packed_data)
            local material_name = id_cache[id]
            -- skip the loop and just advance the y position if its an empty run greater than CHUNK_SIZE
            -- empty runs greater than CHUNK_SIZE will always be divisible by the CHUNK_SIZE
            if id == 0 and material_name == nil and length > CHUNK_SIZE then
                local rows = (length / CHUNK_SIZE)
                current_pos_y = current_pos_y + rows
            else
                for i = 0, length - 1 do
                    if material_name then
                        if layer_type == "foreground" then
                            world.placeMaterial({current_pos_x + i, current_pos_y}, "foreground", material_name, hue, true)
                            if color and color > 0 then world.setMaterialColor({current_pos_x + i, current_pos_y}, "foreground", color) end
                        elseif layer_type == "background" then
                            world.replaceMaterials({{current_pos_x + i, current_pos_y}}, "background", material_name, hue, false)
                            if color and color > 0 then world.setMaterialColor({current_pos_x + i, current_pos_y}, "background", color) end
                        elseif layer_type == "foreground_mods" or layer_type == "background_mods" then
                            local mod_layer = layer_type == "foreground_mods" and "foreground" or "background"
                            world.placeMod({current_pos_x + i, current_pos_y}, mod_layer, material_name, hue, true)
                        end
                    end
                end
                current_pos_x = current_pos_x + length
                while current_pos_x >= chunk_x + CHUNK_SIZE do
                    current_pos_x = current_pos_x - CHUNK_SIZE
                    current_pos_y = current_pos_y + 1
                end
            end
        end
    end

    local deserialize_coroutine = coroutine.create(function()
        --get the cached bounds, then clear the area
        local regions = {}
        local region_bounds
        if isEmpty(ship_region) then
            sb.logInfo("namje // ship_region is empty, though it shouldn't be. using defaults")
            region_bounds = rect.fromVec2({974, 974}, {1074, 1074})
        else
            for region, _ in pairs(ship_region) do
                local chunk = namje_util.region_decode(region)
                table.insert(regions, chunk)
            end
            region_bounds = namje_util.get_chunk_rect(regions)
        end
        namje_byos.clear_ship_area(region_bounds)

        local total_object_count = 0
        local placed_objects = 0
        local failed_objects = {}

        for _, chunk in ipairs(ship_chunks) do
            -- process tiles
            -- due to how replacematerial works, we need to put an initial background wall using a dungeon. then we'll use replaceMaterial on that wall afterwards
            local unpacked_pos = unpack_pos(chunk.pos)
            local top_left_x = unpacked_pos[1]
            local top_left_y = unpacked_pos[2]
            world.placeDungeon("namje_temp_32", {top_left_x, top_left_y})

            place_tiles(chunk.tiles.foreground, "foreground", top_left_x)
            place_tiles(chunk.tiles.background, "background", top_left_x)
            place_tiles(chunk.mods.foreground, "foreground_mods", top_left_x)
            place_tiles(chunk.mods.background, "background_mods", top_left_x)

            coroutine.yield()

            -- remove temporary background
            for x = top_left_x, top_left_x + CHUNK_SIZE do
                for y = top_left_y - (CHUNK_SIZE + 1), top_left_y - 1 do
                    local material = world.material({x, y}, "background")
                    if material and material == "namje_indestructiblemetal" then
                        world.damageTiles({{x, y}}, "background", {x, y}, "blockish", 99999, 0)
                    end
                end
            end

            -- process objects
            -- failed object placements will be recursively done at the end
            --TODO: some objects not placing but being considered 'true' in placeObject?
            if chunk.objs and not isEmpty(chunk.objs) then
                total_object_count = total_object_count + #chunk.objs
                for _, object in pairs (chunk.objs) do
                    local unpacked_data
                    local parameters
                    local object_extras
                    if type(object) == "table" then
                        unpacked_data = object[1]
                        parameters = object[2]
                        object_extras = object[3]
                    else
                        unpacked_data = object
                    end
                    local pos, object_id, dir = unpack_obj_vals(unpacked_data)
                    local container_items = object_extras and object_extras.items or nil
                    local switch_state = object_extras and object_extras.switch_state or nil
                    local object_name = id_cache[object_id]

                    dir = dir == 0 and -1 or 1

                    --TODO: add missing object ids (and tiles) to a list to display later and just dont place them (or place dirt for tiles)
                    if object_name then
                        local place = world.placeObject(object_name, pos, dir or 0, parameters)
                        if place then
                            local placed_object_id = world.objectAt(pos)
                            if placed_object_id then
                                if parameters and parameters["startingAge"] then
                                    world.callScriptedEntity(placed_object_id, "require", "/scripts/namje_entStorageGrabber.lua")
                                    world.callScriptedEntity(placed_object_id, "set_ent_storage", "created", world.time() - parameters["startingAge"])
                                    world.callScriptedEntity(placed_object_id, "set_ent_storage", "durations", parameters["harvestable_durations"])
                                    world.callScriptedEntity(placed_object_id, "setStage")
                                end
                                if switch_state then
                                    world.callScriptedEntity(placed_object_id, "output", switch_state)
                                end
                                if container_items and next(container_items) ~= nil then
                                    for slot, item in pairs (container_items) do
                                        world.containerPutItemsAt(placed_object_id, item, slot - 1)
                                    end
                                end
                            end
                            placed_objects = placed_objects + 1
                        else
                            sb.logInfo("namje // failed to place object " .. object_name .. " at " .. pos[1] .. "," .. pos[2])
                            table.insert(failed_objects, object)
                        end
                    else
                        sb.logInfo("namje // no object name found for object id %s", object_id)
                    end
                end
            end

            -- process monsters
            if chunk.monsters and not isEmpty(chunk.monsters) then
                for _, monster in pairs (chunk.monsters) do
                    local pos = linear_to_pos(monster.pos)
                    local spawned_monster = world.spawnMonster(id_cache[monster.type], pos, monster.parameters)
                end
            end

            coroutine.yield()
        end

        -- recursive placement loop for failed objects
        local iterations = 0
        local iteration_cap = 1000
        if #failed_objects > 0 then
            while placed_objects < total_object_count do
                for k, object in ipairs (failed_objects) do
                    local pos, object_id, dir = unpack_obj_vals(type(object) == "table" and object[1] or object)

                    if world.objectAt(pos) then
                        placed_objects = placed_objects + 1
                        table.remove(failed_objects, k)
                    else
                        local parameters = type(object) == table and object[2] or nil
                        local object_extras = type(object) == table and object[3] or nil
                        local container_items = object_extras and object_extras.items or nil
                        local switch_state = object_extras and object_extras.switch_state or nil
                        local object_name = id_cache[object_id]

                        if object_name then
                            dir = dir == 0 and -1 or 1

                            local place = world.placeObject(object_name, pos, dir or 0, parameters)
                            if place then
                                local placed_object_id = world.objectAt(pos)
                                if placed_object_id then
                                    if switch_state then
                                        world.callScriptedEntity(placed_object_id, "output", switch_state)
                                    end
                                    if parameters and parameters["startingAge"] then
                                        world.callScriptedEntity(placed_object_id, "require", "/scripts/namje_entStorageGrabber.lua")
                                        world.callScriptedEntity(placed_object_id, "set_ent_storage", "created", world.time() - parameters["startingAge"])
                                        world.callScriptedEntity(placed_object_id, "set_ent_storage", "durations", parameters["harvestable_durations"])
                                        world.callScriptedEntity(placed_object_id, "setStage")
                                    end
                                end
                                if container_items then
                                    for slot, item in pairs (container_items) do
                                        world.containerPutItemsAt(object_id, item, slot-1)
                                    end
                                end
                                placed_objects = placed_objects + 1
                                table.remove(failed_objects, k)
                            end
                        else
                            sb.logInfo("namje // no object name found for object id %s", object_id)
                        end
                    end
                end
                iterations = iterations + 1
                if iterations >= iteration_cap then
                    sb.logInfo("namje // object placing timed out after " .. iteration_cap)
                    sb.logInfo("failed objects: %s", failed_objects)
                    break
                end
            end
            sb.logInfo("namje // complete object placement after " .. iterations .. " attempts")
        else
            sb.logInfo("namje // no failed objects")
        end

        --wiring
        if ship_table[3] and not isEmpty(ship_table[3]) then
            for _, packed_data in ipairs(ship_table[3]) do
                local output_pos, output_node, input_pos, input_node = unpack_wire(packed_data)
                sb.logInfo("wire: %s %s %s %s", output_pos, output_node, input_pos, input_node)
                world.wire(output_pos, output_node, input_pos, input_node)
            end
        end

        --liquid
        if ship_table[4] and not isEmpty(ship_table[4]) then
            for _, liquid in pairs (ship_table[4]) do
                local pos, id, level = unpack_liquid_vals(liquid)
                world.spawnLiquid(pos, id, level)
            end
        end

        if not isEmpty(invalid_ids) then
            --TODO: open UI listing invalid ids
            sb.logInfo("invalid ids: %s", invalid_ids)
        end
        return true
    end)
    return deserialize_coroutine
end

--- creates a new ship using the provided .namjeship config. will clear out the ship area and then place a new ship at {1024,1024}
--- @param ply string
--- @param ship_config table
function namje_byos.create_ship_from_config(ply, ship_config, ship_region)
    if not world.isServer() then
        error("namje // create_ship_from_config cannot be called on client")
    end

    local ship_dungeon_id = config.getParameter("shipDungeonId", 10101)
    local ship_offset = ship_config.namje_stats.ship_center_pos
    local ship_position = vec2.sub({1024, 1024}, {ship_offset[1], -ship_offset[2]})

    local coroutine = coroutine.create(function()
        --get the cached bounds, then clear the area
        local regions = {}
        local region_bounds
        if ship_region == nil or isEmpty(ship_region) then
            sb.logInfo("namje // ship_region is empty, though it shouldn't be. using defaults")
            region_bounds = rect.fromVec2({974, 974}, {1074, 1074})
        else
            for region, _ in pairs(ship_region) do
                local chunk = namje_util.region_decode(region)
                table.insert(regions, chunk)
            end
            region_bounds = namje_util.get_chunk_rect(regions)
        end
        namje_byos.clear_ship_area(region_bounds)
        if type(ship_config.ship) == "table" then
            sb.logInfo("namje // placing table variant of ship")
            --TODO: load table ship
        else
            world.placeDungeon(ship_config.ship, ship_position, ship_dungeon_id)
        end

        if namje_byos.is_fu() then
            namje_byos.reset_fu_stats()
        end

        --initialize the new region cache based on the ship_size in .namjeship
        local region_cache = {}
        local ship_size = ship_config.namje_stats.ship_size
        local width_chunks = math.ceil(ship_size[1] / CHUNK_SIZE)
        local height_chunks = math.ceil(ship_size[2] / CHUNK_SIZE)

        for i = 0, (height_chunks) do
            for k = 0, (width_chunks) do
                local chunk = namje_util.get_chunk({ship_position[1] + (CHUNK_SIZE * k), ship_position[2] - (CHUNK_SIZE * i)})
                local chunk_area = rect.fromVec2({chunk[1], chunk[2]}, {chunk[1] + (CHUNK_SIZE), chunk[2] + CHUNK_SIZE})
                local collision_detected = world.rectTileCollision(chunk_area, {"Block", "Dynamic", "Slippery", "Platform"})
                local cache_code = string.format("%s.%s", chunk[1], chunk[2])
                if collision_detected or namje_util.find_background_tiles(chunk[1], chunk[2]) then
                    region_cache[cache_code] = true
                end
            end
        end

        world.setProperty("namje_region_cache", region_cache)

        world.sendEntityMessage(ply, "namje_upgradeShip", ship_config.base_stats)
        return true
    end)
    return coroutine
end

--- scan from 0,0 to 2000,2000 for tiles in chunks of 100, then delete those areas with a 100x100 empty dungeon
function namje_byos.clear_ship_area(rect)
    if not world.isServer() then
        error("namje // clear_ship_area cannot be called on client")
    end
    sb.logInfo("clearing ship area: %s", rect)
    local chunks = namje_util.get_filled_chunks(rect)

    if #chunks == 0 then 
        return 
    end

    for _, chunk in ipairs (chunks) do
        local top_left_x = chunk.bottom_left[1]
        local bottom_right_y = chunk.top_right[2]

        world.placeDungeon("namje_void_32", {top_left_x, bottom_right_y})
    end
end

--- returns a list of items found in containers on the ship
--- @return table
function namje_byos.get_ship_items()
    local items = {}
    local objects = world.objectQuery({0, 0}, {2048, 2048})
    for _, v in ipairs (objects) do
        local container_items = world.containerItems(v)
        if container_items then
            for _, i in ipairs (container_items) do
                table.insert(items, i)
            end
        end
    end
    return items
end

--- returns true if the Frackin Universe mod is enabled, false otherwise
--- @return boolean
function namje_byos.is_fu()
    return root.assetJson("/versioning.config").FrackinUniverse ~= nil
end

--- returns true if the player/ is on a ship on client, or if the world is a ship on the server, false otherwise
--- @return boolean
function namje_byos.is_on_ship()
    if world.isClient() then
        return string.find(player.worldId(), "ClientShipWorld") ~= nil
    else
        return string.find(world.id(), "ClientShipWorld") ~= nil
    end
end

--- returns true if the player is on their own ship, false otherwise
--- @return boolean
function namje_byos.is_on_own_ship()
    if world.isClient() then
        return player.worldId() == player.ownShipWorldId()
    else
        error("namje // is_on_own_ship cannot be called on server")
    end
end

--- returns true if the module is found for the ship in the slot, false otherwise
--- @param slot number
--- @param module string
--- @return boolean
function namje_byos.has_module(slot, module)
    local ship_stats = namje_byos.get_stats(slot)
    local ship_modules = ship_stats.modules
    for _, v in pairs(ship_modules) do
        if v and v == module then
            return true
        end
    end
    return false
end

--- returns the ship config for the given ship_id, or nil if not found
--- @param ship_id string
--- @return table|nil
function namje_byos.get_ship_config(ship_id)
    local ship_configs = root.assetsByExtension("namjeship")
    for i = 1, #ship_configs do
        local config = root.assetJson(ship_configs[i])
        if config.id == ship_id then
            return config
        end
    end
    return nil
end

--- initializes the BYOS system for players, usually before the bootship quest but a failsafe is implemented for existing characters
function namje_byos.init_byos()
    player.setProperty("namje_byos_setup", true)
    namje_byos.add_ship_slots(2)
    namje_byos.set_current_ship(1)

    local existing_char = player.hasCompletedQuest("bootship")
    if existing_char then
        --being used on an existing character, show interface disclaimer thing and give the player an item to 
        --enable byos systems and a starter shiplicense
        --TODO: review and revamp existing char failsafe
        player.interact("scriptPane", "/interface/scripted/namje_existingchar/namje_existingchar.config")
        player.giveItem("namje_enablebyositem")
    else
        world.spawnStagehand({1024, 1024}, "namje_initBYOS_stagehand")
        local ship = namje_byos.register_new_ship(1, "namje_startership", "Lone Trail", "/namje_ships/ship_icons/generic_1.png")
        local system = {["system"] = celestial.currentSystem(), ["location"] = celestial.shipLocation()}
        --TODO: set the stat in the cockpit as well
        namje_byos.set_stats(1, {celestial_pos = system})

        player.warp("nowhere")
        --TODO: replaces the cinematic from the actual intro ending as well. Find a way to detect, or just use that one
        local cinematic = "/cinematics/namje/shipintro.cinematic"
        --player.playCinematic(cinematic, true)
    end
end

function namje_byos.reset_fu_stats()
    if not namje_byos.is_fu() then return end

    local ship_stats = {
        "shipSpeed",
        "fuelEfficiency",
        "maxFuel",
        "crewSize"
    }

    local ship_capabilities = {
        "systemTravel",
        "planetTravel"
    }

    for _, stat in ipairs(ship_stats) do
        world.setProperty("fu_byos." .. stat, 0)
    end

    for _, capability in ipairs(ship_capabilities) do
        world.setProperty("fu_byos." .. capability, 0)
    end

    world.setProperty("fu_byos.group.ftlDrive", 0)
end

--[[
    Fills the ship with their racial starter treasure pool. only to be used on initial ship creation
    method of grabbing racial treasure pool based on how FU does it
    since we're using a custom cargo hold instead of the ship locker for the starter ship, we're just gonna fill random storage containers onboard the ship
]]
function fill_shiplocker(species, ply)
    if not species then
        error("namje // no species provided to fill ship locker")
    end

    local racial_key = root.assetJson("/ships/" .. species .. "/blockKey.config:blockKey")
    local treasure_pools
    local starter_treasure = {}

    for _, tile_info in ipairs (racial_key) do
		treasure_pools = tile_info.objectParameters and tile_info.objectParameters.treasurePools
		if treasure_pools then
			break;
		end
	end

    if not treasure_pools then
        error("namje // no treasure pools found for species " .. species)
    end
    for _, treasure_pool in ipairs (treasure_pools) do
		local treasure = root.createTreasure(treasure_pool, 0)
		starter_treasure = util.mergeTable(starter_treasure, treasure)
	end

    local cargo_hold = {}
    local cargo_count = 1

    for i = 1, #starter_treasure do
        local item_to_add = {
            name = starter_treasure[i].name,
            parameters = starter_treasure[i].parameters,
            count = starter_treasure[i].count
        }
        
        cargo_hold["slot_" .. cargo_count] = item_to_add
        cargo_count = cargo_count + 1
    end

    local ship_slot = player.getProperty("namje_current_ship", 1)
    local ship_stats = namje_byos.get_stats(ship_slot)
    namje_byos.set_stats(ship_slot, {["cargo_hold"] = cargo_hold})
end