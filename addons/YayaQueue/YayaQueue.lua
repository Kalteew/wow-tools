local addonName = ...

local addon = CreateFrame("Frame")
local db

local MAX_QUEUE_QTY = 9999
local MAX_CRAFT_LINES = 8
local MAX_AH_LINES = 10
local MAX_VENDOR_BUTTONS = 3
local CRAFT_PANEL_EXPANDED_HEIGHT = 340
local CRAFT_PANEL_COLLAPSED_HEIGHT = 88
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
        qtyBox = nil,
        minusButton = nil,
        plusButton = nil,
        resetButton = nil,
        nextButton = nil,
        selectedText = nil,
        todoTitle = nil,
        lines = {},
        statusText = nil,
        vendorTitle = nil,
        vendorButtons = {},
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
}

local RefreshAll
local OnAuctionActionClick
local ClearPendingCraftEntries
local QueuePendingCraftEntry
local PopPendingCraftEntry
local GetCurrentProfessionID
local EnsureDB

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

local function NormalizeDirectItemEntry(rawEntry)
    local itemID = tonumber(rawEntry and rawEntry.itemID) or tonumber(rawEntry and rawEntry.directItemID) or 0
    if itemID <= 0 then
        return nil
    end

    local quantity = ClampQuantity(rawEntry.quantity or rawEntry.outputQty or rawEntry.craftQty or 1)
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

local function AddIncomingPurchase(itemID, quantity)
    if type(itemID) ~= "number" or itemID <= 0 then
        return
    end
    quantity = math.max(0, math.floor(tonumber(quantity) or 0))
    if quantity <= 0 then
        return
    end

    state.observedItemCounts[itemID] = GetImmediateOwnedCount(itemID)
    SetIncomingCount(itemID, (state.incomingItemCounts[itemID] or 0) + quantity)
end

local function FinalizePendingItemPurchase()
    if not state.ah.pendingItem then
        return
    end

    AddIncomingPurchase(state.ah.pendingItem.itemID, state.ah.pendingItem.quantity)
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

local function GetQuantityInput()
    local text = state.craft.qtyBox and state.craft.qtyBox:GetText() or "1"
    local quantity = ClampQuantity(text)
    if state.craft.qtyBox then
        state.craft.qtyBox:SetText(tostring(quantity))
    end
    return quantity
end

local function SetQuantityInput(quantity)
    quantity = ClampQuantity(quantity)
    if state.craft.qtyBox then
        state.craft.qtyBox:SetText(tostring(quantity))
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

local function BuildRecipeContext(recipeID, recipeInfo, schematic, transaction, subtractAllocated)
    if not recipeID or type(schematic) ~= "table" then
        return nil
    end

    local reagents = {}
    for slotIndex, slot in ipairs(schematic.reagentSlotSchematics or {}) do
        local isRequiredBasic = slot.required
            and slot.reagentType == Enum.CraftingReagentType.Basic
            and (slot.dataSlotType == Enum.TradeskillSlotDataType.Reagent
                or slot.dataSlotType == Enum.TradeskillSlotDataType.ModifiedReagent)
        local reagent = isRequiredBasic and slot.reagents and slot.reagents[1] or nil
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
        local isRequiredBasic = slot.required
            and slot.reagentType == Enum.CraftingReagentType.Basic
            and (slot.dataSlotType == Enum.TradeskillSlotDataType.Reagent
                or slot.dataSlotType == Enum.TradeskillSlotDataType.ModifiedReagent)
        local reagent = isRequiredBasic and slot.reagents and slot.reagents[1] or nil
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
    local reagentSignature = BuildReagentSignature(reagents)

    for _, entry in ipairs(db.queue) do
        if entry.recipeID == context.recipeID
            and NormalizeQueueMode(entry.mode) == mode
            and (entry.reagentSignature or "") == reagentSignature
            and (tonumber(entry.orderID) or 0) == (tonumber(context.orderID) or 0)
            and NormalizeApplyConcentration(entry.applyConcentration) == NormalizeApplyConcentration(context.applyConcentration)
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
        table.insert(lines, "Craft " .. task.remainingCount .. "x " .. task.name)
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

