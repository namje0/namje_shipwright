function init()
    sb.logInfo("namje // init namje_techstation.lua")

    message.setHandler("namje_set_ship_gravity", function(_, _, gravity)
        --setGravity(gravity)
        sb.logInfo("rahh")
        --local template = world.template()
        --sb.logInfo(sb.print(template))
        --world.settemplate(temp)
        --world.spawnStagehand({1024, 1024}, "namje_returnTemplate_stagehand")
        --local template = world.sendEntityMessage("namje_returnTemplate_stagehand", "namje_returnTemplate")
        --sb.logInfo(sb.print(template))
    end)
end
--[[
function onInteraction()
    if self.dialogTimer then
        sayNext()
        return nil
    else
        return config.getParameter("interactAction")
    end
end
]]