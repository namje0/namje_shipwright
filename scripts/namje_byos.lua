--utility module for all ship related stuff

require "/scripts/vec2.lua"
require "/scripts/util.lua"
require "/scripts/rect.lua"
require "/scripts/messageutil.lua"
require "/scripts/namje_util.lua"
require "/scripts/namje_serialization/namje_shipBinarySerializer.lua"
require "/scripts/namje_serialization/namje_shipCode.lua"

namje_byos = {}
namje_byos.current_ship = nil

--chunk size, for ship serialization purposes
local CHUNK_SIZE = 32
local VERSION_ID = "namje_shipwright"
--the upper limit of ships a player can have
local PLAYER_SHIP_CAP = 8

function namje_byos.get_ship_data()
    if world.isClient() then
        local v_json = player.getProperty("namje_ships")
        return v_json and root.loadVersionedJson(v_json, VERSION_ID) or {}
    else
        --TODO: get on server
        return nil
    end
end

function namje_byos.set_ship_data(data)
    if world.isClient() then
        local v_json = root.makeCurrentVersionedJson(VERSION_ID, data)
        player.setProperty("namje_ships", v_json)
    end
end

function namje_byos.get_ship_content(slot)
    if world.isClient() then
        local v_json = player.getProperty("namje_slot_" .. slot .. "_shipcontent")
        return v_json and root.loadVersionedJson(v_json, VERSION_ID) or nil
    else
        --TODO: get on server
        return nil
    end
end

function namje_byos.set_ship_content(slot, data)
    if world.isClient() then
        local v_json = root.makeCurrentVersionedJson(VERSION_ID, data)
        player.setProperty("namje_slot_" .. slot .. "_shipcontent", v_json)
    end
end

--- register a new ship for the player, overwriting/adding to a slot
--- @param slot number
--- @param ship_type string
--- @param name string
--- @param icon string
--- @return table
function namje_byos.register_new_ship(slot, ship_type, name, icon)
    if world.isServer() then
        error("namje_byos.register_new_ship // register_new_ship cannot be called on server")
    end

    local ship_config = namje_byos.get_ship_config(ship_type)
    local ships = namje_byos.get_ship_data()
    if not ships or not ship_config then
        error("namje_byos.register_new_ship // missing namje_ships property or namje_ship_config for " .. ship_type)
    end
    if ship_config.id ~= ship_type then
        error("namje_byos.register_new_ship // ship config does not match ship type " .. ship_type)
    end
    local ship_slot = ships["slot_" .. slot]
    if not ship_slot then
        error("namje_byos.register_new_ship // slot " .. slot .. " not found in namje_ships")
    end

    local old_stats, old_info
    if ship_slot.stats then
        old_stats = ship_slot.stats
    end
    if ship_slot.ship_info then
        old_info = ship_slot.ship_info
    end

    local ship_data = {
        ship_info = {
            ship_id = ship_config.id,
            name = name or "Unnamed Ship",
            icon = icon or "/namje_ships/ship_icons/generic_1.png",
            favorited = false
        },
        stats = {
            cached_regions = old_stats and old_stats.cached_regions or {},
            crew_amount = old_stats and old_stats.crew_amount or 0,
            cargo_hold = old_stats and old_stats.cargo_hold or {},
            fuel_amount = math.max(old_stats and old_stats.fuel_amount or 500, 500),
            celestial_pos = old_stats and old_stats.celestial_pos or {["system"] = celestial.currentSystem(), ["location"] = celestial.shipLocation()},
            modules = {}, -- return modules as items instead
        },
        upgrades = {
            fuel_efficiency = 0,
            max_fuel = 0,
            ship_speed = 0,
            crew_size = 0,
            cargo_size = 0,
            modules = 0,
        }
    }

    ships["slot_" .. slot] = ship_data

    namje_byos.set_ship_data(ships)
    if player.getProperty("namje_current_ship", 1) == slot then
        local intro = ship_config.id == "namje_startership" and true or false
        if not intro then
            local cinematic = "/cinematics/namje/shipswap.cinematic"
            player.playCinematic(cinematic)
        end
        local region_cache = world.getProperty("namje_region_cache", {})
        namje_byos.change_ships_from_config(ship_config.id, intro, region_cache)
    end

    --overwrite
    if old_info then
        local old_config = namje_byos.get_ship_config(old_info.ship_id)
        if not old_config then
            sb.logInfo("namje // error during overwrite: old ship config not found for " .. old_info.ship_id)
            return
        end

        local previous_ship_content = #namje_byos.get_ship_content(slot) > 0 and namje_binarySerializer.unpack_ship_data(namje_byos.get_ship_content(slot)) or {}
        local items = {}

        if old_stats then
            local modules = old_stats.modules
            for _, v in pairs(modules) do
                local item = {name = v, count = 1}
                table.insert(items, item)
            end
        end

        if not isEmpty(previous_ship_content) then
            for _, chunk in pairs (previous_ship_content[2]) do
                if chunk.objs and not isEmpty(chunk.objs) then
                    for _, object in pairs (chunk.objs) do
                        if type(object) == "table" then
                            local object_params = object[2]
                            if object_params then
                                local container_items = object_params.namje_container_items or nil
                                if container_items then
                                    for slot, item in pairs (container_items) do
                                        table.insert(items, item)
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
        if not isEmpty(items) then
            interface.queueMessage("^orange;Items left on your ship have been packaged for you.")
            world.sendEntityMessage(player.id(), "namje_give_cargo", items)
        end
        --TODO: include upgrade levels in refund
        local refund = math.floor(old_config.price * 0.25) or 0
        interface.queueMessage("You were given ^orange;" .. refund .. "^reset; pixels for your old ship.")
        player.addCurrency("money", refund)
    end

    namje_byos.set_ship_content(slot, "")
    return ships["slot_" .. slot]
