local addonName = ...

local API = _G.YayaContainerValuesAPI or {}
_G.YayaContainerValuesAPI = API

local PRICE_SOURCES = {
    "dbmarket",
    "dbregionmarketavg",
    "dbhistorical",
    "dbregionhistorical",
    "dbregionsaleavg",
}
local IGNORED_CONTAINER_ITEM_IDS = {
    [38682] = true, -- Enchanting Vellum
    [246320] = true, -- Flicker of Midnight Alchemy Knowledge
}
local FINALIZE_DELAY = 1.25
local LOOT_FINALIZE_DELAY = 0.25
local pendingOpens = {}
local initialized = false
local tooltipHooksInstalled = false
local invalidEntriesCleaned = false
local lastBagSnapshot
local lastBagSlots

local function Print(message)
    DEFAULT_CHAT_FRAME:AddMessage(("|cff4cc9f0YayaContainerValues|r: %s"):format(tostring(message)))
end

local function Now()
    return time and time() or 0
end

local function GetDB()
    YayaContainerValuesDB = type(YayaContainerValuesDB) == "table" and YayaContainerValuesDB or {}
    YayaContainerValuesDB.version = 3
    YayaContainerValuesDB.containers = type(YayaContainerValuesDB.containers) == "table"
        and YayaContainerValuesDB.containers
        or {}
    return YayaContainerValuesDB
end

local function GetItemInfoInstantData(itemID)
    if C_Item and type(C_Item.GetItemInfoInstant) == "function" then
        local ok, _, itemType, _, _, _, classID = pcall(C_Item.GetItemInfoInstant, itemID)
        if ok then
            return itemType, classID
        end
    end
    if type(GetItemInfoInstant) == "function" then
        local ok, _, itemType, _, _, _, classID = pcall(GetItemInfoInstant, itemID)
        if ok then
            return itemType, classID
        end
    end
end

local function IsContainerItem(itemID)
    if IGNORED_CONTAINER_ITEM_IDS[itemID] then
        return false
    end

    local itemType, classID = GetItemInfoInstantData(itemID)
    local recipeClassID = Enum and Enum.ItemClass and Enum.ItemClass.Recipe or LE_ITEM_CLASS_RECIPE or 9
    if itemType == "Recipe" or itemType == "Armor" or itemType == "Weapon"
        or classID == recipeClassID or classID == 2 or classID == 4 then
        return false
    end
    return true
end

local function IsRecipeItem(itemID)
    local itemType, classID = GetItemInfoInstantData(itemID)
    if itemType == "Recipe" then
        return true
    end
    if classID == nil or classID == 0 then
        return false
    end
    local recipeClassID = Enum and Enum.ItemClass and Enum.ItemClass.Recipe or LE_ITEM_CLASS_RECIPE or 9
    return classID == recipeClassID
end

local function NormalizeItemID(item)
    if type(item) == "number" and item > 0 then
        return math.floor(item)
    end

    if type(item) ~= "string" or item == "" then
        return nil
    end

    local itemID = tonumber(item:match("item:(%d+)")) or tonumber(item:match("^(%d+)$"))
    return itemID and itemID > 0 and itemID or nil
end

local function GetContainerItemInfoCompat(bagID, slotIndex)
    if C_Container and type(C_Container.GetContainerItemInfo) == "function" then
        return C_Container.GetContainerItemInfo(bagID, slotIndex)
    end
    if type(GetContainerItemInfo) == "function" then
        local texture, count, locked, quality, readable, lootable, link, isFiltered, noValue, itemID
            = GetContainerItemInfo(bagID, slotIndex)
        return {
            iconFileID = texture,
            stackCount = count,
            isLocked = locked,
            quality = quality,
            isReadable = readable,
            hasLoot = lootable,
            hyperlink = link,
            itemID = itemID or NormalizeItemID(link),
        }
    end
end

