local ini = init or function() end

function init() ini()

end

function update(dt)
    local item = world.containerItemAt(pane.containerEntityId(), 0)
    if item then
        sb.logInfo("namje // inserting item into cargohold on client: " .. item.name)
        world.sendEntityMessage(pane.containerEntityId(), "namje_cargohold_insert", item)
    end
end