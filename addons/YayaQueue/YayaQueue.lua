local addonName = ...

local addon = CreateFrame("Frame")
local db

local MAX_QUEUE_QTY = 9999
local MAX_CRAFT_LINES = 8
local MAX_AH_LINES = 10
local CRAFT_PANEL_EXPANDED_HEIGHT = 340
local CRAFT_PANEL_COLLAPSED_HEIGHT = 88
local FIRST_CRAFT_COST_LIMIT = 1000 * 10000
local MERCHANT_AUTO_BUY_MAX_RETRIES = 10
local MERCHANT_AUTO_BUY_INITIAL_DELAY = 0.02
local MERCHANT_AUTO_BUY_RETRY_DELAY = 0.08
local MERCHANT_AUTO_BUY_VERIFY_DELAY = 0.08
local debugNextCraft = false
local DEBUG_LOG_LIMIT = 400
local COMMODITY_SORT = { sortOrder = 0, reverseSort = false }
local ITEM_SORTS = { { sortOrder = 4, reverseSort = false } }
local KNOWN_VENDOR_ITEMS = {
    [38682] = true, -- Enchanting Vellum
    [240991] = true, -- Sunglass Vial
    [242641] = true, -- Cooking Spirits
    [242642] = true, -- Thalassian Herbs
    [242643] = true, -- A Big Ol' Stick of Butter
    [242644] = true, -- Mana-Wyrm Essence
    [242645] = true, -- Ripened Vegetable Assortment
    [242646] = true, -- Pouch of Spices
    [242647] = true, -- Tavern Fixings
    [243060] = true, -- Luminant Flux
    [245881] = true, -- Lexicologist's Vellum
    [245882] = true, -- Thalassian Songwater
    [251665] = true, -- Silverleaf Thread
    [253302] = true, -- Malleable Wireframe
    [253303] = true, -- Pile of Junk
}

local state = {
    craft = {
        panel = nil,
        resetButton = nil,
        nextButton = nil,
        selectedText = nil,
        todoTitle = nil,
        lines = {},
        statusText = nil,
        vendorTitle = nil,
        vendorButtons = {},
        qualityFrame = nil,
        qualityTarget = nil,
        qualityState = nil,
    },
    ah = {
        frame = nil,
        tab = nil,
        lines = {},
        actionButton = nil,
        statusText = nil,
        totalText = nil,
        activeSearch = nil,
        waitingSearch = nil,
        searchQueue = nil,
        pendingCommodity = nil,
        pendingItem = nil,
        statusMessage = "",
    },
    searchCache = {},
    merchantIndexByItemID = {},
    merchantAutoBuyGeneration = 0,
    merchantAutoBuyScheduled = false,
    merchantAutoBuyAttempted = false,
    merchantAutoBuyRetries = 0,
    merchantAutoBuyPending = nil,
    merchantAutoBuySubmitted = {},
    itemLoadPending = {},
    incomingItemCounts = {},
    observedItemCounts = {},
    professionsHooksInitialized = false,
    craftApiHooksInitialized = false,
    orderApiHooksInitialized = false,
    refreshQueued = false,
    refreshDeferredByCombat = false,
    pendingQueuedRecipeConfig = nil,
    pendingCraftBatches = {},
    pendingCraftEntries = {},
    pendingWorkOrderSubmit = {},
    pendingWorkOrderSubmitLockSeconds = 1.0,
    craftClickLockUntil = 0,
    craftClickLockSeconds = 2.0,
    nextActionLock = nil,
    recentCompletedPatronOrders = {},
    recentCompletedPatronOrderTTL = 30.0,
    firstCraftScanRunning = false,
    firstCraftAvailability = {},
}

local RefreshAll
local OnAuctionActionClick
local RunPatronNextAction
local ClearPendingCraftEntries
local QueuePendingCraftEntry
local PopPendingCraftEntry
local GetCurrentProfessionID
local EnsureDB
local YQQuality = {}

local function SafeCall(func, ...)
    if type(func) ~= "function" then
        return nil
    end
    local ok, result = pcall(func, ...)
    if ok then
        return result
    end
    return nil
end

local function Print(message)
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99" .. addonName .. "|r: " .. message)
end

