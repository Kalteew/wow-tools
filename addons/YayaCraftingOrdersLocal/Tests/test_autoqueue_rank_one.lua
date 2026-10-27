-- Garde "rang 1" de la mise en file automatique des commandes de patron
-- (Pane:CanAutoQueueAtRankOne / ShouldAutoQueuePatronOrder, BrowsePane.lua).
--
-- Regression gardee : EvaluateQualityRequirement produit des plans
-- (lowestPlan, reachablePlan), CompactQualityRequirement les jette en fin de
-- preparation, et la garde les relisait APRES -- donc toujours nil. Toute
-- commande a qualite exigee (coche verte ou ambre dans la liste) etait ecartee
-- de la file, meme profitable et realisable avec du rang 1.
--
-- Le test fait passer la VRAIE compaction avant la garde : tester la garde sur
-- une structure ecrite a la main aurait laisse passer le bug.
--
-- Usage : lua5.1 Tests/test_autoqueue_rank_one.lua   (depuis addons/YayaCraftingOrdersLocal)

Enum = {}
COPPER_PER_GOLD = 10000

local ns = { Util = {}, L = {} }
ns.Debug = function() end
ns.RegisterEvent = function() end

local chunk, compileError = loadfile("BrowsePane.lua")
if not chunk then
    print("ECHEC compilation BrowsePane.lua :: " .. tostring(compileError))
    os.exit(2)
end
local loaded, loadError = pcall(chunk, "YayaCraftingOrdersLocal", ns)
if not loaded then
    print("ECHEC chargement BrowsePane.lua :: " .. tostring(loadError))
    os.exit(3)
end

local Pane = ns.BrowsePane

local failures = 0
local checks = 0

local function Check(label, condition, detail)
    checks = checks + 1
    if condition then
        print("  OK    " .. label)
    else
        failures = failures + 1
        print("  ECHEC " .. label .. (detail and (" :: " .. tostring(detail)) or ""))
    end
end

Check("la compaction est exposee pour ce test", type(Pane.CompactQualityRequirement) == "function")

-- Une commande profitable et connue ; la qualite est ce qui varie.
local function Order(requirement)
    return {
        orderID = 4242,
        isKnown = true,
        isRecraft = false,
        profitKnown = true,
        profitValue = 283,
        recipeInfo = { recipeID = 1229897 },
        qualityRequirement = requirement and Pane.CompactQualityRequirement(requirement) or nil,
    }
end

local noQueueApi = {}
local function Allowed(order)
    return Pane:CanAutoQueueAtRankOne(order) == true
end

local lowest = { operationInfo = { craftingQuality = 2 } }
local rankTwo = { operationInfo = { craftingQuality = 3 } }

--------------------------------------------------------------------------------
-- Les cas de la liste
--------------------------------------------------------------------------------

Check("sans exigence de qualite (aucune coche) : mise en file permise",
    Allowed(Order({ showInList = false, lowestPlan = lowest, activePlan = lowest })))

Check("coche verte (le rang 1 suffit) : mise en file permise",
    Allowed(Order({
        showInList = true, state = "green",
        lowestPlan = lowest, reachablePlan = lowest, activePlan = lowest,
    })))

Check("coche ambre, rang 1 + concentration : mise en file permise",
    Allowed(Order({
        showInList = true, state = "amber",
        lowestPlan = lowest, reachablePlan = lowest, activePlan = lowest,
    })))

Check("coche ambre, il faut du rang 2 : ecartee (on n'achete pas de rang 2 en auto)",
    not Allowed(Order({
        showInList = true, state = "amber",
        lowestPlan = lowest, reachablePlan = rankTwo, activePlan = rankTwo,
    })))

Check("qualite inatteignable : ecartee",
    not Allowed(Order({
        showInList = true, state = "none",
        lowestPlan = lowest, activePlan = lowest,
    })))

Check("qualite exigee mais plan de rang 1 introuvable : ecartee, pas permise par defaut",
    not Allowed(Order({
        showInList = true, state = "green",
        lowestPlan = nil, reachablePlan = nil,
    })))

Check("commande sans donnee de qualite du tout : permise (ancien comportement)",
    Allowed(Order(nil)))

--------------------------------------------------------------------------------
-- La garde complete, bout en bout
--------------------------------------------------------------------------------

local greenOrder = Order({
    showInList = true, state = "green",
    lowestPlan = lowest, reachablePlan = lowest, activePlan = lowest,
})
Check("ShouldAutoQueuePatronOrder accepte une commande verte, connue et profitable",
    Pane:ShouldAutoQueuePatronOrder(greenOrder, noQueueApi) == true)

local unprofitable = Order({
    showInList = true, state = "green",
    lowestPlan = lowest, reachablePlan = lowest, activePlan = lowest,
})
unprofitable.profitValue = -217
Check("... et refuse toujours la meme commande a perte",
    not Pane:ShouldAutoQueuePatronOrder(unprofitable, noQueueApi))

local rankTwoOrder = Order({
    showInList = true, state = "amber",
    lowestPlan = lowest, reachablePlan = rankTwo, activePlan = rankTwo,
})
Check("... et refuse toujours une commande qui exige du rang 2",
    not Pane:ShouldAutoQueuePatronOrder(rankTwoOrder, noQueueApi))

--------------------------------------------------------------------------------

print(("\n%d reussite(s), %d echec(s)"):format(checks - failures, failures))
if failures > 0 then
    os.exit(1)
end
