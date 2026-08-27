local addonName = ...

local OPTION_KEY = "autoOpenContainers"
-- Deux verdicts distincts, volontairement separes.
--
-- FORBIDDEN : l'ouverture automatique a declenche ADDON_ACTION_BLOCKED ou
-- ADDON_ACTION_FORBIDDEN. C'est un signal dur de Blizzard, propre au conteneur :
-- il ne s'ouvrira jamais depuis un timer addon et n'a pas a etre reessaye.
--
-- FAILED : refus transitoire (personnage indisponible, loot en retard, sacs
-- pleins). Ce verdict expire et ne doit jamais devenir definitif. Les deux
-- etaient auparavant confondus dans une seule table, alimentee par le timeout et
-- jamais par l'action bloquee, ce qui rendait la categorisation inutilisable.
local FORBIDDEN_CONTAINERS_KEY = "autoOpenForbidden"
local FAILED_CONTAINERS_KEY = "autoOpenFailed"
local LEGACY_REFUSED_CONTAINERS_KEY = "autoOpenRefusedContainers"
local SUCCESSFUL_CONTAINERS_KEY = "autoOpenSuccessfulContainers"
local CACHE_VERSION_KEY = "autoOpenCacheVersion"
local CACHE_VERSION = 2
local FAILED_TTL_SECONDS = 86400
local DEFAULT_OPEN_DELAY_SECONDS = 0.05
local SCAN_DELAY_SECONDS = 0.05
local INITIAL_SCAN_DELAY_SECONDS = 0.30
local MAIL_LOOT_IDLE_SECONDS = 0.50
local MAIL_ACTIVITY_EXTRA_DELAY_SECONDS = 0.05
local PENDING_CHECK_DELAY_SECONDS = 0.03
local PENDING_TIMEOUT_SECONDS = 1.20
local LOOT_SETTLE_SECONDS = 0.45
local CONTAINER_VALUES_MAX_WAIT_SECONDS = 1.35
local KNOWN_SUCCESS_RETRY_SECONDS = 90.00
local MAX_FAILURES = 3
local MANUAL_RESCAN_DELAY_SECONDS = 0.10
local BLOCKED_RETRY_SECONDS = 0.10
local MAX_BLOCKED_RETRY_SECONDS = 2.00

local state = {
    phase = "idle",
    queue = {},
    queueKeys = {},
    pending = nil,
    failureCounts = {},
    halted = false,
    manualFallback = nil,
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
    actionButton = nil,
    armedCandidate = nil,
    -- Refus au niveau d'un item, pour la session : remplace l'ancien drapeau
    -- global halted, qui figeait tout le module des le premier conteneur
    -- problematique rencontre dans l'ordre des sacs.
    skippedItems = {},
}
local OpenNextContainer
local ScheduleScan
local CheckPendingContainer

local eventFrame = CreateFrame("Frame", addonName .. "AutoOpenFrame")

local function EnsureOptions()
    YayaWeeklyTrackerAccountDB = type(YayaWeeklyTrackerAccountDB) == "table"
        and YayaWeeklyTrackerAccountDB
        or {}
    if YayaWeeklyTrackerAccountDB[OPTION_KEY] == nil then
        YayaWeeklyTrackerAccountDB[OPTION_KEY] = false
    end
    if type(YayaWeeklyTrackerAccountDB[FAILED_CONTAINERS_KEY]) ~= "table" then
        YayaWeeklyTrackerAccountDB[FAILED_CONTAINERS_KEY] = {}
    end
    if type(YayaWeeklyTrackerAccountDB[FORBIDDEN_CONTAINERS_KEY]) ~= "table" then
        YayaWeeklyTrackerAccountDB[FORBIDDEN_CONTAINERS_KEY] = {}
    end
    if type(YayaWeeklyTrackerAccountDB[SUCCESSFUL_CONTAINERS_KEY]) ~= "table" then
        YayaWeeklyTrackerAccountDB[SUCCESSFUL_CONTAINERS_KEY] = {}
    end

    YayaWeeklyTrackerAccountDB[LEGACY_REFUSED_CONTAINERS_KEY] = nil

    -- Les caches ecrits avant la separation des deux verdicts melangeaient les
    -- actions bloquees, les timeouts et les faux succes issus d'un simple
    -- deplacement en sac. Ils ne sont pas rattrapables : on les repart a neuf.
    if tonumber(YayaWeeklyTrackerAccountDB[CACHE_VERSION_KEY]) ~= CACHE_VERSION then
        YayaWeeklyTrackerAccountDB[CACHE_VERSION_KEY] = CACHE_VERSION
        YayaWeeklyTrackerAccountDB[FAILED_CONTAINERS_KEY] = {}
        YayaWeeklyTrackerAccountDB[SUCCESSFUL_CONTAINERS_KEY] = {}
    end

    -- Purge des refus transitoires perimes : ce verdict ne doit jamais durer.
    local failures = YayaWeeklyTrackerAccountDB[FAILED_CONTAINERS_KEY]
    local now = time and time() or 0
    for itemID, entry in pairs(failures) do
        if type(entry) ~= "table" or (tonumber(entry.expiresAt) or 0) <= now then
            failures[itemID] = nil
        end
    end

    return YayaWeeklyTrackerAccountDB
