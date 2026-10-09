local modules = assets.byExtension("namjecassette")
local module_format = [[
    {
        "itemName": "%s",
        "shortdescription": "%s",
        "description": "%s",
        "price": %s,
        "tooltipKind": "namje_shipCassette",
        "rarity": "%s",
        "category": "upgradeComponent",
        "tooltipFields": {
            "subtitle": "Ship Cassette"
        },
        "itemTags": [],
        "inventoryIcon": "%s",
        "audio": "%s",
        "twoHanded": true,
        "maxStack": 1,
        "scripts": [],
        "radioMessagesOnPickup" : [ "namje_pickup_cassette" ],
        "isNamjeCassette": true
    }
]]

for i = 1, #modules do
    local module = assets.json(modules[i])
    local module_icon = module.icon or "/namje_shipcassettes/namje_genericcassette.png"
    local module_id = modules[i]:match("^.*/([^%.]+)%.namjecassette$")

    local formatted_module = string.format(module_format, module_id, module.name, module.description, module.price, module.rarity, module_icon, module.audio)

    local path = "/" .. module_id .. ".activeitem"
    assets.add(path, formatted_module)

    sb.logInfo("namje // added cassette activeitem for " .. module_id)
end