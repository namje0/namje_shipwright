require "/scripts/namje_byos.lua"
if not namje_byos.is_on_ship() then
    return
end

local original_upd = update or function(dt) end
local music_exists = false

function update(dt) original_upd(dt)
    if not namje_byos.is_on_ship() then
        return
    end
    
    if not music_exists then
        local stagehand_query = world.entityQuery({1024, 1024}, 2, {includedTypes = {"stagehand"}})
        if #stagehand_query > 0 then
            for _, v in pairs(stagehand_query) do
                if world.stagehandType(v) == "namje_music_stagehand" then
                    world.sendEntityMessage(v, "namje_die")
                    return
                end
            end
        end

        music_exists = true
        world.spawnStagehand({1024,1024}, "namje_music_stagehand", {musicTable = {"/music/tranquility-base.ogg"}})
    end
end
