local addonName = ...

local QUERY_TIMEOUT = 5
local BETWEEN_QUERIES = 0.1
local BETWEEN_CYCLES = 0.05
local FAST_BATCH_SIZE = 100
local ALERT_REPEAT_AFTER = 30
local THROTTLE_WAIT_TIMEOUT = 8
local QUERY_QUARANTINE_SECONDS = 8
local PURCHASE_QUARANTINE_SECONDS = 300
local MAX_PURCHASE_PAGES = 40
local ACTION_COOLDOWN = 0.5
local DIAGNOSTIC_LOG_LIMIT = 1200
local PRICE_SORT = {
	{
		sortOrder = Enum.AuctionHouseSortOrder.Price,
		reverseSort = false,
	},
}

local state = {
	db = nil,
	frame = nil,
	tab = nil,
	events = nil,
	eventsActive = false,
	auctionEvents = {
		"AUCTION_HOUSE_BROWSE_RESULTS_UPDATED",
		"AUCTION_HOUSE_BROWSE_RESULTS_ADDED",
		"AUCTION_HOUSE_BROWSE_FAILURE",
		"AUCTION_HOUSE_THROTTLED_SYSTEM_READY",
		"AUCTION_HOUSE_THROTTLED_MESSAGE_DROPPED",
		"AUCTION_HOUSE_SHOW_ERROR",
		"COMMODITY_SEARCH_RESULTS_UPDATED",
		"COMMODITY_SEARCH_RESULTS_ADDED",
		"OWNED_AUCTIONS_UPDATED",
		"AUCTION_CANCELED",
		"AUCTION_HOUSE_AUCTION_CREATED",
		"AUCTION_MULTISELL_START",
		"AUCTION_MULTISELL_UPDATE",
		"AUCTION_MULTISELL_FAILURE",
		"ITEM_SEARCH_RESULTS_UPDATED",
		"COMMODITY_PRICE_UPDATED",
		"COMMODITY_PRICE_UNAVAILABLE",
		"COMMODITY_PURCHASE_SUCCEEDED",
		"COMMODITY_PURCHASE_FAILED",
		"BIDS_UPDATED",
		"CHAT_MSG_SYSTEM",
		"UI_ERROR_MESSAGE",
		"PLAYER_MONEY",
		"MAIL_INBOX_UPDATE",
		"MAIL_SHOW",
		"BAG_UPDATE",
		"BAG_UPDATE_DELAYED",
		"ITEM_DATA_LOAD_RESULT",
	},
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
	abandonedQuery = nil,
	scanning = false,
	fastMode = false,
	cycle = 0,
	scanGeneration = 0,
	operationGeneration = 0,
	scanThrottleWaitSince = nil,
	queryQuarantineUntil = 0,
	queryQuarantineTimer = nil,
	nextTimer = nil,
	timeoutTimer = nil,
	results = {},
	resultMap = {},
	searchedItems = {},
	resultRows = {},
	searchRetries = {},
	pendingPolicyRescan = false,
	resultsContent = nil,
	inventoryRefreshPending = false,
	diagnosticSnapshot = {},
	diagnosticSnapshotTimer = nil,
	diagnosticSnapshotReasons = {},
	itemLoadRequests = {},
	scanStats = { items = 0, goldSpent = 0 },
	seenAlerts = {},
	suppressedResults = {},
	purchase = nil,
	purchaseGeneration = 0,
	purchaseUncertainUntil = 0,
	quoteQuarantineTimer = nil,
	actionCooldownUntil = 0,
	opportunityPauseUntil = 0,
	resumeAfterPurchase = false,
	resumeWaitStartedAt = nil,
	sortResults = true,
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
local BeginPurchaseRefresh
local StartPendingRefresh
local RequestMorePurchaseResults
local FinishPurchaseSearch
local ReleaseAbandonedQuery
local CancelPurchase
local EnterPurchaseQuarantine
local EnterQuoteQuarantine
local RefreshRows

local function GetDB()
	if type(YayaReagentSniperDB) ~= "table" then
		YayaReagentSniperDB = {}
	end
	local db = YayaReagentSniperDB
	db.group = type(db.group) == "string" and db.group or ""
	db.sound = db.sound ~= false
	db.debug = db.debug == true
	db.diagnostics = db.diagnostics ~= false
	db.diagnosticLog = type(db.diagnosticLog) == "table" and db.diagnosticLog or {}
	db.inTransit = type(db.inTransit) == "table" and db.inTransit or {}
	db.maxGoldPerScan = math.max(0, math.floor(tonumber(db.maxGoldPerScan) or 0))
	db.minRestockPercent = math.max(0, math.min(100, math.floor(tonumber(db.minRestockPercent) or 0)))
	if db.buyAboveMaxPrice == nil then
		db.buyAboveMaxPrice = true
	else
		db.buyAboveMaxPrice = db.buyAboveMaxPrice == true
	end
	return db
end

function state:AllowsAboveMax(item)
	return self.db and self.db.buyAboveMaxPrice == true
		and item and item.showAboveMaxPrice == true
end

local function DiagnosticLog(category, message, ...)
	local db = state.db or GetDB()
	if not db.diagnostics then
		return
	end
	local ok, text = pcall(format, tostring(message or ""), ...)
	if not ok then
		text = tostring(message or "") .. " | logger=" .. tostring(text)
	end
	local stamp = date and date("%Y-%m-%d %H:%M:%S") or "unknown-time"
	local line = format("%s [%.3f] %s %s", stamp, GetTime and GetTime() or 0, tostring(category or "INFO"), text)
	local log = db.diagnosticLog
	log[#log + 1] = line
	while #log > DIAGNOSTIC_LOG_LIMIT do
		table.remove(log, 1)
	end
	if db.debug and print then
		print("|cff33ff99YRS DIAG|r " .. line)
	end
end

_G.YayaReagentSniperTrace = DiagnosticLog

local function SetStatus(text)
	if state.frame and state.frame.status then
		state.frame.status:SetText(text or "")
	end
end

local function BuyDebug(message, ...)
	DiagnosticLog("BUY", message, ...)
end

function state:NewOperation(kind)
	self.operationGeneration = self.operationGeneration + 1
	return {
		kind = kind,
		generation = self.operationGeneration,
		scanGeneration = self.scanGeneration,
		phase = "created",
	}
end

function state:IsActiveOperation(operation)
	return operation ~= nil
		and self.active == operation
		and operation.generation == self.operationGeneration
		and operation.scanGeneration == self.scanGeneration
end

function state:ArmQueryQuarantine(reason)
	self.queryQuarantineUntil = math.max(self.queryQuarantineUntil or 0, GetTime() + QUERY_QUARANTINE_SECONDS)
	if self.queryQuarantineTimer and self.queryQuarantineTimer.Cancel then
		self.queryQuarantineTimer:Cancel()
	end
	local delay = math.max(0.1, self.queryQuarantineUntil - GetTime() + 0.02)
	self.queryQuarantineTimer = C_Timer.NewTimer(delay, function()
		self.queryQuarantineTimer = nil
		if GetTime() >= (self.queryQuarantineUntil or 0) then
			UpdateView()
		end
	end)
	DiagnosticLog("AH_QUARANTINE", "requêtes bloquées jusqu’à %.3f raison=%s", self.queryQuarantineUntil, tostring(reason))
end

function state:IsKnownAuctionError(errorCode)
	if errorCode == nil then
		return false
	end
	return (LE_GAME_ERR_AUCTION_DATABASE_ERROR and errorCode == LE_GAME_ERR_AUCTION_DATABASE_ERROR)
		or (LE_GAME_ERR_AUCTION_HIGHER_BID and errorCode == LE_GAME_ERR_AUCTION_HIGHER_BID)
		or (LE_GAME_ERR_ITEM_NOT_FOUND and errorCode == LE_GAME_ERR_ITEM_NOT_FOUND)
		or (LE_GAME_ERR_NOT_ENOUGH_MONEY and errorCode == LE_GAME_ERR_NOT_ENOUGH_MONEY)
		or (LE_GAME_ERR_AUCTION_BID_OWN and errorCode == LE_GAME_ERR_AUCTION_BID_OWN)
		or (LE_GAME_ERR_ITEM_MAX_COUNT and errorCode == LE_GAME_ERR_ITEM_MAX_COUNT)
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

local function ArmActionCooldown(duration)
	duration = math.max(0.1, tonumber(duration) or ACTION_COOLDOWN)
	state.actionCooldownUntil = math.max(state.actionCooldownUntil or 0, GetTime() + duration)
	local unlockDelay = math.max(0.1, state.actionCooldownUntil - GetTime() + 0.02)
	Schedule("actionUnlockTimer", unlockDelay, function()
		if GetTime() >= (state.actionCooldownUntil or 0) then
			if state.frame then
				UpdateView()
			end
		end
	end)
end

local function IsActionCoolingDown()
	return (state.actionCooldownUntil or 0) > GetTime()
end

local function IsAHActionReady()
	return not C_AuctionHouse.IsThrottledMessageSystemReady
		or C_AuctionHouse.IsThrottledMessageSystemReady()
end

local function IsPurchaseActionBlocked()
	return IsActionCoolingDown()
		or (YayaReagentSniperReset and YayaReagentSniperReset.IsTransportBusy
			and YayaReagentSniperReset:IsTransportBusy())
		or state.purchase ~= nil
		or state.active ~= nil
		or state.abandonedQuery ~= nil
		or (state.purchaseUncertainUntil or 0) > GetTime()
		or (state.queryQuarantineUntil or 0) > GetTime()
end

local function ArmPostPurchaseRecovery()
	state.resumeWaitStartedAt = GetTime()
	ArmActionCooldown()
	BuyDebug("AH récupération armée jusqu’au prochain signal throttle prêt")
end

local function IsAHVisible()
	return AuctionHouseFrame and AuctionHouseFrame:IsShown()
		and state.frame and state.frame:IsShown()
end

local function IsAnyOwnTabVisible()
	if not AuctionHouseFrame or not AuctionHouseFrame:IsShown() then
		return false
	end
	if YayaReagentSniperReset and YayaReagentSniperReset.IsPurchaseBusy
		and YayaReagentSniperReset:IsPurchaseBusy()
	then
		return true
	end
	if IsAHVisible() then
		return true
	end
	return YayaReagentSniperReset
		and YayaReagentSniperReset.IsVisible
		and YayaReagentSniperReset:IsVisible()
end

local function UpdateAHEventSubscription(forceInactive)
	local eventFrame = state.events
	if not eventFrame then
		return
	end
	local shouldRegister = not forceInactive and (
		IsAnyOwnTabVisible()
		or state.purchase ~= nil
		or state.abandonedQuery ~= nil
		or state.active ~= nil
		or state.resumeAfterPurchase
	)
	if state.eventsActive == shouldRegister then
		return
	end
	if shouldRegister then
		for _, eventName in ipairs(state.auctionEvents) do
			eventFrame:RegisterEvent(eventName)
		end
	else
		for _, eventName in ipairs(state.auctionEvents) do
			eventFrame:UnregisterEvent(eventName)
		end
	end
	state.eventsActive = shouldRegister
end

local function CaptureBagDiagnostics(reason)
	if not state.db or not state.db.diagnostics or not C_Container or not IsAHVisible() then
		return
	end
	local previous = state.diagnosticSnapshot or {}
	local current = {}
	local slotCount = 0
	local changeCount = 0
	for bag = 0, 4 do
		local numSlots = C_Container.GetContainerNumSlots and C_Container.GetContainerNumSlots(bag) or 0
		for slot = 1, numSlots do
			local key = tostring(bag) .. ":" .. tostring(slot)
			local info = C_Container.GetContainerItemInfo and C_Container.GetContainerItemInfo(bag, slot) or nil
			local itemID = info and info.itemID or (C_Container.GetContainerItemID and C_Container.GetContainerItemID(bag, slot))
			local link = info and info.hyperlink or (C_Container.GetContainerItemLink and C_Container.GetContainerItemLink(bag, slot))
			local entry = itemID and {
				itemID = itemID,
				link = link,
				quality = info and info.quality or nil,
				count = info and info.stackCount or nil,
				locked = info and info.isLocked or false,
			} or nil
			if entry then
				current[key] = entry
				slotCount = slotCount + 1
			end
			local old = previous[key]
			if old and entry and old.itemID == entry.itemID then
				if old.link and not entry.link then
					changeCount = changeCount + 1
					DiagnosticLog("BAG_LINK_LOST", "reason=%s slot=%s item=%s count=%s quality=%s locked=%s", reason, key, tostring(entry.itemID), tostring(entry.count), tostring(entry.quality), tostring(entry.locked))
				elseif not old.link and entry.link then
					changeCount = changeCount + 1
					DiagnosticLog("BAG_LINK_RESTORED", "reason=%s slot=%s item=%s count=%s quality=%s", reason, key, tostring(entry.itemID), tostring(entry.count), tostring(entry.quality))
				elseif old.quality ~= entry.quality then
					changeCount = changeCount + 1
					DiagnosticLog("BAG_QUALITY", "reason=%s slot=%s item=%s old=%s new=%s link=%s", reason, key, tostring(entry.itemID), tostring(old.quality), tostring(entry.quality), tostring(entry.link ~= nil))
				elseif old.count ~= entry.count or old.locked ~= entry.locked then
					changeCount = changeCount + 1
					DiagnosticLog("BAG_STATE", "reason=%s slot=%s item=%s count=%s->%s locked=%s->%s", reason, key, tostring(entry.itemID), tostring(old.count), tostring(entry.count), tostring(old.locked), tostring(entry.locked))
				end
			elseif old or entry then
				changeCount = changeCount + 1
				DiagnosticLog("BAG_SLOT", "reason=%s slot=%s item=%s->%s link=%s->%s", reason, key, tostring(old and old.itemID), tostring(entry and entry.itemID), tostring(old and old.link ~= nil), tostring(entry and entry.link ~= nil))
			end
		end
	end
	state.diagnosticSnapshot = current
	if not next(previous) then
		DiagnosticLog("BAG_BASELINE", "reason=%s occupied=%d", reason, slotCount)
	elseif changeCount > 0 then
		DiagnosticLog("BAG_SUMMARY", "reason=%s changes=%d occupied=%d", reason, changeCount, slotCount)
	end
end

local function QueueBagDiagnostics(reason, delay)
	if not state.db or not state.db.diagnostics or not IsAHVisible() then
		return
	end
	state.diagnosticSnapshotReasons[tostring(reason or "event")] = true
	if state.diagnosticSnapshotTimer then
		return
	end
	state.diagnosticSnapshotTimer = C_Timer.NewTimer(delay or 0, function()
		state.diagnosticSnapshotTimer = nil
		if not IsAHVisible() then
			wipe(state.diagnosticSnapshotReasons)
			return
		end
		local reasons = {}
		for queuedReason in pairs(state.diagnosticSnapshotReasons) do
			reasons[#reasons + 1] = queuedReason
		end
		wipe(state.diagnosticSnapshotReasons)
		table.sort(reasons)
		CaptureBagDiagnostics(table.concat(reasons, "+"))
	end)
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
	state.itemLoadRequests[item.itemID] = (state.itemLoadRequests[item.itemID] or 0) + 1
	DiagnosticLog("ITEM_LOAD_REQUEST", "item=%s requests=%d frameShown=%s scan=%s", tostring(item.itemID), state.itemLoadRequests[item.itemID], tostring(IsAHVisible()), tostring(state.scanning))
	itemObject:ContinueOnItemLoad(function()
		if not IsAHVisible() then
			return
		end
		DiagnosticLog("ITEM_LOAD_CALLBACK", "item=%s cached=%s", tostring(item.itemID), tostring(itemObject:IsItemDataCached()))
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
	local classID = GetItemClassID(itemID)
	return classID == Enum.ItemClass.Tradegoods
		or (Enum.ItemClass.Consumable and classID == Enum.ItemClass.Consumable)
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
			local valid = itemID and GetShoppingOperation(itemString)
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
					GameTooltip:ClearLines()
					GameTooltip:AddLine(self.fullLabel or "", 1, 1, 1, true)
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

local function GetEffectiveOperations(groups, path, typeName, visited)
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
	local assigned = group and group[typeName]
	if assigned and (path == "" or assigned.override) then
		return assigned
	end
	if path == "" then
		return assigned
	end
	return GetEffectiveOperations(groups, GetParentGroupPath(path), typeName, visited)
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

-- Operation TSM effective d'un objet, pour un type donne ("Shopping",
-- "Auctioning", ...). TSM_API n'expose aucune operation : on lit la table
-- SavedVariables vivante, qui reflete les editions faites dans l'UI de TSM.
local function GetOperationForItem(itemString, typeName)
	local operationsRoot, groups = GetTSMSettingsTables()
	local typeOperations = operationsRoot and operationsRoot[typeName]
	if not typeOperations or not groups then
		return nil, nil
	end
	local path
	if TSM_API and type(TSM_API.GetGroupPathByItem) == "function" then
		local ok, groupPath = pcall(TSM_API.GetGroupPathByItem, itemString)
		path = ok and groupPath or nil
	end
	local assigned = GetEffectiveOperations(groups, path or "", typeName)
	if not assigned then
		return nil, nil
	end
	for index = 1, #assigned do
		local operationName = assigned[index]
		local settings = typeOperations[operationName]
		if settings and not IsOperationIgnored(settings) then
			return settings, operationName, typeOperations
		end
	end
	return nil, nil
end

GetShoppingOperation = function(itemString)
	return GetOperationForItem(itemString, "Shopping")
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
		return false, nil, nil, nil, nil, nil, "no-operation", nil
	end
	local maxPrice = GetCustomPriceValue("ShoppingOpMax", itemString)
	local minRestock = GetCustomPriceValue(ResolveOperationSetting(shoppingOperations, operationName, "minRestock", "1"), itemString)
	local restockQuantity = GetCustomPriceValue(ResolveOperationSetting(shoppingOperations, operationName, "restockQuantity", "0"), itemString)
	local sources = ResolveOperationSetting(shoppingOperations, operationName, "restockSources", {})
	local showAboveMaxPrice = ResolveOperationSetting(shoppingOperations, operationName, "showAboveMaxPrice", true)
	if not maxPrice or maxPrice <= 0 or not minRestock or not restockQuantity or minRestock < 0 or minRestock > 50000 or restockQuantity <= 0 or restockQuantity > 50000 or minRestock > restockQuantity then
		return false, nil, nil, nil, nil, sources, "invalid", operationName
	end
	local maxQuantity
	if restockQuantity > 0 then
		local have, rawQuantity = GetShoppingInventory(itemString, type(sources) == "table" and sources or {})
		if have >= restockQuantity then
			return false, nil, nil, nil, rawQuantity, sources, "covered", operationName
		end
		maxQuantity = restockQuantity - have
		if maxQuantity < minRestock then
			return false, nil, nil, nil, rawQuantity, sources, "covered", operationName
		end
		if maxQuantity * 100 < restockQuantity * (state.db.minRestockPercent or 0) then
			return false, nil, nil, nil, rawQuantity, sources, "below-percent", operationName
		end
		return true, math.floor(maxPrice + 0.5), maxQuantity, showAboveMaxPrice ~= false, rawQuantity, sources, "needed", operationName
	end
	return true, math.floor(maxPrice + 0.5), maxQuantity, showAboveMaxPrice ~= false, nil, sources, "needed", operationName
end

RefreshOperationLimits = function()
	local validItems = {}
	local currentByID = {}
	local seen = {}
	local candidateCount = 0
	local coveredCount = 0
	local invalidCount = 0
	local filteredCount = 0
	for _, item in ipairs(state.items) do
		item.shoppingValid = false
		currentByID[item.itemID] = item
	end
	for _, itemString in ipairs(state.sourceItems) do
		local itemID = GetItemID(itemString)
		if itemID and not seen[itemID] then
			seen[itemID] = true
			local valid, maxPrice, maxQuantity, showAboveMaxPrice, rawQuantity, sources, reason, operationName = GetShoppingSettings(itemString)
			if reason ~= "no-operation" then
				candidateCount = candidateCount + 1
			end
			if reason == "covered" then
				coveredCount = coveredCount + 1
			elseif reason == "below-percent" then
				filteredCount = filteredCount + 1
			elseif reason == "invalid" then
				invalidCount = invalidCount + 1
			elseif valid then
				local item = currentByID[itemID]
				if not item then
					item = {
						itemID = itemID,
						itemString = itemString,
						name = GetItemName(itemID),
						icon = GetItemTexture(itemID),
						commodity = IsCommodity(itemID),
					}
				end
				item.shoppingValid = true
				item.maxPrice = maxPrice
				item.maxQuantity = maxQuantity
				item.showAboveMaxPrice = showAboveMaxPrice
				item.rawInventory = rawQuantity
				item.restockSources = sources
				item.operationName = operationName
				validItems[#validItems + 1] = item
			end
		end
	end
	state.items = validItems
	if #validItems > 0 then
		state.needsState = "ready"
	elseif candidateCount > 0 and coveredCount == candidateCount then
		state.needsState = "covered"
	elseif candidateCount > 0 and coveredCount + filteredCount == candidateCount and filteredCount > 0 then
		state.needsState = "filtered"
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
	elseif state.needsState == "filtered" then
		SetStatus("Aucun restock : manque inférieur au seuil configuré.")
	elseif state.needsState == "empty" then
		SetStatus("Groupe vide — aucun réactif avec une opération Shopping TSM.")
	else
		SetStatus("Aucune cible valide — vérifie les opérations Shopping TSM.")
	end
end

local function MarkResultStale(result, reason)
	if not result then
		return
	end
	result.lifecycleState = "stale"
	result.lifecycleReason = reason or "Résultat non confirmé par le dernier scan."
	result.purchaseVerifiedAt = nil
	result.authorization = nil
	result.staleSince = result.staleSince or GetTime()
end

local function MarkResultFresh(result)
	if not result then
		return
	end
	result.lifecycleState = "fresh"
	result.lifecycleReason = nil
	result.staleSince = nil
	result.lastSeenAt = GetTime()
	result.purchaseVerifiedAt = nil
	result.authorization = nil
end

local function ClearResults()
	wipe(state.results)
	wipe(state.resultMap)
	wipe(state.searchedItems)
	if state.frame then
		UpdateView()
	end
end

local function PruneResults()
	local changed = false
	local currentByID = {}
	for _, item in ipairs(state.items) do
		currentByID[item.itemID] = item
	end
	for index = #state.results, 1, -1 do
		local result = state.results[index]
		local item = currentByID[result.itemID]
		if not item or item.shoppingValid == false then
			table.remove(state.results, index)
			state.resultMap[result.rowKey] = nil
			changed = true
		else
			changed = changed or result.item ~= item or result.maxPrice ~= item.maxPrice or result.maxQuantity ~= item.maxQuantity
			result.item = item
			result.maxPrice = item.maxPrice
			result.maxQuantity = item.maxQuantity
			if result.kind == "commodity" then
				result.quantity = math.min(math.max(1, tonumber(result.quantity) or 1), item.maxQuantity or math.huge)
			end
			result.totalPrice = result.kind == "item"
				and result.buyoutAmount
				or (tonumber(result.unitPrice) or 0) * result.quantity
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
	if state.inventoryRefreshPending or not IsAHVisible() then
		return
	end
	state.inventoryRefreshPending = true
	C_Timer.After(0.2, function()
		state.inventoryRefreshPending = false
		if not IsAHVisible() then
			return
		end
		DiagnosticLog("INVENTORY_REFRESH", "begin scan=%s purchase=%s items=%d", tostring(state.scanning), tostring(state.purchase ~= nil), #state.items)
		ReconcileTransitPurchases()
		RefreshOperationLimits()
		PruneResults()
		if state.scanning and #state.items == 0 then
			StopScan()
			SetIdleNeedsStatus()
		elseif not state.scanning and not state.purchase then
			SetIdleNeedsStatus()
		end
		if IsAHVisible() then
			UpdateView()
		end
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
	if #state.items > 0 and IsAHVisible() then
		C_Timer.After(0, StartScan)
	end
end

local function IsDeal(item, unitPrice)
	return item and item.maxPrice and tonumber(unitPrice) and unitPrice > 0
end

local function FormatPrice(price)
	return YayaCore.Money.Format(price)
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
		"Items achetés : %d  •  Dépensé : %s  •  Budget session : %s",
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

function state:ReadCurrentPurchasePolicy(purchase)
	local itemString = purchase and (purchase.itemString or (purchase.result and purchase.result.item and purchase.result.item.itemString))
	if not itemString then
		return false, nil, nil, nil, "Référence TSM absente."
	end
	local valid, maxPrice, maxQuantity, showAboveMaxPrice, _, _, reason, operationName = GetShoppingSettings(itemString)
	if not valid then
		return false, maxPrice, maxQuantity, operationName, reason == "covered" and "Besoin déjà couvert." or "Opération Shopping devenue invalide.", showAboveMaxPrice
	end
	return true, maxPrice, maxQuantity, operationName, nil, showAboveMaxPrice
end

function state:ValidatePurchasePolicy(purchase)
	local valid, maxPrice, maxQuantity, operationName, reason, showAboveMaxPrice = self:ReadCurrentPurchasePolicy(purchase)
	if not valid then
		return false, reason
	end
	if purchase.authorizedOperationName and operationName ~= purchase.authorizedOperationName then
		return false, "L’opération Shopping effective a changé."
	end
	local allowsAboveMax = self.db.buyAboveMaxPrice == true and showAboveMaxPrice == true
	if purchase.authorizedShowAboveMaxPrice ~= nil
		and purchase.authorizedShowAboveMaxPrice ~= allowsAboveMax
	then
		return false, "Le réglage TSM des prix au-dessus du maximum a changé."
	end
	if not maxQuantity or maxQuantity < purchase.authorizedQuantity then
		return false, "Le besoin TSM a diminué depuis l’autorisation."
	end
	if not maxPrice or maxPrice <= 0 then
		return false, "Le prix maximum TSM est devenu invalide."
	end
	purchase.currentPolicyMaxPrice = maxPrice
	purchase.currentPolicyShowAboveMaxPrice = allowsAboveMax
	return true, nil, maxPrice, purchase.currentPolicyShowAboveMaxPrice
end

local function FormatDealPercent(unitPrice, maxPrice)
	if not unitPrice or not maxPrice or maxPrice <= 0 then
		return "?%"
	end
	return format("%d%%", math.floor(unitPrice / maxPrice * 100 + 0.5))
end

local function AlertResult(result)
	if not result or not result.maxPrice or not result.unitPrice or result.unitPrice <= result.maxPrice then
		return
	end
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
	local rowKey = result.kind .. ":" .. result.itemID
	if state.suppressedResults[rowKey] then
		state.searchedItems[rowKey] = true
		return
	end
	if result.unitPrice > result.item.maxPrice then
		DiagnosticLog("ABOVE_MAX", "item=%s prix=%s maxTSM=%s autorisé par showAboveMaxPrice", tostring(result.itemID), tostring(result.unitPrice), tostring(result.item.maxPrice))
	end
	RequestItemInfo(result.item)
	result.lastSeenCycle = state.cycle
	result.scanGeneration = state.scanGeneration
	result.observedAt = GetTime()
	result.rowKey = rowKey
	state.searchedItems[result.rowKey] = true
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
		previous.auctionID = result.auctionID
		previous.buyoutAmount = result.buyoutAmount
		previous.maxQuantity = result.maxQuantity
		previous.maxPrice = result.maxPrice
		previous.alertKey = result.alertKey
		previous.scanGeneration = result.scanGeneration
		previous.observedAt = result.observedAt
		MarkResultFresh(previous)
		previous.purchaseVerifiedAt = result.observedAt
		previous.authorization = nil
		previous.actionReadyAt = nil
		state.sortResults = true
		AlertResult(previous)
		return
	end
	MarkResultFresh(result)
	result.purchaseVerifiedAt = result.observedAt
	result.authorization = nil
	result.actionReadyAt = nil
	state.resultMap[result.rowKey] = result
	state.results[#state.results + 1] = result
	state.sortResults = true
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
	local lowestPrice
	local totalAvailable = 0
	local acceptableAvailable = 0
	local estimatedTotal = 0
	local remaining = math.max(0, tonumber(item.maxQuantity) or 0)
	for index = 1, count do
		local info = C_AuctionHouse.GetCommoditySearchResultInfo(item.itemID, index)
		if info and info.unitPrice and info.quantity and info.quantity > 0 then
			lowestPrice = lowestPrice or info.unitPrice
			totalAvailable = totalAvailable + info.quantity
			if state:AllowsAboveMax(item) or info.unitPrice <= item.maxPrice then
				acceptableAvailable = acceptableAvailable + info.quantity
				local taken = math.min(remaining, info.quantity)
				estimatedTotal = estimatedTotal + taken * info.unitPrice
				remaining = remaining - taken
			end
		end
	end
	if lowestPrice then
		local usable = state:AllowsAboveMax(item) and totalAvailable or acceptableAvailable
		local quantity = math.min(item.maxQuantity or usable, math.max(1, usable))
		if not state:AllowsAboveMax(item) and lowestPrice > item.maxPrice then
			quantity = math.min(item.maxQuantity or totalAvailable, totalAvailable)
			estimatedTotal = lowestPrice * quantity
		end
		AddResult({
			item = item,
			itemID = item.itemID,
			name = item.name,
			kind = "commodity",
			unitPrice = lowestPrice,
			quantity = quantity,
			available = totalAvailable,
			totalPrice = estimatedTotal,
			maxQuantity = item.maxQuantity,
			maxPrice = item.maxPrice,
			alertKey = "commodity:" .. item.itemID .. ":" .. lowestPrice,
		})
	end
end

local function InvalidatePurchaseAndResearch(purchase, status)
	local result = purchase and purchase.result
	if result then
		state.searchedItems[result.rowKey] = nil
		RemoveResult(result, true)
	end
	CancelPurchase(false)
	UpdateView()
	SetStatus(status or "Offre invalidée : nouvelle recherche en cours.")
	C_Timer.After(0, function()
		if IsAHVisible() and not state.purchase and not state.active and not state.scanning then
			StartScan()
		end
	end)
end

function state:ProcessItemResults(active)
	local item = active and active.item
	local itemKey = active and active.itemKey
	if not item or not itemKey then
		return
	end
	local count = C_AuctionHouse.GetNumItemSearchResults and C_AuctionHouse.GetNumItemSearchResults(itemKey) or 0
	local best
	for index = 1, count do
		local info = C_AuctionHouse.GetItemSearchResultInfo and C_AuctionHouse.GetItemSearchResultInfo(itemKey, index)
		local quantity = math.max(1, math.floor(tonumber(info and info.quantity) or 1))
		local buyoutAmount = math.floor(tonumber(info and info.buyoutAmount) or 0)
		local unitPrice = quantity > 0 and buyoutAmount / quantity or 0
		if info and info.auctionID and buyoutAmount > 0 and not info.containsOwnerItem
			and quantity <= (item.maxQuantity or 0)
			and (not best or unitPrice < best.unitPrice or (unitPrice == best.unitPrice and buyoutAmount < best.buyoutAmount))
		then
			best = {
				auctionID = info.auctionID,
				quantity = quantity,
				buyoutAmount = buyoutAmount,
				unitPrice = unitPrice,
			}
		end
	end
	if best then
		AddResult({
			item = item,
			itemID = item.itemID,
			name = item.name,
			kind = "item",
			unitPrice = best.unitPrice,
			quantity = best.quantity,
			available = best.quantity,
			totalPrice = best.buyoutAmount,
			buyoutAmount = best.buyoutAmount,
			auctionID = best.auctionID,
			maxQuantity = item.maxQuantity,
			maxPrice = item.maxPrice,
			alertKey = "item:" .. item.itemID .. ":" .. tostring(best.auctionID),
		})
	end
end

local function ProcessFastBrowseResults(active, addedResults)
	local browseResults = {}
	local currentResults = C_AuctionHouse.GetBrowseResults and C_AuctionHouse.GetBrowseResults() or {}
	for _, info in pairs(currentResults) do
		browseResults[#browseResults + 1] = info
	end
	if addedResults then
		for _, info in pairs(addedResults) do
			browseResults[#browseResults + 1] = info
		end
	end
	for _, info in pairs(browseResults) do
		local itemKey = info and info.itemKey
		local item = itemKey and active.itemsByID[itemKey.itemID]
		local available = info and info.totalQuantity
		if item and item.commodity and info.minPrice and info.minPrice > 0 and available and available > 0 and IsDeal(item, info.minPrice) then
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
end

local function FinishFastSearch(active, timedOut, reason)
	if not state:IsActiveOperation(active) then
		return
	end
	CancelTimer("timeoutTimer")
	if timedOut then
		state.active = nil
		state:ArmQueryQuarantine(reason or "browse-timeout")
		StopScan()
		SetStatus("Scan interrompu : réponse browse ambiguë. Relance après la quarantaine AH.")
		return
	end
	ProcessFastBrowseResults(active, active.addedResults)
	state.active = nil
	state.queueIndex = active.nextIndex - 1
	UpdateView()
	if state.scanning then
		Schedule("nextTimer", 0, ProcessNext)
	end
end

local function FinishActiveSearch(active, timedOut, reason)
	if not state:IsActiveOperation(active) then
		return
	end
	CancelTimer("timeoutTimer")
	if timedOut then
		state.active = nil
		local retryKey = tostring(active.kind) .. ":" .. tostring(active.itemID)
		local retryDropped = reason == "search-dropped" and (state.searchRetries[retryKey] or 0) < 1
		if retryDropped then
			state.searchRetries[retryKey] = (state.searchRetries[retryKey] or 0) + 1
			SetStatus("Message AH perdu : nouvelle tentative sur cet item.")
		else
			state:ArmQueryQuarantine(reason or "search-timeout")
			state.searchRetries[retryKey] = nil
			state.queueIndex = state.queueIndex + 1
			SetStatus("Offre indisponible : poursuite après drainage AH.")
		end
		if state.scanning then
			Schedule("nextTimer", retryDropped and 0.1 or QUERY_QUARANTINE_SECONDS + 0.05, ProcessNext)
		end
		return
	end
	if active.kind == "commodity-search" then
		ProcessCommodityResults(active.item)
	else
		state:ProcessItemResults(active)
	end
	state.searchedItems[(active.item.commodity and "commodity:" or "item:") .. active.itemID] = true
	state.searchRetries[tostring(active.kind) .. ":" .. tostring(active.itemID)] = nil
	state.active = nil
	state.queueIndex = state.queueIndex + 1
	UpdateView()
	if state.scanning then
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
		state.sortResults = true
		PruneResults()
		UpdateView()
		local completedCycle = state.cycle
		StopScan()
		local restartForPolicy = state.pendingPolicyRescan
		state.pendingPolicyRescan = false
		SetStatus(format("Recherche terminée — %d offre(s) en cache.", #state.results))
		DiagnosticLog("SEARCH_ALL_DONE", "cycle=%d résultats=%d", completedCycle, #state.results)
		if restartForPolicy and state:NeedsSearch() then
			C_Timer.After(0, StartScan)
		end
		return
	end
	if (state.queryQuarantineUntil or 0) > GetTime() then
		Schedule("nextTimer", math.max(0.1, state.queryQuarantineUntil - GetTime() + 0.02), ProcessNext)
		return
	end
	if C_AuctionHouse.IsThrottledMessageSystemReady and not C_AuctionHouse.IsThrottledMessageSystemReady() then
		state.scanThrottleWaitSince = state.scanThrottleWaitSince or GetTime()
		if GetTime() - state.scanThrottleWaitSince >= THROTTLE_WAIT_TIMEOUT then
			StopScan()
			SetStatus("Scan arrêté : throttle AH indisponible trop longtemps.")
			return
		end
		local scanGeneration = state.scanGeneration
		Schedule("nextTimer", 0.5, function()
			if state.scanning and state.scanGeneration == scanGeneration then
				ProcessNext()
			end
		end)
		return
	end
	if state.purchase then
		return
	end
	state.scanThrottleWaitSince = nil
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
		local active = state:NewOperation("browse")
		active.fast = true
		active.items = batchItems
		active.itemsByID = itemsByID
		active.itemKeys = itemKeys
		active.addedResults = {}
		active.nextIndex = index
		state.active = active
		DiagnosticLog("AH_QUERY", "kind=batch count=%d cycle=%d", #itemKeys, state.cycle)
		local ok = pcall(C_AuctionHouse.SearchForItemKeys, itemKeys, PRICE_SORT)
		if not ok then
			DiagnosticLog("AH_QUERY_ERROR", "kind=batch count=%d", #itemKeys)
			FinishFastSearch(active, true, "browse-api-error")
		elseif state:IsActiveOperation(active) then
			active.phase = "sent"
			active.sentAt = GetTime()
			Schedule("timeoutTimer", QUERY_TIMEOUT, function()
				FinishFastSearch(active, true, "browse-timeout")
			end)
		end
		return
	end

	local item = state.queue[state.queueIndex + 1]
	local itemKey = C_AuctionHouse.MakeItemKey(item.itemID)
	if not itemKey then
		state.queueIndex = state.queueIndex + 1
		Schedule("nextTimer", BETWEEN_QUERIES, ProcessNext)
		return
	end
	local active = state:NewOperation(item.commodity and "commodity-search" or "item-search")
	active.item = item
	active.itemID = item.itemID
	active.itemKey = itemKey
	state.active = active
	DiagnosticLog("AH_QUERY", "kind=item item=%s cycle=%d", tostring(item.itemID), state.cycle)
	local ok = pcall(C_AuctionHouse.SendSearchQuery, itemKey, PRICE_SORT, not item.commodity)
	if not ok then
		DiagnosticLog("AH_QUERY_ERROR", "kind=item item=%s", tostring(item.itemID))
		FinishActiveSearch(active, true, "search-api-error")
	elseif state:IsActiveOperation(active) then
		active.phase = "sent"
		active.sentAt = GetTime()
		Schedule("timeoutTimer", QUERY_TIMEOUT, function()
			FinishActiveSearch(active, true, "search-timeout")
		end)
	end
end

StopScan = function()
	if state.scanning or state.active then
		DiagnosticLog("SCAN_STOP", "cycle=%d queue=%d/%d active=%s frameShown=%s", state.cycle, state.queueIndex, #state.queue, tostring(state.active ~= nil), tostring(IsAHVisible()))
	end
	if state.active and state.active.phase == "sent" then
		state:ArmQueryQuarantine("scan-stop")
	end
	state.scanGeneration = state.scanGeneration + 1
	state.scanning = false
	state.fastMode = false
	state.active = nil
	state.scanThrottleWaitSince = nil
	state.opportunityPauseUntil = 0
	state.resumeAfterPurchase = false
	wipe(state.queue)
	state.queueIndex = 0
	CancelTimer("nextTimer")
	CancelTimer("timeoutTimer")
	CancelTimer("purchaseDrainTimer")
	CancelTimer("purchaseWakeTimer")
	CancelTimer("purchaseResumeTimer")
	UpdateView()
end

StartScan = function()
	if state.purchase then
		SetStatus("Attends la fin de l’achat avant de relancer le scan.")
		return
	end
	if YayaReagentSniperReset and YayaReagentSniperReset.StopScan then
		YayaReagentSniperReset:StopScan("Scan Reset arrêté par le Sniper.")
	end
	if state.scanning or state.active then
		return
	end
	if IsPurchaseActionBlocked() then
		SetStatus("Hôtel des ventes occupé ou en quarantaine : réessaie après déverrouillage.")
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
	state.sortResults = true
	wipe(state.searchRetries)
	wipe(state.queue)
	state.resumeAfterPurchase = false
	for _, item in ipairs(state.items) do
		local rowKey = (item.commodity and "commodity:" or "item:") .. item.itemID
		if not state.suppressedResults[rowKey] and not state.resultMap[rowKey] and not state.searchedItems[rowKey] then
			state.queue[#state.queue + 1] = item
		end
	end
	if #state.queue == 0 then
		UpdateView()
		return
	end
	state.queueIndex = 0
	state.scanGeneration = state.scanGeneration + 1
	state.cycle = math.max(1, state.cycle + 1)
	state.fastMode = false
	state.scanning = true
	DiagnosticLog("SCAN_START", "items=%d fast=%s", #state.queue, tostring(state.fastMode))
	SetScanStatus()
	UpdateView()
	ProcessNext()
end

local function PauseScanForPurchase()
	local shouldResume = state.scanning or state.active or state.resumeAfterPurchase
	if not shouldResume then
		return
	end
	state.resumeAfterPurchase = true
	state.scanning = false
	local active = state.active
	if active then
		local kind = active.kind == "browse" and "browse" or (active.kind == "commodity-search" and "commodity" or "item")
		local abandoned = {
			kind = kind,
			itemID = active.itemID,
			generation = active.generation,
			scanGeneration = active.scanGeneration,
			phase = active.phase,
		}
		state.abandonedQuery = abandoned
		state.active = nil
		BuyDebug("pause du scan : requête active drainée kind=%s item=%s", kind, tostring(active.itemID))
		Schedule("purchaseDrainTimer", QUERY_TIMEOUT, function()
			if state.abandonedQuery ~= abandoned
				or abandoned.scanGeneration ~= state.scanGeneration
			then
				return
			end
			DiagnosticLog("AH_DRAIN_TIMEOUT", "ancienne requête ignorée kind=%s item=%s", tostring(abandoned.kind), tostring(abandoned.itemID))
			state.abandonedQuery = nil
			state:ArmQueryQuarantine("purchase-drain-timeout")
			if state.purchase and state.purchase.result then
				MarkResultStale(state.purchase.result, "La requête précédente n’a pas pu être drainée.")
			end
			state.resumeAfterPurchase = false
			CancelPurchase(false)
			SetStatus("Achat annulé : requête AH précédente restée ambiguë.")
		end)
	end
	CancelTimer("nextTimer")
	CancelTimer("timeoutTimer")
	if state.frame and state.frame.scanButton then
		state.frame.scanButton:SetText("Reprendre le scan")
	end
	if active then
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
	state.resumeWaitStartedAt = state.resumeWaitStartedAt or GetTime()
	if state.purchase then
		SetStatus("Scan verrouillé jusqu’à la fin de l’opération AH…")
		Schedule("purchaseResumeTimer", 0.5, ResumeScanAfterPurchase)
		return
	end
	if (state.opportunityPauseUntil or 0) > GetTime() then
		local remaining = state.opportunityPauseUntil - GetTime()
		SetStatus(format("Scan verrouillé par l’opportunité encore %.1f s.", remaining))
		Schedule("purchaseResumeTimer", math.max(0.1, remaining + 0.02), ResumeScanAfterPurchase)
		return
	end
	if not IsAHActionReady() then
		SetStatus("Achat confirmé : récupération AH en cours…")
		Schedule("purchaseResumeTimer", 0.5, ResumeScanAfterPurchase)
		return
	end
	state.resumeAfterPurchase = false
	state.resumeWaitStartedAt = nil
	if not IsAHVisible() or #state.items == 0 then
		if state.frame and state.frame.scanButton then
			state.frame.scanButton:SetText("Start scanning")
		end
		if #state.items == 0 then
			SetIdleNeedsStatus()
		end
		return
	end
	if state.queueIndex >= #state.queue then
		if #state.queue > 0 then
			state.cycle = state.cycle + 1
		end
		wipe(state.queue)
		for _, item in ipairs(state.items) do
			state.queue[#state.queue + 1] = item
		end
		state.queueIndex = 0
		state.scanGeneration = state.scanGeneration + 1
		state.fastMode = type(C_AuctionHouse.SearchForItemKeys) == "function"
			and type(C_AuctionHouse.MakeItemKey) == "function"
	end
	state.scanning = true
	if state.frame and state.frame.scanButton then
		state.frame.scanButton:SetText("Arrêter le scan")
	end
	SetScanStatus()
	UpdateView()
	ProcessNext()
end

CancelPurchase = function(resumeScan)
	CancelTimer("timeoutTimer")
	CancelTimer("purchaseDrainTimer")
	CancelTimer("purchaseWakeTimer")
	CancelTimer("purchaseResumeTimer")
	CancelTimer("purchaseQuarantineTimer")
	CancelTimer("quoteQuarantineTimer")
	BuyDebug(
		"fin transaction item=%s confirmation=%s reprise=%s",
		state.purchase and tostring(state.purchase.itemID) or "aucun",
		state.purchase and tostring(state.purchase.confirming) or "false",
		tostring(resumeScan)
	)
	if state.purchase and state.purchase.kind == "commodity" and state.purchase.started and not state.purchase.confirmed
		and not state.purchase.cancelRequested and C_AuctionHouse.CancelCommoditiesPurchase
	then
		local cancelOk, cancelResult = pcall(C_AuctionHouse.CancelCommoditiesPurchase)
		BuyDebug("CancelCommoditiesPurchase pcall=%s retour=%s", tostring(cancelOk), tostring(cancelResult))
	end
	state.abandonedQuery = nil
	state.purchase = nil
	state.purchaseUncertainUntil = 0
	UpdateView()
	UpdateAHEventSubscription()
	if state.pendingPolicyRescan and IsAHVisible() and not state.active and not state.scanning then
		state.pendingPolicyRescan = false
		C_Timer.After(0, StartScan)
	end
	if resumeScan and state.resumeAfterPurchase then
		state.resumeWaitStartedAt = state.resumeWaitStartedAt or GetTime()
		ResumeScanAfterPurchase()
	elseif not state.resumeAfterPurchase then
		state.resumeWaitStartedAt = nil
	end
end

EnterQuoteQuarantine = function(reason)
	local purchase = state.purchase
	if not purchase or purchase.confirmed then
		return
	end
	CancelTimer("timeoutTimer")
	CancelTimer("purchaseWakeTimer")
	if purchase.started and not purchase.cancelRequested and C_AuctionHouse.CancelCommoditiesPurchase then
		pcall(C_AuctionHouse.CancelCommoditiesPurchase)
		purchase.cancelRequested = true
	end
	purchase.mode = "quote-quarantine"
	purchase.phase = "ambiguous-before-confirm"
	purchase.quarantineReason = reason
	MarkResultStale(purchase.result, "Cotation AH tardive possible : transaction temporairement bloquée.")
	local generation = purchase.generation
	Schedule("quoteQuarantineTimer", QUERY_QUARANTINE_SECONDS, function()
		if state.purchase == purchase and purchase.generation == generation and purchase.mode == "quote-quarantine" then
			local resumeScan = state.resumeAfterPurchase
			purchase.terminal = true
			CancelPurchase(resumeScan)
			SetStatus("Ancienne cotation abandonnée : nouveau refresh requis.")
		end
	end)
	UpdateView()
	SetStatus("Cotation incertaine : achats bloqués jusqu’au drainage ou pendant 8 secondes.")
end

EnterPurchaseQuarantine = function(reason)
	local purchase = state.purchase
	if not purchase then
		return
	end
	CancelTimer("timeoutTimer")
	CancelTimer("purchaseWakeTimer")
	CancelTimer("purchaseResumeTimer")
	purchase.mode = "quarantine"
	purchase.phase = "ambiguous-after-confirm"
	purchase.confirming = false
	purchase.confirmed = true
	purchase.quarantineReason = reason
	purchase.quarantineUntil = GetTime() + PURCHASE_QUARANTINE_SECONDS
	state.purchaseUncertainUntil = purchase.quarantineUntil
	state.resumeAfterPurchase = false
	state.resumeWaitStartedAt = nil
	if purchase.result then
		MarkResultStale(purchase.result, "Résultat d’achat incertain : aucune nouvelle transaction avant résolution.")
	end
	BuyDebug("QUARANTAINE item=%s génération=%s jusqu’à=%.3f raison=%s", tostring(purchase.itemID), tostring(purchase.generation), purchase.quarantineUntil, tostring(reason))
	Schedule("purchaseQuarantineTimer", PURCHASE_QUARANTINE_SECONDS, function()
		if state.purchase == purchase and purchase.mode == "quarantine" then
			state.purchase = nil
			state.purchaseUncertainUntil = 0
			ArmActionCooldown()
			UpdateView()
			UpdateAHEventSubscription()
			SetStatus("Quarantaine terminée sans réponse : résultat périmé, nouveau refresh requis.")
		end
	end)
	UpdateView()
	SetStatus("Issue d’achat incertaine : achats bloqués pendant 5 minutes ou jusqu’au signal Blizzard.")
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
	RemoveResult(result, true)
	state.searchedItems[result.rowKey] = nil
	RefreshOperationLimits()
	PruneResults()
end

StartPendingPurchase = function()
	local purchase = state.purchase
	if not purchase or purchase.kind ~= "commodity" or purchase.mode ~= "purchase" or purchase.started or purchase.confirmed then
		return
	end
	if state.abandonedQuery then
		InvalidatePurchaseAndResearch(purchase, "Achat annulé : requête AH encore en vol.")
		return
	end
	local policyValid, policyReason = state:ValidatePurchasePolicy(purchase)
	if not policyValid then
		InvalidatePurchaseAndResearch(purchase, "Achat annulé : " .. tostring(policyReason))
		return
	end
	purchase.quantity = purchase.authorizedQuantity
	purchase.started = true
	purchase.phase = "quote"
	BuyDebug("phase START direct item=%s quantité=%s", tostring(purchase.itemID), tostring(purchase.quantity))
	local startOk, startResult = pcall(C_AuctionHouse.StartCommoditiesPurchase, purchase.itemID, purchase.quantity)
	BuyDebug("StartCommoditiesPurchase pcall=%s retour=%s", tostring(startOk), tostring(startResult))
	if not startOk then
		purchase.started = false
		purchase.phase = "failed-before-quote"
		InvalidatePurchaseAndResearch(purchase, "Impossible de lancer l’achat : nouvelle recherche en cours.")
		return
	end
	purchase.waitingSince = nil
	if state.purchase == purchase and purchase.phase == "quote" then
		UpdateView()
		SetStatus("Vérification automatique du prix : " .. purchase.name)
	end
end

StartPendingRefresh = function()
	local purchase = state.purchase
	if not purchase or purchase.mode ~= "refresh" or purchase.refreshing or purchase.refreshPaging then
		return
	end
	if state.abandonedQuery then
		CancelPurchase(true)
		SetStatus("Actualisation non envoyée : requête AH encore en vol.")
		return
	end
	if not IsAHActionReady() then
		CancelPurchase(true)
		SetStatus("Actualisation non envoyée : attends que le bouton soit de nouveau disponible.")
		return
	end
	local valid, maxPrice, maxQuantity, operationName, reason = state:ReadCurrentPurchasePolicy(purchase)
	if not valid or not maxQuantity or maxQuantity <= 0 then
		MarkResultStale(purchase.result, reason or "L’opération Shopping ne demande plus cet achat.")
		CancelPurchase(true)
		SetStatus("Refresh annulé : besoin TSM modifié.")
		return
	end
	local itemKey = C_AuctionHouse.MakeItemKey(purchase.itemID)
	if not itemKey then
		MarkResultStale(purchase.result, "Référence AH indisponible : refresh requis.")
		CancelPurchase(true)
		SetStatus("Référence AH indisponible : actualisation annulée.")
		return
	end
	purchase.authorizedOperationName = operationName
	purchase.currentPolicyMaxPrice = maxPrice
	purchase.requestedQuantity = math.min(purchase.requestedQuantity, math.floor(maxQuantity))
	purchase.refreshing = true
	purchase.phase = "refresh-query"
	local generation = purchase.generation
	local ok = pcall(C_AuctionHouse.SendSearchQuery, itemKey, PRICE_SORT, false)
	if not ok then
		purchase.refreshing = false
		MarkResultStale(purchase.result, "Le refresh AH n’a pas pu démarrer.")
		CancelPurchase(true)
		SetStatus("Refresh AH impossible : aucun achat lancé.")
		return
	end
	purchase.waitingSince = nil
	if state.purchase == purchase and purchase.generation == generation and purchase.refreshing then
		Schedule("timeoutTimer", QUERY_TIMEOUT, function()
			if state.purchase == purchase and purchase.generation == generation and purchase.refreshing then
				MarkResultStale(purchase.result, "Le refresh AH n’a pas répondu.")
				CancelPurchase(true)
				SetStatus("Refresh AH sans réponse : aucun achat lancé.")
			end
		end)
	end
	if state.purchase == purchase then
		UpdateView()
		SetStatus("Actualisation AH : " .. purchase.name)
	end
end

BeginPurchaseRefresh = function(result)
	if not result or state.purchase then
		return
	end
	if type(C_AuctionHouse.MakeItemKey) ~= "function" or type(C_AuctionHouse.SendSearchQuery) ~= "function" then
		MarkResultStale(result, "L’API de refresh AH est indisponible.")
		UpdateView()
		SetStatus("Refresh AH indisponible : aucun achat lancé.")
		return
	end
	ArmActionCooldown()
	PauseScanForPurchase()
	state.purchaseGeneration = state.purchaseGeneration + 1
	state.purchase = {
		mode = "refresh",
		kind = "commodity",
		itemID = result.itemID,
		itemString = result.item and result.item.itemString,
		name = result.name,
		quantity = math.max(1, math.floor(tonumber(result.quantity) or 1)),
		requestedQuantity = math.max(1, math.floor(tonumber(result.quantity) or 1)),
		result = result,
		started = false,
		refreshed = false,
		refreshing = false,
		confirming = false,
		refreshPaging = false,
		refreshPages = 0,
		phase = "waiting-refresh",
		waitingSince = GetTime(),
		generation = state.purchaseGeneration,
	}
	UpdateView()
	StartPendingRefresh()
end

RequestMorePurchaseResults = function(purchase)
	if state.purchase ~= purchase or purchase.mode ~= "refresh" or purchase.refreshPages >= MAX_PURCHASE_PAGES then
		return false
	end
	if not IsAHActionReady() then
		purchase.waitingSince = purchase.waitingSince or GetTime()
		if GetTime() - purchase.waitingSince >= THROTTLE_WAIT_TIMEOUT then
			MarkResultStale(purchase.result, "Pagination AH bloquée par le throttle.")
			CancelPurchase(true)
			SetStatus("Refresh annulé : pagination AH indisponible.")
			return false
		end
		local generation = purchase.generation
		Schedule("purchaseWakeTimer", 0.5, function()
			if state.purchase == purchase and purchase.generation == generation then
				RequestMorePurchaseResults(purchase)
			end
		end)
		return true
	end
	purchase.refreshPaging = true
	purchase.refreshing = true
	purchase.phase = "refresh-page"
	local generation = purchase.generation
	local ok, hasFullResults = pcall(C_AuctionHouse.RequestMoreCommoditySearchResults, purchase.itemID)
	if not ok then
		purchase.refreshPaging = false
		purchase.refreshing = false
		MarkResultStale(purchase.result, "La pagination AH a échoué.")
		CancelPurchase(true)
		SetStatus("Refresh AH interrompu : pagination impossible.")
		return false
	end
	if state.purchase ~= purchase then
		return true
	end
	purchase.waitingSince = nil
	purchase.refreshPages = purchase.refreshPages + 1
	if hasFullResults then
		purchase.refreshPaging = false
		return FinishPurchaseSearch(purchase.itemID)
	end
	if state.purchase == purchase and purchase.generation == generation then
		Schedule("timeoutTimer", QUERY_TIMEOUT, function()
			if state.purchase == purchase and purchase.generation == generation and purchase.refreshPaging then
				MarkResultStale(purchase.result, "La pagination AH n’a pas répondu.")
				CancelPurchase(true)
				SetStatus("Refresh AH sans réponse pendant la pagination.")
			end
		end)
	end
	SetStatus(format("Lecture de la profondeur AH… page %d/%d", purchase.refreshPages, MAX_PURCHASE_PAGES))
	return true
end

FinishPurchaseSearch = function(itemID)
	local purchase = state.purchase
	if not purchase or not purchase.refreshing or tonumber(itemID) ~= tonumber(purchase.itemID) then
		return false
	end
	CancelTimer("timeoutTimer")
	purchase.refreshPaging = false
	local result = purchase.result
	local valid, maxPrice, maxQuantity, operationName, reason, showAboveMaxPrice = state:ReadCurrentPurchasePolicy(purchase)
	if not valid or not maxQuantity or maxQuantity <= 0 then
		MarkResultStale(result, reason or "L’opération Shopping ne demande plus cet achat.")
		CancelPurchase(true)
		SetStatus("Refresh annulé : besoin TSM modifié.")
		return true
	end
	local requestedQuantity = math.max(1, math.floor(tonumber(purchase.requestedQuantity or purchase.quantity) or 1))
	requestedQuantity = math.min(requestedQuantity, math.floor(maxQuantity))
	local count = C_AuctionHouse.GetNumCommoditySearchResults(itemID)
	local acceptableQuantity = 0
	local estimatedTotal = 0
	local remaining = requestedQuantity
	local minimumPrice
	local maximumAcceptedPrice
	local lowestPrice
	for index = 1, count do
		local info = C_AuctionHouse.GetCommoditySearchResultInfo(itemID, index)
		if info and info.unitPrice and info.quantity and info.quantity > 0 then
			lowestPrice = math.min(lowestPrice or info.unitPrice, info.unitPrice)
			if showAboveMaxPrice or info.unitPrice <= maxPrice then
				minimumPrice = math.min(minimumPrice or info.unitPrice, info.unitPrice)
				acceptableQuantity = acceptableQuantity + info.quantity
				if remaining > 0 then
					local taken = math.min(remaining, info.quantity)
					if taken > 0 then
						maximumAcceptedPrice = math.max(maximumAcceptedPrice or info.unitPrice, info.unitPrice)
					end
					estimatedTotal = estimatedTotal + taken * info.unitPrice
					remaining = remaining - taken
				end
			end
		end
	end
	local hasFullResults = true
	if type(C_AuctionHouse.HasFullCommoditySearchResults) == "function" then
		local fullOk, fullResult = pcall(C_AuctionHouse.HasFullCommoditySearchResults, itemID)
		hasFullResults = not fullOk or fullResult == true
	end
	if remaining > 0 and not hasFullResults and purchase.refreshPages < MAX_PURCHASE_PAGES
		and type(C_AuctionHouse.RequestMoreCommoditySearchResults) == "function"
	then
		return RequestMorePurchaseResults(purchase)
	end
	purchase.refreshing = false
	if not result or remaining > 0 or acceptableQuantity < requestedQuantity or not minimumPrice then
		if result then
			MarkResultStale(result, not showAboveMaxPrice and lowestPrice and lowestPrice > maxPrice
				and "Prix au-dessus du maximum TSM après refresh."
				or "Profondeur insuffisante pour la quantité demandée.")
		end
		CancelPurchase(true)
		if not showAboveMaxPrice and lowestPrice and lowestPrice > maxPrice then
			SetStatus("Prix remonté au-dessus du max TSM.")
		else
			SetStatus("Enchère indisponible : ligne conservée en périmé.")
		end
		return true
	end

	purchase.quantity = requestedQuantity
	purchase.totalPrice = estimatedTotal
	purchase.refreshed = true
	purchase.readySince = nil
	purchase.waitingSince = GetTime()
	result.unitPrice = minimumPrice
	result.quantity = purchase.quantity
	result.available = acceptableQuantity
	result.totalPrice = estimatedTotal
	result.maxPrice = maxPrice
	result.maxQuantity = maxQuantity
	result.operationName = operationName
	result.lifecycleState = "fresh"
	result.lifecycleReason = nil
	result.staleSince = nil
	result.purchaseVerifiedAt = GetTime()
	result.authorization = {
		quantity = requestedQuantity,
		maxUnitPrice = showAboveMaxPrice and maximumAcceptedPrice or maxPrice,
		maxTotal = estimatedTotal,
		operationName = operationName,
		showAboveMaxPrice = showAboveMaxPrice == true,
		observedAt = result.purchaseVerifiedAt,
	}
	result.actionReadyAt = GetTime() + ACTION_COOLDOWN
	result.budgetRejected = nil
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
			MarkResultStale(purchase.result, "Le coût confirmé dépasse le budget du scan.")
		end
		CancelPurchase(true)
		return true
	end
	BuyDebug("refresh ciblé validé quantité=%d total=%s maxTSM=%s aboveMax=%s plafondAutorisé=%s", purchase.quantity, tostring(estimatedTotal), tostring(maxPrice), tostring(showAboveMaxPrice), tostring(result.authorization.maxUnitPrice))
	local resumeScan = state.resumeAfterPurchase
	state.purchase = nil
	ArmActionCooldown()
	UpdateView()
	if resumeScan then
		ResumeScanAfterPurchase()
	end
	SetStatus("Auction actualisée : clique « Acheter » pour confirmer.")
	return true
end

function state:StartPendingItemPurchase(purchase)
	if self.purchase ~= purchase or purchase.kind ~= "item" or purchase.started or purchase.terminal then
		return
	end
	local policyValid, policyReason = self:ValidatePurchasePolicy(purchase)
	if not policyValid then
		InvalidatePurchaseAndResearch(purchase, "Achat annulé : " .. tostring(policyReason))
		return
	end
	local availableMoney = type(GetMoney) == "function" and tonumber(GetMoney()) or nil
	if availableMoney and purchase.totalPrice > availableMoney then
		InvalidatePurchaseAndResearch(purchase, "Or insuffisant : nouvelle recherche en cours.")
		return
	end
	if IsOverScanBudget(purchase.totalPrice) then
		purchase.result.budgetRejected = true
		CancelPurchase(false)
		UpdateView()
		return
	end
	purchase.waitingSince = nil
	purchase.started = true
	purchase.confirming = true
	purchase.confirmed = true
	purchase.phase = "item-bid-sent"
	local bidOK = pcall(C_AuctionHouse.PlaceBid, purchase.auctionID, purchase.buyoutAmount)
	BuyDebug("PlaceBid pcall=%s auctionID=%s total=%s", tostring(bidOK), tostring(purchase.auctionID), tostring(purchase.buyoutAmount))
	if not bidOK then
		purchase.terminal = true
		InvalidatePurchaseAndResearch(purchase, "Impossible d’envoyer l’achat : nouvelle recherche en cours.")
		return
	end
	Schedule("timeoutTimer", QUERY_TIMEOUT, function()
		if state.purchase == purchase and purchase.phase == "item-bid-sent" and not purchase.terminal then
			EnterPurchaseQuarantine("item-bid-timeout")
		end
	end)
	SetStatus("Achat envoyé : " .. purchase.name)
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
	if not result.rowKey or state.resultMap[result.rowKey] ~= result then
		BuyDebug("ABANDON : la ligne ne correspond plus au résultat courant")
		SetStatus("Offre remplacée : relance la recherche.")
		return
	end
	if IsPurchaseActionBlocked() then
		BuyDebug("ABANDON : clic ignoré pendant le verrou AH/cooldown")
		SetStatus("Hôtel des ventes occupé : attente du prochain signal AH…")
		return
	end
	if state.purchase then
		BuyDebug("ABANDON : un achat est déjà actif pour item=%s", tostring(state.purchase.itemID))
		SetStatus("Achat déjà en cours…")
		return
	end
	local valid, maxPrice, maxQuantity, operationName, reason, showAboveMaxPrice = state:ReadCurrentPurchasePolicy({ result = result })
	if not valid or not maxQuantity or maxQuantity <= 0 then
		RemoveResult(result)
		SetStatus(reason or "Besoin TSM déjà couvert.")
		return
	end
	showAboveMaxPrice = showAboveMaxPrice == true and state.db.buyAboveMaxPrice == true
	local quantity = math.max(1, math.floor(tonumber(result.quantity) or 1))
	if result.kind == "commodity" then
		quantity = math.min(quantity, math.floor(maxQuantity), math.max(1, math.floor(tonumber(result.available) or quantity)))
	elseif quantity > maxQuantity then
		BuyDebug("ABANDON : stack=%d supérieur au besoin=%d", quantity, maxQuantity)
		RemoveResult(result)
		SetStatus("Stack supérieur au besoin TSM : offre ignorée.")
		return
	end
	local purchaseCost = result.kind == "item"
		and math.max(0, math.floor(tonumber(result.buyoutAmount) or 0))
		or math.max(0, math.floor((tonumber(result.unitPrice) or 0) * quantity + 0.5))
	local policyProbe = {
		result = result,
		itemString = result.item and result.item.itemString,
		authorizedOperationName = operationName,
		authorizedShowAboveMaxPrice = showAboveMaxPrice == true,
		authorizedQuantity = quantity,
	}
	local policyValid, policyReason = state:ValidatePurchasePolicy(policyProbe)
	if not policyValid or purchaseCost <= 0 or not result.unitPrice or result.unitPrice <= 0 then
		RemoveResult(result)
		SetStatus(policyReason or "Offre d’achat incomplète.")
		return
	end
	if not showAboveMaxPrice and result.unitPrice > maxPrice then
		SetStatus(format("Prix trop haut : %s du max TSM.", FormatDealPercent(result.unitPrice, maxPrice)))
		return
	end
	local availableMoney = type(GetMoney) == "function" and tonumber(GetMoney()) or nil
	if purchaseCost > 0 and availableMoney and purchaseCost > availableMoney then
		BuyDebug("ABANDON : or insuffisant requis=%s disponible=%s", tostring(purchaseCost), tostring(availableMoney))
		SetStatus("Or insuffisant : " .. FormatPrice(purchaseCost) .. " requis, " .. FormatPrice(availableMoney) .. " disponible.")
		UpdateView()
		return
	end
	local overBudget = IsOverScanBudget(purchaseCost)
	if overBudget then
		BuyDebug("ABANDON : budget session dépassé coût=%s limite=%s", tostring(purchaseCost), tostring(GetScanBudgetCopper()))
		UpdateView()
		return
	end
	state.purchaseGeneration = state.purchaseGeneration + 1
	state.purchase = {
		mode = "purchase",
		kind = result.kind,
		generation = state.purchaseGeneration,
		ownerGeneration = state.operationGeneration,
		itemID = result.itemID,
		itemString = result.item and result.item.itemString,
		name = result.name,
		quantity = quantity,
		totalPrice = purchaseCost,
		authorizedQuantity = quantity,
		authorizedMaxUnitPrice = not showAboveMaxPrice and math.floor(tonumber(maxPrice)) or nil,
		authorizedMaxTotal = purchaseCost,
		authorizedOperationName = operationName,
		authorizedShowAboveMaxPrice = showAboveMaxPrice == true,
		authorizedAt = GetTime(),
		currentPolicyMaxPrice = policyProbe.currentPolicyMaxPrice,
		auctionID = result.auctionID,
		buyoutAmount = result.buyoutAmount,
		result = result,
		started = false,
		refreshing = false,
		confirming = false,
		confirmed = false,
		terminal = false,
		phase = "waiting-quote",
		requestedQuantity = quantity,
		waitingSince = GetTime(),
		readySince = nil,
	}
	BuyDebug(
		"phase ATTENTE depuis OnClick item=%s quantité=%s plafondUnitaire=%s plafondTotal=%s",
		tostring(result.itemID),
		tostring(quantity),
		tostring(showAboveMaxPrice and "sans plafond" or maxPrice),
		tostring(purchaseCost)
	)
	UpdateView()
	if result.kind == "commodity" then
		if not C_AuctionHouse.StartCommoditiesPurchase then
			CancelPurchase(false)
			SetStatus("Achat de commodité indisponible.")
			return
		end
		StartPendingPurchase()
		return
	end
	if not result.auctionID or not result.buyoutAmount or type(C_AuctionHouse.PlaceBid) ~= "function" then
		CancelPurchase(false)
		SetStatus("Achat de l’enchère indisponible.")
		return
	end
	state:StartPendingItemPurchase(state.purchase)
end

local function CollectOwnedBrowseResults(active)
	if not state:IsActiveOperation(active) or active.kind ~= "browse" then
		return
	end
	local browseResults = C_AuctionHouse.GetBrowseResults and C_AuctionHouse.GetBrowseResults() or {}
	for _, info in pairs(browseResults) do
		local itemKey = info and info.itemKey
		local itemID = itemKey and tonumber(itemKey.itemID)
		if itemID and active.itemsByID[itemID] then
			active.addedResults[itemID] = info
		end
	end
end

local function HandleAuctionEvent(_, event, value, unitPrice, totalPrice)
	local active = state.active
	if event == "AUCTION_HOUSE_CLOSED" then
		local confirmedPurchase = state.purchase and (
			state.purchase.confirmed
			or state.purchase.confirming
			or state.purchase.mode == "quarantine"
		)
		StopScan()
		if confirmedPurchase then
			EnterPurchaseQuarantine("auction-house-closed-after-confirm")
		else
			CancelPurchase(false)
		end
		state.abandonedQuery = nil
		state.queryQuarantineUntil = 0
		CancelTimer("queryQuarantineTimer")
		if not confirmedPurchase then
			state.purchaseUncertainUntil = 0
		end
		return
	end
	if state.purchase and state.purchase.mode == "quote-quarantine"
		and (event == "COMMODITY_PRICE_UPDATED" or event == "COMMODITY_PRICE_UNAVAILABLE")
	then
		local purchase = state.purchase
		local resumeScan = state.resumeAfterPurchase
		purchase.terminal = true
		CancelPurchase(resumeScan)
		SetStatus("Cotation tardive drainée : nouveau refresh requis.")
		return
	end
	if event == "AUCTION_HOUSE_THROTTLED_MESSAGE_DROPPED" then
		if state.abandonedQuery then
			state.abandonedQuery = nil
			state:ArmQueryQuarantine("abandoned-query-dropped")
			if state.purchase and state.purchase.result then
				MarkResultStale(state.purchase.result, "Message AH précédent abandonné.")
			end
			CancelPurchase(false)
			SetStatus("Transaction annulée : message AH abandonné.")
		elseif active and active.phase == "sent" then
			if active.kind == "browse" then
				FinishFastSearch(active, true, "browse-dropped")
			else
				FinishActiveSearch(active, true, "search-dropped")
			end
		elseif state.purchase and (state.purchase.confirmed or state.purchase.mode == "quarantine") then
			EnterPurchaseQuarantine("confirm-dropped")
		elseif state.purchase and (state.purchase.started or state.purchase.refreshing or state.purchase.refreshPaging) then
			MarkResultStale(state.purchase.result, "Message AH abandonné avant confirmation.")
			CancelPurchase(true)
			SetStatus("Transaction annulée : message AH abandonné.")
		end
		return
	end
	if ReleaseAbandonedQuery(event, value) then
		return
	end
	if event == "AUCTION_HOUSE_THROTTLED_SYSTEM_READY" then
		if state.abandonedQuery then
			return
		end
		if state.resumeAfterPurchase then
			BuyDebug("événement throttle prêt reçu : reprise du scan différée à la prochaine frame")
			Schedule("purchaseResumeTimer", 0, ResumeScanAfterPurchase)
		elseif state.scanning and not state.active then
			Schedule("nextTimer", 0, ProcessNext)
		else
			UpdateView()
		end
		return
	end
	local ownsActiveRequest = active and (active.phase == "sent" or active.phase == "response")
	local ownsPurchaseRequest = state.purchase and (
		state.purchase.started
		or state.purchase.refreshing
		or state.purchase.refreshPaging
		or state.purchase.confirmed
		or state.purchase.mode == "quarantine"
	)
	local isAuctionError = event == "AUCTION_HOUSE_SHOW_ERROR"
		or (event == "UI_ERROR_MESSAGE" and state:IsKnownAuctionError(value))
	if isAuctionError and (ownsActiveRequest or ownsPurchaseRequest) then
		DiagnosticLog("AH_ERROR", "event=%s code=%s text=%s", event, tostring(value), tostring(unitPrice))
		if active and ownsActiveRequest then
			if active.kind == "browse" then
				FinishFastSearch(active, true, "auction-error")
			else
				FinishActiveSearch(active, true, "auction-error")
			end
		elseif state.purchase and state.purchase.kind == "item" then
			local failed = state.purchase
			failed.terminal = true
			InvalidatePurchaseAndResearch(failed, "Achat de l’enchère refusé : nouvelle recherche en cours.")
		elseif state.purchase and (state.purchase.confirmed or state.purchase.mode == "quarantine") then
			EnterPurchaseQuarantine("auction-error-after-confirm")
		elseif state.purchase and state.purchase.mode == "purchase" and state.purchase.started then
			EnterQuoteQuarantine("auction-error-before-quote")
		else
			MarkResultStale(state.purchase and state.purchase.result, "Erreur AH avant confirmation.")
			CancelPurchase(true)
			SetStatus("Transaction annulée par une erreur AH.")
		end
		return
	end
	if event == "AUCTION_HOUSE_BROWSE_FAILURE" and active and active.kind == "browse" then
		FinishFastSearch(active, true, "browse-failure")
		return
	elseif (event == "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED" or event == "AUCTION_HOUSE_BROWSE_RESULTS_ADDED")
		and active and active.kind == "browse"
	then
		CollectOwnedBrowseResults(active)
		if event == "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED" and state:IsActiveOperation(active) then
			active.phase = "response"
			Schedule("timeoutTimer", 0.1, function()
				FinishFastSearch(active, false)
			end)
		end
		return
	end
	if state.purchase and state.purchase.mode == "refresh" and state.purchase.refreshing
		and tonumber(value) == tonumber(state.purchase.itemID)
		and (event == "COMMODITY_SEARCH_RESULTS_UPDATED"
			or (event == "COMMODITY_SEARCH_RESULTS_ADDED" and state.purchase.refreshPaging))
	then
		FinishPurchaseSearch(value)
		return
	elseif event == "COMMODITY_SEARCH_RESULTS_UPDATED"
		and active and active.kind == "commodity-search" and tonumber(value) == tonumber(active.itemID)
	then
		FinishActiveSearch(active, false)
	elseif event == "ITEM_SEARCH_RESULTS_UPDATED" and active and active.kind == "item-search" and value and value.itemID == active.itemID then
		FinishActiveSearch(active, false)
	elseif event == "COMMODITY_PRICE_UPDATED" and state.purchase and state.purchase.mode == "purchase"
		and state.purchase.started and state.purchase.phase == "quote"
	then
		local purchase = state.purchase
		local currentUnitPrice = tonumber(value)
		local currentTotalPrice = tonumber(unitPrice)
		CancelTimer("timeoutTimer")
		BuyDebug(
			"cotation Blizzard unitaire=%s total=%s plafondUnitaire=%s plafondTotal=%s quantité=%d",
			tostring(currentUnitPrice),
			tostring(currentTotalPrice),
			tostring(purchase.authorizedMaxUnitPrice),
			tostring(purchase.authorizedMaxTotal),
			purchase.authorizedQuantity
		)
		if not currentUnitPrice or currentUnitPrice <= 0 or not currentTotalPrice or currentTotalPrice <= 0 then
			InvalidatePurchaseAndResearch(purchase, "Cotation Blizzard incomplète : nouvelle recherche en cours.")
			return
		end
		local policyValid, policyReason, policyMaxPrice, policyAllowsAboveMax = state:ValidatePurchasePolicy(purchase)
		local maxUnitPrice = not policyAllowsAboveMax and tonumber(policyMaxPrice) or nil
		if not policyValid then
			BuyDebug("ABANDON : autorisation dépassée unité=%s/%s total=%s/%s", tostring(currentUnitPrice), tostring(maxUnitPrice), tostring(currentTotalPrice), tostring(purchase.authorizedMaxTotal))
			InvalidatePurchaseAndResearch(purchase, policyReason or "La politique Shopping a changé.")
			return
		end
		if maxUnitPrice and currentUnitPrice > maxUnitPrice then
			local result = purchase.result
			BuyDebug("BLOCAGE PRIX : unité=%s maxTSM=%s, ligne conservée sans rescan", tostring(currentUnitPrice), tostring(maxUnitPrice))
			if result then
				result.unitPrice = currentUnitPrice
				result.totalPrice = currentTotalPrice
				result.quantity = purchase.authorizedQuantity
				result.maxPrice = policyMaxPrice
				result.alertKey = "quote:" .. purchase.itemID .. ":" .. tostring(currentUnitPrice)
				MarkResultFresh(result)
				state.searchedItems[result.rowKey] = true
				state.sortResults = true
			end
			CancelPurchase(false)
			SetStatus("Prix au-dessus du max TSM : ligne conservée et ignorée.")
			return
		end
		local availableMoney = type(GetMoney) == "function" and tonumber(GetMoney()) or nil
		local confirmedCost = currentTotalPrice
		if confirmedCost > 0 and availableMoney and confirmedCost > availableMoney then
			BuyDebug("ABANDON : total Blizzard supérieur à l’or requis=%s disponible=%s", tostring(confirmedCost), tostring(availableMoney))
			CancelPurchase(false)
			SetStatus("Or insuffisant : " .. FormatPrice(confirmedCost) .. " requis, " .. FormatPrice(availableMoney) .. " disponible.")
			return
		end
		local overBudget, budgetLimit = IsOverScanBudget(confirmedCost)
		if overBudget then
			BuyDebug("ABANDON : budget du scan dépassé coût=%s limite=%s", tostring(confirmedCost), tostring(budgetLimit))
			if purchase.result then
				purchase.result.budgetRejected = true
			end
			CancelPurchase(false)
			return
		end
		if not C_AuctionHouse.ConfirmCommoditiesPurchase then
			BuyDebug("ABANDON : prix ou API ConfirmCommoditiesPurchase indisponible")
			CancelPurchase(false)
			SetStatus("Achat automatique impossible : prix indisponible.")
			return
		end
		purchase.unitPrice = currentUnitPrice
		purchase.totalPrice = currentTotalPrice
		if purchase.result then
			purchase.result.unitPrice = currentUnitPrice
			purchase.result.totalPrice = currentTotalPrice
			purchase.result.maxPrice = policyMaxPrice
			purchase.result.alertKey = "quote:" .. purchase.itemID .. ":" .. tostring(currentUnitPrice)
			if currentUnitPrice > policyMaxPrice then
				DiagnosticLog("ABOVE_MAX_QUOTE", "item=%s prix=%s maxTSM=%s achat autorisé", tostring(purchase.itemID), tostring(currentUnitPrice), tostring(policyMaxPrice))
				AlertResult(purchase.result)
			end
		end
		purchase.confirming = true
		purchase.confirmed = true
		purchase.phase = "confirming"
		local generation = purchase.generation
		local confirmOk, confirmResult = pcall(C_AuctionHouse.ConfirmCommoditiesPurchase, purchase.itemID, purchase.authorizedQuantity)
		BuyDebug("ConfirmCommoditiesPurchase pcall=%s retour=%s", tostring(confirmOk), tostring(confirmResult))
		if not confirmOk then
			purchase.confirming = false
			purchase.confirmed = false
			purchase.phase = "confirm-api-failed"
			InvalidatePurchaseAndResearch(purchase, "Impossible de confirmer l’achat : nouvelle recherche en cours.")
			return
		end
		if state.purchase == purchase and purchase.generation == generation and purchase.phase == "confirming" then
			Schedule("timeoutTimer", QUERY_TIMEOUT, function()
				if state.purchase == purchase and purchase.generation == generation and purchase.phase == "confirming" then
					BuyDebug("TIMEOUT : aucun résultat reçu après confirmation")
					EnterPurchaseQuarantine("confirm-timeout")
				end
			end)
			SetStatus("Achat automatique envoyé : " .. purchase.name)
		end
	elseif event == "COMMODITY_PRICE_UNAVAILABLE" and state.purchase and state.purchase.mode == "purchase"
		and state.purchase.started and state.purchase.phase == "quote"
	then
		BuyDebug("ÉCHEC : prix devenu indisponible")
		InvalidatePurchaseAndResearch(state.purchase, "Prix indisponible : nouvelle recherche en cours.")
	elseif event == "COMMODITY_PURCHASE_SUCCEEDED" and state.purchase and state.purchase.kind == "commodity"
		and (state.purchase.mode == "purchase" or state.purchase.mode == "quarantine")
		and state.purchase.confirmed and not state.purchase.terminal
	then
		BuyDebug("SUCCÈS : achat confirmé par Blizzard")
		local purchase = state.purchase
		purchase.terminal = true
		purchase.phase = "succeeded"
		UpdateResultAfterSuccessfulPurchase(purchase)
		state.opportunityPauseUntil = 0
		ArmActionCooldown(0.1)
		CancelPurchase(false)
		SetStatus("Achat confirmé.")
	elseif event == "COMMODITY_PURCHASE_FAILED" and state.purchase and state.purchase.kind == "commodity"
		and (state.purchase.mode == "purchase" or state.purchase.mode == "quarantine")
		and state.purchase.confirmed and not state.purchase.terminal
	then
		BuyDebug("ÉCHEC : achat refusé par Blizzard")
		local purchase = state.purchase
		purchase.terminal = true
		purchase.phase = "failed"
		InvalidatePurchaseAndResearch(purchase, "Achat refusé : nouvelle recherche en cours.")
	elseif (event == "BIDS_UPDATED" or (event == "CHAT_MSG_SYSTEM" and value == ERR_AUCTION_BID_PLACED))
		and state.purchase and state.purchase.kind == "item"
		and (state.purchase.phase == "item-bid-sent" or state.purchase.mode == "quarantine")
		and state.purchase.ownerGeneration == state.operationGeneration
		and not state.purchase.terminal
	then
		local purchase = state.purchase
		purchase.terminal = true
		purchase.phase = "succeeded"
		BuyDebug("SUCCÈS ITEM : événement=%s auctionID=%s", tostring(event), tostring(purchase.auctionID))
		UpdateResultAfterSuccessfulPurchase(purchase)
		ArmActionCooldown(0.1)
		CancelPurchase(false)
		SetStatus("Achat confirmé.")
	end
end

local function IsResultBlocked(result)
	if not result then
		return true
	end
	if result.rowKey and state.suppressedResults[result.rowKey] then
		return true
	end
	if not result.item or result.item.shoppingValid == false then
		return true
	end
	if not state:AllowsAboveMax(result.item) and (tonumber(result.unitPrice) or math.huge) > (tonumber(result.maxPrice) or 0) then
		return true
	end
	if result.kind == "item" and (tonumber(result.quantity) or math.huge) > (tonumber(result.maxQuantity) or 0) then
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

function state:NeedsSearch()
	for _, item in ipairs(self.items) do
		local rowKey = (item.commodity and "commodity:" or "item:") .. item.itemID
		if not self.suppressedResults[rowKey] and not self.resultMap[rowKey] and not self.searchedItems[rowKey] then
			return true
		end
	end
	return false
end

function state:GetNextPurchasableResult()
	RefreshOperationLimits()
	PruneResults()
	self.sortResults = true
	RefreshRows()
	for _, result in ipairs(self.results) do
		if not IsResultBlocked(result) then
			return result
		end
	end
end

function state:OnAuctionActionClick()
	if self.purchase or self.active or self.scanning or self.abandonedQuery then
		return
	end
	local result = self:GetNextPurchasableResult()
	if result then
		BuyResult(result)
	elseif self:NeedsSearch() then
		StartScan()
	else
		SetStatus("Rien de disponible à acheter.")
		UpdateView()
	end
end

function state:SkipNextResult()
	if self.purchase or self.active or self.scanning or self.abandonedQuery then
		return
	end
	local result = self:GetNextPurchasableResult()
	if not result then
		return
	end
	self.suppressedResults[result.rowKey] = true
	self.searchedItems[result.rowKey] = true
	RemoveResult(result, true)
	DiagnosticLog("SKIP", "item=%s row=%s session=true", tostring(result.itemID), tostring(result.rowKey))
	SetStatus((result.name or "Item") .. " ignoré jusqu’au prochain /reload.")
	UpdateView()
end

RefreshRows = function()
	if not state.frame then
		return
	end
	if state.sortResults then
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
		state.sortResults = false
	end
	if state.createResultRow then
		while #state.resultRows < #state.results do
			state.createResultRow()
		end
	end
	local nextResult
	for _, candidate in ipairs(state.results) do
		if not IsResultBlocked(candidate) then
			nextResult = candidate
			break
		end
	end
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
			local aboveMax = result.maxPrice and result.unitPrice > result.maxPrice
			row.deal:SetText(FormatDealPercent(result.unitPrice, result.maxPrice))
			row.deal:SetTextColor(aboveMax and 1 or 0.85, aboveMax and 0.25 or 0.85, aboveMax and 0.15 or 0.85, 1)
			local purchaseCost = GetPurchaseCost(result)
			row.limit:SetText(format("x%d  %s", tonumber(result.quantity) or 0, FormatPrice(purchaseCost)))
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
			row.hover:SetShown(result == nextResult)
			row:Show()
		else
			HideItemTooltip(row.itemCell)
			row.data = nil
			row.insufficientMoney = false
			row.budgetExceeded = false
			row.purchaseCost = nil
			row.availableMoney = nil
			row.budgetLimit = nil
			row:Hide()
		end
	end
	if state.resultsContent then
		state.resultsContent:SetHeight(math.max(1, #state.results * 32))
	end
end

UpdateView = function()
	if not state.frame then
		return
	end
	if not state.scanning and not state.resumeAfterPurchase then
		state.sortResults = true
	end
	local busySearch = state.scanning or state.active ~= nil or state.abandonedQuery ~= nil
	local nextResult
	for _, result in ipairs(state.results) do
		if not IsResultBlocked(result) then
			nextResult = result
			break
		end
	end
	if state.purchase then
		state.frame.scanButton:SetText("Achat…")
		state.frame.scanButton:SetEnabled(false)
		state.frame.skipButton:SetEnabled(false)
	elseif busySearch then
		state.frame.scanButton:SetText("Recherche…")
		state.frame.scanButton:SetEnabled(false)
		state.frame.skipButton:SetEnabled(false)
	elseif nextResult then
		state.frame.scanButton:SetText("Acheter suivant")
		state.frame.scanButton:SetEnabled(not IsPurchaseActionBlocked())
		state.frame.skipButton:SetEnabled(not IsPurchaseActionBlocked())
	elseif #state.items > 0 and state:NeedsSearch() then
		state.frame.scanButton:SetText("Rechercher tout")
		state.frame.scanButton:SetEnabled(not IsPurchaseActionBlocked())
		state.frame.skipButton:SetEnabled(false)
	else
		state.frame.scanButton:SetText("Rien à acheter")
		state.frame.scanButton:SetEnabled(false)
		state.frame.skipButton:SetEnabled(false)
	end
	UpdateScanStats()
	state.frame.resultCount:SetText(format("Opportunités : %d", #state.results))
	if state.frame.emptyResults then
		if state.needsState == "covered" then
			state.frame.emptyResults:SetText("|TInterface\\RaidFrame\\ReadyCheck-Ready:24|t Rien à sniper — besoins déjà couverts")
			state.frame.emptyResults:SetTextColor(0.35, 1, 0.35, 1)
		elseif state.needsState == "empty" then
			state.frame.emptyResults:SetText("Groupe vide — aucune cible Shopping TSM")
			state.frame.emptyResults:SetTextColor(0.6, 0.6, 0.6, 1)
		elseif state.needsState == "filtered" then
			state.frame.emptyResults:SetText("Aucun restock — manque inférieur au seuil")
			state.frame.emptyResults:SetTextColor(0.75, 0.75, 0.35, 1)
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
	help:SetText("Recherche automatique des opérations Shopping TSM → Acheter suivant")

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
	groupScroll:SetPoint("BOTTOMRIGHT", groupPanel, "BOTTOMRIGHT", -22, 8)
	local groupContent = CreateFrame("Frame", nil, groupScroll)
	groupContent:SetWidth(220)
	groupContent:SetHeight(1)
	groupScroll:SetScrollChild(groupContent)
	state.groupListContent = groupContent
	local scanPanel = CreateFrame("Frame", nil, frame)
	scanPanel:SetPoint("TOPLEFT", groupPanel, "TOPRIGHT", 10, 0)
	scanPanel:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, 10)

	local scanButton = CreateFrame("Button", nil, scanPanel, "UIPanelButtonTemplate")
	scanButton:SetSize(170, 28)
	scanButton:SetPoint("TOPLEFT", 8, -4)
	scanButton:SetText("Rechercher tout")
	scanButton:RegisterForClicks("LeftButtonUp")
	scanButton:SetScript("OnClick", function()
		state:OnAuctionActionClick()
	end)
	local skipButton = CreateFrame("Button", nil, scanPanel, "UIPanelButtonTemplate")
	skipButton:SetSize(90, 28)
	skipButton:SetPoint("LEFT", scanButton, "RIGHT", 8, 0)
	skipButton:SetText("Passer")
	skipButton:RegisterForClicks("LeftButtonUp")
	skipButton:SetScript("OnClick", function()
		state:SkipNextResult()
	end)

	local policy = scanPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	policy:SetPoint("TOPLEFT", scanButton, "BOTTOMLEFT", 4, -6)
	policy:SetPoint("RIGHT", scanPanel, "RIGHT", -4, 0)
	policy:SetWordWrap(false)
	policy:SetMaxLines(1)
	policy:SetText("Un clic = une action • au-dessus du max : alerte informative si TSM l’autorise")

	local budgetLabel = scanPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	budgetLabel:SetPoint("TOPLEFT", policy, "BOTTOMLEFT", 0, -8)
	budgetLabel:SetText("Budget session (po, 0 = illimité)")
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

	local restockLabel = scanPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	restockLabel:SetPoint("TOPLEFT", budgetLabel, "BOTTOMLEFT", 0, -7)
	restockLabel:SetText("Stock manquant min. (%, 0 = désactivé)")
	local restockInput = CreateFrame("EditBox", nil, scanPanel, "InputBoxTemplate")
	restockInput:SetSize(54, 24)
	restockInput:SetPoint("LEFT", restockLabel, "RIGHT", 6, 0)
	restockInput:SetAutoFocus(false)
	restockInput:SetNumeric(true)
	restockInput:SetMaxLetters(3)
	restockInput:SetJustifyH("RIGHT")
	restockInput:SetText(tostring(state.db.minRestockPercent or 0))
	local function CommitRestockPercent(input)
		local percent = math.max(0, math.min(100, math.floor(tonumber(input:GetText()) or 0)))
		local changed = percent ~= state.db.minRestockPercent
		state.db.minRestockPercent = percent
		input:SetText(tostring(percent))
		if not changed then
			return
		end
		DiagnosticLog("POLICY", "stock manquant minimum=%d%%", percent)
		if state.scanning or state.active or state.purchase then
			state.pendingPolicyRescan = true
			SetStatus(format("Seuil %d%% enregistré — appliqué à la fin de l’opération en cours.", percent))
			return
		end
		RefreshOperationLimits()
		PruneResults()
		UpdateView()
		if state:NeedsSearch() then
			StartScan()
		end
	end
	restockInput:SetScript("OnEnterPressed", function(input)
		CommitRestockPercent(input)
		input:ClearFocus()
	end)
	restockInput:SetScript("OnEditFocusLost", CommitRestockPercent)

	local sound = CreateCheck(scanPanel, "Son", state.db.sound, { "TOPLEFT", restockLabel, "BOTTOMLEFT", 0, -2 }, function(check)
		state.db.sound = check:GetChecked()
	end)
	CreateCheck(scanPanel, "Acheter au-dessus du max", state.db.buyAboveMaxPrice, { "LEFT", sound.text, "RIGHT", 14, 0 }, function(check)
		state.db.buyAboveMaxPrice = check:GetChecked() == true
		state.sortResults = true
		DiagnosticLog("POLICY", "achat au-dessus du max=%s", tostring(state.db.buyAboveMaxPrice))
		UpdateView()
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
	headerLimit:SetWidth(128)
	headerLimit:SetText("Qté / total")

	local resultsScroll = CreateFrame("ScrollFrame", nil, scanPanel, "UIPanelScrollFrameTemplate")
	resultsScroll:SetPoint("TOPLEFT", headerName, "BOTTOMLEFT", -4, -4)
	resultsScroll:SetPoint("BOTTOMRIGHT", scanPanel, "BOTTOMRIGHT", -18, 4)
	local resultsContent = CreateFrame("Frame", nil, resultsScroll)
	resultsContent:SetWidth(1)
	resultsContent:SetHeight(1)
	resultsScroll:SetScrollChild(resultsContent)
	state.resultsContent = resultsContent
	local function LayoutResults(width)
		local viewportWidth = math.max(1, math.floor(tonumber(width) or resultsScroll:GetWidth() or 1))
		local itemWidth = math.max(90, viewportWidth - 314)
		resultsContent:SetWidth(viewportWidth)
		headerName:SetWidth(itemWidth)
		for _, row in ipairs(state.resultRows) do
			row.itemCell:SetWidth(itemWidth)
			row.name:SetWidth(math.max(36, itemWidth - 54))
		end
	end
	resultsScroll:SetScript("OnSizeChanged", function(_, width)
		LayoutResults(width)
	end)
	frame.emptyResults = scanPanel:CreateFontString(nil, "OVERLAY", "GameFontDisable")
	frame.emptyResults:SetPoint("TOP", resultsScroll, "TOP", 0, -34)
	frame.emptyResults:SetText("Aucune opportunité pour le moment")

	local function CreateResultRow()
		local index = #state.resultRows + 1
		local row = CreateFrame("Frame", nil, resultsContent, "BackdropTemplate")
		row:SetHeight(30)
		if row.SetClipsChildren then
			row:SetClipsChildren(true)
		end
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
		row.limit:SetWidth(128)
		row.limit:SetJustifyH("RIGHT")
		row.limit:SetWordWrap(false)
		row:Hide()
		state.resultRows[index] = row
		LayoutResults(resultsScroll:GetWidth())
		return row
	end
	state.createResultRow = CreateResultRow
	LayoutResults(resultsScroll:GetWidth())

	state.frame = frame
	frame.scanButton = scanButton
	frame.skipButton = skipButton
	frame.resultCount = frame.resultCount
	frame:SetScript("OnShow", function()
		UpdateAHEventSubscription()
		DiagnosticLog("UI", "sniper tab shown version=%s; lazy initialization starting", tostring(
			(C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(addonName, "Version"))
			or (GetAddOnMetadata and GetAddOnMetadata(addonName, "Version"))
			or "unknown"
		))
		QueueBagDiagnostics("sniper-show", 0)
		C_Timer.After(0, function()
			if not IsAHVisible() then
				return
			end
			LayoutResults(resultsScroll:GetWidth())
			local startedAt = GetTime()
			RefreshGroupPaths()
			RebuildItems()
			DiagnosticLog("LAZY_INIT", "completed groups=%d items=%d elapsed=%.3f", #state.groupPaths, #state.items, GetTime() - startedAt)
		end)
	end)
	frame:SetScript("OnHide", function()
		CancelTimer("diagnosticSnapshotTimer")
		wipe(state.diagnosticSnapshotReasons)
		wipe(state.itemLoadRequests)
		if state.scanning or state.active then
			StopScan()
		end
		if state.purchase and state.purchase.mode == "purchase" and state.purchase.confirmed then
			EnterPurchaseQuarantine("tab-hidden-after-confirm")
		elseif state.purchase and (state.purchase.mode == "quarantine" or state.purchase.mode == "quote-quarantine") then
			-- La transaction reste propriétaire de l’AH jusqu’au terminal ou à sa deadline.
		elseif state.purchase then
			CancelPurchase(false)
		end
		UpdateAHEventSubscription()
	end)
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
		if YayaReagentSniperReset and YayaReagentSniperReset.Hide then
			YayaReagentSniperReset:Hide()
		end
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
		if state.active.kind == "browse" then
			active = format("batch de %d item(s)", state.active.items and #state.active.items or 0)
		else
			active = format("%s (%d)", state.active.kind or "item", state.active.itemID or 0)
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
		print(format("Yaya Reagent Sniper : affichage diagnostic %s", state.db.debug and "ACTIVÉ" or "désactivé"))
		if state.db.debug then
			PrintDebug()
		end
	elseif command == "diag" then
		local action, value = argument:match("^(%S*)%s*(.-)$")
		if action == "on" then
			state.db.diagnostics = true
			DiagnosticLog("DIAG", "persistent diagnostics enabled")
		elseif action == "off" then
			DiagnosticLog("DIAG", "persistent diagnostics disabled")
			state.db.diagnostics = false
		elseif action == "clear" then
			wipe(state.db.diagnosticLog)
			wipe(state.diagnosticSnapshot)
			print("Yaya Reagent Sniper : journal diagnostic vidé.")
			return
		elseif action == "dump" then
			local count = math.max(1, math.min(100, tonumber(value) or 40))
			local first = math.max(1, #state.db.diagnosticLog - count + 1)
			print(format("Yaya Reagent Sniper : %d dernière(s) ligne(s) diagnostic", #state.db.diagnosticLog - first + 1))
			for index = first, #state.db.diagnosticLog do
				print(state.db.diagnosticLog[index])
			end
			return
		end
		print(format("Yaya Reagent Sniper : diagnostics persistants %s • %d/%d lignes", state.db.diagnostics and "ACTIFS" or "désactivés", #state.db.diagnosticLog, DIAGNOSTIC_LOG_LIMIT))
	elseif command == "status" then
		PrintDebug()
	else
		print("Yaya Reagent Sniper : /yrs debug [on|off] • /yrs diag [on|off|clear|dump 40] • /yrs status")
	end
end

ReleaseAbandonedQuery = function(event, value)
	local abandoned = state.abandonedQuery
	if not abandoned then
		return false
	end
	if abandoned.generation ~= state.operationGeneration
		or abandoned.scanGeneration ~= state.scanGeneration
	then
		return false
	end
	local matches = false
	if abandoned.kind == "browse" then
		matches = event == "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED"
			or event == "AUCTION_HOUSE_BROWSE_FAILURE"
	elseif abandoned.kind == "commodity" then
		matches = event == "COMMODITY_SEARCH_RESULTS_UPDATED"
			and tonumber(value) == tonumber(abandoned.itemID)
	elseif abandoned.kind == "item" then
		matches = event == "ITEM_SEARCH_RESULTS_UPDATED"
			and type(value) == "table"
			and tonumber(value.itemID) == tonumber(abandoned.itemID)
	end
	if not matches then
		return false
	end
	CancelTimer("purchaseDrainTimer")
	state.abandonedQuery = nil
	DiagnosticLog("AH_DRAIN", "ancienne requête terminée kind=%s item=%s", tostring(abandoned.kind), tostring(abandoned.itemID))
	return true
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
	if YayaReagentSniperReset and YayaReagentSniperReset.EnsureUI then
		YayaReagentSniperReset:EnsureUI(AuctionHouseFrame, {
			stopSniper = StopScan,
			isPurchaseBusy = function()
				return state.purchase ~= nil
					or state.active ~= nil
					or state.abandonedQuery ~= nil
					or state.scanning
					or state.resumeAfterPurchase
					or (state.queryQuarantineUntil or 0) > GetTime()
			end,
			updateEventSubscription = UpdateAHEventSubscription,
			updateSniperView = UpdateView,
			getOperationForItem = GetOperationForItem,
			getCustomPriceValue = GetCustomPriceValue,
			resolveOperationSetting = ResolveOperationSetting,
		})
	end
end

local eventFrame = CreateFrame("Frame")
	state.events = eventFrame
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("AUCTION_HOUSE_SHOW")
eventFrame:RegisterEvent("AUCTION_HOUSE_CLOSED")
eventFrame:SetScript("OnEvent", function(self, event, ...)
	-- Les SavedVariables ne sont restaurees qu'apres l'execution des fichiers de
	-- l'addon. Le GetDB() de portee fichier travaillait donc sur une table neuve,
	-- orpheline : l'UI y ecrivait, WoW serialisait le global jamais modifie, et
	-- tous les reglages repartaient aux defauts a chaque session (son reactive,
	-- stock manquant min. remis a 0). On repointe state.db sur la table restauree.
	if event == "ADDON_LOADED" then
		local loadedAddon = ...
		if loadedAddon == addonName then
			state.db = GetDB()
		end
		return
	end
	if YayaReagentSniperReset and YayaReagentSniperReset.OnEvent then
		YayaReagentSniperReset:OnEvent(event, ...)
	end
	if event == "PLAYER_LOGIN" then
		-- Ceinture et bretelles : si ADDON_LOADED a ete manque, la table restauree
		-- est de toute facon disponible ici, bien avant la creation de l'UI qui
		-- n'intervient qu'a l'ouverture de l'hotel des ventes.
		state.db = GetDB()
		return
	elseif event == "AUCTION_HOUSE_SHOW" then
		C_Timer.After(0.2, EnsureUI)
		return
	elseif event == "ITEM_DATA_LOAD_RESULT" then
		local itemID, success = ...
		if IsAHVisible() and state.itemLoadRequests[itemID] then
			DiagnosticLog("ITEM_DATA_EVENT", "item=%s success=%s ownRequests=%d frameShown=%s", tostring(itemID), tostring(success), state.itemLoadRequests[itemID], tostring(IsAHVisible()))
			QueueBagDiagnostics("own-item-data:" .. tostring(itemID), 0)
		end
		return
	elseif event == "BAG_UPDATE" then
		if IsAHVisible() then
			QueueBagDiagnostics("bag-update:" .. tostring((...)), 0)
		end
		return
	elseif event == "PLAYER_MONEY" then
		if IsAHVisible() then
			UpdateView()
		end
		return
	elseif event == "MAIL_INBOX_UPDATE" or event == "MAIL_SHOW" or event == "BAG_UPDATE_DELAYED" then
		if IsAHVisible() then
			QueueBagDiagnostics(string.lower(event), 0)
			QueueInventoryRefresh()
		end
		return
	end
	if event == "AUCTION_HOUSE_CLOSED" or state.scanning or state.active or state.purchase or state.abandonedQuery or state.resumeAfterPurchase then
		HandleAuctionEvent(self, event, ...)
	end
	if event == "AUCTION_HOUSE_CLOSED" then
		UpdateAHEventSubscription()
	end
end)

state.db = GetDB()

YayaReagentSniperAPI = YayaReagentSniperAPI or {}

function YayaReagentSniperAPI.IsAuctionContextActive()
	return IsAHVisible()
end

function YayaReagentSniperAPI.OnAuctionActionClick()
	if not IsAHVisible() then
		return false
	end
	state:OnAuctionActionClick()
	return true
end
