require "/scripts/namje_byos.lua"
require "/scripts/vec2.lua"
require "/scripts/util.lua"
require "/scripts/rect.lua"

local CHUNK_SIZE = 32

namje_tableSerializer = {}

-- TODO: Duplicate objects being grabbed
--- starts the serialization coroutine. returns the serialized table form of the shipworld. excludes include npcs, monsters, and container_items.
--- @param excludes table
--- @returns coroutine
function namje_tableSerializer.ship_to_table(excludes)
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
                local object_id = chunk_objects[i]

                if object_id > 0 then
                    --TODO: remove object extras, add to parameters instead(?)
                    local pos = world.entityPosition(object_id)
                    local object_parameters = world.getObjectParameter(object_id,"")
                    local obj_name = object_parameters.objectName
                    local direction = world.callScriptedEntity(object_id, "object.direction") or 1
                    local packed_direction = (direction == 1) and 1 or 0
                    local packed_data = pack_obj_vals(pos, get_cached_id(obj_name), packed_direction)
                    local temp_obj_item = root.itemConfig(obj_name)
                    local old_parameters = temp_obj_item.config
                    world.callScriptedEntity(object_id, "require", "/scripts/namje_entStorageGrabber.lua")
                    
                    local finalized_params = remove_duplicate_keys(object_parameters, old_parameters)

                    local obj_data_storage = world.callScriptedEntity(object_id, "get_ent_storage", "") or {}
                    if namje_util.dict_size(obj_data_storage) > 0 then
                        finalized_params["namje_data_storage"] = obj_data_storage
                    end

                    --upgrade stages
                    if obj_data_storage.currentStage then
                        finalized_params["startingUpgradeStage"] = obj_data_storage.currentStage or 0
                    end

                    --harvestable test
                    if old_parameters.stages then
                        local age = world.callScriptedEntity(object_id, "activeAge")
                        if age then
                            finalized_params["startingAge"] = age
                        end
                    end

                    if not excludes.container_items then
                        local container_items = world.containerItems(object_id)
                        if container_items and not isEmpty(container_items) then
                            finalized_params["namje_container_items"] = container_items
                        end
                    end

                    local farmable_stage = world.farmableStage(object_id)
                    if farmable_stage and farmable_stage > 0 then
                        finalized_params["startingStage"] = farmable_stage
                    end

                    if old_parameters.deed then
                        --delay the firstscan to detect the tenant(?)
                        if finalized_params.deed then
                            finalized_params.deed.firstScan = {15.0, 16.0}
                        else
                            finalized_params.deed = {firstScan = {15.0, 16.0}}
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

                    --[[
                    if input_nodes and input_nodes > 0 or output_nodes and output_nodes > 0 then
                        local current_state = obj_data_storage.state
                        finalized_params["namje_switch_state"] = current_state
                    end]]

                    local object_data = packed_data
                    --remove params that are not being trimmed properly for some reason, the fringe cases where these values are changed via lua arent worth the size increase
                    finalized_params.image = nil
                    finalized_params.direction = nil
                    finalized_params.scripts = nil
                    finalized_params.flipImages = nil
                    if not isEmpty(finalized_params) then
                        object_data = {packed_data, finalized_params}
                    end

                    table.insert(objects, object_data)
                end
            end

            --process monsters
            if not excludes.monsters then
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
            end

            --TODO: process npcs
            if not excludes.npcs then
                local chunk_npcs = world.npcQuery({min_x, min_y}, {max_x, max_y}, {boundMode  = "position"})
                for _, entity_id in ipairs (chunk_npcs) do
                    if entity_id > 0 then
                        local duplicate_npc = false
                        local pos = world.callScriptedEntity(entity_id, "mcontroller.position")
                        local linear_pos = (math.floor(pos[2]) << bit_range) | math.floor(pos[1])
                        local seed = world.callScriptedEntity(entity_id, "npc.seed")
                        local type = world.callScriptedEntity(entity_id, "npc.npcType")
                        if not string.match(type, "crewmember") then
                            for _, v in pairs(ship_chunks) do
                                if v.npcs then
                                    for _, npc in pairs(v.npcs) do
                                        local existing_seed = npc.seed
                                        local existing_pos = npc.pos
                                        if seed == existing_seed and existing_pos == linear_pos then
                                            duplicate_npc = true
                                        end
                                    end
                                end
                            end

                            if not duplicate_npc then
                                local species = world.callScriptedEntity(entity_id, "npc.species")
                                local level = world.callScriptedEntity(entity_id, "npc.level")
                                local unique_id = world.entityUniqueId(entity_id)
                                local npc_info = {
                                    pos = linear_pos,
                                    species = species,
                                    level = level,
                                    seed = seed,
                                    type = type,
                                    uuid = unique_id
                                }
                                table.insert(npcs, npc_info)
                            end
                        end
                    end
                end
            end

            local ship_chunk = {pos = pack_pos(min_x, max_y), tiles = {foreground = foreground_tiles, background = background_tiles}, mods = {foreground = foreground_mods, background = background_mods}}
            if not isEmpty(objects) then
                ship_chunk["objs"] = objects
            end

            if not isEmpty(monsters) then
                ship_chunk["monsters"] = monsters
            end

            if not isEmpty(npcs) then
                ship_chunk["npcs"] = npcs
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

