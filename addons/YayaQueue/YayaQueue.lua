local addonName = ...

local addon = CreateFrame("Frame")
local db

local CONFIG = {
    MAX_QUEUE_QTY = 9999,
    MAX_CRAFT_LINES = 4,
    MAX_AH_LINES = 10,
    CRAFT_PANEL_EXPANDED_HEIGHT = 260,
    CRAFT_PANEL_COLLAPSED_HEIGHT = 88,
    CRAFT_PANEL_LINE_HEIGHT = 16,
    FIRST_CRAFT_COST_LIMIT = 1000 * 10000,
    FIRST_CRAFT_EXCLUDED_ITEM_IDS = {
        [245345] = true, -- Fused Vitality
    },
    ALCHEMY_PROFESSION_IDS = {
        [3] = true, -- Enum.Profession.Alchemy
        [171] = true, -- Alchemy
        [2906] = true, -- Midnight Alchemy
    },
    ALCHEMY_BOUQUET_RECIPE_ID = 1230892,
    ALCHEMY_WONDROUS_SYNERGIST_RECIPE_ID = 1230856,
    ALCHEMY_BOUQUET_SHARED_COOLDOWN_KEY = "midnight-alchemy-material-transmutations",
    ALCHEMY_BOUQUET_SHARED_COOLDOWN_RECIPE_IDS = {
        [1230891] = true, -- Box of Rocks
        [1230892] = true, -- Bouquet of Herbs
        [1230893] = true, -- School of Gems
    },
    STABILIZED_DERIVATE_ITEM_ID = 242651,
    ENTROPIC_EXTRACT_RANK_1_ITEM_ID = 268954,
    RECYCLE_POTIONS_RECIPE_ID = 1233129,
    RECYCLE_POTIONS_ITEM_ID = 242637,
    OIL_OF_HEARTWOOD_ITEM_ID = 247811,
    RECYCLE_BATCH_SIZE = 5,
    RECYCLE_POTIONS_PER_CRAFT = 3,
    RECYCLE_ESTIMATED_DERIVATES_PER_CRAFT = 2,
    GOLD_STAR_ITEM_ID = 246450,
    GOLD_STAR_MERGE_CHAIN = {
        { inputItemID = 246447, outputItemID = 246448, recipeID = 1269450, inputQuantity = 5, name = "Artisan's Ledger" },
        { inputItemID = 246448, outputItemID = 246449, recipeID = 1269451, inputQuantity = 5, name = "Mentor's Helpful Handiwork" },
        { inputItemID = 246449, outputItemID = 246450, recipeID = 1269452, inputQuantity = 5, name = "Artisan's Consortium Gold Star" },
    },
    MERCHANT_AUTO_BUY_MAX_RETRIES = 10,
    MERCHANT_AUTO_BUY_INITIAL_DELAY = 0.02,
    MERCHANT_AUTO_BUY_RETRY_DELAY = 0.08,
    MERCHANT_AUTO_BUY_VERIFY_DELAY = 0.08,
    TSM_MACRO_NAME = "TSMMacro",
    TSM_BUY_BUTTON = "TSMShoppingBuyoutBtn",
    TSM_CRAFT_BUTTON = "TSMCraftingBtn",
    YQ_TSM_BUY_BUTTON = "YQTSMBuy",
    YQ_TSM_CRAFT_BUTTON = "YQTSMNext",
    CONCENTRATION_PHIAL_ITEM_IDS = {
        [1] = 241313, -- Flasque d'inventivité haranir R1
        [2] = 241312, -- Flasque d'inventivité haranir R2
    },
    CONCENTRATION_PHIAL_BUFF_SPELL_ID = 1239755,
    CONCENTRATION_PHIAL_DEFAULT_PURCHASE = 10,
    AUCTION_HIGH_PRICE_CONFIRM_MULTIPLIER = 1.5,
    AUCTION_HIGH_PRICE_CONFIRM_DIALOG = "YQ_HIGH_PRICE_CONFIRM",
    SHATTER_ESSENCE_SPELL_ID = 1235731,
    SHATTER_ESSENCE_BUFF_SPELL_ID = 1235733,
    SHATTER_MOTE_ITEM_IDS = {
        236949, -- Mote of Light
        236950, -- Mote of Primal Energy
        236951, -- Mote of Wild Magic
        236952, -- Mote of Pure Void
    },
    CONCENTRATION_REFUND_RETRY_DELAY = 0.25,
    CONCENTRATION_REFUND_MAX_RETRIES = 12,
    debugNextCraft = false,
    DEBUG_LOG_LIMIT = 400,
    COMMODITY_SORT = { sortOrder = 0, reverseSort = false },
    ITEM_SORTS = { { sortOrder = 4, reverseSort = false } },
    KNOWN_VENDOR_ITEMS = {
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
    [247811] = true, -- Oil of Heartwood
    },
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
        qualityCache = nil,
        qualitySelectionCache = nil,
        qualityPriceCache = {},
        qualityPriceRevision = 0,
        qualityStockCache = {},
        qualitySolve = nil,
        qualitySolveGeneration = 0,
        qualityPreviewStates = {},
        qualityPreviewPending = {},
        qualityPreviewSolve = nil,
        qualityPreviewQueue = {},
        qualityPreviewGeneration = 0,
        qualityPreferences = {
            quality = nil,
            useConcentration = false,
            useFinishing = true,
            useGoldStar = false,
        },
    },
    craftGear = {
        byProfession = {},
        recipeRoles = {},
        scanQueued = false,
        transientRetryCount = 0,
        generation = 0,
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
        highPriceConfirmation = nil,
        soundCheckbox = nil,
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
    itemLoadRetryAt = {},
    incomingItemCounts = {},
    observedItemCounts = {},
    ingenuityBuffActive = false,
    ingenuityBuffInitialized = false,
    professionsHooksInitialized = false,
    craftApiHooksInitialized = false,
    orderApiHooksInitialized = false,
    refreshQueued = false,
    refreshDeferredByCombat = false,
    pendingCraftBatches = {},
    pendingCraftEntries = {},
    pendingWorkOrderSubmit = {},
    pendingWorkOrderSubmitLockSeconds = 1.0,
    pendingPatronAction = nil,
    lastClaimedPatronOrderID = 0,
    craftClickLockUntil = 0,
    craftClickLockSeconds = 2.0,
    nextActionLock = nil,
    recentCompletedPatronOrders = {},
    recentCompletedPatronOrderTTL = 30.0,
    firstCraftScanRunning = false,
    firstCraftAvailability = {},
    pendingIngenuityPhial = nil,
    armedShatter = nil,
    pendingShatter = nil,
    armedMerge = nil,
    pendingMerge = nil,
    armedCraftTool = nil,
    pendingCraftTool = nil,
    concentrationPhialSessionQueued = false,
    armedIngenuityPhial = nil,
    autoFavoriteConcentration = {
        queuedByProfession = {},
        pending = nil,
        timerQueued = false,
        tracker = nil,
    },
    alchemyAutoQueue = {
        pendingProfessionID = nil,
        attempts = 0,
        timerQueued = false,
    },
    optionsPanel = nil,
    optionsCategory = nil,
}

state.addonTable = select(2, ...)
state.auctionPrices = state.addonTable and state.addonTable.AuctionPrices

local YQQuality = {}

function YQQuality.RegisterCentralPricing()
    local api = _G.YayaCraftedPriceAPI
    if api and type(api.SetAuctionProvider) == "function" then
        api.SetAuctionProvider(function(itemID, kind)
            return state.auctionPrices and state.auctionPrices.GetQuote(itemID, kind) or nil
        end)
    end
end

YQQuality.RegisterCentralPricing()

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
    state.EnsureDB()
    db.debugLog = db.debugLog or {}

    local timestamp = date and date("%H:%M:%S") or tostring(math.floor(GetTime and GetTime() or 0))
    db.debugLog[#db.debugLog + 1] = ("[%s] %s%s"):format(timestamp, prefix or "", tostring(message or ""))
    local overflow = #db.debugLog - CONFIG.DEBUG_LOG_LIMIT
    if overflow > 0 then
        for _ = 1, overflow do
            table.remove(db.debugLog, 1)
        end
    end
end

local function PrintPersistentDebugLog(limit)
    state.EnsureDB()
    local lines = db.debugLog or {}
    limit = math.max(1, math.floor(tonumber(limit) or 20))
    local firstIndex = math.max(1, #lines - limit + 1)
    for index = firstIndex, #lines do
        Print(lines[index])
    end
end

local function ClearPersistentDebugLog()
    state.EnsureDB()
    db.debugLog = {}
end

local function DebugPrint(message)
    if not CONFIG.debugNextCraft then
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
    elseif value > CONFIG.MAX_QUEUE_QTY then
        value = CONFIG.MAX_QUEUE_QTY
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

local function BuildCraftingReagentSignature(craftingReagents)
    local parts = {}
    for _, info in ipairs(NormalizeCraftingReagents(craftingReagents)) do
        parts[#parts + 1] = table.concat({
            tostring(info.dataSlotIndex),
            tostring(info.reagent and info.reagent.itemID or ""),
            tostring(info.reagent and info.reagent.currencyID or ""),
            tostring(info.quantity),
        }, ":")
    end
    table.sort(parts)
    return table.concat(parts, "|")
end

local function BuildSlotPlanSignature(slotAllocations, clearSlotIndices)
    local parts = {}
    for _, allocation in ipairs(NormalizeSlotAllocations(slotAllocations)) do
        parts[#parts + 1] = table.concat({
            "a",
            tostring(allocation.slotIndex),
            tostring(allocation.itemID or ""),
            tostring(allocation.currencyID or ""),
            tostring(allocation.quantity),
        }, ":")
    end
    for _, slotIndex in ipairs(NormalizeSlotIndices(clearSlotIndices)) do
        parts[#parts + 1] = "c:" .. tostring(slotIndex)
    end
    table.sort(parts)
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
        concentrationPhial = rawEntry.concentrationPhial == true,
        shatterMote = rawEntry.shatterMote == true,
        queueKind = rawEntry.queueKind == "direct_item" and "direct_item" or "direct_item",
    }
end

local function NormalizeQueueEntries()
    local normalized = {}
    local seenPatronOrderIDs = {}

    for _, rawEntry in ipairs(db.queue or {}) do
        if type(rawEntry) == "table" then
            local recipeID = tonumber(rawEntry.recipeID) or 0
            if recipeID > 0 then
                local outputPerCraft = math.max(1, tonumber(rawEntry.outputPerCraft) or 1)
                local reagents = NormalizeReagents(rawEntry.reagents)
                local salvageItemID = tonumber(rawEntry.salvageItemID) or 0
                local salvageItemQuantity = math.max(1, tonumber(rawEntry.salvageItemQuantity) or 1)
                local isRecycleRecipe = recipeID == CONFIG.RECYCLE_POTIONS_RECIPE_ID
                if isRecycleRecipe then
                    reagents = {
                        { itemID = CONFIG.ENTROPIC_EXTRACT_RANK_1_ITEM_ID, quantity = CONFIG.RECYCLE_POTIONS_PER_CRAFT },
                        { itemID = CONFIG.OIL_OF_HEARTWOOD_ITEM_ID, quantity = 2 },
                    }
                    salvageItemID = CONFIG.ENTROPIC_EXTRACT_RANK_1_ITEM_ID
                    salvageItemQuantity = CONFIG.RECYCLE_POTIONS_PER_CRAFT
                end
                if rawEntry.isSalvageRecipe == true and salvageItemID > 0 then
                    local hasSalvageReagent = false
                    for _, reagent in ipairs(reagents) do
                        if tonumber(reagent.itemID) == salvageItemID then
                            hasSalvageReagent = true
                            break
                        end
                    end
                    if not hasSalvageReagent then
                        reagents[#reagents + 1] = {
                            itemID = salvageItemID,
                            quantity = salvageItemQuantity,
                        }
                    end
                end
                local mode = rawEntry.mode == "crafts" and "crafts" or "output"
                local queueKind = isRecycleRecipe and "recycle"
                    or rawEntry.queueKind == "patron" and "patron"
                    or rawEntry.queueKind == "merge" and "merge"
                    or rawEntry.queueKind == "recycle" and "recycle"
                    or nil
                local orderID = tonumber(rawEntry.orderID) or nil
                local craftQty

                if mode == "crafts" then
                    craftQty = ClampQuantity(rawEntry.craftQty or rawEntry.outputQty or 1)
                else
                    local outputQty = ClampQuantity(rawEntry.outputQty or rawEntry.craftQty or 1)
                    craftQty = ClampQuantity(math.ceil(outputQty / outputPerCraft))
                end

                if queueKind == "patron" then
                    craftQty = 1
                end
                if queueKind ~= "patron" or (orderID and not seenPatronOrderIDs[orderID]) then
                    if queueKind == "patron" then
                        seenPatronOrderIDs[orderID] = true
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
                        concentrationCurrencyID = tonumber(rawEntry.concentrationCurrencyID) or nil,
                        concentrationPhialItemID = tonumber(rawEntry.concentrationPhialItemID) or nil,
                        orderID = orderID,
                        professionID = tonumber(rawEntry.professionID) or nil,
                        queueKind = queueKind,
                        mergeKey = type(rawEntry.mergeKey) == "string" and rawEntry.mergeKey or nil,
                        mergeInputItemID = tonumber(rawEntry.mergeInputItemID) or nil,
                        mergeOutputItemID = tonumber(rawEntry.mergeOutputItemID) or nil,
                        mergeInputQuantity = tonumber(rawEntry.mergeInputQuantity) or nil,
                        mergeDepth = tonumber(rawEntry.mergeDepth) or nil,
                        isRecraft = rawEntry.isRecraft == true,
                        isEnchantingRecipe = rawEntry.isEnchantingRecipe == true,
                        isSalvageRecipe = rawEntry.isSalvageRecipe == true or isRecycleRecipe,
                        salvageItemID = salvageItemID > 0 and salvageItemID or nil,
                        salvageItemQuantity = salvageItemQuantity,
                        salvageOutputItemID = tonumber(rawEntry.salvageOutputItemID) or nil,
                        salvageOutputPerCraft = math.max(0, tonumber(rawEntry.salvageOutputPerCraft) or 0),
                        applyConcentration = NormalizeApplyConcentration(rawEntry.applyConcentration),
                        pendingSubmit = rawEntry.pendingSubmit == true,
                        profitValue = tonumber(rawEntry.profitValue) or nil,
                        profitKnown = rawEntry.profitKnown == true,
                    }
                end
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

state.EnsureDB = function()
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
            point = "BOTTOMLEFT",
            relativePoint = "BOTTOMLEFT",
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
    if YayaQueueDB.auctionPriceWarningSoundEnabled == nil then
        YayaQueueDB.auctionPriceWarningSoundEnabled = true
    else
        YayaQueueDB.auctionPriceWarningSoundEnabled = YayaQueueDB.auctionPriceWarningSoundEnabled == true
    end
    if YayaQueueDB.concentrationPhialEnabled == nil then
        YayaQueueDB.concentrationPhialEnabled = true
    else
        YayaQueueDB.concentrationPhialEnabled = YayaQueueDB.concentrationPhialEnabled == true
    end
    if YayaQueueDB.autoQueueIngenuityRefund == nil then
        YayaQueueDB.autoQueueIngenuityRefund = true
    else
        YayaQueueDB.autoQueueIngenuityRefund = YayaQueueDB.autoQueueIngenuityRefund == true
    end
    if YayaQueueDB.resetQuantityOnRecipeChange == nil then
        YayaQueueDB.resetQuantityOnRecipeChange = false
    else
        YayaQueueDB.resetQuantityOnRecipeChange = YayaQueueDB.resetQuantityOnRecipeChange == true
    end
    if YayaQueueDB.qualityUseGoldStar == nil then
        YayaQueueDB.qualityUseGoldStar = false
    else
        YayaQueueDB.qualityUseGoldStar = YayaQueueDB.qualityUseGoldStar == true
    end
    local phialRank = tonumber(YayaQueueDB.concentrationPhialRank)
    YayaQueueDB.concentrationPhialRank = phialRank == 2 and 2 or 1
    local phialPurchaseQuantity = tonumber(YayaQueueDB.concentrationPhialPurchaseQuantity)
    YayaQueueDB.concentrationPhialPurchaseQuantity = phialPurchaseQuantity == 1
        and 1
        or CONFIG.CONCENTRATION_PHIAL_DEFAULT_PURCHASE
    db = YayaQueueDB
    state.craft.qualityPreferences.useGoldStar = db.qualityUseGoldStar
    for itemID in pairs(CONFIG.KNOWN_VENDOR_ITEMS) do
        db.vendorItems[itemID] = true
    end
    NormalizeQueueEntries()
end

YQQuality.FindShatterMoteDemand = function()
    state.EnsureDB()
    for _, entry in ipairs(db.queue) do
        if entry.queueKind == "direct_item" and entry.shatterMote == true then
            return entry
        end
    end
    return nil
end

YQQuality.RemoveShatterMoteDemand = function(itemID)
    state.EnsureDB()
    itemID = tonumber(itemID)
    local removed = false
    for index = #db.queue, 1, -1 do
        local entry = db.queue[index]
        if entry.queueKind == "direct_item"
            and entry.shatterMote == true
            and (not itemID or tonumber(entry.itemID) == itemID)
        then
            table.remove(db.queue, index)
            state.searchCache[entry.itemID] = nil
            removed = true
        end
    end
    if removed then
        state.InvalidateQualityPricing()
    end
    return removed
end

YQQuality.AddShatterMoteDemand = function(itemID)
    state.EnsureDB()
    itemID = tonumber(itemID) or 0
    if itemID <= 0 or YQQuality.FindShatterMoteDemand() then
        return false
    end

    local entry = NormalizeDirectItemEntry({
        itemID = itemID,
        itemName = GetItemName(itemID),
        directQuantity = 1,
        shatterMote = true,
        queueKind = "direct_item",
    })
    if not entry then
        return false
    end

    table.insert(db.queue, entry)
    state.searchCache[itemID] = nil
    state.InvalidateQualityPricing()
    DebugPrint("shatter-demand item=" .. tostring(itemID))
    return true
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
        state.RefreshAll()
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

WarmItemData = function(itemID, refreshCraftGear)
    if type(itemID) ~= "number" or itemID <= 0 then
        return false
    end
    local now = GetTime()
    local pending = state.itemLoadPending[itemID]
    if pending then
        pending.refreshCraftGear = pending.refreshCraftGear or refreshCraftGear == true
        return true
    end
    if not Item or type(Item.CreateFromItemID) ~= "function" then
        return false
    end

    local item = Item:CreateFromItemID(itemID)
    if not item or item:IsItemDataCached() then
        return false
    end
    if now < (state.itemLoadRetryAt[itemID] or 0) then
        return true
    end

    state.itemLoadPending[itemID] = {
        refreshCraftGear = refreshCraftGear == true,
    }
    item:ContinueOnItemLoad(function()
        local request = state.itemLoadPending[itemID]
        state.itemLoadPending[itemID] = nil
        local cached = type(item.IsItemDataCached) == "function" and item:IsItemDataCached() == true
        state.itemLoadRetryAt[itemID] = GetTime() + (cached and 0.5 or 5)
        if not cached then
            return
        end
        if request and request.refreshCraftGear and state.craftGear and state.craftGear.ScheduleScan then
            state.craftGear.ScheduleScan()
        else
            ScheduleRefresh()
        end
    end)
    return true
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

YQQuality.GetPreferredIngenuityPhial = function()
    state.EnsureDB()
    local rank = db.concentrationPhialRank == 2 and 2 or 1
    return rank, CONFIG.CONCENTRATION_PHIAL_ITEM_IDS[rank]
end

YQQuality.IsConcentrationPhialEnabled = function()
    return not db or db.concentrationPhialEnabled ~= false
end

YQQuality.IsIngenuityRefundAutoQueueEnabled = function()
    state.EnsureDB()
    return db.autoQueueIngenuityRefund ~= false
end

YQQuality.GetConcentrationPhialPurchaseQuantity = function()
    state.EnsureDB()
    return db.concentrationPhialPurchaseQuantity
end

YQQuality.GetIngenuityPhialCount = function(itemID, getter)
    itemID = tonumber(itemID) or 0
    if type(getter) ~= "function" then
        return 0
    end

    local count = getter(itemID)
    if itemID ~= CONFIG.CONCENTRATION_PHIAL_ITEM_IDS[1] and itemID ~= CONFIG.CONCENTRATION_PHIAL_ITEM_IDS[2] then
        return count
    end
    for rank = 1, 2 do
        local otherItemID = CONFIG.CONCENTRATION_PHIAL_ITEM_IDS[rank]
        if otherItemID ~= itemID then
            count = count + getter(otherItemID)
        end
    end
    return count
end

YQQuality.RefreshIngenuityBuffState = function(reason)
    local spellID = CONFIG.CONCENTRATION_PHIAL_BUFF_SPELL_ID
    local auraData
    if C_UnitAuras and type(C_UnitAuras.GetPlayerAuraBySpellID) == "function" then
        auraData = SafeCall(C_UnitAuras.GetPlayerAuraBySpellID, spellID)
    end

    local active = auraData ~= nil
    if not active
        and (not C_UnitAuras or type(C_UnitAuras.GetPlayerAuraBySpellID) ~= "function")
        and AuraUtil
        and type(AuraUtil.FindAuraBySpellID) == "function"
    then
        active = AuraUtil.FindAuraBySpellID(spellID, "player", "HELPFUL") ~= nil
    end

    local changed = state.ingenuityBuffInitialized ~= true
        or state.ingenuityBuffActive ~= active
    state.ingenuityBuffActive = active
    state.ingenuityBuffInitialized = true
    if changed then
        DebugPrint(
            "ingenuity-buff active=" .. tostring(active)
                .. " spellID=" .. tostring(spellID)
                .. " reason=" .. tostring(reason or "?")
        )
    end
    return active
end

YQQuality.IsIngenuityBuffActive = function()
    return state.ingenuityBuffActive == true
end

YQQuality.IsShatterBuffActive = function()
    local spellID = CONFIG.SHATTER_ESSENCE_BUFF_SPELL_ID
    if C_UnitAuras and type(C_UnitAuras.GetPlayerAuraBySpellID) == "function" then
        return C_UnitAuras.GetPlayerAuraBySpellID(spellID) ~= nil
    end

    if AuraUtil and type(AuraUtil.FindAuraBySpellID) == "function" then
        return AuraUtil.FindAuraBySpellID(spellID, "player", "HELPFUL") ~= nil
    end

    return false
end

YQQuality.IsShatterSpellKnown = function()
    local spellID = CONFIG.SHATTER_ESSENCE_SPELL_ID
    local known = false

    if C_TradeSkillUI and type(C_TradeSkillUI.GetRecipeInfo) == "function" then
        local recipeInfo = SafeCall(C_TradeSkillUI.GetRecipeInfo, spellID)
        if type(recipeInfo) == "table" and recipeInfo.learned ~= nil then
            known = recipeInfo.learned == true
        end
    end

    if type(IsPlayerSpell) == "function" then
        known = known or SafeCall(IsPlayerSpell, spellID) == true
    end

    if C_SpellBook and type(C_SpellBook.IsSpellInSpellBook) == "function"
        and Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player
    then
        known = known or SafeCall(
            C_SpellBook.IsSpellInSpellBook,
            spellID,
            Enum.SpellBookSpellBank.Player,
            false
        ) == true
    end

    return known
end

YQQuality.RemoveConcentrationPhialDemand = function(itemID, quantity)
    state.EnsureDB()
    itemID = tonumber(itemID) or 0
    quantity = math.max(0, math.floor(tonumber(quantity) or 0))
    if itemID <= 0 or quantity <= 0 then
        return
    end

    for index = #db.queue, 1, -1 do
        local entry = db.queue[index]
        if entry.queueKind == "direct_item" and tonumber(entry.itemID) == itemID then
            local remaining = math.max(0, math.floor(tonumber(entry.directQuantity) or 0) - quantity)
            if remaining > 0 then
                entry.directQuantity = remaining
            else
                table.remove(db.queue, index)
            end
            state.InvalidateQualityPricing()
            return
        end
    end
end

YQQuality.QueueConcentrationPhial = function(quantity, preferredItemID)
    state.EnsureDB()
    if not YQQuality.IsConcentrationPhialEnabled() or state.concentrationPhialSessionQueued then
        return
    end
    for _, queuedEntry in ipairs(db.queue) do
        if queuedEntry.queueKind == "direct_item" and queuedEntry.concentrationPhial == true then
            state.concentrationPhialSessionQueued = true
            return
        end
    end
    quantity = ClampQuantity(quantity)
    local _, itemID = YQQuality.GetPreferredIngenuityPhial()
    itemID = tonumber(preferredItemID) or itemID
    itemID = tonumber(itemID) or 0
    if itemID <= 0 then
        return
    end

    WarmItemData(itemID)
    for _, entry in ipairs(db.queue) do
        if entry.queueKind == "direct_item" and tonumber(entry.itemID) == itemID then
            entry.directQuantity = ClampQuantity((entry.directQuantity or 0) + quantity)
            entry.itemName = GetItemName(itemID)
            entry.concentrationPhial = true
            state.InvalidateQualityPricing()
            return
        end
    end

    table.insert(db.queue, NormalizeDirectItemEntry({
        itemID = itemID,
        itemName = GetItemName(itemID),
        directQuantity = quantity,
        concentrationPhial = true,
        queueKind = "direct_item",
    }))
    db.queue[#db.queue].concentrationPhial = true
    state.concentrationPhialSessionQueued = true
    state.InvalidateQualityPricing()
end

YQQuality.FindIngenuityPhialBagSlot = function(itemID)
    itemID = tonumber(itemID) or 0
    if itemID <= 0 then
        return nil
    end

    for bagID = 0, 4 do
        local slotCount = C_Container and type(C_Container.GetContainerNumSlots) == "function"
            and C_Container.GetContainerNumSlots(bagID)
            or type(GetContainerNumSlots) == "function" and GetContainerNumSlots(bagID)
            or 0
        for slotIndex = 1, slotCount do
            local info = C_Container and type(C_Container.GetContainerItemInfo) == "function"
                and C_Container.GetContainerItemInfo(bagID, slotIndex)
                or nil
            local slotItemID = info and info.itemID
            if not slotItemID and C_Container and type(C_Container.GetContainerItemID) == "function" then
                slotItemID = C_Container.GetContainerItemID(bagID, slotIndex)
            end
            if not slotItemID and type(GetContainerItemLink) == "function" and type(GetItemInfoInstant) == "function" then
                local link = GetContainerItemLink(bagID, slotIndex)
                slotItemID = link and GetItemInfoInstant(link) or nil
            end
            if tonumber(slotItemID) == itemID then
                return bagID, slotIndex
            end
        end
    end
end

YQQuality.GetAvailableIngenuityPhial = function(preferredItemID)
    local _, demandItemID = YQQuality.GetPreferredIngenuityPhial()
    demandItemID = tonumber(preferredItemID) or demandItemID
    local itemID = demandItemID
    local bagID, slotIndex = YQQuality.FindIngenuityPhialBagSlot(itemID)
    if not bagID then
        for rank = 1, 2 do
            local fallbackItemID = CONFIG.CONCENTRATION_PHIAL_ITEM_IDS[rank]
            if fallbackItemID ~= demandItemID then
                bagID, slotIndex = YQQuality.FindIngenuityPhialBagSlot(fallbackItemID)
                if bagID then
                    itemID = fallbackItemID
                    break
                end
            end
        end
    end
    if not bagID then
        return demandItemID, nil
    end
    return demandItemID, itemID, bagID, slotIndex
end

YQQuality.EnsureOptions = function()
    if state.optionsPanel then
        return
    end

    local panel = CreateFrame("Frame")
    panel.name = "YayaQueue"

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("YayaQueue")

    local description = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    description:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    description:SetText("Options pour les crafts avec concentration.")

    local usePhialCheckbox = CreateFrame("CheckButton", addonName .. "ConcentrationPhialEnabled", panel, "UICheckButtonTemplate")
    usePhialCheckbox:SetPoint("TOPLEFT", description, "BOTTOMLEFT", 0, -14)
    local usePhialLabel = usePhialCheckbox.Text or usePhialCheckbox.text
    if not usePhialLabel then
        usePhialLabel = usePhialCheckbox:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        usePhialLabel:SetPoint("LEFT", usePhialCheckbox, "RIGHT", 2, 1)
        usePhialCheckbox.Text = usePhialLabel
    end
    usePhialLabel:SetText("Utiliser automatiquement une phial avant les crafts concentration")
    usePhialCheckbox:SetScript("OnClick", function(self)
        state.EnsureDB()
        db.concentrationPhialEnabled = self:GetChecked() == true
        ScheduleRefresh()
    end)

    local checkbox = CreateFrame("CheckButton", addonName .. "ConcentrationPhialRank2", panel, "UICheckButtonTemplate")
    checkbox:SetPoint("TOPLEFT", usePhialCheckbox, "BOTTOMLEFT", 0, -6)
    local label = checkbox.Text or checkbox.text
    if not label then
        label = checkbox:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        label:SetPoint("LEFT", checkbox, "RIGHT", 2, 1)
        checkbox.Text = label
    end
    label:SetText("Préférer acheter la phial d’ingéniosité rang 2")
    checkbox:SetScript("OnClick", function(self)
        state.EnsureDB()
        db.concentrationPhialRank = self:GetChecked() and 2 or 1
        state.ah.statusMessage = self:GetChecked() and "Phial R2 preferee" or "Phial R1 preferee"
        ScheduleRefresh()
    end)

    local purchaseHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    purchaseHeader:SetPoint("TOPLEFT", checkbox, "BOTTOMLEFT", 4, -12)
    purchaseHeader:SetText("Quantité achetée chez le marchand")

    local purchaseByTen = CreateFrame("CheckButton", addonName .. "ConcentrationPhialPurchaseTen", panel, "UIRadioButtonTemplate")
    purchaseByTen:SetPoint("TOPLEFT", purchaseHeader, "BOTTOMLEFT", 0, -5)
    local purchaseByTenLabel = purchaseByTen.Text or purchaseByTen.text
    if not purchaseByTenLabel then
        purchaseByTenLabel = purchaseByTen:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        purchaseByTenLabel:SetPoint("LEFT", purchaseByTen, "RIGHT", 2, 1)
        purchaseByTen.Text = purchaseByTenLabel
    end
    purchaseByTenLabel:SetText("Par 10 (buffer)")

    local purchaseByOne = CreateFrame("CheckButton", addonName .. "ConcentrationPhialPurchaseOne", panel, "UIRadioButtonTemplate")
    purchaseByOne:SetPoint("TOPLEFT", purchaseByTen, "BOTTOMLEFT", 0, -4)
    local purchaseByOneLabel = purchaseByOne.Text or purchaseByOne.text
    if not purchaseByOneLabel then
        purchaseByOneLabel = purchaseByOne:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        purchaseByOneLabel:SetPoint("LEFT", purchaseByOne, "RIGHT", 2, 1)
        purchaseByOne.Text = purchaseByOneLabel
    end
    purchaseByOneLabel:SetText("Par 1 (au plus juste)")

    local function SetPhialPurchaseQuantity(quantity)
        state.EnsureDB()
        db.concentrationPhialPurchaseQuantity = quantity == 1 and 1 or CONFIG.CONCENTRATION_PHIAL_DEFAULT_PURCHASE
        purchaseByTen:SetChecked(db.concentrationPhialPurchaseQuantity == CONFIG.CONCENTRATION_PHIAL_DEFAULT_PURCHASE)
        purchaseByOne:SetChecked(db.concentrationPhialPurchaseQuantity == 1)
        ScheduleRefresh()
    end

    purchaseByTen:SetScript("OnClick", function()
        SetPhialPurchaseQuantity(CONFIG.CONCENTRATION_PHIAL_DEFAULT_PURCHASE)
    end)
    purchaseByOne:SetScript("OnClick", function()
        SetPhialPurchaseQuantity(1)
    end)

    local refundCheckbox = CreateFrame("CheckButton", addonName .. "AutoQueueIngenuityRefund", panel, "UICheckButtonTemplate")
    refundCheckbox:SetPoint("TOPLEFT", purchaseByOne, "BOTTOMLEFT", 0, -6)
    local refundLabel = refundCheckbox.Text or refundCheckbox.text
    if not refundLabel then
        refundLabel = refundCheckbox:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        refundLabel:SetPoint("LEFT", refundCheckbox, "RIGHT", 2, 1)
        refundCheckbox.Text = refundLabel
    end
    refundLabel:SetText("Réinjecter un craft après un remboursement d’ingéniosité")
    refundCheckbox:SetScript("OnClick", function(self)
        state.EnsureDB()
        db.autoQueueIngenuityRefund = self:GetChecked() == true
        if not db.autoQueueIngenuityRefund and state.autoFavoriteConcentration.tracker then
            state.autoFavoriteConcentration.tracker.awaitingCraft = false
            state.autoFavoriteConcentration.tracker.craftConfirmed = false
        end
        ScheduleRefresh()
    end)

    local resetQuantityCheckbox = CreateFrame("CheckButton", addonName .. "ResetQuantityOnRecipeChange", panel, "UICheckButtonTemplate")
    resetQuantityCheckbox:SetPoint("TOPLEFT", refundCheckbox, "BOTTOMLEFT", 0, -6)
    local resetQuantityLabel = resetQuantityCheckbox.Text or resetQuantityCheckbox.text
    if not resetQuantityLabel then
        resetQuantityLabel = resetQuantityCheckbox:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        resetQuantityLabel:SetPoint("LEFT", resetQuantityCheckbox, "RIGHT", 2, 1)
        resetQuantityCheckbox.Text = resetQuantityLabel
    end
    resetQuantityLabel:SetText("Réinitialiser la quantité lors d’un changement de recette")
    resetQuantityCheckbox:SetScript("OnClick", function(self)
        state.EnsureDB()
        db.resetQuantityOnRecipeChange = self:GetChecked() == true
    end)
    panel:SetScript("OnShow", function()
        state.EnsureDB()
        usePhialCheckbox:SetChecked(db.concentrationPhialEnabled ~= false)
        checkbox:SetChecked(db.concentrationPhialRank == 2)
        purchaseByTen:SetChecked(db.concentrationPhialPurchaseQuantity == CONFIG.CONCENTRATION_PHIAL_DEFAULT_PURCHASE)
        purchaseByOne:SetChecked(db.concentrationPhialPurchaseQuantity == 1)
        refundCheckbox:SetChecked(db.autoQueueIngenuityRefund ~= false)
        resetQuantityCheckbox:SetChecked(db.resetQuantityOnRecipeChange == true)
    end)

    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
        state.optionsCategory = Settings.RegisterCanvasLayoutCategory(panel, panel.name, panel.name)
        Settings.RegisterAddOnCategory(state.optionsCategory)
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
    end
    state.optionsPanel = panel
end

YQQuality.OpenOptions = function()
    YQQuality.EnsureOptions()
    if state.optionsCategory and type(Settings.OpenToCategory) == "function" then
        local categoryID = type(state.optionsCategory.GetID) == "function" and state.optionsCategory:GetID()
        if categoryID then
            Settings.OpenToCategory(categoryID)
            return
        end
    end
    if type(InterfaceOptionsFrame_OpenToCategory) == "function" and state.optionsPanel then
        InterfaceOptionsFrame_OpenToCategory(state.optionsPanel)
    end
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

    -- Include the character bank, reagent bank, and Warband bank in queue needs.
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
    YQQuality.HideHighPriceConfirmation()
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
    if not CONFIG.debugNextCraft or type(itemID) ~= "number" or itemID <= 0 then
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

YQQuality.GetShatterMotePrice = function(itemID)
    if type(YQQuality.GetFallbackItemPrice) == "function" then
        local quote = YQQuality.GetFallbackItemPrice(itemID)
        local price = tonumber(quote and quote.unitPrice)
        if price and price > 0 then
            return price
        end
    end

    if type(YQQuality.GetItemPriceQuote) == "function" then
        local quote = YQQuality.GetItemPriceQuote(itemID, 1)
        local price = tonumber(quote and quote.amount)
        if price and price > 0 then
            return price
        end
    end

    return nil
end

YQQuality.GetCheapestShatterMote = function()
    local cheapestItemID
    local cheapestPrice
    for _, itemID in ipairs(CONFIG.SHATTER_MOTE_ITEM_IDS) do
        local price = YQQuality.GetShatterMotePrice(itemID)
        if price and (not cheapestPrice or price < cheapestPrice) then
            cheapestItemID = itemID
            cheapestPrice = price
        elseif not cheapestItemID then
            cheapestItemID = itemID
        end
    end
    return cheapestItemID
end

YQQuality.GetAvailableShatterMote = function()
    local availableItemID
    local availablePrice
    for _, itemID in ipairs(CONFIG.SHATTER_MOTE_ITEM_IDS) do
        if GetTotalOwnedCount(itemID) > 0 then
            local price = YQQuality.GetShatterMotePrice(itemID)
            if not availableItemID
                or (price and (not availablePrice or price < availablePrice))
            then
                availableItemID = itemID
                availablePrice = price
            end
        end
    end
    return availableItemID
end

YQQuality.GetShatterMoteState = function()
    if not YQQuality.IsShatterSpellKnown() then
        return { active = true, known = false }
    end

    if YQQuality.IsShatterBuffActive() then
        return { active = true }
    end

    local availableItemID = YQQuality.GetAvailableShatterMote()
    if availableItemID then
        return {
            active = false,
            itemID = availableItemID,
        }
    end

    local demand = YQQuality.FindShatterMoteDemand()
    local demandItemID = tonumber(demand and demand.itemID) or YQQuality.GetCheapestShatterMote()
    return {
        active = false,
        demandItemID = demandItemID,
        mailboxCount = demandItemID and GetMailboxCount(demandItemID) or 0,
    }
end

YQQuality.ConfirmPendingShatter = function()
    local pending = state.pendingShatter
    if not pending then
        return
    end

    if YQQuality.IsShatterBuffActive() then
        YQQuality.RemoveShatterMoteDemand(pending.itemID)
        state.pendingShatter = nil
        ClearNextActionLock("shatter-confirmed")
        state.ah.statusMessage = "Shatter confirme"
        ScheduleRefresh()
        return
    end

    pending.attempts = (pending.attempts or 0) + 1
    if GetTime() < (pending.expiresAt or 0) and pending.attempts < 16 then
        C_Timer.After(0.25, YQQuality.ConfirmPendingShatter)
        return
    end

    state.pendingShatter = nil
    ClearNextActionLock("shatter-timeout")
    state.ah.statusMessage = "Shatter non confirme"
    ScheduleRefresh()
end

YQQuality.IsEnchantingRecipeInfo = function(recipeInfo, entry)
    return (type(recipeInfo) == "table" and recipeInfo.isEnchantingRecipe == true)
        or (type(entry) == "table" and entry.isEnchantingRecipe == true)
end

YQQuality.GetRecipeInfoForEntry = function(entry)
    if not entry or not entry.recipeID or type(C_TradeSkillUI) ~= "table"
        or type(C_TradeSkillUI.GetRecipeInfo) ~= "function"
    then
        return nil
    end
    return SafeCall(C_TradeSkillUI.GetRecipeInfo, entry.recipeID)
end

YQQuality.EnsureShatterMoteDemandForEntry = function(entry, recipeInfo)
    if not entry or entry.queueKind == "merge" or entry.queueKind == "direct_item" then
        return
    end

    recipeInfo = recipeInfo or YQQuality.GetRecipeInfoForEntry(entry)
    if not YQQuality.IsEnchantingRecipeInfo(recipeInfo, entry) then
        return
    end

    if not YQQuality.IsShatterSpellKnown() then
        if YQQuality.RemoveShatterMoteDemand() then
            ScheduleRefresh()
        end
        return
    end

    if YQQuality.IsShatterBuffActive() then
        YQQuality.RemoveShatterMoteDemand()
        return
    end

    local moteState = YQQuality.GetShatterMoteState()
    if moteState.itemID then
        YQQuality.RemoveShatterMoteDemand()
        return
    end

    if not YQQuality.FindShatterMoteDemand() and moteState.demandItemID then
        if YQQuality.AddShatterMoteDemand(moteState.demandItemID) then
            ScheduleRefresh()
        end
    end
end

function YQQuality.GetConcentrationPhialState(entry)
    if not (entry and entry.applyConcentration == true)
        or not YQQuality.IsConcentrationPhialEnabled()
        or YQQuality.IsIngenuityBuffActive()
    then
        return nil
    end

    local demandItemID = tonumber(entry.concentrationPhialItemID)
    local _, preferredItemID = YQQuality.GetPreferredIngenuityPhial()
    demandItemID = demandItemID and demandItemID > 0 and demandItemID or preferredItemID
    local _, actualItemID = YQQuality.GetAvailableIngenuityPhial(demandItemID)
    if actualItemID then
        return {
            demandItemID = demandItemID or actualItemID,
            itemID = actualItemID,
        }
    end

    return {
        demandItemID = demandItemID,
        mailboxCount = YQQuality.GetIngenuityPhialCount(demandItemID, GetMailboxCount),
    }
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
    return CONFIG.KNOWN_VENDOR_ITEMS[itemID] or state.merchantIndexByItemID[itemID] or (db and db.vendorItems and db.vendorItems[itemID]) or false
end

local function IsSoulboundReagent(itemID)
    itemID = tonumber(itemID) or 0
    if itemID <= 0 then
        return false
    end

    if type(_G.CraftSimAPI) == "table" and type(_G.CraftSimAPI.GetCraftSim) == "function" then
        local okAddon, craftSim = pcall(_G.CraftSimAPI.GetCraftSim, _G.CraftSimAPI)
        local itemUtil = okAddon and craftSim and craftSim.GUTIL or nil
        if itemUtil and type(itemUtil.isItemSoulbound) == "function" then
            local okBound, isSoulbound = pcall(itemUtil.isItemSoulbound, itemUtil, itemID)
            if okBound and isSoulbound == true then
                return true
            end
        end
    end

    local bindType = select(14, GetItemInfo(itemID))
    if bindType == nil then
        WarmItemData(itemID)
        return false
    end
    return bindType ~= 0 and bindType ~= 2 and bindType ~= 3
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

local function GetItemLocationFromItemID(itemID, includeBank)
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

    if includeBank then
        local bagIndex = Enum and Enum.BagIndex or {}
        local seenBagIDs = {}
        for _, bagID in ipairs(bagIDs) do
            seenBagIDs[bagID] = true
        end
        local function AddBagID(bagID)
            bagID = tonumber(bagID)
            if bagID and not seenBagIDs[bagID] then
                seenBagIDs[bagID] = true
                bagIDs[#bagIDs + 1] = bagID
            end
        end

        local function AddBankTabs(bankType, firstKey, lastKey)
            if bankType ~= nil and type(C_Bank) == "table"
                and type(C_Bank.FetchPurchasedBankTabIDs) == "function" then
                local purchased = SafeCall(C_Bank.FetchPurchasedBankTabIDs, bankType)
                if type(purchased) == "table" then
                    for _, bagID in pairs(purchased) do
                        AddBagID(bagID)
                    end
                    return
                end
            end

            local first = tonumber(bagIndex[firstKey])
            local last = tonumber(bagIndex[lastKey])
            if first and last then
                for bagID = first, last do
                    AddBagID(bagID)
                end
            end
        end

        local bankType = Enum and Enum.BankType
        AddBankTabs(bankType and bankType.Character, "CharacterBankTab_1", "CharacterBankTab_6")
        AddBankTabs(bankType and bankType.Account, "AccountBankTab_1", "AccountBankTab_5")
    end

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
        local itemID = tonumber(SafeCall(GetMerchantItemID, index))
        if itemID and itemID > 0 then
            return itemID
        end
    end
    local _, _, _, _, _, _, _, _, _, _, itemID = GetMerchantItemInfoCompat(index)
    return tonumber(itemID)
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

    if point.point == "BOTTOMLEFT" and point.relativePoint == "BOTTOMLEFT" then
        return
    end

    local left = frame:GetLeft()
    local bottom = frame:GetBottom()
    if not left or not bottom then
        return
    end

    local parentLeft = UIParent.GetLeft and UIParent:GetLeft() or 0
    local parentBottom = UIParent.GetBottom and UIParent:GetBottom() or 0
    left = left - parentLeft
    bottom = bottom - parentBottom
    frame:ClearAllPoints()
    frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left, bottom)
    db.panelPoint = {
        point = "BOTTOMLEFT",
        relativePoint = "BOTTOMLEFT",
        x = left,
        y = bottom,
    }
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

local function SetPanelHeightKeepingBottomLeft(frame, height)
    if not frame then
        return
    end

    local left = frame:GetLeft()
    local bottom = frame:GetBottom()
    local parentLeft = UIParent.GetLeft and UIParent:GetLeft() or 0
    local parentBottom = UIParent.GetBottom and UIParent:GetBottom() or 0
    frame:SetHeight(height)
    if not left or not bottom then
        return
    end

    frame:ClearAllPoints()
    frame:SetPoint(
        "BOTTOMLEFT",
        UIParent,
        "BOTTOMLEFT",
        left - parentLeft,
        bottom - parentBottom
    )
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
        craftingReagents = transaction and type(transaction.CreateCraftingReagentInfoTbl) == "function"
            and NormalizeCraftingReagents(SafeCall(transaction.CreateCraftingReagentInfoTbl, transaction))
            or {},
        applyConcentration = transaction and type(transaction.IsApplyingConcentration) == "function" and transaction:IsApplyingConcentration() or false,
    }
