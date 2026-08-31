-- Tests unitaires du mode Cancel & Repost, executes hors du jeu avec Lua 5.1.
--
-- Seules les fonctions de decision sont testees : prix de mise en vente, verdict
-- d'annulation, quantite a poster. Les acces au jeu (sacs, hotel des ventes) et
-- a TSM sont remplaces par des doublures.
--
-- Usage : lua5.1 Tests/test_yayareagentsnipersell.lua   (depuis addons/YayaReagentSniper)

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

local function section(title)
    print("")
    print(title)
end

-- ---------------------------------------------------------------------------
-- Doublures : table de prix TSM et operations
-- ---------------------------------------------------------------------------

-- Prix rendus par la doublure de GetCustomPriceValue, en cuivre.
local prices = {}
local operations = {}

local controller = {
    getCustomPriceValue = function(source, itemString)
        local byItem = prices[itemString]
        if byItem and byItem[source] ~= nil then
            return byItem[source]
        end
        return prices[source]
    end,
    getOperationForItem = function(itemString, typeName)
        local entry = operations[itemString]
        if not entry or typeName ~= "Auctioning" then
            return nil
        end
        return entry.settings, entry.name, entry.all
    end,
    resolveOperationSetting = function(all, name, key, default)
        local current, visited = name, {}
        while current and not visited[current] do
            visited[current] = true
            local settings = all and all[current]
            if not settings then
                return default
            end
            local nextName = settings.relationships and settings.relationships[key]
            if not nextName then
                local value = settings[key]
                if value ~= nil then
                    return value
                end
                return default
            end
            current = nextName
        end
        return default
    end,
}

local chunk = assert(loadfile("YayaReagentSniperSell.lua"))
chunk("YayaReagentSniper")
local Sell = _G.YayaReagentSniperSell
Sell.Init(controller)

local ITEM = "i:210796"

-- ---------------------------------------------------------------------------
section("Arrondi et duree")
-- ---------------------------------------------------------------------------

equals("le prix est arrondi au silver superieur", Sell.RoundPrice(12345), 12400)
equals("un prix deja rond est inchange", Sell.RoundPrice(12300), 12300)
equals("un prix nul n'est pas un prix", Sell.RoundPrice(0), nil)
equals("duree 1 = 12 h", Sell.GetDurationHours(1), 12)
equals("duree 2 = 24 h", Sell.GetDurationHours(2), 24)
equals("duree 3 = 48 h", Sell.GetDurationHours(3), 48)
equals("duree inconnue : repli sur 24 h", Sell.GetDurationHours(nil), 24)

-- ---------------------------------------------------------------------------
section("Prix sans operation : le plancher automatique")
-- ---------------------------------------------------------------------------

local FLOOR = Sell.GetFallbackFloorSource()

prices = { [ITEM] = { [FLOOR] = 10000 } }
local price, reason = Sell.ComputePostPrice({ itemString = ITEM, marketPrice = 25000 })
equals("marche au-dessus du plancher : on undercut le marche", price, 25000)

price, reason = Sell.ComputePostPrice({ itemString = ITEM, marketPrice = 9000 })
equals("marche sous le plancher : aucune mise en vente", price, nil)
check("le refus sous plancher est motive", type(reason) == "string" and reason:find("plancher") ~= nil, reason)

price = Sell.ComputePostPrice({ itemString = ITEM, marketPrice = nil })
equals("aucune concurrence : mise en vente au plancher", price, 10000)

prices = { [ITEM] = {} }
price, reason = Sell.ComputePostPrice({ itemString = ITEM, marketPrice = 25000 })
equals("plancher introuvable : aucune mise en vente", price, nil)
check("le plancher introuvable est motive", type(reason) == "string" and reason:find("plancher") ~= nil, reason)

-- ---------------------------------------------------------------------------
section("Prix avec operation TSM")
-- ---------------------------------------------------------------------------

local function UseOperation(settings, all, name)
    all = all or { ["#Default"] = settings }
    name = name or "#Default"
    operations = { [ITEM] = { settings = settings, name = name, all = all } }
    return Sell.GetAuctioningOperation(ITEM)
end

