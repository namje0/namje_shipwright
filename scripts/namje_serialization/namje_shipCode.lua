require "/scripts/namje_byos.lua"
require "/scripts/namje_serialization/namje_shipBinarySerializer.lua"
require "/scripts/namje_serialization/namje_b64.lua"

namje_shipCode = {}

--- generates a ship code from the ship binary data and regions table. returns the base64 ship code
--- @param data string
--- @param regions table
--- @returns string
function namje_shipCode.generate_ship_code(data, regions)
    local prefix = "namjeShip::"
    local compressed_regions = {}
    for k, _ in pairs(regions) do
        table.insert(compressed_regions, k)
    end
    local code = prefix .. namje_b64.encode(table.concat(compressed_regions, "|") .. ":" .. data)
    return code
end

--- decodes a ship code. returns the region and data
--- @param string code
--- @returns table, string
function namje_shipCode.decode_ship_code(code)
    local prefix = "namjeShip::"

    if not (code:sub(1, #prefix) == prefix) then
        return nil, nil
    end

    local encoded_payload = code:sub(#prefix + 1)
    local decoded_string = namje_b64.decode(encoded_payload)
    
    local region_part, data = decoded_string:match("^([^:]*):(.*)$")
    if not region_part or not data then
        return nil, nil
    end

    local region_list = {}
    for region in string.gmatch(region_part, "([^|]+)") do
        table.insert(region_list, region)
    end
    
    local regions = {}
    for _, region in ipairs(region_list) do
        regions[region] = true
    end
    return regions, data
end