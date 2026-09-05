local ADDON_NAME = ...

local frame = CreateFrame("Frame")
local db
local hooked = false
local refreshPending = false
local repaintPending = false
local toggle
local emptyText
local lastHiddenCount = 0
local knownCache = {}
local lastMapping
local useElvMerchantLayout = false
local tsmWarningShown = false
local professionDataReady = false
local knownProfessionSkillLines = {}
local knownProfessionNames = {}
local knownProfessionEnums = {}
local professionEnumByName = {}

local DEFAULTS = {
    enabled = true,
    hideKnownRecipes = true,
    hideCollected = true,
    hideIrrelevant = true,
}

local function Print(message)
    -- Menthe de la suite, valeur de YayaCore.UI.HEX.accent. Litteral assume :
    -- cet addon reste autonome, sans dependance declaree.
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff98YayaVendorFilter|r " .. message)
end

local function SafeCall(func, ...)
    if type(func) ~= "function" then
        return nil
    end

    local ok, a, b, c, d, e, f, g, h, i, j, k, l, m = pcall(func, ...)
    if not ok then
        return nil
    end
    return a, b, c, d, e, f, g, h, i, j, k, l, m
end

local function GetMerchantItemCount()
    if C_MerchantFrame and type(C_MerchantFrame.GetNumItems) == "function" then
        return tonumber(SafeCall(C_MerchantFrame.GetNumItems)) or 0
    end
    return tonumber(SafeCall(GetMerchantNumItems)) or 0
end

local function GetMerchantItemIDCompat(index)
    local itemID = SafeCall(GetMerchantItemID, index)
    if itemID then
        return itemID
    end

    if C_MerchantFrame and type(C_MerchantFrame.GetItemInfo) == "function" then
        local info = SafeCall(C_MerchantFrame.GetItemInfo, index)
        itemID = type(info) == "table" and info.itemID or nil
        if itemID then
            return itemID
        end
    end

    local itemLink = SafeCall(GetMerchantItemLink, index)
    if itemLink and C_Item and type(C_Item.GetItemInfoInstant) == "function" then
        return SafeCall(C_Item.GetItemInfoInstant, itemLink)
    end
end

local function GetMerchantItemLinkCompat(index)
    return SafeCall(GetMerchantItemLink, index)
end

local function FindProfessionInText(text)
    if type(text) ~= "string" or text == "" then
        return nil
    end

    local lowerText = text:lower()
    for name, professionEnum in pairs(professionEnumByName) do
        if lowerText:find(name, 1, true) then
            return professionEnum
        end
    end
end

local function IsRequirementLikeLine(line, lineTypes)
    lineTypes = lineTypes or {}
    if line.usable == false
        or line.type == lineTypes.UsageRequirement
        or line.type == lineTypes.ErrorLine
        or line.type == lineTypes.DisabledLine then
        return true
    end

    local color = line.leftColor
    if type(color) ~= "table" then
        return false
    end
    local red, green, blue = color.r, color.g, color.b
    if type(red) ~= "number" and type(color.GetRGB) == "function" then
        red, green, blue = SafeCall(color.GetRGB, color)
    end
    return type(red) == "number" and type(green) == "number" and type(blue) == "number"
        and red > 0.7 and green < 0.45 and blue < 0.45
end

local function AnalyzeTooltip(index)
    local result = {
        known = false,
        permanentMismatch = false,
        equipMismatch = false,
        skillBlocked = false,
        skillText = nil,
        requiredProfession = nil,
    }

    if not C_TooltipInfo or type(C_TooltipInfo.GetMerchantItem) ~= "function" then
        return result
    end

    local data = SafeCall(C_TooltipInfo.GetMerchantItem, index)
    if type(data) ~= "table" or type(data.lines) ~= "table" then
        return result
    end

    local lineTypes = Enum and Enum.TooltipDataLineType
    local requirementTypes = Enum and Enum.TooltipDataUsageRequirementType
    local usageRequirement = lineTypes and lineTypes.UsageRequirement

    for _, line in ipairs(data.lines) do
        if type(line) == "table" and lineTypes and line.type == lineTypes.EquipSlot
            and (line.isValidItemType == false or line.isValidInvSlot == false) then
            result.equipMismatch = true
        end

        if type(line) == "table" and usageRequirement and requirementTypes
            and line.type == usageRequirement and line.usable ~= true then
            local requirementType = line.requirementType
            if requirementType == requirementTypes.NotAlreadyKnown then
                result.known = true
            elseif requirementType == requirementTypes.RaceClass
                or requirementType == requirementTypes.Faction then
                result.permanentMismatch = true
            elseif requirementType == requirementTypes.Skill then
                result.skillBlocked = true
                result.skillText = line.leftText
            end
        end

        local text = type(line) == "table" and line.leftText or nil
        if text and ITEM_SPELL_KNOWN and text:find(ITEM_SPELL_KNOWN, 1, true) then
            result.known = true
        end
        local requiredProfession = FindProfessionInText(text)
        if requiredProfession and IsRequirementLikeLine(line, lineTypes) then
            result.skillBlocked = true
            result.skillText = text
            result.requiredProfession = requiredProfession
        end
    end
    return result
