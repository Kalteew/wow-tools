local _, ns = ...

ns.BrowsePane = ns.BrowsePane or {}

local Pane = ns.BrowsePane
local Pricing = ns.Pricing
local Util = ns.Util
local L = ns.L

local function LF(key, ...)
	if ns.LF then
		return ns.LF(key, ...)
	end

	local value = (L and L[key]) or key
	if select("#", ...) > 0 then
		return value:format(...)
	end

	return value
end

local ROW_HEIGHT = 62
local HEADER_HEIGHT = 20
local SELECT_WIDTH = 68
local ORDER_WIDTH = 340
local COST_WIDTH = 96
local REWARD_WIDTH = 124
local PROFIT_WIDTH = 92
local PATRON_WIDTH = 28
local PRODUCT_ICON_SIZE = 50
local PRODUCT_ICON_LEFT_OFFSET = 4
local PRODUCT_ICON_TOP_OFFSET = -6
local PRODUCT_TEXT_GAP = 8
local REAGENT_ICON_SIZE = 28
local ICON_GROUP_SPACER = 8
local MUTABLE_SLOT_TYPE = Enum.TradeskillSlotDataType and Enum.TradeskillSlotDataType.ModifiedReagent
local CONTENT_WIDTH = SELECT_WIDTH + ORDER_WIDTH + COST_WIDTH + REWARD_WIDTH + PROFIT_WIDTH + PATRON_WIDTH + 24
local ROOT_WIDTH = 800
local ROOT_HEIGHT = 542.5
local ROOT_RIGHT_OFFSET = -2
local ROOT_BOTTOM_OFFSET = 3
local BACKGROUND_TOP_OFFSET = -0.5
local HEADER_TOP_OFFSET = 19
local SCROLL_TOP_OFFSET = -2
local ROW_ICON_Y_OFFSET = -28
local CREATE_LIST_BUTTON_WIDTH = 30
local CREATE_LIST_BUTTON_HEIGHT = 18
local CREATE_LIST_BUTTON_LEFT_OFFSET = 4
local CREATE_LIST_BUTTON_TOP_OFFSET = 19
local FILTER_BUTTON_WIDTH = 88
local FILTER_BUTTON_HEIGHT = HEADER_HEIGHT
local FILTER_BUTTON_RIGHT_OFFSET = -2
local FILTER_BUTTON_TOP_OFFSET = HEADER_TOP_OFFSET
local FILTER_PANEL_WIDTH = 188
local FILTER_PANEL_HEIGHT = 122
local REQUEST_COOLDOWN = 0.75
local REQUEST_TIMEOUT = 12
local REQUEST_SETTLE_DELAY = 0.25
local REQUEST_READINESS_RETRY_DELAY = 0.15
local REQUEST_READINESS_RETRY_LIMIT = 20
Pane.retryConfig = {
	requestFailureDelay = 0.5,
	requestFailureLimit = 3,
	headlessRequestDelay = 0.5,
	headlessRequestLimit = 3,
	canRequestRecoveryDelay = 1,
	headlessFallbackTimeout = 10,
	orderTypeDelay = 0.15,
	orderTypeLimit = 20,
	autoScanDelay = 0.1,
	autoScanDuration = 3.0,
	emptySyncDelay = 0.5,
	emptySyncLimit = 3,
}
local ITEM_DATA_REFRESH_DELAY = 0.75
local INITIALIZE_RETRY_DELAY = 0.1
local DONT_BUY_OVERLAY_TEXTURE = "Interface\\RaidFrame\\ReadyCheck-NotReady"
local DETAIL_WARNING_ICON_TEXTURE = "Interface\\DialogFrame\\UI-Dialog-Icon-AlertNew"
local DETAIL_WARNING_UPDATE_DELAY = 0.05
local RECIPE_FILTER_ALL = "all"
local RECIPE_FILTER_KNOWN = "known"
local RECIPE_FILTER_UNKNOWN = "unknown"
local CONCENTRATION_FILTER_ALL = "all"
local CONCENTRATION_FILTER_NEEDS = "needs"
local CONCENTRATION_FILTER_NONE = "none"
local PATRON_VALUE = {
	knowledgePointGold = 1000,
	firstCraft = 1000 * COPPER_PER_GOLD,
	skillUp = 200 * COPPER_PER_GOLD,
	moxiePerPointGold = 4,
	concentrationAlchemy = 3 * COPPER_PER_GOLD,
	concentrationLeatherworking = 0,
	concentrationDefault = 1 * COPPER_PER_GOLD,
}
local BORDER_BY_ITEM_QUALITY = {
	[0] = "Professions-Slot-Frame",
	"Professions-Slot-Frame",
	"Professions-Slot-Frame-Green",
	"Professions-Slot-Frame-Blue",
	"Professions-Slot-Frame-Epic",
	"Professions-Slot-Frame-Legendary",
}

local REWARD_KNOWLEDGE_ITEMS = {
	[228724] = 1,
	[228725] = 2,
	[228726] = 1,
	[228727] = 2,
	[228728] = 1,
	[228729] = 2,
	[228730] = 1,
	[228731] = 2,
	[228732] = 1,
	[228733] = 2,
	[228734] = 1,
	[228735] = 2,
	[228736] = 1,
	[228737] = 2,
	[228738] = 1,
	[228739] = 2,
	[246320] = 1,
	[246321] = 2,
	[246322] = 1,
	[246323] = 2,
	[246324] = 1,
	[246325] = 2,
	[246326] = 1,
	[246327] = 2,
	[246328] = 1,
	[246329] = 2,
	[246330] = 1,
	[246331] = 2,
	[246332] = 1,
	[246333] = 2,
	[246334] = 1,
	[246335] = 2,
}

local MOXIE_CURRENCY_IDS = {
	[3256] = true,
	[3257] = true,
	[3258] = true,
	[3259] = true,
	[3261] = true,
	[3262] = true,
	[3263] = true,
	[3266] = true,
}

local QUALITY_TICK_GREEN = "common-icon-checkmark"
local QUALITY_TICK_AMBER = "common-icon-checkmark-yellow"
local QUALITY_WEIGHT_BASE = 1000
local EMPTY_STATE_LOADING_TEXT = L.EMPTY_STATE_LOADING
local EMPTY_STATE_EMPTY_TEXT = L.EMPTY_STATE_EMPTY
local EMPTY_STATE_FILTERED_TEXT = L.EMPTY_STATE_FILTERED

local EXPIRE_THRESHOLDS = {
	{"|cffa0a0a0", 6 * 3600},
	{"|cffe8e800", 3600},
	{"|cffd84000", -math.huge},
}

Pane.sortKey = ns.DEFAULT_SORT_KEY
Pane.sortAscending = false
Pane.allOrders = {}
Pane.rows = {}
Pane.orders = {}
Pane.selectedOrderIDsByProfession = {}
Pane.selectedOrderIDs = {}
Pane.preparedOrderCache = {}
Pane.knowledgeProgressCache = {}
Pane.autoQueuedOrderIDsBySession = {}
Pane.rebuildGeneration = 0
Pane.ordersGeneration = 0
Pane.hasUnresolvedItemData = false
Pane.unresolvedItemIDs = {}
Pane.needsRequest = false
Pane.needsRebuild = false
Pane.needsRender = false
Pane.autoScanCompletedByProfession = {}
Pane.autoScanFlow = nil
Pane.autoScanSerial = 0
Pane.headlessRequestSerial = 0
Pane.autoScanOpeningProfession = nil
Pane.autoScanOpeningRequested = false
Pane.craftingOrdersCanRequest = nil
Pane.craftingOrdersCanRequestProfession = nil
Pane.pendingReason = nil
Pane.pendingDueAt = nil
Pane.visibleSessionId = 0
Pane.requestReadinessRetryCount = 0
Pane.recipeFilter = RECIPE_FILTER_ALL
Pane.concentrationFilter = CONCENTRATION_FILTER_ALL

local function FormatCount(count, alwaysShow)
	if count and (count > 1 or (alwaysShow and count > 0)) then
		return count
	end
	return ""
end

local function FormatItemCountLabel(quantity, label)
	return LF("ITEM_COUNT_FORMAT", quantity or 0, label or UNKNOWN)
end

local function GetProfessionSelectionKey(profession)
	if profession == nil then
		return "none"
	end

	return tostring(profession)
end

local function GetDontBuyKey(itemID)
	if type(itemID) ~= "number" or itemID <= 0 then
		return nil
	end

	return tostring(itemID)
end

local function GetExpensiveIngredientThresholdPercent()
	local value = tonumber(ns.GetConfig("expensiveIngredientThresholdPercent")) or 10
	return math.max(0, math.min(100, math.floor(value + 0.5)))
end

local function NormalizeReagentGroupName(name)
	if type(name) ~= "string" then
		return nil
	end

	name = name:gsub("|A.-|a", "")
	name = name:gsub("%s+", " ")
	name = name:match("^%s*(.-)%s*$")
	if not name or name == "" then
		return nil
	end

	return name:lower()
end

local function GetExpensiveIngredientGroupKey(option)
	if not option or (option.reagentQuality or 0) <= 0 then
		return nil
	end

	return NormalizeReagentGroupName(option.name or Util.GetItemName(option.itemLink or option.itemID))
end

local function IsPricedMarketOption(option)
	return option
		and option.priceState ~= "not_marketable"
		and type(option.unitPrice) == "number"
		and option.unitPrice > 0
end

local function IsCheaperWarningOption(left, right)
	if not left then
		return false
	end
	if not right then
		return true
	end
	if (left.unitPrice or math.huge) ~= (right.unitPrice or math.huge) then
		return (left.unitPrice or math.huge) < (right.unitPrice or math.huge)
	end

	return (left.reagentQuality or math.huge) < (right.reagentQuality or math.huge)
end

local function GetWarningColor()
	return WARNING_FONT_COLOR or NORMAL_FONT_COLOR or { r = 1, g = 0.82, b = 0 }
end

local function GetSavingsColor()
	return GREEN_FONT_COLOR or HIGHLIGHT_FONT_COLOR or { r = 0.25, g = 0.9, b = 0.35 }
end

local function GetMutedTooltipColor()
	return HIGHLIGHT_FONT_COLOR or { r = 0.9, g = 0.9, b = 0.9 }
end

local function GetDontBuyMap()
	if ns.GetDontBuyList then
		return ns.GetDontBuyList()
	end

	local db = ns.GetDatabase()
	if type(db) ~= "table" then
		return nil
	end

	db.dontBuyItems = type(db.dontBuyItems) == "table" and db.dontBuyItems or {}
	return db.dontBuyItems
end

function Pane:IsDontBuyItem(itemID)
	local key = GetDontBuyKey(itemID)
	local map = GetDontBuyMap()
	return key and map and not not map[key] or false
end

function Pane:SetDontBuyItem(itemID, value)
	local key = GetDontBuyKey(itemID)
	local map = GetDontBuyMap()
	if not (key and map) then
		return
	end

	if value then
		map[key] = true
	else
		map[key] = nil
	end
end

function Pane:ToggleDontBuyItem(itemID)
	if not itemID then
		return false
	end

	local isIgnored = not self:IsDontBuyItem(itemID)
	self:SetDontBuyItem(itemID, isIgnored)
	if self.root and self.root:IsShown() then
		self:RenderRows()
	end
	return isIgnored
end

local function LinkHasDisplayName(link)
	return type(link) == "string" and link ~= "" and not link:find("%[%]")
end

local function GetReagentItemIdentity(itemID, itemLink)
	if LinkHasDisplayName(itemLink) then
		return itemLink
	end

	if itemID and itemID > 0 then
		return itemID
	end

	return itemLink
end

local function GetShoppingEntryGroupKey(entry)
	local itemKey = entry and (entry.itemID or entry.itemLink) or "?"
	local reagentQuality = entry and entry.reagentQuality or 0
	return ("%s:%s"):format(tostring(itemKey), tostring(reagentQuality))
end

function Pane:GetYayaQueueAPI()
	local api = _G.YayaQueueAPI
	if type(api) ~= "table" or type(api.AddRecipe) ~= "function" then
		return nil
	end
	return api
end

local function FormatSignedMoney(value)
	if value == nil then
		return NONE
	end

	local amount = math.floor(math.abs(value))
	local formatted = GetMoneyString(amount, true)
	if value < 0 then
		return "-" .. formatted
	end

	return formatted
end

local function NumericSortValue(value)
	return type(value) == "number" and value or 0
end

local function IsExcludedFromMarketValue(priceState)
	return priceState == "not_marketable"
end

local function GetPriceDisplayText(totalPrice, priceState)
	if totalPrice then
		return Util.FormatMoney(totalPrice)
	end

	if IsExcludedFromMarketValue(priceState) then
		return L.PRICE_NOT_MARKETABLE
	end

	return L.PRICE_NO_MARKET_DATA
end

local function GetMarketPreferenceRank(priceState, unitPrice)
	if IsExcludedFromMarketValue(priceState) then
		return 2
	end

	if type(unitPrice) == "number" and unitPrice > 0 then
		return 0
	end

	return 1
end

local function GetGoldIconMarkup()
	return YayaCore.Money.GetGoldIconMarkup()
end

local function FormatGoldOnly(value, signed)
	return YayaCore.Money.FormatGoldOnly(value, signed)
end

local function FormatListMoney(value, signed)
	if value == nil then
		return NONE
	end

	if ns.GetConfig("showSilverCopperInList") then
		return signed and FormatSignedMoney(value) or Util.FormatMoney(value)
	end

	return FormatGoldOnly(value, signed)
end

local function FormatTimeRemaining(secondsRemaining)
	if secondsRemaining >= 86400 then
		return LF("TIME_SHORT_DAYS_FORMAT", math.max(1, math.ceil(secondsRemaining / 86400)))
	elseif secondsRemaining >= 3600 then
		return LF("TIME_SHORT_HOURS_FORMAT", math.max(1, math.ceil(secondsRemaining / 3600)))
	end

	return LF("TIME_SHORT_MINUTES_FORMAT", math.max(1, math.ceil(secondsRemaining / 60)))
end

