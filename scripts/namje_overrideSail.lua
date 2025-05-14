local objects = assets.byExtension("object")
local path = "/scripts/namje_overrideSail_patch.patch"

for i = 1, #objects do
  assets.patch(objects[i], path)
end