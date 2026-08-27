-- YayaCore : implementations partagees par la suite d'addons Yaya.
--
-- Chaque addon gardait sa propre copie du formatage monetaire, du wrapper
-- TSM_API, du journal de debug et du chargement d'objet : huit variantes du
-- premier, quatre du deuxieme, neuf du troisieme. Un correctif devait donc etre
-- reporte a la main dans chaque addon.
--
-- Les addons consommateurs conservent leurs fonctions locales, dont le corps se
-- contente d'appeler ce module : les sites d'appel existants ne changent pas.

local ADDON_NAME = ...

local YayaCore = {
    version = 1,
}
_G.YayaCore = YayaCore

-- ---------------------------------------------------------------------------
-- Money : formatage monetaire
-- ---------------------------------------------------------------------------

local Money = {}
YayaCore.Money = Money

--- Formate un montant en cuivre avec l'affichage standard de WoW.
--
-- opts.zeroText     : texte renvoye pour un montant nul ou negatif (optionnel)
-- opts.clampNegative: ramene les montants negatifs a zero
-- opts.separateThousands : passe a GetMoneyString (defaut true)
function Money.Format(copper, opts)
    opts = opts or {}
    local value = tonumber(copper) or 0

    if opts.zeroText and value <= 0 then
        return opts.zeroText
    end
    if opts.clampNegative then
        value = math.max(0, value)
    end
    value = math.floor(value)

    if type(GetMoneyString) == "function" then
        local separate = opts.separateThousands
        if separate == nil then
            separate = true
        end
        return GetMoneyString(value, separate)
    end
    -- GetMoneyString manque sur certaines fenetres de chargement precoce.
    return tostring(value) .. " copper"
end

--- Renvoie le balisage de l'icone de piece d'or.
function Money.GetGoldIconMarkup()
    if type(CreateTextureMarkup) == "function" then
        return CreateTextureMarkup("Interface\\MoneyFrame\\UI-GoldIcon", 16, 16, 14, 14, 0, 1, 0, 1, 2, 0)
    end
    return "|TInterface\\MoneyFrame\\UI-GoldIcon:14:14:2:0|t"
end

--- Formate un montant en or uniquement, avec l'icone de piece.
--
-- Utilise par les listes ou la place manque pour l'argent et le cuivre.
function Money.FormatGoldOnly(copper, signed)
    local value = tonumber(copper) or 0
    local goldValue = math.floor(math.abs(value) / 10000)
    local amountText = type(BreakUpLargeNumbers) == "function"
        and BreakUpLargeNumbers(goldValue)
        or tostring(goldValue)
    local formatted = amountText .. Money.GetGoldIconMarkup()
    if signed and value < 0 then
        return "-" .. formatted
    end
    return formatted
end

--- Formate un montant de facon compacte (12.3k, 45g, 20s, 7c).
--
-- Destine aux affichages etroits comme le suivi de session.
function Money.FormatCompact(copper)
    local value = tonumber(copper) or 0
    local negative = value < 0
    local absCopper = math.abs(value)
    local goldValue = absCopper / 10000
    local text

    if goldValue >= 100000 then
        text = string.format("%.0fk", goldValue / 1000)
    elseif goldValue >= 10000 then
        text = string.format("%.1fk", goldValue / 1000)
    elseif goldValue >= 100 then
        text = string.format("%.0fg", goldValue)
    elseif goldValue >= 10 then
        text = string.format("%.1fg", goldValue)
    elseif absCopper >= 100 then
        text = string.format("%ds", math.floor(absCopper / 100))
    else
        text = string.format("%dc", absCopper)
    end

    if negative then
        return "-" .. text
    end
    return text
end

-- ---------------------------------------------------------------------------
-- Price : acces unifie a TSM_API
-- ---------------------------------------------------------------------------

local Price = {}
YayaCore.Price = Price

--- Indique si TSM expose les fonctions dont depend la tarification.
function Price.IsAvailable()
    return type(TSM_API) == "table"
        and type(TSM_API.ToItemString) == "function"
        and type(TSM_API.GetCustomPriceValue) == "function"
end

