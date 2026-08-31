-- Mode Cancel & Repost de l'onglet Reset : lecture des operations Auctioning de
-- TSM, calcul du prix de mise en vente, verdict d'annulation.
--
-- Les fonctions de decision sont pures : elles ne touchent ni l'API Blizzard ni
-- l'etat du scan, uniquement les tables qu'on leur passe. Tests/test_yayareagentsnipersell.lua
-- les execute hors du jeu.

local Sell = {}
YayaReagentSniperSell = Sell

local DEFAULTS = {
	duration = 2,
	postCap = "5",
	keepQuantity = "0",
	maxExpires = "0",
	bidPercent = 1,
	undercut = "0c",
	priceReset = "none",
	aboveMax = "maxPrice",
	cancelUndercut = true,
	cancelRepost = true,
	cancelRepostThreshold = "1g",
	ignoreLowDuration = 0,
}

-- Plancher applique aux objets qu'aucune operation Auctioning ne couvre : on ne
-- revend jamais sous le prix d'achat, ni tres sous le marche recent.
local FALLBACK_FLOOR = "first(105% smartavgbuy, 80% dbrecent)"

-- duration TSM : index, pas une duree. 1 = 12 h, 2 = 24 h, 3 = 48 h.
local DURATION_HOURS = { [1] = 12, [2] = 24, [3] = 48 }

-- ignoreLowDuration : seuil de duree restante sous lequel une enchere n'est plus
-- annulee. Memes bandes que TSM.
local LOW_DURATION_SECONDS = { [1] = 30 * 60, [2] = 2 * 60 * 60, [3] = 12 * 60 * 60 }

local PRICE_KEYS = {
	minPrice = true,
	maxPrice = true,
	normalPrice = true,
}

local controller = nil

function Sell.Init(context)
	controller = type(context) == "table" and context or nil
end

function Sell.GetDurationHours(duration)
	return DURATION_HOURS[tonumber(duration) or 0] or 24
end

function Sell.GetFallbackFloorSource()
	return FALLBACK_FLOOR
end

-- TSM arrondit les cles de prix au silver superieur ; GetCustomPriceValue ne le
-- fait pas. Sans cet arrondi, un prix calcule ici differerait de celui que TSM
-- proposerait pour la meme operation.
function Sell.RoundPrice(value)
	value = tonumber(value)
	if not value or value <= 0 then
		return nil
	end
	return math.ceil(value / 100) * 100
end

local function EvaluatePrice(source, itemString)
	if not controller or type(controller.getCustomPriceValue) ~= "function" then
		return nil
	end
	return controller.getCustomPriceValue(source, itemString)
end

-- GetCustomPriceValue("0", ...) renvoie nil et non 0 : le parametre interne
-- allowZero de TSM n'est pas transmis par son API publique. Or "0" est la valeur
-- par defaut de keepQuantity, et une valeur legitime de postCap.
local function EvaluateQuantity(source, itemString, default)
	if source == nil then
		return default
	end
	local text = tostring(source)
	if text == "" then
		return default
	end
	local direct = tonumber(text)
	if direct then
		return math.max(0, math.floor(direct))
	end
	local value = EvaluatePrice(text, itemString)
	if not value then
		return 0
	end
	return math.max(0, math.floor(value))
end

-- Lit une cle d'operation en suivant la chaine relationships : une cle peut etre
-- heritee d'une autre operation, et la valeur locale serait alors perimee.
local function ReadSetting(operation, key)
	if type(operation) ~= "table" then
		return DEFAULTS[key]
	end
	if operation.__operations and operation.__name
		and controller and type(controller.resolveOperationSetting) == "function"
	then
		local value = controller.resolveOperationSetting(operation.__operations, operation.__name, key, nil)
		if value ~= nil then
			return value
		end
	end
	local value = operation[key]
	if value ~= nil then
		return value
	end
	return DEFAULTS[key]
end

Sell.ReadSetting = ReadSetting

function Sell.GetAuctioningOperation(itemString)
	if not controller or type(controller.getOperationForItem) ~= "function" then
		return nil
	end
	local ok, settings, operationName, operations = pcall(controller.getOperationForItem, itemString, "Auctioning")
	if not ok or type(settings) ~= "table" then
		return nil
	end
	-- On garde de quoi resoudre les relationships plus tard, sans copier la table
	-- de TSM : elle est vivante et ne doit jamais etre modifiee.
	local resolved = {}
	for key, value in pairs(settings) do
		resolved[key] = value
	end
	resolved.__name = operationName
	resolved.__operations = operations
	return resolved
end

