require "/scripts/vec2.lua"
require "/scripts/util.lua"
require "/scripts/namje_byos.lua"

function init()
    message.setHandler("namje_swap_ship", swap_ship)
end

function swap_ship(_, _, ply, ship_type, init)
    namje_byos.change_ships_from_config(ship_type, init, ply)
    stagehand.die()
end