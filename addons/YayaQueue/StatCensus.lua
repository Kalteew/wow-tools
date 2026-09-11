-- Recensement des exemplaires a statistique de metier, par personnage.
--
-- Pourquoi ce fichier existe : TSM est aveugle a la statistique par
-- construction. Il indexe l'equipement fabrique par `levelItemString`
-- (`i:244176::i232`), qui porte le niveau d'objet et rien d'autre, et ses
-- totaux n'exposent aucun etat de liaison ni aucune statistique. Or la
-- statistique d'un outil est tiree sur l'exemplaire : elle n'existe qu'au
-- tooltip de son lien unique. Deux exemplaires du meme itemID au meme niveau
-- peuvent donc etre l'un Ingeniosite, l'autre Fabrication multiple, et rien
-- dans les chiffres TSM ne les distingue.
--
-- La seule voie praticable est donc : lire les liens quand le client les
-- expose -- sacs, banques, boite aux lettres, ses propres encheres -- et
-- conserver le decompte. Un alt entre au recensement des qu'on le joue.
--
-- Ce module est volontairement sans dependance a l'API du jeu pour tout ce qui
-- decide d'un chiffre : le magasin, les cles, la fusion et la requete sont du
-- Lua pur, testes hors du jeu par `Tests/test_statcensus.lua`. La lecture d'une
-- statistique est injectee par YayaQueue via `StatCensus.Bind`, parce qu'elle
-- passe par le tooltip et par le cache memoise de l'addon.

local _, ns = ...

local StatCensus = {}
ns.StatCensus = StatCensus

StatCensus.VERSION = 1

-- Statistique illisible. Ces exemplaires ne sont pas devines : ils sont comptes
-- a part et affiches comme tels, sinon un outil de statistique inconnue
-- gonflerait silencieusement le chiffre d'une statistique precise.
StatCensus.UNKNOWN_STAT = "?"

-- Perimetres recenses pour un personnage. `warband` n'en fait pas partie : la
-- banque d'aventuriers est partagee par le compte et vit hors de `characters`,
-- sinon elle serait comptee autant de fois qu'il y a de personnages recenses.
StatCensus.CHARACTER_SCOPES = { "bags", "bank", "mail", "auctions" }

-- Perimetres qui composent le stock « chez les autres personnages ». Les
-- encheres en sont exclues : elles ont leur propre ligne, tous personnages
-- confondus, comme le fait deja la composition sans filtre.
StatCensus.HOLDING_SCOPES = { "bags", "bank", "mail" }

-- ---------------------------------------------------------------------------
-- Cles
-- ---------------------------------------------------------------------------

--- Cle de recensement d'un exemplaire.
--
-- Le niveau d'objet porte deja le rang de craft, et la statistique est retenue
-- par sa cle interne, jamais par son libelle : celui-ci change de langue, la
-- cle non.
function StatCensus.MakeKey(itemID, itemLevel, statKey)
    itemID = tonumber(itemID)
    if not itemID or itemID <= 0 then return nil end
    if type(statKey) ~= "string" or statKey == "" then
        statKey = StatCensus.UNKNOWN_STAT
    end
    return ("%d:%d:%s"):format(itemID, math.floor(tonumber(itemLevel) or 0), statKey)
end

function StatCensus.ParseKey(key)
    if type(key) ~= "string" then return nil end
    local itemID, itemLevel, statKey = key:match("^(%d+):(%d+):(.+)$")
    if not itemID then return nil end
    return tonumber(itemID), tonumber(itemLevel), statKey
end

--- Une cle decrit-elle l'objet demande ?
--
-- Un `itemLevel` nul ou absent dans la demande vaut « tous niveaux » : c'est ce
-- qui permet d'interroger un objet dont on ne connait pas encore le niveau
-- exact sans rendre zero.
function StatCensus.KeyMatches(key, itemID, itemLevel, statKey)
    local keyItemID, keyItemLevel, keyStatKey = StatCensus.ParseKey(key)
    if not keyItemID or keyItemID ~= tonumber(itemID) then return false end
    itemLevel = math.floor(tonumber(itemLevel) or 0)
    if itemLevel > 0 and keyItemLevel ~= itemLevel then return false end
    if statKey and keyStatKey ~= statKey then return false end
    return true
