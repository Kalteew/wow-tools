local ADDON_NAME = ...

local AddOns = C_AddOns or {}
local GetNumAddOnsCompat = AddOns.GetNumAddOns or GetNumAddOns
local GetAddOnInfoCompat = AddOns.GetAddOnInfo or GetAddOnInfo
local GetAddOnEnableStateCompat = AddOns.GetAddOnEnableState or function(nameOrIndex, character)
	return GetAddOnEnableState(character, nameOrIndex)
end
local EnableAddOnCompat = AddOns.EnableAddOn or EnableAddOn
local DisableAddOnCompat = AddOns.DisableAddOn or DisableAddOn
local SaveAddOnsCompat = AddOns.SaveAddOns or SaveAddOns

local DB
local currentCharacterId
local currentCharacterGuid
local mainFrame
local selectedProfileName
local profileButtons = {}
local characterRows = {}
local scrollChild
local statusText
local selectedProfileText
local selectAllButton
local selectUnassignedButton
local clearSelectionButton
local bulkApplyButton
local selectedCharacterIds = {}
local characterIdsByIndex = {}
local lastSelectedCharacterIndex
local reloadQueued = false
local ToggleSelectedCharacter

local function Print(message)
	DEFAULT_CHAT_FRAME:AddMessage("|cff00ccffYayaAddonProfiles|r: " .. message)
end

local function GetSamDb()
	return SimpleAddonManagerDB
end

local function GetCharacterId()
	local name = UnitNameUnmodified and UnitNameUnmodified("player") or UnitName("player")
	local realm = GetRealmName()
	if not realm or realm == "" then
		realm = select(2, UnitFullName("player"))
	end
	return (name or "Unknown") .. "-" .. (realm or "Unknown")
end

local function EnsureDb()
	YayaAddonProfilesDB = YayaAddonProfilesDB or {}
	DB = YayaAddonProfilesDB
	DB.version = 3
	DB.assignments = DB.assignments or {}
	DB.characters = DB.characters or {}
end

local function RememberCharacter(characterId, guid, classFile, color)
	local character = DB.characters[characterId] or {}
	character.id = characterId
	character.guid = guid or character.guid
	character.class = classFile or character.class
	character.color = color or character.color or "ffffffff"
	DB.characters[characterId] = character
	return character
end

local function SeedKnownCharacters()
	local samDb = GetSamDb()
	if not samDb then
		return
	end

	for id, profile in pairs(samDb.autoProfile or {}) do
		RememberCharacter(id, profile.guid, nil, profile.playerColor)
	end

	for realm, characters in pairs((samDb.config or {}).characterList2 or {}) do
		for guid, info in pairs(characters) do
			if info.name then
				local color = RAID_CLASS_COLORS[info.class]
				RememberCharacter(info.name .. "-" .. realm, guid, info.class, color and color.colorStr)
			end
		end
	end
end

local function SortedProfileNames()
	local names = {}
	for name in pairs((GetSamDb() or {}).sets or {}) do
		table.insert(names, name)
	end
	table.sort(names, function(left, right)
		return left:lower() < right:lower()
	end)
	return names
end

local function ResolveProfileName(query)
	if not query or query == "" then
		return nil
	end
	local profiles = (GetSamDb() or {}).sets or {}
	if profiles[query] then
		return query
	end
	local wanted = query:lower()
	for name in pairs(profiles) do
		if name:lower() == wanted then
			return name
		end
	end
	return nil
end

local function AddProfileAddons(profileName, desired, visiting, visited)
	if visited[profileName] then
		return true
	end
	if visiting[profileName] then
		return false, "dependance circulaire: " .. profileName
	end

	local profile = ((GetSamDb() or {}).sets or {})[profileName]
	if not profile then
		return false, "profil introuvable: " .. profileName
	end

	visiting[profileName] = true
	for addonName, enabled in pairs(profile.addons or {}) do
		if enabled then
			desired[addonName] = true
		end
	end
	for childName, enabled in pairs(profile.subSets or {}) do
		if enabled then
			local ok, reason = AddProfileAddons(childName, desired, visiting, visited)
			if not ok then
				return false, reason
			end
		end
	end
	visiting[profileName] = nil
	visited[profileName] = true
	return true
end

local function BuildDesiredAddons(profileName)
	local desired = {}
	local ok, reason = AddProfileAddons(profileName, desired, {}, {})
	if not ok then
		return nil, reason
	end

	-- The manager and this enforcer must survive every profile switch.
	desired.SimpleAddonManager = true
	desired[ADDON_NAME] = true
	for addonName, state in pairs((GetSamDb() or {}).lock and (GetSamDb().lock.addons or {}) or {}) do
		if state.enabled then
			desired[addonName] = true
		end
	end
	return desired
end

