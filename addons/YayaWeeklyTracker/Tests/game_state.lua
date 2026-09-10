-- Environnement realiste : un alchimiste Midnight equipe, pour exercer le scan
-- d'equipement de metier de bout en bout.
local ALCH_SKILL_LINE, ALCH_PROFESSION_ID = 2906, 3
local TOOL_SLOT, GEAR_A, GEAR_B = 20, 21, 22

local ITEMS = {
    [245778] = { name = "Sin'dorei Alchemist's Mixing Rod", quality = 3,
                 equipLoc = "INVTYPE_PROFESSION_TOOL", skillLine = ALCH_SKILL_LINE, stat = "Ingéniosité" },
    [239635] = { name = "Elegant Artisan's Alchemy Coveralls", quality = 3,
                 equipLoc = "INVTYPE_PROFESSION_GEAR", skillLine = ALCH_SKILL_LINE },
    [244626] = { name = "Sin'dorei Alchemist's Hat", quality = 3,
                 equipLoc = "INVTYPE_PROFESSION_GEAR", skillLine = ALCH_SKILL_LINE },
}

local EQUIPPED = {
    [TOOL_SLOT] = { itemID = 245778, itemLevel = 232 },
    [GEAR_A] = { itemID = 239635, itemLevel = 206 },
}

local function LinkFor(itemID) return "|cffa335ee|Hitem:" .. itemID .. "::::::::90:104|h[x]|h|r" end
local function IdFromLink(v)
    if type(v) == "number" then return v end
    return tonumber(tostring(v):match("item:(%d+)"))
end

function GetProfessions() return 1, nil, nil, nil, nil end
function GetProfessionInfo(index)
    if index == 1 then
        return "Midnight Alchemy", nil, 100, 100, nil, nil, 171
    end
end

C_TradeSkillUI.GetProfessionInfoBySkillLineID = function(skillLineID)
    if skillLineID == ALCH_SKILL_LINE then
        return {
            professionID = ALCH_SKILL_LINE,
            profession = ALCH_PROFESSION_ID,
            parentProfessionID = 171,
            professionName = "Midnight Alchemy",
            parentProfessionName = "Alchemy",
            skillLevel = 100,
            maxSkillLevel = 100,
        }
    end
end
C_TradeSkillUI.GetProfessionSkillLineID = function(base)
    if base == 171 then return ALCH_SKILL_LINE end
end
C_TradeSkillUI.GetProfessionSlots = function(professionID)
    if professionID == ALCH_PROFESSION_ID then
        return { TOOL_SLOT, GEAR_A, GEAR_B }
    end
    return {}
end
C_TradeSkillUI.GetSkillLineForGear = function(v)
    local item = ITEMS[IdFromLink(v)]
    return item and item.skillLine or nil
end

function GetInventoryItemLink(_, slot)
    local slotData = EQUIPPED[slot]
    return slotData and LinkFor(slotData.itemID) or nil
end
function GetInventoryItemID(_, slot)
    local slotData = EQUIPPED[slot]
    return slotData and slotData.itemID or nil
end
function GetItemInfo(v)
    local item = ITEMS[IdFromLink(v)]
    if not item then return nil end
    return item.name, LinkFor(IdFromLink(v)), item.quality, 232
end
function GetItemInfoInstant(v)
    local id = IdFromLink(v)
    local item = ITEMS[id]
    if not item then return nil end
    return id, nil, nil, item.equipLoc
end
function GetDetailedItemLevelInfo(v)
    for slot, slotData in pairs(EQUIPPED) do
        if LinkFor(slotData.itemID) == v then
            return slotData.itemLevel, false, slotData.itemLevel
        end
    end
    local item = ITEMS[IdFromLink(v)]
    if item then
        return 232, false, 232
    end
    return nil, false, nil
end
C_Item.GetItemInfoInstant = GetItemInfoInstant
C_Item.GetItemQualityByID = function(id)
    local item = ITEMS[id]
    return item and item.quality or nil
end
C_Item.IsBound = function() return true end
C_Item.GetItemCount = function() return 0 end

