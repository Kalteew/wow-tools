-- Lots de crafts avec finition liee : consommation exacte et sortie du blocage.
--
-- Un dump de concentration met en file plusieurs lots de la MEME recette, qui ne
-- different que par leur finition (Matrix, Identifier, aucune). Deux defauts
-- laissaient la file bloquee sur « Acquerir <finition> » :
--
--  1. ConsumeCraftEntry decrementait le premier lot de la recette, pas celui qui
--     venait d'etre craft. Quand le tri execute un autre lot que le premier de la
--     file (un lot dont la finition manque passe en dernier), la finition du lot
--     reellement craft partait du sac sans que sa reservation baisse : file
--     « fantome » qui exige une finition liee que plus personne ne peut acheter.
--  2. Une finition liee epuisee (usage hors file, autre personnage) n'a aucune
--     sortie : elle est inachetable, donc le lot restait en tete a vie, avec sa
--     concentration gelee. « Next: sans <finition> » reporte les crafts restants
--     sur la meme recette sans finition, sur clic explicite.
--
-- Le dump seul ne sur-engage jamais : l'audit l'a verifie sur 180 000 operations
-- aleatoires (reouvertures, regains de concentration, refund, spare).
--
-- Usage : lua5.1 Tests/test_finishing_lots.lua (depuis addons/YayaQueue)

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

local MATRIX, IDENTIFIER, REBAR = 247719, 260630, 247725
local HERB, RECIPE = 236761, 1230859

CONFIG = {
    FINISHING_REAGENT_ROLES = {
        [MATRIX] = "multicraft", [247724] = "multicraft",
        [REBAR] = "resourcefulness", [247726] = "resourcefulness",
        [IDENTIFIER] = "ingenuity", [247788] = "ingenuity",
    },
}
state = {}
db = { queue = {} }
local owned = {}
function GetTotalOwnedCount(itemID) return owned[itemID] or 0 end
function GetItemName(itemID) return "Objet " .. tostring(itemID) end
function DebugPrint() end
YQQuality = { DebugCraftState = function() end }
local craftLocked, nextLock = false, nil
function IsCraftClickLocked() return craftLocked end
function GetNextActionLock() return nextLock end
function NormalizeApplyConcentration(value) return value == true end
function GetEntryCraftsRemaining(entry) return entry.craftQty or 0, 0 end
state.EnsureDB = function() end

-- Parentheses autour de gsub : il rend aussi un nombre de remplacements, qui
-- deviendrait un element de la table.
assert(loadstring(table.concat({
    (Extract("NormalizeReagents", "(local function NormalizeReagents%(reagents%).-\nend)\n"):gsub("^local function", "function")),
    (Extract("NormalizeCraftingReagents",
        "(local function NormalizeCraftingReagents%(craftingReagents%).-\nend)\n"):gsub("^local function", "function")),
    (Extract("BuildCraftingReagentSignature",
        "(local function BuildCraftingReagentSignature%(craftingReagents%).-\nend)\n"):gsub("^local function", "function")),
}, "\n"), "normalizers"))()

