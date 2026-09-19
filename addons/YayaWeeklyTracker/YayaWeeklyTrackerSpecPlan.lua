-- ---------------------------------------------------------------------------
-- YayaWeeklyTrackerSpecPlan : depenser les points de connaissance selon un plan
--
-- Fichier separe du tracker pour deux raisons. La premiere est mecanique :
-- YayaWeeklyTracker.lua est a 197 locals de chunk sur les 200 que Lua 5.1
-- autorise, et un local de plus empeche l'addon entier de se compiler, sans
-- message clair en jeu. La seconde est que la decision « quel noeud acheter »
-- n'a rien a voir avec l'affichage : elle se teste seule.
--
-- Le moteur d'achat n'est PAS ici. Il vit dans YayaQueue (YQQuality, traces
-- profession-spec-mass) : c'est lui qui sait remonter un chemin, deduire le
-- nombre de points a mettre dans un parent pour debloquer un enfant, et attendre
-- la confirmation du serveur entre deux lots. Ce module se contente de lui dire
-- quel noeud viser, dans quel ordre, et de mener la fenetre Blizzard jusqu'a
-- l'etat ou l'achat est possible.
--
-- Un clic = une etape. Les points depenses ne se reprennent pas : rien ne
-- s'enchaine tout seul, l'infobulle annonce toujours ce que le prochain clic
-- fera, et c'est le clic suivant (ou l'autoclicker) qui avance.
-- ---------------------------------------------------------------------------

local addonName = ...

-- ---------------------------------------------------------------------------
-- Le plan, par metier
--
-- Une entree par skillLineID Midnight, comme MIDNIGHT_PROFESSION_CONFIGS du
-- fichier principal : le plan vaut pour TOUS les personnages qui ont ce metier.
--
--   steps = liste ORDONNEE de { path = <pathID>, rank = <rang vise>, name = "..." }
--
-- `path` est l'autorite : c'est le pathID (traitNodeID) du noeud, stable entre
-- personnages et entre locales. `name` n'est qu'un rappel lisible, jamais utilise
-- pour resoudre quoi que ce soit. `rank` est le rang de depense, rang de
-- deblocage EXCLU, donc le meme nombre que celui affiche par le jeu sur le noeud.
--
-- Les etapes sont traitees dans l'ordre : la premiere dont le rang courant est
-- sous la cible devient l'objectif, et le moteur remonte de lui-meme la chaine
-- des prerequis. Un rang superieur au maximum du noeud est ramene au maximum.
--
-- Un metier absent de cette table n'affiche simplement aucun bouton.
-- Pour relever les pathID d'un arbre : /ywt spec dump
-- ---------------------------------------------------------------------------

local SPEC_PLANS = {
    -- Midnight Alchemy. Les pages « Potion Prowess » et « Path of Void » se
    -- remplissent en dernier : l'ordre ouvre d'abord les rendements, puis
    -- apprend les noeuds intermediaires sans y depenser, et ne remonte les
    -- troncs qu'ensuite. Le plan ne remplit pas l'arbre entier, c'est voulu.
    [2906] = {
        steps = {
            { path = 107101, rank = 20, name = "Prolific Potioneer - Void" },
            { path = 107102, rank = 20, name = "Cunning Potioneer" },
            { path = 107282, rank = 20, name = "Reuse" },
            { path = 107281, rank = 20, name = "Recycle" },
            { path = 107255, rank = 0, name = "Synthesis Synergy" },
            { path = 107213, rank = 0, name = "Sin'dorei Specialist" },
            { path = 107210, rank = 0, name = "Haranir Secrets" },
            { path = 107106, rank = 0, name = "Path of Light" },
            { path = 107283, rank = 20, name = "Reduce" },
            { path = 107284, rank = 30, name = "Alchemical Mastery" },
            { path = 107103, rank = 30, name = "Path of Void" },
            { path = 107107, rank = 30, name = "Potion Prowess" },
            -- Les noeuds feuilles plafonnent a 20, pas a 30 : demander plus est
            -- sans effet, la cible est ramenee au maximum du noeud.
            { path = 107255, rank = 20, name = "Synthesis Synergy" },
            { path = 107254, rank = 20, name = "Metamorphic Mastery" },
        },
    },

    -- Midnight Inscription. Deux pages seulement, prises feuilles d'abord puis
    -- troncs : « Calm Hands » sature ses deux feuilles avant de finir sa racine,
    -- « Perfected Products » remonte Perfect Milling -> Processing -> racine. Les
    -- pages « Blueprints » et « Darkmoon Curiosity » sont volontairement ignorees.
    [2913] = {
        steps = {
            { path = 106278, rank = 20, name = "Keen Eye" },
            { path = 106279, rank = 20, name = "Added Flair" },
            { path = 106280, rank = 10, name = "Calm Hands" },
            { path = 109653, rank = 30, name = "Perfect Milling" },
            { path = 109655, rank = 30, name = "Processing" },
            { path = 109660, rank = 30, name = "Perfected Products" },
        },
    },

    -- Midnight Blacksmithing. L'ordre est celui dicte par le joueur : la racine
    -- « The Old Ways » d'abord, puis ses quatre feuilles, puis les deux noeuds
    -- utiles de la page Craftsmithing, et enfin le deblocage a zero point des dix
    -- feuilles d'armure et des quatre feuilles d'arme -- chacune apporte ses
    -- recettes de base sans rien couter de plus.
    --
    -- Les noeuds intermediaires ne sont volontairement pas listes : Armorsmithing,
    -- Large Plate Armor, Sculpted Armor, Articulating Armor, Weaponsmithing, Blades
    -- et Hafted Weapons sont remontes par le moteur, qui n'y met que le strict
    -- necessaire au deblocage de l'enfant vise. Tool Stones et Weaponstones restent
    -- hors plan.
    [2907] = {
        steps = {
            { path = 104292, rank = 40, name = "The Old Ways" },
            { path = 104289, rank = 20, name = "Prolific Worker" },
            { path = 104290, rank = 20, name = "Resourceful Smith" },
            { path = 104291, rank = 20, name = "Second Nature" },
            { path = 104288, rank = 20, name = "Alloys" },
            { path = 104257, rank = 20, name = "Trade Tools" },
            { path = 104256, rank = 15, name = "Trade Accessories" },
            { path = 104574, rank = 0, name = "Chestplates" },
            { path = 104573, rank = 0, name = "Greaves" },
            { path = 104572, rank = 0, name = "Shields" },
            { path = 104570, rank = 0, name = "Helms" },
            { path = 104569, rank = 0, name = "Pauldrons" },
            { path = 104568, rank = 0, name = "Sabatons" },
            { path = 104566, rank = 0, name = "Belts" },
            { path = 104565, rank = 0, name = "Vambraces" },
            { path = 104564, rank = 0, name = "Gauntlets" },
            { path = 104631, rank = 0, name = "Short Blades" },
            { path = 104630, rank = 0, name = "Long Blades" },
            { path = 104628, rank = 0, name = "Maces" },
            { path = 104627, rank = 0, name = "Axes and Polearms" },
        },
    },

    -- Midnight Enchanting. La page « Spellbound Shatterer » est saturee en premier,
    -- puis la branche Haranir de « Elevating Equipment » remonte des feuilles vers
    -- sa racine, puis « Reputable Rods » est seulement apprise, et « Crystal
    -- Collector » finit le dezenchantement. Les racines intermediaires (Haranir
    -- Heightening exclu, qui est une etape a part entiere) sont remontees par le
    -- moteur : Transitories -> Outstanding Outfits pour Reputable Rods, et
    -- Disenchanting Delegate pour Crystal Collector.
    [2909] = {
        steps = {
            { path = 107616, rank = 30, name = "Responsible Resources" },
            { path = 107617, rank = 30, name = "Spellbound Shatterer" },
            { path = 107615, rank = 30, name = "Infinite Ingenuity" },
            { path = 107757, rank = 20, name = "Nature's Novelties" },
            { path = 107760, rank = 20, name = "Haranir Heightening" },
            { path = 107769, rank = 30, name = "Elevating Equipment" },
            { path = 107686, rank = 0, name = "Reputable Rods" },
            { path = 107646, rank = 30, name = "Crystal Collector" },
        },
    },
}

-- Pas utilise pour une etape de simple apprentissage, et pour le deblocage
-- d'une page. Sa valeur importe peu -- le moteur ne fait que debloquer dans ces
-- deux cas -- mais elle doit rester strictement positive : a zero il bascule en
-- remplissage complet et monterait le noeud a son maximum.
local UNLOCK_STEP_SIZE = 1

-- Fenetre de confirmation que Blizzard ouvre pour l'achat d'une page.
local SPEC_TAB_POPUP = "PROFESSIONS_SPECIALIZATION_CONFIRM_PURCHASE_TAB"

-- Le moteur travaille en asynchrone et n'emet rien en fin de lot quand les rangs
-- ne sont que mis en attente : sans reveil, le bouton restait masque jusqu'a un
-- rafraichissement venu d'ailleurs, qui pouvait ne jamais arriver.
local BUSY_REFRESH_INTERVAL = 0.25
local BUSY_REFRESH_MAX_ATTEMPTS = 24



local api = _G.YayaWeeklyTrackerSpecPlan or {}
_G.YayaWeeklyTrackerSpecPlan = api

local treeIDCache = {}

-- Boutons de Blizzard qui referment l'apercu d'une page, par ordre de preference.
local PREVIEW_BUTTON_KEYS = { "BackToFullTreeButton", "ViewTreeButton" }

-- Tentatives de selection d'un onglet dont l'arbre charge ne suit pas encore.
local SELECT_TREE_MAX_ATTEMPTS = 3
local selectAttempts = {}
local pendingAction
-- Nombre d'ouvertures deja tentees pour un metier, remis a zero des qu'il est
-- effectivement affiche : c'est ce compteur qui fait basculer du skillLineID
-- d'extension vers le metier de base quand le premier reste sans effet.
local openAttempts = {}

