-- Doublure de l'API de widgets WoW pour les tests de YayaCore, hors du jeu.
--
-- Charge par dofile("Tests/ui_stub.lua") depuis addons/YayaCore. Volontairement
-- independant de YayaWeeklyTracker/Tests/wow_env.lua, qui pose des globales du
-- tracker. Les widgets ont un ETAT : SetChecked se relit par GetChecked,
-- SetValue rejoue OnValueChanged comme le client, ClearFocus declenche
-- OnEditFocusLost. C'est ce qui rend testables les boucles de resynchronisation.
--
-- Reglages exposes aux tests :
--   MISSING_TEMPLATES[nom] = true  : CreateFrame leve une erreur pour ce template
--   MENU_API_AVAILABLE = false     : les DropdownButton n'ont pas SetupMenu
--   ALL_FRAMES, REGISTERED_CATEGORIES, OPENED_CATEGORY : traces

MISSING_TEMPLATES = {}
MENU_API_AVAILABLE = true
ALL_FRAMES = {}
REGISTERED_CATEGORIES = {}
OPENED_CATEGORY = nil

local unpack = unpack or table.unpack

-- Champs de widget livres par les templates Blizzard : ils commencent par une
-- majuscule comme les methodes, mais portent un widget. Crees a la demande.
local WIDGET_FIELDS = {
    Text = true, Low = true, High = true, Label = true, Icon = true,
    ScrollBar = true, ScrollChild = true, EditBox = true,
    Left = true, Middle = true, Right = true,
}

-- Methodes de l'API Menu : absentes sauf sur un DropdownButton moderne, pour
-- que le repli UIDropDownMenuTemplate soit reellement exerce.
local NIL_METHODS = { SetupMenu = true, GenerateMenu = true, SetDefaultText = true }

local function Noop() return nil end

local NewWidget

local methods = {}

function methods.GetName(self) return self.__name end
function methods.GetObjectType(self) return self.__kind end
function methods.GetParent(self) return self.__parent end
function methods.Show(self) self.__shown = true end
function methods.Hide(self) self.__shown = false end
function methods.IsShown(self) return self.__shown end
function methods.IsVisible(self) return self.__shown end

