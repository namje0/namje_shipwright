require "/scripts/vec2.lua"
require "/scripts/util.lua"
require "/scripts/rect.lua"
require "/scripts/messageutil.lua"

--utility module used for ship stuff

namje_byos = {}
namje_byos.fu_enabled = nil
namje_byos.current_ship = nil

function namje_byos.get_ship_info()
    local default = {
        ship_id = "namje_startership",
        stats = {
            crew_amount = 0,
            cargo_hold = {},
            fuel_amount = 0
        },
        upgrades = {
            fuel_efficiency = 0,
            max_fuel = 0,
            ship_speed = 0,
            crew_size = 0
        }
    }

    if world.isClient() then
        return player.getProperty("namje_ship_info", default)
    else
        error("namje // get_ship_info cannot be called on server")
    end
end

function namje_byos.set_ship_info(player_id, ship_info)
    if world.isClient() then
        player.setProperty("namje_ship_info", ship_info)
    else
        world.sendEntityMessage(player_id, "namje_set_shipinfo")
    end
end

function namje_byos.change_ships_from_config(ship_type, init, ...)
    local ship_config = namje_byos.get_ship_config(ship_type)
    if not ship_config then
        error("namje // ship config not found for " .. ship_type)
    end
    if ship_config.id ~= ship_type then
        error("namje // ship config does not match ship type " .. ship_type)
    end

    if world.isServer() then
        local items = init and {} or namje_byos.get_ship_items()
        local args = ...
        local ply = init and args[1] or args

        sb.logInfo("namje // changing ship to " .. ship_type .. " on server for player " .. ply)
        
        world.setProperty("namje_cargo_size", ship_config.atelier_stats.cargo_hold_size)

        local previous_ship = not init and namje_byos.ship_to_table(true) or nil
    
        local ship_create, err = pcall(namje_byos.create_ship_from_config, ply, ship_config)
        if ship_create then
            if previous_ship then
                world.sendEntityMessage(ply, "namje_save_prev_ship", previous_ship)
            end
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

            world.sendEntityMessage(ply, "namje_upd_shipinfo_from_config", ship_config.id)
        else 
            sb.logInfo("namje === ship swap failed: " .. err)
            --TODO: revert to previous_ship
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

--- changes ship from a table, comprised of the ship_info and the serialized ship
--- @param ship table
function namje_byos.change_ships_from_table(ship, ply)
    if world.isServer() then
        if #ship == 0 then
            error("namje // tried to change ship from save, but ship table is empty")
        end
        local ship_create, err = pcall(namje_byos.create_ship_from_save, ship[1])
        if ship_create then
            sb.logInfo("namje // loaded ship from table")

            --move players to new ship spawn
            local players = world.players()
            for _, player in ipairs (players) do
                if namje_byos.is_fu() then
                    world.sendEntityMessage(player, "fs_respawn")
                else
                    world.sendEntityMessage(player, "namje_moveToShipSpawn")
                end
            end

            world.sendEntityMessage(ply, "namje_upd_shipinfo_from_config", ship[2].ship_id)
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
        world.sendEntityMessage("namje_shipFromSave_stagehand", "namje_swapShip", player.id(), ship)
    end
end

