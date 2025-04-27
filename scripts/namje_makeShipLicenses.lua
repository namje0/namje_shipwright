local ships = assets.byExtension("namjeship")

for i = 1, #ships do
    local ship = assets.json(ships[i])

    if ship.auto_create_license and ship.auto_create_license == true then
        local license_icon = ship.license_icon or "/items/active/namje_shiplicense/namje_shiplicense.png"
        local license_format = '{"itemName":"shiplicense_' .. ship.id .. '","shortdescription":"' .. ship.name .. '","description":"' .. ship.description .. '","price":' .. (ship.price or 8500) .. ',"tooltipKind":"namje_shiplicense","rarity":"essential","category":"shipLicense","itemTags":[],"inventoryIcon":"' .. license_icon .. '","twoHanded":true,"maxStack":1,"animation":"/items/active/namje_shiplicense/animation.animation","scripts":["/items/active/namje_shiplicense/namje_shiplicense.lua"],"shipType":"' .. ship.id .. '","builder":"/items/buildscripts/build_shiplicense.lua"}'

        local path = "/shiplicense_" .. ship.id .. ".activeitem"
        assets.add(path, license_format)

        local license_id = "shiplicense_" .. ship.id

        sb.logInfo("namje // added ship license activeitem for " .. ship.id .. ", itemID: " .. license_id)
    else
        sb.logInfo("namje // auto ship license creation disabled for " .. ship.id .. ", skipping")
    end
end