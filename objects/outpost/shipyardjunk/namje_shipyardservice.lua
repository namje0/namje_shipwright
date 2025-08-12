require "/scripts/vec2.lua"

function init()
  object.setInteractive(true)

  --TODO: make a custom ui with tabs and give it to the merchant, cause wow its a mess

  local npc_spawned = config.getParameter("npcSpawned")
  if not npc_spawned then
    object.setConfigParameter("npcSpawned", true)
    world.spawnNpc(vec2.add(entity.position(), {-7, 5}), "human", "namjeshipvendor", 1, 3)
  end
end

function onInteraction(args)
  local flag1 = world.universeFlagSet("outpost_mission1")
  if not flag1 then
    local chat_options = config.getParameter("chatOptions", {})
    if #chat_options > 0 then
      object.say(chat_options[math.random(1, #chat_options)])
    end
    return
  end

  local interact_data = config.getParameter("interactData")
  return { "ScriptPane", interact_data.gui }
end
