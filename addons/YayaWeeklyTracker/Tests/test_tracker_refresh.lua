-- Charge la suite Yaya complete hors du jeu, puis rejoue le cycle de
-- rafraichissement sur un personnage alchimiste equipe. Le tracker enrobe
-- UpdateTracker dans un pcall et remplace son contenu par une ligne d'erreur
-- rouge quand il echoue : cette suite echoue si ce cas se produit, car en jeu
-- l'erreur est tronquee par la largeur de la frame et passe facilement pour un
-- simple probleme d'affichage.
--
-- Ce que ce test ne couvre pas : les vraies mesures de frame, les boutons
-- securises et tout ce qui depend du client. Il attrape les erreurs de logique
-- du cycle de rafraichissement, pas les regressions visuelles.

dofile("Tests/wow_env.lua")

local ADDON_FILES = {
    "../YayaCore/YayaCore.lua",
    "../YayaCore/UI.lua",
    "../YayaCore/ActionBinding.lua",
    "../YayaFrame/YayaFrame.lua",
    "YayaWeeklyTracker.lua",
}

for _, file in ipairs(ADDON_FILES) do
    local chunk, compileError = loadfile(file)
    if not chunk then
        print("ECHEC compilation " .. file .. " :: " .. tostring(compileError))
        os.exit(2)
    end
    local name = file:match("([^/\\]+)%.lua$")
    local ok, runtimeError = pcall(chunk, name, {})
    if not ok then
        print("ECHEC chargement " .. file .. " :: " .. tostring(runtimeError))
        os.exit(3)
    end
end

-- L'etat de jeu est applique apres le chargement : il ecrase les stubs neutres
-- par des donnees exploitables (metier Midnight appris, emplacements de metier
-- garnis, sacs, YayaQueue present).
dofile("Tests/game_state.lua")

YayaWeeklyTrackerAccountDB = { debugEnabled = true }
YayaWeeklyTrackerDB = {}

FireEvent("ADDON_LOADED", "YayaCore")
FireEvent("ADDON_LOADED", "YayaFrame")
FireEvent("ADDON_LOADED", "YayaWeeklyTracker")
RunTimers(5)
FireEvent("PLAYER_ENTERING_WORLD")
RunTimers(5)
FireEvent("PLAYER_LOGIN")
RunTimers(5)

for _, event in ipairs({
    "SKILL_LINES_CHANGED",
    "SPELLS_CHANGED",
    "BAG_UPDATE_DELAYED",
    "PLAYER_EQUIPMENT_CHANGED",
    "PLAYER_AVG_ITEM_LEVEL_UPDATE",
    "TRADE_SKILL_SHOW",
    "QUEST_LOG_UPDATE",
    "BANKFRAME_OPENED",
    "BANKFRAME_CLOSED",
}) do
    FireEvent(event)
    RunTimers(3)
end

local failures = 0

local function Fail(reason)
    failures = failures + 1
    print("ECHEC :: " .. reason)
end

-- 1. Aucune erreur, ni fatale ni avalee par les pcall internes.
for _, message in ipairs(CHAT_MESSAGES or {}) do
    local clean = message:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    if clean:find("%.lua:%d") or clean:lower():find("attempt to") then
        Fail("erreur pendant le rafraichissement :: " .. clean)
    end
end
for _, entry in ipairs(UNCAUGHT or {}) do
    Fail("erreur non capturee :: " .. entry)
end
for _, entry in ipairs((YayaWeeklyTrackerAccountDB or {}).debugLog or {}) do
    if entry:find("YWT FATAL", 1, true) then
        Fail("diagnostic fatal journalise :: " .. entry)
    end
end

-- 2. Le scan de l'equipement de metier a bien tourne et rendu un verdict.
local gearTrace
for _, entry in ipairs((YayaWeeklyTrackerAccountDB or {}).debugLog or {}) do
    if entry:find("gear%[2906%]") then
        gearTrace = entry
    end
end
if not gearTrace then
    Fail("aucune trace de scan d'equipement de metier : le test ne couvre plus rien")
