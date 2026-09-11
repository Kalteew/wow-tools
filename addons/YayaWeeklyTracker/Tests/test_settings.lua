-- Reglages de YayaWeeklyTracker hors du jeu : descripteurs, panneau construit
-- par YayaCore.Settings, seuils lus par le tracker, verbosite du chat, ordre et
-- masquage des metiers.
--
-- Ce qui casse en silence en jeu, et que cette suite garde : un descripteur
-- sans defaut (le seuil rend nil dans une comparaison), un slider dont la valeur
-- ne redescend pas jusqu'au jeton KP, un message d'erreur avale par le mode
-- silencieux alors qu'une erreur fatale doit toujours passer, un ordre de
-- metiers change dans la base mais pas dans les lignes.
--
-- Ce que ce test ne couvre pas : les vraies mesures de frame et le rendu du
-- panneau dans la fenetre d'options du client.
--
-- Usage : lua5.1 Tests/test_settings.lua   (depuis addons/YayaWeeklyTracker)

dofile("Tests/wow_env.lua")

local ADDON_FILES = {
    "../YayaCore/YayaCore.lua",
    "../YayaCore/UI.lua",
    "../YayaCore/Settings.lua",
    "../YayaCore/ActionBinding.lua",
    "../YayaFrame/YayaFrame.lua",
    "YayaWeeklyTracker.lua",
}

for _, file in ipairs(ADDON_FILES) do
    local chunk, compileError = loadfile(file)
    if not chunk then
        print("ECHEC compilation " .. file .. " :: " .. tostring(compileError))
        os.exit(2)
    end
    local name = file:match("([^/\\]+)%.lua$")
    local ok, runtimeError = pcall(chunk, name, {})
    if not ok then
        print("ECHEC chargement " .. file .. " :: " .. tostring(runtimeError))
        os.exit(3)
    end
end

dofile("Tests/game_state.lua")

YayaWeeklyTrackerAccountDB = { debugEnabled = true }
YayaWeeklyTrackerDB = {}

FireEvent("ADDON_LOADED", "YayaCore")
FireEvent("ADDON_LOADED", "YayaFrame")
FireEvent("ADDON_LOADED", "YayaWeeklyTracker")
RunTimers(5)
FireEvent("PLAYER_ENTERING_WORLD")
RunTimers(5)
FireEvent("PLAYER_LOGIN")
RunTimers(5)

for _, event in ipairs({
    "SKILL_LINES_CHANGED",
    "SPELLS_CHANGED",
    "BAG_UPDATE_DELAYED",
    "PLAYER_EQUIPMENT_CHANGED",
    "TRADE_SKILL_SHOW",
    "QUEST_LOG_UPDATE",
}) do
    FireEvent(event)
    RunTimers(3)
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

-- La base du compte est relue a chaque acces : GetAccountDB la recree si un
-- test l'efface.
local function DB()
    return YayaWeeklyTrackerAccountDB
end

