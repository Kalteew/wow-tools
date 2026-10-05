-- Ouvertures de metier programmatiques de YayaWeeklyTracker, vues de
-- YayaCraftingOrders (BrowsePane.lua).
--
-- YayaWeeklyTracker ouvre des metiers sans action du joueur (amorcage des
-- donnees au login, plan de depense des points de connaissance) et l'annonce par
-- YayaWeeklyTrackerAPI.IsProgrammaticTradeSkillOpen. Sans cela, chaque
-- TRADE_SKILL_SHOW lancait le scan patron et la concentration du favori sur des
-- donnees de metier pas chargees, et consommait le marqueur "une fois par
-- session" de YayaQueue.
--
-- Ce que la suite garde, dans l'ordre d'importance :
--
--  1. une ouverture programmatique ne lance RIEN : ni scan patron, ni
--     concentration du favori, ni first crafts -- aux quatre portes (TRADE_SKILL_SHOW,
--     TRADE_SKILL_DATA_SOURCE_CHANGED, MaybeStartPatronAutoScan,
--     DispatchProfessionOpenQueueTasks) ;
--  2. elle ne MARQUE rien : ni `autoScanOpeningRequested`, ni le metier "ouvert"
--     ou "traite", ni `postOpenTasksDispatched`. La vraie ouverture qui suit
--     doit demarrer comme si l'autre n'avait pas eu lieu ;
--  3. le drapeau est evalue a la RECEPTION de l'evenement, avant le
--     C_Timer.After(0), et sans YayaWeeklyTracker (ou avec une API qui leve) il
--     est faux : aucun automatisme n'est coupe par erreur.
--
-- Ce que ce test ne couvre pas : le flux d'auto-scan lui-meme (requetes
-- C_CraftingOrders, retombee visible), qui demande le client.
--
-- Usage : lua5.1 Tests/test_programmatic_open.lua   (depuis addons/YayaCraftingOrdersLocal)

--------------------------------------------------------------------------------
-- Doublures minimales
--
-- BrowsePane.lua ne touche, au chargement, que `Enum` et `COPPER_PER_GOLD`.
-- Tout le reste (fenetre de metier, API de commandes) n'est lu que dans les
-- fonctions, et celles que ce test exerce sont remplacees ci-dessous.
--------------------------------------------------------------------------------

Enum = {}
COPPER_PER_GOLD = 10000

local clock = 1000.0
function GetTime()
    return clock
end

