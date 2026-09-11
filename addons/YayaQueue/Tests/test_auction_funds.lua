-- Tests unitaires du controle de bourse, du saut d'item et du filtrage des
-- annonces du compte a l'hotel des ventes, executes hors du jeu avec Lua 5.1.
--
-- Trois regressions vecues le 2026-09-11 sont fixees ici :
--   * un achat lance sans or suffisant ne produisait qu'un ERR_NOT_ENOUGH_MONEY
--     muet, la ligne restant blanche ;
--   * une annonce posee par un reroll du compte etait retenue comme meilleure
--     annonce, et le serveur repondait « you cannot bid on your own auctions »
--     a chaque clic ;
--   * aucun moyen de passer un item trop cher sans le retirer de la file.
--
-- Les fonctions sont extraites de la source et rejouees telles quelles, avec
-- une doublure de C_AuctionHouse qui rend les memes champs que le client.
--
-- Usage : lua5.1 Tests/test_auction_funds.lua   (depuis addons/YayaQueue)

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

-- ---------------------------------------------------------------------------
-- Extraction des definitions depuis la source de l'addon
-- ---------------------------------------------------------------------------

local handle = assert(io.open("YayaQueue.lua", "rb"), "YayaQueue.lua introuvable")
local source = handle:read("*a"):gsub("\r\n", "\n")
handle:close()

local chunks = {}

