require "/scripts/vec2.lua"
require "/scripts/util.lua"
require "/scripts/namje_byos.lua"

function init()
    message.setHandler("swap_ship", swap_ship)
end

function swap_ship(_, _, ply, ship_type)
    local ship_items = get_ship_items()
    local ship_create, err = pcall(create_ship, ply, ship_type)
    if ship_create then
        give_cargo(ply, ship_items)

        local players = world.players()
        for _, player in ipairs (players) do
            world.sendEntityMessage(player, "fs_respawn")
        end
    else 
        sb.logInfo("namje === ship swap failed: " .. err)
    end

    stagehand.die()
end

-- returns a list of every item stored in containers in the ship
--TODO: some containers seem to be ignored?
function get_ship_items()
    local items = {}
    local objects = world.objectQuery({500, 500}, {1500, 1500})
    for _, v in ipairs (objects) do
        local container_items = world.containerItems(v)
        if container_items then
            for _, i in ipairs (container_items) do
                table.insert(items, i)
            end
        end
    end
    return items
end

function give_cargo(ply, items)
    --Honestly I have no clue if i can get the player from their id and give it normally, this is defeat
    --ply.giveItem(cargo_box)
    world.sendEntityMessage(ply, "namje_give_cargo", items)
end

function create_ship(ply, ship_type)
    namje_byos.spawn_ship(ship_type)
end