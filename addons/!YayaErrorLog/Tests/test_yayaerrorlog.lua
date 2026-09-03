-- Tests unitaires de YayaErrorLog, executes hors du jeu avec Lua 5.1.
--
-- Seule la logique pure est exercee : normalisation des messages, extraction de
-- la ligne fautive dans une pile, regroupement par signature, bornage du
-- journal. L'installation en jeu (frame, gestionnaire d'erreurs, commandes) est
-- volontairement inatteignable ici, faute de CreateFrame : c'est aussi ce que
-- verifie le dernier test.
--
-- Usage : lua5.1 Tests/test_yayaerrorlog.lua   (depuis addons/!YayaErrorLog)

-- ---------------------------------------------------------------------------
-- Doublures de l'API WoW
-- ---------------------------------------------------------------------------

_G.time = os.time
_G.date = os.date

-- ---------------------------------------------------------------------------
-- Mini harnais
-- ---------------------------------------------------------------------------

local passed, failed = 0, 0

local function check(name, condition, detail)
    if condition then
        passed = passed + 1
        print(("  OK    %s"):format(name))
    else
        failed = failed + 1
        print(("  ECHEC %s%s"):format(name, detail and (" -> " .. tostring(detail)) or ""))
    end
end

local function equals(name, actual, expected)
    check(name, actual == expected, ("attendu %s, obtenu %s"):format(tostring(expected), tostring(actual)))
end

-- ---------------------------------------------------------------------------
-- Chargement du module
-- ---------------------------------------------------------------------------

local chunk = assert(loadfile("YayaErrorLog.lua"))
chunk("!YayaErrorLog")
local Log = _G.YayaErrorLog
check("le module s'expose en global", type(Log) == "table")

-- ---------------------------------------------------------------------------
-- Normalisation des messages
-- ---------------------------------------------------------------------------

print("NormalizeMessage")

equals(
    "les adresses de table sont neutralisees",
    Log.NormalizeMessage("attempt to index table: 0x1a2b3c"),
    Log.NormalizeMessage("attempt to index table: 0xdeadbeef")
)

equals(
    "les nombres variables sont neutralises",
    Log.NormalizeMessage("Core.lua:107: boom"),
    Log.NormalizeMessage("Core.lua:412: boom")
)

check(
    "deux fautes differentes restent distinctes",
    Log.NormalizeMessage("attempt to call a nil value") ~= Log.NormalizeMessage("attempt to compare a secret value")
)

-- ---------------------------------------------------------------------------
-- Lecture de la pile
-- ---------------------------------------------------------------------------

print("FirstAddonFrame")

local STACK = table.concat({
    "[C]: in function `UnitPower'",
    "Interface/AddOns/AbundanceTracker/Core.lua:358: in function `OnPowerUpdate'",
    "Interface/AddOns/AbundanceTracker/Core.lua:418: in function <Interface/AddOns/AbundanceTracker/Core.lua:426>",
}, "\n")

equals(
    "la premiere ligne d'addon est retenue",
    Log.FirstAddonFrame(STACK),
    "Interface/AddOns/AbundanceTracker/Core.lua:358"
)

equals(
    "les antislashs sont normalises",
    Log.FirstAddonFrame("Interface\\AddOns\\Foo\\Bar.lua:12: in function `Baz'"),
    "Interface/AddOns/Foo/Bar.lua:12"
)

-- Format reel du client : le chemin est encadre de crochets.
equals(
    "le crochet fermant du client est retire",
    Log.FirstAddonFrame("[Interface/AddOns/AbundanceTracker/Core.lua]:387: in function 'TryRegisterEvents'"),
    "Interface/AddOns/AbundanceTracker/Core.lua:387"
)

equals("une pile sans addon ne renvoie rien", Log.FirstAddonFrame("[C]: ?"), nil)
equals("une pile absente ne renvoie rien", Log.FirstAddonFrame(nil), nil)

-- Cas reel : le gestionnaire d'erreurs du journal ouvre la pile. Sans filtrage,
-- chaque incident serait impute au journal lui-meme.
local STACK_WITH_SELF = table.concat({
    "Interface/AddOns/!YayaErrorLog/YayaErrorLog.lua:340: in function <...>",
    "[C]: in function `error'",
    "Interface/AddOns/AbundanceTracker/Core.lua:107: in function `ScanBlessing'",
}, "\n")

