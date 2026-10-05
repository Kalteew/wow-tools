-- Regression : un craft que le jeu refuse (cooldown, echecs repetes) ne doit
-- jamais rester en tete de la file ni etre rejoue a chaque clic.
--
-- Cas reel : « Bouquet of Herbs x2 » en file avec zero charge. Next proposait
-- « Craft x2 », le jeu repondait UNIT_SPELLCAST_FAILED, le verrou tombait, et
-- l'autoclicker rejouait l'echec des dizaines de fois par seconde. Le repli
-- sur `recipeInfo.numAvailable` (crafts permis par les materiaux, rien a voir
-- avec le cooldown) avait mis ces deux crafts en file au depart.
--
-- Le test extrait les fonctions de decision de la source et les rejoue sur une
-- API de metier simulee.
--
-- Usage : lua5.1 Tests/test_craft_limit.lua (depuis addons/YayaQueue)

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
    -- Parentheses : assert rend aussi son message, qui ne doit pas se glisser
    -- comme second element de la table `bodies`.
    return (assert(source:match(pattern), name .. " introuvable"))
end

local bodies = {
    Extract("GetRecipeCooldownState",
        "(state%.GetRecipeCooldownState = function%(recipeID%).-\nend)\n"),
    Extract("GetRecipeAvailableCharges",
        "(alchemyAuto%.GetRecipeAvailableCharges = function%(recipeID%).-\nend)\n"),
    Extract("NoteCraftFailure", "(state%.NoteCraftFailure = function%(recipeID%).-\nend)\n"),
    Extract("ClearCraftFailure", "(state%.ClearCraftFailure = function%(recipeID%).-\nend)\n"),
    Extract("GetEntryCraftLimit", "(state%.GetEntryCraftLimit = function%(entry%).-\nend)\n"),
    Extract("GetRecipeCooldownCap", "(state%.GetRecipeCooldownCap = function%(recipeID%).-\nend)\n"),
    Extract("ScheduleCraftLimitWake",
        "(state%.ScheduleCraftLimitWake = function%(recipeID, limit%).-\nend)\n"),
}
local constants = {
    "state.CRAFT_FAILURE_STREAK = 3",
    "state.CRAFT_FAILURE_WINDOW_SECONDS = 5",
    "state.CRAFT_FAILURE_PARK_SECONDS = 15",
}
assert(source:find(constants[1], 1, true), "constante du disjoncteur introuvable")
assert(source:find(constants[2], 1, true), "constante du disjoncteur introuvable")
assert(source:find(constants[3], 1, true), "constante du disjoncteur introuvable")

-- ---------------------------------------------------------------------------
-- Environnement simule
-- ---------------------------------------------------------------------------

local now = 1000
function GetTime() return now end

