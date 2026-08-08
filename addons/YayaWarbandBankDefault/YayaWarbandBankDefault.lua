local addonName = ...

local eventFrame = CreateFrame("Frame")
local pendingSwitchToken = 0
local hooksInstalled = false
local elvUIHooksInstalled = false
local debugEnabled = true

local function Debug(message)
	if debugEnabled and type(print) == "function" then
		print("|cff00ff98YayaWarbandBankDefault:|r " .. tostring(message))
	end
end

local function IsAccountBankActive(bankFrame)
	return bankFrame
		and type(bankFrame.GetActiveBankType) == "function"
		and bankFrame:GetActiveBankType() == Enum.BankType.Account
end

local function CanViewAccountBank()
	if not (C_Bank and type(C_Bank.CanViewBank) == "function" and Enum and Enum.BankType) then
		return false
	end

	local ok, canView = pcall(C_Bank.CanViewBank, Enum.BankType.Account)
	return ok and canView == true
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

	local ok, bags = pcall(E.GetModule, E, "Bags")
	return ok and bags or nil
end

local function TrySelectAccountBank(token)
	if token ~= pendingSwitchToken then
		return false
	end

	local bankFrame = _G.BankFrame
	if not (bankFrame and type(bankFrame.IsShown) == "function" and bankFrame:IsShown()) then
		Debug("Blizzard: BankFrame absent ou masqué")
		return false
	end

	-- ElvUI owns a separate bank frame and must not be switched through
	-- Blizzard's BankFrame, otherwise the two selected-tab states can diverge.
	local bags = GetElvUIBags()
	local elvUIBankFrame = bags and bags.BankFrame
	if elvUIBankFrame and type(elvUIBankFrame.IsShown) == "function" and elvUIBankFrame:IsShown() then
		Debug("Blizzard: ignoré car la frame ElvUI est visible")
		return false
	end

	local canView = CanViewAccountBank()
	Debug("Blizzard: token=" .. tostring(token)
		.. " actif=" .. tostring(IsAccountBankActive(bankFrame))
		.. " accountTabID=" .. tostring(bankFrame.accountBankTabID)
		.. " canView=" .. tostring(canView))

	if IsAccountBankActive(bankFrame) then
		return true
	end

	local accountTabID = bankFrame.accountBankTabID
	if not (accountTabID and type(bankFrame.SetTab) == "function" and canView) then
		Debug("Blizzard: impossible de sélectionner le tab")
		return false
	end

	local ok, errorMessage = pcall(bankFrame.SetTab, bankFrame, accountTabID)
	Debug("Blizzard: SetTab ok=" .. tostring(ok)
		.. " erreur=" .. tostring(errorMessage)
		.. " actifAprès=" .. tostring(IsAccountBankActive(bankFrame)))
	return ok and IsAccountBankActive(bankFrame)
end

local function TrySelectElvUIAccountBank(token)
	if token ~= pendingSwitchToken then
		return false
	end

	local bags = GetElvUIBags()
	local bankFrame = bags and bags.BankFrame
	if not (bankFrame and type(bankFrame.IsShown) == "function" and bankFrame:IsShown()) then
		Debug("ElvUI: module Bags ou BankFrame absent/masqué")
		return false
	end

	local accountTabID = bags.WarbandIndexs and bags.WarbandIndexs[1]
	local canView = CanViewAccountBank()
	local purchasedCount = "indisponible"
	local canPurchase = "indisponible"
	if C_Bank and type(C_Bank.FetchNumPurchasedBankTabs) == "function" then
		local countOK, count = pcall(C_Bank.FetchNumPurchasedBankTabs, Enum.BankType.Account)
		if countOK then
			purchasedCount = count
		end
	end
	if C_Bank and type(C_Bank.CanPurchaseBankTab) == "function" then
		local purchaseOK, purchase = pcall(C_Bank.CanPurchaseBankTab, Enum.BankType.Account)
		if purchaseOK then
			canPurchase = purchase
		end
	end
	Debug("ElvUI: token=" .. tostring(token)
		.. " actuel=" .. tostring(bags.BankTab)
		.. " cible=" .. tostring(accountTabID)
		.. " canView=" .. tostring(canView)
		.. " purchased=" .. tostring(purchasedCount)
		.. " canPurchase=" .. tostring(canPurchase)
		.. " SelectBankTab=" .. tostring(type(bags.SelectBankTab) == "function")
		.. " ShowBankTab=" .. tostring(type(bags.ShowBankTab) == "function")
		.. " BankPanel.selected=" .. tostring(_G.BankPanel and _G.BankPanel.selectedTabID))

	if not (accountTabID and canView) then
		Debug("ElvUI: impossible de sélectionner le tab")
		return false
	end

	if bags.BankTab == accountTabID then
		Debug("ElvUI: warbank déjà sélectionnée")
		return true
	end

	local selectBankTab = bags.SelectBankTab
	local ok, errorMessage
	if type(selectBankTab) == "function" then
		Debug("ElvUI: appel SelectBankTab(" .. tostring(accountTabID) .. ")")
		ok, errorMessage = pcall(selectBankTab, bags, bankFrame, accountTabID)
	elseif type(bags.ShowBankTab) == "function" then
		Debug("ElvUI: appel fallback ShowBankTab(" .. tostring(accountTabID) .. ")")
		ok, errorMessage = pcall(bags.ShowBankTab, bags, bankFrame, accountTabID)
	end

	if ok and type(bags.SetBankTabs) == "function" then
		pcall(bags.SetBankTabs, bags, bankFrame)
	end

	local iconsOK, iconsError
	if type(bags.BankTabs_UpdateIcons) == "function" then
		iconsOK, iconsError = pcall(bags.BankTabs_UpdateIcons, bags, Enum.BankType.Account)
	end

	local layoutOK, layoutError
	if type(bags.Layout) == "function" then
		layoutOK, layoutError = pcall(bags.Layout, bags, true)
	end

	local panel = _G.BankPanel or (_G.BankFrame and _G.BankFrame.BankPanel)
	local panelBankTypeOK, panelBankTypeError
	local panelRefreshOK, panelRefreshError
	local panelSlotsOK, panelSlotsError
	if panel and type(panel.SetBankType) == "function" then
		panelBankTypeOK, panelBankTypeError = pcall(panel.SetBankType, panel, Enum.BankType.Account)
	end
	if panel and type(panel.RefreshBankTabs) == "function" then
		panelRefreshOK, panelRefreshError = pcall(panel.RefreshBankTabs, panel)
	end
	if panel and type(panel.GenerateItemSlotsForSelectedTab) == "function" then
		panelSlotsOK, panelSlotsError = pcall(panel.GenerateItemSlotsForSelectedTab, panel)
	end

	Debug("ElvUI: résultat ok=" .. tostring(ok)
		.. " erreur=" .. tostring(errorMessage)
		.. " actuelAprès=" .. tostring(bags.BankTab)
		.. " BankPanel.selectedAprès=" .. tostring(_G.BankPanel and _G.BankPanel.selectedTabID)
		.. " refreshIcons=" .. tostring(iconsOK)
		.. " refreshErreur=" .. tostring(iconsError)
		.. " layout=" .. tostring(layoutOK)
		.. " layoutErreur=" .. tostring(layoutError)
		.. " panelSetBankType=" .. tostring(panelBankTypeOK)
		.. " panelBankTypeErreur=" .. tostring(panelBankTypeError)
		.. " panelRefresh=" .. tostring(panelRefreshOK)
		.. " panelRefreshErreur=" .. tostring(panelRefreshError)
		.. " panelSlots=" .. tostring(panelSlotsOK)
		.. " panelSlotsErreur=" .. tostring(panelSlotsError))
	return ok and bags.BankTab == accountTabID
