function init()
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