local function GetContainerNumSlotsCompat(bagID)
    if C_Container and type(C_Container.GetContainerNumSlots) == "function" then
        return C_Container.GetContainerNumSlots(bagID) or 0
    end
    if type(GetContainerNumSlots) == "function" then
        return GetContainerNumSlots(bagID) or 0
    end
    return 0
end

local function GetContainerItemIDCompat(bagID, slotIndex)
    if C_Container and type(C_Container.GetContainerItemID) == "function" then
        return C_Container.GetContainerItemID(bagID, slotIndex)
    end
    local info = GetContainerItemInfoCompat(bagID, slotIndex)
    return info and NormalizeItemID(info.itemID or info.hyperlink)
end

local function BuildBagState()
    local snapshot = {}
    local slots = {}
    local reagentBag = Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag or 5
    local maxBag = math.max(tonumber(NUM_BAG_SLOTS) or 4, tonumber(NUM_TOTAL_EQUIPPED_BAG_SLOTS) or 5, reagentBag)
    for bagID = 0, maxBag do
        slots[bagID] = {}
        for slotIndex = 1, GetContainerNumSlotsCompat(bagID) do
            local info = GetContainerItemInfoCompat(bagID, slotIndex)
            local itemID = info and NormalizeItemID(info.itemID or info.hyperlink)
            local quantity = info and (info.stackCount or info.quantity) or 1
            if itemID and quantity and quantity > 0 then
                snapshot[itemID] = (snapshot[itemID] or 0) + quantity
                slots[bagID][slotIndex] = {
                    itemID = itemID,
                    hasLoot = info.hasLoot == true,
                }
            end
        end
    end
    return snapshot, slots
end

local function BuildBagSnapshot()
    return BuildBagState()
end

local function AddOutput(target, itemID, quantity)
    itemID = NormalizeItemID(itemID)
    quantity = math.floor(tonumber(quantity) or 0)
    if not itemID or quantity <= 0 or IsRecipeItem(itemID) then
        return false
    end

    target[itemID] = (target[itemID] or 0) + quantity
    return true
end

local function GetPositiveBagDiff(before, after)
    local outputs = {}
    for itemID, quantity in pairs(after or {}) do
        local increase = quantity - (before and before[itemID] or 0)
        if increase > 0 then
            AddOutput(outputs, itemID, increase)
        end
    end
    return outputs
end

local function GetConsumedBagItems(before, after, beforeSlots)
    local lootableItemIDs = {}
    for _, bagSlots in pairs(beforeSlots or {}) do
        for _, slotState in pairs(bagSlots) do
            if slotState.hasLoot and slotState.itemID then
                lootableItemIDs[slotState.itemID] = true
            end
        end
    end

    local consumed = {}
    for itemID, quantity in pairs(before or {}) do
        local decrease = quantity - (after and after[itemID] or 0)
        if decrease > 0 and lootableItemIDs[itemID] and IsContainerItem(itemID) then
            consumed[itemID] = decrease
        end
    end
    return consumed
end

local function CleanupInvalidContainerEntries()
    if invalidEntriesCleaned then
        return
    end
    invalidEntriesCleaned = true

    local db = GetDB()
    for containerID, entry in pairs(db.containers) do
        local itemID = tonumber(containerID)
        if itemID and not IsContainerItem(itemID) then
            db.containers[containerID] = nil
        elseif type(entry) == "table" and type(entry.outputs) == "table" then
            for outputID in pairs(entry.outputs) do
                if IsRecipeItem(tonumber(outputID)) then
                    entry.outputs[outputID] = nil
                end
            end
            if next(entry.outputs) == nil then
                db.containers[containerID] = nil
            end
        else
            db.containers[containerID] = nil
        end
    end
end

local function HasOutputs(outputs)
    return next(outputs or {}) ~= nil
end

local function GetContainerEntry(containerID)
    local db = GetDB()
    local key = tostring(containerID)
    local entry = db.containers[key]
    if type(entry) ~= "table" then
        entry = { opens = 0, outputs = {} }
        db.containers[key] = entry
    end
    entry.opens = tonumber(entry.opens) or 0
    entry.outputs = type(entry.outputs) == "table" and entry.outputs or {}
    return entry
