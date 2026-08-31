-- YayaCore.UI : systeme de design partage de la suite Yaya.
--
-- Le depot comptait sept teintes de fond sombre pour un meme role, trois
-- recettes de striping, deux familles de backdrop -- dont deux dans le seul
-- YayaQueue -- et trois familles de couleur d'accent concurrentes. Chaque frame
-- reimplementait ses infobulles (vingt-cinq copies de OnEnter/OnLeave), ses
-- lignes de liste, et oubliait ses gardes de debordement : ni SetWordWrap(false)
-- ni SetMaxLines nulle part dans YayaQueue et YayaWeeklyTracker.
--
-- Ce module est la source de verite unique : les tokens d'abord, les fabriques
-- ensuite.
--
-- ACCES SANS LOCAL. Les addons consommateurs y accedent par champ
-- (YayaCore.UI.PAD.md) ou via une seule local par fichier :
-- YayaWeeklyTracker.lua et YayaQueue.lua sont a 198 et 195 locals de chunk sur
-- les 200 que Lua 5.1 autorise. Un depassement n'est pas un avertissement --
-- le chunk ne compile pas et l'addon entier cesse de charger, sans message
-- clair en jeu.

local YayaCore = _G.YayaCore
if type(YayaCore) ~= "table" then
    return
end

local UI = {
    version = 1,
}
YayaCore.UI = UI

-- ---------------------------------------------------------------------------
-- Tokens : couleurs
-- ---------------------------------------------------------------------------

-- Menthe 00ff98 : deja le prefixe de chat de YayaCore, YayaFrame et
-- YayaWarbandBankDefault, donc la couleur de marque de fait. Les familles
-- concurrentes s'alignent dessus : 33ff99 (Queue, Sniper, VendorFilter) et
-- 4cc9f0 (CraftingOrders, CraftedPrice, ContainerValues).
UI.COLOR = {
    accent    = { 0.00, 1.00, 0.60, 1.00 },
    accentDim = { 0.00, 1.00, 0.60, 0.30 },

    panel     = { 0.04, 0.05, 0.05, 0.92 },
    header    = { 0.08, 0.10, 0.10, 0.96 },
    border    = { 0.24, 0.28, 0.27, 0.90 },
    divider   = { 0.24, 0.28, 0.27, 0.55 },

    rowOdd    = { 1.00, 1.00, 1.00, 0.025 },
    rowEven   = { 1.00, 1.00, 1.00, 0.000 },
    hover     = { 0.00, 1.00, 0.60, 0.12 },
    selected  = { 0.00, 1.00, 0.60, 0.22 },

    text      = { 0.90, 0.90, 0.88, 1.00 },
    textMuted = { 0.62, 0.62, 0.60, 1.00 },
    success   = { 0.50, 1.00, 0.50, 1.00 },
    warning   = { 1.00, 0.80, 0.40, 1.00 },
    danger    = { 1.00, 0.40, 0.40, 1.00 },
    critical  = { 1.00, 0.20, 0.20, 1.00 },
    category  = { 0.84, 0.70, 0.41, 1.00 },
}

-- Equivalents en balisage inline. Reprennent les valeurs deja employees par
-- YayaWeeklyTracker pour les statuts, de facon a ce que l'alignement de la
-- suite ne change pas la semantique de couleur la mieux etablie.
UI.HEX = {
    accent   = "|cff00ff98",
    text     = "|cffe6e6e0",
    muted    = "|cff9e9e99",
    success  = "|cff7fff7f",
    warning  = "|cffffcc66",
    danger   = "|cffff6666",
    critical = "|cffff3333",
    category = "|cffd6b36a",
    stop     = "|r",
}

--- Enrobe un texte dans une couleur de UI.HEX.
function UI.Colorize(tone, text)
    local prefix = UI.HEX[tone or "text"] or UI.HEX.text
    return prefix .. tostring(text) .. UI.HEX.stop
end

--- Deplie une couleur token en r, g, b, a.
function UI.Unpack(color, alpha)
    if type(color) ~= "table" then
        return 1, 1, 1, alpha or 1
    end
    return color[1] or 0, color[2] or 0, color[3] or 0, alpha or color[4] or 1
end

-- ---------------------------------------------------------------------------
-- Tokens : metriques
-- ---------------------------------------------------------------------------