--[[
    saves the ship as a table of chunks and returns the table
]]
function namje_byos.ship_to_table(exclude_items)
    if not world.isServer() then
        --getting an object's direction isn't available on the client
        error("namje // saving ship to table is not supported on client")
    end

    local chunks = namje_byos.get_ship_chunks()
    local mat_cache = {}
    local mat_to_id = {}
    local ship_chunks = {}
    local next_mat_id = 1

    local function get_cached_mat_id(material_name)
        -- skip metamaterials, they include objects and im pretty sure the player can't place down other metamaterials
        if material_name == nil or not material_name or material_name and string.find(material_name, "metamaterial") then
            if material_name == nil then
                sb.logInfo("namje // WARNING: material_name returned nil, chunk is unloaded. ship will be incomplete")
            end
            return nil
        end

        if mat_to_id[material_name] then
            return mat_to_id[material_name]
        else
            local id = next_mat_id
            mat_to_id[material_name] = id
            mat_cache[id] = material_name
            next_mat_id = next_mat_id + 1
            return id
        end
    end

    --TODO: still doesn't get all dupes, fix later
    local function trim_params(current_params, default_params)
        if type(current_params) ~= "table" or type(default_params) ~= "table" then
            return
        end

        for k, v in pairs(current_params) do
            local default_v = default_params[k]

            if type(v) == "table" and type(default_v) == "table" then
                trim_params(v, default_v)
                local is_table_empty = true
                for _ in pairs(v) do
                    is_table_empty = false
                    break
                end
                if is_table_empty and default_v ~= nil then
                    current_params[k] = nil
                end
            elseif v == default_v then
                current_params[k] = nil
            end
        end
    end

    for _, chunk in ipairs (chunks) do
        local top_left_x = chunk.top_left[1]
        local top_left_y = chunk.top_left[2]
        local bottom_right_x = chunk.bottom_right[1]
        local bottom_right_y = chunk.bottom_right[2]

        --TODO: tile hue shift
        local foreground_tiles = {}
        local background_tiles = {}
        local objects = {}
        local mods = {}
        
        local chunk_objects = world.objectQuery({top_left_x, top_left_y}, {bottom_right_x, bottom_right_y})
        for _, object_id in ipairs (chunk_objects) do
            local object_data = {}
            local pos = world.entityPosition(object_id)
            local object_parameters = world.getObjectParameter(object_id,"")

            local temp_obj_item = root.itemConfig(object_parameters.objectName)
            local old_parameters = temp_obj_item.config

            local direction = world.callScriptedEntity(object_id, "object.direction") or 0

            table.insert(object_data, get_cached_mat_id(object_parameters.objectName))

            trim_params(object_parameters, old_parameters)

            table.insert(object_data, object_parameters)
            table.insert(object_data, direction)

            if not exclude_items then
                local container_items = world.containerItems(object_id)
                if container_items then
                    table.insert(object_data, container_items)
                end
            end

            --[[
                very jank system:
                for crafting stations with upgrade stages that were upgraded without being broken and placed again, the upgradeStage is still set to the
                lowest tier; in upgradeablecraftingobject.lua the upgrade stage is only set for the item drop on 'die', so we will
                call die on the object, get the item drop, get the upgrade stage parameters, then add it to the object data table.
            ]]
            local object_upgrade_stage = world.callScriptedEntity(object_id, "currentStageData")
            if object_upgrade_stage then
                world.callScriptedEntity(object_id, "die")
                local item_drops = world.itemDropQuery(pos, 5)
                if #item_drops > 0 then
                    for _, item_drop in ipairs (item_drops) do
                        local descriptor = world.itemDropItem(item_drop)
                        if descriptor.name == object_parameters.objectName then
                            local params = descriptor.parameters
                            local starting_stage = params.startingUpgradeStage or 0
                            object_parameters["startingUpgradeStage"] = starting_stage
                            world.takeItemDrop(item_drop)
                            break
                        end
                    end
                end
            end

            table.insert(objects, {pos, object_data})
        end
        
        for x = top_left_x, bottom_right_x do
            for y = top_left_y, bottom_right_y do
                local foreground_material = world.material({x, y}, "foreground")
                local background_material = world.material({x, y}, "background")
                local fore_mod = world.mod({x, y}, "foreground")
                local back_mod = world.mod({x, y}, "background")

                local foreground_mat_id = get_cached_mat_id(foreground_material)
                local background_mat_id = get_cached_mat_id(background_material)
                if foreground_mat_id then
                    local mat_color = world.materialColor({x, y}, "foreground")
                    table.insert(foreground_tiles, {{x, y}, foreground_mat_id, mat_color})
                end
                if background_mat_id then
                    local mat_color = world.materialColor({x, y}, "background")
                    table.insert(background_tiles, {{x, y}, background_mat_id, mat_color})
                end
                if fore_mod then
                    local mod_hue = world.modHueShift({x, y}, "foreground")
                    table.insert(mods, {{x, y}, "foreground", fore_mod, mod_hue})
                end
                if back_mod then
                    local mod_hue = world.modHueShift({x, y}, "background")
                    table.insert(mods, {{x, y}, "background", back_mod, mod_hue})
                end
            end
        end

        local ship_chunk = {{top_left_x, bottom_right_y}, {foreground_tiles, background_tiles, objects, mods}}
        table.insert(ship_chunks, ship_chunk)
    end
    return {mat_cache, ship_chunks}