end

local function GetItemDetails(itemID, itemLink)
    local itemInfo = itemLink or itemID
    if not itemInfo or not C_Item or type(C_Item.GetItemInfoInstant) ~= "function" then
        return nil
    end

    local _, _, itemSubType, equipLoc, _, classID, subClassID =
        SafeCall(C_Item.GetItemInfoInstant, itemInfo)
    if not classID then
        return nil
    end

    return {
        itemSubType = itemSubType,
        equipLoc = equipLoc,
        classID = classID,
        subClassID = subClassID,
    }
end

local function AddKnownProfessionName(name)
    if type(name) == "string" and name ~= "" then
        knownProfessionNames[name] = true
        knownProfessionNames[name:lower()] = true
    end
end

local function AddProfessionRequirementName(name, professionEnum)
    if type(name) == "string" and name ~= "" and professionEnum ~= nil then
        professionEnumByName[name:lower()] = professionEnum
    end
end

local function RefreshKnownProfessions()
    wipe(knownProfessionSkillLines)
    wipe(knownProfessionNames)
    wipe(knownProfessionEnums)
    wipe(professionEnumByName)
    professionDataReady = type(GetProfessions) == "function" and type(GetProfessionInfo) == "function"
    if not professionDataReady then
        return
    end

    local profession = Enum and Enum.Profession or {}
    local professionSpecs = {
        { 164, "Blacksmithing", profession.Blacksmithing or 1 },
        { 165, "Leatherworking", profession.Leatherworking or 2 },
        { 171, "Alchemy", profession.Alchemy or 3 },
        { 182, "Herbalism", profession.Herbalism or 4 },
        { 185, "Cooking", profession.Cooking or 5 },
        { 186, "Mining", profession.Mining or 6 },
        { 197, "Tailoring", profession.Tailoring or 7 },
        { 202, "Engineering", profession.Engineering or 8 },
        { 333, "Enchanting", profession.Enchanting or 9 },
        { 356, "Fishing", profession.Fishing or 10 },
        { 393, "Skinning", profession.Skinning or 11 },
        { 755, "Jewelcrafting", profession.Jewelcrafting or 12 },
        { 773, "Inscription", profession.Inscription or 13 },
        { 794, "Archaeology", profession.Archaeology or 14 },
    }
    for _, spec in ipairs(professionSpecs) do
        local skillLineID, englishName, professionEnum = spec[1], spec[2], spec[3]
        AddProfessionRequirementName(englishName, professionEnum)
        AddProfessionRequirementName(SafeCall(
            C_TradeSkillUI and C_TradeSkillUI.GetTradeSkillDisplayName,
            skillLineID
        ), professionEnum)
        local info = SafeCall(
            C_TradeSkillUI and C_TradeSkillUI.GetProfessionInfoBySkillLineID,
            skillLineID
        )
        if type(info) == "table" then
            AddProfessionRequirementName(info.parentProfessionName, professionEnum)
            AddProfessionRequirementName(info.professionName, professionEnum)
        end
    end

    local prof1, prof2, archaeology, fishing, cooking, firstAid = SafeCall(GetProfessions)
    for _, professionIndex in pairs({ prof1, prof2, archaeology, fishing, cooking, firstAid }) do
        local name, _, _, _, _, _, skillLineID =
            SafeCall(GetProfessionInfo, professionIndex)
        if skillLineID then
            knownProfessionSkillLines[skillLineID] = true
        end
        local professionInfo = SafeCall(
            C_TradeSkillUI and C_TradeSkillUI.GetProfessionInfoBySkillLineID,
            skillLineID
        )
        if type(professionInfo) == "table" and professionInfo.profession then
            knownProfessionEnums[professionInfo.profession] = true
        end
        AddKnownProfessionName(name)
        AddKnownProfessionName(SafeCall(
            C_TradeSkillUI and C_TradeSkillUI.GetTradeSkillDisplayName,
            skillLineID
        ))
    end
end