local timers = {}
C_Timer = {
    After = function(_, callback)
        timers[#timers + 1] = callback
    end,
}

local uncaught = {}

--- Vide la file des timers, plusieurs tours car un callback peut en poser.
local function RunTimers()
    for _ = 1, 5 do
        local batch = timers
        timers = {}
        for _, callback in ipairs(batch) do
            local ok, err = pcall(callback)
            if not ok then
                uncaught[#uncaught + 1] = tostring(err)
            end
        end
    end
end

local debugLog = {}
local handlers = {}

local ns = { Util = {}, L = {} }
ns.Debug = function(category, message, ...)
    local text = tostring(message)
    if select("#", ...) > 0 then
        text = text:format(...)
    end
    debugLog[#debugLog + 1] = ("[%s] %s"):format(tostring(category), text)
end
ns.RegisterEvent = function(event, callback)
    handlers[event] = callback
end

local chunk, compileError = loadfile("BrowsePane.lua")
if not chunk then
    print("ECHEC compilation BrowsePane.lua :: " .. tostring(compileError))
    os.exit(2)
end
local loaded, loadError = pcall(chunk, "YayaCraftingOrdersLocal", ns)
if not loaded then
    print("ECHEC chargement BrowsePane.lua :: " .. tostring(loadError))
    os.exit(3)
end

local Pane = ns.BrowsePane

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

--- Une trace de debug contient-elle ce motif (texte brut) ?
local function Traced(fragment)
    for _, line in ipairs(debugLog) do
        if line:find(fragment, 1, true) then
            return true
        end
    end
    return false
end

-- Le drapeau de YayaWeeklyTracker, et l'API qui le porte.
local programmatic = false
_G.YayaWeeklyTrackerAPI = {
    IsProgrammaticTradeSkillOpen = function()
        return programmatic
    end,
}

-- YayaQueue : seul ce que BrowsePane lui demande a l'ouverture d'un metier.
local queueCalls
_G.YayaQueueAPI = {
    AddRecipe = function() end,
    QueueFavoriteConcentration = function(profession)
        queueCalls.favorite[#queueCalls.favorite + 1] = profession
        return true, "ok"
    end,
    QueueFirstCraftsAfterProfessionOpen = function()
        queueCalls.firstCraft = queueCalls.firstCraft + 1
        return true, "ok"
    end,
}

-- Le metier ouvert, tel que l'API du client le decrit.
local snapshotCalls, started, markedDirty, detailDirty
local snapshot = { selected = 171, child = 171, base = 171, ordersPage = false }

function Pane:GetProfessionSnapshot()
    snapshotCalls = snapshotCalls + 1
    return snapshot
end
function Pane:IsNearProfessionFocus() return true end
function Pane:CanOpenPatronOrders() return true, true end
function Pane:ResetCrafterOrderRequestToken() end
function Pane:MarkDirty(reason) markedDirty[#markedDirty + 1] = reason end
function Pane:MarkDetailWarningDirty() detailDirty = detailDirty + 1 end
-- La suite du flux (requetes C_CraftingOrders) n'est pas l'objet de ce test :
-- on note seulement qu'un flux a ete demarre.
function Pane:SchedulePatronAutoScanStep(flow) started[#started + 1] = flow end

local realMaybeStart = Pane.MaybeStartPatronAutoScan
local maybeStartReasons

--- Remplace MaybeStartPatronAutoScan par une doublure qui note ses appels, sans
-- rien demarrer. Les tests d'evenements s'y limitent : ce qu'ils gardent, c'est
-- la DECISION de l'evenement, pas le scan.
local function SpyOnMaybeStart()
    Pane.MaybeStartPatronAutoScan = function(_, reason)
        maybeStartReasons[#maybeStartReasons + 1] = reason
    end
end

local function RestoreMaybeStart()
    Pane.MaybeStartPatronAutoScan = realMaybeStart
end

--- Remet le monde a l'etat "rien ne s'est passe depuis le chargement".
local function Reset()
    programmatic = false
    timers = {}
    debugLog = {}
    snapshotCalls = 0
    started = {}
    markedDirty = {}
    detailDirty = 0
    maybeStartReasons = {}
    queueCalls = { favorite = {}, firstCraft = 0 }
    snapshot = { selected = 171, child = 171, base = 171, ordersPage = false }
    RestoreMaybeStart()
    Pane.autoScanFlow = nil
    Pane.autoScanOpeningRequested = false
    Pane.autoScanStartAttempts = 0
    Pane.autoScanOpeningProfession = nil
    Pane.autoScanCompletedByProfession = {}
    Pane.autoScanStartRetryQueued = nil
    Pane.knowledgeProgressCache = {}
    _G.YayaQueueAPI.AddRecipe = function() end
end

Reset()

--------------------------------------------------------------------------------
print("\nPane:IsProgrammaticTradeSkillOpen")
--------------------------------------------------------------------------------

Check("la methode existe", type(Pane.IsProgrammaticTradeSkillOpen) == "function")

local realApi = _G.YayaWeeklyTrackerAPI

programmatic = true
Check("l'API dit vrai : vrai", Pane:IsProgrammaticTradeSkillOpen() == true)
programmatic = false
Check("l'API dit faux : faux", Pane:IsProgrammaticTradeSkillOpen() == false)

_G.YayaWeeklyTrackerAPI = nil
Check("sans YayaWeeklyTracker : faux", Pane:IsProgrammaticTradeSkillOpen() == false)
_G.YayaWeeklyTrackerAPI = {}
Check("API sans la fonction (version ancienne) : faux", Pane:IsProgrammaticTradeSkillOpen() == false)
_G.YayaWeeklyTrackerAPI = { IsProgrammaticTradeSkillOpen = "oui" }
Check("API dont la fonction n'en est pas une : faux", Pane:IsProgrammaticTradeSkillOpen() == false)
_G.YayaWeeklyTrackerAPI = { IsProgrammaticTradeSkillOpen = function() return 1 end }
Check("seul `true` compte : une valeur truthy ne coupe rien", Pane:IsProgrammaticTradeSkillOpen() == false)
_G.YayaWeeklyTrackerAPI = { IsProgrammaticTradeSkillOpen = function() error("tracker casse") end }
local ok, value = pcall(Pane.IsProgrammaticTradeSkillOpen, Pane)
Check("une API qui leve une erreur ne casse pas l'appelant", ok == true, value)
Check("... et rend faux : aucun automatisme coupe par erreur", value == false, value)
_G.YayaWeeklyTrackerAPI = realApi

--------------------------------------------------------------------------------
print("\nMaybeStartPatronAutoScan : filet de securite")
--------------------------------------------------------------------------------

Reset()
programmatic = true
Pane:MaybeStartPatronAutoScan("trade-skill-show")
Check("ouverture programmatique : le metier n'est meme pas lu", snapshotCalls == 0, snapshotCalls)
Check("aucun flux demarre", Pane.autoScanFlow == nil and #started == 0)
Check("le metier n'est pas marque ouvert", Pane.autoScanOpeningProfession == nil,
    Pane.autoScanOpeningProfession)
Check("ni traite", Pane.autoScanCompletedByProfession[171] == nil)
Check("aucun reessai de demarrage n'est programme",
    Pane.autoScanStartRetryQueued == nil and #timers == 0, #timers)
Check("la decision est tracee", Traced("[auto-scan] evaluate ignore reason=trade-skill-show cause=programmatic-open"))

-- La vraie ouverture, ensuite, demarre comme si l'autre n'avait pas eu lieu.
programmatic = false
Pane:MaybeStartPatronAutoScan("trade-skill-show")
Check("la vraie ouverture lit le metier", snapshotCalls >= 1, snapshotCalls)
Check("elle demarre un flux headless pour ce metier",
    Pane.autoScanFlow ~= nil and Pane.autoScanFlow.profession == 171
        and Pane.autoScanFlow.mode == "headless" and #started == 1)
Check("le metier est marque ouvert", Pane.autoScanOpeningProfession == 171)

--------------------------------------------------------------------------------
print("\nDispatchProfessionOpenQueueTasks : filet de securite")
--------------------------------------------------------------------------------

Reset()
local flow = { profession = 171, mode = "headless" }
Pane.autoScanFlow = flow

programmatic = true
local result = Pane:DispatchProfessionOpenQueueTasks(flow, "headless")
Check("ouverture programmatique : rien n'est rendu", result == nil)
Check("la concentration du favori n'est pas lancee", #queueCalls.favorite == 0, #queueCalls.favorite)
Check("les first crafts non plus", queueCalls.firstCraft == 0, queueCalls.firstCraft)
Check("le flux n'est PAS marque `postOpenTasksDispatched`",
    flow.postOpenTasksDispatched == nil, flow.postOpenTasksDispatched)
Check("le metier n'est pas marque traite", Pane.autoScanCompletedByProfession[171] == nil)
Check("la decision est tracee",
    Traced("[auto-scan] post-open ignore profession=171 source=headless reason=programmatic-open"))

-- Le meme flux, la vraie ouverture : les taches partent, une seule fois.
programmatic = false
result = Pane:DispatchProfessionOpenQueueTasks(flow, "headless")
Check("la vraie ouverture dispatche", result ~= nil and result.favoriteOK == true and result.firstCraftOK == true)
Check("la concentration du favori part pour ce metier",
    #queueCalls.favorite == 1 and queueCalls.favorite[1] == 171)
Check("les first crafts partent", queueCalls.firstCraft == 1)
Check("le flux est maintenant marque", flow.postOpenTasksDispatched == true)
Check("un second appel ne dispatche pas deux fois",
    Pane:DispatchProfessionOpenQueueTasks(flow, "headless") == nil
        and #queueCalls.favorite == 1 and queueCalls.firstCraft == 1)

-- Un flux qui n'est pas le flux courant reste ignore, comme avant.
Reset()
Pane.autoScanFlow = { profession = 171 }
Check("un flux perime est ignore, drapeau ou pas",
    Pane:DispatchProfessionOpenQueueTasks({ profession = 171 }, "headless") == nil
        and #queueCalls.favorite == 0)

--------------------------------------------------------------------------------
print("\nTRADE_SKILL_SHOW")
--------------------------------------------------------------------------------

Pane:InitializeEvents()
Check("le handler TRADE_SKILL_SHOW est enregistre", type(handlers.TRADE_SKILL_SHOW) == "function")
Check("le handler TRADE_SKILL_DATA_SOURCE_CHANGED est enregistre",
    type(handlers.TRADE_SKILL_DATA_SOURCE_CHANGED) == "function")
Check("le handler TRADE_SKILL_CLOSE est enregistre", type(handlers.TRADE_SKILL_CLOSE) == "function")

-- Ouverture programmatique.
Reset()
SpyOnMaybeStart()
programmatic = true
handlers.TRADE_SKILL_SHOW()
Check("n'arme pas autoScanOpeningRequested", Pane.autoScanOpeningRequested == false)
Check("ne touche pas au compteur de tentatives", Pane.autoScanStartAttempts == 0)
Check("ne programme aucun callback differe (le drapeau est lu a la reception)",
    #timers == 0, #timers)
Check("la decision est tracee", Traced("[event] TRADE_SKILL_SHOW ignore reason=programmatic-open"))
RunTimers()
Check("aucun scan patron", #maybeStartReasons == 0, #maybeStartReasons)
Check("aucune concentration du favori", #queueCalls.favorite == 0)
Check("aucun first craft", queueCalls.firstCraft == 0)

-- Le drapeau retombe AVANT que le callback ne tourne : l'evenement reste ignore,
-- puisque la decision se prend a la reception.
Reset()
SpyOnMaybeStart()
programmatic = true
handlers.TRADE_SKILL_SHOW()
programmatic = false
RunTimers()
Check("drapeau retombe entre l'evenement et le callback : toujours ignore",
    #maybeStartReasons == 0 and #queueCalls.favorite == 0)

-- Ouverture du joueur.
Reset()
SpyOnMaybeStart()
programmatic = false
handlers.TRADE_SKILL_SHOW()
Check("ouverture du joueur : arme autoScanOpeningRequested", Pane.autoScanOpeningRequested == true)
Check("remet les tentatives a zero", Pane.autoScanStartAttempts == 0)
Check("programme son callback differe", #timers == 1, #timers)
Check("sans trace d'ignorance", not Traced("TRADE_SKILL_SHOW ignore"))
RunTimers()
Check("lance le scan patron", maybeStartReasons[1] == "trade-skill-show" and #maybeStartReasons == 1,
    maybeStartReasons[1])
Check("et la concentration du favori de ce metier, faute de flux en cours",
    #queueCalls.favorite == 1 and queueCalls.favorite[1] == 171, #queueCalls.favorite)

-- Un drapeau qui se leve entre l'evenement et le callback differe : le favori,
-- appele en direct par ce callback, ne part pas.
Reset()
SpyOnMaybeStart()
programmatic = false
handlers.TRADE_SKILL_SHOW()
programmatic = true
RunTimers()
Check("drapeau leve apres l'evenement : la concentration du favori ne part pas",
    #queueCalls.favorite == 0, #queueCalls.favorite)

-- De bout en bout, avec le VRAI MaybeStartPatronAutoScan : l'ouverture fantome
-- puis la vraie.
Reset()
programmatic = true
handlers.TRADE_SKILL_SHOW()
RunTimers()
Check("ouverture fantome : aucun flux", Pane.autoScanFlow == nil and #started == 0)
Check("et aucun metier marque", Pane.autoScanOpeningProfession == nil)
programmatic = false
handlers.TRADE_SKILL_SHOW()
RunTimers()
Check("la vraie ouverture qui suit demarre son flux",
    Pane.autoScanFlow ~= nil and Pane.autoScanFlow.profession == 171 and #started == 1)
Check("... qui dispatchera les taches d'ouverture une fois termine",
    Pane:DispatchProfessionOpenQueueTasks(Pane.autoScanFlow, "headless") ~= nil
        and #queueCalls.favorite == 1)

--------------------------------------------------------------------------------
print("\nTRADE_SKILL_DATA_SOURCE_CHANGED")
--------------------------------------------------------------------------------

Reset()
SpyOnMaybeStart()
programmatic = true
Pane.knowledgeProgressCache = { stale = true }
handlers.TRADE_SKILL_DATA_SOURCE_CHANGED()
Check("ouverture programmatique : aucun callback differe", #timers == 0, #timers)
Check("la decision est tracee",
    Traced("[event] TRADE_SKILL_DATA_SOURCE_CHANGED ignore reason=programmatic-open"))
Check("l'affichage est tout de meme invalide : la source a bien change",
    Pane.knowledgeProgressCache.stale == nil and markedDirty[1] == "trade-skill-source"
        and detailDirty == 1)
RunTimers()
Check("aucun scan patron", #maybeStartReasons == 0, #maybeStartReasons)

Reset()
SpyOnMaybeStart()
programmatic = false
handlers.TRADE_SKILL_DATA_SOURCE_CHANGED()
Check("changement de source du joueur : callback differe programme", #timers == 1, #timers)
Check("sans trace d'ignorance", not Traced("TRADE_SKILL_DATA_SOURCE_CHANGED ignore"))
RunTimers()
Check("lance le scan patron", maybeStartReasons[1] == "trade-skill-source" and #maybeStartReasons == 1,
    maybeStartReasons[1])

--------------------------------------------------------------------------------
print("\nTRADE_SKILL_CLOSE : changement direct de metier")
--------------------------------------------------------------------------------

-- Le plan de specialisation du tracker peut ouvrir un metier alors qu'un autre
-- est affiche : TRADE_SKILL_CLOSE de l'ancien, la fenetre toujours montree.
local frameShown = true
ProfessionsFrame = {
    IsShown = function() return frameShown end,
}

Reset()
SpyOnMaybeStart()
frameShown = true
programmatic = true
handlers.TRADE_SKILL_CLOSE()
RunTimers()
Check("changement programmatique : l'ouverture n'est pas armee", Pane.autoScanOpeningRequested == false)
Check("aucun scan patron", #maybeStartReasons == 0, #maybeStartReasons)
Check("la decision est tracee", Traced("TRADE_SKILL_CLOSE switch ignore reason=programmatic-open"))

Reset()
SpyOnMaybeStart()
frameShown = true
programmatic = false
handlers.TRADE_SKILL_CLOSE()
RunTimers()
Check("changement du joueur : l'ouverture est armee", Pane.autoScanOpeningRequested == true)
Check("et le scan patron relance", maybeStartReasons[1] == "trade-skill-close-switch",
    maybeStartReasons[1])

-- Fermeture pure (rien d'affiche ensuite) : le nettoyage ne depend pas du
-- drapeau. C'est ce que fait la fermeture de l'amorce du tracker.
Reset()
SpyOnMaybeStart()
frameShown = false
programmatic = true
Pane.autoScanOpeningRequested = true
Pane.autoScanOpeningProfession = 171
handlers.TRADE_SKILL_CLOSE()
RunTimers()
Check("fermeture pure, drapeau vrai : l'etat d'ouverture est remis a zero",
    Pane.autoScanOpeningRequested == false and Pane.autoScanOpeningProfession == nil)
Check("aucun scan", #maybeStartReasons == 0)

RestoreMaybeStart()

--------------------------------------------------------------------------------

for _, message in ipairs(uncaught) do
    failures = failures + 1
    print("  ECHEC erreur non rattrapee :: " .. message)
end

print(("\n%d reussite(s), %d echec(s)"):format(checks - failures, failures))
if failures > 0 then
    os.exit(1)
end
