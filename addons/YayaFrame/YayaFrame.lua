local addonName = ...

local DEFAULT_POSITION = {
    point = "TOPLEFT",
    relativePoint = "TOPRIGHT",
    x = 14,
    y = -8,
}

local api = {}
local sections = {}
local rootFrame
local visibilityFrame
local pendingHideInCombat

local function GetDB()
    YayaFrameDB = YayaFrameDB or {}
    return YayaFrameDB
end

local function HasSavedPosition(db)
    return db and db.point and db.relativePoint and db.x and db.y
end

local function CopyLegacyPosition(target, source)
    if not HasSavedPosition(source) then
        return false
    end

    target.point = source.point
    target.relativePoint = source.relativePoint
    target.x = source.x
    target.y = source.y
    return true
end

local function SortSections(left, right)
    if left.order == right.order then
        return left.id < right.id
    end
    return left.order < right.order
end

local function Layout()
    if not rootFrame then
        return
    end

    table.sort(sections, SortSections)

    local offsetY = 0
    local hasVisibleSection = false
    for _, section in ipairs(sections) do
        local frame = section.frame
        if frame and frame:IsShown() then
            frame:ClearAllPoints()
            frame:SetPoint("TOPLEFT", rootFrame, "TOPLEFT", 0, -offsetY)
            frame:SetPoint("TOPRIGHT", rootFrame, "TOPRIGHT", 0, -offsetY)
            offsetY = offsetY + math.max(1, frame:GetHeight())
            hasVisibleSection = true
        end
    end

    rootFrame:SetHeight(math.max(1, offsetY))
    rootFrame.bg:SetHeight(math.max(1, offsetY))
    if hasVisibleSection then
        rootFrame:Show()
    else
        rootFrame:Hide()
    end
end

local function CreateFrames()
    if rootFrame then
        return
    end

    visibilityFrame = CreateFrame("Frame", addonName .. "VisibilityFrame", UIParent, "SecureHandlerStateTemplate")
    visibilityFrame:SetAllPoints(UIParent)
    visibilityFrame:Show()

    rootFrame = CreateFrame("Frame", addonName .. "Frame", visibilityFrame)
    rootFrame:SetFrameStrata("MEDIUM")
    rootFrame:SetSize(200, 1)
    rootFrame:SetClampedToScreen(true)
    rootFrame:SetMovable(true)
    rootFrame:EnableMouse(true)
    rootFrame:RegisterForDrag("LeftButton")
    rootFrame:SetScript("OnDragStart", rootFrame.StartMoving)
    rootFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        api:SavePosition()
    end)

    rootFrame.bg = rootFrame:CreateTexture(nil, "BACKGROUND")
    rootFrame.bg:SetAllPoints()
    rootFrame.bg:SetColorTexture(0, 0, 0, 0.55)

    api:ApplyPosition()
    api:SetHideInCombat(GetDB().hideInCombat == true)
end

function api:EnsureFrame()
    CreateFrames()
    return rootFrame
end

function api:GetFrame()
    return self:EnsureFrame()
end

function api:GetVisibilityFrame()
    self:EnsureFrame()
    return visibilityFrame
end

function api:RegisterSection(id, order)
    if not id then
        return
    end

    for _, section in ipairs(sections) do
        if section.id == id then
            section.order = order or section.order
            return section
        end
    end

    local section = { id = id, order = order or 100 }
    sections[#sections + 1] = section
    return section
end

function api:AttachSection(id, frame, order)
    if not frame then
        return
    end

    local section = self:RegisterSection(id, order)
    section.frame = frame
    frame:SetParent(self:GetFrame())
    self:Refresh()
end

function api:DetachSection(id)
    for index, section in ipairs(sections) do
        if section.id == id then
            if section.frame then
                section.frame:Hide()
                section.frame:SetParent(UIParent)
            end
            table.remove(sections, index)
            break
        end
    end
    self:Refresh()
end

function api:Refresh()
    Layout()
end

function api:SavePosition()
    if not rootFrame then
        return
    end

    local point, _, relativePoint, x, y = rootFrame:GetPoint(1)
    local db = GetDB()
    db.point = point
    db.relativePoint = relativePoint
    db.x = math.floor((x or 0) + 0.5)
    db.y = math.floor((y or 0) + 0.5)
end

function api:ApplyPosition()
    self:EnsureFrame()

    local db = GetDB()
    if not db.positionInitialized then
        local migrated = CopyLegacyPosition(db, YayaWeeklyTrackerAccountDB)
        if not migrated then
            migrated = CopyLegacyPosition(db, YayaWeeklyTrackerDB)
        end
        if not migrated then
            CopyLegacyPosition(db, YayaSessionTrackerDB and YayaSessionTrackerDB.settings and YayaSessionTrackerDB.settings.position)
        end
        db.positionInitialized = true
    end

    rootFrame:ClearAllPoints()
    if HasSavedPosition(db) then
        rootFrame:SetPoint(db.point, UIParent, db.relativePoint, db.x, db.y)
        return
    end

    local anchor = PlayerFrame or UIParent
    rootFrame:SetPoint(DEFAULT_POSITION.point, anchor, DEFAULT_POSITION.relativePoint, DEFAULT_POSITION.x, DEFAULT_POSITION.y)
end

function api:ResetPosition()
    local db = GetDB()
    db.point = nil
    db.relativePoint = nil
    db.x = nil
    db.y = nil
    self:ApplyPosition()
end

function api:SetHideInCombat(enabled)
    self:EnsureFrame()
    if InCombatLockdown and InCombatLockdown() then
        pendingHideInCombat = enabled and true or false
        return
    end

    pendingHideInCombat = nil
    GetDB().hideInCombat = enabled and true or false
    if GetDB().hideInCombat then
        RegisterStateDriver(visibilityFrame, "visibility", "[combat] hide; show")
    else
        UnregisterStateDriver(visibilityFrame, "visibility")
        visibilityFrame:Show()
    end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        CreateFrames()
        Layout()
    elseif pendingHideInCombat ~= nil then
        api:SetHideInCombat(pendingHideInCombat)
    end
end)

YayaFrameAPI = api