function methods.SetPoint(self, ...) self.__points[#self.__points + 1] = { ... } end
function methods.GetNumPoints(self) return #self.__points end
function methods.ClearAllPoints(self) self.__points = {} end
function methods.SetAllPoints(self) end
function methods.SetSize(self, w, h)
    self.__width = tonumber(w) or self.__width
    self.__height = tonumber(h) or self.__height
end
function methods.SetWidth(self, v) self.__width = tonumber(v) or self.__width end
function methods.SetHeight(self, v) self.__height = tonumber(v) or self.__height end
function methods.GetWidth(self) return self.__width end
function methods.GetHeight(self) return self.__height end
function methods.GetStringHeight(self) return 12 end
function methods.GetStringWidth(self) return #tostring(self.__text or "") * 5 end

function methods.SetText(self, text) self.__text = tostring(text == nil and "" or text) end
function methods.GetText(self) return self.__text or "" end
function methods.SetNumber(self, n) self.__text = tostring(n) end
function methods.GetNumber(self) return tonumber(self.__text) or 0 end
function methods.SetFormattedText(self, fmt, ...) self.__text = string.format(fmt, ...) end

function methods.SetChecked(self, v) self.__checked = v and true or false end
function methods.GetChecked(self) return self.__checked == true end

-- Comme le client : SetValue declenche OnValueChanged de facon synchrone.
function methods.SetValue(self, v)
    self.__value = v
    local handler = self.__scripts.OnValueChanged
    if handler then
        handler(self, v)
    end
end
function methods.GetValue(self) return self.__value or 0 end
function methods.SetMinMaxValues(self, lo, hi) self.__min, self.__max = lo, hi end
function methods.GetMinMaxValues(self) return self.__min or 0, self.__max or 0 end
function methods.SetValueStep(self, s) self.__step = s end
function methods.GetValueStep(self) return self.__step end

function methods.SetEnabled(self, v) self.__enabled = v and true or false end
function methods.IsEnabled(self) return self.__enabled ~= false end
function methods.Enable(self) self.__enabled = true end
function methods.Disable(self) self.__enabled = false end
function methods.EnableMouse(self, v) self.__mouse = v and true or false end
function methods.SetAlpha(self, a) self.__alpha = a end
function methods.GetAlpha(self) return self.__alpha or 1 end

function methods.SetScript(self, event, handler) self.__scripts[event] = handler end
function methods.GetScript(self, event) return self.__scripts[event] end
function methods.HookScript(self, event, handler) self.__scripts[event] = handler end

function methods.SetScrollChild(self, child) self.__scrollChild = child end
function methods.GetScrollChild(self) return self.__scrollChild end
function methods.SetVerticalScroll(self, v) self.__scroll = v end
function methods.GetVerticalScroll(self) return self.__scroll or 0 end

-- Comme le client : perdre le focus declenche OnEditFocusLost.
function methods.ClearFocus(self)
    self.__focused = false
    local handler = self.__scripts.OnEditFocusLost
    if handler then
        handler(self)
    end
end
function methods.SetFocus(self) self.__focused = true end
function methods.HasFocus(self) return self.__focused == true end

function methods.GetFontString(self)
    if not rawget(self, "__fontString") then
        self.__fontString = NewWidget(nil, "FontString", self)
    end
    return self.__fontString
end
function methods.CreateFontString(self, name, _, template)
    local fs = NewWidget(name, "FontString", self)
    fs.__template = template
    return fs
end
function methods.CreateTexture(self, name) return NewWidget(name, "Texture", self) end
function methods.GetChildren(self) return unpack(self.__children) end

function methods.SetTextColor(self, ...) self.__color = { ... } end
function methods.SetColorTexture(self, ...) self.__color = { ... } end
function methods.SetTexture(self, path) self.__texture = path end
function methods.SetFontObject(self, font) self.__font = font end
function methods.SetWordWrap(self, v) self.__wrap = v end
function methods.SetMaxLines(self, v) self.__maxLines = v end
function methods.SetJustifyH(self, v) self.__justify = v end
function methods.SetNumeric(self, v) self.__numeric = v end
function methods.SetAutoFocus(self, v) self.__autoFocus = v end
function methods.SetMaxLetters(self, v) self.__maxLetters = v end

local function Index(widget, key)
    local method = methods[key]
    if method then
        return method
    end
    -- Seules les methodes (majuscule initiale) sont simulees : un champ pose
    -- par l'addon (label, editBox, rows) doit rester nil tant qu'il n'est pas
    -- ecrit, sinon le stub fabrique de fausses erreurs.
    if type(key) ~= "string" or not key:match("^%u") then
        return nil
    end
    if NIL_METHODS[key] then
        return nil
    end
    if WIDGET_FIELDS[key] then
        local child = NewWidget(nil, "Frame", widget)
        rawset(widget, key, child)
        return child
    end
    return Noop
end

NewWidget = function(name, kind, parent)
    local widget = {
        __name = name,
        __kind = kind or "Frame",
        __parent = parent,
        __shown = true,
        __scripts = {},
        __points = {},
        __children = {},
        __width = 100,
        __height = 20,
    }
    setmetatable(widget, { __index = Index })
    if parent and rawget(parent, "__children") then
        parent.__children[#parent.__children + 1] = widget
    end
    if name then
        _G[name] = widget
    end
    return widget
end

-- Racine de menu de l'API Menu : capture les radios dans root.entries.
local function NewMenuRoot()
    local root = { entries = {} }
    local function Add(kind, label, isSelected, onSelect)
        local entry = {
            kind = kind,
            label = label,
            isSelected = isSelected,
            onSelect = onSelect,
            SetTooltip = function(self, fn) self.tooltip = fn end,
        }
        root.entries[#root.entries + 1] = entry
        return entry
    end
    function root.CreateRadio(_, label, isSelected, onSelect) return Add("radio", label, isSelected, onSelect) end
    function root.CreateCheckbox(_, label, isSelected, onSelect) return Add("checkbox", label, isSelected, onSelect) end
    function root.CreateButton(_, label, onSelect) return Add("button", label, nil, onSelect) end
    function root.CreateTitle(_, label) return Add("title", label) end
    return root
end

function CreateFrame(kind, name, parent, template)
    if template and MISSING_TEMPLATES[template] then
        error("template inconnu : " .. tostring(template))
    end
    local frame = NewWidget(name, kind, parent)
    frame.__template = template
    if template == "WowStyle1DropdownTemplate" and MENU_API_AVAILABLE then
        function frame.SetupMenu(self, generator)
            self.__generator = generator
            self:GenerateMenu()
        end
        function frame.GenerateMenu(self)
            local root = NewMenuRoot()
            self.__root = root
            self.__generated = (self.__generated or 0) + 1
            if self.__generator then
                self.__generator(self, root)
            end
            return root
        end
        function frame.SetDefaultText(self, text) self.__defaultText = text end
    end
    ALL_FRAMES[#ALL_FRAMES + 1] = frame
    return frame
end

-- API Settings de Blizzard : categories enregistrees et ouverture tracee.
Settings = {
    RegisterCanvasLayoutCategory = function(panel, name)
        local category = { panel = panel, name = name, GetID = function() return 42 end }
        REGISTERED_CATEGORIES[#REGISTERED_CATEGORIES + 1] = category
        return category
    end,
    RegisterAddOnCategory = function(category) category.added = true end,
    OpenToCategory = function(id) OPENED_CATEGORY = id end,
}

-- Ancien systeme de menus deroulants, pour le repli.
UIDROPDOWN_CALLS = {}
function UIDropDownMenu_Initialize(frame, initializer)
    frame.__initializer = initializer
    UIDROPDOWN_CALLS[#UIDROPDOWN_CALLS + 1] = "Initialize"
end
function UIDropDownMenu_SetWidth(frame, width) frame.__menuWidth = width end
function UIDropDownMenu_SetText(frame, text) frame.__menuText = text end
function UIDropDownMenu_CreateInfo() return {} end
function UIDropDownMenu_AddButton(info, level)
    UIDROPDOWN_ADDED = UIDROPDOWN_ADDED or {}
    UIDROPDOWN_ADDED[#UIDROPDOWN_ADDED + 1] = info
end
function UIDropDownMenu_EnableDropDown(frame) frame.__enabled = true end
function UIDropDownMenu_DisableDropDown(frame) frame.__enabled = false end
function CloseDropDownMenus() end

GameTooltip = NewWidget("GameTooltip", "GameTooltip")
function GameTooltip.SetOwner(self, owner) self.__owner = owner end
function GameTooltip.IsOwned(self, owner) return self.__owner == owner end
function GameTooltip.ClearLines(self) self.__lines = {} end
function GameTooltip.AddLine(self, text) self.__lines = self.__lines or {}; self.__lines[#self.__lines + 1] = text end
function GameTooltip.SetHyperlink(self, link) self.__link = link end

function strtrim(text) return (tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", "")) end
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
function CopyTable(t)
    local copy = {}
    for k, v in pairs(t) do
        copy[k] = type(v) == "table" and CopyTable(v) or v
    end
    return copy
end
function tostringall(...)
    local out = {}
    for i = 1, select("#", ...) do out[i] = tostring((select(i, ...))) end
    return unpack(out)
end

-- Liste les frames creees avec un template donne, dans l'ordre de creation.
function FindFrameByTemplate(template)
    local found = {}
    for _, frame in ipairs(ALL_FRAMES) do
        if frame.__template == template then
            found[#found + 1] = frame
        end
    end
    return found
end
