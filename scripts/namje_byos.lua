require "/scripts/vec2.lua"
require "/scripts/util.lua"
require "/scripts/rect.lua"

--utility module used for ship stuff

namje_byos = {}
namje_byos.fu_enabled = nil
namje_byos.current_ship = nil

function namje_byos.change_ships_from_config(ship_type, init, ...)
    local ship_config = root.assetJson("/namje_ships/ships/".. ship_type .."/ship.namjeship")
    if not ship_config then
        error("namje // ship config not found for " .. ship_type)
    end
    if ship_config.id ~= ship_type then
        error("namje // ship config does not match ship type " .. ship_type)
    end

    local is_server = world.isServer()
    if is_server then
        local items = init and {} or namje_byos.get_ship_items()
        local args = ...
        local ply = init and args[1] or args

        sb.logInfo("namje // changing ship to " .. ship_type .. " on server for player " .. ply)
        
        world.setProperty("namje_cargo_size", ship_config.atelier_stats.cargo_hold_size)
        local ship_create, err = pcall(namje_byos.create_ship_from_config, ply, ship_config)
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
                world.callScriptedEntity(entity_id, "mcontroller.setPosition", ship_spawn)
            end
        else 
            sb.logInfo("namje === ship swap failed: " .. err)
        end
    else
        --for the client, spawn the stagehand which will call this function on the server
        sb.logInfo("namje // changing ship to " .. ship_type .. " on client")

        if player.worldId() ~= player.ownShipWorldId() then
            error("namje // tried to change ship on client while player world id is not their ship world id")
        end

        world.spawnStagehand({1024, 1024}, "namje_shipFromConfig_stagehand")
        world.sendEntityMessage("namje_shipFromConfig_stagehand", "namje_swapShip", player.id(), ship_type, init, player.species())
    end
end

function namje_byos.change_ships_from_save(ship)
    local is_server = world.isServer()
    if is_server then
        if #ship == 0 then
            error("namje // tried to change ship from save, but ship table is empty")
        end
        local ship_create, err = pcall(namje_byos.create_ship_from_save, ship)
        if ship_create then
            sb.logInfo("namje // loaded ship from table")
        else
            sb.logInfo("namje === ship load failed: " .. err)
        end
    else
        --for the client, spawn the stagehand which will call this function on the server
        sb.logInfo("namje // changing ship using a save on client")

        if player.worldId() ~= player.ownShipWorldId() then
            error("namje // tried to change ship on client while player world id is not their ship world id")
        end

        world.spawnStagehand({1024, 1024}, "namje_shipFromSave_stagehand")
        local ship = player.getProperty("current_ship", {})
        world.sendEntityMessage("namje_shipFromSave_stagehand", "namje_swapShip", player.id(), ship)
    end
end

--[[
    saves the ship as a table of chunks and returns the table
]]
function namje_byos.ship_to_table()
    local chunks = namje_byos.get_ship_chunks()
    local ship_chunks = {}

    for _, chunk in ipairs (chunks) do
        local top_left_x = chunk.top_left[1]
        local top_left_y = chunk.top_left[2]
        local bottom_right_x = chunk.bottom_right[1]
        local bottom_right_y = chunk.bottom_right[2]

        local foreground_tiles = {}
        local background_tiles = {}
        local objects = {}
        
        local chunk_objects = world.objectQuery({top_left_x, top_left_y}, {bottom_right_x, bottom_right_y})
        for _, object_id in ipairs (chunk_objects) do
            local object_data = {}
            local pos = world.entityPosition(object_id)
            --TODO: Object Parameters, Direction, etc
            local object_parameters = world.getObjectParameter(object_id,"")
            local direction = world.isServer() and world.callScriptedEntity(object_id, "object.direction") or 0
            table.insert(object_data, object_parameters)
            table.insert(object_data, direction)

            local container_items = world.containerItems(object_id)
            if container_items then
                table.insert(object_data, world.containerItems(object_id))
            end

            table.insert(objects, {pos, object_data})
        end
        
        for x = top_left_x, bottom_right_x do
            for y = top_left_y, bottom_right_y do
                local foreground_material = world.material({x, y}, "foreground")
                local background_material = world.material({x, y}, "background")

                if foreground_material and not string.find(foreground_material, "metamaterial") then
                    -- skip metamaterials, they include objects and im pretty sure the player can't place down other metamaterials
                    local mat_color = world.materialColor({x, y}, "foreground")
                    table.insert(foreground_tiles, {{x, y}, foreground_material, mat_color})
                end

                if background_material and not string.find(background_material, "metamaterial") then
                    local mat_color = world.materialColor({x, y}, "background")
                    table.insert(background_tiles, {{x, y}, background_material, mat_color})
                end
            end
        end

        local ship_chunk = {{top_left_x, bottom_right_y}, {foreground_tiles, background_tiles, objects}}
        table.insert(ship_chunks, ship_chunk)
    end
    return ship_chunks
end

