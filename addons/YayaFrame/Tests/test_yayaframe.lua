-- Tests unitaires de YayaFrame, executes hors du jeu avec Lua 5.1.
--
-- Les frames de l'API WoW sont remplacees par des doublures qui suivent taille,
-- points d'ancrage et scripts. Le but est de verifier la mise en page : ordre
-- des sections, empilement vertical, hauteur totale, et surtout le verrou qui
-- empeche OnSizeChanged de relancer la mise en page sans fin.
--
-- Usage : lua5.1 Tests/test_yayaframe.lua   (depuis addons/YayaFrame)

-- ---------------------------------------------------------------------------
-- Doublures
-- ---------------------------------------------------------------------------

local pendingTimers = {}

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
    function frame:EnableMouse() end
    function frame:RegisterForDrag() end
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

    function frame:CreateTexture()
        local texture = { height = 0 }
        function texture:SetAllPoints() end
        function texture:SetColorTexture() end
        function texture:SetHeight(value) self.height = value end
        return texture
    end

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

local chunk = assert(loadfile("YayaFrame.lua"))
chunk("YayaFrame")
local api = _G.YayaFrameAPI
check("l'API s'expose en global", type(api) == "table")

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

equals("hauteur totale empilee", root:GetHeight(), 65)
check("la section prioritaire est en haut",
    sectionA.points[1] and sectionA.points[1].y == 0,
    sectionA.points[1] and sectionA.points[1].y)
check("la suivante est decalee de la hauteur de la premiere",
    sectionB.points[1] and sectionB.points[1].y == -40,
    sectionB.points[1] and sectionB.points[1].y)

print("Reaction automatique au redimensionnement")
-- Le cas qui laissait des sections superposees : une section change de hauteur
-- sans appeler Refresh().
sectionA:SetHeight(80)
local rounds = FlushTimers()
equals("hauteur totale recalculee sans appel manuel", root:GetHeight(), 105)
check("la seconde section est repoussee",
    sectionB.points[#sectionB.points].y == -80,
    sectionB.points[#sectionB.points].y)
check("la mise en page converge", rounds > 0 and rounds < 100, rounds)

print("Section masquee")
sectionA:Hide()
api:Refresh()
FlushTimers()
equals("la section masquee ne compte plus", root:GetHeight(), 25)
sectionA:Show()
api:Refresh()
FlushTimers()
equals("la section reaffichee recompte", root:GetHeight(), 105)

print("Detachement")
api:DetachSection("A")
FlushTimers()
equals("hauteur apres detachement", root:GetHeight(), 25)

print("Largeur")
equals("largeur minimale par defaut", root:GetWidth(), 200)
api:SetSectionWidth("B", 320)
FlushTimers()
equals("largeur suivant la section", root:GetWidth(), 320)
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

print("")
print(("%d reussis, %d echoues"):format(passed, failed))
if failed > 0 then
    os.exit(1)
end
