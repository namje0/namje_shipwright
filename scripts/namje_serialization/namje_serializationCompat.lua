require "/scripts/namje_serialization/namje_b64.lua"

-- backwards compatibility for ship data, ship codes and object parameters saved by older versions.
-- everything here converts old data into the current ship table layout; nothing here writes the old formats.
--
-- formats handled:
--  - v1 binary ship data (fixed width fields, no header). stored as raw binary in player properties, or inside ship codes
--  - v1 ship codes: "namjeShip::" .. base64("regions|...:" .. v1 binary), and the same payload packed by namje_b64.pack
--  - colony deeds saved before namje_data_storage, which kept their state in colonydeed_* object parameters

namje_serializationCompat = {}

-------------------------------------------------------------------------------
-- v1 binary ship data
-------------------------------------------------------------------------------

local V1_TYPE_NIL = 0
local V1_TYPE_FALSE = 1
local V1_TYPE_TRUE = 2
local V1_TYPE_NUMBER_F4 = 3
local V1_TYPE_NUMBER_F8 = 4
local V1_TYPE_INT_I1 = 5
local V1_TYPE_INT_I2 = 6
local V1_TYPE_INT_I4 = 7
local V1_TYPE_INT_I8 = 8
local V1_TYPE_STRING_L1 = 9
local V1_TYPE_STRING_L4 = 10
local V1_TYPE_TABLE = 11

local V1_VALUE_FORMATS = {
    [V1_TYPE_NUMBER_F4] = "f",
    [V1_TYPE_NUMBER_F8] = "d",
    [V1_TYPE_INT_I1] = "i1",
    [V1_TYPE_INT_I2] = "i2",
    [V1_TYPE_INT_I4] = "i4",
    [V1_TYPE_INT_I8] = "j",
    [V1_TYPE_STRING_L1] = "s1",
    [V1_TYPE_STRING_L4] = "s4"
}

local V1_HEADER_POS = 0
local V1_HEADER_MODS = 1
local V1_HEADER_TILES = 2
local V1_HEADER_OBJS = 3
local V1_HEADER_MONSTERS = 4
local V1_HEADER_NPCS = 5
local V1_HEADER_END_CHUNK = 11

local sunpack = string.unpack

local function unpack_v1_value(data, pos)
    local type_id
    type_id, pos = sunpack("B", data, pos)

    if type_id == V1_TYPE_NIL then
        return nil, pos
    elseif type_id == V1_TYPE_TRUE then
        return true, pos
    elseif type_id == V1_TYPE_FALSE then
        return false, pos
    elseif type_id == V1_TYPE_TABLE then
        local entry_count
        entry_count, pos = sunpack("I4", data, pos)
        local t = {}
        for _ = 1, entry_count do
            local key, value
            key, pos = unpack_v1_value(data, pos)
            value, pos = unpack_v1_value(data, pos)
            if key ~= nil then t[key] = value end
        end
        return t, pos
    end

    local format = V1_VALUE_FORMATS[type_id]
    if not format then
        error("namje // unexpected type in legacy ship data: " .. tostring(type_id))
    end
    return sunpack(format, data, pos)
end

-- v1 tile run: length 14 bits, id 10 bits, color 4 bits, hue 4 bits
local function convert_v1_tile(packed)
    return namje_binarySerializer.pack_tile(packed & 0x3FFF, (packed >> 14) & 0x3FF, (packed >> 24) & 0xF, (packed >> 28) & 0xF)
end

-- v1 object: x 12 bits, y 12 bits, id 10 bits, direction 1 bit
local function convert_v1_object(packed)
    return namje_binarySerializer.pack_object(packed & 0xFFF, (packed >> 12) & 0xFFF, (packed >> 24) & 0x3FF, (packed >> 34) & 1)
end

