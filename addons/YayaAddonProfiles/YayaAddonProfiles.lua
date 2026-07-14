local ADDON_NAME = ...

local AddOns = C_AddOns or {}
local GetNumAddOnsCompat = AddOns.GetNumAddOns or GetNumAddOns
local GetAddOnInfoCompat = AddOns.GetAddOnInfo or GetAddOnInfo
local GetAddOnEnableStateCompat = AddOns.GetAddOnEnableState or function(nameOrIndex, character)
    return GetAddOnEnableState(character, nameOrIndex)
end
local EnableAddOnCompat = AddOns.EnableAddOn or EnableAddOn
local DisableAddOnCompat = AddOns.DisableAddOn or DisableAddOn
local SaveAddOnsCompat = AddOns.SaveAddOns or SaveAddOns

local PROFILE_ORDER = { "play", "gold" }
local PROFILE_LABELS = {
    play = "Jouer",
    gold = "Gold",
}

local DB
local currentCharacter
local playerGuid
local mainFrame
local rows = {}
local statusText
local profileText
local listText
local scrollChild

local function Trim(value)
    return (value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function Print(message)
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ccffYayaAddonProfiles|r: " .. message)
end

local function NormalizeProfileKey(value)
    value = Trim(value):lower()
    if value == "play" or value == "jeu" or value == "jouer" then
        return "play"
    end
    if value == "gold" or value == "golds" or value == "goldmaking" then
        return "gold"
    end
    return nil
end

local function GetCharacterId()
    local name, realm = UnitFullName("player")
    if not realm or realm == "" then
        realm = GetRealmName()
    end
    return (name or UnitName("player")) .. "-" .. (realm or "Unknown")
end

local function EnsureDb()
    YayaAddonProfilesDB = YayaAddonProfilesDB or {}
    DB = YayaAddonProfilesDB
    local previousVersion = DB.version or 0
    DB.version = 2
    DB.profiles = DB.profiles or {}
    DB.assignments = DB.assignments or {}
    DB.characters = DB.characters or {}
    if previousVersion < 2 then
        DB.autoApply = false
    elseif DB.autoApply == nil then
        DB.autoApply = false
    end

    for _, profileKey in ipairs(PROFILE_ORDER) do
        DB.profiles[profileKey] = DB.profiles[profileKey] or {}
        DB.profiles[profileKey].name = PROFILE_LABELS[profileKey]
        DB.profiles[profileKey].addons = DB.profiles[profileKey].addons or {}
    end
end

local function RememberCurrentCharacter()
    currentCharacter = GetCharacterId()
    playerGuid = UnitGUID("player")

    local _, classFile = UnitClass("player")
    local color = RAID_CLASS_COLORS[classFile]
    DB.characters[currentCharacter] = DB.characters[currentCharacter] or {}
    DB.characters[currentCharacter].id = currentCharacter
    DB.characters[currentCharacter].class = classFile
    DB.characters[currentCharacter].color = color and color.colorStr or "ffffffff"
    DB.characters[currentCharacter].lastSeen = date("%Y-%m-%d %H:%M")
end

local function IsAddonEnabledForCurrent(addonIndexOrName)
    local state = GetAddOnEnableStateCompat(addonIndexOrName, playerGuid)
    return state == 2
end

local function CountTableValues(t)
    local count = 0
    for _, enabled in pairs(t or {}) do
        if enabled then
            count = count + 1
        end
    end
    return count
end

local function CountProfileAddons(profileKey)
    local profile = DB.profiles[profileKey]
    if not profile then
        return 0
    end
    return CountTableValues(profile.addons)
end

local function IsProfileReady(profileKey)
    local profile = DB.profiles[profileKey]
    return profile and profile.capturedAt and CountProfileAddons(profileKey) > 0
end

local function BuildDesiredAddons(profileKey)
    local desired = {}
    local profile = DB.profiles[profileKey]
    if profile then
        for addonName, enabled in pairs(profile.addons or {}) do
            if enabled then
                desired[addonName] = true
            end
        end
    end
    desired[ADDON_NAME] = true
    return desired
end

local function ProfileMatches(profileKey)
    if not IsProfileReady(profileKey) then
        return false
    end

    local desired = BuildDesiredAddons(profileKey)
    local count = GetNumAddOnsCompat()
    for addonIndex = 1, count do
        local addonName = GetAddOnInfoCompat(addonIndex)
        if addonName then
            local shouldEnable = desired[addonName] == true
            if IsAddonEnabledForCurrent(addonIndex) ~= shouldEnable then
                return false
            end
        end
    end
    return true
end

local function ShowReloadPopup(message)
    StaticPopupDialogs.YAYA_ADDON_PROFILES_RELOAD = {
        text = message .. "\n\nReload UI maintenant ?",
        button1 = "Reload UI",
        button2 = CANCEL,
        OnAccept = function()
            ReloadUI()
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }
    StaticPopup_Show("YAYA_ADDON_PROFILES_RELOAD")
end

local function SaveAddonSelection()
    if SaveAddOnsCompat then
        SaveAddOnsCompat()
    end
end

local function ApplyProfile(profileKey, silent)
    if not IsProfileReady(profileKey) then
        Print("Profil " .. PROFILE_LABELS[profileKey] .. " vide. Configure tes addons puis /yap capture " .. profileKey .. ".")
        return false
    end

    local changed = false
    local desired = BuildDesiredAddons(profileKey)
    local count = GetNumAddOnsCompat()

    for addonIndex = 1, count do
        local addonName = GetAddOnInfoCompat(addonIndex)
        if addonName then
            local shouldEnable = desired[addonName] == true
            if IsAddonEnabledForCurrent(addonIndex) ~= shouldEnable then
                changed = true
            end

            if shouldEnable then
                EnableAddOnCompat(addonIndex, playerGuid)
            else
                DisableAddOnCompat(addonIndex, playerGuid)
            end
        end
    end

    SaveAddonSelection()

    if changed then
        local message = "Profil " .. PROFILE_LABELS[profileKey] .. " applique pour " .. currentCharacter .. "."
        if not silent then
            Print(message)
        end
        ShowReloadPopup(message)
    elseif not silent then
        Print("Profil " .. PROFILE_LABELS[profileKey] .. " deja actif.")
    end

    return changed
end

local function AssignProfile(characterId, profileKey, applyNow)
    DB.assignments[characterId] = profileKey
    if applyNow and characterId == currentCharacter then
        ApplyProfile(profileKey)
    else
        Print(characterId .. " -> " .. PROFILE_LABELS[profileKey])
    end
end

local function CaptureProfile(profileKey)
    local addons = {}
    local count = GetNumAddOnsCompat()

    for addonIndex = 1, count do
        local addonName = GetAddOnInfoCompat(addonIndex)
        if addonName and IsAddonEnabledForCurrent(addonIndex) then
            addons[addonName] = true
        end
    end
    addons[ADDON_NAME] = true

    DB.profiles[profileKey].addons = addons
    DB.profiles[profileKey].capturedAt = date("%Y-%m-%d %H:%M")
    SaveAddonSelection()
    Print("Profil " .. PROFILE_LABELS[profileKey] .. " capture (" .. CountTableValues(addons) .. " addons).")
end

local function SortedCharacters()
    local list = {}
    for id, character in pairs(DB.characters) do
        table.insert(list, {
            id = id,
            color = character.color or "ffffffff",
            assignment = DB.assignments[id],
        })
    end
    table.sort(list, function(a, b)
        return a.id:lower() < b.id:lower()
    end)
    return list
end

local function CreateButton(parent, text, width, height)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width, height)
    button:SetText(text)
    return button
