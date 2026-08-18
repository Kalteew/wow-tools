local addonName = ...

local UPDATE_INTERVAL_SECONDS = 15
local IGNORE_WINDOW_SECONDS = 10
local OUTGOING_MAIL_WINDOW_SECONDS = 30
local MISSION_REWARD_CLAIM_TTL_SECONDS = 600
local MISSION_CONTAINER_PENDING_TTL_SECONDS = 30 * 24 * 60 * 60
local MISSION_CONTAINER_FINALIZE_DELAY_SECONDS = 1.25
local MAX_SESSIONS = 250
local CORROSIVE_COIN_CURRENCY_ID = 3448
local DEFAULT_PRICE_SOURCE = "first(dbmarket, dbregionmarketavg, vendorsell)"
local ITEM_BIND_ON_ACQUIRE = LE_ITEM_BIND_ON_ACQUIRE or (Enum and Enum.ItemBind and Enum.ItemBind.OnAcquire) or 1
local ITEM_BIND_QUEST = LE_ITEM_BIND_QUEST or (Enum and Enum.ItemBind and Enum.ItemBind.Quest) or 4
local FOLLOWER_TYPE_ID = Enum and Enum.GarrisonFollowerType and Enum.GarrisonFollowerType.FollowerType_9_0_GarrisonFollower or 123
local BLIZZARD_GARRISON_UI_ADDON = "Blizzard_GarrisonUI"
local REPLENISH_THE_RESERVOIR_QUEST_IDS = {
    61981,
    61982,
    61983,
    61984,
}
local DEFAULT_POSITION = {
    point = "TOPLEFT",
    relativePoint = "TOPRIGHT",
    x = 14,
    y = -8,
}

local eventFrame
local trackerFrame
local updateTicker
local activeSession
local lastMoney
local UpdateFrame
local lootPatterns = {}
local hookState = {}
local playerInfo = {
    name = nil,
    realm = nil,
    fullName = nil,
}
local pendingIgnoredIncome = {}
local pendingIgnoredExpense = {}
local pendingIgnoredLoot = {}
local pendingOutgoingMail = {}
local activeMissionTableActivity
local activeReplenishActivity
local activeMissionContainerOpen
local FinalizeActivityState
local missionContainerFinalizeToken = 0
local pendingMissionRewardClaims = {}
local missionHistoryByID = {}
local missionHistoryByMissionID = {}
local lastMissionReportSeenAt = {}
local knownInProgressMissions = {}

local function GetNow()
    return time and time() or 0
end

local function FormatTimestamp(value)
    if date then
        return date("%Y-%m-%d %H:%M:%S", value or GetNow())
    end
    return tostring(value or 0)
end

local function Clamp(value, minValue)
    if value < minValue then
        return minValue
    end
    return value
end

local function IsAddOnLoadedCompat(addon)
    if C_AddOns and C_AddOns.IsAddOnLoaded then
        return C_AddOns.IsAddOnLoaded(addon)
    end
    if IsAddOnLoaded then
        return IsAddOnLoaded(addon)
    end
    return false
end

local function NormalizeName(value)
    if not value or value == "" then
        return
    end

    return strtrim(value):lower()
end

local function GetShortName(value)
    if not value or value == "" then
        return
    end

    return value:match("^([^%-]+)")
end

local function GetPlayerKey()
    local name = UnitName and UnitName("player")
    if not name or name == "" then
        return
    end

    local realm = GetRealmName and GetRealmName() or ""
    if realm ~= "" then
        return realm .. "." .. name
    end
    return name
end

local function GetPlayerFullName()
    local name = UnitName and UnitName("player")
    if not name or name == "" then
        return
    end

    local realm = GetRealmName and GetRealmName() or ""
    if realm ~= "" then
        return name .. "-" .. realm
    end
    return name
end

local function GetItemIDFromLink(itemLink)
    if not itemLink or itemLink == "" then
        return
    end

    if C_Item and C_Item.GetItemInfoInstant then
        local itemID = C_Item.GetItemInfoInstant(itemLink)
        if itemID and itemID > 0 then
            return itemID
        end
    end

    local itemID = itemLink:match("item:(%d+)")
    return itemID and tonumber(itemID) or nil
end

local function GetItemStringFromID(itemID)
    if not itemID then
        return
    end
    return "i:" .. tostring(itemID)
end

local function GetAccountDB()
    YayaSessionTrackerDB = YayaSessionTrackerDB or {}
    return YayaSessionTrackerDB
end

local function GetSettings()
    local db = GetAccountDB()
    db.settings = db.settings or {}
    db.settings.priceSource = db.settings.priceSource or DEFAULT_PRICE_SOURCE
    db.settings.position = db.settings.position or {}
    return db.settings
end

local function GetSessions()
    local db = GetAccountDB()
    db.sessions = db.sessions or {}
    return db.sessions
end

local function GetActivities()
    local db = GetAccountDB()
    db.activities = db.activities or {}
    return db.activities
end

local function GetShadowlandsMissionHistory()
    local db = GetAccountDB()
    db.shadowlandsMissionHistory = db.shadowlandsMissionHistory or {}
    return db.shadowlandsMissionHistory
end

local function GetShadowlandsMissionContainerHistory()
    local db = GetAccountDB()
    db.shadowlandsMissionContainerHistory = db.shadowlandsMissionContainerHistory or {}
    return db.shadowlandsMissionContainerHistory
end

local function GetPendingMissionContainers()
    local db = GetAccountDB()
    db.pendingMissionContainers = db.pendingMissionContainers or {}
    return db.pendingMissionContainers
end

local function GetNextHistoryID(fieldName)
    local db = GetAccountDB()
    db[fieldName] = db[fieldName] or 1
    local historyID = db[fieldName]
    db[fieldName] = historyID + 1
    return historyID
end

local function GetKnownCharacters()
    local db = GetAccountDB()
    db.knownCharacters = db.knownCharacters or {}
    return db.knownCharacters
end

local function IsTSMAvailable()
    return type(TSM_API) == "table"
        and type(TSM_API.ToItemString) == "function"
        and type(TSM_API.GetCustomPriceValue) == "function"
end

local function GetPriceSource()
    return GetSettings().priceSource or DEFAULT_PRICE_SOURCE
end

local function IsSavedPosition(position)
    return position
        and position.point
        and position.relativePoint
        and position.x
        and position.y
end

local function GetFramePosition()
    local settings = GetSettings()
    if IsSavedPosition(settings.position) then
        return settings.position
    end
    return DEFAULT_POSITION
end

local function SaveFramePosition()
    if not YayaFrameAPI or type(YayaFrameAPI.SavePosition) ~= "function" then
        return
    end
    YayaFrameAPI:SavePosition()
end

local function ApplyFramePosition()
    if not YayaFrameAPI or type(YayaFrameAPI.ApplyPosition) ~= "function" then
        return
    end
    YayaFrameAPI:ApplyPosition()
end

local function ResetFramePosition()
    if YayaFrameAPI and type(YayaFrameAPI.ResetPosition) == "function" then
        YayaFrameAPI:ResetPosition()
    end
end

local function RegisterKnownCharacter()
    local knownCharacters = GetKnownCharacters()
    if playerInfo.name then
        knownCharacters[NormalizeName(playerInfo.name)] = true
    end
    if playerInfo.fullName then
        knownCharacters[NormalizeName(playerInfo.fullName)] = true
    end
end

local function IsKnownCharacter(name)
    local normalizedName = NormalizeName(name)
    if not normalizedName then
        return false
    end

    local knownCharacters = GetKnownCharacters()
    if knownCharacters[normalizedName] then
        return true
    end

    local shortName = GetShortName(normalizedName)
    return shortName and knownCharacters[shortName] or false
end

local function FormatGoldCompact(copper)
    local negative = copper < 0
    local absCopper = math.abs(copper)
    local goldValue = absCopper / 10000
    local text

    if goldValue >= 100000 then
        text = string.format("%.0fk", goldValue / 1000)
    elseif goldValue >= 10000 then
        text = string.format("%.1fk", goldValue / 1000)
    elseif goldValue >= 100 then
        text = string.format("%.0fg", goldValue)
    elseif goldValue >= 10 then
        text = string.format("%.1fg", goldValue)
    elseif absCopper >= 100 then
        text = string.format("%ds", math.floor(absCopper / 100))
    else
        text = string.format("%dc", absCopper)
    end

    if negative then
        return "-" .. text
    end
    return text
