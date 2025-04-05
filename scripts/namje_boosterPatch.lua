local path = "/namje_boosterPatch.patch"
local boosters = {
  "/objects/ship/boosters/bigboosterflame/bigboosterflame.object",
  "/objects/ship/boosters/boosterflame/boosterflame.object",
  "/objects/ship/boosters/smallboosterflame/smallboosterflame.object",
}

assets.add(path, '{"inventoryIcon" : "/objects/namje_ship/boosters/namje_smallboosterflame/icon.png"}')
for i = 1, #boosters do
  assets.patch(root.assetJson(boosters[i]), path)
end