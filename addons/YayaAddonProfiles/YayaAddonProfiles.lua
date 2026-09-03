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
local GetAddOnDependenciesCompat = AddOns.GetAddOnDependencies or GetAddOnDependencies

local UI = YayaCore.UI

local DB
local currentCharacterId
local currentCharacterGuid
local mainFrame
local selectedProfileName
local profileList
local characterList
local statusText
local selectedProfileText
local selectAllButton
local selectUnassignedButton
local clearSelectionButton
local bulkApplyButton
local promptReloadCheck
local sortHeaders = {}
local selectedCharacterIds = {}
local characterIdsByIndex = {}
local lastSelectedCharacterIndex
local reloadQueued = false
local pendingLoginProfile
local ToggleSelectedCharacter
local Debug
local SaveAddonSettings
local DEBUG_LOG_LIMIT = 80

-- Geometrie propre a cette fenetre. Tout ce que les tokens partages couvrent
-- (marges, hauteurs de ligne, bande d'action) est lu directement sur UI.
local LAYOUT = {
	frameW = 720,
	frameH = 520,
	profileW = 176,
	checkW = 18,
	levelW = 34,
	assignmentW = 160,
}
local REGION_CODES = {
	[1] = "US",
	[2] = "KR",
	[3] = "EU",
	[4] = "TW",
	[5] = "CN",
}

local function Print(message)
	DEFAULT_CHAT_FRAME:AddMessage(UI.HEX.accent .. "YayaAddonProfiles" .. UI.HEX.stop .. ": " .. message)
end

StaticPopupDialogs["YAYA_ADDON_PROFILES_RELOAD"] = {
	text = "Le profil d'addons a ete sauvegarde. Recharger l'interface pour l'activer maintenant ?",
	button1 = "Recharger",
	button2 = CANCEL,
	OnAccept = function()
		Debug("Reload facultatif accepte par l'utilisateur.")
		ReloadUI()
	end,
	OnCancel = function()
		reloadQueued = false
		Debug("Reload reporte a la prochaine connexion.")
	end,
	timeout = 0,
	whileDead = 1,
	hideOnEscape = 1,
	preferredIndex = 3,
}

Debug = function(message)
	if DB and DB.debug then
		Print("|cffaaaaaaDEBUG|r " .. message)
	end
end

local function RecordDebug(event, details)
	if not DB then
		return
	end
	DB.debugLog = DB.debugLog or {}
	-- Tampon circulaire : la purge precedente recopiait tout le journal a chaque
	-- entree au-dela de la limite.
	YayaCore.RingBuffer.Push(DB.debugLog, {
		time = time(),
		event = event,
		details = details,
	}, DEBUG_LOG_LIMIT)
end

SaveAddonSettings = function()
	if not SaveAddOnsCompat then
		RecordDebug("save-addons-error", { reason = "API indisponible" })
		Debug("SaveAddOns indisponible.")
		return false
	end
	local ok, result = pcall(SaveAddOnsCompat)
	RecordDebug("save-addons", {
		ok = ok,
		result = result,
	})
	if not ok then
		Debug("SaveAddOns en erreur : " .. tostring(result))
	end
	return ok
end

local function CountAddons(addons)
	local count = 0
	for _ in pairs(addons or {}) do
		count = count + 1
	end
	return count
end

local function PrintAddonList(prefix, addons, useDebug)
	if #addons == 0 then
		return
	end
	table.sort(addons)
	for first = 1, #addons, 6 do
		local last = math.min(first + 5, #addons)
		local message = prefix .. " : " .. table.concat(addons, ", ", first, last)
		if useDebug then
			Debug(message)
		else
			Print(message)
		end
	end
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
	DB.assignments = DB.assignments or {}
	DB.characters = DB.characters or {}
	if DB.debug == nil then
		DB.debug = true
	end
	-- Defaut silencieux : la liste d'addons est sauvegardee et prend effet a la
	-- prochaine connexion, sans fenetre de confirmation.
	if DB.promptReload == nil then
		DB.promptReload = false
	end
	DB.sortKey = DB.sortKey or "name"
	if DB.sortDesc == nil then
		DB.sortDesc = false
	end
	DB.debugLog = DB.debugLog or {}
end

-- Fusion champ par champ : un argument nil ne doit jamais effacer une valeur
-- connue, car SeedKnownCharacters rappelle cette fonction sans classe ni niveau.
local function RememberCharacter(characterId, guid, classFile, color, level, seenAt)
	local character = DB.characters[characterId] or {}
	character.id = characterId
	character.guid = guid or character.guid
	character.class = classFile or character.class
	character.color = color or character.color or "ffffffff"
	character.level = level or character.level
	character.lastSeen = seenAt or character.lastSeen
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

-- Choisit l'identifiant a conserver entre deux entrees du meme personnage.
-- GetCharacterId compose son identifiant avec GetRealmName, qui rend le royaume
-- avec ses espaces : c'est la forme qui sera regeneree a chaque connexion, donc
-- la forme canonique. Le reste du departage est deterministe pour ne pas
-- dependre de l'ordre de parcours de pairs.
local function PreferredCharacterId(left, right)
	local leftSpaced = left:find(" ", 1, true) ~= nil
	local rightSpaced = right:find(" ", 1, true) ~= nil
	if leftSpaced ~= rightSpaced then
		return leftSpaced and left or right
	end
	if #left ~= #right then
		return #left > #right and left or right
	end
	return left < right and left or right
end

-- Verse l'entree source dans l'entree conservee sans jamais ecraser une valeur
-- connue par un nil. Le niveau ne redescend jamais : le maximum est le bon.
local function MergeCharacterInto(keepId, dropId)
	local keep = DB.characters[keepId]
	local drop = DB.characters[dropId]
	if not keep or not drop or keepId == dropId then
		return false
	end

	keep.guid = keep.guid or drop.guid
	keep.class = keep.class or drop.class
	if keep.color == nil or keep.color == "ffffffff" then
		keep.color = drop.color or keep.color
	end

	local level = math.max(keep.level or 0, drop.level or 0)
	keep.level = level > 0 and level or nil

	if drop.lastSeen and (not keep.lastSeen or drop.lastSeen > keep.lastSeen) then
		keep.lastSeen = drop.lastSeen
	end
	if not DB.assignments[keepId] then
		DB.assignments[keepId] = DB.assignments[dropId]
	end

	DB.characters[dropId] = nil
	DB.assignments[dropId] = nil
	selectedCharacterIds[dropId] = nil
	return true
end

-- SeedKnownCharacters compose ses identifiants a partir des cles de royaume de
-- SimpleAddonManager, tantot avec espaces tantot sans : le meme personnage
-- pouvait exister sous deux entrees. Le seeding peut recreer un doublon apres
-- coup, donc la fusion tourne a chaque connexion et pas seulement une fois.
-- Effacer une cle existante pendant un parcours pairs est permis en Lua ; en
-- ajouter une ne l'est pas, et rien n'en ajoute ici.
local function MergeDuplicateCharacters()
	local firstPass = (DB.version or 0) < 4
	local byGuid = {}
	local mergedPairs = {}

	for characterId, character in pairs(DB.characters) do
		local guid = character.guid
		if guid then
			local known = byGuid[guid]
			if not known then
				byGuid[guid] = characterId
			else
				local keepId = PreferredCharacterId(known, characterId)
				local dropId = (keepId == known) and characterId or known
				if MergeCharacterInto(keepId, dropId) then
					mergedPairs[#mergedPairs + 1] = dropId .. " -> " .. keepId
				end
				byGuid[guid] = keepId
			end
		end
	end

	DB.version = 4

	if #mergedPairs > 0 then
		RecordDebug("merge-duplicates", {
			merged = #mergedPairs,
			pairs = mergedPairs,
			firstPass = firstPass,
		})
		Debug("Doublons de personnages fusionnes : " .. #mergedPairs .. ".")
	end
	return #mergedPairs
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

local function IsAddonEnabled(addonIndexOrName, characterGuid)
    return GetAddOnEnableStateCompat(addonIndexOrName, characterGuid) == 2
end

-- Addons que le client WoW reactive de lui-meme (dependances declarees,
-- chargement a la demande). Leur etat n'est pas pilote par le profil : les
-- comparer produisait un ecart a presque chaque connexion, donc un prompt de
-- reload quasi systematique qui banalisait la confirmation et noyait les vrais
-- changements de profil.
local CLIENT_MANAGED_ADDONS = {
	M33kAurasArchive = true,
	Simulationcraft = true,
}
local CLIENT_MANAGED_ADDON_PATTERNS = {
	"^BigWigs_",
	"^LittleWigs",
}

local function IsClientManagedAddon(addonName)
	if CLIENT_MANAGED_ADDONS[addonName] then
		return true
	end
	for _, pattern in ipairs(CLIENT_MANAGED_ADDON_PATTERNS) do
		if addonName:match(pattern) then
			return true
		end
	end
	return false
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

-- Un addon desire dont une dependance dure manque devient DEP_DISABLED au
-- prochain login : il ne charge pas, n'applique aucun profil et ne peut plus se
-- reparer, ce qui a deja desactive YayaCore puis toute la suite Yaya sur un
-- personnage. On ferme donc transitivement les dependances declarees de chaque
-- addon desire avant toute comparaison avec l'etat enable sauvegarde.
local function AddHardDependencies(desired)
	local added = {}
	if type(GetAddOnDependenciesCompat) ~= "function" then
		-- Repli minimal : la dependance commune de tous les addons Yaya.
		if not desired.YayaCore then
			desired.YayaCore = true
			table.insert(added, "YayaCore")
		end
		return added
	end

	local indexByName = {}
	for addonIndex = 1, GetNumAddOnsCompat() do
		local addonName = GetAddOnInfoCompat(addonIndex)
		if addonName then
			indexByName[addonName] = addonIndex
		end
	end

	local pending = {}
	for addonName in pairs(desired) do
		table.insert(pending, addonName)
	end

	while #pending > 0 do
		local addonName = table.remove(pending)
		local addonIndex = indexByName[addonName]
		if addonIndex then
			local dependencies = { GetAddOnDependenciesCompat(addonIndex) }
			for _, dependencyName in ipairs(dependencies) do
				if type(dependencyName) == "string" and dependencyName ~= ""
					and not desired[dependencyName] then
					desired[dependencyName] = true
					table.insert(added, dependencyName)
					table.insert(pending, dependencyName)
				end
			end
		end
	end

	return added
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
	-- Le journal d'erreurs doit survivre lui aussi : c'est lui qui capture les
	-- fautes des autres addons, et un profil qui le desactive rend tout
	-- diagnostic impossible sans que rien ne le signale. Il se charge avant les
	-- autres, d'ou le "!" dans son nom.
	desired["!YayaErrorLog"] = true

	local addedDependencies = AddHardDependencies(desired)
	if #addedDependencies > 0 then
		Debug("Dependances dures ajoutees au profil : " .. table.concat(addedDependencies, ", "))
	end

	-- Un addon gere par le client et absent du profil est aligne sur son etat
	-- courant, jamais corrige. S'il est explicitement dans le profil, le profil
	-- garde la main.
	for addonIndex = 1, GetNumAddOnsCompat() do
		local addonName = GetAddOnInfoCompat(addonIndex)
		if addonName and not desired[addonName] and IsClientManagedAddon(addonName) then
			desired[addonName] = IsAddonEnabled(addonIndex, currentCharacterGuid) or nil
		end
	end

	-- RaiderIO disables databases from foreign regions at startup. Keeping them
	-- in the comparison would create an enable/reload loop without loading data
	-- useful to the current client region.
	local ignoredRegionAddons = {}
	local regionCode = REGION_CODES[GetCurrentRegion and GetCurrentRegion()]
	if regionCode then
		for addonName in pairs(desired) do
			local databaseRegion = addonName:match("^RaiderIO_DB_([A-Z]+)_[FMR]$")
			if databaseRegion and databaseRegion ~= regionCode then
				desired[addonName] = nil
				table.insert(ignoredRegionAddons, addonName)
			end
		end
	end
	return desired, nil, ignoredRegionAddons, regionCode
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

local function PromptReload()
	-- La trace est ecrite dans les deux modes : elle dit qu'une correction attend
	-- la prochaine connexion, et OnPlayerLogin la relit.
	DB.reloadRequired = {
		time = time(),
		character = currentCharacterId,
		profile = DB.debugLastApply and DB.debugLastApply.profile,
	}
	RecordDebug("reload-required", DB.reloadRequired)

	if DB.promptReload ~= true then
		RecordDebug("reload-silent", DB.reloadRequired)
		Debug("Mode silencieux : profil sauvegarde, actif a la prochaine connexion.")
		return
	end

	if reloadQueued then
		Debug("Confirmation de reload deja affichee.")
		return
	end

	-- reloadQueued etait pose avant l'affichage et le retour de StaticPopup_Show
	-- n'etait pas inspecte : quand les quatre emplacements de popup sont occupes
	-- au login, la fenetre n'apparaissait jamais et tout appel suivant sortait en
	-- early-return, sans que rien ne le signale.
	local popup = StaticPopup_Show("YAYA_ADDON_PROFILES_RELOAD")
	if popup then
		reloadQueued = true
		Debug("Reload requis : confirmation utilisateur affichee.")
		return
	end

	Print("Profil d'addons sauvegarde. Tape |cffffd200/reload|r pour l'activer.")
	RecordDebug("reload-popup-unavailable", DB.reloadRequired)
	Debug("Reload requis : popup indisponible, message chat affiche.")
end

local function ApplyProfile(profileName, announce)
	local desired, reason, ignoredRegionAddons, regionCode = BuildDesiredAddons(profileName)
	if not desired then
		local details = {
			character = currentCharacterId,
			profile = profileName,
			error = reason,
		}
		DB.debugLastApply = details
		RecordDebug("apply-error", details)
		Debug("Application abandonnee : " .. reason)
		Print("Profil non applique : " .. reason)
		return false
	end

	local changed = false
	local enabledAddons = {}
	local disabledAddons = {}
	for addonIndex = 1, GetNumAddOnsCompat() do
		local addonName, _, _, _, loadReason = GetAddOnInfoCompat(addonIndex)
		if addonName and loadReason ~= "MISSING" then
			local shouldEnable = desired[addonName] == true
			if IsAddonEnabled(addonIndex, currentCharacterGuid) ~= shouldEnable then
				changed = true
				if shouldEnable then
					EnableAddOnCompat(addonIndex, currentCharacterGuid)
					table.insert(enabledAddons, addonName)
				else
					DisableAddOnCompat(addonIndex, currentCharacterGuid)
					table.insert(disabledAddons, addonName)
				end
			end
		end
	end

	local details = {
		character = currentCharacterId,
		guid = currentCharacterGuid,
		profile = profileName,
		desiredCount = CountAddons(desired),
		enabled = enabledAddons,
		disabled = disabledAddons,
		ignored = ignoredRegionAddons,
		region = regionCode,
		changed = changed,
	}
	DB.debugLastApply = details
	RecordDebug("apply", details)
	Debug("Profil=" .. profileName .. ", attendu=" .. details.desiredCount .. ", actives=" .. #enabledAddons .. ", desactives=" .. #disabledAddons .. ", ignorees=" .. #(ignoredRegionAddons or {}) .. ".")
	PrintAddonList("Activation", enabledAddons, true)
	PrintAddonList("Desactivation", disabledAddons, true)
	PrintAddonList("Ignore RaiderIO hors " .. (regionCode or "?"), ignoredRegionAddons or {}, true)

	if changed then
		if not SaveAddonSettings() then
			Print("Profil modifie en memoire, mais sa sauvegarde a echoue.")
			return changed
		end
		Debug("Configuration d'addons sauvegardee immediatement.")
		if announce then
			if DB.promptReload == true then
				Print("Profil " .. profileName
					.. " sauvegarde. Reload facultatif ; sinon il sera actif a la prochaine connexion.")
			else
				Print("Profil " .. profileName .. " sauvegarde. Il sera actif a la prochaine connexion.")
			end
		end
		PromptReload()
	end
	return changed
end

local function PrintDebugReport()
	local details = DB.debugLastApply
	if not details then
		Print("DEBUG : aucune application enregistree.")
		return
	end
	if details.error then
		Print("DEBUG dernier echec : " .. (details.profile or "aucun") .. " - " .. details.error)
		return
	end
	Print("DEBUG dernier profil : " .. (details.profile or "aucun") .. ", attendu=" .. (details.desiredCount or 0) .. ", actives=" .. #(details.enabled or {}) .. ", desactives=" .. #(details.disabled or {}) .. ", ignorees=" .. #(details.ignored or {}) .. ".")
	PrintAddonList("DEBUG activation", details.enabled or {}, false)
	PrintAddonList("DEBUG desactivation", details.disabled or {}, false)
	PrintAddonList("DEBUG ignore RaiderIO hors " .. (details.region or "?"), details.ignored or {}, false)
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

-- Comparateur de la liste de personnages. Le departage final par identifiant est
-- indispensable : les identifiants etant uniques, il fait de la relation un
-- ordre strict total, sans quoi table.sort leve "invalid order function for
-- sorting" sur certaines permutations.
local function CompareCharacters(left, right)
	local key = DB.sortKey or "name"
	local desc = DB.sortDesc == true

	if key == "level" then
		-- Un niveau inconnu finit la liste dans les deux sens.
		local leftKnown = left.level ~= nil
		local rightKnown = right.level ~= nil
		if leftKnown ~= rightKnown then
			return leftKnown
		end
		if leftKnown and left.level ~= right.level then
			if desc then
				return left.level > right.level
			end
			return left.level < right.level
		end
	elseif key == "profile" then
		-- Un personnage sans profil finit la liste dans les deux sens.
		local leftProfile = DB.assignments[left.id]
		local rightProfile = DB.assignments[right.id]
		if (leftProfile ~= nil) ~= (rightProfile ~= nil) then
			return leftProfile ~= nil
		end
		if leftProfile then
			local leftKey = leftProfile:lower()
			local rightKey = rightProfile:lower()
			if leftKey ~= rightKey then
				if desc then
					return leftKey > rightKey
				end
				return leftKey < rightKey
			end
		end
	else
		local leftKey = left.id:lower()
		local rightKey = right.id:lower()
		if leftKey ~= rightKey then
			if desc then
				return leftKey > rightKey
			end
			return leftKey < rightKey
		end
	end

	return left.id < right.id
end

local function SortedCharacters()
	local characters = {}
	for _, character in pairs(DB.characters) do
		table.insert(characters, character)
	end
	table.sort(characters, CompareCharacters)
	return characters
end

-- Sens par defaut au premier clic sur une colonne : le nom et le profil se
-- lisent de A a Z, le niveau du plus haut au plus bas.
local function SetSortKey(key)
	if DB.sortKey == key then
		DB.sortDesc = not (DB.sortDesc == true)
	else
		DB.sortKey = key
		DB.sortDesc = (key == "level")
	end
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

-- Niveau maximum de l'extension courante, resolu une fois : il ne sert qu'a
-- teindre la colonne de niveau, son absence n'est pas une erreur.
local maxPlayerLevel

local function ResolveMaxPlayerLevel()
	if type(GetMaxLevelForPlayerExpansion) == "function" then
		local ok, level = pcall(GetMaxLevelForPlayerExpansion)
		if ok and type(level) == "number" and level > 0 then
			return level
		end
	end
	return nil
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
	selectedProfileText:SetText("Profil choisi : " .. (selectedProfileName or "aucun")
		.. " | " .. selectedCount .. " selectionne(s)")
	bulkApplyButton:SetText("Attribuer (" .. selectedCount .. ")")
	bulkApplyButton:SetEnabled(selectedProfileName ~= nil and selectedCount > 0)
	promptReloadCheck:SetChecked(DB.promptReload == true)

	local assignedCounts = {}
	for _, profileName in pairs(DB.assignments) do
		assignedCounts[profileName] = (assignedCounts[profileName] or 0) + 1
	end

	if profileList then
		local profileItems = {}
		for index, profileName in ipairs(profileNames) do
			profileItems[index] = {
				name = profileName,
				index = index,
				selected = profileName == selectedProfileName,
				assigned = assignedCounts[profileName] or 0,
			}
		end
		profileList.SetItems(profileItems)
	end

	-- La ScrollBox recycle ses lignes : l'index de selection ne peut plus vivre
	-- sur la frame. Il voyage dans un objet d'affichage, jamais dans l'entree
	-- persistee, qui partirait telle quelle dans les SavedVariables.
	local characters = SortedCharacters()
	local previousCount = #characterIdsByIndex
	local characterItems = {}
	for index, character in ipairs(characters) do
		characterIdsByIndex[index] = character.id
		characterItems[index] = {
			id = character.id,
			character = character,
			index = index,
		}
	end
	for index = #characters + 1, previousCount do
		characterIdsByIndex[index] = nil
	end
	if characterList then
		characterList.SetItems(characterItems)
	end

	for _, sortHeader in ipairs(sortHeaders) do
		local active = sortHeader.sortKey == (DB.sortKey or "name")
		local suffix = ""
		if active then
			suffix = DB.sortDesc and " v" or " ^"
		end
		sortHeader.text:SetText(sortHeader.sortLabel .. suffix)
		sortHeader.text:SetTextColor(UI.Unpack(active and UI.COLOR.accent or UI.COLOR.textMuted))
	end

	-- ProfileMatches parcourt toute la liste d'addons et la cloture transitive de
	-- leurs dependances : un seul appel, alors que RefreshUi part a chaque clic
	-- de case.
	local assigned = DB.assignments[currentCharacterId]
	local active, reason = false, nil
	if assigned then
		active, reason = ProfileMatches(assigned)
	end
	statusText:SetText("Ce perso : " .. currentCharacterId .. " | "
		.. (assigned and (active and "conforme" or (reason or "correction au prochain login")) or "sans profil"))
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

-- ---------------------------------------------------------------------------
-- Lignes de liste
--
-- UI.DecorateRow remet OnClick a nil dans Reset pour qu'une ligne recyclee ne
-- garde pas de fermeture perimee : les gestionnaires sont donc des fonctions
-- stables, rebranchees a chaque liaison, qui relisent l'etat porte par la ligne.
-- ---------------------------------------------------------------------------

local function OnProfileRowClick(self)
	if self.yapProfileName then
		selectedProfileName = self.yapProfileName
		RefreshUi()
	end
end

local function InitProfileRow(row, item)
	UI.DecorateRow(row, {
		height = UI.SIZE.rowH,
		leftInset = UI.PAD.md,
		rightInset = UI.PAD.md,
	})

	row.Reset()
	row.yapProfileName = item.name
	row.label:SetText(item.name)
	row:SetScript("OnClick", OnProfileRowClick)

	if item.selected then
		row.bg:SetColorTexture(UI.Unpack(UI.COLOR.selected))
		row.label:SetTextColor(UI.Unpack(UI.COLOR.accent))
	else
		row.SetStripe(item.index)
		row.label:SetTextColor(UI.Unpack(UI.COLOR.text))
	end

	row.SetTooltip(item.name, item.assigned .. " personnage(s) sur ce profil.")
end

local function ResetProfileRow(row)
	if row.Reset then
		row.Reset()
	end
	row.yapProfileName = nil
end

local function OnCharacterRowClick(self)
	local item = self.yapItem
	if item then
		ToggleSelectedCharacter(item.id, item.index)
	end
end

local function OnCharacterCheckClick(self)
	local item = self.row and self.row.yapItem
	if item then
		ToggleSelectedCharacter(item.id, item.index)
	end
end

local function InitCharacterRow(row, item)
	local nameInset = UI.PAD.sm + LAYOUT.checkW + UI.PAD.md

	UI.DecorateRow(row, {
		height = UI.SIZE.rowH,
		leftInset = nameInset,
		rightInset = UI.PAD.sm,
		valueWidth = LAYOUT.assignmentW,
	})

	if not row.yapColumns then
		row.yapColumns = true

		row.yapCheck = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
		row.yapCheck:SetSize(LAYOUT.checkW, LAYOUT.checkW)
		row.yapCheck:SetPoint("LEFT", row, "LEFT", UI.PAD.sm, 0)
		row.yapCheck.row = row
		row.yapCheck:SetScript("OnClick", OnCharacterCheckClick)

		row.yapLevel = row:CreateFontString(nil, "OVERLAY", UI.FONT.body)
		row.yapLevel:SetPoint("RIGHT", row.value, "LEFT", -UI.PAD.md, 0)
		row.yapLevel:SetWidth(LAYOUT.levelW)
		UI.BoundLabel(row.yapLevel, "RIGHT")

		-- Le libelle de DecorateRow court jusqu'a la colonne de valeur : le
		-- reborner pour degager la colonne de niveau.
		row.label:ClearAllPoints()
		row.label:SetPoint("LEFT", row, "LEFT", nameInset, 0)
		row.label:SetPoint("RIGHT", row.yapLevel, "LEFT", -UI.PAD.md, 0)

		-- Le profil assigne se lit comme un libelle, pas comme une valeur.
		row.value:SetJustifyH("LEFT")
	end

	local character = item.character
	local assignment = DB.assignments[item.id]
	local level = character.level

	row.Reset()
	row.yapItem = item
	row:SetScript("OnClick", OnCharacterRowClick)
	row.SetStripe(item.index)

	row.label:SetText("|c" .. (character.color or "ffffffff") .. character.id .. "|r")
	row.value:SetText(assignment or "-")
	row.value:SetTextColor(UI.Unpack(assignment and UI.COLOR.text or UI.COLOR.textMuted))
	row.yapCheck:SetChecked(selectedCharacterIds[item.id] == true)

	row.yapLevel:SetText(level and tostring(level) or "-")
	if not level then
		row.yapLevel:SetTextColor(UI.Unpack(UI.COLOR.textMuted))
	elseif maxPlayerLevel and level >= maxPlayerLevel then
		row.yapLevel:SetTextColor(UI.Unpack(UI.COLOR.accent))
	else
		row.yapLevel:SetTextColor(UI.Unpack(UI.COLOR.text))
	end

	local body = "Profil : " .. (assignment or "aucun")
		.. "|nNiveau : " .. (level and tostring(level) or "inconnu")
	if character.lastSeen then
		body = body .. "|nVu le : " .. character.lastSeen
	end
	row.SetTooltip(character.id, body)
end

local function ResetCharacterRow(row)
	if row.Reset then
		row.Reset()
	end
	row.yapItem = nil
	if row.yapLevel then
		row.yapLevel:SetText("")
	end
	if row.yapCheck then
		row.yapCheck:SetChecked(false)
	end
end

-- ---------------------------------------------------------------------------
-- Fenetre
-- ---------------------------------------------------------------------------

local function SaveFramePoint()
	if not mainFrame then
		return
	end
	local point, _, relativePoint, x, y = mainFrame:GetPoint()
	if not point then
		return
	end
	DB.framePoint = {
		point = point,
		relativePoint = relativePoint or point,
		x = x or 0,
		y = y or 0,
	}
end

local function RestoreFramePoint()
	mainFrame:ClearAllPoints()
	local saved = DB.framePoint
	if type(saved) == "table" and saved.point then
		mainFrame:SetPoint(saved.point, UIParent, saved.relativePoint or saved.point, saved.x or 0, saved.y or 0)
	else
		mainFrame:SetPoint("CENTER")
	end
end

-- En-tete de colonne cliquable. Le sens actif se lit au suffixe ASCII et a la
-- couleur : les polices du client ne rendent pas les fleches Unicode.
local function CreateSortHeader(parent, key, label)
	local button = CreateFrame("Button", nil, parent)
	button:SetHeight(UI.SIZE.rowHCompact)
	button.sortKey = key
	button.sortLabel = label
	button.text = button:CreateFontString(nil, "ARTWORK", UI.FONT.header)
	button.text:SetAllPoints()
	UI.BoundLabel(button.text, key == "level" and "RIGHT" or "LEFT")
	button:SetScript("OnClick", function(self)
		SetSortKey(self.sortKey)
		RefreshUi()
	end)
	sortHeaders[#sortHeaders + 1] = button
	return button
end

local function CreateSectionTitle(parent, text)
	local title = parent:CreateFontString(nil, "ARTWORK", UI.FONT.header)
	title:SetHeight(UI.SIZE.rowHCompact)
	title:SetTextColor(UI.Unpack(UI.COLOR.category))
	title:SetText(text)
	UI.BoundLabel(title)
	return title
end

local function CreateUi()
	mainFrame = CreateFrame("Frame", ADDON_NAME .. "Frame", UIParent, "BackdropTemplate")
	mainFrame:SetSize(LAYOUT.frameW, LAYOUT.frameH)
	mainFrame:SetClampedToScreen(true)
	mainFrame:SetMovable(true)
	mainFrame:EnableMouse(true)
	mainFrame:Hide()
	UI.ApplyPanelBackdrop(mainFrame)
	RestoreFramePoint()
	table.insert(UISpecialFrames, mainFrame:GetName())

	-- Le deplacement passe par le bandeau seul, comme partout dans la suite.
	local header = UI.CreateHeader(mainFrame, "Yaya Addon Profiles", {
		moveTarget = mainFrame,
		onMoveStopped = SaveFramePoint,
	})

	-- AddButton empile de droite a gauche : la croix, ajoutee en premier, reste
	-- le bouton le plus a droite.
	local closeButton = CreateFrame("Button", nil, header, "UIPanelCloseButton")
	closeButton:SetSize(UI.SIZE.glyph, UI.SIZE.glyph)
	closeButton:SetScript("OnClick", function()
		mainFrame:Hide()
	end)
	header.AddButton(closeButton)

	local resetPositionButton = UI.CreateGlyphButton(header, "reset")
	if resetPositionButton then
		header.AddButton(resetPositionButton)
		resetPositionButton:SetScript("OnClick", function()
			DB.framePoint = nil
			RestoreFramePoint()
		end)
		resetPositionButton.SetTooltip("Replacer la fenetre",
			"Remet la fenetre au centre de l'ecran.")
	end

	statusText = mainFrame:CreateFontString(nil, "ARTWORK", UI.FONT.muted)
	statusText:SetPoint("TOPLEFT", header, "BOTTOMLEFT", UI.PAD.lg, -UI.PAD.sm)
	statusText:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", -UI.PAD.lg, -UI.PAD.sm)
	statusText:SetHeight(UI.SIZE.rowHCompact)
	UI.BoundLabel(statusText)

	-- Repere geometrique de la bande d'action, sans souris.
	local actionAnchor = CreateFrame("Frame", nil, mainFrame)
	actionAnchor:SetPoint("BOTTOMLEFT", mainFrame, "BOTTOMLEFT", UI.PAD.lg, UI.ACTION.bottomMargin)
	actionAnchor:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -UI.PAD.lg, UI.ACTION.bottomMargin)
	actionAnchor:SetHeight(UI.ACTION.height)

	bulkApplyButton = UI.CreateButton(mainFrame, "Attribuer", { width = 200 })
	bulkApplyButton:SetPoint("RIGHT", actionAnchor, "RIGHT", 0, 0)
	bulkApplyButton:SetScript("OnClick", ApplySelectedProfile)

	promptReloadCheck = CreateFrame("CheckButton", nil, mainFrame, "UICheckButtonTemplate")
	promptReloadCheck:SetSize(UI.ACTION.height, UI.ACTION.height)
	promptReloadCheck:SetPoint("LEFT", actionAnchor, "LEFT", 0, 0)
	local promptLabel = promptReloadCheck.Text or promptReloadCheck.text
	if not promptLabel then
		promptLabel = promptReloadCheck:CreateFontString(nil, "ARTWORK", UI.FONT.body)
		promptLabel:SetPoint("LEFT", promptReloadCheck, "RIGHT", UI.PAD.xs, 1)
		promptReloadCheck.Text = promptLabel
	end
	promptLabel:SetText("Proposer le reload apres application")
	UI.SetFont(promptLabel, UI.FONT.body)
	promptReloadCheck:SetScript("OnClick", function(self)
		DB.promptReload = self:GetChecked() and true or false
		Print("Proposition de reload " .. (DB.promptReload and "activee" or "desactivee") .. ".")
	end)
	promptReloadCheck:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText("Proposer le reload")
		GameTooltip:AddLine("Decoche : la liste d'addons est sauvegardee et s'applique"
			.. " a la prochaine connexion, sans fenetre de confirmation.", 1, 1, 1, true)
		GameTooltip:Show()
	end)
	promptReloadCheck:SetScript("OnLeave", GameTooltip_Hide)

	-- Colonne gauche : profils SimpleAddonManager.
	local profileTitle = CreateSectionTitle(mainFrame, "Profils SAM")
	profileTitle:SetPoint("TOPLEFT", statusText, "BOTTOMLEFT", 0, -UI.PAD.sm)
	profileTitle:SetWidth(LAYOUT.profileW)

	local profileHost = CreateFrame("Frame", nil, mainFrame)
	profileHost:SetPoint("TOPLEFT", profileTitle, "BOTTOMLEFT", 0, -UI.PAD.xs)
	profileHost:SetPoint("BOTTOM", actionAnchor, "TOP", 0, UI.PAD.sm)
	profileHost:SetWidth(LAYOUT.profileW)

	local divider = mainFrame:CreateTexture(nil, "ARTWORK")
	divider:SetColorTexture(UI.Unpack(UI.COLOR.divider))
	divider:SetWidth(UI.SIZE.divider)
	divider:SetPoint("TOPLEFT", profileTitle, "TOPRIGHT", UI.PAD.lg, 0)
	divider:SetPoint("BOTTOMLEFT", profileHost, "BOTTOMRIGHT", UI.PAD.lg, 0)

	profileList = UI.CreateScrollList(profileHost, {
		rowHeight = UI.SIZE.rowH,
		initializer = InitProfileRow,
		resetter = ResetProfileRow,
	})
	if profileList then
		profileList.container:SetAllPoints(profileHost)
	else
		Debug("ScrollBox indisponible : la liste de profils n'est pas affichee.")
	end

	-- Colonne droite : personnages connus.
	--
	-- Un conteneur porte la largeur de la colonne, ce qui permet d'ancrer chaque
	-- element par TOPLEFT et TOPRIGHT sur une seule reference. Melanger TOPLEFT
	-- sur la colonne gauche et RIGHT sur le bord de la fenetre imposerait deux
	-- positions verticales contradictoires au meme widget.
	local rightColumn = CreateFrame("Frame", nil, mainFrame)
	rightColumn:SetPoint("TOPLEFT", profileTitle, "TOPRIGHT",
		UI.PAD.lg + UI.SIZE.divider + UI.PAD.lg, 0)
	rightColumn:SetPoint("BOTTOMRIGHT", actionAnchor, "TOPRIGHT", 0, UI.PAD.sm)

	local charactersTitle = CreateSectionTitle(rightColumn, "Personnages connus")
	charactersTitle:SetPoint("TOPLEFT", rightColumn, "TOPLEFT", 0, 0)
	charactersTitle:SetPoint("TOPRIGHT", rightColumn, "TOPRIGHT", 0, 0)

	local selectionBar = CreateFrame("Frame", nil, rightColumn)
	selectionBar:SetPoint("TOPLEFT", charactersTitle, "BOTTOMLEFT", 0, -UI.PAD.xs)
	selectionBar:SetPoint("TOPRIGHT", charactersTitle, "BOTTOMRIGHT", 0, -UI.PAD.xs)
	selectionBar:SetHeight(UI.ACTION.height)

	selectAllButton = UI.CreateButton(selectionBar, "Tout", { width = 56 })
	selectAllButton:SetPoint("TOPLEFT", selectionBar, "TOPLEFT", 0, 0)
	selectAllButton:SetScript("OnClick", function()
		SelectAllCharacters()
		RefreshUi()
	end)

	selectUnassignedButton = UI.CreateButton(selectionBar, "Sans profil", { width = 92 })
	selectUnassignedButton:SetPoint("TOPLEFT", selectAllButton, "TOPRIGHT", UI.PAD.sm, 0)
	selectUnassignedButton:SetScript("OnClick", function()
		SelectUnassignedCharacters()
		RefreshUi()
	end)

	clearSelectionButton = UI.CreateButton(selectionBar, "Aucun", { width = 66 })
	clearSelectionButton:SetPoint("TOPLEFT", selectUnassignedButton, "TOPRIGHT", UI.PAD.sm, 0)
	clearSelectionButton:SetScript("OnClick", function()
		ClearSelectedCharacters()
		RefreshUi()
	end)

	selectedProfileText = selectionBar:CreateFontString(nil, "ARTWORK", UI.FONT.muted)
	selectedProfileText:SetPoint("TOPLEFT", clearSelectionButton, "TOPRIGHT", UI.PAD.md, 0)
	selectedProfileText:SetPoint("TOPRIGHT", selectionBar, "TOPRIGHT", 0, 0)
	selectedProfileText:SetHeight(UI.ACTION.height)
	UI.BoundLabel(selectedProfileText, "RIGHT")

	-- L'hote de liste reserve lui-meme la hauteur de la bande d'en-tetes : celle-ci
	-- s'ancre ensuite sur la largeur reelle du contenu, gouttiere de barre de
	-- defilement exclue, ce qui lui interdit de porter l'ancrage vertical de l'hote.
	local headerGap = UI.PAD.xs + UI.SIZE.rowHCompact + UI.PAD.xs

	local characterHost = CreateFrame("Frame", nil, rightColumn)
	characterHost:SetPoint("TOPLEFT", selectionBar, "BOTTOMLEFT", 0, -headerGap)
	characterHost:SetPoint("TOPRIGHT", selectionBar, "BOTTOMRIGHT", 0, -headerGap)
	characterHost:SetPoint("BOTTOM", rightColumn, "BOTTOM", 0, 0)

	characterList = UI.CreateScrollList(characterHost, {
		rowHeight = UI.SIZE.rowH,
		initializer = InitCharacterRow,
		resetter = ResetCharacterRow,
	})

	local headerRow = CreateFrame("Frame", nil, rightColumn)
	headerRow:SetHeight(UI.SIZE.rowHCompact)
	if characterList then
		characterList.container:SetAllPoints(characterHost)
		headerRow:SetPoint("BOTTOMLEFT", characterList.frame, "TOPLEFT", 0, UI.PAD.xs)
		headerRow:SetPoint("BOTTOMRIGHT", characterList.frame, "TOPRIGHT", 0, UI.PAD.xs)
	else
		headerRow:SetPoint("BOTTOMLEFT", characterHost, "TOPLEFT", 0, UI.PAD.xs)
		headerRow:SetPoint("BOTTOMRIGHT", characterHost, "TOPRIGHT", 0, UI.PAD.xs)

		local unavailable = characterHost:CreateFontString(nil, "ARTWORK", UI.FONT.muted)
		unavailable:SetPoint("TOPLEFT", characterHost, "TOPLEFT", UI.PAD.md, -UI.PAD.md)
		unavailable:SetPoint("TOPRIGHT", characterHost, "TOPRIGHT", -UI.PAD.md, -UI.PAD.md)
		unavailable:SetHeight(UI.SIZE.rowH)
		unavailable:SetText("Liste indisponible : ce client n'expose pas les modeles de defilement.")
		unavailable:SetJustifyH("LEFT")
		Debug("ScrollBox indisponible : la liste de personnages n'est pas affichee.")
	end

	local assignmentHeader = CreateSortHeader(headerRow, "profile", "Profil")
	assignmentHeader:SetWidth(LAYOUT.assignmentW)
	assignmentHeader:SetPoint("RIGHT", headerRow, "RIGHT", -UI.PAD.sm, 0)

	local levelHeader = CreateSortHeader(headerRow, "level", "Niv.")
	levelHeader:SetWidth(LAYOUT.levelW)
	levelHeader:SetPoint("RIGHT", assignmentHeader, "LEFT", -UI.PAD.md, 0)

	local nameHeader = CreateSortHeader(headerRow, "name", "Nom")
	nameHeader:SetPoint("LEFT", headerRow, "LEFT", UI.PAD.sm + LAYOUT.checkW + UI.PAD.md, 0)
	nameHeader:SetPoint("RIGHT", levelHeader, "LEFT", -UI.PAD.md, 0)

	local headerRule = headerRow:CreateTexture(nil, "ARTWORK")
	headerRule:SetColorTexture(UI.Unpack(UI.COLOR.divider))
	headerRule:SetHeight(UI.SIZE.divider)
	headerRule:SetPoint("BOTTOMLEFT", headerRow, "BOTTOMLEFT", 0, -UI.PAD.xs)
	headerRule:SetPoint("BOTTOMRIGHT", headerRow, "BOTTOMRIGHT", 0, -UI.PAD.xs)
end

local function PrintHelp()
	Print("/yap ouvre la fenetre")
	Print("/yap profile <profil> : attribue le profil SAM au perso courant")
	Print("/yap set <perso-royaume> <profil> : attribution hors ligne")
	Print("/yap status : affiche l'attribution courante")
	Print("/yap reload [on|off] : proposer le reload, ou sauvegarder pour la prochaine connexion")
	Print("/yap debug [on|off] : affiche ou active le diagnostic")
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
	if command == "reload" then
		if rest == "on" then
			DB.promptReload = true
			Print("Proposition de reload activee.")
		elseif rest == "off" then
			DB.promptReload = false
			Print("Proposition de reload desactivee.")
		else
			Print("Proposition de reload " .. (DB.promptReload and "activee" or "desactivee")
				.. ". Sans elle, le profil est sauvegarde pour la prochaine connexion.")
		end
		RefreshUi()
		return
	end
	if command == "debug" then
		if rest == "on" then
			DB.debug = true
			Print("DEBUG active.")
		elseif rest == "off" then
			DB.debug = false
			Print("DEBUG desactive.")
		else
			Print("DEBUG " .. (DB.debug and "active" or "desactive") .. ".")
			PrintDebugReport()
		end
		return
	end
	PrintHelp()
end

local function OnPlayerLogin()
	EnsureDb()
	currentCharacterId = GetCharacterId()
	currentCharacterGuid = UnitGUID("player")
	maxPlayerLevel = ResolveMaxPlayerLevel()
	local _, classFile = UnitClass("player")
	local color = RAID_CLASS_COLORS[classFile]
	-- Seule source de niveau disponible : SimpleAddonManager ne le stocke pas,
	-- donc chaque personnage renseigne le sien a sa propre connexion.
	RememberCharacter(currentCharacterId, currentCharacterGuid, classFile,
		color and color.colorStr, UnitLevel("player"), date("%Y-%m-%d %H:%M"))
	SeedKnownCharacters()
	MergeDuplicateCharacters()
	CreateUi()

	SLASH_YAYAADDONPROFILES1 = "/yap"
	SLASH_YAYAADDONPROFILES2 = "/yayaaddons"
	SlashCmdList.YAYAADDONPROFILES = HandleSlashCommand

	local assignedProfile = DB.assignments[currentCharacterId]
	local details = {
		character = currentCharacterId,
		guid = currentCharacterGuid,
		profile = assignedProfile,
		samProfiles = CountAddons((GetSamDb() or {}).sets),
	}
	RecordDebug("login", details)
	Debug("Connexion personnage=" .. currentCharacterId .. ", profil=" .. (assignedProfile or "aucun") .. ", profils SAM=" .. details.samProfiles .. ".")
	pendingLoginProfile = assignedProfile
	if assignedProfile then
		Debug("Application differee a PLAYER_ENTERING_WORLD.")
	end

	-- DB.reloadRequired etait ecrit mais jamais relu ni nettoye. Une demande
	-- restee en suspens, popup perdu ou reload refuse, ne laissait aucune trace
	-- exploitable a la session suivante.
	local pendingReload = DB.reloadRequired
	if type(pendingReload) == "table" and pendingReload.character == currentCharacterId then
		Debug("Reload encore en attente depuis la session precedente pour "
			.. tostring(pendingReload.profile or "?") .. ".")
	end
	DB.reloadRequired = nil
end

local function OnPlayerEnteringWorld()
	if not pendingLoginProfile then
		return
	end

	local profileName = pendingLoginProfile
	pendingLoginProfile = nil
	Debug("Entree dans le monde : application de " .. profileName .. " dans 0,5 seconde.")
	C_Timer.After(0.5, function()
		ApplyProfile(profileName, true)
	end)
end

local function OnPlayerLevelUp(newLevel)
	-- UnitLevel peut avoir une frame de retard sur l'evenement : l'argument
	-- porte deja le nouveau niveau.
	local level = tonumber(newLevel) or UnitLevel("player")
	if not level or not currentCharacterId then
		return
	end
	RememberCharacter(currentCharacterId, currentCharacterGuid, nil, nil, level,
		date("%Y-%m-%d %H:%M"))
	if mainFrame and mainFrame:IsShown() then
		RefreshUi()
	end
end

function YayaAddonProfiles_OnAddonCompartmentClick()
	if mainFrame then
		ToggleUi()
	end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_LEVEL_UP")
eventFrame:SetScript("OnEvent", function(_, event, ...)
	if event == "PLAYER_LOGIN" then
		OnPlayerLogin()
	elseif event == "PLAYER_ENTERING_WORLD" then
		OnPlayerEnteringWorld()
	elseif event == "PLAYER_LEVEL_UP" then
		OnPlayerLevelUp(...)
	end
end)

-- Surface de test hors jeu : le harnais charge ce chunk avec des bouchons et
-- appelle directement des fonctions autrement locales.
YayaAddonProfiles_Internal = {
	EnsureDb = EnsureDb,
	RememberCharacter = RememberCharacter,
	PreferredCharacterId = PreferredCharacterId,
	MergeDuplicateCharacters = MergeDuplicateCharacters,
	CompareCharacters = CompareCharacters,
	SortedCharacters = SortedCharacters,
	SetSortKey = SetSortKey,
}
