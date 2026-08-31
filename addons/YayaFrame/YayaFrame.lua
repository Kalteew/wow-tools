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

-- YayaCore.UI porte les tokens partages de la suite. L'acces est defensif :
-- si UI.lua disparaissait du TOC, le conteneur doit degrader vers son ancien
-- aplat plutot que cesser de charger.
local UI = _G.YayaCore and _G.YayaCore.UI
local GUTTER = UI and UI.PAD.sm or 4
local HEADER_HEIGHT = UI and UI.SIZE.headerH or 22
local SECTION_HEADER_HEIGHT = UI and UI.SIZE.rowHCompact or 16
local DIVIDER_HEIGHT = UI and UI.SIZE.divider or 1

local api = {}
local sections = {}
local rootFrame
local visibilityFrame
local headerFrame
local lockButton
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

--- Etat de repli des sections, indexe par identifiant.
local function GetCollapsedStore()
    local db = GetDB()
    db.collapsed = db.collapsed or {}
    return db.collapsed
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
    local widest = 0
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
    -- La largeur demandee est celle du contenu : le conteneur y ajoute ses deux
    -- gouttieres, puis borne le tout.
    return math.min(MAX_WIDTH, math.max(MIN_WIDTH, math.floor(widest + 2 * GUTTER + 0.5)))
end

--- Chrome d'une section : bandeau de titre repliable et separateur.
--
-- YayaFrame ne dessine que l'en-tete et le chevron. Replier previent la section
-- via son rappel : c'est elle qui masque son contenu et ramene sa hauteur. Le
-- conteneur ne se bat donc jamais avec le Show/Hide que le tracker
-- hebdomadaire applique deja a sa propre frame.
local function EnsureSectionChrome(section)
    if section.header or not (UI and rootFrame) then
        return section.header
    end

    section.header = UI.CreateHeader(rootFrame, section.title or section.id, {
        anchor = false,
        height = SECTION_HEADER_HEIGHT,
        titleColor = UI.COLOR.category,
        ruleColor = UI.COLOR.divider,
        collapsible = true,
        collapsed = GetCollapsedStore()[section.id] == true,
        onClick = function()
            api:ToggleSection(section.id)
        end,
    })
    section.divider = UI.CreateDivider(rootFrame)
    return section.header
end

local function Layout()
    if not rootFrame or layoutInProgress then
        return
    end

    -- Le redimensionnement des sections declenche OnSizeChanged, qui redemande
    -- un layout : sans ce verrou, la mise en page se rappellerait sans fin.
    layoutInProgress = true

    table.sort(sections, SortSections)

    rootFrame:SetWidth(ComputeWidth())

    local collapsedStore = GetCollapsedStore()
    local offsetY = headerFrame and HEADER_HEIGHT or 0
    local shownCount = 0

    for _, section in ipairs(sections) do
        local frame = section.frame
        if frame and frame:IsShown() then
            shownCount = shownCount + 1
            local header = EnsureSectionChrome(section)

            -- Un filet separe deux sections consecutives ; la premiere n'en a
            -- pas besoin, l'en-tete du conteneur la borne deja.
            if section.divider then
                if shownCount > 1 then
                    section.divider:ClearAllPoints()
                    section.divider:SetPoint("TOPLEFT", rootFrame, "TOPLEFT", GUTTER, -offsetY)
                    section.divider:SetPoint("TOPRIGHT", rootFrame, "TOPRIGHT", -GUTTER, -offsetY)
                    section.divider:Show()
                    offsetY = offsetY + DIVIDER_HEIGHT
                else
                    section.divider:Hide()
                end
            end

            if header then
                header.SetCollapsed(collapsedStore[section.id] == true)
                header:ClearAllPoints()
                header:SetPoint("TOPLEFT", rootFrame, "TOPLEFT", 0, -offsetY)
                header:SetPoint("TOPRIGHT", rootFrame, "TOPRIGHT", 0, -offsetY)
                header:Show()
                offsetY = offsetY + SECTION_HEADER_HEIGHT
            end

            frame:ClearAllPoints()
            frame:SetPoint("TOPLEFT", rootFrame, "TOPLEFT", GUTTER, -offsetY)
            frame:SetPoint("TOPRIGHT", rootFrame, "TOPRIGHT", -GUTTER, -offsetY)
            offsetY = offsetY + math.max(1, frame:GetHeight())
        elseif section.header then
            section.header:Hide()
            if section.divider then
                section.divider:Hide()
            end
        end
    end

    local height = math.max(1, offsetY)
    rootFrame:SetHeight(height)
    if rootFrame.bg then
        rootFrame.bg:SetHeight(height)
    end

    if shownCount > 0 then
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

--- Repose la frame sur son coin bas-gauche et enregistre la position.
--
-- Toutes les frames de la suite sont ancrees BOTTOMLEFT et grandissent vers le
-- haut : le bord bas ne bouge jamais, donc les boutons d'action gardent leur
-- position ecran quand le contenu change.
local function StopMovingAndSave(frame)
    frame:StopMovingOrSizing()
    local x, y = GetBottomLeftPosition()
    if x and y then
        SetBottomLeftPosition(x, y)
    end
    api:SavePosition()
