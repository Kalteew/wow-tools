-- Verifie la decision du plan de depense des points de connaissance.
--
-- Ce que la suite garde, dans l'ordre d'importance :
--
--  1. l'ordre du plan fait loi : la premiere etape sous sa cible gagne, meme si
--     une etape ulterieure est plus loin du compte ;
--  2. le palier demande au moteur ne DEPASSE JAMAIS la cible. C'est le point
--     dur : GetProfessionSpecPurchaseGoal arrondit au multiple superieur du pas,
--     donc viser 12 depuis 10 avec un pas de 5 monterait a 15. Trois points de
--     plus que le plan, et les points de connaissance ne se reprennent pas ;
--  3. la sequence d'etapes mene la fenetre Blizzard jusqu'a l'achat sans sauter
--     de cran, et un lot en attente ne bloque JAMAIS un achat encore possible :
--     l'inverse figeait le plan entier des que l'application echouait ;
--  4. les deux etapes qui commitent la configuration -- appliquer, et confirmer
--     la fenetre de Blizzard -- passent par un clic securise vers le bouton
--     natif, jamais par un appel direct, qui serait refuse a du code d'addon.
--
-- Ce que ce test ne couvre pas : le moteur d'achat lui-meme, qui vit dans
-- YayaQueue et parle au serveur.

dofile("Tests/wow_env.lua")

--------------------------------------------------------------------------------
-- Un arbre de metier minimal mais realiste
--
--   tab 100 : racine 10 -> 11 -> 12
--   tab 200 : racine 20
--
-- Les rangs vivent dans RANKS et sont lus par le faux YayaQueueAPI, exactement
-- comme le module lit le vrai.
--------------------------------------------------------------------------------

local SKILL_LINE_ID = 2906
local CONFIG_ID = 777

-- Un second metier, reduit a une page et une racine : il ne sert qu'a verifier
-- que le plan ne le rejoint pas en abandonnant des rangs en attente ailleurs.
local OTHER_SKILL_LINE_ID = 2913
local OTHER_CONFIG_ID = 778

local CHILDREN = {
    [10] = { 11 },
    [11] = { 12 },
    [12] = {},
    [20] = {},
    [30] = {},
}

local MAX_RANKS = {
    [10] = 30,
    [11] = 26,
    [12] = 20,
    [20] = 15,
    [30] = 20,
}

local RANKS = {}
local UNLOCKED = {}

local function ResetRanks()
    RANKS = { [10] = 0, [11] = 0, [12] = 0, [20] = 0, [30] = 0 }
    UNLOCKED = { [10] = true, [30] = true }
end

ResetRanks()

Enum = Enum or {}
Enum.ProfessionsSpecPathState = { Locked = 0, Unlocked = 1, Progressing = 2, Selected = 3 }
Enum.ProfessionsSpecTabState = { Locked = 0, Unlocked = 1, Unlockable = 2 }

-- Etat de chaque page. Le second onglet sert de page verrouillee par le niveau
-- de metier : c'est celle qu'on doit savoir sauter, puis reprendre.
TAB_STATES = { [100] = Enum.ProfessionsSpecTabState.Unlocked,
    [200] = Enum.ProfessionsSpecTabState.Unlocked,
    [300] = Enum.ProfessionsSpecTabState.Unlocked }

-- Points par metier quand ils different ; sinon KNOWLEDGE_AVAILABLE pour tous.
KNOWLEDGE_BY_SKILL = {}

C_ProfSpecs = {
    GetConfigIDForSkillLine = function(skillLineID)
        if skillLineID == SKILL_LINE_ID then
            return CONFIG_ID
        end
        return skillLineID == OTHER_SKILL_LINE_ID and OTHER_CONFIG_ID or nil
    end,
    GetSpecTabIDsForSkillLine = function(skillLineID)
        if skillLineID == SKILL_LINE_ID then
            return { 100, 200 }
        end
        return skillLineID == OTHER_SKILL_LINE_ID and { 300 } or {}
    end,
    GetRootPathForTab = function(tabID)
        return tabID == 100 and 10 or (tabID == 200 and 20 or (tabID == 300 and 30 or nil))
    end,
    GetChildrenForPath = function(pathID)
        return CHILDREN[pathID] or {}
    end,
    GetCurrencyInfoForSkillLine = function(skillLineID)
        return { numAvailable = KNOWLEDGE_BY_SKILL[skillLineID] or KNOWLEDGE_AVAILABLE }
    end,
    GetStateForTab = function(treeID)
        return TAB_STATES[treeID]
    end,
    GetStateForPath = function(pathID)
        return UNLOCKED[pathID] and Enum.ProfessionsSpecPathState.Unlocked
            or Enum.ProfessionsSpecPathState.Locked
    end,
}

C_Traits = C_Traits or {}
C_Traits.ConfigHasStagedChanges = function()
    return STAGED_CHANGES == true
end

KNOWLEDGE_AVAILABLE = 20
STAGED_CHANGES = false

--------------------------------------------------------------------------------
-- Faux YayaQueueAPI : la surface spec, et rien d'autre
--------------------------------------------------------------------------------

local lastPurchase

YayaQueueAPI = {
    GetProfessionSpecConfigID = function(skillLineID)
        return C_ProfSpecs.GetConfigIDForSkillLine(skillLineID)
    end,
    GetProfessionSpecPathRanks = function(_, nodeID)
        if RANKS[nodeID] == nil then
            return nil, nil
        end
        return RANKS[nodeID], MAX_RANKS[nodeID]
    end,
    GetProfessionSpecPathState = function(_, nodeID)
        return C_ProfSpecs.GetStateForPath(nodeID)
    end,
    IsProfessionSpecBusy = function()
        return false
    end,
    GetProfessionSpecFrame = function(requireVisible)
        if requireVisible and not SPEC_PAGE_VISIBLE then
            return nil
        end
        if not SPEC_PAGE_VISIBLE and OPEN_SKILL_LINE_ID == nil then
            return nil
        end
        return SPEC_FRAME
    end,
    SelectProfessionSpecTab = function(treeID)
        -- Comme le vrai : rien a faire si l'onglet est deja le bon. C'est ce
        -- court-circuit qui laisse l'apercu en place apres un deblocage, la
        -- frame ne repassant alors jamais par SetSelectedTab.
        if SELECTED_TREE_ID == treeID then
            return true
        end
        SPEC_FRAME.SetSelectedTab(SPEC_FRAME, treeID)
        return true
    end,
    StepProfessionSpecTarget = function(nodeID, stepSize)
        lastPurchase = { nodeID = nodeID, stepSize = stepSize }
        return true, nil
    end,
}

