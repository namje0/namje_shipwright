require "/scripts/namje_byos.lua"

function init()
    self.players = {}
    storage.tracks = storage.tracks or config.getParameter("musicTable", {})

    message.setHandler("namje_setMusic", function(_, _, tracks)
        set_music(tracks or {})
    end)

    message.setHandler("namje_die", function()
        stop_music()
        stagehand.die()
    end)

    if not namje_byos.is_on_ship() or #storage.tracks == 0 then
        stagehand.die()
        return
    end
end

function update(dt)
    local present = {}
    for _, player in ipairs(world.players()) do
        present[player] = true
        if not self.players[player] then
            -- reshuffle per player so the order changes each time they enter the ship
            world.sendEntityMessage(player, "playAltMusic", shuffle(storage.tracks))
        end
    end
    self.players = present
end

function set_music(tracks)
    if #tracks == 0 then
        stop_music()
        stagehand.die()
        return
    end

    if same_tracks(tracks, storage.tracks) then
        return
    end

    storage.tracks = tracks
    -- clear known players so everyone currently on the ship gets the new music table
    self.players = {}
    update()
end

function stop_music()
    for _, player in ipairs(world.players()) do
        world.sendEntityMessage(player, "stopAltMusic", 2.0)
    end
    self.players = {}
end

function same_tracks(a, b)
    if #a ~= #b then
        return false
    end
    local lookup = {}
    for _, v in ipairs(b) do
        lookup[v] = true
    end
    for _, v in ipairs(a) do
        if not lookup[v] then
            return false
        end
    end
    return true
end

function shuffle(tracks)
    local shuffled = {}
    for i, v in ipairs(tracks) do
        shuffled[i] = v
    end
    for i = #shuffled, 2, -1 do
        local j = math.random(1, i)
        shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
    end
    return shuffled
end
