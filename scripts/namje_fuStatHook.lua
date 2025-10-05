function namje_unload()
    sb.logInfo("unloading ship stats for obj")
    if storage.reload then
		applyStats(-1)
		validCheck(false)
	end
end