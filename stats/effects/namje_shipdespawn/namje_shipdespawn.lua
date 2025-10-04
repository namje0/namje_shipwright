function init()
  mcontroller.setVelocity({0, 0})
  status.setResource("stunned", math.max(status.resource("stunned"), effect.duration()))
  status.setResource("health", 0)
end

function uninit()
end
