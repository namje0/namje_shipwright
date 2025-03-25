function swapShip()
  world.sendEntityMessage(pane.sourceEntity(), "confirm_swap")
  pane.dismiss()
end