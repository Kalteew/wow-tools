-- Tests unitaires de la fenetre de stock en transit, executes hors du jeu.
--
-- Le transit sert a couvrir le trou entre un achat a l'hotel des ventes et le
-- moment ou TSM voit la marchandise. Une entree qui survit a cette fenetre passe
-- pour du stock : le besoin disparait et l'item n'est plus jamais propose, meme
-- a zero exemplaire. C'est le bug corrige ici, donc la partie a tester.
--
-- Usage : lua5.1 Tests/test_yayareagentsnipertransit.lua   (depuis addons/YayaReagentSniper)

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
    check(name, actual == expected,
        ("attendu %s, obtenu %s"):format(tostring(expected), tostring(actual)))
end

-- ---------------------------------------------------------------------------
-- Copie des fonctions pures
-- ---------------------------------------------------------------------------

-- YayaReagentSniper.lua ne peut pas etre charge ici : son chunk appelle
-- CreateFrame des le niveau superieur. Les deux fonctions sont donc reproduites
-- a l'identique, et le controle de source en fin de fichier verifie qu'elles
-- n'ont pas diverge.
local TRANSIT_TTL_SECONDS = 2 * 60 * 60

local function IsTransitEntryUsable(entry, now)
    if type(entry) ~= "table" then
        return false
    end
    if (tonumber(entry.quantity) or 0) <= 0 then
        return false
    end
    local createdAt = tonumber(entry.createdAt)
    if not createdAt or createdAt > now or now - createdAt >= TRANSIT_TTL_SECONDS then
        return false
    end
    return true
end

local function ReconcileTransitEntry(entry, rawQuantity, now)
    if not IsTransitEntryUsable(entry, now) then
        return 0
    end
    local pending = math.max(0, math.floor(tonumber(entry.quantity) or 0))
    local observed = tonumber(entry.observedInventory) or rawQuantity
    if rawQuantity > observed then
        pending = math.max(0, pending - (rawQuantity - observed))
    end
    entry.observedInventory = rawQuantity
    entry.quantity = pending
    return pending
end

-- Ce que l'appelant fait du resultat : le transit s'ajoute au stock brut tant
-- que la fenetre vit, et disparait des qu'elle se ferme.
local function ShoppingInventory(entry, rawQuantity, now)
    local pending = ReconcileTransitEntry(entry, rawQuantity, now)
    if pending <= 0 then
        return rawQuantity, nil
    end
    return rawQuantity + pending, entry
end

local NOW = 1000000

local function NewEntry(quantity, observed, ageSeconds)
    return {
        quantity = quantity,
        observedInventory = observed,
        createdAt = NOW - (ageSeconds or 0),
        itemString = "i:243599",
    }
end

print("")
print("Fenetre de stock en transit")

-- ---------------------------------------------------------------------------
-- Une fenetre ouverte protege du rachat
-- ---------------------------------------------------------------------------

-- Le courrier n'est pas encore releve : les 200 unites achetees comptent, sinon
-- le sniper les racheterait a chaque rafraichissement.
local entry = NewEntry(200, 50, 60)
local have, kept = ShoppingInventory(entry, 50, NOW)
equals("achat recent : le transit compte comme du stock", have, 250)
check("achat recent : l'entree survit", kept ~= nil)

-- Le courrier est arrive en entier : le stock brut porte deja les 200 unites.
entry = NewEntry(200, 50, 300)
have, kept = ShoppingInventory(entry, 250, NOW)
equals("courrier arrive : plus rien en transit", have, 250)
check("courrier arrive : l'entree est oubliee", kept == nil)

-- Arrivee partielle : seul le reste reste en vol.
entry = NewEntry(200, 50, 300)
have = ShoppingInventory(entry, 120, NOW)
equals("courrier partiel : le reste reste en vol", have, 250)
equals("courrier partiel : quantite decrementee", entry.quantity, 130)
equals("courrier partiel : niveau observe suivi", entry.observedInventory, 120)

-- ---------------------------------------------------------------------------
-- Non-regression : la fenetre se ferme toujours
-- ---------------------------------------------------------------------------

-- Le bug : le courrier releve hors hotel des ventes puis le stock consomme. Le
-- stock ne remonte jamais au-dessus du niveau observe, donc l'ancienne version
-- gardait la quantite en transit pour toujours et n'offrait plus jamais l'item.
entry = NewEntry(1560, 285, 0)
for _ = 1, 5 do
    entry.createdAt = NOW - 60
    ShoppingInventory(entry, 0, NOW)
