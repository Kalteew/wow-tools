-- Tests unitaires de YayaCore.UI, executes hors du jeu avec Lua 5.1.
--
-- Le module de design ne peut pas etre teste sur du rendu : ce qui est verifie
-- ici, c'est ce qui casse en silence en jeu -- la coherence des tokens,
-- l'arithmetique de l'empilement dont depend le contrat autoclicker, les gardes
-- de debordement, et la degradation propre quand une API du client manque.
--
-- Usage : lua5.1 Tests/test_yayacoreui.lua   (depuis addons/YayaCore)

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
-- Doublures : widgets minimaux
-- ---------------------------------------------------------------------------

-- Une doublure de widget n'a que ce que UI.StackLayout et UI.BoundLabel
-- appellent reellement, pour que l'oubli d'une garde de type se voie.
local function NewWidget(height)
    local widget = { points = {}, height = height }
    function widget:ClearAllPoints()
        self.points = {}
    end
    function widget:SetPoint(point, _, _, x, y)
        self.points[point] = { x = x, y = y }
    end
    function widget:GetHeight()
        return self.height
    end
    return widget
end

local function NewFontString()
    local fs = { wrap = nil, maxLines = nil, justify = nil }
    function fs:SetWordWrap(value)
        self.wrap = value
    end
    function fs:SetMaxLines(value)
        self.maxLines = value
    end
    function fs:SetJustifyH(value)
        self.justify = value
    end
    return fs
end

local function NewTexture()
    local texture = { atlas = nil, path = nil }
    function texture:SetAtlas(name)
        self.atlas = name
    end
    function texture:SetTexture(path)
        self.path = path
    end
    return texture
end

-- ---------------------------------------------------------------------------
-- Chargement du module
-- ---------------------------------------------------------------------------

-- UI.lua depend de YayaCore : sans lui il doit sortir sans rien exposer.
_G.YayaCore = nil
assert(loadfile("UI.lua"))("YayaCore")
check("sans YayaCore, le module ne s'installe pas", _G.YayaCore == nil)

_G.YayaCore = {
    Tooltip = { Attach = function() end },
    Item = { Load = function() end },
}
assert(loadfile("UI.lua"))("YayaCore")

local UI = _G.YayaCore.UI
check("le module s'expose sur YayaCore", type(UI) == "table")

-- ---------------------------------------------------------------------------
-- Tokens
-- ---------------------------------------------------------------------------

print("")
print("Tokens")

