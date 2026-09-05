local _ = ...

local SOURCE_KEY = "smartAvgCrafted"
local SOURCE_LOOKUP_KEY = strlower(SOURCE_KEY)
local SOURCE_LABEL = "Smart Avg Crafted"
local MAX_SNAPSHOTS_PER_ITEM = 2000
local RegisterSource
local state = {
	db = nil,
	tsm = nil,
	customString = nil,
	itemString = nil,
	marketItemStringCache = {},
	craftString = nil,
	recipeString = nil,
	registered = false,
	hooksInstalled = false,
	craftApiHooksInstalled = false,
	tooltipHooksInstalled = false,
	debugEnabled = false,
	pendingCrafts = {},
	nextPendingSequence = 0,
	activeSpellID = nil,
	auctionProvider = nil,
}

local GetTSMItemString

local function ChatPrint(formatString, ...)
	if not DEFAULT_CHAT_FRAME or type(DEFAULT_CHAT_FRAME.AddMessage) ~= "function" then
		return
	end
	local message = tostring(formatString)
	if select("#", ...) > 0 then
		local ok, formatted = pcall(string.format, message, ...)
		if ok then
			message = formatted
		end
	end
	DEFAULT_CHAT_FRAME:AddMessage(YayaCore.UI.HEX.accent .. "YayaCraftedPrice|r " .. message)
end

local function DebugPrint(formatString, ...)
	if state.debugEnabled then
		ChatPrint("[debug] " .. tostring(formatString), ...)
	end
end

local function GetExactItemString(itemString)
	if type(itemString) ~= "string" or itemString == "" then
		return nil
	end

	if GetTSMItemString then
		local exactItemString = GetTSMItemString(itemString)
		if exactItemString then
			return exactItemString
		end
	end

	return itemString
end

local function GetMarketItemString(itemString)
	local exactItemString = GetExactItemString(itemString)
	if not exactItemString then
		return nil
	end

	local itemStringModule = state.itemString
	if not itemStringModule or type(itemStringModule.ToLevel) ~= "function" then
		return exactItemString
	end

	local cached = state.marketItemStringCache[exactItemString]
	if cached then
		return cached
	end

	local ok, marketItemString = pcall(itemStringModule.ToLevel, exactItemString)
	if not ok or type(marketItemString) ~= "string" or marketItemString == "" then
		return exactItemString
	end

	state.marketItemStringCache[exactItemString] = marketItemString
	return marketItemString
end

local function GetCurrentInventory(itemString)
	local exactItemString = GetExactItemString(itemString) or itemString
	local marketItemString = GetMarketItemString(exactItemString) or exactItemString
	if state.customString and type(state.customString.GetSourceValue) == "function" then
		local ok, quantity = pcall(state.customString.GetSourceValue, "NumInventory", marketItemString)
		quantity = ok and math.max(0, tonumber(quantity) or 0) or 0
		if quantity > 0 then
			return quantity
		end
	end

	local itemID = type(itemString) == "string" and tonumber(itemString:match("^[ip]:(%d+)")) or nil
	if not itemID then
		return 0
	end
	if C_Item and type(C_Item.GetItemCount) == "function" then
		return math.max(0, tonumber(C_Item.GetItemCount(itemID, true, false, true, true)) or 0)
	end
	if type(GetItemCount) == "function" then
		return math.max(0, tonumber(GetItemCount(itemID, true)) or 0)
	end
	return 0
end

