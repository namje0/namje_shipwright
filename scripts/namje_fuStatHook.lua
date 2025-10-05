function namje_unload()
    if storage.reload then
		applyStats(-1)
		validCheck(false)
	end
end