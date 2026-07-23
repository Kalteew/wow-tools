local addonName = ...

local eventFrame = CreateFrame("Frame")
local state = {
    applied = false,
    originalIsBagSlotLocked = nil,
    originalStartSending = nil,
}

local function GetUpvalueByName(func, targetName)
    if type(func) ~= "function" or type(debug) ~= "table" or type(debug.getupvalue) ~= "function" then
        return nil
    end

    local index = 1
    while true do
        local name, value = debug.getupvalue(func, index)
        if not name then
            return nil
        end
        if name == targetName then
            return value
        end
        index = index + 1
    end
end

local function RefreshTSMBags(bagTracking, container)
    local trackingPrivate = GetUpvalueByName(bagTracking.CreateQueryBags, "private")
    if not trackingPrivate
        or type(trackingPrivate.BagUpdateHandler) ~= "function"
        or type(trackingPrivate.BagUpdateDelayedHandler) ~= "function"
        or type(container.GetNumBags) ~= "function" then
        return
    end

    for bag = 0, container.GetNumBags() do
        trackingPrivate.BagUpdateHandler(nil, bag)
    end
    trackingPrivate.BagUpdateDelayedHandler()
end

local function TryApplyPatch()
    if state.applied or type(TSM_API) ~= "table" or type(TSM_API.MailSelectedGroups) ~= "function" then
        return state.applied
    end

    local tsm = GetUpvalueByName(TSM_API.MailSelectedGroups, "TSM")
    local mailingGroups = tsm and tsm.Mailing and tsm.Mailing.Groups or nil
    local container = tsm and tsm.LibTSMWoW and tsm.LibTSMWoW:Include("API.Container") or nil
    local bagTracking = tsm and tsm.LibTSMService and tsm.LibTSMService:Include("Inventory.BagTracking") or nil
    if not mailingGroups
        or type(mailingGroups.StartSending) ~= "function"
        or not container
        or type(container.IsBagSlotLocked) ~= "function"
        or not bagTracking
        or type(bagTracking.CreateQueryBags) ~= "function" then
        return false
    end

    state.originalIsBagSlotLocked = container.IsBagSlotLocked
    state.originalStartSending = mailingGroups.StartSending

    container.IsBagSlotLocked = function(bag, slot)
        local info = C_Container and C_Container.GetContainerItemInfo
            and C_Container.GetContainerItemInfo(bag, slot) or nil
        if info and info.isLocked ~= nil then
            return info.isLocked and true or false
        end
        return state.originalIsBagSlotLocked(bag, slot)
    end

    mailingGroups.StartSending = function(callback, groupList, sendRepeat, isDryRun)
        pcall(RefreshTSMBags, bagTracking, container)
        return state.originalStartSending(callback, groupList, sendRepeat, isDryRun)
    end

    state.applied = true
    return true
end

eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", function(_, event, loadedAddon)
    if event == "ADDON_LOADED" and loadedAddon ~= "TradeSkillMaster" and loadedAddon ~= addonName then
        return
    end

    if not TryApplyPatch() and C_Timer and C_Timer.After then
        C_Timer.After(1, TryApplyPatch)
    end
end)
