-- Ouvertures de metier faites par le tracker lui-meme, vues des autres addons.
--
-- YayaWeeklyTracker ouvre des metiers sans action du joueur : l'amorcage des
-- donnees au login (ArmTradeSkillBootstrap / FinishTradeSkillBootstrap) et le
-- plan de depense des points de connaissance (YayaWeeklyTrackerSpecPlan).
-- YayaQueue et YayaCraftingOrders lancent leurs automatismes a chaque
-- TRADE_SKILL_SHOW ; sur ces ouvertures-la les cooldowns et les charges ne sont
-- pas chargees, et leur marqueur "une fois par session" serait consomme pour
-- mettre en file des recettes irrealisables. Ils interrogent donc
-- YayaWeeklyTrackerAPI.IsProgrammaticTradeSkillOpen.
--
-- Ce que la suite garde, dans l'ordre d'importance :
--
--  1. le drapeau est vrai AVANT l'appel OpenTradeSkill, donc quand les autres
--     addons recoivent TRADE_SKILL_SHOW dans le meme frame ;
--  2. il reste vrai pendant une grace de 1,5 s APRES la fermeture : les
--     callbacks C_Timer.After(0) des autres addons tournent apres elle, et c'est
--     eux qui lancaient les automatismes ;
--  3. il ne reste JAMAIS coince a vrai -- appel refuse, appel ignore par le
--     client, timer qui ne tourne pas -- car il fermerait tous les automatismes
--     jusqu'au /reload, sans le moindre message ;
--  4. une ouverture du JOUEUR n'est jamais prise pour une ouverture du tracker.
--
-- Ce que ce test ne couvre pas : le comportement du client lui-meme (ordre reel
-- des evenements) et les consommateurs, YayaQueue et YayaCraftingOrders.
--
-- Usage : lua5.1 Tests/test_programmatic_open.lua   (depuis addons/YayaWeeklyTracker)

dofile("Tests/wow_env.lua")

--------------------------------------------------------------------------------
-- Horloge pilotable
--
-- Posee AVANT le chargement des modules. Le tracker lit GetTime a chaque appel
-- (jamais time()) : c'est ce qui permet de faire expirer une grace sans attendre.
--------------------------------------------------------------------------------

local clock = 1000.0

function GetTime()
    return clock
end

local function Advance(seconds)
    clock = clock + seconds
end

--------------------------------------------------------------------------------
-- Chargement, dans l'ordre du TOC
--------------------------------------------------------------------------------

local OPEN_CALLS = {}
local CLOSE_CALLS = 0
local OPEN_MODE = "ok"
local flagDuringOpen
local showDuringOpen = false