end

local function IsEnabled()
    return EnsureOptions()[OPTION_KEY] == true
end

local function Now()
    return GetTime and GetTime() or 0
end

-- Verdict dur : l'ouverture automatique est interdite par Blizzard pour ce
-- conteneur. Il reste suivi, mais uniquement via le bouton securise.
local function RecordContainerBlocked(itemID, blockedEvent, blockedFunctionName)
    if not itemID then
        return false
    end

    local accountDB = EnsureOptions()
    local forbidden = accountDB[FORBIDDEN_CONTAINERS_KEY]
    accountDB[FAILED_CONTAINERS_KEY][itemID] = nil
    local entry = forbidden[itemID]
    if type(entry) ~= "table" then
        entry = { itemID = itemID, blockedCount = 0 }
        forbidden[itemID] = entry
    end

    local timestamp = date and date("%Y-%m-%d %H:%M:%S") or tostring(math.floor(Now()))
    entry.itemID = itemID
    entry.blockedCount = (tonumber(entry.blockedCount) or 0) + 1
    entry.firstSeen = entry.firstSeen or timestamp
    entry.lastSeen = timestamp
    entry.lastEvent = blockedEvent and tostring(blockedEvent) or nil
    entry.lastFunction = blockedFunctionName and tostring(blockedFunctionName) or nil
    return true
end

local function IsContainerForbidden(itemID)
    if not itemID then
        return false
    end
    return type(EnsureOptions()[FORBIDDEN_CONTAINERS_KEY][itemID]) == "table"
end

local function IsContainerTransientlyRefused(itemID)
    if not itemID then
        return false
    end
    local entry = EnsureOptions()[FAILED_CONTAINERS_KEY][itemID]
    if type(entry) ~= "table" then
        return false
    end
    return (tonumber(entry.expiresAt) or 0) > (time and time() or 0)
end

-- Verdict mou : un refus qui expire. Il n'ecrase jamais un verdict dur et ne
-- devient jamais definitif.
local function RecordContainerRefusal(itemID, refusalKind, detail)
    if not itemID then
        return
    end

    local accountDB = EnsureOptions()
    local failures = accountDB[FAILED_CONTAINERS_KEY]
    if type(accountDB[FORBIDDEN_CONTAINERS_KEY][itemID]) == "table" then
        failures[itemID] = nil
        return false
    end
    local entry = failures[itemID]
    if type(entry) ~= "table" then
        entry = {
            itemID = itemID,
            refusalCount = 0,
            byKind = {},
        }
        failures[itemID] = entry
    end

    local kind = tostring(refusalKind or "unknown")
    local timestamp = date and date("%Y-%m-%d %H:%M:%S") or tostring(math.floor(Now()))
    entry.itemID = itemID
    entry.refusalCount = (tonumber(entry.refusalCount) or 0) + 1
    entry.byKind = type(entry.byKind) == "table" and entry.byKind or {}
    entry.byKind[kind] = (tonumber(entry.byKind[kind]) or 0) + 1
    entry.firstSeen = entry.firstSeen or timestamp
    entry.lastSeen = timestamp
    entry.lastKind = kind
    entry.lastDetail = detail and tostring(detail) or nil
    entry.expiresAt = (time and time() or 0) + FAILED_TTL_SECONDS
    return true