local function IsAddonEnabled(addonIndexOrName, characterGuid)
	return GetAddOnEnableStateCompat(addonIndexOrName, characterGuid) ~= 0
end

local function ProfileMatches(profileName)
	local desired, reason = BuildDesiredAddons(profileName)
	if not desired then
		return false, reason
	end

	for addonIndex = 1, GetNumAddOnsCompat() do
		local addonName, _, _, _, loadReason = GetAddOnInfoCompat(addonIndex)
		if addonName and loadReason ~= "MISSING" and IsAddonEnabled(addonIndex, currentCharacterGuid) ~= (desired[addonName] == true) then
			return false
		end
	end
	return true
end

local function QueueReload()
	if reloadQueued then
		return
	end
	reloadQueued = true
	C_Timer.After(0.2, ReloadUI)
end

local function ApplyProfile(profileName, announce)
	local desired, reason = BuildDesiredAddons(profileName)
	if not desired then
		Print("Profil non applique : " .. reason)
		return false
	end

	local changed = false
	for addonIndex = 1, GetNumAddOnsCompat() do
		local addonName, _, _, _, loadReason = GetAddOnInfoCompat(addonIndex)
		if addonName and loadReason ~= "MISSING" then
			local shouldEnable = desired[addonName] == true
			if IsAddonEnabled(addonIndex, currentCharacterGuid) ~= shouldEnable then
				changed = true
				if shouldEnable then
					EnableAddOnCompat(addonIndex, currentCharacterGuid)
				else
					DisableAddOnCompat(addonIndex, currentCharacterGuid)
				end
			end
		end
	end

	if changed then
		if SaveAddOnsCompat then
			SaveAddOnsCompat()
		end
		if announce then
			Print("Profil " .. profileName .. " reapplique. Reload UI...")
		end
		QueueReload()
	end
	return changed
end

local function EnableEnforcerForCharacter(character, saveImmediately)
	if not character.guid then
		return
	end
	EnableAddOnCompat("SimpleAddonManager", character.guid)
	EnableAddOnCompat(ADDON_NAME, character.guid)
	if saveImmediately and SaveAddOnsCompat then
		SaveAddOnsCompat()
	end
end

local function AssignProfile(characterId, profileName)
	local canonicalProfileName = ResolveProfileName(profileName)
	if not canonicalProfileName then
		Print("Profil SAM introuvable : " .. (profileName or ""))
		return false
	end
	DB.assignments[characterId] = canonicalProfileName
	local character = DB.characters[characterId] or RememberCharacter(characterId)
	EnableEnforcerForCharacter(character, true)
	if characterId == currentCharacterId then
		ApplyProfile(canonicalProfileName, true)
	else
		Print(characterId .. " -> " .. canonicalProfileName)
	end
	return true
end

local function SortedCharacters()
	local characters = {}
	for id, character in pairs(DB.characters) do
		table.insert(characters, character)
	end
	table.sort(characters, function(left, right)
		return left.id:lower() < right.id:lower()
	end)
	return characters
end

local function CreateButton(parent, text, width, height)
	local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	button:SetSize(width, height)
	button:SetText(text)
	return button
end

local function GetSelectedCharacterCount()
	local count = 0
	for _ in pairs(selectedCharacterIds) do
		count = count + 1
	end
	return count
end

local function ClearSelectedCharacters()
	for characterId in pairs(selectedCharacterIds) do
		selectedCharacterIds[characterId] = nil
	end
	lastSelectedCharacterIndex = nil
end

local function SelectAllCharacters()
	ClearSelectedCharacters()
	for characterId in pairs(DB.characters) do
		selectedCharacterIds[characterId] = true
	end
end

local function SelectUnassignedCharacters()
	ClearSelectedCharacters()
	for characterId in pairs(DB.characters) do
		if not DB.assignments[characterId] then
			selectedCharacterIds[characterId] = true
		end
	end
end

