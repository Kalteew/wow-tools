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

    -- Verrou engage. Meme valeur que warning : un cadenas ferme est un etat
    -- signale, pas une erreur. Sans ce token, la branche lock de
    -- UI.CreateGlyphButton retombait sur textMuted et le cadenas ferme
    -- s'affichait exactement de la meme couleur que l'ouvert.
    locked    = { 1.00, 0.80, 0.40, 1.00 },
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

    -- Largeur utile d'une section de YayaFrame : les 200 px minimaux du
    -- conteneur moins ses deux gouttieres. Sert de repli pour mesurer un texte
    -- avant que les ancres du conteneur ne soient resolues.
    contentW    = 192,
    -- Bouton carre portant une icone et non un libelle : trop grand pour glyph,
    -- qui vise les commandes de bandeau, trop petit pour ACTION.height.
    iconButton  = 26,

    -- Panneaux d'options (YayaCore.Settings) : colonne des categories, ligne
    -- d'un slider avec son libelle au-dessus et ses bornes en dessous, largeur
    -- d'une saisie numerique.
    settingsRailW = 140,
    sliderRowH    = 44,
    inputW        = 80,
}

UI.FONT = {
    title  = "GameFontNormal",
    header = "GameFontNormalSmall",
    body   = "GameFontHighlightSmall",
    muted  = "GameFontDisableSmall",
    -- Titre d'un canevas Settings. Le client titre ses propres panneaux avec
    -- cette police : s'en ecarter rendrait le panneau Yaya etranger a la
    -- fenetre qui l'accueille.
    heading = "GameFontNormalLarge",
}