-- Les messages vides par un test sont archives : le bilan final les relit tous.
CHAT_ARCHIVE = {}
local function ResetChat()
    for _, message in ipairs(CHAT_MESSAGES or {}) do
        CHAT_ARCHIVE[#CHAT_ARCHIVE + 1] = message
    end
    CHAT_MESSAGES = {}
end

local function ChatContains(text)
    for _, message in ipairs(CHAT_MESSAGES or {}) do
        if message:find(text, 1, true) then
            return true
        end
    end
    return false
end

local function FindToken(tokens, prefix)
    for _, token in ipairs(tokens or {}) do
        if type(token.short) == "string" and token.short:find(prefix, 1, true) == 1 then
            return token
        end
    end
    return nil
end

local options = runtimeState.trackingOptions
local seams = runtimeState.testSeams
local NB = YayaCore.UI.TEXT.nbsp

-- ---------------------------------------------------------------------------
-- 1. Descripteurs et defauts
-- ---------------------------------------------------------------------------

print("")
print("Descripteurs")

local KNOWN_TYPES = { checkbox = true, slider = true, dropdown = true, orderlist = true }
local seenKeys, keyedCount, duplicates, unknownTypes = {}, 0, {}, {}
local missingDefaults, badSliders, badDropdowns, unfilled = {}, {}, {}, {}
local categories, categoryCount = {}, 0

for _, option in ipairs(options) do
    if option.category and not categories[option.category] then
        categories[option.category] = true
        categoryCount = categoryCount + 1
    end
    local key = option.key
    if key ~= nil then
        keyedCount = keyedCount + 1
        if seenKeys[key] then
            duplicates[#duplicates + 1] = key
        end
        seenKeys[key] = true
        if option.type ~= nil and not KNOWN_TYPES[option.type] then
            unknownTypes[#unknownTypes + 1] = key .. ":" .. tostring(option.type)
        end
        -- Le socle a recopie TRACKER_DEFAULTS[key] dans option.default a la
        -- construction : un defaut absent ici l'est des deux cotes.
        if option.default == nil and key ~= "professionOrder" then
            missingDefaults[#missingDefaults + 1] = key
        end
        if option.type == "slider" then
            local minValue, maxValue, default = tonumber(option.min), tonumber(option.max), tonumber(option.default)
            if not (minValue and maxValue and default and tonumber(option.step)
                and minValue <= default and default <= maxValue) then
                badSliders[#badSliders + 1] = key
            end
        elseif option.type == "dropdown" then
            local found = false
            for _, choice in ipairs(option.choices or {}) do
                if type(choice) ~= "table" or choice.value == nil or choice.label == nil then
                    found = false
                    break
                end
                if choice.value == option.default then
                    found = true
                end
            end
            if not found then
                badDropdowns[#badDropdowns + 1] = key
            end
        end
        if option.default ~= nil and DB()[key] == nil then
            unfilled[#unfilled + 1] = key
        end
    end
end

check("au moins quarante reglages a cle", keyedCount >= 40, keyedCount)
check("aucune cle en double", #duplicates == 0, table.concat(duplicates, ", "))
check("chaque type est connu du socle", #unknownTypes == 0, table.concat(unknownTypes, ", "))
check("chaque reglage a un defaut (sauf professionOrder)", #missingDefaults == 0, table.concat(missingDefaults, ", "))
check("sliders : min <= defaut <= max, pas present", #badSliders == 0, table.concat(badSliders, ", "))
check("dropdowns : le defaut est un des choix, chaque choix a value et label", #badDropdowns == 0, table.concat(badDropdowns, ", "))
check("apres PLAYER_LOGIN, chaque cle a defaut est ecrite dans la base", #unfilled == 0, table.concat(unfilled, ", "))
check("professionOrder reste nil tant que rien n'est choisi", DB().professionOrder == nil)

local orderDesc
for _, option in ipairs(options) do
    if option.key == "professionOrder" then
        orderDesc = option
    end
end
check("professionOrder est une orderlist", orderDesc and orderDesc.type == "orderlist")
equals("professionOrder masque via hiddenProfessions", orderDesc and orderDesc.hiddenKey, "hiddenProfessions")
equals("professionOrder porte l'effet professions", orderDesc and orderDesc.effect, "professions")
check("professionOrder a un fournisseur d'items", orderDesc and type(orderDesc.items) == "function")
equals("le fournisseur rend les onze metiers Midnight", orderDesc and #orderDesc.items() or 0, 11)

-- ---------------------------------------------------------------------------
-- 2. Panneau
-- ---------------------------------------------------------------------------

print("")
print("Panneau")

local handle = runtimeState.options
check("runtimeState.options est pose apres PLAYER_LOGIN", type(handle) == "table")
if type(handle) ~= "table" then
    print("Panneau absent : arret")
    print(("%d reussite(s), %d echec(s)"):format(passed, failed))
    os.exit(1)
end

equals("une categorie de panneau par categorie de descripteur", #handle.categories, categoryCount)
equals("douze categories", #handle.categories, 12)
equals("le rail porte un bouton par categorie", #handle.railButtons, 12)
equals("la premiere categorie est Affichage", handle.categories[1], "Affichage")
check("runtimeState.optionsPanel est le panneau du socle", runtimeState.optionsPanel == handle.panel)
equals("le panneau porte le prefixe de l'addon", handle.panel:GetName(), "YayaWeeklyTrackerOptionsPanel")
equals("le panneau porte son nom", handle.panel.name, "Yaya Weekly Tracker")
check("la categorie Blizzard est enregistree", handle.category ~= nil and handle.category.added == true)
check("runtimeState.optionsCategory suit le handle", runtimeState.optionsCategory == handle.category)
equals("une seule categorie enregistree", #SETTINGS_REGISTERED_CATEGORIES, 1)

local W = handle.widgets
check("widget chatVerbosity (dropdown)", W.chatVerbosity ~= nil)
check("widget professionOrder (orderlist)", W.professionOrder ~= nil)
check("widget trackJard (checkbox)", W.trackJard ~= nil)
check("widget unspentKnowledgeWarningThreshold (slider)", W.unspentKnowledgeWarningThreshold ~= nil)
check("widget professionGearMinimumQuality (dropdown)", W.professionGearMinimumQuality ~= nil)
equals("le dropdown n'est pas en repli", W.chatVerbosity and W.chatVerbosity.isLegacy, false)
equals("l'orderlist a onze lignes", W.professionOrder and #W.professionOrder.rows or 0, 11)
equals("la premiere ligne est l'alchimie", W.professionOrder and W.professionOrder.rows[1].id, 2906)

-- Case a cocher : la db suit et un rafraichissement est planifie.
RunTimers(5)
PENDING_TIMERS = {}
equals("trackJard vaut true au depart", DB().trackJard, true)
W.trackJard:SetChecked(false)
W.trackJard:GetScript("OnClick")(W.trackJard)
equals("decocher trackJard ecrit false", DB().trackJard, false)
check("un rafraichissement est planifie", #(PENDING_TIMERS or {}) > 0)
equals("le widget relu reste decoche apres la resynchronisation", W.trackJard:GetChecked(), false)
RunTimers(5)
W.trackJard:SetChecked(true)
W.trackJard:GetScript("OnClick")(W.trackJard)
equals("recocher trackJard ecrit true", DB().trackJard, true)

-- Slider : la valeur descend dans la db.
local slider = W.unspentKnowledgeWarningThreshold
equals("le slider part du defaut", slider.GetValueRounded(), 5)
slider:GetScript("OnValueChanged")(slider, 1)
equals("OnValueChanged(1) ecrit 1", DB().unspentKnowledgeWarningThreshold, 1)
slider:GetScript("OnValueChanged")(slider, 99)
equals("le slider clampe a son max", DB().unspentKnowledgeWarningThreshold, 50)
slider:GetScript("OnValueChanged")(slider, 5)
equals("retour au defaut", DB().unspentKnowledgeWarningThreshold, 5)

-- Dropdown : les choix du menu ecrivent la db.
local root = W.chatVerbosity.dropdown:OpenMenu()
equals("le menu porte trois choix", #root.entries, 3)
equals("le premier choix est Silencieux", root.entries[1].label, "Silencieux")
equals("Normal est selectionne", root.entries[2].isSelected(), true)
root:Select(1)
equals("choisir Silencieux ecrit silent", DB().chatVerbosity, "silent")
root:Select(2)
equals("choisir Normal ecrit normal", DB().chatVerbosity, "normal")

-- Resynchronisation : OnShow relit la base sans la reecrire.
DB().trackJard = false
DB().unspentKnowledgeWarningThreshold = 7
handle.panel:GetScript("OnShow")(handle.panel)
equals("OnShow relit la case", W.trackJard:GetChecked(), false)
equals("OnShow relit le slider", slider.GetValueRounded(), 7)
equals("OnShow ne reecrit pas la base", DB().unspentKnowledgeWarningThreshold, 7)
DB().trackJard = true
DB().unspentKnowledgeWarningThreshold = 5
handle.Refresh()

-- /ywt options ouvre la categorie enregistree.
SETTINGS_OPENED_CATEGORY = nil
SlashCmdList.YAYAWEEKLYTRACKER("options")
equals("/ywt options ouvre la categorie du socle", SETTINGS_OPENED_CATEGORY, 1)

-- ---------------------------------------------------------------------------
-- 3. Seuil KP lu par le tracker
-- ---------------------------------------------------------------------------

print("")
print("Seuil KP")

local rows = seams.GetTrackedProfessions()
equals("un metier suivi", #rows, 1)
equals("c'est l'alchimie", rows[1] and rows[1].skillLineID, 2906)
local tokens = seams.BuildTokens(rows[1])
check("3 KP sous le seuil 5 : aucun jeton KP", FindToken(tokens, "KP") == nil)

DB().unspentKnowledgeWarningThreshold = 1
FireEvent("TRAIT_CONFIG_UPDATED")
RunTimers(5)
rows = seams.GetTrackedProfessions()
tokens = seams.BuildTokens(rows[1])
local kp = FindToken(tokens, "KP")
check("3 KP au-dessus du seuil 1 : jeton KP present", kp ~= nil)
equals("le jeton dit KP 3", kp and kp.short, "KP" .. NB .. "3")
equals("le jeton est en danger", kp and kp.tone, "danger")

DB().unspentKnowledgeWarningThreshold = 5
FireEvent("TRAIT_CONFIG_UPDATED")
RunTimers(5)
tokens = seams.BuildTokens(seams.GetTrackedProfessions()[1])
check("retour au seuil 5 : le jeton disparait", FindToken(tokens, "KP") == nil)

-- ---------------------------------------------------------------------------
-- 4. Ordre et masquage des metiers
-- ---------------------------------------------------------------------------

print("")
print("Ordre et masquage")

DB().hiddenProfessions = { [2906] = true }
FireEvent("SKILL_LINES_CHANGED")
RunTimers(5)
equals("l'alchimie masquee ne laisse aucune ligne", #seams.GetTrackedProfessions(), 0)

DB().hiddenProfessions = nil
LearnInscriptionFixture()
DB().professionOrder = { 2913, 2906 }
-- Ecriture directe dans la base : le rang est mis en cache jusqu'au prochain
-- changement d'option, on l'efface comme le ferait ApplySettingChange.
runtimeState.professionRankByID = nil
FireEvent("SKILL_LINES_CHANGED")
RunTimers(5)
rows = seams.GetTrackedProfessions()
equals("deux metiers suivis", #rows, 2)
equals("l'inscription passe en tete", rows[1] and rows[1].skillLineID, 2913)
equals("l'alchimie suit", rows[2] and rows[2].skillLineID, 2906)

-- Le widget rejoue l'ordre de la base, puis un clic sur v echange les lignes.
handle.Refresh()
local list = W.professionOrder
equals("orderlist : la premiere ligne est l'inscription", list.rows[1].id, 2913)
equals("orderlist : la seconde est l'alchimie", list.rows[2].id, 2906)
PENDING_TIMERS = {}
list.rows[1].down:GetScript("OnClick")(list.rows[1].down)
equals("v sur la premiere ligne : l'alchimie repasse en tete", DB().professionOrder[1], 2906)
equals("v sur la premiere ligne : l'inscription passe seconde", DB().professionOrder[2], 2913)
equals("la liste normalisee est stockee entiere", #DB().professionOrder, 11)
equals("les lignes sont redessinees", list.rows[1].id, 2906)
check("un rafraichissement est planifie", #(PENDING_TIMERS or {}) > 0)
RunTimers(5)
rows = seams.GetTrackedProfessions()
equals("les lignes de metier suivent le nouvel ordre", rows[1] and rows[1].skillLineID, 2906)

list.rows[1].check:SetChecked(false)
list.rows[1].check:GetScript("OnClick")(list.rows[1].check)
equals("decocher masque l'alchimie", DB().hiddenProfessions and DB().hiddenProfessions[2906], true)
RunTimers(5)
rows = seams.GetTrackedProfessions()
equals("une seule ligne reste", #rows, 1)
equals("c'est l'inscription", rows[1] and rows[1].skillLineID, 2913)
list.rows[1].check:SetChecked(true)
list.rows[1].check:GetScript("OnClick")(list.rows[1].check)
check("recocher retire la cle", DB().hiddenProfessions[2906] == nil)
RunTimers(5)
equals("les deux lignes reviennent", #seams.GetTrackedProfessions(), 2)

-- ---------------------------------------------------------------------------
-- 5. Verbosite du chat
-- ---------------------------------------------------------------------------

print("")
print("Verbosite")

DB().chatVerbosity = "silent"
ResetChat()
SlashCmdList.YAYAWEEKLYTRACKER("help")
check("silent : la reponse a /ywt help s'affiche", ChatContains("/ywt options"))

-- Erreur reelle : le bouton d'approvisionnement (Warbank puis YayaQueue) sans YayaQueue.
local gearButton = _G.YayaWeeklyTrackerProfessionSupplyButton
check("le bouton d'approvisionnement existe", gearButton ~= nil)
local savedQueue = YayaQueueAPI
YayaQueueAPI = nil
ResetChat()
gearButton:GetScript("OnClick")(gearButton, "LeftButton", false)
check("silent : l'erreur YayaQueue absent est tue", not ChatContains("YayaQueue n'est pas disponible"))
DB().chatVerbosity = "normal"
ResetChat()
gearButton:GetScript("OnClick")(gearButton, "LeftButton", false)
check("normal : l'erreur YayaQueue absent s'affiche", ChatContains("YayaQueue n'est pas disponible"))
YayaQueueAPI = savedQueue

-- Action reelle : une weekly d'enchantement rendue retire ses reactifs de la file.
local weeklyQuestID = next(runtimeState.midnightEnchantingWeeklyReagents)
check("une weekly d'enchantement est connue", weeklyQuestID ~= nil)
DB().chatVerbosity = "normal"
ResetChat()
FireEvent("QUEST_TURNED_IN", weeklyQuestID)
RunTimers(3)
check("normal : l'action de retrait est tue", not ChatContains("weekly rendue"))
DB().chatVerbosity = "verbose"
ResetChat()
FireEvent("QUEST_TURNED_IN", weeklyQuestID)
RunTimers(3)
check("verbose : l'action de retrait s'affiche", ChatContains("weekly rendue"))

-- Une erreur fatale passe toujours, meme en silencieux.
DB().chatVerbosity = "silent"
ResetChat()
runtimeState.LogFatalDiagnostic("boom test")
check("silent : une erreur fatale s'affiche quand meme", ChatContains("boom test"))
DB().chatVerbosity = "normal"

-- ---------------------------------------------------------------------------
-- Bilan : aucune erreur avalee pendant toute la suite
-- ---------------------------------------------------------------------------

print("")
print("Bilan")

ResetChat()
local swallowed = {}
for _, message in ipairs(CHAT_ARCHIVE) do
    local clean = message:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    if clean:find("%.lua:%d") or clean:lower():find("attempt to") then
        swallowed[#swallowed + 1] = clean
    end
end
check("aucune erreur Lua dans le chat", #swallowed == 0, swallowed[1])
check("aucune erreur non capturee", #(UNCAUGHT or {}) == 0, (UNCAUGHT or {})[1])
local fatals = {}
for _, entry in ipairs(DB().debugLog or {}) do
    if entry:find("YWT FATAL", 1, true) and not entry:find("boom test", 1, true) then
        fatals[#fatals + 1] = entry
    end
end
check("aucun diagnostic fatal journalise", #fatals == 0, fatals[1])

print("")
print(("%d reussite(s), %d echec(s)"):format(passed, failed))
if failed > 0 then
    os.exit(1)
end
