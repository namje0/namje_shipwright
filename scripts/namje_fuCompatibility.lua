
local player_config = assets.json("/player.config")
local fu = false

sb.logInfo("namje // checking for fu compatibility")
local deployment_scripts = player_config.deploymentConfig.scripts
for i = 1, #deployment_scripts do
  sb.logInfo(sb.print(deployment_scripts[i]))
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

-- FTL Drive Compatibility
local ftl_drive_path = "/namje_fuCompatibility_drive_patch.patch"
assets.add(ftl_drive_path, '{"scriptDelta": 60, "scripts": ["/objects/ship/fu_shipstatmodifier.lua"], "description":"A service panel for an FTL drive. ^orange;FU detected, this will function identically to the^reset; ^cyan;Small FTL Drive^reset;"}')

assets.patch("/objects/namje_ship/drives/namje_inner_ftl_drive/namje_inner_ftl_drive.object", ftl_drive_path)