end

local function GetTSMUnitPrice(itemID)
    if type(TSM_API) ~= "table"
        or type(TSM_API.ToItemString) ~= "function"
        or type(TSM_API.GetCustomPriceValue) ~= "function" then
        return nil
    end

    local okString, itemString = pcall(TSM_API.ToItemString, "i:" .. tostring(itemID))
    if not okString or type(itemString) ~= "string" or itemString == "" then
        return nil
    end

    for _, priceSource in ipairs(PRICE_SOURCES) do
        local okPrice, price = pcall(TSM_API.GetCustomPriceValue, priceSource, itemString)
        if okPrice and type(price) == "number" and price > 0 then
            return price
        end
    end
    return nil
end

local function FindPending(pending)
    for index, candidate in ipairs(pendingOpens) do
        if candidate == pending then
            return index
        end
    end
end

local function RecordOpening(pending)
    if not pending or pending.finalized then
        return
    end
    pending.finalized = true

    local outputs = pending.outputs
    if not HasOutputs(outputs) then
        outputs = GetPositiveBagDiff(pending.before, BuildBagSnapshot())
    end
    if not HasOutputs(outputs) then
        return
    end

    local entry = GetContainerEntry(pending.containerID)
    entry.opens = entry.opens + (pending.openCount or 1)
    entry.lastOpenedAt = pending.createdAt
    for itemID, quantity in pairs(outputs) do
        entry.outputs[tostring(itemID)] = (tonumber(entry.outputs[tostring(itemID)]) or 0) + quantity
    end
end

local function FinalizePending(pending)
    local index = FindPending(pending)
    if not index then
        return
    end
    table.remove(pendingOpens, index)
    RecordOpening(pending)
end

local function ScheduleFinalize(pending, delay)
    if not pending or not C_Timer or type(C_Timer.After) ~= "function" then
        return
    end
    pending.finalizeToken = (pending.finalizeToken or 0) + 1
    local token = pending.finalizeToken
    C_Timer.After(delay, function()
        if pending.finalizeToken == token then
            FinalizePending(pending)
        end
    end)
end

local function GetFirstPending()
    return pendingOpens[1]
end

local function CaptureLootWindow()
    local pending = GetFirstPending()
    if not pending or type(GetNumLootItems) ~= "function" or type(GetLootSlotInfo) ~= "function" then
        return
    end

    pending.lootWindowSeen = true
    local count = GetNumLootItems() or 0
    for slotIndex = 1, count do
        local _, _, quantity = GetLootSlotInfo(slotIndex)
        local itemLink = type(GetLootSlotLink) == "function" and GetLootSlotLink(slotIndex) or nil
        AddOutput(pending.outputs, itemLink, quantity or 1)
    end

    if HasOutputs(pending.outputs) then
        pending.lootCaptured = true
        ScheduleFinalize(pending, LOOT_FINALIZE_DELAY)
    end
end

local function CaptureLootMessage(message)
    local pending = GetFirstPending()
    if not pending or pending.lootCaptured or type(message) ~= "string" then
        return
    end

    local captured = false
    for itemID in message:gmatch("|Hitem:(%d+)") do
        captured = AddOutput(pending.outputs, itemID, tonumber(message:match("[xX](%d+)")) or 1) or captured
    end
    if captured then
        ScheduleFinalize(pending, LOOT_FINALIZE_DELAY)
    end
end

