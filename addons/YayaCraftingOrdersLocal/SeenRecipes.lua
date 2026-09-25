local _, ns = ...

local Seen = {}
local watcher = CreateFrame("Frame")
local professionSkillLines = {
	[1] = 164,
	[2] = 165,
	[3] = 171,
	[4] = 182,
	[5] = 185,
	[6] = 186,
	[7] = 197,
	[8] = 202,
	[9] = 333,
	[10] = 356,
	[11] = 393,
	[12] = 755,
	[13] = 773,
	[14] = 794,
}
local professionEnumsBySkillLine = {}
for professionID, skillLineID in pairs(professionSkillLines) do
	professionEnumsBySkillLine[skillLineID] = professionID
end

ns.SeenRecipes = Seen

local function GetText(key, ...)
	return ns.LF and ns.LF(key, ...) or key
end

local function GetNow()
	return type(time) == "function" and time() or 0
end

local function NormalizeProfessionID(professionID)
	professionID = tonumber(professionID)
	if not professionID then
		return nil
	end
	return professionSkillLines[professionID] and professionID or professionEnumsBySkillLine[professionID] or professionID
end

local function GetProfessionName(professionID, recipeID)
	local skillLineID = professionSkillLines[NormalizeProfessionID(professionID) or 0]
	if recipeID and C_TradeSkillUI and type(C_TradeSkillUI.GetProfessionInfoByRecipeID) == "function" then
		local ok, info = pcall(C_TradeSkillUI.GetProfessionInfoByRecipeID, recipeID)
		if ok and type(info) == "table" then
			local name = info.professionName or info.parentProfessionName
			if name and name ~= "" then
				return name
			end
		end
	end
	if skillLineID and C_TradeSkillUI and type(C_TradeSkillUI.GetProfessionInfoBySkillLineID) == "function" then
		local ok, info = pcall(C_TradeSkillUI.GetProfessionInfoBySkillLineID, skillLineID)
		if ok and type(info) == "table" then
			local name = info.professionName or info.parentProfessionName
			if name and name ~= "" then
				return name
			end
		end
	end
	return GetText("SEEN_RECIPES_PROFESSION_FORMAT", tostring(professionID or "?"))
end

function Seen:EnsureDatabase()
	local db = ns.GetDatabase and ns.GetDatabase()
	if type(db) ~= "table" then
		return nil
	end

	db.patronRecipeHistory = type(db.patronRecipeHistory) == "table" and db.patronRecipeHistory or {}
	local history = db.patronRecipeHistory
	local historyVersion = tonumber(history.version) or 1
	history.recipes = type(history.recipes) == "table" and history.recipes or {}
	if historyVersion < 2 then
		for _, entry in pairs(history.recipes) do
			if type(entry) == "table" then
				-- Les anciennes versions pouvaient associer l'order au metier
				-- ouvert plutot qu'au metier de la recette. Les orders restent
				-- conserves et seront reappris avec l'ID fiable au prochain scan.
				entry.professionID = nil
				entry.professions = {}
			end
		end
		history.version = 2
	else
		history.version = historyVersion
	end
	return history
end

function Seen:Observe(recipeID, recipeName, professionID, source, orderID, observedAt)
	recipeID = tonumber(recipeID)
	if not recipeID or recipeID <= 0 then
		return false
	end

	local history = self:EnsureDatabase()
	if not history then
		return false
	end

	local entry = history.recipes[recipeID]
	if type(entry) ~= "table" then
		entry = {
			recipeID = recipeID,
			recipeName = recipeName,
			professionID = nil,
			professions = {},
			sources = {},
			orderIDs = {},
			seenCount = 0,
			firstSeenAt = observedAt or GetNow(),
		}
		history.recipes[recipeID] = entry
	end

	if recipeName and recipeName ~= "" then
		entry.recipeName = recipeName
	end
	entry.professions = type(entry.professions) == "table" and entry.professions or {}
	entry.sources = type(entry.sources) == "table" and entry.sources or {}
	entry.orderIDs = type(entry.orderIDs) == "table" and entry.orderIDs or {}

	professionID = NormalizeProfessionID(professionID)
	if professionID then
		-- Une recette appartient a un seul metier. Les anciennes versions
		-- pouvaient enregistrer le metier actuellement affiche au lieu de celui
		-- de la recette : une observation live fiable doit donc nettoyer ce bruit.
		if source == "jeu" then
			entry.professions = {}
		end
		entry.professionID = professionID
		entry.professions[professionID] = true
	end
	if source and source ~= "" then
		entry.sources[source] = true
	end

	local timestamp = tonumber(observedAt) or GetNow()
	entry.firstSeenAt = tonumber(entry.firstSeenAt) or timestamp
	entry.lastSeenAt = timestamp
	local orderKey = orderID and tostring(orderID) or ("recipe:" .. tostring(recipeID))
	if not entry.orderIDs[orderKey] then
		entry.orderIDs[orderKey] = true
		entry.seenCount = (tonumber(entry.seenCount) or 0) + 1
	end
	return true
