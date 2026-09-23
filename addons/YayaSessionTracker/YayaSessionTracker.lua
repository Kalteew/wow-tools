local addonName = ...
local XPTracker = YayaSessionTrackerXP
local trackerUI = {}

local UPDATE_INTERVAL_SECONDS = 15
local IGNORE_WINDOW_SECONDS = 10
local OUTGOING_MAIL_WINDOW_SECONDS = 30
local MISSION_REWARD_CLAIM_TTL_SECONDS = 600
local MISSION_CONTAINER_PENDING_TTL_SECONDS = 30 * 24 * 60 * 60
local MISSION_CONTAINER_FINALIZE_DELAY_SECONDS = 1.25
local MAX_SESSIONS = 250
local CORROSIVE_COIN_CURRENCY_ID = 3448
local DEFAULT_PRICE_SOURCE = "first(dbregionsaleavg, dbmarket, dbregionmarketavg, vendorsell)"
local LEGACY_PRICE_SOURCES = {
    ["first(dbmarket, dbregionmarketavg, vendorsell)"] = true,
}
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
local trackerCollapsed = false
local updateTicker
local activeSession
local activeXPSession
local xpCursor
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

trackerUI.xpSourceState = trackerUI.xpSourceState or {
    questUntil = 0,
    combatUntil = 0,
}

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
    if not db.settings.priceSource or LEGACY_PRICE_SOURCES[db.settings.priceSource] then
        db.settings.priceSource = DEFAULT_PRICE_SOURCE
    end
    local bandSize = tonumber(db.settings.xpLevelBandSize)
    if bandSize ~= 5 and bandSize ~= 10 and bandSize ~= 20 then
        db.settings.xpLevelBandSize = 10
    else
        db.settings.xpLevelBandSize = bandSize
    end
    if db.settings.xpDashboardMetric ~= "levels" and db.settings.xpDashboardMetric ~= "xph" then
        db.settings.xpDashboardMetric = "xph"
    end
    if db.settings.xpTrackingMode ~= XPTracker.MODE_BELOW_80
        and db.settings.xpTrackingMode ~= XPTracker.MODE_80_TO_90 then
        db.settings.xpTrackingMode = XPTracker.MODE_BELOW_80
    end
    db.settings.position = db.settings.position or {}
    return db.settings
end

function trackerUI.GetXPTrackingMode()
    return XPTracker.NormalizeMode(GetSettings().xpTrackingMode)
end

function trackerUI.GetXPModeConfig()
    return XPTracker.GetModeConfig(trackerUI.GetXPTrackingMode())
end

local function GetSessions()
    local db = GetAccountDB()
    db.sessions = db.sessions or {}
    return db.sessions
end

local function GetXPSessions(mode)
    local db = GetAccountDB()
    mode = XPTracker.NormalizeMode(mode or trackerUI.GetXPTrackingMode())
    local field = XPTracker.GetSessionStoreField(mode)
    db[field] = db[field] or {}
    return db[field]
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
    return YayaCore.Money.FormatCompact(copper)
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

local function TrimXPSessions(mode)
    local sessions = GetXPSessions(mode)
    while #sessions > XPTracker.MAX_SESSIONS do
        table.remove(sessions, 1)
    end
end

local function GetCurrentZoneName()
    -- GetZoneText() retourne la sous-zone (par ex. The Farstrider Lodge).
    -- GetRealZoneText() est le nom de la zone de carte a conserver dans les stats.
    local zone = GetRealZoneText and GetRealZoneText() or nil
    if not zone or zone == "" then
        if C_Map and type(C_Map.GetBestMapForUnit) == "function"
            and type(C_Map.GetMapInfo) == "function" then
            local mapID = C_Map.GetBestMapForUnit("player")
            local mapInfo = mapID and C_Map.GetMapInfo(mapID)
            zone = mapInfo and mapInfo.name
        end
    end
    if not zone or zone == "" then
        zone = GetZoneText and GetZoneText() or ""
    end
    if XPTracker and type(XPTracker.GetZoneName) == "function" then
        zone = XPTracker.GetZoneName(zone)
    end
    return zone or ""
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

local function GetCurrentXPState()
    return XPTracker.NewCursor(GetPlayerLevel(), GetCurrentXP(), GetCurrentXPMax())
end

function trackerUI.MarkQuestXPSource()
    trackerUI.xpSourceState.questUntil = GetNow() + 8
end

function trackerUI.MarkCombatXPSource()
    trackerUI.xpSourceState.combatUntil = GetNow() + 12
end

function trackerUI.IsDungeonContext()
    if not GetInstanceInfo then
        return false
    end
    local _, instanceType = GetInstanceInfo()
    return instanceType == "party" or instanceType == "scenario"
end

function trackerUI.GetXPSource()
    local state = trackerUI.xpSourceState
    local now = GetNow()
    if (state.questUntil or 0) >= now then
        return XPTracker.SOURCE_QUEST
    end
    if trackerUI.IsDungeonContext() then
        return XPTracker.SOURCE_DUNGEON
    end
    if (state.combatUntil or 0) >= now then
        return XPTracker.SOURCE_COMBAT
    end
    return XPTracker.SOURCE_OTHER
end

function trackerUI.HandleCombatLogXPSource()
    if not CombatLogGetCurrentEventInfo then
        return
    end
    local _, subevent, _, sourceGUID, _, _, _, destGUID = CombatLogGetCurrentEventInfo()
    local playerGUID = UnitGUID and UnitGUID("player")
    local petGUID = UnitGUID and UnitGUID("pet")
    if subevent == "UNIT_DIED" or subevent == "PARTY_KILL"
        or subevent == "SWING_DAMAGE" or subevent == "RANGE_DAMAGE"
        or subevent == "SPELL_DAMAGE" or subevent == "SPELL_PERIODIC_DAMAGE" then
        if sourceGUID == playerGUID or sourceGUID == petGUID
            or destGUID == playerGUID or destGUID == petGUID then
            trackerUI.MarkCombatXPSource()
        end
    end
end

local function GetPlayerSpecSnapshot()
    local className, classToken, classID = UnitClass and UnitClass("player")
    local specializationIndex = GetSpecialization and GetSpecialization()
    local specID, specName, _, _, role
    if specializationIndex and GetSpecializationInfo then
        specID, specName, _, _, role = GetSpecializationInfo(specializationIndex)
    end

    local specKey = tostring(classID or classToken or "unknown") .. ":" .. tostring(specID or "unknown")
    return {
        specKey = specKey,
        specID = specID,
        specName = specName or "Inconnue",
        role = role,
        classID = classID,
        className = className,
        classToken = classToken,
    }
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

local function PersistActiveXPSession()
    local db = GetAccountDB()
    db.activeXPSession = nil
    db.activeXPSession80to90 = nil
    if activeXPSession then
        activeXPSession.trackingMode = XPTracker.NormalizeMode(activeXPSession.trackingMode)
        db[XPTracker.GetActiveStoreField(activeXPSession.trackingMode)] = activeXPSession
    end
end

