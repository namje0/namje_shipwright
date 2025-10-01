require "/scripts/namje_byos.lua"
local original_upd = update or function(dt) end

function update(dt) original_upd(dt)
    if not namje_byos.is_on_ship() then
        return
    end
end