end

local function FormatDurationCompact(seconds)
    local totalSeconds = math.max(0, math.floor(seconds))
    local hours = math.floor(totalSeconds / 3600)
    local minutes = math.floor((totalSeconds % 3600) / 60)
    local secs = totalSeconds % 60

    if hours > 0 then
        return string.format("%02d:%02d", hours, minutes)
    end
    return string.format("%02d:%02d", minutes, secs)
end

local function BuildLootPatterns()
    wipe(lootPatterns)

    local templates = {
        { LOOT_ITEM_SELF_MULTIPLE, true },
        { LOOT_ITEM_PUSHED_SELF_MULTIPLE, true },
        { LOOT_ITEM_SELF, false },
        { LOOT_ITEM_PUSHED_SELF, false },
    }

    for _, entry in ipairs(templates) do
        local template = entry[1]
        if type(template) == "string" and template ~= "" then
            local pattern = template
                :gsub("%%s", "(.+)")
                :gsub("%%d", "(%%d+)")
            lootPatterns[#lootPatterns + 1] = {
                pattern = "^" .. pattern .. "$",
                hasQuantity = entry[2],
            }
        end
    end
end

local function AddIgnoredGold(queue, amount)
    if not amount or amount <= 0 then
        return
    end

    queue[#queue + 1] = {
        amount = amount,
        expiresAt = GetNow() + IGNORE_WINDOW_SECONDS,
    }
end

local function AddIgnoredLoot(itemString, quantity)
    if not itemString or not quantity or quantity <= 0 then
        return
    end

    pendingIgnoredLoot[#pendingIgnoredLoot + 1] = {
        itemString = itemString,
        quantity = quantity,
        expiresAt = GetNow() + IGNORE_WINDOW_SECONDS,
    }
end

local function CleanupQueue(queue)
    local now = GetNow()
    for index = #queue, 1, -1 do
        local entry = queue[index]
        if not entry or entry.amount == 0 or (entry.expiresAt and entry.expiresAt <= now) then
            table.remove(queue, index)
        end
    end
end

local function CleanupLootQueue()
    local now = GetNow()
    for index = #pendingIgnoredLoot, 1, -1 do
        local entry = pendingIgnoredLoot[index]
        if not entry or entry.quantity == 0 or (entry.expiresAt and entry.expiresAt <= now) then
            table.remove(pendingIgnoredLoot, index)
        end
    end
end

local function ClearPendingState()
    wipe(pendingIgnoredIncome)
    wipe(pendingIgnoredExpense)
    wipe(pendingIgnoredLoot)
    wipe(pendingOutgoingMail)
end

local function ConsumeIgnoredGold(queue, amount)
    CleanupQueue(queue)

    local remaining = amount
    local consumed = 0
    for _, entry in ipairs(queue) do
        if remaining <= 0 then
            break
        end

        local delta = math.min(entry.amount, remaining)
        entry.amount = entry.amount - delta
        remaining = remaining - delta
        consumed = consumed + delta
    end

    CleanupQueue(queue)
    return consumed
end

local function ConsumeIgnoredLoot(itemString, quantity)
    CleanupLootQueue()

    local remaining = quantity
    for _, entry in ipairs(pendingIgnoredLoot) do
        if remaining <= 0 then
            break
        end

        if entry.itemString == itemString and entry.quantity > 0 then
            local delta = math.min(entry.quantity, remaining)
            entry.quantity = entry.quantity - delta
            remaining = remaining - delta
        end
    end

    CleanupLootQueue()
    return remaining
end

local function TrimSessions()
    local sessions = GetSessions()
    while #sessions > MAX_SESSIONS do
        table.remove(sessions, 1)
    end
end

local function GetCurrentZoneName()
    return GetRealZoneText and GetRealZoneText() or GetZoneText and GetZoneText() or ""
end

local function GetPlayerLevel()
    return UnitLevel and UnitLevel("player") or 0
end

local function GetPlayerMaxLevel()
    if GetMaxPlayerLevel then
        return GetMaxPlayerLevel()
    end
    if C_PlayerInfo and C_PlayerInfo.GetMaxLevel then
        return C_PlayerInfo.GetMaxLevel()
    end
    return 0
end

local function IsPlayerAtMaxLevel()
    local maxLevel = GetPlayerMaxLevel()
    return maxLevel > 0 and GetPlayerLevel() >= maxLevel
end

local function GetCurrentXP()
    return UnitXP and UnitXP("player") or 0
end

local function GetCurrentXPMax()
    return UnitXPMax and UnitXPMax("player") or 0
end

local function NewSession()
    local db = GetAccountDB()
    db.nextSessionID = db.nextSessionID or 1

    local session = {
        id = db.nextSessionID,
        playerKey = GetPlayerKey(),
        playerName = playerInfo.name,
        playerFullName = playerInfo.fullName,
        realm = playerInfo.realm,
        startedAt = GetNow(),
        lastSeenAt = GetNow(),
        zone = GetCurrentZoneName(),
        priceSource = GetPriceSource(),
        gold = {
            total = 0,
            earned = 0,
            spent = 0,
            ignoredIncome = 0,
            ignoredExpense = 0,
        },
        items = {},
        currencyGains = {},
        itemCount = 0,
        xp = {
            gained = 0,
            lastXP = GetCurrentXP(),
            lastXPMax = GetCurrentXPMax(),
        },
    }

    db.nextSessionID = db.nextSessionID + 1
    return session
end

local function GetItemStringFromLink(itemLink)
    if not itemLink or itemLink == "" or not IsTSMAvailable() then
        return
    end

    local ok, itemString = pcall(TSM_API.ToItemString, itemLink)
    if ok and itemString and itemString ~= "" then
        return itemString
    end
end

local function GetItemName(itemString, itemLink)
    local name = itemLink and GetItemInfo and GetItemInfo(itemLink)
    if name and name ~= "" then
        return name
    end

    if IsTSMAvailable() and itemString then
        local ok, itemName = pcall(TSM_API.GetItemName, itemString)
        if ok and itemName and itemName ~= "" then
            return itemName
        end
    end
end

local function GetItemDetails(itemRef)
    if not itemRef or not GetItemInfo then
        return
    end

    local name, _, quality, _, _, _, _, _, _, _, sellPrice, _, _, bindType = GetItemInfo(itemRef)
    return name, quality, sellPrice or 0, bindType
end

local function IsWarboundUntilEquipped(itemRef)
    return itemRef
        and C_Item
        and C_Item.IsItemBindToAccountUntilEquip
        and C_Item.IsItemBindToAccountUntilEquip(itemRef) == true
end

local function IsSoulbound(itemRef, bindType)
    if bindType == ITEM_BIND_ON_ACQUIRE or bindType == ITEM_BIND_QUEST then
        return true
    end

    if itemRef and C_Item and C_Item.IsItemSoulbound then
        local ok, isSoulbound = pcall(C_Item.IsItemSoulbound, itemRef)
        return ok and isSoulbound == true
    end
    return false
end

local function GetUnitPrice(entry, priceSource)
    local knownBindType = entry.itemBindType
    if knownBindType == nil then
        local _, _, _, resolvedBindType = GetItemDetails(entry.itemLink or entry.itemString)
        knownBindType = resolvedBindType
    end
    if IsSoulbound(entry.itemLink or entry.itemString, knownBindType) then
        return 0
    end

    local containerAPI = _G.YayaContainerValuesAPI
    local itemID = entry.itemID or GetItemIDFromLink(entry.itemLink)
    if not itemID and type(entry.itemString) == "string" then
        itemID = tonumber(entry.itemString:match("^i:(%d+)$"))
    end
    if containerAPI and type(containerAPI.GetAverageValue) == "function" and itemID then
        local ok, containerValue, sampleCount, containerState = pcall(containerAPI.GetAverageValue, itemID)
        if ok and type(containerValue) == "number" and containerValue > 0 and (sampleCount or 0) > 0 then
            return containerValue
        end
        if ok and containerState == "missing_price" and (sampleCount or 0) > 0 then
            return 0
        end
    end

    local itemQuality = entry.itemQuality
    local sellPrice = entry.vendorSellPrice
    local itemBindType = entry.itemBindType

    if itemQuality == nil or itemBindType == nil then
        local _, resolvedQuality, resolvedSellPrice, resolvedBindType = GetItemDetails(entry.itemLink or entry.itemString)
        itemQuality = resolvedQuality
        if resolvedSellPrice and resolvedSellPrice > 0 then
            sellPrice = resolvedSellPrice
        end
        itemBindType = resolvedBindType
    end

    if IsSoulbound(entry.itemLink or entry.itemString, itemBindType) then
        return 0
    end

    if itemQuality == 0 then
        if sellPrice and sellPrice > 0 then
            return sellPrice
        end

        local _, quality, sellPrice = GetItemDetails(entry.itemLink)
        if quality == 0 and sellPrice and sellPrice > 0 then
            return sellPrice
        end
        return 0
    end

    if not entry.itemString or not IsTSMAvailable() then
        return 0
    end

    local ok, price = pcall(TSM_API.GetCustomPriceValue, priceSource or GetPriceSource(), entry.itemString)
    if ok and type(price) == "number" and price > 0 then
        return price
    end
    return 0
