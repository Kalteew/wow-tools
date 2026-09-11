-- Tests unitaires de l'ordre de la file de craft, executes hors du jeu avec
-- Lua 5.1.
--
-- QueueOrder.lua est du Lua pur : on charge le vrai fichier et on l'interroge
-- directement. Ce qui est verifie ici est ce qui compte pour l'utilisateur --
-- quelle entree le bouton Next designe, dans quel ordre la liste s'affiche, et
-- que les invariants qui protegent le bouton Next tiennent quel que soit le
-- mode choisi.
--
-- Usage : lua5.1 Tests/test_queueorder.lua   (depuis addons/YayaQueue)

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
-- Chargement du vrai module
-- ---------------------------------------------------------------------------

local ns = {}
assert(loadfile("QueueOrder.lua"), "QueueOrder.lua introuvable")("YayaQueue", ns)
local QueueOrder = assert(ns.QueueOrder, "ns.QueueOrder non exporte")

-- ---------------------------------------------------------------------------
-- Outils
-- ---------------------------------------------------------------------------

local OPEN_PROFESSION = 2906
local CLAIMED_ORDER = 777

-- Rang d'outil injecte : lu sur l'entree elle-meme pour le test.
local function GearRank(entry)
    return entry.testGearRank or 0
end

local CTX = {
    claimedOrderID = CLAIMED_ORDER,
    currentProfessionID = OPEN_PROFESSION,
    gearRank = GearRank,
}

--- Entree de file minimale : `name` sert a lire l'ordre obtenu.
local function Entry(name, fields)
    local entry = { recipeName = name, queueKind = "recipe", professionID = OPEN_PROFESSION }
    for key, value in pairs(fields or {}) do
        entry[key] = value
    end
    return entry
end

local function Describe(entries, ctx)
    local described = {}
    for index, entry in ipairs(entries) do
        described[index] = QueueOrder.Describe(entry, index, ctx or CTX)
    end
    return described
end

local function Names(candidates)
    local names = {}
    for index, candidate in ipairs(candidates) do
        names[index] = candidate.entry.recipeName
    end
    return table.concat(names, ",")
end

local function SortedNames(entries, mode, ctx)
    return Names(QueueOrder.Sort(Describe(entries, ctx), mode))
end

local function BestName(entries, mode, ctx)
    local best = QueueOrder.PickBest(Describe(entries, ctx), mode)
    return best and best.entry.recipeName or nil
end

-- ---------------------------------------------------------------------------
-- Modes
-- ---------------------------------------------------------------------------

section("Modes")