end

function namje_byos.swap_ships(new_slot)
    if world.isServer() then
        error("namje_byos.swap_ships // swap_ships cannot be called on server")
    end

    local current_slot = player.getProperty("namje_current_ship", 1)

    world.spawnStagehand({1024, 1024}, "namje_saveShip_stagehand")
    world.sendEntityMessage("namje_saveShip_stagehand", "namje_save_ship", player.id(), current_slot, 1, {}, new_slot)
end

--- give the player num amount of ship slots if it's under the PLAYER_SHIP_CAP. returns true if the slots were added, and false if it wasnt
--- @param num number
--- @return boolean
function namje_byos.add_ship_slots(num)
    local current_slots = player.getProperty("namje_ship_slots", 0)
    local ships = namje_byos.get_ship_data()

    if current_slots + num > PLAYER_SHIP_CAP then
        return false
    end
    local num_slots = math.min(current_slots + num, PLAYER_SHIP_CAP)
    player.setProperty("namje_ship_slots", num_slots)
    for i = 1, num_slots do
        local slot = "slot_" .. i
        if not ships[slot] then
            ships[slot] = {}
            namje_byos.set_ship_content(slot, "")
        end
    end
    namje_byos.set_ship_data(ships)
    return true
end

--- sets the current ship slot for the player
--- @param slot number
function namje_byos.set_current_ship(slot)
    local current_slots = player.getProperty("namje_ship_slots", 1)
    if slot > current_slots or slot < 1 then
        error("namje // tried to set current ship to slot " .. slot .. " but only " .. current_slots .. " slots are available")
    end
    return player.setProperty("namje_current_ship", slot)
end

--- returns the stats table for the ship in the given slot
--- @param slot number
--- @return table
function namje_byos.get_stats(slot)
    local ships = namje_byos.get_ship_data()
    if not ships or not ships["slot_" .. slot] then
        return nil
    end
    local ship = ships["slot_" .. slot]
    return ship.stats or nil
end

