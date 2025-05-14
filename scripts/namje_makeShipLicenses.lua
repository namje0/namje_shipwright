local ships = assets.byExtension("namjeship")

for i = 1, #ships do
    local ship = assets.json(ships[i])

    if ship.auto_create_license and ship.auto_create_license == true then
        local license_icon = ship.license_icon or "/items/active/namje_shiplicense/namje_shiplicense.png"
        local license_format = [[
            {
                "itemName": "shiplicense_%s",
                "shortdescription": "%s",
                "description": "%s",
                "price": %s,
                "tooltipKind": "namje_shiplicense",
                "rarity": "essential",
                "category": "shipLicense",
                "itemTags": [],
                "inventoryIcon": "%s",
                "twoHanded": true,
                "maxStack": 1,
                "animation": "/items/active/namje_shiplicense/animation.animation",
                "scripts": ["/items/active/namje_shiplicense/namje_shiplicense.lua"],
                "shipType": "%s",
                "builder": "/items/buildscripts/build_shiplicense.lua"
            }
        ]]

        local formatted_license = string.format(license_format, ship.id, ship.name, ship.description, (ship.price or 10000), license_icon, ship.id)

        local path = "/shiplicense_" .. ship.id .. ".activeitem"
        assets.add(path, formatted_license)

        local license_id = "shiplicense_" .. ship.id

        sb.logInfo("namje // added ship license activeitem for " .. ship.id .. ", itemID: " .. license_id)
    end
end