equals("quatre modes", #QueueOrder.MODES, 4)
equals("ordre des modes", table.concat(QueueOrder.MODES, ","),
    "standard,profit,profession_insertion,insertion")
equals("le mode par defaut est standard", QueueOrder.DEFAULT_MODE, "standard")
for _, mode in ipairs(QueueOrder.MODES) do
    equals("mode valide : " .. mode, QueueOrder.IsValidMode(mode), true)
    equals("libelle present : " .. mode, type(QueueOrder.MODE_LABELS[mode]), "string")
end
equals("mode inconnu invalide", QueueOrder.IsValidMode("random"), false)
equals("nil invalide", QueueOrder.IsValidMode(nil), false)
equals("un nombre est invalide", QueueOrder.IsValidMode(1), false)
equals("normalisation d'un mode connu", QueueOrder.NormalizeMode("profit"), "profit")
equals("normalisation d'un mode inconnu", QueueOrder.NormalizeMode("random"), "standard")
equals("normalisation de nil", QueueOrder.NormalizeMode(nil), "standard")

-- ---------------------------------------------------------------------------
-- Describe
-- ---------------------------------------------------------------------------

section("Describe")

local d = QueueOrder.Describe(Entry("patron", { queueKind = "patron", orderID = "777" }), 3, CTX)
equals("index conserve", d.index, 3)
equals("entree conservee", d.entry.recipeName, "patron")
equals("commande claim reconnue par orderID chaine", d.isClaimedOrder, true)
equals("un patron n'est pas salvage", d.isSalvage, false)
equals("un patron n'est pas une fusion", d.isMerge, false)
equals("mergeDepth nil hors fusion", d.mergeDepth, nil)

d = QueueOrder.Describe(Entry("autre patron", { queueKind = "patron", orderID = 778 }), 1, CTX)
equals("un autre orderID n'est pas la commande claim", d.isClaimedOrder, false)

d = QueueOrder.Describe(Entry("patron", { queueKind = "patron", orderID = 777 }), 1,
    { claimedOrderID = 0, currentProfessionID = OPEN_PROFESSION, gearRank = GearRank })
equals("sans commande claim, aucun patron n'est prioritaire", d.isClaimedOrder, false)

d = QueueOrder.Describe(Entry("recette", { queueKind = "recipe", orderID = 777 }), 1, CTX)
equals("le bon orderID sur une recette ne fait pas une commande claim", d.isClaimedOrder, false)

d = QueueOrder.Describe(Entry("recycle", { queueKind = "recycle" }), 1, CTX)
equals("recycle est salvage", d.isSalvage, true)
d = QueueOrder.Describe(Entry("milling", { isSalvageRecipe = true }), 1, CTX)
equals("le broyage (isSalvageRecipe) est salvage", d.isSalvage, true)

d = QueueOrder.Describe(Entry("ouvert", { professionID = "2906" }), 1, CTX)
equals("metier ouvert reconnu meme si professionID est une chaine", d.matchesOpenProfession, true)
d = QueueOrder.Describe(Entry("ferme", { professionID = 2913 }), 1, CTX)
equals("autre metier", d.matchesOpenProfession, false)
d = QueueOrder.Describe(Entry("ouvert"), 1,
    { claimedOrderID = 0, currentProfessionID = nil, gearRank = GearRank })
equals("aucun metier ouvert : personne ne correspond", d.matchesOpenProfession, false)

d = QueueOrder.Describe(Entry("fusion", { queueKind = "merge", mergeDepth = "2" }), 1, CTX)
equals("fusion reconnue", d.isMerge, true)
equals("profondeur lue comme nombre", d.mergeDepth, 2)
d = QueueOrder.Describe(Entry("fusion", { queueKind = "merge" }), 1, CTX)
equals("fusion sans profondeur : profondeur infinie", d.mergeDepth, math.huge)

d = QueueOrder.Describe(Entry("outil", { testGearRank = 2 }), 1, CTX)
equals("rang d'outil injecte par le contexte", d.gearRank, 2)
d = QueueOrder.Describe(Entry("outil", { testGearRank = 2 }), 1,
    { claimedOrderID = 0, currentProfessionID = nil })
equals("sans fonction de rang, rang 0", d.gearRank, 0)
d = QueueOrder.Describe(Entry("outil"), 1, nil)
equals("contexte absent tolere", d.gearRank, 0)

d = QueueOrder.Describe(Entry("profit", { profitKnown = true, profitValue = 1500 }), 1, CTX)
equals("profit connu", d.hasKnownProfit, true)
equals("valeur de profit", d.profitValue, 1500)
d = QueueOrder.Describe(Entry("profit", { profitKnown = true, profitValue = "1500" }), 1, CTX)
equals("un profit non numerique vaut inconnu", d.hasKnownProfit, false)
equals("aucune valeur pour un profit inconnu", d.profitValue, nil)
d = QueueOrder.Describe(Entry("profit", { profitKnown = false, profitValue = 1500 }), 1, CTX)
equals("profitKnown false vaut inconnu malgre la valeur", d.hasKnownProfit, false)

-- ---------------------------------------------------------------------------
-- Cascade standard, cran par cran
-- ---------------------------------------------------------------------------
-- Dans chaque cas, l'entree qui doit gagner est placee en second : si le cran
-- ne tranchait pas, l'index la laisserait derriere.

section("Cascade standard, cran par cran")

equals("la commande claim passe avant le salvage",
    SortedNames({
        Entry("recycle", { queueKind = "recycle" }),
        Entry("claim", { queueKind = "patron", orderID = CLAIMED_ORDER, professionID = 2913 }),
    }, "standard"), "claim,recycle")

equals("le salvage passe avant une fusion",
    SortedNames({
        Entry("fusion", { queueKind = "merge", mergeDepth = 0 }),
        Entry("recycle", { queueKind = "recycle", professionID = 2913 }),
    }, "standard"), "recycle,fusion")

-- Comportement historique : le metier ouvert passe avant une fusion d'un autre
-- metier ; la fusion ne prime que dans son propre bloc de metier.
equals("une recette du metier ouvert passe avant une fusion d'un autre metier",
    SortedNames({
        Entry("fusion-autre", { queueKind = "merge", mergeDepth = 0, professionID = 2913 }),
        Entry("ouvert", { professionID = OPEN_PROFESSION }),
    }, "standard"), "ouvert,fusion-autre")

equals("une fusion du metier ouvert passe avant une recette du metier ouvert",
    SortedNames({
        Entry("ouvert", { professionID = OPEN_PROFESSION }),
        Entry("fusion", { queueKind = "merge", mergeDepth = 0, professionID = OPEN_PROFESSION }),
    }, "standard"), "fusion,ouvert")

equals("une fusion passe avant l'outil a equiper et le profit",
    SortedNames({
        Entry("riche", { testGearRank = 0, profitKnown = true, profitValue = 9999 }),
        Entry("fusion", { queueKind = "merge", mergeDepth = 0, testGearRank = 2 }),
    }, "standard"), "fusion,riche")

equals("les fusions vont par profondeur croissante",
    SortedNames({
        Entry("profonde", { queueKind = "merge", mergeDepth = 2 }),
        Entry("sans", { queueKind = "merge" }),
        Entry("racine", { queueKind = "merge", mergeDepth = 0 }),
        Entry("moyenne", { queueKind = "merge", mergeDepth = 1 }),
    }, "standard"), "racine,moyenne,profonde,sans")

equals("le metier ouvert passe avant l'outil deja equipe d'un autre metier",
    SortedNames({
        Entry("ferme", { professionID = 2913, testGearRank = 0 }),
        Entry("ouvert", { professionID = OPEN_PROFESSION, testGearRank = 2 }),
    }, "standard"), "ouvert,ferme")

equals("le metier ouvert passe avant un profit superieur",
    SortedNames({
        Entry("ferme", { professionID = 2913, profitKnown = true, profitValue = 9999 }),
        Entry("ouvert", { professionID = OPEN_PROFESSION, profitKnown = true, profitValue = 1 }),
    }, "standard"), "ouvert,ferme")

equals("rang d'outil croissant : rien a equiper d'abord",
    SortedNames({
        Entry("rf", { testGearRank = 2 }),
        Entry("mc", { testGearRank = 1 }),
        Entry("pret", { testGearRank = 0 }),
    }, "standard"), "pret,mc,rf")

equals("le rang d'outil passe avant le profit",
    SortedNames({
        Entry("riche", { testGearRank = 1, profitKnown = true, profitValue = 9999 }),
        Entry("pret", { testGearRank = 0, profitKnown = true, profitValue = 1 }),
    }, "standard"), "pret,riche")

equals("profit decroissant",
    SortedNames({
        Entry("petit", { profitKnown = true, profitValue = 10 }),
        Entry("gros", { profitKnown = true, profitValue = 100 }),
        Entry("negatif", { profitKnown = true, profitValue = -5 }),
    }, "standard"), "gros,petit,negatif")

equals("profit connu avant profit inconnu, meme negatif",
    SortedNames({
        Entry("inconnu"),
        Entry("perte", { profitKnown = true, profitValue = -50 }),
    }, "standard"), "perte,inconnu")

equals("a egalite complete, l'ordre d'ajout",
    SortedNames({
        Entry("a", { profitKnown = true, profitValue = 10 }),
        Entry("b", { profitKnown = true, profitValue = 10 }),
        Entry("c", { profitKnown = true, profitValue = 10 }),
    }, "standard"), "a,b,c")

-- ---------------------------------------------------------------------------
-- Suites propres a chaque mode
-- ---------------------------------------------------------------------------

section("Mode profit")

local PROFIT_SET = {
    Entry("ferme-riche", { professionID = 2913, testGearRank = 2, profitKnown = true, profitValue = 500 }),
    Entry("ouvert-pauvre", { professionID = OPEN_PROFESSION, testGearRank = 0, profitKnown = true, profitValue = 5 }),
    Entry("ouvert-inconnu", { professionID = OPEN_PROFESSION, testGearRank = 0 }),
    Entry("ferme-inconnu", { professionID = 2913, testGearRank = 0 }),
}
equals("le profit passe avant le metier ouvert et l'outil",
    SortedNames(PROFIT_SET, "profit"), "ferme-riche,ouvert-pauvre,ouvert-inconnu,ferme-inconnu")
equals("le meme jeu en standard garde le metier ouvert devant",
    SortedNames(PROFIT_SET, "standard"), "ouvert-pauvre,ouvert-inconnu,ferme-inconnu,ferme-riche")
equals("a profit egal, metier ouvert puis outil",
    SortedNames({
        Entry("ferme", { professionID = 2913, profitKnown = true, profitValue = 10 }),
        Entry("ouvert-rf", { professionID = OPEN_PROFESSION, testGearRank = 2, profitKnown = true, profitValue = 10 }),
        Entry("ouvert-pret", { professionID = OPEN_PROFESSION, testGearRank = 0, profitKnown = true, profitValue = 10 }),
    }, "profit"), "ouvert-pret,ouvert-rf,ferme")
equals("une fusion passe devant un craft plus rentable, meme d'un autre metier",
    SortedNames({
        Entry("ouvert-riche", { professionID = OPEN_PROFESSION, profitKnown = true, profitValue = 9999 }),
        Entry("fusion-autre", { queueKind = "merge", mergeDepth = 1, professionID = 2913 }),
    }, "profit"), "fusion-autre,ouvert-riche")

section("Mode profession_insertion")

equals("metier ouvert d'abord, puis l'ordre d'ajout sans regarder profit ni outil",
    SortedNames({
        Entry("ferme-1", { professionID = 2913, profitKnown = true, profitValue = 900 }),
        Entry("ouvert-rf", { professionID = OPEN_PROFESSION, testGearRank = 2 }),
        Entry("ferme-2", { professionID = 2913 }),
        Entry("ouvert-riche", { professionID = OPEN_PROFESSION, testGearRank = 0, profitKnown = true, profitValue = 900 }),
    }, "profession_insertion"), "ouvert-rf,ouvert-riche,ferme-1,ferme-2")
equals("les fusions restent dans leur bloc de metier, devant ses crafts",
    SortedNames({
        Entry("ferme", { professionID = 2913 }),
        Entry("fusion-autre", { queueKind = "merge", mergeDepth = 0, professionID = 2913 }),
        Entry("ouvert", { professionID = OPEN_PROFESSION }),
        Entry("fusion-ouverte", { queueKind = "merge", mergeDepth = 1, professionID = OPEN_PROFESSION }),
    }, "profession_insertion"), "fusion-ouverte,ouvert,fusion-autre,ferme")

section("Mode insertion")

equals("l'ordre d'ajout, sans regarder metier, outil ni profit",
    SortedNames({
        Entry("ferme-riche", { professionID = 2913, profitKnown = true, profitValue = 900 }),
        Entry("ouvert-rf", { professionID = OPEN_PROFESSION, testGearRank = 2 }),
        Entry("ouvert-pret", { professionID = OPEN_PROFESSION, testGearRank = 0 }),
    }, "insertion"), "ferme-riche,ouvert-rf,ouvert-pret")
equals("les fusions precedent tout craft, par profondeur, quel que soit le metier",
    SortedNames({
        Entry("ouvert", { professionID = OPEN_PROFESSION }),
        Entry("fusion-2", { queueKind = "merge", mergeDepth = 2, professionID = OPEN_PROFESSION }),
        Entry("ferme", { professionID = 2913 }),
        Entry("fusion-0", { queueKind = "merge", mergeDepth = 0, professionID = 2913 }),
    }, "insertion"), "fusion-0,fusion-2,ouvert,ferme")

section("Invariants dans tous les modes")

local INVARIANT_SET = {
    Entry("ferme-riche", { professionID = 2913, profitKnown = true, profitValue = 9000 }),
    Entry("fusion-1", { queueKind = "merge", mergeDepth = 1, professionID = OPEN_PROFESSION }),
    Entry("ouvert", { professionID = OPEN_PROFESSION }),
    Entry("fusion-0", { queueKind = "merge", mergeDepth = 0, professionID = 2913 }),
    Entry("broyage", { isSalvageRecipe = true, professionID = 2913 }),
    Entry("claim", { queueKind = "patron", orderID = CLAIMED_ORDER, professionID = 2913 }),
}
for _, mode in ipairs(QueueOrder.MODES) do
    local names = SortedNames(INVARIANT_SET, mode)
    equals("claim puis salvage en tete : " .. mode,
        names:sub(1, #"claim,broyage"), "claim,broyage")
end
-- Standard et profession_insertion classent les fusions dans leur bloc de
-- metier : la fusion du metier ouvert ouvre le bloc ouvert, celle de l'autre
-- metier ouvre le bloc ferme.
equals("standard : bloc metier ouvert (fusion puis craft), puis bloc ferme",
    SortedNames(INVARIANT_SET, "standard"), "claim,broyage,fusion-1,ouvert,fusion-0,ferme-riche")
equals("profession_insertion : memes blocs que standard",
    SortedNames(INVARIANT_SET, "profession_insertion"), "claim,broyage,fusion-1,ouvert,fusion-0,ferme-riche")
-- Profit et insertion placent toutes les fusions devant tout craft.
equals("profit : toutes les fusions par profondeur, puis le profit",
    SortedNames(INVARIANT_SET, "profit"), "claim,broyage,fusion-0,fusion-1,ferme-riche,ouvert")
equals("insertion : toutes les fusions par profondeur, puis l'ordre d'ajout",
    SortedNames(INVARIANT_SET, "insertion"), "claim,broyage,fusion-0,fusion-1,ferme-riche,ouvert")

section("Mode inconnu")

equals("un mode inconnu trie comme standard",
    SortedNames(PROFIT_SET, "random"), SortedNames(PROFIT_SET, "standard"))
equals("nil trie comme standard",
    SortedNames(PROFIT_SET, nil), SortedNames(PROFIT_SET, "standard"))
equals("PickBest en mode inconnu suit standard",
    BestName(PROFIT_SET, "random"), BestName(PROFIT_SET, "standard"))

-- ---------------------------------------------------------------------------
-- PickBest et Sort designent la meme entree ; ordre strict total
-- ---------------------------------------------------------------------------

section("PickBest, Sort et ordre strict total (fuzz)")

math.randomseed(20260911)

local KINDS = { "recipe", "recipe", "recipe", "merge", "recycle", "patron", "direct_item" }
local PROFESSIONS = { OPEN_PROFESSION, 2913, 2917 }

local function RandomEntry(index)
    local kind = KINDS[math.random(#KINDS)]
    local entry = Entry("e" .. index, {
        queueKind = kind,
        professionID = PROFESSIONS[math.random(#PROFESSIONS)],
        testGearRank = math.random(0, 2),
    })
    if kind == "merge" then
        -- Profondeurs volontairement repetees, et parfois absentes.
        local roll = math.random(4)
        entry.mergeDepth = roll == 4 and nil or (roll - 1)
    elseif kind == "patron" then
        entry.orderID = math.random(2) == 1 and CLAIMED_ORDER or (CLAIMED_ORDER + math.random(5))
    elseif kind == "recipe" and math.random(5) == 1 then
        entry.isSalvageRecipe = true
    end
    -- Profits volontairement egaux (multiples de 100) ou inconnus.
    local roll = math.random(3)
    if roll == 1 then
        entry.profitKnown = true
        entry.profitValue = math.random(-2, 5) * 100
    elseif roll == 2 then
        entry.profitKnown = true
        entry.profitValue = nil
    end
    return entry
end

local function RandomQueue(count)
    local queue = {}
    for index = 1, count do
        queue[index] = RandomEntry(index)
    end
    return queue
end

-- Modes qui classent les fusions a l'interieur du bloc « metier ouvert » :
-- l'invariant « fusion avant craft » ne vaut alors qu'entre entrees de meme
-- statut de metier ouvert, et le bloc ouvert precede le bloc ferme.
local MERGE_WITHIN_PROFESSION_BLOCK = { standard = true, profession_insertion = true }

local function CheckInvariants(sorted, mode, label)
    local blockAware = MERGE_WITHIN_PROFESSION_BLOCK[mode] == true
    local seenNonClaimed, seenNonSalvage = false, false
    local blocks = {}
    local blockOrder = {}
    local ok = true
    for _, candidate in ipairs(sorted) do
        if candidate.isClaimedOrder and seenNonClaimed then ok = false end
        if not candidate.isClaimedOrder then seenNonClaimed = true end
        if not candidate.isClaimedOrder then
            if candidate.isSalvage and seenNonSalvage then ok = false end
            if not candidate.isSalvage then seenNonSalvage = true end
            if not candidate.isSalvage then
                local key = blockAware and tostring(candidate.matchesOpenProfession) or "all"
                if not blocks[key] then
                    blocks[key] = { seenNonMerge = false, lastDepth = -math.huge }
                    blockOrder[#blockOrder + 1] = key
                elseif key ~= blockOrder[#blockOrder] then
                    -- Retour dans un bloc deja quitte : les blocs se melangent.
                    ok = false
                end
                local block = blocks[key]
                if candidate.isMerge then
                    if block.seenNonMerge then ok = false end
                    if candidate.mergeDepth < block.lastDepth then ok = false end
                    block.lastDepth = candidate.mergeDepth
                else
                    block.seenNonMerge = true
                end
            end
        end
    end
    if blockAware and #blockOrder == 2 then
        -- Le bloc du metier ouvert vient en premier et les deux blocs ne se
        -- melangent pas (chaque cle n'est ouverte qu'une fois).
        equals(label .. " (bloc metier ouvert en premier)", blockOrder[1], "true")
    end
    equals(label, ok, true)
end

for _, mode in ipairs(QueueOrder.MODES) do
    local queue = RandomQueue(60)
    local described = Describe(queue)

    -- table.sort de Lua 5.1 leve « invalid order function » sur un comparateur
    -- incoherent ; il ne doit rien lever ici, quelles que soient les egalites.
    local ok, err = pcall(function()
        for _ = 1, 5 do
            QueueOrder.Sort(Describe(queue), mode)
        end
    end)
    equals("table.sort n'echoue jamais en mode " .. mode, ok, true)
    if not ok then print("        " .. tostring(err)) end

    local sorted = QueueOrder.Sort(Describe(queue), mode)
    equals("60 entrees conservees en mode " .. mode, #sorted, 60)
    local best = QueueOrder.PickBest(described, mode)
    equals("PickBest == Sort[1] en mode " .. mode, best.entry, sorted[1].entry)

    -- Ordre strict total : pour toute paire distincte, exactement une des deux
    -- comparaisons est vraie ; jamais les deux, jamais aucune.
    local strict = true
    for i = 1, #described do
        if QueueOrder.Compare(described[i], described[i], mode) then strict = false end
        for j = i + 1, #described do
            local ab = QueueOrder.Compare(described[i], described[j], mode)
            local ba = QueueOrder.Compare(described[j], described[i], mode)
            if ab == ba then strict = false end
        end
    end
    equals("ordre strict total sur 60 entrees en mode " .. mode, strict, true)

    -- Le tri est stable par construction (departage par index) : deux passes
    -- rendent la meme sequence.
    equals("tri deterministe en mode " .. mode, Names(sorted), Names(QueueOrder.Sort(Describe(queue), mode)))

    CheckInvariants(sorted, mode, "invariants respectes en mode " .. mode)
end

equals("PickBest d'une liste vide vaut nil", QueueOrder.PickBest({}, "standard"), nil)
equals("PickBest d'un seul element le rend",
    QueueOrder.PickBest(Describe({ Entry("seul") }), "insertion").entry.recipeName, "seul")

-- ---------------------------------------------------------------------------
-- Garde-fous de source : la cascade ne vit plus qu'ici
-- ---------------------------------------------------------------------------

section("Garde-fous de source")

local handle = assert(io.open("YayaQueue.lua", "rb"), "YayaQueue.lua introuvable")
local source = handle:read("*a"):gsub("\r\n", "\n")
handle:close()

equals("le bouton Next compare par QueueOrder.Compare",
    source:find("QueueOrder.Compare(candidate, best, mode)", 1, true) ~= nil, true)
equals("les candidats sont decrits par QueueOrder.Describe",
    source:find("QueueOrder.Describe(entry, index, context)", 1, true) ~= nil, true)
equals("la liste est triee par QueueOrder.Sort",
    source:find("QueueOrder.Sort(candidates, mode)", 1, true) ~= nil, true)
equals("l'ancienne boucle « garder le meilleur » a disparu",
    source:find("shouldReplace = entryIsClaimedOrder", 1, true) == nil, true)
equals("l'ancien comparateur duplique a disparu",
    source:find("Meme cascade que GetNextQueueEntry", 1, true) == nil, true)
equals("le mode de tri est lu dans la base",
    source:find("QueueOrder.NormalizeMode(db.queueSortMode)", 1, true) ~= nil, true)
equals("le module est expose via state.queueOrder",
    source:find("state.queueOrder = state.addonTable and state.addonTable.QueueOrder", 1, true) ~= nil, true)
equals("/yq sort ecrit le mode via SetQueueSortMode",
    source:find("YQQuality.SetQueueSortMode(sortArgument)", 1, true) ~= nil, true)

handle = assert(io.open("YayaQueue.toc", "rb"), "YayaQueue.toc introuvable")
local toc = handle:read("*a"):gsub("\r\n", "\n")
handle:close()

local queueOrderAt = toc:find("\nQueueOrder.lua\n", 1, true)
local mainAt = toc:find("\nYayaQueue.lua\n", 1, true)
equals("le TOC charge QueueOrder.lua", queueOrderAt ~= nil, true)
equals("QueueOrder.lua est charge avant YayaQueue.lua",
    queueOrderAt ~= nil and mainAt ~= nil and queueOrderAt < mainAt, true)

print("")
print(("%d reussis, %d echoues"):format(passed, failed))
if failed > 0 then
    os.exit(1)
end