function namje_byos.load_ship_from_table(ship_chunks)
    --due to how placematerial works, we need to put an initial background wall using a dungeon. then we'll use replaceMaterial on that wall afterwards
    for _, chunk in pairs (ship_chunks) do
        local top_left_x = chunk[1][1]
        local top_left_y = chunk[1][2]

        world.placeDungeon("namje_temp_chunk", {top_left_x, top_left_y})

        local foreground_tiles = chunk[2][1]
        local background_tiles = chunk[2][2]
        local objects = chunk[2][3]

        for _, tile in pairs (foreground_tiles) do
            local place = world.placeMaterial(tile[1], "foreground", tile[2], 0, true)
            if tile[3] > 0 then
                world.setMaterialColor(tile[1], "foreground", tile[3])
            end
        end

        for _, tile in pairs (background_tiles) do
            local place = world.replaceMaterials({tile[1]}, "background", tile[2], 0, false)
            if tile[3] > 0 then
                world.setMaterialColor(tile[1], "background", tile[3])
            end
        end

        --clearing temp background
        for i = 0, 100 do
            for j = 0, 100 do
                local grid_x = top_left_x + i
                local grid_y = top_left_y - j
                local material = world.material({grid_x, grid_y}, "background")
                if material and material == "namje_indestructiblemetal" then
                    world.damageTiles({{grid_x, grid_y}}, "background", {grid_x, grid_y}, "blockish", 99999, 0)
                end
            end
        end

        --placing objects
        for _, object in pairs (objects) do
            local pos = object[1]
            local object_data = object[2]
            local parameters = object_data[1]
            local dir = object_data[2]
            local container_items = object_data[3] or nil

            local place = world.placeObject(parameters.objectName, pos, dir or 0, parameters)
            if container_items then
                local object_id = world.objectAt(pos)
                if not object_id then
                    return 
                end
                for slot, item in pairs (container_items) do
                    world.containerPutItemsAt(object_id, item, slot-1)
                end
            end
        end
    end
end

function namje_byos.create_ship_from_save(ship)
    clear_ship_area()
    namje_byos.load_ship_from_table(ship)
end

--[[
    creates a new ship using the provided .namjeship config.
    will clear out the ship area and then place a new ship at {1024,1024}
]]
function namje_byos.create_ship_from_config(ply, ship_config)
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

    namje_byos.ship_to_table()
end

function find_background_tiles(pos_x,pos_y)
    for x = pos_x, (pos_x + 99), 10 do
        for y = pos_y, (pos_y + 99), 10 do
            local material = world.material({x, y}, "background")
            if material and material ~= false then
                return true
            end
        end
    end
    return false
end

-- scans from 500,500 to 1500,1500 for tiles in chunks of 100. then returns a table of chunks with tiles in it
function namje_byos.get_ship_chunks()
    local chunks = {}
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

            --[[
                platforms and back walls arent detected by this, i'm assuming im missing platforms in the collisionSet, but starbound docs sucks
                so I couldnt find the full collisionKind list.

                as for background tiles, this is abysmal dogshit but too bad! check in intervals of 10 for background tiles in the chunk

                TODO: detect platforms
            ]]

            local collision_detected = world.rectTileCollision(rect.fromVec2(min_vec, max_vec), {"Block", "Dynamic", "Slippery"})
            if collision_detected then
                sb.logInfo(sb.print("tiles detected: ".. top_left_x .. "," .. top_left_y .. "|" .. bottom_right_x .. "," .. bottom_right_y))
                local chunk = {
                    top_left = {top_left_x, top_left_y},
                    bottom_right = {bottom_right_x, bottom_right_y}
                }
                table.insert(chunks, chunk)
            else
                if find_background_tiles(top_left_x, top_left_y) then
                    sb.logInfo(sb.print("background tiles detected: ".. top_left_x .. "," .. top_left_y .. "|" .. bottom_right_x .. "," .. bottom_right_y))
                    local chunk = {
                        top_left = {top_left_x, top_left_y},
                        bottom_right = {bottom_right_x, bottom_right_y}
                    }
                    table.insert(chunks, chunk)
                end
            end
        end
    end
    return chunks
end

-- scan from 500,500 to 1500,1500 for tiles in chunks of 100, then delete those areas with a 100x100 empty dungeon
function clear_ship_area()
    local chunks = namje_byos.get_ship_chunks()

    if #chunks == 0 then 
        return 
    end

    for _, chunk in ipairs (chunks) do
        local top_left_x = chunk.top_left[1]
        local bottom_right_y = chunk.bottom_right[2]

        world.placeDungeon("namje_void_xsmall", {top_left_x, bottom_right_y})
    end
end

-- returns a list of items found in containers on the ship
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

--[[
    Fills the ship with their racial starter treasure pool. only to be used on initial ship creation
    method of grabbing racial treasure pool based on how FU does it
    since we're using a custom cargo hold instead of the ship locker for the starter ship, we're just gonna fill random storage containers onboard the ship
]]
function fill_shiplocker(species)
    if not species then
        error("namje // no species provided to fill ship locker")
    end

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