end

local function RecordContainerSuccess(itemID, successMode)
    if not itemID then
        return
    end

    local accountDB = EnsureOptions()
    local successes = accountDB[SUCCESSFUL_CONTAINERS_KEY]
    accountDB[FAILED_CONTAINERS_KEY][itemID] = nil
    local entry = successes[itemID]
    if type(entry) ~= "table" then
        entry = {
            itemID = itemID,
            successCount = 0,
        }
        successes[itemID] = entry
    end

    local timestamp = date and date("%Y-%m-%d %H:%M:%S") or tostring(math.floor(Now()))
    entry.itemID = itemID
    entry.successCount = (tonumber(entry.successCount) or 0) + 1
    entry.firstSeen = entry.firstSeen or timestamp
    entry.lastSeen = timestamp
    entry.lastMode = tostring(successMode or "unknown")
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

local function IsInRestrictedInstance()
    if IsInInstance then
        local inInstance, instanceType = IsInInstance()
        if inInstance or (type(instanceType) == "string" and instanceType ~= "none") then
            return true
        end
    end
    if GetInstanceInfo then
        local _, instanceType = GetInstanceInfo()
        if type(instanceType) == "string" and instanceType ~= "none" then
            return true
        end
    end
    return false
end

local function IsBlocked()
    if InCombatLockdown and InCombatLockdown() then
        return true
    end
    if IsInRestrictedInstance() then
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

-- La whitelist est declarative et compte pres de 300 IDs : elle contient des
-- objets qui ne s'ouvrent pas par clic (objets de test Blizzard, coffres a
-- crocheter). Un conteneur ouvrable expose toujours un effet d'utilisation, donc
-- un sort d'objet. On ne rejette que si la donnee est reellement chargee, sinon
-- on la demande et on laisse passer.
local function IsItemLikelyOpenable(bagID, slotID, itemID)
    local info = GetContainerInfo(bagID, slotID)

    -- Seul negatif certain : un coffre verrouille exige une cle ou du
    -- crochetage, aucun clic ne l'ouvrira.
    if info and info.isLocked == true then
        return false, "locked"
    end

    -- Positif certain, et independant du cache d'objets : Blizzard marque
    -- lui-meme l'emplacement comme contenant du butin.
    if info and info.hasLoot == true then
        return true, "has-loot"
    end

    if not (C_Item and type(C_Item.GetItemSpell) == "function") then
        return true, "no-api"
    end

    local cached = true
    if type(C_Item.IsItemDataCachedByID) == "function" then
        local ok, isCached = pcall(C_Item.IsItemDataCachedByID, itemID)
        cached = ok and isCached == true
    end
    if not cached then
        if type(C_Item.RequestLoadItemDataByID) == "function" then
            pcall(C_Item.RequestLoadItemDataByID, itemID)
        end
        return true, "pending-data"
    end

    local ok, spellName, spellID = pcall(C_Item.GetItemSpell, itemID)
    if ok and (spellName ~= nil or spellID ~= nil) then
        return true, "usable"
    end

    -- Rejet uniquement quand les trois signaux manquent a la fois : ni butin
    -- annonce, ni effet d'utilisation, sur une donnee bien chargee. Le cout d'un
    -- faux rejet est un conteneur qui ne s'ouvre plus jamais, en silence, alors
    -- qu'un faux positif ne coute qu'une tentative bloquee, apres quoi l'objet
    -- part dans autoOpenForbidden et passe par le bouton securise.
    return false, "no-loot-no-use-effect"
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
        -- manualOnly : ce conteneur ne doit pas etre tente automatiquement, mais
        -- reste propose via le bouton securise.
        manualOnly = IsContainerForbidden(itemID)
            or state.skippedItems[itemID] == true
            or IsContainerTransientlyRefused(itemID),
    }
end

local function GetActionButton()
    local api = _G.YayaWeeklyTrackerAutoOpen
    if not api or type(api.GetActionButton) ~= "function" then
        return nil
    end
    local ok, button = pcall(api.GetActionButton)
    return ok and button or nil
end

