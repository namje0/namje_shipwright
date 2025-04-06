require "/scripts/util.lua"
require "/quests/scripts/questutil.lua"
require "/quests/scripts/portraits.lua"
require("/scripts/namje_byos.lua")

--TODO: FU compatability

function init()
  storage.complete = storage.complete or false
  self.compassUpdate = config.getParameter("compassUpdate", 0.5)
  self.descriptions = config.getParameter("descriptions")

  self.techstationUid = config.getParameter("techstationUid")

  setPortraits()

  self.state = FSM:new()
  self.state:set(wakeSail)

  self.interactTimer = 0

  --this method of running the script is based off how FU does it, i'm not sure if there's a better way to do this atm
    player.startQuest("namje_shippassive")
    if namje_byos.is_fu() then
      player.startQuest("fu_shipupgrades")
    end
end

function questInteract(entityId)
  if self.interactTimer > 0 then return true end

  if world.entityUniqueId(entityId) == self.techstationUid then
    --player.upgradeShip(config.getParameter("shipUpgrade"))
    --namje_byos.change_ships("namje_templateship")
    if namje_byos.is_fu() then
      player.interact("ScriptPane", "/interface/ai/fu_byosai.config")
    else
      world.sendEntityMessage(self.techstationUid, "activateShip")
      quest.complete()
    end
    self.interactTimer = 1.0
    return true
  end
end

function questStart()
end

function update(dt)
  self.state:update(dt)

  if self.questComplete then
	  world.sendEntityMessage(self.techstationUid, "activateShip")
    player.giveItem("statustablet")
    quest.complete()
  end

  self.interactTimer = math.max(self.interactTimer - dt, 0)
end

function wakeSail()
  quest.setCompassDirection(nil)
  quest.setObjectiveList({
    {self.descriptions.wakeSail, false}
  })

  -- try to lounge in the teleporter for a bit
  util.wait(1.0, function()
    local teleporters = world.entityQuery(mcontroller.position(), 100, {includedTypes = {"object"}})
    teleporters = util.filter(teleporters, function(entityId)
      if string.find(world.entityName(entityId), "teleporterTier0") then
        return true
      end
    end)
    if #teleporters > 0 then
      player.lounge(teleporters[1])
      return true
    end
  end)

  util.wait(2.0)

  world.sendEntityMessage(self.techstationUid, "wakePlayer")

  local findTechStation = util.uniqueEntityTracker(self.techstationUid, self.compassUpdate)
  while true do
    questutil.pointCompassAt(findTechStation())

    --[[local shipUpgrades = player.shipUpgrades()
    if shipUpgrades.shipLevel > 0 then
      quest.complete()
    end]]
    if namje_byos.is_fu() and world.getProperty("fu_byos") then
      self.questComplete = true
    end 
    coroutine.yield()
  end
end

function questComplete()
  if namje_byos.is_fu() then
    status.addEphemeralEffect("fu_byosfindship", 10)
  end
  questutil.questCompleteActions()
end
