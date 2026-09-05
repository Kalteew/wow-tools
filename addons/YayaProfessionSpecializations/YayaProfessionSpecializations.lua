local addonName = ...

local addon = CreateFrame("Frame")
local saveQueued = false
local retryCount = 0
local MAX_RETRIES = 6

local function SafeCall(func, ...)
    if type(func) ~= "function" then
        return nil
    end
    local ok, result1, result2, result3, result4, result5 = pcall(func, ...)
    if not ok then
        return nil
    end
    return result1, result2, result3, result4, result5
end

local function Reply(message)
    if DEFAULT_CHAT_FRAME then
        -- Menthe de la suite, valeur de YayaCore.UI.HEX.accent. Litteral
        -- assume : cet addon ne dessine aucune frame et n'a aucune raison
        -- de dependre de YayaCore pour une couleur de chat.
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff98" .. addonName .. "|r: " .. tostring(message))
    end
end

local function GetDB()
    YayaProfessionSpecializationsDB = YayaProfessionSpecializationsDB or {}
    local db = YayaProfessionSpecializationsDB
    db.characters = db.characters or {}
    db.meta = db.meta or {}
    return db
end

local function GetCharacterKey()
    local name = UnitName and UnitName("player")
    if not name or name == "" then
        return nil
    end
    local realm = GetRealmName and GetRealmName() or ""
    if realm ~= "" then
        return realm .. "." .. name
    end
    return name
end

local function CollectPathIDs(pathIDs, pathID)
    if not pathID or pathIDs[pathID] then
        return
    end
    pathIDs[pathID] = true
    local children = SafeCall(C_ProfSpecs and C_ProfSpecs.GetChildrenForPath, pathID) or {}
    for _, childPathID in ipairs(children) do
        CollectPathIDs(pathIDs, childPathID)
    end
end

local function GetDefinitionName(definitionInfo)
    if not definitionInfo then
        return nil
    end
    if definitionInfo.overrideName and definitionInfo.overrideName ~= "" then
        return definitionInfo.overrideName
    end
    if definitionInfo.spellID and C_Spell and C_Spell.GetSpellName then
        return SafeCall(C_Spell.GetSpellName, definitionInfo.spellID)
    end
    return nil
end

local function BuildNodeSnapshot(configID, pathID)
    local nodeInfo = SafeCall(C_Traits and C_Traits.GetNodeInfo, configID, pathID)
    local activeEntry = nodeInfo and nodeInfo.activeEntry or nil
    local chosenEntryID = activeEntry and activeEntry.entryID

    if not chosenEntryID and nodeInfo and nodeInfo.entryIDsWithCommittedRanks and nodeInfo.entryIDsWithCommittedRanks[1] then
        chosenEntryID = nodeInfo.entryIDsWithCommittedRanks[1]
    end
    if not chosenEntryID and nodeInfo and nodeInfo.entryIDs and nodeInfo.entryIDs[1] then
        chosenEntryID = nodeInfo.entryIDs[1]
    end

    local entryInfo = chosenEntryID and SafeCall(C_Traits and C_Traits.GetEntryInfo, configID, chosenEntryID) or nil
    local definitionInfo = entryInfo and entryInfo.definitionID and SafeCall(C_Traits and C_Traits.GetDefinitionInfo, entryInfo.definitionID) or nil
    local perks = SafeCall(C_ProfSpecs and C_ProfSpecs.GetPerksForPath, pathID) or {}
    local perkSnapshots = {}
    for _, perk in ipairs(perks) do
        perkSnapshots[#perkSnapshots + 1] = {
            perkID = perk.perkID,
            name = perk.name,
            description = SafeCall(C_ProfSpecs and C_ProfSpecs.GetDescriptionForPerk, perk.perkID),
        }
    end

    return {
        pathID = pathID,
        name = GetDefinitionName(definitionInfo) or (entryInfo and entryInfo.name) or ("Path " .. tostring(pathID)),
        state = SafeCall(C_ProfSpecs and C_ProfSpecs.GetStateForPath, pathID, configID),
        currentRank = nodeInfo and nodeInfo.currentRank or nil,
        maxRanks = nodeInfo and nodeInfo.maxRanks or nil,
        activeRank = activeEntry and activeEntry.rank or nil,
        activeEntryID = activeEntry and activeEntry.entryID or nil,
        entryID = chosenEntryID,
        definitionID = entryInfo and entryInfo.definitionID or nil,
        spellID = definitionInfo and definitionInfo.spellID or nil,
        icon = (definitionInfo and definitionInfo.overrideIcon) or (entryInfo and entryInfo.icon) or nil,
        children = SafeCall(C_ProfSpecs and C_ProfSpecs.GetChildrenForPath, pathID) or {},
        perks = perkSnapshots,
    }
end

local function GetProfessionInfo(skillLineID)
    local info = SafeCall(C_TradeSkillUI and C_TradeSkillUI.GetProfessionInfoBySkillLineID, skillLineID)
    if type(info) == "table" then
        return {
            professionName = info.professionName,
            parentProfessionName = info.parentProfessionName,
            skillLineID = info.professionID or skillLineID,
            parentSkillLineID = info.parentProfessionID,
            skillLevel = info.skillLevel,
            maxSkillLevel = info.maxSkillLevel,
        }
    end

    local name, skillLevel, maxSkillLevel = SafeCall(C_TradeSkillUI and C_TradeSkillUI.GetTradeSkillLineInfoByID, skillLineID)
    return {
        professionName = name,
        skillLineID = skillLineID,
        skillLevel = skillLevel,
        maxSkillLevel = maxSkillLevel,
    }
