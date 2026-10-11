function get_ent_storage(value)
    if #value > 0 then
        return storage[value]
    else
        return storage
    end
end

function set_ent_storage(value)
    storage = value
end

function merge_ent_storage(value)
    for k, v in pairs(value) do
        storage[k] = v
    end
end