prices = {
    [ITEM] = {
        ["minPrice"] = 10000,
        ["maxPrice"] = 50000,
        ["normalPrice"] = 30000,
        ["0c"] = 0,
        ["1g"] = 10000,
    },
}

local op = UseOperation({
    minPrice = "minPrice",
    maxPrice = "maxPrice",
    normalPrice = "normalPrice",
    undercut = "0c",
    aboveMax = "maxPrice",
    priceReset = "none",
})

price = Sell.ComputePostPrice({ itemString = ITEM, operation = op, marketPrice = 25000 })
equals("concurrence dans les bornes : on s'aligne", price, 25000)

price, reason = Sell.ComputePostPrice({ itemString = ITEM, operation = op, marketPrice = nil })
equals("aucune concurrence : prix normal de l'operation", price, 30000)

price = Sell.ComputePostPrice({ itemString = ITEM, operation = op, marketPrice = 80000 })
equals("concurrence au-dessus du maximum : repli sur maxPrice", price, 50000)

price, reason = Sell.ComputePostPrice({ itemString = ITEM, operation = op, marketPrice = 5000 })
equals("concurrence sous le minimum avec priceReset none : pas de vente", price, nil)
check("le refus sous minimum est motive", type(reason) == "string" and reason:find("minimum") ~= nil, reason)

op = UseOperation({
    minPrice = "minPrice",
    maxPrice = "maxPrice",
    normalPrice = "normalPrice",
    undercut = "0c",
    aboveMax = "maxPrice",
    priceReset = "minPrice",
})
price = Sell.ComputePostPrice({ itemString = ITEM, operation = op, marketPrice = 5000 })
equals("concurrence sous le minimum avec priceReset minPrice : on poste au minimum", price, 10000)

op = UseOperation({
    minPrice = "minPrice",
    maxPrice = "maxPrice",
    normalPrice = "normalPrice",
    undercut = "0c",
    aboveMax = "none",
    priceReset = "none",
})
price, reason = Sell.ComputePostPrice({ itemString = ITEM, operation = op, marketPrice = 80000 })
equals("concurrence au-dessus du maximum avec aboveMax none : pas de vente", price, nil)

-- L'operation TSM fait autorite : le plancher automatique ne s'applique pas.
prices[ITEM][FLOOR] = 40000
op = UseOperation({
    minPrice = "minPrice",
    maxPrice = "maxPrice",
    normalPrice = "normalPrice",
    undercut = "0c",
    aboveMax = "maxPrice",
    priceReset = "none",
})
price = Sell.ComputePostPrice({ itemString = ITEM, operation = op, marketPrice = 25000 })
equals("le plancher automatique ne s'applique pas sous operation", price, 25000)
prices[ITEM][FLOOR] = nil

-- ---------------------------------------------------------------------------
section("Chaine relationships")
-- ---------------------------------------------------------------------------

local shared = {
    ["Base"] = { minPrice = "minPrice", maxPrice = "maxPrice", normalPrice = "normalPrice" },
    ["Derivee"] = {
        relationships = { minPrice = "Base", maxPrice = "Base", normalPrice = "Base" },
        undercut = "0c",
        aboveMax = "maxPrice",
        priceReset = "none",
    },
}
op = UseOperation(shared["Derivee"], shared, "Derivee")
price = Sell.ComputePostPrice({ itemString = ITEM, operation = op, marketPrice = 80000 })
equals("les cles heritees sont resolues via l'operation parente", price, 50000)

-- ---------------------------------------------------------------------------
section("Quantite a poster")
-- ---------------------------------------------------------------------------

prices = { [ITEM] = {} }
op = UseOperation({ postCap = "5", keepQuantity = "0" })
equals("quantite bornee par le postCap", (Sell.GetPostQuantity(op, 20, ITEM, 0)), 5)
equals("quantite bornee par le stock", (Sell.GetPostQuantity(op, 3, ITEM, 0)), 3)

op = UseOperation({ postCap = "5", keepQuantity = "10" })
equals("keepQuantity retire du disponible", (Sell.GetPostQuantity(op, 12, ITEM, 0)), 2)
equals("keepQuantity superieur au stock : rien a poster", (Sell.GetPostQuantity(op, 8, ITEM, 0)), 0)