-- Quantite a poster. En Retail il n'y a pas de taille de pile : une seule
-- enchere de min(postCap, disponible - keepQuantity - reserve).
function Sell.GetPostQuantity(operation, numHave, itemString, reserved)
	numHave = math.max(0, math.floor(tonumber(numHave) or 0))
	reserved = math.max(0, math.floor(tonumber(reserved) or 0))
	local postCap = EvaluateQuantity(ReadSetting(operation, "postCap"), itemString, 5)
	local keepQuantity = EvaluateQuantity(ReadSetting(operation, "keepQuantity"), itemString, 0)
	local available = numHave - keepQuantity - reserved
	if available <= 0 then
		return 0, "reserve"
	end
	if postCap <= 0 then
		-- postCap = 0 signifie litteralement « poster 0 », pas « sans limite ».
		return 0, "postCap"
	end
	return math.min(postCap, available), nil
end

local function ResolvePriceKey(operation, key, itemString, visited)
	visited = visited or {}
	if visited[key] then
		return nil
	end
	visited[key] = true
	if not PRICE_KEYS[key] then
		return nil
	end
	local source = ReadSetting(operation, key)
	if not source then
		return nil
	end
	return Sell.RoundPrice(EvaluatePrice(source, itemString))
end

-- aboveMax et priceReset ne portent pas un prix mais le nom d'une autre cle.
local function ResolveRedirect(operation, key, itemString)
	local target = ReadSetting(operation, key)
	if type(target) ~= "string" or target == "none" or target == "ignore" then
		return nil, target
	end
	return ResolvePriceKey(operation, target, itemString), target
end

--- Prix de mise en vente d'un objet.
-- context = {
--   itemString, operation (ou nil),
--   marketPrice   = plus basse enchere d'un autre joueur, nil si aucune,
--   floorPrice    = plancher deja evalue (optionnel, sinon evalue ici),
-- }
-- Retourne price, reason. price = nil quand il ne faut pas poster ; reason dit
-- pourquoi, et s'affiche dans le detail de la ligne.
function Sell.ComputePostPrice(context)
	local itemString = context.itemString
	local operation = context.operation
	local market = tonumber(context.marketPrice)
	if market and market <= 0 then
		market = nil
	end

	if not operation then
		-- Aucune operation ne couvre l'objet : on undercut le marche, borne par le
		-- plancher automatique.
		local floor = context.floorPrice
		if floor == nil then
			floor = Sell.RoundPrice(EvaluatePrice(FALLBACK_FLOOR, itemString))
		end
		if not floor then
			return nil, "Aucun plancher connu : ni prix d'achat moyen ni marche recent."
		end
		if not market then
			return floor, "Aucune concurrence : mise en vente au plancher."
		end
		if market < floor then
			return nil, "Marche sous le plancher de revente : mise en vente reportee."
		end
		return market, nil
	end

	local undercut = EvaluatePrice(ReadSetting(operation, "undercut"), itemString) or 0
	local minPrice = ResolvePriceKey(operation, "minPrice", itemString)
	local maxPrice = ResolvePriceKey(operation, "maxPrice", itemString)
	local normalPrice = ResolvePriceKey(operation, "normalPrice", itemString)

	if not market then
		if not normalPrice then
			return nil, "Aucune concurrence et pas de prix normal exploitable."
		end
		return normalPrice, "Aucune concurrence : prix normal de l'operation."
	end

	if maxPrice and market > maxPrice then
		local redirected, target = ResolveRedirect(operation, "aboveMax", itemString)
		if not redirected then
			return nil, "Concurrence au-dessus du prix maximum (" .. tostring(target) .. ")."
		end
		return redirected, "Concurrence au-dessus du maximum : repli sur " .. tostring(target) .. "."
	end

	local price = market - undercut
	if minPrice and price < minPrice then
		local redirected, target = ResolveRedirect(operation, "priceReset", itemString)
		if not redirected then
			return nil, "Concurrence sous le prix minimum de l'operation."
		end
		return redirected, "Concurrence sous le minimum : repli sur " .. tostring(target) .. "."
	end
	if price <= 0 then
		return nil, "Prix calcule nul."
	end
	return price, nil
end