local function GetSnapshotsForMarketItem(itemString)
	local exactItemString = GetExactItemString(itemString)
	local marketItemString = GetMarketItemString(exactItemString)
	local snapshots = {}
	if not exactItemString or not marketItemString or not state.db or type(state.db.items) ~= "table" then
		return exactItemString, marketItemString, snapshots
	end

	for storedItemString, storedSnapshots in pairs(state.db.items) do
		if type(storedSnapshots) == "table"
			and GetMarketItemString(storedItemString) == marketItemString
		then
			for index = 1, #storedSnapshots do
				snapshots[#snapshots + 1] = storedSnapshots[index]
			end
		end
	end

	table.sort(snapshots, function(left, right)
		return (tonumber(left.time) or 0) < (tonumber(right.time) or 0)
	end)
	return exactItemString, marketItemString, snapshots
end

local function GetSmartAvgCrafted(itemString)
	local _, marketItemString, snapshots = GetSnapshotsForMarketItem(itemString)
	if #snapshots == 0 then
		return nil
	end

	local remaining = GetCurrentInventory(marketItemString)
	if remaining <= 0 then
		return nil
	end

	local priceSum, quantitySum = 0, 0
	for index = #snapshots, 1, -1 do
		if remaining <= 0 then
			break
		end

		local snapshot = snapshots[index]
		local quantity = math.max(0, tonumber(snapshot.quantity) or 0)
		local price = tonumber(snapshot.price)
		if quantity > 0 and price and price >= 0 then
			local used = math.min(remaining, quantity)
			priceSum = priceSum + price * used
			quantitySum = quantitySum + used
			remaining = remaining - used
		end
	end

	if quantitySum <= 0 then
		return nil
	end
	return math.floor(priceSum / quantitySum + 0.5)
end

local function InvalidateItem(itemString)
	if state.customString and type(state.customString.InvalidateCache) == "function" then
		local exactItemString = GetExactItemString(itemString) or itemString
		local marketItemString = GetMarketItemString(exactItemString) or exactItemString
		state.customString.InvalidateCache(SOURCE_KEY, exactItemString)
		if marketItemString ~= exactItemString then
			state.customString.InvalidateCache(SOURCE_KEY, marketItemString)
		end
	end
end

local function SaveSnapshot(itemString, price, quantity)
	local exactItemString = GetExactItemString(itemString)
	price = tonumber(price)
	quantity = math.floor(tonumber(quantity) or 0)
	if not exactItemString or not price or price < 0 or quantity <= 0 then
		return false
	end

	local snapshots = state.db.items[exactItemString]
	if type(snapshots) ~= "table" then
		snapshots = {}
		state.db.items[exactItemString] = snapshots
	end

	snapshots[#snapshots + 1] = {
		price = math.floor(price + 0.5),
		quantity = quantity,
		time = time(),
	}
	while #snapshots > MAX_SNAPSHOTS_PER_ITEM do
		tremove(snapshots, 1)
	end
	InvalidateItem(exactItemString)
	DebugPrint("snapshot item=%s market=%s price=%d qty=%d", exactItemString, GetMarketItemString(exactItemString) or exactItemString, math.floor(price + 0.5), quantity)
	return true
end

GetTSMItemString = function(itemString)
	local result = YayaCore.Price.ToItemString(itemString)
	return type(result) == "string" and result ~= "" and result or nil
end

local function GetSmartAvgBuy(itemString)
	return YayaCore.Price.Get(itemString, "SmartAvgBuy")
end

local function GetVendorBuy(itemString)
	return YayaCore.Price.Get(itemString, "VendorBuy")
end

local function GetTSMPrice(itemString, source)
	return YayaCore.Price.Get(itemString, source)
end

local function GetContainerAverage(item)
	local api = _G.YayaContainerValuesAPI
	if not api or type(api.GetAverageValue) ~= "function" then
		return nil
	end

	local ok, value = pcall(api.GetAverageValue, item)
	return ok and tonumber(value) and value > 0 and value or nil
end

local function GetAuctionQuote(itemID, kind)
	if type(state.auctionProvider) ~= "function" then
		return nil
	end

	local ok, quote = pcall(state.auctionProvider, itemID, kind)
	if (not ok or type(quote) ~= "table") and kind ~= "item" then
		ok, quote = pcall(state.auctionProvider, itemID, "item")
	end
	if (not ok or type(quote) ~= "table") and kind ~= "commodity" then
		ok, quote = pcall(state.auctionProvider, itemID, "commodity")
	end
	if not ok or type(quote) ~= "table" then
		return nil
	end

	local unitPrice = tonumber(quote.unitPrice)
	if not unitPrice or unitPrice <= 0 then
		return nil
	end

	return {
		unitPrice = unitPrice,
		capturedAt = tonumber(quote.capturedAt),
		source = "auction-snapshot",
		estimated = false,
	}
end

local function GetPriceQuote(item, quantity, options)
	options = type(options) == "table" and options or {}
	quantity = math.max(1, math.floor(tonumber(quantity) or 1))

	local exactItemString = GetExactItemString(
		type(item) == "number" and ("i:" .. tostring(item)) or item
	)
	if not exactItemString then
		return nil
	end

	local itemID = tonumber(exactItemString:match("^[ip]:(%d+)"))
	local reservations = type(options.reservations) == "table" and options.reservations or {}
	local inventory = math.max(0, math.floor(GetCurrentInventory(exactItemString)))
	local reserved = math.max(0, tonumber(reservations[itemID or exactItemString]) or 0)
	local smartPrice = GetSmartAvgBuy(exactItemString)
	local smartQuantity = 0
	if options.useInventory ~= false and smartPrice then
		smartQuantity = math.min(quantity, math.max(0, inventory - reserved))
	end

	local remaining = quantity - smartQuantity
	local fallback
	if remaining > 0 then
		fallback = itemID and GetAuctionQuote(itemID, options.auctionKind or "commodity")
		if not fallback then
			local vendorPrice = GetVendorBuy(exactItemString)
			if vendorPrice then
				fallback = { unitPrice = vendorPrice, source = "vendorbuy", estimated = false }
			end
		end
		if not fallback then
			local buyoutPrice = GetTSMPrice(exactItemString, "dbminbuyout")
			if buyoutPrice then
				fallback = { unitPrice = buyoutPrice, source = "dbminbuyout", estimated = false }
			end
		end
		if not fallback then
			local marketPrice = GetTSMPrice(exactItemString, "dbmarket")
			if marketPrice then
				fallback = { unitPrice = marketPrice, source = "dbmarket", estimated = true }
			end
		end
		if not fallback then
			local containerPrice = GetContainerAverage(item)
			if containerPrice then
				fallback = { unitPrice = containerPrice, source = "container-average", estimated = true }
			end
		end
	end

	if remaining > 0 and not fallback then
		return nil
	end

	local total = smartQuantity * (smartPrice or 0)
		+ remaining * (fallback and fallback.unitPrice or 0)
	local source = fallback and fallback.source or "smartAvgBuy"
	if smartQuantity > 0 and fallback then
		source = "smartAvgBuy+" .. fallback.source
	end

	return {
		amount = total / quantity,
		total = total,
		unitPrice = total / quantity,
		source = source,
		estimated = fallback and fallback.estimated == true or false,
		capturedAt = fallback and fallback.capturedAt or nil,
		smartQuantity = smartQuantity,
		fallbackQuantity = remaining,
		pricingKey = table.concat({
			exactItemString,
			tostring(quantity),
			tostring(smartPrice or ""),
			tostring(inventory),
			tostring(reserved),
			tostring(fallback and fallback.source or ""),
			tostring(fallback and fallback.unitPrice or ""),
			tostring(fallback and fallback.capturedAt or ""),
		}, ":"),
	}
end

local function CalculateNetValue(outputUnitValue, outputQuantity, materialCost, marketCut)
	outputUnitValue = tonumber(outputUnitValue)
	outputQuantity = tonumber(outputQuantity) or 1
	materialCost = tonumber(materialCost)
	marketCut = tonumber(marketCut) or 0
	if not outputUnitValue or outputUnitValue <= 0
		or outputQuantity <= 0 or not materialCost or materialCost < 0
	then
		return nil
	end

	return outputUnitValue * outputQuantity * math.max(0, 1 - marketCut) - materialCost
end

local function FormatMoney(value)
	return YayaCore.Money.Format(value)
end

local function GetTooltipItemString(tooltip, data)
	local itemLink = data and data.hyperlink
	if not itemLink and tooltip and type(tooltip.GetItem) == "function" then
		local _, tooltipItemLink = tooltip:GetItem()
		itemLink = tooltipItemLink
	end
	local itemID = data and tonumber(data.id)
	if not itemID and itemLink then
		if C_Item and type(C_Item.GetItemInfoInstant) == "function" then
			local instantItemID = C_Item.GetItemInfoInstant(itemLink)
			itemID = tonumber(instantItemID)
		elseif type(GetItemInfoInstant) == "function" then
			local instantItemID = GetItemInfoInstant(itemLink)
			itemID = tonumber(instantItemID)
		end
	end

	local itemString = itemLink and GetTSMItemString(itemLink)
	DebugPrint("tooltip item id=%s link=%s item=%s", tostring(itemID), tostring(itemLink), tostring(itemString or (itemID and ("i:" .. tostring(itemID)))))
	return itemString or (itemID and ("i:" .. tostring(itemID)))
end

local function AddSmartAvgCraftedToTooltip(tooltip, data)
	if not tooltip or type(tooltip.GetItem) ~= "function" or type(tooltip.AddDoubleLine) ~= "function" then
		return
	end

	local itemString = GetTooltipItemString(tooltip, data)
	local value = itemString and GetSmartAvgCrafted(itemString)
	if not itemString or value == nil then
		return
	end

	local displayValue = FormatMoney(value)
	local marker = ("%s:%s"):format(itemString, displayValue)
	if tooltip.yayaSmartAvgCraftedMarker == marker then
		return
	end

	tooltip.yayaSmartAvgCraftedMarker = marker
	tooltip:AddDoubleLine(
		SOURCE_LABEL,
		displayValue,
		0.3,
		1,
		0.5,
		1,
		1,
		1
	)
	tooltip:Show()
end

local function ResetTooltipMarker(tooltip)
	tooltip.yayaSmartAvgCraftedMarker = nil
end

local function ScheduleTooltipRefresh(tooltip)
	if not tooltip or tooltip.yayaSmartAvgCraftedRefreshQueued then
		return
	end

	tooltip.yayaSmartAvgCraftedRefreshQueued = true
	C_Timer.After(0, function()
		tooltip.yayaSmartAvgCraftedRefreshQueued = nil
		if tooltip.IsShown and tooltip:IsShown() then
			AddSmartAvgCraftedToTooltip(tooltip)
		end
	end)
end

local function InstallTooltipHooks()
	if state.tooltipHooksInstalled then
		return
	end

	local tooltips = { GameTooltip, ItemRefTooltip, ShoppingTooltip1, ShoppingTooltip2, ShoppingTooltip3 }
	for _, tooltip in ipairs(tooltips) do
		if tooltip and type(tooltip.HookScript) == "function" then
			if not tooltip.yayaSmartAvgCraftedResetHooked then
				tooltip.yayaSmartAvgCraftedResetHooked = true
				tooltip:HookScript("OnHide", ResetTooltipMarker)
				tooltip:HookScript("OnTooltipCleared", ResetTooltipMarker)
			end
			pcall(tooltip.HookScript, tooltip, "OnTooltipSetItem", function(currentTooltip, data)
				AddSmartAvgCraftedToTooltip(currentTooltip, data)
				ScheduleTooltipRefresh(currentTooltip)
			end)
		end
	end

	if GameTooltip and not GameTooltip.yayaSmartAvgCraftedBagHooked
		and type(GameTooltip.SetBagItem) == "function" then
		local ok = pcall(hooksecurefunc, GameTooltip, "SetBagItem", function(tooltip)
			AddSmartAvgCraftedToTooltip(tooltip)
			ScheduleTooltipRefresh(tooltip)
		end)
		GameTooltip.yayaSmartAvgCraftedBagHooked = ok
	end

	if TooltipDataProcessor
		and type(TooltipDataProcessor.AddTooltipPostCall) == "function"
		and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Item then
		TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
			AddSmartAvgCraftedToTooltip(tooltip, data)
			ScheduleTooltipRefresh(tooltip)
		end)
	end

	state.tooltipHooksInstalled = true
