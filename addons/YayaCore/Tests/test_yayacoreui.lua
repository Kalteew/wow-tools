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

local function NewFontString(opts)
    opts = opts or {}
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
    function fs:SetText(value)
        self.text = value
    end
    function fs:SetWidth(value)
        self.width = value
    end
    function fs:SetSpacing(value)
        self.spacing = value
    end
    function fs:GetFont()
        return "Font", opts.fontSize or 10
    end
    -- Hauteur mesuree pilotable : c'est la valeur dont FitLabel se mefie, et
    -- dont il ne retient que le maximum face au compte de lignes calcule.
    if opts.stringHeight then
        function fs:GetStringHeight()
            return opts.stringHeight
        end
    end
    if opts.truncated ~= nil then
        function fs:IsTruncated()
            return opts.truncated
        end
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

-- Regression : la branche lock de CreateGlyphButton lisait UI.COLOR.locked, un
-- token qui n'existait pas. L'expression retombait donc en silence sur
-- textMuted et le cadenas ferme s'affichait exactement comme l'ouvert. Le test
-- porte sur ce qui se voyait -- deux etats distincts -- pas sur la presence du
-- token.
check("le token de verrou a quatre composantes",
    type(UI.COLOR.locked) == "table" and #UI.COLOR.locked == 4)
local sameAsMuted = true
for index = 1, 4 do
    if UI.COLOR.locked[index] ~= UI.COLOR.textMuted[index] then
        sameAsMuted = false
    end
end
check("le cadenas ferme se distingue de l'ouvert", not sameAsMuted)

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
-- Texte multi-lignes
-- ---------------------------------------------------------------------------

print("")
print("Texte multi-lignes")

-- Mesure injectee en nombre de caracteres : le test ne depend alors d'aucune
-- police, et les largeurs se lisent directement dans les assertions.
local function chars(text)
    return #UI.StripMarkup(text)
end

local function packed(tokens, width, maxLines, prefix)
    return UI.PackLines(tokens, {
        width = width,
        maxLines = maxLines,
        prefix = prefix,
        measure = chars,
    })
end

local text0, lines0, hidden0 = packed({}, 30, 3, "X:")
equals("aucun jeton : le prefixe seul", text0, "X:")
equals("aucun jeton : une ligne", lines0, 1)
equals("aucun jeton : rien de cache", hidden0, 0)

local text1, lines1, hidden1 = packed({ "abc" }, 30, 3)
equals("un jeton qui tient : une ligne", lines1, 1)
equals("un jeton qui tient : le texte brut", text1, "abc")
equals("un jeton qui tient : rien de cache", hidden1, 0)

-- Trois jetons de 8 caracteres pour 8 de large : une ligne chacun, pile le
-- plafond, donc aucun marqueur de debordement.
local text3, lines3, hidden3 = packed({ "aaaaaaaa", "bbbbbbbb", "cccccccc" }, 8, 3)
equals("exactement trois lignes", lines3, 3)
equals("exactement trois lignes : rien de cache", hidden3, 0)
check("exactement trois lignes : pas de marqueur", not text3:find("%+%d"))

local text4, lines4, hidden4 = packed({ "aaaaaaaa", "bbbbbbbb", "cccccccc", "dddddddd" }, 8, 3)
equals("quatre jetons pour trois lignes : plafonne", lines4, 3)
check("quatre jetons pour trois lignes : du texte est cache", hidden4 > 0)
equals("le marqueur annonce le compte cache", text4:match("%+(%d+)$"), tostring(hidden4))

-- Largeur nulle : la coupure est desactivee, tout tient sur une ligne.
local wide = packed({ "a", "b", "c", "d", "e", "f", "g", "h", "i", "j" }, 0, 3)
equals("largeur nulle : une seule ligne", select(2, packed({ "a", "b" }, 0, 3)), 1)
check("largeur nulle : rien n'est perdu", wide:find("j") ~= nil)

-- Un jeton plus large que la ligne doit etre pose seul plutot que perdu, et
-- surtout ne pas faire boucler le packer.
local long = "Enchant Tool - Haranir Multicrafting"
local textLong, linesLong, hiddenLong = packed({ long }, 10, 3)
equals("un jeton trop large est pose seul", textLong, long)
equals("un jeton trop large tient sur une ligne", linesLong, 1)
equals("un jeton trop large n'est pas perdu", hiddenLong, 0)

-- Garde du contrat : une coupure ne tombe jamais au milieu d'un jeton.
local tokens = { "loot 6/6", "dez 2/2", "hebdo", "catchup 3", "traite" }
local packedText = packed(tokens, 20, 3, "Ench:")
local rebuilt = packedText:gsub("\n", " "):gsub("^Ench: ", "")
for _, token in ipairs(tokens) do
    if rebuilt:find(token, 1, true) == nil then
        check("le jeton " .. token .. " survit a la coupure", false)
    end
end
check("aucun jeton n'est coupe par le retour a la ligne", true)

equals("deux appels identiques rendent le meme texte", packed(tokens, 20, 3, "Ench:"), packedText)

-- FitLabel : le compte calcule fait foi, la mesure n'est qu'un second avis.
local height1, count1 = UI.FitLabel(NewFontString({ fontSize = 10 }), "a", 1, 3)
equals("une ligne : hauteur d'une ligne", height1, 13)
equals("une ligne : un compte de un", count1, 1)

local height3 = UI.FitLabel(NewFontString({ fontSize = 10 }), "a", 3, 3)
equals("trois lignes : trois hauteurs", height3, 39)

-- La mesure sous-evalue (une seule ligne) alors que le packer en a compte
-- trois : c'est le cas ou se fier a GetStringHeight ferait chevaucher le texte.
local _, countUnder = UI.FitLabel(NewFontString({ fontSize = 10, stringHeight = 13 }), "a", 3, 3)
equals("mesure sous-evaluee : le compte calcule gagne", countUnder, 3)

-- La mesure sur-evalue : le plafond doit tenir.
local _, countOver = UI.FitLabel(NewFontString({ fontSize = 10, stringHeight = 91 }), "a", 1, 3)
equals("mesure sur-evaluee : le plafond tient", countOver, 3)

local heightPartial = UI.FitLabel({ SetText = function() end }, "a", 2, 3)
equals("FontString partielle : repli de hauteur de ligne", heightPartial, 24)
equals("la hauteur rendue est entiere", heightPartial, math.floor(heightPartial))

-- LineHeight, ResolveWidth, StripMarkup, IsLabelTruncated
equals("LineHeight sans police : repli du token", UI.LineHeight({}), UI.TEXT.lineH)
equals("LineHeight depuis la taille de police", UI.LineHeight(NewFontString({ fontSize = 10 })), 13)
equals("ResolveWidth : une largeur trop faible retombe sur le repli",
    UI.ResolveWidth({ GetWidth = function() return 1 end }, 192), 192)
equals("ResolveWidth : une largeur valide est gardee",
    UI.ResolveWidth({ GetWidth = function() return 240 end }, 192), 240)
equals("ResolveWidth : une region absente retombe sur le repli", UI.ResolveWidth(nil, 192), 192)
equals("StripMarkup retire les couleurs", UI.StripMarkup("|cffff6666KP 7|r"), "KP 7")
equals("StripMarkup garde le libelle d'un lien", UI.StripMarkup("|Hitem:1|hlien|h"), "lien")
equals("StripMarkup normalise l'espace insecable", UI.StripMarkup("a" .. UI.TEXT.nbsp .. "b"), "a b")
equals("IsLabelTruncated sans la methode", UI.IsLabelTruncated({}), false)
equals("IsLabelTruncated a false", UI.IsLabelTruncated(NewFontString({ truncated = false })), false)
equals("IsLabelTruncated a true", UI.IsLabelTruncated(NewFontString({ truncated = true })), true)

-- WrapLabel : l'inverse de BoundLabel, avec une largeur explicite obligatoire.
local wrapped = UI.WrapLabel(NewFontString(), { width = 100, maxLines = 3 })
equals("WrapLabel autorise le retour a la ligne", wrapped.wrap, true)
equals("WrapLabel plafonne les lignes", wrapped.maxLines, 3)
equals("WrapLabel impose une largeur", wrapped.width, 100)
equals("WrapLabel aligne a gauche", wrapped.justify, "LEFT")
check("WrapLabel rend un argument non table tel quel", UI.WrapLabel(nil) == nil)

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
-- Lignes de liste
-- ---------------------------------------------------------------------------

print("")
print("Lignes de liste")

-- Doublure de Button : uniquement ce que DecorateRow appelle reellement, pour
-- qu'un appel oublie se voie plutot que d'etre absorbe.
local function NewRow(width)
    local row = { points = {}, scripts = {}, width = width or 192 }
    function row:SetHeight(value) self.height = value end
    function row:GetHeight() return self.height end
    function row:GetWidth() return self.width end
    function row:SetClipsChildren(value) self.clips = value end
    function row:SetScript(name, fn) self.scripts[name] = fn end
    function row:CreateTexture()
        local texture = {}
        function texture:SetAllPoints() end
        function texture:SetColorTexture(...) self.color = { ... } end
        function texture:SetTexture(value) self.path = value end
        function texture:SetSize() end
        function texture:SetPoint() end
        function texture:SetTexCoord() end
        return texture
    end
    function row:CreateFontString()
        local fs = NewFontString()
        function fs:ClearAllPoints() self.points = {} end
        function fs:SetPoint(point, _, _, x, y)
            self.points = self.points or {}
            self.points[point] = { x = x, y = y }
        end
        function fs:SetTextColor(...) self.color = { ... } end
        function fs:GetStringWidth() return #tostring(self.text or "") end
        return fs
    end
    return row
end

local row = UI.DecorateRow(NewRow())
check("la ligne est decoree", row ~= nil and row.yayaRow == true)
check("la ligne clippe ses enfants", row.clips == true)
check("le libelle est borne a une ligne", row.label.maxLines == 1)
check("la valeur est bornee a une ligne", row.value.maxLines == 1)
check("le libelle est ancre a gauche et a droite",
    row.label.points.LEFT ~= nil and row.label.points.RIGHT ~= nil)

-- DecorateRow est idempotent : une ligne recyclee ne doit pas se voir equiper
-- deux fois.
check("DecorateRow est idempotent", UI.DecorateRow(row) == row)

row.SetStripe(1)
local odd = row.bg.color
row.SetStripe(2)
check("la zebrure alterne selon la parite", odd[4] ~= row.bg.color[4])

-- SetTone ne teinte que la valeur, SetLabelTone que le libelle : c'est
-- exactement la separation qui manquait et que le commentaire promettait.
row.label.color, row.value.color = nil, nil
row.SetTone("danger")
check("SetTone teinte la valeur", row.value.color ~= nil)
check("SetTone ne touche pas au libelle", row.label.color == nil)
row.SetLabelTone("danger")
check("SetLabelTone teinte le libelle", row.label.color ~= nil)

-- Le recyclage doit rendre la ligne a son etat neuf : sans la remise a zero de
-- la couleur du libelle, une ligne heritait de la teinte de la precedente.
row.label:SetTextColor(1, 0, 0, 1)
row.SetTruncatedTooltip("titre", "corps")
row.SetLabelWrap(3, 100)
row.Reset()
equals("Reset rebascule le libelle sur une ligne", row.label.maxLines, 1)
check("Reset oublie la condition de troncature", row.tooltipWhenTruncated == nil)
check("Reset efface l'infobulle", row.tooltipTitle == nil)
equals("Reset remet la couleur du libelle", row.label.color[1], UI.COLOR.text[1])
equals("Reset remet la couleur de la valeur", row.value.color[1], UI.COLOR.text[1])

-- Bascule multi-lignes : la largeur explicite remplace l'ancre droite, sinon la
-- coupure et la hauteur seraient calculees contre une largeur non resolue.
row.SetLabelWrap(3, 100)
equals("le libelle passe a trois lignes", row.label.maxLines, 3)
equals("le libelle recoit une largeur explicite", row.label.width, 100)
check("l'ancre droite est retiree", row.label.points.RIGHT == nil)
row.SetLabelWrap(1)
equals("le retour a une ligne restaure la borne", row.label.maxLines, 1)
check("le retour a une ligne restaure l'ancre droite", row.label.points.RIGHT ~= nil)

equals("LabelWidth retranche les marges et la gouttiere",
    row.LabelWidth(192), 192 - UI.PAD.md - UI.PAD.md - UI.PAD.sm)

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
