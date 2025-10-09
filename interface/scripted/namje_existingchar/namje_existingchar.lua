function confirm()
  player.interact("scriptPane", "/interface/scripted/namje_existingchar/namje_choosebyos.config", player.id())
  pane.dismiss()
end

function menu()
  player.playCinematic("\n\n\n\n\n\n\n\n\n\n\nReturning to title screen.\n^yellow;If you would like to use your vanilla ship, uninstall namjeShipwright and relaunch\n\n\n\n\n\n\n\n\n\n\n")
  pane.dismiss()
end