local addonName = ...

local DEFAULTS = {
    enabled = true,
    debug = true,
}

local COVENANT_ZONE_MAP = {
    [1] = { mapID = 1533, fallbackName = "Bastion", covenantName = "Kyrian" },
    [2] = { mapID = 1525, fallbackName = "Revendreth", covenantName = "Venthyr" },
    [3] = { mapID = 1565, fallbackName = "Ardenweald", covenantName = "Night Fae" },
    [4] = { mapID = 1536, fallbackName = "Maldraxxus", covenantName = "Necrolord" },
}

local function GetDB()
    if type(YayaCovenantWormholeDB) ~= "table" then
        YayaCovenantWormholeDB = {}
    end

    for key, value in pairs(DEFAULTS) do
        if YayaCovenantWormholeDB[key] == nil then
            YayaCovenantWormholeDB[key] = value
        end
    end

    return YayaCovenantWormholeDB
end

local function Print(message)
    print("|cff33ff99YCW|r " .. tostring(message))
end

local function PrintDebug(message)
    if GetDB().debug then
        Print("[debug] " .. tostring(message))
    end
end

local function NormalizeText(text)
    text = tostring(text or "")
    text = text:gsub("|T.-|t", "")
    text = text:gsub("|c%x%x%x%x%x%x%x%x", "")
    text = text:gsub("|r", "")
    text = text:gsub("^%s+", ""):gsub("%s+$", "")
    return text:lower()
end

local function GetZoneName(mapID, fallbackName)
    if C_Map and C_Map.GetMapInfo then
        local mapInfo = C_Map.GetMapInfo(mapID)
        if mapInfo and mapInfo.name and mapInfo.name ~= "" then
            return mapInfo.name
        end
    end

    return fallbackName
end

local function BuildKnownZoneLookup()
    local lookup = {}

    for _, zoneInfo in pairs(COVENANT_ZONE_MAP) do
        lookup[NormalizeText(zoneInfo.fallbackName)] = true
        lookup[NormalizeText(GetZoneName(zoneInfo.mapID, zoneInfo.fallbackName))] = true
    end

    return lookup
end

local KNOWN_ZONE_LOOKUP = BuildKnownZoneLookup()

local function GetOptionText(optionInfo)
    if type(optionInfo) ~= "table" then
        return ""
    end

    return optionInfo.name or optionInfo.optionText or optionInfo.text or optionInfo.header or optionInfo.description or optionInfo.buttonText or ""
end

local function TextMatchesTarget(optionText, targetText)
    local optionKey = NormalizeText(optionText)
    local targetKey = NormalizeText(targetText)

    if optionKey == "" or targetKey == "" then
        return false
    end

    return optionKey == targetKey
        or optionKey:find(targetKey, 1, true) ~= nil
        or targetKey:find(optionKey, 1, true) ~= nil
end

local function GetTargetZoneInfo()
    if not (C_Covenants and C_Covenants.GetActiveCovenantID) then
        return nil
    end

    local covenantID = C_Covenants.GetActiveCovenantID()
    local zoneInfo = covenantID and COVENANT_ZONE_MAP[covenantID]
    if not zoneInfo then
        return nil
    end

    return {
        covenantID = covenantID,
        covenantName = zoneInfo.covenantName,
        zoneName = GetZoneName(zoneInfo.mapID, zoneInfo.fallbackName),
    }
end

local function DumpGossipOptions(options)
    for index, optionInfo in ipairs(options) do
        PrintDebug(("gossip option %d: id=%s text=%s"):format(
            index,
            tostring(optionInfo.gossipOptionID),
            GetOptionText(optionInfo)
        ))
    end
end

local function FindTargetGossipOptionID()
    if not (C_GossipInfo and C_GossipInfo.GetOptions and C_GossipInfo.SelectOption) then
        PrintDebug("api gossip indisponible")
        return nil
    end

    local targetInfo = GetTargetZoneInfo()
    if not targetInfo then
        PrintDebug("aucun covenant actif detecte")
        return nil
    end

    local options = C_GossipInfo.GetOptions()
    if type(options) ~= "table" or #options == 0 then
        PrintDebug("gossip sans options")
        return nil
    end

    PrintDebug(("covenant=%s (%s) cible=%s options=%d"):format(
        targetInfo.covenantName,
        tostring(targetInfo.covenantID),
        targetInfo.zoneName,
        #options
    ))
    DumpGossipOptions(options)

    local matchedZoneCount = 0

    for _, optionInfo in ipairs(options) do
        local optionText = GetOptionText(optionInfo)
        local optionKey = NormalizeText(optionText)

        if KNOWN_ZONE_LOOKUP[optionKey] then
            matchedZoneCount = matchedZoneCount + 1
        end

        if TextMatchesTarget(optionText, targetInfo.zoneName) and optionInfo.gossipOptionID then
            PrintDebug(("gossip match: id=%s text=%s zones_detectees=%d"):format(
                tostring(optionInfo.gossipOptionID),
                optionText,
                matchedZoneCount
            ))
            return optionInfo.gossipOptionID
        end
    end

    PrintDebug(("aucun match gossip pour %s (zones_detectees=%d)"):format(targetInfo.zoneName, matchedZoneCount))
    return nil
