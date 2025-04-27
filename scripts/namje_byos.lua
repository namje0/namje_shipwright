require "/scripts/vec2.lua"
require "/scripts/util.lua"
require "/scripts/rect.lua"

--utility module used for ship stuff

namje_byos = {}
namje_byos.fu_enabled = nil

function namje_byos.change_ships(ship_type, init, ...)
    local ship_config = root.assetJson("/namje_ships/ships/".. ship_type .."/ship.namjeship")
    if not ship_config then
        error("namje // ship config not found for " .. ship_type)
    end
    if ship_config.id ~= ship_type then
        error("namje // ship config does not match ship type " .. ship_type)
    end

    sb.logInfo("namje // changing ship to " .. ship_type)

    local is_server = world.isServer()
    if is_server then
        local items = init and {} or namje_byos.get_ship_items()
        local args = ...
        local ply = init and args[1] or args

        sb.logInfo("namje // changing ship on server")
        
        world.setProperty("namje_cargo_size", ship_config.atelier_stats.cargo_hold_size)
        local ship_create, err = pcall(namje_byos.create_ship, ply, ship_config)
        if ship_create then
            if #items > 0 then
                world.sendEntityMessage(ply, "namje_give_cargo", items)
            end

            --create the shiplocker treasurepool on init
            --FU also fills the shiplocker (or a random container if there is none) so just skip that part if FU is enabled
            if init and not namje_byos.is_fu() then
                local species = args[2]
                fill_shiplocker(species)
            end

            --move players to new ship spawn
            local players = world.players()
            for _, player in ipairs (players) do
                if namje_byos.is_fu() then
                    world.sendEntityMessage(player, "fs_respawn")
                else
                    world.sendEntityMessage(player, "namje_moveToShipSpawn")
                end
            end
            
            --move crew (and any other monsters/animals) to new ship spawn
            --TODO: occasional bug where they dont get moved? try to replicate more
            local ship_spawn = vec2.add(world.getProperty("namje_ship_spawn", {1024, 1024}), {0, 2})
            local entities = world.entityQuery({500, 500}, {1500, 1500}, {includedTypes = {"npc", "monster"}})
            for _, entity_id in ipairs(entities) do
                sb.logInfo(entity_id)
                world.callScriptedEntity(entity_id, "mcontroller.setPosition", ship_spawn)
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
    local ship_dungeon_id = config.getParameter("shipDungeonId", 10101)
    local ship_offset = ship_config.atelier_stats.ship_center_pos
    local ship_position = vec2.sub({1024, 1024}, {ship_offset[1], -ship_offset[2]})

    if namje_byos.is_fu() then
        namje_byos.reset_fu_stats()
    end

    world.sendEntityMessage(ply, "namje_upgradeShip", ship_config.base_stats)

    clear_ship_area()

    if type(ship_config.ship) == "table" then
        sb.logInfo("namje // placing table variant of ship")
    else
        world.placeDungeon(ship_config.ship, ship_position, ship_dungeon_id)
    end
end

--scan from 500,500 to 1500,1500 for tiles in chunks of 100, then delete those areas with a 100x100 empty dungeon
function clear_ship_area()
    local start_x = 500
    local start_y = 500

    for i = 0, 10 - 1 do
        for j = 0, 10 - 1 do
            local top_left_x = start_x + i * 100
            local top_left_y = start_y + j * 100
            local bottom_right_x = top_left_x + 100
            local bottom_right_y = top_left_y + 100

            local min_vec = {top_left_x, top_left_y}
            local max_vec = {bottom_right_x + 1, bottom_right_y + 1}

            local collision_detected = world.rectTileCollision(rect.fromVec2(min_vec, max_vec), {"Block", "Dynamic", "Slippery"})
            if collision_detected then
                sb.logInfo(sb.print("tiles detected: ".. top_left_x .. "," .. top_left_y .. "|" .. bottom_right_x .. "," .. bottom_right_y))
                world.placeDungeon("namje_void_xsmall", {top_left_x, bottom_right_y})
            end
        end
    end
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
    if namje_byos.fu_enabled == nil then
        local player_config = root.assetJson("/player.config")
        local deployment_scripts = player_config.deploymentConfig.scripts
        for i = 1, #deployment_scripts do
            if string.find(deployment_scripts[i], "fu_player_init") then
                namje_byos.fu_enabled = true
                return true
            end
        end
        namje_byos.fu_enabled = false
        return false
    else
        return namje_byos.fu_enabled
    end
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
    --since we're using a custom cargo hold instead of the ship locker for the starter ship, we're just gonna fill random storage containers onboard the ship
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

    local starter_ship_containers = {
        "wrecklocker",
        "bunkerdesk",
        "outpostcargocrate",
        "outpostcargocrateshort",
        "industrialcrate"

    }
    local containers = {}
    local objects = world.objectQuery({500, 500}, {1500, 1500})
    for _, v in ipairs (objects) do
        for _, container in ipairs (starter_ship_containers) do
            if string.find(world.entityName(v), container) then
                table.insert(containers, v)
            end
        end
    end

    if #containers > 0 then
        for _, item in ipairs(starter_treasure) do
            world.containerAddItems(containers[math.random(1,#starter_ship_containers)], item)
        end
    else
        error("namje // no ship locker found to fill with treasure")
    end
end