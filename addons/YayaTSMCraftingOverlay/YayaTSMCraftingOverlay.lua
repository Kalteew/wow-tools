local addonName = ...

local addon = CreateFrame("Frame")
local state = {
    panel = nil,
    parent = nil,
    firstCraftLabel = nil,
    onlyFirstCheck = nil,
    concentrationCheck = nil,
    concentrationBar = nil,
    concentrationText = nil,
    queueButton = nil,
    statusText = nil,
    lastRecipeID = nil,
    elapsed = 0,
    callbackRegistered = false,
}

local function SafeCall(func, ...)
    if type(func) ~= "function" then
        return nil
    end
    local ok, result = pcall(func, ...)
    if ok then
        return result
    end
    return nil
end

local function Print(message)
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99" .. addonName .. "|r: " .. message)
end

local function HasTSMQueue()
    return type(TSM) == "table"
        and type(TSM.Crafting) == "table"
        and type(TSM.Crafting.Queue) == "table"
        and type(TSM.Crafting.Queue.Adjust) == "function"
end

local function GetSelectedRecipeID()
    if type(C_TradeSkillUI) ~= "table" or type(C_TradeSkillUI.GetSelectedRecipeID) ~= "function" then
        return nil
    end
    local recipeID = SafeCall(C_TradeSkillUI.GetSelectedRecipeID)
    if type(recipeID) == "number" and recipeID > 0 then
        return recipeID
    end
    return nil
end

local function GetRecipeInfo(recipeID)
    if type(recipeID) ~= "number" or type(C_TradeSkillUI) ~= "table" or type(C_TradeSkillUI.GetRecipeInfo) ~= "function" then
        return nil
    end
    return SafeCall(C_TradeSkillUI.GetRecipeInfo, recipeID)
end

local function GetOperationInfo(recipeID)
    if type(recipeID) ~= "number" or type(C_TradeSkillUI) ~= "table" or type(C_TradeSkillUI.GetCraftingOperationInfo) ~= "function" then
        return nil
    end
    return SafeCall(C_TradeSkillUI.GetCraftingOperationInfo, recipeID, {}, nil, false)
end

local function GetCraftString(recipeID)
    local operationInfo = GetOperationInfo(recipeID)
    local quality = operationInfo and operationInfo.quality or nil
    local qualifiedCraftString = quality and ("c:" .. recipeID .. ":q" .. quality) or nil
    if qualifiedCraftString and TSM and TSM.Crafting and TSM.Crafting.HasCraftString(qualifiedCraftString) then
        return qualifiedCraftString
    end

    local baseCraftString = "c:" .. recipeID
    if TSM and TSM.Crafting and TSM.Crafting.HasCraftString(baseCraftString) then
        return baseCraftString
    end
    return nil
end

local function GetRecipeString(recipeID, useConcentration)
    local craftString = GetCraftString(recipeID)
    if not craftString then
        return nil
    end

    local recipeString = "r:" .. recipeID
    local concentrationCost = 0
    local operationInfo = GetOperationInfo(recipeID)
    if useConcentration and operationInfo and tonumber(operationInfo.concentrationCost) and tonumber(operationInfo.concentrationCost) > 0 then
        concentrationCost = tonumber(operationInfo.concentrationCost)
        recipeString = recipeString .. ":c" .. concentrationCost
    end

    local quality = string.match(craftString, ":q(%d+)$")
    if quality then
        recipeString = recipeString .. ":q" .. quality
    end
    return recipeString, concentrationCost
end

local function GetConcentrationState(recipeID)
    local operationInfo = GetOperationInfo(recipeID)
    local cost = operationInfo and tonumber(operationInfo.concentrationCost) or 0
    local currencyID = operationInfo and operationInfo.concentrationCurrencyID or nil
    local available = 0
    if cost > 0 and currencyID and C_CurrencyInfo and type(C_CurrencyInfo.GetCurrencyInfo) == "function" then
        local currencyInfo = SafeCall(C_CurrencyInfo.GetCurrencyInfo, currencyID)
        available = currencyInfo and tonumber(currencyInfo.quantity) or 0
    end
    return {
        cost = cost,
        available = available,
    }