local function SafeCall(func, ...)
    if type(func) ~= "function" then
        return nil
    end
    local ok, result = pcall(func, ...)
    if not ok then
        return nil
    end
    return result
end

local function DebugLog(...)
    if type(api.DebugLog) == "function" then
        pcall(api.DebugLog, ...)
    end
end

local function Say(level, message)
    if type(api.Say) == "function" then
        pcall(api.Say, level, message)
    elseif DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage(addonName .. ": " .. tostring(message))
    end
end

--- Surface spec de YayaQueue, ou nil si l'addon est absent ou trop ancien.
local function GetQueueAPI()
    local queue = _G.YayaQueueAPI
    if type(queue) ~= "table"
        or type(queue.StepProfessionSpecTarget) ~= "function"
        or type(queue.GetProfessionSpecPathRanks) ~= "function" then
        return nil
    end
    return queue
end

local function GetConfigID(skillLineID)
    local queue = GetQueueAPI()
    if queue and type(queue.GetProfessionSpecConfigID) == "function" then
        return queue.GetProfessionSpecConfigID(skillLineID)
    end
    if type(C_ProfSpecs) ~= "table"
        or type(C_ProfSpecs.GetConfigIDForSkillLine) ~= "function" then
        return nil
    end
    local configID = SafeCall(C_ProfSpecs.GetConfigIDForSkillLine, skillLineID)
    if not configID or configID == 0 then
        return nil
    end
    return configID
end

-- ---------------------------------------------------------------------------
-- Lecture de l'arbre
-- ---------------------------------------------------------------------------

local function CollectPathsForTab(pathID, seen)
    if not pathID or seen[pathID] then
        return
    end
    seen[pathID] = true
    local children = SafeCall(C_ProfSpecs and C_ProfSpecs.GetChildrenForPath, pathID) or {}
    for _, childPathID in ipairs(children) do
        CollectPathsForTab(childPathID, seen)
    end
end

local function GetRootPathForTab(treeID)
    if not treeID
        or type(C_ProfSpecs) ~= "table"
        or type(C_ProfSpecs.GetRootPathForTab) ~= "function" then
        return nil
    end
    return SafeCall(C_ProfSpecs.GetRootPathForTab, treeID)
end

--- Table pathID -> tabID (= traitTreeID) pour un metier, construite une fois.
local function GetTreeIDsByPath(skillLineID)
    local cached = treeIDCache[skillLineID]
    if cached then
        return cached
    end
    if type(C_ProfSpecs) ~= "table"
        or type(C_ProfSpecs.GetSpecTabIDsForSkillLine) ~= "function" then
        return nil
    end

    local tabIDs = SafeCall(C_ProfSpecs.GetSpecTabIDsForSkillLine, skillLineID) or {}
    if #tabIDs == 0 then
        -- Les donnees de metier ne sont pas encore chargees : ne rien memoriser,
        -- sinon le cache fige un arbre vide pour toute la session.
        return nil
    end

    local byPath = {}
    for _, tabID in ipairs(tabIDs) do
        local rootPathID = SafeCall(C_ProfSpecs.GetRootPathForTab, tabID)
        local seen = {}
        CollectPathsForTab(rootPathID, seen)
        for pathID in pairs(seen) do
            byPath[pathID] = tabID
        end
    end

    treeIDCache[skillLineID] = byPath
    return byPath
end

local function GetAvailableKnowledge(skillLineID)
    local info = SafeCall(
        C_ProfSpecs and C_ProfSpecs.GetCurrencyInfoForSkillLine,
        skillLineID
    )
    if type(info) ~= "table" then
        return nil
    end
    return tonumber(info.numAvailable) or 0
end

local function GetPathRanks(configID, pathID)
    local queue = GetQueueAPI()
    if not queue then
        return nil, nil
    end
    return queue.GetProfessionSpecPathRanks(configID, pathID)
end

--- Un noeud est-il appris ? Distinct du rang : un noeud tout juste debloque a
-- zero point depense, et c'est exactement ce que demande une etape a `rank = 0`.
local function IsPathUnlocked(configID, pathID)
    local queue = GetQueueAPI()
    if not queue then
        return nil
    end
    local pathState = queue.GetProfessionSpecPathState(configID, pathID)
    if pathState == nil then
        return nil
    end
    local locked = Enum and Enum.ProfessionsSpecPathState
        and Enum.ProfessionsSpecPathState.Locked
    if locked == nil then
        return true
    end
    return pathState ~= locked
end

--- Etat d'une page de specialisation : Locked (0), Unlocked (1), Unlockable (2).
-- Une page s'ouvre tous les 25 niveaux de metier, donc `Locked` n'est pas une
-- erreur mais une attente, et `Unlockable` demande l'achat de sa racine, que
-- Blizzard fait passer par sa propre fenetre de confirmation.
local function GetTabState(treeID, configID)
    if not treeID
        or type(C_ProfSpecs) ~= "table"
        or type(C_ProfSpecs.GetStateForTab) ~= "function" then
        return nil
    end
    return SafeCall(C_ProfSpecs.GetStateForTab, treeID, configID)
end

local function IsTabLocked(treeID, configID)
    local locked = Enum and Enum.ProfessionsSpecTabState
        and Enum.ProfessionsSpecTabState.Locked
    if locked == nil then
        return false
    end
    return GetTabState(treeID, configID) == locked
end

local function IsTabUnlocked(treeID, configID)
    local unlocked = Enum and Enum.ProfessionsSpecTabState
        and Enum.ProfessionsSpecTabState.Unlocked
    local tabState = GetTabState(treeID, configID)
    if tabState == nil or unlocked == nil then
        -- Sans information, laisser le moteur trancher : lui verra le refus.
        return true
    end
    return tabState == unlocked
end

--- Nom lisible d'un noeud, par le meme chemin que YayaProfessionSpecializations.
-- GetSourceTextForPath ne rend pas un nom mais la condition de deblocage : s'en
-- servir affichait « Requires 20 points » a la place de la specialisation.
local function GetPathName(configID, pathID)
    if type(C_Traits) ~= "table" or type(C_Traits.GetNodeInfo) ~= "function" then
        return nil
    end

    local nodeInfo = SafeCall(C_Traits.GetNodeInfo, configID, pathID)
    if type(nodeInfo) ~= "table" then
        return nil
    end

    local entryID = nodeInfo.activeEntry and nodeInfo.activeEntry.entryID
        or (nodeInfo.entryIDsWithCommittedRanks and nodeInfo.entryIDsWithCommittedRanks[1])
        or (nodeInfo.entryIDs and nodeInfo.entryIDs[1])
    if not entryID then
        return nil
    end

    local entryInfo = SafeCall(C_Traits.GetEntryInfo, configID, entryID)
    local definitionInfo = entryInfo and entryInfo.definitionID
        and SafeCall(C_Traits.GetDefinitionInfo, entryInfo.definitionID)
        or nil
    if type(definitionInfo) == "table" then
        if definitionInfo.overrideName and definitionInfo.overrideName ~= "" then
            return definitionInfo.overrideName
        end
        if definitionInfo.spellID and C_Spell and C_Spell.GetSpellName then
            local name = SafeCall(C_Spell.GetSpellName, definitionInfo.spellID)
            if name and name ~= "" then
                return name
            end
        end
    end
    return entryInfo and entryInfo.name or nil
end

local function HasStagedChanges(configID)
    if not configID
        or type(C_Traits) ~= "table"
        or type(C_Traits.ConfigHasStagedChanges) ~= "function" then
        return false
    end
    return SafeCall(C_Traits.ConfigHasStagedChanges, configID) == true
end

--- Frame de specialisation Blizzard. Passe par YayaQueue quand il est la, sinon
-- la retrouve seule : ce module doit pouvoir se diagnostiquer meme degrade.
local function GetSpecFrame(requireVisible)
    local queue = GetQueueAPI()
    if queue and type(queue.GetProfessionSpecFrame) == "function" then
        return queue.GetProfessionSpecFrame(requireVisible)
    end
    local frame = (ProfessionsFrame and ProfessionsFrame.SpecPage) or _G.ProfessionsSpecFrame
    if type(frame) ~= "table" or type(frame.GetConfigID) ~= "function" then
        return nil
    end
    if requireVisible and type(frame.IsVisible) == "function" and not frame:IsVisible() then
        return nil
    end
    return frame
end

local function ReadProfessionID(info)
    local skillLineID = type(info) == "table" and tonumber(info.professionID) or nil
    if skillLineID and skillLineID > 0 then
        return skillLineID
    end
    return nil
end

--- skillLineID de la ligne de metier actuellement affichee, ou nil.
--
-- Trois oracles, dans cet ordre. La page de specialisation porte elle-meme le
-- `professionInfo` sur lequel elle a construit son arbre : c'est la reponse qui
-- compte, puisque c'est cet arbre que l'on va acheter. `GetChildProfessionInfo`
-- vient ensuite -- il decrit la ligne d'extension ouverte, mais rend une table
-- vide tant que les donnees ne sont pas chargees, et son `professionID` valait
-- alors nil, ce qui laissait le bouton proposer indefiniment « ouvrir ».
local function GetOpenProfessionSkillLineID()
    if not (ProfessionsFrame
        and type(ProfessionsFrame.IsVisible) == "function"
        and ProfessionsFrame:IsVisible()) then
        return nil
    end

    -- Enchainement, jamais une table de candidats : un oracle muet y laisse un
    -- trou, et `ipairs` s'arrete au premier nil -- les suivants n'etaient alors
    -- jamais consultes.
    local specFrame = GetSpecFrame(false)
    return ReadProfessionID(specFrame and specFrame.professionInfo)
        or ReadProfessionID(SafeCall(C_TradeSkillUI and C_TradeSkillUI.GetChildProfessionInfo))
        or ReadProfessionID(ProfessionsFrame.professionInfo)