local function StoreCompletedXPSession(session, reason, endedAt)
    if not session or (session.xpGained or 0) <= 0 then
        return
    end

    session.id = session.id or GetNextHistoryID("nextXPSessionID")
    session.trackingMode = XPTracker.NormalizeMode(session.trackingMode)
    XPTracker.Finalize(session, endedAt or GetNow(), reason)

    local sessions = GetXPSessions(session.trackingMode)
    sessions[#sessions + 1] = session
    TrimXPSessions(session.trackingMode)
end

local function FinalizeActiveXPSession(reason)
    if not activeXPSession then
        PersistActiveXPSession()
        return
    end

    StoreCompletedXPSession(activeXPSession, reason, GetNow())
    activeXPSession = nil
    PersistActiveXPSession()
end

local function RecoverActiveXPSession()
    local db = GetAccountDB()
    local recoveredBelow80 = db.activeXPSession
    local recovered80to90 = db.activeXPSession80to90
    db.activeXPSession = nil
    db.activeXPSession80to90 = nil
    if recoveredBelow80 and (recoveredBelow80.xpGained or 0) > 0 then
        StoreCompletedXPSession(recoveredBelow80, "recovered_login", GetNow())
    end
    if recovered80to90 and (recovered80to90.xpGained or 0) > 0 then
        StoreCompletedXPSession(recovered80to90, "recovered_login", GetNow())
    end
    activeXPSession = nil
end

local function MaintainXPTracking()
    if not activeXPSession then
        return
    end

    local modeConfig = XPTracker.GetModeConfig(activeXPSession.trackingMode)
    if GetPlayerLevel() >= modeConfig.maxLevel then
        FinalizeActiveXPSession("level_cap")
        return
    end

    if GetNow() - (activeXPSession.lastGainAt or GetNow()) > XPTracker.IDLE_TIMEOUT_SECONDS then
        FinalizeActiveXPSession("idle_timeout")
    end
end

local function StartNewSession()
    local db = GetAccountDB()
    db.activeSession = nil
    activeSession = NewSession()
    activeXPSession = nil
    xpCursor = GetCurrentXPState()
    PersistActiveSession()
    PersistActiveXPSession()
end

local function ResetSession()
    FinalizeActiveSession("manual_reset")
    FinalizeActiveXPSession("manual_reset")
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

local function SwitchXPTrackingMode()
    local trackingMode = trackerUI.GetXPTrackingMode()
    if activeXPSession and activeXPSession.trackingMode ~= trackingMode then
        FinalizeActiveXPSession("mode_changed")
    end
    xpCursor = GetCurrentXPState()
end

local function RecordXPUpdate()
    if not activeSession or not XPTracker then
        return
    end

    activeSession.xp = activeSession.xp or {
        gained = 0,
        lastXP = GetCurrentXP(),
        lastXPMax = GetCurrentXPMax(),
    }

    local trackingMode = trackerUI.GetXPTrackingMode()
    local modeConfig = XPTracker.GetModeConfig(trackingMode)
    local current = GetCurrentXPState()
    if activeXPSession and activeXPSession.trackingMode ~= trackingMode then
        FinalizeActiveXPSession("mode_changed")
        xpCursor = current
    end
    local previous = xpCursor or current
    local delta = XPTracker.CalculateDelta(previous, current, trackingMode)
    xpCursor = current

    if delta > 0 then
        activeSession.xp.gained = (activeSession.xp.gained or 0) + delta

        local spec = GetPlayerSpecSnapshot()
        local context = {
            now = GetNow(),
            level = current.level,
            startLevel = previous.level,
            zone = GetCurrentZoneName(),
            playerKey = GetPlayerKey(),
            playerName = playerInfo.name,
            playerFullName = playerInfo.fullName,
            realm = playerInfo.realm,
            loginSessionID = activeSession.id,
            trackingMode = trackingMode,
            specKey = spec.specKey,
            specID = spec.specID,
            specName = spec.specName,
            role = spec.role,
            classID = spec.classID,
            className = spec.className,
            classToken = spec.classToken,
            source = trackerUI.GetXPSource(),
        }
        local nextSession, closedSession = XPTracker.AddGain(activeXPSession, context, delta)
        if closedSession then
            StoreCompletedXPSession(closedSession, closedSession.endReason, closedSession.endedAt)
        end
        activeXPSession = nextSession
        if context.source == XPTracker.SOURCE_QUEST then
            trackerUI.xpSourceState.questUntil = 0
        end
    end

    activeSession.xp.lastXP = current.xp
    activeSession.xp.lastXPMax = current.xpMax
    if current.level >= modeConfig.maxLevel then
        FinalizeActiveXPSession("level_cap")
    elseif delta > 0 then
        PersistActiveXPSession()
    end
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

--- Infobulle de la ligne Loot : les meilleurs objets de la session.
--
-- BuildSessionSnapshot calculait deja topItems et bestItem sans que rien ne les
-- affiche jamais. Les voici, sans cout de collecte supplementaire.
local function ApplyLootTooltip(row, topItems)
    if not topItems or #topItems == 0 then
        row.SetTooltip("Loot de la session", "Aucun objet valorise pour l'instant.")
        return
    end

    local lines = {}
    for _, item in ipairs(topItems) do
        lines[#lines + 1] = ("%s x%d  %s"):format(
            item.itemName or item.itemString or "?",
            item.quantity or 0,
            FormatGoldCompact(item.totalValue or 0)
        )
    end
    row.SetTooltip("Meilleurs objets de la session", table.concat(lines, "|n"))
end

local function BuildActiveXPSnapshot()
    if not activeXPSession then
        return
    end
    local preview = XPTracker.CopyForPreview(activeXPSession)
    return XPTracker.Finalize(preview, GetNow(), "active")
end

function trackerUI.FormatXP(value)
    value = math.floor(tonumber(value) or 0)
    return BreakUpLargeNumbers and BreakUpLargeNumbers(value) or tostring(value)
end

function trackerUI.FormatDashboardXP(value)
    value = math.max(0, tonumber(value) or 0)
    if value >= 1000000 then
        return ("%.1fM"):format(value / 1000000)
    end
    if value >= 1000 then
        return ("%.1fk"):format(value / 1000)
    end
    return tostring(math.floor(value + 0.5))
end

function trackerUI.CreateDashboardLabel(parent, font, justify)
    local label = parent:CreateFontString(nil, "OVERLAY", font)
    YayaCore.UI.SetFont(label, font)
    YayaCore.UI.BoundLabel(label, justify or "LEFT")
    return label
end

function trackerUI.CreateDashboardMetricCard(parent, title, width, height)
    local UI = YayaCore.UI
    local card = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    card:SetSize(width, height)
    UI.ApplyPanelBackdrop(card, { color = UI.COLOR.header })

    card.title = trackerUI.CreateDashboardLabel(card, UI.FONT.muted, "LEFT")
    card.title:SetPoint("TOPLEFT", card, "TOPLEFT", UI.PAD.md, -UI.PAD.sm)
    card.title:SetPoint("TOPRIGHT", card, "TOPRIGHT", -UI.PAD.md, -UI.PAD.sm)
    card.title:SetText(title or "")
    card.title:SetTextColor(UI.Unpack(UI.COLOR.textMuted))

    card.value = trackerUI.CreateDashboardLabel(card, UI.FONT.heading, "LEFT")
    card.value:SetPoint("TOPLEFT", card.title, "BOTTOMLEFT", 0, -UI.PAD.xs)
    card.value:SetPoint("TOPRIGHT", card.title, "BOTTOMRIGHT", 0, -UI.PAD.xs)
    card.value:SetText("—")
    card.value:SetTextColor(UI.Unpack(UI.COLOR.accent))

    card.detail = trackerUI.CreateDashboardLabel(card, UI.FONT.muted, "LEFT")
    card.detail:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", UI.PAD.md, UI.PAD.sm)
    card.detail:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -UI.PAD.md, UI.PAD.sm)
    card.detail:SetTextColor(UI.Unpack(UI.COLOR.textMuted))

    function card.SetMetric(value, detail, tone)
        card.value:SetText(value or "—")
        card.detail:SetText(detail or "")
        card.value:SetTextColor(UI.Unpack(UI.COLOR[tone or "accent"] or UI.COLOR.accent))
    end

    return card
end

function trackerUI.CreateDashboardChartCard(parent, title, width, height)
    local UI = YayaCore.UI
    local card = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    card:SetSize(width, height)
    UI.ApplyPanelBackdrop(card, { color = UI.COLOR.panel })

    card.title = trackerUI.CreateDashboardLabel(card, UI.FONT.header, "LEFT")
    card.title:SetPoint("TOPLEFT", card, "TOPLEFT", UI.PAD.md, -UI.PAD.sm)
    card.title:SetPoint("TOPRIGHT", card, "TOPRIGHT", -UI.PAD.md, -UI.PAD.sm)
    card.title:SetText(title or "")
    card.title:SetTextColor(UI.Unpack(UI.COLOR.category))

    card.rule = UI.CreateDivider(card, { color = UI.COLOR.divider })
    card.rule:SetPoint("TOPLEFT", card, "TOPLEFT", UI.PAD.md, -UI.SIZE.headerH)
    card.rule:SetPoint("TOPRIGHT", card, "TOPRIGHT", -UI.PAD.md, -UI.SIZE.headerH)
    return card
end

trackerUI.DASHBOARD_ALL = "__all__"
trackerUI.dashboardFilters = trackerUI.dashboardFilters or {
    classKey = "__all__",
    specKey = "__all__",
    zone = "__all__",
    levelBand = "__all__",
}

function trackerUI.GetDashboardMetric()
    return GetSettings().xpDashboardMetric == "levels" and "levels" or "xph"
end

function trackerUI.GetDashboardMetricLabel(metric)
    return metric == "levels" and "Niveaux/h" or "XP/h"
end

function trackerUI.FormatDashboardMetric(value, metric)
    if metric == "levels" then
        return ("%.2f/h"):format(tonumber(value) or 0)
    end
    local formatted = trackerUI.FormatDashboardXP(value)
    return formatted .. "/h"
end

function trackerUI.GetDashboardClassKey(session)
    return session.classToken or tostring(session.classID or "unknown")
end

function trackerUI.GetDashboardSpecKey(session)
    return session.specKey or "unknown"
end

function trackerUI.GetDashboardClassColor(classToken)
    if RAID_CLASS_COLORS and classToken and RAID_CLASS_COLORS[classToken] then
        return RAID_CLASS_COLORS[classToken]
    end
end

function trackerUI.SessionHasDashboardZone(session, zone)
    if session.zoneXP and (tonumber(session.zoneXP[zone]) or 0) > 0 then
        return true
    end
    return session.startZone == zone or session.endZone == zone
end

function trackerUI.SessionHasDashboardBand(session, band)
    if session.levelXP and (tonumber(session.levelXP[band]) or 0) > 0 then
        return true
    end
    return XPTracker.GetLevelBand(session.startLevel, nil, session.trackingMode) == band
        or XPTracker.GetLevelBand(session.endLevel, nil, session.trackingMode) == band