local function TextMentionsKnownProfession(text)
    if type(text) ~= "string" or text == "" then
        return false
    end

    local lowerText = text:lower()
    for name in pairs(knownProfessionNames) do
        if text:find(name, 1, true) or lowerText:find(name, 1, true) then
            return true
        end
    end
    return false
end

local function PlayerHasProfessionForSkillLine(skillLineID)
    if not professionDataReady then
        return nil
    end
    if not skillLineID then
        return false
    end
    if knownProfessionSkillLines[skillLineID] then
        return true
    end

    local info = SafeCall(
        C_TradeSkillUI and C_TradeSkillUI.GetProfessionInfoBySkillLineID,
        skillLineID
    )
    if type(info) == "table" then
        if info.profession and knownProfessionEnums[info.profession] then
            return true
        end
        if knownProfessionSkillLines[info.parentProfessionID]
            or knownProfessionSkillLines[info.professionID]
            or TextMentionsKnownProfession(info.parentProfessionName)
            or TextMentionsKnownProfession(info.professionName) then
            return true
        end
    end

    return TextMentionsKnownProfession(SafeCall(
        C_TradeSkillUI and C_TradeSkillUI.GetTradeSkillDisplayName,
        skillLineID
    ))
end

local function GetRecipeProfessionEnum(details)
    local itemClass = Enum and Enum.ItemClass or {}
    if details.classID ~= (itemClass.Recipe or 9) then
        return nil
    end

    local recipe = Enum and Enum.ItemRecipeSubclass or {}
    local profession = Enum and Enum.Profession or {}
    local professionByRecipeSubclass = {
        [recipe.Leatherworking or 1] = profession.Leatherworking or 2,
        [recipe.Tailoring or 2] = profession.Tailoring or 7,
        [recipe.Engineering or 3] = profession.Engineering or 8,
        [recipe.Blacksmithing or 4] = profession.Blacksmithing or 1,
        [recipe.Cooking or 5] = profession.Cooking or 5,
        [recipe.Alchemy or 6] = profession.Alchemy or 3,
        [recipe.FirstAid or 7] = profession.FirstAid or 0,
        [recipe.Enchanting or 8] = profession.Enchanting or 9,
        [recipe.Fishing or 9] = profession.Fishing or 10,
        [recipe.Jewelcrafting or 10] = profession.Jewelcrafting or 12,
        [recipe.Inscription or 11] = profession.Inscription or 13,
    }
    return professionByRecipeSubclass[details.subClassID]
end

local function HasRequiredProfession(itemID, itemLink, details, tooltip)
    if tooltip.requiredProfession ~= nil then
        if not professionDataReady then
            return nil
        end
        return knownProfessionEnums[tooltip.requiredProfession] == true
    end

    local requiredProfession = GetRecipeProfessionEnum(details)
    if requiredProfession ~= nil then
        if not professionDataReady then
            return nil
        end
        return knownProfessionEnums[requiredProfession] == true
    end

    local recipeClassID = Enum and Enum.ItemClass and Enum.ItemClass.Recipe or 9
    local isRecipe = details.classID == recipeClassID
    local itemInfo = itemLink or itemID
    local recipeProfessionInfo
    if isRecipe then
        local _, recipeID = SafeCall(C_Item and C_Item.GetItemSpell, itemInfo)
        recipeProfessionInfo = SafeCall(
            C_TradeSkillUI and C_TradeSkillUI.GetProfessionInfoByRecipeID,
            recipeID
        )
        if type(recipeProfessionInfo) == "table" and recipeProfessionInfo.profession then
            if not professionDataReady then
                return nil
            end
            return knownProfessionEnums[recipeProfessionInfo.profession] == true
        end
    end

    local professionClassID = Enum and Enum.ItemClass and Enum.ItemClass.Profession or 19
    if not tooltip.skillBlocked and details.classID ~= professionClassID then
        return nil
    end

    local skillLineID = SafeCall(
        C_TradeSkillUI and C_TradeSkillUI.GetSkillLineForGear,
        itemInfo
    )
    if skillLineID then
        return PlayerHasProfessionForSkillLine(skillLineID)
    end

    if TextMentionsKnownProfession(details.itemSubType)
        or TextMentionsKnownProfession(tooltip.skillText) then
        return true
    end

    return professionDataReady and false or nil
end