end

-- ---------------------------------------------------------------------------
-- Magasin
-- ---------------------------------------------------------------------------

--- Normalise `db.statCensus` et le renvoie.
--
-- Une version inconnue est repartie de zero plutot que lue de travers : un
-- recensement se reconstitue en quelques minutes de jeu, un chiffre faux ne se
-- voit pas.
function StatCensus.EnsureStore(db)
    if type(db) ~= "table" then return nil end
    local store = db.statCensus
    if type(store) ~= "table" or tonumber(store.version) ~= StatCensus.VERSION then
        store = { version = StatCensus.VERSION }
        db.statCensus = store
    end
    if type(store.characters) ~= "table" then store.characters = {} end
    if type(store.warband) ~= "table" then store.warband = nil end
    return store
end

local function NormalizeEntry(entry)
    local counts = {}
    for key, count in pairs(type(entry) == "table" and entry.counts or {}) do
        count = math.floor(tonumber(count) or 0)
        if StatCensus.ParseKey(key) and count > 0 then
            counts[key] = count
        end
    end
    return {
        counts = counts,
        updatedAt = math.floor(tonumber(entry and entry.updatedAt) or 0),
        partial = (entry and entry.partial) == true or nil,
    }
end

--- Remplace le recensement d'un perimetre pour un personnage.
--
-- Remplacement et non fusion : un exemplaire vendu ou envoye doit disparaitre.
-- Fusionner ferait grossir le chiffre indefiniment.
function StatCensus.SetScope(db, characterKey, scope, entry)
    local store = StatCensus.EnsureStore(db)
    if not store or type(characterKey) ~= "string" or characterKey == "" then return nil end
    local character = store.characters[characterKey]
    if type(character) ~= "table" then
        character = { scopes = {} }
        store.characters[characterKey] = character
    end
    if type(character.scopes) ~= "table" then character.scopes = {} end
    if entry and entry.realm then character.realm = entry.realm end
    character.scopes[scope] = NormalizeEntry(entry)
    return character.scopes[scope]
end

--- Remplace le recensement de la banque d'aventuriers, commune au compte.
function StatCensus.SetWarband(db, entry)
    local store = StatCensus.EnsureStore(db)
    if not store then return nil end
    store.warband = NormalizeEntry(entry)
    return store.warband
end

-- ---------------------------------------------------------------------------
-- Requete
-- ---------------------------------------------------------------------------

local function SumEntry(entry, itemID, itemLevel, statKey)
    if type(entry) ~= "table" or type(entry.counts) ~= "table" then return nil end
    local count, unknownStat = 0, 0
    for key, quantity in pairs(entry.counts) do
        if StatCensus.KeyMatches(key, itemID, itemLevel, statKey) then
            count = count + quantity
        elseif StatCensus.KeyMatches(key, itemID, itemLevel, StatCensus.UNKNOWN_STAT) then
            unknownStat = unknownStat + quantity
        end
    end
    return count, unknownStat, entry.updatedAt, entry.partial == true
end

local function Accumulate(target, count, unknownStat, updatedAt, partial)
    if count == nil then return end
    target.count = (target.count or 0) + count
    target.unknownStat = (target.unknownStat or 0) + (unknownStat or 0)
    -- La date affichee est la plus ancienne : c'est celle qui dit jusqu'ou le
    -- chiffre est garanti. Retenir la plus recente ferait passer un
    -- recensement vieux de trois semaines pour frais.
    if updatedAt and updatedAt > 0 then
        if not target.updatedAt or updatedAt < target.updatedAt then
            target.updatedAt = updatedAt
        end
    end
    if partial then target.partial = true end
    target.sources = (target.sources or 0) + 1
end

