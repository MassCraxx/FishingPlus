if getDebug() then
	Events.OnCustomUIKey.Add(function(key)
		---@type IsoPlayer | IsoGameCharacter | IsoGameCharacter | IsoLivingCharacter | IsoMovingObject player
		local player = getSpecificPlayer(0)

		if key == Keyboard.KEY_1 then
			player:getInventory():AddItem("Base.FishingRod");
		elseif key == Keyboard.KEY_2 then
			player:getInventory():AddItem("Base.Worm");
			player:getInventory():AddItem("Base.Worm");
			player:getInventory():AddItem("Base.Worm");
			player:getInventory():AddItem("Base.Worm");
			player:getInventory():AddItem("Base.Worm");
		elseif key == Keyboard.KEY_3 then
			local fishingLvl = player:getPerkLevel(Perks.Fishing);
			FishingPlus:printLootTablePercentages(fishingLvl)
		end

	end)
end
