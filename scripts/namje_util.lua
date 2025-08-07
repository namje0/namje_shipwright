namje_util = {}

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
