-- Le mode debug ne doit rien changer a ce qu'il observe, et un rendu qui echoue
-- ne doit pas figer le bouton Next.
--
-- Cas reel : avec `/yq debug` allume, le bouton Next re-proposait « Craft x2 »
-- apres chaque lot, alors que matieres et concentration etaient depensees. Chaque
-- trace passait par `state.EnsureDB()`, qui se termine par NormalizeQueueEntries
-- et REMPLACE `db.queue` par des copies : l'entree que ConsumeMatchedQueueEntry
-- tenait en main n'etait plus dans la file, et son decrement partait dans le vide.
-- Eteindre le debug « debloquait » le bouton.
--
-- Autres causes de rendu fige, trouvees au meme endroit :
--   * `tostring(select(14, GetItemInfo(id)))` leve pour un objet pas en cache
--     (select ne rend rien) et faisait avorter RefreshAll (62 fois dans
--     !YayaErrorLog), arguments evalues meme avec le debug eteint ;
--   * une action de patron dont la resynchronisation ne revient pas n'expirait
--     qu'a la lecture, sans rendu pour la constater ;
--   * RefreshAll n'etait pas protege : une erreur laissait le panneau fige.
--
-- Usage : lua5.1 Tests/test_debug_neutrality.lua (depuis addons/YayaQueue)

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

local handle = assert(io.open("YayaQueue.lua", "rb"), "YayaQueue.lua introuvable")
local source = handle:read("*a"):gsub("\r\n", "\n")
handle:close()

local function Extract(name, pattern)
    return (assert(source:match(pattern), name .. " introuvable"))
end

-- ---------------------------------------------------------------------------
-- Environnement simule
-- ---------------------------------------------------------------------------

local now = 100
function GetTime() return now end
function date() return "12:00:00" end

