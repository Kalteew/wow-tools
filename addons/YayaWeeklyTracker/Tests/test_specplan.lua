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

local CHILDREN = {
    [10] = { 11 },
    [11] = { 12 },
    [12] = {},
    [20] = {},
}

local MAX_RANKS = {
    [10] = 30,
    [11] = 26,
    [12] = 20,
    [20] = 15,
}

local RANKS = {}
local UNLOCKED = {}

local function ResetRanks()
    RANKS = { [10] = 0, [11] = 0, [12] = 0, [20] = 0 }
    UNLOCKED = { [10] = true }
end

ResetRanks()

Enum = Enum or {}
Enum.ProfessionsSpecPathState = { Locked = 0, Unlocked = 1, Progressing = 2, Selected = 3 }
Enum.ProfessionsSpecTabState = { Locked = 0, Unlocked = 1, Unlockable = 2 }

-- Etat de chaque page. Le second onglet sert de page verrouillee par le niveau
-- de metier : c'est celle qu'on doit savoir sauter, puis reprendre.
TAB_STATES = { [100] = Enum.ProfessionsSpecTabState.Unlocked,
    [200] = Enum.ProfessionsSpecTabState.Unlocked }

C_ProfSpecs = {
    GetConfigIDForSkillLine = function(skillLineID)
        return skillLineID == SKILL_LINE_ID and CONFIG_ID or nil
    end,
    GetSpecTabIDsForSkillLine = function(skillLineID)
        return skillLineID == SKILL_LINE_ID and { 100, 200 } or {}
    end,
    GetRootPathForTab = function(tabID)
        return tabID == 100 and 10 or (tabID == 200 and 20 or nil)
    end,
    GetChildrenForPath = function(pathID)
        return CHILDREN[pathID] or {}
    end,
    GetCurrencyInfoForSkillLine = function()
        return { numAvailable = KNOWLEDGE_AVAILABLE }
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
        SELECTED_TREE_ID = treeID
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
    end,
    GetConfigID = function() return CONFIG_ID end,
    professionInfo = setmetatable({}, {
        __index = function(_, key)
            return key == "professionID" and OPEN_SKILL_LINE_ID or nil
        end,
    }),
    UpdateConfigButtonsState = function() end,
    ApplyButton = {
        Click = function() APPLY_CLICKS = APPLY_CLICKS + 1 end,
        IsShown = function() return true end,
        IsEnabled = function() return APPLY_ENABLED end,
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

_G.YayaWeeklyTrackerSpecPlan = {
    GetTrackedProfessionRows = function()
        return { { skillLineID = SKILL_LINE_ID, config = { label = "Alch" } } }
    end,
    IsEnabled = function()
        return true
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
    STAGED_CHANGES = false
    SPEC_PAGE_VISIBLE = false
    SELECTED_TREE_ID = nil
    DISPLAYED_ROOT_ID = nil
    OPEN_SKILL_LINE_ID = nil
    lastPurchase = nil
    TAB_STATES = { [100] = Enum.ProfessionsSpecTabState.Unlocked,
        [200] = Enum.ProfessionsSpecTabState.Unlocked }
    APPLY_ENABLED = true
    APPLY_CLICKS = 0
    POPUP_SHOWN = nil
    POPUP_CLICKS = 0
    specPlan.SetPlanForSkillLine(SKILL_LINE_ID, plan)
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
