require "/scripts/util.lua"

local TYPE_NIL          = 0
local TYPE_FALSE        = 1
local TYPE_TRUE         = 2
local TYPE_NUMBER_F4    = 3
local TYPE_NUMBER_F8    = 4
local TYPE_INT_I1       = 5
local TYPE_INT_I2       = 6
local TYPE_INT_I4       = 7
local TYPE_INT_I8       = 8
local TYPE_STRING_L1    = 9
local TYPE_STRING_L4    = 10
local TYPE_TABLE        = 11
local FORMAT_TYPE_ID      = "B"
local FORMAT_INT_I1       = "i1"
local FORMAT_INT_I2       = "i2"
local FORMAT_INT_I4       = "i4"
local FORMAT_INT_I8       = "j"
local FORMAT_FLOAT_F4     = "f"
local FORMAT_FLOAT_F8     = "d"
local FORMAT_LEN_L1       = "I1"
local FORMAT_LEN_L4       = "I4"
local MAX_INT_I1 = 127
local MAX_INT_I2 = 32767
local MAX_INT_I4 = 2147483647
local MAX_STRING_L1 = 255
local MAX_TABLE_COUNT = 4294967295
local DICT_HEADERS = {
    pos = 0,
    mods = 1,
    tiles = 2,
    objs = 3,
    monsters = 4,
    npcs = 5,
    entities = 6,
    background = 7,
    foreground = 8,
    items = 9,
    switch_state = 10,
    end_chunk = 11
}
local DICT_HEADERS_REV = {
    [0] = "pos",
    [1] = "mods",
    [2] = "tiles",
    [3] = "objs",
    [4] = "monsters",
    [5] = "npcs",
    [6] = "entities",
    [7] = "background",
    [8] = "foreground",
    [9] = "items",
    [10] = "switch_state",
    [11] = "end_chunk"
}

binary_serializer = {}
binary_serializer.seen_tables = {}

-- honestly didn't feel like writing a "general-use-case" packer for object parameters, so Gemini can do it for me. it works so too bad
local function _pack(value, buffer)
    local v_type = type(value)

    if v_type == "nil" then
        table.insert(buffer, string.pack(FORMAT_TYPE_ID, TYPE_NIL))

    elseif v_type == "boolean" then
        -- Optimization: Consolidate TRUE/FALSE into the Type ID byte
        if value then
            table.insert(buffer, string.pack(FORMAT_TYPE_ID, TYPE_TRUE))
        else
            table.insert(buffer, string.pack(FORMAT_TYPE_ID, TYPE_FALSE))
        end

    elseif v_type == "number" then
        if value % 1 ~= 0 then
            -- Value is a float. Use single-precision (F4) for size, F8 if needed
            -- Defaulting to F4 as a common optimization
            table.insert(buffer, string.pack(FORMAT_TYPE_ID .. FORMAT_FLOAT_F4, TYPE_NUMBER_F4, value))
        else
            -- Optimization: Use smallest integer format
            local abs_value = math.abs(value)
            local type_id, format
            
            if abs_value <= MAX_INT_I1 then
                type_id, format = TYPE_INT_I1, FORMAT_INT_I1
            elseif abs_value <= MAX_INT_I2 then
                type_id, format = TYPE_INT_I2, FORMAT_INT_I2
            elseif abs_value <= MAX_INT_I4 then
                type_id, format = TYPE_INT_I4, FORMAT_INT_I4
            else
                -- Max 64-bit integer
                type_id, format = TYPE_INT_I8, FORMAT_INT_I8
            end
            
            table.insert(buffer, string.pack(FORMAT_TYPE_ID .. format, type_id, value))
        end

    elseif v_type == "string" then
        local len = #value
        
        -- Optimization: Use smallest length format
        local type_id, len_format
        if len <= MAX_STRING_L1 then
            type_id, len_format = TYPE_STRING_L1, FORMAT_LEN_L1
        else
            -- For very large strings, stick to 4 bytes for length
            type_id, len_format = TYPE_STRING_L4, FORMAT_LEN_L4
        end
        
        -- Pack ID, Length, then the String data
        local header = string.pack(FORMAT_TYPE_ID .. len_format, type_id, len)
        table.insert(buffer, header)
        table.insert(buffer, value) -- Direct string insertion is fastest

    elseif v_type == "table" then
        if binary_serializer.seen_tables[value] then
            error("namje // circular reference found")
        end
        binary_serializer.seen_tables[value] = true

        local packed_entries_buffer = {}
        local entry_count = 0

        -- 1. Recursively pack keys and values into a temporary buffer
        for k, v in pairs(value) do
            _pack(k, packed_entries_buffer) -- Use recursive call
            _pack(v, packed_entries_buffer) -- Use recursive call
            entry_count = entry_count + 1
        end

        binary_serializer.seen_tables[value] = nil

        -- 2. Pack the header (ID + Count)
        -- Optimization: Use I4 for table count (could be made variable, but I4 is safe)
        local header = string.pack(FORMAT_TYPE_ID .. FORMAT_LEN_L4, TYPE_TABLE, entry_count)
        table.insert(buffer, header)
        
        -- 3. Insert all packed entries at once using table.concat
        table.insert(buffer, table.concat(packed_entries_buffer))

    else
        error("namje // unexpected type: " .. tostring(v_type))
    end
