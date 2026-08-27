-- YayaErrorLog : capture persistante des erreurs Lua et des actions bloquees.
--
-- Pourquoi cet addon existe. Le client ne laisse aucune trace exploitable des
-- fautes d'execution : scriptErrors vaut 0 par defaut, donc le texte des
-- erreurs Lua n'est jamais affiche, et Logs/FrameXML.log ne consigne que les
-- erreurs de *chargement*. Le popup ADDON_ACTION_FORBIDDEN nomme bien l'addon
-- fautif, mais le nom de la fonction protegee et la pile d'appel disparaissent
-- avec la fenetre. Il ne reste donc rien a lire apres coup.
--
-- Pourquoi le prefixe "!" dans le nom du dossier. WoW charge les addons par
-- ordre alphabetique, et un gestionnaire d'erreurs n'attrape que ce qui suit
-- son installation. Sans le "!", cet addon se chargerait apres AbundanceTracker
-- et manquerait les fautes commises pendant son chunk et dans son handler
-- ADDON_LOADED. C'est la convention de !BugGrabber, pour la meme raison.
--
-- Le journal vit dans les SavedVariables : il est relisible depuis le disque
-- apres la session. Attention, WoW n'ecrit ce fichier qu'au /reload ou a la
-- deconnexion.

local ADDON_NAME = ...

local YayaErrorLog = {}
_G.YayaErrorLog = YayaErrorLog

-- Entrees detaillees conservees. Chacune porte une pile complete, d'ou une
-- limite plus basse que les journaux de la suite Yaya.
local ENTRY_LIMIT = 250
-- Profondeur de pile capturee. La ligne interessante est souvent loin quand la
-- faute traverse le dispatcher d'evenements du client.
local STACK_DEPTH = 30
-- Au-dela de ce nombre d'exemplaires, un incident recurrent n'ajoute plus
-- d'entree : seul son compteur augmente. Sans cela une faute dans un ticker
-- 0,5 s noierait le journal en une minute.
local SAMPLES_PER_SIGNATURE = 3
-- Garde-fou sur le nombre d'incidents distincts suivis, pour qu'un message
-- portant une part variable non normalisee ne fasse pas croitre la table sans
-- fin.
local MAX_SIGNATURES = 120
local SIGNATURE_MAX_LENGTH = 200
local SESSION_LIMIT = 60
-- Motif reconnaissant les frames de cet addon dans une pile, pour les ecarter :
-- son gestionnaire d'erreurs et son handler d'evenement figurent en tete de
-- pile, et les retenir ferait accuser le journal a la place du fautif.
local SELF_NAME = "YayaErrorLog"

-- ---------------------------------------------------------------------------
-- Logique pure : normalisation, signature, lecture de pile
-- ---------------------------------------------------------------------------

--- Retire d'un message ce qui change d'une occurrence a l'autre.
--
-- Deux occurrences du meme bug doivent produire la meme signature : sans cela
-- les adresses de table et les compteurs empecheraient tout regroupement, et
-- le journal ne dirait pas si une faute se produit une fois ou mille.
local function NormalizeMessage(message)
    local text = tostring(message or "")
    text = text:gsub("0[xX]%x+", "0x?")
    text = text:gsub("%d+", "#")
    return text
end
YayaErrorLog.NormalizeMessage = NormalizeMessage

--- Renvoie la premiere ligne de pile qui pointe vers un fichier d'addon tiers.
--
-- C'est la donnee decisive du diagnostic : elle nomme le fichier et la ligne
-- responsables, la ou le popup du client ne nomme que l'addon. Les frames de
-- cet addon sont sautees, sinon la capture s'accuserait elle-meme : c'est son
-- gestionnaire d'erreurs qui ouvre la pile.
local function FirstAddonFrame(stack)
    for line in tostring(stack or ""):gmatch("[^\r\n]+") do
        -- Le client encadre le chemin de crochets : "[Interface/AddOns/X.lua]:42".
        -- Chemin et numero sont captures separement puis recomposes, sinon le
        -- crochet fermant reste collee au chemin.
        local path, lineNumber = line:match("([Ii]nterface[\\/][Aa]dd[Oo]ns[\\/][^%]:]+)%]?:(%d+)")
        if path and lineNumber and not path:find(SELF_NAME, 1, true) then
            return ("%s:%s"):format((path:gsub("\\", "/")), lineNumber)
        end
    end
    return nil
