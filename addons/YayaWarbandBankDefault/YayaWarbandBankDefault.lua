local addonName = ...

local eventFrame = CreateFrame("Frame")
local pendingSwitchToken = 0
local hooksInstalled = false

local function IsClickableButton(frame)
	return frame
		and type(frame.IsObjectType) == "function"
		and frame:IsObjectType("Button")
		and type(frame.IsShown) == "function"
		and frame:IsShown()
		and type(frame.IsEnabled) == "function"
		and frame:IsEnabled()
end

local function IsSelectedTab(frame)
	if not frame then
		return false
	end

	if type(frame.IsSelected) == "function" then
		local ok, selected = pcall(frame.IsSelected, frame)
		if ok and selected ~= nil then
			return selected == true
		end
	end

	return frame.selected == true
		or frame.isSelected == true
		or (frame.Selected and type(frame.Selected.IsShown) == "function" and frame.Selected:IsShown())
end

local function GetFrameText(frame)
	if not frame then
		return nil
	end

	for _, key in ipairs({ "Text", "Label", "text" }) do
		local region = frame[key]
		if region and type(region.GetText) == "function" then
			local text = region:GetText()
			if type(text) == "string" and text ~= "" then
				return text
			end
		end
	end

	if type(frame.GetText) == "function" then
		local text = frame:GetText()
		if type(text) == "string" and text ~= "" then
			return text
		end
	end

	return nil
end

local function GetLowerFrameName(frame)
	if not (frame and type(frame.GetName) == "function") then
		return nil
	end

	local name = frame:GetName()
	if type(name) ~= "string" or name == "" then
		return nil
	end

	return name:lower()
end

local function GetParentChainScore(frame)
	local score = 0
	local depth = 0
	local current = frame

	while current and depth < 8 do
		local lowerName = GetLowerFrameName(current)
		if lowerName then
			if lowerName:find("tsm", 1, true) then
				return nil
			end
			if lowerName:find("bankframe", 1, true) then
				score = score + 60
			end
			if lowerName:find("tab", 1, true) then
				score = score + 20
			end
			if lowerName:find("accountbank", 1, true) or lowerName:find("warband", 1, true) then
				score = score + 40
			end
		end

		if type(current.GetParent) ~= "function" then
			break
		end

		current = current:GetParent()
		depth = depth + 1
	end

	return score
end

local function ScoreWarbandTab(frame)
	if not IsClickableButton(frame) or IsSelectedTab(frame) then
		return nil
	end

	local parentScore = GetParentChainScore(frame)
	if not parentScore then
		return nil
	end

	local name = type(frame.GetName) == "function" and frame:GetName() or nil
	local text = GetFrameText(frame)
	local score = parentScore

	if type(name) == "string" then
		local lowerName = name:lower()
		if lowerName:find("accountbank", 1, true) then
			score = score + 100
		end
		if lowerName:find("warband", 1, true) then
			score = score + 100
		end
		if lowerName:find("banktab", 1, true) then
			score = score + 20
		end
	end

	if type(text) == "string" then
		local lowerText = text:lower()
		if lowerText:find("warband", 1, true) then
			score = score + 50
		end
		if lowerText:find("bataillon", 1, true) then
			score = score + 50
		end
		if lowerText:find("account", 1, true) then
			score = score + 40
		end
	end

	if score <= 0 then
		return nil
	end

	return score
end

local function FindBestWarbandTab(root)
	local bestFrame
	local bestScore

	local function Visit(frame, depth)
		if not frame or depth > 8 then
			return
		end

		local score = ScoreWarbandTab(frame)
		if score and (not bestScore or score > bestScore) then
			bestScore = score
			bestFrame = frame
		end

		if type(frame.GetChildren) ~= "function" then
			return
		end

		for index = 1, select("#", frame:GetChildren()) do
			Visit(select(index, frame:GetChildren()), depth + 1)
		end
	end

	Visit(root, 0)
	return bestFrame
end

local function FindSelectedWarbandTab(root)
	local selectedFrame

	local function Visit(frame, depth)
		if selectedFrame or not frame or depth > 8 then
			return
		end

		local parentScore = GetParentChainScore(frame)
		if parentScore and parentScore > 0 and IsSelectedTab(frame) then
			local name = GetLowerFrameName(frame)
			local text = GetFrameText(frame)
			local lowerText = type(text) == "string" and text:lower() or nil
			if (name and (name:find("accountbank", 1, true) or name:find("warband", 1, true)))
				or (lowerText and (lowerText:find("warband", 1, true) or lowerText:find("bataillon", 1, true) or lowerText:find("account", 1, true))) then
				selectedFrame = frame
				return
			end
		end

		if type(frame.GetChildren) ~= "function" then
			return
		end

		for index = 1, select("#", frame:GetChildren()) do
			Visit(select(index, frame:GetChildren()), depth + 1)
		end
	end

	Visit(root, 0)
	return selectedFrame
end

local function TrySelectWarbandBank(token)
	if token ~= pendingSwitchToken then
		return false
	end

	local bankFrame = _G.BankFrame
	if not (bankFrame and type(bankFrame.IsShown) == "function" and bankFrame:IsShown()) then
		return false
	end

	if FindSelectedWarbandTab(bankFrame) then
		return true
	end

	local button = FindBestWarbandTab(bankFrame)
	if button and type(button.Click) == "function" then
		button:Click()
		return FindSelectedWarbandTab(bankFrame) ~= nil
	end

	return false
end

local function QueueSelectWarbandBank()
	pendingSwitchToken = pendingSwitchToken + 1
	local token = pendingSwitchToken

	for _, delay in ipairs({ 0, 0.05, 0.15, 0.3 }) do
		C_Timer.After(delay, function()
			TrySelectWarbandBank(token)
		end)
	end
end

local function InstallHooks()
	if hooksInstalled then
		return
	end

	if not (BankFrame and type(BankFrame.HookScript) == "function") then
		return
	end

	hooksInstalled = true
	BankFrame:HookScript("OnShow", QueueSelectWarbandBank)
end

eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", function(_, event, ...)
	if event ~= "ADDON_LOADED" then
		return
	end

	local loadedAddonName = ...
	if loadedAddonName == addonName or loadedAddonName == "Blizzard_BankUI" or loadedAddonName == "Blizzard_UIPanels_Game" then
		InstallHooks()
	end
end)
