require "/scripts/util.lua"
require "/quests/scripts/questutil.lua"
require "/quests/scripts/portraits.lua"
require("/scripts/namje_byos.lua")

function init()
  storage.complete = storage.complete or false
  self.compassUpdate = config.getParameter("compassUpdate", 0.5)
  self.descriptions = config.getParameter("descriptions")

  self.techstationUid = config.getParameter("techstationUid")

  setPortraits()

  self.state = FSM:new()
  self.state:set(wakeSail)

  self.interactTimer = 0

  player.startQuest("namje_shipPassive")
  player.startQuest("namje_shipCache")
  if namje_byos.is_fu() then
    world.setProperty("fu_byos", true)
    player.startQuest("fu_shipupgrades")
  end
end

function questInteract(entityId)
  if self.interactTimer > 0 then return true end

  if world.entityUniqueId(entityId) == self.techstationUid then
    --player.upgradeShip(config.getParameter("shipUpgrade"))
    --namje_byos.change_ships_from_config("namje_templateship")
    
    world.sendEntityMessage(self.techstationUid, "activateShip")
    if namje_byos.is_fu() then
      player.giveItem("statustablet")
    end
    quest.complete()
    self.interactTimer = 1.0
    return true
  end
end

function questStart()
end

function update(dt)
  self.state:update(dt)
  self.interactTimer = math.max(self.interactTimer - dt, 0)
end

function wakeSail()
  quest.setCompassDirection(nil)
  quest.setObjectiveList({
    {self.descriptions.wakeSail, false}
  })

  -- try to lounge in the bed instead of teleporter, since we're spawning the ship with a functional tp
  util.wait(2.2, function()
    local teleporters = world.entityQuery(mcontroller.position(), 100, {includedTypes = {"object"}})
    teleporters = util.filter(teleporters, function(entityId)
      if string.find(world.entityName(entityId), "prisonbed") then
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
    coroutine.yield()
  end
end

function questComplete()
  if namje_byos.is_fu() then
    status.addEphemeralEffect("fu_byosfindship", 10)
  end
  player.upgradeShip({capabilities = { "teleport" }})
  questutil.questCompleteActions()
end