end

local function CalculateCraftPrice(materials, resultQuantity)
	DebugPrint("craft-cost begin materials=%s resultQuantity=%s", type(materials), tostring(resultQuantity))
	if type(materials) ~= "table" then
		DebugPrint("craft-cost abort reason=invalid-materials")
		return nil
	end

	local total = 0
	local hasMaterials = false
	local materialPrices = {}
	for itemString, quantity in pairs(materials) do
		quantity = tonumber(quantity) or 0
		if quantity > 0 then
			DebugPrint("craft-cost input item=%s quantity=%s", tostring(itemString), tostring(quantity))
			hasMaterials = true
			local price = GetSmartAvgBuy(itemString) or GetVendorBuy(itemString)
			if not price then
				DebugPrint("craft-cost abort reason=missing-price item=%s", tostring(itemString))
				return nil
			end
			materialPrices[itemString] = price
			total = total + price * quantity
		end
	end

	resultQuantity = tonumber(resultQuantity) or 1
	if not hasMaterials or resultQuantity <= 0 or total < 0 then
		DebugPrint("craft-cost abort reason=invalid-total hasMaterials=%s total=%s resultQuantity=%s", tostring(hasMaterials), tostring(total), tostring(resultQuantity))
		return nil
	end
	DebugPrint("craft-cost done total=%s unit=%s resultQuantity=%s", tostring(total), tostring(total / resultQuantity), tostring(resultQuantity))
	return total / resultQuantity, total, materialPrices
