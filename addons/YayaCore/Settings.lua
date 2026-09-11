-- YayaCore.Settings : constructeur de panneaux d'options partage par la suite.
--
-- Chaque addon reecrivait son panneau Blizzard a la main : une ScrollFrame, une
-- pile de cases a cocher, un OnShow qui relit la base. Les seuils restaient
-- codes en dur faute de slider, de saisie numerique ou de liste deroulante.
--
-- Ce module prend une liste de descripteurs -- des tables de donnees, sans
-- logique -- et rend un panneau a categories : un rail de boutons a gauche, une
-- page scrollable par categorie a droite, des widgets relies a la base par
-- get/set, et une resynchronisation a chaque ouverture.
--
-- ACCES SANS LOCAL. Comme YayaCore.UI : YayaWeeklyTracker.lua et YayaQueue.lua
-- sont au bord des 200 locals de chunk. Les consommateurs posent leurs
-- descripteurs sur une table deja globale ou les construisent dans la fonction
-- qui appelle BuildPanel -- une closure ecrite au niveau chunk ne voit pas les
-- locals declares plus bas.
--
-- Dans ce fichier la table locale s'appelle YSettings : `Settings` designe
-- l'API Blizzard, atteinte par _G.Settings pour eviter toute collision.

local YayaCore = _G.YayaCore
if type(YayaCore) ~= "table" or type(YayaCore.UI) ~= "table" then
    return
end

local UI = YayaCore.UI

local YSettings = {
    version = 1,
}
YayaCore.Settings = YSettings

-- Gouttiere des pages et du panneau : la meme que l'ancien panneau de
-- YayaWeeklyTracker, pour que la migration ne bouge pas le contenu.
local PAD = UI.PAD.xl

-- Largeur presumee d'un texte libre avant que la page ne soit mesuree : les
-- pages ne connaissent leur largeur qu'au premier OnSizeChanged, apres la
-- construction. Sous-estimer la largeur surestime la hauteur, ce qui coute
-- quelques pixels ; l'inverse ferait chevaucher le texte et le widget suivant.
local TEXT_ASSUMED_WIDTH = 360
local TEXT_MAX_LINES = 8

-- Libelle de repli d'une entree sans categorie ni predecesseur.
local DEFAULT_CATEGORY = "General"

-- Largeur du libelle d'une ligne d'orderlist.
local ORDERLIST_LABEL_W = 200

-- ---------------------------------------------------------------------------
-- Outils
-- ---------------------------------------------------------------------------

local function DeepCopy(value)
    if type(value) ~= "table" then
        return value
    end
    local copy = {}
    for key, item in pairs(value) do
        copy[key] = DeepCopy(item)
    end
    return copy
end

local function ReportError(context, err)
    local message = "YayaCore.Settings : " .. tostring(context) .. " -> " .. tostring(err)
    if type(geterrorhandler) == "function" then
        local handler = geterrorhandler()
        if type(handler) == "function" then
            handler(message)
            return
        end
    end
    print(message)
end

local function TooltipOf(desc)
    if desc.tooltip == nil then
        return nil
    end
    if type(desc.tooltip) == "table" then
        return desc.tooltip
    end
    return { title = desc.label or desc.key, body = tostring(desc.tooltip) }
end

--- Remplit les valeurs absentes d'une base avec des defauts.
--
-- Seules les cles a nil sont ecrites : false est une valeur choisie, pas une
-- absence. Les tables sont copiees en profondeur pour qu'une mutation de la
-- base ne remonte jamais dans la table de defauts partagee.
--
-- keys : optionnel, tableau de chaines ou de descripteurs (on lit .key) pour ne
--        remplir qu'un sous-ensemble.
function YSettings.ApplyDefaults(db, defaults, keys)
    if type(db) ~= "table" then
        db = {}
    end
    if type(defaults) ~= "table" then
        return db
    end
    if type(keys) == "table" then
        for _, entry in ipairs(keys) do
            local key = type(entry) == "table" and entry.key or entry
            if key ~= nil and db[key] == nil and defaults[key] ~= nil then
                db[key] = DeepCopy(defaults[key])
            end
        end
        return db
    end
    for key, value in pairs(defaults) do
        if db[key] == nil then
            db[key] = DeepCopy(value)
        end
    end
    return db