local function IsWrongArmorType(details)
    local armorClassID = Enum and Enum.ItemClass and Enum.ItemClass.Armor or 4
    local armorSlots = {
        INVTYPE_HEAD = true,
        INVTYPE_SHOULDER = true,
        INVTYPE_CHEST = true,
        INVTYPE_ROBE = true,
        INVTYPE_WAIST = true,
        INVTYPE_LEGS = true,
        INVTYPE_FEET = true,
        INVTYPE_WRIST = true,
        INVTYPE_HAND = true,
        INVTYPE_SHIELD = true,
    }
    if details.classID ~= armorClassID or not armorSlots[details.equipLoc] then
        return false
    end

    local armor = Enum and Enum.ItemArmorSubclass or {}
    local preferredByClass = {
        WARRIOR = armor.Plate or 4,
        PALADIN = armor.Plate or 4,
        HUNTER = armor.Mail or 3,
        ROGUE = armor.Leather or 2,
        PRIEST = armor.Cloth or 1,
        DEATHKNIGHT = armor.Plate or 4,
        SHAMAN = armor.Mail or 3,
        MAGE = armor.Cloth or 1,
        WARLOCK = armor.Cloth or 1,
        MONK = armor.Leather or 2,
        DRUID = armor.Leather or 2,
        DEMONHUNTER = armor.Leather or 2,
        EVOKER = armor.Mail or 3,
    }
    local _, classToken = UnitClass("player")
    local preferredArmor = preferredByClass[classToken]
    local subClassID = details.subClassID
    if type(subClassID) ~= "number" then
        return false
    end

    if subClassID >= (armor.Cloth or 1) and subClassID <= (armor.Plate or 4) then
        return preferredArmor and subClassID ~= preferredArmor or false
    end

    if subClassID == (armor.Shield or 6) then
        return classToken ~= "WARRIOR" and classToken ~= "PALADIN" and classToken ~= "SHAMAN"
    end
    return false
end

local function IsIrrelevantItem(itemID, itemLink, details, tooltip)
    if HasRequiredProfession(itemID, itemLink, details, tooltip) == false then
        return true
    end

    if tooltip.permanentMismatch then
        return true
    end

    local recipeClassID = Enum and Enum.ItemClass and Enum.ItemClass.Recipe or 9
    if details.classID ~= recipeClassID
        and (tooltip.equipMismatch or IsWrongArmorType(details)) then
        return true
    end
    return false
end

local function IsCollectedTransmog(itemID, itemLink)
    if not C_TransmogCollection or type(C_TransmogCollection.GetItemInfo) ~= "function" then
        return false
    end

    local _, sourceID = SafeCall(C_TransmogCollection.GetItemInfo, itemLink or itemID)
    if not sourceID or sourceID == 0 then
        return false
    end

    if type(C_TransmogCollection.PlayerHasTransmogItemModifiedAppearance) == "function" then
        if SafeCall(C_TransmogCollection.PlayerHasTransmogItemModifiedAppearance, sourceID) == true then
            return true
        end
    end

    if type(C_TransmogCollection.GetAppearanceInfoBySource) == "function" then
        local info = SafeCall(C_TransmogCollection.GetAppearanceInfoBySource, sourceID)
        if type(info) == "table" then
            return info.appearanceIsCollected == true
        end
    end

    if type(C_TransmogCollection.GetSourceInfo) == "function" then
        local info = SafeCall(C_TransmogCollection.GetSourceInfo, sourceID)
        if type(info) == "table" then
            return info.isCollected == true
        end
    end
    return false
end

local function IsCollectedPet(itemID)
    if not C_PetJournal or type(C_PetJournal.GetPetInfoByItemID) ~= "function" then
        return false
    end

    local _, _, _, creatureID, _, _, _, _, _, _, _, _, speciesID =
        SafeCall(C_PetJournal.GetPetInfoByItemID, itemID)
    if not speciesID then
        return false
    end

    if type(C_PetJournal.GetNumCollectedInfo) == "function" then
        local numCollected = SafeCall(C_PetJournal.GetNumCollectedInfo, speciesID)
        return (tonumber(numCollected) or 0) > 0
    end

    if type(C_PetJournal.GetNumPetsInJournal) == "function" then
        local _, numPets = SafeCall(C_PetJournal.GetNumPetsInJournal, creatureID)
        return (tonumber(numPets) or 0) > 0
    end
    return false
end

local function IsCollectedMount(itemID)
    if not C_MountJournal or type(C_MountJournal.GetMountFromItem) ~= "function" then
        return false
    end

    local mountID = SafeCall(C_MountJournal.GetMountFromItem, itemID)
    if not mountID or type(C_MountJournal.GetMountInfoByID) ~= "function" then
        return false
    end
    return select(11, SafeCall(C_MountJournal.GetMountInfoByID, mountID)) == true
end