local function RequestTrackerRefresh()
    local api = _G.YayaWeeklyTrackerAutoOpen
    if api and type(api.RequestTrackerRefresh) == "function" then
        pcall(api.RequestTrackerRefresh)
    end
end

local function UpdateActionButton(candidate)
    local button = GetActionButton()
    if not button then
        return false
    end

    if state.actionButton ~= button then
        state.actionButton = button
        button:HookScript("PreClick", function(self, _, down)
            if down then
                return
            end

            local queued = state.armedCandidate
            if not queued or not IsEnabled() or IsBlocked() then
                return
            end

            local currentItemID, currentSlotCount = ReadSlot(queued.bagID, queued.slotID)
            if currentItemID ~= queued.itemID or currentSlotCount <= 0 then
                if queued.manualFallback then
                    state.manualFallback = nil
                    state.halted = false
                end
                state.armedCandidate = nil
                UpdateActionButton(nil)
                ScheduleScan(0)
                return
            end

            state.pending = {
                bagID = queued.bagID,
                slotID = queued.slotID,
                itemID = queued.itemID,
                beforeSlotCount = currentSlotCount,
                beforeTotalCount = CountItem(queued.itemID),
                startedAt = Now(),
                pausedSeconds = 0,
                candidate = queued,
                manualFallback = queued.manualFallback == true,
            }
            state.armedCandidate = nil
            state.phase = "opening"
            Log(("ouverture securisee itemID=%d bag=%d slot=%d"):format(
                queued.itemID,
                queued.bagID,
                queued.slotID
            ))
        end)
        button:HookScript("PostClick", function(_, _, down)
            if down then
                return
            end
            if state.pending then
                UpdateActionButton(nil)
                state.phase = "loot pending"
                Schedule("pendingTimer", PENDING_CHECK_DELAY_SECONDS, CheckPendingContainer)
            else
                ScheduleScan(SCAN_DELAY_SECONDS)
            end
        end)
    end

    -- Show et Hide appartiennent desormais a UpdateTracker : lui seul connait la
    -- pile de boutons et peut ancrer celui-ci avant de l'afficher. Le module
    -- montrait le bouton puis demandait un rafraichissement, si bien qu'il
    -- apparaissait une frame sans ancrage, etait positionne a la frame suivante,
    -- puis re-empile par YayaFrame a la frame d'apres.
    if not candidate or not IsEnabled() or IsBlocked()
        or (InCombatLockdown and InCombatLockdown()) then
        local wasArmed = state.armedCandidate ~= nil
        state.armedCandidate = nil
        button:SetEnabled(false)
        if not (InCombatLockdown and InCombatLockdown()) then
            button:SetAttribute("type", nil)
            button:SetAttribute("item", nil)
        end
        if wasArmed then
            RequestTrackerRefresh()
        end
        return false
    end

    local previous = state.armedCandidate
    local unchanged = previous ~= nil
        and previous.itemID == candidate.itemID
        and previous.bagID == candidate.bagID
        and previous.slotID == candidate.slotID
        and previous.totalCount == candidate.totalCount

    state.armedCandidate = candidate
    if not button.itemActionLocked then
        button:SetEnabled(true)
    end
    button.itemID = candidate.itemID
    button.itemLink = candidate.itemLink
    button:SetText(("Ouvrir conteneur x%d"):format(candidate.totalCount or 1))
    button:SetAttribute("type", "item")
    button:SetAttribute("item", "item:" .. tostring(candidate.itemID))
    -- Un rafraichissement declenche UpdateTracker puis une remise en page
    -- complete de YayaFrame : inutile quand rien n'a change a l'affichage.
    if not unchanged then
        RequestTrackerRefresh()
    end
    return true
end

