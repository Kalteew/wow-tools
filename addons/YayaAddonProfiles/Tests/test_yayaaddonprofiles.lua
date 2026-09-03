-- Tests unitaires de YayaAddonProfiles, executes hors du jeu avec Lua 5.1.
--
-- Deux zones seulement sont testables sans client, et ce sont justement les
-- deux qui cassent en silence : la fusion des personnages en double, qui
-- reecrit des donnees reelles au chargement, et le comparateur de tri, qu'un
-- ordre non strict ferait exploser dans table.sort sur certaines permutations.
--
-- Usage : lua5.1 Tests/test_yayaaddonprofiles.lua   (depuis addons/YayaAddonProfiles)

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
-- Doublures : le strict necessaire au chargement du chunk
-- ---------------------------------------------------------------------------

_G.time = os.time
_G.date = os.date

_G.DEFAULT_CHAT_FRAME = { AddMessage = function() end }
_G.StaticPopupDialogs = {}
_G.CANCEL = "Annuler"

_G.YayaCore = {
    RingBuffer = {
        Push = function(buffer, entry)
            buffer[#buffer + 1] = entry
        end,
    },
    UI = {
        HEX = { accent = "|cff00ff98", stop = "|r" },
    },
}

-- Le chunk ne cree qu'une frame d'evenements a son chargement.
_G.CreateFrame = function()
    local frame = {}
    function frame:RegisterEvent() end
    function frame:SetScript() end
    return frame
end

-- ---------------------------------------------------------------------------
-- Chargement du module
-- ---------------------------------------------------------------------------

assert(loadfile("YayaAddonProfiles.lua"))("YayaAddonProfiles")

local Internal = _G.YayaAddonProfiles_Internal
check("le module expose sa surface de test", type(Internal) == "table")

-- Repose une base neuve et la rebranche sur le local DB du chunk.
local function ResetDb(characters, assignments)
    _G.YayaAddonProfilesDB = {
        characters = characters or {},
        assignments = assignments or {},
    }
    Internal.EnsureDb()
    return _G.YayaAddonProfilesDB
end

-- ---------------------------------------------------------------------------
-- Valeurs par defaut
-- ---------------------------------------------------------------------------

print("")
print("Valeurs par defaut")

local db = ResetDb()
equals("la proposition de reload est silencieuse par defaut", db.promptReload, false)
equals("le tri par defaut porte sur le nom", db.sortKey, "name")
equals("le tri par defaut est croissant", db.sortDesc, false)
equals("le diagnostic reste actif par defaut", db.debug, true)

-- Un choix deja pose ne doit pas etre ecrase au chargement suivant.
_G.YayaAddonProfilesDB = { promptReload = true, sortKey = "level", sortDesc = true, debug = false }
Internal.EnsureDb()
equals("un choix de reload existant survit", _G.YayaAddonProfilesDB.promptReload, true)
equals("une cle de tri existante survit", _G.YayaAddonProfilesDB.sortKey, "level")
equals("un sens de tri existant survit", _G.YayaAddonProfilesDB.sortDesc, true)

-- ---------------------------------------------------------------------------
-- RememberCharacter : la fusion champ par champ
-- ---------------------------------------------------------------------------

print("")
print("RememberCharacter")

db = ResetDb()
Internal.RememberCharacter("Yayawar-Hyjal", "Player-1", "WARRIOR", "ffc69b6d", 80, "2026-09-01 10:00")
local remembered = db.characters["Yayawar-Hyjal"]
equals("le niveau est persiste", remembered.level, 80)
equals("la derniere connexion est persistee", remembered.lastSeen, "2026-09-01 10:00")

-- Le piege : SeedKnownCharacters rappelle la fonction sans classe ni niveau.
-- Un nil ne doit jamais effacer une valeur connue.
Internal.RememberCharacter("Yayawar-Hyjal", "Player-1", nil, nil, nil, nil)
equals("un seeding sans niveau ne l'efface pas", db.characters["Yayawar-Hyjal"].level, 80)
equals("un seeding sans classe ne l'efface pas", db.characters["Yayawar-Hyjal"].class, "WARRIOR")
equals("un seeding sans date ne l'efface pas", db.characters["Yayawar-Hyjal"].lastSeen, "2026-09-01 10:00")

Internal.RememberCharacter("Inconnu-Hyjal")
equals("une entree neuve retombe sur le blanc", db.characters["Inconnu-Hyjal"].color, "ffffffff")
equals("une entree neuve n'invente pas de niveau", db.characters["Inconnu-Hyjal"].level, nil)

-- ---------------------------------------------------------------------------
-- PreferredCharacterId
-- ---------------------------------------------------------------------------

print("")
print("PreferredCharacterId")

-- GetCharacterId compose son identifiant avec GetRealmName, qui rend le royaume
-- avec ses espaces : c'est la forme qui sera regeneree a chaque connexion.
equals("la forme avec espaces l'emporte",
    Internal.PreferredCharacterId("Kaltmodan-Khaz Modan", "Kaltmodan-KhazModan"),
    "Kaltmodan-Khaz Modan")
equals("le resultat ne depend pas de l'ordre des arguments",
    Internal.PreferredCharacterId("Kaltmodan-KhazModan", "Kaltmodan-Khaz Modan"),
    "Kaltmodan-Khaz Modan")
equals("a defaut d'espace, la forme la plus longue l'emporte",
    Internal.PreferredCharacterId("Yaya-Hyjal", "Yayaa-Hyjal"), "Yayaa-Hyjal")
equals("a longueur egale, le departage est alphabetique",
    Internal.PreferredCharacterId("Bbb-Hyjal", "Aaa-Hyjal"), "Aaa-Hyjal")

-- ---------------------------------------------------------------------------
-- MergeDuplicateCharacters
-- ---------------------------------------------------------------------------

print("")
print("MergeDuplicateCharacters")

db = ResetDb({
    ["Kaltmodan-Khaz Modan"] = {
        id = "Kaltmodan-Khaz Modan", guid = "Player-3690-0B102B2F",
        class = "EVOKER", color = "ff33937f",
    },
    ["Kaltmodan-KhazModan"] = {
        id = "Kaltmodan-KhazModan", guid = "Player-3690-0B102B2F",
        class = "EVOKER", color = "ff33937f", level = 74, lastSeen = "2026-08-30 12:00",
    },
    ["Yayawar-Hyjal"] = {
        id = "Yayawar-Hyjal", guid = "Player-1390-0A2A49D5", level = 80,
    },
    ["Sansguid-Hyjal"] = { id = "Sansguid-Hyjal" },
}, {
    ["Kaltmodan-KhazModan"] = "AH toon",
    ["Yayawar-Hyjal"] = "Concentration crafting",
})

local mergedCount = Internal.MergeDuplicateCharacters()
equals("une seule paire est fusionnee", mergedCount, 1)
check("le jumeau sans espace disparait", db.characters["Kaltmodan-KhazModan"] == nil)
check("la forme canonique subsiste", db.characters["Kaltmodan-Khaz Modan"] ~= nil)
equals("le niveau du jumeau est recupere", db.characters["Kaltmodan-Khaz Modan"].level, 74)
equals("la derniere connexion du jumeau est recuperee",
    db.characters["Kaltmodan-Khaz Modan"].lastSeen, "2026-08-30 12:00")
equals("l'assignation est reportee sur la forme conservee",
    db.assignments["Kaltmodan-Khaz Modan"], "AH toon")
equals("l'assignation du jumeau est retiree", db.assignments["Kaltmodan-KhazModan"], nil)
check("une entree sans GUID est laissee intacte", db.characters["Sansguid-Hyjal"] ~= nil)
check("un personnage unique est laisse intact", db.characters["Yayawar-Hyjal"] ~= nil)
equals("son assignation n'a pas bouge", db.assignments["Yayawar-Hyjal"], "Concentration crafting")
equals("la version de schema est posee", db.version, 4)

equals("un second passage ne fusionne plus rien", Internal.MergeDuplicateCharacters(), 0)

-- Conflit d'assignations : celle de la forme conservee est prioritaire.
db = ResetDb({
    ["Perso-Argent Dawn"] = { id = "Perso-Argent Dawn", guid = "G1" },
    ["Perso-ArgentDawn"] = { id = "Perso-ArgentDawn", guid = "G1" },
}, {
    ["Perso-Argent Dawn"] = "Garde",
    ["Perso-ArgentDawn"] = "Jette",
})
Internal.MergeDuplicateCharacters()
equals("l'assignation de la forme conservee gagne", db.assignments["Perso-Argent Dawn"], "Garde")
equals("l'assignation du jumeau est retiree", db.assignments["Perso-ArgentDawn"], nil)

-- Le niveau ne redescend jamais : le maximum des deux est le bon.
db = ResetDb({
    ["Perso-Temple noir"] = { id = "Perso-Temple noir", guid = "G2", level = 71 },
    ["Perso-Templenoir"] = { id = "Perso-Templenoir", guid = "G2", level = 80 },
})
Internal.MergeDuplicateCharacters()
equals("le niveau retenu est le plus haut", db.characters["Perso-Temple noir"].level, 80)

-- Trois entrees sur un meme GUID doivent converger vers une seule.
db = ResetDb({
    ["Perso-Tarren Mill"] = { id = "Perso-Tarren Mill", guid = "G3" },
    ["Perso-TarrenMill"] = { id = "Perso-TarrenMill", guid = "G3", level = 60 },
    ["Perso-Tarrenmill"] = { id = "Perso-Tarrenmill", guid = "G3", level = 62 },
})
Internal.MergeDuplicateCharacters()
local remaining = 0
for _ in pairs(db.characters) do
    remaining = remaining + 1
end
equals("trois entrees d'un meme GUID convergent", remaining, 1)
equals("la forme canonique survit a trois entrees",
    db.characters["Perso-Tarren Mill"] ~= nil, true)
equals("le niveau le plus haut des trois est retenu",
    db.characters["Perso-Tarren Mill"].level, 62)

-- ---------------------------------------------------------------------------
-- Tri
-- ---------------------------------------------------------------------------

print("")
print("Tri de la liste de personnages")

local function ids(list)
    local names = {}
    for index, character in ipairs(list) do
        names[index] = character.id
    end
    return table.concat(names, ",")
end

db = ResetDb({
    ["Bbb-Hyjal"] = { id = "Bbb-Hyjal", level = 80 },
    ["Aaa-Hyjal"] = { id = "Aaa-Hyjal", level = 60 },
    ["Ccc-Hyjal"] = { id = "Ccc-Hyjal" },
    ["Ddd-Hyjal"] = { id = "Ddd-Hyjal", level = 71 },
}, {
    ["Bbb-Hyjal"] = "Alpha",
    ["Aaa-Hyjal"] = "Zeta",
})

db.sortKey, db.sortDesc = "name", false
equals("tri par nom croissant", ids(Internal.SortedCharacters()),
    "Aaa-Hyjal,Bbb-Hyjal,Ccc-Hyjal,Ddd-Hyjal")

db.sortDesc = true
equals("tri par nom decroissant", ids(Internal.SortedCharacters()),
    "Ddd-Hyjal,Ccc-Hyjal,Bbb-Hyjal,Aaa-Hyjal")

-- Un niveau inconnu finit la liste dans les DEUX sens : le relegue est une
-- absence de donnee, pas une valeur basse.
db.sortKey, db.sortDesc = "level", true
equals("tri par niveau decroissant, inconnu en fin", ids(Internal.SortedCharacters()),
    "Bbb-Hyjal,Ddd-Hyjal,Aaa-Hyjal,Ccc-Hyjal")

db.sortDesc = false
equals("tri par niveau croissant, inconnu toujours en fin", ids(Internal.SortedCharacters()),
    "Aaa-Hyjal,Ddd-Hyjal,Bbb-Hyjal,Ccc-Hyjal")

-- Meme regle pour un personnage sans profil.
db.sortKey, db.sortDesc = "profile", false
equals("tri par profil croissant, sans profil en fin", ids(Internal.SortedCharacters()),
    "Bbb-Hyjal,Aaa-Hyjal,Ccc-Hyjal,Ddd-Hyjal")

db.sortDesc = true
equals("tri par profil decroissant, sans profil toujours en fin", ids(Internal.SortedCharacters()),
    "Aaa-Hyjal,Bbb-Hyjal,Ccc-Hyjal,Ddd-Hyjal")

-- Le comparateur doit rester un ordre strict total, sinon table.sort leve
-- "invalid order function for sorting" sur certaines permutations.
db = ResetDb()
for index = 1, 40 do
    local id = ("Perso%02d-Hyjal"):format(index)
    db.characters[id] = { id = id, level = (index % 3 == 0) and nil or (60 + (index % 7)) }
    if index % 4 == 0 then
        db.assignments[id] = ("Profil%d"):format(index % 3)
    end
end
for _, key in ipairs({ "name", "level", "profile" }) do
    for _, desc in ipairs({ false, true }) do
        db.sortKey, db.sortDesc = key, desc
        local ok = pcall(Internal.SortedCharacters)
        check(("le tri %s %s reste un ordre strict"):format(key, desc and "descendant" or "ascendant"), ok)
    end
end

-- ---------------------------------------------------------------------------
-- SetSortKey
-- ---------------------------------------------------------------------------

print("")
print("SetSortKey")

db = ResetDb()
Internal.SetSortKey("level")
equals("une nouvelle colonne devient active", db.sortKey, "level")
equals("le niveau part du plus haut", db.sortDesc, true)

Internal.SetSortKey("level")
equals("un second clic inverse le sens", db.sortDesc, false)

Internal.SetSortKey("name")
equals("le nom part de A", db.sortDesc, false)

Internal.SetSortKey("profile")
equals("le profil part de A", db.sortDesc, false)

-- ---------------------------------------------------------------------------
-- Bilan
-- ---------------------------------------------------------------------------

print("")
print(("%d reussite(s), %d echec(s)"):format(passed, failed))
if failed > 0 then
    os.exit(1)
end