else
    -- L'etat de jeu equipe un outil conforme, un accessoire sous le seuil et
    -- laisse le second emplacement d'accessoire vide.
    if not gearTrace:find("bad=2") then
        Fail("comptage d'emplacements inattendu :: " .. gearTrace)
    end
    if not gearTrace:find("tool=true") then
        Fail("un outil conforme est possede mais n'est pas reconnu :: " .. gearTrace)
    end
    -- L'exemplaire Multicrafting dort en sac a l'ilvl 206 : possede, donc vu,
    -- mais sous le seuil, donc l'achat reste a faire.
    if not gearTrace:find("mcOwned=true") then
        Fail("l'outil Multicrafting en sac n'est pas vu :: " .. gearTrace)
    end
    if not gearTrace:find("mcOk=false") then
        Fail("un outil Multicrafting ilvl 206 passe pour conforme :: " .. gearTrace)
    end
    -- Cet exemplaire sortant est ecarte de la comptabilite des enchantements,
    -- et aucune action ne propose de l enchanter : sur deux outils possedes,
    -- un seul est compte nu et une seule action est offerte, celle de l outil
    -- conforme.
    if not gearTrace:find("tools=2 unench=1 wrong=0 skipped=1 apply=1", 1, true) then
        Fail("l outil sortant n est pas ecarte des enchantements :: " .. gearTrace)
    end
end

-- 3. Le plan d'achat vise bien une variante, et emmene l'enchantement avec.
--
-- L'etat de jeu porte exactement le cas qui motive tout : l'outil equipe est un
-- Resourcefulness rang maximal (rien a acheter de ce cote), mais l'exemplaire
-- Multicrafting garde en sac est ilvl 206. Le plan doit donc demander un outil
-- Multicrafting ilvl >= 232 -- pas l'itemID nu, qui rendrait le rang 1 -- et
-- l'enchantement Multicraft (243995) avec lui. Les deux emplacements
-- d'accessoire fautifs completent le plan, sur le rang seul.
--
-- Les enchantements sont desormais dans LE MEME plan que l equipement. Tant
-- qu il y avait deux boutons, ce plan-ci n annoncait que l enchantement de l
-- outil qu il commandait et les autres vivaient sur l autre bouton, si bien
-- qu aucun des deux compteurs ne disait ce qui manquait vraiment.
--
-- Il en reste deux, pas trois : le Resourcefulness equipe est nu et conforme,
-- donc il reclame le sien (243967) ; le futur outil Multicrafting emmene le
-- sien (243995) ; mais le Multicrafting ilvl 206 garde en sac ne compte pas,
-- puisque c est precisement lui qu on remplace.
local planTrace
for _, entry in ipairs((YayaWeeklyTrackerAccountDB or {}).debugLog or {}) do
    if entry:find("Profession supply plan", 1, true) then
        planTrace = entry
    end
end
if not planTrace then
    Fail("aucune trace de plan d'achat d'equipement : le test ne couvre plus rien")
else
    if not planTrace:find("multicrafting:232", 1, true) then
        Fail("l'outil Multicrafting n'est pas demande sur sa variante :: " .. planTrace)
    end
    -- UN seul enchantement Multicraft, celui du futur outil. L exemplaire
    -- ilvl 206 garde en sac porte la meme statistique mais part des que le
    -- 232 arrive : l enchanter serait jeter un parchemin, et son besoin est
    -- deja porte par son remplacant. En compter deux faisait acheter deux
    -- parchemins pour un seul outil final.
    if not planTrace:find("1x243995/enchant", 1, true) then
        Fail("l enchantement du futur outil Multicraft manque :: " .. planTrace)
    end
    if planTrace:find("2x243995/enchant", 1, true) then
        Fail("l outil Multicraft sortant reclame encore son enchantement :: " .. planTrace)
    end
    if not planTrace:find("1x243967/enchant", 1, true) then
        Fail("l'enchantement de l'outil Resourcefulness nu manque :: " .. planTrace)
    end
    if planTrace:find("resourcefulness:", 1, true) then
        Fail("un outil Resourcefulness conforme est possede, il ne doit rien declencher :: " .. planTrace)
    end
    -- Deux accessoires fautifs : l'un sous le seuil, l'autre absent.
    if not planTrace:find("rank:232", 1, true) then
        Fail("les accessoires ne sont pas demandes sur le rang :: " .. planTrace)
    end
    if not planTrace:find("gear=3 ench=2", 1, true) then
        Fail("le decompte du plan est inattendu :: " .. planTrace)
    end
    if planTrace:find("unknownStats=[1-9]") then
        Fail("une statistique demandee n'a pas de bonusId connu :: " .. planTrace)
    end
