-- Tests unitaires des variantes d'achat, executes hors du jeu avec Lua 5.1.
--
-- Ce qui est verifie ici est la seule chose qui empeche la file d'acheter un
-- outil rang 1 a statistique quelconque : la lecture de la statistique au
-- tooltip du lien d'une annonce, le verdict de conformite, et l'identite d'une
-- variante. Ces fonctions ne touchent aucune frame : elles sont extraites de la
-- source de l'addon et rejouees telles quelles, sans doublure de CreateFrame.
--
-- Le tooltip est la seule source qui nomme la statistique d'un outil craft sans
-- Missive. Le bonusId `8952` / `8953` n'existe que sur un exemplaire craft AVEC
-- Missive (le lien porte alors le modificateur 48 avec l'itemID de la Missive) :
-- il ne sert donc que de repli, et les liens reels ci-dessous portent les deux
-- cas.
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

local statsTable = source:match("(state%.professionStats = %b{})")
assert(statsTable, "state.professionStats introuvable dans la source")
chunks[#chunks + 1] = statsTable

for _, name in ipairs({
    "NormalizeText",
    "ReadTextStatKey",
    "ReadLinkStatKey",
}) do
    local body = source:match("(state%.professionStats%." .. name .. " = function%(.-\nend)\n")
    assert(body, "state.professionStats." .. name .. " introuvable")
    chunks[#chunks + 1] = body
end

for _, name in ipairs({
    "NormalizeItemVariant",
    "GetItemVariantKey",
    "DescribeItemVariant",
    "GetLinkBonusIDs",
    "MatchesVariantStat",
    "DoesLinkMatchVariant",
}) do
    local body = source:match("(state%." .. name .. " = function%(.-\nend)\n")
    assert(body, "state." .. name .. " introuvable dans la source")
    chunks[#chunks + 1] = body
end

-- Les fonctions extraites resolvent `state`, `SafeCall` et l'API du client
-- comme des globales : la doublure doit rendre autant de valeurs que la vraie
-- API, sinon le test masque exactement la classe de bug qu'il surveille.
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

-- Client francais : c'est la locale ou les faux amis se paient. Resourcefulness
-- s'y affiche `Ingéniosité` et Ingenuity `Inventivité`.
ITEM_MOD_PERCEPTION_SHORT = "Perception"
ITEM_MOD_RESOURCEFULNESS_SHORT = "Ingéniosité"
ITEM_MOD_FINESSE_SHORT = "Finesse"
ITEM_MOD_MULTICRAFT_SHORT = "Fabrication multiple"
ITEM_MOD_INGENUITY_SHORT = "Inventivité"
ITEM_MOD_DEFTNESS_SHORT = "Adresse"
ITEM_MOD_CRAFTING_SPEED_SHORT = "Vitesse d’artisanat"

local ITEM_LEVEL_BY_LINK = {}
local TOOLTIP_STAT_BY_LINK = {}

function GetDetailedItemLevelInfo(link)
    local itemLevel = ITEM_LEVEL_BY_LINK[link]
    if not itemLevel then
        return nil, false, nil
    end
    return itemLevel, false, itemLevel
end

C_TooltipInfo = {
    GetHyperlink = function(link)
        local stat = TOOLTIP_STAT_BY_LINK[link]
        if stat == nil then
            -- Donnees d'objet pas encore chargees : le client ne rend rien.
            return nil
        end
        local lines = { { leftText = "Sin'dorei Alchemist's Mixing Rod" } }
        if stat ~= false then
            lines[#lines + 1] = { leftText = "+303 " .. stat }
        end
        return { lines = lines }
    end,
}

assert(loadstring(table.concat(chunks, "\n"), "variants"))()

-- ---------------------------------------------------------------------------
-- Liens reels, releves dans les SavedVariables du client
-- ---------------------------------------------------------------------------

-- Trois bonusIds (8851, 8852, 9404) puis cinq modificateurs. Le champ 13 porte
-- le nombre de bonusIds : sans ce comptage, le « 5 » des modificateurs et les
-- paires qui suivent seraient pris pour des bonusIds.
local GEAR_LINK = "|cffa335ee|Hitem:200641::::::::80:66::13:3:8851:8852:9404:5:28:2164:29:32:30:49:38:7:40:783:::::|h[x]|h|r"
-- Outil craft AVEC Missive : quatre bonusIds dont 8952, et le modificateur 48
-- qui porte l'itemID de la Missive utilisee.
local RF_MISSIVE_LINK = "|cff0070dd|Hitem:244176:7977:::::::90:104::13:4:12253:12251:12502:8952:5:28:3615:29:82:38:8:40:3917:48:245816:::::|h[x]|h|r"
-- Meme outil, meme rang, craft SANS Missive : trois bonusIds, aucun 89xx. Sa
-- statistique n'existe qu'au tooltip. C'est le cas majoritaire a l'hotel des
-- ventes, et celui que le filtre par bonusId ne voyait pas.
local RF_NO_MISSIVE_LINK = "|cff0070dd|Hitem:244176:7977:::::::90:73::13:3:12253:12251:12502:4:28:3615:29:76:38:8:40:3917:::::|h[x]|h|r"
local MC_NO_MISSIVE_LINK = "|cff0070dd|Hitem:244176:7977:::::::90:74::13:3:12253:12251:12502:4:28:3615:29:76:38:8:40:3917:::::|h[y]|h|r"
-- Rang inferieur (bonusId 12499 au lieu de 12502), statistique voulue.
local RF_LOW_RANK_LINK = "|cff0070dd|Hitem:244176:7977:::::::82:73::13:3:12253:12251:12499:4:28:3615:29:76:38:5:40:3917:::::|h[z]|h|r"
-- L'objet de base, celui que l'infobulle d'un simple itemID montre.
local BASE_LINK = "|cff0070dd|Hitem:244176::::::::90:104|h[base]|h|r"
-- Outil dont les donnees ne sont pas encore chargees.
local UNLOADED_LINK = "|cff0070dd|Hitem:244176:7977:::::::90:75::13:3:12253:12251:12502:4:28:3615:29:76:38:8:40:3917:::::|h[?]|h|r"

ITEM_LEVEL_BY_LINK[GEAR_LINK] = 447
ITEM_LEVEL_BY_LINK[RF_MISSIVE_LINK] = 232
ITEM_LEVEL_BY_LINK[RF_NO_MISSIVE_LINK] = 232
ITEM_LEVEL_BY_LINK[MC_NO_MISSIVE_LINK] = 232
ITEM_LEVEL_BY_LINK[RF_LOW_RANK_LINK] = 206
ITEM_LEVEL_BY_LINK[BASE_LINK] = 32
ITEM_LEVEL_BY_LINK[UNLOADED_LINK] = 232

TOOLTIP_STAT_BY_LINK[GEAR_LINK] = false
TOOLTIP_STAT_BY_LINK[RF_MISSIVE_LINK] = "Ingéniosité"
TOOLTIP_STAT_BY_LINK[RF_NO_MISSIVE_LINK] = "Ingéniosité"
TOOLTIP_STAT_BY_LINK[MC_NO_MISSIVE_LINK] = "Fabrication multiple"
TOOLTIP_STAT_BY_LINK[RF_LOW_RANK_LINK] = "Ingéniosité"
TOOLTIP_STAT_BY_LINK[BASE_LINK] = false
TOOLTIP_STAT_BY_LINK[UNLOADED_LINK] = nil

section("Lecture de la statistique dans la langue du client")

equals("Ingeniosite est Resourcefulness, pas Ingenuity",
    state.professionStats.ReadTextStatKey("+303 ingéniosité"), "resourcefulness")
equals("Inventivite est Ingenuity",
    state.professionStats.ReadTextStatKey("+303 inventivité"), "ingenuity")
equals("Fabrication multiple est Multicrafting",
    state.professionStats.ReadTextStatKey("+303 fabrication multiple"), "multicrafting")
equals("le libelle anglais reste reconnu",
    state.professionStats.ReadTextStatKey("+303 resourcefulness"), "resourcefulness")
equals("une ligne sans statistique ne nomme rien",
    state.professionStats.ReadTextStatKey("niveau d'objet 232"), nil)
equals("la statistique se lit au tooltip d'un lien",
    state.professionStats.ReadLinkStatKey(RF_NO_MISSIVE_LINK), "resourcefulness")
equals("un tooltip absent est en attente, pas vide",
    select(2, state.professionStats.ReadLinkStatKey(UNLOADED_LINK)), true)
equals("un tooltip lu sans statistique n'est pas en attente",
    select(2, state.professionStats.ReadLinkStatKey(BASE_LINK)), false)

section("Lecture des bonusIds d'un lien : le champ 13 en donne le nombre")

local bonusIDs = state.GetLinkBonusIDs(GEAR_LINK)
equals("le premier bonusId est lu", bonusIDs[8851], true)
equals("le dernier bonusId est lu", bonusIDs[9404], true)
equals("le nombre de modificateurs n'est pas un bonusId", bonusIDs[5], nil)
equals("un type de modificateur n'est pas un bonusId", bonusIDs[29], nil)
equals("une valeur de modificateur n'est pas un bonusId", bonusIDs[2164], nil)
equals("le bonusId de statistique est lu quand il existe",
    state.GetLinkBonusIDs(RF_MISSIVE_LINK)[8952], true)
equals("un outil sans Missive n'en porte aucun",
    state.GetLinkBonusIDs(RF_NO_MISSIVE_LINK)[8952], nil)
equals("un lien sans bonusId n'en rend aucun", state.GetLinkBonusIDs(BASE_LINK), nil)

section("Verdict de conformite d'une annonce")

local rfVariant = state.NormalizeItemVariant({ minItemLevel = 232, statKey = "resourcefulness" })
local mcVariant = state.NormalizeItemVariant({ minItemLevel = 232, statKey = "multicrafting" })
local rankOnlyVariant = state.NormalizeItemVariant({ minItemLevel = 232 })

equals("l'outil RF sans Missive est conforme : c'est le cas qui echouait",
    state.DoesLinkMatchVariant(RF_NO_MISSIVE_LINK, rfVariant), true)
equals("l'outil RF avec Missive est conforme aussi",
    state.DoesLinkMatchVariant(RF_MISSIVE_LINK, rfVariant), true)
equals("l'outil MC est ecarte d'une demande RF",
    state.DoesLinkMatchVariant(MC_NO_MISSIVE_LINK, rfVariant), false)
equals("l'outil RF de rang inferieur est ecarte",
    state.DoesLinkMatchVariant(RF_LOW_RANK_LINK, rfVariant), false)
equals("l'objet de base est ecarte",
    state.DoesLinkMatchVariant(BASE_LINK, rfVariant), false)
equals("l'outil MC satisfait la demande MC",
    state.DoesLinkMatchVariant(MC_NO_MISSIVE_LINK, mcVariant), true)
equals("une demande de rang seul accepte n'importe quelle statistique",
    state.DoesLinkMatchVariant(MC_NO_MISSIVE_LINK, rankOnlyVariant), true)
equals("une demande de rang seul ecarte quand meme le rang inferieur",
    state.DoesLinkMatchVariant(RF_LOW_RANK_LINK, rankOnlyVariant), false)
equals("l'accessoire ilvl 447 tient le seuil",
    state.DoesLinkMatchVariant(GEAR_LINK, rankOnlyVariant), true)

section("Inconnu n'est pas non conforme")

equals("un tooltip pas encore charge ne tranche pas",
    state.DoesLinkMatchVariant(UNLOADED_LINK, rfVariant), nil)
equals("un lien absent ne tranche pas",
    state.DoesLinkMatchVariant(nil, rfVariant), nil)
equals("sans variante, tout convient",
    state.DoesLinkMatchVariant(nil, nil), true)
-- Repli par bonusId : tooltip muet, mais la Missive nomme deja la statistique.
TOOLTIP_STAT_BY_LINK[RF_MISSIVE_LINK] = nil
equals("le bonusId de Missive tranche quand le tooltip se tait",
    state.DoesLinkMatchVariant(RF_MISSIVE_LINK, rfVariant), true)
equals("et il ecarte la mauvaise statistique",
    state.DoesLinkMatchVariant(RF_MISSIVE_LINK, mcVariant), false)
TOOLTIP_STAT_BY_LINK[RF_MISSIVE_LINK] = "Ingéniosité"
-- Une statistique qu'aucune annonce ne portera : rien ne doit etre achete.
local unknownVariant = state.NormalizeItemVariant({ minItemLevel = 232, statKey = "inexistante" })
equals("une statistique inconnue n'elargit pas la demande",
    state.DoesLinkMatchVariant(MC_NO_MISSIVE_LINK, unknownVariant), false)

section("Identite d'une variante")

equals("deux demandes identiques partagent leur cle",
    state.GetItemVariantKey(rfVariant),
    state.GetItemVariantKey(state.NormalizeItemVariant({
        minItemLevel = 232, statKey = "resourcefulness" })))
equals("le libelle ne fait pas partie de l'identite",
    state.GetItemVariantKey(rfVariant),
    state.GetItemVariantKey(state.NormalizeItemVariant({
        minItemLevel = 232, statKey = "resourcefulness", statLabel = "autre chose" })))
equals("deux statistiques donnent deux cles",
    state.GetItemVariantKey(rfVariant) ~= state.GetItemVariantKey(mcVariant), true)
equals("deux rangs donnent deux cles",
    state.GetItemVariantKey(rfVariant) ~= state.GetItemVariantKey(
        state.NormalizeItemVariant({ minItemLevel = 226, statKey = "resourcefulness" })), true)
-- Une demande persistee avant que la statistique ne soit nommee ne portait que
-- le bonusId : elle doit retrouver la meme identite, sinon elle reapparait en
-- double dans la file.
equals("une demande ecrite par bonusId garde son identite",
    state.GetItemVariantKey(state.NormalizeItemVariant({
        minItemLevel = 232, bonusIDs = { 8952 } })),
    state.GetItemVariantKey(rfVariant))
equals("idem pour le Multicraft",
    state.GetItemVariantKey(state.NormalizeItemVariant({
        minItemLevel = 232, bonusIDs = { 8953 } })),
    state.GetItemVariantKey(mcVariant))
equals("une demande sans contrainte n'est pas une variante",
    state.NormalizeItemVariant({}), nil)
equals("une variante absente n'a pas de cle", state.GetItemVariantKey(nil), nil)

section("Libelle lisible d'une variante")

equals("statistique et rang", state.DescribeItemVariant(rfVariant), "Resourcefulness ilvl>=232")
equals("rang seul", state.DescribeItemVariant(rankOnlyVariant), "ilvl>=232")
equals("une statistique inconnue s'affiche telle quelle",
    state.DescribeItemVariant(unknownVariant), "inexistante ilvl>=232")

print("")
print(("%d reussite(s), %d echec(s)"):format(passed, failed))
if failed > 0 then
    os.exit(1)
end