end

-- Queue entries created before direct Next did not persist a CraftingReagentInfo
-- payload. Rebuild only selectable slots; Blizzard still allocates basic slots.
local function GetDirectCraftingReagents(entry)
    local saved = NormalizeCraftingReagents(entry and entry.craftingReagents)
    if #saved > 0 or not entry or not entry.recipeID then
        return saved
    end

    local schematic = type(C_TradeSkillUI) == "table"
        and type(C_TradeSkillUI.GetRecipeSchematic) == "function"
        and SafeCall(C_TradeSkillUI.GetRecipeSchematic, entry.recipeID, false)
        or nil
    if type(schematic) ~= "table" then
        return saved
    end

    local remainingByItemID = {}
    for _, reagent in ipairs(entry.reagents or {}) do
        local itemID = tonumber(reagent and reagent.itemID) or 0
        if itemID > 0 then
            remainingByItemID[itemID] = (remainingByItemID[itemID] or 0) + math.max(0, tonumber(reagent.quantity) or 0)
        end
    end

    for _, slot in ipairs(schematic.reagentSlotSchematics or {}) do
        if IsRequiredSelectableReagentSlot(slot) then
            local needed = math.max(0, tonumber(slot.quantityRequired) or 0)
            for _, reagent in ipairs(slot.reagents or {}) do
                local itemID = tonumber(reagent and reagent.itemID) or 0
                local available = remainingByItemID[itemID] or 0
                local quantity = math.min(needed, available)
                if itemID > 0 and quantity > 0 then
                    saved[#saved + 1] = {
                        dataSlotIndex = tonumber(slot.dataSlotIndex),
                        reagent = { itemID = itemID },
                        quantity = quantity,
                    }
                    remainingByItemID[itemID] = available - quantity
                    needed = needed - quantity
                end
                if needed <= 0 then
                    break
                end
            end
        end
    end

    saved = NormalizeCraftingReagents(saved)
    entry.craftingReagents = saved
    return saved
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
    state.EnsureDB()
    wipe(db.queue)
    state.InvalidateQualityPricing()
    state.concentrationPhialSessionQueued = false
    state.armedIngenuityPhial = nil
    state.armedShatter = nil
    state.pendingShatter = nil
    state.armedMerge = nil
    state.pendingMerge = nil
    state.armedCraftTool = nil
    state.pendingCraftTool = nil
    state.pendingPatronAction = nil
    if state.nextActionLock
        and (state.nextActionLock.action == "equip_tool" or state.nextActionLock.action == "shatter")
    then
        ClearNextActionLock("queue-reset")
    end
    wipe(state.searchCache)
    YQQuality.HideHighPriceConfirmation()
    if state.ah.pendingCommodity and type(C_AuctionHouse.CancelCommoditiesPurchase) == "function" then
        pcall(C_AuctionHouse.CancelCommoditiesPurchase)
    end
    state.ah.searchQueue = nil
    state.ah.activeSearch = nil
    state.ah.waitingSearch = nil
    state.ah.pendingCommodity = nil
    state.ah.pendingItem = nil
    state.ah.statusMessage = "Queue reset"
    ScheduleRefresh()
end

local function AddRecipeToQueue(context, quantity)
    state.EnsureDB()
    quantity = ClampQuantity(quantity)
    local mode = NormalizeQueueMode(context and context.mode)
    local queueKind = context and context.queueKind == "patron" and "patron"
        or context and context.queueKind == "merge" and "merge"
        or context and context.queueKind == "recycle" and "recycle"
        or nil
    local reagents = NormalizeReagents(context and context.reagents)
    local craftingReagents = NormalizeCraftingReagents(context and context.craftingReagents)
    local slotAllocations = NormalizeSlotAllocations(context and context.slotAllocations)
    local clearSlotIndices = NormalizeSlotIndices(context and context.clearSlotIndices)
    local reagentSignature = BuildReagentSignature(reagents)
    local craftingReagentSignature = BuildCraftingReagentSignature(craftingReagents)
    local slotPlanSignature = BuildSlotPlanSignature(slotAllocations, clearSlotIndices)
    local concentrationPhialItemID
    if NormalizeApplyConcentration(context.applyConcentration) then
        local _, preferredItemID = YQQuality.GetPreferredIngenuityPhial()
        concentrationPhialItemID = preferredItemID
    end

    for _, entry in ipairs(db.queue) do
        if entry.recipeID == context.recipeID
            and NormalizeQueueMode(entry.mode) == mode
            and entry.queueKind == queueKind
            and (queueKind ~= "merge" or entry.mergeKey == context.mergeKey)
            and (entry.reagentSignature or "") == reagentSignature
            and (tonumber(entry.orderID) or 0) == (tonumber(context.orderID) or 0)
            and NormalizeApplyConcentration(entry.applyConcentration) == NormalizeApplyConcentration(context.applyConcentration)
            and NormalizeTargetQuality(entry.targetQuality) == NormalizeTargetQuality(context.targetQuality)
            and (entry.targetQualitySimplified == true) == (context.targetQualitySimplified == true)
            and (tonumber(entry.concentrationPhialItemID) or 0) == (tonumber(concentrationPhialItemID) or 0)
            and BuildCraftingReagentSignature(entry.craftingReagents) == craftingReagentSignature
            and BuildSlotPlanSignature(entry.slotAllocations, entry.clearSlotIndices) == slotPlanSignature
            and (tonumber(entry.concentrationCost) or 0) == (tonumber(context.concentrationCost) or 0)
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
            entry.concentrationCurrencyID = tonumber(context.concentrationCurrencyID) or nil
            entry.concentrationPhialItemID = concentrationPhialItemID
            entry.orderID = tonumber(context.orderID) or nil
            entry.professionID = tonumber(context.professionID) or nil
            entry.queueKind = queueKind
            entry.mergeKey = type(context.mergeKey) == "string" and context.mergeKey or nil
            entry.mergeInputItemID = tonumber(context.mergeInputItemID) or nil
            entry.mergeOutputItemID = tonumber(context.mergeOutputItemID) or nil
            entry.mergeInputQuantity = tonumber(context.mergeInputQuantity) or nil
            entry.mergeDepth = tonumber(context.mergeDepth) or nil
            entry.isRecraft = context.isRecraft == true
            entry.isEnchantingRecipe = context.isEnchantingRecipe == true
            entry.isSalvageRecipe = context.isSalvageRecipe == true
            entry.salvageItemID = tonumber(context.salvageItemID) or nil
            entry.salvageItemQuantity = math.max(1, tonumber(context.salvageItemQuantity) or 1)
            entry.salvageOutputItemID = tonumber(context.salvageOutputItemID) or nil
            entry.salvageOutputPerCraft = math.max(0, tonumber(context.salvageOutputPerCraft) or 0)
            entry.applyConcentration = NormalizeApplyConcentration(context.applyConcentration)
            entry.pendingSubmit = context.pendingSubmit == true
            entry.profitValue = tonumber(context.profitValue) or nil
            entry.profitKnown = context.profitKnown == true
            if NormalizeApplyConcentration(context.applyConcentration) then
                YQQuality.QueueConcentrationPhial(1, concentrationPhialItemID)
            end
            state.InvalidateQualityPricing()
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
        concentrationCurrencyID = tonumber(context.concentrationCurrencyID) or nil,
        concentrationPhialItemID = concentrationPhialItemID,
        orderID = tonumber(context.orderID) or nil,
        professionID = tonumber(context.professionID) or nil,
        queueKind = queueKind,
        mergeKey = type(context.mergeKey) == "string" and context.mergeKey or nil,
        mergeInputItemID = tonumber(context.mergeInputItemID) or nil,
        mergeOutputItemID = tonumber(context.mergeOutputItemID) or nil,
        mergeInputQuantity = tonumber(context.mergeInputQuantity) or nil,
        mergeDepth = tonumber(context.mergeDepth) or nil,
        isRecraft = context.isRecraft == true,
        isEnchantingRecipe = context.isEnchantingRecipe == true,
        isSalvageRecipe = context.isSalvageRecipe == true,
        salvageItemID = tonumber(context.salvageItemID) or nil,
        salvageItemQuantity = math.max(1, tonumber(context.salvageItemQuantity) or 1),
        salvageOutputItemID = tonumber(context.salvageOutputItemID) or nil,
        salvageOutputPerCraft = math.max(0, tonumber(context.salvageOutputPerCraft) or 0),
        applyConcentration = NormalizeApplyConcentration(context.applyConcentration),
        pendingSubmit = context.pendingSubmit == true,
        profitValue = tonumber(context.profitValue) or nil,
        profitKnown = context.profitKnown == true,
    }
    table.insert(db.queue, entry)
    if NormalizeApplyConcentration(context.applyConcentration) then
        YQQuality.QueueConcentrationPhial(1, concentrationPhialItemID)
    end
    state.InvalidateQualityPricing()
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
    local ownedOutput = entry.outputItemID and GetTotalOwnedCount(entry.outputItemID) or 0
    local remainingOutput = entry.outputItemID and math.max(0, outputQty - ownedOutput) or outputQty
    local craftsRemaining = math.ceil(remainingOutput / outputPerCraft)
    return craftsRemaining, remainingOutput
end

local alchemyAuto = {}

alchemyAuto.IsAlchemyProfession = function(professionID)
    professionID = tonumber(professionID)
    if CONFIG.ALCHEMY_PROFESSION_IDS[professionID] then
        return true
    end

    local info = type(C_TradeSkillUI) == "table"
        and type(C_TradeSkillUI.GetChildProfessionInfo) == "function"
        and SafeCall(C_TradeSkillUI.GetChildProfessionInfo)
        or nil
    if info and (tonumber(info.profession) == 171 or tonumber(info.parentProfession) == 171) then
        return true
    end
    info = type(C_TradeSkillUI) == "table"
        and type(C_TradeSkillUI.GetBaseProfessionInfo) == "function"
        and SafeCall(C_TradeSkillUI.GetBaseProfessionInfo)
        or nil
    return info and tonumber(info.profession) == 171 or false
end

alchemyAuto.GetRecipeAvailableCharges = function(recipeID, recipeInfo)
    if type(C_TradeSkillUI) == "table" and type(C_TradeSkillUI.GetRecipeCooldown) == "function" then
        local ok, currentCooldown, isDayCooldown, currentCharges, maxCharges = pcall(
            C_TradeSkillUI.GetRecipeCooldown,
            recipeID
        )
        if ok then
            currentCooldown = tonumber(currentCooldown) or 0
            currentCharges = tonumber(currentCharges)
            maxCharges = tonumber(maxCharges)
            if maxCharges and maxCharges > 0 then
                return math.min(maxCharges, math.max(0, math.floor(currentCharges or 0)))
            end
            if isDayCooldown == true then
                return currentCooldown > 0 and 0 or 1
            end
        end
    end

    if type(C_Spell) == "table" and type(C_Spell.GetSpellCharges) == "function" then
        local ok, currentCharges, maxCharges = pcall(C_Spell.GetSpellCharges, recipeID)
        if ok and type(currentCharges) == "number" and type(maxCharges) == "number" and maxCharges > 0 then
            return math.max(0, math.floor(currentCharges))
        end
    end
    if type(GetSpellCharges) == "function" then
        local ok, currentCharges, maxCharges = pcall(GetSpellCharges, recipeID)
        if ok and type(currentCharges) == "number" and type(maxCharges) == "number" and maxCharges > 0 then
            return math.max(0, math.floor(currentCharges))
        end
    end
    local recipeCharges = recipeInfo and tonumber(recipeInfo.numAvailable)
    if recipeCharges ~= nil then
        return math.max(0, math.floor(recipeCharges))
    end
    return nil
end

alchemyAuto.GetQueuedRecipeCrafts = function(recipeID, queueKind)
    state.EnsureDB()
    local quantity = 0
    for _, entry in ipairs(db.queue) do
        if tonumber(entry.recipeID) == tonumber(recipeID)
            and (not queueKind or entry.queueKind == queueKind)
        then
            quantity = quantity + select(1, GetEntryCraftsRemaining(entry))
        end
    end
    return quantity
end

alchemyAuto.GetQueuedReagentDemand = function(itemID)
    state.EnsureDB()
    itemID = tonumber(itemID) or 0
    local quantity = 0
    for _, entry in ipairs(db.queue) do
        local craftsRemaining = select(1, GetEntryCraftsRemaining(entry))
        if craftsRemaining > 0 then
            for _, reagent in ipairs(entry.reagents or {}) do
                if tonumber(reagent.itemID) == itemID then
                    quantity = quantity + craftsRemaining * math.max(0, tonumber(reagent.quantity) or 0)
                end
            end
        end
    end
    return quantity
end

alchemyAuto.GetDerivateQueueProfessionID = function()
    state.EnsureDB()
    for _, entry in ipairs(db.queue) do
        for _, reagent in ipairs(entry.reagents or {}) do
            if tonumber(reagent.itemID) == CONFIG.STABILIZED_DERIVATE_ITEM_ID then
                return tonumber(entry.professionID)
            end
        end
    end
    return tonumber(state.GetCurrentProfessionID and state.GetCurrentProfessionID())
end

alchemyAuto.GetCooldownKey = function(recipeID, craftSim)
    recipeID = tonumber(recipeID) or recipeID
    if CONFIG.ALCHEMY_BOUQUET_SHARED_COOLDOWN_RECIPE_IDS[recipeID] then
        return "shared:" .. CONFIG.ALCHEMY_BOUQUET_SHARED_COOLDOWN_KEY
    end
    local sharedMap = craftSim and craftSim.CONST and craftSim.CONST.SHARED_PROFESSION_COOLDOWNS_RECIPE_ID_MAP
    local sharedCooldown = sharedMap and sharedMap[recipeID]
    if sharedCooldown then
        return "shared:" .. tostring(sharedCooldown)
    end
    return "recipe:" .. tostring(recipeID)
end

alchemyAuto.GetQueuedCooldownReservations = function(craftSim)
    state.EnsureDB()
    local reservations = {}
    for _, entry in ipairs(db.queue) do
        local recipeID = tonumber(entry.recipeID)
        if recipeID then
            local key = alchemyAuto.GetCooldownKey(recipeID, craftSim)
            reservations[key] = (reservations[key] or 0) + select(1, GetEntryCraftsRemaining(entry))
        end
    end
    return reservations
end

alchemyAuto.BuildCooldownContext = function(professionID, recipeID, recipeInfo)
    if type(C_TradeSkillUI) ~= "table"
        or type(C_TradeSkillUI.GetRecipeSchematic) ~= "function"
    then
        return nil
    end

    local schematic = SafeCall(C_TradeSkillUI.GetRecipeSchematic, recipeID, false, nil)
    local context = BuildRecipeContext(
        recipeID,
        recipeInfo,
        schematic,
        nil,
        false
    )
    if not context then
        return nil
    end
    context.professionID = professionID
    context.mode = "crafts"
    return context
end

alchemyAuto.BuildRecycleContext = function(professionID)
    return {
        recipeID = CONFIG.RECYCLE_POTIONS_RECIPE_ID,
        recipeName = GetItemName(CONFIG.RECYCLE_POTIONS_ITEM_ID),
        outputPerCraft = 1,
        mode = "crafts",
        reagents = {
            { itemID = CONFIG.ENTROPIC_EXTRACT_RANK_1_ITEM_ID, quantity = CONFIG.RECYCLE_POTIONS_PER_CRAFT },
            { itemID = CONFIG.OIL_OF_HEARTWOOD_ITEM_ID, quantity = 2 },
        },
        professionID = professionID,
        queueKind = "recycle",
        isSalvageRecipe = true,
        salvageItemID = CONFIG.ENTROPIC_EXTRACT_RANK_1_ITEM_ID,
        salvageItemQuantity = CONFIG.RECYCLE_POTIONS_PER_CRAFT,
        salvageOutputItemID = CONFIG.STABILIZED_DERIVATE_ITEM_ID,
        salvageOutputPerCraft = CONFIG.RECYCLE_ESTIMATED_DERIVATES_PER_CRAFT,
    }
end

alchemyAuto.EnsureRecycleForDerivateShortage = function(professionID)
    state.EnsureDB()
    local derivateDemand = alchemyAuto.GetQueuedReagentDemand(CONFIG.STABILIZED_DERIVATE_ITEM_ID)
    if derivateDemand <= 0 then
        return false
    end

    local queuedRecycles = alchemyAuto.GetQueuedRecipeCrafts(CONFIG.RECYCLE_POTIONS_RECIPE_ID, "recycle")
    if queuedRecycles > 0 then
        return false
    end

    local ownedDerivates = GetTotalOwnedCount(CONFIG.STABILIZED_DERIVATE_ITEM_ID)
    local shortage = math.max(0, derivateDemand - ownedDerivates)
    if shortage <= 0 then
        return false
    end

    local neededRecycles = math.ceil(shortage / CONFIG.RECYCLE_ESTIMATED_DERIVATES_PER_CRAFT)
    local recycleToQueue = math.ceil(neededRecycles / CONFIG.RECYCLE_BATCH_SIZE)
        * CONFIG.RECYCLE_BATCH_SIZE
    local recycleProfessionID = tonumber(professionID) or alchemyAuto.GetDerivateQueueProfessionID()
    local entry = AddRecipeToQueue(alchemyAuto.BuildRecycleContext(recycleProfessionID), recycleToQueue)
    if entry then
        DebugPrint(
            "derivate-shortage demand=" .. tostring(derivateDemand)
                .. " owned=" .. tostring(ownedDerivates)
                .. " recycle=" .. tostring(recycleToQueue)
        )
        return true
    end
    return false
end

alchemyAuto.QueueBouquetAndRecycling = function()
    state.EnsureDB()
    local professionID = state.GetCurrentProfessionID()
    if not alchemyAuto.IsAlchemyProfession(professionID) then
        return false
    end

    if type(C_TradeSkillUI) ~= "table"
        or type(C_TradeSkillUI.GetAllRecipeIDs) ~= "function"
        or type(C_TradeSkillUI.GetRecipeInfo) ~= "function"
    then
        return nil
    end

    local knownRecipeIDs = {}
    local recipeIDs = SafeCall(C_TradeSkillUI.GetAllRecipeIDs)
    if type(recipeIDs) ~= "table" or #recipeIDs == 0 then
        DebugPrint("alchemy-auto wait reason=recipe-data-not-ready")
        return nil
    end
    for _, recipeID in ipairs(recipeIDs) do
        knownRecipeIDs[tonumber(recipeID)] = true
        if type(SafeCall(C_TradeSkillUI.GetRecipeInfo, recipeID)) ~= "table" then
            DebugPrint("alchemy-auto wait reason=recipe-info recipe=" .. tostring(recipeID))
            return nil
        end
    end

    local okCraftSim, craftSim = pcall(
        _G.CraftSimAPI and _G.CraftSimAPI.GetCraftSim,
        _G.CraftSimAPI
    )
    craftSim = okCraftSim and type(craftSim) == "table" and craftSim or nil
    local cooldownReservations = alchemyAuto.GetQueuedCooldownReservations(craftSim)
    local pendingRecipes = {}
    for _, recipeID in ipairs({
        CONFIG.ALCHEMY_BOUQUET_RECIPE_ID,
        CONFIG.ALCHEMY_WONDROUS_SYNERGIST_RECIPE_ID,
    }) do
        if knownRecipeIDs[recipeID] then
            local recipeInfo = SafeCall(C_TradeSkillUI.GetRecipeInfo, recipeID)
            if type(recipeInfo) ~= "table" then
                return nil
            end
            if recipeInfo.learned ~= false then
                local availableCharges = alchemyAuto.GetRecipeAvailableCharges(recipeID, recipeInfo)
                if availableCharges == nil then
                    DebugPrint("alchemy-auto wait reason=cooldown recipe=" .. tostring(recipeID))
                    return nil
                end

                DebugPrint("alchemy-auto recipe=" .. tostring(recipeID) .. " charges=" .. tostring(availableCharges))

                local cooldownKey = alchemyAuto.GetCooldownKey(recipeID, craftSim)
                local reservedCharges = cooldownReservations[cooldownKey] or 0
                local craftsToQueue = math.max(0, availableCharges - reservedCharges)
                if craftsToQueue > 0 then
                    local context = alchemyAuto.BuildCooldownContext(professionID, recipeID, recipeInfo)
                    if not context then
                        return nil
                    end
                    pendingRecipes[#pendingRecipes + 1] = {
                        context = context,
                        quantity = craftsToQueue,
                    }
                    cooldownReservations[cooldownKey] = reservedCharges + craftsToQueue
                end
            end
        end
    end

    for _, pendingRecipe in ipairs(pendingRecipes) do
        AddRecipeToQueue(pendingRecipe.context, pendingRecipe.quantity)
    end
    alchemyAuto.EnsureRecycleForDerivateShortage(professionID)
    return true
end

function YQQuality.ScheduleAutoQueueAlchemy(delay)
    local autoQueue = state.alchemyAutoQueue
    if autoQueue.timerQueued or autoQueue.pendingProfessionID == false then
        return
    end
    autoQueue.timerQueued = true
    C_Timer.After(delay or 0, function()
        autoQueue.timerQueued = false
        if autoQueue.pendingProfessionID == false then
            return
        end
        autoQueue.attempts = (autoQueue.attempts or 0) + 1
        local result = alchemyAuto.QueueBouquetAndRecycling()
        if result == nil and autoQueue.attempts < 30 then
            YQQuality.ScheduleAutoQueueAlchemy(0.1)
        else
            autoQueue.pendingProfessionID = false
        end
    end)
end

local function StartAlchemyAutoQueue()
    state.alchemyAutoQueue.pendingProfessionID = nil
    state.alchemyAutoQueue.attempts = 0
    YQQuality.ScheduleAutoQueueAlchemy(0)
end

local function GetEntryConcentrationInfo(entry)
    if not entry or entry.applyConcentration ~= true then
        return 0, nil
    end

    local storedCost = tonumber(entry.concentrationCost)
    local storedCurrencyID = tonumber(entry.concentrationCurrencyID)
    if storedCost and storedCost > 0 and storedCurrencyID and storedCurrencyID > 0 then
        return storedCost, storedCurrencyID
    end

    if type(C_TradeSkillUI) ~= "table"
        or type(C_TradeSkillUI.GetCraftingOperationInfo) ~= "function"
        or not entry.recipeID then
        return math.max(0, storedCost or 0), storedCurrencyID
    end

    local operationInfo = SafeCall(
        C_TradeSkillUI.GetCraftingOperationInfo,
        entry.recipeID,
        NormalizeCraftingReagents(entry.craftingReagents),
        nil,
        false
    )
    local resolvedCost = storedCost and storedCost > 0
        and storedCost
        or tonumber(operationInfo and operationInfo.concentrationCost)
        or 0
    return math.max(0, resolvedCost),
        storedCurrencyID or tonumber(operationInfo and operationInfo.concentrationCurrencyID)
end

local function GetQueuedConcentrationReservation(professionID, currencyID)
    state.EnsureDB()
    professionID = tonumber(professionID)
    currencyID = tonumber(currencyID)
    local reserved = 0
    for _, entry in ipairs(db.queue) do
        local entryProfessionID = tonumber(entry.professionID)
        local entryCost, entryCurrencyID = GetEntryConcentrationInfo(entry)
        local matchesProfession = professionID and entryProfessionID == professionID
        local matchesCurrency = currencyID and entryCurrencyID == currencyID
        local unscopedEntry = not entryProfessionID and not entryCurrencyID
        if (not professionID and not currencyID) or matchesProfession or matchesCurrency or unscopedEntry then
            reserved = reserved + GetEntryCraftsRemaining(entry) * entryCost
        end
    end
    return reserved
end