--- sets the stats for the given ship slot. stats should be a table with the keys matching the ship stats. returns the updated stats table or nil if the slot does not exist
--- @param slot number
--- @param stats table
--- @return table
function namje_byos.set_stats(slot, stats)
    local ship_stats = namje_byos.get_stats(slot)
    if not ship_stats then
        return nil
    end
    for stat, value in pairs(stats) do
        if ship_stats[stat] ~= nil then
            ship_stats[stat] = value
        end
    end
    local ships = namje_byos.get_ship_data()
    local ship = ships["slot_" .. slot]
    ship.stats = ship_stats
    namje_byos.set_ship_data(ships)
    return ship_stats
end

--- returns the upgrades table for the ship in the given slot
--- @param slot number
--- @return table
function namje_byos.get_upgrades(slot)
    local ships = namje_byos.get_ship_data()
    if not ships or not ships["slot_" .. slot] then
        return nil
    end
    local ship = ships["slot_" .. slot]
    return ship.upgrades or nil
end

--- sets the upgrades for the given ship slot. stats should be a table with the keys matching the ship upgrades. returns the updated upgrades table or nil if the slot does not exist
--- @param slot number
--- @param upgrades table
--- @return table
function namje_byos.set_upgrades(slot, upgrades)
    local ship_upgrades = namje_byos.get_upgrades(slot)
    if not ship_upgrades then
        return nil
    end
    for upgrade, value in pairs(upgrades) do
        if ship_upgrades[upgrade] ~= nil then
            ship_upgrades[upgrade] = value
        end
    end
    local ships = namje_byos.get_ship_data()
    local ship = ships["slot_" .. slot]
    ship.upgrades = ship_upgrades
    namje_byos.set_ship_data(ships)
    return ship_upgrades
end

--- returns the ship_info table for the ship in the given slot
--- @param slot number
--- @return table
function namje_byos.get_ship_info(slot)
    local ships = namje_byos.get_ship_data()
    if not ships or not ships["slot_" .. slot] then
        return nil
    end
    local ship = ships["slot_" .. slot]
    return ship.ship_info or nil
end

--- sets the ship_info for the given ship slot. ship_info should be a table with the keys matching the ship info. returns the updated ship_info table or nil if the slot does not exist
--- @param slot number
--- @param info table
--- @return table
function namje_byos.set_ship_info(slot, info)
    local ship_info = namje_byos.get_ship_info(slot)
    if not ship_info then
        return nil
    end
    for key, value in pairs(info) do
        if ship_info[key] ~= nil then
            ship_info[key] = value
        end
    end
    local ships = namje_byos.get_ship_data()
    local ship = ships["slot_" .. slot]
    ship.ship_info = ship_info
    namje_byos.set_ship_data(ships)
    return ship_info
end

--- despawns monsters in the cached ship regions.
function namje_byos.despawn_ship_monsters()
    local region_cache = world.getProperty("namje_region_cache", {})
    local regions = {}
    local region_bounds
    if isEmpty(region_cache) then
        sb.logInfo("namje // region cache is empty, though it shouldn't be. using defaults")
        region_bounds = rect.fromVec2({974, 974}, {1074, 1074})
    else
        for region, _ in pairs(region_cache) do
            local chunk = namje_util.region_decode(region)
            table.insert(regions, chunk)
        end
        region_bounds = namje_util.get_chunk_rect(regions)
    end
    local entities = world.monsterQuery({region_bounds[1], region_bounds[2]}, {region_bounds[3], region_bounds[4]})
    for _, entity_id in ipairs(entities) do
        if entity_id > 0 then
            world.callScriptedEntity(entity_id, "monster.setDeathSound", nil)
            world.callScriptedEntity(entity_id, "monster.setDropPool", nil)
            world.callScriptedEntity(entity_id, "monster.setDeathParticleBurst", nil)
            world.callScriptedEntity(entity_id, "status.addEphemeralEffect", "namje_shipdespawn")
        end
    end
end