--- Agrege le recensement pour un objet et une statistique.
--
-- Fonction pure. `count == nil` veut dire « jamais recense » et doit ressortir
-- en inconnu, jamais en zero : un personnage qu'on n'a pas joue depuis la mise
-- en place du recensement n'a pas un stock nul, il a un stock inconnu.
function StatCensus.Query(store, request)
    local result = {
        own = {},
        others = {},
        auctions = {},
        warband = {},
    }
    if type(store) ~= "table" then return result end
    local itemID = tonumber(request and request.itemID)
    if not itemID then return result end
    local itemLevel = request and request.itemLevel
    local statKey = request and request.statKey
    local characterKey = request and request.characterKey

    Accumulate(result.warband, SumEntry(store.warband, itemID, itemLevel, statKey))

    result.characters = 0
    result.otherCharacters = 0
    for key, character in pairs(type(store.characters) == "table" and store.characters or {}) do
        local scopes = type(character) == "table" and character.scopes or {}
        result.characters = result.characters + 1
        local isSelf = key == characterKey
        if not isSelf then result.otherCharacters = result.otherCharacters + 1 end
        for _, scope in ipairs(StatCensus.HOLDING_SCOPES) do
            local entry = scopes[scope]
            if entry then
                if isSelf then
                    local target = result.own[scope] or {}
                    result.own[scope] = target
                    Accumulate(target, SumEntry(entry, itemID, itemLevel, statKey))
                else
                    Accumulate(result.others, SumEntry(entry, itemID, itemLevel, statKey))
                end
            end
        end
        -- Les encheres de tous les personnages tiennent une seule ligne, comme
        -- dans la composition sans filtre ou TSM cumule deja perso et alts.
        Accumulate(result.auctions, SumEntry(scopes.auctions, itemID, itemLevel, statKey))
    end

    return result
end

-- ---------------------------------------------------------------------------
-- Affichage
-- ---------------------------------------------------------------------------

--- Date courte d'un recensement, ou nil.
--
-- `date` est le nom du global dans le client ; `os.date` n'existe qu'en Lua
-- autonome, ou tournent les tests.
function StatCensus.FormatDate(timestamp)
    timestamp = tonumber(timestamp)
    if not timestamp or timestamp <= 0 then return nil end
    local formatter = _G and _G.date or (os and os.date)
    if type(formatter) ~= "function" then return nil end
    local ok, text = pcall(formatter, "%d/%m", timestamp)
    return ok and type(text) == "string" and text or nil
end

-- ---------------------------------------------------------------------------
-- Injection depuis YayaQueue
-- ---------------------------------------------------------------------------

-- `readStat(itemID, itemLink)` doit rendre `statKey, pending`, et `warm(itemID)`
-- redemander les donnees d'un objet. Les deux vivent dans YayaQueue.lua, qui se
-- charge apres ce fichier, d'ou l'injection au chargement plutot qu'un appel
-- direct.
function StatCensus.Bind(hooks)
    StatCensus.readStat = type(hooks) == "table" and hooks.readStat or nil
    StatCensus.warm = type(hooks) == "table" and hooks.warm or nil
    StatCensus.isGear = type(hooks) == "table" and hooks.isGear or nil
end

local function ReadItemLevel(itemLink)
    local reader = _G and (_G.GetDetailedItemLevelInfo
        or (_G.C_Item and _G.C_Item.GetDetailedItemLevelInfo))
    if type(reader) ~= "function" then return 0 end
    local ok, itemLevel = pcall(reader, itemLink)
    return ok and math.floor(tonumber(itemLevel) or 0) or 0
end

--- Ajoute un exemplaire au brouillon de recensement en cours.
--
-- Seul l'equipement de metier entre : la table resterait autrement une copie de
-- l'inventaire entier dans les SavedVariables. Un exemplaire dont le tooltip
-- n'est pas encore lisible va dans le seau « statistique inconnue » -- il est
-- reel, il ne doit pas disparaitre, et il ne doit pas etre attribue au hasard.
function StatCensus.AddSample(counts, itemID, itemLink, quantity)
    itemID = tonumber(itemID)
    quantity = math.floor(tonumber(quantity) or 0)
    if type(counts) ~= "table" or not itemID or quantity <= 0 then return false end
    if type(StatCensus.isGear) == "function" and not StatCensus.isGear(itemID) then
        return false
    end
    local statKey
    if type(StatCensus.readStat) == "function" then
        local pending
        statKey, pending = StatCensus.readStat(itemID, itemLink)
        if pending and type(StatCensus.warm) == "function" then
            StatCensus.warm(itemID)
        end
    end
    local key = StatCensus.MakeKey(itemID, ReadItemLevel(itemLink), statKey)
    if not key then return false end
    counts[key] = (counts[key] or 0) + quantity
    return true
end