--- Convertit un identifiant, un lien ou une chaine en itemString TSM.
--
-- Accepte un nombre (itemID), un lien d'objet ou une chaine deja au format TSM.
function Price.ToItemString(item)
    if not Price.IsAvailable() then
        return nil
    end

    local candidate
    if type(item) == "number" then
        candidate = "i:" .. tostring(item)
    elseif type(item) == "string" then
        candidate = item
    else
        return nil
    end

    local ok, itemString = pcall(TSM_API.ToItemString, candidate)
    if not ok then
        return nil
    end
    return itemString
end

--- Renvoie la valeur d'une source de prix TSM, en cuivre.
--
-- Renvoie nil si TSM est absent, si l'objet est inconnu, ou si la source est
-- invalide : les appelants doivent traiter ce cas.
function Price.Get(item, source)
    local itemString = Price.ToItemString(item)
    if not itemString then
        return nil
    end

    local ok, value = pcall(TSM_API.GetCustomPriceValue, source or "dbmarket", itemString)
    if not ok then
        return nil
    end
    value = tonumber(value)
    if not value or value <= 0 then
        return nil
    end
    return value
end

-- ---------------------------------------------------------------------------
-- RingBuffer : journal borne sans recopie
-- ---------------------------------------------------------------------------

local RingBuffer = {}
YayaCore.RingBuffer = RingBuffer

--- Ajoute une entree a un journal borne.
--
-- Les addons purgeaient leur journal par table.remove(store, 1) repete, ce qui
-- recopie tout le tableau a chaque depassement : sur un journal de 400 entrees
-- c'est 400 deplacements par nouvelle ligne. Ici l'ecriture est en place.
--
-- La table peut deja contenir un journal lineaire ecrit par l'ancienne version :
-- tant qu'elle n'a pas atteint la limite, on continue de l'allonger.
--
-- Accepte n'importe quelle valeur d'entree : chaine formatee comme table
-- structuree, selon ce que stocke l'addon.
function RingBuffer.Push(store, entry, limit)
    if type(store) ~= "table" then
        return
    end
    limit = math.max(1, math.floor(tonumber(limit) or 200))

    local count = #store
    if count < limit then
        store[count + 1] = entry
        return
    end

    -- Au-dela de la limite, on recycle la case la plus ancienne.
    local cursor = (tonumber(store.cursor) or 0) % limit + 1
    store[cursor] = entry
    store.cursor = cursor

    -- Un journal herite d'une limite plus large est ramene a la nouvelle.
    for index = count, limit + 1, -1 do
        store[index] = nil
    end
end

--- Restitue un journal borne dans l'ordre chronologique.
function RingBuffer.Read(store, count)
    if type(store) ~= "table" then
        return {}
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

-- ---------------------------------------------------------------------------
-- Log : messages de chat et journal persistant
-- ---------------------------------------------------------------------------

local Log = {}
YayaCore.Log = Log

local DEFAULT_PREFIX_COLOR = "|cff00ff98"