local debugLines = {}
function DebugPrint(message) debugLines[#debugLines + 1] = message end

function SafeCall(fn, ...)
    local ok, a = pcall(fn, ...)
    if ok then return a end
    return nil
end

local refreshes = 0
function ScheduleRefresh() refreshes = refreshes + 1 end

local timers = {}
C_Timer = { After = function(delay, fn) timers[#timers + 1] = { delay = delay, fn = fn } end }

local cooldowns = {}      -- recipeID -> { cooldown, isDay, charges, maxCharges } ou fonction
local spellCharges = {}   -- recipeID -> table SpellChargeInfo
local secret = false

C_TradeSkillUI = {
    GetRecipeCooldown = function(recipeID)
        local value = cooldowns[recipeID]
        if type(value) == "function" then return value() end
        if value then return value[1], value[2], value[3], value[4] end
        return nil
    end,
}
C_Spell = { GetSpellCharges = function(recipeID) return spellCharges[recipeID] end }
C_Secrets = { ShouldCooldownsBeSecret = function() return secret end }

state = {
    craftFailures = {},
    craftLimitWake = {},
}
CONFIG = {}
alchemyAuto = {}

local reservations = {}
alchemyAuto.GetCraftSim = function() return nil end
alchemyAuto.GetCooldownKey = function(recipeID) return "recipe:" .. tostring(recipeID) end
alchemyAuto.GetQueuedCooldownReservations = function() return reservations end

assert(loadstring(table.concat(constants, "\n") .. "\n" .. table.concat(bodies, "\n"), "craft-limit"))()

local BOUQUET = 1230892
local SYNERGIST = 1230856

local function reset()
    cooldowns, spellCharges, secret = {}, {}, false
    reservations = {}
    state.craftFailures, state.craftLimitWake = {}, {}
    timers, debugLines, refreshes = {}, {}, 0
    now = 1000
end

-- ---------------------------------------------------------------------------
section("Etat de cooldown : recette a charges")
-- ---------------------------------------------------------------------------

reset()
cooldowns[BOUQUET] = { 3600, false, 0, 2 }
local has, available, remaining, maxCharges, src = state.GetRecipeCooldownState(BOUQUET)
equals("zero charge : cooldown signale", has, true)
equals("zero charge : rien de disponible", available, 0)
equals("le temps avant la charge suivante est rendu", remaining, 3600)
equals("le plafond de charges est rendu", maxCharges, 2)
equals("l'oracle est nomme", src, "charges")

cooldowns[BOUQUET] = { nil, false, 2, 2 }
has, available = state.GetRecipeCooldownState(BOUQUET)
equals("deux charges : deux crafts permis", available, 2)

cooldowns[BOUQUET] = { nil, false, 9, 2 }
_, available = state.GetRecipeCooldownState(BOUQUET)
equals("charges au-dessus du plafond : ramenees au plafond", available, 2)

cooldowns[BOUQUET] = { nil, false, -1, 2 }
_, available = state.GetRecipeCooldownState(BOUQUET)
equals("charges negatives : ramenees a zero", available, 0)

cooldowns[BOUQUET] = { 60, false, nil, 2 }
has, available = state.GetRecipeCooldownState(BOUQUET)
equals("charges illisibles : cooldown signale", has, true)
equals("charges illisibles : jamais « disponible »", available, nil)

section("Etat de cooldown : autres formes")

reset()
cooldowns[BOUQUET] = { 7200, false, nil, nil }
has, available, remaining, maxCharges, src = state.GetRecipeCooldownState(BOUQUET)
equals("cooldown en cours sans drapeau jour ni charges : signale", has, true)
equals("... et la recette n'est pas disponible", available, 0)
equals("... le temps restant est rendu", remaining, 7200)
equals("... sans plafond de charges", maxCharges, nil)
equals("... l'oracle est nomme", src, "cooldown")

cooldowns[SYNERGIST] = { nil, true, nil, nil }
has, available, _, _, src = state.GetRecipeCooldownState(SYNERGIST)
equals("cooldown de jour pret : signale", has, true)
equals("cooldown de jour pret : un craft", available, 1)
equals("... l'oracle est nomme", src, "day-ready")

cooldowns[SYNERGIST] = { 500, true, nil, nil }
_, available = state.GetRecipeCooldownState(SYNERGIST)
equals("cooldown de jour en cours : rien de disponible", available, 0)

reset()
has = state.GetRecipeCooldownState(555)
equals("recette ordinaire : aucun cooldown", has, false)

reset()
spellCharges[BOUQUET] = { currentCharges = 1, maxCharges = 2 }
has, available, _, maxCharges, src = state.GetRecipeCooldownState(BOUQUET)
equals("second oracle : le sort porte ses charges", has, true)
equals("second oracle : charges lues dans la table", available, 1)
equals("second oracle : plafond", maxCharges, 2)
equals("second oracle : nomme", src, "spell-charges")

reset()
cooldowns[BOUQUET] = function() error("valeur secrete") end
has, available, _, _, src = state.GetRecipeCooldownState(BOUQUET)
equals("lecture qui leve : cooldown suppose", has, true)
equals("lecture qui leve : jamais « disponible »", available, nil)
equals("lecture qui leve : nommee", src, "unreadable")

reset()
secret = true
cooldowns[BOUQUET] = { nil, false, 2, 2 }
has, available, _, _, src = state.GetRecipeCooldownState(BOUQUET)
equals("cooldowns secrets : signale sans valeur", has, true)
equals("cooldowns secrets : jamais « disponible »", available, nil)
equals("cooldowns secrets : nomme", src, "secret")

-- ---------------------------------------------------------------------------
section("Charges disponibles : le nombre de crafts permis par les materiaux n'est pas un repli")
-- ---------------------------------------------------------------------------

reset()
equals("aucune lecture : nil, jamais un nombre devine",
    alchemyAuto.GetRecipeAvailableCharges(BOUQUET, { numAvailable = 2 }), nil)
cooldowns[BOUQUET] = { 3600, false, 0, 2 }
equals("cooldown a zero charge malgre des materiaux pour deux crafts",
    alchemyAuto.GetRecipeAvailableCharges(BOUQUET, { numAvailable = 2 }), 0)
cooldowns[BOUQUET] = { 7200, false, nil, nil }
equals("cooldown sans charges malgre des materiaux pour deux crafts",
    alchemyAuto.GetRecipeAvailableCharges(BOUQUET, { numAvailable = 2 }), 0)
equals("la lecture de cooldown ne consulte jamais numAvailable",
    bodies[1]:find("numAvailable", 1, true), nil)
equals("les charges d'Alchimie non plus",
    bodies[2]:find("numAvailable", 1, true), nil)

-- ---------------------------------------------------------------------------
section("Limite d'une entree")
-- ---------------------------------------------------------------------------

reset()
cooldowns[BOUQUET] = { 3600, false, 0, 2 }
local entry = { recipeID = BOUQUET, craftQty = 2 }
local limit = state.GetEntryCraftLimit(entry)
equals("recette a zero charge : limite posee", limit ~= nil, true)
equals("... rien ne peut partir", limit.available, 0)
equals("... raison : cooldown", limit.reason, "cooldown")
equals("... duree restante", limit.remaining, 3600)

cooldowns[BOUQUET] = { nil, false, 1, 2 }
limit = state.GetEntryCraftLimit(entry)
equals("une charge : un craft permis", limit.available, 1)

equals("commande de patron : jamais limitee",
    state.GetEntryCraftLimit({ recipeID = BOUQUET, queueKind = "patron", orderID = 1 }), nil)
equals("fusion : jamais limitee",
    state.GetEntryCraftLimit({ recipeID = BOUQUET, queueKind = "merge" }), nil)
equals("recyclage : jamais limite",
    state.GetEntryCraftLimit({ recipeID = BOUQUET, queueKind = "recycle" }), nil)
equals("salvage : jamais limite",
    state.GetEntryCraftLimit({ recipeID = BOUQUET, isSalvageRecipe = true }), nil)
equals("entree sans recette : jamais limitee", state.GetEntryCraftLimit({}), nil)

reset()
equals("recette ordinaire : pas de limite", state.GetEntryCraftLimit({ recipeID = 555 }), nil)

cooldowns[BOUQUET] = { 60, false, nil, 2 }
equals("cooldown illisible : pas de limite (le disjoncteur reste le filet)",
    state.GetEntryCraftLimit(entry), nil)

reset()
cooldowns[BOUQUET] = { nil, false, 2, 2 }
reservations["recipe:" .. BOUQUET] = 2
equals("plafond du dump : charges moins crafts deja en file",
    state.GetRecipeCooldownCap(BOUQUET), 0)
reservations["recipe:" .. BOUQUET] = 1
equals("plafond du dump : une charge libre", state.GetRecipeCooldownCap(BOUQUET), 1)
reservations["recipe:" .. BOUQUET] = 5
equals("plafond du dump : jamais negatif", state.GetRecipeCooldownCap(BOUQUET), 0)
equals("plafond du dump : recette ordinaire non plafonnee", state.GetRecipeCooldownCap(555), nil)

-- ---------------------------------------------------------------------------
section("Disjoncteur : le meme craft refuse trois fois de suite est suspendu")
-- ---------------------------------------------------------------------------

reset()
equals("premier echec : rien", state.NoteCraftFailure(BOUQUET), false)
equals("deuxieme echec : rien", state.NoteCraftFailure(BOUQUET), false)
equals("la limite n'existe pas encore", state.GetEntryCraftLimit(entry), nil)
equals("troisieme echec : suspendu", state.NoteCraftFailure(BOUQUET), true)
limit = state.GetEntryCraftLimit(entry)
equals("la limite existe", limit ~= nil, true)
equals("... raison : echecs", limit.reason, "failures")
equals("... rien ne peut partir", limit.available, 0)
equals("... duree de la pause", limit.remaining, 15)

now = now + 16
equals("apres la pause : la limite tombe", state.GetEntryCraftLimit(entry), nil)

reset()
state.NoteCraftFailure(BOUQUET)
state.NoteCraftFailure(BOUQUET)
now = now + 6
equals("la serie est oubliee apres la fenetre de cinq secondes",
    state.NoteCraftFailure(BOUQUET), false)

reset()
state.NoteCraftFailure(BOUQUET)
state.NoteCraftFailure(BOUQUET)
state.ClearCraftFailure(BOUQUET)
equals("un craft abouti remet la serie a zero", state.NoteCraftFailure(BOUQUET), false)

reset()
state.NoteCraftFailure(BOUQUET)
state.NoteCraftFailure(BOUQUET)
equals("deux recettes ne se melangent pas", state.NoteCraftFailure(777), false)

-- ---------------------------------------------------------------------------
section("Lot en attente : jamais pose pour un cast deja refuse")
-- ---------------------------------------------------------------------------

assert(loadstring(
    (assert(source:match("(state%.NoteCastFailure = function%(spellID%).-\nend)\n"),
        "NoteCastFailure introuvable"))
        .. "\n"
        .. (assert(source:match("(state%.WasCraftFailedInCall = function%(recipeID%).-\nend)\n"),
        "WasCraftFailedInCall introuvable")),
    "cast-failure"))()

reset()
equals("aucun echec : rien a ignorer", state.WasCraftFailedInCall(BOUQUET), false)
state.NoteCastFailure(BOUQUET)
equals("echec pendant l'appel : le post-hook doit ignorer ce craft", state.WasCraftFailedInCall(BOUQUET), true)
equals("... mais pas une autre recette", state.WasCraftFailedInCall(777), false)
equals("... ni une recette inconnue", state.WasCraftFailedInCall(nil), false)
now = now + 0.5
equals("... et plus rien une fois le frame passe", state.WasCraftFailedInCall(BOUQUET), false)
local succeededHandler = Extract("UnitSpellcastSucceeded",
    "(handle%.UnitSpellcastSucceeded = function.-\nend)\n")
equals("un sort reussi sans rapport avec le craft attendu ne depile rien",
    succeededHandler:find("not state.IsPendingCraftSpell(castSpellID)", 1, true) ~= nil, true)
equals("... le filtre passe avant tout depilage",
    (succeededHandler:find("not state.IsPendingCraftSpell(castSpellID)", 1, true) or 0)
        < (succeededHandler:find("state.PopPendingCraftEntry()", 1, true) or 0), true)
equals("QueuePendingCraftRecipe consulte cette memoire avant de poser un lot",
    source:find("if state.WasCraftFailedInCall(recipeID) then", 1, true) ~= nil, true)
equals("le handler d'echec l'alimente",
    source:find("state.NoteCastFailure(abortedSpellID)", 1, true) ~= nil, true)

-- ---------------------------------------------------------------------------
section("Reveil : le bouton se rafraichit quand la limite se leve")
-- ---------------------------------------------------------------------------

reset()
state.ScheduleCraftLimitWake(BOUQUET, { remaining = 100 })
equals("un reveil est arme", #timers, 1)
equals("... a la duree restante plus une seconde", timers[1].delay, 101)
state.ScheduleCraftLimitWake(BOUQUET, { remaining = 100 })
equals("pas de reveil en double", #timers, 1)
timers[1].fn()
equals("le reveil rafraichit le panneau", refreshes, 1)
state.ScheduleCraftLimitWake(BOUQUET, { remaining = 100 })
equals("apres le reveil, un nouveau peut etre arme", #timers, 2)

reset()
state.ScheduleCraftLimitWake(BOUQUET, { remaining = 100000 })
equals("un cooldown tres long est reverifie au bout de cinq minutes", timers[1].delay, 300)
reset()
state.ScheduleCraftLimitWake(BOUQUET, nil)
equals("duree inconnue : retour au bout de trente secondes", timers[1].delay, 30)

-- ---------------------------------------------------------------------------
section("Ouverture programmatique (amorcage YayaWeeklyTracker)")
-- ---------------------------------------------------------------------------

YQQuality = {}
assert(loadstring(
    (assert(source:match("(function YQQuality%.IsProgrammaticTradeSkillOpen%(%).-\nend)\n"),
        "IsProgrammaticTradeSkillOpen introuvable")),
    "programmatic-open"))()

_G.YayaWeeklyTrackerAPI = nil
equals("YWT absent : jamais programmatique", YQQuality.IsProgrammaticTradeSkillOpen(), false)
_G.YayaWeeklyTrackerAPI = {}
equals("API sans la fonction : jamais programmatique", YQQuality.IsProgrammaticTradeSkillOpen(), false)
_G.YayaWeeklyTrackerAPI = { IsProgrammaticTradeSkillOpen = function() return true end }
equals("YWT annonce une ouverture programmatique", YQQuality.IsProgrammaticTradeSkillOpen(), true)
_G.YayaWeeklyTrackerAPI = { IsProgrammaticTradeSkillOpen = function() return false end }
equals("YWT annonce une ouverture du joueur", YQQuality.IsProgrammaticTradeSkillOpen(), false)
_G.YayaWeeklyTrackerAPI = { IsProgrammaticTradeSkillOpen = function() error("boom") end }
equals("une erreur cote YWT ne bloque jamais l'ouverture", YQQuality.IsProgrammaticTradeSkillOpen(), false)
_G.YayaWeeklyTrackerAPI = { IsProgrammaticTradeSkillOpen = function() return "oui" end }
equals("seul `true` compte", YQQuality.IsProgrammaticTradeSkillOpen(), false)
_G.YayaWeeklyTrackerAPI = nil

-- ---------------------------------------------------------------------------
section("Reservations de finitions vues par la fusion de YayaWeeklyTracker")
-- ---------------------------------------------------------------------------

CONFIG.FINISHING_REAGENT_ROLES = {
    [247719] = "multicraft", [247724] = "multicraft",
    [247725] = "resourcefulness", [247726] = "resourcefulness",
    [260630] = "ingenuity", [247788] = "ingenuity",
}
local queueReservations = {}
YQQuality.GetQueuedReagentReservations = function() return queueReservations end
assert(loadstring(
    (assert(source:match("(function YQQuality%.NotifyFinishingReservations%(%).-\nend)\n"),
        "NotifyFinishingReservations introuvable")),
    "notify-finishing"))()
YayaQueueAPI = {}
assert(loadstring(
    (assert(source:match("(function YayaQueueAPI%.GetReservedItemQuantity%(itemID%).-\nend)\n"),
        "GetReservedItemQuantity introuvable")),
    "reserved-quantity"))()

queueReservations = { [247719] = 10, [999] = 4 }
equals("la file expose les unites reservees d'un objet", YayaQueueAPI.GetReservedItemQuantity(247719), 10)
equals("... zero pour un objet que la file ne reserve pas", YayaQueueAPI.GetReservedItemQuantity(247725), 0)
equals("... zero pour un identifiant invalide", YayaQueueAPI.GetReservedItemQuantity(nil), 0)

local invalidations = 0
_G.YayaWeeklyTrackerAPI = { InvalidateFinishingMerges = function() invalidations = invalidations + 1 end }
state.finishingReservationSignature = nil
equals("premiere lecture : YWT est prevenu", YQQuality.NotifyFinishingReservations(), true)
equals("... une fois", invalidations, 1)
equals("signature inchangee : personne n'est derange", YQQuality.NotifyFinishingReservations(), false)
equals("... aucune invalidation de plus", invalidations, 1)
queueReservations = { [247719] = 5 }
equals("une reservation de finition change : YWT est prevenu", YQQuality.NotifyFinishingReservations(), true)
queueReservations = { [247719] = 5, [999] = 50 }
equals("une reservation sans rapport avec les finitions ne derange pas YWT",
    YQQuality.NotifyFinishingReservations(), false)
_G.YayaWeeklyTrackerAPI = nil
equals("YWT absent : rien a faire", YQQuality.NotifyFinishingReservations(), false)
equals("RefreshAll previent YWT sans jamais casser le rafraichissement",
    source:find("pcall(YQQuality.NotifyFinishingReservations)", 1, true) ~= nil, true)

-- ---------------------------------------------------------------------------
section("Branchement dans la source")
-- ---------------------------------------------------------------------------

local showHandler = Extract("TradeSkillShow", "(handle%.TradeSkillShow = function.-\nend)\n")
equals("TRADE_SKILL_SHOW lit le drapeau de facon synchrone, avant le rappel differe",
    (showHandler:find("local programmaticOpen = YQQuality.IsProgrammaticTradeSkillOpen()", 1, true) or 0)
        < (showHandler:find("C_Timer.After(0, function()", 1, true) or 0), true)
equals("... et abandonne les automatismes d'ouverture dans ce cas",
    showHandler:find('skip reason=programmatic-open', 1, true) ~= nil, true)
local startAlchemy = Extract("StartAlchemyAutoQueue",
    "(local function StartAlchemyAutoQueue%(%).-\nend)\n")
equals("la file Alchimie ignore une ouverture programmatique",
    startAlchemy:find("YQQuality.IsProgrammaticTradeSkillOpen()", 1, true) ~= nil, true)
equals("... et ne se relance pas apres une passe aboutie dans la meme ouverture",
    startAlchemy:find("autoQueue.completedProfessionID == professionID", 1, true) ~= nil, true)
local favoriteAPI = Extract("QueueFavoriteConcentration",
    "(function YayaQueueAPI%.QueueFavoriteConcentration%(professionID%).-\nend)\n")
equals("le dump du favori ignore une ouverture programmatique",
    favoriteAPI:find("YQQuality.IsProgrammaticTradeSkillOpen()", 1, true) ~= nil, true)
equals("... sans marquer le metier comme traite",
    (favoriteAPI:find("IsProgrammaticTradeSkillOpen", 1, true) or 0)
        < (favoriteAPI:find("handledFavoriteByProfession", 1, true) or 0), true)
local firstCraftAPI = Extract("QueueFirstCraftsAfterProfessionOpen",
    "(function YayaQueueAPI%.QueueFirstCraftsAfterProfessionOpen%(%).-\nend)\n")
equals("le scan first craft ignore une ouverture programmatique",
    firstCraftAPI:find("YQQuality.IsProgrammaticTradeSkillOpen()", 1, true) ~= nil, true)
local closeHandler = Extract("TradeSkillClose", "(handle%.TradeSkillClose = function.-\nend)\n")
equals("la fermeture du metier remet le marqueur « favori traite » a zero",
    closeHandler:find("handledFavoriteByProfession = {}", 1, true) ~= nil, true)
equals("... et celui de la file Alchimie",
    closeHandler:find("completedProfessionID = nil", 1, true) ~= nil, true)
local tryFavorite = Extract("TryAutoQueueFavoriteConcentration",
    "(YQQuality%.TryAutoQueueFavoriteConcentration = function%(%).-\nend)\n")
equals("plus de garde « deja en file » qui bloquait le dump a la reouverture",
    tryFavorite:find("alreadyQueued", 1, true), nil)

-- ---------------------------------------------------------------------------
section("Branchement dans la source : cooldown")
-- ---------------------------------------------------------------------------

equals("le bouton Next lit la limite avant de proposer un craft",
    source:find("local craftLimit = state.GetEntryCraftLimit(entry)", 1, true) ~= nil, true)
equals("... et affiche « Next: cooldown » desactive",
    source:find('"Next: cooldown"', 1, true) ~= nil, true)
equals("le clic relit la limite avant d'armer phiole ou remboursement",
    source:find("local craftLimit = state.GetEntryCraftLimit(stateInfo.entry)", 1, true) ~= nil, true)
equals("le tri recoit le predicat de blocage",
    source:find("isCraftBlocked = function(entry)", 1, true) ~= nil, true)
equals("un echec de cast alimente le disjoncteur",
    source:find("state.NoteCraftFailure(abortedSpellID)", 1, true) ~= nil, true)
equals("un craft abouti remet la serie a zero",
    source:find("state.ClearCraftFailure(pendingEntry.recipeID)", 1, true) ~= nil, true)
equals("le dump est plafonne par les charges",
    source:find("state.GetRecipeCooldownCap(recipeID)", 1, true) ~= nil, true)

print(("\n%d OK, %d echec(s)"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
