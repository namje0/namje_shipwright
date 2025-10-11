local objs = assets.byExtension("object")
local pet_items = assets.json("/scripts/namje_pets/namje_shipPet.config").ship_pets
local module_format = [[
    {
        "itemName": "%s",
        "shortdescription": "%s",
        "description": "%s",
        "price": %s,
        "rarity": "rare",
        "category": "upgradeComponent",
        "tooltipFields": {
            "subtitle": "Ship Pet"
        },
        "tooltipKind": "namje_shipPet",
        "itemTags": [],
        "inventoryIcon": "%s",
        "twoHanded": true,
        "maxStack": 1,
        "scripts": [],
        "radioMessagesOnPickup" : [ "namje_pickup_pet" ],
        "namjePetType": "%s"
    }
]]

local pets = {}

for _, v in pairs(objs) do
    local obj = assets.json(v)
    local pet = obj.shipPetType
    if pet then
        pets[pet] = true
    end
end

for k, _ in pairs(pets) do
    local id =  "namje_shippet_" .. k
    local formatted_pet = string.format(module_format, id, pet_items[k] and pet_items[k].name or (k:sub(1, 1):upper() .. k:sub(2)), pet_items[k] and pet_items[k].desc or "Contains ship pet ^orange;" .. k .. "^reset;.", pet_items[k] and pet_items[k].price or 1000, pet_items[k] and pet_items[k].icon or "/scripts/namje_pets/icon.png", k)

    local path = "/" .. id .. ".activeitem"
    assets.add(path, formatted_pet)
    sb.logInfo("namje // added ship pet activeitem for " .. k .. ", itemID: " .. id)
end