end

local function IsSpecPageVisible()
    return GetSpecFrame(true) ~= nil
end

local function GetSelectedTreeID()
    local frame = GetSpecFrame(true)
    if not frame or type(frame.GetTalentTreeID) ~= "function" then
        return nil
    end
    return SafeCall(frame.GetTalentTreeID, frame)
end

--- Racine de l'arbre REELLEMENT charge par la page.
--
-- Deux oracles pour une seule question, et ils divergent. `GetTalentTreeID` dit
-- l'onglet choisi ; `GetRootNodeID` dit l'arbre affiche, et c'est de LUI que
-- part le DFS du moteur d'achat (`FindProfessionSpecPath`). Apres le deblocage
-- d'une page, l'onglet peut deja porter le nouveau treeID alors que l'arbre
-- charge est encore l'ancien : le module se croyait arrive, et chaque achat
-- repartait sur `invalid-context`, la cible n'etant atteignable depuis aucune
-- racine visitee.
local function GetDisplayedRootPathID()
    local frame = GetSpecFrame(true)
    if not frame or type(frame.GetRootNodeID) ~= "function" then
        return nil
    end
    return tonumber(SafeCall(frame.GetRootNodeID, frame))
end

--- L'arbre charge est-il celui de la page visee ?
-- Rend `true` des qu'on ne peut pas savoir : ne jamais bloquer sur une inconnue.
local function IsDisplayedTreeReady(treeID)
    local displayedRoot = GetDisplayedRootPathID()
    local expectedRoot = treeID and GetRootPathForTab(treeID) or nil
    if not displayedRoot or not expectedRoot then
        return true
    end
    return displayedRoot == expectedRoot
end

--- Bouton « Appliquer » natif, pret a etre clique, ou nil et la raison.
--
-- Son etat n'est rafraichi par Blizzard qu'a la fin d'une operation : le relire
-- sans demander sa mise a jour le montrait encore desactive alors que des rangs
-- venaient d'etre poses. `UpdateConfigButtonsState` est la meme methode que le
-- moteur de YayaQueue appelle deja en fin de lot.
local function GetApplyButton()
    local frame = GetSpecFrame(true)
    if not frame then
        return nil, "spec-page-hidden"
    end
    if type(frame.UpdateConfigButtonsState) == "function" then
        pcall(frame.UpdateConfigButtonsState, frame)
    end

    local applyButton = frame.ApplyButton
    if type(applyButton) ~= "table" or type(applyButton.Click) ~= "function" then
        return nil, "no-apply-button"
    end
    if type(applyButton.IsShown) == "function" and not applyButton:IsShown() then
        return nil, "apply-hidden"
    end
    if type(applyButton.IsEnabled) == "function" and not applyButton:IsEnabled() then
        return nil, "apply-disabled"
    end
    return applyButton
end

--- L'apercu d'une page de specialisation recouvre-t-il l'arbre ?
--
-- `SetSelectedTab` affiche cet apercu -- la page de presentation, titre,
-- description et icone -- des que la page visee est verrouillee, et SEUL le
-- `onAccept` de la fenetre de confirmation de Blizzard le referme. L'achat
-- direct de la racine, lui, deverrouille la page en laissant l'apercu par
-- dessus : Blizzard garde alors son propre « Appliquer » cache, puisqu'il le
-- montre a la condition `not isLocked and not TreePreview:IsShown()`. Le plan
-- s'arretait la, sur une page de presentation sans bouton a cliquer.
local function IsTreePreviewShown()
    local frame = GetSpecFrame(true)
    local preview = frame and frame.TreePreview
    if type(preview) ~= "table" or type(preview.IsShown) ~= "function" then
        return false
    end
    return SafeCall(preview.IsShown, preview) == true
end

--- Bouton qui referme cet apercu, ou nil et la raison.
--
-- Les deux font le meme geste -- `TreePreview:Hide()` -- et Blizzard n'en montre
-- qu'un : « Voir l'arbre complet » quand la page est deja deverrouillee, « Voir
-- l'arbre » quand elle ne l'est pas encore. Prendre celui qui est la evite de
-- dependre de l'ordre dans lequel le deblocage et l'affichage se sont produits.
local function GetTreePreviewButton()
    local frame = GetSpecFrame(true)
    if not frame then
        return nil, "spec-page-hidden"
    end
    if not IsTreePreviewShown() then
        return nil, "preview-hidden"
    end
    -- Meme raison que pour « Appliquer » : Blizzard ne revoit la visibilite de
    -- ses boutons qu'au passage suivant de son `OnUpdate`, donc pas encore au
    -- clic qui vient de debloquer la page.
    if type(frame.UpdateSelectedTabState) == "function" then
        pcall(frame.UpdateSelectedTabState, frame)
    end

    for index = 1, #PREVIEW_BUTTON_KEYS do
        local candidate = frame[PREVIEW_BUTTON_KEYS[index]]
        if type(candidate) == "table"
            and type(candidate.Click) == "function"
            and (type(candidate.IsShown) ~= "function" or candidate:IsShown())
            and (type(candidate.IsEnabled) ~= "function" or candidate:IsEnabled()) then
            return candidate
        end
    end
    return nil, "preview-button-hidden"
end

--- Index et nom de la fenetre de confirmation de specialisation affichee.
--
-- On rend l'INDEX, pas la frame : la validation passe par la macro securisee
-- `/click StaticPopup<N>Button1`, qui ne depend que du nom global du bouton.
-- C'est le geste que le joueur fait deja a la main, et un bouton securise le
-- reproduit tel quel -- le clic materiel reste le sien.
--
-- Le filtre reste large a dessein. La detection precedente exigeait un `which`
-- contenant `PROFESSIONS_SPECIALIZATION` et ne trouvait jamais rien : l'etape
-- n'etait alors pas meme produite, si bien que personne n'essayait de valider
-- quoi que ce soit. Le `which` reel est visible dans `/ywt spec diag`, qui liste
-- desormais toutes les fenetres ouvertes.
local function FindSpecConfirmPopup()
    for index = 1, 4 do
        local dialog = _G["StaticPopup" .. index]
        if type(dialog) == "table"
            and type(dialog.IsShown) == "function"
            and dialog:IsShown() then
            local which = tostring(dialog.which or "")
            if which:find("PROFESSION", 1, true) or which:find("SPECIALIZATION", 1, true) then
                return index, which
            end
        end
    end
    return nil
end

-- ---------------------------------------------------------------------------
-- Remplissage libre, une fois le plan termine
--
-- Le plan ne remplit jamais l'arbre entier : il s'arrete sur ce qui a ete
-- arbitre. Passe cette ligne, les points restants n'ont plus de destination
-- choisie, et le bouton disparaissait en les laissant dormir. Le repli prend
-- alors la suite, en deux temps : finir les specialisations DEJA entamees --
-- laisser un noeud a moitie rempli ne sert a rien -- puis en completer une tiree
-- au sort, et recommencer.
--
-- Un noeud simplement debloque a zero point n'est PAS « entame » : les etapes a
-- `rank = 0` du plan Forgeron en ouvrent quatorze d'un coup, et les traiter comme
-- entames aurait supprime le tirage de fait.
-- ---------------------------------------------------------------------------

-- Noeud tire au sort par metier, garde jusqu'a ce qu'il soit plein.
local randomChoice = {}

local function DefaultRandomSource(count)
    return math.random(count)
end

local randomSource = DefaultRandomSource

--- Remplace la source du tirage. Reservee aux tests, qui exigent un choix connu.
-- Vide la memoire au passage : sans cela, un choix deja tire serait garde et la
-- source injectee ne serait jamais consultee -- un test vert qui ne teste rien.
function api.SetRandomSource(source)
    randomSource = type(source) == "function" and source or DefaultRandomSource
    randomChoice = {}
end

--- L'option de remplissage libre est-elle active ?
--
-- Absente, elle est consideree ETEINTE -- l'inverse de `IsEnabled`, et c'est
-- voulu : le pont du tracker la pose toujours en jeu, donc le seul cas d'absence
-- est le module charge seul. Inventer un remplissage y depenserait des points sur
-- une decision que personne n'a prise.
local function RandomFillAllowed()
    if type(api.IsRandomFillEnabled) ~= "function" then
        return false
    end
    return api.IsRandomFillEnabled() == true
end

