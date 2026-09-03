local addonName = ...

local Reset = {}
YayaReagentSniperReset = Reset

local CONSTANTS = {
	BATCH_SIZE = 100,
	START_SETTLE_DELAY = 0.05,
	QUERY_TIMEOUT = 7,
	THROTTLE_WAIT_TIMEOUT = 8,
	BETWEEN_QUERIES = 0.10,
	DEEP_UI_REFRESH_EVERY = 8,
	DEEP_QUERY_LIMIT = 85,
	DEEP_QUERY_ACTION_LIMIT = 90,
	DEEP_QUERY_WINDOW = 60,
	OPPORTUNITY_PAUSE = 10,
	ACTION_LOCK = 0.5,
	MAX_DEEP_PAGES = 40,
	MAX_SCAN_AGE = 300,
	PURCHASE_REFRESH_MAX_AGE = 10,
	THROTTLE_UI_GRACE = 0.4,
	PURCHASE_UNCERTAIN_COOLDOWN = 300,
	QUOTE_QUARANTINE_SECONDS = 8,
	ROW_HEIGHT = 36,
	AH_CUT = 0.05,
	STOCK_SCORE_BONUS = 5,
	STOCK_SCORE_PENALTY = 8,
}

local SORTS = {
	{
		sortOrder = Enum.AuctionHouseSortOrder.Price,
		reverseSort = false,
	},
}

local CATALOG_OPTIONS = {
	{ key = "all", label = "Toutes extensions" },
	{ key = "classic", label = "Vanilla" },
	{ key = "burning_crusade", label = "Burning Crusade" },
	{ key = "wrath", label = "Wrath" },
	{ key = "cataclysm", label = "Cataclysm" },
	{ key = "mists", label = "Mists" },
	{ key = "warlords", label = "Warlords" },
	{ key = "legion", label = "Legion" },
	{ key = "bfa", label = "BfA" },
	{ key = "shadowlands", label = "Shadowlands" },
	{ key = "dragonflight", label = "Dragonflight" },
	{ key = "the_war_within", label = "The War Within" },
	{ key = "midnight", label = "Midnight" },
}

-- Ordre de traitement des cibles : une baisse de plancher passe avant un volume
-- ajoute, lui-meme avant un item jamais lu en profondeur.
local TRIGGER_RANK = { price = 1, volume = 2, first = 3 }

local CATALOG_TYPES = {
	{ key = "raw", label = "Réactifs bruts" },
	{ key = "prepared", label = "Consommables préparés" },
}

local RESULT_COLUMNS = {
	{ key = "cost", label = "Coût", width = 64 },
	{ key = "quantity", label = "Qté", width = 36 },
	{ key = "target", label = "Cible", width = 60, minViewport = 380 },
	{ key = "profit", label = "Profit", width = 64 },
	{ key = "roi", label = "ROI", width = 36, minViewport = 460 },
	{ key = "liquidity", label = "TSM/j", width = 72, minViewport = 640 },
	{ key = "days", label = "J", width = 34, minViewport = 560 },
	{ key = "risk", label = "Risque", width = 50, minViewport = 720 },
	{ key = "score", label = "Score", width = 40 },
}

local scan = {
	frame = nil,
	tab = nil,
	controller = nil,
	db = nil,
	phase = "idle",
	running = false,
	paused = false,
	pauseRequested = false,
	opportunityPauseUntil = nil,
	opportunityPauseExpired = false,
	pausedActive = nil,
	startPending = false,
	generation = 0,
	operationGeneration = 0,
	candidates = {},
	browseIndex = 1,
	deepCandidates = {},
	deepIndex = 1,
	active = nil,
	timers = {},
	opportunities = {},
	depthCache = {},
	priceBaseline = {},
	baselineStartedAt = nil,
	forceDeepCycle = false,
	cycleMode = "deep",
	bagCounts = {},
	rows = {},
	selected = nil,
	resumeAfterPurchase = false,
	prepareRefresh = nil,
	purchase = nil,
	purchaseGeneration = 0,
	purchaseCooldowns = {},
	purchaseUncertainUntil = 0,
	actionCooldownUntil = 0,
	continuousPending = false,
	resumeContinuousAfterAction = false,
	throttleResume = nil,
	throttleWaitSince = nil,
	throttleBusySince = nil,
	abandonedQuery = nil,
	throttleDrops = 0,
	deepQueryTimes = {},
	completedAt = nil,
	stats = {},
	catalogSource = nil,
	catalogSelectedCount = 0,
	ownAuctions = {},
	ownAuctionRecords = {},
	ownAuctionCount = 0,
	ownAuctionQuantity = 0,
	ownQuerySent = false,
	ownAuctionsReady = false,
	ownCancelCheck = nil,
	sellTargets = {},
	sellIndex = 1,
	sellStage = nil,
	sellCursor = 1,
	sellBagItems = {},
	sellQuerySent = false,
	post = nil,
	sellOnly = false,
}

local BeginOwnAuctionCancellation
local BeginOwnAuctionVerification
local EnterPause
local ValidateFreshResetPlan
local RefreshBlacklistPanel
local HandleCommodityResults
local IsSellModeEnabled

local function GetCatalogOption(key)
	for _, option in ipairs(CATALOG_OPTIONS) do
		if option.key == key then
			return option
		end
	end
	return CATALOG_OPTIONS[1]
end

local function GetCatalogTypeOption(key)
	for _, option in ipairs(CATALOG_TYPES) do
		if option.key == key then
			return option
		end
	end
	return CATALOG_TYPES[1]
end

local function Clamp(value, minimum, maximum)
	value = tonumber(value) or minimum
	return math.max(minimum, math.min(maximum, value))
end

local function FormatPrice(value)
	return YayaCore.Money.Format(value, { clampNegative = true })
end

local function FormatDecimal(value, digits)
	local text = string.format("%." .. tostring(digits or 1) .. "f", tonumber(value) or 0)
	return text:gsub("%.", ",")
end

local function FormatCompactNumber(value)
	value = tonumber(value) or 0
	if value >= 1000000 then
		return FormatDecimal(value / 1000000, 1) .. " M"
	elseif value >= 1000 then
		return FormatDecimal(value / 1000, 1) .. " k"
	end
	return tostring(math.floor(value + 0.5))
end

local function GetItemID(itemString)
	return tonumber(string.match(itemString or "", "^[pi]:(%d+)"))
end

local function GetItemLink(itemID)
	if C_Item and C_Item.GetItemLinkByID then
		local link = C_Item.GetItemLinkByID(itemID)
		if link then
			return link
		end
	end
	return GetItemInfo and select(2, GetItemInfo(itemID)) or nil
end

local function GetItemName(itemID)
	local name = C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(itemID)
	return name or (GetItemInfo and select(1, GetItemInfo(itemID))) or ("Composant " .. tostring(itemID))
end

local function GetItemTexture(itemID)
	if C_Item and C_Item.GetItemInfoInstant then
		local icon = select(5, C_Item.GetItemInfoInstant(itemID))
		if icon then
			return icon
		end
	end
	return GetItemIcon and GetItemIcon(itemID) or "Interface\\Icons\\INV_Misc_QuestionMark"
end

local function IsCommodity(itemID)
	if not itemID then
		return false
	end
	local classID
	if C_Item and C_Item.GetItemInfoInstant then
		classID = select(6, C_Item.GetItemInfoInstant(itemID))
	elseif GetItemInfoInstant then
		classID = select(6, GetItemInfoInstant(itemID))
	end
	return classID == Enum.ItemClass.Tradegoods
		or (Enum.ItemClass.Consumable and classID == Enum.ItemClass.Consumable)
end

