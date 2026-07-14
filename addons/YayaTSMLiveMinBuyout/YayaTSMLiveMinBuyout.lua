local addonName = ...

local eventFrame = CreateFrame("Frame")
local liveMinBuyoutByItemString = {}
local pendingSearchByKey = {}
local patchState = {
    applied = false,
    customString = nil,
    originalCallback = nil,
    itemStringApi = nil,
    itemStringModule = nil,
}

local function GetUpvalueByName(func, targetName)
    if type(debug) ~= "table" or type(debug.getupvalue) ~= "function" then
        return nil
    end

    local index = 1
    while true do
        local name, value = debug.getupvalue(func, index)
        if not name then
            return nil
        end
        if name == targetName then
            return value
        end
        index = index + 1
    end
end

local function GetItemKeyToken(itemKey)
    if type(itemKey) ~= "table" or not itemKey.itemID then
        return nil
    end

    return table.concat({
        tostring(itemKey.itemID or 0),
        tostring(itemKey.itemLevel or 0),
        tostring(itemKey.itemSuffix or 0),
        tostring(itemKey.battlePetSpeciesID or 0),
    }, ":")
end

local function NormalizeItemStrings(itemString)
    local itemStrings = {}
    if not itemString or itemString == "" then
        return itemStrings
    end

    itemStrings[itemString] = true

    local itemStringModule = patchState.itemStringModule
    if itemStringModule and type(itemStringModule.GetBaseFast) == "function" then
        local baseItemString = itemStringModule.GetBaseFast(itemString)
        if baseItemString and baseItemString ~= "" then
            itemStrings[baseItemString] = true
        end
    end

    return itemStrings
end

local function InvalidateDBMinBuyout()
    if patchState.customString and type(patchState.customString.InvalidateCache) == "function" then
        patchState.customString.InvalidateCache("DBMinBuyout")
    end
end

local function GetItemSearchMinBuyout(itemKey)
    if type(itemKey) ~= "table" or not C_AuctionHouse or not C_AuctionHouse.GetNumItemSearchResults then
        return nil
    end

    local numResults = C_AuctionHouse.GetNumItemSearchResults(itemKey) or 0
    local minBuyout = nil
    for index = 1, numResults do
        local info = C_AuctionHouse.GetItemSearchResultInfo(itemKey, index)
        local quantity = info and info.quantity or 0
        local buyoutAmount = info and info.buyoutAmount or 0
        if quantity > 0 and buyoutAmount and buyoutAmount > 0 then
            local unitBuyout = math.floor(buyoutAmount / quantity)
            if unitBuyout > 0 and (not minBuyout or unitBuyout < minBuyout) then
                minBuyout = unitBuyout
            end
        end
    end

    return minBuyout
end

local function GetCommoditySearchMinBuyout(itemID)
    if type(itemID) ~= "number" or not C_AuctionHouse or not C_AuctionHouse.GetNumCommoditySearchResults then
        return nil
    end

    local numResults = C_AuctionHouse.GetNumCommoditySearchResults(itemID) or 0
    local minBuyout = nil
    for index = 1, numResults do
        local info = C_AuctionHouse.GetCommoditySearchResultInfo(itemID, index)
        local unitPrice = info and info.unitPrice or 0
        if unitPrice and unitPrice > 0 and (not minBuyout or unitPrice < minBuyout) then
            minBuyout = unitPrice
        end
    end

    return minBuyout
end

local function StoreLiveMinBuyout(itemString, minBuyout)
    if not itemString or not minBuyout or minBuyout <= 0 then
        return
    end

    local changed = false
    for normalizedItemString in pairs(NormalizeItemStrings(itemString)) do
        if liveMinBuyoutByItemString[normalizedItemString] ~= minBuyout then
            liveMinBuyoutByItemString[normalizedItemString] = minBuyout
            changed = true
        end
    end
    if changed then
        InvalidateDBMinBuyout()
    end
end

