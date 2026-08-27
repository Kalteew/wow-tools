local _, ns = ...

ns.Pricing = ns.Pricing or {}

local Pricing = ns.Pricing
local Util = ns.Util

local DEFAULT_PRICE_SOURCE = "dbmarket"
local TSM_PROVIDER = {
	key = "tsm",
	name = "TradeSkillMaster",
}
local CONTAINER_PROVIDER_KEY = "yaya_container_average"

local function NormalizeUnitPrice(value)
	if type(value) ~= "number" or value ~= value or value <= 0 then
		return nil
	end

	return value
end

local function GetMarketableState(item)
	if not (Util and type(Util.IsItemMarketable) == "function") then
		return nil
	end

	local ok, isMarketable = pcall(Util.IsItemMarketable, item)
	if ok then
		return isMarketable
	end

	return nil
end

local function BuildPriceInfo(item, count, providerKey, state, unitPrice, isMarketable)
	local quantity = math.max(1, tonumber(count) or 1)
	unitPrice = NormalizeUnitPrice(unitPrice)

	return {
		item = item,
		count = quantity,
		providerKey = providerKey,
		state = state,
		isMarketable = isMarketable,
		unitPrice = unitPrice,
		totalPrice = unitPrice and (unitPrice * quantity) or nil,
	}
end

local function ResolveTSMItemString(item)
	if not (TSM_API and type(TSM_API.ToItemString) == "function") then
		return nil
	end

	local candidate
	if type(item) == "string" and item ~= "" then
		candidate = item
	elseif type(item) == "number" and item > 0 then
		candidate = Util.GetItemLink(item) or ("i:%d"):format(item)
	end

	if not candidate then
		return nil
	end

	local ok, itemString = pcall(TSM_API.ToItemString, candidate)
	if ok and type(itemString) == "string" and itemString ~= "" then
		return itemString
	end

	return nil
end

local function GetTSMPrice(item, priceSource)
	local itemString = ResolveTSMItemString(item)
	if not itemString then
		return nil
	end

	return NormalizeUnitPrice(YayaCore.Price.Get(itemString, priceSource or DEFAULT_PRICE_SOURCE))
end

local function GetContainerAveragePrice(item)
	local api = _G.YayaContainerValuesAPI
	if not (api and type(api.GetAverageValue) == "function") then
		return nil
	end

	local ok, value, sampleCount, state = pcall(api.GetAverageValue, item)
	value = ok and NormalizeUnitPrice(value) or nil
	if value and type(sampleCount) == "number" and sampleCount > 0 then
		return value, sampleCount
	end
	if ok and state == "missing_price" and type(sampleCount) == "number" and sampleCount > 0 then
		return false, sampleCount
	end
	return nil
end

function Pricing:RefreshProviders()
	local tsmDetected = ns.IsAddonLoaded("TradeSkillMaster")
		and TSM_API
		and type(TSM_API.GetCustomPriceValue) == "function"
		and type(TSM_API.ToItemString) == "function"
	local priceSourceValid = not not tsmDetected
	local priceSourceError

	if tsmDetected and type(TSM_API.IsCustomPriceValid) == "function" then
		local ok, isValid, validationError = pcall(TSM_API.IsCustomPriceValid, DEFAULT_PRICE_SOURCE)
		if ok then
			priceSourceValid = not not isValid
			priceSourceError = validationError
		end
	end

	self.status = {
		tsmDetected = not not tsmDetected,
		detectedProviderKeys = priceSourceValid and { TSM_PROVIDER.key } or {},
		activeProviderKey = priceSourceValid and TSM_PROVIDER.key or nil,
		selectedProviderKey = priceSourceValid and TSM_PROVIDER.key or nil,
		priceSource = DEFAULT_PRICE_SOURCE,
		priceSourceValid = priceSourceValid,
		priceSourceError = priceSourceError,
	}

	self.activeProvider = priceSourceValid and TSM_PROVIDER or nil
end

function Pricing:Initialize()
	if self.initialized then
		self:RefreshProviders()
		return
	end

	self.initialized = true
	self:RefreshProviders()
end

function Pricing:GetActiveProvider()
	if not self.initialized then
		self:Initialize()
	end

	return self.activeProvider
end

function Pricing:GetProviderName()
	local provider = self:GetActiveProvider()
	return provider and provider.name or NONE
end

function Pricing:GetStatus()
	if not self.initialized then
		self:Initialize()
	end

	return self.status
end

function Pricing:GetPriceInfo(item, count)
	local provider = self:GetActiveProvider()
	local providerKey = provider and provider.key or nil
	local isMarketable = GetMarketableState(item)

	if isMarketable == false then
		return BuildPriceInfo(item, count, providerKey, "not_marketable", nil, false)
	end

	local central = _G.YayaCraftedPriceAPI
	if central and type(central.GetPriceQuote) == "function" then
		local quote = central.GetPriceQuote(item, count, {
			useInventory = true,
			auctionKind = "item",
		})
		if quote then
			local priceInfo = BuildPriceInfo(item, count, quote.source, "priced", quote.amount, isMarketable)
			priceInfo.estimated = quote.estimated == true
			priceInfo.capturedAt = quote.capturedAt
			priceInfo.pricingKey = quote.pricingKey
			return priceInfo
		end
	end

	local containerPrice, containerSamples = GetContainerAveragePrice(item)
	if containerPrice == false then
		local priceInfo = BuildPriceInfo(item, count, CONTAINER_PROVIDER_KEY, "container_average_missing", nil, true)
		priceInfo.sampleCount = containerSamples
		return priceInfo
	end
	if containerPrice then
		local priceInfo = BuildPriceInfo(item, count, CONTAINER_PROVIDER_KEY, "container_average", containerPrice, true)
		priceInfo.sampleCount = containerSamples
		return priceInfo
	end

	if not provider then
		return BuildPriceInfo(item, count, nil, "no_provider", nil, isMarketable)
	end

	local unitPrice = GetTSMPrice(item, self.status and self.status.priceSource or DEFAULT_PRICE_SOURCE)
	if unitPrice then
		return BuildPriceInfo(item, count, provider.key, "priced", unitPrice, isMarketable)
	end

	return BuildPriceInfo(item, count, provider.key, "no_data", nil, isMarketable)
end

function Pricing:GetUnitPrice(item)
	local priceInfo = self:GetPriceInfo(item, 1)
	return priceInfo.unitPrice, priceInfo.providerKey, priceInfo.state
end

function Pricing:GetTotalPrice(item, count)
	local priceInfo = self:GetPriceInfo(item, count)
	return priceInfo.totalPrice, priceInfo.providerKey, priceInfo.unitPrice, priceInfo.state
end