-- Arme le bouton securise pour un conteneur donne, sans arreter le module.
--
-- L'ancienne version posait state.halted, ce qui coupait ScheduleScan : le
-- premier conteneur problematique dans l'ordre des sacs bloquait definitivement
-- tous les suivants. Desormais le refus est porte par l'item, et le scan
-- continue pour les autres candidats.
local function ArmManualCandidate(candidate, reason, skipItem)
    if not candidate then
        return
    end

    local alreadyArmed = state.manualFallback ~= nil
        and state.manualFallback.itemID == candidate.itemID
        and state.manualFallback.bagID == candidate.bagID
        and state.manualFallback.slotID == candidate.slotID

    candidate.manualFallback = true
    candidate.manualOnly = true
    state.manualFallback = candidate
    if skipItem ~= false and candidate.itemID then
        state.skippedItems[candidate.itemID] = true
    end
    state.pending = nil
    state.phase = "bouton manuel"
    UpdateActionButton(candidate)
    -- Ne journaliser qu'un changement reel : ce message partait aussi dans le
    -- chat, donc le rearmement du meme conteneur le spammait.
    if reason and not alreadyArmed then
        Log(reason)
    end
    -- Pas de ScheduleScan ici : l'etat est terminal jusqu'a un changement de sac.
    -- Reprogrammer un scan relancait immediatement le meme cycle.
end

local function MarkProtectedActionBlocked(blockedEvent, blockedFunctionName)
    local pending = state.pending
    if not pending or pending.protectedActionBlocked then
        return
    end

    pending.protectedActionBlocked = true
    pending.protectedActionEvent = blockedEvent
    pending.protectedFunctionName = blockedFunctionName
    -- Signal dur : ce conteneur n'est pas ouvrable depuis un timer addon. Il est
    -- memorise pour de bon afin de ne plus jamais etre tente automatiquement,
    -- contrairement a un refus transitoire.
    RecordContainerBlocked(pending.itemID, blockedEvent, blockedFunctionName)
    Log(("action Blizzard bloquee: %s (%s), itemID=%d passe en ouverture manuelle uniquement"):format(
        tostring(blockedFunctionName or "fonction inconnue"),
        tostring(blockedEvent or "evenement inconnu"),
        tonumber(pending.itemID) or 0
    ))
    Schedule("pendingTimer", 0, CheckPendingContainer)
end

-- Echec sans action bloquee : personnage indisponible, loot en retard, sacs
-- pleins. Verdict transitoire uniquement. Apres MAX_FAILURES dans la session,
-- l'item bascule sur le bouton securise, mais le scan des autres continue.
local function HandleAutomaticFailure(candidate, refusalKind, reason, detail)
    local itemID = candidate.itemID
    local failures = (state.failureCounts[itemID] or 0) + 1
    state.failureCounts[itemID] = failures

    if failures >= MAX_FAILURES then
        RecordContainerRefusal(itemID, refusalKind, detail)
        ArmManualCandidate(candidate, ("%s itemID=%d (%d/%d), bouton manuel affiche"):format(
            reason,
            itemID,
            failures,
            MAX_FAILURES
        ))
        return
    end

    state.phase = "retry"
    Log(("%s itemID=%d (%d/%d), nouvelle tentative"):format(
        reason,
        itemID,
        failures,
        MAX_FAILURES
    ))
    ScheduleScan(SCAN_DELAY_SECONDS)
end

local function ScanBags()
    state.scanTimer = nil
    if not IsEnabled() then
        StopTimers()
        ClearQueue()
        state.pending = nil
        UpdateActionButton(nil)
        state.phase = "idle"
        state.halted = false
        state.wasEnabled = false
        return
    end
    if IsBlocked() then
        if state.reportNextScan then
            Log("scan suspendu: combat, instance, cast ou interface sensible")
        end
        UpdateActionButton(nil)
        state.phase = "paused"
        return
    end
    if state.pending then
        UpdateActionButton(nil)
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
                    local openable, openableReason = IsItemLikelyOpenable(bagID, slotID, itemID)
                    if openable then
                        QueueCandidate(bagID, slotID, itemID)
                    elseif state.reportNextScan then
                        Log(("ignore itemID=%d: %s"):format(itemID, tostring(openableReason)))
                    end
                end
            end
        end
    end

    if #state.queue == 0 then
        UpdateActionButton(nil)
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
    if not IsEnabled() or state.pending then
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
    state.failureCounts = {}
    state.skippedItems = {}
    state.manualFallback = nil
    state.halted = halt == true
    state.mailSettleUntil = 0
    UpdateActionButton(nil)
    if reason then
        Log(reason)
    end
end