for _, name in ipairs({
    "GetItemVariantTaskKey",
    "CountTableKeys",
    "GetTaskAuctionCache",
    "GetAuctionTaskKey",
    "IsAuctionTaskSkipped",
    "SetAuctionTaskSkipped",
    "ClearSkippedAuctionTasks",
    "GetAuctionTaskCost",
    "GetPlayerMoney",
    "CanAffordAuctionCost",
    "DescribeInsufficientFunds",
    "IsOwnAuctionListing",
    "GetAuctionSkipTarget",
}) do
    local body = source:match("(state%." .. name .. " = function%(.-\nend)\n")
    assert(body, "state." .. name .. " introuvable dans la source")
    chunks[#chunks + 1] = body
end

for _, name in ipairs({
    "CaptureSearchCache%(itemID, searchItemKey%)",
    "GetNextPurchasableTask%(summary%)",
}) do
    local body = source:match("(local function " .. name .. ".-\nend)\n")
    assert(body, name .. " introuvable dans la source")
    chunks[#chunks + 1] = body:gsub("^local function", "function")
end

-- ---------------------------------------------------------------------------
-- Doublures du client
-- ---------------------------------------------------------------------------

state = {
    searchCache = {},
    craft = { qualityPriceCache = {} },
    ah = { skippedTasks = {} },
    CollectItemVariantDemands = function() return {} end,
    MakeSearchItemKey = function(itemID) return { itemID = itemID, itemLevel = 0 } end,
    DescribeItemVariant = function() return nil end,
    DescribeVariantSample = function() return "" end,
    InvalidateMaterialPricing = function() end,
}
YQQuality = { GetExpectedAuctionPrice = function() return nil end }

local COMMODITIES = {}
function IsCommodityItem(itemID) return COMMODITIES[itemID] == true end
function GetItemName(itemID) return "Item" .. tostring(itemID) end
function WarmItemData() end
function DebugPrint() end
function SafeCall() return nil end
function GetTime() return 0 end
function GetMoneyString(value) return tostring(value) .. "c" end

local MONEY = 0
function GetMoney() return MONEY end

local COMMODITY_RESULTS = {}
local ITEM_RESULTS = {}
C_AuctionHouse = {
    GetNumCommoditySearchResults = function(itemID)
        return #(COMMODITY_RESULTS[itemID] or {})
    end,
    GetCommoditySearchResultInfo = function(itemID, index)
        return (COMMODITY_RESULTS[itemID] or {})[index]
    end,
    GetNumItemSearchResults = function(itemKey)
        return #(ITEM_RESULTS[itemKey.itemID] or {})
    end,
    GetItemSearchResultInfo = function(itemKey, index)
        return (ITEM_RESULTS[itemKey.itemID] or {})[index]
    end,
}

assert(loadstring(table.concat(chunks, "\n"), "yq-auction-funds"))()

-- ---------------------------------------------------------------------------
-- Annonces du compte
-- ---------------------------------------------------------------------------

section("Une annonce du personnage ou d'un reroll n'est pas achetable")
equals("annonce du personnage", state.IsOwnAuctionListing({ containsOwnerItem = true }), true)
equals("annonce d'un reroll du compte", state.IsOwnAuctionListing({ containsAccountItem = true }), true)
equals("annonce d'un tiers", state.IsOwnAuctionListing({ containsOwnerItem = false, containsAccountItem = false }), false)
equals("resultat absent", state.IsOwnAuctionListing(nil), false)

section("Marchandise : une annonce du compte bloque tout ce qui la suit")
COMMODITIES[1001] = true
-- Livree dans le desordre : le serveur sert pourtant de la moins chere a la
-- plus chere, et c'est cet ordre qui compte.
COMMODITY_RESULTS[1001] = {
    { quantity = 4, unitPrice = 11 },
    { quantity = 5, unitPrice = 10, containsAccountItem = true },
    { quantity = 3, unitPrice = 9 },
}
CaptureSearchCache(1001)
local cache = state.searchCache[1001]
equals("unites achetables avant l'annonce du compte", cache.available, 3)
equals("unites du compte comptees a part", cache.ownQuantity, 5)
equals("prix unitaire = la moins chere achetable", cache.unitPrice, 9)
equals("une seule annonce retenue pour le cout", #cache.listings, 1)
equals("les resultats existent bien", cache.hasResults, true)

section("Marchandise : l'annonce du compte la moins chere ne laisse rien")
COMMODITIES[1002] = true
COMMODITY_RESULTS[1002] = {
    { quantity = 2, unitPrice = 5, containsOwnerItem = true },
    { quantity = 8, unitPrice = 6 },
}
CaptureSearchCache(1002)
equals("rien d'achetable", state.searchCache[1002].available, 0)
equals("prix unitaire inconnu", state.searchCache[1002].unitPrice, nil)
equals("unites du compte", state.searchCache[1002].ownQuantity, 2)

section("Objet : l'annonce du reroll n'est jamais la meilleure annonce")
ITEM_RESULTS[2001] = {
    { auctionID = 1, buyoutAmount = 100, quantity = 1, itemLink = "a", containsAccountItem = true },
    { auctionID = 2, buyoutAmount = 500, quantity = 1, itemLink = "b" },
}
CaptureSearchCache(2001)
cache = state.searchCache[2001]
equals("meilleure annonce = celle d'un tiers", cache.bestAuction and cache.bestAuction.auctionID, 2)
equals("une seule unite disponible", cache.available, 1)
equals("l'annonce du compte est comptee", cache.ownQuantity, 1)
equals("prix = buyout de l'annonce retenue", cache.unitPrice, 500)

-- ---------------------------------------------------------------------------
-- Cout et bourse
-- ---------------------------------------------------------------------------

section("Cout du prochain achat")
COMMODITIES[1003] = true
COMMODITY_RESULTS[1003] = {
    { quantity = 3, unitPrice = 9 },
    { quantity = 4, unitPrice = 11 },
}
CaptureSearchCache(1003)
cache = state.searchCache[1003]
local task = { itemID = 1003, name = "Reactif", missing = 5 }
local cost, covered = state.GetAuctionTaskCost(task, cache, cache)
equals("somme des annonces les moins cheres", cost, 3 * 9 + 2 * 11)
equals("quantite couverte", covered, 5)
task.missing = 2
equals("deux unites a 9", (state.GetAuctionTaskCost(task, cache, cache)), 18)
task.missing = 0
equals("rien a acheter = pas de cout", state.GetAuctionTaskCost(task, cache, cache), nil)

local itemTask = { itemID = 2001, name = "Surtout", missing = 1 }
cache = state.searchCache[2001]
equals("objet : buyout de la meilleure annonce", (state.GetAuctionTaskCost(itemTask, cache, cache)), 500)

section("Bourse")
MONEY = 40
equals("49c avec 40c : non", state.CanAffordAuctionCost(49), false)
equals("18c avec 40c : oui", state.CanAffordAuctionCost(18), true)
equals("40c avec 40c : oui", state.CanAffordAuctionCost(40), true)
equals("cout inconnu : indetermine", state.CanAffordAuctionCost(nil), nil)
local message = state.DescribeInsufficientFunds("Surtout", 500)
equals("le message nomme l'objet", message:find("Surtout", 1, true) ~= nil, true)
equals("le message donne le manque", message:find("460c", 1, true) ~= nil, true)
equals("cout inconnu : pas de faux zero",
    state.DescribeInsufficientFunds("Surtout", nil):find("requis", 1, true), nil)

-- ---------------------------------------------------------------------------
-- Choix de la prochaine tache
-- ---------------------------------------------------------------------------

section("Acheter suivant prefere une tache payable")
local summary = { auctionTasks = {
    { itemID = 2001, name = "Surtout", missing = 1 },
    { itemID = 1003, name = "Reactif", missing = 2 },
} }
MONEY = 40
local picked, view, blocked = GetNextPurchasableTask(summary)
equals("la tache payable passe devant", picked and picked.itemID, 1003)
equals("sa vue est rendue", view ~= nil, true)
equals("une tache payable trouvee : pas de blocage a signaler", blocked, nil)

MONEY = 10
picked, view, blocked = GetNextPurchasableTask(summary)
equals("rien de payable : aucune tache", picked, nil)
equals("le blocage designe la premiere tache", blocked and blocked.task.itemID, 2001)
equals("avec son cout", blocked and blocked.cost, 500)

section("Le bouton Passer ecarte une tache pour la session")
MONEY = 1000
equals("cible du saut = ce que le clic acheterait", state.GetAuctionSkipTarget(summary).itemID, 2001)
equals("marquage accepte", state.SetAuctionTaskSkipped(summary.auctionTasks[1], true), true)
equals("la tache est passee", state.IsAuctionTaskSkipped(summary.auctionTasks[1]), true)
equals("l'autre ne l'est pas", state.IsAuctionTaskSkipped(summary.auctionTasks[2]), false)
picked = GetNextPurchasableTask(summary)
equals("Acheter suivant saute la tache passee", picked and picked.itemID, 1003)
equals("la cible du saut avance", state.GetAuctionSkipTarget(summary).itemID, 1003)

section("Deux variantes du meme itemID se passent separement")
local toolA = { itemID = 3001, variantKey = "rank:2|stat:resourcefulness" }
local toolB = { itemID = 3001, variantKey = "rank:2|stat:multicraft" }
state.SetAuctionTaskSkipped(toolA, true)
equals("variante A passee", state.IsAuctionTaskSkipped(toolA), true)
equals("variante B intacte", state.IsAuctionTaskSkipped(toolB), false)
equals("cle de la variante", state.GetAuctionTaskKey(toolA), "3001#rank:2|stat:resourcefulness")
equals("cle sans variante = itemID", state.GetAuctionTaskKey({ itemID = 2001 }), 2001)

section("Maj+Passer retablit tout")
equals("deux taches retablies", state.ClearSkippedAuctionTasks(), 2)
equals("plus rien de passe", state.IsAuctionTaskSkipped(summary.auctionTasks[1]), false)
equals("un second appel ne compte rien", state.ClearSkippedAuctionTasks(), 0)

print("")
print(("%d reussite(s), %d echec(s)"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