end

local function BuildItemSummary(entry, priceSource)
    local unitPrice = GetUnitPrice(entry, priceSource)
    local totalValue = unitPrice * (entry.quantity or 0)
    return {
        itemString = entry.itemString,
        itemLink = entry.itemLink,
        itemName = entry.itemName or GetItemName(entry.itemString, entry.itemLink) or entry.itemString,
        quantity = entry.quantity or 0,
        unitPrice = unitPrice,
        totalValue = totalValue,
    }
end

local function BuildItemSummaryFromItem(itemID, quantity, itemLink, priceSource)
    if not itemID and not itemLink then
        return
    end

    local resolvedItemID = itemID or GetItemIDFromLink(itemLink)
    local itemString = GetItemStringFromLink(itemLink) or GetItemStringFromID(resolvedItemID)
    local itemName, itemQuality, vendorSellPrice, itemBindType = GetItemDetails(itemLink or resolvedItemID)
    local entry = {
        itemID = resolvedItemID,
        itemString = itemString,
        itemLink = itemLink,
        itemName = itemName or GetItemName(itemString, itemLink),
        itemQuality = itemQuality,
        vendorSellPrice = vendorSellPrice or 0,
        itemBindType = itemBindType,
        quantity = quantity or 1,
    }

    local summary = BuildItemSummary(entry, priceSource)
    summary.itemID = resolvedItemID
    return summary
end

local function IsQuestDone(questID)
    if C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then
        return C_QuestLog.IsQuestFlaggedCompleted(questID)
    end
    if IsQuestFlaggedCompleted then
        return IsQuestFlaggedCompleted(questID)
    end
    return false
end

local function IsAnyQuestDone(questIDs)
    for _, questID in ipairs(questIDs or {}) do
        if IsQuestDone(questID) then
            return true
        end
    end
    return false
end

local function FindQuestLogIndexByQuestID(questID)
    if not questID then
        return
    end

    if C_QuestLog and C_QuestLog.GetLogIndexForQuestID then
        local index = C_QuestLog.GetLogIndexForQuestID(questID)
        if index and index > 0 then
            return index
        end
    end

    if GetQuestLogIndexByID then
        local index = GetQuestLogIndexByID(questID)
        if index and index > 0 then
            return index
        end
    end
end

local function ExtractProgressText(text)
    if type(text) ~= "string" or text == "" then
        return
    end

    local current, total = text:match("(%d+)%s*/%s*(%d+)")
    if current and total then
        return current .. "/" .. total, tonumber(current), tonumber(total)
    end
end

local function GetQuestObjectiveProgressText(questID)
    if C_QuestLog and C_QuestLog.GetQuestObjectives then
        local objectives = C_QuestLog.GetQuestObjectives(questID) or {}
        for _, objective in ipairs(objectives) do
            local progressText, current, total = ExtractProgressText(objective and objective.text)
            if progressText then
                return progressText, current, total
            end
        end
    end

    local questLogIndex = FindQuestLogIndexByQuestID(questID)
    if questLogIndex and GetNumQuestLeaderBoards and GetQuestLogLeaderBoard then
        local objectiveCount = GetNumQuestLeaderBoards(questLogIndex) or 0
        for objectiveIndex = 1, objectiveCount do
            local objectiveText = GetQuestLogLeaderBoard(objectiveIndex, questLogIndex)
            local progressText, current, total = ExtractProgressText(objectiveText)
            if progressText then
                return progressText, current, total
            end
        end
    end
end

local function GetQuestInfoByQuestID(questID)
    local questLogIndex = FindQuestLogIndexByQuestID(questID)
    if not questLogIndex then
        return
    end

    if C_QuestLog and C_QuestLog.GetInfo then
        local info = C_QuestLog.GetInfo(questLogIndex)
        if info then
            return {
                questID = questID,
                title = info.title,
                isComplete = info.isComplete,
            }
        end
    end

    if GetQuestLogTitle then
        local title, _, _, isHeader, _, isComplete = GetQuestLogTitle(questLogIndex)
        if not isHeader then
            return {
                questID = questID,
                title = title,
                isComplete = isComplete == 1,
            }
        end
    end
end

local function GetActiveReplenishState()
    for _, questID in ipairs(REPLENISH_THE_RESERVOIR_QUEST_IDS) do
        local info = GetQuestInfoByQuestID(questID)
        if info then
            local progressText, current, total = GetQuestObjectiveProgressText(questID)
            return {
                isActive = true,
                questID = questID,
                title = info.title or "Replenish the Reservoir",
                isComplete = info.isComplete and true or false,
                progressText = progressText or "0/1000",
                progressCurrent = current,
                progressTotal = total,
            }
        end
    end

    return {
        isActive = false,
        isAvailable = not IsAnyQuestDone(REPLENISH_THE_RESERVOIR_QUEST_IDS),
    }
end

local function AllocateHistoryEntryID(nextField)
    return GetNextHistoryID(nextField)
end

