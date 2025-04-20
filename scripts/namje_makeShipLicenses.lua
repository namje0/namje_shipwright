local ships = assets.byExtension("namjeship")

for i = 1, #ships do
    local ship = assets.json(ships[i])
    
    local license_format = '{"itemName":"shiplicense_' .. ship.ship .. '","shortdescription":"' .. ship.name .. '","description":"' .. ship.description .. '","price":' .. (ship.price or 8500) .. ',"tooltipKind":"namje_shiplicense","rarity":"essential","category":"shipLicense","itemTags":[],"inventoryIcon":"/items/active/ship_license/shiplicense.png","twoHanded":true,"maxStack":1,"animation":"/items/active/ship_license/animation.animation","scripts":["/items/active/ship_license/shiplicense.lua"],"shipType":"' .. ship.ship .. '","builder":"/items/buildscripts/build_shiplicense.lua"}'

    local path = "/shiplicense_" .. ship.ship .. ".activeitem"
    assets.add(path, license_format)

    sb.logInfo("namje // added ship license activeitem for " .. ship.ship .. ", itemID: shiplicense_" .. ship.ship)
end