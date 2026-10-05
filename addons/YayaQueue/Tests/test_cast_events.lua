-- Regression : les evenements de cast et d'ouverture de metier pilotent la file ;
-- ils ne doivent consommer, purger ou declencher que ce qui les concerne.
--
-- Cas reels :
--  * un sort reussi sans rapport (monture, ouverture d'un metier : sort 2259)
--    depilait le lot en attente d'une AUTRE recette et decrementait la file ;
--  * un cast refuse d'emblee declenche UNIT_SPELLCAST_FAILED PENDANT l'appel de
--    CraftRecipe : le disjoncteur doit le compter, mais pas quand c'est le
--    personnage (monte, en mouvement) qui l'a fait echouer ;
--  * l'ouverture du metier par YayaWeeklyTracker (amorcage des donnees) lancait
--    les automatismes de file ; le drapeau doit etre lu A LA RECEPTION de
--    l'evenement, pas dans le rappel differe qui s'execute apres la fermeture.
--
-- Le test extrait les vrais gestionnaires de la source et les rejoue sur un
-- environnement simule qui enregistre ce qu'ils font.
--
-- Usage : lua5.1 Tests/test_cast_events.lua (depuis addons/YayaQueue)

local passed, failed = 0, 0

local function equals(name, actual, expected)
    if actual == expected then
        passed = passed + 1
        print(("  OK    %s"):format(name))
    else
        failed = failed + 1
        print(("  ECHEC %s -> attendu %s, obtenu %s"):format(
            name, tostring(expected), tostring(actual)))
    end
end

local function section(title)
    print("")
    print(title)
end

local file = assert(io.open("YayaQueue.lua", "rb"), "YayaQueue.lua introuvable")
local source = file:read("*a"):gsub("\r\n", "\n")
file:close()

local function Extract(name, pattern)
    return (assert(source:match(pattern), name .. " introuvable"))
end

local function Load(chunkName, ...)
    return assert(loadstring(table.concat({ ... }, "\n"), chunkName))()
end

-- ---------------------------------------------------------------------------
-- Environnement simule
-- ---------------------------------------------------------------------------

local now = 1000
function GetTime() return now end
function wipe(t) for key in pairs(t) do t[key] = nil end return t end
function SafeCall(fn, ...)
    local ok, a = pcall(fn, ...)
    if ok then return a end
    return nil
end

local debugLines = {}
function DebugPrint(message) debugLines[#debugLines + 1] = message end

local timers = {}
C_Timer = { After = function(delay, fn) timers[#timers + 1] = { delay = delay, fn = fn } end }
local function runTimers()
    local guard = 0
    while #timers > 0 and guard < 100 do
        guard = guard + 1
        table.remove(timers, 1).fn()
    end
end

local calls = {}                     -- noms des fonctions du jeu appelees, dans l'ordre
local function Count(name)
    local total = 0
    for _, called in ipairs(calls) do
        if called == name then total = total + 1 end
    end
    return total
end

handle = {}
CONFIG = { SHATTER_ESSENCE_SPELL_ID = 999999 }
state = {
    pendingCraftEntries = {},
    pendingCraftBatches = {},
    craftFailures = {},
    craftLimitWake = {},
    autoFavoriteConcentration = {},
    ah = {},
    alchemyAutoQueue = {},
    firstCraftAvailability = {},
    craft = {},
    GetSpellNameForDebug = function() return "?" end,
}
YQQuality = {
    DebugCraftState = function() end,
    ConfirmPendingShatter = function() calls[#calls + 1] = "ConfirmPendingShatter" end,
    ConfirmPendingMerge = function() calls[#calls + 1] = "ConfirmPendingMerge" end,
    TryQueueFavoriteConcentrationRefund = function() calls[#calls + 1] = "TryRefund" end,
    CancelRecipeSolve = function() calls[#calls + 1] = "CancelRecipeSolve" end,
    InstallProfessionSpecMassPurchaseHook = function() end,
    IsProgrammaticTradeSkillOpen = function() return false end,
}
state.craftGear = { ScheduleScan = function() end }

local queueNames = {}                -- recipeID -> nom rendu par la file
function ConsumeCraftEntry(entry)
    if not entry then return nil end
    calls[#calls + 1] = "ConsumeCraftEntry:" .. tostring(entry.recipeID)
    return entry.recipeName
end
function ConsumeCraftFromQueue(recipeID)
    calls[#calls + 1] = "ConsumeCraftFromQueue:" .. tostring(recipeID)
    return queueNames[recipeID]
end
local lock
function GetNextActionLock() return lock end
function ClearNextActionLock(reason) calls[#calls + 1] = "ClearNextActionLock:" .. tostring(reason) end
function EndCraftClickLock() calls[#calls + 1] = "EndCraftClickLock" end
function IsCraftClickLocked() return false end
function GetPendingPatronAction() return nil end
function ClearPendingWorkOrderSubmit() end
function ScheduleRefresh() calls[#calls + 1] = "ScheduleRefresh" end
function ClearPendingCraftBatches() wipe(state.pendingCraftBatches) end
state.RefreshPatronOrder = function() end

-- Etat du personnage
local mounted = false
function IsMounted() return mounted end
function IsFalling() return false end
function GetUnitSpeed() return 0 end

-- Vraies fonctions de suivi des crafts en attente, extraites de la source.
Load("pending",
    "state.CRAFT_FAILURE_STREAK = 3",
    "state.CRAFT_FAILURE_WINDOW_SECONDS = 5",
    "state.CRAFT_FAILURE_PARK_SECONDS = 15",
    Extract("IsPendingCraftSpell", "(state%.IsPendingCraftSpell = function%(spellID%).-\nend)\n"),
    Extract("FindPendingCraftIndex",
        "(state%.FindPendingCraftIndex = function%(list, spellID%).-\nend)\n"),
    Extract("PopPendingCraftEntry", "(state%.PopPendingCraftEntry = function%(spellID%).-\nend)\n"),
    (Extract("PopPendingCraftRecipe", "(local function PopPendingCraftRecipe%(spellID%).-\nend)\n")
        :gsub("^local function ", "function ")),
    Extract("ClearPendingCraftEntries",
        "(state%.ClearPendingCraftEntries = function%(%).-\nend)\n"),
    Extract("NoteCraftFailure", "(state%.NoteCraftFailure = function%(recipeID%).-\nend)\n"),
    Extract("ClearCraftFailure", "(state%.ClearCraftFailure = function%(recipeID%).-\nend)\n"),
    Extract("NoteCastFailure", "(state%.NoteCastFailure = function%(spellID%).-\nend)\n"),
    Extract("IsCastBlockedByPlayerState",
        "(state%.IsCastBlockedByPlayerState = function%(%).-\nend)\n"),
    Extract("UnitSpellcastSucceeded", "(handle%.UnitSpellcastSucceeded = function.-\nend)\n"),
    Extract("SpellcastAborted", "(handle%.SpellcastAborted = function.-\nend)\n"),
    Extract("TradeSkillShow", "(handle%.TradeSkillShow = function.-\nend)\n"),
    Extract("TradeSkillClose", "(handle%.TradeSkillClose = function.-\nend)\n")
)

local X, A, B, MOUNT = 1230892, 111, 222, 23214

local function reset()
    now = 1000
    state.pendingCraftEntries, state.pendingCraftBatches = {}, {}
    state.craftFailures, state.craftLimitWake, state.lastCastFailure = {}, {}, nil
    state.autoFavoriteConcentration = {}
    state.ah = {}
    state.alchemyAutoQueue = {}
    state.pendingShatter, state.pendingMerge, state.armedMerge = nil, nil, nil
    calls, debugLines, timers, queueNames = {}, {}, {}, {}
    lock, mounted = nil, false
end

local function Field(list, index, field)
    local item = list[index]
    return item and item[field]
end

local function Pending(recipeID, amount, name)
    state.pendingCraftEntries[#state.pendingCraftEntries + 1] =
        { recipeID = recipeID, amount = amount, recipeName = name or ("recette " .. recipeID), orderID = 0 }
    state.pendingCraftBatches[#state.pendingCraftBatches + 1] = { recipeID = recipeID, amount = amount }
end

local function Succeeded(spellID, unit)
    return handle.UnitSpellcastSucceeded("UNIT_SPELLCAST_SUCCEEDED", unit or "player", "guid", spellID)
end
local function Failed(spellID, event, unit)
    return handle.SpellcastAborted(event or "UNIT_SPELLCAST_FAILED", unit or "player", "guid", spellID)
end

-- ---------------------------------------------------------------------------
section("Sort reussi : il ne depile que le craft qu'il termine")
-- ---------------------------------------------------------------------------

reset()
Pending(X, 2)
equals("monture pendant un craft en attente : traite sans erreur", Succeeded(MOUNT), true)
equals("... aucune entree de file consommee", Count("ConsumeCraftEntry:" .. X), 0)
equals("... aucun lot de recette consomme", Count("ConsumeCraftFromQueue:" .. X), 0)
equals("... l'entree en attente garde ses deux crafts", Field(state.pendingCraftEntries, 1, "amount"), 2)
equals("... le lot en attente aussi", Field(state.pendingCraftBatches, 1, "amount"), 2)
equals("... et le journal le dit",
    (table.concat(debugLines, "\n")):find("ignored spellID=" .. MOUNT, 1, true) ~= nil, true)
equals("... le suivi du remboursement n'est pas relance pour un sort etranger", #timers, 0)
equals("... aucun statut « Craft termine » n'est affiche", state.ah.statusMessage, nil)

reset()
Pending(X, 2, "Bouquet")
equals("craft reussi : traite", Succeeded(X), true)
equals("... l'entree de file est consommee", Count("ConsumeCraftEntry:" .. X), 1)
equals("... un craft de moins en attente", Field(state.pendingCraftEntries, 1, "amount"), 1)
equals("... et le lot en attente aussi", Field(state.pendingCraftBatches, 1, "amount"), 1)
equals("... le message de statut nomme la recette", state.ah.statusMessage, "Craft termine: Bouquet")
equals("... un rafraichissement est demande", Count("ScheduleRefresh") >= 1, true)
equals("... le suivi du remboursement est relance", #timers >= 1, true)
Succeeded(X)
equals("dernier craft : l'entree s'en va", #state.pendingCraftEntries, 0)
equals("... et le lot aussi", #state.pendingCraftBatches, 0)

reset()
Pending(A, 1, "orphelin")
Pending(B, 2, "suivi")
Succeeded(B)
equals("lot orphelin en tete : l'entree consommee est celle du sort reussi",
    Count("ConsumeCraftEntry:" .. B), 1)
equals("... pas l'orphelin", Count("ConsumeCraftEntry:" .. A), 0)
equals("... l'orphelin attend toujours", Field(state.pendingCraftEntries, 1, "recipeID"), A)
equals("... le lot du craft suivi perd une unite", Field(state.pendingCraftBatches, 2, "amount"), 1)
Succeeded(B)
equals("dernier craft suivi : son entree s'en va et l'orpheline reste seule",
    #state.pendingCraftEntries == 1 and Field(state.pendingCraftEntries, 1, "recipeID") == A, true)
equals("... idem pour le lot",
    #state.pendingCraftBatches == 1 and Field(state.pendingCraftBatches, 1, "recipeID") == A, true)

-- Craft lance depuis l'interface de Blizzard : seul un lot en attente existe
-- (aucune entree posee par Next) ; la file est decrementee par recette.
reset()
state.pendingCraftBatches = {
    { recipeID = A, amount = 1 },
    { recipeID = B, amount = 2 },
}
queueNames[B] = "suivi"
Succeeded(B)
equals("lot seul, orphelin en tete : la file est decrementee pour la recette reussie",
    Count("ConsumeCraftFromQueue:" .. B), 1)
equals("... pas pour l'orphelin", Count("ConsumeCraftFromQueue:" .. A), 0)
equals("... l'orphelin attend toujours", Field(state.pendingCraftBatches, 1, "recipeID"), A)
equals("... le lot suivi perd une unite", Field(state.pendingCraftBatches, 2, "amount"), 1)
equals("... le statut nomme la recette", state.ah.statusMessage, "Craft termine: suivi")

reset()
equals("rien en attente : un sort reussi ne leve rien", Succeeded(MOUNT), true)
equals("... et ne consomme rien", Count("ConsumeCraftEntry:" .. MOUNT), 0)

reset()
Pending(X, 1)
equals("sort d'une autre unite : ignore", Succeeded(X, "target"), true)
equals("... rien n'est consomme", Count("ConsumeCraftEntry:" .. X), 0)

reset()
Pending(X, 1)
state.pendingMerge = {}
Succeeded(X)
equals("fusion en cours : la confirmation est planifiee", #timers, 1)
equals("... rien n'est depile", #state.pendingCraftEntries, 1)

reset()
Pending(X, 1, "Bouquet")
Succeeded(X)
equals("un craft abouti remet la serie d'echecs a zero (cle absente)", state.craftFailures[X], nil)
state.craftFailures[X] = { count = 2, lastAt = now }
Pending(X, 1, "Bouquet")
Succeeded(X)
equals("... meme apres deux echecs", state.craftFailures[X], nil)

-- ---------------------------------------------------------------------------
section("Cast refuse : le disjoncteur compte les refus de la recette, pas ceux du personnage")
-- ---------------------------------------------------------------------------

reset()
Pending(X, 2)
state.autoFavoriteConcentration.tracker = { awaitingCraft = true, confirmedCrafts = 1 }
Failed(MOUNT)
equals("monture refusee pendant un craft : ignoree", Count("EndCraftClickLock"), 0)
equals("... l'entree en attente est intacte", #state.pendingCraftEntries, 1)
equals("... le suivi du remboursement aussi", state.autoFavoriteConcentration.tracker.awaitingCraft, true)
equals("... aucun echec compte contre la recette", state.craftFailures[X], nil)
equals("... ni contre la monture", state.craftFailures[MOUNT], nil)

reset()
Pending(X, 2)
state.autoFavoriteConcentration.tracker = { awaitingCraft = true, confirmedCrafts = 1 }
Failed(X)
equals("craft refuse a l'arret : l'entree en attente est purgee", #state.pendingCraftEntries, 0)
equals("... le lot aussi", #state.pendingCraftBatches, 0)
equals("... le verrou de clic est libere", Count("EndCraftClickLock"), 1)
equals("... le suivi du remboursement est remis a zero", state.autoFavoriteConcentration.tracker.awaitingCraft, false)
equals("... l'echec compte pour le disjoncteur", state.craftFailures[X] and state.craftFailures[X].count, 1)
equals("... et le cast refuse est memorise pour le post-hook",
    state.lastCastFailure and state.lastCastFailure.spellID, X)
-- Chaque clic de Next repose son lot en attente avant d'appeler CraftRecipe.
Pending(X, 2)
Failed(X)
Pending(X, 2)
Failed(X)
equals("trois refus d'affilee : la recette est suspendue",
    state.craftFailures[X].parkedUntil ~= nil, true)

reset()
Pending(X, 1)
mounted = true
Failed(X)
equals("craft refuse monte : la file est quand meme purgee", #state.pendingCraftEntries, 0)
equals("... mais rien n'est compte contre la recette", state.craftFailures[X], nil)
equals("... le cast refuse reste memorise (aucun lot ne sera pose)",
    state.lastCastFailure and state.lastCastFailure.spellID, X)
equals("... et le journal en donne la raison",
    (table.concat(debugLines, "\n")):find("reason=player-state", 1, true) ~= nil, true)
for _ = 1, 3 do
    Pending(X, 1)
    Failed(X)
end
equals("... meme repete monte, la recette n'est jamais suspendue", state.craftFailures[X], nil)

reset()
Pending(X, 1)
Failed(X, "UNIT_SPELLCAST_INTERRUPTED")
equals("craft interrompu (mouvement) : la file est purgee", #state.pendingCraftEntries, 0)
equals("... aucun echec compte", state.craftFailures[X], nil)
equals("... et aucun cast refuse memorise", state.lastCastFailure, nil)

reset()
Pending(X, 1)
equals("echec d'une autre unite : ignore", Failed(X, "UNIT_SPELLCAST_FAILED", "target"), true)
equals("... rien n'est purge", #state.pendingCraftEntries, 1)

reset()
Pending(X, 1)
state.pendingMerge = {}
Failed(X)
equals("fusion en cours : l'echec la remet a zero", state.pendingMerge, nil)
equals("... et ne touche pas aux crafts en attente", #state.pendingCraftEntries, 1)

-- ---------------------------------------------------------------------------
section("Ouverture du metier : les automatismes attendent la vraie ouverture")
-- ---------------------------------------------------------------------------

db = { autoQueueFavoriteConcentration = true, autoQueueAlchemy = true }
state.EnsureDB = function() end
state.GetCurrentProfessionID = function() return 171 end
local started, favorites = 0, 0
function StartAlchemyAutoQueue() started = started + 1 end
YayaQueueAPI = {
    QueueFavoriteConcentration = function() favorites = favorites + 1 return true, "ok" end,
}
local programmatic = false
YQQuality.IsProgrammaticTradeSkillOpen = function() return programmatic end

local function Show()
    return handle.TradeSkillShow("TRADE_SKILL_SHOW")
end

reset()
started, favorites, programmatic = 0, 0, false
db.autoQueueFavoriteConcentration, db.autoQueueAlchemy = true, true
Show()
runTimers()
equals("vraie ouverture : le dump du favori est lance", favorites, 1)
equals("... la passe Alchimie aussi", started, 1)

reset()
started, favorites, programmatic = 0, 0, true
Show()
programmatic = false              -- YayaWeeklyTracker a deja ferme le metier au frame suivant
runTimers()
equals("ouverture amorcee par YWT : pas de dump du favori", favorites, 0)
equals("... pas de passe Alchimie", started, 0)
equals("... le drapeau est lu a la reception : relu plus tard il serait deja faux",
    (table.concat(debugLines, "\n")):find("skip reason=programmatic-open", 1, true) ~= nil, true)
equals("... l'etat « en attente » n'est pas touche", state.alchemyAutoQueue.pendingProfessionID, nil)

reset()
started, favorites, programmatic = 0, 0, false
Show()
programmatic = true               -- une ouverture amorcee juste apres ne change rien
runTimers()
equals("vraie ouverture suivie d'une amorce : les automatismes partent quand meme",
    favorites == 1 and started == 1, true)

reset()
started, favorites, programmatic = 0, 0, false
_G.YayaCraftingOrdersAPI = {}
Show()
runTimers()
equals("YayaCraftingOrders present : le dump du favori lui est laisse", favorites, 0)
equals("... la passe Alchimie part quand meme", started, 1)
_G.YayaCraftingOrdersAPI = nil

reset()
started, favorites = 0, 0
db.autoQueueAlchemy = false
state.alchemyAutoQueue.pendingProfessionID = 171
Show()
runTimers()
equals("file Alchimie desactivee : aucune passe", started, 0)
equals("... l'etat « en attente » est remis a zero", state.alchemyAutoQueue.pendingProfessionID, nil)
db.autoQueueAlchemy = true

reset()
started, favorites = 0, 0
db.autoQueueFavoriteConcentration = false
Show()
runTimers()
equals("dump du favori desactive : il n'est pas lance", favorites, 0)
equals("... la passe Alchimie part", started, 1)
db.autoQueueFavoriteConcentration = true

-- ---------------------------------------------------------------------------
section("Fermeture du metier : l'ouverture suivante repart de zero")
-- ---------------------------------------------------------------------------

reset()
state.alchemyAutoQueue = {
    pendingProfessionID = 171, completedProfessionID = 171,
    passRecipeCount = 10, confirmedRecipeCount = 10, attempts = 5,
}
state.autoFavoriteConcentration.handledFavoriteByProfession = { [171] = 1230892 }
state.autoFavoriteConcentration.spareObservedAmount = { [171] = 50 }
state.firstCraftAvailability = { [1] = true }
state.craft.qualityTarget = 3
handle.TradeSkillClose("TRADE_SKILL_CLOSE")
equals("la passe Alchimie n'est plus en attente", state.alchemyAutoQueue.pendingProfessionID, false)
equals("... ni marquee terminee", state.alchemyAutoQueue.completedProfessionID, nil)
equals("... ni confirmee", state.alchemyAutoQueue.confirmedRecipeCount, nil)
equals("... le nombre de recettes vu est oublie", state.alchemyAutoQueue.passRecipeCount, nil)
equals("... les tentatives repartent de zero", state.alchemyAutoQueue.attempts, 0)
equals("le dump du favori n'est plus « traite »",
    next(state.autoFavoriteConcentration.handledFavoriteByProfession), nil)
equals("... les observations de concentration sont oubliees",
    next(state.autoFavoriteConcentration.spareObservedAmount), nil)
equals("... la cible de qualite aussi", state.craft.qualityTarget, nil)
equals("... le verrou de clic est libere", Count("EndCraftClickLock"), 1)

reset()
Pending(X, 1)
handle.TradeSkillClose("TRADE_SKILL_CLOSE")
equals("fermeture avec un craft en attente : il n'est pas purge a la volee", #state.pendingCraftEntries, 1)
reset()
handle.TradeSkillClose("TRADE_SKILL_CLOSE")
equals("fermeture sans rien en attente : les listes restent vides",
    #state.pendingCraftEntries + #state.pendingCraftBatches, 0)

print("")
print(("%d OK, %d echec(s)"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