--- Noeuds encore remplissables d'un metier : entames d'abord, vierges ensuite.
--
-- Rend `nil` quand l'arbre n'est pas lisible : ne pas savoir n'est pas la meme
-- chose qu'un arbre plein, et les deux ne doivent pas se confondre plus haut.
--
-- Une page seulement ACHETABLE est mise de cote au lieu d'etre fouillee. Deux
-- raisons : ses noeuds interieurs ne sont pas des cibles valides -- le moteur
-- n'ouvre la fenetre de confirmation de Blizzard que sur la racine -- et ouvrir
-- une page coute un point alors qu'il reste des noeuds a finir sur les pages
-- deja payees. Sa racine ne sert donc que de dernier recours.
local function CollectFillCandidates(skillLineID, configID)
    local byPath = GetTreeIDsByPath(skillLineID)
    if not byPath then
        return nil
    end

    local started, untouched = {}, {}
    local buyableRoot
    local readable = 0

    for pathID, treeID in pairs(byPath) do
        -- Une page verrouillee par le niveau de metier s'ouvrira d'elle-meme :
        -- ses noeuds ne sont pas candidats, pas plus que pour le plan.
        if not IsTabLocked(treeID, configID) then
            if not IsTabUnlocked(treeID, configID) then
                if GetRootPathForTab(treeID) == pathID
                    and (not buyableRoot or pathID < buyableRoot.pathID) then
                    buyableRoot = {
                        pathID = pathID,
                        treeID = treeID,
                        currentRank = 0,
                        maxRank = 0,
                        locked = true,
                    }
                end
            else
                local currentRank, maxRank = GetPathRanks(configID, pathID)
                if currentRank and maxRank then
                    readable = readable + 1
                    if maxRank > 0 and currentRank < maxRank then
                        local entry = {
                            pathID = pathID,
                            treeID = treeID,
                            currentRank = currentRank,
                            maxRank = maxRank,
                            -- Jamais appris : le moteur ne fera que le debloquer,
                            -- et l'infobulle doit annoncer cela, pas un rang.
                            locked = IsPathUnlocked(configID, pathID) == false,
                        }
                        if currentRank > 0 then
                            started[#started + 1] = entry
                        else
                            untouched[#untouched + 1] = entry
                        end
                    end
                end
            end
        end
    end

    -- `pairs` ne garantit aucun ordre : sans tri, deux passes successives sur le
    -- MEME etat pourraient nommer deux noeuds differents, et le libelle du bouton
    -- changerait entre l'affichage et le clic.
    local function ByPathID(a, b)
        return a.pathID < b.pathID
    end
    table.sort(started, ByPathID)
    table.sort(untouched, ByPathID)
    return started, untouched, buyableRoot, readable
end

--- Noeud vierge a completer, tire une fois et garde jusqu'a ce qu'il soit plein.
--
-- Rejouer le tirage a chaque rafraichissement ferait danser la cible entre deux
-- clics, et un autoclicker sauterait d'un noeud a l'autre sans jamais en finir
-- un. Le choix n'a pas besoin de survivre au /reload : des le premier point pose,
-- le noeud devient « entame » et passe devant tout nouveau tirage.
local function PickUntouched(skillLineID, untouched)
    local chosen = randomChoice[skillLineID]
    if chosen then
        for _, entry in ipairs(untouched) do
            if entry.pathID == chosen then
                return entry
            end
        end
        -- Plus candidat : plein, page refermee, ou arbre change.
        randomChoice[skillLineID] = nil
    end

    local count = #untouched
    if count == 0 then
        return nil
    end

    local index = tonumber(randomSource(count)) or 1
    index = math.floor(index)
    if index < 1 or index > count then
        index = 1
    end

    local entry = untouched[index]
    randomChoice[skillLineID] = entry.pathID
    return entry
end

--- Cible de repli, de la meme forme que celle du plan.
--
-- `targetRank` vaut le maximum du noeud, donc `ResolveStepSize` rend ce maximum
-- et un seul clic remplit le noeud : le moteur plafonne de toute facon a
-- `maxRank`, il n'y a rien a depasser.
local function ResolveRandomFillTarget(skillLineID, configID)
    if not RandomFillAllowed() then
        return nil
    end

    local started, untouched, buyableRoot, readable =
        CollectFillCandidates(skillLineID, configID)
    if not started then
        return nil, "tree-unavailable"
    end
    if readable == 0 and not buyableRoot then
        -- L'arbre repond, mais aucun rang ne se lit : ce n'est pas un arbre plein,
        -- et l'alerte KP n'a aucune raison de s'eteindre la-dessus.
        return nil, "rank-unavailable"
    end

    -- Les pages deja payees d'abord, en entier : ouvrir la suivante coute un point
    -- et une confirmation, et rouvre une fournee de candidats.
    local entry = started[1] or PickUntouched(skillLineID, untouched) or buyableRoot
    if not entry then
        return nil
    end

    return {
        skillLineID = skillLineID,
        configID = configID,
        pathID = entry.pathID,
        treeID = entry.treeID,
        currentRank = entry.currentRank,
        targetRank = entry.maxRank,
        maxRank = entry.maxRank,
        unlockOnly = entry.locked == true,
        randomFill = true,
        step = {
            path = entry.pathID,
            rank = entry.maxRank,
            name = GetPathName(configID, entry.pathID)
                or ("path " .. tostring(entry.pathID)),
        },
    }
end

-- ---------------------------------------------------------------------------
-- Resolution du plan
-- ---------------------------------------------------------------------------

--- Premiere etape non satisfaite ET realisable du plan d'un metier, ou nil.
--
-- Une etape dont la page est encore verrouillee par le niveau de metier est
-- SAUTEE, pas bloquante : le plan alterne entre les quatre pages, et attendre le
-- prochain palier de 25 niveaux laisserait dormir des points utilisables ailleurs.
-- Elle reprendra sa place dans l'ordre des que la page s'ouvrira, l'ordre du plan
-- etant relu en entier a chaque passe. Le second retour dit ce qui a ete saute.
function api.ResolvePlanTarget(skillLineID)
    local plan = SPEC_PLANS[skillLineID]
    if type(plan) ~= "table" or type(plan.steps) ~= "table" or #plan.steps == 0 then
        return nil
    end

    local configID = GetConfigID(skillLineID)
    if not configID then
        return nil, "config-unavailable"
    end

    local byPath = GetTreeIDsByPath(skillLineID)
    local skipped

    for index, step in ipairs(plan.steps) do
        local pathID = tonumber(step.path)
        local wanted = tonumber(step.rank)
        if pathID and wanted and wanted >= 0 then
            local currentRank, maxRank = GetPathRanks(configID, pathID)
            if currentRank == nil then
                -- Un rang illisible n'est pas un plan termine : on s'arrete ici
                -- plutot que de sauter l'etape et d'aller depenser plus loin.
                return nil, "rank-unavailable"
            end

            -- `rank = 0` ne demande pas zero point : il demande que le noeud
            -- soit APPRIS, sans rien y depenser de plus. Comparer les rangs le
            -- declarerait satisfait alors qu'il est encore verrouille.
            local satisfied, targetRank
            if wanted == 0 then
                targetRank = 0
                satisfied = IsPathUnlocked(configID, pathID)
                if satisfied == nil then
                    return nil, "state-unavailable"
                end
            else
                targetRank = maxRank and math.min(wanted, maxRank) or wanted
                satisfied = currentRank >= targetRank
            end

            if not satisfied then
                local treeID = byPath and byPath[pathID] or nil
                if treeID and IsTabLocked(treeID, configID) then
                    skipped = skipped or {
                        step = step,
                        stepIndex = index,
                        treeID = treeID,
                    }
                else
                    return {
                        skillLineID = skillLineID,
                        configID = configID,
                        stepIndex = index,
                        step = step,
                        pathID = pathID,
                        currentRank = currentRank,
                        targetRank = targetRank,
                        unlockOnly = wanted == 0,
                        maxRank = maxRank,
                        treeID = treeID,
                        totalSteps = #plan.steps,
                        skipped = skipped,
                    }
                end
            end
        end
    end

    if skipped then
        return nil, "tab-locked", skipped
    end

    -- Plan termine : le repli prend la suite s'il est autorise, sinon `nil`, comme
    -- avant lui. Une etape SAUTEE ne l'ouvre pas : la page verrouillee finira par
    -- s'ouvrir et les points qu'elle attend ne doivent pas partir ailleurs
    -- entre-temps -- ils ne se reprennent pas.
    return ResolveRandomFillTarget(skillLineID, configID)
end

--- Palier a demander au moteur : la cible du plan elle-meme.
--
-- Un clic mene donc le noeud courant a son rang vise en une fois, comme le fait
-- Alt+Shift+clic, au lieu de grimper cinq par cinq. C'est ce que `stepSize` rend
-- possible sans rien depasser : `GetProfessionSpecPurchaseGoal` arrondit au
-- multiple superieur du pas, et tant que le rang courant est sous la cible,
-- `(floor(courant / cible) + 1) * cible` vaut exactement la cible. Le pas EST
-- donc le plafond -- passer `nil` (le vrai mode Alt+Shift) remplirait le noeud
-- jusqu'a son maximum, bien au-dela du plan, et ces points ne se reprennent pas.
--
-- Dans la remontee des prerequis, le moteur borne de lui-meme au seuil exige par
-- l'enfant : le parent monte d'un coup jusqu'a ce seuil, jamais plus loin.
local function ResolveStepSize(target)
    -- Une etape de simple deblocage ne doit surtout pas passer un pas nul : le
    -- moteur lit `stepSize > 0` et, sans lui, bascule en remplissage complet --
    -- il monterait le noeud a son maximum au lieu de s'arreter a l'apprentissage.
    if target.unlockOnly or target.targetRank <= 0 then
        return UNLOCK_STEP_SIZE
    end
    return target.targetRank
end

-- ---------------------------------------------------------------------------
-- Etape suivante
-- ---------------------------------------------------------------------------

--- Redemande un rafraichissement tant qu'une operation d'achat est en vol.
local ScheduleBusyRefresh
ScheduleBusyRefresh = function(attempt)
    if type(C_Timer) ~= "table" or type(C_Timer.After) ~= "function" then
        return
    end
    attempt = (tonumber(attempt) or 0) + 1
    if attempt > BUSY_REFRESH_MAX_ATTEMPTS then
        return
    end

    C_Timer.After(BUSY_REFRESH_INTERVAL, function()
        if type(api.RequestTrackerRefresh) == "function" then
            api.RequestTrackerRefresh()
        end
        local queue = GetQueueAPI()
        if queue and queue.IsProfessionSpecBusy() then
            ScheduleBusyRefresh(attempt)
        end
    end)
end

-- Derniere raison d'indisponibilite deja dite, pour ne pas la repeter a chaque
-- clic.
local lastApplyFailure

-- Un bouton eteint est un etat ABSORBANT. C'est le clic qui demande le
-- rafraichissement suivant -- `Step` appelle `RequestTrackerRefresh` -- et un
-- bouton desactive ne recoit plus de clic : plus rien ne vient reevaluer son
-- etat. Le jeu, lui, redevient pret une seconde plus tard (Blizzard desactive
-- son bouton Appliquer le temps du commit, puis le rallume), mais personne ne
-- regarde, et le bouton reste gris jusqu'a ce qu'un evenement sans rapport
-- passe par la. D'ou ce reveil, arme chaque fois qu'un etat desactive est rendu.
--
-- L'intervalle double tant que l'etat reste eteint, plafonne : deverrouiller
-- vite dans le cas normal, sans tourner a 1 Hz pour rien devant un blocage
-- durable. Il repart a son minimum des qu'un etat actif est rendu.
local DISABLED_RECHECK_MIN = 1
local DISABLED_RECHECK_MAX = 8
local disabledRecheckDelay = DISABLED_RECHECK_MIN
local disabledRecheckPending = false

local function ScheduleDisabledRecheck()
    if disabledRecheckPending
        or type(C_Timer) ~= "table"
        or type(C_Timer.After) ~= "function" then
        return
    end
    disabledRecheckPending = true
    local delay = disabledRecheckDelay
    disabledRecheckDelay = math.min(delay * 2, DISABLED_RECHECK_MAX)
    C_Timer.After(delay, function()
        disabledRecheckPending = false
        if type(api.RequestTrackerRefresh) == "function" then
            api.RequestTrackerRefresh()
        end
    end)
end

local function BuildAction(kind, target, reason)
    return {
        kind = kind,
        reason = reason,
        skillLineID = target and target.skillLineID or nil,
        configID = target and target.configID or nil,
        treeID = target and target.treeID or nil,
        target = target,
    }
end

--- Rangs poses sur le metier OUVERT et pas encore appliques : l'etape qui les
-- sauve, ou nil s'il n'y a rien en attente.
--
-- Cette question passe AVANT tout changement de metier. Avec deux metiers a
-- servir, le plan du premier se deroulait -- rangs mis en attente, jamais
-- commites -- puis, plus aucun achat n'y etant possible, la boucle proposait
-- d'OUVRIR le second : la fenetre changeait de metier et les points poses sur
-- le premier n'etaient jamais appliques. L'application ne vient donc « en
-- dernier » que pour le metier AFFICHE ; le quitter, c'est la perdre.
--
-- Onglet Specialisations masque : on le rouvre d'abord, le bouton natif
-- « Appliquer » n'existe que la. Le libelle est repris de la ligne du tracker,
-- pour que le bouton dise de quel metier il s'agit.
local function ResolvePendingApplyAction(openedSkillLineID, rows)
    if not openedSkillLineID then
        return nil
    end
    local openedConfigID = GetConfigID(openedSkillLineID)
    if not HasStagedChanges(openedConfigID) then
        return nil
    end

    local label
    for _, row in ipairs(rows or {}) do
        if row and tonumber(row.skillLineID) == openedSkillLineID then
            label = row.config and row.config.label or nil
            break
        end
    end
    local target = {
        skillLineID = openedSkillLineID,
        configID = openedConfigID,
        label = label,
        pendingApply = true,
    }
    if not IsSpecPageVisible() then
        return BuildAction("open-spec-tab", target)
    end
    if IsTreePreviewShown() then
        return BuildAction("close-preview", target)
    end
    return BuildAction("apply", target)
end

--- Decrit ce que le prochain clic fera, ou nil s'il n'y a rien a faire.
function api.GetNextAction()
    if type(api.IsEnabled) == "function" and api.IsEnabled() == false then
        return nil
    end
    if not GetQueueAPI() then
        return nil
    end

    local rows = type(api.GetTrackedProfessionRows) == "function"
        and api.GetTrackedProfessionRows()
        or nil
    if type(rows) ~= "table" or #rows == 0 then
        return nil
    end

    -- Une operation en vol ne fait pas DISPARAITRE le bouton : il reste visible
    -- et grise. Le masquer decalait toute la pile d'un cran sous l'autoclicker,
    -- et surtout, rien ne garantissait qu'un rafraichissement revienne une fois
    -- l'operation finie -- le bouton disparaissait alors pour de bon, plan non
    -- termine. `ScheduleBusyRefresh` est ce qui le fait revenir.
    local queue = GetQueueAPI()
    if queue.IsProfessionSpecBusy() then
        return BuildAction("busy")
    end

    -- Priorite absolue : une fenetre de confirmation ouverte bloque le moteur
    -- (`AnyPopupShown`). Tant qu'elle est la, il n'y a litteralement rien d'autre
    -- a faire.
    local popupIndex, popupWhich = FindSpecConfirmPopup()
    if popupIndex then
        return BuildAction("confirm-popup", { popupIndex = popupIndex, which = popupWhich })
    end

    local openedSkillLineID = GetOpenProfessionSkillLineID()

    -- Le metier AFFICHE passe en premier : son plan se termine avant qu'on
    -- envisage d'en changer, quel que soit l'ordre des lignes du tracker. Sinon
    -- une ligne placee avant lui proposait d'appliquer -- ou d'ouvrir -- alors
    -- qu'un achat y restait possible.
    local ordered = rows
    if openedSkillLineID then
        ordered = {}
        for _, row in ipairs(rows) do
            if row and tonumber(row.skillLineID) == openedSkillLineID then
                ordered[#ordered + 1] = row
            end
        end
        for _, row in ipairs(rows) do
            if not (row and tonumber(row.skillLineID) == openedSkillLineID) then
                ordered[#ordered + 1] = row
            end
        end
    end

    for _, row in ipairs(ordered) do
        local skillLineID = row and tonumber(row.skillLineID)
        if skillLineID and SPEC_PLANS[skillLineID] then
            local knowledge = GetAvailableKnowledge(skillLineID)
            if knowledge and knowledge > 0 then
                local target, reason, skippedStep = api.ResolvePlanTarget(skillLineID)
                if target then
                    target.row = row
                    target.knowledge = knowledge
                    target.label = row.config and row.config.label or tostring(skillLineID)

                    if openedSkillLineID ~= skillLineID then
                        -- Ne jamais quitter un metier dont les rangs poses ne
                        -- sont pas appliques : ils ne survivent pas au changement.
                        local pending = ResolvePendingApplyAction(openedSkillLineID, rows)
                        if pending then
                            return pending
                        end
                        return BuildAction("open-profession", target)
                    end
                    openAttempts[skillLineID] = nil
                    if not IsSpecPageVisible() then
                        return BuildAction("open-spec-tab", target)
                    end
                    if not target.treeID then
                        return BuildAction("blocked", target, "tree-unknown")
                    end
                    local needsSelect = GetSelectedTreeID() ~= target.treeID
                    local displayReady = IsDisplayedTreeReady(target.treeID)
                    if not needsSelect and displayReady then
                        -- Arrive pour de bon : les deux oracles s'accordent.
                        selectAttempts[target.treeID] = nil
                    elseif not needsSelect then
                        -- L'onglet est le bon, l'arbre charge ne l'est pas
                        -- encore : on redemande la page. Quelques fois
                        -- seulement -- si le client ne suit pas, mieux vaut
                        -- laisser l'achat tenter sa chance que figer le plan.
                        -- Le compteur RESTE alors a son plafond : le remettre a
                        -- zero en renoncant faisait osciller navigation et
                        -- achat a l'infini.
                        needsSelect = (selectAttempts[target.treeID] or 0)
                            < SELECT_TREE_MAX_ATTEMPTS
                    end
                    if needsSelect then
                        return BuildAction("select-tree", target)
                    end
                    -- Page ouverte a l'achat mais pas encore payee. Viser la
                    -- RACINE : le moteur ne declenche la fenetre de confirmation
                    -- de Blizzard que si la cible est la racine de l'onglet, et
                    -- un noeud interieur repartait sur `skip=tab-locked`.
                    if not IsTabUnlocked(target.treeID, target.configID) then
                        target.rootPathID = GetRootPathForTab(target.treeID)
                        if not target.rootPathID then
                            return BuildAction("blocked", target, "tab-root-unknown")
                        end
                        return BuildAction("unlock-tab", target)
                    end
                    -- Page deverrouillee, mais l'apercu la recouvre encore.
                    if IsTreePreviewShown() then
                        return BuildAction("close-preview", target)
                    end
                    return BuildAction("purchase", target)
                elseif reason then
                    DebugLog(
                        "SpecPlan resolve skillLine=%s sans cible: %s%s",
                        tostring(skillLineID),
                        tostring(reason),
                        skippedStep and (" saute=etape " .. tostring(skippedStep.stepIndex)
                            .. " " .. tostring(skippedStep.step and skippedStep.step.name)) or ""
                    )
                end
            end
        end
    end

    -- L'application vient EN DERNIER, quand plus aucun achat n'est possible sur
    -- le metier affiche.
    --
    -- Elle etait prioritaire, et c'etait un piege : le moteur laisse les rangs
    -- en attente, si bien qu'apres le tout premier achat le bouton ne proposait
    -- plus que « appliquer ». Une application qui echoue figeait alors le plan
    -- entier -- observe sur Processing, debloque a 0 puis plus rien. Les rangs
    -- en attente s'empilent sans se gener : mieux vaut derouler le plan, puis
    -- valider, et si la validation ne part pas le joueur garde le bouton natif.
    -- Le changement de metier, lui, est traite dans la boucle : il passe apres
    -- l'application, jamais avant.
    return ResolvePendingApplyAction(openedSkillLineID, rows)
end

-- ---------------------------------------------------------------------------
-- Libelle et infobulle
-- ---------------------------------------------------------------------------

local function DescribeTarget(target)
    if not target or not target.step then
        return ""
    end
    local name = target.step.name or ("path " .. tostring(target.pathID))
    if target.unlockOnly then
        -- Une etape a `rank = 0` n'a pas de progression a montrer : elle est
        -- soit a apprendre, soit faite. Afficher `0/0` ne dirait rien.
        return ("%s (débloquer)"):format(name)
    end
    return ("%s %d/%d"):format(name, target.currentRank or 0, target.targetRank or 0)
end

local function BuildButtonStateInternal()
    local action = api.GetNextAction()
    pendingAction = action
    if not action then
        return nil
    end

    local target = action.target
    local label = target and target.label or "Spé"
    local lines = {}

    if action.kind == "busy" then
        -- Visible mais grise : le masquer decalerait toute la pile d'un cran
        -- sous l'autoclicker, le temps d'un achat.
        return {
            action = action,
            label = "Spé : en cours...",
            enabled = false,
            tooltip = { "Achat en cours, le jeu n'a pas encore confirmé." },
        }
    end

    if action.kind == "confirm-popup" then
        return {
            action = action,
            label = "Spé : confirmer",
            enabled = true,
            tooltip = {
                "Valide la fenêtre de confirmation ouverte par le jeu.",
                ("Équivaut à /click StaticPopup%dButton1."):format(
                    action.target.popupIndex),
                "Tant qu'elle est affichée, rien d'autre ne peut avancer.",
            },
        }
    end

    if action.kind == "close-preview" then
        local previewButton, previewReason = GetTreePreviewButton()
        return {
            action = action,
            label = "Spé : voir l'arbre",
            enabled = previewButton ~= nil,
            tooltip = previewButton and {
                "La page de présentation recouvre l'arbre de spécialisation.",
                "Tant qu'elle est affichée, le jeu cache son bouton « Appliquer ».",
                "Ce clic affiche l'arbre complet.",
            } or {
                ("Bouton de retour à l'arbre indisponible (%s)."):format(
                    tostring(previewReason)),
                "Clique « Voir l'arbre » toi-même dans la fenêtre de métier.",
            },
        }
    end

    if action.kind == "apply" then
        local applyButton, applyReason = GetApplyButton()
        return {
            action = action,
            label = target and target.label
                and ("Spé %s : appliquer"):format(target.label)
                or "Spé : appliquer",
            enabled = applyButton ~= nil,
            tooltip = applyButton and {
                "Applique les points déjà placés.",
                "Le jeu ne les enregistre qu'après cette validation.",
            } or {
                ("Bouton « Appliquer » du jeu indisponible (%s)."):format(
                    tostring(applyReason)),
                "Clique-le toi-même dans la fenêtre de métier.",
            },
        }
    end

    if action.kind == "blocked" then
        return {
            action = action,
            label = ("Spé %s : indisponible"):format(label),
            enabled = false,
            tooltip = {
                ("Onglet introuvable pour %s."):format(DescribeTarget(target)),
                "Ouvrir une fois la fenêtre de métier pour charger l'arbre.",
            },
        }
    end

    if target.pendingApply then
        -- Pas de cible d'achat : seulement des rangs poses a sauver avant de
        -- passer a un autre metier.
        lines[#lines + 1] = ("Des points placés sur %s attendent d'être appliqués."):format(label)
    else
        if target.randomFill then
            -- Hors plan : plus aucune etape numerotee a annoncer.
            lines[#lines + 1] = ("Remplissage libre %s : %s"):format(
                label,
                DescribeTarget(target)
            )
        else
            lines[#lines + 1] = ("Plan %s, étape %d/%d : %s"):format(
                label,
                target.stepIndex or 0,
                target.totalSteps or 0,
                DescribeTarget(target)
            )
        end
        lines[#lines + 1] = ("%d point(s) de connaissance disponible(s)."):format(
            target.knowledge or 0
        )
    end

    if action.kind == "open-profession" then
        lines[#lines + 1] = "Ce clic ouvre la fenêtre du métier."
        return {
            action = action,
            label = ("Spé %s : ouvrir"):format(label),
            enabled = true,
            tooltip = lines,
        }
    end
    if action.kind == "open-spec-tab" then
        lines[#lines + 1] = "Ce clic ouvre l'onglet Spécialisations."
        return {
            action = action,
            label = ("Spé %s : onglet"):format(label),
            enabled = true,
            tooltip = lines,
        }
    end
    if action.kind == "select-tree" then
        lines[#lines + 1] = "Ce clic sélectionne la bonne spécialisation."
        return {
            action = action,
            label = ("Spé %s : sélectionner"):format(label),
            enabled = true,
            tooltip = lines,
        }
    end
    if action.kind == "unlock-tab" then
        lines[#lines + 1] = "Ce clic ouvre la confirmation Blizzard de déblocage de la page."
        lines[#lines + 1] = "C'est toi qui l'acceptes."
        return {
            action = action,
            label = ("Spé %s : débloquer la page"):format(label),
            enabled = true,
            tooltip = lines,
        }
    end

    if target.unlockOnly then
        lines[#lines + 1] = "Ce clic apprend le nœud, sans y dépenser de point de plus."
    else
        local stepSize = ResolveStepSize(target)
        local nextRank = math.min(
            target.targetRank,
            (math.floor(target.currentRank / stepSize) + 1) * stepSize
        )
        lines[#lines + 1] = ("Ce clic monte le nœud à %d."):format(nextRank)
    end
    lines[#lines + 1] = "Les points dépensés ne se reprennent pas."
    if target.skipped and target.skipped.step then
        lines[#lines + 1] = ("Étape %d (%s) sautée : sa page est encore verrouillée."):format(
            target.skipped.stepIndex or 0,
            tostring(target.skipped.step.name)
        )
    end

    return {
        action = action,
        label = ("Spé %s : %s"):format(label, DescribeTarget(target)),
        enabled = true,
        tooltip = lines,
    }
end

--- Etat du bouton, et le reveil qui va avec quand il est rendu eteint.
function api.BuildButtonState()
    local state = BuildButtonStateInternal()
    if state and state.enabled == false then
        ScheduleDisabledRecheck()
    else
        disabledRecheckDelay = DISABLED_RECHECK_MIN
    end
    return state
end

function api.GetPendingAction()
    return pendingAction
end

--- Reste-t-il des points a placer utilement dans ce metier ?
--
-- Trois reponses, jamais deux. `nil` : aucun plan pour ce metier, le tracker
-- garde son alerte KP telle quelle. `true` : une etape est faisable maintenant.
-- `false` : plan termine, ou tout ce qui reste attend une page verrouillee par
-- le niveau de metier -- dans les deux cas les points ne sont pas depensables,
-- et l'alerte n'est que du bruit.
--
-- Un arbre illisible rend `nil` et non `false` : ne pas savoir n'est pas une
-- raison d'eteindre un rappel.
function api.HasSpendableWork(skillLineID)
    skillLineID = tonumber(skillLineID)
    if not skillLineID or type(SPEC_PLANS[skillLineID]) ~= "table" then
        return nil
    end

    local target, reason = api.ResolvePlanTarget(skillLineID)
    if target then
        return true
    end
    if reason == "rank-unavailable"
        or reason == "state-unavailable"
        or reason == "config-unavailable"
        or reason == "tree-unavailable" then
        return nil
    end
    return false
end

-- ---------------------------------------------------------------------------
-- Execution, une etape par clic
-- ---------------------------------------------------------------------------

--- Arme ou desarme l'action securisee du bouton.
-- Seule l'etape d'application passe par un clic securise : le bouton Appliquer
-- de Blizzard commite la configuration, et C_Traits.CommitConfig est refuse a du
-- code d'addon. Toutes les autres etapes sont de simples appels d'API, donc le
-- type securise doit etre efface, faute de quoi le clic suivant rejouerait la
-- derniere action armee.
--- Desarme toute action securisee du bouton.
-- Indispensable avant chaque etape non securisee : sans cela le clic rejouerait
-- la derniere action armee, en plus de l'etape courante.
local function DisarmSecureAction(button)
    if not button or (InCombatLockdown and InCombatLockdown()) then
        return false
    end
    button:SetAttribute("type", nil)
    button:SetAttribute("clickbutton", nil)
    button:SetAttribute("macrotext", nil)
    return true
end

-- Une cible absente DESARME, elle ne se contente pas d'echouer. Sans cela, le
-- clic materiel qui suit rejouait la derniere action armee : le bouton
-- Appliquer, desactive le temps du commit, faisait rendre nil ici, l'addon
-- annoncait « indisponible » -- et le clic repartait quand meme vers lui.
local function ArmSecureClick(button, targetButton)
    if not button or (InCombatLockdown and InCombatLockdown()) then
        return false
    end
    if not targetButton then
        DisarmSecureAction(button)
        return false
    end
    button:SetAttribute("type", "click")
    button:SetAttribute("clickbutton", targetButton)
    button:SetAttribute("macrotext", nil)
    return true
end

--- Arme la macro securisee `macrotext` sur le bouton.
-- Preferee au clic par reference pour les StaticPopup : elle ne depend que du
-- nom global du bouton, exactement comme la macro que le joueur taperait.
local function ArmSecureMacro(button, macrotext)
    if not button or (InCombatLockdown and InCombatLockdown()) then
        return false
    end
    if not macrotext then
        DisarmSecureAction(button)
        return false
    end
    button:SetAttribute("type", "macro")
    button:SetAttribute("macrotext", macrotext)
    button:SetAttribute("clickbutton", nil)
    return true
end

--- Ouvre la ligne de metier visee.
--
-- Deux identifiants possibles et un seul essai par clic. La ligne d'extension
-- (2906 pour l'alchimie Midnight) est la bonne cible, mais elle n'est acceptee
-- que si ses donnees sont chargees ; sinon le client ignore l'appel et le bouton
-- reproposait « ouvrir » sans fin. Au deuxieme passage sur le meme metier on
-- retombe donc sur le metier de BASE, que le client ouvre toujours, quitte a
-- atterrir sur une autre extension -- de la, un clic de plus rebascule sur la
-- bonne ligne, cette fois avec les donnees chargees.
local function StepOpenProfession(target)
    if type(C_TradeSkillUI) ~= "table" or type(C_TradeSkillUI.OpenTradeSkill) ~= "function" then
        return false, "api-unavailable"
    end

    local skillLineID = target.skillLineID
    local attempts = (openAttempts[skillLineID] or 0) + 1
    openAttempts[skillLineID] = attempts

    local requestedID = skillLineID
    if attempts > 1 then
        local info = SafeCall(
            C_TradeSkillUI.GetProfessionInfoBySkillLineID,
            skillLineID
        )
        local parentID = type(info) == "table" and tonumber(info.parentProfessionID) or nil
        requestedID = parentID or skillLineID
    end

    local ok = pcall(C_TradeSkillUI.OpenTradeSkill, requestedID)
    DebugLog(
        "SpecPlan open-profession skillLine=%s demande=%s tentative=%d ok=%s",
        tostring(skillLineID),
        tostring(requestedID),
        attempts,
        tostring(ok)
    )
    return ok == true, ok and nil or "open-refused"
end

local function StepOpenSpecTab()
    local tabID = ProfessionsFrame and ProfessionsFrame.specializationsTabID
    if not ProfessionsFrame or not tabID then
        return false, "tab-unavailable"
    end

    if type(ProfessionsFrame.SetTab) == "function" then
        local ok = pcall(ProfessionsFrame.SetTab, ProfessionsFrame, tabID)
        DebugLog("SpecPlan open-spec-tab tab=%s ok=%s", tostring(tabID), tostring(ok))
        if ok then
            return true, nil
        end
    end

    local tabs = ProfessionsFrame.TabSystem and ProfessionsFrame.TabSystem.tabs
    local tabButton = tabs and tabs[tabID]
    if type(tabButton) == "table" and type(tabButton.Click) == "function" then
        local ok = pcall(tabButton.Click, tabButton)
        DebugLog("SpecPlan open-spec-tab fallback=click ok=%s", tostring(ok))
        return ok == true, ok and nil or "tab-click-refused"
    end
    return false, "tab-unavailable"
end

--- Execute l'etape courante. Appele depuis le PreClick du bouton du tracker.
function api.Step(button)
    local state = api.BuildButtonState()
    local action = state and state.action
    if not action then
        DisarmSecureAction(button)
        return false
    end

    -- Les deux seules etapes qui passent par une action securisee : elles visent
    -- un bouton de Blizzard qui commite la configuration de traits, ce qu'un
    -- appel direct depuis l'addon se verrait refuser. Le clic materiel du joueur
    -- sur notre bouton est ce qui autorise l'action.
    if action.kind == "confirm-popup" then
        local macro = ("/click StaticPopup%dButton1"):format(action.target.popupIndex)
        local armed = ArmSecureMacro(button, macro)
        DebugLog(
            "SpecPlan confirm-popup which=%s macro=%s armed=%s",
            tostring(action.target.which),
            macro,
            tostring(armed)
        )
        return armed
    end

    if action.kind == "close-preview" then
        local previewButton, previewReason = GetTreePreviewButton()
        local armed = ArmSecureClick(button, previewButton)
        DebugLog(
            "SpecPlan close-preview armed=%s raison=%s",
            tostring(armed),
            tostring(previewReason)
        )
        if type(api.RequestTrackerRefresh) == "function" then
            api.RequestTrackerRefresh()
        end
        return armed
    end

    if action.kind == "apply" then
        local applyButton, applyReason = GetApplyButton()
        local armed = ArmSecureClick(button, applyButton)
        DebugLog("SpecPlan apply armed=%s raison=%s", tostring(armed), tostring(applyReason))
        if armed then
            lastApplyFailure = nil
        elseif lastApplyFailure ~= applyReason then
            -- Une seule plainte par episode : la meme sortait a chaque clic, et
            -- un autoclicker en remplissait le chat en une seconde.
            lastApplyFailure = applyReason
            Say("error", ("Spé : bouton « Appliquer » du jeu indisponible (%s)")
                :format(tostring(applyReason)))
        end
        if type(api.RequestTrackerRefresh) == "function" then
            api.RequestTrackerRefresh()
        end
        return armed
    end

    DisarmSecureAction(button)


    local target = action.target
    local ok, reason = false, action.reason

    if action.kind == "open-profession" then
        ok, reason = StepOpenProfession(target)
    elseif action.kind == "open-spec-tab" then
        ok, reason = StepOpenSpecTab()
    elseif action.kind == "select-tree" then
        local queue = GetQueueAPI()
        ok = (queue ~= nil and queue.SelectProfessionSpecTab(target.treeID)) or false
        reason = ok and nil or "tree-refused"
        selectAttempts[target.treeID] = (selectAttempts[target.treeID] or 0) + 1
        -- `SelectProfessionSpecTab` rend true sans rien faire quand l'onglet est
        -- deja le bon -- exactement le cas ou l'arbre charge est reste l'ancien.
        -- On redemande alors la page a la frame elle-meme.
        if ok and not IsDisplayedTreeReady(target.treeID) then
            local frame = GetSpecFrame(true)
            if frame and type(frame.SetSelectedTab) == "function" then
                SafeCall(frame.SetSelectedTab, frame, target.treeID)
            end
        end
        DebugLog(
            "SpecPlan select-tree tree=%s ok=%s racine=%s attendue=%s tentative=%d",
            tostring(target.treeID),
            tostring(ok),
            tostring(GetDisplayedRootPathID()),
            tostring(GetRootPathForTab(target.treeID)),
            selectAttempts[target.treeID]
        )
    elseif action.kind == "unlock-tab" then
        local queue = GetQueueAPI()
        if not queue then
            return false
        end
        -- L'achat direct de la racine d'abord : il met le rang en attente comme
        -- les autres et evite la fenetre de confirmation, donc un clic de moins.
        -- S'il est refuse, on repasse par le moteur, qui ouvre la fenetre ;
        -- l'etape `confirm-popup` la validera au clic suivant.
        if type(queue.PurchaseProfessionSpecRank) == "function" then
            ok, reason = queue.PurchaseProfessionSpecRank(target.rootPathID)
        end
        if not ok then
            local directReason = reason
            ok, reason = queue.StepProfessionSpecTarget(target.rootPathID, UNLOCK_STEP_SIZE)
            DebugLog("SpecPlan unlock-tab achat direct refuse: %s", tostring(directReason))
        end
        DebugLog(
            "SpecPlan unlock-tab skillLine=%s tree=%s root=%s ok=%s reason=%s",
            tostring(target.skillLineID),
            tostring(target.treeID),
            tostring(target.rootPathID),
            tostring(ok),
            tostring(reason)
        )
        ScheduleBusyRefresh()
    elseif action.kind == "purchase" then
        local queue = GetQueueAPI()
        if not queue then
            return false
        end
        local stepSize = ResolveStepSize(target)
        ok, reason = queue.StepProfessionSpecTarget(target.pathID, stepSize)
        DebugLog(
            "SpecPlan purchase skillLine=%s path=%s rank=%s/%s step=%s ok=%s reason=%s",
            tostring(target.skillLineID),
            tostring(target.pathID),
            tostring(target.currentRank),
            tostring(target.targetRank),
            tostring(stepSize),
            tostring(ok),
            tostring(reason)
        )
        if not ok then
            Say("error", ("Spé %s : achat refusé (%s)"):format(
                target.label or "?", tostring(reason)))
        end
        ScheduleBusyRefresh()
    end

    if type(api.RequestTrackerRefresh) == "function" then
        api.RequestTrackerRefresh()
    end
    return ok == true
end

-- ---------------------------------------------------------------------------
-- Caches
-- ---------------------------------------------------------------------------

function api.InvalidateCaches()
    treeIDCache = {}
    pendingAction = nil
    -- Le noeud tire au sort, LUI, survit : cette fonction tourne a chaque
    -- TRAIT_CONFIG_UPDATED, donc apres chaque achat. Le vider ici rejouerait le
    -- tirage entre deux clics -- exactement ce qu'il sert a empecher. Un choix
    -- devenu invalide est ecarte par `PickUntouched`, qui le revalide contre la
    -- liste vivante.
end

-- ---------------------------------------------------------------------------
-- /ywt spec
-- ---------------------------------------------------------------------------

local function DumpTree(skillLineID, professionLabel)
    local configID = GetConfigID(skillLineID)
    if not configID then
        Say("reply", ("spec dump %s : arbre non charge, ouvrir le metier une fois.")
            :format(tostring(professionLabel or skillLineID)))
        return
    end

    local tabIDs = SafeCall(C_ProfSpecs and C_ProfSpecs.GetSpecTabIDsForSkillLine, skillLineID) or {}
    Say("reply", ("=== %s (skillLine %d, config %d) ==="):format(
        tostring(professionLabel or skillLineID), skillLineID, configID))

    local function DumpPath(pathID, depth, seen)
        if not pathID or seen[pathID] then
            return
        end
        seen[pathID] = true

        local currentRank, maxRank = GetPathRanks(configID, pathID)
        local name = GetPathName(configID, pathID) or ("path " .. tostring(pathID))
        Say("reply", ("%s%d  %s  %s/%s"):format(
            string.rep("  ", depth),
            pathID,
            name,
            tostring(currentRank or "?"),
            tostring(maxRank or "?")
        ))

        local children = SafeCall(C_ProfSpecs and C_ProfSpecs.GetChildrenForPath, pathID) or {}
        for _, childPathID in ipairs(children) do
            DumpPath(childPathID, depth + 1, seen)
        end
    end

    for _, tabID in ipairs(tabIDs) do
        local rootPathID = SafeCall(C_ProfSpecs.GetRootPathForTab, tabID)
        Say("reply", ("-- onglet %d --"):format(tabID))
        DumpPath(rootPathID, 1, {})
    end
end

--- Etat brut de tous les oracles dont depend le bouton.
--
-- Trois des quatre pannes constatees en jeu venaient d'un oracle qui ne rendait
-- pas ce qu'on croyait, pas de la logique du plan. Les afficher tous coute une
-- commande et evite une serie d'allers-retours en jeu.
--- Toutes les lignes du diagnostic vont au chat ET au journal.
-- Lues dans le chat elles defilent et se perdent ; le journal, lui, survit a la
-- session et se relit dans les SavedVariables. Sans ce doublon, diagnostiquer un
-- blocage revenait a demander une copie d'ecran de dix lignes.
local function ReportLine(message)
    Say("reply", message)
    DebugLog("spec diag %s", message)
end

local function ReportDiagnostics()
    local frame = GetSpecFrame(false)
    ReportLine(("diag ProfessionsFrame=%s visible=%s"):format(
        tostring(ProfessionsFrame ~= nil),
        tostring(ProfessionsFrame and type(ProfessionsFrame.IsVisible) == "function"
            and ProfessionsFrame:IsVisible())))
    ReportLine(("diag SpecPage=%s visible=%s tree=%s racine-affichee=%s"):format(
        tostring(frame ~= nil),
        tostring(IsSpecPageVisible()),
        tostring(GetSelectedTreeID()),
        tostring(GetDisplayedRootPathID())))

    local specInfo = frame and frame.professionInfo
    local childInfo = SafeCall(C_TradeSkillUI and C_TradeSkillUI.GetChildProfessionInfo)
    ReportLine(("diag professionID specPage=%s child=%s frame=%s retenu=%s"):format(
        tostring(type(specInfo) == "table" and specInfo.professionID),
        tostring(type(childInfo) == "table" and childInfo.professionID),
        tostring(ProfessionsFrame and type(ProfessionsFrame.professionInfo) == "table"
            and ProfessionsFrame.professionInfo.professionID),
        tostring(GetOpenProfessionSkillLineID())))

    local applyButton, applyReason = GetApplyButton()
    ReportLine(("diag ApplyButton=%s raison=%s"):format(
        tostring(applyButton ~= nil), tostring(applyReason)))

    -- L'apercu cache le bouton « Appliquer » de Blizzard : sans cette ligne, le
    -- diagnostic disait seulement « apply-hidden », sans dire ce qui le cachait.
    local previewButton, previewReason = GetTreePreviewButton()
    ReportLine(("diag TreePreview visible=%s bouton=%s raison=%s"):format(
        tostring(IsTreePreviewShown()),
        tostring(previewButton ~= nil),
        tostring(previewReason)))

    -- Pourquoi le bouton natif refuse, dans le detail. Blizzard le desactive
    -- notamment tant qu'une de SES fenetres est ouverte -- `AnyPopupShown` --
    -- et celles-la ne sont pas des StaticPopup : la boucle ci-dessous ne les
    -- verrait jamais. Un dialogue interne reste ouvert, le bouton reste gris,
    -- et rien ne le dit.
    local native = frame and frame.ApplyButton
    ReportLine(("diag ApplyButton natif shown=%s enabled=%s popupShown=%s"):format(
        tostring(type(native) == "table" and type(native.IsShown) == "function"
            and native:IsShown()),
        tostring(type(native) == "table" and type(native.IsEnabled) == "function"
            and native:IsEnabled()),
        tostring(frame and type(frame.AnyPopupShown) == "function"
            and SafeCall(frame.AnyPopupShown, frame))))

    -- Nommer ce dialogue interne : c'est le seul moyen d'apprendre ou cliquer.
    if type(frame) == "table" then
        for key, child in pairs(frame) do
            if type(child) == "table"
                and type(child.IsShown) == "function"
                and type(key) == "string"
                and (key:find("opup") or key:find("ialog") or key:find("onfirm"))
                and SafeCall(child.IsShown, child) == true then
                ReportLine(("diag fenetre interne %s visible nom=%s"):format(
                    key,
                    tostring(type(child.GetName) == "function"
                        and SafeCall(child.GetName, child))))
            end
        end
    end

    -- Toutes les fenetres ouvertes, pas seulement celles qu'on reconnait : c'est
    -- la seule facon de voir un `which` inattendu, qui laissait la detection
    -- muette et donc l'etape de confirmation jamais proposee.
    local popupIndex, popupWhich = FindSpecConfirmPopup()
    ReportLine(("diag popup retenue=%s index=%s"):format(
        tostring(popupWhich), tostring(popupIndex)))
    for index = 1, 4 do
        local dialog = _G["StaticPopup" .. index]
        if type(dialog) == "table"
            and type(dialog.IsShown) == "function"
            and dialog:IsShown() then
            local accept = _G["StaticPopup" .. index .. "Button1"]
            ReportLine(("diag StaticPopup%d visible which=%s bouton1=%s actif=%s"):format(
                index,
                tostring(dialog.which),
                tostring(accept ~= nil),
                tostring(accept and type(accept.IsEnabled) == "function"
                    and accept:IsEnabled())))
        end
    end

    local openedSkillLineID = GetOpenProfessionSkillLineID()
    if openedSkillLineID then
        local configID = GetConfigID(openedSkillLineID)
        ReportLine(("diag config=%s stagedChanges=%s"):format(
            tostring(configID), tostring(HasStagedChanges(configID))))
        if configID then
            local tabIDs = SafeCall(
                C_ProfSpecs and C_ProfSpecs.GetSpecTabIDsForSkillLine,
                openedSkillLineID
            ) or {}
            for _, tabID in ipairs(tabIDs) do
                ReportLine(("diag page %s etat=%s racine=%s"):format(
                    tostring(tabID),
                    tostring(GetTabState(tabID, configID)),
                    tostring(GetRootPathForTab(tabID))))
            end
        end
    end

    local queue = GetQueueAPI()
    ReportLine(("diag YayaQueue=%s occupe=%s"):format(
        tostring(queue ~= nil),
        tostring(queue and queue.IsProfessionSpecBusy())))
end

local function ReportStatus()
    local action = api.GetNextAction()
    if not action then
        local planned = 0
        for _ in pairs(SPEC_PLANS) do
            planned = planned + 1
        end
        Say("reply", ("spec : rien a faire (%d metier(s) avec un plan)."):format(planned))
        return
    end

    local target = action.target
    if target and target.step and target.randomFill then
        Say("reply", ("spec : %s, remplissage libre, %s, %d KP, action=%s"):format(
            tostring(target.label),
            DescribeTarget(target),
            target.knowledge or 0,
            action.kind))
    elseif target and target.step then
        Say("reply", ("spec : %s, etape %d/%d, %s, %d KP, action=%s"):format(
            tostring(target.label),
            target.stepIndex or 0,
            target.totalSteps or 0,
            DescribeTarget(target),
            target.knowledge or 0,
            action.kind))
    else
        Say("reply", ("spec : action=%s"):format(action.kind))
    end
end

--- Rend true si la commande a ete traitee.
function api.HandleSlash(args)
    args = tostring(args or ""):lower():match("^%s*(.-)%s*$")

    if args == "" then
        ReportStatus()
        return true
    end

    if args == "diag" then
        ReportDiagnostics()
        return true
    end

    if args == "random" or args == "random on" or args == "random off" then
        if type(api.SetRandomFillEnabled) ~= "function" then
            Say("reply", "spec random : reglage indisponible sans le tracker.")
            return true
        end
        local wanted
        if args == "random on" then
            wanted = true
        elseif args == "random off" then
            wanted = false
        else
            wanted = not RandomFillAllowed()
        end
        api.SetRandomFillEnabled(wanted)
        Say("reply", ("spec : remplissage libre une fois le plan termine %s"):format(
            wanted and "active" or "desactive"))
        return true
    end

    if args == "dump" or args:match("^dump%s") then
        local wanted = args:match("^dump%s+(.+)$")
        local rows = type(api.GetTrackedProfessionRows) == "function"
            and api.GetTrackedProfessionRows()
            or {}
        local dumped = 0
        for _, row in ipairs(rows) do
            local label = row.config and row.config.label or tostring(row.skillLineID)
            if not wanted
                or label:lower() == wanted
                or tostring(row.skillLineID) == wanted then
                DumpTree(row.skillLineID, label)
                dumped = dumped + 1
            end
        end
        if dumped == 0 then
            Say("reply", "spec dump : aucun metier suivi ne correspond.")
        end
        return true
    end

    return false
end

--- Nombre de metiers couverts par un plan, pour les tests et le diagnostic.
function api.GetPlannedProfessionCount()
    local count = 0
    for _ in pairs(SPEC_PLANS) do
        count = count + 1
    end
    return count
end

function api.GetPlanForSkillLine(skillLineID)
    return SPEC_PLANS[skillLineID]
end

--- Pose ou retire le plan d'un metier a chaud.
-- Seul point d'ecriture de SPEC_PLANS : les tests s'en servent pour injecter un
-- arbre connu, et une surcharge utilisateur passerait par la plutot que par une
-- seconde table qui vivrait a cote de celle du fichier.
function api.SetPlanForSkillLine(skillLineID, plan)
    skillLineID = tonumber(skillLineID)
    if not skillLineID then
        return false
    end
    SPEC_PLANS[skillLineID] = plan
    api.InvalidateCaches()
    return true
end

-- Les arbres ne changent qu'a un changement de configuration de traits ; le
-- cache pathID -> tabID est construit une fois par metier et par session.
local eventFrame = CreateFrame("Frame")
eventFrame:SetScript("OnEvent", function()
    api.InvalidateCaches()
end)
eventFrame:RegisterEvent("TRAIT_CONFIG_UPDATED")
eventFrame:RegisterEvent("SKILL_LINES_CHANGED")
