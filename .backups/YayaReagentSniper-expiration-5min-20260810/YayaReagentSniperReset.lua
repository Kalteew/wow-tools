local addonName = ...

local Reset = {}
YayaReagentSniperReset = Reset

local CONSTANTS = {
	BATCH_SIZE = 100,
	START_SETTLE_DELAY = 0.25,
	QUERY_TIMEOUT = 7,
	BETWEEN_QUERIES = 0.15,
	MAX_DEEP_PAGES = 40,
	MAX_SCAN_AGE = 120,
	ROW_HEIGHT = 36,
	AH_CUT = 0.05,
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
	startPending = false,
	generation = 0,
	candidates = {},
	browseIndex = 1,
	deepCandidates = {},
	deepIndex = 1,
	active = nil,
	timers = {},
	opportunities = {},
	depthCache = {},
	rows = {},
	selected = nil,
	prepareRefresh = nil,
	purchase = nil,
	purchaseGeneration = 0,
	completedAt = nil,
	stats = {},
	catalogSource = nil,
	catalogSelectedCount = 0,
	ownAuctions = {},
	ownAuctionCount = 0,
	ownAuctionQuantity = 0,
	ownQuerySent = false,
	ownAuctionsReady = false,
}

local function GetCatalogOption(key)
	for _, option in ipairs(CATALOG_OPTIONS) do
		if option.key == key then
			return option
		end
	end
	return CATALOG_OPTIONS[1]
end

local function Clamp(value, minimum, maximum)
	value = tonumber(value) or minimum
	return math.max(minimum, math.min(maximum, value))
end

local function FormatPrice(value)
	value = math.max(0, math.floor(tonumber(value) or 0))
	return GetMoneyString and GetMoneyString(value, true) or tostring(value)
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
end