-- Echelle d'espacement. Le depot utilisait 6, 8, 10, 12, 14, 16 et 18 pour le
-- meme role selon l'addon, et des ecarts verticaux de -4 a -14.
UI.PAD = {
    xs = 2,
    sm = 4,
    md = 6,
    lg = 10,
    xl = 14,
}

UI.SIZE = {
    rowH        = 20,
    rowHCompact = 16,
    iconSm      = 14,
    icon        = 18,
    headerH     = 22,
    glyph       = 18,
    divider     = 1,
}

UI.FONT = {
    title  = "GameFontNormal",
    header = "GameFontNormalSmall",
    body   = "GameFontHighlightSmall",
    muted  = "GameFontDisableSmall",
}

-- ATTENTION -- CRITIQUE AUTOCLICKER. Ne pas modifier sans le dire.
--
-- L'utilisateur superpose volontairement le panneau YayaQueue et la frame
-- partagee YayaFrame pour que le bouton Next et le premier bouton du tracker
-- hebdomadaire tombent aux memes coordonnees ecran : son autoclicker vise un
-- seul point et les boutons s'y succedent.
--
-- Le mecanisme repose sur trois proprietes, toutes obligatoires :
--
--   1. les frames sont ancrees BOTTOMLEFT et grandissent vers le haut, donc le
--      bord bas ne bouge jamais ;
--   2. la pile de boutons est packee depuis le bas a pas constant, donc quand
--      un bouton disparait la frame retrecit d'autant par le haut et les
--      boutons restants gardent leur position ecran ;
--   3. un bouton sans action est Hide(), jamais seulement desactive, pour que
--      le clic retombe sur le bouton situe dessous.
--
-- Ces valeurs sont partagees par YayaQueue et YayaWeeklyTracker : le slot 1 des
-- deux frames doit etre exactement au meme offset du bord bas. Auparavant Next
-- faisait 120x22 et les boutons hebdo 178x20, donc l'alignement etait
-- approximatif. Les modifier oblige l'utilisateur a repointer son autoclicker.
UI.ACTION = {
    height       = 22,
    gap          = 4,
    bottomMargin = 6,
}
UI.ACTION.pitch = UI.ACTION.height + UI.ACTION.gap

-- Recette de backdrop unique. WHITE8X8 pour le fond comme pour la bordure
-- donne un filet net de 1 px, la ou UI-Tooltip-Border tuile une bordure de 12
-- a 16 px qui mange le contenu.
UI.BACKDROP = {
    bgFile   = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    edgeSize = 1,
    insets   = { left = 1, right = 1, top = 1, bottom = 1 },
}

-- ---------------------------------------------------------------------------
-- Fabriques : habillage
-- ---------------------------------------------------------------------------

--- Applique le backdrop unique de la suite.
--
-- opts.color       : couleur de fond (defaut UI.COLOR.panel)
-- opts.borderColor : couleur de bordure (defaut UI.COLOR.border)
-- opts.noBorder    : fond seul, sans filet
function UI.ApplyPanelBackdrop(frame, opts)
    if type(frame) ~= "table" then
        return frame
    end
    opts = opts or {}
    local fill = opts.color or UI.COLOR.panel

    if type(frame.SetBackdrop) == "function" then
        frame:SetBackdrop({
            bgFile = UI.BACKDROP.bgFile,
            edgeFile = (not opts.noBorder) and UI.BACKDROP.edgeFile or nil,
            edgeSize = UI.BACKDROP.edgeSize,
            insets = UI.BACKDROP.insets,
        })
        frame:SetBackdropColor(UI.Unpack(fill))
        if not opts.noBorder and type(frame.SetBackdropBorderColor) == "function" then
            frame:SetBackdropBorderColor(UI.Unpack(opts.borderColor or UI.COLOR.border))
        end
        return frame
    end

    -- La frame n'a pas herite de BackdropTemplate : on retombe sur l'aplat que
    -- YayaFrame posait a la main avant ce module.
    if not frame.yayaBackdropFallback and type(frame.CreateTexture) == "function" then
        frame.yayaBackdropFallback = frame:CreateTexture(nil, "BACKGROUND")
        frame.yayaBackdropFallback:SetAllPoints()
    end
    if frame.yayaBackdropFallback then
        frame.yayaBackdropFallback:SetColorTexture(UI.Unpack(fill))
    end
    return frame
end

