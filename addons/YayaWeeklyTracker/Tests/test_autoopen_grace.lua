-- Verifie la politique de reprise de l'ouverture automatique des conteneurs.
--
-- Il n'existe que deux categories, et une seule est terminale :
--
--  1. le client refuse le call (ADDON_ACTION_BLOCKED / ADDON_ACTION_FORBIDDEN).
--     Blacklist des la premiere erreur, plus jamais de tentative automatique.
--  2. tout le reste. Un echec n'y decrit que l'indisponibilite du personnage
--     (loot en retard, sacs pleins), jamais l'objet : apres 3 echecs on laisse
--     passer une grace de 90 s, puis on boucle, indefiniment, jusqu'a
--     l'ouverture.
--
-- Il n'y a surtout pas de troisieme categorie qui rangerait un conteneur
-- ouvrable pour 24 h parce que les sacs etaient pleins : c'est la regression que
-- cette suite garde.
--
-- Ce que ce test ne couvre pas : le clic sur le bouton securise (il depend du
-- moteur secure du client) et les vraies mesures de frame.

dofile("Tests/wow_env.lua")

local GRACE_SECONDS = 90
local MAX_FAILURES = 3

--------------------------------------------------------------------------------
-- Horloge et timers pilotables
--------------------------------------------------------------------------------

-- Le module lit deux horloges : GetTime() (flottant, pour les delais) et time()
-- (secondes entieres, pour la peremption des verdicts). Les deux doivent avancer
-- ensemble, sinon la grace n'expire jamais.
local monotonic = 1000.0
local unixTime = 1700000000

function GetTime()
    return monotonic
end

function time()
    return unixTime
end

local timers = {}

