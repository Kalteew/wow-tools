local addonName = ...

-- Ouvre la banque sur le premier onglet de banque de bataillon reellement achete.
--
-- Rappel du mecanisme Blizzard (Blizzard_UIPanels_Game/Mainline/BankFrame.lua, 12.1) :
--   BankFrameMixin:OnShow -> RefreshTabVisibility -> SelectDefaultTab
--     -> SelectFirstAvailableTab -> premier onglet de TYPE visible (Banque avant Warband)
--     -> BankFrame:SetTab -> BankPanel:SetBankType -> BankPanel:Reset
--          -> FetchPurchasedBankTabData -> SelectFirstAvailableTab -> RefreshBankPanel
--
-- BankPanelMixin:SelectFirstAvailableTab retombe sur PURCHASE_TAB_ID (-1) quand le type
-- courant n'a aucun onglet achete, et BankPanel:SelectTab sort en early-return quand la
-- valeur ne change pas : de la vient le panneau d'achat affiche sur les personnages sans
-- banque perso. On force donc explicitement le type ET l'onglet, et on ne considere la
-- selection reussie que si un onglet warband achete est effectivement affiche.

local ADDON_PREFIX = "|cff00ff98YayaWarbandBankDefault:|r "
local LOG_LIMIT = 200
local RETRY_DELAYS = { 0, 0.05, 0.1, 0.25, 0.5, 1, 2 }

local HOOK_TRIGGER_ADDONS = {
	["Blizzard_UIPanels_Game"] = true,
	["ElvUI"] = true,
	["EllesmereUI"] = true,
	["TradeSkillMaster"] = true,
}

-- Suites UI susceptibles de remplacer la fenetre de banque, listees par /ywd probe.
local PROBE_ADDONS = {
	"ElvUI", "EllesmereUI", "EllesmereUIUnitFrames", "TradeSkillMaster",
	"Bagnon", "Baganator", "AdiBags", "ArkInventory", "BetterBags", "Syndicator",
}

local eventFrame = CreateFrame("Frame")
local db
local sessionID = 0

local state = {
	open = false,        -- une session de banque est en cours
	done = false,        -- plus rien a forcer pour cette session
	attempt = 0,         -- index courant dans RETRY_DELAYS
	attemptsRun = 0,     -- nombre de tentatives reellement executees
	token = 0,           -- invalide les timers d'une session precedente
}

local hooks = { bankFrame = false, elvui = false }

-- ============================================================================
-- Journal
-- ============================================================================

local function Timestamp()
	if type(date) == "function" then
		return date("%H:%M:%S")
	end
	return type(GetTime) == "function" and string.format("%.1f", GetTime()) or "?"
end