local function RefreshUi()
	if not mainFrame then
		return
	end

	local profileNames = SortedProfileNames()
	if selectedProfileName and not ResolveProfileName(selectedProfileName) then
		selectedProfileName = nil
	end
	if not selectedProfileName then
		selectedProfileName = profileNames[1]
	end
	local selectedCount = GetSelectedCharacterCount()
	selectedProfileText:SetText("Profil choisi : " .. (selectedProfileName or "aucun") .. " | " .. selectedCount .. " selectionne(s)")
	bulkApplyButton:SetText("Attribuer (" .. selectedCount .. ")")
	bulkApplyButton:SetEnabled(selectedProfileName ~= nil and selectedCount > 0)

	for index, profileName in ipairs(profileNames) do
		local button = profileButtons[index]
		if not button then
			button = CreateButton(mainFrame, "", 170, 24)
			button:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 18, -74 - ((index - 1) * 27))
			profileButtons[index] = button
		end
		button.profileName = profileName
		button:SetText(profileName)
		button:SetEnabled(profileName ~= selectedProfileName)
		button:SetScript("OnClick", function(self)
			selectedProfileName = self.profileName
			RefreshUi()
		end)
		button:Show()
	end
	for index = #profileNames + 1, #profileButtons do
		profileButtons[index]:Hide()
	end

	local characters = SortedCharacters()
	for index, character in ipairs(characters) do
		characterIdsByIndex[index] = character.id
		local row = characterRows[index]
		if not row then
			row = CreateFrame("Frame", nil, scrollChild)
			row:SetSize(400, 26)
			row:EnableMouse(true)
			row.select = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
			row.select:SetPoint("LEFT", 0, 0)
			row.select:SetSize(24, 24)
			row.name = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
			row.name:SetPoint("LEFT", row.select, "RIGHT", 2, 0)
			row.name:SetWidth(185)
			row.name:SetJustifyH("LEFT")
			row.name:SetWordWrap(false)
			row.name:SetMaxLines(1)
			row.assignment = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
			row.assignment:SetPoint("LEFT", row.name, "RIGHT", 6, 0)
			row.assignment:SetWidth(178)
			row.assignment:SetJustifyH("LEFT")
			row.assignment:SetWordWrap(false)
			row.assignment:SetMaxLines(1)
			row:SetScript("OnEnter", function(self)
				GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
				GameTooltip:SetText(self.character.id)
				GameTooltip:AddLine("Profil : " .. (DB.assignments[self.character.id] or "aucun"), 1, 1, 1)
				GameTooltip:Show()
			end)
			row:SetScript("OnLeave", GameTooltip_Hide)
			characterRows[index] = row
		end
		row:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -((index - 1) * 27))
		row.character = character
		row.characterIndex = index
		row.name:SetText("|c" .. (character.color or "ffffffff") .. character.id .. "|r")
		row.assignment:SetText(DB.assignments[character.id] or "-")
		row.select:SetChecked(selectedCharacterIds[character.id] == true)
		row.select:SetScript("OnClick", function(self)
			local parent = self:GetParent()
			ToggleSelectedCharacter(parent.character.id, parent.characterIndex)
		end)
		row:Show()
	end
	for index = #characters + 1, #characterRows do
		characterRows[index]:Hide()
		characterIdsByIndex[index] = nil
	end
	scrollChild:SetHeight(math.max(1, #characters * 27))

	local assigned = DB.assignments[currentCharacterId]
	local active, reason = assigned and ProfileMatches(assigned) or false, nil
	if assigned then
		active, reason = ProfileMatches(assigned)
	end
	statusText:SetText("Ce perso : " .. currentCharacterId .. " | " .. (assigned and (active and "conforme" or (reason or "correction au prochain login")) or "sans profil"))
end

ToggleSelectedCharacter = function(characterId, characterIndex)
	if IsShiftKeyDown() and lastSelectedCharacterIndex then
		local firstIndex = math.min(lastSelectedCharacterIndex, characterIndex)
		local lastIndex = math.max(lastSelectedCharacterIndex, characterIndex)
		for index = firstIndex, lastIndex do
			selectedCharacterIds[characterIdsByIndex[index]] = true
		end
	elseif selectedCharacterIds[characterId] then
		selectedCharacterIds[characterId] = nil
	else
		selectedCharacterIds[characterId] = true
	end
	lastSelectedCharacterIndex = characterIndex
	RefreshUi()
end

local function ApplySelectedProfile()
	local profileName = ResolveProfileName(selectedProfileName)
	local count = GetSelectedCharacterCount()
	if not profileName or count == 0 then
		return
	end

	local includesCurrentCharacter = false
	for characterId in pairs(selectedCharacterIds) do
		DB.assignments[characterId] = profileName
		EnableEnforcerForCharacter(DB.characters[characterId], false)
		if characterId == currentCharacterId then
			includesCurrentCharacter = true
		end
	end
	if SaveAddOnsCompat then
		SaveAddOnsCompat()
	end
	Print(count .. " personnage(s) -> " .. profileName)
	ClearSelectedCharacters()
	if includesCurrentCharacter then
		ApplyProfile(profileName, true)
	end
	RefreshUi()
end

local function ToggleUi()
	if mainFrame:IsShown() then
		mainFrame:Hide()
	else
		RefreshUi()
		mainFrame:Show()
	end
end

local function CreateUi()
	mainFrame = CreateFrame("Frame", ADDON_NAME .. "Frame", UIParent, "BasicFrameTemplateWithInset")
	mainFrame:SetSize(650, 470)
	mainFrame:SetPoint("CENTER")
	mainFrame:SetMovable(true)
	mainFrame:EnableMouse(true)
	mainFrame:RegisterForDrag("LeftButton")
	mainFrame:SetScript("OnDragStart", mainFrame.StartMoving)
	mainFrame:SetScript("OnDragStop", mainFrame.StopMovingOrSizing)
	mainFrame:Hide()
	table.insert(UISpecialFrames, mainFrame:GetName())

	local title = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	title:SetPoint("TOP", 0, -6)
	title:SetText("Yaya Addon Profiles")

	statusText = mainFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	statusText:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 18, -36)
	statusText:SetWidth(614)
	statusText:SetJustifyH("LEFT")
	statusText:SetWordWrap(false)

	local profileHeader = mainFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	profileHeader:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 18, -56)
	profileHeader:SetText("Profils SAM")

	local charactersHeader = mainFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	charactersHeader:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 205, -56)
	charactersHeader:SetText("Personnages connus — selectionne, puis attribue en lot")

	selectedProfileText = mainFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	selectedProfileText:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 205, -75)
	selectedProfileText:SetWidth(400)
	selectedProfileText:SetJustifyH("LEFT")
	selectedProfileText:SetWordWrap(false)
	selectedProfileText:SetMaxLines(1)

	selectUnassignedButton = CreateButton(mainFrame, "Sans profil", 94, 22)
	selectAllButton = CreateButton(mainFrame, "Tout", 48, 22)
	selectAllButton:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 205, -95)
	selectAllButton:SetScript("OnClick", function()
		SelectAllCharacters()
		RefreshUi()
	end)

	selectUnassignedButton:SetSize(82, 22)
	selectUnassignedButton:SetPoint("LEFT", selectAllButton, "RIGHT", 8, 0)
	selectUnassignedButton:SetScript("OnClick", function()
		SelectUnassignedCharacters()
		RefreshUi()
	end)

	clearSelectionButton = CreateButton(mainFrame, "Aucun", 60, 22)
	clearSelectionButton:SetPoint("LEFT", selectUnassignedButton, "RIGHT", 8, 0)
	clearSelectionButton:SetScript("OnClick", function()
		ClearSelectedCharacters()
		RefreshUi()
	end)

	bulkApplyButton = CreateButton(mainFrame, "Attribuer", 186, 22)
	bulkApplyButton:SetPoint("LEFT", clearSelectionButton, "RIGHT", 8, 0)
	bulkApplyButton:SetScript("OnClick", ApplySelectedProfile)

	local scrollFrame = CreateFrame("ScrollFrame", nil, mainFrame, "UIPanelScrollFrameTemplate")
	scrollFrame:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 205, -124)
	scrollFrame:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -32, 18)
	scrollChild = CreateFrame("Frame", nil, scrollFrame)
	scrollChild:SetSize(400, 1)
	scrollFrame:SetScrollChild(scrollChild)
