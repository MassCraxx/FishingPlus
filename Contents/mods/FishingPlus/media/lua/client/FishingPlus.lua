--***********************************************************
--**                    Fishing+ v3                        **
--**              MassCraxx + ROBERT JOHNSON               **
--***********************************************************

--[[
[h1]Vanilla Fishing Rework[/h1]

[h3]Features:[/h3]

> [b]Adds features of [url=https://steamcommunity.com/sharedfiles/filedetails/?id=2696281225]Bricks Wants Fish[/url] (Big thanks to bricks for letting me include his idea)[/b]
[list]
[*] Fish size chance now scales off fishing level
[*] High fishing levels have a better chance of catching bigger fish
[*] Small fish become nonexistent past Fishing level 5
[*] Added new fish size: Prize - 50% larger than Big fish
[*] Adjusted fish size chance distribution
[/list]

> [b]Reworked XP gain to be more rewarding[/b]
[list]
[*] Increase XP gain in general (adjustable via Sandbox options)
[*] Gained XP scales with the actual size of caught fish
[*] Catching bigger fish gains significantly more XP than catching smaller ones
[*] Show gained XP just as in Foraging
[/list]

> [b]Reworked trash loot generation[/b]
[list]
[*] Catching trash gains fixed amount of XP
[*] Trash loot is taken from a weighted loot table containing many different items
[*] Chance of slightly more useful trash items with higher fishing level
[/list]

[h3]Sandbox options:[/h3]
[list]
[*] Choose from 3 different XP gain options - High, Medium, Low (Vanilla-near)
[*] Free XP multiplier for fine balancing
[*] Fish nutrition factor to adjust the nutrition value of caught fish
[*] En- / Disable reworked trash loot table
[*] Set if fish abundance should decrease every catch or only if catching fish
[/list]

Can be en- and disabled on existing savegames and is fully multiplayer compatible.
On dedicated servers, Sandbox options can be adjusted any time (may require restart).

[hr][/hr] 
Workshop ID: 2757633688
Mod ID: FishingPlus
]]

FishingPlus = _G['FishingPlus'] or {}

OG_ISFishingAction_perform = ISFishingAction.perform
function ISFishingAction:perform()
    local decreaseAbundance = SandboxVars.FishingPlus.DecreaseAbundance or 1;
    if decreaseAbundance == 1 then
        OG_ISFishingAction_perform(self);
        return;
    end

    self.rod:setJobDelta(0.0);

    self.character:PlayAnim("Idle");

    if self.usingSpear then
        self.splashTimer = 0;
    end

    -- get the fishing zone to see how many fishes left
    local updateZone = self:getFishingZone();
    if updateZone then
        local fishLeft = tonumber(updateZone:getName());
        if getGametimeTimestamp() - updateZone:getLastActionTimestamp() > 20000 then
            fishLeft = math.max(ZombRand(10,25) + self.fishingZoneIncrease, 0);
            updateZone:setName(tostring(fishLeft));
            updateZone:setOriginalName(tostring(fishLeft));
        end
        if fishLeft == 0 then
            self.character:SetVariable("FishingFinished","true");
            -- needed to remove from queue / start next.
            ISBaseTimedAction.perform(self);
           return;
        end
    end


    local caughtFish = false;
    if self:attractFish() then -- caught something !
        local fish = self:getFish();
        if updateZone and fish and fish.fish and fish.fish.name then -- only update if caught item is a fish
            local fishLeft = tonumber(updateZone:getName());
            updateZone:setName(tostring(fishLeft - 1));
            updateZone:setLastActionTimestamp(getGametimeTimestamp());
            if isClient() then updateZone:sendToServer() end
        end
        caughtFish = true;
    else
        if ZombRand(9) == 0 then -- give some xp even for a fail
            self.character:getXp():AddXP(Perks.Fishing, 1);
        end
        if self.lureProperties and ZombRand(100) <= self.lureProperties.chanceOfBreak then -- maybe remove the lure
            self.character:getSecondaryHandItem():Use();
            self.character:setSecondaryHandItem(nil);
        end
    end

    if not updateZone then -- register a new fishing zone
        local nbrOfFish = math.max(ZombRand(10,25) + self.fishingZoneIncrease, 0);
        local x,y,z = self.tile:getSquare():getX(), self.tile:getSquare():getY(), self.tile:getSquare():getZ()
        local updateZone = getWorld():registerZone(tostring(nbrOfFish), "Fishing", x - 20, y - 20, z, 40, 40);
        updateZone:setOriginalName(tostring(nbrOfFish));
        updateZone:setLastActionTimestamp(getGametimeTimestamp());
        if isClient() then updateZone:sendToServer() end
    end
    
    if self.fishingUI then
        self.fishingUI:updateZoneProgress(updateZone);
    end

    local newAction = nil;
    if not self.usingSpear then
        local lure = ISWorldObjectContextMenu.getFishingLure(self.character, self.rod)
        if lure then
            ISWorldObjectContextMenu.equip(self.character, self.character:getSecondaryHandItem(), lure:getType(), false);
            newAction = ISFishingAction:new(self.character, self.tile, self.rod, lure, self.fishingUI);
        end
    else
        newAction = ISFishingAction:new(self.character, self.tile, self.rod, nil, self.fishingUI);
    end

    if newAction then
        ISTimedActionQueue.add(newAction);
    end

    if not self.usingSpear then
        if newAction then
            if caughtFish then
                newAction.stage = "reel";
--                print(" - TRIGGER: strike (newcast & caughtfish)")
            else
                newAction.stage = "cast";
--                print(" - TRIGGER: cast (newcast & nocaught)")
            end
        else
            if caughtFish then
                self.character:SetVariable("FishingStage","strikeEnd");
--                print(" - TRIGGER: strikeEnd (nonewcast & caughtfish)")
            else
                self.character:SetVariable("FishingFinished","true");
--                print(" - TRIGGER: FishingFinished = true (nonewcast & nocaught)")
            end
        end
    else
        if newAction then
            if caughtFish then
                newAction.stage = "spearStrike";
                --                print(" - TRIGGER: strike (newcast & caughtfish)")
            else
                newAction.stage = "spearIdle";
                --                print(" - TRIGGER: cast (newcast & nocaught)")
            end
        else
            if caughtFish then
                self.character:SetVariable("FishingStage","spearStrike");
                --                print(" - TRIGGER: strikeEnd (nonewcast & caughtfish)")
            else
                self.character:SetVariable("FishingFinished","true");
                --                print(" - TRIGGER: FishingFinished = true (nonewcast & nocaught)")
            end
        end
    end

    -- needed to remove from queue / start next.
    ISBaseTimedAction.perform(self);
end

-- get a fish by the number
-- if plastic lure : 15/100 it's a big, 25/100 medium and 60/100 it's a little/lure fish
-- if living lure : 20/100 it's a big, 30/100 it's a medium and 50/100 it's a little/lure fish
function ISFishingAction:getFish()
    local fishItem = nil;
    local minRoll = 100-(8*self.fishingLvl);
    local fishSizeNumber = ZombRand(minRoll * 100) / 100;
    local fishSizeThreshold = {};
    local fish = {};

    -- we gonna determine the fish size and give player's xp
    -- first, if we have a plastic lure
    if self.plasticLure then
        if fishSizeNumber <= 1 then --vanilla 3
            fish.size = "Prize";
            fishSizeThreshold = {1,0};
            --self.character:getXp():AddXP(Perks.Fishing, 10);
		elseif fishSizeNumber <= 15 then
            fish.size = "Big";
            fishSizeThreshold = {15,2};
            --self.character:getXp():AddXP(Perks.Fishing, 7);  -- 13 - 15
        elseif fishSizeNumber <= 55 then
            fish.size = "Medium";
            fishSizeThreshold = {55,16};
            --self.character:getXp():AddXP(Perks.Fishing, 5); -- 7-8
        else
            fish.size = "Small";
            fishSizeThreshold = {100,56};
            --self.character:getXp():AddXP(Perks.Fishing, 3); -- 5-6
        end
    else -- living lure size
        if fishSizeNumber <= 2 then --vanilla 5
            fish.size = "Prize";
            fishSizeThreshold = {2,0};
            --self.character:getXp():AddXP(Perks.Fishing, 10);
		elseif fishSizeNumber <= 20 then
            fish.size = "Big";
            fishSizeThreshold = {20,3};
            --self.character:getXp():AddXP(Perks.Fishing, 7);
        elseif fishSizeNumber <= 65 then
            fish.size = "Medium";
            fishSizeThreshold = {65,21};
            --self.character:getXp():AddXP(Perks.Fishing, 5);
        else
            fish.size = "Small";
            fishSizeThreshold = {100,66};
            --self.character:getXp():AddXP(Perks.Fishing, 3);
        end
    end
    
    local gainedXP = 1;

    fish.fish = self:getFishByLure();

    -- DEBUG
    if not fish or not fish.fish then
        print("ERROR: No item was generated in getFishByLure! Please send this log to the mod developer!");
        print("Possible fishes: " .. #Fishing.fishes .. " | Possible trash items: " .. #Fishing.trashItems .. " | using lure: " .. (self.lure and self.lure:getType()));
        local trashItemConfig = SandboxVars.FishingPlus.TrashItemConfig or 1;
        if trashItemConfig == 1 then
            local testTrash = FishingPlus:getTrashItem(self.fishingLvl);
            if testTrash then
                print("Test trash generation: ".. testTrash.item);
            else
                print("Test trash generation failed!");
            end
        end
        HaloTextHelper.addText(self.character, "ERROR")
        return fish
    end
    if fish.fish.name then -- if no name then it's a "trash" item
    -- then we may broke our line
        if not self:brokeLine(fish) then
            -- we gonna create our fish
            fishItem, gainedXP = self:createFish(fish, fish.fish, fishSizeNumber, fishSizeThreshold);
--            getSoundManager():PlayWorldSound("getFish", false, self.character:getSquare(), 1, 20, 1, false)
            self.character:playSound("CatchFish");
            addSound(self.character, self.character:getX(), self.character:getY(), self.character:getZ(), 20, 1)
        else
            fish.fish = nil;
        end
    else
        fishItem = InventoryItemFactory.CreateItem(fish.fish.item);
        if not fishItem then
            print("Item "..fish.fish.item.." from TrashLoot could not be created.")
            HaloTextHelper.addText(self.character, "Hmm, nothing. Some modder may have screwed up...")
            return {}
        end
        if fishItem:getCondition() and fishItem:getCondition() > 0 then
            fishItem:setCondition(ZombRand(1,fishItem:getConditionMax()/2));
        end
        local inv = self:getUsedInventory(fishItem);
        inv:AddItem(fishItem);
        if not self.usingSpear then
--            getSoundManager():PlayWorldSound("getFish", false, self.character:getSquare(), 1, 20, 1, false)
            self.character:playSound("CatchTrashWithRod");
            addSound(self.character, self.character:getX(), self.character:getY(), self.character:getZ(), 20, 1)
        end

        if fish.fish.xp then
            gainedXP = fish.fish.xp;
        else
            gainedXP = FishingPlus:getXpFromRoll(100); -- should be worst possible catch xp (TEST: 100 vs minRoll)
        end
    end
    
    if fishItem then
        print("Fishing caught: "..(fish.fish.name or fishItem:getName()).." | fishSizeNumber: "..fishSizeNumber.." | gainedXP: "..gainedXP)
    else
        print("Line broke! | gainedXP: "..gainedXP)
    end
    -- gain XP
    local currentXP = self.character:getXp():getXP(Perks.Fishing);
    self.character:getXp():AddXP(Perks.Fishing, gainedXP);
	gainedXP = self.character:getXp():getXP(Perks.Fishing) - currentXP;
    gainedXP = string.format("%.2f", gainedXP);
    local holotext = "[col=137,232,148]"..Perks.Fishing:getName().." "..getText("Challenge_Challenge2_CurrentXp", gainedXP) .. "[/] [img=media/ui/ArrowUp.png]"
    HaloTextHelper.addText(self.character, holotext)

    -- remove the lure
    if not self.plasticLure and self.character:getSecondaryHandItem() then
        self.character:getSecondaryHandItem():Use();
        self.character:setSecondaryHandItem(nil);
    end
    
    if self.fishingUI then
        self.fishingUI:setFish(fishItem);
    end
    
    return fish;
end

-- Visual ratio of fish caught and trash caught using player level
function ISFishingAction:getFishByLure()
    local item = 0;
    local MaxTrashRate = 0.4;
    local MinTrashRate = 0.15;
    local DampingConstant = 0.3;
    local trashRate = MaxTrashRate;
    for i = 0,self.fishingLvl do
        trashDelta = trashRate - MinTrashRate
        trashRate = trashRate - (trashDelta*DampingConstant)
    end

    if ZombRandFloat(0.0,1.0) < trashRate then
        local trashItemConfig = SandboxVars.FishingPlus.TrashItemConfig or 1;
        if trashItemConfig == 2 then
            item = Fishing.trashItems[ZombRand(#Fishing.trashItems) + 1];
        else
            item = FishingPlus:getTrashItem(self.fishingLvl);
        end
    else
        item = Fishing.fishes[ZombRand(#Fishing.fishes) + 1];
        for i,v in ipairs(item.lure) do
            if (self.lure and v == self.lure:getType()) or self.usingSpear then
                return item;
            end
        end
        return self:getFishByLure(); -- (could cause stack overflow if caught in infinite loop when lure is invalid for any fish)
    end

    return item;
end

-- create the fish we just get
-- we randomize is weight and size according to his size
-- then we set his new name
function ISFishingAction:createFish(fishType, fish, fishSizeNumber, fishSizeThreshold)
    --    local fish = Fishing.fishes[fishType.fishType];
    local fishToCreate = InventoryItemFactory.CreateItem(fish.item);
    local baseWeightLb = fishToCreate:getActualWeight();
    local size = nil;
    local maxSize = nil;
    local minSize = nil;
    local weightKg = nil;
    local baseScale = 1;
    local ancient = false;
    -- now we set the size (for the name) and weight (for hunger) according to his size (little, medium and big)
    if fishType.size == "Small" then
        --size = ZombRand(fish.little.minSize, fish.little.maxSize);
        maxSize = fish.little.maxSize;
        minSize = fish.little.minSize;
        size = FishingPlus:getSizeFromRoll(minSize, maxSize, fishSizeNumber, fishSizeThreshold);
        weightKg = size / fish.little.weightChange;
    elseif fishType.size == "Medium" then
        --size = ZombRand(fish.medium.minSize, fish.medium.maxSize);
        maxSize = fish.medium.maxSize;
        minSize = fish.medium.minSize;
        size = FishingPlus:getSizeFromRoll(minSize, maxSize, fishSizeNumber, fishSizeThreshold);
        weightKg = size / fish.medium.weightChange;
        baseScale = 1.2;
	elseif fishType.size == "Big" then
        --size = ZombRand(fish.big.minSize, fish.big.maxSize);
        maxSize = fish.big.maxSize;
        minSize = fish.big.minSize;
        size = FishingPlus:getSizeFromRoll(minSize, maxSize, fishSizeNumber, fishSizeThreshold);
        weightKg = size / fish.big.weightChange;
        baseScale = 1.3;
    else
        --size = ZombRand(fish.big.minSize*1.5, fish.big.maxSize*1.5);
        maxSize = fish.big.maxSize*1.5;
        minSize = fish.big.minSize*1.5;
        size = FishingPlus:getSizeFromRoll(minSize, maxSize, fishSizeNumber, fishSizeThreshold);
        weightKg = size / fish.big.weightChange;
        baseScale = 1.4;

        local ancientThreshold = maxSize - maxSize * 0.03; --size in max 3%
        ancient = size >= ancientThreshold;
        print(">>Ancient Roll " .. size .." / ".. ancientThreshold .. "(" .. maxSize .. ")");
        
        if ancient then
            baseScale = 1.5;
            -- split defined legendary prefixes to array
            local prefixCfgString = getText("IGUI_FishingPlus_LegendaryPrefixes");
            local prefixes = {};
            local prefixPattern = string.format("([^%s]+)", ",");
            prefixCfgString:gsub(prefixPattern, function(c) prefixes[#prefixes+1] = c end);

            if prefixes and #prefixes > 0 then
                fishType.size = prefixes[ZombRand(1,#prefixes+1)];
            end
        else
            fishType.size = "Big"; -- actual vanilla size "Prize" has no translation...
        end
    end

    local scaleMod = (((size - minSize) + 1) / ((maxSize - minSize) + 1) / 2);
    local nutritionConfigMulti = tonumber(SandboxVars.FishingPlus.FishNutritionFactor) or 2.2;
    local nutritionFactor = nutritionConfigMulti * weightKg / baseWeightLb;
    print("Create Fish: " .. fishType.size.. " " .. fish.name.. " | Size:" .. size .. " >".. minSize .. " <".. maxSize .. " | nutri: " .. nutritionFactor .. " (x" .. nutritionConfigMulti ..  ")");
    fishToCreate:setCalories(fishToCreate:getCalories() * nutritionFactor);
    fishToCreate:setLipids(fishToCreate:getLipids() * nutritionFactor);
    fishToCreate:setCarbohydrates(fishToCreate:getCarbohydrates() * nutritionFactor);
    fishToCreate:setProteins(fishToCreate:getProteins() * nutritionFactor);
    fishToCreate:setWorldScale(scaleMod + baseScale);

    -- the fish name is like : Big Trout - 26cm
    if SandboxVars.FishingPlus.RenameFish then
        local prefix = fishType.size
        if not ancient then
            prefix = getText("IGUI_Fish_" .. prefix);
        end
        local localizedFishName = getText("IGUI_Fish_"..string.gsub(fish.name, "%s+", ""));
        fishToCreate:setName(prefix .. " " .. localizedFishName .. " - " .. string.format(size) .. "cm");
    end

    -- hunger reduction is weight of the fish div by 6, and set it to negative
    fishToCreate:setBaseHunger(- weightKg / 6);
    fishToCreate:setHungChange(fishToCreate:getBaseHunger());
    -- weight is kg * 2.2 (in pound)
    fishToCreate:setActualWeight(weightKg * 2.2);
    fishToCreate:setCustomWeight(true)
    local inv = self:getUsedInventory(fishToCreate);
    inv:AddItem(fishToCreate);
    
    local xp = FishingPlus:getXpFromRoll(fishSizeNumber);

    return fishToCreate, xp;
end

--------------------- TRASH LOOT GEN -----------------------

LootTable = {}

-- roll 0-100
function FishingPlus:getXpFromRoll(x)
    local setting = SandboxVars.FishingPlus.XpSetting or 2;
    local multi = tonumber(SandboxVars.FishingPlus.XpMultiplier) or 1.0;
    
    -- 220/x+10 +1 || 440/x+10 +6 || 880/x+10 +12
    local XP = ((220*(2^(setting-1)) / (x + 10)) + (6^(setting-1))) * multi;

    return math.floor(XP * 100) / 100;
end

function FishingPlus:getSizeFromRoll(minSize, maxSize, x, max)
    -- minimum fishsize plus a percentage of the maximum size difference dependent on roll (x) and max roll
    local percentage = math.abs(x - max[1]) / (max[1]-max[2]);
    print("Roll x "..x.." with treshold "..max[1].."-"..max[2].." results in "..(percentage * 100).."% of size.")
    local result = minSize + ((maxSize - minSize) * percentage);
    return math.floor(result + 0.5) -- round to nearest number
end

function FishingPlus:getTrashItem(fishingLvl)
    local lootTable = FishingPlus:getTrashLoot(fishingLvl);
    if lootTable == nil or #lootTable == 0 then
        print("Could not load TrashItems loot table! Returning UnusableWood..")
        return {item = "Base.UnusableWood", weight = 500}
    end

    local totalWeight = lootTable.weight
	local randomNumber = ZombRand(1, totalWeight); --math.random(1,totalWeight)

    local weightIndex = 0;
    for _, entry in ipairs(lootTable) do
        if entry and entry.item then
            weightIndex = weightIndex + entry.weight;
            if randomNumber <= weightIndex then
                --print(randomNumber.." - "..entry.item);
                return entry;
            end
        end
    end

    print("No valid TrashItem found. Returning UnusableWood.")
    return {item = "Base.UnusableWood", weight = 500}
end

function FishingPlus:getTrashLoot(fishingLvl)
    -- Generate/Filter Loot-Table
    if not LootTable.level or LootTable.level ~= fishingLvl then
        LootTable = {};
        local count, weight = 0, 0;
        for k, v in pairs(FishingPlus.TrashItems) do
            if not v.level or v.level <= fishingLvl then
                count = count + 1;
                weight = weight + v.weight;
                LootTable[k] = v;
            end
        end
        LootTable.weight = weight;
        LootTable.level = fishingLvl;
        print("Generated new LootTable for level "..fishingLvl.." with "..count.." items.")
    end

    return LootTable;
end

function FishingPlus:printLootTablePercentages(fishingLvl)
    local lootTable = FishingPlus:getTrashLoot(fishingLvl)
    table.sort(lootTable, function (a, b) return (a and b and a.weight and b.weight and a.weight > b.weight) end)
    local proof = 0
    for _, entry in pairs(lootTable) do
        if entry and entry.item then
            local percentage = (entry.weight / lootTable.weight) * 100
            proof = proof + percentage
            print(string.format("%.2f", percentage).."%".." - "..entry.item);
        else
            print(_.." - "..tostring(entry));
        end
    end
    print("Total percentage: "..proof);
end