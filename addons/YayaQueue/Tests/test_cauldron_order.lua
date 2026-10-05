-- Regression : les recettes du chaudron de Camberon que le joueur n'a pas
-- apprises ne doivent pas tenir la tete de la file.
--
-- Cas reel : a l'ouverture du metier d'alchimiste, YayaQueue met en file les
-- recettes du chaudron selon la Moxie (transmutations de motes, potions...).
-- Tant qu'elles ne sont pas apprises au chaudron, ce sont des plans : Next
-- affiche « ouvre le chaudron » et ne peut rien faire. Le tri les plaçait avant
-- tous les crafts generiques, donc devant des crafts parfaitement realisables.
--
-- Le test branche le vrai predicat `alchemyAuto.IsCauldronEntryActionable`
-- (extrait de la source) sur le vrai `QueueOrder.lua`, de bout en bout.
--
-- Usage : lua5.1 Tests/test_cauldron_order.lua (depuis addons/YayaQueue)

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

local ns = {}
assert(loadfile("QueueOrder.lua"), "QueueOrder.lua introuvable")("YayaQueue", ns)
local QueueOrder = assert(ns.QueueOrder)

function SafeCall(fn, ...)
    local ok, a = pcall(fn, ...)
    if ok then return a end
    return nil
end

local recipeInfos = {}     -- recipeID -> table recipeInfo
local bags, mailbox = {}, {}
local apiPresent = true
C_TradeSkillUI = {
    GetRecipeInfo = function(recipeID)
        local info = recipeInfos[recipeID]
        if info == "error" then error("boom") end
        return info
    end,
}
function GetImmediateOwnedCount(itemID) return bags[itemID] or 0 end
function GetMailboxCount(itemID) return mailbox[itemID] or 0 end

alchemyAuto = {}
assert(loadstring(
    Extract("IsCauldronEntryActionable",
        "(alchemyAuto%.IsCauldronEntryActionable = function%(entry%).-\nend)\n"),
    "cauldron-actionable"))()

local FLASK_ITEM = 241321
local BLOOD_KNIGHTS = 1230877
local MOTES = 1230890
local POTION = 1230862

local function reset()
    recipeInfos, bags, mailbox = {}, {}, {}
end

-- ---------------------------------------------------------------------------
section("Une entree du chaudron peut-elle avancer ?")
-- ---------------------------------------------------------------------------

reset()
equals("une entree ordinaire n'est jamais concernee",
    alchemyAuto.IsCauldronEntryActionable({ recipeID = 55 }), true)
equals("... ni une valeur absente", alchemyAuto.IsCauldronEntryActionable(nil), true)

local motes = { recipeID = MOTES, cauldronRecipe = true }
equals("recette du chaudron pas apprise, rien a consommer : plan seulement",
    alchemyAuto.IsCauldronEntryActionable(motes), false)
recipeInfos[MOTES] = { recipeID = MOTES, learned = false }
equals("... meme avec des infos de recette (learned = false)",
    alchemyAuto.IsCauldronEntryActionable(motes), false)
recipeInfos[MOTES] = { recipeID = MOTES, learned = true }
equals("recette apprise : Next la promeut en craft ordinaire",
    alchemyAuto.IsCauldronEntryActionable(motes), true)
recipeInfos[MOTES] = "error"
equals("lecture de recette qui leve : jamais une exception, plan seulement",
    alchemyAuto.IsCauldronEntryActionable(motes), false)

local flask = {
    recipeID = BLOOD_KNIGHTS, cauldronRecipe = true,
    cauldronRequiresItemID = FLASK_ITEM, cauldronItemConsumed = false,
}
reset()
equals("flasque requise absente de partout : on ne peut qu'attendre l'achat",
    alchemyAuto.IsCauldronEntryActionable(flask), false)
bags[FLASK_ITEM] = 1
equals("flasque dans les sacs : Next peut la consommer",
    alchemyAuto.IsCauldronEntryActionable(flask), true)