local added = {}
function AddRecipeToQueue(context, quantity)
    added[#added + 1] = { context = context, quantity = quantity }
    return context, quantity
end

assert(loadstring(table.concat({
    Extract("StripBoundFinishing", "(state%.StripBoundFinishing = function%(context%).-\nend)\n"),
    Extract("GetFinishingLimit", "(state%.GetFinishingLimit = function%(entry%).-\nend)\n"),
    Extract("DropEntryFinishing", "(state%.DropEntryFinishing = function%(entry%).-\nend)\n"),
    Extract("QueuePendingCraftEntry", "(state%.QueuePendingCraftEntry = function%(entry, amount%).-\nend)\n"),
}, "\n"), "finishing-lots"))()
state.pendingCraftEntries = {}

local function Finishing(itemID, quantity, slot)
    return { dataSlotIndex = slot or 3, reagent = { itemID = itemID }, quantity = quantity or 1 }
end
local function Herb(quantity)
    return { dataSlotIndex = 1, reagent = { itemID = HERB }, quantity = quantity or 4 }
end
local function Lot(finishingID, crafts)
    local craftingReagents = { Herb() }
    local reagents = { { itemID = HERB, quantity = 4 } }
    if finishingID then
        craftingReagents[#craftingReagents + 1] = Finishing(finishingID)
        reagents[#reagents + 1] = { itemID = finishingID, quantity = 1 }
    end
    table.sort(reagents, function(a, b) return a.itemID < b.itemID end)
    local signature = {}
    for _, reagent in ipairs(reagents) do signature[#signature + 1] = reagent.itemID .. ":" .. reagent.quantity end
    return {
        recipeID = RECIPE, recipeName = "Potion of Recklessness", mode = "crafts", craftQty = crafts,
        applyConcentration = true, professionID = 2906, concentrationCost = 161,
        reagents = reagents, craftingReagents = craftingReagents,
        reagentSignature = table.concat(signature, "|"),
    }
end

-- ---------------------------------------------------------------------------
section("Entree privee de sa finition liee")
-- ---------------------------------------------------------------------------

local lot = Lot(MATRIX, 3)
local stripped = state.StripBoundFinishing(lot)
equals("la finition disparait de craftingReagents", #stripped.craftingReagents, 1)
equals("... le reactif de base reste", stripped.craftingReagents[1].reagent.itemID, HERB)
equals("... et de reagents", #stripped.reagents, 1)
equals("... le reactif de base reste en quantite", stripped.reagents[1].quantity, 4)
equals("l'entree d'origine n'est pas modifiee", #lot.craftingReagents, 2)
equals("... ni ses reagents", #lot.reagents, 2)
equals("les autres champs sont copies (concentration)", stripped.concentrationCost, 161)

local plain = state.StripBoundFinishing(Lot(nil, 2))
equals("un lot sans finition reste identique", #plain.craftingReagents, 1)

-- ---------------------------------------------------------------------------
section("Crafts permis par le stock de finitions")
-- ---------------------------------------------------------------------------

owned = { [MATRIX] = 5 }
equals("cinq Matrix, une par craft : cinq crafts", (state.GetFinishingLimit(Lot(MATRIX, 9))), 5)
local limit, limitingID, perCraft = state.GetFinishingLimit(Lot(MATRIX, 9))
equals("... le reactif limitant est nomme", limitingID, MATRIX)
equals("... avec sa quantite par craft", perCraft, 1)
owned = { [MATRIX] = 0 }
equals("aucune Matrix : zero craft", (state.GetFinishingLimit(Lot(MATRIX, 3))), 0)
owned = { [MATRIX] = 5 }
equals("lot sans finition : aucune limite", (state.GetFinishingLimit(Lot(nil, 3))), nil)
local patron = Lot(MATRIX, 1)
patron.queueKind = "patron"
equals("commande de patron : jamais limitee", (state.GetFinishingLimit(patron)), nil)
local salvage = Lot(MATRIX, 1)
salvage.isSalvageRecipe = true
equals("salvage : jamais limite", (state.GetFinishingLimit(salvage)), nil)
local twoUnits = Lot(MATRIX, 3)
twoUnits.craftingReagents[2].quantity = 2
owned = { [MATRIX] = 5 }
equals("deux unites par craft : deux crafts avec cinq en stock", (state.GetFinishingLimit(twoUnits)), 2)

-- ---------------------------------------------------------------------------
section("Consommation : le craft decremente le lot qu'il a execute")
-- ---------------------------------------------------------------------------

local matched
function ConsumeMatchedQueueEntry(index, entry, entryData)
    matched = { index = index, entry = entry }
    return entry.recipeName
end
assert(loadstring((assert(
    source:match("(local function ConsumeCraftEntry%(entryData%).-\nend)\n"),
    "ConsumeCraftEntry introuvable")):gsub("^local function", "function")
    .. "\nreturn ConsumeCraftEntry"))()

-- (le chargement ci-dessus definit ConsumeCraftEntry en global)
local matrixLot, identifierLot, plainLot = Lot(MATRIX, 2), Lot(IDENTIFIER, 2), Lot(nil, 2)
db.queue = { matrixLot, identifierLot, plainLot }

state.pendingCraftEntries = {}
state.QueuePendingCraftEntry(identifierLot, 2)
local pending = state.pendingCraftEntries[1]
equals("l'entree en attente retient la signature des reactifs", pending.reagentSignature, identifierLot.reagentSignature)
equals("... et celle des reactifs de craft",
    pending.craftingReagentSignature, BuildCraftingReagentSignature(identifierLot.craftingReagents))

matched = nil
ConsumeCraftEntry(pending)
equals("le lot Identifier est decremente, pas le premier de la file", matched and matched.index, 2)

matched = nil
state.pendingCraftEntries = {}
state.QueuePendingCraftEntry(plainLot, 1)
ConsumeCraftEntry(state.pendingCraftEntries[1])
equals("le lot sans finition est retrouve de la meme facon", matched and matched.index, 3)

matched = nil
local legacy = { recipeID = RECIPE, applyConcentration = true, amount = 1 }
ConsumeCraftEntry(legacy)
equals("sans signature (ancien suivi), repli historique : premier lot de la recette", matched and matched.index, 1)

matched = nil
local orphan = { recipeID = RECIPE, applyConcentration = true, amount = 1,
    craftingReagentSignature = "inconnu", reagentSignature = "inconnu" }
ConsumeCraftEntry(orphan)
equals("signature introuvable (lot fusionne entre-temps) : repli, jamais de craft sans decrement",
    matched and matched.index, 1)

matched = nil
db.queue = { { recipeID = 999, queueKind = "patron", orderID = 55, applyConcentration = false } }
ConsumeCraftEntry({ recipeID = 999, queueKind = "patron", orderID = 55, applyConcentration = false, amount = 1 })
equals("une commande de patron reste identifiee par son orderID", matched and matched.index, 1)

-- ---------------------------------------------------------------------------
section("Sortie : « Next: sans <finition> »")
-- ---------------------------------------------------------------------------

local function Fresh()
    local entry = Lot(MATRIX, 3)
    db.queue = { entry }
    added = {}
    craftLocked, nextLock = false, nil
    return entry
end

local entry = Fresh()
local moved = state.DropEntryFinishing(entry)
equals("les crafts restants sont reportes", moved, 3)
equals("l'entree d'origine quitte la file", #db.queue, 0)
equals("un seul ajout, sans finition", #added, 1)
equals("... pour la meme quantite", added[1].quantity, 3)
equals("... sans la Matrix", #added[1].context.craftingReagents, 1)
equals("... la concentration est conservee", added[1].context.applyConcentration, true)

entry = Fresh()
craftLocked = true
equals("refuse pendant un lot de crafts en vol", state.DropEntryFinishing(entry), 0)
equals("... et ne touche pas a la file", #db.queue, 1)
craftLocked = false
nextLock = { action = "craft" }
equals("refuse tant qu'un verrou d'action est actif", state.DropEntryFinishing(entry), 0)
nextLock = nil

local stale = {}
for key, value in pairs(entry) do stale[key] = value end
equals("une copie perimee de l'entree est retrouvee par signature", state.DropEntryFinishing(stale), 3)
equals("... l'entree reelle est retiree", #db.queue, 0)
equals("rejouer le drop sur l'ancienne copie ne compte pas les crafts deux fois", state.DropEntryFinishing(stale), 0)
equals("... aucun ajout de plus", #added, 1)

local patronEntry = Lot(MATRIX, 1)
patronEntry.queueKind = "patron"
db.queue = { patronEntry }
added = {}
equals("une commande de patron n'est jamais convertie", state.DropEntryFinishing(patronEntry), 0)
equals("... et reste dans la file", #db.queue, 1)

-- ---------------------------------------------------------------------------
section("Branchement dans la source")
-- ---------------------------------------------------------------------------

local nextState = Extract("GetPatronNextButtonState", "(local function GetPatronNextButtonState%(%).-\nend)\n")
local finishingAt = nextState:find("state.GetFinishingLimit(entry)", 1, true)
local resourcesAt = nextState:find("GetEntryResourceState(entry)", finishingAt or 1, true)
equals("Next lit le stock de finitions avant le gate materiaux", finishingAt ~= nil and resourcesAt ~= nil and finishingAt < resourcesAt, true)
equals("... propose l'action explicite",
    nextState:find('action = "drop_finishing"', 1, true) ~= nil, true)
equals("... et plafonne un lot au stock de finitions",
    nextState:find("craftAmount = finishingLimit", 1, true) ~= nil, true)
equals("le clic traite l'action",
    source:find('if stateInfo.action == "drop_finishing" then', 1, true) ~= nil, true)
equals("... qui n'est pas une action securisee",
    source:find('drop_finishing = true', 1, true), nil)

print(("\n%d OK, %d echec(s)"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