SPEC_PAGE_VISIBLE = false
SELECTED_TREE_ID = nil
OPEN_SKILL_LINE_ID = nil
APPLY_ENABLED = true
APPLY_CLICKS = 0
POPUP_SHOWN = nil
POPUP_CLICKS = 0

-- La page de specialisation Blizzard, reduite a ce que le module lui demande :
-- l'arbre affiche, le metier sur lequel elle est construite, et le bouton
-- Appliquer -- seul a pouvoir commiter la configuration de traits.
-- `DISPLAYED_ROOT_ID` decolle l'arbre charge de l'onglet choisi : c'est l'etat
-- d'une page fraichement debloquee, ou l'onglet porte deja le nouveau treeID
-- pendant que la frame affiche encore l'ancien arbre. nil = les deux d'accord.
DISPLAYED_ROOT_ID = nil

-- L'apercu d'une page -- titre, description, icone -- que Blizzard affiche par
-- dessus l'arbre des qu'on selectionne une page verrouillee. Il ne se referme
-- ni a l'achat de la racine ni au deverrouillage : seuls les deux boutons
-- ci-dessous, et le `onAccept` de la fenetre de confirmation, le cachent.
PREVIEW_SHOWN = false
PREVIEW_CLICKS = 0

SPEC_FRAME = {
    GetTalentTreeID = function() return SELECTED_TREE_ID end,
    GetRootNodeID = function()
        if DISPLAYED_ROOT_ID then
            return DISPLAYED_ROOT_ID
        end
        return C_ProfSpecs.GetRootPathForTab(SELECTED_TREE_ID)
    end,
    SetSelectedTab = function(_, treeID)
        SELECTED_TREE_ID = treeID
        DISPLAYED_ROOT_ID = nil
        -- `TreePreview:SetShown(isLocked)`, la derniere ligne du vrai.
        PREVIEW_SHOWN = TAB_STATES[treeID] ~= Enum.ProfessionsSpecTabState.Unlocked
    end,
    GetConfigID = function() return CONFIG_ID end,
    professionInfo = setmetatable({}, {
        __index = function(_, key)
            return key == "professionID" and OPEN_SKILL_LINE_ID or nil
        end,
    }),
    UpdateConfigButtonsState = function() end,
    UpdateSelectedTabState = function() end,
    ApplyButton = {
        Click = function() APPLY_CLICKS = APPLY_CLICKS + 1 end,
        -- `ApplyButton:SetShown(not isLocked and not TreePreview:IsShown())` :
        -- l'apercu ne grise pas le bouton, il le fait disparaitre.
        IsShown = function() return not PREVIEW_SHOWN end,
        IsEnabled = function() return APPLY_ENABLED end,
    },
    TreePreview = {
        IsShown = function() return PREVIEW_SHOWN end,
    },
    -- Blizzard n'en montre qu'un : « voir l'arbre complet » quand la page est
    -- deja deverrouillee, « voir l'arbre » quand elle ne l'est pas encore.
    BackToFullTreeButton = {
        Click = function()
            PREVIEW_CLICKS = PREVIEW_CLICKS + 1
            PREVIEW_SHOWN = false
        end,
        IsShown = function()
            return PREVIEW_SHOWN
                and TAB_STATES[SELECTED_TREE_ID] == Enum.ProfessionsSpecTabState.Unlocked
        end,
        IsEnabled = function() return true end,
    },
    ViewTreeButton = {
        Click = function()
            PREVIEW_CLICKS = PREVIEW_CLICKS + 1
            PREVIEW_SHOWN = false
        end,
        IsShown = function()
            return PREVIEW_SHOWN
                and TAB_STATES[SELECTED_TREE_ID] ~= Enum.ProfessionsSpecTabState.Unlocked
        end,
        IsEnabled = function() return true end,
    },
}

-- Fenetre de confirmation de Blizzard. `which` porte le nom que le module
-- reconnait ; un autre nom ne doit surtout pas etre clique.
StaticPopup1Button1 = {
    Click = function() POPUP_CLICKS = POPUP_CLICKS + 1 end,
    IsShown = function() return true end,
    IsEnabled = function() return true end,
}
StaticPopup1 = {
    IsShown = function() return POPUP_SHOWN ~= nil end,
    button1 = StaticPopup1Button1,
}
setmetatable(StaticPopup1, { __index = function(_, key)
    return key == "which" and POPUP_SHOWN or nil
end })

C_TradeSkillUI = C_TradeSkillUI or {}
C_TradeSkillUI.GetChildProfessionInfo = function()
    return { professionID = OPEN_SKILL_LINE_ID }
end
C_TradeSkillUI.OpenTradeSkill = function(skillLineID)
    OPEN_SKILL_LINE_ID = skillLineID
end

ProfessionsFrame = {
    specializationsTabID = 2,
    IsVisible = function()
        return OPEN_SKILL_LINE_ID ~= nil
    end,
    SetTab = function()
        SPEC_PAGE_VISIBLE = true
    end,
}

--------------------------------------------------------------------------------
-- Pont du tracker
--------------------------------------------------------------------------------

RANDOM_FILL_ENABLED = false

ALCH_ROW = { skillLineID = SKILL_LINE_ID, config = { label = "Alch" } }
OTHER_ROW = { skillLineID = OTHER_SKILL_LINE_ID, config = { label = "Inscr" } }
TRACKED_ROWS = { ALCH_ROW }

_G.YayaWeeklyTrackerSpecPlan = {
    GetTrackedProfessionRows = function()
        return TRACKED_ROWS
    end,
    IsEnabled = function()
        return true
    end,
    IsRandomFillEnabled = function()
        return RANDOM_FILL_ENABLED == true
    end,
    RequestTrackerRefresh = function() end,
    DebugLog = function() end,
    Say = function() end,
}

dofile("YayaWeeklyTrackerSpecPlan.lua")

local specPlan = _G.YayaWeeklyTrackerSpecPlan

--------------------------------------------------------------------------------

local failures = 0
local checks = 0

local function Check(label, condition, detail)
    checks = checks + 1
    if condition then
        print("  OK    " .. label)
    else
        failures = failures + 1
        print("  ECHEC " .. label .. (detail and (" :: " .. tostring(detail)) or ""))
    end
end