end
YayaErrorLog.FirstAddonFrame = FirstAddonFrame

--- Identifiant stable d'un incident, utilise comme cle de comptage.
local function BuildSignature(kind, message, stack)
    local signature = table.concat({
        tostring(kind or "?"),
        NormalizeMessage(message),
        FirstAddonFrame(stack) or "?",
    }, "|")
    if #signature > SIGNATURE_MAX_LENGTH then
        signature = signature:sub(1, SIGNATURE_MAX_LENGTH)
    end
    return signature
end
YayaErrorLog.BuildSignature = BuildSignature

--- Rend une entree lisible sur une ligne de chat.
local function Describe(entry)
    if type(entry) ~= "table" then
        return tostring(entry)
    end
    local parts = { ("[%s] %s"):format(entry.clock or "?", entry.kind or "?") }
    if entry.addon then
        parts[#parts + 1] = "addon=" .. tostring(entry.addon)
    end
    if entry.protectedFunction then
        parts[#parts + 1] = "fonction=" .. tostring(entry.protectedFunction)
    end
    if entry.message then
        parts[#parts + 1] = tostring(entry.message)
    end
    if entry.frame then
        parts[#parts + 1] = "-> " .. tostring(entry.frame)
    end
    return table.concat(parts, " ")
end
YayaErrorLog.Describe = Describe

-- ---------------------------------------------------------------------------
-- Journal borne : delegue a YayaCore, avec repli autonome
-- ---------------------------------------------------------------------------

-- Le repli existe parce que le profil d'addons minimal qui sert a isoler un
-- addon suspect ne charge pas forcement YayaCore : cet addon doit rester
-- utilisable seul.

local function GetRingBuffer()
    local core = _G.YayaCore
    if type(core) == "table" and type(core.RingBuffer) == "table" then
        return core.RingBuffer
    end
    return nil
end

local function PushBounded(store, entry, limit)
    if type(store) ~= "table" then
        return
    end
    limit = math.max(1, math.floor(tonumber(limit) or ENTRY_LIMIT))

    local ring = GetRingBuffer()
    if ring and type(ring.Push) == "function" then
        ring.Push(store, entry, limit)
        return
    end

    local count = #store
    if count < limit then
        store[count + 1] = entry
        return
    end
    local cursor = (tonumber(store.cursor) or 0) % limit + 1
    store[cursor] = entry
    store.cursor = cursor
    for index = count, limit + 1, -1 do
        store[index] = nil
    end
end
YayaErrorLog.PushBounded = PushBounded

local function ReadBounded(store, count)
    if type(store) ~= "table" then
        return {}
    end

    local ring = GetRingBuffer()
    if ring and type(ring.Read) == "function" then
        return ring.Read(store, count)
    end

    local total = #store
    local ordered = {}
    local cursor = tonumber(store.cursor)
    if cursor and cursor >= 1 and cursor <= total then
        for index = 1, total do
            ordered[index] = store[(cursor + index - 1) % total + 1]
        end
    else
        for index = 1, total do
            ordered[index] = store[index]
        end
    end
    if not count or count >= #ordered then
        return ordered
    end
    local tail = {}
    for index = #ordered - count + 1, #ordered do
        tail[#tail + 1] = ordered[index]
    end
    return tail
end
YayaErrorLog.ReadBounded = ReadBounded

-- ---------------------------------------------------------------------------
-- Enregistrement
-- ---------------------------------------------------------------------------

local db
-- Les fautes survenues avant ADDON_LOADED sont mises de cote : le gestionnaire
-- d'erreurs est installe au chargement du chunk, bien avant que les
-- SavedVariables soient disponibles.
local pendingEntries = {}
-- Verrou de reentrance. Une faute levee dans l'enregistrement lui-meme
-- repasserait par le gestionnaire d'erreurs et boucherait la pile.
local recording = false

local function NewEntry(kind, fields)
    local stack = fields.stack
    return {
        kind = kind,
        stamp = (type(time) == "function") and time() or nil,
        clock = (type(date) == "function") and date("%H:%M:%S") or nil,
        addon = fields.addon and tostring(fields.addon) or nil,
        protectedFunction = fields.protectedFunction and tostring(fields.protectedFunction) or nil,
        message = fields.message and tostring(fields.message) or nil,
        frame = FirstAddonFrame(stack),
        stack = stack and tostring(stack) or nil,
        zone = fields.zone,
        combat = fields.combat,
        signature = BuildSignature(kind, fields.message or fields.protectedFunction, stack),
    }
end
YayaErrorLog.NewEntry = NewEntry

local function CountSignatures()
    local count = 0
    if db and type(db.counters) == "table" then
        for _ in pairs(db.counters) do
            count = count + 1
        end
    end
    return count
end

local function StoreEntry(entry)
    if not db then
        -- Meme borne que le journal persistant : une boucle de fautes avant
        -- ADDON_LOADED ne doit pas gonfler indefiniment.
        PushBounded(pendingEntries, entry, ENTRY_LIMIT)
        return
    end

    db.counters = db.counters or {}
    local counter = db.counters[entry.signature]
    if not counter then
        if CountSignatures() >= MAX_SIGNATURES then
            db.droppedSignatures = (db.droppedSignatures or 0) + 1
            return
        end
        counter = {
            count = 0,
            first = entry.stamp,
            kind = entry.kind,
            frame = entry.frame,
            sample = entry.message or entry.protectedFunction,
        }
        db.counters[entry.signature] = counter
    end
    counter.count = counter.count + 1
    counter.last = entry.stamp

    if counter.count <= SAMPLES_PER_SIGNATURE then
        db.entries = db.entries or {}
        PushBounded(db.entries, entry, ENTRY_LIMIT)
    end
end

local function Record(kind, fields)
    StoreEntry(NewEntry(kind, fields or {}))
end
YayaErrorLog.Record = Record

--- Enregistre sans jamais laisser echapper d'erreur.
local function SafeRecord(kind, fields)
    if recording then
        return
    end
    recording = true
    pcall(Record, kind, fields)
    recording = false
end
YayaErrorLog.SafeRecord = SafeRecord

--- Rattache une table de stockage, pour les tests hors du jeu.
function YayaErrorLog.SetStore(store)
    db = store
    return db
end

--- Liste les incidents suivis, du plus frequent au moins frequent.
function YayaErrorLog.OrderedCounters()
    local ordered = {}
    if not db or type(db.counters) ~= "table" then
        return ordered
    end
    for signature, counter in pairs(db.counters) do
        ordered[#ordered + 1] = { signature = signature, counter = counter }
    end
    table.sort(ordered, function(a, b)
        local left, right = a.counter.count or 0, b.counter.count or 0
        if left ~= right then
            return left > right
        end
        return a.signature < b.signature
    end)
    return ordered
end

-- ---------------------------------------------------------------------------
-- Installation en jeu
-- ---------------------------------------------------------------------------

-- Garde volontaire : le fichier doit se charger hors du jeu pour les tests
-- unitaires, qui n'exercent que la logique pure ci-dessus.
if type(CreateFrame) ~= "function" then
    return
end

local function Print(message)
    if type(DEFAULT_CHAT_FRAME) == "table" and type(DEFAULT_CHAT_FRAME.AddMessage) == "function" then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff8040YayaErrorLog|r: " .. tostring(message))
    end
end

-- La pile est capturee largement, depuis le premier niveau : les frames de cet
-- addon qui s'y trouvent sont ecartees a la lecture par FirstAddonFrame. Ajuster
-- un niveau exact ici serait fragile, puisqu'il differe selon que l'on vient du
-- gestionnaire d'erreurs ou d'un handler d'evenement.
local function CaptureStack()
    if type(debugstack) ~= "function" then
        return nil
    end
    return debugstack(1, STACK_DEPTH, STACK_DEPTH)
end

local function CurrentZone()
    if type(GetZoneText) == "function" then
        local zone = GetZoneText()
        if zone and zone ~= "" then
            return zone
        end
    end
    return nil
end

local function InCombat()
    return type(InCombatLockdown) == "function" and InCombatLockdown() and true or false
end

--- Rassemble le contexte d'un incident sans jamais pouvoir lever.
--
-- Cette collecte s'execute a l'interieur du gestionnaire d'erreurs global : une
-- faute ici, meme improbable, laisserait le gestionnaire inutilisable pour toute
-- la session. Chaque source est donc isolee, et son echec coute au pire un champ
-- manquant.
local function SafeContext()
    local context = {}
    local ok, value = pcall(CaptureStack)
    context.stack = ok and value or nil
    ok, value = pcall(CurrentZone)
    context.zone = ok and value or nil
    ok, value = pcall(InCombat)
    context.combat = ok and value or nil
    return context
end

local function AdoptDB()
    YayaErrorLogDB = YayaErrorLogDB or {}
    db = YayaErrorLogDB
    db.entries = db.entries or {}
    db.counters = db.counters or {}
    db.sessions = db.sessions or {}

    -- Les fautes mises de cote avant ADDON_LOADED rejoignent le journal, dans
    -- l'ordre ou elles se sont produites.
    for _, entry in ipairs(ReadBounded(pendingEntries)) do
        StoreEntry(entry)
    end
    pendingEntries = {}
end

local function RecordSession()
    if not db then
        return
    end
    local name = (type(UnitName) == "function") and UnitName("player") or nil
    local realm = (type(GetRealmName) == "function") and GetRealmName() or nil
    PushBounded(db.sessions, {
        stamp = time(),
        clock = date("%Y-%m-%d %H:%M:%S"),
        character = (name and realm) and (name .. "-" .. realm) or name,
    }, SESSION_LIMIT)
end

-- Gestionnaire d'erreurs chaine : on enveloppe le precedent sans le remplacer,
-- pour ne priver ni un eventuel BugSack ni le dialogue du client.
local previousHandler = (type(geterrorhandler) == "function") and geterrorhandler() or nil
if type(seterrorhandler) == "function" then
    seterrorhandler(function(err)
        local context = SafeContext()
        context.message = err
        SafeRecord("lua-error", context)
        if previousHandler then
            return previousHandler(err)
        end
    end)
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
-- Le popup qui propose de desactiver un addon vient de ADDON_ACTION_FORBIDDEN.
-- ADDON_ACTION_BLOCKED est capture aussi : il precede souvent la faute fatale
-- et nomme la premiere fonction refusee.
frame:RegisterEvent("ADDON_ACTION_FORBIDDEN")
frame:RegisterEvent("ADDON_ACTION_BLOCKED")
frame:SetScript("OnEvent", function(_, event, arg1, arg2)
    if event == "ADDON_LOADED" then
        if arg1 == ADDON_NAME then
            AdoptDB()
        end
        return
    end
    if event == "PLAYER_LOGIN" then
        RecordSession()
        return
    end
    local context = SafeContext()
    context.addon = arg1
    context.protectedFunction = arg2
    SafeRecord(event, context)
end)

-- ---------------------------------------------------------------------------
-- Fenetre de relecture copiable
-- ---------------------------------------------------------------------------

local dumpFrame, dumpEdit

local function EnsureDumpFrame()
    if dumpFrame then
        return
    end

    dumpFrame = CreateFrame("Frame", "YayaErrorLogDumpFrame", UIParent, "BackdropTemplate")
    dumpFrame:SetSize(760, 460)
    dumpFrame:SetPoint("CENTER")
    dumpFrame:SetFrameStrata("DIALOG")
    dumpFrame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    dumpFrame:SetBackdropColor(0.05, 0.05, 0.08, 0.95)
    dumpFrame:SetMovable(true)
    dumpFrame:EnableMouse(true)
    dumpFrame:SetClampedToScreen(true)
    dumpFrame:RegisterForDrag("LeftButton")
    dumpFrame:SetScript("OnDragStart", dumpFrame.StartMoving)
    dumpFrame:SetScript("OnDragStop", dumpFrame.StopMovingOrSizing)

    local title = dumpFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -10)
    title:SetText("YayaErrorLog")

    local close = CreateFrame("Button", nil, dumpFrame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -2, -2)

    local scroll = CreateFrame("ScrollFrame", "YayaErrorLogDumpScroll", dumpFrame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 14, -36)
    scroll:SetPoint("BOTTOMRIGHT", -32, 14)

    dumpEdit = CreateFrame("EditBox", nil, scroll)
    dumpEdit:SetMultiLine(true)
    dumpEdit:SetAutoFocus(false)
    dumpEdit:SetFontObject("ChatFontNormal")
    dumpEdit:SetWidth(700)
    dumpEdit:SetScript("OnEscapePressed", function()
        dumpFrame:Hide()
    end)
    scroll:SetScrollChild(dumpEdit)
end

local function BuildReport()
    local lines = { ("YayaErrorLog - %s"):format(date("%Y-%m-%d %H:%M:%S")) }
    if not db then
        lines[#lines + 1] = "Journal indisponible (SavedVariables pas encore charges)."
        return table.concat(lines, "\n")
    end

    local ordered = YayaErrorLog.OrderedCounters()
    local total = 0
    for _, item in ipairs(ordered) do
        total = total + (item.counter.count or 0)
    end
    lines[#lines + 1] = ("%d incident(s), %d type(s) distinct(s)."):format(total, #ordered)
    if db.droppedSignatures then
        lines[#lines + 1] = ("Types distincts non suivis (plafond atteint) : %d"):format(db.droppedSignatures)
    end

    lines[#lines + 1] = ""
    lines[#lines + 1] = "--- Recapitulatif ---"
    for _, item in ipairs(ordered) do
        lines[#lines + 1] = ("x%-5d [%s] %s %s"):format(
            item.counter.count or 0,
            item.counter.kind or "?",
            item.counter.frame or "?",
            item.counter.sample or ""
        )
    end

    lines[#lines + 1] = ""
    lines[#lines + 1] = "--- Detail avec piles ---"
    for _, entry in ipairs(ReadBounded(db.entries)) do
        lines[#lines + 1] = Describe(entry)
        if entry.stack then
            lines[#lines + 1] = entry.stack
        end
        lines[#lines + 1] = ""
    end

    return table.concat(lines, "\n")
end

-- ---------------------------------------------------------------------------
-- Sonde : pourquoi un RegisterEvent est-il refuse ?
-- ---------------------------------------------------------------------------

-- En 12.1, RegisterEvent porte ChecksForbiddenAspects et AddsForbiddenAspects
-- sur l'aspect EventRegistrations (« Restricts querying or modifying registered
-- script events for this object »). Un refus a donc deux causes possibles : la
-- frame ciblee porte cet aspect interdit, ou l'evenement demande est restreint.
-- La sonde separe les deux, ce que la pile d'appel seule ne permet pas.

-- Liste d'ALL_EVENTS d'AbundanceTracker, telle qu'enregistree par sa fonction
-- TryRegisterEvents.
local PROBE_EVENTS = {
    "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD",
    "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA",
    "UPDATE_UI_WIDGET", "UNIT_AURA", "UNIT_POWER_UPDATE",
    "UNIT_POWER_BAR_SHOW", "UNIT_POWER_BAR_HIDE",
    "UNIT_SPELLCAST_SUCCEEDED", "COMBAT_LOG_EVENT_UNFILTERED",
    "SCENARIO_UPDATE", "SCENARIO_CRITERIA_UPDATE", "CRITERIA_UPDATE",
    "PLAYER_LOGOUT", "SCENARIO_COMPLETED",
    "CHAT_MSG_MONSTER_YELL", "CHAT_MSG_MONSTER_SAY",
}

local probeFrame

--- Teste si une frame nommee accepte encore les requetes d'evenements.
--
-- IsEventRegistered porte le meme controle d'aspect que RegisterEvent mais ne
-- modifie rien : le test est donc non destructif et ne declenche aucun popup
-- supplementaire.
local function ProbeFrameAspect(frameName)
    local target = _G[frameName]
    if type(target) ~= "table" or type(target.IsEventRegistered) ~= "function" then
        return nil, "frame absente ou sans IsEventRegistered"
    end
    local ok, err = pcall(target.IsEventRegistered, target, "PLAYER_LOGIN")
    if ok then
        return true
    end
    return false, tostring(err)
end

--- Tente chaque evenement sur une frame neuve et renvoie ceux qui sont refuses.
local function ProbeEvents()
    if not probeFrame then
        probeFrame = CreateFrame("Frame")
    end
    local refused = {}
    for _, event in ipairs(PROBE_EVENTS) do
        local registered = false
        if pcall(probeFrame.RegisterEvent, probeFrame, event) then
            local ok, value = pcall(probeFrame.IsEventRegistered, probeFrame, event)
            registered = (ok and value) and true or false
        end
        if not registered then
            refused[#refused + 1] = event
        end
        pcall(probeFrame.UnregisterEvent, probeFrame, event)
    end
    return refused
end

-- ---------------------------------------------------------------------------
-- Commandes
-- ---------------------------------------------------------------------------

SLASH_YAYAERRORLOG1 = "/yerr"
SLASH_YAYAERRORLOG2 = "/yayaerrorlog"
SlashCmdList["YAYAERRORLOG"] = function(input)
    local command = (input or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")

    if command == "clear" then
        if db then
            db.entries = {}
            db.counters = {}
            db.droppedSignatures = nil
        end
        Print("Journal vide.")
        return
    end

    if command == "dump" then
        EnsureDumpFrame()
        dumpEdit:SetText(BuildReport())
        dumpEdit:SetCursorPosition(0)
        dumpFrame:Show()
        return
    end

    if command == "probe" then
        local ok, detail = ProbeFrameAspect("AbundanceTrackerFrame")
        if ok == nil then
            Print("AbundanceTrackerFrame : " .. tostring(detail))
        elseif ok then
            Print("AbundanceTrackerFrame : accessible, l'aspect EventRegistrations n'est pas pose.")
        else
            Print("AbundanceTrackerFrame : REFUSEE, la frame porte l'aspect interdit -> " .. tostring(detail))
        end

        local refused = ProbeEvents()
        if #refused == 0 then
            Print(("Les %d evenements passent sur une frame neuve."):format(#PROBE_EVENTS))
        else
            Print("Evenements refuses sur une frame neuve : " .. table.concat(refused, ", "))
        end
        return
    end

    if command == "test" then
        -- Verifie la chaine de capture de bout en bout : sans cela, un journal
        -- vide ne permet pas de distinguer "aucune faute" de "instrumentation
        -- inoperante".
        C_Timer.After(0, function()
            error("YayaErrorLog : erreur de test volontaire")
        end)
        Print("Erreur de test declenchee ; verifie avec /yerr.")
        return
    end

    if not db then
        Print("Journal indisponible.")
        return
    end

    local ordered = YayaErrorLog.OrderedCounters()
    local total = 0
    for _, item in ipairs(ordered) do
        total = total + (item.counter.count or 0)
    end
    Print(("%d incident(s) sur %d type(s) distinct(s). /yerr dump pour le detail copiable."):format(total, #ordered))
    for index = 1, math.min(8, #ordered) do
        local counter = ordered[index].counter
        Print(("  x%d [%s] %s %s"):format(
            counter.count or 0,
            counter.kind or "?",
            counter.frame or "?",
            counter.sample or ""
        ))
    end
end
