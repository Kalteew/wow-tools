local addonName = ...

local OPTION_KEY = "autoOpenContainers"
local DEFAULT_OPEN_DELAY_SECONDS = 0.05
local SCAN_DELAY_SECONDS = 0.05
local INITIAL_SCAN_DELAY_SECONDS = 0.30
local MAIL_LOOT_IDLE_SECONDS = 0.50
local MAIL_ACTIVITY_EXTRA_DELAY_SECONDS = 0.05
local PENDING_CHECK_DELAY_SECONDS = 0.03
local PENDING_TIMEOUT_SECONDS = 1.20
local LOOT_SETTLE_SECONDS = 0.45
local CONTAINER_VALUES_MAX_WAIT_SECONDS = 1.35
local MAX_FAILURES = 3
local BLOCKED_RETRY_SECONDS = 0.10
local MAX_BLOCKED_RETRY_SECONDS = 2.00

local state = {
    phase = "idle",
    queue = {},
    queueKeys = {},
    pending = nil,
    failureCount = 0,
    halted = false,
    wasEnabled = false,
    lastEnabled = nil,
    itemIDs = {},
    scanTimer = nil,
    openTimer = nil,
    pendingTimer = nil,
    resumeTimer = nil,
    reportNextScan = false,
    mailSettleUntil = 0,
    mailHooksInitialized = false,
}
local OpenNextContainer
local ScheduleScan

local eventFrame = CreateFrame("Frame", addonName .. "AutoOpenFrame")

local function EnsureOptions()
    YayaWeeklyTrackerAccountDB = type(YayaWeeklyTrackerAccountDB) == "table"
        and YayaWeeklyTrackerAccountDB
        or {}
    if YayaWeeklyTrackerAccountDB[OPTION_KEY] == nil then
        YayaWeeklyTrackerAccountDB[OPTION_KEY] = false
    end
    return YayaWeeklyTrackerAccountDB
end

local function IsEnabled()
    return EnsureOptions()[OPTION_KEY] == true
end

local function Now()
    return GetTime and GetTime() or 0
end

local function StopTimer(field)
    local timer = state[field]
    if timer and type(timer.Cancel) == "function" then
        timer:Cancel()
    end
    state[field] = nil
end

local function StopTimers()
    StopTimer("scanTimer")
    StopTimer("openTimer")
    StopTimer("pendingTimer")
    StopTimer("resumeTimer")
end

local function ClearQueue()
    for index = #state.queue, 1, -1 do
        state.queue[index] = nil
    end
    for key in pairs(state.queueKeys) do
        state.queueKeys[key] = nil
    end
end

local function Log(message)
    local text = tostring(message)
    local api = _G.YayaWeeklyTrackerAutoOpen
    if api and type(api.DebugLog) == "function" then
        pcall(api.DebugLog, text)
    end
    if DEFAULT_CHAT_FRAME and type(DEFAULT_CHAT_FRAME.AddMessage) == "function" then
        DEFAULT_CHAT_FRAME:AddMessage(("|cff7fff7fYWT AutoOpen|r: %s"):format(text))
    end
end

local function IsFrameVisible(frame)
    if not frame then
        return false
    end
    if type(frame.IsVisible) == "function" then
        return frame:IsVisible()
    end
    return type(frame.IsShown) == "function" and frame:IsShown() or false
end

local function IsMailboxVisible()
    return IsFrameVisible(_G.MailFrame) or IsFrameVisible(_G.InboxFrame)
end

local function IsBlocked()
    if InCombatLockdown and InCombatLockdown() then
        return true
    end
    if UnitCastingInfo and UnitCastingInfo("player") then
        return true
    end
    if UnitChannelInfo and UnitChannelInfo("player") then
        return true
    end
    if C_Mail and type(C_Mail.IsCommandPending) == "function" then
        local ok, pending = pcall(C_Mail.IsCommandPending)
        if ok and pending then
            return true
        end
    end

    for _, frameName in ipairs({
        "MerchantFrame",
        "BankFrame",
        "AccountBankPanel",
        "AccountBankFrame",
        "GuildBankFrame",
        "TradeFrame",
    }) do
        local frame = _G[frameName]
        if IsFrameVisible(frame) then
            return true
        end
    end

    return IsMailboxVisible() == true
