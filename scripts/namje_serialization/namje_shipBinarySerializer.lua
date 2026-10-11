require "/scripts/namje_serialization/namje_serializationCompat.lua"

-- binary format for serialized ship tables (see namje_tableSerializer for the table layout).
--
-- layout (v2):
--   header    "nS", u8 version, u8 flags
--   regions   only if flags & FLAG_REGIONS. varint count, then per region varint(x + 1), varint(y), or varint(0) and a string
--   materials varint count, strings
--   chunks    varint count, then per chunk:
--               varint pos, four tile run lists (fg tiles, bg tiles, fg mods, bg mods), u8 section mask, sections
--               positions inside a chunk are stored as zigzag offsets from the chunk origin
--   wiring    varint count, zigzag deltas between wires
--   liquids   varint count, per liquid zigzag position delta, varint id, varint level
--
-- general values (object/monster parameters, npc and vehicle data) use a tagged encoding. every string is written once
-- and referenced by index afterwards, which is where most of the savings on object parameters come from.
--
-- data that doesn't start with HEADER is from before v2, and is handled by namje_serializationCompat.

namje_binarySerializer = {}

local HEADER = "nS"
local VERSION = 2
local FLAG_REGIONS = 1

local SECTION_OBJECTS = 1
local SECTION_MONSTERS = 2
local SECTION_NPCS = 4
local SECTION_VEHICLES = 8

local TAG_NIL = 0
local TAG_FALSE = 1
local TAG_TRUE = 2
local TAG_F32 = 3
local TAG_F64 = 4
local TAG_INT = 5
local TAG_STRING = 6
local TAG_STRING_REF = 7
local TAG_ARRAY = 8
local TAG_MAP = 9
local TAG_FIXINT = 0x40 -- 0x40-0x7F: integers 0-63
local TAG_FIXREF = 0x80 -- 0x80-0xFF: string refs 0-127

local byte, char, spack, sunpack, concat = string.byte, string.char, string.pack, string.unpack, table.concat

local CHARS = {}
for i = 0, 255 do CHARS[i] = char(i) end

-------------------------------------------------------------------------------
-- packed value layouts shared with namje_tableSerializer
-------------------------------------------------------------------------------

-- tile run: length 14 bits, id 16 bits, color variant 8 bits, hue shift 8 bits
function namje_binarySerializer.pack_tile(length, id, color, hue)
    return length | (id << 14) | (color << 30) | (hue << 38)
end

function namje_binarySerializer.unpack_tile(packed)
    return packed & 0x3FFF, (packed >> 14) & 0xFFFF, (packed >> 30) & 0xFF, (packed >> 38) & 0xFF
end

-- object: x 12 bits, y 12 bits, id 16 bits, direction 1 bit
function namje_binarySerializer.pack_object(x, y, id, direction)
    return x | (y << 12) | (id << 24) | (direction << 40)
end

function namje_binarySerializer.unpack_object(packed)
    return packed & 0xFFF, (packed >> 12) & 0xFFF, (packed >> 24) & 0xFFFF, (packed >> 40) & 1
end

local pack_tile, unpack_tile = namje_binarySerializer.pack_tile, namje_binarySerializer.unpack_tile
local pack_object, unpack_object = namje_binarySerializer.pack_object, namje_binarySerializer.unpack_object

-------------------------------------------------------------------------------
-- writer / reader
-------------------------------------------------------------------------------

