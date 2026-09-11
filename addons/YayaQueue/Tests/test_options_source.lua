-- Garde-fous de source du panneau d'options de YayaQueue, executes hors du jeu
-- avec Lua 5.1.
--
-- YayaQueue.lua ne se charge pas sans le client : on lit le texte et on verifie
-- que le panneau passe par YayaCore.Settings.BuildPanel, que chaque cle de la
-- base y a son descripteur, et que l'ancien panneau ecrit a la main a disparu.
--
-- Usage : lua5.1 Tests/test_options_source.lua   (depuis addons/YayaQueue)

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

-- Zone du panneau : du debut d'EnsureOptions au debut d'OpenOptions.
local optionsStart = source:find("YQQuality.EnsureOptions = function()", 1, true)
local optionsEnd = source:find("YQQuality.OpenOptions = function()", 1, true)
assert(optionsStart and optionsEnd and optionsEnd > optionsStart, "zone EnsureOptions introuvable")
local optionsZone = source:sub(optionsStart, optionsEnd - 1)

-- ---------------------------------------------------------------------------
-- Socle
-- ---------------------------------------------------------------------------

section("Socle YayaCore.Settings")

equals("le panneau est construit par YayaCore.Settings.BuildPanel",
    optionsZone:find("YSettings.BuildPanel(", 1, true) ~= nil
        and source:find("YayaCore.Settings", 1, true) ~= nil, true)
equals("le socle absent ne plante pas ADDON_LOADED",
    optionsZone:find('type(YSettings.BuildPanel) ~= "function"', 1, true) ~= nil, true)
equals("la garde idempotente est conservee",
    optionsZone:find("if state.optionsPanel then", 1, true) ~= nil, true)
equals("le handle est memorise dans state.options",
    optionsZone:find("state.options = YSettings.BuildPanel", 1, true) ~= nil, true)
equals("OpenOptions ouvre via le handle",
    source:find("state.options.Open()", 1, true) ~= nil, true)
equals("le panneau notifie ScheduleRefresh",
    optionsZone:find("onChange = function()\n            ScheduleRefresh()", 1, true) ~= nil, true)

-- ---------------------------------------------------------------------------
-- Cles : une par ligne du tableau du plan, dans la zone du panneau
-- ---------------------------------------------------------------------------

section("Descripteurs par cle")

local KEYS = {
    -- Panneau de file
    "panelLocked", "craftVisibleRows", "queueSortMode", "qualityPanelEnabled", "qualityPanelLocked",
    -- Concentration
    "concentrationPhialEnabled", "concentrationPhialRank", "concentrationPhialPurchaseQuantity",
    "autoQueueIngenuityRefund",
    -- Automatismes
    "autoBuyVendor", "autoQueueFavoriteConcentration", "autoQueueAlchemy", "resetQuantityOnRecipeChange",
    -- Hotel des ventes et seuils
    "auctionPriceWarningSoundEnabled", "auctionPriceWarningTolerancePercent", "auctionHighPriceMultiplier",
    "auctionCutPercent", "firstCraftCostLimitGold", "wondrousSynergistMinBuyoutGold",
    -- Shatter
    "shatterGatingEnabled", "shatterPreferredMoteItemID",
    -- Diagnostic
    "debugEnabled", "debugLogOnly",
}
equals("le tableau compte 23 cles", #KEYS, 23)

for _, key in ipairs(KEYS) do
    local needle = 'key = "' .. key .. '"'
    local first = optionsZone:find(needle, 1, true)
    equals("descripteur present : " .. key, first ~= nil, true)
    if first then
        equals("descripteur unique : " .. key,
            optionsZone:find(needle, first + 1, true) == nil, true)
    end
end

-- ---------------------------------------------------------------------------
-- Categories, dans l'ordre du rail
-- ---------------------------------------------------------------------------

section("Categories")

local CATEGORIES = {
    "Panneau de file", "Concentration", "Automatismes",
    "Hotel des ventes et seuils", "Shatter (enchantement)", "Diagnostic",
}
local cursor = 1
for _, category in ipairs(CATEGORIES) do
    local found = optionsZone:find('category = "' .. category .. '"', cursor, true)
    equals("categorie dans l'ordre : " .. category, found ~= nil, true)
    if found then
        cursor = found + 1
    end
end

-- ---------------------------------------------------------------------------
-- Effets de bord et ancien panneau
-- ---------------------------------------------------------------------------

section("Effets de bord")

equals("qualityPanelEnabled passe par SetSelectorEnabled",
    optionsZone:find("YQQuality.SetSelectorEnabled(value)", 1, true) ~= nil, true)
equals("le rang de phial est lu comme une case rang 2",
    optionsZone:find("current.concentrationPhialRank == 2", 1, true) ~= nil, true)
equals("changer la mote retire la demande en file",
    optionsZone:find("YQQuality.RemoveShatterMoteDemand()", 1, true) ~= nil, true)
equals("le mode debug est reflete dans CONFIG",
    optionsZone:find("CONFIG.debugNextCraft = value", 1, true) ~= nil, true)
equals("la taxe HV invalide le cache de prix",
    optionsZone:find("state.InvalidateQualityPricing()", 1, true) ~= nil, true)
equals("le tri propose les modes de QueueOrder",
    optionsZone:find("QueueOrder.MODES", 1, true) ~= nil, true)

section("Ancien panneau")

equals("plus de case construite a la main dans le panneau",
    optionsZone:find("UI.CreateCheckbox(", 1, true) == nil, true)
equals("plus de StackLayout dans le panneau",
    optionsZone:find("UI.StackLayout(", 1, true) == nil, true)
equals("plus d'enregistrement Blizzard direct dans le panneau",
    optionsZone:find("Settings.RegisterCanvasLayoutCategory", 1, true) == nil, true)
equals("plus de pseudo-radio SetPhialPurchaseQuantity",
    source:find("SetPhialPurchaseQuantity", 1, true) == nil, true)

-- ---------------------------------------------------------------------------
-- Synchro inverse : les ecritures hors panneau rafraichissent les widgets
-- ---------------------------------------------------------------------------

section("Synchro inverse")

equals("state.RefreshOptionsPanel est defini",
    source:find("state.RefreshOptionsPanel = function()", 1, true) ~= nil, true)
local calls = select(2, source:gsub("state%.RefreshOptionsPanel%(%)", ""))
equals("les ecritures hors panneau rafraichissent (>= 9 sites)", calls >= 9, true)
equals("CommitResize rafraichit le panneau",
    source:find("SavePanelPoint(panel)\n    state.RefreshOptionsPanel()", 1, true) ~= nil, true)
equals("SetSelectorEnabled rafraichit le panneau",
    source:find("if not enabled then YQQuality.CancelRecipeSolve() end\n"
        .. "    -- Point de passage unique", 1, true) ~= nil, true)

-- ---------------------------------------------------------------------------
-- Budget de locals de chunk
-- ---------------------------------------------------------------------------

section("Budget de locals")

local chunkLocals = 0
for line in (source .. "\n"):gmatch("([^\n]*)\n") do
    if line:match("^local%s+function%s+[%a_][%w_]*") then
        chunkLocals = chunkLocals + 1
    elseif line:match("^local%s") then
        local names = line:match("^local%s+([^=]+)") or ""
        for name in names:gmatch("[^,]+") do
            if name:match("^%s*[%a_][%w_]*%s*$") then
                chunkLocals = chunkLocals + 1
            end
        end
    end
end
equals("au plus 196 locals de chunk", chunkLocals <= 196, true)

print("")
print(("%d reussis, %d echoues"):format(passed, failed))
if failed > 0 then
    os.exit(1)
end