--- Interdit a un FontString de deborder de sa cellule.
--
-- Les tables du depot placaient des FontString avec un TOPLEFT et un RIGHT sans
-- aucune garde : un nom de recette long passait sur deux lignes et chevauchait
-- la ligne suivante, dont l'ecart etait fixe a -4 px.
function UI.BoundLabel(fontString, justify)
    if type(fontString) ~= "table" then
        return fontString
    end
    if type(fontString.SetWordWrap) == "function" then
        fontString:SetWordWrap(false)
    end
    if type(fontString.SetMaxLines) == "function" then
        fontString:SetMaxLines(1)
    end
    if type(fontString.SetJustifyH) == "function" then
        fontString:SetJustifyH(justify or "LEFT")
    end
    return fontString
end

--- Applique une police de UI.FONT a un FontString.
--
-- SetFontObject attend un objet Font. Le nom global est resolu ici pour ne pas
-- dependre de la tolerance du client aux chaines.
function UI.SetFont(fontString, name)
    if type(fontString) ~= "table" or type(fontString.SetFontObject) ~= "function" then
        return fontString
    end
    pcall(fontString.SetFontObject, fontString, _G[name] or name)
    return fontString
end

--- Cree un separateur horizontal de 1 px.
function UI.CreateDivider(parent, opts)
    if type(parent) ~= "table" or type(parent.CreateTexture) ~= "function" then
        return nil
    end
    opts = opts or {}
    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetHeight(UI.SIZE.divider)
    line:SetColorTexture(UI.Unpack(opts.color or UI.COLOR.divider))
    return line
end

-- ---------------------------------------------------------------------------
-- Fabriques : verrou de position
-- ---------------------------------------------------------------------------

-- Les emojis ne sont pas rendus par les polices du client : le verrou doit etre
-- une texture. On sonde d'abord les atlas, puis on retombe sur les fichiers de
-- l'ancien bouton de verrouillage des barres d'action, presents depuis toujours,
-- puis sur un glyphe texte.
UI.LOCK_ATLAS = {
    locked = { "common-icon-padlock", "UI-LockIcon", "Garr_LockIcon" },
    unlocked = { "common-icon-unlocked", "UI-UnlockIcon" },
}

UI.LOCK_TEXTURE = {
    locked = "Interface\\Buttons\\LockButton-Locked-Up",
    unlocked = "Interface\\Buttons\\LockButton-Unlocked-Up",
}

UI.LOCK_GLYPH = {
    locked = "L",
    unlocked = "U",
}

-- Chevron de repli. Memes contraintes que le verrou : pas d'emoji, et les
-- fichiers des anciens boutons plus/moins sont presents depuis toujours.
UI.EXPAND_TEXTURE = {
    collapsed = "Interface\\Buttons\\UI-PlusButton-Up",
    expanded = "Interface\\Buttons\\UI-MinusButton-Up",
}

UI.EXPAND_GLYPH = {
    collapsed = "+",
    expanded = "-",
}

local resolvedLockAtlas = {}

local function ResolveAtlas(candidates)
    if type(candidates) ~= "table" then
        return nil
    end
    if not (C_Texture and type(C_Texture.GetAtlasInfo) == "function") then
        return nil
    end
    for _, name in ipairs(candidates) do
        local ok, info = pcall(C_Texture.GetAtlasInfo, name)
        if ok and info then
            return name
        end
    end
    return nil
end

--- Peint une texture avec l'icone de verrou correspondant a l'etat.
--
-- Renvoie true si une icone a pu etre appliquee : l'appelant retombe sinon sur
-- UI.LOCK_GLYPH.
function UI.SetLockIcon(texture, locked)
    if type(texture) ~= "table" then
        return false
    end
    local key = locked and "locked" or "unlocked"

    if resolvedLockAtlas[key] == nil then
        resolvedLockAtlas[key] = ResolveAtlas(UI.LOCK_ATLAS[key]) or false
    end

    local atlas = resolvedLockAtlas[key]
    if atlas and type(texture.SetAtlas) == "function" then
        if pcall(texture.SetAtlas, texture, atlas, false) then
            return true
        end
    end

    if type(texture.SetTexture) == "function" then
        if pcall(texture.SetTexture, texture, UI.LOCK_TEXTURE[key]) then
            return true
        end
    end

    return false
end