local function ApplyQueuedRecipeConfigNow()
    local pending = state.pendingQueuedRecipeConfig
    if not pending then
        return true
    end

    local _, recipeInfo, schematicForm, transaction = GetCurrentCraftingSchematicContext()
    if not (recipeInfo and schematicForm and transaction and recipeInfo.recipeID == pending.recipeID) then
        return false
    end

    if type(transaction.SetApplyConcentration) == "function" then
        pcall(transaction.SetApplyConcentration, transaction, pending.applyConcentration == true)
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
        if ApplyQueuedRecipeConfigNow() then
            ScheduleRefresh()
            return
        end

        state.pendingQueuedRecipeConfig.attempts = (state.pendingQueuedRecipeConfig.attempts or 0) + 1
        if state.pendingQueuedRecipeConfig.attempts < 20 then
            ScheduleApplyQueuedRecipeConfig(0.05)
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

        if currentProfessionID ~= entry.professionID or currentRecipeID ~= entry.recipeID then
            return {
                entry = entry,
                text = "Next: Open",
                enabled = entry.professionID and entry.recipeID and type(C_TradeSkillUI) == "table",
                action = "open_recipe",
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
            if currentOrderID == lockedOrderID
                and recipeInfo and recipeInfo.recipeID == entry.recipeID
                and transactionRecipeID == entry.recipeID then
                ClearNextActionLock("opened")
                nextActionLock = nil
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
    if not (currentOrder and currentOrder.orderID == entry.orderID) then
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

local function RunPatronNextAction()
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

        BeginCraftClickLock()
        local reagentInfo = transaction:CreateCraftingReagentInfoTbl()
        local applyConcentration = NormalizeApplyConcentration(stateInfo.entry.applyConcentration)
        local craftAmount = math.max(1, math.floor(tonumber(stateInfo.craftAmount) or 1))
        if recipeInfo and recipeInfo.isEnchantingRecipe and type(C_TradeSkillUI.CraftEnchant) == "function" then
            local vellumLocation = GetItemLocationFromItemID(38682)
            if not vellumLocation then
                state.ah.statusMessage = "Vellin manquant"
                EndCraftClickLock()
                ScheduleRefresh()
                return
            end
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
    while quantity > 0 do
        local buyQuantity = math.min(quantity, maxStack)
        BuyMerchantItem(index, buyQuantity)
        quantity = quantity - buyQuantity
    end
end

local function BuyVendorTask(itemID, quantity)
    local merchantIndex = state.merchantIndexByItemID[itemID]
    if not merchantIndex then
        state.ah.statusMessage = "Marchand incompatible"
        ScheduleRefresh()
        return
    end

    local _, _, _, stackSize, numAvailable = GetMerchantItemInfoCompat(merchantIndex)
    stackSize = math.max(1, tonumber(stackSize) or 1)

    local purchaseCount = math.max(1, math.ceil((tonumber(quantity) or 0) / stackSize))
    if type(numAvailable) == "number" and numAvailable >= 0 then
        purchaseCount = math.min(purchaseCount, numAvailable)
    end
    if purchaseCount <= 0 then
        state.ah.statusMessage = "Rupture de stock"
        ScheduleRefresh()
        return
    end

    local totalQuantity = purchaseCount * stackSize
    BuyMerchantQuantity(merchantIndex, totalQuantity)
    state.ah.statusMessage = "Achete " .. totalQuantity .. "x " .. GetItemName(itemID)
    ScheduleRefresh()
end

local function QueueRecipeContext(context)
    if not context then
        return nil
    end

    local quantity = GetQuantityInput()
    context.professionID = tonumber(context.professionID) or GetCurrentProfessionID()
    context.applyConcentration = NormalizeApplyConcentration(context.applyConcentration)
    context.mode = "crafts"
    AddRecipeToQueue(context, quantity)
    state.ah.statusMessage = "Ajoute " .. quantity .. "x " .. context.recipeName
    ScheduleRefresh()
    return quantity
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

    local buttonIndex = 1
    for _, task in ipairs(summary.vendorTasks) do
        if buttonIndex > MAX_VENDOR_BUTTONS then
            break
        end

        if state.merchantIndexByItemID[task.itemID] then
            local button = state.craft.vendorButtons[buttonIndex]
            if button then
                button.itemID = task.itemID
                button.quantity = task.missing
                button:SetText("Acheter " .. task.missing .. "x " .. task.name)
                button:Show()
                buttonIndex = buttonIndex + 1
            end
        end
    end

    if buttonIndex > 1 and state.craft.vendorTitle then
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
        state.craft.selectedText:SetText(context.recipeName .. " | +" .. GetQuantityInput() .. " craft(s)")
    else
        state.craft.selectedText:SetText("Quantite ajout: " .. GetQuantityInput() .. " craft(s)")
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
        else
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

local function EnsureOrderQueueButton(schematicForm)
    if not schematicForm then
        return nil
    end

    local button = schematicForm.yayaQueueAddButton
    if button then
        return button
    end

    button = CreateFrame("Button", nil, schematicForm, "UIPanelButtonTemplate")
    button:SetSize(110, 22)
    button:SetText("Ajouter YQ")
    button:SetFrameStrata("DIALOG")
    button:SetFrameLevel((schematicForm:GetFrameLevel() or 1) + 30)
    button.schematicForm = schematicForm
    button:SetScript("OnClick", function(self)
        local context = GetRecipeContextFromSchematicForm(self.schematicForm)
        local quantity = QueueRecipeContext(context)
        if not quantity then
            Print("Aucune recette de commande selectionnee.")
            return
        end

        Print("Ajoute " .. quantity .. "x " .. context.recipeName .. " a YayaQueue.")
    end)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Ajouter YayaQueue")
        GameTooltip:AddLine("Ajoute cette recette avec la quantite choisie dans la fenetre YayaQueue.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", GameTooltip_Hide)

    button:ClearAllPoints()
    if schematicForm.TrackRecipeCheckbox then
        button:SetPoint("LEFT", schematicForm.TrackRecipeCheckbox, "RIGHT", 12, 0)
    elseif schematicForm.AllocateBestQualityCheckbox then
        button:SetPoint("BOTTOMLEFT", schematicForm.AllocateBestQualityCheckbox, "TOPLEFT", 0, 8)
    else
        button:SetPoint("TOPRIGHT", schematicForm, "TOPRIGHT", -18, -18)
    end

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

    button = CreateFrame("Button", nil, schematicForm, "UIPanelButtonTemplate")
    button:SetSize(110, 22)
    button:SetText("Ajouter YQ")
    button:SetFrameStrata("DIALOG")
    button:SetFrameLevel((schematicForm:GetFrameLevel() or 1) + 30)
    button.schematicForm = schematicForm
    button:SetScript("OnClick", function(self)
        local context = GetRecipeContextFromSchematicForm(self.schematicForm)
        local quantity = QueueRecipeContext(context)
        if not quantity then
            Print("Aucune recette selectionnee.")
            return
        end

        Print("Ajoute " .. quantity .. "x " .. context.recipeName .. " a YayaQueue.")
    end)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Ajouter YayaQueue")
        GameTooltip:AddLine("Ajoute cette recette avec la quantite choisie dans la fenetre YayaQueue.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", GameTooltip_Hide)

    button:ClearAllPoints()
    if schematicForm.TrackRecipeCheckbox then
        button:SetPoint("LEFT", schematicForm.TrackRecipeCheckbox, "RIGHT", 12, 0)
    elseif schematicForm.AllocateBestQualityCheckbox then
        button:SetPoint("BOTTOMLEFT", schematicForm.AllocateBestQualityCheckbox, "TOPLEFT", 0, 8)
    else
        button:SetPoint("TOPRIGHT", schematicForm, "TOPRIGHT", -18, -18)
    end

    schematicForm.yayaQueueRecipeButton = button
    return button
end

local function UpdateCraftingQueueButton()
    local schematicForm = GetCraftingSchematicForm()
    if not schematicForm then
        return
    end

    local button = EnsureCraftingQueueButton(schematicForm)
    local isVisible = schematicForm:IsShown()
    button:SetShown(isVisible)
    if isVisible then
        button:SetEnabled(GetRecipeContextFromSchematicForm(schematicForm) ~= nil)
    end
end

local function UpdateOrderQueueButton()
    local schematicForm = GetOrderSchematicForm()
    if not schematicForm then
        return
    end

    local button = EnsureOrderQueueButton(schematicForm)
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
    button:SetFrameStrata("DIALOG")
    button:SetFrameLevel((orderForm:GetFrameLevel() or 1) + 30)
    button.orderForm = orderForm
    button:SetScript("OnClick", function(self)
        local context = GetRecipeContextFromCustomerOrdersForm(self.orderForm)
        local quantity = QueueRecipeContext(context)
        if not quantity then
            Print("Aucune recette de commande selectionnee.")
            return
        end

        Print("Ajoute " .. quantity .. "x " .. context.recipeName .. " a YayaQueue.")
    end)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Ajouter YayaQueue")
        GameTooltip:AddLine("Ajoute cette commande avec la quantite choisie dans la fenetre YayaQueue.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", GameTooltip_Hide)

    button:ClearAllPoints()
    if orderForm.ReagentContainer and orderForm.ReagentContainer.Reagents then
        button:SetPoint("TOPLEFT", orderForm.ReagentContainer.Reagents, "BOTTOMLEFT", 0, -12)
    else
        button:SetPoint("BOTTOMLEFT", orderForm, "BOTTOMLEFT", 18, 54)
    end

    orderForm.yayaQueueAddButton = button
    return button
end

local function UpdateCustomerOrderQueueButton()
    local orderForm = GetCustomerOrdersForm()
    if not orderForm then
        return
    end

    local button = EnsureCustomerOrderQueueButton(orderForm)
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

    local qtyBox = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    qtyBox:SetSize(36, 20)
    qtyBox:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 24, -12)
    qtyBox:SetAutoFocus(false)
    qtyBox:SetNumeric(true)
    qtyBox:SetMaxLetters(4)
    qtyBox:SetText("1")
    qtyBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        SetQuantityInput(GetQuantityInput())
    end)
    qtyBox:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        SetQuantityInput(GetQuantityInput())
    end)
    qtyBox:SetScript("OnTextChanged", function()
        ScheduleRefresh()
    end)

    local minusButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    minusButton:SetSize(20, 20)
    minusButton:SetPoint("RIGHT", qtyBox, "LEFT", -2, 0)
    minusButton:SetText("-")
    minusButton:SetScript("OnClick", function()
        SetQuantityInput(GetQuantityInput() - 1)
        ScheduleRefresh()
    end)

    local plusButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    plusButton:SetSize(20, 20)
    plusButton:SetPoint("LEFT", qtyBox, "RIGHT", 2, 0)
    plusButton:SetText("+")
    plusButton:SetScript("OnClick", function()
        SetQuantityInput(GetQuantityInput() + 1)
        ScheduleRefresh()
    end)

    local selectedText = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    selectedText:SetPoint("TOPLEFT", qtyBox, "BOTTOMLEFT", -22, -10)
    selectedText:SetPoint("RIGHT", panel, "RIGHT", -10, 0)
    selectedText:SetJustifyH("LEFT")
    selectedText:SetText("Quantite ajout: 1 craft(s)")

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
    for index = 1, MAX_VENDOR_BUTTONS do
        local button = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        button:SetSize(248, 20)
        if index == 1 then
            button:SetPoint("BOTTOMLEFT", 10, 84)
        else
            button:SetPoint("BOTTOMLEFT", vendorButtons[index - 1], "TOPLEFT", 0, 4)
        end
        button:SetScript("OnClick", function(self)
            BuyVendorTask(self.itemID, self.quantity)
        end)
        button:Hide()
        vendorButtons[index] = button
    end

    state.craft.panel = panel
    state.craft.qtyBox = qtyBox
    state.craft.minusButton = minusButton
    state.craft.plusButton = plusButton
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
    CaptureSearchCache(itemID)

    if state.ah.activeSearch and state.ah.activeSearch.itemID == itemID then
        local purpose = state.ah.activeSearch.purpose
        state.ah.activeSearch = nil
        if purpose == "scan" then
            ProcessNextQueuedSearch()
        else
            local summary = BuildQueueSummary()
            PruneSearchCache(summary)
            StartPurchaseFromCache(summary, itemID)
        end
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
        if arg1 ~= addonName then
            return
        end

        EnsureDB()
        addon:RegisterEvent("PLAYER_ENTERING_WORLD")
        addon:RegisterEvent("TRADE_SKILL_SHOW")
        addon:RegisterEvent("TRADE_SKILL_CLOSE")
        addon:RegisterEvent("TRADE_SKILL_ITEM_CRAFTED_RESULT")
        addon:RegisterEvent("SPELL_DATA_LOAD_RESULT")
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
        ScheduleRefresh()
        return
    end

    if event == "TRADE_SKILL_CLOSE" then
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

    if event == "TRADE_SKILL_ITEM_CRAFTED_RESULT" then
        EndCraftClickLock()
        local itemID = arg1 and arg1.itemID or nil
        local quantity = arg1 and arg1.quantity or nil
        local multicraft = arg1 and arg1.quantityMulticraft or nil
        DebugPrint("event=TRADE_SKILL_ITEM_CRAFTED_RESULT itemID=" .. tostring(itemID) .. " qty=" .. tostring(quantity) .. " multicraft=" .. tostring(multicraft) .. " pendingEntries=" .. tostring(#state.pendingCraftEntries) .. " pendingBatches=" .. tostring(#state.pendingCraftBatches))
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
        CacheMerchantItems()
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
            AddIncomingPurchase(state.ah.pendingCommodity.itemID, state.ah.pendingCommodity.quantity)
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
            state.ah.statusMessage = "Ajoute " .. entry.directQuantity .. "x " .. entry.itemName
            ScheduleRefresh()
            return true
        end
    end

    table.insert(db.queue, directEntry)
    state.ah.statusMessage = "Ajoute " .. directEntry.directQuantity .. "x " .. directEntry.itemName
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
