local _, ns = ...

ns.AuctionPrices = ns.AuctionPrices or {}

local Prices = ns.AuctionPrices
local STORE_VERSION = 1

local function NormalizeItemID(itemID)
	itemID = tonumber(itemID)
	if not itemID or itemID <= 0 then
		return nil
	end
	return math.floor(itemID)
end

local function GetNow()
	if type(time) == "function" then
		return time()
	end
	if type(GetTime) == "function" then
		return math.floor(GetTime())
	end
	return 0
end

local function GetRealmNameCompat()
	local realm
	if type(GetNormalizedRealmName) == "function" then
		realm = GetNormalizedRealmName()
	end
	if (type(realm) ~= "string" or realm == "") and type(GetRealmName) == "function" then
		realm = GetRealmName()
	end
	return type(realm) == "string" and realm ~= "" and realm or nil
end

local function GetRegionScopeKey()
	if type(GetCurrentRegion) == "function" then
		local region = tonumber(GetCurrentRegion())
		if region and region > 0 then
			return "region:" .. tostring(region)
		end
	end
	return nil
end

local function GetScopeKey(kind)
	if kind == "commodity" then
		local regionKey = GetRegionScopeKey()
		if regionKey then
			return regionKey
		end
	end

	local realm = GetRealmNameCompat()
	if realm then
		return "realm:" .. realm
	end
	return nil
end

local function EnsureStore()
	if type(YayaQueueDB) ~= "table" then
		YayaQueueDB = {}
	end
	if type(YayaQueueDB.auctionPrices) ~= "table" then
		YayaQueueDB.auctionPrices = {
			version = STORE_VERSION,
			scopes = {},
		}
	end

	local store = YayaQueueDB.auctionPrices
	store.version = STORE_VERSION
	if type(store.scopes) ~= "table" then
		store.scopes = {}
	end
	return store
end

local function NormalizeUnitPrice(unitPrice)
	unitPrice = tonumber(unitPrice)
	if not unitPrice or unitPrice <= 0 or unitPrice ~= unitPrice then
		return nil
	end
	return math.floor(unitPrice + 0.5)
end

function Prices.GetScopeKey(kind)
	return GetScopeKey(kind)
end

function Prices.GetQuote(itemID, kind)
	itemID = NormalizeItemID(itemID)
	local scopeKey = GetScopeKey(kind)
	if not itemID or not scopeKey then
		return nil
	end

	local store = EnsureStore()
	local scope = store.scopes[scopeKey]
	local quote = scope and scope[itemID]
	if type(quote) ~= "table" then
		return nil
	end

	local unitPrice = NormalizeUnitPrice(quote.unitPrice)
	local capturedAt = tonumber(quote.capturedAt)
	if not unitPrice or not capturedAt or capturedAt <= 0 then
		return nil
	end

	return {
		itemID = itemID,
		kind = kind,
		scopeKey = scopeKey,
		unitPrice = unitPrice,
		capturedAt = capturedAt,
	}
end

function Prices.RecordSearch(itemID, kind, unitPrice)
	itemID = NormalizeItemID(itemID)
	unitPrice = NormalizeUnitPrice(unitPrice)
	local scopeKey = GetScopeKey(kind)
	if not itemID or not unitPrice or not scopeKey then
		return nil
	end

	local store = EnsureStore()
	local scope = store.scopes[scopeKey]
	if type(scope) ~= "table" then
		scope = {}
		store.scopes[scopeKey] = scope
	end

	local quote = {
		itemID = itemID,
		kind = kind,
		scopeKey = scopeKey,
		unitPrice = unitPrice,
		capturedAt = GetNow(),
	}
	scope[itemID] = {
		unitPrice = quote.unitPrice,
		capturedAt = quote.capturedAt,
	}
	return quote
end