--- Remet le monde a l'etat « fenetre fermee, rien de depense ».
local function Reset(plan)
    ResetRanks()
    KNOWLEDGE_AVAILABLE = 20
    KNOWLEDGE_BY_SKILL = {}
    STAGED_CHANGES = false
    TRACKED_ROWS = { ALCH_ROW }
    SPEC_PAGE_VISIBLE = false
    SELECTED_TREE_ID = nil
    DISPLAYED_ROOT_ID = nil
    OPEN_SKILL_LINE_ID = nil
    lastPurchase = nil
    TAB_STATES = { [100] = Enum.ProfessionsSpecTabState.Unlocked,
        [200] = Enum.ProfessionsSpecTabState.Unlocked,
        [300] = Enum.ProfessionsSpecTabState.Unlocked }
    APPLY_ENABLED = true
    APPLY_CLICKS = 0
    PREVIEW_SHOWN = false
    PREVIEW_CLICKS = 0
    POPUP_SHOWN = nil
    POPUP_CLICKS = 0
    RANDOM_FILL_ENABLED = false
    specPlan.SetRandomSource(nil)
    specPlan.SetPlanForSkillLine(SKILL_LINE_ID, plan)
    specPlan.SetPlanForSkillLine(OTHER_SKILL_LINE_ID, nil)
end

--- Faux bouton du tracker : il enregistre l'action securisee qu'on lui arme,
-- puis la declenche comme le moteur securise du client le ferait au meme clic.
local function FakeButton()
    local attributes = {}
    return {
        SetAttribute = function(_, key, value) attributes[key] = value end,
        GetAttribute = function(_, key) return attributes[key] end,
        Fire = function()
            if attributes.type == "click" and attributes.clickbutton then
                attributes.clickbutton.Click()
                return true
            end
            -- Le moteur securise du client execute la macro : on n'en simule
            -- que la forme utilisee ici, `/click <nom global>`.
            if attributes.type == "macro" and attributes.macrotext then
                local name = tostring(attributes.macrotext):match("^/click%s+(%S+)$")
                local widget = name and _G[name]
                if widget and type(widget.Click) == "function" then
                    widget.Click()
                    return true
                end
            end
            return false
        end,
    }
end

--- Amene la fenetre a l'etat « prete a acheter », en passant par chaque etape.
local function OpenUpTo(treeID)
    OPEN_SKILL_LINE_ID = SKILL_LINE_ID
    SPEC_PAGE_VISIBLE = true
    SELECTED_TREE_ID = treeID
end

--------------------------------------------------------------------------------
print("\nResolution du plan")
--------------------------------------------------------------------------------

Reset({ steps = {
    { path = 12, rank = 20, name = "Feuille" },
    { path = 11, rank = 10, name = "Milieu" },
} })

local target = specPlan.ResolvePlanTarget(SKILL_LINE_ID)
Check("une cible est resolue", target ~= nil)
Check("c'est la PREMIERE etape du plan, pas la plus en retard",
    target and target.pathID == 12, target and target.pathID)
Check("le rang vise est celui du plan", target and target.targetRank == 20)
Check("l'onglet est deduit de l'arbre", target and target.treeID == 100, target and target.treeID)

RANKS[12] = 20
target = specPlan.ResolvePlanTarget(SKILL_LINE_ID)
Check("etape satisfaite : on passe a la suivante",
    target and target.pathID == 11, target and target.pathID)

RANKS[11] = 10
Check("plan termine : plus de cible", specPlan.ResolvePlanTarget(SKILL_LINE_ID) == nil)

Reset({ steps = { { path = 12, rank = 999, name = "Trop haut" } } })
target = specPlan.ResolvePlanTarget(SKILL_LINE_ID)
Check("un rang au-dessus du maximum est ramene au maximum",
    target and target.targetRank == MAX_RANKS[12], target and target.targetRank)

Reset({ steps = { { path = 4242, rank = 5, name = "Inconnu" } } })
local unknownTarget, unknownReason = specPlan.ResolvePlanTarget(SKILL_LINE_ID)
Check("un noeud illisible arrete la resolution au lieu de sauter l'etape",
    unknownTarget == nil and unknownReason == "rank-unavailable", unknownReason)

--------------------------------------------------------------------------------
print("\nSequence d'etapes")
--------------------------------------------------------------------------------

Reset({ steps = { { path = 12, rank = 20, name = "Feuille" } } })

local action = specPlan.GetNextAction()
Check("fenetre fermee : ouvrir le metier", action and action.kind == "open-profession",
    action and action.kind)

specPlan.Step()
action = specPlan.GetNextAction()
Check("metier ouvert : ouvrir l'onglet Specialisations",
    action and action.kind == "open-spec-tab", action and action.kind)

specPlan.Step()
action = specPlan.GetNextAction()
Check("onglet ouvert mais mauvais arbre : selectionner l'arbre",
    action and action.kind == "select-tree", action and action.kind)

specPlan.Step()
Check("l'arbre selectionne est celui du noeud", SELECTED_TREE_ID == 100, SELECTED_TREE_ID)
action = specPlan.GetNextAction()
Check("tout est en place : acheter", action and action.kind == "purchase", action and action.kind)

specPlan.Step()
Check("le moteur recoit le noeud du plan", lastPurchase and lastPurchase.nodeID == 12,
    lastPurchase and lastPurchase.nodeID)

--------------------------------------------------------------------------------
print("\nPalier : ne jamais depasser la cible")
--------------------------------------------------------------------------------

--- Rang que le moteur atteindrait avec le pas demande, arrondi comme le fait
-- GetProfessionSpecPurchaseGoal de YayaQueue.
local function GoalFor(currentRank, targetRank, stepSize)
    return math.min(targetRank, (math.floor(currentRank / stepSize) + 1) * stepSize)
end

local function PurchaseWith(currentRank, targetRank)
    Reset({ steps = { { path = 12, rank = targetRank, name = "Feuille" } } })
    RANKS[12] = currentRank
    OpenUpTo(100)
    specPlan.Step()
    return lastPurchase and lastPurchase.stepSize
end

local cases = {
    { current = 0, target = 20 },
    { current = 5, target = 12 },
    { current = 10, target = 12 },
    { current = 10, target = 11 },
    { current = 3, target = 20 },
    { current = 19, target = 20 },
}

for _, case in ipairs(cases) do
    local stepSize = PurchaseWith(case.current, case.target)
    local goal = stepSize and GoalFor(case.current, case.target, stepSize)
    Check(
        ("%d -> %d : le palier ne depasse pas la cible"):format(case.current, case.target),
        goal ~= nil and goal <= case.target,
        ("pas=%s atteint=%s"):format(tostring(stepSize), tostring(goal))
    )
    -- Un clic mene a la cible, comme Alt+Shift : plus de montee cinq par cinq.
    Check(
        ("%d -> %d : un seul clic atteint la cible"):format(case.current, case.target),
        goal == case.target,
        ("pas=%s atteint=%s"):format(tostring(stepSize), tostring(goal))
    )
end

