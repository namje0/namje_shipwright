local ini = init or function() end

function init() ini()
    message.setHandler("namje_return_crew", function() 
        return playerCompanions.getCompanions("crew")
    end)
    message.setHandler("namje_dismiss_crew", function(_, _, uuid) 
        local recruit = recruitSpawner:getRecruit(uuid)
        recruitSpawner:dismiss(uuid)
        recordEvent(entity.id(), "dismissCrewMember", recruitSpawner:eventFields(), recruit:eventFields())
    end)
end