local function CollectCatalogItemIDs(selection)
	local catalog = type(YayaReagentSniperCatalog) == "table" and YayaReagentSniperCatalog or nil
	local expansions = catalog and type(catalog.expansions) == "table" and catalog.expansions or nil
	local seen, itemIDs, hasCatalog = {}, {}, false
	if not expansions then
		return itemIDs, false
	end
	local enabledTypes = scan.db and scan.db.catalogTypes or {}
	-- Le tri se fait a l'interieur de chaque extension : un tri global sur les
	-- itemID melangerait les extensions et remonterait les plus anciennes en
	-- premier, leurs identifiants etant les plus petits.
	local function AddIDs(ids)
		if not ids then
			return
		end
		local batch = {}
		for _, itemID in ipairs(ids) do
			itemID = tonumber(itemID)
			if itemID and itemID > 0 and not seen[itemID] then
				seen[itemID] = true
				batch[#batch + 1] = itemID
			end
		end
		table.sort(batch)
		for _, itemID in ipairs(batch) do
			itemIDs[#itemIDs + 1] = itemID
		end
	end
	-- CATALOG_OPTIONS va de la plus ancienne extension a la plus recente : on la
	-- remonte a l'envers pour scanner Midnight en premier. Un objet partage entre
	-- deux extensions est ainsi retenu sous la plus recente qui le contient.
	for index = #CATALOG_OPTIONS, 1, -1 do
		local option = CATALOG_OPTIONS[index]
		if option.key ~= "all" then
			local entry = expansions[option.key]
			local rawIDs = entry and type(entry.rawItemIDs) == "table" and entry.rawItemIDs or nil
			local preparedIDs = entry and type(entry.preparedItemIDs) == "table" and entry.preparedItemIDs or nil
			local legacyIDs = entry and type(entry.itemIDs) == "table" and entry.itemIDs or nil
			if (rawIDs and #rawIDs > 0) or (preparedIDs and #preparedIDs > 0) or (legacyIDs and #legacyIDs > 0) then
				hasCatalog = true
				if selection == "all" or selection == option.key then
					if rawIDs or preparedIDs then
						if enabledTypes.raw ~= false then
							AddIDs(rawIDs)
						end
						if enabledTypes.prepared ~= false then
							AddIDs(preparedIDs)
						end
					else
						AddIDs(legacyIDs)
					end
				end
			end
		end
	end
	return itemIDs, hasCatalog
end

local function GetTSMValue(source, itemString)
	if type(TSM_API) ~= "table" or type(TSM_API.GetCustomPriceValue) ~= "function" then
		return nil
	end
	local ok, value = pcall(TSM_API.GetCustomPriceValue, source, itemString)
	value = ok and tonumber(value) or nil
	return value and value > 0 and value or nil
end

local function CancelTimer(name)
	local timer = scan.timers[name]
	if timer and timer.Cancel then
		timer:Cancel()
	end
	scan.timers[name] = nil
end

local function Schedule(name, delay, callback)
	CancelTimer(name)
	scan.timers[name] = C_Timer.NewTimer(delay, function()
		scan.timers[name] = nil
		callback()
	end)
end

local function CancelScanTimers()
	for name in pairs(scan.timers) do
		CancelTimer(name)
	end
	scan.continuousPending = false
	scan.throttleResume = nil
end

local function ResetStats()
	scan.stats = {
		browsed = 0,
		deepQueued = 0,
		deepScanned = 0,
		noMarket = 0,
		missingData = 0,
		incomplete = 0,
		rejected = 0,
		unchanged = 0,
	}
end

-- Prix planchers releves au pre-scan. Ils survivent volontairement aux cycles du
-- scan continu : le premier passage d'un item l'analyse en profondeur, les
-- suivants ne relancent une requete que si son marche a bouge.
local function ClearPriceBaselines()
	wipe(scan.priceBaseline)
	scan.baselineStartedAt = nil
end

local function RememberPrice(itemID, minPrice, totalQuantity)
	local entry = scan.priceBaseline[itemID]
	if not entry then
		entry = {}
		scan.priceBaseline[itemID] = entry
	end
	entry.minPrice = minPrice
	entry.totalQuantity = totalQuantity
	entry.seenAt = GetTime()
end

-- Motif d'analyse profonde. Sans reference, l'item n'a jamais ete lu en
-- profondeur : c'est le cycle qui etablit la reference. Ensuite, seule une
-- baisse du plancher ou du volume ajoute justifie une nouvelle requete.
local function GetDeepTrigger(candidate)
	local baseline = scan.priceBaseline[candidate.itemID]
	if not baseline or not baseline.minPrice then
		return "first", 0
	elseif candidate.minPrice < baseline.minPrice then
		return "price", 1 - candidate.minPrice / baseline.minPrice
	elseif candidate.totalQuantity > (baseline.totalQuantity or 0) then
		return "volume", candidate.totalQuantity - baseline.totalQuantity
	end
	return nil, 0
end

-- Seule la queue non traitee est triee : scan.deepIndex avance en continu et
-- reordonner tout le tableau relancerait des items deja analyses.
local function SortPendingDeepCandidates()
	local first = scan.deepIndex
	if first >= #scan.deepCandidates then
		return
	end
	local pending = {}
	for index = first, #scan.deepCandidates do
		pending[#pending + 1] = scan.deepCandidates[index]
	end
	table.sort(pending, function(left, right)
		local leftRank = TRIGGER_RANK[left.triggerReason or "first"] or 3
		local rightRank = TRIGGER_RANK[right.triggerReason or "first"] or 3
		if leftRank ~= rightRank then
			return leftRank < rightRank
		end
		local leftScore = left.triggerScore or 0
		local rightScore = right.triggerScore or 0
		if leftScore ~= rightScore then
			return leftScore > rightScore
		end
		return (left.rotationOrder or 0) < (right.rotationOrder or 0)
	end)
	for offset, candidate in ipairs(pending) do
		scan.deepCandidates[first + offset - 1] = candidate
	end
end

local function GetDB()
	YayaReagentSniperDB = type(YayaReagentSniperDB) == "table" and YayaReagentSniperDB or {}
	local db = type(YayaReagentSniperDB.reset) == "table" and YayaReagentSniperDB.reset or {}
	YayaReagentSniperDB.reset = db
	local defaultsVersion = tonumber(db.defaultsVersion) or 0
	if defaultsVersion < 2 then
		if tonumber(db.minROI) == 15 then
			db.minROI = 8
		end
		if tonumber(db.minProfitGold) == 1000 then
			db.minProfitGold = 250
		end
		if tonumber(db.maxDays) == 3 then
			db.maxDays = 7
		end
		if tonumber(db.maxTargetPct) == 120 then
			db.maxTargetPct = 140
		end
		db.defaultsVersion = 2
	end
	db.minROI = Clamp(db.minROI or 8, 1, 500)
	db.minProfitGold = Clamp(db.minProfitGold or 250, 0, 100000000)
	db.maxDays = Clamp(db.maxDays or 7, 0.25, 30)
	db.marketShare = Clamp(db.marketShare or 10, 1, 100)
	db.maxTargetPct = Clamp(db.maxTargetPct or 140, 50, 300)
	db.budgetGold = Clamp(db.budgetGold or 500000, 1, 100000000)
	db.goldThreshold = Clamp(db.goldThreshold or 0, 0, 100000000)
	db.minScore = Clamp(db.minScore or 0, 0, 100)
	db.sound = db.sound == true
	db.continuous = db.continuous == true
	-- L'ancienne case unique se scinde en deux : on reporte son etat sur les deux.
	if db.cancelRepost ~= nil then
		db.autoCancel = db.autoCancel == nil and db.cancelRepost == true or db.autoCancel
		db.autoPost = db.autoPost == nil and db.cancelRepost == true or db.autoPost
		db.cancelRepost = nil
	end
	db.autoCancel = db.autoCancel == true
	db.autoPost = db.autoPost == true
	db.catalogTypes = type(db.catalogTypes) == "table" and db.catalogTypes or {}
	db.catalogTypes.raw = db.catalogTypes.raw ~= false
	db.catalogTypes.prepared = db.catalogTypes.prepared ~= false
	db.blacklist = type(db.blacklist) == "table" and db.blacklist or {}
	db.rotation = type(db.rotation) == "table" and db.rotation or {}
	db.deepRefreshMinutes = Clamp(db.deepRefreshMinutes or 15, 0, 720)
	db.purchaseUncertainUntil = tonumber(db.purchaseUncertainUntil) or 0
	if db.purchaseUncertainUntil <= time() then
		db.purchaseUncertainUntil = 0
	end
	db.expansion = GetCatalogOption(db.expansion).key
	return db
end

local function IsBlacklisted(itemID)
	itemID = tonumber(itemID)
	return itemID and scan.db and (scan.db.blacklist[tostring(itemID)] == true or scan.db.blacklist[itemID] == true) or false
end

local function GetBlacklistedItemIDs()
	local itemIDs = {}
	local seen = {}
	for key, enabled in pairs(scan.db and scan.db.blacklist or {}) do
		local itemID = enabled and tonumber(key)
		if itemID and itemID > 0 and not seen[itemID] then
			seen[itemID] = true
			itemIDs[#itemIDs + 1] = itemID
		end
	end
	table.sort(itemIDs)
	return itemIDs
end

local function GetGoldThresholdCopper()
	local gold = scan.db and tonumber(scan.db.goldThreshold) or 0
	return math.max(0, math.floor(gold * 10000 + 0.5))
end

function Reset:GetEffectiveBudgetCopper()
	local configuredBudget = math.max(0, math.floor((tonumber(scan.db and scan.db.budgetGold) or 0) * 10000))
	local currentGold = type(GetMoney) == "function" and tonumber(GetMoney()) or configuredBudget
	return math.min(configuredBudget, math.max(0, math.floor(currentGold or 0)))
end

local function IsBelowGoldThreshold()
	local threshold = GetGoldThresholdCopper()
	local available = type(GetMoney) == "function" and tonumber(GetMoney()) or nil
	return threshold > 0 and available ~= nil and available < threshold, threshold, available
end

local function GetGoldThresholdMessage()
	local blocked, threshold, available = IsBelowGoldThreshold()
	if not blocked then
		return nil
	end
	return string.format("Seuil d’or minimum atteint : %s requis, %s disponible.", FormatPrice(threshold), FormatPrice(available))
end

local function GetRotationState()
	local key = scan.db and scan.db.expansion or "all"
	local state = scan.db.rotation[key]
	if type(state) ~= "table" then
		state = {}
		scan.db.rotation[key] = state
	end
	state.nextIndex = math.max(1, math.floor(tonumber(state.nextIndex) or 1))
	return state
end

local function GetBagItemCount(itemID)
	itemID = tonumber(itemID)
	if not itemID or itemID <= 0 then
		return 0
	end
	if scan.bagCounts[itemID] ~= nil then
		return scan.bagCounts[itemID]
	end
	local count = 0
	if C_Item and type(C_Item.GetItemCount) == "function" then
		local ok, value = pcall(C_Item.GetItemCount, itemID, false, false, false, false)
		if ok then
			count = tonumber(value) or 0
		end
	elseif type(GetItemCount) == "function" then
		local ok, value = pcall(GetItemCount, itemID, false)
		if ok then
			count = tonumber(value) or 0
		end
	end
	scan.bagCounts[itemID] = math.max(0, count)
	return scan.bagCounts[itemID]
end

local function ApplyInventoryMetrics(result, bagQuantity)
	local quantity = math.max(1, tonumber(result.quantity) or 0)
	local dailyCapacity = math.max(0, (tonumber(result.soldPerDay) or 0) * scan.db.marketShare / 100)
	local horizonCapacity = math.max(1, dailyCapacity * scan.db.maxDays)
	result.bagQuantity = math.max(0, tonumber(bagQuantity) or 0)
	result.inventoryPriority = Clamp(result.bagQuantity / math.max(1, result.bagQuantity + quantity), 0, 1)
	result.inventoryRisk = Clamp(result.bagQuantity / horizonCapacity, 0, 1)
	result.inventoryDays = dailyCapacity > 0 and result.bagQuantity / dailyCapacity or 0
	result.inventoryBonus = CONSTANTS.STOCK_SCORE_BONUS * result.inventoryPriority
	result.inventoryPenalty = CONSTANTS.STOCK_SCORE_PENALTY * result.inventoryRisk
end

local function SetStatus(text, red)
	if not scan.frame then
		return
	end
	scan.frame.status:SetText(text or "")
	if red then
		scan.frame.status:SetTextColor(1, 0.35, 0.25, 1)
	else
		scan.frame.status:SetTextColor(0.85, 0.85, 0.85, 1)
	end
end

local function PlayNewOpportunitySound()
	if not scan.db or not scan.db.sound or type(PlaySound) ~= "function" then
		return
	end
	local sound = SOUNDKIT and (SOUNDKIT.RAID_WARNING or SOUNDKIT.ALARM_CLOCK_WARNING_2)
	if sound then
		pcall(PlaySound, sound)
	end
end

local function IsFresh()
	return scan.completedAt and GetTime() - scan.completedAt <= CONSTANTS.MAX_SCAN_AGE
end

local function RiskFor(result)
	if result.targetPrice <= result.referencePrice * 1.05 then
		return "Faible", 0.35, 1, 0.45, 1
	elseif result.targetPrice <= result.referencePrice * 1.12 then
		return "Moyen", 1, 0.82, 0.25, 0.6
	end
	return "Élevé", 1, 0.35, 0.25, 0.2
end

local function ComputeScore(result)
	local budget = math.max(1, Reset:GetEffectiveBudgetCopper())
	local profitPivot = math.max(5000 * 10000, scan.db.minProfitGold * 10000 * 5)
	local roiFloor = scan.db.minROI / 100
	local profitComponent = result.profit / (result.profit + profitPivot)
	local roiComponent = Clamp((result.roi - roiFloor) / math.max(0.01, 1 - roiFloor), 0, 1)
	local costComponent = 1 / (1 + result.absorbCost / math.max(1, budget * 0.10))
	local liquidityComponent = Clamp((result.saleRate or 0) / 0.30, 0, 1)
	local speedComponent = 1 - Clamp(result.days / math.max(0.01, scan.db.maxDays), 0, 1)
	local riskComponent = result.riskFactor or 0.2
	local inventoryBonus = result.inventoryBonus or 0
	local inventoryPenalty = result.inventoryPenalty or 0
	result.scoreParts = {
		profit = profitComponent,
		roi = roiComponent,
		cost = costComponent,
		liquidity = liquidityComponent,
		speed = speedComponent,
		risk = riskComponent,
		inventoryPriority = result.inventoryPriority or 0,
		inventoryRisk = result.inventoryRisk or 0,
	}
	local baseScore = 100 * (
		0.48 * profitComponent
		+ 0.22 * roiComponent
		+ 0.10 * costComponent
		+ 0.07 * liquidityComponent
		+ 0.08 * speedComponent
		+ 0.05 * riskComponent
	)
	return Clamp(baseScore + inventoryBonus - inventoryPenalty, 0, 100)
end

local function ResolveTSMData(candidate)
	if candidate.tsmResolved then
		return candidate.referencePrice and candidate.soldPerDay
	end
	candidate.tsmResolved = true
	candidate.referencePrice = GetTSMValue("DBMarket", candidate.itemString)
		or GetTSMValue("DBRegionMarketAvg", candidate.itemString)
	candidate.soldPerDay = GetTSMValue("DBRegionSoldPerDay", candidate.itemString)
	candidate.saleRate = GetTSMValue("DBRegionSaleRate", candidate.itemString)
	return candidate.referencePrice and candidate.soldPerDay
end

local function LoadOpportunityItem(result)
	result.itemLink = GetItemLink(result.itemID)
	result.name = GetItemName(result.itemID)
	result.icon = GetItemTexture(result.itemID)
	if not Item or not Item.CreateFromItemID then
		return
	end
	local generation = scan.generation
	local itemObject = Item:CreateFromItemID(result.itemID)
	if type(YayaReagentSniperTrace) == "function" then
		YayaReagentSniperTrace("RESET_ITEM_LOAD", "request item=%s generation=%s", tostring(result.itemID), tostring(generation))
	end
	itemObject:ContinueOnItemLoad(function()
		if not scan.frame or not scan.frame:IsShown() then
			return
		end
		if type(YayaReagentSniperTrace) == "function" then
			YayaReagentSniperTrace("RESET_ITEM_LOAD", "callback item=%s cached=%s generation=%s current=%s", tostring(result.itemID), tostring(itemObject:IsItemDataCached()), tostring(generation), tostring(scan.generation))
		end
		if scan.generation ~= generation then
			return
		end
		result.itemLink = itemObject:GetItemLink() or result.itemLink
		result.name = itemObject:GetItemName() or result.name
		result.icon = GetItemTexture(result.itemID)
		Reset:RefreshRows()
	end)
end

local function EvaluateDepth(candidate, tiers, ownAuctionQuantity)
	if not candidate.referencePrice or not candidate.soldPerDay or candidate.soldPerDay <= 0 or #tiers < 2 then
		return nil
	end
	local maxTarget = candidate.referencePrice * scan.db.maxTargetPct / 100
	local budget = Reset:GetEffectiveBudgetCopper()
	local minProfit = scan.db.minProfitGold * 10000
	local dailyCapacity = candidate.soldPerDay * scan.db.marketShare / 100
	if dailyCapacity <= 0 then
		return nil
	end
	local bagQuantity = GetBagItemCount(candidate.itemID)
	local cumulativeQuantity = 0
	local cumulativeCost = 0
	local best
	for index = 1, #tiers - 1 do
		local tier = tiers[index]
		local nextTier = tiers[index + 1]
		cumulativeQuantity = cumulativeQuantity + tier.quantity
		cumulativeCost = cumulativeCost + tier.price * tier.quantity
		local targetPrice = nextTier.price
		if targetPrice > tier.price and targetPrice <= maxTarget then
			local days = cumulativeQuantity / dailyCapacity
			local revenue = cumulativeQuantity * targetPrice * (1 - CONSTANTS.AH_CUT)
			local profit = math.floor(revenue - cumulativeCost)
			local roi = cumulativeCost > 0 and profit / cumulativeCost or 0
			if cumulativeCost <= budget and profit >= minProfit and roi >= scan.db.minROI / 100 and days <= scan.db.maxDays then
					local option = {
						itemID = candidate.itemID,
						itemString = candidate.itemString,
						quantity = cumulativeQuantity,
						absorbCost = cumulativeCost,
						maxUnitPrice = tier.price,
						targetPrice = targetPrice,
						profit = profit,
						roi = roi,
						soldPerDay = candidate.soldPerDay,
						saleRate = candidate.saleRate,
						days = days,
						referencePrice = candidate.referencePrice,
						tiersAbsorbed = index,
						tierCount = #tiers,
						complete = true,
						ownAuctionQuantity = ownAuctionQuantity or 0,
						scanAt = GetTime(),
					}
				ApplyInventoryMetrics(option, bagQuantity)
				option.risk, option.riskR, option.riskG, option.riskB, option.riskFactor = RiskFor(option)
				option.score = ComputeScore(option)
				if not best
					or option.score > best.score
					or (option.score == best.score and option.profit > best.profit)
					or (option.score == best.score and option.profit == best.profit and option.roi > best.roi)
				then
					best = option
				end
			end
		end
		if cumulativeCost > budget then
			break
		end
	end
	if best then
		if best.score < scan.db.minScore then
			return nil
		end
		LoadOpportunityItem(best)
	end
	return best
end

local function SortOpportunities()
	table.sort(scan.opportunities, function(left, right)
		if left.score ~= right.score then
			return left.score > right.score
		end
		if left.profit ~= right.profit then
			return left.profit > right.profit
		end
		if left.roi ~= right.roi then
			return left.roi > right.roi
		end
		return left.itemID < right.itemID
	end)
end

local function EnsureDefaultSelection()
	if scan.selected then
		for _, result in ipairs(scan.opportunities) do
			if result == scan.selected then
				return
			end
		end
	end
	scan.selected = scan.opportunities[1]
end

local function SelectNextOpportunity(excludedItemID)
	SortOpportunities()
	if #scan.opportunities == 0 then
		scan.selected = nil
		return nil
	end
	local startIndex = 1
	for index, result in ipairs(scan.opportunities) do
		if result.itemID == excludedItemID then
			startIndex = index + 1
			break
		end
	end
	for offset = 0, #scan.opportunities - 1 do
		local index = ((startIndex + offset - 1) % #scan.opportunities) + 1
		local result = scan.opportunities[index]
		if result.itemID ~= excludedItemID then
			scan.selected = result
			return result
		end
	end
	scan.selected = nil
	return nil
end

local function UpdateCatalogSelector()
	local selection = scan.db and scan.db.expansion or "all"
	local option = GetCatalogOption(selection)
	local itemIDs, hasCatalog = CollectCatalogItemIDs(option.key)
	scan.catalogSelectedCount = #itemIDs
	if scan.frame and scan.frame.expansionDropdown then
		UIDropDownMenu_SetSelectedValue(scan.frame.expansionDropdown, option.key)
		UIDropDownMenu_SetText(scan.frame.expansionDropdown, option.label)
		scan.frame.catalogCount:SetText(hasCatalog and string.format("%d catalogue", #itemIDs) or "Catalogue indisponible")
		local types = scan.db and scan.db.catalogTypes or {}
		if scan.frame.rawTypeCheck then
			scan.frame.rawTypeCheck:SetChecked(types.raw ~= false)
		end
		if scan.frame.preparedTypeCheck then
			scan.frame.preparedTypeCheck:SetChecked(types.prepared ~= false)
		end
	end
	return hasCatalog
end

local function GetCatalogTypeSummary()
	local types = scan.db and scan.db.catalogTypes or {}
	local raw = types.raw ~= false
	local prepared = types.prepared ~= false
	if raw and prepared then
		return "brut + préparé"
	elseif raw then
		return GetCatalogTypeOption("raw").label
	elseif prepared then
		return GetCatalogTypeOption("prepared").label
	end
	return "aucun type"
end

local function GetScanSummary()
	if scan.running then
		if scan.paused then
			if scan.phase == "deep" then
				return string.format("Analyse en pause : %d / %d", math.min(scan.deepIndex - 1, #scan.deepCandidates), #scan.deepCandidates)
			end
			return "Analyse en pause"
		elseif scan.phase == "owned" then
			return "Lecture des auctions personnelles…"
		elseif scan.phase == "browse" then
			if scan.cycleMode == "snipe" then
				return string.format("Pré-scan snipe : %d / %d composants • %d cible(s)", math.min(scan.browseIndex - 1, #scan.candidates), #scan.candidates, scan.stats.deepQueued or 0)
			end
			return string.format("Pré-scan profond : %d / %d composants", math.min(scan.browseIndex - 1, #scan.candidates), #scan.candidates)
		elseif scan.phase == "deep" then
			if scan.cycleMode == "snipe" then
				return string.format("Analyse ciblée : %d / %d", math.min(scan.deepIndex - 1, #scan.deepCandidates), #scan.deepCandidates)
			end
			return string.format("Analyse des paliers : %d / %d", math.min(scan.deepIndex - 1, #scan.deepCandidates), #scan.deepCandidates)
		end
	end
	if IsFresh() then
		return string.format("%d recommandation(s) • données fraîches", #scan.opportunities)
	elseif scan.completedAt then
		return "Résultats périmés — relance le scan"
	end
	if scan.catalogSource == "tsm" then
		return string.format("Prêt — fallback groupes TSM • %d composants", scan.catalogSelectedCount or 0)
	end
	local label = GetCatalogOption(scan.db and scan.db.expansion or "all").label
	return string.format("Catalogue • %s • %s • %d composants", label, GetCatalogTypeSummary(), scan.catalogSelectedCount or 0)
end

-- Les widgets ne sont reecrits que sur changement reel : pendant un scan, le
-- transport Blizzard bascule toutes les 100 ms et repeindrait le bouton d'action
-- a chaque bascule. L'etat courant du widget sert de reference plutot qu'un cache
-- local, car d'autres fonctions ecrivent encore ces boutons directement.
local function SetWidgetText(widget, text)
	if not widget or widget:GetText() == text then
		return
	end
	widget:SetText(text)
end

local function SetButtonEnabled(button, enabled)
	enabled = enabled == true
	if not button or (button:IsEnabled() and true or false) == enabled then
		return
	end
	button:SetEnabled(enabled)
end

local function RefreshGoldLock()
	local frame = scan.frame
	if not frame then
		return false
	end
	-- Le mode Cancel & Repost survit au seuil d'or : il ne coupe que les achats,
	-- lesquels sont deja refuses par l'etat du bouton d'action.
	local blocked = IsBelowGoldThreshold() and not IsSellModeEnabled()
	if blocked then
		SetButtonEnabled(frame.scanButton, false)
		SetButtonEnabled(frame.pauseButton, false)
		SetButtonEnabled(frame.continuousButton, false)
		SetButtonEnabled(frame.prepareButton, false)
		return true
	end
	if frame.scanButton then
		local pending = scan.startPending or scan.purchase or scan.prepareRefresh or scan.continuousPending
		SetButtonEnabled(frame.scanButton, not pending)
	end
	return false
end

local function EnforceGoldThreshold()
	local message = GetGoldThresholdMessage()
	if not message then
		return false
	end
	-- En mode Cancel & Repost, le seuil ne coupe que les achats : la vente prend
	-- le relais au lieu d'arreter le scan.
	if IsSellModeEnabled() then
		scan.sellOnly = true
		if scan.running and (scan.phase == "browse" or scan.phase == "deep") and scan.sellStage == nil then
			Reset:BeginSellPhase(false)
		end
		return false
	end
	if scan.running or scan.active or scan.startPending or scan.purchase or scan.prepareRefresh or scan.ownCancelCheck or scan.continuousPending then
		Reset:StopScan()
	end
	if scan.frame and scan.frame:IsShown() then
		Reset:RefreshRows()
		SetStatus(message, true)
	end
	return true
end

local function RefreshContinuousButton()
	local button = scan.frame and scan.frame.continuousButton
	if not button then
		return
	end
	SetWidgetText(button, scan.db and scan.db.continuous and "Scan continu ✓" or "Scan continu")
	SetButtonEnabled(button, not IsBelowGoldThreshold() and not scan.purchase and not scan.prepareRefresh and not scan.ownCancelCheck and not scan.pauseRequested)
end

local function RefreshPauseButton()
	local button = scan.frame and scan.frame.pauseButton
	if not button then
		return
	end
	local canPause = scan.running and scan.phase == "deep" and not scan.prepareRefresh and not scan.purchase and not scan.ownCancelCheck
	if scan.paused then
		SetWidgetText(button, "Reprendre")
		SetButtonEnabled(button, not IsBelowGoldThreshold() and not scan.purchase and not scan.prepareRefresh and not scan.ownCancelCheck)
	elseif scan.pauseRequested then
		SetWidgetText(button, "Pause…")
		SetButtonEnabled(button, false)
	else
		SetWidgetText(button, "Pause")
		SetButtonEnabled(button, canPause)
	end
end

local function IsPurchaseOutcomeUncertain()
	local expiresAt = math.max(
		tonumber(scan.purchaseUncertainUntil) or 0,
		scan.db and tonumber(scan.db.purchaseUncertainUntil) or 0
	)
	if expiresAt <= 0 then
		return false
	elseif time() >= expiresAt then
		scan.purchaseUncertainUntil = 0
		if scan.db then
			scan.db.purchaseUncertainUntil = 0
		end
		return false
	end
	scan.purchaseUncertainUntil = expiresAt
	return true
end

-- L'occupation du transport dure 0,1 a 0,3 s entre deux requetes de scan : on ne
-- grise le bouton que si elle se prolonge, sinon il clignoterait a chaque requete.
local function IsTransportBlockingAction()
	if not C_AuctionHouse.IsThrottledMessageSystemReady or C_AuctionHouse.IsThrottledMessageSystemReady() then
		scan.throttleBusySince = nil
		return false
	end
	if not scan.throttleBusySince then
		scan.throttleBusySince = GetTime()
		return false
	end
	return GetTime() - scan.throttleBusySince >= CONSTANTS.THROTTLE_UI_GRACE
end

-- Libelle du bouton d'action : ne depend que de l'etat durable de la selection,
-- jamais d'un blocage transitoire (transport occupe, phase du scan, budget).
local function IsSellAction(action)
	return action == "sell-cancel" or action == "sell-post"
end

local function GetBuyAction(result)
	if not result or result.complete ~= true then
		return "none"
	elseif not result.quantity or result.quantity <= 0 or not result.absorbCost or result.absorbCost <= 0 then
		return "none"
	elseif result.lifecycleState == "stale" or not result.scanAt or GetTime() - result.scanAt > CONSTANTS.MAX_SCAN_AGE then
		return "refresh"
	elseif not result.purchaseVerifiedAt or GetTime() - result.purchaseVerifiedAt > CONSTANTS.PURCHASE_REFRESH_MAX_AGE then
		return "refresh"
	elseif result.ownAuctionQuantity and result.ownAuctionQuantity > 0 then
		return "cancel-own"
	end
	return "buy"
end

local function GetPrepareAction(result)
	if scan.purchase then
		return "purchase"
	elseif scan.post then
		return "posting"
	elseif scan.prepareRefresh then
		return "refreshing"
	elseif scan.ownCancelCheck then
		return "own-cancel"
	end
	local buyAction = GetBuyAction(result)
	-- L'achat garde la priorite tant qu'il est finançable : une opportunite
	-- fraiche est bien plus perissable qu'une enchere a annuler.
	if buyAction ~= "none" and not IsBelowGoldThreshold() then
		-- Pendant la phase de vente, seule une opportunite directement achetable
		-- passe devant : une ligne a rafraichir bloquerait sinon toutes les cibles.
		if scan.phase ~= "sell" or buyAction == "buy" or buyAction == "cancel-own" then
			return buyAction
		end
	end
	local target = Reset:GetNextSellTarget()
	if target then
		return target.kind == "cancel" and "sell-cancel" or "sell-post"
	end
	return buyAction
end

local function GetPrepareState(result, ignoreCooldown)
	if scan.purchase then
		return "disabled", "Un achat Reset est déjà en cours."
	elseif scan.post then
		return "disabled", "Une mise en vente est déjà en cours."
	elseif IsPurchaseOutcomeUncertain() then
		return "disabled", "Résultat d’achat incertain : sécurité active pendant 5 min."
	elseif scan.prepareRefresh then
		return "disabled", "Actualisation ciblée en cours…"
	elseif scan.ownCancelCheck then
		return "disabled", scan.ownCancelCheck.phase == "wait" and "Action prioritaire en attente de Blizzard…"
			or scan.ownCancelCheck.phase == "cancel" and "Annulation de tes auctions en cours…"
			or "Vérification de tes auctions en cours…"
	elseif scan.pauseRequested then
		return "disabled", "Pause du scan en cours…"
	elseif not ignoreCooldown and GetTime() < (scan.actionCooldownUntil or 0) then
		return "disabled", "Protection multiclic active…"
	elseif IsBelowGoldThreshold() and not IsSellAction(GetPrepareAction(result)) then
		return "disabled", GetGoldThresholdMessage()
	elseif scan.controller and scan.controller.isPurchaseBusy and scan.controller.isPurchaseBusy() then
		return "disabled", "Termine l’achat Sniper en cours."
	elseif IsTransportBlockingAction() then
		return "disabled", "Transport Blizzard occupé : le bouton sera réactivé au signal de disponibilité."
	elseif scan.running and scan.phase ~= "browse" and scan.phase ~= "deep" and scan.phase ~= "sell" then
		return "disabled", "Attends l’analyse du marché avant l’achat."
	elseif IsSellAction(GetPrepareAction(result)) then
		return "ready", nil
	elseif not result then
		return "disabled", "Sélectionne une opportunité."
	elseif result.complete ~= true then
		return "disabled", "Les paliers de cette opportunité sont incomplets."
	elseif not result.quantity or result.quantity <= 0 or not result.absorbCost or result.absorbCost <= 0 then
		return "disabled", "La quantité ou le coût estimé est indisponible."
	elseif result.lifecycleState == "stale" or not result.scanAt or GetTime() - result.scanAt > CONSTANTS.MAX_SCAN_AGE then
		return "refresh", result.lifecycleReason or "Les données ont expiré : un rescan profond ciblé est requis."
	elseif not result.purchaseVerifiedAt or GetTime() - result.purchaseVerifiedAt > CONSTANTS.PURCHASE_REFRESH_MAX_AGE then
		return "refresh", "Une vérification profonde ciblée est requise juste avant chaque achat."
	elseif result.absorbCost > Reset:GetEffectiveBudgetCopper() then
		return "disabled", "Le coût dépasse le budget effectif (budget configuré ou or disponible)."
	end
	return "ready", nil
end

function Reset:RefreshSelected()
	if not scan.frame then
		return
	end
	local result = scan.selected
	local prepareState, prepareMessage = GetPrepareState(result)
	local prepareAction = GetPrepareAction(result)
	local locked = GetTime() < (scan.actionCooldownUntil or 0)
	local canBlacklist = result ~= nil
		and not IsBlacklisted(result.itemID)
		and not scan.purchase
		and not scan.prepareRefresh
		and not scan.ownCancelCheck
		and not scan.continuousPending
		and not scan.pauseRequested
		and not IsBelowGoldThreshold()
		and (not scan.running or scan.paused)
	if scan.frame.prepareButton then
		local text
		if prepareAction == "purchase" then
			text = "Achat en cours…"
		elseif prepareAction == "posting" then
			text = "Mise en vente…"
		elseif prepareAction == "refreshing" then
			text = "Actualisation…"
		elseif prepareAction == "own-cancel" then
			text = scan.ownCancelCheck.phase == "wait" and "Action verrouillée…" or scan.ownCancelCheck.phase == "cancel" and "Annulation…" or "Vérification…"
		elseif locked then
			text = "Verrouillé…"
		elseif prepareAction == "refresh" then
			text = "Actualiser"
		elseif prepareAction == "cancel-own" then
			text = "Annule mes auctions"
		elseif prepareAction == "sell-cancel" then
			local cancels = Reset:GetSellCounts()
			text = cancels > 1 and string.format("Annuler (%d)", cancels) or "Annuler l’enchère"
		elseif prepareAction == "sell-post" then
			local _, posts = Reset:GetSellCounts()
			text = posts > 1 and string.format("Mettre en vente (%d)", posts) or "Mettre en vente"
		elseif not result then
			text = "Aucune sélection"
		else
			text = "Acheter le reset"
		end
		SetWidgetText(scan.frame.prepareButton, text)
		SetButtonEnabled(scan.frame.prepareButton, prepareState ~= "disabled")
	end
	if scan.frame.blacklistButton then
		SetButtonEnabled(scan.frame.blacklistButton, canBlacklist)
	end
	if scan.frame.prepareHint then
		local hint
		if prepareAction == "purchase" then
			hint = "Transaction Blizzard en cours"
		elseif prepareAction == "posting" then
			hint = "Mise en vente en cours"
		elseif prepareAction == "refreshing" then
			hint = "Lecture des paliers en cours"
		elseif prepareAction == "own-cancel" then
			hint = scan.ownCancelCheck.phase == "wait" and "Attente du signal Blizzard" or scan.ownCancelCheck.phase == "cancel" and "Annulation de tes auctions" or "Vérification de tes auctions"
		elseif locked then
			hint = "Action disponible dans 0,5 seconde"
		elseif prepareAction == "refresh" then
			hint = "1 clic • aucun achat automatique"
		elseif prepareAction == "cancel-own" then
			hint = "Étape 1/2 • clic manuel pour annuler"
		elseif prepareAction == "sell-cancel" then
			hint = "1 clic • 1 enchère annulée"
		elseif prepareAction == "sell-post" then
			hint = "1 clic • 1 mise en vente"
		elseif prepareAction == "none" then
			hint = "Sélection fraîche requise"
		else
			hint = scan.running and "1 clic • scan interrompu" or "1 achat • prix revalidé"
		end
		SetWidgetText(scan.frame.prepareHint, hint)
	end
	if IsSellAction(prepareAction) then
		local target = self:GetNextSellTarget()
		if target then
			local name = GetItemLink(target.itemID) or GetItemName(target.itemID) or ("Objet " .. tostring(target.itemID))
			SetWidgetText(scan.frame.detailTitle, name)
			if target.kind == "cancel" then
				SetWidgetText(scan.frame.detailBody, string.format(
					"%s Ton prix %s/u pour %d unité(s)%s. L’objet annulé revient par courrier avant de pouvoir être remis en vente.",
					target.reason or "Enchère à annuler.",
					FormatPrice(target.unitPrice or 0),
					target.quantity or 0,
					target.targetPrice and string.format(" • repost visé %s/u", FormatPrice(target.targetPrice)) or ""
				))
			else
				SetWidgetText(scan.frame.detailBody, string.format(
					"Mise en vente de %d unité(s) à %s/u pour %d h%s%s.",
					target.quantity or 0,
					FormatPrice(target.unitPrice or 0),
					YayaReagentSniperSell and YayaReagentSniperSell.GetDurationHours(target.duration) or 24,
					target.hasOperation and " • opération Auctioning TSM" or " • plancher automatique",
					target.marketPrice and string.format(" • marché %s/u", FormatPrice(target.marketPrice)) or " • aucune concurrence"
				))
			end
			return
		end
	end
	if not result then
		SetWidgetText(scan.frame.detailTitle, "Sélectionne une ligne pour voir le scénario")
		SetWidgetText(scan.frame.detailBody, "Aucune boucle : un clic humain ne lance qu’un seul achat Reset sélectionné.")
		return
	end
	SetWidgetText(scan.frame.detailTitle, result.itemLink or result.name or ("Composant " .. tostring(result.itemID)))
	if prepareState == "disabled" then
		SetWidgetText(scan.frame.detailBody, prepareMessage .. " Aucun achat n’a été lancé.")
		return
	elseif prepareState == "refresh" then
		SetWidgetText(scan.frame.detailBody, (result.lifecycleReason or "Données expirées.") .. " Le bouton actualise uniquement cet item. Un nouveau clic sera requis pour acheter.")
		return
	end
	SetWidgetText(scan.frame.detailBody, string.format(
		"Score %d/100 • absorber %s palier(s) pour %s, puis viser %s/u. Profit net %s après 5%% de commission • %.1f j à %.0f%% de la demande TSM%s%s. Le prix Blizzard sera revalidé avant confirmation.",
		math.floor(result.score + 0.5),
		result.tiersAbsorbed,
		FormatPrice(result.absorbCost),
		FormatPrice(result.targetPrice),
		FormatPrice(result.profit),
		result.days,
		scan.db.marketShare,
		result.ownAuctionQuantity and result.ownAuctionQuantity > 0
			and string.format(" • %s de tes unités exclues du calcul : annulation au clic manuel", FormatCompactNumber(result.ownAuctionQuantity))
			or "",
		result.bagQuantity and result.bagQuantity > 0
			and string.format(" • sacs %s : +%.1f / -%.1f score", FormatCompactNumber(result.bagQuantity), result.inventoryBonus or 0, result.inventoryPenalty or 0)
			or ""
	))
end

local function DropResetOpportunity(itemID)
	for index = #scan.opportunities, 1, -1 do
		if scan.opportunities[index].itemID == itemID then
			table.remove(scan.opportunities, index)
		end
	end
	scan.depthCache[itemID] = nil
	if scan.selected and scan.selected.itemID == itemID then
		scan.selected = nil
	end
end

local function InvalidateResetOpportunity(result, reason)
	if not result then
		return
	end
	result.lifecycleState = "stale"
	result.lifecycleReason = reason or "Résultat à rescanner avant tout nouvel achat."
	result.scanAt = 0
	scan.depthCache[result.itemID] = nil
end

local function IsPurchaseCoolingDown(itemID)
	itemID = tonumber(itemID)
	local expiresAt = itemID and tonumber(scan.purchaseCooldowns[itemID]) or nil
	if not expiresAt then
		return false
	elseif GetTime() >= expiresAt then
		scan.purchaseCooldowns[itemID] = nil
		return false
	end
	return true
end

function Reset:SuspendScanForPurchase()
	if not scan.running or scan.paused then
		return false
	end
	local active = scan.active
	CancelScanTimers()
	scan.pauseRequested = false
	scan.paused = true
	scan.pausedActive = nil
	if active and not active.waitingForMore and not active.responseReceived then
		local abandoned = {
			kind = active.kind,
			itemID = active.candidate and active.candidate.itemID or nil,
			generation = active.generation,
			operationGeneration = active.operationGeneration,
		}
		scan.abandonedQuery = abandoned
		Schedule("actionDrainTimeout", CONSTANTS.QUERY_TIMEOUT, function()
			Reset:HandleDrainTimeout(abandoned)
		end)
	else
		scan.abandonedQuery = nil
	end
	-- La réponse éventuelle sera seulement drainée, jamais traitée. L'index
	-- courant n'avance pas, donc le composant ou le lot sera repris proprement.
	scan.active = nil
	return true
end

function Reset:ArmActionCooldown(duration)
	duration = math.max(0.1, tonumber(duration) or 0.5)
	scan.actionCooldownUntil = math.max(scan.actionCooldownUntil or 0, GetTime() + duration)
	local unlockDelay = math.max(0.1, scan.actionCooldownUntil - GetTime() + 0.02)
	Schedule("actionUnlock", unlockDelay, function()
		if GetTime() >= (scan.actionCooldownUntil or 0) then
			Reset:RefreshRows()
			if scan.controller and scan.controller.updateSniperView then
				scan.controller.updateSniperView()
			end
		end
	end)
end

function Reset:AbortPriorityAction(message)
	self:ArmActionCooldown(CONSTANTS.ACTION_LOCK)
	self:ResumeSuspendedScan()
	self:ResumeContinuousAfterAction()
	self:RefreshRows()
	SetStatus(message or "Action interrompue : reprise du scan.", true)
end

function Reset:ResumeContinuousAfterAction()
	if not scan.resumeContinuousAfterAction then
		return false
	end
	scan.resumeContinuousAfterAction = false
	if not scan.db.continuous or scan.running or not scan.frame or not scan.frame:IsShown() then
		return false
	end
	scan.continuousPending = true
	Schedule("continuous", CONSTANTS.BETWEEN_QUERIES, function()
		scan.continuousPending = false
		if scan.db.continuous and not scan.purchase and not scan.running and scan.frame and scan.frame:IsShown() then
			Reset:StartScan()
		end
	end)
	return true
end

function Reset:ResumeSuspendedScan()
	if not scan.running or not scan.paused or scan.prepareRefresh then
		return false
	end
	scan.paused = false
	scan.pauseRequested = false
	scan.pausedActive = nil
	Schedule("next", 0, function()
		if not scan.running or scan.paused or scan.purchase then
			return
		end
		if scan.phase == "browse" then
			Reset:ProcessBrowse()
		elseif scan.phase == "deep" then
			Reset:ProcessDeep()
			elseif scan.phase == "sell" then
				Reset:ProcessSell()
		end
	end)
	return true
end

function Reset:ResumeAfterSuccessfulPurchase()
	if scan.purchase or not scan.frame or not scan.frame:IsShown() then
		return false
	end
	if C_AuctionHouse.IsThrottledMessageSystemReady
		and not C_AuctionHouse.IsThrottledMessageSystemReady()
	then
		scan.throttleResume = {
			timerName = "purchaseReady",
			callback = function()
				Reset:ResumeAfterSuccessfulPurchase()
			end,
		}
		Schedule("purchaseReady", 0.5, function()
			Reset:ResumeAfterSuccessfulPurchase()
		end)
		SetStatus("Achat réussi • attente du transport Blizzard avant reprise…")
		return false
	end
	CancelTimer("opportunityPause")
	scan.opportunityPauseUntil = nil
	scan.opportunityPauseExpired = false
	scan.resumeContinuousAfterAction = false
	if scan.running then
		if scan.paused then
			self:ResumeSuspendedScan()
		end
	else
		local actionLockRemaining = math.max(0, (scan.actionCooldownUntil or 0) - GetTime())
		self:StartScan(true)
		if actionLockRemaining > 0 then
			self:ArmActionCooldown(actionLockRemaining)
		end
	end
	self:RefreshRows()
	SetStatus("Achat réussi • reprise du scan.")
	return true
end

function Reset:FinishOpportunityPause(success)
	if not scan.opportunityPauseUntil and not scan.opportunityPauseExpired then
		return false
	end
	local remaining = (scan.opportunityPauseUntil or 0) - GetTime()
	if not success and remaining > 0 then
		Schedule("opportunityPause", remaining, function()
			scan.opportunityPauseUntil = nil
			scan.opportunityPauseExpired = true
			if not scan.purchase and not scan.prepareRefresh and not scan.ownCancelCheck then
				Reset:FinishOpportunityPause(false)
			end
		end)
		return false
	end
	if scan.purchase or scan.prepareRefresh or scan.ownCancelCheck then
		scan.opportunityPauseExpired = true
		return false
	end
	if success and C_AuctionHouse.IsThrottledMessageSystemReady
		and not C_AuctionHouse.IsThrottledMessageSystemReady()
	then
		scan.opportunityPauseExpired = true
		scan.throttleResume = {
			timerName = "opportunityReady",
			callback = function()
				Reset:FinishOpportunityPause(true)
			end,
		}
		SetStatus("Achat réussi • attente du transport Blizzard avant reprise…")
		return false
	end
	CancelTimer("opportunityPause")
	scan.opportunityPauseUntil = nil
	scan.opportunityPauseExpired = false
	if scan.running and scan.paused then
		self:ResumeSuspendedScan()
		self:RefreshRows()
		SetStatus(success and "Achat réussi • reprise du scan." or "Fenêtre d’achat terminée • reprise du scan.")
	end
	return true
end

local function CancelResetPurchase(message, red, disposition)
	local purchase = scan.purchase
	if purchase and purchase.confirming and not purchase.terminal and disposition ~= "uncertain" then
		disposition = "uncertain"
		message = message or "Résultat de confirmation incertain : achats bloqués 5 min."
		red = true
	end
	if purchase and disposition == "quote-uncertain" then
		CancelTimer("purchaseTimeout")
		CancelTimer("purchaseWake")
		if purchase.started and not purchase.cancelRequested and C_AuctionHouse.CancelCommoditiesPurchase then
			pcall(C_AuctionHouse.CancelCommoditiesPurchase)
			purchase.cancelRequested = true
		end
		purchase.mode = "quote-quarantine"
		purchase.phase = "ambiguous-before-confirm"
		InvalidateResetOpportunity(purchase.result, message)
		C_Timer.After(CONSTANTS.QUOTE_QUARANTINE_SECONDS, function()
			if scan.purchase == purchase and purchase.mode == "quote-quarantine" then
				purchase.terminal = true
				CancelResetPurchase("Ancienne cotation abandonnée : nouveau scan requis.", true, "stale")
			end
		end)
		Reset:RefreshRows()
		if scan.controller and scan.controller.updateEventSubscription then
			scan.controller.updateEventSubscription()
		end
		SetStatus(message or "Cotation incertaine : achats bloqués pendant 8 secondes.", true)
		return
	end
	if purchase and disposition == "uncertain" then
		CancelTimer("purchaseTimeout")
		CancelTimer("purchaseWake")
		if scan.throttleResume and scan.throttleResume.timerName == "purchaseWake" then
			scan.throttleResume = nil
		end
		purchase.mode = "quarantine"
		purchase.phase = "ambiguous-after-confirm"
		purchase.confirming = false
		purchase.confirmed = true
		purchase.resumeScan = false
		scan.resumeAfterPurchase = false
		scan.resumeContinuousAfterAction = false
		local expiresAt = time() + CONSTANTS.PURCHASE_UNCERTAIN_COOLDOWN
		purchase.quarantineUntil = expiresAt
		scan.purchaseCooldowns[purchase.itemID] = GetTime() + CONSTANTS.PURCHASE_UNCERTAIN_COOLDOWN
		scan.purchaseUncertainUntil = math.max(scan.purchaseUncertainUntil or 0, expiresAt)
		if scan.db then
			scan.db.purchaseUncertainUntil = math.max(tonumber(scan.db.purchaseUncertainUntil) or 0, expiresAt)
		end
		DropResetOpportunity(purchase.itemID)
		C_Timer.After(CONSTANTS.PURCHASE_UNCERTAIN_COOLDOWN + 0.1, function()
			if scan.purchase == purchase and purchase.mode == "quarantine" then
				scan.purchaseGeneration = scan.purchaseGeneration + 1
				scan.purchase = nil
				IsPurchaseOutcomeUncertain()
				Reset:ArmActionCooldown(CONSTANTS.ACTION_LOCK)
				Reset:RefreshRows()
				if scan.controller and scan.controller.updateEventSubscription then
					scan.controller.updateEventSubscription()
				end
				if scan.controller and scan.controller.updateSniperView then
					scan.controller.updateSniperView()
				end
				SetStatus("Quarantaine terminée sans réponse : nouveau scan requis.", true)
			end
		end)
		Reset:RefreshRows()
		if scan.controller and scan.controller.updateEventSubscription then
			scan.controller.updateEventSubscription()
		end
		SetStatus(message or "Résultat de confirmation incertain : achats bloqués 5 min.", true)
		return
	end
	local resumeScan = purchase and purchase.resumeScan == true
	CancelTimer("purchaseTimeout")
	CancelTimer("purchaseWake")
	if scan.throttleResume and scan.throttleResume.timerName == "purchaseWake" then
		scan.throttleResume = nil
	end
	if purchase and purchase.started and not purchase.confirmed and not purchase.cancelRequested and C_AuctionHouse.CancelCommoditiesPurchase then
		pcall(C_AuctionHouse.CancelCommoditiesPurchase)
	end
	if purchase and (disposition == "drop" or disposition == "success" or disposition == "uncertain") then
		DropResetOpportunity(purchase.itemID)
	elseif purchase and disposition ~= "keep" then
		InvalidateResetOpportunity(purchase.result, message)
	end
	if purchase and purchase.terminal then
		scan.purchaseCooldowns[purchase.itemID] = nil
		scan.purchaseUncertainUntil = 0
		if scan.db then
			scan.db.purchaseUncertainUntil = 0
		end
	end
	scan.purchaseGeneration = scan.purchaseGeneration + 1
	scan.purchase = nil
	scan.throttleWaitSince = nil
	scan.resumeAfterPurchase = false
	Reset:ArmActionCooldown(CONSTANTS.ACTION_LOCK)
	if disposition == "success" then
		Reset:ResumeAfterSuccessfulPurchase()
	elseif resumeScan then
		if purchase and purchase.opportunityPause then
			Reset:FinishOpportunityPause(false)
		else
			Reset:ResumeSuspendedScan()
		end
	end
	Reset:ResumeContinuousAfterAction()
	if scan.frame then
		scan.frame.scanButton:SetEnabled(true)
	end
	Reset:RefreshRows()
	if scan.controller and scan.controller.updateEventSubscription then
		scan.controller.updateEventSubscription()
	end
	if scan.controller and scan.controller.updateSniperView then
		scan.controller.updateSniperView()
	end
	if message then
		SetStatus(message, red)
	end
end

function Reset:HandleDrainTimeout(abandoned)
	if not scan.abandonedQuery or (abandoned and scan.abandonedQuery ~= abandoned) then
		return
	end
	scan.abandonedQuery = nil
	scan.throttleResume = nil
	if scan.purchase then
		CancelResetPurchase("Requête précédente sans réponse : achat abandonné, scan repris.", true, "keep")
		return
	end
	if scan.ownCancelCheck and scan.ownCancelCheck.phase == "wait" then
		scan.ownCancelCheck = nil
		self:AbortPriorityAction("Requête précédente sans réponse : annulation abandonnée.")
		return
	end
	local context = scan.prepareRefresh
	if context then
		local resume = context.resume
		scan.prepareRefresh = nil
		scan.running = resume and resume.running or false
		scan.phase = resume and resume.phase or "idle"
		scan.active = nil
		scan.deepCandidates = resume and resume.deepCandidates or scan.deepCandidates
		scan.deepIndex = resume and resume.deepIndex or scan.deepIndex
		scan.paused = resume and resume.paused or false
		scan.pausedActive = nil
	end
	if scan.frame then
		scan.frame.scanButton:SetText(scan.running and "Arrêter" or "Scanner le marché")
		scan.frame.scanButton:SetEnabled(true)
	end
	self:AbortPriorityAction("Requête précédente sans réponse : action abandonnée, scan repris.")
end

ValidateFreshResetPlan = function(result)
	local verifiedAt = tonumber(result and result.purchaseVerifiedAt)
	local cached = result and scan.depthCache[result.itemID]
	if not verifiedAt or GetTime() - verifiedAt > CONSTANTS.PURCHASE_REFRESH_MAX_AGE
		or not cached or not cached.scanAt or GetTime() - cached.scanAt > CONSTANTS.PURCHASE_REFRESH_MAX_AGE
	then
		return false, "La vérification profonde a expiré."
	end
	local fullOk, full = pcall(C_AuctionHouse.HasFullCommoditySearchResults, result.itemID)
	if not fullOk or not full then
		return false, "Les paliers Blizzard ne sont pas complets."
	end
	local quantities = {}
	local ownByPrice = scan.ownAuctions[result.itemID] or {}
	local count = tonumber(C_AuctionHouse.GetNumCommoditySearchResults(result.itemID)) or 0
	for index = 1, count do
		local info = C_AuctionHouse.GetCommoditySearchResultInfo(result.itemID, index)
		if info and info.unitPrice and info.unitPrice > 0 and info.quantity and info.quantity > 0 then
			quantities[info.unitPrice] = (quantities[info.unitPrice] or 0) + info.quantity
		end
	end
	local tiers = {}
	local ownQuantity = 0
	for price, quantity in pairs(quantities) do
		local own = math.min(quantity, ownByPrice[price] or 0)
		ownQuantity = ownQuantity + own
		if quantity > own then
			tiers[#tiers + 1] = { price = price, quantity = quantity - own }
		end
	end
	table.sort(tiers, function(left, right)
		return left.price < right.price
	end)
	local fresh = EvaluateDepth(cached.candidate, tiers, ownQuantity)
	if not fresh
		or fresh.quantity ~= result.quantity
		or fresh.absorbCost ~= result.absorbCost
		or fresh.maxUnitPrice ~= result.maxUnitPrice
		or fresh.targetPrice ~= result.targetPrice
		or fresh.tiersAbsorbed ~= result.tiersAbsorbed
	then
		return false, "Le palier ou la profondeur cible a changé."
	end
	return true
end

local function StartResetPurchase(result)
	if EnforceGoldThreshold() then
		return
	end
	if scan.purchase or scan.prepareRefresh or scan.ownCancelCheck then
		return
	end
	if scan.controller and scan.controller.isPurchaseBusy and scan.controller.isPurchaseBusy() then
		Reset:AbortPriorityAction("Termine l’achat Sniper en cours : reprise du scan.")
		return
	end
	local valid, validationMessage = ValidateFreshResetPlan(result)
	if not valid then
		result.purchaseVerifiedAt = nil
		result.lifecycleState = "stale"
		result.lifecycleReason = validationMessage
		result.scanAt = 0
		scan.depthCache[result.itemID] = nil
		Reset:ArmActionCooldown(CONSTANTS.ACTION_LOCK)
		Reset:RefreshRows()
		SetStatus((validationMessage or "Offre devenue obsolète.") .. " Clique « Actualiser » après le verrou.", true)
		return
	end
	local quantity = math.max(1, math.floor(tonumber(result.quantity) or 0))
	local maxCost = math.max(0, math.floor(tonumber(result.absorbCost) or 0))
	local maxUnitPrice = math.max(0, math.floor(tonumber(result.maxUnitPrice) or 0))
	local budget = Reset:GetEffectiveBudgetCopper()
	local availableMoney = type(GetMoney) == "function" and tonumber(GetMoney()) or nil
	if type(C_AuctionHouse.StartCommoditiesPurchase) ~= "function"
		or type(C_AuctionHouse.ConfirmCommoditiesPurchase) ~= "function"
	then
		InvalidateResetOpportunity(result, "API d’achat indisponible : résultat à rescanner.")
		Reset:AbortPriorityAction("API d’achat de commodités indisponible : reprise du scan.")
		return
	elseif quantity <= 0 or maxCost <= 0 or maxUnitPrice <= 0 then
		InvalidateResetOpportunity(result, "Quantité ou coût invalide : résultat à rescanner.")
		Reset:AbortPriorityAction("Quantité ou coût du reset invalide : reprise du scan.")
		return
	elseif maxCost > budget then
		Reset:AbortPriorityAction("Le coût du reset dépasse le budget : reprise du scan.")
		return
	elseif availableMoney and maxCost > availableMoney then
		Reset:AbortPriorityAction("Or insuffisant : " .. FormatPrice(maxCost) .. " requis, " .. FormatPrice(availableMoney) .. " disponible. Reprise du scan.")
		return
	end
	if scan.abandonedQuery then
		Reset:ArmActionCooldown(CONSTANTS.ACTION_LOCK)
		Reset:RefreshRows()
		SetStatus("Ancienne requête AH en cours de vidage : reclique quand le bouton se réactive.", true)
		return
	elseif C_AuctionHouse.IsThrottledMessageSystemReady and not C_AuctionHouse.IsThrottledMessageSystemReady() then
		Reset:AbortPriorityAction("Transport Blizzard occupé : reclique dès que le bouton se réactive.")
		return
	end
	if scan.controller and scan.controller.stopSniper then
		scan.controller.stopSniper()
	end
	scan.purchaseGeneration = scan.purchaseGeneration + 1
	scan.purchase = {
		generation = scan.purchaseGeneration,
		itemID = result.itemID,
		name = result.name or GetItemName(result.itemID),
		quantity = quantity,
		maxCost = maxCost,
		authorizedQuantity = quantity,
		authorizedMaxUnitPrice = maxUnitPrice,
		authorizedMaxTotal = maxCost,
		budget = budget,
		result = result,
		resumeScan = scan.running and scan.paused or false,
		opportunityPause = scan.opportunityPauseUntil ~= nil or scan.opportunityPauseExpired,
		phase = "quote",
		confirmed = false,
		started = true,
		confirming = false,
	}
	if scan.frame then
		scan.frame.scanButton:SetEnabled(false)
	end
	Reset:RefreshRows()
	local purchase = scan.purchase
	if type(YayaReagentSniperTrace) == "function" then
		YayaReagentSniperTrace("RESET_PURCHASE", "click start item=%s generation=%s quantity=%s", tostring(purchase.itemID), tostring(purchase.generation), tostring(purchase.quantity))
	end
	local ok = pcall(C_AuctionHouse.StartCommoditiesPurchase, purchase.itemID, purchase.quantity)
	if not ok then
		purchase.started = false
		purchase.phase = "start-failed"
		CancelResetPurchase("Impossible de lancer l’achat : résultat à rescanner.", true, "stale")
		return
	end
	local generation = purchase.generation
	if scan.purchase == purchase and not purchase.confirming then
		Schedule("purchaseTimeout", CONSTANTS.QUERY_TIMEOUT, function()
			if scan.purchase == purchase and purchase.generation == generation and not purchase.confirming then
				CancelResetPurchase("Achat sans réponse : cotation tardive mise en quarantaine.", true, "quote-uncertain")
			end
		end)
		Reset:RefreshRows()
		if scan.controller and scan.controller.updateEventSubscription then
			scan.controller.updateEventSubscription()
		end
		SetStatus(string.format("Vérification Blizzard : %s × %s…", FormatCompactNumber(purchase.quantity), purchase.name or "composant"))
	end
end

local function HandleResetPurchaseEvent(event, ...)
	-- La cotation Blizzard est l’ultime garde-fou avant l’unique confirmation.
	local purchase = scan.purchase
	if not purchase then
		return false
	end
	if purchase.mode == "quote-quarantine"
		and (event == "COMMODITY_PRICE_UPDATED" or event == "COMMODITY_PRICE_UNAVAILABLE")
	then
		purchase.terminal = true
		CancelResetPurchase("Cotation tardive drainée : nouveau scan requis.", true, "stale")
		return true
	end
	if event == "COMMODITY_PRICE_UPDATED" then
		if not purchase.started or purchase.confirming then
			return true
		end
		CancelTimer("purchaseTimeout")
		local unitPrice, totalPrice = ...
		unitPrice = tonumber(unitPrice)
		totalPrice = tonumber(totalPrice)
		local planValid = ValidateFreshResetPlan(purchase.result)
		if not planValid
			or not unitPrice or unitPrice <= 0
			or not totalPrice or totalPrice <= 0
			or unitPrice > purchase.authorizedMaxUnitPrice
			or totalPrice > purchase.authorizedMaxTotal
		then
			CancelResetPurchase("Prix ou profondeur modifié : clique « Actualiser » après le verrou.", true, "stale")
			return true
		end
		local availableMoney = type(GetMoney) == "function" and tonumber(GetMoney()) or nil
		local currentBudget = Reset:GetEffectiveBudgetCopper()
		if availableMoney and totalPrice > availableMoney then
			CancelResetPurchase("Or insuffisant : " .. FormatPrice(totalPrice) .. " requis, " .. FormatPrice(availableMoney) .. " disponible.", true, "keep")
			return true
		elseif totalPrice > math.min(purchase.budget, currentBudget) then
			CancelResetPurchase("Le prix Blizzard dépasse le budget Reset.", true, "keep")
			return true
		end
		purchase.unitPrice = unitPrice
		purchase.totalPrice = totalPrice
		purchase.confirming = true
		purchase.confirmed = true
		purchase.phase = "confirming"
		local ok = pcall(C_AuctionHouse.ConfirmCommoditiesPurchase, purchase.itemID, purchase.authorizedQuantity)
		if not ok then
			purchase.confirming = false
			purchase.confirmed = false
			purchase.phase = "confirm-api-failed"
			CancelResetPurchase("Confirmation impossible : résultat à rescanner.", true, "stale")
			return true
		end
		local generation = purchase.generation
		if scan.purchase == purchase and purchase.confirming then
			Schedule("purchaseTimeout", CONSTANTS.QUERY_TIMEOUT, function()
				if scan.purchase == purchase and purchase.generation == generation and purchase.confirming then
					CancelResetPurchase("Confirmation sans réponse : item bloqué 5 min pour éviter un double achat.", true, "uncertain")
				end
			end)
			Reset:RefreshRows()
			SetStatus("Achat envoyé à Blizzard…")
		end
		return true
	elseif event == "COMMODITY_PRICE_UNAVAILABLE" then
		if not purchase.started or purchase.confirming then
			return true
		end
		CancelResetPurchase("Prix indisponible : clique « Actualiser » après le verrou.", true, "stale")
		return true
	elseif event == "COMMODITY_PURCHASE_SUCCEEDED" then
		if not purchase.confirmed or purchase.terminal then
			return true
		end
		local quantity, totalPrice = purchase.quantity, purchase.totalPrice or purchase.maxCost
		purchase.terminal = true
		purchase.confirmed = true
		CancelResetPurchase(string.format("Achat confirmé : %s unités pour %s.", FormatCompactNumber(quantity), FormatPrice(totalPrice)), false, "success")
		return true
	elseif event == "COMMODITY_PURCHASE_FAILED" then
		if not purchase.confirmed or purchase.terminal then
			return true
		end
		purchase.terminal = true
		CancelResetPurchase("Achat refusé ou offre déjà partie : résultat à actualiser.", true, "stale")
		return true
	end
	return false
end

function Reset:PreparePurchase()
	if scan.purchase or scan.post or scan.prepareRefresh or scan.ownCancelCheck or scan.pauseRequested then
		return
	end
	-- Les appels de vente sont restreints par Blizzard : ils partent du clic
	-- courant, jamais d'un timer ni d'un evenement.
	local sellTarget = self:GetNextSellTarget()
	local sellAction = IsSellAction(GetPrepareAction(scan.selected))
	if sellTarget and sellAction then
		local prepareState, prepareMessage = GetPrepareState(scan.selected)
		if prepareState ~= "ready" then
			SetStatus(prepareMessage, true)
			self:RefreshSelected()
			return
		end
		if sellTarget.kind == "cancel" then
			self:ExecuteSellCancel(sellTarget)
		else
			self:ExecuteSellPost(sellTarget)
		end
		return
	end
	if EnforceGoldThreshold() then
		return
	end
	local result = scan.selected
	local prepareState, prepareMessage = GetPrepareState(result)
	if prepareState ~= "ready" and prepareState ~= "refresh" then
		SetStatus(prepareMessage, true)
		self:RefreshSelected()
		return
	end
	-- Le clic d'achat gagne toujours contre le scan : on détache immédiatement
	-- toute requête en vol avant d'effectuer une autre opération AH.
	if scan.continuousPending then
		CancelTimer("continuous")
		scan.continuousPending = false
		scan.resumeContinuousAfterAction = scan.db.continuous == true
	end
	self:SuspendScanForPurchase()
	self:ArmActionCooldown(CONSTANTS.ACTION_LOCK)
	if prepareState == "refresh" then
		self:RefreshSelectedForPurchase(result, true)
		return
	end
	if result.ownAuctionQuantity and result.ownAuctionQuantity > 0 then
		BeginOwnAuctionCancellation(result)
		return
	end
	StartResetPurchase(result)
end

function Reset:RefreshSelectedForPurchase(result, acceptedClick)
	local prepareState, prepareMessage = GetPrepareState(result, acceptedClick == true)
	if prepareState == "ready" then
		self:PreparePurchase()
		return
	elseif prepareState ~= "refresh" then
		self:AbortPriorityAction(prepareMessage)
		return
	end
	if scan.controller and scan.controller.isPurchaseBusy and scan.controller.isPurchaseBusy() then
		self:AbortPriorityAction("Termine l’achat en cours : reprise du scan.")
		return
	end
	local candidate = {
		itemID = result.itemID,
		itemString = result.itemString or ("i:" .. tostring(result.itemID)),
		name = result.name or GetItemName(result.itemID),
	}
	if not ResolveTSMData(candidate) then
		result.complete = false
		self:AbortPriorityAction("Liquidité ou référence TSM indisponible : reprise du scan.")
		return
	end
	if type(C_AuctionHouse.MakeItemKey) ~= "function" or type(C_AuctionHouse.SendSearchQuery) ~= "function" then
		result.complete = false
		self:AbortPriorityAction("Recherche profonde indisponible : reprise du scan.")
		return
	end
	local resume = nil
	if scan.running and scan.paused and (scan.phase == "browse" or scan.phase == "deep") then
		resume = {
			running = true,
			phase = scan.phase,
			active = scan.active,
			paused = true,
			pausedActive = scan.pausedActive,
			deepCandidates = scan.deepCandidates,
			deepIndex = scan.deepIndex,
		}
	end
	scan.generation = scan.generation + 1
	CancelScanTimers()
	if scan.abandonedQuery then
		Schedule("actionDrainTimeout", CONSTANTS.QUERY_TIMEOUT, function()
			Reset:HandleDrainTimeout()
		end)
	end
	scan.paused = false
	scan.pauseRequested = false
	scan.pausedActive = nil
	scan.prepareRefresh = {
		itemID = result.itemID,
		original = result,
		resume = resume,
		expectedQuantity = result.quantity,
		expectedCost = result.absorbCost,
		expectedTarget = result.targetPrice,
	}
	scan.running = true
	scan.phase = "deep"
	scan.active = nil
	scan.deepCandidates = { candidate }
	scan.deepIndex = 1
	if scan.frame then
		scan.frame.scanButton:SetText("Actualisation…")
		scan.frame.scanButton:SetEnabled(false)
	end
	SetStatus("Actualisation profonde de " .. (result.name or "ce composant") .. "…")
	self:RefreshSelected()
	self:ProcessDeep()
end

local function UpdateRowVisual(row)
	local selected = row.data and scan.selected == row.data
	row.selected:SetShown(selected)
	row.hover:SetShown(row.mouseOver and not selected)
end

local function ShowRowTooltip(row)
	row.mouseOver = true
	UpdateRowVisual(row)
	local result = row.data
	if not result or not GameTooltip then
		return
	end
	GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
	local target = result.itemLink or ("item:" .. tostring(result.itemID))
	local ok = pcall(GameTooltip.SetHyperlink, GameTooltip, target)
	if not ok then
		GameTooltip:ClearLines()
		GameTooltip:AddLine(result.name or "Composant", 1, 1, 1)
	end
	GameTooltip:AddLine(" ")
	if result.lifecycleState == "stale" then
		GameTooltip:AddLine("État : à rescanner", 1, 0.62, 0.2)
		GameTooltip:AddLine(result.lifecycleReason or "Cette donnée ne peut plus être réutilisée pour acheter.", 0.85, 0.85, 0.85, true)
	elseif result.absorbCost > Reset:GetEffectiveBudgetCopper() then
		GameTooltip:AddLine("Achat bloqué : budget effectif insuffisant", 1, 0.35, 0.25)
	end
	GameTooltip:AddDoubleLine("Coût à absorber", FormatPrice(result.absorbCost), 0.8, 0.8, 0.8, 1, 1, 1)
	GameTooltip:AddDoubleLine("Quantité", FormatCompactNumber(result.quantity), 0.8, 0.8, 0.8, 1, 1, 1)
	if result.bagQuantity and result.bagQuantity > 0 then
		GameTooltip:AddDoubleLine("Dans tes sacs", FormatCompactNumber(result.bagQuantity), 0.8, 0.8, 0.8, 1, 1, 1)
		GameTooltip:AddLine(string.format("Priorité stock : +%.1f score • malus risque : -%.1f score • stock %.1f j", result.inventoryBonus or 0, result.inventoryPenalty or 0, result.inventoryDays or 0), 1, 0.82, 0.25, true)
	end
	if result.ownAuctionQuantity and result.ownAuctionQuantity > 0 then
		GameTooltip:AddLine(string.format("Tes propres auctions exclues : %s unités • annulation au clic manuel.", FormatCompactNumber(result.ownAuctionQuantity)), 1, 0.82, 0.25, true)
	end
	GameTooltip:AddDoubleLine("Cible / unité", FormatPrice(result.targetPrice), 0.8, 0.8, 0.8, 1, 1, 1)
	GameTooltip:AddDoubleLine("Profit net", FormatPrice(result.profit), 0.8, 0.8, 0.8, 0.35, 1, 0.45)
	GameTooltip:AddDoubleLine("ROI", string.format("%d%%", math.floor(result.roi * 100 + 0.5)), 0.8, 0.8, 0.8, 1, 1, 1)
	GameTooltip:AddDoubleLine("Référence TSM", FormatPrice(result.referencePrice), 0.8, 0.8, 0.8, 1, 1, 1)
	GameTooltip:AddDoubleLine("Ventes région / jour", FormatDecimal(result.soldPerDay, 1), 0.8, 0.8, 0.8, 1, 1, 1)
	GameTooltip:AddDoubleLine("Écoulement estimé", FormatDecimal(result.days, 1) .. " j", 0.8, 0.8, 0.8, 1, 1, 1)
	GameTooltip:AddDoubleLine("Risque", result.risk or "—", 0.8, 0.8, 0.8, result.riskR or 1, result.riskG or 1, result.riskB or 1)
	GameTooltip:AddDoubleLine("Score", string.format("%d / 100", math.floor(result.score + 0.5)), 0.8, 0.8, 0.8, 1, 0.82, 0.25)
	GameTooltip:AddLine("48% profit net • 22% ROI • 10% coût • 7% liquidité • 8% vitesse • 5% risque cible • bonus/malus stock", 0.75, 0.85, 1, true)
	GameTooltip:AddLine("Pivot profit : max(5 000 po, 5× seuil min) • coût 10% budget • SaleRate 30%.", 0.65, 0.75, 0.9, true)
	GameTooltip:AddLine("La quantité et les ventes/jour alimentent la durée ; la cible face à la référence et le stock en sacs alimentent le risque.", 0.65, 0.65, 0.65, true)
	GameTooltip:AddLine("Scénario indicatif : le marché peut se remplir avant la revente.", 1, 0.82, 0.25, true)
	GameTooltip:Show()
end

local function HideRowTooltip(row)
	row.mouseOver = false
	UpdateRowVisual(row)
	if GameTooltip and GameTooltip:IsOwned(row) then
		GameTooltip:Hide()
	end
end

local function RelayoutResults()
	local frame = scan.frame
	if not frame or not frame.resultsScroll or not frame.resultsContent or not frame.headers then
		return
	end
	local viewportWidth = math.floor(tonumber(frame.resultsScroll:GetWidth()) or 0)
	if viewportWidth <= 1 then
		return
	end
	local gap, itemX, rightPadding = 4, 36, 6
	local fixedWidth, visibleCount = 0, 0
	for _, column in ipairs(RESULT_COLUMNS) do
		column.visible = not column.minViewport or viewportWidth >= column.minViewport
		if column.visible then
			fixedWidth = fixedWidth + column.width
			visibleCount = visibleCount + 1
		end
	end
	local nameWidth = math.max(10, viewportWidth - rightPadding - itemX - fixedWidth - visibleCount * gap)
	frame.resultsContent:SetWidth(viewportWidth)
	frame.headerItem:ClearAllPoints()
	frame.headerItem:SetPoint("LEFT", frame.header, "LEFT", itemX, 0)
	frame.headerItem:SetWidth(nameWidth)
	local x = itemX + nameWidth
	for _, column in ipairs(RESULT_COLUMNS) do
		local header = frame.headers[column.key]
		if column.visible then
			x = x + gap
			header:ClearAllPoints()
			header:SetPoint("LEFT", frame.header, "LEFT", x, 0)
			header:SetWidth(column.width)
			header:Show()
			x = x + column.width
		else
			header:Hide()
		end
	end
	for _, row in ipairs(scan.rows) do
		row.itemText:SetWidth(nameWidth)
		x = itemX + nameWidth
		for _, column in ipairs(RESULT_COLUMNS) do
			local cell = row[column.key]
			if column.visible then
				x = x + gap
				cell:ClearAllPoints()
				cell:SetPoint("LEFT", row, "LEFT", x, 0)
				cell:SetWidth(column.width)
				cell:Show()
				x = x + column.width
			else
				cell:Hide()
			end
		end
	end
	if frame.empty then
		frame.empty:SetWidth(math.max(120, math.min(520, viewportWidth - 32)))
	end
	if frame.prepareButton and frame.blacklistButton and frame.detailTitle and frame.detailBody then
		local buttonWidth = viewportWidth < 560 and 150 or 178
		local blacklistWidth = viewportWidth < 560 and 82 or 92
		local actionGap = 6
		frame.prepareButton:SetWidth(buttonWidth)
		frame.blacklistButton:SetWidth(blacklistWidth)
		frame.blacklistButton:ClearAllPoints()
		frame.blacklistButton:SetPoint("RIGHT", frame.prepareButton, "LEFT", -actionGap, 0)
		frame.prepareHint:SetWidth(buttonWidth)
		local actionWidth = buttonWidth + blacklistWidth + actionGap + 22
		frame.detailTitle:ClearAllPoints()
		frame.detailTitle:SetPoint("TOPLEFT", frame.detail, "TOPLEFT", 10, -8)
		frame.detailTitle:SetPoint("RIGHT", frame.detail, "RIGHT", -actionWidth, 0)
		frame.detailBody:ClearAllPoints()
		frame.detailBody:SetPoint("TOPLEFT", frame.detailTitle, "BOTTOMLEFT", 0, -5)
		frame.detailBody:SetPoint("BOTTOMRIGHT", frame.detail, "BOTTOMRIGHT", -actionWidth, 7)
	end
end

local function CreateRow(index)
	local row = CreateFrame("Button", nil, scan.frame.resultsContent, "BackdropTemplate")
	row:SetHeight(CONSTANTS.ROW_HEIGHT - 2)
	row:SetPoint("TOPLEFT", scan.frame.resultsContent, "TOPLEFT", 2, -2 - (index - 1) * CONSTANTS.ROW_HEIGHT)
	row:SetPoint("RIGHT", scan.frame.resultsContent, "RIGHT", -2, 0)
	if row.SetClipsChildren then
		row:SetClipsChildren(true)
	end
	row.bg = row:CreateTexture(nil, "BACKGROUND")
	row.bg:SetAllPoints()
	row.bg:SetColorTexture(0.055, 0.055, 0.065, index % 2 == 0 and 0.78 or 0.58)
	row.hover = row:CreateTexture(nil, "BORDER")
	row.hover:SetAllPoints()
	row.hover:SetColorTexture(0.95, 0.78, 0.18, 0.10)
	row.hover:Hide()
	row.selected = row:CreateTexture(nil, "BORDER")
	row.selected:SetAllPoints()
	row.selected:SetColorTexture(0.2, 0.55, 0.95, 0.18)
	row.selected:Hide()

	row.icon = row:CreateTexture(nil, "ARTWORK")
	row.icon:SetSize(26, 26)
	row.icon:SetPoint("LEFT", row, "LEFT", 5, 0)
	row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	row.itemText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	row.itemText:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
	row.itemText:SetWidth(118)
	row.itemText:SetJustifyH("LEFT")
	row.itemText:SetWordWrap(false)
	row.itemText:SetMaxLines(1)

	local function Cell(width)
		local cell = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		cell:SetWidth(width)
		cell:SetJustifyH("RIGHT")
		cell:SetWordWrap(false)
		cell:SetMaxLines(1)
		return cell
	end
	row.cost = Cell(64)
	row.quantity = Cell(36)
	row.target = Cell(60)
	row.profit = Cell(64)
	row.roi = Cell(36)
	row.liquidity = Cell(72)
	row.days = Cell(34)
	row.risk = Cell(50)
	row.risk:SetJustifyH("CENTER")
	row.score = Cell(40)
	row.score:SetJustifyH("CENTER")

	row:SetScript("OnEnter", ShowRowTooltip)
	row:SetScript("OnLeave", HideRowTooltip)
	row:SetScript("OnClick", function(self)
		if not self.data or scan.purchase or scan.prepareRefresh or scan.ownCancelCheck then
			return
		end
		if IsModifiedClick and IsModifiedClick("CHATLINK") and self.data.itemLink and HandleModifiedItemClick then
			HandleModifiedItemClick(self.data.itemLink)
			return
		end
		scan.selected = self.data
		Reset:RefreshRows()
		Reset:RefreshSelected()
	end)
	scan.rows[index] = row
	return row
end

function Reset:RefreshRows()
	if not scan.frame then
		return
	end
	SortOpportunities()
	EnsureDefaultSelection()
	for index = 1, #scan.opportunities do
		local result = scan.opportunities[index]
		local row = scan.rows[index] or CreateRow(index)
		if row.data ~= result and GameTooltip and GameTooltip:IsOwned(row) then
			GameTooltip:Hide()
		end
		row.data = result
		row.icon:SetTexture(result.icon or GetItemTexture(result.itemID))
		row.itemText:SetText(result.itemLink or result.name or ("Composant " .. tostring(result.itemID)))
		row.cost:SetText(FormatPrice(result.absorbCost))
		row.quantity:SetText(FormatCompactNumber(result.quantity))
		row.target:SetText(FormatPrice(result.targetPrice))
		row.profit:SetText(FormatPrice(result.profit))
		row.profit:SetTextColor(result.profit > 0 and 0.35 or 1, result.profit > 0 and 1 or 0.3, 0.35, 1)
		row.roi:SetText(string.format("%d%%", math.floor(result.roi * 100 + 0.5)))
		local saleRate = result.saleRate and string.format("%d%%", math.floor(result.saleRate * 100 + 0.5)) or "—"
		row.liquidity:SetText(FormatCompactNumber(result.soldPerDay) .. "/j • " .. saleRate)
		row.days:SetText(FormatDecimal(result.days, 1))
		if result.lifecycleState == "stale" then
			row.risk:SetText("Périmé")
			row.risk:SetTextColor(1, 0.62, 0.2, 1)
		elseif result.absorbCost > Reset:GetEffectiveBudgetCopper() then
			row.risk:SetText("Bloqué")
			row.risk:SetTextColor(1, 0.35, 0.25, 1)
		else
			row.risk:SetText(result.risk)
			row.risk:SetTextColor(result.riskR, result.riskG, result.riskB, 1)
		end
		local score = math.floor(result.score + 0.5)
		row.score:SetText(tostring(score))
		if score >= 70 then
			row.score:SetTextColor(0.35, 1, 0.45, 1)
		elseif score >= 45 then
			row.score:SetTextColor(1, 0.82, 0.25, 1)
		else
			row.score:SetTextColor(1, 0.45, 0.3, 1)
		end
		UpdateRowVisual(row)
		row:Show()
	end
	for index = #scan.opportunities + 1, #scan.rows do
		local row = scan.rows[index]
		if row.data == scan.selected then
			scan.selected = nil
		end
		if GameTooltip and GameTooltip:IsOwned(row) then
			GameTooltip:Hide()
		end
		row.data = nil
		row.mouseOver = false
		row:Hide()
	end
	local viewportHeight = math.max(1, scan.frame.resultsScroll:GetHeight() or 1)
	scan.frame.resultsContent:SetHeight(math.max(viewportHeight, #scan.opportunities * CONSTANTS.ROW_HEIGHT + 4))
	RelayoutResults()
	scan.frame.count:SetText(string.format("%d proposition(s)", #scan.opportunities))
	scan.frame.empty:SetShown(#scan.opportunities == 0)
	if #scan.opportunities == 0 then
		if scan.running then
			scan.frame.empty:SetText("Analyse en cours…")
		elseif scan.completedAt and not IsFresh() then
			scan.frame.empty:SetText("Résultats périmés — relance le scan")
		elseif scan.completedAt then
			scan.frame.empty:SetText("Aucun reset ne respecte tous les garde-fous")
		else
			scan.frame.empty:SetText("Lance un scan pour analyser la profondeur du marché")
		end
	end
	RefreshPauseButton()
	RefreshContinuousButton()
	SetStatus(GetScanSummary())
	self:RefreshSelected()
	RefreshGoldLock()
end

local function RotateCandidates(candidates)
	local total = #candidates
	if total == 0 then
		return candidates
	end
	local state = GetRotationState()
	-- En « Toutes extensions », l'ordre est volontairement fixe : chaque cycle
	-- doit repartir des extensions les plus recentes. La reprise en cours de
	-- liste ne vaut que pour une extension precise, ou elle sert a retenter les
	-- composants laisses de cote par un scan interrompu.
	local pinned = scan.db and scan.db.expansion == "all"
	local startIndex = pinned and 1 or (((state.nextIndex - 1) % total) + 1)
	local rotated = {}
	for offset = 0, total - 1 do
		local sourceIndex = ((startIndex + offset - 1) % total) + 1
		local candidate = candidates[sourceIndex]
		candidate.rotationIndex = sourceIndex
		candidate.rotationOrder = offset + 1
		rotated[#rotated + 1] = candidate
	end
	return rotated
end

local function BuildCandidates()
	local selection = scan.db and scan.db.expansion or "all"
	local catalogIDs, hasCatalog = CollectCatalogItemIDs(selection)
	if hasCatalog then
		local candidates = {}
		for _, itemID in ipairs(catalogIDs) do
			if IsCommodity(itemID) and not IsBlacklisted(itemID) and not IsPurchaseCoolingDown(itemID) then
				candidates[#candidates + 1] = {
					itemID = itemID,
					itemString = "i:" .. tostring(itemID),
				}
			end
		end
		scan.catalogSource = "catalog"
		scan.catalogSelectedCount = #candidates
		if #candidates == 0 then
			return nil, "Aucune commodité du type sélectionné pour cette extension."
		end
		return RotateCandidates(candidates)
	end

	-- Fallback explicite : utilisé seulement si le fichier catalogue est absent ou vide.
	local paths = {}
	local ok = type(TSM_API) == "table" and type(TSM_API.GetGroupPaths) == "function" and pcall(TSM_API.GetGroupPaths, paths)
	if not ok or type(TSM_API.GetGroupItems) ~= "function" then
		return nil, "Catalogue local indisponible et fallback TSM inaccessible."
	end
	local seen = {}
	local candidates = {}
	for _, path in ipairs(paths) do
		local rawItems = {}
		if pcall(TSM_API.GetGroupItems, path, true, rawItems) then
			for _, itemString in ipairs(rawItems) do
				local itemID = GetItemID(itemString)
				if itemID and not seen[itemID] and IsCommodity(itemID) and not IsBlacklisted(itemID) and not IsPurchaseCoolingDown(itemID) then
					seen[itemID] = true
					candidates[#candidates + 1] = {
						itemID = itemID,
						itemString = itemString,
					}
				end
			end
		end
	end
	table.sort(candidates, function(left, right)
		return left.itemID < right.itemID
	end)
	scan.catalogSource = "tsm"
	scan.catalogSelectedCount = #candidates
	return RotateCandidates(candidates)
end

local function AdvanceRotation(candidate, complete)
	local index = candidate and tonumber(candidate.rotationIndex)
	local total = #scan.candidates
	if not index or total <= 0 then
		return
	end
	local state = GetRotationState()
	state.nextIndex = (math.floor(index) % total) + 1
	state.lastItemID = candidate.itemID
	state.lastAttemptAt = GetTime()
	if complete then
		state.lastCompleteAt = state.lastAttemptAt
	end
end

function Reset:SetExpansion(key)
	local option = GetCatalogOption(key)
	if scan.purchase then
		SetStatus("Termine l’achat Reset avant de changer d’extension.", true)
		UpdateCatalogSelector()
		return
	end
	if scan.db.expansion == option.key then
		return
	end
	if scan.running then
		self:StopScan()
	end
	scan.db.expansion = option.key
	scan.catalogSource = nil
	scan.selected = nil
	scan.completedAt = nil
	wipe(scan.candidates)
	wipe(scan.deepCandidates)
	wipe(scan.opportunities)
	wipe(scan.depthCache)
	ClearPriceBaselines()
	UpdateCatalogSelector()
	self:RefreshRows()
	SetStatus(string.format("Extension : %s • %s • %d composants.", option.label, GetCatalogTypeSummary(), scan.catalogSelectedCount))
end

function Reset:SetCatalogType(key, enabled)
	local option = GetCatalogTypeOption(key)
	if scan.purchase then
		UpdateCatalogSelector()
		SetStatus("Termine l’achat Reset avant de changer les types.", true)
		return
	end
	scan.db.catalogTypes[option.key] = enabled == true
	if not scan.db.catalogTypes.raw and not scan.db.catalogTypes.prepared then
		SetStatus("Sélectionne au moins un type de composant.", true)
	end
	if scan.running then
		self:StopScan()
	end
	scan.catalogSource = nil
	scan.selected = nil
	scan.completedAt = nil
	wipe(scan.candidates)
	wipe(scan.deepCandidates)
	wipe(scan.opportunities)
	wipe(scan.depthCache)
	ClearPriceBaselines()
	UpdateCatalogSelector()
	self:RefreshRows()
	if scan.db.catalogTypes.raw or scan.db.catalogTypes.prepared then
		SetStatus(string.format("Types : %s • %d composants.", GetCatalogTypeSummary(), scan.catalogSelectedCount))
	end
end

local function IsThrottleReady()
	return not C_AuctionHouse.IsThrottledMessageSystemReady or C_AuctionHouse.IsThrottledMessageSystemReady()
end

local function IsKnownAuctionError(errorCode)
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

local function GetDeepQueryDelay(limit)
	local now = GetTime()
	while scan.deepQueryTimes[1] and now - scan.deepQueryTimes[1] >= CONSTANTS.DEEP_QUERY_WINDOW do
		table.remove(scan.deepQueryTimes, 1)
	end
	if #scan.deepQueryTimes < (limit or CONSTANTS.DEEP_QUERY_LIMIT) then
		return 0
	end
	return math.max(0, scan.deepQueryTimes[1] + CONSTANTS.DEEP_QUERY_WINDOW - now + 0.05)
end

local function WaitForQuerySlot(timerName, callback, deepQueryLimit)
	if scan.abandonedQuery then
		scan.throttleResume = { timerName = timerName, callback = callback }
		return true
	end
	if not IsThrottleReady() then
		scan.throttleWaitSince = scan.throttleWaitSince or GetTime()
		if GetTime() - scan.throttleWaitSince >= CONSTANTS.THROTTLE_WAIT_TIMEOUT then
			scan.throttleResume = nil
			scan.throttleWaitSince = nil
			if scan.purchase then
				CancelResetPurchase("Throttle AH indisponible : achat abandonné.", true, "stale")
			elseif scan.running then
				Reset:StopScan("Throttle AH indisponible trop longtemps : scan arrêté.")
			else
				Reset:AbortPriorityAction("Throttle AH indisponible : action abandonnée.")
			end
			return true
		end
		scan.throttleResume = { timerName = timerName, callback = callback }
		Schedule(timerName, 0.5, callback)
		return true
	end
	scan.throttleWaitSince = nil
	local delay = deepQueryLimit and GetDeepQueryDelay(deepQueryLimit) or 0
	if delay > 0 then
		Schedule(timerName, delay, callback)
		SetStatus(string.format("Cadence AH prudente • reprise dans %.1f s", delay))
		return true
	end
	return false
end

local function MarkDeepQuerySent()
	scan.deepQueryTimes[#scan.deepQueryTimes + 1] = GetTime()
end

local function ReadOwnedAuctions()
	wipe(scan.ownAuctions)
	wipe(scan.ownAuctionRecords)
	scan.ownAuctionCount = 0
	scan.ownAuctionQuantity = 0
	local count = tonumber(C_AuctionHouse.GetNumOwnedAuctions()) or 0
	local activeStatus = Enum.AuctionStatus and Enum.AuctionStatus.Active or 0
	for index = 1, count do
		local info = C_AuctionHouse.GetOwnedAuctionInfo(index)
		local itemKey = info and info.itemKey
		local itemID = itemKey and tonumber(itemKey.itemID)
		local auctionID = info and tonumber(info.auctionID)
		local quantity = info and tonumber(info.quantity)
		local buyout = info and tonumber(info.buyoutAmount)
		local status = info and info.status
		if itemID and itemID > 0 and quantity and quantity > 0 and buyout and buyout > 0
			and (not status or status == activeStatus)
		then
			local unitPrice = math.floor(buyout + 0.5)
			local records = scan.ownAuctionRecords[itemID] or {}
			records[#records + 1] = {
				auctionID = auctionID,
				quantity = quantity,
				unitPrice = unitPrice,
				timeLeftSeconds = tonumber(info.timeLeftSeconds),
				timeLeft = info.timeLeft,
			}
			scan.ownAuctionRecords[itemID] = records
			local byPrice = scan.ownAuctions[itemID] or {}
			byPrice[unitPrice] = (byPrice[unitPrice] or 0) + quantity
			scan.ownAuctions[itemID] = byPrice
			scan.ownAuctionCount = scan.ownAuctionCount + 1
			scan.ownAuctionQuantity = scan.ownAuctionQuantity + quantity
		end
	end
end

local function GetOwnedAuctionQuantity(itemID)
	local total = 0
	for _, quantity in pairs(scan.ownAuctions[itemID] or {}) do
		total = total + quantity
	end
	return total
end

local FinishOwnAuctionVerification

BeginOwnAuctionCancellation = function(result)
	if scan.ownCancelCheck then
		return
	end
	if scan.abandonedQuery or not IsThrottleReady() then
		scan.ownCancelCheck = { phase = "wait", result = result, itemID = result.itemID }
		scan.throttleResume = {
			timerName = "ownCancelWake",
			callback = function()
				local check = scan.ownCancelCheck
				if check and check.phase == "wait" then
					scan.ownCancelCheck = nil
					BeginOwnAuctionCancellation(check.result)
				end
			end,
		}
		Reset:RefreshRows()
		SetStatus("Annulation verrouillée • attente du signal Blizzard…")
		return
	end
	if type(C_AuctionHouse.CancelAuction) ~= "function" then
		Reset:AbortPriorityAction("Annulation des auctions indisponible : reprise du scan.")
		return
	end
	local auctionIDs = {}
	local seen = {}
	for _, auction in ipairs(scan.ownAuctionRecords[result.itemID] or {}) do
		local auctionID = tonumber(auction.auctionID)
		if auctionID and not seen[auctionID] then
			local canCancel = true
			if type(C_AuctionHouse.CanCancelAuction) == "function" then
				local canCheckOK, allowed = pcall(C_AuctionHouse.CanCancelAuction, auctionID)
				canCancel = canCheckOK and allowed ~= false
			end
			if canCancel then
				seen[auctionID] = true
				auctionIDs[#auctionIDs + 1] = auctionID
			end
		end
	end
	if #auctionIDs == 0 then
		Reset:AbortPriorityAction("Aucune auction annulable trouvée : reprise du scan.")
		return
	end
	local pending = {}
	for _, auctionID in ipairs(auctionIDs) do
		pending[auctionID] = true
	end
	scan.ownCancelCheck = {
		phase = "cancel",
		result = result,
		itemID = result.itemID,
		pending = pending,
		pendingCount = #auctionIDs,
	}
	Reset:RefreshRows()
	SetStatus(string.format("Annulation de %s auction(s) pour cet item…", FormatCompactNumber(#auctionIDs)))
	Schedule("ownCancelTimeout", CONSTANTS.QUERY_TIMEOUT, function()
		FinishOwnAuctionVerification(false)
	end)
	local failed = 0
	for _, auctionID in ipairs(auctionIDs) do
		local ok, cancelResult = pcall(C_AuctionHouse.CancelAuction, auctionID)
		if not ok or cancelResult == false then
			pending[auctionID] = nil
			failed = failed + 1
		end
	end
	scan.ownCancelCheck.pendingCount = #auctionIDs - failed
	if failed > 0 and scan.ownCancelCheck.pendingCount > 0 then
		SetStatus(string.format("Annulation lancée : %d auction(s) en attente, %d refusée(s).", scan.ownCancelCheck.pendingCount, failed), true)
	elseif scan.ownCancelCheck.pendingCount <= 0 then
		FinishOwnAuctionVerification(false)
	end
end

FinishOwnAuctionVerification = function(success)
	local check = scan.ownCancelCheck
	if not check then
		return
	end
	CancelTimer("ownCancelTimeout")
	if check.phase == "cancel" then
		scan.ownCancelCheck = nil
		if success then
			BeginOwnAuctionVerification(check.result)
		else
			Reset:AbortPriorityAction("Annulation non confirmée : reprise du scan.")
		end
		return
	end
	scan.ownCancelCheck = nil
	if not success then
		Reset:AbortPriorityAction("Vérification impossible : reprise du scan.")
		return
	end
	ReadOwnedAuctions()
	local remaining = GetOwnedAuctionQuantity(check.itemID)
	if remaining > 0 then
		Reset:AbortPriorityAction(string.format("Il reste %s unités de tes auctions : reprise du scan.", FormatCompactNumber(remaining)))
		return
	end
	if scan.selected ~= check.result then
		Reset:AbortPriorityAction("La sélection a changé : reprise du scan.")
		return
	end
	check.result.ownAuctionQuantity = 0
	if scan.depthCache[check.itemID] then
		scan.depthCache[check.itemID].ownAuctionQuantity = 0
	end
	check.result.purchaseVerifiedAt = nil
	check.result.lifecycleState = "stale"
	check.result.lifecycleReason = "Tes auctions ont été annulées : actualise les paliers avant l’achat."
	check.result.scanAt = 0
	scan.depthCache[check.itemID] = nil
	Reset:ArmActionCooldown(CONSTANTS.ACTION_LOCK)
	Reset:RefreshRows()
	Reset:FinishOpportunityPause(false)
	SetStatus("Tes auctions sont annulées : clique « Actualiser » après le verrou.")
end

BeginOwnAuctionVerification = function(result)
	if scan.ownCancelCheck then
		return
	end
	if type(C_AuctionHouse.QueryOwnedAuctions) ~= "function"
		or type(C_AuctionHouse.GetNumOwnedAuctions) ~= "function"
		or type(C_AuctionHouse.GetOwnedAuctionInfo) ~= "function"
	then
		Reset:AbortPriorityAction("Lecture des auctions indisponible : reprise du scan.")
		return
	end
	scan.ownCancelCheck = { phase = "verify", result = result, itemID = result.itemID }
	Reset:RefreshRows()
	SetStatus("Vérification de l’annulation de tes auctions…")
	Reset:SendOwnAuctionVerification()
end

function Reset:SendOwnAuctionVerification()
	local check = scan.ownCancelCheck
	if not check or check.phase ~= "verify" then
		return
	end
	if WaitForQuerySlot("ownCancelQuery", function()
		Reset:SendOwnAuctionVerification()
	end) then
		SetStatus("Vérification verrouillée • attente du signal Blizzard…")
		return
	end
	if type(YayaReagentSniperTrace) == "function" then
		YayaReagentSniperTrace("RESET_AH_QUERY", "kind=owned-cancel-check item=%s", tostring(check.itemID))
	end
	local ok = pcall(C_AuctionHouse.QueryOwnedAuctions, SORTS)
	if not ok then
		FinishOwnAuctionVerification(false)
	elseif scan.ownCancelCheck == check then
		Schedule("ownCancelTimeout", CONSTANTS.QUERY_TIMEOUT, function()
			if scan.ownCancelCheck == check then
				FinishOwnAuctionVerification(false)
			end
		end)
	end
end

local function FinishOwnedAuctionQuery(success)
	if not scan.running or scan.phase ~= "owned" then
		return
	end
	CancelTimer("ownedTimeout")
	if not success then
		Reset:StopScan("Impossible de lire tes auctions : scan Reset annulé, relance-le.")
		return
	end
	ReadOwnedAuctions()
	scan.ownAuctionsReady = true
	if scan.sellOnly and Reset:BeginSellPhase(true) then
		return
	end
	scan.phase = "browse"
	if scan.frame then
		scan.frame.scanButton:SetText("Arrêter")
		scan.frame.scanButton:SetEnabled(true)
	end
	Reset:RefreshRows()
	SetStatus(string.format("Scan du marché • %d de tes auctions chargées.", scan.ownAuctionCount))
	Schedule("next", 0, function()
		Reset:ProcessBrowse()
	end)
end

local function ProcessOwnedAuctions()
	if EnforceGoldThreshold() then
		return
	end
	if not scan.running or scan.phase ~= "owned" or scan.ownQuerySent then
		return
	end
	if WaitForQuerySlot("owned", function()
		ProcessOwnedAuctions()
	end) then
		return
	end
	scan.ownQuerySent = true
	local generation = scan.generation
	if type(YayaReagentSniperTrace) == "function" then
		YayaReagentSniperTrace("RESET_AH_QUERY", "kind=owned")
	end
	local ok = pcall(C_AuctionHouse.QueryOwnedAuctions, SORTS)
	if not ok then
		FinishOwnedAuctionQuery(false)
	elseif scan.running and scan.phase == "owned" and scan.generation == generation then
		Schedule("ownedTimeout", CONSTANTS.QUERY_TIMEOUT, function()
			if scan.running and scan.phase == "owned" and scan.generation == generation then
				FinishOwnedAuctionQuery(false)
			end
		end)
	end
end

local function FinishBrowseBatch(timedOut)
	local active = scan.active
	if not active or active.kind ~= "browse" then
		return
	end
	CancelTimer("timeout")
	CancelTimer("settle")
	if timedOut then
		scan.stats.incomplete = scan.stats.incomplete + #active.items
		Reset:StopScan("Scan Reset arrêté : réponse browse ambiguë, relance après récupération AH.")
		return
	else
		local seen = {}
		local resultByID = {}
		local resultSets = {
			C_AuctionHouse.GetBrowseResults and C_AuctionHouse.GetBrowseResults() or {},
			active.addedResults or {},
		}
		for _, results in ipairs(resultSets) do
			-- Blizzard ne garantit pas un tableau dense ici : ipairs peut ignorer
			-- tous les résultats si le premier index est absent.
			for _, info in pairs(results) do
				local itemKey = info and info.itemKey
				if itemKey and active.byID[itemKey.itemID] then
					resultByID[itemKey.itemID] = info
				end
			end
		end
		for _, info in pairs(resultByID) do
			local itemKey = info and info.itemKey
			local candidate = itemKey and active.byID[itemKey.itemID]
			if candidate and not IsBlacklisted(candidate.itemID) then
				seen[candidate.itemID] = true
				scan.stats.browsed = scan.stats.browsed + 1
				if info.minPrice and info.minPrice > 0 and info.totalQuantity and info.totalQuantity > 0 then
					candidate.minPrice = info.minPrice
					candidate.totalQuantity = info.totalQuantity
					local trigger, triggerScore = GetDeepTrigger(candidate)
					candidate.triggerReason = trigger
					candidate.triggerScore = triggerScore
					local deferBaseline = false
					if ResolveTSMData(candidate) then
						if candidate.minPrice >= candidate.referencePrice * scan.db.maxTargetPct / 100 then
							scan.stats.rejected = scan.stats.rejected + 1
						elseif trigger then
							scan.deepCandidates[#scan.deepCandidates + 1] = candidate
							scan.stats.deepQueued = scan.stats.deepQueued + 1
							-- Le plancher n'est retenu qu'apres une lecture profonde reussie :
							-- une analyse interrompue est ainsi retentee au cycle suivant.
							deferBaseline = true
						else
							scan.stats.unchanged = scan.stats.unchanged + 1
						end
					else
						scan.stats.missingData = scan.stats.missingData + 1
					end
					if not deferBaseline then
						-- La reference est retenue meme quand les garde-fous rejettent l'item :
						-- c'est sa chute future qui en fera une cible.
						RememberPrice(candidate.itemID, candidate.minPrice, candidate.totalQuantity)
					end
				else
					scan.stats.noMarket = scan.stats.noMarket + 1
					-- Plus aucune offre : oublier le plancher, sinon le retour d'une vente
					-- ne serait pas vu comme une baisse.
					scan.priceBaseline[candidate.itemID] = nil
				end
			end
		end
		for _, candidate in ipairs(active.items) do
			if not IsBlacklisted(candidate.itemID) and not seen[candidate.itemID] then
				scan.stats.noMarket = scan.stats.noMarket + 1
				scan.priceBaseline[candidate.itemID] = nil
			end
		end
	end
	scan.active = nil
	scan.browseIndex = active.nextIndex
	SortPendingDeepCandidates()
	if type(YayaReagentSniperTrace) == "function" then
		YayaReagentSniperTrace("RESET_BROWSE_BATCH", "mode=%s items=%d browsed=%d deep=%d unchanged=%d no-market=%d missing-tsm=%d above-target=%d", tostring(scan.cycleMode), #active.items, scan.stats.browsed, scan.stats.deepQueued, scan.stats.unchanged, scan.stats.noMarket, scan.stats.missingData, scan.stats.rejected)
	end
	Reset:RefreshRows()
	Schedule("next", 0, function()
		if scan.phase == "sell" then
			Reset:ProcessSell()
			return
		end
		if scan.deepIndex <= #scan.deepCandidates then
			scan.phase = "deep"
			Reset:ProcessDeep()
		else
			Reset:ProcessBrowse()
		end
	end)
end

function Reset:ProcessBrowse()
	if EnforceGoldThreshold() then
		return
	end
	if not scan.running or scan.phase ~= "browse" or scan.active then
		return
	end
	if not scan.frame or not scan.frame:IsShown() then
		self:StopScan()
		return
	end
	if scan.browseIndex > #scan.candidates then
		scan.phase = "deep"
		self:RefreshRows()
		Schedule("next", 0, function()
			Reset:ProcessDeep()
		end)
		return
	end
	if WaitForQuerySlot("next", function()
		Reset:ProcessBrowse()
	end) then
		return
	end
	local items = {}
	local byID = {}
	local keys = {}
	local nextIndex = scan.browseIndex
	while nextIndex <= #scan.candidates and #items < CONSTANTS.BATCH_SIZE do
		local candidate = scan.candidates[nextIndex]
		if not IsBlacklisted(candidate.itemID) then
			local key = C_AuctionHouse.MakeItemKey(candidate.itemID)
			if key then
				items[#items + 1] = candidate
				byID[candidate.itemID] = candidate
				keys[#keys + 1] = key
			end
		end
		nextIndex = nextIndex + 1
	end
	if #keys == 0 then
		scan.browseIndex = nextIndex
		Schedule("next", 0, function()
			Reset:ProcessBrowse()
		end)
		return
	end
	scan.operationGeneration = scan.operationGeneration + 1
	local active = {
		kind = "browse",
		items = items,
		byID = byID,
		nextIndex = nextIndex,
		generation = scan.generation,
		operationGeneration = scan.operationGeneration,
	}
	scan.active = active
	if type(YayaReagentSniperTrace) == "function" then
		YayaReagentSniperTrace("RESET_AH_QUERY", "kind=browse count=%d index=%d", #keys, scan.browseIndex)
	end
	local ok = pcall(C_AuctionHouse.SearchForItemKeys, keys, SORTS)
	if not ok then
		FinishBrowseBatch(true)
	elseif scan.active == active and active.generation == scan.generation then
		Schedule("timeout", CONSTANTS.QUERY_TIMEOUT, function()
			if scan.active == active and active.generation == scan.generation then
				FinishBrowseBatch(true)
			end
		end)
	end
end

local function ReadDepth(active)
	local tiersByPrice = active.tiersByPrice or {}
	local tierByPrice = active.tierByPrice or {}
	local ownByPrice = scan.ownAuctions[active.candidate.itemID] or {}
	local count = C_AuctionHouse.GetNumCommoditySearchResults(active.candidate.itemID)
	local previousCount = tonumber(active.resultCount) or 0
	if count < previousCount then
		wipe(tiersByPrice)
		wipe(tierByPrice)
		wipe(active.tiers)
		active.ownAuctionQuantity = 0
		previousCount = 0
	end
	for index = previousCount + 1, count do
		local info = C_AuctionHouse.GetCommoditySearchResultInfo(active.candidate.itemID, index)
		if info and info.unitPrice and info.unitPrice > 0 and info.quantity and info.quantity > 0 then
			if index == 1 then
				-- Critere d'undercut de TSM : le lot le moins cher contient-il mes
				-- unites ? Si oui je suis en tete de file, quel que soit le nombre de
				-- vendeurs a ce prix. C'est la seule facon de trancher une egalite de
				-- prix, l'ordre interne d'un palier n'etant pas expose.
				active.lowestPrice = info.unitPrice
				active.lowestIsPlayer = (tonumber(info.numOwnerItems) or 0) > 0
					or info.containsOwnerItem == true
			end
			local price = info.unitPrice
			local previousQuantity = tiersByPrice[price] or 0
			local quantity = previousQuantity + info.quantity
			tiersByPrice[price] = quantity
			local ownQuantity = math.min(quantity, ownByPrice[price] or 0)
			local previousOwnQuantity = math.min(previousQuantity, ownByPrice[price] or 0)
			active.ownAuctionQuantity = (active.ownAuctionQuantity or 0)
				+ ownQuantity - previousOwnQuantity
			local effectiveQuantity = quantity - ownQuantity
			local tier = tierByPrice[price]
			if tier then
				tier.quantity = effectiveQuantity
			elseif effectiveQuantity > 0 then
				local insertAt = #active.tiers + 1
				while insertAt > 1 and active.tiers[insertAt - 1].price > price do
					insertAt = insertAt - 1
				end
				tier = { price = price, quantity = effectiveQuantity }
				table.insert(active.tiers, insertAt, tier)
				tierByPrice[price] = tier
			end
		end
	end
	active.tiersByPrice = tiersByPrice
	active.tierByPrice = tierByPrice
	active.resultCount = count
end

local function RemoveOpportunityByItemID(itemID)
	for index = #scan.opportunities, 1, -1 do
		if scan.opportunities[index].itemID == itemID then
			table.remove(scan.opportunities, index)
		end
	end
	if scan.selected and scan.selected.itemID == itemID then
		scan.selected = nil
	end
end

function Reset:BlacklistSelected()
	if scan.purchase or scan.prepareRefresh or scan.ownCancelCheck or scan.continuousPending or scan.pauseRequested then
		return
	end
	if IsBelowGoldThreshold() or (scan.running and not scan.paused) then
		return
	end
	local result = scan.selected
	local itemID = result and tonumber(result.itemID)
	if not itemID or IsBlacklisted(itemID) then
		return
	end
	scan.db.blacklist[tostring(itemID)] = true
	scan.depthCache[itemID] = nil
	RemoveOpportunityByItemID(itemID)
	local nextResult = SelectNextOpportunity(itemID)
	scan.resumeAfterPurchase = nextResult == nil and scan.running and scan.paused or false
	if RefreshBlacklistPanel then
		RefreshBlacklistPanel()
	end
	self:RefreshRows()
	local message = nextResult and "Item blacklisté : prochaine opportunité sélectionnée."
		or (scan.running and scan.paused and "Item blacklisté : le scan est en pause, clique « Reprendre le scan »." or "Item blacklisté.")
	SetStatus(message, scan.running and scan.paused and not nextResult)
end

function Reset:RemoveBlacklistedItem(itemID)
	if scan.purchase or scan.prepareRefresh or scan.ownCancelCheck or scan.continuousPending or scan.pauseRequested then
		return
	end
	itemID = tonumber(itemID)
	if not itemID then
		return
	end
	scan.db.blacklist[tostring(itemID)] = nil
	scan.db.blacklist[itemID] = nil
	scan.depthCache[itemID] = nil
	RemoveOpportunityByItemID(itemID)
	SelectNextOpportunity(itemID)
	if RefreshBlacklistPanel then
		RefreshBlacklistPanel()
	end
	self:RefreshRows()
	SetStatus("Item retiré de la blacklist. Il sera disponible au prochain scan.")
end

local function ReplaceOpportunity(result)
	if not result then
		return
	end
	local selectedItemID = scan.selected and scan.selected.itemID
	local firstIndex
	for index = #scan.opportunities, 1, -1 do
		if scan.opportunities[index].itemID == result.itemID then
			firstIndex = index
			break
		end
	end
	if firstIndex then
		scan.opportunities[firstIndex] = result
	else
		scan.opportunities[#scan.opportunities + 1] = result
	end
	if selectedItemID == result.itemID then
		scan.selected = result
	elseif not scan.selected or scan.selected.lifecycleState == "stale" then
		scan.selected = result
	end
end

local function FinishDeepCandidate(complete)
	local active = scan.active
	if not active or active.kind ~= "deep" then
		return
	end
	CancelTimer("timeout")
	CancelTimer("page")
	scan.active = nil
	scan.stats.deepScanned = scan.stats.deepScanned + 1
	local prepareRefresh = scan.prepareRefresh and scan.prepareRefresh.itemID == active.candidate.itemID and scan.prepareRefresh or nil
	local opportunityChanged = false
	local pauseForOpportunity = false
	if complete and not IsBlacklisted(active.candidate.itemID) then
		local result = EvaluateDepth(active.candidate, active.tiers or {}, active.ownAuctionQuantity or 0)
		if result then
			-- Cette lecture vient d'être déclarée complète par Blizzard : elle est
			-- directement achetable sans imposer un second rescan réseau.
			result.purchaseVerifiedAt = result.scanAt
		end
		scan.depthCache[active.candidate.itemID] = {
			candidate = active.candidate,
			tiers = active.tiers or {},
			ownAuctionQuantity = active.ownAuctionQuantity or 0,
			purchaseVerifiedAt = result and result.purchaseVerifiedAt or nil,
			lowestPrice = active.lowestPrice,
			lowestIsPlayer = active.lowestIsPlayer,
			scanAt = GetTime(),
		}
		if active.candidate.minPrice and active.candidate.minPrice > 0 then
			RememberPrice(active.candidate.itemID, active.candidate.minPrice, active.candidate.totalQuantity)
		end
		if prepareRefresh then
			prepareRefresh.result = result
			prepareRefresh.complete = true
			elseif active.candidate.sellOnly then
				-- Lecture faite pour la phase de vente : le cache de profondeur suffit,
				-- pas d'opportunite d'achat ni de fenetre d'achat de dix secondes.
			elseif result then
			ReplaceOpportunity(result)
			PlayNewOpportunitySound()
			opportunityChanged = true
			pauseForOpportunity = true
		else
			RemoveOpportunityByItemID(active.candidate.itemID)
			scan.stats.rejected = scan.stats.rejected + 1
			opportunityChanged = true
		end
	elseif IsBlacklisted(active.candidate.itemID) then
		scan.depthCache[active.candidate.itemID] = nil
		RemoveOpportunityByItemID(active.candidate.itemID)
		scan.stats.incomplete = scan.stats.incomplete + 1
		if prepareRefresh then
			prepareRefresh.incomplete = true
			prepareRefresh.original.complete = false
		end
	else
		scan.stats.incomplete = scan.stats.incomplete + 1
		if prepareRefresh then
			prepareRefresh.incomplete = true
			prepareRefresh.original.complete = false
		end
	end
	AdvanceRotation(active.candidate, complete)
	scan.deepIndex = scan.deepIndex + 1
	if pauseForOpportunity and not scan.pauseRequested then
		local pauseEndsAt = GetTime() + CONSTANTS.OPPORTUNITY_PAUSE
		scan.opportunityPauseUntil = pauseEndsAt
		scan.opportunityPauseExpired = false
		scan.pauseRequested = true
		Reset:ArmActionCooldown(CONSTANTS.ACTION_LOCK)
		Schedule("opportunityPause", CONSTANTS.OPPORTUNITY_PAUSE, function()
			if scan.opportunityPauseUntil ~= pauseEndsAt then
				return
			end
			scan.opportunityPauseUntil = nil
			scan.opportunityPauseExpired = true
			if not scan.purchase and not scan.prepareRefresh and not scan.ownCancelCheck then
				Reset:FinishOpportunityPause(false)
			end
		end)
	end
	if scan.pauseRequested then
		EnterPause()
		return
	end
	if prepareRefresh
		or opportunityChanged
		or scan.deepIndex > #scan.deepCandidates
		or scan.stats.deepScanned % CONSTANTS.DEEP_UI_REFRESH_EVERY == 0
	then
		Reset:RefreshRows()
	else
		SetStatus(GetScanSummary())
	end
	Schedule("next", CONSTANTS.BETWEEN_QUERIES, function()
		if scan.phase == "sell" then
			Reset:ProcessSell()
		else
			Reset:ProcessDeep()
		end
	end)
end

local function CompletePrepareRefresh()
	local context = scan.prepareRefresh
	local resume = context and context.resume
	scan.prepareRefresh = nil
	scan.running = resume and resume.running or false
	scan.phase = resume and resume.phase or "idle"
	scan.active = resume and resume.active or nil
	scan.deepCandidates = resume and resume.deepCandidates or scan.deepCandidates
	scan.deepIndex = resume and resume.deepIndex or scan.deepIndex
	scan.paused = resume and resume.paused or false
	scan.pauseRequested = false
	scan.pausedActive = resume and resume.pausedActive or nil
	if scan.frame then
		scan.frame.scanButton:SetText(scan.running and "Arrêter" or "Scanner le marché")
		scan.frame.scanButton:SetEnabled(true)
	end
	if not context then
		Reset:RefreshRows()
		return
	end
	if context.result then
		scan.resumeAfterPurchase = false
		context.result.purchaseVerifiedAt = GetTime()
		RemoveOpportunityByItemID(context.itemID)
		scan.opportunities[#scan.opportunities + 1] = context.result
		PlayNewOpportunitySound()
		scan.selected = context.result
		if not resume then
			Schedule("stale", CONSTANTS.MAX_SCAN_AGE, function()
				if not scan.running and scan.selected == context.result then
					Reset:RefreshRows()
				end
			end)
		end
		Reset:ArmActionCooldown(CONSTANTS.ACTION_LOCK)
		Reset:RefreshRows()
		Reset:FinishOpportunityPause(false)
		SetStatus("Paliers actualisés : clique « Acheter le reset » après le verrou.")
	elseif context.incomplete then
		local nextResult = SelectNextOpportunity(context.itemID)
		scan.resumeAfterPurchase = nextResult == nil and resume ~= nil
		Reset:ArmActionCooldown(CONSTANTS.ACTION_LOCK)
		if not nextResult then
			if scan.opportunityPauseUntil or scan.opportunityPauseExpired then
				Reset:FinishOpportunityPause(false)
			else
				Reset:ResumeSuspendedScan()
			end
			Reset:ResumeContinuousAfterAction()
		end
		Reset:RefreshRows()
		SetStatus(nextResult and "Actualisation incomplète : prochaine opportunité sélectionnée." or (resume and "Actualisation incomplète : scan repris." or "Actualisation incomplète : aucun achat lancé."), true)
	else
		RemoveOpportunityByItemID(context.itemID)
		local nextResult = SelectNextOpportunity(context.itemID)
		scan.resumeAfterPurchase = nextResult == nil and resume ~= nil
		Reset:ArmActionCooldown(CONSTANTS.ACTION_LOCK)
		if not nextResult then
			if scan.opportunityPauseUntil or scan.opportunityPauseExpired then
				Reset:FinishOpportunityPause(false)
			else
				Reset:ResumeSuspendedScan()
			end
			Reset:ResumeContinuousAfterAction()
		end
		Reset:RefreshRows()
		SetStatus(nextResult and "Opportunité rejetée : prochaine sélection prête." or (resume and "Opportunité rejetée : scan repris." or "L’opportunité ne respecte plus les garde-fous."), true)
	end
end

local function FinalizeScanFreshness()
	scan.completedAt = GetTime()
end

local function RequestMoreDepth(active)
	if scan.active ~= active or not scan.running or scan.paused then
		return
	end
	if not scan.frame or not scan.frame:IsShown() then
		Reset:StopScan()
		return
	end
	if WaitForQuerySlot("page", function()
		RequestMoreDepth(active)
	end, scan.prepareRefresh and CONSTANTS.DEEP_QUERY_ACTION_LIMIT or CONSTANTS.DEEP_QUERY_LIMIT) then
		return
	end
	if active.pages >= CONSTANTS.MAX_DEEP_PAGES then
		FinishDeepCandidate(false)
		return
	end
	active.waitingForMore = false
	if type(YayaReagentSniperTrace) == "function" then
		YayaReagentSniperTrace("RESET_AH_QUERY", "kind=more item=%s page=%d", tostring(active.candidate.itemID), active.pages)
	end
	MarkDeepQuerySent()
	local ok, hasFullResults = pcall(C_AuctionHouse.RequestMoreCommoditySearchResults, active.candidate.itemID)
	if not ok then
		FinishDeepCandidate(false)
	elseif scan.active == active and active.generation == scan.generation then
		active.pages = active.pages + 1
		if hasFullResults then
			HandleCommodityResults(active.candidate.itemID)
		else
			Schedule("timeout", CONSTANTS.QUERY_TIMEOUT, function()
				if scan.active == active and active.generation == scan.generation then
					FinishDeepCandidate(false)
				end
			end)
		end
	end
end

EnterPause = function(active)
	CancelTimer("next")
	CancelTimer("page")
	CancelTimer("settle")
	CancelTimer("timeout")
	scan.pauseRequested = false
	scan.paused = true
	scan.pausedActive = active
	scan.active = nil
	Reset:RefreshRows()
	if (scan.opportunityPauseUntil or 0) > GetTime() then
		SetStatus("Deal détecté : scan en pause 10 s • action disponible après 0,5 s.")
	else
		SetStatus("Analyse en pause : tu peux acheter une opportunité déjà analysée.")
	end
end

function Reset:TogglePause()
	if not scan.running or scan.prepareRefresh or scan.purchase then
		return
	end
	CancelTimer("opportunityPause")
	scan.opportunityPauseUntil = nil
	scan.opportunityPauseExpired = false
	if scan.paused and scan.phase ~= "deep" then
		self:ResumeSuspendedScan()
		self:RefreshRows()
		SetStatus("Reprise du scan du marché…")
		return
	elseif scan.phase ~= "deep" then
		return
	end
	if scan.paused then
		local active = scan.pausedActive
		scan.paused = false
		scan.pauseRequested = false
		scan.pausedActive = nil
		if active then
			scan.active = active
		end
		self:RefreshRows()
		SetStatus("Reprise de l’analyse des paliers…")
		if active then
			Schedule("page", CONSTANTS.BETWEEN_QUERIES, function()
				if scan.running and not scan.paused and scan.active == active then
					RequestMoreDepth(active)
				end
			end)
		else
			Schedule("next", 0, function()
				if not scan.running or scan.paused then
					return
				end
				Reset:ProcessDeep()
			end)
		end
		return
	end
	if scan.pauseRequested then
		return
	end
	local active = scan.active
	if active and active.kind == "deep" and active.waitingForMore then
		EnterPause(active)
	elseif active then
		scan.pauseRequested = true
		self:RefreshRows()
		SetStatus("Pause demandée : la requête AH en cours va se terminer…")
	else
		EnterPause()
	end
end

-- Oublie les prix planchers : le cycle courant, puis les suivants, repassent en
-- releve profond complet jusqu'a ce qu'une nouvelle reference soit etablie.
function Reset:ForceDeepCycle()
	ClearPriceBaselines()
	scan.forceDeepCycle = true
	scan.cycleMode = "deep"
	if scan.frame and scan.frame.settingsPanel then
		scan.frame.settingsPanel:Hide()
	end
	self:RefreshRows()
	SetStatus(scan.running and "Relevé profond complet repris sur le cycle en cours." or "Prochain cycle : relevé profond complet du catalogue.")
end

function Reset:ToggleContinuous()
	if EnforceGoldThreshold() then
		return
	end
	if scan.purchase or scan.prepareRefresh or scan.ownCancelCheck then
		return
	end
	if scan.db.continuous then
		scan.db.continuous = false
		CancelTimer("continuous")
		scan.continuousPending = false
		if scan.frame and not scan.running then
			scan.frame.scanButton:SetText("Scanner le marché")
			scan.frame.scanButton:SetEnabled(true)
		end
		RefreshContinuousButton()
		SetStatus("Scan continu désactivé.")
		return
	end
	scan.db.continuous = true
	RefreshContinuousButton()
	if not scan.running and not scan.continuousPending then
		self:StartScan()
	else
		SetStatus("Scan continu activé : nouveau cycle à la fin du scan.")
	end
end

function Reset:ProcessDeep()
	if EnforceGoldThreshold() then
		return
	end
	if not scan.running or scan.paused or scan.phase ~= "deep" or scan.active then
		return
	end
	if not scan.frame or not scan.frame:IsShown() then
		self:StopScan()
		return
	end
	if scan.deepIndex > #scan.deepCandidates then
		if scan.prepareRefresh then
			CompletePrepareRefresh()
			return
		end
		-- Le marche des objets a vendre vient d'etre lu : retour a la phase vente.
		if scan.sellStage == "market" then
			scan.phase = "sell"
			scan.sellStage = "targets"
			Schedule("next", 0, function()
				Reset:ProcessSell()
			end)
			return
		end
		if scan.browseIndex <= #scan.candidates then
			scan.phase = "browse"
			Schedule("next", CONSTANTS.BETWEEN_QUERIES, function()
				Reset:ProcessBrowse()
			end)
			return
		end
		-- En mode snipe, un cycle sans aucune baisse est le cas normal : seul un
		-- cycle qui n'a rien pu evaluer du tout signale une vraie anomalie.
		local quietCycle = scan.stats.deepQueued == 0 and scan.stats.unchanged > 0
		local noDeepCandidates = scan.stats.deepQueued == 0 and not quietCycle
		-- Le cycle d'achat est fini : la vente enchaine avant de relancer.
		if not noDeepCandidates and self:BeginSellPhase(false) then
			return
		end
		scan.running = false
		scan.phase = "idle"
		if noDeepCandidates then
			scan.db.continuous = false
		end
		scan.continuousPending = scan.db.continuous
		FinalizeScanFreshness()
		if scan.frame then
			scan.frame.scanButton:SetText(scan.continuousPending and "Relance…" or "Scanner le marché")
			scan.frame.scanButton:SetEnabled(not scan.continuousPending)
		end
		SortOpportunities()
		self:RefreshRows()
		if noDeepCandidates then
			SetStatus(string.format("Aucun candidat deep : %d sans marché • %d sans données TSM • %d au-dessus du seuil.", scan.stats.noMarket, scan.stats.missingData, scan.stats.rejected), true)
			return
		end
		Schedule("stale", CONSTANTS.MAX_SCAN_AGE, function()
			if not scan.running and not IsFresh() then
				Reset:RefreshRows()
			end
		end)
		if scan.db.continuous then
			SetStatus(quietCycle and "Aucune baisse détectée • prochain cycle…" or "Scan terminé — prochain cycle…")
			Schedule("continuous", CONSTANTS.BETWEEN_QUERIES, function()
				scan.continuousPending = false
				if not scan.db.continuous or scan.purchase or scan.running or not scan.frame or not scan.frame:IsShown() then
					if scan.frame then
						scan.frame.scanButton:SetText("Scanner le marché")
						scan.frame.scanButton:SetEnabled(true)
					end
					return
				end
				Reset:StartScan()
			end)
		end
		return
	end
	if WaitForQuerySlot("next", function()
		Reset:ProcessDeep()
	end, scan.prepareRefresh and CONSTANTS.DEEP_QUERY_ACTION_LIMIT or CONSTANTS.DEEP_QUERY_LIMIT) then
		return
	end
	local candidate = scan.deepCandidates[scan.deepIndex]
	if IsBlacklisted(candidate.itemID) then
		scan.deepIndex = scan.deepIndex + 1
		scan.depthCache[candidate.itemID] = nil
		RemoveOpportunityByItemID(candidate.itemID)
		Schedule("next", 0, function()
			Reset:ProcessDeep()
		end)
		return
	end
	local itemKey = C_AuctionHouse.MakeItemKey(candidate.itemID)
	if not itemKey then
		scan.stats.incomplete = scan.stats.incomplete + 1
		if scan.prepareRefresh and scan.prepareRefresh.itemID == candidate.itemID then
			scan.prepareRefresh.incomplete = true
			scan.prepareRefresh.original.complete = false
		end
		AdvanceRotation(candidate, false)
		scan.deepIndex = scan.deepIndex + 1
		Schedule("next", 0, function()
			Reset:ProcessDeep()
		end)
		return
	end
	scan.operationGeneration = scan.operationGeneration + 1
	scan.active = {
		kind = "deep",
		generation = scan.generation,
		operationGeneration = scan.operationGeneration,
		candidate = candidate,
		pages = 1,
		tiers = {},
		tiersByPrice = {},
		tierByPrice = {},
		resultCount = 0,
	}
	if type(YayaReagentSniperTrace) == "function" then
		YayaReagentSniperTrace("RESET_AH_QUERY", "kind=deep item=%s", tostring(candidate.itemID))
	end
	MarkDeepQuerySent()
	local ok = pcall(C_AuctionHouse.SendSearchQuery, itemKey, SORTS, false)
	if not ok then
		FinishDeepCandidate(false)
	elseif scan.active and scan.active.kind == "deep" and scan.active.generation == scan.generation then
		local active = scan.active
		Schedule("timeout", CONSTANTS.QUERY_TIMEOUT, function()
			if scan.active == active and active.generation == scan.generation then
				FinishDeepCandidate(false)
			end
		end)
	end
end

HandleCommodityResults = function(itemID)
	local active = scan.active
	if not active or active.kind ~= "deep" or itemID ~= active.candidate.itemID then
		return
	end
	CancelTimer("timeout")
	ReadDepth(active)
	local ok, full = pcall(C_AuctionHouse.HasFullCommoditySearchResults, active.candidate.itemID)
	if ok and full then
		FinishDeepCandidate(true)
	elseif scan.pauseRequested then
		active.waitingForMore = true
		EnterPause(active)
	else
		active.waitingForMore = true
		Schedule("page", CONSTANTS.BETWEEN_QUERIES, function()
			RequestMoreDepth(active)
		end)
	end
end

-- ---------------------------------------------------------------------------
-- Mode Cancel & Repost
-- ---------------------------------------------------------------------------

IsSellModeEnabled = function()
	if type(YayaReagentSniperSell) ~= "table" or not scan.db then
		return false
	end
	return scan.db.autoCancel == true or scan.db.autoPost == true
end

-- Etat du marche d'un objet, vu depuis le cache de profondeur : les paliers y
-- sont deja tries et purges de mes propres encheres.
local function GetSellMarket(itemID, myPrice)
	local cached = scan.depthCache[itemID]
	if not cached or GetTime() - (cached.scanAt or 0) > CONSTANTS.MAX_SCAN_AGE then
		return nil
	end
	local market = {
		lowestPrice = cached.lowestPrice,
		lowestIsPlayer = cached.lowestIsPlayer,
	}
	local tiers = cached.tiers or {}
	for index = 1, #tiers do
		local tier = tiers[index]
		if tier.quantity and tier.quantity > 0 then
			if not market.lowestOther then
				market.lowestOther = tier.price
			end
			if myPrice and tier.price == myPrice then
				market.hasOtherAtSamePrice = true
			end
			if myPrice and tier.price > myPrice then
				break
			end
		end
	end
	return market
end

-- Objets dont le marche doit etre connu pour decider : ceux que je vends, et
-- ceux que je pourrais remettre en vente depuis mes sacs.
local function CollectSellItemIDs()
	local seen, list = {}, {}
	local function Add(itemID)
		itemID = tonumber(itemID)
		if itemID and itemID > 0 and not seen[itemID] and not IsBlacklisted(itemID) and IsCommodity(itemID) then
			seen[itemID] = true
			list[#list + 1] = itemID
		end
	end
	for itemID in pairs(scan.ownAuctionRecords) do
		Add(itemID)
	end
	for itemID in pairs(scan.sellBagItems or {}) do
		Add(itemID)
	end
	return list
end

local function BuildSellTargets()
	local Sell = YayaReagentSniperSell
	wipe(scan.sellTargets)
	scan.sellIndex = 1
	if not Sell then
		return
	end

	-- Annulations : une cible par enchere.
	if scan.db.autoCancel then
		for itemID, records in pairs(scan.ownAuctionRecords) do
			if not IsBlacklisted(itemID) then
				local itemString = "i:" .. tostring(itemID)
				local operation = Sell.GetAuctioningOperation(itemString)
				for index = 1, #records do
					local record = records[index]
					local market = GetSellMarket(itemID, record.unitPrice)
					if market then
						local repostPrice = Sell.ComputePostPrice({
							itemString = itemString,
							operation = operation,
							marketPrice = market.lowestOther,
						})
						market.targetPrice = repostPrice
						local shouldCancel, reason = Sell.ShouldCancel(record, market, operation, itemString)
						if type(YayaReagentSniperTrace) == "function" then
							YayaReagentSniperTrace(
								"RESET_SELL_CHECK",
								"item=%s mine=%s lowest=%s head=%s target=%s cancel=%s",
								tostring(itemID),
								tostring(record.unitPrice),
								tostring(market.lowestPrice),
								tostring(market.lowestIsPlayer),
								tostring(repostPrice),
								tostring(shouldCancel)
							)
						end
						if shouldCancel then
							scan.sellTargets[#scan.sellTargets + 1] = {
								kind = "cancel",
								itemID = itemID,
								itemString = itemString,
								auctionID = record.auctionID,
								quantity = record.quantity,
								unitPrice = record.unitPrice,
								targetPrice = repostPrice,
								reason = reason,
							}
						end
					end
				end
			end
		end
	end

	-- Mises en vente : ce qui dort dans les sacs, hors reserve de craft.
	if scan.db.autoPost then
		local reservations = Sell.GetCraftingReservations()
		for itemID, entry in pairs(scan.sellBagItems or {}) do
			if not IsBlacklisted(itemID) then
				local itemString = "i:" .. tostring(itemID)
				local operation = Sell.GetAuctioningOperation(itemString)
				local market = GetSellMarket(itemID)
				local quantity = Sell.GetPostQuantity(operation, entry.quantity, itemString, reservations[itemID] or 0)
				if quantity > 0 then
					local price, reason = Sell.ComputePostPrice({
						itemString = itemString,
						operation = operation,
						marketPrice = market and market.lowestOther or nil,
					})
					if price and price > 0 then
						scan.sellTargets[#scan.sellTargets + 1] = {
							kind = "post",
							itemID = itemID,
							itemString = itemString,
							quantity = quantity,
							unitPrice = price,
							marketPrice = market and market.lowestOther or nil,
							duration = Sell.ReadSetting(operation, "duration"),
							location = entry.location,
							hasOperation = operation ~= nil,
							reason = reason,
						}
					end
				end
			end
		end
	end

	-- Les annulations passent avant les mises en vente : une enchere sous-cotee
	-- perd de la valeur a chaque minute, un objet en sac non.
	table.sort(scan.sellTargets, function(left, right)
		if left.kind ~= right.kind then
			return left.kind == "cancel"
		end
		local leftValue = (left.unitPrice or 0) * (left.quantity or 0)
		local rightValue = (right.unitPrice or 0) * (right.quantity or 0)
		if leftValue ~= rightValue then
			return leftValue > rightValue
		end
		return (left.itemID or 0) < (right.itemID or 0)
	end)
end

local function GetSellSummary()
	local cancels, posts = 0, 0
	for index = scan.sellIndex, #scan.sellTargets do
		local target = scan.sellTargets[index]
		if not target.done then
			if target.kind == "cancel" then
				cancels = cancels + 1
			else
				posts = posts + 1
			end
		end
	end
	return cancels, posts
end

local function FinishSellPhase()
	scan.sellStage = nil
	scan.sellQuerySent = false
	scan.running = false
	scan.phase = "idle"
	scan.continuousPending = scan.db.continuous
	FinalizeScanFreshness()
	if scan.frame then
		scan.frame.scanButton:SetText(scan.continuousPending and "Relance…" or "Scanner le marché")
		scan.frame.scanButton:SetEnabled(not scan.continuousPending)
	end
	Reset:RefreshRows()
	if scan.db.continuous then
		SetStatus(scan.sellOnly
			and "Vente terminée • or sous le seuil : prochain cycle de vente…"
			or "Vente terminée — prochain cycle…")
		Schedule("continuous", CONSTANTS.BETWEEN_QUERIES, function()
			scan.continuousPending = false
			if not scan.db.continuous or scan.purchase or scan.running or not scan.frame or not scan.frame:IsShown() then
				if scan.frame then
					scan.frame.scanButton:SetText("Scanner le marché")
					scan.frame.scanButton:SetEnabled(true)
				end
				return
			end
			Reset:StartScan()
		end)
	else
		SetStatus("Vente terminée : plus rien à annuler ni à remettre en vente.")
	end
end

function Reset:GetNextSellTarget()
	while scan.sellIndex <= #scan.sellTargets do
		local target = scan.sellTargets[scan.sellIndex]
		if target and not target.done then
			return target
		end
		scan.sellIndex = scan.sellIndex + 1
	end
	return nil
end

function Reset:GetSellCounts()
	return GetSellSummary()
end

function Reset:ProcessSell()
	if not scan.running or scan.phase ~= "sell" or scan.active or scan.paused then
		return
	end
	if not scan.frame or not scan.frame:IsShown() then
		self:StopScan()
		return
	end
	local stage = scan.sellStage

	if stage == "owned" then
		if scan.sellQuerySent then
			return
		end
		if WaitForQuerySlot("next", function()
			Reset:ProcessSell()
		end) then
			return
		end
		scan.sellQuerySent = true
		if type(YayaReagentSniperTrace) == "function" then
			YayaReagentSniperTrace("RESET_AH_QUERY", "kind=sell-owned")
		end
		local ok = pcall(C_AuctionHouse.QueryOwnedAuctions, SORTS)
		if not ok then
			self:FinishSellOwnedQuery(false)
			return
		end
		local generation = scan.generation
		Schedule("timeout", CONSTANTS.QUERY_TIMEOUT, function()
			if scan.generation == generation and scan.phase == "sell" and scan.sellStage == "owned" then
				Reset:FinishSellOwnedQuery(false)
			end
		end)
		return
	end

	if stage == "market" then
		-- Le marche des objets concernes passe par la file profonde existante :
		-- elle remplit scan.depthCache, qui porte deja les paliers hors mes encheres.
		wipe(scan.deepCandidates)
		scan.deepIndex = 1
		local itemIDs = CollectSellItemIDs()
		for index = 1, #itemIDs do
			local itemID = itemIDs[index]
			local cached = scan.depthCache[itemID]
			if not cached or GetTime() - (cached.scanAt or 0) > CONSTANTS.MAX_SCAN_AGE then
				scan.deepCandidates[#scan.deepCandidates + 1] = {
					itemID = itemID,
					itemString = "i:" .. tostring(itemID),
					sellOnly = true,
				}
			end
		end
		if #scan.deepCandidates == 0 then
			scan.sellStage = "targets"
			Schedule("next", 0, function()
				Reset:ProcessSell()
			end)
			return
		end
		SetStatus(string.format("Vente : lecture du marché de %d objet(s)…", #scan.deepCandidates))
		scan.phase = "deep"
		Schedule("next", 0, function()
			Reset:ProcessDeep()
		end)
		return
	end

	if stage == "targets" then
		BuildSellTargets()
		scan.sellStage = "ready"
		local cancels, posts = GetSellSummary()
		if type(YayaReagentSniperTrace) == "function" then
			YayaReagentSniperTrace("RESET_SELL_TARGETS", "cancel=%d post=%d", cancels, posts)
		end
		if cancels == 0 and posts == 0 then
			FinishSellPhase()
			return
		end
		self:RefreshRows()
		SetStatus(string.format("Vente : %d à annuler • %d à remettre en vente.", cancels, posts))
		return
	end

	if stage == "ready" then
		if not self:GetNextSellTarget() then
			FinishSellPhase()
		end
		return
	end
end

function Reset:FinishSellOwnedQuery(success)
	if scan.phase ~= "sell" or scan.sellStage ~= "owned" then
		return
	end
	CancelTimer("timeout")
	scan.sellQuerySent = false
	if not success then
		self:StopScan("Vente : lecture de tes auctions impossible, scan arrêté.")
		return
	end
	ReadOwnedAuctions()
	scan.sellBagItems = YayaReagentSniperSell and YayaReagentSniperSell.EnumerateSellableBagItems(IsCommodity) or {}
	scan.sellStage = "market"
	Schedule("next", 0, function()
		Reset:ProcessSell()
	end)
end

-- Annulation d'une enchere sous-cotee. C_AuctionHouse.CancelAuction est un appel
-- restreint : il doit partir du clic courant, il ne supporte ni file ni timer.
function Reset:ExecuteSellCancel(target)
	if not target or target.done then
		return
	end
	target.done = true
	if type(C_AuctionHouse.CancelAuction) ~= "function" then
		SetStatus("API d’annulation indisponible.", true)
		self:RefreshRows()
		return
	end
	if type(C_AuctionHouse.CanCancelAuction) == "function" then
		local ok, allowed = pcall(C_AuctionHouse.CanCancelAuction, target.auctionID)
		if ok and allowed == false then
			SetStatus("Cette enchère ne peut plus être annulée.", true)
			self:RefreshRows()
			return
		end
	end
	local ok = pcall(C_AuctionHouse.CancelAuction, target.auctionID)
	self:ArmActionCooldown(CONSTANTS.ACTION_LOCK)
	if not ok then
		SetStatus("Annulation refusée par Blizzard : enchère laissée en place.", true)
	else
		local name = GetItemName(target.itemID) or ("objet " .. tostring(target.itemID))
		SetStatus(string.format("Annulation envoyée : %s ×%d. L’objet revient par courrier.", name, target.quantity or 0))
		if type(YayaReagentSniperTrace) == "function" then
			YayaReagentSniperTrace("RESET_SELL_CANCEL", "item=%s auction=%s price=%s", tostring(target.itemID), tostring(target.auctionID), tostring(target.unitPrice))
		end
	end
	self:RefreshRows()
	Schedule("next", CONSTANTS.BETWEEN_QUERIES, function()
		Reset:ProcessSell()
	end)
end

-- Mise en vente d'une pile des sacs. PostCommodity est restreint de la meme
-- facon, et renvoie true quand Blizzard veut sa propre confirmation.
function Reset:ExecuteSellPost(target)
	if not target or target.done then
		return
	end
	if type(C_AuctionHouse.PostCommodity) ~= "function" then
		target.done = true
		SetStatus("API de mise en vente indisponible.", true)
		self:RefreshRows()
		return
	end
	local location = target.location
	if not location or type(location.IsValid) ~= "function" or not location:IsValid() then
		target.done = true
		SetStatus("L’objet n’est plus à sa place dans les sacs : cible abandonnée.", true)
		self:RefreshRows()
		return
	end
	local duration = tonumber(target.duration) or 2
	duration = math.max(1, math.min(3, math.floor(duration)))
	local quantity = math.max(1, math.floor(tonumber(target.quantity) or 1))
	local unitPrice = math.floor(tonumber(target.unitPrice) or 0)
	if unitPrice <= 0 then
		target.done = true
		SetStatus("Prix de mise en vente indisponible : cible abandonnée.", true)
		self:RefreshRows()
		return
	end
	if type(C_AuctionHouse.CalculateCommodityDeposit) == "function" then
		local ok, deposit = pcall(C_AuctionHouse.CalculateCommodityDeposit, target.itemID, duration, quantity)
		deposit = ok and tonumber(deposit) or 0
		local money = type(GetMoney) == "function" and GetMoney() or 0
		if deposit > 0 and deposit > money then
			target.done = true
			SetStatus(string.format("Dépôt de %s requis : or insuffisant pour cette mise en vente.", FormatPrice(deposit)), true)
			self:RefreshRows()
			return
		end
	end
	target.done = true
	local ok, needsConfirmation = pcall(C_AuctionHouse.PostCommodity, location, duration, quantity, unitPrice)
	self:ArmActionCooldown(CONSTANTS.ACTION_LOCK)
	local name = GetItemName(target.itemID) or ("objet " .. tostring(target.itemID))
	if not ok then
		SetStatus("Mise en vente refusée par Blizzard : objet laissé en sac.", true)
	elseif needsConfirmation then
		SetStatus(string.format("%s : Blizzard demande une confirmation, valide sa fenêtre.", name), true)
	else
		SetStatus(string.format("Mise en vente : %s ×%d à %s/u pour %d h.", name, quantity, FormatPrice(unitPrice), YayaReagentSniperSell.GetDurationHours(duration)))
	end
	if type(YayaReagentSniperTrace) == "function" then
		YayaReagentSniperTrace("RESET_SELL_POST", "item=%s qty=%d price=%s confirm=%s", tostring(target.itemID), quantity, tostring(unitPrice), tostring(needsConfirmation))
	end
	self:RefreshRows()
	Schedule("next", CONSTANTS.BETWEEN_QUERIES, function()
		Reset:ProcessSell()
	end)
end

function Reset:BeginSellPhase(auctionsAreFresh)
	if not IsSellModeEnabled() then
		return false
	end
	scan.phase = "sell"
	scan.sellQuerySent = false
	wipe(scan.sellTargets)
	scan.sellIndex = 1
	if auctionsAreFresh then
		-- Les encheres viennent d'etre lues : inutile de redemander.
		scan.sellBagItems = YayaReagentSniperSell and YayaReagentSniperSell.EnumerateSellableBagItems(IsCommodity) or {}
		scan.sellStage = "market"
	else
		scan.sellStage = "owned"
	end
	if scan.frame then
		scan.frame.scanButton:SetText("Arrêter")
		scan.frame.scanButton:SetEnabled(true)
	end
	SetStatus("Vente : vérification de tes auctions et de tes sacs…")
	Schedule("next", 0, function()
		Reset:ProcessSell()
	end)
	return true
end

function Reset:StopScan(message)
	if scan.purchase and scan.purchase.mode ~= "quarantine" and scan.purchase.mode ~= "quote-quarantine" then
		CancelResetPurchase(message or "Achat Reset annulé.", true)
		message = nil
	elseif scan.purchase then
		message = nil
	end
	CancelTimer("continuous")
	scan.continuousPending = false
	scan.sellStage = nil
	scan.sellQuerySent = false
	scan.resumeContinuousAfterAction = false
	scan.resumeAfterPurchase = false
	scan.actionCooldownUntil = 0
	scan.throttleWaitSince = nil
	scan.abandonedQuery = nil
	local interrupted = scan.active or scan.pausedActive
	if interrupted and interrupted.kind == "deep" then
		AdvanceRotation(interrupted.candidate, false)
	end
	CancelTimer("ownCancelTimeout")
	scan.ownCancelCheck = nil
	scan.paused = false
	scan.pauseRequested = false
	scan.opportunityPauseUntil = nil
	scan.opportunityPauseExpired = false
	scan.pausedActive = nil
	if not scan.running and not scan.active then
		CancelScanTimers()
		if scan.frame then
			scan.frame.scanButton:SetText("Scanner le marché")
			scan.frame.scanButton:SetEnabled(true)
		end
		self:RefreshRows()
		return
	end
	scan.running = false
	scan.startPending = false
	scan.phase = "idle"
	scan.ownQuerySent = false
	scan.ownAuctionsReady = false
	scan.active = nil
	scan.prepareRefresh = nil
	scan.generation = scan.generation + 1
	CancelScanTimers()
	if scan.frame then
		scan.frame.scanButton:SetText("Scanner le marché")
		scan.frame.scanButton:SetEnabled(true)
	end
	self:RefreshRows()
	if interrupted then
		self:ArmActionCooldown(CONSTANTS.QUOTE_QUARANTINE_SECONDS)
	end
	if message then
		SetStatus(message)
	end
end

function Reset:StartScan(ignoreActionCooldown)
	if EnforceGoldThreshold() then
		return
	end
	if not ignoreActionCooldown and GetTime() < (scan.actionCooldownUntil or 0) then
		SetStatus("Hôtel des ventes en récupération : attends la fin du verrou.", true)
		return
	end
	if scan.startPending then
		SetStatus("Préparation du scan en cours…")
		return
	end
	if scan.purchase then
		SetStatus("Attends la fin de l’achat Reset avant de scanner.", true)
		return
	end
	if scan.running then
		self:StopScan("Scan arrêté.")
		return
	end
	if scan.controller and scan.controller.isPurchaseBusy and scan.controller.isPurchaseBusy() then
		SetStatus("Termine l’achat en cours avant le scan Reset.", true)
		return
	end
	local required = {
		"MakeItemKey",
		"SearchForItemKeys",
		"SendSearchQuery",
		"GetNumCommoditySearchResults",
		"GetCommoditySearchResultInfo",
		"HasFullCommoditySearchResults",
		"RequestMoreCommoditySearchResults",
		"QueryOwnedAuctions",
		"GetNumOwnedAuctions",
		"GetOwnedAuctionInfo",
	}
	for _, method in ipairs(required) do
		if type(C_AuctionHouse[method]) ~= "function" then
			SetStatus("API Blizzard indisponible : " .. method .. ".", true)
			return
		end
	end
	local candidates, errorMessage = BuildCandidates()
	if not candidates or #candidates == 0 then
		SetStatus(errorMessage or "Aucun composant de récolte trouvé pour cette sélection.", true)
		return
	end
	if type(YayaReagentSniperTrace) == "function" then
		YayaReagentSniperTrace("RESET_SCAN_START", "candidates=%d expansion=%s", #candidates, tostring(scan.db and scan.db.expansion))
	end
	if scan.controller and scan.controller.stopSniper then
		scan.controller.stopSniper()
	end
	local refreshMinutes = tonumber(scan.db.deepRefreshMinutes) or 0
	if scan.forceDeepCycle then
		ClearPriceBaselines()
		scan.forceDeepCycle = false
	elseif refreshMinutes > 0 and scan.baselineStartedAt and GetTime() - scan.baselineStartedAt >= refreshMinutes * 60 then
		ClearPriceBaselines()
	end
	-- Les prix planchers survivent au cycle : c'est leur presence qui fait passer
	-- le scan du releve profond au snipe des baisses.
	scan.cycleMode = next(scan.priceBaseline) and "snipe" or "deep"
	if scan.cycleMode == "deep" then
		scan.baselineStartedAt = GetTime()
	end
	scan.generation = scan.generation + 1
	CancelScanTimers()
	if not ignoreActionCooldown then
		scan.actionCooldownUntil = 0
	end
	scan.abandonedQuery = nil
	scan.resumeContinuousAfterAction = false
	wipe(scan.depthCache)
	wipe(scan.bagCounts)
	wipe(scan.deepCandidates)
	wipe(scan.ownAuctions)
	wipe(scan.ownAuctionRecords)
	scan.ownAuctionCount = 0
	scan.ownAuctionQuantity = 0
	scan.ownQuerySent = false
	scan.ownAuctionsReady = false
	scan.ownCancelCheck = nil
	scan.paused = false
	scan.pauseRequested = false
	scan.opportunityPauseUntil = nil
	scan.opportunityPauseExpired = false
	scan.pausedActive = nil
	scan.resumeAfterPurchase = false
	scan.completedAt = nil
	scan.sellOnly = IsSellModeEnabled() and IsBelowGoldThreshold() or false
	scan.sellStage = nil
	scan.sellQuerySent = false
	wipe(scan.sellTargets)
	scan.sellIndex = 1
	scan.candidates = candidates
	scan.browseIndex = 1
	scan.deepIndex = 1
	scan.active = nil
	scan.phase = "starting"
	scan.running = true
	scan.startPending = true
	ResetStats()
	scan.frame.scanButton:SetText("Préparation…")
	scan.frame.scanButton:SetEnabled(false)
	for _, result in ipairs(scan.opportunities) do
		result.lifecycleState = "stale"
		result.lifecycleReason = "Nouveau scan en cours : prix à revalider."
		result.scanAt = 0
		result.purchaseVerifiedAt = nil
	end
	self:RefreshRows()
	SetStatus(string.format("Préparation du %s • %d candidats au pré-scan…", scan.cycleMode == "snipe" and "cycle snipe" or "cycle profond", #candidates))
	local generation = scan.generation
	Schedule("start", CONSTANTS.START_SETTLE_DELAY, function()
		if not scan.startPending or not scan.running or scan.generation ~= generation then
			return
		end
		scan.startPending = false
		scan.phase = "owned"
		scan.frame.scanButton:SetText("Lecture de tes auctions…")
		scan.frame.scanButton:SetEnabled(false)
		Reset:RefreshRows()
		SetStatus("Lecture de tes auctions avant le scan…")
		ProcessOwnedAuctions()
	end)
end

function Reset:RebuildFromCache()
	wipe(scan.bagCounts)
	wipe(scan.opportunities)
	for _, cached in pairs(scan.depthCache) do
		if not IsBlacklisted(cached.candidate.itemID) and GetTime() - cached.scanAt <= CONSTANTS.MAX_SCAN_AGE then
			local result = EvaluateDepth(cached.candidate, cached.tiers, cached.ownAuctionQuantity or 0)
			if result then
				result.scanAt = cached.scanAt
				result.purchaseVerifiedAt = cached.purchaseVerifiedAt
				scan.opportunities[#scan.opportunities + 1] = result
			end
		end
	end
	if scan.selected then
		local selectedID = scan.selected.itemID
		scan.selected = nil
		for _, result in ipairs(scan.opportunities) do
			if result.itemID == selectedID then
				scan.selected = result
				break
			end
		end
	end
	self:RefreshRows()
end

function Reset:ReleaseAbandonedQuery(event, value)
	local abandoned = scan.abandonedQuery
	if not abandoned then
		return false
	end
	if abandoned.operationGeneration ~= scan.operationGeneration then
		return false
	end
	local matches = abandoned.kind == "browse" and (
		event == "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED"
		or event == "AUCTION_HOUSE_BROWSE_FAILURE"
	) or abandoned.kind == "deep" and (
		event == "COMMODITY_SEARCH_RESULTS_UPDATED"
		or event == "COMMODITY_SEARCH_RESULTS_ADDED"
	) and tonumber(value) == tonumber(abandoned.itemID)
	if not matches then
		return false
	end
	CancelTimer("actionDrainTimeout")
	scan.abandonedQuery = nil
	local resume = scan.throttleResume
	scan.throttleResume = nil
	if resume and resume.callback then
		Schedule(resume.timerName or "next", 0, resume.callback)
	end
	return true
end

function Reset:OnEvent(event, ...)
	if not scan.frame or (not scan.frame:IsShown() and not scan.purchase and not scan.abandonedQuery) then
		return
	end
	if event == "AUCTION_HOUSE_CLOSED" then
		if scan.purchase then
			CancelResetPurchase(nil, true, "stale")
		end
		CancelScanTimers()
		scan.generation = scan.generation + 1
		for _, result in ipairs(scan.opportunities) do
			InvalidateResetOpportunity(result, "Hôtel des ventes fermé : résultat à rescanner.")
		end
		wipe(scan.depthCache)
		ClearPriceBaselines()
		scan.selected = nil
		scan.completedAt = nil
		self:StopScan()
		self:RefreshRows()
		SetStatus("Hôtel des ventes fermé : achats annulés et résultats invalidés.", true)
		return
	end
	if HandleResetPurchaseEvent(event, ...) then
		return
	end
	if self:ReleaseAbandonedQuery(event, ...) then
		return
	end
	if event == "AUCTION_CANCELED" then
		local auctionID = tonumber(...)
		local check = scan.ownCancelCheck
		if check and check.phase == "cancel" and check.pending[auctionID] then
			check.pending[auctionID] = nil
			check.pendingCount = math.max(0, (check.pendingCount or 1) - 1)
			if check.pendingCount == 0 then
				FinishOwnAuctionVerification(true)
			end
		end
		if scan.phase == "sell" then
			self:RefreshRows()
			Schedule("next", 0, function()
				Reset:ProcessSell()
			end)
		end
		return
	end
	if event == "AUCTION_HOUSE_AUCTION_CREATED" or event == "AUCTION_MULTISELL_FAILURE" then
		wipe(scan.bagCounts)
		if scan.phase == "sell" then
			scan.sellBagItems = YayaReagentSniperSell and YayaReagentSniperSell.EnumerateSellableBagItems(IsCommodity) or scan.sellBagItems
			self:RefreshRows()
			Schedule("next", 0, function()
				Reset:ProcessSell()
			end)
		end
		return
	end
	if event == "OWNED_AUCTIONS_UPDATED" then
		if scan.ownCancelCheck then
			if scan.ownCancelCheck.phase == "cancel" then
				ReadOwnedAuctions()
				if GetOwnedAuctionQuantity(scan.ownCancelCheck.itemID) <= 0 then
					scan.ownCancelCheck.pendingCount = 0
					FinishOwnAuctionVerification(true)
				end
			elseif scan.ownCancelCheck.phase == "verify" then
				FinishOwnAuctionVerification(true)
			end
		elseif scan.running and scan.phase == "sell" and scan.sellStage == "owned" then
			self:FinishSellOwnedQuery(true)
		elseif scan.running and scan.phase == "owned" then
			FinishOwnedAuctionQuery(true)
		end
		return
	end
	if event == "PLAYER_MONEY" then
		if EnforceGoldThreshold() then
			return
		end
		if (scan.frame and scan.frame:IsShown()) or scan.running or scan.purchase then
			self:RefreshRows()
		end
		return
	end
	if event == "BAG_UPDATE_DELAYED" then
		if not ((scan.frame and scan.frame:IsShown()) or scan.running or scan.purchase) then
			return
		end
		wipe(scan.bagCounts)
		if not scan.running and not scan.purchase then
			self:RebuildFromCache()
		else
			self:RefreshRows()
		end
		return
	end
	if event == "AUCTION_HOUSE_THROTTLED_MESSAGE_DROPPED" then
		scan.throttleDrops = scan.throttleDrops + 1
		if type(YayaReagentSniperTrace) == "function" then
			YayaReagentSniperTrace("RESET_AH_THROTTLE", "message dropped count=%d", scan.throttleDrops)
		end
		if scan.abandonedQuery then
			self:HandleDrainTimeout()
		elseif scan.purchase and (scan.purchase.confirmed or scan.purchase.mode == "quarantine") then
			CancelResetPurchase("Confirmation incertaine après abandon du message AH.", true, "uncertain")
		elseif scan.purchase and scan.purchase.started then
			CancelResetPurchase("Message d’achat abandonné : résultat à rescanner.", true, "stale")
		elseif scan.active and scan.active.kind == "browse" then
			FinishBrowseBatch(true)
		elseif scan.active and scan.active.kind == "deep" then
			FinishDeepCandidate(false)
		end
		return
	elseif event == "AUCTION_HOUSE_THROTTLED_SYSTEM_READY" then
		if scan.abandonedQuery then
			return
		end
		scan.throttleWaitSince = nil
		scan.throttleBusySince = nil
		local resume = scan.throttleResume
		scan.throttleResume = nil
		if resume and resume.callback then
			Schedule(resume.timerName or "next", 0, resume.callback)
		elseif scan.running and not scan.active and not scan.paused then
			Schedule("next", 0, function()
				if scan.phase == "owned" then
					ProcessOwnedAuctions()
				elseif scan.phase == "browse" then
					Reset:ProcessBrowse()
				elseif scan.phase == "deep" then
					Reset:ProcessDeep()
					elseif scan.phase == "sell" then
						Reset:ProcessSell()
				end
			end)
		end
		self:RefreshRows()
		if scan.controller and scan.controller.updateSniperView then
			scan.controller.updateSniperView()
		end
		return
	end
	local isAuctionError = event == "AUCTION_HOUSE_SHOW_ERROR"
		or (event == "UI_ERROR_MESSAGE" and IsKnownAuctionError(...))
	if isAuctionError
		and (scan.purchase or scan.active)
	then
		if scan.purchase and (scan.purchase.confirmed or scan.purchase.mode == "quarantine") then
			CancelResetPurchase("Erreur AH après confirmation : issue incertaine.", true, "uncertain")
		elseif scan.purchase and scan.purchase.started then
			CancelResetPurchase("Erreur AH avant cotation : réponse tardive mise en quarantaine.", true, "quote-uncertain")
		elseif scan.active and scan.active.kind == "browse" then
			FinishBrowseBatch(true)
		elseif scan.active and scan.active.kind == "deep" then
			FinishDeepCandidate(false)
		end
		return
	end
	if not scan.running then
		return
	end
	if event == "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED" or event == "AUCTION_HOUSE_BROWSE_RESULTS_ADDED" then
		if scan.active and scan.active.kind == "browse" then
			if event == "AUCTION_HOUSE_BROWSE_RESULTS_ADDED" then
				scan.active.addedResults = scan.active.addedResults or {}
				local browseResults = C_AuctionHouse.GetBrowseResults and C_AuctionHouse.GetBrowseResults() or {}
				for _, info in pairs(browseResults) do
					local itemKey = info and info.itemKey
					if itemKey and scan.active.byID[itemKey.itemID] then
						scan.active.addedResults[itemKey.itemID] = info
					end
				end
			else
				local active = scan.active
				Schedule("settle", 0.10, function()
					if scan.active == active and active.generation == scan.generation then
						FinishBrowseBatch(false)
					end
				end)
			end
		end
	elseif event == "AUCTION_HOUSE_BROWSE_FAILURE" then
		if scan.active and scan.active.kind == "browse" then
			FinishBrowseBatch(true)
		end
	elseif event == "COMMODITY_SEARCH_RESULTS_UPDATED" or event == "COMMODITY_SEARCH_RESULTS_ADDED" then
		HandleCommodityResults(...)
	end
end

local function CreateHeader(parent, text, x, width, align)
	local label = parent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	label:SetPoint("LEFT", parent, "LEFT", x, 0)
	label:SetWidth(width)
	label:SetJustifyH(align or "RIGHT")
	label:SetWordWrap(false)
	label:SetMaxLines(1)
	label:SetText(text)
	return label
end

local function CreateSetting(parent, label, x, width)
	local holder = CreateFrame("Frame", nil, parent)
	holder:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -8)
	holder:SetSize(width, 42)
	holder.label = holder:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	holder.label:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, 0)
	holder.label:SetWidth(width)
	holder.label:SetJustifyH("LEFT")
	holder.label:SetWordWrap(false)
	holder.label:SetMaxLines(1)
	holder.label:SetText(label)
	holder.input = CreateFrame("EditBox", nil, holder, "InputBoxTemplate")
	holder.input:SetPoint("TOPLEFT", holder.label, "BOTTOMLEFT", 4, -2)
	holder.input:SetSize(width - 8, 22)
	holder.input:SetAutoFocus(false)
	holder.input:SetNumeric(true)
	holder.input:SetMaxLetters(9)
	holder.input:SetJustifyH("RIGHT")
	return holder
end

local function CreateUI(parent)
	if scan.frame then
		return
	end
	local frame = CreateFrame("Frame", addonName .. "ResetFrame", parent, "BackdropTemplate")
	frame:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -78)
	frame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -16, 16)
	frame:SetBackdrop({
		bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = true,
		tileSize = 16,
		edgeSize = 12,
		insets = { left = 2, right = 2, top = 2, bottom = 2 },
	})
	frame:SetBackdropColor(0.025, 0.03, 0.04, 0.97)
	frame:Hide()

	frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	frame.title:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -13)
	frame.title:SetText("Reset de marché")
	frame.subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	frame.subtitle:SetPoint("TOPLEFT", frame.title, "BOTTOMLEFT", 0, -3)
	frame.subtitle:SetPoint("RIGHT", frame, "RIGHT", -270, 0)
	frame.subtitle:SetJustifyH("LEFT")
	frame.subtitle:SetWordWrap(false)
	frame.subtitle:SetMaxLines(1)
	frame.subtitle:SetText("Catalogue composants × profondeur réelle de l’HV × liquidité TSM")

	frame.settingsButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	frame.settingsButton:SetSize(104, 26)
	frame.settingsButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -16, -14)
	frame.settingsButton:SetText("Paramètres")
	frame.scanButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	frame.scanButton:SetSize(150, 26)
	frame.scanButton:SetPoint("RIGHT", frame.settingsButton, "LEFT", -8, 0)
	frame.scanButton:SetText("Scanner le marché")
	frame.scanButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	frame.scanButton:SetScript("OnClick", function(_, button)
		if button == "RightButton" then
			Reset:ForceDeepCycle()
			if not scan.running then
				Reset:StartScan()
			end
			return
		end
		Reset:StartScan()
	end)
	frame.scanButton:SetScript("OnEnter", function(button)
		GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
		GameTooltip:AddLine(scan.running and "Arrêter le scan" or "Scanner le marché", 1, 0.82, 0.25)
		GameTooltip:AddLine("Le premier cycle relève le prix plancher de chaque composant et analyse leurs paliers. Les cycles suivants ne réanalysent que les marchés qui ont bougé.", 0.85, 0.85, 0.85, true)
		GameTooltip:AddLine("Clic droit : repartir sur un relevé profond complet.", 0.35, 1, 0.45, true)
		GameTooltip:Show()
	end)
	frame.scanButton:SetScript("OnLeave", function(button)
		if GameTooltip:IsOwned(button) then
			GameTooltip:Hide()
		end
	end)
	frame.pauseButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	frame.pauseButton:SetSize(112, 26)
	frame.pauseButton:SetPoint("RIGHT", frame.scanButton, "LEFT", -8, 0)
	frame.pauseButton:SetText("Pause")
	frame.pauseButton:SetScript("OnClick", function()
		Reset:TogglePause()
	end)
	frame.pauseButton:SetScript("OnEnter", function(button)
		GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
		if scan.paused then
			GameTooltip:AddLine("Reprendre l’analyse", 0.35, 1, 0.45)
			GameTooltip:AddLine("La reprise continue au composant où le scan s’est arrêté.", 0.85, 0.85, 0.85, true)
		elseif scan.pauseRequested then
			GameTooltip:AddLine("Pause en attente", 1, 0.82, 0.25)
			GameTooltip:AddLine("La requête AH en cours se termine avant la pause.", 0.85, 0.85, 0.85, true)
		else
			GameTooltip:AddLine("Mettre l’analyse en pause", 1, 0.82, 0.25)
			GameTooltip:AddLine("Permet de sélectionner une opportunité déjà analysée et de l’acheter.", 0.85, 0.85, 0.85, true)
		end
		GameTooltip:Show()
	end)
	frame.pauseButton:SetScript("OnLeave", function(button)
		if GameTooltip:IsOwned(button) then
			GameTooltip:Hide()
		end
	end)
	frame.continuousButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	frame.continuousButton:SetSize(112, 26)
	frame.continuousButton:SetPoint("RIGHT", frame.pauseButton, "LEFT", -8, 0)
	frame.continuousButton:SetText("Scan continu")
	frame.continuousButton:SetScript("OnClick", function()
		Reset:ToggleContinuous()
	end)
	frame.continuousButton:SetScript("OnEnter", function(button)
		GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
		GameTooltip:AddLine(scan.db.continuous and "Scan continu activé" or "Activer le scan continu", 1, 0.82, 0.25)
		GameTooltip:AddLine("À la fin du scan, relance automatiquement un nouveau cycle.", 0.85, 0.85, 0.85, true)
		GameTooltip:Show()
	end)
	frame.continuousButton:SetScript("OnLeave", function(button)
		if GameTooltip:IsOwned(button) then
			GameTooltip:Hide()
		end
	end)

	frame.expansionLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	frame.expansionLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -51)
	frame.expansionLabel:SetWidth(52)
	frame.expansionLabel:SetJustifyH("LEFT")
	frame.expansionLabel:SetText("Extension")
	frame.expansionDropdown = CreateFrame("Frame", nil, frame, "UIDropDownMenuTemplate")
	frame.expansionDropdown:SetPoint("LEFT", frame.expansionLabel, "RIGHT", -12, 0)
	UIDropDownMenu_SetWidth(frame.expansionDropdown, 142)
	UIDropDownMenu_Initialize(frame.expansionDropdown, function(_, level)
		for _, option in ipairs(CATALOG_OPTIONS) do
			local optionKey, optionLabel = option.key, option.label
			local info = UIDropDownMenu_CreateInfo()
			info.text = optionLabel
			info.value = optionKey
			info.checked = scan.db.expansion == optionKey
			info.func = function()
				Reset:SetExpansion(optionKey)
			end
			UIDropDownMenu_AddButton(info, level)
		end
	end)
	frame.catalogCount = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	frame.catalogCount:SetPoint("LEFT", frame.expansionDropdown, "RIGHT", -7, 0)
	frame.catalogCount:SetWidth(112)
	frame.catalogCount:SetJustifyH("LEFT")
	frame.catalogCount:SetWordWrap(false)
	frame.catalogCount:SetMaxLines(1)
	frame.typeLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	frame.typeLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -75)
	frame.typeLabel:SetWidth(34)
	frame.typeLabel:SetJustifyH("LEFT")
	frame.typeLabel:SetText("Types")
	local function CreateCatalogTypeCheck(key, label, x)
		local check = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
		check:SetSize(24, 24)
		check:SetPoint("TOPLEFT", frame, "TOPLEFT", x, -70)
		check.label = check:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		check.label:SetPoint("LEFT", check, "RIGHT", 2, 0)
		check.label:SetWidth(106)
		check.label:SetJustifyH("LEFT")
		check.label:SetWordWrap(false)
		check.label:SetMaxLines(1)
		check.label:SetText(label)
		check:SetScript("OnClick", function(button)
			Reset:SetCatalogType(key, button:GetChecked())
		end)
		return check
	end
	frame.rawTypeCheck = CreateCatalogTypeCheck("raw", GetCatalogTypeOption("raw").label, 54)
	frame.preparedTypeCheck = CreateCatalogTypeCheck("prepared", GetCatalogTypeOption("prepared").label, 177)

	frame.status = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	frame.status:SetPoint("TOPLEFT", frame, "TOPLEFT", 337, -52)
	frame.status:SetPoint("RIGHT", frame, "RIGHT", -150, 0)
	frame.status:SetJustifyH("LEFT")
	frame.status:SetWordWrap(false)
	frame.status:SetMaxLines(1)
	frame.count = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	frame.count:SetPoint("RIGHT", frame, "RIGHT", -18, 0)
	frame.count:SetPoint("TOP", frame.status, "TOP", 0, 0)
	frame.count:SetWidth(125)
	frame.count:SetJustifyH("RIGHT")

	frame.header = CreateFrame("Frame", nil, frame)
	frame.header:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -96)
	frame.header:SetPoint("RIGHT", frame, "RIGHT", -34, 0)
	frame.header:SetHeight(18)
	if frame.header.SetClipsChildren then
		frame.header:SetClipsChildren(true)
	end
	frame.headerItem = CreateHeader(frame.header, "Composant", 36, 118, "LEFT")
	frame.headers = {}
	for _, column in ipairs(RESULT_COLUMNS) do
		frame.headers[column.key] = CreateHeader(
			frame.header,
			column.label,
			0,
			column.width,
			(column.key == "risk" or column.key == "score") and "CENTER" or "RIGHT"
		)
	end

	frame.detail = CreateFrame("Frame", nil, frame, "BackdropTemplate")
	frame.detail:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 14, 12)
	frame.detail:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -14, 12)
	frame.detail:SetHeight(64)
	frame.detail:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 8 })
	frame.detail:SetBackdropColor(0.035, 0.04, 0.05, 0.92)
	frame.detailTitle = frame.detail:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	frame.detailTitle:SetPoint("TOPLEFT", frame.detail, "TOPLEFT", 10, -8)
	frame.detailTitle:SetPoint("RIGHT", frame.detail, "RIGHT", -200, 0)
	frame.detailTitle:SetJustifyH("LEFT")
	frame.detailTitle:SetWordWrap(false)
	frame.detailTitle:SetMaxLines(1)
	frame.detailBody = frame.detail:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	frame.detailBody:SetPoint("TOPLEFT", frame.detailTitle, "BOTTOMLEFT", 0, -5)
	frame.detailBody:SetPoint("BOTTOMRIGHT", frame.detail, "BOTTOMRIGHT", -200, 7)
	frame.detailBody:SetJustifyH("LEFT")
	frame.detailBody:SetJustifyV("TOP")
	frame.detailBody:SetWordWrap(true)
	frame.detailBody:SetMaxLines(2)
	frame.prepareButton = CreateFrame("Button", nil, frame.detail, "UIPanelButtonTemplate")
	frame.prepareButton:SetSize(178, 25)
	frame.prepareButton:SetPoint("TOPRIGHT", frame.detail, "TOPRIGHT", -10, -9)
	frame.prepareButton:SetText("Acheter le reset")
	frame.prepareButton:RegisterForClicks("LeftButtonUp")
	frame.prepareButton:SetScript("OnClick", function()
		Reset:PreparePurchase()
	end)
	frame.prepareButton:SetScript("OnEnter", function(button)
		GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
		local prepareState, prepareMessage = GetPrepareState(scan.selected)
		local prepareAction = GetPrepareAction(scan.selected)
		if prepareState == "disabled" then
			GameTooltip:AddLine("Préparation indisponible", 1, 0.35, 0.25)
			GameTooltip:AddLine(prepareMessage, 0.85, 0.85, 0.85, true)
		elseif prepareAction == "own-cancel" then
			local canceling = scan.ownCancelCheck.phase == "cancel"
			GameTooltip:AddLine(canceling and "Annulation des auctions" or "Vérification de l’annulation", 1, 0.82, 0.25)
			GameTooltip:AddLine(canceling and "Attends la fin de l’annulation." or "Attends la fin de la vérification.", 0.85, 0.85, 0.85, true)
		elseif prepareAction == "refresh" then
			GameTooltip:AddLine("Actualiser", 1, 0.82, 0.25)
			GameTooltip:AddLine("Ce clic actualise uniquement les paliers. Après 0,5 seconde, un nouveau clic pourra lancer l’achat.", 0.85, 0.85, 0.85, true)
		elseif prepareAction == "cancel-own" then
			GameTooltip:AddLine("Annule mes auctions", 1, 0.82, 0.25)
			GameTooltip:AddLine("Un clic manuel annule toutes tes auctions actives pour cet item, puis vérifie leur disparition avant l’achat.", 0.85, 0.85, 0.85, true)
		else
			GameTooltip:AddLine("Acheter le reset", 1, 0.82, 0.25)
			GameTooltip:AddLine("Le premier appui verrouille l’action, interrompt le scan et ignore les multiclics. Blizzard renvoie le total avant confirmation.", 0.85, 0.85, 0.85, true)
		end
		GameTooltip:Show()
	end)
	frame.prepareButton:SetScript("OnLeave", function(button)
		if GameTooltip:IsOwned(button) then
			GameTooltip:Hide()
		end
	end)
	frame.blacklistButton = CreateFrame("Button", nil, frame.detail, "UIPanelButtonTemplate")
	frame.blacklistButton:SetSize(92, 25)
	frame.blacklistButton:SetPoint("RIGHT", frame.prepareButton, "LEFT", -6, 0)
	frame.blacklistButton:SetText("Blacklist")
	frame.blacklistButton:SetScript("OnClick", function()
		Reset:BlacklistSelected()
	end)
	frame.blacklistButton:SetScript("OnEnter", function(button)
		GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
		GameTooltip:AddLine("Blacklist l’item", 1, 0.45, 0.35)
		GameTooltip:AddLine("Retire cette opportunité et l’exclut des prochains scans.", 0.85, 0.85, 0.85, true)
		GameTooltip:Show()
	end)
	frame.blacklistButton:SetScript("OnLeave", function(button)
		if GameTooltip:IsOwned(button) then
			GameTooltip:Hide()
		end
	end)
	frame.prepareHint = frame.detail:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	frame.prepareHint:SetPoint("TOP", frame.prepareButton, "BOTTOM", 0, -4)
	frame.prepareHint:SetWidth(178)
	frame.prepareHint:SetJustifyH("CENTER")
	frame.prepareHint:SetWordWrap(false)
	frame.prepareHint:SetMaxLines(1)
	frame.prepareHint:SetText("1 achat • prix revalidé")

	frame.resultsScroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
	frame.resultsScroll:SetPoint("TOPLEFT", frame.header, "BOTTOMLEFT", 0, -2)
	frame.resultsScroll:SetPoint("BOTTOMRIGHT", frame.detail, "TOPRIGHT", -22, 8)
	frame.resultsContent = CreateFrame("Frame", nil, frame.resultsScroll)
	frame.resultsContent:SetSize(1, 1)
	frame.resultsScroll:SetScrollChild(frame.resultsContent)
	frame.resultsScroll:SetScript("OnSizeChanged", function(self, width, height)
		frame.resultsContent:SetWidth(math.max(1, width))
		frame.resultsContent:SetHeight(math.max(height, #scan.opportunities * CONSTANTS.ROW_HEIGHT + 4))
		RelayoutResults()
	end)
	frame.empty = frame:CreateFontString(nil, "OVERLAY", "GameFontDisable")
	frame.empty:SetPoint("CENTER", frame.resultsScroll, "CENTER", 0, 12)
	frame.empty:SetWidth(520)
	frame.empty:SetJustifyH("CENTER")

	frame.settingsPanel = CreateFrame("Frame", nil, frame, "BackdropTemplate")
	frame.settingsPanel:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -58)
	frame.settingsPanel:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -16, -58)
	frame.settingsPanel:SetHeight(224)
	frame.settingsPanel:SetFrameLevel(frame:GetFrameLevel() + 20)
	frame.settingsPanel:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 10 })
	frame.settingsPanel:SetBackdropColor(0.025, 0.03, 0.04, 0.99)
	frame.settingsTab = CreateFrame("Button", nil, frame.settingsPanel, "UIPanelButtonTemplate")
	frame.settingsTab:SetSize(92, 24)
	frame.settingsTab:SetPoint("TOPLEFT", frame.settingsPanel, "TOPLEFT", 8, -6)
	frame.settingsTab:SetText("Paramètres")
	frame.blacklistTab = CreateFrame("Button", nil, frame.settingsPanel, "UIPanelButtonTemplate")
	frame.blacklistTab:SetSize(92, 24)
	frame.blacklistTab:SetPoint("LEFT", frame.settingsTab, "RIGHT", 6, 0)
	frame.blacklistTab:SetText("Blacklist")
	frame.settingsContent = CreateFrame("Frame", nil, frame.settingsPanel)
	frame.settingsContent:SetPoint("TOPLEFT", frame.settingsPanel, "TOPLEFT", 0, -34)
	frame.settingsContent:SetPoint("BOTTOMRIGHT", frame.settingsPanel, "BOTTOMRIGHT", 0, 0)
	frame.blacklistContent = CreateFrame("Frame", nil, frame.settingsPanel)
	frame.blacklistContent:SetPoint("TOPLEFT", frame.settingsPanel, "TOPLEFT", 0, -34)
	frame.blacklistContent:SetPoint("BOTTOMRIGHT", frame.settingsPanel, "BOTTOMRIGHT", 0, 0)
	local roi = CreateSetting(frame.settingsContent, "ROI min (%)", 10, 100)
	local profit = CreateSetting(frame.settingsContent, "Profit min (po)", 10, 100)
	local days = CreateSetting(frame.settingsContent, "Horizon (j)", 10, 100)
	local share = CreateSetting(frame.settingsContent, "Part marché (%)", 10, 100)
	local target = CreateSetting(frame.settingsContent, "Cible/réf. (%)", 10, 100)
	local budget = CreateSetting(frame.settingsContent, "Budget (po)", 10, 100)
	local score = CreateSetting(frame.settingsContent, "Score min. (0-100)", 10, 100)
	local goldThreshold = CreateSetting(frame.settingsContent, "Seuil or min. (po)", 10, 100)
	local deepRefresh = CreateSetting(frame.settingsContent, "Cycle profond (min)", 10, 100)
	local settingRows = {
		{ roi, profit, days, share },
		{ target, budget, score, goldThreshold },
		{ deepRefresh },
	}
	local function LayoutSettings()
		local panelWidth = math.max(1, frame.settingsContent:GetWidth())
		local side, gap = 10, 6
		local columnWidth = math.max(86, math.floor((panelWidth - side * 2 - gap * 3) / 4))
		for rowIndex, row in ipairs(settingRows) do
			for columnIndex, holder in ipairs(row) do
				holder:ClearAllPoints()
				holder:SetPoint("TOPLEFT", frame.settingsContent, "TOPLEFT", side + (columnIndex - 1) * (columnWidth + gap), -8 - (rowIndex - 1) * 43)
				holder:SetSize(columnWidth, 42)
				holder.label:SetWidth(columnWidth)
				holder.input:SetSize(math.max(42, columnWidth - 8), 22)
			end
		end
	end
	frame.settingsContent:SetScript("OnSizeChanged", LayoutSettings)
	LayoutSettings()
	local sound = CreateFrame("CheckButton", nil, frame.settingsContent, "UICheckButtonTemplate")
	sound:SetSize(24, 24)
	sound:SetPoint("TOPLEFT", frame.settingsContent, "TOPLEFT", 8, -152)
	sound.label = sound:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	sound.label:SetPoint("LEFT", sound, "RIGHT", 3, 0)
	sound.label:SetText("Son à chaque nouvelle ligne")
	-- Les deux moities du mode sont independantes : une enchere annulee revient
	-- par courrier, on peut donc vouloir remettre en vente sans annuler.
	local function CreateSellToggle(label, anchor, offsetY, tooltipTitle, tooltipBody)
		local check = CreateFrame("CheckButton", nil, frame.settingsContent, "UICheckButtonTemplate")
		check:SetSize(24, 24)
		check:SetPoint("TOPLEFT", anchor, "TOPRIGHT", 14, offsetY)
		check.label = check:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		check.label:SetPoint("LEFT", check, "RIGHT", 3, 0)
		check.label:SetText(label)
		check:SetScript("OnEnter", function(button)
			GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
			GameTooltip:AddLine(tooltipTitle, 1, 0.82, 0.25)
			GameTooltip:AddLine(tooltipBody, 0.85, 0.85, 0.85, true)
			GameTooltip:Show()
		end)
		check:SetScript("OnLeave", function(button)
			if GameTooltip:IsOwned(button) then
				GameTooltip:Hide()
			end
		end)
		return check
	end
	local autoCancel = CreateSellToggle(
		"Annuler les sous-cotées",
		deepRefresh,
		0,
		"Annuler les enchères sous-cotées",
		"À la fin de chaque cycle, le bouton d’action propose d’annuler tes enchères de commodités dépassées, en respectant cancelUndercut, cancelRepost et ignoreLowDuration de tes opérations Auctioning TSM. L’objet annulé revient par courrier."
	)
	local autoPost = CreateSellToggle(
		"Remettre en vente",
		deepRefresh,
		-24,
		"Remettre en vente depuis les sacs",
		"Le bouton d’action propose de mettre en vente les commodités de tes sacs, au prix de ton opération Auctioning TSM ou, à défaut, en undercut du marché sans jamais descendre sous le plancher automatique."
	)
	frame.settingInputs = {
		roi = roi.input,
		profit = profit.input,
		days = days.input,
		share = share.input,
		target = target.input,
		budget = budget.input,
		score = score.input,
		goldThreshold = goldThreshold.input,
		deepRefresh = deepRefresh.input,
		sound = sound,
		autoCancel = autoCancel,
		autoPost = autoPost,
	}
	frame.applySettings = CreateFrame("Button", nil, frame.settingsContent, "UIPanelButtonTemplate")
	frame.applySettings:SetSize(94, 24)
	frame.applySettings:SetPoint("BOTTOMRIGHT", frame.settingsContent, "BOTTOMRIGHT", -10, 8)
	frame.applySettings:SetText("Appliquer")
	frame.applySettings:SetScript("OnClick", function()
		scan.db.minROI = Clamp(frame.settingInputs.roi:GetText(), 1, 500)
		scan.db.minProfitGold = Clamp(frame.settingInputs.profit:GetText(), 0, 100000000)
		scan.db.maxDays = Clamp(frame.settingInputs.days:GetText(), 0.25, 30)
		scan.db.marketShare = Clamp(frame.settingInputs.share:GetText(), 1, 100)
		scan.db.maxTargetPct = Clamp(frame.settingInputs.target:GetText(), 50, 300)
		scan.db.budgetGold = Clamp(frame.settingInputs.budget:GetText(), 1, 100000000)
		scan.db.minScore = Clamp(frame.settingInputs.score:GetText(), 0, 100)
		scan.db.goldThreshold = Clamp(frame.settingInputs.goldThreshold:GetText(), 0, 100000000)
		scan.db.deepRefreshMinutes = Clamp(frame.settingInputs.deepRefresh:GetText(), 0, 720)
		scan.db.sound = frame.settingInputs.sound:GetChecked() == true
		scan.db.autoCancel = frame.settingInputs.autoCancel:GetChecked() == true
		scan.db.autoPost = frame.settingInputs.autoPost:GetChecked() == true
		frame.settingsPanel:Hide()
		local goldBlocked = EnforceGoldThreshold()
		Reset:RebuildFromCache()
		if goldBlocked then
			SetStatus(GetGoldThresholdMessage(), true)
		else
			SetStatus(string.format("Paramètres appliqués • score min. %d • seuil gold %s.", scan.db.minScore, scan.db.goldThreshold > 0 and FormatPrice(scan.db.goldThreshold * 10000) or "désactivé"))
		end
	end)
	frame.forceDeepButton = CreateFrame("Button", nil, frame.settingsContent, "UIPanelButtonTemplate")
	frame.forceDeepButton:SetSize(128, 24)
	frame.forceDeepButton:SetPoint("RIGHT", frame.applySettings, "LEFT", -6, 0)
	frame.forceDeepButton:SetText("Cycle profond")
	frame.forceDeepButton:SetScript("OnClick", function()
		Reset:ForceDeepCycle()
	end)
	frame.forceDeepButton:SetScript("OnEnter", function(button)
		GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
		GameTooltip:AddLine("Repartir sur un relevé profond", 1, 0.82, 0.25)
		GameTooltip:AddLine("Oublie les prix planchers mémorisés : chaque composant est de nouveau analysé en profondeur, comme au premier cycle.", 0.85, 0.85, 0.85, true)
		GameTooltip:Show()
	end)
	frame.forceDeepButton:SetScript("OnLeave", function(button)
		if GameTooltip:IsOwned(button) then
			GameTooltip:Hide()
		end
	end)
	frame.blacklistScroll = CreateFrame("ScrollFrame", nil, frame.blacklistContent, "UIPanelScrollFrameTemplate")
	frame.blacklistScroll:SetPoint("TOPLEFT", frame.blacklistContent, "TOPLEFT", 8, -4)
	frame.blacklistScroll:SetPoint("BOTTOMRIGHT", frame.blacklistContent, "BOTTOMRIGHT", -22, 6)
	frame.blacklistContentFrame = CreateFrame("Frame", nil, frame.blacklistScroll)
	frame.blacklistContentFrame:SetSize(1, 1)
	frame.blacklistScroll:SetScrollChild(frame.blacklistContentFrame)
	frame.blacklistEmpty = frame.blacklistContent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	frame.blacklistEmpty:SetPoint("CENTER", frame.blacklistContent, "CENTER", 0, -2)
	frame.blacklistEmpty:SetText("Aucun item blacklisté.")
	frame.blacklistRows = {}
	RefreshBlacklistPanel = function()
		if not frame.blacklistContentFrame then
			return
		end
		local itemIDs = GetBlacklistedItemIDs()
		local contentWidth = math.max(1, frame.blacklistScroll:GetWidth() or 1)
		frame.blacklistContentFrame:SetWidth(contentWidth)
		frame.blacklistContentFrame:SetHeight(math.max(frame.blacklistScroll:GetHeight() or 1, #itemIDs * 28 + 8))
		for _, row in ipairs(frame.blacklistRows) do
			row:Hide()
		end
		for index, itemID in ipairs(itemIDs) do
			local row = frame.blacklistRows[index]
			if not row then
				row = CreateFrame("Frame", nil, frame.blacklistContentFrame, "BackdropTemplate")
				row:SetHeight(26)
				row:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background" })
				row:SetBackdropColor(0.08, 0.08, 0.09, 0.75)
				row.icon = row:CreateTexture(nil, "ARTWORK")
				row.icon:SetSize(20, 20)
				row.icon:SetPoint("LEFT", row, "LEFT", 4, 0)
				row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
				row.label:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
				row.label:SetPoint("RIGHT", row, "RIGHT", -92, 0)
				row.label:SetJustifyH("LEFT")
				row.label:SetWordWrap(false)
				row.removeButton = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
				row.removeButton:SetSize(82, 22)
				row.removeButton:SetPoint("RIGHT", row, "RIGHT", -4, 0)
				row.removeButton:SetText("Supprimer")
				row.removeButton:SetScript("OnClick", function(button)
					Reset:RemoveBlacklistedItem(button.itemID)
				end)
			end
			row.itemID = itemID
			row.removeButton.itemID = itemID
			row.icon:SetTexture(GetItemTexture(itemID))
			row.label:SetText(GetItemLink(itemID) or GetItemName(itemID))
			row:ClearAllPoints()
			row:SetPoint("TOPLEFT", frame.blacklistContentFrame, "TOPLEFT", 0, -4 - (index - 1) * 28)
			row:SetPoint("RIGHT", frame.blacklistContentFrame, "RIGHT", 0, 0)
			row:Show()
		end
		frame.blacklistEmpty:SetShown(#itemIDs == 0)
	end
	local function ShowOptionsPage(page)
		local blacklistShown = page == "blacklist"
		frame.settingsContent:SetShown(not blacklistShown)
		frame.blacklistContent:SetShown(blacklistShown)
		frame.settingsTab:SetEnabled(blacklistShown)
		frame.blacklistTab:SetEnabled(not blacklistShown)
		if blacklistShown then
			RefreshBlacklistPanel()
		end
	end
	frame.settingsTab:SetScript("OnClick", function()
		ShowOptionsPage("settings")
	end)
	frame.blacklistTab:SetScript("OnClick", function()
		ShowOptionsPage("blacklist")
	end)
	frame.settingsButton:SetScript("OnClick", function()
		frame.settingInputs.roi:SetText(tostring(scan.db.minROI))
		frame.settingInputs.profit:SetText(tostring(scan.db.minProfitGold))
		frame.settingInputs.days:SetText(tostring(scan.db.maxDays))
		frame.settingInputs.share:SetText(tostring(scan.db.marketShare))
		frame.settingInputs.target:SetText(tostring(scan.db.maxTargetPct))
		frame.settingInputs.budget:SetText(tostring(scan.db.budgetGold))
		frame.settingInputs.score:SetText(tostring(scan.db.minScore))
		frame.settingInputs.goldThreshold:SetText(tostring(scan.db.goldThreshold))
		frame.settingInputs.deepRefresh:SetText(tostring(scan.db.deepRefreshMinutes))
		frame.settingInputs.sound:SetChecked(scan.db.sound)
		frame.settingInputs.autoCancel:SetChecked(scan.db.autoCancel)
		frame.settingInputs.autoPost:SetChecked(scan.db.autoPost)
		local shown = not frame.settingsPanel:IsShown()
		frame.settingsPanel:SetShown(shown)
		if shown then
			ShowOptionsPage("settings")
		end
	end)
	ShowOptionsPage("settings")
	frame.settingsPanel:Hide()
	scan.frame = frame
	frame:SetScript("OnHide", function()
		scan.generation = scan.generation + 1
		if scan.running or scan.active or scan.startPending or scan.purchase or scan.continuousPending then
			Reset:StopScan("Scan Reset arrêté : onglet quitté.")
		end
		if scan.controller and scan.controller.updateEventSubscription then
			scan.controller.updateEventSubscription()
		end
	end)
	frame:SetScript("OnShow", function()
		if scan.controller and scan.controller.updateEventSubscription then
			scan.controller.updateEventSubscription()
		end
		if type(YayaReagentSniperTrace) == "function" then
			YayaReagentSniperTrace("UI", "reset tab shown; refreshing cached opportunities")
		end
		wipe(scan.bagCounts)
		Reset:RebuildFromCache()
		C_Timer.After(0, RelayoutResults)
	end)
	UpdateCatalogSelector()
	Reset:RefreshRows()
end

local function CreateTab(parent)
	if scan.tab or not scan.frame then
		return
	end
	local tabID = addonName .. "Reset"
	local libAHTab = type(LibStub) == "table" and LibStub("LibAHTab-1-0", true) or nil
	if libAHTab then
		if not libAHTab:DoesIDExist(tabID) then
			libAHTab:CreateTab(tabID, scan.frame, "Reset", "Yaya Market Reset")
		end
		scan.tab = libAHTab:GetButton(tabID)
		return
	end
	local anchor = _G[addonName .. "Tab"] or parent.Tabs[#parent.Tabs]
	local root = CreateFrame("Frame", nil, parent)
	root:SetSize(10, 10)
	root:SetPoint("TOPLEFT", anchor, "TOPRIGHT")
	local tab = CreateFrame("Button", addonName .. "ResetTab", root, "AuctionHouseFrameDisplayModeTabTemplate")
	tab:SetText("Reset")
	PanelTemplates_TabResize(tab, 20, nil, 78)
	tab:SetPoint("TOPLEFT", root, "TOPLEFT", 3, 0)
	tab.tabHeader = "Yaya Market Reset"
	PanelTemplates_DeselectTab(tab)
	tab:SetScript("OnClick", function()
		parent:SetDisplayMode({})
		parent.displayMode = nil
		local sniperFrame = _G[addonName .. "Frame"]
		if sniperFrame then
			sniperFrame:Hide()
		end
		scan.frame:Show()
		parent:SetTitle(tab.tabHeader)
	end)
	hooksecurefunc(parent, "SetDisplayMode", function(_, mode)
		if mode and not (type(mode) == "table" and next(mode) == nil) then
			scan.frame:Hide()
		end
	end)
	scan.tab = tab
end

function Reset:EnsureUI(parent, controller)
	if not parent or not parent.Tabs then
		return
	end
	scan.controller = controller or scan.controller
	scan.db = scan.db or GetDB()
	if type(YayaReagentSniperSell) == "table" and type(YayaReagentSniperSell.Init) == "function" then
		YayaReagentSniperSell.Init(scan.controller)
	end
	CreateUI(parent)
	CreateTab(parent)
end

function Reset:IsVisible()
	return scan.frame and scan.frame:IsShown() == true
end

function Reset:IsPurchaseBusy()
	return scan.purchase ~= nil
end

function Reset:IsTransportBusy()
	return scan.purchase ~= nil
		or scan.active ~= nil
		or scan.abandonedQuery ~= nil
		or (scan.db ~= nil and IsPurchaseOutcomeUncertain())
		or GetTime() < (scan.actionCooldownUntil or 0)
end

function Reset:Hide()
	if scan.running or scan.active or scan.startPending or scan.purchase or scan.continuousPending then
		self:StopScan("Scan Reset arrêté : onglet quitté.")
	end
	if scan.frame then
		scan.frame:Hide()
	end
end