end

-- 4. Un outil Multicrafting EQUIPE satisfait l'exigence autant qu'un outil
-- garde en sac.
--
-- YayaQueue equipe l'outil Multicrafting depuis les sacs avant les crafts qui
-- multicraftent, mais l'echange renvoie en sac l'outil qui sort : porter
-- l'exemplaire Multicrafting revient au meme, il est meme deja en place. Juger
-- sur la seule presence en sac faisait reclamer un second exemplaire des que le
-- premier etait porte, et le plan d'achat en achetait un doublon.
EquipMulticraftToolFixture()
FireEvent("PLAYER_EQUIPMENT_CHANGED")
FireEvent("BAG_UPDATE_DELAYED")
RunTimers(5)

local swappedGearTrace, swappedPlanTrace
for _, entry in ipairs((YayaWeeklyTrackerAccountDB or {}).debugLog or {}) do
    if entry:find("gear%[2906%]") then
        swappedGearTrace = entry
    end
    if entry:find("Profession supply plan", 1, true) then
        swappedPlanTrace = entry
    end
end
if not swappedGearTrace then
    Fail("aucune trace de scan d'equipement apres l'echange d'outil")
else
    if not swappedGearTrace:find("mcOwned=true") or not swappedGearTrace:find("mcOk=true") then
        Fail("l'outil Multicrafting equipe n'est pas reconnu conforme :: " .. swappedGearTrace)
    end
    if not swappedGearTrace:find("needs=none", 1, true) then
        Fail("un besoin d'outil subsiste alors que les deux statistiques sont possedees :: "
            .. swappedGearTrace)
    end
end
if not swappedPlanTrace then
    Fail("aucune trace de plan d'achat apres l'echange d'outil")
else
    if swappedPlanTrace:find("multicrafting:", 1, true) then
        Fail("un outil Multicrafting conforme est equipe, il ne doit rien declencher :: "
            .. swappedPlanTrace)
    end
    -- Restent les deux accessoires sur le rang seul, et les enchantements des
    -- deux outils possedes : aucun outil n'est plus a acheter, mais les deux
    -- exemplaires en main sont toujours nus.
    if not swappedPlanTrace:find("gear=2 ench=2", 1, true) then
        Fail("le decompte du plan est inattendu apres l'echange d'outil :: " .. swappedPlanTrace)
    end
end

-- 5. L'instantane de la Warbank : ecrit banque ouverte, il survit a sa
-- fermeture. C'est le seul moyen de repondre « present en Warbank » a l'hotel
-- des ventes, loin de la banque.
local function LastTrace(needle)
    local found
    for _, entry in ipairs((YayaWeeklyTrackerAccountDB or {}).debugLog or {}) do
        if entry:find(needle, 1, true) then
            found = entry
        end
    end
    return found
end

FillWarbankFixture()
OpenWarbankFixture()
FireEvent("BANKFRAME_OPENED")
FireEvent("PLAYER_ACCOUNT_BANK_TAB_SLOTS_CHANGED")
RunTimers(5)

local inventoryTrace = LastTrace("Warbank inventory")
if not inventoryTrace then
    Fail("aucune trace d'inventaire Warbank : le scan n'a pas tourne")
else
    for _, expected in ipairs({ "243995x2", "245778x3", "244626x1", "245755x3" }) do
        if not inventoryTrace:find(expected, 1, true) then
            Fail("l'inventaire Warbank ne voit pas " .. expected .. " :: " .. inventoryTrace)
        end
    end
    -- L'exemplaire sans lien est enregistre, mais marque indecis.
    if not inventoryTrace:find("unresolved=1", 1, true) then
        Fail("l'exemplaire sans lien n'est pas marque indecis :: " .. inventoryTrace)
    end
    if not inventoryTrace:find("oracle=client", 1, true) then
        Fail("l'oracle du client aurait du etre valide par le scan :: " .. inventoryTrace)
    end