-- Le tracker n'amorce l'ouverture que si le client expose OpenTradeSkill.
C_TradeSkillUI.OpenTradeSkill = function(id)
    OPEN_CALLS[#OPEN_CALLS + 1] = id
    flagDuringOpen = _G.YayaWeeklyTrackerAPI
        and _G.YayaWeeklyTrackerAPI.IsProgrammaticTradeSkillOpen() or nil
    if OPEN_MODE == "error" then
        error("OpenTradeSkill refuse")
    end
    -- Le client peut emettre TRADE_SKILL_SHOW pendant l'appel meme.
    if OPEN_MODE == "ok" and showDuringOpen then
        FireEvent("TRADE_SKILL_SHOW")
    end
    -- "ignored" : le client ignore l'appel en silence, sans evenement.
end
C_TradeSkillUI.CloseTradeSkill = function()
    CLOSE_CALLS = CLOSE_CALLS + 1
end

local ADDON_FILES = {
    "../YayaCore/YayaCore.lua",
    "../YayaCore/UI.lua",
    "../YayaCore/Settings.lua",
    "../YayaCore/ActionBinding.lua",
    "../YayaFrame/YayaFrame.lua",
    "YayaWeeklyTracker.lua",
    "YayaWeeklyTrackerSpecPlan.lua",
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

-- Pas de game_state.lua : un personnage Midnight deja suivi desarmerait
-- l'amorcage, qui n'existe que tant qu'aucune ligne de metier n'est lisible.
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

--------------------------------------------------------------------------------
-- Harnais
--------------------------------------------------------------------------------

local failures = 0
local checks = 0

local function Check(label, condition, detail)
    checks = checks + 1
    if condition then
        print("  OK    " .. label)
    else
        failures = failures + 1
        print("  ECHEC " .. label .. (detail and (" :: " .. tostring(detail)) or ""))
    end
end

local API = _G.YayaWeeklyTrackerAPI
local specPlan = _G.YayaWeeklyTrackerSpecPlan

local function IsOpen()
    return API.IsProgrammaticTradeSkillOpen()
end

--- La frame d'evenements du tracker : seule a ecouter TRADE_SKILL_SHOW et a
-- porter l'amorce clavier.
local function FindBootstrapFrame()
    for _, frame in ipairs(ALL_FRAMES) do
        if frame.__scripts
            and type(frame.__scripts.OnKeyDown) == "function"
            and frame.__events
            and frame.__events.TRADE_SKILL_SHOW then
            return frame
        end
    end
    return nil
end

--- Un autre addon : il lit le drapeau a la reception de l'evenement puis dans un
-- callback After(0), comme YayaQueue et YayaCraftingOrders. Cree APRES le
-- tracker, donc servi apres lui : son After(0) passe derriere celui du tracker,
-- qui ferme le metier. C'est le pire cas que la grace doit couvrir.
local spyLog = {}
local spy = CreateFrame("Frame", "ProgrammaticOpenSpy")
spy:RegisterEvent("TRADE_SKILL_SHOW")
spy:RegisterEvent("TRADE_SKILL_DATA_SOURCE_CHANGED")
spy:SetScript("OnEvent", function(_, event)
    local entry = { event = event, atEvent = IsOpen() }
    spyLog[#spyLog + 1] = entry
    C_Timer.After(0, function()
        entry.deferred = IsOpen()
        entry.pendingByThen = runtimeState.tradeSkillBootstrapPending
    end)
end)

--- Rearme l'amorce du tracker, comme au prochain login, et rend sa frame.
local function RearmBootstrap()
    runtimeState.tradeSkillBootstrapAttempted = false
    runtimeState.tradeSkillBootstrapPending = false
    runtimeState.tradeSkillBootstrapArmed = false
    runtimeState.tradeSkillBootstrapStartedAt = nil
    runtimeState.tradeSkillProgrammaticGraceUntil = nil
    FireEvent("SKILL_LINES_CHANGED")
    RunTimers(5)
    return FindBootstrapFrame()
end

--- Simule le premier appui clavier qui declenche l'ouverture.
local function PressKey(frame)
    local handler = frame.__scripts.OnKeyDown
    handler(frame, "A")
end

local function ResetCalls()
    OPEN_CALLS = {}
    CLOSE_CALLS = 0
    flagDuringOpen = nil
    spyLog = {}
    PENDING_TIMERS = {}
end

--------------------------------------------------------------------------------
print("\nContrat de l'API")
--------------------------------------------------------------------------------

Check("l'API est exposee", type(API) == "table")
Check("IsProgrammaticTradeSkillOpen est une fonction",
    type(API) == "table" and type(API.IsProgrammaticTradeSkillOpen) == "function")
Check("le plan de spe expose son etat d'ouverture",
    type(specPlan.IsOpeningProfession) == "function")
Check("et le relais de TRADE_SKILL_SHOW que le tracker lui envoie",
    type(specPlan.NotifyTradeSkillShown) == "function")
Check("la fonction rend un booleen", type(IsOpen()) == "boolean", type(IsOpen()))
Check("au repos, le drapeau est faux", IsOpen() == false)
Check("l'amorce est armee par PLAYER_LOGIN", FindBootstrapFrame() ~= nil)

--------------------------------------------------------------------------------
print("\nAmorcage : ouverture normale")
--------------------------------------------------------------------------------

ResetCalls()
OPEN_MODE = "ok"
showDuringOpen = false
local frame = FindBootstrapFrame()
Check("armee, l'amorce n'a encore rien ouvert", #OPEN_CALLS == 0 and IsOpen() == false)

PressKey(frame)
Check("OpenTradeSkill est appele une fois", #OPEN_CALLS == 1, #OPEN_CALLS)
Check("le drapeau est vrai PENDANT l'appel : pose avant OpenTradeSkill",
    flagDuringOpen == true, flagDuringOpen)
Check("amorce en attente : vrai", runtimeState.tradeSkillBootstrapPending == true and IsOpen() == true)

-- Le client montre le metier, un frame plus tard : le tracker programme sa
-- fermeture, l'autre addon lit le drapeau et programme son propre callback.
FireEvent("TRADE_SKILL_SHOW")
Check("a la reception de TRADE_SKILL_SHOW, un autre addon lit vrai",
    spyLog[1] and spyLog[1].atEvent == true, spyLog[1] and spyLog[1].atEvent)

RunTimers(1)
Check("le tracker a ferme le metier", CLOSE_CALLS == 1, CLOSE_CALLS)
Check("l'amorce n'est plus en attente", runtimeState.tradeSkillBootstrapPending == false)
Check("le callback After(0) de l'autre addon passe APRES la fermeture",
    spyLog[1] and spyLog[1].pendingByThen == false, spyLog[1] and spyLog[1].pendingByThen)
Check("... et lit encore vrai : c'est la grace",
    spyLog[1] and spyLog[1].deferred == true, spyLog[1] and spyLog[1].deferred)
Check("juste apres la fermeture : vrai", IsOpen() == true)

Advance(1.4)
Check("1,4 s apres la fermeture : encore vrai", IsOpen() == true)
Advance(0.2)
Check("1,6 s apres : retombe", IsOpen() == false)

-- Les deux filets partent du meme appel : celui qui arrive en second ne doit ni
-- fermer une seconde fois ni prolonger la grace.
RunTimers(5)
Check("le filet de 2 s, arrive en retard, ne referme rien", CLOSE_CALLS == 1, CLOSE_CALLS)
Check("et ne releve pas le drapeau", IsOpen() == false)

--------------------------------------------------------------------------------
print("\nAmorcage : TRADE_SKILL_SHOW emis pendant l'appel meme")
--------------------------------------------------------------------------------

ResetCalls()
frame = RearmBootstrap()
Check("l'amorce se rearme", frame ~= nil)
showDuringOpen = true
PressKey(frame)
showDuringOpen = false
Check("l'autre addon a lu vrai alors que l'appel n'etait pas termine",
    spyLog[1] and spyLog[1].atEvent == true, spyLog[1] and spyLog[1].atEvent)
RunTimers(1)
Check("le callback differe lit encore vrai", spyLog[1] and spyLog[1].deferred == true)
Advance(1.6)
Check("la grace expire", IsOpen() == false)
RunTimers(5)

--------------------------------------------------------------------------------
print("\nAmorcage : OpenTradeSkill echoue")
--------------------------------------------------------------------------------

ResetCalls()
frame = RearmBootstrap()
Check("l'amorce se rearme", frame ~= nil)
OPEN_MODE = "error"
PressKey(frame)
OPEN_MODE = "ok"
Check("l'appel a bien eu lieu", #OPEN_CALLS == 1, #OPEN_CALLS)
Check("le drapeau etait leve pendant l'appel", flagDuringOpen == true)
Check("l'amorce n'est pas restee en attente", runtimeState.tradeSkillBootstrapPending == false)
Check("le drapeau retombe sur-le-champ : rien ne s'est ouvert", IsOpen() == false)
Check("aucune grace n'est posee pour une ouverture qui n'a pas eu lieu",
    runtimeState.tradeSkillProgrammaticGraceUntil == nil
        or runtimeState.tradeSkillProgrammaticGraceUntil <= clock,
    runtimeState.tradeSkillProgrammaticGraceUntil)
RunTimers(5)
Check("et les timers qui suivent n'y changent rien", IsOpen() == false)
Advance(60)
Check("une minute plus tard : toujours faux", IsOpen() == false)
Check("le tracker n'a rien ferme", CLOSE_CALLS == 0, CLOSE_CALLS)

--------------------------------------------------------------------------------
print("\nAmorcage : appel ignore en silence par le client")
--------------------------------------------------------------------------------

ResetCalls()
frame = RearmBootstrap()
OPEN_MODE = "ignored"
local t0 = clock
PressKey(frame)
OPEN_MODE = "ok"
Check("amorce en attente : vrai", IsOpen() == true)
Advance(1.9)
Check("1,9 s sans evenement : le filet de 2 s n'a pas encore joue, vrai", IsOpen() == true)
Advance(0.1)
RunTimers(1)
Check("2 s : le filet ferme et libere l'amorce", runtimeState.tradeSkillBootstrapPending == false)
Check("la fermeture a eu lieu (par precaution)", CLOSE_CALLS == 1, CLOSE_CALLS)
Check("la grace court ensuite : vrai", IsOpen() == true)
Advance(1.4)
Check("1,4 s apres le filet : vrai", IsOpen() == true)
Advance(0.2)
Check("1,6 s apres le filet : faux, au plus 3,6 s en tout", IsOpen() == false, clock - t0)

--------------------------------------------------------------------------------
print("\nAmorcage : le timer de securite ne tourne jamais")
--------------------------------------------------------------------------------

-- Plafond de secours. Aucun timer n'est execute : l'amorce reste "en attente"
-- pour de bon, et le drapeau doit pourtant retomber.
ResetCalls()
frame = RearmBootstrap()
OPEN_MODE = "ignored"
t0 = clock
PressKey(frame)
OPEN_MODE = "ok"
PENDING_TIMERS = {}
Check("en attente : vrai", IsOpen() == true)
Advance(3.4)
Check("3,4 s : sous le plafond (2 s + 1,5 s), vrai", IsOpen() == true)
Advance(0.2)
Check("3,6 s : le plafond joue, faux",
    IsOpen() == false, clock - t0)
Check("alors que l'amorce se croit toujours en attente",
    runtimeState.tradeSkillBootstrapPending == true)
runtimeState.tradeSkillBootstrapPending = false
PENDING_TIMERS = {}

--------------------------------------------------------------------------------
print("\nUne ouverture du joueur n'est jamais prise pour celle du tracker")
--------------------------------------------------------------------------------

ResetCalls()
Advance(10)
FireEvent("TRADE_SKILL_SHOW")
RunTimers(3)
Check("le joueur ouvre un metier a la main : faux", IsOpen() == false)
Check("l'autre addon lit faux a la reception",
    spyLog[1] and spyLog[1].atEvent == false, spyLog[1] and spyLog[1].atEvent)
Check("et dans son callback differe",
    spyLog[1] and spyLog[1].deferred == false, spyLog[1] and spyLog[1].deferred)
Check("le tracker ne ferme rien qu'il n'ait pas ouvert", CLOSE_CALLS == 0, CLOSE_CALLS)

FireEvent("TRADE_SKILL_DATA_SOURCE_CHANGED")
RunTimers(3)
Check("changement de source de donnees a la main : faux", IsOpen() == false)

--------------------------------------------------------------------------------
print("\nPlan de specialisation : source combinee")
--------------------------------------------------------------------------------

-- Le vrai module est charge (ordre du TOC). Sa decision "quel noeud acheter"
-- demande tout un arbre ; ici on ne pilote que l'ouverture, en lui prêtant une
-- action `open-profession` -- BuildButtonState relit api.GetNextAction a chaque
-- appel.
local SKILL_LINE_ID = 2906
specPlan.GetNextAction = function()
    return {
        kind = "open-profession",
        skillLineID = SKILL_LINE_ID,
        target = {
            skillLineID = SKILL_LINE_ID,
            label = "Alch",
            knowledge = 5,
            stepIndex = 1,
            totalSteps = 1,
        },
    }
end

ResetCalls()
Advance(10)
Check("au repos : ni amorce ni plan", IsOpen() == false and specPlan.IsOpeningProfession() == false)

OPEN_MODE = "ok"
specPlan.Step()
Check("le plan a ouvert le metier", OPEN_CALLS[1] == SKILL_LINE_ID, OPEN_CALLS[1])
Check("le drapeau du tracker est vrai PENDANT l'appel du plan : pose avant OpenTradeSkill",
    flagDuringOpen == true, flagDuringOpen)
Check("le plan se dit en train d'ouvrir", specPlan.IsOpeningProfession() == true)
Check("l'API du tracker combine la source du plan", IsOpen() == true)
Check("sans que l'amorce y soit pour quelque chose", runtimeState.tradeSkillBootstrapPending == false)

-- Le client montre le metier : le tracker relaie a son plan, qui ramene
-- l'echeance de 2 s a 1,5 s apres cette apparition.
Advance(0.3)
FireEvent("TRADE_SKILL_SHOW")
RunTimers(1)
Check("TRADE_SKILL_SHOW relaye : l'autre addon lit vrai, a la reception et ensuite",
    spyLog[1] and spyLog[1].atEvent == true and spyLog[1].deferred == true)
Check("le tracker ne ferme PAS ce metier : il n'a pas ete ouvert par l'amorce",
    CLOSE_CALLS == 0, CLOSE_CALLS)
Advance(1.4)
Check("1,4 s apres l'apparition : vrai", IsOpen() == true)
Advance(0.2)
Check("1,6 s apres : le plan laisse la fenetre au joueur, faux", IsOpen() == false)
Check("et la source du plan est tombee", specPlan.IsOpeningProfession() == false)

-- Une apparition posterieure est le fait du joueur : elle ne releve rien.
FireEvent("TRADE_SKILL_SHOW")
RunTimers(1)
Check("une autre apparition, plus tard : faux", IsOpen() == false)

-- Le relais joue dans les deux sens : il RACCOURCIT l'echeance quand le metier
-- apparait vite (test ci-dessus, 1,6 s apres une apparition a +0,3 s est faux
-- alors que le filet de 2 s courait encore), et il la REPOUSSE quand le client
-- est lent. Une apparition a +1 s tient jusqu'a +2,5 s, au-dela du filet : sans
-- le relais le drapeau serait deja tombe a +2 s, et les callbacks After(0)
-- d'une ouverture lente partiraient avec des donnees pas chargees.
ResetCalls()
Advance(10)
specPlan.Step()
Advance(1.0)
FireEvent("TRADE_SKILL_SHOW")
RunTimers(1)
Advance(1.2)
Check("apparition a +1 s, controle a +2,2 s : au-dela du filet de 2 s, vrai", IsOpen() == true)
Advance(0.4)
Check("a +2,6 s (1,6 s apres l'apparition) : faux", IsOpen() == false)

--------------------------------------------------------------------------------
print("\nPlan de specialisation : appel refuse ou ignore")
--------------------------------------------------------------------------------

ResetCalls()
Advance(10)
OPEN_MODE = "error"
specPlan.Step()
OPEN_MODE = "ok"
Check("OpenTradeSkill refuse : le drapeau etait leve pendant l'appel", flagDuringOpen == true)
Check("il retombe sur-le-champ", IsOpen() == false and specPlan.IsOpeningProfession() == false)
Advance(60)
Check("et ne revient pas", IsOpen() == false)

ResetCalls()
Advance(10)
OPEN_MODE = "ignored"
specPlan.Step()
OPEN_MODE = "ok"
Check("appel ignore par le client : vrai le temps du filet", IsOpen() == true)
Advance(1.9)
Check("1,9 s : vrai", IsOpen() == true)
Advance(0.2)
Check("2,1 s sans apparition : le filet libere le drapeau", IsOpen() == false)

-- Le joueur ouvre ensuite le metier a la main : c'est SON ouverture. Le relais
-- ne doit pas la prendre pour la reponse a l'appel ignore, longtemps expire.
FireEvent("TRADE_SKILL_SHOW")
RunTimers(1)
Check("le joueur ouvre le metier apres l'echeance : faux, a la reception comme apres",
    IsOpen() == false and spyLog[1] and spyLog[1].atEvent == false and spyLog[1].deferred == false)

--------------------------------------------------------------------------------
print("\nCombinaison des deux sources")
--------------------------------------------------------------------------------

-- Le plan est remplace par une doublure : on verifie la combinaison seule.
local realIsOpening = specPlan.IsOpeningProfession
local planSays

specPlan.IsOpeningProfession = function() return planSays end

planSays = true
Check("le plan seul suffit", IsOpen() == true)
planSays = false
Check("ni l'un ni l'autre : faux", IsOpen() == false)
planSays = 1
Check("seul `true` compte : une valeur truthy ne leve pas le drapeau", IsOpen() == false)
planSays = nil
Check("un plan muet ne leve rien", IsOpen() == false)

specPlan.IsOpeningProfession = function() error("plan casse") end
Check("un plan qui leve une erreur ne casse pas la requete", select(1, pcall(IsOpen)) == true)
Check("... et ne leve pas le drapeau", IsOpen() == false)

specPlan.IsOpeningProfession = nil
Check("sans la fonction du plan (version ancienne) : faux", IsOpen() == false)

-- L'amorce l'emporte meme si le plan se tait.
specPlan.IsOpeningProfession = function() return false end
runtimeState.tradeSkillBootstrapPending = true
runtimeState.tradeSkillBootstrapStartedAt = nil
Check("amorce en attente, plan muet : vrai", IsOpen() == true)
runtimeState.tradeSkillBootstrapPending = false

runtimeState.tradeSkillProgrammaticGraceUntil = clock + 1
Check("grace de l'amorce, plan muet : vrai", IsOpen() == true)
runtimeState.tradeSkillProgrammaticGraceUntil = nil
Check("tout retombe : faux", IsOpen() == false)

specPlan.IsOpeningProfession = realIsOpening

--------------------------------------------------------------------------------
print("\nRelais de TRADE_SKILL_SHOW")
--------------------------------------------------------------------------------

local relayed = 0
local realNotify = specPlan.NotifyTradeSkillShown
specPlan.NotifyTradeSkillShown = function() relayed = relayed + 1 end
FireEvent("TRADE_SKILL_SHOW")
Check("le tracker relaie TRADE_SKILL_SHOW au plan", relayed == 1, relayed)
FireEvent("TRADE_SKILL_DATA_SOURCE_CHANGED")
Check("mais pas le changement de source de donnees", relayed == 1, relayed)
specPlan.NotifyTradeSkillShown = function() error("plan casse") end
FireEvent("TRADE_SKILL_SHOW")
specPlan.NotifyTradeSkillShown = nil
FireEvent("TRADE_SKILL_SHOW")
specPlan.NotifyTradeSkillShown = realNotify
Check("un plan qui leve ou qui n'a pas le relais ne casse pas le tracker",
    not UNCAUGHT or #UNCAUGHT == 0)

--------------------------------------------------------------------------------

if UNCAUGHT and #UNCAUGHT > 0 then
    for _, message in ipairs(UNCAUGHT) do
        print("  ECHEC erreur non rattrapee :: " .. message)
    end
    failures = failures + #UNCAUGHT
end

print(("\n%d reussite(s), %d echec(s)"):format(checks - failures, failures))
if failures > 0 then
    os.exit(1)
end
