local structs = assets.byExtension("structure")
local remove_overlay_path = "/namje_removeShipBackgrounds_patch.patch"

--[[
  For pre-existing characters, the backgroundOverlay is already placed for pre-existing ships. There is no lua way to remove these, but we can override it
  with an empty image backgroundOverlay. We'll create a new dummy tier and upgrade to it solely for pre-existing characters opting to enable
  namjeShipwright systems
]]

local test_structure = '{"config" : {"shipUpgrades" : {"capabilities" : ["teleport", "planetTravel", "systemTravel"],"crewSize" : 2}}, "blockKey" : "blockKey.config:blockKey", "blockImage" : "/ships/blankkey.png", "backgroundOverlays":[{"image" : "/ships/blankoverlay.png","position" : [-24.5, 12.75],"fullbright" : true},{"image" : "/ships/blankoverlay.png","position" : [-24.5, 12.75]}]}'
local ship_folders = {}

assets.add(remove_overlay_path, '{"backgroundOverlays":[]}')
for i = 1, #structs do
  local directory = string.match(structs[i], "^(/[^/]+/[^/]+/)")
  local species = string.match(directory, "^/[^/]+/([^/]+)")
  local change_blockimg_path = "/namje_" .. species .. "_key.patch"
  table.insert(ship_folders, directory)

  --force blockimages for upgrades past T0 to just be the same size as the t0 ship.
  assets.add(change_blockimg_path, '{"blockImage":"'.. species ..'T0blocks.png"}')
  assets.patch(structs[i], change_blockimg_path)
  assets.patch(structs[i], remove_overlay_path)
end

--remove duplicates
if #ship_folders > 0 then
  table.sort(ship_folders)
  local w = 1
  while w < #ship_folders do
      if ship_folders[w] == ship_folders[w + 1] then
          table.remove(ship_folders, w + 1)
      else
          w = w + 1
      end
  end
end

for i = 1, #ship_folders do
  local species = string.match(ship_folders[i], "^/[^/]+/([^/]+)")
  local tier_path = ship_folders[i] .. species ..  "T9.structure"
  assets.add(tier_path, test_structure)
end