equals(
    "les frames du journal sont ignorees",
    Log.FirstAddonFrame(STACK_WITH_SELF),
    "Interface/AddOns/AbundanceTracker/Core.lua:107"
)

equals(
    "une pile ne contenant que le journal ne designe personne",
    Log.FirstAddonFrame("Interface/AddOns/!YayaErrorLog/YayaErrorLog.lua:12: in function <...>"),
    nil
)

-- ---------------------------------------------------------------------------
-- Signature
-- ---------------------------------------------------------------------------

print("BuildSignature")

equals(
    "deux occurrences du meme bug partagent leur signature",
    Log.BuildSignature("lua-error", "Core.lua:358: bad argument"),
    Log.BuildSignature("lua-error", "Core.lua:358: bad argument")
)

check(
    "deux messages differents donnent deux signatures",
    Log.BuildSignature("lua-error", "attempt to call a nil value")
        ~= Log.BuildSignature("lua-error", "attempt to index a nil value")
)

check(
    "deux types differents donnent deux signatures",
    Log.BuildSignature("lua-error", "boom") ~= Log.BuildSignature("ADDON_ACTION_BLOCKED", "boom")
)

check("la signature est tronquee", #Log.BuildSignature("lua-error", string.rep("x", 500)) <= 200)

-- ---------------------------------------------------------------------------
-- Journal borne, repli sans YayaCore
-- ---------------------------------------------------------------------------

print("PushBounded / ReadBounded sans YayaCore")

local store = {}
for index = 1, 7 do
    Log.PushBounded(store, index, 3)
end
equals("le journal ne depasse pas sa limite", #store, 3)

local read = Log.ReadBounded(store)
equals("la relecture est chronologique (debut)", read[1], 5)
equals("la relecture est chronologique (fin)", read[3], 7)

local tail = Log.ReadBounded(store, 2)
equals("la relecture partielle garde les plus recents", tail[1], 6)
equals("la relecture partielle s'arrete au compte demande", #tail, 2)

-- ---------------------------------------------------------------------------
-- Delegation a YayaCore quand il est charge
-- ---------------------------------------------------------------------------

print("Delegation a YayaCore")

local delegated = 0
_G.YayaCore = {
    RingBuffer = {
        Push = function(target, entry)
            delegated = delegated + 1
            target[#target + 1] = entry
        end,
        Read = function(target)
            return target
        end,
    },
}

local shared = {}
Log.PushBounded(shared, "a", 10)
equals("l'implementation de YayaCore est preferee", delegated, 1)
equals("l'entree passe bien par YayaCore", Log.ReadBounded(shared)[1], "a")

_G.YayaCore = nil

-- ---------------------------------------------------------------------------
-- Regroupement des incidents
-- ---------------------------------------------------------------------------

print("Record")

local db = Log.SetStore({ entries = {}, counters = {}, sessions = {} })

for _ = 1, 10 do
    Log.Record("lua-error", { message = "Core.lua:358: bad argument", stack = STACK })
end

local signature = Log.BuildSignature("lua-error", "Core.lua:358: bad argument")
equals("les occurrences sont comptees", db.counters[signature].count, 10)
equals("le detail est echantillonne", #db.entries, 3)
equals(
    "le compteur retient la ligne fautive",
    db.counters[signature].frame,
    "Interface/AddOns/AbundanceTracker/Core.lua:358"
)

Log.Record("ADDON_ACTION_FORBIDDEN", {
    addon = "AbundanceTracker",
    protectedFunction = "UseAction()",
    stack = STACK,
})
local ordered = Log.OrderedCounters()
equals("les incidents sont classes par frequence", ordered[1].counter.count, 10)
equals("le second incident est suivi aussi", #ordered, 2)

-- ---------------------------------------------------------------------------
-- Cout de la capture
-- ---------------------------------------------------------------------------

-- Le vrai enjeu de la signature sans pile. Le client facture a cet addon le
-- temps passe dans son gestionnaire d'erreurs, quel que soit l'addon fautif :
-- une faute levee a chaque image doit rester comptee sans que sa pile soit
-- capturee a chaque fois, faute de quoi le client suspend le journal lui-meme
-- (« insecure scripts exceeded execution limit »).

print("Capture paresseuse du contexte")

local lazy = Log.SetStore({ entries = {}, counters = {}, sessions = {} })
local enriched = 0
local function enrich(fields)
    enriched = enriched + 1
    fields.stack = STACK
    fields.zone = "Silvermoon City"
end

for _ = 1, 50 do
    Log.Record("lua-error", { message = "Core.lua:358: bad argument" }, enrich)
end

local lazySignature = Log.BuildSignature("lua-error", "Core.lua:358: bad argument")
equals("les 50 occurrences sont comptees", lazy.counters[lazySignature].count, 50)
equals("le contexte n'est collecte que pour les exemplaires conserves", enriched, 3)
equals("le detail reste echantillonne", #lazy.entries, 3)
equals(
    "la ligne fautive vient du contexte collecte",
    lazy.counters[lazySignature].frame,
    "Interface/AddOns/AbundanceTracker/Core.lua:358"
)
equals("le contexte enrichit bien l'entree", Log.ReadBounded(lazy.entries)[1].zone, "Silvermoon City")

-- Un incident jamais conserve ne coute donc rien de plus qu'un increment.
local other = 0
for _ = 1, 20 do
    Log.Record("ADDON_ACTION_BLOCKED", { protectedFunction = "UseAction()" }, function(fields)
        other = other + 1
        fields.stack = STACK
    end)
end
equals("chaque signature dispose de ses propres exemplaires", other, 3)

print("Describe")

local described = Log.Describe(Log.NewEntry("ADDON_ACTION_FORBIDDEN", {
    addon = "AbundanceTracker",
    protectedFunction = "UseAction()",
    stack = STACK,
}))
check("la description nomme l'addon", described:find("AbundanceTracker", 1, true) ~= nil, described)
check("la description nomme la fonction protegee", described:find("UseAction()", 1, true) ~= nil, described)
check(
    "la description nomme la ligne fautive",
    described:find("Core.lua:358", 1, true) ~= nil,
    described
)

-- ---------------------------------------------------------------------------
-- Plafond du nombre d'incidents distincts
-- ---------------------------------------------------------------------------

print("Plafond des signatures")

local capped = Log.SetStore({ entries = {}, counters = {}, sessions = {} })
for index = 1, 130 do
    -- Un message distinct par tour. La variation passe par des lettres : les
    -- chiffres sont neutralises par la normalisation, et la pile n'entre plus
    -- dans la signature.
    Log.Record("lua-error", { message = "boom " .. string.rep("z", index) })
end
check("le plafond est applique", capped.droppedSignatures and capped.droppedSignatures > 0, capped.droppedSignatures)
equals("aucun incident distinct au-dela du plafond", #Log.OrderedCounters(), 120)

-- ---------------------------------------------------------------------------
-- Budget de capture
-- ---------------------------------------------------------------------------

-- Dernier garde-fou, et le seul qui tienne quand la rafale change de message a
-- chaque occurrence : l'echantillonnage par signature ne borne alors rien, et
-- chaque incident reclamerait sa pile. Le budget ne s'active qu'en presence
-- d'une horloge, d'ou l'injection de GetTime pour cette section.

print("Budget de capture")

local frozen = 1000
_G.GetTime = function()
    return frozen
end

local bursty = Log.SetStore({ entries = {}, counters = {}, sessions = {} })
local captured = 0
local function burstEnrich(fields)
    captured = captured + 1
    fields.stack = STACK
end

for index = 1, 40 do
    -- Un message distinct par tour : sans budget, chacun capturerait sa pile.
    Log.Record("lua-error", { message = "boom " .. string.rep("q", index) }, burstEnrich)
end

equals("le budget plafonne les captures d'une meme fenetre", captured, 8)
equals("les incidents restent tous comptes", #Log.OrderedCounters(), 40)
equals("les captures refusees sont rapportees", bursty.throttled, 32)

frozen = frozen + 2
Log.Record("lua-error", { message = "boom hors fenetre" }, burstEnrich)
equals("la fenetre suivante rouvre le budget", captured, 9)

_G.GetTime = nil

-- ---------------------------------------------------------------------------
-- Le chunk ne s'installe pas hors du jeu
-- ---------------------------------------------------------------------------

print("Installation")

equals("aucune commande n'est enregistree sans CreateFrame", _G.SLASH_YAYAERRORLOG1, nil)

-- ---------------------------------------------------------------------------

print(("\n%d reussite(s), %d echec(s)"):format(passed, failed))
if failed > 0 then
    os.exit(1)
end
