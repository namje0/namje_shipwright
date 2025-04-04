require "/scripts/vec2.lua"
require "/scripts/util.lua"
require "/scripts/namje_byos.lua"

function init()
    message.setHandler("swap_ship", swap_ship)
end

function swap_ship(_, _, ply, ship_type, init, ...)
    if init then
        local species = ...
        namje_byos.change_ships(ship_type, init, {ply, species})
    else
        namje_byos.change_ships(ship_type, init, ply)
    end
    stagehand.die()
end