local function StartPendingOpening(itemID, before, openCount)
    if not itemID or not IsContainerItem(itemID) then
        return false
    end

    openCount = math.max(1, math.floor(tonumber(openCount) or 1))
    local previous = GetFirstPending()
    if previous and previous.containerID == itemID then
        previous.openCount = (previous.openCount or 1) + openCount
        previous.createdAt = Now()
        ScheduleFinalize(previous, FINALIZE_DELAY)
        return true
    elseif previous then
        FinalizePending(previous)
    end

    local pending = {
        containerID = itemID,
        before = before or BuildBagSnapshot(),
        outputs = {},
        createdAt = Now(),
        openCount = openCount,
    }
    pendingOpens[#pendingOpens + 1] = pending
    ScheduleFinalize(pending, FINALIZE_DELAY)
    return true
end

local function BeginOpening(bagID, slotIndex)
    local cachedBag = lastBagSlots and lastBagSlots[bagID]
    local slotState = cachedBag and cachedBag[slotIndex]
    if slotState and slotState.hasLoot and slotState.itemID then
        StartPendingOpening(slotState.itemID, lastBagSnapshot or BuildBagSnapshot())
    end
end

local function InstallHooks()
    if initialized or type(hooksecurefunc) ~= "function" then
        return
    end

    if C_Container and type(C_Container.UseContainerItem) == "function" then
        hooksecurefunc(C_Container, "UseContainerItem", BeginOpening)
    elseif type(UseContainerItem) == "function" then
        hooksecurefunc("UseContainerItem", BeginOpening)
    end
    initialized = true
end

local function GetAverageValue(item)
    local itemID = NormalizeItemID(item)
    local db = GetDB()
    local entry = itemID and db.containers[tostring(itemID)]
    local opens = entry and tonumber(entry.opens) or 0
    if opens <= 0 or type(entry.outputs) ~= "table" then
        return nil, opens, "no_samples"
    end

    local total = 0
    local pricedOutputs = 0
    local missingOutputs = 0
    for outputID, quantity in pairs(entry.outputs) do
        local price = GetTSMUnitPrice(tonumber(outputID))
        if not price then
            missingOutputs = missingOutputs + 1
        else
            total = total + price * (tonumber(quantity) or 0)
            pricedOutputs = pricedOutputs + 1
        end
    end
    if pricedOutputs == 0 then
        return nil, opens, "missing_price", missingOutputs
    end
    return total / opens, opens, missingOutputs > 0 and "partial" or "ok", missingOutputs
end

function API.GetAverageValue(item)
    return GetAverageValue(item)
end

function API.BeginOpening(item)
    local itemID = NormalizeItemID(item)
    if not itemID then
        return false
    end
    return StartPendingOpening(itemID, lastBagSnapshot or BuildBagSnapshot())
end

API.GetPrice = API.GetAverageValue
API.GetContainerValue = API.GetAverageValue

function API.GetStats(item)
    local itemID = NormalizeItemID(item)
    local entry = itemID and GetDB().containers[tostring(itemID)]
    if not entry then
        return nil
    end
    return entry
end

local function FormatMoney(value)
    if type(GetMoneyString) == "function" then
        return GetMoneyString(math.floor(value), true)
    end
    return tostring(math.floor(value)) .. " copper"
end

local function AddContainerValueToTooltip(tooltip, data)
    if not tooltip or type(tooltip.GetItem) ~= "function" or type(tooltip.AddDoubleLine) ~= "function" then
        return
    end

    local _, itemLink = tooltip:GetItem()
    local itemID = NormalizeItemID(data and data.id) or NormalizeItemID(itemLink)
    if not itemID then
        return
    end

    local value, opens = API.GetAverageValue(itemID)
    if not value or not opens or opens <= 0 then
        return
    end

    local marker = ("%d:%d:%d"):format(itemID, opens, math.floor(value + 0.5))
    if tooltip.yayaContainerValueMarker == marker then
        return
    end

    tooltip.yayaContainerValueMarker = marker
    tooltip:AddDoubleLine(
        "Valeur moyenne Yaya",
        ("%s / ouverture (%d)"):format(FormatMoney(value), opens),
        0.3,
        1,
        0.5,
        1,
        1,
        1
    )
    tooltip:Show()
end

local function ResetTooltipMarker(tooltip)
    tooltip.yayaContainerValueMarker = nil
end

local function HookTooltipReset(tooltip)
    if not tooltip or tooltip.yayaContainerValueResetHooked or type(tooltip.HookScript) ~= "function" then
        return
    end
    tooltip.yayaContainerValueResetHooked = true
    tooltip:HookScript("OnHide", ResetTooltipMarker)
end

local function InstallTooltipHooks()
    if tooltipHooksInstalled then
        return
    end

    local tooltips = { GameTooltip, ItemRefTooltip, ShoppingTooltip1, ShoppingTooltip2, ShoppingTooltip3 }
    for _, tooltip in ipairs(tooltips) do
        HookTooltipReset(tooltip)
    end

    if TooltipDataProcessor
        and type(TooltipDataProcessor.AddTooltipPostCall) == "function"
        and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Item then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, AddContainerValueToTooltip)
    end

    for _, tooltip in ipairs(tooltips) do
        if tooltip and type(tooltip.HookScript) == "function" then
            pcall(tooltip.HookScript, tooltip, "OnTooltipSetItem", AddContainerValueToTooltip)
        end
    end

    tooltipHooksInstalled = true
