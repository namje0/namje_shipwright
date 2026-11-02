require "/scripts/namje_byos.lua"
require "/scripts/vec2.lua"

local fu_atmosphere = false
local initial_outside = false
local on_ship = false
local on_own_ship = false
local promise
local music_refresh_pending = false
local music_lookup_pending = false
local MUSIC_STAGEHAND = "namje_music_stagehand"

function move_to_ship_spawn()
    --[[local spawn = world.getProperty("namje_ship_spawn", {1024, 1024})
    mcontroller.setPosition(vec2.add(spawn, {0, 2}))]]
    player.warp("nowhere")
end

function init()
    promise = PromiseKeeper.new()
    if namje_byos.is_fu() then
        fu_atmosphere = true
        sb.logInfo("namje // fu atmosphere detected")
    end
    message.setHandler("namje_moveToShipSpawn", move_to_ship_spawn)
    if not namje_byos.is_on_ship() then
        on_ship = false
        mcontroller.clearControls()
        initial_outside = true
    else
        on_ship = true
    end
    if namje_byos.is_on_own_ship() then
        on_own_ship = true
    else
        on_own_ship = false
    end

    music_refresh_pending = on_own_ship
    message.setHandler("namje_refreshCassettes", function()
        music_refresh_pending = on_own_ship
    end)

    local current_slot = player.getProperty("namje_current_ship", 1)
    local ship_stats = namje_byos.get_stats(current_slot)
    if ship_stats then
        local ship_modules = ship_stats.modules
        for k, v in pairs(ship_modules) do
            if v then
                local module = root.itemConfig(v)
                if module then
                    local module_config = module.config
                    if #module_config.script > 0 then
                        require(module_config.script)
                    end
                end
            end
        end
    end

    message.setHandler("namje_upgradeShip", function(_, _, ship_stats)
        sb.logInfo("namje // upgrading ship with stats")
        local capabilities = namje_byos.is_fu() and {} or ship_stats.capabilities
        player.upgradeShip({capabilities = capabilities, maxFuel = ship_stats.max_fuel, fuelEfficiency = ship_stats.fuel_efficiency, shipSpeed = ship_stats.ship_speed, crewSize = ship_stats.crew_size})
    end)

    if on_own_ship then
        local success = namje_byos.process_ship_queue()
        if success then
            move_to_ship_spawn()
        end
    end
end

function update(dt)
    promise:update()
    sync_music_stagehand()

    local current_slot = player.getProperty("namje_current_ship", 1)
    if fu_atmosphere or namje_byos.has_module(current_slot, "namje_atmomodule") then
        return
    end
    if not on_ship then
        if not initial_outside then
            mcontroller.clearControls()
            initial_outside = true
        end
        return
    end
    if not world.tileIsOccupied(mcontroller.position(), false) then
        mcontroller.controlParameters({gravityEnabled = false})
        if initial_outside then
            mcontroller.setVelocity({0, 0})
            initial_outside = false
        end
    else
        mcontroller.clearControls()
        initial_outside = true
    end
end

function get_cassette_tracks()
    local current_slot = player.getProperty("namje_current_ship", 1)
    local ship_stats = namje_byos.get_stats(current_slot)
    local tracks = {}
    if not ship_stats then
        return tracks
    end

    for k, v in pairs(ship_stats.cassettes or {}) do
        if v then
            local cassette = root.itemConfig(v)
            if cassette then
                table.insert(tracks, cassette.config.audio)
            end
        end
    end
    return tracks
end

function sync_music_stagehand()
    if not music_refresh_pending or music_lookup_pending then
        return
    end

    music_refresh_pending = false
    music_lookup_pending = true
    local tracks = get_cassette_tracks()
    local function spawn_music_stagehand()
        music_lookup_pending = false
        if #tracks > 0 then
            world.spawnStagehand({1024, 1024}, MUSIC_STAGEHAND, {musicTable = tracks})
        end
    end
    promise:add(world.findUniqueEntity(MUSIC_STAGEHAND),
        function(result)
            if not result then
                spawn_music_stagehand()
                return
            end
            music_lookup_pending = false
            -- stagehand updates its music in place, or dies if there are no tracks
            world.sendEntityMessage(MUSIC_STAGEHAND, "namje_setMusic", tracks)
        end,
        spawn_music_stagehand
    )
end