bags[FLASK_ITEM] = nil
mailbox[FLASK_ITEM] = 1
equals("flasque au courrier : Next peut la recuperer",
    alchemyAuto.IsCauldronEntryActionable(flask), true)
mailbox[FLASK_ITEM] = nil
flask.cauldronItemConsumed = true
bags[FLASK_ITEM] = 1
equals("flasque deja consommee et recette pas apprise : plan seulement",
    alchemyAuto.IsCauldronEntryActionable(flask), false)
flask.cauldronItemConsumed = false
bags[FLASK_ITEM] = nil
recipeInfos[BLOOD_KNIGHTS] = { recipeID = BLOOD_KNIGHTS, learned = true }
equals("recette apprise : actionnable meme sans la flasque",
    alchemyAuto.IsCauldronEntryActionable(flask), true)

local savedTradeSkill = C_TradeSkillUI
C_TradeSkillUI = nil
equals("API de metier absente : plan seulement (et jamais d'exception)",
    alchemyAuto.IsCauldronEntryActionable(motes), false)
C_TradeSkillUI = savedTradeSkill

-- ---------------------------------------------------------------------------
section("De bout en bout : le tri suit le predicat")
-- ---------------------------------------------------------------------------

local function Entry(name, fields)
    local entry = { recipeName = name, queueKind = "recipe", professionID = 2906 }
    for key, value in pairs(fields or {}) do entry[key] = value end
    return entry
end

local CTX = {
    claimedOrderID = 0,
    currentProfessionID = 2906,
    isCauldronActionable = function(entry)
        return alchemyAuto.IsCauldronEntryActionable(entry)
    end,
}

local function Sorted(entries, mode)
    local described = {}
    for index, entry in ipairs(entries) do
        described[index] = QueueOrder.Describe(entry, index, CTX)
    end
    local names = {}
    for index, candidate in ipairs(QueueOrder.Sort(described, mode or "standard")) do
        names[index] = candidate.entry.recipeName
    end
    return table.concat(names, ",")
end

reset()
local queue = {
    Entry("motes", { recipeID = MOTES, cauldronRecipe = true, cauldronOrder = 400 }),
    Entry("potion", { recipeID = POTION, cauldronRecipe = true, cauldronOrder = 100 }),
    Entry("elixir", { recipeID = 777 }),
}
equals("rien d'appris : le craft realisable passe devant les deux plans, qui gardent leur ordre",
    Sorted(queue), "elixir,potion,motes")
recipeInfos[MOTES] = { recipeID = MOTES, learned = true }
equals("une recette apprise au chaudron retrouve la tete ; l'autre plan reste derriere le craft",
    Sorted(queue), "motes,elixir,potion")
recipeInfos[POTION] = { recipeID = POTION, learned = true }
equals("toutes apprises : le plan Moxie reprend la tete, dans son ordre",
    Sorted(queue), "potion,motes,elixir")

reset()
equals("aucun predicat : l'ancien comportement (plan en tete)",
    (function()
        local described = {}
        for index, entry in ipairs(queue) do
            described[index] = QueueOrder.Describe(entry, index, { currentProfessionID = 2906 })
        end
        local names = {}
        for index, candidate in ipairs(QueueOrder.Sort(described, "standard")) do
            names[index] = candidate.entry.recipeName
        end
        return table.concat(names, ",")
    end)(), "potion,motes,elixir")

-- ---------------------------------------------------------------------------
section("Branchement dans la source")
-- ---------------------------------------------------------------------------

local contextBody = Extract("GetQueueOrderContext",
    "(state%.GetQueueOrderContext = function%(%).-\nend)\n")
equals("le contexte de tri injecte le predicat du chaudron",
    contextBody:find("isCauldronActionable = function(entry)", 1, true) ~= nil, true)
equals("... qui interroge alchemyAuto.IsCauldronEntryActionable",
    contextBody:find("alchemyAuto.IsCauldronEntryActionable(entry)", 1, true) ~= nil, true)

print("")
print(("%d OK, %d echec(s)"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
