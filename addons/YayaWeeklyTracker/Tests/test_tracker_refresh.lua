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
    -- L'exemplaire Multicrafting dort en sac a l'ilvl 206 : possede, donc vu,
    -- mais sous le seuil, donc l'achat reste a faire.
    if not gearTrace:find("mcOwned=true") then
        Fail("l'outil Multicrafting en sac n'est pas vu :: " .. gearTrace)
    end
    if not gearTrace:find("mcOk=false") then
        Fail("un outil Multicrafting ilvl 206 passe pour conforme :: " .. gearTrace)
    end
end

-- 3. Le plan d'achat vise bien une variante, et emmene l'enchantement avec.
--
-- L'etat de jeu porte exactement le cas qui motive tout : l'outil equipe est un
-- Resourcefulness rang maximal (rien a acheter de ce cote), mais l'exemplaire
-- Multicrafting garde en sac est ilvl 206. Le plan doit donc demander un outil
-- Multicrafting ilvl >= 232 -- pas l'itemID nu, qui rendrait le rang 1 -- et
-- l'enchantement Multicraft (243995) avec lui. Les deux emplacements
-- d'accessoire fautifs completent le plan, sur le rang seul.
local planTrace
for _, entry in ipairs((YayaWeeklyTrackerAccountDB or {}).debugLog or {}) do
    if entry:find("Profession gear plan", 1, true) then
        planTrace = entry
    end
end
if not planTrace then
    Fail("aucune trace de plan d'achat d'equipement : le test ne couvre plus rien")
else
    if not planTrace:find("multicrafting:232", 1, true) then
        Fail("l'outil Multicrafting n'est pas demande sur sa variante :: " .. planTrace)
    end
    if not planTrace:find("1x243995/enchant", 1, true) then
        Fail("l'enchantement Multicraft ne part pas avec l'outil :: " .. planTrace)
    end
    if planTrace:find("resourcefulness:", 1, true) then
        Fail("un outil Resourcefulness conforme est possede, il ne doit rien declencher :: " .. planTrace)
    end
    -- Deux accessoires fautifs : l'un sous le seuil, l'autre absent.
    if not planTrace:find("rank:232", 1, true) then
        Fail("les accessoires ne sont pas demandes sur le rang :: " .. planTrace)
    end
    if not planTrace:find("gear=3 ench=1", 1, true) then
        Fail("le decompte du plan est inattendu :: " .. planTrace)
    end
    if planTrace:find("unknownStats=[1-9]") then
        Fail("une statistique demandee n'a pas de bonusId connu :: " .. planTrace)
    end
end

-- 4. Un outil Multicrafting EQUIPE satisfait l'exigence autant qu'un outil
-- garde en sac.
--
-- YayaQueue equipe l'outil Multicrafting depuis les sacs avant les crafts qui
-- multicraftent, mais l'echange renvoie en sac l'outil qui sort : porter
-- l'exemplaire Multicrafting revient au meme, il est meme deja en place. Juger
-- sur la seule presence en sac faisait reclamer un second exemplaire des que le
-- premier etait porte, et le plan d'achat en achetait un doublon.
EquipMulticraftToolFixture()
FireEvent("PLAYER_EQUIPMENT_CHANGED")
FireEvent("BAG_UPDATE_DELAYED")
RunTimers(5)

local swappedGearTrace, swappedPlanTrace
for _, entry in ipairs((YayaWeeklyTrackerAccountDB or {}).debugLog or {}) do
    if entry:find("gear%[2906%]") then
        swappedGearTrace = entry
    end
    if entry:find("Profession gear plan", 1, true) then
        swappedPlanTrace = entry
    end
end
if not swappedGearTrace then
    Fail("aucune trace de scan d'equipement apres l'echange d'outil")
else
    if not swappedGearTrace:find("mcOwned=true") or not swappedGearTrace:find("mcOk=true") then
        Fail("l'outil Multicrafting equipe n'est pas reconnu conforme :: " .. swappedGearTrace)
    end
    if not swappedGearTrace:find("needs=none", 1, true) then
        Fail("un besoin d'outil subsiste alors que les deux statistiques sont possedees :: "
            .. swappedGearTrace)
    end
end
if not swappedPlanTrace then
    Fail("aucune trace de plan d'achat apres l'echange d'outil")
else
    if swappedPlanTrace:find("multicrafting:", 1, true) then
        Fail("un outil Multicrafting conforme est equipe, il ne doit rien declencher :: "
            .. swappedPlanTrace)
    end
    -- Restent les deux accessoires, sur le rang seul, et plus aucun
    -- enchantement d'outil a acheter puisque plus aucun outil n'est demande.
    if not swappedPlanTrace:find("gear=2 ench=0", 1, true) then
        Fail("le decompte du plan est inattendu apres l'echange d'outil :: " .. swappedPlanTrace)
    end
end

if failures > 0 then
    print(("%d echec(s)"):format(failures))
    os.exit(1)
end

print("test_tracker_refresh : rafraichissement sans erreur, scan d'equipement conforme, plan d'achat par variante, outil Multicrafting equipe reconnu")
