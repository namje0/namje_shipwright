require "/scripts/vec2.lua"
require "/scripts/util.lua"
require "/scripts/namje_byos.lua"
require "/scripts/messageutil.lua"

function init()
    message.setHandler("namje_save_ship", function(_, _, ply, slot, action, ...)
        world.sendEntityMessage(ply, "namje_ship_loading")
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
        if not status then 
            world.sendEntityMessage(self.ply, "namje_ship_loading_error")
            stagehand.die()
            error(result) 
        end
        if result then
            world.sendEntityMessage(self.ply, "namje_ship_loading_end")
            stagehand.die()
            if self.action == 1 then
                namje_byos.despawn_ship_monsters()
                namje_byos.despawn_ship_npcs()
                --deactivate all crew members on swap for FU.
                if namje_byos.is_fu() then
                    world.sendEntityMessage(self.ply, "namje_fu_deactivate_crew")
                end
            end
            world.sendEntityMessage(self.ply, "namje_receive_serialized_ship", result, self.slot, self.action, self.args)
        end
    end
end