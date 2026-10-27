local quests = assets.byExtension("questtemplate")

local message = '{"messageType" : "queueRadioMessage", "messageArgs" : ["namje_ship_noupgrades", 4.0]}'
local append_message_path = "/namje_removeQuestShipUpgrades_append.patch"
local create_message_path = "/namje_removeQuestShipUpgrades_create.patch"

assets.add(append_message_path, '[{"op" : "remove", "path" : "/scriptConfig/upgradeShip"}, {"op" : "add", "path" : "/scriptConfig/completionPlayerMessages/-", "value" : ' .. message .. '}]')
assets.add(create_message_path, '[{"op" : "remove", "path" : "/scriptConfig/upgradeShip"}, {"op" : "add", "path" : "/scriptConfig/completionPlayerMessages", "value" : [' .. message .. ']}]')

for i = 1, #quests do
  local script_config = assets.json(quests[i]).scriptConfig
  if type(script_config) == "table" and script_config.upgradeShip then
    if script_config.completionPlayerMessages then
      assets.patch(quests[i], append_message_path)
    else
      assets.patch(quests[i], create_message_path)
    end
  end
end
