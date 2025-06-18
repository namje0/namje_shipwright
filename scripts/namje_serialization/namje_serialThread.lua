function init()
    script.setUpdateDelta(1)
    message.setHandler("encode", function(_,_, ship)
        sb.logInfo("namje_serialThread encode")
    end)
    message.setHandler("decode", function(_,_, code)
        sb.logInfo("namje_serialThread decode")
    end)
end

function uninit()
end
