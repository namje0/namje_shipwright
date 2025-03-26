require "/scripts/util.lua"

function init()
    self.chatOptions = config.getParameter("chatOptions", {})
    self.chatTimer = 0
    self.buyFactor = config.getParameter("buyFactor", root.assetJson("/merchant.config").defaultBuyFactor)

    object.setInteractive(true)
end
  
function update(dt)
    self.chatTimer = math.max(0, self.chatTimer - dt)
    if self.chatTimer == 0 then
        local players = world.entityQuery(object.position(), config.getParameter("chatRadius"), {
            includedTypes = {"player"},
            boundMode = "CollisionArea"
        })

        if #players > 0 and #self.chatOptions > 0 then
            object.say(self.chatOptions[math.random(1, #self.chatOptions)])
            self.chatTimer = config.getParameter("chatCooldown")
        end
    end
end

function onInteraction(args)
    local interactData = config.getParameter("interactData")

    interactData.recipes = {}
    local addRecipes = function(items, category)
        for i, item in ipairs(items) do
        interactData.recipes[#interactData.recipes + 1] = generateRecipe(item, category)
        end
    end

    local storeInventory = config.getParameter("storeInventory")
    addRecipes(storeInventory.small, "small")
    addRecipes(storeInventory.medium, "medium")
    addRecipes(storeInventory.large, "large")

    return { "OpenCraftingInterface", interactData }
end
  
function generateRecipe(itemName, category)
    return {
        input = { {"money", math.floor(self.buyFactor * (root.itemConfig(itemName).config.price or root.assetJson("/merchant.config").defaultItemPrice))} },
        output = itemName,
        groups = { category }
    }
end