end

local function GetCraftData(recipeString, spellID)
	local tsm = state.tsm
	local craftString
	if spellID and state.craftString and type(state.craftString.Get) == "function" then
		local ok, result = pcall(state.craftString.Get, spellID)
		craftString = ok and result or nil
	end
	local outputItemString
	local resultQuantity
	local materials = {}

	if type(recipeString) == "string" and recipeString:match("^r:%d+") then
		if state.recipeString and type(state.recipeString.GetSpellId) == "function" then
			local ok, recipeSpellID = pcall(state.recipeString.GetSpellId, recipeString)
			spellID = ok and recipeSpellID or spellID
		end
		if state.craftString and type(state.craftString.FromRecipeString) == "function" then
			local ok, converted = pcall(state.craftString.FromRecipeString, recipeString)
			craftString = ok and converted or craftString
		end
		if TSM_API and type(TSM_API.GetCraftingQueueItemMaterials) == "function" then
			pcall(TSM_API.GetCraftingQueueItemMaterials, recipeString, materials)
		end
		if tsm and tsm.Crafting and tsm.Crafting.Cost
			and type(tsm.Crafting.Cost.GetLevelItemString) == "function" then
			local ok, levelItemString = pcall(tsm.Crafting.Cost.GetLevelItemString, recipeString)
			outputItemString = ok and levelItemString or nil
		end
	elseif craftString and tsm and tsm.Crafting and type(tsm.Crafting.GetMatsAsTable) == "function" then
		pcall(tsm.Crafting.GetMatsAsTable, craftString, materials)
	end

	if not craftString or not outputItemString then
		if craftString and tsm and tsm.Crafting then
			if not outputItemString and type(tsm.Crafting.GetItemString) == "function" then
				local ok, result = pcall(tsm.Crafting.GetItemString, craftString)
				outputItemString = ok and result or nil
			end
		end
	end
	if craftString and tsm and tsm.Crafting then
		if type(tsm.Crafting.GetNumResult) == "function" then
			local ok, result = pcall(tsm.Crafting.GetNumResult, craftString)
			resultQuantity = ok and result or nil
		end
	end

	local price, craftCost, materialPrices = CalculateCraftPrice(materials, resultQuantity)
	return {
		spellID = tonumber(spellID),
		itemString = outputItemString,
		price = price,
		craftCost = craftCost,
		materials = materials,
		materialPrices = materialPrices,
		quantity = resultQuantity or 1,
	}
end

local function GetCraftSpellID(recipeID)
	local spellID = tonumber(recipeID)
	if type(C_TradeSkillUI) == "table" and type(C_TradeSkillUI.GetRecipeInfo) == "function" then
		local ok, recipeInfo = pcall(C_TradeSkillUI.GetRecipeInfo, recipeID)
		if ok and type(recipeInfo) == "table" then
			spellID = tonumber(recipeInfo.recipeID)
				or tonumber(recipeInfo.spellID)
				or spellID
		end
	end
	return spellID
end

local function GetItemIDFromString(itemString)
	return type(itemString) == "string" and tonumber(itemString:match("^[ip]:(%d+)")) or nil
end