end

local function Schedule(field, delaySeconds, callback)
    StopTimer(field)
    if not (C_Timer and type(C_Timer.NewTimer) == "function") then
        callback()
        return
    end
    state[field] = C_Timer.NewTimer(delaySeconds, function()
        state[field] = nil
        callback()
    end)
end

local function GetContainerInfo(bagID, slotID)
    if not (C_Container and type(C_Container.GetContainerItemInfo) == "function") then
        return nil
    end
    local ok, info = pcall(C_Container.GetContainerItemInfo, bagID, slotID)
    return ok and info or nil
end

local function GetContainerSlots(bagID)
    if not (C_Container and type(C_Container.GetContainerNumSlots) == "function") then
        return 0
    end
    local ok, slots = pcall(C_Container.GetContainerNumSlots, bagID)
    return ok and tonumber(slots) or 0
end

local function ReadSlot(bagID, slotID)
    local itemID
    if C_Container and type(C_Container.GetContainerItemID) == "function" then
        local ok, fallbackItemID = pcall(C_Container.GetContainerItemID, bagID, slotID)
        itemID = ok and tonumber(fallbackItemID) or nil
    end
    local info = GetContainerInfo(bagID, slotID)
    itemID = itemID or (info and tonumber(info.itemID) or nil)
    if not itemID then
        return nil, 0
    end
    return itemID, math.max(tonumber(info and (info.stackCount or info.quantity)) or 1, 1)
end

local function GetMaxBagIndex()
    return math.max(
        tonumber(NUM_TOTAL_EQUIPPED_BAG_SLOTS) or 0,
        tonumber(NUM_BAG_SLOTS) or 0,
        5
    )
end

local function CountItem(itemID)
    local total = 0
    for bagID = 0, GetMaxBagIndex() do
        for slotID = 1, GetContainerSlots(bagID) do
            local currentItemID, count = ReadSlot(bagID, slotID)
            if currentItemID == itemID then
                total = total + count
            end
        end
    end
    return total
end

local function RefreshConfiguredItems()
    local api = _G.YayaWeeklyTrackerAutoOpen
    if not api or type(api.GetAutoOpenContainerItemIDs) ~= "function" then
        state.itemIDs = {}
        return
    end
    local ok, itemIDs = pcall(api.GetAutoOpenContainerItemIDs)
    state.itemIDs = ok and type(itemIDs) == "table" and itemIDs or {}
end

local function IsContainerValuesPending()
    local api = _G.YayaContainerValuesAPI
    if not api or type(api.IsOpeningPending) ~= "function" then
        return false
    end
    local ok, pending = pcall(api.IsOpeningPending)
    return ok and pending == true
end

local function MarkMailboxLootActivity()
    state.mailSettleUntil = math.max(
        state.mailSettleUntil or 0,
        Now() + MAIL_LOOT_IDLE_SECONDS + MAIL_ACTIVITY_EXTRA_DELAY_SECONDS
    )
end

local function EnsureMailHooks()
    if state.mailHooksInitialized or type(hooksecurefunc) ~= "function" then
        return
    end
    for _, functionName in ipairs({ "AutoLootMailItem", "TakeInboxMoney", "TakeInboxItem" }) do
        if type(_G[functionName]) == "function" then
            hooksecurefunc(functionName, MarkMailboxLootActivity)
        end
    end
    state.mailHooksInitialized = true
end

local function ScheduleMailboxLootScan(shouldClearQueue)
    MarkMailboxLootActivity()
    StopTimer("scanTimer")
    StopTimer("openTimer")
    if shouldClearQueue then
        ClearQueue()
    end
    ScheduleScan(MAIL_LOOT_IDLE_SECONDS + MAIL_ACTIVITY_EXTRA_DELAY_SECONDS)
end

local function CountConfiguredItems()
    local count = 0
    for _ in pairs(state.itemIDs) do
        count = count + 1
    end
    return count
end

local function QueueCandidate(bagID, slotID, itemID)
    local key = ("%d:%d:%d"):format(bagID, slotID, itemID)
    if state.queueKeys[key] then
        return
    end
    state.queueKeys[key] = true
    state.queue[#state.queue + 1] = {
        bagID = bagID,
        slotID = slotID,
        itemID = itemID,
    }