--- Peint une texture avec le chevron correspondant a l'etat de repli.
function UI.SetExpandIcon(texture, collapsed)
    if type(texture) ~= "table" or type(texture.SetTexture) ~= "function" then
        return false
    end
    local key = collapsed and "collapsed" or "expanded"
    return pcall(texture.SetTexture, texture, UI.EXPAND_TEXTURE[key]) and true or false
end

-- ---------------------------------------------------------------------------
-- Fabriques : boutons
-- ---------------------------------------------------------------------------

local function AttachTooltip(frame, title, body, anchor)
    if not (YayaCore.Tooltip and type(YayaCore.Tooltip.Attach) == "function") then
        return
    end
    YayaCore.Tooltip.Attach(frame, function(tooltip)
        tooltip:SetText(title or "")
        if body then
            tooltip:AddLine(body, 1, 1, 1, true)
        end
    end, { anchor = anchor })
end

--- Bouton d'action standard, aux dimensions de UI.ACTION.
--
-- opts.width   : largeur
-- opts.height  : hauteur (defaut UI.ACTION.height)
-- opts.tooltip : { title, body, anchor }
function UI.CreateButton(parent, text, opts)
    if type(parent) ~= "table" or type(CreateFrame) ~= "function" then
        return nil
    end
    opts = opts or {}
    local button = CreateFrame("Button", opts.name, parent, opts.template or "UIPanelButtonTemplate")
    button:SetHeight(opts.height or UI.ACTION.height)
    if opts.width then
        button:SetWidth(opts.width)
    end
    if text and type(button.SetText) == "function" then
        button:SetText(text)
    end

    --- Cable une infobulle sans reimplementer OnEnter/OnLeave.
    function button.SetTooltip(title, body, anchor)
        AttachTooltip(button, title, body, anchor or "ANCHOR_TOP")
    end

    if opts.tooltip then
        button.SetTooltip(opts.tooltip.title, opts.tooltip.body, opts.tooltip.anchor)
    end

    return button
end

--- Petit bouton carre d'en-tete : R pour reinitialiser, verrou pour figer.
--
-- kind : "reset" ou "lock"
function UI.CreateGlyphButton(parent, kind, opts)
    if type(parent) ~= "table" or type(CreateFrame) ~= "function" then
        return nil
    end
    opts = opts or {}
    local button = CreateFrame("Button", opts.name, parent, "UIPanelButtonTemplate")
    button:SetSize(UI.SIZE.glyph, UI.SIZE.glyph)

    if kind == "lock" then
        button.icon = button:CreateTexture(nil, "OVERLAY")
        button.icon:SetPoint("CENTER")
        button.icon:SetSize(UI.SIZE.glyph - 6, UI.SIZE.glyph - 6)

        --- Reflete l'etat de verrouillage sur l'icone, ou a defaut sur le texte.
        function button.SetLocked(locked)
            button.locked = locked and true or false
            if UI.SetLockIcon(button.icon, button.locked) then
                button.icon:Show()
                button:SetText("")
                button.icon:SetVertexColor(
                    UI.Unpack(button.locked and UI.COLOR.locked or UI.COLOR.textMuted)
                )
            else
                button.icon:Hide()
                button:SetText(UI.LOCK_GLYPH[button.locked and "locked" or "unlocked"])
            end
        end

        button.SetLocked(opts.locked)
    else
        button:SetText("R")
    end

    function button.SetTooltip(title, body, anchor)
        AttachTooltip(button, title, body, anchor or "ANCHOR_LEFT")
    end

    if opts.tooltip then
        button.SetTooltip(opts.tooltip.title, opts.tooltip.body, opts.tooltip.anchor)
    end

    return button
end

-- ---------------------------------------------------------------------------
-- Fabriques : en-tete
-- ---------------------------------------------------------------------------

