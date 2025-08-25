require "/scripts/vec2.lua"
require "/scripts/util.lua"
require "/scripts/namje_byos.lua"
require "/scripts/messageutil.lua"

function init()
    message.setHandler("namje_save_ship", function(_, _, ply, slot, action, ...)
        local region = {0, 0, 1000, 1000}
        --TODO: loadregion increases load time a fair bit. problem for bigger map sizes?
        world.loadRegion(region)
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
            stagehand.die()
            world.sendEntityMessage(self.ply, "namje_receive_serialized_ship", result, self.slot, self.action, self.args)
        end
    end
end