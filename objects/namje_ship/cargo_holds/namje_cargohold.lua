local cargo_size
local ini = init or function() end

function init() ini()
    if world.type() ~= "unknown" then
        object.smash(false)
    end
    
    cargo_size = world.getProperty("namje_cargo_size", 0)
    message.setHandler("namje_cargohold_insert", insert_item)
    message.setHandler("namje_receive_item", receive_item)
end

function receive_item(_, _, args)
    local item = args[1]
    local pos = args[2]

    if not item then
        return
    end

    local cargo_hold = world.getProperty("namje_cargo_hold") or {}
    if #cargo_hold <= 0 then
        return
    end

    for k, v in pairs(cargo_hold) do
        local cargo_item = v
        if cargo_item and root.itemDescriptorsMatch(cargo_item, item, true) then
            world.spawnItem(item, pos)
            table.remove(cargo_hold, k)
            world.setProperty("namje_cargo_hold", cargo_hold)
            break
        end
    end
end

function insert_item(_, _, item)
    if not item then
        return
    end

    local container_item = world.containerItemAt(entity.id(), 0)

    if container_item and root.itemDescriptorsMatch(container_item, item, true) then
        local cargo_hold = world.getProperty("namje_cargo_hold") or {}

        if #cargo_hold >= cargo_size then
            return
        end

        world.containerTakeAll(entity.id())
        table.insert(cargo_hold, container_item)
        world.setProperty("namje_cargo_hold", cargo_hold)
    end
end

--[[
function match_item(item, item2)
    if not item or not item2 then
        return
    end

    local para_1 = {item.parameters, item.count}
    local para_2 = {item2.parameters, item2.count}

    --checking the count first
    if para_1[2] ~= para_2[2] then
        return false
    end

    local count_1 = 0
    local count_2 = 0

    for _ in pairs(para_1[1]) do
        count_1 = count_1 + 1
    end

    for _ in pairs(para_2[1]) do
        count_2 = count_2 + 1
    end

    if count_1 ~= count_2 then
        return false
    end
    
    for k, v in pairs(para_1[1]) do
        local item = para_2[1][k]
        if type(item) == "table" and type(v) == "table" then
            item = tostring(item)
            v = tostring(v)
            sb.logInfo(sb.print(item))
            sb.logInfo(sb.print(v))
        end
        if item ~= v then
            sb.logInfo("error, wrong value")
            sb.logInfo(sb.print(item))
            sb.logInfo(sb.print(v))
            return false
        end
    end

    return true
end
]]