--- starts the coroutine to build a ship from a serialized table. returns the coroutine.
--- @param ship_table table
--- @param ship_region table
--- @returns coroutine
function namje_tableSerializer.table_to_ship(ship_table, ship_region)
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

    local function manage_placed_object(placed_object_id, parameters)
        local container_items = parameters and parameters.namje_container_items or nil
        if parameters and parameters["namje_data_storage"] then
            -- setting output state for wireables/doors
            local object_state = parameters["namje_data_storage"].state
            if object_state then
                world.callScriptedEntity(placed_object_id, "output", object_state)
                world.callScriptedEntity(placed_object_id, "openDoor")
            end

            world.callScriptedEntity(placed_object_id, "require", "/scripts/namje_entStorageGrabber.lua")
            world.callScriptedEntity(placed_object_id, "set_ent_storage", parameters["namje_data_storage"])
        end
        if parameters and parameters["startingAge"] then
            world.callScriptedEntity(placed_object_id, "setStage")
        end
        if container_items and next(container_items) ~= nil then
            for slot, item in pairs (container_items) do
                world.containerPutItemsAt(placed_object_id, item, slot - 1)
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
        --[[
            FU compatibility:
            fu_shipstatmodifier only resets stats on die(), which doesn't seem to trigger when the area is overriden with a dungeon.
            require a new unload() function onto the object and call it beforehand
        ]]
        if namje_byos.is_fu() then
            local objects = world.objectQuery({region_bounds[1], region_bounds[2]}, {region_bounds[3], region_bounds[4]})
            for _, object in pairs(objects) do
                local obj_name = world.getObjectParameter(object, "objectName")
                local temp_obj_item = root.itemConfig(obj_name)
                local old_parameters = temp_obj_item.config
                if old_parameters.byosOnly then
                    world.callScriptedEntity(object, "require", "/scripts/namje_fuStatHook.lua")
                    world.callScriptedEntity(object, "namje_unload")
                end
            end
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
                    if type(object) == "table" then
                        unpacked_data = object[1]
                        parameters = object[2]
                    else
                        unpacked_data = object
                    end
                    local pos, object_id, dir = unpack_obj_vals(unpacked_data)
                    local object_name = id_cache[object_id]

                    dir = dir == 0 and -1 or 1

                    --TODO: add missing object ids (and tiles) to a list to display later and just dont place them (or place dirt for tiles)
                    if object_name then
                        local place = world.placeObject(object_name, pos, dir or 0, parameters)
                        if place then
                            local placed_object_id = world.objectAt(pos)
                            if placed_object_id then
                                manage_placed_object(placed_object_id, parameters)
                            end
                            placed_objects = placed_objects + 1
                        else
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

            -- process npcs
            if chunk.npcs and not isEmpty(chunk.npcs) then
                for _, npc in pairs (chunk.npcs) do
                    local pos = linear_to_pos(npc.pos)
                    local spawned_npc = world.spawnNpc(pos, npc.species, npc.type, npc.level, npc.seed)
                    if spawned_npc and #npc.uuid > 0 then
                        world.setUniqueId(spawned_npc, npc.uuid)
                    end
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
                        local object_name = id_cache[object_id]

                        if object_name then
                            dir = dir == 0 and -1 or 1

                            local place = world.placeObject(object_name, pos, dir or 0, parameters)
                            if place then
                                local placed_object_id = world.objectAt(pos)
                                if placed_object_id then
                                    manage_placed_object(placed_object_id, parameters)
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
                --TODO: something wrong with spawning liquids that gives it more quantity than expected? try reducing the quantity to a point, though this
                --may affect smaller bodies of liquids
                world.spawnLiquid(pos, id, (level*0.84))
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