-- Texte sur plusieurs lignes. Les lignes de metier de YayaWeeklyTracker font
-- couramment 100 a 140 caracteres pour 176 px utiles : sans plafond elles
-- mangeraient toute la frame, sans repli tout ce qui depasse la premiere ligne
-- est perdu sans recours.
UI.TEXT = {
    maxLines = 3,          -- plafond de lignes par defaut
    spacing  = 0,          -- interligne additionnel ; 0 = celui de la police
    lineH    = 12,         -- repli quand la police ne repond pas
    charW    = 4.6,        -- repli de mesure hors du jeu, pour des tests stables
    more     = "+%d",      -- marqueur de debordement ; le reste va en infobulle
    nbsp     = "\194\160", -- U+00A0 : espace qui ne casse pas la ligne
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

--- Retire le balisage d'affichage pour obtenir le texte reellement rendu.
--
-- Sert a mesurer et a composer une infobulle : les sequences de couleur, les
-- textures et les hyperliens occupent des octets mais aucun pixel.
function UI.StripMarkup(text)
    text = tostring(text or "")
    text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    text = text:gsub("|T.-|t", ""):gsub("|A.-|a", "")
    text = text:gsub("|H.-|h(.-)|h", "%1")
    text = text:gsub(UI.TEXT.nbsp, " ")
    return text
end

--- Largeur rendue d'un texte, balisage exclu.
--
-- Un FontString cache et mutualise sert de reglet. GetStringWidth est la seule
-- mesure synchrone : elle ne depend que de la police et de la chaine. A
-- l'inverse GetStringHeight sur une largeur derivee d'ancres, GetNumLines et
-- IsTruncated ont tous besoin d'une passe de rendu deja faite.
function UI.MeasureWidth(text, fontName)
    text = tostring(text or "")
    if type(UIParent) ~= "table" or type(UIParent.CreateFontString) ~= "function" then
        -- Hors du jeu : estimation stable, pour que les tests soient reproductibles.
        return #UI.StripMarkup(text) * UI.TEXT.charW
    end
    UI.measureStrings = UI.measureStrings or {}
    fontName = fontName or UI.FONT.body
    local ruler = UI.measureStrings[fontName]
    if not ruler then
        ruler = UIParent:CreateFontString(nil, "BACKGROUND", fontName)
        ruler:SetWordWrap(false)
        ruler:Hide()
        UI.measureStrings[fontName] = ruler
    end
    ruler:SetText(text)
    return tonumber(ruler:GetStringWidth()) or 0
end

--- Hauteur d'une ligne de texte, interligne additionnel exclu.
function UI.LineHeight(fontString)
    if type(fontString) == "table" then
        if type(fontString.GetLineHeight) == "function" then
            local ok, value = pcall(fontString.GetLineHeight, fontString)
            value = ok and tonumber(value) or nil
            if value and value > 0 then
                return value
            end
        end
        if type(fontString.GetFont) == "function" then
            local ok, _, size = pcall(fontString.GetFont, fontString)
            size = ok and tonumber(size) or nil
            if size and size > 0 then
                return math.ceil(size * 1.25)
            end
        end
    end
    return UI.TEXT.lineH
end

--- Largeur exploitable d'une region, avec repli.
--
-- Une region qui tire sa largeur de deux ancres rend 0 ou sa taille de creation
-- tant que la passe de mise en page du conteneur n'a pas eu lieu.
function UI.ResolveWidth(region, fallback)
    local width = 0
    if type(region) == "table" and type(region.GetWidth) == "function" then
        local ok, value = pcall(region.GetWidth, region)
        width = (ok and tonumber(value)) or 0
    end
    if width < 8 then
        return tonumber(fallback) or 0
    end
    return width
end

--- Repartit des jetons sur au plus maxLines lignes, sans jamais couper un jeton.
--
-- Le moteur de rendu coupe aux espaces : "catchup restant : 3" se casserait
-- entre "restant" et ":". Les coupures sont donc calculees ici et posees en \n.
-- Le client n'a plus aucune decision a prendre, et surtout le nombre de lignes
-- est connu AVANT que le texte soit pose : c'est ce qui rend la hauteur exacte
-- des le premier passage, sans attendre une passe de rendu.
--
-- tokens         : liste de chaines, balisage de couleur compris
-- opts.width     : largeur utile en pixels (<= 0 desactive la coupure)
-- opts.maxLines  : plafond (defaut UI.TEXT.maxLines)
-- opts.prefix    : texte colle en tete de la premiere ligne
-- opts.separator : separateur entre jetons (defaut " ")
-- opts.font      : police de mesure (defaut UI.FONT.body)
-- opts.measure   : mesure injectable, pour les tests hors du jeu
--
-- Renvoie le texte, le nombre de lignes, et le nombre de jetons non affiches.
function UI.PackLines(tokens, opts)
    opts = opts or {}
    tokens = tokens or {}
    local width = tonumber(opts.width) or 0
    local maxLines = math.max(1, math.floor(tonumber(opts.maxLines) or UI.TEXT.maxLines))
    local separator = opts.separator or " "
    local measure = opts.measure
    if type(measure) ~= "function" then
        measure = function(value) return UI.MeasureWidth(value, opts.font) end
    end

    local function Pack(reserve)
        local lines, current, used = {}, opts.prefix or "", 0
        for index = 1, #tokens do
            local last = (#lines + 1) >= maxLines
            local room = width - ((last and reserve) or 0)
            local candidate = current ~= ""
                and (current .. separator .. tokens[index])
                or tokens[index]
            -- current == "" : un jeton plus large que la ligne est place seul
            -- plutot que perdu, quitte a se faire elider par le client.
            if width <= 0 or current == "" or measure(candidate) <= room then
                current, used = candidate, index
            elseif not last then
                lines[#lines + 1] = current
                current, used = tokens[index], index
            else
                break
            end
        end
        lines[#lines + 1] = current
        return lines, #tokens - used
    end

    -- Deux passes : la premiere dit s'il y a debordement, la seconde reserve la
    -- place du marqueur. Reserver a l'aveugle couterait une place meme quand
    -- tout tient.
    local lines, hidden = Pack(0)
    if hidden > 0 then
        lines, hidden = Pack(measure(separator .. UI.TEXT.more:format(#tokens)))
        if hidden > 0 then
            lines[#lines] = lines[#lines] .. separator .. UI.TEXT.more:format(hidden)
        end
    end
    return table.concat(lines, "\n"), #lines, hidden
end

--- Passe un FontString en texte multi-lignes plafonne.
--
-- La largeur DOIT etre explicite : un FontString qui tire la sienne de deux
-- ancres n'a pas de largeur resolue au moment ou on lui pose son texte, donc ni
-- sa coupure ni sa hauteur ne seraient justes.
function UI.WrapLabel(fontString, opts)
    if type(fontString) ~= "table" then
        return fontString
    end
    opts = opts or {}
    if type(fontString.SetWidth) == "function" then
        fontString:SetWidth(math.max(1, tonumber(opts.width) or 1))
    end
    if type(fontString.SetWordWrap) == "function" then
        fontString:SetWordWrap(true)
    end
    if type(fontString.SetMaxLines) == "function" then
        fontString:SetMaxLines(math.max(1, math.floor(tonumber(opts.maxLines) or UI.TEXT.maxLines)))
    end
    if type(fontString.SetSpacing) == "function" then
        fontString:SetSpacing(tonumber(opts.spacing) or UI.TEXT.spacing)
    end
    if type(fontString.SetJustifyH) == "function" then
        fontString:SetJustifyH(opts.justify or "LEFT")
    end
    return fontString
end

--- Pose un texte deja decoupe et rend la hauteur a reserver, en entier.
--
-- lines vient de UI.PackLines : c'est la seule valeur certaine a cet instant.
-- GetStringHeight ne sert que de second avis, et on garde le maximum des deux.
-- L'asymetrie le justifie : une hauteur surestimee coute quelques pixels, une
-- hauteur sous-estimee fait chevaucher les lignes.
function UI.FitLabel(fontString, text, lines, maxLines, spacing)
    if type(fontString) ~= "table" then
        return 0, 0
    end
    maxLines = math.max(1, math.floor(tonumber(maxLines) or UI.TEXT.maxLines))
    spacing = tonumber(spacing) or UI.TEXT.spacing
    if type(fontString.SetText) == "function" then
        fontString:SetText(text or "")
    end

    local lineHeight = UI.LineHeight(fontString)
    local step = lineHeight + spacing
    local count = math.max(1, math.floor(tonumber(lines) or 1))

    if type(fontString.GetStringHeight) == "function" then
        local ok, measured = pcall(fontString.GetStringHeight, fontString)
        measured = ok and tonumber(measured) or nil
        if measured and measured > 0 and step > 0 then
            count = math.max(count, math.floor((measured + spacing) / step + 0.5))
        end
    end

    count = math.max(1, math.min(maxLines, count))
    return math.ceil(count * step - spacing), count
end

--- Le libelle est-il visiblement coupe ?
--
-- IsTruncated est pose par le moteur au moment du dessin : la valeur n'a de sens
-- qu'apres une passe de rendu, donc a l'entree de la souris, jamais au moment ou
-- le texte est ecrit.
function UI.IsLabelTruncated(fontString)
    if type(fontString) ~= "table" or type(fontString.IsTruncated) ~= "function" then
        return false
    end
    local ok, truncated = pcall(fontString.IsTruncated, fontString)
    return ok and truncated == true
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

--- Cree un separateur de 1 px.
--
-- opts.vertical : pose une largeur au lieu d'une hauteur. L'appelant fournit
-- l'autre dimension par ses ancres, comme pour le filet horizontal.
function UI.CreateDivider(parent, opts)
    if type(parent) ~= "table" or type(parent.CreateTexture) ~= "function" then
        return nil
    end
    opts = opts or {}
    local line = parent:CreateTexture(nil, "ARTWORK")
    if opts.vertical then
        line:SetWidth(UI.SIZE.divider)
    else
        line:SetHeight(UI.SIZE.divider)
    end
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

--- Borne le libelle interne d'un bouton et conserve son texte complet.
--
-- Le ButtonText d'un UIPanelButtonTemplate est ancre au centre, sans largeur,
-- sans SetWordWrap ni SetMaxLines : un libelle trop long deborde de part et
-- d'autre du bouton, et rien ne le rattrape si le parent ne clippe pas.
--
-- button.fullLabel garde le texte d'origine ; l'infobulle ne s'ouvre que si le
-- libelle est reellement coupe a l'ecran.
function UI.BindButtonLabel(button, text, opts)
    if type(button) ~= "table" or type(button.GetFontString) ~= "function" then
        return button
    end
    opts = opts or {}
    local ok, label = pcall(button.GetFontString, button)
    if not ok or type(label) ~= "table" then
        return button
    end

    if text ~= nil then
        button.fullLabel = tostring(text)
    end

    if not button.yayaBoundLabel then
        button.yayaBoundLabel = true
        label:ClearAllPoints()
        label:SetPoint("LEFT", button, "LEFT", opts.leftInset or UI.PAD.sm, 0)
        label:SetPoint("RIGHT", button, "RIGHT", -(opts.rightInset or UI.PAD.sm), 0)
        UI.BoundLabel(label, opts.justify or "CENTER")

        --- Change le libelle en gardant sa version complete pour l'infobulle.
        function button.SetLabel(value)
            button.fullLabel = tostring(value or "")
            if type(button.SetText) == "function" then
                button:SetText(button.fullLabel)
            end
        end

        if YayaCore.Tooltip and type(YayaCore.Tooltip.Attach) == "function" then
            YayaCore.Tooltip.Attach(button, function(tooltip, self)
                local fontString = self:GetFontString()
                if not UI.IsLabelTruncated(fontString) then
                    return false
                end
                tooltip:SetText(self.fullLabel or "")
                return true
            end, { anchor = opts.anchor or "ANCHOR_RIGHT" })
        end
    end

    return button
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
    -- Police reduite des barres d'outils, ou le bouton cotoie ceux du client.
    if opts.small then
        if type(button.SetNormalFontObject) == "function" then
            pcall(button.SetNormalFontObject, button, _G.GameFontNormalSmall)
        end
        if type(button.SetHighlightFontObject) == "function" then
            pcall(button.SetHighlightFontObject, button, _G.GameFontHighlightSmall)
        end
    end
    -- Un bouton desactive n'emet plus OnEnter : sans cela, l'infobulle qui
    -- explique justement pourquoi il est desactive devient inatteignable.
    if opts.motionWhileDisabled and type(button.SetMotionScriptsWhileDisabled) == "function" then
        pcall(button.SetMotionScriptsWhileDisabled, button, true)
    end
    if text and type(button.SetText) == "function" then
        button:SetText(text)
    end
    UI.BindButtonLabel(button, text)

    --- Cable une infobulle sans reimplementer OnEnter/OnLeave.
    function button.SetTooltip(title, body, anchor)
        AttachTooltip(button, title, body, anchor or "ANCHOR_TOP")
    end

    --- Infobulle dont le contenu est relu a chaque survol.
    --
    -- provider(tooltip, button) remplit l'infobulle ; renvoyer false l'annule.
    -- Indispensable aux boutons dont le texte depend de l'etat courant : une
    -- chaine figee a la creation y serait perimee des le premier changement.
    function button.SetTooltipProvider(provider, anchor)
        if not (YayaCore.Tooltip and type(YayaCore.Tooltip.Attach) == "function") then
            return
        end
        YayaCore.Tooltip.Attach(button, provider, { anchor = anchor or "ANCHOR_TOP" })
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

--- Case a cocher, avec son libelle, sa zone de clic et son infobulle.
--
-- Le depot repetait vingt-trois fois la meme danse : creer la case, retrouver
-- son FontString sous deux noms possibles, en fabriquer un si le template n'en
-- livre pas, puis etendre la zone cliquable au libelle a la main.
--
-- opts.radio      : UIRadioButtonTemplate au lieu de UICheckButtonTemplate
-- opts.size       : cote de la case (defaut UI.SIZE.headerH)
-- opts.font       : police du libelle (defaut UI.FONT.body)
-- opts.labelWidth : largeur imposee du libelle
-- opts.hitLabel   : etend la zone cliquable au libelle (defaut true)
-- opts.icon       : texture ou fileID affiche a la place du libelle
-- opts.iconSize   : cote de cette icone (defaut UI.SIZE.icon)
-- opts.checked    : etat initial
-- opts.tooltip    : { title, body, anchor }
-- opts.onClick    : fonction(checked, button)
--
-- button.label porte le FontString, deja borne ; button.icon la texture.
function UI.CreateCheckbox(parent, text, opts)
    if type(parent) ~= "table" or type(CreateFrame) ~= "function" then
        return nil
    end
    opts = opts or {}
    local template = opts.radio and "UIRadioButtonTemplate" or "UICheckButtonTemplate"
    local button = CreateFrame("CheckButton", opts.name, parent, template)
    local size = opts.size or UI.SIZE.headerH
    button:SetSize(size, size)

    if opts.icon then
        button.icon = button:CreateTexture(nil, "ARTWORK")
        local iconSize = opts.iconSize or UI.SIZE.icon
        button.icon:SetSize(iconSize, iconSize)
        button.icon:SetPoint("LEFT", button, "RIGHT", UI.PAD.sm, 0)
        button.icon:SetTexture(opts.icon)
    else
        -- Certains templates livrent deja leur FontString, sous deux noms
        -- possibles selon la version du client. En creer un second
        -- afficherait le libelle en double.
        local label = button.Text or button.text
        if not label then
            label = button:CreateFontString(nil, "OVERLAY", opts.font or UI.FONT.body)
            label:SetPoint("LEFT", button, "RIGHT", UI.PAD.sm, 0)
        elseif opts.font then
            UI.SetFont(label, opts.font)
        end
        button.label = label
        if label then
            label:SetText(text or "")
            if opts.labelWidth then
                label:SetWidth(opts.labelWidth)
            end
            UI.BoundLabel(label, "LEFT")
        end
    end

    -- Le libelle fait partie de la cible : viser une case de 22 px est inutilement
    -- precis quand le texte a cote dit la meme chose. GetStringWidth n'a de sens
    -- qu'apres SetText.
    if opts.hitLabel ~= false and button.label
        and type(button.SetHitRectInsets) == "function" then
        local width = tonumber(opts.labelWidth)
        if not width and type(button.label.GetStringWidth) == "function" then
            local ok, measured = pcall(button.label.GetStringWidth, button.label)
            width = ok and tonumber(measured) or nil
        end
        if width and width > 0 then
            pcall(button.SetHitRectInsets, button, 0, -(width + UI.PAD.sm), 0, 0)
        end
    end

    if type(button.SetChecked) == "function" then
        button:SetChecked(opts.checked and true or false)
    end

    if type(opts.onClick) == "function" then
        button:SetScript("OnClick", function(self)
            local checked = type(self.GetChecked) == "function" and self:GetChecked() or false
            opts.onClick(checked and true or false, self)
        end)
    end

    --- Cable une infobulle sans reimplementer OnEnter/OnLeave.
    function button.SetTooltip(title, body, anchor)
        AttachTooltip(button, title, body, anchor or "ANCHOR_RIGHT")
    end

    --- Infobulle dont le contenu est relu a chaque survol.
    function button.SetTooltipProvider(provider, anchor)
        if not (YayaCore.Tooltip and type(YayaCore.Tooltip.Attach) == "function") then
            return
        end
        YayaCore.Tooltip.Attach(button, provider, { anchor = anchor or "ANCHOR_RIGHT" })
    end

    if opts.tooltip then
        button.SetTooltip(opts.tooltip.title, opts.tooltip.body, opts.tooltip.anchor)
    end

    return button
end

-- ---------------------------------------------------------------------------
-- Fabriques : controles de reglage
-- ---------------------------------------------------------------------------

-- Nombre de decimales impliquees par un pas : 0.5 -> 1, 0.25 -> 2, 5 -> 0.
local function StepDecimals(step)
    local text = tostring(tonumber(step) or 1)
    local fraction = text:match("%.(%d+)$")
    return fraction and #fraction or 0
end

-- Formateur de valeur : chaine string.format, fonction, ou repli derive du pas.
local function ResolveFormatter(format, step)
    if type(format) == "function" then
        return function(value)
            return tostring(format(value))
        end
    end
    if type(format) == "string" then
        return function(value)
            local ok, text = pcall(string.format, format, value)
            return ok and text or tostring(value)
        end
    end
    local pattern = "%." .. StepDecimals(step) .. "f"
    return function(value)
        return string.format(pattern, value)
    end
end

-- Alpha d'un controle grise. Meme valeur que l'ancien SetSliderEnabled de
-- YayaCraftingOrdersLocal, pour que les panneaux de la suite grisent pareil.
local DISABLED_ALPHA = 0.45

-- Un setter expose en style point (widget.SetEnabled(true)) doit aussi
-- supporter l'appel en style methode (widget:SetEnabled(true)), sinon un
-- appelant qui confond les deux passe la frame en guise de booleen.
local function ResolveEnabledArg(widget, first, second)
    if first == widget then
        return second and true or false
    end
    return first and true or false
end

--- Grise ou reactive un controle, conteneur compris.
--
-- Les conteneurs de ce module (saisie numerique, dropdown, groupes de
-- YayaCore.Settings) exposent un SetEnabled en style point, pose comme champ
-- direct : c'est lui qui sait quels enfants desactiver. Un widget nu passe par
-- Enable/Disable et EnableMouse. Dans les deux cas l'alpha porte l'etat visuel.
--
-- Le libelle n'est attenue separement que s'il n'est pas un enfant du widget :
-- l'alpha d'une region se multiplie par celui de son parent, et un libelle
-- enfant passerait sinon a 0.2.
function UI.SetWidgetEnabled(widget, enabled)
    if type(widget) ~= "table" then
        return widget
    end
    enabled = enabled and true or false

    local custom = rawget(widget, "SetEnabled")
    if type(custom) == "function" then
        custom(enabled)
    else
        if enabled then
            if type(widget.Enable) == "function" then
                widget:Enable()
            end
        elseif type(widget.Disable) == "function" then
            widget:Disable()
        end
        if type(widget.EnableMouse) == "function" then
            widget:EnableMouse(enabled)
        end
    end

    local alpha = enabled and 1 or DISABLED_ALPHA
    if type(widget.SetAlpha) == "function" then
        widget:SetAlpha(alpha)
    end

    local label = widget.label
    if type(label) == "table" and type(label.SetAlpha) == "function" then
        local parent = type(label.GetParent) == "function" and label:GetParent() or nil
        if parent ~= widget then
            label:SetAlpha(alpha)
        end
    end
    return widget
end

--- Curseur de reglage borne, arrondi au pas.
--
-- OptionsSliderTemplate livre trois FontString : le libelle au-dessus, les
-- bornes en dessous. Les clients recents les exposent par parentKey
-- (slider.Text, slider.Low, slider.High) ; les anciens ne les nommaient que par
-- _G[nom .. "Text"], d'ou le repli quand un nom est fourni. S'il n'y a ni l'un
-- ni l'autre, les FontString sont crees ici.
--
-- opts.min, opts.max, opts.step : bornes et pas (defaut 0, 100, 1)
-- opts.value    : valeur initiale (defaut min)
-- opts.width    : largeur (defaut 200)
-- opts.format   : "%d", "%.1fx", ou fonction(value) -> texte ; defaut derive du pas
-- opts.onChange : fonction(value, slider), appelee seulement si la valeur
--                 arrondie change et hors de SetValueSilently
-- opts.tooltip  : { title, body, anchor }
--
-- slider.label porte le FontString de titre. slider.SetValueSilently(v) pousse
-- une valeur sans rappeler onChange, slider.GetValueRounded() rend la valeur
-- arrondie courante, slider.SetEnabled(bool) grise le curseur.
function UI.CreateSlider(parent, text, opts)
    if type(parent) ~= "table" or type(CreateFrame) ~= "function" then
        return nil
    end
    opts = opts or {}
    local name = opts.name

    local ok, slider = pcall(CreateFrame, "Slider", name, parent, "OptionsSliderTemplate")
    if not ok or type(slider) ~= "table" then
        return nil
    end

    local minValue = tonumber(opts.min) or 0
    local maxValue = tonumber(opts.max) or 100
    if maxValue < minValue then
        maxValue = minValue
    end
    local step = tonumber(opts.step) or 1
    if step <= 0 then
        step = 1
    end
    local decimals = StepDecimals(step)
    local Format = ResolveFormatter(opts.format, step)

    slider:SetWidth(opts.width or 200)
    slider:SetMinMaxValues(minValue, maxValue)
    slider:SetValueStep(step)
    if type(slider.SetObeyStepOnDrag) == "function" then
        slider:SetObeyStepOnDrag(true)
    end

    -- L'arrondi au pas passe par une chaine pour effacer la poussiere binaire :
    -- 1 + 5 * 0.1 ne vaut pas exactement 1.5 en flottant.
    local function Round(value)
        value = tonumber(value) or minValue
        local rounded = minValue + math.floor((value - minValue) / step + 0.5) * step
        rounded = tonumber(string.format("%." .. decimals .. "f", rounded)) or rounded
        if rounded < minValue then
            rounded = minValue
        elseif rounded > maxValue then
            rounded = maxValue
        end
        return rounded
    end

    local function Resolve(field, fallbackFont, point, relativePoint, x, y)
        local region = slider[field]
        if not region and name then
            region = _G[name .. field]
        end
        if not region and type(slider.CreateFontString) == "function" then
            region = slider:CreateFontString(nil, "OVERLAY", fallbackFont)
            region:SetPoint(point, slider, relativePoint, x, y)
        end
        return region
    end

    local label = Resolve("Text", UI.FONT.body, "BOTTOM", "TOP", 0, UI.PAD.xs)
    local low = Resolve("Low", UI.FONT.muted, "TOPLEFT", "BOTTOMLEFT", 0, -UI.PAD.xs)
    local high = Resolve("High", UI.FONT.muted, "TOPRIGHT", "BOTTOMRIGHT", 0, -UI.PAD.xs)
    slider.label = label
    slider.low = low
    slider.high = high

    if low and type(low.SetText) == "function" then
        low:SetText(Format(minValue))
    end
    if high and type(high.SetText) == "function" then
        high:SetText(Format(maxValue))
    end

    slider.value = Round(opts.value)

    local function UpdateText()
        if label and type(label.SetText) == "function" then
            label:SetText((text or "") .. " : " .. Format(slider.value))
        end
    end

    slider:SetScript("OnValueChanged", function(self, raw)
        local rounded = Round(raw)
        if self.suppress then
            self.value = rounded
            UpdateText()
            return
        end
        if rounded == self.value then
            return
        end
        self.value = rounded
        UpdateText()
        if type(opts.onChange) == "function" then
            opts.onChange(rounded, self)
        end
    end)

    --- Pousse une valeur sans rappeler onChange : pour resynchroniser depuis la db.
    function slider.SetValueSilently(value)
        slider.suppress = true
        slider.value = Round(value)
        slider:SetValue(slider.value)
        UpdateText()
        slider.suppress = nil
    end

    --- Valeur courante, arrondie au pas.
    function slider.GetValueRounded()
        return slider.value
    end

    local nativeSetEnabled = slider.SetEnabled

    --- Grise ou reactive le curseur.
    function slider.SetEnabled(first, second)
        local enabled = ResolveEnabledArg(slider, first, second)
        if type(nativeSetEnabled) == "function" then
            pcall(nativeSetEnabled, slider, enabled)
        elseif enabled and type(slider.Enable) == "function" then
            slider:Enable()
        elseif not enabled and type(slider.Disable) == "function" then
            slider:Disable()
        end
        if type(slider.EnableMouse) == "function" then
            slider:EnableMouse(enabled)
        end
        slider:SetAlpha(enabled and 1 or DISABLED_ALPHA)
    end

    --- Cable une infobulle sans reimplementer OnEnter/OnLeave.
    function slider.SetTooltip(title, body, anchor)
        AttachTooltip(slider, title, body, anchor or "ANCHOR_RIGHT")
    end

    if opts.tooltip then
        slider.SetTooltip(opts.tooltip.title, opts.tooltip.body, opts.tooltip.anchor)
    end

    slider.SetValueSilently(slider.value)
    return slider
end

--- Saisie numerique : libelle, EditBox alignee a droite, suffixe optionnel.
--
-- La valeur n'est prise qu'a la validation (Entree ou perte de focus) : une
-- saisie invalide ou vide restaure la derniere valeur validee, Echap l'annule.
-- onCommit n'est rappele que si la valeur validee change, ce qui absorbe le
-- OnEditFocusLost que ClearFocus declenche juste apres OnEnterPressed.
--
-- opts.min, opts.max : bornes de clamp (optionnelles)
-- opts.decimals   : decimales acceptees ; nil ou 0 = entiers, SetNumeric(true)
-- opts.value      : valeur initiale (defaut min, sinon 0)
-- opts.width      : largeur de l'EditBox (defaut UI.SIZE.inputW)
-- opts.labelWidth : largeur imposee du libelle
-- opts.suffix     : unite affichee apres la saisie ("po", "%")
-- opts.onCommit   : fonction(value, editBox)
-- opts.tooltip    : { title, body, anchor }
--
-- container.editBox, container.label, container.suffix portent les regions ;
-- container.SetValueSilently(v), container.GetValue(), container.SetEnabled(bool).
function UI.CreateNumberInput(parent, text, opts)
    if type(parent) ~= "table" or type(CreateFrame) ~= "function" then
        return nil
    end
    opts = opts or {}

    local container = CreateFrame("Frame", opts.name, parent)
    container:SetHeight(UI.SIZE.headerH)

    local ok, box = pcall(CreateFrame, "EditBox", opts.name and (opts.name .. "EditBox") or nil,
        container, "InputBoxTemplate")
    if not ok or type(box) ~= "table" then
        container:Hide()
        return nil
    end

    local label = container:CreateFontString(nil, "OVERLAY", UI.FONT.body)
    label:SetPoint("LEFT", container, "LEFT", 0, 0)
    if opts.labelWidth then
        label:SetWidth(opts.labelWidth)
    end
    label:SetText(text or "")
    UI.BoundLabel(label, "LEFT")
    container.label = label

    local decimals = math.max(0, math.floor(tonumber(opts.decimals) or 0))
    local minValue, maxValue = tonumber(opts.min), tonumber(opts.max)

    -- InputBoxTemplate deborde de 8 px a gauche de sa zone de saisie.
    box:SetSize(opts.width or UI.SIZE.inputW, UI.SIZE.headerH)
    box:SetPoint("LEFT", label, "RIGHT", UI.PAD.lg + 8, 0)
    box:SetAutoFocus(false)
    if decimals == 0 and type(box.SetNumeric) == "function" then
        box:SetNumeric(true)
    end
    box:SetJustifyH("RIGHT")
    if opts.maxLetters and type(box.SetMaxLetters) == "function" then
        box:SetMaxLetters(opts.maxLetters)
    end
    container.editBox = box

    if opts.suffix then
        local suffix = container:CreateFontString(nil, "OVERLAY", UI.FONT.muted)
        suffix:SetPoint("LEFT", box, "RIGHT", UI.PAD.sm, 0)
        suffix:SetText(opts.suffix)
        UI.BoundLabel(suffix, "LEFT")
        container.suffix = suffix
    end

    local pattern = "%." .. decimals .. "f"

    local function Normalize(raw)
        local value = tonumber(raw)
        if value == nil then
            return nil
        end
        if minValue and value < minValue then
            value = minValue
        end
        if maxValue and value > maxValue then
            value = maxValue
        end
        return tonumber(string.format(pattern, value)) or value
    end

    local function Display(value)
        return string.format(pattern, value)
    end

    container.value = Normalize(opts.value) or minValue or 0
    box:SetText(Display(container.value))

    local function Commit(self)
        if container.suppress then
            return
        end
        local value = Normalize(self:GetText())
        if value == nil then
            self:SetText(Display(container.value))
            return
        end
        local changed = value ~= container.value
        container.value = value
        self:SetText(Display(value))
        if changed and type(opts.onCommit) == "function" then
            opts.onCommit(value, self)
        end
    end

    box:SetScript("OnEnterPressed", function(self)
        Commit(self)
        self:ClearFocus()
    end)
    box:SetScript("OnEditFocusLost", function(self)
        Commit(self)
    end)
    box:SetScript("OnEscapePressed", function(self)
        self:SetText(Display(container.value))
        self:ClearFocus()
    end)

    --- Pousse une valeur sans rappeler onCommit : pour resynchroniser depuis la db.
    function container.SetValueSilently(value)
        container.suppress = true
        local normalized = Normalize(value)
        if normalized ~= nil then
            container.value = normalized
        end
        box:SetText(Display(container.value))
        container.suppress = nil
    end

    --- Derniere valeur validee.
    function container.GetValue()
        return container.value
    end

    --- Grise ou reactive la saisie.
    function container.SetEnabled(first, second)
        local enabled = ResolveEnabledArg(container, first, second)
        if type(box.SetEnabled) == "function" then
            pcall(box.SetEnabled, box, enabled)
        elseif enabled and type(box.Enable) == "function" then
            box:Enable()
        elseif not enabled and type(box.Disable) == "function" then
            box:Disable()
        end
        if type(box.EnableMouse) == "function" then
            box:EnableMouse(enabled)
        end
        if not enabled and type(box.ClearFocus) == "function" then
            box:ClearFocus()
        end
        container:SetAlpha(enabled and 1 or DISABLED_ALPHA)
    end

    --- Cable une infobulle sur la zone de saisie.
    function container.SetTooltip(title, body, anchor)
        AttachTooltip(box, title, body, anchor or "ANCHOR_RIGHT")
    end

    if opts.tooltip then
        container.SetTooltip(opts.tooltip.title, opts.tooltip.body, opts.tooltip.anchor)
    end

    return container
end

--- Liste deroulante a choix unique : libelle a gauche, bouton a droite.
--
-- Primaire : DropdownButton + WowStyle1DropdownTemplate et l'API Menu (11.0+),
-- dont le texte se met a jour depuis les radios selectionnes a chaque
-- GenerateMenu. Repli : UIDropDownMenuTemplate quand le client n'expose pas
-- SetupMenu ; le texte y est pousse a la main par UIDropDownMenu_SetText.
--
-- opts.choices  : { { value =, label =, tooltip = }, ... }, dans l'ordre d'affichage
-- opts.get      : fonction() -> valeur courante
-- opts.onSelect : fonction(value)
-- opts.width    : largeur du bouton (defaut 160)
-- opts.labelWidth : largeur imposee du libelle
-- opts.tooltip  : { title, body, anchor }
--
-- container.dropdown, container.label, container.isLegacy (true en repli) ;
-- container.Refresh() relit opts.get(), container.SetEnabled(bool).
function UI.CreateDropdown(parent, text, opts)
    if type(parent) ~= "table" or type(CreateFrame) ~= "function" then
        return nil
    end
    opts = opts or {}
    local choices = type(opts.choices) == "table" and opts.choices or {}
    local width = opts.width or 160

    local function Get()
        if type(opts.get) == "function" then
            return opts.get()
        end
        return nil
    end

    local function Select(value)
        if type(opts.onSelect) == "function" then
            opts.onSelect(value)
        end
    end

    local function LabelOf(value)
        for _, choice in ipairs(choices) do
            if choice.value == value then
                return tostring(choice.label or choice.value)
            end
        end
        return ""
    end

    local container = CreateFrame("Frame", opts.name, parent)
    container:SetHeight(UI.SIZE.iconButton)

    local label = container:CreateFontString(nil, "OVERLAY", UI.FONT.body)
    label:SetPoint("LEFT", container, "LEFT", 0, 0)
    if opts.labelWidth then
        label:SetWidth(opts.labelWidth)
    end
    label:SetText(text or "")
    UI.BoundLabel(label, "LEFT")
    container.label = label

    local dropdown
    local okModern, modern = pcall(CreateFrame, "DropdownButton", nil, container, "WowStyle1DropdownTemplate")
    if okModern and type(modern) == "table" and type(modern.SetupMenu) == "function" then
        dropdown = modern
        container.isLegacy = false
        dropdown:SetPoint("LEFT", label, "RIGHT", UI.PAD.lg, 0)
        dropdown:SetWidth(width)
        if type(dropdown.SetDefaultText) == "function" then
            pcall(dropdown.SetDefaultText, dropdown, LabelOf(Get()))
        end
        dropdown:SetupMenu(function(_, root)
            for _, choice in ipairs(choices) do
                local value = choice.value
                local radio = root:CreateRadio(tostring(choice.label or value),
                    function() return Get() == value end,
                    function() Select(value) end)
                if choice.tooltip and type(radio) == "table" and type(radio.SetTooltip) == "function" then
                    pcall(radio.SetTooltip, radio, function(tooltip)
                        tooltip:SetText(tostring(choice.label or value))
                        tooltip:AddLine(choice.tooltip, 1, 1, 1, true)
                    end)
                end
            end
        end)

        --- Relit opts.get() et remet le texte du bouton a jour.
        function container.Refresh()
            if type(dropdown.SetDefaultText) == "function" then
                pcall(dropdown.SetDefaultText, dropdown, LabelOf(Get()))
            end
            if type(dropdown.GenerateMenu) == "function" then
                pcall(dropdown.GenerateMenu, dropdown)
            end
        end
    else
        if okModern and type(modern) == "table" and type(modern.Hide) == "function" then
            modern:Hide()
        end
        local okLegacy, legacy = pcall(CreateFrame, "Frame", opts.name and (opts.name .. "Menu") or nil,
            container, "UIDropDownMenuTemplate")
        if not okLegacy or type(legacy) ~= "table" then
            container:Hide()
            return nil
        end
        dropdown = legacy
        container.isLegacy = true
        -- Le template deborde de 16 px a gauche de son bouton.
        dropdown:SetPoint("LEFT", label, "RIGHT", UI.PAD.lg - 16, 0)
        if type(UIDropDownMenu_SetWidth) == "function" then
            UIDropDownMenu_SetWidth(dropdown, width)
        end
        if type(UIDropDownMenu_Initialize) == "function" then
            UIDropDownMenu_Initialize(dropdown, function(_, level)
                for _, choice in ipairs(choices) do
                    local value = choice.value
                    local info = type(UIDropDownMenu_CreateInfo) == "function" and UIDropDownMenu_CreateInfo() or {}
                    info.text = tostring(choice.label or value)
                    info.value = value
                    info.checked = Get() == value
                    info.func = function()
                        Select(value)
                        if type(UIDropDownMenu_SetText) == "function" then
                            UIDropDownMenu_SetText(dropdown, LabelOf(Get()))
                        end
                    end
                    if choice.tooltip then
                        info.tooltipTitle = info.text
                        info.tooltipText = choice.tooltip
                        info.tooltipOnButton = true
                    end
                    if type(UIDropDownMenu_AddButton) == "function" then
                        UIDropDownMenu_AddButton(info, level)
                    end
                end
            end)
        end

        --- Relit opts.get() et remet le texte du bouton a jour.
        function container.Refresh()
            if type(UIDropDownMenu_SetText) == "function" then
                UIDropDownMenu_SetText(dropdown, LabelOf(Get()))
            end
        end
    end
    container.dropdown = dropdown

    --- Grise ou reactive la liste.
    function container.SetEnabled(first, second)
        local enabled = ResolveEnabledArg(container, first, second)
        if container.isLegacy then
            if enabled and type(UIDropDownMenu_EnableDropDown) == "function" then
                UIDropDownMenu_EnableDropDown(dropdown)
            elseif not enabled and type(UIDropDownMenu_DisableDropDown) == "function" then
                UIDropDownMenu_DisableDropDown(dropdown)
            end
        elseif type(dropdown.SetEnabled) == "function" then
            pcall(dropdown.SetEnabled, dropdown, enabled)
        elseif enabled and type(dropdown.Enable) == "function" then
            dropdown:Enable()
        elseif not enabled and type(dropdown.Disable) == "function" then
            dropdown:Disable()
        end
        if type(dropdown.EnableMouse) == "function" then
            dropdown:EnableMouse(enabled)
        end
        container:SetAlpha(enabled and 1 or DISABLED_ALPHA)
    end

    --- Cable une infobulle sur le bouton.
    function container.SetTooltip(title, body, anchor)
        AttachTooltip(dropdown, title, body, anchor or "ANCHOR_RIGHT")
    end

    if opts.tooltip then
        container.SetTooltip(opts.tooltip.title, opts.tooltip.body, opts.tooltip.anchor)
    end

    container.Refresh()
    return container
end

--- Croix de fermeture du rail d'en-tete.
--
-- UIPanelCloseButton ferme son parent. Cree sous le bandeau, il masquerait donc
-- le bandeau et non la fenetre : la cible est explicite.
--
-- Appelee EN PREMIER, elle reste le bouton le plus a droite du rail, puisque
-- header.AddButton empile de droite a gauche.
--
-- opts.size    : cote (defaut UI.SIZE.glyph)
-- opts.onClick : rappel execute avant le masquage
-- opts.attach  : false pour placer le bouton soi-meme
function UI.CreateCloseButton(header, frameToClose, opts)
    if type(header) ~= "table" or type(CreateFrame) ~= "function" then
        return nil
    end
    opts = opts or {}
    local button = CreateFrame("Button", opts.name, header, "UIPanelCloseButton")
    local size = opts.size or UI.SIZE.glyph
    button:SetSize(size, size)

    button:SetScript("OnClick", function(self)
        if type(opts.onClick) == "function" then
            opts.onClick(self)
        end
        local target = frameToClose or header:GetParent()
        if target and type(target.Hide) == "function" then
            target:Hide()
        end
    end)

    if opts.attach ~= false and type(header.AddButton) == "function" then
        header.AddButton(button)
    end

    return button
end

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

    local rightInset = opts.rightInset or UI.PAD.md
    row.value = row:CreateFontString(nil, "OVERLAY", opts.valueFont or UI.FONT.body)
    row.value:SetPoint("RIGHT", row, "RIGHT", -rightInset, 0)
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

    --- Rend l'etat de selection d'une ligne.
    --
    -- Une case a cocher de dix-huit pixels ne se lit pas dans une liste de
    -- trente lignes : la selection doit teindre la ligne entiere. Le fond est
    -- exclusif de la zebrure, donc les deux passent par le meme point d'entree
    -- -- sans quoi un appelant qui rend la selection apres la zebrure, ou
    -- l'inverse selon la branche, finit par en oublier une.
    function row.SetSelected(selected, index)
        if selected then
            row.bg:SetColorTexture(UI.Unpack(UI.COLOR.selected))
        else
            row.SetStripe(index)
        end
    end

    --- Teinte la valeur avec un token de couleur.
    function row.SetTone(tone)
        local color = UI.COLOR[tone or "text"] or UI.COLOR.text
        row.value:SetTextColor(UI.Unpack(color))
    end

    --- Teinte le libelle avec un token de couleur.
    function row.SetLabelTone(tone)
        local color = UI.COLOR[tone or "text"] or UI.COLOR.text
        row.label:SetTextColor(UI.Unpack(color))
    end

    --- Largeur utile du libelle pour une largeur de ligne donnee.
    function row.LabelWidth(rowWidth)
        return math.max(1, math.floor(
            (tonumber(rowWidth) or 0) - leftInset - rightInset - UI.PAD.sm))
    end

    --- Bascule le libelle entre une ligne et plusieurs lignes bornees.
    --
    -- En multi-lignes l'ancre droite cede la place a une largeur explicite :
    -- c'est la seule facon d'obtenir une coupure et une hauteur justes des le
    -- SetText, sans attendre la passe de mise en page du conteneur.
    function row.SetLabelWrap(maxLines, width)
        maxLines = math.max(1, math.floor(tonumber(maxLines) or 1))
        row.label:ClearAllPoints()
        row.label:SetPoint("LEFT", row, "LEFT", leftInset, 0)
        if maxLines <= 1 then
            row.labelWrapped = nil
            row.label:SetWidth(0)
            if type(row.label.SetSpacing) == "function" then
                row.label:SetSpacing(0)
            end
            row.label:SetPoint("RIGHT", row.value, "LEFT", -UI.PAD.sm, 0)
            return UI.BoundLabel(row.label, "LEFT")
        end
        row.labelWrapped = true
        return UI.WrapLabel(row.label, {
            width = width or row.LabelWidth(row:GetWidth()),
            maxLines = maxLines,
        })
    end

    --- Infobulle libre, pour une ligne qui ne porte pas d'objet.
    function row.SetTooltip(title, body)
        row.tooltipTitle = title
        row.tooltipBody = body
    end

    --- Infobulle qui ne s'ouvre que si le libelle est coupe a l'ecran.
    --
    -- IsTruncated n'est renseigne qu'apres le dessin : la condition est donc
    -- evaluee a l'entree de la souris, jamais ici.
    function row.SetTruncatedTooltip(title, body)
        row.tooltipTitle = title
        row.tooltipBody = body
        row.tooltipWhenTruncated = true
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
        row.tooltipWhenTruncated = nil
        row.hiddenTokenCount = nil
        row.SetLabelWrap(1)
        row.label:SetText("")
        row.label:SetTextColor(UI.Unpack(UI.COLOR.text))
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
        if self.tooltipTitle
            and (not self.tooltipWhenTruncated or UI.IsLabelTruncated(self.label)) then
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
    --- Remplace le contenu de la liste, en gardant la position de defilement.
    --
    -- Flush vide le fournisseur avant de le remplir : le ScrollBox voit passer
    -- une liste vide et ramene son defilement tout en haut. Un simple repeint
    -- apres un clic renvoyait donc l'utilisateur au debut de la liste, alors
    -- qu'il regardait la trentieme ligne.
    --
    -- resetScroll : true pour revenir volontairement en haut, quand le contenu
    -- affiche n'a plus rien a voir avec le precedent.
    function list.SetItems(items, resetScroll)
        items = items or {}

        local percentage
        if not resetScroll and type(scrollFrame.GetScrollPercentage) == "function" then
            local ok, value = pcall(scrollFrame.GetScrollPercentage, scrollFrame)
            percentage = ok and tonumber(value) or nil
        end

        local provider = list.provider
        if provider and type(provider.Flush) == "function" and type(provider.InsertTable) == "function" then
            provider:Flush()
            provider:InsertTable(items)
        else
            list.provider = CreateDataProvider(items)
            scrollFrame:SetDataProvider(list.provider)
        end

        -- Une liste plus courte qu'avant fait clamper le client : inutile de
        -- borner nous-memes.
        if percentage and percentage > 0 and type(scrollFrame.SetScrollPercentage) == "function" then
            pcall(scrollFrame.SetScrollPercentage, scrollFrame, percentage)
        end
    end

    --- Redessine les lignes affichees sans toucher au jeu de donnees.
    --
    -- SetItems vide puis reinsere le fournisseur : c'est un brassage complet des
    -- donnees pour un simple repeint. Mais FullUpdate ne suffit pas a l'eviter :
    -- le ScrollBox ne rejoue l'initialiseur que sur les lignes qu'il acquiert,
    -- et une ligne deja a l'ecran n'est pas reacquise. Un etat qui vit hors de
    -- l'element -- une selection, par exemple -- restait donc peint comme avant
    -- le clic jusqu'a ce que la ligne sorte du champ et y revienne.
    --
    -- Le repeint rejoue donc l'initialiseur, ligne visible par ligne visible.
    -- L'initialiseur doit pouvoir etre rejoue sur une ligne deja liee : ceux de
    -- la suite commencent par row.Reset(), qui remet le rendu a plat.
    --
    -- Retourne false quand rien n'a pu etre repeint -- client sans ForEachFrame,
    -- ou aucune ligne acquise -- pour que l'appelant retombe sur SetItems.
    function list.Refresh()
        if type(opts.initializer) ~= "function"
            or type(scrollFrame.ForEachFrame) ~= "function" then
            return false
        end

        local repainted = false
        local ok = pcall(scrollFrame.ForEachFrame, scrollFrame, function(frame, elementData)
            if elementData == nil and type(frame.GetElementData) == "function" then
                elementData = frame:GetElementData()
            end
            if elementData == nil then
                return
            end

            -- Reset ferme l'infobulle de la ligne : sans cela, un clic sous le
            -- curseur la ferait disparaitre jusqu'au prochain passage de souris,
            -- qui n'aura pas lieu puisque la souris n'a pas bouge.
            local hadTooltip = GameTooltip and type(GameTooltip.IsOwned) == "function"
                and GameTooltip:IsOwned(frame)

            repainted = true
            opts.initializer(frame, elementData)

            if hadTooltip and type(frame.GetScript) == "function" then
                local onEnter = frame:GetScript("OnEnter")
                if onEnter then
                    onEnter(frame)
                end
            end
        end)

        return ok and repainted
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