for _, name in ipairs({ "accent", "panel", "header", "border", "text", "success", "danger" }) do
    local color = UI.COLOR[name]
    check(("la couleur %s a quatre composantes"):format(name), type(color) == "table" and #color == 4)
end

local r, g, b, a = UI.Unpack(UI.COLOR.accent)
equals("Unpack rend le rouge", r, 0)
equals("Unpack rend le vert", g, 1)
equals("Unpack rend le bleu", b, 0.6)
equals("Unpack rend l'alpha", a, 1)
equals("Unpack accepte un alpha impose", select(4, UI.Unpack(UI.COLOR.accent, 0.5)), 0.5)
equals("Unpack tolere une couleur absente", select(1, UI.Unpack(nil)), 1)

equals("Colorize enrobe et referme", UI.Colorize("success", "fait"), "|cff7fff7ffait|r")
equals("Colorize retombe sur text", UI.Colorize("inconnu", "x"), UI.HEX.text .. "x|r")

-- L'accent de marque doit rester la menthe : c'est le prefixe de chat deja
-- utilise par YayaCore, YayaFrame et YayaWarbandBankDefault.
equals("l'accent inline est la menthe", UI.HEX.accent, "|cff00ff98")

-- CRITIQUE AUTOCLICKER : le pas doit rester la somme hauteur + ecart, sinon les
-- slots de YayaQueue et du tracker hebdomadaire cessent de coincider.
equals("le pas d'action derive de la hauteur et de l'ecart",
    UI.ACTION.pitch, UI.ACTION.height + UI.ACTION.gap)
check("la marge basse d'action est positive", (UI.ACTION.bottomMargin or 0) > 0)

-- ---------------------------------------------------------------------------
-- BoundLabel
-- ---------------------------------------------------------------------------

print("")
print("Gardes de debordement")

local label = UI.BoundLabel(NewFontString())
equals("le retour a la ligne est coupe", label.wrap, false)
equals("le texte est limite a une ligne", label.maxLines, 1)
equals("l'alignement par defaut est a gauche", label.justify, "LEFT")
equals("l'alignement est parametrable", UI.BoundLabel(NewFontString(), "RIGHT").justify, "RIGHT")

-- Un FontString incomplet ne doit pas lever d'erreur : le module tourne aussi
-- sur des clients ou SetMaxLines manque.
local partial = { SetJustifyH = function(self, v) self.justify = v end }
check("un widget partiel ne leve pas d'erreur", UI.BoundLabel(partial) == partial)
check("un argument non table est rendu tel quel", UI.BoundLabel(nil) == nil)

-- ---------------------------------------------------------------------------
-- StackLayout
-- ---------------------------------------------------------------------------

print("")
print("Empilement vertical")

local stack = UI.StackLayout(NewWidget(0), { left = 6, right = 6, top = 22 })
local first, second, action = NewWidget(20), NewWidget(20), NewWidget(22)

stack.Add(first)
stack.Add(second)
stack.Add(action, UI.ACTION.gap)

equals("trois widgets empiles", stack.count, 3)
equals("le premier part sous l'en-tete", first.points.TOPLEFT.y, -22)
equals("la gouttiere gauche est appliquee", first.points.TOPLEFT.x, 6)
equals("le second suit le premier", second.points.TOPLEFT.y, -42)
equals("l'ecart avant le bouton est respecte", action.points.TOPLEFT.y, -66)
check("les widgets sont etires a droite", second.points.TOPRIGHT ~= nil)

-- La hauteur totale determine ou se retrouve le dernier widget : les frames
-- sont ancrees en bas, donc total = offset + marge basse place le bouton a
-- exactement bottomMargin du bord inferieur.
local total = stack.Finish(UI.ACTION.bottomMargin)
equals("la hauteur totale inclut la marge basse", total, 22 + 20 + 20 + 4 + 22 + UI.ACTION.bottomMargin)

local narrow = NewWidget(20)
stack.Add(narrow, 0, { stretch = false })
check("stretch = false n'ancre pas le bord droit", narrow.points.TOPRIGHT == nil)

local imposed = NewWidget(999)
local beforeImposed = stack.offset
stack.Add(imposed, 0, { height = 10 })
equals("une hauteur imposee remplace GetHeight", stack.offset - beforeImposed, 10)

stack.Reset()
equals("Reset revient sous l'en-tete", stack.offset, 22)
equals("Reset remet le compteur a zero", stack.count, 0)

stack.AddSpace(8)
equals("AddSpace avance sans widget", stack.offset, 30)
check("Add tolere un widget absent", stack.Add(nil) == stack)

local bare = UI.StackLayout(NewWidget(0))
equals("sans options, l'empilement part de zero", bare.Finish(), 1)

-- ---------------------------------------------------------------------------
-- Verrou de position
-- ---------------------------------------------------------------------------

print("")
print("Icone de verrou")

-- Sans C_Texture, le sondage d'atlas echoue et on doit retomber sur le fichier
-- de l'ancien bouton de verrouillage des barres d'action.
_G.C_Texture = nil
local texture = NewTexture()
check("une icone est appliquee sans C_Texture", UI.SetLockIcon(texture, true))
equals("le repli utilise le fichier verrouille", texture.path, UI.LOCK_TEXTURE.locked)
check("aucun atlas n'est pose sans C_Texture", texture.atlas == nil)

check("sans texture, l'appel echoue proprement", UI.SetLockIcon(nil, true) == false)

-- Un antislash isole dans une chaine Lua est une sequence d'echappement
-- invalide : Lua 5.1 la mange en silence, et le chemin devient une texture
-- introuvable, sans la moindre erreur. On verifie donc la valeur reelle.
local BACKSLASH = string.char(92)
local function PathIsIntact(path)
    return type(path) == "string" and path:find(BACKSLASH, 1, true) ~= nil
end

check("le chemin de fond garde ses antislashs", PathIsIntact(UI.BACKDROP.bgFile), UI.BACKDROP.bgFile)
check("le chemin de bordure garde ses antislashs", PathIsIntact(UI.BACKDROP.edgeFile), UI.BACKDROP.edgeFile)
check("le chemin du verrou garde ses antislashs", PathIsIntact(UI.LOCK_TEXTURE.locked), UI.LOCK_TEXTURE.locked)
check("le chemin du deverrouillage garde ses antislashs", PathIsIntact(UI.LOCK_TEXTURE.unlocked), UI.LOCK_TEXTURE.unlocked)
check("le chevron replie garde ses antislashs", PathIsIntact(UI.EXPAND_TEXTURE.collapsed), UI.EXPAND_TEXTURE.collapsed)
check("le chevron deplie garde ses antislashs", PathIsIntact(UI.EXPAND_TEXTURE.expanded), UI.EXPAND_TEXTURE.expanded)

local mute = { }
check("une texture sans setter echoue proprement", UI.SetLockIcon(mute, false) == false)

-- ---------------------------------------------------------------------------
-- Degradation sans API WoW
-- ---------------------------------------------------------------------------

print("")
print("Degradation propre")

-- CreateFrame n'existe pas hors du jeu : aucune fabrique ne doit lever
-- d'erreur, sinon le chunk entier cesse de charger.
check("CreateRow degrade sans CreateFrame", UI.CreateRow({}, {}) == nil)
check("CreateButton degrade sans CreateFrame", UI.CreateButton({}, "x") == nil)
check("CreateGlyphButton degrade sans CreateFrame", UI.CreateGlyphButton({}, "lock") == nil)
check("CreateHeader degrade sans CreateFrame", UI.CreateHeader({}, "x") == nil)
check("CreateScrollList degrade sans les templates", UI.CreateScrollList({}, {}) == nil)
check("CreateDivider degrade sans CreateTexture", UI.CreateDivider({}) == nil)

-- ApplyPanelBackdrop doit poser un aplat quand SetBackdrop manque, comme
-- YayaFrame le faisait a la main avant ce module.
local plain = {}
function plain:CreateTexture()
    local t = NewTexture()
    function t:SetAllPoints() end
    function t:SetColorTexture(cr, cg, cb, ca)
        self.color = { cr, cg, cb, ca }
    end
    return t
end
UI.ApplyPanelBackdrop(plain)
check("sans SetBackdrop, un aplat est cree", plain.yayaBackdropFallback ~= nil)
equals("l'aplat prend la couleur de panneau",
    plain.yayaBackdropFallback.color[4], UI.COLOR.panel[4])

-- Deux appels ne doivent pas empiler deux textures.
local firstFallback = plain.yayaBackdropFallback
UI.ApplyPanelBackdrop(plain)
check("l'aplat n'est pas duplique", plain.yayaBackdropFallback == firstFallback)

-- ---------------------------------------------------------------------------

print("")
print(("%d reussis, %d echoues"):format(passed, failed))
if failed > 0 then
    os.exit(1)
end
