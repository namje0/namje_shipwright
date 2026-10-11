require "/scripts/namje_byos.lua"
require "/scripts/namje_serialization/namje_shipBinarySerializer.lua"
require "/scripts/namje_serialization/namje_serializationCompat.lua"
require "/scripts/namje_serialization/namje_b64.lua"

namje_shipCode = {}

local PREFIX = "namjeShip::"

--- generates a ship code from the ship binary data and regions table. returns the compressed, base64 ship code
--- @param data string
--- @param regions table
--- @returns string
function namje_shipCode.generate_ship_code(data, regions)
    return PREFIX .. namje_b64.pack(namje_binarySerializer.attach_regions(data, regions))
end

--- decodes a ship code. returns the regions and the ship binary data, or nil if the code is invalid.
--- accepts current and legacy codes
--- @param string code
--- @returns table, string
function namje_shipCode.decode_ship_code(code)
    if not (code:sub(1, #PREFIX) == PREFIX) then
        return nil, nil
    end

    local payload = code:sub(#PREFIX + 1)
    local success, regions, data = pcall(function()
        if namje_b64.is_packed(payload) then
            local decoded = namje_b64.unpack(payload)
            if namje_binarySerializer.is_current(decoded) then
                return namje_binarySerializer.read_regions(decoded), decoded
            end
            return namje_serializationCompat.split_ship_code_v1(decoded)
        end
        return namje_serializationCompat.decode_ship_code_v1(payload)
    end)
    if not success then
        sb.logInfo("namje // failed to decode ship code: %s", regions)
        return nil, nil
    end
    if not regions or not data then
        return nil, nil
    end
    return regions, data
end