local function GetReagentItemString(reagent, itemID)
	local candidate = reagent and (
		reagent.itemLink or reagent.hyperlink or reagent.itemString or reagent.link
	)
	if not candidate and type(reagent) == "table" and type(reagent.GetItemLink) == "function" then
		local ok, link = pcall(reagent.GetItemLink, reagent)
		candidate = ok and link or nil
	end
	return GetExactItemString(candidate or (itemID and ("i:" .. tostring(itemID))))
end

local function GetResourceReturnItemID(resource)
	local reagent = resource and resource.reagent
	return tonumber(resource and resource.itemID)
		or tonumber(reagent and reagent.itemID)
end

local function GetActualCraftCost(data, resourcesReturned)
	local baseCost = tonumber(data and data.craftCost)
	if not baseCost or type(resourcesReturned) ~= "table" then
		return baseCost, 0
	end

	local remainingByItemID = {}
	for itemString, quantity in pairs(data.materials or {}) do
		local itemID = type(itemString) == "string" and tonumber(itemString:match("^[ip]:(%d+)")) or nil
		local unitPrice = tonumber(data.materialPrices and data.materialPrices[itemString])
		quantity = tonumber(quantity) or 0
		if itemID and quantity > 0 and unitPrice and unitPrice >= 0 then
			local bucket = remainingByItemID[itemID] or { quantity = 0, value = 0 }
			bucket.quantity = bucket.quantity + quantity
			bucket.value = bucket.value + quantity * unitPrice
			remainingByItemID[itemID] = bucket
		end
	end

	local savedValue = 0
	local returnCount = 0
	for _, resource in pairs(resourcesReturned) do
		local itemID = GetResourceReturnItemID(resource)
		local quantity = math.max(0, tonumber(resource and resource.quantity) or 0)
		local bucket = itemID and remainingByItemID[itemID]
		if bucket and quantity > 0 and bucket.quantity > 0 then
			local returnedQuantity = math.min(quantity, bucket.quantity)
			local unitPrice = bucket.value / bucket.quantity
			savedValue = savedValue + returnedQuantity * unitPrice
			bucket.quantity = bucket.quantity - returnedQuantity
			bucket.value = bucket.value - returnedQuantity * unitPrice
			returnCount = returnCount + 1
			DebugPrint("craft-cost resource-return item=%s quantity=%s value=%s", tostring(itemID), tostring(returnedQuantity), tostring(returnedQuantity * unitPrice))
		end
	end

	local actualCost = math.max(0, baseCost - savedValue)
	DebugPrint("craft-cost actual base=%s saved=%s actual=%s returns=%s", tostring(baseCost), tostring(savedValue), tostring(actualCost), tostring(returnCount))
	return actualCost, savedValue
end

local function GetBlizzardOutputItemString(recipeID, craftingReagents)
	if type(C_TradeSkillUI) ~= "table" or type(C_TradeSkillUI.GetRecipeOutputItemData) ~= "function" then
		return nil
	end

	local ok, output = pcall(C_TradeSkillUI.GetRecipeOutputItemData, recipeID, craftingReagents, nil)
	if not ok or type(output) ~= "table" then
		return nil
	end

	return GetExactItemString(output.hyperlink or output.itemLink or (output.itemID and ("i:" .. tostring(output.itemID))))
end

local function GetBlizzardCraftData(recipeID, craftingReagents)
	if type(C_TradeSkillUI) ~= "table" or type(C_TradeSkillUI.GetRecipeSchematic) ~= "function" then
		return nil, nil
	end

	local ok, schematic = pcall(C_TradeSkillUI.GetRecipeSchematic, recipeID, false)
	if not ok or type(schematic) ~= "table" then
		return nil, nil
	end

	local materials = {}
	local hasMaterials = false
	for _, slot in ipairs(schematic.reagentSlotSchematics or {}) do
		local allowedItems = {}
		for _, candidate in ipairs(slot.reagents or {}) do
			local itemID = tonumber(candidate.itemID)
			if itemID and itemID > 0 then
				allowedItems[itemID] = true
			end
		end

		local selectedQuantity = 0
		for _, info in ipairs(craftingReagents or {}) do
			local reagent = info and info.reagent
			local itemID = tonumber(reagent and reagent.itemID)
			local sameSlot = tonumber(info and info.dataSlotIndex) == tonumber(slot.dataSlotIndex)
			if sameSlot and itemID and allowedItems[itemID] then
				local quantity = math.max(0, tonumber(info.quantity) or 0)
				local itemString = GetReagentItemString(reagent, itemID)
				materials[itemString] = (materials[itemString] or 0) + quantity
				selectedQuantity = selectedQuantity + quantity
				hasMaterials = hasMaterials or quantity > 0
			end
		end

		local requiredQuantity = tonumber(slot.quantityRequired) or 0
		if selectedQuantity <= 0 and slot.required then
			local reagent = slot.reagents and slot.reagents[1]
			local itemID = reagent and tonumber(reagent.itemID)
			if itemID and itemID > 0 and requiredQuantity > 0 then
				local itemString = GetReagentItemString(reagent, itemID)
				materials[itemString] = (materials[itemString] or 0) + requiredQuantity
				hasMaterials = true
			end
		end
	end

	local resultQuantity = math.max(1, tonumber(schematic.quantityMin) or 1)
	local price, craftCost, materialPrices
	if hasMaterials then
		price, craftCost, materialPrices = CalculateCraftPrice(materials, resultQuantity)
	else
		price = 0
	end
	return price, resultQuantity, GetBlizzardOutputItemString(recipeID, craftingReagents), craftCost, materials, materialPrices
