require "/scripts/namje_util.lua"
require "/scripts/namje_byos.lua"

local promise

function init()
    promise = PromiseKeeper.new()
    message.setHandler("namje_cargohold_insert", insert_item)
    message.setHandler("namje_receive_item", receive_item)
    object.setInteractive(true)
end

function update(dt)
    promise:update()
end

function onInteraction(args)
    if not namje_byos.is_on_ship() then
        animator.playSound("error")
        return
    end
    promise:add(world.sendEntityMessage(args.sourceId, "namje_cargohold_open"), 
        function(result) 
            if not result then
                animator.playSound("error")
                return
            else
                animator.playSound("use")
            end
        end, 
        function(err) 
            sb.logInfo("namje // cargo promise error: ".. err)
        end
    )
end