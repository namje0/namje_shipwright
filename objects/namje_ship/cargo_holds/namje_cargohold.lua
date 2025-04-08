local slot_size
local ini = init or function() end

function init() ini()
    local id = world.id()
    if not string.find(id, "ClientShipWorld") then
        object.smash(false)
    end
    
    slot_size = world.getProperty("namje_cargo_size") or 0
    message.setHandler("namje_cargohold_insert", insert_item)
end


function insert_item(_, _, item)
    if not item then
        return
    end
    world.containerTakeAll(entity.id())
    sb.logInfo("namje // inserting item into cargohold: " .. item.name)

    local cargo_hold = world.getProperty("namje_cargo_hold") or {}
    table.insert(cargo_hold, item)
    sb.logInfo("namje // cargo hold size: " .. #cargo_hold .. "/" .. slot_size)
end