--- Faut-il annuler une enchere ?
-- auction = { unitPrice, timeLeft, quantity }
-- market  = { lowestOther, hasOtherAtSamePrice, targetPrice }
--   lowestOther         = plus basse enchere d'un autre joueur, nil si aucune
--   hasOtherAtSamePrice = un autre joueur est au meme prix que moi
--   targetPrice         = prix auquel on reposterait (issu de ComputePostPrice)
-- Retourne shouldCancel, reason.
function Sell.ShouldCancel(auction, market, operation, itemString)
	if type(auction) ~= "table" or type(market) ~= "table" then
		return false, nil
	end
	local myPrice = tonumber(auction.unitPrice)
	if not myPrice or myPrice <= 0 then
		return false, nil
	end

	if ReadSetting(operation, "cancelUndercut") == false
		and ReadSetting(operation, "cancelRepost") == false
	then
		return false, "L'operation TSM interdit l'annulation."
	end

	local ignoreLowDuration = tonumber(ReadSetting(operation, "ignoreLowDuration")) or 0
	local threshold = LOW_DURATION_SECONDS[ignoreLowDuration]
	local timeLeft = tonumber(auction.timeLeftSeconds)
	if threshold and timeLeft and timeLeft <= threshold then
		return false, "Duree restante trop courte pour rentabiliser l'annulation."
	end

	local lowestOther = tonumber(market.lowestOther)
	if ReadSetting(operation, "cancelUndercut") ~= false then
		if lowestOther and lowestOther < myPrice then
			return true, "Sous-cote : un autre vendeur est moins cher."
		end
		-- En Retail (LIFO), une enchere posee au meme prix apres la mienne passe
		-- devant : TSM la traite comme une sous-cotation.
		if market.hasOtherAtSamePrice then
			return true, "Sous-cote : un autre vendeur est au meme prix."
		end
	end

	if ReadSetting(operation, "cancelRepost") ~= false then
		local target = tonumber(market.targetPrice)
		if target and target > myPrice then
			local repostThreshold = EvaluatePrice(ReadSetting(operation, "cancelRepostThreshold"), itemString) or 10000
			if (target - myPrice) >= repostThreshold then
				return true, "A reposter plus haut : la concurrence a disparu."
			end
		end
	end

	return false, nil
end

-- ---------------------------------------------------------------------------
-- Acces au jeu : sacs et reservations de craft
-- ---------------------------------------------------------------------------

local function GetContainerSlots(bagID)
	if C_Container and type(C_Container.GetContainerNumSlots) == "function" then
		return tonumber(C_Container.GetContainerNumSlots(bagID)) or 0
	end
	return 0
end

local function GetContainerItem(bagID, slotIndex)
	if C_Container and type(C_Container.GetContainerItemInfo) == "function" then
		local ok, info = pcall(C_Container.GetContainerItemInfo, bagID, slotIndex)
		return ok and info or nil
	end
	return nil
end

--- Objets des sacs qui peuvent partir a l'hotel des ventes en commodite.
-- Retourne { [itemID] = { quantity, location, slots } }.
function Sell.EnumerateSellableBagItems(isCommodity)
	local result = {}
	local lastBag = Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag or 5
	for bagID = 0, lastBag do
		for slotIndex = 1, GetContainerSlots(bagID) do
			local info = GetContainerItem(bagID, slotIndex)
			local itemID = info and tonumber(info.itemID)
			if itemID and not info.isLocked and not info.hasNoValue then
				local sellable = true
				if type(isCommodity) == "function" then
					sellable = isCommodity(itemID) == true
				end
				if sellable and ItemLocation and type(ItemLocation.CreateFromBagAndSlot) == "function" then
					local location = ItemLocation:CreateFromBagAndSlot(bagID, slotIndex)
					local bound = false
					if C_Item and type(C_Item.IsBound) == "function" then
						local ok, value = pcall(C_Item.IsBound, location)
						bound = ok and value == true
					end
					if not bound then
						local entry = result[itemID]
						if not entry then
							entry = { quantity = 0, location = location, slots = 0 }
							result[itemID] = entry
						end
						entry.quantity = entry.quantity + (tonumber(info.stackCount) or 0)
						entry.slots = entry.slots + 1
						-- On poste depuis la plus grosse pile : Blizzard consomme les
						-- piles suivantes automatiquement si la quantite depasse.
						if (tonumber(info.stackCount) or 0) > (entry.bestStack or 0) then
							entry.bestStack = tonumber(info.stackCount) or 0
							entry.location = location
						end
					end
				end
			end
		end
	end
	return result
end

--- Quantites reservees par la file de craft TSM : on ne vend pas les reactifs
-- que l'utilisateur a prevu de consommer.
function Sell.GetCraftingReservations()
	local reserved = {}
	if type(TSM_API) ~= "table" or type(TSM_API.CraftingQueueIterator) ~= "function" then
		return reserved
	end
	local ok, iterator = pcall(TSM_API.CraftingQueueIterator)
	if not ok or type(iterator) ~= "function" then
		return reserved
	end
	local success = pcall(function()
		for _, recipeString, _, quantity in iterator do
			local materials = {}
			if type(TSM_API.GetCraftingQueueItemMaterials) == "function" then
				pcall(TSM_API.GetCraftingQueueItemMaterials, recipeString, materials)
			end
			for itemString, materialQuantity in pairs(materials) do
				local itemID = tonumber(string.match(tostring(itemString), "^i:(%d+)"))
				if itemID then
					local need = (tonumber(materialQuantity) or 0) * (tonumber(quantity) or 1)
					reserved[itemID] = (reserved[itemID] or 0) + need
				end
			end
		end
	end)
	if not success then
		return {}
	end
	return reserved
end

return Sell
