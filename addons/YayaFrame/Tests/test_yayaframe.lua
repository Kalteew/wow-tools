-- Tests unitaires de YayaFrame, executes hors du jeu avec Lua 5.1.
--
-- Les frames de l'API WoW sont remplacees par des doublures qui suivent taille,
-- points d'ancrage et scripts. Le but est de verifier la mise en page : ordre
-- des sections, empilement vertical, hauteur totale, chrome partage, repli, et
-- surtout le verrou qui empeche OnSizeChanged de relancer la mise en page sans
-- fin.
--
-- Le vrai YayaCore/UI.lua est charge : c'est lui qui fournit les tokens dont
-- depend l'arithmetique de la mise en page, donc le tester par doublure
-- masquerait justement les desynchronisations qu'on cherche a attraper.
--
-- Usage : lua5.1 Tests/test_yayaframe.lua   (depuis addons/YayaFrame)

-- ---------------------------------------------------------------------------
-- Doublures
-- ---------------------------------------------------------------------------

local pendingTimers = {}

local function NewRegion()
    local region = { shown = true, points = {}, height = 0, width = 0 }
    function region:SetAllPoints() end
    function region:ClearAllPoints() self.points = {} end
    function region:SetPoint(point, _, _, x, y)
        self.points[#self.points + 1] = { point = point, x = x, y = y }
    end
    function region:SetColorTexture(r, g, b, a) self.color = { r, g, b, a } end
    function region:SetTexture(path) self.texture = path end
    function region:SetAtlas(name) self.atlas = name end
    function region:SetVertexColor() end
    function region:SetTexCoord() end
    function region:SetSize(w, h) self.width, self.height = w, h end
    function region:SetHeight(value) self.height = value end
    function region:SetWidth(value) self.width = value end
    function region:GetHeight() return self.height end
    function region:Show() self.shown = true end
    function region:Hide() self.shown = false end
    function region:IsShown() return self.shown end
    return region
end

local function NewFontString()
    local fs = NewRegion()
    function fs:SetText(value) self.text = value end
    function fs:GetText() return self.text end
    function fs:SetTextColor() end
    function fs:SetWordWrap(value) self.wrap = value end
    function fs:SetMaxLines(value) self.maxLines = value end
    function fs:SetJustifyH(value) self.justify = value end
    function fs:SetFontObject() end
    return fs
end

local function NewFrame(name, parent)
    local frame = {
        name = name,
        parent = parent,
        width = 0,
        height = 0,
        shown = true,
        points = {},
        scripts = {},
        hooks = {},
        scale = 1,
    }

    function frame:SetParent(value) self.parent = value end
    function frame:GetParent() return self.parent end
    function frame:SetFrameStrata() end
    function frame:SetClampedToScreen() end
    function frame:SetMovable() end
    function frame:EnableMouse(value) self.mouseEnabled = value end
    function frame:RegisterForDrag() end
    function frame:RegisterForClicks() end
    function frame:StartMoving() end
    function frame:StopMovingOrSizing() end
    function frame:SetAllPoints() end
    function frame:Show() self.shown = true end
    function frame:Hide() self.shown = false end
    function frame:IsShown() return self.shown end
    function frame:GetWidth() return self.width end
    function frame:GetHeight() return self.height end
    function frame:SetScale(value) self.scale = value end
    function frame:GetScale() return self.scale end
    function frame:ClearAllPoints() self.points = {} end
    function frame:GetLeft() return 0 end
    function frame:GetBottom() return 0 end
    function frame:GetPoint() return "BOTTOMLEFT", nil, "BOTTOMLEFT", 0, 0 end
    function frame:SetText(value) self.text = value end
    function frame:GetText() return self.text end
    function frame:SetBackdrop(value) self.backdrop = value end
    function frame:SetBackdropColor(r, g, b, a) self.backdropColor = { r, g, b, a } end
    function frame:SetBackdropBorderColor(r, g, b, a) self.borderColor = { r, g, b, a } end
    function frame:SetClipsChildren() end

    function frame:SetPoint(point, relativeTo, relativePoint, x, y)
        self.points[#self.points + 1] = { point = point, x = x, y = y }
    end

    function frame:SetWidth(value)
        local changed = self.width ~= value
        self.width = value
        if changed then self:FireSizeChanged() end
    end

    function frame:SetHeight(value)
        local changed = self.height ~= value
        self.height = value
        if changed then self:FireSizeChanged() end
    end

    function frame:SetSize(w, h)
        self:SetWidth(w)
        self:SetHeight(h)
    end

    function frame:SetScript(event, handler) self.scripts[event] = handler end
    function frame:HookScript(event, handler)
        self.hooks[event] = self.hooks[event] or {}
        table.insert(self.hooks[event], handler)
    end

    function frame:FireSizeChanged()
        for _, handler in ipairs(self.hooks.OnSizeChanged or {}) do
            handler(self, self.width, self.height)
        end
    end

    function frame:CreateTexture() return NewRegion() end
    function frame:CreateFontString() return NewFontString() end
    function frame:RegisterEvent() end
    return frame
end

_G.CreateFrame = function(_, name, parent) return NewFrame(name, parent) end
_G.UIParent = NewFrame("UIParent")
_G.RegisterStateDriver = function() end
_G.UnregisterStateDriver = function() end
_G.InCombatLockdown = function() return false end
_G.C_Timer = {
    After = function(delay, callback)
        pendingTimers[#pendingTimers + 1] = callback
    end,
}
_G.SlashCmdList = {}

local function FlushTimers()
    local guard = 0
    while #pendingTimers > 0 do
        guard = guard + 1
        assert(guard < 100, "les timers ne convergent pas : mise en page en boucle")
        local batch = pendingTimers
        pendingTimers = {}
        for _, callback in ipairs(batch) do
            callback()
        end
    end
    return guard
end

-- ---------------------------------------------------------------------------
-- Mini harnais
-- ---------------------------------------------------------------------------

local passed, failed = 0, 0

local function check(name, condition, detail)
    if condition then
        passed = passed + 1
        print(("  OK    %s"):format(name))
    else
        failed = failed + 1
        print(("  ECHEC %s%s"):format(name, detail and (" -> " .. tostring(detail)) or ""))
    end
end

local function equals(name, actual, expected)
    check(name, actual == expected, ("attendu %s, obtenu %s"):format(tostring(expected), tostring(actual)))
end

-- ---------------------------------------------------------------------------
-- Chargement : YayaCore.UI puis YayaFrame
-- ---------------------------------------------------------------------------

_G.YayaCore = {
    Tooltip = { Attach = function() end },
    Item = { Load = function() end },
}
assert(loadfile("../YayaCore/UI.lua"), "UI.lua introuvable depuis addons/YayaFrame")("YayaCore")
local UI = _G.YayaCore.UI
check("les tokens partages sont charges", type(UI) == "table")

local chunk = assert(loadfile("YayaFrame.lua"))
chunk("YayaFrame")
local api = _G.YayaFrameAPI
check("l'API s'expose en global", type(api) == "table")

-- Le chrome consomme de la hauteur avant la premiere section : en-tete du
-- conteneur, puis un bandeau par section, plus un filet entre deux sections.
local CHROME = UI.SIZE.headerH
local SECTION_HEADER = UI.SIZE.rowHCompact
local DIVIDER = UI.SIZE.divider
local GUTTER = UI.PAD.sm

-- ---------------------------------------------------------------------------

print("Mise en page")
local root = api:GetFrame()
check("le conteneur existe", root ~= nil)

local sectionA = _G.CreateFrame("Frame", "SectionA", UIParent)
sectionA.height = 40
local sectionB = _G.CreateFrame("Frame", "SectionB", UIParent)
sectionB.height = 25

api:AttachSection("B", sectionB, 20)
api:AttachSection("A", sectionA, 10)
FlushTimers()

local topA = CHROME + SECTION_HEADER
local topB = topA + 40 + DIVIDER + SECTION_HEADER

equals("hauteur totale empilee", root:GetHeight(), topB + 25)
check("la section prioritaire est sous son bandeau",
    sectionA.points[1] and sectionA.points[1].y == -topA,
    sectionA.points[1] and sectionA.points[1].y)
check("la gouttiere laterale est appliquee",
    sectionA.points[1] and sectionA.points[1].x == GUTTER,
    sectionA.points[1] and sectionA.points[1].x)
check("la suivante est decalee de la hauteur de la premiere",
    sectionB.points[1] and sectionB.points[1].y == -topB,
    sectionB.points[1] and sectionB.points[1].y)

print("Reaction automatique au redimensionnement")
-- Le cas qui laissait des sections superposees : une section change de hauteur
-- sans appeler Refresh().
sectionA:SetHeight(80)
local rounds = FlushTimers()
local topBGrown = topA + 80 + DIVIDER + SECTION_HEADER
equals("hauteur totale recalculee sans appel manuel", root:GetHeight(), topBGrown + 25)
check("la seconde section est repoussee",
    sectionB.points[#sectionB.points].y == -topBGrown,
    sectionB.points[#sectionB.points].y)
check("la mise en page converge", rounds > 0 and rounds < 100, rounds)

print("Section masquee")
sectionA:Hide()
api:Refresh()
FlushTimers()
-- Seule section visible : pas de filet, un seul bandeau.
equals("la section masquee ne compte plus", root:GetHeight(), CHROME + SECTION_HEADER + 25)
sectionA:Show()
api:Refresh()
FlushTimers()
equals("la section reaffichee recompte", root:GetHeight(), topBGrown + 25)

print("Detachement")
api:DetachSection("A")
FlushTimers()
equals("hauteur apres detachement", root:GetHeight(), CHROME + SECTION_HEADER + 25)

print("Chrome partage")
check("le conteneur a recu un backdrop", root.backdrop ~= nil)
check("la souris n'est plus active sur tout le conteneur", root.mouseEnabled == false)

print("Titre de section")
api:SetSectionTitle("B", "Hebdo")
FlushTimers()
equals("le titre remonte dans le bandeau", root:GetHeight(), CHROME + SECTION_HEADER + 25)
check("un titre pose avant creation du bandeau est repris", api:IsSectionCollapsed("B") == false)

print("Repli des sections")
-- YayaFrame ne touche jamais a la visibilite de la frame d'une section : il
-- previent la section, qui ramene sa hauteur elle-meme.
local collapseCalls = {}
api:SetSectionCollapseHandler("B", function(collapsed)
    collapseCalls[#collapseCalls + 1] = collapsed
    sectionB:SetHeight(collapsed and 1 or 25)
end)

api:ToggleSection("B")
FlushTimers()
equals("le rappel de repli est appele", #collapseCalls, 1)
equals("le rappel recoit l'etat replie", collapseCalls[1], true)
check("la section est marquee repliee", api:IsSectionCollapsed("B"))
check("la frame de la section reste affichee", sectionB:IsShown())
equals("la hauteur suit la section repliee", root:GetHeight(), CHROME + SECTION_HEADER + 1)

api:ToggleSection("B")
FlushTimers()
equals("le rappel recoit l'etat deplie", collapseCalls[2], false)
check("la section n'est plus repliee", api:IsSectionCollapsed("B") == false)
equals("la hauteur revient", root:GetHeight(), CHROME + SECTION_HEADER + 25)

-- L'etat est persiste : c'est ce qui doit survivre a un rechargement.
api:SetSectionCollapsed("B", true)
FlushTimers()
equals("l'etat replie est enregistre", _G.YayaFrameDB.collapsed.B, true)
api:SetSectionCollapsed("B", false)
FlushTimers()
check("l'etat deplie ne laisse pas d'entree", _G.YayaFrameDB.collapsed.B == nil)

print("Verrou de position")
check("la position est libre par defaut", api:IsLocked() == false)
api:SetLocked(true)
check("le verrou est pose", api:IsLocked())
equals("le verrou est enregistre", _G.YayaFrameDB.locked, true)
api:SetLocked(false)
check("le verrou est retire", api:IsLocked() == false)

print("Largeur")
equals("largeur minimale par defaut", root:GetWidth(), 200)
-- La largeur demandee est celle du contenu : le conteneur ajoute ses deux
-- gouttieres par-dessus.
api:SetSectionWidth("B", 320)
FlushTimers()
equals("largeur suivant la section", root:GetWidth(), 320 + 2 * GUTTER)
api:SetSectionWidth("B", 5000)
FlushTimers()
equals("largeur bornee au maximum", root:GetWidth(), 520)
api:SetSectionWidth("B", 10)
FlushTimers()
equals("largeur bornee au minimum", root:GetWidth(), 200)

print("Echelle")
equals("echelle par defaut", api:GetScale(), 1.0)
api:SetScale(1.4)
equals("echelle appliquee", api:GetScale(), 1.4)
api:SetScale(9)
equals("echelle bornee en haut", api:GetScale(), 2.0)
api:SetScale(0.1)
equals("echelle bornee en bas", api:GetScale(), 0.5)
api:SetScale("abc")
equals("valeur non numerique ignoree", api:GetScale(), 0.5)

print("Regroupement des demandes")
-- Plusieurs demandes consecutives ne doivent produire qu'une seule mise en page.
pendingTimers = {}
api:Refresh()
api:Refresh()
api:Refresh()
equals("une seule mise en page programmee", #pendingTimers, 1)
FlushTimers()

print("Degradation sans YayaCore")
-- Le TOC declare YayaCore en dependance dure, donc ce chemin ne sert qu'en cas
-- de retrait de UI.lua : le conteneur doit alors perdre son chrome, pas cesser
-- de charger.
_G.YayaCore = nil
_G.YayaFrameDB = nil
assert(loadfile("YayaFrame.lua"))("YayaFrame")
local bare = _G.YayaFrameAPI
local sectionC = _G.CreateFrame("Frame", "SectionC", UIParent)
sectionC.height = 30
bare:AttachSection("C", sectionC, 10)
FlushTimers()
equals("sans tokens, la hauteur est celle des sections", bare:GetFrame():GetHeight(), 30)
check("sans tokens, le conteneur reste la poignee", bare:GetFrame().mouseEnabled == true)

-- ---------------------------------------------------------------------------

print("")
print(("%d reussis, %d echoues"):format(passed, failed))
if failed > 0 then
    os.exit(1)
end
