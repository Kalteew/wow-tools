local addonName = ...

local MAX_ROWS = 60
local QUERY_TIMEOUT = 5
local BETWEEN_QUERIES = 0.1
local BETWEEN_CYCLES = 0.05
local FAST_BATCH_SIZE = 100
local ALERT_REPEAT_AFTER = 30
local PURCHASE_READY_DELAY = 0.15
local PRICE_SORT = {
	 sortOrder = Enum.AuctionHouseSortOrder.Price,
	 reverseSort = false,
}

local state = {
	db = nil,
	frame = nil,
	tab = nil,
	events = nil,
	groupListContent = nil,
	groupButtons = {},
	groupPaths = {},
	selectedGroup = nil,
	sourceItems = {},
	items = {},
	needsState = "empty",
	queue = {},
	queueIndex = 0,
	active = nil,
	scanning = false,
	fastMode = false,
	cycle = 0,
	nextTimer = nil,
	timeoutTimer = nil,
	results = {},
	resultMap = {},
	resultRows = {},
	resultsContent = nil,
	inventoryRefreshPending = false,
	scanStats = { items = 0, goldSpent = 0 },
	seenAlerts = {},
	suppressedResults = {},
	purchase = nil,
	resumeAfterPurchase = false,
}

local UpdateView
local RebuildItems
local GetShoppingSettings
local GetShoppingOperation
local GetItemsFromGroup
local RefreshOperationLimits
local RefreshGroupList
local ProcessNext
local StopScan
local StartScan
local EnsureUI
local ResumeScanAfterPurchase
local StartPendingPurchase

local function GetDB()
	if type(YayaReagentSniperDB) ~= "table" then
		YayaReagentSniperDB = {}
	end
	local db = YayaReagentSniperDB
	db.group = type(db.group) == "string" and db.group or ""
	db.sound = db.sound ~= false
	db.debug = db.debug == true
	db.inTransit = type(db.inTransit) == "table" and db.inTransit or {}
	db.maxGoldPerScan = math.max(0, math.floor(tonumber(db.maxGoldPerScan) or 0))
	return db
end

local function SetStatus(text)
	if state.frame and state.frame.status then
		state.frame.status:SetText(text or "")
	end
end

local function BuyDebug(message, ...)
	if not state.db or not state.db.debug then
		return
	end
	local ok, text = pcall(format, message, ...)
	if not ok then
		text = message .. " | erreur du logger: " .. tostring(text)
	end
	print(format("|cff33ff99YRS achat|r [%.3f] %s", GetTime(), text))
end

local function SetScanStatus()
	SetStatus(format("Scan en cours — cycle %d", math.max(1, state.cycle)))
end

local function CancelTimer(field)
	local timer = state[field]
	if timer and timer.Cancel then
		timer:Cancel()
	end
	state[field] = nil
end

local function Schedule(field, delay, callback)
	CancelTimer(field)
	state[field] = C_Timer.NewTimer(delay, function()
		state[field] = nil
		callback()
	end)
end

local function IsAHVisible()
	return AuctionHouseFrame and AuctionHouseFrame:IsShown()
end

local function GetItemID(itemString)
	return tonumber(string.match(itemString or "", "^[pi]:(%d+)"))
end

local function GetItemName(itemID)
	local name = C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(itemID)
	return name or (GetItemInfo and select(1, GetItemInfo(itemID))) or "Chargement…"
end

local function GetItemTexture(itemID)
	if C_Item and C_Item.GetItemInfoInstant then
		local icon = select(5, C_Item.GetItemInfoInstant(itemID))
		if icon then
			return icon
		end
	end
	return GetItemIcon and GetItemIcon(itemID)
end

local function GetItemQuality(itemID, itemString)
	if not C_TradeSkillUI or type(C_TradeSkillUI.GetItemReagentQualityInfo) ~= "function" then
		return nil, nil
	end
	local candidates = { itemID, itemString }
	for _, itemInfo in ipairs(candidates) do
		if itemInfo then
			local ok, qualityInfo = pcall(C_TradeSkillUI.GetItemReagentQualityInfo, itemInfo)
			if ok and type(qualityInfo) == "table" and type(qualityInfo.iconChat) == "string" then
				local quality = tonumber(qualityInfo.iconChat:match("Quality%-12%-Tier(%d+)"))
					or tonumber(qualityInfo.iconChat:match("Quality%-Tier(%d+)"))
				return quality, qualityInfo.iconChat
			end
		end
	end
	return nil, nil
end

local function RequestItemInfo(item)
	if item.infoRequested or not Item or not Item.CreateFromItemID then
		return
	end
	item.infoRequested = true
	local itemObject = Item:CreateFromItemID(item.itemID)
	itemObject:ContinueOnItemLoad(function()
		local name = itemObject:GetItemName()
		local icon = GetItemTexture(item.itemID)
		local quality, qualityAtlas = GetItemQuality(item.itemID, item.itemString)
		if name then
			item.name = name
		end
		if icon then
			item.icon = icon
		end
		if quality then
			item.quality = quality
		end
		if qualityAtlas then
			item.qualityAtlas = qualityAtlas
		end
		for _, result in ipairs(state.results) do
			if result.item == item then
				result.name = item.name
			end
		end
		UpdateView()
	end)
end

local function GetItemTooltipLink(item)
	if item and type(item.itemString) == "string" and string.match(item.itemString, "^i:") then
		return "item:" .. string.sub(item.itemString, 3)
	end
	return item and item.itemID and ("item:" .. tostring(item.itemID)) or nil
end

local function ShowItemTooltip(cell)
	local row = cell:GetParent()
	local result = row.data
	if row.hover then
		row.hover:Show()
	end
	local link = result and GetItemTooltipLink(result.item)
	if not link or not GameTooltip then
		return
	end
	GameTooltip:SetOwner(cell, "ANCHOR_RIGHT")
	GameTooltip:SetHyperlink(link)
	GameTooltip:Show()
end

local function HideItemTooltip(cell)
	local row = cell and cell:GetParent()
	if row and row.hover then
		row.hover:Hide()
	end
	if cell and GameTooltip and GameTooltip:IsOwned(cell) then
		GameTooltip:Hide()
	end
end

local function GetItemClassID(itemID)
	if C_Item and C_Item.GetItemInfoInstant then
		return select(6, C_Item.GetItemInfoInstant(itemID))
	end
	return GetItemInfoInstant and select(6, GetItemInfoInstant(itemID)) or nil
end

local function IsCommodity(itemID)
	return Enum.ItemClass.Tradegoods and GetItemClassID(itemID) == Enum.ItemClass.Tradegoods
end

local function GetGroupLabel(path)
	if not path then
		return "Tous les groupes"
	end
	if TSM_API and type(TSM_API.FormatGroupPath) == "function" then
		local ok, label = pcall(TSM_API.FormatGroupPath, path)
		if ok and type(label) == "string" and label ~= "" then
			return label
		end
	end
	return path
end

local function RefreshGroupPaths()
	wipe(state.groupPaths)
	state.groupPaths[1] = { path = nil, label = "Tous les groupes" }
	if not TSM_API or type(TSM_API.GetGroupPaths) ~= "function" then
		state.selectedGroup = nil
		RefreshGroupList()
		return
	end

	local paths = {}
	local ok = pcall(TSM_API.GetGroupPaths, paths)
	if not ok then
		RefreshGroupList()
		return
	end
	table.sort(paths)
	for _, path in ipairs(paths) do
		local rawItems = {}
		local seenItems = {}
		local reagentCount = 0
		GetItemsFromGroup(path, rawItems)
		for _, itemString in ipairs(rawItems) do
			local itemID = GetItemID(itemString)
			local valid = itemID and IsCommodity(itemID) and GetShoppingOperation(itemString)
			if valid and not seenItems[itemID] then
				seenItems[itemID] = true
				reagentCount = reagentCount + 1
			end
		end
		if reagentCount > 0 then
			state.groupPaths[#state.groupPaths + 1] = {
				path = path,
				label = format("%s (%d)", GetGroupLabel(path), reagentCount),
			}
		end
	end

	local wanted = state.db.group ~= "" and state.db.group or nil
	state.selectedGroup = nil
	for _, entry in ipairs(state.groupPaths) do
		if entry.path == wanted then
			state.selectedGroup = wanted
			break
		end
	end
	RefreshGroupList()
end

GetItemsFromGroup = function(path, result)
	if not TSM_API or type(TSM_API.GetGroupItems) ~= "function" or not path then
		return
	end
	local ok = pcall(TSM_API.GetGroupItems, path, true, result)
	if not ok then
		return
	end
end

