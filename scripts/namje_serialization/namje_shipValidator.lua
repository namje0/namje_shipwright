require "/scripts/namje_serialization/namje_shipBinarySerializer.lua"

namje_shipValidator = {}

local material_cache = {}
local mod_cache = {}
local object_cache = {}

local unpack_tile, unpack_object = namje_binarySerializer.unpack_tile, namje_binarySerializer.unpack_object

function namje_shipValidator.is_valid_material(name)
    local valid = material_cache[name]
    if valid == nil then
        local success, material_config = pcall(root.materialConfig, name)
        valid = success and material_config ~= nil
        material_cache[name] = valid
    end
    return valid
end

function namje_shipValidator.is_valid_mod(name)
    local valid = mod_cache[name]
    if valid == nil then
        local success, mod_config = pcall(root.modConfig, name)
        valid = success and mod_config ~= nil
        mod_cache[name] = valid
    end
    return valid
end

function namje_shipValidator.is_valid_object(name)
    local valid = object_cache[name]
    if valid == nil then
        local success, item_config = pcall(root.itemConfig, name)
        valid = success and item_config ~= nil
        object_cache[name] = valid
    end
    return valid
end

local function check_runs(runs, id_cache, is_valid, invalid)
    for _, entry in ipairs(runs or {}) do
        local length, id = unpack_tile(type(entry) == "table" and entry[2] or entry)
        local name = id_cache[id]
        if name and not is_valid(name) then
            invalid[name] = (invalid[name] or 0) + length
        end
    end
end

function namje_shipValidator.get_invalid_ids(ship_table)
    local id_cache = ship_table[1]
    local invalid = {tiles = {}, mods = {}, objects = {}}

    for _, chunk in ipairs(ship_table[2]) do
        local tiles = chunk.tiles or {}
        local mods = chunk.mods or {}
        check_runs(tiles.foreground, id_cache, namje_shipValidator.is_valid_material, invalid.tiles)
        check_runs(tiles.background, id_cache, namje_shipValidator.is_valid_material, invalid.tiles)
        check_runs(mods.foreground, id_cache, namje_shipValidator.is_valid_mod, invalid.mods)
        check_runs(mods.background, id_cache, namje_shipValidator.is_valid_mod, invalid.mods)

        for _, obj in ipairs(chunk.objs or {}) do
            local _, _, id = unpack_object(type(obj) == "table" and obj[1] or obj)
            local name = id_cache[id]
            if name and not namje_shipValidator.is_valid_object(name) then
                invalid.objects[name] = (invalid.objects[name] or 0) + 1
            end
        end
    end

    return invalid
end

function namje_shipValidator.has_invalid_ids(invalid)
    return next(invalid.tiles) ~= nil or next(invalid.mods) ~= nil or next(invalid.objects) ~= nil
end