end

function namje_byos.load_ship_from_table(ship_table)
    if not world.isServer() then
        error("namje // loading ship from table is not supported on client")
    end

    local mat_cache = ship_table[1]
    if not mat_cache then
        error("namje // no material cache found in ship table")
    end

    local total_object_count = 0
    local failed_objects = {}
    local placed_objects = 0

    --due to how placematerial works, we need to put an initial background wall using a dungeon. then we'll use replaceMaterial on that wall afterwards
    for _, chunk in pairs (ship_table[2]) do
        local top_left_x = chunk[1][1]
        local top_left_y = chunk[1][2]

        world.placeDungeon("namje_temp_chunk", {top_left_x, top_left_y})

        local foreground_tiles = chunk[2][1]
        local background_tiles = chunk[2][2]
        local objects = chunk[2][3]
        local mods = chunk[2][4]

        for _, tile in pairs (foreground_tiles) do
            local pos = tile[1]
            local material_id = tile[2]
            local mat_color = tile[3]
            local material_name = mat_cache[material_id]

            if material_name then
                world.placeMaterial(pos, "foreground", material_name, 0, true)
                if mat_color > 0 then
                    world.setMaterialColor(pos, "foreground", mat_color)
                end
            end
        end

        for _, tile in pairs (background_tiles) do
            local pos = tile[1]
            local material_id = tile[2]
            local mat_color = tile[3]
            local material_name = mat_cache[material_id]

            if material_name then
                world.replaceMaterials({pos}, "background", material_name, 0, false)
                if mat_color > 0 then
                    world.setMaterialColor(pos, "background", mat_color)
                end
            end
        end

        for _, mod in pairs (mods) do
            local place = world.placeMod(mod[1], mod[2], mod[3], mod[4], true)
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
        total_object_count = total_object_count + #objects
        for _, object in pairs (objects) do
            local pos = object[1]
            local object_data = object[2]
            local object_id = object_data[1]
            local parameters = object_data[2]
            local dir = object_data[3]
            local container_items = object_data[4] or nil
            local object_name = mat_cache[object_id]

            if not object_name then
                error("namje // no object name found for object id " .. material_id .. " in object " .. object_id)
            end

            local place = world.placeObject(object_name, pos, dir or 0, parameters)
            if place then
                if container_items then
                    local object_id = world.objectAt(pos)
                    if not object_id then
                        return 
                    end
                    for slot, item in pairs (container_items) do
                        world.containerPutItemsAt(object_id, item, slot-1)
                    end
                end
                placed_objects = placed_objects + 1
            else
                sb.logInfo("namje // failed to place object " .. mat_cache[object[2][1]] .. " at " .. object[1][1] .. "," .. object[1][2])
                table.insert(failed_objects, object)
            end
        end
    end

    -- get the failed object placements and try to place them here recursively
    local iterations = 0
    local iteration_cap = 500
    if #failed_objects > 0 then
        while placed_objects < total_object_count do
            for k, object in ipairs (failed_objects) do
                local pos = object[1]

                if world.objectAt(pos) then
                    placed_objects = placed_objects + 1
                    table.remove(failed_objects, k)
                else
                    local object_data = object[2]
                    local object_id = object_data[1]
                    local parameters = object_data[2]
                    local dir = object_data[3]
                    local container_items = object_data[4] or nil
                    local object_name = mat_cache[object_id]

                    if not object_name then
                        error("namje // no object name found for object id " .. material_id .. " in object " .. object_id)
                    end

                    local place = world.placeObject(object_name, pos, dir or 0, parameters)

                    if place then
                        if container_items then
                            local object_id = world.objectAt(pos)
                            if not object_id then
                                return 
                            end
                            for slot, item in pairs (container_items) do
                                world.containerPutItemsAt(object_id, item, slot-1)
                            end
                        end
                        placed_objects = placed_objects + 1
                        table.remove(failed_objects, k)
                    end
                end
            end
            iterations = iterations + 1
            if iterations >= iteration_cap then
                sb.logInfo("namje // object placing timed out after " .. iteration_cap)
                for k, object in pairs (failed_objects) do
                    sb.logInfo("namje // failed to place object " .. object[2][1].objectName .. " at " .. object[1][1] .. "," .. object[1][2])
                end
                break
            end
        end
        sb.logInfo("namje // complete object placement after " .. iterations .. " attempts")
    else
        sb.logInfo("namje // no failed objects")
    end
    