local function AppendPersistentDebugLog(prefix, message)
    EnsureDB()
    db.debugLog = db.debugLog or {}

    local timestamp = date and date("%H:%M:%S") or tostring(math.floor(GetTime and GetTime() or 0))
    db.debugLog[#db.debugLog + 1] = ("[%s] %s%s"):format(timestamp, prefix or "", tostring(message or ""))
    local overflow = #db.debugLog - DEBUG_LOG_LIMIT
    if overflow > 0 then
        for _ = 1, overflow do
            table.remove(db.debugLog, 1)
        end
    end
end

local function PrintPersistentDebugLog(limit)
    EnsureDB()
    local lines = db.debugLog or {}
    limit = math.max(1, math.floor(tonumber(limit) or 20))
    local firstIndex = math.max(1, #lines - limit + 1)
    for index = firstIndex, #lines do
        Print(lines[index])
    end
end

local function ClearPersistentDebugLog()
    EnsureDB()
    db.debugLog = {}
end

local function DebugPrint(message)
    if not debugNextCraft then
        return
    end
    AppendPersistentDebugLog("YQ DEBUG ", message)
    Print("DEBUG " .. tostring(message))
end

local function ClampQuantity(value)
    value = tonumber(value) or 1
    value = math.floor(value)
    if value < 1 then
        value = 1
    elseif value > MAX_QUEUE_QTY then
        value = MAX_QUEUE_QTY
    end
    return value
end

local GetItemName

local function NormalizeQueueMode(mode)
    if mode == "output" then
        return "output"
    end
    if mode == "crafts" then
        return "crafts"
    end
    return "crafts"
end

local function NormalizeReagents(reagents)
    local normalized = {}

    for _, reagent in ipairs(reagents or {}) do
        local itemID = tonumber(reagent and reagent.itemID) or 0
        local quantity = tonumber(reagent and reagent.quantity) or 0
        if itemID > 0 and quantity > 0 then
            normalized[#normalized + 1] = {
                itemID = itemID,
                quantity = quantity,
            }
        end
    end

    table.sort(normalized, function(left, right)
        if left.itemID == right.itemID then
            return left.quantity < right.quantity
        end
        return left.itemID < right.itemID
    end)

    return normalized
end

local function NormalizeSlotAllocations(slotAllocations)
    local normalized = {}
    for _, allocation in ipairs(slotAllocations or {}) do
        local slotIndex = tonumber(allocation and allocation.slotIndex)
        local itemID = tonumber(allocation and allocation.itemID)
        local currencyID = tonumber(allocation and allocation.currencyID)
        local quantity = math.max(0, tonumber(allocation and allocation.quantity) or 0)
        if slotIndex and slotIndex > 0 and quantity > 0 and ((itemID and itemID > 0) or (currencyID and currencyID > 0)) then
            normalized[#normalized + 1] = {
                slotIndex = slotIndex,
                itemID = itemID and itemID > 0 and itemID or nil,
                currencyID = currencyID and currencyID > 0 and currencyID or nil,
                quantity = quantity,
            }
        end
    end
    return normalized
end

local function NormalizeCraftingReagents(craftingReagents)
    local normalized = {}
    for _, info in ipairs(craftingReagents or {}) do
        local dataSlotIndex = tonumber(info and info.dataSlotIndex)
        local reagent = info and info.reagent
        local itemID = tonumber(reagent and reagent.itemID)
        local currencyID = tonumber(reagent and reagent.currencyID)
        local quantity = math.max(0, tonumber(info and info.quantity) or 0)
        if dataSlotIndex and dataSlotIndex > 0 and quantity > 0
            and ((itemID and itemID > 0) or (currencyID and currencyID > 0)) then
            normalized[#normalized + 1] = {
                dataSlotIndex = dataSlotIndex,
                reagent = {
                    itemID = itemID and itemID > 0 and itemID or nil,
                    currencyID = currencyID and currencyID > 0 and currencyID or nil,
                },
                quantity = quantity,
            }
        end
    end
    return normalized
end

local function NormalizeSlotIndices(slotIndices)
    local normalized = {}
    local seen = {}
    for _, value in ipairs(slotIndices or {}) do
        local slotIndex = tonumber(value)
        if slotIndex and slotIndex > 0 and not seen[slotIndex] then
            seen[slotIndex] = true
            normalized[#normalized + 1] = slotIndex
        end
    end
    table.sort(normalized)
    return normalized
end

local WarmItemData

local function AddEnchantingVellumReagent(reagents, recipeInfo)
    if type(recipeInfo) ~= "table" or recipeInfo.isEnchantingRecipe ~= true then
        return reagents
    end

    for _, reagent in ipairs(reagents or {}) do
        if tonumber(reagent and reagent.itemID) == 38682 then
            return reagents
        end
    end

    WarmItemData(38682)
    reagents[#reagents + 1] = {
        itemID = 38682,
        quantity = 1,
    }
    return reagents
end

local function BuildReagentSignature(reagents)
    local parts = {}
    for _, reagent in ipairs(NormalizeReagents(reagents)) do
        parts[#parts + 1] = reagent.itemID .. ":" .. reagent.quantity
    end
    return table.concat(parts, "|")
end

local function NormalizeApplyConcentration(value)
    return value == true
end

local function NormalizeTargetQuality(value)
    value = tonumber(value)
    if not value or value <= 0 then
        return nil
    end
    return math.floor(value)
end

local function NormalizeDirectItemEntry(rawEntry)
    local itemID = tonumber(rawEntry and rawEntry.itemID) or tonumber(rawEntry and rawEntry.directItemID) or 0
    if itemID <= 0 then
        return nil
    end

    local quantity = ClampQuantity(rawEntry.directQuantity or rawEntry.quantity or rawEntry.outputQty or rawEntry.craftQty or 1)
    local itemName = type(rawEntry.itemName) == "string" and rawEntry.itemName ~= "" and rawEntry.itemName or GetItemName(itemID)
    return {
        itemID = itemID,
        itemName = itemName,
        directQuantity = quantity,
        queueKind = rawEntry.queueKind == "direct_item" and "direct_item" or "direct_item",
    }
end

local function NormalizeQueueEntries()
    local normalized = {}

    for _, rawEntry in ipairs(db.queue or {}) do
        if type(rawEntry) == "table" then
            local recipeID = tonumber(rawEntry.recipeID) or 0
            if recipeID > 0 then
                local outputPerCraft = math.max(1, tonumber(rawEntry.outputPerCraft) or 1)
                local reagents = NormalizeReagents(rawEntry.reagents)
                local mode = rawEntry.mode == "crafts" and "crafts" or "output"
                local craftQty

                if mode == "crafts" then
                    craftQty = ClampQuantity(rawEntry.craftQty or rawEntry.outputQty or 1)
                else
                    local outputQty = ClampQuantity(rawEntry.outputQty or rawEntry.craftQty or 1)
                    craftQty = ClampQuantity(math.ceil(outputQty / outputPerCraft))
                end

                normalized[#normalized + 1] = {
                    recipeID = recipeID,
                    recipeName = type(rawEntry.recipeName) == "string" and rawEntry.recipeName ~= ""
                        and rawEntry.recipeName
                        or ("Recette " .. recipeID),
                    outputItemID = tonumber(rawEntry.outputItemID) or nil,
                    outputPerCraft = outputPerCraft,
                    craftQty = craftQty,
                    mode = "crafts",
                    reagents = reagents,
                    reagentSignature = BuildReagentSignature(reagents),
                    craftingReagents = NormalizeCraftingReagents(rawEntry.craftingReagents),
                    slotAllocations = NormalizeSlotAllocations(rawEntry.slotAllocations),
                    clearSlotIndices = NormalizeSlotIndices(rawEntry.clearSlotIndices),
                    targetQuality = NormalizeTargetQuality(rawEntry.targetQuality),
                    targetQualitySimplified = rawEntry.targetQualitySimplified == true,
                    concentrationCost = tonumber(rawEntry.concentrationCost) or nil,
                    orderID = tonumber(rawEntry.orderID) or nil,
                    professionID = tonumber(rawEntry.professionID) or nil,
                    queueKind = rawEntry.queueKind == "patron" and "patron" or nil,
                    isRecraft = rawEntry.isRecraft == true,
                    applyConcentration = NormalizeApplyConcentration(rawEntry.applyConcentration),
                    pendingSubmit = rawEntry.pendingSubmit == true,
                    profitValue = tonumber(rawEntry.profitValue) or nil,
                    profitKnown = rawEntry.profitKnown == true,
                }
            elseif rawEntry.queueKind == "direct_item" or rawEntry.directItemID or rawEntry.itemID then
                local directEntry = NormalizeDirectItemEntry(rawEntry)
                if directEntry then
                    normalized[#normalized + 1] = directEntry
                end
            end
        end
    end

    db.queue = normalized
end

EnsureDB = function()
    if type(YayaQueueDB) ~= "table" then
        YayaQueueDB = {}
    end
    if type(YayaQueueDB.queue) ~= "table" then
        YayaQueueDB.queue = {}
    end
    if type(YayaQueueDB.vendorItems) ~= "table" then
        YayaQueueDB.vendorItems = {}
    end
    if type(YayaQueueDB.panelPoint) ~= "table" then
        YayaQueueDB.panelPoint = {
            point = "CENTER",
            relativePoint = "CENTER",
            x = 430,
            y = 0,
        }
    end
    if type(YayaQueueDB.debugLog) ~= "table" then
        YayaQueueDB.debugLog = {}
    end
    if YayaQueueDB.autoBuyVendor == nil then
        YayaQueueDB.autoBuyVendor = true
    end
    db = YayaQueueDB
    for itemID in pairs(KNOWN_VENDOR_ITEMS) do
        db.vendorItems[itemID] = true
    end
    NormalizeQueueEntries()
end

local function ScheduleRefresh()
    if InCombatLockdown and InCombatLockdown() then
        state.refreshDeferredByCombat = true
        return
    end

    if state.refreshQueued then
        return
    end
    state.refreshQueued = true
    C_Timer.After(0, function()
        state.refreshQueued = false
        RefreshAll()
    end)
end

local function GetPlayerCraftCastEndTime()
    local _, _, _, startMS, endMS = UnitCastingInfo and UnitCastingInfo("player") or nil
    if type(endMS) == "number" and endMS > 0 then
        return endMS / 1000
    end

    local _, _, _, channelStartMS, channelEndMS = UnitChannelInfo and UnitChannelInfo("player") or nil
    if type(channelEndMS) == "number" and channelEndMS > 0 then
        return channelEndMS / 1000
    end

    return nil
end

local function BeginCraftClickLock()
    local fallbackLockSeconds = state.craftClickLockSeconds or 2.0
    local castEndTime = GetPlayerCraftCastEndTime()
    state.craftClickLockUntil = math.max(
        GetTime() + fallbackLockSeconds,
        castEndTime or 0
    )

    C_Timer.After(fallbackLockSeconds + 0.05, function()
        if state.craftClickLockUntil <= 0 then
            return
        end
        local isCrafting = C_TradeSkillUI and C_TradeSkillUI.IsCrafting and C_TradeSkillUI.IsCrafting()
        if not isCrafting and GetTime() >= state.craftClickLockUntil then
            state.craftClickLockUntil = 0
            ScheduleRefresh()
        end
    end)
end

local function EndCraftClickLock()
    state.craftClickLockUntil = 0
end

local function BeginNextActionLock(action, orderID, timeoutSeconds)
    state.nextActionLock = {
        action = tostring(action or ""),
        orderID = tonumber(orderID) or 0,
        expiresAt = GetTime() + math.max(0.5, tonumber(timeoutSeconds) or 1.5),
    }
    DebugPrint("next-lock begin action=" .. tostring(state.nextActionLock.action) .. " order=" .. tostring(state.nextActionLock.orderID))
end

local function ClearNextActionLock(reason)
    if not state.nextActionLock then
        return
    end
    DebugPrint("next-lock clear action=" .. tostring(state.nextActionLock.action) .. " order=" .. tostring(state.nextActionLock.orderID) .. " reason=" .. tostring(reason or "?"))
    state.nextActionLock = nil
end

local function GetNextActionLock()
    local lock = state.nextActionLock
    if not lock then
        return nil
    end
    if type(lock.expiresAt) == "number" and GetTime() < lock.expiresAt then
        return lock
    end
    ClearNextActionLock("expired")
    return nil
end

local function MarkRecentCompletedPatronOrder(orderID)
    orderID = tonumber(orderID) or 0
    if orderID <= 0 then
        return
    end
    state.recentCompletedPatronOrders[orderID] = GetTime() + (state.recentCompletedPatronOrderTTL or 30.0)
end

local function WasPatronOrderCompletedRecently(orderID)
    orderID = tonumber(orderID) or 0
    if orderID <= 0 then
        return false
    end

    local expiresAt = state.recentCompletedPatronOrders[orderID]
    if not expiresAt then
        return false
    end
    if GetTime() < expiresAt then
        return true
    end

    state.recentCompletedPatronOrders[orderID] = nil
    return false
end

local function IsCraftClickLocked()
    if not state.craftClickLockUntil or state.craftClickLockUntil <= 0 then
        return false
    end

    local castEndTime = GetPlayerCraftCastEndTime()
    if castEndTime and castEndTime > GetTime() then
        state.craftClickLockUntil = math.max(state.craftClickLockUntil or 0, castEndTime)
        return true
    end

    local isCrafting = C_TradeSkillUI and C_TradeSkillUI.IsCrafting and C_TradeSkillUI.IsCrafting()
    if isCrafting then
        return true
    end

    if GetTime() < state.craftClickLockUntil then
        return true
    end

    state.craftClickLockUntil = 0
    return false
end

local function MarkPendingWorkOrderSubmit(orderID)
    orderID = tonumber(orderID) or 0
    if orderID <= 0 then
        return
    end

    local expiresAt = GetTime() + (state.pendingWorkOrderSubmitLockSeconds or 1.0)
    state.pendingWorkOrderSubmit[orderID] = expiresAt
    C_Timer.After((state.pendingWorkOrderSubmitLockSeconds or 1.0) + 0.05, function()
        local expiry = state.pendingWorkOrderSubmit[orderID]
        if expiry and GetTime() >= expiry then
            state.pendingWorkOrderSubmit[orderID] = nil
            ScheduleRefresh()
        end
    end)
end

local function ClearPendingWorkOrderSubmit(orderID)
    orderID = tonumber(orderID) or 0
    if orderID > 0 then
        state.pendingWorkOrderSubmit[orderID] = nil
    end
end

local function IsPendingWorkOrderSubmit(orderID)
    orderID = tonumber(orderID) or 0
    if orderID <= 0 then
        return false
    end

    local expiry = state.pendingWorkOrderSubmit[orderID]
    if not expiry then
        return false
    end

    if GetTime() < expiry then
        return true
    end

    state.pendingWorkOrderSubmit[orderID] = nil
    return false
end

WarmItemData = function(itemID)
    if type(itemID) ~= "number" or itemID <= 0 then
        return
    end
    if state.itemLoadPending[itemID] or not Item or type(Item.CreateFromItemID) ~= "function" then
        return
    end

    local item = Item:CreateFromItemID(itemID)
    if not item or item:IsItemDataCached() then
        return
    end

    state.itemLoadPending[itemID] = true
    item:ContinueOnItemLoad(function()
        state.itemLoadPending[itemID] = nil
        ScheduleRefresh()
    end)
end

GetItemName = function(itemID)
    if type(itemID) ~= "number" or itemID <= 0 then
        return "Item inconnu"
    end

    local name = C_Item and SafeCall(C_Item.GetItemNameByID, itemID) or nil
    if type(name) == "string" and name ~= "" then
        return name
    end

    name = SafeCall(GetItemInfo, itemID)
    if type(name) == "string" and name ~= "" then
        return name
    end

    WarmItemData(itemID)
    return "Item " .. itemID
end

local function GetImmediateOwnedCount(itemID)
    if type(itemID) ~= "number" or itemID <= 0 then
        return 0
    end

    if C_Item and type(C_Item.GetItemCount) == "function" then
        return C_Item.GetItemCount(itemID, false, false, false, false) or 0
    end

    return GetItemCount(itemID) or 0
end

local function GetTotalOwnedCount(itemID)
    if type(itemID) ~= "number" or itemID <= 0 then
        return 0
    end

    if C_Item and type(C_Item.GetItemCount) == "function" then
        return C_Item.GetItemCount(itemID, true, false, true, true) or 0
    end

    return GetItemCount(itemID, true, false, true, true) or GetItemCount(itemID, true) or 0
end

local function SetIncomingCount(itemID, quantity)
    if type(itemID) ~= "number" or itemID <= 0 then
        return
    end
    if quantity > 0 then
        state.incomingItemCounts[itemID] = quantity
    else
        state.incomingItemCounts[itemID] = nil
    end
end

local function AddIncomingPurchase(itemID, quantity, ownedBefore)
    if type(itemID) ~= "number" or itemID <= 0 then
        return
    end
    quantity = math.max(0, math.floor(tonumber(quantity) or 0))
    if quantity <= 0 then
        return
    end

    local actualOwned = GetImmediateOwnedCount(itemID)
    local previousOwned = tonumber(ownedBefore)
    if previousOwned == nil then
        previousOwned = state.observedItemCounts[itemID]
    end
    local alreadyReceived = type(previousOwned) == "number"
        and math.min(quantity, math.max(0, actualOwned - previousOwned))
        or 0

    state.observedItemCounts[itemID] = actualOwned
    SetIncomingCount(itemID, (state.incomingItemCounts[itemID] or 0) + quantity - alreadyReceived)
end

local function FinalizePendingItemPurchase()
    if not state.ah.pendingItem then
        return
    end

    AddIncomingPurchase(
        state.ah.pendingItem.itemID,
        state.ah.pendingItem.quantity,
        state.ah.pendingItem.ownedBefore
    )
    state.ah.statusMessage = "Achete " .. state.ah.pendingItem.quantity .. "x " .. state.ah.pendingItem.name
    state.ah.pendingItem = nil
end

local function ClearAuctionTransientState(statusMessage)
    if state.ah.pendingCommodity and type(C_AuctionHouse.CancelCommoditiesPurchase) == "function" then
        pcall(C_AuctionHouse.CancelCommoditiesPurchase)
    end

    state.ah.searchQueue = nil
    state.ah.activeSearch = nil
    state.ah.waitingSearch = nil
    state.ah.pendingCommodity = nil
    state.ah.pendingItem = nil

    if type(statusMessage) == "string" and statusMessage ~= "" then
        state.ah.statusMessage = statusMessage
    end
end

local function GetOwnedCount(itemID)
    local actualOwned = GetImmediateOwnedCount(itemID)
    local previousOwned = state.observedItemCounts[itemID]
    if type(previousOwned) == "number" and actualOwned > previousOwned then
        local incoming = state.incomingItemCounts[itemID] or 0
        if incoming > 0 then
            SetIncomingCount(itemID, incoming - (actualOwned - previousOwned))
        end
    end
    state.observedItemCounts[itemID] = actualOwned
    return actualOwned
end

local function DebugPrintReagentCount(prefix, itemID, needed, mailbox)
    if not debugNextCraft or type(itemID) ~= "number" or itemID <= 0 then
        return
    end

    local immediateOwned = GetOwnedCount(itemID)
    local totalOwned = GetTotalOwnedCount(itemID)
    local name = GetItemName(itemID)
    DebugPrint(
        prefix
            .. " item="
            .. tostring(name)
            .. " itemID="
            .. tostring(itemID)
            .. " needed="
            .. tostring(needed or 0)
            .. " immediate="
            .. tostring(immediateOwned)
            .. " total="
            .. tostring(totalOwned)
            .. " mailbox="
            .. tostring(mailbox or 0)
    )
end

local function GetMailboxCount(itemID)
    local _ = GetOwnedCount(itemID)
    return state.incomingItemCounts[itemID] or 0
end

local function IsCommodityItem(itemID)
    local maxStack = select(8, SafeCall(GetItemInfo, itemID))
    if type(maxStack) ~= "number" then
        WarmItemData(itemID)
        return true
    end
    return maxStack > 1
end

local function MakeItemKey(itemID)
    if not C_AuctionHouse or type(C_AuctionHouse.MakeItemKey) ~= "function" then
        return nil
    end
    return C_AuctionHouse.MakeItemKey(itemID, 0, 0, 0)
end

local function FormatMoneyEstimate(value)
    if type(value) ~= "number" or value <= 0 then
        return "?"
    end
    return GetMoneyString(math.floor(value), true)
end

local function IsKnownVendorItem(itemID)
    return KNOWN_VENDOR_ITEMS[itemID] or state.merchantIndexByItemID[itemID] or (db and db.vendorItems and db.vendorItems[itemID]) or false
end

local function GetMerchantNumItemsCompat()
    if type(GetMerchantNumItems) == "function" then
        return tonumber(SafeCall(GetMerchantNumItems)) or 0
    end
    if C_MerchantFrame and type(C_MerchantFrame.GetNumItems) == "function" then
        return tonumber(SafeCall(C_MerchantFrame.GetNumItems)) or 0
    end
    return 0
end

local function GetItemLocationFromItemID(itemID)
    if type(itemID) ~= "number" or itemID <= 0 or type(ItemLocation) ~= "table" then
        return nil
    end

    local bagIDs = {
        Enum.BagIndex and Enum.BagIndex.Backpack or 0,
        Enum.BagIndex and Enum.BagIndex.Bag_1 or 1,
        Enum.BagIndex and Enum.BagIndex.Bag_2 or 2,
        Enum.BagIndex and Enum.BagIndex.Bag_3 or 3,
        Enum.BagIndex and Enum.BagIndex.Bag_4 or 4,
        Enum.BagIndex and Enum.BagIndex.ReagentBag or 5,
    }

    for _, bagID in ipairs(bagIDs) do
        local numSlots = (C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerNumSlots(bagID))
            or (GetContainerNumSlots and GetContainerNumSlots(bagID))
            or 0
        for slot = 1, numSlots do
            local info = C_Container and C_Container.GetContainerItemInfo and C_Container.GetContainerItemInfo(bagID, slot) or nil
            local slotItemID = info and info.itemID or (C_Container and C_Container.GetContainerItemID and C_Container.GetContainerItemID(bagID, slot)) or nil
            if slotItemID == itemID then
                return ItemLocation:CreateFromBagAndSlot(bagID, slot)
            end
        end
    end

    return nil
end

local function GetMerchantItemInfoCompat(index)
    if C_MerchantFrame and type(C_MerchantFrame.GetItemInfo) == "function" then
        local info = SafeCall(C_MerchantFrame.GetItemInfo, index)
        if type(info) == "table" then
            return info.name, info.texture, info.price, info.stackCount, info.numAvailable, info.isPurchasable, info.isUsable, info.hasExtendedCost, info.currencyID, info.spellID, info.itemID
        end
    end
    if type(GetMerchantItemInfo) == "function" then
        return SafeCall(GetMerchantItemInfo, index)
    end
    return nil
end

local function GetMerchantItemIDCompat(index)
    if type(GetMerchantItemID) == "function" then
        return SafeCall(GetMerchantItemID, index)
    end
    local _, _, _, _, _, _, _, _, _, _, itemID = GetMerchantItemInfoCompat(index)
    return itemID
end

local function GetMerchantItemMaxStackCompat(index)
    if type(GetMerchantItemMaxStack) == "function" then
        return tonumber(SafeCall(GetMerchantItemMaxStack, index)) or nil
    end
    local _, _, _, stackSize = GetMerchantItemInfoCompat(index)
    return tonumber(stackSize) or nil
end

local function CacheMerchantItems()
    wipe(state.merchantIndexByItemID)
    if not db then
        return
    end

    for index = 1, GetMerchantNumItemsCompat() do
        local itemID = GetMerchantItemIDCompat(index)
        if type(itemID) == "number" and itemID > 0 then
            state.merchantIndexByItemID[itemID] = index
            db.vendorItems[itemID] = true
            WarmItemData(itemID)
        end
    end
end

local function ReadQuantityInput(qtyBox)
    local text = qtyBox and qtyBox:GetText() or "1"
    return ClampQuantity(text)
end

local function GetQuantityInput(qtyBox)
    local quantity = ReadQuantityInput(qtyBox)
    if qtyBox then
        qtyBox:SetText(tostring(quantity))
    end
    return quantity
end

local function SetQuantityInput(qtyBox, quantity)
    quantity = ClampQuantity(quantity)
    if qtyBox then
        qtyBox:SetText(tostring(quantity))
    end
end

local function ApplyPanelPoint(frame)
    if not frame or not db or not db.panelPoint then
        return
    end

    local point = db.panelPoint
    frame:ClearAllPoints()
    frame:SetPoint(
        point.point or "CENTER",
        UIParent,
        point.relativePoint or point.point or "CENTER",
        tonumber(point.x) or 430,
        tonumber(point.y) or 0
    )
end

local function SavePanelPoint(frame)
    if not frame or not db then
        return
    end

    local point, _, relativePoint, x, y = frame:GetPoint(1)
    if not point then
        return
    end

    db.panelPoint = {
        point = point,
        relativePoint = relativePoint or point,
        x = tonumber(x) or 0,
        y = tonumber(y) or 0,
    }
end

local function ResolveCraftAnchor()
    local candidates = {
        ProfessionsFrame and ProfessionsFrame.CraftingPage and ProfessionsFrame.CraftingPage.SchematicForm,
        ProfessionsFrame and ProfessionsFrame.CraftingPage,
        ProfessionsFrame,
    }

    for _, candidate in ipairs(candidates) do
        if candidate then
            return candidate
        end
    end

    return nil
end

local function GetCraftingSchematicForm()
    return ProfessionsFrame and ProfessionsFrame.CraftingPage and ProfessionsFrame.CraftingPage.SchematicForm
end

local function GetOrderSchematicForm()
    local ordersPage = ProfessionsFrame and ProfessionsFrame.OrdersPage
    local orderView = ordersPage and ordersPage.OrderView
    return orderView and orderView.OrderDetails and orderView.OrderDetails.SchematicForm
end

local function IsProfessionPageVisible(page)
    return page
        and type(page.IsVisible) == "function"
        and SafeCall(page.IsVisible, page) == true
end

local function TrySelectProfessionTab(tabIndex, page)
    if IsProfessionPageVisible(page)
        or not ProfessionsFrame
        or type(ProfessionsFrame.GetTabButton) ~= "function" then
        return
    end

    local tabButton = SafeCall(ProfessionsFrame.GetTabButton, ProfessionsFrame, tabIndex)
    if tabButton and type(tabButton.Click) == "function" then
        SafeCall(tabButton.Click, tabButton)
    end
end

local function GuardRecipeDescriptionOwner(owner)
    if type(owner) ~= "table" or owner.YayaQueueRecipeDescriptionGuard then
        return
    end

    local original = owner.UpdateRecipeDescription
    if type(original) ~= "function" then
        return
    end

    owner.UpdateRecipeDescription = function(self, ...)
        if not (self and self.currentRecipeInfo) then
            return
        end
        return original(self, ...)
    end
    owner.YayaQueueRecipeDescriptionGuard = true
end

local function InstallRecipeDescriptionGuard()
    GuardRecipeDescriptionOwner(_G.ProfessionsRecipeSchematicFormMixin)
    GuardRecipeDescriptionOwner(GetCraftingSchematicForm())
    GuardRecipeDescriptionOwner(GetOrderSchematicForm())
end

local function GetCustomerOrdersForm()
    return ProfessionsCustomerOrdersFrame and ProfessionsCustomerOrdersFrame.Form
end

local function GetActiveSchematicForm()
    local orderForm = GetOrderSchematicForm()
    if orderForm and orderForm:IsShown() then
        return orderForm
    end

    local craftingForm = GetCraftingSchematicForm()
    if craftingForm and craftingForm:IsShown() then
        return craftingForm
    end

    return craftingForm or orderForm
end

local function GetSelectedRecipeID()
    local form = GetActiveSchematicForm()
    if form and type(form.GetRecipeInfo) == "function" then
        local info = SafeCall(form.GetRecipeInfo, form)
        if type(info) == "table" and type(info.recipeID) == "number" and info.recipeID > 0 then
            return info.recipeID
        end
    end

    local recipeID = C_TradeSkillUI and SafeCall(C_TradeSkillUI.GetSelectedRecipeID) or nil
    if type(recipeID) == "number" and recipeID > 0 then
        return recipeID
    end

    form = GetCraftingSchematicForm()
    if form and type(form.GetRecipeInfo) == "function" then
        local info = SafeCall(form.GetRecipeInfo, form)
        if type(info) == "table" and type(info.recipeID) == "number" and info.recipeID > 0 then
            return info.recipeID
        end
    end

    return nil
end

local function IsRequiredRecipeReagentSlot(slot)
    return slot
        and slot.required
        and type(slot.reagents) == "table"
        and #slot.reagents > 0
end

local function IsRequiredSelectableReagentSlot(slot)
    if not IsRequiredRecipeReagentSlot(slot) then
        return false
    end
    local firstReagent = slot.reagents[1]
    return tonumber(slot.reagentType) == 0
        or (tonumber(firstReagent and firstReagent.currencyID) or 0) > 0
end

local function BuildRecipeContext(recipeID, recipeInfo, schematic, transaction, subtractAllocated)
    if not recipeID or type(schematic) ~= "table" then
        return nil
    end

    local reagents = {}
    for slotIndex, slot in ipairs(schematic.reagentSlotSchematics or {}) do
        local reagent = IsRequiredRecipeReagentSlot(slot) and slot.reagents[1] or nil
        local itemID = reagent and reagent.itemID or nil
        local quantityRequired = tonumber(slot.quantityRequired) or 0
        if subtractAllocated and transaction and type(transaction.GetAllocations) == "function" then
            local allocations = SafeCall(transaction.GetAllocations, transaction, slotIndex)
            if allocations and type(allocations.Accumulate) == "function" then
                quantityRequired = math.max(0, quantityRequired - (tonumber(SafeCall(allocations.Accumulate, allocations)) or 0))
            end
        end
        if type(itemID) == "number" and itemID > 0 and quantityRequired > 0 then
            WarmItemData(itemID)
            table.insert(reagents, {
                itemID = itemID,
                quantity = quantityRequired,
            })
        end
    end
    reagents = AddEnchantingVellumReagent(reagents, recipeInfo)

    local outputItemID = schematic.outputItemID
    WarmItemData(outputItemID)

    return {
        recipeID = recipeID,
        recipeName = (recipeInfo and recipeInfo.name) or schematic.name or ("Recette " .. recipeID),
        outputItemID = outputItemID,
        outputPerCraft = math.max(1, tonumber(schematic.quantityMin) or 1),
        reagents = reagents,
        applyConcentration = transaction and type(transaction.IsApplyingConcentration) == "function" and transaction:IsApplyingConcentration() or false,
    }
end

local function GetRecipeContextFromSchematicForm(form)
    local recipeInfo = form and type(form.GetRecipeInfo) == "function" and SafeCall(form.GetRecipeInfo, form) or nil
    local transaction = form and ((type(form.GetTransaction) == "function" and SafeCall(form.GetTransaction, form)) or form.transaction) or nil
    local recipeID = recipeInfo and recipeInfo.recipeID or nil
    if (not recipeID or recipeID <= 0) and form and form.recipeSchematic and form.recipeSchematic.recipeID then
        recipeID = form.recipeSchematic.recipeID
    end
    if not recipeID or type(C_TradeSkillUI) ~= "table" then
        return nil
    end

    if type(recipeInfo) ~= "table" then
        recipeInfo = SafeCall(C_TradeSkillUI.GetRecipeInfo, recipeID)
    end

    local recipeLevel = form and type(form.GetCurrentRecipeLevel) == "function" and SafeCall(form.GetCurrentRecipeLevel, form) or nil
    local schematic = SafeCall(C_TradeSkillUI.GetRecipeSchematic, recipeID, false, recipeLevel)
    return BuildRecipeContext(recipeID, recipeInfo, schematic, transaction, false)
end

local function GetRecipeContextFromCustomerOrdersForm(form)
    local transaction = form and ((type(form.GetTransaction) == "function" and SafeCall(form.GetTransaction, form)) or form.transaction) or nil
    local schematic = transaction and type(transaction.GetRecipeSchematic) == "function" and SafeCall(transaction.GetRecipeSchematic, transaction) or nil
    local recipeID = schematic and schematic.recipeID or nil
    if not recipeID or type(C_TradeSkillUI) ~= "table" then
        return nil
    end

    local recipeInfo = SafeCall(C_TradeSkillUI.GetRecipeInfo, recipeID)
    return BuildRecipeContext(recipeID, recipeInfo, schematic, transaction, true)
end

local function GetCurrentRecipeContext()
    local form = GetActiveSchematicForm()
    if form then
        local context = GetRecipeContextFromSchematicForm(form)
        if context then
            return context
        end
    end

    local recipeID = GetSelectedRecipeID()
    if not recipeID or type(C_TradeSkillUI) ~= "table" then
        return nil
    end

    local recipeInfo = SafeCall(C_TradeSkillUI.GetRecipeInfo, recipeID)
    if type(recipeInfo) ~= "table" then
        return nil
    end

    local schematic = SafeCall(C_TradeSkillUI.GetRecipeSchematic, recipeID, false, nil)
    if type(schematic) ~= "table" then
        return nil
    end

    local reagents = {}
    for _, slot in ipairs(schematic.reagentSlotSchematics or {}) do
        local reagent = IsRequiredRecipeReagentSlot(slot) and slot.reagents[1] or nil
        local itemID = reagent and reagent.itemID or nil
        local quantityRequired = tonumber(slot.quantityRequired) or 0
        if type(itemID) == "number" and itemID > 0 and quantityRequired > 0 then
            WarmItemData(itemID)
            reagents[#reagents + 1] = {
                itemID = itemID,
                quantity = quantityRequired,
            }
        end
    end
    reagents = AddEnchantingVellumReagent(reagents, recipeInfo)

    return {
        recipeID = recipeID,
        recipeName = recipeInfo.name or schematic.name or ("Recette " .. recipeID),
        outputItemID = schematic.outputItemID,
        outputPerCraft = math.max(1, tonumber(schematic.quantityMin) or 1),
        reagents = reagents,
        applyConcentration = false,
    }
end

local function ResetQueue()
    EnsureDB()
    wipe(db.queue)
    wipe(state.searchCache)
    state.ah.searchQueue = nil
    state.ah.activeSearch = nil
    state.ah.waitingSearch = nil
    state.ah.pendingCommodity = nil
    state.ah.pendingItem = nil
    state.ah.statusMessage = "Queue reset"
    ScheduleRefresh()
end

local function AddRecipeToQueue(context, quantity)
    EnsureDB()
    quantity = ClampQuantity(quantity)
    local mode = NormalizeQueueMode(context and context.mode)
    local reagents = NormalizeReagents(context and context.reagents)
    local craftingReagents = NormalizeCraftingReagents(context and context.craftingReagents)
    local slotAllocations = NormalizeSlotAllocations(context and context.slotAllocations)
    local clearSlotIndices = NormalizeSlotIndices(context and context.clearSlotIndices)
    local reagentSignature = BuildReagentSignature(reagents)

    for _, entry in ipairs(db.queue) do
        if entry.recipeID == context.recipeID
            and NormalizeQueueMode(entry.mode) == mode
            and (entry.reagentSignature or "") == reagentSignature
            and (tonumber(entry.orderID) or 0) == (tonumber(context.orderID) or 0)
            and NormalizeApplyConcentration(entry.applyConcentration) == NormalizeApplyConcentration(context.applyConcentration)
            and NormalizeTargetQuality(entry.targetQuality) == NormalizeTargetQuality(context.targetQuality)
            and (entry.targetQualitySimplified == true) == (context.targetQualitySimplified == true)
        then
            if mode == "crafts" then
                entry.craftQty = ClampQuantity((entry.craftQty or 0) + quantity)
                entry.outputQty = nil
            else
                entry.outputQty = ClampQuantity((entry.outputQty or 0) + quantity)
            end
            entry.recipeName = context.recipeName
            entry.outputItemID = context.outputItemID
            entry.outputPerCraft = context.outputPerCraft
            entry.mode = mode
            entry.reagents = reagents
            entry.reagentSignature = reagentSignature
            entry.craftingReagents = craftingReagents
            entry.slotAllocations = slotAllocations
            entry.clearSlotIndices = clearSlotIndices
            entry.targetQuality = NormalizeTargetQuality(context.targetQuality)
            entry.targetQualitySimplified = context.targetQualitySimplified == true
            entry.concentrationCost = tonumber(context.concentrationCost) or nil
            entry.orderID = tonumber(context.orderID) or nil
            entry.professionID = tonumber(context.professionID) or nil
            entry.queueKind = context.queueKind == "patron" and "patron" or nil
            entry.isRecraft = context.isRecraft == true
            entry.applyConcentration = NormalizeApplyConcentration(context.applyConcentration)
            entry.pendingSubmit = context.pendingSubmit == true
            entry.profitValue = tonumber(context.profitValue) or nil
            entry.profitKnown = context.profitKnown == true
            return entry
        end
    end

    local entry = {
        recipeID = context.recipeID,
        recipeName = context.recipeName,
        outputItemID = context.outputItemID,
        outputQty = mode == "crafts" and nil or quantity,
        outputPerCraft = context.outputPerCraft,
        craftQty = mode == "crafts" and quantity or nil,
        mode = mode,
        reagents = reagents,
        reagentSignature = reagentSignature,
        craftingReagents = craftingReagents,
        slotAllocations = slotAllocations,
        clearSlotIndices = clearSlotIndices,
        targetQuality = NormalizeTargetQuality(context.targetQuality),
        targetQualitySimplified = context.targetQualitySimplified == true,
        concentrationCost = tonumber(context.concentrationCost) or nil,
        orderID = tonumber(context.orderID) or nil,
        professionID = tonumber(context.professionID) or nil,
        queueKind = context.queueKind == "patron" and "patron" or nil,
        isRecraft = context.isRecraft == true,
        applyConcentration = NormalizeApplyConcentration(context.applyConcentration),
        pendingSubmit = context.pendingSubmit == true,
        profitValue = tonumber(context.profitValue) or nil,
        profitKnown = context.profitKnown == true,
    }
    table.insert(db.queue, entry)
    return entry
end

local function SortTaskList(tasks)
    table.sort(tasks, function(left, right)
        if left.name == right.name then
            return (left.itemID or left.recipeID or 0) < (right.itemID or right.recipeID or 0)
        end
        return left.name < right.name
    end)
end

local function GetEntryCraftsRemaining(entry)
    if type(entry) ~= "table" then
        return 0, 0
    end

    if entry.queueKind == "direct_item" then
        return 0, 0
    end

    local mode = NormalizeQueueMode(entry.mode)
    if mode == "crafts" then
        local craftsRemaining = ClampQuantity(entry.craftQty or entry.outputQty or 1)
        return craftsRemaining, craftsRemaining
    end

    local outputQty = ClampQuantity(entry.outputQty or 1)
    local outputPerCraft = math.max(1, tonumber(entry.outputPerCraft) or 1)
    local ownedOutput = entry.outputItemID and GetOwnedCount(entry.outputItemID) or 0
    local remainingOutput = entry.outputItemID and math.max(0, outputQty - ownedOutput) or outputQty
    local craftsRemaining = math.ceil(remainingOutput / outputPerCraft)
    return craftsRemaining, remainingOutput
end

local function GetEntryConcentrationCost(entry)
    if not entry or entry.applyConcentration ~= true then
        return 0
    end

    local storedCost = tonumber(entry.concentrationCost)
    if storedCost and storedCost > 0 then
        return storedCost
    end

    if type(C_TradeSkillUI) ~= "table"
        or type(C_TradeSkillUI.GetCraftingOperationInfo) ~= "function"
        or not entry.recipeID then
        return 0
    end

    local operationInfo = SafeCall(
        C_TradeSkillUI.GetCraftingOperationInfo,
        entry.recipeID,
        NormalizeCraftingReagents(entry.craftingReagents),
        nil,
        false
    )
    return math.max(0, tonumber(operationInfo and operationInfo.concentrationCost) or 0)
end

local function GetQueuedConcentrationReservation()
    EnsureDB()
    local reserved = 0
    for _, entry in ipairs(db.queue) do
        reserved = reserved + GetEntryCraftsRemaining(entry) * GetEntryConcentrationCost(entry)
    end
    return reserved
end

local function GetNextQueueEntry()
    EnsureDB()
    local currentProfessionID = GetCurrentProfessionID and GetCurrentProfessionID() or nil
    local bestEntry
    local bestCraftsRemaining
    local bestIndex

    for index, entry in ipairs(db.queue) do
        local craftsRemaining = GetEntryCraftsRemaining(entry)
        if craftsRemaining > 0 then
            local entryProfessionID = tonumber(entry.professionID) or nil
            local bestProfessionID = bestEntry and tonumber(bestEntry.professionID) or nil
            local entryMatchesOpenProfession = currentProfessionID ~= nil and entryProfessionID == currentProfessionID
            local bestMatchesOpenProfession = currentProfessionID ~= nil and bestProfessionID == currentProfessionID
            local entryProfitKnown = entry.profitKnown == true and type(entry.profitValue) == "number"
            local bestProfitKnown = bestEntry and bestEntry.profitKnown == true and type(bestEntry.profitValue) == "number"

            local shouldReplace = false
            if not bestEntry then
                shouldReplace = true
            elseif entryMatchesOpenProfession ~= bestMatchesOpenProfession then
                shouldReplace = entryMatchesOpenProfession
            elseif entryProfitKnown and bestProfitKnown and entry.profitValue ~= bestEntry.profitValue then
                shouldReplace = entry.profitValue > bestEntry.profitValue
            elseif entryProfitKnown ~= bestProfitKnown then
                shouldReplace = entryProfitKnown
            else
                shouldReplace = index < bestIndex
            end

            if shouldReplace then
                bestEntry = entry
                bestCraftsRemaining = craftsRemaining
                bestIndex = index
            end
        end
    end

    return bestEntry, bestCraftsRemaining or 0
end

local function GetSortedActiveQueueEntries()
    EnsureDB()

    local currentProfessionID = GetCurrentProfessionID and GetCurrentProfessionID() or nil
    local candidates = {}

    for index, entry in ipairs(db.queue) do
        local craftsRemaining, remainingCount = GetEntryCraftsRemaining(entry)
        if craftsRemaining > 0 then
            candidates[#candidates + 1] = {
                entry = entry,
                craftsRemaining = craftsRemaining,
                remainingCount = remainingCount,
                index = index,
                matchesOpenProfession = currentProfessionID ~= nil and (tonumber(entry.professionID) or nil) == currentProfessionID,
                hasKnownProfit = entry.profitKnown == true and type(entry.profitValue) == "number",
            }
        end
    end

    table.sort(candidates, function(left, right)
        if left.matchesOpenProfession ~= right.matchesOpenProfession then
            return left.matchesOpenProfession
        end
        if left.hasKnownProfit and right.hasKnownProfit and left.entry.profitValue ~= right.entry.profitValue then
            return left.entry.profitValue > right.entry.profitValue
        end
        if left.hasKnownProfit ~= right.hasKnownProfit then
            return left.hasKnownProfit
        end
        return left.index < right.index
    end)

    return candidates
end

local function GetEntryResourceState(entry)
    local mailboxTasks = {}
    local vendorTasks = {}
    local auctionTasks = {}

    if type(entry) ~= "table" then
        return mailboxTasks, vendorTasks, auctionTasks
    end

    for _, reagent in ipairs(entry.reagents or {}) do
        local itemID = tonumber(reagent.itemID) or 0
        local quantity = math.max(0, tonumber(reagent.quantity) or 0)
        if itemID > 0 and quantity > 0 then
            local owned = GetOwnedCount(itemID)
            local mailbox = GetMailboxCount(itemID)
            DebugPrintReagentCount("entry-resource", itemID, quantity, mailbox)
            local missing = math.max(0, quantity - owned)
            local mailboxMissing = math.min(missing, mailbox)
            local remainingMissing = math.max(0, missing - mailboxMissing)
            local task = {
                itemID = itemID,
                name = GetItemName(itemID),
                needed = quantity,
                owned = owned,
                mailbox = mailbox,
            }
            if mailboxMissing > 0 then
                task.missing = mailboxMissing
                mailboxTasks[#mailboxTasks + 1] = task
            end
            if remainingMissing > 0 then
                task = {
                    itemID = itemID,
                    name = GetItemName(itemID),
                    needed = quantity,
                    owned = owned,
                    mailbox = mailbox,
                    missing = remainingMissing,
                }
                if IsKnownVendorItem(itemID) then
                    vendorTasks[#vendorTasks + 1] = task
                else
                    auctionTasks[#auctionTasks + 1] = task
                end
            end
        end
    end

    SortTaskList(mailboxTasks)
    SortTaskList(vendorTasks)
    SortTaskList(auctionTasks)
    return mailboxTasks, vendorTasks, auctionTasks
end

local function BuildQueueSummary()
    EnsureDB()

    local summary = {
        craftTasks = {},
        mailboxTasks = {},
        auctionTasks = {},
        vendorTasks = {},
    }
    local neededByItemID = {}

    for _, entry in ipairs(db.queue) do
        if entry.queueKind == "direct_item" then
            local itemID = tonumber(entry.itemID) or 0
            local quantity = ClampQuantity(entry.directQuantity or 1)
            if itemID > 0 and quantity > 0 then
                WarmItemData(itemID)
                if not neededByItemID[itemID] then
                    neededByItemID[itemID] = {
                        itemID = itemID,
                        name = entry.itemName or GetItemName(itemID),
                        needed = 0,
                    }
                end
                neededByItemID[itemID].needed = neededByItemID[itemID].needed + quantity
            end
        end
    end

    for _, candidate in ipairs(GetSortedActiveQueueEntries()) do
        local entry = candidate.entry
        local mode = NormalizeQueueMode(entry.mode)
        local craftsRemaining, remainingCount = candidate.craftsRemaining, candidate.remainingCount

        if craftsRemaining > 0 then
            table.insert(summary.craftTasks, {
                recipeID = entry.recipeID,
                name = entry.recipeName or ("Recette " .. tostring(entry.recipeID)),
                remainingCount = remainingCount,
                mode = mode,
                targetQuality = entry.targetQuality,
                targetQualitySimplified = entry.targetQualitySimplified == true,
            })

            for _, reagent in ipairs(entry.reagents or {}) do
                if type(reagent.itemID) == "number" and reagent.itemID > 0 and (reagent.quantity or 0) > 0 then
                    WarmItemData(reagent.itemID)
                    if not neededByItemID[reagent.itemID] then
                        neededByItemID[reagent.itemID] = {
                            itemID = reagent.itemID,
                            name = GetItemName(reagent.itemID),
                            needed = 0,
                        }
                    end
                    neededByItemID[reagent.itemID].needed = neededByItemID[reagent.itemID].needed + (craftsRemaining * reagent.quantity)
                end
            end
        end
    end

    for itemID, task in pairs(neededByItemID) do
        task.name = GetItemName(itemID)
        task.owned = GetOwnedCount(itemID)
        task.mailbox = GetMailboxCount(itemID)
        DebugPrintReagentCount("queue-summary", itemID, task.needed, task.mailbox)
        task.missing = math.max(0, task.needed - task.owned)
        if task.missing > 0 then
            local mailboxMissing = math.min(task.missing, task.mailbox or 0)
            local remainingMissing = math.max(0, task.missing - mailboxMissing)
            if mailboxMissing > 0 then
                table.insert(summary.mailboxTasks, {
                    itemID = task.itemID,
                    name = task.name,
                    needed = task.needed,
                    owned = task.owned,
                    mailbox = task.mailbox,
                    missing = mailboxMissing,
                })
            end
            if remainingMissing > 0 then
                task.missing = remainingMissing
            else
                task.missing = 0
            end
        end
        if task.missing > 0 then
            if IsKnownVendorItem(itemID) then
                table.insert(summary.vendorTasks, task)
            else
                table.insert(summary.auctionTasks, task)
            end
        end
    end

    SortTaskList(summary.mailboxTasks)
    SortTaskList(summary.auctionTasks)
    SortTaskList(summary.vendorTasks)
    return summary
end

local function BuildCraftLines(summary)
    local lines = {}

    for _, task in ipairs(summary.mailboxTasks) do
        table.insert(lines, "Mailbox " .. task.missing .. "x " .. task.name)
    end
    for _, task in ipairs(summary.auctionTasks) do
        table.insert(lines, "HV " .. task.missing .. "x " .. task.name)
    end
    for _, task in ipairs(summary.vendorTasks) do
        table.insert(lines, "Marchand " .. task.missing .. "x " .. task.name)
    end
    for _, task in ipairs(summary.craftTasks) do
        local qualityText = task.targetQuality and (
            " " .. YQQuality.GetQualityIcon(task.targetQuality, 16, task.targetQualitySimplified)
        ) or ""
        table.insert(lines, "Craft " .. task.remainingCount .. "x " .. task.name .. qualityText)
    end

    if #lines == 0 then
        lines[1] = "Queue vide"
    end

    return lines
end

local function ConsumeCraftFromQueue(recipeID)
    if type(recipeID) ~= "number" or recipeID <= 0 then
        return nil
    end

    EnsureDB()

    for index, entry in ipairs(db.queue) do
        if entry.recipeID == recipeID then
            local recipeName = entry.recipeName
            if entry.queueKind == "patron" and entry.orderID then
                entry.pendingSubmit = true
                entry.craftQty = math.max(1, ClampQuantity(entry.craftQty or 1))
                return recipeName
            end

            if NormalizeQueueMode(entry.mode) == "output" then
                local remainingOutput = ClampQuantity(entry.outputQty or 1) - math.max(1, tonumber(entry.outputPerCraft) or 1)
                if remainingOutput > 0 then
                    entry.outputQty = remainingOutput
                else
                    table.remove(db.queue, index)
                end
            else
                local remaining = ClampQuantity(entry.craftQty or 1) - 1
                if remaining > 0 then
                    entry.craftQty = remaining
                else
                    table.remove(db.queue, index)
                end
            end
            return recipeName
        end
    end

    return nil
end

local function ConsumeMatchedQueueEntry(index, entry, entryData)
    local recipeName = entry.recipeName or (entryData and entryData.recipeName)
    if entry.queueKind == "patron" and entry.orderID then
        entry.pendingSubmit = true
        entry.craftQty = math.max(1, ClampQuantity(entry.craftQty or 1))
        return recipeName
    end

    if NormalizeQueueMode(entry.mode) == "output" then
        local remainingOutput = ClampQuantity(entry.outputQty or 1) - math.max(1, tonumber(entry.outputPerCraft) or 1)
        if remainingOutput > 0 then
            entry.outputQty = remainingOutput
        else
            table.remove(db.queue, index)
        end
    else
        local remaining = ClampQuantity(entry.craftQty or 1) - 1
        if remaining > 0 then
            entry.craftQty = remaining
        else
            table.remove(db.queue, index)
        end
    end

    return recipeName
end

local function ConsumeCraftEntry(entryData)
    if type(entryData) ~= "table" then
        return nil
    end

    EnsureDB()
    local isPatronEntry = entryData.queueKind == "patron"
    local expectedOrderID = tonumber(entryData.orderID) or 0

    for index, entry in ipairs(db.queue) do
        local sameOrder = expectedOrderID > 0 and (tonumber(entry.orderID) or 0) == expectedOrderID
        local sameRecipe = (tonumber(entry.recipeID) or 0) > 0 and (tonumber(entry.recipeID) or 0) == (tonumber(entryData.recipeID) or 0)
        local sameConcentration = NormalizeApplyConcentration(entry.applyConcentration) == NormalizeApplyConcentration(entryData.applyConcentration)
        local sameKind = entry.queueKind == entryData.queueKind

        if sameOrder or (not isPatronEntry and sameRecipe and sameConcentration and sameKind) then
            return ConsumeMatchedQueueEntry(index, entry, entryData)
        end
    end

    if isPatronEntry then
        DebugPrint("consume-miss kind=patron order=" .. tostring(expectedOrderID) .. " recipe=" .. tostring(entryData.recipeID))
    end

    return nil
end

local function ConsumePatronSubmit(orderID)
    orderID = tonumber(orderID) or 0
    if orderID <= 0 then
        return nil
    end

    EnsureDB()

    for index, entry in ipairs(db.queue) do
        if entry.queueKind == "patron" and entry.orderID == orderID then
            local recipeName = entry.recipeName
            table.remove(db.queue, index)
            return recipeName
        end
    end

    return nil
end

GetCurrentProfessionID = function()
    local ordersPage = ProfessionsFrame and ProfessionsFrame.OrdersPage
    local professionInfo = ordersPage and ordersPage.professionInfo
    if professionInfo and professionInfo.profession then
        return professionInfo.profession
    end

    if type(C_TradeSkillUI) == "table" and type(C_TradeSkillUI.GetChildProfessionInfo) == "function" then
        professionInfo = C_TradeSkillUI.GetChildProfessionInfo()
        if professionInfo and professionInfo.profession then
            return professionInfo.profession
        end
    end

    if type(C_TradeSkillUI) == "table" and type(C_TradeSkillUI.GetBaseProfessionInfo) == "function" then
        professionInfo = C_TradeSkillUI.GetBaseProfessionInfo()
        if professionInfo and professionInfo.profession then
            return professionInfo.profession
        end
    end

    return nil
end

local function HandlePatronFulfill(orderID, source)
    orderID = tonumber(orderID) or 0
    if orderID <= 0 then
        return nil
    end

    local recipeName = ConsumePatronSubmit(orderID)
    local nextActionLock = GetNextActionLock()
    if nextActionLock and nextActionLock.orderID == orderID and nextActionLock.action == "complete" then
        ClearNextActionLock("fulfilled")
    end
    MarkRecentCompletedPatronOrder(orderID)
    DebugPrint("fulfill-hook source=" .. tostring(source or "?") .. " order=" .. tostring(orderID) .. " matched=" .. tostring(recipeName))
    if recipeName then
        state.ah.statusMessage = "Commande terminee: " .. recipeName
        ScheduleRefresh()
    end

    return recipeName
end

local function GetCurrentOrderViewContext()
    local ordersPage = ProfessionsFrame and ProfessionsFrame.OrdersPage
    local orderView = ordersPage and ordersPage.OrderView
    return orderView, orderView and orderView.order
end

local function GetCurrentOrderSchematicContext()
    local orderView, orderInfo = GetCurrentOrderViewContext()
    local orderDetails = orderView and orderView.OrderDetails
    local schematicForm = orderDetails and orderDetails.SchematicForm
    local transaction = schematicForm and ((type(schematicForm.GetTransaction) == "function" and schematicForm:GetTransaction()) or schematicForm.transaction)
    return orderView, orderInfo, schematicForm, transaction
end

local function GetOrderReagentItemID(reagentInfo)
    if type(reagentInfo) ~= "table" then
        return nil
    end

    if reagentInfo.reagent then
        if reagentInfo.reagent.reagent and reagentInfo.reagent.reagent.itemID then
            return reagentInfo.reagent.reagent.itemID
        end
        if reagentInfo.reagent.itemID then
            return reagentInfo.reagent.itemID
        end
    end

    if reagentInfo.reagentInfo and reagentInfo.reagentInfo.reagent and reagentInfo.reagentInfo.reagent.itemID then
        return reagentInfo.reagentInfo.reagent.itemID
    end

    return nil
end

local function FilterSuppliedOrderReagents(craftingReagentInfoTbl, orderInfo)
    if type(craftingReagentInfoTbl) ~= "table" or type(orderInfo) ~= "table" or type(orderInfo.reagents) ~= "table" then
        return craftingReagentInfoTbl
    end

    local suppliedIDs = {}
    for _, reagentInfo in ipairs(orderInfo.reagents) do
        local itemID = GetOrderReagentItemID(reagentInfo)
        if type(itemID) == "number" and itemID > 0 then
            suppliedIDs[itemID] = true
        end
    end

    if not next(suppliedIDs) then
        return craftingReagentInfoTbl
    end

    local filtered = {}
    for _, craftingReagentInfo in ipairs(craftingReagentInfoTbl) do
        local itemID = craftingReagentInfo and craftingReagentInfo.reagent and craftingReagentInfo.reagent.itemID or nil
        if not suppliedIDs[itemID] then
            filtered[#filtered + 1] = craftingReagentInfo
        end
    end
    return filtered
end

local function GetCurrentCraftingSchematicContext()
    local craftingPage = ProfessionsFrame and ProfessionsFrame.CraftingPage
    local schematicForm = craftingPage and craftingPage.SchematicForm
    local recipeInfo = schematicForm and type(schematicForm.GetRecipeInfo) == "function" and SafeCall(schematicForm.GetRecipeInfo, schematicForm) or nil
    local transaction = schematicForm and ((type(schematicForm.GetTransaction) == "function" and SafeCall(schematicForm.GetTransaction, schematicForm)) or schematicForm.transaction) or nil
    return craftingPage, recipeInfo, schematicForm, transaction
end

local function FindTransactionReagent(transaction, allocation)
    if not (transaction and allocation and allocation.slotIndex) then
        return nil
    end
    local schematic = type(transaction.GetReagentSlotSchematic) == "function"
        and SafeCall(transaction.GetReagentSlotSchematic, transaction, allocation.slotIndex)
        or nil
    for _, reagent in ipairs(schematic and schematic.reagents or {}) do
        if allocation.itemID and reagent.itemID == allocation.itemID then
            return reagent
        end
        if allocation.currencyID and reagent.currencyID == allocation.currencyID then
            return reagent
        end
    end
    return nil
end

local function ApplyQueuedSlotAllocations(transaction, schematicForm, clearSlotIndices, slotAllocations)
    if not transaction then
        return false
    end
    if #(clearSlotIndices or {}) == 0 and #(slotAllocations or {}) == 0 then
        if type(transaction.SetManuallyAllocated) == "function"
            and not pcall(transaction.SetManuallyAllocated, transaction, false) then
            return false
        end
        if type(Professions) == "table" and type(Professions.AllocateAllBasicReagents) == "function" then
            local useBestQuality = type(Professions.ShouldAllocateBestQualityReagents) == "function"
                and SafeCall(Professions.ShouldAllocateBestQualityReagents) == true
            return pcall(Professions.AllocateAllBasicReagents, transaction, useBestQuality)
        end
        return true
    end

    local checkbox = schematicForm and schematicForm.AllocateBestQualityCheckbox
    if checkbox and type(checkbox.SetChecked) == "function" then
        if not pcall(checkbox.SetChecked, checkbox, false) then
            return false
        end
    end
    if type(Professions) == "table" and type(Professions.SetShouldAllocateBestQualityReagents) == "function" then
        pcall(Professions.SetShouldAllocateBestQualityReagents, false)
    end
    if type(transaction.SetManuallyAllocated) == "function" then
        if not pcall(transaction.SetManuallyAllocated, transaction, true) then
            return false
        end
    end

    local clearedSlots = {}
    for _, slotIndex in ipairs(clearSlotIndices or {}) do
        local allocations = type(transaction.GetAllocations) == "function"
            and SafeCall(transaction.GetAllocations, transaction, slotIndex)
            or nil
        local cleared = false
        if allocations and type(allocations.Clear) == "function" then
            cleared = pcall(allocations.Clear, allocations)
        elseif type(transaction.ClearAllocations) == "function" then
            cleared = pcall(transaction.ClearAllocations, transaction, slotIndex)
        end
        if not cleared then
            return false
        end
        clearedSlots[slotIndex] = true
    end

    for _, allocation in ipairs(slotAllocations or {}) do
        local slotIndex = allocation.slotIndex
        local allocations = type(transaction.GetAllocations) == "function"
            and SafeCall(transaction.GetAllocations, transaction, slotIndex)
            or nil
        if not clearedSlots[slotIndex] then
            if allocations and type(allocations.Clear) == "function" then
                if not pcall(allocations.Clear, allocations) then
                    return false
                end
            elseif type(transaction.ClearAllocations) == "function" then
                if not pcall(transaction.ClearAllocations, transaction, slotIndex) then
                    return false
                end
            else
                return false
            end
            clearedSlots[slotIndex] = true
        end

        local reagent = FindTransactionReagent(transaction, allocation)
        if not reagent then
            return false
        end
        if allocations and type(allocations.Allocate) == "function" then
            if not pcall(allocations.Allocate, allocations, reagent, allocation.quantity) then
                return false
            end
        elseif type(transaction.OverwriteAllocation) == "function" then
            if not pcall(transaction.OverwriteAllocation, transaction, slotIndex, reagent, allocation.quantity) then
                return false
            end
        else
            return false
        end
    end
    return true
end

local function ApplyQueuedRecipeConfigNow()
    local pending = state.pendingQueuedRecipeConfig
    if not pending then
        return true
    end

    local _, recipeInfo, schematicForm, transaction = GetCurrentCraftingSchematicContext()
    if not (recipeInfo and schematicForm and transaction and recipeInfo.recipeID == pending.recipeID) then
        return false
    end
    if type(transaction.GetRecipeID) == "function" and SafeCall(transaction.GetRecipeID, transaction) ~= pending.recipeID then
        return false
    end

    if type(transaction.SetApplyConcentration) == "function" then
        if not pcall(transaction.SetApplyConcentration, transaction, pending.applyConcentration == true) then
            return false
        end
    end
    if not ApplyQueuedSlotAllocations(transaction, schematicForm, pending.clearSlotIndices, pending.slotAllocations) then
        return false
    end
    if type(schematicForm.TriggerEvent) == "function"
        and type(ProfessionsRecipeSchematicFormMixin) == "table"
        and ProfessionsRecipeSchematicFormMixin.Event
        and ProfessionsRecipeSchematicFormMixin.Event.AllocationsModified then
        pcall(schematicForm.TriggerEvent, schematicForm, ProfessionsRecipeSchematicFormMixin.Event.AllocationsModified)
    end
    if type(schematicForm.UpdateDetailsStats) == "function" then
        pcall(schematicForm.UpdateDetailsStats, schematicForm)
    end
    if type(schematicForm.UpdateAllSlots) == "function" then
        pcall(schematicForm.UpdateAllSlots, schematicForm)
    end

    state.pendingQueuedRecipeConfig = nil
    return true
end

local function ScheduleApplyQueuedRecipeConfig(delay)
    if not state.pendingQueuedRecipeConfig or state.pendingQueuedRecipeConfig.timerQueued then
        return
    end

    state.pendingQueuedRecipeConfig.timerQueued = true
    C_Timer.After(delay or 0, function()
        if not state.pendingQueuedRecipeConfig then
            return
        end
        state.pendingQueuedRecipeConfig.timerQueued = nil
        local applyCallOK, applied = pcall(ApplyQueuedRecipeConfigNow)
        if applyCallOK and applied then
            ScheduleRefresh()
            return
        end

        state.pendingQueuedRecipeConfig.attempts = (state.pendingQueuedRecipeConfig.attempts or 0) + 1
        if state.pendingQueuedRecipeConfig.attempts < 20 then
            ScheduleApplyQueuedRecipeConfig(0.05)
        else
            state.pendingQueuedRecipeConfig.failed = true
            state.ah.statusMessage = "Plan de composants non applique; /reload puis reouvre la recette"
            ScheduleRefresh()
        end
    end)
end

local function GetPatronNextButtonState()
    local entry = GetNextQueueEntry()
    if not entry then
        return nil
    end

    local nextActionLock = GetNextActionLock()

    if entry.queueKind ~= "patron" then
        if nextActionLock then
            return {
                entry = entry,
                text = "Next: attente",
                enabled = false,
            }
        end
        local mailboxTasks, vendorTasks, auctionTasks = GetEntryResourceState(entry)
        if #mailboxTasks > 0 then
            return {
                entry = entry,
                text = "Next: Mailbox",
                enabled = true,
                action = "mailbox",
            }
        end
        if #vendorTasks > 0 or #auctionTasks > 0 then
            return {
                entry = entry,
                text = "Next: materiaux",
                enabled = false,
            }
        end

        local currentProfessionID = GetCurrentProfessionID()
        local _, currentRecipeInfo = GetCurrentCraftingSchematicContext()
        local currentRecipeID = currentRecipeInfo and currentRecipeInfo.recipeID or nil
        local craftingPageVisible = IsProfessionPageVisible(ProfessionsFrame and ProfessionsFrame.CraftingPage)

        if not craftingPageVisible or currentProfessionID ~= entry.professionID or currentRecipeID ~= entry.recipeID then
            return {
                entry = entry,
                text = "Next: Open",
                enabled = entry.professionID and entry.recipeID and type(C_TradeSkillUI) == "table",
                action = "open_recipe",
            }
        end

        if state.pendingQueuedRecipeConfig and state.pendingQueuedRecipeConfig.recipeID == entry.recipeID then
            return {
                entry = entry,
                text = state.pendingQueuedRecipeConfig.failed and "Next: erreur composants" or "Next: attente",
                enabled = false,
            }
        end

        if IsCraftClickLocked() then
            return {
                entry = entry,
                text = "Next: attente",
                enabled = false,
            }
        end

        local _, _, schematicForm, transaction = GetCurrentCraftingSchematicContext()
        local hasCraftInfo = schematicForm
            and transaction
            and type(transaction.CreateCraftingReagentInfoTbl) == "function"
            and type(C_TradeSkillUI) == "table"
            and type(C_TradeSkillUI.CraftRecipe) == "function"
        local craftsRemaining = GetEntryCraftsRemaining(entry)
        local craftAmount = math.max(1, tonumber(craftsRemaining) or 1)
        if hasCraftInfo then
            return {
                entry = entry,
                text = craftAmount > 1 and ("Next: Craft x" .. craftAmount) or "Next: Craft",
                enabled = true,
                action = "craft_normal",
                craftAmount = craftAmount,
            }
        end

        return {
            entry = entry,
            text = "Next: attente",
            enabled = false,
        }
    end

    local currentProfessionID = GetCurrentProfessionID()
    if entry.professionID and currentProfessionID and entry.professionID ~= currentProfessionID then
        return {
            entry = entry,
            text = "Next: bon metier",
            enabled = false,
        }
    end

    local api = _G.YayaCraftingOrdersAPI
    if not api or type(api.ViewOrderByID) ~= "function" then
        return {
            entry = entry,
            text = "Next: YCO requis",
            enabled = false,
        }
    end

    local hasOrderAccess = not (type(C_TradeSkillUI) == "table" and type(C_TradeSkillUI.IsNearProfessionSpellFocus) == "function")
        or C_TradeSkillUI.IsNearProfessionSpellFocus(entry.professionID)
    if not hasOrderAccess then
        return {
            entry = entry,
            text = "Next: focus",
            enabled = false,
        }
    end

    local claimedOrder = type(C_CraftingOrders) == "table"
        and type(C_CraftingOrders.GetClaimedOrder) == "function"
        and C_CraftingOrders.GetClaimedOrder()
        or nil
    local _, currentOrder = GetCurrentOrderViewContext()
    local ordersPageVisible = IsProfessionPageVisible(ProfessionsFrame and ProfessionsFrame.OrdersPage)

    if nextActionLock then
        local lockedOrderID = nextActionLock.orderID
        local currentOrderID = currentOrder and currentOrder.orderID or 0
        local claimedOrderID = claimedOrder and claimedOrder.orderID or 0

        if nextActionLock.action == "open" then
            local _, _, schematicForm, transaction = GetCurrentOrderSchematicContext()
            local recipeInfo = schematicForm and type(schematicForm.GetRecipeInfo) == "function"
                and SafeCall(schematicForm.GetRecipeInfo, schematicForm)
                or schematicForm and schematicForm.currentRecipeInfo
            local transactionRecipeID = transaction and type(transaction.GetRecipeID) == "function"
                and SafeCall(transaction.GetRecipeID, transaction)
                or nil
            if ordersPageVisible
                and currentOrderID == lockedOrderID
                and recipeInfo and recipeInfo.recipeID == entry.recipeID
                and transactionRecipeID == entry.recipeID then
                ClearNextActionLock("opened")
                nextActionLock = nil
            else
                return {
                    entry = entry,
                    text = "Next: attente",
                    enabled = false,
                }
            end
        elseif nextActionLock.action == "claim" then
            if claimedOrderID == lockedOrderID then
                ClearNextActionLock("claimed")
                nextActionLock = nil
            end
        elseif nextActionLock.action == "craft" then
            if claimedOrderID == lockedOrderID and claimedOrder and claimedOrder.isFulfillable then
                ClearNextActionLock("craft-ready-complete")
                nextActionLock = nil
            elseif currentOrderID == lockedOrderID and claimedOrderID == lockedOrderID then
                return {
                    entry = entry,
                    text = "Next: attente",
                    enabled = false,
                }
            else
                ClearNextActionLock("craft-state-changed")
                nextActionLock = nil
            end
        elseif nextActionLock.action == "complete" then
            if currentOrderID == lockedOrderID or claimedOrderID == lockedOrderID then
                return {
                    entry = entry,
                    text = "Next: attente",
                    enabled = false,
                }
            end
            ClearNextActionLock("completed")
            nextActionLock = nil
        else
            return {
                entry = entry,
                text = "Next: attente",
                enabled = false,
            }
        end
    end

    local orderIsRecraft = entry.isRecraft == true
        or (currentOrder and currentOrder.isRecraft == true)
        or (claimedOrder and claimedOrder.isRecraft == true)
    if not ordersPageVisible or not (currentOrder and currentOrder.orderID == entry.orderID) then
        DebugPrint("next-state order=" .. tostring(entry.orderID) .. " state=open currentOrder=" .. tostring(currentOrder and currentOrder.orderID) .. " claimed=" .. tostring(claimedOrder and claimedOrder.orderID))
        return {
            entry = entry,
            text = "Next: Open",
            enabled = true,
            action = "open",
        }
    end

    if orderIsRecraft then
        DebugPrint("next-state order=" .. tostring(entry.orderID) .. " state=recraft")
        return {
            entry = entry,
            text = "Next: recraft",
            enabled = false,
        }
    end

    if claimedOrder and claimedOrder.orderID == entry.orderID then
        if claimedOrder.isFulfillable then
            ClearPendingWorkOrderSubmit(entry.orderID)
            DebugPrint("next-state order=" .. tostring(entry.orderID) .. " state=complete")
            return {
                entry = entry,
                text = "Next: Claim",
                enabled = entry.professionID and type(C_CraftingOrders) == "table" and type(C_CraftingOrders.FulfillOrder) == "function",
                action = "complete",
            }
        end

        if IsPendingWorkOrderSubmit(entry.orderID) or IsCraftClickLocked() then
            return {
                entry = entry,
                text = "Next: attente",
                enabled = false,
            }
        end

        local _, _, schematicForm, transaction = GetCurrentOrderSchematicContext()
        local recipeID = transaction and type(transaction.GetRecipeID) == "function" and transaction:GetRecipeID() or entry.recipeID
        local hasCraftInfo = schematicForm
            and transaction
            and type(transaction.CreateCraftingReagentInfoTbl) == "function"
            and type(C_TradeSkillUI) == "table"
            and type(C_TradeSkillUI.CraftRecipe) == "function"
            and type(recipeID) == "number"
            and recipeID > 0
        if hasCraftInfo then
            DebugPrint("next-state order=" .. tostring(entry.orderID) .. " state=craft recipe=" .. tostring(recipeID))
            return {
                entry = entry,
                text = "Next: Craft",
                enabled = true,
                action = "craft",
                recipeID = recipeID,
            }
        end
    end

    if claimedOrder then
        DebugPrint("next-state order=" .. tostring(entry.orderID) .. " state=blocked claimed=" .. tostring(claimedOrder.orderID))
        return {
            entry = entry,
            text = "Next: attente",
            enabled = false,
        }
    end

    if not (claimedOrder and claimedOrder.orderID == entry.orderID) then
        DebugPrint("next-state order=" .. tostring(entry.orderID) .. " state=claim")
        return {
            entry = entry,
            text = "Next: Start",
            enabled = entry.professionID and type(C_CraftingOrders) == "table" and type(C_CraftingOrders.ClaimOrder) == "function",
            action = "claim",
        }
    end

    return {
        entry = entry,
        text = "Next: attente",
        enabled = false,
    }
end

RunPatronNextAction = function()
    local stateInfo = GetPatronNextButtonState()
    if not stateInfo or not stateInfo.entry then
        state.ah.statusMessage = "Aucun patron order"
        ScheduleRefresh()
        return
    end

    if not stateInfo.enabled then
        state.ah.statusMessage = stateInfo.text or "Action indisponible"
        ScheduleRefresh()
        return
    end

    if stateInfo.action == "open" then
        BeginNextActionLock("open", stateInfo.entry.orderID, 1.5)
        TrySelectProfessionTab(
            (ProfessionsFrame and ProfessionsFrame.craftingOrdersTabID) or 3,
            ProfessionsFrame and ProfessionsFrame.OrdersPage
        )
        local ok, message = _G.YayaCraftingOrdersAPI.ViewOrderByID(stateInfo.entry.orderID)
        if ok then
            state.ah.statusMessage = "Order ouvert"
        else
            ClearNextActionLock("open-failed")
            state.ah.statusMessage = type(message) == "string" and message or "Order introuvable"
        end
        ScheduleRefresh()
        return
    end

    if stateInfo.action == "open_recipe" then
        local professionID = stateInfo.entry.professionID
        local recipeID = stateInfo.entry.recipeID
        state.pendingQueuedRecipeConfig = {
            recipeID = recipeID,
            applyConcentration = NormalizeApplyConcentration(stateInfo.entry.applyConcentration),
            -- CraftSim and TSM pass CraftingReagentInfo (dataSlotIndex) directly
            -- when crafting. Legacy YayaQueue plans confused it with the UI's
            -- slotIndex and could allocate two different reagents to one slot.
            slotAllocations = {},
            clearSlotIndices = {},
            attempts = 0,
        }

        -- Cancel the previous async recipe load before navigation. Blizzard can clear
        -- currentRecipeInfo without cancelling it, then run its stale callback.
        local schematicForm = GetCraftingSchematicForm()
        if schematicForm and schematicForm.loader and type(schematicForm.loader.Cancel) == "function" then
            pcall(schematicForm.loader.Cancel, schematicForm.loader)
        end

        local currentProfessionID = GetCurrentProfessionID()
        if professionID and currentProfessionID ~= professionID and type(C_TradeSkillUI.GetProfessionSkillLineID) == "function" and type(C_TradeSkillUI.OpenTradeSkill) == "function" then
            local skillLineID = C_TradeSkillUI.GetProfessionSkillLineID(professionID)
            if skillLineID then
                C_TradeSkillUI.OpenTradeSkill(skillLineID)
            end
        end
        TrySelectProfessionTab(
            (ProfessionsFrame and ProfessionsFrame.recipesTabID) or 1,
            ProfessionsFrame and ProfessionsFrame.CraftingPage
        )
        if type(C_TradeSkillUI.OpenRecipe) == "function" and recipeID then
            C_Timer.After(0, function()
                C_TradeSkillUI.OpenRecipe(recipeID)
                ScheduleApplyQueuedRecipeConfig(0)
            end)
        else
            ScheduleApplyQueuedRecipeConfig(0)
        end
        state.ah.statusMessage = "Recette ouverte"
        ScheduleRefresh()
        return
    end

    if stateInfo.action == "mailbox" then
        state.ah.statusMessage = "Recupere les items en boite aux lettres"
        ScheduleRefresh()
        return
    end

    if stateInfo.action == "claim" then
        BeginNextActionLock("claim", stateInfo.entry.orderID, 1.5)
        C_CraftingOrders.ClaimOrder(stateInfo.entry.orderID, stateInfo.entry.professionID)
        state.ah.statusMessage = "Action: Start"
        C_Timer.After(0, ScheduleRefresh)
        ScheduleRefresh()
        return
    end

    if stateInfo.action == "craft_normal" then
        local _, recipeInfo, _, transaction = GetCurrentCraftingSchematicContext()
        if not (transaction and type(transaction.CreateCraftingReagentInfoTbl) == "function") then
            state.ah.statusMessage = "Transaction indisponible"
            ScheduleRefresh()
            return
        end

        local reagentInfo = NormalizeCraftingReagents(stateInfo.entry.craftingReagents)
        if #reagentInfo == 0 then
            reagentInfo = transaction:CreateCraftingReagentInfoTbl()
        end
        local applyConcentration = NormalizeApplyConcentration(stateInfo.entry.applyConcentration)
        local craftAmount = math.max(1, math.floor(tonumber(stateInfo.craftAmount) or 1))
        local vellumLocation
        if recipeInfo and recipeInfo.isEnchantingRecipe and type(C_TradeSkillUI.CraftEnchant) == "function" then
            vellumLocation = GetItemLocationFromItemID(38682)
            if not vellumLocation then
                state.ah.statusMessage = "Vellin manquant"
                ScheduleRefresh()
                return
            end
        end

        -- Keep one batch active until its final confirmed craft, like TSM's
        -- Craft Next state. This is the durable guard against rapid repeat clicks.
        BeginNextActionLock("craft", 0, 30.0)
        BeginCraftClickLock()
        if recipeInfo and recipeInfo.isEnchantingRecipe and type(C_TradeSkillUI.CraftEnchant) == "function" then
            QueuePendingCraftEntry(stateInfo.entry, craftAmount)
            C_TradeSkillUI.CraftEnchant(stateInfo.entry.recipeID, craftAmount, reagentInfo, vellumLocation, applyConcentration)
        else
            QueuePendingCraftEntry(stateInfo.entry, craftAmount)
            C_TradeSkillUI.CraftRecipe(stateInfo.entry.recipeID, craftAmount, reagentInfo, nil, nil, applyConcentration)
        end
        state.ah.statusMessage = craftAmount > 1 and ("Action: Craft x" .. craftAmount) or "Action: Craft"
        C_Timer.After(0, ScheduleRefresh)
        ScheduleRefresh()
        return
    end

    if stateInfo.action == "craft" then
        local _, currentOrder, schematicForm, transaction = GetCurrentOrderSchematicContext()
        local currentClaimedOrder = type(C_CraftingOrders) == "table"
            and type(C_CraftingOrders.GetClaimedOrder) == "function"
            and C_CraftingOrders.GetClaimedOrder()
            or nil
        if not (currentOrder and currentOrder.orderID == stateInfo.entry.orderID and currentClaimedOrder and currentClaimedOrder.orderID == stateInfo.entry.orderID) then
            state.ah.statusMessage = "Order non pret"
            ScheduleRefresh()
            return
        end
        if IsPendingWorkOrderSubmit(stateInfo.entry.orderID) or IsCraftClickLocked() then
            ScheduleRefresh()
            return
        end
        if not (schematicForm and transaction and type(transaction.CreateCraftingReagentInfoTbl) == "function") then
            state.ah.statusMessage = "Transaction indisponible"
            ScheduleRefresh()
            return
        end

        local recipeID = stateInfo.recipeID or (type(transaction.GetRecipeID) == "function" and transaction:GetRecipeID()) or stateInfo.entry.recipeID
        local reagentInfo = transaction:CreateCraftingReagentInfoTbl()
        reagentInfo = FilterSuppliedOrderReagents(reagentInfo, currentOrder)
        local applyConcentration = type(transaction.IsApplyingConcentration) == "function" and transaction:IsApplyingConcentration() or false

        BeginNextActionLock("craft", stateInfo.entry.orderID, 8.0)
        MarkPendingWorkOrderSubmit(stateInfo.entry.orderID)
        BeginCraftClickLock()
        QueuePendingCraftEntry(stateInfo.entry)
        C_TradeSkillUI.CraftRecipe(recipeID, 1, reagentInfo, nil, stateInfo.entry.orderID, applyConcentration)
        state.ah.statusMessage = "Action: Craft"
        C_Timer.After(0, ScheduleRefresh)
        ScheduleRefresh()
        return
    end

    if stateInfo.action == "complete" then
        BeginNextActionLock("complete", stateInfo.entry.orderID, 3.0)
        BeginCraftClickLock()
        ClearPendingWorkOrderSubmit(stateInfo.entry.orderID)
        C_CraftingOrders.FulfillOrder(stateInfo.entry.orderID, "", stateInfo.entry.professionID)
        state.ah.statusMessage = "Action: Claim"
        C_Timer.After(0, ScheduleRefresh)
        ScheduleRefresh()
        return
    end
end

local TSM_MACRO_NAME = "TSMMacro"
local TSM_BUY_BUTTON = "TSMShoppingBuyoutBtn"
local TSM_CRAFT_BUTTON = "TSMCraftingBtn"
local YQ_TSM_BUY_BUTTON = "YQTSMBuy"
local YQ_TSM_CRAFT_BUTTON = "YQTSMNext"

local function ClickExistingButton(name)
    local button = _G[name]
    if button and type(button.Click) == "function" then
        pcall(button.Click, button)
    end
end

local function IsYayaAuctionContextActive()
    return AuctionHouseFrame
        and AuctionHouseFrame:IsShown()
        and state.ah.frame
        and state.ah.frame:IsShown()
end

local function IsYayaCraftContextActive()
    return ProfessionsFrame
        and ProfessionsFrame:IsShown()
        and state.craft.panel
        and state.craft.panel:IsShown()
        and state.craft.nextButton
        and state.craft.nextButton:IsShown()
end

local function CreateTSMMacroBridgeButton(name, onClick)
    local button = _G[name] or CreateFrame("Button", name, UIParent)
    button:SetSize(1, 1)
    button:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -100, -100)
    button:SetAlpha(0)
    button:SetScript("OnClick", onClick)
    button:Show()
end

local function UpdateTSMMacroBridge()
    if InCombatLockdown and InCombatLockdown() then
        return
    end

    CreateTSMMacroBridgeButton(YQ_TSM_BUY_BUTTON, function()
        if IsYayaAuctionContextActive() then
            OnAuctionActionClick()
        else
            ClickExistingButton(TSM_BUY_BUTTON)
        end
    end)
    CreateTSMMacroBridgeButton(YQ_TSM_CRAFT_BUTTON, function()
        if IsYayaCraftContextActive() then
            RunPatronNextAction()
        else
            ClickExistingButton(TSM_CRAFT_BUTTON)
        end
    end)

    local macroName, macroIcon = GetMacroInfo(TSM_MACRO_NAME)
    if not macroName then
        return
    end

    local body = GetMacroBody(TSM_MACRO_NAME)
    if type(body) ~= "string" or body == "" then
        return
    end

    local updatedBody = body
        :gsub("/click " .. TSM_BUY_BUTTON .. "([^\r\n]*)", "/click " .. YQ_TSM_BUY_BUTTON .. "%1")
        :gsub("/click " .. TSM_CRAFT_BUTTON .. "([^\r\n]*)", "/click " .. YQ_TSM_CRAFT_BUTTON .. "%1")
    if updatedBody ~= body then
        EditMacro(TSM_MACRO_NAME, macroName, macroIcon, updatedBody)
    end
end

local function PruneSearchCache(summary)
    local activeItems = {}
    for _, task in ipairs(summary.auctionTasks) do
        activeItems[task.itemID] = true
    end

    for itemID in pairs(state.searchCache) do
        if not activeItems[itemID] then
            state.searchCache[itemID] = nil
        end
    end
end

local function ClearPendingCraftBatches()
    wipe(state.pendingCraftBatches)
end

ClearPendingCraftEntries = function()
    wipe(state.pendingCraftEntries)
end

local function QueuePendingCraftRecipe(recipeID, amount)
    recipeID = tonumber(recipeID) or 0
    amount = math.max(1, math.floor(tonumber(amount) or 1))
    if recipeID <= 0 then
        return
    end

    local batches = state.pendingCraftBatches
    local lastBatch = batches[#batches]
    if lastBatch and lastBatch.recipeID == recipeID then
        lastBatch.amount = lastBatch.amount + amount
        return
    end

    batches[#batches + 1] = {
        recipeID = recipeID,
        amount = amount,
    }
    DebugPrint("queue-recipe recipe=" .. tostring(recipeID) .. " amount=" .. tostring(amount) .. " pendingBatches=" .. tostring(#state.pendingCraftBatches))
end

local function PopPendingCraftRecipe()
    local batch = state.pendingCraftBatches[1]
    if not batch then
        return nil
    end

    local recipeID = batch.recipeID
    batch.amount = (batch.amount or 1) - 1
    if batch.amount <= 0 then
        table.remove(state.pendingCraftBatches, 1)
    end
    return recipeID
end

QueuePendingCraftEntry = function(entry, amount)
    if type(entry) ~= "table" then
        return
    end

    amount = math.max(1, math.floor(tonumber(amount) or 1))
    state.pendingCraftEntries[#state.pendingCraftEntries + 1] = {
        recipeID = tonumber(entry.recipeID) or 0,
        orderID = tonumber(entry.orderID) or 0,
        professionID = tonumber(entry.professionID) or 0,
        queueKind = entry.queueKind,
        recipeName = entry.recipeName,
        applyConcentration = NormalizeApplyConcentration(entry.applyConcentration),
        amount = amount,
    }
    DebugPrint("queue-entry recipe=" .. tostring(entry.recipeID) .. " order=" .. tostring(entry.orderID) .. " amount=" .. tostring(amount) .. " pendingEntries=" .. tostring(#state.pendingCraftEntries))
end

PopPendingCraftEntry = function()
    local batch = state.pendingCraftEntries[1]
    if not batch then
        return nil
    end

    batch.amount = (batch.amount or 1) - 1
    if batch.amount <= 0 then
        table.remove(state.pendingCraftEntries, 1)
    end

    return batch
end

local function NeedsAuctionSearch(summary)
    for _, task in ipairs(summary.auctionTasks) do
        if not state.searchCache[task.itemID] then
            return true
        end
    end
    return false
end

local function FindAuctionTask(summary, itemID)
    for _, task in ipairs(summary.auctionTasks) do
        if task.itemID == itemID then
            return task
        end
    end
    return nil
end

local function GetNextPurchasableTask(summary)
    for _, task in ipairs(summary.auctionTasks) do
        local cache = state.searchCache[task.itemID]
        if cache and cache.available and cache.available > 0 then
            return task, cache
        end
    end
    return nil, nil
end

local function SetLineText(lines, maxLines, values)
    local extra = #values - maxLines
    for index = 1, maxLines do
        local value = values[index]
        if index == maxLines and extra > 0 then
            value = "+" .. extra .. " autres"
        end
        lines[index]:SetText(value or "")
    end
end

local function BuyMerchantQuantity(index, quantity)
    local maxStack = math.max(1, GetMerchantItemMaxStackCompat(index) or quantity or 1)
    quantity = math.max(0, math.floor(tonumber(quantity) or 0))
    local purchasedQuantity = 0
    while quantity > 0 do
        local buyQuantity = math.min(quantity, maxStack)
        local ok, err = pcall(BuyMerchantItem, index, buyQuantity)
        if not ok then
            return false, err, purchasedQuantity
        end
        purchasedQuantity = purchasedQuantity + buyQuantity
        quantity = quantity - buyQuantity
    end
    return true, nil, purchasedQuantity
end

local function BuyVendorTask(itemID, quantity)
    local merchantIndex = state.merchantIndexByItemID[itemID]
    if not merchantIndex then
        return nil, "Marchand incompatible"
    end

    local _, _, _, stackSize, numAvailable = GetMerchantItemInfoCompat(merchantIndex)
    stackSize = math.max(1, tonumber(stackSize) or 1)

    local purchaseCount = math.max(1, math.ceil((tonumber(quantity) or 0) / stackSize))
    if type(numAvailable) == "number" and numAvailable >= 0 then
        purchaseCount = math.min(purchaseCount, numAvailable)
    end
    if purchaseCount <= 0 then
        return nil, "Rupture de stock"
    end

    local totalQuantity = purchaseCount * stackSize
    local ok, err, purchasedQuantity = BuyMerchantQuantity(merchantIndex, totalQuantity)
    if purchasedQuantity and purchasedQuantity > 0 then
        return purchasedQuantity
    end
    if not ok then
        return nil, "Achat bloque: " .. tostring(err)
    end
    return totalQuantity
end

local function BuyVendorTasks(tasks)
    local purchasedTypes = 0
    local purchasedQuantity = 0
    local lastError
    local purchasedItems = {}

    for _, task in ipairs(tasks or {}) do
        local quantity, err = BuyVendorTask(task.itemID, task.missing)
        if quantity then
            purchasedTypes = purchasedTypes + 1
            purchasedQuantity = purchasedQuantity + quantity
            purchasedItems[task.itemID] = true
        elseif err then
            lastError = err
        end
    end

    if purchasedTypes > 0 then
        state.ah.statusMessage = "Achats demandes: " .. purchasedQuantity .. " objets (" .. purchasedTypes .. " composants)"
    else
        state.ah.statusMessage = lastError or "Aucun achat marchand"
    end
    ScheduleRefresh()
    return purchasedItems
end

local function GetCurrentMerchantTasks(summary, excludedItems)
    local tasks = {}
    for _, task in ipairs(summary and summary.vendorTasks or {}) do
        if state.merchantIndexByItemID[task.itemID]
            and not (excludedItems and excludedItems[task.itemID])
        then
            tasks[#tasks + 1] = {
                itemID = task.itemID,
                missing = task.missing,
                name = task.name,
            }
        end
    end
    return tasks
end

local ScheduleAutoBuyVendor

local function AttemptAutoBuyVendor(generation)
    CacheMerchantItems()
    local tasks = GetCurrentMerchantTasks(BuildQueueSummary(), state.merchantAutoBuySubmitted)
    if #tasks == 0 then
        state.merchantAutoBuyRetries = state.merchantAutoBuyRetries + 1
        if state.merchantAutoBuyRetries < MERCHANT_AUTO_BUY_MAX_RETRIES then
            ScheduleAutoBuyVendor(MERCHANT_AUTO_BUY_RETRY_DELAY)
        else
            state.merchantAutoBuyAttempted = true
            DebugPrint("merchant-auto-buy no-compatible-task")
        end
        return
    end

    local ownedBefore = {}
    for _, task in ipairs(tasks) do
        ownedBefore[task.itemID] = GetImmediateOwnedCount(task.itemID)
    end

    state.merchantAutoBuyRetries = state.merchantAutoBuyRetries + 1
    state.merchantAutoBuyPending = {
        tasks = tasks,
        ownedBefore = ownedBefore,
    }
    DebugPrint("merchant-auto-buy attempt=" .. tostring(state.merchantAutoBuyRetries) .. " tasks=" .. tostring(#tasks))
    local purchasedItems = BuyVendorTasks(tasks)
    for itemID in pairs(purchasedItems) do
        state.merchantAutoBuySubmitted[itemID] = true
    end
    ScheduleAutoBuyVendor(MERCHANT_AUTO_BUY_VERIFY_DELAY)
end

local function VerifyAutoBuyVendor(generation)
    if generation ~= state.merchantAutoBuyGeneration
        or not state.merchantAutoBuyPending
        or not MerchantFrame
        or not MerchantFrame:IsShown()
    then
        return
    end

    CacheMerchantItems()
    local pending = state.merchantAutoBuyPending
    local remainingTasks = GetCurrentMerchantTasks(BuildQueueSummary(), state.merchantAutoBuySubmitted)
    local received = false
    for _, task in ipairs(pending.tasks) do
        local currentOwned = GetImmediateOwnedCount(task.itemID)
        if currentOwned > (pending.ownedBefore[task.itemID] or 0) then
            received = true
            break
        end
    end

    state.merchantAutoBuyPending = nil
    if #remainingTasks == 0 then
        state.merchantAutoBuyAttempted = true
        DebugPrint("merchant-auto-buy success")
        return
    end

    if received then
        DebugPrint("merchant-auto-buy partial-success remaining=" .. tostring(#remainingTasks))
    else
        DebugPrint("merchant-auto-buy no-bag-change remaining=" .. tostring(#remainingTasks))
    end

    if state.merchantAutoBuyRetries < MERCHANT_AUTO_BUY_MAX_RETRIES then
        ScheduleAutoBuyVendor(MERCHANT_AUTO_BUY_RETRY_DELAY)
    else
        state.merchantAutoBuyAttempted = true
        DebugPrint("merchant-auto-buy retry-limit")
    end
end

ScheduleAutoBuyVendor = function(delay)
    EnsureDB()
    if not db.autoBuyVendor
        or state.merchantAutoBuyAttempted
        or state.merchantAutoBuyScheduled
    then
        return
    end

    state.merchantAutoBuyScheduled = true
    local generation = state.merchantAutoBuyGeneration
    C_Timer.After(delay or 0.05, function()
        state.merchantAutoBuyScheduled = false
        if generation ~= state.merchantAutoBuyGeneration
            or state.merchantAutoBuyAttempted
            or not MerchantFrame
            or not MerchantFrame:IsShown()
        then
            return
        end

        if state.merchantAutoBuyPending then
            VerifyAutoBuyVendor(generation)
        else
            AttemptAutoBuyVendor(generation)
        end
    end)
end

local function QueueRecipeContext(context, qtyBox, quantityOverride)
    if not context then
        return nil
    end

    local quantity = quantityOverride and ClampQuantity(quantityOverride) or GetQuantityInput(qtyBox)
    context.professionID = tonumber(context.professionID) or GetCurrentProfessionID()
    context.applyConcentration = NormalizeApplyConcentration(context.applyConcentration)
    context.mode = "crafts"
    AddRecipeToQueue(context, quantity)
    state.ah.statusMessage = "Ajoute " .. quantity .. "x " .. context.recipeName
    ScheduleRefresh()
    return quantity
end

local function BuildCompleteRecipeReagents(schematic, craftingReagents, recipeInfo)
    local quantityByItemID = {}
    local consumedReagentInfos = {}
    local function AddItem(itemID, quantity)
        itemID = tonumber(itemID)
        quantity = math.max(0, tonumber(quantity) or 0)
        if itemID and itemID > 0 and quantity > 0 then
            quantityByItemID[itemID] = (quantityByItemID[itemID] or 0) + quantity
        end
    end

    for _, slot in ipairs(schematic and schematic.reagentSlotSchematics or {}) do
        local allowedItems = {}
        local allowedCurrencies = {}
        for _, candidate in ipairs(slot.reagents or {}) do
            local itemID = tonumber(candidate.itemID)
            local currencyID = tonumber(candidate.currencyID)
            if itemID then
                allowedItems[itemID] = true
            elseif currencyID then
                allowedCurrencies[currencyID] = true
            end
        end

        local selectedQuantity = 0
        for _, reagentInfo in ipairs(craftingReagents or {}) do
            local reagent = reagentInfo and reagentInfo.reagent
            local itemID = tonumber(reagent and reagent.itemID)
            local currencyID = tonumber(reagent and reagent.currencyID)
            if not consumedReagentInfos[reagentInfo]
                and ((itemID and allowedItems[itemID]) or (currencyID and allowedCurrencies[currencyID])) then
                consumedReagentInfos[reagentInfo] = true
                selectedQuantity = selectedQuantity + math.max(0, tonumber(reagentInfo.quantity) or 0)
                AddItem(itemID, reagentInfo.quantity)
            end
        end

        -- Some required selectable reagents (for example Mote of Primal Energy)
        -- are not exposed as CraftingReagentType.Basic. They still belong in
        -- the queue when the transaction only contains a partial allocation.
        if IsRequiredRecipeReagentSlot(slot) then
            local missingQuantity = math.max(0, (tonumber(slot.quantityRequired) or 0) - selectedQuantity)
            local fallbackReagent = slot.reagents and slot.reagents[1] or nil
            AddItem(fallbackReagent and fallbackReagent.itemID, missingQuantity)
        end
    end

    for _, reagentInfo in ipairs(craftingReagents or {}) do
        if not consumedReagentInfos[reagentInfo] then
            AddItem(reagentInfo.reagent and reagentInfo.reagent.itemID, reagentInfo.quantity)
        end
    end

    local reagents = {}
    for itemID, quantity in pairs(quantityByItemID) do
        reagents[#reagents + 1] = {
            itemID = itemID,
            quantity = quantity,
        }
    end
    table.sort(reagents, function(left, right)
        return left.itemID < right.itemID
    end)
    return AddEnchantingVellumReagent(reagents, recipeInfo)
end

local function AddVisibleRequiredReagents(schematicForm, schematic, craftingReagents)
    local slotFrames = {}
    local visitedFrames = {}
    local function Visit(frame, depth)
        if not frame or visitedFrames[frame] or depth > 4 then
            return
        end
        visitedFrames[frame] = true

        if type(frame.GetReagentSlotSchematic) == "function" and frame.Button
            and type(frame.Button.GetItemID) == "function" then
            local slot = SafeCall(frame.GetReagentSlotSchematic, frame)
            local itemID = tonumber(SafeCall(frame.Button.GetItemID, frame.Button))
            if slot and itemID and itemID > 0 then
                slotFrames[#slotFrames + 1] = {
                    itemID = itemID,
                    slotIndex = tonumber(slot.slotIndex),
                    dataSlotIndex = tonumber(slot.dataSlotIndex),
                }
            end
        end

        if type(frame.GetChildren) == "function" then
            for _, child in ipairs({ frame:GetChildren() }) do
                Visit(child, depth + 1)
            end
        end
    end

    Visit(schematicForm and schematicForm.Reagents, 0)
    Visit(schematicForm and schematicForm.OptionalReagents, 0)
    for _, frame in ipairs((schematicForm and schematicForm.extraSlotFrames) or {}) do
        Visit(frame, 0)
    end
    Visit(schematicForm, 0)

    for _, slot in ipairs(schematic and schematic.reagentSlotSchematics or {}) do
        local dataSlotIndex = tonumber(slot.dataSlotIndex)
        local requiredQuantity = math.max(0, tonumber(slot.quantityRequired) or 0)
        local allowedItems = {}
        local allocatedQuantity = 0
        for _, candidate in ipairs(slot.reagents or {}) do
            local itemID = tonumber(candidate.itemID)
            if itemID then
                allowedItems[itemID] = true
            end
        end
        for _, reagentInfo in ipairs(craftingReagents or {}) do
            local itemID = tonumber(reagentInfo and reagentInfo.reagent and reagentInfo.reagent.itemID)
            if itemID and allowedItems[itemID] then
                allocatedQuantity = allocatedQuantity + math.max(0, tonumber(reagentInfo.quantity) or 0)
            end
        end
        local missingQuantity = dataSlotIndex and math.max(0, requiredQuantity - allocatedQuantity) or 0
        -- Blizzard returns nil from GetCraftingOperationInfo when a normal
        -- non-quality required reagent is included. Only required-selectable
        -- slots need to be restored here, matching CraftSim's reagent model.
        if IsRequiredSelectableReagentSlot(slot) and missingQuantity > 0 then
            local selectedItemID
            for _, slotFrame in ipairs(slotFrames) do
                local indexMatches = slotFrame.dataSlotIndex == dataSlotIndex
                    or slotFrame.slotIndex == tonumber(slot.slotIndex)
                if allowedItems[slotFrame.itemID] and (indexMatches or selectedItemID == nil) then
                    selectedItemID = slotFrame.itemID
                    if indexMatches then
                        break
                    end
                end
            end

            if selectedItemID then
                craftingReagents[#craftingReagents + 1] = {
                    dataSlotIndex = dataSlotIndex,
                    reagent = { itemID = selectedItemID },
                    quantity = missingQuantity,
                }
            end
        end
    end
    return craftingReagents
end

local function GetConcentrationDumpState(schematicForm)
    if not schematicForm or type(C_TradeSkillUI) ~= "table" then
        return nil
    end

    local transaction = (type(schematicForm.GetTransaction) == "function"
        and SafeCall(schematicForm.GetTransaction, schematicForm)) or schematicForm.transaction
    local context = GetRecipeContextFromSchematicForm(schematicForm)
    local recipeID = context and context.recipeID or nil
    local recipeInfo = recipeID and SafeCall(C_TradeSkillUI.GetRecipeInfo, recipeID) or nil
    local recipeLevel = type(schematicForm.GetCurrentRecipeLevel) == "function"
        and SafeCall(schematicForm.GetCurrentRecipeLevel, schematicForm) or nil
    local schematic = recipeID and SafeCall(C_TradeSkillUI.GetRecipeSchematic, recipeID, false, recipeLevel) or nil
    local craftingReagents = transaction and type(transaction.CreateCraftingReagentInfoTbl) == "function"
        and SafeCall(transaction.CreateCraftingReagentInfoTbl, transaction) or {}
    if type(craftingReagents) ~= "table" then
        craftingReagents = {}
    end
    craftingReagents = AddVisibleRequiredReagents(schematicForm, schematic, craftingReagents)

    local allocationItemGUID = transaction and type(transaction.GetAllocationItemGUID) == "function"
        and SafeCall(transaction.GetAllocationItemGUID, transaction) or nil
    local operationInfo = recipeID and type(C_TradeSkillUI.GetCraftingOperationInfo) == "function"
        and SafeCall(C_TradeSkillUI.GetCraftingOperationInfo, recipeID, craftingReagents, allocationItemGUID, false) or nil
    local concentrationCost = math.max(0, tonumber(operationInfo and operationInfo.concentrationCost) or 0)
    local currencyID = tonumber(operationInfo and operationInfo.concentrationCurrencyID)

    if not currencyID and type(C_TradeSkillUI.GetConcentrationCurrencyID) == "function" then
        local skillLineID = type(C_TradeSkillUI.GetProfessionChildSkillLineID) == "function"
            and SafeCall(C_TradeSkillUI.GetProfessionChildSkillLineID) or nil
        currencyID = skillLineID and tonumber(SafeCall(C_TradeSkillUI.GetConcentrationCurrencyID, skillLineID)) or nil
    end

    local currencyInfo = currencyID and type(C_CurrencyInfo) == "table"
        and type(C_CurrencyInfo.GetCurrencyInfo) == "function"
        and SafeCall(C_CurrencyInfo.GetCurrencyInfo, currencyID) or nil
    local available = math.max(0, tonumber(currencyInfo and currencyInfo.quantity) or 0)
    local queuedReservation = GetQueuedConcentrationReservation()
    local threshold = 500
    local availableAfterQueue = math.max(0, available - queuedReservation)
    local availableForDump = availableAfterQueue > threshold and availableAfterQueue or 0
    local maxQuantity = availableForDump > 0 and concentrationCost > 0
        and math.min(MAX_QUEUE_QTY, math.floor(availableForDump / concentrationCost))
        or 0

    if context then
        context.applyConcentration = true
        context.concentrationCost = concentrationCost
        context.craftingReagents = NormalizeCraftingReagents(craftingReagents)
        if type(schematic) == "table" then
            context.reagents = BuildCompleteRecipeReagents(schematic, context.craftingReagents, recipeInfo)
        end
    end

    return {
        available = available,
        queuedReservation = queuedReservation,
        threshold = threshold,
        availableForDump = availableForDump,
        cost = concentrationCost,
        maxQuantity = maxQuantity,
        context = context,
    }
end

local function IsCraftSimPriceKnown(priceData, itemID)
    local priceEntry = priceData and priceData.reagentPriceInfos and priceData.reagentPriceInfos[itemID]
    local priceInfo = priceEntry and priceEntry.priceInfo
    return type(priceEntry and priceEntry.itemPrice) == "number"
        and type(priceInfo) == "table"
        and priceInfo.noPriceSource ~= true
        and (priceInfo.noAHPriceFound ~= true or priceInfo.isOverride == true or priceInfo.isExpectedCost == true)
end

local function IsOwnedSoulboundReagent(itemID, quantity, reserved)
    local okAddon, craftSim = pcall(_G.CraftSimAPI.GetCraftSim, _G.CraftSimAPI)
    local itemUtil = okAddon and craftSim and craftSim.GUTIL or nil
    local okBound, isSoulbound = false, false
    if itemUtil and type(itemUtil.isItemSoulbound) == "function" then
        okBound, isSoulbound = pcall(itemUtil.isItemSoulbound, itemUtil, itemID)
    end
    if not okBound or not isSoulbound then
        return false
    end

    quantity = math.max(0, tonumber(quantity) or 0)
    return GetTotalOwnedCount(itemID) >= ((reserved and reserved[itemID] or 0) + quantity)
end

local function GetUsableCraftSimReagentPrice(priceData, itemID, quantity, reserved)
    local priceEntry = priceData and priceData.reagentPriceInfos and priceData.reagentPriceInfos[itemID]
    if IsCraftSimPriceKnown(priceData, itemID) then
        return priceEntry.itemPrice
    end
    if IsOwnedSoulboundReagent(itemID, quantity, reserved) then
        return 0
    end
    return nil
end

local function GetCraftSimItemPrice(itemID)
    if type(_G.CraftSimAPI) ~= "table" or type(_G.CraftSimAPI.GetCraftSim) ~= "function" then
        return nil
    end
    local okAddon, craftSim = pcall(_G.CraftSimAPI.GetCraftSim, _G.CraftSimAPI)
    local priceSource = okAddon and craftSim and craftSim.PRICE_SOURCE or nil
    if not priceSource or type(priceSource.GetMinBuyoutByItemID) ~= "function" then
        return nil
    end
    local okPrice, price, priceInfo = pcall(priceSource.GetMinBuyoutByItemID, priceSource, itemID, true)
    if not okPrice then
        return nil
    end
    local syntheticPriceData = {
        reagentPriceInfos = {
            [itemID] = { itemPrice = price, priceInfo = priceInfo },
        },
    }
    return IsCraftSimPriceKnown(syntheticPriceData, itemID) and tonumber(price) or nil
end

local function SelectKnownCraftSimReagents(recipeData, reserved)
    local priceData = recipeData and recipeData.priceData
    for _, reagent in ipairs(recipeData.reagentData.requiredReagents or {}) do
        if reagent.hasQuality then
            local cheapestItem
            local cheapestPrice
            for _, reagentItem in ipairs(reagent.items or {}) do
                local itemID = reagentItem.item and reagentItem.item.GetItemID and reagentItem.item:GetItemID() or nil
                local itemPrice = itemID and GetUsableCraftSimReagentPrice(
                    priceData, itemID, reagent.requiredQuantity, reserved
                ) or nil
                if itemPrice and (not cheapestPrice or itemPrice < cheapestPrice) then
                    cheapestItem = reagentItem
                    cheapestPrice = itemPrice
                end
            end
            if not cheapestItem or type(reagent.Clear) ~= "function" then
                return false
            end
            reagent:Clear()
            cheapestItem.quantity = reagent.requiredQuantity
        end
    end

    local requiredSlot = recipeData.reagentData.requiredSelectableReagentSlot
    local activeReagent = requiredSlot and requiredSlot.activeReagent
    if requiredSlot and activeReagent and activeReagent.item then
        local activeItemID = activeReagent.item:GetItemID()
        if not GetUsableCraftSimReagentPrice(priceData, activeItemID, requiredSlot.maxQuantity or 1, reserved) then
            local cheapestReagent
            local cheapestPrice
            for _, possibleReagent in ipairs(requiredSlot.possibleReagents or {}) do
                local itemID = possibleReagent.item and possibleReagent.item:GetItemID() or nil
                local itemPrice = itemID and GetUsableCraftSimReagentPrice(
                    priceData, itemID, requiredSlot.maxQuantity or 1, reserved
                ) or nil
                if itemPrice and (not cheapestPrice or itemPrice < cheapestPrice) then
                    cheapestReagent = possibleReagent
                    cheapestPrice = itemPrice
                end
            end
            if not cheapestReagent or type(requiredSlot.SetReagent) ~= "function" then
                return false
            end
            requiredSlot:SetReagent(cheapestReagent.item:GetItemID())
        end
    elseif requiredSlot and not activeReagent then
        return false
    end
    return true
end

local function GetCraftSimCooldownKey(craftSim, recipeID, cooldownData)
    local sharedCooldown = cooldownData and cooldownData.sharedCD
    local sharedMap = craftSim and craftSim.CONST and craftSim.CONST.SHARED_PROFESSION_COOLDOWNS_RECIPE_ID_MAP
    sharedCooldown = sharedCooldown or (sharedMap and sharedMap[recipeID])
    if sharedCooldown then
        return "shared:" .. tostring(sharedCooldown)
    end
    if cooldownData and cooldownData.isCooldownRecipe then
        return "recipe:" .. tostring(recipeID)
    end
    return nil
end

local function BuildQueuedCooldownReservations(craftSim)
    EnsureDB()
    local reservations = {}
    local sharedMap = craftSim and craftSim.CONST and craftSim.CONST.SHARED_PROFESSION_COOLDOWNS_RECIPE_ID_MAP
    for _, entry in ipairs(db.queue) do
        local recipeID = tonumber(entry.recipeID)
        if recipeID and not entry.pendingSubmit then
            local sharedCooldown = sharedMap and sharedMap[recipeID]
            local key = sharedCooldown and ("shared:" .. tostring(sharedCooldown)) or ("recipe:" .. recipeID)
            local craftsRemaining = GetEntryCraftsRemaining(entry)
            reservations[key] = (reservations[key] or 0) + craftsRemaining
        end
    end
    return reservations
end

local function BuildFirstCraftContext(
    recipeID, recipeInfo, professionID, currentSkillLineID, reserved, cooldownReservations, craftSim
)
    if type(_G.CraftSimAPI) ~= "table" or type(_G.CraftSimAPI.GetRecipeData) ~= "function" then
        return nil, "craftsim"
    end

    local ok, recipeData = pcall(_G.CraftSimAPI.GetRecipeData, _G.CraftSimAPI, { recipeID = recipeID })
    if not ok or type(recipeData) ~= "table" or type(recipeData.reagentData) ~= "table" then
        return nil, "incompatible"
    end
    local recipeSkillLineID = recipeData.professionData and recipeData.professionData.skillLineID
    if currentSkillLineID and recipeSkillLineID ~= currentSkillLineID then
        return nil, "incompatible"
    end
    local cooldownData = recipeData.cooldownData
    local cooldownKey = GetCraftSimCooldownKey(craftSim, recipeID, cooldownData)
    if cooldownKey then
        local okCharges, currentCharges = false, nil
        if cooldownData and type(cooldownData.GetCurrentCharges) == "function" then
            okCharges, currentCharges = pcall(cooldownData.GetCurrentCharges, cooldownData)
        end
        currentCharges = okCharges and tonumber(currentCharges) or nil
        if currentCharges == nil
            or math.floor(currentCharges) <= (cooldownReservations and cooldownReservations[cooldownKey] or 0) then
            return nil, "cooldown"
        end
    end
    if type(recipeData.SetNonQualityReagentsMax) ~= "function"
        or type(recipeData.SetCheapestQualityReagentsMax) ~= "function"
        or type(recipeData.Update) ~= "function"
        or not pcall(recipeData.SetNonQualityReagentsMax, recipeData)
        or not pcall(recipeData.SetCheapestQualityReagentsMax, recipeData) then
        return nil, "incompatible"
    end
    local selectionCallOK, pricesKnown = pcall(SelectKnownCraftSimReagents, recipeData, reserved)
    if not selectionCallOK or not pricesKnown then
        return nil, "unknown"
    end
    if not pcall(recipeData.Update, recipeData) then
        return nil, "incompatible"
    end

    local priceData = recipeData.priceData
    local craftingCost = tonumber(priceData and priceData.craftingCosts)
    if not craftingCost then
        return nil, "unknown"
    end
    if recipeInfo and recipeInfo.isEnchantingRecipe then
        local vellumPrice = GetCraftSimItemPrice(38682)
        if not vellumPrice then
            return nil, "unknown"
        end
        craftingCost = craftingCost + vellumPrice
    end

    local schematic = SafeCall(C_TradeSkillUI.GetRecipeSchematic, recipeID, false, nil)
    if type(schematic) ~= "table" then
        return nil, "incompatible"
    end
    local reagents = {}
    local ownedSoulboundUsage = {}
    for _, reagent in ipairs(recipeData.reagentData.requiredReagents or {}) do
        for _, reagentItem in ipairs(reagent.items or {}) do
            local quantity = tonumber(reagentItem.quantity) or 0
            local pricedItemID = reagentItem.item and reagentItem.item.GetItemID and reagentItem.item:GetItemID() or nil
            local originalItemID = reagentItem.originalItem and reagentItem.originalItem.GetItemID
                and reagentItem.originalItem:GetItemID()
                or pricedItemID
            if quantity > 0 and pricedItemID then
                if not IsCraftSimPriceKnown(priceData, pricedItemID) then
                    local reservedWithCurrent = (reserved and reserved[pricedItemID] or 0)
                        + (ownedSoulboundUsage[pricedItemID] or 0)
                    if not IsOwnedSoulboundReagent(pricedItemID, quantity, { [pricedItemID] = reservedWithCurrent }) then
                        return nil, "unknown"
                    end
                    ownedSoulboundUsage[pricedItemID] = (ownedSoulboundUsage[pricedItemID] or 0) + quantity
                end
                reagents[#reagents + 1] = { itemID = originalItemID, quantity = quantity }
            end
        end
    end

    local requiredSlot = recipeData.reagentData.requiredSelectableReagentSlot
    local activeReagent = requiredSlot and requiredSlot.activeReagent
    if activeReagent then
        local quantity = tonumber(requiredSlot.maxQuantity) or 1
        local itemID = activeReagent.item and activeReagent.item.GetItemID and activeReagent.item:GetItemID() or nil
        local currencyID = tonumber(activeReagent.currencyID)
        if itemID then
            if not IsCraftSimPriceKnown(priceData, itemID) then
                local reservedWithCurrent = (reserved and reserved[itemID] or 0)
                    + (ownedSoulboundUsage[itemID] or 0)
                if not IsOwnedSoulboundReagent(itemID, quantity, { [itemID] = reservedWithCurrent }) then
                    return nil, "unknown"
                end
                ownedSoulboundUsage[itemID] = (ownedSoulboundUsage[itemID] or 0) + quantity
            end
            reagents[#reagents + 1] = { itemID = itemID, quantity = quantity }
        end
    end

    if craftingCost >= FIRST_CRAFT_COST_LIMIT then
        return nil, "expensive"
    end

    local context = BuildRecipeContext(recipeID, recipeInfo, schematic, nil, false)
    if not context then
        return nil, "incompatible"
    end
    context.reagents = AddEnchantingVellumReagent(reagents, recipeInfo)
    local reagentInfoOK, craftingReagents = pcall(
        recipeData.reagentData.GetCraftingReagentInfoTbl,
        recipeData.reagentData
    )
    if not reagentInfoOK or type(craftingReagents) ~= "table" then
        return nil, "incompatible"
    end
    context.craftingReagents = NormalizeCraftingReagents(craftingReagents)
    context.slotAllocations = {}
    context.clearSlotIndices = {}
    context.professionID = professionID
    context.mode = "crafts"
    return context, craftingCost, ownedSoulboundUsage, cooldownKey
end

local function IsEligibleFirstCraftInfo(info)
    return info and info.learned and info.firstCraft
        and not info.isDummyRecipe and not info.isGatheringRecipe
        and not info.isRecraft and not info.isSalvageRecipe
end

local function DoesQueuedEntryCoverFirstCraft(entry, recipeID)
    local queuedRecipeID = tonumber(entry and entry.recipeID)
    return queuedRecipeID
        and (recipeID == nil or queuedRecipeID == tonumber(recipeID))
        and not (entry.queueKind == "patron" and entry.isRecraft == true)
end

local function HasQueuedRecipe(recipeID)
    EnsureDB()
    for _, entry in ipairs(db.queue) do
        if DoesQueuedEntryCoverFirstCraft(entry, recipeID) then
            return true
        end
    end
    return false
end

local function HasAddableFirstCraft()
    if type(_G.CraftSimAPI) ~= "table" or type(_G.CraftSimAPI.GetRecipeData) ~= "function"
        or type(C_TradeSkillUI) ~= "table" or type(C_TradeSkillUI.GetAllRecipeIDs) ~= "function" then
        return false
    end

    EnsureDB()
    local skillLineID = type(C_TradeSkillUI.GetProfessionChildSkillLineID) == "function"
        and SafeCall(C_TradeSkillUI.GetProfessionChildSkillLineID)
        or nil
    local queuedRecipeIDs = {}
    for _, entry in ipairs(db.queue) do
        if DoesQueuedEntryCoverFirstCraft(entry) then
            queuedRecipeIDs[#queuedRecipeIDs + 1] = tostring(entry.recipeID)
        end
    end
    table.sort(queuedRecipeIDs)
    local queueSignature = table.concat(queuedRecipeIDs, ",")
    local cache = state.firstCraftAvailability
    if cache.skillLineID == skillLineID and cache.queueSignature == queueSignature then
        return cache.hasAddable == true
    end

    local scan = {
        skillLineID = skillLineID,
        queueSignature = queueSignature,
        scanning = true,
    }
    state.firstCraftAvailability = scan

    local recipeIDs = {}
    for _, recipeID in ipairs(SafeCall(C_TradeSkillUI.GetAllRecipeIDs) or {}) do
        if IsEligibleFirstCraftInfo(SafeCall(C_TradeSkillUI.GetRecipeInfo, recipeID)) then
            recipeIDs[#recipeIDs + 1] = recipeID
        end
    end
    table.sort(recipeIDs)

    local okCraftSim, craftSim = pcall(_G.CraftSimAPI.GetCraftSim, _G.CraftSimAPI)
    if not okCraftSim or type(craftSim) ~= "table" then
        scan.scanning = false
        scan.hasAddable = false
        return false
    end

    local professionID = GetCurrentProfessionID()
    local cooldownReservations = BuildQueuedCooldownReservations(craftSim)
    local function FinishAvailabilityScan(hasAddable)
        if state.firstCraftAvailability ~= scan then
            return
        end
        scan.scanning = false
        scan.hasAddable = hasAddable == true
        ScheduleRefresh()
    end
    local function ProcessAvailabilityRecipe(index)
        if index > #recipeIDs then
            FinishAvailabilityScan(false)
            return
        end
        C_Timer.After(0, function()
            if state.firstCraftAvailability ~= scan then
                return
            end
            local activeSkillLineID = type(C_TradeSkillUI.GetProfessionChildSkillLineID) == "function"
                and SafeCall(C_TradeSkillUI.GetProfessionChildSkillLineID)
                or nil
            if skillLineID and activeSkillLineID ~= skillLineID then
                FinishAvailabilityScan(false)
                return
            end

            local recipeID = recipeIDs[index]
            if not HasQueuedRecipe(recipeID) then
                local ok, context = pcall(
                    BuildFirstCraftContext,
                    recipeID,
                    SafeCall(C_TradeSkillUI.GetRecipeInfo, recipeID),
                    professionID,
                    skillLineID,
                    {},
                    cooldownReservations,
                    craftSim
                )
                if ok and context then
                    FinishAvailabilityScan(true)
                    return
                end
            end
            ProcessAvailabilityRecipe(index + 1)
        end)
    end
    ProcessAvailabilityRecipe(1)
    return false
end

local function QueueAllAffordableFirstCrafts(button)
    if state.firstCraftScanRunning then
        return
    end
    if type(_G.CraftSimAPI) ~= "table" or type(_G.CraftSimAPI.GetRecipeData) ~= "function" then
        Print("CraftSim est requis pour chiffrer les first crafts.")
        return
    end
    if type(C_TradeSkillUI) ~= "table" or type(C_TradeSkillUI.GetAllRecipeIDs) ~= "function" then
        Print("La liste des recettes est indisponible.")
        return
    end

    local recipeIDs = {}
    for _, recipeID in ipairs(SafeCall(C_TradeSkillUI.GetAllRecipeIDs) or {}) do
        local info = SafeCall(C_TradeSkillUI.GetRecipeInfo, recipeID)
        if IsEligibleFirstCraftInfo(info) then
            recipeIDs[#recipeIDs + 1] = recipeID
        end
    end
    table.sort(recipeIDs)

    local stats = { added = 0, expensive = 0, unknown = 0, cooldown = 0, queued = 0, incompatible = 0 }
    local professionID = GetCurrentProfessionID()
    local reservedSoulboundReagents = {}
    local okCraftSim, craftSim = pcall(_G.CraftSimAPI.GetCraftSim, _G.CraftSimAPI)
    if not okCraftSim or type(craftSim) ~= "table" then
        Print("CraftSim est indisponible pour verifier les cooldowns.")
        return
    end
    local reservedCooldownCharges = BuildQueuedCooldownReservations(craftSim)
    local currentSkillLineID = type(C_TradeSkillUI.GetProfessionChildSkillLineID) == "function"
        and SafeCall(C_TradeSkillUI.GetProfessionChildSkillLineID)
        or nil
    state.firstCraftScanRunning = true
    button:Disable()

    local function FinishFirstCraftScan()
        state.firstCraftScanRunning = false
        button:SetText("first craft")
        button:Enable()
        state.ah.statusMessage = stats.added .. " first craft(s) ajoute(s)"
        Print(("First crafts: %d ajoutes, %d deja en file, %d sans charge CD, %d trop chers, %d sans prix, %d incompatibles."):format(
            stats.added, stats.queued, stats.cooldown, stats.expensive, stats.unknown, stats.incompatible
        ))
        ScheduleRefresh()
    end

    local function ProcessRecipe(index)
        if index > #recipeIDs then
            FinishFirstCraftScan()
            return
        end
        button:SetText(index .. "/" .. #recipeIDs)
        C_Timer.After(0, function()
            local activeSkillLineID = type(C_TradeSkillUI.GetProfessionChildSkillLineID) == "function"
                and SafeCall(C_TradeSkillUI.GetProfessionChildSkillLineID)
                or nil
            if currentSkillLineID and activeSkillLineID ~= currentSkillLineID then
                stats.incompatible = stats.incompatible + (#recipeIDs - index + 1)
                FinishFirstCraftScan()
                return
            end

            local processed = pcall(function()
                local recipeID = recipeIDs[index]
                if HasQueuedRecipe(recipeID) then
                    stats.queued = stats.queued + 1
                else
                    local info = SafeCall(C_TradeSkillUI.GetRecipeInfo, recipeID)
                    local context, result, ownedSoulboundUsage, cooldownKey = BuildFirstCraftContext(
                        recipeID, info, professionID, currentSkillLineID, reservedSoulboundReagents,
                        reservedCooldownCharges, craftSim
                    )
                    if context then
                        AddRecipeToQueue(context, 1)
                        for itemID, quantity in pairs(ownedSoulboundUsage or {}) do
                            reservedSoulboundReagents[itemID] = (reservedSoulboundReagents[itemID] or 0) + quantity
                        end
                        if cooldownKey then
                            reservedCooldownCharges[cooldownKey] = (reservedCooldownCharges[cooldownKey] or 0) + 1
                        end
                        stats.added = stats.added + 1
                    elseif result == "expensive" then
                        stats.expensive = stats.expensive + 1
                    elseif result == "unknown" then
                        stats.unknown = stats.unknown + 1
                    elseif result == "cooldown" then
                        stats.cooldown = stats.cooldown + 1
                    else
                        stats.incompatible = stats.incompatible + 1
                    end
                end
            end)
            if not processed then
                stats.incompatible = stats.incompatible + 1
            end
            ProcessRecipe(index + 1)
        end)
    end

    if #recipeIDs == 0 then
        FinishFirstCraftScan()
    else
        ProcessRecipe(1)
    end
end

local function UpdateVendorButtons(summary)
    if not state.craft.panel then
        return
    end

    for _, button in ipairs(state.craft.vendorButtons or {}) do
        button:Hide()
    end
    if state.craft.vendorTitle then
        state.craft.vendorTitle:Hide()
    end

    if not MerchantFrame or not MerchantFrame:IsShown() then
        return
    end

    local tasks = GetCurrentMerchantTasks(summary)

    local button = state.craft.vendorButtons[1]
    if button and #tasks > 0 then
        button.tasks = tasks
        if #tasks == 1 then
            button:SetText("Acheter " .. tasks[1].missing .. "x " .. tasks[1].name)
        else
            button:SetText("Tout acheter (" .. #tasks .. " composants)")
        end
        button:Show()
    end

    if #tasks > 0 and state.craft.vendorTitle then
        state.craft.vendorTitle:Show()
    end
end

local function SummaryHasTasks(summary)
    return #summary.mailboxTasks > 0 or #summary.auctionTasks > 0 or #summary.vendorTasks > 0 or #summary.craftTasks > 0
end

local function UpdateCraftPanel(summary)
    if not state.craft.panel then
        return
    end

    local hasTasks = SummaryHasTasks(summary)
    local context = GetCurrentRecipeContext()
    if context then
        state.craft.selectedText:SetText(context.recipeName)
    else
        state.craft.selectedText:SetText("")
    end

    state.craft.panel:SetHeight(hasTasks and CRAFT_PANEL_EXPANDED_HEIGHT or CRAFT_PANEL_COLLAPSED_HEIGHT)
    if state.craft.todoTitle then
        state.craft.todoTitle:SetShown(hasTasks)
    end
    for _, line in ipairs(state.craft.lines) do
        line:SetShown(hasTasks)
    end

    SetLineText(state.craft.lines, MAX_CRAFT_LINES, BuildCraftLines(summary))
    UpdateVendorButtons(summary)

    local nextState = GetPatronNextButtonState()
    if state.craft.nextButton then
        if nextState then
            state.craft.nextButton:SetShown(true)
            state.craft.nextButton:SetText(nextState.text or "Next")
            if nextState.enabled then
                state.craft.nextButton:Enable()
            else
                state.craft.nextButton:Disable()
            end
            if GetNextActionLock() then
                state.craft.nextButton:SetButtonState("PUSHED", true)
            else
                state.craft.nextButton:SetButtonState("NORMAL", false)
            end
        else
            state.craft.nextButton:SetButtonState("NORMAL", false)
            state.craft.nextButton:Hide()
        end
    end

    local statusParts = {}
    if #summary.mailboxTasks > 0 then
        table.insert(statusParts, #summary.mailboxTasks .. " boite")
    end
    if #summary.auctionTasks > 0 then
        table.insert(statusParts, #summary.auctionTasks .. " HV")
    end
    if #summary.vendorTasks > 0 then
        table.insert(statusParts, #summary.vendorTasks .. " marchand")
    end
    if #summary.craftTasks > 0 then
        table.insert(statusParts, #summary.craftTasks .. " craft")
    end
    state.craft.statusText:SetText(#statusParts > 0 and table.concat(statusParts, " | ") or "")
end

local function HideAuctionFrame()
    if state.ah.frame then
        state.ah.frame:Hide()
    end
    if state.ah.tab then
        PanelTemplates_DeselectTab(state.ah.tab)
    end
end

local function ShowAuctionFrame()
    if not state.ah.frame or not state.ah.tab then
        return
    end

    if state.ah.tab.libAHTab and state.ah.tab.libTabID then
        state.ah.tab.libAHTab:SetSelected(state.ah.tab.libTabID)
        ScheduleRefresh()
        return
    end

    AuctionHouseFrame:SetDisplayMode({})
    AuctionHouseFrame.displayMode = nil
    for _, tab in ipairs(AuctionHouseFrame.Tabs or {}) do
        PanelTemplates_DeselectTab(tab)
    end

    PanelTemplates_SelectTab(state.ah.tab)
    AuctionHouseFrame:SetTitle(state.ah.tab.tabHeader or "YayaQueue")
    state.ah.frame:Show()
    ScheduleRefresh()
end

local function CaptureSearchCache(itemID)
    if type(itemID) ~= "number" or itemID <= 0 then
        return
    end

    local cache = {
        itemID = itemID,
        name = GetItemName(itemID),
        kind = IsCommodityItem(itemID) and "commodity" or "item",
        available = 0,
        hasResults = false,
    }

    if cache.kind == "commodity" then
        local resultCount = C_AuctionHouse and C_AuctionHouse.GetNumCommoditySearchResults and C_AuctionHouse.GetNumCommoditySearchResults(itemID) or 0
        for index = 1, resultCount do
            local info = C_AuctionHouse.GetCommoditySearchResultInfo(itemID, index)
            if info and (info.quantity or 0) > 0 then
                cache.hasResults = true
                cache.available = cache.available + info.quantity
                if not cache.unitPrice or info.unitPrice < cache.unitPrice then
                    cache.unitPrice = info.unitPrice
                end
            end
        end
    else
        local itemKey = MakeItemKey(itemID)
        local resultCount = itemKey and C_AuctionHouse and C_AuctionHouse.GetNumItemSearchResults and C_AuctionHouse.GetNumItemSearchResults(itemKey) or 0
        for index = 1, resultCount do
            local info = itemKey and C_AuctionHouse.GetItemSearchResultInfo(itemKey, index) or nil
            local buyoutAmount = info and info.buyoutAmount or 0
            local quantity = info and info.quantity or 0
            if buyoutAmount > 0 and quantity > 0 then
                local unitPrice = math.floor(buyoutAmount / quantity)
                cache.hasResults = true
                cache.available = cache.available + quantity
                if not cache.bestAuction or unitPrice < cache.bestAuction.unitPrice then
                    cache.bestAuction = {
                        auctionID = info.auctionID,
                        buyoutAmount = buyoutAmount,
                        quantity = quantity,
                        unitPrice = unitPrice,
                    }
                end
            end
        end
        if cache.bestAuction then
            cache.unitPrice = cache.bestAuction.unitPrice
        end
    end

    state.searchCache[itemID] = cache
end

local function UpdateAuctionLines(summary)
    local lines = {}
    local totalEstimate = 0
    local hasUnknownEstimate = false

    for _, task in ipairs(summary.auctionTasks) do
        local cache = state.searchCache[task.itemID]
        local suffix = "?"
        local estimateText = "?"
        if cache then
            suffix = tostring(cache.available or 0)
            if cache.unitPrice and cache.unitPrice > 0 then
                local itemEstimate = cache.unitPrice * task.missing
                estimateText = FormatMoneyEstimate(itemEstimate) .. " (" .. FormatMoneyEstimate(cache.unitPrice) .. "/u)"
                totalEstimate = totalEstimate + itemEstimate
            end
        end
        if estimateText == "?" then
            hasUnknownEstimate = true
        end
        table.insert(lines, task.missing .. "x " .. task.name .. " [" .. suffix .. "] ~ " .. estimateText)
    end

    if #lines == 0 then
        lines[1] = "Aucun achat HV"
    end

    if state.ah.totalText then
        if #summary.auctionTasks == 0 then
            state.ah.totalText:SetText("Total estime: 0")
        elseif totalEstimate > 0 and hasUnknownEstimate then
            state.ah.totalText:SetText("Total estime: " .. FormatMoneyEstimate(totalEstimate) .. " + ?")
        elseif totalEstimate > 0 then
            state.ah.totalText:SetText("Total estime: " .. FormatMoneyEstimate(totalEstimate))
        else
            state.ah.totalText:SetText("Total estime: ?")
        end
    end

    SetLineText(state.ah.lines, MAX_AH_LINES, lines)
end

local function UpdateAuctionButton(summary)
    if not state.ah.actionButton then
        return
    end

    local hasTasks = #summary.auctionTasks > 0
    local isBusy = state.ah.pendingCommodity or state.ah.pendingItem or state.ah.activeSearch or state.ah.waitingSearch or (state.ah.searchQueue and #state.ah.searchQueue > 0)
    local needsSearch = hasTasks and NeedsAuctionSearch(summary)

    if not hasTasks then
        state.ah.actionButton:SetText("Rien a acheter")
        state.ah.actionButton:Disable()
    elseif isBusy then
        state.ah.actionButton:SetText((state.ah.pendingCommodity or state.ah.pendingItem) and "Achat..." or "Recherche...")
        state.ah.actionButton:Disable()
    elseif needsSearch then
        state.ah.actionButton:SetText("Rechercher tout")
        state.ah.actionButton:Enable()
    else
        state.ah.actionButton:SetText("Acheter suivant")
        state.ah.actionButton:Enable()
    end
end

local function UpdateAuctionFrame(summary)
    if not state.ah.frame or not state.ah.frame:IsShown() then
        return
    end

    UpdateAuctionLines(summary)
    UpdateAuctionButton(summary)
    state.ah.statusText:SetText(state.ah.statusMessage ~= "" and state.ah.statusMessage or "Pret")
end

function YQQuality.GetQualityAtlas(quality, simplified)
    local prefix = simplified and "Professions-Icon-Quality-12-Tier" or "Professions-Icon-Quality-Tier"
    return prefix .. tostring(quality)
end

function YQQuality.GetQualityIcon(quality, size, simplified)
    if type(CreateAtlasMarkup) == "function" then
        return CreateAtlasMarkup(YQQuality.GetQualityAtlas(quality, simplified), size or 22, size or 22, 0, -2)
    end
    return "|TInterface\\Professions\\ProfessionsQualityIcons:" .. tostring(size or 22) .. "|t"
end

function YQQuality.GetTSMPrice(priceSource, item)
    if type(TSM_API) == "table" and type(TSM_API.ToItemString) == "function"
        and type(TSM_API.GetCustomPriceValue) == "function" then
        local candidate
        if type(item) == "string" and item ~= "" then
            candidate = item
        elseif type(item) == "number" and item > 0 then
            candidate = select(2, GetItemInfo(item)) or ("i:" .. item)
        end
        local okString, itemString
        if candidate then
            okString, itemString = pcall(TSM_API.ToItemString, candidate)
        end
        if okString and itemString then
            local okPrice, price = pcall(TSM_API.GetCustomPriceValue, priceSource, itemString)
            if okPrice and type(price) == "number" and price > 0 then return price end
        end
    end
    return nil
end

function YQQuality.GetItemPrice(itemID)
    itemID = tonumber(itemID)
    if not itemID or itemID <= 0 then return nil end
    for _, priceSource in ipairs({ "vendorbuy", "dbminbuyout", "dbmarket" }) do
        local price = YQQuality.GetTSMPrice(priceSource, itemID)
        if price then return price end
    end
    local containerAPI = _G.YayaContainerValuesAPI
    if containerAPI and type(containerAPI.GetAverageValue) == "function" then
        local ok, price = pcall(containerAPI.GetAverageValue, itemID)
        if ok and type(price) == "number" and price > 0 then return price end
    end
    return nil
end

function YQQuality.GetConcentrationCurrencyID(operation)
    local currencyID = tonumber(operation and operation.concentrationCurrencyID)
    if not currencyID and type(C_TradeSkillUI.GetConcentrationCurrencyID) == "function" then
        local skillLineID = type(C_TradeSkillUI.GetProfessionChildSkillLineID) == "function"
            and SafeCall(C_TradeSkillUI.GetProfessionChildSkillLineID) or nil
        currencyID = skillLineID and tonumber(
            SafeCall(C_TradeSkillUI.GetConcentrationCurrencyID, skillLineID)
        ) or nil
    end
    return currencyID
end

function YQQuality.CopyReagents(reagents)
    local copy = {}
    for _, info in ipairs(reagents or {}) do
        local dataSlotIndex = tonumber(info.dataSlotIndex)
        local itemID = tonumber(info.reagent and info.reagent.itemID)
        local currencyID = tonumber(info.reagent and info.reagent.currencyID)
        local quantity = math.max(0, tonumber(info.quantity) or 0)
        if dataSlotIndex and dataSlotIndex > 0 and quantity > 0
            and ((itemID and itemID > 0) or (currencyID and currencyID > 0)) then
            copy[#copy + 1] = {
                dataSlotIndex = dataSlotIndex,
                reagent = {
                    itemID = itemID and itemID > 0 and itemID or nil,
                    currencyID = currencyID and currencyID > 0 and currencyID or nil,
                },
                quantity = quantity,
            }
        end
    end
    return copy
end

function YQQuality.FilterOperationReagents(schematic, reagents)
    local fixedRequiredSlots = {}
    for _, slot in ipairs(schematic and schematic.reagentSlotSchematics or {}) do
        local firstReagent = slot.reagents and slot.reagents[1] or nil
        local reagentType = tonumber(slot.reagentType)
        local isFixedRequiredItem = reagentType == 1
            and #(slot.reagents or {}) == 1
            and (tonumber(firstReagent and firstReagent.itemID) or 0) > 0
            and (tonumber(firstReagent and firstReagent.currencyID) or 0) <= 0
        local isAutomaticSlot = reagentType == 3
        local dataSlotIndex = tonumber(slot.dataSlotIndex)
        if (isFixedRequiredItem or isAutomaticSlot) and dataSlotIndex then
            fixedRequiredSlots[dataSlotIndex] = true
        end
    end

    local filtered = {}
    for _, info in ipairs(YQQuality.CopyReagents(reagents)) do
        if not fixedRequiredSlots[tonumber(info.dataSlotIndex)] then
            filtered[#filtered + 1] = info
        end
    end
    return filtered
end

function YQQuality.ReplaceReagent(reagents, slot, allocations)
    local result = {}
    for _, info in ipairs(reagents or {}) do
        if tonumber(info.dataSlotIndex) ~= tonumber(slot.dataSlotIndex) then
            result[#result + 1] = info
        end
    end
    for _, allocation in ipairs(allocations or {}) do
        local quantity = math.max(0, tonumber(allocation.quantity) or 0)
        if allocation.itemID and quantity > 0 then
            result[#result + 1] = {
                dataSlotIndex = tonumber(slot.dataSlotIndex),
                reagent = { itemID = tonumber(allocation.itemID) },
                quantity = quantity,
            }
        end
    end
    return result
end

function YQQuality.BuildCompositions(slotData)
    local options = slotData.options or {}
    local required = math.max(1, math.floor((tonumber(slotData.slot.quantityRequired) or 1) + 0.5))
    local compositions = {}
    local function price(option)
        return tonumber(option and option.price) or 1000000000000
    end
    local function addComposition(factor, counts)
        local allocations = {}
        local cost = 0
        for index, count in ipairs(counts) do
            if count > 0 and options[index] then
                allocations[#allocations + 1] = {
                    itemID = options[index].itemID,
                    quantity = count,
                    quality = options[index].quality,
                }
                cost = cost + price(options[index]) * count
            end
        end
        compositions[#compositions + 1] = {
            factor = factor,
            allocations = allocations,
            cost = cost,
        }
    end

    if #options == 2 then
        for highCount = 0, required do
            addComposition(highCount / required, { required - highCount, highCount })
        end
    elseif #options == 3 then
        local deltaMiddle = price(options[3]) - 2 * price(options[2]) + price(options[1])
        for qualityFactor = 0, 2 * required do
            local highLow = math.max(0, qualityFactor - required)
            local highHigh = math.floor(qualityFactor / 2)
            if highLow <= highHigh then
                local highCount = deltaMiddle < 0 and highHigh or highLow
                local middleCount = qualityFactor - 2 * highCount
                local lowCount = required - middleCount - highCount
                addComposition(qualityFactor / (2 * required), { lowCount, middleCount, highCount })
            end
        end
    else
        for index, _ in ipairs(options) do
            addComposition(#options > 1 and ((index - 1) / (#options - 1)) or 0, {
                index == 1 and required or 0,
                index == 2 and required or 0,
                index == 3 and required or 0,
            })
        end
    end
    return compositions
end

function YQQuality.BuildRecipeState(form, useConcentration)
    local recipeInfo = form and type(form.GetRecipeInfo) == "function" and SafeCall(form.GetRecipeInfo, form) or nil
    local transaction = form and ((type(form.GetTransaction) == "function" and SafeCall(form.GetTransaction, form)) or form.transaction) or nil
    local recipeID = recipeInfo and tonumber(recipeInfo.recipeID)
    if not recipeID or not transaction or type(C_TradeSkillUI) ~= "table"
        or type(C_TradeSkillUI.GetCraftingOperationInfo) ~= "function" then return nil end

    local level = type(form.GetCurrentRecipeLevel) == "function" and SafeCall(form.GetCurrentRecipeLevel, form) or nil
    local schematic = SafeCall(C_TradeSkillUI.GetRecipeSchematic, recipeID, false, level)
    local base = type(transaction.CreateCraftingReagentInfoTbl) == "function"
        and SafeCall(transaction.CreateCraftingReagentInfoTbl, transaction) or {}
    if type(schematic) ~= "table" or type(base) ~= "table" then return nil end
    base = AddVisibleRequiredReagents(form, schematic, base)
    base = YQQuality.FilterOperationReagents(schematic, base)

    local slots = {}
    for _, slot in ipairs(schematic.reagentSlotSchematics or {}) do
        local options = {}
        local seen = {}
        for _, reagent in ipairs(slot.reagents or {}) do
            local itemID = tonumber(reagent.itemID)
            local quality = tonumber(reagent.reagentQuality or reagent.quality or reagent.qualityID) or 0
            if quality <= 0 and itemID and C_TradeSkillUI.GetItemReagentQualityByItemInfo then
                quality = tonumber(SafeCall(C_TradeSkillUI.GetItemReagentQualityByItemInfo, itemID)) or 0
            end
            if tonumber(slot.reagentType) == 1 and itemID and itemID > 0 and quality > 0 and not seen[itemID] then
                seen[itemID] = true
                options[#options + 1] = { itemID = itemID, quality = quality, price = YQQuality.GetItemPrice(itemID) }
            end
        end
        DebugPrint(
            "quality-slot index=" .. tostring(slot.dataSlotIndex)
                .. " required=" .. tostring(slot.required)
                .. " reagents=" .. tostring(#(slot.reagents or {}))
                .. " quality-options=" .. tostring(#options)
        )
        table.sort(options, function(left, right) return left.quality < right.quality end)
        if #options > 1 then
            local slotData = { slot = slot, options = options }
            slotData.compositions = YQQuality.BuildCompositions(slotData)
            slots[#slots + 1] = slotData
        end
    end

    local result = {
        recipeID = recipeID,
        recipeName = recipeInfo.name or ("Recette " .. recipeID),
        slots = slots,
        candidates = {},
        minQuality = math.huge,
        maxQuality = tonumber(recipeInfo.maxQuality) or 0,
        reachableQuality = 0,
        reagentQualityCount = 0,
        recipeInfo = recipeInfo,
        schematic = schematic,
    }
    local allocationGUID = type(transaction.GetAllocationItemGUID) == "function"
        and SafeCall(transaction.GetAllocationItemGUID, transaction) or nil
    result.allocationGUID = allocationGUID

    local baseline = YQQuality.CopyReagents(base)
    for _, slotData in ipairs(slots) do
        result.reagentQualityCount = math.max(result.reagentQualityCount, #slotData.options)
        baseline = YQQuality.ReplaceReagent(baseline, slotData.slot, slotData.compositions[1].allocations)
    end
    local baselineOperation = SafeCall(C_TradeSkillUI.GetCraftingOperationInfo, recipeID, baseline, allocationGUID, false)
    if not baselineOperation then return nil end
    local baselineSkill = (tonumber(baselineOperation and baselineOperation.baseSkill) or 0)
        + (tonumber(baselineOperation and baselineOperation.bonusSkill) or 0)

    for _, slotData in ipairs(slots) do
        local maximum = slotData.compositions[#slotData.compositions]
        local maximumReagents = YQQuality.ReplaceReagent(baseline, slotData.slot, maximum.allocations)
        local maximumOperation = SafeCall(
            C_TradeSkillUI.GetCraftingOperationInfo, recipeID, maximumReagents, allocationGUID, false
        )
        if not maximumOperation then return nil end
        local maximumBaseSkill = tonumber(maximumOperation and maximumOperation.baseSkill)
        local maximumSkill = maximumBaseSkill and (
            maximumBaseSkill + (tonumber(maximumOperation and maximumOperation.bonusSkill) or 0)
        ) or baselineSkill
        slotData.maximumSkillBonus = math.max(0, maximumSkill - baselineSkill)
    end

    local states = {
        ["0"] = { cost = 0, reagents = baseline, skillBonus = 0 },
    }
    for _, slotData in ipairs(slots) do
        local nextStates = {}
        for _, stateData in pairs(states) do
            for _, composition in ipairs(slotData.compositions) do
                local skillBonus = stateData.skillBonus + composition.factor * slotData.maximumSkillBonus
                local stateKey = tostring(math.floor(skillBonus * 1000 + 0.5))
                local cost = stateData.cost + composition.cost
                if not nextStates[stateKey] or cost < nextStates[stateKey].cost then
                    nextStates[stateKey] = {
                        cost = cost,
                        skillBonus = skillBonus,
                        reagents = YQQuality.ReplaceReagent(
                            stateData.reagents, slotData.slot, composition.allocations
                        ),
                    }
                end
            end
        end
        states = nextStates
    end

    local visited = 0
    for _, stateData in pairs(states) do
        visited = visited + 1
        local operation = SafeCall(
            C_TradeSkillUI.GetCraftingOperationInfo,
            recipeID,
            stateData.reagents,
            allocationGUID,
            useConcentration == true
        )
        local quality = tonumber(operation and operation.craftingQuality) or 0
        if operation and quality > 0 then
            result.candidates[#result.candidates + 1] = {
                quality = quality,
                cost = stateData.cost,
                reagents = YQQuality.CopyReagents(stateData.reagents),
                operation = operation,
            }
            result.minQuality = math.min(result.minQuality, quality)
            result.reachableQuality = math.max(result.reachableQuality, quality)
        end
    end
    if result.maxQuality <= 0 then result.maxQuality = result.reachableQuality end
    result.simplifiedResult = result.maxQuality == 2
    DebugPrint(
        "quality-state recipe=" .. tostring(recipeID)
            .. " max=" .. tostring(result.maxQuality)
            .. " reachable=" .. tostring(result.reachableQuality)
            .. " slots=" .. tostring(#result.slots)
            .. " states=" .. tostring(visited)
            .. " candidates=" .. tostring(#result.candidates)
    )
    table.sort(result.candidates, function(left, right)
        if left.quality ~= right.quality then return left.quality < right.quality end
        if left.cost ~= right.cost then return left.cost < right.cost end
        return false
    end)
    return result
end

function YQQuality.FindCandidate(recipeState, targetQuality)
    local selected
    for _, candidate in ipairs(recipeState and recipeState.candidates or {}) do
        if candidate.quality == targetQuality and (
            not selected
                or candidate.cost < selected.cost
        ) then
            selected = candidate
        end
    end
    return selected
end

function YQQuality.GetOutputPriceReference(recipeState, candidate)
    if not recipeState or not candidate then return nil end
    local quality = tonumber(candidate.quality) or 0
    local recipeID = tonumber(recipeState.recipeID)
    if not recipeID or recipeID <= 0 or quality <= 0 then return nil end

    if recipeState.maxQuality <= 3 and type(C_TradeSkillUI.GetRecipeQualityItemIDs) == "function" then
        local itemIDs = SafeCall(C_TradeSkillUI.GetRecipeQualityItemIDs, recipeID)
        local itemID = type(itemIDs) == "table" and tonumber(itemIDs[quality]) or nil
        if itemID and itemID > 0 then
            WarmItemData(itemID)
            return itemID
        end
    end

    if type(C_TradeSkillUI.GetRecipeOutputItemData) ~= "function" then return nil end
    local recipeInfo = recipeState.recipeInfo
    local qualityIDs = recipeInfo and recipeInfo.qualityIDs
    local overrideQualityID = type(qualityIDs) == "table" and qualityIDs[quality] or nil
    if not overrideQualityID and recipeState.maxQuality > 3 then
        overrideQualityID = quality + 3
    end
    local output = SafeCall(
        C_TradeSkillUI.GetRecipeOutputItemData,
        recipeID,
        candidate.reagents,
        recipeState.allocationGUID,
        overrideQualityID
    )
    if type(output) ~= "table" then return nil end
    local itemID = tonumber(output.itemID)
    if itemID then WarmItemData(itemID) end
    if recipeState.maxQuality > 3 and itemID then
        local baseItemLevel = tonumber(recipeInfo and recipeInfo.itemLevel)
        local qualityBonuses = recipeInfo and recipeInfo.qualityIlvlBonuses
        local qualityBonus = type(qualityBonuses) == "table" and tonumber(qualityBonuses[quality]) or nil
        local expectedItemLevel = baseItemLevel and qualityBonus and (baseItemLevel + qualityBonus) or nil
        local detailedItemLevel
        if type(output.hyperlink) == "string" and output.hyperlink ~= "" then
            if type(C_Item) == "table" and type(C_Item.GetDetailedItemLevelInfo) == "function" then
                detailedItemLevel = tonumber(SafeCall(C_Item.GetDetailedItemLevelInfo, output.hyperlink))
            elseif type(GetDetailedItemLevelInfo) == "function" then
                detailedItemLevel = tonumber(SafeCall(GetDetailedItemLevelInfo, output.hyperlink))
            end
        end
        local itemLevel = math.max(expectedItemLevel or 0, detailedItemLevel or 0)
        if itemLevel > 0 then
            return "i:" .. tostring(itemID) .. "::i" .. tostring(math.floor(itemLevel + 0.5))
        end
    end
    if type(output.hyperlink) == "string" and output.hyperlink ~= "" then
        return output.hyperlink
    end
    if recipeState.maxQuality <= 3 then
        return itemID
    end
    return nil
end

function YQQuality.GetCandidatePricing(recipeState, candidate)
    local pricing = {
        minBuyout = nil,
        materialCost = nil,
        profit = nil,
    }
    if not recipeState or not candidate then return pricing end

    local outputReference = YQQuality.GetOutputPriceReference(recipeState, candidate)
    pricing.minBuyout = outputReference and YQQuality.GetTSMPrice("dbminbuyout", outputReference) or nil

    local completeReagents = BuildCompleteRecipeReagents(
        recipeState.schematic,
        candidate.reagents,
        recipeState.recipeInfo
    )
    local materialCost = 0
    local materialCostKnown = true
    for _, reagent in ipairs(completeReagents or {}) do
        local itemID = tonumber(reagent.itemID)
        local quantity = math.max(0, tonumber(reagent.quantity) or 0)
        local price = itemID and YQQuality.GetItemPrice(itemID) or nil
        if quantity > 0 and not price then
            materialCostKnown = false
            break
        end
        materialCost = materialCost + ((price or 0) * quantity)
    end
    pricing.materialCost = materialCostKnown and materialCost or nil

    if pricing.minBuyout and pricing.materialCost then
        local schematic = recipeState.schematic or {}
        local quantityMin = math.max(1, tonumber(schematic.quantityMin) or 1)
        local quantityMax = math.max(quantityMin, tonumber(schematic.quantityMax) or quantityMin)
        local baseYield = (quantityMin + quantityMax) / 2
        pricing.profit = (pricing.minBuyout * baseYield * 0.95) - pricing.materialCost
    end
    return pricing
end

function YQQuality.FormatSignedMoney(value)
    if type(value) ~= "number" then return "?" end
    local prefix = value > 0 and "+" or (value < 0 and "-" or "")
    return prefix .. GetMoneyString(math.floor(math.abs(value)), true)
end

function YQQuality.HasEnoughConcentration(candidate, quantity)
    if not candidate then return false end
    local concentrationCost = math.max(0, tonumber(candidate.operation and candidate.operation.concentrationCost) or 0)
    if concentrationCost <= 0 then return true end

    local currencyID = YQQuality.GetConcentrationCurrencyID(candidate.operation)
    local currencyInfo = currencyID and C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo
        and SafeCall(C_CurrencyInfo.GetCurrencyInfo, currencyID) or nil
    local available = math.max(0, tonumber(currencyInfo and currencyInfo.quantity) or 0)
    local queuedReservation = GetQueuedConcentrationReservation()
    local availableAfterQueue = math.max(0, available - queuedReservation)
    local required = concentrationCost * ClampQuantity(quantity)
    return currencyID ~= nil and availableAfterQueue > 500 and availableAfterQueue >= required
end

local function CreateQuantityControls(button, includeReset, onChanged)
    local parent = button
    local function NotifyChanged()
        if type(onChanged) == "function" then
            onChanged()
        end
    end

    local plusButton = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    plusButton:SetSize(20, 22)
    plusButton:SetPoint("RIGHT", button, "LEFT", -4, 0)
    plusButton:SetText("+")

    local qtyBox = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    qtyBox:SetSize(36, 22)
    qtyBox:SetPoint("RIGHT", plusButton, "LEFT", -2, 0)
    qtyBox:SetAutoFocus(false)
    qtyBox:SetNumeric(true)
    qtyBox:SetMaxLetters(4)
    qtyBox:SetText("1")
    qtyBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        SetQuantityInput(self, GetQuantityInput(self))
        NotifyChanged()
    end)
    qtyBox:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        SetQuantityInput(self, GetQuantityInput(self))
        NotifyChanged()
    end)
    qtyBox:SetScript("OnTextChanged", function(_, userInput)
        if userInput then
            NotifyChanged()
        end
    end)

    local minusButton = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    minusButton:SetSize(20, 22)
    minusButton:SetPoint("RIGHT", qtyBox, "LEFT", -2, 0)
    minusButton:SetText("-")
    minusButton:SetScript("OnClick", function()
        SetQuantityInput(qtyBox, GetQuantityInput(qtyBox) - 1)
        NotifyChanged()
    end)
    plusButton:SetScript("OnClick", function()
        SetQuantityInput(qtyBox, GetQuantityInput(qtyBox) + 1)
        NotifyChanged()
    end)

    local resetButton
    if includeReset then
        resetButton = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
        resetButton:SetSize(20, 22)
        resetButton:SetPoint("RIGHT", minusButton, "LEFT", -2, 0)
        resetButton:SetText("R")
        resetButton:SetScript("OnClick", function()
            SetQuantityInput(qtyBox, 1)
            NotifyChanged()
        end)
    end

    button.qtyBox = qtyBox
    button.minusButton = minusButton
    button.plusButton = plusButton
    button.resetButton = resetButton
    return minusButton
end

function YQQuality.EnsureReagentRows(frame, rowCount)
    frame.reagentRows = frame.reagentRows or {}
    for rowIndex = #frame.reagentRows + 1, rowCount do
        local row = CreateFrame("Frame", nil, frame)
        row:SetSize(320, 26)
        row:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -165 - ((rowIndex - 1) * 28))
        row:EnableMouse(true)
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(24, 24)
        row.icon:SetPoint("LEFT", 2, 0)
        row.counts = {}
        for quality = 1, 3 do
            local count = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
            count:SetWidth(32)
            count:SetJustifyH("CENTER")
            row.counts[quality] = count
        end
        row:SetScript("OnEnter", function(self)
            if not self.itemID then return end
            GameTooltip:SetOwner(self, "ANCHOR_LEFT")
            GameTooltip:SetItemByID(self.itemID)
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)
        row:Hide()
        frame.reagentRows[rowIndex] = row
    end
end

function YQQuality.EnsureSelector(schematicForm)
    local craftingPage = ProfessionsFrame and ProfessionsFrame.CraftingPage
    if not craftingPage or not schematicForm then return nil end
    local frame = state.craft.qualityFrame
    if frame then
        frame.schematicForm = schematicForm
        if frame.addButton then frame.addButton.schematicForm = schematicForm end
        return frame
    end

    frame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    frame:SetSize(340, 296)
    frame:SetPoint("CENTER", UIParent, "CENTER", 180, 0)
    frame:SetFrameStrata("MEDIUM")
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    frame.schematicForm = schematicForm

    frame.title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    frame.title:SetPoint("TOPLEFT", 12, -10)
    frame.title:SetText("YQ — Optimisation des réactifs")
    frame.title:SetTextColor(1, 0.82, 0)
    frame.closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    frame.closeButton:SetPoint("TOPRIGHT", -2, -2)
    frame.closeButton:SetScript("OnClick", function() frame.userClosed = true; frame:Hide() end)
    frame.maxText = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    frame.maxText:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -36)
    frame.status = frame:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    frame.status:SetPoint("TOPLEFT", frame, "TOPLEFT", 165, -36)

    frame.marketText = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    frame.marketText:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -58)
    frame.marketText:SetWidth(316)
    frame.marketText:SetJustifyH("LEFT")
    frame.marketText:SetText("Minbuyout : ?   Profit est. : ?")

    frame.qualityChoiceLabel = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    frame.qualityChoiceLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -86)
    frame.qualityChoiceLabel:SetText("Choix de qualité")
    frame.qualityChoiceLabel:SetTextColor(1, 0.82, 0)

    frame.qualityButtons = {}
    for quality = 1, 5 do
        local button = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        button:SetSize(28, 26)
        button:SetPoint("TOPLEFT", frame, "TOPLEFT", 150 + (quality - 1) * 34, -78)
        button:SetText("")
        button.icon = button:CreateTexture(nil, "ARTWORK")
        button.icon:SetSize(20, 20)
        button.icon:SetPoint("CENTER")
        button.icon:SetAtlas(YQQuality.GetQualityAtlas(quality, false))
        button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
        button:RegisterForClicks("AnyUp")
        button.quality = quality
        button:SetScript("OnClick", function(self)
            if state.craft.qualityTarget then
                state.craft.qualityTarget.quality = self.quality
            end
            YQQuality.UpdateSelector()
        end)
        frame.qualityButtons[quality] = button
    end

    frame.concentration = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    frame.concentration:SetSize(24, 24)
    frame.concentration:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -114)
    frame.concentration:SetChecked(false)
    frame.concentration:SetHitRectInsets(0, -28, 0, 0)
    frame.concentration.icon = frame:CreateTexture(nil, "ARTWORK")
    frame.concentration.icon:SetSize(22, 22)
    frame.concentration.icon:SetPoint("LEFT", frame.concentration, "RIGHT", 2, 0)
    frame.concentration.icon:SetTexture(5747318)
    frame.concentration:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Utiliser la concentration")
        GameTooltip:Show()
    end)
    frame.concentration:SetScript("OnLeave", function() GameTooltip:Hide() end)
    frame.concentration:SetScript("OnClick", function(self)
        if state.craft.qualityTarget then
            local useConcentration = self:GetChecked() == true
            state.craft.qualityTarget.useConcentration = useConcentration
            if not useConcentration then
                state.craft.qualityTarget.quality = nil
            end
        end
        YQQuality.UpdateSelector()
    end)

    frame.reagentHeader = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    frame.reagentHeader:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -144)
    frame.reagentHeader:SetText("Réactifs")
    frame.reagentHeader:SetTextColor(1, 0.82, 0)
    frame.reagentQualityHeaders = {}
    for quality = 1, 3 do
        local header = frame:CreateTexture(nil, "ARTWORK")
        header:SetSize(20, 20)
        frame.reagentQualityHeaders[quality] = header
    end
    frame.reagentRows = {}

    frame.addButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.addButton:SetSize(108, 22)
    frame.addButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -8, 8)
    frame.addButton:SetText("Ajouter YQ")
    frame.addButton.schematicForm = schematicForm
    frame.addButton:SetScript("OnClick", function(self)
        local target = state.craft.qualityTarget
        local recipeState = state.craft.qualityState
        local candidate = recipeState and YQQuality.FindCandidate(recipeState, target and target.quality or 1)
        local context = GetRecipeContextFromSchematicForm(self.schematicForm)
        if not (context and candidate) then
            Print("Qualite ou recette indisponible pour YQ.")
            return
        end
        local recipeInfo = self.schematicForm:GetRecipeInfo()
        local level = type(self.schematicForm.GetCurrentRecipeLevel) == "function"
            and SafeCall(self.schematicForm.GetCurrentRecipeLevel, self.schematicForm) or nil
        local schematic = SafeCall(C_TradeSkillUI.GetRecipeSchematic, context.recipeID, false, level)
        context.craftingReagents = candidate.reagents
        context.slotAllocations = {}
        context.clearSlotIndices = {}
        context.reagents = BuildCompleteRecipeReagents(schematic, candidate.reagents, recipeInfo)
        context.applyConcentration = target.useConcentration == true
        context.concentrationCost = tonumber(candidate.operation and candidate.operation.concentrationCost) or nil
        context.targetQuality = target.quality
        context.targetQualitySimplified = recipeState.simplifiedResult == true
        context.mode = "crafts"
        local requestedQuantity = GetQuantityInput(self.qtyBox)
        if target.useConcentration == true then
            if not YQQuality.HasEnoughConcentration(candidate, requestedQuantity) then
                Print("Concentration insuffisante pour ajouter ce lot.")
                return
            end
        end
        local quantity = QueueRecipeContext(context, self.qtyBox)
        if quantity then
            Print(
                "Ajoute " .. quantity .. "x " .. context.recipeName .. " en "
                    .. YQQuality.GetQualityIcon(target.quality, 16, recipeState.simplifiedResult)
            )
        end
    end)
    CreateQuantityControls(frame.addButton, true, function()
        YQQuality.UpdateSelector()
    end)
    frame:Hide()
    state.craft.qualityFrame = frame
    return frame
end

function YQQuality.UpdateSelector()
    local craftingPage = ProfessionsFrame and ProfessionsFrame.CraftingPage
    if not ProfessionsFrame or not ProfessionsFrame:IsShown() or not craftingPage or not craftingPage:IsShown() then
        if state.craft.qualityFrame then state.craft.qualityFrame:Hide() end
        return
    end
    local schematicForm = craftingPage and craftingPage.SchematicForm
    if not schematicForm then
        if state.craft.qualityFrame then state.craft.qualityFrame:Hide() end
        return
    end
    local frame = YQQuality.EnsureSelector(schematicForm)
    if not frame then return end
    local isVisible = schematicForm:IsShown()
    frame:SetShown(isVisible and not frame.userClosed)
    if not isVisible then return end

    local target = state.craft.qualityTarget
    local useConcentration = target and target.useConcentration == true or false
    local recipeInfo = schematicForm.GetRecipeInfo and SafeCall(schematicForm.GetRecipeInfo, schematicForm) or nil
    local recipeID = recipeInfo and tonumber(recipeInfo.recipeID)
    if not recipeID or recipeID <= 0 then
        frame:Hide()
        state.craft.qualityTarget = nil
        state.craft.qualityState = nil
        return
    end
    if recipeInfo.isRecraft == true then
        frame:Hide()
        state.craft.qualityTarget = nil
        state.craft.qualityState = nil
        return
    end
    if not target or target.recipeID ~= recipeID then
        target = { recipeID = recipeID, quality = nil, useConcentration = false }
        state.craft.qualityTarget = target
        frame.userClosed = false
    end
    useConcentration = target.useConcentration == true
    state.craft.qualityState = YQQuality.BuildRecipeState(schematicForm, useConcentration)
    local recipeState = state.craft.qualityState
    if not recipeState or recipeState.reachableQuality <= 0 then
        frame.status:SetText("Qualité indisponible")
        frame.maxText:SetText("")
        frame.marketText:SetText("Minbuyout : |cffaaaaaa?|r   Profit est. : |cffaaaaaa?|r")
        frame.addButton:Disable()
        for _, button in ipairs(frame.qualityButtons) do button:Hide() end
        frame.concentration:Show()
        frame.concentration:Enable()
        frame.concentration:SetChecked(useConcentration)
        frame.reagentHeader:Hide()
        for _, header in ipairs(frame.reagentQualityHeaders or {}) do header:Hide() end
        for _, row in ipairs(frame.reagentRows or {}) do row:Hide() end
        return
    end
    frame.concentration:Show()
    frame.reagentHeader:Show()
    local minimumQuality = recipeState.minQuality == math.huge and 1 or recipeState.minQuality
    target.quality = math.min(
        recipeState.maxQuality,
        math.max(minimumQuality, tonumber(target.quality) or recipeState.reachableQuality)
    )
    local selectedCandidate = YQQuality.FindCandidate(recipeState, target.quality)
    frame.maxText:SetText(
        "Qualité max : " .. YQQuality.GetQualityIcon(
            recipeState.maxQuality, 18, recipeState.simplifiedResult
        )
    )
    frame.status:SetText(
        "Atteignable : " .. YQQuality.GetQualityIcon(
            recipeState.reachableQuality, 18, recipeState.simplifiedResult
        )
    )
    DebugPrint(
        "quality-display recipe=" .. tostring(recipeState.recipeID)
            .. " target=" .. tostring(target.quality)
            .. " selected=" .. tostring(selectedCandidate and selectedCandidate.quality)
    )
    for quality, button in ipairs(frame.qualityButtons) do
        button.icon:SetAtlas(YQQuality.GetQualityAtlas(quality, recipeState.simplifiedResult))
        button:SetShown(quality >= minimumQuality and quality <= recipeState.maxQuality)
        button:SetEnabled(quality >= minimumQuality and quality <= recipeState.reachableQuality and YQQuality.FindCandidate(recipeState, quality) ~= nil)
        if quality == target.quality then
            button:LockHighlight()
        else
            button:UnlockHighlight()
        end
    end
    frame.concentration:SetChecked(useConcentration)
    frame.concentration:SetEnabled(recipeState.maxQuality > 1)
    local candidate = YQQuality.FindCandidate(recipeState, target.quality)
    local concentrationEnough = not useConcentration
        or YQQuality.HasEnoughConcentration(candidate, ReadQuantityInput(frame.addButton.qtyBox))
    frame.addButton:SetEnabled(candidate ~= nil and concentrationEnough)
    local pricing = YQQuality.GetCandidatePricing(recipeState, candidate)
    local minBuyoutText = pricing.minBuyout and GetMoneyString(math.floor(pricing.minBuyout), true) or "|cffaaaaaa?|r"
    local profitText = YQQuality.FormatSignedMoney(pricing.profit)
    local profitColor = "|cffaaaaaa"
    if type(pricing.profit) == "number" then
        profitColor = pricing.profit > 0 and "|cff55dd77" or (pricing.profit < 0 and "|cffff5555" or "|cffffffff")
    end
    frame.marketText:SetText(
        "Minbuyout : " .. minBuyoutText
            .. "   Profit est. : " .. profitColor .. profitText .. "|r"
    )
    DebugPrint(
        "quality-price recipe=" .. tostring(recipeState.recipeID)
            .. " target=" .. tostring(target.quality)
            .. " minbuyout=" .. tostring(pricing.minBuyout)
            .. " materials=" .. tostring(pricing.materialCost)
            .. " profit=" .. tostring(pricing.profit)
    )

    local reagentQualityCount = math.min(3, math.max(0, recipeState.reagentQualityCount or 0))
    local columnCenter = reagentQualityCount == 2 and 250 or 220
    local columnSpacing = reagentQualityCount == 2 and 46 or 42
    for quality, header in ipairs(frame.reagentQualityHeaders or {}) do
        header:ClearAllPoints()
        header:SetPoint("TOPLEFT", frame, "TOPLEFT", columnCenter - 10 + ((quality - 1) * columnSpacing), -142)
        header:SetAtlas(YQQuality.GetQualityAtlas(quality, reagentQualityCount == 2))
        header:SetShown(quality <= reagentQualityCount)
    end

    YQQuality.EnsureReagentRows(frame, #(recipeState.slots or {}))
    frame:SetHeight(math.max(260, 204 + (#(recipeState.slots or {}) * 28)))
    for rowIndex, row in ipairs(frame.reagentRows or {}) do
        local slotData = recipeState.slots and recipeState.slots[rowIndex]
        local selectedCounts = {}
        if candidate and slotData then
            for _, info in ipairs(candidate.reagents or {}) do
                if tonumber(info.dataSlotIndex) == tonumber(slotData.slot.dataSlotIndex) then
                    local itemID = tonumber(info.reagent and info.reagent.itemID)
                    for _, option in ipairs(slotData.options or {}) do
                        if option.itemID == itemID then
                            selectedCounts[option.quality] = (selectedCounts[option.quality] or 0)
                                + (tonumber(info.quantity) or 0)
                            break
                        end
                    end
                end
            end
        end
        if slotData and slotData.options and slotData.options[1] then
            local itemID = tonumber(slotData.options[1].itemID)
            local itemIcon = GetItemIcon(itemID)
            row.icon:SetTexture(itemIcon)
            row.itemID = itemID
            for quality = 1, 3 do
                local count = row.counts[quality]
                count:ClearAllPoints()
                count:SetPoint("LEFT", row, "LEFT", columnCenter - 16 + ((quality - 1) * columnSpacing), 0)
                count:SetText((selectedCounts[quality] or 0) > 0 and tostring(selectedCounts[quality]) or "-")
                count:SetShown(quality <= reagentQualityCount)
            end
            row:Show()
        else
            row.itemID = nil
            row:Hide()
        end
    end
end

local function AnchorQueueButton(button, target, fallbackParent)
    button:ClearAllPoints()
    if target then
        button:SetPoint("BOTTOMRIGHT", target, "TOPRIGHT", 0, 8)
    else
        button:SetPoint("BOTTOMRIGHT", fallbackParent, "BOTTOMRIGHT", -18, 54)
    end
end

local function EnsureOrderQueueButton(schematicForm)
    if not schematicForm then
        return nil
    end

    local button = schematicForm.yayaQueueAddButton
    if button then
        return button
    end

    local orderView = ProfessionsFrame and ProfessionsFrame.OrdersPage and ProfessionsFrame.OrdersPage.OrderView
    local parent = orderView or schematicForm
    button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(110, 22)
    button:SetText("Ajouter YQ")
    button:SetFrameLevel((parent:GetFrameLevel() or 1) + 5)
    button.schematicForm = schematicForm
    button:SetScript("OnClick", function(self)
        local context = GetRecipeContextFromSchematicForm(self.schematicForm)
        local quantity = QueueRecipeContext(context, self.qtyBox)
        if not quantity then
            Print("Aucune recette de commande selectionnee.")
            return
        end

        Print("Ajoute " .. quantity .. "x " .. context.recipeName .. " a YayaQueue.")
    end)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Ajouter YayaQueue")
        GameTooltip:AddLine("Ajoute cette recette avec la quantite indiquee a gauche.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", GameTooltip_Hide)

    AnchorQueueButton(button, orderView and (orderView.CreateButton or orderView.CompleteOrderButton), parent)
    CreateQuantityControls(button)

    schematicForm.yayaQueueAddButton = button
    return button
end

local function EnsureCraftingQueueButton(schematicForm)
    if not schematicForm then
        return nil
    end

    local button = schematicForm.yayaQueueRecipeButton
    if button then
        return button
    end

    local craftingPage = ProfessionsFrame and ProfessionsFrame.CraftingPage
    local parent = craftingPage or schematicForm
    button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(110, 22)
    button:SetText("Ajouter YQ")
    button:SetFrameLevel((parent:GetFrameLevel() or 1) + 5)
    button.schematicForm = schematicForm
    button:SetScript("OnClick", function(self)
        local context = GetRecipeContextFromSchematicForm(self.schematicForm)
        local quantity = QueueRecipeContext(context, self.qtyBox)
        if not quantity then
            Print("Aucune recette selectionnee.")
            return
        end

        Print("Ajoute " .. quantity .. "x " .. context.recipeName .. " a YayaQueue.")
    end)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Ajouter YayaQueue")
        GameTooltip:AddLine("Ajoute cette recette avec la quantite indiquee a gauche.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", GameTooltip_Hide)

    AnchorQueueButton(button, craftingPage and (craftingPage.CreateButton or craftingPage.CreateAllButton), parent)
    local minusButton = CreateQuantityControls(button)

    local dumpConcentrationButton = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    dumpConcentrationButton:SetSize(90, 22)
    dumpConcentrationButton:SetPoint("RIGHT", minusButton, "LEFT", -10, 0)
    dumpConcentrationButton:SetFrameLevel((parent:GetFrameLevel() or 1) + 5)
    dumpConcentrationButton:SetText("dump conc.")
    dumpConcentrationButton:Hide()
    dumpConcentrationButton.schematicForm = schematicForm
    dumpConcentrationButton:SetScript("OnClick", function(self)
        local dumpState = GetConcentrationDumpState(self.schematicForm)
        if not (dumpState and dumpState.context and dumpState.maxQuantity > 0) then
            Print("Concentration ou recette indisponible.")
            return
        end

        local quantity = QueueRecipeContext(dumpState.context, nil, dumpState.maxQuantity)
        Print("Ajoute " .. quantity .. "x " .. dumpState.context.recipeName .. " avec concentration.")
    end)
    dumpConcentrationButton:SetScript("OnEnter", function(self)
        local dumpState = GetConcentrationDumpState(self.schematicForm)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Vider la concentration")
        if dumpState and dumpState.cost > 0 then
            GameTooltip:AddLine(
                "Ajoute " .. dumpState.maxQuantity .. " craft(s) avec concentration ("
                    .. dumpState.available .. " disponibles, " .. dumpState.cost .. " par craft).",
                1, 1, 1, true
            )
        else
            GameTooltip:AddLine("Le cout de concentration de cette recette est indisponible.", 1, 0.25, 0.25, true)
        end
        GameTooltip:Show()
    end)
    dumpConcentrationButton:SetScript("OnLeave", GameTooltip_Hide)
    button.dumpConcentrationButton = dumpConcentrationButton
    button.firstCraftAnchor = minusButton

    local firstCraftButton = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    firstCraftButton:SetSize(95, 22)
    firstCraftButton:SetPoint("RIGHT", minusButton, "LEFT", -10, 0)
    firstCraftButton:SetFrameLevel((parent:GetFrameLevel() or 1) + 5)
    firstCraftButton:SetText("first craft")
    firstCraftButton:Hide()
    firstCraftButton:SetScript("OnClick", function(self)
        QueueAllAffordableFirstCrafts(self)
    end)
    firstCraftButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Ajouter les first crafts")
        if type(_G.CraftSimAPI) == "table" then
            GameTooltip:AddLine("Ajoute une fois chaque recette connue non realisee dont le cout CraftSim est strictement inferieur a 1000 po. Les prix inconnus sont ignores.", 1, 1, 1, true)
            GameTooltip:AddLine("Les cooldowns disponibles sont reserves par charge, y compris entre recettes partageant le meme cooldown.", 1, 1, 1, true)
        else
            GameTooltip:AddLine("CraftSim doit etre active pour calculer les couts.", 1, 0.25, 0.25, true)
        end
        GameTooltip:Show()
    end)
    firstCraftButton:SetScript("OnLeave", GameTooltip_Hide)
    button.firstCraftButton = firstCraftButton

    schematicForm.yayaQueueRecipeButton = button
    return button
end

local function UpdateCraftingQueueButton()
    local schematicForm = GetCraftingSchematicForm()
    if not schematicForm then
        return
    end

    local button = EnsureCraftingQueueButton(schematicForm)
    local craftingPage = ProfessionsFrame and ProfessionsFrame.CraftingPage
    AnchorQueueButton(button, craftingPage and (craftingPage.CreateButton or craftingPage.CreateAllButton), craftingPage or schematicForm)
    local isVisible = schematicForm:IsShown()
    button:SetShown(isVisible)
    if isVisible then
        button:SetEnabled(GetRecipeContextFromSchematicForm(schematicForm) ~= nil)
    end
    local dumpState = isVisible and GetConcentrationDumpState(schematicForm) or nil
    local showDumpConcentration = isVisible
    if button.dumpConcentrationButton then
        button.dumpConcentrationButton:SetShown(showDumpConcentration)
        button.dumpConcentrationButton:SetEnabled(
            showDumpConcentration and dumpState ~= nil and dumpState.context ~= nil and dumpState.maxQuantity > 0
        )
    end
    if button.firstCraftButton then
        button.firstCraftButton:ClearAllPoints()
        if showDumpConcentration and button.dumpConcentrationButton then
            button.firstCraftButton:SetPoint("RIGHT", button.dumpConcentrationButton, "LEFT", -10, 0)
        else
            button.firstCraftButton:SetPoint("RIGHT", button.firstCraftAnchor, "LEFT", -10, 0)
        end
        local hasAddableFirstCraft = isVisible and HasAddableFirstCraft()
        button.firstCraftButton:SetShown(hasAddableFirstCraft)
        button.firstCraftButton:SetEnabled(
            hasAddableFirstCraft and not state.firstCraftScanRunning
        )
    end
    YQQuality.UpdateSelector()
end

local function UpdateOrderQueueButton()
    local schematicForm = GetOrderSchematicForm()
    if not schematicForm then
        return
    end

    local button = EnsureOrderQueueButton(schematicForm)
    local orderView = ProfessionsFrame and ProfessionsFrame.OrdersPage and ProfessionsFrame.OrdersPage.OrderView
    AnchorQueueButton(button, orderView and (orderView.CreateButton or orderView.CompleteOrderButton), orderView or schematicForm)
    local isVisible = schematicForm:IsShown()
    button:SetShown(isVisible)
    if isVisible then
        button:SetEnabled(GetRecipeContextFromSchematicForm(schematicForm) ~= nil)
    end
end

local function EnsureCustomerOrderQueueButton(orderForm)
    if not orderForm then
        return nil
    end

    local button = orderForm.yayaQueueAddButton
    if button then
        return button
    end

    button = CreateFrame("Button", nil, orderForm, "UIPanelButtonTemplate")
    button:SetSize(110, 22)
    button:SetText("Ajouter YQ")
    button:SetFrameLevel((orderForm:GetFrameLevel() or 1) + 5)
    button.orderForm = orderForm
    button:SetScript("OnClick", function(self)
        local context = GetRecipeContextFromCustomerOrdersForm(self.orderForm)
        local quantity = QueueRecipeContext(context, self.qtyBox)
        if not quantity then
            Print("Aucune recette de commande selectionnee.")
            return
        end

        Print("Ajoute " .. quantity .. "x " .. context.recipeName .. " a YayaQueue.")
    end)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Ajouter YayaQueue")
        GameTooltip:AddLine("Ajoute cette commande avec la quantite indiquee a gauche.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", GameTooltip_Hide)

    local listOrderButton = orderForm.PaymentContainer and orderForm.PaymentContainer.ListOrderButton
    AnchorQueueButton(button, listOrderButton, orderForm)
    CreateQuantityControls(button)

    orderForm.yayaQueueAddButton = button
    return button
end

local function UpdateCustomerOrderQueueButton()
    local orderForm = GetCustomerOrdersForm()
    if not orderForm then
        return
    end

    local button = EnsureCustomerOrderQueueButton(orderForm)
    local listOrderButton = orderForm.PaymentContainer and orderForm.PaymentContainer.ListOrderButton
    AnchorQueueButton(button, listOrderButton, orderForm)
    local isVisible = orderForm:IsShown()
    button:SetShown(isVisible)
    if isVisible then
        button:SetEnabled(GetRecipeContextFromCustomerOrdersForm(orderForm) ~= nil)
    end
end

local function HookRefreshTarget(target)
    if not target or type(target.HookScript) ~= "function" or target.yayaQueueRefreshHooked then
        return
    end

    target.yayaQueueRefreshHooked = true
    target:HookScript("OnShow", ScheduleRefresh)
    target:HookScript("OnHide", ScheduleRefresh)
end

local function EnsureProfessionHooks()
    if not ProfessionsFrame and not ProfessionsCustomerOrdersFrame then
        return
    end

    local targets = {
        ProfessionsFrame,
        ProfessionsFrame and ProfessionsFrame.CraftingPage,
        ProfessionsFrame and ProfessionsFrame.OrdersPage,
        ProfessionsFrame and ProfessionsFrame.OrdersPage and ProfessionsFrame.OrdersPage.OrderView,
        GetOrderSchematicForm(),
        GetCraftingSchematicForm(),
        ProfessionsCustomerOrdersFrame,
        GetCustomerOrdersForm(),
    }
    for _, target in ipairs(targets) do
        HookRefreshTarget(target)
    end
end

local function HookCraftAPIs()
    if type(C_TradeSkillUI) ~= "table" then
        return
    end

    if not state.craftApiHooksInitialized then
        if type(C_TradeSkillUI.CraftRecipe) == "function" then
            hooksecurefunc(C_TradeSkillUI, "CraftRecipe", function(recipeID, amount)
                QueuePendingCraftRecipe(recipeID, amount)
            end)
        end
        if type(C_TradeSkillUI.CraftEnchant) == "function" then
            hooksecurefunc(C_TradeSkillUI, "CraftEnchant", function(recipeID, amount)
                QueuePendingCraftRecipe(recipeID, amount)
            end)
        end
        if type(C_TradeSkillUI.CraftSalvage) == "function" then
            hooksecurefunc(C_TradeSkillUI, "CraftSalvage", function(recipeID, amount)
                QueuePendingCraftRecipe(recipeID, amount)
            end)
        end
        if type(C_TradeSkillUI.RecraftRecipe) == "function" then
            hooksecurefunc(C_TradeSkillUI, "RecraftRecipe", function(itemGUID)
                local recipeID = itemGUID and select(1, C_TradeSkillUI.GetOriginalCraftRecipeID(itemGUID)) or nil
                QueuePendingCraftRecipe(recipeID, 1)
            end)
        end
        if type(C_TradeSkillUI.RecraftRecipeForOrder) == "function" then
            hooksecurefunc(C_TradeSkillUI, "RecraftRecipeForOrder", function(_, itemGUID)
                local recipeID = itemGUID and select(1, C_TradeSkillUI.GetOriginalCraftRecipeID(itemGUID)) or nil
                QueuePendingCraftRecipe(recipeID, 1)
            end)
        end

        state.craftApiHooksInitialized = true
    end

    if not state.orderApiHooksInitialized and type(C_CraftingOrders) == "table" then
        if type(C_CraftingOrders.FulfillOrder) == "function" then
            hooksecurefunc(C_CraftingOrders, "FulfillOrder", function(orderID)
                HandlePatronFulfill(orderID, "api")
            end)
        end
        if type(C_CraftingOrders.ClaimOrder) == "function" then
            hooksecurefunc(C_CraftingOrders, "ClaimOrder", function(orderID, professionID)
                DebugPrint("claim-hook order=" .. tostring(orderID) .. " profession=" .. tostring(professionID))
            end)
        end

        state.orderApiHooksInitialized = true
    end
end

local function CreateCraftPanel()
    if state.craft.panel then
        return
    end

    local panel = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    panel:SetSize(274, CRAFT_PANEL_EXPANDED_HEIGHT)
    panel:SetFrameStrata("HIGH")
    panel:SetClampedToScreen(true)
    panel:SetMovable(true)
    panel:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    panel:SetBackdropColor(0.05, 0.05, 0.05, 0.92)

    local dragHandle = CreateFrame("Frame", nil, panel)
    dragHandle:SetPoint("TOPLEFT", 6, -6)
    dragHandle:SetPoint("TOPRIGHT", -66, -6)
    dragHandle:SetHeight(18)
    dragHandle:EnableMouse(true)
    dragHandle:RegisterForDrag("LeftButton")
    dragHandle:SetFrameLevel(panel:GetFrameLevel())
    dragHandle:SetScript("OnDragStart", function()
        panel:StartMoving()
    end)
    dragHandle:SetScript("OnDragStop", function()
        panel:StopMovingOrSizing()
        SavePanelPoint(panel)
    end)

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    title:SetPoint("TOPLEFT", dragHandle, "TOPLEFT", 4, -1)
    title:SetText("YayaQueue")

    local resetButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    resetButton:SetSize(48, 18)
    resetButton:SetPoint("TOPRIGHT", -10, -6)
    resetButton:SetFrameStrata("HIGH")
    resetButton:SetFrameLevel((panel:GetFrameLevel() or 1) + 5)
    resetButton:SetText("Reset")
    resetButton:SetScript("OnClick", ResetQueue)

    local selectedText = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    selectedText:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
    selectedText:SetPoint("RIGHT", panel, "RIGHT", -10, 0)
    selectedText:SetJustifyH("LEFT")
    selectedText:SetText("")

    local todoTitle = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    todoTitle:SetPoint("TOPLEFT", selectedText, "BOTTOMLEFT", 0, -10)
    todoTitle:SetText("A faire")

    local lines = {}
    for index = 1, MAX_CRAFT_LINES do
        local line = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        if index == 1 then
            line:SetPoint("TOPLEFT", todoTitle, "BOTTOMLEFT", 0, -6)
        else
            line:SetPoint("TOPLEFT", lines[index - 1], "BOTTOMLEFT", 0, -4)
        end
        line:SetPoint("RIGHT", panel, "RIGHT", -10, 0)
        line:SetJustifyH("LEFT")
        line:SetText("")
        lines[index] = line
    end

    local statusText = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    statusText:SetPoint("BOTTOMLEFT", 10, 10)
    statusText:SetPoint("RIGHT", panel, "RIGHT", -140, 0)
    statusText:SetJustifyH("LEFT")
    statusText:SetText("")

    local nextButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    nextButton:SetSize(120, 22)
    nextButton:SetPoint("BOTTOMRIGHT", -10, 8)
    nextButton:SetText("Next")
    nextButton:SetScript("OnClick", RunPatronNextAction)
    nextButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Next patron order")
        GameTooltip:AddLine("Ouvre puis clique l'action du prochain patron order en file.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    nextButton:SetScript("OnLeave", GameTooltip_Hide)
    nextButton:Hide()

    local vendorTitle = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    vendorTitle:SetPoint("BOTTOMLEFT", 10, 108)
    vendorTitle:SetPoint("RIGHT", panel, "RIGHT", -10, 0)
    vendorTitle:SetJustifyH("LEFT")
    vendorTitle:SetText("Acheter ici")
    vendorTitle:Hide()

    local vendorButtons = {}
    for index = 1, 1 do
        local button = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        button:SetSize(248, 20)
        if index == 1 then
            button:SetPoint("BOTTOMLEFT", 10, 84)
        else
            button:SetPoint("BOTTOMLEFT", vendorButtons[index - 1], "TOPLEFT", 0, 4)
        end
        button:SetScript("OnClick", function(self)
            BuyVendorTasks(self.tasks)
        end)
        button:Hide()
        vendorButtons[index] = button
    end

    state.craft.panel = panel
    state.craft.resetButton = resetButton
    state.craft.nextButton = nextButton
    state.craft.selectedText = selectedText
    state.craft.todoTitle = todoTitle
    state.craft.lines = lines
    state.craft.statusText = statusText
    state.craft.vendorTitle = vendorTitle
    state.craft.vendorButtons = vendorButtons

    ApplyPanelPoint(panel)
end

local function CreateAuctionFrame()
    if state.ah.frame or not AuctionHouseFrame then
        return
    end

    local frame = CreateFrame("Frame", nil, AuctionHouseFrame, "BackdropTemplate")
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
    frame:SetBackdropColor(0.05, 0.05, 0.05, 0.92)
    frame:Hide()

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", 14, -12)
    title:SetText("YayaQueue")

    local helpText = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    helpText:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
    helpText:SetPoint("RIGHT", frame, "RIGHT", -14, 0)
    helpText:SetJustifyH("LEFT")
    helpText:SetText("Rechercher tout puis acheter suivant.")

    local totalText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    totalText:SetPoint("TOPLEFT", helpText, "BOTTOMLEFT", 0, -8)
    totalText:SetPoint("RIGHT", frame, "RIGHT", -14, 0)
    totalText:SetJustifyH("LEFT")
    totalText:SetText("Total estime: ?")

    local lines = {}
    for index = 1, MAX_AH_LINES do
        local line = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        if index == 1 then
            line:SetPoint("TOPLEFT", totalText, "BOTTOMLEFT", 0, -10)
        else
            line:SetPoint("TOPLEFT", lines[index - 1], "BOTTOMLEFT", 0, -8)
        end
        line:SetPoint("RIGHT", frame, "RIGHT", -14, 0)
        line:SetJustifyH("LEFT")
        line:SetText("")
        lines[index] = line
    end

    local statusText = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    statusText:SetPoint("BOTTOMLEFT", 14, 16)
    statusText:SetPoint("RIGHT", frame, "RIGHT", -160, 0)
    statusText:SetJustifyH("LEFT")
    statusText:SetText("")

    local actionButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    actionButton:SetSize(130, 24)
    actionButton:SetPoint("BOTTOMRIGHT", -14, 12)
    actionButton:SetText("Rechercher tout")
    actionButton:SetScript("OnClick", function()
        OnAuctionActionClick()
    end)

    state.ah.frame = frame
    state.ah.lines = lines
    state.ah.statusText = statusText
    state.ah.totalText = totalText
    state.ah.actionButton = actionButton
end

local function CreateAuctionTab()
    if state.ah.tab or not AuctionHouseFrame or not AuctionHouseFrame.Tabs then
        return
    end

    local libAHTab = type(LibStub) == "table" and LibStub("LibAHTab-1-0", true) or nil
    if libAHTab and state.ah.frame then
        if not libAHTab:DoesIDExist(addonName) then
            libAHTab:CreateTab(addonName, state.ah.frame, "YQ", "YayaQueue")
        end

        local tab = libAHTab:GetButton(addonName)
        if tab then
            tab.libAHTab = libAHTab
            tab.libTabID = addonName
            tab.tabHeader = "YayaQueue"
            tab:HookScript("OnClick", function()
                ScheduleRefresh()
            end)
            state.ah.tab = tab
            return
        end
    end

    local root = CreateFrame("Frame", nil, AuctionHouseFrame)
    root:SetSize(10, 10)
    root:SetPoint("TOPLEFT", AuctionHouseFrame.Tabs[#AuctionHouseFrame.Tabs], "TOPRIGHT", 0, 0)

    local tab = CreateFrame("Button", addonName .. "AuctionTab", root, "AuctionHouseFrameDisplayModeTabTemplate")
    tab:SetText("YQ")
    PanelTemplates_TabResize(tab, 20, nil, 70)
    tab:SetPoint("TOPLEFT", root, "TOPLEFT", 3, 0)
    tab:SetHitRectInsets(0, 0, 0, 0)
    tab.tabHeader = "YayaQueue"
    PanelTemplates_DeselectTab(tab)
    tab:SetScript("OnClick", ShowAuctionFrame)

    hooksecurefunc(AuctionHouseFrame, "SetDisplayMode", function(_, mode)
        if mode and not (type(mode) == "table" and next(mode) == nil) then
            HideAuctionFrame()
        end
    end)

    state.ah.tab = tab
end

local function EnsureAuctionUI()
    CreateAuctionFrame()
    CreateAuctionTab()
end

local function SendSearchQuery(itemID, purpose)
    local itemKey = MakeItemKey(itemID)
    if not itemKey or not C_AuctionHouse or type(C_AuctionHouse.SendSearchQuery) ~= "function" then
        return false
    end

    if C_AuctionHouse.IsThrottledMessageSystemReady and not C_AuctionHouse.IsThrottledMessageSystemReady() then
        state.ah.waitingSearch = {
            itemID = itemID,
            purpose = purpose,
        }
        state.ah.statusMessage = "Throttle en attente"
        ScheduleRefresh()
        return false
    end

    local isCommodity = IsCommodityItem(itemID)
    state.ah.waitingSearch = nil
    state.ah.activeSearch = {
        itemID = itemID,
        purpose = purpose,
    }
    state.ah.statusMessage = "Recherche " .. GetItemName(itemID)
    C_AuctionHouse.SendSearchQuery(itemKey, isCommodity and COMMODITY_SORT or ITEM_SORTS, not isCommodity)
    ScheduleRefresh()
    return true
end

local function ProcessNextQueuedSearch()
    if state.ah.activeSearch or state.ah.waitingSearch then
        return
    end

    if not state.ah.searchQueue or #state.ah.searchQueue == 0 then
        state.ah.searchQueue = nil
        state.ah.statusMessage = "Recherche terminee"
        ScheduleRefresh()
        return
    end

    local itemID = table.remove(state.ah.searchQueue, 1)
    SendSearchQuery(itemID, "scan")
end

local function StartSearchAll(summary)
    local queue = {}
    for _, task in ipairs(summary.auctionTasks) do
        if not state.searchCache[task.itemID] then
            table.insert(queue, task.itemID)
        end
    end

    if #queue == 0 then
        state.ah.statusMessage = "Recherche deja faite"
        ScheduleRefresh()
        return
    end

    state.ah.searchQueue = queue
    state.ah.statusMessage = "Recherche " .. #queue .. " items"
    ProcessNextQueuedSearch()
end

local function StartPurchaseFromCache(summary, itemID)
    local task = FindAuctionTask(summary, itemID)
    local cache = task and state.searchCache[itemID] or nil
    if not task or not cache or not cache.available or cache.available <= 0 then
        state.ah.statusMessage = "Aucun resultat pour " .. GetItemName(itemID)
        ScheduleRefresh()
        return
    end

    if cache.kind == "commodity" then
        local quantity = math.min(task.missing, cache.available)
        if quantity <= 0 then
            state.ah.statusMessage = "Aucune quantite dispo"
            ScheduleRefresh()
            return
        end

        state.ah.pendingCommodity = {
            itemID = itemID,
            quantity = quantity,
            name = task.name,
            confirmSent = false,
            ownedBefore = GetImmediateOwnedCount(itemID),
        }
        state.ah.statusMessage = "Achat " .. quantity .. "x " .. task.name
        C_AuctionHouse.StartCommoditiesPurchase(itemID, quantity)
        ScheduleRefresh()
        return
    end

    local auction = cache.bestAuction
    if not auction then
        state.ah.statusMessage = "Aucune enchere achetable"
        ScheduleRefresh()
        return
    end

    state.ah.pendingItem = {
        itemID = itemID,
        quantity = math.max(1, math.min(task.missing, auction.quantity or 1)),
        name = task.name,
        ownedBefore = GetImmediateOwnedCount(itemID),
    }
    state.ah.statusMessage = "Achat " .. state.ah.pendingItem.quantity .. "x " .. task.name
    C_AuctionHouse.PlaceBid(auction.auctionID, auction.buyoutAmount)
    state.searchCache[itemID] = nil
    C_Timer.After(0.5, ScheduleRefresh)
    ScheduleRefresh()
end

local function BuyNext(summary)
    local task, cache = GetNextPurchasableTask(summary)
    if task and cache then
        StartPurchaseFromCache(summary, task.itemID)
        return
    end

    if NeedsAuctionSearch(summary) then
        StartSearchAll(summary)
        return
    end

    local retryEmptySearch = false
    for _, auctionTask in ipairs(summary.auctionTasks) do
        local emptyCache = state.searchCache[auctionTask.itemID]
        if emptyCache and (tonumber(emptyCache.available) or 0) <= 0 then
            state.searchCache[auctionTask.itemID] = nil
            retryEmptySearch = true
        end
    end
    if retryEmptySearch then
        state.ah.statusMessage = "Nouvelle recherche des items indisponibles"
        StartSearchAll(summary)
        return
    end

    state.ah.statusMessage = "Rien de dispo a acheter"
    ScheduleRefresh()
end

OnAuctionActionClick = function()
    local summary = BuildQueueSummary()
    PruneSearchCache(summary)

    if #summary.auctionTasks == 0 then
        state.ah.statusMessage = "Aucun achat HV"
        ScheduleRefresh()
        return
    end

    if state.ah.pendingCommodity or state.ah.pendingItem or state.ah.activeSearch or state.ah.waitingSearch or (state.ah.searchQueue and #state.ah.searchQueue > 0) then
        return
    end

    if NeedsAuctionSearch(summary) then
        StartSearchAll(summary)
    else
        BuyNext(summary)
    end
end

local function HandleSearchResults(itemID)
    if not (state.ah.activeSearch and state.ah.activeSearch.itemID == itemID) then
        return
    end

    CaptureSearchCache(itemID)

    local purpose = state.ah.activeSearch.purpose
    state.ah.activeSearch = nil
    if purpose == "scan" then
        ProcessNextQueuedSearch()
    else
        local summary = BuildQueueSummary()
        PruneSearchCache(summary)
        StartPurchaseFromCache(summary, itemID)
    end

    ScheduleRefresh()
end

local function ResumeSearches()
    if state.ah.waitingSearch then
        local pending = state.ah.waitingSearch
        SendSearchQuery(pending.itemID, pending.purpose)
        return
    end

    if state.ah.searchQueue and not state.ah.activeSearch then
        ProcessNextQueuedSearch()
    end
end

function RefreshAll()
    InstallRecipeDescriptionGuard()
    if InCombatLockdown and InCombatLockdown() then
        state.refreshDeferredByCombat = true
        return
    end

    EnsureDB()
    EnsureProfessionHooks()
    HookCraftAPIs()
    CacheMerchantItems()

    local summary = BuildQueueSummary()
    PruneSearchCache(summary)
    ApplyQueuedRecipeConfigNow()

    CreateCraftPanel()
    if state.craft.panel then
        if SummaryHasTasks(summary) then
            state.craft.panel:Show()
            UpdateCraftPanel(summary)
        else
            state.craft.panel:Hide()
        end
    end

    UpdateCraftingQueueButton()
    UpdateOrderQueueButton()
    UpdateCustomerOrderQueueButton()

    if AuctionHouseFrame and AuctionHouseFrame:IsShown() then
        EnsureAuctionUI()
        UpdateAuctionFrame(summary)
    elseif state.ah.frame then
        HideAuctionFrame()
    end
end

addon:SetScript("OnEvent", function(_, event, arg1, arg2)
    InstallRecipeDescriptionGuard()
    if event == "ADDON_LOADED" then
        if arg1 == "TradeSkillMaster" then
            C_Timer.After(0, UpdateTSMMacroBridge)
            return
        end
        if arg1 ~= addonName then
            return
        end

        EnsureDB()
        addon:RegisterEvent("PLAYER_ENTERING_WORLD")
        addon:RegisterEvent("TRADE_SKILL_SHOW")
        addon:RegisterEvent("TRADE_SKILL_CLOSE")
        addon:RegisterEvent("TRADE_SKILL_ITEM_CRAFTED_RESULT")
        addon:RegisterEvent("SPELLS_CHANGED")
        addon:RegisterEvent("SKILL_LINES_CHANGED")
        addon:RegisterEvent("SPELL_DATA_LOAD_RESULT")
        addon:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
        addon:RegisterEvent("BAG_UPDATE_DELAYED")
        addon:RegisterEvent("PLAYERBANKSLOTS_CHANGED")
        pcall(addon.RegisterEvent, addon, "PLAYERREAGENTBANKSLOTS_CHANGED")
        addon:RegisterEvent("MERCHANT_SHOW")
        addon:RegisterEvent("MERCHANT_UPDATE")
        addon:RegisterEvent("AUCTION_HOUSE_SHOW")
        addon:RegisterEvent("AUCTION_HOUSE_CLOSED")
        addon:RegisterEvent("UNIT_SPELLCAST_FAILED")
        addon:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
        addon:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
        addon:RegisterEvent("PLAYER_REGEN_ENABLED")
        HookCraftAPIs()
        addon:RegisterEvent("ITEM_SEARCH_RESULTS_UPDATED")
        addon:RegisterEvent("COMMODITY_SEARCH_RESULTS_UPDATED")
        addon:RegisterEvent("COMMODITY_PRICE_UPDATED")
        addon:RegisterEvent("COMMODITY_PRICE_UNAVAILABLE")
        addon:RegisterEvent("COMMODITY_PURCHASE_SUCCEEDED")
        addon:RegisterEvent("COMMODITY_PURCHASE_FAILED")
        addon:RegisterEvent("AUCTION_HOUSE_THROTTLED_SYSTEM_READY")
        addon:RegisterEvent("BIDS_UPDATED")
        addon:RegisterEvent("AUCTION_CANCELED")
        addon:RegisterEvent("CHAT_MSG_SYSTEM")
        addon:RegisterEvent("UI_ERROR_MESSAGE")
        C_Timer.After(0, UpdateTSMMacroBridge)
        ScheduleRefresh()
        return
    end

    if event == "PLAYER_ENTERING_WORLD" then
        UpdateTSMMacroBridge()
        ScheduleRefresh()
        return
    end

    if event == "TRADE_SKILL_SHOW" then
        if state.craft.qualityFrame then state.craft.qualityFrame.userClosed = false end
        C_Timer.After(0, ScheduleRefresh)
        return
    end

    if event == "TRADE_SKILL_CLOSE" then
        state.firstCraftAvailability = {}
        state.craft.qualityTarget = nil
        state.craft.qualityState = nil
        if state.craft.qualityFrame then state.craft.qualityFrame:Hide() end
        DebugPrint("event=TRADE_SKILL_CLOSE pendingEntries=" .. tostring(#state.pendingCraftEntries) .. " pendingBatches=" .. tostring(#state.pendingCraftBatches) .. " lock=" .. tostring(IsCraftClickLocked()))
        if not IsCraftClickLocked() and #state.pendingCraftEntries == 0 and #state.pendingCraftBatches == 0 then
            ClearPendingCraftBatches()
            ClearPendingCraftEntries()
        end
        EndCraftClickLock()
        local nextActionLock = GetNextActionLock()
        if nextActionLock and nextActionLock.action == "craft" then
            ClearNextActionLock("trade-skill-close")
        end
        ScheduleRefresh()
        return
    end

    if event == "AUCTION_HOUSE_SHOW" then
        C_Timer.After(0, function()
            if not AuctionHouseFrame or not AuctionHouseFrame:IsShown() then
                return
            end

            EnsureDB()
            local summary = BuildQueueSummary()
            EnsureAuctionUI()
            UpdateAuctionFrame(summary)
            if #summary.auctionTasks > 0 then
                ShowAuctionFrame()
            end
        end)
        return
    end

    if event == "TRADE_SKILL_ITEM_CRAFTED_RESULT" then
        state.firstCraftAvailability = {}
        EndCraftClickLock()
        local itemID = arg1 and arg1.itemID or nil
        local quantity = arg1 and arg1.quantity or nil
        local multicraft = arg1 and arg1.quantityMulticraft or nil
        DebugPrint("event=TRADE_SKILL_ITEM_CRAFTED_RESULT itemID=" .. tostring(itemID) .. " qty=" .. tostring(quantity) .. " multicraft=" .. tostring(multicraft) .. " pendingEntries=" .. tostring(#state.pendingCraftEntries) .. " pendingBatches=" .. tostring(#state.pendingCraftBatches))
        C_Timer.After(0.5, function()
            state.firstCraftAvailability = {}
            ScheduleRefresh()
        end)
        ScheduleRefresh()
        return
    end

    if event == "SPELLS_CHANGED" or event == "SKILL_LINES_CHANGED" then
        state.firstCraftAvailability = {}
        ScheduleRefresh()
        return
    end

    if event == "PLAYER_REGEN_ENABLED" then
        if state.refreshDeferredByCombat then
            state.refreshDeferredByCombat = false
            ScheduleRefresh()
        end
        return
    end

    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unit = arg1
        if unit ~= "player" then
            return
        end

        local pendingEntry = PopPendingCraftEntry()
        local recipeName = ConsumeCraftEntry(pendingEntry)
        if not recipeName then
            local recipeID = PopPendingCraftRecipe()
            recipeName = recipeID and ConsumeCraftFromQueue(recipeID) or nil
        else
            PopPendingCraftRecipe()
        end
        local nextActionLock = GetNextActionLock()
        if nextActionLock
            and nextActionLock.action == "craft"
            and nextActionLock.orderID == 0
            and pendingEntry
            and (tonumber(pendingEntry.orderID) or 0) == 0 then
            if (tonumber(pendingEntry.amount) or 0) <= 0 then
                ClearNextActionLock("craft-batch-complete")
            else
                nextActionLock.expiresAt = GetTime() + 30.0
                DebugPrint("next-lock progress action=craft remaining=" .. tostring(pendingEntry.amount))
            end
        end
        DebugPrint("event=UNIT_SPELLCAST_SUCCEEDED spellID=" .. tostring(arg3) .. " recipe=" .. tostring(pendingEntry and pendingEntry.recipeID) .. " order=" .. tostring(pendingEntry and pendingEntry.orderID) .. " remainingEntryAmount=" .. tostring(pendingEntry and pendingEntry.amount) .. " matched=" .. tostring(recipeName) .. " pendingEntries=" .. tostring(#state.pendingCraftEntries) .. " pendingBatches=" .. tostring(#state.pendingCraftBatches))
        if recipeName then
            state.ah.statusMessage = "Craft termine: " .. recipeName
            ScheduleRefresh()
        end
        return
    end

    if event == "UNIT_SPELLCAST_FAILED" or event == "UNIT_SPELLCAST_INTERRUPTED" then
        local unit = arg1
        if unit == "player" then
            DebugPrint("event=" .. tostring(event) .. " pendingEntries=" .. tostring(#state.pendingCraftEntries) .. " pendingBatches=" .. tostring(#state.pendingCraftBatches))
            ClearPendingCraftBatches()
            ClearPendingCraftEntries()
            EndCraftClickLock()
            local nextActionLock = GetNextActionLock()
            if nextActionLock and nextActionLock.action == "craft" then
                ClearNextActionLock(string.lower(tostring(event)))
            end
            ScheduleRefresh()
        end
        return
    end

    if event == "AUCTION_HOUSE_CLOSED" then
        ClearAuctionTransientState("HV fermee")
        HideAuctionFrame()
        ScheduleRefresh()
        return
    end

    if event == "MERCHANT_SHOW" or event == "MERCHANT_UPDATE" then
        if event == "MERCHANT_SHOW" then
            state.merchantAutoBuyGeneration = state.merchantAutoBuyGeneration + 1
            state.merchantAutoBuyAttempted = false
            state.merchantAutoBuyRetries = 0
            state.merchantAutoBuyPending = nil
            state.merchantAutoBuyScheduled = false
            wipe(state.merchantAutoBuySubmitted)
        end
        CacheMerchantItems()
        ScheduleAutoBuyVendor(event == "MERCHANT_SHOW" and MERCHANT_AUTO_BUY_INITIAL_DELAY or MERCHANT_AUTO_BUY_RETRY_DELAY)
        ScheduleRefresh()
        return
    end

    if event == "BAG_UPDATE_DELAYED" and state.merchantAutoBuyPending then
        ScheduleAutoBuyVendor(0)
        ScheduleRefresh()
        return
    end

    if event == "ITEM_SEARCH_RESULTS_UPDATED" then
        local itemID = type(arg1) == "table" and arg1.itemID or nil
        if itemID then
            HandleSearchResults(itemID)
        end
        return
    end

    if event == "COMMODITY_SEARCH_RESULTS_UPDATED" then
        HandleSearchResults(arg1)
        return
    end

    if event == "COMMODITY_PRICE_UPDATED" then
        if state.ah.pendingCommodity and not state.ah.pendingCommodity.confirmSent then
            state.ah.pendingCommodity.confirmSent = true
            C_AuctionHouse.ConfirmCommoditiesPurchase(state.ah.pendingCommodity.itemID, state.ah.pendingCommodity.quantity)
        end
        return
    end

    if event == "COMMODITY_PRICE_UNAVAILABLE" then
        state.ah.statusMessage = "Prix indisponible"
        if state.ah.pendingCommodity and type(C_AuctionHouse.CancelCommoditiesPurchase) == "function" then
            C_AuctionHouse.CancelCommoditiesPurchase()
        end
        state.ah.pendingCommodity = nil
        ScheduleRefresh()
        return
    end

    if event == "COMMODITY_PURCHASE_SUCCEEDED" then
        if state.ah.pendingCommodity then
            AddIncomingPurchase(
                state.ah.pendingCommodity.itemID,
                state.ah.pendingCommodity.quantity,
                state.ah.pendingCommodity.ownedBefore
            )
            state.searchCache[state.ah.pendingCommodity.itemID] = nil
            state.ah.statusMessage = "Achete " .. state.ah.pendingCommodity.quantity .. "x " .. state.ah.pendingCommodity.name
            state.ah.pendingCommodity = nil
        end
        ScheduleRefresh()
        return
    end

    if event == "COMMODITY_PURCHASE_FAILED" then
        state.ah.statusMessage = "Achat echoue"
        state.ah.pendingCommodity = nil
        ScheduleRefresh()
        return
    end

    if event == "AUCTION_HOUSE_THROTTLED_SYSTEM_READY" then
        ResumeSearches()
        return
    end

    if event == "BIDS_UPDATED" or event == "AUCTION_CANCELED" then
        if state.ah.pendingItem then
            FinalizePendingItemPurchase()
            ScheduleRefresh()
            return
        end
    end

    if event == "CHAT_MSG_SYSTEM" then
        if state.ah.pendingItem and arg1 == ERR_AUCTION_BID_PLACED then
            FinalizePendingItemPurchase()
            ScheduleRefresh()
            return
        end
    end

    if event == "UI_ERROR_MESSAGE" then
        local message = arg2
        if (state.ah.pendingItem or state.ah.pendingCommodity) and (
            message == ERR_AUCTION_DATABASE_ERROR
            or message == ERR_AUCTION_HIGHER_BID
            or message == ERR_ITEM_NOT_FOUND
            or message == ERR_AUCTION_BID_OWN
            or message == ERR_NOT_ENOUGH_MONEY
        ) then
            ClearAuctionTransientState(type(message) == "string" and message or "Achat echoue")
            ScheduleRefresh()
            return
        end
    end

    ScheduleRefresh()
end)

addon:RegisterEvent("ADDON_LOADED")
InstallRecipeDescriptionGuard()

YayaQueueAPI = YayaQueueAPI or {}

function YayaQueueAPI.AddRecipe(context, quantity)
    if type(context) ~= "table" or type(context.recipeID) ~= "number" or context.recipeID <= 0 then
        return false, "Invalid recipe context"
    end

    if context.queueKind == "patron" and WasPatronOrderCompletedRecently(context.orderID) then
        if debugNextCraft then
            DebugPrint("skip-add-recipe completed-order recipe=" .. tostring(context.recipeID) .. " order=" .. tostring(context.orderID))
        end
        return false, "Order deja terminee"
    end

    if type(context.recipeName) ~= "string" or context.recipeName == "" then
        context.recipeName = "Recette " .. tostring(context.recipeID)
    end

    context.mode = NormalizeQueueMode(context.mode)
    context.outputPerCraft = math.max(1, tonumber(context.outputPerCraft) or 1)
    context.reagents = NormalizeReagents(context.reagents)
    if debugNextCraft then
        local reagentParts = {}
        for _, reagent in ipairs(context.reagents) do
            reagentParts[#reagentParts + 1] = tostring(reagent.itemID) .. "x" .. tostring(reagent.quantity)
        end
        DebugPrint(
            "add-recipe recipe="
                .. tostring(context.recipeID)
                .. " order="
                .. tostring(context.orderID)
                .. " reagents=["
                .. table.concat(reagentParts, ", ")
                .. "]"
        )
    end
    AddRecipeToQueue(context, quantity)
    state.ah.statusMessage = "Ajoute " .. ClampQuantity(quantity) .. "x " .. context.recipeName
    ScheduleRefresh()
    return true
end

function YayaQueueAPI.AddItem(itemID, quantity, itemName)
    EnsureDB()
    itemID = tonumber(itemID) or 0
    if itemID <= 0 then
        return false, "Invalid itemID"
    end

    local directEntry = NormalizeDirectItemEntry({
        itemID = itemID,
        quantity = quantity,
        itemName = itemName,
        queueKind = "direct_item",
    })
    if not directEntry then
        return false, "Invalid direct item entry"
    end

    for _, entry in ipairs(db.queue) do
        if entry.queueKind == "direct_item" and entry.itemID == directEntry.itemID then
            entry.directQuantity = ClampQuantity((entry.directQuantity or 0) + directEntry.directQuantity)
            entry.itemName = directEntry.itemName
            state.searchCache[entry.itemID] = nil
            state.ah.statusMessage = "Ajoute " .. entry.directQuantity .. "x " .. entry.itemName
            ScheduleRefresh()
            return true
        end
    end

    table.insert(db.queue, directEntry)
    state.searchCache[directEntry.itemID] = nil
    state.ah.statusMessage = "Ajoute " .. directEntry.directQuantity .. "x " .. directEntry.itemName
    ScheduleRefresh()
    return true
end

function YayaQueueAPI.RemoveItem(itemID, quantity)
    EnsureDB()
    itemID = tonumber(itemID) or 0
    quantity = math.floor(tonumber(quantity) or 0)
    if itemID <= 0 then
        return false, "Invalid itemID"
    end
    if quantity <= 0 then
        return false, "Invalid quantity"
    end

    local quantityLeft = quantity
    local removedQuantity = 0
    local itemName = GetItemName(itemID)
    for index = #db.queue, 1, -1 do
        local entry = db.queue[index]
        if quantityLeft > 0 and entry.queueKind == "direct_item" and tonumber(entry.itemID) == itemID then
            local currentQuantity = math.max(0, math.floor(tonumber(entry.directQuantity) or 0))
            local removedFromEntry = math.min(currentQuantity, quantityLeft)
            local remainingQuantity = currentQuantity - removedFromEntry
            removedQuantity = removedQuantity + removedFromEntry
            quantityLeft = quantityLeft - removedFromEntry
            itemName = entry.itemName or itemName

            if remainingQuantity > 0 then
                entry.directQuantity = remainingQuantity
            else
                table.remove(db.queue, index)
            end
        end
    end

    if removedQuantity > 0 then
        state.searchCache[itemID] = nil
        DebugPrint("remove-item item=" .. tostring(itemID) .. " removed=" .. tostring(removedQuantity))
        state.ah.statusMessage = "Retire " .. removedQuantity .. "x " .. itemName
        ScheduleRefresh()
    end
    return true, removedQuantity
end

function YayaQueueAPI.SetItemTarget(itemID, quantity, itemName)
    EnsureDB()
    itemID = tonumber(itemID) or 0
    if itemID <= 0 then
        return false, "Invalid itemID"
    end

    local directEntry = NormalizeDirectItemEntry({
        itemID = itemID,
        quantity = quantity,
        itemName = itemName,
        queueKind = "direct_item",
    })
    if not directEntry then
        return false, "Invalid direct item entry"
    end

    for _, entry in ipairs(db.queue) do
        if entry.queueKind == "direct_item" and entry.itemID == directEntry.itemID then
            entry.directQuantity = directEntry.directQuantity
            entry.itemName = directEntry.itemName
            state.searchCache[entry.itemID] = nil
            DebugPrint("set-item-target item=" .. tostring(entry.itemID) .. " target=" .. tostring(entry.directQuantity))
            state.ah.statusMessage = "Objectif " .. entry.directQuantity .. "x " .. entry.itemName
            ScheduleRefresh()
            return true
        end
    end

    table.insert(db.queue, directEntry)
    state.searchCache[directEntry.itemID] = nil
    DebugPrint("set-item-target item=" .. tostring(directEntry.itemID) .. " target=" .. tostring(directEntry.directQuantity))
    state.ah.statusMessage = "Objectif " .. directEntry.directQuantity .. "x " .. directEntry.itemName
    ScheduleRefresh()
    return true
end

function YayaQueueAPI.Reset()
    ResetQueue()
    return true
end

function YayaQueueAPI.Refresh()
    ScheduleRefresh()
    return true
end

function YayaQueueAPI.IsReady()
    return true
end

function YayaQueueAPI.HasPatronOrder(orderID)
    EnsureDB()
    orderID = tonumber(orderID) or 0
    if orderID <= 0 then
        return false
    end

    if WasPatronOrderCompletedRecently(orderID) then
        return true
    end

    for _, entry in ipairs(db.queue) do
        if entry.queueKind == "patron" and (tonumber(entry.orderID) or 0) == orderID then
            return true
        end
    end

    return false
end

SLASH_YAYAQUEUE1 = "/yayaqueue"
SLASH_YAYAQUEUE2 = "/yq"
SlashCmdList.YAYAQUEUE = function(message)
    local command = string.lower(strtrim(message or ""))
    if command == "reset" then
        ResetQueue()
        return
    end
    if command == "debug" then
        debugNextCraft = not debugNextCraft
        Print("Debug " .. (debugNextCraft and "active" or "inactif"))
        return
    end
    if command == "vendor on" or command == "vendor off" then
        EnsureDB()
        db.autoBuyVendor = command == "vendor on"
        Print("Achat automatique marchand " .. (db.autoBuyVendor and "active" or "inactif") .. ".")
        return
    end
    if command == "vendor" or command == "vendor status" then
        EnsureDB()
        Print("Achat automatique marchand " .. (db.autoBuyVendor and "active" or "inactif") .. ".")
        return
    end
    if command == "log clear" then
        ClearPersistentDebugLog()
        Print("Log vide")
        return
    end
    local logCount = command:match("^log%s+(%d+)$")
    if command == "log" or logCount then
        PrintPersistentDebugLog(logCount)
        return
    end

    local summary = BuildQueueSummary()
    Print(#summary.craftTasks .. " craft, " .. #summary.auctionTasks .. " HV, " .. #summary.vendorTasks .. " marchand")
    ScheduleRefresh()
end
