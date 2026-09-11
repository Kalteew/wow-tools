-- Ordre de la file de craft.
--
-- Pourquoi ce fichier existe : le bouton Next et la liste affichee doivent
-- designer la meme entree, donc partager la meme cascade de tri. Elle vivait
-- en double dans YayaQueue.lua -- une fois sous forme de boucle « garder le
-- meilleur », une fois sous forme de comparateur pour table.sort -- et toute
-- retouche devait etre faite deux fois, a l'identique, sans rien pour le
-- verifier. Ici la cascade est ecrite une seule fois, sous forme d'un ordre
-- strict total, et c'est la meme fonction qui sert au bouton et a la liste.
--
-- Deux niveaux se distinguent :
--
-- * des invariants fixes, valables dans tous les modes, parce qu'un autre ordre
--   casse le bouton Next : la commande de patron claim passe en tete (sinon
--   Next reste sur « relache la commande »), puis le salvage / recyclage /
--   broyage ; et, au sein d'un meme bloc de metier, les fusions precedent les
--   crafts par profondeur croissante (un craft consommateur place devant son
--   producteur bloque Next sur « materiaux ») ;
-- * une suite choisie par l'utilisateur (`queueSortMode`) : metier ouvert,
--   fusions, outil de metier a equiper, profit, ordre d'ajout. Le mode
--   `standard` est, cran pour cran, la cascade historique de l'addon.
--
-- Ce module est du Lua pur, sans API du jeu : ce qui depend du jeu (commande
-- claim, metier ouvert, rang d'outil) est injecte par YayaQueue dans le
-- contexte de `Describe`. Il est teste hors du jeu par
-- `Tests/test_queueorder.lua`.

local _, ns = ...

local QueueOrder = {}
ns.QueueOrder = QueueOrder

QueueOrder.DEFAULT_MODE = "standard"

-- Ordre d'affichage des modes dans les options et dans `/yq sort`.
QueueOrder.MODES = { "standard", "profit", "profession_insertion", "insertion" }

QueueOrder.MODE_LABELS = {
    standard = "Standard : metier ouvert, outil a equiper, profit",
    profit = "Profit d'abord",
    profession_insertion = "Metier ouvert, puis ordre d'ajout",
    insertion = "Ordre d'ajout",
}

local MODE_SET = {}
for _, mode in ipairs(QueueOrder.MODES) do
    MODE_SET[mode] = true
end

function QueueOrder.IsValidMode(mode)
    return type(mode) == "string" and MODE_SET[mode] == true
end

--- Mode retenu pour une valeur lue dans la base : inconnu vaut standard.
function QueueOrder.NormalizeMode(mode)
    if QueueOrder.IsValidMode(mode) then
        return mode
    end
    return QueueOrder.DEFAULT_MODE
end

-- ---------------------------------------------------------------------------
-- Description d'une entree
-- ---------------------------------------------------------------------------

--- Descripteur de tri d'une entree de la file.
--
-- `ctx` porte ce qui depend du jeu :
--   claimedOrderID      orderID de la commande de patron claim, 0 si aucune
--   currentProfessionID metier ouvert, nil si aucun
--   gearRank            fonction(entry) -> rang d'outil a equiper (0 = rien)
--
-- Le descripteur fige tout ce que la comparaison lit : la cascade ne relit
-- jamais l'entree, donc une mutation de la file pendant un tri ne peut pas
-- rendre l'ordre incoherent.
function QueueOrder.Describe(entry, index, ctx)
    ctx = ctx or {}
    local claimedOrderID = tonumber(ctx.claimedOrderID) or 0
    local currentProfessionID = ctx.currentProfessionID
    local isMerge = entry.queueKind == "merge"
    local gearRank = 0
    if type(ctx.gearRank) == "function" then
        gearRank = tonumber(ctx.gearRank(entry)) or 0
    end
    local hasKnownProfit = entry.profitKnown == true and type(entry.profitValue) == "number"

    return {
        entry = entry,
        index = index,
        isClaimedOrder = claimedOrderID > 0
            and entry.queueKind == "patron"
            and (tonumber(entry.orderID) or 0) == claimedOrderID,
        -- Le milling est une recette salvage sans queueKind "recycle" : il
        -- beneficie de la meme priorite, sinon il reste derriere les crafts
        -- normaux.
        isSalvage = entry.queueKind == "recycle" or entry.isSalvageRecipe == true,
        matchesOpenProfession = currentProfessionID ~= nil
            and (tonumber(entry.professionID) or nil) == currentProfessionID,
        isMerge = isMerge,
        -- Une fusion sans profondeur passe apres toutes celles qui en ont une.
        mergeDepth = isMerge and (tonumber(entry.mergeDepth) or math.huge) or nil,
        gearRank = gearRank,
        hasKnownProfit = hasKnownProfit,
        profitValue = hasKnownProfit and entry.profitValue or nil,
    }
end

-- ---------------------------------------------------------------------------
-- Crans de la cascade
-- ---------------------------------------------------------------------------
-- Chaque cran rend true/false quand il tranche, nil quand les deux entrees
-- sont a egalite sur son critere.

local function CompareOpenProfession(left, right)
    if left.matchesOpenProfession ~= right.matchesOpenProfession then
        return left.matchesOpenProfession
    end
    return nil
end

-- Fusions avant les crafts, puis par profondeur croissante : un craft
-- consommateur place devant son producteur bloquerait Next sur « materiaux ».
local function CompareMerge(left, right)
    if left.isMerge ~= right.isMerge then
        return left.isMerge
    end
    if left.isMerge and left.mergeDepth ~= right.mergeDepth then
        return left.mergeDepth < right.mergeDepth
    end
    return nil
end

-- Rang d'outil croissant : 0 = rien a equiper, donc craftable tout de suite.
local function CompareGearRank(left, right)
    if left.gearRank ~= right.gearRank then
        return left.gearRank < right.gearRank
    end
    return nil
end

-- Profit decroissant, puis profit connu avant profit inconnu.
local function CompareProfit(left, right)
    if left.hasKnownProfit and right.hasKnownProfit and left.profitValue ~= right.profitValue then
        return left.profitValue > right.profitValue
    end
    if left.hasKnownProfit ~= right.hasKnownProfit then
        return left.hasKnownProfit
    end
    return nil
end

-- Suite de la cascade apres les deux invariants de tete. En `standard` et
-- `profession_insertion` les fusions sont classees a l'interieur du bloc
-- « metier ouvert » ; en `profit` et `insertion` elles precedent tout craft.
local MODE_STEPS = {
    standard = { CompareOpenProfession, CompareMerge, CompareGearRank, CompareProfit },
    profit = { CompareMerge, CompareProfit, CompareOpenProfession, CompareGearRank },
    profession_insertion = { CompareOpenProfession, CompareMerge },
    insertion = { CompareMerge },
}

--- Ordre strict total : true si `left` passe avant `right`.
--
-- La commande claim puis le salvage viennent d'abord, dans tous les modes ; le
-- mode choisit la suite ; l'index d'ajout departage toujours, donc deux
-- descripteurs d'index distincts ne sont jamais a egalite et table.sort ne
-- peut pas recevoir un comparateur incoherent.
function QueueOrder.Compare(left, right, mode)
    if left.isClaimedOrder ~= right.isClaimedOrder then
        return left.isClaimedOrder
    end
    if left.isSalvage ~= right.isSalvage then
        return left.isSalvage
    end

    local steps = MODE_STEPS[QueueOrder.NormalizeMode(mode)]
    for _, step in ipairs(steps) do
        local result = step(left, right)
        if result ~= nil then
            return result
        end
    end

    return left.index < right.index
end

--- Trie en place une liste de descripteurs selon le mode.
function QueueOrder.Sort(candidates, mode)
    mode = QueueOrder.NormalizeMode(mode)
    table.sort(candidates, function(left, right)
        return QueueOrder.Compare(left, right, mode)
    end)
    return candidates
end

--- Meilleur descripteur d'une liste, sans la trier : nil si elle est vide.
--
-- C'est ce que fait le bouton Next : un minimum lineaire suffit, et il rend
-- par construction le meme element que `Sort(...)[1]`.
function QueueOrder.PickBest(candidates, mode)
    mode = QueueOrder.NormalizeMode(mode)
    local best
    for _, candidate in ipairs(candidates) do
        if not best or QueueOrder.Compare(candidate, best, mode) then
            best = candidate
        end
    end
    return best
end
