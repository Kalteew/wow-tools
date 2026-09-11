-- Tests unitaires du recensement par statistique de metier, executes hors du
-- jeu avec Lua 5.1.
--
-- StatCensus.lua est sans dependance a l'API du jeu pour tout ce qui decide
-- d'un chiffre : on charge le vrai fichier et on l'interroge directement. Ce
-- qui est verifie ici est la seule chose qui compte pour l'utilisateur -- quel
-- exemplaire entre dans quel seau, et ce qui vaut « inconnu » plutot que zero.
--
-- Usage : lua5.1 Tests/test_statcensus.lua   (depuis addons/YayaQueue)

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

-- ---------------------------------------------------------------------------
-- Chargement du vrai module
-- ---------------------------------------------------------------------------

local ns = {}
assert(loadfile("StatCensus.lua"), "StatCensus.lua introuvable")("YayaQueue", ns)
local StatCensus = assert(ns.StatCensus, "ns.StatCensus non exporte")

local RF, MC = "resourcefulness", "multicrafting"
local TOOL = 244176

-- ---------------------------------------------------------------------------
-- Cles
-- ---------------------------------------------------------------------------

section("Cles de recensement")

equals("cle complete", StatCensus.MakeKey(TOOL, 232, RF), "244176:232:resourcefulness")
equals("statistique absente -> sentinelle",
    StatCensus.MakeKey(TOOL, 232, nil), "244176:232:?")
equals("statistique vide -> sentinelle",
    StatCensus.MakeKey(TOOL, 232, ""), "244176:232:?")
equals("niveau absent -> zero", StatCensus.MakeKey(TOOL, nil, RF), "244176:0:resourcefulness")
equals("itemID invalide", StatCensus.MakeKey(0, 232, RF), nil)

local parsedID, parsedLevel, parsedStat = StatCensus.ParseKey("244176:232:resourcefulness")
equals("relecture itemID", parsedID, TOOL)
equals("relecture niveau", parsedLevel, 232)
equals("relecture statistique", parsedStat, RF)

equals("niveau exige, cle conforme",
    StatCensus.KeyMatches("244176:232:resourcefulness", TOOL, 232, RF), true)
equals("niveau exige, cle d'un autre rang",
    StatCensus.KeyMatches("244176:226:resourcefulness", TOOL, 232, RF), false)
-- Le niveau nul vaut « tous niveaux » : c'est ce qui evite de rendre zero sur
-- un objet dont le niveau exact n'est pas encore connu.
equals("niveau nul = tous niveaux",
    StatCensus.KeyMatches("244176:226:resourcefulness", TOOL, 0, RF), true)
equals("autre statistique ecartee",
    StatCensus.KeyMatches("244176:232:multicrafting", TOOL, 232, RF), false)
equals("statistique non exigee = toutes",
    StatCensus.KeyMatches("244176:232:multicrafting", TOOL, 232, nil), true)

-- ---------------------------------------------------------------------------
-- Magasin
-- ---------------------------------------------------------------------------

section("Magasin : version inconnue repartie de zero")

local db = { statCensus = { version = 99, characters = { ghost = {} } } }
local store = StatCensus.EnsureStore(db)
equals("version normalisee", store.version, StatCensus.VERSION)
equals("contenu d'une version inconnue jete", store.characters.ghost, nil)

section("SetScope remplace, ne fusionne pas")

db = {}
StatCensus.SetScope(db, "Main-Hyjal", "bags", {
    counts = { [StatCensus.MakeKey(TOOL, 232, RF)] = 3 },
    updatedAt = 1000,
    realm = "Hyjal",
})
StatCensus.SetScope(db, "Main-Hyjal", "bags", {
    counts = { [StatCensus.MakeKey(TOOL, 232, RF)] = 1 },
    updatedAt = 2000,
    realm = "Hyjal",
})
local scope = db.statCensus.characters["Main-Hyjal"].scopes.bags
equals("un exemplaire vendu disparait",
    scope.counts[StatCensus.MakeKey(TOOL, 232, RF)], 1)
equals("royaume conserve", db.statCensus.characters["Main-Hyjal"].realm, "Hyjal")

section("Entrees invalides ecartees a l'ecriture")

StatCensus.SetScope(db, "Main-Hyjal", "bank", {
    counts = { ["pas-une-cle"] = 5, [StatCensus.MakeKey(TOOL, 232, MC)] = 0,
               [StatCensus.MakeKey(TOOL, 232, RF)] = 2 },
    updatedAt = 3000,
})
scope = db.statCensus.characters["Main-Hyjal"].scopes.bank
equals("cle illisible jetee", scope.counts["pas-une-cle"], nil)
equals("quantite nulle jetee", scope.counts[StatCensus.MakeKey(TOOL, 232, MC)], nil)
equals("entree valide conservee", scope.counts[StatCensus.MakeKey(TOOL, 232, RF)], 2)