RefreshGroupList = function()
	if not state.groupListContent then
		return
	end
	for _, button in ipairs(state.groupButtons) do
		button:Hide()
	end
	for index, entry in ipairs(state.groupPaths) do
		local button = state.groupButtons[index]
		if not button then
			button = CreateFrame("Button", nil, state.groupListContent, "UIPanelButtonTemplate")
			button:SetHeight(24)
			button:SetText("")
			local label = button:GetFontString()
			if label then
				label:ClearAllPoints()
				label:SetPoint("LEFT", button, "LEFT", 10, 0)
				label:SetPoint("RIGHT", button, "RIGHT", -8, 0)
				label:SetJustifyH("LEFT")
				label:SetWordWrap(false)
				label:SetMaxLines(1)
			end
			button:SetScript("OnClick", function(self)
				local selected = self.entry
				if not selected then
					return
				end
				state.selectedGroup = selected.path
				state.db.group = selected.path or ""
				RebuildItems()
				RefreshGroupList()
			end)
			button:SetScript("OnEnter", function(self)
				local fontString = self:GetFontString()
				if fontString and fontString.IsTruncated and fontString:IsTruncated() then
					GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
					GameTooltip:SetText(self.fullLabel or "", 1, 1, 1, true)
					GameTooltip:Show()
				end
			end)
			button:SetScript("OnLeave", function(self)
				if GameTooltip and GameTooltip:IsOwned(self) then
					GameTooltip:Hide()
				end
			end)
			state.groupButtons[index] = button
		end
		button.entry = entry
		button.fullLabel = entry.label
		button:ClearAllPoints()
		button:SetPoint("TOPLEFT", state.groupListContent, "TOPLEFT", 4, -4 - (index - 1) * 26)
		button:SetPoint("RIGHT", state.groupListContent, "RIGHT", -4, 0)
		button:SetText((entry.path == state.selectedGroup and "> " or "") .. entry.label)
		button:Show()
	end
	state.groupListContent:SetHeight(math.max(1, #state.groupPaths * 26))
end

local function GetTSMSettingsTables()
	if type(TradeSkillMasterDB) ~= "table" then
		return nil, nil
	end
	if not TSM_API or type(TSM_API.GetActiveProfile) ~= "function" then
		return nil, nil
	end
	local ok, profile = pcall(TSM_API.GetActiveProfile)
	if not ok or type(profile) ~= "string" then
		return nil, nil
	end
	local prefix = "p@" .. profile .. "@"
	local operations = TradeSkillMasterDB["g@ @userData@sharedOperations"]
	if not TradeSkillMasterDB["g@ @coreOptions@globalOperations"] then
		operations = TradeSkillMasterDB[prefix .. "userData@operations"]
	end
	local groups = TradeSkillMasterDB[prefix .. "userData@groups"]
	return type(operations) == "table" and operations or nil, type(groups) == "table" and groups or nil
end

local function GetParentGroupPath(path)
	return string.match(path or "", "^(.*)`[^`]*$") or ""
end

local function GetEffectiveShoppingOperations(groups, path, visited)
	if type(groups) ~= "table" then
		return nil
	end
	path = path or ""
	visited = visited or {}
	if visited[path] then
		return nil
	end
	visited[path] = true
	local group = groups[path]
	local shopping = group and group.Shopping
	if shopping and (path == "" or shopping.override) then
		return shopping
	end
	if path == "" then
		return shopping
	end
	return GetEffectiveShoppingOperations(groups, GetParentGroupPath(path), visited)
end

local function ResolveOperationSetting(operations, operationName, key, default)
	local currentName = operationName
	local visited = {}
	while currentName and not visited[currentName] do
		visited[currentName] = true
		local settings = operations and operations[currentName]
		if not settings then
			return default
		end
		local relationships = settings.relationships
		local nextName = relationships and relationships[key]
		if not nextName then
			local value = settings[key]
			return value ~= nil and value or default
		end
		currentName = nextName
	end
	return default
end

local function IsOperationIgnored(settings)
	local character = UnitName and UnitName("player")
	local faction = UnitFactionGroup and UnitFactionGroup("player")
	local realm = GetRealmName and GetRealmName()
	local factionrealm = faction and realm and (faction .. " - " .. realm) or nil
	local characterKey = character and factionrealm and (character .. " - " .. factionrealm) or nil
	return settings.ignorePlayer and characterKey and settings.ignorePlayer[characterKey]
		or settings.ignoreFactionrealm and factionrealm and settings.ignoreFactionrealm[factionrealm]
end

GetShoppingOperation = function(itemString)
	local operationsRoot, groups = GetTSMSettingsTables()
	local shoppingOperations = operationsRoot and operationsRoot.Shopping
	if not shoppingOperations or not groups then
		return nil, nil
	end
	local path
	if TSM_API and type(TSM_API.GetGroupPathByItem) == "function" then
		local ok, groupPath = pcall(TSM_API.GetGroupPathByItem, itemString)
		path = ok and groupPath or nil
	end
	local assigned = GetEffectiveShoppingOperations(groups, path or "")
	if not assigned then
		return nil, nil
	end
	for index = 1, #assigned do
		local operationName = assigned[index]
		local settings = shoppingOperations[operationName]
		if settings and not IsOperationIgnored(settings) then
			return settings, operationName, shoppingOperations
		end
	end
	return nil, nil
end

local function GetCustomPriceValue(source, itemString)
	if not source or type(TSM_API) ~= "table" or type(TSM_API.GetCustomPriceValue) ~= "function" then
		return nil
	end
	local ok, value = pcall(TSM_API.GetCustomPriceValue, tostring(source), itemString)
	value = ok and tonumber(value) or nil
	return value and value >= 0 and value or nil
end

local function GetShoppingInventoryRaw(itemString, sources)
	if type(TSM_API) ~= "table" then
		return 0
	end
	local function Quantity(method)
		if type(TSM_API[method]) ~= "function" then
			return 0
		end
		local ok, value = pcall(TSM_API[method], itemString)
		return ok and tonumber(value) or 0
	end
	local quantity = Quantity("GetMailQuantity") + Quantity("GetBagQuantity")
	if sources.bank then
		quantity = quantity + Quantity("GetBankQuantity") + Quantity("GetWarbankQuantity")
	end
	if sources.guild then
		quantity = quantity + Quantity("GetGuildQuantity")
	end
	if sources.auctions then
		quantity = quantity + Quantity("GetAuctionQuantity")
	end
	if sources.alts or sources.auctions then
		if type(TSM_API.GetPlayerTotals) == "function" then
			local ok, _, altQuantity, _, altAuctionQuantity = pcall(TSM_API.GetPlayerTotals, itemString)
			if ok then
				quantity = quantity + (sources.alts and tonumber(altQuantity) or 0) + (sources.auctions and tonumber(altAuctionQuantity) or 0)
			end
		end
	end
	return quantity
end

local function GetShoppingInventory(itemString, sources)
	local rawQuantity = GetShoppingInventoryRaw(itemString, sources)
	local itemID = GetItemID(itemString)
	local entry = itemID and state.db.inTransit[tostring(itemID)]
	if type(entry) ~= "table" or (tonumber(entry.quantity) or 0) <= 0 then
		if itemID then
			state.db.inTransit[tostring(itemID)] = nil
		end
		return rawQuantity, rawQuantity
	end

	local pendingQuantity = math.max(0, math.floor(tonumber(entry.quantity) or 0))
	local observedQuantity = tonumber(entry.observedInventory) or rawQuantity
	if rawQuantity > observedQuantity then
		pendingQuantity = math.max(0, pendingQuantity - (rawQuantity - observedQuantity))
	end
	entry.observedInventory = rawQuantity
	entry.quantity = pendingQuantity
	entry.itemString = itemString
	if pendingQuantity == 0 then
		state.db.inTransit[tostring(itemID)] = nil
	end
	return rawQuantity + pendingQuantity, rawQuantity
end

GetShoppingSettings = function(itemString)
	local settings, operationName, shoppingOperations = GetShoppingOperation(itemString)
	if not settings then
		return false, nil, nil, nil, nil, nil, "no-operation"
	end
	local maxPrice = GetCustomPriceValue("ShoppingOpMax", itemString)
	local minRestock = GetCustomPriceValue(ResolveOperationSetting(shoppingOperations, operationName, "minRestock", "1"), itemString)
	local restockQuantity = GetCustomPriceValue(ResolveOperationSetting(shoppingOperations, operationName, "restockQuantity", "0"), itemString)
	local sources = ResolveOperationSetting(shoppingOperations, operationName, "restockSources", {})
	local showAboveMaxPrice = ResolveOperationSetting(shoppingOperations, operationName, "showAboveMaxPrice", true)
	if not maxPrice or maxPrice <= 0 or not minRestock or not restockQuantity or minRestock < 0 or minRestock > 50000 or restockQuantity <= 0 or restockQuantity > 50000 or minRestock > restockQuantity then
		return false, nil, nil, nil, nil, sources, "invalid"
	end
	local maxQuantity
	if restockQuantity > 0 then
		local have, rawQuantity = GetShoppingInventory(itemString, type(sources) == "table" and sources or {})
		if have >= restockQuantity then
			return false, nil, nil, nil, rawQuantity, sources, "covered"
		end
		maxQuantity = restockQuantity - have
		if maxQuantity < minRestock then
			return false, nil, nil, nil, rawQuantity, sources, "covered"
		end
		return true, math.floor(maxPrice + 0.5), maxQuantity, showAboveMaxPrice ~= false, rawQuantity, sources, "needed"
	end
	return true, math.floor(maxPrice + 0.5), maxQuantity, showAboveMaxPrice ~= false, nil, sources, "needed"
end

RefreshOperationLimits = function()
	local validItems = {}
	local currentByID = {}
	local seen = {}
	local candidateCount = 0
	local coveredCount = 0
	local invalidCount = 0
	for _, item in ipairs(state.items) do
		item.shoppingValid = false
		currentByID[item.itemID] = item
	end
	for _, itemString in ipairs(state.sourceItems) do
		local itemID = GetItemID(itemString)
		if itemID and not seen[itemID] and IsCommodity(itemID) then
			seen[itemID] = true
			local valid, maxPrice, maxQuantity, showAboveMaxPrice, rawQuantity, sources, reason = GetShoppingSettings(itemString)
			if reason ~= "no-operation" then
				candidateCount = candidateCount + 1
			end
			if reason == "covered" then
				coveredCount = coveredCount + 1
			elseif reason == "invalid" then
				invalidCount = invalidCount + 1
			elseif valid then
				local item = currentByID[itemID]
				if not item then
					local quality, qualityAtlas = GetItemQuality(itemID, itemString)
					item = {
						itemID = itemID,
						itemString = itemString,
						name = GetItemName(itemID),
						icon = GetItemTexture(itemID),
						quality = quality,
						qualityAtlas = qualityAtlas,
						commodity = true,
					}
					RequestItemInfo(item)
				end
				item.shoppingValid = true
				item.maxPrice = maxPrice
				item.maxQuantity = maxQuantity
				item.showAboveMaxPrice = showAboveMaxPrice
				item.rawInventory = rawQuantity
				item.restockSources = sources
				validItems[#validItems + 1] = item
			end
		end
	end
	state.items = validItems
	if #validItems > 0 then
		state.needsState = "ready"
	elseif candidateCount > 0 and coveredCount == candidateCount then
		state.needsState = "covered"
	elseif candidateCount == 0 then
		state.needsState = "empty"
	else
		state.needsState = invalidCount > 0 and "invalid" or "empty"
	end
	table.sort(state.items, function(left, right)
		return left.name < right.name
	end)
	if state.frame and state.frame.itemCount then
		state.frame.itemCount:SetText(format("%d item(s) avec Shopping TSM", #state.items))
	end
end

local function SetIdleNeedsStatus()
	if state.needsState == "covered" then
		SetStatus("Rien à sniper — besoins déjà couverts (stock et courrier en transit inclus).")
	elseif state.needsState == "ready" then
		SetStatus("Prêt à scanner avec les opérations Shopping TSM.")
	elseif state.needsState == "empty" then
		SetStatus("Groupe vide — aucun réactif avec une opération Shopping TSM.")
	else
		SetStatus("Aucune cible valide — vérifie les opérations Shopping TSM.")
	end
end

local function ClearResults()
	wipe(state.results)
	wipe(state.resultMap)
	if state.frame then
		UpdateView()
	end
end

local function PruneResults()
	local changed = false
	for index = #state.results, 1, -1 do
		local result = state.results[index]
		if not result.item or result.item.shoppingValid == false or result.unitPrice > result.item.maxPrice then
			table.remove(state.results, index)
			state.resultMap[result.rowKey] = nil
			changed = true
		else
			changed = changed or result.maxPrice ~= result.item.maxPrice or result.maxQuantity ~= result.item.maxQuantity
			result.maxPrice = result.item.maxPrice
			result.maxQuantity = result.item.maxQuantity
		end
	end
	if state.frame and changed then
		UpdateView()
	end
end

local function ReconcileTransitPurchases()
	local itemStrings = {}
	for _, entry in pairs(state.db.inTransit) do
		if type(entry) == "table" and type(entry.itemString) == "string" then
			itemStrings[#itemStrings + 1] = entry.itemString
		end
	end
	for _, itemString in ipairs(itemStrings) do
		GetShoppingSettings(itemString)
	end
end

local function QueueInventoryRefresh()
	if state.inventoryRefreshPending then
		return
	end
	state.inventoryRefreshPending = true
	C_Timer.After(0.2, function()
		state.inventoryRefreshPending = false
		ReconcileTransitPurchases()
		RefreshOperationLimits()
		PruneResults()
		if state.scanning and #state.items == 0 then
			StopScan()
			SetIdleNeedsStatus()
		elseif not state.scanning and not state.purchase then
			SetIdleNeedsStatus()
		end
		UpdateView()
	end)
end

RebuildItems = function()
	StopScan()
	wipe(state.items)
	wipe(state.sourceItems)
	ClearResults()

	if state.selectedGroup then
		GetItemsFromGroup(state.selectedGroup, state.sourceItems)
	else
		for _, entry in ipairs(state.groupPaths) do
			GetItemsFromGroup(entry.path, state.sourceItems)
		end
	end
	RefreshOperationLimits()
	SetIdleNeedsStatus()
	UpdateView()
end

local function IsDeal(item, unitPrice)
	return item.maxPrice and unitPrice <= item.maxPrice
end

local function FormatPrice(price)
	return GetMoneyString and GetMoneyString(math.floor(price or 0), true) or tostring(price or 0)
end

local function GetScanBudgetCopper()
	local gold = state.db and tonumber(state.db.maxGoldPerScan) or 0
	return gold > 0 and math.floor(gold * 10000 + 0.5) or 0
end

local function IsOverScanBudget(cost)
	local limit = GetScanBudgetCopper()
	return limit > 0 and state.scanStats.goldSpent + math.max(0, tonumber(cost) or 0) > limit, limit
end

local function UpdateScanStats()
	if not state.frame or not state.frame.scanStats then
		return
	end
	local limit = GetScanBudgetCopper()
	state.frame.scanStats:SetText(format(
		"Items achetés : %d  •  Dépensé : %s  •  Budget : %s",
		state.scanStats.items,
		FormatPrice(state.scanStats.goldSpent),
		limit > 0 and FormatPrice(limit) or "∞"
	))
end

local function GetPurchaseCost(result)
	if not result then
		return 0
	end
	local totalPrice = tonumber(result.totalPrice)
	if totalPrice and totalPrice > 0 then
		return math.floor(totalPrice + 0.5)
	end
	local unitPrice = math.max(0, tonumber(result.unitPrice) or 0)
	local quantity = math.max(1, tonumber(result.quantity) or 1)
	return math.floor(unitPrice * quantity + 0.5)
end

local function FormatDealPercent(unitPrice, maxPrice)
	if not unitPrice or not maxPrice or maxPrice <= 0 then
		return "?%"
	end
	return format("%d%%", math.floor(unitPrice / maxPrice * 100 + 0.5))
end

local function AlertResult(result)
	local now = GetTime()
	local last = state.seenAlerts[result.alertKey]
	if last and now - last < ALERT_REPEAT_AFTER then
		return
	end
	state.seenAlerts[result.alertKey] = now
	if state.db.sound and PlaySound then
		local sound = SOUNDKIT and (SOUNDKIT.RAID_WARNING or SOUNDKIT.ALARM_CLOCK_WARNING_2)
		if sound then
			pcall(PlaySound, sound)
		end
	end
	if print then
		print(format("|cff00ff00Yaya Sniper|r %s : %s/u (%s du max TSM, x%d)", result.name, FormatPrice(result.unitPrice), FormatDealPercent(result.unitPrice, result.maxPrice), result.quantity))
	end
end

local function AddResult(result)
	if not IsDeal(result.item, result.unitPrice) then
		return
	end
	result.lastSeenCycle = state.cycle
	result.rowKey = result.kind .. ":" .. result.itemID
	if (state.suppressedResults[result.rowKey] or 0) >= state.cycle then
		return
	end
	result.alertKey = result.alertKey or (result.kind .. ":" .. result.itemID .. ":" .. tostring(result.auctionID or result.unitPrice))
	local previous = state.resultMap[result.rowKey]
	if previous then
		previous.lastSeenCycle = state.cycle
		previous.item = result.item
		previous.name = result.name
		previous.unitPrice = result.unitPrice
		previous.quantity = result.quantity
		previous.available = result.available
		previous.totalPrice = result.totalPrice
		previous.maxQuantity = result.maxQuantity
		previous.maxPrice = result.maxPrice
		previous.alertKey = result.alertKey
		AlertResult(previous)
		return
	end
	state.resultMap[result.rowKey] = result
	state.results[#state.results + 1] = result
	while #state.results > 60 do
		local removed = table.remove(state.results, 1)
		if removed then
			state.resultMap[removed.rowKey] = nil
		end
	end
	AlertResult(result)
end

local function RemoveResult(result, deferUpdate)
	if not result or not result.rowKey then
		return false
	end
	local current = state.resultMap[result.rowKey]
	if not current then
		return false
	end
	state.resultMap[result.rowKey] = nil
	for index = #state.results, 1, -1 do
		if state.results[index] == current then
			table.remove(state.results, index)
			break
		end
	end
	if not deferUpdate then
		UpdateView()
	end
	return true
end

local function ProcessCommodityResults(item)
	local count = C_AuctionHouse.GetNumCommoditySearchResults(item.itemID)
	local found = false
	for index = 1, count do
		local info = C_AuctionHouse.GetCommoditySearchResultInfo(item.itemID, index)
		if info and info.unitPrice and info.quantity and info.quantity > 0 then
			if IsDeal(item, info.unitPrice) then
				local quantity = item.maxQuantity and math.min(item.maxQuantity, info.quantity) or info.quantity
				AddResult({
					item = item,
					itemID = item.itemID,
					name = item.name,
					kind = "commodity",
					unitPrice = info.unitPrice,
					quantity = quantity,
					available = info.quantity,
					maxQuantity = item.maxQuantity,
					maxPrice = item.maxPrice,
					alertKey = "commodity:" .. item.itemID .. ":" .. info.unitPrice,
				})
				found = true
			end
			break
		end
	end
	if not found then
		RemoveResult(state.resultMap["commodity:" .. item.itemID], true)
	end
end

local function ProcessFastBrowseResults(active, addedResults)
	local browseResults = addedResults or (C_AuctionHouse.GetBrowseResults and C_AuctionHouse.GetBrowseResults()) or {}
	local foundItems = {}
	for _, info in ipairs(browseResults) do
		local itemKey = info and info.itemKey
		local item = itemKey and active.itemsByID[itemKey.itemID]
		local available = info and info.totalQuantity
		if item and item.commodity and info.minPrice and info.minPrice > 0 and available and available > 0 and IsDeal(item, info.minPrice) then
			foundItems[item.itemID] = true
			local quantity = item.maxQuantity and math.min(item.maxQuantity, available) or available
			AddResult({
				item = item,
				itemID = item.itemID,
				name = item.name,
				kind = "commodity",
				unitPrice = info.minPrice,
				quantity = quantity,
				available = available,
				maxQuantity = item.maxQuantity,
				maxPrice = item.maxPrice,
				alertKey = "commodity:" .. item.itemID .. ":" .. info.minPrice,
			})
		end
	end
	for _, item in ipairs(active.items) do
		if not foundItems[item.itemID] then
			RemoveResult(state.resultMap["commodity:" .. item.itemID], true)
		end
	end
end

local function FinishFastSearch(active, timedOut, addedResults)
	CancelTimer("timeoutTimer")
	if not state.active or state.active ~= active then
		return
	end
	if not timedOut then
		ProcessFastBrowseResults(active, addedResults)
	end
	state.active = nil
	state.queueIndex = active.nextIndex - 1
	UpdateView()
	if state.purchase and not state.purchase.started then
		BuyDebug("scan en vol terminé : lancement différé de l’achat")
		Schedule("timeoutTimer", 0, StartPendingPurchase)
	elseif state.scanning then
		Schedule("nextTimer", 0, ProcessNext)
	end
end

local function FinishActiveSearch(item, timedOut)
	CancelTimer("timeoutTimer")
	if not state.active or state.active.itemID ~= item.itemID then
		return
	end
	if not timedOut then
		ProcessCommodityResults(item)
	end
	state.active = nil
	state.queueIndex = state.queueIndex + 1
	UpdateView()
	if state.purchase and not state.purchase.started then
		BuyDebug("recherche en vol terminée : lancement différé de l’achat")
		Schedule("timeoutTimer", 0, StartPendingPurchase)
	elseif state.scanning then
		Schedule("nextTimer", BETWEEN_QUERIES, ProcessNext)
	end
end

ProcessNext = function()
	if not state.scanning or state.active then
		return
	end
	if not IsAHVisible() then
		StopScan()
		return
	end
	if InCombatLockdown and InCombatLockdown() then
		SetStatus("Scan en pause pendant le combat.")
		Schedule("nextTimer", 1, ProcessNext)
		return
	end
	if state.queueIndex >= #state.queue then
		RefreshOperationLimits()
		PruneResults()
		state.cycle = state.cycle + 1
		for rowKey, untilCycle in pairs(state.suppressedResults) do
			if untilCycle < state.cycle then
				state.suppressedResults[rowKey] = nil
			end
		end
		wipe(state.queue)
		for _, queuedItem in ipairs(state.items) do
			state.queue[#state.queue + 1] = queuedItem
		end
		state.queueIndex = 0
		if #state.queue == 0 then
			StopScan()
			SetIdleNeedsStatus()
			return
		end
		SetScanStatus()
		Schedule("nextTimer", BETWEEN_CYCLES, ProcessNext)
		return
	end
	if C_AuctionHouse.IsThrottledMessageSystemReady and not C_AuctionHouse.IsThrottledMessageSystemReady() then
		Schedule("nextTimer", 0.2, ProcessNext)
		return
	end
	SetScanStatus()
	if state.fastMode then
		local batchItems = {}
		local itemsByID = {}
		local itemKeys = {}
		local index = state.queueIndex + 1
		while index <= #state.queue and #batchItems < FAST_BATCH_SIZE do
			local batchItem = state.queue[index]
			local itemKey = C_AuctionHouse.MakeItemKey(batchItem.itemID)
			if itemKey then
				batchItems[#batchItems + 1] = batchItem
				itemsByID[batchItem.itemID] = batchItem
				itemKeys[#itemKeys + 1] = itemKey
			end
			index = index + 1
		end
		if #itemKeys == 0 then
			state.queueIndex = index - 1
			Schedule("nextTimer", 0, ProcessNext)
			return
		end
		state.active = { fast = true, items = batchItems, itemsByID = itemsByID, nextIndex = index }
		Schedule("timeoutTimer", QUERY_TIMEOUT, function()
			FinishFastSearch(state.active, true)
		end)
		C_AuctionHouse.SearchForItemKeys(itemKeys, {})
		return
	end

	local item = state.queue[state.queueIndex + 1]
	local itemKey = C_AuctionHouse.MakeItemKey(item.itemID)
	if not itemKey then
		state.queueIndex = state.queueIndex + 1
		Schedule("nextTimer", BETWEEN_QUERIES, ProcessNext)
		return
	end
	state.active = item
	Schedule("timeoutTimer", QUERY_TIMEOUT, function()
		FinishActiveSearch(item, true)
	end)
	C_AuctionHouse.SendSearchQuery(itemKey, PRICE_SORT, not item.commodity)
end

StopScan = function()
	state.scanning = false
	state.fastMode = false
	state.active = nil
	state.resumeAfterPurchase = false
	wipe(state.queue)
	state.queueIndex = 0
	CancelTimer("nextTimer")
	CancelTimer("timeoutTimer")
	if state.frame and state.frame.scanButton then
		state.frame.scanButton:SetText("Start scanning")
	end
	UpdateView()
end

StartScan = function()
	if state.scanning then
		StopScan()
		SetStatus("Scan arrêté.")
		return
	end
	if #state.items == 0 then
		SetIdleNeedsStatus()
		return
	end
	RefreshOperationLimits()
	PruneResults()
	if #state.items == 0 then
		SetIdleNeedsStatus()
		return
	end
	state.scanStats.items = 0
	state.scanStats.goldSpent = 0
	ClearResults()
	wipe(state.suppressedResults)
	wipe(state.queue)
	state.resumeAfterPurchase = false
	for _, item in ipairs(state.items) do
		state.queue[#state.queue + 1] = item
	end
	state.queueIndex = 0
	state.cycle = 1
	state.fastMode = type(C_AuctionHouse.SearchForItemKeys) == "function" and type(C_AuctionHouse.MakeItemKey) == "function"
	state.scanning = true
	if state.frame and state.frame.scanButton then
		state.frame.scanButton:SetText("Arrêter le scan")
	end
	SetScanStatus()
	ProcessNext()
end

local function PauseScanForPurchase()
	if not state.scanning then
		return
	end
	state.resumeAfterPurchase = true
	state.scanning = false
	CancelTimer("nextTimer")
	if not state.active then
		CancelTimer("timeoutTimer")
	end
	if state.frame and state.frame.scanButton then
		state.frame.scanButton:SetText("Reprendre le scan")
	end
	if state.active then
		BuyDebug("pause demandée avec une requête de scan encore en vol")
		SetStatus("Achat en attente de la requête de scan en cours…")
	else
		SetStatus("Scan en pause pour l’achat…")
	end
end

ResumeScanAfterPurchase = function()
	if not state.resumeAfterPurchase then
		return
	end
	state.resumeAfterPurchase = false
	if not IsAHVisible() or #state.items == 0 then
		if state.frame and state.frame.scanButton then
			state.frame.scanButton:SetText("Start scanning")
		end
		if #state.items == 0 then
			SetIdleNeedsStatus()
		end
		return
	end
	state.scanning = true
	if state.frame and state.frame.scanButton then
		state.frame.scanButton:SetText("Arrêter le scan")
	end
	SetScanStatus()
	ProcessNext()
end

local function CancelPurchase(resumeScan)
	CancelTimer("timeoutTimer")
	BuyDebug(
		"fin transaction item=%s confirmation=%s reprise=%s",
		state.purchase and tostring(state.purchase.itemID) or "aucun",
		state.purchase and tostring(state.purchase.confirming) or "false",
		tostring(resumeScan)
	)
	if state.purchase and state.purchase.kind == "commodity" and state.purchase.started and not state.purchase.confirming and C_AuctionHouse.CancelCommoditiesPurchase then
		local cancelOk, cancelResult = pcall(C_AuctionHouse.CancelCommoditiesPurchase)
		BuyDebug("CancelCommoditiesPurchase pcall=%s retour=%s", tostring(cancelOk), tostring(cancelResult))
	end
	state.purchase = nil
	UpdateView()
	if resumeScan then
		ResumeScanAfterPurchase()
	end
end

local function UpdateResultAfterSuccessfulPurchase(purchase)
	local quantity = math.max(0, math.floor(tonumber(purchase and purchase.quantity) or 0))
	local spent = math.max(0, math.floor(tonumber(purchase and purchase.totalPrice) or 0))
	state.scanStats.items = state.scanStats.items + quantity
	state.scanStats.goldSpent = state.scanStats.goldSpent + spent
	BuyDebug("STATS : achats=%d dépensé=%s", state.scanStats.items, FormatPrice(state.scanStats.goldSpent))
	local result = purchase and purchase.result
	if not result then
		return
	end
	local item = result.item
	local itemID = item and item.itemID or purchase.itemID
	if itemID and quantity > 0 then
		local key = tostring(itemID)
		local entry = state.db.inTransit[key]
		if type(entry) ~= "table" then
			entry = {
				quantity = 0,
				observedInventory = item and item.rawInventory or 0,
				itemString = item and item.itemString or "i:" .. itemID,
			}
			state.db.inTransit[key] = entry
		end
		entry.quantity = math.max(0, math.floor(tonumber(entry.quantity) or 0)) + quantity
		entry.itemString = item and item.itemString or entry.itemString
		BuyDebug("TRANSIT : item=%s +%d, total=%d", tostring(itemID), quantity, entry.quantity)
	end
	state.suppressedResults[result.rowKey] = state.cycle + 1
	RemoveResult(result, true)
	RefreshOperationLimits()
	PruneResults()
	state.queueIndex = #state.queue
end

StartPendingPurchase = function()
	local purchase = state.purchase
	if not purchase or purchase.started or purchase.confirming or purchase.refreshing then
		return
	end
	if state.active then
		BuyDebug("ATTENTE : requête de scan encore active")
		SetStatus("Achat en attente de la requête de scan en cours…")
		return
	end

	local throttleReady = true
	if C_AuctionHouse.IsThrottledMessageSystemReady then
		local throttleOk, ready = pcall(C_AuctionHouse.IsThrottledMessageSystemReady)
		throttleReady = not throttleOk or ready == true
		BuyDebug("throttle pcall=%s prêt=%s", tostring(throttleOk), tostring(ready))
	end
	if not throttleReady then
		purchase.readySince = nil
		if GetTime() - purchase.waitingSince >= QUERY_TIMEOUT then
			BuyDebug("ABANDON : throttle indisponible après %.1f s", GetTime() - purchase.waitingSince)
			CancelPurchase(true)
			SetStatus("Achat annulé : hôtel des ventes encore occupé.")
			return
		end
		SetStatus("Achat en attente de l’hôtel des ventes…")
		Schedule("timeoutTimer", 0.05, StartPendingPurchase)
		return
	end
	local readyFor = purchase.readySince and (GetTime() - purchase.readySince) or 0
	if readyFor < PURCHASE_READY_DELAY then
		purchase.readySince = purchase.readySince or GetTime()
		local remaining = PURCHASE_READY_DELAY - readyFor
		BuyDebug("throttle prêt : stabilisation pendant encore %.3f s", remaining)
		SetStatus("Achat prêt — synchronisation avec l’hôtel des ventes…")
		Schedule("timeoutTimer", remaining, StartPendingPurchase)
		return
	end

	if not purchase.refreshed then
		if not C_AuctionHouse.SendSearchQuery or not C_AuctionHouse.MakeItemKey then
			CancelPurchase(true)
			SetStatus("Impossible de vérifier cette enchère.")
			return
		end
		local itemKey = C_AuctionHouse.MakeItemKey(purchase.itemID)
		if not itemKey then
			CancelPurchase(true)
			SetStatus("Impossible de vérifier cette enchère.")
			return
		end
		purchase.refreshing = true
		BuyDebug("recherche ciblée avant achat item=%s", tostring(purchase.itemID))
		local searchOk, searchResult = pcall(C_AuctionHouse.SendSearchQuery, itemKey, { PRICE_SORT }, false)
		BuyDebug("SendSearchQuery achat pcall=%s retour=%s", tostring(searchOk), tostring(searchResult))
		if not searchOk then
			purchase.refreshing = false
			CancelPurchase(true)
			SetStatus("Impossible de vérifier cette enchère.")
			return
		end
		Schedule("timeoutTimer", QUERY_TIMEOUT, function()
			if state.purchase and state.purchase.refreshing then
				local result = state.purchase.result
				BuyDebug("TIMEOUT : aucune réponse à la recherche ciblée, ligne retirée")
				if result then
					state.suppressedResults[result.rowKey] = state.cycle
					RemoveResult(result, true)
				end
				CancelPurchase(true)
				SetStatus("Enchère sans réponse : ligne retirée.")
			end
		end)
		SetStatus("Actualisation de l’enchère avant achat…")
		return
	end

	BuyDebug("ABANDON : tentative de lancement différé interdite par Blizzard")
	CancelPurchase(true)
	SetStatus("L’achat doit être déclenché directement par un clic.")
end

local function FinishPurchaseSearch(itemID)
	local purchase = state.purchase
	if not purchase or not purchase.refreshing or itemID ~= purchase.itemID then
		return false
	end
	CancelTimer("timeoutTimer")
	purchase.refreshing = false
	local result = purchase.result
	local maxPrice = result and tonumber(result.maxPrice) or 0
	local requestedQuantity = math.max(1, math.floor(tonumber(purchase.requestedQuantity or purchase.quantity) or 1))
	local count = C_AuctionHouse.GetNumCommoditySearchResults(itemID)
	local acceptableQuantity = 0
	local estimatedTotal = 0
	local remaining = requestedQuantity
	local minimumPrice
	local lowestPrice
	for index = 1, count do
		local info = C_AuctionHouse.GetCommoditySearchResultInfo(itemID, index)
		if info and info.unitPrice and info.quantity and info.quantity > 0 then
			lowestPrice = lowestPrice or info.unitPrice
			if info.unitPrice <= maxPrice then
				minimumPrice = minimumPrice or info.unitPrice
				acceptableQuantity = acceptableQuantity + info.quantity
				if remaining > 0 then
					local taken = math.min(remaining, info.quantity)
					estimatedTotal = estimatedTotal + taken * info.unitPrice
					remaining = remaining - taken
				end
			end
		end
	end
	if not result or acceptableQuantity <= 0 or not minimumPrice then
		if result then
			state.suppressedResults[result.rowKey] = state.cycle
			RemoveResult(result, true)
		end
		CancelPurchase(true)
		if lowestPrice and lowestPrice > maxPrice then
			SetStatus("Prix remonté au-dessus du max TSM.")
		else
			SetStatus("Enchère indisponible : ligne retirée.")
		end
		return true
	end

	purchase.quantity = math.min(requestedQuantity, acceptableQuantity)
	purchase.totalPrice = estimatedTotal
	purchase.refreshed = true
	purchase.readySince = nil
	purchase.waitingSince = GetTime()
	result.unitPrice = minimumPrice
	result.quantity = purchase.quantity
	result.available = acceptableQuantity
	result.totalPrice = estimatedTotal
	local availableMoney = type(GetMoney) == "function" and tonumber(GetMoney()) or nil
	if estimatedTotal > 0 and availableMoney and estimatedTotal > availableMoney then
		BuyDebug("ABANDON : coût détaillé supérieur à l’or requis=%s disponible=%s", tostring(estimatedTotal), tostring(availableMoney))
		CancelPurchase(true)
		SetStatus("Or insuffisant : " .. FormatPrice(estimatedTotal) .. " requis, " .. FormatPrice(availableMoney) .. " disponible.")
		return true
	end
	local overBudget, budgetLimit = IsOverScanBudget(estimatedTotal)
	if overBudget then
		BuyDebug("ABANDON : budget du scan dépassé coût=%s limite=%s", tostring(estimatedTotal), tostring(budgetLimit))
		if purchase.result then
			purchase.result.budgetRejected = true
			state.suppressedResults[purchase.result.rowKey] = state.cycle + 1
			RemoveResult(purchase.result)
		end
		CancelPurchase(true)
		return true
	end
	BuyDebug("recherche ciblée validée quantité=%d total=%s", purchase.quantity, tostring(estimatedTotal))
	UpdateView()
	Schedule("timeoutTimer", 0, StartPendingPurchase)
	return true
end

local function BuyResult(result)
	BuyDebug(
		"BuyResult item=%s nom=%s achatActif=%s scan=%s",
		result and tostring(result.itemID) or "nil",
		result and tostring(result.name) or "nil",
		tostring(state.purchase ~= nil),
		tostring(state.scanning)
	)
	if not result then
		BuyDebug("ABANDON : aucune donnée associée à la ligne")
		return
	end
	if state.purchase then
		BuyDebug("ABANDON : un achat est déjà actif pour item=%s", tostring(state.purchase.itemID))
		SetStatus("Achat déjà en cours…")
		return
	end
	local purchaseCost = GetPurchaseCost(result)
	local availableMoney = type(GetMoney) == "function" and tonumber(GetMoney()) or nil
	if purchaseCost > 0 and availableMoney and purchaseCost > availableMoney then
		BuyDebug("ABANDON : or insuffisant requis=%s disponible=%s", tostring(purchaseCost), tostring(availableMoney))
		SetStatus("Or insuffisant : " .. FormatPrice(purchaseCost) .. " requis, " .. FormatPrice(availableMoney) .. " disponible.")
		UpdateView()
		return
	end
	local overBudget = IsOverScanBudget(purchaseCost)
	if overBudget then
		BuyDebug("ABANDON : budget du scan dépassé coût=%s limite=%s", tostring(purchaseCost), tostring(GetScanBudgetCopper()))
		UpdateView()
		return
	end
	if result.kind == "item" then
		BuyDebug("branche enchère classique auctionID=%s total=%s", tostring(result.auctionID), tostring(result.totalPrice))
		if result.auctionID and C_AuctionHouse.PlaceBid then
			C_AuctionHouse.PlaceBid(result.auctionID, result.totalPrice)
			SetStatus("Achat envoyé : " .. result.name)
		end
		return
	end
	if not C_AuctionHouse.StartCommoditiesPurchase then
		BuyDebug("ABANDON : API StartCommoditiesPurchase absente")
		SetStatus("Achat indisponible pour cette enchère.")
		return
	end
	local quantity = math.max(1, math.floor(tonumber(result.quantity) or 1))
	PauseScanForPurchase()
	state.purchase = {
		kind = "commodity",
		itemID = result.itemID,
		name = result.name,
		quantity = quantity,
		totalPrice = result.unitPrice * quantity,
		result = result,
		started = true,
		refreshed = false,
		refreshing = false,
		confirming = false,
		attempt = 0,
		requestedQuantity = quantity,
		waitingSince = GetTime(),
		readySince = nil,
	}
	BuyDebug(
		"phase START depuis OnClick item=%s quantité=%s prixUnitaire=%s maxTSM=%s",
		tostring(result.itemID),
		tostring(quantity),
		tostring(result.unitPrice),
		tostring(result.maxPrice)
	)
	C_AuctionHouse.StartCommoditiesPurchase(result.itemID, quantity)
	BuyDebug("StartCommoditiesPurchase envoyé depuis le clic utilisateur")
	Schedule("timeoutTimer", QUERY_TIMEOUT, function()
		if state.purchase and state.purchase.started and not state.purchase.confirming then
			BuyDebug("TIMEOUT : aucun COMMODITY_PRICE_UPDATED reçu")
			CancelPurchase(true)
			SetStatus("Achat sans réponse de l’hôtel des ventes.")
		end
	end)
	UpdateView()
	SetStatus("Vérification automatique du prix : " .. result.name)
end

local function HandleAuctionEvent(_, event, value, unitPrice, totalPrice)
	local active = state.active
	if event == "UI_ERROR_MESSAGE" and state.purchase then
		BuyDebug(
			"UI_ERROR_MESSAGE code=%s texte=%s started=%s confirmation=%s",
			tostring(value),
			tostring(unitPrice),
			tostring(state.purchase.started),
			tostring(state.purchase.confirming)
		)
	end
	if state.purchase and (
		event == "COMMODITY_PRICE_UPDATED"
		or event == "COMMODITY_PRICE_UNAVAILABLE"
		or event == "COMMODITY_PURCHASE_SUCCEEDED"
		or event == "COMMODITY_PURCHASE_FAILED"
	) then
		BuyDebug(
			"événement=%s arg1=%s arg2=%s arg3=%s itemActif=%s",
			event,
			tostring(value),
			tostring(unitPrice),
			tostring(totalPrice),
			tostring(state.purchase.itemID)
		)
	end
	if event == "AUCTION_HOUSE_CLOSED" then
		StopScan()
		CancelPurchase(false)
		return
	elseif event == "AUCTION_HOUSE_THROTTLED_SYSTEM_READY" then
		if state.purchase and not state.purchase.started and not state.purchase.refreshing then
			BuyDebug("événement throttle prêt reçu : achat différé à la prochaine frame")
			Schedule("timeoutTimer", 0, StartPendingPurchase)
		elseif state.scanning and not state.active then
			Schedule("nextTimer", 0, ProcessNext)
		end
		return
	elseif event == "AUCTION_HOUSE_BROWSE_FAILURE" and active and active.fast then
		CancelTimer("timeoutTimer")
		state.active = nil
		if state.purchase and not state.purchase.started then
			BuyDebug("échec du browse en vol : poursuite de l’achat")
			Schedule("timeoutTimer", 0, StartPendingPurchase)
		elseif state.scanning then
			Schedule("nextTimer", 0.2, ProcessNext)
		end
		return
	elseif (event == "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED" or event == "AUCTION_HOUSE_BROWSE_RESULTS_ADDED") and state.active and state.active.fast then
		FinishFastSearch(state.active, false, event == "AUCTION_HOUSE_BROWSE_RESULTS_ADDED" and value or nil)
	end
	if event == "COMMODITY_SEARCH_RESULTS_UPDATED" and state.purchase and state.purchase.refreshing and value == state.purchase.itemID then
		FinishPurchaseSearch(value)
		return
	elseif event == "COMMODITY_SEARCH_RESULTS_UPDATED" and active and active.commodity and value == active.itemID then
		FinishActiveSearch(active, false)
	elseif event == "ITEM_SEARCH_RESULTS_UPDATED" and active and not active.commodity and value and value.itemID == active.itemID then
		FinishActiveSearch(active, false)
	elseif event == "COMMODITY_PRICE_UPDATED" and state.purchase then
		local currentUnitPrice = tonumber(value)
		local currentTotalPrice = tonumber(unitPrice)
		if state.purchase.confirming then
			BuyDebug("événement prix ignoré : confirmation déjà envoyée")
			return
		end
		CancelTimer("timeoutTimer")
		if currentTotalPrice and state.purchase.quantity > 0 then
			currentUnitPrice = math.ceil(currentTotalPrice / state.purchase.quantity)
		end
		BuyDebug(
			"prix recalculé unitaire=%s total=%s maxTSM=%s quantité=%d",
			tostring(currentUnitPrice),
			tostring(currentTotalPrice),
			state.purchase.result and tostring(state.purchase.result.maxPrice) or "nil",
			state.purchase.quantity
		)
		if currentUnitPrice and state.purchase.result and currentUnitPrice > state.purchase.result.maxPrice then
			BuyDebug("ABANDON : prix %s supérieur au max TSM %s", tostring(currentUnitPrice), tostring(state.purchase.result.maxPrice))
			local result = state.purchase.result
			state.suppressedResults[result.rowKey] = state.cycle + 1
			RemoveResult(result)
			CancelPurchase(true)
			SetStatus("Prix remonté au-dessus du max TSM.")
			return
		end
		local availableMoney = type(GetMoney) == "function" and tonumber(GetMoney()) or nil
		local confirmedCost = currentTotalPrice or state.purchase.totalPrice or 0
		if confirmedCost > 0 and availableMoney and confirmedCost > availableMoney then
			BuyDebug("ABANDON : total Blizzard supérieur à l’or requis=%s disponible=%s", tostring(confirmedCost), tostring(availableMoney))
			CancelPurchase(true)
			SetStatus("Or insuffisant : " .. FormatPrice(confirmedCost) .. " requis, " .. FormatPrice(availableMoney) .. " disponible.")
			return
		end
		local overBudget, budgetLimit = IsOverScanBudget(confirmedCost)
		if overBudget then
			BuyDebug("ABANDON : budget du scan dépassé coût=%s limite=%s", tostring(confirmedCost), tostring(budgetLimit))
			if state.purchase.result then
				state.purchase.result.budgetRejected = true
				state.suppressedResults[state.purchase.result.rowKey] = state.cycle + 1
				RemoveResult(state.purchase.result)
			end
			CancelPurchase(true)
			return
		end
		if not currentUnitPrice or not C_AuctionHouse.ConfirmCommoditiesPurchase then
			BuyDebug("ABANDON : prix ou API ConfirmCommoditiesPurchase indisponible")
			if state.purchase.result then
				state.suppressedResults[state.purchase.result.rowKey] = state.cycle
				RemoveResult(state.purchase.result, true)
			end
			CancelPurchase(true)
			SetStatus("Achat automatique impossible : prix indisponible.")
			return
		end
		state.purchase.unitPrice = currentUnitPrice or state.purchase.unitPrice
		state.purchase.totalPrice = currentTotalPrice or state.purchase.totalPrice
		state.purchase.confirming = true
		local confirmOk, confirmResult = pcall(C_AuctionHouse.ConfirmCommoditiesPurchase, state.purchase.itemID, state.purchase.quantity)
		BuyDebug("ConfirmCommoditiesPurchase pcall=%s retour=%s", tostring(confirmOk), tostring(confirmResult))
		if not confirmOk then
			state.purchase.confirming = false
			CancelPurchase(true)
			SetStatus("Impossible de confirmer l’achat.")
			return
		end
		Schedule("timeoutTimer", QUERY_TIMEOUT, function()
			if state.purchase and state.purchase.confirming then
				BuyDebug("TIMEOUT : aucun résultat reçu après confirmation")
				CancelPurchase(true)
				SetStatus("Confirmation d’achat sans réponse de l’hôtel des ventes.")
			end
		end)
		SetStatus("Achat automatique envoyé : " .. state.purchase.name)
	elseif event == "COMMODITY_PRICE_UNAVAILABLE" and state.purchase then
		BuyDebug("ÉCHEC : prix devenu indisponible")
		if state.purchase.result then
			state.suppressedResults[state.purchase.result.rowKey] = state.cycle
			RemoveResult(state.purchase.result, true)
		end
		CancelPurchase(true)
		SetStatus("Prix indisponible : enchère déjà partie ?")
	elseif event == "COMMODITY_PURCHASE_SUCCEEDED" and state.purchase then
		BuyDebug("SUCCÈS : achat confirmé par Blizzard")
		local purchase = state.purchase
		UpdateResultAfterSuccessfulPurchase(purchase)
		SetStatus("Achat confirmé.")
		CancelPurchase(true)
	elseif event == "COMMODITY_PURCHASE_FAILED" and state.purchase then
		BuyDebug("ÉCHEC : achat refusé par Blizzard")
		if state.purchase.result then
			state.suppressedResults[state.purchase.result.rowKey] = state.cycle
			RemoveResult(state.purchase.result, true)
		end
		CancelPurchase(true)
		SetStatus("Achat refusé ou enchère déjà partie.")
	end
end

local function IsResultBlocked(result)
	if not result then
		return true
	end
	local purchaseCost = GetPurchaseCost(result)
	local availableMoney = type(GetMoney) == "function" and tonumber(GetMoney()) or nil
	if purchaseCost > 0 and availableMoney ~= nil and purchaseCost > availableMoney then
		return true
	end
	local overBudget = IsOverScanBudget(purchaseCost)
	return overBudget or result.budgetRejected == true
end

local function RefreshRows()
	if not state.frame then
		return
	end
	table.sort(state.results, function(left, right)
		local leftBlocked = IsResultBlocked(left)
		local rightBlocked = IsResultBlocked(right)
		if leftBlocked ~= rightBlocked then
			return not leftBlocked
		end
		local leftMaxPrice = tonumber(left.maxPrice) or 0
		local rightMaxPrice = tonumber(right.maxPrice) or 0
		local leftPercent = leftMaxPrice > 0 and (tonumber(left.unitPrice) or math.huge) / leftMaxPrice or math.huge
		local rightPercent = rightMaxPrice > 0 and (tonumber(right.unitPrice) or math.huge) / rightMaxPrice or math.huge
		if leftPercent ~= rightPercent then
			return leftPercent < rightPercent
		end
		local leftItemID = tonumber(left.itemID) or math.huge
		local rightItemID = tonumber(right.itemID) or math.huge
		if leftItemID ~= rightItemID then
			return leftItemID < rightItemID
		end
		return tostring(left.rowKey or "") < tostring(right.rowKey or "")
	end)
	for index, row in ipairs(state.resultRows) do
		local result = state.results[index]
		if result then
			if row.data ~= result then
				HideItemTooltip(row.itemCell)
			end
			row.data = result
			row.icon:SetTexture(result.item and result.item.icon or GetItemTexture(result.itemID) or "Interface\\Icons\\INV_Misc_QuestionMark")
			row.name:SetText(result.name)
			if result.item and result.item.qualityAtlas then
				row.quality:SetAtlas(result.item.qualityAtlas)
				row.quality:Show()
			else
				row.quality:Hide()
			end
			row.price:SetText(FormatPrice(result.unitPrice))
			row.deal:SetText(FormatDealPercent(result.unitPrice, result.maxPrice))
			row.limit:SetText(result.maxQuantity and format("x%d", result.maxQuantity) or "∞")
			local purchaseCost = GetPurchaseCost(result)
			local availableMoney = type(GetMoney) == "function" and tonumber(GetMoney()) or nil
			local budgetExceeded, budgetLimit = IsOverScanBudget(purchaseCost)
			if result.budgetRejected and not budgetExceeded then
				result.budgetRejected = nil
			end
			budgetExceeded = budgetExceeded or result.budgetRejected == true
			row.insufficientMoney = purchaseCost > 0 and availableMoney ~= nil and purchaseCost > availableMoney
			row.budgetExceeded = budgetExceeded
			row.purchaseCost = purchaseCost
			row.availableMoney = availableMoney
			row.budgetLimit = budgetLimit
			row.buy:SetEnabled(state.purchase == nil and not row.insufficientMoney and not row.budgetExceeded)
			row.buy:SetText(state.purchase and state.purchase.result == result and "Achat…" or "Acheter")
			row:Show()
		else
			HideItemTooltip(row.itemCell)
			row.data = nil
			row.insufficientMoney = false
			row.budgetExceeded = false
			row.purchaseCost = nil
			row.availableMoney = nil
			row.budgetLimit = nil
			row.buy:SetEnabled(false)
			row:Hide()
		end
	end
	if state.resultsContent then
		state.resultsContent:SetHeight(math.max(1, math.min(#state.results, #state.resultRows) * 32))
	end
end

UpdateView = function()
	if not state.frame then
		return
	end
	state.frame.scanButton:SetEnabled(not state.purchase and (not state.scanning or #state.items > 0))
	UpdateScanStats()
	state.frame.resultCount:SetText(format("Opportunités : %d", #state.results))
	if state.frame.emptyResults then
		if state.needsState == "covered" then
			state.frame.emptyResults:SetText("|TInterface\\RaidFrame\\ReadyCheck-Ready:24|t Rien à sniper — besoins déjà couverts")
			state.frame.emptyResults:SetTextColor(0.35, 1, 0.35, 1)
		elseif state.needsState == "empty" then
			state.frame.emptyResults:SetText("Groupe vide — aucune cible Shopping TSM")
			state.frame.emptyResults:SetTextColor(0.6, 0.6, 0.6, 1)
		elseif state.needsState == "invalid" then
			state.frame.emptyResults:SetText("Aucune cible valide — vérifie les opérations Shopping TSM")
			state.frame.emptyResults:SetTextColor(1, 0.35, 0.2, 1)
		else
			state.frame.emptyResults:SetText("Aucune opportunité pour le moment")
			state.frame.emptyResults:SetTextColor(0.6, 0.6, 0.6, 1)
		end
		state.frame.emptyResults:SetShown(#state.results == 0)
	end
	RefreshRows()
end

local function CreateCheck(parent, label, checked, point, callback)
	local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
	check:SetPoint(unpack(point))
	check:SetSize(24, 24)
	check:SetChecked(checked)
	check.text = check:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	check.text:SetPoint("LEFT", check, "RIGHT", 2, 0)
	check.text:SetText(label)
	check:SetScript("OnClick", callback)
	return check
end

local function CreateFrames()
	if state.frame then
		return
	end
	local frame = CreateFrame("Frame", addonName .. "Frame", AuctionHouseFrame, "BackdropTemplate")
	frame:SetPoint("TOPLEFT", AuctionHouseFrame, "TOPLEFT", 16, -78)
	frame:SetPoint("BOTTOMRIGHT", AuctionHouseFrame, "BOTTOMRIGHT", -16, 16)
	frame:SetBackdrop({
		bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = true,
		tileSize = 16,
		edgeSize = 12,
		insets = { left = 2, right = 2, top = 2, bottom = 2 },
	})
	frame:SetBackdropColor(0.04, 0.04, 0.04, 0.94)
	frame:Hide()

	local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	title:SetPoint("TOPLEFT", 14, -12)
	title:SetText("Yaya Reagent Sniper")

	local help = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	help:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -5)
	help:SetText("Groupes Shopping TSM → scan rapide → alerte → achat")

	local groupPanel = CreateFrame("Frame", nil, frame, "BackdropTemplate")
	groupPanel:SetWidth(250)
	groupPanel:SetPoint("TOPLEFT", help, "BOTTOMLEFT", 0, -8)
	groupPanel:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 10, 10)
	groupPanel:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 8 })
	groupPanel:SetBackdropColor(0.02, 0.02, 0.02, 0.75)
	local groupTitle = groupPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	groupTitle:SetPoint("TOPLEFT", 10, -8)
	groupTitle:SetText("Groupes avec Shopping")
	local groupScroll = CreateFrame("ScrollFrame", nil, groupPanel, "UIPanelScrollFrameTemplate")
	groupScroll:SetPoint("TOPLEFT", groupTitle, "BOTTOMLEFT", -4, -6)
	groupScroll:SetPoint("BOTTOMRIGHT", groupPanel, "BOTTOMRIGHT", -22, 38)
	local groupContent = CreateFrame("Frame", nil, groupScroll)
	groupContent:SetWidth(220)
	groupContent:SetHeight(1)
	groupScroll:SetScrollChild(groupContent)
	state.groupListContent = groupContent
	local refreshGroups = CreateFrame("Button", nil, groupPanel, "UIPanelButtonTemplate")
	refreshGroups:SetSize(90, 22)
	refreshGroups:SetPoint("BOTTOMLEFT", groupPanel, "BOTTOMLEFT", 8, 8)
	refreshGroups:SetText("Actualiser")
	refreshGroups:SetScript("OnClick", function()
		RefreshGroupPaths()
		RebuildItems()
	end)

	local scanPanel = CreateFrame("Frame", nil, frame)
	scanPanel:SetPoint("TOPLEFT", groupPanel, "TOPRIGHT", 10, 0)
	scanPanel:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, 10)

	local scanButton = CreateFrame("Button", nil, scanPanel, "UIPanelButtonTemplate")
	scanButton:SetSize(170, 28)
	scanButton:SetPoint("TOPLEFT", 8, -4)
	scanButton:SetText("Start scanning")
	scanButton:SetScript("OnClick", StartScan)

	local policy = scanPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	policy:SetPoint("LEFT", scanButton, "RIGHT", 16, 0)
	policy:SetText("Prix et quantités TSM • achat automatique")

	local budgetLabel = scanPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	budgetLabel:SetPoint("TOPLEFT", scanButton, "BOTTOMLEFT", 4, -8)
	budgetLabel:SetText("Or max / scan (po)")
	local budgetInput = CreateFrame("EditBox", nil, scanPanel, "InputBoxTemplate")
	budgetInput:SetSize(92, 24)
	budgetInput:SetPoint("LEFT", budgetLabel, "RIGHT", 6, 0)
	budgetInput:SetAutoFocus(false)
	budgetInput:SetNumeric(true)
	budgetInput:SetMaxLetters(10)
	budgetInput:SetJustifyH("RIGHT")
	budgetInput:SetText(tostring(state.db.maxGoldPerScan or 0))
	local function CommitBudget(input)
		local gold = math.max(0, math.floor(tonumber(input:GetText()) or 0))
		state.db.maxGoldPerScan = gold
		input:SetText(tostring(gold))
		UpdateView()
	end
	budgetInput:SetScript("OnEnterPressed", function(input)
		CommitBudget(input)
		input:ClearFocus()
	end)
	budgetInput:SetScript("OnEditFocusLost", CommitBudget)

	local sound = CreateCheck(scanPanel, "Son", state.db.sound, { "TOPLEFT", budgetInput, "BOTTOMLEFT", -4, -2 }, function(check)
		state.db.sound = check:GetChecked()
	end)

	frame.scanStats = scanPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	frame.scanStats:SetPoint("TOPLEFT", sound, "BOTTOMLEFT", 4, -2)
	frame.scanStats:SetPoint("RIGHT", scanPanel, "RIGHT", -4, 0)
	frame.scanStats:SetJustifyH("LEFT")
	frame.scanStats:SetText("")
	frame.itemCount = scanPanel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	frame.itemCount:SetPoint("TOPLEFT", frame.scanStats, "BOTTOMLEFT", 0, -2)
	frame.itemCount:SetText("")
	frame.status = scanPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	frame.status:SetPoint("TOPLEFT", frame.itemCount, "BOTTOMLEFT", 0, -5)
	frame.status:SetPoint("RIGHT", scanPanel, "RIGHT", -4, 0)
	frame.status:SetJustifyH("LEFT")
	frame.status:SetText("")
	frame.resultCount = scanPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	frame.resultCount:SetPoint("TOPLEFT", frame.status, "BOTTOMLEFT", 0, -8)
	frame.resultCount:SetText("")

	local headerName = scanPanel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	headerName:SetPoint("TOPLEFT", frame.resultCount, "BOTTOMLEFT", 4, -6)
	headerName:SetWidth(150)
	headerName:SetText("Réactif")
	local headerPrice = scanPanel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	headerPrice:SetPoint("LEFT", headerName, "RIGHT", 4, 0)
	headerPrice:SetWidth(78)
	headerPrice:SetText("Prix/u")
	local headerDeal = scanPanel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	headerDeal:SetPoint("LEFT", headerPrice, "RIGHT", 4, 0)
	headerDeal:SetWidth(62)
	headerDeal:SetText("% max")
	local headerLimit = scanPanel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	headerLimit:SetPoint("LEFT", headerDeal, "RIGHT", 4, 0)
	headerLimit:SetWidth(54)
	headerLimit:SetText("Qté TSM")

	local resultsScroll = CreateFrame("ScrollFrame", nil, scanPanel, "UIPanelScrollFrameTemplate")
	resultsScroll:SetPoint("TOPLEFT", headerName, "BOTTOMLEFT", -4, -4)
	resultsScroll:SetPoint("BOTTOMRIGHT", scanPanel, "BOTTOMRIGHT", -18, 4)
	local resultsContent = CreateFrame("Frame", nil, resultsScroll)
	resultsContent:SetWidth(455)
	resultsContent:SetHeight(1)
	resultsScroll:SetScrollChild(resultsContent)
	state.resultsContent = resultsContent
	frame.emptyResults = scanPanel:CreateFontString(nil, "OVERLAY", "GameFontDisable")
	frame.emptyResults:SetPoint("TOP", resultsScroll, "TOP", 0, -34)
	frame.emptyResults:SetText("Aucune opportunité pour le moment")

	for index = 1, MAX_ROWS do
		local row = CreateFrame("Frame", nil, resultsContent, "BackdropTemplate")
		row:SetHeight(30)
		row:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background" })
		row:SetBackdropColor(0.06, 0.06, 0.06, index % 2 == 0 and 0.62 or 0.38)
		if index == 1 then
			row:SetPoint("TOPLEFT", resultsContent, "TOPLEFT", 4, -2)
		else
			row:SetPoint("TOPLEFT", state.resultRows[index - 1], "BOTTOMLEFT", 0, -2)
		end
		row:SetPoint("RIGHT", resultsContent, "RIGHT", -4, 0)
		row.hover = row:CreateTexture(nil, "BACKGROUND")
		row.hover:SetAllPoints()
		row.hover:SetColorTexture(1, 0.82, 0.18, 0.10)
		row.hover:Hide()
		row.itemCell = CreateFrame("Frame", nil, row)
		row.itemCell:SetSize(158, 30)
		row.itemCell:SetPoint("LEFT", row, "LEFT", 0, 0)
		row.itemCell:EnableMouse(true)
		row.itemCell:SetScript("OnEnter", ShowItemTooltip)
		row.itemCell:SetScript("OnLeave", HideItemTooltip)
		row.icon = row:CreateTexture(nil, "ARTWORK")
		row.icon:SetSize(22, 22)
		row.icon:SetPoint("LEFT", row, "LEFT", 2, 0)
		row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		row.name:SetPoint("LEFT", row.icon, "RIGHT", 4, 0)
		row.name:SetWidth(102)
		row.name:SetJustifyH("LEFT")
		row.name:SetWordWrap(false)
		row.name:SetMaxLines(1)
		row.quality = row:CreateTexture(nil, "OVERLAY")
		row.quality:SetSize(18, 18)
		row.quality:SetPoint("LEFT", row.name, "RIGHT", 4, 0)
		row.quality:Hide()
		row.price = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		row.price:SetPoint("LEFT", row.quality, "RIGHT", 4, 0)
		row.price:SetWidth(78)
		row.price:SetJustifyH("RIGHT")
		row.price:SetWordWrap(false)
		row.deal = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		row.deal:SetPoint("LEFT", row.price, "RIGHT", 4, 0)
		row.deal:SetWidth(62)
		row.deal:SetJustifyH("RIGHT")
		row.deal:SetWordWrap(false)
		row.limit = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		row.limit:SetPoint("LEFT", row.deal, "RIGHT", 4, 0)
		row.limit:SetWidth(54)
		row.limit:SetJustifyH("RIGHT")
		row.limit:SetWordWrap(false)
		row.buy = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
		row.buy:SetSize(76, 24)
		row.buy:SetPoint("RIGHT", 0, 0)
		row.buy:RegisterForClicks("LeftButtonUp")
		row.buy:HookScript("OnMouseDown", function(button, mouseButton)
			local result = button:GetParent().data
			BuyDebug("OnMouseDown bouton=%s enabled=%s item=%s", tostring(mouseButton), tostring(button:IsEnabled()), result and tostring(result.itemID) or "nil")
		end)
		row.buy:HookScript("OnMouseUp", function(button, mouseButton)
			local result = button:GetParent().data
			BuyDebug("OnMouseUp bouton=%s enabled=%s item=%s", tostring(mouseButton), tostring(button:IsEnabled()), result and tostring(result.itemID) or "nil")
		end)
		row.buy:SetScript("OnClick", function(button, mouseButton, down)
			local result = button:GetParent().data
			BuyDebug("OnClick bouton=%s down=%s item=%s", tostring(mouseButton), tostring(down), result and tostring(result.itemID) or "nil")
			BuyResult(result)
		end)
		row.buy:SetScript("OnEnter", function(button)
			local resultRow = button:GetParent()
			resultRow.hover:Show()
			if resultRow.insufficientMoney and GameTooltip then
				GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
				GameTooltip:ClearLines()
				GameTooltip:AddLine("Or insuffisant", 1, 0.2, 0.2)
				GameTooltip:AddLine("Requis : " .. FormatPrice(resultRow.purchaseCost), 1, 1, 1)
				GameTooltip:AddLine("Disponible : " .. FormatPrice(resultRow.availableMoney), 0.75, 0.75, 0.75)
				GameTooltip:Show()
			elseif resultRow.budgetExceeded and GameTooltip then
				GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
				GameTooltip:ClearLines()
				GameTooltip:AddLine("Budget du scan dépassé", 1, 0.2, 0.2)
				GameTooltip:AddLine("Coût : " .. FormatPrice(resultRow.purchaseCost), 1, 1, 1)
				GameTooltip:AddLine("Budget : " .. FormatPrice(resultRow.budgetLimit), 0.75, 0.75, 0.75)
				GameTooltip:AddLine("Items achetés : " .. state.scanStats.items .. " • Dépensé : " .. FormatPrice(state.scanStats.goldSpent), 0.75, 0.75, 0.75)
				GameTooltip:Show()
			end
		end)
		row.buy:SetScript("OnLeave", function(button)
			button:GetParent().hover:Hide()
			if GameTooltip and GameTooltip:IsOwned(button) then
				GameTooltip:Hide()
			end
		end)
		row:Hide()
		state.resultRows[index] = row
	end

	state.frame = frame
	frame.scanButton = scanButton
	frame.resultCount = frame.resultCount
	RefreshGroupPaths()
	RebuildItems()
end

local function CreateTab()
	if state.tab or not state.frame or not AuctionHouseFrame.Tabs then
		return
	end
	local libAHTab = type(LibStub) == "table" and LibStub("LibAHTab-1-0", true) or nil
	if libAHTab then
		if not libAHTab:DoesIDExist(addonName) then
			libAHTab:CreateTab(addonName, state.frame, "YRS", "Yaya Reagent Sniper")
		end
		state.tab = libAHTab:GetButton(addonName)
		return
	end

	local root = CreateFrame("Frame", nil, AuctionHouseFrame)
	root:SetSize(10, 10)
	root:SetPoint("TOPLEFT", AuctionHouseFrame.Tabs[#AuctionHouseFrame.Tabs], "TOPRIGHT")
	local tab = CreateFrame("Button", addonName .. "Tab", root, "AuctionHouseFrameDisplayModeTabTemplate")
	tab:SetText("YRS")
	PanelTemplates_TabResize(tab, 20, nil, 70)
	tab:SetPoint("TOPLEFT", root, "TOPLEFT", 3, 0)
	tab.tabHeader = "Yaya Reagent Sniper"
	PanelTemplates_DeselectTab(tab)
	tab:SetScript("OnClick", function()
		AuctionHouseFrame:SetDisplayMode({})
		AuctionHouseFrame.displayMode = nil
		state.frame:Show()
		AuctionHouseFrame:SetTitle(tab.tabHeader)
	end)
	hooksecurefunc(AuctionHouseFrame, "SetDisplayMode", function(_, mode)
		if mode and not (type(mode) == "table" and next(mode) == nil) then
			state.frame:Hide()
		end
	end)
	state.tab = tab
end

local function PrintDebug()
	local throttle = "indisponible"
	if C_AuctionHouse.IsThrottledMessageSystemReady then
		throttle = C_AuctionHouse.IsThrottledMessageSystemReady() and "prêt" or "throttle"
	end
	local active = "aucun"
	if state.active then
		if state.active.fast then
			active = format("batch de %d item(s)", state.active.items and #state.active.items or 0)
		else
			active = format("%s (%d)", state.active.name or "item", state.active.itemID or 0)
		end
	end
	print(format(
		"|cff00ff00YRS debug|r scan=%s mode=%s cycle=%d file=%d/%d résultats=%d items=%d throttle=%s actif=%s",
		state.scanning and "oui" or "non",
		state.fastMode and "rapide" or "item",
		state.cycle,
		state.queueIndex,
		#state.queue,
		#state.results,
		#state.items,
		throttle,
		active
	))
	local shown = math.min(#state.results, 10)
	for index = 1, shown do
		local result = state.results[index]
		print(format(
			"  #%d %s id=%d vuCycle=%d prix=%s max=%s",
			index,
			result.name or "item",
			result.itemID or 0,
			result.lastSeenCycle or 0,
			FormatPrice(result.unitPrice),
			FormatPrice(result.maxPrice)
		))
	end
	if #state.results > shown then
		print(format("  … %d résultat(s) supplémentaire(s)", #state.results - shown))
	end
end

local function HandleSlashCommand(message)
	local input = string.lower((message or ""):match("^%s*(.-)%s*$"))
	local command, argument = input:match("^(%S+)%s*(.-)$")
	if command == "debug" then
		if argument == "on" then
			state.db.debug = true
		elseif argument == "off" then
			state.db.debug = false
		else
			state.db.debug = not state.db.debug
		end
		print(format("Yaya Reagent Sniper : debug achat %s", state.db.debug and "ACTIVÉ" or "désactivé"))
		if state.db.debug then
			PrintDebug()
		end
	elseif command == "status" then
		PrintDebug()
	else
		print("Yaya Reagent Sniper : /yrs debug [on|off] • /yrs status")
	end
end

SLASH_YAYAREAGENTSNIPER1 = "/yrs"
SlashCmdList.YAYAREAGENTSNIPER = HandleSlashCommand

EnsureUI = function()
	if not AuctionHouseFrame or not AuctionHouseFrame.Tabs then
		Schedule("nextTimer", 0.5, EnsureUI)
		return
	end
	CreateFrames()
	CreateTab()
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("AUCTION_HOUSE_SHOW")
eventFrame:RegisterEvent("AUCTION_HOUSE_CLOSED")
eventFrame:RegisterEvent("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED")
eventFrame:RegisterEvent("AUCTION_HOUSE_BROWSE_RESULTS_ADDED")
eventFrame:RegisterEvent("AUCTION_HOUSE_BROWSE_FAILURE")
eventFrame:RegisterEvent("AUCTION_HOUSE_THROTTLED_SYSTEM_READY")
eventFrame:RegisterEvent("COMMODITY_SEARCH_RESULTS_UPDATED")
eventFrame:RegisterEvent("ITEM_SEARCH_RESULTS_UPDATED")
eventFrame:RegisterEvent("COMMODITY_PRICE_UPDATED")
eventFrame:RegisterEvent("COMMODITY_PRICE_UNAVAILABLE")
eventFrame:RegisterEvent("COMMODITY_PURCHASE_SUCCEEDED")
eventFrame:RegisterEvent("COMMODITY_PURCHASE_FAILED")
eventFrame:RegisterEvent("UI_ERROR_MESSAGE")
eventFrame:RegisterEvent("PLAYER_MONEY")
eventFrame:RegisterEvent("MAIL_INBOX_UPDATE")
eventFrame:RegisterEvent("MAIL_SHOW")
eventFrame:RegisterEvent("BAG_UPDATE_DELAYED")
eventFrame:SetScript("OnEvent", function(self, event, ...)
	if event == "PLAYER_LOGIN" or event == "AUCTION_HOUSE_SHOW" then
		C_Timer.After(0.2, EnsureUI)
		return
	elseif event == "PLAYER_MONEY" then
		UpdateView()
		return
	elseif event == "MAIL_INBOX_UPDATE" or event == "MAIL_SHOW" or event == "BAG_UPDATE_DELAYED" then
		QueueInventoryRefresh()
		return
	end
	HandleAuctionEvent(self, event, ...)
end)

state.db = GetDB()
