require "/scripts/vec2.lua"
require "/scripts/util.lua"
require "/scripts/namje_byos.lua"

function init()
    message.setHandler("namje_swap_ship", function(_, _, ply, ship, region)
        if not namje_byos.is_on_ship() then
            sb.logInfo("namje // stagehand called on non-shipworld, killing stagehand")
            stagehand.die()
            return
        end
        self.coroutine = namje_byos.table_to_ship(ship, region)
        self.ply = ply
    end)
end

function update()
    if self.coroutine and self.ply then
        local status, result = coroutine.resume(self.coroutine)
        if not status then error(result) end
        if result then
            --connect wiring
            if type(result) == "table" then
                world.sendEntityMessage(self.ply, "namje_connect_wiring", result)
            end
            namje_byos.move_all_to_ship_spawn()
            stagehand.die()
        end
    end
end