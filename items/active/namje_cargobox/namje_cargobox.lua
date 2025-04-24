function activate()
	if player then
		local loot = config.getParameter("loot")
		for _, item in ipairs(loot) do
			player.giveItem(item)
		end

		--todo: chance for random crap like a dead rat or something
		item.consume(1)
	end
end