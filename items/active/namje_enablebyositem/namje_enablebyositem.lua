require("/scripts/namje_byos.lua")

function activate()
    player.giveItem("shiplicense_namje_aomkellion")
    player.startQuest("namje_shippassive")
    if namje_byos.is_fu() then
      player.startQuest("fu_shipupgrades")
    end
    item.consume(1)
end