end

local function PrintHelp()
	Print("/yap ouvre la fenetre")
	Print("/yap profile <profil> : attribue le profil SAM au perso courant")
	Print("/yap set <perso-royaume> <profil> : attribution hors ligne")
	Print("/yap status : affiche l'attribution courante")
end

local function HandleSlashCommand(message)
	message = (message or ""):match("^%s*(.-)%s*$")
	if message == "" then
		ToggleUi()
		return
	end

	local command, rest = message:match("^(%S+)%s*(.-)$")
	command = (command or ""):lower()
	if command == "profile" then
		AssignProfile(currentCharacterId, rest)
		RefreshUi()
		return
	end
	if command == "set" then
		local characterId, profileName = rest:match("^(%S+)%s+(.+)$")
		if characterId and profileName then
			AssignProfile(characterId, profileName)
			RefreshUi()
		else
			Print("Usage : /yap set Perso-Royaume ProfilSAM")
		end
		return
	end
	if command == "status" then
		Print("Profil de " .. currentCharacterId .. " : " .. (DB.assignments[currentCharacterId] or "aucun"))
		return
	end
	PrintHelp()
end

local function OnPlayerLogin()
	EnsureDb()
	currentCharacterId = GetCharacterId()
	currentCharacterGuid = UnitGUID("player")
	local _, classFile = UnitClass("player")
	local color = RAID_CLASS_COLORS[classFile]
	RememberCharacter(currentCharacterId, currentCharacterGuid, classFile, color and color.colorStr)
	SeedKnownCharacters()
	CreateUi()

	SLASH_YAYAADDONPROFILES1 = "/yap"
	SLASH_YAYAADDONPROFILES2 = "/yayaaddons"
	SlashCmdList.YAYAADDONPROFILES = HandleSlashCommand

	local assignedProfile = DB.assignments[currentCharacterId]
	if assignedProfile then
		ApplyProfile(assignedProfile, true)
	end
end

function YayaAddonProfiles_OnAddonCompartmentClick()
	if mainFrame then
		ToggleUi()
	end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", OnPlayerLogin)
