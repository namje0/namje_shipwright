function init()
  object.setInteractive(true)
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
  return { "OpenCraftingInterface", interact_data }
end