end

local function CreateFrames()
    if rootFrame then
        return
    end

    visibilityFrame = CreateFrame("Frame", addonName .. "VisibilityFrame", UIParent, "SecureHandlerStateTemplate")
    visibilityFrame:SetAllPoints(UIParent)
    visibilityFrame:Show()

    rootFrame = CreateFrame("Frame", addonName .. "Frame", visibilityFrame, "BackdropTemplate")
    rootFrame:SetFrameStrata("MEDIUM")
    rootFrame:SetSize(MIN_WIDTH, 1)
    rootFrame:SetClampedToScreen(true)
    rootFrame:SetMovable(true)

    if UI then
        UI.ApplyPanelBackdrop(rootFrame)
    else
        rootFrame.bg = rootFrame:CreateTexture(nil, "BACKGROUND")
        rootFrame.bg:SetAllPoints()
        rootFrame.bg:SetColorTexture(0, 0, 0, 0.55)
    end

    headerFrame = UI and UI.CreateHeader(rootFrame, "Yaya", {
        moveTarget = rootFrame,
        isLocked = function()
            return api:IsLocked()
        end,
        onMoveStopped = function()
            StopMovingAndSave(rootFrame)
        end,
    }) or nil

    if headerFrame then
        -- La souris n'est plus activee sur tout le conteneur : il attrapait les
        -- glissers accidentels et interceptait les clics destines aux frames
        -- posees dessous, dont le panneau de YayaQueue.
        rootFrame:EnableMouse(false)

        lockButton = UI.CreateGlyphButton(headerFrame, "lock", { locked = api:IsLocked() })
        if lockButton then
            headerFrame.AddButton(lockButton)
            lockButton:SetScript("OnClick", function()
                api:SetLocked(not api:IsLocked())
            end)
            lockButton.SetTooltip(
                "Verrouiller la position",
                "Empeche le deplacement de la frame partagee."
            )
        end
    else
        -- Sans en-tete, tout le conteneur redevient la poignee, comme avant.
        rootFrame:EnableMouse(true)
        rootFrame:RegisterForDrag("LeftButton")
        rootFrame:SetScript("OnDragStart", rootFrame.StartMoving)
        rootFrame:SetScript("OnDragStop", StopMovingAndSave)
    end

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

--- Titre affiche dans l'en-tete d'une section.
--
-- Sans appel, l'identifiant sert de titre. Les sections qui portaient leur
-- propre libelle (le "Hebdo" du tracker, la ligne "Session") le remontent ici
-- et recuperent la hauteur correspondante.
function api:SetSectionTitle(id, title)
    local section = self:RegisterSection(id)
    if not section then
        return
    end
    section.title = title
    if section.header and section.header.title then
        section.header.title:SetText(title or id)
    end
    return section
end

--- Cree si besoin le bandeau d'une section et le renvoie.
--
-- Une section y pose ses propres boutons -- reinitialisation, actions -- au lieu
-- de les loger dans son contenu, ou ils consommaient une ligne.
function api:EnsureSectionHeader(id)
    self:EnsureFrame()
    for _, section in ipairs(sections) do
        if section.id == id then
            return EnsureSectionChrome(section)
        end
    end
end

--- Enregistre le rappel appele quand la section est repliee ou depliee.
--
-- La section reste maitresse de son rendu : elle masque son contenu et ramene
-- sa hauteur elle-meme. Le conteneur ne touche jamais a la visibilite de la
-- frame d'une section.
function api:SetSectionCollapseHandler(id, handler)
    local section = self:RegisterSection(id)
    if not section then
        return
    end
    section.onCollapse = handler
    return section
end

function api:IsSectionCollapsed(id)
    return GetCollapsedStore()[id] == true
end

--- Replie ou deplie une section, et previent celle-ci.
function api:SetSectionCollapsed(id, collapsed)
    collapsed = collapsed and true or false
    GetCollapsedStore()[id] = collapsed or nil

    for _, section in ipairs(sections) do
        if section.id == id then
            if section.header and type(section.header.SetCollapsed) == "function" then
                section.header.SetCollapsed(collapsed)
            end
            if type(section.onCollapse) == "function" then
                section.onCollapse(collapsed)
            end
            break
        end
    end

    RequestLayout()
end

function api:ToggleSection(id)
    self:SetSectionCollapsed(id, not self:IsSectionCollapsed(id))
end

--- Indique si la position du conteneur est figee.
function api:IsLocked()
    return GetDB().locked == true
end

--- Fige ou libere la position du conteneur.
function api:SetLocked(locked)
    GetDB().locked = locked and true or false
    if lockButton and type(lockButton.SetLocked) == "function" then
        lockButton.SetLocked(GetDB().locked)
    end
    return GetDB().locked
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
    elseif command == "lock" then
        api:SetLocked(not api:IsLocked())
        print(("|cff00ff98YayaFrame:|r position %s"):format(
            api:IsLocked() and "verrouillee" or "deverrouillee"
        ))
    else
        print("|cff00ff98YayaFrame:|r /yframe scale <0.5-2.0> | /yframe lock | /yframe reset")
    end
end

YayaFrameAPI = api
