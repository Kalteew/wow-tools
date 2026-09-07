-- Stub WoW minimal : de quoi charger un addon Yaya hors du jeu et appeler
-- quelques fonctions, pour attraper les erreurs runtime que luac ne voit pas.

local unpack = unpack or table.unpack

local frameRegistry = {}

WIDGET_FIELD_NAMES = {
    Text = true, Label = true, Icon = true, Name = true, Count = true,
    Border = true, Background = true, Highlight = true, Left = true,
    Right = true, Middle = true, NormalTexture = true, ScrollBar = true,
    ScrollChild = true, EditBox = true, Title = true, TitleText = true,
    CloseButton = true, Bg = true, Center = true, Overlay = true,
}

local function NewWidget(name, kind)
    local widget = {
        __name = name,
        __kind = kind or "Frame",
        __shown = false,
        __scripts = {},
        __attributes = {},
        __events = {},
        __points = {},
        __width = 100,
        __height = 20,
    }

    local methods = {}

    function methods.GetName(self) return self.__name end
    function methods.GetObjectType(self) return self.__kind end
    function methods.Show(self) self.__shown = true end
    function methods.Hide(self) self.__shown = false end
    function methods.IsShown(self) return self.__shown end
    function methods.IsVisible(self) return self.__shown end
    function methods.GetWidth(self) return self.__width end
    function methods.GetHeight(self) return self.__height end
    function methods.SetWidth(self, v) self.__width = tonumber(v) or self.__width end
    function methods.SetHeight(self, v) self.__height = tonumber(v) or self.__height end
    function methods.SetSize(self, w, h)
        self.__width = tonumber(w) or self.__width
        self.__height = tonumber(h) or self.__height
    end
    function methods.GetSize(self) return self.__width, self.__height end
    function methods.SetScript(self, event, handler) self.__scripts[event] = handler end
    function methods.GetScript(self, event) return self.__scripts[event] end
    function methods.HookScript(self, event, handler) self.__scripts[event] = handler end
    function methods.RegisterEvent(self, event) self.__events[event] = true end
    function methods.UnregisterEvent(self, event) self.__events[event] = nil end
    function methods.IsEventRegistered(self, event) return self.__events[event] == true end
    function methods.SetAttribute(self, key, value) self.__attributes[key] = value end
    function methods.GetAttribute(self, key) return self.__attributes[key] end
    function methods.SetPoint(self, ...) self.__points[#self.__points + 1] = { ... } end
    function methods.GetPoint(self) return "BOTTOMLEFT", nil, "BOTTOMLEFT", 0, 0 end
    function methods.GetNumPoints(self) return #self.__points end
    function methods.ClearAllPoints(self) self.__points = {} end
    function methods.GetLeft(self) return 0 end
    function methods.GetRight(self) return self.__width end
    function methods.GetTop(self) return self.__height end
    function methods.GetBottom(self) return 0 end
    function methods.GetCenter(self) return 100, 100 end
    function methods.GetEffectiveScale(self) return 1 end
    function methods.GetScale(self) return 1 end
    function methods.GetStringWidth(self) return 50 end
    function methods.GetText(self) return self.__text end
    function methods.SetText(self, text) self.__text = text end
    function methods.SetFormattedText(self, fmt, ...) self.__text = string.format(fmt, ...) end
    function methods.IsEnabled(self) return true end
    function methods.NumLines(self) return 0 end
    function methods.GetFont(self) return "Fonts\\FRIZQT__.TTF", 12, "" end
    function methods.CreateFontString(self, name, layer, template)
        return NewWidget(name or ((self.__name or "Anon") .. "FS"), "FontString")
    end
    function methods.CreateTexture(self, name)
        return NewWidget(name or ((self.__name or "Anon") .. "Tex"), "Texture")
    end
    function methods.CreateLine(self, name)
        return NewWidget(name or ((self.__name or "Anon") .. "Line"), "Line")
    end
    function methods.GetParent(self) return self.__parent end
    function methods.GetChildren(self) return end
    function methods.GetRegions(self) return end

    setmetatable(widget, {
        __index = function(t, key)
            local method = methods[key]
            if method then
                return method
            end
            -- Seules les METHODES sont simulees. Les methodes de widget WoW
            -- commencent par une majuscule ; un champ de donnees pose par
            -- l'addon (label, bg, lines) doit rester nil, sinon le stub
            -- fabrique de fausses erreurs "index a function value".
            if type(key) ~= "string" or not key:match("^%u") then
                return nil
            end
            -- Champs de widget des templates Blizzard : ils commencent par une
            -- majuscule comme les methodes, mais portent un widget, pas une
            -- fonction. Les rendre comme widgets evite de fausses erreurs.
            if WIDGET_FIELD_NAMES[key] then
                local child = NewWidget(nil, "Frame")
                t[key] = child
                return child
            end
            local fallback = function() return nil end
            t[key] = fallback
            return fallback
        end,
    })

    if name then
        frameRegistry[name] = widget
        _G[name] = widget
    end
    return widget
end

ALL_FRAMES = {}
function CreateFrame(kind, name, parent, template)
    local frame = NewWidget(name, kind)
    frame.__parent = parent
    frame.__template = template
    ALL_FRAMES[#ALL_FRAMES + 1] = frame
    return frame
end

-- Rejoue un evenement sur toutes les frames qui l'ont enregistre.
function FireEvent(event, ...)
    for _, frame in ipairs(ALL_FRAMES) do
        local handler = frame.__scripts and frame.__scripts["OnEvent"]
        if handler and frame.__events and frame.__events[event] then
            local ok, err = pcall(handler, frame, event, ...)
            if not ok then
                UNCAUGHT = UNCAUGHT or {}
                UNCAUGHT[#UNCAUGHT + 1] = event .. " :: " .. tostring(err)
            end
        end
    end
end

-- Vide la file des timers differes, plusieurs fois car un timer peut en poser.
function RunTimers(rounds)
    for _ = 1, rounds or 5 do
        local pending = PENDING_TIMERS or {}
        PENDING_TIMERS = {}
        for _, callback in ipairs(pending) do
            local ok, err = pcall(callback)
            if not ok then
                UNCAUGHT = UNCAUGHT or {}
                UNCAUGHT[#UNCAUGHT + 1] = "timer :: " .. tostring(err)
            end
        end
    end
end

UIParent = NewWidget("UIParent", "Frame")
WorldFrame = NewWidget("WorldFrame", "Frame")
GameTooltip = NewWidget("GameTooltip", "GameTooltip")
DEFAULT_CHAT_FRAME = NewWidget("DEFAULT_CHAT_FRAME", "Frame")
function DEFAULT_CHAT_FRAME.AddMessage(_, message)
    CHAT_MESSAGES = CHAT_MESSAGES or {}
    CHAT_MESSAGES[#CHAT_MESSAGES + 1] = tostring(message)
end
function GameTooltip_Hide() end

-- ------------------------------------------------------------------ globales
NUM_BAG_SLOTS = 4
NUM_TOTAL_EQUIPPED_BAG_SLOTS = 5
INVSLOT_BACK = 15
SLASH_YWT1 = nil
ITEM_SPELL_KNOWN = "Already known"

function GetTime() return 1000.0 end
function GetLocale() return "frFR" end
function UnitName() return "Tester" end
function UnitLevel() return 90 end
function UnitClass() return "Mage", "MAGE", 8 end
function GetRealmName() return "Realm" end
function InCombatLockdown() return false end
function IsInInstance() return false, "none" end
function GetAverageItemLevel() return 250, 250 end
function GetMoney() return 0 end
function GetProfessions() return 1, 2 end
function GetProfessionInfo(index)
    if index == 1 then
        return "Alchemy", nil, 100, 100, nil, nil, 171
    end
    return "Inscription", nil, 100, 100, nil, nil, 773
end
function GetInventoryItemLink() return nil end
function GetInventoryItemID() return nil end
function GetItemInfo() return nil end
function GetItemInfoInstant() return nil end
function GetDetailedItemLevelInfo() return nil end
function GetContainerNumSlots() return 0 end
function IsQuestFlaggedCompleted() return false end
function GetQuestLogIndexByID() return nil end
function UnitAffectingCombat() return false end
function RegisterStateDriver() end
function UnregisterStateDriver() end
function hooksecurefunc() end
function strsplit(sep, str)
    local out = {}
    for part in tostring(str):gmatch("([^" .. sep .. "]*)") do
        out[#out + 1] = part
    end
    return unpack(out)
end
function strtrim(s) return (tostring(s):gsub("^%s+", ""):gsub("%s+$", "")) end
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
function tContains(t, value)
    for _, v in ipairs(t or {}) do
        if v == value then return true end
    end
    return false
end
function SlashCmdList() end
SlashCmdList = {}

C_Timer = {
    After = function(_, callback)
        PENDING_TIMERS = PENDING_TIMERS or {}
        PENDING_TIMERS[#PENDING_TIMERS + 1] = callback
    end,
    NewTicker = function() return { Cancel = function() end } end,
}

C_Container = {
    GetContainerNumSlots = function() return 0 end,
    GetContainerItemInfo = function() return nil end,
    GetContainerItemID = function() return nil end,
    GetContainerItemLink = function() return nil end,
    UseContainerItem = function() end,
    PickupContainerItem = function() end,
}

C_Item = {
    GetItemInfoInstant = function() return nil end,
    GetItemQualityByID = function() return nil end,
    GetItemCount = function() return 0 end,
    RequestLoadItemDataByID = function() end,
    IsBound = function() return false end,
    IsEquippableItem = function() return false end,
    GetItemNameByID = function() return nil end,
    GetCurrentItemLevel = function() return nil end,
    GetItemSpell = function() return nil end,
    DoesItemExistByID = function() return true end,
}

C_TradeSkillUI = {
    GetProfessionSlots = function() return {} end,
    GetProfessionInfoBySkillLineID = function() return nil end,
    GetSkillLineForGear = function() return nil end,
    GetProfessionSkillLineID = function() return nil end,
    GetChildProfessionInfos = function() return {} end,
    GetBaseProfessionInfo = function() return nil end,
    IsRecipeProfessionLearned = function() return false end,
    GetRecipeInfo = function() return nil end,
}

C_TooltipInfo = {
    GetHyperlink = function() return nil end,
    GetItemByID = function() return nil end,
    GetInventoryItem = function() return nil end,
    GetBagItem = function() return nil end,
}

C_QuestLog = {
    IsQuestFlaggedCompleted = function() return false end,
    GetLogIndexForQuestID = function() return nil end,
    IsOnQuest = function() return false end,
    GetInfo = function() return nil end,
    GetNumQuestLogEntries = function() return 0 end,
    GetQuestObjectives = function() return {} end,
    GetTitleForQuestID = function() return nil end,
}

C_CurrencyInfo = {
    GetCurrencyInfo = function() return nil end,
}

C_Spell = { GetSpellInfo = function() return nil end }
C_MountJournal = {}
C_Map = { GetBestMapForUnit = function() return nil end }
C_AddOns = {
    IsAddOnLoaded = function() return false end,
    GetAddOnMetadata = function() return nil end,
}
C_EquipmentSet = {}
C_Bank = {}
C_PlayerInteractionManager = {}
C_DateAndTime = { GetCurrentCalendarTime = function() return { hour = 12, minute = 0 } end }

Enum = {
    TooltipDataLineType = { None = 0, UnitName = 1 },
    TooltipDataUsageRequirementType = { NotAlreadyKnown = 1 },
    CraftingReagentType = { Basic = 1, Finishing = 2, Modifying = 3 },
    PlayerInteractionType = { AccountBanker = 1, MerchantFrame = 2 },
    BagIndex = { Bank = -1, Bankbag = 6, AccountBankTab = 13, Reagentbank = -3 },
    ItemQuality = { Poor = 0, Common = 1, Uncommon = 2, Rare = 3, Epic = 4 },
}

Settings = {
    RegisterAddOnCategory = function() end,
    RegisterCanvasLayoutCategory = function() return { ID = 1 } end,
    RegisterVerticalLayoutCategory = function() return { ID = 1 } end,
    CreateCheckbox = function() end,
    CreateControlTextContainer = function()
        return { Add = function() end, GetData = function() return {} end }
    end,
    RegisterProxySetting = function()
        return { SetValueChangedCallback = function() end }
    end,
    Default = {}, VarType = { Boolean = "boolean", Number = "number" },
}
SettingsPanel = NewWidget("SettingsPanel", "Frame")

ItemLocation = {
    CreateFromBagAndSlot = function() return {} end,
    CreateFromEquipmentSlot = function() return {} end,
}

BackdropTemplateMixin = {}
CopyTable = function(t)
    local out = {}
    for k, v in pairs(t or {}) do out[k] = v end
    return out
end

STUB_READY = true
