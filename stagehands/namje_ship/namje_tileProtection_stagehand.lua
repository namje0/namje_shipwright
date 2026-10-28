require "/scripts/vec2.lua"
require "/scripts/util.lua"
require "/scripts/namje_byos.lua"

function init()
    message.setHandler("namje_set_tile_protection", function(_, _, enabled)
        if not namje_byos.is_on_ship() then
            sb.logInfo("namje // stagehand called on non-shipworld, killing stagehand")
            stagehand.die()
            return
        end
        namje_byos.set_tile_protection(enabled)
        sb.logInfo("namje // ship tile protection set to %s", enabled)
        stagehand.die()
    end)
end
