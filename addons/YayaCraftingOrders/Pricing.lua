local _, ns = ...

ns.Pricing = ns.Pricing or {}

local Pricing = ns.Pricing
local Util = ns.Util

local DEFAULT_PRICE_SOURCE = "dbmarket"
local TSM_PROVIDER = {
	key = "tsm",
	name = "TradeSkillMaster",
}

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
	if not (TSM_API and type(TSM_API.GetCustomPriceValue) == "function") then
		return nil
	end

	local itemString = ResolveTSMItemString(item)
	if not itemString then
		return nil
	end

	local ok, value = pcall(TSM_API.GetCustomPriceValue, priceSource or DEFAULT_PRICE_SOURCE, itemString)
	return NormalizeUnitPrice(ok and value or nil)
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
