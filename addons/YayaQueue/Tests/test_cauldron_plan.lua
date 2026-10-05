-- Tests purs du plan Camberon's Cauldron.

local passed, failed = 0, 0

local function equals(name, actual, expected)
    if actual == expected then
        passed = passed + 1
        print(("  OK    %s"):format(name))
    else
        failed = failed + 1
        print(("  ECHEC %s -> attendu %s, obtenu %s"):format(name, tostring(expected), tostring(actual)))
    end
end

local ns = {}
assert(loadfile("CauldronPlan.lua"))("YayaQueue", ns)
local plan = assert(ns.CauldronPlan, "ns.CauldronPlan non exporte")

local function IDs(recipes)
    local result = {}
    for _, recipe in ipairs(recipes) do
        result[#result + 1] = recipe.recipeID
    end
    return table.concat(result, ",")
end

local selected, remaining = plan.Build(75, {}, {})
equals("75 Moxie selectionne 25 puis la mote finale", IDs(selected),
    "1230865,1230861,1230862,1230872,1230892,1230890")
equals("75 Moxie est entierement reservee", remaining, 0)

selected, remaining = plan.Build(100, {}, {})
equals("100 Moxie ne depasse pas le budget", IDs(selected),
    "1230865,1230861,1230862,1230872,1230892,1230869")
equals("100 Moxie ne reserve qu'une recette a 50", remaining, 0)

local knownBeforeFlasks = {
    [1230865] = true, [1230861] = true, [1230862] = true,
    [1230872] = true, [1230892] = true, [1230869] = true,
    [1230863] = true, [1230860] = true,
}
selected, remaining = plan.Build(100, knownBeforeFlasks, {})
equals("100 Moxie ajoute deux flasques a 50", IDs(selected),
    "1230877,1230876")
equals("la troisieme flasque a 50 attend", remaining, 0)

equals("la flasque Blood Knights est retrouvable par output", 
    plan.GetRecipeByOutputItemID(241324).recipeID, 1230877)
equals("un output inconnu ne correspond a aucune recette",
    plan.GetRecipeByOutputItemID(999999), nil)

local hasSchool = false
for _, recipe in ipairs(plan.RECIPES) do
    if recipe.recipeID == 1230893 then hasSchool = true end
end
equals("School of Gems est absente", hasSchool, false)

selected, remaining = plan.Build(50, { [1230865] = true, [1230861] = true }, {})
equals("50 Moxie ignore les recettes gratuites deja apprises", IDs(selected),
    "1230862,1230872,1230892")
equals("50 Moxie garde 0 apres deux recettes a 25", remaining, 0)

selected, remaining = plan.Build(25, {}, { [1230862] = true, [1230872] = true, [1230892] = true })
equals("une recette deja en file est ignoree et les motes restent en dernier", IDs(selected),
    "1230865,1230861,1230890")
equals("le budget est consomme par la mote finale", remaining, 0)

print(("\n%d OK, %d echec(s)"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
