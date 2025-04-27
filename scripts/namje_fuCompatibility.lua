
local player_config = assets.json("/player.config")
local fu = false

sb.logInfo("namje // checking for fu compatibility")
local deployment_scripts = player_config.deploymentConfig.scripts
for i = 1, #deployment_scripts do
  if string.find(deployment_scripts[i], "fu_player_init") then
    fu = true
    break
  end
end

if not fu then
  sb.logInfo("namje // not fu, skipping compatibility patches")
  return
end
sb.logInfo("namje // fu detected, adding compatibility patches")

--TODO: FTL Drive recipe compatibility

-- FTL Drive Compatibility
local ftl_drive_path = "/namje_fuCompatibility_drive_patch.patch"
assets.add(ftl_drive_path, '{"scriptDelta": 60, "scripts": ["/objects/ship/fu_shipstatmodifier.lua"], "description":"A service panel for an FTL drive. ^orange;FU detected, this will function identically to the^reset; ^cyan;Small FTL Drive^reset;"}')

assets.patch("/objects/namje_ship/drives/namje_inner_ftl_drive/namje_inner_ftl_drive.object", ftl_drive_path)

--Techstation (SAIL) Compatibility
local techstation_path = "/namje_fuCompatibility_techstation_patch.patch"
assets.add(techstation_path, '{"interactAction": "ScriptPane", "interactData": "/zb/newSail/newSail.config", "scripts": ["/objects/scripts/customtechstation.lua"]}')

local techstations = {
  "/objects/namje_ship/techstations/namje_techstation_1/namje_techstation1.object"
}
for i=1, #techstations do
  local techstation = techstations[i]
  assets.patch(techstation, techstation_path)
end

--Ship Teleporter Compatibility
local teleporter_path = "/namje_fuCompatibility_teleporter_patch.patch"
assets.add(teleporter_path, '{"scripts": ["/objects/namje_ship/shipteleporters/namje_shipteleporter.lua", "/objects/ship/fu_byosteleporter/fu_byosteleporter.lua", "/objects/ship/fu_byosobjectdeath.lua"]}')

local teleporters = {
  "/objects/namje_ship/shipteleporters/namje_shipteleporter_1/namje_shipteleporter_1.object"
}
for i=1, #teleporters do
  local teleporter = teleporters[i]
  assets.patch(teleporter, teleporter_path)
end