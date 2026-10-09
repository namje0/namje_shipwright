require "/scripts/namje_byos.lua"

function init()
    self.players = {}
    self.music = config.getParameter("musicTable")
    
    message.setHandler("namje_die", function()
        stagehand.die()
    end)

    if not namje_byos.is_on_ship() then
        stagehand.die()
        return
    end
end

function update(dt)
    local players = world.players()
    for _, player in ipairs (players) do
        if not self.players[player] then
            self.players[player] = true
            world.sendEntityMessage(player, "playAltMusic", self.music)
        end
    end
end