--- despawns npcs in the cached ship regions. ignores crewmembers.
function namje_byos.despawn_ship_npcs()
    local region_cache = world.getProperty("namje_region_cache", {})
    local regions = {}
    local region_bounds
    if isEmpty(region_cache) then
        sb.logInfo("namje // region cache is empty, though it shouldn't be. using defaults")
        region_bounds = rect.fromVec2({974, 974}, {1074, 1074})
    else
        for region, _ in pairs(region_cache) do
            local chunk = namje_util.region_decode(region)
            table.insert(regions, chunk)
        end
        region_bounds = namje_util.get_chunk_rect(regions)
    end
    local entities = world.npcQuery({region_bounds[1], region_bounds[2]}, {region_bounds[3], region_bounds[4]})
    for _, entity_id in ipairs(entities) do
        if entity_id > 0 then
            local type = world.callScriptedEntity(entity_id, "npc.npcType")
            if not string.match(type, "crewmember") then
                world.callScriptedEntity(entity_id, "monster.setDeathSound", nil)
                world.callScriptedEntity(entity_id, "monster.setDropPool", nil)
                world.callScriptedEntity(entity_id, "monster.setDeathParticleBurst", nil)
                world.callScriptedEntity(entity_id, "status.addEphemeralEffect", "namje_shipdespawn")
            end
        end
    end
end

--- moves all players on the shipworld and crewmembers to the ship spawn.
function namje_byos.move_all_to_ship_spawn()
    local players = world.players()
    for _, player in ipairs (players) do
        world.sendEntityMessage(player, "namje_moveToShipSpawn")
    end
    
    --TODO: use region_cache
    local ship_spawn = vec2.add(world.getProperty("namje_ship_spawn", {1024, 1024}), {0, 2})
    local region_cache = world.getProperty("namje_region_cache", {})
    local regions = {}
    local region_bounds
    if isEmpty(region_cache) then
        sb.logInfo("namje // region cache is empty, though it shouldn't be. using defaults")
        region_bounds = rect.fromVec2({974, 974}, {1074, 1074})
    else
        for region, _ in pairs(region_cache) do
            local chunk = namje_util.region_decode(region)
            table.insert(regions, chunk)
        end
        region_bounds = namje_util.get_chunk_rect(regions)
    end
    local entities = world.npcQuery({region_bounds[1], region_bounds[2]}, {region_bounds[3], region_bounds[4]})
    for _, entity_id in ipairs(entities) do
        local type = world.callScriptedEntity(entity_id, "npc.npcType")
        if string.match(type, "crewmember") then
            world.callScriptedEntity(entity_id, "mcontroller.setPosition", ship_spawn)
        end
    end
end

--- changes the ship using a config .namjeship file's ship_id.
--- @param ship_id string
--- @param init boolean
--- @param region table
function namje_byos.change_ships_from_config(ship_id, init, region)
    local ship_config = namje_byos.get_ship_config(ship_id)
    if not ship_config then
        error("namje // ship config not found for " .. ship_id)
    end
    if ship_config.id ~= ship_id then
        error("namje // ship config does not match ship type " .. ship_id)
    end
    --TODO: server is never used atm, but instead of ply argument do variable arg
    if world.isServer() then
        if not namje_byos.is_on_ship() then
            error("namje // tried to change ship on server while not on shipworld")
        end

        --world.spawnStagehand({1024, 1024}, "namje_shipFromConfig_stagehand")
        --world.sendEntityMessage("namje_shipFromConfig_stagehand", "namje_swap_ship", ply, ship_config, init)
    else
        --for the client, spawn the stagehand which will call this function on the server
        sb.logInfo("namje // changing ship using a save on client")

        if not namje_byos.is_on_own_ship() then
            error("namje // tried to change ship on client while player world id is not their ship world id")
        end
        if init then
            namje_byos.fill_shiplocker(player.species())
        end
        world.spawnStagehand({1024, 1024}, "namje_shipFromConfig_stagehand")
        world.sendEntityMessage("namje_shipFromConfig_stagehand", "namje_swap_ship", player.id(), ship_config, init, region)
    end
end

