local addonName = ...

local DEFAULT_POSITION = {
    point = "BOTTOMLEFT",
    relativePoint = "BOTTOMLEFT",
    x = 14,
    y = 8,
}

-- La largeur suivait la plus large des sections, mais restait bornee : une
-- section qui deborde ne doit pas etirer le conteneur sur tout l'ecran.
local MIN_WIDTH = 200
local MAX_WIDTH = 520

local api = {}
local sections = {}
local rootFrame
local visibilityFrame
local pendingHideInCombat
local layoutScheduled = false
local layoutInProgress = false

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

local function GetBottomLeftPosition()
    if not rootFrame then
        return nil, nil
    end

    local left = rootFrame:GetLeft()
    local bottom = rootFrame:GetBottom()
    if not left or not bottom then
        return nil, nil
    end

    return left, bottom
end

local function SetBottomLeftPosition(x, y)
    rootFrame:ClearAllPoints()
    rootFrame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x, y)
end

local function SortSections(left, right)
    if left.order == right.order then
        return left.id < right.id
    end
    return left.order < right.order
end

--- Largeur souhaitee du conteneur, deduite de la plus large des sections.
local function ComputeWidth()
    local widest = MIN_WIDTH
    for _, section in ipairs(sections) do
        local frame = section.frame
        if frame and frame:IsShown() then
            local requested = tonumber(section.preferredWidth)
                or (frame.GetWidth and frame:GetWidth())
                or 0
            if requested > widest then
                widest = requested
            end
        end
    end
    return math.min(MAX_WIDTH, math.max(MIN_WIDTH, math.floor(widest + 0.5)))
end

local function Layout()
    if not rootFrame or layoutInProgress then
        return
    end

    -- Le redimensionnement des sections declenche OnSizeChanged, qui redemande
    -- un layout : sans ce verrou, la mise en page se rappellerait sans fin.
    layoutInProgress = true

    table.sort(sections, SortSections)

    local width = ComputeWidth()
    local totalHeight = 0
    local hasVisibleSection = false
    for _, section in ipairs(sections) do
        local frame = section.frame
        if frame and frame:IsShown() then
            totalHeight = totalHeight + math.max(1, frame:GetHeight())
            hasVisibleSection = true
        end
    end

    local height = math.max(1, totalHeight)
    rootFrame:SetWidth(width)
    rootFrame:SetHeight(height)
    rootFrame.bg:SetHeight(height)

    local offsetY = 0
    for _, section in ipairs(sections) do
        local frame = section.frame
        if frame and frame:IsShown() then
            frame:ClearAllPoints()
            frame:SetPoint("TOPLEFT", rootFrame, "TOPLEFT", 0, -offsetY)
            frame:SetPoint("TOPRIGHT", rootFrame, "TOPRIGHT", 0, -offsetY)
            offsetY = offsetY + math.max(1, frame:GetHeight())
        end
    end

    if hasVisibleSection then
        rootFrame:Show()
    else
        rootFrame:Hide()
    end

    layoutInProgress = false
end

--- Demande une mise en page, au plus une par frame de rendu.
--
-- Les sections modifiaient leur hauteur puis devaient penser a appeler
-- Refresh() : la convention n'etait pas toujours respectee et laissait des
-- sections superposees. Le layout est desormais declenche par OnSizeChanged, ce
-- qui impose de le regrouper pour ne pas le rejouer a chaque pixel.
local function RequestLayout()
    if layoutScheduled or layoutInProgress then
        return
    end
    if not (C_Timer and type(C_Timer.After) == "function") then
        Layout()
        return
    end
    layoutScheduled = true
    C_Timer.After(0, function()
        layoutScheduled = false
        Layout()
    end)
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
    rootFrame:SetSize(MIN_WIDTH, 1)
    rootFrame:SetClampedToScreen(true)
    rootFrame:SetMovable(true)
    rootFrame:EnableMouse(true)
    rootFrame:RegisterForDrag("LeftButton")
    rootFrame:SetScript("OnDragStart", rootFrame.StartMoving)
    rootFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local x, y = GetBottomLeftPosition()
        if x and y then
            SetBottomLeftPosition(x, y)
        end
        api:SavePosition()
    end)

    rootFrame.bg = rootFrame:CreateTexture(nil, "BACKGROUND")
    rootFrame.bg:SetAllPoints()
    rootFrame.bg:SetColorTexture(0, 0, 0, 0.55)

    api:ApplyPosition()
    api:ApplyScale()
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

    -- La section n'a plus a signaler ses changements de taille elle-meme.
    if not section.sizeHooked and frame.HookScript then
        frame:HookScript("OnSizeChanged", RequestLayout)
        frame:HookScript("OnShow", RequestLayout)
        frame:HookScript("OnHide", RequestLayout)
        section.sizeHooked = true
    end

    self:Refresh()
end

--- Declare la largeur souhaitee d'une section.
--
-- Sans cet appel, la largeur mesuree de la frame est utilisee.
function api:SetSectionWidth(id, width)
    for _, section in ipairs(sections) do
        if section.id == id then
            section.preferredWidth = tonumber(width)
            RequestLayout()
            return
        end
    end
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
    RequestLayout()
end

--- Mise en page immediate, sans attendre la fin de la frame de rendu.
function api:RefreshNow()
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
        local x, y = GetBottomLeftPosition()
        if x and y then
            SetBottomLeftPosition(x, y)
            db.point = "BOTTOMLEFT"
            db.relativePoint = "BOTTOMLEFT"
            db.x = math.floor(x + 0.5)
            db.y = math.floor(y + 0.5)
        end
        return
    end

    SetBottomLeftPosition(DEFAULT_POSITION.x, DEFAULT_POSITION.y)
end

function api:ResetPosition()
    local db = GetDB()
    db.point = nil
    db.relativePoint = nil
    db.x = nil
    db.y = nil
    self:ApplyPosition()
end

--- Applique l'echelle enregistree du conteneur.
function api:ApplyScale()
    self:EnsureFrame()
    local scale = tonumber(GetDB().scale)
    if not scale then
        return
    end
    rootFrame:SetScale(math.min(2.0, math.max(0.5, scale)))
end

--- Regle l'echelle du conteneur, bornee entre 50 % et 200 %.
function api:SetScale(scale)
    scale = tonumber(scale)
    if not scale then
        return
    end
    scale = math.min(2.0, math.max(0.5, scale))
    GetDB().scale = scale
    self:EnsureFrame()
    rootFrame:SetScale(scale)
end

function api:GetScale()
    return tonumber(GetDB().scale) or 1.0
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

SLASH_YAYAFRAME1 = "/yframe"
SlashCmdList.YAYAFRAME = function(message)
    local command, argument = (message or ""):lower():match("^(%S*)%s*(.*)$")
    if command == "scale" then
        local scale = tonumber(argument)
        if scale then
            api:SetScale(scale)
            print(("|cff00ff98YayaFrame:|r echelle %.2f"):format(api:GetScale()))
        else
            print(("|cff00ff98YayaFrame:|r echelle %.2f (usage : /yframe scale 0.5 a 2.0)"):format(api:GetScale()))
        end
    elseif command == "reset" then
        api:ResetPosition()
        print("|cff00ff98YayaFrame:|r position reinitialisee")
    else
        print("|cff00ff98YayaFrame:|r /yframe scale <0.5-2.0> | /yframe reset")
    end
end

YayaFrameAPI = api
