-- Fusion des finitions Midnight : seul le surplus hors file est propose.
--
-- Le bouton « Fusionner » transforme cinq rang 1 en un rang 2. Or un dump de
-- concentration de YayaQueue met en file des crafts qui consomment des rang 1
-- (Multicraft Matrix, Resourceful Rebar, Ingenious Identifier) : fusionner ces
-- exemplaires les remplace par un rang 2 que l'entree de file ne reconnait pas,
-- et la file se bloque sur un « Acquerir » impossible, ces finitions etant liees
-- au personnage. Le bouton doit donc ignorer les unites que la file reserve
-- (`YayaQueueAPI.GetReservedItemQuantity`).
--
-- Le test extrait les deux fonctions de la source et les rejoue sur des sacs
-- simules.
--
-- Usage : lua5.1 Tests/test_finishing_merge.lua (depuis addons/YayaWeeklyTracker)

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

local handle = assert(io.open("YayaWeeklyTracker.lua", "rb"), "YayaWeeklyTracker.lua introuvable")
local source = handle:read("*a"):gsub("\r\n", "\n")
handle:close()

local function Extract(name, pattern)
    return (assert(source:match(pattern), name .. " introuvable"))
end

local reservedBody = Extract("GetQueueReservedQuantity",
    "(trackerUI%.GetQueueReservedQuantity = function%(itemID%).-\nend)\n")
-- 12.1.5 : la source lit C_Item.GetItemCount (alias global retire). Sans file
-- de craft, la table existe mais ne compte rien, comme la globale absente avant.
C_Item = C_Item or {}

local findBody = Extract("FindMergeableFinishingReagentsInBags",
    "(trackerUI%.FindMergeableFinishingReagentsInBags = function%(%).-\nend)\n")

-- ---------------------------------------------------------------------------
-- Environnement simule
-- ---------------------------------------------------------------------------

local MATRIX, MANIFOLD = 247719, 247724
local REBAR = 247725
local IDENTIFIER = 260630

trackerUI = {
    UsePreviousBagCacheOnTransientEmpty = function() return false end,
}
midnightCaches = { finishingReagentMergesDirty = true }
runtimeState = {
    mergeableFinishingReagents = {
        [REBAR] = { outputItemID = 247726, order = 1, label = "Resourceful" },
        [MATRIX] = { outputItemID = MANIFOLD, order = 2, label = "Multicraft" },
        [IDENTIFIER] = { outputItemID = 247788, order = 3, label = "Ingenuity" },
    },
}
NUM_TOTAL_EQUIPPED_BAG_SLOTS = 5
NUM_BAG_SLOTS = 4

local bags = {}   -- bagID -> { [slot] = { itemID, count } }
function GetContainerNumSlotsCompat(bagID)
    local bag = bags[bagID]
    if not bag then return 0 end
    local highest = 0
    for slot in pairs(bag) do highest = math.max(highest, slot) end
    return highest
end
function GetContainerItemIDCompat(bagID, slot)
    local entry = bags[bagID] and bags[bagID][slot]
    return entry and entry.itemID or nil
end
function GetContainerItemLinkCompat(bagID, slot)
    local entry = bags[bagID] and bags[bagID][slot]
    return entry and ("item:" .. entry.itemID) or nil
end
function GetContainerItemCountCompat(bagID, slot)
    local entry = bags[bagID] and bags[bagID][slot]
    return entry and entry.count or 0
end
function GetItemInfo(itemID) return "Objet " .. tostring(itemID) end

local reservations
local apiMode
YayaQueueAPI = nil

local function UseQueue(mode, table_)
    apiMode, reservations = mode, table_ or {}
    if mode == "absent" then
        YayaQueueAPI = nil
    elseif mode == "old" then
        YayaQueueAPI = {}
    else
        YayaQueueAPI = {
            GetReservedItemQuantity = function(itemID)
                if mode == "error" then error("boom") end
                if mode == "garbage" then return "beaucoup" end
                return reservations[itemID]
            end,
        }
    end
end

assert(loadstring(reservedBody .. "\n" .. findBody, "finishing-merge"))()

local function Fill(content)
    bags = { [0] = {} }
    local slot = 1
    for itemID, counts in pairs(content) do
        for _, count in ipairs(type(counts) == "table" and counts or { counts }) do
            bags[0][slot] = { itemID = itemID, count = count }
            slot = slot + 1
        end
    end
    midnightCaches.finishingReagentMergesDirty = true
    midnightCaches.finishingReagentMerges = nil
end

local function Merges()
    return trackerUI.FindMergeableFinishingReagentsInBags()
end

local function Find(results, itemID)
    for _, state in ipairs(results) do
        if state.itemID == itemID then return state end
    end
    return nil
end

-- ---------------------------------------------------------------------------
section("Sans file de craft : comportement inchange")
-- ---------------------------------------------------------------------------

