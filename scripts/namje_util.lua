

namje_util = {}

local CHUNK_SIZE = 128

--- finds background tiles in a CHUNK_SIZExCHUNK_SIZE area starting from pos_x, pos_y. returns true if any background tiles are found, false otherwise
--- @param pos_x number
--- @param pos_y number
--- @return boolean
function namje_util.find_background_tiles(pos_x,pos_y)
    for x = pos_x, (pos_x + (CHUNK_SIZE - 1)), 8 do
        for y = pos_y, (pos_y + (CHUNK_SIZE - 1)), 8 do
            local material = world.material({x, y}, "background")
            if material and material ~= false then
                return true
            end
        end
    end
    return false
end

function namje_util.deep_copy(original_table)
    local copied_table = {}
    for key, value in pairs(original_table) do
        if type(value) == "table" then
            copied_table[key] = namje_util.deep_copy(value)
        else
            copied_table[key] = value
        end
    end

    return copied_table
end

function namje_util.dict_size(dict)
    local count = 0
    for _, _ in pairs(dict) do
        count = count + 1
    end
    return count
end

--gets the bottom leftmost position of a CHUNK_SIZExCHUNK_SIZE chunk
function namje_util.get_chunk(coords)
    if not coords or type(coords) ~= "table" or not coords[1] or not coords[2] then
        return {0, 0}
    end

    local chunk_bl_x = math.floor(coords[1] / CHUNK_SIZE) * CHUNK_SIZE
    local chunk_bl_y = math.floor(coords[2] / CHUNK_SIZE) * CHUNK_SIZE

    return {chunk_bl_x, chunk_bl_y}
end

--returns a table of start_chunk and adjacent chunks
function namje_util.get_adjacent_chunks(start_chunk)
    local adjacent_chunks = {}
    local start_x = start_chunk[1]
    local start_y = start_chunk[2]

    for i = -1, 1 do
        for j = -1, 1 do
            local adjacent_x = start_x + (i * CHUNK_SIZE)
            local adjacent_y = start_y + (j * CHUNK_SIZE)
            table.insert(adjacent_chunks, {adjacent_x, adjacent_y})
        end
    end

    return adjacent_chunks
end

--gets the bounding box of the chunks
function namje_util.get_chunk_rect(chunk_table)
    if #chunk_table == 0 then
        return nil
    end

    local min_x = chunk_table[1][1]
    local min_y = chunk_table[1][2]
    local max_x = chunk_table[1][1]
    local max_y = chunk_table[1][2]

    for i = 2, #chunk_table do
        local chunk = chunk_table[i]
        local current_x = chunk[1]
        local current_y = chunk[2]

        min_x = math.min(min_x, current_x)
        min_y = math.min(min_y, current_y)
        max_x = math.max(max_x, current_x)
        max_y = math.max(max_y, current_y)
    end

    local bottom_left = {min_x, min_y}
    local top_right = {max_x + CHUNK_SIZE, max_y + CHUNK_SIZE}

    return rect.fromVec2(bottom_left, top_right)
end

function namje_util.region_decode(path)
    local new_table = {}
    for part in string.gmatch(path, "[^%.]+") do
        table.insert(new_table, tonumber(part))
    end
    return new_table
end

--- TODO: replace (requires coroutine)
--- @return table
function namje_util.get_filled_chunks(rect)
    local failed_regions = {}
    local success_regions = {}
    local chunks = {}
    local x1 = rect[1]
    local y1 = rect[2]
    local x2 = rect[3]
    local y2 = rect[4]
    local width = x2 - x1
    local height = y2 - y1
    local num_chunks_x = math.ceil(width / CHUNK_SIZE)
    local num_chunks_y = math.ceil(height / CHUNK_SIZE)

    local region_load = false
    while not region_load do
        region_load = world.loadRegion(rect)
        if not region_load then
            coroutine.yield()
        end
    end

    for i = 0, num_chunks_x - 1 do
        for j = 0, num_chunks_y - 1 do
            local chunk_bl_x = x1 + i * CHUNK_SIZE
            local chunk_bl_y = y1 + j * CHUNK_SIZE

            local chunk_tr_x = math.min(x2, chunk_bl_x + CHUNK_SIZE - 1)
            local chunk_tr_y = math.min(y2, chunk_bl_y + CHUNK_SIZE + 1)

            local min_vec = {chunk_bl_x, chunk_bl_y}
            local max_vec = {chunk_tr_x + 1, chunk_tr_y + 1}

            local to_load = {chunk_bl_x, chunk_bl_y, chunk_tr_x + 1, chunk_tr_y + 1}

            local collision_detected = world.rectTileCollision({chunk_bl_x, chunk_bl_y, chunk_tr_x + 1, chunk_tr_y + 1}, {"Platform", "Block", "Dynamic", "Slippery"})
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
            table.insert(success_regions, to_load)
        end
    end
    return chunks
end