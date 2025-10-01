local modules = assets.byExtension("namjemodule")

for i = 1, #modules do
    local module = assets.json(modules[i])
    local module_icon = module.icon or "/namje_shipmodules/namje_genericmodule.png"
    local module_format = [[
        {
            "itemName": "%s",
            "shortdescription": "%s",
            "description": "%s",
            "price": %s,
            "tooltipKind": "namje_shipModule",
            "rarity": "%s",
            "category": "namje_shipModule",
            "itemTags": [],
            "inventoryIcon": "%s",
            "twoHanded": true,
            "maxStack": 1,
            "scripts": []
        }
    ]]

    local formatted_module = string.format(module_format, module.id, module.name, module.description, module.price, module.rarity, module.icon)

    local path = "/" .. module.id .. ".activeitem"
    assets.add(path, formatted_module)

    sb.logInfo("namje // added module activeitem for " .. module.id)
end