C_TooltipInfo.GetHyperlink = function(link)
    local item = ITEMS[IdFromLink(link)]
    if not item then return nil end
    local lines = {
        { leftText = item.name },
        { leftText = "Niveau d'objet 232" },
    }
    if item.stat then
        lines[#lines + 1] = { leftText = "+303 " .. item.stat }
    end
    return { lines = lines }
end

ITEM_MOD_RESOURCEFULNESS_SHORT = "Ingéniosité"
ITEM_MOD_INGENUITY_SHORT = "Inventivité"
ITEM_MOD_MULTICRAFT_SHORT = "Fabrication multiple"
ITEM_MOD_PERCEPTION_SHORT = "Perception"
ITEM_MOD_FINESSE_SHORT = "Finesse"
ITEM_MOD_DEFTNESS_SHORT = "Adresse"
ITEM_MOD_CRAFTING_SPEED_SHORT = "Vitesse d’artisanat"

-- ------------------------------------------------------- sacs et YayaQueue
-- Outils de rechange en sac : c'est le chemin ou la conformite d'un outil est
-- lue sur le lien unique d'un exemplaire non equipe.
ITEMS[245777] = { name = "Hobbyist Alchemist's Mixing Rod", quality = 2,
                  equipLoc = "INVTYPE_PROFESSION_TOOL", skillLine = ALCH_SKILL_LINE,
                  stat = "Ingéniosité" }
local BAG_CONTENT = {
    [0] = {
        [1] = { itemID = 245778, itemLevel = 206, stat = "Fabrication multiple" },
        [2] = { itemID = 245777, itemLevel = 232 },
        [3] = { itemID = 239635, itemLevel = 232 },
        -- Un exemplaire de l'accessoire vise dort deja en sac. Sa taille de
        -- pile n'est pas renseignee par cette doublure, exactement comme un
        -- objet pas encore en cache cote client : la destination ne doit pas
        -- pour autant le prendre pour une pile a completer.
        [4] = { itemID = 244626, itemLevel = 232 },
    },
}

local function BagLink(itemID) return "|cffa335ee|Hitem:" .. itemID .. "::::::::90:105|h[bag]|h|r" end

C_Container.GetContainerNumSlots = function(bag)
    local content = BAG_CONTENT[bag]
    if not content then return 0 end
    return 7
end
C_Container.GetContainerItemID = function(bag, slot)
    local entry = BAG_CONTENT[bag] and BAG_CONTENT[bag][slot]
    return entry and entry.itemID or nil
end
C_Container.GetContainerItemLink = function(bag, slot)
    local entry = BAG_CONTENT[bag] and BAG_CONTENT[bag][slot]
    return entry and BagLink(entry.itemID) or nil
end
C_Container.GetContainerItemInfo = function(bag, slot)
    local entry = BAG_CONTENT[bag] and BAG_CONTENT[bag][slot]
    if not entry then return nil end
    return { itemID = entry.itemID, stackCount = 1, hyperlink = BagLink(entry.itemID) }
end
function GetContainerNumSlots(bag) return C_Container.GetContainerNumSlots(bag) end

-- Un lien de sac doit rendre son propre ilvl et sa propre stat.
local previousDetailed = GetDetailedItemLevelInfo
function GetDetailedItemLevelInfo(v)
    for bag, slots in pairs(BAG_CONTENT) do
        for slot, entry in pairs(slots) do
            if BagLink(entry.itemID) == v then
                return entry.itemLevel, false, entry.itemLevel
            end
        end
    end
    return previousDetailed(v)
end

local previousTooltip = C_TooltipInfo.GetHyperlink
C_TooltipInfo.GetHyperlink = function(link)
    for bag, slots in pairs(BAG_CONTENT) do
        for slot, entry in pairs(slots) do
            if BagLink(entry.itemID) == link then
                local item = ITEMS[entry.itemID]
                local lines = { { leftText = item and item.name or "?" } }
                local stat = entry.stat or (item and item.stat)
                if stat then
                    lines[#lines + 1] = { leftText = "+303 " .. stat }
                end
                return { lines = lines }
            end
        end
    end
    return previousTooltip(link)
end

-- Sans stock de banque d'aventuriers connu, le plan d'achat des enchantements
-- reste a zero par prudence : rien ne dit que l'objet n'y dort pas deja. TSM
-- est la source de ce stock hors ouverture de banque, et l'utilisateur l'a
-- toujours charge : la doublure rend donc un stock connu et vide.
TSM_API = {
    ToItemString = function(value) return value end,
    GetWarbankQuantity = function() return 0 end,
}

-- Bascule d'outillage rejouable par les tests : l'exemplaire Multicrafting
-- passe a l'equipement au rang maximal, et un exemplaire Resourcefulness
-- conforme prend sa place en sac. C'est l'etat d'un alchimiste qui vient de
-- multicrafter, YayaQueue ayant renvoye l'outil sortant dans les sacs.
function EquipMulticraftToolFixture()
    ITEMS[245778].stat = "Fabrication multiple"
    BAG_CONTENT[0][1] = { itemID = 245778, itemLevel = 232, stat = "Ingéniosité" }
end

QUEUE_CALLS = {}
YayaQueueAPI = {
    -- La signature suit celle de l'addon : la variante est le quatrieme
    -- argument, et c'est elle qui distingue deux demandes du meme itemID.
    AddItem = function(itemID, quantity, itemName, variant)
        QUEUE_CALLS[#QUEUE_CALLS + 1] = ("AddItem %s x%s %s"):format(
            tostring(itemID),
            tostring(quantity),
            variant
                and (tostring(variant.statKey or "rank") .. ":" .. tostring(variant.minItemLevel))
                or "sans-variante")
        return true
    end,
    RemoveItem = function(itemID, quantity)
        QUEUE_CALLS[#QUEUE_CALLS + 1] = ("RemoveItem %s x%s"):format(tostring(itemID), tostring(quantity))
        return true, quantity
    end,
    GetDirectItemQuantity = function() return 0 end,
    Refresh = function() return true end,
    IsReady = function() return true end,
}

-- ---------------------------------------------------------------- Warbank
-- La banque de compte demarre VIDE : les assertions de non-regression du plan
-- d'achat doivent voir exactement l'etat d'avant, ou rien ne dort en banque.
-- `FillWarbankFixture` la garnit ensuite, une fois ces assertions passees.
local WARBANK_BAGS = { 13, 14, 15, 16, 17 }
local WARBANK_CONTENT = {}
local WARBANK_OPEN = false

-- Un exemplaire de la Warbank porte son propre lien : c'est lui qui distingue
-- deux outils du meme itemID par leur statistique et leur rang.
local function WarbankLink(bagID, slotIndex, itemID)
    return ("|cffa335ee|Hitem:%d::::::::90:1%d%d|h[wb]|h|r"):format(itemID, bagID, slotIndex)
end

local function WarbankEntry(bagID, slotIndex)
    local tab = WARBANK_CONTENT[bagID]
    return tab and tab[slotIndex] or nil
end

function FillWarbankFixture()
    WARBANK_CONTENT = {
        -- Marchandise : deux parchemins Multicraft, pas d'identite a verifier.
        [13] = { [1] = { itemID = 243995, stackCount = 2 } },
        [14] = {
            -- Outil Resourcefulness au rang maximal : satisfait la variante.
            [1] = { itemID = 245778, itemLevel = 232, stat = "Ingéniosité" },
            -- Meme itemID, mauvaise stat ET rang insuffisant : ne satisfait rien.
            [2] = { itemID = 245778, itemLevel = 206, stat = "Fabrication multiple" },
            -- Accessoire au rang exige : la variante ne porte que le rang.
            [3] = { itemID = 244626, itemLevel = 232 },
        },
        -- Exemplaire dont le client ne rend pas le lien : indecis, jamais
        -- « absent » ni « present ».
        [15] = { [1] = { itemID = 245778, noLink = true } },
        -- Traite d'alchimie.
        [16] = { [1] = { itemID = 245755, stackCount = 3 } },
    }
end

function OpenWarbankFixture()
    WARBANK_OPEN = true
    BankFrame.__shown = true
    BankFrame.__activeBankType = Enum.BankType.Account
end

function CloseWarbankFixture()
    WARBANK_OPEN = false
    BankFrame.__shown = false
    BankFrame.__activeBankType = nil
end

-- Fait mentir l'instantane : le compte vivant grimpe sans qu'un scan ait pu
-- enregistrer le nouvel exemplaire. C'est le cas « un autre personnage a
-- touche a la banque ».
WARBANK_DESYNC = {}
function DesyncWarbankFixture(itemID, extra)
    WARBANK_DESYNC[itemID] = (WARBANK_DESYNC[itemID] or 0) + (extra or 1)
end

C_Bank.FetchPurchasedBankTabIDs = function(bankType)
    if bankType ~= Enum.BankType.Account then
        return {}
    end
    return WARBANK_BAGS
end

-- Le contenu d'un onglet de Warbank n'est lisible que banque ouverte : c'est
-- ce qui rend testable le chemin « banque fermee, instantane seul ».
local previousNumSlots = C_Container.GetContainerNumSlots
C_Container.GetContainerNumSlots = function(bag)
    if WARBANK_CONTENT[bag] then
        return WARBANK_OPEN and 8 or 0
    end
    return previousNumSlots(bag)
end
local previousItemID = C_Container.GetContainerItemID
C_Container.GetContainerItemID = function(bag, slot)
    if WARBANK_CONTENT[bag] then
        if not WARBANK_OPEN then return nil end
        local entry = WarbankEntry(bag, slot)
        return entry and entry.itemID or nil
    end
    return previousItemID(bag, slot)
end
local previousItemLink = C_Container.GetContainerItemLink
C_Container.GetContainerItemLink = function(bag, slot)
    if WARBANK_CONTENT[bag] then
        local entry = WARBANK_OPEN and WarbankEntry(bag, slot) or nil
        if not entry or entry.noLink then return nil end
        return WarbankLink(bag, slot, entry.itemID)
    end
    return previousItemLink(bag, slot)
end
local previousItemInfo = C_Container.GetContainerItemInfo
C_Container.GetContainerItemInfo = function(bag, slot)
    if WARBANK_CONTENT[bag] then
        local entry = WARBANK_OPEN and WarbankEntry(bag, slot) or nil
        if not entry then return nil end
        local info = { itemID = entry.itemID, stackCount = entry.stackCount or 1 }
        if not entry.noLink then
            info.hyperlink = WarbankLink(bag, slot, entry.itemID)
        end
        return info
    end
    return previousItemInfo(bag, slot)
end

-- Rang et statistique d'un exemplaire de Warbank, lus sur son lien unique.
local previousDetailedWithBank = GetDetailedItemLevelInfo
function GetDetailedItemLevelInfo(v)
    for bag, slots in pairs(WARBANK_CONTENT) do
        for slot, entry in pairs(slots) do
            if not entry.noLink and WarbankLink(bag, slot, entry.itemID) == v then
                return entry.itemLevel, false, entry.itemLevel
            end
        end
    end
    return previousDetailedWithBank(v)
end

local previousTooltipWithBank = C_TooltipInfo.GetHyperlink
C_TooltipInfo.GetHyperlink = function(link)
    for bag, slots in pairs(WARBANK_CONTENT) do
        for slot, entry in pairs(slots) do
            if not entry.noLink and WarbankLink(bag, slot, entry.itemID) == link then
                local item = ITEMS[entry.itemID]
                local lines = { { leftText = item and item.name or "?" } }
                if entry.stat then
                    lines[#lines + 1] = { leftText = "+303 " .. entry.stat }
                end
                return { lines = lines }
            end
        end
    end
    return previousTooltipWithBank(link)
end

-- L'oracle de cardinalite du client. Le cinquieme argument inclut la banque de
-- compte, et c'est lui qui permet de repondre banque fermee.
C_Item.GetItemCount = function(itemID, _, _, _, includeAccountBank)
    itemID = tonumber(itemID) or 0
    local total = 0
    for _, slots in pairs(BAG_CONTENT) do
        for _, entry in pairs(slots) do
            if entry.itemID == itemID then
                total = total + (entry.stackCount or 1)
            end
        end
    end
    if includeAccountBank then
        for _, slots in pairs(WARBANK_CONTENT) do
            for _, entry in pairs(slots) do
                if entry.itemID == itemID then
                    total = total + (entry.stackCount or 1)
                end
            end
        end
        total = total + (WARBANK_DESYNC[itemID] or 0)
    end
    return total
end

-- Un outil rare qui vient d'etre achete n'est pas encore lie : c'est
-- exactement l'exemplaire qu'il ne faut pas racheter. L'emplacement porte
-- desormais ses coordonnees, donc la doublure peut repondre par slot.
-- Les appels sont comptes : le tracker ne doit plus consulter cette API du
-- tout. Un compteur non nul signalerait le retour du filtre soulbound, et donc
-- du doublon commande juste apres une livraison.
ISBOUND_CALLS = 0
C_Item.IsBound = function(location)
    ISBOUND_CALLS = ISBOUND_CALLS + 1
    if type(location) == "table" and location.bag and location.slot then
        local entry = BAG_CONTENT[location.bag] and BAG_CONTENT[location.bag][location.slot]
        if entry and entry.unbound then
            return false
        end
    end
    return true
end

-- Depose un outil rare conforme, mais NON LIE, dans les sacs : l'etat d'un
-- achat tout juste livre par le courrier. Son itemID lui est propre, car un
-- lien de sac de cette doublure ne porte que l'itemID : deux exemplaires du
-- meme objet dans deux emplacements y partageraient leur identite.
ITEMS[245779] = { name = "Sin'dorei Alchemist's Spare Rod", quality = 3,
                  equipLoc = "INVTYPE_PROFESSION_TOOL", skillLine = ALCH_SKILL_LINE,
                  stat = "Perception" }
function AddUnboundToolFixture()
    BAG_CONTENT[0][7] = { itemID = 245779, itemLevel = 232, stat = "Perception", unbound = true }
end
