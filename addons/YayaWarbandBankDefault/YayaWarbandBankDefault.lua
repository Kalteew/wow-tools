local addonName = ...

local eventFrame = CreateFrame("Frame")
local pendingSwitchToken = 0
local hooksInstalled = false

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

local function TrySelectAccountBank(token)
	if token ~= pendingSwitchToken then
		return false
	end

	local bankFrame = _G.BankFrame
	if not (bankFrame and type(bankFrame.IsShown) == "function" and bankFrame:IsShown()) then
		return false
	end

	if IsAccountBankActive(bankFrame) then
		return true
	end

	local accountTabID = bankFrame.accountBankTabID
	if not (accountTabID and type(bankFrame.SetTab) == "function" and CanViewAccountBank()) then
		return false
	end

	local ok = pcall(bankFrame.SetTab, bankFrame, accountTabID)
	return ok and IsAccountBankActive(bankFrame)
end

local function QueueSelectAccountBank()
	pendingSwitchToken = pendingSwitchToken + 1
	local token = pendingSwitchToken

	for _, delay in ipairs({ 0, 0.05, 0.15, 0.3, 0.6 }) do
		C_Timer.After(delay, function()
			TrySelectAccountBank(token)
		end)
	end
end

local function InstallHooks()
	if hooksInstalled then
		return true
	end

	local bankFrame = _G.BankFrame
	if not (bankFrame and type(bankFrame.HookScript) == "function") then
		return false
	end

	hooksInstalled = true
	bankFrame:HookScript("OnShow", QueueSelectAccountBank)
	return true
end

eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("BANKFRAME_OPENED")
eventFrame:SetScript("OnEvent", function(_, event, ...)
	if event == "ADDON_LOADED" then
		local loadedAddonName = ...
		if loadedAddonName ~= addonName
			and loadedAddonName ~= "Blizzard_UIPanels_Game"
			and loadedAddonName ~= "Blizzard_BankUI" then
			return
		end

		InstallHooks()
		return
	end

	InstallHooks()
	if event == "BANKFRAME_OPENED" then
		QueueSelectAccountBank()
	end
end)
