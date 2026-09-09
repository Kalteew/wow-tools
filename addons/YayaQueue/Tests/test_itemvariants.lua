-- Tests unitaires des variantes d'achat, executes hors du jeu avec Lua 5.1.
--
-- Ce qui est verifie ici est la seule chose qui empeche la file d'acheter un
-- outil rang 1 a statistique quelconque : la lecture des bonusIds sur le lien
-- d'une annonce, le verdict de conformite, et l'identite d'une variante. Ces
-- fonctions ne touchent aucune frame : elles sont extraites de la source de
-- l'addon et rejouees telles quelles, sans doublure de CreateFrame.
--
-- Usage : lua5.1 Tests/test_itemvariants.lua   (depuis addons/YayaQueue)

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
    "NormalizeItemVariant",
    "GetItemVariantKey",
    "DescribeItemVariant",
    "GetLinkBonusIDs",
    "DoesLinkMatchVariant",
}) do
    local pattern = "(state%." .. name .. " = function%(.-\nend)\n"
    local body = source:match(pattern)
    assert(body, "state." .. name .. " introuvable dans la source")
    chunks[#chunks + 1] = body
end

-- Les fonctions extraites resolvent `state`, `SafeCall` et l'API du client
-- comme des globales : la doublure doit donc rendre autant de valeurs que la
-- vraie API, sinon le test masque exactement la classe de bug qu'il surveille.
state = {}

function SafeCall(func, ...)
    if type(func) ~= "function" then
        return nil
    end
    local ok, result = pcall(func, ...)
    if ok then
        return result
    end
    return nil
end

local ITEM_LEVEL_BY_LINK = {}
function GetDetailedItemLevelInfo(link)
    local itemLevel = ITEM_LEVEL_BY_LINK[link]
    if not itemLevel then
        return nil, false, nil
    end
    return itemLevel, false, itemLevel
end

assert(loadstring(table.concat(chunks, "\n"), "variants"))()

-- ---------------------------------------------------------------------------
-- Liens reels, releves dans les SavedVariables du client
-- ---------------------------------------------------------------------------

-- Trois bonusIds (8851, 8852, 9404) puis cinq modificateurs. Le champ 13 porte
-- le nombre de bonusIds : sans ce comptage, le « 5 » des modificateurs et les
-- paires qui suivent seraient pris pour des bonusIds.
local GEAR_LINK = "|cffa335ee|Hitem:200641::::::::80:66::13:3:8851:8852:9404:5:28:2164:29:32:30:49:38:7:40:783:::::|h[x]|h|r"
-- Outil de metier Midnight rang maximal, statistique Resourcefulness (8952).
local RF_TOOL_LINK = "|cff0070dd|Hitem:245778::::::::90:104::13:4:8952:12251:12253:12502:1:29:81:::::|h[x]|h|r"
-- Meme outil, meme rang, statistique Multicraft (8953).
local MC_TOOL_LINK = "|cff0070dd|Hitem:245778::::::::90:104::13:4:8953:12251:12253:12502:1:29:81:::::|h[x]|h|r"
-- Meme statistique, rang inferieur : c'est l'annonce que la file achetait.
local RF_LOW_RANK_LINK = "|cff0070dd|Hitem:245778::::::::90:104::13:4:8952:12251:12253:12499:1:29:81:::::|h[x]|h|r"
-- Un objet sans aucun bonusId : l'item de base, celui que l'infobulle d'un
-- simple itemID montre, ilvl 32 et statistique encore aleatoire.
local BASE_LINK = "|cff0070dd|Hitem:245778::::::::90:104|h[x]|h|r"

ITEM_LEVEL_BY_LINK[GEAR_LINK] = 447
ITEM_LEVEL_BY_LINK[RF_TOOL_LINK] = 232
ITEM_LEVEL_BY_LINK[MC_TOOL_LINK] = 232
ITEM_LEVEL_BY_LINK[RF_LOW_RANK_LINK] = 206
ITEM_LEVEL_BY_LINK[BASE_LINK] = 32

section("Lecture des bonusIds d'un lien : le champ 13 en donne le nombre")

local bonusIDs = state.GetLinkBonusIDs(GEAR_LINK)
equals("le premier bonusId est lu", bonusIDs[8851], true)
equals("le dernier bonusId est lu", bonusIDs[9404], true)
equals("le nombre de modificateurs n'est pas un bonusId", bonusIDs[5], nil)
equals("un type de modificateur n'est pas un bonusId", bonusIDs[29], nil)
equals("une valeur de modificateur n'est pas un bonusId", bonusIDs[2164], nil)
equals("un lien sans bonusId n'en rend aucun", state.GetLinkBonusIDs(BASE_LINK), nil)
equals("une chaine qui n'est pas un lien n'en rend aucun", state.GetLinkBonusIDs("item:245778"), nil)

section("Verdict de conformite d'une annonce")

local rfVariant = state.NormalizeItemVariant({
    minItemLevel = 232,
    bonusIDs = { 8952 },
    statLabel = "Resourcefulness",
})
local mcVariant = state.NormalizeItemVariant({
    minItemLevel = 232,
    bonusIDs = { 8953 },
    statLabel = "Multicrafting",
})
local rankOnlyVariant = state.NormalizeItemVariant({ minItemLevel = 232 })

equals("l'outil RF rang maximal est conforme",
    state.DoesLinkMatchVariant(RF_TOOL_LINK, rfVariant), true)
equals("l'outil MC est ecarte d'une demande RF",
    state.DoesLinkMatchVariant(MC_TOOL_LINK, rfVariant), false)
equals("l'outil RF de rang inferieur est ecarte",
    state.DoesLinkMatchVariant(RF_LOW_RANK_LINK, rfVariant), false)
equals("l'objet de base est ecarte",
    state.DoesLinkMatchVariant(BASE_LINK, rfVariant), false)
equals("l'outil MC satisfait la demande MC",
    state.DoesLinkMatchVariant(MC_TOOL_LINK, mcVariant), true)
equals("une demande de rang seul accepte n'importe quelle statistique",
    state.DoesLinkMatchVariant(MC_TOOL_LINK, rankOnlyVariant), true)
equals("une demande de rang seul ecarte quand meme le rang inferieur",
    state.DoesLinkMatchVariant(RF_LOW_RANK_LINK, rankOnlyVariant), false)
equals("l'accessoire ilvl 447 tient le seuil",
    state.DoesLinkMatchVariant(GEAR_LINK, rankOnlyVariant), true)

section("Inconnu n'est pas non conforme")

local UNKNOWN_LINK = "|cff0070dd|Hitem:245778::::::::90:104::13:4:8952:12251:12253:12502:1:29:81:::::|h[y]|h|r"
equals("un niveau d'objet illisible ne tranche pas",
    state.DoesLinkMatchVariant(UNKNOWN_LINK, rfVariant), nil)
equals("un lien absent ne tranche pas",
    state.DoesLinkMatchVariant(nil, rfVariant), nil)
equals("sans variante, tout convient",
    state.DoesLinkMatchVariant(nil, nil), true)
-- Le bonusId se lit sans le client : une statistique fausse est ecartee meme
-- quand le niveau d'objet n'est pas encore charge.
equals("une mauvaise statistique est ecartee sans attendre le niveau d'objet",
    state.DoesLinkMatchVariant(
        "|cff0070dd|Hitem:245778::::::::90:104::13:4:8953:12251:12253:12502:1:29:81:::::|h[y]|h|r",
        rfVariant),
    false)

section("Identite d'une variante")

equals("deux demandes identiques partagent leur cle",
    state.GetItemVariantKey(rfVariant),
    state.GetItemVariantKey(state.NormalizeItemVariant({ minItemLevel = 232, bonusIDs = { 8952 } })))
equals("le libelle ne fait pas partie de l'identite",
    state.GetItemVariantKey(rfVariant),
    state.GetItemVariantKey(state.NormalizeItemVariant({
        minItemLevel = 232, bonusIDs = { 8952 }, statLabel = "autre chose" })))
equals("deux statistiques donnent deux cles",
    state.GetItemVariantKey(rfVariant) ~= state.GetItemVariantKey(mcVariant), true)
equals("deux rangs donnent deux cles",
    state.GetItemVariantKey(rfVariant) ~= state.GetItemVariantKey(
        state.NormalizeItemVariant({ minItemLevel = 226, bonusIDs = { 8952 } })), true)
equals("l'ordre des bonusIds ne change pas la cle",
    state.GetItemVariantKey(state.NormalizeItemVariant({ bonusIDs = { 8952, 8953 } })),
    state.GetItemVariantKey(state.NormalizeItemVariant({ bonusIDs = { 8953, 8952 } })))
equals("une demande sans contrainte n'est pas une variante",
    state.NormalizeItemVariant({}), nil)
equals("une valeur non exploitable n'est pas une variante",
    state.NormalizeItemVariant({ minItemLevel = 0, bonusIDs = { 0 } }), nil)
equals("une variante absente n'a pas de cle", state.GetItemVariantKey(nil), nil)

section("Libelle lisible d'une variante")

equals("statistique et rang", state.DescribeItemVariant(rfVariant), "Resourcefulness ilvl>=232")
equals("rang seul", state.DescribeItemVariant(rankOnlyVariant), "ilvl>=232")
equals("bonusId a defaut de libelle",
    state.DescribeItemVariant(state.NormalizeItemVariant({ bonusIDs = { 8952 } })),
    "bonus 8952")

print("")
print(("%d reussite(s), %d echec(s)"):format(passed, failed))
if failed > 0 then
    os.exit(1)
end