end

--- creates a new ship using the provided ship table. will clear out the ship area and then place a new ship at {1024,1024}
--- @param ship table
--TODO: change ship_info back
function namje_byos.create_ship_from_save(ship)
    clear_ship_area()
    namje_byos.load_ship_from_table(ship)
end

--- creates a new ship using the provided .namjeship config. will clear out the ship area and then place a new ship at {1024,1024}
--- @param ply string
--- @param ship_config table
function namje_byos.create_ship_from_config(ply, ship_config)
    local ship_dungeon_id = config.getParameter("shipDungeonId", 10101)
    local ship_offset = ship_config.atelier_stats.ship_center_pos
    local ship_position = vec2.sub({1024, 1024}, {ship_offset[1], -ship_offset[2]})

    clear_ship_area()

    if type(ship_config.ship) == "table" then
        sb.logInfo("namje // placing table variant of ship")
        namje_byos.load_ship_from_table(ship_config.ship)
    else
        world.placeDungeon(ship_config.ship, ship_position, ship_dungeon_id)
    end

    --namje_byos.ship_to_table()

    if namje_byos.is_fu() then
        namje_byos.reset_fu_stats()
    end

    world.sendEntityMessage(ply, "namje_upgradeShip", ship_config.base_stats)
end

--- finds background tiles in a 100x100 area starting from pos_x, pos_y. returns true if any background tiles are found, false otherwise
--- @param pos_x number
--- @param pos_y number
--- @return boolean
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

--- scans from 500,500 to 1500,1500 for tiles in chunks of 100. then returns a table of chunks with tiles in it
--- @return table
function namje_byos.get_ship_chunks()
    local chunks = {}
    local start_x = 500
    local start_y = 500

    for i = 0, 10 - 1 do
        for j = 0, 10 - 1 do
            local top_left_x = start_x + i * 100
            local top_left_y = start_y + j * 100
            local bottom_right_x = top_left_x + 99
            local bottom_right_y = top_left_y + 99

            local min_vec = {top_left_x, top_left_y}
            local max_vec = {bottom_right_x + 1, bottom_right_y + 1}

            --[[
                platforms and back walls arent detected by this, i'm assuming im missing platforms in the collisionSet, but starbound docs sucks
                so I couldnt find the full collisionKind list.

                as for background tiles, this is abysmal dogshit but too bad! check in intervals of 10 for background tiles in the chunk

                TODO: detect platforms, detect objects; it only grabs foreground/background tiles atm
            ]]

            local collision_detected = world.rectTileCollision(rect.fromVec2(min_vec, max_vec), {"Block", "Dynamic", "Slippery"})
            if collision_detected then
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

--- scan from 500,500 to 1500,1500 for tiles in chunks of 100, then delete those areas with a 100x100 empty dungeon
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

--- returns a list of items found in containers on the ship
--- @return table
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

--- returns true if the Frackin Universe mod is enabled, false otherwise
--- @return boolean
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

--- returns true if the player is on a ship, false otherwise
--- @return boolean
function namje_byos.is_on_ship()
    if world.isClient() then
        return string.find(player.worldId(), "ClientShipWorld") ~= nil
    else
        error("namje // is_on_ship cannot be called on server")
    end
end

--- returns true if the player is on their own ship, false otherwise
--- @return boolean
function namje_byos.is_on_own_ship()
    if world.isClient() then
        return player.worldId() == player.ownShipWorldId()
    else
        error("namje // is_on_own_ship cannot be called on server")
    end
end

--- returns the ship config for the given ship_id, or nil if not found
--- @param ship_id string
--- @return table|nil
function namje_byos.get_ship_config(ship_id)
    local ship_configs = root.assetsByExtension("namjeship")
    for i = 1, #ship_configs do
        local config = root.assetJson(ship_configs[i])
        if config.id == ship_id then
            return config
        end
    end
    return nil
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