local addonName = ...

local FOLLOWER_TYPE_ID = Enum and Enum.GarrisonFollowerType and Enum.GarrisonFollowerType.FollowerType_9_0_GarrisonFollower or 123
local TRACK_MODE_ALL = "all"
local TRACK_MODE_TRACKED = "tracked"

local COMPANION_XP_ITEM_IDS = {
    [186472] = true, -- Wisps of Memory
    [188655] = true, -- Crystalline Memory Repository
    [188656] = true, -- Fractal Thoughtbinder
    [188657] = true, -- Mind-Expanding Prism
}

local pendingItemID
local isHandlingSpellTarget = false
local GetDB

local function Print(message)
    print("|cff33ff99YCT|r " .. message)
end

local function PrintVerbose(message)
    local db = GetDB()
    if db.verbose then
        Print("[v] " .. message)
    end
end

local function CopyTable(source)
    local copy = {}

    for key, value in pairs(source) do
        if type(value) == "table" then
            local nested = {}
            for nestedKey, nestedValue in pairs(value) do
                nested[nestedKey] = nestedValue
            end
            copy[key] = nested
        else
            copy[key] = value
        end
    end

    return copy
end

GetDB = function()
    if not YayaCompanionTargeterDB then
        YayaCompanionTargeterDB = CopyTable({
            enabled = true,
            mode = TRACK_MODE_ALL,
            verbose = false,
            trackedFollowerIDs = {},
        })
    end

    if YayaCompanionTargeterDB.enabled == nil then
        YayaCompanionTargeterDB.enabled = true
    end

    if YayaCompanionTargeterDB.verbose == nil then
        YayaCompanionTargeterDB.verbose = false
    end

    if YayaCompanionTargeterDB.mode ~= TRACK_MODE_TRACKED then
        YayaCompanionTargeterDB.mode = TRACK_MODE_ALL
    end

    YayaCompanionTargeterDB.trackedFollowerIDs = YayaCompanionTargeterDB.trackedFollowerIDs or {}

    return YayaCompanionTargeterDB
end

local function FollowerKey(followerID)
    return tostring(followerID or "")
end

local function GetFollowerName(followerID)
    if not C_Garrison or not C_Garrison.GetFollowerInfo or not followerID then
        return tostring(followerID)
    end

    local info = C_Garrison.GetFollowerInfo(followerID)
    return info and info.name or tostring(followerID)
end

local function GetSelectedFollowerID()
    if CovenantMissionFrame and CovenantMissionFrame.FollowerTab then
        return CovenantMissionFrame.FollowerTab.followerID
    end
end

local function IsTrackedFollower(followerID)
    local db = GetDB()

    if db.mode ~= TRACK_MODE_TRACKED then
        return true
    end

    return db.trackedFollowerIDs[FollowerKey(followerID)] == true
end

local function GetSpellTargetKind()
    if not SpellCanTargetGarrisonFollower or not SpellCanTargetGarrisonFollower(0) then
        return nil
    end

    if C_Garrison and C_Garrison.TargetSpellHasFollowerTemporaryAbility and C_Garrison.TargetSpellHasFollowerTemporaryAbility() then
        return "temporary"
    end

    if C_Garrison and C_Garrison.TargetSpellHasFollowerItemLevelUpgrade and C_Garrison.TargetSpellHasFollowerItemLevelUpgrade() then
        return "itemlevel"
    end

    if C_Garrison and C_Garrison.TargetSpellHasFollowerReroll then
        local hasReroll = C_Garrison.TargetSpellHasFollowerReroll()
        if hasReroll then
            return "reroll"
        end
    end

    return "generic"
end

local function GetFollowerRejectReason(followerInfo, requireSpellCheck)
    if not followerInfo or not followerInfo.followerID then
        return "invalid"
    end

    if followerInfo.followerTypeID ~= FOLLOWER_TYPE_ID then
        return "wrong_type"
    end

    if followerInfo.isAutoTroop or followerInfo.isTroop then
        return "troop"
    end

    if followerInfo.isCollected == false then
        return "not_collected"
    end

    if followerInfo.isMaxLevel then
        return "max_level"
    end

    if not IsTrackedFollower(followerInfo.followerID) then
        return "not_tracked"
    end

    if requireSpellCheck and SpellCanTargetGarrisonFollower then
        local canTarget = SpellCanTargetGarrisonFollower(followerInfo.followerID)
        if not canTarget then
            return tostring(followerInfo.status or "spell_rejected")
        end
    end

    return nil