local function StoreMissionHistoryEntry(entry)
    if not entry.id then
        entry.id = AllocateHistoryEntryID("nextMissionHistoryID")
        local history = GetShadowlandsMissionHistory()
        history[#history + 1] = entry
    end

    missionHistoryByID[entry.id] = entry
    if entry.missionID then
        missionHistoryByMissionID[entry.missionID] = entry
    end
    return entry
end

local function StoreActivityEntry(entry)
    if not entry.id then
        entry.id = AllocateHistoryEntryID("nextActivityHistoryID")
    end

    local history = GetActivities()
    history[#history + 1] = entry
    return entry
end

local function StoreMissionContainerHistoryEntry(entry)
    if not entry.id then
        entry.id = AllocateHistoryEntryID("nextMissionContainerHistoryID")
    end

    local history = GetShadowlandsMissionContainerHistory()
    history[#history + 1] = entry
    return entry
end

local function NewActivityEntry(kind)
    local now = GetNow()
    return {
        id = AllocateHistoryEntryID("nextActivityHistoryID"),
        kind = kind,
        sessionID = activeSession and activeSession.id or nil,
        playerKey = GetPlayerKey(),
        playerName = playerInfo.name,
        playerFullName = playerInfo.fullName,
        realm = playerInfo.realm,
        startedAt = now,
        startedDate = FormatTimestamp(now),
        zone = GetCurrentZoneName(),
    }
end

local function FinalizeActivityEntry(entry, reason)
    if not entry then
        return
    end

    local now = GetNow()
    entry.endedAt = entry.endedAt or now
    entry.endedDate = entry.endedDate or FormatTimestamp(entry.endedAt)
    entry.durationSeconds = Clamp((entry.endedAt or now) - (entry.startedAt or now), 1)
    entry.endReason = reason or entry.endReason
    StoreActivityEntry(entry)
end

local function GetMissionHistoryEntryByID(historyID)
    return historyID and missionHistoryByID[historyID] or nil
end

local function GetMissionSecondaryCurrencyID()
    if not C_Garrison or not C_Garrison.GetCurrencyTypes then
        return
    end

    local _, currencyID = C_Garrison.GetCurrencyTypes(123)
    return currencyID
end

local function BuildMissionRewardsSnapshot(rewards, priceSource)
    local snapshots = {}

    for _, reward in pairs(rewards or {}) do
        local snapshot = {
            title = reward.title,
            quantity = reward.quantity,
            itemID = reward.itemID,
            currencyID = reward.currencyID,
            followerXP = reward.followerXP,
            quality = reward.quality,
        }

        if reward.itemID then
            local itemSummary = BuildItemSummaryFromItem(reward.itemID, reward.quantity or 1, nil, priceSource)
            if itemSummary then
                snapshot.itemName = itemSummary.itemName
                snapshot.itemValue = itemSummary.totalValue
                snapshot.unitPrice = itemSummary.unitPrice
            end
        end

        if reward.currencyID and C_CurrencyInfo and C_CurrencyInfo.IsCurrencyContainer and C_CurrencyInfo.IsCurrencyContainer(reward.currencyID, reward.quantity) then
            if CurrencyContainerUtil and CurrencyContainerUtil.GetCurrencyContainerInfo then
                local name, _, quantity, quality = CurrencyContainerUtil.GetCurrencyContainerInfo(reward.currencyID, reward.quantity)
                snapshot.currencyContainerName = name
                snapshot.currencyContainerQuantity = quantity
                snapshot.currencyContainerQuality = quality
            end
        end

        snapshots[#snapshots + 1] = snapshot
    end

    return snapshots
end

local function BuildMissionFollowerSnapshot(frame, missionInfo)
    local followers = {}
    local missionPage = frame and frame.GetMissionPage and frame:GetMissionPage() or nil
    local board = missionPage and missionPage.Board or nil

    if board and board.EnumerateFollowers then
        for followerFrame in board:EnumerateFollowers() do
            local info = followerFrame.info
            if info then
                followers[#followers + 1] = {
                    boardIndex = followerFrame.boardIndex,
                    followerID = info.followerID,
                    garrFollowerID = info.garrFollowerID,
                    name = info.name,
                    level = info.level,
                    quality = info.quality,
                    isTroop = info.isTroop or info.isAutoTroop or false,
                    attack = info.autoCombatantStats and info.autoCombatantStats.attack or nil,
                    currentHealth = info.autoCombatantStats and info.autoCombatantStats.currentHealth or nil,
                    maxHealth = info.autoCombatantStats and info.autoCombatantStats.maxHealth or nil,
                }
            end
        end
    elseif missionInfo and missionInfo.followers then
        for _, followerID in ipairs(missionInfo.followers) do
            followers[#followers + 1] = {
                followerID = followerID,
                name = C_Garrison and C_Garrison.GetFollowerName and C_Garrison.GetFollowerName(followerID) or tostring(followerID),
            }
        end
    end

    table.sort(followers, function(left, right)
        return (left.boardIndex or 99) < (right.boardIndex or 99)
    end)

    return followers
end

local function CleanupPendingMissionRewardClaims()
    local now = GetNow()
    for index = #pendingMissionRewardClaims, 1, -1 do
        local claim = pendingMissionRewardClaims[index]
        if not claim or not claim.itemID or (claim.expiresAt and claim.expiresAt <= now) or (claim.remainingQuantity or 0) <= 0 then
            table.remove(pendingMissionRewardClaims, index)
        end
    end
end

local function CleanupPendingMissionContainers()
    local pendingContainers = GetPendingMissionContainers()
    local now = GetNow()
    for index = #pendingContainers, 1, -1 do
        local entry = pendingContainers[index]
        if not entry or not entry.itemID or (entry.expiresAt and entry.expiresAt <= now) then
            table.remove(pendingContainers, index)
        end
    end
end

local function QueuePendingMissionRewardClaims(historyEntry)
    CleanupPendingMissionRewardClaims()

    for _, reward in ipairs(historyEntry.rewards or {}) do
        local quantity = reward.quantity or 1
        if reward.itemID and quantity > 0 then
            pendingMissionRewardClaims[#pendingMissionRewardClaims + 1] = {
                missionHistoryID = historyEntry.id,
                missionID = historyEntry.missionID,
                itemID = reward.itemID,
                itemName = reward.itemName or reward.title,
                remainingQuantity = quantity,
                expiresAt = GetNow() + MISSION_REWARD_CLAIM_TTL_SECONDS,
            }
        end
    end
end

local function ConsumePendingMissionRewardClaim(itemID, quantity)
    CleanupPendingMissionRewardClaims()

    for index = 1, #pendingMissionRewardClaims do
        local claim = pendingMissionRewardClaims[index]
        if claim and claim.itemID == itemID and (claim.remainingQuantity or 0) > 0 then
            local matchedQuantity = math.min(quantity or 1, claim.remainingQuantity or 0)
            claim.remainingQuantity = (claim.remainingQuantity or 0) - matchedQuantity
            if claim.remainingQuantity <= 0 then
                table.remove(pendingMissionRewardClaims, index)
            end
            return claim, matchedQuantity
        end
    end
end

local function QueuePendingMissionContainer(claim, itemID, itemLink, quantity)
    local pendingContainers = GetPendingMissionContainers()
    local priceSource = activeSession and activeSession.priceSource or GetPriceSource()

    for _ = 1, quantity or 1 do
        local summary = BuildItemSummaryFromItem(itemID, 1, itemLink, priceSource)
        pendingContainers[#pendingContainers + 1] = {
            missionHistoryID = claim.missionHistoryID,
            missionID = claim.missionID,
            itemID = itemID,
            itemLink = itemLink,
            itemName = summary and summary.itemName or claim.itemName,
            rewardItemValue = summary and summary.totalValue or 0,
            claimedAt = GetNow(),
            claimedDate = FormatTimestamp(GetNow()),
            expiresAt = GetNow() + MISSION_CONTAINER_PENDING_TTL_SECONDS,
        }
    end
end

local function PopPendingMissionContainer(itemID)
    CleanupPendingMissionContainers()

    local pendingContainers = GetPendingMissionContainers()
    for index = 1, #pendingContainers do
        local entry = pendingContainers[index]
        if entry and entry.itemID == itemID then
            table.remove(pendingContainers, index)
            return entry
        end
    end
end

local function BuildSessionSnapshot(session)
    local endedAt = session.endedAt or GetNow()
    local durationSeconds = Clamp(endedAt - (session.startedAt or endedAt), 1)
    local rawGold = session.gold and session.gold.total or 0
    local itemValue = 0
    local topItems = {}
    local priceSource = session.priceSource or GetPriceSource()

    for itemString, entry in pairs(session.items or {}) do
        entry.itemString = itemString
        local summary = BuildItemSummary(entry, priceSource)
        itemValue = itemValue + summary.totalValue
        topItems[#topItems + 1] = summary
    end

    table.sort(topItems, function(left, right)
        if left.totalValue == right.totalValue then
            return left.quantity > right.quantity
        end
        return left.totalValue > right.totalValue
    end)

    local totalValue = rawGold + itemValue
    local gph = math.floor((totalValue * 3600 / durationSeconds) + 0.5)
    local xpGained = session.xp and session.xp.gained or 0
    local xph = math.floor((xpGained * 3600 / durationSeconds) + 0.5)
    local corrosiveCoin = tonumber(session.currencyGains and session.currencyGains[CORROSIVE_COIN_CURRENCY_ID])
        or tonumber(session.corrosiveCoin)
        or 0
    local corrosiveCoinPerHour = math.floor((corrosiveCoin * 3600 / durationSeconds) + 0.5)
    local bestItem = topItems[1]

    while #topItems > 5 do
        table.remove(topItems)
    end

    return {
        durationSeconds = durationSeconds,
        rawGold = rawGold,
        itemValue = itemValue,
        totalValue = totalValue,
        gph = gph,
        xpGained = xpGained,
        xph = xph,
        corrosiveCoin = corrosiveCoin,
        corrosiveCoinPerHour = corrosiveCoinPerHour,
        bestItem = bestItem,
        topItems = topItems,
    }
end

local function PersistActiveSession()
    if not activeSession then
        return
    end

    activeSession.lastSeenAt = GetNow()
    activeSession.zone = GetCurrentZoneName()
end

local function StoreCompletedSession(session, reason, endedAt)
    session.endedAt = endedAt or session.endedAt or GetNow()
    session.endReason = reason or session.endReason

    local snapshot = BuildSessionSnapshot(session)
    session.durationSeconds = snapshot.durationSeconds
    session.rawGold = snapshot.rawGold
    session.itemValue = snapshot.itemValue
    session.totalValue = snapshot.totalValue
    session.gph = snapshot.gph
    session.xpGained = snapshot.xpGained
    session.xph = snapshot.xph
    session.corrosiveCoin = snapshot.corrosiveCoin
    session.corrosiveCoinPerHour = snapshot.corrosiveCoinPerHour
    session.bestItem = snapshot.bestItem
    session.topItems = snapshot.topItems

    local sessions = GetSessions()
    sessions[#sessions + 1] = session
    TrimSessions()
end

local function FinalizeActiveSession(reason)
    if not activeSession then
        return
    end

    FinalizeActivityState(reason)
    StoreCompletedSession(activeSession, reason, GetNow())
    activeSession = nil
end

local function StartNewSession()
    local db = GetAccountDB()
    db.activeSession = nil
    activeSession = NewSession()
    PersistActiveSession()
end

local function ResetSession()
    FinalizeActiveSession("manual_reset")
    ClearPendingState()
    StartNewSession()
    lastMoney = GetMoney and GetMoney() or 0
    UpdateFrame()
end

local function RecordGoldDelta(delta)
    if not activeSession or delta == 0 then
        return
    end

    if delta > 0 then
        activeSession.gold.total = activeSession.gold.total + delta
        activeSession.gold.earned = activeSession.gold.earned + delta
    else
        activeSession.gold.total = activeSession.gold.total + delta
        activeSession.gold.spent = activeSession.gold.spent + math.abs(delta)
    end

    PersistActiveSession()
end

local function RecordXPUpdate()
    if not activeSession or IsPlayerAtMaxLevel() then
        return
    end

    activeSession.xp = activeSession.xp or {
        gained = 0,
        lastXP = GetCurrentXP(),
        lastXPMax = GetCurrentXPMax(),
    }

    local currentXP = GetCurrentXP()
    local currentXPMax = GetCurrentXPMax()
    local lastXP = activeSession.xp.lastXP or currentXP
    local lastXPMax = activeSession.xp.lastXPMax or currentXPMax
    local delta = currentXP - lastXP

    if delta < 0 and lastXPMax and lastXPMax > 0 then
        delta = (lastXPMax - lastXP) + currentXP
    end

    if delta > 0 then
        activeSession.xp.gained = (activeSession.xp.gained or 0) + delta
    end

    activeSession.xp.lastXP = currentXP
    activeSession.xp.lastXPMax = currentXPMax
end

local function RecordCurrencyGain(currencyID, quantityChange)
    if not activeSession or tonumber(currencyID) ~= CORROSIVE_COIN_CURRENCY_ID then
        return false
    end

    quantityChange = tonumber(quantityChange)
    if not quantityChange or quantityChange <= 0 then
        return false
    end

    activeSession.currencyGains = activeSession.currencyGains or {}
    activeSession.currencyGains[CORROSIVE_COIN_CURRENCY_ID] =
        (tonumber(activeSession.currencyGains[CORROSIVE_COIN_CURRENCY_ID]) or 0) + quantityChange
    PersistActiveSession()
    return true
end

local function RecordIgnoredGold(delta, isIncome)
    if not activeSession or delta <= 0 then
        return
    end

    if isIncome then
        activeSession.gold.ignoredIncome = activeSession.gold.ignoredIncome + delta
    else
        activeSession.gold.ignoredExpense = activeSession.gold.ignoredExpense + delta
    end

    PersistActiveSession()
end

local function RecordItemGain(itemString, itemLink, quantity)
    local _, _, _, itemBindType = GetItemDetails(itemLink)
    if not activeSession or not itemString or quantity <= 0
        or IsWarboundUntilEquipped(itemLink)
        or IsSoulbound(itemLink, itemBindType) then
        return
    end

    local itemName, itemQuality, vendorSellPrice = GetItemDetails(itemLink)
    activeSession.items[itemString] = activeSession.items[itemString] or {
        itemLink = itemLink,
        itemName = itemName or GetItemName(itemString, itemLink),
        itemQuality = itemQuality,
        vendorSellPrice = vendorSellPrice or 0,
        itemBindType = itemBindType,
        quantity = 0,
        firstLootAt = GetNow(),
    }

    local entry = activeSession.items[itemString]
    entry.itemLink = itemLink or entry.itemLink
    entry.itemName = entry.itemName or itemName or GetItemName(itemString, itemLink)
    if itemQuality ~= nil then
        entry.itemQuality = itemQuality
    end
    if vendorSellPrice and vendorSellPrice > 0 then
        entry.vendorSellPrice = vendorSellPrice
    end
    if itemBindType ~= nil then
        entry.itemBindType = itemBindType
    end
    entry.quantity = (entry.quantity or 0) + quantity
    entry.lastLootAt = GetNow()
    activeSession.itemCount = (activeSession.itemCount or 0) + quantity
    PersistActiveSession()
end

local function FinalizeMissionContainerOpen(reason)
    if not activeMissionContainerOpen then
        return
    end

    local now = GetNow()
    activeMissionContainerOpen.endedAt = now
    activeMissionContainerOpen.endedDate = FormatTimestamp(now)
    activeMissionContainerOpen.durationSeconds = Clamp(now - (activeMissionContainerOpen.openedAt or now), 1)
    activeMissionContainerOpen.endReason = reason or activeMissionContainerOpen.endReason or "finished"

    local outputs = {}
    local totalValue = 0
    for _, entry in pairs(activeMissionContainerOpen.outputs or {}) do
        outputs[#outputs + 1] = entry
        totalValue = totalValue + (entry.totalValue or 0)
    end

    table.sort(outputs, function(left, right)
        if (left.totalValue or 0) == (right.totalValue or 0) then
            return (left.itemName or "") < (right.itemName or "")
        end
        return (left.totalValue or 0) > (right.totalValue or 0)
    end)

    activeMissionContainerOpen.outputs = outputs
    activeMissionContainerOpen.totalValue = totalValue
    activeMissionContainerOpen.outputCount = #outputs
    StoreMissionContainerHistoryEntry(activeMissionContainerOpen)

    local historyEntry = GetMissionHistoryEntryByID(activeMissionContainerOpen.missionHistoryID)
    if historyEntry then
        historyEntry.containerCount = (historyEntry.containerCount or 0) + 1
        historyEntry.containerValue = (historyEntry.containerValue or 0) + totalValue
    end

    activeMissionContainerOpen = nil
end

local function ScheduleFinalizeMissionContainerOpen(delaySeconds)
    if not activeMissionContainerOpen or not C_Timer or not C_Timer.After then
        return
    end

    missionContainerFinalizeToken = missionContainerFinalizeToken + 1
    local token = missionContainerFinalizeToken
    C_Timer.After(delaySeconds or MISSION_CONTAINER_FINALIZE_DELAY_SECONDS, function()
        if activeMissionContainerOpen and token == missionContainerFinalizeToken then
            FinalizeMissionContainerOpen("timeout")
        end
    end)
end

local function StartMissionContainerOpen(itemID, itemLink)
    local pending = PopPendingMissionContainer(itemID)
    if not pending then
        return
    end

    if activeMissionContainerOpen then
        FinalizeMissionContainerOpen("interrupted")
    end

    local now = GetNow()
    activeMissionContainerOpen = {
        id = AllocateHistoryEntryID("nextMissionContainerHistoryID"),
        sessionID = activeSession and activeSession.id or nil,
        missionHistoryID = pending.missionHistoryID,
        missionID = pending.missionID,
        playerKey = GetPlayerKey(),
        playerName = playerInfo.name,
        playerFullName = playerInfo.fullName,
        realm = playerInfo.realm,
        rewardItemID = itemID,
        rewardItemLink = itemLink or pending.itemLink,
        rewardItemName = pending.itemName,
        rewardItemValue = pending.rewardItemValue,
        openedAt = now,
        openedDate = FormatTimestamp(now),
        zone = GetCurrentZoneName(),
        priceSource = activeSession and activeSession.priceSource or GetPriceSource(),
        outputs = {},
    }

    ScheduleFinalizeMissionContainerOpen(MISSION_CONTAINER_FINALIZE_DELAY_SECONDS)
end

local function RecordMissionContainerLoot(itemLink, quantity)
    if not activeMissionContainerOpen then
        return
    end

    local itemID = GetItemIDFromLink(itemLink)
    local summary = BuildItemSummaryFromItem(itemID, quantity or 1, itemLink, activeMissionContainerOpen.priceSource)
    if not summary or not summary.itemString then
        return
    end

    local outputs = activeMissionContainerOpen.outputs
    outputs[summary.itemString] = outputs[summary.itemString] or {
        itemString = summary.itemString,
        itemID = summary.itemID,
        itemLink = itemLink,
        itemName = summary.itemName,
        quantity = 0,
        unitPrice = summary.unitPrice or 0,
        totalValue = 0,
    }

    local entry = outputs[summary.itemString]
    entry.quantity = (entry.quantity or 0) + (quantity or 1)
    entry.unitPrice = summary.unitPrice or entry.unitPrice or 0
    entry.totalValue = (entry.unitPrice or 0) * (entry.quantity or 0)

    ScheduleFinalizeMissionContainerOpen(MISSION_CONTAINER_FINALIZE_DELAY_SECONDS)
end

local function GetCurrentInProgressMissionInfo()
    local missions = {}
    if C_Garrison and C_Garrison.GetInProgressMissions then
        C_Garrison.GetInProgressMissions(missions, FOLLOWER_TYPE_ID)
    end

    local byID = {}
    for _, mission in ipairs(missions) do
        if mission and mission.missionID then
            byID[mission.missionID] = mission
        end
    end
    return byID
end

local function RefreshKnownInProgressMissions()
    local current = GetCurrentInProgressMissionInfo()
    local now = GetNow()

    for missionID in pairs(knownInProgressMissions) do
        if not current[missionID] then
            local historyEntry = missionHistoryByMissionID[missionID]
            if historyEntry and not historyEntry.finishedAt then
                historyEntry.finishedAt = now
                historyEntry.finishedDate = FormatTimestamp(now)
            end
        end
    end

    knownInProgressMissions = current
end

local function EnsureMissionTableActivity()
    if activeMissionTableActivity then
        return activeMissionTableActivity
    end

    activeMissionTableActivity = NewActivityEntry("shadowlands_mission_table")
    activeMissionTableActivity.missionIDs = {}
    activeMissionTableActivity.reportedMissionIDs = {}
    return activeMissionTableActivity
end

local function FinalizeMissionTableActivity(reason)
    if not activeMissionTableActivity then
        return
    end

    FinalizeActivityEntry(activeMissionTableActivity, reason or "hide")
    activeMissionTableActivity = nil
end

local function EnsureReplenishActivity(state)
    if activeReplenishActivity then
        return activeReplenishActivity
    end

    activeReplenishActivity = NewActivityEntry("replenish_the_reservoir")
    activeReplenishActivity.questID = state and state.questID or nil
    activeReplenishActivity.questTitle = state and state.title or "Replenish the Reservoir"
    activeReplenishActivity.progressHistory = {}
    return activeReplenishActivity
end

local function AddReplenishProgressSnapshot(state)
    if not state or not state.isActive then
        return
    end

    local activity = EnsureReplenishActivity(state)
    local now = GetNow()
    local snapshot = {
        at = now,
        atDate = FormatTimestamp(now),
        progressText = state.progressText,
        progressCurrent = state.progressCurrent,
        progressTotal = state.progressTotal,
        isComplete = state.isComplete and true or false,
    }

    local history = activity.progressHistory
    local previous = history[#history]
    if previous
        and previous.progressText == snapshot.progressText
        and previous.isComplete == snapshot.isComplete then
        return
    end

    history[#history + 1] = snapshot
    activity.questID = state.questID
    activity.questTitle = state.title or activity.questTitle
end

local function FinalizeReplenishActivity(reason)
    if not activeReplenishActivity then
        return
    end

    FinalizeActivityEntry(activeReplenishActivity, reason or "inactive")
    activeReplenishActivity = nil
end

local function UpdateReplenishTracking()
    local state = GetActiveReplenishState()
    if state.isActive then
        AddReplenishProgressSnapshot(state)
        return
    end

    if activeReplenishActivity then
        FinalizeReplenishActivity(state.isAvailable and "inactive" or "completed")
    end
end

local function RecordMissionStart(frame)
    if not frame or frame.followerTypeID ~= FOLLOWER_TYPE_ID then
        return
    end

    local missionPage = frame.GetMissionPage and frame:GetMissionPage() or nil
    local missionInfo = missionPage and missionPage.missionInfo or nil
    if not missionInfo or not missionInfo.missionID then
        return
    end

    local now = GetNow()
    local historyEntry = missionHistoryByMissionID[missionInfo.missionID]
    if historyEntry and historyEntry.startedAt and not historyEntry.finishedAt and (now - historyEntry.startedAt) < 5 then
        return
    end

    local missionActivity = EnsureMissionTableActivity()
    local entry = historyEntry or {}
    entry.sessionID = activeSession and activeSession.id or entry.sessionID
    entry.missionActivityID = missionActivity and missionActivity.id or nil
    entry.playerKey = GetPlayerKey()
    entry.playerName = playerInfo.name
    entry.playerFullName = playerInfo.fullName
    entry.realm = playerInfo.realm
    entry.missionID = missionInfo.missionID
    entry.name = missionInfo.name
    entry.level = missionInfo.level
    entry.location = missionInfo.location
    entry.duration = missionInfo.duration
    entry.durationSeconds = missionInfo.durationSeconds
    entry.offerEndTime = missionInfo.offerEndTime
    entry.xp = missionInfo.xp
    entry.startedAt = now
    entry.startedDate = FormatTimestamp(now)
    entry.startedZone = GetCurrentZoneName()
    entry.rewards = BuildMissionRewardsSnapshot(missionInfo.rewards, activeSession and activeSession.priceSource or GetPriceSource())
    entry.followers = BuildMissionFollowerSnapshot(frame, missionInfo)
    entry.status = "started"
    StoreMissionHistoryEntry(entry)

    missionActivity.missionIDs[missionInfo.missionID] = true
    RefreshKnownInProgressMissions()
end

local function RecordMissionReport(missionInfo)
    if not missionInfo or not missionInfo.missionID then
        return
    end

    local now = GetNow()
    if lastMissionReportSeenAt[missionInfo.missionID] and (now - lastMissionReportSeenAt[missionInfo.missionID]) < 2 then
        return
    end
    lastMissionReportSeenAt[missionInfo.missionID] = now

    local missionActivity = EnsureMissionTableActivity()
    local entry = missionHistoryByMissionID[missionInfo.missionID] or {}
    entry.sessionID = activeSession and activeSession.id or entry.sessionID
    entry.missionActivityID = missionActivity and missionActivity.id or entry.missionActivityID
    entry.playerKey = GetPlayerKey()
    entry.playerName = playerInfo.name
    entry.playerFullName = playerInfo.fullName
    entry.realm = playerInfo.realm
    entry.missionID = missionInfo.missionID
    entry.name = missionInfo.name or entry.name
    entry.level = missionInfo.level or entry.level
    entry.location = missionInfo.location or entry.location
    entry.duration = missionInfo.duration or entry.duration
    entry.durationSeconds = missionInfo.durationSeconds or entry.durationSeconds
    entry.succeeded = missionInfo.succeeded and true or false
    entry.finishedAt = entry.finishedAt or now
    entry.finishedDate = entry.finishedDate or FormatTimestamp(now)
    entry.reportViewedAt = now
    entry.reportViewedDate = FormatTimestamp(now)
    entry.rewards = BuildMissionRewardsSnapshot(missionInfo.rewards, activeSession and activeSession.priceSource or GetPriceSource())
    entry.followers = entry.followers or {}
    entry.reportFollowers = BuildMissionFollowerSnapshot(nil, missionInfo)
    entry.status = missionInfo.succeeded and "reported_success" or "reported_failure"
    StoreMissionHistoryEntry(entry)
    QueuePendingMissionRewardClaims(entry)

    missionActivity.reportedMissionIDs[missionInfo.missionID] = true
    RefreshKnownInProgressMissions()
end

FinalizeActivityState = function(reason)
    FinalizeMissionContainerOpen(reason)
    FinalizeMissionTableActivity(reason)
    FinalizeReplenishActivity(reason)
end

local function GetMailHeaderInfo(index)
    local _, _, sender, _, money, _, _, numItems = GetInboxHeaderInfo(index)
    return sender, money or 0, numItems or 0
end

local function QueueIgnoredMailLoot(index, attachmentIndex)
    local sender = GetMailHeaderInfo(index)
    local maxAttachments = ATTACHMENTS_MAX_RECEIVE or 16
    if attachmentIndex then
        maxAttachments = attachmentIndex
    end

    for currentIndex = attachmentIndex or 1, maxAttachments do
        local _, _, _, quantity = GetInboxItem(index, currentIndex)
        local itemLink = GetInboxItemLink(index, currentIndex)
        if itemLink and quantity and quantity > 0 then
            local itemString = GetItemStringFromLink(itemLink)
            if itemString then
                AddIgnoredLoot(itemString, quantity)
            end
        end

        if attachmentIndex then
            break
        end
    end

    return sender
end

local function QueueIgnoredInternalMailMoney(index)
    local sender, money = GetMailHeaderInfo(index)
    if IsKnownCharacter(sender) and money and money > 0 then
        AddIgnoredGold(pendingIgnoredIncome, money)
    end
end

local function QueueOutgoingInternalMail(destination)
    if not IsKnownCharacter(destination) then
        return
    end

    local mailMoney = GetSendMailMoney and GetSendMailMoney() or 0
    local mailCost = GetSendMailPrice and GetSendMailPrice() or 0
    local total = mailMoney + mailCost
    if total <= 0 then
        return
    end

    pendingOutgoingMail[#pendingOutgoingMail + 1] = {
        amount = total,
        expiresAt = GetNow() + OUTGOING_MAIL_WINDOW_SECONDS,
    }
end

local function CleanupOutgoingMail()
    local now = GetNow()
    for index = #pendingOutgoingMail, 1, -1 do
        local entry = pendingOutgoingMail[index]
        if not entry or not entry.amount or entry.amount <= 0 or (entry.expiresAt and entry.expiresAt <= now) then
            table.remove(pendingOutgoingMail, index)
        end
    end
end

local function ConfirmOutgoingMail()
    CleanupOutgoingMail()
    local entry = table.remove(pendingOutgoingMail, 1)
    if entry and entry.amount and entry.amount > 0 then
        AddIgnoredGold(pendingIgnoredExpense, entry.amount)
    end
end

local function CancelOutgoingMail()
    CleanupOutgoingMail()
    table.remove(pendingOutgoingMail, 1)
end

local function HandleMoneyChange()
    local currentMoney = GetMoney and GetMoney() or 0
    if not lastMoney then
        lastMoney = currentMoney
        return
    end

    local delta = currentMoney - lastMoney
    lastMoney = currentMoney
    if delta == 0 then
        return
    end

    if delta > 0 then
        local ignored = ConsumeIgnoredGold(pendingIgnoredIncome, delta)
        if ignored > 0 then
            RecordIgnoredGold(ignored, true)
        end
        delta = delta - ignored
    else
        local ignored = ConsumeIgnoredGold(pendingIgnoredExpense, math.abs(delta))
        if ignored > 0 then
            RecordIgnoredGold(ignored, false)
        end
        delta = delta + ignored
    end

    RecordGoldDelta(delta)
end

local function ParseLootMessage(message)
    if not message then
        return
    end

    if issecretvalue and issecretvalue(message) then
        return
    end

    if type(message) ~= "string" or message == "" then
        return
    end

    for _, entry in ipairs(lootPatterns) do
        local itemLink, quantity = string.match(message, entry.pattern)
        if itemLink then
            return itemLink, tonumber(quantity) or 1
        end
    end
end

local function HandleMissionRewardClaimLoot(itemLink, quantity)
    local itemID = GetItemIDFromLink(itemLink)
    if not itemID then
        return
    end

    local claim, matchedQuantity = ConsumePendingMissionRewardClaim(itemID, quantity or 1)
    if not claim or not matchedQuantity or matchedQuantity <= 0 then
        return
    end

    QueuePendingMissionContainer(claim, itemID, itemLink, matchedQuantity)

    local historyEntry = GetMissionHistoryEntryByID(claim.missionHistoryID)
    if historyEntry then
        historyEntry.claimedRewardCount = (historyEntry.claimedRewardCount or 0) + matchedQuantity
        historyEntry.lastRewardClaimAt = GetNow()
        historyEntry.lastRewardClaimDate = FormatTimestamp(historyEntry.lastRewardClaimAt)
    end
end

local function HandleLootMessage(message)
    local itemLink, quantity = ParseLootMessage(message)
    if not itemLink then
        return
    end

    local itemString = GetItemStringFromLink(itemLink)
    if not itemString then
        return
    end

    quantity = ConsumeIgnoredLoot(itemString, quantity)
    if quantity <= 0 then
        return
    end

    HandleMissionRewardClaimLoot(itemLink, quantity)
    RecordMissionContainerLoot(itemLink, quantity)
    RecordItemGain(itemString, itemLink, quantity)
end

local function BuildFrameLines()
    if not activeSession then
        return {
            "No session",
            "GPH 0g",
            "Time 00:00",
            "Gold 0g",
            "Loot 0g",
            "",
        }
    end

    local snapshot = BuildSessionSnapshot(activeSession)
    local lines = {
        "Session",
        "GPH " .. FormatGoldCompact(snapshot.gph),
        "Time " .. FormatDurationCompact(snapshot.durationSeconds),
        "Gold " .. FormatGoldCompact(snapshot.rawGold),
        "Loot " .. FormatGoldCompact(snapshot.itemValue),
        "",
    }

    local nextLine = 6
    if snapshot.corrosiveCoin > 0 then
        lines[nextLine] = "Coin/h " .. BreakUpLargeNumbers(snapshot.corrosiveCoinPerHour or 0)
        nextLine = nextLine + 1
    end

    if not IsPlayerAtMaxLevel() then
        lines[nextLine] = "XP/h " .. BreakUpLargeNumbers(snapshot.xph or 0)
    end

    return lines
end

function UpdateFrame()
    if not trackerFrame then
        return
    end

    local lines = BuildFrameLines()
    for index, fontString in ipairs(trackerFrame.lines) do
        fontString:SetText(lines[index] or "")
    end

    PersistActiveSession()
    if YayaFrameAPI and type(YayaFrameAPI.Refresh) == "function" then
        YayaFrameAPI:Refresh()
    end
end

local function CreateTrackerFrame()
    if not YayaFrameAPI or type(YayaFrameAPI.GetFrame) ~= "function" then
        return
    end

    trackerFrame = CreateFrame("Frame", addonName .. "Frame", YayaFrameAPI:GetFrame())
    trackerFrame:SetFrameStrata("MEDIUM")
    trackerFrame:SetSize(132, 106)
    trackerFrame:SetClampedToScreen(true)

    trackerFrame.bg = trackerFrame:CreateTexture(nil, "BACKGROUND")
    trackerFrame.bg:SetAllPoints()
    trackerFrame.bg:SetColorTexture(0, 0, 0, 0.55)

    trackerFrame.resetButton = CreateFrame("Button", nil, trackerFrame, "UIPanelButtonTemplate")
    trackerFrame.resetButton:SetSize(18, 18)
    trackerFrame.resetButton:SetPoint("TOPRIGHT", -4, -4)
    trackerFrame.resetButton:SetText("R")
    trackerFrame.resetButton:SetScript("OnClick", ResetSession)
    trackerFrame.resetButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("Reset session")
        GameTooltip:Show()
    end)
    trackerFrame.resetButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    trackerFrame.lines = {}
    for index = 1, 7 do
        local line = trackerFrame:CreateFontString(nil, "OVERLAY", index == 1 and "GameFontNormalSmall" or "GameFontHighlightSmall")
        line:SetPoint("TOPLEFT", 6, -5 - ((index - 1) * 14))
        line:SetWidth(102)
        line:SetJustifyH("LEFT")
        trackerFrame.lines[index] = line
    end

    YayaFrameAPI:AttachSection(addonName, trackerFrame, 10)
    UpdateFrame()
end

local function InstallMailHooks()
    if hookState.installed then
        return
    end

    hookState.SendMail = SendMail
    SendMail = function(destination, currentSubject, ...)
        QueueOutgoingInternalMail(destination)
        return hookState.SendMail(destination, currentSubject, ...)
    end

    hookState.TakeInboxItem = TakeInboxItem
    TakeInboxItem = function(index, attachmentIndex)
        QueueIgnoredMailLoot(index, attachmentIndex)
        return hookState.TakeInboxItem(index, attachmentIndex)
    end

    hookState.TakeInboxMoney = TakeInboxMoney
    TakeInboxMoney = function(index)
        QueueIgnoredInternalMailMoney(index)
        return hookState.TakeInboxMoney(index)
    end

    hookState.AutoLootMailItem = AutoLootMailItem
    AutoLootMailItem = function(index, attachmentIndex)
        local sender = QueueIgnoredMailLoot(index, attachmentIndex)
        if IsKnownCharacter(sender) then
            local _, money = GetMailHeaderInfo(index)
            if money and money > 0 then
                AddIgnoredGold(pendingIgnoredIncome, money)
            end
        end
        return hookState.AutoLootMailItem(index, attachmentIndex)
    end

    hookState.installed = true
end

local function GetContainerItemIDCompat(bagID, slotIndex)
    if C_Container and C_Container.GetContainerItemID then
        return C_Container.GetContainerItemID(bagID, slotIndex)
    end
    if GetContainerItemID then
        return GetContainerItemID(bagID, slotIndex)
    end
end

local function GetContainerItemLinkCompat(bagID, slotIndex)
    if C_Container and C_Container.GetContainerItemLink then
        return C_Container.GetContainerItemLink(bagID, slotIndex)
    end
    if GetContainerItemLink then
        return GetContainerItemLink(bagID, slotIndex)
    end
end

local function OnMissionContainerItemUsed(bagID, slotIndex)
    local itemID = GetContainerItemIDCompat(bagID, slotIndex)
    if not itemID then
        return
    end

    StartMissionContainerOpen(itemID, GetContainerItemLinkCompat(bagID, slotIndex))
end

local function InstallContainerHooks()
    if hookState.containerHooksInstalled then
        return
    end

    if hooksecurefunc then
        if UseContainerItem then
            hooksecurefunc("UseContainerItem", OnMissionContainerItemUsed)
        end

        if C_Container and C_Container.UseContainerItem then
            hooksecurefunc(C_Container, "UseContainerItem", OnMissionContainerItemUsed)
        end
    end

    hookState.containerHooksInstalled = true
end

local function InstallGarrisonHooks()
    if hookState.garrisonHooksInstalled or not IsAddOnLoadedCompat(BLIZZARD_GARRISON_UI_ADDON) then
        return
    end

    if CovenantMissionFrame and CovenantMissionFrame.HookScript then
        CovenantMissionFrame:HookScript("OnShow", function()
            EnsureMissionTableActivity()
            RefreshKnownInProgressMissions()
        end)

        CovenantMissionFrame:HookScript("OnHide", function()
            RefreshKnownInProgressMissions()
            FinalizeMissionTableActivity("hide")
        end)
    end

    if hooksecurefunc and GarrisonFollowerMission then
        hooksecurefunc(GarrisonFollowerMission, "OnClickStartMissionButton", function(self)
            RecordMissionStart(self)
        end)
    end

    if hooksecurefunc and CovenantMission then
        hooksecurefunc(CovenantMission, "MissionCompleteInitialize", function(_, missionList, index)
            if missionList and index and missionList[index] then
                RecordMissionReport(missionList[index])
            end
        end)
    end

    hookState.garrisonHooksInstalled = true
end

local function RebuildMissionHistoryIndexes()
    wipe(missionHistoryByID)
    wipe(missionHistoryByMissionID)

    for _, entry in ipairs(GetShadowlandsMissionHistory()) do
        if entry.id then
            missionHistoryByID[entry.id] = entry
        end
        if entry.missionID then
            missionHistoryByMissionID[entry.missionID] = entry
        end
    end
end

local function StartTicker()
    if updateTicker or not C_Timer or not C_Timer.NewTicker then
        return
    end

    updateTicker = C_Timer.NewTicker(UPDATE_INTERVAL_SECONDS, function()
        CleanupQueue(pendingIgnoredIncome)
        CleanupQueue(pendingIgnoredExpense)
        CleanupLootQueue()
        CleanupOutgoingMail()
        CleanupPendingMissionRewardClaims()
        CleanupPendingMissionContainers()
        UpdateFrame()
    end)
end

local function HandleSlashCommand(message)
    local command = strtrim((message or ""):lower())
    if command == "reset" then
        ResetFramePosition()
    end
    UpdateFrame()
end

local function OnLogin()
    playerInfo.name = UnitName and UnitName("player") or nil
    playerInfo.realm = GetRealmName and GetRealmName() or nil
    playerInfo.fullName = GetPlayerFullName()
    RebuildMissionHistoryIndexes()
    RegisterKnownCharacter()
    BuildLootPatterns()
    StartNewSession()
    InstallMailHooks()
    InstallContainerHooks()
    InstallGarrisonHooks()
    CreateTrackerFrame()
    StartTicker()

    lastMoney = GetMoney and GetMoney() or 0

    SLASH_YAYASESSIONTRACKER1 = "/yst"
    SlashCmdList.YAYASESSIONTRACKER = HandleSlashCommand

    UpdateReplenishTracking()
    UpdateFrame()
end

eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_LOGOUT")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_MONEY")
eventFrame:RegisterEvent("PLAYER_XP_UPDATE")
eventFrame:RegisterEvent("PLAYER_LEVEL_UP")
eventFrame:RegisterEvent("CHAT_MSG_LOOT")
eventFrame:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
eventFrame:RegisterEvent("MAIL_SEND_SUCCESS")
eventFrame:RegisterEvent("MAIL_FAILED")
eventFrame:RegisterEvent("QUEST_LOG_UPDATE")
eventFrame:RegisterEvent("QUEST_TURNED_IN")
eventFrame:RegisterEvent("GARRISON_MISSION_STARTED")
eventFrame:RegisterEvent("GARRISON_MISSION_FINISHED")
eventFrame:RegisterEvent("GARRISON_MISSION_LIST_UPDATE")
eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_LOGIN" then
        OnLogin()
        return
    end

    if event == "PLAYER_LOGOUT" then
        FinalizeActiveSession("logout")
        return
    end

    if event == "ADDON_LOADED" then
        local addon = ...
        if addon == BLIZZARD_GARRISON_UI_ADDON then
            InstallGarrisonHooks()
        end
        return
    end

    if not activeSession then
        return
    end

    if event == "PLAYER_MONEY" then
        HandleMoneyChange()
        UpdateFrame()
    elseif event == "PLAYER_XP_UPDATE" or event == "PLAYER_LEVEL_UP" then
        RecordXPUpdate()
        UpdateFrame()
    elseif event == "CHAT_MSG_LOOT" then
        local message = ...
        HandleLootMessage(message)
        UpdateFrame()
    elseif event == "CURRENCY_DISPLAY_UPDATE" then
        local currencyID, _, quantityChange = ...
        if RecordCurrencyGain(currencyID, quantityChange) then
            UpdateFrame()
        end
    elseif event == "MAIL_SEND_SUCCESS" then
        ConfirmOutgoingMail()
    elseif event == "MAIL_FAILED" then
        CancelOutgoingMail()
    elseif event == "QUEST_LOG_UPDATE" then
        UpdateReplenishTracking()
    elseif event == "QUEST_TURNED_IN" then
        local questID = ...
        local isReplenishQuest = false
        for _, replenishQuestID in ipairs(REPLENISH_THE_RESERVOIR_QUEST_IDS) do
            if replenishQuestID == questID then
                isReplenishQuest = true
                break
            end
        end

        if isReplenishQuest then
            FinalizeReplenishActivity("turned_in")
        else
            UpdateReplenishTracking()
        end
    elseif event == "GARRISON_MISSION_STARTED" then
        local followerTypeID = ...
        if followerTypeID == FOLLOWER_TYPE_ID then
            RefreshKnownInProgressMissions()
        end
    elseif event == "GARRISON_MISSION_FINISHED" or event == "GARRISON_MISSION_LIST_UPDATE" then
        local followerTypeID = ...
        if followerTypeID == FOLLOWER_TYPE_ID then
            RefreshKnownInProgressMissions()
        end
    elseif event == "ZONE_CHANGED_NEW_AREA" or event == "PLAYER_ENTERING_WORLD" then
        PersistActiveSession()
        UpdateReplenishTracking()
        UpdateFrame()
    end
end)