--- changes ship from a table, comprised of the ship_info and the serialized ship
--- @param ship table
function namje_byos.change_ships_from_table(ship, region)
    if #ship == 0 then
        error("namje // tried to change ship from save, but ship table is empty")
    end
    --TODO: server is never used atm, but instead of ply argument do variable arg
    if world.isServer() then
        if not namje_byos.is_on_ship() then
            error("namje // tried to change ship on server while not on shipworld")
        end

        world.spawnStagehand({1024, 1024}, "namje_shipFromSave_stagehand")
        world.sendEntityMessage("namje_shipFromSave_stagehand", "namje_swap_ship", player.id(), ship, region)
    else
        --for the client, spawn the stagehand which will call this function on the server
        sb.logInfo("namje // changing ship using a save on client")

        if not namje_byos.is_on_own_ship() then
            error("namje // tried to change ship on client while player world id is not their ship world id")
        end

        world.spawnStagehand({1024, 1024}, "namje_shipFromSave_stagehand")
        world.sendEntityMessage("namje_shipFromSave_stagehand", "namje_swap_ship", player.id(), ship, region)
    end
end

--- creates a new ship using the provided .namjeship config. will clear out the ship area and then place a new ship at {1024,1024}
--- @param ply string
--- @param ship_config table
function namje_byos.create_ship_from_config(ply, ship_config, ship_region)
    if not world.isServer() then
        error("namje // create_ship_from_config cannot be called on client")
    end

    local coroutine = coroutine.create(function()
        --get the cached bounds, then clear the area
        local regions = {}
        local region_bounds
        if ship_region == nil or isEmpty(ship_region) then
            sb.logInfo("namje // ship_region is empty, though it shouldn't be. using defaults")
            region_bounds = rect.fromVec2({974, 974}, {1074, 1074})
        else
            for region, _ in pairs(ship_region) do
                local chunk = namje_util.region_decode(region)
                table.insert(regions, chunk)
            end
            region_bounds = namje_util.get_chunk_rect(regions)
        end
        namje_byos.clear_ship_area(region_bounds)

        local code_prefix = "namjeShip::"
        if string.sub(ship_config.ship, 1, #code_prefix) == code_prefix then
            --TODO: get ship region and stuff nicer
            sb.logInfo("namje // placing shipcode variant of ship")
            local regions, data = namje_shipCode.decode_ship_code(ship_config.ship)

            world.spawnStagehand({1024, 1024}, "namje_shipFromSave_stagehand")
            world.sendEntityMessage("namje_shipFromSave_stagehand", "namje_swap_ship", ply, data, regions)
            world.setProperty("namje_region_cache", regions)
        else
            local ship_dungeon_id = config.getParameter("shipDungeonId", 10101)
            local ship_offset = ship_config.namje_stats.ship_center_pos
            local ship_position = vec2.sub({1024, 1024}, {ship_offset[1], -ship_offset[2]})
            
            world.placeDungeon(ship_config.ship, ship_position, ship_dungeon_id)
            --initialize the new region cache based on the ship_size in .namjeship
            local region_cache = {}
            local ship_size = ship_config.namje_stats.ship_size
            local width_chunks = math.ceil(ship_size[1] / CHUNK_SIZE)
            local height_chunks = math.ceil(ship_size[2] / CHUNK_SIZE)

            for i = 0, (height_chunks) do
                for k = 0, (width_chunks) do
                    local chunk = namje_util.get_chunk({ship_position[1] + (CHUNK_SIZE * k), ship_position[2] - (CHUNK_SIZE * i)})
                    local chunk_area = rect.fromVec2({chunk[1], chunk[2]}, {chunk[1] + (CHUNK_SIZE), chunk[2] + CHUNK_SIZE})
                    local collision_detected = world.rectTileCollision(chunk_area, {"Block", "Dynamic", "Slippery", "Platform"})
                    local cache_code = string.format("%s.%s", chunk[1], chunk[2])
                    if collision_detected or namje_util.find_background_tiles(chunk[1], chunk[2]) then
                        region_cache[cache_code] = true
                    end
                end
            end

            world.setProperty("namje_region_cache", region_cache)
        end

        if namje_byos.is_fu() then
            namje_byos.reset_fu_stats()
        end

        world.sendEntityMessage(ply, "namje_upgradeShip", ship_config.base_stats)
        return true
    end)
    return coroutine
end

--- scan from 0,0 to 2000,2000 for tiles in chunks of 100, then delete those areas with a 100x100 empty dungeon
function namje_byos.clear_ship_area(rect)
    if not world.isServer() then
        error("namje // clear_ship_area cannot be called on client")
    end
    sb.logInfo("clearing ship area: %s", rect)
    local chunks = namje_util.get_filled_chunks(rect)

    if #chunks == 0 then 
        return 
    end

    for _, chunk in ipairs (chunks) do
        local top_left_x = chunk.bottom_left[1]
        local bottom_right_y = chunk.top_right[2]

        world.placeDungeon("namje_void_32", {top_left_x, bottom_right_y})
    end
end

--- returns a list of items found in containers on the ship
--- @return table
function namje_byos.get_ship_items()
    local items = {}
    local objects = world.objectQuery({0, 0}, {2048, 2048})
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
    return root.assetJson("/versioning.config").FrackinUniverse ~= nil
end

--- returns true if the player/ is on a ship on client, or if the world is a ship on the server, false otherwise
--- @return boolean
function namje_byos.is_on_ship()
    if world.isClient() then
        return string.find(player.worldId(), "ClientShipWorld") ~= nil
    else
        return string.find(world.id(), "ClientShipWorld") ~= nil
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

--- returns true if the module is found for the ship in the slot, false otherwise
--- @param slot number
--- @param module string
--- @return boolean
function namje_byos.has_module(slot, module)
    local ship_stats = namje_byos.get_stats(slot)
    local ship_modules = ship_stats.modules
    for _, v in pairs(ship_modules) do
        if v and v == module then
            return true
        end
    end
    return false
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

--- initializes the BYOS system for players, usually before the bootship quest but a failsafe is implemented for existing characters
function namje_byos.init_byos(starting_ship)
    starting_ship = starting_ship or "namje_startership"
    
    player.setProperty("namje_byos_setup", true)
    namje_byos.add_ship_slots(2)
    namje_byos.set_current_ship(1)
    world.spawnStagehand({1024, 1024}, "namje_initBYOS_stagehand")
    local ship = namje_byos.register_new_ship(1, starting_ship, "Lone Trail", "/namje_ships/ship_icons/generic_1.png")
    local system = {["system"] = celestial.currentSystem(), ["location"] = celestial.shipLocation()}
    --TODO: set the stat in the cockpit as well
    namje_byos.set_stats(1, {celestial_pos = system})

    player.warp("nowhere")

    if namje_byos.is_fu() then
        player.startQuest("fu_byos")
    end
    --TODO: replaces the cinematic from the actual intro ending as well. Find a way to detect, or just use that one
    local cinematic = "/cinematics/namje/shipintro.cinematic"
    --player.playCinematic(cinematic, true)
end

--- resets all fu_byos stats if fu is enabled.
function namje_byos.reset_fu_stats()
    if not namje_byos.is_fu() then
        return
    end

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

--- fills the cargo hold with the player's racial starter items
--- @param species string
function namje_byos.fill_shiplocker(species)
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

    local cargo_hold = {}
    local cargo_count = 1

    for i = 1, #starter_treasure do
        local item_to_add = {
            name = starter_treasure[i].name,
            parameters = starter_treasure[i].parameters,
            count = starter_treasure[i].count
        }
        
        cargo_hold["slot_" .. cargo_count] = item_to_add
        cargo_count = cargo_count + 1
    end

    local ship_slot = player.getProperty("namje_current_ship", 1)
    local ship_stats = namje_byos.get_stats(ship_slot)
    namje_byos.set_stats(ship_slot, {["cargo_hold"] = cargo_hold})
end