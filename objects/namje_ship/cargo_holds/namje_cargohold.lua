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

function receive_item(_, _, args, world_id)
    local item = args[1]
    local pos = args[2]

    if not item then
        return
    end

    local cargo_hold = world.getProperty("namje_cargo_hold", {})
    if #cargo_hold <= 0 then
        return
    end

    for k, v in pairs(cargo_hold) do
        local cargo_item = v
        if cargo_item and root.itemDescriptorsMatch(cargo_item, item, true) and cargo_item.count == item.count then
            world.spawnItem(item, pos)
            table.remove(cargo_hold, k)
            world.setProperty("namje_cargo_hold", cargo_hold)
            break
        end
    end

    local uuid = world_id:match("ClientShipWorld:(.*)")
    if uuid then
        world.sendEntityMessage(uuid, "namje_upd_cargoinfo", cargo_hold)
    end
end

function insert_item(_, _, item, world_id)
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


        local uuid = world_id:match("ClientShipWorld:(.*)")
        if uuid then
            world.sendEntityMessage(uuid, "namje_upd_cargoinfo", cargo_hold)
        end
    end
end