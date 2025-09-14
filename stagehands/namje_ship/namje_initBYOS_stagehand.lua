require "/scripts/vec2.lua"
require "/scripts/util.lua"
require "/scripts/namje_byos.lua"

local CHUNK_SIZE = 128

local function get_vanilla_chunks()
    local chunks = {}
    local start_x = 768
    local start_y = 768

    local num_chunks_x = 4
    local num_chunks_y = 4

    for i = 0, num_chunks_x - 1 do
        for j = 0, num_chunks_y - 1 do
            local chunk_bl_x = start_x + i * CHUNK_SIZE
            local chunk_bl_y = start_y + j * CHUNK_SIZE

            local chunk_tr_x = chunk_bl_x + CHUNK_SIZE - 1
            local chunk_tr_y = chunk_bl_y + CHUNK_SIZE - 1

            local collision_check_min_vec = {chunk_bl_x, chunk_bl_y}
            local collision_check_max_vec = {chunk_tr_x + 1, chunk_tr_y + 1}

            local collision_detected = world.rectTileCollision(rect.fromVec2(
                collision_check_min_vec,
                collision_check_max_vec
            ), {"Block", "Dynamic", "Slippery"})

            if collision_detected then
                local chunk = {
                bottom_left = {chunk_bl_x, chunk_bl_y},
                top_right = {chunk_tr_x, chunk_tr_y}
                }
                table.insert(chunks, chunk)
            else
                if namje_util.find_background_tiles(chunk_bl_x, chunk_bl_y) then
                    local chunk = {
                        bottom_left = {chunk_bl_x, chunk_bl_y},
                        top_right = {chunk_tr_x, chunk_tr_y}
                    }
                    table.insert(chunks, chunk)
                end
            end
        end
    end
    return chunks
end

function init()
    if not string.find(world.id(), "ClientShipWorld") then
        error("namje_initBYOS_stagehand // world is not a shipworld. this should never happen")
    end

    --clear out the original vanilla ship area, and then decrease the world size.
    local chunks = get_vanilla_chunks()
    for _, chunk in ipairs (chunks) do
        local top_left_x = chunk.bottom_left[1]
        local bottom_right_y = chunk.top_right[2]

        world.placeDungeon("namje_void_xsmall", {top_left_x, bottom_right_y})
        sb.logInfo("place at %s, %s", top_left_x, bottom_right_y)
    end
    stagehand.die()
end