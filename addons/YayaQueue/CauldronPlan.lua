-- Plan pur des recettes de Camberon's Cauldron.
-- Aucun appel WoW ici : le calcul de priorite et de budget reste testable hors jeu.

local _, ns = ...

local CauldronPlan = {}
ns.CauldronPlan = CauldronPlan

CauldronPlan.RESISTANCE_FLASK_ITEM_ID = 241321 -- Flask of Thalassian Resistance
CauldronPlan.MOXIE_CURRENCY_ID = 3256

-- L'ordre est volontaire : les motes restent toujours en dernier.
-- Les recettes gratuites passent avant les recettes a Moxie puisqu'elles
-- n'entament pas le budget du jour.
CauldronPlan.RECIPES = {
    { recipeID = 1230865, outputItemID = 241300, name = "Lightfused Mana Potion", moxieCost = 0, order = 10 },
    { recipeID = 1230861, outputItemID = 241291, name = "Primal Philosopher's Stone", moxieCost = 0, order = 20 },
    { recipeID = 1230862, outputItemID = 241294, name = "Potion of Devoured Dreams", moxieCost = 25, order = 100 },
    { recipeID = 1230872, outputItemID = 241313, name = "Haranir Phial of Ingenuity", moxieCost = 25, order = 110 },
    { recipeID = 1230892, outputItemID = 245650, name = "Bouquet of Herbs", moxieCost = 0, order = 120 },
    { recipeID = 1230869, outputItemID = 241308, name = "Light's Potential", moxieCost = 50, order = 200 },
    { recipeID = 1230863, outputItemID = 241296, name = "Potion of Zealotry", moxieCost = 50, order = 210 },
    { recipeID = 1230860, outputItemID = 241292, name = "Draught of Rampant Abandon", moxieCost = 50, order = 220 },
    { recipeID = 1230877, outputItemID = 241324, name = "Flask of the Blood Knights", moxieCost = 50, order = 300,
        requiresItemID = CauldronPlan.RESISTANCE_FLASK_ITEM_ID },
    { recipeID = 1230876, outputItemID = 241322, name = "Flask of the Magisters", moxieCost = 50, order = 310 },
    { recipeID = 1230878, outputItemID = 241326, name = "Flask of the Shattered Sun", moxieCost = 50, order = 320 },
    { recipeID = 1230890, outputItemID = 236949, name = "Transmute: Mote of Light", moxieCost = 25, order = 400 },
    { recipeID = 1230889, outputItemID = 236950, name = "Transmute: Mote of Primal Energy", moxieCost = 25, order = 410 },
    { recipeID = 1230888, outputItemID = 236952, name = "Transmute: Mote of Pure Void", moxieCost = 25, order = 420 },
}

function CauldronPlan.GetRecipeByOutputItemID(outputItemID)
    outputItemID = tonumber(outputItemID)
    if not outputItemID then
        return nil
    end
    for _, recipe in ipairs(CauldronPlan.RECIPES) do
        if recipe.outputItemID == outputItemID then
            return recipe
        end
    end
    return nil
end

function CauldronPlan.Build(availableMoxie, knownByID, queuedByID)
    local plan = {}
    local remaining = math.max(0, math.floor(tonumber(availableMoxie) or 0))
    for _, recipe in ipairs(CauldronPlan.RECIPES) do
        local recipeID = recipe.recipeID
        if not (knownByID and knownByID[recipeID])
            and not (queuedByID and queuedByID[recipeID])
        then
            local cost = math.max(0, tonumber(recipe.moxieCost) or 0)
            if cost == 0 or remaining >= cost then
                plan[#plan + 1] = recipe
                remaining = remaining - cost
            end
        end
    end
    return plan, remaining
end
