require "/scripts/namje_byos.lua"
require "/scripts/namje_util.lua"
require "/scripts/rect.lua"
require "/scripts/util.lua"

local CHUNK_SIZE = 32
local DEBUG = true

local on_ship = false
local on_own_ship = false

function init()
    if not namje_byos.is_on_ship() then
        on_ship = false
    else
        on_ship = true
    end
    if namje_byos.is_on_own_ship() then
        on_own_ship = true
    else
        on_own_ship = false
    end
    if DEBUG then
        util.setDebug(true)
    end
end

function update(dt)
    if not on_ship then
        return
    end
    if world.getProperty("namje_ship_loading", false) then
        return
    end
    local player_pos = mcontroller.position()
    local start_chunk = namje_util.get_chunk(player_pos)
    local region_cache = world.getProperty("namje_region_cache", {})

    if DEBUG then
        util.debugText("Scanning chunk %s for caching", start_chunk, player_pos, "green")
        local chunks = {}
        for region, _ in pairs(region_cache) do
            local chunk = namje_util.region_decode(region)
            table.insert(chunks, chunk)
            local chunk_area = rect.fromVec2({chunk[1], chunk[2]}, {chunk[1] + (CHUNK_SIZE), chunk[2] + CHUNK_SIZE})
            util.debugRect(chunk_area, "white")
        end
        local bounding_box = namje_util.get_chunk_rect(chunks)
        util.debugRect(bounding_box, "black")
    end

    local chunks_to_scan = namje_util.get_adjacent_chunks(start_chunk)
    for i = 1, #chunks_to_scan do
        local chunk = chunks_to_scan[i]
        local chunk_area = rect.fromVec2({chunk[1], chunk[2]}, {chunk[1] + (CHUNK_SIZE), chunk[2] + CHUNK_SIZE})
        local debug_area = rect.fromVec2({chunk[1] + 0.1, chunk[2] + 0.1}, {chunk[1] + (CHUNK_SIZE - 0.1), chunk[2] + (CHUNK_SIZE - 0.1)})
        local collision_detected = world.rectTileCollision(chunk_area, {"Block", "Dynamic", "Slippery"})
        local region_cache = world.getProperty("namje_region_cache", {})
        local cache_code = string.format("%s.%s", chunk[1], chunk[2])
        
        if DEBUG then
            local color = (collision_detected or namje_util.find_background_tiles(chunk[1], chunk[2])) and "red" or "cyan"
            util.debugRect(debug_area, color)
            end

        if collision_detected then
            if not region_cache then
                return
            end
            if not region_cache[cache_code] then
                sb.logInfo("collision detected in uncached chunk, adding")
                region_cache[cache_code] = true
                world.setProperty("namje_region_cache", region_cache)
            end
        else
            if namje_util.find_background_tiles(chunk[1], chunk[2]) then
                if not region_cache[cache_code] then
                    sb.logInfo("wall detected in uncached chunk, adding")
                    region_cache[cache_code] = true
                    world.setProperty("namje_region_cache", region_cache)
                end
            else
                if region_cache[cache_code] then
                    sb.logInfo("collision not detected in cached chunk, removing")
                    region_cache[cache_code] = nil
                    world.setProperty("namje_region_cache", region_cache)
                end
            end
        end
    end
    if DEBUG then
        local bounding_box = namje_util.get_chunk_rect(chunks_to_scan)
        util.debugRect(bounding_box, "green")
    end
end