end

local function BuildProfessionSnapshot(skillLineID)
    local configID = SafeCall(C_ProfSpecs and C_ProfSpecs.GetConfigIDForSkillLine, skillLineID)
    if not configID or configID == 0 then
        return nil
    end

    local professionInfo = GetProfessionInfo(skillLineID)
    local tabIDs = SafeCall(C_ProfSpecs and C_ProfSpecs.GetSpecTabIDsForSkillLine, skillLineID) or {}
    local tabs = {}
    for _, tabID in ipairs(tabIDs) do
        local rootPathID = SafeCall(C_ProfSpecs and C_ProfSpecs.GetRootPathForTab, tabID)
        local pathIDs = {}
        if rootPathID then
            CollectPathIDs(pathIDs, rootPathID)
        end

        local nodes = {}
        for pathID in pairs(pathIDs) do
            nodes[#nodes + 1] = BuildNodeSnapshot(configID, pathID)
        end
        table.sort(nodes, function(a, b)
            return a.pathID < b.pathID
        end)

        local rootNode = rootPathID and BuildNodeSnapshot(configID, rootPathID) or nil
        tabs[#tabs + 1] = {
            tabID = tabID,
            rootPathID = rootPathID,
            name = rootNode and rootNode.name or ("Tab " .. tostring(tabID)),
            nodes = nodes,
        }
    end

    return {
        skillLineID = skillLineID,
        configID = configID,
        professionName = professionInfo.professionName or ("SkillLine " .. tostring(skillLineID)),
        parentProfessionName = professionInfo.parentProfessionName,
        skillLevel = professionInfo.skillLevel,
        maxSkillLevel = professionInfo.maxSkillLevel,
        tabs = tabs,
    }
end

local function BuildSnapshot()
    if type(C_TradeSkillUI) ~= "table" or type(C_TradeSkillUI.GetAllProfessionTradeSkillLines) ~= "function" then
        return nil, "C_TradeSkillUI indisponible"
    end
    if type(C_ProfSpecs) ~= "table" or type(C_ProfSpecs.GetConfigIDForSkillLine) ~= "function" then
        return nil, "C_ProfSpecs indisponible"
    end

    local skillLineIDs = SafeCall(C_TradeSkillUI.GetAllProfessionTradeSkillLines) or {}
    local professions = {}
    for _, skillLineID in ipairs(skillLineIDs) do
        local snapshot = BuildProfessionSnapshot(skillLineID)
        if snapshot then
            professions[#professions + 1] = snapshot
        end
    end

    table.sort(professions, function(a, b)
        return (a.professionName or "") < (b.professionName or "")
    end)

    return {
        capturedAt = time and time() or 0,
        capturedAtText = date and date("%Y-%m-%d %H:%M:%S") or nil,
        playerName = UnitName and UnitName("player") or nil,
        realmName = GetRealmName and GetRealmName() or nil,
        professions = professions,
    }
end

local function SaveSnapshot(source)
    local snapshot, err = BuildSnapshot()
    if not snapshot then
        return false, err
    end

    local characterKey = GetCharacterKey()
    if not characterKey then
        return false, "personnage introuvable"
    end

    local db = GetDB()
    db.meta.lastSource = source
    db.meta.lastUpdated = snapshot.capturedAt
    db.meta.lastUpdatedText = snapshot.capturedAtText
    db.characters[characterKey] = snapshot
    return true, snapshot
end

local function TrySave(source)
    local ok, result = SaveSnapshot(source)
    if ok then
        retryCount = 0
        return
    end

    retryCount = retryCount + 1
    if retryCount <= MAX_RETRIES then
        saveQueued = true
        C_Timer.After(2, function()
            saveQueued = false
            TrySave(source .. ":retry" .. retryCount)
        end)
    else
        retryCount = 0
    end
end

local function QueueSave(source)
    if saveQueued then
        return
    end
    saveQueued = true
    C_Timer.After(1, function()
        saveQueued = false
        TrySave(source)
    end)
end

SLASH_YAYAPROFSPECS1 = "/yayaspec"
SLASH_YAYAPROFSPECS2 = "/yspec"
SlashCmdList.YAYAPROFSPECS = function(msg)
    local command = msg and msg:lower():match("^%s*(.-)%s*$") or ""
    if command == "dump" or command == "scan" or command == "" then
        QueueSave("slash")
        return
    end
    if command == "show" then
        local characterKey = GetCharacterKey()
        local db = GetDB()
        local snapshot = characterKey and db.characters[characterKey]
        if snapshot then
            Reply("dernier snapshot: " .. tostring(snapshot.capturedAtText) .. " | " .. tostring(#(snapshot.professions or {})) .. " metiers")
        else
            Reply("aucun snapshot.")
        end
        return
    end
    Reply("usage: /yayaspec dump | show")
end

addon:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        QueueSave("login")
    elseif event == "SKILL_LINES_CHANGED" or event == "TRAIT_CONFIG_UPDATED" or event == "TRADE_SKILL_SHOW" then
        QueueSave(event)
    end
end)

addon:RegisterEvent("PLAYER_LOGIN")
addon:RegisterEvent("SKILL_LINES_CHANGED")
addon:RegisterEvent("TRAIT_CONFIG_UPDATED")
addon:RegisterEvent("TRADE_SKILL_SHOW")
