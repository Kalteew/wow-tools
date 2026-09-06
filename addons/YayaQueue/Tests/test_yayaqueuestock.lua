-- Tests unitaires de la composition du stock vendable, executes hors du jeu
-- avec Lua 5.1.
--
-- YQQuality.ComposeSellableStock est volontairement pure : elle recoit les
-- comptages deja faits et n'appelle aucune API du jeu. C'est ce qui permet de
-- verifier ici la seule regle qui compte vraiment -- ce qui entre dans le total
-- et avec quel niveau de confiance -- sans doublure de CreateFrame ni de TSM.
--
-- Usage : lua5.1 Tests/test_yayaqueuestock.lua   (depuis addons/YayaQueue)

-- ---------------------------------------------------------------------------
-- Mini harnais
-- ---------------------------------------------------------------------------

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
-- Extraction des deux definitions depuis la source de l'addon
-- ---------------------------------------------------------------------------

local handle = assert(io.open("YayaQueue.lua", "rb"), "YayaQueue.lua introuvable")
local source = handle:read("*a"):gsub("\r\n", "\n")
handle:close()

local sources = source:match("(YQQuality%.STOCK_SOURCES = %b{})")
assert(sources, "YQQuality.STOCK_SOURCES introuvable")
local compose = source:match("(function YQQuality%.ComposeSellableStock%(raw%).-\nend)\n")
assert(compose, "YQQuality.ComposeSellableStock introuvable")

YQQuality = {}
assert(loadstring(sources .. "\n" .. compose, "compose"))()

local function sourceEntry(stock, key)
    for _, entry in ipairs(stock.sources) do
        if entry.key == key then return entry.count, entry.confidence end
    end
    return nil, "absente"
end

-- ---------------------------------------------------------------------------
-- Cas nominal : un objet poste sur plusieurs royaumes
-- ---------------------------------------------------------------------------

section("Cas nominal : sacs, banque et banque d'aventuriers lus, TSM present")

-- 1 en sac, 2 en banque d'aventuriers, 2 aux encheres du perso, 14 chez les
-- alts, 2 chez un alt hors enchere. TSM voit 3 pour le perso : 1 sac + 2 en
-- courrier, que le scan natif ne peut pas voir.
local stock = YQQuality.ComposeSellableStock({
    reference = "i:244714::i232",
    bagsUnbound = 1, bagsAll = 1,
    bankUnbound = 0, bankAll = 0,
    warbandUnbound = 2,
    tsm = { itemString = "i:244714::i232", player = 3, alts = 2,
            auctions = 2, altAuctions = 14, warbank = 2 },
})
equals("total", stock.total, 23)
equals("courrier deduit par difference", (sourceEntry(stock, "mail")), 2)
equals("encheres perso et alts cumulees", (sourceEntry(stock, "auctions")), 16)
equals("les encheres sont certaines", select(2, sourceEntry(stock, "auctions")), "certain")
equals("les alts restent non verifies", select(2, sourceEntry(stock, "alts")), "unverified")
equals("la banque d'aventuriers scannee est certaine",
    select(2, sourceEntry(stock, "warband")), "certain")
equals("total marque approximatif", stock.approximate, true)
equals("aucune source illisible", stock.hasUnknown, false)

-- ---------------------------------------------------------------------------
-- La correction qui motive tout : TSM compte les copies liees, pas nous
-- ---------------------------------------------------------------------------

section("Copie liee dans les sacs : comptee par TSM, exclue du stock vendable")

-- Deux exemplaires en sac dont un deja lie. TSM en voit 2, le scan n'en retient
-- qu'un. Le total doit suivre le scan, pas TSM.
stock = YQQuality.ComposeSellableStock({
    bagsUnbound = 1, bagsAll = 2,
    bankUnbound = 0, bankAll = 0,
    warbandUnbound = 0,
    tsm = { itemString = "i:1", player = 2, alts = 0,
            auctions = 0, altAuctions = 0, warbank = 0 },
})
equals("les sacs ne comptent que la copie libre", (sourceEntry(stock, "bags")), 1)
equals("la copie liee ne ressort pas en courrier", (sourceEntry(stock, "mail")), 0)
equals("total sans la copie liee", stock.total, 1)

