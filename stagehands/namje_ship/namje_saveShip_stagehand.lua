require "/scripts/vec2.lua"
require "/scripts/util.lua"
require "/scripts/namje_byos.lua"
require "/scripts/messageutil.lua"

function init()
    message.setHandler("namje_save_ship", function(_, _, ply, slot, action, ...)
        world.setProperty("namje_ship_loading", true)
        self.coroutine = namje_byos.ship_to_table()
        self.ply = ply
        self.slot = slot
        self.action = action
        self.args = {...}
    end)
end

function update()
    if self.coroutine and self.ply then
        local status, result = coroutine.resume(self.coroutine)
        if not status then error(result) end
        if result then
            world.setProperty("namje_ship_loading", false)
            stagehand.die()
            if self.action == 1 then
                namje_byos.despawn_ship_monsters()
            end
            world.sendEntityMessage(self.ply, "namje_receive_serialized_ship", result, self.slot, self.action, self.args)
        end
    end
end