function get_ent_storage()
    return storage
end

function set_ent_storage(values)
    for k, v in pairs(values) do
        storage[k] = v
    end
end