end

function Seen:ImportCraftSim()
	local craftSim = _G.CraftSimDB
	local crafterData = craftSim and craftSim.crafterDB and craftSim.crafterDB.data
	if type(crafterData) ~= "table" then
		return 0
	end

	local imported = 0
	local now = GetNow()
	for _, characterData in pairs(crafterData) do
		for professionID, professionSnapshot in pairs(characterData.patronWorkOrders or {}) do
			for orderID, orderSnapshot in pairs(professionSnapshot.orders or {}) do
				if type(orderSnapshot) == "table"
					and self:Observe(
						orderSnapshot.spellID or orderSnapshot.recipeID,
						orderSnapshot.recipeName,
						professionID,
						"CraftSim",
						orderSnapshot.orderID or orderID,
						now
					)
				then
					imported = imported + 1
				end
			end
		end
	end
	return imported
end

function Seen:ResolveOrder(order)
	if type(order) ~= "table" then
		return nil
	end

	local recipeInfo
	local recipeID = tonumber(order.spellID or order.recipeID)
	if not recipeID and order.skillLineAbilityID
		and C_TradeSkillUI and type(C_TradeSkillUI.GetRecipeInfoForSkillLineAbility) == "function" then
		local ok, info = pcall(C_TradeSkillUI.GetRecipeInfoForSkillLineAbility, order.skillLineAbilityID, 2)
		if ok and type(info) == "table" then
			recipeInfo = info
			recipeID = tonumber(info.recipeID)
		end
	end

	if recipeID and not recipeInfo and C_TradeSkillUI and type(C_TradeSkillUI.GetRecipeInfo) == "function" then
		local ok, info = pcall(C_TradeSkillUI.GetRecipeInfo, recipeID)
		if ok and type(info) == "table" then
			recipeInfo = info
		end
	end

	local recipeName = recipeInfo and recipeInfo.name
	if not recipeName and recipeID and C_Spell and type(C_Spell.GetSpellName) == "function" then
		recipeName = C_Spell.GetSpellName(recipeID)
	end
	return recipeID, recipeName, order.orderID
end

function Seen:GetCurrentProfessionID(recipeID)
	local professionID
	-- L'ID de recette est la source de verite. Le metier affiche n'est qu'un
	-- repli : ScanLive parcourt parfois des orders d'un autre onglet.
	if recipeID and C_TradeSkillUI and type(C_TradeSkillUI.GetProfessionInfoByRecipeID) == "function" then
		local ok, info = pcall(C_TradeSkillUI.GetProfessionInfoByRecipeID, recipeID)
		if ok and type(info) == "table" then
			professionID = info.professionID or info.skillLineID
		end
	end
	if not professionID and ns.BrowsePane and type(ns.BrowsePane.GetCurrentProfessionID) == "function" then
		local ok, value = pcall(ns.BrowsePane.GetCurrentProfessionID, ns.BrowsePane)
		if ok then
			professionID = value
		end
	end
	return NormalizeProfessionID(professionID)
end

function Seen:ScanLive()
	if not C_CraftingOrders or type(C_CraftingOrders.GetCrafterOrders) ~= "function" then
		return 0
	end

	local scanned = 0
	local function ScanOrder(order)
		if type(order) ~= "table" or order.orderType ~= ns.ORDER_TYPE_NPC then
			return
		end
		local recipeID, recipeName, orderID = self:ResolveOrder(order)
		if recipeID and self:Observe(recipeID, recipeName, self:GetCurrentProfessionID(recipeID), "jeu", orderID) then
			scanned = scanned + 1
		end
	end

	for _, order in ipairs(C_CraftingOrders.GetCrafterOrders() or {}) do
		ScanOrder(order)
	end
	local claimed = type(C_CraftingOrders.GetClaimedOrder) == "function" and C_CraftingOrders.GetClaimedOrder()
	ScanOrder(claimed)
	return scanned
end

