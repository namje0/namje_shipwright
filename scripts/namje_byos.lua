require "/scripts/vec2.lua"
require "/scripts/util.lua"

--utility module used for ship stuff

namje_byos = {}

function namje_byos.change_ships(ship_type, init, ...)
    local ship_config = root.assetJson("/atelier_ships/ships/".. ship_type .."/ship.config")
    if not ship_config then
        error("namje // ship config not found for " .. ship_type)
    end
    if ship_config.ship ~= ship_type then
        error("namje // ship config does not match ship type " .. ship_type)
    end

    sb.logInfo("namje // changing ship to " .. ship_type)

    local is_server = world.isServer()
    if is_server then
        local items = namje_byos.get_ship_items()
        local args = ...
        local ply = init and args[1] or args

        sb.logInfo("namje // changing ship on server")

        local ship_create, err = pcall(namje_byos.create_ship, ply, ship_config)
        if ship_create then
            if #items > 0 then
                world.sendEntityMessage(ply, "namje_give_cargo", items)
            end

            --create the shiplocker treasurepool on init
            if init then
                local species = args[2]
                fill_shiplocker(species)
            end

            local players = world.players()
            for _, player in ipairs (players) do
                world.sendEntityMessage(player, "namje_moveToShipSpawn")
            end
        else 
            sb.logInfo("namje === ship swap failed: " .. err)
        end
    else
        --for the client, spawn the stagehand which will call this function on the server
        sb.logInfo("namje // changing ship on client")

        if player.worldId() ~= player.ownShipWorldId() then
            error("namje // tried to change ship on client while player world id is not their ship world id")
        end

        world.spawnStagehand({1024, 1024}, "namje_ship_stagehand")
        world.sendEntityMessage("namje_ship_stagehand", "swap_ship", player.id(), ship_type, init, player.species())
    end
end

function namje_byos.create_ship(ply, ship_config)
    if world.getProperty("fu_byos") then 
        namje_byos.reset_fu_stats() 
    end
    local ship_dungeon_id = config.getParameter("shipDungeonId", 10101)
    local replace_mode = {dungeon = "namje_void", size = {512, 512}}
    local teleporter_offset = ship_config.atelier_stats.teleporter_position
    local ship_position = vec2.sub({1024, 1024}, {teleporter_offset[1], -teleporter_offset[2]})

    world.sendEntityMessage(ply, "namje_upgradeShip", ship_config.base_stats)
    
    world.placeDungeon(replace_mode.dungeon, getReplaceModePosition(replace_mode.size))
    world.placeDungeon(ship_config.ship, ship_position, ship_dungeon_id)
end

--TODO: see if some items are still missing after ship change
function namje_byos.get_ship_items()
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

function namje_byos.is_fu()
    local status, err = pcall(function()
        local fu = root.assetJson("/frackinship/configs/ships.config")
        if fu then
            return true
        end
    end)
    return false
end

function namje_byos.reset_fu_stats()
    if not namje_byos.is_fu() then return end

    local ship_stats = {
        "shipSpeed",
        "fuelEfficiency",
        "maxFuel",
        "crewSize"
    }

    local ship_capabilities = {
        "systemTravel",
        "planetTravel"
    }

    for _, stat in ipairs(ship_stats) do
        world.setProperty("fu_byos." .. stat, 0)
    end

    for _, capability in ipairs(ship_capabilities) do
        world.setProperty("fu_byos." .. capability, 0)
    end

    world.setProperty("fu_byos.group.ftlDrive", 0)
end

--only used on init
--method of grabbing racial treasure pool based on how FU does it
function fill_shiplocker(species)
    sb.logInfo("namje // creating ship locker treasure pool")

    local racial_key = root.assetJson("/ships/" .. species .. "/blockKey.config:blockKey")
    local treasure_pools
    local starter_treasure = {}

    for _, tile_info in ipairs (racial_key) do
		treasure_pools = tile_info.objectParameters and tile_info.objectParameters.treasurePools
		if treasure_pools then
			break;
		end
	end

    if not treasure_pools then
        error("namje // no treasure pools found for species " .. species)
    end
    for _, treasure_pool in ipairs (treasure_pools) do
		local treasure = root.createTreasure(treasure_pool, 0)
		starter_treasure = util.mergeTable(starter_treasure, treasure)
	end

    local objects = world.objectQuery({500, 500}, {1500, 1500})
    for _, v in ipairs (objects) do
        if string.find(world.entityName(v), "shiplocker") then
            for _,item in pairs(starter_treasure) do
                world.containerAddItems(v, item)
            end
            break
        end
    end
end

--taken from Frackin Universe
function getReplaceModePosition(size)
	local position = {1024, 1024}
	local halfSize = vec2.div(size, 2)
	position[1] = position[1] - halfSize[1]
	position[2] = position[2] + halfSize[2] + 1

	return position
end