end

function trackerUI.SessionMatchesDashboardFilters(session, filters, ignoredKey)
    if type(session) ~= "table" then
        return false
    end
    if ignoredKey ~= "classKey" and filters.classKey ~= trackerUI.DASHBOARD_ALL
        and trackerUI.GetDashboardClassKey(session) ~= filters.classKey then
        return false
    end
    if ignoredKey ~= "specKey" and filters.specKey ~= trackerUI.DASHBOARD_ALL
        and trackerUI.GetDashboardSpecKey(session) ~= filters.specKey then
        return false
    end
    if ignoredKey ~= "zone" and filters.zone ~= trackerUI.DASHBOARD_ALL
        and not trackerUI.SessionHasDashboardZone(session, filters.zone) then
        return false
    end
    if ignoredKey ~= "levelBand" and filters.levelBand ~= trackerUI.DASHBOARD_ALL
        and not trackerUI.SessionHasDashboardBand(session, filters.levelBand) then
        return false
    end
    return true
end

function trackerUI.BuildDashboardFilterChoices(history, key)
    local values = {}
    local labels = {}
    local filters = trackerUI.dashboardFilters
    local function Add(value, label)
        if value and value ~= "" and not values[value] then
            values[value] = true
            labels[value] = label or value
        end
    end

    for _, session in ipairs(history or {}) do
        if type(session) == "table" and (tonumber(session.xpGained) or 0) > 0 then
            local candidate = XPTracker.CopyForPreview(session)
            XPTracker.NormalizeSessionZones(candidate)
            if trackerUI.SessionMatchesDashboardFilters(candidate, filters, key) then
                if key == "classKey" then
                    Add(trackerUI.GetDashboardClassKey(candidate), candidate.className or "Classe inconnue")
                elseif key == "specKey" then
                    Add(trackerUI.GetDashboardSpecKey(candidate), candidate.specName or "Spé inconnue")
                elseif key == "zone" then
                    for zone, amount in pairs(candidate.zoneXP or {}) do
                        if (tonumber(amount) or 0) > 0 then
                            Add(zone, zone)
                        end
                    end
                    Add(candidate.startZone, candidate.startZone)
                    Add(candidate.endZone, candidate.endZone)
                elseif key == "levelBand" then
                    for band, amount in pairs(candidate.levelXP or {}) do
                        if (tonumber(amount) or 0) > 0 then
                            Add(band, "Niveaux " .. band)
                        end
                    end
                    Add(XPTracker.GetLevelBand(candidate.startLevel, nil, candidate.trackingMode),
                        "Niveaux " .. XPTracker.GetLevelBand(candidate.startLevel, nil, candidate.trackingMode))
                    Add(XPTracker.GetLevelBand(candidate.endLevel, nil, candidate.trackingMode),
                        "Niveaux " .. XPTracker.GetLevelBand(candidate.endLevel, nil, candidate.trackingMode))
                end
            end
        end
    end

    local choices = {{ value = trackerUI.DASHBOARD_ALL, label = "Toutes" }}
    local sorted = {}
    for value in pairs(values) do
        sorted[#sorted + 1] = value
    end
    table.sort(sorted, function(left, right)
        return tostring(labels[left]):lower() < tostring(labels[right]):lower()
    end)
    for _, value in ipairs(sorted) do
        choices[#choices + 1] = { value = value, label = labels[value] }
    end
    return choices
end

function trackerUI.RefreshDashboardFilterChoices()
    local dashboard = trackerUI.dashboard
    if not dashboard or not dashboard.filterControls then
        return
    end
    local history = GetXPSessions()
    local order = { "classKey", "specKey", "zone", "levelBand" }
    local resetFollowing = false
    for _, key in ipairs(order) do
        if resetFollowing then
            trackerUI.dashboardFilters[key] = trackerUI.DASHBOARD_ALL
        end
        local choices = trackerUI.BuildDashboardFilterChoices(history, key)
        local selected = trackerUI.dashboardFilters[key]
        local valid = selected == trackerUI.DASHBOARD_ALL
        for _, choice in ipairs(choices) do
            if choice.value == selected then
                valid = true
                break
            end
        end
        if not valid then
            trackerUI.dashboardFilters[key] = trackerUI.DASHBOARD_ALL
            resetFollowing = true
        end
        dashboard.filterControls[key].SetChoices(choices)
    end
end

function trackerUI.GetDashboardFilteredSessions()
    local filtered = {}
    local filters = trackerUI.dashboardFilters
    for _, session in ipairs(GetXPSessions()) do
        if type(session) == "table" and (tonumber(session.xpGained) or 0) > 0 then
            local candidate = XPTracker.CopyForPreview(session)
            XPTracker.NormalizeSessionZones(candidate)
            if trackerUI.SessionMatchesDashboardFilters(candidate, filters) then
                filtered[#filtered + 1] = candidate
            end
        end
    end
    return filtered
end

function trackerUI.BuildDashboardEntries(map, labeler, limit, ascending, metric)
    local entries = {}
    for key, aggregate in pairs(map or {}) do
        if aggregate and ((metric == "levels" and (tonumber(aggregate.levelsPerHour) or 0) > 0)
                or (metric ~= "levels" and (tonumber(aggregate.xpPerHour) or 0) > 0)) then
            local value = metric == "levels" and aggregate.levelsPerHour or aggregate.xpPerHour
            local tooltipMetric = metric == "levels"
                and ("%.2f niveaux/h"):format(aggregate.levelsPerHour or 0)
                or (trackerUI.FormatXP(aggregate.xpPerHour) .. " XP/h")
            entries[#entries + 1] = {
                key = key,
                label = labeler(key, aggregate),
                value = value or 0,
                valueLabel = trackerUI.FormatDashboardMetric(value, metric),
                aggregate = aggregate,
                tooltip = ("%s · %s actifs"):format(
                    tooltipMetric,
                    FormatDurationCompact(aggregate.durationSeconds or 0)),
            }
        end
    end
    table.sort(entries, function(left, right)
        if ascending then
            local leftLevel = tonumber(tostring(left.key):match("^(%d+)")) or 0
            local rightLevel = tonumber(tostring(right.key):match("^(%d+)")) or 0
            if leftLevel == rightLevel then
                return tostring(left.key) < tostring(right.key)
            end
            return leftLevel < rightLevel
        end
        if left.value == right.value then
            return tostring(left.key) < tostring(right.key)
        end
        return left.value > right.value
    end)
    while #entries > (limit or 5) do
        table.remove(entries)
    end
    return entries
end

function trackerUI.BuildDashboardProfileEntries(stats, metric)
    local specCountByClass = {}
    for _, aggregate in pairs(stats.bySpec or {}) do
        local classKey = aggregate.classToken or aggregate.className or "unknown"
        specCountByClass[classKey] = (specCountByClass[classKey] or 0) + 1
    end

    local classEntries = trackerUI.BuildDashboardEntries(stats.byClass, function(_, aggregate)
        return "Classe · " .. (aggregate.className or "Inconnue")
    end, 2, nil, metric)
    local entries = {}
    for _, entry in ipairs(classEntries) do
        local aggregate = entry.aggregate
        local classKey = aggregate.classToken or aggregate.className or "unknown"
        local specCount = specCountByClass[classKey] or 0
        if specCount ~= 1 then
            if specCount > 1 then
                entry.label = entry.label .. (" · %d spés"):format(specCount)
            end
            entry.color = trackerUI.GetDashboardClassColor(aggregate.classToken)
            entries[#entries + 1] = entry
        end
    end
    for _, entry in ipairs(entries) do
        entry.tone = "category"
    end

    local specs = trackerUI.BuildDashboardEntries(stats.bySpec, function(_, aggregate)
        return "Spé · " .. (aggregate.specName or "Inconnue")
            .. " · " .. (aggregate.className or "?")
    end, 3, nil, metric)
    for _, entry in ipairs(specs) do
        entry.tone = "success"
        entry.color = trackerUI.GetDashboardClassColor(entry.aggregate.classToken)
        entries[#entries + 1] = entry
    end
    return entries
end

function trackerUI.BuildDashboardRecentEntries(history, metric)
    history = history or GetXPSessions()
    local entries = {}
    local first = math.max(1, #history - 7)
    for index = first, #history do
        local session = history[index]
        if session and ((metric == "levels" and (tonumber(session.levelsPerHour) or 0) > 0)
                or (metric ~= "levels" and (tonumber(session.xpPerHour) or 0) > 0)) then
            entries[#entries + 1] = {
                label = date and date("%d/%m", session.endedAt or session.startedAt or GetNow())
                    or tostring(index),
                value = metric == "levels" and session.levelsPerHour or session.xpPerHour or 0,
                valueLabel = trackerUI.FormatDashboardMetric(
                    metric == "levels" and session.levelsPerHour or session.xpPerHour, metric),
                tooltip = ("%s · %s actifs|n%s · niveaux %s-%s"):format(
                    trackerUI.FormatDashboardMetric(
                        metric == "levels" and session.levelsPerHour or session.xpPerHour, metric),
                    FormatDurationCompact(session.durationSeconds or 0),
                    session.specName or "Spé inconnue",
                    tostring(session.startLevel or "?"),
                    tostring(session.endLevel or "?")),
            }
        end
    end
    return entries
end

function trackerUI.AttachDashboardTooltip(row)
    if row.dashboardTooltipAttached then
        return
    end
    row.dashboardTooltipAttached = true
    row:SetScript("OnEnter", function(self)
        if not self.dashboardEntry or not GameTooltip then
            return
        end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.dashboardEntry.label or "Session XP")
        if self.dashboardEntry.tooltip then
            GameTooltip:AddLine(self.dashboardEntry.tooltip, 1, 1, 1, true)
        end
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function()
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)
end

function trackerUI.RenderDashboardBars(card, entries)
    local UI = YayaCore.UI
    card.chartRows = card.chartRows or {}
    local rowHeight = UI.SIZE.rowH
    local labelWidth = 132
    local valueWidth = 48
    local barGap = UI.PAD.sm
    local chartWidth = math.max(20, card:GetWidth() - (UI.PAD.md * 2)
        - labelWidth - valueWidth - (barGap * 2))
    local maximum = 0
    for _, entry in ipairs(entries or {}) do
        maximum = math.max(maximum, tonumber(entry.value) or 0)
    end

    if #entries == 0 then
        if not card.empty then
            card.empty = trackerUI.CreateDashboardLabel(card, UI.FONT.muted, "CENTER")
            card.empty:SetPoint("TOPLEFT", card, "TOPLEFT", UI.PAD.md, -UI.SIZE.headerH - UI.PAD.md)
            card.empty:SetPoint("TOPRIGHT", card, "TOPRIGHT", -UI.PAD.md, -UI.SIZE.headerH - UI.PAD.md)
            card.empty:SetTextColor(UI.Unpack(UI.COLOR.textMuted))
        end
        card.empty:SetText("Pas encore assez de données XP")
        card.empty:Show()
    elseif card.empty then
        card.empty:Hide()
    end

    for index = 1, math.max(#entries, #card.chartRows) do
        local entry = entries[index]
        local row = card.chartRows[index]
        if entry then
            if not row then
                row = CreateFrame("Button", nil, card)
                row:SetHeight(rowHeight)
                row.label = trackerUI.CreateDashboardLabel(row, UI.FONT.muted, "LEFT")
                row.label:SetWidth(labelWidth)
                row.label:SetPoint("LEFT", row, "LEFT", 0, 0)
                row.value = trackerUI.CreateDashboardLabel(row, UI.FONT.body, "RIGHT")
                row.value:SetWidth(valueWidth)
                row.value:SetPoint("RIGHT", row, "RIGHT", 0, 0)
                row.bar = row:CreateTexture(nil, "ARTWORK")
                row.bar:SetHeight(6)
                row.barBackground = row:CreateTexture(nil, "BACKGROUND")
                row.barBackground:SetHeight(6)
                trackerUI.AttachDashboardTooltip(row)
                card.chartRows[index] = row
            end
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", card, "TOPLEFT", UI.PAD.md, -UI.SIZE.headerH - UI.PAD.md
                - ((index - 1) * rowHeight))
            row:SetPoint("TOPRIGHT", card, "TOPRIGHT", -UI.PAD.md, -UI.SIZE.headerH - UI.PAD.md
                - ((index - 1) * rowHeight))
            row.label:SetText(entry.label or "")
            row.value:SetText(entry.valueLabel or trackerUI.FormatDashboardXP(entry.value))
            row.label:SetTextColor(UI.Unpack(UI.COLOR.text))
            row.value:SetTextColor(UI.Unpack(UI.COLOR[entry.tone or "accent"] or UI.COLOR.accent))
            row.barBackground:ClearAllPoints()
            row.barBackground:SetPoint("LEFT", row, "LEFT", labelWidth + barGap, 0)
            row.barBackground:SetWidth(chartWidth)
            row.barBackground:SetColorTexture(UI.Unpack(UI.COLOR.rowOdd))
            row.bar:ClearAllPoints()
            row.bar:SetPoint("LEFT", row.barBackground, "LEFT", 0, 0)
            row.bar:SetWidth(math.max(1, chartWidth * (maximum > 0
                and ((tonumber(entry.value) or 0) / maximum) or 0)))
            local color = entry.color
            if color and color.r then
                row.label:SetTextColor(color.r, color.g, color.b, 1)
                row.value:SetTextColor(color.r, color.g, color.b, 1)
                row.bar:SetColorTexture(color.r, color.g, color.b, 1)
            else
                row.label:SetTextColor(UI.Unpack(UI.COLOR.text))
                row.value:SetTextColor(UI.Unpack(UI.COLOR[entry.tone or "accent"] or UI.COLOR.accent))
                row.bar:SetColorTexture(UI.Unpack(UI.COLOR[entry.tone or "accent"] or UI.COLOR.accent))
            end
            row.dashboardEntry = entry
            row:Show()
        elseif row then
            row.dashboardEntry = nil
            row:Hide()
        end
    end
end

function trackerUI.RenderDashboardTrend(card, entries)
    local UI = YayaCore.UI
    card.trendRows = card.trendRows or {}
    local innerWidth = math.max(20, card:GetWidth() - UI.PAD.md * 2)
    local chartHeight = math.max(20, card:GetHeight() - UI.SIZE.headerH - UI.PAD.xl * 2)
    local slotWidth = innerWidth / math.max(1, #entries)
    local maximum = 0
    for _, entry in ipairs(entries or {}) do
        maximum = math.max(maximum, tonumber(entry.value) or 0)
    end

    for index = 1, math.max(#entries, #card.trendRows) do
        local entry = entries[index]
        local row = card.trendRows[index]
        if entry then
            if not row then
                row = CreateFrame("Button", nil, card)
                row.background = row:CreateTexture(nil, "BACKGROUND")
                row.fill = row:CreateTexture(nil, "ARTWORK")
                row.value = trackerUI.CreateDashboardLabel(row, UI.FONT.muted, "CENTER")
                row.label = trackerUI.CreateDashboardLabel(row, UI.FONT.muted, "CENTER")
                trackerUI.AttachDashboardTooltip(row)
                card.trendRows[index] = row
            end
            row:ClearAllPoints()
            row:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", UI.PAD.md + ((index - 1) * slotWidth), UI.PAD.md)
            row:SetSize(math.max(1, slotWidth - UI.PAD.xs), chartHeight)
            row.background:ClearAllPoints()
            row.background:SetPoint("BOTTOM", row, "BOTTOM", 0, UI.PAD.xl)
            row.background:SetSize(math.max(1, slotWidth - UI.PAD.xs), math.max(1, chartHeight - UI.PAD.xl))
            row.background:SetColorTexture(UI.Unpack(UI.COLOR.rowOdd))
            row.fill:ClearAllPoints()
            row.fill:SetPoint("BOTTOM", row.background, "BOTTOM", 0, 0)
            row.fill:SetWidth(math.max(1, slotWidth - UI.PAD.xs))
            row.fill:SetHeight(math.max(1, (chartHeight - UI.PAD.xl)
                * (maximum > 0 and ((tonumber(entry.value) or 0) / maximum) or 0)))
            row.fill:SetColorTexture(UI.Unpack(UI.COLOR.accent))
            row.value:ClearAllPoints()
            row.value:SetPoint("BOTTOM", row, "TOP", 0, UI.PAD.xs)
            row.value:SetWidth(math.max(1, slotWidth))
            row.value:SetText(entry.valueLabel or trackerUI.FormatDashboardXP(entry.value))
            row.value:SetTextColor(UI.Unpack(UI.COLOR.textMuted))
            row.label:ClearAllPoints()
            row.label:SetPoint("BOTTOM", row, "BOTTOM", 0, 0)
            row.label:SetWidth(math.max(1, slotWidth))
            row.label:SetText(entry.label or "")
            row.label:SetTextColor(UI.Unpack(UI.COLOR.textMuted))
            row.dashboardEntry = entry
            row:Show()
        elseif row then
            row.dashboardEntry = nil
            row:Hide()
        end
    end
end

function trackerUI.CreateDashboardFilter(parent, key, label, width)
    local UI = YayaCore.UI
    local control = UI.CreateDropdown(parent, label, {
        choices = {{ value = trackerUI.DASHBOARD_ALL, label = "Toutes" }},
        get = function()
            return trackerUI.dashboardFilters[key]
        end,
        onSelect = function(value)
            trackerUI.dashboardFilters[key] = value
            trackerUI.RefreshDashboardFilterChoices()
            trackerUI.UpdateDashboard()
        end,
        width = width - 56,
        labelWidth = 48,
    })
    if control then
        control:SetSize(width, UI.SIZE.iconButton)
        control.SetTooltip("Filtre " .. label,
            "Les filtres suivants se resserrent selon ce choix.")
    end
    return control
end

function trackerUI.CreateDashboardFrame()
    if trackerUI.dashboard then
        return trackerUI.dashboard
    end

    local UI = YayaCore.UI
    local dashboard = CreateFrame("Frame", addonName .. "Dashboard", UIParent, "BackdropTemplate")
    trackerUI.dashboard = dashboard
    dashboard:SetFrameStrata("HIGH")
    dashboard:SetClampedToScreen(true)
    dashboard:SetMovable(true)
    dashboard:SetSize(720, 804)
    dashboard:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    UI.ApplyPanelBackdrop(dashboard)

    dashboard.header = UI.CreateHeader(dashboard, "Yaya Session Tracker · XP Dashboard", {
        moveTarget = dashboard,
    })
    UI.CreateCloseButton(dashboard.header, dashboard)
    dashboard.refreshButton = UI.CreateButton(dashboard.header, "Maj", {
        width = 34,
        height = UI.SIZE.glyph,
        small = true,
    })
    if dashboard.refreshButton then
        dashboard.header.AddButton(dashboard.refreshButton)
        dashboard.refreshButton:SetScript("OnClick", function()
            trackerUI.UpdateDashboard()
        end)
        dashboard.refreshButton.SetTooltip("Actualiser", "Recalcule les KPI et les graphiques.")
    end

    dashboard.cards = {}
    local cardWidth = 168
    local cardHeight = 62
    local cardGap = UI.PAD.sm
    local cardTop = UI.SIZE.headerH + UI.PAD.lg
    local cardTitles = { "Métrique moyenne", "Sessions filtrées", "Temps actif", "Meilleure session" }
    for index, title in ipairs(cardTitles) do
        local card = trackerUI.CreateDashboardMetricCard(dashboard, title, cardWidth, cardHeight)
        card:SetPoint("TOPLEFT", dashboard, "TOPLEFT", UI.PAD.lg + ((index - 1) * (cardWidth + cardGap)), -cardTop)
        dashboard.cards[index] = card
    end

    dashboard.filterBar = CreateFrame("Frame", nil, dashboard, "BackdropTemplate")
    dashboard.filterBar:SetSize(688, UI.SIZE.iconButton + UI.PAD.sm)
    dashboard.filterBar:SetPoint("TOPLEFT", dashboard, "TOPLEFT", UI.PAD.lg,
        -(cardTop + cardHeight + UI.PAD.md))
    UI.ApplyPanelBackdrop(dashboard.filterBar, { color = UI.COLOR.header })
    dashboard.filterControls = {}
    local filterWidth = 164
    local filterGap = UI.PAD.sm
    for index, key in ipairs({ "classKey", "specKey", "zone", "levelBand" }) do
        local labels = {
            classKey = "Classe",
            specKey = "Spé",
            zone = "Zone",
            levelBand = "Niveau",
        }
        local control = trackerUI.CreateDashboardFilter(
            dashboard.filterBar, key, labels[key], filterWidth)
        if control then
            control:SetPoint("TOPLEFT", dashboard.filterBar, "TOPLEFT",
                UI.PAD.sm + ((index - 1) * (filterWidth + filterGap)), -UI.PAD.xs)
            dashboard.filterControls[key] = control
        end
    end

    dashboard.configBar = CreateFrame("Frame", nil, dashboard)
    dashboard.configBar:SetSize(688, UI.SIZE.iconButton)
    dashboard.configBar:SetPoint("TOPLEFT", dashboard.filterBar, "BOTTOMLEFT", 0, -UI.PAD.sm)
    dashboard.metricSwitchButton = UI.CreateButton(dashboard.configBar, "Vue : XP/h", {
        width = 128,
        height = UI.SIZE.iconButton,
        small = true,
    })
    if dashboard.metricSwitchButton then
        dashboard.metricSwitchButton:SetPoint("TOPLEFT", dashboard.configBar, "TOPLEFT", 0, 0)
        dashboard.metricSwitchButton:SetScript("OnClick", function()
            GetSettings().xpDashboardMetric = trackerUI.GetDashboardMetric() == "levels"
                and "xph" or "levels"
            trackerUI.UpdateDashboard()
        end)
        dashboard.metricSwitchButton.SetTooltip("Changer de métrique",
            "Bascule entre XP/h et Niveaux/h. Une seule métrique est affichée à la fois.")
    end
    dashboard.modeControl = UI.CreateDropdown(dashboard.configBar, "Données", {
        choices = {
            { value = XPTracker.MODE_BELOW_80, label = "Niveaux 1–80" },
            { value = XPTracker.MODE_80_TO_90, label = "Niveaux 80–90" },
        },
        get = function()
            return trackerUI.GetXPTrackingMode()
        end,
        onSelect = function(value)
            GetSettings().xpTrackingMode = XPTracker.NormalizeMode(value)
            SwitchXPTrackingMode()
            trackerUI.dashboardFilters = {
                classKey = trackerUI.DASHBOARD_ALL,
                specKey = trackerUI.DASHBOARD_ALL,
                zone = trackerUI.DASHBOARD_ALL,
                levelBand = trackerUI.DASHBOARD_ALL,
            }
            trackerUI.UpdateDashboard()
        end,
        width = 104,
        labelWidth = 52,
    })
    if dashboard.modeControl then
        dashboard.modeControl:SetSize(164, UI.SIZE.iconButton)
        dashboard.modeControl:SetPoint("TOPLEFT", dashboard.configBar, "TOPLEFT", 140, 0)
        dashboard.modeControl.SetTooltip("Jeu de données XP",
            "Les sessions 1–80 et 80–90 sont stockées et analysées séparément.")
    end
    dashboard.bandControl = UI.CreateDropdown(dashboard.configBar, "Tranches", {
        choices = {
            { value = 5, label = "5 niveaux" },
            { value = 10, label = "10 niveaux" },
            { value = 20, label = "20 niveaux" },
        },
        get = function()
            return GetSettings().xpLevelBandSize
        end,
        onSelect = function(value)
            GetSettings().xpLevelBandSize = tonumber(value) or 10
            XPTracker.SetLevelBandSize(GetSettings().xpLevelBandSize)
            trackerUI.RefreshDashboardFilterChoices()
            trackerUI.UpdateDashboard()
        end,
        width = 108,
        labelWidth = 54,
    })
    if dashboard.bandControl then
        dashboard.bandControl:SetSize(180, UI.SIZE.iconButton)
        dashboard.bandControl:SetPoint("TOPLEFT", dashboard.configBar, "TOPLEFT", 316, 0)
        dashboard.bandControl.SetTooltip("Taille des tranches",
            "Les nouvelles sessions et le regroupement des données suivent ce réglage.")
    end
    dashboard.filterSummary = trackerUI.CreateDashboardLabel(dashboard.configBar, UI.FONT.muted, "LEFT")
    dashboard.filterSummary:SetPoint("LEFT", dashboard.configBar, "LEFT", 508, 0)
    dashboard.filterSummary:SetPoint("RIGHT", dashboard.configBar, "RIGHT", 0, 0)
    dashboard.filterSummary:SetTextColor(UI.Unpack(UI.COLOR.textMuted))

    local chartWidth = 348
    local chartHeight = 168
    local chartTop = cardTop + cardHeight + UI.PAD.md
        + dashboard.filterBar:GetHeight() + UI.PAD.sm + dashboard.configBar:GetHeight() + UI.PAD.md
    dashboard.profileChart = trackerUI.CreateDashboardChartCard(
        dashboard, "Classes & spécialisations", chartWidth, chartHeight)
    dashboard.profileChart:SetPoint("TOPLEFT", dashboard, "TOPLEFT", UI.PAD.lg, -chartTop)
    dashboard.zoneChart = trackerUI.CreateDashboardChartCard(
        dashboard, "Zones", chartWidth, chartHeight)
    dashboard.zoneChart:SetPoint("TOPRIGHT", dashboard, "TOPRIGHT", -UI.PAD.lg, -chartTop)

    local lowerTop = chartTop + chartHeight + UI.PAD.md
    dashboard.levelChart = trackerUI.CreateDashboardChartCard(
        dashboard, "Tranches de niveau", chartWidth, chartHeight)
    dashboard.levelChart:SetPoint("TOPLEFT", dashboard, "TOPLEFT", UI.PAD.lg, -lowerTop)
    dashboard.trendChart = trackerUI.CreateDashboardChartCard(
        dashboard, "Tendance des sessions filtrées", chartWidth, chartHeight)
    dashboard.trendChart:SetPoint("TOPRIGHT", dashboard, "TOPRIGHT", -UI.PAD.lg, -lowerTop)
    local sourceTop = lowerTop + chartHeight + UI.PAD.md
    dashboard.sourceChart = trackerUI.CreateDashboardChartCard(
        dashboard, "Sources XP", chartWidth, chartHeight)
    dashboard.sourceChart:SetPoint("TOPLEFT", dashboard, "TOPLEFT", UI.PAD.lg, -sourceTop)

    dashboard.footer = trackerUI.CreateDashboardLabel(dashboard, UI.FONT.muted, "LEFT")
    dashboard.footer:SetPoint("BOTTOMLEFT", dashboard, "BOTTOMLEFT", UI.PAD.lg, UI.PAD.sm)
    dashboard.footer:SetPoint("BOTTOMRIGHT", dashboard, "BOTTOMRIGHT", -UI.PAD.lg, UI.PAD.sm)
    dashboard.footer:SetTextColor(UI.Unpack(UI.COLOR.textMuted))
    dashboard:SetScript("OnShow", function()
        trackerUI.UpdateDashboard()
    end)
    dashboard:Hide()
    return dashboard
end

function trackerUI.UpdateDashboard()
    local dashboard = trackerUI.dashboard
    if not dashboard or not dashboard:IsShown() then
        return
    end

    local settings = GetSettings()
    XPTracker.SetLevelBandSize(settings.xpLevelBandSize)
    trackerUI.RefreshDashboardFilterChoices()
    local history = trackerUI.GetDashboardFilteredSessions()
    local stats = XPTracker.BuildStats(history, trackerUI.GetXPTrackingMode())
    local live = BuildActiveXPSnapshot()
    local UI = YayaCore.UI
    local metric = trackerUI.GetDashboardMetric()
    local metricLabel = trackerUI.GetDashboardMetricLabel(metric)
    dashboard.profileChart.title:SetText("Classes & spécialisations · " .. metricLabel)
    dashboard.zoneChart.title:SetText("Zones · " .. metricLabel)
    dashboard.levelChart.title:SetText("Tranches de niveau · " .. metricLabel)
    dashboard.trendChart.title:SetText("Tendance des sessions filtrées · " .. metricLabel)
    if dashboard.metricSwitchButton then
        dashboard.metricSwitchButton:SetText("Vue : " .. metricLabel)
    end
    if dashboard.bandControl then
        dashboard.bandControl.Refresh()
    end
    if dashboard.modeControl then
        dashboard.modeControl.Refresh()
    end
    if dashboard.filterSummary then
        dashboard.filterSummary:SetText(("%d session(s) · filtres appliqués"):format(#history))
    end
    local averageMetric = metric == "levels" and stats.levelsPerHour or stats.xpPerHour
    local bestMetric = metric == "levels" and stats.bestLevelsPerHour or stats.bestXPH
    dashboard.cards[1].title:SetText(metricLabel .. " moyenne")
    dashboard.cards[1].SetMetric(
        trackerUI.FormatDashboardMetric(averageMetric, metric),
        metric == "levels"
            and ("%.0f niveau(x) gagné(s)"):format(stats.levelsGained or 0)
            or (trackerUI.FormatXP(stats.xpGained) .. " XP gagné(e)"),
        "success")
    dashboard.cards[2].SetMetric(
        tostring(stats.sessions or 0),
        "session(s) XP",
        "accent")
    dashboard.cards[3].SetMetric(
        FormatDurationCompact(stats.durationSeconds or 0),
        "temps actif cumulé",
        "accent")
    dashboard.cards[4].SetMetric(
        trackerUI.FormatDashboardMetric(bestMetric, metric),
        "meilleure session filtrée",
        "accent")

    trackerUI.RenderDashboardBars(dashboard.profileChart,
        trackerUI.BuildDashboardProfileEntries(stats, metric))
    trackerUI.RenderDashboardBars(dashboard.zoneChart, trackerUI.BuildDashboardEntries(stats.byZone, function(key)
        return key
    end, 5, nil, metric))
    trackerUI.RenderDashboardBars(dashboard.levelChart, trackerUI.BuildDashboardEntries(stats.byLevelBand, function(key)
        return "Niveaux " .. key
    end, 5, true, metric))
    trackerUI.RenderDashboardBars(dashboard.sourceChart, trackerUI.BuildDashboardEntries(stats.bySource, function(key)
        return XPTracker.GetSourceLabel(key)
    end, 4, nil, metric))
    trackerUI.RenderDashboardTrend(dashboard.trendChart,
        trackerUI.BuildDashboardRecentEntries(history, metric))

    if live then
        local liveMetric = metric == "levels" and live.levelsPerHour or live.xpPerHour
        dashboard.footer:SetText(("En cours · %s · %s · %s"):format(
            live.specName or "Spé inconnue",
            live.endZone or live.startZone or "Zone inconnue",
            trackerUI.FormatDashboardMetric(liveMetric, metric)))
        dashboard.footer:SetTextColor(UI.Unpack(UI.COLOR.success))
    else
        dashboard.footer:SetText(("Historique %s · temps actif"):format(
            XPTracker.GetXPModeConfig().label))
        dashboard.footer:SetTextColor(UI.Unpack(UI.COLOR.textMuted))
    end
end

function trackerUI.MetricTooltip(title, aggregate)
    return {
        title = title,
        body = ("%s XP|n%s XP/h · %.2f niveaux/h · %s|n%d session(s) · %d niveau(x)|nMeilleur : %s XP/h"):format(
            trackerUI.FormatXP(aggregate.xpGained),
            trackerUI.FormatXP(aggregate.xpPerHour),
            aggregate.levelsPerHour or 0,
            FormatDurationCompact(aggregate.durationSeconds),
            aggregate.sessions or 0,
            aggregate.levelsGained or 0,
            trackerUI.FormatXP(aggregate.bestXPH)),
    }
end

function trackerUI.BuildStatsRows()
    local history = GetXPSessions()
    local stats = XPTracker.BuildStats(history, trackerUI.GetXPTrackingMode())
    local live = BuildActiveXPSnapshot()
    local rows = {}
    local signature = ("%d:%s:%s:%d"):format(
        stats.sessions,
        tostring(stats.xpGained),
        live and tostring(live.xpGained) or "0",
        #history)

    local function AddRow(label, value, tone, tooltip)
        rows[#rows + 1] = {
            label = label,
            value = value,
            tone = tone,
            tooltip = tooltip,
        }
    end

    local function AddHeading(label)
        rows[#rows + 1] = {
            label = label,
            value = "",
            tone = "category",
            heading = true,
        }
    end

    local function AddMap(title, map, labeler, descending)
        local entries = {}
        for key, aggregate in pairs(map or {}) do
            entries[#entries + 1] = { key = key, aggregate = aggregate }
        end
        table.sort(entries, function(left, right)
            if descending then
                if left.aggregate.xpGained == right.aggregate.xpGained then
                    return tostring(left.key) < tostring(right.key)
                end
                return left.aggregate.xpGained > right.aggregate.xpGained
            end
            local leftLevel = tonumber(tostring(left.key):match("^(%d+)")) or 0
            local rightLevel = tonumber(tostring(right.key):match("^(%d+)")) or 0
            if leftLevel == rightLevel then
                return tostring(left.key) < tostring(right.key)
            end
            return leftLevel < rightLevel
        end)
        if #entries == 0 then
            return
        end

        AddHeading(title)
        for _, entry in ipairs(entries) do
            local label = labeler(entry.key, entry.aggregate)
            AddRow(
                label,
                trackerUI.FormatXP(entry.aggregate.xpPerHour) .. "/h",
                nil,
                trackerUI.MetricTooltip(label, entry.aggregate)
            )
        end
    end

    AddHeading("Résumé")
    AddRow("XP totale", trackerUI.FormatXP(stats.xpGained), "accent")
    AddRow("XP/h moyen", trackerUI.FormatXP(stats.xpPerHour), "success")
    AddRow("Niveaux/h", ("%.2f"):format(stats.levelsPerHour or 0), "success")
    AddRow("Temps actif", FormatDurationCompact(stats.durationSeconds))
    AddRow("Sessions / niveaux", ("%d / %d"):format(stats.sessions, stats.levelsGained))

    AddMap("Sources XP", stats.bySource, function(key)
        return XPTracker.GetSourceLabel(key)
    end, true)

    if live then
        AddRow(
            "En cours · " .. (live.specName or "Spé inconnue"),
            trackerUI.FormatXP(live.xpPerHour) .. "/h",
            "success",
            trackerUI.MetricTooltip("Session XP en cours", {
                xpGained = live.xpGained,
                xpPerHour = live.xpPerHour,
                levelsPerHour = live.levelsPerHour,
                durationSeconds = live.durationSeconds,
                sessions = 1,
                levelsGained = live.levelsGained,
                bestXPH = live.xpPerHour,
            })
        )
    end

    AddMap("Classes", stats.byClass, function(_, aggregate)
        return aggregate.className or "Classe inconnue"
    end, true)
    AddMap("Spécialisations", stats.bySpec, function(_, aggregate)
        return (aggregate.specName or "Spé inconnue") .. " · " .. (aggregate.className or "?")
    end, true)
    AddMap("Zones", stats.byZone, function(key)
        return key
    end, true)
    AddMap("Tranches de niveau", stats.byLevelBand, function(key)
        return "Niveaux " .. key
    end, false)
    AddMap("Zone · tranche", stats.byZoneLevelBand, function(key)
        local separator = string.find(key, "\31", 1, true)
        if not separator then
            return key
        end
        return string.sub(key, 1, separator - 1) .. " · " .. string.sub(key, separator + 1)
    end, true)

    if #history > 0 then
        AddHeading("Sessions récentes")
        local first = math.max(1, #history - 19)
        for index = #history, first, -1 do
            local session = history[index]
            local label = ("%s · %s"):format(
                FormatTimestamp(session.endedAt),
                session.specName or "Spé inconnue")
            local zone = session.startZone or "Zone inconnue"
            AddRow(
                label,
                trackerUI.FormatXP(session.xpPerHour) .. "/h",
                nil,
                {
                    title = "Session XP",
                    body = ("%s XP · %s|n%s · niveaux %s-%s|n%s → %s"):format(
                        trackerUI.FormatXP(session.xpGained),
                        FormatDurationCompact(session.durationSeconds or 0),
                        zone,
                        tostring(session.startLevel or "?"),
                        tostring(session.endLevel or "?"),
                        session.startZone or "?",
                        session.endZone or "?"),
                }
            )
        end
    end

    if stats.sessions == 0 and not live then
        AddRow("Aucune session XP enregistrée", "", "textMuted")
    end
    return rows, signature
end

function trackerUI.InitStatsRow(row, item)
    local UI = YayaCore.UI
    UI.DecorateRow(row, {
        height = UI.SIZE.rowHCompact,
        labelFont = item.heading and UI.FONT.header or UI.FONT.muted,
        valueFont = UI.FONT.body,
        tooltipAnchor = "ANCHOR_RIGHT",
    })
    row.Reset()
    UI.SetFont(row.label, item.heading and UI.FONT.header or UI.FONT.muted)
    row.label:SetText(item.label or "")
    row.value:SetText(item.value or "")
    row.SetTone(item.tone)
    row.SetLabelTone(item.heading and "category" or "text")
    row.SetStripe(item.index or 1)
    if item.tooltip then
        row.SetTooltip(item.tooltip.title, item.tooltip.body)
    end
    if type(row.SetMouseClickEnabled) == "function" then
        row:SetMouseClickEnabled(false)
        if type(row.SetMouseMotionEnabled) == "function" then
            row:SetMouseMotionEnabled(true)
        end
    end
end

function trackerUI.UpdateStatsButton()
    if not trackerFrame or not trackerFrame.statsButton then
        return
    end
    local label = trackerFrame.statsMode and "Live" or "Stats"
    if type(trackerFrame.statsButton.SetLabel) == "function" then
        trackerFrame.statsButton.SetLabel(label)
    else
        trackerFrame.statsButton:SetText(label)
    end
end

function trackerUI.UpdateStatsView()
    if not trackerFrame or not trackerFrame.statsMode then
        return
    end

    local items, signature = trackerUI.BuildStatsRows()
    for index, item in ipairs(items) do
        item.index = index
    end

    local UI = YayaCore.UI
    local visibleRows = math.max(1, math.min(#items, 8))
    if trackerFrame.statsList then
        trackerFrame.statsHost:SetHeight(visibleRows * UI.SIZE.rowHCompact)
        trackerFrame.statsHost:Show()
        trackerFrame:SetHeight(trackerFrame.statsHost:GetHeight() + UI.PAD.xs)
        if signature ~= trackerFrame.statsSignature then
            trackerFrame.statsList.SetItems(items, trackerFrame.statsSignature == nil)
            trackerFrame.statsSignature = signature
        end
        return
    end

    trackerFrame.statsHost:Hide()
    local stack = UI.StackLayout(trackerFrame)
    for index, item in ipairs(items) do
        local row = trackerFrame.statsRows[index]
        if not row then
            row = UI.CreateRow(trackerFrame, {
                height = UI.SIZE.rowHCompact,
                labelFont = UI.FONT.muted,
                valueFont = UI.FONT.body,
                tooltipAnchor = "ANCHOR_RIGHT",
            })
            trackerFrame.statsRows[index] = row
        end
        trackerUI.InitStatsRow(row, item)
        row:Show()
        stack.Add(row, 0, { height = UI.SIZE.rowHCompact })
    end
    for index = #items + 1, #trackerFrame.statsRows do
        trackerFrame.statsRows[index]:Hide()
    end
    trackerFrame:SetHeight(stack.Finish(UI.PAD.xs))
end

function trackerUI.ToggleStats()
    local dashboard = trackerUI.CreateDashboardFrame()
    if not dashboard then
        return
    end
    if dashboard:IsShown() then
        dashboard:Hide()
    else
        dashboard:Show()
        trackerUI.UpdateDashboard()
    end
end

--- Contenu de la section, une entree par ligne.
--
-- Chaque valeur a sa propre colonne alignee a droite. Auparavant le libelle et
-- la valeur etaient concatenes dans une seule chaine alignee a gauche, donc les
-- chiffres ne s'alignaient pas d'une ligne a l'autre.
local function BuildFrameRows()
    if not activeSession then
        return {
            { label = "Etat", value = "inactive", tone = "textMuted" },
        }
    end

    local snapshot = BuildSessionSnapshot(activeSession)
    local rows = {
        { label = "GPH", value = FormatGoldCompact(snapshot.gph), tone = "success" },
        { label = "Time", value = FormatDurationCompact(snapshot.durationSeconds) },
        { label = "Gold", value = FormatGoldCompact(snapshot.rawGold) },
        { label = "Loot", value = FormatGoldCompact(snapshot.itemValue), topItems = snapshot.topItems },
        { label = "Total", value = FormatGoldCompact(snapshot.totalValue), tone = "accent" },
    }

    if snapshot.corrosiveCoin > 0 then
        rows[#rows + 1] = {
            label = "Coin/h",
            value = BreakUpLargeNumbers(snapshot.corrosiveCoinPerHour or 0),
        }
    end

    local xpSnapshot = BuildActiveXPSnapshot()
    local modeConfig = trackerUI.GetXPModeConfig()
    if xpSnapshot and GetPlayerLevel() < modeConfig.maxLevel then
        rows[#rows + 1] = {
            label = "XP/h",
            value = BreakUpLargeNumbers(xpSnapshot.xpPerHour or 0),
            tooltip = {
                title = "Session XP active",
                body = ("%s XP en %s|n%s · niveau %s-%s"):format(
                    BreakUpLargeNumbers(xpSnapshot.xpGained or 0),
                    FormatDurationCompact(xpSnapshot.durationSeconds or 0),
                    xpSnapshot.specName or "Spé inconnue",
                    tostring(xpSnapshot.startLevel or "?"),
                    tostring(xpSnapshot.endLevel or "?"))
            },
        }
        rows[#rows + 1] = {
            label = "Niveaux/h",
            value = ("%.2f"):format(xpSnapshot.levelsPerHour or 0),
            tone = "success",
        }
    end

    return rows
end

local function EnsureTrackerRow(index)
    local existing = trackerFrame.rows[index]
    if existing then
        return existing
    end

    local row = YayaCore.UI.CreateRow(trackerFrame, {
        height = YayaCore.UI.SIZE.rowHCompact,
        labelFont = YayaCore.UI.FONT.muted,
        valueFont = YayaCore.UI.FONT.body,
        tooltipAnchor = "ANCHOR_LEFT",
    })
    trackerFrame.rows[index] = row
    return row
end

function UpdateFrame()
    if not trackerFrame then
        return
    end

    if trackerCollapsed then
        for _, row in ipairs(trackerFrame.rows) do
            row:Hide()
        end
        for _, row in ipairs(trackerFrame.statsRows or {}) do
            row:Hide()
        end
        if trackerFrame.statsHost then
            trackerFrame.statsHost:Hide()
        end
        trackerFrame:SetHeight(1)
    elseif trackerFrame.statsMode then
        for _, row in ipairs(trackerFrame.rows) do
            row:Hide()
        end
        trackerUI.UpdateStatsView()
    else
        for _, row in ipairs(trackerFrame.statsRows or {}) do
            row:Hide()
        end
        if trackerFrame.statsHost then
            trackerFrame.statsHost:Hide()
        end
        local rows = BuildFrameRows()
        local stack = YayaCore.UI.StackLayout(trackerFrame)

        for index, data in ipairs(rows) do
            local row = EnsureTrackerRow(index)
            row.Reset()
            row.label:SetText(data.label)
            row.value:SetText(data.value)
            row.SetTone(data.tone)
            row.SetStripe(index)
            if data.topItems then
                ApplyLootTooltip(row, data.topItems)
            elseif data.tooltip then
                row.SetTooltip(data.tooltip.title, data.tooltip.body)
            end
            row:Show()
            stack.Add(row, 0, { height = YayaCore.UI.SIZE.rowHCompact })
        end

        for index = #rows + 1, #trackerFrame.rows do
            trackerFrame.rows[index]:Hide()
        end

        -- La hauteur suit le nombre de lignes reellement affichees. Elle etait
        -- figee a 106 px, donc la section reservait de la place pour des lignes
        -- absentes.
        trackerFrame:SetHeight(stack.Finish(YayaCore.UI.PAD.xs))
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
    -- Pas de fond ici : celui du conteneur suffit. La section en repeignait un
    -- identique par-dessus, ce qui portait l'opacite reelle a environ 80 %.
    --
    -- Pas de largeur non plus : YayaFrame etire chaque section entre ses
    -- gouttieres. Les 132 px declares etaient morts, et le SetWidth(102) des
    -- lignes laissait la moitie de la place inutilisee.
    trackerFrame:SetSize(1, 1)
    trackerFrame.rows = {}
    trackerFrame.statsRows = {}
    trackerFrame.statsMode = false

    trackerFrame.statsHost = CreateFrame("Frame", nil, trackerFrame)
    trackerFrame.statsHost:SetPoint("TOPLEFT", trackerFrame, "TOPLEFT", 0, 0)
    trackerFrame.statsHost:SetPoint("TOPRIGHT", trackerFrame, "TOPRIGHT", 0, 0)
    trackerFrame.statsHost:SetHeight(YayaCore.UI.SIZE.rowHCompact)
    trackerFrame.statsHost:Hide()
    trackerFrame.statsList = YayaCore.UI.CreateScrollList(trackerFrame.statsHost, {
        rowHeight = YayaCore.UI.SIZE.rowHCompact,
        initializer = trackerUI.InitStatsRow,
    })
    if trackerFrame.statsList then
        trackerFrame.statsList.container:SetAllPoints(trackerFrame.statsHost)
    end

    YayaFrameAPI:AttachSection(addonName, trackerFrame, 10)
    YayaFrameAPI:SetSectionTitle(addonName, "Session")
    YayaFrameAPI:SetSectionCollapseHandler(addonName, function(collapsed)
        trackerCollapsed = collapsed
        UpdateFrame()
    end)
    trackerCollapsed = YayaFrameAPI:IsSectionCollapsed(addonName) == true

    -- Le bouton de reinitialisation remonte dans le bandeau de la section : il
    -- occupait un coin du contenu, a cote d'un texte large de 102 px.
    local header = type(YayaFrameAPI.EnsureSectionHeader) == "function"
        and YayaFrameAPI:EnsureSectionHeader(addonName)
    if header and type(header.AddButton) == "function" then
        trackerFrame.statsButton = YayaCore.UI.CreateButton(header, "Stats", {
            width = 38,
            height = YayaCore.UI.SIZE.glyph,
            small = true,
        })
        if trackerFrame.statsButton then
            header.AddButton(trackerFrame.statsButton)
            trackerFrame.statsButton:SetScript("OnClick", trackerUI.ToggleStats)
            trackerFrame.statsButton.SetTooltip(
                "Ouvrir le dashboard XP",
                "Affiche les KPI et graphiques des sessions XP."
            )
        end

        trackerFrame.resetButton = YayaCore.UI.CreateGlyphButton(header, "reset")
        if trackerFrame.resetButton then
            header.AddButton(trackerFrame.resetButton)
            trackerFrame.resetButton:SetScript("OnClick", ResetSession)
            trackerFrame.resetButton.SetTooltip(
                "Reinitialiser la session",
                "Remet a zero l'or, le loot, la duree et l'XP."
            )
        end
    end

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
        MaintainXPTracking()
        UpdateFrame()
        trackerUI.UpdateDashboard()
    end)
end

local function FormatXPChat(value)
    value = math.floor(tonumber(value) or 0)
    return BreakUpLargeNumbers and BreakUpLargeNumbers(value) or tostring(value)
end

local function PrintXPStats()
    local trackingMode = trackerUI.GetXPTrackingMode()
    local modeConfig = XPTracker.GetModeConfig(trackingMode)
    local stats = XPTracker.BuildStats(GetXPSessions(trackingMode), trackingMode)
    local live = BuildActiveXPSnapshot()
    print(("|cff00ff98[YST]|r %s : %d sessions · %s XP · %s actives · %s XP/h · %.2f niveaux/h · %d niveaux"):format(
        modeConfig.label,
        stats.sessions,
        FormatXPChat(stats.xpGained),
        FormatDurationCompact(stats.durationSeconds),
        FormatXPChat(stats.xpPerHour),
        stats.levelsPerHour or 0,
        stats.levelsGained))

    local classes = {}
    for _, aggregate in pairs(stats.byClass or {}) do
        classes[#classes + 1] = aggregate
    end
    table.sort(classes, function(left, right) return left.xpGained > right.xpGained end)
    for index = 1, math.min(5, #classes) do
        local aggregate = classes[index]
        print(("  Classe %s: %s XP · %s XP/h · %s"):format(
            aggregate.className or "Inconnue",
            FormatXPChat(aggregate.xpGained),
            FormatXPChat(aggregate.xpPerHour),
            FormatDurationCompact(aggregate.durationSeconds)))
    end

    local specs = {}
    for _, aggregate in pairs(stats.bySpec) do
        specs[#specs + 1] = aggregate
    end
    table.sort(specs, function(left, right) return left.xpGained > right.xpGained end)
    for index = 1, math.min(5, #specs) do
        local aggregate = specs[index]
        print(("  Spé %s (%s): %s XP · %s XP/h · %s"):format(
            aggregate.specName or "Inconnue",
            aggregate.className or "classe inconnue",
            FormatXPChat(aggregate.xpGained),
            FormatXPChat(aggregate.xpPerHour),
            FormatDurationCompact(aggregate.durationSeconds)))
    end

    local zones = {}
    for zone, aggregate in pairs(stats.byZone or {}) do
        aggregate.label = zone
        zones[#zones + 1] = aggregate
    end
    table.sort(zones, function(left, right) return left.xpGained > right.xpGained end)
    for index = 1, math.min(5, #zones) do
        local aggregate = zones[index]
        print(("  Zone %s: %s XP · %s XP/h · %s"):format(
            aggregate.label,
            FormatXPChat(aggregate.xpGained),
            FormatXPChat(aggregate.xpPerHour),
            FormatDurationCompact(aggregate.durationSeconds)))
    end

    local sources = {}
    for source, aggregate in pairs(stats.bySource or {}) do
        sources[#sources + 1] = { label = XPTracker.GetSourceLabel(source), aggregate = aggregate }
    end
    table.sort(sources, function(left, right) return left.aggregate.xpGained > right.aggregate.xpGained end)
    for index = 1, #sources do
        local entry = sources[index]
        print(("  Source %s: %s XP · %s XP/h · %.2f niveaux/h"):format(
            entry.label,
            FormatXPChat(entry.aggregate.xpGained),
            FormatXPChat(entry.aggregate.xpPerHour),
            entry.aggregate.levelsPerHour or 0))
    end

    local levelBands = {}
    for band, aggregate in pairs(stats.byLevelBand or {}) do
        aggregate.label = band
        levelBands[#levelBands + 1] = aggregate
    end
    table.sort(levelBands, function(left, right) return left.label < right.label end)
    if #levelBands > 0 then
        local labels = {}
        for index = 1, math.min(8, #levelBands) do
            local aggregate = levelBands[index]
            labels[#labels + 1] = ("%s: %s XP/h"):format(aggregate.label, FormatXPChat(aggregate.xpPerHour))
        end
        print("  Tranches: " .. table.concat(labels, " · "))
    end

    if live then
        print(("  En cours (%s): %s XP/h · %s"):format(
            live.specName or "Inconnue",
            FormatXPChat(live.xpPerHour),
            FormatDurationCompact(live.durationSeconds)))
    end
end

local function HandleSlashCommand(message)
    local command = strtrim((message or ""):lower())
    if command == "xp" then
        PrintXPStats()
        return
    elseif command == "stats" then
        trackerUI.ToggleStats()
        return
    elseif command == "reset" then
        ResetFramePosition()
    end
    UpdateFrame()
end

local function OnLogin()
    XPTracker.SetLevelBandSize(GetSettings().xpLevelBandSize)
    playerInfo.name = UnitName and UnitName("player") or nil
    playerInfo.realm = GetRealmName and GetRealmName() or nil
    playerInfo.fullName = GetPlayerFullName()
    RebuildMissionHistoryIndexes()
    RegisterKnownCharacter()
    BuildLootPatterns()
    RecoverActiveXPSession()
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
eventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
eventFrame:RegisterEvent("CHAT_MSG_LOOT")
eventFrame:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
eventFrame:RegisterEvent("MAIL_SEND_SUCCESS")
eventFrame:RegisterEvent("MAIL_FAILED")
eventFrame:RegisterEvent("QUEST_LOG_UPDATE")
eventFrame:RegisterEvent("QUEST_COMPLETE")
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
        FinalizeActiveXPSession("logout")
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
        MaintainXPTracking()
        UpdateFrame()
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        trackerUI.HandleCombatLogXPSource()
    elseif event == "PLAYER_REGEN_DISABLED" then
        trackerUI.MarkCombatXPSource()
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
    elseif event == "QUEST_COMPLETE" then
        trackerUI.MarkQuestXPSource()
    elseif event == "QUEST_TURNED_IN" then
        trackerUI.MarkQuestXPSource()
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
        MaintainXPTracking()
        PersistActiveSession()
        UpdateReplenishTracking()
        UpdateFrame()
    end
end)