end

local function CaptureTSMCraft(recipeString, quantity, craftingReagents)
	local spellID = nil
	local recipeID = nil
	if type(recipeString) == "number" then
		recipeID = recipeString
		spellID = GetCraftSpellID(recipeString)
		if state.recipeString and type(state.recipeString.Get) == "function" then
			local ok, converted = pcall(state.recipeString.Get, spellID)
			recipeString = ok and converted or recipeString
		end
	elseif type(recipeString) == "string" and state.recipeString then
		local ok, value = pcall(state.recipeString.GetSpellId, recipeString)
		spellID = ok and value or nil
	end

	local data = GetCraftData(recipeString, spellID)
	if recipeID then
		local outputItemString = GetBlizzardOutputItemString(recipeID, craftingReagents)
		if outputItemString then
			local currentItemID = GetItemIDFromString(data.itemString)
			local outputItemID = GetItemIDFromString(outputItemString)
			local currentHasVariant = type(data.itemString) == "string"
				and data.itemString:find("::", 1, true)
			if not data.itemString
				or currentItemID ~= outputItemID
				or outputItemString:find("::", 1, true)
				or not currentHasVariant
			then
				data.itemString = outputItemString
			end
		end
	end
	if recipeID and data.price == nil then
		local price, resultQuantity, outputItemString, craftCost, materials, materialPrices = GetBlizzardCraftData(recipeID, craftingReagents)
		data.price = price
		data.craftCost = craftCost
		data.materials = materials or data.materials
		data.materialPrices = materialPrices or data.materialPrices
		data.quantity = resultQuantity or data.quantity
		data.itemString = data.itemString or outputItemString
	end
	data.craftingReagents = craftingReagents
	if data.spellID and data.price ~= nil then
		local craftQuantity = math.max(1, math.floor(tonumber(quantity) or 1))
		local outputItemID = GetItemIDFromString(data.itemString)
		local capturedAt = type(GetTime) == "function" and GetTime() or time()
		local duplicate
		for _, pending in ipairs(state.pendingCrafts) do
			if pending.spellID == data.spellID
				and pending.outputItemID == outputItemID
				and pending.quantity == craftQuantity
				and (not pending.capturedAt or not capturedAt or capturedAt - pending.capturedAt <= 0.1)
			then
				duplicate = pending
				break
			end
		end
		if not duplicate then
			state.nextPendingSequence = state.nextPendingSequence + 1
			data.sequence = state.nextPendingSequence
			data.remaining = craftQuantity
			data.quantity = data.quantity or 1
			data.outputItemID = outputItemID
			data.capturedAt = capturedAt
			table.insert(state.pendingCrafts, data)
		end
		DebugPrint("craft queued spell=%s item=%s price=%d qty=%d", data.spellID, tostring(data.itemString), data.price, data.quantity)
	else
		DebugPrint("craft ignored spell=%s item=%s price=%s", tostring(data.spellID), tostring(data.itemString), tostring(data.price))
	end
end

local function FindPendingCraft(spellID, result)
	spellID = tonumber(spellID)
	local resultItemID = tonumber(result and result.itemID)
	local bestIndex
	for index, pending in ipairs(state.pendingCrafts) do
		if (not spellID or pending.spellID == spellID)
			and (not resultItemID or not pending.outputItemID or pending.outputItemID == resultItemID)
		then
			bestIndex = index
			break
		end
	end
	if bestIndex then
		return bestIndex, state.pendingCrafts[bestIndex]
	end

	if spellID then
		for index, pending in ipairs(state.pendingCrafts) do
			if pending.spellID == spellID then
				return index, pending
			end
		end
	end
	return nil, nil
end

local function RecordSuccessfulCraft(spellID, result)
	local pendingIndex, data = FindPendingCraft(spellID or state.activeSpellID, result)
	if not data then
		pendingIndex, data = FindPendingCraft(nil, result)
	end
	if not data then
		return
	end

	local itemString = data and data.itemString
	local quantity = data and data.quantity
	local price = data and data.price
	local actualCraftCost = data and data.craftCost
	local savedValue = 0
	if result and result.itemID then
		local resultItemString = GetExactItemString(result.hyperlink or result.itemLink or result.link)
		local resultItemID = GetItemIDFromString(resultItemString)
		if resultItemID == tonumber(result.itemID) then
			itemString = resultItemString
		elseif not itemString or (GetItemIDFromString(itemString) and GetItemIDFromString(itemString) ~= tonumber(result.itemID)) then
			itemString = "i:" .. tostring(result.itemID)
		end
		quantity = result.quantity or quantity
		actualCraftCost, savedValue = GetActualCraftCost(data, result.resourcesReturned)
		if actualCraftCost and tonumber(result.quantity) and tonumber(result.quantity) > 0 then
			price = actualCraftCost / tonumber(result.quantity)
			DebugPrint("craft realized item=%s output=%s exact=%s baseCost=%s saved=%s actualCost=%s unit=%s", tostring(result.itemID), tostring(result.quantity), tostring(itemString), tostring(data.craftCost), tostring(savedValue), tostring(actualCraftCost), tostring(price))
		end
	end
	if not data or not itemString or price == nil then
		DebugPrint("craft success without data spell=%s", spellID)
		return
	end

	local saved = SaveSnapshot(itemString, price, quantity)
	DebugPrint("craft recorded spell=%s item=%s saved=%s", spellID, itemString, tostring(saved))
	data.remaining = math.max(0, (data.remaining or 1) - 1)
	if data.remaining <= 0 then
		tremove(state.pendingCrafts, pendingIndex)
	end