CheckPendingContainer = function()
    StopTimer("pendingTimer")
    local pending = state.pending
    if not pending then
        return
    end
    if not IsEnabled() then
        StopAutoOpen()
        return
    end
    if pending.protectedActionBlocked then
        local candidate = pending.candidate or {
            bagID = pending.bagID,
            slotID = pending.slotID,
            itemID = pending.itemID,
        }
        state.pending = nil
        state.failureCounts[pending.itemID] = nil
        ArmManualCandidate(
            candidate,
            ("itemID=%d reserve au bouton securise: ouverture automatique interdite par Blizzard"):format(
                pending.itemID
            )
        )
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
    -- La condition d'origine concluait a une ouverture des que l'objet avait
    -- quitte son emplacement : un simple tri de sac, un regroupement de pile ou
    -- un craft suffisait a marquer le conteneur ouvrable pour toujours. On exige
    -- desormais que le total detenu baisse, et qu'un evenement de sac ou de loot
    -- ait effectivement ete observe. Les depots banque, courrier, marchand et
    -- echange sont deja couverts par IsBlocked, qui met le suivi en pause.
    local totalDropped = currentTotal < pending.beforeTotalCount
    local activitySeen = pending.lootSeen == true or pending.bagUpdateSeen == true
    local consumed = totalDropped and activitySeen
    if not consumed and totalDropped and elapsed >= PENDING_TIMEOUT_SECONDS then
        -- Filet : le total a baisse mais aucun evenement n'a ete vu dans la
        -- fenetre. On accepte plutot que de compter un echec a tort.
        consumed = true
    end
    if currentItemID ~= pending.itemID and currentSlotCount <= 0 and not totalDropped then
        -- L'objet a change d'emplacement sans etre consomme : on relance un scan
        -- propre au lieu de conclure quoi que ce soit.
        state.pending = nil
        state.phase = "candidate"
        ScheduleScan(SCAN_DELAY_SECONDS)
        return
    end

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
        RecordContainerSuccess(pending.itemID, pending.manualFallback and "secure_button" or "automatic")
        state.failureCounts[pending.itemID] = nil
        -- Une ouverture reussie annule le refus transitoire de session : seul le
        -- verdict dur ADDON_ACTION_FORBIDDEN survit.
        if not IsContainerForbidden(pending.itemID) then
            state.skippedItems[pending.itemID] = nil
        end
        if state.manualFallback and state.manualFallback.itemID == pending.itemID then
            state.manualFallback = nil
        end
        ScheduleScan(DEFAULT_OPEN_DELAY_SECONDS)
        return
    end

    if elapsed < PENDING_TIMEOUT_SECONDS then
        Schedule("pendingTimer", PENDING_CHECK_DELAY_SECONDS, CheckPendingContainer)
        return
    end

    state.pending = nil
    if pending.manualFallback then
        -- Un clic joueur qui ne consomme rien n'est pas un verdict sur l'objet :
        -- le bouton reste en place sans nouvelle inscription.
        ArmManualCandidate(
            pending.candidate,
            ("ouverture manuelle non confirmee itemID=%d, bouton conserve"):format(pending.itemID),
            false
        )
    else
        HandleAutomaticFailure(pending.candidate or {
            bagID = pending.bagID,
            slotID = pending.slotID,
            itemID = pending.itemID,
        }, "not_consumed", "echec ouverture automatique")
    end
end

local function DropQueueEntry(index, candidate)
    table.remove(state.queue, index)
    state.queueKeys[("%d:%d:%d"):format(candidate.bagID, candidate.slotID, candidate.itemID)] = nil
end