end

local snapshot = (YayaWeeklyTrackerAccountDB or {}).warbankSnapshot
if type(snapshot) ~= "table" or type(snapshot.itemsByID) ~= "table" then
    Fail("l'instantane Warbank n'est pas persiste")
else
    local tool = snapshot.itemsByID[245778]
    if not tool or #tool.instances ~= 3 then
        Fail("les trois exemplaires d'outil ne sont pas enregistres")
    else
        local resourceful, wrongStat, unresolved = 0, 0, 0
        for _, instance in ipairs(tool.instances) do
            if instance.unresolved then
                unresolved = unresolved + 1
            elseif instance.statKey == "resourcefulness" and instance.itemLevel == 232 then
                resourceful = resourceful + 1
            elseif instance.statKey == "multicrafting" then
                wrongStat = wrongStat + 1
            end
        end
        if resourceful ~= 1 or wrongStat ~= 1 or unresolved ~= 1 then
            Fail(("identites d'outil mal lues en Warbank : rf=%d mc=%d indecis=%d")
                :format(resourceful, wrongStat, unresolved))
        end
    end
end

-- 6. Banque refermee, l'instantane repond encore, et chaque verdict garde ses
-- trois etats : conforme, non conforme, indecis.
CloseWarbankFixture()
FireEvent("BANKFRAME_CLOSED")
RunTimers(5)

local warbank = _G.YayaWeeklyTrackerAPI
    and { Resolve = _G.YayaWeeklyTrackerAPI.ResolveWarbankItem }
    or nil
if not warbank or not warbank.Resolve then
    Fail("l'inventaire Warbank n'est pas expose par YayaWeeklyTrackerAPI")
else
    local rfVariant = { minItemLevel = 232, statKey = "resourcefulness" }
    local mcVariant = { minItemLevel = 232, statKey = "multicrafting" }

    local scroll = warbank.Resolve(243995, nil)
    if not scroll.known or scroll.matched ~= 2 then
        Fail(("une marchandise en Warbank n'est pas vue banque fermee : known=%s matched=%s")
            :format(tostring(scroll.known), tostring(scroll.matched)))
    end

    local rf = warbank.Resolve(245778, rfVariant)
    if not rf.known then
        Fail("l'outil Resourcefulness en Warbank n'est pas jugeable banque fermee")
    elseif rf.matched ~= 1 then
        Fail("l'exemplaire Resourcefulness conforme n'est pas reconnu : matched=" .. tostring(rf.matched))
    elseif rf.undecided ~= 1 then
        Fail("l'exemplaire sans lien devrait rester indecis : undecided=" .. tostring(rf.undecided))
    end

    -- Le seul exemplaire Multicrafting est ilvl 206 : possede, mais non
    -- conforme. Il ne doit ni compter, ni bloquer.
    local mc = warbank.Resolve(245778, mcVariant)
    if not mc.known or mc.matched ~= 0 then
        Fail("un outil Multicrafting sous le seuil est pris pour conforme : matched="
            .. tostring(mc.matched))
    end

    -- Rien en Warbank : absent CERTAIN, sans instantane. C'est ce qui permet
    -- de proposer un achat sur une installation neuve.
    local absent = warbank.Resolve(243967, { minItemLevel = 232 })
    if not absent.known or absent.count ~= 0 then
        Fail("un objet absent de la Warbank devrait etre un verdict certain")
    end

    -- Instantane perime : le compte vivant grimpe sans qu'un scan l'ait vu.
    -- Indecis, donc ni recuperation ni achat.
    DesyncWarbankFixture(245778, 1)
    local stale = warbank.Resolve(245778, rfVariant)
    if stale.known then
        Fail("un instantane perime devrait rendre un verdict inconnu")
    end
    WARBANK_DESYNC[245778] = nil
end

-- Le scenario qui motive tout : a l'hotel des ventes, banque fermee, ce qui
-- dort en Warbank n'est PAS rachete, et le bouton propose l'achat du reste.
FireEvent("BAG_UPDATE_DELAYED")
RunTimers(5)