end

local function RefreshUi()
    if not mainFrame then
        return
    end

    local assigned = DB.assignments[currentCharacter]
    local assignedLabel = assigned and PROFILE_LABELS[assigned] or "aucun"
    local ready = assigned and IsProfileReady(assigned)
    local active = ready and ProfileMatches(assigned)
    local state = ready and (active and "OK" or "reload requis") or "non capture"

    statusText:SetText("Perso: " .. currentCharacter)
    profileText:SetText("Profil assigne: " .. assignedLabel .. " (" .. state .. ")")
    listText:SetText(
        "Jouer: " .. CountProfileAddons("play") ..
        " addons | Gold: " .. CountProfileAddons("gold") ..
        " addons | Auto: " .. (DB.autoApply and "on" or "off")
    )

    local characters = SortedCharacters()
    for index, character in ipairs(characters) do
        local row = rows[index]
        if not row then
            row = CreateFrame("Frame", nil, scrollChild)
            row:SetSize(430, 24)
            row.name = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
            row.name:SetPoint("LEFT", 0, 0)
            row.name:SetWidth(245)
            row.name:SetJustifyH("LEFT")
            row.profile = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
            row.profile:SetPoint("LEFT", row.name, "RIGHT", 6, 0)
            row.profile:SetWidth(45)
            row.profile:SetJustifyH("LEFT")
            row.play = CreateButton(row, "Jouer", 58, 22)
            row.play:SetPoint("RIGHT", row, "RIGHT", -64, 0)
            row.gold = CreateButton(row, "Gold", 58, 22)
            row.gold:SetPoint("RIGHT", row, "RIGHT", 0, 0)
            rows[index] = row
        end

        row:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -((index - 1) * 26))
        row.name:SetText("|c" .. character.color .. character.id .. "|r")
        row.profile:SetText(character.assignment and PROFILE_LABELS[character.assignment] or "-")
        row.play:SetEnabled(character.assignment ~= "play")
        row.gold:SetEnabled(character.assignment ~= "gold")
        row.play:SetScript("OnClick", function()
            AssignProfile(character.id, "play", character.id == currentCharacter)
            RefreshUi()
        end)
        row.gold:SetScript("OnClick", function()
            AssignProfile(character.id, "gold", character.id == currentCharacter)
            RefreshUi()
        end)
        row:Show()
    end

    for index = #characters + 1, #rows do
        rows[index]:Hide()
    end

    scrollChild:SetHeight(math.max(1, #characters * 26))
end

local function ToggleUi()
    if mainFrame:IsShown() then
        mainFrame:Hide()
    else
        RefreshUi()
        mainFrame:Show()
    end
end

local function CreateUi()
    mainFrame = CreateFrame("Frame", ADDON_NAME .. "Frame", UIParent, "BasicFrameTemplateWithInset")
    mainFrame:SetSize(520, 430)
    mainFrame:SetPoint("CENTER")
    mainFrame:SetMovable(true)
    mainFrame:EnableMouse(true)
    mainFrame:RegisterForDrag("LeftButton")
    mainFrame:SetScript("OnDragStart", mainFrame.StartMoving)
    mainFrame:SetScript("OnDragStop", mainFrame.StopMovingOrSizing)
    mainFrame:Hide()
    table.insert(UISpecialFrames, mainFrame:GetName())

    local title = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("TOP", 0, -6)
    title:SetText("Yaya Addon Profiles")

    statusText = mainFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    statusText:SetPoint("TOPLEFT", 18, -36)
    statusText:SetWidth(480)
    statusText:SetJustifyH("LEFT")

    profileText = mainFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    profileText:SetPoint("TOPLEFT", statusText, "BOTTOMLEFT", 0, -8)
    profileText:SetWidth(480)
    profileText:SetJustifyH("LEFT")

    listText = mainFrame:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    listText:SetPoint("TOPLEFT", profileText, "BOTTOMLEFT", 0, -8)
    listText:SetWidth(480)
    listText:SetJustifyH("LEFT")

    local playButton = CreateButton(mainFrame, "Ce perso: Jouer", 116, 24)
    playButton:SetPoint("TOPLEFT", listText, "BOTTOMLEFT", 0, -14)
    playButton:SetScript("OnClick", function()
        AssignProfile(currentCharacter, "play", true)
        RefreshUi()
    end)

    local goldButton = CreateButton(mainFrame, "Ce perso: Gold", 116, 24)
    goldButton:SetPoint("LEFT", playButton, "RIGHT", 8, 0)
    goldButton:SetScript("OnClick", function()
        AssignProfile(currentCharacter, "gold", true)
        RefreshUi()
    end)

    local applyButton = CreateButton(mainFrame, "Appliquer", 92, 24)
    applyButton:SetPoint("LEFT", goldButton, "RIGHT", 8, 0)
    applyButton:SetScript("OnClick", function()
        local assigned = DB.assignments[currentCharacter]
        if assigned then
            ApplyProfile(assigned)
        else
            Print("Aucun profil assigne a ce personnage.")
        end
        RefreshUi()
    end)

    local reloadButton = CreateButton(mainFrame, "Reload UI", 82, 24)
    reloadButton:SetPoint("LEFT", applyButton, "RIGHT", 8, 0)
    reloadButton:SetScript("OnClick", ReloadUI)

    local capturePlay = CreateButton(mainFrame, "Capturer Jouer", 116, 24)
    capturePlay:SetPoint("TOPLEFT", playButton, "BOTTOMLEFT", 0, -8)
    capturePlay:SetScript("OnClick", function()
        CaptureProfile("play")
        RefreshUi()
    end)

    local captureGold = CreateButton(mainFrame, "Capturer Gold", 116, 24)
    captureGold:SetPoint("LEFT", capturePlay, "RIGHT", 8, 0)
    captureGold:SetScript("OnClick", function()
        CaptureProfile("gold")
        RefreshUi()
    end)

    local autoButton = CreateButton(mainFrame, "Auto on/off", 92, 24)
    autoButton:SetPoint("LEFT", captureGold, "RIGHT", 8, 0)
    autoButton:SetScript("OnClick", function()
        DB.autoApply = not DB.autoApply
        Print("Auto apply: " .. (DB.autoApply and "on" or "off"))
        RefreshUi()
    end)

    local help = mainFrame:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    help:SetPoint("TOPLEFT", capturePlay, "BOTTOMLEFT", 0, -10)
    help:SetWidth(468)
    help:SetJustifyH("LEFT")
    help:SetText("Workflow: regle tes addons une fois, capture Jouer/Gold, assigne les persos.")

    local header = mainFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    header:SetPoint("TOPLEFT", help, "BOTTOMLEFT", 0, -12)
    header:SetText("Personnages connus")

    local scrollFrame = CreateFrame("ScrollFrame", nil, mainFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -6)
    scrollFrame:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -32, 18)

    scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(452, 1)
    scrollFrame:SetScrollChild(scrollChild)
end

local function PrintHelp()
    Print("/yap: ouvrir/fermer")
    Print("/yap play|gold: assigner et appliquer au perso courant")
    Print("/yap capture play|gold: capturer les addons coches actuellement")
    Print("/yap set Perso-Royaume play|gold: assigner un profil a un perso")
    Print("/yap apply: appliquer le profil assigne")
    Print("/yap auto on|off: application auto a la connexion")
end

local function HandleSlashCommand(message)
    message = Trim(message)
    if message == "" then
        ToggleUi()
        return
    end

    local command, rest = message:match("^(%S+)%s*(.-)$")
    command = (command or ""):lower()
    rest = Trim(rest)

    local directProfile = NormalizeProfileKey(command)
    if directProfile then
        AssignProfile(currentCharacter, directProfile, true)
        RefreshUi()
        return
    end

    if command == "capture" then
        local profileKey = NormalizeProfileKey(rest)
        if profileKey then
            CaptureProfile(profileKey)
            RefreshUi()
        else
            Print("Profil attendu: play ou gold.")
        end
        return
    end

    if command == "apply" then
        local assigned = DB.assignments[currentCharacter]
        if assigned then
            ApplyProfile(assigned)
            RefreshUi()
        else
            Print("Aucun profil assigne a ce personnage.")
        end
        return
    end

    if command == "set" then
        local characterId, profileValue = rest:match("^(%S+)%s+(%S+)$")
        local profileKey = NormalizeProfileKey(profileValue)
        if characterId and profileKey then
            DB.characters[characterId] = DB.characters[characterId] or {
                id = characterId,
                color = "ffffffff",
            }
            AssignProfile(characterId, profileKey, characterId == currentCharacter)
            RefreshUi()
        else
            Print("Usage: /yap set Perso-Royaume play|gold")
        end
        return
    end

    if command == "auto" then
        local value = rest:lower()
        if value == "on" then
            DB.autoApply = true
        elseif value == "off" then
            DB.autoApply = false
        else
            DB.autoApply = not DB.autoApply
        end
        Print("Auto apply: " .. (DB.autoApply and "on" or "off"))
        RefreshUi()
        return
    end

    if command == "status" then
        local assigned = DB.assignments[currentCharacter]
        Print("Perso: " .. currentCharacter .. " | profil: " .. (assigned and PROFILE_LABELS[assigned] or "aucun"))
        return
    end

    PrintHelp()
end

local function OnLogin()
    EnsureDb()
    RememberCurrentCharacter()
    CreateUi()

    SLASH_YAYAADDONPROFILES1 = "/yap"
    SLASH_YAYAADDONPROFILES2 = "/yayaaddons"
    SlashCmdList.YAYAADDONPROFILES = HandleSlashCommand

    local assigned = DB.assignments[currentCharacter]
    if DB.autoApply and assigned and IsProfileReady(assigned) and not ProfileMatches(assigned) then
        ApplyProfile(assigned, true)
    end
end

function YayaAddonProfiles_OnAddonCompartmentClick()
    if mainFrame then
        ToggleUi()
    end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", OnLogin)
