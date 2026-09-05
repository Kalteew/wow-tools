-- Tests unitaires de l'etat vide du sniper, executes hors du jeu avec Lua 5.1.
--
-- L'interface du sniper est inatteignable sans CreateFrame : la seule partie
-- qui se teste ici est le choix du message et de la couleur selon l'etat des
-- besoins, extrait en fonction pure pour cette raison. Le reste de la vague de
-- restyle se verifie a l'oeil, en jeu.
--
-- Usage : lua5.1 Tests/test_yayareagentsniperstatus.lua   (depuis addons/YayaReagentSniper)

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
    check(name, actual == expected,
        ("attendu %s, obtenu %s"):format(tostring(expected), tostring(actual)))
end

-- ---------------------------------------------------------------------------
-- Chargement de la palette
-- ---------------------------------------------------------------------------

-- UI.lua se charge sans CreateFrame : il degrade ses fabriques mais expose ses
-- tokens, ce qui suffit a verifier que chaque etat designe une couleur reelle.
YayaCore = {}
dofile("../YayaCore/YayaCore.lua")
dofile("../YayaCore/UI.lua")
local UI = YayaCore.UI

-- ---------------------------------------------------------------------------
-- Copie de la table de decision
-- ---------------------------------------------------------------------------

-- YayaReagentSniper.lua ne peut pas etre charge ici : son chunk appelle
-- CreateFrame des le niveau superieur. La fonction est donc reproduite a
-- l'identique, et un controle de source verifie qu'elle n'a pas divergé.
local function EmptyResultsStatus(needsState)
    if needsState == "covered" then
        return "|TInterface\\RaidFrame\\ReadyCheck-Ready:24|t Rien à sniper — besoins déjà couverts", "success"
    elseif needsState == "empty" then
        return "Groupe vide — aucune cible Shopping TSM", "textMuted"
    elseif needsState == "filtered" then
        return "Aucun restock — manque inférieur au seuil", "warning"
    elseif needsState == "invalid" then
        return "Aucune cible valide — vérifie les opérations Shopping TSM", "danger"
    end
    return "Aucune opportunité pour le moment", "textMuted"
end

print("")
print("Etat vide du sniper")

-- ---------------------------------------------------------------------------
-- Chaque etat rend un ton, et chaque ton existe dans la palette
-- ---------------------------------------------------------------------------

local states = { "covered", "empty", "filtered", "invalid", "inconnu", nil }
for index = 1, 6 do
    local needsState = states[index]
    local message, tone = EmptyResultsStatus(needsState)
    local label = tostring(needsState)
    check(("l'etat %s rend un message"):format(label),
        type(message) == "string" and message ~= "")
    check(("l'etat %s designe un token de la palette"):format(label),
        type(UI.COLOR[tone]) == "table" and #UI.COLOR[tone] == 4, tone)
end

-- Les tons portent du sens : un succes ne doit pas se peindre comme une erreur.
equals("besoins couverts : succes", select(2, EmptyResultsStatus("covered")), "success")
equals("groupe vide : neutre", select(2, EmptyResultsStatus("empty")), "textMuted")
equals("sous le seuil : avertissement", select(2, EmptyResultsStatus("filtered")), "warning")
equals("cibles invalides : erreur", select(2, EmptyResultsStatus("invalid")), "danger")
equals("etat inconnu : neutre", select(2, EmptyResultsStatus("autre chose")), "textMuted")
equals("etat absent : neutre", select(2, EmptyResultsStatus(nil)), "textMuted")

-- ---------------------------------------------------------------------------
-- Non-regression : la copie ci-dessus doit suivre la source
-- ---------------------------------------------------------------------------

-- Sans ce controle, une teinte modifiee dans l'addon laisserait le test vert.
local handle = assert(io.open("YayaReagentSniper.lua", "rb"))
local source = handle:read("*a")
handle:close()
-- L'arbre de travail est rendu en CRLF : sans normalisation, aucun motif
-- contenant un saut de ligne ne trouverait sa cible.
source = source:gsub("\r\n", "\n")

-- Le fichier contient d'autres tests sur needsState : on isole d'abord le corps
-- de la fonction, sinon la recherche retomberait sur un bloc voisin.
local body = source:match("local function EmptyResultsStatus%(needsState%)\n(.-)\nend\n")
check("la fonction pure est presente dans la source", body ~= nil)

for _, pair in ipairs({
    { "covered", "success" },
    { "empty", "textMuted" },
    { "filtered", "warning" },
    { "invalid", "danger" },
}) do
    local needle = ('"%s"'):format(pair[2])
    local line = body and body:match('needsState == "' .. pair[1] .. '" then\n([^\n]+)')
    check(("la source associe %s au ton %s"):format(pair[1], pair[2]),
        line ~= nil and line:find(needle, 1, true) ~= nil, line)
end

check("la source n'a plus de triplet RGB dans l'etat vide",
    source:find("emptyResults:SetTextColor(0", 1, true) == nil)

-- ---------------------------------------------------------------------------
-- Verdict
-- ---------------------------------------------------------------------------

print("")
print(("%d reussis, %d echoues"):format(passed, failed))
if failed > 0 then
    os.exit(1)
end
