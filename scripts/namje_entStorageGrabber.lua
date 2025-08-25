function get_ent_storage(value)
    if #value > 0 then
        return storage[value]
    else
        return storage
    end
end

function set_ent_storage(values)
    for k, v in pairs(values) do
        storage[k] = v
    end
end