local function HandleCommodityResults(_, itemID)
    local pending = pendingSearchByKey["commodity:" .. tostring(itemID)]
    if not pending then
        return
    end

    local minBuyout = GetCommoditySearchMinBuyout(itemID)
    if not minBuyout then
        return
    end

    StoreLiveMinBuyout(pending.itemString, minBuyout)
end

local function HandleItemResults(_, itemKey)
    local pending = pendingSearchByKey["item:" .. tostring(GetItemKeyToken(itemKey))]
    if not pending then
        return
    end

    local minBuyout = GetItemSearchMinBuyout(itemKey)
    if not minBuyout then
        return
    end

    StoreLiveMinBuyout(pending.itemString, minBuyout)
end

local function TrackSearch(itemKey)
    if type(itemKey) ~= "table" or not patchState.itemStringApi then
        return
    end

    local itemString = patchState.itemStringApi("i:" .. tostring(itemKey.itemID or 0))
    if not itemString then
        return
    end

    pendingSearchByKey["commodity:" .. tostring(itemKey.itemID)] = {
        itemString = itemString,
    }

    local token = GetItemKeyToken(itemKey)
    if token then
        pendingSearchByKey["item:" .. token] = {
            itemString = itemString,
        }
    end
end

local function RegisterSearchHooks()
    if not hooksecurefunc or not C_AuctionHouse then
        return
    end

    hooksecurefunc(C_AuctionHouse, "SendSearchQuery", function(itemKey)
        TrackSearch(itemKey)
    end)
    hooksecurefunc(C_AuctionHouse, "SendSellSearchQuery", function(itemKey)
        TrackSearch(itemKey)
    end)
end

local function TryApplyPatch()
    if patchState.applied or type(TSM_API) ~= "table" then
        return patchState.applied
    end

    local customString = GetUpvalueByName(TSM_API.GetPriceSourceKeys, "CustomString")
    local itemStringModule = GetUpvalueByName(TSM_API.ToItemString, "ItemString")
    if not customString or not itemStringModule then
        return false
    end

    local sourcesModule = GetUpvalueByName(customString.GetSourceValue, "Sources")
    local sourcesPrivate = sourcesModule and GetUpvalueByName(sourcesModule.GetValue, "private")
    local sourceInfo = sourcesPrivate and sourcesPrivate.info and sourcesPrivate.info.dbminbuyout or nil
    if not sourceInfo or type(sourceInfo.callback) ~= "function" then
        return false
    end

    patchState.customString = customString
    patchState.itemStringApi = TSM_API.ToItemString
    patchState.itemStringModule = itemStringModule
    patchState.originalCallback = sourceInfo.callback

    customString.RegisterSource(
        addonName,
        "DBMinBuyout",
        sourceInfo.label,
        function(itemString)
            local liveValue = liveMinBuyoutByItemString[itemString]
            if liveValue and liveValue > 0 then
                return liveValue
            end

            if patchState.itemStringModule and type(patchState.itemStringModule.GetBaseFast) == "function" then
                local baseItemString = patchState.itemStringModule.GetBaseFast(itemString)
                liveValue = baseItemString and liveMinBuyoutByItemString[baseItemString] or nil
                if liveValue and liveValue > 0 then
                    return liveValue
                end
            end

            return patchState.originalCallback(itemString)
        end,
        customString.SOURCE_TYPE.PRICE_DB
    )

    patchState.applied = true
    RegisterSearchHooks()
    eventFrame:RegisterEvent("COMMODITY_SEARCH_RESULTS_UPDATED")
    eventFrame:RegisterEvent("ITEM_SEARCH_RESULTS_UPDATED")
    return true
end

local function OnEvent(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == "TradeSkillMaster" or arg1 == addonName then
            TryApplyPatch()
        end
        return
    end

    if not patchState.applied and not TryApplyPatch() then
        return
    end

    if event == "COMMODITY_SEARCH_RESULTS_UPDATED" then
        HandleCommodityResults(event, arg1)
    elseif event == "ITEM_SEARCH_RESULTS_UPDATED" then
        HandleItemResults(event, arg1)
    elseif event == "PLAYER_LOGIN" then
        TryApplyPatch()
    end
end

eventFrame:SetScript("OnEvent", OnEvent)
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