end

local function CanTargetFollower(followerInfo, requireSpellCheck)
    return GetFollowerRejectReason(followerInfo, requireSpellCheck) == nil
end

local function IsBetterFollower(candidate, currentBest)
    local candidateLevel = candidate.level or math.huge
    local currentLevel = currentBest.level or math.huge

    if candidateLevel ~= currentLevel then
        return candidateLevel < currentLevel
    end

    local candidateXP = candidate.xp or 0
    local currentXP = currentBest.xp or 0

    if candidateXP ~= currentXP then
        return candidateXP < currentXP
    end

    local candidateItemLevel = candidate.iLevel or 0
    local currentItemLevel = currentBest.iLevel or 0

    if candidateItemLevel ~= currentItemLevel then
        return candidateItemLevel < currentItemLevel
    end

    return (candidate.name or "") < (currentBest.name or "")
end

local function FindLowestLevelFollower(requireSpellCheck)
    if not C_Garrison or not C_Garrison.GetFollowers then
        return nil
    end

    local followers = C_Garrison.GetFollowers(FOLLOWER_TYPE_ID)
    local bestFollower

    if type(followers) ~= "table" then
        return nil
    end

    for _, followerInfo in ipairs(followers) do
        local rejectReason = GetFollowerRejectReason(followerInfo, requireSpellCheck)
        if not rejectReason and (not bestFollower or IsBetterFollower(followerInfo, bestFollower)) then
            bestFollower = followerInfo
        elseif rejectReason then
            PrintVerbose(("skip %s: %s"):format(followerInfo.name or tostring(followerInfo.followerID), rejectReason))
        end
    end

    return bestFollower
end

local function MarkPendingItem(itemID)
    if COMPANION_XP_ITEM_IDS[itemID] then
        pendingItemID = itemID
        PrintVerbose("item detecte: " .. tostring(itemID))
    end
end

local function GetPendingItemIDFromCursor()
    if not GetCursorInfo then
        return nil
    end

    local cursorType, cursorItemID = GetCursorInfo()
    if cursorType == "item" and COMPANION_XP_ITEM_IDS[cursorItemID] then
        return cursorItemID
    end

    return nil
end

local function GetActivePendingItemID()
    return GetPendingItemIDFromCursor() or pendingItemID
end

local function TryAutoTargetCompanion()
    if isHandlingSpellTarget then
        return
    end

    local db = GetDB()
    if not db.enabled or IsAltKeyDown() then
        return
    end

    if not SpellCanTargetGarrisonFollower or not SpellStopTargeting then
        return
    end

    local activePendingItemID = GetActivePendingItemID()
    local spellTargetKind = GetSpellTargetKind()

    if not activePendingItemID and spellTargetKind ~= "generic" then
        if not spellTargetKind then
            pendingItemID = nil
        end
        return
    end

    if not spellTargetKind then
        PrintVerbose("pas de ciblage follower actif")
        pendingItemID = nil
        return
    end

    if spellTargetKind ~= "generic" then
        PrintVerbose("ciblage ignore: " .. spellTargetKind)
        pendingItemID = nil
        return
    end

    PrintVerbose(("tentative auto-target item=%s"):format(tostring(activePendingItemID or "generic")))

    local followerInfo = FindLowestLevelFollower(true)

    isHandlingSpellTarget = true
    if followerInfo and C_Garrison and C_Garrison.CastSpellOnFollower then
        PrintVerbose(("target choisi: %s (lvl %s)"):format(followerInfo.name or tostring(followerInfo.followerID), tostring(followerInfo.level or "?")))
        C_Garrison.CastSpellOnFollower(followerInfo.followerID)
    else
        PrintVerbose("aucun companion eligible, ciblage annule")
        SpellStopTargeting()
    end
    isHandlingSpellTarget = false

    pendingItemID = nil
end

local function GetContainerItemIDCompat(bagID, slotIndex)
    if C_Container and C_Container.GetContainerItemInfo then
        local info = C_Container.GetContainerItemInfo(bagID, slotIndex)
        if info and info.itemID then
            return info.itemID
        end
    end

    if GetContainerItemLink and GetItemInfoInstant then
        local itemLink = GetContainerItemLink(bagID, slotIndex)
        if itemLink then
            return GetItemInfoInstant(itemLink)
        end
    end