end

function binary_serializer.pack_general_dictionary(value)
    local buffer = {}
    _pack(value, buffer)
    return table.concat(buffer)
end

function binary_serializer.unpack_general_dictionary(data, pos)
    pos = pos or 1
    local type_id, next_pos = string.unpack(FORMAT_TYPE_ID, data, pos)

    if not type_id then return nil, pos end 
    pos = next_pos
    
    if type_id == TYPE_NIL then
        return nil, pos
    elseif type_id == TYPE_TRUE then
        return true, pos
    elseif type_id == TYPE_FALSE then
        return false, pos
        
    elseif type_id == TYPE_NUMBER_F4 then
        local value
        value, pos = string.unpack(FORMAT_FLOAT_F4, data, pos)
        return value, pos
    elseif type_id == TYPE_NUMBER_F8 then
        local value
        value, pos = string.unpack(FORMAT_FLOAT_F8, data, pos)
        return value, pos
        
    elseif type_id == TYPE_INT_I1 then
        local value
        value, pos = string.unpack(FORMAT_INT_I1, data, pos)
        return value, pos
    elseif type_id == TYPE_INT_I2 then
        local value
        value, pos = string.unpack(FORMAT_INT_I2, data, pos)
        return value, pos
    elseif type_id == TYPE_INT_I4 then
        local value
        value, pos = string.unpack(FORMAT_INT_I4, data, pos)
        return value, pos
    elseif type_id == TYPE_INT_I8 then
        local value
        value, pos = string.unpack(FORMAT_INT_I8, data, pos)
        return value, pos
        
    elseif type_id == TYPE_STRING_L1 or type_id == TYPE_STRING_L4 then
        local len_format = (type_id == TYPE_STRING_L1) and FORMAT_LEN_L1 or FORMAT_LEN_L4
        local len
        len, pos = string.unpack(len_format, data, pos) 
        local format = "c" .. len
        local value
        value, pos = string.unpack(format, data, pos)
        return value, pos

    elseif type_id == TYPE_TABLE then
        local entry_count
        entry_count, pos = string.unpack(FORMAT_LEN_L4, data, pos) 
        local new_table = {}
        
        for i = 1, entry_count do
            local key, value
            key, pos = binary_serializer.unpack_general_dictionary(data, pos)
            value, pos = binary_serializer.unpack_general_dictionary(data, pos)
            
            new_table[key] = value
        end

        return new_table, pos

    else
        error("namje// unexpected type: " .. tostring(type_id))
    end
end