local function GetTimeColorCode(secondsRemaining)
	for _, thresholdInfo in ipairs(EXPIRE_THRESHOLDS) do
		if secondsRemaining > thresholdInfo[2] then
			return thresholdInfo[1]
		end
	end

	return EXPIRE_THRESHOLDS[#EXPIRE_THRESHOLDS][1]
end

local function GetTimeColor(secondsRemaining)
	local colorCode = GetTimeColorCode(secondsRemaining)
	local red, green, blue = colorCode:match("(%x%x)(%x%x)(%x%x)$")
	if red and green and blue then
		return tonumber(red, 16) / 255, tonumber(green, 16) / 255, tonumber(blue, 16) / 255
	end

	return 0.63, 0.63, 0.63
end

local function GetTimeHeaderText()
	if type(CreateAtlasMarkup) == "function" then
		return CreateAtlasMarkup("auctionhouse-icon-clock", 14, 14, 0, -1)
	end

	return L.TIME_HEADER
end

local function GetAtlasMarkup(atlas, width, height, offsetX, offsetY)
	if not atlas or atlas == "" then
		return ""
	end

	if type(CreateAtlasMarkup) == "function" then
		return CreateAtlasMarkup(atlas, width, height, offsetX or 0, offsetY or 0)
	end

	return ("|A:%s:%d:%d:%d:%d|a"):format(atlas, width or 0, height or 0, offsetX or 0, offsetY or 0)
end

local function GetAtlasInfoData(atlas)
	if not atlas or atlas == "" then
		return nil
	end

	if C_Texture and type(C_Texture.GetAtlasInfo) == "function" then
		return C_Texture.GetAtlasInfo(atlas)
	end

	if type(GetAtlasInfo) == "function" then
		return GetAtlasInfo(atlas)
	end

	return nil
end

local function GetAspectCorrectAtlasMarkup(atlas, width, height, offsetX, offsetY)
	local resolvedWidth = tonumber(width) or 0
	local resolvedHeight = tonumber(height) or 0
	local atlasInfo = GetAtlasInfoData(atlas)

	if atlasInfo and atlasInfo.width and atlasInfo.height and atlasInfo.height > 0 and resolvedHeight > 0 then
		local aspect = atlasInfo.width / atlasInfo.height
		resolvedWidth = math.max(1, math.floor((resolvedHeight * aspect) + 0.5))
	end

	return GetAtlasMarkup(atlas, resolvedWidth, resolvedHeight, tonumber(offsetX) or 0, tonumber(offsetY) or 0)
end

local function NormalizeProfessionQualityMarkup(text)
	if type(text) ~= "string" or text == "" or not text:find("|A:Professions%-ChatIcon%-Quality") then
		return text
	end

	return text:gsub("|A:(Professions%-ChatIcon%-Quality[^:|]*):(%d+):(%d+):?(-?%d*):?(-?%d*)[^|]*|a", function(atlas, width, height, offsetX, offsetY)
		return GetAspectCorrectAtlasMarkup(atlas, width, height, offsetX, offsetY)
	end)
end

local function StripProfessionQualityMarkup(text)
	if type(text) ~= "string" or text == "" or not text:find("|A:Professions%-ChatIcon%-Quality") then
		return text
	end

	text = text:gsub("|A:Professions%-ChatIcon%-Quality[^|]*|a", "")
	text = text:gsub("%s%s+", " ")
	text = text:gsub("%s+|h", "|h")
	text = text:gsub("|h%s+", "|h ")
	return strtrim(text)
end

local function GetRefreshDelay(reason)
	if reason == "show" or reason == "order-type" then
		return 0.01
	elseif reason == "sort" or reason == "filter" then
		return 0
	elseif reason == "pricing-db" or reason == "trade-skill-source" or (type(reason) == "string" and reason:match("^config:")) then
		return 0.1
	elseif reason == "request-success" then
		return REQUEST_SETTLE_DELAY
	elseif reason == "order-count" or reason == "rewards" or reason == "can-request" or reason == "request-timeout" then
		return 0.15
	elseif reason == "item-data" then
		return ITEM_DATA_REFRESH_DELAY
	end

	return 0.05
end

local function GetBorderAtlas(itemID, quality)
	local itemQuality = quality
	if itemQuality == nil and itemID then
		itemQuality = select(3, GetItemInfo(itemID))
	end
	return BORDER_BY_ITEM_QUALITY[itemQuality or 1] or BORDER_BY_ITEM_QUALITY[1]
end

local function GetCurrencyQuantity(currencyID)
	if not currencyID then
		return 0
	end
	local info = C_CurrencyInfo.GetCurrencyInfo(currencyID)
	return info and info.quantity or 0
end

local function GetCurrencyLink(currencyID, count)
	if not currencyID then
		return nil
	end
	return C_CurrencyInfo.GetCurrencyLink(currencyID, count or 1)
end

local function FormatConcentrationValue(value)
	if value == nil then
		return UNKNOWN
	elseif value == math.huge then
		return UNAVAILABLE
	end
	return tostring(value)
end

local function BuildConcentrationExtraLines(concentration)
	if type(concentration) ~= "table" then
		return nil
	end

	local lines = {}
	if concentration.lowestFillCost ~= nil then
		lines[#lines + 1] = LF("CONCENTRATION_LOWEST_MATERIALS_FORMAT", FormatConcentrationValue(concentration.lowestFillCost))
	end
	if concentration.ownedFillCost ~= nil then
		lines[#lines + 1] = LF("CONCENTRATION_WITH_OWNED_FORMAT", FormatConcentrationValue(concentration.ownedFillCost))
	end
	if concentration.bestOwnedCost ~= nil then
		lines[#lines + 1] = LF("CONCENTRATION_BEST_OWNED_FORMAT", FormatConcentrationValue(concentration.bestOwnedCost))
	end
	if concentration.bestMarketCost ~= nil then
		lines[#lines + 1] = LF("CONCENTRATION_BEST_MARKET_FORMAT", FormatConcentrationValue(concentration.bestMarketCost))
	end

	return #lines > 0 and lines or nil
end

local function CreateHeaderButton(parent, text, sortKey, width, xOffset)
	local button = CreateFrame("Button", nil, parent, "ColumnDisplayButtonShortTemplate")
	button:SetPoint("TOPLEFT", parent, "TOPLEFT", xOffset, HEADER_TOP_OFFSET)
	button:SetSize(width, HEADER_HEIGHT)
	button:SetText(text)
	button.sortKey = sortKey
	button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	return button
end

local function CreateBlizzardFilterButton(parent)
	return CreateFrame("Button", nil, parent)
end

local function SetFallbackFilterButtonLabel(button, text)
	if not button then
		return
	end

	if button.fallbackText and type(button.fallbackText.SetText) == "function" then
		button.fallbackText:SetText(text)
	end
end

local function CreateFallbackFilterButtonVisuals(button, text)
	if not button or button.fallbackVisualsCreated then
		SetFallbackFilterButtonLabel(button, text)
		return
	end

	button.fallbackVisualsCreated = true
	button.fallbackBackground = button:CreateTexture(nil, "BACKGROUND")
	button.fallbackBackground:SetAllPoints()
	button.fallbackBackground:SetColorTexture(0.08, 0.08, 0.075, 0.95)
	button.fallbackBorder = button:CreateTexture(nil, "BORDER")
	button.fallbackBorder:SetAllPoints()
	button.fallbackBorder:SetColorTexture(0.32, 0.32, 0.3, 0.75)
	button.fallbackInset = button:CreateTexture(nil, "ARTWORK")
	button.fallbackInset:SetPoint("TOPLEFT", button, "TOPLEFT", 2, -2)
	button.fallbackInset:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)
	button.fallbackInset:SetColorTexture(0.03, 0.03, 0.028, 0.95)
	button.fallbackText = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	button.fallbackText:SetPoint("LEFT", button, "LEFT", 8, 0)
	button.fallbackText:SetPoint("RIGHT", button, "RIGHT", -17, 0)
	button.fallbackText:SetJustifyH("CENTER")
	button.fallbackArrow = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	button.fallbackArrow:SetPoint("RIGHT", button, "RIGHT", -7, 0)
	button.fallbackArrow:SetText(">")
	SetFallbackFilterButtonLabel(button, text)
end

local function SetFallbackFilterButtonVisualsShown(button, shown)
	if not button then
		return
	end

	for _, key in ipairs({ "fallbackBackground", "fallbackBorder", "fallbackInset", "fallbackText", "fallbackArrow" }) do
		local region = button[key]
		if region then
			region:SetShown(shown)
		end
	end
end

local function IsDescendantOf(frame, ancestor)
	local parent = frame
	while parent do
		if parent == ancestor then
			return true
		end
		parent = type(parent.GetParent) == "function" and parent:GetParent() or nil
	end

	return false
end

local function GetFrameLabelText(frame)
	if not frame then
		return nil
	end

	if type(frame.GetText) == "function" then
		local text = frame:GetText()
		if type(text) == "string" and text ~= "" then
			return text
		end
	end

	for _, key in ipairs({ "Text", "Label", "text" }) do
		local region = frame[key]
		if region and type(region.GetText) == "function" then
			local text = region:GetText()
			if type(text) == "string" and text ~= "" then
				return text
			end
		end
	end

	local regionCount = type(frame.GetRegions) == "function" and select("#", frame:GetRegions()) or 0
	for index = 1, regionCount do
		local region = select(index, frame:GetRegions())
		if region and type(region.GetObjectType) == "function" and region:GetObjectType() == "FontString" and type(region.GetText) == "function" then
			local text = region:GetText()
			if type(text) == "string" and text ~= "" then
				return text
			end
		end
	end

	return nil
end

local function FindLeftRecipeFilterButton(root)
	local expectedText = (L and L.TOOLBAR_FILTER_BUTTON) or FILTER or "Filter"
	local bestButton
	local bestScore = math.huge
	local rootLeft = root and type(root.GetLeft) == "function" and root:GetLeft()
	local rootTop = root and type(root.GetTop) == "function" and root:GetTop()

	local function visit(frame, depth)
		if not frame or depth > 12 then
			return
		end

		if frame ~= root and not IsDescendantOf(frame, root) and type(frame.GetObjectType) == "function" then
			local objectType = frame:GetObjectType()
			local text = GetFrameLabelText(frame)
			if (objectType == "Button" or objectType == "DropdownButton") and text == expectedText then
				local width = type(frame.GetWidth) == "function" and frame:GetWidth() or 0
				local height = type(frame.GetHeight) == "function" and frame:GetHeight() or 0
				if width >= 40 and width <= 180 and height >= 14 and height <= 40 then
					local score = 1000
					local left = type(frame.GetLeft) == "function" and frame:GetLeft()
					local right = type(frame.GetRight) == "function" and frame:GetRight()
					local top = type(frame.GetTop) == "function" and frame:GetTop()
					if rootLeft and right and right <= rootLeft + 12 then
						score = score - 600 + math.abs((rootLeft or 0) - right)
					end
					if rootTop and top then
						score = score + math.abs(rootTop - top)
					end
					if score < bestScore then
						bestScore = score
						bestButton = frame
					end
				end
			end
		end

		local childCount = type(frame.GetChildren) == "function" and select("#", frame:GetChildren()) or 0
		for index = 1, childCount do
			visit(select(index, frame:GetChildren()), depth + 1)
		end
	end

	visit(ProfessionsFrame, 0)
	return bestButton
end

local function FindDescendantButtonByText(root, expectedTexts, maxDepth)
	if not root then
		return nil
	end

	local wanted = {}
	for _, text in ipairs(expectedTexts or {}) do
		if type(text) == "string" and text ~= "" then
			wanted[text] = true
		end
	end

	local function visit(frame, depth)
		if not frame or depth > (maxDepth or 12) then
			return nil
		end

		if type(frame.GetObjectType) == "function" and frame:GetObjectType() == "Button" then
			local text = GetFrameLabelText(frame)
			if text and wanted[text] then
				return frame
			end
		end

		local childCount = type(frame.GetChildren) == "function" and select("#", frame:GetChildren()) or 0
		for index = 1, childCount do
			local found = visit(select(index, frame:GetChildren()), depth + 1)
			if found then
				return found
			end
		end

		return nil
	end

	return visit(root, 0)
end

local function ReanchorButtonToMatch(sourceButton, targetButton)
	if not (sourceButton and targetButton) then
		return
	end

	sourceButton:ClearAllPoints()
	sourceButton:SetPoint("TOPLEFT", targetButton, "TOPLEFT", 0, 0)

	local width = targetButton:GetWidth()
	local height = targetButton:GetHeight()
	if width and width > 0 and height and height > 0 then
		sourceButton:SetSize(width, height)
	end

	sourceButton:SetFrameLevel((targetButton:GetFrameLevel() or sourceButton:GetFrameLevel() or 1) + 1)
end

local function CopyRegionAnchors(source, target, sourceRoot, targetRoot, scaleX, scaleY)
	target:ClearAllPoints()
	local pointCount = type(source.GetNumPoints) == "function" and source:GetNumPoints() or 0
	if pointCount == 0 then
		target:SetAllPoints(targetRoot)
		return
	end

	for index = 1, pointCount do
		local point, relativeTo, relativePoint, xOffset, yOffset = source:GetPoint(index)
		if point then
			local relative = relativeTo == sourceRoot and targetRoot or targetRoot
			target:SetPoint(point, relative, relativePoint or point, (xOffset or 0) * scaleX, (yOffset or 0) * scaleY)
		end
	end
end

local function CopyTextureRegion(source, targetRoot, sourceRoot, scaleX, scaleY)
	local layer, sublevel = source:GetDrawLayer()
	local copy = targetRoot:CreateTexture(nil, layer or "ARTWORK", nil, sublevel or 0)
	local atlas = type(source.GetAtlas) == "function" and source:GetAtlas()
	if atlas then
		copy:SetAtlas(atlas, false)
	else
		copy:SetTexture(source:GetTexture())
	end
	copy:SetTexCoord(source:GetTexCoord())
	copy:SetVertexColor(source:GetVertexColor())
	if type(source.IsDesaturated) == "function" and type(copy.SetDesaturated) == "function" then
		copy:SetDesaturated(source:IsDesaturated())
	end
	if type(source.GetBlendMode) == "function" and type(copy.SetBlendMode) == "function" then
		copy:SetBlendMode(source:GetBlendMode())
	end
	if type(source.GetAlpha) == "function" then
		copy:SetAlpha(source:GetAlpha())
	end
	local width, height = source:GetSize()
	copy:SetSize((width or 0) * scaleX, (height or 0) * scaleY)
	CopyRegionAnchors(source, copy, sourceRoot, targetRoot, scaleX, scaleY)
	return copy
end

local function CopyFontStringRegion(source, targetRoot, sourceRoot, scaleX, scaleY)
	local layer, sublevel = source:GetDrawLayer()
	local copy = targetRoot:CreateFontString(nil, layer or "ARTWORK", nil)
	local fontObject = type(source.GetFontObject) == "function" and source:GetFontObject()
	if fontObject then
		copy:SetFontObject(fontObject)
	end
	local font, size, flags = source:GetFont()
	if font and size then
		copy:SetFont(font, math.max(8, size * math.min(scaleX, scaleY)), flags)
	end
	copy:SetText(source:GetText() or "")
	copy:SetTextColor(source:GetTextColor())
	copy:SetJustifyH(source:GetJustifyH())
	copy:SetJustifyV(source:GetJustifyV())
	copy:SetShadowColor(source:GetShadowColor())
	local shadowX, shadowY = source:GetShadowOffset()
	copy:SetShadowOffset((shadowX or 0) * scaleX, (shadowY or 0) * scaleY)
	if type(source.GetAlpha) == "function" then
		copy:SetAlpha(source:GetAlpha())
	end
	local width, height = source:GetSize()
	copy:SetSize((width or 0) * scaleX, (height or 0) * scaleY)
	CopyRegionAnchors(source, copy, sourceRoot, targetRoot, scaleX, scaleY)
	return copy
end

local function CopyFilterFrameVisuals(sourceFrame, targetFrame, sourceRoot, targetRoot, scaleX, scaleY, visuals, depth)
	if not sourceFrame or not targetFrame or depth > 3 then
		return
	end

	local regionCount = type(sourceFrame.GetRegions) == "function" and select("#", sourceFrame:GetRegions()) or 0
	for index = 1, regionCount do
		local region = select(index, sourceFrame:GetRegions())
		if region and type(region.GetObjectType) == "function" and (type(region.IsShown) ~= "function" or region:IsShown()) then
			local objectType = region:GetObjectType()
			local copy
			if objectType == "Texture" then
				copy = CopyTextureRegion(region, targetFrame, sourceFrame, scaleX, scaleY)
			elseif objectType == "FontString" then
				copy = CopyFontStringRegion(region, targetFrame, sourceFrame, scaleX, scaleY)
			end
			if copy then
				visuals[#visuals + 1] = copy
			end
		end
	end

	local childCount = type(sourceFrame.GetChildren) == "function" and select("#", sourceFrame:GetChildren()) or 0
	for index = 1, childCount do
		local child = select(index, sourceFrame:GetChildren())
		if child and child:IsShown() and type(child.GetSize) == "function" then
			local childWidth, childHeight = child:GetSize()
			if childWidth and childHeight and childWidth > 0 and childHeight > 0 and childWidth <= 220 and childHeight <= 80 then
				local childCopy = CreateFrame("Frame", nil, targetFrame)
				childCopy:SetSize(childWidth * scaleX, childHeight * scaleY)
				CopyRegionAnchors(child, childCopy, sourceRoot, targetRoot, scaleX, scaleY)
				visuals[#visuals + 1] = childCopy
				CopyFilterFrameVisuals(child, childCopy, child, childCopy, scaleX, scaleY, visuals, depth + 1)
			end
		end
	end
end

local function ClearCopiedFilterButtonVisuals(button)
	if not button or not button.copiedFilterVisuals then
		return
	end

	for _, visual in ipairs(button.copiedFilterVisuals) do
		visual:Hide()
	end
	button.copiedFilterVisuals = nil
	button.copiedFilterVisualSource = nil
end

local function CopyFilterButtonVisuals(source, target)
	if not source or not target then
		return false
	end

	ClearCopiedFilterButtonVisuals(target)
	target.copiedFilterVisuals = {}

	local sourceWidth, sourceHeight = source:GetSize()
	local targetWidth, targetHeight = target:GetSize()
	local scaleX = sourceWidth and sourceWidth > 0 and targetWidth / sourceWidth or 1
	local scaleY = sourceHeight and sourceHeight > 0 and targetHeight / sourceHeight or 1

	CopyFilterFrameVisuals(source, target, source, target, scaleX, scaleY, target.copiedFilterVisuals, 0)

	target.copiedFilterVisualSource = source
	SetFallbackFilterButtonVisualsShown(target, false)
	return #target.copiedFilterVisuals > 0
end

local function NormalizeRecipeFilter(filterKey)
	if filterKey == RECIPE_FILTER_KNOWN or filterKey == RECIPE_FILTER_UNKNOWN then
		return filterKey
	end

	return RECIPE_FILTER_ALL
end

local function NormalizeConcentrationFilter(filterKey)
	if filterKey == CONCENTRATION_FILTER_NEEDS or filterKey == CONCENTRATION_FILTER_NONE then
		return filterKey
	end

	return CONCENTRATION_FILTER_ALL
end

local function NormalizeSortKey(sortKey)
	if sortKey == "order"
		or sortKey == "cost"
		or sortKey == "reward"
		or sortKey == "profit"
		or sortKey == "time" then
		return sortKey
	end

	return ns.DEFAULT_SORT_KEY or "profit"
end

local function DoesOrderNeedConcentration(orderData)
	local concentration = orderData and orderData.concentration
	return type(concentration) == "table"
		and (tonumber(concentration.currentCost) or 0) > 0
end

local function CreateFilterMenuToggle(parent, text, anchor, offsetY)
	local button = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
	button:SetSize(22, 22)
	button:SetPoint("TOPLEFT", anchor, "TOPLEFT", -1, offsetY)
	button.text = button.text or button.Text
	if not button.text then
		button.text = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	end
	if button.text then
		button.text:ClearAllPoints()
		button.text:SetPoint("LEFT", button, "RIGHT", 9, 0)
		button.text:SetPoint("RIGHT", parent, "RIGHT", -12, 0)
		button.text:SetHeight(22)
		button.text:SetText(text)
		button.text:SetFontObject(GameFontHighlight)
		button.text:SetJustifyH("LEFT")
		button.text:SetTextColor(1, 1, 1)
	end
	if type(button.SetHitRectInsets) == "function" then
		button:SetHitRectInsets(0, -(FILTER_PANEL_WIDTH - 46), -2, -2)
	end
	return button
end

function Pane:CreateSelectionActionButton(parent, text, anchor, offsetY)
	local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	button:SetSize(198, 20)
	button:SetPoint("TOPLEFT", anchor, anchor == parent and "TOPLEFT" or "BOTTOMLEFT", 12, offsetY)
	button:SetText(text)
	button:SetNormalFontObject(GameFontNormalSmall)
	button:SetHighlightFontObject(GameFontHighlightSmall)
	return button
end

local function SetFilterMenuToggleChecked(button, checked)
	if not button then
		return
	end

	button:SetChecked(checked)
	if button.text then
		button.text:SetTextColor(1, 1, 1)
	end
end

local function GetCraftingReagentDescriptor(reagentInfo)
	if type(reagentInfo) ~= "table" then
		return nil
	end

	local reagent = type(reagentInfo.reagent) == "table" and reagentInfo.reagent or reagentInfo
	local itemID = reagent.itemID or reagentInfo.itemID
	local currencyID = reagent.currencyID or reagentInfo.currencyID
	if not itemID and not currencyID then
		return nil
	end

	return {
		itemID = itemID,
		currencyID = currencyID,
	}
end

local function AddMutableOperationReagent(target, reagentInfo, dataSlotIndex, quantity)
	local reagent = GetCraftingReagentDescriptor(reagentInfo)
	if not reagent then
		return
	end

	local entry = {
		reagent = reagent,
		quantity = quantity or reagentInfo.quantity or 0,
		dataSlotIndex = reagentInfo.dataSlotIndex or dataSlotIndex,
		itemID = reagent.itemID,
		currencyID = reagent.currencyID,
	}
	target[#target + 1] = entry
end

local function CopyOperationReagents(reagents)
	local copy = {}
	for index, reagent in ipairs(reagents or {}) do
		local descriptor = GetCraftingReagentDescriptor(reagent)
		if descriptor then
			copy[index] = {
				reagent = descriptor,
				itemID = descriptor.itemID,
				currencyID = descriptor.currencyID,
				quantity = reagent.quantity,
				dataSlotIndex = reagent.dataSlotIndex,
			}
		end
	end
	return copy
end

local function GetOrderQuality(order)
	return order.minQuality or 0
end

local function GetRecipeInfo(order)
	if not order.skillLineAbilityID then
		return nil
	end

	local skillLineRecipeInfo = C_TradeSkillUI.GetRecipeInfoForSkillLineAbility(order.skillLineAbilityID, 2)
	if not (skillLineRecipeInfo and skillLineRecipeInfo.recipeID and type(C_TradeSkillUI.GetRecipeInfo) == "function") then
		return skillLineRecipeInfo
	end

	local recipeInfo = securecall(C_TradeSkillUI.GetRecipeInfo, skillLineRecipeInfo.recipeID)
	if type(recipeInfo) ~= "table" then
		return skillLineRecipeInfo
	end

	local merged = {}
	for key, value in pairs(skillLineRecipeInfo) do
		merged[key] = value
	end
	for key, value in pairs(recipeInfo) do
		merged[key] = value
	end
	return merged
end

local function GetRecipeSchematic(recipeInfo)
	if not recipeInfo or not recipeInfo.recipeID then
		return nil
	end

	return C_TradeSkillUI.GetRecipeSchematic(recipeInfo.recipeID, false)
end

local function GetOperationInfo(orderData, reagents, applyConcentration)
	if not (orderData and orderData.recipeInfo and orderData.recipeInfo.recipeID and C_TradeSkillUI) then
		return nil
	end

	if orderData.orderID and type(C_TradeSkillUI.GetCraftingOperationInfoForOrder) == "function" then
		return securecall(
			C_TradeSkillUI.GetCraftingOperationInfoForOrder,
			orderData.recipeInfo.recipeID,
			reagents or {},
			orderData.orderID,
			not not applyConcentration
		)
	end

	if type(C_TradeSkillUI.GetCraftingOperationInfo) ~= "function" then
		return nil
	end

	return securecall(
		C_TradeSkillUI.GetCraftingOperationInfo,
		orderData.recipeInfo.recipeID,
		reagents or {},
		nil,
		not not applyConcentration
	)
end

local RECIPE_REQUIREMENT_LABELS = {
	[(Enum.RecipeRequirementType and Enum.RecipeRequirementType.SpellFocus) or 0] = L.RECIPE_REQ_SPELL_FOCUS,
	[(Enum.RecipeRequirementType and Enum.RecipeRequirementType.Totem) or 1] = L.RECIPE_REQ_TOTEM,
	[(Enum.RecipeRequirementType and Enum.RecipeRequirementType.Area) or 2] = L.RECIPE_REQ_AREA,
}

local function AddUniqueTooltipLine(lines, seen, text)
	if type(text) ~= "string" then
		return
	end

	text = strtrim(text)
	if text == "" or seen[text] then
		return
	end

	seen[text] = true
	lines[#lines + 1] = text
end

local function AddTooltipTextBlock(lines, seen, text)
	if type(text) ~= "string" or text == "" then
		return
	end

	text = text:gsub("|n", "\n")
	for line in text:gmatch("([^\n]+)") do
		AddUniqueTooltipLine(lines, seen, line)
	end
end

local function GetRecipeSourceText(recipeID)
	if not (recipeID and C_TradeSkillUI.GetRecipeSourceText) then
		return nil
	end

	return securecall(C_TradeSkillUI.GetRecipeSourceText, recipeID)
end

local function BuildUnknownRecipeTooltip(recipeInfo)
	if not (recipeInfo and recipeInfo.recipeID) then
		return nil
	end

	local lines = {}
	local seen = {}
	local professionName = recipeInfo.skillLineAbilityID
		and C_TradeSkillUI.GetProfessionNameForSkillLineAbility
		and securecall(C_TradeSkillUI.GetProfessionNameForSkillLineAbility, recipeInfo.skillLineAbilityID)
	local sourceText = GetRecipeSourceText(recipeInfo.recipeID)
	local requirements = C_TradeSkillUI.GetRecipeRequirements and securecall(C_TradeSkillUI.GetRecipeRequirements, recipeInfo.recipeID)

	AddUniqueTooltipLine(lines, seen, ("|cffffd100%s|r"):format(L.UNKNOWN_RECIPE_HEADER))
	if professionName then
		AddUniqueTooltipLine(lines, seen, LF("UNKNOWN_RECIPE_PROFESSION_FORMAT", professionName))
	end

	if sourceText then
		AddUniqueTooltipLine(lines, seen, ("|cffffd100%s|r"):format(L.UNKNOWN_RECIPE_LEARN_HEADER))
		AddTooltipTextBlock(lines, seen, sourceText)
	end

	if type(requirements) == "table" and #requirements > 0 then
		AddUniqueTooltipLine(lines, seen, ("|cffffd100%s|r"):format(L.UNKNOWN_RECIPE_REQUIREMENTS_HEADER))
		for _, requirement in ipairs(requirements) do
			local requirementName = requirement and requirement.name
			if requirementName and requirementName ~= "" then
				local label = RECIPE_REQUIREMENT_LABELS[requirement.type] or L.RECIPE_REQ_GENERIC
				local suffix = requirement.met and "" or L.RECIPE_REQ_NOT_MET_SUFFIX
				AddUniqueTooltipLine(lines, seen, LF("UNKNOWN_RECIPE_REQUIREMENT_FORMAT", label, requirementName, suffix))
			end
		end
	end

	if #lines <= 1 then
		AddUniqueTooltipLine(lines, seen, L.UNKNOWN_RECIPE_NO_SOURCE)
	end

	return lines
end

local function AppendTooltipLines(target, source)
	if type(source) ~= "table" then
		return target
	end

	target = target or {}
	for _, line in ipairs(source) do
		target[#target + 1] = line
	end
	return target
end

local function GetRecipeInfoByID(recipeID)
	if not (recipeID and type(C_TradeSkillUI.GetRecipeInfo) == "function") then
		return nil
	end

	local info = securecall(C_TradeSkillUI.GetRecipeInfo, recipeID)
	return type(info) == "table" and info or nil
end

local function IsRecipeKnown(recipeInfo)
	if type(recipeInfo) ~= "table" then
		return false
	end

	local info = recipeInfo.recipeID and GetRecipeInfoByID(recipeInfo.recipeID) or recipeInfo
	if info and info.learned then
		return true
	end

	local seen = {}
	while info and info.previousRecipeID and not seen[info.previousRecipeID] do
		seen[info.recipeID or info.previousRecipeID] = true
		info = GetRecipeInfoByID(info.previousRecipeID)
		if info and info.learned then
			return true
		end
	end

	while info and info.nextRecipeID and not seen[info.nextRecipeID] do
		seen[info.recipeID or info.nextRecipeID] = true
		info = GetRecipeInfoByID(info.nextRecipeID)
		if info and info.learned then
			return true
		end
	end

	return false
end

local function GetMinimumRequiredQuality(recipeInfo)
	local qualityIDs = recipeInfo and recipeInfo.qualityIDs
	if type(qualityIDs) == "table" then
		local minimumQuality
		for qualityIndex, qualityID in pairs(qualityIDs) do
			if type(qualityIndex) == "number" and qualityIndex > 0 and qualityID ~= nil then
				minimumQuality = minimumQuality and math.min(minimumQuality, qualityIndex) or qualityIndex
			end
		end

		if minimumQuality then
			return minimumQuality
		end
	end

	return 0
end

local function MeetsRequiredQuality(operationInfo, requiredQuality)
	if requiredQuality <= 0 then
		return true
	end

	return operationInfo and (operationInfo.craftingQuality or 0) >= requiredQuality
end

local function CanReachRequiredQuality(operationInfo, requiredQuality)
	if MeetsRequiredQuality(operationInfo, requiredQuality) then
		return true
	end

	if not (operationInfo and requiredQuality > 0) then
		return false
	end

	local currentQuality = operationInfo.craftingQuality or 0
	return currentQuality + 1 >= requiredQuality and operationInfo.concentrationCost ~= nil
end

local function SortFillOptions(strategy, left, right)
	if strategy == "lowest" then
		local leftQuality = left.reagentQuality or 0
		local rightQuality = right.reagentQuality or 0
		if leftQuality ~= rightQuality then
			return leftQuality < rightQuality
		end

		local leftRank = GetMarketPreferenceRank(left.priceState, left.unitPrice)
		local rightRank = GetMarketPreferenceRank(right.priceState, right.unitPrice)
		if leftRank ~= rightRank then
			return leftRank < rightRank
		end

		local leftPrice = left.unitPrice or math.huge
		local rightPrice = right.unitPrice or math.huge
		if leftPrice ~= rightPrice then
			return leftPrice < rightPrice
		end

		return (left.score or 0) < (right.score or 0)
	elseif strategy == "best" then
		if (left.score or 0) ~= (right.score or 0) then
			return (left.score or 0) > (right.score or 0)
		end

		local leftRank = GetMarketPreferenceRank(left.priceState, left.unitPrice)
		local rightRank = GetMarketPreferenceRank(right.priceState, right.unitPrice)
		if leftRank ~= rightRank then
			return leftRank < rightRank
		end

		local leftPrice = left.unitPrice or math.huge
		local rightPrice = right.unitPrice or math.huge
		if leftPrice ~= rightPrice then
			return leftPrice < rightPrice
		end

		return (left.reagentQuality or 0) > (right.reagentQuality or 0)
	end

	local leftRank = GetMarketPreferenceRank(left.priceState, left.unitPrice)
	local rightRank = GetMarketPreferenceRank(right.priceState, right.unitPrice)
	if leftRank ~= rightRank then
		return leftRank < rightRank
	end

	local leftPrice = left.unitPrice or math.huge
	local rightPrice = right.unitPrice or math.huge
	if leftPrice ~= rightPrice then
		return leftPrice < rightPrice
	end

	return (left.score or 0) > (right.score or 0)
end

local function BuildStrategizedOperation(orderData, inventoryOnly, strategy)
	if not (orderData.recipeInfo and orderData.recipeInfo.recipeID) then
		return nil
	end

	local workingReagents = CopyOperationReagents(orderData.operationReagents)
	local inventory = {}
	local includeOptional = strategy == "best"

	for _, slotData in ipairs(orderData.mutableSlots or {}) do
		if slotData.dataSlotType == MUTABLE_SLOT_TYPE and not slotData.covered and not slotData.locked and (slotData.required or includeOptional) then
			local remaining = slotData.quantityRequired
			local options = {}

			for index, option in ipairs(slotData.options) do
				options[index] = option
				if inventoryOnly and option.itemID and inventory[option.itemID] == nil then
					inventory[option.itemID] = Util.GetItemCount(option.itemID)
				end
			end

			table.sort(options, function(left, right)
				return SortFillOptions(strategy, left, right)
			end)

			for _, option in ipairs(options) do
				local available = inventoryOnly and (inventory[option.itemID] or 0) or remaining
				if available > 0 then
					local quantity = math.min(remaining, available)
					AddMutableOperationReagent(workingReagents, option, slotData.dataSlotIndex, quantity)
					remaining = remaining - quantity
					if inventoryOnly then
						inventory[option.itemID] = available - quantity
					end
					if remaining == 0 then
						break
					end
				end
			end
		end
	end

	return GetOperationInfo(orderData, workingReagents, false), workingReagents
end

local function GetComparableUnitPrice(option)
	local unitPrice = option and option.unitPrice
	if type(unitPrice) == "number" and unitPrice > 0 then
		return unitPrice
	end

	return math.huge
end

local function CompareLowestMaterialOptions(left, right)
	local leftQuality = left and left.reagentQuality or 0
	local rightQuality = right and right.reagentQuality or 0
	if leftQuality ~= rightQuality then
		return leftQuality < rightQuality
	end

	local leftRank = GetMarketPreferenceRank(left and left.priceState, left and left.unitPrice)
	local rightRank = GetMarketPreferenceRank(right and right.priceState, right and right.unitPrice)
	if leftRank ~= rightRank then
		return leftRank < rightRank
	end

	local leftPrice = GetComparableUnitPrice(left)
	local rightPrice = GetComparableUnitPrice(right)
	if leftPrice ~= rightPrice then
		return leftPrice < rightPrice
	end

	if (left.score or 0) ~= (right.score or 0) then
		return (left.score or 0) > (right.score or 0)
	end

	return (left.itemID or 0) < (right.itemID or 0)
end

local function BuildMaterialEntry(slotData, option, quantity)
	if not (slotData and option and quantity and quantity > 0) then
		return nil
	end

	local totalPrice = type(option.unitPrice) == "number" and option.unitPrice > 0 and option.unitPrice * quantity or nil
	local availableTotal = option.ownedCount or 0
	return {
		slotData = slotData,
		option = option,
		quantity = quantity,
		required = slotData.required,
		availableTotal = availableTotal,
		selectedQualityOwnedCount = option.ownedCount or 0,
		otherQualityOwnedCount = option.otherQualityOwnedCount or 0,
		totalOwnedCount = option.totalOwnedCount or option.ownedCount or 0,
		shortage = math.max(0, quantity - availableTotal),
		totalPrice = totalPrice,
		priceState = option.priceState,
		marketValueExcluded = IsExcludedFromMarketValue(option.priceState),
	}
end

local EMPTY_LIST = {}

local function GetMaterialPlanEntries(orderData, materialPlan)
	materialPlan = materialPlan or (orderData and orderData.materialPlan)
	return materialPlan and materialPlan.entries or EMPTY_LIST
end

function Pane:BuildOrderQueueReagents(orderData, skipDontBuyItems, materialPlan)
	local grouped = {}
	local hasAllMaterials = true

	for _, materialEntry in ipairs(GetMaterialPlanEntries(orderData, materialPlan)) do
		local option = materialEntry.option
		local quantity = tonumber(materialEntry.quantity) or 0
		if option and option.itemID and quantity > 0 then
			if not (skipDontBuyItems and self:IsDontBuyItem(option.itemID)) then
				local refreshedLink = Util.GetItemLink(option.itemID)
				local itemLink = LinkHasDisplayName(option.itemLink) and option.itemLink or refreshedLink
				local reagentQuality = option.reagentQuality
					or Util.GetProfessionItemQuality(itemLink or option.itemID)
					or Util.GetProfessionItemQuality(option.itemID)
				local groupKey = GetShoppingEntryGroupKey({
					itemID = option.itemID,
					reagentQuality = reagentQuality,
				})
				local bucket = grouped[groupKey]
				if not bucket then
					bucket = {
						itemID = option.itemID,
						itemLink = itemLink,
						required = 0,
					}
					grouped[groupKey] = bucket
				end
				bucket.required = bucket.required + quantity
			end
		elseif quantity > 0 then
			hasAllMaterials = false
		end
	end

	local reagents = {}
	for _, bucket in pairs(grouped) do
		local owned = Util.GetQualityAwareItemCounts(bucket.itemID, bucket.itemLink)
		if owned < bucket.required then
			hasAllMaterials = false
		end
		reagents[#reagents + 1] = {
			itemID = bucket.itemID,
			quantity = bucket.required,
		}
	end

	table.sort(reagents, function(left, right)
		if left.itemID == right.itemID then
			return left.quantity < right.quantity
		end
		return left.itemID < right.itemID
	end)

	return reagents, hasAllMaterials
end

local function CreatePendingSlotAllocation(slotAllocations, slotIndex, itemID, currencyID, quantity)
	if not slotIndex or not quantity or quantity <= 0 then
		return
	end

	local bucket = slotAllocations[slotIndex]
	if not bucket then
		bucket = {}
		slotAllocations[slotIndex] = bucket
	end

	for _, allocation in ipairs(bucket) do
		if allocation.itemID == itemID and allocation.currencyID == currencyID then
			allocation.quantity = (allocation.quantity or 0) + quantity
			return
		end
	end

	bucket[#bucket + 1] = {
		itemID = itemID,
		currencyID = currencyID,
		quantity = quantity,
	}
end

local function SelectDefaultSlotOption(slotData)
	local options = {}
	for index, option in ipairs(slotData and slotData.options or {}) do
		options[index] = option
	end

	if #options == 0 then
		return nil
	end

	table.sort(options, CompareLowestMaterialOptions)
	return options[1]
end

local function CreateMaterialVariant(slotData, components)
	local variant = {
		slotData = slotData,
		entries = {},
		qualityWeight = 0,
		scoreTotal = 0,
		marketCost = 0,
		marketCostKnown = true,
		excludedEntryCount = 0,
	}

	for _, component in ipairs(components or {}) do
		local entry = BuildMaterialEntry(slotData, component.option, component.quantity)
		if entry then
			variant.entries[#variant.entries + 1] = entry
			variant.qualityWeight = variant.qualityWeight
				+ ((QUALITY_WEIGHT_BASE ^ math.max(0, entry.option.reagentQuality or 0)) * (entry.quantity or 0))
			variant.scoreTotal = variant.scoreTotal + ((entry.option.score or 0) * (entry.quantity or 0))
			if entry.marketValueExcluded then
				variant.excludedEntryCount = variant.excludedEntryCount + 1
			elseif entry.totalPrice then
				variant.marketCost = variant.marketCost + entry.totalPrice
			else
				variant.marketCostKnown = false
			end
		end
	end

	return variant
end

local function CompareMaterialPlanPreference(left, right)
	local leftWeight = left and left.qualityWeight or math.huge
	local rightWeight = right and right.qualityWeight or math.huge
	if leftWeight ~= rightWeight then
		return leftWeight < rightWeight
	end

	if (left.excludedEntryCount or 0) ~= (right.excludedEntryCount or 0) then
		return (left.excludedEntryCount or 0) < (right.excludedEntryCount or 0)
	end

	if left.marketCostKnown ~= right.marketCostKnown then
		return left.marketCostKnown
	end

	local leftCost = left.marketCost or math.huge
	local rightCost = right.marketCost or math.huge
	if leftCost ~= rightCost then
		return leftCost < rightCost
	end

	if (left.scoreTotal or 0) ~= (right.scoreTotal or 0) then
		return (left.scoreTotal or 0) > (right.scoreTotal or 0)
	end

	return false
end

local function BuildSlotFillVariants(slotData, allowEmpty)
	local variants = {}
	local options = {}

	for index, option in ipairs(slotData.options or {}) do
		options[index] = option
	end

	table.sort(options, CompareLowestMaterialOptions)

	if allowEmpty then
		variants[#variants + 1] = CreateMaterialVariant(slotData)
	end

	if #options == 0 then
		return variants
	end

	local components = {}
	local function Visit(optionIndex, remaining)
		local option = options[optionIndex]
		if remaining == 0 then
			variants[#variants + 1] = CreateMaterialVariant(slotData, components)
			return
		end

		if not option then
			return
		end

		if optionIndex == #options then
			components[#components + 1] = {
				option = option,
				quantity = remaining,
			}
			variants[#variants + 1] = CreateMaterialVariant(slotData, components)
			components[#components] = nil
			return
		end

		for quantity = remaining, 0, -1 do
			if quantity > 0 then
				components[#components + 1] = {
					option = option,
					quantity = quantity,
				}
			end

			Visit(optionIndex + 1, remaining - quantity)

			if quantity > 0 then
				components[#components] = nil
			end
		end
	end

	Visit(1, slotData.quantityRequired or 0)
	table.sort(variants, CompareMaterialPlanPreference)
	return variants
end

local function ShouldConsiderOptionalSlot(slotData)
	if not slotData then
		return false
	end

	if slotData.required then
		return true
	end

	for _, option in ipairs(slotData.options or {}) do
		if (option.score or 0) > 0 then
			return true
		end
	end

	return false
end

local function BuildPlannedMaterialCombination(orderData, selections, missingRequiredSlots)
	local workingReagents = CopyOperationReagents(orderData.operationReagents)
	local entries = {}
	local qualityWeight = 0
	local scoreTotal = 0
	local marketCost = 0
	local marketCostKnown = true
	local excludedEntryCount = 0
	local requiredMissing = (missingRequiredSlots or 0) + (orderData.staticMissingRequiredSlots or 0)

	for _, entry in ipairs(orderData.staticMaterialEntries or {}) do
		entries[#entries + 1] = entry
		if entry.marketValueExcluded then
			excludedEntryCount = excludedEntryCount + 1
		elseif entry.totalPrice then
			marketCost = marketCost + entry.totalPrice
		else
			marketCostKnown = false
		end
	end

	for _, selection in ipairs(selections or {}) do
		local hasEntries = false
		for _, entry in ipairs(selection.entries or {}) do
			hasEntries = true
			entries[#entries + 1] = entry
			AddMutableOperationReagent(workingReagents, entry.option, entry.slotData.dataSlotIndex, entry.quantity)
			qualityWeight = qualityWeight
				+ ((QUALITY_WEIGHT_BASE ^ math.max(0, entry.option.reagentQuality or 0)) * (entry.quantity or 0))
			scoreTotal = scoreTotal + ((entry.option.score or 0) * (entry.quantity or 0))
			if entry.marketValueExcluded then
				excludedEntryCount = excludedEntryCount + 1
			elseif entry.totalPrice then
				marketCost = marketCost + entry.totalPrice
			else
				marketCostKnown = false
			end
		end

		if selection.slotData and selection.slotData.required and not hasEntries then
			requiredMissing = requiredMissing + 1
		end
	end

	return {
		entries = entries,
		reagents = workingReagents,
		operationInfo = requiredMissing == 0 and GetOperationInfo(orderData, workingReagents, false) or nil,
		missingRequiredSlots = requiredMissing,
		qualityWeight = qualityWeight,
		scoreTotal = scoreTotal,
		marketCost = marketCost,
		marketCostKnown = marketCostKnown,
		excludedEntryCount = excludedEntryCount,
	}
end

local function BuildLowestMaterialPlan(orderData)
	local selections = {}
	local missingRequiredSlots = 0

	for _, slotData in ipairs(orderData.mutableSlots or {}) do
		if slotData.dataSlotType == MUTABLE_SLOT_TYPE and not slotData.covered and not slotData.locked and slotData.required then
			local variants = BuildSlotFillVariants(slotData, false)
			if variants[1] then
				selections[#selections + 1] = variants[1]
			else
				missingRequiredSlots = missingRequiredSlots + 1
			end
		end
	end

	return BuildPlannedMaterialCombination(orderData, selections, missingRequiredSlots)
end

local function FindReachableMaterialPlan(orderData, requiredQuality)
	local planningSlots = {}
	local missingRequiredSlots = 0

	for _, slotData in ipairs(orderData.mutableSlots or {}) do
		if slotData.dataSlotType == MUTABLE_SLOT_TYPE
			and not slotData.covered
			and not slotData.locked
			and ShouldConsiderOptionalSlot(slotData) then
			local variants = BuildSlotFillVariants(slotData, not slotData.required)
			if variants[1] then
				planningSlots[#planningSlots + 1] = {
					slotData = slotData,
					variants = variants,
				}
			elseif slotData.required then
				missingRequiredSlots = missingRequiredSlots + 1
			end
		end
	end

	if missingRequiredSlots > 0 then
		return nil
	end

	if #planningSlots == 0 then
		local fallback = BuildPlannedMaterialCombination(orderData, {}, 0)
		return CanReachRequiredQuality(fallback.operationInfo, requiredQuality) and fallback or nil
	end

	local suffixMinQualityWeight = {
		[#planningSlots + 1] = 0,
	}

	for index = #planningSlots, 1, -1 do
		local firstVariant = planningSlots[index].variants[1]
		suffixMinQualityWeight[index] = suffixMinQualityWeight[index + 1] + (firstVariant and firstVariant.qualityWeight or 0)
	end

	local bestPlan
	local selections = {}

	local function Search(slotIndex, currentQualityWeight)
		if slotIndex > #planningSlots then
			local candidate = BuildPlannedMaterialCombination(orderData, selections, 0)
			if CanReachRequiredQuality(candidate.operationInfo, requiredQuality)
				and (not bestPlan or CompareMaterialPlanPreference(candidate, bestPlan)) then
				bestPlan = candidate
			end
			return
		end

		if bestPlan and currentQualityWeight + suffixMinQualityWeight[slotIndex] > (bestPlan.qualityWeight or math.huge) then
			return
		end

		for _, variant in ipairs(planningSlots[slotIndex].variants) do
			local candidateWeight = currentQualityWeight + (variant.qualityWeight or 0)
			if bestPlan
				and candidateWeight + suffixMinQualityWeight[slotIndex + 1] > (bestPlan.qualityWeight or math.huge) then
				break
			end

			selections[#selections + 1] = variant
			Search(slotIndex + 1, candidateWeight)
			selections[#selections] = nil
		end
	end

	Search(1, 0)
	return bestPlan
end

local function EvaluateQualityRequirement(orderData)
	local requiredQuality = orderData.requiredQuality or 0
	local minimumQuality = GetMinimumRequiredQuality(orderData.recipeInfo)
	local lowestPlan = BuildLowestMaterialPlan(orderData)
	local lowestOperation = lowestPlan and lowestPlan.operationInfo
	if requiredQuality <= minimumQuality then
		return {
			showInList = false,
			minimumQuality = minimumQuality,
			requiredQuality = requiredQuality,
			lowestPlan = lowestPlan,
			activePlan = lowestPlan,
		}
	end

	if MeetsRequiredQuality(lowestOperation, requiredQuality) then
		return {
			showInList = true,
			minimumQuality = minimumQuality,
			requiredQuality = requiredQuality,
			state = "green",
			lowestPlan = lowestPlan,
			reachablePlan = lowestPlan,
			activePlan = lowestPlan,
		}
	end

	if CanReachRequiredQuality(lowestOperation, requiredQuality) then
		return {
			showInList = true,
			minimumQuality = minimumQuality,
			requiredQuality = requiredQuality,
			state = "amber",
			lowestPlan = lowestPlan,
			reachablePlan = lowestPlan,
			activePlan = lowestPlan,
		}
	end

	local reachablePlan = FindReachableMaterialPlan(orderData, requiredQuality)
	if reachablePlan then
		return {
			showInList = true,
			minimumQuality = minimumQuality,
			requiredQuality = requiredQuality,
			state = "amber",
			lowestPlan = lowestPlan,
			reachablePlan = reachablePlan,
			activePlan = reachablePlan,
		}
	end

	return {
		showInList = true,
		minimumQuality = minimumQuality,
		requiredQuality = requiredQuality,
		state = "none",
		lowestPlan = lowestPlan,
		activePlan = lowestPlan,
	}
end

local function BuildQualityTooltip(orderData)
	local qualityRequirement = orderData.qualityRequirement
	if not (qualityRequirement and qualityRequirement.showInList) then
		return nil
	end

	local lines = {
		LF("QUALITY_TOOLTIP_REQUESTED_FORMAT", qualityRequirement.requiredQuality or 0),
	}

	if qualityRequirement.state == "green" then
		lines[#lines + 1] = L.QUALITY_TOOLTIP_GREEN
	elseif qualityRequirement.state == "amber" then
		local reachableOperation = qualityRequirement.reachablePlan and qualityRequirement.reachablePlan.operationInfo
		if qualityRequirement.reachablePlan == qualityRequirement.lowestPlan then
			lines[#lines + 1] = L.QUALITY_TOOLTIP_AMBER_CONCENTRATION
		elseif MeetsRequiredQuality(reachableOperation, orderData.requiredQuality or 0) then
			lines[#lines + 1] = L.QUALITY_TOOLTIP_AMBER_STRONGER_MATERIALS
		else
			lines[#lines + 1] = L.QUALITY_TOOLTIP_AMBER_STRONGER_OR_CONCENTRATION
		end
	else
		lines[#lines + 1] = L.QUALITY_TOOLTIP_UNREACHABLE
	end

	return lines
end

local function BuildProductTooltipLines(orderData)
	return BuildQualityTooltip(orderData)
end

local function CompactQualityRequirement(qualityRequirement)
	if not qualityRequirement then
		return nil
	end

	return {
		showInList = qualityRequirement.showInList,
		minimumQuality = qualityRequirement.minimumQuality,
		requiredQuality = qualityRequirement.requiredQuality,
		state = qualityRequirement.state,
	}
end

local function GetQualityIndicatorText(orderData)
	local qualityRequirement = orderData.qualityRequirement
	if not (qualityRequirement and qualityRequirement.showInList) then
		return ""
	end

	if qualityRequirement.state == "green" then
		return " " .. GetAtlasMarkup(QUALITY_TICK_GREEN, 14, 14, 0, -1)
	elseif qualityRequirement.state == "amber" then
		return " " .. GetAtlasMarkup(QUALITY_TICK_AMBER, 14, 14, 0, -1)
	end

	return ""
end

local function GetOutputPresentation(order, recipeInfo)
	local qualityIndex = GetOrderQuality(order)
	local minimumQuality = GetMinimumRequiredQuality(recipeInfo)
	local itemID = order.itemID
	local itemLink

	if recipeInfo and recipeInfo.recipeID and qualityIndex > 0 and recipeInfo.qualityIDs then
		local operationReagents = {}
		for _, suppliedReagent in ipairs(order.reagents or {}) do
			if suppliedReagent.reagentInfo then
				operationReagents[#operationReagents + 1] = suppliedReagent.reagentInfo
			end
		end

		local output = C_TradeSkillUI.GetRecipeOutputItemData(
			recipeInfo.recipeID,
			operationReagents,
			nil,
			recipeInfo.qualityIDs[qualityIndex]
		)

		if output then
			itemID = output.itemID or itemID
			itemLink = output.hyperlink or Util.GetItemLink(itemID)
		end
	end

	if not itemLink and itemID then
		itemLink = Util.GetItemLink(itemID)
	end

	local label = itemLink and itemLink:gsub("|h%[(.*)%]|h", "|h%1|h") or C_Spell.GetSpellName(order.spellID or 0) or UNKNOWN
	if qualityIndex > minimumQuality then
		label = NormalizeProfessionQualityMarkup(label)
	else
		label = StripProfessionQualityMarkup(label)
	end
	local icon = itemID and select(5, C_Item.GetItemInfoInstant(itemID)) or C_Spell.GetSpellTexture(order.spellID or 0) or 134400

	return {
		itemID = itemID,
		itemLink = itemLink,
		icon = icon,
		label = label,
		plainLabel = C_StringUtil.StripHyperlinks(label),
	}
end

function Pane:GetKnowledgeProgressForRecipe(recipeInfo)
	if not (recipeInfo and recipeInfo.recipeID and C_ProfSpecs and C_Traits and C_TradeSkillUI) then
		return nil
	end

	local okProfession, professionInfo = Util.SafeCall(
		C_TradeSkillUI.GetProfessionInfoByRecipeID,
		recipeInfo.recipeID
	)
	if not okProfession or type(professionInfo) ~= "table" then
		return nil
	end

	local skillLineID = tonumber(professionInfo.professionID or professionInfo.skillLineID)
	if not skillLineID then
		return nil
	end

	self.knowledgeProgressCache = self.knowledgeProgressCache or {}
	local cached = self.knowledgeProgressCache[skillLineID]
	if cached then
		return cached
	end

	local okConfig, configID = Util.SafeCall(C_ProfSpecs.GetConfigIDForSkillLine, skillLineID)
	if not okConfig or not configID or configID <= 0 then
		return nil
	end

	local okConfigInfo, configInfo = Util.SafeCall(C_Traits.GetConfigInfo, configID)
	if not okConfigInfo or type(configInfo) ~= "table" then
		return nil
	end

	local allocated = 0
	local maximum = 0
	local seenNodes = {}
	for _, treeID in ipairs(configInfo.treeIDs or EMPTY_LIST) do
		local okNodes, nodeIDs = Util.SafeCall(C_Traits.GetTreeNodes, treeID)
		if okNodes then
			for _, nodeID in ipairs(nodeIDs or EMPTY_LIST) do
				if not seenNodes[nodeID] then
					seenNodes[nodeID] = true
					local okNode, nodeInfo = Util.SafeCall(C_Traits.GetNodeInfo, configID, nodeID)
					local maxRanks = tonumber(nodeInfo and nodeInfo.maxRanks)
					local activeRank = tonumber(nodeInfo and nodeInfo.activeRank)
					if maxRanks and maxRanks > 1 then
						local maxRank = math.max(0, maxRanks - 1)
						local currentRank = math.max(0, (activeRank or 0) - 1)
						maximum = maximum + maxRank
						allocated = allocated + math.min(maxRank, currentRank)
					end
				end
			end
		end
	end

	if maximum <= 0 then
		return nil
	end

	local result = {
		allocated = allocated,
		maximum = maximum,
		remainingRatio = math.max(0, math.min(1, 1 - allocated / maximum)),
	}
	self.knowledgeProgressCache[skillLineID] = result
	return result
end

local function EvaluateRewardValue(order, recipeInfo)
	local rewardGold = math.max(0, (order.tipAmount or 0) - (order.consortiumCut or 0))
	local rewardItemValue = 0
	local rewardIcons = {}
	local rewardKnowledge = 0
	local rewardMoxie = 0
	local pricedRewardCount = 0
	local marketableRewardCount = 0
	local excludedRewardCount = 0

	for _, reward in ipairs(order.npcOrderRewards or {}) do
		local count = reward.count or reward.quantity or 1
		local itemLink = reward.itemLink
		local itemID = itemLink and tonumber(itemLink:match("item:(%d+)")) or nil
		local currencyID = reward.currencyType
		local iconTexture
		local borderAtlas
		local unitPrice
		local totalPrice
		local priceState
		local knowledgeContribution = 0
		local extraLines
		local itemName

		if itemLink or itemID then
			local priceInfo = Pricing:GetPriceInfo(itemLink or itemID, count)
			unitPrice = priceInfo.unitPrice
			totalPrice = priceInfo.totalPrice
			priceState = priceInfo.state
			if priceInfo.isMarketable == false then
				excludedRewardCount = excludedRewardCount + 1
			else
				marketableRewardCount = marketableRewardCount + 1
				if totalPrice then
					pricedRewardCount = pricedRewardCount + 1
					rewardItemValue = rewardItemValue + totalPrice
				end
			end

			local instantID = itemID or tonumber((itemLink or ""):match("item:(%d+)"))
			itemID = instantID or itemID
			if instantID then
				itemLink = LinkHasDisplayName(itemLink) and itemLink or Util.GetItemLink(instantID) or itemLink
				itemName = Util.GetItemName(instantID) or reward.name or reward.itemName
			end
			iconTexture = instantID and select(5, C_Item.GetItemInfoInstant(instantID))
			borderAtlas = GetBorderAtlas(instantID)

			if instantID then
				knowledgeContribution = (REWARD_KNOWLEDGE_ITEMS[instantID] or 0) * count
				rewardKnowledge = rewardKnowledge + knowledgeContribution
				if knowledgeContribution > 0 then
					extraLines = {
						LF("KNOWLEDGE_REWARD_FORMAT", knowledgeContribution),
					}
				end
			end
		elseif currencyID then
			local basic = C_CurrencyInfo.GetBasicCurrencyInfo(currencyID, count)
			iconTexture = basic and basic.icon
			borderAtlas = GetBorderAtlas(nil, basic and basic.quality)
			priceState = "not_marketable"
			if MOXIE_CURRENCY_IDS[currencyID] then
				rewardMoxie = rewardMoxie + count
			end
		end

		rewardIcons[#rewardIcons + 1] = {
			itemID = itemID,
			itemLink = itemLink,
			name = itemName,
			currencyID = currencyID,
			count = count,
			icon = iconTexture,
			borderAtlas = borderAtlas,
			unitPrice = unitPrice,
			totalPrice = totalPrice,
			priceState = priceState,
			knowledgeContribution = knowledgeContribution,
			favoriteBadge = knowledgeContribution > 1,
			extraLines = extraLines,
		}
	end

	local firstCraftCount = recipeInfo and recipeInfo.firstCraft and 1 or 0
	local skillUpCount = recipeInfo and recipeInfo.canSkillUp
		and math.max(0, tonumber(recipeInfo.numSkillUps) or 0)
		or 0
	local knowledgeValueGold = ns.GetPatronValueGold
		and ns.GetPatronValueGold("patronKnowledgeValueGold", PATRON_VALUE.knowledgePointGold)
		or PATRON_VALUE.knowledgePointGold
	local knowledgeProgress = Pane:GetKnowledgeProgressForRecipe(recipeInfo)
	local knowledgeRemainingRatio = knowledgeProgress and knowledgeProgress.remainingRatio or 1
	local moxieValueGold = ns.GetPatronValueGold
		and ns.GetPatronValueGold("patronMoxieValueGold", PATRON_VALUE.moxiePerPointGold)
		or PATRON_VALUE.moxiePerPointGold
	local knowledgeValue = rewardKnowledge * knowledgeValueGold * knowledgeRemainingRatio * COPPER_PER_GOLD
	local firstCraftValue = firstCraftCount * PATRON_VALUE.firstCraft
	local skillUpValue = skillUpCount * PATRON_VALUE.skillUp
	local moxieValue = rewardMoxie * moxieValueGold * COPPER_PER_GOLD
	local deterministicValue = knowledgeValue + firstCraftValue + skillUpValue + moxieValue

	return {
		gold = rewardGold,
		itemValue = rewardItemValue,
		totalValue = rewardGold + rewardItemValue + deterministicValue,
		hasPriceData = rewardItemValue > 0 or deterministicValue > 0,
		isPriceComplete = marketableRewardCount > 0 and pricedRewardCount == marketableRewardCount,
		totalValueKnown = rewardGold > 0 or marketableRewardCount == 0 or pricedRewardCount == marketableRewardCount,
		totalValueComplete = marketableRewardCount == 0 or pricedRewardCount == marketableRewardCount,
		marketableItemCount = marketableRewardCount,
		excludedItemCount = excludedRewardCount,
		icons = rewardIcons,
		knowledge = rewardKnowledge,
		knowledgeValue = knowledgeValue,
		knowledgeReferenceValueGold = knowledgeValueGold,
		knowledgeRemainingRatio = knowledgeRemainingRatio,
		knowledgeAllocated = knowledgeProgress and knowledgeProgress.allocated or nil,
		knowledgeMaximum = knowledgeProgress and knowledgeProgress.maximum or nil,
		firstCraft = firstCraftCount > 0,
		firstCraftValue = firstCraftValue,
		skillUps = skillUpCount,
		skillUpValue = skillUpValue,
		moxie = rewardMoxie,
		moxieValue = moxieValue,
	}
end

local function GetRewardTooltipLabel(rewardIcon)
	if rewardIcon.currencyID then
		return GetCurrencyLink(rewardIcon.currencyID, rewardIcon.count)
			or (C_CurrencyInfo.GetBasicCurrencyInfo(rewardIcon.currencyID, rewardIcon.count) or {}).name
			or UNKNOWN
	end

	if LinkHasDisplayName(rewardIcon.itemLink) then
		return rewardIcon.itemLink
	end

	local resolvedLink = rewardIcon.itemID and Util.GetItemLink(rewardIcon.itemID)
	if LinkHasDisplayName(resolvedLink) then
		return resolvedLink
	end

	local itemName = rewardIcon.name or Util.GetItemName(rewardIcon.itemID)
	if itemName and itemName ~= "" then
		return rewardIcon.count and rewardIcon.count > 1 and FormatItemCountLabel(rewardIcon.count, itemName) or itemName
	end

	return rewardIcon.itemID and LF("ITEM_FALLBACK_FORMAT", rewardIcon.itemID) or UNKNOWN
end

local function IsAlchemyProfession(professionID)
	professionID = tonumber(professionID)
	if not professionID then
		return false
	end

	if professionID == 3 or professionID == 171 or professionID == 2906 then
		return true
	end

	local info = type(C_TradeSkillUI) == "table"
		and type(C_TradeSkillUI.GetProfessionInfoBySkillLineID) == "function"
		and C_TradeSkillUI.GetProfessionInfoBySkillLineID(professionID)
	if type(info) ~= "table" then
		return false
	end

	local professionName = tostring(info.professionName or ""):lower()
	local parentProfessionName = tostring(info.parentProfessionName or ""):lower()
	return professionName:find("alchemy", 1, true) ~= nil
		or professionName:find("alchim", 1, true) ~= nil
		or parentProfessionName:find("alchemy", 1, true) ~= nil
		or parentProfessionName:find("alchim", 1, true) ~= nil
end

local function GetConcentrationGoldCost(orderData)
	local points = tonumber(orderData and orderData.concentration and orderData.concentration.currentCost) or 0
	if points <= 0 then
		return 0
	end

	local professionID = tonumber(orderData and orderData.professionID)
	local isLeatherworking = professionID == 2 or professionID == 165 or professionID == 2915
	local goldPerPoint
	if isLeatherworking then
		goldPerPoint = PATRON_VALUE.concentrationLeatherworking
	elseif IsAlchemyProfession(professionID) then
		goldPerPoint = PATRON_VALUE.concentrationAlchemy
	else
		goldPerPoint = PATRON_VALUE.concentrationDefault
	end
	return points * goldPerPoint
end

local function EvaluateProfit(orderData)
	local reward = orderData and orderData.reward or {}
	local materialCost = orderData and orderData.materialCost or 0
	local concentrationCost = GetConcentrationGoldCost(orderData)
	local cost = materialCost + concentrationCost
	local materialEntryCount = #GetMaterialPlanEntries(orderData)
	local hasCostData = orderData and (materialEntryCount == 0 or orderData.materialCostKnown)
	local hasRewardData = reward.totalValueKnown
	if orderData then
		orderData.concentrationGoldCost = concentrationCost
		orderData.totalCost = cost
	end

	if not (hasCostData and hasRewardData) then
		return nil, false, false
	end

	local costComplete = materialEntryCount == 0 or orderData.materialCostComplete
	local rewardComplete = reward.totalValueComplete
	local central = _G.YayaCraftedPriceAPI
	local netValue = central and type(central.CalculateNetValue) == "function"
		and central.CalculateNetValue(reward.totalValue, 1, cost, 0)
		or (reward.totalValue or 0) - cost
	return netValue, netValue ~= nil, costComplete and rewardComplete
end

local function GetLockedStatus(slot, recipeInfo)
	if not (slot and slot.slotInfo and recipeInfo and recipeInfo.recipeID and recipeInfo.skillLineAbilityID) then
		return false, nil
	end

	return C_TradeSkillUI.GetReagentSlotStatus(slot.slotInfo.mcrSlotID, recipeInfo.recipeID, recipeInfo.skillLineAbilityID)
end

local function CreateOperationContext(orderData, suppliedReagents)
	local reagents = {}
	for _, suppliedReagent in ipairs(suppliedReagents or EMPTY_LIST) do
		local reagentInfo = suppliedReagent.reagentInfo
		local slotData = suppliedReagent.slotIndex and orderData.slotMap[suppliedReagent.slotIndex]
		if reagentInfo and slotData and slotData.dataSlotType == MUTABLE_SLOT_TYPE then
			AddMutableOperationReagent(reagents, reagentInfo, slotData.dataSlotIndex, reagentInfo.quantity)
		end
	end

	local operationInfo = GetOperationInfo(orderData, reagents, false)
	return reagents, operationInfo
end

local function ScoreMutableOption(orderData, slotData, option, baseReagents, baseOperation)
	if not (slotData and slotData.dataSlotType == MUTABLE_SLOT_TYPE and option.itemID and baseOperation) then
		return 0
	end

	local testReagents = CopyOperationReagents(baseReagents)
	AddMutableOperationReagent(testReagents, option, slotData.dataSlotIndex, slotData.quantityRequired)

	local operationInfo = GetOperationInfo(orderData, testReagents, false)
	if not operationInfo then
		return 0
	end

	local qualityDelta = ((operationInfo.craftingQuality or 0) - (baseOperation.craftingQuality or 0)) * 100000
	local concentrationDelta = (baseOperation.concentrationCost or 0) - (operationInfo.concentrationCost or 0)
	return qualityDelta + concentrationDelta
end

local function SortSlotOptions(left, right)
	if (left.score or 0) ~= (right.score or 0) then
		return (left.score or 0) > (right.score or 0)
	end

	local leftRank = GetMarketPreferenceRank(left.priceState, left.unitPrice)
	local rightRank = GetMarketPreferenceRank(right.priceState, right.unitPrice)
	if leftRank ~= rightRank then
		return leftRank < rightRank
	end

	local leftPrice = left.unitPrice or math.huge
	local rightPrice = right.unitPrice or math.huge
	if leftPrice ~= rightPrice then
		return leftPrice < rightPrice
	end

	if (left.ownedCount or 0) ~= (right.ownedCount or 0) then
		return (left.ownedCount or 0) > (right.ownedCount or 0)
	end

	return (left.reagentQuality or 0) > (right.reagentQuality or 0)
end

local function EstimateConcentrationCost(orderData, inventoryOnly, preferHighScore)
	local operationInfo = BuildStrategizedOperation(orderData, inventoryOnly, preferHighScore and "best" or "lowest")
	if not operationInfo then
		return nil
	end

	if orderData.requiredQuality > 0 and (operationInfo.craftingQuality or 0) < orderData.requiredQuality then
		return math.huge, operationInfo
	end

	return operationInfo.concentrationCost or 0, operationInfo
end

local function BuildRequiredReagents(orderData, reagentSlotSchematics, suppliedReagents)
	local coveredSlots = {}
	for _, suppliedReagent in ipairs(suppliedReagents or EMPTY_LIST) do
		if suppliedReagent.slotIndex then
			coveredSlots[suppliedReagent.slotIndex] = suppliedReagent.reagentInfo
		end
	end

	local requiredReagents = {}
	local mutableSlots = {}
	local staticMaterialEntries = {}
	local staticMissingRequiredSlots = 0
	local materialCost = 0
	local pricedSlotCount = 0
	local marketableSlotCount = 0
	local excludedSlotCount = 0
	local slotMap = {}

	for _, slot in ipairs(reagentSlotSchematics or EMPTY_LIST) do
		local slotData = {
			slotIndex = slot.slotIndex,
			dataSlotType = slot.dataSlotType,
			dataSlotIndex = slot.dataSlotIndex,
			required = slot.required,
			quantityRequired = slot.quantityRequired,
			covered = coveredSlots[slot.slotIndex],
			options = {},
		}

		slotData.locked, slotData.lockedReason = GetLockedStatus(slot, orderData.recipeInfo)
		slotMap[slot.slotIndex] = slotData

		if not slotData.covered then
			for _, reagent in ipairs(slot.reagents or {}) do
				if reagent.itemID then
					local itemLink = reagent.itemLink or reagent.hyperlink or Util.GetItemLink(reagent.itemID)
					local itemIdentity = GetReagentItemIdentity(reagent.itemID, itemLink)
					local priceInfo = Pricing:GetPriceInfo(itemIdentity, 1)
					local quality = Util.GetProfessionItemQuality(itemIdentity) or Util.GetProfessionItemQuality(reagent.itemID)
					local ownedCount, otherQualityOwnedCount, totalOwnedCount = Util.GetQualityAwareItemCounts(reagent.itemID, itemLink)
					local option = {
						itemID = reagent.itemID,
						itemLink = itemLink,
						itemIdentity = itemIdentity,
						name = Util.GetItemName(reagent.itemID),
						ownedCount = ownedCount,
						otherQualityOwnedCount = otherQualityOwnedCount,
						totalOwnedCount = totalOwnedCount,
						unitPrice = priceInfo.unitPrice,
						priceState = priceInfo.state,
						isMarketable = priceInfo.isMarketable,
						reagentQuality = quality,
						borderAtlas = GetBorderAtlas(reagent.itemID),
					}

					slotData.options[#slotData.options + 1] = option
				end
			end
		end

		if #slotData.options > 0 then
			-- La mise en file automatique et les listes d'achat n'engagent que le
			-- rang 1. Sommer toutes les qualites -- banque de guilde comprise --
			-- mettait shortage a 0 grace a un stock de rang 2, et le manque de
			-- rang 1 disparaissait. Le stock des autres qualites reste visible via
			-- option.otherQualityOwnedCount.
			local lowestQuality
			for _, option in ipairs(slotData.options) do
				local quality = option.reagentQuality
				if quality and (not lowestQuality or quality < lowestQuality) then
					lowestQuality = quality
				end
			end
			local availableTotal = 0
			for _, option in ipairs(slotData.options) do
				local quality = option.reagentQuality
				if not lowestQuality or not quality or quality <= lowestQuality then
					availableTotal = availableTotal + (option.ownedCount or 0)
				end
			end
			slotData.availableTotal = availableTotal
			slotData.shortage = math.max(0, slotData.quantityRequired - availableTotal)
		end

		if slotData.dataSlotType == MUTABLE_SLOT_TYPE and not slotData.covered and #slotData.options > 0 then
			mutableSlots[#mutableSlots + 1] = slotData
		elseif slot.required and not slotData.covered then
			local staticEntry = BuildMaterialEntry(slotData, SelectDefaultSlotOption(slotData), slotData.quantityRequired)
			if staticEntry then
				staticMaterialEntries[#staticMaterialEntries + 1] = staticEntry
			else
				staticMissingRequiredSlots = staticMissingRequiredSlots + 1
			end
		end

		if slot.required and not slotData.covered then
			requiredReagents[#requiredReagents + 1] = slotData
		end
	end

	orderData.slotMap = slotMap
	orderData.requiredReagents = requiredReagents
	orderData.mutableSlots = mutableSlots
	orderData.staticMaterialEntries = staticMaterialEntries
	orderData.staticMissingRequiredSlots = staticMissingRequiredSlots
	orderData.operationReagents, orderData.baseOperation = CreateOperationContext(orderData, suppliedReagents)

	for _, slotData in ipairs(mutableSlots) do
		for _, option in ipairs(slotData.options) do
			option.score = ScoreMutableOption(orderData, slotData, option, orderData.operationReagents, orderData.baseOperation)
		end

		table.sort(slotData.options, SortSlotOptions)

		local availableTotal = slotData.availableTotal or 0
		slotData.availableTotal = availableTotal
		slotData.shortage = math.max(0, slotData.quantityRequired - availableTotal)
	end

	orderData.qualityRequirement = EvaluateQualityRequirement(orderData)

	local qualityRequirement = orderData.qualityRequirement or {}
	-- The quality plan is useful for the UI, but automatic queueing must buy
	-- rank 1 materials. Keep the lowest plan before compacting the quality data.
	orderData.lowestMaterialPlan = qualityRequirement.lowestPlan or BuildLowestMaterialPlan(orderData)
	local materialPlan = qualityRequirement.activePlan or qualityRequirement.lowestPlan or BuildLowestMaterialPlan(orderData) or {}
	orderData.materialPlan = materialPlan

	for _, entry in ipairs(GetMaterialPlanEntries(orderData)) do
		local option = entry.option
		local quantity = entry.quantity or 0
		if option and quantity > 0 then
			if entry.marketValueExcluded then
				excludedSlotCount = excludedSlotCount + 1
			else
				marketableSlotCount = marketableSlotCount + 1
			end

			if not entry.marketValueExcluded and entry.totalPrice and entry.totalPrice > 0 then
				materialCost = materialCost + entry.totalPrice
						pricedSlotCount = pricedSlotCount + 1
			end
		end
	end

	orderData.materialCost = materialCost
	orderData.marketableMaterialEntryCount = marketableSlotCount
	orderData.excludedMaterialEntryCount = excludedSlotCount
	orderData.materialCostKnown = marketableSlotCount == 0 or pricedSlotCount == marketableSlotCount
	orderData.materialCostComplete = marketableSlotCount == 0 or pricedSlotCount == marketableSlotCount

	local activeOperation = materialPlan.operationInfo or orderData.baseOperation
	if orderData.requiredQuality > 0 and activeOperation and (activeOperation.craftingQuality or 0) < orderData.requiredQuality then
		local ownedFillCost = EstimateConcentrationCost(orderData, true, false)
		local bestOwnedCost = EstimateConcentrationCost(orderData, true, true)
		local lowestFillCost = qualityRequirement.lowestPlan
			and qualityRequirement.lowestPlan.operationInfo
			and qualityRequirement.lowestPlan.operationInfo.concentrationCost
		local bestMarketCost = qualityRequirement.reachablePlan
			and qualityRequirement.reachablePlan.operationInfo
			and qualityRequirement.reachablePlan.operationInfo.concentrationCost
		local currentCost = activeOperation.concentrationCost or 0
		local currencyID = activeOperation.concentrationCurrencyID or (orderData.baseOperation and orderData.baseOperation.concentrationCurrencyID)

		orderData.concentration = {
			currencyID = currencyID,
			currentCost = currentCost,
			lowestFillCost = lowestFillCost ~= currentCost and lowestFillCost or nil,
			ownedFillCost = ownedFillCost,
			bestOwnedCost = bestOwnedCost,
			bestMarketCost = bestMarketCost ~= currentCost and bestMarketCost or nil,
			available = GetCurrencyQuantity(currencyID),
		}
	end

	orderData.productTooltipLines = BuildProductTooltipLines(orderData)
	orderData.qualityRequirement = CompactQualityRequirement(orderData.qualityRequirement)
end

local function AppendFingerprintParts(parts, ...)
	for index = 1, select("#", ...) do
		local value = select(index, ...)
		parts[#parts + 1] = tostring(value == nil and "" or value)
	end
end

local function AppendRewardFingerprint(parts, rewards)
	for _, reward in ipairs(rewards or EMPTY_LIST) do
		AppendFingerprintParts(
			parts,
			reward.itemLink or reward.itemID or "",
			reward.currencyType or "",
			reward.count or reward.quantity or 1
		)
	end
end

local function AppendSuppliedReagentFingerprint(parts, suppliedReagents)
	for _, suppliedReagent in ipairs(suppliedReagents or EMPTY_LIST) do
		local reagentInfo = suppliedReagent.reagentInfo or {}
		AppendFingerprintParts(
			parts,
			suppliedReagent.slotIndex or "",
			reagentInfo.itemID or "",
			reagentInfo.itemLink or "",
			reagentInfo.currencyID or "",
			reagentInfo.quality or "",
			reagentInfo.quantity or suppliedReagent.quantity or 0
		)
	end
end

local function BuildOrderFingerprint(rawOrder)
	local parts = {}
	AppendFingerprintParts(
		parts,
		rawOrder and rawOrder.orderID or "",
		rawOrder and rawOrder.expirationTime or "",
		rawOrder and rawOrder.customerName or "",
		rawOrder and rawOrder.skillLineAbilityID or "",
		rawOrder and rawOrder.minQuality or "",
		rawOrder and rawOrder.tipAmount or "",
		rawOrder and rawOrder.consortiumCut or ""
	)
	AppendRewardFingerprint(parts, rawOrder and rawOrder.npcOrderRewards)
	AppendSuppliedReagentFingerprint(parts, rawOrder and rawOrder.reagents)
	return table.concat(parts, "|")
end

local function IsItemDataPending(itemID)
	if type(itemID) ~= "number" or itemID <= 0 then
		return false
	end

	if C_Item and type(C_Item.IsItemDataCachedByID) == "function" then
		local ok, isCached = pcall(C_Item.IsItemDataCachedByID, itemID)
		if ok then
			return not isCached
		end
	end

	return Util.GetItemName(itemID) == nil
end

local function TrackUnresolvedItemID(unresolvedItemIDs, itemID)
	if IsItemDataPending(itemID) then
		unresolvedItemIDs[itemID] = true
	end
end

local function CollectUnresolvedItemIDs(orderData)
	local unresolvedItemIDs = {}
	if not orderData then
		return unresolvedItemIDs
	end

	TrackUnresolvedItemID(unresolvedItemIDs, orderData.product and orderData.product.itemID)

	for _, rewardIcon in ipairs((orderData.reward and orderData.reward.icons) or EMPTY_LIST) do
		TrackUnresolvedItemID(unresolvedItemIDs, rewardIcon.itemID)
	end

	for _, slotData in ipairs(orderData.requiredReagents or EMPTY_LIST) do
		for _, option in ipairs(slotData.options or EMPTY_LIST) do
			TrackUnresolvedItemID(unresolvedItemIDs, option.itemID)
		end
	end

	return unresolvedItemIDs
end

local function OrderHasUnresolvedItemData(orderData)
	if not orderData then
		return false
	end
	return next(orderData.unresolvedItemIDs or EMPTY_LIST) ~= nil
end

local function PrepareOrder(rawOrder, professionID)
	local recipeInfo = GetRecipeInfo(rawOrder)
	local recipeSchematic = recipeInfo and GetRecipeSchematic(recipeInfo)
	if not (recipeInfo and recipeSchematic) then
		return nil
	end

	local output = GetOutputPresentation(rawOrder, recipeInfo)
	local rewardData = EvaluateRewardValue(rawOrder, recipeInfo)
	local isKnown = IsRecipeKnown(recipeInfo)
	local suppliedReagents = rawOrder.reagents
	local reagentSlotSchematics = recipeSchematic.reagentSlotSchematics
	local orderData = {
		orderID = rawOrder.orderID,
		isRecraft = rawOrder.isRecraft == true,
		customerName = rawOrder.customerName,
		expirationTime = rawOrder.expirationTime or 0,
		recipeInfo = recipeInfo,
		requiredQuality = GetOrderQuality(rawOrder),
		product = output,
		isKnown = isKnown,
		firstCraft = recipeInfo.firstCraft,
		canSkillUp = recipeInfo.canSkillUp,
		relativeDifficulty = recipeInfo.relativeDifficulty,
		skillUps = recipeInfo.numSkillUps or 0,
		professionID = professionID or Pane.visibleProfession or Pane:GetCurrentProfessionID(),
		unknownRecipeTooltip = isKnown and nil or BuildUnknownRecipeTooltip(recipeInfo),
		reward = rewardData,
	}

	BuildRequiredReagents(orderData, reagentSlotSchematics, suppliedReagents)
	orderData.profitValue, orderData.profitKnown, orderData.profitComplete = EvaluateProfit(orderData)
	orderData.unresolvedItemIDs = CollectUnresolvedItemIDs(orderData)
	orderData.hasUnresolvedItemData = OrderHasUnresolvedItemData(orderData)

	return orderData
end

function Pane:MarkDetailWarningDirty()
	self.detailWarningDataDirty = true
	if self:IsDetailWarningVisible() then
		self:ScheduleDetailWarningUpdate(DETAIL_WARNING_UPDATE_DELAY)
	end
end

function Pane:ScheduleDetailWarningUpdate(delay)
	if self.detailWarningTimerQueued then
		return
	end

	self.detailWarningTimerQueued = true
	C_Timer.After(delay or 0, function()
		Pane.detailWarningTimerQueued = nil
		if Pane and Pane:IsDetailWarningVisible() then
			Pane:UpdateDetailExpensiveWarning()
		end
	end)
end

function Pane:IsDetailWarningVisible()
	local _, _, schematicForm = self:GetCurrentOrderViewContext()
	return not not (schematicForm and schematicForm:IsShown())
end

function Pane:EnsureDetailWarningHooks()
	local _, _, schematicForm = self:GetCurrentOrderViewContext()
	if not schematicForm then
		return false
	end

	if not schematicForm.coppDetailWarningOnShowHooked then
		schematicForm.coppDetailWarningOnShowHooked = true
		schematicForm:HookScript("OnShow", function()
			Pane:ScheduleDetailWarningUpdate(0)
		end)
	end

	if not schematicForm.coppDetailWarningOnHideHooked then
		schematicForm.coppDetailWarningOnHideHooked = true
		schematicForm:HookScript("OnHide", function(self)
			if self.coppExpensiveIngredientWarning then
				self.coppExpensiveIngredientWarning:Hide()
			end
			Pane:HideDetailExpensiveIngredientSlotWarnings(self)
		end)
	end

	if type(schematicForm.Init) == "function" and not schematicForm.coppDetailWarningInitHooked then
		schematicForm.coppDetailWarningInitHooked = true
		hooksecurefunc(schematicForm, "Init", function()
			Pane:MarkDetailWarningDirty()
		end)
	end

	if type(schematicForm.RegisterCallback) == "function"
		and type(ProfessionsRecipeSchematicFormMixin) == "table"
		and ProfessionsRecipeSchematicFormMixin.Event
		and not schematicForm.coppDetailWarningCallbacksRegistered then
		schematicForm.coppDetailWarningCallbacksRegistered = true

		if ProfessionsRecipeSchematicFormMixin.Event.AllocationsModified then
			schematicForm:RegisterCallback(ProfessionsRecipeSchematicFormMixin.Event.AllocationsModified, function()
				Pane:ScheduleDetailWarningUpdate(0)
			end)
		end

		if ProfessionsRecipeSchematicFormMixin.Event.UseBestQualityModified then
			schematicForm:RegisterCallback(ProfessionsRecipeSchematicFormMixin.Event.UseBestQualityModified, function()
				Pane:ScheduleDetailWarningUpdate(0)
			end)
		end
	end

	return true
end

function Pane:EnsureExpensiveIngredientWarningFrame(schematicForm)
	if not schematicForm then
		return nil
	end

	local warningFrame = schematicForm.coppExpensiveIngredientWarning
	if warningFrame then
		return warningFrame
	end

	local parent = (schematicForm.AllocateBestQualityCheckbox and schematicForm.AllocateBestQualityCheckbox:GetParent()) or schematicForm
	warningFrame = CreateFrame("Button", nil, parent)
	warningFrame:SetHeight(18)
	warningFrame:Hide()

	warningFrame.icon = warningFrame:CreateTexture(nil, "ARTWORK")
	warningFrame.icon:SetTexture(DETAIL_WARNING_ICON_TEXTURE)
	warningFrame.icon:SetSize(16, 16)
	warningFrame.icon:SetPoint("LEFT", warningFrame, "LEFT", 0, 0)

	warningFrame.text = warningFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	warningFrame.text:SetPoint("LEFT", warningFrame.icon, "RIGHT", 4, 0)
	warningFrame.text:SetPoint("RIGHT", warningFrame, "RIGHT", 0, 0)
	warningFrame.text:SetJustifyH("LEFT")
	warningFrame.text:SetJustifyV("MIDDLE")

	warningFrame:SetScript("OnEnter", function(self)
		Pane:ShowDetailExpensiveWarningTooltip(self)
	end)
	warningFrame:SetScript("OnLeave", GameTooltip_Hide)

	schematicForm.coppExpensiveIngredientWarning = warningFrame
	return warningFrame
end

function Pane:EnsureExpensiveIngredientSlotWarning(slotFrame)
	if not slotFrame then
		return nil
	end

	local warningButton = slotFrame.coppExpensiveIngredientWarning
	if warningButton then
		return warningButton
	end

	warningButton = CreateFrame("Button", nil, slotFrame)
	warningButton:SetSize(16, 16)
	warningButton:SetFrameStrata(slotFrame:GetFrameStrata())
	warningButton:SetFrameLevel((slotFrame:GetFrameLevel() or 0) + 10)
	warningButton:Hide()

	warningButton.icon = warningButton:CreateTexture(nil, "ARTWORK")
	warningButton.icon:SetTexture(DETAIL_WARNING_ICON_TEXTURE)
	warningButton.icon:SetAllPoints()

	warningButton:SetScript("OnEnter", function(self)
		Pane:ShowDetailExpensiveIngredientSlotTooltip(self)
	end)
	warningButton:SetScript("OnLeave", GameTooltip_Hide)

	slotFrame.coppExpensiveIngredientWarning = warningButton
	return warningButton
end

function Pane:HideDetailExpensiveIngredientSlotWarnings(schematicForm)
	for _, slotFrame in ipairs((schematicForm and schematicForm.coppTrackedExpensiveIngredientSlots) or EMPTY_LIST) do
		local warningButton = slotFrame and slotFrame.coppExpensiveIngredientWarning
		if warningButton then
			warningButton:Hide()
		end
	end
end

function Pane:GetDetailReagentSlotFrames(schematicForm)
	local slotFramesByIndex = {}
	local visitedFrames = {}

	local function TrackSlotFrame(frame)
		if not frame or type(frame.GetReagentSlotSchematic) ~= "function" then
			return
		end

		local ok, slotSchematic = pcall(frame.GetReagentSlotSchematic, frame)
		local slotIndex = ok and slotSchematic and slotSchematic.slotIndex or nil
		if not slotIndex then
			return
		end

		local existing = slotFramesByIndex[slotIndex]
		local existingHasButton = existing and existing.Button ~= nil
		local frameHasButton = frame.Button ~= nil
		if not existing or (frameHasButton and not existingHasButton) then
			slotFramesByIndex[slotIndex] = frame
		end
	end

	local function Visit(frame, depth)
		if not frame or visitedFrames[frame] or depth > 4 then
			return
		end

		visitedFrames[frame] = true
		TrackSlotFrame(frame)

		if type(frame.GetChildren) ~= "function" then
			return
		end

		for _, child in ipairs({ frame:GetChildren() }) do
			Visit(child, depth + 1)
		end
	end

	Visit(schematicForm and schematicForm.Reagents, 0)
	Visit(schematicForm and schematicForm.OptionalReagents, 0)
	for _, frame in ipairs((schematicForm and schematicForm.extraSlotFrames) or EMPTY_LIST) do
		Visit(frame, 0)
	end

	if next(slotFramesByIndex) == nil then
		Visit(schematicForm, 0)
	end

	local orderedFrames = {}
	for slotIndex, frame in pairs(slotFramesByIndex) do
		orderedFrames[#orderedFrames + 1] = {
			slotIndex = slotIndex,
			frame = frame,
		}
	end

	table.sort(orderedFrames, function(left, right)
		return (left.slotIndex or 0) < (right.slotIndex or 0)
	end)

	local slotFrames = {}
	for _, entry in ipairs(orderedFrames) do
		slotFrames[#slotFrames + 1] = entry.frame
	end

	schematicForm.coppTrackedExpensiveIngredientSlots = slotFrames
	return slotFrames
end

function Pane:ShowDetailExpensiveIngredientSlotTooltip(frame)
	local warningEntries = frame and frame.warningEntries or EMPTY_LIST
	local warningColor = GetWarningColor()
	local savingsColor = GetSavingsColor()
	local mutedColor = GetMutedTooltipColor()
	local totalSavings = 0
	local showAggregateSaving = #warningEntries > 1

	GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
	GameTooltip:SetText(L.WARNING_ITEM_TITLE, warningColor.r, warningColor.g, warningColor.b)
	GameTooltip:AddLine(L.WARNING_ITEM_SUBTITLE, mutedColor.r, mutedColor.g, mutedColor.b, true)

	for entryIndex, entry in ipairs(warningEntries) do
		local selectedLabel = entry.selectedOption.itemLink or entry.selectedOption.name or UNKNOWN
		local cheapestLabel = entry.cheapestOption.itemLink or entry.cheapestOption.name or UNKNOWN
		local entrySavings = math.max(0, entry.totalSavings or 0)
		totalSavings = totalSavings + entrySavings

		if entryIndex == 1 then
			GameTooltip:AddLine(" ")
		else
			GameTooltip:AddLine(" ")
		end

		GameTooltip:AddDoubleLine(
			FormatItemCountLabel(entry.quantity or 0, selectedLabel),
			LF("WARNING_ITEM_LINE_RIGHT_FORMAT", entry.percentAboveRounded or 0),
			1,
			1,
			1,
			warningColor.r,
			warningColor.g,
			warningColor.b
		)
		GameTooltip:AddDoubleLine(L.WARNING_SELECTED_UNIT_COST, Util.FormatMoney(entry.selectedUnitPrice), 1, 1, 1, 1, 1, 1)
		GameTooltip:AddDoubleLine(L.WARNING_CHEAPEST_UNIT_COST, Util.FormatMoney(entry.cheapestUnitPrice), mutedColor.r, mutedColor.g, mutedColor.b, 1, 1, 1)
		GameTooltip:AddLine(LF("WARNING_CHEAPER_QUALITY_FORMAT", cheapestLabel), mutedColor.r, mutedColor.g, mutedColor.b, true)
		GameTooltip:AddDoubleLine(
			L.WARNING_POTENTIAL_SAVING,
			Util.FormatMoney(entrySavings),
			savingsColor.r,
			savingsColor.g,
			savingsColor.b,
			savingsColor.r,
			savingsColor.g,
			savingsColor.b
		)
	end

	GameTooltip:AddLine(" ")
	if showAggregateSaving and totalSavings > 0 then
		GameTooltip:AddDoubleLine(
			L.WARNING_TOTAL_POTENTIAL_SAVING,
			Util.FormatMoney(totalSavings),
			1,
			1,
			1,
			savingsColor.r,
			savingsColor.g,
			savingsColor.b
		)
		GameTooltip:AddLine(" ")
	end
	GameTooltip:AddLine(L.WARNING_ITEM_SELF_SUPPLIED_ONLY, mutedColor.r, mutedColor.g, mutedColor.b, true)
	GameTooltip:Show()
end

function Pane:ShowDetailExpensiveWarningTooltip(frame)
	local thresholdPercent = frame and frame.thresholdPercent or GetExpensiveIngredientThresholdPercent()
	local warningCount = frame and frame.warningCount or 0
	local totalSavings = frame and frame.totalSavings or 0
	local warningColor = GetWarningColor()
	local savingsColor = GetSavingsColor()
	local mutedColor = GetMutedTooltipColor()

	GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
	GameTooltip:SetText(L.WARNING_SUMMARY_TITLE, warningColor.r, warningColor.g, warningColor.b)
	GameTooltip:AddLine(
		LF("WARNING_SUMMARY_DESC_FORMAT", thresholdPercent),
		mutedColor.r,
		mutedColor.g,
		mutedColor.b,
		true
	)
	if warningCount > 0 then
		GameTooltip:AddLine(" ")
		GameTooltip:AddDoubleLine(L.WARNING_SUMMARY_AFFECTED_INGREDIENTS, tostring(warningCount), 1, 1, 1, 1, 1, 1)
		if totalSavings > 0 then
			GameTooltip:AddDoubleLine(
				L.WARNING_TOTAL_POTENTIAL_SAVING,
				Util.FormatMoney(totalSavings),
				1,
				1,
				1,
				savingsColor.r,
				savingsColor.g,
				savingsColor.b
			)
		end
	end

	GameTooltip:AddLine(" ")
	GameTooltip:AddLine(L.WARNING_SUMMARY_HOVER_HINT, mutedColor.r, mutedColor.g, mutedColor.b, true)
	GameTooltip:AddLine(L.WARNING_SUMMARY_SELF_SUPPLIED_ONLY, mutedColor.r, mutedColor.g, mutedColor.b, true)
	GameTooltip:Show()
end

function Pane:RefreshDetailWarningOrderData(orderInfo)
	if not (orderInfo and orderInfo.orderID) then
		self.detailWarningOrderID = nil
		self.detailWarningOrderData = nil
		self.detailWarningDataDirty = nil
		return nil
	end

	if not self.detailWarningDataDirty
		and self.detailWarningOrderID == orderInfo.orderID
		and self.detailWarningOrderData then
		return self.detailWarningOrderData
	end

	self.detailWarningOrderID = orderInfo.orderID
	self.detailWarningOrderData = PrepareOrder(orderInfo)
	self.detailWarningDataDirty = nil
	return self.detailWarningOrderData
end

function Pane:BuildExpensiveIngredientWarnings(orderData, transaction, thresholdPercent)
	local warningEntries = {}
	if not (orderData and transaction) then
		return warningEntries
	end

	for slotIndex, slotData in pairs(orderData.slotMap or EMPTY_LIST) do
		if slotData and not slotData.covered and not slotData.locked then
			local cheapestByGroup = {}
			local groupCounts = {}

			for _, option in ipairs(slotData.options or EMPTY_LIST) do
				local groupKey = GetExpensiveIngredientGroupKey(option)
				if groupKey and IsPricedMarketOption(option) then
					groupCounts[groupKey] = (groupCounts[groupKey] or 0) + 1
					if IsCheaperWarningOption(option, cheapestByGroup[groupKey]) then
						cheapestByGroup[groupKey] = option
					end
				end
			end

			local allocations = type(transaction.GetAllocations) == "function" and transaction:GetAllocations(slotIndex) or nil
			if allocations and type(allocations.FindAllocationByReagent) == "function" then
				for _, option in ipairs(slotData.options or EMPTY_LIST) do
					local groupKey = GetExpensiveIngredientGroupKey(option)
					local cheapestOption = groupKey and cheapestByGroup[groupKey]
					if groupKey
						and cheapestOption
						and cheapestOption ~= option
						and (groupCounts[groupKey] or 0) > 1
						and IsPricedMarketOption(option)
						and type(cheapestOption.unitPrice) == "number"
						and cheapestOption.unitPrice > 0 then
						local reagent = self:FindTransactionReagent(transaction, slotIndex, option)
						local allocation = reagent and allocations:FindAllocationByReagent(reagent)
						local quantity = allocation and type(allocation.GetQuantity) == "function" and allocation:GetQuantity() or 0
						if quantity > 0 then
							local percentAbove = ((option.unitPrice - cheapestOption.unitPrice) / cheapestOption.unitPrice) * 100
							if percentAbove > thresholdPercent then
								local totalSavings = math.max(0, (option.unitPrice - cheapestOption.unitPrice) * quantity)
								warningEntries[#warningEntries + 1] = {
									slotIndex = slotIndex,
									quantity = quantity,
									selectedOption = option,
									selectedUnitPrice = option.unitPrice,
									cheapestOption = cheapestOption,
									cheapestUnitPrice = cheapestOption.unitPrice,
									percentAbove = percentAbove,
									percentAboveRounded = math.floor(percentAbove + 0.5),
									totalSavings = totalSavings,
								}
							end
						end
					end
				end
			end
		end
	end

	table.sort(warningEntries, function(left, right)
		if (left.percentAbove or 0) ~= (right.percentAbove or 0) then
			return (left.percentAbove or 0) > (right.percentAbove or 0)
		end
		if (left.selectedUnitPrice or 0) ~= (right.selectedUnitPrice or 0) then
			return (left.selectedUnitPrice or 0) > (right.selectedUnitPrice or 0)
		end
		return (left.slotIndex or 0) < (right.slotIndex or 0)
	end)

	return warningEntries
end

function Pane:UpdateDetailExpensiveIngredientSlotWarnings(schematicForm, warningEntries, thresholdPercent)
	self:HideDetailExpensiveIngredientSlotWarnings(schematicForm)

	if not (schematicForm and warningEntries and #warningEntries > 0) then
		return
	end

	local warningsBySlot = {}
	for _, entry in ipairs(warningEntries) do
		local slotIndex = entry.slotIndex
		if slotIndex then
			local bucket = warningsBySlot[slotIndex]
			if not bucket then
				bucket = {}
				warningsBySlot[slotIndex] = bucket
			end
			bucket[#bucket + 1] = entry
		end
	end

	for _, slotFrame in ipairs(self:GetDetailReagentSlotFrames(schematicForm)) do
		local ok, slotSchematic = pcall(slotFrame.GetReagentSlotSchematic, slotFrame)
		local slotIndex = ok and slotSchematic and slotSchematic.slotIndex or nil
		local slotWarnings = slotIndex and warningsBySlot[slotIndex] or nil
		local warningButton = slotWarnings and self:EnsureExpensiveIngredientSlotWarning(slotFrame) or nil
		if warningButton and slotWarnings and #slotWarnings > 0 then
			local anchorTo = slotFrame.Button or slotFrame
			warningButton.warningEntries = slotWarnings
			warningButton.thresholdPercent = thresholdPercent
			warningButton:ClearAllPoints()
			warningButton:SetPoint("TOPRIGHT", anchorTo, "TOPRIGHT", 4, 2)
			warningButton:Show()
		end
	end
end

function Pane:UpdateDetailExpensiveWarning()
	self:EnsureDetailWarningHooks()

	local _, orderInfo, schematicForm, transaction = self:GetCurrentOrderViewContext()
	local warningFrame = schematicForm and self:EnsureExpensiveIngredientWarningFrame(schematicForm) or nil
	local checkbox = schematicForm and schematicForm.AllocateBestQualityCheckbox
	if not warningFrame then
		return
	end

	if ns.GetConfig("warnExpensiveIngredients") == false
		or not (schematicForm and schematicForm:IsShown())
		or not transaction
		or not orderInfo then
		warningFrame:Hide()
		self:HideDetailExpensiveIngredientSlotWarnings(schematicForm)
		return
	end

	local orderData = self:RefreshDetailWarningOrderData(orderInfo)
	local thresholdPercent = GetExpensiveIngredientThresholdPercent()
	local warningEntries = self:BuildExpensiveIngredientWarnings(orderData, transaction, thresholdPercent)
	self:UpdateDetailExpensiveIngredientSlotWarnings(schematicForm, warningEntries, thresholdPercent)
	if #warningEntries == 0 or not (checkbox and checkbox:IsShown()) then
		warningFrame:Hide()
		return
	end

	local warningColor = GetWarningColor()
	local warningCount = #warningEntries
	local warningText = L.WARNING_SUMMARY_LABEL
	local totalSavings = 0
	for _, entry in ipairs(warningEntries) do
		totalSavings = totalSavings + math.max(0, entry.totalSavings or 0)
	end
	local checkboxLabel = checkbox and (checkbox.Text or checkbox.text)
	local anchorTarget = checkboxLabel or checkbox
	warningFrame.warningEntries = warningEntries
	warningFrame.thresholdPercent = thresholdPercent
	warningFrame.warningCount = warningCount
	warningFrame.totalSavings = totalSavings
	warningFrame:ClearAllPoints()
	warningFrame:SetPoint("LEFT", anchorTarget, "RIGHT", 10, 0)
	warningFrame.text:SetText(warningText)
	warningFrame:SetWidth(20 + warningFrame.text:GetStringWidth())
	warningFrame.text:SetTextColor(warningColor.r, warningColor.g, warningColor.b)
	warningFrame:Show()
end

local function CompareRewards(left, right)
	if left.reward.knowledge ~= right.reward.knowledge then
		return left.reward.knowledge > right.reward.knowledge
	end
	if left.reward.moxie ~= right.reward.moxie then
		return left.reward.moxie > right.reward.moxie
	end
	if left.reward.totalValue ~= right.reward.totalValue then
		return left.reward.totalValue > right.reward.totalValue
	end
	return left.expirationTime < right.expirationTime
end

local function CompareProfit(left, right)
	local leftProfit = NumericSortValue(left.profitValue)
	local rightProfit = NumericSortValue(right.profitValue)
	if leftProfit ~= rightProfit then
		return leftProfit > rightProfit
	end
	if left.profitKnown ~= right.profitKnown then
		return left.profitKnown
	end
	if left.product.plainLabel ~= right.product.plainLabel then
		return left.product.plainLabel < right.product.plainLabel
	end
	return CompareRewards(left, right)
end

local function SortOrders(orders, sortKey, ascending)
	table.sort(orders, function(left, right)
		local result
		if sortKey == "order" then
			if left.isKnown ~= right.isKnown then
				result = left.isKnown
			elseif left.product.plainLabel ~= right.product.plainLabel then
				result = left.product.plainLabel < right.product.plainLabel
			else
				result = CompareRewards(left, right)
			end
		elseif sortKey == "cost" then
			local leftCost = NumericSortValue(left.materialCost)
			local rightCost = NumericSortValue(right.materialCost)
			if leftCost ~= rightCost then
				result = leftCost < rightCost
			else
				result = left.product.plainLabel < right.product.plainLabel
			end
		elseif sortKey == "profit" then
			result = CompareProfit(left, right)
		elseif sortKey == "time" then
			if left.expirationTime ~= right.expirationTime then
				result = left.expirationTime < right.expirationTime
			elseif left.product.plainLabel ~= right.product.plainLabel then
				result = left.product.plainLabel < right.product.plainLabel
			else
				result = CompareRewards(left, right)
			end
		else
			result = CompareRewards(left, right)
		end

		if ascending then
			return not result
		end

		return result
	end)
end

function Pane:ShowCostTooltip(row)
	GameTooltip:SetOwner(row.costHitBox, "ANCHOR_RIGHT")
	GameTooltip:SetText(L.TOOLTIP_SUPPLIED_MATERIALS)

	if #GetMaterialPlanEntries(row.order) == 0 then
		GameTooltip:AddLine(L.TOOLTIP_ALL_REQUIRED_REAGENTS_ALREADY_SUPPLIED, 1, 1, 1, true)
	else
		for _, entry in ipairs(GetMaterialPlanEntries(row.order)) do
			local option = entry.option
			if option then
				local line = FormatItemCountLabel(entry.quantity or 0, option.name or UNKNOWN)
				local right = GetPriceDisplayText(entry.totalPrice, entry.priceState)
				GameTooltip:AddDoubleLine(line, right, 1, 1, 1, 1, 1, 1)
			end
		end
	end

	if row.order.concentration then
		local concentration = row.order.concentration
		GameTooltip:AddLine(" ")
		GameTooltip:AddDoubleLine(L.TOOLTIP_CURRENT_CONCENTRATION, FormatConcentrationValue(concentration.currentCost or 0), 1, 1, 1, 1, 1, 1)
		if concentration.lowestFillCost ~= nil then
			GameTooltip:AddDoubleLine(L.TOOLTIP_LOWEST_QUALITY_MATERIALS, FormatConcentrationValue(concentration.lowestFillCost), 0.9, 0.9, 0.9, 1, 1, 1)
		end
		if concentration.ownedFillCost ~= nil then
			GameTooltip:AddDoubleLine(L.TOOLTIP_WITH_OWNED_REAGENTS, FormatConcentrationValue(concentration.ownedFillCost), 0.9, 0.9, 0.9, 1, 1, 1)
		end
		if concentration.bestOwnedCost ~= nil then
			GameTooltip:AddDoubleLine(L.TOOLTIP_BEST_OWNED_MIX, FormatConcentrationValue(concentration.bestOwnedCost), 0.9, 0.9, 0.9, 1, 1, 1)
		end
		if concentration.bestMarketCost ~= nil then
			GameTooltip:AddDoubleLine(L.TOOLTIP_BEST_MARKET_MIX, FormatConcentrationValue(concentration.bestMarketCost), 0.9, 0.9, 0.9, 1, 1, 1)
		end
	end

	GameTooltip:Show()
end

function Pane:ShowRewardTooltip(row)
	GameTooltip:SetOwner(row.rewardHitBox, "ANCHOR_RIGHT")
	GameTooltip:SetText(L.TOOLTIP_REWARD_VALUE)
	GameTooltip:AddDoubleLine(L.TOOLTIP_GOLD, Util.FormatMoney(row.order.reward.gold), 1, 1, 1, 1, 1, 1)

	for _, rewardIcon in ipairs(row.order.reward.icons) do
		if rewardIcon.itemLink or rewardIcon.currencyID then
			local left = GetRewardTooltipLabel(rewardIcon)
			local right = GetPriceDisplayText(rewardIcon.totalPrice, rewardIcon.priceState)
			GameTooltip:AddDoubleLine(left, right, 1, 1, 1, 1, 1, 1)
		end
	end

	if row.order.reward.hasPriceData then
		GameTooltip:AddLine(" ")
		GameTooltip:AddDoubleLine(L.TOOLTIP_TOTAL, Util.FormatMoney(row.order.reward.totalValue), 1, 1, 1, 1, 1, 1)
	end

	GameTooltip:Show()
end

function Pane:ShowProfitTooltip(row)
	GameTooltip:SetOwner(row.profitHitBox, "ANCHOR_RIGHT")
	GameTooltip:SetText(L.TOOLTIP_ESTIMATED_PROFIT)

	if not row.order.profitKnown then
		GameTooltip:AddLine(L.TOOLTIP_NOT_ENOUGH_MARKET_DATA, 1, 1, 1, true)
		GameTooltip:Show()
		return
	end

	GameTooltip:AddDoubleLine(L.TOOLTIP_REWARD_TOTAL, FormatSignedMoney(math.max(0, row.order.reward.totalValue or 0)), 1, 1, 1, 1, 1, 1)
	GameTooltip:AddDoubleLine(
		L.TOOLTIP_SUPPLY_COST,
		FormatSignedMoney(-math.max(0, row.order.totalCost or row.order.materialCost or 0)),
		1,
		1,
		1,
		RED_FONT_COLOR.r,
		RED_FONT_COLOR.g,
		RED_FONT_COLOR.b
	)
	GameTooltip:AddLine(" ")

	local value = row.order.profitValue or 0
	local color = value < 0 and RED_FONT_COLOR or HIGHLIGHT_FONT_COLOR
	local rightText = FormatSignedMoney(value)
	if not row.order.profitComplete then
		rightText = rightText .. "*"
	end
	GameTooltip:AddDoubleLine(L.TOOLTIP_NET_PROFIT, rightText, NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, color.r, color.g, color.b)

	if not row.order.profitComplete then
		GameTooltip:AddLine(L.TOOLTIP_PARTIAL_MARKET_DATA, 0.95, 0.95, 0.95)
	end

	GameTooltip:Show()
end

function Pane:ShowIconTooltip(iconFrame)
	local data = iconFrame.data
	if not data then
		return
	end

	GameTooltip:SetOwner(iconFrame, "ANCHOR_RIGHT")
	if data.itemLink then
		GameTooltip:SetHyperlink(data.itemLink)
	elseif data.itemID then
		GameTooltip:SetHyperlink(("item:%d"):format(data.itemID))
	elseif data.currencyID then
		GameTooltip:SetCurrencyByID(data.currencyID)
	end

	if data.reagentQuality and data.selectedQualityOwnedCount ~= nil then
		GameTooltip:AddLine(" ")
		GameTooltip:AddDoubleLine(L.ICON_AVAILABLE_SELECTED_QUALITY, tostring(data.selectedQualityOwnedCount), 1, 1, 1, 1, 1, 1)
		if (data.otherQualityOwnedCount or 0) > 0 then
			local warningColor = WARNING_FONT_COLOR or { r = 1, g = 0.282, b = 0 }
			GameTooltip:AddDoubleLine(L.ICON_AVAILABLE_OTHER_QUALITIES, tostring(data.otherQualityOwnedCount), 1, 1, 1, warningColor.r, warningColor.g, warningColor.b)
			if (data.shortage or 0) > 0 then
				GameTooltip:AddLine(L.ICON_OTHER_QUALITIES_HINT, warningColor.r, warningColor.g, warningColor.b, true)
			end
		end
	elseif data.availableTotal then
		GameTooltip:AddLine(" ")
		GameTooltip:AddDoubleLine(L.ICON_AVAILABLE, tostring(data.availableTotal), 1, 1, 1, 1, 1, 1)
	end

	local hasPricingState = data.totalPrice ~= nil or data.unitPrice ~= nil or data.priceState ~= nil
	if hasPricingState then
		if data.totalPrice then
			GameTooltip:AddDoubleLine(L.ICON_MARKET_VALUE, Util.FormatMoney(data.totalPrice), 1, 1, 1, 1, 1, 1)
		elseif data.unitPrice then
			GameTooltip:AddDoubleLine(L.ICON_UNIT_VALUE, Util.FormatMoney(data.unitPrice), 1, 1, 1, 1, 1, 1)
		elseif IsExcludedFromMarketValue(data.priceState) then
			GameTooltip:AddLine(L.PRICE_NOT_MARKETABLE, 0.95, 0.95, 0.95, true)
		elseif data.itemID then
			GameTooltip:AddLine(L.PRICE_NO_MARKET_DATA, 0.95, 0.95, 0.95, true)
		end
	end

	if data.extraLines then
		for _, line in ipairs(data.extraLines) do
			GameTooltip:AddLine(line, 0.95, 0.95, 0.95, true)
		end
	end

	if data.toggleDontBuy and data.itemID then
		GameTooltip:AddLine(" ")
		if data.doNotBuy then
			GameTooltip:AddLine(("|cffff4040%s|r"):format(L.DONT_BUY_MARKED), 1, 1, 1, true)
			GameTooltip:AddLine(L.DONT_BUY_MARKED_DESC, 0.95, 0.95, 0.95, true)
		else
			GameTooltip:AddLine(L.DONT_BUY_CLICK_TO_MARK, 1, 1, 1, true)
			GameTooltip:AddLine(L.DONT_BUY_DESC, 0.95, 0.95, 0.95, true)
		end
	end

	if not data.isKnown and data.unknownRecipeLines then
		local addonTitle = ns.GetAddonMetadata and ns.GetAddonMetadata(ns.ADDON_NAME, "Title") or nil
		GameTooltip:AddLine(" ")
		GameTooltip:AddLine(("%s%s|r"):format(
			ns.UI and ns.UI.HEX.accent or "|cff00ff98",
			addonTitle or L.ADDON_TITLE or ns.ADDON_NAME), 0.95, 0.95, 0.95, true)
		for _, line in ipairs(data.unknownRecipeLines) do
			GameTooltip:AddLine(line, 0.95, 0.95, 0.95, true)
		end
	end

	GameTooltip:Show()
end

function Pane:SetIconData(iconFrame, data)
	iconFrame.data = data
	if not data then
		if iconFrame.favorite then
			iconFrame.favorite:Hide()
		end
		iconFrame:Hide()
		return
	end

	iconFrame.icon:SetTexture(data.icon or "Interface/Icons/INV_Misc_QuestionMark")
	iconFrame.border:SetAtlas(data.borderAtlas or GetBorderAtlas(data.itemID))
	iconFrame.count:SetText(FormatCount(data.count, data.alwaysShowCount))
	iconFrame.icon:SetDesaturated(data.desaturated)
	if iconFrame.favorite then
		iconFrame.favorite:SetShown(not not data.favoriteBadge)
	end
	if iconFrame.blocked then
		iconFrame.blocked:SetShown(not not data.doNotBuy)
	end
	if data.shortage and data.shortage > 0 then
		if (data.otherQualityOwnedCount or 0) > 0 then
			local warningColor = WARNING_FONT_COLOR or { r = 1, g = 0.282, b = 0 }
			iconFrame.count:SetTextColor(warningColor.r, warningColor.g, warningColor.b)
		else
			iconFrame.count:SetTextColor(1, 0.2, 0.2)
		end
	else
		iconFrame.count:SetTextColor(1, 1, 1)
	end
	iconFrame:Show()
end

function Pane:CreateIcon(parent)
	local iconButton = CreateFrame("Button", nil, parent)
	iconButton:SetSize(REAGENT_ICON_SIZE, REAGENT_ICON_SIZE)
	iconButton.icon = iconButton:CreateTexture(nil, "ARTWORK")
	iconButton.icon:SetAllPoints()

	iconButton.border = iconButton:CreateTexture(nil, "OVERLAY")
	iconButton.border:SetAllPoints()
	iconButton.border:SetAtlas("Professions-Slot-Frame")

	iconButton.favorite = iconButton:CreateTexture(nil, "OVERLAY", nil, 1)
	iconButton.favorite:SetAtlas("auctionhouse-icon-favorite", true)
	iconButton.favorite:SetSize(12, 12)
	iconButton.favorite:SetPoint("TOPRIGHT", iconButton, "TOPRIGHT", 3, 2)
	iconButton.favorite:Hide()

	iconButton.blocked = iconButton:CreateTexture(nil, "HIGHLIGHT")
	iconButton.blocked:SetTexture(DONT_BUY_OVERLAY_TEXTURE)
	iconButton.blocked:SetSize(18, 18)
	iconButton.blocked:SetPoint("CENTER", iconButton, "CENTER")
	iconButton.blocked:Hide()

	iconButton.count = iconButton:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
	iconButton.count:SetPoint("BOTTOMRIGHT", iconButton, "BOTTOMRIGHT", -2, 2)
	iconButton.count:SetJustifyH("RIGHT")

	iconButton:SetScript("OnEnter", function(self)
		Pane:ShowIconTooltip(self)
	end)
	iconButton:SetScript("OnLeave", GameTooltip_Hide)
	iconButton:SetScript("OnClick", function(self, button)
		local data = self.data
		if IsModifiedClick("CHATLINK") then
			local link = data and (data.itemLink or GetCurrencyLink(data.currencyID, data.count))
			if link then
				ChatFrameUtil.InsertLink(link)
				return
			end
		end

		if button == "LeftButton" and data and data.toggleDontBuy and data.itemID then
			Pane:ToggleDontBuyItem(data.itemID)
			if GameTooltip:IsOwned(self) then
				Pane:ShowIconTooltip(self)
			end
			return
		end

		Pane:ViewOrder(self.row and self.row.order)
	end)

	return iconButton
end

function Pane:FindLiveOrderInfo(orderID)
	if not orderID then
		return nil
	end

	for _, orderInfo in ipairs(C_CraftingOrders.GetCrafterOrders() or EMPTY_LIST) do
		if orderInfo.orderID == orderID then
			return orderInfo
		end
	end

	return nil
end

function Pane:BuildPendingOpenPlan(orderData)
	if not (orderData and orderData.orderID and orderData.recipeInfo and orderData.recipeInfo.recipeID) then
		return nil
	end

	local slotAllocations = {}
	local clearSlotIndices = {}

	for slotIndex, slotData in pairs(orderData.slotMap or {}) do
		if slotData and not slotData.covered then
			clearSlotIndices[#clearSlotIndices + 1] = slotIndex
		end
	end
	table.sort(clearSlotIndices)

	for _, entry in ipairs(GetMaterialPlanEntries(orderData)) do
		local slotData = entry.slotData
		local option = entry.option
		local quantity = entry.quantity or 0
		if slotData and option and quantity > 0 then
			CreatePendingSlotAllocation(slotAllocations, slotData.slotIndex, option.itemID, option.currencyID, quantity)
		end
	end

	return {
		orderID = orderData.orderID,
		recipeID = orderData.recipeInfo.recipeID,
		clearSlotIndices = clearSlotIndices,
		slotAllocations = slotAllocations,
		applyConcentration = not not (orderData.concentration and (orderData.concentration.currentCost or 0) > 0),
		attempts = 0,
	}
end

function Pane:GetCurrentOrderViewContext()
	local ordersPage = ProfessionsFrame and ProfessionsFrame.OrdersPage
	local orderView = ordersPage and ordersPage.OrderView
	local schematicForm = orderView and orderView.OrderDetails and orderView.OrderDetails.SchematicForm
	local transaction = schematicForm and ((type(schematicForm.GetTransaction) == "function" and schematicForm:GetTransaction()) or schematicForm.transaction)
	return orderView, orderView and orderView.order, schematicForm, transaction
end

function Pane:FindTransactionReagent(transaction, slotIndex, allocationData)
	if not (transaction and slotIndex and allocationData) then
		return nil
	end

	local reagentSlotSchematic = type(transaction.GetReagentSlotSchematic) == "function" and transaction:GetReagentSlotSchematic(slotIndex)
	for _, reagent in ipairs(reagentSlotSchematic and reagentSlotSchematic.reagents or EMPTY_LIST) do
		if allocationData.itemID and reagent.itemID == allocationData.itemID then
			return reagent
		end
		if allocationData.currencyID and reagent.currencyID == allocationData.currencyID then
			return reagent
		end
	end

	return nil
end

function Pane:ApplyPendingOrderPlanNow()
	local pending = self.pendingOpenPlan
	if not pending then
		return true
	end

	local orderView, orderInfo, schematicForm, transaction = self:GetCurrentOrderViewContext()
	if not (orderView and orderInfo and schematicForm and transaction) then
		return false
	end

	if orderInfo.orderID ~= pending.orderID then
		return false
	end

	if type(transaction.GetRecipeID) == "function" and pending.recipeID and transaction:GetRecipeID() ~= pending.recipeID then
		return false
	end

	-- The order transaction can exist before Blizzard's asynchronous recipe loader
	-- has finished initializing the schematic form. Updating the form in that gap
	-- makes Blizzard's UpdateRecipeDescription index a nil currentRecipeInfo.
	local currentRecipeInfo = type(schematicForm.GetRecipeInfo) == "function" and schematicForm:GetRecipeInfo() or schematicForm.currentRecipeInfo
	if not (currentRecipeInfo and currentRecipeInfo.recipeID == pending.recipeID) then
		return false
	end

	local checkbox = schematicForm.AllocateBestQualityCheckbox
	if checkbox and type(checkbox.SetChecked) == "function" then
		checkbox:SetChecked(false)
	end

	if type(Professions) == "table" and type(Professions.SetShouldAllocateBestQualityReagents) == "function" then
		pcall(Professions.SetShouldAllocateBestQualityReagents, false)
	end

	if type(transaction.SetManuallyAllocated) == "function" then
		pcall(transaction.SetManuallyAllocated, transaction, true)
	end

	for _, slotIndex in ipairs(pending.clearSlotIndices or EMPTY_LIST) do
		if type(transaction.ClearAllocations) == "function" then
			pcall(transaction.ClearAllocations, transaction, slotIndex)
		end
	end

	for slotIndex, allocationsData in pairs(pending.slotAllocations or {}) do
		local allocations = type(transaction.GetAllocations) == "function" and transaction:GetAllocations(slotIndex) or nil
		if allocations and type(allocations.Clear) == "function" then
			pcall(allocations.Clear, allocations)
		elseif type(transaction.ClearAllocations) == "function" then
			pcall(transaction.ClearAllocations, transaction, slotIndex)
		end

		for _, allocationData in ipairs(allocationsData) do
			local reagent = self:FindTransactionReagent(transaction, slotIndex, allocationData)
			if reagent then
				if allocations and type(allocations.Allocate) == "function" then
					pcall(allocations.Allocate, allocations, reagent, allocationData.quantity)
				elseif type(transaction.OverwriteAllocation) == "function" then
					pcall(transaction.OverwriteAllocation, transaction, slotIndex, reagent, allocationData.quantity)
				end
			end
		end
	end

	if type(transaction.SetApplyConcentration) == "function" then
		pcall(transaction.SetApplyConcentration, transaction, pending.applyConcentration)
	end

	if type(schematicForm.TriggerEvent) == "function"
		and type(ProfessionsRecipeSchematicFormMixin) == "table"
		and ProfessionsRecipeSchematicFormMixin.Event
		and ProfessionsRecipeSchematicFormMixin.Event.UseBestQualityModified then
		pcall(schematicForm.TriggerEvent, schematicForm, ProfessionsRecipeSchematicFormMixin.Event.UseBestQualityModified, false)
	end

	if type(schematicForm.UpdateAllSlots) == "function" then
		pcall(schematicForm.UpdateAllSlots, schematicForm)
	end
	if type(schematicForm.UpdateDetailsStats) == "function" then
		pcall(schematicForm.UpdateDetailsStats, schematicForm)
	end

	self:ScheduleDetailWarningUpdate(0)

	return true
end

function Pane:SchedulePendingOrderPlan(delay)
	if not self.pendingOpenPlan or self.pendingPlanTimerQueued then
		return
	end

	self.pendingPlanTimerQueued = true
	C_Timer.After(delay or 0, function()
		Pane.pendingPlanTimerQueued = nil
		Pane:TryApplyPendingOrderPlan()
	end)
end

function Pane:TryApplyPendingOrderPlan()
	local pending = self.pendingOpenPlan
	if not pending then
		return
	end

	if self:ApplyPendingOrderPlanNow() then
		self.pendingOpenPlan = nil
		return
	end

	pending.attempts = (pending.attempts or 0) + 1
	if pending.attempts < 20 then
		self:SchedulePendingOrderPlan(0.05)
	else
		self.pendingOpenPlan = nil
	end
end

function Pane:ViewOrder(orderData)
	if not (orderData and orderData.orderID) then
		return
	end

	local orderInfo = self:FindLiveOrderInfo(orderData.orderID)
	if orderInfo and ProfessionsFrame and ProfessionsFrame.OrdersPage then
		if ns.GetConfig("openPatronOrderBehavior") == "apply_plan" then
			self.pendingOpenPlan = self:BuildPendingOpenPlan(orderData)
		else
			self.pendingOpenPlan = nil
		end
		-- Blizzard's Init(nil) returns before cancelling the previous async recipe
		-- loader, whose stale callback then indexes a nil currentRecipeInfo.
		local _, _, schematicForm = self:GetCurrentOrderViewContext()
		if schematicForm and schematicForm.loader and type(schematicForm.loader.Cancel) == "function" then
			pcall(schematicForm.loader.Cancel, schematicForm.loader)
		end
		ProfessionsFrame.OrdersPage:ViewOrder(orderInfo)
		self:SchedulePendingOrderPlan(0)
		return
	end

	self.pendingOpenPlan = nil
	ns.Print(L.MSG_ORDER_NO_LONGER_AVAILABLE)
end

function Pane:CreateRow(index, row)
	local hasNativeLayout = row ~= nil
	row = row or CreateFrame("Button", nil, self.scrollChild or self.scrollFrame)
	row.rowIndex = index or row.rowIndex or 1
	if row.craftingOrdersInitialized then
		return row
	end

	row.craftingOrdersInitialized = true
	if self.rows and not row.trackedByPane then
		row.trackedByPane = true
		self.rows[#self.rows + 1] = row
	end
	row:SetHeight(ROW_HEIGHT)
	row:SetWidth(CONTENT_WIDTH)
	if not hasNativeLayout and self.scrollChild then
		row:SetPoint("LEFT", self.scrollChild, "LEFT", 0, 0)
		row:SetPoint("RIGHT", self.scrollChild, "RIGHT", -2, 0)
	end
	row:SetHighlightAtlas("talents-pvpflyout-rowhighlight")
	if ns.UI then
		-- Seules les trois composantes de teinte : l'alpha du token et le
		-- SetAlpha ci-dessous se multiplieraient, et 0.12 fois 0.75 rendrait
		-- la surbrillance invisible.
		local hover = ns.UI.COLOR.hover
		row:GetHighlightTexture():SetVertexColor(hover[1], hover[2], hover[3])
	else
		row:GetHighlightTexture():SetVertexColor(0.12, 0.48, 0.95)
	end
	row:GetHighlightTexture():SetAlpha(0.75)

	row.background = row:CreateTexture(nil, "BACKGROUND")
	row.background:SetAllPoints()
	if ns.UI then
		-- Unpack rend quatre valeurs : une expression and/or n'en garderait
		-- qu'une, et la couleur serait fausse.
		row.background:SetColorTexture(ns.UI.Unpack(
			row.rowIndex % 2 == 1 and ns.UI.COLOR.rowOdd or ns.UI.COLOR.rowEven))
	else
		row.background:SetColorTexture(1, 1, 1, row.rowIndex % 2 == 0 and 0.025 or 0.01)
	end

	row.checkbox = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
	row.checkbox:SetPoint("TOPLEFT", row, "TOPLEFT", 2, -12)
	row.checkbox:SetScript("OnClick", function(self)
		if self.row and self.row.order then
			Pane.selectedOrderIDs[self.row.order.orderID] = self:GetChecked() or nil
			Pane.selectedOrderIDsByProfession[GetProfessionSelectionKey(Pane.visibleProfession)] = Pane.selectedOrderIDs
			Pane:UpdateToolbar()
		end
	end)
	row.checkbox.row = row

	row.productIcon = self:CreateIcon(row)
	row.productIcon.row = row
	row.productIcon:SetSize(PRODUCT_ICON_SIZE, PRODUCT_ICON_SIZE)
	row.productIcon:SetPoint("TOPLEFT", row, "TOPLEFT", SELECT_WIDTH + PRODUCT_ICON_LEFT_OFFSET, PRODUCT_ICON_TOP_OFFSET)

	row.title = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	row.title:SetPoint("TOPLEFT", row.productIcon, "TOPRIGHT", PRODUCT_TEXT_GAP, -1)
	row.title:SetPoint("RIGHT", row, "LEFT", SELECT_WIDTH + ORDER_WIDTH - 6, 0)
	row.title:SetJustifyH("LEFT")

	row.flags = row:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	row.flags:SetPoint("TOPLEFT", row.title, "BOTTOMLEFT", 0, -2)
	row.flags:SetPoint("RIGHT", row.title, "RIGHT")
	row.flags:SetJustifyH("LEFT")

	row.reagentLabel = row:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	row.reagentLabel:SetPoint("TOPLEFT", row.title, "BOTTOMLEFT", 0, -3)
	row.reagentLabel:SetText("")
	row.reagentLabel:Hide()

	row.reagentIcons = {}

	row.costText = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	row.costText:SetPoint("TOPLEFT", row, "TOPLEFT", SELECT_WIDTH + ORDER_WIDTH + 8, -10)
	row.costText:SetPoint("RIGHT", row, "LEFT", SELECT_WIDTH + ORDER_WIDTH + COST_WIDTH - 6, 0)
	row.costText:SetJustifyH("LEFT")

	row.costHint = row:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	row.costHint:SetPoint("TOPLEFT", row.costText, "BOTTOMLEFT", 0, -2)
	row.costHint:SetPoint("RIGHT", row.costText, "RIGHT")
	row.costHint:SetJustifyH("LEFT")

	row.costHitBox = CreateFrame("Frame", nil, row)
	row.costHitBox:SetPoint("TOPLEFT", row, "TOPLEFT", SELECT_WIDTH + ORDER_WIDTH, 0)
	row.costHitBox:SetSize(COST_WIDTH, ROW_HEIGHT)
	row.costHitBox:EnableMouse(true)
	row.costHitBox:SetScript("OnEnter", function()
		Pane:ShowCostTooltip(row)
	end)
	row.costHitBox:SetScript("OnLeave", GameTooltip_Hide)
	row.costHitBox:SetScript("OnMouseUp", function()
		Pane:ViewOrder(row.order)
	end)

	row.rewardText = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	row.rewardText:SetPoint("TOPLEFT", row, "TOPLEFT", SELECT_WIDTH + ORDER_WIDTH + COST_WIDTH + 8, -8)
	row.rewardText:SetPoint("RIGHT", row, "LEFT", SELECT_WIDTH + ORDER_WIDTH + COST_WIDTH + REWARD_WIDTH - 8, 0)
	row.rewardText:SetJustifyH("LEFT")

	row.rewardValue = row:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	row.rewardValue:SetPoint("TOPLEFT", row.rewardText, "BOTTOMLEFT", 0, -2)
	row.rewardValue:SetPoint("RIGHT", row.rewardText, "RIGHT")
	row.rewardValue:SetJustifyH("LEFT")
	row.rewardValue:Hide()

	row.rewardIcons = {}

	row.rewardHitBox = CreateFrame("Frame", nil, row)
	row.rewardHitBox:SetPoint("TOPLEFT", row, "TOPLEFT", SELECT_WIDTH + ORDER_WIDTH + COST_WIDTH, 0)
	row.rewardHitBox:SetSize(REWARD_WIDTH, ROW_HEIGHT)
	row.rewardHitBox:EnableMouse(true)
	row.rewardHitBox:SetScript("OnEnter", function()
		Pane:ShowRewardTooltip(row)
	end)
	row.rewardHitBox:SetScript("OnLeave", GameTooltip_Hide)
	row.rewardHitBox:SetScript("OnMouseUp", function()
		Pane:ViewOrder(row.order)
	end)

	row.profitText = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	row.profitText:SetPoint("TOPLEFT", row, "TOPLEFT", SELECT_WIDTH + ORDER_WIDTH + COST_WIDTH + REWARD_WIDTH + 8, -10)
	row.profitText:SetPoint("RIGHT", row, "LEFT", SELECT_WIDTH + ORDER_WIDTH + COST_WIDTH + REWARD_WIDTH + PROFIT_WIDTH - 6, 0)
	row.profitText:SetJustifyH("LEFT")

	row.profitHitBox = CreateFrame("Frame", nil, row)
	row.profitHitBox:SetPoint("TOPLEFT", row, "TOPLEFT", SELECT_WIDTH + ORDER_WIDTH + COST_WIDTH + REWARD_WIDTH, 0)
	row.profitHitBox:SetSize(PROFIT_WIDTH, ROW_HEIGHT)
	row.profitHitBox:EnableMouse(true)
	row.profitHitBox:SetScript("OnEnter", function()
		Pane:ShowProfitTooltip(row)
	end)
	row.profitHitBox:SetScript("OnLeave", GameTooltip_Hide)
	row.profitHitBox:SetScript("OnMouseUp", function()
		Pane:ViewOrder(row.order)
	end)

	row.timeLeft = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	row.timeLeft:SetPoint("TOPLEFT", row, "TOPLEFT", SELECT_WIDTH + ORDER_WIDTH + COST_WIDTH + REWARD_WIDTH + PROFIT_WIDTH + 8, -10)
	row.timeLeft:SetPoint("RIGHT", row, "RIGHT", -8, 0)
	row.timeLeft:SetJustifyH("LEFT")

	row:SetScript("OnClick", function(self)
		Pane:ViewOrder(self.order)
	end)

	return row
end

function Pane:EnsureRowCount(count)
	while #self.rows < count do
		self:CreateRow(#self.rows + 1)
	end
end

function Pane:EnsureIconCount(row, bucketName, count)
	local bucket = row[bucketName]
	while #bucket < count do
		local icon = self:CreateIcon(row)
		icon.row = row
		bucket[#bucket + 1] = icon
	end
end

function Pane:UpdateHeaderArrow()
	if not self.sortArrow or not self.headers then
		return
	end

	local header = self.headers[self.sortKey]
	if not header then
		self.sortArrow:Hide()
		return
	end

	self.sortArrow:ClearAllPoints()
	self.sortArrow:SetParent(header)
	self.sortArrow:SetPoint("LEFT", header:GetFontString(), "RIGHT", 4, 0)
	local isAscending
	if self.sortKey == "reward" or self.sortKey == "profit" then
		isAscending = self.sortAscending
	else
		isAscending = not self.sortAscending
	end
	self.sortArrow:SetTexCoord(0, 1, isAscending and 1 or 0, isAscending and 0 or 1)
	self.sortArrow:Show()
end

function Pane:UpdateToolbar()
	local selectedCount = 0
	local queueApi = self:GetYayaQueueAPI()

	for _, order in ipairs(self.orders or EMPTY_LIST) do
		if self.selectedOrderIDs[order.orderID] then
			selectedCount = selectedCount + 1
		end
	end

	self.createListButton:SetText("YQ+")
	self.createListButton.tooltipTitle = queueApi and L.TOOLBAR_ADD_TO_YAYAQUEUE or L.TOOLBAR_YAYAQUEUE_UNAVAILABLE
	self.createListButton.tooltipText = queueApi and L.TOOLBAR_ADD_TO_YAYAQUEUE_TOOLTIP or L.TOOLBAR_INSTALL_YAYAQUEUE_TOOLTIP

	local autoQueueableCount = 0
	if selectedCount == 0 and queueApi then
		autoQueueableCount = self:GetAutoQueueablePatronOrderCount(queueApi)
	end
	if selectedCount == 0 then
		self.createListButton.tooltipText = queueApi and L.TOOLBAR_ADD_TO_YAYAQUEUE_TOOLTIP or L.TOOLBAR_INSTALL_AND_SELECT_TOOLTIP
	end
	self.createListButton:SetEnabled(queueApi ~= nil and (selectedCount > 0 or autoQueueableCount > 0))

	if self.selectAllButton then
		self.selectAllButton:SetText(L.TOOLBAR_SELECT_ALL_BUTTON)
		self.selectAllButton.tooltipTitle = L.TOOLBAR_SELECT_ALL_MENU
		self.selectAllButton.tooltipText = L.TOOLBAR_SELECT_ALL_TOOLTIP
		self.selectAllButton:SetEnabled(#(self.orders or EMPTY_LIST) > 0)
	end

	if self.filterButton then
		SetFallbackFilterButtonLabel(self.filterButton, L.TOOLBAR_FILTER_BUTTON)
		self.filterButton.tooltipTitle = L.TOOLBAR_FILTER_MENU
		self.filterButton.tooltipText = L.TOOLBAR_FILTER_TOOLTIP
		self.filterButton.recipeFilterLabel = self:GetRecipeFilterLabel()
		self.filterButton.concentrationFilterLabel = self:GetConcentrationFilterLabel()
	end

	self:UpdateFilterPanel()
	self:UpdateNextOrderButton()
end

function Pane:OrderHasAvailableMaterials(orderData)
	local _, hasAllMaterials = self:BuildOrderQueueReagents(orderData, false)
	return hasAllMaterials
end

function Pane:BuildYayaQueueCraftingReagents(orderData, materialPlan)
	local craftingReagents = {}

	for _, materialEntry in ipairs(GetMaterialPlanEntries(orderData, materialPlan)) do
		local slotData = materialEntry.slotData
		local option = materialEntry.option
		local dataSlotIndex = tonumber(slotData and slotData.dataSlotIndex)
		local itemID = tonumber(option and option.itemID)
		local currencyID = tonumber(option and option.currencyID)
		local quantity = math.max(0, tonumber(materialEntry.quantity) or 0)
		if slotData
			and slotData.dataSlotType == MUTABLE_SLOT_TYPE
			and not slotData.covered
			and dataSlotIndex and dataSlotIndex > 0
			and quantity > 0
			and ((itemID and itemID > 0) or (currencyID and currencyID > 0)) then
			craftingReagents[#craftingReagents + 1] = {
				dataSlotIndex = dataSlotIndex,
				reagent = {
					itemID = itemID and itemID > 0 and itemID or nil,
					currencyID = currencyID and currencyID > 0 and currencyID or nil,
				},
				quantity = quantity,
			}
		end
	end

	table.sort(craftingReagents, function(left, right)
		if left.dataSlotIndex ~= right.dataSlotIndex then
			return left.dataSlotIndex < right.dataSlotIndex
		end
		local leftItemID = left.reagent.itemID or left.reagent.currencyID or 0
		local rightItemID = right.reagent.itemID or right.reagent.currencyID or 0
		if leftItemID ~= rightItemID then
			return leftItemID < rightItemID
		end
		return left.quantity < right.quantity
	end)

	return craftingReagents
end

function Pane:BuildYayaQueueContext(orderData, skipDontBuyItems)
	if not (orderData and orderData.recipeInfo and orderData.recipeInfo.recipeID) then
		return nil, "missing recipe info"
	end

	local recipeInfo = orderData.recipeInfo
	local applyConcentration = DoesOrderNeedConcentration(orderData)
	local automaticMaterialPlan = orderData.lowestMaterialPlan or orderData.materialPlan
	return {
		recipeID = recipeInfo.recipeID,
		recipeName = (orderData.product and orderData.product.plainLabel) or recipeInfo.name or ("Recipe " .. recipeInfo.recipeID),
		outputItemID = orderData.product and orderData.product.itemID or nil,
		outputPerCraft = 1,
		mode = "crafts",
		reagents = self:BuildOrderQueueReagents(orderData, skipDontBuyItems, automaticMaterialPlan),
		craftingReagents = self:BuildYayaQueueCraftingReagents(orderData, automaticMaterialPlan),
		orderID = orderData.orderID,
		professionID = orderData.professionID or self.visibleProfession or self:GetCurrentProfessionID(),
		queueKind = "patron",
		isEnchantingRecipe = recipeInfo.isEnchantingRecipe == true,
		applyConcentration = applyConcentration,
		concentrationCost = applyConcentration and tonumber(orderData.concentration.currentCost) or nil,
		concentrationCurrencyID = applyConcentration and tonumber(orderData.concentration.currencyID) or nil,
		isRecraft = orderData.isRecraft == true,
		profitValue = tonumber(orderData.profitValue) or nil,
		profitKnown = orderData.profitKnown == true,
	}, nil
end

function Pane:AddOrderToYayaQueue(orderData, skipDontBuyItems)
	local queueApi = self:GetYayaQueueAPI()
	if not queueApi then
		return false, "queue unavailable"
	end

	if not self:HasEnoughConcentrationForOrder(orderData, queueApi) then
		return false, L.MSG_INSUFFICIENT_CONCENTRATION
	end

	local context, errorMessage = self:BuildYayaQueueContext(orderData, skipDontBuyItems)
	if not context then
		return false, errorMessage
	end

	return queueApi.AddRecipe(context, 1)
end

function Pane:HasEnoughConcentrationForOrder(orderData, queueApi)
	local concentration = orderData and orderData.concentration
	local required = tonumber(concentration and concentration.currentCost) or 0
	if required <= 0 then
		return true
	end

	local currencyID = tonumber(concentration and concentration.currencyID)
	if not currencyID then
		return false
	end

	local available = GetCurrencyQuantity(currencyID)
	local professionID = tonumber(orderData.professionID) or self.visibleProfession or self:GetCurrentProfessionID()
	local reserved = 0
	if queueApi and type(queueApi.GetQueuedConcentrationReservation) == "function" then
		reserved = math.max(0, tonumber(queueApi.GetQueuedConcentrationReservation(professionID, currencyID)) or 0)
	end

	return available - reserved >= required
end

-- La mise en file automatique n'engage que du rang 1 (lowestMaterialPlan). Si la
-- qualite exigee par la commande n'est pas atteignable avec ce plan, la mettre en
-- file produirait un craft incapable de la remplir : on la laisse de cote plutot
-- que de substituer du rang 2.
function Pane:CanAutoQueueAtRankOne(orderData)
	local requirement = orderData and orderData.qualityRequirement
	if not requirement or requirement.showInList == false then
		return true
	end
	if requirement.state == "none" then
		return false
	end
	return requirement.lowestPlan ~= nil and requirement.reachablePlan == requirement.lowestPlan
end

function Pane:ShouldAutoQueuePatronOrder(orderData, queueApi)
	return orderData
		and orderData.orderID
		and not orderData.isRecraft
		and orderData.isKnown
		and orderData.profitKnown
		and (orderData.profitValue or 0) > 0
		and orderData.recipeInfo
		and orderData.recipeInfo.recipeID
		and self:CanAutoQueueAtRankOne(orderData)
		and self:HasEnoughConcentrationForOrder(orderData, queueApi or self:GetYayaQueueAPI())
end

function Pane:IsAutoQueueablePatronOrder(orderData, queueApi, bucket)
	if not self:ShouldAutoQueuePatronOrder(orderData, queueApi) then
		return false
	end

	if type(queueApi.HasPatronOrder) == "function" then
		if queueApi.HasPatronOrder(orderData.orderID) then
			return false
		end
		if bucket then
			bucket[orderData.orderID] = nil
		end
		return true
	end

	return not (bucket and bucket[orderData.orderID])
end

function Pane:GetAutoQueueSessionBucket(professionID, sessionKey)
	professionID = professionID or self.visibleProfession or self:GetCurrentProfessionID()
	if not professionID then
		return nil
	end

	self.autoQueuedOrderIDsBySession = self.autoQueuedOrderIDsBySession or {}
	sessionKey = ("%s:%s"):format(tostring(sessionKey or self.visibleSessionId or 0), tostring(professionID))
	local bucket = self.autoQueuedOrderIDsBySession[sessionKey]
	if not bucket then
		bucket = {}
		self.autoQueuedOrderIDsBySession[sessionKey] = bucket
	end

	return bucket
end

function Pane:MaybeAutoQueuePatronOrders()
	local queueApi = self:GetYayaQueueAPI()
	if not queueApi then
		return
	end

	local bucket = self:GetAutoQueueSessionBucket()
	if not bucket then
		return
	end

	for _, order in ipairs(self.allOrders or EMPTY_LIST) do
		if self:IsAutoQueueablePatronOrder(order, queueApi, bucket) then
			local ok = self:AddOrderToYayaQueue(order, true)
			if ok then
				bucket[order.orderID] = true
			end
		end
	end
end

function Pane:GetAutoQueueablePatronOrderCount(queueApi)
	queueApi = queueApi or self:GetYayaQueueAPI()
	if not queueApi then
		return 0
	end

	local bucket = self:GetAutoQueueSessionBucket()
	if not bucket then
		return 0
	end

	local count = 0
	for _, order in ipairs(self.allOrders or EMPTY_LIST) do
		if self:IsAutoQueueablePatronOrder(order, queueApi, bucket) then
			count = count + 1
		end
	end

	return count
end

function Pane:QueueAutoQueueablePatronOrders(queueApi)
	queueApi = queueApi or self:GetYayaQueueAPI()
	if not queueApi then
		return 0, 0, "queue unavailable"
	end

	local bucket = self:GetAutoQueueSessionBucket()
	if not bucket then
		return 0, 0, "profession unavailable"
	end

	local candidateCount = 0
	local addedCount = 0
	local firstError
	for _, order in ipairs(self.allOrders or EMPTY_LIST) do
		if self:IsAutoQueueablePatronOrder(order, queueApi, bucket) then
			candidateCount = candidateCount + 1
			local ok, message = self:AddOrderToYayaQueue(order, true)
			if ok then
				bucket[order.orderID] = true
				addedCount = addedCount + 1
			elseif not firstError then
				firstError = message or "missing recipe info"
			end
		end
	end

	return candidateCount, addedCount, firstError
end

function Pane:IsProfessionPageVisible(page)
	if not page then
		return false
	end

	if type(page.IsVisible) == "function" then
		local ok, visible = Util.SafeCall(page.IsVisible, page)
		if ok and visible ~= nil then
			return visible == true
		end
	end

	return type(page.IsShown) == "function" and page:IsShown()
end

function Pane:SelectProfessionTab(tabID, page)
	if self:IsProfessionPageVisible(page) then
		ns.Debug("ui", "tab already-visible tab=%s", tostring(tabID))
		return true
	end

	if tabID == ((ProfessionsFrame and ProfessionsFrame.craftingOrdersTabID) or 3) then
		local canOpen = self:CanOpenPatronOrders()
		if not canOpen or (ProfessionsFrame and ProfessionsFrame.isCraftingOrdersTabEnabled == false) then
			ns.Debug(
				"ui",
				"tab blocked tab=%s canOpen=%s enabled=%s",
				tostring(tabID),
				tostring(canOpen),
				tostring(ProfessionsFrame and ProfessionsFrame.isCraftingOrdersTabEnabled)
			)
			return false
		end
	end

	if not (ProfessionsFrame and type(ProfessionsFrame.GetTabButton) == "function") then
		return false
	end

	-- Blizzard's SetTab expects this private filter snapshot to exist when
	-- switching between the recipes and crafting-orders pages. During the
	-- initial profession load it can still be nil; wait for the next retry
	-- instead of entering Blizzard_ProfessionsFrame:SetTab too early.
	if ProfessionsFrame.changingTabs or type(ProfessionsFrame.recipesFilters) ~= "table" then
		ns.Debug(
			"ui",
			"tab not-ready tab=%s recipesFilters=%s changingTabs=%s",
			tostring(tabID),
			tostring(type(ProfessionsFrame.recipesFilters)),
			tostring(ProfessionsFrame.changingTabs)
		)
		return false
	end

	local ok, tabButton = Util.SafeCall(ProfessionsFrame.GetTabButton, ProfessionsFrame, tabID)
	if ok and tabButton and type(tabButton.Click) == "function" then
		local enabled = true
		if type(tabButton.IsEnabled) == "function" then
			local enabledOK, enabledValue = Util.SafeCall(tabButton.IsEnabled, tabButton)
			enabled = enabledOK and enabledValue == true
		end
		ns.Debug("ui", "tab click tab=%s button=%s enabled=%s", tostring(tabID), tostring(tabButton), tostring(enabled))
		local clicked = Util.SafeCall(tabButton.Click, tabButton)
		ns.Debug(
			"ui",
			"tab click-result tab=%s ok=%s page-visible=%s",
			tostring(tabID),
			tostring(clicked == true),
			tostring(self:IsProfessionPageVisible(page))
		)
		return clicked == true
	end

	ns.Debug("ui", "tab unavailable tab=%s get-button-ok=%s", tostring(tabID), tostring(ok))
	return false
end

function Pane:SelectPatronOrderType(ordersPage)
	if not ordersPage then
		return false
	end
	if not self:CanOpenPatronOrders() then
		return false
	end

	if type(ordersPage.SetCraftingOrderType) == "function" then
		local ok = Util.SafeCall(ordersPage.SetCraftingOrderType, ordersPage, ns.ORDER_TYPE_NPC)
		ns.Debug(
			"ui",
			"order-type set requested=%s ok=%s current=%s",
			tostring(ns.ORDER_TYPE_NPC),
			tostring(ok),
			tostring(self:GetCurrentOrderType())
		)
		return ok == true
	end

	for _, buttonName in ipairs({ "NpcOrdersButton", "PatronOrdersButton" }) do
		local button = ordersPage[buttonName]
		if button and type(button.Click) == "function" then
			local ok = Util.SafeCall(button.Click, button)
			ns.Debug("ui", "order-type button=%s ok=%s current=%s", buttonName, tostring(ok), tostring(self:GetCurrentOrderType()))
			return ok == true
		end
	end

	return false
end

function Pane:IsNearProfessionFocus(profession)
	if not (C_TradeSkillUI and type(C_TradeSkillUI.IsNearProfessionSpellFocus) == "function") then
		return true
	end

	local ok, nearFocus = Util.SafeCall(C_TradeSkillUI.IsNearProfessionSpellFocus, profession)
	return ok and nearFocus == true
end

function Pane:GetFirstRecipeForRestore()
	if not (C_TradeSkillUI and type(C_TradeSkillUI.GetAllRecipeIDs) == "function") then
		return nil, false
	end

	local ok, recipeIDs = Util.SafeCall(C_TradeSkillUI.GetAllRecipeIDs)
	if not ok or type(recipeIDs) ~= "table" then
		return nil, false
	end

	local firstRecipeID
	local hasRecipeData = false
	for _, recipeID in ipairs(recipeIDs) do
		local info
		if type(C_TradeSkillUI.GetRecipeInfo) == "function" then
			local infoOK
			infoOK, info = Util.SafeCall(C_TradeSkillUI.GetRecipeInfo, recipeID)
			if not infoOK then
				info = nil
			end
		end

		if type(info) == "table" and info.learned ~= false then
			hasRecipeData = true
			firstRecipeID = firstRecipeID or recipeID
			if type(C_TradeSkillUI.IsRecipeFavorite) == "function" then
				local favoriteOK, isFavorite = Util.SafeCall(C_TradeSkillUI.IsRecipeFavorite, recipeID)
				if favoriteOK and isFavorite == true then
					return recipeID, true
				end
			end
		elseif type(info) == "table" then
			hasRecipeData = true
		end
	end

	return firstRecipeID, #recipeIDs == 0 or hasRecipeData
end

function Pane:SchedulePatronAutoScanStep(flow, delay)
	if self.autoScanFlow ~= flow or flow.timerQueued then
		return
	end

	flow.timerQueued = true
	C_Timer.After(delay or 0, function()
		flow.timerQueued = nil
		if Pane.autoScanFlow == flow then
			Pane:RunPatronAutoScanStep(flow)
		end
	end)
end

function Pane:HasCrafterOrderRequestToken(profession)
	if self.craftingOrdersCanRequest == nil
		and self.craftingOrdersCanRequestProfession == nil
	then
		return true, "bootstrap"
	end
	if self.craftingOrdersCanRequest ~= true then
		return false, "consumed"
	end
	if tonumber(self.craftingOrdersCanRequestProfession) ~= tonumber(profession) then
		-- CRAFTINGORDERS_CAN_REQUEST est un deblocage de throttle cote serveur,
		-- pas un droit attache a un metier. L'etiquette posee a la reception est
		-- deduite de GetProfessionSnapshot, qui renvoie encore le metier
		-- precedent juste apres une ouverture : refuser sur cette base bloquait
		-- le flux headless jusqu'au repli visible. On accepte donc le token en
		-- signalant la derive.
		return true, "profession-drift"
	end
	return true, "ready"
end

function Pane:ResetCrafterOrderRequestToken(reason)
	if self.craftingOrdersCanRequest == nil and self.craftingOrdersCanRequestProfession == nil then
		return false
	end
	ns.Debug(
		"auto-scan",
		"reset can-request token reason=%s previous=%s/%s",
		tostring(reason),
		tostring(self.craftingOrdersCanRequest),
		tostring(self.craftingOrdersCanRequestProfession)
	)
	self.craftingOrdersCanRequest = nil
	self.craftingOrdersCanRequestProfession = nil
	return true
end

function Pane:ConsumeCrafterOrderRequestToken(profession)
	self.craftingOrdersCanRequest = false
	self.craftingOrdersCanRequestProfession = tonumber(profession)
end

function Pane:RetryPatronAutoScanFlowReadiness(flow, reason)
	if self.autoScanFlow ~= flow then
		return false
	end

	flow.readinessAttempts = (flow.readinessAttempts or 0) + 1
	if flow.readinessAttempts <= REQUEST_READINESS_RETRY_LIMIT then
		ns.Debug(
			"auto-scan",
			"flow wait profession=%s reason=%s attempt=%s/%s",
			tostring(flow.profession),
			tostring(reason),
			tostring(flow.readinessAttempts),
			tostring(REQUEST_READINESS_RETRY_LIMIT)
		)
		self:SchedulePatronAutoScanStep(flow, REQUEST_READINESS_RETRY_DELAY)
		return true
	end

	ns.Debug("auto-scan", "flow readiness exhausted profession=%s reason=%s", tostring(flow.profession), tostring(reason))
	self.autoScanFlow = nil
	self.autoScanOpeningRequested = true
	self:SchedulePatronAutoScanStartRetry(reason or "flow-readiness")
	return false
end

function Pane:FallbackToVisiblePatronAutoScan(flow, reason)
	if self.autoScanFlow ~= flow then
		return
	end

	flow.mode = "visible"
	flow.stage = "open-orders"
	flow.requesting = nil
	flow.restoreAt = nil
	flow.visibleFallbackStartedAt = GetTime()
	flow.visibleFallbackDeadline = flow.visibleFallbackStartedAt + REQUEST_TIMEOUT
	flow.visibleFallbackWaitLogged = nil
	ns.Debug(
		"auto-scan",
		"fallback-visible profession=%s reason=%s attempts=%s",
		tostring(flow.profession),
		tostring(reason),
		tostring(flow.requestAttempts or 0)
	)
	self:SchedulePatronAutoScanStep(flow, 0)
end

function Pane:DispatchProfessionOpenQueueTasks(flow, source)
	if self.autoScanFlow ~= flow or flow.postOpenTasksDispatched then
		return nil
	end

	flow.postOpenTasksDispatched = true
	local queueApi = self:GetYayaQueueAPI()
	local result = {
		favoriteOK = false,
		favoriteMessage = "queue-unavailable",
		firstCraftOK = false,
		firstCraftMessage = "queue-unavailable",
	}
	if queueApi and type(queueApi.QueueFavoriteConcentration) == "function" then
		result.favoriteOK, result.favoriteMessage = queueApi.QueueFavoriteConcentration(flow.profession)
	end
	if queueApi and type(queueApi.QueueFirstCraftsAfterProfessionOpen) == "function" then
		result.firstCraftOK, result.firstCraftMessage = queueApi.QueueFirstCraftsAfterProfessionOpen()
	end
	ns.Debug(
		"auto-scan",
		"post-open profession=%s source=%s favorite=%s favoriteMessage=%s firstCraft=%s firstCraftMessage=%s",
		tostring(flow.profession),
		tostring(source or flow.mode or "?"),
		tostring(result.favoriteOK),
		tostring(result.favoriteMessage),
		tostring(result.firstCraftOK),
		tostring(result.firstCraftMessage)
	)
	return result
end

function Pane:CompleteHeadlessPatronAutoScan(flow, stats)
	if self.autoScanFlow ~= flow then
		return
	end

	self.autoScanCompletedByProfession[flow.profession] = true
	self:DispatchProfessionOpenQueueTasks(flow, "headless")
	ns.Debug(
		"headless",
		"complete profession=%s raw=%s prepared=%s candidates=%s added=%s skipped=%s failed=%s",
		tostring(flow.profession),
		tostring(stats and stats.rawCount or 0),
		tostring(stats and stats.preparedCount or 0),
		tostring(stats and stats.candidateCount or 0),
		tostring(stats and stats.addedCount or 0),
		tostring(stats and stats.skippedCount or 0),
		tostring(stats and stats.failedCount or 0)
	)
	self.autoScanFlow = nil
	if self.autoScanOpeningRequested then
		self.autoScanStartAttempts = 0
		self:SchedulePatronAutoScanStartRetry("opening-after-headless")
	end
end

function Pane:ProcessHeadlessPatronOrders(flow)
	local rawOrders = self:GetVisibleRawOrders()
	local stats = {
		rawCount = #rawOrders,
		preparedCount = 0,
		candidateCount = 0,
		addedCount = 0,
		skippedCount = 0,
		failedCount = 0,
		deferredCount = 0,
	}

	if #rawOrders == 0 then
		flow.emptyAttempts = (flow.emptyAttempts or 0) + 1
		if flow.emptyAttempts < self.retryConfig.emptySyncLimit then
			return "retry", "empty-orders", stats
		end
		return "fallback", "empty-orders", stats
	end

	local preparedOrders = {}
	for _, rawOrder in ipairs(rawOrders) do
		local ok, orderData = pcall(PrepareOrder, rawOrder, flow.profession)
		if ok and orderData then
			preparedOrders[#preparedOrders + 1] = orderData
			stats.preparedCount = stats.preparedCount + 1
		else
			stats.deferredCount = stats.deferredCount + 1
		end
	end

	if stats.deferredCount > 0 then
		flow.prepareAttempts = (flow.prepareAttempts or 0) + 1
		if flow.prepareAttempts < self.retryConfig.headlessRequestLimit then
			return "retry", "recipe-data", stats
		end
		return "fallback", "recipe-data", stats
	end

	local queueApi = self:GetYayaQueueAPI()
	if not queueApi then
		return "fallback", "queue-unavailable", stats
	end

	local bucket = self:GetAutoQueueSessionBucket(flow.profession, flow.sessionKey)
	if not bucket then
		return "fallback", "session-unavailable", stats
	end

	local availableOrderIDs = {}
	for _, rawOrder in ipairs(rawOrders) do
		local orderID = tonumber(rawOrder.orderID) or 0
		if orderID > 0 then
			availableOrderIDs[orderID] = true
		end
	end
	if type(queueApi.SyncPatronOrders) == "function" then
		queueApi.SyncPatronOrders(availableOrderIDs, flow.profession)
	end

	for _, orderData in ipairs(preparedOrders) do
		if self:IsAutoQueueablePatronOrder(orderData, queueApi, bucket) then
			stats.candidateCount = stats.candidateCount + 1
			local ok = self:AddOrderToYayaQueue(orderData, true)
			if ok then
				bucket[orderData.orderID] = true
				stats.addedCount = stats.addedCount + 1
			else
				stats.failedCount = stats.failedCount + 1
			end
		else
			stats.skippedCount = stats.skippedCount + 1
		end
	end

	if stats.failedCount > 0 then
		return "fallback", "queue-add-failed", stats
	end

	return "success", nil, stats
end

function Pane:RequestHeadlessPatronOrders(flow)
	if self.autoScanFlow ~= flow or flow.requesting then
		return
	end

	local snapshot = self:GetProfessionSnapshot()
	if snapshot.selected ~= flow.profession then
		if not snapshot.selected then
			self:RetryPatronAutoScanFlowReadiness(flow, "profession-not-ready")
		else
			ns.Debug(
				"headless",
				"cancel profession-changed flow=%s current=%s child=%s base=%s orders=%s",
				tostring(flow.profession),
				tostring(snapshot.selected),
				tostring(snapshot.child),
				tostring(snapshot.base),
				tostring(snapshot.ordersPage)
			)
			self.autoScanFlow = nil
			self.autoScanOpeningRequested = true
			self.autoScanStartAttempts = 0
			self:SchedulePatronAutoScanStartRetry("profession-changed")
		end
		return
	end

	if not self:IsNearProfessionFocus(flow.profession) then
		self:RetryPatronAutoScanFlowReadiness(flow, "focus-unavailable")
		return
	end
	flow.readinessAttempts = 0

	if type(C_CraftingOrders) ~= "table"
		or type(C_CraftingOrders.RequestCrafterOrders) ~= "function"
	then
		self:FallbackToVisiblePatronAutoScan(flow, "request-unavailable")
		return
	end

	local canRequest, canRequestReason = self:HasCrafterOrderRequestToken(flow.profession)
	local requestTimeout = self.retryConfig.headlessFallbackTimeout
	if not canRequest then
		flow.canRequestWaitStartedAt = flow.canRequestWaitStartedAt or GetTime()
		flow.canRequestFallbackAt = flow.canRequestFallbackAt
			or (flow.canRequestWaitStartedAt + self.retryConfig.headlessFallbackTimeout)
		local waitElapsed = GetTime() - flow.canRequestWaitStartedAt
		local fallbackIn = flow.canRequestFallbackAt - GetTime()
		-- Recuperation repetable : une seule tentative laissait le flux
		-- attendre le repli visible des que cette tentative echouait.
		if waitElapsed >= self.retryConfig.canRequestRecoveryDelay
			and GetTime() >= (flow.canRequestRecoveryNextAt or 0)
		then
			-- Recul progressif : 1 s, 2 s, 4 s... plutot qu'une tentative par
			-- seconde, pour laisser le throttle serveur se liberer de lui-meme.
			flow.canRequestRecoveryAttempts = (flow.canRequestRecoveryAttempts or 0) + 1
			flow.canRequestRecoveryNextAt = GetTime()
				+ self.retryConfig.canRequestRecoveryDelay
					* (2 ^ (flow.canRequestRecoveryAttempts - 1))
			canRequest = true
			canRequestReason = "timed-recovery"
			flow.canRequestForcedRequest = true
			requestTimeout = math.max(0.1, fallbackIn)
			ns.Debug(
				"headless",
				"recover can-request profession=%s waited=%.2f timeoutIn=%.2f token=%s/%s",
				tostring(flow.profession),
				waitElapsed,
				requestTimeout,
				tostring(self.craftingOrdersCanRequest),
				tostring(self.craftingOrdersCanRequestProfession)
			)
		elseif fallbackIn > 0 then
			if not flow.canRequestWaitLogged then
				flow.canRequestWaitLogged = true
				ns.Debug(
					"headless",
					"wait can-request profession=%s reason=%s token=%s/%s",
					tostring(flow.profession),
					tostring(canRequestReason),
					tostring(self.craftingOrdersCanRequest),
					tostring(self.craftingOrdersCanRequestProfession)
				)
			end
			self:SchedulePatronAutoScanStep(flow, self.retryConfig.autoScanDelay)
			return
		else
			self:FallbackToVisiblePatronAutoScan(flow, "can-request-timeout")
			return
		end
	end
	if flow.canRequestFallbackAt then
		requestTimeout = math.max(0.1, flow.canRequestFallbackAt - GetTime())
	end
	flow.canRequestWaitLogged = nil

	-- Seul "ready" signifie que le serveur a effectivement accorde la requete.
	-- Une requete emise sans cette autorisation, bootstrap ou recuperation
	-- forcee, peut etre ignoree en silence : elle ne consomme donc pas le budget
	-- de requetes headless. Elle reste bornee par son propre timer de timeout et
	-- court-circuitee par la reemission sur CRAFTINGORDERS_CAN_REQUEST.
	local granted = canRequestReason == "ready"
	flow.canRequestForcedRequest = nil
	if granted then
		flow.requestAttempts = (flow.requestAttempts or 0) + 1
		if flow.requestAttempts > self.retryConfig.headlessRequestLimit then
			self:FallbackToVisiblePatronAutoScan(flow, "request-retries-exhausted")
			return
		end
	end
	flow.requestGranted = granted
	self.headlessRequestSerial = (self.headlessRequestSerial or 0) + 1
	local requestID = self.headlessRequestSerial
	flow.requestID = requestID
	flow.requesting = true
	ns.Debug(
		"headless",
		"request start id=%s attempt=%s profession=%s child=%s base=%s orders=%s tokenReason=%s tokenProfession=%s",
		tostring(requestID),
		tostring(flow.requestAttempts),
		tostring(flow.profession),
		tostring(snapshot.child),
		tostring(snapshot.base),
		tostring(snapshot.ordersPage),
		tostring(canRequestReason),
		tostring(self.craftingOrdersCanRequestProfession)
	)

	C_Timer.After(requestTimeout, function()
		if Pane and Pane.autoScanFlow == flow and flow.requestID == requestID and flow.requesting then
			flow.requesting = nil
			Pane:FallbackToVisiblePatronAutoScan(flow, "request-timeout")
		end
	end)

	self:ConsumeCrafterOrderRequestToken(flow.profession)
	local request = {
		profession = flow.profession,
		orderType = ns.ORDER_TYPE_NPC,
		forCrafter = true,
		offset = 0,
		searchFavorites = false,
		initialNonPublicSearch = true,
		primarySort = { sortType = 0, reversed = false },
		secondarySort = { sortType = 0, reversed = false },
	}
	request.callback = function(result, orderType, _, expectMoreRows, responseOffset)
			if Pane.autoScanFlow ~= flow or flow.requestID ~= requestID or not flow.requesting then
				ns.Debug("headless", "ignore stale callback id=%s request-active=%s", tostring(requestID), tostring(flow.requesting == true))
				return
			end

			local currentProfession = Pane:GetCurrentProfessionID()
			local requestSucceeded = result == 0
				and (orderType == nil or orderType == ns.ORDER_TYPE_NPC)
			local rawCount = 0
			if type(C_CraftingOrders) == "table"
				and type(C_CraftingOrders.GetCrafterOrders) == "function"
			then
				local rawOK, callbackOrders = pcall(C_CraftingOrders.GetCrafterOrders)
				if rawOK and type(callbackOrders) == "table" then
					rawCount = #callbackOrders
				end
			end
			ns.Debug(
				"headless",
				"request callback id=%s result=%s type=%s current=%s success=%s raw=%s more=%s offset=%s",
				tostring(requestID),
				tostring(result),
				tostring(orderType),
				tostring(currentProfession),
				tostring(requestSucceeded),
					tostring(rawCount),
					tostring(expectMoreRows),
					tostring(responseOffset)
			)
			if requestSucceeded and expectMoreRows then
				local currentOffset = tonumber(responseOffset) or tonumber(request.offset) or 0
				if rawCount <= currentOffset then
					ns.Debug("headless", "pagination stalled id=%s offset=%s raw=%s", tostring(requestID), tostring(currentOffset), tostring(rawCount))
					Pane:FallbackToVisiblePatronAutoScan(flow, "pagination-stalled")
					return
				end
				request.offset = rawCount
				ns.Debug("headless", "request next-page id=%s offset=%s", tostring(requestID), tostring(request.offset))
				local nextOK, nextError = pcall(C_CraftingOrders.RequestCrafterOrders, request)
				if not nextOK then
					ns.Debug("headless", "next-page error id=%s error=%s", tostring(requestID), tostring(nextError))
					Pane:FallbackToVisiblePatronAutoScan(flow, "pagination-error")
				end
				return
			end
			flow.requesting = nil

			if not requestSucceeded then
				if flow.requestAttempts < Pane.retryConfig.headlessRequestLimit then
					ns.Debug(
						"headless",
						"request retry result=%s attempt=%s/%s profession=%s",
						tostring(result),
						tostring(flow.requestAttempts),
						tostring(Pane.retryConfig.headlessRequestLimit),
						tostring(flow.profession)
					)
					Pane:SchedulePatronAutoScanStep(flow, Pane.retryConfig.headlessRequestDelay)
				else
					Pane:FallbackToVisiblePatronAutoScan(flow, "request-failed")
				end
				return
			end
			if currentProfession ~= flow.profession then
				Pane.autoScanFlow = nil
				Pane.autoScanOpeningRequested = true
				Pane.autoScanStartAttempts = 0
				Pane:SchedulePatronAutoScanStartRetry("profession-changed-callback")
				return
			end

			local processOK, status, reason, stats = pcall(Pane.ProcessHeadlessPatronOrders, Pane, flow)
			if not processOK then
				ns.Debug("headless", "process error=%s", tostring(status))
				Pane:FallbackToVisiblePatronAutoScan(flow, "process-error")
				return
			end
			ns.Debug(
				"headless",
				"process status=%s reason=%s raw=%s prepared=%s deferred=%s candidates=%s added=%s skipped=%s failed=%s",
				tostring(status),
				tostring(reason),
				tostring(stats and stats.rawCount),
				tostring(stats and stats.preparedCount),
				tostring(stats and stats.deferredCount),
				tostring(stats and stats.candidateCount),
				tostring(stats and stats.addedCount),
				tostring(stats and stats.skippedCount),
				tostring(stats and stats.failedCount)
			)
			if status == "success" then
				Pane:CompleteHeadlessPatronAutoScan(flow, stats)
			elseif status == "retry" then
				Pane:SchedulePatronAutoScanStep(flow, Pane.retryConfig.headlessRequestDelay)
			else
				Pane:FallbackToVisiblePatronAutoScan(flow, reason or "headless-failed")
			end
		end
	local requestOK, requestError = pcall(C_CraftingOrders.RequestCrafterOrders, request)
	if not requestOK then
		flow.requesting = nil
		ns.Debug("headless", "request error=%s", tostring(requestError))
		if canRequestReason == "timed-recovery"
			and flow.canRequestFallbackAt
			and GetTime() < flow.canRequestFallbackAt
		then
			self:SchedulePatronAutoScanStep(flow, self.retryConfig.autoScanDelay)
			return
		end
		self:FallbackToVisiblePatronAutoScan(flow, "request-error")
	end
end

function Pane:RestoreAfterPatronAutoScan(flow)
	local visibleQueueProcessed = flow.visibleRequestSucceeded and flow.visibleQueueProcessed
	if flow.mode == "visible" and not visibleQueueProcessed then
		local deadline = flow.visibleFallbackDeadline or (GetTime() + REQUEST_TIMEOUT)
		flow.visibleFallbackDeadline = deadline
		if GetTime() < deadline then
			if not flow.visibleFallbackWaitLogged then
				flow.visibleFallbackWaitLogged = true
				ns.Debug(
					"auto-scan",
					"visible fallback waiting profession=%s request=%s queue=%s deadline=%s",
					tostring(flow.profession),
					tostring(flow.visibleRequestSucceeded),
					tostring(flow.visibleQueueProcessed),
					tostring(deadline)
				)
			end
			self:SchedulePatronAutoScanStep(flow, self.retryConfig.autoScanDelay)
			return
		end

		self:DispatchProfessionOpenQueueTasks(flow, "visible-timeout")
		ns.Debug(
			"auto-scan",
			"visible fallback timeout profession=%s request=%s queue=%s",
			tostring(flow.profession),
			tostring(flow.visibleRequestSucceeded),
			tostring(flow.visibleQueueProcessed)
		)
		self.autoScanFlow = nil
		if self.autoScanOpeningRequested then
			self.autoScanStartAttempts = 0
			self:SchedulePatronAutoScanStartRetry("opening-after-visible-timeout")
		end
		return
	end

	local craftingPage = ProfessionsFrame and ProfessionsFrame.CraftingPage
	if not self:IsProfessionPageVisible(craftingPage) then
		self:SelectProfessionTab((ProfessionsFrame and ProfessionsFrame.recipesTabID) or 1, craftingPage)
		self:SchedulePatronAutoScanStep(flow, self.retryConfig.autoScanDelay)
		return
	end

	local recipeID, recipeDataReady = self:GetFirstRecipeForRestore()
	if not recipeDataReady then
		self:SchedulePatronAutoScanStep(flow, self.retryConfig.autoScanDelay)
		return
	end

	if recipeID and type(C_TradeSkillUI.OpenRecipe) == "function" then
		Util.SafeCall(C_TradeSkillUI.OpenRecipe, recipeID)
		ns.Debug("auto-scan", "restored profession=%s recipe=%s", tostring(flow.profession), tostring(recipeID))
	else
		ns.Debug("auto-scan", "restored profession=%s without recipe", tostring(flow.profession))
	end

	self:DispatchProfessionOpenQueueTasks(flow, "visible")

	if flow.mode == "visible" and visibleQueueProcessed then
		self.autoScanCompletedByProfession[flow.profession] = true
		ns.Debug(
			"auto-scan",
			"visible fallback completed profession=%s request=%s queue=%s",
			tostring(flow.profession),
			tostring(flow.visibleRequestSucceeded),
			tostring(flow.visibleQueueProcessed)
		)
	else
		ns.Debug(
			"auto-scan",
			"visible fallback incomplete profession=%s request=%s queue=%s",
			tostring(flow.profession),
			tostring(flow.visibleRequestSucceeded),
			tostring(flow.visibleQueueProcessed)
		)
	end

	self.autoScanFlow = nil
	if self.autoScanOpeningRequested then
		self.autoScanStartAttempts = 0
		self:SchedulePatronAutoScanStartRetry("opening-after-visible")
	end
end

function Pane:RunPatronAutoScanStep(flow)
	local snapshot = self:GetProfessionSnapshot()
	if snapshot.selected ~= flow.profession then
		if not snapshot.selected then
			self:RetryPatronAutoScanFlowReadiness(flow, "profession-not-ready-step")
		else
			ns.Debug(
				"auto-scan",
				"cancel profession-changed flow=%s current=%s child=%s base=%s orders=%s",
				tostring(flow.profession),
				tostring(snapshot.selected),
				tostring(snapshot.child),
				tostring(snapshot.base),
				tostring(snapshot.ordersPage)
			)
			self.autoScanFlow = nil
			self.autoScanOpeningRequested = true
			self.autoScanStartAttempts = 0
			self:SchedulePatronAutoScanStartRetry("profession-changed-step")
		end
		return
	end

	if flow.mode == "headless" then
		self:RequestHeadlessPatronOrders(flow)
		return
	end

	if flow.stage == "restore" then
		self:RestoreAfterPatronAutoScan(flow)
		return
	end

	if not self:IsNearProfessionFocus(flow.profession) then
		self:RetryPatronAutoScanFlowReadiness(flow, "focus-unavailable-step")
		return
	end
	flow.readinessAttempts = 0

	if flow.restoreAt and GetTime() >= flow.restoreAt then
		flow.stage = "restore"
		ns.Debug("auto-scan", "restore after %ss profession=%s", tostring(self.retryConfig.autoScanDuration), tostring(flow.profession))
		self:SchedulePatronAutoScanStep(flow, 0)
		return
	end

	local ordersPage = ProfessionsFrame and ProfessionsFrame.OrdersPage
	if not self:IsProfessionPageVisible(ordersPage) then
		self:SelectProfessionTab((ProfessionsFrame and ProfessionsFrame.craftingOrdersTabID) or 3, ordersPage)
		self:SchedulePatronAutoScanStep(flow, self.retryConfig.autoScanDelay)
		return
	end

	if self:GetCurrentOrderType() ~= ns.ORDER_TYPE_NPC then
		self:SelectPatronOrderType(ordersPage)
		self:SchedulePatronAutoScanStep(flow, self.retryConfig.autoScanDelay)
		return
	end

	self:SetCustomPaneShown(true)
	flow.sessionInitialized = true
	flow.stage = "wait-orders"
	if not flow.restoreAt then
		flow.restoreAt = GetTime() + self.retryConfig.autoScanDuration
		ns.Debug("auto-scan", "opened profession=%s; restoring in %ss", tostring(flow.profession), tostring(self.retryConfig.autoScanDuration))
	end
	self:SchedulePatronAutoScanStep(flow, self.retryConfig.autoScanDelay)
end

function Pane:SchedulePatronAutoScanStartRetry(reason)
	if self.autoScanStartRetryQueued
		or (self.autoScanStartAttempts or 0) >= REQUEST_READINESS_RETRY_LIMIT
	then
		ns.Debug(
			"auto-scan",
			"start retry rejected reason=%s queued=%s attempts=%s/%s",
			tostring(reason),
			tostring(self.autoScanStartRetryQueued == true),
			tostring(self.autoScanStartAttempts or 0),
			tostring(REQUEST_READINESS_RETRY_LIMIT)
		)
		return false
	end

	self.autoScanStartAttempts = (self.autoScanStartAttempts or 0) + 1
	self.autoScanStartRetryQueued = true
	C_Timer.After(REQUEST_READINESS_RETRY_DELAY, function()
		if Pane then
			Pane.autoScanStartRetryQueued = nil
			local snapshot = Pane:GetProfessionSnapshot()
			ns.Debug(
				"auto-scan",
				"start retry fire reason=%s attempt=%s selected=%s child=%s base=%s orders=%s activeFlow=%s/%s",
				tostring(reason),
				tostring(Pane.autoScanStartAttempts or 0),
				tostring(snapshot.selected),
				tostring(snapshot.child),
				tostring(snapshot.base),
				tostring(snapshot.ordersPage),
				tostring(Pane.autoScanFlow and Pane.autoScanFlow.profession),
				tostring(Pane.autoScanFlow and Pane.autoScanFlow.sessionKey)
			)
			Pane:MaybeStartPatronAutoScan(reason or "profession-readiness")
		end
	end)
	return true
end

function Pane:MaybeStartPatronAutoScan(reason)
	local snapshot = self:GetProfessionSnapshot()
	local profession = snapshot.selected
	ns.Debug(
		"auto-scan",
		"evaluate reason=%s selected=%s child=%s base=%s orders=%s opening=%s/%s completed=%s attempts=%s retryQueued=%s canRequest=%s/%s flow=%s/%s/%s/%s",
		tostring(reason),
		tostring(profession),
		tostring(snapshot.child),
		tostring(snapshot.base),
		tostring(snapshot.ordersPage),
		tostring(self.autoScanOpeningRequested == true),
		tostring(self.autoScanOpeningProfession),
		tostring(profession and self.autoScanCompletedByProfession[profession] == true or false),
		tostring(self.autoScanStartAttempts or 0),
		tostring(self.autoScanStartRetryQueued == true),
		tostring(self.craftingOrdersCanRequest),
		tostring(self.craftingOrdersCanRequestProfession),
		tostring(self.autoScanFlow and self.autoScanFlow.profession),
		tostring(self.autoScanFlow and self.autoScanFlow.mode),
		tostring(self.autoScanFlow and self.autoScanFlow.stage),
		tostring(self.autoScanFlow and self.autoScanFlow.sessionKey)
	)
	if not profession then
		self:SchedulePatronAutoScanStartRetry("profession-readiness")
		ns.Debug(
			"auto-scan",
			"wait profession reason=%s attempts=%s child=%s base=%s orders=%s",
			tostring(reason),
			tostring(self.autoScanStartAttempts),
			tostring(snapshot.child),
			tostring(snapshot.base),
			tostring(snapshot.ordersPage)
		)
		return
	end

	if not self:IsNearProfessionFocus(profession) then
		self:SchedulePatronAutoScanStartRetry("focus-readiness")
		ns.Debug(
			"auto-scan",
			"wait focus profession=%s reason=%s attempt=%s/%s",
			tostring(profession),
			tostring(reason),
			tostring(self.autoScanStartAttempts or 0),
			tostring(REQUEST_READINESS_RETRY_LIMIT)
		)
		return
	end

	if self.autoScanCompletedByProfession[profession]
		and self.autoScanOpeningRequested
		and self.autoScanOpeningProfession == profession
	then
		ns.Debug("auto-scan", "wait completed profession still exposed profession=%s reason=%s", tostring(profession), tostring(reason))
		self:SchedulePatronAutoScanStartRetry("opening-profession-readiness")
		return
	end
	if self.autoScanOpeningProfession ~= profession then
		self.autoScanOpeningProfession = profession
		self.autoScanCompletedByProfession[profession] = nil
		self.autoScanStartAttempts = 0
		ns.Debug("auto-scan", "new profession opening profession=%s", tostring(profession))
	end
	if not profession or self.autoScanCompletedByProfession[profession] then
		ns.Debug("auto-scan", "skip already completed profession=%s reason=%s", tostring(profession), tostring(reason))
		return
	end

	local canOpen, definitive = self:CanOpenPatronOrders()
	if not canOpen then
		local retryScheduled = self:SchedulePatronAutoScanStartRetry("patron-tab-readiness")
		if definitive and not retryScheduled then
			self.autoScanCompletedByProfession[profession] = true
			self.autoScanOpeningRequested = false
			self.autoScanStartAttempts = 0
		end
		ns.Debug(
			"auto-scan",
			"wait patron-tab profession=%s definitive=%s retry=%s attempt=%s/%s",
			tostring(profession),
			tostring(definitive),
			tostring(retryScheduled),
			tostring(self.autoScanStartAttempts or 0),
			tostring(REQUEST_READINESS_RETRY_LIMIT)
		)
		return
	end

	if self.autoScanFlow then
		if self.autoScanFlow.profession == profession then
			if self.autoScanOpeningRequested then
				self:SchedulePatronAutoScanStartRetry("opening-flow-readiness")
			end
			return
		end
		ns.Debug(
			"auto-scan",
			"replace flow old=%s/%s/%s newProfession=%s reason=%s",
			tostring(self.autoScanFlow.profession),
			tostring(self.autoScanFlow.mode),
			tostring(self.autoScanFlow.sessionKey),
			tostring(profession),
			tostring(reason)
		)
		self.autoScanFlow = nil
	end

	self.autoScanStartAttempts = 0
	self.autoScanOpeningRequested = false
	-- Nouveau metier : l'etat du token decrit la requete du metier precedent et
	-- n'est plus pertinent. Sans cette remise a neutre, ce flux demarre en
	-- "consumed" alors que le premier metier de la session demarrait en
	-- "bootstrap", d'ou une attente puis une recuperation forcee.
	if self.lastAutoScanTokenProfession ~= profession then
		self.lastAutoScanTokenProfession = profession
		self:ResetCrafterOrderRequestToken("new-profession")
	end
	local rootShown = self.root and self.root:IsShown() == true
	self.autoScanSerial = (self.autoScanSerial or 0) + 1
	local flow = {
		profession = profession,
		mode = "headless",
		stage = "headless",
		sessionKey = "headless:" .. tostring(self.autoScanSerial),
		sessionInitialized = rootShown,
	}
	self.autoScanFlow = flow
	ns.Debug(
		"auto-scan",
		"start profession=%s reason=%s child=%s base=%s orders=%s mode=headless",
		tostring(profession),
		tostring(reason),
		tostring(snapshot.child),
		tostring(snapshot.base),
		tostring(snapshot.ordersPage)
	)
	self:SchedulePatronAutoScanStep(flow, 0)
end

function Pane:DoesOrderMatchSelectionMode(orderData, mode)
	if mode ~= "known" and mode ~= "profitable" and mode ~= "available" then
		mode = "all"
	end

	if mode == "known" then
		return not not (orderData and orderData.isKnown)
	elseif mode == "profitable" then
		return not not (orderData and orderData.profitKnown and (orderData.profitValue or 0) > 0)
	elseif mode == "available" then
		return self:OrderHasAvailableMaterials(orderData)
	end

	return orderData ~= nil
end

function Pane:SelectOrdersByMode(mode)
	local selection = {}

	for _, order in ipairs(self.orders or EMPTY_LIST) do
		if self:DoesOrderMatchSelectionMode(order, mode) then
			selection[order.orderID] = true
		end
	end

	self.selectedOrderIDs = selection
	self.selectedOrderIDsByProfession[GetProfessionSelectionKey(self.visibleProfession)] = selection
	if self.selectPanel then
		self.selectPanel:Hide()
	end
	self:RenderRows()
	self:UpdateToolbar()
end

function Pane:AddSelectedOrdersToYayaQueue()
	local queueApi = self:GetYayaQueueAPI()
	if not queueApi then
		ns.Print(L.MSG_YAYAQUEUE_UNAVAILABLE)
		return
	end

	local selectedCount = 0
	local addedCount = 0
	local firstError

	for _, order in ipairs(self.orders or EMPTY_LIST) do
		if self.selectedOrderIDs[order.orderID] then
			selectedCount = selectedCount + 1

			local ok, message = self:AddOrderToYayaQueue(order, true)
			if ok then
				addedCount = addedCount + 1
			elseif not firstError then
				firstError = message or "missing recipe info"
			end
		end
	end

	if selectedCount == 0 then
		local candidateCount, autoAddedCount, autoError = self:QueueAutoQueueablePatronOrders(queueApi)
		if autoAddedCount > 0 then
			if type(queueApi.Refresh) == "function" then
				queueApi.Refresh()
			end
			ns.Print(LF("MSG_ADDED_TO_YAYAQUEUE_FORMAT", autoAddedCount))
		elseif candidateCount > 0 then
			ns.Print(LF("MSG_YAYAQUEUE_FAILED_FORMAT", autoError or UNKNOWN))
		end
		return
	end

	if addedCount > 0 then
		if type(queueApi.Refresh) == "function" then
			queueApi.Refresh()
		end
		ns.Print(LF("MSG_ADDED_TO_YAYAQUEUE_FORMAT", addedCount))
		return
	end

	ns.Print(LF("MSG_YAYAQUEUE_FAILED_FORMAT", firstError or UNKNOWN))
end

function Pane:ApplyReferenceLayout()
	if not self.root then
		return
	end

	local browseFrame = ProfessionsFrame and ProfessionsFrame.OrdersPage and ProfessionsFrame.OrdersPage.BrowseFrame
	if not browseFrame then
		return
	end

	self.root:ClearAllPoints()
	self.root:SetSize(ROOT_WIDTH, ROOT_HEIGHT)
	self.root:SetPoint("BOTTOMRIGHT", browseFrame, "BOTTOMRIGHT", ROOT_RIGHT_OFFSET, ROOT_BOTTOM_OFFSET)
end

function Pane:ApplyLeftFilterButtonVisuals()
	if not self.root or not self.filterButton then
		return
	end

	local source = FindLeftRecipeFilterButton(self.root)
	if source and CopyFilterButtonVisuals(source, self.filterButton) then
		return
	end

	CreateFallbackFilterButtonVisuals(self.filterButton, L.TOOLBAR_FILTER_BUTTON)
	SetFallbackFilterButtonVisualsShown(self.filterButton, true)
end

function Pane:BuildFrame()
	if self.root then
		return true
	end

	local browseFrame = ProfessionsFrame and ProfessionsFrame.OrdersPage and ProfessionsFrame.OrdersPage.BrowseFrame
	if not browseFrame then
		return false
	end

	local root = CreateFrame("Frame", "YayaCraftingOrdersBrowsePane", browseFrame)
	root:Hide()

	local background = root:CreateTexture(nil, "BACKGROUND")
	background:SetAtlas("auctionhouse-background-index", false)
	background:SetPoint("TOPLEFT", 3, BACKGROUND_TOP_OFFSET)
	background:SetPoint("BOTTOMRIGHT", -4, 0)

	self.createListButton = CreateFrame("Button", nil, root, "UIPanelButtonTemplate")
	self.createListButton:SetPoint("TOPLEFT", root, "TOPLEFT", CREATE_LIST_BUTTON_LEFT_OFFSET, CREATE_LIST_BUTTON_TOP_OFFSET)
	self.createListButton:SetSize(CREATE_LIST_BUTTON_WIDTH, CREATE_LIST_BUTTON_HEIGHT)
	self.createListButton:SetText("YQ+")
	self.createListButton:SetNormalFontObject(GameFontNormalSmall)
	self.createListButton:SetHighlightFontObject(GameFontHighlightSmall)
	self.createListButton:SetMotionScriptsWhileDisabled(true)
	self.createListButton:SetScript("OnClick", function()
		Pane:AddSelectedOrdersToYayaQueue()
	end)
	self.createListButton:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(self.tooltipTitle or L.TOOLBAR_ADD_TO_YAYAQUEUE)
		GameTooltip:AddLine(self.tooltipText or L.TOOLBAR_SELECT_ORDERS_TOOLTIP, 1, 1, 1, true)
		GameTooltip:Show()
	end)
	self.createListButton:SetScript("OnLeave", GameTooltip_Hide)

	self.selectAllButton = CreateFrame("Button", nil, root, "UIPanelButtonTemplate")
	self.selectAllButton:SetPoint("TOPLEFT", root, "TOPLEFT", 36, CREATE_LIST_BUTTON_TOP_OFFSET)
	self.selectAllButton:SetSize(32, 18)
	self.selectAllButton:SetText(L.TOOLBAR_SELECT_ALL_BUTTON)
	self.selectAllButton:SetNormalFontObject(GameFontNormalSmall)
	self.selectAllButton:SetHighlightFontObject(GameFontHighlightSmall)
	self.selectAllButton:SetMotionScriptsWhileDisabled(true)
	self.selectAllButton:SetScript("OnClick", function()
		Pane:ToggleSelectPanel()
	end)
	self.selectAllButton:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
		GameTooltip:SetText(self.tooltipTitle or L.TOOLBAR_SELECT_ALL_MENU)
		GameTooltip:AddLine(self.tooltipText or L.TOOLBAR_SELECT_ALL_TOOLTIP, 1, 1, 1, true)
		GameTooltip:Show()
	end)
	self.selectAllButton:SetScript("OnLeave", GameTooltip_Hide)

	self.filterButton = CreateBlizzardFilterButton(root)
	self.filterButton:SetPoint("TOPRIGHT", root, "TOPRIGHT", FILTER_BUTTON_RIGHT_OFFSET, FILTER_BUTTON_TOP_OFFSET)
	self.filterButton:SetSize(FILTER_BUTTON_WIDTH, FILTER_BUTTON_HEIGHT)
	self.filterButton:SetMotionScriptsWhileDisabled(true)
	CreateFallbackFilterButtonVisuals(self.filterButton, L.TOOLBAR_FILTER_BUTTON)
	self.filterButton:SetScript("OnClick", function()
		Pane:ToggleFilterPanel()
	end)
	self.filterButton:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip:SetText(self.tooltipTitle or L.TOOLBAR_FILTER_MENU)
		GameTooltip:AddLine(self.tooltipText or L.TOOLBAR_FILTER_TOOLTIP, 1, 1, 1, true)
		GameTooltip:AddLine(" ")
		GameTooltip:AddDoubleLine(L.FILTER_RECIPE_HEADER, self.recipeFilterLabel or Pane:GetRecipeFilterLabel(), 1, 1, 1, 1, 1, 1)
		GameTooltip:AddDoubleLine(L.FILTER_CONCENTRATION_HEADER, self.concentrationFilterLabel or Pane:GetConcentrationFilterLabel(), 1, 1, 1, 1, 1, 1)
		GameTooltip:Show()
	end)
	self.filterButton:SetScript("OnLeave", function(self)
		GameTooltip_Hide()
	end)

	self.selectPanel = CreateFrame("Frame", nil, root, BackdropTemplateMixin and "BackdropTemplate" or nil)
	self.selectPanel:SetPoint("TOPLEFT", self.selectAllButton, "BOTTOMLEFT", 0, -4)
	self.selectPanel:SetSize(222, 126)
	self.selectPanel:SetFrameStrata("DIALOG")
	self.selectPanel:SetFrameLevel(root:GetFrameLevel() + 20)
	if type(self.selectPanel.SetBackdrop) == "function" then
		self.selectPanel:SetBackdrop({
			bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
			edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
			tile = true,
			tileSize = 16,
			edgeSize = 16,
			insets = {
				left = 4,
				right = 4,
				top = 4,
				bottom = 4,
			},
		})
		self.selectPanel:SetBackdropColor(0.02, 0.02, 0.02, 0.92)
		self.selectPanel:SetBackdropBorderColor(0.55, 0.55, 0.55, 1)
	end
	self.selectPanel:Hide()

	self.selectPanel.allButton = self:CreateSelectionActionButton(self.selectPanel, L.SELECT_MODE_ALL, self.selectPanel, -12)
	self.selectPanel.knownButton = self:CreateSelectionActionButton(
		self.selectPanel,
		L.SELECT_MODE_KNOWN,
		self.selectPanel.allButton,
		-6
	)
	self.selectPanel.profitableButton = self:CreateSelectionActionButton(
		self.selectPanel,
		L.SELECT_MODE_PROFITABLE,
		self.selectPanel.knownButton,
		-6
	)
	self.selectPanel.availableButton = self:CreateSelectionActionButton(
		self.selectPanel,
		L.SELECT_MODE_AVAILABLE,
		self.selectPanel.profitableButton,
		-6
	)

	self.selectPanel.allButton:SetScript("OnClick", function()
		self:SelectOrdersByMode("all")
	end)
	self.selectPanel.knownButton:SetScript("OnClick", function()
		self:SelectOrdersByMode("known")
	end)
	self.selectPanel.profitableButton:SetScript("OnClick", function()
		self:SelectOrdersByMode("profitable")
	end)
	self.selectPanel.availableButton:SetScript("OnClick", function()
		self:SelectOrdersByMode("available")
	end)

	self.filterPanel = CreateFrame("Frame", nil, root, BackdropTemplateMixin and "BackdropTemplate" or nil)
	self.filterPanel:SetPoint("TOPRIGHT", self.filterButton, "BOTTOMRIGHT", 0, -4)
	self.filterPanel:SetSize(FILTER_PANEL_WIDTH, FILTER_PANEL_HEIGHT)
	self.filterPanel:SetFrameStrata("DIALOG")
	self.filterPanel:SetFrameLevel(root:GetFrameLevel() + 20)
	if type(self.filterPanel.SetBackdrop) == "function" then
		self.filterPanel:SetBackdrop({
			bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
			edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
			tile = true,
			tileSize = 16,
			edgeSize = 16,
			insets = {
				left = 4,
				right = 4,
				top = 4,
				bottom = 4,
			},
		})
		self.filterPanel:SetBackdropColor(0.02, 0.02, 0.02, 0.92)
		self.filterPanel:SetBackdropBorderColor(0.55, 0.55, 0.55, 1)
	end
	self.filterPanel:Hide()

	self.filterPanel.recipeHeader = self.filterPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	self.filterPanel.recipeHeader:SetPoint("TOPLEFT", self.filterPanel, "TOPLEFT", 12, -12)
	self.filterPanel.recipeHeader:SetWidth(FILTER_PANEL_WIDTH - 28)
	self.filterPanel.recipeHeader:SetJustifyH("LEFT")
	self.filterPanel.recipeHeader:SetText(L.FILTER_RECIPE_HEADER)

	self.recipeFilterButtons = {
		[RECIPE_FILTER_KNOWN] = CreateFilterMenuToggle(self.filterPanel, L.FILTER_RECIPE_KNOWN, self.filterPanel.recipeHeader, -17),
	}

	self.recipeFilterButtons[RECIPE_FILTER_KNOWN]:SetScript("OnClick", function()
		Pane:SetRecipeFilter(Pane.recipeFilter == RECIPE_FILTER_KNOWN and RECIPE_FILTER_ALL or RECIPE_FILTER_KNOWN)
	end)

	self.filterPanel.concentrationHeader = self.filterPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	self.filterPanel.concentrationHeader:SetPoint("TOPLEFT", self.recipeFilterButtons[RECIPE_FILTER_KNOWN], "BOTTOMLEFT", 2, -12)
	self.filterPanel.concentrationHeader:SetWidth(FILTER_PANEL_WIDTH - 28)
	self.filterPanel.concentrationHeader:SetJustifyH("LEFT")
	self.filterPanel.concentrationHeader:SetText(L.FILTER_CONCENTRATION_HEADER)

	self.concentrationFilterButtons = {
		[CONCENTRATION_FILTER_NONE] = CreateFilterMenuToggle(self.filterPanel, L.FILTER_CONCENTRATION_NONE, self.filterPanel.concentrationHeader, -17),
	}

	self.concentrationFilterButtons[CONCENTRATION_FILTER_NONE]:SetScript("OnClick", function()
		Pane:SetConcentrationFilter(Pane.concentrationFilter == CONCENTRATION_FILTER_NONE and CONCENTRATION_FILTER_ALL or CONCENTRATION_FILTER_NONE)
	end)

	self.headers = {
		order = CreateHeaderButton(root, L.HEADER_YOU_CRAFT_SUPPLY, "order", ORDER_WIDTH, SELECT_WIDTH + 2),
		cost = CreateHeaderButton(root, L.HEADER_COST, "cost", COST_WIDTH, SELECT_WIDTH + ORDER_WIDTH + 2),
		reward = CreateHeaderButton(root, L.HEADER_REWARD, "reward", REWARD_WIDTH, SELECT_WIDTH + ORDER_WIDTH + COST_WIDTH + 2),
		profit = CreateHeaderButton(root, L.HEADER_PROFIT, "profit", PROFIT_WIDTH, SELECT_WIDTH + ORDER_WIDTH + COST_WIDTH + REWARD_WIDTH + 2),
		time = CreateHeaderButton(root, GetTimeHeaderText(), "time", PATRON_WIDTH, SELECT_WIDTH + ORDER_WIDTH + COST_WIDTH + REWARD_WIDTH + PROFIT_WIDTH + 2),
	}

	for _, header in pairs(self.headers) do
		header:SetScript("OnClick", function(button, mouseButton)
			local sortAscending
			if Pane.sortKey == button.sortKey then
				sortAscending = mouseButton == "RightButton" and true or not Pane.sortAscending
			else
				sortAscending = mouseButton == "RightButton"
			end
			Pane:SetSort(button.sortKey, sortAscending)
		end)
	end

	self.sortArrow = root:CreateTexture(nil, "ARTWORK")
	self.sortArrow:SetAtlas("auctionhouse-ui-sortarrow", true)

	local scrollBarInset = 10
	local scrollBarGap = 10

	self.scrollFrame = CreateFrame("Frame", nil, root, "WowScrollBoxList")
	self.scrollFrame:SetPoint("TOPLEFT", root, "TOPLEFT", 0, SCROLL_TOP_OFFSET)

	self.scrollBar = CreateFrame("EventFrame", nil, root, "MinimalScrollBar")
	self.scrollBar:SetPoint("TOPRIGHT", root, "TOPRIGHT", -scrollBarInset, SCROLL_TOP_OFFSET)
	self.scrollBar:SetPoint("BOTTOMRIGHT", root, "BOTTOMRIGHT", -scrollBarInset, 10)

	self.scrollFrame:SetPoint("TOPRIGHT", self.scrollBar, "TOPLEFT", -scrollBarGap, 0)
	self.scrollFrame:SetPoint("BOTTOMRIGHT", self.scrollBar, "BOTTOMLEFT", -scrollBarGap, 0)

	if self.scrollFrame.SetInterpolateScroll then
		self.scrollFrame:SetInterpolateScroll(true)
	end
	if self.scrollBar.SetInterpolateScroll then
		self.scrollBar:SetInterpolateScroll(true)
	end

	local scrollView = CreateScrollBoxListLinearView()
	scrollView:SetElementExtent(ROW_HEIGHT)
	if scrollView.SetPadding then
		scrollView:SetPadding(0, 0, 0, 0, 0)
	end
	scrollView:SetElementInitializer("Button", function(button, elementData)
		Pane:CreateRow(elementData and elementData.index, button)
		Pane:ApplyRowData(button, elementData)
	end)
	if scrollView.SetElementResetter then
		scrollView:SetElementResetter(function(button)
			button.order = nil
		end)
	end

	ScrollUtil.InitScrollBoxListWithScrollBar(self.scrollFrame, self.scrollBar, scrollView)
	self.orderDataProvider = CreateDataProvider()
	self.scrollFrame:SetDataProvider(self.orderDataProvider)
	self.rows = {}

	self.noOrders = root:CreateFontString(nil, "ARTWORK", "GameFontDisableLarge")
	self.noOrders:SetPoint("CENTER", self.scrollFrame, "CENTER", 0, 40)
	self.noOrders:SetText(EMPTY_STATE_EMPTY_TEXT)
	self.noOrders:Hide()

	root:SetScript("OnShow", function()
		ns.Debug("ui", "custom pane OnShow")
		Pane:ApplyReferenceLayout()
		Pane:ApplyLeftFilterButtonVisuals()
		C_Timer.After(0, function()
			if Pane and Pane.root and Pane.root:IsShown() then
				Pane:ApplyLeftFilterButtonVisuals()
				Pane:UpdateScrollBox()
				Pane:UpdateNextOrderButton()
			end
		end)
		Pane:BeginVisibleSession()
		Pane:MarkDirty("show")
	end)
	root:SetScript("OnUpdate", function(_, elapsed)
		Pane.elapsedSinceTick = (Pane.elapsedSinceTick or 0) + elapsed
		Pane.elapsedSinceNextButtonTick = (Pane.elapsedSinceNextButtonTick or 0) + elapsed

		if Pane.pendingDueAt and GetTime() >= Pane.pendingDueAt then
			Pane.pendingDueAt = nil
			Pane:ProcessPendingRefresh()
		end

		if Pane.root:IsShown() and Pane.elapsedSinceNextButtonTick > 0.25 then
			Pane.elapsedSinceNextButtonTick = 0
			Pane:UpdateNextOrderButton()
		end

		if Pane.root:IsShown() and Pane.elapsedSinceTick > 30 then
			Pane.elapsedSinceTick = 0
			Pane:UpdateTimeLabels()
		end
	end)

	self.root = root
	self:ApplyReferenceLayout()

	if not self.layoutHooked then
		self.layoutHooked = true
		browseFrame:HookScript("OnSizeChanged", function()
			Pane:ApplyReferenceLayout()
		end)
	end

	return true
end

function Pane:GetVisibleRawOrders()
	local rawOrders = {}
	for _, rawOrder in ipairs(C_CraftingOrders.GetCrafterOrders() or EMPTY_LIST) do
		if rawOrder.orderType == ns.ORDER_TYPE_NPC then
			rawOrders[#rawOrders + 1] = rawOrder
		end
	end

	return rawOrders
end

function Pane:SyncYayaQueuePatronOrders(rawOrders, professionID)
	local queueApi = self:GetYayaQueueAPI()
	if not professionID or not queueApi or type(queueApi.SyncPatronOrders) ~= "function" then
		return 0
	end

	local rawCount = #(rawOrders or EMPTY_LIST)
	if rawCount > 0 then
		self.emptySyncConfirmation = nil
	else
		local confirmation = self.emptySyncConfirmation
		if not confirmation
			or confirmation.professionID ~= professionID
			or confirmation.visibleSessionId ~= self.visibleSessionId then
			confirmation = {
				professionID = professionID,
				visibleSessionId = self.visibleSessionId,
				attempts = 0,
			}
			self.emptySyncConfirmation = confirmation
		end
		confirmation.attempts = confirmation.attempts + 1
		if confirmation.attempts < Pane.retryConfig.emptySyncLimit then
			self.needsRebuild = true
			self:SchedulePendingRefresh("empty-sync-confirm", Pane.retryConfig.emptySyncDelay)
			ns.Debug(
				"queue",
				"defer empty patron sync profession=%s confirmation=%s/%s",
				tostring(professionID),
				tostring(confirmation.attempts),
				tostring(Pane.retryConfig.emptySyncLimit)
			)
			return 0
		end
		self.emptySyncConfirmation = nil
	end

	local availableOrderIDs = {}
	for _, rawOrder in ipairs(rawOrders or EMPTY_LIST) do
		local orderID = tonumber(rawOrder.orderID) or 0
		if orderID > 0 then
			availableOrderIDs[orderID] = true
		end
	end

	local removed, removedOrderIDs = queueApi.SyncPatronOrders(availableOrderIDs, professionID)
	if removed > 0 then
		local bucket = self:GetAutoQueueSessionBucket()
		for orderID in pairs(removedOrderIDs or EMPTY_LIST) do
			if bucket then
				bucket[orderID] = nil
			end
		end
		ns.Debug("queue", "removed unavailable patron orders profession=%s count=%s", tostring(professionID), tostring(removed))
	end
	return removed
end

function Pane:CanOpenPatronOrders()
	if type(C_CraftingOrders) == "table"
		and type(C_CraftingOrders.ShouldShowCraftingOrderTab) == "function" then
		local ok, shouldShow = pcall(C_CraftingOrders.ShouldShowCraftingOrderTab)
		if ok and shouldShow == false then
			return false, true
		end
	end

	return true, false
end

function Pane:GetProfessionSnapshot()
	local snapshot = {
		child = nil,
		base = nil,
		ordersPage = nil,
		apiAvailable = false,
	}
	local professionInfo

	if type(C_TradeSkillUI) == "table" and type(C_TradeSkillUI.GetChildProfessionInfo) == "function" then
		snapshot.apiAvailable = true
		local ok, info = Util.SafeCall(C_TradeSkillUI.GetChildProfessionInfo)
		professionInfo = ok and info or nil
		snapshot.child = professionInfo and tonumber(professionInfo.profession) or nil
	end

	if type(C_TradeSkillUI) == "table" and type(C_TradeSkillUI.GetBaseProfessionInfo) == "function" then
		snapshot.apiAvailable = true
		local ok, info = Util.SafeCall(C_TradeSkillUI.GetBaseProfessionInfo)
		professionInfo = ok and info or nil
		snapshot.base = professionInfo and tonumber(professionInfo.profession) or nil
	end

	local ordersPage = ProfessionsFrame and ProfessionsFrame.OrdersPage
	professionInfo = ordersPage and ordersPage.professionInfo
	snapshot.ordersPage = professionInfo and tonumber(professionInfo.profession) or nil

	-- OrdersPage.professionInfo can still describe the previous profession while
	-- the C_TradeSkillUI source already describes the profession being opened.
	-- Only use the UI field when the authoritative APIs are unavailable.
	snapshot.selected = snapshot.child or snapshot.base
	if not snapshot.selected and not snapshot.apiAvailable then
		snapshot.selected = snapshot.ordersPage
	end

	return snapshot
end

function Pane:GetCurrentProfessionID()
	return self:GetProfessionSnapshot().selected
end

function Pane:DebugState(reason)
	local ordersPage = ProfessionsFrame and ProfessionsFrame.OrdersPage
	local professionSnapshot = self:GetProfessionSnapshot()
	local profession = professionSnapshot.selected
	local canOpenPatronOrders = self:CanOpenPatronOrders()
	local nearFocus = false
	if profession
		and type(C_TradeSkillUI) == "table"
		and type(C_TradeSkillUI.IsNearProfessionSpellFocus) == "function" then
		local ok, result = pcall(C_TradeSkillUI.IsNearProfessionSpellFocus, profession)
		nearFocus = ok and not not result
	end

	local rawCount = -1
	if type(C_CraftingOrders) == "table" and type(C_CraftingOrders.GetCrafterOrders) == "function" then
		local ok, rawOrders = pcall(C_CraftingOrders.GetCrafterOrders)
		if ok and type(rawOrders) == "table" then
			rawCount = #rawOrders
		end
	end

	ns.Debug(
		"state",
		"reason=%s init=%s ready=%s pageShown=%s rootShown=%s rootVisible=%s type=%s patrons=%s profession=%s child=%s base=%s orders=%s focus=%s session=%s request=%s id=%s requestProfession=%s requestSession=%s needs=%s/%s/%s retry=%s/%s pending=%s raw=%s prepared=%s visible=%s",
		tostring(reason),
		tostring(self.initialized == true),
		tostring(ns.IsProfessionsReady()),
		tostring(ordersPage and ordersPage:IsShown() or false),
		tostring(self.root and self.root:IsShown() or false),
		tostring(self.root and self.root:IsVisible() or false),
		tostring(self:GetCurrentOrderType()),
		tostring(canOpenPatronOrders == true),
		tostring(profession),
		tostring(professionSnapshot.child),
		tostring(professionSnapshot.base),
		tostring(professionSnapshot.ordersPage),
		tostring(nearFocus),
		tostring(self.visibleSessionId),
		tostring(self.requesting == true),
		tostring(self.activeRequestID),
		tostring(self.activeRequestProfession),
		tostring(self.activeRequestSessionId),
		tostring(self.needsRequest == true),
		tostring(self.needsRebuild == true),
		tostring(self.needsRender == true),
		tostring(self.requestReadinessRetryCount or 0),
		tostring(self.requestFailureRetryCount or 0),
		tostring(self.pendingReason),
		tostring(rawCount),
		tostring(#(self.allOrders or EMPTY_LIST)),
		tostring(#(self.orders or EMPTY_LIST))
	)
	local flow = self.autoScanFlow
	ns.Debug(
		"flow-state",
		"reason=%s opening=%s/%s completed=%s canRequest=%s/%s attempts=%s retryQueued=%s flow=%s/%s/%s/%s requesting=%s requestID=%s requestAttempts=%s readiness=%s visibleRequest=%s visibleQueue=%s",
		tostring(reason),
		tostring(self.autoScanOpeningRequested == true),
		tostring(self.autoScanOpeningProfession),
		tostring(profession and self.autoScanCompletedByProfession[profession] == true or false),
		tostring(self.craftingOrdersCanRequest),
		tostring(self.craftingOrdersCanRequestProfession),
		tostring(self.autoScanStartAttempts or 0),
		tostring(self.autoScanStartRetryQueued == true),
		tostring(flow and flow.profession),
		tostring(flow and flow.mode),
		tostring(flow and flow.stage),
		tostring(flow and flow.sessionKey),
		tostring(flow and flow.requesting == true),
		tostring(flow and flow.requestID),
		tostring(flow and flow.requestAttempts or 0),
		tostring(flow and flow.readinessAttempts or 0),
		tostring(flow and flow.visibleRequestSucceeded == true),
		tostring(flow and flow.visibleQueueProcessed == true)
	)
end

function Pane:RepositionOrderActionButtons()
	local ordersPage = ProfessionsFrame and ProfessionsFrame.OrdersPage
	local orderView = ordersPage and ordersPage.OrderView
	local orderDetails = orderView and orderView.OrderDetails
	local schematicForm = orderDetails and orderDetails.SchematicForm
	local roots = {
		ProfessionsCustomerOrdersFrame,
		ordersPage,
		orderView,
		orderDetails,
		schematicForm,
	}

	local createButton
	for _, root in ipairs(roots) do
		createButton = createButton or FindDescendantButtonByText(root, { "Create", "Créer", "Creer" }, 12)
	end
	if not createButton then
		return
	end

	local actionButton
	for _, root in ipairs(roots) do
		actionButton = actionButton
			or FindDescendantButtonByText(root, { "Start Order", "Complete Order", "Démarrer", "Terminer" }, 12)
	end
	if not actionButton or actionButton == createButton then
		return
	end

	ReanchorButtonToMatch(actionButton, createButton)
end

function Pane:GetCurrentProfessionSelection()
	local key = GetProfessionSelectionKey(self.visibleProfession)
	local selection = self.selectedOrderIDsByProfession[key]
	if type(selection) ~= "table" then
		selection = {}
		self.selectedOrderIDsByProfession[key] = selection
	end

	self.selectedOrderIDs = selection
	return selection
end

function Pane:GetSelectedOrdersForCurrentProfession()
	self:PruneSelectedOrders()

	local selectedOrders = {}
	for _, order in ipairs(self.allOrders or self.orders or EMPTY_LIST) do
		if self.selectedOrderIDs[order.orderID] then
			selectedOrders[#selectedOrders + 1] = order
		end
	end

	return selectedOrders
end

function Pane:GetNextSelectedOrder()
	local selectedOrders = self:GetSelectedOrdersForCurrentProfession()
	if #selectedOrders == 0 then
		return nil
	end

	local currentOrderID = nil
	local _, orderInfo = self:GetCurrentOrderViewContext()
	if orderInfo and orderInfo.orderID then
		currentOrderID = orderInfo.orderID
	end

	if not currentOrderID then
		return selectedOrders[1]
	end

	for index, order in ipairs(selectedOrders) do
		if order.orderID == currentOrderID then
			return selectedOrders[index + 1] or selectedOrders[1]
		end
	end

	return selectedOrders[1]
end

function Pane:GoToNextSelectedOrder()
	local nextOrder = self:GetNextSelectedOrder()
	if not nextOrder then
		ns.Print(L.MSG_SELECT_ORDERS_FIRST)
		return
	end

	self:ViewOrder(nextOrder)
end

function Pane:EnsureNextOrderButton()
	if self.nextOrderButton then
		return self.nextOrderButton
	end

	local parent = (ProfessionsFrame and ProfessionsFrame.OrdersPage) or UIParent
	local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	button:SetSize(90, 22)
	button:SetText(L.TOOLBAR_NEXT_ORDER_BUTTON or "Suivant")
	button:SetFrameStrata("DIALOG")
	button:SetFrameLevel((parent:GetFrameLevel() or 1) + 30)
	button:SetScript("OnClick", function()
		Pane:GoToNextSelectedOrder()
	end)
	button:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:SetText(L.TOOLBAR_NEXT_ORDER_TITLE or "Order suivant")
		GameTooltip:AddLine(L.TOOLBAR_NEXT_ORDER_TOOLTIP or "Ouvre le prochain order sélectionné pour ce métier.", 1, 1, 1, true)
		GameTooltip:Show()
	end)
	button:SetScript("OnLeave", GameTooltip_Hide)
	button:Hide()

	self.nextOrderButton = button
	return button
end

function Pane:UpdateNextOrderButton()
	local button = self:EnsureNextOrderButton()
	if not button then
		return
	end

	local selectedOrders = self:GetSelectedOrdersForCurrentProfession()
	if #selectedOrders == 0 then
		button:Hide()
		return
	end

	local ordersPage = ProfessionsFrame and ProfessionsFrame.OrdersPage
	local orderView = ordersPage and ordersPage.OrderView
	local orderDetails = orderView and orderView.OrderDetails
	local schematicForm = orderDetails and orderDetails.SchematicForm
	local roots = {
		ProfessionsCustomerOrdersFrame,
		ordersPage,
		orderView,
		orderDetails,
		schematicForm,
	}

	local anchorButton
	for _, root in ipairs(roots) do
		anchorButton = anchorButton
			or FindDescendantButtonByText(root, { "Create", "Créer", "Creer", "Start Order", "Complete Order", "Démarrer", "Terminer" }, 12)
	end
	if not anchorButton then
		button:Hide()
		return
	end

	ReanchorButtonToMatch(button, anchorButton)
	button:SetText(L.TOOLBAR_NEXT_ORDER_BUTTON or "Suivant")
	button:SetEnabled(self:GetNextSelectedOrder() ~= nil)

	if anchorButton:IsShown() then
		button:Hide()
	else
		button:Show()
	end
end

function Pane:HideAllRows()
	for _, row in ipairs(self.rows or {}) do
		row:Hide()
		row.order = nil
	end

	if self.orderDataProvider then
		self.orderDataProvider:Flush()
	end
	self:UpdateScrollBox()
end

function Pane:SetRowIcons(row, bucketName, startX, yOffset, items)
	self:EnsureIconCount(row, bucketName, #items)

	local xOffset = startX
	for index, icon in ipairs(row[bucketName]) do
		local item = items[index]
		if item then
			if item.leadingSpacer then
				xOffset = xOffset + ICON_GROUP_SPACER
			end
			icon:SetPoint("TOPLEFT", row, "TOPLEFT", xOffset, yOffset)
			self:SetIconData(icon, item)
			xOffset = xOffset + REAGENT_ICON_SIZE + 2
		else
			icon:Hide()
			icon.data = nil
		end
	end
end

-- Table de correspondance hissee hors de la fonction : elle etait reconstruite
-- a chaque ligne et a chaque rafraichissement de la liste.
local SKILL_UP_ATLAS = {
	[0] = "Professions-Icon-Skill-High",
	[1] = "Professions-Icon-Skill-Medium",
	[2] = "Professions-Icon-Skill-Low",
}

local FIRST_CRAFT_MARKUP = "|A:Professions_Icon_FirstTimeCraft:14:12:0:1|a"

-- Tampon reutilise entre les appels : la fonction est appelee pour chaque ligne
-- visible a chaque rafraichissement.
local flagParts = {}

function Pane:GetFlagText(order)
	local count = 0
	if order.firstCraft then
		count = count + 1
		flagParts[count] = FIRST_CRAFT_MARKUP
	end
	if order.canSkillUp and order.relativeDifficulty ~= nil then
		local atlas = SKILL_UP_ATLAS[order.relativeDifficulty]
		if atlas then
			count = count + 1
			flagParts[count] = ("|A:%s:13:14|a %s"):format(atlas, order.skillUps > 1 and order.skillUps or "")
		end
	end
	if count == 0 then
		return ""
	end
	return table.concat(flagParts, "  ", 1, count)
end

function Pane:SortPreparedOrders()
	SortOrders(self.orders, self.sortKey, self.sortAscending)
end

function Pane:UpdateScrollBox()
	if self.scrollFrame and self.scrollFrame.FullUpdate then
		local updateImmediately = ScrollBoxConstants and ScrollBoxConstants.UpdateImmediately or true
		self.scrollFrame:FullUpdate(updateImmediately)
	end
end

function Pane:ApplyRowData(row, elementData)
	local order = elementData and (elementData.order or elementData)
	if not row or not order then
		if row then
			row:Hide()
			row.order = nil
		end
		return
	end

	local index = elementData.index or row.rowIndex or 1
	row.rowIndex = index
	row.order = order
	row:Show()
	if row.background then
		if ns.UI then
			row.background:SetColorTexture(
				ns.UI.Unpack(index % 2 == 1 and ns.UI.COLOR.rowOdd or ns.UI.COLOR.rowEven))
		else
			row.background:SetColorTexture(1, 1, 1, index % 2 == 0 and 0.025 or 0.01)
		end
	end
	row.checkbox:SetChecked(not not self.selectedOrderIDs[order.orderID])

	local titleColor = WHITE_FONT_COLOR
	local desaturated = false
	local greyUnknown = not order.isKnown and ns.GetConfig("greyUnknownRecipes")
	if greyUnknown then
		titleColor = DISABLED_FONT_COLOR
		desaturated = true
	end
	row:SetAlpha(greyUnknown and 0.6 or 1)
	local inlineFlags = order.isKnown and self:GetFlagText(order) or ""
	if inlineFlags ~= "" then
		inlineFlags = "  " .. inlineFlags
	end
	row.title:SetText(order.product.label .. GetQualityIndicatorText(order) .. inlineFlags)
	row.title:SetTextColor(titleColor.r, titleColor.g, titleColor.b)
	row.flags:SetText("")
	row.flags:Hide()
	self:SetIconData(row.productIcon, {
		itemID = order.product.itemID,
		itemLink = order.product.itemLink,
		icon = order.product.icon,
		count = 1,
		isKnown = order.isKnown,
		desaturated = desaturated,
		extraLines = order.productTooltipLines,
		unknownRecipeLines = order.isKnown and nil or order.unknownRecipeTooltip,
	})

	local reagentIcons = {}
	for _, entry in ipairs(GetMaterialPlanEntries(order)) do
		local option = entry.option
		if option then
			reagentIcons[#reagentIcons + 1] = {
				itemID = option.itemID,
				itemLink = option.itemLink,
				icon = select(5, C_Item.GetItemInfoInstant(option.itemID)),
				count = entry.quantity,
				alwaysShowCount = true,
				name = option.name,
				reagentQuality = option.reagentQuality,
				borderAtlas = option.borderAtlas,
				shortage = entry.shortage,
				availableTotal = entry.availableTotal,
				selectedQualityOwnedCount = entry.selectedQualityOwnedCount,
				otherQualityOwnedCount = entry.otherQualityOwnedCount,
				totalOwnedCount = entry.totalOwnedCount,
				unitPrice = option.unitPrice,
				totalPrice = entry.totalPrice,
				priceState = entry.priceState,
				doNotBuy = self:IsDontBuyItem(option.itemID),
				toggleDontBuy = true,
			}
		end
	end

	if order.concentration and order.concentration.currentCost and order.concentration.currencyID then
		local currencyBasic = C_CurrencyInfo.GetBasicCurrencyInfo(order.concentration.currencyID, order.concentration.currentCost)
		reagentIcons[#reagentIcons + 1] = {
			currencyID = order.concentration.currencyID,
			icon = currencyBasic and currencyBasic.icon,
			count = order.concentration.currentCost,
			alwaysShowCount = true,
			borderAtlas = GetBorderAtlas(nil, currencyBasic and currencyBasic.quality),
			leadingSpacer = #reagentIcons > 0,
			availableTotal = order.concentration.available,
			shortage = math.max(0, (order.concentration.currentCost or 0) - (order.concentration.available or 0)),
			extraLines = BuildConcentrationExtraLines(order.concentration),
		}
	end

	row.reagentLabel:Hide()
	self:SetRowIcons(row, "reagentIcons", SELECT_WIDTH + PRODUCT_ICON_LEFT_OFFSET + PRODUCT_ICON_SIZE + PRODUCT_TEXT_GAP, ROW_ICON_Y_OFFSET, reagentIcons)

	if #GetMaterialPlanEntries(order) == 0 then
		row.costText:SetText(NONE)
		row.costHint:SetText(L.COST_HINT_ALL_PROVIDED)
	elseif (order.marketableMaterialEntryCount or 0) == 0 and (order.excludedMaterialEntryCount or 0) > 0 then
		row.costText:SetText(NONE)
		row.costHint:SetText(L.PRICE_NOT_MARKETABLE)
	elseif order.materialCostKnown then
		local costText = FormatListMoney(order.materialCost)
		if not order.materialCostComplete then
			costText = costText .. "*"
		end
		row.costText:SetText(costText)
		row.costHint:SetText(order.materialCostComplete and L.COST_HINT_ALL_PRICED or L.COST_HINT_PARTIAL_PRICING)
	else
		row.costText:SetText(NONE)
		row.costHint:SetText(L.PRICE_NO_MARKET_DATA)
	end

	row.rewardText:SetText(order.reward.gold > 0 and FormatListMoney(order.reward.gold) or NONE)
	row.rewardValue:SetText("")

	if order.profitKnown then
		local profitText = FormatListMoney(order.profitValue or 0, true)
		if not order.profitComplete then
			profitText = profitText .. "*"
		end
		row.profitText:SetText(profitText)
		if (order.profitValue or 0) < 0 then
			row.profitText:SetTextColor(RED_FONT_COLOR.r, RED_FONT_COLOR.g, RED_FONT_COLOR.b)
		else
			row.profitText:SetTextColor(HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)
		end
	else
		row.profitText:SetText(NONE)
		row.profitText:SetTextColor(DISABLED_FONT_COLOR.r, DISABLED_FONT_COLOR.g, DISABLED_FONT_COLOR.b)
	end

	for _, icon in ipairs(order.reward.icons) do
		if icon.itemID and not icon.icon then
			icon.icon = select(5, C_Item.GetItemInfoInstant(icon.itemID))
		end
	end
	self:SetRowIcons(row, "rewardIcons", SELECT_WIDTH + ORDER_WIDTH + COST_WIDTH + 8, ROW_ICON_Y_OFFSET, order.reward.icons)

	local secondsRemaining = math.max(0, (order.expirationTime or 0) - C_CraftingOrders.GetCraftingOrderTime())
	local red, green, blue = GetTimeColor(secondsRemaining)
	row.timeLeft:SetText(FormatTimeRemaining(secondsRemaining))
	row.timeLeft:SetTextColor(red, green, blue)
end

function Pane:RenderRows()
	self.rowData = self.rowData or {}
	wipe(self.rowData)
	for index, order in ipairs(self.orders) do
		self.rowData[index] = {
			order = order,
			index = index,
		}
	end

	if self.orderDataProvider then
		self.orderDataProvider:Flush()
		if #self.rowData > 0 then
			self.orderDataProvider:InsertTable(self.rowData)
		end
	end

	self:UpdateScrollBox()
	C_Timer.After(0, function()
		if Pane and Pane.root and Pane.root:IsShown() then
			Pane:UpdateScrollBox()
		end
	end)
	self:UpdateEmptyState()
	self:UpdateHeaderArrow()
	self:UpdateToolbar()
end

function Pane:UpdateTimeLabels()
	for _, row in ipairs(self.rows) do
		if row:IsShown() and row.order then
			local secondsRemaining = math.max(0, (row.order.expirationTime or 0) - C_CraftingOrders.GetCraftingOrderTime())
			local red, green, blue = GetTimeColor(secondsRemaining)
			row.timeLeft:SetText(FormatTimeRemaining(secondsRemaining))
			row.timeLeft:SetTextColor(red, green, blue)
		end
	end
end

local function GetConfigKeyFromReason(reason)
	return type(reason) == "string" and reason:match("^config:(.+)$") or nil
end

local function DoesReasonBumpGeneration(reason)
	local configKey = GetConfigKeyFromReason(reason)
	return reason == "pricing-db"
		or reason == "trade-skill-source"
		or configKey == "pricingSource"
end

local function IsRenderOnlyConfigKey(configKey)
	return configKey == "greyUnknownRecipes"
		or configKey == "showSilverCopperInList"
		or configKey == "dontBuyPerCharacter"
end

function Pane:GetRecipeFilterLabel(filterKey)
	filterKey = NormalizeRecipeFilter(filterKey or self.recipeFilter)
	if filterKey == RECIPE_FILTER_KNOWN then
		return L.FILTER_RECIPE_KNOWN
	elseif filterKey == RECIPE_FILTER_UNKNOWN then
		return L.FILTER_RECIPE_UNKNOWN
	end

	return L.FILTER_RECIPE_ALL
end

function Pane:GetConcentrationFilterLabel(filterKey)
	filterKey = NormalizeConcentrationFilter(filterKey or self.concentrationFilter)
	if filterKey == CONCENTRATION_FILTER_NEEDS then
		return L.FILTER_CONCENTRATION_NEEDS
	elseif filterKey == CONCENTRATION_FILTER_NONE then
		return L.FILTER_CONCENTRATION_NONE
	end

	return L.FILTER_CONCENTRATION_ALL
end

function Pane:HasActiveFilters()
	return NormalizeRecipeFilter(self.recipeFilter) ~= RECIPE_FILTER_ALL
		or NormalizeConcentrationFilter(self.concentrationFilter) ~= CONCENTRATION_FILTER_ALL
end

function Pane:DoesOrderMatchFilters(orderData)
	if not orderData then
		return false
	end

	local recipeFilter = NormalizeRecipeFilter(self.recipeFilter)
	if recipeFilter == RECIPE_FILTER_KNOWN and not orderData.isKnown then
		return false
	elseif recipeFilter == RECIPE_FILTER_UNKNOWN and orderData.isKnown then
		return false
	end

	local concentrationFilter = NormalizeConcentrationFilter(self.concentrationFilter)
	local needsConcentration = DoesOrderNeedConcentration(orderData)
	local currentProfession = self.visibleProfession or self:GetCurrentProfessionID()
	if needsConcentration and ns.ShouldIgnoreConcentrationOrdersForProfession and ns.ShouldIgnoreConcentrationOrdersForProfession(currentProfession) then
		return false
	end
	if concentrationFilter == CONCENTRATION_FILTER_NEEDS and not needsConcentration then
		return false
	elseif concentrationFilter == CONCENTRATION_FILTER_NONE and needsConcentration then
		return false
	end

	return true
end

function Pane:ApplyOrderFilters()
	local filteredOrders = {}
	for _, order in ipairs(self.allOrders or EMPTY_LIST) do
		if self:DoesOrderMatchFilters(order) then
			filteredOrders[#filteredOrders + 1] = order
		end
	end

	self.orders = filteredOrders
end

function Pane:SetRecipeFilter(filterKey)
	filterKey = NormalizeRecipeFilter(filterKey)
	local db = ns.GetDatabase and ns.GetDatabase()
	if type(db) == "table" then
		db.patronRecipeFilter = filterKey
	end

	if self.recipeFilter == filterKey then
		self:UpdateFilterPanel()
		return
	end

	self.recipeFilter = filterKey
	self:UpdateFilterPanel()
	self:MarkDirty("filter")
end

function Pane:SetConcentrationFilter(filterKey)
	filterKey = NormalizeConcentrationFilter(filterKey)
	local db = ns.GetDatabase and ns.GetDatabase()
	if type(db) == "table" then
		db.patronConcentrationFilter = filterKey
	end

	if self.concentrationFilter == filterKey then
		self:UpdateFilterPanel()
		return
	end

	self.concentrationFilter = filterKey
	self:UpdateFilterPanel()
	self:MarkDirty("filter")
end

function Pane:SetSort(sortKey, sortAscending)
	sortKey = NormalizeSortKey(sortKey)
	sortAscending = sortAscending == true
	local db = ns.GetDatabase and ns.GetDatabase()
	if type(db) == "table" then
		db.patronSortKey = sortKey
		db.patronSortAscending = sortAscending
	end

	if self.sortKey == sortKey and self.sortAscending == sortAscending then
		self:UpdateHeaderArrow()
		return
	end

	self.sortKey = sortKey
	self.sortAscending = sortAscending
	self:MarkDirty("sort")
end

function Pane:LoadSavedFilters()
	self.recipeFilter = NormalizeRecipeFilter(ns.GetConfig and ns.GetConfig("patronRecipeFilter") or self.recipeFilter)
	self.concentrationFilter = NormalizeConcentrationFilter(ns.GetConfig and ns.GetConfig("patronConcentrationFilter") or self.concentrationFilter)
	self:UpdateFilterPanel()
end

function Pane:LoadSavedSort()
	self.sortKey = NormalizeSortKey(ns.GetConfig and ns.GetConfig("patronSortKey") or self.sortKey)
	self.sortAscending = (ns.GetConfig and ns.GetConfig("patronSortAscending")) == true
	self:UpdateHeaderArrow()
end

function Pane:UpdateFilterPanel()
	if not self.filterPanel then
		return
	end

	if self.recipeFilterButtons then
		local recipeFilter = NormalizeRecipeFilter(self.recipeFilter)
		SetFilterMenuToggleChecked(self.recipeFilterButtons[RECIPE_FILTER_KNOWN], recipeFilter == RECIPE_FILTER_KNOWN)
	end

	if self.concentrationFilterButtons then
		local concentrationFilter = NormalizeConcentrationFilter(self.concentrationFilter)
		SetFilterMenuToggleChecked(self.concentrationFilterButtons[CONCENTRATION_FILTER_NONE], concentrationFilter == CONCENTRATION_FILTER_NONE)
	end
end

function Pane:HideFloatingPanels(exceptPanel)
	if self.filterPanel and self.filterPanel ~= exceptPanel then
		self.filterPanel:Hide()
	end
	if self.selectPanel and self.selectPanel ~= exceptPanel then
		self.selectPanel:Hide()
	end
end

function Pane:ToggleFilterPanel()
	if not self.filterPanel then
		return
	end

	if self.filterPanel:IsShown() then
		self.filterPanel:Hide()
		return
	end

	self:HideFloatingPanels(self.filterPanel)
	self:UpdateFilterPanel()
	self.filterPanel:Show()
end

function Pane:ToggleSelectPanel()
	if not self.selectPanel then
		return
	end

	if self.selectPanel:IsShown() then
		self.selectPanel:Hide()
		return
	end

	self:HideFloatingPanels(self.selectPanel)
	self.selectPanel:Show()
end

local function GetReasonPriority(reason)
	if reason == "show" or reason == "order-type" or reason == "can-request" or reason == "request-timeout" or reason == "request-success" then
		return 3
	end
	if reason == "pricing-db" or reason == "trade-skill-source" or reason == "order-count" or reason == "rewards" or reason == "item-data" then
		return 2
	end
	if GetConfigKeyFromReason(reason) then
		return 2
	end
	if reason == "sort" or reason == "filter" then
		return 1
	end
	return 0
end

function Pane:HasVisibleOrdersForProfession(profession)
	local orders = self.allOrders or self.orders or EMPTY_LIST
	return profession ~= nil
		and self.ordersProfession == profession
		and #orders > 0
end

function Pane:HasSuccessfulRequestForVisibleSession(profession)
	local requestInfo = self.lastSuccessfulRequest
	return requestInfo ~= nil
		and requestInfo.visibleSessionId == self.visibleSessionId
		and requestInfo.profession == profession
end

function Pane:HasTimedOutRequestForVisibleSession(profession)
	local requestInfo = self.lastTimedOutRequest
	return requestInfo ~= nil
		and requestInfo.visibleSessionId == self.visibleSessionId
		and requestInfo.profession == profession
end

function Pane:NeedsPreparedOrderRebuild(profession)
	return profession ~= nil
		and self.ordersProfession == profession
		and (self.ordersGeneration or 0) ~= (self.rebuildGeneration or 0)
end

function Pane:PruneSelectedOrders()
	local sourceOrders = self.allOrders or self.orders or EMPTY_LIST
	if #sourceOrders == 0 then
		return
	end

	local validSelection = {}
	for _, order in ipairs(sourceOrders) do
		if self.selectedOrderIDs[order.orderID] then
			validSelection[order.orderID] = true
		end
	end

	self.selectedOrderIDs = validSelection
	self.selectedOrderIDsByProfession[GetProfessionSelectionKey(self.visibleProfession)] = validSelection
end

function Pane:ClearVisibleOrders(profession)
	self.allOrders = {}
	self.orders = {}
	self.ordersProfession = profession
	self.ordersGeneration = self.rebuildGeneration or 0
	self.selectedOrderIDs = self.selectedOrderIDsByProfession[GetProfessionSelectionKey(profession)] or {}
	self.hasUnresolvedItemData = false
	self.unresolvedItemIDs = {}
	self:HideAllRows()
end

function Pane:SetVisibleProfession(profession)
	local previousProfession = self.visibleProfession
	local changed = previousProfession ~= profession
	if changed then
		self.visibleProfession = profession
		self:GetCurrentProfessionSelection()
		ns.Debug(
			"profession",
			"visible changed old=%s new=%s ordersProfession=%s session=%s request=%s/%s/%s flow=%s/%s/%s",
			tostring(previousProfession),
			tostring(profession),
			tostring(self.ordersProfession),
			tostring(self.visibleSessionId),
			tostring(self.activeRequestID),
			tostring(self.activeRequestProfession),
			tostring(self.activeRequestSessionId),
			tostring(self.autoScanFlow and self.autoScanFlow.profession),
			tostring(self.autoScanFlow and self.autoScanFlow.mode),
			tostring(self.autoScanFlow and self.autoScanFlow.sessionKey)
		)
	end

	if self.requesting
		and self.activeRequestProfession
		and self.activeRequestProfession ~= profession then
		ns.Debug(
			"profession",
			"clear stale request id=%s requestProfession=%s newProfession=%s requestSession=%s currentSession=%s",
			tostring(self.activeRequestID),
			tostring(self.activeRequestProfession),
			tostring(profession),
			tostring(self.activeRequestSessionId),
			tostring(self.visibleSessionId)
		)
		self:ClearRequestState()
	end

	if changed and self.root and self.root:IsShown() and self.ordersProfession ~= profession then
		self:ClearVisibleOrders(profession)
	end

	return changed
end

function Pane:BeginVisibleSession()
	if self.autoScanFlow and self.autoScanFlow.sessionInitialized then
		ns.Debug("state", "skip duplicate visible-session during auto-scan profession=%s", tostring(self.autoScanFlow.profession))
		return
	end

	local currentProfession = self:GetCurrentProfessionID()
	if self.requesting and self.activeRequestProfession == currentProfession then
		ns.Debug("state", "skip duplicate visible-session during request profession=%s", tostring(currentProfession))
		return
	end

	self:LoadSavedFilters()
	self:LoadSavedSort()
	self.visibleSessionId = (self.visibleSessionId or 0) + 1
	self.autoQueuedOrderIDsBySession = {}
	self.emptySyncConfirmation = nil
	self.requestSettleUntil = nil
	self.requestReadinessRetryCount = 0
	self.requestFailureRetryCount = 0
	self:SetVisibleProfession(self:GetCurrentProfessionID())
	self:GetCurrentProfessionSelection()
	self:DebugState("visible-session")
end

function Pane:BumpPreparedOrderGeneration()
	self.rebuildGeneration = (self.rebuildGeneration or 0) + 1
end

function Pane:ChoosePendingReason(reason)
	if not reason then
		return
	end

	if not self.pendingReason or GetReasonPriority(reason) >= GetReasonPriority(self.pendingReason) then
		self.pendingReason = reason
	end
end

function Pane:SchedulePendingRefresh(reason, delay)
	if not (self.root and self.root:IsShown()) then
		return
	end

	local dueAt = GetTime() + (delay or GetRefreshDelay(reason))
	if self.needsRebuild and self.requestSettleUntil then
		dueAt = math.max(dueAt, self.requestSettleUntil)
	end

	if not self.pendingDueAt or dueAt < self.pendingDueAt then
		self.pendingDueAt = dueAt
	end

	self:ChoosePendingReason(reason)
	self:UpdateEmptyState()
end

function Pane:ScheduleRequestReadinessRetry(reason)
	if (self.requestReadinessRetryCount or 0) >= REQUEST_READINESS_RETRY_LIMIT then
		ns.Debug("request", "readiness retries exhausted reason=%s", tostring(reason))
		self:DebugState("readiness-exhausted")
		self:UpdateEmptyState()
		return false
	end

	self.requestReadinessRetryCount = (self.requestReadinessRetryCount or 0) + 1
	ns.Debug(
		"request",
		"readiness retry=%s/%s reason=%s",
		tostring(self.requestReadinessRetryCount),
		tostring(REQUEST_READINESS_RETRY_LIMIT),
		tostring(reason)
	)
	self:SchedulePendingRefresh(reason or "show", REQUEST_READINESS_RETRY_DELAY)
	self:UpdateEmptyState()
	return true
end

function Pane:ShouldQueueOpenRequest(profession)
	if not profession then
		return false
	end

	return self.ordersProfession ~= profession
		or not self:HasVisibleOrdersForProfession(profession)
		or not self:HasSuccessfulRequestForVisibleSession(profession)
		or self:HasTimedOutRequestForVisibleSession(profession)
end

function Pane:IsLoadingOrders()
	return not not self.requesting
		or not not self.needsRequest
end

function Pane:UpdateEmptyState()
	if not self.noOrders then
		return
	end

	local hasOrders = #(self.orders or EMPTY_LIST) > 0
	local hasPreparedOrders = #(self.allOrders or EMPTY_LIST) > 0
	local isLoading = not hasOrders and self:IsLoadingOrders()
	local emptyText = EMPTY_STATE_EMPTY_TEXT
	if not isLoading and not hasOrders and hasPreparedOrders and self:HasActiveFilters() then
		emptyText = EMPTY_STATE_FILTERED_TEXT
	end

	self.noOrders:SetText(isLoading and EMPTY_STATE_LOADING_TEXT or emptyText)
	if isLoading then
		self.noOrders:SetTextColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
	else
		self.noOrders:SetTextColor(DISABLED_FONT_COLOR.r, DISABLED_FONT_COLOR.g, DISABLED_FONT_COLOR.b)
	end

	self.noOrders:SetShown(not hasOrders)
end

function Pane:MarkDirty(reason)
	reason = reason or "update"

	local isVisible = self.root and self.root:IsShown()
	local currentProfession = isVisible and self:GetCurrentProfessionID() or self.visibleProfession
	local professionChanged = false
	local configKey = GetConfigKeyFromReason(reason)

	if DoesReasonBumpGeneration(reason) or (reason == "item-data" and self.hasUnresolvedItemData) then
		self:BumpPreparedOrderGeneration()
	end

	if isVisible then
		professionChanged = self:SetVisibleProfession(currentProfession)
	end

	if reason == "sort" or reason == "filter" then
		self.needsRender = true
	elseif reason == "show" or reason == "order-type" or reason == "can-request" or reason == "request-timeout" then
		if currentProfession == nil or self:ShouldQueueOpenRequest(currentProfession) then
			self.needsRequest = true
		end
		if self:NeedsPreparedOrderRebuild(currentProfession) then
			self.needsRebuild = true
		end
	elseif reason == "request-success" or reason == "order-count" or reason == "rewards" or reason == "pricing-db" then
		self.needsRebuild = true
	elseif reason == "item-data" then
		if self.hasUnresolvedItemData then
			self.needsRebuild = true
		end
	elseif reason == "trade-skill-source" then
		if professionChanged or currentProfession == nil or not self:HasSuccessfulRequestForVisibleSession(currentProfession) then
			self.needsRequest = true
		else
			self.needsRebuild = true
		end
	elseif configKey == "pricingSource" then
		self.needsRebuild = true
	elseif configKey == "patronKnowledgeValueGold" or configKey == "patronMoxieValueGold" then
		self.needsRebuild = true
	elseif IsRenderOnlyConfigKey(configKey) then
		self.needsRender = true
	end

	if not isVisible then
		return
	end

	if self.needsRequest or self.needsRebuild or self.needsRender then
		self:SchedulePendingRefresh(reason, GetRefreshDelay(reason))
	else
		self:UpdateEmptyState()
	end
end

function Pane:ClearRequestState(requestID)
	if requestID ~= nil and self.activeRequestID ~= requestID then
		return false
	end

	self.requesting = false
	self.activeRequestID = nil
	self.activeRequestProfession = nil
	self.activeRequestSessionId = nil
	self.activeRequestReason = nil
	self:UpdateEmptyState()
	return true
end

function Pane:StartRequestTimeout(requestID)
	C_Timer.After(REQUEST_TIMEOUT, function()
		if not Pane or Pane.activeRequestID ~= requestID then
			return
		end

		local timedOutProfession = Pane.activeRequestProfession
		local timedOutSessionId = Pane.activeRequestSessionId
		ns.Debug(
			"request",
			"timeout id=%s profession=%s session=%s",
			tostring(requestID),
			tostring(timedOutProfession),
			tostring(timedOutSessionId)
		)
		local professionMatches = timedOutProfession ~= nil
			and timedOutProfession == Pane:GetCurrentProfessionID()
		if timedOutProfession and timedOutSessionId then
			Pane.lastTimedOutRequest = {
				visibleSessionId = timedOutSessionId,
				profession = timedOutProfession,
			}
		end
		Pane:ClearRequestState(requestID)
		if professionMatches and Pane.root and Pane.root:IsShown() then
			Pane:MarkDirty("request-timeout")
		end
	end)
end

function Pane:RequestOrders(reason, profession)
	local now = GetTime()
	local requestID = (self.requestSerial or 0) + 1
	local requestSessionId = self.visibleSessionId
	self.requestSerial = requestID
	self.requestReadinessRetryCount = 0
	self.requesting = true
	self.activeRequestID = requestID
	self.activeRequestProfession = profession
	self.activeRequestSessionId = requestSessionId
	self.activeRequestReason = reason
	ns.Debug(
		"request",
		"start id=%s reason=%s profession=%s session=%s",
		tostring(requestID),
		tostring(reason),
		tostring(profession),
		tostring(requestSessionId)
	)
	self:UpdateEmptyState()
	self.lastRequestAt = now
	self:StartRequestTimeout(requestID)
	local request = {
		profession = profession,
		orderType = ns.ORDER_TYPE_NPC,
		forCrafter = true,
		offset = 0,
		searchFavorites = false,
		initialNonPublicSearch = true,
		primarySort = { sortType = 0, reversed = false },
		secondarySort = { sortType = 0, reversed = false },
	}
	request.callback = function(result, orderType, _, expectMoreRows, responseOffset)
			local currentProfession = self:GetCurrentProfessionID()
			local isActiveRequest = self.activeRequestID == requestID
			local isCurrentSession = requestSessionId == self.visibleSessionId
			local rawCount = #(C_CraftingOrders.GetCrafterOrders() or EMPTY_LIST)
			ns.Debug(
				"request",
				"callback id=%s result=%s type=%s currentProfession=%s active=%s currentSession=%s rootShown=%s raw=%s more=%s offset=%s",
				tostring(requestID),
				tostring(result),
				tostring(orderType),
				tostring(currentProfession),
				tostring(isActiveRequest),
				tostring(isCurrentSession),
				tostring(self.root and self.root:IsShown() or false),
				tostring(rawCount),
				tostring(expectMoreRows),
				tostring(responseOffset)
			)
			local requestSucceeded = result == 0
				and (orderType == nil or orderType == ns.ORDER_TYPE_NPC)
			if requestSucceeded
				and profession == currentProfession
				and self.root
				and self.root:IsShown() then
				self.requestFailureRetryCount = 0
				if expectMoreRows then
					local currentOffset = tonumber(responseOffset) or tonumber(request.offset) or 0
					if rawCount <= currentOffset then
						ns.Debug("request", "pagination stalled id=%s offset=%s raw=%s", tostring(requestID), tostring(currentOffset), tostring(rawCount))
					else
						request.offset = rawCount
						ns.Debug("request", "next-page id=%s offset=%s", tostring(requestID), tostring(request.offset))
						local nextOK, nextError = pcall(C_CraftingOrders.RequestCrafterOrders, request)
						if nextOK then
							return
						end
						ns.Debug("request", "next-page error id=%s error=%s", tostring(requestID), tostring(nextError))
					end
				end
				if self.autoScanFlow
					and self.autoScanFlow.mode == "visible"
					and self.autoScanFlow.profession == profession
				then
					self.autoScanFlow.visibleRequestSucceeded = true
					ns.Debug("auto-scan", "visible request succeeded profession=%s id=%s", tostring(profession), tostring(requestID))
				end
				if isActiveRequest then
					self:ClearRequestState(requestID)
				end
				if isCurrentSession then
					self.lastSuccessfulRequest = {
						visibleSessionId = requestSessionId,
						profession = profession,
					}
					if self:HasTimedOutRequestForVisibleSession(profession) then
						self.lastTimedOutRequest = nil
					end
				end

				self.requestSettleUntil = GetTime() + REQUEST_SETTLE_DELAY
				self:MarkDirty("request-success")
			elseif not requestSucceeded
				and isActiveRequest
				and isCurrentSession
				and profession == currentProfession
				and self.root
				and self.root:IsShown() then
				self:ClearRequestState(requestID)
				self.requestFailureRetryCount = (self.requestFailureRetryCount or 0) + 1
				if self.requestFailureRetryCount <= Pane.retryConfig.requestFailureLimit then
					self.needsRequest = true
					ns.Debug(
						"request",
						"retry after failure=%s/%s result=%s",
						tostring(self.requestFailureRetryCount),
						tostring(Pane.retryConfig.requestFailureLimit),
						tostring(result)
					)
					self:SchedulePendingRefresh("request-failed", Pane.retryConfig.requestFailureDelay)
				else
					ns.Debug("request", "failure retries exhausted result=%s", tostring(result))
					self:DebugState("request-failure-exhausted")
				end
			end
			if self.activeRequestID == requestID then
				self:ClearRequestState(requestID)
			end
			ns.Debug(
				"request",
				"callback decision id=%s success=%s applied=%s active=%s currentSession=%s requestedProfession=%s currentProfession=%s shown=%s",
				tostring(requestID),
				tostring(requestSucceeded),
				tostring(requestSucceeded and profession == currentProfession and self.root and self.root:IsShown() or false),
				tostring(isActiveRequest),
				tostring(isCurrentSession),
				tostring(profession),
				tostring(currentProfession),
				tostring(self.root and self.root:IsShown() or false)
			)
		end
	C_CraftingOrders.RequestCrafterOrders(request)
end

function Pane:FinishHeadlessPatronRefresh(refresh, success, context, message)
	if not refresh or refresh.completed then
		return
	end

	ns.Debug(
		"state",
		"visible-session begin oldSession=%s profession=%s visibleProfession=%s ordersProfession=%s prepared=%s visible=%s",
		tostring(self.visibleSessionId),
		tostring(currentProfession),
		tostring(self.visibleProfession),
		tostring(self.ordersProfession),
		tostring(#(self.allOrders or EMPTY_LIST)),
		tostring(#(self.orders or EMPTY_LIST))
	)

	refresh.completed = true
	if self.headlessPatronRefreshes then
		self.headlessPatronRefreshes[refresh.key] = nil
	end
	if not success then
		context = nil
	end

	ns.Debug(
		"request",
		"headless refresh order=%s profession=%s success=%s message=%s",
		tostring(refresh.orderID),
		tostring(refresh.professionID),
		tostring(success == true),
		tostring(message)
	)

	if success and self.root and self.root:IsShown() then
		self:MarkDirty("headless-refresh")
	end

	for _, callback in ipairs(refresh.callbacks or EMPTY_LIST) do
		local callbackOK, callbackError = pcall(callback, success == true, context, message)
		if not callbackOK then
			ns.Debug("request", "headless refresh callback failed: %s", tostring(callbackError))
		end
	end
end

function Pane:RefreshPatronOrder(orderID, professionID, callback)
	orderID = tonumber(orderID) or 0
	professionID = tonumber(professionID) or self:GetCurrentProfessionID()
	if orderID <= 0 then
		if type(callback) == "function" then
			callback(false, nil, "invalid_order_id")
		end
		return false, "invalid_order_id"
	end
	if not professionID or professionID <= 0 then
		if type(callback) == "function" then
			callback(false, nil, "profession_unavailable")
		end
		return false, "profession_unavailable"
	end
	if self:CanOpenPatronOrders() == false then
		if type(callback) == "function" then
			callback(false, nil, "patron_orders_unavailable")
		end
		return false, "patron_orders_unavailable"
	end
	if type(C_CraftingOrders) ~= "table"
		or type(C_CraftingOrders.RequestCrafterOrders) ~= "function"
		or type(C_CraftingOrders.GetCrafterOrders) ~= "function" then
		if type(callback) == "function" then
			callback(false, nil, "request_unavailable")
		end
		return false, "request_unavailable"
	end
	self.headlessPatronRefreshes = self.headlessPatronRefreshes or {}
	local key = tostring(professionID) .. ":" .. tostring(orderID)
	local activeRefresh = self.headlessPatronRefreshes[key]
	if activeRefresh then
		if type(callback) == "function" then
			activeRefresh.callbacks[#activeRefresh.callbacks + 1] = callback
		end
		return true, "refreshing"
	end

	local canRequest, canRequestReason = self:HasCrafterOrderRequestToken(professionID)
	if not canRequest then
		ns.Debug(
			"request",
			"headless refresh wait order=%s profession=%s reason=%s token=%s/%s",
			tostring(orderID),
			tostring(professionID),
			tostring(canRequestReason),
			tostring(self.craftingOrdersCanRequest),
			tostring(self.craftingOrdersCanRequestProfession)
		)
		if type(callback) == "function" then
			callback(false, nil, "request_not_ready")
		end
		return false, "request_not_ready"
	end

	local refresh = {
		key = key,
		orderID = orderID,
		professionID = professionID,
		callbacks = type(callback) == "function" and { callback } or {},
	}
	self.headlessPatronRefreshes[key] = refresh

	C_Timer.After(REQUEST_TIMEOUT, function()
		if Pane and Pane.headlessPatronRefreshes and Pane.headlessPatronRefreshes[refresh.key] == refresh then
			Pane:FinishHeadlessPatronRefresh(refresh, false, nil, "request_timeout")
		end
	end)

	self:ConsumeCrafterOrderRequestToken(professionID)
	local request = {
		profession = professionID,
		orderType = ns.ORDER_TYPE_NPC,
		forCrafter = true,
		offset = 0,
		searchFavorites = false,
		initialNonPublicSearch = true,
		primarySort = { sortType = 0, reversed = false },
		secondarySort = { sortType = 0, reversed = false },
	}
	request.callback = function(result, orderType, _, expectMoreRows, responseOffset)
			if refresh.completed then
				return
			end
			if result ~= 0 or (orderType ~= nil and orderType ~= ns.ORDER_TYPE_NPC) then
				Pane:FinishHeadlessPatronRefresh(refresh, false, nil, "request_failed")
				return
			end

			-- A claimed patron order is no longer necessarily in GetCrafterOrders().
			-- It remains live and carries the full order payload needed to rebuild
			-- the direct CraftingReagentInfo plan after a craft failure.
			local claimedOrder = type(C_CraftingOrders.GetClaimedOrder) == "function"
				and C_CraftingOrders.GetClaimedOrder()
				or nil
			local liveOrder = claimedOrder and claimedOrder.orderID == refresh.orderID and claimedOrder or nil
			if not liveOrder then
				for _, orderInfo in ipairs(C_CraftingOrders.GetCrafterOrders() or EMPTY_LIST) do
					if orderInfo.orderID == refresh.orderID
						and (orderInfo.orderType == nil or orderInfo.orderType == ns.ORDER_TYPE_NPC) then
						liveOrder = orderInfo
						break
					end
				end
			end
			if not liveOrder then
				if expectMoreRows then
					local rawCount = #(C_CraftingOrders.GetCrafterOrders() or EMPTY_LIST)
					local currentOffset = tonumber(responseOffset) or tonumber(request.offset) or 0
					if rawCount <= currentOffset then
						ns.Debug("request", "headless refresh pagination stalled order=%s offset=%s raw=%s", tostring(orderID), tostring(currentOffset), tostring(rawCount))
						Pane:FinishHeadlessPatronRefresh(refresh, false, nil, "pagination_stalled")
						return
					end
					request.offset = rawCount
					ns.Debug("request", "headless refresh next-page order=%s offset=%s", tostring(orderID), tostring(request.offset))
					local nextOK, nextError = pcall(C_CraftingOrders.RequestCrafterOrders, request)
					if not nextOK then
						ns.Debug("request", "headless refresh next-page error order=%s error=%s", tostring(orderID), tostring(nextError))
						Pane:FinishHeadlessPatronRefresh(refresh, false, nil, "request_failed")
					end
					return
				end
				Pane:FinishHeadlessPatronRefresh(refresh, false, nil, "order_absent")
				return
			end

			local orderData = PrepareOrder(liveOrder)
			if not orderData then
				Pane:FinishHeadlessPatronRefresh(refresh, false, nil, "recipe_unavailable")
				return
			end
			orderData.professionID = refresh.professionID
			local context, contextError = Pane:BuildYayaQueueContext(orderData, true)
			if not context then
				Pane:FinishHeadlessPatronRefresh(refresh, false, nil, contextError or "context_unavailable")
				return
			end

			Pane:FinishHeadlessPatronRefresh(refresh, true, context, nil)
		end
	local requestOK, requestError = pcall(C_CraftingOrders.RequestCrafterOrders, request)
	if not requestOK then
		self:FinishHeadlessPatronRefresh(refresh, false, nil, "request_failed")
		ns.Debug("request", "headless refresh request error=%s", tostring(requestError))
		return false, "request_failed"
	end

	return true, "refreshing"
end

function Pane:MaybeRequestOrders(reason)
	if not self.needsRequest then
		ns.Debug("request", "skip reason=%s needsRequest=false", tostring(reason))
		return false
	end

	local profession = self:GetCurrentProfessionID()
	ns.Debug(
		"request",
		"evaluate reason=%s profession=%s visibleProfession=%s ordersProfession=%s session=%s canRequest=%s/%s active=%s/%s lastAt=%s",
		tostring(reason),
		tostring(profession),
		tostring(self.visibleProfession),
		tostring(self.ordersProfession),
		tostring(self.visibleSessionId),
		tostring(self.craftingOrdersCanRequest),
		tostring(self.craftingOrdersCanRequestProfession),
		tostring(self.activeRequestID),
		tostring(self.activeRequestProfession),
		tostring(self.lastRequestAt)
	)
	if not self:CanOpenPatronOrders() then
		self.needsRequest = false
		self:ClearRequestState()
		ns.Debug("request", "skip profession=%s: patron tab unavailable", tostring(profession))
		return false
	end
	if self.requesting then
		if self.activeRequestProfession == profession then
			ns.Debug("request", "skip active request profession=%s", tostring(profession))
			self.needsRequest = false
		else
			ns.Debug(
				"request",
				"clear stale request activeProfession=%s currentProfession=%s",
				tostring(self.activeRequestProfession),
				tostring(profession)
			)
			self:ClearRequestState()
		end
		return false
	end

	local now = GetTime()
	if self.lastRequestAt and (now - self.lastRequestAt) < REQUEST_COOLDOWN then
		ns.Debug("request", "cooldown profession=%s", tostring(profession))
		self:SchedulePendingRefresh(reason or "request-cooldown", (self.lastRequestAt + REQUEST_COOLDOWN) - now)
		self:UpdateEmptyState()
		return false
	end

	if not profession then
		ns.Debug("request", "profession unavailable")
		self:ScheduleRequestReadinessRetry(reason)
		return false
	end

	if type(C_TradeSkillUI) ~= "table"
		or type(C_TradeSkillUI.IsNearProfessionSpellFocus) ~= "function"
		or not C_TradeSkillUI.IsNearProfessionSpellFocus(profession) then
		ns.Debug("request", "profession focus unavailable profession=%s", tostring(profession))
		self:ScheduleRequestReadinessRetry(reason)
		return false
	end
	local canRequest, canRequestReason = self:HasCrafterOrderRequestToken(profession)
	if not canRequest then
		ns.Debug(
			"request",
			"wait can-request profession=%s reason=%s token=%s/%s",
			tostring(profession),
			tostring(canRequestReason),
			tostring(self.craftingOrdersCanRequest),
			tostring(self.craftingOrdersCanRequestProfession)
		)
		self:ScheduleRequestReadinessRetry(reason or "can-request")
		return false
	end

	self.needsRequest = false
	self:ConsumeCrafterOrderRequestToken(profession)
	self:RequestOrders(reason, profession)
	return true
end

function Pane:RebuildPreparedOrders()
	local currentProfession = self:GetCurrentProfessionID()
	local rawOrders = self:GetVisibleRawOrders()
	local preserveVisibleCache = #rawOrders == 0
		and self:HasVisibleOrdersForProfession(currentProfession)
		and self:IsLoadingOrders()
	ns.Debug(
		"rebuild",
		"start profession=%s visibleProfession=%s ordersProfession=%s raw=%s cached=%s generation=%s/%s loading=%s preserve=%s request=%s/%s",
		tostring(currentProfession),
		tostring(self.visibleProfession),
		tostring(self.ordersProfession),
		tostring(#rawOrders),
		tostring(#(self.allOrders or EMPTY_LIST)),
		tostring(self.ordersGeneration or 0),
		tostring(self.rebuildGeneration or 0),
		tostring(self:IsLoadingOrders()),
		tostring(preserveVisibleCache),
		tostring(self.activeRequestID),
		tostring(self.activeRequestProfession)
	)

	if preserveVisibleCache then
		local hasUnresolvedItemData = false
		local unresolvedItemIDs = {}
		for _, order in ipairs(self.allOrders or self.orders or EMPTY_LIST) do
			if order.hasUnresolvedItemData then
				hasUnresolvedItemData = true
				for itemID in pairs(order.unresolvedItemIDs or EMPTY_LIST) do
					unresolvedItemIDs[itemID] = true
				end
			end
		end

		self.hasUnresolvedItemData = hasUnresolvedItemData
		self.unresolvedItemIDs = unresolvedItemIDs
		self.ordersProfession = currentProfession
		ns.Debug("rebuild", "preserve cache profession=%s prepared=%s", tostring(currentProfession), tostring(#(self.allOrders or EMPTY_LIST)))
		return false
	end

	if not self:IsLoadingOrders() then
		self:SyncYayaQueuePatronOrders(rawOrders, currentProfession)
	end

	local preparedOrders = {}
	local preparedOrderCache = {}
	local hasUnresolvedItemData = false
	local unresolvedItemIDs = {}

	for _, rawOrder in ipairs(rawOrders) do
		local fingerprint = BuildOrderFingerprint(rawOrder)
		local cacheEntry = self.preparedOrderCache[rawOrder.orderID]
		local orderData

		if cacheEntry
			and cacheEntry.fingerprint == fingerprint
			and cacheEntry.generation == self.rebuildGeneration then
			orderData = cacheEntry.data
			hasUnresolvedItemData = hasUnresolvedItemData or not not cacheEntry.hasUnresolvedItemData
		else
			orderData = PrepareOrder(rawOrder)
			hasUnresolvedItemData = hasUnresolvedItemData or not not (orderData and orderData.hasUnresolvedItemData)
		end

		if orderData then
			preparedOrders[#preparedOrders + 1] = orderData
			for itemID in pairs(orderData.unresolvedItemIDs or EMPTY_LIST) do
				unresolvedItemIDs[itemID] = true
			end
			preparedOrderCache[rawOrder.orderID] = {
				fingerprint = fingerprint,
				generation = self.rebuildGeneration,
				data = orderData,
				hasUnresolvedItemData = orderData.hasUnresolvedItemData or false,
			}
		end
	end

	self.preparedOrderCache = preparedOrderCache
	self.allOrders = preparedOrders
	if self.autoScanFlow
		and self.autoScanFlow.mode == "visible"
		and self.autoScanFlow.profession == currentProfession
	then
		local candidateCount, addedCount, firstError = self:QueueAutoQueueablePatronOrders()
		self.autoScanFlow.visibleQueueProcessed = candidateCount == addedCount
		ns.Debug(
			"auto-scan",
			"visible queue processed profession=%s prepared=%s candidates=%s added=%s error=%s success=%s",
			tostring(currentProfession),
			tostring(#preparedOrders),
			tostring(candidateCount),
			tostring(addedCount),
			tostring(firstError),
			tostring(self.autoScanFlow.visibleQueueProcessed)
		)
	else
		self:MaybeAutoQueuePatronOrders()
	end
	self:ApplyOrderFilters()
	self.ordersProfession = currentProfession
	self.ordersGeneration = self.rebuildGeneration
	self.hasUnresolvedItemData = hasUnresolvedItemData
	self.unresolvedItemIDs = unresolvedItemIDs
	self:PruneSelectedOrders()
	ns.Debug(
		"rebuild",
		"profession=%s raw=%s prepared=%s visible=%s unresolved=%s",
		tostring(currentProfession),
		tostring(#rawOrders),
		tostring(#preparedOrders),
		tostring(#(self.orders or EMPTY_LIST)),
		tostring(hasUnresolvedItemData)
	)
	return true
end

function Pane:ProcessPendingRefresh()
	if not (self.root and self.root:IsShown()) then
		return
	end

	local reason = self.pendingReason or "update"
	ns.Debug(
		"refresh",
		"start reason=%s profession=%s visibleProfession=%s ordersProfession=%s session=%s needs=%s/%s/%s request=%s/%s",
		tostring(reason),
		tostring(self:GetCurrentProfessionID()),
		tostring(self.visibleProfession),
		tostring(self.ordersProfession),
		tostring(self.visibleSessionId),
		tostring(self.needsRequest == true),
		tostring(self.needsRebuild == true),
		tostring(self.needsRender == true),
		tostring(self.activeRequestID),
		tostring(self.activeRequestProfession)
	)
	self.pendingReason = nil
	self:SetVisibleProfession(self:GetCurrentProfessionID())
	self:MaybeRequestOrders(reason)

	if self.needsRebuild then
		self.needsRebuild = false
		if self:RebuildPreparedOrders() then
			self.needsRender = true
		end
	end

	if self.needsRender then
		self.needsRender = false
		self:ApplyOrderFilters()
		self:SortPreparedOrders()
		self:RenderRows()
	else
		self:UpdateEmptyState()
		self:UpdateHeaderArrow()
		self:UpdateToolbar()
	end

	if self.requestSettleUntil and GetTime() >= self.requestSettleUntil then
		self.requestSettleUntil = nil
	end
	ns.Debug(
		"refresh",
		"end reason=%s profession=%s ordersProfession=%s needs=%s/%s/%s pending=%s prepared=%s visible=%s request=%s/%s",
		tostring(reason),
		tostring(self:GetCurrentProfessionID()),
		tostring(self.ordersProfession),
		tostring(self.needsRequest == true),
		tostring(self.needsRebuild == true),
		tostring(self.needsRender == true),
		tostring(self.pendingReason),
		tostring(#(self.allOrders or EMPTY_LIST)),
		tostring(#(self.orders or EMPTY_LIST)),
		tostring(self.activeRequestID),
		tostring(self.activeRequestProfession)
	)
end

function Pane:SetCustomPaneShown(isShown)
	if not self.root then
		return
	end

	if isShown then
		self:ApplyReferenceLayout()
	else
		if self.filterPanel then
			self.filterPanel:Hide()
		end
		if self.selectPanel then
			self.selectPanel:Hide()
		end
		self:ClearRequestState()
		self.pendingReason = nil
		self.pendingDueAt = nil
		self.needsRequest = false
		self.needsRebuild = false
		self.needsRender = false
		self.requestSettleUntil = nil
		self.emptySyncConfirmation = nil
		self.requestReadinessRetryCount = 0
		self.trailingDirtyTokens = nil
	end

	if isShown then
		self:UpdateEmptyState()
		self:UpdateToolbar()
	elseif self.nextOrderButton then
		self.nextOrderButton:Hide()
	end
	self.root:SetShown(isShown)
	local browseFrame = ProfessionsFrame.OrdersPage.BrowseFrame
	if browseFrame.OrderList then
		browseFrame.OrderList:SetShown(not isShown)
	end
	if browseFrame.SearchButton then
		browseFrame.SearchButton:SetShown(not isShown)
	end
	if browseFrame.FavoritesSearchButton then
		browseFrame.FavoritesSearchButton:SetShown(not isShown)
	end
end

local function IsOrderTypeButtonSelected(button)
	if not button then
		return false
	end

	if type(button.IsSelected) == "function" then
		local ok, selected = pcall(button.IsSelected, button)
		if ok and selected ~= nil then
			return not not selected
		end
	end

	if button.Selected and type(button.Selected.IsShown) == "function" and button.Selected:IsShown() then
		return true
	end

	if type(button.GetButtonState) == "function" then
		local ok, state = pcall(button.GetButtonState, button)
		if ok and state == "PUSHED" then
			return true
		end
	end

	return false
end

function Pane:GetCurrentOrderType()
	local ordersPage = ProfessionsFrame and ProfessionsFrame.OrdersPage
	if not ordersPage then
		return nil
	end

	for _, methodName in ipairs({
		"GetCraftingOrderType",
		"GetCurrentOrderType",
		"GetOrderType",
	}) do
		local method = ordersPage[methodName]
		if type(method) == "function" then
			local ok, orderType = pcall(method, ordersPage)
			if ok and type(orderType) == "number" then
				return orderType
			end
		end
	end

	for _, fieldName in ipairs({
		"orderType",
		"craftingOrderType",
		"selectedOrderType",
		"selectedCraftingOrderType",
	}) do
		local orderType = ordersPage[fieldName]
		if type(orderType) == "number" then
			return orderType
		end
	end

	for _, candidate in ipairs({
		{ "NpcOrdersButton", ns.ORDER_TYPE_NPC },
		{ "PatronOrdersButton", ns.ORDER_TYPE_NPC },
		{ "PublicOrdersButton", Enum.CraftingOrderType and Enum.CraftingOrderType.Public or 0 },
		{ "GuildOrdersButton", Enum.CraftingOrderType and Enum.CraftingOrderType.Guild or 1 },
		{ "PersonalOrdersButton", Enum.CraftingOrderType and Enum.CraftingOrderType.Personal or 2 },
	}) do
		local button = ordersPage[candidate[1]]
		if IsOrderTypeButtonSelected(button) then
			return candidate[2]
		end
	end

	return nil
end

function Pane:SyncCurrentOrderType(reason)
	local orderType = self:GetCurrentOrderType()
	ns.Debug("ui", "sync order type reason=%s type=%s", tostring(reason), tostring(orderType))
	if orderType == nil then
		self:ScheduleOrderTypeSyncRetry(reason)
		return
	end

	self.orderTypeSyncRetryCount = 0
	local showCustomPane = orderType == ns.ORDER_TYPE_NPC
	self:SetCustomPaneShown(showCustomPane)
	if showCustomPane then
		self:MarkDirty(reason or "order-type")
	end
end

function Pane:ScheduleOrderTypeSyncRetry(reason)
	local ordersPage = ProfessionsFrame and ProfessionsFrame.OrdersPage
	if self.orderTypeSyncRetryQueued or not (ordersPage and ordersPage:IsShown()) then
		return false
	end
	if (self.orderTypeSyncRetryCount or 0) >= Pane.retryConfig.orderTypeLimit then
		ns.Debug("ui", "order type retries exhausted reason=%s", tostring(reason))
		self:DebugState("order-type-exhausted")
		return false
	end

	self.orderTypeSyncRetryCount = (self.orderTypeSyncRetryCount or 0) + 1
	self.orderTypeSyncRetryQueued = true
	ns.Debug(
		"ui",
		"order type retry=%s/%s reason=%s",
		tostring(self.orderTypeSyncRetryCount),
		tostring(Pane.retryConfig.orderTypeLimit),
		tostring(reason)
	)
	C_Timer.After(Pane.retryConfig.orderTypeDelay, function()
		if not Pane then
			return
		end
		Pane.orderTypeSyncRetryQueued = nil
		Pane:SyncCurrentOrderType(reason or "order-type-retry")
	end)
	return true
end

function Pane:InitializeHooks()
	local ordersPage = ProfessionsFrame and ProfessionsFrame.OrdersPage
	if not ordersPage then
		return false
	end

	if type(ordersPage.SetCraftingOrderType) == "function" and not self.orderTypeHooked then
		self.orderTypeHooked = true
		hooksecurefunc(ordersPage, "SetCraftingOrderType", function(_, orderType)
			ns.Debug("ui", "SetCraftingOrderType type=%s", tostring(orderType))
			Pane.orderTypeSyncRetryCount = 0
			local showCustomPane = orderType == ns.ORDER_TYPE_NPC
			Pane:SetCustomPaneShown(showCustomPane)
			if showCustomPane then
				Pane:MarkDirty("order-type")
			end
		end)
	end

	if not self.ordersPageShowHooked then
		self.ordersPageShowHooked = true
		ordersPage:HookScript("OnShow", function()
			ns.Debug("ui", "orders page OnShow")
			Pane:SyncCurrentOrderType("show")
			C_Timer.After(0, function()
				if Pane then
					Pane:SyncCurrentOrderType("show-deferred")
					Pane:RepositionOrderActionButtons()
					Pane:UpdateNextOrderButton()
				end
			end)
		end)
	end

	local craftingOrdersTab = ProfessionsFrame
		and ProfessionsFrame.TabSystem
		and ProfessionsFrame.TabSystem.tabs
		and ProfessionsFrame.TabSystem.tabs[(ProfessionsFrame.craftingOrdersTabID or 3)]
	if craftingOrdersTab and not self.craftingOrdersTabHooked then
		self.craftingOrdersTabHooked = true
		craftingOrdersTab:HookScript("OnClick", function()
			ns.Debug("ui", "crafting orders tab clicked")
			C_Timer.After(0, function()
				if Pane then
					Pane:SyncCurrentOrderType("orders-tab-click")
				end
			end)
		end)
	end

	local craftingPage = ProfessionsFrame and ProfessionsFrame.CraftingPage
	if craftingPage and not self.craftingPageShowHooked then
		self.craftingPageShowHooked = true
		craftingPage:HookScript("OnShow", function()
			C_Timer.After(0, function()
				if not Pane or Pane.autoScanFlow then
					return
				end
				Pane:MaybeStartPatronAutoScan("crafting-page-show")
			end)
		end)
	end

	local orderView = ordersPage.OrderView
	if orderView and type(orderView.SetOrder) == "function" and not self.orderViewSetOrderHooked then
		self.orderViewSetOrderHooked = true
		hooksecurefunc(orderView, "SetOrder", function(_, order)
			Pane:RefreshDetailWarningOrderData(order)
			Pane:ScheduleDetailWarningUpdate(0)
			C_Timer.After(0, function()
				if Pane then
					Pane:RepositionOrderActionButtons()
					Pane:UpdateNextOrderButton()
				end
			end)
			if Pane.pendingOpenPlan and order and order.orderID == Pane.pendingOpenPlan.orderID then
				Pane:SchedulePendingOrderPlan(0)
			end
		end)
	end

	self:EnsureDetailWarningHooks()

	return true
end

function Pane:ScheduleTrailingDirty(reason, delay)
	self.trailingDirtyTokens = self.trailingDirtyTokens or {}
	local token = (self.trailingDirtyTokens[reason] or 0) + 1
	self.trailingDirtyTokens[reason] = token

	C_Timer.After(delay or 0, function()
		if not Pane or not Pane.trailingDirtyTokens or Pane.trailingDirtyTokens[reason] ~= token then
			return
		end

		Pane.trailingDirtyTokens[reason] = nil
		Pane:MarkDirty(reason)
	end)
end

function Pane:InitializeEvents()
	if self.eventsInitialized then
		return
	end

	self.eventsInitialized = true
	ns.RegisterEvent("CRAFTINGORDERS_UPDATE_ORDER_COUNT", function(_, orderType, count)
		ns.Debug("event", "CRAFTINGORDERS_UPDATE_ORDER_COUNT type=%s count=%s", tostring(orderType), tostring(count))
		if orderType == ns.ORDER_TYPE_NPC then
			Pane:MarkDirty("order-count")
		end
	end)

	ns.RegisterEvent("CRAFTINGORDERS_CAN_REQUEST", function()
		local snapshot = Pane:GetProfessionSnapshot()
		local flow = Pane.autoScanFlow
		-- Le metier du flux en cours est la seule valeur fiable : snapshot.selected
		-- retarde d'une ouverture. On le prefere meme quand une requete est en vol.
		local tokenProfession = (flow and flow.profession)
			or snapshot.selected
			or Pane.visibleProfession
		ns.Debug(
			"event",
			"CRAFTINGORDERS_CAN_REQUEST previous=%s/%s tokenProfession=%s selected=%s child=%s base=%s orders=%s flow=%s/%s/%s/%s requesting=%s requestID=%s",
			tostring(Pane.craftingOrdersCanRequest),
			tostring(Pane.craftingOrdersCanRequestProfession),
			tostring(tokenProfession),
			tostring(snapshot.selected),
			tostring(snapshot.child),
			tostring(snapshot.base),
			tostring(snapshot.ordersPage),
			tostring(flow and flow.profession),
			tostring(flow and flow.mode),
			tostring(flow and flow.stage),
			tostring(flow and flow.sessionKey),
			tostring(flow and flow.requesting == true),
			tostring(flow and flow.requestID)
		)
		Pane.craftingOrdersCanRequest = true
		Pane.craftingOrdersCanRequestProfession = tonumber(tokenProfession)
		-- Une requete en vol emise sans autorisation ne recevra jamais de
		-- callback : ce token est precisement la reponse du serveur. On l'abandonne
		-- et on reemet tout de suite, au lieu d'attendre le timeout de 10 s puis
		-- de retomber sur le flux visible.
		if flow and flow.mode == "headless" and flow.requesting and not flow.requestGranted then
			ns.Debug(
				"headless",
				"reissue after can-request profession=%s deadRequestID=%s",
				tostring(flow.profession),
				tostring(flow.requestID)
			)
			flow.requesting = nil
			-- Nouvel identifiant : neutralise le timer de timeout et le callback
			-- de la requete abandonnee, tous deux gardes par requestID.
			Pane.headlessRequestSerial = (Pane.headlessRequestSerial or 0) + 1
			flow.requestID = Pane.headlessRequestSerial
			Pane:SchedulePatronAutoScanStep(flow, 0)
		elseif flow and flow.mode == "headless" and not flow.requesting then
			Pane:SchedulePatronAutoScanStep(flow, 0)
		else
			Pane:MaybeStartPatronAutoScan("can-request")
		end
		Pane:MarkDirty("can-request")
	end)

	ns.RegisterEvent("CRAFTINGORDERS_UPDATE_REWARDS", function()
		Pane:MarkDirty("rewards")
	end)

	ns.RegisterEvent("ITEM_DATA_LOAD_RESULT", function(_, itemID)
		if type(itemID) ~= "number" then
			return
		end
		local isTrackedListItem = Pane.unresolvedItemIDs and Pane.unresolvedItemIDs[itemID]
		local isTrackedDetailItem = Pane.detailWarningOrderData
			and Pane.detailWarningOrderData.unresolvedItemIDs
			and Pane.detailWarningOrderData.unresolvedItemIDs[itemID]
		if not isTrackedListItem and not isTrackedDetailItem then
			return
		end
		if Pane.root and Pane.root:IsShown() and isTrackedListItem then
			Pane:ScheduleTrailingDirty("item-data", ITEM_DATA_REFRESH_DELAY)
		end
		if isTrackedDetailItem then
			Pane:MarkDetailWarningDirty()
		end
	end)

	ns.RegisterEvent("TRADE_SKILL_DATA_SOURCE_CHANGED", function()
		Pane.knowledgeProgressCache = {}
		local snapshot = Pane:GetProfessionSnapshot()
		ns.Debug(
			"event",
			"TRADE_SKILL_DATA_SOURCE_CHANGED selected=%s child=%s base=%s orders=%s",
			tostring(snapshot.selected),
			tostring(snapshot.child),
			tostring(snapshot.base),
			tostring(snapshot.ordersPage)
		)
		Pane:MarkDirty("trade-skill-source")
		Pane:MarkDetailWarningDirty()
		C_Timer.After(0, function()
			if Pane then
				Pane:MaybeStartPatronAutoScan("trade-skill-source")
			end
		end)
	end)

	ns.RegisterEvent("TRAIT_CONFIG_UPDATED", function()
		Pane.knowledgeProgressCache = {}
		Pane:MarkDirty("trade-skill-source")
	end)

	ns.RegisterEvent("TRAIT_TREE_CURRENCY_INFO_UPDATED", function()
		Pane.knowledgeProgressCache = {}
		Pane:MarkDirty("trade-skill-source")
	end)

	ns.RegisterEvent("TRADE_SKILL_SHOW", function()
		Pane.autoScanOpeningRequested = true
		Pane.autoScanStartAttempts = 0
		C_Timer.After(0, function()
			if Pane then
				local snapshot = Pane:GetProfessionSnapshot()
				ns.Debug(
					"event",
					"TRADE_SKILL_SHOW selected=%s child=%s base=%s orders=%s focus=%s",
					tostring(snapshot.selected),
					tostring(snapshot.child),
					tostring(snapshot.base),
					tostring(snapshot.ordersPage),
					tostring(Pane:IsNearProfessionFocus(snapshot.selected))
				)
				Pane:MaybeStartPatronAutoScan("trade-skill-show")
				local canOpenPatronOrders = Pane:CanOpenPatronOrders()
				ns.Debug("event", "TRADE_SKILL_SHOW patron-tab-available=%s flow=%s", tostring(canOpenPatronOrders), tostring(Pane.autoScanFlow ~= nil))
				if canOpenPatronOrders and not Pane.autoScanFlow then
					local queueApi = Pane:GetYayaQueueAPI()
					if queueApi and type(queueApi.QueueFavoriteConcentration) == "function" then
						local favoriteOK, favoriteMessage = queueApi.QueueFavoriteConcentration(snapshot.selected)
						ns.Debug("event", "TRADE_SKILL_SHOW favorite profession=%s ok=%s message=%s", tostring(snapshot.selected), tostring(favoriteOK), tostring(favoriteMessage))
					end
				end
			end
		end)
	end)

	ns.RegisterEvent("TRADE_SKILL_CLOSE", function()
		local immediateSnapshot = Pane:GetProfessionSnapshot()
		local immediateFlow = Pane.autoScanFlow
		ns.Debug(
			"event",
			"TRADE_SKILL_CLOSE immediate selected=%s child=%s base=%s orders=%s frame=%s flow=%s/%s/%s/%s",
			tostring(immediateSnapshot.selected),
			tostring(immediateSnapshot.child),
			tostring(immediateSnapshot.base),
			tostring(immediateSnapshot.ordersPage),
			tostring(ProfessionsFrame and ProfessionsFrame:IsShown() or false),
			tostring(immediateFlow and immediateFlow.profession),
			tostring(immediateFlow and immediateFlow.mode),
			tostring(immediateFlow and immediateFlow.stage),
			tostring(immediateFlow and immediateFlow.sessionKey)
		)
		C_Timer.After(0, function()
			local flow = Pane and Pane.autoScanFlow
			local snapshot = Pane and Pane:GetProfessionSnapshot()
			local currentProfession = snapshot and snapshot.selected
			local professionFrameShown = ProfessionsFrame and ProfessionsFrame:IsShown()
			ns.Debug(
				"event",
				"TRADE_SKILL_CLOSE deferred before selected=%s child=%s base=%s orders=%s frame=%s captured=%s/%s/%s/%s",
				tostring(currentProfession),
				tostring(snapshot and snapshot.child),
				tostring(snapshot and snapshot.base),
				tostring(snapshot and snapshot.ordersPage),
				tostring(professionFrameShown),
				tostring(flow and flow.profession),
				tostring(flow and flow.mode),
				tostring(flow and flow.stage),
				tostring(flow and flow.sessionKey)
			)
			if Pane and professionFrameShown then
				Pane.autoScanOpeningRequested = true
				Pane.autoScanStartAttempts = 0
				Pane:MaybeStartPatronAutoScan("trade-skill-close-switch")
			elseif Pane then
				Pane.autoScanOpeningRequested = false
				Pane.autoScanStartAttempts = 0
				Pane.autoScanOpeningProfession = nil
			end
			local activeFlow = Pane and Pane.autoScanFlow
			ns.Debug(
				"event",
				"TRADE_SKILL_CLOSE deferred after-start capturedIsActive=%s active=%s/%s/%s/%s",
				tostring(flow ~= nil and flow == activeFlow),
				tostring(activeFlow and activeFlow.profession),
				tostring(activeFlow and activeFlow.mode),
				tostring(activeFlow and activeFlow.stage),
				tostring(activeFlow and activeFlow.sessionKey)
			)
			if flow and (not professionFrameShown or (currentProfession and currentProfession ~= flow.profession)) then
				ns.Debug(
					"auto-scan",
					"cancelled on profession close captured=%s/%s/%s active=%s/%s same=%s current=%s child=%s base=%s orders=%s frame=%s",
					tostring(flow.profession),
					tostring(flow.mode),
					tostring(flow.sessionKey),
					tostring(activeFlow and activeFlow.profession),
					tostring(activeFlow and activeFlow.sessionKey),
					tostring(flow == activeFlow),
					tostring(currentProfession),
					tostring(snapshot and snapshot.child),
					tostring(snapshot and snapshot.base),
					tostring(snapshot and snapshot.ordersPage),
					tostring(professionFrameShown)
				)
				Pane.autoScanFlow = nil
			end
		end)
	end)
end

function Pane:ScheduleInitializeRetry()
	if self.initializeRetryQueued then
		return
	end

	self.initializeRetryQueued = true
	C_Timer.After(INITIALIZE_RETRY_DELAY, function()
		if Pane then
			Pane.initializeRetryQueued = nil
		end
		if Pane and not Pane.initialized then
			Pane:Initialize()
		end
	end)
end

function Pane:Initialize()
	if self.initialized then
		return
	end

	self:LoadSavedFilters()
	self:LoadSavedSort()

	if not self:BuildFrame() then
		self:ScheduleInitializeRetry()
		return
	end

	if not self:InitializeHooks() then
		self:ScheduleInitializeRetry()
		return
	end

	self.initializeRetryQueued = nil
	self.initialized = true
	self:InitializeEvents()
	self:UpdateToolbar()
	C_Timer.After(0, function()
		if Pane and Pane.initialized then
			Pane:SyncCurrentOrderType("initial-state")
			Pane:ScheduleDetailWarningUpdate(0)
		end
	end)
end

YayaCraftingOrdersAPI = YayaCraftingOrdersAPI or {}

function YayaCraftingOrdersAPI.CanOpenPatronOrders()
	return Pane:CanOpenPatronOrders()
end

function YayaCraftingOrdersAPI.ViewOrderByID(orderID)
	orderID = tonumber(orderID) or 0
	if orderID <= 0 then
		return false, "orderID invalide"
	end

	local ordersPage = ProfessionsFrame and ProfessionsFrame.OrdersPage
	if not Pane:IsProfessionPageVisible(ordersPage) then
		return false, "onglet commandes indisponible"
	end
	local currentOrderType = Pane:GetCurrentOrderType()
	if currentOrderType and currentOrderType ~= ns.ORDER_TYPE_NPC then
		Pane:SelectPatronOrderType(ordersPage)
		return false, "onglet patrons en cours d'ouverture"
	end

	for _, order in ipairs(Pane.allOrders or EMPTY_LIST) do
		if order and order.orderID == orderID then
			Pane:ViewOrder(order)
			return true
		end
	end

	local liveOrder = Pane:FindLiveOrderInfo(orderID)
	if liveOrder then
		ns.Debug("open", "resolve live order=%s outside filtered list", tostring(orderID))
		Pane:ViewOrder(liveOrder)
		return true
	end

	return false, "order introuvable"
end

function YayaCraftingOrdersAPI.GetCurrentOrderID()
	local _, order = Pane:GetCurrentOrderViewContext()
	return order and order.orderID or nil
end

function YayaCraftingOrdersAPI.RefreshPatronOrder(orderID, professionID, callback)
	return Pane:RefreshPatronOrder(orderID, professionID, callback)
end