local function new_writer()
    local buf, n = {}, 0
    local strings, string_count = {}, 0
    local w = {}

    function w.raw(s)
        n = n + 1
        buf[n] = s
    end

    function w.u8(v)
        n = n + 1
        buf[n] = CHARS[v]
    end

    function w.varint(v)
        while v & ~0x7F ~= 0 do
            n = n + 1
            buf[n] = CHARS[(v & 0x7F) | 0x80]
            v = v >> 7
        end
        n = n + 1
        buf[n] = CHARS[v]
    end

    function w.zigzag(v)
        w.varint(v >= 0 and v << 1 or ((-v) << 1) - 1)
    end

    function w.str(s)
        w.varint(#s)
        n = n + 1
        buf[n] = s
    end

    local function value(v, seen)
        local v_type = type(v)
        if v_type == "nil" then
            w.u8(TAG_NIL)
        elseif v_type == "boolean" then
            w.u8(v and TAG_TRUE or TAG_FALSE)
        elseif v_type == "number" then
            local int = math.tointeger(v)
            if int then
                if int >= 0 and int < 64 then
                    w.u8(TAG_FIXINT + int)
                else
                    w.u8(TAG_INT)
                    w.zigzag(int)
                end
            elseif v == v and sunpack("<f", spack("<f", v)) == v then
                -- only use single precision when nothing is lost
                w.u8(TAG_F32)
                w.raw(spack("<f", v))
            else
                w.u8(TAG_F64)
                w.raw(spack("<d", v))
            end
        elseif v_type == "string" then
            local index = strings[v]
            if index then
                if index < 128 then
                    w.u8(TAG_FIXREF + index)
                else
                    w.u8(TAG_STRING_REF)
                    w.varint(index)
                end
            else
                strings[v] = string_count
                string_count = string_count + 1
                w.u8(TAG_STRING)
                w.str(v)
            end
        elseif v_type == "table" then
            if seen[v] then
                error("namje // circular reference found")
            end
            seen[v] = true

            local count, max_index, is_array = 0, 0, true
            for k in pairs(v) do
                count = count + 1
                if is_array then
                    if math.type(k) == "integer" and k >= 1 then
                        if k > max_index then max_index = k end
                    else
                        is_array = false
                    end
                end
            end

            if is_array and count > 0 and max_index == count then
                w.u8(TAG_ARRAY)
                w.varint(count)
                for i = 1, count do
                    value(v[i], seen)
                end
            else
                w.u8(TAG_MAP)
                w.varint(count)
                for k, entry in pairs(v) do
                    value(k, seen)
                    value(entry, seen)
                end
            end

            seen[v] = nil
        else
            error("namje // unexpected type: " .. v_type)
        end
    end

    function w.value(v)
        value(v, {})
    end

    function w.result()
        return concat(buf, "", 1, n)
    end

    return w
end

local function truncated()
    error("namje // ship data is truncated")
end

local function new_reader(data, pos)
    local data_len = #data
    local strings, string_count = {}, 0
    local r = {}

    function r.pos()
        return pos
    end

    function r.u8()
        local b = byte(data, pos)
        if not b then truncated() end
        pos = pos + 1
        return b
    end

    function r.varint()
        local b = byte(data, pos)
        if not b then truncated() end
        pos = pos + 1
        if b < 128 then return b end

        local v, shift = b & 0x7F, 7
        repeat
            b = byte(data, pos)
            if not b then truncated() end
            pos = pos + 1
            v = v | ((b & 0x7F) << shift)
            shift = shift + 7
        until b < 128
        return v
    end

    function r.zigzag()
        local z = r.varint()
        if z & 1 == 0 then return z >> 1 end
        return -(z >> 1) - 1
    end

    function r.str()
        local len = r.varint()
        if pos + len - 1 > data_len then truncated() end
        local s = data:sub(pos, pos + len - 1)
        pos = pos + len
        return s
    end

    local function string_ref(index)
        local s = strings[index + 1]
        if not s then error("namje // invalid string reference in ship data") end
        return s
    end

    local value
    value = function()
        local tag = r.u8()
        if tag >= TAG_FIXREF then
            return string_ref(tag - TAG_FIXREF)
        elseif tag >= TAG_FIXINT then
            return tag - TAG_FIXINT
        elseif tag == TAG_NIL then
            return nil
        elseif tag == TAG_FALSE then
            return false
        elseif tag == TAG_TRUE then
            return true
        elseif tag == TAG_F32 or tag == TAG_F64 then
            if pos + (tag == TAG_F32 and 3 or 7) > data_len then truncated() end
            local v
            v, pos = sunpack(tag == TAG_F32 and "<f" or "<d", data, pos)
            return v
        elseif tag == TAG_INT then
            return r.zigzag()
        elseif tag == TAG_STRING then
            local s = r.str()
            string_count = string_count + 1
            strings[string_count] = s
            return s
        elseif tag == TAG_STRING_REF then
            return string_ref(r.varint())
        elseif tag == TAG_ARRAY then
            local t = {}
            for i = 1, r.varint() do
                t[i] = value()
            end
            return t
        elseif tag == TAG_MAP then
            local t = {}
            for _ = 1, r.varint() do
                local k = value()
                local v = value()
                if k ~= nil then t[k] = v end
            end
            return t
        end
        error("namje // unexpected value tag in ship data: " .. tag)
    end
    r.value = value

    return r
end

-------------------------------------------------------------------------------
-- regions
-------------------------------------------------------------------------------

local function write_regions(w, regions)
    local list = {}
    for region in pairs(regions) do
        list[#list + 1] = region
    end
    table.sort(list)

    w.varint(#list)
    for _, region in ipairs(list) do
        local x, y = region:match("^(%d+)%.(%d+)$")
        if x then
            w.varint(tonumber(x) + 1)
            w.varint(tonumber(y))
        else
            w.varint(0)
            w.str(region)
        end
    end
end

local function read_regions(r)
    local regions = {}
    for _ = 1, r.varint() do
        local x = r.varint()
        if x == 0 then
            regions[r.str()] = true
        else
            regions[(x - 1) .. "." .. r.varint()] = true
        end
    end
    return regions
end

--- whether the data is in the current binary format (as opposed to a legacy format)
--- @param data string
--- @returns boolean
function namje_binarySerializer.is_current(data)
    return type(data) == "string" and data:sub(1, #HEADER) == HEADER
end

--- returns the data with the ship's regions embedded, replacing any already there. used for ship codes
--- @param data string
--- @param regions table
--- @returns string
function namje_binarySerializer.attach_regions(data, regions)
    if not namje_binarySerializer.is_current(data) then
        error("namje // regions can only be attached to current ship data")
    end
    local flags = byte(data, 4)
    local rest = 5
    if flags & FLAG_REGIONS ~= 0 then
        local r = new_reader(data, 5)
        read_regions(r)
        rest = r.pos()
    end

    local w = new_writer()
    w.raw(data:sub(1, 3))
    w.u8(flags | FLAG_REGIONS)
    write_regions(w, regions)
    w.raw(data:sub(rest))
    return w.result()
end

--- returns the regions embedded in the data, or nil if there are none
--- @param data string
--- @returns table
function namje_binarySerializer.read_regions(data)
    if not namje_binarySerializer.is_current(data) or byte(data, 4) & FLAG_REGIONS == 0 then
        return nil
    end
    return read_regions(new_reader(data, 5))
end

-------------------------------------------------------------------------------
-- ship data
-------------------------------------------------------------------------------

local function write_runs(w, runs, origin_x, origin_y)
    w.varint(#runs)
    for i, entry in ipairs(runs) do
        local packed = entry
        if type(entry) == "table" then
            packed = entry[2]
            -- only the first run's start position is needed, every later run follows on from the previous one
            if i == 1 then
                local start = entry[1]
                w.zigzag((start & 0xFFFF) - origin_x)
                w.zigzag((start >> 16) - origin_y)
            end
        elseif i == 1 then
            error("namje // tile runs are missing a start position")
        end

        local length, id, color, hue = unpack_tile(packed)
        local has_extra = (color ~= 0 or hue ~= 0) and 1 or 0
        w.varint(length)
        w.varint((id << 1) | has_extra)
        if has_extra == 1 then
            w.u8(color)
            w.u8(hue)
        end
    end
end

local function read_runs(r, origin_x, origin_y)
    local runs = {}
    for i = 1, r.varint() do
        local start
        if i == 1 then
            local dx = r.zigzag()
            local dy = r.zigzag()
            start = ((origin_y + dy) << 16) | (origin_x + dx)
        end

        local length = r.varint()
        local id_extra = r.varint()
        local color, hue = 0, 0
        if id_extra & 1 == 1 then
            color = r.u8()
            hue = r.u8()
        end

        local packed = pack_tile(length, id_extra >> 1, color, hue)
        runs[i] = start and {start, packed} or packed
    end
    return runs
end

local function has_entries(t)
    return t ~= nil and next(t) ~= nil
end

--- serializes a ship table into binary. regions are optional, and only embedded for ship codes
--- @param ship_table table
--- @param regions table
--- @returns string
function namje_binarySerializer.pack_ship_data(ship_table, regions)
    local material_cache = ship_table[1]
    local ship_chunks = ship_table[2]
    local ship_wiring = ship_table[3] or {}
    local ship_liquids = ship_table[4] or {}
    local w = new_writer()

    w.raw(HEADER)
    w.u8(VERSION)
    w.u8(regions and FLAG_REGIONS or 0)
    if regions then
        write_regions(w, regions)
    end

    w.varint(#material_cache)
    for _, name in ipairs(material_cache) do
        w.str(name)
    end

    w.varint(#ship_chunks)
    for _, chunk in ipairs(ship_chunks) do
        local chunk_pos = chunk.pos
        local origin_x, origin_y = chunk_pos & 0x7FF, chunk_pos >> 11
        local tiles = chunk.tiles or {}
        local mods = chunk.mods or {}

        w.varint(chunk_pos)
        write_runs(w, tiles.foreground or {}, origin_x, origin_y)
        write_runs(w, tiles.background or {}, origin_x, origin_y)
        write_runs(w, mods.foreground or {}, origin_x, origin_y)
        write_runs(w, mods.background or {}, origin_x, origin_y)

        local sections = 0
        if has_entries(chunk.objs) then sections = sections | SECTION_OBJECTS end
        if has_entries(chunk.monsters) then sections = sections | SECTION_MONSTERS end
        if has_entries(chunk.npcs) then sections = sections | SECTION_NPCS end
        if has_entries(chunk.vehicles) then sections = sections | SECTION_VEHICLES end
        w.u8(sections)

        if sections & SECTION_OBJECTS ~= 0 then
            w.varint(#chunk.objs)
            for _, obj in ipairs(chunk.objs) do
                local packed, params = obj, nil
                if type(obj) == "table" then
                    packed, params = obj[1], obj[2]
                end
                local x, y, id, direction = unpack_object(packed)
                w.varint((id << 2) | (direction << 1) | (params ~= nil and 1 or 0))
                w.zigzag(x - origin_x)
                w.zigzag(y - origin_y)
                if params ~= nil then
                    w.value(params)
                end
            end
        end

        if sections & SECTION_MONSTERS ~= 0 then
            w.varint(#chunk.monsters)
            for _, monster in ipairs(chunk.monsters) do
                w.varint(monster.type or 0)
                w.zigzag((monster.pos & 0xFFFF) - origin_x)
                w.zigzag((monster.pos >> 16) - origin_y)
                w.value(monster.parameters)
            end
        end

        if sections & SECTION_NPCS ~= 0 then
            w.varint(#chunk.npcs)
            for _, npc in ipairs(chunk.npcs) do
                w.zigzag((npc.pos & 0xFFFF) - origin_x)
                w.zigzag((npc.pos >> 16) - origin_y)
                w.value(npc.species)
                w.value(npc.level)
                w.value(npc.seed)
                w.value(npc.type)
                w.value(npc.uuid)
            end
        end

        if sections & SECTION_VEHICLES ~= 0 then
            w.varint(#chunk.vehicles)
            for _, vehicle in ipairs(chunk.vehicles) do
                w.value(vehicle)
            end
        end
    end

    -- wiring is sorted, so the deltas stay small
    w.varint(#ship_wiring)
    local prev = 0
    for _, wire in ipairs(ship_wiring) do
        w.zigzag(wire - prev)
        prev = wire
    end

    -- liquids are in scan order, so consecutive positions are usually one tile apart
    w.varint(#ship_liquids)
    prev = 0
    for _, liquid in ipairs(ship_liquids) do
        local liquid_pos = liquid & 0x3FFFFF
        w.zigzag(liquid_pos - prev)
        prev = liquid_pos
        w.varint((liquid >> 22) & 0xFF)
        w.varint(liquid >> 30)
    end

    return w.result()
end

local function unpack_current(ship_data)
    local r = new_reader(ship_data, #HEADER + 1)
    local version = r.u8()
    if version ~= VERSION then
        error("namje // unsupported ship data version " .. version)
    end
    if r.u8() & FLAG_REGIONS ~= 0 then
        read_regions(r)
    end

    local material_cache = {}
    for i = 1, r.varint() do
        material_cache[i] = r.str()
    end

    local ship_chunks = {}
    for c = 1, r.varint() do
        local chunk_pos = r.varint()
        local origin_x, origin_y = chunk_pos & 0x7FF, chunk_pos >> 11
        local chunk = {pos = chunk_pos}
        chunk.tiles = {
            foreground = read_runs(r, origin_x, origin_y),
            background = read_runs(r, origin_x, origin_y)
        }
        chunk.mods = {
            foreground = read_runs(r, origin_x, origin_y),
            background = read_runs(r, origin_x, origin_y)
        }

        local sections = r.u8()

        if sections & SECTION_OBJECTS ~= 0 then
            chunk.objs = {}
            for i = 1, r.varint() do
                local header = r.varint()
                local x = origin_x + r.zigzag()
                local y = origin_y + r.zigzag()
                local packed = pack_object(x, y, header >> 2, (header >> 1) & 1)
                if header & 1 == 1 then
                    chunk.objs[i] = {packed, r.value()}
                else
                    chunk.objs[i] = packed
                end
            end
        end

        if sections & SECTION_MONSTERS ~= 0 then
            chunk.monsters = {}
            for i = 1, r.varint() do
                local monster_type = r.varint()
                local x = origin_x + r.zigzag()
                local y = origin_y + r.zigzag()
                chunk.monsters[i] = {type = monster_type, pos = (y << 16) | x, parameters = r.value()}
            end
        end

        if sections & SECTION_NPCS ~= 0 then
            chunk.npcs = {}
            for i = 1, r.varint() do
                local x = origin_x + r.zigzag()
                local y = origin_y + r.zigzag()
                local npc = {pos = (y << 16) | x}
                npc.species = r.value()
                npc.level = r.value()
                npc.seed = r.value()
                npc.type = r.value()
                npc.uuid = r.value() or ""
                chunk.npcs[i] = npc
            end
        end

        if sections & SECTION_VEHICLES ~= 0 then
            chunk.vehicles = {}
            for i = 1, r.varint() do
                chunk.vehicles[i] = r.value()
            end
        end

        ship_chunks[c] = chunk
    end

    local ship_wiring = {}
    local prev = 0
    for i = 1, r.varint() do
        prev = prev + r.zigzag()
        ship_wiring[i] = prev
    end

    local ship_liquids = {}
    prev = 0
    for i = 1, r.varint() do
        prev = prev + r.zigzag()
        local id = r.varint()
        local level = r.varint()
        ship_liquids[i] = prev | (id << 22) | (level << 30)
    end

    return {material_cache, ship_chunks, ship_wiring, ship_liquids}
end

--- deserializes binary ship data back into a ship table. accepts the current format and every legacy format
--- @param ship_data string
--- @returns table
function namje_binarySerializer.unpack_ship_data(ship_data)
    if namje_binarySerializer.is_current(ship_data) then
        return unpack_current(ship_data)
    end
    return namje_serializationCompat.unpack_ship_data_v1(ship_data)
end