end

local function ScanBags()
    state.scanTimer = nil
    if not IsEnabled() then
        StopTimers()
        ClearQueue()
        state.pending = nil
        state.phase = "idle"
        state.halted = false
        state.wasEnabled = false
        return
    end
    if state.halted then
        state.phase = "halted"
        return
    end
    if IsBlocked() then
        if state.reportNextScan then
            Log("scan suspendu: combat, cast ou interface sensible")
        end
        state.phase = "paused"
        return
    end
    if state.pending then
        state.phase = "paused"
        return
    end

    ClearQueue()
    if IsEnabled() then
        RefreshConfiguredItems()
        for bagID = 0, GetMaxBagIndex() do
            for slotID = 1, GetContainerSlots(bagID) do
                local itemID = ReadSlot(bagID, slotID)
                if itemID and state.itemIDs[itemID] then
                    QueueCandidate(bagID, slotID, itemID)
                end
            end
        end
    end

    if #state.queue == 0 then
        state.phase = "idle"
        if state.reportNextScan then
            Log(("scan: 0 candidat, %d IDs suivis"):format(CountConfiguredItems()))
            state.reportNextScan = false
        end
        return
    end

    if state.reportNextScan then
        Log(("scan: %d candidat(s) détecté(s)"):format(#state.queue))
        state.reportNextScan = false
    end

    table.sort(state.queue, function(left, right)
        if left.bagID ~= right.bagID then
            return left.bagID < right.bagID
        end
        return left.slotID < right.slotID
    end)
    state.phase = "candidate"
    Schedule("openTimer", DEFAULT_OPEN_DELAY_SECONDS, function()
        state.openTimer = nil
        OpenNextContainer()
    end)
end

ScheduleScan = function(delaySeconds)
    if not IsEnabled() or state.halted or state.pending then
        return
    end
    local delay = delaySeconds or SCAN_DELAY_SECONDS
    local mailDelay = (state.mailSettleUntil or 0) - Now()
    if mailDelay > delay then
        delay = mailDelay
    end
    Schedule("scanTimer", delay, ScanBags)
end

local function StopAutoOpen(reason, halt)
    StopTimers()
    ClearQueue()
    state.pending = nil
    state.phase = "idle"
    state.failureCount = 0
    state.halted = halt == true
    state.mailSettleUntil = 0
    if reason then
        Log(reason)
    end
end

local function CheckPendingContainer()
    StopTimer("pendingTimer")
    local pending = state.pending
    if not pending then
        return
    end
    if not IsEnabled() then
        StopAutoOpen()
        return
    end

    local mailDelay = (state.mailSettleUntil or 0) - Now()
    if mailDelay > 0 then
        state.phase = "paused"
        Schedule("pendingTimer", mailDelay, CheckPendingContainer)
        return
    end

    if IsBlocked() then
        pending.pausedAt = pending.pausedAt or Now()
        state.phase = "paused"
        return
    end

    if pending.pausedAt then
        pending.pausedSeconds = (pending.pausedSeconds or 0) + Now() - pending.pausedAt
        pending.pausedAt = nil
    end

    local currentItemID, currentSlotCount = ReadSlot(pending.bagID, pending.slotID)
    local currentTotal = CountItem(pending.itemID)
    local elapsed = Now() - pending.startedAt - (pending.pausedSeconds or 0)
    local consumed = currentItemID ~= pending.itemID
        or currentSlotCount < pending.beforeSlotCount
        or currentTotal < pending.beforeTotalCount

    if consumed then
        pending.consumedAt = pending.consumedAt or Now()
        if IsContainerValuesPending() and elapsed < CONTAINER_VALUES_MAX_WAIT_SECONDS then
            Schedule("pendingTimer", PENDING_CHECK_DELAY_SECONDS, CheckPendingContainer)
            return
        end
        if Now() - pending.consumedAt < LOOT_SETTLE_SECONDS then
            Schedule("pendingTimer", PENDING_CHECK_DELAY_SECONDS, CheckPendingContainer)
            return
        end

        state.pending = nil
        state.phase = "settled"
        state.failureCount = 0
        ScheduleScan(DEFAULT_OPEN_DELAY_SECONDS)
        return
    end

    if elapsed < PENDING_TIMEOUT_SECONDS then
        Schedule("pendingTimer", PENDING_CHECK_DELAY_SECONDS, CheckPendingContainer)
        return
    end

    state.pending = nil
    state.failureCount = state.failureCount + 1
    if state.failureCount >= MAX_FAILURES then
        StopAutoOpen("arrêt après 3 ouvertures sans consommation confirmée", true)
    else
        state.phase = "candidate"
        ScheduleScan(SCAN_DELAY_SECONDS)
    end
end

OpenNextContainer = function()
    state.openTimer = nil
    if not IsEnabled() then
        StopAutoOpen()
        return
    end
    if state.halted then
        state.phase = "halted"
        return
    end
    if IsBlocked() or state.pending then
        state.phase = "paused"
        return
    end

    local candidate = table.remove(state.queue, 1)
    if not candidate then
        state.phase = "idle"
        return
    end
    state.queueKeys[("%d:%d:%d"):format(candidate.bagID, candidate.slotID, candidate.itemID)] = nil

    local currentItemID, currentSlotCount = ReadSlot(candidate.bagID, candidate.slotID)
    if currentItemID ~= candidate.itemID or currentSlotCount <= 0 then
        ClearQueue()
        ScheduleScan(SCAN_DELAY_SECONDS)
        return
    end

    if not (C_Container and type(C_Container.UseContainerItem) == "function") then
        StopAutoOpen("C_Container.UseContainerItem indisponible", true)
        return
    end

    local beforeTotalCount = CountItem(candidate.itemID)
    state.pending = {
        bagID = candidate.bagID,
        slotID = candidate.slotID,
        itemID = candidate.itemID,
        beforeSlotCount = currentSlotCount,
        beforeTotalCount = beforeTotalCount,
        startedAt = Now(),
        pausedSeconds = 0,
    }
    state.phase = "opening"
    Log(("tentative ouverture itemID=%d bag=%d slot=%d"):format(
        candidate.itemID,
        candidate.bagID,
        candidate.slotID
    ))
    local ok, result = pcall(C_Container.UseContainerItem, candidate.bagID, candidate.slotID)
    if not ok or result == false then
        state.pending = nil
        StopAutoOpen("échec de C_Container.UseContainerItem", true)
        return
    end

    state.phase = "loot pending"
    Schedule("pendingTimer", PENDING_CHECK_DELAY_SECONDS, CheckPendingContainer)
end

local function PauseForBlockedUI()
    StopTimer("scanTimer")
    StopTimer("openTimer")
    StopTimer("pendingTimer")
    StopTimer("resumeTimer")
    if state.pending then
        state.pending.pausedAt = state.pending.pausedAt or Now()
    end
    state.phase = "paused"
end

local function ResumeAfterBlockedUI(startedAt)
    if not IsEnabled() or state.halted then
        return
    end

    local mailDelay = (state.mailSettleUntil or 0) - Now()
    if mailDelay > 0 then
        Schedule("resumeTimer", mailDelay, function()
            ResumeAfterBlockedUI(startedAt)
        end)
        return
    end

    if IsBlocked() then
        startedAt = startedAt or Now()
        if Now() - startedAt < MAX_BLOCKED_RETRY_SECONDS then
            Schedule("resumeTimer", BLOCKED_RETRY_SECONDS, function()
                ResumeAfterBlockedUI(startedAt)
            end)
        end
        return
    end

    StopTimer("resumeTimer")
    if state.pending then
        if state.pending.pausedAt then
            state.pending.pausedSeconds = (state.pending.pausedSeconds or 0) + Now() - state.pending.pausedAt
            state.pending.pausedAt = nil
        end
        Schedule("pendingTimer", PENDING_CHECK_DELAY_SECONDS, CheckPendingContainer)
    else
        ScheduleScan(SCAN_DELAY_SECONDS)
    end
end

local function Refresh()
    EnsureOptions()
    local enabled = IsEnabled()
    local optionsChanged = state.lastEnabled ~= enabled
    state.lastEnabled = enabled

    if optionsChanged then
        state.failureCount = 0
        state.halted = false
    end

    if state.pending and not enabled then
        StopAutoOpen()
    end

    if not enabled then
        state.wasEnabled = false
        state.halted = false
        StopAutoOpen()
        return
    end
    if not state.wasEnabled then
        state.failureCount = 0
        state.halted = false
    end
    state.wasEnabled = true
    state.reportNextScan = true
    RefreshConfiguredItems()
    StopTimer("scanTimer")
    if not state.pending and not state.halted then
        ScheduleScan(SCAN_DELAY_SECONDS)
    end
end

_G.YayaWeeklyTrackerAutoOpen = _G.YayaWeeklyTrackerAutoOpen or {}
_G.YayaWeeklyTrackerAutoOpen.Refresh = Refresh

eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("BAG_UPDATE")
eventFrame:RegisterEvent("BAG_UPDATE_DELAYED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:RegisterEvent("UNIT_SPELLCAST_START")
eventFrame:RegisterEvent("UNIT_SPELLCAST_STOP")
eventFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
eventFrame:RegisterEvent("UNIT_SPELLCAST_FAILED")
eventFrame:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
eventFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
eventFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
eventFrame:RegisterEvent("MERCHANT_SHOW")
eventFrame:RegisterEvent("MERCHANT_CLOSED")
eventFrame:RegisterEvent("BANKFRAME_OPENED")
eventFrame:RegisterEvent("BANKFRAME_CLOSED")
eventFrame:RegisterEvent("TRADE_SHOW")
eventFrame:RegisterEvent("TRADE_CLOSED")
eventFrame:RegisterEvent("MAIL_SHOW")
eventFrame:RegisterEvent("MAIL_CLOSED")
eventFrame:RegisterEvent("MAIL_INBOX_UPDATE")
eventFrame:RegisterEvent("MAIL_SUCCESS")
eventFrame:RegisterEvent("MAIL_FAILED")
eventFrame:RegisterEvent("CLOSE_INBOX_ITEM")

eventFrame:SetScript("OnEvent", function(_, event, unit)
    if event:match("^UNIT_SPELLCAST") and unit ~= "player" then
        return
    end
    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        EnsureMailHooks()
        Refresh()
        if IsEnabled() then
            ScheduleScan(INITIAL_SCAN_DELAY_SECONDS)
        end
    elseif event == "BAG_UPDATE" then
        if state.pending then
            state.pending.bagUpdateSeen = true
        end
    elseif event == "BAG_UPDATE_DELAYED" then
        if state.pending then
            CheckPendingContainer()
        elseif not IsBlocked() then
            ScheduleScan(SCAN_DELAY_SECONDS)
        else
            PauseForBlockedUI()
        end
    elseif event == "MAIL_SHOW" then
        EnsureMailHooks()
        PauseForBlockedUI()
    elseif event == "MAIL_CLOSED" then
        state.mailSettleUntil = Now() + MAIL_LOOT_IDLE_SECONDS
        Log(("courrier fermé: attente %.2fs avant le scan des sacs"):format(MAIL_LOOT_IDLE_SECONDS))
        ResumeAfterBlockedUI()
    elseif event == "MAIL_INBOX_UPDATE"
        or event == "MAIL_SUCCESS"
        or event == "CLOSE_INBOX_ITEM"
    then
        if IsMailboxVisible() then
            ScheduleMailboxLootScan(true)
        end
    elseif event == "MAIL_FAILED" then
        if IsMailboxVisible() then
            ScheduleMailboxLootScan(false)
        end
    elseif event == "PLAYER_REGEN_ENABLED"
        or event == "UNIT_SPELLCAST_STOP"
        or event == "UNIT_SPELLCAST_SUCCEEDED"
        or event == "UNIT_SPELLCAST_FAILED"
        or event == "UNIT_SPELLCAST_INTERRUPTED"
        or event == "UNIT_SPELLCAST_CHANNEL_STOP"
        or event == "MERCHANT_CLOSED"
        or event == "BANKFRAME_CLOSED"
        or event == "TRADE_CLOSED"
    then
        ResumeAfterBlockedUI()
    elseif event == "MERCHANT_SHOW"
        or event == "UNIT_SPELLCAST_START"
        or event == "UNIT_SPELLCAST_CHANNEL_START"
        or event == "BANKFRAME_OPENED"
        or event == "TRADE_SHOW"
    then
        PauseForBlockedUI()
    end
end)

Refresh()