--- Bandeau de titre : chrome de frame, ou en-tete de section repliable.
--
-- opts.anchor       : false pour laisser l'appelant poser les points
-- opts.height       : hauteur (defaut UI.SIZE.headerH)
-- opts.moveTarget   : frame reellement deplacee par le glisser
-- opts.isLocked     : fonction renvoyant true quand le deplacement est interdit
-- opts.onMoveStopped: rappel de sauvegarde de position
-- opts.collapsible  : ajoute un chevron a gauche et header.SetCollapsed
-- opts.onClick      : rappel du clic sur le bandeau
function UI.CreateHeader(parent, title, opts)
    if type(parent) ~= "table" or type(CreateFrame) ~= "function" then
        return nil
    end
    opts = opts or {}

    local header = CreateFrame("Frame", opts.name, parent)
    header:SetHeight(opts.height or UI.SIZE.headerH)
    if opts.anchor ~= false then
        header:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
        header:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
    end

    header.bg = header:CreateTexture(nil, "BACKGROUND")
    header.bg:SetAllPoints()
    header.bg:SetColorTexture(UI.Unpack(UI.COLOR.header))

    -- Filet d'accent : la seule marque de couleur du chrome.
    header.rule = header:CreateTexture(nil, "ARTWORK")
    header.rule:SetHeight(UI.SIZE.divider)
    header.rule:SetPoint("BOTTOMLEFT")
    header.rule:SetPoint("BOTTOMRIGHT")
    header.rule:SetColorTexture(UI.Unpack(opts.ruleColor or UI.COLOR.accentDim))

    local titleInset = UI.PAD.md
    if opts.collapsible then
        header.chevron = header:CreateTexture(nil, "OVERLAY")
        header.chevron:SetSize(UI.SIZE.iconSm - 2, UI.SIZE.iconSm - 2)
        header.chevron:SetPoint("LEFT", header, "LEFT", UI.PAD.sm, 0)
        titleInset = UI.PAD.sm + (UI.SIZE.iconSm - 2) + UI.PAD.xs
    end

    header.title = header:CreateFontString(nil, "OVERLAY", opts.font or UI.FONT.header)
    header.title:SetPoint("LEFT", header, "LEFT", titleInset, 0)
    header.title:SetPoint("RIGHT", header, "RIGHT", -UI.PAD.sm, 0)
    header.title:SetTextColor(UI.Unpack(opts.titleColor or UI.COLOR.accent))
    header.title:SetText(title or "")
    UI.BoundLabel(header.title)

    header.buttons = {}
    header.IsLocked = opts.isLocked

    --- Ajoute un bouton dans le rail droit, de droite a gauche.
    function header.AddButton(button)
        if not button then
            return button
        end
        local previous = header.buttons[#header.buttons]
        button:ClearAllPoints()
        if previous then
            button:SetPoint("RIGHT", previous, "LEFT", -UI.PAD.xs, 0)
        else
            button:SetPoint("RIGHT", header, "RIGHT", -UI.PAD.sm, 0)
        end
        header.buttons[#header.buttons + 1] = button
        -- Le titre s'arrete avant le bouton le plus a gauche.
        header.title:SetPoint("RIGHT", button, "LEFT", -UI.PAD.sm, 0)
        return button
    end

    if opts.collapsible then
        --- Reflete l'etat de repli sur le chevron, ou a defaut sur le titre.
        function header.SetCollapsed(collapsed)
            header.collapsed = collapsed and true or false
            if UI.SetExpandIcon(header.chevron, header.collapsed) then
                header.chevron:Show()
            elseif header.chevron then
                header.chevron:Hide()
            end
        end

        header.SetCollapsed(opts.collapsed)
    end

    -- Poignee de deplacement. Le conteneur partage activait la souris sur toute
    -- sa surface : il attrapait les glissers accidentels et interceptait les
    -- clics destines aux frames situees dessous.
    if opts.moveTarget then
        header:EnableMouse(true)
        header:RegisterForDrag("LeftButton")
        header:SetScript("OnDragStart", function()
            if type(header.IsLocked) == "function" and header.IsLocked() then
                return
            end
            if type(opts.moveTarget.StartMoving) == "function" then
                opts.moveTarget:StartMoving()
            end
        end)
        header:SetScript("OnDragStop", function()
            if type(opts.moveTarget.StopMovingOrSizing) == "function" then
                opts.moveTarget:StopMovingOrSizing()
            end
            if type(opts.onMoveStopped) == "function" then
                opts.onMoveStopped()
            end
        end)
    end

    if type(opts.onClick) == "function" then
        header:EnableMouse(true)
        header:SetScript("OnMouseUp", function(_, button)
            opts.onClick(header, button)
        end)
    end

    return header
end

-- ---------------------------------------------------------------------------
-- Fabriques : lignes de liste
-- ---------------------------------------------------------------------------

local function RowTooltipTarget(row)
    if row.itemLink then
        return row.itemLink
    end
    if row.itemID then
        return "item:" .. tostring(row.itemID)
    end
    return nil
end

--- Equipe un bouton existant des elements d'une ligne de liste.
--
-- Separe de UI.CreateRow parce qu'un ScrollBox fournit lui-meme les boutons
-- recycles : l'initialiseur decore le bouton au premier passage.
function UI.DecorateRow(row, opts)
    if type(row) ~= "table" or row.yayaRow then
        return row
    end
    opts = opts or {}
    row.yayaRow = true

    row:SetHeight(opts.height or UI.SIZE.rowH)
    if type(row.SetClipsChildren) == "function" then
        row:SetClipsChildren(true)
    end

    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
    row.bg:SetColorTexture(UI.Unpack(UI.COLOR.rowEven))

    row.hover = row:CreateTexture(nil, "HIGHLIGHT")
    row.hover:SetAllPoints()
    row.hover:SetColorTexture(UI.Unpack(UI.COLOR.hover))

    -- Les colonnes fixes reservent leur largeur en premier ; le libelle prend
    -- ce qui reste, donc il ne peut pas atteindre la colonne de droite.
    local leftInset = opts.leftInset or UI.PAD.md
    local iconSize = opts.iconSize or UI.SIZE.iconSm
    if opts.icon then
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(iconSize, iconSize)
        row.icon:SetPoint("LEFT", row, "LEFT", leftInset, 0)
        row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        leftInset = leftInset + iconSize + UI.PAD.sm
    end

    row.value = row:CreateFontString(nil, "OVERLAY", opts.valueFont or UI.FONT.body)
    row.value:SetPoint("RIGHT", row, "RIGHT", -(opts.rightInset or UI.PAD.md), 0)
    if opts.valueWidth then
        row.value:SetWidth(opts.valueWidth)
    end
    UI.BoundLabel(row.value, "RIGHT")

    row.label = row:CreateFontString(nil, "OVERLAY", opts.labelFont or UI.FONT.body)
    row.label:SetPoint("LEFT", row, "LEFT", leftInset, 0)
    row.label:SetPoint("RIGHT", row.value, "LEFT", -UI.PAD.sm, 0)
    UI.BoundLabel(row.label, "LEFT")

    row.tooltipAnchor = opts.tooltipAnchor or "ANCHOR_RIGHT"

    --- Alterne le fond une ligne sur deux.
    function row.SetStripe(index)
        local odd = (tonumber(index) or 0) % 2 == 1
        row.bg:SetColorTexture(UI.Unpack(odd and UI.COLOR.rowOdd or UI.COLOR.rowEven))
    end

    --- Teinte le libelle et la valeur avec un token de couleur.
    function row.SetTone(tone)
        local color = UI.COLOR[tone or "text"] or UI.COLOR.text
        row.value:SetTextColor(UI.Unpack(color))
    end

    --- Infobulle libre, pour une ligne qui ne porte pas d'objet.
    function row.SetTooltip(title, body)
        row.tooltipTitle = title
        row.tooltipBody = body
    end

    --- Rattache un objet a la ligne : icone et infobulle native, sans toucher
    --- au libelle.
    --
    -- Le lien exact est conserve tel quel. Le reconstruire depuis le seul
    -- itemID ferait silencieusement disparaitre la qualite et les bonus.
    --
    -- opts.onName(name) : rappel a l'arrivee du nom, pour les lignes qui
    -- composent elles-memes leur libelle.
    function row.SetItemTarget(itemID, itemLink, onName)
        row.itemLoadToken = (row.itemLoadToken or 0) + 1
        local token = row.itemLoadToken
        row.itemID = tonumber(itemID)
        row.itemLink = itemLink

        if not row.itemID then
            return
        end

        local function Apply()
            -- La ligne a pu etre recyclee entre la demande et la reponse.
            if row.itemLoadToken ~= token then
                return
            end
            if row.icon and C_Item and type(C_Item.GetItemIconByID) == "function" then
                row.icon:SetTexture(C_Item.GetItemIconByID(row.itemID))
            end
            if type(onName) == "function" and C_Item and type(C_Item.GetItemNameByID) == "function" then
                local name = C_Item.GetItemNameByID(row.itemID)
                if name then
                    onName(name)
                end
            end
        end

        if YayaCore.Item and type(YayaCore.Item.Load) == "function" then
            YayaCore.Item.Load(row.itemID, Apply)
        else
            Apply()
        end
    end

    --- Rattache un objet et en fait le libelle de la ligne.
    function row.SetItem(itemID, itemLink, fallbackName)
        row.label:SetText(itemLink or fallbackName or "...")
        row.SetItemTarget(itemID, itemLink, function(name)
            if not row.itemLink then
                row.label:SetText(name)
            end
        end)
    end

    --- Remet la ligne a zero avant recyclage.
    function row.Reset()
        if GameTooltip and type(GameTooltip.IsOwned) == "function" and GameTooltip:IsOwned(row) then
            GameTooltip:Hide()
        end
        row.itemLoadToken = (row.itemLoadToken or 0) + 1
        row.data = nil
        row.itemID = nil
        row.itemLink = nil
        row.tooltipTitle = nil
        row.tooltipBody = nil
        row.label:SetText("")
        row.value:SetText("")
        row.value:SetTextColor(UI.Unpack(UI.COLOR.text))
        if row.icon then
            row.icon:SetTexture(nil)
        end
        row.bg:SetColorTexture(UI.Unpack(UI.COLOR.rowEven))
        if type(row.SetScript) == "function" then
            row:SetScript("OnClick", nil)
        end
    end

    -- Scripts stables installes une seule fois : ils relisent l'etat de la
    -- ligne a l'appel, donc le recyclage ne laisse pas de fermeture perimee.
    row:SetScript("OnEnter", function(self)
        if not GameTooltip then
            return
        end
        local target = RowTooltipTarget(self)
        if target then
            GameTooltip:SetOwner(self, self.tooltipAnchor)
            GameTooltip:SetHyperlink(target)
            GameTooltip:Show()
            return
        end
        if self.tooltipTitle then
            GameTooltip:SetOwner(self, self.tooltipAnchor)
            GameTooltip:SetText(self.tooltipTitle)
            if self.tooltipBody then
                GameTooltip:AddLine(self.tooltipBody, 1, 1, 1, true)
            end
            GameTooltip:Show()
        end
    end)

    row:SetScript("OnLeave", function(self)
        if GameTooltip and type(GameTooltip.IsOwned) == "function" and GameTooltip:IsOwned(self) then
            GameTooltip:Hide()
        end
    end)

    return row
end

--- Cree une ligne de liste autonome, hors ScrollBox.
function UI.CreateRow(parent, opts)
    if type(parent) ~= "table" or type(CreateFrame) ~= "function" then
        return nil
    end
    opts = opts or {}
    local row = CreateFrame("Button", opts.name, parent)
    return UI.DecorateRow(row, opts)
end

-- ---------------------------------------------------------------------------
-- Fabriques : liste scrollable
-- ---------------------------------------------------------------------------

--- Liste scrollable moderne, calquee sur YayaCraftingOrdersLocal/BrowsePane.
--
-- Renvoie nil si le client n'expose pas les templates : l'appelant retombe
-- alors sur son rendu statique.
--
-- opts.rowHeight   : extent d'un element (defaut UI.SIZE.rowH)
-- opts.initializer : fonction(frame, elementData) liant toutes les donnees
-- opts.resetter    : fonction(frame) ; a defaut frame.Reset() est appele
function UI.CreateScrollList(parent, opts)
    if type(parent) ~= "table" or type(CreateFrame) ~= "function" then
        return nil
    end
    if type(CreateScrollBoxListLinearView) ~= "function"
        or type(CreateDataProvider) ~= "function"
        or type(ScrollUtil) ~= "table"
        or type(ScrollUtil.InitScrollBoxListWithScrollBar) ~= "function" then
        return nil
    end
    opts = opts or {}

    local list = {}
    list.container = CreateFrame("Frame", opts.name, parent)

    local okList, scrollFrame = pcall(CreateFrame, "Frame", nil, list.container, "WowScrollBoxList")
    local okBar, scrollBar = pcall(CreateFrame, "EventFrame", nil, list.container, "MinimalScrollBar")
    if not okList or not scrollFrame or not okBar or not scrollBar then
        return nil
    end

    list.frame = scrollFrame
    list.scrollBar = scrollBar

    -- La gouttiere de la barre reste hors de la largeur de contenu.
    scrollBar:SetPoint("TOPRIGHT", list.container, "TOPRIGHT", 0, 0)
    scrollBar:SetPoint("BOTTOMRIGHT", list.container, "BOTTOMRIGHT", 0, 0)
    scrollFrame:SetPoint("TOPLEFT", list.container, "TOPLEFT", 0, 0)
    scrollFrame:SetPoint("BOTTOMRIGHT", scrollBar, "BOTTOMLEFT", -UI.PAD.sm, 0)

    if type(scrollFrame.SetInterpolateScroll) == "function" then
        scrollFrame:SetInterpolateScroll(true)
    end
    if type(scrollBar.SetInterpolateScroll) == "function" then
        scrollBar:SetInterpolateScroll(true)
    end

    local view = CreateScrollBoxListLinearView()
    view:SetElementExtent(opts.rowHeight or UI.SIZE.rowH)
    if type(view.SetPadding) == "function" then
        view:SetPadding(0, 0, 0, 0, 0)
    end
    view:SetElementInitializer(opts.elementType or "Button", function(frame, elementData)
        if type(opts.initializer) == "function" then
            opts.initializer(frame, elementData)
        end
    end)
    if type(view.SetElementResetter) == "function" then
        view:SetElementResetter(function(frame)
            if type(opts.resetter) == "function" then
                opts.resetter(frame)
            elseif type(frame.Reset) == "function" then
                frame.Reset()
            end
        end)
    end

    ScrollUtil.InitScrollBoxListWithScrollBar(scrollFrame, scrollBar, view)
    list.view = view
    list.provider = CreateDataProvider()
    scrollFrame:SetDataProvider(list.provider)

    --- Remplace le contenu de la liste.
    function list.SetItems(items)
        items = items or {}
        local provider = list.provider
        if provider and type(provider.Flush) == "function" and type(provider.InsertTable) == "function" then
            provider:Flush()
            provider:InsertTable(items)
            return
        end
        list.provider = CreateDataProvider(items)
        scrollFrame:SetDataProvider(list.provider)
    end

    return list
end

-- ---------------------------------------------------------------------------
-- Mise en page : empilement vertical
-- ---------------------------------------------------------------------------

--- Empileur vertical ordonne.
--
-- Remplace les cascades de if/elseif ou chaque widget devait connaitre tous ses
-- predecesseurs possibles. Comme les frames de la suite sont ancrees en bas et
-- grandissent vers le haut, empiler depuis le sommet puis fixer la hauteur au
-- total garantit que le dernier widget se retrouve toujours au meme offset du
-- bord bas : c'est ce qui fait tenir le contrat autoclicker decrit sur
-- UI.ACTION.
function UI.StackLayout(parent, opts)
    opts = opts or {}
    local stack = {
        parent = parent,
        left = opts.left or 0,
        right = opts.right or 0,
        top = opts.top or 0,
    }
    stack.offset = stack.top
    stack.count = 0

    function stack.Reset()
        stack.offset = stack.top
        stack.count = 0
        return stack
    end

    --- Empile un widget sous le precedent.
    --
    -- gapBefore        : ecart avant le widget
    -- itemOpts.height  : hauteur imposee
    -- itemOpts.stretch : ancre aussi le bord droit (defaut true)
    function stack.Add(widget, gapBefore, itemOpts)
        if not widget then
            return stack
        end
        itemOpts = itemOpts or {}
        stack.offset = stack.offset + (tonumber(gapBefore) or 0)

        if type(widget.ClearAllPoints) == "function" then
            widget:ClearAllPoints()
            widget:SetPoint("TOPLEFT", stack.parent, "TOPLEFT", stack.left, -stack.offset)
            if itemOpts.stretch ~= false then
                widget:SetPoint("TOPRIGHT", stack.parent, "TOPRIGHT", -stack.right, -stack.offset)
            end
        end

        local height = tonumber(itemOpts.height)
        if not height and type(widget.GetStringHeight) == "function" then
            height = math.ceil((widget:GetStringHeight() or 0) + 0.5)
        end
        if not height and type(widget.GetHeight) == "function" then
            height = widget:GetHeight()
        end

        stack.offset = stack.offset + math.max(1, math.floor((tonumber(height) or 0) + 0.5))
        stack.count = stack.count + 1
        return stack
    end

    --- Insere un espace sans widget.
    function stack.AddSpace(height)
        stack.offset = stack.offset + (tonumber(height) or 0)
        return stack
    end

    --- Hauteur totale, marge basse comprise.
    function stack.Finish(bottomMargin)
        return math.max(1, stack.offset + (tonumber(bottomMargin) or 0))
    end

    return stack
end
