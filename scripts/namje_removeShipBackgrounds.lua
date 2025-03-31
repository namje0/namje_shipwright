local structs = assets.byExtension("structure")
local path = "/namje_removeShipBackgrounds_patch.patch"

sb.logInfo("=============== Namje Postload: Removing ship backgrounds")
assets.add(path, '{"backgroundOverlays":[]}')
for i = 1, #structs do
  assets.patch(structs[i], path)
end