end
equals("stock consomme : le transit ne se resorbe pas de lui-meme", entry.quantity, 1560)

entry = NewEntry(1560, 285, TRANSIT_TTL_SECONDS)
have, kept = ShoppingInventory(entry, 0, NOW)
equals("transit perime : le besoin reel ressort", have, 0)
check("transit perime : l'entree est oubliee", kept == nil)

-- Une entree ecrite par la version sans horodatage bloquait le restock sans fin.
entry = { quantity = 1560, observedInventory = 285, itemString = "i:243599" }
have, kept = ShoppingInventory(entry, 0, NOW)
equals("entree heritee sans date : ignoree", have, 0)
check("entree heritee sans date : oubliee", kept == nil)

-- Horloge qui recule ou date bricolee : on ne fait pas confiance au futur.
entry = NewEntry(200, 50, -600)
have = ShoppingInventory(entry, 0, NOW)
equals("date dans le futur : ignoree", have, 0)

-- Formes degenerees.
equals("quantite nulle : ignoree", (ShoppingInventory(NewEntry(0, 50, 60), 7, NOW)), 7)
equals("quantite negative : ignoree", (ShoppingInventory(NewEntry(-5, 50, 60), 7, NOW)), 7)
equals("entree absente : stock brut", (ShoppingInventory(nil, 7, NOW)), 7)
equals("entree corrompue : stock brut", (ShoppingInventory("transit", 7, NOW)), 7)

-- La borne est stricte : une seconde avant la peremption, la fenetre vit encore.
equals("juste avant la peremption : encore compte",
    (ShoppingInventory(NewEntry(10, 0, TRANSIT_TTL_SECONDS - 1), 0, NOW)), 10)
equals("pile a la peremption : ferme",
    (ShoppingInventory(NewEntry(10, 0, TRANSIT_TTL_SECONDS), 0, NOW)), 0)

-- ---------------------------------------------------------------------------
-- Non-regression : la copie ci-dessus doit suivre la source
-- ---------------------------------------------------------------------------

local handle = assert(io.open("YayaReagentSniper.lua", "rb"))
local source = handle:read("*a")
handle:close()
-- L'arbre de travail est rendu en CRLF : sans normalisation, aucun motif
-- contenant un saut de ligne ne trouverait sa cible.
source = source:gsub("\r\n", "\n")

check("la source declare la peremption du transit",
    source:find("local TRANSIT_TTL_SECONDS = 2 * 60 * 60", 1, true) ~= nil)

local usable = source:match("local function IsTransitEntryUsable%(entry, now%)\n(.-)\nend\n")
check("la garde de fenetre est presente dans la source", usable ~= nil)
check("la garde exige un horodatage",
    usable ~= nil and usable:find("if not createdAt or createdAt > now or now - createdAt >= TRANSIT_TTL_SECONDS then", 1, true) ~= nil)

local reconcile = source:match("local function ReconcileTransitEntry%(entry, rawQuantity, now%)\n(.-)\nend\n")
check("la reconciliation est presente dans la source", reconcile ~= nil)
check("la reconciliation passe par la garde",
    reconcile ~= nil and reconcile:find("if not IsTransitEntryUsable(entry, now) then", 1, true) ~= nil)
check("la reconciliation resorbe la hausse de stock",
    reconcile ~= nil and reconcile:find("pending - (rawQuantity - observed)", 1, true) ~= nil)

check("un achat date la fenetre",
    source:find("entry.createdAt = time()", 1, true) ~= nil)
check("la fermeture du courrier vide le transit",
    source:find('DropTransitEntries("mail-closed", true)', 1, true) ~= nil)
check("le chargement purge les entrees perimees",
    source:find('DropTransitEntries("addon-loaded", false)', 1, true) ~= nil)
check("MAIL_CLOSED est ecoute hors hotel des ventes",
    source:find('eventFrame:RegisterEvent("MAIL_CLOSED")', 1, true) ~= nil)
check("la commande de purge existe",
    source:find('DropTransitEntries("slash-clear", true)', 1, true) ~= nil)
check("le stock en transit n'est plus ajoute sans garde",
    source:find("local pendingQuantity = math.max(0, math.floor(tonumber(entry.quantity) or 0))", 1, true) == nil)

-- ---------------------------------------------------------------------------
-- Verdict
-- ---------------------------------------------------------------------------

print("")
print(("%d reussis, %d echoues"):format(passed, failed))
if failed > 0 then
    os.exit(1)
end
