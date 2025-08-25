require "/scripts/vec2.lua"
require "/scripts/util.lua"
require "/scripts/namje_byos.lua"

function init()
    message.setHandler("namje_swap_ship", function(_, _, ply, ship)
        if not namje_byos.is_on_ship() then
            sb.logInfo("namje // stagehand called on non-shipworld, killing stagehand")
            stagehand.die()
            return
        end

        namje_byos.clear_ship_area()
        self.coroutine = namje_byos.table_to_ship(ship)
        self.ply = ply
    end)
end

function update()
    if self.coroutine and self.ply then
        local status, result = coroutine.resume(self.coroutine)
        if not status then error(result) end
        if result then
            namje_byos.move_all_to_ship_spawn()
            stagehand.die()
        end
    end
end