end

--- Complete un descripteur : type, categorie, get et set par defaut.
--
-- type absent + key presente => "checkbox" ; type absent sans key => nil (entree
-- ignoree). category absente => previousCategory, sinon "General".
--
-- Lecture par defaut d'une checkbox : `db[key] ~= false` si default == true
-- (une cle jamais ecrite vaut coche), `db[key] == true` sinon (une cle jamais
-- ecrite vaut decochee). Les autres types lisent db[key] tel quel.
function YSettings.NormalizeOption(desc, previousCategory)
    if type(desc) ~= "table" then
        return nil
    end
    if desc.type == nil then
        if desc.key == nil then
            return nil
        end
        desc.type = "checkbox"
    end
    if desc.category == nil then
        desc.category = previousCategory or DEFAULT_CATEGORY
    end

    local key = desc.key
    if key ~= nil then
        if type(desc.get) ~= "function" then
            if desc.type == "checkbox" then
                if desc.default == true then
                    desc.get = function(db) return db[key] ~= false end
                else
                    desc.get = function(db) return db[key] == true end
                end
            else
                desc.get = function(db) return db[key] end
            end
        end
        if type(desc.set) ~= "function" then
            desc.set = function(db, value) db[key] = value end
        end
    end
    return desc
end

-- ---------------------------------------------------------------------------
-- Builders : un par type de descripteur
--
-- Signature : BUILDERS[type](page, stack, desc, ctx). Chaque builder cree son
-- widget via UI.*, l'empile, puis l'enregistre par ctx.Register(desc, widget,
-- push) ou push(db) pousse la valeur de la base dans le widget. Un widget nil
-- (template absent) fait sortir sans rien enregistrer.
-- ---------------------------------------------------------------------------

local BUILDERS = {}

local function CurrentOrDefault(desc, db)
    local value = desc.get(db)
    if value == nil then
        value = desc.default
    end
    return value
end

BUILDERS.section = function(page, stack, desc)
    local title = page:CreateFontString(nil, "ARTWORK", UI.FONT.header)
    title:SetText(desc.label or "")
    title:SetTextColor(UI.Unpack(UI.COLOR.category))
    UI.BoundLabel(title, "LEFT")
    stack.Add(title, stack.count > 0 and UI.PAD.lg or 0,
        { height = UI.SIZE.rowHCompact, stretch = false })

    local divider = UI.CreateDivider(page)
    if divider then
        divider:SetPoint("LEFT", title, "RIGHT", UI.PAD.md, 0)
        divider:SetPoint("RIGHT", page, "RIGHT", -PAD, 0)
    end
end

BUILDERS.text = function(page, stack, desc)
    local text = tostring(desc.label or desc.text or "")
    local body = page:CreateFontString(nil, "ARTWORK", UI.FONT.body)
    body:SetTextColor(UI.Unpack(UI.COLOR.textMuted))
    if type(body.SetWordWrap) == "function" then
        body:SetWordWrap(true)
    end
    if type(body.SetJustifyH) == "function" then
        body:SetJustifyH("LEFT")
    end
    local lines = math.max(1, math.ceil(UI.MeasureWidth(text, UI.FONT.body) / TEXT_ASSUMED_WIDTH))
    local height = UI.FitLabel(body, text, lines, TEXT_MAX_LINES)
    stack.Add(body, UI.PAD.sm, { height = height })
end

BUILDERS.checkbox = function(page, stack, desc, ctx)
    local widget = UI.CreateCheckbox(page, desc.label or tostring(desc.key), {
        tooltip = TooltipOf(desc),
        onClick = function(checked)
            if ctx.refreshing then
                return
            end
            ctx.Commit(desc, checked and true or false)
        end,
    })
    if not widget then
        return
    end
    stack.Add(widget, UI.PAD.sm, { height = UI.SIZE.headerH, stretch = false })
    ctx.Register(desc, widget, function(db)
        widget:SetChecked(desc.get(db) and true or false)
    end)