end

local function PrintContainer(itemID)
    local stats = API.GetStats(itemID)
    local value, opens, state, missingOutputs = API.GetAverageValue(itemID)
    local name = type(GetItemInfo) == "function" and GetItemInfo(itemID) or nil
    name = name or ("item:" .. tostring(itemID))
    if value then
        Print(("%s : %s / ouverture (%d ouvertures)"):format(name, FormatMoney(value), opens))
    elseif state == "missing_price" then
        Print(("%s : aucun output tarifé (%d ouverture(s))"):format(name, opens))
    elseif stats then
        Print(("%s : %d ouverture(s), prix moyen indisponible"):format(name, opens))
    else
        Print(("Aucune ouverture connue pour %s"):format(name))
    end
end

local function HandleSlashCommand(message)
    local command, argument = tostring(message or ""):match("^%s*(%S+)%s*(.-)%s*$")
    command = command and command:lower() or "list"
    local itemID = NormalizeItemID(argument)

    if command == "price" and itemID then
        PrintContainer(itemID)
        return
    end
    if command == "reset" and itemID then
        GetDB().containers[tostring(itemID)] = nil
        Print("Historique agrégé réinitialisé pour item:" .. tostring(itemID))
        return
    end

    local found = false
    for containerID, stats in pairs(GetDB().containers) do
        if type(stats) == "table" and HasOutputs(stats.outputs) then
            found = true
            PrintContainer(tonumber(containerID))
        end
    end
    if not found then
        Print("Aucun container avec output suivi. Commande : /ycv price <itemID>")
    end
end

SLASH_YAYACONTAINERVALUES1 = "/ycv"
SlashCmdList.YAYACONTAINERVALUES = HandleSlashCommand

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("BAG_UPDATE_DELAYED")
eventFrame:RegisterEvent("LOOT_OPENED")
eventFrame:RegisterEvent("CHAT_MSG_LOOT")
eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_LOGIN" then
        GetDB()
        CleanupInvalidContainerEntries()
        lastBagSnapshot, lastBagSlots = BuildBagState()
        InstallHooks()
        InstallTooltipHooks()
    elseif event == "LOOT_OPENED" then
        CaptureLootWindow()
    elseif event == "CHAT_MSG_LOOT" then
        CaptureLootMessage(...)
    elseif event == "BAG_UPDATE_DELAYED" then
        local before = lastBagSnapshot or BuildBagSnapshot()
        local beforeSlots = lastBagSlots
        local after, afterSlots = BuildBagState()
        lastBagSnapshot = after
        lastBagSlots = afterSlots
        local pending = GetFirstPending()
        if not pending then
            local consumedID
            local consumedCount
            for itemID, count in pairs(GetConsumedBagItems(before, after, beforeSlots)) do
                if consumedID then
                    consumedID = nil
                    break
                end
                consumedID = itemID
                consumedCount = count
            end
            if consumedID and StartPendingOpening(consumedID, before, consumedCount) then
                pending = GetFirstPending()
            end
        end
        if pending and HasOutputs(pending.outputs) then
            ScheduleFinalize(pending, LOOT_FINALIZE_DELAY)
        end
    end
end)