local function IsCollectedItem(itemID, itemLink)
    if type(PlayerHasToy) == "function" and SafeCall(PlayerHasToy, itemID) == true then
        return true
    end

    if C_Heirloom and type(C_Heirloom.IsItemHeirloom) == "function"
        and SafeCall(C_Heirloom.IsItemHeirloom, itemID) == true
        and type(C_Heirloom.PlayerHasHeirloom) == "function"
        and SafeCall(C_Heirloom.PlayerHasHeirloom, itemID) == true then
        return true
    end

    return IsCollectedMount(itemID)
        or IsCollectedPet(itemID)
        or IsCollectedTransmog(itemID, itemLink)
end

local function ShouldHideMerchantItem(index)
    local itemID = GetMerchantItemIDCompat(index)
    local itemLink = GetMerchantItemLinkCompat(index)
    if not itemID and not itemLink then
        return false
    end

    local details = GetItemDetails(itemID, itemLink)
    if not details then
        return false
    end

    local cacheKey = itemID or itemLink
    if knownCache[cacheKey] ~= nil then
        return knownCache[cacheKey]
    end

    local recipeClassID = Enum and Enum.ItemClass and Enum.ItemClass.Recipe or 9
    local isRecipe = details.classID == recipeClassID
    local tooltip = AnalyzeTooltip(index)

    if db.hideKnownRecipes and isRecipe and tooltip.known then
        knownCache[cacheKey] = true
        return true
    end

    if db.hideCollected and not isRecipe and itemID and IsCollectedItem(itemID, itemLink) then
        knownCache[cacheKey] = true
        return true
    end

    if db.hideCollected and not isRecipe and tooltip.known then
        knownCache[cacheKey] = true
        return true
    end

    if db.hideIrrelevant and IsIrrelevantItem(itemID, itemLink, details, tooltip) then
        knownCache[cacheKey] = true
        return true
    end

    knownCache[cacheKey] = false
    return false
end

