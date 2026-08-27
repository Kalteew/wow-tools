-- Tests unitaires de YayaCore, executes hors du jeu avec Lua 5.1.
--
-- Les fonctions de l'API WoW utilisees par le module sont remplacees par des
-- doublures : le but est de verifier la logique propre a YayaCore (formatage,
-- tampon circulaire du journal, resolution des prix TSM), pas l'API Blizzard.
--
-- Usage : lua5.1 Tests/test_yayacore.lua   (depuis addons/YayaCore)

-- ---------------------------------------------------------------------------
-- Doublures de l'API WoW
-- ---------------------------------------------------------------------------

local function FormatCopperParts(copper)
    local gold = math.floor(copper / 10000)
    local silver = math.floor((copper % 10000) / 100)
    local copperPart = copper % 100
    return ("%dg%ds%dc"):format(gold, silver, copperPart)
end

_G.GetMoneyString = function(copper, separateThousands)
    return FormatCopperParts(copper) .. (separateThousands and "" or "|nosep")
end

_G.BreakUpLargeNumbers = function(value)
    return tostring(value)
end

_G.CreateTextureMarkup = nil  -- force le repli sur le balisage texte

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

local chunk = assert(loadfile("YayaCore.lua"))
chunk("YayaCore")
local Core = _G.YayaCore
check("le module s'expose en global", type(Core) == "table")

-- ---------------------------------------------------------------------------
-- Money
-- ---------------------------------------------------------------------------

print("Money.Format")
equals("montant simple", Core.Money.Format(12345), "1g23s45c")
equals("valeur nil traitee comme zero", Core.Money.Format(nil), "0g0s0c")
equals("chaine numerique acceptee", Core.Money.Format("12345"), "1g23s45c")
equals("partie decimale tronquee", Core.Money.Format(12345.9), "1g23s45c")
equals("texte pour montant nul", Core.Money.Format(0, { zeroText = "-" }), "-")
equals("texte pour montant negatif", Core.Money.Format(-5, { zeroText = "-" }), "-")
equals("sans zeroText, zero est formate", Core.Money.Format(0), "0g0s0c")
equals("clampNegative ramene a zero", Core.Money.Format(-500, { clampNegative = true }), "0g0s0c")

print("Money.FormatCompact")
equals("cuivre", Core.Money.FormatCompact(45), "45c")
equals("argent", Core.Money.FormatCompact(2500), "25s")
equals("or a une decimale", Core.Money.FormatCompact(15 * 10000), "15.0g")
equals("or entier", Core.Money.FormatCompact(150 * 10000), "150g")
equals("milliers a une decimale", Core.Money.FormatCompact(15000 * 10000), "15.0k")
equals("milliers entiers", Core.Money.FormatCompact(150000 * 10000), "150k")
equals("negatif prefixe", Core.Money.FormatCompact(-2500), "-25s")
equals("zero", Core.Money.FormatCompact(0), "0c")

print("Money.FormatGoldOnly")
equals("or seul avec icone", Core.Money.FormatGoldOnly(123456789),
    "12345|TInterface\\MoneyFrame\\UI-GoldIcon:14:14:2:0|t")
equals("negatif non signe", Core.Money.FormatGoldOnly(-50000),
    "5|TInterface\\MoneyFrame\\UI-GoldIcon:14:14:2:0|t")
equals("negatif signe", Core.Money.FormatGoldOnly(-50000, true),
    "-5|TInterface\\MoneyFrame\\UI-GoldIcon:14:14:2:0|t")

-- ---------------------------------------------------------------------------
-- Price
-- ---------------------------------------------------------------------------

print("Price")
check("indisponible sans TSM", Core.Price.IsAvailable() == false)
equals("Get renvoie nil sans TSM", Core.Price.Get(12345), nil)

_G.TSM_API = {
    ToItemString = function(value)
        if value == "i:0" then
            return nil
        end
        return value
    end,
    GetCustomPriceValue = function(source, itemString)
        if source == "invalide" then
            error("source inconnue")
        end
        if itemString == "i:404" then
            return nil
        end
        return 4200
    end,
}

check("disponible avec TSM", Core.Price.IsAvailable() == true)
equals("itemID converti", Core.Price.ToItemString(4321), "i:4321")
equals("chaine transmise telle quelle", Core.Price.ToItemString("i:9:1:2"), "i:9:1:2")
equals("type invalide", Core.Price.ToItemString({}), nil)
equals("prix lu", Core.Price.Get(4321), 4200)
equals("objet sans prix", Core.Price.Get(404), nil)
equals("source invalide capturee", Core.Price.Get(4321, "invalide"), nil)

_G.TSM_API.GetCustomPriceValue = function() return 0 end
equals("prix nul traite comme absent", Core.Price.Get(4321), nil)
_G.TSM_API = nil