end

local function IsOnlyFirstEnabled()
    return state.onlyFirstCheck and state.onlyFirstCheck:GetChecked() and true or false
end

local function IsConcentrationEnabled()
    return state.concentrationCheck and state.concentrationCheck:GetChecked() and true or false
end

local function UpdatePanel()
    if not state.panel then
        return
    end

    local recipeID = GetSelectedRecipeID()
    state.lastRecipeID = recipeID

    local enabled = false
    local status = "Aucune recette"

    if not recipeID then
        state.firstCraftLabel:SetText("|cff999999First craft inconnu|r")
        state.concentrationBar:Hide()
        state.concentrationText:SetText("Pas de concentration")
        state.concentrationCheck:SetChecked(false)
        state.concentrationCheck:Disable()
    else
        local recipeInfo = GetRecipeInfo(recipeID)
        local concentration = GetConcentrationState(recipeID)

        if recipeInfo and recipeInfo.firstCraft then
            state.firstCraftLabel:SetText("|cff33ff99First craft|r")
        else
            state.firstCraftLabel:SetText("|cff999999First craft deja fait|r")
        end

        if concentration.cost > 0 then
            local maxValue = math.max(concentration.available, concentration.cost, 1)
            state.concentrationBar:SetMinMaxValues(0, maxValue)
            state.concentrationBar:SetValue(math.min(concentration.available, maxValue))
            state.concentrationBar:Show()
            state.concentrationText:SetText("Conc. " .. concentration.available .. " / " .. concentration.cost)
            state.concentrationCheck:Enable()
        else
            state.concentrationBar:Hide()
            state.concentrationText:SetText("Pas de concentration")
            state.concentrationCheck:SetChecked(false)
            state.concentrationCheck:Disable()
        end

        if not HasTSMQueue() then
            status = "Queue TSM absente"
        elseif IsOnlyFirstEnabled() and recipeInfo and not recipeInfo.firstCraft then
            status = "Pas un first craft"
        elseif IsConcentrationEnabled() and concentration.cost > concentration.available then
            status = "Concentration insuffisante"
        elseif GetRecipeString(recipeID, IsConcentrationEnabled()) then
            enabled = true
            status = IsConcentrationEnabled() and "Queue current + conc." or "Queue current"
        else
            status = "Recette TSM introuvable"
        end
    end

    state.queueButton:SetEnabled(enabled)
    state.statusText:SetText(status)
end

local function QueueCurrentRecipe()
    local recipeID = state.lastRecipeID or GetSelectedRecipeID()
    if not recipeID then
        Print("Aucune recette selectionnee.")
        return
    end

    local recipeString = GetRecipeString(recipeID, IsConcentrationEnabled())
    if not recipeString then
        Print("Recette absente de la base TSM.")
        return
    end

    TSM.Crafting.Queue.Adjust(recipeString, 1)
    Print("Ajoute 1 recette a la queue TSM.")
    UpdatePanel()
end

