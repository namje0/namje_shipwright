function update(dt)
    if world.loungeableOccupied(entity.id()) then
        animator.setAnimationState("base", "using")
    else
        animator.setAnimationState("base", "default")
    end
end