end

local function InstallBlizzardCraftHooks()
	if state.craftApiHooksInstalled or type(C_TradeSkillUI) ~= "table" then
		return
	end

	local installed = false
	if type(C_TradeSkillUI.CraftRecipe) == "function" then
		hooksecurefunc(C_TradeSkillUI, "CraftRecipe", function(recipeID, quantity, craftingReagents)
			CaptureTSMCraft(recipeID, quantity, craftingReagents)
		end)
		installed = true
	end
	if type(C_TradeSkillUI.CraftEnchant) == "function" then
		hooksecurefunc(C_TradeSkillUI, "CraftEnchant", function(recipeID, quantity, craftingReagents)
			CaptureTSMCraft(recipeID, quantity, craftingReagents)
		end)
		installed = true
	end
	if type(C_TradeSkillUI.CraftSalvage) == "function" then
		hooksecurefunc(C_TradeSkillUI, "CraftSalvage", function(recipeID, quantity, craftingReagents)
			CaptureTSMCraft(recipeID, quantity, craftingReagents)
		end)
		installed = true
	end
	state.craftApiHooksInstalled = installed
end

local function InstallHooks()
	local tsm = state.tsm
	InstallBlizzardCraftHooks()
	if state.hooksInstalled or not tsm or not tsm.Crafting or not tsm.Crafting.ProfessionUtil then
		return
	end

	if type(tsm.Crafting.ProfessionUtil.Craft) == "function" then
		hooksecurefunc(tsm.Crafting.ProfessionUtil, "Craft", CaptureTSMCraft)
		state.hooksInstalled = true
	end
end

local function InitializeTSM(tsm, customString)
	if type(tsm) ~= "table" then
		return
	end
	state.tsm = tsm
	state.customString = customString or state.customString
	state.itemString = state.itemString or tsm.LibTSMTypes:Include("Item.ItemString")
	state.craftString = state.craftString or tsm.LibTSMTypes:Include("Crafting.CraftString")
	state.recipeString = state.recipeString or tsm.LibTSMTypes:Include("Crafting.RecipeString")
	RegisterSource()
	InstallHooks()
end

RegisterSource = function()
	local tsm = state.tsm or (type(TSM) == "table" and TSM or nil)
	if state.registered or not tsm or not tsm.LibTSMTypes then
		return
	end

	state.customString = state.customString or tsm.LibTSMTypes:Include("CustomString")
	state.itemString = state.itemString or tsm.LibTSMTypes:Include("Item.ItemString")
	state.craftString = state.craftString or tsm.LibTSMTypes:Include("Crafting.CraftString")
	state.recipeString = state.recipeString or tsm.LibTSMTypes:Include("Crafting.RecipeString")
	if not state.customString or type(state.customString.RegisterSource) ~= "function" then
		return
	end

	if not state.customString.IsSourceRegistered(SOURCE_LOOKUP_KEY) then
		state.customString.RegisterSource(
			"YayaCraftedPrice",
			SOURCE_KEY,
			SOURCE_LABEL,
			GetSmartAvgCrafted,
			state.customString.SOURCE_TYPE.NORMAL
		)
	end
	local inventory = tsm.LibTSMApp and tsm.LibTSMApp:Include("Service.Inventory")
	if inventory and type(inventory.RegisterDependentCustomSource) == "function" then
		inventory.RegisterDependentCustomSource(SOURCE_KEY)
	end
	state.registered = true
	InstallHooks()
end

local function NotifyTSM()
	if type(YayaCraftedPriceTSMRegister) == "function" then
		YayaCraftedPriceTSMRegister(YayaCraftedPriceAPI)
	end
end

local function PrintDebugStatus()
	local itemCount, snapshotCount = 0, 0
	if state.db and type(state.db.items) == "table" then
		for _, snapshots in pairs(state.db.items) do
			if type(snapshots) == "table" then
				itemCount = itemCount + 1
				snapshotCount = snapshotCount + #snapshots
			end
		end
	end

	local sourceRegistered = state.registered
	if state.customString and type(state.customString.IsSourceRegistered) == "function" then
		local ok, result = pcall(state.customString.IsSourceRegistered, SOURCE_LOOKUP_KEY)
		sourceRegistered = ok and result or sourceRegistered
	end
	ChatPrint(
		"debug=%s TSM=%s source=%s tsm-craft=%s api-craft=%s tooltip=%s items=%d snapshots=%d",
		state.debugEnabled and "ON" or "OFF",
		state.tsm and "OK" or "NO",
		sourceRegistered and "OK" or "NO",
		state.hooksInstalled and "OK" or "NO",
		state.craftApiHooksInstalled and "OK" or "NO",
		state.tooltipHooksInstalled and "OK" or "NO",
		itemCount,
		snapshotCount
	)