local chat = {}
DEFAULT_CHAT_FRAME = { AddMessage = function(_, message) chat[#chat + 1] = message end }
YayaCore = {
    RingBuffer = { Push = function(buffer, value) buffer[#buffer + 1] = value end },
    UI = { HEX = { accent = "" } },
}
CONFIG = { debugNextCraft = true, DEBUG_LOG_LIMIT = 400 }
addonName = "YayaQueue"
state = { pendingCraftEntries = {}, pendingCraftBatches = {}, debugCountSignatures = {} }
YQQuality = {}
db = nil

local ensureCalls = 0
state.EnsureDB = function()
    ensureCalls = ensureCalls + 1
    -- Ce que fait NormalizeQueueEntries : la file devient une liste de COPIES.
    local copies = {}
    for index, entry in ipairs(YayaQueueDB.queue) do
        local copy = {}
        for key, value in pairs(entry) do copy[key] = value end
        copies[index] = copy
    end
    YayaQueueDB.queue = copies
    db = YayaQueueDB
end

local function Print(message) chat[#chat + 1] = message end
Print = Print

local function GetEntryCraftsRemaining(entry) return entry.craftQty or 0, 0 end

local loaded = assert(loadstring(table.concat({
    "local addonName, state, CONFIG, YayaCore, YQQuality = ...",
    "local function Print(message) DEFAULT_CHAT_FRAME:AddMessage(message) end",
    Extract("AppendPersistentDebugLog",
        "(local function AppendPersistentDebugLog%(prefix, message%).-\nend)\n"),
    "local DebugPrint",
    Extract("DebugPrint", "(DebugPrint = function%(message%).-\nend)\n"),
    "return DebugPrint",
}, "\n"), "debug-log"))
local DebugPrint = loaded(addonName, state, CONFIG, YayaCore, YQQuality)

-- Pour DebugCraftState, qui lit aussi GetEntryCraftsRemaining et DebugPrint.
local craftStateChunk = assert(loadstring(table.concat({
    "local state, CONFIG, DebugPrint, GetEntryCraftsRemaining, YQQuality = ...",
    Extract("DebugCraftState", "(function YQQuality%.DebugCraftState%(stage, recipeID, details%).-\nend)\n"),
}, "\n"), "craft-state"))
craftStateChunk(state, CONFIG, DebugPrint, GetEntryCraftsRemaining, YQQuality)

-- ---------------------------------------------------------------------------
section("Une trace ne renormalise jamais la file")
-- ---------------------------------------------------------------------------

local entry = { recipeID = 1230859, craftQty = 2, applyConcentration = true }
YayaQueueDB = { queue = { entry } }
db = YayaQueueDB
CONFIG.debugNextCraft = true

DebugPrint("trace de test")
equals("DebugPrint n'appelle pas EnsureDB", ensureCalls, 0)
equals("l'entree tenue en main est toujours dans la file", YayaQueueDB.queue[1], entry)
equals("la trace est bien journalisee", #YayaQueueDB.debugLog, 1)
equals("... avec son prefixe", YayaQueueDB.debugLog[1]:find("YQ DEBUG trace de test", 1, true) ~= nil, true)

state.pendingCraftEntries[1] = { recipeID = 1230859, amount = 2 }
YQQuality.DebugCraftState("consume-entry-before", 1230859)
equals("DebugCraftState n'appelle pas EnsureDB", ensureCalls, 0)
equals("... et laisse l'entree en place", YayaQueueDB.queue[1], entry)
equals("... mais journalise l'etat de la file",
    YayaQueueDB.debugLog[#YayaQueueDB.debugLog]:find("queue=[1:1230859x2:normal:conc=true]", 1, true) ~= nil, true)

-- Le decrement ecrit apres la trace atteint la bonne table.
entry.craftQty = entry.craftQty - 1
equals("un decrement ecrit apres une trace reste visible dans la file", YayaQueueDB.queue[1].craftQty, 1)

YayaQueueDB = nil
db = nil
DebugPrint("avant le chargement des SavedVariables")
equals("sans base chargee, une trace ne leve pas et ne cree rien", YayaQueueDB, nil)

-- ---------------------------------------------------------------------------
section("La trace des stocks ne modifie pas les stocks observes")
-- ---------------------------------------------------------------------------

local observed = 0
local reagentBody = Extract("DebugPrintReagentCount",
    "(local function DebugPrintReagentCount%(prefix, itemID, needed, mailbox%).-\nend)\n")
equals("lecture pure du sac (pas de GetOwnedCount, qui regle les achats en transit)",
    reagentBody:find("GetOwnedCount(", 1, true), nil)
equals("... GetImmediateOwnedCount a la place",
    reagentBody:find("GetImmediateOwnedCount(itemID)", 1, true) ~= nil, true)

-- ---------------------------------------------------------------------------
section("Un objet pas en cache ne fait plus avorter le rendu")
-- ---------------------------------------------------------------------------

-- select(14, rien) ne rend rien : tostring() leve. Les parentheses ramenent a
-- exactement une valeur.
local function GetItemInfoUncached() end
local okRaw = pcall(function() return tostring(select(14, GetItemInfoUncached(1))) end)
local okFixed, text = pcall(function() return tostring((select(14, GetItemInfoUncached(1)))) end)
equals("l'ancienne forme leve pour un objet pas en cache", okRaw, false)
equals("la forme corrigee rend « nil »", okFixed and text, "nil")
equals("plus aucun tostring(select(14, ...)) sans parentheses dans la source",
    source:find("tostring(select(14, GetItemInfo", 1, true), nil)
equals("la trace des paniers est reservee au debug",
    source:find("if CONFIG.debugNextCraft then\n                local bucketKey", 1, true) ~= nil, true)

-- ---------------------------------------------------------------------------
section("Un rendu qui leve une erreur est retente, de facon bornee")
-- ---------------------------------------------------------------------------

local timers = {}
C_Timer = { After = function(delay, fn) timers[#timers + 1] = { delay = delay, fn = fn } end }
function InCombatLockdown() return false end
local handlerCalls = 0
function geterrorhandler()
    return function(message) handlerCalls = handlerCalls + 1; return message end
end

local refreshState = { refreshQueued = false }
local refreshChunk = assert(loadstring(table.concat({
    "local state = ...",
    Extract("ScheduleRefresh", "(local function ScheduleRefresh%(%).-\nend)\n"),
    "return ScheduleRefresh",
}, "\n"), "schedule-refresh"))
local ScheduleRefresh = refreshChunk(refreshState)

local renders, failuresLeft = 0, 0
refreshState.RefreshAll = function()
    renders = renders + 1
    if failuresLeft > 0 then
        failuresLeft = failuresLeft - 1
        error("rendu avorte")
    end
end

local function Drain()
    local guard = 0
    while #timers > 0 and guard < 20 do
        guard = guard + 1
        local timer = table.remove(timers, 1)
        timer.fn()
    end
end

ScheduleRefresh()
Drain()
equals("rendu sain : un seul passage", renders, 1)
equals("... aucun nouvel essai", #timers, 0)

renders, failuresLeft = 0, 2
ScheduleRefresh()
Drain()
equals("deux echecs puis un succes : trois passages", renders, 3)
equals("... l'erreur est remise au gestionnaire a chaque echec", handlerCalls, 2)
equals("... le compteur d'essais retombe a zero", refreshState.refreshRetries, 0)

renders, failuresLeft, handlerCalls = 0, 99, 0
refreshState.refreshRetries = 0
ScheduleRefresh()
Drain()
equals("erreur persistante : abandon au bout de quatre passages (1 + 3 essais)", renders, 4)
equals("... jamais de boucle infinie", #timers, 0)

-- ---------------------------------------------------------------------------
section("Branchements dans la source")
-- ---------------------------------------------------------------------------

local patronAction = Extract("BeginPatronAction",
    "(state%.BeginPatronAction = function%(phase, entry, timeoutSeconds%).-\nend)\n")
equals("une action de patron programme le rendu qui constate son expiration",
    patronAction:find("C_Timer.After(timeout + 10.1, ScheduleRefresh)", 1, true) ~= nil, true)

local resetQueue = Extract("ResetQueue", "(local function ResetQueue%(%).-\nend)\n")
equals("le reset libere aussi le verrou d'un lot de crafts",
    resetQueue:find('state.nextActionLock.action == "craft"', 1, true) ~= nil, true)
equals("... vide les lots en attente",
    resetQueue:find("wipe(state.pendingCraftBatches)", 1, true) ~= nil, true)
equals("... et le verrou de clic",
    resetQueue:find("EndCraftClickLock()", 1, true) ~= nil, true)

local aborted = Extract("SpellcastAborted", "(handle%.SpellcastAborted = function.-\nend)\n")
equals("le suivi de remboursement n'est remis a zero qu'apres le filtre d'identite",
    (aborted:find("tracker.awaitingCraft = false", 1, true) or 0)
        > (aborted:find("if not state.IsPendingCraftSpell(abortedSpellID) then", 1, true) or math.huge), true)

equals("le debug allume est rappele au chargement",
    source:find("Mode debug ACTIF", 1, true) ~= nil, true)
equals("le texte d'erreur du jeu est trace",
    source:find('DebugPrint("ui-error message=" .. message)', 1, true) ~= nil, true)

print(("\n%d OK, %d echec(s)"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