end

local function DumpPlayerChoiceOptions(choiceInfo)
    if type(choiceInfo) ~= "table" or type(choiceInfo.options) ~= "table" then
        return
    end

    for index, optionInfo in ipairs(choiceInfo.options) do
        PrintDebug(("choice option %d: responseID=%s text=%s"):format(
            index,
            tostring(optionInfo.responseID or optionInfo.id),
            GetOptionText(optionInfo)
        ))
    end
end

local function TryAutoSelectPlayerChoice()
    if not (C_PlayerChoice and C_PlayerChoice.GetCurrentPlayerChoiceInfo and C_PlayerChoice.SendPlayerChoiceResponse) then
        return false
    end

    local targetInfo = GetTargetZoneInfo()
    if not targetInfo then
        return false
    end

    local choiceInfo = C_PlayerChoice.GetCurrentPlayerChoiceInfo()
    if type(choiceInfo) ~= "table" or type(choiceInfo.options) ~= "table" or #choiceInfo.options == 0 then
        PrintDebug("player choice vide")
        return false
    end

    PrintDebug(("player choice detecte: covenant=%s cible=%s options=%d"):format(
        targetInfo.covenantName,
        targetInfo.zoneName,
        #choiceInfo.options
    ))
    DumpPlayerChoiceOptions(choiceInfo)

    for _, optionInfo in ipairs(choiceInfo.options) do
        local responseID = optionInfo.responseID or optionInfo.id
        local optionText = GetOptionText(optionInfo)

        if responseID and TextMatchesTarget(optionText, targetInfo.zoneName) then
            PrintDebug(("player choice match: responseID=%s text=%s"):format(tostring(responseID), optionText))
            C_PlayerChoice.SendPlayerChoiceResponse(responseID)
            return true
        end
    end

    PrintDebug("aucun match player choice")
    return false
end

local function TryAutoSelectGossip()
    local targetOptionID = FindTargetGossipOptionID()
    if not targetOptionID then
        return false
    end

    PrintDebug("select gossip option id=" .. tostring(targetOptionID))
    C_GossipInfo.SelectOption(targetOptionID)
    return true
end

local function TryAutoSelect(reason)
    local db = GetDB()
    if not db.enabled then
        PrintDebug(reason .. ": addon off")
        return
    end

    if IsShiftKeyDown and IsShiftKeyDown() then
        PrintDebug(reason .. ": bypass shift")
        return
    end

    if TryAutoSelectGossip() then
        return
    end

    TryAutoSelectPlayerChoice()
end

local function PrintStatus()
    local db = GetDB()
    Print(("enabled=%s debug=%s shift=bypass"):format(
        db.enabled and "on" or "off",
        db.debug and "on" or "off"
    ))
end

local function HandleSlashCommand(message)
    local command = NormalizeText(message)

    if command == "" or command == "status" then
        PrintStatus()
    elseif command == "debug" then
        GetDB().debug = not GetDB().debug
        Print("debug=" .. (GetDB().debug and "on" or "off"))
    elseif command == "debug on" then
        GetDB().debug = true
        Print("debug=on")
    elseif command == "debug off" then
        GetDB().debug = false
        Print("debug=off")
    elseif command == "on" then
        GetDB().enabled = true
        Print("enabled=on")
    elseif command == "off" then
        GetDB().enabled = false
        Print("enabled=off")
    elseif command == "test" then
        TryAutoSelect("slash test")
    else
        Print("cmds: status, on, off, debug, test")
    end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("GOSSIP_SHOW")
eventFrame:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_SHOW")
eventFrame:RegisterEvent("PLAYER_CHOICE_UPDATE")
eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        local loadedAddonName = ...
        if loadedAddonName ~= addonName then
            return
        end

        GetDB()
        SLASH_YAYACOVENANTWORMHOLE1 = "/ycw"
        SlashCmdList.YAYACOVENANTWORMHOLE = HandleSlashCommand
        PrintDebug("addon charge")
        PrintStatus()
        return
    end

    if event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" then
        local interactionType = ...
        PrintDebug("interaction show type=" .. tostring(interactionType))
        return
    end

    PrintDebug("event=" .. event)
    TryAutoSelect(event)
end)
