--[[ TODO: cant require here
if not namje_byos.is_fu() then
  sb.logInfo("namje // not fu, skipping compatibility patches")
  return
end
sb.logInfo("namje // fu detected, adding compatibility patches")
]]
--booster patch
--[[
local booster_path = "/namje_fuCompatibility_patch.patch"
local boosters = {
  "/objects/namje_ship/boosters/namje_smallboosterflame/namje_boosterflame.object"
}
assets.add(booster_path, '{"scripts":["/objects/ship/boosters/boosterflame.lua","/objects/ship/fu_shipstatmodifier.lua"]}')
assets.add(booster_path, '{"scriptDelta":60}')
for i = 1, #boosters do
    assets.patch(root.assetJson(boosters[i]), booster_path)
end
]]