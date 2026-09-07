-- Charge la suite Yaya complete hors du jeu, puis rejoue le cycle de
-- rafraichissement sur un personnage alchimiste equipe. Le tracker enrobe
-- UpdateTracker dans un pcall et remplace son contenu par une ligne d'erreur
-- rouge quand il echoue : cette suite echoue si ce cas se produit, car en jeu
-- l'erreur est tronquee par la largeur de la frame et passe facilement pour un
-- simple probleme d'affichage.
--
-- Ce que ce test ne couvre pas : les vraies mesures de frame, les boutons
-- securises et tout ce qui depend du client. Il attrape les erreurs de logique
-- du cycle de rafraichissement, pas les regressions visuelles.

dofile("Tests/wow_env.lua")

local ADDON_FILES = {
    "../YayaCore/YayaCore.lua",
    "../YayaCore/UI.lua",
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

-- L'etat de jeu est applique apres le chargement : il ecrase les stubs neutres
-- par des donnees exploitables (metier Midnight appris, emplacements de metier
-- garnis, sacs, YayaQueue present).
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
    "PLAYER_AVG_ITEM_LEVEL_UPDATE",
    "TRADE_SKILL_SHOW",
    "QUEST_LOG_UPDATE",
    "BANKFRAME_OPENED",
    "BANKFRAME_CLOSED",
}) do
    FireEvent(event)
    RunTimers(3)
end

local failures = 0

local function Fail(reason)
    failures = failures + 1
    print("ECHEC :: " .. reason)
end

-- 1. Aucune erreur, ni fatale ni avalee par les pcall internes.
for _, message in ipairs(CHAT_MESSAGES or {}) do
    local clean = message:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    if clean:find("%.lua:%d") or clean:lower():find("attempt to") then
        Fail("erreur pendant le rafraichissement :: " .. clean)
    end
end
for _, entry in ipairs(UNCAUGHT or {}) do
    Fail("erreur non capturee :: " .. entry)
end
for _, entry in ipairs((YayaWeeklyTrackerAccountDB or {}).debugLog or {}) do
    if entry:find("YWT FATAL", 1, true) then
        Fail("diagnostic fatal journalise :: " .. entry)
    end
end

-- 2. Le scan de l'equipement de metier a bien tourne et rendu un verdict.
local gearTrace
for _, entry in ipairs((YayaWeeklyTrackerAccountDB or {}).debugLog or {}) do
    if entry:find("gear%[2906%]") then
        gearTrace = entry
    end
end
if not gearTrace then
    Fail("aucune trace de scan d'equipement de metier : le test ne couvre plus rien")
else
    -- L'etat de jeu equipe un outil conforme, un accessoire sous le seuil et
    -- laisse le second emplacement d'accessoire vide.
    if not gearTrace:find("bad=2") then
        Fail("comptage d'emplacements inattendu :: " .. gearTrace)
    end
    if not gearTrace:find("tool=true") then
        Fail("un outil conforme est possede mais n'est pas reconnu :: " .. gearTrace)
    end
    if not gearTrace:find("mcBag=true") then
        Fail("l'outil Multicrafting en sac n'est pas vu :: " .. gearTrace)
    end
end

if failures > 0 then
    print(("%d echec(s)"):format(failures))
    os.exit(1)
end

print("test_tracker_refresh : rafraichissement sans erreur, scan d'equipement conforme")