local function CreatePanel(parent)
    if state.panel then
        state.panel:SetParent(parent)
        state.parent = parent
        return
    end

    local panel = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    panel:SetSize(220, 108)
    panel:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -40, -34)
    panel:SetFrameStrata("HIGH")
    panel:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    panel:SetBackdropColor(0.05, 0.05, 0.05, 0.92)

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    title:SetPoint("TOPLEFT", 10, -8)
    title:SetText("TSM extras")

    local firstCraftLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    firstCraftLabel:SetPoint("TOPRIGHT", -10, -8)
    firstCraftLabel:SetText("First craft inconnu")

    local onlyFirstCheck = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    onlyFirstCheck:SetPoint("TOPLEFT", title, "BOTTOMLEFT", -4, -6)
    onlyFirstCheck:SetScript("OnClick", UpdatePanel)
    local onlyFirstText = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    onlyFirstText:SetPoint("LEFT", onlyFirstCheck, "RIGHT", -2, 1)
    onlyFirstText:SetText("Only first")

    local concentrationCheck = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    concentrationCheck:SetPoint("LEFT", onlyFirstCheck, "RIGHT", 82, 0)
    concentrationCheck:SetScript("OnClick", UpdatePanel)
    local concentrationCheckText = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    concentrationCheckText:SetPoint("LEFT", concentrationCheck, "RIGHT", -2, 1)
    concentrationCheckText:SetText("Use conc.")

    local concentrationBar = CreateFrame("StatusBar", nil, panel)
    concentrationBar:SetSize(194, 10)
    concentrationBar:SetPoint("TOPLEFT", onlyFirstCheck, "BOTTOMLEFT", 8, -4)
    concentrationBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    concentrationBar:SetStatusBarColor(0.18, 0.65, 1.0)
    concentrationBar:SetMinMaxValues(0, 1)
    concentrationBar:SetValue(0)
    concentrationBar:Hide()
    local concentrationBg = concentrationBar:CreateTexture(nil, "BACKGROUND")
    concentrationBg:SetAllPoints()
    concentrationBg:SetColorTexture(0.12, 0.12, 0.12, 0.9)

    local concentrationText = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    concentrationText:SetPoint("TOPLEFT", concentrationBar, "BOTTOMLEFT", 0, -3)
    concentrationText:SetPoint("RIGHT", panel, "RIGHT", -10, 0)
    concentrationText:SetJustifyH("LEFT")
    concentrationText:SetText("Pas de concentration")

    local queueButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    queueButton:SetSize(104, 22)
    queueButton:SetPoint("TOPLEFT", concentrationText, "BOTTOMLEFT", 0, -6)
    queueButton:SetText("Queue current")
    queueButton:SetScript("OnClick", QueueCurrentRecipe)

    local statusText = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    statusText:SetPoint("LEFT", queueButton, "RIGHT", 8, 0)
    statusText:SetPoint("RIGHT", panel, "RIGHT", -10, 0)
    statusText:SetJustifyH("LEFT")
    statusText:SetText("")

    state.panel = panel
    state.parent = parent
    state.firstCraftLabel = firstCraftLabel
    state.onlyFirstCheck = onlyFirstCheck
    state.concentrationCheck = concentrationCheck
    state.concentrationBar = concentrationBar
    state.concentrationText = concentrationText
    state.queueButton = queueButton
    state.statusText = statusText
end

local function HandleTSMUIVisible(isVisible, frame)
    if not isVisible then
        if state.panel then
            state.panel:Hide()
            state.panel:SetScript("OnUpdate", nil)
        end
        return
    end

    if not frame then
        return
    end

    CreatePanel(frame)
    state.panel:ClearAllPoints()
    state.panel:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -40, -34)
    state.panel:Show()
    state.panel:SetScript("OnUpdate", function(_, elapsed)
        state.elapsed = state.elapsed + elapsed
        if state.elapsed < 0.2 then
            return
        end
        state.elapsed = 0
        UpdatePanel()
    end)
    UpdatePanel()
end

local function RegisterCallback()
    if state.callbackRegistered or type(TSM_API) ~= "table" or type(TSM_API.RegisterUICallback) ~= "function" then
        return
    end
    TSM_API.RegisterUICallback("CRAFTING", addonName .. ":Overlay", HandleTSMUIVisible)
    state.callbackRegistered = true
end

addon:SetScript("OnEvent", function(_, event, arg1)
    if event ~= "ADDON_LOADED" then
        return
    end

    if arg1 == addonName then
        RegisterCallback()
    elseif arg1 == "TradeSkillMaster" then
        RegisterCallback()
    end
end)

addon:RegisterEvent("ADDON_LOADED")