local function BuildVisibleIndices()
    local visible = {}
    local hidden = 0

    RefreshKnownProfessions()
    for index = 1, GetMerchantItemCount() do
        if ShouldHideMerchantItem(index) then
            hidden = hidden + 1
        else
            visible[#visible + 1] = index
        end
    end

    return visible, hidden
end

local function ResetMerchantSlot(slot)
    local itemButton = _G["MerchantItem" .. slot .. "ItemButton"]
    local merchantButton = _G["MerchantItem" .. slot]
    if not itemButton or not merchantButton then
        return
    end

    itemButton.price = nil
    itemButton.extendedCost = nil
    itemButton.hasItem = nil
    itemButton.name = nil
    itemButton.link = nil
    itemButton.texture = nil
    itemButton:Hide()

    SetItemButtonNameFrameVertexColor(merchantButton, 0.5, 0.5, 0.5)
    SetItemButtonSlotVertexColor(merchantButton, 0.4, 0.4, 0.4)
    _G["MerchantItem" .. slot .. "Name"]:SetText("")
    _G["MerchantItem" .. slot .. "MoneyFrame"]:Hide()
    _G["MerchantItem" .. slot .. "AltCurrencyFrame"]:Hide()
end

local function SetMerchantMoneyColor(moneyFrame, canAfford)
    if canAfford then
        SetMoneyFrameColor(moneyFrame:GetName())
    else
        SetMoneyFrameColor(moneyFrame:GetName(), "gray")
    end
end

local function PositionCostFrames(itemButton, moneyFrame, altCurrencyFrame, hasExtendedCost, hasMoneyCost)
    altCurrencyFrame:ClearAllPoints()

    if useElvMerchantLayout then
        moneyFrame:ClearAllPoints()
        moneyFrame:SetPoint("BOTTOMLEFT", itemButton, "BOTTOMRIGHT", 5, -3)
        if hasExtendedCost and hasMoneyCost then
            altCurrencyFrame:SetPoint("LEFT", moneyFrame, "RIGHT", -8, 0)
        else
            altCurrencyFrame:SetPoint("BOTTOMLEFT", itemButton, "BOTTOMRIGHT", 5, -3)
        end
    elseif hasExtendedCost and hasMoneyCost then
        altCurrencyFrame:SetPoint("LEFT", moneyFrame:GetName(), "RIGHT", -14, 0)
    else
        local nameFrame = _G[itemButton:GetParent():GetName() .. "NameFrame"]
        altCurrencyFrame:SetPoint("BOTTOMLEFT", nameFrame, "BOTTOMLEFT", 0, 31)
    end
end

local function RenderMerchantSlot(slot, index)
    local itemButton = _G["MerchantItem" .. slot .. "ItemButton"]
    local merchantButton = _G["MerchantItem" .. slot]
    local merchantMoney = _G["MerchantItem" .. slot .. "MoneyFrame"]
    local merchantAltCurrency = _G["MerchantItem" .. slot .. "AltCurrencyFrame"]
    local info = C_MerchantFrame and SafeCall(C_MerchantFrame.GetItemInfo, index)
    if not itemButton or not merchantButton or type(info) ~= "table" then
        ResetMerchantSlot(slot)
        return
    end

    if info.currencyID and CurrencyContainerUtil and CurrencyContainerUtil.GetCurrencyContainerInfo then
        info.name, info.texture, info.numAvailable = CurrencyContainerUtil.GetCurrencyContainerInfo(
            info.currencyID, info.numAvailable, info.name, info.texture, nil
        )
    end

    local canAfford = SafeCall(CanAffordMerchantItem, index) ~= false
    local itemLink = GetMerchantItemLinkCompat(index)
    local itemID = GetMerchantItemIDCompat(index)

    _G["MerchantItem" .. slot .. "Name"]:SetText(info.name)
    SetItemButtonCount(itemButton, info.stackCount)
    SetItemButtonStock(itemButton, info.numAvailable)
    SetItemButtonTexture(itemButton, info.texture)

    if info.hasExtendedCost and info.price <= 0 then
        itemButton.price = nil
    else
        itemButton.price = info.price
    end
    itemButton.extendedCost = info.hasExtendedCost or nil
    itemButton.name = info.name
    itemButton.link = itemLink
    itemButton.texture = info.texture

    if info.hasExtendedCost then
        local altCurrencyWidth = MerchantFrame_UpdateAltCurrency(index, slot, canAfford)
        if info.price > 0 then
            MoneyFrame_SetMaxDisplayWidth(merchantMoney, 120 - altCurrencyWidth)
            MoneyFrame_Update(merchantMoney:GetName(), info.price)
            SetMerchantMoneyColor(merchantMoney, canAfford)
            PositionCostFrames(itemButton, merchantMoney, merchantAltCurrency, true, true)
            merchantMoney:Show()
        else
            PositionCostFrames(itemButton, merchantMoney, merchantAltCurrency, true, false)
            merchantMoney:Hide()
        end
        merchantAltCurrency:Show()
    else
        MoneyFrame_SetMaxDisplayWidth(merchantMoney, 120)
        MoneyFrame_Update(merchantMoney:GetName(), info.price)
        SetMerchantMoneyColor(merchantMoney, canAfford)
        if useElvMerchantLayout then
            PositionCostFrames(itemButton, merchantMoney, merchantAltCurrency, false, true)
        end
        merchantAltCurrency:Hide()
        merchantMoney:Show()
    end

    itemButton.IconQuestTexture:SetShown(info.isQuestStartItem == true)
    if info.isQuestStartItem then
        itemButton.IconQuestTexture:SetTexture(TEXTURE_ITEM_QUEST_BANG)
    end

    MerchantFrameItem_UpdateQuality(merchantButton, itemLink)

    local isHeirloom = itemID and C_Heirloom and SafeCall(C_Heirloom.IsItemHeirloom, itemID) == true
    local isKnownHeirloom = isHeirloom and SafeCall(C_Heirloom.PlayerHasHeirloom, itemID) == true
    local tintRed = not info.isPurchasable or (not info.isUsable and not isHeirloom)

    itemButton.showNonrefundablePrompt = C_MerchantFrame
        and SafeCall(C_MerchantFrame.IsMerchantItemRefundable, index) == false
    itemButton.hasItem = true
    itemButton:SetID(index)
    itemButton:Show()
    SetItemButtonDesaturated(itemButton, isKnownHeirloom)

    if info.numAvailable == 0 or isKnownHeirloom then
        local red = tintRed and 0 or 0.5
        SetItemButtonNameFrameVertexColor(merchantButton, 0.5, red, red)
        SetItemButtonSlotVertexColor(merchantButton, 0.5, red, red)
        SetItemButtonTextureVertexColor(itemButton, 0.5, red, red)
        SetItemButtonNormalTextureVertexColor(itemButton, 0.5, red, red)
    elseif tintRed then
        SetItemButtonNameFrameVertexColor(merchantButton, 1, 0, 0)
        SetItemButtonSlotVertexColor(merchantButton, 1, 0, 0)
        SetItemButtonTextureVertexColor(itemButton, 0.9, 0, 0)
        SetItemButtonNormalTextureVertexColor(itemButton, 0.9, 0, 0)
    else
        SetItemButtonNameFrameVertexColor(merchantButton, 0.5, 0.5, 0.5)
        SetItemButtonSlotVertexColor(merchantButton, 1, 1, 1)
        SetItemButtonTextureVertexColor(itemButton, 1, 1, 1)
        SetItemButtonNormalTextureVertexColor(itemButton, 1, 1, 1)
    end
end

local function UpdatePaging(visibleCount)
    local perPage = MERCHANT_ITEMS_PER_PAGE or 10
    local pageCount = math.max(1, math.ceil(visibleCount / perPage))
    MerchantFrame.page = math.max(1, math.min(MerchantFrame.page or 1, pageCount))

    if visibleCount > perPage then
        MerchantPageText:SetFormattedText(MERCHANT_PAGE_NUMBER, MerchantFrame.page, pageCount)
        MerchantPageText:Show()
        MerchantPrevPageButton:Show()
        MerchantNextPageButton:Show()
        MerchantPrevPageButton:SetEnabled(MerchantFrame.page > 1)
        MerchantNextPageButton:SetEnabled(MerchantFrame.page < pageCount)
    else
        MerchantPageText:Hide()
        MerchantPrevPageButton:Hide()
        MerchantNextPageButton:Hide()
    end
end

local function ApplyFilter()
    if not db or not toggle or not MerchantFrame or MerchantFrame.selectedTab ~= 1 then
        return
    end

    toggle:Show()
    toggle:SetChecked(db.enabled)
    if not db.enabled then
        emptyText:Hide()
        return
    end

    local visible, hidden = BuildVisibleIndices()
    lastHiddenCount = hidden
    UpdatePaging(#visible)

    local perPage = MERCHANT_ITEMS_PER_PAGE or 10
    local first = ((MerchantFrame.page or 1) - 1) * perPage
    local mapping = table.concat(visible, ",", first + 1, math.min(first + perPage, #visible))
    if mapping ~= lastMapping then
        SafeCall(MerchantFrame_CloseStackSplitFrame)
        if MerchantFrame.itemHover then
            MerchantFrame.itemHover = nil
            GameTooltip:Hide()
            ResetCursor()
        end
        lastMapping = mapping
    end

    for slot = 1, perPage do
        local merchantIndex = visible[first + slot]
        if merchantIndex then
            RenderMerchantSlot(slot, merchantIndex)
        else
            ResetMerchantSlot(slot)
        end
    end

    emptyText:SetShown(#visible == 0 and hidden > 0)
end

local function AfterMerchantUpdate()
    ApplyFilter()

    if repaintPending then
        return
    end
    repaintPending = true
    C_Timer.After(0.12, function()
        repaintPending = false
        if MerchantFrame and MerchantFrame:IsShown() then
            ApplyFilter()
        end
    end)
end

local function ScheduleRefresh()
    if refreshPending then
        return
    end
    refreshPending = true
    C_Timer.After(0.1, function()
        refreshPending = false
        if MerchantFrame and MerchantFrame:IsShown() and type(MerchantFrame_Update) == "function" then
            MerchantFrame_Update()
        end
    end)
end

local function SetEnabled(enabled)
    db.enabled = enabled == true
    SafeCall(MerchantFrame_CloseStackSplitFrame)
    lastMapping = nil
    if MerchantFrame then
        MerchantFrame.page = 1
    end
    ScheduleRefresh()
end

local function CreateMerchantControls()
    if toggle or not MerchantFrame then
        return
    end

    toggle = CreateFrame("CheckButton", "YayaVendorFilterToggle", MerchantFrame, "UICheckButtonTemplate")
    toggle:SetSize(22, 22)
    toggle:SetPoint("BOTTOMLEFT", MerchantFrame, "BOTTOMLEFT", 108, 52)
    toggle:SetChecked(db.enabled)
    local label = toggle.Text
    if not label then
        label = toggle:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        label:SetPoint("LEFT", toggle, "RIGHT", 2, 0)
    end
    label:SetText("Masquer inutiles")
    toggle:SetScript("OnClick", function(self)
        SetEnabled(self:GetChecked())
    end)
    toggle:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Yaya Vendor Filter")
        GameTooltip:AddLine(
            "Masque les objets acquis ou incompatibles avec ta classe, ton armure ou tes metiers.",
            1, 1, 1, true
        )
        GameTooltip:AddLine("Un niveau de metier insuffisant ne masque pas l'objet.", 0.8, 0.8, 0.8, true)
        if db.enabled then
            GameTooltip:AddLine(string.format("%d objet(s) masque(s) chez ce vendeur.", lastHiddenCount), 0.3, 1, 0.3)
        end
        GameTooltip:Show()
    end)
    toggle:SetScript("OnLeave", GameTooltip_Hide)

    emptyText = MerchantFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    emptyText:SetPoint("CENTER", MerchantFrame, "CENTER", 0, 15)
    emptyText:SetText("Rien d'utile chez ce vendeur")
    emptyText:Hide()

    local engine = type(ElvUI) == "table" and ElvUI[1] or nil
    useElvMerchantLayout = engine and engine.private and engine.private.skins
        and engine.private.skins.blizzard and engine.private.skins.blizzard.enable
        and engine.private.skins.blizzard.merchant or false
end

local function InstallHooks()
    if hooked or type(MerchantFrame_UpdateMerchantInfo) ~= "function" or not MerchantFrame then
        return
    end

    CreateMerchantControls()
    hooksecurefunc("MerchantFrame_UpdateMerchantInfo", AfterMerchantUpdate)
    hooksecurefunc("MerchantFrame_UpdateBuybackInfo", function()
        if toggle then
            toggle:Hide()
        end
        if emptyText then
            emptyText:Hide()
        end
    end)
    hooked = true
end

local function InitializeDatabase()
    YayaVendorFilterDB = type(YayaVendorFilterDB) == "table" and YayaVendorFilterDB or {}
    db = YayaVendorFilterDB
    for key, value in pairs(DEFAULTS) do
        if db[key] == nil then
            db[key] = value
        end
    end
end

local function WarnIfTSMIsVisible()
    if tsmWarningShown then
        return
    end

    C_Timer.After(0.2, function()
        local vendoringUI = TSM and TSM.UI and TSM.UI.VendoringUI
        if not tsmWarningShown and vendoringUI and type(vendoringUI.IsVisible) == "function"
            and SafeCall(vendoringUI.IsVisible) == true then
            tsmWarningShown = true
            Print("TSM utilise sa propre liste : clique sur le bouton WoW UI pour voir le filtre.")
        end
    end)
end

-- Evenements de collection : ils invalident le cache de possession, mais ne
-- servent que fenetre marchand ouverte. TRANSMOG_COLLECTION_UPDATED,
-- PET_JOURNAL_LIST_UPDATE et TOYS_UPDATED sont tres bavards hors de ce
-- contexte : on ne s'y abonne qu'entre MERCHANT_SHOW et MERCHANT_CLOSED.
local COLLECTION_EVENTS = {
    "GET_ITEM_INFO_RECEIVED",
    "MERCHANT_FILTER_ITEM_UPDATE",
    "SPELLS_CHANGED",
    "TOYS_UPDATED",
    "NEW_TOY_ADDED",
    "NEW_MOUNT_ADDED",
    "PET_JOURNAL_LIST_UPDATE",
    "NEW_PET_ADDED",
    "TRANSMOG_COLLECTION_UPDATED",
    "TRANSMOG_COLLECTION_SOURCE_ADDED",
    "SKILL_LINES_CHANGED",
}

local collectionEventsActive = false

local function SetCollectionEventsRegistered(enabled)
    enabled = enabled and true or false
    if collectionEventsActive == enabled then
        return
    end
    collectionEventsActive = enabled
    for _, eventName in ipairs(COLLECTION_EVENTS) do
        if enabled then
            frame:RegisterEvent(eventName)
        else
            frame:UnregisterEvent(eventName)
        end
    end
end

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("MERCHANT_SHOW")
frame:RegisterEvent("MERCHANT_CLOSED")
frame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" and ... == ADDON_NAME then
        InitializeDatabase()
        InstallHooks()
    elseif event == "MERCHANT_CLOSED" then
        -- Le cache n'etait vide qu'a l'ouverture : sans cela il survivait a la
        -- fermeture et pouvait etre relu plus tard avec des donnees perimees.
        SetCollectionEventsRegistered(false)
        wipe(knownCache)
    elseif event == "PLAYER_LOGIN" or event == "MERCHANT_SHOW" then
        wipe(knownCache)
        InstallHooks()
        if event == "MERCHANT_SHOW" then
            SetCollectionEventsRegistered(true)
        end
        ScheduleRefresh()
        if event == "MERCHANT_SHOW" then
            WarnIfTSMIsVisible()
        end
    elseif MerchantFrame and MerchantFrame:IsShown() then
        wipe(knownCache)
        ScheduleRefresh()
    end
end)

SLASH_YAYAVENDORFILTER1 = "/yvf"
SlashCmdList.YAYAVENDORFILTER = function(message)
    local command = strtrim(message or ""):lower()
    if command == "on" then
        SetEnabled(true)
    elseif command == "off" then
        SetEnabled(false)
    else
        SetEnabled(not db.enabled)
    end
    Print(db.enabled and "filtre active." or "filtre desactive.")
end