--------------------------------------------------------------------------------
print("\nGardes")
--------------------------------------------------------------------------------

Reset({ steps = { { path = 12, rank = 20, name = "Feuille" } } })
KNOWLEDGE_AVAILABLE = 0
Check("aucun point disponible : aucune action", specPlan.GetNextAction() == nil)

-- Regression : l'application etait prioritaire, donc le plan s'arretait des le
-- premier achat en attente et une application qui echouait le figeait pour de
-- bon. Les rangs en attente s'empilent sans se gener : on deroule d'abord.
Reset({ steps = { { path = 12, rank = 20, name = "Feuille" } } })
OpenUpTo(100)
STAGED_CHANGES = true
action = specPlan.GetNextAction()
Check("un lot en attente ne bloque PAS un achat encore possible",
    action and action.kind == "purchase", action and action.kind)

RANKS[12] = 20
action = specPlan.GetNextAction()
Check("plan deroule et lot en attente : appliquer",
    action and action.kind == "apply", action and action.kind)

STAGED_CHANGES = false
Check("plan deroule et rien en attente : plus rien a faire",
    specPlan.GetNextAction() == nil)

-- Regression : pendant un achat, le bouton disparaissait. La pile se decalait
-- d'un cran sous le raccourci, et rien ne garantissait qu'un rafraichissement
-- revienne une fois l'operation finie -- le bouton restait absent, plan en cours.
Reset({ steps = { { path = 12, rank = 20, name = "Feuille" } } })
OpenUpTo(100)
local savedBusy = YayaQueueAPI.IsProfessionSpecBusy
YayaQueueAPI.IsProfessionSpecBusy = function() return true end
action = specPlan.GetNextAction()
Check("achat en vol : le bouton ne disparait pas",
    action and action.kind == "busy", action and action.kind)
buttonState = specPlan.BuildButtonState()
Check("il reste visible mais grise",
    buttonState ~= nil and buttonState.enabled == false)
YayaQueueAPI.IsProfessionSpecBusy = savedBusy

Reset(nil)
Check("metier sans plan : aucune action", specPlan.GetNextAction() == nil)
Check("metier sans plan : aucun bouton", specPlan.BuildButtonState() == nil)

Reset({ steps = { { path = 12, rank = 20, name = "Feuille" } } })
specPlan.IsEnabled = function() return false end
Check("reglage desactive : aucune action", specPlan.GetNextAction() == nil)
specPlan.IsEnabled = function() return true end

local savedQueue = YayaQueueAPI
YayaQueueAPI = nil
Check("YayaQueue absent : aucune action", specPlan.GetNextAction() == nil)
YayaQueueAPI = savedQueue

--------------------------------------------------------------------------------
print("\nEtape a rank = 0 : apprendre sans depenser")
--------------------------------------------------------------------------------

Reset({ steps = {
    { path = 11, rank = 0, name = "Milieu" },
    { path = 12, rank = 20, name = "Feuille" },
} })

target = specPlan.ResolvePlanTarget(SKILL_LINE_ID)
Check("noeud verrouille : l'etape a rank 0 n'est PAS satisfaite",
    target and target.pathID == 11, target and target.pathID)
Check("l'etape est marquee deblocage seul", target and target.unlockOnly == true)

OpenUpTo(100)
specPlan.Step()
Check("le moteur recoit un pas NON NUL, sinon il remplirait le noeud au maximum",
    lastPurchase and lastPurchase.stepSize > 0, lastPurchase and lastPurchase.stepSize)

UNLOCKED[11] = true
target = specPlan.ResolvePlanTarget(SKILL_LINE_ID)
Check("noeud appris a rang 0 : l'etape est satisfaite, on passe a la suivante",
    target and target.pathID == 12, target and target.pathID)

RANKS[11] = 7
UNLOCKED[11] = false
target = specPlan.ResolvePlanTarget(SKILL_LINE_ID)
Check("un rang non nul ne vaut pas apprentissage : c'est l'etat qui tranche",
    target and target.pathID == 11, target and target.pathID)

--------------------------------------------------------------------------------
print("\nPage verrouillee par le niveau de metier")
--------------------------------------------------------------------------------

Reset({ steps = {
    { path = 12, rank = 20, name = "Feuille page 1" },
    { path = 20, rank = 10, name = "Racine page 2" },
} })
TAB_STATES[200] = Enum.ProfessionsSpecTabState.Locked

RANKS[12] = 20
local skippedTarget, skippedReason, skippedStep = specPlan.ResolvePlanTarget(SKILL_LINE_ID)
Check("etape 1 faite, etape 2 sur page verrouillee : aucune cible",
    skippedTarget == nil and skippedReason == "tab-locked", skippedReason)
Check("l'etape sautee est nommee",
    skippedStep and skippedStep.stepIndex == 2, skippedStep and skippedStep.stepIndex)
Check("rien de depensable tant que la page est fermee",
    specPlan.HasSpendableWork(SKILL_LINE_ID) == false)

RANKS[12] = 5
local resumed = specPlan.ResolvePlanTarget(SKILL_LINE_ID)
Check("une etape faisable APRES la sautee reste prise dans l'ordre",
    resumed and resumed.pathID == 12, resumed and resumed.pathID)

RANKS[12] = 20
TAB_STATES[200] = Enum.ProfessionsSpecTabState.Unlocked
resumed = specPlan.ResolvePlanTarget(SKILL_LINE_ID)
Check("page ouverte : l'etape sautee reprend sa place",
    resumed and resumed.pathID == 20, resumed and resumed.pathID)

--------------------------------------------------------------------------------
print("\nPage achetable : la confirmation Blizzard")
--------------------------------------------------------------------------------

Reset({ steps = { { path = 20, rank = 10, name = "Racine page 2" } } })
TAB_STATES[200] = Enum.ProfessionsSpecTabState.Unlockable
OpenUpTo(200)

action = specPlan.GetNextAction()
Check("page achetable : l'action est le deblocage de page",
    action and action.kind == "unlock-tab", action and action.kind)
Check("elle vise la RACINE de la page, seule cible qui ouvre la confirmation",
    action and action.target and action.target.rootPathID == 20,
    action and action.target and action.target.rootPathID)

specPlan.Step()
Check("le moteur recoit la racine", lastPurchase and lastPurchase.nodeID == 20,
    lastPurchase and lastPurchase.nodeID)

TAB_STATES[200] = Enum.ProfessionsSpecTabState.Unlocked
action = specPlan.GetNextAction()
Check("page debloquee : on passe a l'achat", action and action.kind == "purchase",
    action and action.kind)

--------------------------------------------------------------------------------
print("\nAlerte KP")
--------------------------------------------------------------------------------