op = UseOperation({ postCap = "0", keepQuantity = "0" })
local quantity, why = Sell.GetPostQuantity(op, 20, ITEM, 0)
equals("postCap a 0 signifie poster zero", quantity, 0)
equals("le motif du refus est le postCap", why, "postCap")

op = UseOperation({ postCap = "5", keepQuantity = "0" })
equals("les reservations de craft reduisent le disponible", (Sell.GetPostQuantity(op, 8, ITEM, 6)), 2)

equals("sans operation : postCap par defaut", (Sell.GetPostQuantity(nil, 20, ITEM, 0)), 5)

-- ---------------------------------------------------------------------------
section("Verdict d'annulation")
-- ---------------------------------------------------------------------------

prices = { [ITEM] = { ["1g"] = 10000 } }

local function Cancel(auction, market, settings)
    local operation = settings and UseOperation(settings) or nil
    return Sell.ShouldCancel(auction, market, operation, ITEM)
end

local cancel, motive = Cancel({ unitPrice = 20000 }, { lowestOther = 15000 })
equals("sous-cote : on annule", cancel, true)
check("la sous-cotation est motivee", type(motive) == "string" and motive:find("moins cher") ~= nil, motive)

cancel = Cancel({ unitPrice = 20000 }, { lowestOther = 25000 })
equals("moins cher que la concurrence : on garde", cancel, false)

cancel, motive = Cancel({ unitPrice = 20000 }, { lowestOther = 20000, hasOtherAtSamePrice = true })
equals("egalite avec un autre vendeur : on annule (LIFO)", cancel, true)

cancel = Cancel({ unitPrice = 20000 }, { lowestOther = 20000, hasOtherAtSamePrice = false })
equals("seul au prix mini : on garde", cancel, false)

cancel, motive = Cancel({ unitPrice = 20000 }, { lowestOther = 15000 }, { cancelUndercut = false })
equals("cancelUndercut a false : on n'annule pas la sous-cotation", cancel, false)

cancel = Cancel(
    { unitPrice = 20000 },
    { targetPrice = 40000 },
    { cancelUndercut = true, cancelRepost = true, cancelRepostThreshold = "1g" }
)
equals("ecart au-dessus du seuil : on annule pour reposter plus haut", cancel, true)

cancel = Cancel(
    { unitPrice = 20000 },
    { targetPrice = 25000 },
    { cancelUndercut = true, cancelRepost = true, cancelRepostThreshold = "1g" }
)
equals("ecart sous le seuil : on garde", cancel, false)

cancel = Cancel(
    { unitPrice = 20000 },
    { targetPrice = 40000 },
    { cancelUndercut = true, cancelRepost = false }
)
equals("cancelRepost a false : pas d'annulation pour reposter", cancel, false)

cancel, motive = Cancel(
    { unitPrice = 20000, timeLeftSeconds = 600 },
    { lowestOther = 15000 },
    { ignoreLowDuration = 1 }
)
equals("duree restante sous le seuil : on garde", cancel, false)
check("la duree courte est motivee", type(motive) == "string" and motive:find("Duree") ~= nil, motive)

cancel = Cancel(
    { unitPrice = 20000, timeLeftSeconds = 3600 },
    { lowestOther = 15000 },
    { ignoreLowDuration = 1 }
)
equals("duree restante au-dessus du seuil : on annule", cancel, true)

cancel = Cancel(
    { unitPrice = 20000, timeLeftSeconds = 600 },
    { lowestOther = 15000 },
    { ignoreLowDuration = 0 }
)
equals("ignoreLowDuration a 0 : la duree n'ecarte rien", cancel, true)

cancel = Cancel({ unitPrice = 20000 }, { lowestOther = 15000 }, { cancelUndercut = false, cancelRepost = false })
equals("les deux drapeaux a false : jamais d'annulation", cancel, false)

equals("sans marche connu : on garde", (Sell.ShouldCancel({ unitPrice = 20000 }, {}, nil, ITEM)), false)
equals("enchere sans prix : on garde", (Sell.ShouldCancel({}, { lowestOther = 1 }, nil, ITEM)), false)

-- ---------------------------------------------------------------------------

print("")
print(("%d reussis, %d echoues"):format(passed, failed))
if failed > 0 then
    os.exit(1)
end