-- ---------------------------------------------------------------------------
-- Requete
-- ---------------------------------------------------------------------------

section("Requete : perso, autres et encheres restent separes")

db = {}
StatCensus.SetScope(db, "Main-Hyjal", "bags", {
    counts = { [StatCensus.MakeKey(TOOL, 232, RF)] = 1 }, updatedAt = 5000 })
StatCensus.SetScope(db, "Main-Hyjal", "mail", {
    counts = { [StatCensus.MakeKey(TOOL, 232, RF)] = 2 }, updatedAt = 4000 })
StatCensus.SetScope(db, "Main-Hyjal", "auctions", {
    counts = { [StatCensus.MakeKey(TOOL, 232, RF)] = 7,
               [StatCensus.MakeKey(TOOL, 232, MC)] = 5,
               [StatCensus.MakeKey(TOOL, 232, nil)] = 3 }, updatedAt = 6000 })
StatCensus.SetScope(db, "Alt-Hyjal", "bags", {
    counts = { [StatCensus.MakeKey(TOOL, 232, RF)] = 4 }, updatedAt = 2000 })
StatCensus.SetScope(db, "Alt-Hyjal", "auctions", {
    counts = { [StatCensus.MakeKey(TOOL, 232, RF)] = 9 }, updatedAt = 3000 })
StatCensus.SetWarband(db, {
    counts = { [StatCensus.MakeKey(TOOL, 232, RF)] = 6 }, updatedAt = 7000 })

local query = StatCensus.Query(db.statCensus, {
    itemID = TOOL, itemLevel = 232, statKey = RF, characterKey = "Main-Hyjal",
})

equals("courrier du perso courant", query.own.mail.count, 2)
equals("les sacs du perso courant ne partent pas chez les autres",
    query.others.count, 4)
equals("encheres cumulees tous personnages", query.auctions.count, 16)
equals("statistique illisible comptee a part", query.auctions.unknownStat, 3)
equals("banque d'aventuriers comptee une seule fois", query.warband.count, 6)
equals("personnages recenses", query.characters, 2)
equals("autres personnages", query.otherCharacters, 1)
-- La date affichee doit etre la plus ancienne : c'est jusqu'a elle que le
-- chiffre est garanti. Retenir la plus recente ferait passer un recensement
-- vieux de trois semaines pour frais.
equals("date la plus ancienne retenue", query.auctions.updatedAt, 3000)

section("Jamais recense : inconnu, pas zero")

query = StatCensus.Query(db.statCensus, {
    itemID = TOOL, itemLevel = 232, statKey = RF, characterKey = "Neuf-Hyjal",
})
equals("aucun courrier pour ce perso", query.own.mail, nil)
-- Vu depuis un personnage absent du recensement, les deux autres sont des
-- « autres » : sacs 1 + courrier 2 du main, plus les sacs 4 de l'alt.
equals("les deux autres personnages comptent", query.others.count, 7)

query = StatCensus.Query({}, { itemID = TOOL, statKey = RF })
equals("magasin vide : encheres inconnues", query.auctions.count, nil)
equals("magasin vide : autres inconnus", query.others.count, nil)
equals("magasin vide : banque d'aventuriers inconnue", query.warband.count, nil)

section("Un autre objet ne fuit pas dans le total")

query = StatCensus.Query(db.statCensus, {
    itemID = 999999, itemLevel = 232, statKey = RF, characterKey = "Main-Hyjal",
})
equals("autre itemID", query.auctions.count, 0)

-- ---------------------------------------------------------------------------
-- AddSample
-- ---------------------------------------------------------------------------

section("AddSample : equipement de metier seulement, statistique au tooltip")

_G.GetDetailedItemLevelInfo = function() return 232 end
StatCensus.Bind({
    isGear = function(itemID) return itemID == TOOL end,
    readStat = function(_, itemLink)
        if itemLink == "pending" then return nil, true end
        if itemLink == "rf" then return RF, false end
        return nil, false
    end,
    warm = function() end,
})

local counts = {}
equals("outil a statistique lue", StatCensus.AddSample(counts, TOOL, "rf", 2), true)
equals("compte", counts[StatCensus.MakeKey(TOOL, 232, RF)], 2)

equals("objet ordinaire ignore", StatCensus.AddSample(counts, 12345, "rf", 1), false)

StatCensus.AddSample(counts, TOOL, "pending", 1)
equals("tooltip illisible -> seau inconnu",
    counts[StatCensus.MakeKey(TOOL, 232, nil)], 1)

StatCensus.AddSample(counts, TOOL, "rf", 3)
equals("les exemplaires s'additionnent",
    counts[StatCensus.MakeKey(TOOL, 232, RF)], 5)
equals("quantite nulle refusee", StatCensus.AddSample(counts, TOOL, "rf", 0), false)

print("")
print(("%d reussis, %d echoues"):format(passed, failed))
if failed > 0 then
    os.exit(1)
end
