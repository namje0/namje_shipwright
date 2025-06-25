function confirm()
  local register_pane = root.assetJson("/interface/namje_shipslotselect/namje_registershipinfo.config")
  register_pane.slot = config.getParameter("slot")
  player.interact("ScriptPane", register_pane, pane.sourceEntity())
end

function cancel()
  player.interact("ScriptPane", "/interface/namje_shipslotselect/namje_shipslotselect.config", pane.sourceEntity())
end