UseQueue("absent")
Fill({ [MATRIX] = 12 })
local results = Merges()
equals("douze Matrix : une ligne de fusion", #results, 1)
equals("... deux fusions possibles", results[1].mergeCount, 2)
equals("... rien de reserve", results[1].reservedCount, 0)

Fill({ [MATRIX] = 4 })
equals("quatre Matrix : pas de fusion", #Merges(), 0)

Fill({ [MATRIX] = { 3, 3 } })
results = Merges()
equals("deux piles de trois : les piles s'additionnent", results[1] and results[1].mergeCount, 1)

UseQueue("old")
Fill({ [MATRIX] = 10 })
results = Merges()
equals("YayaQueue sans l'API de reservation : fusion comme avant", results[1] and results[1].mergeCount, 2)

-- ---------------------------------------------------------------------------
section("Avec une file qui reserve des exemplaires")
-- ---------------------------------------------------------------------------

UseQueue("queue", { [MATRIX] = 10 })
Fill({ [MATRIX] = 12 })
equals("douze Matrix dont dix reservees : deux libres, pas de fusion", #Merges(), 0)

UseQueue("queue", { [MATRIX] = 4 })
Fill({ [MATRIX] = 12 })
results = Merges()
equals("douze Matrix dont quatre reservees : huit libres", results[1] and results[1].usableCount, 8)
equals("... une seule fusion", results[1] and results[1].mergeCount, 1)
equals("... la reservation est exposee pour l'infobulle", results[1] and results[1].reservedCount, 4)

UseQueue("queue", { [MATRIX] = 40 })
Fill({ [MATRIX] = 12 })
equals("reservation superieure au stock : rien a fusionner, pas de negatif", #Merges(), 0)

UseQueue("queue", { [MATRIX] = 5 })
Fill({ [MATRIX] = 10, [REBAR] = 5, [IDENTIFIER] = 5 })
results = Merges()
equals("la reservation d'un objet ne touche pas les autres : trois lignes", #results, 3)
equals("... Rebar reste fusionnable", Find(results, REBAR) and Find(results, REBAR).mergeCount, 1)
equals("... Identifier reste fusionnable", Find(results, IDENTIFIER) and Find(results, IDENTIFIER).mergeCount, 1)
equals("... Matrix : cinq libres, une fusion", Find(results, MATRIX) and Find(results, MATRIX).mergeCount, 1)
equals("l'ordre d'affichage est conserve", results[1].itemID, REBAR)

-- ---------------------------------------------------------------------------
section("Scan de sacs transitoirement vide : seul un scan qui ne trouve rien est ecarte")
-- ---------------------------------------------------------------------------
-- Le garde de YayaWeeklyTracker garde l'ancien cache quand un scan ne rend rien
-- alors qu'il y en avait avant (curseur, deplacement d'objet). Un resultat vide
-- parce que la FILE a tout reserve est un etat vrai : le garde le ressortait
-- comme un scan rate et gardait le bouton Fusionner perime.

local guardBody = Extract("UsePreviousBagCacheOnTransientEmpty",
    "(trackerUI%.UsePreviousBagCacheOnTransientEmpty = function%(cacheKey, previousCount, currentCount, previousState%).-\nend)\n")
local resetBody = Extract("ResetBagScanRetry",
    "(trackerUI%.ResetBagScanRetry = function%(cacheKey%).-\nend)\n")

local owned = {}
C_Item = { GetItemCount = function(itemID) return owned[itemID] or 0 end }
function SafeCall(fn, ...)
    local ok, value = pcall(fn, ...)
    if ok then return value end
    return nil
end
function DebugLog() end
local retryTimers = {}
C_Timer = { After = function(delay, fn) retryTimers[#retryTimers + 1] = fn end }
assert(loadstring(resetBody .. "\n" .. guardBody, "bag-guard"))()
runtimeState.bagScanRetryCount, runtimeState.bagScanRetryQueued, runtimeState.bagScanRetryToken = {}, {}, {}

local function Rescan()
    midnightCaches.finishingReagentMergesDirty = true
    return Merges()
end

UseQueue("queue", {})
Fill({ [MATRIX] = 12 })
owned[MATRIX] = 12
equals("avant la reservation : une ligne de fusion", #Merges(), 1)
UseQueue("queue", { [MATRIX] = 12 })
results = Rescan()
equals("la file reserve tout : le bouton disparait au lieu de rester perime", #results, 0)
equals("... sans relance de scan en attente", #retryTimers, 0)

UseQueue("queue", {})
Fill({ [MATRIX] = 12 })
Merges()
bags = { [0] = {} }                 -- sacs vus vides : curseur, deplacement d'objet
results = Rescan()
equals("scan reellement vide alors que l'objet est possede : l'ancien cache est garde",
    #results, 1)
equals("... un nouveau scan est planifie", #retryTimers, 1)
owned[MATRIX] = 0
results = Rescan()
equals("... et si l'objet n'est plus possede, le vide est accepte", #results, 0)

-- ---------------------------------------------------------------------------
section("Une API defaillante ne bloque jamais la fusion")
-- ---------------------------------------------------------------------------

UseQueue("error")
Fill({ [MATRIX] = 10 })
results = Merges()
equals("l'API leve : on fusionne comme s'il n'y avait pas de file", results[1] and results[1].mergeCount, 2)

UseQueue("garbage")
Fill({ [MATRIX] = 10 })
results = Merges()
equals("l'API rend n'importe quoi : zero reserve", results[1] and results[1].mergeCount, 2)

-- ---------------------------------------------------------------------------
section("Branchement dans la source")
-- ---------------------------------------------------------------------------

equals("le clic relit la reservation avant d'executer l'action securisee",
    source:find('button:HookScript("PreClick"', source:find("FinishingReagentMergeButton", 1, true), true) ~= nil,
    true)
equals("... en retirant les attributs securises quand moins de cinq sont libres",
    source:find("if free < 5 then", 1, true) ~= nil, true)
equals("YayaQueue peut invalider le bouton",
    source:find("_G.YayaWeeklyTrackerAPI.InvalidateFinishingMerges = function()", 1, true) ~= nil, true)
equals("l'infobulle dit combien d'exemplaires la file garde",
    source:find("reserve(s) par YayaQueue", 1, true) ~= nil, true)

print(("\n%d OK, %d echec(s)"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