OpenNextContainer = function()
    state.openTimer = nil
    if not IsEnabled() then
        StopAutoOpen()
        return
    end
    if IsBlocked() or state.pending then
        state.phase = "paused"
        return
    end

    -- La queue est triee par bag puis slot. On la parcourt au lieu de ne
    -- regarder que queue[1] : un conteneur reserve au bouton securise ne doit
    -- pas empecher l'ouverture automatique de tous ceux qui le suivent.
    local manualIndex, manualCandidate
    local index = 1
    while index <= #state.queue do
        local candidate = state.queue[index]
        local currentItemID, currentSlotCount = ReadSlot(candidate.bagID, candidate.slotID)
        if currentItemID ~= candidate.itemID or currentSlotCount <= 0 then
            DropQueueEntry(index, candidate)
        elseif candidate.manualOnly then
            if not manualCandidate then
                manualIndex, manualCandidate = index, candidate
            end
            index = index + 1
        else
            candidate.totalCount = CountItem(candidate.itemID)
            DropQueueEntry(index, candidate)
            state.pending = {
                bagID = candidate.bagID,
                slotID = candidate.slotID,
                itemID = candidate.itemID,
                beforeSlotCount = currentSlotCount,
                beforeTotalCount = candidate.totalCount,
                startedAt = Now(),
                pausedSeconds = 0,
                candidate = candidate,
                manualFallback = false,
            }
            state.phase = "ouverture automatique"
            Log(("tentative ouverture automatique itemID=%d bag=%d slot=%d"):format(
                candidate.itemID,
                candidate.bagID,
                candidate.slotID
            ))
            UpdateActionButton(nil)
            if C_Container and type(C_Container.UseContainerItem) == "function" then
                pcall(C_Container.UseContainerItem, candidate.bagID, candidate.slotID)
            end
            Schedule("pendingTimer", PENDING_CHECK_DELAY_SECONDS, CheckPendingContainer)
            return
        end
    end

    if manualCandidate then
        manualCandidate.totalCount = CountItem(manualCandidate.itemID)
        DropQueueEntry(manualIndex, manualCandidate)
        -- skipItem = false : l'item est deja marque, soit par un verdict
        -- persistant, soit par la session. Inutile de le reinscrire.
        ArmManualCandidate(
            manualCandidate,
            ("ouverture manuelle requise itemID=%d, bouton securise affiche"):format(manualCandidate.itemID),
            false
        )
        return
    end

    UpdateActionButton(nil)
    state.phase = "idle"
end

local function PauseForBlockedUI()
    StopTimer("scanTimer")
    StopTimer("openTimer")
    StopTimer("pendingTimer")
    StopTimer("resumeTimer")
    if state.pending then
        state.pending.pausedAt = state.pending.pausedAt or Now()
    end
    UpdateActionButton(nil)
    state.phase = "paused"
end

local function ResumeAfterBlockedUI(startedAt)
    if not IsEnabled() then
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
        if state.manualFallback then
            UpdateActionButton(state.manualFallback)
        end
        ScheduleScan(SCAN_DELAY_SECONDS)
    end
end

local function Refresh()
    EnsureOptions()
    local enabled = IsEnabled()
    local optionsChanged = state.lastEnabled ~= enabled
    state.lastEnabled = enabled

    if optionsChanged then
        state.failureCounts = {}
        state.skippedItems = {}
        state.manualFallback = nil
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
        state.failureCounts = {}
        state.skippedItems = {}
        state.manualFallback = nil
        state.halted = false
    end
    state.wasEnabled = true
    state.reportNextScan = true
    RefreshConfiguredItems()
    StopTimer("scanTimer")
    if not state.pending then
        ScheduleScan(SCAN_DELAY_SECONDS)
    end
end

_G.YayaWeeklyTrackerAutoOpen = _G.YayaWeeklyTrackerAutoOpen or {}
_G.YayaWeeklyTrackerAutoOpen.Refresh = Refresh
_G.YayaWeeklyTrackerAutoOpen.GetRefusedContainers = function()
    return EnsureOptions()[FAILED_CONTAINERS_KEY]
end
_G.YayaWeeklyTrackerAutoOpen.GetFailedContainers = _G.YayaWeeklyTrackerAutoOpen.GetRefusedContainers
_G.YayaWeeklyTrackerAutoOpen.GetSuccessfulContainers = function()
    return EnsureOptions()[SUCCESSFUL_CONTAINERS_KEY]
end
_G.YayaWeeklyTrackerAutoOpen.GetForbiddenContainers = function()
    return EnsureOptions()[FORBIDDEN_CONTAINERS_KEY]
