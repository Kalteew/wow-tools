-- Regression : la passe Alchimie a l'ouverture du metier ne doit ni se relancer
-- en boucle ni se croire terminee sur une liste de recettes encore partielle.
--
-- Cas reels : (1) YayaWeeklyTracker ouvre le metier au login pour amorcer ses
-- donnees ; les cooldowns ne sont pas charges, la passe mettait « Bouquet x2 » en
-- file sur un repli faux. (2) La passe se relancait a chaque TRADE_SKILL_LIST_
-- UPDATE. (3) Une passe « reussie » sur une liste partielle bloquait toute
-- relance jusqu'a la fermeture.
--
-- Le test extrait de la source le point d'entree (StartAlchemyAutoQueue), la
-- planification (ScheduleAutoQueueAlchemy) et la confirmation de passe, puis
-- les rejoue sur des minuteries et des passes simulees.
--
-- Usage : lua5.1 Tests/test_alchemy_pass.lua (depuis addons/YayaQueue)

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

local debugLines = {}
function DebugPrint(message) debugLines[#debugLines + 1] = message end

local timers = {}
C_Timer = { After = function(delay, fn) timers[#timers + 1] = { delay = delay, fn = fn } end }

local function runTimers()
    -- Rejoue les minuteries en attente (chaque tour peut en armer d'autres).
    local guard = 0
    while #timers > 0 and guard < 200 do
        guard = guard + 1
        local timer = table.remove(timers, 1)
        timer.fn()
    end
end

local programmatic = false
YQQuality = {
    IsProgrammaticTradeSkillOpen = function() return programmatic end,
}
local professionID = 171
state = {
    alchemyAutoQueue = {},
    GetCurrentProfessionID = function() return professionID end,
}
alchemyAuto = {
    IsAlchemyProfession = function(id) return id == 171 end,
}

-- Passe simulee : une suite de resultats {resultat, nombre de recettes}.
local passes, passCalls = {}, 0
alchemyAuto.QueueBouquetAndRecycling = function()
    passCalls = passCalls + 1
    local step = table.remove(passes, 1)
    if step == nil then step = { true, 10 } end
    if step == "error" then error("boom") end
    state.alchemyAutoQueue.passRecipeCount = step[2]
    return step[1]
end

assert(loadstring(
    Extract("ConfirmPass", "(alchemyAuto%.ConfirmPass = function%(autoQueue%).-\nend)\n")
        .. "\n"
        .. Extract("ScheduleAutoQueueAlchemy",
            "(function YQQuality%.ScheduleAutoQueueAlchemy%(delay%).-\nend)\n")
        .. "\n"
        .. (Extract("StartAlchemyAutoQueue",
            "(local function StartAlchemyAutoQueue%(%).-\nend)\n"):gsub("^local function ", "function ")),
    "alchemy-pass"))()

local function reset()
    state.alchemyAutoQueue = {}
    timers, debugLines, passes, passCalls = {}, {}, {}, 0
    programmatic = false
    professionID = 171
end

-- ---------------------------------------------------------------------------
section("Confirmation de passe : le meme nombre de recettes deux fois de suite")
-- ---------------------------------------------------------------------------

local queue = {}
equals("aucun nombre de recettes connu : pas confirmee", alchemyAuto.ConfirmPass(queue), false)
queue.passRecipeCount = 10
equals("premiere passe : pas encore confirmee", alchemyAuto.ConfirmPass(queue), false)
equals("... la meme liste a la passe suivante : confirmee", alchemyAuto.ConfirmPass(queue), true)
queue.passRecipeCount = 12
equals("la liste a grandi : a reconfirmer", alchemyAuto.ConfirmPass(queue), false)
equals("... puis stable", alchemyAuto.ConfirmPass(queue), true)

-- ---------------------------------------------------------------------------
section("Ouverture du metier : une passe, confirmee a la seconde")
-- ---------------------------------------------------------------------------

reset()
StartAlchemyAutoQueue()
runTimers()
equals("une passe est lancee a l'ouverture", passCalls, 1)
equals("... elle n'est pas confirmee : pas de marqueur de fin",
    state.alchemyAutoQueue.completedProfessionID, nil)
equals("... mais plus rien n'est en attente", state.alchemyAutoQueue.pendingProfessionID, false)
equals("... et le journal le dit",
    (table.concat(debugLines, "\n")):find("pass-unconfirmed", 1, true) ~= nil, true)

StartAlchemyAutoQueue()
runTimers()
equals("la rafale d'evenements suivante relance une passe", passCalls, 2)
equals("... qui voit le meme nombre de recettes : confirmee",
    state.alchemyAutoQueue.completedProfessionID, 171)

StartAlchemyAutoQueue()
runTimers()
equals("ensuite plus aucune relance (rafale LIST_UPDATE / DETAILS_UPDATE)", passCalls, 2)

-- ---------------------------------------------------------------------------
section("Liste partielle : la passe suivante rattrape")
-- ---------------------------------------------------------------------------

reset()
passes = { { true, 4 }, { true, 10 }, { true, 10 } }
StartAlchemyAutoQueue()
runTimers()
equals("premiere passe sur 4 recettes : pas de marqueur", state.alchemyAutoQueue.completedProfessionID, nil)
StartAlchemyAutoQueue()
runTimers()
equals("deuxieme passe sur 10 recettes : toujours pas (la liste a change)",
    state.alchemyAutoQueue.completedProfessionID, nil)
StartAlchemyAutoQueue()
runTimers()
equals("troisieme passe, liste stable : confirmee", state.alchemyAutoQueue.completedProfessionID, 171)
equals("... trois passes en tout", passCalls, 3)

-- ---------------------------------------------------------------------------
section("Donnees pas pretes : on reessaie, sans rien conclure")
-- ---------------------------------------------------------------------------

reset()
passes = { { nil }, { nil }, { true, 10 } }
StartAlchemyAutoQueue()
runTimers()
equals("deux attentes puis une passe : trois appels", passCalls, 3)
equals("... la passe aboutie n'est pas encore confirmee",
    state.alchemyAutoQueue.completedProfessionID, nil)

reset()
for _ = 1, 40 do passes[#passes + 1] = { nil } end
StartAlchemyAutoQueue()
runTimers()
equals("des donnees qui n'arrivent jamais : 30 tentatives puis on arrete", passCalls, 30)
equals("... sans marqueur de fin", state.alchemyAutoQueue.completedProfessionID, nil)
equals("... et plus rien d'arme", state.alchemyAutoQueue.pendingProfessionID, false)

-- ---------------------------------------------------------------------------
section("Une passe en erreur ne laisse rien d'arme")
-- ---------------------------------------------------------------------------

reset()
passes = { "error" }
StartAlchemyAutoQueue()
runTimers()
equals("l'erreur est absorbee : un seul appel, pas de reessai", passCalls, 1)
equals("... pas de marqueur de fin", state.alchemyAutoQueue.completedProfessionID, nil)
equals("... plus rien en attente", state.alchemyAutoQueue.pendingProfessionID, false)
equals("... l'erreur est tracee",
    (table.concat(debugLines, "\n")):find("alchemy-auto failed", 1, true) ~= nil, true)

-- ---------------------------------------------------------------------------
section("Ouverture programmatique et autres metiers")
-- ---------------------------------------------------------------------------

reset()
programmatic = true
StartAlchemyAutoQueue()
runTimers()
equals("ouverture amorcee par YWT : aucune passe", passCalls, 0)
equals("... rien n'est marque en attente", state.alchemyAutoQueue.pendingProfessionID, nil)
equals("... ni termine", state.alchemyAutoQueue.completedProfessionID, nil)
programmatic = false
StartAlchemyAutoQueue()
runTimers()
equals("la vraie ouverture qui suit lance bien la passe", passCalls, 1)

reset()
professionID = 164 -- forge
state.alchemyAutoQueue.pendingProfessionID = false
StartAlchemyAutoQueue()
runTimers()
equals("autre metier : aucune passe", passCalls, 0)
equals("... l'etat « en attente » est remis a zero", state.alchemyAutoQueue.pendingProfessionID, nil)

-- ---------------------------------------------------------------------------
section("Fermeture du metier : la passe suivante repart de zero")
-- ---------------------------------------------------------------------------

local closeHandler = Extract("TradeSkillClose", "(handle%.TradeSkillClose = function.-\nend)\n")
for _, literal in ipairs({
    "completedProfessionID = nil",
    "passRecipeCount = nil",
    "confirmedRecipeCount = nil",
}) do
    equals("la fermeture efface " .. literal,
        closeHandler:find("state.alchemyAutoQueue." .. literal, 1, true) ~= nil, true)
end

print("")
print(("%d OK, %d echec(s)"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
