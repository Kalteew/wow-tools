-- Regression du cooldown partage des transmutations d'alchimie.
--
-- Le scan des first crafts doit traiter Bouquet of Herbs avant les autres
-- recettes de la famille, puis compter Box of Rocks/School of Gems sur la meme
-- reservation. Le test extrait les deux fonctions de decision de la source.
--
-- Usage : lua5.1 Tests/test_alchemy_cooldown.lua (depuis addons/YayaQueue)

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

local handle = assert(io.open("YayaQueue.lua", "rb"), "YayaQueue.lua introuvable")
local source = handle:read("*a"):gsub("\r\n", "\n")
handle:close()

local sortBody = assert(
    source:match("(alchemyAuto%.SortFirstCraftRecipeIDs = function%(recipeIDs%).-\nend)\n"),
    "SortFirstCraftRecipeIDs introuvable"
)
local cooldownBody = assert(
    source:match("(local function GetCraftSimCooldownKey%(craftSim, recipeID, cooldownData%).-\nend)\n"),
    "GetCraftSimCooldownKey introuvable"
):gsub("^local function", "function")

CONFIG = {
    ALCHEMY_BOUQUET_RECIPE_ID = 1230892,
    ALCHEMY_BOUQUET_SHARED_COOLDOWN_KEY = "midnight-alchemy-material-transmutations",
    ALCHEMY_BOUQUET_SHARED_COOLDOWN_RECIPE_IDS = {
        [1230891] = true,
        [1230892] = true,
        [1230893] = true,
    },
}

alchemyAuto = {}
assert(loadstring(sortBody .. "\n" .. cooldownBody, "alchemy-cooldown"))()

local recipeIDs = { 1230891, 1230892, 991001, 1230893 }
alchemyAuto.SortFirstCraftRecipeIDs(recipeIDs)
equals("Bouquet passe avant les transmutations concurrentes", recipeIDs[1], 1230892)
equals("Box of Rocks reste apres Bouquet", recipeIDs[2], 1230891)
equals("School of Gems reste dans la famille", recipeIDs[3], 1230893)
equals("les autres recettes restent apres la famille", recipeIDs[4], 991001)

equals(
    "Box of Rocks partage le cooldown explicite",
    GetCraftSimCooldownKey(nil, 1230891, { isCooldownRecipe = true }),
    "shared:midnight-alchemy-material-transmutations"
)
equals(
    "une autre recette garde son cooldown propre",
    GetCraftSimCooldownKey(nil, 991001, { isCooldownRecipe = true }),
    "recipe:991001"
)

print(("\n%d OK, %d echec(s)"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
