local addonName = ...

local PREFIX = "|cff33ff99YPA|r "
local PARTY_CATEGORY = LE_PARTY_CATEGORY_HOME or 1
local PARTY_CAPACITY = (MAX_PARTY_MEMBERS or 4) + 1
local RAID_CAPACITY = MAX_RAID_MEMBERS or 40
local runtime = {
    applicantAttempts = {},
    acceptAttempts = {},
    processScheduled = false,
    pendingConversionApplicantID = nil,
    pendingGroupApplicantIDs = {},
    pendingAcceptResultID = nil,
    retryAfterCombat = false,
}

local mainFrame
local statusText
local toggleButton
local actionButton

local function Print(message)
    print(PREFIX .. tostring(message))
end

local function GetDB()
    if not YayaPremadeAssistantDB then
        YayaPremadeAssistantDB = {}
    end

    local db = YayaPremadeAssistantDB
    if db.enabled == nil then db.enabled = true end
    if db.autoInvite == nil then db.autoInvite = true end
    if db.autoAccept == nil then db.autoAccept = true end
    if db.debug == nil then db.debug = false end
    if db.showFrame == nil then db.showFrame = true end
    db.position = db.position or { point = "CENTER", relativePoint = "CENTER", x = 360, y = 40 }
    return db
end

local function Debug(message)
    if GetDB().debug then
        Print("[debug] " .. tostring(message))
    end
end

local function SafeCall(label, callback)
    local ok, result = pcall(callback)
    if not ok then
        Print(label .. " impossible: " .. tostring(result))
        return false
    end
    return true, result
end

local function HasActiveListing()
    if not C_LFGList then
        return false
    end
    if C_LFGList.HasActiveEntryInfo then
        return C_LFGList.HasActiveEntryInfo()
    end
    return C_LFGList.GetActiveEntryInfo and C_LFGList.GetActiveEntryInfo() ~= nil
end

local function CanManageListing()
    if not HasActiveListing() then
        return false
    end
    if not IsInGroup(PARTY_CATEGORY) then
        return true
    end
    return UnitIsGroupLeader("player", PARTY_CATEGORY) or UnitIsGroupAssistant("player", PARTY_CATEGORY)
end

local function GetGroupSize()
    local size = GetNumGroupMembers(PARTY_CATEGORY) or 0
    return math.max(1, size)
end

local function GetListingMaxPlayers()
    local fallback = IsInRaid(PARTY_CATEGORY) and RAID_CAPACITY or PARTY_CAPACITY
    if not C_LFGList or not C_LFGList.GetActiveEntryInfo or not C_LFGList.GetActivityInfoTable then
        return fallback
    end

    local entryInfo = C_LFGList.GetActiveEntryInfo()
    if not entryInfo or type(entryInfo.activityIDs) ~= "table" then
        return fallback
    end

    local maxPlayers = 0
    for _, activityID in ipairs(entryInfo.activityIDs) do
        local activityInfo = C_LFGList.GetActivityInfoTable(activityID, entryInfo.questID)
        if activityInfo then
            local activityMax = activityInfo.maxNumPlayers or 0
            maxPlayers = math.max(maxPlayers, activityMax == 0 and RAID_CAPACITY or activityMax)
        end
    end
    return maxPlayers > 0 and maxPlayers or fallback
end

local function GetInvitedApplicantMembers()
    if C_LFGList and C_LFGList.GetNumInvitedApplicantMembers then
        local ok, count = SafeCall("GetNumInvitedApplicantMembers", C_LFGList.GetNumInvitedApplicantMembers)
        if ok then
            return count or 0
        end
    end
    return 0
end

