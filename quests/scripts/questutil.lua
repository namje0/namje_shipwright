require "/scripts/vec2.lua"

questutil = {}

--TODO: find better alternative than overwriting

function questutil.pointCompassAt(position)
  if position then
    local direction = world.distance(position, mcontroller.position())
    quest.setCompassDirection(vec2.angle(direction))
  elseif position == nil then
    quest.setCompassDirection(nil)
  end
end

function questutil.questCompleteActions()
  local completionMessages = config.getParameter("completionMessages", {})
  for _,message in ipairs(completionMessages) do
    world.sendEntityMessage(message.uniqueId, message.messageType, table.unpack(message.messageArgs))
  end

  local completionPlayerMessages = config.getParameter("completionPlayerMessages", {})
  for _,message in ipairs(completionPlayerMessages) do
    world.sendEntityMessage(player.id(), message.messageType, table.unpack(message.messageArgs))
  end

  local associatedMission = config.getParameter("associatedMission")
  if associatedMission then
    player.completeMission(associatedMission)
  end

  local showTech = config.getParameter("showTech")
  if showTech then
    for _,tech in ipairs(showTech) do
      player.makeTechAvailable(tech)
    end
  end

  local enableTech = config.getParameter("enableTech")
  if enableTech then
    for _,tech in ipairs(enableTech) do
      player.makeTechAvailable(tech)
      player.enableTech(tech)
    end
  end

  local equipTech = config.getParameter("equipTech")
  if equipTech then
    for _,tech in ipairs(equipTech) do
      player.makeTechAvailable(tech)
      player.enableTech(tech)
      player.equipTech(tech)
    end
  end

  local giveBlueprints = config.getParameter("giveBlueprints")
  if giveBlueprints then
    for _,blueprint in ipairs(giveBlueprints) do
      player.giveBlueprint(blueprint)
    end
  end

  local giveSpeciesBlueprints = config.getParameter("giveSpeciesBlueprints")
  if giveSpeciesBlueprints then
    local playerSpecies = player.species()
    if giveSpeciesBlueprints[playerSpecies] then
      for _,blueprint in ipairs(giveSpeciesBlueprints[playerSpecies]) do
        player.giveBlueprint(blueprint)
      end
    elseif giveSpeciesBlueprints["default"] then
      for _,blueprint in ipairs(giveSpeciesBlueprints["default"]) do
        player.giveBlueprint(blueprint)
      end
    end
  end


  --[[
    TODO: upgradeShip is used for more than just shipLevel, if we dont do custom ship maxfuel etc. then just
    deny any shipLevel calls instead of the whole thing.
  ]]
  local upgradeShip = config.getParameter("upgradeShip")
  if upgradeShip then
    world.sendEntityMessage(player.id(), "queueRadioMessage", "namje_ship_noupgrades", 4.0)
    --player.upgradeShip(upgradeShip)
  end
  
  local setUniverseFlags = config.getParameter("setUniverseFlags")
  if setUniverseFlags then
    for _, flagName in pairs(setUniverseFlags) do
      player.setUniverseFlag(flagName)
    end
  end

  local cinematic = config.getParameter("preCompletionCinema")
  if cinematic then
    player.playCinematic(cinematic)
  end

  local eventName = config.getParameter("completeEvent", "completeQuest")
  local eventFields = config.getParameter("completeEventFields", {})
  eventFields.templateId = quest.templateId()
  eventFields.generated = false
  player.recordEvent(eventName, eventFields)

  local followUp = config.getParameter("followUp")
  if followUp and player.canStartQuest(followUp) then
    local descriptor = followUp
    if type(descriptor) == "string" then
      descriptor = {
          templateId = descriptor,
          questId = descriptor,
          parameters = {}
        }
    end
    if not descriptor.parameters.questGiver then
      local p = quest.parameters()
      descriptor.parameters.questGiver = p.questReceiver or p.questGiver
    end
    player.startQuest(descriptor)
  end
end