local closedPlanTrace = LastTrace("Profession supply plan")
if not closedPlanTrace then
    Fail("aucun plan banque fermee")
else
    -- L'accessoire 244626 et le parchemin 243995 dorment en banque : ils
    -- passent en recuperation, jamais en achat. Restent 239635 et 243967.
    if not closedPlanTrace:find("+wb", 1, true) then
        Fail("banque fermee, le plan ne voit plus la Warbank :: " .. closedPlanTrace)
    end
    if closedPlanTrace:find("1x244626/rank:232,", 1, true)
        or closedPlanTrace:find("1x244626/rank:232$") then
        Fail("un accessoire present en Warbank est propose a l'achat :: " .. closedPlanTrace)
    end
    if not closedPlanTrace:find("gear=1 ench=1", 1, true) then
        Fail("le plan banque fermee ne deduit pas la Warbank :: " .. closedPlanTrace)
    end
end

local closedButton = _G.YayaWeeklyTrackerProfessionSupplyButton
if not closedButton or not closedButton:IsShown() then
    Fail("le bouton d'approvisionnement disparait banque fermee")
elseif not (closedButton.__text or ""):find("Acheter") then
    -- Banque fermee, les emplacements ne sont pas adressables : le clic doit
    -- basculer sur l'achat plutot que de proposer un transfert impossible.
    Fail("banque fermee, le bouton n'annonce pas l'achat :: " .. tostring(closedButton.__text))
elseif not closedButton:IsEnabled() then
    Fail("banque fermee, le bouton d'achat est grise alors que YayaQueue repond")
end

-- 7. Le geste de transfert : un clic sort UN objet, depuis le bon emplacement,
-- et un second clic immediat ne fait rien. Les deux implementations qu'il
-- remplace laissaient passer le double-clic et le curseur charge.
OpenWarbankFixture()
FireEvent("BANKFRAME_OPENED")
RunTimers(5)

local supplyButton = _G.YayaWeeklyTrackerProfessionSupplyButton
if not supplyButton or not supplyButton:IsShown() then
    Fail("le bouton d'approvisionnement n'apparait pas alors qu'il reste des manques")
elseif not (supplyButton.__text or ""):find("Récupérer WB") then
    -- Warbank ouverte et objets conformes dedans : le prochain clic recupere,
    -- il n'achete pas. Le libelle doit le dire.
    Fail("le bouton n'annonce pas la recuperation Warbank :: " .. tostring(supplyButton.__text))