local function CollectCatalogItemIDs(selection)
	local catalog = type(YayaReagentSniperCatalog) == "table" and YayaReagentSniperCatalog or nil
	local expansions = catalog and type(catalog.expansions) == "table" and catalog.expansions or nil
	local seen, itemIDs, hasCatalog = {}, {}, false
	if not expansions then
		return itemIDs, false
	end
	for _, option in ipairs(CATALOG_OPTIONS) do
		if option.key ~= "all" then
			local entry = expansions[option.key]
			local ids = entry and type(entry.itemIDs) == "table" and entry.itemIDs or nil
			if ids and #ids > 0 then
				hasCatalog = true
				if selection == "all" or selection == option.key then
					for _, itemID in ipairs(ids) do
						itemID = tonumber(itemID)
						if itemID and itemID > 0 and not seen[itemID] then
							seen[itemID] = true
							itemIDs[#itemIDs + 1] = itemID
						end
					end
				end
			end
		end
	end
	table.sort(itemIDs)
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
end

local function ResetStats()
	scan.stats = {
		browsed = 0,
		deepScanned = 0,
		noMarket = 0,
		missingData = 0,
		incomplete = 0,
		rejected = 0,
	}
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
	db.expansion = GetCatalogOption(db.expansion).key
	return db
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
	local budget = math.max(1, scan.db.budgetGold * 10000)
	local profitPivot = math.max(5000 * 10000, scan.db.minProfitGold * 10000 * 5)
	local roiFloor = scan.db.minROI / 100
	local profitComponent = result.profit / (result.profit + profitPivot)
	local roiComponent = Clamp((result.roi - roiFloor) / math.max(0.01, 1 - roiFloor), 0, 1)
	local costComponent = 1 / (1 + result.absorbCost / math.max(1, budget * 0.10))
	local liquidityComponent = Clamp((result.saleRate or 0) / 0.30, 0, 1)
	local speedComponent = 1 - Clamp(result.days / math.max(0.01, scan.db.maxDays), 0, 1)
	local riskComponent = result.riskFactor or 0.2
	result.scoreParts = {
		profit = profitComponent,
		roi = roiComponent,
		cost = costComponent,
		liquidity = liquidityComponent,
		speed = speedComponent,
		risk = riskComponent,
	}
	return 100 * (
		0.48 * profitComponent
		+ 0.22 * roiComponent
		+ 0.10 * costComponent
		+ 0.07 * liquidityComponent
		+ 0.08 * speedComponent
		+ 0.05 * riskComponent
	)
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
	itemObject:ContinueOnItemLoad(function()
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
	local budget = scan.db.budgetGold * 10000
	local minProfit = scan.db.minProfitGold * 10000
	local dailyCapacity = candidate.soldPerDay * scan.db.marketShare / 100
	if dailyCapacity <= 0 then
		return nil
	end
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

local function UpdateCatalogSelector()
	local selection = scan.db and scan.db.expansion or "all"
	local option = GetCatalogOption(selection)
	local itemIDs, hasCatalog = CollectCatalogItemIDs(option.key)
	scan.catalogSelectedCount = #itemIDs
	if scan.frame and scan.frame.expansionDropdown then
		UIDropDownMenu_SetSelectedValue(scan.frame.expansionDropdown, option.key)
		UIDropDownMenu_SetText(scan.frame.expansionDropdown, option.label)
		scan.frame.catalogCount:SetText(hasCatalog and string.format("%d composants", #itemIDs) or "Catalogue indisponible")
	end
	return hasCatalog
end

local function GetScanSummary()
	if scan.running then
		if scan.phase == "owned" then
			return "Lecture des auctions personnelles…"
		elseif scan.phase == "browse" then
			return string.format("Pré-scan : %d / %d composants", math.min(scan.browseIndex - 1, #scan.candidates), #scan.candidates)
		elseif scan.phase == "deep" then
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
	return string.format("Catalogue récolte • %s • %d composants", label, scan.catalogSelectedCount or 0)
end

local function GetPrepareState(result)
	if not result then
		return "disabled", "Sélectionne une opportunité."
	elseif scan.purchase then
		return "disabled", "Un achat Reset est déjà en cours."
	elseif scan.running then
		return "disabled", scan.prepareRefresh and "Actualisation ciblée en cours…" or "Attends la fin du scan avant l’achat."
	elseif scan.controller and scan.controller.isPurchaseBusy and scan.controller.isPurchaseBusy() then
		return "disabled", "Termine l’achat Sniper en cours."
	elseif result.complete ~= true then
		return "disabled", "Les paliers de cette opportunité sont incomplets."
	elseif not result.quantity or result.quantity <= 0 or not result.absorbCost or result.absorbCost <= 0 then
		return "disabled", "La quantité ou le coût estimé est indisponible."
	elseif result.lifecycleState == "stale" or not result.scanAt or GetTime() - result.scanAt > CONSTANTS.MAX_SCAN_AGE then
		return "refresh", result.lifecycleReason or "Les données ont expiré : un rescan profond ciblé est requis."
	elseif result.absorbCost > (tonumber(scan.db.budgetGold) or 0) * 10000 then
		return "disabled", "Le coût dépasse le budget Reset configuré."
	elseif type(GetMoney) == "function" and result.absorbCost > GetMoney() then
		return "disabled", "L’or disponible ne couvre pas ce reset."
	end
	return "ready", nil
end

function Reset:RefreshSelected()
	if not scan.frame then
		return
	end
	local result = scan.selected
	local prepareState, prepareMessage = GetPrepareState(result)
	if scan.frame.prepareButton then
		scan.frame.prepareButton:SetEnabled(prepareState ~= "disabled")
		if scan.purchase then
			scan.frame.prepareButton:SetText("Achat en cours…")
		elseif scan.prepareRefresh then
			scan.frame.prepareButton:SetText("Actualisation…")
		elseif prepareState == "refresh" then
			scan.frame.prepareButton:SetText("Actualiser puis acheter")
		else
			scan.frame.prepareButton:SetText("Acheter le reset")
		end
	end
	if scan.frame.prepareHint then
		if scan.purchase then
			scan.frame.prepareHint:SetText("Transaction Blizzard en cours")
		elseif scan.prepareRefresh then
			scan.frame.prepareHint:SetText("Lecture des paliers en cours")
		elseif prepareState == "refresh" then
			scan.frame.prepareHint:SetText("Rescan ciblé • puis clic achat")
		elseif prepareState == "disabled" then
			scan.frame.prepareHint:SetText("Sélection fraîche requise")
		else
			scan.frame.prepareHint:SetText("1 achat • prix revalidé")
		end
	end
	if not result then
		scan.frame.detailTitle:SetText("Sélectionne une ligne pour voir le scénario")
		scan.frame.detailBody:SetText("Aucune boucle : un clic humain ne lance qu’un seul achat Reset sélectionné.")
		return
	end
	scan.frame.detailTitle:SetText(result.itemLink or result.name or ("Composant " .. tostring(result.itemID)))
	if prepareState == "disabled" then
		scan.frame.detailBody:SetText(prepareMessage .. " Aucun achat n’a été lancé.")
		return
	elseif prepareState == "refresh" then
		scan.frame.detailBody:SetText((result.lifecycleReason or "Données expirées.") .. " Clique « Actualiser puis acheter » : seul cet item sera rescanné, puis un nouveau clic humain lancera l’achat.")
		return
	end
	scan.frame.detailBody:SetText(string.format(
		"Score %d/100 • absorber %s palier(s) pour %s, puis viser %s/u. Profit net %s après 5%% de commission • %.1f j à %.0f%% de la demande TSM%s. Le prix Blizzard sera revalidé avant confirmation.",
		math.floor(result.score + 0.5),
		result.tiersAbsorbed,
		FormatPrice(result.absorbCost),
		FormatPrice(result.targetPrice),
		FormatPrice(result.profit),
		result.days,
		scan.db.marketShare,
		result.ownAuctionQuantity and result.ownAuctionQuantity > 0
			and string.format(" • %s de tes unités exclues du calcul : annule-les avant l’achat", FormatCompactNumber(result.ownAuctionQuantity))
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
	if scan.selected == result or (scan.selected and scan.selected.itemID == result.itemID) then
		scan.selected = nil
	end
end

local function CancelResetPurchase(message, red, disposition)
	local purchase = scan.purchase
	CancelTimer("purchaseTimeout")
	if purchase and purchase.started and not purchase.confirming and C_AuctionHouse.CancelCommoditiesPurchase then
		pcall(C_AuctionHouse.CancelCommoditiesPurchase)
	end
	if purchase and disposition == "drop" then
		DropResetOpportunity(purchase.itemID)
	elseif purchase and disposition ~= "keep" then
		InvalidateResetOpportunity(purchase.result, message)
	end
	scan.purchaseGeneration = scan.purchaseGeneration + 1
	scan.purchase = nil
	if scan.frame then
		scan.frame.scanButton:SetEnabled(true)
	end
	Reset:RefreshRows()
	if message then
		SetStatus(message, red)
	end
end

local function StartResetPurchase(result)
	-- Start reste synchrone avec le clic humain ; aucun timer ne relance un achat.
	local quantity = math.max(1, math.floor(tonumber(result.quantity) or 0))
	local maxCost = math.max(0, math.floor(tonumber(result.absorbCost) or 0))
	local budget = math.max(0, math.floor((tonumber(scan.db.budgetGold) or 0) * 10000))
	local availableMoney = type(GetMoney) == "function" and tonumber(GetMoney()) or nil
	if type(C_AuctionHouse.StartCommoditiesPurchase) ~= "function"
		or type(C_AuctionHouse.ConfirmCommoditiesPurchase) ~= "function"
	then
		InvalidateResetOpportunity(result, "API d’achat indisponible : résultat à rescanner.")
		Reset:RefreshRows()
		SetStatus("API d’achat de commodités indisponible.", true)
		return
	elseif quantity <= 0 or maxCost <= 0 then
		InvalidateResetOpportunity(result, "Quantité ou coût invalide : résultat à rescanner.")
		Reset:RefreshRows()
		SetStatus("Quantité ou coût du reset invalide.", true)
		return
	elseif maxCost > budget then
		SetStatus("Le coût du reset dépasse le budget configuré.", true)
		return
	elseif availableMoney and maxCost > availableMoney then
		SetStatus("Or insuffisant : " .. FormatPrice(maxCost) .. " requis, " .. FormatPrice(availableMoney) .. " disponible.", true)
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
		budget = budget,
		result = result,
		started = true,
		confirming = false,
	}
	local ok = pcall(C_AuctionHouse.StartCommoditiesPurchase, result.itemID, quantity)
	if not ok then
		scan.purchase.started = false
		CancelResetPurchase("Impossible de lancer l’achat : résultat à rescanner.", true, "stale")
		return
	end
	local generation = scan.purchase.generation
	Schedule("purchaseTimeout", CONSTANTS.QUERY_TIMEOUT, function()
		if scan.purchase and scan.purchase.generation == generation and not scan.purchase.confirming then
			CancelResetPurchase("Achat sans réponse : résultat à rescanner.", true, "stale")
		end
	end)
	if scan.frame then
		scan.frame.scanButton:SetEnabled(false)
	end
	Reset:RefreshRows()
	SetStatus(string.format("Vérification Blizzard : %s × %s…", FormatCompactNumber(quantity), result.name or "composant"))
end

local function HandleResetPurchaseEvent(event, ...)
	-- La cotation Blizzard est l’ultime garde-fou avant l’unique confirmation.
	local purchase = scan.purchase
	if not purchase then
		return false
	end
	if event == "COMMODITY_PRICE_UPDATED" then
		if purchase.confirming then
			return true
		end
		CancelTimer("purchaseTimeout")
		local unitPrice, totalPrice = ...
		unitPrice = tonumber(unitPrice)
		totalPrice = tonumber(totalPrice)
		if (not totalPrice or totalPrice <= 0) and unitPrice and unitPrice > 0 then
			totalPrice = unitPrice * purchase.quantity
		end
		if not totalPrice or totalPrice <= 0 or totalPrice > purchase.maxCost then
			CancelResetPurchase("Prix remonté au-dessus des paliers recommandés : opportunité retirée.", true, "drop")
			return true
		end
		local availableMoney = type(GetMoney) == "function" and tonumber(GetMoney()) or nil
		if availableMoney and totalPrice > availableMoney then
			CancelResetPurchase("Or insuffisant : " .. FormatPrice(totalPrice) .. " requis, " .. FormatPrice(availableMoney) .. " disponible.", true, "keep")
			return true
		elseif totalPrice > purchase.budget then
			CancelResetPurchase("Le prix Blizzard dépasse le budget Reset.", true, "keep")
			return true
		end
		purchase.unitPrice = unitPrice or math.ceil(totalPrice / purchase.quantity)
		purchase.totalPrice = totalPrice
		purchase.confirming = true
		local ok = pcall(C_AuctionHouse.ConfirmCommoditiesPurchase, purchase.itemID, purchase.quantity)
		if not ok then
			purchase.confirming = false
			CancelResetPurchase("Confirmation impossible : résultat à rescanner.", true, "stale")
			return true
		end
		local generation = purchase.generation
		Schedule("purchaseTimeout", CONSTANTS.QUERY_TIMEOUT, function()
			if scan.purchase and scan.purchase.generation == generation and scan.purchase.confirming then
				CancelResetPurchase("Confirmation sans réponse : résultat à rescanner.", true, "stale")
			end
		end)
		Reset:RefreshRows()
		SetStatus("Achat envoyé à Blizzard…")
		return true
	elseif event == "COMMODITY_PRICE_UNAVAILABLE" then
		CancelResetPurchase("Prix indisponible : l’opportunité a été retirée.", true, "drop")
		return true
	elseif event == "COMMODITY_PURCHASE_SUCCEEDED" then
		local quantity, totalPrice = purchase.quantity, purchase.totalPrice or purchase.maxCost
		CancelResetPurchase(string.format("Achat confirmé : %s unités pour %s.", FormatCompactNumber(quantity), FormatPrice(totalPrice)), false, "drop")
		return true
	elseif event == "COMMODITY_PURCHASE_FAILED" then
		CancelResetPurchase("Achat refusé ou offre déjà partie : opportunité retirée.", true, "drop")
		return true
	end
	return false
end

function Reset:PreparePurchase()
	local result = scan.selected
	local prepareState, prepareMessage = GetPrepareState(result)
	if prepareState == "refresh" then
		self:RefreshSelectedForPurchase(result)
		return
	elseif prepareState ~= "ready" then
		SetStatus(prepareMessage, true)
		self:RefreshSelected()
		return
	end
	StartResetPurchase(result)
end

function Reset:RefreshSelectedForPurchase(result)
	local prepareState, prepareMessage = GetPrepareState(result)
	if prepareState == "ready" then
		self:PreparePurchase()
		return
	elseif prepareState ~= "refresh" then
		SetStatus(prepareMessage, true)
		self:RefreshSelected()
		return
	end
	if scan.controller and scan.controller.isPurchaseBusy and scan.controller.isPurchaseBusy() then
		SetStatus("Termine l’achat en cours avant l’actualisation ciblée.", true)
		return
	end
	local candidate = {
		itemID = result.itemID,
		itemString = result.itemString or ("i:" .. tostring(result.itemID)),
		name = result.name or GetItemName(result.itemID),
	}
	if not ResolveTSMData(candidate) then
		result.complete = false
		SetStatus("Liquidité ou référence TSM indisponible après actualisation.", true)
		self:RefreshSelected()
		return
	end
	if type(C_AuctionHouse.MakeItemKey) ~= "function" or type(C_AuctionHouse.SendSearchQuery) ~= "function" then
		result.complete = false
		SetStatus("L’API de recherche profonde Blizzard est indisponible.", true)
		self:RefreshSelected()
		return
	end
	scan.generation = scan.generation + 1
	CancelScanTimers()
	scan.prepareRefresh = { itemID = result.itemID, original = result }
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
	elseif result.absorbCost > (tonumber(scan.db.budgetGold) or 0) * 10000 then
		GameTooltip:AddLine("Achat bloqué : budget Reset insuffisant", 1, 0.35, 0.25)
	elseif type(GetMoney) == "function" and result.absorbCost > GetMoney() then
		GameTooltip:AddLine("Achat bloqué : or insuffisant", 1, 0.35, 0.25)
	end
	GameTooltip:AddDoubleLine("Coût à absorber", FormatPrice(result.absorbCost), 0.8, 0.8, 0.8, 1, 1, 1)
	GameTooltip:AddDoubleLine("Quantité", FormatCompactNumber(result.quantity), 0.8, 0.8, 0.8, 1, 1, 1)
	if result.ownAuctionQuantity and result.ownAuctionQuantity > 0 then
		GameTooltip:AddLine(string.format("Tes propres auctions exclues : %s unités • annulation manuelle requise.", FormatCompactNumber(result.ownAuctionQuantity)), 1, 0.82, 0.25, true)
	end
	GameTooltip:AddDoubleLine("Cible / unité", FormatPrice(result.targetPrice), 0.8, 0.8, 0.8, 1, 1, 1)
	GameTooltip:AddDoubleLine("Profit net", FormatPrice(result.profit), 0.8, 0.8, 0.8, 0.35, 1, 0.45)
	GameTooltip:AddDoubleLine("ROI", string.format("%d%%", math.floor(result.roi * 100 + 0.5)), 0.8, 0.8, 0.8, 1, 1, 1)
	GameTooltip:AddDoubleLine("Référence TSM", FormatPrice(result.referencePrice), 0.8, 0.8, 0.8, 1, 1, 1)
	GameTooltip:AddDoubleLine("Ventes région / jour", FormatDecimal(result.soldPerDay, 1), 0.8, 0.8, 0.8, 1, 1, 1)
	GameTooltip:AddDoubleLine("Écoulement estimé", FormatDecimal(result.days, 1) .. " j", 0.8, 0.8, 0.8, 1, 1, 1)
	GameTooltip:AddDoubleLine("Risque", result.risk or "—", 0.8, 0.8, 0.8, result.riskR or 1, result.riskG or 1, result.riskB or 1)
	GameTooltip:AddDoubleLine("Score", string.format("%d / 100", math.floor(result.score + 0.5)), 0.8, 0.8, 0.8, 1, 0.82, 0.25)
	GameTooltip:AddLine("48% profit net • 22% ROI • 10% coût • 7% liquidité • 8% vitesse • 5% risque cible", 0.75, 0.85, 1, true)
	GameTooltip:AddLine("Pivot profit : max(5 000 po, 5× seuil min) • coût 10% budget • SaleRate 30%.", 0.65, 0.75, 0.9, true)
	GameTooltip:AddLine("La quantité et les ventes/jour alimentent la durée ; la cible face à la référence alimente le risque.", 0.65, 0.65, 0.65, true)
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
	if frame.prepareButton and frame.detailTitle and frame.detailBody then
		local buttonWidth = viewportWidth < 560 and 150 or 178
		frame.prepareButton:SetWidth(buttonWidth)
		frame.prepareHint:SetWidth(buttonWidth)
		frame.detailTitle:ClearAllPoints()
		frame.detailTitle:SetPoint("TOPLEFT", frame.detail, "TOPLEFT", 10, -8)
		frame.detailTitle:SetPoint("RIGHT", frame.detail, "RIGHT", -(buttonWidth + 22), 0)
		frame.detailBody:ClearAllPoints()
		frame.detailBody:SetPoint("TOPLEFT", frame.detailTitle, "BOTTOMLEFT", 0, -5)
		frame.detailBody:SetPoint("BOTTOMRIGHT", frame.detail, "BOTTOMRIGHT", -(buttonWidth + 22), 7)
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
		if not self.data then
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
		elseif result.absorbCost > (tonumber(scan.db.budgetGold) or 0) * 10000
			or (type(GetMoney) == "function" and result.absorbCost > GetMoney())
		then
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
	SetStatus(GetScanSummary())
	self:RefreshSelected()
end

local function BuildCandidates()
	local selection = scan.db and scan.db.expansion or "all"
	local catalogIDs, hasCatalog = CollectCatalogItemIDs(selection)
	if hasCatalog then
		local candidates = {}
		for _, itemID in ipairs(catalogIDs) do
			if IsCommodity(itemID) then
				candidates[#candidates + 1] = {
					itemID = itemID,
					itemString = "i:" .. tostring(itemID),
				}
			end
		end
		scan.catalogSource = "catalog"
		scan.catalogSelectedCount = #candidates
		if #candidates == 0 then
			return nil, "Aucune commodité de récolte valide pour cette extension."
		end
		return candidates
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
				if itemID and not seen[itemID] and IsCommodity(itemID) then
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
	return candidates
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
	UpdateCatalogSelector()
	self:RefreshRows()
	SetStatus(string.format("Extension : %s • %d composants de récolte.", option.label, scan.catalogSelectedCount))
end

local function IsThrottleReady()
	return not C_AuctionHouse.IsThrottledMessageSystemReady or C_AuctionHouse.IsThrottledMessageSystemReady()
end

local function ReadOwnedAuctions()
	wipe(scan.ownAuctions)
	scan.ownAuctionCount = 0
	scan.ownAuctionQuantity = 0
	local count = tonumber(C_AuctionHouse.GetNumOwnedAuctions()) or 0
	local activeStatus = Enum.AuctionStatus and Enum.AuctionStatus.Active or 0
	for index = 1, count do
		local info = C_AuctionHouse.GetOwnedAuctionInfo(index)
		local itemKey = info and info.itemKey
		local itemID = itemKey and tonumber(itemKey.itemID)
		local quantity = info and tonumber(info.quantity)
		local buyout = info and tonumber(info.buyoutAmount)
		local status = info and info.status
		if itemID and itemID > 0 and quantity and quantity > 0 and buyout and buyout > 0
			and (not status or status == activeStatus)
		then
			local unitPrice = math.floor((buyout + quantity / 2) / quantity)
			local byPrice = scan.ownAuctions[itemID] or {}
			byPrice[unitPrice] = (byPrice[unitPrice] or 0) + quantity
			scan.ownAuctions[itemID] = byPrice
			scan.ownAuctionCount = scan.ownAuctionCount + 1
			scan.ownAuctionQuantity = scan.ownAuctionQuantity + quantity
		end
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
	if not scan.running or scan.phase ~= "owned" or scan.ownQuerySent then
		return
	end
	if not IsThrottleReady() then
		Schedule("owned", 0.25, function()
			ProcessOwnedAuctions()
		end)
		return
	end
	scan.ownQuerySent = true
	Schedule("ownedTimeout", CONSTANTS.QUERY_TIMEOUT, function()
		FinishOwnedAuctionQuery(false)
	end)
	local ok = pcall(C_AuctionHouse.QueryOwnedAuctions, SORTS)
	if not ok then
		FinishOwnedAuctionQuery(false)
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
	else
		local seen = {}
		local resultByID = {}
		local resultSets = {
			C_AuctionHouse.GetBrowseResults and C_AuctionHouse.GetBrowseResults() or {},
			active.addedResults or {},
		}
		for _, results in ipairs(resultSets) do
			for _, info in ipairs(results) do
				local itemKey = info and info.itemKey
				if itemKey and active.byID[itemKey.itemID] then
					resultByID[itemKey.itemID] = info
				end
			end
		end
		for _, info in pairs(resultByID) do
			local itemKey = info and info.itemKey
			local candidate = itemKey and active.byID[itemKey.itemID]
			if candidate then
				seen[candidate.itemID] = true
				scan.stats.browsed = scan.stats.browsed + 1
				if info.minPrice and info.minPrice > 0 and info.totalQuantity and info.totalQuantity > 0 then
					candidate.minPrice = info.minPrice
					candidate.totalQuantity = info.totalQuantity
					if ResolveTSMData(candidate) then
						if candidate.minPrice < candidate.referencePrice * scan.db.maxTargetPct / 100 then
							scan.deepCandidates[#scan.deepCandidates + 1] = candidate
						else
							scan.stats.rejected = scan.stats.rejected + 1
						end
					else
						scan.stats.missingData = scan.stats.missingData + 1
					end
				else
					scan.stats.noMarket = scan.stats.noMarket + 1
				end
			end
		end
		for _, candidate in ipairs(active.items) do
			if not seen[candidate.itemID] then
				scan.stats.noMarket = scan.stats.noMarket + 1
			end
		end
	end
	scan.active = nil
	scan.browseIndex = active.nextIndex
	Reset:RefreshRows()
	Schedule("next", 0, function()
		Reset:ProcessBrowse()
	end)
end

function Reset:ProcessBrowse()
	if not scan.running or scan.phase ~= "browse" or scan.active then
		return
	end
	if scan.browseIndex > #scan.candidates then
		table.sort(scan.deepCandidates, function(left, right)
			return left.minPrice / left.referencePrice < right.minPrice / right.referencePrice
		end)
		scan.phase = "deep"
		scan.deepIndex = 1
		self:RefreshRows()
		Schedule("next", 0, function()
			Reset:ProcessDeep()
		end)
		return
	end
	if not IsThrottleReady() then
		Schedule("next", 0.25, function()
			Reset:ProcessBrowse()
		end)
		return
	end
	local items = {}
	local byID = {}
	local keys = {}
	local nextIndex = scan.browseIndex
	while nextIndex <= #scan.candidates and #items < CONSTANTS.BATCH_SIZE do
		local candidate = scan.candidates[nextIndex]
		local key = C_AuctionHouse.MakeItemKey(candidate.itemID)
		if key then
			items[#items + 1] = candidate
			byID[candidate.itemID] = candidate
			keys[#keys + 1] = key
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
	scan.active = { kind = "browse", items = items, byID = byID, nextIndex = nextIndex }
	Schedule("timeout", CONSTANTS.QUERY_TIMEOUT, function()
		FinishBrowseBatch(true)
	end)
	local ok = pcall(C_AuctionHouse.SearchForItemKeys, keys, {})
	if not ok then
		FinishBrowseBatch(true)
	end
end

local function ReadDepth(active)
	local tiersByPrice = {}
	local ownByPrice = scan.ownAuctions[active.candidate.itemID] or {}
	active.ownAuctionQuantity = 0
	local count = C_AuctionHouse.GetNumCommoditySearchResults(active.candidate.itemID)
	for index = 1, count do
		local info = C_AuctionHouse.GetCommoditySearchResultInfo(active.candidate.itemID, index)
		if info and info.unitPrice and info.unitPrice > 0 and info.quantity and info.quantity > 0 then
			tiersByPrice[info.unitPrice] = (tiersByPrice[info.unitPrice] or 0) + info.quantity
		end
	end
	local tiers = {}
	for price, quantity in pairs(tiersByPrice) do
		local ownQuantity = math.min(quantity, ownByPrice[price] or 0)
		quantity = quantity - ownQuantity
		active.ownAuctionQuantity = active.ownAuctionQuantity + ownQuantity
		if quantity > 0 then
			tiers[#tiers + 1] = { price = price, quantity = quantity }
		end
	end
	table.sort(tiers, function(left, right)
		return left.price < right.price
	end)
	active.tiers = tiers
	active.resultCount = count
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
	if complete then
		local result = EvaluateDepth(active.candidate, active.tiers or {}, active.ownAuctionQuantity or 0)
		scan.depthCache[active.candidate.itemID] = {
			candidate = active.candidate,
			tiers = active.tiers or {},
			ownAuctionQuantity = active.ownAuctionQuantity or 0,
			scanAt = GetTime(),
		}
		if prepareRefresh then
			prepareRefresh.result = result
			prepareRefresh.complete = true
		elseif result then
			scan.opportunities[#scan.opportunities + 1] = result
		else
			scan.stats.rejected = scan.stats.rejected + 1
		end
	else
		scan.stats.incomplete = scan.stats.incomplete + 1
		if prepareRefresh then
			prepareRefresh.incomplete = true
			prepareRefresh.original.complete = false
		end
	end
	scan.deepIndex = scan.deepIndex + 1
	Reset:RefreshRows()
	Schedule("next", CONSTANTS.BETWEEN_QUERIES, function()
		Reset:ProcessDeep()
	end)
end

local function RemoveOpportunityByItemID(itemID)
	for index = #scan.opportunities, 1, -1 do
		if scan.opportunities[index].itemID == itemID then
			table.remove(scan.opportunities, index)
		end
	end
end

local function CompletePrepareRefresh()
	local context = scan.prepareRefresh
	scan.prepareRefresh = nil
	scan.running = false
	scan.phase = "idle"
	scan.active = nil
	if scan.frame then
		scan.frame.scanButton:SetText("Scanner le marché")
		scan.frame.scanButton:SetEnabled(true)
	end
	if not context then
		Reset:RefreshRows()
		return
	end
	if context.result then
		RemoveOpportunityByItemID(context.itemID)
		scan.opportunities[#scan.opportunities + 1] = context.result
		scan.selected = context.result
		Reset:RefreshRows()
		Schedule("stale", CONSTANTS.MAX_SCAN_AGE, function()
			if not scan.running and scan.selected == context.result then
				Reset:RefreshRows()
			end
		end)
		SetStatus("Paliers actualisés : clique « Acheter le reset » pour lancer l’achat.")
	elseif context.incomplete then
		scan.selected = context.original
		Reset:RefreshRows()
		SetStatus("Actualisation incomplète : aucun achat n’a été lancé.", true)
	else
		RemoveOpportunityByItemID(context.itemID)
		scan.selected = nil
		Reset:RefreshRows()
		SetStatus("L’opportunité ne respecte plus les garde-fous après actualisation.", true)
	end
end

local function FinalizeScanFreshness()
	scan.completedAt = GetTime()
	for _, result in ipairs(scan.opportunities) do
		result.scanAt = scan.completedAt
	end
	for _, cached in pairs(scan.depthCache) do
		cached.scanAt = scan.completedAt
	end
end

local function RequestMoreDepth(active)
	if scan.active ~= active or not scan.running then
		return
	end
	if not IsThrottleReady() then
		Schedule("page", 0.25, function()
			RequestMoreDepth(active)
		end)
		return
	end
	if active.pages >= CONSTANTS.MAX_DEEP_PAGES then
		FinishDeepCandidate(false)
		return
	end
	active.pages = active.pages + 1
	Schedule("timeout", CONSTANTS.QUERY_TIMEOUT, function()
		FinishDeepCandidate(false)
	end)
	local ok = pcall(C_AuctionHouse.RequestMoreCommoditySearchResults, active.candidate.itemID)
	if not ok then
		FinishDeepCandidate(false)
	end
end

function Reset:ProcessDeep()
	if not scan.running or scan.phase ~= "deep" or scan.active then
		return
	end
	if scan.deepIndex > #scan.deepCandidates then
		if scan.prepareRefresh then
			CompletePrepareRefresh()
			return
		end
		scan.running = false
		scan.phase = "idle"
		FinalizeScanFreshness()
		if scan.frame then
			scan.frame.scanButton:SetText("Scanner le marché")
		end
		SortOpportunities()
		self:RefreshRows()
		Schedule("stale", CONSTANTS.MAX_SCAN_AGE, function()
			if not scan.running and not IsFresh() then
				Reset:RefreshRows()
			end
		end)
		return
	end
	if not IsThrottleReady() then
		Schedule("next", 0.25, function()
			Reset:ProcessDeep()
		end)
		return
	end
	local candidate = scan.deepCandidates[scan.deepIndex]
	local itemKey = C_AuctionHouse.MakeItemKey(candidate.itemID)
	if not itemKey then
		scan.stats.incomplete = scan.stats.incomplete + 1
		if scan.prepareRefresh and scan.prepareRefresh.itemID == candidate.itemID then
			scan.prepareRefresh.incomplete = true
			scan.prepareRefresh.original.complete = false
		end
		scan.deepIndex = scan.deepIndex + 1
		Schedule("next", 0, function()
			Reset:ProcessDeep()
		end)
		return
	end
	scan.active = { kind = "deep", candidate = candidate, pages = 1, tiers = {} }
	Schedule("timeout", CONSTANTS.QUERY_TIMEOUT, function()
		FinishDeepCandidate(false)
	end)
	local ok = pcall(C_AuctionHouse.SendSearchQuery, itemKey, SORTS, false)
	if not ok then
		FinishDeepCandidate(false)
	end
end

local function HandleCommodityResults(itemID)
	local active = scan.active
	if not active or active.kind ~= "deep" or itemID ~= active.candidate.itemID then
		return
	end
	CancelTimer("timeout")
	ReadDepth(active)
	local ok, full = pcall(C_AuctionHouse.HasFullCommoditySearchResults, active.candidate.itemID)
	if ok and full then
		FinishDeepCandidate(true)
	else
		Schedule("page", CONSTANTS.BETWEEN_QUERIES, function()
			RequestMoreDepth(active)
		end)
	end
end

function Reset:StopScan(message)
	if scan.purchase then
		CancelResetPurchase(message or "Achat Reset annulé.", true)
		message = nil
	end
	if not scan.running and not scan.active then
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
	if message then
		SetStatus(message)
	end
end

function Reset:StartScan()
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
	if scan.controller and scan.controller.stopSniper then
		scan.controller.stopSniper()
	end
	scan.generation = scan.generation + 1
	CancelScanTimers()
	wipe(scan.opportunities)
	wipe(scan.depthCache)
	wipe(scan.deepCandidates)
	wipe(scan.ownAuctions)
	scan.ownAuctionCount = 0
	scan.ownAuctionQuantity = 0
	scan.ownQuerySent = false
	scan.ownAuctionsReady = false
	scan.selected = nil
	scan.completedAt = nil
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
	self:RefreshRows()
	SetStatus(string.format("Préparation du scan • %d composants…", #candidates))
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
	wipe(scan.opportunities)
	for _, cached in pairs(scan.depthCache) do
		if GetTime() - cached.scanAt <= CONSTANTS.MAX_SCAN_AGE then
			local result = EvaluateDepth(cached.candidate, cached.tiers, cached.ownAuctionQuantity or 0)
			if result then
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

function Reset:OnEvent(event, ...)
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
	if event == "OWNED_AUCTIONS_UPDATED" then
		if scan.running and scan.phase == "owned" then
			FinishOwnedAuctionQuery(true)
		end
		return
	end
	if event == "PLAYER_MONEY" then
		self:RefreshRows()
		return
	end
	if not scan.running then
		return
	end
	if event == "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED" or event == "AUCTION_HOUSE_BROWSE_RESULTS_ADDED" then
		if scan.active and scan.active.kind == "browse" then
			local addedResults = ...
			if event == "AUCTION_HOUSE_BROWSE_RESULTS_ADDED" and type(addedResults) == "table" then
				scan.active.addedResults = scan.active.addedResults or {}
				for _, info in ipairs(addedResults) do
					scan.active.addedResults[#scan.active.addedResults + 1] = info
				end
			end
			Schedule("settle", 0.10, function()
				FinishBrowseBatch(false)
			end)
		end
	elseif event == "AUCTION_HOUSE_BROWSE_FAILURE" then
		if scan.active and scan.active.kind == "browse" then
			FinishBrowseBatch(true)
		end
	elseif event == "COMMODITY_SEARCH_RESULTS_UPDATED" then
		HandleCommodityResults(...)
	elseif event == "AUCTION_HOUSE_THROTTLED_SYSTEM_READY" then
		if not scan.active then
			Schedule("next", 0, function()
				if scan.phase == "owned" then
					ProcessOwnedAuctions()
				elseif scan.phase == "browse" then
					Reset:ProcessBrowse()
				elseif scan.phase == "deep" then
					Reset:ProcessDeep()
				end
			end)
		end
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
	frame.subtitle:SetText("Catalogue récolte × profondeur réelle de l’HV × liquidité TSM")

	frame.settingsButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	frame.settingsButton:SetSize(104, 26)
	frame.settingsButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -16, -14)
	frame.settingsButton:SetText("Paramètres")
	frame.scanButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	frame.scanButton:SetSize(150, 26)
	frame.scanButton:SetPoint("RIGHT", frame.settingsButton, "LEFT", -8, 0)
	frame.scanButton:SetText("Scanner le marché")
	frame.scanButton:SetScript("OnClick", function()
		Reset:StartScan()
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
	frame.header:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -74)
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
	frame.prepareButton:SetScript("OnClick", function()
		Reset:PreparePurchase()
	end)
	frame.prepareButton:SetScript("OnEnter", function(button)
		GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
		local prepareState, prepareMessage = GetPrepareState(scan.selected)
		if prepareState == "disabled" then
			GameTooltip:AddLine("Préparation indisponible", 1, 0.35, 0.25)
			GameTooltip:AddLine(prepareMessage, 0.85, 0.85, 0.85, true)
		elseif prepareState == "refresh" then
			GameTooltip:AddLine("Actualiser puis acheter", 1, 0.82, 0.25)
			GameTooltip:AddLine("Rescan profond de cet item uniquement. Après validation, un nouveau clic humain lancera l’achat.", 0.85, 0.85, 0.85, true)
		else
			GameTooltip:AddLine("Acheter le reset", 1, 0.82, 0.25)
			GameTooltip:AddLine("Lance une seule quantité. Blizzard renvoie le total, contrôlé avant confirmation.", 0.85, 0.85, 0.85, true)
		end
		GameTooltip:Show()
	end)
	frame.prepareButton:SetScript("OnLeave", function(button)
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
	frame.settingsPanel:SetHeight(58)
	frame.settingsPanel:SetFrameLevel(frame:GetFrameLevel() + 20)
	frame.settingsPanel:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 10 })
	frame.settingsPanel:SetBackdropColor(0.025, 0.03, 0.04, 0.99)
	local roi = CreateSetting(frame.settingsPanel, "ROI min (%)", 12, 70)
	local profit = CreateSetting(frame.settingsPanel, "Profit min (po)", 90, 110)
	local days = CreateSetting(frame.settingsPanel, "Horizon (j)", 208, 84)
	local share = CreateSetting(frame.settingsPanel, "Part marché (%)", 300, 90)
	local target = CreateSetting(frame.settingsPanel, "Cible/réf. (%)", 398, 105)
	local budget = CreateSetting(frame.settingsPanel, "Budget (po)", 511, 110)
	frame.settingInputs = { roi = roi.input, profit = profit.input, days = days.input, share = share.input, target = target.input, budget = budget.input }
	frame.applySettings = CreateFrame("Button", nil, frame.settingsPanel, "UIPanelButtonTemplate")
	frame.applySettings:SetSize(94, 24)
	frame.applySettings:SetPoint("BOTTOMRIGHT", frame.settingsPanel, "BOTTOMRIGHT", -12, 9)
	frame.applySettings:SetText("Appliquer")
	frame.applySettings:SetScript("OnClick", function()
		scan.db.minROI = Clamp(frame.settingInputs.roi:GetText(), 1, 500)
		scan.db.minProfitGold = Clamp(frame.settingInputs.profit:GetText(), 0, 100000000)
		scan.db.maxDays = Clamp(frame.settingInputs.days:GetText(), 0.25, 30)
		scan.db.marketShare = Clamp(frame.settingInputs.share:GetText(), 1, 100)
		scan.db.maxTargetPct = Clamp(frame.settingInputs.target:GetText(), 50, 300)
		scan.db.budgetGold = Clamp(frame.settingInputs.budget:GetText(), 1, 100000000)
		frame.settingsPanel:Hide()
		Reset:RebuildFromCache()
		SetStatus(string.format("Paramètres appliqués • profit net minimum : %s po.", FormatCompactNumber(scan.db.minProfitGold)))
	end)
	frame.settingsButton:SetScript("OnClick", function()
		frame.settingInputs.roi:SetText(tostring(scan.db.minROI))
		frame.settingInputs.profit:SetText(tostring(scan.db.minProfitGold))
		frame.settingInputs.days:SetText(tostring(scan.db.maxDays))
		frame.settingInputs.share:SetText(tostring(scan.db.marketShare))
		frame.settingInputs.target:SetText(tostring(scan.db.maxTargetPct))
		frame.settingInputs.budget:SetText(tostring(scan.db.budgetGold))
		frame.settingsPanel:SetShown(not frame.settingsPanel:IsShown())
	end)
	frame.settingsPanel:Hide()
	scan.frame = frame
	frame:SetScript("OnShow", function()
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
	CreateUI(parent)
	CreateTab(parent)
end

function Reset:Hide()
	if scan.frame then
		scan.frame:Hide()
	end
end
