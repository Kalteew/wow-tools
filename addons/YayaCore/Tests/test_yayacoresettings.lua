-- Tests unitaires de YayaCore.Settings, executes hors du jeu avec Lua 5.1.
--
-- Ce qui est verifie, c'est ce qui casse en silence en jeu : les defauts qui
-- ecrasent un false, un widget qui ne relit pas la base a l'ouverture, une
-- boucle de resynchronisation qui reecrit la base a chaque OnShow, et la
-- degradation quand un template ou l'API Settings manquent.
--
-- Usage : lua5.1 Tests/test_yayacoresettings.lua   (depuis addons/YayaCore)

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
-- Chargement : doublures puis modules
-- ---------------------------------------------------------------------------

dofile("Tests/ui_stub.lua")

_G.YayaCore = nil
assert(loadfile("YayaCore.lua"))("YayaCore")
assert(loadfile("UI.lua"))("YayaCore")
assert(loadfile("Settings.lua"))("YayaCore")

local UI = _G.YayaCore.UI
local YS = _G.YayaCore.Settings
check("le module s'expose sur YayaCore.Settings", type(YS) == "table")
check("BuildPanel est exposee", type(YS.BuildPanel) == "function")

-- Sans YayaCore.UI, le module doit sortir sans rien poser.
do
    local saved = _G.YayaCore
    _G.YayaCore = { }
    assert(loadfile("Settings.lua"))("YayaCore")
    check("sans YayaCore.UI, le module ne s'installe pas", _G.YayaCore.Settings == nil)
    _G.YayaCore = saved
end

-- ---------------------------------------------------------------------------
-- 1. ApplyDefaults
-- ---------------------------------------------------------------------------

print("")
print("ApplyDefaults")

local defaults = {
    enabled = true,
    hidden = false,
    threshold = 5,
    order = { 1, 2, { nested = "x" } },
}
local db = { hidden = false, threshold = nil, enabled = false }
YS.ApplyDefaults(db, defaults)
equals("une cle nil est remplie", db.threshold, 5)
equals("un false explicite est garde", db.hidden, false)
equals("un false explicite n'est pas ecrase par un default true", db.enabled, false)
check("une table est copiee", type(db.order) == "table" and db.order ~= defaults.order)

