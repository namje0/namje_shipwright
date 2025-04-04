require("/scripts/namje_byos.lua")

local namje_oldInit = init or function() end
init = function() 
    --FU overwrites the entire cockpit lua and config, so we just run the old init.
    --TODO: come back when actually dealing with FU compatability and see if this is nessecary
    if namje_byos.is_fu() then
        namje_oldInit()
    else
        --unneeded right now, delete hook if we dont use this
        namje_oldInit()
    end
end