end

BUILDERS.radio = function(page, stack, desc, ctx)
    local choices = type(desc.choices) == "table" and desc.choices or {}
    local group = CreateFrame("Frame", nil, page)
    group.buttons = {}

    local groupStack = UI.StackLayout(group, {})
    if desc.label then
        local title = group:CreateFontString(nil, "ARTWORK", UI.FONT.body)
        title:SetText(desc.label)
        UI.BoundLabel(title, "LEFT")
        group.label = title
        groupStack.Add(title, 0, { height = UI.SIZE.rowHCompact, stretch = false })
    end

    for _, choice in ipairs(choices) do
        local value = choice.value
        local tooltip = choice.tooltip and { title = choice.label, body = choice.tooltip } or nil
        local button = UI.CreateCheckbox(group, tostring(choice.label or value), {
            radio = true,
            tooltip = tooltip,
            onClick = function()
                if ctx.refreshing then
                    return
                end
                ctx.Commit(desc, value)
            end,
        })
        if button then
            button.value = value
            groupStack.Add(button, UI.PAD.xs, { height = UI.SIZE.headerH, stretch = false })
            group.buttons[#group.buttons + 1] = button
        end
    end
    if #group.buttons == 0 then
        group:Hide()
        return
    end

    local height = groupStack.Finish(0)
    group:SetHeight(height)

    --- Active ou desactive chaque bouton ; l'alpha est porte par le groupe.
    function group.SetEnabled(first, second)
        local enabled = (first == group) and (second and true or false) or (first and true or false)
        for _, button in ipairs(group.buttons) do
            if enabled then
                button:Enable()
            else
                button:Disable()
            end
        end
        group:SetAlpha(enabled and 1 or 0.45)
    end

    stack.Add(group, UI.PAD.sm, { height = height })
    ctx.Register(desc, group, function(db)
        local current = CurrentOrDefault(desc, db)
        for _, button in ipairs(group.buttons) do
            button:SetChecked(button.value == current)
        end
    end)
end

BUILDERS.slider = function(page, stack, desc, ctx)
    local format = desc.format
    if format == nil and desc.suffix then
        local pattern = "%." .. (#(tostring(desc.step or 1):match("%.(%d+)$") or "")) .. "f"
        local suffix = tostring(desc.suffix)
        local glue = suffix:sub(1, 1) == "%" and "" or " "
        format = function(value)
            return string.format(pattern, value) .. glue .. suffix
        end
    end

    -- Le libelle du slider vit au-dessus de la barre et les bornes en dessous :
    -- la ligne reserve la place des trois par UI.SIZE.sliderRowH.
    local row = CreateFrame("Frame", nil, page)
    row:SetHeight(UI.SIZE.sliderRowH)

    local db = ctx.ResolveDB(desc)
    local widget = UI.CreateSlider(row, desc.label or tostring(desc.key), {
        min = desc.min,
        max = desc.max,
        step = desc.step,
        width = desc.width,
        format = format,
        value = CurrentOrDefault(desc, db),
        tooltip = TooltipOf(desc),
        onChange = function(value)
            if ctx.refreshing then
                return
            end
            ctx.Commit(desc, value)
        end,
    })
    if not widget then
        row:Hide()
        return
    end
    widget:SetPoint("TOPLEFT", row, "TOPLEFT", UI.PAD.sm, -(UI.SIZE.rowHCompact))

    stack.Add(row, UI.PAD.lg, { height = UI.SIZE.sliderRowH })
    ctx.Register(desc, widget, function(current)
        widget.SetValueSilently(CurrentOrDefault(desc, current))
    end)
end

BUILDERS.number = function(page, stack, desc, ctx)
    local db = ctx.ResolveDB(desc)
    local widget = UI.CreateNumberInput(page, desc.label or tostring(desc.key), {
        min = desc.min,
        max = desc.max,
        decimals = desc.decimals,
        suffix = desc.suffix,
        width = desc.width,
        labelWidth = desc.labelWidth,
        value = CurrentOrDefault(desc, db),
        tooltip = TooltipOf(desc),
        onCommit = function(value)
            if ctx.refreshing then
                return
            end
            ctx.Commit(desc, value)
        end,
    })
    if not widget then
        return
    end
    stack.Add(widget, UI.PAD.sm, { height = UI.SIZE.headerH })
    ctx.Register(desc, widget, function(current)
        widget.SetValueSilently(CurrentOrDefault(desc, current))
    end)
end

BUILDERS.dropdown = function(page, stack, desc, ctx)
    local widget = UI.CreateDropdown(page, desc.label or tostring(desc.key), {
        choices = desc.choices,
        width = desc.width,
        labelWidth = desc.labelWidth,
        tooltip = TooltipOf(desc),
        get = function()
            return CurrentOrDefault(desc, ctx.ResolveDB(desc))
        end,
        onSelect = function(value)
            if ctx.refreshing then
                return
            end
            ctx.Commit(desc, value)
        end,
    })
    if not widget then
        return
    end
    stack.Add(widget, UI.PAD.sm, { height = widget:GetHeight() })
    ctx.Register(desc, widget, function()
        widget.Refresh()
    end)
end

BUILDERS.button = function(page, stack, desc, ctx)
    local widget = UI.CreateButton(page, desc.label or tostring(desc.key or ""), {
        width = desc.width or 160,
        tooltip = TooltipOf(desc),
    })
    if not widget then
        return
    end
    widget:SetScript("OnClick", function(self)
        if ctx.refreshing then
            return
        end
        if type(desc.onClick) == "function" then
            desc.onClick(desc, self)
        end
    end)
    stack.Add(widget, UI.PAD.sm, { height = UI.ACTION.height, stretch = false })
    ctx.Register(desc, widget, nil)
end

-- Liste ordonnee : une ligne par element, avec sa case de visibilite quand
-- hiddenKey est fourni et ses fleches de deplacement. La valeur stockee est la
-- liste des ids ; a la lecture elle est normalisee -- ordre stocke filtre aux
-- ids connus, puis ids manquants en queue dans l'ordre de desc.items -- pour
-- qu'un element ajoute par une version ulterieure apparaisse sans migration.
--
-- La hauteur du groupe est fixee au nombre d'elements connus a la construction.
BUILDERS.orderlist = function(page, stack, desc, ctx)
    local rowH = UI.SIZE.headerH
    local rowGap = UI.PAD.xs
    local labelW = desc.labelWidth or ORDERLIST_LABEL_W

    local function Items()
        local items = desc.items
        if type(items) == "function" then
            items = items()
        end
        return type(items) == "table" and items or {}
    end

    local function Normalize(db)
        local items = Items()
        local known, labels = {}, {}
        for _, item in ipairs(items) do
            if item.id ~= nil then
                known[item.id] = true
                labels[item.id] = item.label
            end
        end
        local order, seen = {}, {}
        local stored = desc.get(db)
        if type(stored) == "table" then
            for _, id in ipairs(stored) do
                if known[id] and not seen[id] then
                    order[#order + 1] = id
                    seen[id] = true
                end
            end
        end
        for _, item in ipairs(items) do
            if item.id ~= nil and not seen[item.id] then
                order[#order + 1] = item.id
                seen[item.id] = true
            end
        end
        return order, labels
    end

    local group = CreateFrame("Frame", nil, page)
    group.rows = {}
    group.Normalize = Normalize

    local function Move(index, delta)
        local db = ctx.ResolveDB(desc)
        local order = Normalize(db)
        local target = index + delta
        if order[index] == nil or order[target] == nil then
            return
        end
        order[index], order[target] = order[target], order[index]
        ctx.Commit(desc, order)
    end

    local function SetHidden(id, hidden)
        local db = ctx.ResolveDB(desc)
        db[desc.hiddenKey] = db[desc.hiddenKey] or {}
        db[desc.hiddenKey][id] = hidden and true or nil
        ctx.Commit(desc, (Normalize(db)))
    end

    local function EnsureRow(index)
        local row = group.rows[index]
        if row then
            return row
        end
        row = CreateFrame("Frame", nil, group)
        row:SetHeight(rowH)
        row:SetPoint("TOPLEFT", group, "TOPLEFT", 0, -((index - 1) * (rowH + rowGap)))
        row:SetPoint("TOPRIGHT", group, "TOPRIGHT", 0, -((index - 1) * (rowH + rowGap)))

        local anchor
        if desc.hiddenKey then
            row.check = UI.CreateCheckbox(row, "", {
                labelWidth = labelW,
                onClick = function(checked)
                    if ctx.refreshing or row.id == nil then
                        return
                    end
                    SetHidden(row.id, not checked)
                end,
            })
            if row.check then
                row.check:SetPoint("LEFT", row, "LEFT", 0, 0)
                row.label = row.check.label
                anchor = row.check.label or row.check
            end
        end
        if not row.label then
            row.label = row:CreateFontString(nil, "OVERLAY", UI.FONT.body)
            row.label:SetPoint("LEFT", row, "LEFT", UI.PAD.sm, 0)
            row.label:SetWidth(labelW)
            UI.BoundLabel(row.label, "LEFT")
            anchor = row.label
        end

        row.up = UI.CreateButton(row, "^", { small = true, width = 22 })
        row.down = UI.CreateButton(row, "v", { small = true, width = 22 })
        if row.up then
            row.up:SetPoint("LEFT", anchor, "RIGHT", UI.PAD.md, 0)
            row.up:SetScript("OnClick", function()
                if ctx.refreshing or not row.index then
                    return
                end
                Move(row.index, -1)
            end)
        end
        if row.down then
            row.down:SetPoint("LEFT", row.up or anchor, "RIGHT", UI.PAD.xs, 0)
            row.down:SetScript("OnClick", function()
                if ctx.refreshing or not row.index then
                    return
                end
                Move(row.index, 1)
            end)
        end

        group.rows[index] = row
        return row
    end

    local function Render(db)
        local order, labels = Normalize(db)
        local hidden = desc.hiddenKey and db[desc.hiddenKey] or nil
        for index, id in ipairs(order) do
            local row = EnsureRow(index)
            row.index = index
            row.id = id
            if row.label then
                row.label:SetText(tostring(labels[id] or id))
            end
            if row.check then
                row.check:SetChecked(not (type(hidden) == "table" and hidden[id]))
            end
            if row.up then
                UI.SetWidgetEnabled(row.up, index > 1)
            end
            if row.down then
                UI.SetWidgetEnabled(row.down, index < #order)
            end
            row:Show()
        end
        for index = #order + 1, #group.rows do
            group.rows[index].index = nil
            group.rows[index].id = nil
            group.rows[index]:Hide()
        end
    end

    --- Active ou desactive chaque ligne ; l'alpha est porte par le groupe.
    function group.SetEnabled(first, second)
        local enabled = (first == group) and (second and true or false) or (first and true or false)
        for _, row in ipairs(group.rows) do
            if row.check then
                if enabled then row.check:Enable() else row.check:Disable() end
            end
            if row.up then
                UI.SetWidgetEnabled(row.up, enabled and row.index ~= nil and row.index > 1)
            end
            if row.down then
                UI.SetWidgetEnabled(row.down, enabled and row.index ~= nil and row.index < #group.rows)
            end
        end
        group:SetAlpha(enabled and 1 or 0.45)
    end

    local count = #Items()
    local height = math.max(rowH, count * rowH + math.max(0, count - 1) * rowGap)
    group:SetHeight(height)

    if desc.label then
        local title = page:CreateFontString(nil, "ARTWORK", UI.FONT.body)
        title:SetText(desc.label)
        UI.BoundLabel(title, "LEFT")
        stack.Add(title, UI.PAD.sm, { height = UI.SIZE.rowHCompact, stretch = false })
    end
    stack.Add(group, UI.PAD.xs, { height = height })
    ctx.Register(desc, group, Render)
end

-- ---------------------------------------------------------------------------
-- Panneau
-- ---------------------------------------------------------------------------

--- Construit et enregistre un panneau d'options a categories.
--
-- spec.name        : titre du panneau et de la categorie Blizzard
-- spec.description : sous-titre
-- spec.db          : fonction() -> table (la base ; rappelee a chaque acces)
-- spec.defaults    : table des defauts par cle, pour desc.default absent et OnDefault
-- spec.options     : liste de descripteurs (voir NormalizeOption)
-- spec.onChange    : fonction(key, value, desc), apres desc.onChange
-- spec.framePrefix : prefixe des noms de frame (defaut "YayaCore")
-- spec.rail        : nil = rail si plus d'une categorie ; true/false pour forcer
--
-- Rend nil sans CreateFrame, sinon un handle :
--   panel, category (objet Blizzard ou nil), Open(), Refresh(),
--   SetCategory(name), widgets = {[key] = widget}, pages = {[category] = frame},
--   categories = {name, ...}.
function YSettings.BuildPanel(spec)
    if type(CreateFrame) ~= "function" or type(spec) ~= "table" then
        return nil
    end
    local prefix = tostring(spec.framePrefix or "YayaCore")

    local function DefaultDB()
        spec.__db = spec.__db or {}
        return spec.__db
    end
    local getDB = type(spec.db) == "function" and spec.db or DefaultDB

    local handle = {
        widgets = {},
        pages = {},
        categories = {},
    }
    local ctx = {
        widgets = handle.widgets,
        refreshers = {},
        byKey = {},
        refreshing = false,
    }

    function ctx.ResolveDB(desc)
        local provider = (desc and type(desc.db) == "function") and desc.db or getDB
        local db = provider()
        if type(db) ~= "table" then
            db = {}
        end
        return db
    end

    -- Normalisation et regroupement par categorie, dans l'ordre d'apparition.
    local grouped = {}
    local normalized = {}
    local previousCategory
    for _, raw in ipairs(spec.options or {}) do
        if type(raw) == "table" then
            if raw.default == nil and raw.key ~= nil and type(spec.defaults) == "table" then
                raw.default = spec.defaults[raw.key]
            end
            local desc = YSettings.NormalizeOption(raw, previousCategory)
            if desc and BUILDERS[desc.type] then
                previousCategory = desc.category
                if not grouped[desc.category] then
                    grouped[desc.category] = {}
                    handle.categories[#handle.categories + 1] = desc.category
                end
                local bucket = grouped[desc.category]
                bucket[#bucket + 1] = desc
                normalized[#normalized + 1] = desc
                if desc.key ~= nil then
                    ctx.byKey[desc.key] = desc
                end
            end
        end
    end

    local function IsDependencyMet(desc, db)
        local dependency = desc.dependsOn
        if dependency == nil then
            return true
        end
        if type(dependency) == "function" then
            local ok, result = pcall(dependency, db)
            return ok and result and true or false
        end
        if type(dependency) == "string" then
            local other = ctx.byKey[dependency]
            if other and type(other.get) == "function" then
                return other.get(ctx.ResolveDB(other)) and true or false
            end
            return db[dependency] and true or false
        end
        return true
    end

    function ctx.Register(desc, widget, push)
        if desc.key ~= nil then
            ctx.widgets[desc.key] = widget
        end
        ctx.refreshers[#ctx.refreshers + 1] = function()
            local db = ctx.ResolveDB(desc)
            if type(push) == "function" then
                push(db)
            end
            if desc.dependsOn ~= nil then
                UI.SetWidgetEnabled(widget, IsDependencyMet(desc, db))
            end
        end
    end

    --- Resynchronise chaque widget depuis la base, sans rappeler onChange.
    function handle.Refresh()
        ctx.refreshing = true
        for _, refresher in ipairs(ctx.refreshers) do
            local ok, err = pcall(refresher)
            if not ok then
                ReportError("refresh", err)
            end
        end
        ctx.refreshing = false
    end

    --- Ecrit une valeur, notifie, puis resynchronise tout le panneau.
    function ctx.Commit(desc, value)
        if ctx.refreshing then
            return
        end
        local db = ctx.ResolveDB(desc)
        desc.set(db, value)
        if type(desc.onChange) == "function" then
            desc.onChange(desc.key, value, desc)
        end
        if type(spec.onChange) == "function" then
            spec.onChange(desc.key, value, desc)
        end
        handle.Refresh()
    end

    -- Panneau et en-tete.
    local panel = CreateFrame("Frame", prefix .. "OptionsPanel")
    panel.name = spec.name or prefix
    panel.handle = handle
    handle.panel = panel

    local title = panel:CreateFontString(nil, "ARTWORK", UI.FONT.heading)
    title:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, -PAD)
    title:SetText(panel.name)
    UI.BoundLabel(title, "LEFT")
    panel.title = title

    local description = panel:CreateFontString(nil, "ARTWORK", UI.FONT.body)
    description:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -UI.PAD.sm)
    description:SetPoint("RIGHT", panel, "RIGHT", -PAD, 0)
    description:SetTextColor(UI.Unpack(UI.COLOR.textMuted))
    description:SetText(spec.description or "")
    UI.BoundLabel(description, "LEFT")
    panel.description = description

    local headerBottom = PAD + UI.SIZE.headerH + UI.PAD.sm + UI.SIZE.rowHCompact + UI.PAD.lg

    -- Rail des categories.
    local useRail = spec.rail == true or (spec.rail == nil and #handle.categories > 1)
    local railButtons = {}
    local contentLeft = 0
    if useRail then
        local rail = CreateFrame("Frame", nil, panel)
        rail:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, -headerBottom)
        rail:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", PAD, PAD)
        rail:SetWidth(UI.SIZE.settingsRailW)
        handle.rail = rail

        local railStack = UI.StackLayout(rail, {})
        for _, category in ipairs(handle.categories) do
            local button = UI.CreateButton(rail, category, { small = true })
            if button then
                button.category = category
                button.selectedBg = button:CreateTexture(nil, "ARTWORK")
                button.selectedBg:SetAllPoints()
                button.selectedBg:SetColorTexture(UI.Unpack(UI.COLOR.selected))
                button.selectedBg:Hide()
                button:SetScript("OnClick", function()
                    handle.SetCategory(category)
                end)
                railStack.Add(button, UI.PAD.sm, { height = UI.ACTION.height })
                railButtons[#railButtons + 1] = button
            end
        end

        local divider = UI.CreateDivider(panel, { vertical = true })
        if divider then
            divider:SetPoint("TOPLEFT", rail, "TOPRIGHT", UI.PAD.sm, 0)
            divider:SetPoint("BOTTOMLEFT", rail, "BOTTOMRIGHT", UI.PAD.sm, 0)
        end
        contentLeft = UI.SIZE.settingsRailW + UI.PAD.lg
    end
    handle.railButtons = railButtons

    -- Zone scrollable : une page par categorie, une seule visible.
    local okScroll, scrollFrame = pcall(CreateFrame, "ScrollFrame", prefix .. "OptionsScrollFrame",
        panel, "UIPanelScrollFrameTemplate")
    if not okScroll or type(scrollFrame) ~= "table" then
        scrollFrame = CreateFrame("ScrollFrame", prefix .. "OptionsScrollFrame", panel)
    end
    scrollFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", contentLeft, -headerBottom)
    scrollFrame:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -24, PAD)
    handle.scrollFrame = scrollFrame

    for _, category in ipairs(handle.categories) do
        local page = CreateFrame("Frame", nil, scrollFrame)
        page:SetSize(1, 1)
        page:Hide()
        handle.pages[category] = page

        local stack = UI.StackLayout(page, { left = PAD, right = PAD, top = PAD })
        for _, desc in ipairs(grouped[category]) do
            local ok, err = pcall(BUILDERS[desc.type], page, stack, desc, ctx)
            if not ok then
                ReportError("option " .. tostring(desc.key or desc.type), err)
            end
        end
        page.contentHeight = stack.Finish(PAD)
        page:SetHeight(page.contentHeight)
    end

    local function ApplyPageSize(page)
        local width = scrollFrame:GetWidth() or 0
        if width > 0 then
            page:SetWidth(width)
        end
        page:SetHeight(page.contentHeight or 1)
    end

    local function PaintRail(active)
        for _, button in ipairs(railButtons) do
            local selected = button.category == active
            if selected then
                button.selectedBg:Show()
            else
                button.selectedBg:Hide()
            end
            if type(button.SetLabel) == "function" then
                button.SetLabel(selected and UI.Colorize("accent", button.category) or button.category)
            elseif type(button.SetText) == "function" then
                button:SetText(selected and UI.Colorize("accent", button.category) or button.category)
            end
        end
    end

    --- Affiche la page d'une categorie et met le rail en evidence.
    function handle.SetCategory(name)
        local page = handle.pages[name]
        if not page then
            return false
        end
        if handle.currentPage and handle.currentPage ~= page then
            handle.currentPage:Hide()
        end
        handle.activeCategory = name
        handle.currentPage = page
        scrollFrame:SetScrollChild(page)
        page:Show()
        ApplyPageSize(page)
        if type(scrollFrame.SetVerticalScroll) == "function" then
            scrollFrame:SetVerticalScroll(0)
        end
        PaintRail(name)
        return true
    end

    scrollFrame:SetScript("OnSizeChanged", function()
        if handle.currentPage then
            ApplyPageSize(handle.currentPage)
        end
    end)

    if handle.categories[1] then
        handle.SetCategory(handle.categories[1])
    end

    panel:SetScript("OnShow", function()
        handle.Refresh()
    end)

    --- Remet chaque cle a son defaut connu, puis resynchronise.
    panel.OnDefault = function()
        for _, desc in ipairs(normalized) do
            if desc.key ~= nil and desc.default ~= nil then
                desc.set(ctx.ResolveDB(desc), DeepCopy(desc.default))
            end
        end
        handle.Refresh()
    end
    panel.OnRefresh = handle.Refresh
    -- Noms de l'ancien InterfaceOptions, pour le repli.
    panel.default = panel.OnDefault
    panel.refresh = handle.Refresh

    -- Enregistrement dans la fenetre d'options du client.
    local blizzard = _G.Settings
    if type(blizzard) == "table"
        and type(blizzard.RegisterCanvasLayoutCategory) == "function"
        and type(blizzard.RegisterAddOnCategory) == "function" then
        local ok, category = pcall(blizzard.RegisterCanvasLayoutCategory, panel, panel.name)
        if ok and category then
            pcall(blizzard.RegisterAddOnCategory, category)
            handle.category = category
        end
    elseif type(InterfaceOptions_AddCategory) == "function" then
        InterfaceOptions_AddCategory(panel)
    end

    --- Ouvre la fenetre d'options sur ce panneau.
    function handle.Open()
        local api = _G.Settings
        if type(api) == "table" and type(api.OpenToCategory) == "function"
            and handle.category and type(handle.category.GetID) == "function" then
            api.OpenToCategory(handle.category:GetID())
            return
        end
        if type(InterfaceOptionsFrame_OpenToCategory) == "function" then
            -- Deux appels : le premier ouvre la fenetre, le second selectionne
            -- reellement la categorie (bug historique du client).
            InterfaceOptionsFrame_OpenToCategory(panel)
            InterfaceOptionsFrame_OpenToCategory(panel)
        end
    end

    handle.Refresh()
    return handle
end