-- ---------------------------------------------------------------------------
-- RingBuffer
-- ---------------------------------------------------------------------------

print("RingBuffer")
local ring = {}
for index = 1, 3 do
    Core.RingBuffer.Push(ring, "e" .. index, 3)
end
equals("remplissage lineaire", #ring, 3)
check("pas de curseur tant que la limite n'est pas atteinte", ring.cursor == nil, tostring(ring.cursor))

Core.RingBuffer.Push(ring, "e4", 3)
equals("la taille reste bornee", #ring, 3)
local ordered = Core.RingBuffer.Read(ring)
check("la plus ancienne est evincee",
    table.concat(ordered, ",") == "e2,e3,e4",
    table.concat(ordered, ","))

for index = 5, 9 do
    Core.RingBuffer.Push(ring, "e" .. index, 3)
end
ordered = Core.RingBuffer.Read(ring)
check("rotation sur plusieurs tours",
    table.concat(ordered, ",") == "e7,e8,e9",
    table.concat(ordered, ","))

-- Un journal ecrit par l'ancienne version n'a pas de curseur : il doit etre
-- repris sans perte ni desordre.
local legacy = { "a", "b", "c", "d", "e" }
Core.RingBuffer.Push(legacy, "f", 5)
equals("journal existant ramene a la limite", #legacy, 5)
ordered = Core.RingBuffer.Read(legacy)
check("reprise d'un journal lineaire",
    table.concat(ordered, ",") == "b,c,d,e,f",
    table.concat(ordered, ","))

-- Une limite reduite doit tronquer l'ancien journal, pas laisser de residus.
local shrink = { "a", "b", "c", "d", "e", "f", "g", "h" }
Core.RingBuffer.Push(shrink, "i", 4)
equals("journal tronque a la nouvelle limite", #shrink, 4)

-- Les entrees ne sont pas forcement des chaines.
local structured = {}
Core.RingBuffer.Push(structured, { event = "x" }, 2)
Core.RingBuffer.Push(structured, { event = "y" }, 2)
Core.RingBuffer.Push(structured, { event = "z" }, 2)
equals("entrees structurees bornees", #structured, 2)
equals("derniere entree structuree", Core.RingBuffer.Read(structured)[2].event, "z")

Core.RingBuffer.Push(nil, "ignore", 5)
check("table absente ignoree sans erreur", true)

-- ---------------------------------------------------------------------------
-- Log : tampon circulaire
-- ---------------------------------------------------------------------------

print("Log")
local store = {}
local logger = Core.Log.New("Test", { limit = 3, store = function() return store end })

logger.Append("un")
logger.Append("deux")
equals("deux entrees stockees", #store, 2)

logger.Append("trois")
logger.Append("quatre")
logger.Append("cinq")
equals("la limite est respectee", #store, 3)

local read = logger.Read()
equals("lecture: trois entrees", #read, 3)
check("la plus ancienne est evincee", not read[1]:find("deux"), read[1])
check("l'ordre chronologique est conserve",
    read[1]:find("trois") and read[2]:find("quatre") and read[3]:find("cinq"),
    table.concat(read, " | "))

local tail = logger.Read(2)
equals("lecture partielle", #tail, 2)
check("la lecture partielle prend la fin",
    tail[1]:find("quatre") and tail[2]:find("cinq"),
    table.concat(tail, " | "))

local noStore = Core.Log.New("Test", { limit = 2 })
noStore.Append("ignore")
equals("sans stockage, lecture vide", #noStore.Read(), 0)

-- ---------------------------------------------------------------------------
-- Schedule
-- ---------------------------------------------------------------------------

print("Schedule")
local pendingTimers = {}
_G.C_Timer = {
    After = function(delay, callback)
        pendingTimers[#pendingTimers + 1] = { delay = delay, callback = callback }
    end,
}

local scheduler = Core.Schedule.NewToken()
local runs = 0
scheduler.After(1, function() runs = runs + 1 end)
scheduler.After(1, function() runs = runs + 1 end)
equals("deux timers programmes", #pendingTimers, 2)
for _, timer in ipairs(pendingTimers) do
    timer.callback()
end
equals("seul le dernier s'execute", runs, 1)

pendingTimers = {}
runs = 0
scheduler.After(1, function() runs = runs + 1 end)
scheduler.Cancel()
pendingTimers[1].callback()
equals("l'annulation empeche l'execution", runs, 0)

_G.C_Timer = nil
local immediate = 0
Core.Schedule.NewToken().After(1, function() immediate = immediate + 1 end)
equals("sans C_Timer, execution immediate", immediate, 1)

-- ---------------------------------------------------------------------------

print("")
print(("%d reussis, %d echoues"):format(passed, failed))
if failed > 0 then
    os.exit(1)
end