local function GetNextQueueEntry()
    state.EnsureDB()
    local currentProfessionID = state.GetCurrentProfessionID and state.GetCurrentProfessionID() or nil
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
            local entryIsRecycle = entry.queueKind == "recycle"
            local bestIsRecycle = bestEntry and bestEntry.queueKind == "recycle"
            local entryIsMerge = entry.queueKind == "merge"
            local bestIsMerge = bestEntry and bestEntry.queueKind == "merge"
            local entryGearRank = state.craftGear.GetEntrySortRank(entry)
            local bestGearRank = bestEntry and state.craftGear.GetEntrySortRank(bestEntry) or nil
            local entryProfitKnown = entry.profitKnown == true and type(entry.profitValue) == "number"
            local bestProfitKnown = bestEntry and bestEntry.profitKnown == true and type(bestEntry.profitValue) == "number"

            local shouldReplace = false
            if not bestEntry then
                shouldReplace = true
            elseif entryIsRecycle ~= bestIsRecycle then
                shouldReplace = entryIsRecycle
            elseif entryMatchesOpenProfession ~= bestMatchesOpenProfession then
                shouldReplace = entryMatchesOpenProfession
            elseif entryIsMerge ~= bestIsMerge then
                shouldReplace = entryIsMerge
            elseif entryIsMerge
                and (tonumber(entry.mergeDepth) or math.huge) ~= (tonumber(bestEntry.mergeDepth) or math.huge)
            then
                shouldReplace = (tonumber(entry.mergeDepth) or math.huge)
                    < (tonumber(bestEntry.mergeDepth) or math.huge)
            elseif entryGearRank ~= bestGearRank then
                shouldReplace = entryGearRank < bestGearRank
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
    state.EnsureDB()

    local currentProfessionID = state.GetCurrentProfessionID and state.GetCurrentProfessionID() or nil
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
                isRecycle = entry.queueKind == "recycle",
                gearRank = state.craftGear.GetEntrySortRank(entry),
                hasKnownProfit = entry.profitKnown == true and type(entry.profitValue) == "number",
            }
        end
    end

    table.sort(candidates, function(left, right)
        if left.isRecycle ~= right.isRecycle then
            return left.isRecycle
        end
        if left.matchesOpenProfession ~= right.matchesOpenProfession then
            return left.matchesOpenProfession
        end
        local leftIsMerge = left.entry.queueKind == "merge"
        local rightIsMerge = right.entry.queueKind == "merge"
        if leftIsMerge ~= rightIsMerge then
            return leftIsMerge
        end
        if leftIsMerge
            and (tonumber(left.entry.mergeDepth) or math.huge) ~= (tonumber(right.entry.mergeDepth) or math.huge)
        then
            return (tonumber(left.entry.mergeDepth) or math.huge)
                < (tonumber(right.entry.mergeDepth) or math.huge)
        end
        if left.gearRank ~= right.gearRank then
            return left.gearRank < right.gearRank
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
    local acquireTasks = {}

    if type(entry) ~= "table" then
        return mailboxTasks, vendorTasks, auctionTasks, acquireTasks
    end

    for _, reagent in ipairs(entry.reagents or {}) do
        local itemID = tonumber(reagent.itemID) or 0
        local quantity = math.max(0, tonumber(reagent.quantity) or 0)
        if itemID > 0 and quantity > 0 then
            local owned = GetTotalOwnedCount(itemID)
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
                elseif IsSoulboundReagent(itemID) then
                    acquireTasks[#acquireTasks + 1] = task
                else
                    auctionTasks[#auctionTasks + 1] = task
                end
            end
        end
    end

    SortTaskList(mailboxTasks)
    SortTaskList(vendorTasks)
    SortTaskList(auctionTasks)
    SortTaskList(acquireTasks)
    return mailboxTasks, vendorTasks, auctionTasks, acquireTasks
end

local function BuildQueueSummary()
    state.EnsureDB()
    alchemyAuto.EnsureRecycleForDerivateShortage()

    local summary = {
        craftTasks = {},
        mailboxTasks = {},
        auctionTasks = {},
        vendorTasks = {},
        acquireTasks = {},
    }
    local neededByItemID = {}
    local plannedOutputs = {}

    for _, entry in ipairs(db.queue) do
        if entry.queueKind == "direct_item"
            and not (entry.concentrationPhial == true and not YQQuality.IsConcentrationPhialEnabled())
            and not (entry.shatterMote == true and YQQuality.IsShatterBuffActive())
        then
            local itemID = tonumber(entry.itemID) or 0
            local quantity = ClampQuantity(entry.directQuantity or 1)
            if itemID > 0 and quantity > 0 then
                WarmItemData(itemID)
                if not neededByItemID[itemID] then
                    neededByItemID[itemID] = {
                        itemID = itemID,
                        name = entry.itemName or GetItemName(itemID),
                        needed = 0,
                        immediateNeeded = 0,
                        shatterMote = false,
                    }
                end
                neededByItemID[itemID].needed = neededByItemID[itemID].needed + quantity
                if entry.shatterMote == true then
                    neededByItemID[itemID].shatterMote = true
                    neededByItemID[itemID].immediateNeeded = (neededByItemID[itemID].immediateNeeded or 0) + quantity
                end
            end
        end
    end

    for _, candidate in ipairs(GetSortedActiveQueueEntries()) do
        local entry = candidate.entry
        local mode = NormalizeQueueMode(entry.mode)
        local craftsRemaining, remainingCount = candidate.craftsRemaining, candidate.remainingCount

        if craftsRemaining > 0 then
            if entry.queueKind == "merge" and entry.outputItemID then
                plannedOutputs[entry.outputItemID] = (plannedOutputs[entry.outputItemID] or 0)
                    + craftsRemaining * math.max(1, tonumber(entry.outputPerCraft) or 1)
            elseif entry.queueKind == "recycle" and entry.salvageOutputItemID then
                plannedOutputs[entry.salvageOutputItemID] = (plannedOutputs[entry.salvageOutputItemID] or 0)
                    + craftsRemaining * math.max(0, tonumber(entry.salvageOutputPerCraft) or 0)
            end
            table.insert(summary.craftTasks, {
                recipeID = entry.recipeID,
                name = entry.recipeName or ("Recette " .. tostring(entry.recipeID)),
                remainingCount = remainingCount,
                mode = mode,
                queueKind = entry.queueKind,
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
                            immediateNeeded = 0,
                            shatterMote = false,
                        }
                    end
                    neededByItemID[reagent.itemID].needed = neededByItemID[reagent.itemID].needed + (craftsRemaining * reagent.quantity)
                end
            end
        end
    end

    for itemID, task in pairs(neededByItemID) do
        task.name = GetItemName(itemID)
        task.owned = YQQuality.GetIngenuityPhialCount(
            itemID,
            (itemID == CONFIG.CONCENTRATION_PHIAL_ITEM_IDS[1]
                or itemID == CONFIG.CONCENTRATION_PHIAL_ITEM_IDS[2])
                and GetImmediateOwnedCount
                or GetTotalOwnedCount
        )
        task.mailbox = YQQuality.GetIngenuityPhialCount(itemID, GetMailboxCount)
        task.queuedOutput = math.max(0, tonumber(plannedOutputs[itemID]) or 0)
        DebugPrintReagentCount("queue-summary", itemID, task.needed, task.mailbox)
        task.missing = math.max(0, task.needed - task.owned - task.queuedOutput)
        if (tonumber(task.immediateNeeded) or 0) > 0 and task.shatterMote ~= true then
            local immediateOwned = GetImmediateOwnedCount(itemID)
            local immediateMissing = math.max(0, task.immediateNeeded - immediateOwned)
            task.missing = math.max(task.missing, immediateMissing)
        end
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
            if itemID == CONFIG.CONCENTRATION_PHIAL_ITEM_IDS[1]
                or itemID == CONFIG.CONCENTRATION_PHIAL_ITEM_IDS[2]
            then
                task.missing = math.max(task.missing, YQQuality.GetConcentrationPhialPurchaseQuantity())
            end
            if IsKnownVendorItem(itemID) then
                table.insert(summary.vendorTasks, task)
            elseif IsSoulboundReagent(itemID) then
                table.insert(summary.acquireTasks, task)
            else
                table.insert(summary.auctionTasks, task)
            end
        end
    end

    SortTaskList(summary.mailboxTasks)
    SortTaskList(summary.auctionTasks)
    SortTaskList(summary.vendorTasks)
    SortTaskList(summary.acquireTasks)
    return summary
end

local function BuildCraftLines(summary)
    local lines = {}

    for _, task in ipairs(summary.mailboxTasks) do
        table.insert(lines, "Mailbox " .. task.missing .. "x " .. task.name)
    end
    for _, task in ipairs(summary.acquireTasks) do
        table.insert(lines, "Acquérir " .. task.missing .. "x " .. task.name)
    end
    for _, task in ipairs(summary.auctionTasks) do
        table.insert(lines, "HV " .. task.missing .. "x " .. task.name)
    end
    for _, task in ipairs(summary.vendorTasks) do
        table.insert(lines, "Marchand " .. task.missing .. "x " .. task.name)
    end
    for _, task in ipairs(summary.craftTasks) do
        if task.queueKind == "recycle" then
            table.insert(lines, "Recycle " .. task.remainingCount .. "x " .. task.name)
        elseif task.queueKind == "merge" then
            table.insert(lines, "Fusion " .. task.remainingCount .. "x " .. task.name)
        else
            local qualityText = task.targetQuality and (
                " " .. YQQuality.GetQualityIcon(task.targetQuality, 16, task.targetQualitySimplified)
            ) or ""
            table.insert(lines, "Craft " .. task.remainingCount .. "x " .. task.name .. qualityText)
        end
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

    state.EnsureDB()

    for index, entry in ipairs(db.queue) do
        if entry.recipeID == recipeID then
            local recipeName = entry.recipeName
            if entry.queueKind == "patron" and entry.orderID then
                entry.pendingSubmit = true
                entry.craftQty = math.max(1, ClampQuantity(entry.craftQty or 1))
                state.InvalidateQualityPricing()
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
            state.InvalidateQualityPricing()
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
        state.InvalidateQualityPricing()
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

    state.InvalidateQualityPricing()
    return recipeName
end

local function ConsumeCraftEntry(entryData)
    if type(entryData) ~= "table" then
        return nil
    end

    state.EnsureDB()
    local isPatronEntry = entryData.queueKind == "patron"
    local expectedOrderID = tonumber(entryData.orderID) or 0

    for index, entry in ipairs(db.queue) do
        local sameOrder = expectedOrderID > 0 and (tonumber(entry.orderID) or 0) == expectedOrderID
        local sameRecipe = (tonumber(entry.recipeID) or 0) > 0 and (tonumber(entry.recipeID) or 0) == (tonumber(entryData.recipeID) or 0)
        local sameConcentration = NormalizeApplyConcentration(entry.applyConcentration) == NormalizeApplyConcentration(entryData.applyConcentration)
        local sameKind = entry.queueKind == entryData.queueKind
        local sameMerge = entry.queueKind == "merge"
            and type(entry.mergeKey) == "string"
            and entry.mergeKey == entryData.mergeKey

        if sameOrder or sameMerge or (not isPatronEntry and sameRecipe and sameConcentration and sameKind) then
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

    state.EnsureDB()

    for index, entry in ipairs(db.queue) do
        if entry.queueKind == "patron" and entry.orderID == orderID then
            local recipeName = entry.recipeName
            table.remove(db.queue, index)
            state.InvalidateQualityPricing()
            return recipeName
        end
    end

    return nil
end

state.GetCurrentProfessionID = function()
    local professionInfo
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

    local ordersPage = ProfessionsFrame and ProfessionsFrame.OrdersPage
    professionInfo = ordersPage and ordersPage.professionInfo
    if professionInfo and professionInfo.profession then
        return professionInfo.profession
    end

    return nil
end

state.GetPatronQueueEntry = function(orderID)
    orderID = tonumber(orderID) or 0
    if orderID <= 0 then
        return nil
    end
    state.EnsureDB()
    for _, entry in ipairs(db.queue) do
        if entry.queueKind == "patron" and tonumber(entry.orderID) == orderID then
            return entry
        end
    end
    return nil
end

state.FinalizePatronCompletion = function(orderID, source)
    orderID = tonumber(orderID) or 0
    local recipeName = ConsumePatronSubmit(orderID)
    if recipeName then
        MarkRecentCompletedPatronOrder(orderID)
        state.ah.statusMessage = "Commande terminee: " .. recipeName
    end
    local action = state.pendingPatronAction
    if action and action.orderID == orderID then
        state.pendingPatronAction = nil
    end
    if state.lastClaimedPatronOrderID == orderID then
        state.lastClaimedPatronOrderID = 0
    end
    local nextActionLock = GetNextActionLock()
    if nextActionLock and nextActionLock.orderID == orderID then
        ClearNextActionLock("patron-complete-" .. tostring(source or "confirmed"))
    end
    DebugPrint("fulfill-confirmed source=" .. tostring(source or "?") .. " order=" .. tostring(orderID) .. " matched=" .. tostring(recipeName))
    ScheduleRefresh()
    return recipeName
end

state.BeginPatronAction = function(phase, entry, timeoutSeconds)
    if not entry or not entry.orderID then
        return false
    end
    local action = {
        phase = phase,
        orderID = tonumber(entry.orderID) or 0,
        professionID = tonumber(entry.professionID) or 0,
        entry = entry,
    }
    if action.orderID <= 0 then
        return false
    end
    state.pendingPatronAction = action
    BeginNextActionLock(phase, action.orderID, timeoutSeconds)
    C_Timer.After((tonumber(timeoutSeconds) or 2.0) + 0.1, function()
        if state.pendingPatronAction == action and state.RefreshPatronOrder then
            state.RefreshPatronOrder(action.orderID, action.professionID, phase .. "-timeout")
        end
    end)
    return true
end

state.RefreshPatronOrder = function(orderID, professionID, reason)
    local action = state.pendingPatronAction
    if action and action.orderID == tonumber(orderID) and action.resyncing then
        return
    end
    local api = _G.YayaCraftingOrdersAPI
    if not api or type(api.RefreshPatronOrder) ~= "function" then
        if action and action.orderID == tonumber(orderID) then
            state.pendingPatronAction = nil
        end
        ClearNextActionLock("patron-resync-api-missing")
        state.ah.statusMessage = "Resynchronisation patron indisponible"
        ScheduleRefresh()
        return
    end
    if action and action.orderID == tonumber(orderID) then
        action.resyncing = true
    end
    local callOK = pcall(api.RefreshPatronOrder, orderID, professionID, function(success, context, message)
        local pending = state.pendingPatronAction
        if pending and pending.orderID == tonumber(orderID) then
            pending.resyncing = nil
        end
        if success and type(context) == "table" then
            local entry = state.GetPatronQueueEntry(orderID)
            if entry then
                entry.recipeID = tonumber(context.recipeID) or entry.recipeID
                entry.recipeName = context.recipeName or entry.recipeName
                entry.outputItemID = tonumber(context.outputItemID) or entry.outputItemID
                entry.outputPerCraft = math.max(1, tonumber(context.outputPerCraft) or entry.outputPerCraft or 1)
                entry.reagents = NormalizeReagents(context.reagents)
                entry.reagentSignature = BuildReagentSignature(entry.reagents)
                entry.craftingReagents = NormalizeCraftingReagents(context.craftingReagents)
                entry.professionID = tonumber(context.professionID) or entry.professionID
                entry.isEnchantingRecipe = context.isEnchantingRecipe == true
                entry.applyConcentration = NormalizeApplyConcentration(context.applyConcentration)
                entry.concentrationCost = tonumber(context.concentrationCost) or nil
                entry.concentrationCurrencyID = tonumber(context.concentrationCurrencyID) or nil
                entry.isRecraft = context.isRecraft == true
                entry.profitValue = tonumber(context.profitValue) or nil
                entry.profitKnown = context.profitKnown == true
            end
            if pending and pending.orderID == tonumber(orderID) then
                state.pendingPatronAction = nil
            end
            ClearNextActionLock("patron-resynced")
            state.ah.statusMessage = "Commande patron resynchronisee"
        elseif message == "order_absent" then
            if pending and pending.phase == "complete" then
                state.FinalizePatronCompletion(orderID, "resync")
                return
            end
            ConsumePatronSubmit(orderID)
            if pending and pending.orderID == tonumber(orderID) then
                state.pendingPatronAction = nil
            end
            ClearNextActionLock("patron-absent")
            state.ah.statusMessage = "Commande patron indisponible"
        else
            if pending and pending.orderID == tonumber(orderID) then
                state.pendingPatronAction = nil
            end
            ClearNextActionLock("patron-resync-failed")
            state.ah.statusMessage = type(message) == "string" and message or "Resynchronisation patron echouee"
        end
        DebugPrint("patron-resync order=" .. tostring(orderID) .. " reason=" .. tostring(reason or "?") .. " success=" .. tostring(success))
        ScheduleRefresh()
    end)
    if not callOK then
        if action and action.orderID == tonumber(orderID) then
            state.pendingPatronAction = nil
        end
        ClearNextActionLock("patron-resync-call-failed")
        state.ah.statusMessage = "Resynchronisation patron echouee"
        ScheduleRefresh()
    end
end

local function HandlePatronFulfill(orderID, source)
    orderID = tonumber(orderID) or 0
    if orderID <= 0 then
        return nil
    end
    local action = state.pendingPatronAction
    if not (action and action.orderID == orderID and action.phase == "complete") then
        local entry = state.GetPatronQueueEntry(orderID)
        if entry then
            state.BeginPatronAction("complete", entry, 3.0)
        end
    end
    DebugPrint("fulfill-hook source=" .. tostring(source or "?") .. " order=" .. tostring(orderID) .. " awaiting-removal")
    return orderID
end

local function GetPatronNextButtonState()
    local entry = GetNextQueueEntry()
    if not entry then
        return nil
    end

    local nextActionLock = GetNextActionLock()

    if entry.queueKind == "merge" then
        if nextActionLock or state.pendingMerge then
            return {
                entry = entry,
                text = "Next: attente",
                enabled = false,
            }
        end

        local inputItemID = tonumber(entry.mergeInputItemID)
        local inputQuantity = math.max(1, tonumber(entry.mergeInputQuantity) or 1)
        local immediateQuantity = inputItemID and GetImmediateOwnedCount(inputItemID) or 0
        if immediateQuantity < inputQuantity then
            local mailboxQuantity = inputItemID and GetMailboxCount(inputItemID) or 0
            return {
                entry = entry,
                text = mailboxQuantity > 0 and "Next: Mailbox" or "Next: sacs",
                enabled = mailboxQuantity > 0,
                action = mailboxQuantity > 0 and "mailbox" or nil,
            }
        end

        return {
            entry = entry,
            text = "Next: Fusion",
            enabled = true,
            action = "merge",
            mergeInputItemID = inputItemID,
            mergeOutputItemID = tonumber(entry.mergeOutputItemID) or tonumber(entry.outputItemID),
            mergeInputQuantity = inputQuantity,
        }
    end

    if entry.queueKind == "recycle" or entry.isSalvageRecipe == true then
        if nextActionLock then
            return {
                entry = entry,
                text = "Next: attente",
                enabled = false,
            }
        end

        local mailboxTasks, vendorTasks, auctionTasks, acquireTasks = GetEntryResourceState(entry)
        if #mailboxTasks > 0 then
            return {
                entry = entry,
                text = "Next: Mailbox",
                enabled = true,
                action = "mailbox",
            }
        end
        if #vendorTasks > 0 or #auctionTasks > 0 or #acquireTasks > 0 then
            return {
                entry = entry,
                text = "Next: materiaux",
                enabled = false,
            }
        end

        local currentProfessionID = state.GetCurrentProfessionID()
        if (entry.professionID and currentProfessionID and entry.professionID ~= currentProfessionID)
            or not IsProfessionPageVisible(ProfessionsFrame and ProfessionsFrame.CraftingPage)
        then
            return {
                entry = entry,
                text = "Next: ouvre le metier",
                enabled = false,
            }
        end

        local itemID = tonumber(entry.salvageItemID) or 0
        local itemQuantity = math.max(1, tonumber(entry.salvageItemQuantity) or 1)
        local craftsRemaining = select(1, GetEntryCraftsRemaining(entry))
        local craftAmount = math.min(craftsRemaining, math.floor(GetTotalOwnedCount(itemID) / itemQuantity))
        if craftAmount <= 0 then
            return {
                entry = entry,
                text = "Next: potions",
                enabled = false,
            }
        end

        return {
            entry = entry,
            text = craftAmount > 1 and ("Next: Recycle x" .. craftAmount) or "Next: Recycle",
            enabled = true,
            action = "craft_salvage",
            craftAmount = craftAmount,
            itemID = itemID,
        }
    end

    if entry.queueKind ~= "patron" then
        if nextActionLock then
            return {
                entry = entry,
                text = "Next: attente",
                enabled = false,
            }
        end
        local mailboxTasks, vendorTasks, auctionTasks, acquireTasks = GetEntryResourceState(entry)
        if #mailboxTasks > 0 then
            return {
                entry = entry,
                text = "Next: Mailbox",
                enabled = true,
                action = "mailbox",
            }
        end
        if #vendorTasks > 0 or #auctionTasks > 0 or #acquireTasks > 0 then
            return {
                entry = entry,
                text = "Next: materiaux",
                enabled = false,
            }
        end

        local phialState = YQQuality.GetConcentrationPhialState(entry)
        if phialState and not phialState.itemID then
            return {
                entry = entry,
                text = (phialState.mailboxCount or 0) > 0 and "Next: Mailbox" or "Next: materiaux",
                enabled = (phialState.mailboxCount or 0) > 0,
                action = (phialState.mailboxCount or 0) > 0 and "mailbox" or nil,
            }
        end

        local currentProfessionID = state.GetCurrentProfessionID()
        local craftingPageVisible = IsProfessionPageVisible(ProfessionsFrame and ProfessionsFrame.CraftingPage)

        if not craftingPageVisible or currentProfessionID ~= entry.professionID then
            return {
                entry = entry,
                text = "Next: bon metier",
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

        GetDirectCraftingReagents(entry)
        local hasCraftInfo = type(C_TradeSkillUI) == "table"
            and type(C_TradeSkillUI.CraftRecipe) == "function"
        local craftsRemaining = GetEntryCraftsRemaining(entry)
        local craftAmount = math.max(1, tonumber(craftsRemaining) or 1)
        if hasCraftInfo then
            local toolAction = state.craftGear.GetToolAction(entry, nil)
            if toolAction then
                return toolAction
            end
            local recipeInfo = YQQuality.GetRecipeInfoForEntry(entry)
            if YQQuality.IsEnchantingRecipeInfo(recipeInfo, entry) then
                YQQuality.EnsureShatterMoteDemandForEntry(entry, recipeInfo)
                local shatterState = YQQuality.GetShatterMoteState()
                if not shatterState.active then
                    if shatterState.itemID then
                        return {
                            entry = entry,
                            text = "Next: Shatter",
                            enabled = true,
                            action = "shatter",
                            itemID = shatterState.itemID,
                        }
                    end
                    return {
                        entry = entry,
                        text = (shatterState.mailboxCount or 0) > 0 and "Next: Mailbox" or "Next: mote",
                        enabled = (shatterState.mailboxCount or 0) > 0,
                        action = (shatterState.mailboxCount or 0) > 0 and "mailbox" or nil,
                    }
                end
            end
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

    local currentProfessionID = state.GetCurrentProfessionID()
    local professionOpen = ProfessionsFrame and ProfessionsFrame:IsShown()
    if not professionOpen or currentProfessionID ~= entry.professionID then
        return { entry = entry, text = "Next: bon metier", enabled = false }
    end
    if entry.isRecraft == true then
        return { entry = entry, text = "Next: recraft", enabled = false }
    end
    local pendingPatronAction = state.pendingPatronAction
    if pendingPatronAction and pendingPatronAction.orderID == tonumber(entry.orderID) then
        return { entry = entry, text = "Next: attente", enabled = false }
    end
    if nextActionLock then
        return { entry = entry, text = "Next: attente", enabled = false }
    end
    if type(C_CraftingOrders) ~= "table" or type(C_CraftingOrders.GetClaimedOrder) ~= "function" then
        return { entry = entry, text = "Next: patrons indisponibles", enabled = false }
    end
    if type(C_TradeSkillUI) == "table" and type(C_TradeSkillUI.IsNearProfessionSpellFocus) == "function"
        and not C_TradeSkillUI.IsNearProfessionSpellFocus(entry.professionID)
    then
        return { entry = entry, text = "Next: focus", enabled = false }
    end

    local claimedOrder = C_CraftingOrders.GetClaimedOrder()
    if claimedOrder and tonumber(claimedOrder.orderID) ~= tonumber(entry.orderID) then
        return { entry = entry, text = "Next: autre commande", enabled = false }
    end
    if not claimedOrder then
        return {
            entry = entry,
            text = "Next: Start",
            enabled = type(C_CraftingOrders.ClaimOrder) == "function",
            action = "claim",
        }
    end
    if claimedOrder.isFulfillable then
        state.lastClaimedPatronOrderID = tonumber(claimedOrder.orderID) or 0
        ClearPendingWorkOrderSubmit(entry.orderID)
        return {
            entry = entry,
            text = "Next: Claim",
            enabled = type(C_CraftingOrders.FulfillOrder) == "function",
            action = "complete",
        }
    end
    state.lastClaimedPatronOrderID = tonumber(claimedOrder.orderID) or 0
    if IsPendingWorkOrderSubmit(entry.orderID) or IsCraftClickLocked() then
        return { entry = entry, text = "Next: attente", enabled = false }
    end

    local mailboxTasks, vendorTasks, auctionTasks, acquireTasks = GetEntryResourceState(entry)
    if #mailboxTasks > 0 then
        return { entry = entry, text = "Next: Mailbox", enabled = true, action = "mailbox" }
    end
    if #vendorTasks > 0 or #auctionTasks > 0 or #acquireTasks > 0 then
        return { entry = entry, text = "Next: materiaux", enabled = false }
    end
    local phialState = YQQuality.GetConcentrationPhialState(entry)
    if phialState and not phialState.itemID then
        return {
            entry = entry,
            text = (phialState.mailboxCount or 0) > 0 and "Next: Mailbox" or "Next: materiaux",
            enabled = (phialState.mailboxCount or 0) > 0,
            action = (phialState.mailboxCount or 0) > 0 and "mailbox" or nil,
        }
    end
    GetDirectCraftingReagents(entry)
    local toolAction = state.craftGear.GetToolAction(entry, nil)
    if toolAction then
        return toolAction
    end
    local recipeInfo = YQQuality.GetRecipeInfoForEntry(entry)
    if YQQuality.IsEnchantingRecipeInfo(recipeInfo, entry) then
        YQQuality.EnsureShatterMoteDemandForEntry(entry, recipeInfo)
        local shatterState = YQQuality.GetShatterMoteState()
        if not shatterState.active then
            return {
                entry = entry,
                text = shatterState.itemID and "Next: Shatter" or "Next: mote",
                enabled = shatterState.itemID ~= nil,
                action = shatterState.itemID and "shatter" or nil,
                itemID = shatterState.itemID,
            }
        end
    end
    return {
        entry = entry,
        text = "Next: Craft",
        enabled = type(C_TradeSkillUI) == "table" and type(C_TradeSkillUI.CraftRecipe) == "function",
        action = "craft",
        recipeID = entry.recipeID,
    }
end

state.RunPatronNextAction = function()
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

    if stateInfo.action == "equip_tool" then
        state.ah.statusMessage = "Clique Next pour equiper l'outil"
        ScheduleRefresh()
        return
    end

    if stateInfo.action == "mailbox" then
        state.ah.statusMessage = "Recupere les items en boite aux lettres"
        ScheduleRefresh()
        return
    end

    if stateInfo.action == "claim" then
        if not state.BeginPatronAction("claim", stateInfo.entry, 2.0) then
            state.ah.statusMessage = "Commande patron invalide"
            ScheduleRefresh()
            return
        end
        local callOK = pcall(C_CraftingOrders.ClaimOrder, stateInfo.entry.orderID, stateInfo.entry.professionID)
        if not callOK then
            state.RefreshPatronOrder(stateInfo.entry.orderID, stateInfo.entry.professionID, "claim-call-failed")
            return
        end
        state.ah.statusMessage = "Action: Start"
        C_Timer.After(0, ScheduleRefresh)
        ScheduleRefresh()
        return
    end

    if stateInfo.action == "craft_salvage" then
        local itemID = tonumber(stateInfo.entry.salvageItemID) or 0
        local recipeID = tonumber(stateInfo.entry.recipeID) or 0
        local craftAmount = math.max(1, math.floor(tonumber(stateInfo.craftAmount) or 1))
        local itemLocation = GetItemLocationFromItemID(itemID, true)
        if not itemLocation then
            state.ah.statusMessage = "Potion Entropic Extract introuvable"
            ScheduleRefresh()
            return
        end
        if type(C_TradeSkillUI) ~= "table" or type(C_TradeSkillUI.CraftSalvage) ~= "function" then
            state.ah.statusMessage = "Recyclage indisponible"
            ScheduleRefresh()
            return
        end

        BeginNextActionLock("craft", 0, 30.0)
        BeginCraftClickLock()
        state.QueuePendingCraftEntry(stateInfo.entry, craftAmount)
        local callOK = pcall(
            C_TradeSkillUI.CraftSalvage,
            recipeID,
            craftAmount,
            itemLocation,
            nil,
            false
        )
        if not callOK then
            state.ClearPendingCraftEntries()
            ClearNextActionLock("recycle-call-failed")
            EndCraftClickLock()
            state.ah.statusMessage = "Recyclage echoue"
            ScheduleRefresh()
            return
        end
        state.ah.statusMessage = craftAmount > 1
            and ("Action: Recycle x" .. craftAmount)
            or "Action: Recycle"
        C_Timer.After(0, ScheduleRefresh)
        ScheduleRefresh()
        return
    end

    if stateInfo.action == "craft_normal" then
        local recipeInfo = YQQuality.GetRecipeInfoForEntry(stateInfo.entry)
        local reagentInfo = GetDirectCraftingReagents(stateInfo.entry)
        local applyConcentration = NormalizeApplyConcentration(stateInfo.entry.applyConcentration)
        local craftAmount = math.max(1, math.floor(tonumber(stateInfo.craftAmount) or 1))
        if applyConcentration and YQQuality.IsConcentrationPhialEnabled() then
            local phialID = tonumber(stateInfo.entry.concentrationPhialItemID)
            if not phialID or phialID <= 0 then
                local _, preferredItemID = YQQuality.GetPreferredIngenuityPhial()
                phialID = preferredItemID
            end
            if YQQuality.IsIngenuityBuffActive() then
                YQQuality.RemoveConcentrationPhialDemand(phialID, 1)
            else
                state.ah.statusMessage = "Clique Next: Phial"
                ScheduleRefresh()
                return
            end
        end

        local favoriteTracker = state.autoFavoriteConcentration.tracker
        if favoriteTracker
            and not favoriteTracker.requeued
            and favoriteTracker.recipeID == stateInfo.entry.recipeID
            and stateInfo.entry.applyConcentration == true
        then
            -- At craft time we only need the raw currency snapshot. Rebuilding
            -- the schematic here can race the Blizzard profession UI refresh.
            favoriteTracker.beforeConcentration = state.GetCurrentConcentrationAmount()
            favoriteTracker.awaitingCraft = favoriteTracker.beforeConcentration ~= nil
            favoriteTracker.craftConfirmed = false
            favoriteTracker.reservationConsumed = false
            favoriteTracker.refundCheckAttempts = 0
            favoriteTracker.refundCheckScheduled = false
            favoriteTracker.currencyEventAmount = nil
        end
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
            state.QueuePendingCraftEntry(stateInfo.entry, craftAmount)
            C_TradeSkillUI.CraftEnchant(stateInfo.entry.recipeID, craftAmount, reagentInfo, vellumLocation, applyConcentration)
        else
            state.QueuePendingCraftEntry(stateInfo.entry, craftAmount)
            C_TradeSkillUI.CraftRecipe(stateInfo.entry.recipeID, craftAmount, reagentInfo, nil, nil, applyConcentration)
        end
        state.ah.statusMessage = craftAmount > 1 and ("Action: Craft x" .. craftAmount) or "Action: Craft"
        C_Timer.After(0, ScheduleRefresh)
        ScheduleRefresh()
        return
    end

    if stateInfo.action == "craft" then
        local currentClaimedOrder = type(C_CraftingOrders) == "table"
            and type(C_CraftingOrders.GetClaimedOrder) == "function"
            and C_CraftingOrders.GetClaimedOrder()
            or nil
        if not (currentClaimedOrder and tonumber(currentClaimedOrder.orderID) == tonumber(stateInfo.entry.orderID)) then
            state.ah.statusMessage = "Order non pret"
            state.RefreshPatronOrder(stateInfo.entry.orderID, stateInfo.entry.professionID, "craft-order-mismatch")
            ScheduleRefresh()
            return
        end
        if IsPendingWorkOrderSubmit(stateInfo.entry.orderID) or IsCraftClickLocked() then
            ScheduleRefresh()
            return
        end
        local recipeID = stateInfo.recipeID or stateInfo.entry.recipeID
        local reagentInfo = GetDirectCraftingReagents(stateInfo.entry)
        local applyConcentration = NormalizeApplyConcentration(stateInfo.entry.applyConcentration)

        if applyConcentration and YQQuality.IsConcentrationPhialEnabled() then
            local phialID = tonumber(stateInfo.entry.concentrationPhialItemID)
            if not phialID or phialID <= 0 then
                local _, preferredItemID = YQQuality.GetPreferredIngenuityPhial()
                phialID = preferredItemID
            end
            if YQQuality.IsIngenuityBuffActive() then
                YQQuality.RemoveConcentrationPhialDemand(phialID, 1)
            else
                state.ah.statusMessage = "Clique Next: Phial"
                ScheduleRefresh()
                return
            end
        end

        if not state.BeginPatronAction("craft", stateInfo.entry, 8.0) then
            state.ah.statusMessage = "Commande patron invalide"
            ScheduleRefresh()
            return
        end
        MarkPendingWorkOrderSubmit(stateInfo.entry.orderID)
        BeginCraftClickLock()
        state.QueuePendingCraftEntry(stateInfo.entry)
        local callOK = pcall(
            C_TradeSkillUI.CraftRecipe,
            recipeID,
            1,
            reagentInfo,
            nil,
            stateInfo.entry.orderID,
            applyConcentration
        )
        if not callOK then
            ClearPendingWorkOrderSubmit(stateInfo.entry.orderID)
            state.ClearPendingCraftEntries()
            EndCraftClickLock()
            state.RefreshPatronOrder(stateInfo.entry.orderID, stateInfo.entry.professionID, "craft-call-failed")
            return
        end
        state.ah.statusMessage = "Action: Craft"
        C_Timer.After(0, ScheduleRefresh)
        ScheduleRefresh()
        return
    end

    if stateInfo.action == "complete" then
        if not state.BeginPatronAction("complete", stateInfo.entry, 3.0) then
            state.ah.statusMessage = "Commande patron invalide"
            ScheduleRefresh()
            return
        end
        BeginCraftClickLock()
        ClearPendingWorkOrderSubmit(stateInfo.entry.orderID)
        local callOK = pcall(C_CraftingOrders.FulfillOrder, stateInfo.entry.orderID, "", stateInfo.entry.professionID)
        if not callOK then
            EndCraftClickLock()
            state.RefreshPatronOrder(stateInfo.entry.orderID, stateInfo.entry.professionID, "fulfill-call-failed")
            return
        end
        state.ah.statusMessage = "Action: Claim"
        C_Timer.After(0, ScheduleRefresh)
        ScheduleRefresh()
        return
    end
end

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

    CreateTSMMacroBridgeButton(CONFIG.YQ_TSM_BUY_BUTTON, function()
        if IsYayaAuctionContextActive() then
            state.OnAuctionActionClick()
        else
            ClickExistingButton(CONFIG.TSM_BUY_BUTTON)
        end
    end)
    CreateTSMMacroBridgeButton(CONFIG.YQ_TSM_CRAFT_BUTTON, function()
        if IsYayaCraftContextActive() then
            state.RunPatronNextAction()
        else
            ClickExistingButton(CONFIG.TSM_CRAFT_BUTTON)
        end
    end)

    local macroName, macroIcon = GetMacroInfo(CONFIG.TSM_MACRO_NAME)
    if not macroName then
        return
    end

    local body = GetMacroBody(CONFIG.TSM_MACRO_NAME)
    if type(body) ~= "string" or body == "" then
        return
    end

    local updatedBody = body
        :gsub("/click " .. CONFIG.TSM_BUY_BUTTON .. "([^\r\n]*)", "/click " .. CONFIG.YQ_TSM_BUY_BUTTON .. "%1")
        :gsub("/click " .. CONFIG.TSM_CRAFT_BUTTON .. "([^\r\n]*)", "/click " .. CONFIG.YQ_TSM_CRAFT_BUTTON .. "%1")
    if updatedBody ~= body then
        EditMacro(CONFIG.TSM_MACRO_NAME, macroName, macroIcon, updatedBody)
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

state.ClearPendingCraftEntries = function()
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

state.QueuePendingCraftEntry = function(entry, amount)
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

state.PopPendingCraftEntry = function()
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

function YQQuality.ConfirmPendingMerge()
    local pending = state.pendingMerge
    if not pending then
        return false
    end

    local inputNow = GetImmediateOwnedCount(pending.inputItemID)
    local outputNow = GetImmediateOwnedCount(pending.outputItemID)
    if inputNow > (pending.beforeInput - pending.inputQuantity)
        or outputNow < (pending.beforeOutput + pending.outputQuantity)
    then
        return false
    end

    local recipeName = ConsumeCraftEntry({
        queueKind = "merge",
        mergeKey = pending.mergeKey,
        recipeID = pending.recipeID,
    })
    if not recipeName then
        DebugPrint("merge-consume-miss key=" .. tostring(pending.mergeKey))
        return false
    end

    state.pendingMerge = nil
    state.armedMerge = nil
    ClearNextActionLock("merge-complete")
    state.ah.statusMessage = "Fusion terminee: " .. recipeName
    DebugPrint(
        "merge-complete key=" .. tostring(pending.mergeKey)
            .. " input=" .. tostring(pending.inputItemID)
            .. " output=" .. tostring(pending.outputItemID)
    )
    ScheduleRefresh()
    return true
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
    return math.min(#values, maxLines)
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
        if state.merchantAutoBuyRetries < CONFIG.MERCHANT_AUTO_BUY_MAX_RETRIES then
            ScheduleAutoBuyVendor(CONFIG.MERCHANT_AUTO_BUY_RETRY_DELAY)
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
    ScheduleAutoBuyVendor(CONFIG.MERCHANT_AUTO_BUY_VERIFY_DELAY)
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

    if state.merchantAutoBuyRetries < CONFIG.MERCHANT_AUTO_BUY_MAX_RETRIES then
        ScheduleAutoBuyVendor(CONFIG.MERCHANT_AUTO_BUY_RETRY_DELAY)
    else
        state.merchantAutoBuyAttempted = true
        DebugPrint("merchant-auto-buy retry-limit")
    end
end

ScheduleAutoBuyVendor = function(delay)
    state.EnsureDB()
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
    context.professionID = tonumber(context.professionID) or state.GetCurrentProfessionID()
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

local function AddVisibleRequiredReagents(schematicForm, schematic, craftingReagents, transaction)
    local slotFrames = {}
    local visitedFrames = {}
    local function TrackSlotFrame(frame)
        if not frame or type(frame.GetReagentSlotSchematic) ~= "function" or not frame.Button
            or (type(frame.Button.GetItemID) ~= "function" and type(frame.Button.GetCurrencyID) ~= "function") then
            return
        end

        local slot = SafeCall(frame.GetReagentSlotSchematic, frame)
        local itemID = tonumber(SafeCall(frame.Button.GetItemID, frame.Button))
        local currencyID = type(frame.Button.GetCurrencyID) == "function"
            and tonumber(SafeCall(frame.Button.GetCurrencyID, frame.Button)) or nil
        if slot and ((itemID and itemID > 0) or (currencyID and currencyID > 0)) then
            slotFrames[#slotFrames + 1] = {
                itemID = itemID,
                currencyID = currencyID,
                slotIndex = tonumber(slot.slotIndex),
                dataSlotIndex = tonumber(slot.dataSlotIndex),
            }
        end
    end

    local function Visit(frame, depth)
        if not frame or visitedFrames[frame] or depth > 4 then
            return
        end
        visitedFrames[frame] = true
        TrackSlotFrame(frame)

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
    for _, slotGroup in pairs((schematicForm and schematicForm.reagentSlots) or {}) do
        if type(slotGroup) == "table" then
            for _, frame in pairs(slotGroup) do
                Visit(frame, 0)
            end
        end
    end
    Visit(schematicForm, 0)

    for schematicIndex, slot in ipairs(schematic and schematic.reagentSlotSchematics or {}) do
        local dataSlotIndex = tonumber(slot.dataSlotIndex)
        local requiredQuantity = math.max(0, tonumber(slot.quantityRequired) or 0)
        local allowedItems = {}
        local allowedCurrencies = {}
        local allocatedQuantity = 0
        for _, candidate in ipairs(slot.reagents or {}) do
            local itemID = tonumber(candidate.itemID)
            local currencyID = tonumber(candidate.currencyID)
            if itemID then
                allowedItems[itemID] = true
            elseif currencyID then
                allowedCurrencies[currencyID] = true
            end
        end
        for _, reagentInfo in ipairs(craftingReagents or {}) do
            local itemID = tonumber(reagentInfo and reagentInfo.reagent and reagentInfo.reagent.itemID)
            local currencyID = tonumber(reagentInfo and reagentInfo.reagent and reagentInfo.reagent.currencyID)
            local infoSlotIndex = tonumber(reagentInfo and reagentInfo.dataSlotIndex)
            local sameSlot = not dataSlotIndex or not infoSlotIndex or infoSlotIndex == dataSlotIndex
            if sameSlot and ((itemID and allowedItems[itemID]) or (currencyID and allowedCurrencies[currencyID])) then
                allocatedQuantity = allocatedQuantity + math.max(0, tonumber(reagentInfo.quantity) or 0)
            end
        end
        local missingQuantity = dataSlotIndex and math.max(0, requiredQuantity - allocatedQuantity) or 0
        -- Blizzard returns nil from GetCraftingOperationInfo when a normal
        -- non-quality required reagent is included. Only required-selectable
        -- slots need to be restored here, matching CraftSim's reagent model.
        if IsRequiredSelectableReagentSlot(slot) and missingQuantity > 0 then
            local selectedItemID
            local selectedCurrencyID
            for _, slotFrame in ipairs(slotFrames) do
                local indexMatches = slotFrame.dataSlotIndex == dataSlotIndex
                    or slotFrame.slotIndex == tonumber(slot.slotIndex)
                local itemMatches = slotFrame.itemID and allowedItems[slotFrame.itemID]
                local currencyMatches = slotFrame.currencyID and allowedCurrencies[slotFrame.currencyID]
                if (itemMatches or currencyMatches)
                    and (indexMatches or (selectedItemID == nil and selectedCurrencyID == nil)) then
                    selectedItemID = slotFrame.itemID
                    selectedCurrencyID = slotFrame.currencyID
                    if indexMatches then
                        break
                    end
                end
            end

            if not selectedItemID and not selectedCurrencyID and transaction
                and type(transaction.GetAllocations) == "function" then
                local allocations = SafeCall(transaction.GetAllocations, transaction, schematicIndex)
                if not allocations and tonumber(slot.slotIndex) and tonumber(slot.slotIndex) ~= schematicIndex then
                    allocations = SafeCall(transaction.GetAllocations, transaction, tonumber(slot.slotIndex))
                end
                if allocations and type(allocations.FindAllocationByReagent) == "function" then
                    for _, candidate in ipairs(slot.reagents or {}) do
                        local allocation = SafeCall(allocations.FindAllocationByReagent, allocations, candidate)
                        local quantity = allocation and type(allocation.GetQuantity) == "function"
                            and tonumber(SafeCall(allocation.GetQuantity, allocation)) or 0
                        if quantity and quantity > 0 then
                            selectedItemID = tonumber(candidate.itemID)
                            selectedCurrencyID = tonumber(candidate.currencyID)
                            break
                        end
                    end
                end
            end

            if selectedItemID or selectedCurrencyID then
                craftingReagents[#craftingReagents + 1] = {
                    dataSlotIndex = dataSlotIndex,
                    reagent = { itemID = selectedItemID, currencyID = selectedCurrencyID },
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
    craftingReagents = AddVisibleRequiredReagents(schematicForm, schematic, craftingReagents, transaction)

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
    local queuedReservation = GetQueuedConcentrationReservation(state.GetCurrentProfessionID(), currencyID)
    local availableAfterQueue = math.max(0, available - queuedReservation)
    local maxQuantity = concentrationCost > 0
        and math.min(CONFIG.MAX_QUEUE_QTY, math.floor(availableAfterQueue / concentrationCost))
        or 0

    if context then
        context.applyConcentration = true
        context.concentrationCost = concentrationCost
        context.concentrationCurrencyID = currencyID
        context.craftingReagents = NormalizeCraftingReagents(craftingReagents)
        if type(schematic) == "table" then
            context.reagents = BuildCompleteRecipeReagents(schematic, context.craftingReagents, recipeInfo)
        end
    end

    return {
        available = available,
        queuedReservation = queuedReservation,
        availableForDump = availableAfterQueue,
        cost = concentrationCost,
        maxQuantity = maxQuantity,
        context = context,
    }
end

function YQQuality.GetFirstFavoriteRecipeID()
    if type(C_TradeSkillUI) ~= "table"
        or type(C_TradeSkillUI.GetAllRecipeIDs) ~= "function"
        or type(C_TradeSkillUI.GetRecipeInfo) ~= "function"
        or type(C_TradeSkillUI.IsRecipeFavorite) ~= "function" then
        return nil, false
    end

    local recipeIDs = SafeCall(C_TradeSkillUI.GetAllRecipeIDs)
    if type(recipeIDs) ~= "table" then
        return nil, false
    end

    local dataReady = true
    for _, recipeID in ipairs(recipeIDs) do
        local info = SafeCall(C_TradeSkillUI.GetRecipeInfo, recipeID)
        if type(info) ~= "table" then
            dataReady = false
        elseif info.learned ~= false and info.isRecraft ~= true then
            local isFavorite = SafeCall(C_TradeSkillUI.IsRecipeFavorite, recipeID)
            if isFavorite == true then
                return tonumber(recipeID), true
            end
        end
    end

    return nil, dataReady
end

function YQQuality.ScheduleAutoQueueFavoriteConcentration(delay)
    local autoQueue = state.autoFavoriteConcentration
    if not autoQueue.pending or autoQueue.timerQueued then
        return
    end

    autoQueue.timerQueued = true
    C_Timer.After(delay or 0, function()
        autoQueue.timerQueued = false
        if autoQueue.pending then
            YQQuality.TryAutoQueueFavoriteConcentration()
        end
    end)
end

state.craftGear.GetRoleForLink = function(link)
    if type(link) ~= "string" or link == "" then
        return "none"
    end

    local stats
    if type(C_Item) == "table" and type(C_Item.GetItemStats) == "function" then
        stats = SafeCall(C_Item.GetItemStats, link)
    elseif type(GetItemStats) == "function" then
        stats = SafeCall(GetItemStats, link)
    end
    if type(stats) ~= "table" then
        return "none"
    end

    local function HasStat(keys)
        for _, key in ipairs(keys) do
            local value = stats[key]
            if tonumber(value) and tonumber(value) > 0 then
                return true
            end
        end
        return false
    end

    local multicraftKeys = {
        "ITEM_MOD_MULTICRAFT_RATING_SHORT",
        "ITEM_MOD_MULTICRAFT_RATING",
    }
    local resourcefulnessKeys = {
        "ITEM_MOD_RESOURCEFULNESS_RATING_SHORT",
        "ITEM_MOD_RESOURCEFULNESS_RATING",
    }
    for _, key in ipairs({
        _G.ITEM_MOD_MULTICRAFT_RATING_SHORT,
        _G.ITEM_MOD_MULTICRAFT_RATING,
    }) do
        if key then multicraftKeys[#multicraftKeys + 1] = key end
    end
    for _, key in ipairs({
        _G.ITEM_MOD_RESOURCEFULNESS_RATING_SHORT,
        _G.ITEM_MOD_RESOURCEFULNESS_RATING,
    }) do
        if key then resourcefulnessKeys[#resourcefulnessKeys + 1] = key end
    end

    if HasStat(multicraftKeys) then
        return "multicraft"
    end
    if HasStat(resourcefulnessKeys) then
        return "resourcefulness"
    end
    return "none"
end

state.craftGear.GetBagItem = function(bagID, slotIndex)
    local info = type(C_Container) == "table"
        and type(C_Container.GetContainerItemInfo) == "function"
        and SafeCall(C_Container.GetContainerItemInfo, bagID, slotIndex)
        or nil
    local itemID = info and tonumber(info.itemID) or nil
    local link = info and info.hyperlink or nil
    if not link and type(C_Container) == "table" and type(C_Container.GetContainerItemLink) == "function" then
        link = SafeCall(C_Container.GetContainerItemLink, bagID, slotIndex)
    end
    if not link and type(GetContainerItemLink) == "function" then
        link = SafeCall(GetContainerItemLink, bagID, slotIndex)
    end
    if not itemID and link and type(GetItemInfoInstant) == "function" then
        itemID = tonumber(select(1, SafeCall(GetItemInfoInstant, link)))
    end
    if not itemID and type(C_Container) == "table" and type(C_Container.GetContainerItemID) == "function" then
        itemID = tonumber(SafeCall(C_Container.GetContainerItemID, bagID, slotIndex))
    end
    return itemID, link, info
end

state.craftGear.IsMainToolLink = function(link, itemID)
    if (type(link) ~= "string" or link == "") and not itemID then
        return false
    end
    local itemReference = itemID or link
    local equipLoc
    if type(C_Item) == "table" and type(C_Item.GetItemInfoInstant) == "function" then
        local ok, _, _, _, itemEquipLoc = pcall(C_Item.GetItemInfoInstant, itemReference)
        if ok then
            equipLoc = itemEquipLoc
        end
    end
    if not equipLoc and type(GetItemInfoInstant) == "function" then
        local ok, _, _, _, itemEquipLoc = pcall(GetItemInfoInstant, itemReference)
        if ok then
            equipLoc = itemEquipLoc
        end
    end
    if not equipLoc and type(GetItemInfo) == "function" then
        local ok, _, _, _, _, _, _, _, _, itemEquipLoc = pcall(GetItemInfo, itemReference)
        if ok then
            equipLoc = itemEquipLoc
        end
    end
    if equipLoc == "INVTYPE_PROFESSION_TOOL" then
        return true
    end
    return false
end

state.craftGear.GetProfessionRecords = function()
    local records = {}
    local seen = {}
    local skillLines = type(C_TradeSkillUI) == "table"
        and type(C_TradeSkillUI.GetAllProfessionTradeSkillLines) == "function"
        and SafeCall(C_TradeSkillUI.GetAllProfessionTradeSkillLines)
        or {}
    for _, skillLineID in ipairs(skillLines or {}) do
        local info = type(C_TradeSkillUI) == "table"
            and type(C_TradeSkillUI.GetProfessionInfoBySkillLineID) == "function"
            and SafeCall(C_TradeSkillUI.GetProfessionInfoBySkillLineID, skillLineID)
            or nil
        local professionID = info and tonumber(info.profession) or nil
        if professionID and not seen[professionID] then
            seen[professionID] = true
            records[#records + 1] = {
                professionID = professionID,
                skillLineID = tonumber(skillLineID),
            }
        end
    end

    if #records == 0 and state.GetCurrentProfessionID then
        local professionID = tonumber(state.GetCurrentProfessionID())
        if professionID then
            local skillLineID = type(C_TradeSkillUI) == "table"
                and type(C_TradeSkillUI.GetProfessionSkillLineID) == "function"
                and SafeCall(C_TradeSkillUI.GetProfessionSkillLineID, professionID)
                or nil
            records[1] = {
                professionID = professionID,
                skillLineID = tonumber(skillLineID),
            }
        end
    end
    return records
end

state.craftGear.Scan = function()
    local gearState = state.craftGear

    if type(C_TradeSkillUI) ~= "table" then
        return
    end

    local knownToolIDs = {}
    for _, profession in pairs(gearState.byProfession) do
        for _, tool in ipairs(profession.tools or {}) do
            if tool.itemID then knownToolIDs[tool.itemID] = true end
        end
        if profession.equipped and profession.equipped.itemID then
            knownToolIDs[profession.equipped.itemID] = true
        end
    end
    local candidatesBySkillLine = {}
    local hasPendingItemData = false
    for bagID = 0, 4 do
        local slotCount = type(C_Container) == "table"
            and type(C_Container.GetContainerNumSlots) == "function"
            and tonumber(SafeCall(C_Container.GetContainerNumSlots, bagID))
            or type(GetContainerNumSlots) == "function" and tonumber(SafeCall(GetContainerNumSlots, bagID))
            or 0
        for slotIndex = 1, math.max(0, slotCount or 0) do
            local itemID, link = state.craftGear.GetBagItem(bagID, slotIndex)
            if itemID then
                local isMainTool = state.craftGear.IsMainToolLink(link, itemID)
                local hasUsableLink = type(link) == "string" and link:find("item:", 1, true) ~= nil
                if isMainTool and not hasUsableLink then
                    hasPendingItemData = true
                    WarmItemData(itemID, true)
                elseif isMainTool then
                    local skillLineID = type(C_TradeSkillUI.GetSkillLineForGear) == "function"
                        and tonumber(SafeCall(C_TradeSkillUI.GetSkillLineForGear, link))
                        or nil
                    if skillLineID then
                        local role = state.craftGear.GetRoleForLink(link)
                        if role == "multicraft" or role == "resourcefulness" then
                            candidatesBySkillLine[skillLineID] = candidatesBySkillLine[skillLineID] or {}
                            candidatesBySkillLine[skillLineID][#candidatesBySkillLine[skillLineID] + 1] = {
                                itemID = itemID,
                                link = link,
                                role = role,
                                bagID = bagID,
                                slotIndex = slotIndex,
                            }
                        else
                            hasPendingItemData = WarmItemData(itemID, true)
                                or knownToolIDs[itemID]
                                or hasPendingItemData
                        end
                    else
                        hasPendingItemData = WarmItemData(itemID, true)
                            or knownToolIDs[itemID]
                            or hasPendingItemData
                    end
                elseif knownToolIDs[itemID] then
                    hasPendingItemData = true
                    WarmItemData(itemID, true)
                end
            end
        end
    end

    local scannedByProfession = {}
    for _, record in ipairs(state.craftGear.GetProfessionRecords()) do
        local professionID = record.professionID
        local slots = type(C_TradeSkillUI.GetProfessionSlots) == "function"
            and SafeCall(C_TradeSkillUI.GetProfessionSlots, professionID)
            or nil
        local toolSlot = slots and (slots[1] or slots[0]) or nil
        local equippedLink = toolSlot and type(GetInventoryItemLink) == "function"
            and SafeCall(GetInventoryItemLink, "player", toolSlot)
            or nil
        local equippedItemID = toolSlot and type(GetInventoryItemID) == "function"
            and tonumber(SafeCall(GetInventoryItemID, "player", toolSlot))
            or nil
        local equippedRole = state.craftGear.GetRoleForLink(equippedLink)
        if equippedItemID and equippedRole == "none" then
            local previous = gearState.byProfession[professionID]
            hasPendingItemData = WarmItemData(equippedItemID, true)
                or (
                    previous
                    and previous.equipped
                    and previous.equipped.itemID == equippedItemID
                    and previous.equipped.role ~= "none"
                )
                or hasPendingItemData
        end

        local roleSet = {}
        if equippedRole == "multicraft" or equippedRole == "resourcefulness" then
            roleSet[equippedRole] = true
        end
        local profession = {
            professionID = professionID,
            skillLineID = record.skillLineID,
            toolSlot = toolSlot,
            equipped = {
                itemID = equippedItemID,
                link = equippedLink,
                role = equippedRole,
            },
            tools = {},
            candidates = {},
        }
        local candidates = candidatesBySkillLine[record.skillLineID] or {}
        for _, candidate in ipairs(candidates) do
            profession.tools[#profession.tools + 1] = candidate
            profession.candidates[candidate.role] = profession.candidates[candidate.role] or candidate
            roleSet[candidate.role] = true
        end
        profession.active = roleSet.multicraft == true and roleSet.resourcefulness == true
        scannedByProfession[professionID] = profession
    end

    if not hasPendingItemData then
        gearState.transientRetryCount = 0
        gearState.byProfession = scannedByProfession
        wipe(gearState.recipeRoles)
        gearState.generation = (gearState.generation or 0) + 1
    else
        if (gearState.transientRetryCount or 0) < 3 then
            gearState.transientRetryCount = (gearState.transientRetryCount or 0) + 1
            C_Timer.After(0.25, function()
                state.craftGear.ScheduleScan()
            end)
        end
        if CONFIG.debugNextCraft then
            DebugPrint("craft-gear preserve-last-good reason=item-data retry=" .. tostring(gearState.transientRetryCount))
        end
    end

    state.craftGear.ConfirmPendingTool()
    return not hasPendingItemData
end

state.craftGear.ScheduleScan = function()
    if state.craftGear.scanQueued then
        return
    end
    state.craftGear.scanQueued = true
    C_Timer.After(0, function()
        state.craftGear.scanQueued = false
        if state.craftGear.Scan() then
            ScheduleRefresh()
        end
    end)
end

state.craftGear.ConfirmPendingTool = function()
    local pending = state.pendingCraftTool
    if not pending then
        return
    end

    local profession = state.craftGear.byProfession[tonumber(pending.professionID) or 0]
    local equipped = profession and profession.equipped
    if equipped and equipped.role == pending.role
        and (not pending.itemID or not equipped.itemID or equipped.itemID == pending.itemID)
    then
        state.pendingCraftTool = nil
        ClearNextActionLock("tool-equipped")
        state.ah.statusMessage = "Outil " .. tostring(pending.role) .. " equipe"
        ScheduleRefresh()
        return
    end

    if pending.expiresAt and GetTime() >= pending.expiresAt then
        state.pendingCraftTool = nil
        ClearNextActionLock("tool-timeout")
        state.ah.statusMessage = "Outil non confirme"
        ScheduleRefresh()
    end
end

state.craftGear.HasBonusStat = function(bonusStats, role)
    for _, bonus in ipairs(bonusStats or {}) do
        local text = string.lower(table.concat({
            tostring(bonus.bonusStatName or ""),
            tostring(bonus.statName or ""),
            tostring(bonus.name or ""),
            tostring(bonus.bonusStat or ""),
        }, " "))
        if role == "multicraft" and (text:find("multicraft", 1, true) or text:find("multi-craft", 1, true)) then
            return true
        end
        if role == "resourcefulness"
            and (text:find("resource", 1, true)
                or text:find("ressource", 1, true)
                or text:find("ingenios", 1, true)
                or text:find("ingénios", 1, true))
        then
            return true
        end
    end
    return false
end

state.craftGear.GetRecipeRole = function(entry, transaction)
    local recipeID = tonumber(entry and entry.recipeID) or 0
    if recipeID <= 0 then
        return "none"
    end

    local craftingReagents = NormalizeCraftingReagents(entry.craftingReagents)
    if #craftingReagents == 0 and transaction and type(transaction.CreateCraftingReagentInfoTbl) == "function" then
        craftingReagents = SafeCall(transaction.CreateCraftingReagentInfoTbl, transaction) or {}
    end
    local key = table.concat({
        tostring(recipeID),
        tostring(entry.orderID or 0),
        entry.applyConcentration == true and "1" or "0",
        BuildCraftingReagentSignature(craftingReagents),
    }, "|")
    local cached = state.craftGear.recipeRoles[key]
    if cached and cached.generation == state.craftGear.generation then
        return cached.role
    end

    local recipeInfo = type(C_TradeSkillUI) == "table"
        and type(C_TradeSkillUI.GetRecipeInfo) == "function"
        and SafeCall(C_TradeSkillUI.GetRecipeInfo, recipeID)
        or nil
    local operationInfo
    local orderID = tonumber(entry.orderID) or 0
    local applyConcentration = entry.applyConcentration == true
    if orderID > 0 and type(C_TradeSkillUI) == "table"
        and type(C_TradeSkillUI.GetCraftingOperationInfoForOrder) == "function"
    then
        operationInfo = SafeCall(
            C_TradeSkillUI.GetCraftingOperationInfoForOrder,
            recipeID,
            craftingReagents,
            orderID,
            applyConcentration
        )
    end
    if not operationInfo and type(C_TradeSkillUI) == "table"
        and type(C_TradeSkillUI.GetCraftingOperationInfo) == "function"
    then
        operationInfo = SafeCall(
            C_TradeSkillUI.GetCraftingOperationInfo,
            recipeID,
            craftingReagents,
            nil,
            applyConcentration
        )
    end

    local supportsStats = recipeInfo and recipeInfo.supportsCraftingStats
    local multicraft = state.craftGear.HasBonusStat(operationInfo and operationInfo.bonusStats, "multicraft")
    if not multicraft and supportsStats == true and recipeInfo then
        multicraft = recipeInfo.canCreateMultiple == true
    end
    local resourcefulness = supportsStats == true
        and state.craftGear.HasBonusStat(operationInfo and operationInfo.bonusStats, "resourcefulness")
        or false
    local role
    if multicraft then
        role = "multicraft"
    elseif resourcefulness then
        role = "resourcefulness"
    elseif recipeInfo and supportsStats == false then
        role = "none"
    else
        role = "unknown"
    end
    state.craftGear.recipeRoles[key] = {
        role = role,
        generation = state.craftGear.generation,
    }
    return role
end

state.craftGear.GetToolAction = function(entry, transaction)
    if not entry or entry.queueKind == "merge" or entry.queueKind == "direct_item" then
        return nil
    end
    local professionID = tonumber(entry.professionID) or tonumber(state.GetCurrentProfessionID and state.GetCurrentProfessionID())
    local profession = professionID and state.craftGear.byProfession[professionID] or nil
    if not profession or not profession.active then
        return nil
    end

    local role = state.craftGear.GetRecipeRole(entry, transaction)
    if role ~= "multicraft" and role ~= "resourcefulness" then
        return nil
    end
    local candidate = profession.candidates[role]
    if not candidate or profession.equipped.role == role then
        return nil
    end
    if InCombatLockdown and InCombatLockdown() then
        return {
            entry = entry,
            enabled = false,
            text = "Next: sortie combat",
        }
    end
    return {
        entry = entry,
        action = "equip_tool",
        enabled = true,
        role = role,
        itemID = candidate.itemID,
        itemLink = candidate.link,
        professionID = professionID,
        text = role == "multicraft" and "Next: outil MC" or "Next: outil RF",
    }
end

state.craftGear.GetEntrySortRank = function(entry)
    if not entry or entry.queueKind == "merge" or entry.queueKind == "direct_item" then
        return 0
    end
    local professionID = tonumber(entry.professionID) or 0
    local profession = state.craftGear.byProfession[professionID]
    if not profession or not profession.active then
        return 0
    end
    local role = state.craftGear.GetRecipeRole(entry)
    if (role ~= "multicraft" and role ~= "resourcefulness") or not profession.candidates[role] then
        return 0
    end
    if profession.equipped.role == role then
        return 0
    end
    return role == "multicraft" and 1 or 2
end

state.InvalidateQualityPricing = function()
    if type(YQQuality.ClearRecipeCache) == "function" then
        YQQuality.ClearRecipeCache(true)
    end
end

state.InvalidateMaterialPricing = function()
    state.craft.qualityPriceCache = {}
    state.craft.qualityPriceRevision = (state.craft.qualityPriceRevision or 0) + 1
end

local function GetBoundBagItemCount(itemID)
    local total = 0
    local reagentBagID = Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag or 5
    DebugPrint(
        "finishing-bag-scan item=" .. tostring(GetItemName(itemID))
            .. " itemID=" .. tostring(itemID)
            .. " range=0.." .. tostring(reagentBagID)
    )
    for bagID = 0, reagentBagID do
        local slotCount = C_Container and type(C_Container.GetContainerNumSlots) == "function"
            and SafeCall(C_Container.GetContainerNumSlots, bagID) or 0
        for slotIndex = 1, math.max(0, tonumber(slotCount) or 0) do
            local info = C_Container and type(C_Container.GetContainerItemInfo) == "function"
                and SafeCall(C_Container.GetContainerItemInfo, bagID, slotIndex) or nil
            if info and tonumber(info.itemID) == itemID then
                local isBound = info.isBound == true
                local location = ItemLocation and type(ItemLocation.CreateFromBagAndSlot) == "function"
                    and ItemLocation:CreateFromBagAndSlot(bagID, slotIndex) or nil
                if location and C_Item and type(C_Item.IsBound) == "function" then
                    local apiBound = SafeCall(C_Item.IsBound, location)
                    if apiBound ~= nil then isBound = apiBound == true end
                end
                if isBound then
                    total = total + math.max(0, tonumber(info.stackCount) or 0)
                    DebugPrint(
                        "finishing-bag-match item=" .. tostring(GetItemName(itemID))
                            .. " itemID=" .. tostring(itemID)
                            .. " bag=" .. tostring(bagID)
                            .. " slot=" .. tostring(slotIndex)
                            .. " stack=" .. tostring(info.stackCount or 0)
                            .. " bound=true"
                    )
                else
                    DebugPrint(
                        "finishing-bag-match item=" .. tostring(GetItemName(itemID))
                            .. " itemID=" .. tostring(itemID)
                            .. " bag=" .. tostring(bagID)
                            .. " slot=" .. tostring(slotIndex)
                            .. " stack=" .. tostring(info.stackCount or 0)
                            .. " bound=false"
                    )
                end
            end
        end
    end
    DebugPrint(
        "finishing-bag-count item=" .. tostring(GetItemName(itemID))
            .. " itemID=" .. tostring(itemID)
            .. " count=" .. tostring(total)
    )
    return total
end

local function GetBoundFinishingRole(itemID)
    local text = string.lower(tostring(GetItemName(itemID) or ""))
    if C_TooltipInfo and type(C_TooltipInfo.GetItemByID) == "function" then
        local tooltip = SafeCall(C_TooltipInfo.GetItemByID, itemID)
        for _, line in ipairs(tooltip and tooltip.lines or {}) do
            text = text .. " " .. string.lower(tostring(line.leftText or "") .. " " .. tostring(line.rightText or ""))
        end
    end
    if text:find("multicraft", 1, true) or text:find("fabrication multiple", 1, true) then
        DebugPrint("finishing-role item=" .. tostring(GetItemName(itemID)) .. " itemID=" .. tostring(itemID) .. " role=multicraft")
        return "multicraft"
    end
    if text:find("resourcefulness", 1, true) or text:find("débrouillardise", 1, true) then
        DebugPrint("finishing-role item=" .. tostring(GetItemName(itemID)) .. " itemID=" .. tostring(itemID) .. " role=resourcefulness")
        return "resourcefulness"
    end
    if text:find("ingenuity", 1, true) or text:find("ingéniosité", 1, true) then
        DebugPrint("finishing-role item=" .. tostring(GetItemName(itemID)) .. " itemID=" .. tostring(itemID) .. " role=ingenuity")
        return "ingenuity"
    end
    DebugPrint("finishing-role item=" .. tostring(GetItemName(itemID)) .. " itemID=" .. tostring(itemID) .. " role=none")
    return nil
end

local function CopyAutoFavoriteContext(context, craftingReagents, reagents)
    local copy = {}
    for key, value in pairs(context or {}) do copy[key] = value end
    copy.craftingReagents = NormalizeCraftingReagents(craftingReagents)
    copy.reagents = reagents
    return copy
end

local function GetFinishingBatches(schematicForm, dumpState)
    local context = dumpState and dumpState.context
    if not context or dumpState.maxQuantity <= 0 then
        DebugPrint("finishing-batches unavailable context-or-quantity")
        return nil
    end
    DebugPrint(
        "finishing-batches start recipe=" .. tostring(context.recipeID)
            .. " quantity=" .. tostring(dumpState.maxQuantity)
    )

    local recipeInfo = SafeCall(C_TradeSkillUI.GetRecipeInfo, context.recipeID)
    local recipeLevel = schematicForm and type(schematicForm.GetCurrentRecipeLevel) == "function"
        and SafeCall(schematicForm.GetCurrentRecipeLevel, schematicForm) or nil
    local schematic = SafeCall(C_TradeSkillUI.GetRecipeSchematic, context.recipeID, false, recipeLevel)
    if type(recipeInfo) ~= "table" or type(schematic) ~= "table" then
        DebugPrint(
            "finishing-batches unavailable recipe-data recipe=" .. tostring(context.recipeID)
                .. " recipeInfo=" .. tostring(type(recipeInfo))
                .. " schematic=" .. tostring(type(schematic))
        )
        return nil
    end

    local optionalSlots = YQQuality.BuildOptionalSlots(recipeInfo, schematic)
    local base = YQQuality.CopyReagents(context.craftingReagents)
    local finishingSlots = {}
    for _, slotData in ipairs(optionalSlots) do
        if slotData.options[1] and slotData.options[1].isFinishing then
            finishingSlots[#finishingSlots + 1] = slotData
            base = YQQuality.ReplaceReagent(base, slotData.slot, {})
        end
    end
    DebugPrint(
        "finishing-slots recipe=" .. tostring(context.recipeID)
            .. " optional=" .. tostring(#optionalSlots)
            .. " finishing=" .. tostring(#finishingSlots)
    )
    if #finishingSlots == 0 then return nil end

    local recipeRole = state.craftGear.GetRecipeRole({
        recipeID = context.recipeID,
        craftingReagents = base,
        applyConcentration = true,
    })
    DebugPrint(
        "finishing-recipe-role recipe=" .. tostring(context.recipeID)
            .. " role=" .. tostring(recipeRole)
    )
    local candidates = { multicraft = {}, resourcefulness = {}, ingenuity = {} }
    for _, slotData in ipairs(finishingSlots) do
        local required = math.max(1, tonumber(slotData.slot.quantityRequired) or 1)
        for _, option in ipairs(slotData.options) do
            local role = GetBoundFinishingRole(option.itemID)
            local supportsRole = role == "ingenuity"
                or (role == "multicraft" and recipeRole == "multicraft")
                or (role == "resourcefulness" and recipeRole == "resourcefulness")
            local available = supportsRole and math.floor(GetBoundBagItemCount(option.itemID) / required) or 0
            DebugPrint(
                "finishing-candidate item=" .. tostring(option.itemName)
                    .. " itemID=" .. tostring(option.itemID)
                    .. " role=" .. tostring(role)
                    .. " supports=" .. tostring(supportsRole)
                    .. " required=" .. tostring(required)
                    .. " available=" .. tostring(available)
            )
            if available > 0 then
                candidates[role][#candidates[role] + 1] = {
                    itemID = option.itemID,
                    slot = slotData.slot,
                    available = available,
                    required = required,
                }
            end
        end
    end

    local batches, remaining = {}, dumpState.maxQuantity
    for _, role in ipairs({ "multicraft", "resourcefulness", "ingenuity" }) do
        table.sort(candidates[role], function(left, right) return left.itemID < right.itemID end)
        for _, candidate in ipairs(candidates[role]) do
            if remaining <= 0 then break end
            local quantity = math.min(remaining, candidate.available)
            if quantity > 0 then
                local selected = YQQuality.ReplaceReagent(base, candidate.slot, {
                    { itemID = candidate.itemID, quantity = candidate.required },
                })
                batches[#batches + 1] = {
                    quantity = quantity,
                    context = CopyAutoFavoriteContext(
                        context,
                        selected,
                        BuildCompleteRecipeReagents(schematic, selected, recipeInfo)
                    ),
                }
                DebugPrint(
                    "finishing-batch recipe=" .. tostring(context.recipeID)
                        .. " role=" .. tostring(role)
                        .. " itemID=" .. tostring(candidate.itemID)
                        .. " quantity=" .. tostring(quantity)
                )
                remaining = remaining - quantity
            end
        end
    end
    if remaining > 0 then
        batches[#batches + 1] = {
            quantity = remaining,
            context = CopyAutoFavoriteContext(
                context,
                base,
                BuildCompleteRecipeReagents(schematic, base, recipeInfo)
            ),
        }
        DebugPrint(
            "finishing-batch recipe=" .. tostring(context.recipeID)
                .. " role=none itemID=none quantity=" .. tostring(remaining)
        )
    end
    DebugPrint(
        "finishing-batches done recipe=" .. tostring(context.recipeID)
            .. " batches=" .. tostring(#batches)
    )
    return batches
end

local function QueueConcentrationDump(schematicForm, dumpState, source)
    local batches = GetFinishingBatches(schematicForm, dumpState)
    DebugPrint(
        "concentration-dump source=" .. tostring(source or "?")
            .. " recipe=" .. tostring(dumpState and dumpState.context and dumpState.context.recipeID)
            .. " batches=" .. tostring(batches and #batches or 0)
    )
    local queuedQuantity = 0
    if batches then
        for _, batch in ipairs(batches) do
            queuedQuantity = queuedQuantity + (QueueRecipeContext(batch.context, nil, batch.quantity) or 0)
        end
    else
        queuedQuantity = dumpState and dumpState.context and dumpState.maxQuantity > 0
            and QueueRecipeContext(dumpState.context, nil, dumpState.maxQuantity)
            or 0
    end
    DebugPrint(
        "concentration-dump queued source=" .. tostring(source or "?")
            .. " quantity=" .. tostring(queuedQuantity)
            .. " batches=" .. tostring(batches and #batches or 0)
            .. " fallback=" .. tostring(batches == nil)
    )
    if (source == "button" or source == "auto-favorite")
        and queuedQuantity > 0
        and YQQuality.IsIngenuityRefundAutoQueueEnabled()
    then
        local context = dumpState and dumpState.context
        state.autoFavoriteConcentration.tracker = {
            professionID = context and tonumber(context.professionID) or state.GetCurrentProfessionID(),
            recipeID = context and tonumber(context.recipeID),
            concentrationCost = dumpState and tonumber(dumpState.cost) or nil,
            concentrationCurrencyID = context and tonumber(context.concentrationCurrencyID),
            context = context,
            schematicForm = schematicForm,
            source = source,
            awaitingCraft = false,
            craftConfirmed = false,
            reservationConsumed = false,
            requeued = false,
            refundCheckAttempts = 0,
            refundCheckScheduled = false,
            currencyEventAmount = nil,
        }
        DebugPrint(
            "concentration-refund armed source=" .. tostring(source)
                .. " recipe=" .. tostring(context and context.recipeID)
                .. " cost=" .. tostring(dumpState and dumpState.cost)
        )
    end
    return batches, queuedQuantity
end

YQQuality.TryAutoQueueFavoriteConcentration = function()
    local autoQueue = state.autoFavoriteConcentration
    local request = autoQueue.pending
    if not request then
        return
    end

    request.attempts = (request.attempts or 0) + 1
    if request.attempts > 100 then
        DebugPrint("auto-favorite timeout profession=" .. tostring(request.professionID))
        autoQueue.pending = nil
        return
    end

    local professionID = state.GetCurrentProfessionID()
    if professionID ~= request.professionID then
        autoQueue.pending = nil
        return
    end
    if autoQueue.queuedByProfession[professionID] then
        autoQueue.pending = nil
        return
    end

    local favoriteRecipeID, recipeDataReady = YQQuality.GetFirstFavoriteRecipeID()
    if not recipeDataReady then
        YQQuality.ScheduleAutoQueueFavoriteConcentration(0.1)
        return
    end
    if not favoriteRecipeID then
        DebugPrint("auto-favorite none profession=" .. tostring(professionID))
        autoQueue.queuedByProfession[professionID] = true
        autoQueue.pending = nil
        return
    end

    local craftingPage = ProfessionsFrame and ProfessionsFrame.CraftingPage
    if not craftingPage or not craftingPage:IsShown() then
        YQQuality.ScheduleAutoQueueFavoriteConcentration(0.1)
        return
    end

    local schematicForm = GetCraftingSchematicForm()
    local recipeInfo = schematicForm and type(schematicForm.GetRecipeInfo) == "function"
        and SafeCall(schematicForm.GetRecipeInfo, schematicForm) or nil
    local currentRecipeID = recipeInfo and tonumber(recipeInfo.recipeID)
    if currentRecipeID ~= favoriteRecipeID then
        if not request.openRequested and type(C_TradeSkillUI.OpenRecipe) == "function" then
            request.openRequested = true
            if schematicForm and schematicForm.loader and type(schematicForm.loader.Cancel) == "function" then
                pcall(schematicForm.loader.Cancel, schematicForm.loader)
            end
            SafeCall(C_TradeSkillUI.OpenRecipe, favoriteRecipeID)
        end
        YQQuality.ScheduleAutoQueueFavoriteConcentration(0.1)
        return
    end

    local dumpState = GetConcentrationDumpState(schematicForm)
    if not dumpState or not dumpState.context or dumpState.cost <= 0 then
        YQQuality.ScheduleAutoQueueFavoriteConcentration(0.1)
        return
    end

    state.EnsureDB()
    local alreadyQueued = false
    for _, entry in ipairs(db.queue) do
        if entry.queueKind ~= "patron"
            and tonumber(entry.professionID) == professionID
            and tonumber(entry.recipeID) == favoriteRecipeID
            and entry.applyConcentration == true then
            alreadyQueued = true
            break
        end
    end

    if not alreadyQueued and dumpState.maxQuantity > 0 then
        local batches, queuedQuantity = QueueConcentrationDump(schematicForm, dumpState, "auto-favorite")
        DebugPrint("auto-favorite queued profession=" .. tostring(professionID) .. " recipe=" .. tostring(favoriteRecipeID) .. " quantity=" .. tostring(queuedQuantity) .. " batches=" .. tostring(batches and #batches or 0) .. " reserved=" .. tostring(dumpState.queuedReservation))
    else
        DebugPrint("auto-favorite skip profession=" .. tostring(professionID) .. " recipe=" .. tostring(favoriteRecipeID) .. " queued=" .. tostring(alreadyQueued) .. " max=" .. tostring(dumpState.maxQuantity) .. " reserved=" .. tostring(dumpState.queuedReservation))
    end

    autoQueue.queuedByProfession[professionID] = true
    autoQueue.pending = nil
end

state.GetCurrentConcentrationAmount = function()
    local currencyID = SafeCall(YQQuality.GetConcentrationCurrencyID, nil)
    local currencyInfo = currencyID and C_CurrencyInfo and type(C_CurrencyInfo.GetCurrencyInfo) == "function"
        and SafeCall(C_CurrencyInfo.GetCurrencyInfo, currencyID) or nil
    return currencyInfo and tonumber(currencyInfo.quantity) or nil
end

local function ScheduleFavoriteConcentrationRefundRetry(tracker)
    local attempts = (tonumber(tracker.refundCheckAttempts) or 0) + 1
    tracker.refundCheckAttempts = attempts
    if attempts > CONFIG.CONCENTRATION_REFUND_MAX_RETRIES then
        tracker.awaitingCraft = false
        DebugPrint("concentration-refund timeout waiting-for-currency-update")
        return
    end
    if tracker.refundCheckScheduled then
        return
    end
    tracker.refundCheckScheduled = true
    C_Timer.After(CONFIG.CONCENTRATION_REFUND_RETRY_DELAY, function()
        if state.autoFavoriteConcentration.tracker ~= tracker then
            return
        end
        tracker.refundCheckScheduled = false
        YQQuality.TryQueueFavoriteConcentrationRefund()
    end)
end

function YQQuality.TryQueueFavoriteConcentrationRefund(observedAmount)
    local tracker = state.autoFavoriteConcentration.tracker
    if not tracker or not tracker.awaitingCraft or not tracker.craftConfirmed or tracker.requeued then
        return
    end

    if not YQQuality.IsIngenuityRefundAutoQueueEnabled() then
        tracker.awaitingCraft = false
        tracker.craftConfirmed = false
        return
    end

    local before = tonumber(tracker.beforeConcentration)
    local after = state.GetCurrentConcentrationAmount()
    local eventAmount = tonumber(observedAmount) or tonumber(tracker.currencyEventAmount)
    if after == before and eventAmount and eventAmount ~= before then
        after = eventAmount
    end
    local cost = tonumber(tracker.concentrationCost) or 0
    if not before or not after or cost <= 0 then
        ScheduleFavoriteConcentrationRefundRetry(tracker)
        return
    end

    -- CURRENCY_DISPLAY_UPDATE can arrive before GetCurrencyInfo exposes the
    -- post-craft value. Never treat the pre-craft amount as a refund result.
    if after == before then
        DebugPrint(
            "concentration-refund wait currency-update before=" .. tostring(before)
                .. " observed=" .. tostring(after)
        )
        ScheduleFavoriteConcentrationRefundRetry(tracker)
        return
    end

    tracker.awaitingCraft = false
    tracker.refundCheckAttempts = 0
    tracker.currencyEventAmount = nil
    local spent = before - cost
    local professionID = tonumber(tracker.professionID) or state.GetCurrentProfessionID()
    local currencyID = tonumber(tracker.concentrationCurrencyID)
    local reserved = GetQueuedConcentrationReservation(professionID, currencyID)
    if tracker.reservationConsumed ~= true then
        reserved = math.max(0, reserved - cost)
    end
    local availableAfterQueue = math.max(0, after - reserved)
    DebugPrint(
        "concentration-refund check source=" .. tostring(tracker.source or "?")
            .. " recipe=" .. tostring(tracker.recipeID)
            .. " before=" .. tostring(before)
            .. " after=" .. tostring(after)
            .. " cost=" .. tostring(cost)
            .. " reserved=" .. tostring(reserved)
            .. " available=" .. tostring(availableAfterQueue)
    )
    if after <= spent or availableAfterQueue < cost then
        DebugPrint(
            "concentration-refund skip recipe=" .. tostring(tracker.recipeID)
                .. " reason=insufficient-after-queue"
        )
        return
    end

    local schematicForm = tracker.schematicForm or GetCraftingSchematicForm()
    local refundState = {
        context = tracker.context,
        cost = cost,
        maxQuantity = 1,
    }
    local batches, queuedQuantity = QueueConcentrationDump(schematicForm, refundState, "ingenuity-refund")
    if queuedQuantity > 0 then
        tracker.requeued = true
        DebugPrint(
            "concentration-refund queued recipe=" .. tostring(tracker.recipeID)
                .. " quantity=" .. tostring(queuedQuantity)
                .. " batches=" .. tostring(batches and #batches or 0)
        )
    end
end

local function IsCraftSimPriceKnown(priceData, itemID)
    local priceEntry = priceData and priceData.reagentPriceInfos and priceData.reagentPriceInfos[itemID]
    local priceInfo = priceEntry and priceEntry.priceInfo
    return type(priceEntry and priceEntry.itemPrice) == "number"
        and type(priceInfo) == "table"
        and priceInfo.noPriceSource ~= true
        and (priceInfo.noAHPriceFound ~= true or priceInfo.isOverride == true or priceInfo.isExpectedCost == true)
end

local function IsExcludedFirstCraftReagent(reagent)
    local item = reagent and (reagent.item or reagent.originalItem
        or (type(reagent.GetItemID) == "function" and reagent))
    local itemID = item and type(item.GetItemID) == "function"
        and tonumber(SafeCall(item.GetItemID, item))
        or nil
    local currencyID = tonumber(reagent and reagent.currencyID)
    return CONFIG.FIRST_CRAFT_EXCLUDED_ITEM_IDS[itemID] == true
        or CONFIG.FIRST_CRAFT_EXCLUDED_ITEM_IDS[currencyID] == true
end

local function RecipeUsesExcludedFirstCraftReagent(recipeData)
    local reagentData = recipeData and recipeData.reagentData
    if type(reagentData) ~= "table" then
        return false
    end

    for _, reagent in ipairs(reagentData.requiredReagents or {}) do
        for _, reagentItem in ipairs(reagent.items or {}) do
            if IsExcludedFirstCraftReagent(reagentItem)
                or IsExcludedFirstCraftReagent(reagentItem.originalItem) then
                return true
            end
        end
    end

    local requiredSlot = reagentData.requiredSelectableReagentSlot
    if requiredSlot and IsExcludedFirstCraftReagent(requiredSlot.activeReagent) then
        return true
    end
    for _, possibleReagent in ipairs(requiredSlot and requiredSlot.possibleReagents or {}) do
        if IsExcludedFirstCraftReagent(possibleReagent) then
            return true
        end
    end

    return false
end

local function IsOwnedSoulboundReagent(itemID, quantity, reserved)
    if not IsSoulboundReagent(itemID) then
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
    state.EnsureDB()
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
    DebugPrint("first-craft-cost begin recipe=" .. tostring(recipeID)
        .. " profession=" .. tostring(professionID)
        .. " reserved=" .. tostring(reserved and "yes" or "no"))
    if type(_G.CraftSimAPI) ~= "table" or type(_G.CraftSimAPI.GetRecipeData) ~= "function" then
        return nil, "craftsim"
    end

    local ok, recipeData = pcall(_G.CraftSimAPI.GetRecipeData, _G.CraftSimAPI, { recipeID = recipeID })
    if not ok or type(recipeData) ~= "table" or type(recipeData.reagentData) ~= "table" then
        return nil, "incompatible"
    end
    if RecipeUsesExcludedFirstCraftReagent(recipeData) then
        return nil, "fused-vitality"
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
    DebugPrint("first-craft-cost price-data recipe=" .. tostring(recipeID)
        .. " craftingCosts=" .. tostring(priceData and priceData.craftingCosts)
        .. " parsed=" .. tostring(craftingCost))
    if not craftingCost then
        DebugPrint("first-craft-cost abort recipe=" .. tostring(recipeID) .. " reason=unknown-cost")
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

    if craftingCost >= CONFIG.FIRST_CRAFT_COST_LIMIT then
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
    state.EnsureDB()
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

    state.EnsureDB()
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

    local professionID = state.GetCurrentProfessionID()
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
    local professionID = state.GetCurrentProfessionID()
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
    return #summary.mailboxTasks > 0
        or #summary.acquireTasks > 0
        or #summary.auctionTasks > 0
        or #summary.vendorTasks > 0
        or #summary.craftTasks > 0
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

    if state.craft.todoTitle then
        state.craft.todoTitle:SetShown(hasTasks)
    end
    for _, line in ipairs(state.craft.lines) do
        line:SetShown(hasTasks)
    end

    local displayedLineCount = SetLineText(
        state.craft.lines,
        CONFIG.MAX_CRAFT_LINES,
        BuildCraftLines(summary)
    )
    if hasTasks then
        local unusedLineCount = math.max(0, CONFIG.MAX_CRAFT_LINES - displayedLineCount)
        SetPanelHeightKeepingBottomLeft(
            state.craft.panel,
            CONFIG.CRAFT_PANEL_EXPANDED_HEIGHT - unusedLineCount * CONFIG.CRAFT_PANEL_LINE_HEIGHT
        )
    else
        SetPanelHeightKeepingBottomLeft(state.craft.panel, CONFIG.CRAFT_PANEL_COLLAPSED_HEIGHT)
    end
    UpdateVendorButtons(summary)

    local nextState = GetPatronNextButtonState()
    if state.craft.nextButton then
        if nextState then
            state.craft.nextButton:SetShown(true)
            local toolArmed = false
            local shatterArmed = false
            local phialArmed = false
            local mergeArmed = false
            local inCombat = InCombatLockdown and InCombatLockdown()
            if not inCombat
                and nextState.enabled
                and nextState.action == "equip_tool"
                and nextState.itemID
            then
                state.craft.nextButton:SetAttribute("type", "item")
                state.craft.nextButton:SetAttribute("item", nextState.itemLink or ("item:" .. tostring(nextState.itemID)))
                state.armedCraftTool = {
                    professionID = nextState.professionID,
                    role = nextState.role,
                    itemID = nextState.itemID,
                    itemLink = nextState.itemLink,
                }
                toolArmed = true
            end
            if not inCombat and not toolArmed
                and nextState.enabled
                and nextState.action == "shatter"
                and nextState.itemID
            then
                -- Shatter is a salvage recipe. CraftSalvage receives the
                -- selected mote location and can consume it from bags or bank.
                state.craft.nextButton:SetAttribute("type", nil)
                state.craft.nextButton:SetAttribute("item", nil)
                state.armedShatter = {
                    itemID = nextState.itemID,
                    expiresAt = GetTime() + 2.0,
                }
                shatterArmed = true
            end
            if not inCombat and not toolArmed
                and not shatterArmed
                and nextState.enabled
                and (nextState.action == "craft_normal" or nextState.action == "craft")
                and nextState.entry
                and YQQuality.GetConcentrationPhialState(nextState.entry)
                and not (state.pendingIngenuityPhial and GetTime() < (state.pendingIngenuityPhial.expiresAt or 0))
            then
                local phialState = YQQuality.GetConcentrationPhialState(nextState.entry)
                local demandItemID = phialState.demandItemID
                local actualItemID = phialState.itemID
                if actualItemID then
                    state.craft.nextButton:SetAttribute("type", "item")
                    state.craft.nextButton:SetAttribute("item", "item:" .. tostring(actualItemID))
                    state.armedIngenuityPhial = {
                        demandItemID = demandItemID or actualItemID,
                        itemID = actualItemID,
                    }
                    phialArmed = true
                end
            end
            if not inCombat and not toolArmed and not phialArmed
                and nextState.enabled
                and nextState.action == "merge"
                and nextState.mergeInputItemID
                and GetImmediateOwnedCount(nextState.mergeInputItemID) >= (nextState.mergeInputQuantity or 1)
            then
                state.craft.nextButton:SetAttribute("type", "item")
                state.craft.nextButton:SetAttribute("item", "item:" .. tostring(nextState.mergeInputItemID))
                state.armedMerge = {
                    mergeKey = nextState.entry.mergeKey,
                    recipeID = nextState.entry.recipeID,
                    inputItemID = nextState.mergeInputItemID,
                    outputItemID = nextState.mergeOutputItemID,
                    inputQuantity = nextState.mergeInputQuantity or 1,
                    outputQuantity = 1,
                    beforeInput = GetImmediateOwnedCount(nextState.mergeInputItemID),
                    beforeOutput = GetImmediateOwnedCount(nextState.mergeOutputItemID),
                }
                mergeArmed = true
            end
            if not inCombat and not toolArmed and not shatterArmed and not phialArmed and not mergeArmed then
                state.craft.nextButton:SetAttribute("type", nil)
                state.craft.nextButton:SetAttribute("item", nil)
                state.armedShatter = nil
                state.armedIngenuityPhial = nil
                state.armedMerge = nil
                state.armedCraftTool = nil
            end
            state.craft.nextButton:SetText(
                toolArmed and (nextState.text or "Next: outil")
                    or (shatterArmed and "Next: Shatter"
                        or (phialArmed and "Next: Phial"
                            or (mergeArmed and "Next: Fusion" or (nextState.text or "Next"))))
            )
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
            if not (InCombatLockdown and InCombatLockdown()) then
                state.craft.nextButton:SetAttribute("type", nil)
                state.craft.nextButton:SetAttribute("item", nil)
                state.armedShatter = nil
                state.armedIngenuityPhial = nil
                state.armedCraftTool = nil
            end
        end
    end

    local statusParts = {}
    if #summary.mailboxTasks > 0 then
        table.insert(statusParts, #summary.mailboxTasks .. " boite")
    end
    if #summary.acquireTasks > 0 then
        table.insert(statusParts, #summary.acquireTasks .. " a acquerir")
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
        PanelTemplates_TabResize(state.ah.tab, 20, nil, 70)
        state.ah.tab:SetWidth(70)
        state.ah.tab.libAHTab:SetSelected(state.ah.tab.libTabID)
        ScheduleRefresh()
        C_Timer.After(0, function()
            if state.ah.frame and state.ah.frame:IsShown() then
            state.OnAuctionActionClick()
            end
        end)
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
    C_Timer.After(0, function()
        if state.ah.frame and state.ah.frame:IsShown() then
            state.OnAuctionActionClick()
        end
    end)
end

function YQQuality.GetExpectedAuctionPrice(itemID, kind)
    local quote = state.auctionPrices and state.auctionPrices.GetQuote(itemID, kind)
    if quote and quote.unitPrice then
        return quote.unitPrice, "auction-snapshot", quote.capturedAt
    end

    local tsmPrice = YQQuality.GetTSMPrice("dbminbuyout", itemID)
    if tsmPrice then
        return tsmPrice, "tsm-dbminbuyout", nil
    end

    tsmPrice = YQQuality.GetTSMPrice("dbmarket", itemID)
    if tsmPrice then
        return tsmPrice, "tsm-dbmarket", nil
    end

    return nil, nil, nil
end

local function CaptureSearchCache(itemID)
    if type(itemID) ~= "number" or itemID <= 0 then
        return
    end

    local kind = IsCommodityItem(itemID) and "commodity" or "item"
    local expectedPrice, expectedSource, expectedCapturedAt = YQQuality.GetExpectedAuctionPrice(itemID, kind)
    local cache = {
        itemID = itemID,
        name = GetItemName(itemID),
        kind = kind,
        available = 0,
        hasResults = false,
        expectedPrice = expectedPrice,
        expectedSource = expectedSource,
        expectedCapturedAt = expectedCapturedAt,
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

    if cache.unitPrice and cache.unitPrice > 0 then
        cache.capturedAt = time and time() or math.floor(GetTime and GetTime() or 0)
        if state.auctionPrices then
            local quote = state.auctionPrices.RecordSearch(itemID, kind, cache.unitPrice)
            if quote then
                cache.capturedAt = quote.capturedAt
            end
        end
        if YQQuality.ClearRecipeCache then
            state.InvalidateMaterialPricing()
        else
            state.craft.qualityPriceCache[itemID] = nil
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

    SetLineText(state.ah.lines, CONFIG.MAX_AH_LINES, lines)
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
    if state.ah.soundCheckbox then
        state.EnsureDB()
        state.ah.soundCheckbox:SetChecked(db.auctionPriceWarningSoundEnabled ~= false)
    end
    state.ah.statusText:SetText(state.ah.statusMessage ~= "" and state.ah.statusMessage or "Pret")
end

function YQQuality.WarnIfAuctionPriceAboveExpected(name, actualPrice, expectedPrice)
    actualPrice = tonumber(actualPrice)
    expectedPrice = tonumber(expectedPrice)
    if not actualPrice or actualPrice <= 0 or not expectedPrice or expectedPrice <= 0
        or actualPrice <= expectedPrice then
        return nil
    end

    local delta = actualPrice - expectedPrice
    local percent = (delta / expectedPrice) * 100
    local message = ("ALERTE prix YQ: %s a %s/u, attendu %s/u (+%s, +%.1f%%)"):format(
        tostring(name or "item"),
        GetMoneyString(math.floor(actualPrice), true),
        GetMoneyString(math.floor(expectedPrice), true),
        GetMoneyString(math.floor(delta), true),
        percent
    )
    Print(message)
    state.EnsureDB()
    if db.auctionPriceWarningSoundEnabled ~= false
        and type(PlaySound) == "function" and type(SOUNDKIT) == "table" and SOUNDKIT.RAID_WARNING then
        pcall(PlaySound, SOUNDKIT.RAID_WARNING)
    end
    return message
end

function YQQuality.GetHighPriceConfirmation(itemID, actualPrice)
    itemID = tonumber(itemID)
    actualPrice = tonumber(actualPrice)
    if not itemID or itemID <= 0 or not actualPrice or actualPrice <= 0 then
        return nil
    end

    local dbrecent = YQQuality.GetTSMPrice("dbrecent", itemID)
    local multiplier = tonumber(CONFIG.AUCTION_HIGH_PRICE_CONFIRM_MULTIPLIER) or 1.5
    local threshold = dbrecent and dbrecent > 0
        and dbrecent * multiplier
        or nil
    if not threshold or actualPrice < threshold then
        return nil
    end

    return {
        actualPrice = actualPrice,
        dbrecent = dbrecent,
        premiumPercent = ((actualPrice / dbrecent) - 1) * 100,
        threshold = threshold,
    }
end

function YQQuality.HideHighPriceConfirmation()
    state.ah.highPriceConfirmation = nil
    if type(StaticPopup_Hide) == "function" then
        StaticPopup_Hide(CONFIG.AUCTION_HIGH_PRICE_CONFIRM_DIALOG)
    end
end

function YQQuality.ShowHighPriceConfirmation(pending)
    if type(pending) ~= "table"
        or type(StaticPopupDialogs) ~= "table"
        or type(StaticPopup_Show) ~= "function"
    then
        return false
    end

    local dialogName = CONFIG.AUCTION_HIGH_PRICE_CONFIRM_DIALOG
    if not StaticPopupDialogs[dialogName] then
        StaticPopupDialogs[dialogName] = {
            text = "%s",
            button1 = "Acheter",
            button2 = "Annuler",
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3,
            OnAccept = function(dialog)
                local current = dialog.data
                if type(current) ~= "table" or state.ah.highPriceConfirmation ~= current then
                    return
                end
                state.ah.highPriceConfirmation = nil

                if current.kind == "commodity" then
                    if state.ah.pendingCommodity ~= current or current.confirmSent then
                        return
                    end
                    current.confirmSent = true
                    C_AuctionHouse.ConfirmCommoditiesPurchase(current.itemID, current.quantity)
                    state.ah.statusMessage = "Confirmation achat " .. current.quantity .. "x " .. current.name
                    ScheduleRefresh()
                    return
                end

                if current.kind == "item" and state.ah.pendingItem == current then
                    YQQuality.PlacePendingItemPurchase(current)
                end
            end,
            OnCancel = function(dialog)
                local current = dialog.data
                if type(current) ~= "table" or state.ah.highPriceConfirmation ~= current then
                    return
                end
                state.ah.highPriceConfirmation = nil

                if current.kind == "commodity" then
                    if type(C_AuctionHouse.CancelCommoditiesPurchase) == "function" then
                        pcall(C_AuctionHouse.CancelCommoditiesPurchase)
                    end
                    if state.ah.pendingCommodity == current then
                        state.ah.pendingCommodity = nil
                    end
                elseif current.kind == "item" and state.ah.pendingItem == current then
                    state.ah.pendingItem = nil
                end
                state.ah.statusMessage = "Achat annule"
                ScheduleRefresh()
            end,
        }
    end

    local quote = pending.highPrice or {}
    local quantity = math.max(1, tonumber(pending.quantity) or 1)
    local unitPrice = tonumber(quote.actualPrice) or 0
    local dbrecent = tonumber(quote.dbrecent) or 0
    local totalPrice = unitPrice * quantity
    local message = ("Prix eleve pour %s : %s/u contre %s/u ( +%.0f%% ).\nConfirmer l'achat de %dx pour %s ?"):format(
        tostring(pending.name or "item"),
        GetMoneyString(math.floor(unitPrice), true),
        GetMoneyString(math.floor(dbrecent), true),
        tonumber(quote.premiumPercent) or 0,
        quantity,
        GetMoneyString(math.floor(totalPrice), true)
    )

    state.ah.highPriceConfirmation = pending
    local dialog = StaticPopup_Show(dialogName, message, nil, pending)
    if not dialog then
        state.ah.highPriceConfirmation = nil
        return false
    end
    return true
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

function YQQuality.GetTSMItemString(item)
    if type(TSM_API) ~= "table"
        or type(TSM_API.ToItemString) ~= "function"
    then
        return nil
    end

    local candidate
    if type(item) == "string" and item ~= "" then
        candidate = item
    elseif type(item) == "number" and item > 0 then
        candidate = select(2, GetItemInfo(item)) or ("i:" .. item)
    end
    if not candidate then return nil end

    local okString, itemString = pcall(TSM_API.ToItemString, candidate)
    if okString and type(itemString) == "string" and itemString ~= "" then
        return itemString
    end
    return nil
end

function YQQuality.GetTSMSourceValue(source, item)
    if type(TSM_API) ~= "table" or type(TSM_API.GetCustomPriceValue) ~= "function" then
        return nil
    end

    local itemString = YQQuality.GetTSMItemString(item)
    if not itemString then return nil end
    local okValue, value = pcall(TSM_API.GetCustomPriceValue, source, itemString)
    if okValue and type(value) == "number" then return value end
    return nil
end

function YQQuality.GetTSMPrice(priceSource, item)
    local price = YQQuality.GetTSMSourceValue(priceSource, item)
    return price and price > 0 and price or nil
end

function YQQuality.GetFallbackItemPrice(itemID)
    YQQuality.RegisterCentralPricing()
    local central = _G.YayaCraftedPriceAPI
    if central and type(central.GetPriceQuote) == "function" then
        local quote = central.GetPriceQuote(itemID, 1, {
            useInventory = false,
            auctionKind = IsCommodityItem(itemID) and "commodity" or "item",
        })
        if quote then
            return {
                unitPrice = quote.amount,
                estimated = quote.estimated == true,
                source = quote.source,
                capturedAt = quote.capturedAt,
            }
        end
    end

    local kind = IsCommodityItem(itemID) and "commodity" or "item"
    local auctionQuote = state.auctionPrices and state.auctionPrices.GetQuote(itemID, kind)
    if auctionQuote and tonumber(auctionQuote.unitPrice) and auctionQuote.unitPrice > 0 then
        return {
            unitPrice = auctionQuote.unitPrice,
            estimated = false,
            source = "auction-snapshot",
            capturedAt = auctionQuote.capturedAt,
        }
    end

    local tsmPrice = YQQuality.GetTSMPrice("vendorbuy", itemID)
    if tsmPrice then
        return { unitPrice = tsmPrice, estimated = false, source = "vendorbuy" }
    end

    tsmPrice = YQQuality.GetTSMPrice("dbminbuyout", itemID)
    if tsmPrice then
        return { unitPrice = tsmPrice, estimated = false, source = "dbminbuyout" }
    end

    tsmPrice = YQQuality.GetTSMPrice("dbmarket", itemID)
    if tsmPrice then
        return { unitPrice = tsmPrice, estimated = true, source = "dbmarket" }
    end

    local containerAPI = _G.YayaContainerValuesAPI
    if containerAPI and type(containerAPI.GetAverageValue) == "function" then
        local ok, price = pcall(containerAPI.GetAverageValue, itemID)
        if ok and type(price) == "number" and price > 0 then
            return { unitPrice = price, estimated = true, source = "container-average" }
        end
    end
    return nil
end

function YQQuality.BuildReservationSignature(reservations)
    local itemIDs = {}
    for itemID in pairs(reservations or {}) do
        itemIDs[#itemIDs + 1] = tonumber(itemID) or 0
    end
    table.sort(itemIDs)
    local parts = {}
    for _, itemID in ipairs(itemIDs) do
        parts[#parts + 1] = tostring(itemID) .. ":" .. tostring(reservations[itemID] or 0)
    end
    return table.concat(parts, ",")
end

function YQQuality.GetQueuedReagentReservations()
    state.EnsureDB()
    local reservations = {}
    local function Reserve(itemID, quantity)
        itemID = tonumber(itemID) or 0
        quantity = math.max(0, tonumber(quantity) or 0)
        if itemID > 0 and quantity > 0 then
            reservations[itemID] = (reservations[itemID] or 0) + quantity
        end
    end

    for _, entry in ipairs(db.queue or {}) do
        if entry.queueKind == "direct_item" then
            if not (entry.concentrationPhial == true and not YQQuality.IsConcentrationPhialEnabled()) then
                Reserve(entry.itemID, entry.directQuantity or 0)
            end
        else
            local craftsRemaining = select(1, GetEntryCraftsRemaining(entry))
            if craftsRemaining > 0 then
                for _, reagent in ipairs(entry.reagents or {}) do
                    Reserve(reagent.itemID, craftsRemaining * (tonumber(reagent.quantity) or 0))
                end
            end
        end
    end
    return reservations
end

function YQQuality.CreateMaterialPriceContext(reservations)
    reservations = reservations or YQQuality.GetQueuedReagentReservations()
    return {
        reservations = reservations,
        reservationSignature = YQQuality.BuildReservationSignature(reservations),
        profiles = {},
    }
end

function YQQuality.GetMaterialPriceProfile(context, itemID)
    local profile = context.profiles[itemID]
    if profile then return profile end

    local smartPrice = YQQuality.GetTSMPrice("SmartAvgBuy", itemID)
    local inventory = math.max(0, math.floor(YQQuality.GetTSMSourceValue("NumInventory", itemID) or 0))
    local reserved = math.max(0, tonumber(context.reservations[itemID]) or 0)
    local fallback = YQQuality.GetFallbackItemPrice(itemID)
    local smartQuantity = smartPrice and math.max(0, inventory - reserved) or 0
    profile = {
        itemID = itemID,
        smartPrice = smartPrice,
        inventory = inventory,
        reserved = reserved,
        smartQuantity = smartQuantity,
        fallback = fallback,
    }
    profile.signature = table.concat({
        tostring(itemID),
        tostring(smartPrice or ""),
        tostring(inventory),
        tostring(reserved),
        tostring(fallback and fallback.source or ""),
        tostring(fallback and fallback.unitPrice or ""),
        tostring(fallback and fallback.capturedAt or ""),
    }, ":")
    context.profiles[itemID] = profile
    return profile
end

function YQQuality.GetMergeDefinition(outputItemID)
    outputItemID = tonumber(outputItemID)
    for _, definition in ipairs(CONFIG.GOLD_STAR_MERGE_CHAIN or {}) do
        if definition.outputItemID == outputItemID then
            return definition
        end
    end
    return nil
end

function YQQuality.GetDirectItemPriceQuote(itemID, quantity, context)
    local profile = YQQuality.GetMaterialPriceProfile(context, itemID)
    local cacheKey = table.concat({
        tostring(itemID), tostring(quantity), profile.signature,
    }, "|")
    local cachedQuote = state.craft.qualityPriceCache[cacheKey]
    if cachedQuote then return cachedQuote end

    local smartQuantity = math.min(quantity, profile.smartQuantity)
    local fallbackQuantity = quantity - smartQuantity
    if fallbackQuantity > 0 and not profile.fallback then
        return nil
    end

    local total = smartQuantity * (profile.smartPrice or 0)
        + fallbackQuantity * (profile.fallback and profile.fallback.unitPrice or 0)
    local usedFallback = fallbackQuantity > 0 and profile.fallback or nil
    local source
    if smartQuantity > 0 and usedFallback then
        source = "smartAvgBuy+" .. usedFallback.source
    elseif smartQuantity > 0 then
        source = "smartAvgBuy"
    else
        source = usedFallback and usedFallback.source or nil
    end
    local quote = {
        amount = total / quantity,
        total = total,
        estimated = usedFallback and usedFallback.estimated == true or false,
        source = source,
        capturedAt = usedFallback and usedFallback.capturedAt or nil,
        smartQuantity = smartQuantity,
        fallbackQuantity = fallbackQuantity,
        pricingKey = profile.signature,
    }
    state.craft.qualityPriceCache[cacheKey] = quote
    return quote
end

function YQQuality.GetItemPriceQuote(itemID, quantity, priceContext)
    itemID = tonumber(itemID)
    quantity = math.max(1, math.floor(tonumber(quantity) or 1))
    if not itemID or itemID <= 0 then return nil end

    local context = priceContext or YQQuality.CreateMaterialPriceContext()
    local merge = YQQuality.GetMergeDefinition(itemID)
    YQQuality.RegisterCentralPricing()
    local central = _G.YayaCraftedPriceAPI
    if not merge and central and type(central.GetPriceQuote) == "function" then
        local quote = central.GetPriceQuote(itemID, quantity, {
            reservations = context.reservations,
            useInventory = true,
            auctionKind = IsCommodityItem(itemID) and "commodity" or "item",
        })
        if quote then
            local cacheKey = table.concat({
                tostring(itemID),
                tostring(quantity),
                tostring(quote.pricingKey or ""),
            }, "|")
            local cachedQuote = state.craft.qualityPriceCache[cacheKey]
            if cachedQuote then return cachedQuote end
            state.craft.qualityPriceCache[cacheKey] = quote
            return quote
        end
    end

    if merge then
        if itemID == CONFIG.GOLD_STAR_ITEM_ID then
            local available = YQQuality.GetAvailableCharacterGoldStars(context)
            local missing = math.max(0, quantity - available)
            if missing == 0 then
                return {
                    amount = 0,
                    total = 0,
                    estimated = false,
                    source = "characterGoldStar",
                    pricingKey = "characterGoldStar:" .. tostring(available),
                    mergePlan = { steps = {} },
                }
            end

            local previous = YQQuality.GetItemPriceQuote(
                merge.inputItemID,
                missing * merge.inputQuantity,
                context
            )
            if not previous then return nil end

            local steps = {}
            for _, step in ipairs(previous.mergePlan and previous.mergePlan.steps or {}) do
                steps[#steps + 1] = step
            end
            steps[#steps + 1] = {
                inputItemID = merge.inputItemID,
                outputItemID = merge.outputItemID,
                inputQuantity = merge.inputQuantity,
                quantity = missing,
                recipeID = merge.recipeID,
                name = merge.name,
            }
            return {
                amount = previous.total / quantity,
                total = previous.total,
                estimated = previous.estimated == true,
                source = "merge:" .. tostring(itemID),
                capturedAt = previous.capturedAt,
                pricingKey = "merge:" .. tostring(itemID) .. ":characterGoldStar:" .. tostring(available) .. ":" .. tostring(previous.pricingKey),
                mergePlan = { steps = steps },
            }
        end

        local direct = itemID ~= CONFIG.GOLD_STAR_ITEM_ID
            and YQQuality.GetDirectItemPriceQuote(itemID, quantity, context)
            or nil
        local previous = YQQuality.GetItemPriceQuote(
            merge.inputItemID,
            quantity * merge.inputQuantity,
            context
        )
        local merged
        if previous then
            local steps = {}
            for _, step in ipairs(previous.mergePlan and previous.mergePlan.steps or {}) do
                steps[#steps + 1] = step
            end
            steps[#steps + 1] = {
                inputItemID = merge.inputItemID,
                outputItemID = merge.outputItemID,
                inputQuantity = merge.inputQuantity,
                quantity = quantity,
                recipeID = merge.recipeID,
                name = merge.name,
            }
            merged = {
                amount = previous.total / quantity,
                total = previous.total,
                estimated = previous.estimated == true,
                source = "merge:" .. tostring(itemID),
                capturedAt = previous.capturedAt,
                pricingKey = "merge:" .. tostring(itemID) .. ":" .. tostring(previous.pricingKey),
                mergePlan = { steps = steps },
            }
        end
        if direct and (not merged or direct.total <= merged.total) then
            return direct
        end
        return merged
    end

    return YQQuality.GetDirectItemPriceQuote(itemID, quantity, context)
end

function YQQuality.GetItemPrice(itemID)
    local quote = YQQuality.GetItemPriceQuote(itemID)
    return quote and quote.amount or nil
end

function YQQuality.BuildItemCostCurve(itemID, maxQuantity, priceContext)
    maxQuantity = math.max(1, math.floor(tonumber(maxQuantity) or 1))
    local firstQuote = YQQuality.GetItemPriceQuote(itemID, 1, priceContext)
    if not firstQuote then return nil, nil, nil end
    local fullQuote = maxQuantity == 1
        and firstQuote or YQQuality.GetItemPriceQuote(itemID, maxQuantity, priceContext)
    local fullTotal = tonumber(fullQuote and fullQuote.total)
    local smartQuantity = tonumber(fullQuote and fullQuote.smartQuantity)
    local fallbackQuantity = tonumber(fullQuote and fullQuote.fallbackQuantity)
    if not fullTotal or fullTotal < 0 or not smartQuantity or not fallbackQuantity then
        return nil, firstQuote, fullQuote
    end
    smartQuantity = math.max(0, math.floor(smartQuantity))
    fallbackQuantity = math.max(0, math.floor(fallbackQuantity))
    if smartQuantity + fallbackQuantity ~= maxQuantity then return nil, firstQuote, fullQuote end

    local tiers = {}
    local smartUnitPrice
    if smartQuantity > 0 then
        if tonumber(firstQuote.smartQuantity) ~= 1 then return nil, firstQuote, fullQuote end
        smartUnitPrice = tonumber(firstQuote.total)
        if not smartUnitPrice or smartUnitPrice < 0 then return nil, firstQuote, fullQuote end
        tiers[#tiers + 1] = {
            upTo = smartQuantity,
            unitPrice = smartUnitPrice,
            estimated = false,
        }
    end
    if fallbackQuantity > 0 then
        local fallbackTotal = fullTotal - smartQuantity * (smartUnitPrice or 0)
        local fallbackUnitPrice = fallbackTotal / fallbackQuantity
        if fallbackUnitPrice < 0 then return nil, firstQuote, fullQuote end
        tiers[#tiers + 1] = {
            upTo = maxQuantity,
            unitPrice = fallbackUnitPrice,
            estimated = fullQuote.estimated == true,
        }
    end
    if #tiers == 0 then return nil, firstQuote, fullQuote end

    return {
        tiers = tiers,
        maxQuantity = maxQuantity,
        total = fullTotal,
        signature = table.concat({
            tostring(firstQuote.pricingKey or ""),
            tostring(fullQuote.pricingKey or ""),
            tostring(smartQuantity),
            tostring(fallbackQuantity),
            tostring(smartUnitPrice or ""),
            tostring(tiers[#tiers].unitPrice or ""),
        }, ":"),
    }, firstQuote, fullQuote
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

function YQQuality.CopyOptionalSelections(selections)
    local copy = {}
    for slotIndex, itemID in pairs(selections or {}) do
        slotIndex = tonumber(slotIndex)
        itemID = tonumber(itemID)
        if slotIndex and slotIndex > 0 and itemID and itemID > 0 then
            copy[slotIndex] = itemID
        end
    end
    return copy
end

function YQQuality.GetOptionalReagentPriority(itemName, isGathering)
    local name = string.lower(tostring(itemName or ""))
    local function Has(text)
        return string.find(name, text, 1, true) ~= nil
    end

    if isGathering then
        if Has("perception") then return 10 end
        if Has("finesse") then return 20 end
        return 90
    end
    if Has("multicraft") or Has("fabrication multiple") then return 10 end
    if Has("resourcefulness") or Has("ressource") or Has("economie de ressources") or Has("économie de ressources") then return 20 end
    if Has("ingenuity") or Has("ingeniosite") or Has("ingéniosité") then return 30 end
    if Has("crafting speed") or Has("vitesse de fabrication") then return 40 end
    if Has("missive") then return 50 end
    return nil
end

function YQQuality.IsFinishingSlot(slot)
    local reagentTypes = Enum and Enum.CraftingReagentType
    local finishingType = reagentTypes and tonumber(reagentTypes.Finishing) or 2
    return tonumber(slot and slot.reagentType) == finishingType
end

function YQQuality.IsOptionalSlotUnlocked(slot, recipeInfo)
    local mcrSlotID = slot and slot.slotInfo and slot.slotInfo.mcrSlotID
    if not mcrSlotID or not recipeInfo or not recipeInfo.recipeID
        or type(C_TradeSkillUI.GetReagentSlotStatus) ~= "function" then
        return true
    end
    local skillLineID = type(C_TradeSkillUI.GetProfessionChildSkillLineID) == "function"
        and SafeCall(C_TradeSkillUI.GetProfessionChildSkillLineID) or nil
    if not skillLineID then return true end
    local locked = SafeCall(
        C_TradeSkillUI.GetReagentSlotStatus,
        mcrSlotID,
        recipeInfo.recipeID,
        skillLineID
    )
    return locked ~= true
end

function YQQuality.BuildOptionalSlots(recipeInfo, schematic)
    local rawSlots = {}
    local hasGatheringStat = recipeInfo and recipeInfo.isGatheringRecipe == true
    for _, slot in ipairs(schematic and schematic.reagentSlotSchematics or {}) do
        local slotIndex = tonumber(slot.dataSlotIndex)
        local isFinishing = YQQuality.IsFinishingSlot(slot)
        if slotIndex and slotIndex > 0
            and slot.required == false
            and type(slot.reagents) == "table"
            and #slot.reagents > 0
            and (not isFinishing or YQQuality.IsOptionalSlotUnlocked(slot, recipeInfo))
        then
            local options = {}
            local seen = {}
            for _, reagent in ipairs(slot.reagents or {}) do
                local itemID = tonumber(reagent.itemID)
                if itemID and itemID > 0 and not seen[itemID] then
                    seen[itemID] = true
                    WarmItemData(itemID)
                    local itemName = GetItemName(itemID)
                    local normalPriority = YQQuality.GetOptionalReagentPriority(itemName, false)
                    local gatheringPriority = YQQuality.GetOptionalReagentPriority(itemName, true)
                    if isFinishing or normalPriority or gatheringPriority < 90 then
                        hasGatheringStat = hasGatheringStat or gatheringPriority < 90
                        local quality = tonumber(reagent.reagentQuality or reagent.quality or reagent.qualityID) or 0
                        if quality <= 0 and C_TradeSkillUI.GetItemReagentQualityByItemInfo then
                            quality = tonumber(SafeCall(C_TradeSkillUI.GetItemReagentQualityByItemInfo, itemID)) or 0
                        end
                        options[#options + 1] = {
                            itemID = itemID,
                            itemName = itemName,
                            quality = quality,
                            normalPriority = normalPriority,
                            gatheringPriority = gatheringPriority,
                            isMissive = string.find(string.lower(tostring(itemName or "")), "missive", 1, true) ~= nil,
                            isFinishing = isFinishing,
                            isGoldStar = itemID == 246450,
                        }
                    end
                end
            end
            if #options > 0 then
                rawSlots[#rawSlots + 1] = { slot = slot, options = options }
            end
        end
    end

    local slots = {}
    for _, slotData in ipairs(rawSlots) do
        local options = {}
        for _, option in ipairs(slotData.options) do
            option.priority = option.isFinishing and 60
                or (hasGatheringStat and option.gatheringPriority or option.normalPriority)
            if option.priority then
                options[#options + 1] = option
            end
        end
        if #options > 0 then
            slots[#slots + 1] = { slot = slotData.slot, options = options }
        end
    end
    table.sort(slots, function(left, right)
        return tonumber(left.slot.dataSlotIndex) < tonumber(right.slot.dataSlotIndex)
    end)
    for _, slotData in ipairs(slots) do
        table.sort(slotData.options, function(left, right)
            if left.priority ~= right.priority then return left.priority < right.priority end
            if left.quality ~= right.quality then return left.quality < right.quality end
            return left.itemName < right.itemName
        end)
    end
    return slots
end

function YQQuality.ApplyOptionalSelections(reagents, optionalSlots, selections)
    local result = YQQuality.CopyReagents(reagents)
    for _, slotData in ipairs(optionalSlots or {}) do
        local slot = slotData.slot
        local itemID = tonumber(selections and selections[tonumber(slot.dataSlotIndex)])
        result = YQQuality.ReplaceReagent(result, slot, nil)
        if itemID and itemID > 0 then
            result = YQQuality.ReplaceReagent(result, slot, {
                { itemID = itemID, quantity = math.max(1, tonumber(slot.quantityRequired) or 1) },
            })
        end
    end
    return result
end

function YQQuality.GetSelectionOption(optionalSlots, slotIndex, itemID)
    for _, slotData in ipairs(optionalSlots or {}) do
        if tonumber(slotData.slot and slotData.slot.dataSlotIndex) == tonumber(slotIndex) then
            for _, option in ipairs(slotData.options or {}) do
                if tonumber(option.itemID) == tonumber(itemID) then
                    return option
                end
            end
        end
    end
    return nil
end

function YQQuality.GetOperationSkill(operation)
    return (tonumber(operation and operation.baseSkill) or 0)
        + (tonumber(operation and operation.bonusSkill) or 0)
end

function YQQuality.GetCraftSimReagentWeight(itemID)
    local api = _G.CraftSimAPI
    local craftSim = api and type(api.GetCraftSim) == "function"
        and SafeCall(api.GetCraftSim, api) or nil
    local reagentOptimizer = craftSim and craftSim.REAGENT_OPTIMIZATION
    local weight = reagentOptimizer and type(reagentOptimizer.GetReagentWeightByID) == "function"
        and SafeCall(reagentOptimizer.GetReagentWeightByID, reagentOptimizer, itemID) or nil
    weight = tonumber(weight)
    return weight and weight > 0 and math.floor(weight) or nil
end

function YQQuality.OwnsGoldStar()
    local count
    if type(C_Item) == "table" and type(C_Item.GetItemCount) == "function" then
        count = SafeCall(C_Item.GetItemCount, 246450, true)
    elseif type(GetItemCount) == "function" then
        count = SafeCall(GetItemCount, 246450, true)
    end
    return math.max(0, tonumber(count) or 0)
end

function YQQuality.GetAvailableCharacterGoldStars(priceContext)
    local reservations = priceContext and priceContext.reservations or {}
    local reserved = math.max(0, tonumber(reservations[CONFIG.GOLD_STAR_ITEM_ID]) or 0)
    -- GetItemCount only covers the current character (bags and personal bank),
    -- never the Warband bank. Gold Stars must be available to this character.
    return math.max(0, YQQuality.OwnsGoldStar() - reserved)
end

function YQQuality.IsSkillFinishingOption(form, recipeInfo, schematic, optionalSlots, selections, slot, itemID)
    local transaction = form and ((type(form.GetTransaction) == "function" and SafeCall(form.GetTransaction, form)) or form.transaction) or nil
    local recipeID = tonumber(recipeInfo and recipeInfo.recipeID)
    if not transaction or not recipeID then return nil end
    local allocationGUID = type(transaction.GetAllocationItemGUID) == "function"
        and SafeCall(transaction.GetAllocationItemGUID, transaction) or nil
    local reagents = type(transaction.CreateCraftingReagentInfoTbl) == "function"
        and SafeCall(transaction.CreateCraftingReagentInfoTbl, transaction) or {}
    if type(reagents) ~= "table" then return nil end
    reagents = AddVisibleRequiredReagents(form, schematic, reagents, transaction)
    reagents = YQQuality.FilterOperationReagents(schematic, reagents)
    for _, slotData in ipairs(optionalSlots or {}) do
        if slotData.options[1] and slotData.options[1].isFinishing then
            reagents = YQQuality.ReplaceReagent(reagents, slotData.slot, {})
        end
    end
    local base = YQQuality.ApplyOptionalSelections(reagents, optionalSlots, selections)
    local before = SafeCall(C_TradeSkillUI.GetCraftingOperationInfo, recipeID, base, allocationGUID, false)
    local withSelection = YQQuality.CopyOptionalSelections(selections)
    withSelection[tonumber(slot.dataSlotIndex)] = itemID
    local withFinishing = YQQuality.ApplyOptionalSelections(reagents, optionalSlots, withSelection)
    local after = SafeCall(C_TradeSkillUI.GetCraftingOperationInfo, recipeID, withFinishing, allocationGUID, false)
    if not before or not after then return nil end
    return after and YQQuality.GetOperationSkill(after) > YQQuality.GetOperationSkill(before)
end

function YQQuality.BuildOptionalPlans(form, recipeInfo, schematic, selections, useFinishing, useGoldStar, yieldWork)
    local optionalSlots = YQQuality.BuildOptionalSlots(recipeInfo, schematic)
    local baseSelections = YQQuality.CopyOptionalSelections(selections)
    for _, slotData in ipairs(optionalSlots) do
        if slotData.options[1] and slotData.options[1].isFinishing then
            baseSelections[tonumber(slotData.slot.dataSlotIndex)] = nil
        end
    end
    local plans = { baseSelections }
    if not useFinishing then return optionalSlots, plans, true end
    local complete = true

    local function Expand(slotIndex, choices)
        local expanded = {}
        for _, plan in ipairs(plans) do
            for _, itemID in ipairs(choices) do
                local copy = YQQuality.CopyOptionalSelections(plan)
                copy[slotIndex] = itemID or nil
                expanded[#expanded + 1] = copy
            end
        end
        plans = expanded
    end

    for _, slotData in ipairs(optionalSlots) do
        local slotIndex = tonumber(slotData.slot.dataSlotIndex)
        local selectedItemID = baseSelections[slotIndex]
        local selectedOption = YQQuality.GetSelectionOption(optionalSlots, slotIndex, selectedItemID)
        if slotData.options[1] and slotData.options[1].isFinishing then
            local choices = { false }
            for _, option in ipairs(slotData.options) do
                local isEligible = not option.isGoldStar or useGoldStar
                local addsSkill = false
                if isEligible then
                    addsSkill = YQQuality.IsSkillFinishingOption(
                        form, recipeInfo, schematic, optionalSlots, baseSelections, slotData.slot, option.itemID
                    )
                end
                if addsSkill == nil then
                    complete = false
                elseif addsSkill then
                    choices[#choices + 1] = option.itemID
                end
                if yieldWork then yieldWork() end
            end
            Expand(slotIndex, choices)
        elseif selectedOption and selectedOption.isMissive then
            local choices = {}
            for _, option in ipairs(slotData.options) do
                if option.isMissive and option.itemName == selectedOption.itemName then
                    choices[#choices + 1] = option.itemID
                end
            end
            if #choices > 0 then Expand(slotIndex, choices) end
        end
    end
    return optionalSlots, plans, complete
end

function YQQuality.BuildCacheKey(recipeID, recipeLevel, useConcentration, allocationGUID, baseline, slots, pricingSignature)
    local optimizedSlots = {}
    local parts = {
        tostring(recipeID),
        tostring(recipeLevel or ""),
        useConcentration == true and "1" or "0",
        tostring(allocationGUID or ""),
    }
    for _, slotData in ipairs(slots or {}) do
        local slotIndex = tonumber(slotData.slot and slotData.slot.dataSlotIndex)
        if slotIndex then optimizedSlots[slotIndex] = true end
        parts[#parts + 1] = "s:" .. tostring(slotIndex or "")
            .. ":" .. tostring(slotData.slot and slotData.slot.quantityRequired or "")
        for _, option in ipairs(slotData.options or {}) do
            parts[#parts + 1] = "o:" .. tostring(option.itemID or "")
                .. ":" .. tostring(option.quality or "")
                .. ":" .. tostring(option.price or "?")
                .. ":" .. tostring(option.pricingKey or "")
        end
    end
    local fixedReagents = {}
    for _, info in ipairs(baseline or {}) do
        local slotIndex = tonumber(info.dataSlotIndex)
        if not optimizedSlots[slotIndex] then
            fixedReagents[#fixedReagents + 1] = table.concat({
                tostring(slotIndex or ""),
                tostring(info.reagent and info.reagent.itemID or ""),
                tostring(info.reagent and info.reagent.currencyID or ""),
                tostring(info.quantity or 0),
            }, ":")
        end
    end
    table.sort(fixedReagents)
    for _, signature in ipairs(fixedReagents) do
        parts[#parts + 1] = "r:" .. signature
    end
    parts[#parts + 1] = "p:" .. tostring(pricingSignature or "")
    return table.concat(parts, "|")
end

function YQQuality.GetCachedRecipeState(recipeID, cacheKey)
    local cache = state.craft.qualityCache
    if type(cache) ~= "table" then
        cache = { entries = {}, order = {}, count = 0 }
        state.craft.qualityCache = cache
    end
    return cache.entries[cacheKey], cache
end

function YQQuality.CacheRecipeState(cache, cacheKey, recipeState)
    if not cache.entries[cacheKey] then
        if cache.count >= 128 then
            local oldestKey = table.remove(cache.order, 1)
            if oldestKey then
                cache.entries[oldestKey] = nil
                cache.count = math.max(0, cache.count - 1)
            end
        end
        cache.count = cache.count + 1
        cache.order[#cache.order + 1] = cacheKey
    end
    cache.entries[cacheKey] = recipeState
end

function YQQuality.CancelRecipeSolve()
    state.craft.qualityState = nil
    state.craft.qualitySolveGeneration = (state.craft.qualitySolveGeneration or 0) + 1
    state.craft.qualitySolve = nil
    state.craft.qualityPreviewGeneration = (state.craft.qualityPreviewGeneration or 0) + 1
    state.craft.qualityPreviewStates = {}
    state.craft.qualityPreviewPending = {}
    state.craft.qualityPreviewSolve = nil
    state.craft.qualityPreviewQueue = {}
end

function YQQuality.ClearRecipeCache(clearPrices)
    state.craft.qualityCache = nil
    state.craft.qualitySelectionCache = nil
    YQQuality.CancelRecipeSolve()
    if clearPrices then
        state.craft.qualityPriceCache = {}
        state.craft.qualityPriceRevision = (state.craft.qualityPriceRevision or 0) + 1
    end
end

function YQQuality.GetCachedSelectionState(selectionKey)
    local cache = state.craft.qualitySelectionCache
    if type(cache) ~= "table" then
        cache = { entries = {}, order = {}, count = 0 }
        state.craft.qualitySelectionCache = cache
    end
    return cache.entries[selectionKey], cache
end

function YQQuality.CacheSelectionState(cache, selectionKey, recipeState)
    if not cache.entries[selectionKey] then
        if cache.count >= 128 then
            local oldestKey = table.remove(cache.order, 1)
            if oldestKey then
                cache.entries[oldestKey] = nil
                cache.count = math.max(0, cache.count - 1)
            end
        end
        cache.count = cache.count + 1
        cache.order[#cache.order + 1] = selectionKey
    end
    cache.entries[selectionKey] = recipeState
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

function YQQuality.GetPredictedQuality(maxQuality, skill, difficulty)
    local thresholds = maxQuality == 5 and { 0, 0.2, 0.5, 0.8, 1 }
        or (maxQuality == 3 and { 0, 0.5, 1 })
        or (maxQuality == 2 and { 0, 1 })
        or nil
    if not thresholds or difficulty <= 0 then return nil end
    local quality = 1
    for index = 2, #thresholds do
        if skill + 0.000001 >= difficulty * thresholds[index] then
            quality = index
        end
    end
    return math.min(maxQuality, quality)
end

function YQQuality.BuildOptimizerReagents(baseline, slots, optimizerState)
    local path = {}
    local cursor = optimizerState
    while type(cursor) == "table" and cursor.choice do
        path[cursor.groupIndex] = cursor.choice
        cursor = cursor.previous
    end
    local reagents = YQQuality.CopyReagents(baseline)
    for slotIndex, slotData in ipairs(slots or {}) do
        local choice = path[slotIndex]
        if choice then
            reagents = YQQuality.ReplaceReagent(reagents, slotData.slot, choice.allocations)
        end
    end
    return reagents
end

function YQQuality.GetCandidateItemQuantity(candidate, itemID)
    local quantity = 0
    for _, info in ipairs(candidate and candidate.reagents or {}) do
        if tonumber(info.reagent and info.reagent.itemID) == tonumber(itemID) then
            quantity = quantity + math.max(0, tonumber(info.quantity) or 0)
        end
    end
    return quantity
end

function YQQuality.IsCandidateDominated(candidate, other)
    if candidate.quality ~= other.quality then return false end
    local candidateCost = tonumber(candidate.totalCost or candidate.cost) or math.huge
    local otherCost = tonumber(other.totalCost or other.cost) or math.huge
    local candidateGoldStar = YQQuality.GetCandidateItemQuantity(candidate, 246450)
    local otherGoldStar = YQQuality.GetCandidateItemQuantity(other, 246450)
    if otherCost > candidateCost
        or otherGoldStar > candidateGoldStar then return false end
    if otherCost < candidateCost
        or otherGoldStar < candidateGoldStar then return true end
    return other.estimated ~= true or candidate.estimated == true
end

function YQQuality.InsertParetoCandidate(candidates, candidate)
    for _, current in ipairs(candidates) do
        if YQQuality.IsCandidateDominated(candidate, current) then return false end
    end
    for index = #candidates, 1, -1 do
        if YQQuality.IsCandidateDominated(candidates[index], candidate) then
            table.remove(candidates, index)
        end
    end
    candidates[#candidates + 1] = candidate
    return true
end

function YQQuality.GetOptimizerFrontier(
    optimizerResult, maxQuality, baselineSkill, difficulty, useConcentration, weightToSkill
)
    local buckets = {}
    weightToSkill = tonumber(weightToSkill) or 0.000001
    for _, optimizerState in ipairs(optimizerResult and optimizerResult.states or {}) do
        local baseQuality = YQQuality.GetPredictedQuality(
            maxQuality,
            baselineSkill + ((tonumber(optimizerState.weight) or 0) * weightToSkill),
            difficulty
        )
        local predictedQuality = useConcentration
            and baseQuality and baseQuality < maxQuality and (baseQuality + 1)
            or (not useConcentration and baseQuality or nil)
        if predictedQuality then
            optimizerState.baseQuality = baseQuality
            buckets[predictedQuality] = buckets[predictedQuality] or {}
            buckets[predictedQuality][#buckets[predictedQuality] + 1] = optimizerState
        end
    end

    local frontier = {}
    local included = {}
    local function AddFrontierState(optimizerState, predictedQuality)
        if included[optimizerState] then return end
        included[optimizerState] = true
        optimizerState.predictedQuality = predictedQuality
        frontier[#frontier + 1] = optimizerState
    end
    for predictedQuality, states in pairs(buckets) do
        local minimumWeightState = states[1]
        local maximumWeightState = states[1]
        for _, optimizerState in ipairs(states) do
            if optimizerState.weight < minimumWeightState.weight then minimumWeightState = optimizerState end
            if optimizerState.weight > maximumWeightState.weight then maximumWeightState = optimizerState end
        end
        table.sort(states, function(left, right)
            if left.cost ~= right.cost then return left.cost < right.cost end
            if left.estimated ~= right.estimated then return left.estimated ~= true end
            return left.signature < right.signature
        end)
        AddFrontierState(states[1], predictedQuality)
        AddFrontierState(minimumWeightState, predictedQuality)
        AddFrontierState(maximumWeightState, predictedQuality)
    end
    return frontier
end

function YQQuality.BuildRecipeState(form, useConcentration, optionalSelections, yieldWork)
    local optimizer = state.addonTable and state.addonTable.QualityOptimizer
    local recipeInfo = form and type(form.GetRecipeInfo) == "function" and SafeCall(form.GetRecipeInfo, form) or nil
    local transaction = form and ((type(form.GetTransaction) == "function" and SafeCall(form.GetTransaction, form)) or form.transaction) or nil
    local recipeID = recipeInfo and tonumber(recipeInfo.recipeID)
    if not optimizer or not recipeID or not transaction or type(C_TradeSkillUI) ~= "table"
        or type(C_TradeSkillUI.GetCraftingOperationInfo) ~= "function" then return nil end

    local level = type(form.GetCurrentRecipeLevel) == "function" and SafeCall(form.GetCurrentRecipeLevel, form) or nil
    local schematic = SafeCall(C_TradeSkillUI.GetRecipeSchematic, recipeID, false, level)
    local base = type(transaction.CreateCraftingReagentInfoTbl) == "function"
        and SafeCall(transaction.CreateCraftingReagentInfoTbl, transaction) or {}
    if type(schematic) ~= "table" or type(base) ~= "table" then return nil end
    base = AddVisibleRequiredReagents(form, schematic, base, transaction)
    base = YQQuality.FilterOperationReagents(schematic, base)
    local optionalSlots = YQQuality.BuildOptionalSlots(recipeInfo, schematic)
    for _, slotData in ipairs(optionalSlots) do
        if slotData.options[1] and slotData.options[1].isFinishing then
            base = YQQuality.ReplaceReagent(base, slotData.slot, {})
        end
    end
    base = YQQuality.ApplyOptionalSelections(base, optionalSlots, optionalSelections)
    local priceContext = YQQuality.CreateMaterialPriceContext()

    local result = {
        recipeID = recipeID,
        recipeName = recipeInfo.name or ("Recette " .. recipeID),
        slots = {},
        optionalSlots = optionalSlots,
        optionalSelections = YQQuality.CopyOptionalSelections(optionalSelections),
        candidates = {},
        minQuality = math.huge,
        maxQuality = tonumber(recipeInfo.maxQuality) or 0,
        reachableQuality = 0,
        reagentQualityCount = 0,
        recipeInfo = recipeInfo,
        schematic = schematic,
        optimizerVersion = 3,
    }
    local allocationGUID = type(transaction.GetAllocationItemGUID) == "function"
        and SafeCall(transaction.GetAllocationItemGUID, transaction) or nil
    result.allocationGUID = allocationGUID

    for _, slot in ipairs(schematic.reagentSlotSchematics or {}) do
        local required = math.max(1, math.floor((tonumber(slot.quantityRequired) or 1) + 0.5))
        local bestByQuality = {}
        for _, reagent in ipairs(slot.reagents or {}) do
            local itemID = tonumber(reagent.itemID)
            local quality = tonumber(reagent.reagentQuality or reagent.quality or reagent.qualityID) or 0
            if quality <= 0 and itemID and C_TradeSkillUI.GetItemReagentQualityByItemInfo then
                quality = tonumber(SafeCall(C_TradeSkillUI.GetItemReagentQualityByItemInfo, itemID)) or 0
            end
            if tonumber(slot.reagentType) == 1 and itemID and itemID > 0 and quality > 0 then
                local costCurve, quote, requiredQuote = YQQuality.BuildItemCostCurve(itemID, required, priceContext)
                local option = {
                    itemID = itemID,
                    quality = quality,
                    price = quote and quote.amount or nil,
                    requiredCost = tonumber(requiredQuote and requiredQuote.total),
                    estimated = requiredQuote and requiredQuote.estimated == true or false,
                    pricingKey = costCurve and costCurve.signature or (requiredQuote and requiredQuote.pricingKey or nil),
                    costCurve = costCurve,
                }
                if not costCurve then
                    option.costForQuantity = function(quantity)
                        local costQuote = YQQuality.GetItemPriceQuote(itemID, quantity, priceContext)
                        return costQuote and costQuote.total or nil,
                            costQuote and costQuote.estimated == true or false
                    end
                end
                local current = bestByQuality[quality]
                if not current
                    or (option.requiredCost and not current.requiredCost)
                    or (
                        option.requiredCost
                        and current.requiredCost
                        and option.requiredCost < current.requiredCost
                    )
                    or (
                        option.requiredCost == current.requiredCost
                        and option.estimated ~= current.estimated
                        and not option.estimated
                    )
                    or (
                        option.requiredCost == current.requiredCost
                        and option.estimated == current.estimated
                        and option.itemID < current.itemID
                    ) then
                    bestByQuality[quality] = option
                end
            end
        end
        local options = {}
        for _, option in pairs(bestByQuality) do options[#options + 1] = option end
        table.sort(options, function(left, right) return left.quality < right.quality end)
        if #options > 1 then
            local tierCount = tonumber(options[#options].quality) or #options
            local slotData = {
                slot = slot,
                options = options,
                required = required,
                tierCount = tierCount,
            }
            result.slots[#result.slots + 1] = slotData
            result.reagentQualityCount = math.max(result.reagentQualityCount, tierCount)
        end
    end

    local baseline = YQQuality.CopyReagents(base)
    for _, slotData in ipairs(result.slots) do
        if slotData.tierCount ~= 2 and slotData.tierCount ~= 3 then
            result.exactUnavailableReason = "nombre de rangs non pris en charge"
            return result
        end
        local lowOption = slotData.options[1]
        if not lowOption or lowOption.quality ~= 1 then
            result.exactUnavailableReason = "rang de réactif manquant"
            return result
        end
        for quality = 1, slotData.tierCount do
            if not slotData.options[quality] or slotData.options[quality].quality ~= quality
                or not slotData.options[quality].price then
                result.exactUnavailableReason = "prix de réactif manquant"
                return result
            end
        end
        baseline = YQQuality.ReplaceReagent(baseline, slotData.slot, {
            { itemID = lowOption.itemID, quantity = slotData.required, quality = 1 },
        })
    end

    local cacheKey = YQQuality.BuildCacheKey(
        recipeID,
        level,
        useConcentration,
        allocationGUID,
        baseline,
        result.slots,
        priceContext.reservationSignature
    )
    local cachedState, qualityCache = YQQuality.GetCachedRecipeState(recipeID, cacheKey)
    if cachedState then
        cachedState.recipeInfo = recipeInfo
        cachedState.schematic = schematic
        DebugPrint("quality-cache hit recipe=" .. tostring(recipeID))
        return cachedState
    end

    local baselineOperation = SafeCall(
        C_TradeSkillUI.GetCraftingOperationInfo, recipeID, baseline, allocationGUID, false
    )
    if not baselineOperation then
        result.exactUnavailableReason = "oracle Blizzard indisponible"
        return result
    end
    local baselineSkill = YQQuality.GetOperationSkill(baselineOperation)
    local difficulty = tonumber(baselineOperation.baseDifficulty) or 0
    local groups = {}
    local allMaximumReagents = YQQuality.CopyReagents(baseline)
    local maximumScore = 0

    for _, slotData in ipairs(result.slots) do
        local reagentWeight = YQQuality.GetCraftSimReagentWeight(slotData.options[1].itemID)
        if not reagentWeight and #result.slots == 1 then reagentWeight = 1 end
        if not reagentWeight then
            result.exactUnavailableReason = "poids de réactif CraftSim indisponible"
            return result
        end
        slotData.weightPerPoint = reagentWeight
        local maximumOption = slotData.options[slotData.tierCount]
        local maximumAllocations = {
            {
                itemID = maximumOption.itemID,
                quantity = slotData.required,
                quality = slotData.tierCount,
            },
        }
        local maximumPoints = (slotData.tierCount - 1) * slotData.required
        maximumScore = maximumScore + (reagentWeight * maximumPoints)
        allMaximumReagents = YQQuality.ReplaceReagent(
            allMaximumReagents, slotData.slot, maximumAllocations
        )
    end

    local allMaximumOperation = SafeCall(
        C_TradeSkillUI.GetCraftingOperationInfo,
        recipeID,
        allMaximumReagents,
        allocationGUID,
        false
    )
    if not allMaximumOperation then
        result.exactUnavailableReason = "oracle Blizzard indisponible"
        return result
    end
    local maximumSkillBonus = math.max(
        0, YQQuality.GetOperationSkill(allMaximumOperation) - baselineSkill
    )

    for _, slotData in ipairs(result.slots) do
        local maximumPoints = (slotData.tierCount - 1) * slotData.required
        slotData.maximumSkillBonus = maximumScore > 0
            and (maximumSkillBonus * slotData.weightPerPoint * maximumPoints / maximumScore)
            or 0
        for quality = 2, slotData.tierCount do
            local option = slotData.options[quality]
            local counts = { 1, math.max(1, slotData.required - 1), slotData.required }
            local seenCounts = {}
            for _, highCount in ipairs(counts) do
                if not seenCounts[highCount] then
                    seenCounts[highCount] = true
                    local allocations = {
                        {
                            itemID = slotData.options[1].itemID,
                            quantity = slotData.required - highCount,
                            quality = 1,
                        },
                        { itemID = option.itemID, quantity = highCount, quality = quality },
                    }
                    local sampleReagents = YQQuality.ReplaceReagent(baseline, slotData.slot, allocations)
                    local sampleOperation = SafeCall(
                        C_TradeSkillUI.GetCraftingOperationInfo,
                        recipeID,
                        sampleReagents,
                        allocationGUID,
                        false
                    )
                    local expectedBonus = maximumScore > 0
                        and (
                            maximumSkillBonus * slotData.weightPerPoint
                                * (quality - 1) * highCount / maximumScore
                        )
                        or 0
                    local measuredBonus = sampleOperation
                        and (YQQuality.GetOperationSkill(sampleOperation) - baselineSkill) or nil
                    if not measuredBonus then
                        result.exactUnavailableReason = "oracle Blizzard incomplet"
                        return result
                    end
                    if math.abs(measuredBonus - expectedBonus) > 1.01 then
                        result.exactUnavailableReason = "pondération Blizzard non linéaire"
                        return result
                    end
                    if yieldWork then yieldWork() end
                end
            end
        end

    end

    local weightGCD = 0
    for _, slotData in ipairs(result.slots) do
        local left = math.floor(math.abs(tonumber(slotData.weightPerPoint) or 0))
        local right = weightGCD
        while right ~= 0 do
            left, right = right, left % right
        end
        weightGCD = left
    end
    if weightGCD <= 0 then weightGCD = 1 end
    for _, slotData in ipairs(result.slots) do
        slotData.weightPerPoint = slotData.weightPerPoint / weightGCD
        local choices, choiceError = optimizer.BuildSlotChoices({
            required = slotData.required,
            tierCount = slotData.tierCount,
            weightPerPoint = slotData.weightPerPoint,
            options = slotData.options,
        }, yieldWork)
        if not choices then
            result.exactUnavailableReason = tostring(choiceError or "modèle de réactifs invalide")
            return result
        end
        slotData.compositions = choices
        groups[#groups + 1] = choices
    end

    local optimizerResult, optimizerError = optimizer.CombineGroups(groups, yieldWork)
    if not optimizerResult then
        result.exactUnavailableReason = tostring(optimizerError or "optimisation impossible")
        return result
    end
    local frontier = YQQuality.GetOptimizerFrontier(
        optimizerResult,
        result.maxQuality,
        baselineSkill,
        difficulty,
        useConcentration == true,
        maximumScore > 0 and (maximumSkillBonus * weightGCD / maximumScore) or 0
    )
    local predictionMismatch = #frontier == 0 and #(optimizerResult.states or {}) > 0
    local evaluationFailed = false
    local concentrationMismatch = false
    local evaluationCache = {}
    local evaluationCount = 0
    local operationCallCount = 0
    local steppedStats
    local function Inspect(optimizerState)
        local cached = evaluationCache[optimizerState]
        if cached ~= nil then return cached or nil end
        evaluationCount = evaluationCount + 1
        local reagents = YQQuality.BuildOptimizerReagents(baseline, result.slots, optimizerState)
        if useConcentration then
            operationCallCount = operationCallCount + 1
            local baseOperation = SafeCall(
                C_TradeSkillUI.GetCraftingOperationInfo,
                recipeID,
                reagents,
                allocationGUID,
                false
            )
            local baseQuality = tonumber(baseOperation and baseOperation.craftingQuality) or 0
            if not baseOperation or baseQuality <= 0 then
                evaluationFailed = true
                evaluationCache[optimizerState] = false
                return nil
            end
            cached = { class = baseQuality, reagents = reagents }
            evaluationCache[optimizerState] = cached
            return cached
        end
        operationCallCount = operationCallCount + 1
        local operation = SafeCall(
            C_TradeSkillUI.GetCraftingOperationInfo,
            recipeID,
            reagents,
            allocationGUID,
            useConcentration == true
        )
        local quality = tonumber(operation and operation.craftingQuality) or 0
        if not operation or quality <= 0 then
            evaluationFailed = true
            evaluationCache[optimizerState] = false
            return nil
        end
        cached = { class = quality, reagents = reagents, candidateChecked = true }
        evaluationCache[optimizerState] = cached
        cached.candidate = {
            quality = quality,
            cost = optimizerState.cost,
            estimated = optimizerState.estimated == true,
            skillWeight = optimizerState.weight,
            usesConcentration = useConcentration == true,
            reagents = YQQuality.CopyReagents(reagents),
            operation = operation,
        }
        return cached
    end
    local function EnsureCandidate(optimizerState, evaluation)
        if not evaluation or evaluation.candidateChecked then
            return evaluation and evaluation.candidate or nil
        end
        evaluation.candidateChecked = true
        if evaluation.class >= result.maxQuality then return nil end
        operationCallCount = operationCallCount + 1
        local operation = SafeCall(
            C_TradeSkillUI.GetCraftingOperationInfo,
            recipeID,
            evaluation.reagents,
            allocationGUID,
            true
        )
        local quality = tonumber(operation and operation.craftingQuality) or 0
        if not operation or quality <= 0 then
            evaluationFailed = true
            return nil
        end
        if quality ~= evaluation.class + 1 then
            concentrationMismatch = true
            return nil
        end
        evaluation.candidate = {
            quality = quality,
            cost = optimizerState.cost,
            estimated = optimizerState.estimated == true,
            skillWeight = optimizerState.weight,
            usesConcentration = true,
            reagents = YQQuality.CopyReagents(evaluation.reagents),
            operation = operation,
        }
        return evaluation.candidate
    end
    local function AddEvaluation(optimizerState, checkPrediction)
        local evaluation = Inspect(optimizerState)
        if not evaluation then
            predictionMismatch = true
            return
        end
        local candidate = EnsureCandidate(optimizerState, evaluation)
        if checkPrediction and optimizerState.predictedQuality
            and (not candidate or candidate.quality ~= optimizerState.predictedQuality) then
            predictionMismatch = true
        end
        if candidate then
            YQQuality.InsertParetoCandidate(result.candidates, candidate)
        end
    end
    for _, optimizerState in ipairs(frontier) do
        AddEvaluation(optimizerState, true)
        if yieldWork then yieldWork() end
    end
    if predictionMismatch then
        result.candidates = {}
        if evaluationFailed or concentrationMismatch then
            result.exactUnavailableReason = "oracle Blizzard incomplet"
            return result
        end
        local steppedMinima, steppedDetail = optimizer.FindSteppedClassMinima(
            optimizerResult.states or {},
            function(optimizerState)
                local evaluation = Inspect(optimizerState)
                if yieldWork then yieldWork() end
                return evaluation and evaluation.class or nil
            end
        )
        local steppedError
        if steppedMinima then
            steppedStats = steppedDetail
        else
            steppedError = steppedDetail
        end
        if not steppedMinima or evaluationFailed then
            result.candidates = {}
            local nonMonotone = steppedError == "classifier is not monotone"
                or steppedError == "classifier changed inside a coarse plateau"
            result.exactUnavailableReason = nonMonotone
                and "qualité Blizzard non monotone"
                or "oracle Blizzard incomplet"
            return result
        end
        for _, minimum in ipairs(steppedMinima) do
            local evaluation = Inspect(minimum.state)
            local candidate = EnsureCandidate(minimum.state, evaluation)
            if evaluation and evaluation.class == minimum.class and candidate then
                YQQuality.InsertParetoCandidate(result.candidates, candidate)
            end
        end
        if evaluationFailed or concentrationMismatch then
            result.candidates = {}
            result.exactUnavailableReason = "oracle Blizzard incomplet"
            return result
        end
    end

    for _, candidate in ipairs(result.candidates) do
        result.minQuality = math.min(result.minQuality, candidate.quality)
        result.reachableQuality = math.max(result.reachableQuality, candidate.quality)
    end
    if result.maxQuality <= 0 then result.maxQuality = result.reachableQuality end
    result.simplifiedResult = result.maxQuality == 2
    table.sort(result.candidates, function(left, right)
        if left.quality ~= right.quality then return left.quality < right.quality end
        if left.cost ~= right.cost then return left.cost < right.cost end
        if left.estimated ~= right.estimated then return left.estimated ~= true end
        return YQQuality.GetCandidateItemQuantity(left, 246450)
            < YQQuality.GetCandidateItemQuantity(right, 246450)
    end)
    DebugPrint(
        "quality-state recipe=" .. tostring(recipeID)
            .. " max=" .. tostring(result.maxQuality)
            .. " reachable=" .. tostring(result.reachableQuality)
            .. " dp=" .. tostring(#(optimizerResult.states or {}))
            .. " inspected=" .. tostring(evaluationCount)
            .. " evalOracle=" .. tostring(operationCallCount)
            .. " refine=" .. tostring(steppedStats and steppedStats.classificationCount or 0)
            .. " candidates=" .. tostring(#result.candidates)
    )
    YQQuality.CacheRecipeState(qualityCache, cacheKey, result)
    return result
end

function YQQuality.GetOptionalSelectionCost(optionalSlots, selections, priceContext)
    local cost = 0
    local estimated = false
    priceContext = priceContext or YQQuality.CreateMaterialPriceContext()
    for _, slotData in ipairs(optionalSlots or {}) do
        local slotIndex = tonumber(slotData.slot and slotData.slot.dataSlotIndex)
        local itemID = slotIndex and tonumber(selections and selections[slotIndex]) or nil
        if itemID then
            local option = YQQuality.GetSelectionOption(optionalSlots, slotIndex, itemID)
            if not option then return nil, false end
            if option.isFinishing or option.isMissive then
                local quantity = math.max(1, tonumber(slotData.slot and slotData.slot.quantityRequired) or 1)
                local quote = YQQuality.GetItemPriceQuote(itemID, quantity, priceContext)
                if not quote then return nil, false end
                cost = cost + quote.total
                estimated = estimated or quote.estimated == true
            end
        end
    end
    return cost, estimated
end

function YQQuality.BuildFinishingOptimizedRecipeState(form, useConcentration, optionalSelections, useGoldStar, yieldWork)
    local recipeInfo = form and type(form.GetRecipeInfo) == "function" and SafeCall(form.GetRecipeInfo, form) or nil
    local recipeID = tonumber(recipeInfo and recipeInfo.recipeID)
    local level = form and type(form.GetCurrentRecipeLevel) == "function" and SafeCall(form.GetCurrentRecipeLevel, form) or nil
    local schematic = recipeID and SafeCall(C_TradeSkillUI.GetRecipeSchematic, recipeID, false, level) or nil
    if not recipeInfo or type(schematic) ~= "table" then return nil end

    local optionalSlots, plans, plansComplete = YQQuality.BuildOptionalPlans(
        form, recipeInfo, schematic, optionalSelections, true, useGoldStar == true, yieldWork
    )
    local priceContext = YQQuality.CreateMaterialPriceContext()
    local combined
    local allPlansComplete = plansComplete == true
    local basePlanComplete = false
    for planIndex, selections in ipairs(plans) do
        local recipeState = YQQuality.BuildRecipeState(form, useConcentration, selections, yieldWork)
        local planComplete = false
        if recipeState then
            if not combined then
                combined = {
                    recipeID = recipeState.recipeID,
                    recipeName = recipeState.recipeName,
                    slots = recipeState.slots,
                    optionalSlots = optionalSlots,
                    optionalSelections = YQQuality.CopyOptionalSelections(optionalSelections),
                    candidates = {},
                    minQuality = math.huge,
                    maxQuality = recipeState.maxQuality,
                    reachableQuality = 0,
                    reagentQualityCount = recipeState.reagentQualityCount,
                    recipeInfo = recipeState.recipeInfo,
                    schematic = recipeState.schematic,
                    allocationGUID = recipeState.allocationGUID,
                    simplifiedResult = recipeState.simplifiedResult,
                }
            end
            combined.exactUnavailableReason = combined.exactUnavailableReason
                or recipeState.exactUnavailableReason
            local optionalCost, optionalEstimated = YQQuality.GetOptionalSelectionCost(
                optionalSlots, selections, priceContext
            )
            if not recipeState.exactUnavailableReason and optionalCost
                and #(recipeState.candidates or {}) > 0 then
                planComplete = true
            end
            for _, candidate in ipairs(planComplete and recipeState.candidates or {}) do
                if optionalCost then
                    local totalCost = candidate.cost + optionalCost
                    YQQuality.InsertParetoCandidate(combined.candidates, {
                        quality = candidate.quality,
                        cost = totalCost,
                        totalCost = totalCost,
                        estimated = candidate.estimated == true or optionalEstimated,
                        skillWeight = candidate.skillWeight,
                        usesConcentration = candidate.usesConcentration == true,
                        reagents = YQQuality.CopyReagents(candidate.reagents),
                        operation = candidate.operation,
                        optionalSelections = YQQuality.CopyOptionalSelections(selections),
                    })
                end
                if yieldWork then yieldWork() end
            end
        end
        allPlansComplete = allPlansComplete and planComplete
        if planIndex == 1 then basePlanComplete = planComplete end
        if yieldWork then yieldWork() end
    end
    if not combined then return nil end
    if not allPlansComplete or not basePlanComplete then
        combined.candidates = {}
        combined.minQuality = math.huge
        combined.reachableQuality = 0
        combined.exactUnavailableReason = combined.exactUnavailableReason
            or "comparaison finishing incomplète"
        return combined
    end
    for _, candidate in ipairs(combined.candidates) do
        combined.minQuality = math.min(combined.minQuality, candidate.quality)
        combined.reachableQuality = math.max(combined.reachableQuality, candidate.quality)
    end
    combined.optionalSelections = YQQuality.CopyOptionalSelections(optionalSelections)
    combined.finishingOptimized = true
    table.sort(combined.candidates, function(left, right)
        if left.quality ~= right.quality then return left.quality < right.quality end
        if left.cost ~= right.cost then return left.cost < right.cost end
        if left.estimated ~= right.estimated then return left.estimated ~= true end
        return YQQuality.GetCandidateItemQuantity(left, 246450)
            < YQQuality.GetCandidateItemQuantity(right, 246450)
    end)
    return combined
end

function YQQuality.GetSelectionKey(recipeID, useConcentration, selections, useFinishing, useGoldStar, form)
    local transaction = form and (
        (type(form.GetTransaction) == "function" and SafeCall(form.GetTransaction, form))
            or form.transaction
    ) or nil
    local level = form and type(form.GetCurrentRecipeLevel) == "function"
        and SafeCall(form.GetCurrentRecipeLevel, form) or nil
    local allocationGUID = transaction and type(transaction.GetAllocationItemGUID) == "function"
        and SafeCall(transaction.GetAllocationItemGUID, transaction) or nil
    local priceContext = YQQuality.CreateMaterialPriceContext()
    local parts = {
        tostring(recipeID),
        tostring(level or ""),
        tostring(allocationGUID or ""),
        tostring(state.craft.qualityPriceRevision or 0),
        priceContext.reservationSignature,
        useConcentration == true and "1" or "0",
        useFinishing == true and "1" or "0",
        useGoldStar == true and "1" or "0",
    }
    local slots = {}
    for slotIndex, itemID in pairs(selections or {}) do
        slotIndex = tonumber(slotIndex)
        itemID = tonumber(itemID)
        if slotIndex and itemID then
            slots[#slots + 1] = tostring(slotIndex) .. ":" .. tostring(itemID)
        end
    end
    table.sort(slots)
    for _, slot in ipairs(slots) do parts[#parts + 1] = slot end
    return table.concat(parts, "|")
end

function YQQuality.QueueRecipeStateSolve(form, recipeID, useConcentration, selections, useFinishing, useGoldStar, selectionKey)
    local active = state.craft.qualitySolve
    if active and active.selectionKey == selectionKey then return false end
    local cachedState, selectionCache = YQQuality.GetCachedSelectionState(selectionKey)
    if cachedState then
        YQQuality.CancelRecipeSolve()
        cachedState.selectionKey = selectionKey
        state.craft.qualityState = cachedState
        DebugPrint("quality-selection-cache hit recipe=" .. tostring(recipeID))
        return true
    end

    state.craft.qualitySolveGeneration = (state.craft.qualitySolveGeneration or 0) + 1
    local generation = state.craft.qualitySolveGeneration
    state.craft.qualityPreviewGeneration = (state.craft.qualityPreviewGeneration or 0) + 1
    state.craft.qualityPreviewStates = {}
    state.craft.qualityPreviewPending = {}
    state.craft.qualityPreviewSolve = nil
    state.craft.qualityPreviewQueue = {}
    local job = {
        generation = generation,
        selectionKey = selectionKey,
        form = form,
        useConcentration = useConcentration == true,
        useFinishing = useFinishing == true,
        useGoldStar = useGoldStar == true,
        selections = YQQuality.CopyOptionalSelections(selections),
    }
    job.co = coroutine.create(function()
        if job.useFinishing then
            return YQQuality.BuildFinishingOptimizedRecipeState(
                job.form, job.useConcentration, job.selections, job.useGoldStar,
                function() coroutine.yield() end
            )
        end
        return YQQuality.BuildRecipeState(job.form, job.useConcentration, job.selections, function() coroutine.yield() end)
    end)
    state.craft.qualitySolve = job

    local function Continue()
        if state.craft.qualitySolve ~= job or generation ~= state.craft.qualitySolveGeneration then return end
        local frame = state.craft.qualityFrame
        if not frame or frame.userClosed or not frame:IsShown() then
            state.craft.qualitySolve = nil
            return
        end
        local startedAt = debugprofilestop and debugprofilestop() or 0
        while coroutine.status(job.co) ~= "dead" do
            local ok, result = coroutine.resume(job.co)
            if not ok then
                DebugPrint("quality-solve error=" .. tostring(result))
                state.craft.qualitySolve = nil
                return
            end
            if coroutine.status(job.co) == "dead" then
                state.craft.qualitySolve = nil
                if type(result) == "table" and generation == state.craft.qualitySolveGeneration then
                    result.selectionKey = selectionKey
                    YQQuality.CacheSelectionState(selectionCache, selectionKey, result)
                    state.craft.qualityState = result
                    YQQuality.UpdateSelector()
                end
                return
            end
            if not debugprofilestop or (debugprofilestop() - startedAt) >= 2 then break end
        end
        C_Timer.After(0, Continue)
    end
    C_Timer.After(0, Continue)
    return false
end

function YQQuality.RunNextPreviewSolve()
    if state.craft.qualityPreviewSolve then return end
    if state.craft.qualitySolve then
        C_Timer.After(0.05, YQQuality.RunNextPreviewSolve)
        return
    end
    local job = table.remove(state.craft.qualityPreviewQueue or {}, 1)
    if not job then return end
    if job.generation ~= state.craft.qualityPreviewGeneration then
        state.craft.qualityPreviewPending[job.key] = nil
        YQQuality.RunNextPreviewSolve()
        return
    end
    state.craft.qualityPreviewSolve = job
    job.co = coroutine.create(function()
        return YQQuality.BuildRecipeState(
            job.form,
            job.useConcentration,
            job.selections,
            function() coroutine.yield() end
        )
    end)

    local function Continue()
        if state.craft.qualityPreviewSolve ~= job then return end
        local frame = state.craft.qualityFrame
        if not frame or frame.userClosed or not frame:IsShown() then
            state.craft.qualityPreviewPending[job.key] = nil
            state.craft.qualityPreviewSolve = nil
            return
        end
        if job.generation ~= state.craft.qualityPreviewGeneration then
            state.craft.qualityPreviewPending[job.key] = nil
            state.craft.qualityPreviewSolve = nil
            YQQuality.RunNextPreviewSolve()
            return
        end
        local startedAt = debugprofilestop and debugprofilestop() or 0
        while coroutine.status(job.co) ~= "dead" do
            local ok, result = coroutine.resume(job.co)
            if not ok then
                DebugPrint("quality-preview error=" .. tostring(result))
                state.craft.qualityPreviewPending[job.key] = nil
                state.craft.qualityPreviewSolve = nil
                YQQuality.RunNextPreviewSolve()
                return
            end
            if coroutine.status(job.co) == "dead" then
                state.craft.qualityPreviewPending[job.key] = nil
                state.craft.qualityPreviewSolve = nil
                if type(result) == "table" and job.generation == state.craft.qualityPreviewGeneration then
                    state.craft.qualityPreviewStates[job.key] = result
                    YQQuality.UpdateSelector()
                end
                YQQuality.RunNextPreviewSolve()
                return
            end
            if not debugprofilestop or (debugprofilestop() - startedAt) >= 3 then break end
        end
        C_Timer.After(0, Continue)
    end
    C_Timer.After(0, Continue)
end

function YQQuality.QueuePreviewStateSolve(form, useConcentration, selections, key)
    if state.craft.qualityPreviewStates[key] or state.craft.qualityPreviewPending[key] then return end
    state.craft.qualityPreviewPending[key] = true
    state.craft.qualityPreviewQueue[#state.craft.qualityPreviewQueue + 1] = {
        generation = state.craft.qualityPreviewGeneration,
        key = key,
        form = form,
        useConcentration = useConcentration == true,
        selections = YQQuality.CopyOptionalSelections(selections),
    }
    YQQuality.RunNextPreviewSolve()
end

function YQQuality.FindCandidate(recipeState, targetQuality, quantity)
    local selected
    for _, candidate in ipairs(recipeState and recipeState.candidates or {}) do
        local feasible = quantity == nil or YQQuality.HasGoldStarQuantity(candidate, quantity)
        if candidate.quality == targetQuality and feasible then
            local candidateCost = tonumber(candidate.totalCost or candidate.cost) or math.huge
            local selectedCost = selected
                and (tonumber(selected.totalCost or selected.cost) or math.huge) or math.huge
            if not selected
                or candidateCost < selectedCost
                or (
                    candidateCost == selectedCost
                    and candidate.estimated ~= selected.estimated
                    and candidate.estimated ~= true
                ) then
                selected = candidate
            end
        end
    end
    return selected
end

function YQQuality.FindClosestCandidateQuality(recipeState, preferredQuality, quantity)
    local preferred = tonumber(preferredQuality)
    local selectedQuality
    local selectedDistance
    for _, candidate in ipairs(recipeState and recipeState.candidates or {}) do
        local quality = tonumber(candidate and candidate.quality)
        if quality and YQQuality.FindCandidate(recipeState, quality, quantity) then
            local distance = preferred and math.abs(quality - preferred) or 0
            if not selectedQuality
                or distance < selectedDistance
                or (distance == selectedDistance and quality > selectedQuality) then
                selectedQuality = quality
                selectedDistance = distance
            end
        end
    end
    return selectedQuality
end

function YQQuality.GetRecipeQualityItemID(recipeState, quality)
    local recipeInfo = recipeState and recipeState.recipeInfo
    local itemIDs = recipeInfo and recipeInfo.qualityItemIDs
    local itemID = type(itemIDs) == "table" and tonumber(itemIDs[quality]) or nil
    if itemID and itemID > 0 then
        return itemID
    end

    if type(C_TradeSkillUI) == "table"
        and type(C_TradeSkillUI.GetRecipeQualityItemIDs) == "function" then
        itemIDs = SafeCall(C_TradeSkillUI.GetRecipeQualityItemIDs, recipeState.recipeID)
        itemID = type(itemIDs) == "table" and tonumber(itemIDs[quality]) or nil
        if itemID and itemID > 0 then
            return itemID
        end
    end
end

function YQQuality.GetOutputPriceReference(recipeState, candidate)
    if not recipeState or not candidate then return nil end
    local quality = tonumber(candidate.quality) or 0
    local recipeID = tonumber(recipeState.recipeID)
    if not recipeID or recipeID <= 0 or quality <= 0 then return nil end

    if recipeState.maxQuality <= 3 then
        local itemID = YQQuality.GetRecipeQualityItemID(recipeState, quality)
        if itemID then
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

function YQQuality.GetOutputInventoryReference(recipeState, candidate)
    if not recipeState or not candidate then return nil, nil end
    local quality = tonumber(candidate.quality) or 0
    local recipeID = tonumber(recipeState.recipeID)
    if not recipeID or recipeID <= 0 or quality <= 0 then return nil, nil end

    if recipeState.maxQuality <= 3 then
        local itemID = YQQuality.GetRecipeQualityItemID(recipeState, quality)
        if itemID then
            WarmItemData(itemID)
            return itemID, itemID
        end
    end

    if type(C_TradeSkillUI.GetRecipeOutputItemData) ~= "function" then return nil, nil end
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
    if type(output) ~= "table" then return nil, nil end
    local itemID = tonumber(output.itemID)
    if itemID then WarmItemData(itemID) end
    if recipeState.maxQuality > 3 then
        local hyperlink = type(output.hyperlink) == "string" and output.hyperlink or nil
        return hyperlink ~= "" and hyperlink or nil, itemID
    end
    return itemID, itemID
end

function YQQuality.GetCraftedItemQuality(item)
    if type(item) == "string" then
        local quality = tonumber(item:match("Professions%-ChatIcon%-Quality%-12%-Tier(%d+)"))
            or tonumber(item:match("Professions%-ChatIcon%-Quality%-Tier(%d+)"))
            or tonumber(item:match("Professions%-Icon%-Quality%-12%-Tier(%d+)"))
            or tonumber(item:match("Professions%-Icon%-Quality%-Tier(%d+)"))
        if quality and quality > 0 then return quality end
    end
    if type(C_TradeSkillUI) == "table"
        and type(C_TradeSkillUI.GetItemCraftedQualityByItemInfo) == "function" then
        local quality = tonumber(SafeCall(C_TradeSkillUI.GetItemCraftedQualityByItemInfo, item))
        if quality and quality > 0 then return quality end
    end
    return nil
end

function YQQuality.GetStockCache()
    local cache = state.craft.qualityStockCache
    if type(cache) ~= "table" or type(cache.containers) ~= "table" then
        cache = {
            containers = {},
            knownBags = {},
            scopeBagIDs = {},
            scopeAuthoritative = {},
            dirty = { bags = true, character = true, warband = true },
        }
        state.craft.qualityStockCache = cache
    end
    return cache
end

function YQQuality.MarkStockDirty(bags, character, warband)
    local cache = YQQuality.GetStockCache()
    if bags then cache.dirty.bags = true end
    if character then cache.dirty.character = true end
    if warband then cache.dirty.warband = true end
end

function YQQuality.GetStockBagIDs(scope)
    local bagIndex = Enum and Enum.BagIndex or {}
    if scope == "bags" then
        local ids = {}
        local first = tonumber(bagIndex.Backpack) or 0
        local last = tonumber(bagIndex.ReagentBag) or 5
        for bagID = first, last do ids[#ids + 1] = bagID end
        return ids, true
    end

    local bankType = Enum and Enum.BankType
    local requestedType = scope == "character"
        and bankType and bankType.Character
        or bankType and bankType.Account
    if requestedType ~= nil and type(C_Bank) == "table"
        and type(C_Bank.FetchPurchasedBankTabIDs) == "function" then
        local purchased = SafeCall(C_Bank.FetchPurchasedBankTabIDs, requestedType)
        if type(purchased) == "table" then
            local ids = {}
            for _, bagID in pairs(purchased) do
                bagID = tonumber(bagID)
                if bagID then ids[#ids + 1] = bagID end
            end
            return ids, true
        end
    end

    local first = scope == "character"
        and tonumber(bagIndex.CharacterBankTab_1)
        or tonumber(bagIndex.AccountBankTab_1)
    local last = scope == "character"
        and tonumber(bagIndex.CharacterBankTab_6)
        or tonumber(bagIndex.AccountBankTab_5)
    local ids = {}
    if first and last then
        for bagID = first, last do ids[#ids + 1] = bagID end
    end
    return ids, false
end

function YQQuality.ScanStockScope(scope)
    local cache = YQQuality.GetStockCache()
    local bagIDs, authoritative = YQQuality.GetStockBagIDs(scope)
    cache.scopeBagIDs[scope] = bagIDs
    cache.scopeAuthoritative[scope] = authoritative
    for _, bagID in ipairs(bagIDs) do
        local slotCount = C_Container and type(C_Container.GetContainerNumSlots) == "function"
            and tonumber(SafeCall(C_Container.GetContainerNumSlots, bagID)) or nil
        if scope == "bags" or (slotCount and slotCount > 0) then
            local snapshot = {}
            for slotIndex = 1, math.max(0, slotCount or 0) do
                local info = type(C_Container.GetContainerItemInfo) == "function"
                    and SafeCall(C_Container.GetContainerItemInfo, bagID, slotIndex) or nil
                if type(info) == "table" and tonumber(info.itemID) then
                    local location = ItemLocation and type(ItemLocation.CreateFromBagAndSlot) == "function"
                        and ItemLocation:CreateFromBagAndSlot(bagID, slotIndex) or nil
                    local isBound = info.isBound
                    if location and type(C_Item) == "table" and type(C_Item.IsBound) == "function" then
                        local apiBound = SafeCall(C_Item.IsBound, location)
                        if apiBound ~= nil then isBound = apiBound == true end
                    end
                    if isBound == false then
                        snapshot[#snapshot + 1] = {
                            itemID = tonumber(info.itemID),
                            quantity = math.max(1, tonumber(info.stackCount) or 1),
                            quality = YQQuality.GetCraftedItemQuality(info.hyperlink),
                        }
                    end
                end
            end
            cache.containers[bagID] = snapshot
            cache.knownBags[bagID] = true
        end
    end
    cache.dirty[scope] = false
end

function YQQuality.GetTSMOutputStock(itemReference)
    if type(TSM_API) ~= "table"
        or type(TSM_API.ToItemString) ~= "function"
        or type(TSM_API.GetPlayerTotals) ~= "function" then
        return nil, nil
    end

    local candidate = itemReference
    if type(candidate) == "number" then
        candidate = select(2, GetItemInfo(candidate)) or ("i:" .. candidate)
    end
    if type(candidate) ~= "string" or candidate == "" then return nil, nil end

    local okString, itemString = pcall(TSM_API.ToItemString, candidate)
    if not okString or type(itemString) ~= "string" or itemString == "" then
        return nil, nil
    end

    local okTotals, character, alts, characterAuctions, altAuctions = pcall(
        TSM_API.GetPlayerTotals,
        itemString
    )
    if not okTotals
        or type(character) ~= "number"
        or type(alts) ~= "number"
        or type(characterAuctions) ~= "number"
        or type(altAuctions) ~= "number" then
        return nil, nil
    end

    local warbank = 0
    if type(TSM_API.GetWarbankQuantity) == "function" then
        local okWarbank, quantity = pcall(TSM_API.GetWarbankQuantity, itemString)
        if okWarbank and type(quantity) == "number" then warbank = quantity end
    end

    -- Keep C for the current character's immediately owned stock. Auctions are
    -- account/realm-wide in practice, so expose current and alt auctions in W.
    return character, alts + warbank + characterAuctions + altAuctions
end

function YQQuality.CountStockScope(scope, itemID, targetQuality, requireCraftedQuality)
    local cache = YQQuality.GetStockCache()
    if cache.dirty[scope] then YQQuality.ScanStockScope(scope) end
    local bagIDs = cache.scopeBagIDs[scope] or {}
    if cache.scopeAuthoritative[scope] ~= true and #bagIDs == 0 then return nil end
    local quantity = 0
    for _, bagID in ipairs(bagIDs) do
        if not cache.knownBags[bagID] then return nil end
        for _, item in ipairs(cache.containers[bagID] or {}) do
            local qualityMatches = item.quality == nil
                and not requireCraftedQuality
                or tonumber(item.quality) == tonumber(targetQuality)
            if item.itemID == itemID and qualityMatches then
                quantity = quantity + item.quantity
            end
        end
    end
    return quantity
end

function YQQuality.GetTradableOutputStock(recipeState, candidate)
    local itemReference, itemID = YQQuality.GetOutputInventoryReference(recipeState, candidate)
    if not itemReference or not itemID then return nil, nil, false end

    local bindType = select(14, GetItemInfo(itemID))
    if bindType == nil then
        WarmItemData(itemID)
        return nil, nil, false
    end
    if bindType ~= 0 and bindType ~= 2 and bindType ~= 3 then
        return nil, nil, false
    end

    local targetQuality = tonumber(candidate.quality)
    local requireCraftedQuality = tonumber(recipeState.maxQuality) > 3
    -- TSM stores crafted gear by levelItemString (for example i:238018::i232).
    -- Reuse the exact output reference built for pricing instead of the raw
    -- Blizzard hyperlink, whose bonus payload is not always normalized by TSM.
    local tsmReference = YQQuality.GetOutputPriceReference(recipeState, candidate) or itemReference
    local trackedCharacter, trackedWarband = YQQuality.GetTSMOutputStock(tsmReference)
    if trackedCharacter ~= nil and trackedWarband ~= nil then
        return trackedCharacter, trackedWarband, true
    end

    local bags = YQQuality.CountStockScope("bags", itemID, targetQuality, requireCraftedQuality)
    local bank = YQQuality.CountStockScope("character", itemID, targetQuality, requireCraftedQuality)
    local warband = YQQuality.CountStockScope("warband", itemID, targetQuality, requireCraftedQuality)
    local character = bags ~= nil and bank ~= nil and (bags + bank) or nil
    return character, warband, true
end

function YQQuality.GetCandidatePricing(recipeState, candidate)
    local pricing = {
        minBuyout = nil,
        materialCost = nil,
        profit = nil,
        estimated = false,
    }
    if not recipeState or not candidate then return pricing end

    local outputReference = YQQuality.GetOutputPriceReference(recipeState, candidate)
    pricing.minBuyout = outputReference and YQQuality.GetTSMPrice("dbminbuyout", outputReference) or nil

    local completeReagents = BuildCompleteRecipeReagents(
        recipeState.schematic,
        candidate.reagents,
        recipeState.recipeInfo
    )
    local priceContext = YQQuality.CreateMaterialPriceContext()
    local quantitiesByItemID = {}
    local itemIDs = {}
    for _, reagent in ipairs(completeReagents or {}) do
        local itemID = tonumber(reagent.itemID)
        local quantity = math.max(0, tonumber(reagent.quantity) or 0)
        if itemID and itemID > 0 and quantity > 0 then
            if not quantitiesByItemID[itemID] then
                itemIDs[#itemIDs + 1] = itemID
                quantitiesByItemID[itemID] = 0
            end
            quantitiesByItemID[itemID] = quantitiesByItemID[itemID] + quantity
        end
    end
    table.sort(itemIDs)
    local materialCost = 0
    local materialCostKnown = true
    for _, itemID in ipairs(itemIDs) do
        local quantity = quantitiesByItemID[itemID]
        local quote = YQQuality.GetItemPriceQuote(itemID, quantity, priceContext)
        if not quote then
            materialCostKnown = false
            break
        end
        if quote.estimated then
            pricing.estimated = true
        end
        materialCost = materialCost + quote.total
    end
    pricing.materialCost = materialCostKnown and materialCost or nil

    if pricing.minBuyout and pricing.materialCost then
        local schematic = recipeState.schematic or {}
		local quantityMin = math.max(1, tonumber(schematic.quantityMin) or 1)
		local quantityMax = math.max(quantityMin, tonumber(schematic.quantityMax) or quantityMin)
		local baseYield = (quantityMin + quantityMax) / 2
		local central = _G.YayaCraftedPriceAPI
		if central and type(central.CalculateNetValue) == "function" then
			pricing.profit = central.CalculateNetValue(
				pricing.minBuyout,
				baseYield,
				pricing.materialCost,
				0.05
			)
		else
			pricing.profit = (pricing.minBuyout * baseYield * 0.95) - pricing.materialCost
		end
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
    local queuedReservation = GetQueuedConcentrationReservation(state.GetCurrentProfessionID(), currencyID)
    local availableAfterQueue = math.max(0, available - queuedReservation)
    local required = concentrationCost * ClampQuantity(quantity)
    return currencyID ~= nil and availableAfterQueue >= required
end

function YQQuality.GetGoldStarAcquisitionPlan(candidate, quantity)
    local required = YQQuality.GetCandidateItemQuantity(candidate, CONFIG.GOLD_STAR_ITEM_ID)
        * ClampQuantity(quantity)
    if required <= 0 then
        return { steps = {} }
    end

    local priceContext = YQQuality.CreateMaterialPriceContext()
    local quote = YQQuality.GetItemPriceQuote(CONFIG.GOLD_STAR_ITEM_ID, required, priceContext)
    return quote and quote.mergePlan or nil
end

function YQQuality.QueueMergePlan(plan, professionID)
    if type(plan) ~= "table" or type(plan.steps) ~= "table" then
        return false
    end

    for depth, step in ipairs(plan.steps) do
        local quantity = math.floor(tonumber(step.quantity) or 0)
        local inputItemID = tonumber(step.inputItemID) or 0
        local outputItemID = tonumber(step.outputItemID) or 0
        local inputQuantity = math.max(1, math.floor(tonumber(step.inputQuantity) or 1))
        if quantity <= 0 or quantity > CONFIG.MAX_QUEUE_QTY or inputItemID <= 0 or outputItemID <= 0 then
            return false
        end

        local context = {
            recipeID = tonumber(step.recipeID) or 0,
            recipeName = step.name or ("Fusion " .. tostring(outputItemID)),
            professionID = tonumber(professionID) or state.GetCurrentProfessionID(),
            mode = "crafts",
            queueKind = "merge",
            mergeKey = tostring(inputItemID) .. ">" .. tostring(outputItemID),
            mergeInputItemID = inputItemID,
            mergeOutputItemID = outputItemID,
            mergeInputQuantity = inputQuantity,
            mergeDepth = depth,
            outputItemID = outputItemID,
            outputPerCraft = 1,
            reagents = {
                { itemID = inputItemID, quantity = inputQuantity },
            },
            craftingReagents = {},
        }
        if context.recipeID <= 0 then
            return false
        end
        AddRecipeToQueue(context, quantity)
    end
    return true
end

function YQQuality.HasGoldStarQuantity(candidate, quantity)
    return YQQuality.GetGoldStarAcquisitionPlan(candidate, quantity) ~= nil
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
        row:SetSize(320, 32)
        row:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -165 - ((rowIndex - 1) * 28))
        row:EnableMouse(true)
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(30, 30)
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

function YQQuality.EnsureOptionalRows(frame, rowCount)
    frame.optionalRows = frame.optionalRows or {}
    for rowIndex = #frame.optionalRows + 1, rowCount do
        local button = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        button:SetSize(36, 36)
        button:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -190 - ((rowIndex - 1) * 30))
        button.icon = button:CreateTexture(nil, "ARTWORK")
        button.icon:SetSize(30, 30)
        button.icon:SetPoint("CENTER")
        button.selectionMark = button:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        button.selectionMark:SetPoint("TOPRIGHT", button, "TOPRIGHT", 4, 5)
        button.selectionMark:SetText("|cff55ff77✓|r")
        button.selectionMark:Hide()
        button:SetScript("OnEnter", function(self)
            if not self.itemID then return end
            GameTooltip:SetOwner(self, "ANCHOR_LEFT")
            GameTooltip:SetItemByID(self.itemID)
            GameTooltip:Show()
        end)
        button:SetScript("OnLeave", GameTooltip_Hide)
        button:SetScript("OnClick", function(self)
            local target = state.craft.qualityTarget
            if not target or not self.slotIndex or self.lockedByOptimizer then return end
            local selectionItemID = self.selectionItemID or self.itemID
            target.optionalSelections = YQQuality.CopyOptionalSelections(target.optionalSelections)
            if self.selectedFamily or target.optionalSelections[self.slotIndex] == selectionItemID then
                target.optionalSelections[self.slotIndex] = nil
            else
                target.optionalSelections[self.slotIndex] = selectionItemID
            end
            YQQuality.UpdateSelector()
        end)
        button:Hide()
        frame.optionalRows[rowIndex] = button
    end
end

function YQQuality.EnsureFinishingRows(frame, rowCount)
    frame.finishingRows = frame.finishingRows or {}
    for rowIndex = #frame.finishingRows + 1, rowCount do
        local button = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        button:SetSize(36, 36)
        button.icon = button:CreateTexture(nil, "ARTWORK")
        button.icon:SetSize(30, 30)
        button.icon:SetPoint("CENTER")
        button.selectionMark = button:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        button.selectionMark:SetPoint("TOPRIGHT", button, "TOPRIGHT", 4, 5)
        button.selectionMark:SetText("|cff55ff77✓|r")
        button:SetScript("OnEnter", function(self)
            if not self.itemID then return end
            GameTooltip:SetOwner(self, "ANCHOR_LEFT")
            GameTooltip:SetItemByID(self.itemID)
            GameTooltip:Show()
        end)
        button:SetScript("OnLeave", GameTooltip_Hide)
        button:Disable()
        button:Hide()
        frame.finishingRows[rowIndex] = button
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
            state.craft.qualityPreferences.quality = self.quality
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
            state.craft.qualityPreferences.useConcentration = useConcentration
        end
        YQQuality.UpdateSelector()
    end)

    frame.finishing = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    frame.finishing:SetSize(24, 24)
    frame.finishing:SetPoint("TOPLEFT", frame, "TOPLEFT", 104, -114)
    frame.finishing:SetHitRectInsets(0, -56, 0, 0)
    frame.finishing.label = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    frame.finishing.label:SetPoint("LEFT", frame.finishing, "RIGHT", 1, 0)
    frame.finishing.label:SetText("Finishing")
    frame.finishing:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Finishing reagents")
        GameTooltip:AddLine("Optimise les finishing +skill débloqués avec les réactifs de base et la missive sélectionnée.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    frame.finishing:SetScript("OnLeave", GameTooltip_Hide)
    frame.finishing:SetScript("OnClick", function(self)
        if state.craft.qualityTarget then
            state.craft.qualityTarget.useFinishing = self:GetChecked() == true
            state.craft.qualityPreferences.useFinishing = state.craft.qualityTarget.useFinishing
        end
        YQQuality.UpdateSelector()
    end)

    frame.goldStar = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    frame.goldStar:SetSize(24, 24)
    frame.goldStar:SetPoint("TOPLEFT", frame, "TOPLEFT", 216, -114)
    frame.goldStar:SetHitRectInsets(0, -52, 0, 0)
    frame.goldStar.label = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    frame.goldStar.label:SetPoint("LEFT", frame.goldStar, "RIGHT", 1, 0)
    frame.goldStar.label:SetText("Gold Star +50")
    frame.goldStar:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Artisan's Consortium Gold Star")
        GameTooltip:AddLine("Réactif lié : n'est utilisé que si coché et présent dans les sacs.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    frame.goldStar:SetScript("OnLeave", GameTooltip_Hide)
    frame.goldStar:SetScript("OnClick", function(self)
        if state.craft.qualityTarget then
            state.craft.qualityTarget.useGoldStar = self:GetChecked() == true
            state.EnsureDB()
            db.qualityUseGoldStar = state.craft.qualityTarget.useGoldStar
            state.craft.qualityPreferences.useGoldStar = state.craft.qualityTarget.useGoldStar
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

    frame.optionalHeader = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    frame.optionalHeader:SetText("Réactifs optionnels")
    frame.optionalHeader:SetTextColor(1, 0.82, 0)
    frame.optionalHeader:Hide()
    frame.optionalRows = {}

    frame.finishingHeader = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    frame.finishingHeader:SetText("Finishing retenu")
    frame.finishingHeader:SetTextColor(1, 0.82, 0)
    frame.finishingHeader:Hide()
    frame.finishingNone = frame:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    frame.finishingNone:SetText("Aucun — le moins cher est retenu")
    frame.finishingNone:Hide()
    frame.finishingRows = {}

    frame.addButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.addButton:SetSize(108, 22)
    frame.addButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -8, 8)
    frame.addButton:SetText("Ajouter YQ")
    frame.addButton.schematicForm = schematicForm
    frame.addButton:SetScript("OnClick", function(self)
        local target = state.craft.qualityTarget
        local recipeState = state.craft.qualityState
        local requestedQuantity = GetQuantityInput(self.qtyBox)
        local candidate = recipeState and YQQuality.FindCandidate(
            recipeState, target and target.quality or 1, requestedQuantity
        )
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
        context.concentrationCurrencyID = YQQuality.GetConcentrationCurrencyID(candidate.operation)
        context.targetQuality = target.quality
        context.targetQualitySimplified = recipeState.simplifiedResult == true
        context.mode = "crafts"
        if target.useConcentration == true then
            if not YQQuality.HasEnoughConcentration(candidate, requestedQuantity) then
                Print("Concentration insuffisante pour ajouter ce lot.")
                return
            end
        end
        local goldStarPlan = YQQuality.GetGoldStarAcquisitionPlan(candidate, requestedQuantity)
        if not goldStarPlan then
            Print("Gold Star insuffisante pour ajouter ce lot.")
            return
        end
        if #(goldStarPlan.steps or {}) > 0
            and not YQQuality.QueueMergePlan(goldStarPlan, context.professionID)
        then
            Print("Etapes de fusion Gold Star indisponibles pour ce lot.")
            return
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
    if not isVisible or frame.userClosed then return end

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
        local preferences = state.craft.qualityPreferences
        target = {
            recipeID = recipeID,
            quality = preferences.quality,
            useConcentration = preferences.useConcentration == true,
            useFinishing = preferences.useFinishing ~= false,
            useGoldStar = preferences.useGoldStar == true,
            optionalSelections = {},
        }
        state.craft.qualityTarget = target
        frame.userClosed = false
    end
    target.optionalSelections = YQQuality.CopyOptionalSelections(target.optionalSelections)
    useConcentration = target.useConcentration == true
    local useFinishing = target.useFinishing == true
    local useGoldStar = useFinishing and target.useGoldStar == true
    local selectionKey = YQQuality.GetSelectionKey(
        recipeID, useConcentration, target.optionalSelections, useFinishing, useGoldStar,
        schematicForm
    )
    local recipeState = state.craft.qualityState
    if not recipeState or recipeState.selectionKey ~= selectionKey then
        local cacheHit = YQQuality.QueueRecipeStateSolve(
            schematicForm, recipeID, useConcentration, target.optionalSelections,
            useFinishing, useGoldStar, selectionKey
        )
        recipeState = state.craft.qualityState
        if not cacheHit then
            frame.status:SetText("Calcul en cours…")
            frame.maxText:SetText("")
            frame.marketText:SetText("")
            frame.addButton:Disable()
            for _, button in ipairs(frame.qualityButtons) do button:Hide() end
            frame.concentration:Disable()
            frame.finishing:Disable()
            frame.goldStar:Hide()
            frame.reagentHeader:Hide()
            for _, header in ipairs(frame.reagentQualityHeaders or {}) do header:Hide() end
            for _, row in ipairs(frame.reagentRows or {}) do row:Hide() end
            frame.optionalHeader:Hide()
            for _, row in ipairs(frame.optionalRows or {}) do row:Hide() end
            frame.finishingHeader:Hide()
            frame.finishingNone:Hide()
            for _, row in ipairs(frame.finishingRows or {}) do row:Hide() end
            return
        end
    end
    if not recipeState or recipeState.reachableQuality <= 0 then
        frame.status:SetText(
            recipeState and recipeState.exactUnavailableReason
                and ("Optimum exact indisponible : " .. recipeState.exactUnavailableReason)
                or "Qualité indisponible"
        )
        frame.maxText:SetText("")
        frame.marketText:SetText("Minbuyout : |cffaaaaaa?|r   Profit est. : |cffaaaaaa?|r")
        frame.addButton:Disable()
        for _, button in ipairs(frame.qualityButtons) do button:Hide() end
        frame.concentration:Show()
        frame.concentration:Enable()
        frame.concentration:SetChecked(useConcentration)
        local errorHasFinishing = false
        for _, slotData in ipairs(recipeState and recipeState.optionalSlots or {}) do
            errorHasFinishing = errorHasFinishing
                or (slotData.options[1] and slotData.options[1].isFinishing == true)
        end
        frame.finishing:SetShown(errorHasFinishing)
        frame.finishing:SetEnabled(errorHasFinishing)
        frame.finishing:SetChecked(useFinishing)
        frame.goldStar:Hide()
        frame.reagentHeader:Hide()
        for _, header in ipairs(frame.reagentQualityHeaders or {}) do header:Hide() end
        for _, row in ipairs(frame.reagentRows or {}) do row:Hide() end
        frame.optionalHeader:Hide()
        for _, row in ipairs(frame.optionalRows or {}) do row:Hide() end
        frame.finishingHeader:Hide()
        frame.finishingNone:Hide()
        for _, row in ipairs(frame.finishingRows or {}) do row:Hide() end
        return
    end
    frame.concentration:Show()
    frame.reagentHeader:Show()
    local minimumQuality = recipeState.minQuality == math.huge and 1 or recipeState.minQuality
    local requestedQuantity = ReadQuantityInput(frame.addButton.qtyBox)
    local preferredQuality = tonumber(state.craft.qualityPreferences.quality)
        or tonumber(target.quality)
        or recipeState.reachableQuality
    target.quality = YQQuality.FindClosestCandidateQuality(
        recipeState, preferredQuality, requestedQuantity
    )
        or math.min(recipeState.maxQuality, math.max(minimumQuality, preferredQuality))
    if state.craft.qualityPreferences.quality == nil then
        state.craft.qualityPreferences.quality = target.quality
    end
    local selectedCandidate = YQQuality.FindCandidate(
        recipeState, target.quality, requestedQuantity
    )
    frame.maxText:SetText(
        "Qualité max : " .. YQQuality.GetQualityIcon(
            recipeState.maxQuality, 18, recipeState.simplifiedResult
        )
    )
    local characterStock, warbandStock, showStock = YQQuality.GetTradableOutputStock(
        recipeState, selectedCandidate
    )
    local stockText = showStock
        and (
            "  Stock " .. YQQuality.GetQualityIcon(
                target.quality, 14, recipeState.simplifiedResult
            )
                .. " C:" .. (characterStock ~= nil and tostring(characterStock) or "?")
                .. " W:" .. (warbandStock ~= nil and tostring(warbandStock) or "?")
        )
        or ""
    frame.status:SetText(
        "Atteignable : " .. YQQuality.GetQualityIcon(
            recipeState.reachableQuality, 18, recipeState.simplifiedResult
        ) .. stockText
    )
    DebugPrint(
        "quality-display recipe=" .. tostring(recipeState.recipeID)
            .. " target=" .. tostring(target.quality)
            .. " selected=" .. tostring(selectedCandidate and selectedCandidate.quality)
    )
    for quality, button in ipairs(frame.qualityButtons) do
        button.icon:SetAtlas(YQQuality.GetQualityAtlas(quality, recipeState.simplifiedResult))
        button:SetShown(quality >= minimumQuality and quality <= recipeState.maxQuality)
        button:SetEnabled(
            quality >= minimumQuality
                and quality <= recipeState.reachableQuality
                and YQQuality.FindCandidate(recipeState, quality, requestedQuantity) ~= nil
        )
        if quality == target.quality then
            button:LockHighlight()
        else
            button:UnlockHighlight()
        end
    end
    frame.concentration:SetChecked(useConcentration)
    frame.concentration:SetEnabled(recipeState.maxQuality > 1)
    local hasFinishing = false
    local hasGoldStar = false
    for _, slotData in ipairs(recipeState.optionalSlots or {}) do
        for _, option in ipairs(slotData.options or {}) do
            hasFinishing = hasFinishing or option.isFinishing == true
            hasGoldStar = hasGoldStar or option.isGoldStar == true
        end
    end
    frame.finishing:SetShown(hasFinishing)
    frame.finishing:SetEnabled(hasFinishing)
    frame.finishing:SetChecked(useFinishing)
    frame.goldStar:SetShown(hasFinishing and hasGoldStar and useFinishing)
    frame.goldStar:SetChecked(useGoldStar)
    local candidate = YQQuality.FindCandidate(recipeState, target.quality, requestedQuantity)
    local goldStarPlan = YQQuality.GetGoldStarAcquisitionPlan(candidate, requestedQuantity)
    frame.goldStar:SetEnabled(goldStarPlan ~= nil)
    local concentrationEnough = not useConcentration
        or YQQuality.HasEnoughConcentration(candidate, requestedQuantity)
    local goldStarEnough = goldStarPlan ~= nil
    frame.addButton:SetEnabled(candidate ~= nil and concentrationEnough and goldStarEnough)
    local pricing = YQQuality.GetCandidatePricing(recipeState, candidate)
    local minBuyoutText = pricing.minBuyout and GetMoneyString(math.floor(pricing.minBuyout), true) or "|cffaaaaaa?|r"
    local profitText = YQQuality.FormatSignedMoney(pricing.profit)
    local profitColor = "|cffaaaaaa"
    if type(pricing.profit) == "number" then
        profitColor = pricing.profit > 0 and "|cff55dd77" or (pricing.profit < 0 and "|cffff5555" or "|cffffffff")
    end
    frame.lastMarketText = (pricing.estimated and "Coût estimé : " or "Coût : ")
        .. (pricing.materialCost and GetMoneyString(math.floor(pricing.materialCost), true) or "|cffaaaaaa?|r")
        .. "   Minbuyout : " .. minBuyoutText
        .. "   Profit est. : " .. profitColor .. profitText .. "|r"
    frame.marketText:SetText(frame.lastMarketText)
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
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -165 - ((rowIndex - 1) * 34))
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

    local reagentRowCount = #(recipeState.slots or {})
    local optionalOptions = {}
    local finishingOptions = {}
    local seenMissiveFamilies = {}
    for _, slotData in ipairs(recipeState.optionalSlots or {}) do
        local slotIndex = tonumber(slotData.slot.dataSlotIndex)
        local selectedItemID = candidate and candidate.optionalSelections
            and candidate.optionalSelections[slotIndex] or target.optionalSelections[slotIndex]
        local selectedOption = YQQuality.GetSelectionOption(recipeState.optionalSlots, slotIndex, selectedItemID)
        for _, option in ipairs(slotData.options or {}) do
            if useFinishing then
                if option.isFinishing and selectedItemID == option.itemID then
                    finishingOptions[#finishingOptions + 1] = { slot = slotData.slot, option = option, optimized = true }
                elseif option.isMissive then
                    local familyKey = tostring(slotIndex) .. "|" .. tostring(option.itemName)
                    if not seenMissiveFamilies[familyKey] then
                        seenMissiveFamilies[familyKey] = true
                        optionalOptions[#optionalOptions + 1] = {
                            slot = slotData.slot,
                            option = option,
                            selectionItemID = option.itemID,
                            selected = selectedOption and selectedOption.itemName == option.itemName,
                        }
                    end
                elseif selectedItemID == option.itemID then
                    optionalOptions[#optionalOptions + 1] = { slot = slotData.slot, option = option, optimized = true }
                end
            elseif not option.isFinishing then
                optionalOptions[#optionalOptions + 1] = { slot = slotData.slot, option = option }
            end
        end
    end
    table.sort(optionalOptions, function(left, right)
        if left.option.priority ~= right.option.priority then return left.option.priority < right.option.priority end
        if left.option.quality ~= right.option.quality then return left.option.quality < right.option.quality end
        return left.option.itemName < right.option.itemName
    end)
    table.sort(finishingOptions, function(left, right)
        return tostring(left.option.itemName) < tostring(right.option.itemName)
    end)
    YQQuality.EnsureOptionalRows(frame, #optionalOptions)
    YQQuality.EnsureFinishingRows(frame, #finishingOptions)
    local contentTop = -171 - (reagentRowCount * 34)
    local finishingColumns = 8
    local finishingLineCount = math.ceil(#finishingOptions / finishingColumns)
    frame.finishingHeader:ClearAllPoints()
    frame.finishingHeader:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, contentTop)
    frame.finishingHeader:SetShown(useFinishing)
    frame.finishingNone:ClearAllPoints()
    frame.finishingNone:SetPoint("TOPLEFT", frame, "TOPLEFT", 132, contentTop)
    frame.finishingNone:SetShown(useFinishing and #finishingOptions == 0)
    for rowIndex, row in ipairs(frame.finishingRows or {}) do
        local rowData = finishingOptions[rowIndex]
        if rowData then
            local column = (rowIndex - 1) % finishingColumns
            local line = math.floor((rowIndex - 1) / finishingColumns)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", frame, "TOPLEFT", 14 + (column * 38), contentTop - 18 - (line * 38))
            row.itemID = rowData.option.itemID
            row.icon:SetTexture(GetItemIcon(row.itemID))
            row.selectionMark:Show()
            row:Show()
        else
            row.itemID = nil
            row.selectionMark:Hide()
            row:Hide()
        end
    end
    local optionalTop = contentTop - (useFinishing and (24 + (finishingLineCount * 38)) or 0)
    frame.optionalHeader:ClearAllPoints()
    frame.optionalHeader:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, optionalTop)
    frame.optionalHeader:SetText(useFinishing and "Missives / optionnels" or "Réactifs optionnels")
    frame.optionalHeader:SetShown(#optionalOptions > 0)
    local optionalColumns = 8
    local optionalRows = math.ceil(#optionalOptions / optionalColumns)
    for rowIndex, row in ipairs(frame.optionalRows or {}) do
        local rowData = optionalOptions[rowIndex]
        if rowData then
            local slotIndex = tonumber(rowData.slot.dataSlotIndex)
            local option = rowData.option
            local selections = YQQuality.CopyOptionalSelections(target.optionalSelections)
            local selectionItemID = rowData.selectionItemID or option.itemID
            selections[slotIndex] = selectionItemID
            local selected = rowData.selected == true or rowData.optimized
                or target.optionalSelections[slotIndex] == selectionItemID
            local canReachTarget = true
            if not useFinishing and option.isMissive and not selected then
                local previewKey = selectionKey .. "|" .. tostring(slotIndex) .. ":" .. tostring(option.itemID)
                local preview = state.craft.qualityPreviewStates[previewKey]
                if preview then
                    canReachTarget = YQQuality.FindCandidate(preview, target.quality) ~= nil
                else
                    canReachTarget = false
                    YQQuality.QueuePreviewStateSolve(schematicForm, useConcentration, selections, previewKey)
                end
            end
            local column = (rowIndex - 1) % optionalColumns
            local line = math.floor((rowIndex - 1) / optionalColumns)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", frame, "TOPLEFT", 14 + (column * 38), optionalTop - 18 - (line * 38))
            row.itemID = option.itemID
            row.selectionItemID = selectionItemID
            row.slotIndex = slotIndex
            row.icon:SetTexture(GetItemIcon(option.itemID))
            row.lockedByOptimizer = rowData.optimized == true
            row.selectedFamily = rowData.selected == true
            row:SetEnabled((canReachTarget or selected) and not row.lockedByOptimizer)
            if selected then row:LockHighlight() else row:UnlockHighlight() end
            row.selectionMark:SetShown(selected)
            row:Show()
        else
            row.itemID = nil
            row.selectionItemID = nil
            row.slotIndex = nil
            row.lockedByOptimizer = false
            row.selectedFamily = false
            row.selectionMark:Hide()
            row:Hide()
        end
    end
    frame:SetHeight(math.max(280, 222 + (reagentRowCount * 34) + (finishingLineCount * 38) + (optionalRows * 38)))
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

        local batches, quantity = QueueConcentrationDump(self.schematicForm, dumpState, "button")
        Print(
            "Ajoute " .. quantity .. "x " .. dumpState.context.recipeName
                .. " avec concentration"
                .. (batches and (" (" .. #batches .. " sous-lot(s)).") or ".")
        )
    end)
    dumpConcentrationButton:SetScript("OnEnter", function(self)
        local dumpState = GetConcentrationDumpState(self.schematicForm)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Vider la concentration")
        if dumpState and dumpState.cost > 0 then
            GameTooltip:AddLine(
                "Ajoute " .. dumpState.maxQuantity .. " craft(s) avec concentration ("
                    .. dumpState.availableForDump .. " disponibles après la queue, " .. dumpState.cost .. " par craft).",
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
    local context = GetRecipeContextFromSchematicForm(schematicForm)
    local recipeID = context and tonumber(context.recipeID)
    if recipeID and recipeID ~= button.yayaQueueRecipeID then
        if db.resetQuantityOnRecipeChange then
            SetQuantityInput(button.qtyBox, 1)
            local qualityFrame = state.craft.qualityFrame
            if qualityFrame and qualityFrame.addButton then
                SetQuantityInput(qualityFrame.addButton.qtyBox, 1)
            end
        end
        button.yayaQueueRecipeID = recipeID
    end
    local isVisible = schematicForm:IsShown()
    button:SetShown(isVisible)
    if isVisible then
        button:SetEnabled(context ~= nil)
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
    local context = GetRecipeContextFromSchematicForm(schematicForm)
    local recipeID = context and tonumber(context.recipeID)
    if recipeID and recipeID ~= button.yayaQueueRecipeID then
        if db.resetQuantityOnRecipeChange then
            SetQuantityInput(button.qtyBox, 1)
        end
        button.yayaQueueRecipeID = recipeID
    end
    local isVisible = schematicForm:IsShown()
    button:SetShown(isVisible)
    if isVisible then
        button:SetEnabled(context ~= nil)
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
    local context = GetRecipeContextFromCustomerOrdersForm(orderForm)
    local recipeID = context and tonumber(context.recipeID)
    if recipeID and recipeID ~= button.yayaQueueRecipeID then
        if db.resetQuantityOnRecipeChange then
            SetQuantityInput(button.qtyBox, 1)
        end
        button.yayaQueueRecipeID = recipeID
    end
    local isVisible = orderForm:IsShown()
    button:SetShown(isVisible)
    if isVisible then
        button:SetEnabled(context ~= nil)
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
        ProfessionsFrame and ProfessionsFrame.TabSystem and ProfessionsFrame.TabSystem.tabs
            and ProfessionsFrame.TabSystem.tabs[(ProfessionsFrame.craftingOrdersTabID or 3)],
        ProfessionsFrame and ProfessionsFrame.CraftingPage,
        ProfessionsFrame and ProfessionsFrame.OrdersPage,
        ProfessionsFrame and ProfessionsFrame.OrdersPage and ProfessionsFrame.OrdersPage.OrderView,
        ProfessionsFrame and ProfessionsFrame.OrdersPage and ProfessionsFrame.OrdersPage.OrderView
            and ProfessionsFrame.OrdersPage.OrderView.OrderDetails,
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
                if tonumber(recipeID) ~= CONFIG.SHATTER_ESSENCE_SPELL_ID then
                    QueuePendingCraftRecipe(recipeID, amount)
                end
            end)
        end
        if type(C_TradeSkillUI.CraftEnchant) == "function" then
            hooksecurefunc(C_TradeSkillUI, "CraftEnchant", function(recipeID, amount)
                QueuePendingCraftRecipe(recipeID, amount)
            end)
        end
        if type(C_TradeSkillUI.CraftSalvage) == "function" then
            hooksecurefunc(C_TradeSkillUI, "CraftSalvage", function(recipeID, amount)
                if tonumber(recipeID) ~= CONFIG.SHATTER_ESSENCE_SPELL_ID then
                    QueuePendingCraftRecipe(recipeID, amount)
                end
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
    panel:SetSize(274, CONFIG.CRAFT_PANEL_EXPANDED_HEIGHT)
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
    for index = 1, CONFIG.MAX_CRAFT_LINES do
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

    local nextButton = CreateFrame("Button", nil, panel, "SecureActionButtonTemplate,UIPanelButtonTemplate")
    nextButton:SetSize(120, 22)
    nextButton:SetPoint("BOTTOMRIGHT", -10, 8)
    nextButton:SetText("Next")
    nextButton:RegisterForClicks("AnyUp", "AnyDown")
    -- HookScript preserves SecureActionButtonTemplate's native item handler.
    -- SetScript would replace it and leave the phial click inert.
    nextButton:HookScript("PreClick", function()
        local armedPhial = state.armedIngenuityPhial
        if armedPhial and state.ingenuityBuffActive == true then
            -- The aura may have appeared after the last panel refresh. Clear
            -- the secure action before it can consume a now-unnecessary phial.
            state.armedIngenuityPhial = nil
            if not (InCombatLockdown and InCombatLockdown()) then
                nextButton:SetAttribute("type", nil)
                nextButton:SetAttribute("item", nil)
            end
            state.ah.statusMessage = "Buff d'ingeniosite deja actif"
            DebugPrint("phial-click-skip buff-active item=" .. tostring(armedPhial.itemID))
            ScheduleRefresh()
            return
        end

        local shatter = state.armedShatter
        if not shatter then
            return
        end

        state.armedShatter = nil
        state.pendingShatter = {
            itemID = shatter.itemID,
            expiresAt = GetTime() + 4.0,
            attempts = 0,
        }
        BeginNextActionLock("shatter", 0, 5.0)
        local salvageLocation = GetItemLocationFromItemID(shatter.itemID, true)
        local callOK = type(C_TradeSkillUI) == "table"
            and type(C_TradeSkillUI.CraftSalvage) == "function"
            and salvageLocation ~= nil
            and pcall(
                C_TradeSkillUI.CraftSalvage,
                CONFIG.SHATTER_ESSENCE_SPELL_ID,
                1,
                salvageLocation,
                nil,
                false
            )
        if not callOK then
            state.pendingShatter = nil
            ClearNextActionLock("shatter-call-failed")
            state.ah.statusMessage = salvageLocation and "Shatter indisponible" or "Mote introuvable"
            ScheduleRefresh()
            return
        end

        state.ah.statusMessage = "Shatter en cours"
        C_Timer.After(0.1, YQQuality.ConfirmPendingShatter)
    end)
    nextButton:HookScript("OnClick", function()
        if state.pendingShatter then
            return
        end
        local tool = state.armedCraftTool
        if tool then
            state.armedCraftTool = nil
            local pending = {
                professionID = tool.professionID,
                role = tool.role,
                itemID = tool.itemID,
                itemLink = tool.itemLink,
                expiresAt = GetTime() + 4.0,
            }
            state.pendingCraftTool = pending
            BeginNextActionLock("equip_tool", 0, 4.0)
            state.ah.statusMessage = "Outil en cours d'equipement"
            C_Timer.After(0.15, ScheduleRefresh)
            C_Timer.After(4.2, function()
                if state.pendingCraftTool == pending then
                    state.craftGear.ConfirmPendingTool()
                end
            end)
            return
        end
        local armed = state.armedIngenuityPhial
        if armed then
            state.pendingIngenuityPhial = {
                demandItemID = armed.demandItemID,
                itemID = armed.itemID,
                expiresAt = GetTime() + 2.0,
            }
            state.armedIngenuityPhial = nil
            state.ah.statusMessage = "Phial en cours de consommation"
            C_Timer.After(0.15, ScheduleRefresh)
            return
        end
        local merge = state.armedMerge
        if merge then
            state.armedMerge = nil
            state.pendingMerge = merge
            BeginNextActionLock("merge", 0, 5.0)
            state.ah.statusMessage = "Fusion en cours"
            C_Timer.After(0.15, ScheduleRefresh)
            C_Timer.After(5.2, function()
                if state.pendingMerge == merge then
                    state.pendingMerge = nil
                    ClearNextActionLock("merge-timeout")
                    state.ah.statusMessage = "Fusion non confirmee"
                    ScheduleRefresh()
                end
            end)
            return
        end
        state.RunPatronNextAction()
    end)
    nextButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Next YayaQueue")
        GameTooltip:AddLine("Lance directement la prochaine action en file sans changer la recette ni l'onglet.", 1, 1, 1, true)
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

    local soundCheckbox = CreateFrame("CheckButton", addonName .. "AuctionPriceWarningSound", frame, "UICheckButtonTemplate")
    soundCheckbox:SetPoint("TOPLEFT", helpText, "BOTTOMLEFT", -4, -4)
    local soundLabel = soundCheckbox.Text or soundCheckbox.text
    if not soundLabel then
        soundLabel = soundCheckbox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        soundLabel:SetPoint("LEFT", soundCheckbox, "RIGHT", 2, 1)
        soundCheckbox.Text = soundLabel
    end
    soundLabel:SetText("Jouer un son si le prix est trop haut")
    soundCheckbox:SetScript("OnClick", function(self)
        state.EnsureDB()
        db.auctionPriceWarningSoundEnabled = self:GetChecked() == true
    end)
    frame:SetScript("OnShow", function()
        state.EnsureDB()
        soundCheckbox:SetChecked(db.auctionPriceWarningSoundEnabled ~= false)
    end)

    local totalText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    totalText:SetPoint("TOPLEFT", soundCheckbox, "BOTTOMLEFT", 0, -6)
    totalText:SetPoint("RIGHT", frame, "RIGHT", -14, 0)
    totalText:SetJustifyH("LEFT")
    totalText:SetText("Total estime: ?")

    local lines = {}
    for index = 1, CONFIG.MAX_AH_LINES do
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
                state.OnAuctionActionClick()
    end)

    state.ah.frame = frame
    state.ah.lines = lines
    state.ah.statusText = statusText
    state.ah.totalText = totalText
    state.ah.actionButton = actionButton
    state.ah.soundCheckbox = soundCheckbox
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
            -- TSM can leave the shared LibAHTab button stretched on its first
            -- switch back to Blizzard's AH. YQ has a fixed two-letter label.
            PanelTemplates_TabResize(tab, 20, nil, 70)
            tab:SetWidth(70)
            tab:HookScript("OnShow", function(self)
                PanelTemplates_TabResize(self, 20, nil, 70)
                self:SetWidth(70)
            end)
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
    tab:SetWidth(70)
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
    C_AuctionHouse.SendSearchQuery(itemKey, isCommodity and CONFIG.COMMODITY_SORT or CONFIG.ITEM_SORTS, not isCommodity)
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

function YQQuality.PlacePendingItemPurchase(pending)
    if state.ah.pendingItem ~= pending or type(pending) ~= "table" then
        return false
    end

    local warning = YQQuality.WarnIfAuctionPriceAboveExpected(
        pending.name,
        pending.unitPrice,
        pending.expectedPrice
    )
    state.ah.statusMessage = warning
        and (warning .. " | Achat " .. pending.quantity .. "x " .. pending.name)
        or ("Achat " .. pending.quantity .. "x " .. pending.name)
    C_AuctionHouse.PlaceBid(pending.auctionID, pending.buyoutAmount)
    state.searchCache[pending.itemID] = nil
    C_Timer.After(0.5, ScheduleRefresh)
    ScheduleRefresh()
    return true
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
            kind = "commodity",
            itemID = itemID,
            quantity = quantity,
            name = task.name,
            expectedPrice = cache.expectedPrice,
            expectedSource = cache.expectedSource,
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
        kind = "item",
        itemID = itemID,
        quantity = math.max(1, math.min(task.missing, auction.quantity or 1)),
        name = task.name,
        expectedPrice = cache.expectedPrice,
        expectedSource = cache.expectedSource,
        auctionID = auction.auctionID,
        buyoutAmount = auction.buyoutAmount,
        unitPrice = auction.unitPrice,
        ownedBefore = GetImmediateOwnedCount(itemID),
    }
    local highPrice = YQQuality.GetHighPriceConfirmation(itemID, auction.unitPrice)
    if highPrice then
        state.ah.pendingItem.highPrice = highPrice
        if YQQuality.ShowHighPriceConfirmation(state.ah.pendingItem) then
            state.ah.statusMessage = "Confirmation prix " .. task.name
            ScheduleRefresh()
            return
        end
        state.ah.pendingItem = nil
        state.ah.statusMessage = "Confirmation prix indisponible"
        ScheduleRefresh()
        return
    end

    YQQuality.PlacePendingItemPurchase(state.ah.pendingItem)
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

state.OnAuctionActionClick = function()
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

state.RefreshAll = function()
    InstallRecipeDescriptionGuard()
    if InCombatLockdown and InCombatLockdown() then
        state.refreshDeferredByCombat = true
        return
    end

    state.EnsureDB()
    EnsureProfessionHooks()
    HookCraftAPIs()
    CacheMerchantItems()

    YQQuality.EnsureShatterMoteDemandForEntry(GetNextQueueEntry())
    local summary = BuildQueueSummary()
    PruneSearchCache(summary)
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

addon:SetScript("OnEvent", function(_, event, arg1, arg2, arg3)
    InstallRecipeDescriptionGuard()
    if event == "ADDON_LOADED" then
        if arg1 == "TradeSkillMaster" then
            C_Timer.After(0, UpdateTSMMacroBridge)
            return
        end
        if arg1 ~= addonName then
            return
        end

        state.EnsureDB()
        YQQuality.RefreshIngenuityBuffState("addon-loaded")
        YQQuality.EnsureOptions()
        addon:RegisterEvent("PLAYER_ENTERING_WORLD")
        addon:RegisterEvent("TRADE_SKILL_SHOW")
        addon:RegisterEvent("TRADE_SKILL_DATA_SOURCE_CHANGED")
        addon:RegisterEvent("TRADE_SKILL_CLOSE")
        addon:RegisterEvent("TRADE_SKILL_ITEM_CRAFTED_RESULT")
        addon:RegisterEvent("SPELLS_CHANGED")
        addon:RegisterEvent("SKILL_LINES_CHANGED")
        addon:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
        addon:RegisterEvent("SPELL_DATA_LOAD_RESULT")
        addon:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
        addon:RegisterEvent("BAG_UPDATE_DELAYED")
        addon:RegisterEvent("BANKFRAME_OPENED")
        addon:RegisterEvent("PLAYERBANKSLOTS_CHANGED")
        pcall(addon.RegisterEvent, addon, "PLAYERREAGENTBANKSLOTS_CHANGED")
        pcall(addon.RegisterEvent, addon, "PLAYER_ACCOUNT_BANK_TAB_SLOTS_CHANGED")
        addon:RegisterEvent("MERCHANT_SHOW")
        addon:RegisterEvent("MERCHANT_UPDATE")
        addon:RegisterEvent("AUCTION_HOUSE_SHOW")
        addon:RegisterEvent("AUCTION_HOUSE_CLOSED")
        addon:RegisterEvent("UNIT_SPELLCAST_FAILED")
        addon:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
        addon:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
        addon:RegisterEvent("CRAFTINGORDERS_CLAIMED_ORDER_UPDATED")
        addon:RegisterEvent("CRAFTINGORDERS_CLAIMED_ORDER_REMOVED")
        addon:RegisterEvent("PLAYER_REGEN_ENABLED")
        addon:RegisterEvent("UNIT_AURA")
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
        state.craftGear.ScheduleScan()
        ScheduleRefresh()
        return
    end

    if event == "PLAYER_ENTERING_WORLD" then
        YQQuality.RefreshIngenuityBuffState("player-entering-world")
        UpdateTSMMacroBridge()
        state.craftGear.ScheduleScan()
        ScheduleRefresh()
        return
    end

    if event == "TRADE_SKILL_SHOW" then
        if state.craft.qualityFrame then state.craft.qualityFrame.userClosed = false end
        state.craftGear.ScheduleScan()
        C_Timer.After(0, function()
            if type(_G.YayaCraftingOrdersAPI) ~= "table"
                and type(YayaQueueAPI) == "table"
                and type(YayaQueueAPI.QueueFavoriteConcentration) == "function" then
                YayaQueueAPI.QueueFavoriteConcentration(state.GetCurrentProfessionID())
            end
            StartAlchemyAutoQueue()
        end)
        C_Timer.After(0, ScheduleRefresh)
        return
    end

    if event == "CRAFTINGORDERS_CLAIMED_ORDER_UPDATED" then
        local pending = state.pendingPatronAction
        local claimedOrder = type(C_CraftingOrders) == "table"
            and type(C_CraftingOrders.GetClaimedOrder) == "function"
            and C_CraftingOrders.GetClaimedOrder()
            or nil
        local claimedOrderID = tonumber(claimedOrder and claimedOrder.orderID) or 0
        if claimedOrderID > 0 then
            state.lastClaimedPatronOrderID = claimedOrderID
        end
        if pending and claimedOrderID == pending.orderID then
            if pending.phase == "claim" then
                state.pendingPatronAction = nil
                ClearNextActionLock("patron-claim-confirmed")
                state.ah.statusMessage = "Commande patron demarree"
            elseif pending.phase == "craft" and claimedOrder.isFulfillable then
                state.pendingPatronAction = nil
                ClearNextActionLock("patron-craft-confirmed")
                ClearPendingWorkOrderSubmit(claimedOrderID)
                state.ah.statusMessage = "Craft termine: Claim"
            end
        end
        ScheduleRefresh()
        return
    end

    if event == "CRAFTINGORDERS_CLAIMED_ORDER_REMOVED" then
        local pending = state.pendingPatronAction
        local removedOrderID = tonumber(pending and pending.orderID) or state.lastClaimedPatronOrderID or 0
        state.lastClaimedPatronOrderID = 0
        if pending then
            if pending.phase == "complete" then
                state.FinalizePatronCompletion(pending.orderID, "claimed-order-removed")
            else
                state.RefreshPatronOrder(pending.orderID, pending.professionID, "claimed-order-removed")
            end
        elseif removedOrderID > 0 then
            local entry = state.GetPatronQueueEntry(removedOrderID)
            if entry then
                state.RefreshPatronOrder(removedOrderID, entry.professionID, "claimed-order-removed")
            end
        end
        ScheduleRefresh()
        return
    end

    if event == "TRADE_SKILL_DATA_SOURCE_CHANGED" then
        if state.alchemyAutoQueue.pendingProfessionID ~= false
            and alchemyAuto.IsAlchemyProfession(state.GetCurrentProfessionID())
        then
            StartAlchemyAutoQueue()
        end
        ScheduleRefresh()
        return
    end

    if event == "TRADE_SKILL_CLOSE" then
        state.alchemyAutoQueue.pendingProfessionID = false
        state.alchemyAutoQueue.attempts = 0
        state.firstCraftAvailability = {}
        state.craft.qualityTarget = nil
        YQQuality.CancelRecipeSolve()
        if state.craft.qualityFrame then state.craft.qualityFrame:Hide() end
        DebugPrint("event=TRADE_SKILL_CLOSE pendingEntries=" .. tostring(#state.pendingCraftEntries) .. " pendingBatches=" .. tostring(#state.pendingCraftBatches) .. " lock=" .. tostring(IsCraftClickLocked()))
        if not IsCraftClickLocked() and #state.pendingCraftEntries == 0 and #state.pendingCraftBatches == 0 then
            ClearPendingCraftBatches()
            state.ClearPendingCraftEntries()
        end
        EndCraftClickLock()
        local pendingPatronAction = state.pendingPatronAction
        if pendingPatronAction then
            state.RefreshPatronOrder(
                pendingPatronAction.orderID,
                pendingPatronAction.professionID,
                "trade-skill-close"
            )
        end
        local nextActionLock = GetNextActionLock()
        if nextActionLock and nextActionLock.action == "craft" then
            ClearNextActionLock("trade-skill-close")
        elseif nextActionLock and nextActionLock.action == "equip_tool" then
            state.armedCraftTool = nil
            state.pendingCraftTool = nil
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

            state.EnsureDB()
            local summary = BuildQueueSummary()
            EnsureAuctionUI()
            UpdateAuctionFrame(summary)
            if #summary.auctionTasks > 0 then
                ShowAuctionFrame()
            end
        end)
        return
    end

    if event == "CURRENCY_DISPLAY_UPDATE" then
        local favoriteTracker = state.autoFavoriteConcentration.tracker
        if favoriteTracker and favoriteTracker.awaitingCraft
            and tonumber(arg1) == tonumber(favoriteTracker.concentrationCurrencyID)
        then
            favoriteTracker.currencyEventAmount = tonumber(arg2)
        end
        C_Timer.After(0.25, YQQuality.TryQueueFavoriteConcentrationRefund)
        ScheduleRefresh()
        return
    end

    if event == "TRADE_SKILL_ITEM_CRAFTED_RESULT" then
        state.firstCraftAvailability = {}
        YQQuality.MarkStockDirty(true, false, false)
        state.InvalidateMaterialPricing()
        EndCraftClickLock()
        local itemID = arg1 and arg1.itemID or nil
        local quantity = arg1 and arg1.quantity or nil
        local multicraft = arg1 and arg1.quantityMulticraft or nil
        local favoriteTracker = state.autoFavoriteConcentration.tracker
        local pendingFavoriteEntry = state.pendingCraftEntries[1]
        if favoriteTracker and favoriteTracker.awaitingCraft
            and pendingFavoriteEntry
            and pendingFavoriteEntry.recipeID == favoriteTracker.recipeID
        then
            favoriteTracker.craftConfirmed = true
        end
        DebugPrint("event=TRADE_SKILL_ITEM_CRAFTED_RESULT itemID=" .. tostring(itemID) .. " qty=" .. tostring(quantity) .. " multicraft=" .. tostring(multicraft) .. " pendingEntries=" .. tostring(#state.pendingCraftEntries) .. " pendingBatches=" .. tostring(#state.pendingCraftBatches))
        C_Timer.After(0.5, function()
            state.firstCraftAvailability = {}
            ScheduleRefresh()
        end)
        C_Timer.After(0.5, YQQuality.TryQueueFavoriteConcentrationRefund)
        ScheduleRefresh()
        return
    end

    if event == "SPELLS_CHANGED" or event == "SKILL_LINES_CHANGED"
        or event == "PLAYER_EQUIPMENT_CHANGED" then
        state.firstCraftAvailability = {}
        YQQuality.ClearRecipeCache(true)
        YQQuality.MarkStockDirty(true, false, false)
        state.craftGear.ScheduleScan()
        ScheduleRefresh()
        return
    end

    if event == "PLAYER_REGEN_ENABLED" then
        state.craftGear.ScheduleScan()
        if state.refreshDeferredByCombat then
            state.refreshDeferredByCombat = false
            ScheduleRefresh()
        end
        return
    end

    if event == "UNIT_AURA" and arg1 == "player" then
        local ingenuityBuffActive = YQQuality.RefreshIngenuityBuffState("unit-aura")
        if YQQuality.IsShatterBuffActive() then
            if state.pendingShatter then
                YQQuality.ConfirmPendingShatter()
            else
                YQQuality.RemoveShatterMoteDemand()
            end
        end
        if state.pendingIngenuityPhial and ingenuityBuffActive then
            YQQuality.RemoveConcentrationPhialDemand(state.pendingIngenuityPhial.demandItemID, 1)
            state.pendingIngenuityPhial = nil
            state.ah.statusMessage = "Phial consommee"
        end
        ScheduleRefresh()
        return
    end

    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unit = arg1
        if unit ~= "player" then
            return
        end

        if state.pendingShatter or tonumber(arg3) == CONFIG.SHATTER_ESSENCE_SPELL_ID then
            C_Timer.After(0.1, YQQuality.ConfirmPendingShatter)
            return
        end

        if state.pendingMerge then
            C_Timer.After(0.1, YQQuality.ConfirmPendingMerge)
            return
        end

        local pendingEntry = state.PopPendingCraftEntry()
        local recipeName = ConsumeCraftEntry(pendingEntry)
        if not recipeName then
            local recipeID = PopPendingCraftRecipe()
            recipeName = recipeID and ConsumeCraftFromQueue(recipeID) or nil
        else
            PopPendingCraftRecipe()
        end
        local favoriteTracker = state.autoFavoriteConcentration.tracker
        if favoriteTracker and favoriteTracker.awaitingCraft
            and pendingEntry
            and pendingEntry.recipeID == favoriteTracker.recipeID
        then
            favoriteTracker.craftConfirmed = true
            favoriteTracker.reservationConsumed = recipeName ~= nil
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
        C_Timer.After(0.5, YQQuality.TryQueueFavoriteConcentrationRefund)
        if recipeName then
            state.ah.statusMessage = "Craft termine: " .. recipeName
            ScheduleRefresh()
        end
        return
    end

    if event == "UNIT_SPELLCAST_FAILED" or event == "UNIT_SPELLCAST_INTERRUPTED" then
        local unit = arg1
        if unit == "player" then
            if state.pendingShatter or tonumber(arg3) == CONFIG.SHATTER_ESSENCE_SPELL_ID then
                state.pendingShatter = nil
                ClearNextActionLock(string.lower(tostring(event)))
                state.ah.statusMessage = "Shatter echoue"
                ScheduleRefresh()
                return
            end
            if state.pendingMerge then
                state.pendingMerge = nil
                state.armedMerge = nil
                ClearNextActionLock(string.lower(tostring(event)))
                state.ah.statusMessage = "Fusion echouee"
                ScheduleRefresh()
                return
            end
            if state.autoFavoriteConcentration.tracker then
                state.autoFavoriteConcentration.tracker.awaitingCraft = false
                state.autoFavoriteConcentration.tracker.craftConfirmed = false
                state.autoFavoriteConcentration.tracker.reservationConsumed = false
            end
            DebugPrint("event=" .. tostring(event) .. " pendingEntries=" .. tostring(#state.pendingCraftEntries) .. " pendingBatches=" .. tostring(#state.pendingCraftBatches))
            ClearPendingCraftBatches()
            state.ClearPendingCraftEntries()
            EndCraftClickLock()
            local pendingPatronAction = state.pendingPatronAction
            if pendingPatronAction and pendingPatronAction.phase == "craft" then
                ClearPendingWorkOrderSubmit(pendingPatronAction.orderID)
                state.RefreshPatronOrder(
                    pendingPatronAction.orderID,
                    pendingPatronAction.professionID,
                    string.lower(tostring(event))
                )
            end
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
        -- Les resultats Blizzard ne survivent pas a la fermeture de l'HV.
        -- Evite de reutiliser un auctionID ou une quantite devenue obsolete.
        wipe(state.searchCache)
        HideAuctionFrame()
        ScheduleRefresh()
        return
    end

    if event == "BAG_UPDATE_DELAYED" then
        YQQuality.MarkStockDirty(true, true, true)
        state.InvalidateMaterialPricing()
        state.craftGear.ScheduleScan()
        C_Timer.After(0, YQQuality.ConfirmPendingMerge)
    elseif event == "BANKFRAME_OPENED" then
        YQQuality.MarkStockDirty(false, true, true)
        state.InvalidateMaterialPricing()
        C_Timer.After(0, function()
            YQQuality.ScanStockScope("character")
            YQQuality.ScanStockScope("warband")
        end)
    elseif event == "PLAYERBANKSLOTS_CHANGED" or event == "PLAYERREAGENTBANKSLOTS_CHANGED" then
        YQQuality.MarkStockDirty(false, true, false)
        state.InvalidateMaterialPricing()
        C_Timer.After(0, function() YQQuality.ScanStockScope("character") end)
    elseif event == "PLAYER_ACCOUNT_BANK_TAB_SLOTS_CHANGED" then
        YQQuality.MarkStockDirty(false, false, true)
        state.InvalidateMaterialPricing()
        C_Timer.After(0, function() YQQuality.ScanStockScope("warband") end)
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
        ScheduleAutoBuyVendor(event == "MERCHANT_SHOW" and CONFIG.MERCHANT_AUTO_BUY_INITIAL_DELAY or CONFIG.MERCHANT_AUTO_BUY_RETRY_DELAY)
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
            local pending = state.ah.pendingCommodity
            local unitPrice = tonumber(arg1)
            if (not unitPrice or unitPrice <= 0) and tonumber(arg2) and pending.quantity > 0 then
                unitPrice = math.floor((tonumber(arg2) / pending.quantity) + 0.5)
            end
            if pending.confirmationShown then
                return
            end
            local warning = YQQuality.WarnIfAuctionPriceAboveExpected(
                pending.name,
                unitPrice,
                pending.expectedPrice
            )
            local highPrice = YQQuality.GetHighPriceConfirmation(pending.itemID, unitPrice)
            if highPrice then
                if not pending.confirmationShown then
                    pending.unitPrice = unitPrice
                    pending.highPrice = highPrice
                    pending.confirmationShown = YQQuality.ShowHighPriceConfirmation(pending)
                    if pending.confirmationShown then
                        state.ah.statusMessage = "Confirmation prix " .. pending.name
                        ScheduleRefresh()
                        return
                    end
                end
                if not pending.confirmationShown then
                    state.ah.statusMessage = "Confirmation prix indisponible"
                    if type(C_AuctionHouse.CancelCommoditiesPurchase) == "function" then
                        pcall(C_AuctionHouse.CancelCommoditiesPurchase)
                    end
                    state.ah.pendingCommodity = nil
                    ScheduleRefresh()
                    return
                end
            end
            if warning then
                state.ah.statusMessage = warning .. " | Achat " .. pending.quantity .. "x " .. pending.name
            end
            pending.confirmSent = true
            C_AuctionHouse.ConfirmCommoditiesPurchase(pending.itemID, pending.quantity)
        end
        return
    end

    if event == "COMMODITY_PRICE_UNAVAILABLE" then
        state.ah.statusMessage = "Prix indisponible"
        YQQuality.HideHighPriceConfirmation()
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
        YQQuality.HideHighPriceConfirmation()
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
        local pendingPatronAction = state.pendingPatronAction
        if pendingPatronAction then
            state.RefreshPatronOrder(
                pendingPatronAction.orderID,
                pendingPatronAction.professionID,
                "ui-error"
            )
            return
        end
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

    if context.queueKind == "patron" then
        local orderID = tonumber(context.orderID) or 0
        if orderID <= 0 then
            return false, "Invalid patron orderID"
        end
        context.orderID = orderID
        if WasPatronOrderCompletedRecently(orderID) then
            if CONFIG.debugNextCraft then
                DebugPrint("skip-add-recipe completed-order recipe=" .. tostring(context.recipeID) .. " order=" .. tostring(orderID))
            end
            return false, "Order deja terminee"
        end
        state.EnsureDB()
        for _, entry in ipairs(db.queue) do
            if entry.queueKind == "patron" and (tonumber(entry.orderID) or 0) == orderID then
                if CONFIG.debugNextCraft then
                    DebugPrint("skip-add-recipe duplicate-order recipe=" .. tostring(context.recipeID) .. " order=" .. tostring(orderID))
                end
                return false, "Order deja en file"
            end
        end
    end

    if type(context.recipeName) ~= "string" or context.recipeName == "" then
        context.recipeName = "Recette " .. tostring(context.recipeID)
    end

    context.mode = NormalizeQueueMode(context.mode)
    context.outputPerCraft = math.max(1, tonumber(context.outputPerCraft) or 1)
    context.reagents = NormalizeReagents(context.reagents)
    if CONFIG.debugNextCraft then
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

function YayaQueueAPI.SyncPatronOrders(orderIDs, professionID)
    state.EnsureDB()

    local availableOrderIDs = {}
    for key, value in pairs(type(orderIDs) == "table" and orderIDs or {}) do
        local orderID = value
        if value == true then
            orderID = key
        elseif type(value) == "table" then
            orderID = value.orderID
        end
        orderID = tonumber(orderID) or 0
        if orderID > 0 then
            availableOrderIDs[orderID] = true
        end
    end

    professionID = tonumber(professionID)
    local removed = 0
    local removedOrderIDs = {}
    local claimedOrder = type(C_CraftingOrders) == "table"
        and type(C_CraftingOrders.GetClaimedOrder) == "function"
        and C_CraftingOrders.GetClaimedOrder()
        or nil
    local claimedOrderID = tonumber(claimedOrder and claimedOrder.orderID) or 0
    local ordersPage = ProfessionsFrame and ProfessionsFrame.OrdersPage
    local currentOrder = ordersPage and ordersPage.OrderView and ordersPage.OrderView.order
    local currentOrderID = tonumber(currentOrder and currentOrder.orderID) or 0
    local nextActionLock = GetNextActionLock()
    local lockedOrderID = tonumber(nextActionLock and nextActionLock.orderID) or 0
    local pendingPatronAction = state.pendingPatronAction
    local pendingOrderID = tonumber(pendingPatronAction and pendingPatronAction.orderID) or 0
    for index = #db.queue, 1, -1 do
        local entry = db.queue[index]
        local sameProfession = not professionID or tonumber(entry.professionID) == professionID
        local orderID = tonumber(entry.orderID) or 0
        local isActive = (orderID > 0 and orderID == claimedOrderID)
            or (orderID > 0 and orderID == currentOrderID)
            or (orderID > 0 and orderID == lockedOrderID)
            or (orderID > 0 and orderID == pendingOrderID)
        if entry.queueKind == "patron" and sameProfession and not availableOrderIDs[orderID] and not isActive then
            removedOrderIDs[orderID] = true
            table.remove(db.queue, index)
            removed = removed + 1
        end
    end

    if removed > 0 then
        state.InvalidateQualityPricing()
        DebugPrint("sync-patron-orders profession=" .. tostring(professionID) .. " removed=" .. tostring(removed))
        ScheduleRefresh()
    end

    return removed, removedOrderIDs
end

function YayaQueueAPI.AddItem(itemID, quantity, itemName)
    state.EnsureDB()
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
        if entry.queueKind == "direct_item"
            and entry.itemID == directEntry.itemID
            and entry.shatterMote ~= true
        then
            entry.directQuantity = ClampQuantity((entry.directQuantity or 0) + directEntry.directQuantity)
            entry.itemName = directEntry.itemName
            state.searchCache[entry.itemID] = nil
            state.InvalidateQualityPricing()
            state.ah.statusMessage = "Ajoute " .. entry.directQuantity .. "x " .. entry.itemName
            ScheduleRefresh()
            return true
        end
    end

    table.insert(db.queue, directEntry)
    state.searchCache[directEntry.itemID] = nil
    state.InvalidateQualityPricing()
    state.ah.statusMessage = "Ajoute " .. directEntry.directQuantity .. "x " .. directEntry.itemName
    ScheduleRefresh()
    return true
end

function YayaQueueAPI.GetDirectItemQuantity(itemID)
    state.EnsureDB()
    itemID = tonumber(itemID) or 0
    if itemID <= 0 then
        return 0
    end

    local quantity = 0
    for _, entry in ipairs(db.queue) do
        if entry.queueKind == "direct_item" and tonumber(entry.itemID) == itemID then
            quantity = quantity + math.max(0, math.floor(tonumber(entry.directQuantity) or 0))
        end
    end
    return quantity
end

function YayaQueueAPI.RemoveItem(itemID, quantity)
    state.EnsureDB()
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
        state.InvalidateQualityPricing()
        DebugPrint("remove-item item=" .. tostring(itemID) .. " removed=" .. tostring(removedQuantity))
        state.ah.statusMessage = "Retire " .. removedQuantity .. "x " .. itemName
        ScheduleRefresh()
    end
    return true, removedQuantity
end

function YayaQueueAPI.SetItemTarget(itemID, quantity, itemName)
    state.EnsureDB()
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
        if entry.queueKind == "direct_item"
            and entry.itemID == directEntry.itemID
            and entry.shatterMote ~= true
        then
            entry.directQuantity = directEntry.directQuantity
            entry.itemName = directEntry.itemName
            state.searchCache[entry.itemID] = nil
            state.InvalidateQualityPricing()
            DebugPrint("set-item-target item=" .. tostring(entry.itemID) .. " target=" .. tostring(entry.directQuantity))
            state.ah.statusMessage = "Objectif " .. entry.directQuantity .. "x " .. entry.itemName
            ScheduleRefresh()
            return true
        end
    end

    table.insert(db.queue, directEntry)
    state.searchCache[directEntry.itemID] = nil
    state.InvalidateQualityPricing()
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

function YayaQueueAPI.GetQueuedConcentrationReservation(professionID, currencyID)
    return GetQueuedConcentrationReservation(professionID, currencyID)
end

function YayaQueueAPI.QueueFavoriteConcentration(professionID)
    state.EnsureDB()
    professionID = tonumber(professionID) or state.GetCurrentProfessionID()
    if not professionID then
        return false, "Profession unavailable"
    end

    if type(C_TradeSkillUI) == "table"
        and type(C_TradeSkillUI.GetProfessionChildSkillLineID) == "function"
        and type(C_TradeSkillUI.GetConcentrationCurrencyID) == "function" then
        local skillLineID = SafeCall(C_TradeSkillUI.GetProfessionChildSkillLineID)
        local currencyID = skillLineID and SafeCall(C_TradeSkillUI.GetConcentrationCurrencyID, skillLineID) or nil
        if not currencyID then
            DebugPrint("auto-favorite skip profession=" .. tostring(professionID) .. " reason=no-concentration")
            return false, "No concentration"
        end
    end

    local autoQueue = state.autoFavoriteConcentration
    if autoQueue.queuedByProfession[professionID] then
        return false, "Already handled"
    end
    if not autoQueue.pending or autoQueue.pending.professionID ~= professionID then
        autoQueue.pending = {
            professionID = professionID,
            attempts = 0,
            openRequested = false,
        }
    end
    YQQuality.ScheduleAutoQueueFavoriteConcentration(0)
    return true
end

function YayaQueueAPI.HasPatronOrder(orderID)
    state.EnsureDB()
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
        CONFIG.debugNextCraft = not CONFIG.debugNextCraft
        Print("Debug " .. (CONFIG.debugNextCraft and "active" or "inactif"))
        return
    end
    if command == "options" then
        YQQuality.OpenOptions()
        return
    end
    if command == "optimizer test" or command == "opttest" then
        local optimizer = state.addonTable and state.addonTable.QualityOptimizer
        local ok, message = false, "module absent"
        if optimizer then ok, message = optimizer.RunSelfTests() end
        Print(ok and ("Optimiseur OK : " .. tostring(message)) or ("Optimiseur KO : " .. tostring(message)))
        return
    end
    if command == "vendor on" or command == "vendor off" then
        state.EnsureDB()
        db.autoBuyVendor = command == "vendor on"
        Print("Achat automatique marchand " .. (db.autoBuyVendor and "active" or "inactif") .. ".")
        return
    end
    if command == "vendor" or command == "vendor status" then
        state.EnsureDB()
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