Reset({ steps = { { path = 12, rank = 20, name = "Feuille" } } })
Check("plan en cours : il reste a depenser",
    specPlan.HasSpendableWork(SKILL_LINE_ID) == true)

RANKS[12] = 20
Check("plan termine : plus rien a depenser",
    specPlan.HasSpendableWork(SKILL_LINE_ID) == false)

Reset(nil)
Check("metier sans plan : ni oui ni non, le tracker garde son alerte",
    specPlan.HasSpendableWork(SKILL_LINE_ID) == nil)

Reset({ steps = { { path = 4242, rank = 5, name = "Inconnu" } } })
Check("arbre illisible : ni oui ni non, ne pas eteindre un rappel sur une inconnue",
    specPlan.HasSpendableWork(SKILL_LINE_ID) == nil)

--------------------------------------------------------------------------------
print("\nClics securises : appliquer et confirmer")
--------------------------------------------------------------------------------

Reset({ steps = { { path = 12, rank = 20, name = "Feuille" } } })
RANKS[12] = 20
OpenUpTo(100)
STAGED_CHANGES = true

local applyButtonWidget = FakeButton()
Check("l'etape appliquer arme un clic securise", specPlan.Step(applyButtonWidget) == true)
Check("elle vise le bouton Appliquer du jeu, jamais un appel direct",
    applyButtonWidget:GetAttribute("type") == "click"
        and applyButtonWidget:GetAttribute("clickbutton") == SPEC_FRAME.ApplyButton)
applyButtonWidget.Fire()
Check("le clic atteint le bouton natif", APPLY_CLICKS == 1, APPLY_CLICKS)

APPLY_ENABLED = false
buttonState = specPlan.BuildButtonState()
Check("bouton natif desactive : l'etape se grise au lieu de mentir",
    buttonState and buttonState.enabled == false)
Check("et l'infobulle dit d'utiliser le bouton du jeu",
    buttonState and table.concat(buttonState.tooltip, " "):find("Appliquer", 1, true) ~= nil)