end

local function HandleSlashCommand(message)
	local command = tostring(message or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
	if command == "debug" then
		state.debugEnabled = not state.debugEnabled
		ChatPrint("debug %s", state.debugEnabled and "activé" or "désactivé")
		PrintDebugStatus()
	elseif command == "debug on" then
		state.debugEnabled = true
		PrintDebugStatus()
	elseif command == "debug off" then
		state.debugEnabled = false
		PrintDebugStatus()
	elseif command == "debug status" or command == "status" then
		PrintDebugStatus()
	else
		ChatPrint("Commande : /ycp debug [on|off|status]")
	end
end

SLASH_YAYACRAFTEDPRICE1 = "/ycp"
SlashCmdList.YAYACRAFTEDPRICE = HandleSlashCommand

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("TRADE_SKILL_ITEM_CRAFTED_RESULT")
eventFrame:RegisterEvent("UNIT_SPELLCAST_START")
eventFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
eventFrame:RegisterEvent("UNIT_SPELLCAST_FAILED")
eventFrame:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
eventFrame:SetScript("OnEvent", function(_, event, ...)
	if event == "ADDON_LOADED" then
		local loadedAddon = ...
		if loadedAddon == "YayaCraftedPrice" then
			YayaCraftedPriceDB = type(YayaCraftedPriceDB) == "table" and YayaCraftedPriceDB or {}
			YayaCraftedPriceDB.items = type(YayaCraftedPriceDB.items) == "table" and YayaCraftedPriceDB.items or {}
			state.db = YayaCraftedPriceDB
		end
	elseif event == "PLAYER_LOGIN" then
		if not state.db then
			YayaCraftedPriceDB = type(YayaCraftedPriceDB) == "table" and YayaCraftedPriceDB or { items = {} }
			YayaCraftedPriceDB.items = type(YayaCraftedPriceDB.items) == "table" and YayaCraftedPriceDB.items or {}
			state.db = YayaCraftedPriceDB
		end
		RegisterSource()
		NotifyTSM()
		InstallTooltipHooks()
		C_Timer.After(0, function()
			RegisterSource()
			NotifyTSM()
			InstallHooks()
			InstallTooltipHooks()
		end)
	elseif event == "TRADE_SKILL_ITEM_CRAFTED_RESULT" then
		local result = ...
		local itemID = type(result) == "table" and result.itemID or result
		local quantity = type(result) == "table" and result.quantity or select(2, ...)
		if tonumber(itemID) and tonumber(quantity) and tonumber(quantity) > 0 then
			local craftResult = type(result) == "table" and result or {
				itemID = tonumber(itemID),
				quantity = tonumber(quantity),
			}
			DebugPrint("craft result item=%s qty=%s link=%s exact=%s multicraft=%s returns=%s", itemID, quantity, tostring(craftResult.hyperlink or craftResult.itemLink or craftResult.link), tostring(GetExactItemString(craftResult.hyperlink or craftResult.itemLink or craftResult.link)), tostring(craftResult.multicraft), tostring(craftResult.resourcesReturned and "yes" or "no"))
			RecordSuccessfulCraft(state.activeSpellID, craftResult)
		end
	elseif event == "UNIT_SPELLCAST_START" then
		local unit, _, spellID = ...
		if unit == "player" then
			local _, pending = FindPendingCraft(spellID, nil)
			state.activeSpellID = pending and tonumber(spellID) or state.activeSpellID
		end
	elseif event == "UNIT_SPELLCAST_FAILED" or event == "UNIT_SPELLCAST_INTERRUPTED" then
		local unit, _, spellID = ...
		if unit == "player" then
			local pendingIndex, pending = FindPendingCraft(spellID, nil)
			if pending and pendingIndex then
				tremove(state.pendingCrafts, pendingIndex)
			end
			if tonumber(state.activeSpellID) == tonumber(spellID) then
				state.activeSpellID = nil
			end
		end
	elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
		local unit, _, spellID = ...
		if unit == "player" then
			DebugPrint("craft spell succeeded spell=%s", spellID)
			local _, pending = FindPendingCraft(spellID, nil)
			state.activeSpellID = pending and tonumber(spellID) or nil
		end
	end
end)

YayaCraftedPriceAPI = YayaCraftedPriceAPI or {}
YayaCraftedPriceAPI.GetSmartAvgCrafted = GetSmartAvgCrafted
YayaCraftedPriceAPI.InitializeTSM = InitializeTSM
YayaCraftedPriceAPI.GetPriceQuote = GetPriceQuote
YayaCraftedPriceAPI.CalculateNetValue = CalculateNetValue
YayaCraftedPriceAPI.SetAuctionProvider = function(provider)
	state.auctionProvider = type(provider) == "function" and provider or nil
end
