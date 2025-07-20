require "/scripts/vec2.lua"
require "/scripts/util.lua"
require "/scripts/namje_byos.lua"

function init()
    message.setHandler("namje_swapShip", swap_ship)
end

function swap_ship(_, _, ply, ship)
    namje_byos.change_ships_from_table(ship)
    stagehand.die()
end