function binary_serializer.pack_ship_data(ship_table)
    local material_cache = ship_table[1]
    local ship_chunks = ship_table[2]
    local ship_wiring = ship_table[3]
    local ship_liquids = ship_table[4]
    local packed_data = {}

    local function pack_tiles(tbl)
        table.insert(packed_data, string.pack("I3", #tbl))
        for _, val in ipairs(tbl) do
            if type(val) == "table" then
                table.insert(packed_data, string.pack("I4I4", val[1], val[2]))
            else
                table.insert(packed_data, string.pack("I4", val))
            end
        end
    end

    --pack material cache
    table.insert(packed_data, string.pack("I2", #material_cache))
    for _, id in ipairs(material_cache) do
        --1 byte = 255 characters, if a material id exceeds that then something has gone horribly wrong
        table.insert(packed_data, string.pack("s1", id))
    end

    --pack shipchunks
    table.insert(packed_data, string.pack("I3", #ship_chunks))
    for _, chunk in pairs(ship_chunks) do
        for k, v in pairs(chunk) do
            local header = string.pack(FORMAT_TYPE_ID, DICT_HEADERS[k]) 
            table.insert(packed_data, header)
            if k == "pos" then
                table.insert(packed_data, string.pack("I3", v))
            elseif k == "mods" or k == "tiles" then
                pack_tiles(v.foreground)
                pack_tiles(v.background)
            elseif k == "objs" then
                table.insert(packed_data, string.pack("I3", #v))
                for _, obj in pairs(v) do
                    table.insert(packed_data, string.pack(FORMAT_TYPE_ID, type(obj)=="table" and 2 or 1))
                    if type(obj) == "table" then
                        table.insert(packed_data, string.pack("I8", obj[1]))
                        table.insert(packed_data, binary_serializer.pack_general_dictionary(obj[2]))
                    else
                        table.insert(packed_data, string.pack("I8", obj))
                    end
                end
            elseif k == "monsters" then
                table.insert(packed_data, string.pack("I3", #v))
                for _, monster in pairs(v) do
                    table.insert(packed_data, string.pack("I2", monster.type))
                    table.insert(packed_data, binary_serializer.pack_general_dictionary(monster.parameters))
                    table.insert(packed_data, string.pack("I4", monster.pos))
                end
            elseif k == "npcs" then
                table.insert(packed_data, string.pack("I3", #v))
                for _, npc in pairs(v) do
                    table.insert(packed_data, string.pack("I4", npc.pos))
                    table.insert(packed_data, string.pack("s1", npc.species))
                    table.insert(packed_data, string.pack("I1", npc.level))
                    table.insert(packed_data, string.pack("I8", npc.seed))
                    table.insert(packed_data, string.pack("s1", npc.type))
                    table.insert(packed_data, string.pack("s1", npc.uuid or ""))
                end
            end
        end
        local header = string.pack(FORMAT_TYPE_ID, DICT_HEADERS["end_chunk"]) 
        table.insert(packed_data, header)
    end

    --pack wiring
    table.insert(packed_data, string.pack("I2", #ship_wiring))
    for _, id in ipairs(ship_wiring) do
        table.insert(packed_data, string.pack("I8", id))
    end

    --pack liquids
    table.insert(packed_data, string.pack("I2", #ship_liquids))
    for _, id in ipairs(ship_liquids) do
        table.insert(packed_data, string.pack("I8", id))
    end

    --pack chunk data
    return table.concat(packed_data)
end

function binary_serializer.unpack_ship_data(ship_data)
    local material_cache = {}
    local ship_chunks = {}
    local ship_wiring = {}
    local ship_liquids = {}
    local pos = 1

    local function unpack_tiles(tbl)
        local layer_length
        layer_length, pos = string.unpack("I3", ship_data, pos)
        for i = 1, layer_length do
            if i == 1 then
                local run_start, data, next_pos = string.unpack("I4I4", ship_data, pos)
                pos = next_pos
                table.insert(tbl, {run_start, data})
            else
                local data, next_pos = string.unpack("I4", ship_data, pos)
                pos = next_pos
                table.insert(tbl, data)
            end
        end
    end

    local material_count
    material_count, pos = string.unpack("I2", ship_data, pos)
    for _ = 1, material_count do
        local id
        id, pos = string.unpack("s1", ship_data, pos)
        table.insert(material_cache, id)
    end

    --unpack shipchunks
    local chunk_count
    chunk_count, pos = string.unpack("I3", ship_data, pos)
    for _ = 1, chunk_count do
        local chunk = {
            mods = {
                foreground = {},
                background = {}
            },
            tiles = {
                foreground = {},
                background = {}
            }
        }
        local end_of_chunk = false
        while not end_of_chunk do
            local header_id
            header_id, pos = string.unpack(FORMAT_TYPE_ID, ship_data, pos)
            local key = DICT_HEADERS_REV[header_id]
            if key == "end_chunk" then
                end_of_chunk = true
            elseif key == "pos" then
                local chunk_pos
                chunk_pos, pos = string.unpack("I3", ship_data, pos)
                chunk.pos = chunk_pos
            elseif key == "mods" or key == "tiles" then
                unpack_tiles(chunk[key].foreground)
                unpack_tiles(chunk[key].background)
            elseif key == "objs" then
                chunk.objs = {}
                local objs_count
                objs_count, pos = string.unpack("I3", ship_data, pos)
                
                for _ = 1, objs_count do
                    local obj_type
                    obj_type, pos = string.unpack(FORMAT_TYPE_ID, ship_data, pos)
                    if obj_type > 1 then
                        local obj_id
                        obj_id, pos = string.unpack("I8", ship_data, pos)
                        local obj_params
                        obj_params, pos = binary_serializer.unpack_general_dictionary(ship_data, pos)
                        table.insert(chunk.objs, {obj_id, obj_params})
                    else
                        local obj_id
                        obj_id, pos = string.unpack("I8", ship_data, pos)
                        table.insert(chunk.objs, obj_id)
                    end
                end
            elseif key == "monsters" then
                chunk.monsters = {}
                local mons_count
                mons_count, pos = string.unpack("I3", ship_data, pos)
                for _ = 1, mons_count do
                    local mon_type
                    mon_type, pos = string.unpack("I2", ship_data, pos)
                    local mon_params
                    mon_params, pos = binary_serializer.unpack_general_dictionary(ship_data, pos)
                    local mon_pos
                    mon_pos, pos = string.unpack("I4", ship_data, pos)
                    table.insert(chunk.monsters, {type = mon_type, parameters = mon_params, pos = mon_pos})
                end
            elseif key == "npcs" then
                chunk.npcs = {}
                local npcs_count
                npcs_count, pos = string.unpack("I3", ship_data, pos)
                for _ = 1, npcs_count do
                    local npc_pos
                    npc_pos, pos = string.unpack("I4", ship_data, pos)
                    local npc_species
                    npc_species, pos = string.unpack("s1", ship_data, pos)
                    local npc_level
                    npc_level, pos = string.unpack("I1", ship_data, pos)
                    local npc_seed
                    npc_seed, pos = string.unpack("I8", ship_data, pos)
                    local npc_type
                    npc_type, pos = string.unpack("s1", ship_data, pos)
                    local npc_uuid
                    npc_uuid, pos = string.unpack("s1", ship_data, pos)
                    table.insert(chunk.npcs, {pos = npc_pos, species = npc_species, level = npc_level, seed = npc_seed, type = npc_type, uuid = npc_uuid})
                end
            end
        end
        if not isEmpty(chunk) then
            table.insert(ship_chunks, chunk)
        end
    end

    local wiring_count
    wiring_count, pos = string.unpack("I2", ship_data, pos)
    for _ = 1, wiring_count do
        local id
        id, pos = string.unpack("I8", ship_data, pos)
        table.insert(ship_wiring, id)
    end

    local liquids_count
    liquids_count, pos = string.unpack("I2", ship_data, pos)
    for _ = 1, liquids_count do
        local id
        id, pos = string.unpack("I8", ship_data, pos)
        table.insert(ship_liquids, id)
    end

    return {material_cache, ship_chunks, ship_wiring, ship_liquids}
end