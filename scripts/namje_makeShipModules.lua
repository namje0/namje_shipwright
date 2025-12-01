local modules = assets.byExtension("namjemodule")
local module_format = [[
    {
        "itemName": "%s",
        "shortdescription": "%s",
        "description": "%s",
        "price": %s,
        "tooltipKind": "namje_shipModule",
        "rarity": "%s",
        "category": "upgradeComponent",
        "tooltipFields": {
            "subtitle": "Ship Module"
        },
        "itemTags": [],
        "inventoryIcon": "%s",
        "music": %s,
        "script": "%s",
        "twoHanded": true,
        "maxStack": 1,
        "scripts": [],
        "radioMessagesOnPickup" : [ "namje_pickup_module" ],
        "isNamjeModule": true
    }
]]

for i = 1, #modules do
    local module = assets.json(modules[i])
    local module_icon = module.icon or "/namje_shipmodules/namje_genericmodule.png"
    local module_id = modules[i]:match("^.*/([^%.]+)%.namjemodule$")

    local formatted_module = string.format(module_format, module_id, module.name, module.description, module.price, module.rarity, module_icon, module.music or false, module.script or "")

    local path = "/" .. module_id .. ".activeitem"
    assets.add(path, formatted_module)

    sb.logInfo("namje // added module activeitem for " .. module_id)
end