db.order[3].nested = "muted"
db.order[4] = 99
equals("la copie est profonde : la mutation ne remonte pas", defaults.order[3].nested, "x")
equals("la copie est profonde : la longueur des defauts ne bouge pas", #defaults.order, 3)

local filtered = YS.ApplyDefaults({}, defaults, { "threshold" })
equals("keys en chaines : la cle listee est remplie", filtered.threshold, 5)
check("keys en chaines : les autres sont ignorees", filtered.enabled == nil and filtered.order == nil)

local fromDescs = YS.ApplyDefaults({}, defaults, { { key = "enabled" }, { type = "section", label = "x" } })
equals("keys en descripteurs : .key est lue", fromDescs.enabled, true)
check("keys en descripteurs : une entree sans key est ignoree", fromDescs.threshold == nil)

check("ApplyDefaults rend la db", YS.ApplyDefaults(db, defaults) == db)
check("ApplyDefaults tolere des defauts absents", type(YS.ApplyDefaults({}, nil)) == "table")

-- NormalizeOption
local normalized = YS.NormalizeOption({ key = "a" }, "Cat")
equals("type absent + key => checkbox", normalized.type, "checkbox")
equals("category absente => celle du predecesseur", normalized.category, "Cat")
check("type absent sans key => ignoree", YS.NormalizeOption({ label = "x" }) == nil)
equals("sans predecesseur, la categorie de repli est General", YS.NormalizeOption({ key = "b" }).category, "General")

local checkTrue = YS.NormalizeOption({ key = "t", default = true })
local checkFalse = YS.NormalizeOption({ key = "f", default = false })
equals("checkbox default true : nil se lit coche", checkTrue.get({}), true)
equals("checkbox default true : false se lit decoche", checkTrue.get({ t = false }), false)
equals("checkbox default false : nil se lit decoche", checkFalse.get({}), false)
equals("checkbox default false : true se lit coche", checkFalse.get({ f = true }), true)
local plain = YS.NormalizeOption({ key = "n", type = "slider" })
equals("slider : get lit db[key] tel quel", plain.get({ n = 7 }), 7)
local target = {}
plain.set(target, 3)
equals("set ecrit db[key]", target.n, 3)

-- ---------------------------------------------------------------------------
-- 2. Construction
-- ---------------------------------------------------------------------------

print("")
print("Construction")

local store = {
    hideInCombat = false,
    rank = 2,
    rows = 8,
    mult = 1.2,
    limit = 50,
    mode = "standard",
    order = { "ench", "alch" },
    hidden = {},
    tomtom = true,
}
local changes = {}

local function NewSpec()
    return {
        name = "Yaya Test",
        description = "Panneau de test.",
        framePrefix = "YayaTest",
        db = function() return store end,
        defaults = { hideInCombat = false, rank = 1, rows = 8, mult = 1.5, limit = 100, mode = "standard" },
        onChange = function(key, value, desc)
            changes[#changes + 1] = { key = key, value = value, desc = desc }
        end,
        options = {
            { type = "section", label = "Affichage", category = "Affichage" },
            { key = "hideInCombat", label = "Cacher en combat", tooltip = "Masque la frame." },
            { key = "rank", type = "radio", label = "Rang", choices = {
                { value = 1, label = "Rang 1" }, { value = 2, label = "Rang 2" } } },
            { key = "rows", type = "slider", label = "Lignes", min = 2, max = 24, step = 1, category = "Seuils" },
            { key = "mult", type = "slider", label = "Multiplicateur", min = 1, max = 3, step = 0.1, format = "%.1fx" },
            { key = "limit", type = "number", label = "Limite", min = 0, max = 100, suffix = "po" },
            { key = "mode", type = "dropdown", label = "Tri", choices = {
                { value = "standard", label = "Standard" }, { value = "profit", label = "Profit" } } },
            { key = "order", type = "orderlist", label = "Metiers", hiddenKey = "hidden", category = "Metiers",
                items = { { id = "alch", label = "Alchimie" }, { id = "ench", label = "Enchantement" }, { id = "jc", label = "Joaillerie" } } },
            { key = "tomtom", label = "TomTom", dependsOn = "hideInCombat" },
            { type = "text", label = "Un texte libre explicatif." },
            { type = "button", key = "reset", label = "Reinitialiser", onClick = function() changes.clicked = true end },
            { type = "inconnu", key = "ghost", label = "Type inconnu" },
            { label = "Ni type ni key" },
        },
    }
end

local handle = YS.BuildPanel(NewSpec())
check("BuildPanel rend un handle", type(handle) == "table")
equals("trois categories", #handle.categories, 3)
equals("la premiere categorie est Affichage", handle.categories[1], "Affichage")
equals("la seconde est Seuils", handle.categories[2], "Seuils")
check("le rail est present avec plusieurs categories", handle.rail ~= nil)
equals("le rail porte un bouton par categorie", #handle.railButtons, 3)
local pageCount = 0
for _ in pairs(handle.pages) do pageCount = pageCount + 1 end
equals("une page par categorie", pageCount, 3)
equals("la premiere categorie est active", handle.activeCategory, "Affichage")
check("la page active est le scrollChild", handle.scrollFrame:GetScrollChild() == handle.pages.Affichage)
equals("le panneau porte le prefixe demande", handle.panel:GetName(), "YayaTestOptionsPanel")
equals("le panneau porte le nom du spec", handle.panel.name, "Yaya Test")
check("le panneau expose son handle", handle.panel.handle == handle)

local W = handle.widgets
check("widgets.hideInCombat (checkbox)", W.hideInCombat ~= nil)
check("widgets.rank (radio)", W.rank ~= nil)
check("widgets.rows (slider)", W.rows ~= nil)
check("widgets.mult (slider decimal)", W.mult ~= nil)
check("widgets.limit (number)", W.limit ~= nil)
check("widgets.mode (dropdown)", W.mode ~= nil)
check("widgets.order (orderlist)", W.order ~= nil)
check("widgets.reset (button)", W.reset ~= nil)
check("un type inconnu est saute", W.ghost == nil)

equals("checkbox : UICheckButtonTemplate", W.hideInCombat.__template, "UICheckButtonTemplate")
equals("radio : UIRadioButtonTemplate", W.rank.buttons[1].__template, "UIRadioButtonTemplate")
equals("radio : deux boutons", #W.rank.buttons, 2)
equals("slider : OptionsSliderTemplate", W.rows.__template, "OptionsSliderTemplate")
equals("number : InputBoxTemplate", W.limit.editBox.__template, "InputBoxTemplate")
equals("dropdown : WowStyle1DropdownTemplate", W.mode.dropdown.__template, "WowStyle1DropdownTemplate")
equals("dropdown : pas en repli", W.mode.isLegacy, false)
equals("scroll : UIPanelScrollFrameTemplate", handle.scrollFrame.__template, "UIPanelScrollFrameTemplate")

equals("slider : le texte porte libelle et valeur", W.rows.label:GetText(), "Lignes : 8")
equals("slider decimal : le format est applique", W.mult.label:GetText(), "Multiplicateur : 1.2x")
equals("number : la saisie affiche la valeur", W.limit.editBox:GetText(), "50")
equals("number : le suffixe est pose", W.limit.suffix:GetText(), "po")
equals("orderlist : trois lignes", #W.order.rows, 3)
equals("orderlist : l'ordre stocke est respecte", W.order.rows[1].id, "ench")
equals("orderlist : les ids manquants passent en queue", W.order.rows[3].id, "jc")
equals("orderlist : le libelle est celui de l'item", W.order.rows[1].label:GetText(), "Enchantement")
equals("orderlist : le premier ^ est desactive", W.order.rows[1].up:IsEnabled(), false)
equals("orderlist : le dernier v est desactive", W.order.rows[3].down:IsEnabled(), false)
equals("orderlist : un v intermediaire est actif", W.order.rows[2].down:IsEnabled(), true)

check("chaque page a une hauteur", (handle.pages.Seuils:GetHeight() or 0) > 50)
check("la categorie est enregistree", handle.category ~= nil and handle.category.added == true)

-- SetCategory
check("SetCategory bascule la page", handle.SetCategory("Seuils") == true)
check("la page Seuils devient le scrollChild", handle.scrollFrame:GetScrollChild() == handle.pages.Seuils)
equals("la page Affichage est masquee", handle.pages.Affichage:IsShown(), false)
equals("la page Seuils est montree", handle.pages.Seuils:IsShown(), true)
equals("le defilement revient en haut", handle.scrollFrame:GetVerticalScroll(), 0)
check("le bouton actif du rail est mis en evidence", handle.railButtons[2].selectedBg:IsShown() == true)
check("le bouton inactif ne l'est pas", handle.railButtons[1].selectedBg:IsShown() == false)
check("SetCategory inconnue rend false", handle.SetCategory("Nope") == false)
handle.SetCategory("Affichage")

-- Une seule categorie : pas de rail.
local single = YS.BuildPanel({
    name = "Mono", framePrefix = "YayaMono", db = function() return {} end,
    options = { { key = "a", label = "A" }, { key = "b", label = "B" } },
})
equals("une categorie", #single.categories, 1)
check("pas de rail avec une seule categorie", single.rail == nil)
equals("le rail force par spec.rail = true", YS.BuildPanel({
    name = "Force", framePrefix = "YayaForce", db = function() return {} end, rail = true,
    options = { { key = "a", label = "A" } },
}).rail ~= nil, true)

-- ---------------------------------------------------------------------------
-- 3. get / set
-- ---------------------------------------------------------------------------

print("")
print("Lecture et ecriture")

changes = {}
W.hideInCombat:SetChecked(true)
W.hideInCombat:GetScript("OnClick")(W.hideInCombat)
equals("checkbox : la db est ecrite", store.hideInCombat, true)
equals("checkbox : onChange appele une fois", #changes, 1)
equals("checkbox : onChange recoit la cle", changes[1].key, "hideInCombat")
equals("checkbox : onChange recoit la valeur", changes[1].value, true)
equals("checkbox : onChange recoit le descripteur", changes[1].desc.key, "hideInCombat")

changes = {}
W.rank.buttons[1]:GetScript("OnClick")(W.rank.buttons[1])
equals("radio : la valeur du choix est ecrite", store.rank, 1)
equals("radio : le choix clique est coche", W.rank.buttons[1]:GetChecked(), true)
equals("radio : l'autre est decoche", W.rank.buttons[2]:GetChecked(), false)
equals("radio : onChange appele une fois", #changes, 1)

changes = {}
W.mult:GetScript("OnValueChanged")(W.mult, 1.54)
equals("slider : 1.54 est arrondi au pas 0.1", store.mult, 1.5)
equals("slider : la valeur arrondie est exposee", W.mult.GetValueRounded(), 1.5)
equals("slider : le texte suit", W.mult.label:GetText(), "Multiplicateur : 1.5x")
W.mult:GetScript("OnValueChanged")(W.mult, 1.52)
equals("slider : meme valeur arrondie, pas de second onChange", #changes, 1)
W.rows:GetScript("OnValueChanged")(W.rows, 99)
equals("slider : clamp au max", store.rows, 24)

changes = {}
W.limit.editBox:SetText("abc")
W.limit.editBox:GetScript("OnEnterPressed")(W.limit.editBox)
equals("number : une saisie invalide garde la valeur precedente", store.limit, 50)
equals("number : la saisie est restauree", W.limit.editBox:GetText(), "50")
equals("number : aucun onChange sur saisie invalide", #changes, 0)
W.limit.editBox:SetText("200")
W.limit.editBox:GetScript("OnEnterPressed")(W.limit.editBox)
equals("number : 200 est clampe a max 100", store.limit, 100)
equals("number : onChange une fois malgre Enter + perte de focus", #changes, 1)
W.limit.editBox:SetText("42")
W.limit.editBox:GetScript("OnEscapePressed")(W.limit.editBox)
equals("number : Echap restaure la derniere valeur validee", W.limit.editBox:GetText(), "100")
equals("number : Echap n'ecrit pas la db", store.limit, 100)

changes = {}
local root = W.mode.dropdown.__root
check("dropdown : le menu est genere", root ~= nil and #root.entries == 2)
equals("dropdown : le second radio porte son libelle", root.entries[2].label, "Profit")
equals("dropdown : le premier est selectionne", root.entries[1].isSelected(), true)
root.entries[2].onSelect()
equals("dropdown : la db est ecrite", store.mode, "profit")
equals("dropdown : onChange appele une fois", #changes, 1)
equals("dropdown : le menu est regenere et le second est selectionne",
    W.mode.dropdown.__root.entries[2].isSelected(), true)
equals("dropdown : le texte par defaut suit", W.mode.dropdown.__defaultText, "Profit")

changes = {}
W.order.rows[1].down:GetScript("OnClick")(W.order.rows[1].down)
equals("orderlist : v sur le premier echange avec le second", store.order[1], "alch")
equals("orderlist : l'ancien premier passe second", store.order[2], "ench")
equals("orderlist : la liste normalisee est stockee entiere", #store.order, 3)
equals("orderlist : onChange recoit la liste", type(changes[1].value), "table")
equals("orderlist : les lignes sont redessinees", W.order.rows[1].id, "alch")
W.order.rows[1].up:GetScript("OnClick")(W.order.rows[1].up)
equals("orderlist : ^ sur le premier ne fait rien", store.order[1], "alch")

changes = {}
W.order.rows[2].check:SetChecked(false)
W.order.rows[2].check:GetScript("OnClick")(W.order.rows[2].check)
equals("orderlist : decocher masque l'id", store.hidden.ench, true)
equals("orderlist : onChange recoit la liste d'ordre", changes[1].key, "order")
W.order.rows[2].check:SetChecked(true)
W.order.rows[2].check:GetScript("OnClick")(W.order.rows[2].check)
check("orderlist : recocher retire la cle", store.hidden.ench == nil)

W.reset:GetScript("OnClick")(W.reset)
equals("button : onClick est appele", changes.clicked, true)

-- ---------------------------------------------------------------------------
-- 4. Resynchronisation
-- ---------------------------------------------------------------------------

print("")
print("Resynchronisation")

store.hideInCombat = false
store.rank = 2
store.rows = 12
store.mult = 2.5
store.limit = 7
store.mode = "standard"
store.order = { "jc" }
store.tomtom = true

changes = {}
handle.panel:GetScript("OnShow")(handle.panel)
equals("OnShow : checkbox relue", W.hideInCombat:GetChecked(), false)
equals("OnShow : radio 2 cochee", W.rank.buttons[2]:GetChecked(), true)
equals("OnShow : radio 1 decochee", W.rank.buttons[1]:GetChecked(), false)
equals("OnShow : slider relu", W.rows:GetValue(), 12)
equals("OnShow : slider decimal relu", W.mult.GetValueRounded(), 2.5)
equals("OnShow : number relu", W.limit.editBox:GetText(), "7")
equals("OnShow : dropdown relu", W.mode.dropdown.__root.entries[1].isSelected(), true)
equals("OnShow : orderlist normalisee, jc en tete", W.order.rows[1].id, "jc")
equals("OnShow : orderlist, les manquants suivent l'ordre des items", W.order.rows[2].id, "alch")
equals("OnShow : aucun onChange pendant le resync", #changes, 0)
check("OnShow : la db n'est pas reecrite", store.rows == 12 and store.mult == 2.5 and store.limit == 7)
equals("OnShow : la db d'ordre n'est pas normalisee en place", #store.order, 1)

-- dependsOn : tomtom depend de hideInCombat, qui est faux.
equals("dependsOn faux : le widget est desactive", W.tomtom:IsEnabled(), false)
equals("dependsOn faux : alpha 0.45", W.tomtom:GetAlpha(), 0.45)
store.hideInCombat = true
handle.Refresh()
equals("dependsOn vrai : le widget est reactive", W.tomtom:IsEnabled(), true)
equals("dependsOn vrai : alpha 1", W.tomtom:GetAlpha(), 1)

-- dependsOn par fonction
local fnStore = { gate = false, child = true }
local fnHandle = YS.BuildPanel({
    name = "Fn", framePrefix = "YayaFn", db = function() return fnStore end,
    options = {
        { key = "gate", label = "Porte" },
        { key = "child", label = "Enfant", dependsOn = function(d) return d.gate == true end },
    },
})
equals("dependsOn fonction : faux desactive", fnHandle.widgets.child:IsEnabled(), false)
fnStore.gate = true
fnHandle.Refresh()
equals("dependsOn fonction : vrai reactive", fnHandle.widgets.child:IsEnabled(), true)

-- OnDefault
store.rows = 3
store.limit = 1
handle.panel.OnDefault()
equals("OnDefault : le slider revient au defaut", store.rows, 8)
equals("OnDefault : le number revient au defaut", store.limit, 100)
equals("OnDefault : le widget suit", W.limit.editBox:GetText(), "100")

-- db par descripteur
local accountStore, charStore = { a = true }, { b = 5 }
local mixed = YS.BuildPanel({
    name = "Mixed", framePrefix = "YayaMixed", db = function() return accountStore end,
    options = {
        { key = "a", label = "Compte" },
        { key = "b", type = "slider", label = "Perso", min = 0, max = 10, db = function() return charStore end },
    },
})
mixed.widgets.b:GetScript("OnValueChanged")(mixed.widgets.b, 9)
equals("desc.db : la db du descripteur est ecrite", charStore.b, 9)
check("desc.db : la db du panneau n'est pas touchee", accountStore.b == nil)

-- Open
OPENED_CATEGORY = nil
handle.Open()
equals("Open : Settings.OpenToCategory recoit l'id", OPENED_CATEGORY, 42)

-- ---------------------------------------------------------------------------
-- 5. Degradation
-- ---------------------------------------------------------------------------

print("")
print("Degradation")

local savedSettings = _G.Settings
_G.Settings = nil
_G.InterfaceOptions_AddCategory = nil
_G.InterfaceOptionsFrame_OpenToCategory = nil
local bare = YS.BuildPanel(NewSpec())
check("sans API d'options : le panneau se construit", bare ~= nil)
check("sans API d'options : category est nil", bare.category == nil)
check("sans API d'options : Open ne leve pas", pcall(bare.Open))
_G.Settings = savedSettings

-- Ancien systeme d'options : InterfaceOptions_AddCategory est appele.
_G.Settings = nil
local legacyAdded, legacyOpened = nil, 0
_G.InterfaceOptions_AddCategory = function(panel) legacyAdded = panel end
_G.InterfaceOptionsFrame_OpenToCategory = function() legacyOpened = legacyOpened + 1 end
local legacyHandle = YS.BuildPanel(NewSpec())
check("repli InterfaceOptions : le panneau est ajoute", legacyAdded == legacyHandle.panel)
legacyHandle.Open()
equals("repli InterfaceOptions : deux appels d'ouverture", legacyOpened, 2)
_G.Settings = savedSettings
_G.InterfaceOptions_AddCategory = nil
_G.InterfaceOptionsFrame_OpenToCategory = nil

-- Template de slider absent : la fabrique rend nil, le panneau saute l'entree.
MISSING_TEMPLATES.OptionsSliderTemplate = true
check("CreateSlider sans template rend nil", UI.CreateSlider(CreateFrame("Frame"), "x", {}) == nil)
local noSlider = YS.BuildPanel(NewSpec())
check("sans slider : le panneau se construit", noSlider ~= nil)
check("sans slider : l'entree est sautee", noSlider.widgets.rows == nil and noSlider.widgets.mult == nil)
check("sans slider : les autres widgets sont la", noSlider.widgets.limit ~= nil and noSlider.widgets.mode ~= nil)
MISSING_TEMPLATES.OptionsSliderTemplate = nil

MISSING_TEMPLATES.InputBoxTemplate = true
check("CreateNumberInput sans template rend nil", UI.CreateNumberInput(CreateFrame("Frame"), "x", {}) == nil)
MISSING_TEMPLATES.InputBoxTemplate = nil

-- Menu API absente : repli sur UIDropDownMenuTemplate.
MENU_API_AVAILABLE = false
local legacyStore = { mode = "profit" }
local legacyDropdown = UI.CreateDropdown(CreateFrame("Frame"), "Tri", {
    choices = { { value = "standard", label = "Standard" }, { value = "profit", label = "Profit" } },
    get = function() return legacyStore.mode end,
    onSelect = function(value) legacyStore.mode = value end,
})
check("repli dropdown : un conteneur est rendu", legacyDropdown ~= nil)
equals("repli dropdown : isLegacy", legacyDropdown.isLegacy, true)
equals("repli dropdown : UIDropDownMenuTemplate", legacyDropdown.dropdown.__template, "UIDropDownMenuTemplate")
equals("repli dropdown : le texte est pousse", legacyDropdown.dropdown.__menuText, "Profit")
equals("repli dropdown : la largeur est posee", legacyDropdown.dropdown.__menuWidth, 160)
check("repli dropdown : l'initialiseur est enregistre", type(legacyDropdown.dropdown.__initializer) == "function")
UIDROPDOWN_ADDED = {}
legacyDropdown.dropdown.__initializer(legacyDropdown.dropdown, 1)
equals("repli dropdown : deux boutons ajoutes", #UIDROPDOWN_ADDED, 2)
equals("repli dropdown : le choix courant est coche", UIDROPDOWN_ADDED[2].checked, true)
UIDROPDOWN_ADDED[1].func()
equals("repli dropdown : selectionner ecrit la valeur", legacyStore.mode, "standard")
equals("repli dropdown : le texte suit la selection", legacyDropdown.dropdown.__menuText, "Standard")
local legacyPanel = YS.BuildPanel(NewSpec())
equals("repli dropdown dans un panneau : isLegacy", legacyPanel.widgets.mode.isLegacy, true)
MENU_API_AVAILABLE = true

-- Les deux templates de dropdown absents : entree sautee.
MISSING_TEMPLATES.WowStyle1DropdownTemplate = true
MISSING_TEMPLATES.UIDropDownMenuTemplate = true
check("sans aucun template de dropdown, la fabrique rend nil",
    UI.CreateDropdown(CreateFrame("Frame"), "x", {}) == nil)
MISSING_TEMPLATES.WowStyle1DropdownTemplate = nil
MISSING_TEMPLATES.UIDropDownMenuTemplate = nil

-- SetWidgetEnabled sur les conteneurs
UI.SetWidgetEnabled(W.limit, false)
equals("SetWidgetEnabled : la saisie est desactivee", W.limit.editBox:IsEnabled(), false)
equals("SetWidgetEnabled : le conteneur est attenue", W.limit:GetAlpha(), 0.45)
UI.SetWidgetEnabled(W.limit, true)
equals("SetWidgetEnabled : la saisie est reactivee", W.limit.editBox:IsEnabled(), true)
UI.SetWidgetEnabled(W.rows, false)
equals("SetWidgetEnabled : le slider est desactive", W.rows:IsEnabled(), false)
W.rows:SetEnabled(true)
equals("SetEnabled en style methode : le slider est reactive", W.rows:IsEnabled(), true)
UI.SetWidgetEnabled(W.rank, false)
equals("SetWidgetEnabled : les radios sont desactivees", W.rank.buttons[1]:IsEnabled(), false)
UI.SetWidgetEnabled(W.rank, true)

-- Sans CreateFrame : tout rend nil.
local savedCreateFrame = _G.CreateFrame
_G.CreateFrame = nil
check("sans CreateFrame, BuildPanel rend nil", YS.BuildPanel(NewSpec()) == nil)
check("sans CreateFrame, CreateSlider rend nil", UI.CreateSlider({}, "x") == nil)
check("sans CreateFrame, CreateNumberInput rend nil", UI.CreateNumberInput({}, "x") == nil)
check("sans CreateFrame, CreateDropdown rend nil", UI.CreateDropdown({}, "x") == nil)
_G.CreateFrame = savedCreateFrame

-- Un builder qui leve ne doit pas tuer le panneau ni figer ctx.refreshing.
local errorStore = { ok = true }
local errorHandle = YS.BuildPanel({
    name = "Err", framePrefix = "YayaErr", db = function() return errorStore end,
    options = {
        { key = "ok", label = "Sain" },
        { key = "boom", type = "slider", label = "Casse", min = 0, max = 1,
            get = function() error("get casse") end },
    },
})
check("un descripteur qui leve laisse le panneau debout", errorHandle ~= nil and errorHandle.widgets.ok ~= nil)
errorHandle.widgets.ok:SetChecked(false)
errorHandle.widgets.ok:GetScript("OnClick")(errorHandle.widgets.ok)
equals("apres une erreur de refresh, les clics passent toujours", errorStore.ok, false)

-- ---------------------------------------------------------------------------

print("")
print(("%d reussis, %d echoues"):format(passed, failed))
if failed > 0 then
    os.exit(1)
end