--- Cree un journal pour un addon.
--
-- opts.prefix : nom affiche en tete des messages (defaut : nom de l'addon)
-- opts.color  : code couleur du prefixe
-- opts.limit  : nombre de lignes conservees dans le journal persistant
-- opts.store  : fonction renvoyant la table de stockage du journal
function Log.New(addonName, opts)
    opts = opts or {}
    local prefix = ("%s%s:|r "):format(opts.color or DEFAULT_PREFIX_COLOR, opts.prefix or addonName)
    local limit = tonumber(opts.limit) or 200

    local logger = {}

    function logger.Print(message)
        if type(DEFAULT_CHAT_FRAME) ~= "table" or type(DEFAULT_CHAT_FRAME.AddMessage) ~= "function" then
            return
        end
        DEFAULT_CHAT_FRAME:AddMessage(prefix .. tostring(message))
    end

    --- Ajoute une ligne horodatee au journal persistant.
    function logger.Append(message, tag)
        if type(opts.store) ~= "function" then
            return
        end
        local entry = ("[%s] %s%s"):format(
            date("%H:%M:%S"),
            tag and (tag .. " ") or "",
            tostring(message)
        )
        RingBuffer.Push(opts.store(), entry, limit)
    end

    --- Restitue le journal dans l'ordre chronologique.
    function logger.Read(count)
        if type(opts.store) ~= "function" then
            return {}
        end
        return RingBuffer.Read(opts.store(), count)
    end

    return logger
end

-- ---------------------------------------------------------------------------
-- Item : chargement des donnees d'objet
-- ---------------------------------------------------------------------------

local Item = {}
YayaCore.Item = Item

local pendingItemCallbacks = {}
local itemEventFrame

local function EnsureItemEventFrame()
    if itemEventFrame then
        return
    end
    itemEventFrame = CreateFrame("Frame")
    itemEventFrame:RegisterEvent("ITEM_DATA_LOAD_RESULT")
    itemEventFrame:SetScript("OnEvent", function(_, _, itemID, success)
        local callbacks = pendingItemCallbacks[itemID]
        if not callbacks then
            return
        end
        pendingItemCallbacks[itemID] = nil
        for _, callback in ipairs(callbacks) do
            pcall(callback, itemID, success == true)
        end
    end)
end

--- Demande le chargement des donnees d'un objet et rappelle a l'arrivee.
--
-- Le rappel est immediat si les donnees sont deja en cache. Les demandes
-- concurrentes pour un meme objet partagent une seule requete.
function Item.Load(itemID, callback)
    itemID = tonumber(itemID)
    if not itemID or itemID <= 0 then
        return false
    end

    if C_Item and type(C_Item.GetItemNameByID) == "function" and C_Item.GetItemNameByID(itemID) then
        if type(callback) == "function" then
            pcall(callback, itemID, true)
        end
        return true
    end

    if type(callback) == "function" then
        EnsureItemEventFrame()
        local callbacks = pendingItemCallbacks[itemID]
        if callbacks then
            callbacks[#callbacks + 1] = callback
        else
            pendingItemCallbacks[itemID] = { callback }
        end
    end

    if C_Item and type(C_Item.RequestLoadItemDataByID) == "function" then
        C_Item.RequestLoadItemDataByID(itemID)
    end
    return false
end

-- ---------------------------------------------------------------------------
-- Tooltip : ancrage et remplissage
-- ---------------------------------------------------------------------------

local Tooltip = {}
YayaCore.Tooltip = Tooltip

--- Branche une infobulle sur une frame.
--
-- provider(tooltip, frame) remplit l'infobulle ; renvoyer false l'annule.
-- opts.anchor : point d'ancrage GameTooltip (defaut ANCHOR_RIGHT)
function Tooltip.Attach(frame, provider, opts)
    if not frame or type(provider) ~= "function" then
        return
    end
    opts = opts or {}
    local anchor = opts.anchor or "ANCHOR_RIGHT"

    frame:SetScript("OnEnter", function(self)
        if not GameTooltip then
            return
        end
        GameTooltip:SetOwner(self, anchor)
        GameTooltip:ClearLines()
        local ok, result = pcall(provider, GameTooltip, self)
        if not ok or result == false then
            GameTooltip:Hide()
            return
        end
        GameTooltip:Show()
    end)

    frame:SetScript("OnLeave", function()
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)
end

-- ---------------------------------------------------------------------------
-- Schedule : planification annulable
-- ---------------------------------------------------------------------------

local Schedule = {}
YayaCore.Schedule = Schedule

--- Cree un planificateur dont chaque nouvelle demande annule la precedente.
--
-- Reprend le motif a jeton deja utilise par YayaWeeklyTracker : C_Timer.After
-- n'etant pas annulable, on compare un jeton a l'echeance pour ignorer les
-- rappels perimes.
function Schedule.NewToken()
    local scheduler = { token = 0 }

    function scheduler.Cancel()
        scheduler.token = scheduler.token + 1
    end

    function scheduler.After(delay, callback)
        if type(callback) ~= "function" then
            return
        end
        scheduler.token = scheduler.token + 1
        local token = scheduler.token
        if not (C_Timer and type(C_Timer.After) == "function") then
            callback()
            return
        end
        C_Timer.After(delay or 0, function()
            if scheduler.token == token then
                callback()
            end
        end)
    end

    return scheduler
end