local function Debug(message)
	if not db then
		return
	end
	message = tostring(message)
	local log = db.log
	log[#log + 1] = string.format("[%s #%d] %s", Timestamp(), sessionID, message)
	while #log > LOG_LIMIT do
		table.remove(log, 1)
	end
	if db.debug then
		print(ADDON_PREFIX .. message)
	end
end

local function InitDB()
	if type(YayaWarbandBankDefaultDB) ~= "table" then
		YayaWarbandBankDefaultDB = {}
	end
	db = YayaWarbandBankDefaultDB
	if type(db.log) ~= "table" then
		db.log = {}
	end
	if type(db.debug) ~= "boolean" then
		db.debug = false
	end
	db.session = (tonumber(db.session) or 0) + 1
	sessionID = db.session
end

-- ============================================================================
-- Cible : premier onglet de warbank achete
-- ============================================================================

local function GetAccountBankType()
	return Enum and Enum.BankType and Enum.BankType.Account or nil
end

local function CanViewWarbandBank()
	local bankType = GetAccountBankType()
	if not (bankType and C_Bank and type(C_Bank.CanViewBank) == "function") then
		Debug("cible: Enum.BankType.Account ou C_Bank.CanViewBank indisponible")
		return false
	end
	local ok, canView = pcall(C_Bank.CanViewBank, bankType)
	if not ok then
		Debug("cible: CanViewBank a echoue -> " .. tostring(canView))
		return false
	end
	return canView == true
end

-- Meme ordre que Blizzard : BankPanelMixin:SelectFirstAvailableTab prend
-- purchasedBankTabData[1].ID. Aucune valeur codee en dur (pas de 12 devine).
local function GetWarbandTargetTabID()
	local bankType = GetAccountBankType()
	if not (bankType and C_Bank) then
		return nil, 0
	end

	if type(C_Bank.FetchPurchasedBankTabData) == "function" then
		local ok, tabData = pcall(C_Bank.FetchPurchasedBankTabData, bankType)
		if ok and type(tabData) == "table" then
			if type(tabData[1]) == "table" and tabData[1].ID then
				return tabData[1].ID, #tabData
			end
			Debug("cible: FetchPurchasedBankTabData renvoie 0 onglet")
		else
			Debug("cible: FetchPurchasedBankTabData a echoue -> " .. tostring(tabData))
		end
	end

	if type(C_Bank.FetchPurchasedBankTabIDs) == "function" then
		local ok, tabIDs = pcall(C_Bank.FetchPurchasedBankTabIDs, bankType)
		if ok and type(tabIDs) == "table" then
			local best, count = nil, 0
			for _, tabID in pairs(tabIDs) do
				count = count + 1
				if type(tabID) == "number" and (best == nil or tabID < best) then
					best = tabID
				end
			end
			Debug("cible: repli FetchPurchasedBankTabIDs -> " .. tostring(best)
				.. " (" .. tostring(count) .. " onglets)")
			return best, count
		end
	end

	Debug("cible: aucune API C_Bank exploitable")
	return nil, 0
end

-- ============================================================================
-- Providers d'interface
-- ============================================================================

local function GetBankPanel()
	local bankFrame = _G.BankFrame
	return _G.BankPanel or (bankFrame and bankFrame.BankPanel) or nil
end

local function GetElvUIBags()
	local elvUI = _G.ElvUI
	if type(elvUI) ~= "table" then
		return nil
	end
	local E = elvUI[1]
	if not (E and type(E.GetModule) == "function") then
		return nil
	end
	-- Module sacs desactive : ElvUI ne remplace pas la banque.
	if E.private and E.private.bags and E.private.bags.enable == false then
		return nil
	end
	local ok, bags = pcall(E.GetModule, E, "Bags")
	if not (ok and type(bags) == "table") then
		return nil
	end
	return bags
end

local function IsFrameVisible(frame)
	return frame ~= nil and type(frame.IsShown) == "function" and frame:IsShown() == true
end

local function GetPanelField(panel, getterName, fieldName)
	if not panel then
		return nil
	end
	if type(panel[getterName]) == "function" then
		local ok, value = pcall(panel[getterName], panel)
		if ok then
			return value
		end
	end
	return panel[fieldName]
end

local providers = {
	{
		name = "elvui",
		IsActive = function()
			local bags = GetElvUIBags()
			return IsFrameVisible(bags and bags.BankFrame)
		end,
		IsSatisfied = function(target)
			local bags = GetElvUIBags()
			return bags ~= nil and bags.BankTab == target
		end,
		-- Chemin natif d'ElvUI (B:WarbandToggle_OnClick) : SelectBankTab enchaine
		-- ShowBankTab puis SetBankTabs. On ne touche pas au BankPanel Blizzard,
		-- neutralise par B:DisableBlizzard.
		Apply = function(target)
			local bags = GetElvUIBags()
			local frame = bags and bags.BankFrame
			if not frame then
				Debug("elvui: BankFrame absente pendant Apply")
				return false
			end
			if type(bags.SelectBankTab) == "function" then
				Debug("elvui: SelectBankTab(" .. tostring(target) .. ")")
				local ok, err = pcall(bags.SelectBankTab, bags, frame, target)
				if not ok then
					Debug("elvui: SelectBankTab a echoue -> " .. tostring(err))
					return false
				end
				return true
			end
			if type(bags.ShowBankTab) == "function" then
				Debug("elvui: repli ShowBankTab(" .. tostring(target) .. ")")
				local ok, err = pcall(bags.ShowBankTab, bags, frame, target)
				if not ok then
					Debug("elvui: ShowBankTab a echoue -> " .. tostring(err))
					return false
				end
				if type(bags.SetBankTabs) == "function" then
					pcall(bags.SetBankTabs, bags, frame)
				end
				return true
			end
			Debug("elvui: ni SelectBankTab ni ShowBankTab")
			return false
		end,
	},
	{
		name = "blizzard",
		IsActive = function()
			if not IsFrameVisible(_G.BankFrame) then
				return false
			end
			-- Une UI tierce qui affiche sa propre banque garde la main.
			local bags = GetElvUIBags()
			if IsFrameVisible(bags and bags.BankFrame) then
				return false
			end
			return true
		end,
		IsSatisfied = function(target)
			local panel = GetBankPanel()
			if not panel then
				return false
			end
			local activeType = GetPanelField(panel, "GetActiveBankType", "bankType")
			local selected = GetPanelField(panel, "GetSelectedTabID", "selectedTabID")
			return activeType == GetAccountBankType() and selected == target
		end,
		Apply = function(target)
			local bankFrame = _G.BankFrame
			local panel = GetBankPanel()
			if not panel then
				Debug("blizzard: BankPanel introuvable")
				return false
			end

			-- 1. type de banque + onglet de type visuellement selectionne
			local accountTabID = bankFrame and bankFrame.accountBankTabID
			if accountTabID and type(bankFrame.SetTab) == "function" then
				local ok, err = pcall(bankFrame.SetTab, bankFrame, accountTabID)
				Debug("blizzard: SetTab(" .. tostring(accountTabID) .. ") ok=" .. tostring(ok)
					.. (ok and "" or (" -> " .. tostring(err))))
			else
				Debug("blizzard: accountBankTabID=" .. tostring(accountTabID)
					.. " SetTab=" .. tostring(bankFrame ~= nil and type(bankFrame.SetTab) == "function"))
			end

			-- 2. onglet warband : Reset() ne le choisit pas quand les donnees arrivent
			--    en retard, et SelectTab(-1) sort en early-return depuis le panneau
			--    d'achat de la banque perso.
			local selected = GetPanelField(panel, "GetSelectedTabID", "selectedTabID")
			if selected ~= target then
				if type(panel.SelectTab) ~= "function" then
					Debug("blizzard: BankPanel:SelectTab indisponible")
					return false
				end
				local ok, err = pcall(panel.SelectTab, panel, target)
				Debug("blizzard: SelectTab(" .. tostring(target) .. ") depuis "
					.. tostring(selected) .. " ok=" .. tostring(ok)
					.. (ok and "" or (" -> " .. tostring(err))))
			end

			-- 3. rafraichissement, indispensable si SelectTab est sorti en early-return
			if type(panel.RefreshBankTabs) == "function" then
				pcall(panel.RefreshBankTabs, panel)
			end
			if type(panel.RefreshBankPanel) == "function" then
				pcall(panel.RefreshBankPanel, panel)
			end
			return true
		end,
	},
}

local function CurrentProvider()
	for _, provider in ipairs(providers) do
		local ok, active = pcall(provider.IsActive)
		if ok and active then
			return provider
		end
	end
	return nil
end

-- ============================================================================
-- Moteur de selection
-- ============================================================================

local function TryOnce()
	state.attemptsRun = state.attemptsRun + 1
	local label = "essai " .. state.attemptsRun .. ": "

	local provider = CurrentProvider()
	if not provider then
		Debug(label .. "aucun provider actif (fenetre de banque non visible)")
		return false
	end

	if not CanViewWarbandBank() then
		Debug(label .. provider.name
			.. " banque de bataillon non consultable ici, on laisse le defaut Blizzard")
		return false
	end

	local target, purchased = GetWarbandTargetTabID()
	if not target then
		Debug(label .. provider.name .. " aucun onglet de warbank achete ("
			.. tostring(purchased) .. ") -> on ne force rien, jamais de panneau d'achat")
		return false
	end

	if provider.IsSatisfied(target) then
		Debug(label .. provider.name .. " deja sur l'onglet warband " .. tostring(target))
		return true
	end

	local ok, applied = pcall(provider.Apply, target)
	if not ok then
		Debug(label .. provider.name .. " Apply a leve une erreur -> " .. tostring(applied))
		return false
	end

	local satisfied = provider.IsSatisfied(target) == true
	Debug(label .. provider.name
		.. " applique=" .. tostring(applied)
		.. " cible=" .. tostring(target)
		.. " onglets=" .. tostring(purchased)
		.. " satisfait=" .. tostring(satisfied))
	return satisfied
end

local ScheduleRetry
ScheduleRetry = function(token)
	if token ~= state.token or state.done or not state.open then
		return
	end
	state.attempt = state.attempt + 1
	local delay = RETRY_DELAYS[state.attempt]
	if not delay then
		Debug("essais epuises (" .. #RETRY_DELAYS .. "), en attente de BANK_TABS_CHANGED")
		return
	end
	C_Timer.After(delay, function()
		if token ~= state.token or state.done or not state.open then
			return
		end
		if TryOnce() then
			state.done = true
			Debug("onglet warband selectionne (essai differe)")
		else
			ScheduleRetry(token)
		end
	end)
end

local function Trigger(reason)
	if not state.open then
		state.open = true
		state.done = false
		state.attemptsRun = 0
		Debug("session de banque ouverte (" .. tostring(reason) .. ")")
	elseif state.done then
		Debug("declencheur '" .. tostring(reason) .. "' ignore: termine pour cette session")
		return
	end

	state.attempt = 0
	state.token = state.token + 1
	local token = state.token

	if TryOnce() then
		state.done = true
		Debug("onglet warband selectionne immediatement (" .. tostring(reason) .. ")")
	else
		ScheduleRetry(token)
	end
end

local function EndSession()
	if not state.open then
		return
	end
	state.open = false
	state.done = false
	state.attempt = 0
	state.attemptsRun = 0
	state.token = state.token + 1
	Debug("session de banque fermee")
end

-- Pourquoi aucun hook de detection de "choix manuel" :
--
-- 1. Des que la selection a abouti, state.done reste vrai jusqu'a la fermeture de la
--    banque : un changement d'onglet fait a la main est donc respecte sans surveillance.
-- 2. Les seuls cas ou la boucle d'essais continue sont ceux ou il n'y a rien a voler a
--    l'utilisateur : fenetre de banque non visible, banque de bataillon non consultable,
--    ou aucun onglet de warbank achete. La fenetre de conflit reelle se limite a l'echec
--    d'un Apply, soit environ 4 secondes apres l'ouverture.
-- 3. Surveiller BankFrame:SetTab serait de toute facon faux : TabSystemOwnerMixin
--    capture self.SetTab via GenerateClosure au chargement, donc un hooksecurefunc ne
--    voit PAS les clics sur les onglets Banque / Banque de bataillon, mais voit la
--    sequence d'ouverture de Blizzard. C'est ce piege qui faisait s'annuler la version
--    precedente (HandleExternalBankSelection sur BankPanel:SetBankType).

-- ============================================================================
-- Hooks
-- ============================================================================

local function InstallBlizzardHooks()
	local bankFrame = _G.BankFrame
	if hooks.bankFrame or not bankFrame or type(hooksecurefunc) ~= "function" then
		return hooks.bankFrame
	end

	-- Declencheur principal : SelectDefaultTab est appele par BankFrameMixin:OnShow
	-- juste apres le choix par defaut, donc on corrige dans la meme frame, sans
	-- dependre de l'ordre des handlers BANKFRAME_OPENED et sans flash visible.
	if type(bankFrame.SelectDefaultTab) == "function" then
		hooksecurefunc(bankFrame, "SelectDefaultTab", function()
			Trigger("BankFrame:SelectDefaultTab")
		end)
		Debug("hook BankFrame:SelectDefaultTab installe")
	else
		Debug("BankFrame:SelectDefaultTab absent, repli sur OnShow/BANKFRAME_OPENED")
	end

	if type(bankFrame.HookScript) == "function" then
		bankFrame:HookScript("OnShow", function()
			Trigger("BankFrame OnShow")
		end)
		-- filet si BANKFRAME_CLOSED n'arrive pas (fermeture par Echap, /reload...)
		bankFrame:HookScript("OnHide", EndSession)
	end

	hooks.bankFrame = true
	return true
end

local function InstallElvUIHooks()
	if hooks.elvui or type(hooksecurefunc) ~= "function" then
		return hooks.elvui
	end
	local bags = GetElvUIBags()
	if not bags then
		return false
	end
	if type(bags.OpenBank) ~= "function" then
		Debug("elvui: OpenBank absent, hook impossible")
		return false
	end
	hooksecurefunc(bags, "OpenBank", function()
		Trigger("ElvUI OpenBank")
	end)
	hooks.elvui = true
	Debug("elvui: hook OpenBank installe")
	return true
end

local function InstallHooks()
	InstallBlizzardHooks()
	InstallElvUIHooks()
end

-- ============================================================================
-- Diagnostic
-- ============================================================================

local function Probe()
	local out = {}
	local function add(text)
		out[#out + 1] = text
	end

	local provider = CurrentProvider()
	local target, purchased = GetWarbandTargetTabID()
	add("provider actif = " .. tostring(provider and provider.name or "aucun"))
	add("cible warband = " .. tostring(target) .. " (" .. tostring(purchased) .. " onglets achetes)")
	add("session ouverte=" .. tostring(state.open) .. " termine=" .. tostring(state.done)
		.. " essais=" .. tostring(state.attemptsRun))

	if C_Bank and Enum and Enum.BankType then
		local types = {
			{ "Character", Enum.BankType.Character },
			{ "Account  ", Enum.BankType.Account },
		}
		for _, entry in ipairs(types) do
			local label, bankType = entry[1], entry[2]
			local canView, canPurchase, numTabs = "?", "?", "?"
			if bankType ~= nil then
				if type(C_Bank.CanViewBank) == "function" then
					local ok, value = pcall(C_Bank.CanViewBank, bankType)
					canView = ok and tostring(value) or "erreur"
				end
				if type(C_Bank.CanPurchaseBankTab) == "function" then
					local ok, value = pcall(C_Bank.CanPurchaseBankTab, bankType)
					canPurchase = ok and tostring(value) or "erreur"
				end
				if type(C_Bank.FetchNumPurchasedBankTabs) == "function" then
					local ok, value = pcall(C_Bank.FetchNumPurchasedBankTabs, bankType)
					numTabs = ok and tostring(value) or "erreur"
				end
			end
			add(label .. ": canView=" .. canView .. " canPurchase=" .. canPurchase
				.. " onglets=" .. numTabs)
		end
	else
		add("C_Bank ou Enum.BankType indisponible")
	end

	local bankFrame = _G.BankFrame
	local panel = GetBankPanel()
	add("BankFrame visible=" .. tostring(IsFrameVisible(bankFrame))
		.. " accountBankTabID=" .. tostring(bankFrame and bankFrame.accountBankTabID))
	add("BankPanel bankType=" .. tostring(panel and panel.bankType)
		.. " selectedTabID=" .. tostring(panel and panel.selectedTabID)
		.. " (-1 = panneau d'achat)")

	local bags = GetElvUIBags()
	if bags then
		add("ElvUI Bags: BankFrame visible=" .. tostring(IsFrameVisible(bags.BankFrame))
			.. " BankTab=" .. tostring(bags.BankTab)
			.. " WarbandIndexs[1]=" .. tostring(bags.WarbandIndexs and bags.WarbandIndexs[1]))
	else
		add("ElvUI Bags: absent ou module sacs desactive")
	end

	local loaded = {}
	if C_AddOns and type(C_AddOns.IsAddOnLoaded) == "function" then
		for _, name in ipairs(PROBE_ADDONS) do
			local ok, isLoaded = pcall(C_AddOns.IsAddOnLoaded, name)
			if ok and isLoaded then
				loaded[#loaded + 1] = name
			end
		end
	end
	add("addons banque/sacs charges: " .. (#loaded > 0 and table.concat(loaded, ", ") or "aucun"))

	local found = 0
	for name, value in pairs(_G) do
		if type(name) == "string" and name:find("ank") and type(value) == "table"
			and type(value.IsShown) == "function" and type(value.GetObjectType) == "function" then
			local ok, shown = pcall(value.IsShown, value)
			if ok and shown then
				local typeOK, objectType = pcall(value.GetObjectType, value)
				found = found + 1
				add("  frame visible: " .. name .. " (" .. (typeOK and tostring(objectType) or "?") .. ")")
			end
		end
	end
	if found == 0 then
		add("  aucune frame globale '*ank*' visible")
	end

	for _, line in ipairs(out) do
		print(ADDON_PREFIX .. line)
		Debug("probe| " .. line)
	end
end

local function DumpLog(argument)
	if not db then
		print(ADDON_PREFIX .. "journal indisponible (SavedVariables pas encore chargees)")
		return
	end
	if argument == "clear" then
		wipe(db.log)
		print(ADDON_PREFIX .. "journal vide")
		return
	end
	local log = db.log
	if #log == 0 then
		print(ADDON_PREFIX .. "journal vide")
		return
	end
	local count = tonumber(argument) or 30
	local first = math.max(1, #log - count + 1)
	print(ADDON_PREFIX .. "journal (" .. (#log - first + 1) .. "/" .. #log .. " entrees)")
	for index = first, #log do
		print("  " .. log[index])
	end
end

SLASH_YAYAWARBANDBANKDEFAULT1 = "/ywd"
SLASH_YAYAWARBANDBANKDEFAULT2 = "/ywbdebug"
SlashCmdList.YAYAWARBANDBANKDEFAULT = function(message)
	local input = string.lower(message or "")
	local command, argument = input:match("^(%S*)%s*(.-)%s*$")

	if command == "debug" or command == "on" or command == "off" then
		if not db then
			print(ADDON_PREFIX .. "SavedVariables pas encore chargees")
			return
		end
		if command == "debug" then
			db.debug = not db.debug
		else
			db.debug = (command == "on")
		end
		print(ADDON_PREFIX .. "debug " .. (db.debug and "active" or "desactive") .. " (persistant)")
	elseif command == "probe" then
		Probe()
	elseif command == "log" then
		DumpLog(argument ~= "" and argument or nil)
	elseif command == "retry" then
		if CurrentProvider() then
			state.done = false
			Debug("nouvel essai demande via /ywd retry")
			Trigger("/ywd retry")
		else
			print(ADDON_PREFIX .. "aucune fenetre de banque visible, rien a forcer")
		end
	else
		print(ADDON_PREFIX .. "/ywd retry | probe | log [n|clear] | debug (on/off)")
	end
end

-- ============================================================================
-- Evenements
-- ============================================================================

eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("BANKFRAME_OPENED")
eventFrame:RegisterEvent("BANKFRAME_CLOSED")
eventFrame:RegisterEvent("BANK_TABS_CHANGED")
eventFrame:SetScript("OnEvent", function(_, event, ...)
	if event == "ADDON_LOADED" then
		local loadedAddonName = ...
		if loadedAddonName == addonName then
			InitDB()
			Debug("SavedVariables chargees (session " .. tostring(sessionID) .. ")")
		end
		if loadedAddonName == addonName or HOOK_TRIGGER_ADDONS[loadedAddonName] then
			InstallHooks()
		end
		return
	end

	InstallHooks()

	if event == "PLAYER_LOGIN" then
		-- les hooks poses avant le chargement des SavedVariables n'ont rien pu journaliser
		Debug("PLAYER_LOGIN: hooks bankFrame=" .. tostring(hooks.bankFrame)
			.. " elvui=" .. tostring(hooks.elvui))
	elseif event == "BANKFRAME_OPENED" then
		Trigger("BANKFRAME_OPENED")
	elseif event == "BANKFRAME_CLOSED" then
		EndSession()
	elseif event == "BANK_TABS_CHANGED" then
		if state.open and not state.done then
			Debug("BANK_TABS_CHANGED pendant nos essais")
			Trigger("BANK_TABS_CHANGED")
		end
	end
end)
