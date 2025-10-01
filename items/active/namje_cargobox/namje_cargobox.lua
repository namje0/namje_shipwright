function activate()
	if player then
		local loot = config.getParameter("loot")
		for _, item in ipairs(loot) do
			player.giveItem(item)
		end

		item.consume(1)
	end
end