end

local function QueueSelectAccountBank()
	pendingSwitchToken = pendingSwitchToken + 1
	local token = pendingSwitchToken
	Debug("queue token=" .. tostring(token))

	for _, delay in ipairs({ 0, 0.05, 0.15, 0.3, 0.6 }) do
		C_Timer.After(delay, function()
			TrySelectElvUIAccountBank(token)
			TrySelectAccountBank(token)
		end)
	end
end

SLASH_YAYAWARBANDBANKDEFAULT1 = "/ywbdebug"
SlashCmdList.YAYAWARBANDBANKDEFAULT = function(message)
	local command = string.lower(message or "")
	if command == "off" then
		debugEnabled = false
		print("|cff00ff98YayaWarbandBankDefault:|r debug désactivé")
	elseif command == "on" then
		debugEnabled = true
		Debug("debug activé")
	elseif command == "retry" then
		debugEnabled = true
		Debug("nouvel essai demandé")
		QueueSelectAccountBank()
	else
		print("|cff00ff98YayaWarbandBankDefault:|r /ywbdebug on|off|retry")
	end
end

local function InstallElvUIHooks()
	if elvUIHooksInstalled then
		return true
	end

	local bags = GetElvUIBags()
	if not (bags and type(bags.OpenBank) == "function" and type(hooksecurefunc) == "function") then
		Debug("ElvUI: hook OpenBank impossible, module indisponible")
		return false
	end

	hooksecurefunc(bags, "OpenBank", function()
		Debug("ElvUI: OpenBank hook appelé")
		QueueSelectAccountBank()
	end)
	elvUIHooksInstalled = true
	Debug("ElvUI: hook OpenBank installé")
	return true
end

local function InstallHooks()
	local bankFrame = _G.BankFrame
	if not hooksInstalled and bankFrame and type(bankFrame.HookScript) == "function" then
		hooksInstalled = true
		bankFrame:HookScript("OnShow", QueueSelectAccountBank)
		Debug("Blizzard: hook OnShow installé")
	end

	InstallElvUIHooks()
	return hooksInstalled or elvUIHooksInstalled
end

eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("BANKFRAME_OPENED")
eventFrame:RegisterEvent("BANK_TABS_CHANGED")
eventFrame:RegisterEvent("BANK_TAB_SETTINGS_UPDATED")
eventFrame:SetScript("OnEvent", function(_, event, ...)
	Debug("event " .. tostring(event) .. " reçu")
	if event == "ADDON_LOADED" then
		local loadedAddonName = ...
		Debug("ADDON_LOADED: " .. tostring(loadedAddonName))
		if loadedAddonName ~= addonName
			and loadedAddonName ~= "Blizzard_UIPanels_Game"
			and loadedAddonName ~= "Blizzard_BankUI"
			and loadedAddonName ~= "ElvUI" then
			return
		end

		InstallHooks()
		return
	end

	InstallHooks()
	if event == "BANKFRAME_OPENED" then
		QueueSelectAccountBank()
	elseif event == "BANK_TABS_CHANGED" or event == "BANK_TAB_SETTINGS_UPDATED" then
		local bags = GetElvUIBags()
		local bankFrame = bags and bags.BankFrame
		Debug("bank tabs update: bankType=" .. tostring((...)))
		if bankFrame and type(bankFrame.IsShown) == "function" and bankFrame:IsShown() then
			QueueSelectAccountBank()
		end
	end
end)