function Seen:BuildRows()
	local history = self:EnsureDatabase()
	local rows = {}
	for _, entry in pairs(history and history.recipes or {}) do
		if type(entry) == "table" and entry.recipeID then
			rows[#rows + 1] = entry
		end
	end
	table.sort(rows, function(left, right)
		local leftName = tostring(left.recipeName or "")
		local rightName = tostring(right.recipeName or "")
		if leftName == rightName then
			return tonumber(left.recipeID) < tonumber(right.recipeID)
		end
		return leftName:lower() < rightName:lower()
	end)
	return rows
end

function Seen:FormatProfessions(entry)
	local names = {}
	for professionID in pairs(entry.professions or {}) do
		names[#names + 1] = GetProfessionName(professionID, entry.recipeID)
	end
	table.sort(names)
	return #names > 0 and table.concat(names, ", ") or GetText("SEEN_RECIPES_UNKNOWN_PROFESSION")
end

function Seen:FormatSources(entry)
	local sources = {}
	for source in pairs(entry.sources or {}) do
		sources[#sources + 1] = source
	end
	table.sort(sources)
	return #sources > 0 and table.concat(sources, ", ") or GetText("SEEN_RECIPES_UNKNOWN_SOURCE")
end

function Seen:BuildFrame()
	if self.frame then
		return
	end

	local UI = ns.UI
	if not UI or type(CreateFrame) ~= "function" then
		return
	end

	local frame = CreateFrame("Frame", "YayaCraftingOrdersSeenRecipes", UIParent, "BackdropTemplate")
	frame:SetSize(760, 520)
	frame:SetPoint("CENTER")
	frame:SetFrameStrata("HIGH")
	frame:SetClampedToScreen(true)
	frame:SetMovable(true)
	UI.ApplyPanelBackdrop(frame)

	local header = UI.CreateHeader(frame, GetText("SEEN_RECIPES_TITLE"), { moveTarget = frame })
	UI.CreateCloseButton(header, frame)

	local summary = frame:CreateFontString(nil, "ARTWORK", UI.FONT.muted)
	summary:SetPoint("TOPLEFT", header, "BOTTOMLEFT", UI.PAD.lg, -UI.PAD.md)
	summary:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", -UI.PAD.lg, -UI.PAD.md)
	UI.BoundLabel(summary, "LEFT")

	local columns = CreateFrame("Frame", nil, frame)
	columns:SetPoint("TOPLEFT", summary, "BOTTOMLEFT", 0, -UI.PAD.lg)
	columns:SetPoint("TOPRIGHT", summary, "BOTTOMRIGHT", 0, -UI.PAD.lg)
	columns:SetHeight(UI.SIZE.rowHCompact)
	local recipeColumn = columns:CreateFontString(nil, "ARTWORK", UI.FONT.muted)
	recipeColumn:SetPoint("LEFT", columns, "LEFT", 0, 0)
	recipeColumn:SetText(GetText("SEEN_RECIPES_COLUMN_RECIPE"))
	UI.BoundLabel(recipeColumn, "LEFT")
	local professionColumn = columns:CreateFontString(nil, "ARTWORK", UI.FONT.muted)
	professionColumn:SetWidth(132)
	professionColumn:SetText(GetText("SEEN_RECIPES_COLUMN_PROFESSION"))
	UI.BoundLabel(professionColumn, "LEFT")
	local lastSeenColumn = columns:CreateFontString(nil, "ARTWORK", UI.FONT.muted)
	lastSeenColumn:SetWidth(78)
	lastSeenColumn:SetText(GetText("SEEN_RECIPES_COLUMN_LAST_SEEN"))
	UI.BoundLabel(lastSeenColumn, "RIGHT")
	local ordersColumn = columns:CreateFontString(nil, "ARTWORK", UI.FONT.muted)
	ordersColumn:SetWidth(52)
	ordersColumn:SetPoint("RIGHT", columns, "RIGHT", -UI.PAD.md, 0)
	ordersColumn:SetText(GetText("SEEN_RECIPES_COLUMN_ORDERS"))
	UI.BoundLabel(ordersColumn, "RIGHT")
	professionColumn:SetPoint("RIGHT", ordersColumn, "LEFT", -UI.PAD.lg, 0)
	lastSeenColumn:SetPoint("RIGHT", professionColumn, "LEFT", -UI.PAD.lg, 0)
	recipeColumn:SetPoint("RIGHT", lastSeenColumn, "LEFT", -UI.PAD.lg, 0)

	local listHost = CreateFrame("Frame", nil, frame)
	listHost:SetPoint("TOPLEFT", columns, "BOTTOMLEFT", 0, -UI.PAD.sm)
	listHost:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -UI.PAD.lg, UI.PAD.lg)

	local list = UI.CreateScrollList(listHost, {
		rowHeight = UI.SIZE.rowH,
		initializer = function(row, entry)
			if not row.yayaRow then
				UI.DecorateRow(row, { height = UI.SIZE.rowH, valueWidth = 52 })
				row.profession = row:CreateFontString(nil, "OVERLAY", UI.FONT.muted)
				row.profession:SetWidth(132)
				row.profession:SetPoint("RIGHT", row.value, "LEFT", -UI.PAD.lg, 0)
				UI.BoundLabel(row.profession, "LEFT")
				row.lastSeen = row:CreateFontString(nil, "OVERLAY", UI.FONT.muted)
				row.lastSeen:SetWidth(78)
				row.lastSeen:SetPoint("RIGHT", row.profession, "LEFT", -UI.PAD.lg, 0)
				UI.BoundLabel(row.lastSeen, "RIGHT")
				row.label:ClearAllPoints()
				row.label:SetPoint("LEFT", row, "LEFT", UI.PAD.md, 0)
				row.label:SetPoint("RIGHT", row.lastSeen, "LEFT", -UI.PAD.lg, 0)
			end

			row:Reset()
			row.data = entry
			row.label:ClearAllPoints()
			row.label:SetPoint("LEFT", row, "LEFT", UI.PAD.md, 0)
			row.label:SetPoint("RIGHT", row.lastSeen, "LEFT", -UI.PAD.lg, 0)
			row.label:SetText(entry.recipeName or GetText("SEEN_RECIPES_RECIPE_FORMAT", entry.recipeID))
			row.label:SetTextColor(UI.Unpack(UI.COLOR.text))
			row.profession:SetText(self:FormatProfessions(entry))
			row.profession:SetTextColor(UI.Unpack(UI.COLOR.textMuted))
			row.lastSeen:SetText(entry.lastSeenAt and date("%d/%m/%y", entry.lastSeenAt) or "-")
			row.lastSeen:SetTextColor(UI.Unpack(UI.COLOR.textMuted))
			row.value:SetText(tostring(tonumber(entry.seenCount) or 0))
			row.value:SetTextColor(UI.Unpack(UI.COLOR.accent))
			row.SetStripe(entry.recipeID)
			row.SetTruncatedTooltip(entry.recipeName or tostring(entry.recipeID),
				GetText("SEEN_RECIPES_TOOLTIP_FORMAT", entry.recipeID, tonumber(entry.seenCount) or 0, self:FormatSources(entry)))
		end,
	})
	if not list then
		return
	end

	list.container:SetAllPoints(listHost)
	self.frame = frame
	self.summary = summary
	self.list = list
	frame:SetScript("OnShow", function()
		self:Refresh(true)
	end)
	frame:Hide()
end

function Seen:Refresh(importCraftSim)
	self:EnsureDatabase()
	if importCraftSim ~= false then
		self:ImportCraftSim()
		self:ScanLive()
	end
	if not self.frame then
		self:BuildFrame()
	end
	if not self.frame or not self.list then
		return
	end

	local rows = self:BuildRows()
	local totalObservations = 0
	for _, entry in ipairs(rows) do
		totalObservations = totalObservations + (tonumber(entry.seenCount) or 0)
	end
	self.summary:SetText(GetText("SEEN_RECIPES_SUMMARY_FORMAT", #rows, totalObservations))
	self.list.SetItems(rows, importCraftSim == true)
end

function Seen:Initialize()
	if self.initialized then
		return
	end
	self.initialized = true
	self:EnsureDatabase()
	self:BuildFrame()
	self:ImportCraftSim()
	self:ScanLive()
end

function Seen:Show()
	self:Initialize()
	if not self.frame then
		if ns.Print then
			ns.Print(GetText("SEEN_RECIPES_UNAVAILABLE"))
		end
		return
	end
	self.frame:Show()
end

function Seen:Toggle()
	self:Initialize()
	if self.frame and self.frame:IsShown() then
		self.frame:Hide()
	else
		self:Show()
	end
end

function Seen:ScheduleScan()
	self.scanToken = (self.scanToken or 0) + 1
	local token = self.scanToken
	C_Timer.After(0.5, function()
		if self.scanToken ~= token then
			return
		end
		self:ScanLive()
		if self.frame and self.frame:IsShown() then
			self:Refresh(false)
		end
	end)
end

watcher:SetScript("OnEvent", function(_, eventName, orderType)
	if eventName == "PLAYER_LOGIN" then
		Seen:Initialize()
	elseif eventName == "CRAFTINGORDERS_UPDATE_ORDER_COUNT" then
		if orderType == ns.ORDER_TYPE_NPC then
			Seen:ScheduleScan()
		end
	elseif eventName == "CRAFTINGORDERS_CAN_REQUEST" or eventName == "TRADE_SKILL_SHOW" then
		Seen:ScheduleScan()
	end
end)
watcher:RegisterEvent("PLAYER_LOGIN")
watcher:RegisterEvent("CRAFTINGORDERS_UPDATE_ORDER_COUNT")
watcher:RegisterEvent("CRAFTINGORDERS_CAN_REQUEST")
watcher:RegisterEvent("TRADE_SKILL_SHOW")