-- ---------------------------------------------------------------------------
-- Jamais un faux zero
-- ---------------------------------------------------------------------------

section("Banque jamais ouverte : fusionnee avec le courrier plutot qu'affichee a zero")

stock = YQQuality.ComposeSellableStock({
    bagsUnbound = 1, bagsAll = 1,
    bankUnbound = nil, bankAll = nil,
    warbandUnbound = nil,
    tsm = { itemString = "i:1", player = 5, alts = 0,
            auctions = 0, altAuctions = 0, warbank = 3 },
})
equals("pas de ligne banque isolee", (sourceEntry(stock, "bank")), nil)
equals("banque et courrier regroupes", (sourceEntry(stock, "selfOther")), 4)
equals("banque d'aventuriers repliee sur TSM", (sourceEntry(stock, "warband")), 3)
equals("ce repli est non verifie", select(2, sourceEntry(stock, "warband")), "unverified")
equals("total", stock.total, 8)

section("TSM absent : le scan natif seul compte, le reste reste inconnu")

stock = YQQuality.ComposeSellableStock({
    bagsUnbound = 4, bagsAll = 4,
    bankUnbound = 2, bankAll = 2,
    warbandUnbound = 1,
    tsm = nil,
})
equals("total natif", stock.total, 7)
equals("encheres inconnues", select(2, sourceEntry(stock, "auctions")), "unknown")
equals("alts inconnus", select(2, sourceEntry(stock, "alts")), "unknown")
equals("total marque incomplet", stock.hasUnknown, true)
equals("une source inconnue n'a pas de compte", (sourceEntry(stock, "auctions")), nil)

section("TSM en retard sur le scan : la difference ne devient jamais negative")

stock = YQQuality.ComposeSellableStock({
    bagsUnbound = 10, bagsAll = 10,
    bankUnbound = 0, bankAll = 0,
    warbandUnbound = 0,
    tsm = { itemString = "i:1", player = 0, alts = 0,
            auctions = 0, altAuctions = 0, warbank = 0 },
})
equals("courrier borne a zero", (sourceEntry(stock, "mail")), 0)
equals("total", stock.total, 10)

-- ---------------------------------------------------------------------------
-- L'infobulle doit lister les memes lignes dans le meme ordre a chaque passe
-- ---------------------------------------------------------------------------

section("Ordre d'affichage stable")

stock = YQQuality.ComposeSellableStock({
    bagsUnbound = 1, bagsAll = 1, bankUnbound = 1, bankAll = 1, warbandUnbound = 1,
    tsm = { itemString = "i:1", player = 2, alts = 1,
            auctions = 1, altAuctions = 1, warbank = 1 },
})
local order = {}
for _, entry in ipairs(stock.sources) do
    order[#order + 1] = entry.key
end
equals("ordre des sources", table.concat(order, ","),
    "bags,bank,warband,mail,alts,auctions")

-- ---------------------------------------------------------------------------
-- Garde-fous de source : ces regles ne se voient pas dans la fonction pure
-- ---------------------------------------------------------------------------

section("Garde-fous de source")

equals("le scan conserve les copies liees en les marquant",
    source:find("bound = isBound == true", 1, true) ~= nil, true)
equals("aucun conteneur signifie inconnu, pas zero",
    source:find("if #bagIDs == 0 then return nil end", 1, true) ~= nil, true)
equals("les totaux TSM sont memoises",
    source:find("cache.tsmTotals[itemString]", 1, true) ~= nil, true)
equals("le profit de reference reste sur dbminbuyout",
    source:find('pricing.profit = NetValue(pricing.minBuyout)', 1, true) ~= nil, true)
equals("avgsell est lu sur la reference de sortie exacte",
    source:find('YQQuality.GetTSMPrice("avgsell", outputReference)', 1, true) ~= nil, true)
equals("le corps du panneau n'active pas la souris",
    source:find("frame:EnableMouse(true)", 1, true) == nil, true)
equals("les lignes informatives laissent passer le clic",
    source:find("row:SetMouseClickEnabled(false)", 1, true) ~= nil, true)

print("")
print(("%d reussis, %d echoues"):format(passed, failed))
if failed > 0 then
    os.exit(1)
end