C_Timer.NewTimer = function(delay, callback)
    local entry = { delay = tonumber(delay) or 0, callback = callback }
    timers[#timers + 1] = entry
    return {
        Cancel = function()
            entry.cancelled = true
        end,
    }
end

-- Avance les deux horloges puis vide la file des timers, plusieurs tours car un
-- timer peut en reprogrammer un autre. Comme le harnais existant, on declenche
-- tous les timers en attente sans respecter leur delai : c'est la peremption lue
-- sur time() qui porte la regle testee, pas l'ordonnancement.
local function Advance(seconds, rounds)
    monotonic = monotonic + seconds
    unixTime = unixTime + math.floor(seconds)
    for _ = 1, rounds or 8 do
        local pending = timers
        timers = {}
        for _, entry in ipairs(pending) do
            if not entry.cancelled then
                local ok, err = pcall(entry.callback)
                if not ok then
                    error("timer :: " .. tostring(err), 0)
                end
            end
        end
    end
end

-- Une tentative echouee n'est constatee qu'une fois PENDING_TIMEOUT_SECONDS
-- (1,20 s) ecoule : un cycle complet demande donc plus d'une seconde.
local function BurnCycles(count)
    for _ = 1, count do
        Advance(2)
    end
end

--------------------------------------------------------------------------------
-- Scenario
--------------------------------------------------------------------------------

-- Charge une instance neuve du module sur un sac contenant un seul conteneur
-- suivi, dont l'ouverture ne consomme rien : chaque tentative expire donc.
--
-- Chaque scenario prend son propre itemID et repart d'une file de timers et
-- d'une liste de frames vides : les instances precedentes n'ont plus ni timer
-- programme ni evenement a recevoir, elles restent dormantes.
local function StartScenario(itemID, presetForbidden)
    timers = {}
    ALL_FRAMES = {}

    local attempts = 0

    C_Container.GetContainerNumSlots = function(bagID)
        return bagID == 0 and 1 or 0
    end
    C_Container.GetContainerItemID = function(bagID, slotID)
        if bagID == 0 and slotID == 1 then
            return itemID
        end
        return nil
    end
    C_Container.GetContainerItemInfo = function(bagID, slotID)
        if bagID == 0 and slotID == 1 then
            -- hasLoot est le positif certain de IsItemLikelyOpenable : il evite
            -- de dependre du cache d'objets du client dans ce test.
            return { itemID = itemID, stackCount = 1, hasLoot = true }
        end
        return nil
    end
    C_Container.UseContainerItem = function()
        attempts = attempts + 1
    end

    -- autoOpenCacheVersion doit valoir la version courante, sinon EnsureOptions
    -- repart de zero et effacerait l'etat prepare par le scenario.
    YayaWeeklyTrackerAccountDB = {
        autoOpenContainers = true,
        autoOpenCacheVersion = 2,
        autoOpenFailed = {},
        autoOpenForbidden = presetForbidden or {},
        autoOpenSuccessfulContainers = {},
    }

    local button = CreateFrame("Button", "TestAutoOpenActionButton")

    -- Le pont vers le fichier principal, pose avant le chargement : le module
    -- fait `_G.YayaWeeklyTrackerAutoOpen or {}` puis y ajoute sa propre surface.
    _G.YayaWeeklyTrackerAutoOpen = {
        GetAutoOpenContainerItemIDs = function()
            return { [itemID] = true }
        end,
        GetActionButton = function()
            return button
        end,
        RequestTrackerRefresh = function() end,
        DebugLog = function() end,
    }

    local chunk, compileError = loadfile("YayaWeeklyTrackerAutoOpen.lua")
    if not chunk then
        print("ECHEC compilation YayaWeeklyTrackerAutoOpen.lua :: " .. tostring(compileError))
        os.exit(2)
    end
    local ok, runtimeError = pcall(chunk, "YayaWeeklyTracker", {})
    if not ok then
        print("ECHEC chargement YayaWeeklyTrackerAutoOpen.lua :: " .. tostring(runtimeError))
        os.exit(3)
    end

    return {
        Attempts = function()
            return attempts
        end,
        Failed = function()
            return YayaWeeklyTrackerAccountDB.autoOpenFailed[itemID]
        end,
        Forbidden = function()
            return YayaWeeklyTrackerAccountDB.autoOpenForbidden[itemID]
        end,
        ForbiddenEntry = function(otherItemID)
            return YayaWeeklyTrackerAccountDB.autoOpenForbidden[otherItemID]
        end,
    }
end

--------------------------------------------------------------------------------
-- Assertions
--------------------------------------------------------------------------------

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

local function GraceRemaining(entry)
    if type(entry) ~= "table" then
        return nil
    end
    return tonumber(entry.expiresAt) - unixTime
end

--------------------------------------------------------------------------------
print("Conteneur non blackliste : grace de 90 s puis reprise, sans fin")
--------------------------------------------------------------------------------

local retried = StartScenario(999001)

-- Le chargement declenche Refresh(), donc un premier scan. Il faut un cycle de
-- plus que MAX_FAILURES pour que la troisieme expiration soit constatee.
BurnCycles(MAX_FAILURES + 1)

local beforeGrace = retried.Attempts()
Check("les trois tentatives automatiques ont eu lieu", beforeGrace == MAX_FAILURES, beforeGrace)

Check("un refus transitoire est enregistre", type(retried.Failed()) == "table")
Check(
    "le refus dure une grace, pas un rangement de 24 h",
    GraceRemaining(retried.Failed()) == GRACE_SECONDS,
    GraceRemaining(retried.Failed()) or "absent"
)
Check("le conteneur n'est pas blackliste", retried.Forbidden() == nil)

-- Pendant la grace, aucune tentative : l'objet attend sur le bouton securise.
BurnCycles(3)
Check("aucune nouvelle tentative pendant la grace", retried.Attempts() == beforeGrace, retried.Attempts())

-- Grace passee, l'ouverture automatique doit repartir d'elle-meme.
Advance(GRACE_SECONDS + 5)
Check(
    "la grace expiree relance l'ouverture automatique",
    retried.Attempts() > beforeGrace,
    retried.Attempts()
)

-- Et le cycle se rejoue sans fin : trois tentatives, grace, trois de plus.
BurnCycles(MAX_FAILURES + 1)
local afterSecondCycle = retried.Attempts()
Check(
    "le second cycle consomme aussi ses trois tentatives",
    afterSecondCycle >= MAX_FAILURES * 2,
    afterSecondCycle
)

Advance(GRACE_SECONDS + 5)
Check("une seconde grace expiree relance encore", retried.Attempts() > afterSecondCycle, retried.Attempts())

-- Le troisieme tour prouve qu'aucun compteur cumulatif ne finit par condamner
-- l'objet : la boucle est bien infinie, pas un nombre de reprises fini.
BurnCycles(MAX_FAILURES + 1)
local afterThirdCycle = retried.Attempts()
Advance(GRACE_SECONDS + 5)
Check("un troisieme tour relance toujours", retried.Attempts() > afterThirdCycle, retried.Attempts())

--------------------------------------------------------------------------------
print("Conteneur refuse par le client : blacklist des la premiere erreur")
--------------------------------------------------------------------------------

local blocked = StartScenario(999003)

-- Un seul tour de timers suffit a poser la premiere tentative et son pending.
Advance(0)
Check("une premiere tentative a eu lieu", blocked.Attempts() == 1, blocked.Attempts())

-- Le client refuse l'action protegee, sur le nom de cet addon.
FireEvent("ADDON_ACTION_FORBIDDEN", "YayaWeeklyTracker", "UseContainerItem")

Check("le conteneur est blackliste", type(blocked.Forbidden()) == "table")
Check(
    "le verdict dur efface le refus transitoire",
    blocked.Failed() == nil,
    blocked.Failed() and "encore present" or nil
)

-- Aucune reprise, ni tout de suite, ni apres la duree d'une grace, ni apres
-- plusieurs cycles : le refus porte sur l'objet, definitivement.
BurnCycles(MAX_FAILURES + 2)
Advance(GRACE_SECONDS + 5)
BurnCycles(2)
Check(
    "aucune tentative automatique apres la blacklist",
    blocked.Attempts() == 1,
    blocked.Attempts()
)

--------------------------------------------------------------------------------
print("Blocage d'un widget de l'addon : aucun verdict sur le conteneur")
--------------------------------------------------------------------------------

-- Le cas qui a casse les Weathered Mysterious Satchel en jeu le 2026-09-09.
-- OpenNextContainer pose le pending, puis mute son propre bouton securise avant
-- d'appeler UseContainerItem : un blocage de ce widget tombait dans la fenetre
-- du pending et blacklistait un conteneur parfaitement ouvrable.
local selfBlocked = StartScenario(999004)

Advance(0)
Check("une premiere tentative a eu lieu", selfBlocked.Attempts() == 1, selfBlocked.Attempts())

FireEvent(
    "ADDON_ACTION_BLOCKED",
    "YayaWeeklyTracker",
    "YayaWeeklyTrackerAutoOpenButton:SetEnabled()"
)

Check(
    "un blocage de notre propre bouton ne blackliste pas le conteneur",
    selfBlocked.Forbidden() == nil,
    selfBlocked.Forbidden() and "blackliste a tort" or nil
)

-- L'echec doit rester transitoire : trois tentatives, grace, puis reprise.
BurnCycles(MAX_FAILURES + 1)
local selfBlockedBeforeGrace = selfBlocked.Attempts()
-- Borne large plutot qu'egalite : la grace a ete posee quelques secondes plus
-- tot dans ce scenario, qui consomme un cycle de plus. Ce qui compte est
-- l'ordre de grandeur, une grace contre un rangement de 24 h.
local selfBlockedGrace = GraceRemaining(selfBlocked.Failed())
Check(
    "le refus reste transitoire, sur l'echelle d'une grace",
    selfBlockedGrace ~= nil
        and selfBlockedGrace > GRACE_SECONDS - 10
        and selfBlockedGrace <= GRACE_SECONDS,
    selfBlockedGrace or "absent"
)

Advance(GRACE_SECONDS + 5)
Check(
    "le conteneur repart en automatique apres la grace",
    selfBlocked.Attempts() > selfBlockedBeforeGrace,
    selfBlocked.Attempts()
)

--------------------------------------------------------------------------------
print("Audit au chargement : les blacklists mal attribuees sont retirees")
--------------------------------------------------------------------------------

-- Le verdict dur est terminal par conception : sans cet audit, les entrees deja
-- ecrites en jeu survivaient a tous les /reload.
local LEGIT_ITEM_ID = 999900
local repaired = StartScenario(999005, {
    [999005] = {
        itemID = 999005,
        blockedCount = 1,
        lastEvent = "ADDON_ACTION_BLOCKED",
        lastFunction = "YayaWeeklyTrackerAutoOpenButton:SetEnabled()",
    },
    [LEGIT_ITEM_ID] = {
        itemID = LEGIT_ITEM_ID,
        blockedCount = 1,
        lastEvent = "ADDON_ACTION_FORBIDDEN",
        lastFunction = "UNKNOWN()",
    },
})

Check(
    "l'entree attribuee a notre bouton est retiree",
    repaired.Forbidden() == nil,
    repaired.Forbidden() and "encore blacklistee" or nil
)
Check(
    "un vrai refus du client est conserve",
    type(repaired.ForbiddenEntry(LEGIT_ITEM_ID)) == "table"
)

Advance(0)
Check(
    "le conteneur repare est retente en automatique",
    repaired.Attempts() >= 1,
    repaired.Attempts()
)

--------------------------------------------------------------------------------

if UNCAUGHT and #UNCAUGHT > 0 then
    for _, message in ipairs(UNCAUGHT) do
        print("  ECHEC erreur non rattrapee :: " .. message)
    end
    failures = failures + #UNCAUGHT
end

print(("%d reussite(s), %d echec(s)"):format(checks - failures, failures))
if failures > 0 then
    os.exit(1)
end