local function RefreshUI()
    if not mainFrame then
        return
    end

    local db = GetDB()
    if db.showFrame then mainFrame:Show() else mainFrame:Hide() end

    toggleButton:SetText(db.enabled and "Auto : ON" or "Auto : OFF")
    statusText:SetText(("Inviter: %s  |  Accepter: %s"):format(
        db.autoInvite and "ON" or "OFF",
        db.autoAccept and "ON" or "OFF"
    ))

    if runtime.pendingConversionApplicantID then
        actionButton:SetText("Convertir en raid + inviter")
        actionButton:Show()
    elseif runtime.pendingAcceptResultID then
        actionButton:SetText("Accepter le groupe")
        actionButton:Show()
    elseif #runtime.pendingGroupApplicantIDs > 0 then
        actionButton:SetText(("Inviter groupes (%d)"):format(#runtime.pendingGroupApplicantIDs))
        actionButton:Show()
    else
        actionButton:Hide()
    end
end

local ProcessAll
local ScheduleProcess

local function GetPendingSoloInviteCount()
    local now = GetTime()
    local count = 0

    for applicantID, attemptedAt in pairs(runtime.applicantAttempts) do
        local info = C_LFGList.GetApplicantInfo(applicantID)
        if now - attemptedAt < 60 and info and info.applicationStatus == "applied" then
            count = count + 1
        else
            runtime.applicantAttempts[applicantID] = nil
        end
    end
    return count
end

local function InviteSoloApplicant(applicantID)
    local now = GetTime()
    local lastAttempt = runtime.applicantAttempts[applicantID]
    if lastAttempt and now - lastAttempt < 60 then
        return false
    end

    local name = C_LFGList.GetApplicantMemberInfo(applicantID, 1)
    if not name then
        return false
    end

    runtime.applicantAttempts[applicantID] = now
    local ok = SafeCall("InviteUnit", function()
        C_PartyInfo.InviteUnit(name)
    end)
    if ok then
        Debug("candidature solo invitee: " .. tostring(applicantID))
    end
    return ok
end

local function ProcessApplicants()
    local db = GetDB()
    runtime.pendingConversionApplicantID = nil
    runtime.pendingGroupApplicantIDs = {}

    if not db.enabled or not db.autoInvite or not CanManageListing() then
        return
    end
    if InCombatLockdown() then
        runtime.retryAfterCombat = true
        return
    end
    if not C_LFGList.GetApplicants or not C_LFGList.GetApplicantInfo or not C_LFGList.GetApplicantMemberInfo
        or not C_PartyInfo or not C_PartyInfo.InviteUnit then
        return
    end

    local applicantIDs = C_LFGList.GetApplicants()
    if type(applicantIDs) ~= "table" then
        return
    end

    local activityMax = GetListingMaxPlayers()
    local currentSize = GetGroupSize()
    local invitedMembers = GetInvitedApplicantMembers() + GetPendingSoloInviteCount()
    local currentCap = IsInRaid(PARTY_CATEGORY) and math.min(activityMax, RAID_CAPACITY) or math.min(activityMax, PARTY_CAPACITY)

    for _, applicantID in ipairs(applicantIDs) do
        local info = C_LFGList.GetApplicantInfo(applicantID)
        local status = info and info.applicationStatus
        local pendingStatus = info and info.pendingApplicationStatus
        local numMembers = info and info.numMembers or 1

        if status == "applied" and not pendingStatus then
            if currentSize + invitedMembers + numMembers <= currentCap then
                if numMembers == 1 and InviteSoloApplicant(applicantID) then
                    invitedMembers = invitedMembers + numMembers
                elseif numMembers > 1 then
                    runtime.pendingGroupApplicantIDs[#runtime.pendingGroupApplicantIDs + 1] = applicantID
                    invitedMembers = invitedMembers + numMembers
                end
            elseif not IsInRaid(PARTY_CATEGORY) and activityMax > PARTY_CAPACITY then
                runtime.pendingConversionApplicantID = runtime.pendingConversionApplicantID or applicantID
            end
        end
    end
end

local function GetApplicationStatus(resultID)
    if not C_LFGList or not C_LFGList.GetApplicationInfo then
        return nil, nil
    end
    local _, status, pendingStatus = C_LFGList.GetApplicationInfo(resultID)
    return status, pendingStatus
end

local function AcceptLFGInvite(resultID, force)
    local now = GetTime()
    local lastAttempt = runtime.acceptAttempts[resultID]
    if not force and lastAttempt and now - lastAttempt < 10 then
        if now - lastAttempt >= 1 then
            runtime.pendingAcceptResultID = resultID
        end
        return false
    end

    runtime.acceptAttempts[resultID] = now
    local ok = SafeCall("AcceptInvite", function()
        C_LFGList.AcceptInvite(resultID)
    end)
    if ok then
        Debug("invitation LFG acceptee: " .. tostring(resultID))
    else
        runtime.pendingAcceptResultID = resultID
    end
    C_Timer.After(1.2, function()
        ScheduleProcess(0)
    end)
    return ok
end

local function ProcessApplications()
    local db = GetDB()
    runtime.pendingAcceptResultID = nil

    if not db.enabled or not db.autoAccept or not C_LFGList or not C_LFGList.GetApplications or not C_LFGList.AcceptInvite then
        return
    end
    if InCombatLockdown() then
        runtime.retryAfterCombat = true
        return
    end

    local resultIDs = C_LFGList.GetApplications()
    if type(resultIDs) ~= "table" then
        return
    end

    for _, resultID in ipairs(resultIDs) do
        local status, pendingStatus = GetApplicationStatus(resultID)
        if status == "invited" and not pendingStatus then
            AcceptLFGInvite(resultID, false)
            break
        end
    end
end

ProcessAll = function()
    ProcessApplicants()
    ProcessApplications()
    RefreshUI()
end

ScheduleProcess = function(delay)
    if runtime.processScheduled then
        return
    end
    runtime.processScheduled = true
    C_Timer.After(delay or 0.2, function()
        runtime.processScheduled = false
        ProcessAll()
    end)
end

local function HandleActionButton()
    if runtime.pendingConversionApplicantID then
        local applicantID = runtime.pendingConversionApplicantID
        if C_PartyInfo and C_PartyInfo.ConfirmConvertToRaid then
            SafeCall("ConfirmConvertToRaid", C_PartyInfo.ConfirmConvertToRaid)
            SafeCall("InviteApplicant", function()
                C_LFGList.InviteApplicant(applicantID)
            end)
            runtime.pendingConversionApplicantID = nil
            ScheduleProcess(0.5)
        end
        return
    end

    if runtime.pendingAcceptResultID then
        local resultID = runtime.pendingAcceptResultID
        runtime.pendingAcceptResultID = nil
        AcceptLFGInvite(resultID, true)
        ScheduleProcess(0.5)
        return
    end

    if #runtime.pendingGroupApplicantIDs > 0 then
        local applicantIDs = runtime.pendingGroupApplicantIDs
        runtime.pendingGroupApplicantIDs = {}
        for _, applicantID in ipairs(applicantIDs) do
            local info = C_LFGList.GetApplicantInfo(applicantID)
            if info and info.applicationStatus == "applied" and not info.pendingApplicationStatus then
                SafeCall("InviteApplicant", function()
                    C_LFGList.InviteApplicant(applicantID)
                end)
            end
        end
        ScheduleProcess(0.5)
    end
end

local function CreateUI()
    mainFrame = CreateFrame("Frame", "YayaPremadeAssistantFrame", UIParent, "BackdropTemplate")
    mainFrame:SetSize(230, 92)
    mainFrame:SetClampedToScreen(true)
    mainFrame:SetMovable(true)
    mainFrame:EnableMouse(true)
    mainFrame:RegisterForDrag("LeftButton")
    mainFrame:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    mainFrame:SetBackdropColor(0.04, 0.04, 0.04, 0.92)

    local position = GetDB().position
    mainFrame:SetPoint(position.point, UIParent, position.relativePoint, position.x, position.y)
    mainFrame:SetScript("OnDragStart", mainFrame.StartMoving)
    mainFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relativePoint, x, y = self:GetPoint()
        GetDB().position = { point = point, relativePoint = relativePoint, x = x, y = y }
    end)

    local title = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", 10, -9)
    title:SetText("Yaya Premade")

    local closeButton = CreateFrame("Button", nil, mainFrame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", 1, 1)
    closeButton:SetScript("OnClick", function()
        GetDB().showFrame = false
        RefreshUI()
    end)

    statusText = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    statusText:SetPoint("TOPLEFT", 10, -31)

    toggleButton = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
    toggleButton:SetSize(82, 22)
    toggleButton:SetPoint("BOTTOMLEFT", 9, 9)
    toggleButton:SetScript("OnClick", function()
        local db = GetDB()
        db.enabled = not db.enabled
        Print("auto=" .. (db.enabled and "on" or "off"))
        ScheduleProcess(0)
        RefreshUI()
    end)

    actionButton = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
    actionButton:SetSize(125, 22)
    actionButton:SetPoint("BOTTOMRIGHT", -9, 9)
    actionButton:SetScript("OnClick", HandleActionButton)
    RefreshUI()
end

local function PrintStatus()
    local db = GetDB()
    Print(("auto=%s inviter=%s accepter=%s debug=%s"):format(
        db.enabled and "on" or "off",
        db.autoInvite and "on" or "off",
        db.autoAccept and "on" or "off",
        db.debug and "on" or "off"
    ))
end

local function SetOption(key, value, label)
    if value ~= "on" and value ~= "off" then
        Print("usage: /ypa " .. label .. " on|off")
        return
    end
    GetDB()[key] = value == "on"
    Print(label .. "=" .. value)
    ScheduleProcess(0)
    RefreshUI()
end

local function HandleSlashCommand(message)
    local command, value = (message or ""):lower():match("^%s*(%S*)%s*(%S*)")
    if command == "" then
        local db = GetDB()
        db.showFrame = not db.showFrame
        RefreshUI()
    elseif command == "status" then
        PrintStatus()
    elseif command == "on" or command == "off" then
        GetDB().enabled = command == "on"
        Print("auto=" .. command)
        ScheduleProcess(0)
        RefreshUI()
    elseif command == "leader" then
        SetOption("autoInvite", value, "leader")
    elseif command == "accept" then
        SetOption("autoAccept", value, "accept")
    elseif command == "now" then
        ProcessAll()
    elseif command == "debug" then
        local db = GetDB()
        db.debug = not db.debug
        Print("debug=" .. (db.debug and "on" or "off"))
    else
        Print("cmds: status, on, off, leader on|off, accept on|off, now, debug")
    end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        if ... ~= addonName then
            return
        end
        GetDB()
        CreateUI()
        SLASH_YAYAPREMADEASSISTANT1 = "/ypa"
        SlashCmdList.YAYAPREMADEASSISTANT = HandleSlashCommand

        eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
        eventFrame:RegisterEvent("LFG_LIST_ACTIVE_ENTRY_UPDATE")
        eventFrame:RegisterEvent("LFG_LIST_APPLICANT_LIST_UPDATED")
        eventFrame:RegisterEvent("LFG_LIST_APPLICANT_UPDATED")
        eventFrame:RegisterEvent("LFG_LIST_APPLICATION_STATUS_UPDATED")
        eventFrame:RegisterEvent("LFG_LIST_SEARCH_RESULT_UPDATED")
        eventFrame:RegisterEvent("LFG_LIST_JOINED_GROUP")
        eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
        eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
        ScheduleProcess(1)
        return
    end

    if event == "LFG_LIST_ACTIVE_ENTRY_UPDATE" then
        runtime.applicantAttempts = {}
    elseif event == "GROUP_ROSTER_UPDATE" or event == "LFG_LIST_JOINED_GROUP" then
        runtime.pendingConversionApplicantID = nil
        runtime.pendingGroupApplicantIDs = {}
    elseif event == "PLAYER_REGEN_ENABLED" then
        runtime.retryAfterCombat = false
    end
    ScheduleProcess(event == "PLAYER_ENTERING_WORLD" and 1 or 0.2)
end)