end

local function OnContainerItemUsed(bagID, slotIndex)
    MarkPendingItem(GetContainerItemIDCompat(bagID, slotIndex))
end

local function OnActionUsed(actionSlot)
    if not GetActionInfo then
        return
    end

    local actionType, actionID = GetActionInfo(actionSlot)
    if actionType == "item" then
        MarkPendingItem(actionID)
    end
end

local function HookItemUse()
    if not hooksecurefunc then
        return
    end

    if C_Container and C_Container.UseContainerItem then
        hooksecurefunc(C_Container, "UseContainerItem", OnContainerItemUsed)
    elseif UseContainerItem then
        hooksecurefunc("UseContainerItem", OnContainerItemUsed)
    end

    if UseAction then
        hooksecurefunc("UseAction", OnActionUsed)
    end
end

local function PrintStatus()
    local db = GetDB()
    local trackedCount = 0

    for _ in pairs(db.trackedFollowerIDs) do
        trackedCount = trackedCount + 1
    end

    Print(("auto=%s mode=%s tracked=%d verbose=%s alt=bypass"):format(db.enabled and "on" or "off", db.mode, trackedCount, db.verbose and "on" or "off"))
end

local function SetMode(mode)
    local db = GetDB()
    db.mode = mode
    Print("mode=" .. mode)
end

local function ToggleTrackedFollower()
    local followerID = GetSelectedFollowerID()
    if not followerID then
        Print("selectionne un companion dans l'onglet Companions")
        return
    end

    local db = GetDB()
    local key = FollowerKey(followerID)

    if db.trackedFollowerIDs[key] then
        db.trackedFollowerIDs[key] = nil
        Print("retire: " .. GetFollowerName(followerID))
    else
        db.trackedFollowerIDs[key] = true
        Print("ajoute: " .. GetFollowerName(followerID))
    end
end

local function ClearTrackedFollowers()
    GetDB().trackedFollowerIDs = {}
    Print("tracked vide")
end

local function ListTrackedFollowers()
    local names = {}

    for followerID in pairs(GetDB().trackedFollowerIDs) do
        names[#names + 1] = GetFollowerName(followerID)
    end

    table.sort(names)

    if #names == 0 then
        Print("tracked vide")
        return
    end

    Print(table.concat(names, ", "))
end

local function SetVerbose(enabled)
    GetDB().verbose = enabled
    Print("verbose=" .. (enabled and "on" or "off"))
end

local function HandleSlashCommand(message)
    local command = (message or ""):lower():match("^%s*(.-)%s*$")

    if command == "" or command == "status" then
        PrintStatus()
    elseif command == "on" then
        GetDB().enabled = true
        Print("auto=on")
    elseif command == "off" then
        GetDB().enabled = false
        Print("auto=off")
    elseif command == "all" then
        SetMode(TRACK_MODE_ALL)
    elseif command == "tracked" or command == "only" then
        SetMode(TRACK_MODE_TRACKED)
    elseif command == "track" then
        ToggleTrackedFollower()
    elseif command == "clear" then
        ClearTrackedFollowers()
    elseif command == "list" then
        ListTrackedFollowers()
    elseif command == "verbose" or command == "debug" then
        SetVerbose(not GetDB().verbose)
    elseif command == "verbose on" or command == "debug on" then
        SetVerbose(true)
    elseif command == "verbose off" or command == "debug off" then
        SetVerbose(false)
    else
        Print("cmds: status, on, off, all, tracked, track, list, clear, verbose")
    end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("CURRENT_SPELL_CAST_CHANGED")
eventFrame:RegisterEvent("GARRISON_FOLLOWER_XP_CHANGED")
eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        local loadedAddonName = ...
        if loadedAddonName ~= addonName then
            return
        end

        GetDB()
        HookItemUse()
        PrintVerbose("addon charge")

        SLASH_YAYACOMPANIONTARGETER1 = "/yct"
        SlashCmdList.YAYACOMPANIONTARGETER = HandleSlashCommand
        return
    end

    if event == "CURRENT_SPELL_CAST_CHANGED" then
        TryAutoTargetCompanion()
    elseif event == "GARRISON_FOLLOWER_XP_CHANGED" then
        local followerTypeID, followerID = ...
        if followerTypeID == FOLLOWER_TYPE_ID then
            PrintVerbose("xp appliquee a " .. GetFollowerName(followerID))
        end
    end
end)