end
-- Purge des verdicts. Sans ce point d'entree, un cache pollue restait definitif :
-- un faux succes rendait l'objet inclassable et rien ne permettait de repartir.
_G.YayaWeeklyTrackerAutoOpen.ResetContainerCaches = function(includeForbidden)
    local accountDB = EnsureOptions()
    accountDB[FAILED_CONTAINERS_KEY] = {}
    accountDB[SUCCESSFUL_CONTAINERS_KEY] = {}
    if includeForbidden then
        accountDB[FORBIDDEN_CONTAINERS_KEY] = {}
    end
    state.failureCounts = {}
    state.skippedItems = {}
    state.manualFallback = nil
    state.halted = false
    ScheduleScan(SCAN_DELAY_SECONDS)
    return true
end
-- Seul armedCandidate compte : c'est l'objet reellement pose sur l'attribut
-- securise. manualFallback survit a un blocage (combat, banque, courrier) alors
-- que les attributs ont ete retires, et afficherait un bouton mort.
_G.YayaWeeklyTrackerAutoOpen.GetPendingCandidate = function()
    return state.armedCandidate or nil
end

eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
pcall(eventFrame.RegisterEvent, eventFrame, "ZONE_CHANGED")
pcall(eventFrame.RegisterEvent, eventFrame, "ZONE_CHANGED_INDOORS")
eventFrame:RegisterEvent("BAG_UPDATE")
eventFrame:RegisterEvent("BAG_UPDATE_DELAYED")
pcall(eventFrame.RegisterEvent, eventFrame, "LOOT_READY")
pcall(eventFrame.RegisterEvent, eventFrame, "LOOT_OPENED")
pcall(eventFrame.RegisterEvent, eventFrame, "CHAT_MSG_LOOT")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:RegisterEvent("ADDON_ACTION_BLOCKED")
eventFrame:RegisterEvent("ADDON_ACTION_FORBIDDEN")
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

eventFrame:SetScript("OnEvent", function(_, event, ...)
    local unit = ...
    if event:match("^UNIT_SPELLCAST") and unit ~= "player" then
        return
    end
    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        EnsureMailHooks()
        Refresh()
        if IsEnabled() then
            ScheduleScan(INITIAL_SCAN_DELAY_SECONDS)
        end
    elseif event == "ZONE_CHANGED_NEW_AREA"
        or event == "ZONE_CHANGED"
        or event == "ZONE_CHANGED_INDOORS" then
        if IsBlocked() then
            PauseForBlockedUI()
        else
            ResumeAfterBlockedUI()
        end
    elseif event == "ADDON_ACTION_BLOCKED" or event == "ADDON_ACTION_FORBIDDEN" then
        local blockedAddonName, blockedFunctionName = ...
        if blockedAddonName == addonName then
            MarkProtectedActionBlocked(event, blockedFunctionName)
        end
    elseif event == "LOOT_READY" or event == "LOOT_OPENED" or event == "CHAT_MSG_LOOT" then
        if state.pending then
            state.pending.lootSeen = true
        end
    elseif event == "BAG_UPDATE" then
        if state.pending then
            state.pending.bagUpdateSeen = true
        end
    elseif event == "BAG_UPDATE_DELAYED" then
        if state.pending then
            CheckPendingContainer()
        elseif not IsBlocked() then
            local candidate = state.manualFallback
            if candidate then
                local currentItemID, currentSlotCount = ReadSlot(candidate.bagID, candidate.slotID)
                if currentItemID == candidate.itemID and currentSlotCount > 0 then
                    candidate.totalCount = CountItem(candidate.itemID)
                    UpdateActionButton(candidate)
                    -- Le bouton reste arme, mais un conteneur ouvrable a pu
                    -- arriver entre-temps : c'est le seul moment ou un nouveau
                    -- scan est justifie.
                    ScheduleScan(MANUAL_RESCAN_DELAY_SECONDS)
                else
                    state.manualFallback = nil
                    UpdateActionButton(nil)
                    ScheduleScan(SCAN_DELAY_SECONDS)
                end
            else
                ScheduleScan(SCAN_DELAY_SECONDS)
            end
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
    elseif event == "PLAYER_REGEN_DISABLED"
        or event == "MERCHANT_SHOW"
        or event == "UNIT_SPELLCAST_START"
        or event == "UNIT_SPELLCAST_CHANNEL_START"
        or event == "BANKFRAME_OPENED"
        or event == "TRADE_SHOW"
    then
        PauseForBlockedUI()
    end
end)

Refresh()