-- Un bouton eteint est un etat ABSORBANT : c'est le clic qui demande le
-- rafraichissement suivant, et un bouton desactive n'en recoit plus. Sans ce
-- reveil, le bouton restait gris alors que le jeu etait redevenu pret -- le
-- blocage observe en jeu, que n'importe quelle commande /ywt levait.
local refreshCalls = 0
specPlan.RequestTrackerRefresh = function() refreshCalls = refreshCalls + 1 end
RunTimers(3)
PENDING_TIMERS = {}
buttonState = specPlan.BuildButtonState()
Check("etat eteint : un reveil est arme",
    buttonState ~= nil and buttonState.enabled == false
        and #(PENDING_TIMERS or {}) > 0,
    #(PENDING_TIMERS or {}))
refreshCalls = 0
RunTimers(1)
Check("le reveil redemande un rafraichissement", refreshCalls > 0, refreshCalls)

-- Une cible absente DESARME, elle ne se contente pas d'echouer. Sans cela le
-- clic materiel qui suit rejouait la derniere action armee : l'addon annoncait
-- « indisponible » et le clic repartait quand meme vers le bouton Appliquer.
APPLY_CLICKS = 0
Check("bouton natif indisponible : l'armement echoue",
    specPlan.Step(applyButtonWidget) == false)
applyButtonWidget.Fire()
Check("et l'action precedente n'est PAS rejouee", APPLY_CLICKS == 0, APPLY_CLICKS)
APPLY_ENABLED = true

-- La fenetre de confirmation bloque le moteur (`AnyPopupShown`) : tant qu'elle
-- est ouverte, rien d'autre ne peut avancer, donc elle passe avant tout.
Reset({ steps = { { path = 12, rank = 20, name = "Feuille" } } })
OpenUpTo(100)
POPUP_SHOWN = "PROFESSIONS_SPECIALIZATION_CONFIRM_PURCHASE_TAB"
action = specPlan.GetNextAction()
Check("une confirmation ouverte passe avant l'achat",
    action and action.kind == "confirm-popup", action and action.kind)

local popupWidget = FakeButton()
Check("l'etape confirmer arme une action securisee", specPlan.Step(popupWidget) == true)
Check("c'est la macro que le joueur taperait, pas une reference de frame",
    popupWidget:GetAttribute("type") == "macro"
        and popupWidget:GetAttribute("macrotext") == "/click StaticPopup1Button1",
    popupWidget:GetAttribute("macrotext"))
popupWidget.Fire()
Check("le clic atteint le bouton de la fenetre", POPUP_CLICKS == 1, POPUP_CLICKS)

POPUP_SHOWN = "SOME_OTHER_DIALOG"
action = specPlan.GetNextAction()
Check("une fenetre etrangere n'est jamais cliquee",
    action and action.kind ~= "confirm-popup", action and action.kind)
POPUP_SHOWN = nil

--------------------------------------------------------------------------------
print("\nPage fraichement debloquee : l'arbre charge fait foi")
--------------------------------------------------------------------------------
-- Deux oracles disent ou l'on se trouve, et ils divergent. `GetTalentTreeID`
-- rend l'onglet CHOISI ; `GetRootNodeID` rend l'arbre CHARGE, et c'est de lui
-- que part le DFS du moteur d'achat. Au deblocage d'une page, l'onglet prend le
-- nouveau treeID avant que la frame n'ait recharge son arbre : le module se
-- croyait arrive et chaque achat repartait sur `invalid-context`.

Reset({ steps = { { path = 12, rank = 20, name = "Feuille" } } })
OpenUpTo(100)

action = specPlan.GetNextAction()
Check("les deux oracles d'accord : on achete",
    action and action.kind == "purchase", action and action.kind)

DISPLAYED_ROOT_ID = 20
action = specPlan.GetNextAction()
Check("arbre charge reste sur l'ancienne page : une navigation s'intercale",
    action and action.kind == "select-tree", action and action.kind)

-- Le faux moteur rend `true` sans rien faire quand l'onglet est deja le bon --
-- comme le vrai. C'est donc la frame elle-meme qu'il faut redemander.
local navWidget = FakeButton()
specPlan.Step(navWidget)
Check("le clic recharge la page au lieu de se croire arrive",
    DISPLAYED_ROOT_ID == nil, tostring(DISPLAYED_ROOT_ID))
action = specPlan.GetNextAction()
Check("puis l'achat reprend", action and action.kind == "purchase",
    action and action.kind)

-- Garde anti-boucle : si le client ne recharge jamais, le plan ne doit pas
-- rester coince sur sa navigation. Au bout de quelques tentatives, l'achat
-- tente sa chance -- figer ici serait pire que de laisser le moteur refuser.
Reset({ steps = { { path = 12, rank = 20, name = "Feuille" } } })
OpenUpTo(100)
local stubbornSetTab = SPEC_FRAME.SetSelectedTab
SPEC_FRAME.SetSelectedTab = function() end
DISPLAYED_ROOT_ID = 20
local kinds = {}
for _ = 1, 5 do
    local nextAction = specPlan.GetNextAction()
    kinds[#kinds + 1] = nextAction and nextAction.kind or "nil"
    specPlan.Step(FakeButton())
end
SPEC_FRAME.SetSelectedTab = stubbornSetTab
DISPLAYED_ROOT_ID = nil
Check("le plan ne boucle pas indefiniment sur la navigation",
    kinds[#kinds] == "purchase", table.concat(kinds, ">"))

--------------------------------------------------------------------------------
print("\nOuverture du metier")
--------------------------------------------------------------------------------

local OPEN_CALLS = {}
C_TradeSkillUI.OpenTradeSkill = function(id)
    OPEN_CALLS[#OPEN_CALLS + 1] = id
    -- Le client ignore la ligne d'extension tant que ses donnees ne sont pas
    -- chargees : c'est exactement la panne observee en jeu.
    if id ~= SKILL_LINE_ID then
        OPEN_SKILL_LINE_ID = id
    end
end
C_TradeSkillUI.GetProfessionInfoBySkillLineID = function(id)
    return id == SKILL_LINE_ID and { parentProfessionID = 171 } or nil
end

Reset({ steps = { { path = 12, rank = 20, name = "Feuille" } } })
specPlan.Step()
Check("premiere tentative : la ligne d'extension", OPEN_CALLS[1] == SKILL_LINE_ID, OPEN_CALLS[1])
specPlan.Step()
Check("restee sans effet, la seconde retombe sur le metier de base",
    OPEN_CALLS[2] == 171, OPEN_CALLS[2])

--------------------------------------------------------------------------------
print("\nLibelle du bouton")
--------------------------------------------------------------------------------

Reset({ steps = { { path = 12, rank = 20, name = "Feuille" } } })
RANKS[12] = 5
OpenUpTo(100)
buttonState = specPlan.BuildButtonState()
Check("le bouton est actif", buttonState ~= nil and buttonState.enabled == true)
Check("le libelle nomme le metier et le noeud",
    buttonState and buttonState.label:find("Alch", 1, true) ~= nil
        and buttonState.label:find("Feuille", 1, true) ~= nil,
    buttonState and buttonState.label)
Check("le libelle porte la progression",
    buttonState and buttonState.label:find("5/20", 1, true) ~= nil,
    buttonState and buttonState.label)
Check("l'infobulle annonce le rang vise par CE clic",
    buttonState and #buttonState.tooltip >= 3)

--------------------------------------------------------------------------------
-- Remplissage libre, une fois le plan termine
--
-- L'arbre du harnais : page 100 racine 10 (max 30) -> 11 (max 26) -> 12 (max 20),
-- page 200 racine 20 (max 15). Apres un Reset, seul 10 est appris et tout est a
-- zero, donc les quatre noeuds sont candidats, tries par pathID croissant :
-- {10, 11, 12, 20}.
--------------------------------------------------------------------------------

print("")
print("Remplissage libre, une fois le plan termine")

-- Un plan d'une seule etape deja satisfaite : le noeud 10 est appris, donc une
-- etape `rank = 0` dessus ne demande plus rien.
local FINISHED_PLAN = { steps = { { path = 10, rank = 0, name = "Racine" } } }

local pickCalls = 0
local pickIndex = 1
local function CountingSource(count)
    pickCalls = pickCalls + 1
    -- Rend un index qui CHANGE a chaque appel : si la cible etait retiree a
    -- chaque passe, les tests de stabilite le verraient immediatement.
    pickIndex = pickIndex % count + 1
    return pickIndex
end

Reset(FINISHED_PLAN)
Check("plan termine, option eteinte : rien a faire, comme avant",
    specPlan.ResolvePlanTarget(SKILL_LINE_ID) == nil)
Check("et l'alerte KP s'eteint", specPlan.HasSpendableWork(SKILL_LINE_ID) == false)

Reset(FINISHED_PLAN)
specPlan.IsRandomFillEnabled = nil
Check("le reglage absent vaut ETEINT, a l'inverse de IsEnabled",
    specPlan.ResolvePlanTarget(SKILL_LINE_ID) == nil)
specPlan.IsRandomFillEnabled = function()
    return RANDOM_FILL_ENABLED == true
end

Reset(FINISHED_PLAN)
RANDOM_FILL_ENABLED = true
specPlan.SetRandomSource(CountingSource)
pickCalls = 0
RANKS[11] = 5
UNLOCKED[11] = true
local fill = specPlan.ResolvePlanTarget(SKILL_LINE_ID)
Check("plan termine : un noeud entame devient la cible",
    fill ~= nil and fill.pathID == 11, fill and fill.pathID)
Check("il est mene a son maximum, pas a un palier intermediaire",
    fill ~= nil and fill.targetRank == 26, fill and fill.targetRank)
Check("la cible se declare hors plan", fill ~= nil and fill.randomFill == true)
Check("finir un noeud entame ne consulte JAMAIS le tirage", pickCalls == 0)
Check("et l'alerte KP reste allumee", specPlan.HasSpendableWork(SKILL_LINE_ID) == true)

RANKS[12] = 3
UNLOCKED[12] = true
fill = specPlan.ResolvePlanTarget(SKILL_LINE_ID)
Check("deux noeuds entames : le plus petit pathID gagne, sans hasard",
    fill ~= nil and fill.pathID == 11, fill and fill.pathID)

Reset(FINISHED_PLAN)
RANDOM_FILL_ENABLED = true
specPlan.SetRandomSource(CountingSource)
pickCalls = 0
fill = specPlan.ResolvePlanTarget(SKILL_LINE_ID)
local firstPick = fill and fill.pathID
local againPick = specPlan.ResolvePlanTarget(SKILL_LINE_ID)
Check("aucun noeud entame : un vierge est tire au sort", firstPick ~= nil)
Check("le tirage ne rejoue pas d'une passe a l'autre",
    againPick ~= nil and againPick.pathID == firstPick,
    tostring(firstPick) .. " puis " .. tostring(againPick and againPick.pathID))
Check("la source n'a ete consultee qu'une fois", pickCalls == 1, pickCalls)

-- Le noeud tire est mene a son maximum : il quitte alors la liste, et seulement
-- la un nouveau tirage a lieu.
RANKS[firstPick] = MAX_RANKS[firstPick]
UNLOCKED[firstPick] = true
fill = specPlan.ResolvePlanTarget(SKILL_LINE_ID)
Check("le noeud tire complete, un autre est tire",
    fill ~= nil and fill.pathID ~= firstPick, fill and fill.pathID)
Check("et la source a ete reconsultee", pickCalls == 2, pickCalls)

Reset(FINISHED_PLAN)
RANDOM_FILL_ENABLED = true
specPlan.SetRandomSource(function() return 2 end)
fill = specPlan.ResolvePlanTarget(SKILL_LINE_ID)
Check("un noeud encore verrouille est tire comme les autres",
    fill ~= nil and fill.pathID == 11, fill and fill.pathID)
Check("mais il s'annonce comme un deblocage, pas comme un rang",
    fill ~= nil and fill.unlockOnly == true)
Check("son nom retombe sur le pathID quand l'arbre ne le nomme pas",
    fill ~= nil and fill.step.name == "path 11", fill and fill.step.name)

Reset(FINISHED_PLAN)
RANDOM_FILL_ENABLED = true
TAB_STATES[200] = Enum.ProfessionsSpecTabState.Locked
specPlan.SetRandomSource(function() return 4 end)
fill = specPlan.ResolvePlanTarget(SKILL_LINE_ID)
Check("une page verrouillee par le niveau ne fournit aucun candidat",
    fill ~= nil and fill.pathID ~= 20, fill and fill.pathID)

Reset(FINISHED_PLAN)
RANDOM_FILL_ENABLED = true
TAB_STATES[200] = Enum.ProfessionsSpecTabState.Unlockable
specPlan.SetRandomSource(function() return 1 end)
fill = specPlan.ResolvePlanTarget(SKILL_LINE_ID)
Check("une page seulement achetable attend que les pages payees soient pleines",
    fill ~= nil and fill.pathID ~= 20, fill and fill.pathID)

RANKS[10], RANKS[11], RANKS[12] = 30, 26, 20
UNLOCKED[11], UNLOCKED[12] = true, true
fill = specPlan.ResolvePlanTarget(SKILL_LINE_ID)
Check("page payee pleine : la cible devient la RACINE de la page achetable",
    fill ~= nil and fill.pathID == 20, fill and fill.pathID)
Check("visee en deblocage, seule cible qui ouvre la fenetre de Blizzard",
    fill ~= nil and fill.unlockOnly == true)

Reset(FINISHED_PLAN)
RANDOM_FILL_ENABLED = true
RANKS[10], RANKS[11], RANKS[12], RANKS[20] = 30, 26, 20, 15
Check("arbre entierement plein : plus rien a faire",
    specPlan.ResolvePlanTarget(SKILL_LINE_ID) == nil)
Check("et l'alerte KP s'eteint pour de bon",
    specPlan.HasSpendableWork(SKILL_LINE_ID) == false)

-- Une etape SAUTEE n'ouvre pas le repli : la page verrouillee finira par
-- s'ouvrir, et les points qu'elle attend ne doivent pas partir ailleurs.
Reset({ steps = { { path = 20, rank = 10, name = "Autre page" } } })
RANDOM_FILL_ENABLED = true
TAB_STATES[200] = Enum.ProfessionsSpecTabState.Locked
local skippedTarget, skippedReason = specPlan.ResolvePlanTarget(SKILL_LINE_ID)
Check("etape sautee faute de page ouverte : pas de remplissage libre",
    skippedTarget == nil and skippedReason == "tab-locked", tostring(skippedReason))

-- Le plan reste la loi : une etape encore ouverte passe devant le repli.
Reset({ steps = { { path = 12, rank = 20, name = "Feuille" } } })
RANDOM_FILL_ENABLED = true
RANKS[11] = 5
UNLOCKED[11] = true
fill = specPlan.ResolvePlanTarget(SKILL_LINE_ID)
Check("une etape de plan encore ouverte passe avant le remplissage libre",
    fill ~= nil and fill.pathID == 12 and fill.randomFill == nil,
    fill and fill.pathID)

-- Le clic : un seul pas mene le noeud entame a son maximum.
Reset(FINISHED_PLAN)
RANDOM_FILL_ENABLED = true
RANKS[11] = 5
UNLOCKED[11] = true
OpenUpTo(100)
buttonState = specPlan.BuildButtonState()
Check("le bouton reste affiche apres la fin du plan",
    buttonState ~= nil and buttonState.enabled == true)
Check("son infobulle dit que le plan est derriere, sans etape numerotee",
    buttonState ~= nil
        and buttonState.tooltip[1]:find("Remplissage libre", 1, true) ~= nil
        and buttonState.tooltip[1]:find("tape ", 1, true) == nil,
    buttonState and buttonState.tooltip[1])
specPlan.Step(FakeButton())
Check("le clic vise bien le noeud a finir",
    lastPurchase ~= nil and lastPurchase.nodeID == 11,
    lastPurchase and lastPurchase.nodeID)
Check("et le pas demande est le maximum du noeud, sans le depasser",
    lastPurchase ~= nil and GoalFor(5, 26, lastPurchase.stepSize) == 26,
    lastPurchase and lastPurchase.stepSize)

--------------------------------------------------------------------------------
print("\nApercu de page : la presentation qui cache le bouton Appliquer")
--------------------------------------------------------------------------------

-- Le deblocage d'une page marchait, la suite non : on restait sur la page de
-- presentation, ou Blizzard CACHE son bouton « Appliquer » au lieu de le griser,
-- et le plan s'arretait la pour de bon.

Reset({ steps = { { path = 20, rank = 10, name = "Racine 200" } } })
TAB_STATES[200] = Enum.ProfessionsSpecTabState.Unlockable
OPEN_SKILL_LINE_ID = SKILL_LINE_ID
SPEC_PAGE_VISIBLE = true

action = specPlan.GetNextAction()
Check("page verrouillee : on commence par la selectionner",
    action and action.kind == "select-tree", action and action.kind)
specPlan.Step(FakeButton())
Check("la selection d'une page verrouillee ouvre l'apercu, comme en jeu",
    PREVIEW_SHOWN == true)

action = specPlan.GetNextAction()
Check("puis on debloque la page", action and action.kind == "unlock-tab",
    action and action.kind)
specPlan.Step(FakeButton())
TAB_STATES[200] = Enum.ProfessionsSpecTabState.Unlocked
STAGED_CHANGES = true
Check("le deblocage ne referme PAS l'apercu", PREVIEW_SHOWN == true)

action = specPlan.GetNextAction()
Check("l'etape suivante est donc de revenir a l'arbre, pas d'acheter a l'aveugle",
    action and action.kind == "close-preview", action and action.kind)

local previewWidget = FakeButton()
Check("elle arme un clic securise", specPlan.Step(previewWidget) == true)
Check("vers le bouton « voir l'arbre complet » du jeu",
    previewWidget:GetAttribute("type") == "click"
        and previewWidget:GetAttribute("clickbutton") == SPEC_FRAME.BackToFullTreeButton)
previewWidget.Fire()
Check("le clic referme l'apercu", PREVIEW_CLICKS == 1 and PREVIEW_SHOWN == false,
    PREVIEW_CLICKS)

action = specPlan.GetNextAction()
Check("l'arbre revenu, l'achat reprend", action and action.kind == "purchase",
    action and action.kind)

-- Et la garde tient aussi devant l'application finale : un plan termine dont
-- l'apercu serait reste ouvert n'a pas de bouton « Appliquer » a cliquer.
Reset({ steps = { { path = 12, rank = 20, name = "Feuille" } } })
RANKS[12] = 20
OpenUpTo(100)
STAGED_CHANGES = true
PREVIEW_SHOWN = true

action = specPlan.GetNextAction()
Check("apercu ouvert : on le referme avant d'appliquer",
    action and action.kind == "close-preview", action and action.kind)
local finalWidget = FakeButton()
specPlan.Step(finalWidget)
finalWidget.Fire()
action = specPlan.GetNextAction()
Check("apercu referme : l'application redevient l'etape courante",
    action and action.kind == "apply", action and action.kind)

--------------------------------------------------------------------------------
print("\nDeux metiers : appliquer avant de changer de metier")
--------------------------------------------------------------------------------

-- Regression : avec deux metiers a servir, le plan du premier se deroulait --
-- rangs mis en attente, jamais commites -- puis, plus aucun achat n'y etant
-- possible, le bouton proposait d'OUVRIR le second. La fenetre changeait de
-- metier et les points poses sur le premier n'etaient jamais appliques.
local OTHER_PLAN = { steps = { { path = 30, rank = 10, name = "Autre" } } }

Reset({ steps = { { path = 12, rank = 20, name = "Feuille" } } })
specPlan.SetPlanForSkillLine(OTHER_SKILL_LINE_ID, OTHER_PLAN)
TRACKED_ROWS = { ALCH_ROW, OTHER_ROW }
OpenUpTo(100)
RANKS[12] = 20
STAGED_CHANGES = true
action = specPlan.GetNextAction()
Check("plan du metier ouvert deroule, lot en attente : appliquer AVANT d'ouvrir l'autre",
    action and action.kind == "apply" and action.skillLineID == SKILL_LINE_ID,
    action and (action.kind .. " " .. tostring(action.skillLineID)))
buttonState = specPlan.BuildButtonState()
Check("le libelle nomme le metier a appliquer",
    buttonState and buttonState.label:find("Alch", 1, true) ~= nil,
    buttonState and buttonState.label)

-- Points epuises sur le metier ouvert alors que son plan n'est pas fini : c'est
-- le cas courant, et il doit aussi appliquer avant de partir.
RANKS[12] = 10
KNOWLEDGE_BY_SKILL[SKILL_LINE_ID] = 0
action = specPlan.GetNextAction()
Check("points epuises sur le metier ouvert, lot en attente : appliquer d'abord",
    action and action.kind == "apply" and action.skillLineID == SKILL_LINE_ID,
    action and action.kind)

STAGED_CHANGES = false
action = specPlan.GetNextAction()
Check("une fois applique : ouvrir le second metier",
    action and action.kind == "open-profession"
        and action.skillLineID == OTHER_SKILL_LINE_ID,
    action and (action.kind .. " " .. tostring(action.skillLineID)))

-- L'ordre des lignes du tracker ne doit rien y changer.
TRACKED_ROWS = { OTHER_ROW, ALCH_ROW }
STAGED_CHANGES = true
action = specPlan.GetNextAction()
Check("le second metier liste en premier : appliquer d'abord quand meme",
    action and action.kind == "apply" and action.skillLineID == SKILL_LINE_ID,
    action and (action.kind .. " " .. tostring(action.skillLineID)))

-- Onglet Specialisations masque avec un lot en attente : le rouvrir, le bouton
-- natif Appliquer n'existe que la.
SPEC_PAGE_VISIBLE = false
action = specPlan.GetNextAction()
Check("onglet Specialisations masque : le rouvrir avant d'appliquer",
    action and action.kind == "open-spec-tab" and action.skillLineID == SKILL_LINE_ID,
    action and (action.kind .. " " .. tostring(action.skillLineID)))
buttonState = specPlan.BuildButtonState()
Check("et l'infobulle dit pourquoi",
    buttonState and table.concat(buttonState.tooltip, " "):find("appliqu", 1, true) ~= nil,
    buttonState and table.concat(buttonState.tooltip, " | "))

-- Un achat encore possible sur le metier ouvert garde la priorite sur
-- l'application : les rangs en attente s'empilent sans se gener.
Reset({ steps = { { path = 12, rank = 20, name = "Feuille" } } })
specPlan.SetPlanForSkillLine(OTHER_SKILL_LINE_ID, OTHER_PLAN)
TRACKED_ROWS = { OTHER_ROW, ALCH_ROW }
OpenUpTo(100)
RANKS[12] = 5
STAGED_CHANGES = true
action = specPlan.GetNextAction()
Check("un achat encore possible sur le metier ouvert passe avant l'application",
    action and action.kind == "purchase" and action.skillLineID == SKILL_LINE_ID,
    action and (action.kind .. " " .. tostring(action.skillLineID)))

-- Fenetre de metier fermee : rien en attente a proteger, on ouvre le premier
-- metier servi.
Reset({ steps = { { path = 12, rank = 20, name = "Feuille" } } })
specPlan.SetPlanForSkillLine(OTHER_SKILL_LINE_ID, OTHER_PLAN)
TRACKED_ROWS = { ALCH_ROW, OTHER_ROW }
action = specPlan.GetNextAction()
Check("fenetre fermee : ouvrir le premier metier",
    action and action.kind == "open-profession" and action.skillLineID == SKILL_LINE_ID,
    action and (action.kind .. " " .. tostring(action.skillLineID)))

Reset(nil)

--------------------------------------------------------------------------------

if UNCAUGHT and #UNCAUGHT > 0 then
    for _, message in ipairs(UNCAUGHT) do
        print("  ECHEC erreur non rattrapee :: " .. message)
    end
    failures = failures + #UNCAUGHT
end

print(("%d reussite(s), %d echec(s)"):format(checks - failures, failures))
if failures > 0 then
    os.exit(1)
end
