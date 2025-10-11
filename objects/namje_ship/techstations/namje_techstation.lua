function init()
    storage.spawnTimer = storage.spawnTimer and 0.5 or 0
    storage.petParams = storage.petParams or {}

    self.currentPetType = nil
    self.currentPetSeed = nil
    self.spawnOffset = config.getParameter("spawnOffset", {0, 2})
end

function hasPet()
  return self.petId ~= nil
end

function setPet(entityId, params)
  if self.petId == nil or self.petId == entityId then
    self.petId = entityId
    storage.petParams = params
  else
    return false
  end
end

function update(dt)
  if self.petId and not world.entityExists(self.petId) then
    self.petId = nil
  end

  local pet = world.getProperty("namje_ship_pet", nil)
  if storage.spawnTimer < 0 and self.petId == nil and pet ~= nil then
    self.currentPetType = pet[1]
    self.currentPetSeed = pet[2]
    storage.petParams.level = 1
    storage.petParams.seed = pet[2]
    self.petId = world.spawnMonster(pet[1], object.toAbsolutePosition(self.spawnOffset), storage.petParams)
    world.callScriptedEntity(self.petId, "setAnchor", entity.id())
    storage.spawnTimer = 0.5
  else
    if self.petId then
      local outdated = pet and (pet[1] ~= self.currentPetType or pet[2] ~= self.currentPetSeed)
      local missing = not pet
      
      if outdated or missing then
          world.callScriptedEntity(self.petId, "monster.setDeathSound", nil)
          world.callScriptedEntity(self.petId, "monster.setDropPool", nil)
          world.callScriptedEntity(self.petId, "monster.setDeathParticleBurst", nil)
          world.callScriptedEntity(self.petId, "status.addEphemeralEffect", "namje_shipdespawn")
          self.petId = nil
          storage.petParams = {}
      end
    end
    storage.spawnTimer = storage.spawnTimer - dt
  end
end

--[[
function onInteraction()
    if self.dialogTimer then
        sayNext()
        return nil
    else
        return config.getParameter("interactAction")
    end
end
]]