--- deserializes v1 binary ship data into the current ship table layout
--- @param ship_data string
--- @returns table
function namje_serializationCompat.unpack_ship_data_v1(ship_data)
    local material_cache = {}
    local ship_chunks = {}
    local ship_wiring = {}
    local ship_liquids = {}
    local pos = 1

    local function unpack_tiles(tbl)
        local layer_length
        layer_length, pos = sunpack("I3", ship_data, pos)
        for i = 1, layer_length do
            if i == 1 then
                local run_start, data
                run_start, data, pos = sunpack("I4I4", ship_data, pos)
                tbl[i] = {run_start, convert_v1_tile(data)}
            else
                local data
                data, pos = sunpack("I4", ship_data, pos)
                tbl[i] = convert_v1_tile(data)
            end
        end
    end

    local material_count
    material_count, pos = sunpack("I2", ship_data, pos)
    for i = 1, material_count do
        material_cache[i], pos = sunpack("s1", ship_data, pos)
    end

    local chunk_count
    chunk_count, pos = sunpack("I3", ship_data, pos)
    for _ = 1, chunk_count do
        local chunk = {
            mods = {foreground = {}, background = {}},
            tiles = {foreground = {}, background = {}}
        }
        while true do
            local header_id
            header_id, pos = sunpack("B", ship_data, pos)
            if header_id == V1_HEADER_END_CHUNK then
                break
            elseif header_id == V1_HEADER_POS then
                chunk.pos, pos = sunpack("I3", ship_data, pos)
            elseif header_id == V1_HEADER_MODS or header_id == V1_HEADER_TILES then
                local key = header_id == V1_HEADER_MODS and "mods" or "tiles"
                unpack_tiles(chunk[key].foreground)
                unpack_tiles(chunk[key].background)
            elseif header_id == V1_HEADER_OBJS then
                chunk.objs = {}
                local objs_count
                objs_count, pos = sunpack("I3", ship_data, pos)
                for i = 1, objs_count do
                    local obj_type, obj_id
                    obj_type, obj_id, pos = sunpack("BI8", ship_data, pos)
                    obj_id = convert_v1_object(obj_id)
                    if obj_type > 1 then
                        local obj_params
                        obj_params, pos = unpack_v1_value(ship_data, pos)
                        chunk.objs[i] = {obj_id, obj_params}
                    else
                        chunk.objs[i] = obj_id
                    end
                end
            elseif header_id == V1_HEADER_MONSTERS then
                chunk.monsters = {}
                local mons_count
                mons_count, pos = sunpack("I3", ship_data, pos)
                for i = 1, mons_count do
                    local mon_type, mon_params, mon_pos
                    mon_type, pos = sunpack("I2", ship_data, pos)
                    mon_params, pos = unpack_v1_value(ship_data, pos)
                    mon_pos, pos = sunpack("I4", ship_data, pos)
                    chunk.monsters[i] = {type = mon_type, parameters = mon_params, pos = mon_pos}
                end
            elseif header_id == V1_HEADER_NPCS then
                chunk.npcs = {}
                local npcs_count
                npcs_count, pos = sunpack("I3", ship_data, pos)
                for i = 1, npcs_count do
                    local npc_pos, species, level, seed, npc_type, uuid
                    npc_pos, species, level, seed, npc_type, uuid, pos = sunpack("I4s1I1I8s1s1", ship_data, pos)
                    chunk.npcs[i] = {pos = npc_pos, species = species, level = level, seed = seed, type = npc_type, uuid = uuid}
                end
            else
                error("namje // unexpected chunk section in legacy ship data: " .. tostring(header_id))
            end
        end
        ship_chunks[#ship_chunks + 1] = chunk
    end

    local wiring_count
    wiring_count, pos = sunpack("I2", ship_data, pos)
    for i = 1, wiring_count do
        ship_wiring[i], pos = sunpack("I8", ship_data, pos)
    end

    local liquids_count
    liquids_count, pos = sunpack("I2", ship_data, pos)
    for i = 1, liquids_count do
        ship_liquids[i], pos = sunpack("I8", ship_data, pos)
    end

    return {material_cache, ship_chunks, ship_wiring, ship_liquids}
end

-------------------------------------------------------------------------------
-- v1 ship codes
-------------------------------------------------------------------------------

--- decodes the payload of a v1 ship code (everything after the prefix). returns the regions and v1 binary ship data,
--- or nil if the payload isn't a v1 ship code
--- @param payload string
--- @returns table, string
function namje_serializationCompat.decode_ship_code_v1(payload)
    local decoded
    if namje_b64.is_packed(payload) then
        decoded = namje_b64.unpack(payload)
    else
        decoded = namje_b64.decode(payload)
    end
    return namje_serializationCompat.split_ship_code_v1(decoded)
end

--- splits a decoded v1 ship code payload ("region|region:data") into its regions and data
--- @param decoded string
--- @returns table, string
function namje_serializationCompat.split_ship_code_v1(decoded)
    local region_part, data = decoded:match("^([^:]*):(.*)$")
    if not region_part or not data then
        return nil, nil
    end

    local regions = {}
    for region in region_part:gmatch("([^|]+)") do
        regions[region] = true
    end
    return regions, data
end

-------------------------------------------------------------------------------
-- colony deeds
-------------------------------------------------------------------------------

--- returns the deed storage kept by ships saved before namje_data_storage, or nil if the parameters have none
--- @param parameters table
--- @returns table
function namje_serializationCompat.legacy_deed_storage(parameters)
    if not parameters or parameters["namje_data_storage"] or not parameters["colonydeed_occupier"] then
        return nil
    end
    return {
        occupier = parameters["colonydeed_occupier"],
        house = parameters["colonydeed_house"],
        grumbles = parameters["colonydeed_grumbles"]
    }
end

--- removes object parameters that older versions saved, which current saves keep elsewhere
--- @param parameters table
function namje_serializationCompat.strip_legacy_parameters(parameters)
    parameters.colonydeed_occupier = nil
    parameters.colonydeed_house = nil
    parameters.colonydeed_grumbles = nil
end