else
    TRANSFER_CALLS = {}
    supplyButton.__scripts.OnClick(supplyButton, "LeftButton", false)
    -- L'accessoire conforme dort en 14:3, seul exemplaire de sa pile.
    if TRANSFER_CALLS[1] ~= "Pickup 14:3" then
        Fail("le transfert ne part pas du bon emplacement Warbank :: "
            .. tostring(TRANSFER_CALLS[1]))
    end
    -- La destination doit etre un emplacement VIDE. Un exemplaire du meme
    -- objet dort en 0:4 : le designer comme destination faisait executer au
    -- jeu un echange a deux sens, et l'objet du sac -- soulbound des qu'il a
    -- ete equipe une fois -- repartait vers la Warbank, qui le refusait.
    if TRANSFER_CALLS[2] ~= "Pickup 0:5" then
        Fail("l'objet sorti n'est pas depose dans un emplacement vide :: "
            .. tostring(TRANSFER_CALLS[2]))
    end
    if #TRANSFER_CALLS ~= 2 then
        Fail(("un clic a produit %d appels de transfert au lieu de 2"):format(#TRANSFER_CALLS))
    end

    -- Verrou anti-multiclic : rien avant le rafraichissement suivant.
    local afterFirst = #TRANSFER_CALLS
    supplyButton.__scripts.OnClick(supplyButton, "LeftButton", false)
    if #TRANSFER_CALLS ~= afterFirst then
        Fail("un second clic immediat sort un deuxieme objet")
    end

    -- Curseur charge : le transfert doit renoncer, sinon il echange
    -- silencieusement ce que le curseur porte contre l'objet vise.
    supplyButton.itemActionLocked = false
    local previousCursor = GetCursorInfo
    GetCursorInfo = function() return "item", 12345 end
    TRANSFER_CALLS = {}
    supplyButton.__scripts.OnClick(supplyButton, "LeftButton", false)
    GetCursorInfo = previousCursor
    if #TRANSFER_CALLS ~= 0 then
        Fail("un curseur charge n'empeche pas le transfert")
    end
end

-- 8. Un seul bouton : les trois anciens ont disparu, et le raccourci partage
-- ne peut plus tomber sur un doublon.
for _, name in ipairs({
    "YayaWeeklyTrackerToolEnchantPullButton",
    "YayaWeeklyTrackerToolEnchantBuyButton",
    "YayaWeeklyTrackerProfessionGearBuyButton",
    "YayaWeeklyTrackerWarbankTreatiseButton1",
}) do
    if _G[name] then
        Fail("un bouton remplace existe encore : " .. name)
    end
end
CloseWarbankFixture()
FireEvent("BANKFRAME_CLOSED")
RunTimers(3)

-- 9. Les jetons de ligne : deux, et derives des memes sources que le plan.
-- Les quatre anciens -- outil KO, outil RF, MC KO, outil xN -- decoupaient la
-- meme regle en morceaux sous deux options differentes.
local tokenTrace = LastTrace("Profession tokens[2906]")
if not tokenTrace then
    Fail("aucune trace de jetons de metier : ils ne sont plus verifiables hors du jeu")
else
    for _, gone in ipairs({ "outil KO", "outil RF", "MC KO" }) do
        if tokenTrace:find(gone, 1, true) then
            Fail("un jeton remplace est encore emis : " .. gone .. " :: " .. tokenTrace)
        end
    end
    -- Deux accessoires fautifs, aucun besoin d'outil apres l'echange, et les
    -- deux outils possedes sont nus.
    if not tokenTrace:find("stuff x2", 1, true) then
        Fail("le jeton de materiel ne compte pas les deux accessoires :: " .. tokenTrace)
    end
    if not tokenTrace:find("ench x2", 1, true) then
        Fail("le jeton d'enchantement ne compte pas les deux outils nus :: " .. tokenTrace)
    end
end

-- 10. Un outil rare NON LIE compte comme possede. C'est l'etat d'un achat tout
-- juste livre par le courrier : l'ignorer faisait commander un doublon dans la
-- foulee de la livraison. YayaQueue, lui, garde son filtre soulbound pour
-- l'echange d'outil avant craft.
local toolsBefore
for _, entry in ipairs((YayaWeeklyTrackerAccountDB or {}).debugLog or {}) do
    local count = entry:match("id=2906 .- tools=(%d+)")
    if count then
        toolsBefore = tonumber(count)
    end
end

AddUnboundToolFixture()
ISBOUND_CALLS = 0
FireEvent("BAG_UPDATE_DELAYED")
RunTimers(5)

-- La preuve que le filtre a bien disparu : le tracker ne demande plus l'etat
-- de liaison d'aucun objet. Le compter vaut mieux qu'esperer, car un outil
-- lie serait compte de toute facon.
if ISBOUND_CALLS ~= 0 then
    Fail(("le tracker consulte encore l'etat de liaison (%d appels)"):format(ISBOUND_CALLS))
end

local toolsAfter
for _, entry in ipairs((YayaWeeklyTrackerAccountDB or {}).debugLog or {}) do
    local count = entry:match("id=2906 .- tools=(%d+)")
    if count then
        toolsAfter = tonumber(count)
    end
end
if not toolsBefore or not toolsAfter then
    Fail("la trace de scan d'outils ne rend plus son compte")
elseif toolsAfter ~= toolsBefore + 1 then
    Fail(("un outil rare non lie n'est pas compte comme possede : %s -> %s")
        :format(tostring(toolsBefore), tostring(toolsAfter)))
end

if failures > 0 then
    print(("%d echec(s)"):format(failures))
    os.exit(1)
end

print("test_tracker_refresh : rafraichissement sans erreur, scan d'equipement conforme, plan d'achat par variante, outil Multicrafting equipe reconnu, Warbank suivie et jugee par variante")
