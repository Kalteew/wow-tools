Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$script:TaskName = "TSM Auto Patch Watcher"
$script:WatcherMutexName = "Local\TSMAutoPatchWatcher"
$script:StartupLauncherName = "TSM Auto Patch Watcher.vbs"
$script:DefaultAddonCandidates = @(
    "C:\Program Files (x86)\World of Warcraft\_retail_\Interface\AddOns\TradeSkillMaster",
    "C:\Program Files\World of Warcraft\_retail_\Interface\AddOns\TradeSkillMaster",
    "D:\World of Warcraft\_retail_\Interface\AddOns\TradeSkillMaster",
    "E:\World of Warcraft\_retail_\Interface\AddOns\TradeSkillMaster",
    (Join-Path $env:USERPROFILE "Games\World of Warcraft\_retail_\Interface\AddOns\TradeSkillMaster")
)

function Get-TSMAutoPatchLogPath {
    return Join-Path $PSScriptRoot "tsm-auto-patch.log"
}

function Get-TSMAutoPatchStartupPath {
    return Join-Path ([Environment]::GetFolderPath("Startup")) $script:StartupLauncherName
}

function Write-TSMAutoPatchLog {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        [switch]$Quiet
    )

    $line = "{0} {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Message
    Add-Content -LiteralPath (Get-TSMAutoPatchLogPath) -Value $line
    if (-not $Quiet) {
        Write-Host $line
    }
}

function Resolve-TSMAddonPath {
    param(
        [string]$AddonPath
    )

    if ($AddonPath) {
        if (-not (Test-Path -LiteralPath $AddonPath)) {
            throw "TSM addon path not found: $AddonPath"
        }
        return (Resolve-Path -LiteralPath $AddonPath).Path
    }

    foreach ($candidate in $script:DefaultAddonCandidates) {
        if (Test-Path -LiteralPath $candidate) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }

    throw "Unable to locate the TradeSkillMaster addon folder."
}

function Get-TSMAddonVersion {
    param(
        [Parameter(Mandatory = $true)]
        [string]$AddonPath
    )

    $tocPath = Join-Path $AddonPath "TradeSkillMaster.toc"
    if (-not (Test-Path -LiteralPath $tocPath)) {
        return "unknown"
    }

    $match = Select-String -Path $tocPath -Pattern "^## Version:\s*(.+)$" | Select-Object -First 1
    if ($match) {
        return $match.Matches[0].Groups[1].Value.Trim()
    }
    return "unknown"
}

function Replace-ExactBlock {
    param(
        [Parameter(Mandatory = $true)]
        [ref]$Content,
        [Parameter(Mandatory = $true)]
        [string]$Original,
        [Parameter(Mandatory = $true)]
        [string]$Patched,
        [Parameter(Mandatory = $true)]
        [string]$Label
    )

    $newline = if ($Content.Value.Contains("`r`n")) { "`r`n" } else { "`n" }
    $normalizedOriginal = [regex]::Replace($Original, "\r?\n", $newline)
    $normalizedPatched = [regex]::Replace($Patched, "\r?\n", $newline)

    if ($Content.Value.Contains($normalizedPatched)) {
        return $false
    }
    if (-not $Content.Value.Contains($normalizedOriginal)) {
        throw "Unexpected code in $Label."
    }

    $Content.Value = $Content.Value.Replace($normalizedOriginal, $normalizedPatched)
    return $true
}

function Update-TSMShoppingOperationFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )

    $content = Get-Content -LiteralPath $FilePath -Raw
    $changed = $false

    $original = @'
ShoppingOperation.ERROR = EnumType.New("SHOPPING_OPERATION_ERROR", {
	MAX_PRICE_INVALID = EnumType.NewValue(),
	RESTOCK_INVALID = EnumType.NewValue(),
	RESTOCK_INVALID_RANGE = EnumType.NewValue(),
})
'@
    $patched = @'
ShoppingOperation.ERROR = EnumType.New("SHOPPING_OPERATION_ERROR", {
	MAX_PRICE_INVALID = EnumType.NewValue(),
	RESTOCK_INVALID = EnumType.NewValue(),
	RESTOCK_INVALID_RANGE = EnumType.NewValue(),
	MIN_RESTOCK_INVALID = EnumType.NewValue(),
	MIN_RESTOCK_INVALID_RANGE = EnumType.NewValue(),
	RESTOCK_QUANTITIES_CONFLICT = EnumType.NewValue(),
})
'@
    $changed = (Replace-ExactBlock -Content ([ref]$content) -Original $original -Patched $patched -Label "LibTSMSystem\\Source\\Operation\\ShoppingOperation.lua errors") -or $changed

    $original = @'
		:AddCustomStringSetting("restockQuantity", "0")
'@
    $patched = @'
		:AddCustomStringSetting("minRestock", "1")
		:AddCustomStringSetting("restockQuantity", "0")
'@
    $changed = (Replace-ExactBlock -Content ([ref]$content) -Original $original -Patched $patched -Label "LibTSMSystem\\Source\\Operation\\ShoppingOperation.lua settings") -or $changed

    $original = @'
---Validates and gets the restock quantity for an item.
---@param itemString string The item string
---@return boolean isValid
---@return number|EnumValue|nil maxQuantityOrErrType
---@return any errArg
function ShoppingOperation.ValidateAndGetRestockQuantity(itemString)
	local operationSettings = Util.GetFirstOperationByItem(OPERATION_TYPE, itemString)
	if not operationSettings then
		return false, nil
	end
	if not CustomString.Validate(operationSettings.maxPrice) then
		return false, ShoppingOperation.ERROR.MAX_PRICE_INVALID, operationSettings.maxPrice
	end
	local restockQuantity = CustomString.GetValue(operationSettings.restockQuantity, itemString, true)
	if not restockQuantity then
		return false, ShoppingOperation.ERROR.RESTOCK_INVALID, operationSettings.restockQuantity
	elseif restockQuantity < MIN_RESTOCK_VALUE or restockQuantity > MAX_RESTOCK_VALUE then
		return false, ShoppingOperation.ERROR.RESTOCK_INVALID_RANGE, operationSettings.restockQuantity
	end
	local maxQuantity = nil
	if restockQuantity > 0 then
		local numHave = private.inventoryNumFunc(itemString, operationSettings.restockSources.bank, operationSettings.restockSources.auctions, operationSettings.restockSources.alts, operationSettings.restockSources.guild)
		if numHave >= restockQuantity then
			return false, nil
		end
		maxQuantity = restockQuantity - numHave
	end
	if not operationSettings.showAboveMaxPrice and not CustomString.GetValue(operationSettings.maxPrice, itemString) then
		-- We're not showing auctions above the max price and the max price isn't valid for this item, so skip it
		return false, nil
	end
	return true, maxQuantity
end
'@
    $patched = @'
---Validates and gets the restock quantity for an item.
---@param itemString string The item string
---@return boolean isValid
---@return number|EnumValue|nil maxQuantityOrErrType
---@return any errArg
---@return any errArg2
---@return any errArg3
function ShoppingOperation.ValidateAndGetRestockQuantity(itemString)
	local operationSettings, operationName = Util.GetFirstOperationByItem(OPERATION_TYPE, itemString)
	if not operationSettings then
		return false, nil
	end
	if not CustomString.Validate(operationSettings.maxPrice) then
		return false, ShoppingOperation.ERROR.MAX_PRICE_INVALID, operationSettings.maxPrice
	end
	local minRestock = CustomString.GetValue(operationSettings.minRestock, itemString, true)
	if not minRestock then
		return false, ShoppingOperation.ERROR.MIN_RESTOCK_INVALID, operationSettings.minRestock
	elseif minRestock < MIN_RESTOCK_VALUE or minRestock > MAX_RESTOCK_VALUE then
		return false, ShoppingOperation.ERROR.MIN_RESTOCK_INVALID_RANGE, operationSettings.minRestock
	end
	local restockQuantity = CustomString.GetValue(operationSettings.restockQuantity, itemString, true)
	if not restockQuantity then
		return false, ShoppingOperation.ERROR.RESTOCK_INVALID, operationSettings.restockQuantity
	elseif restockQuantity < MIN_RESTOCK_VALUE or restockQuantity > MAX_RESTOCK_VALUE then
		return false, ShoppingOperation.ERROR.RESTOCK_INVALID_RANGE, operationSettings.restockQuantity
	end
	if restockQuantity > 0 and minRestock > restockQuantity then
		return false, ShoppingOperation.ERROR.RESTOCK_QUANTITIES_CONFLICT, operationName, minRestock, restockQuantity
	end
	local maxQuantity = nil
	if restockQuantity > 0 then
		local numHave = private.inventoryNumFunc(itemString, operationSettings.restockSources.bank, operationSettings.restockSources.auctions, operationSettings.restockSources.alts, operationSettings.restockSources.guild)
		if numHave >= restockQuantity then
			return false, nil
		end
		maxQuantity = restockQuantity - numHave
		if maxQuantity < minRestock then
			return false, nil
		end
	end
	if not operationSettings.showAboveMaxPrice and not CustomString.GetValue(operationSettings.maxPrice, itemString) then
		-- We're not showing auctions above the max price and the max price isn't valid for this item, so skip it
		return false, nil
	end
	return true, maxQuantity
end
'@
    $changed = (Replace-ExactBlock -Content ([ref]$content) -Original $original -Patched $patched -Label "LibTSMSystem\\Source\\Operation\\ShoppingOperation.lua validation") -or $changed

    if ($changed) {
        Set-Content -LiteralPath $FilePath -Value $content -NoNewline
    }
    return $changed
}

function Update-TSMShoppingUIFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )

    $content = Get-Content -LiteralPath $FilePath -Raw
    $changed = $false

    $original = @'
local SETTING_TOOLTIPS = {
	maxPrice = L["The max price to show in the shopping results."],
	showAboveMaxPrice = L["If enabled, auctions above the defined max price will be shown in shopping results."],
	restockQuantity = L["The maximum number of items to have in your inventory."],
	restockSources = L["Select the inventory sources you would like to include when calculating how many of an item a character already has for restocking."],
}
'@
    $patched = @'
local SETTING_TOOLTIPS = {
	maxPrice = L["The max price to show in the shopping results."],
	showAboveMaxPrice = L["If enabled, auctions above the defined max price will be shown in shopping results."],
	minRestock = L["Minimum restock quantity"],
	restockQuantity = L["The maximum number of items to have in your inventory."],
	restockSources = L["Select the inventory sources you would like to include when calculating how many of an item a character already has for restocking."],
}
'@
    $changed = (Replace-ExactBlock -Content ([ref]$content) -Original $original -Patched $patched -Label "Core\\UI\\MainUI\\Operations\\Shopping.lua tooltips") -or $changed

    $original = @'
			:AddChild(TSM.MainUI.Operations.CreateLinkedPriceInput("restockQuantity", L["Maximum restock quantity"], MAX_QUANTITY_VALIDATE_CONTEXT, nil, nil, SETTING_TOOLTIPS.restockQuantity)
				:SetMargin(0, 0, 0, 12)
			)
'@
    $patched = @'
			:AddChild(TSM.MainUI.Operations.CreateLinkedPriceInput("minRestock", L["Minimum restock quantity"], MAX_QUANTITY_VALIDATE_CONTEXT, nil, nil, SETTING_TOOLTIPS.minRestock)
				:SetMargin(0, 0, 0, 12)
			)
			:AddChild(TSM.MainUI.Operations.CreateLinkedPriceInput("restockQuantity", L["Maximum restock quantity"], MAX_QUANTITY_VALIDATE_CONTEXT, nil, nil, SETTING_TOOLTIPS.restockQuantity)
				:SetMargin(0, 0, 0, 12)
			)
'@
    $changed = (Replace-ExactBlock -Content ([ref]$content) -Original $original -Patched $patched -Label "Core\\UI\\MainUI\\Operations\\Shopping.lua minimum restock input") -or $changed

    if ($changed) {
        Set-Content -LiteralPath $FilePath -Value $content -NoNewline
    }
    return $changed
}

function Update-TSMShoppingGroupSearchFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )

    $content = Get-Content -LiteralPath $FilePath -Raw
    $original = @'
function private.GetRestockQuantity(itemString)
	local isValid, maxQuantityOrErrType, errArg = ShoppingOperation.ValidateAndGetRestockQuantity(itemString)
	if isValid then
		return true, maxQuantityOrErrType
	end
	if maxQuantityOrErrType == ShoppingOperation.ERROR.MAX_PRICE_INVALID then
		local _, errStr = CustomPrice.GetValue(errArg, itemString, true)
		ChatMessage.PrintfUser(L["Your max price (%s) is invalid for %s."].." "..errStr, errArg, ItemInfo.GetLink(itemString))
	elseif maxQuantityOrErrType == ShoppingOperation.ERROR.RESTOCK_INVALID then
		local _, errStr = CustomPrice.GetValue(errArg, itemString, true)
		ChatMessage.PrintfUser(L["Your min restock (%s) is invalid for %s."].." "..errStr, errArg, ItemInfo.GetLink(itemString))
	elseif maxQuantityOrErrType == ShoppingOperation.ERROR.RESTOCK_INVALID_RANGE then
		ChatMessage.PrintfUser(L["Your restock quantity (%s) is invalid for %s."].." "..L["Must be between %d and %d."], errArg, ItemInfo.GetLink(itemString), ShoppingOperation.GetRestockRange())
	elseif maxQuantityOrErrType ~= nil then
		error("Invalid error type: "..tostring(maxQuantityOrErrType))
	end
	return false, nil
end
'@
    $patched = @'
function private.GetRestockQuantity(itemString)
	local isValid, maxQuantityOrErrType, errArg, errArg2, errArg3 = ShoppingOperation.ValidateAndGetRestockQuantity(itemString)
	if isValid then
		return true, maxQuantityOrErrType
	end
	if maxQuantityOrErrType == ShoppingOperation.ERROR.MAX_PRICE_INVALID then
		local _, errStr = CustomPrice.GetValue(errArg, itemString, true)
		ChatMessage.PrintfUser(L["Your max price (%s) is invalid for %s."].." "..errStr, errArg, ItemInfo.GetLink(itemString))
	elseif maxQuantityOrErrType == ShoppingOperation.ERROR.RESTOCK_INVALID then
		local _, errStr = CustomPrice.GetValue(errArg, itemString, true)
		ChatMessage.PrintfUser(L["Your max restock (%s) is invalid for %s."].." "..errStr, errArg, ItemInfo.GetLink(itemString))
	elseif maxQuantityOrErrType == ShoppingOperation.ERROR.RESTOCK_INVALID_RANGE then
		ChatMessage.PrintfUser(L["Your max restock (%s) is invalid for %s."].." "..L["Must be between %d and %d."], errArg, ItemInfo.GetLink(itemString), ShoppingOperation.GetRestockRange())
	elseif maxQuantityOrErrType == ShoppingOperation.ERROR.MIN_RESTOCK_INVALID then
		local _, errStr = CustomPrice.GetValue(errArg, itemString, true)
		ChatMessage.PrintfUser(L["Your min restock (%s) is invalid for %s."].." "..errStr, errArg, ItemInfo.GetLink(itemString))
	elseif maxQuantityOrErrType == ShoppingOperation.ERROR.MIN_RESTOCK_INVALID_RANGE then
		ChatMessage.PrintfUser(L["Your min restock (%s) is invalid for %s."].." "..L["Must be between %d and %d."], errArg, ItemInfo.GetLink(itemString), ShoppingOperation.GetRestockRange())
	elseif maxQuantityOrErrType == ShoppingOperation.ERROR.RESTOCK_QUANTITIES_CONFLICT then
		ChatMessage.PrintfUser(L["'%s' is an invalid operation. Min restock of %d is higher than max restock of %d for %s."], errArg, errArg2, errArg3, ItemInfo.GetLink(itemString))
	elseif maxQuantityOrErrType ~= nil then
		error("Invalid error type: "..tostring(maxQuantityOrErrType))
	end
	return false, nil
end
'@
    $changed = Replace-ExactBlock -Content ([ref]$content) -Original $original -Patched $patched -Label "Core\\Service\\Shopping\\GroupSearch.lua restock validation"
    if ($changed) {
        Set-Content -LiteralPath $FilePath -Value $content -NoNewline
    }
    return $changed
}

function Update-TSMApiFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )

    $content = Get-Content -LiteralPath $FilePath -Raw
    $changed = $false

    $original = @'
local TSM = select(2, ...) ---@type TSM
local API = TSM:NewPackage("API") ---@type AddonPackage
local Money = TSM.LibTSMUtil:Include("UI.Money")
'@
    $patched = @'
local TSM = select(2, ...) ---@type TSM
local API = TSM:NewPackage("API") ---@type AddonPackage
local L = TSM.Locale.GetTable()
local Money = TSM.LibTSMUtil:Include("UI.Money")
'@
    $changed = (Replace-ExactBlock -Content ([ref]$content) -Original $original -Patched $patched -Label "Core\\API.lua locals") -or $changed

    $original = @'
function TSM_API.ShiftDefaultUIButton(uiName, addonTag, xOffset)
	private.CheckCallMethod(uiName)
	private.ValidateArgumentType(addonTag, "string", "addonTag")
	if addonTag == "" then
		error("Invalid `addonTag` argument (cannot be an empty string)", 2)
	end
	private.ValidateArgumentType(xOffset, "number", "xOffset")
	if uiName == "VENDORING" then
		TSM.UI.VendoringUI.ShiftDefaultUIButton(addonTag, xOffset)
	else
		error("Invalid uiName: "..tostring(uiName), 2)
	end
end



-- ============================================================================
-- Groups
'@
    $patched = @'
function TSM_API.ShiftDefaultUIButton(uiName, addonTag, xOffset)
	private.CheckCallMethod(uiName)
	private.ValidateArgumentType(addonTag, "string", "addonTag")
	if addonTag == "" then
		error("Invalid `addonTag` argument (cannot be an empty string)", 2)
	end
	private.ValidateArgumentType(xOffset, "number", "xOffset")
	if uiName == "VENDORING" then
		TSM.UI.VendoringUI.ShiftDefaultUIButton(addonTag, xOffset)
	else
		error("Invalid uiName: "..tostring(uiName), 2)
	end
end

--- Runs the "Mail Selected Groups" action from the TSM Mailing Groups tab.
-- @within UI
-- @tparam[opt=false] boolean sendRepeat Whether to auto-resend according to the mailing settings
-- @tparam[opt=false] boolean isDryRun Whether to perform a dry-run without actually sending mail
-- @treturn boolean Whether the action was started
function TSM_API.MailSelectedGroups(sendRepeat, isDryRun)
	private.CheckCallMethod(sendRepeat)
	if sendRepeat == nil then
		sendRepeat = false
	else
		private.ValidateArgumentType(sendRepeat, "boolean", "sendRepeat")
	end
	if isDryRun == nil then
		isDryRun = false
	else
		private.ValidateArgumentType(isDryRun, "boolean", "isDryRun")
	end
	return TSM.UI.MailingUI.Groups.SendSelectedGroups(sendRepeat, isDryRun)
end

--- Shows the TSM Mailing UI on the Groups tab.
-- @within UI
-- @treturn boolean Whether the Groups tab was shown
function TSM_API.ShowMailGroups()
	return TSM.UI.MailingUI.ShowTab(L["Groups"], true)
end



-- ============================================================================
-- Groups
'@
    if (-not $content.Contains("function TSM_API.MailSelectedGroups(")) {
        $changed = (Replace-ExactBlock -Content ([ref]$content) -Original $original -Patched $patched -Label "Core\\API.lua UI hooks") -or $changed
    }

    $original = @'
function TSM_API.ShowMailGroups()
	return TSM.UI.MailingUI.ShowTab(L["Groups"], true)
end
'@
    $patched = @'
function TSM_API.ShowMailGroups()
	return TSM.UI.MailingUI.ShowTab(L["Groups"], true)
end

--- Runs the "Send Excess Gold to Banker" action from the TSM Mailing Other tab.
-- @within UI
-- @treturn boolean Whether the action was started
function TSM_API.MailExcessGold()
	return TSM.UI.MailingUI.Other.SendExcessGold()
end

--- Shows the TSM Mailing UI on the Other tab.
-- @within UI
-- @treturn boolean Whether the Other tab was shown
function TSM_API.ShowMailOther()
	return TSM.UI.MailingUI.ShowTab(OTHER, true)
end
'@
    $changed = (Replace-ExactBlock -Content ([ref]$content) -Original $original -Patched $patched -Label "Core\\API.lua Other hooks") -or $changed

    if ($changed) {
        Set-Content -LiteralPath $FilePath -Value $content -NoNewline
    }
    return $changed
}

function Update-TSMMailingCoreFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )

    $content = Get-Content -LiteralPath $FilePath -Raw
    $original = @'
function MailingUI.SetSelectedTab(buttonText, redraw)
	private.frame:SetSelectedNavButton(buttonText, redraw)
end
'@
    $patched = @'
function MailingUI.SetSelectedTab(buttonText, redraw)
	private.frame:SetSelectedNavButton(buttonText, redraw)
end

function MailingUI.ShowTab(buttonText, redraw)
	if private.isVisible and private.frame then
		private.frame:SetSelectedNavButton(buttonText, redraw)
		return true
	end
	if MailFrame and MailFrame:IsVisible() then
		private.settings.showDefault = false
		private.fsm:ProcessEvent("EV_SWITCH_BTN_CLICKED")
		if private.frame then
			private.frame:SetSelectedNavButton(buttonText, redraw)
			return true
		end
	end
	return false
end
'@

    $changed = Replace-ExactBlock -Content ([ref]$content) -Original $original -Patched $patched -Label "Core\\UI\\MailingUI\\Core.lua"
    if ($changed) {
        Set-Content -LiteralPath $FilePath -Value $content -NoNewline
    }
    return $changed
}

function Update-TSMMailingGroupsFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )

    $content = Get-Content -LiteralPath $FilePath -Raw
    $changed = $false

    $original = @'
local private = {
	settings = nil,
	filterText = "",
	fsm = nil
}
'@
    $patched = @'
local private = {
	settings = nil,
	filterText = "",
	fsm = nil,
	visibleFrame = nil,
	isReady = false,
	pendingSendRepeat = nil,
	pendingIsDryRun = nil,
}
'@
    $changed = (Replace-ExactBlock -Content ([ref]$content) -Original $original -Patched $patched -Label "Groups.lua private state") -or $changed

    $original = @'
function Groups.OnInitialize(settingsDB)
	private.settings = settingsDB:NewView()
		:AddKey("char", "mailingUIContext", "groupTree")
		:AddKey("global", "mailingOptions", "resendDelay")
	private.FSMCreate()
	TSM.UI.MailingUI.RegisterTopLevelPage(L["Groups"], private.GetGroupsFrame)
end



-- ============================================================================
-- Groups UI
'@
    $patched = @'
function Groups.OnInitialize(settingsDB)
	private.settings = settingsDB:NewView()
		:AddKey("char", "mailingUIContext", "groupTree")
		:AddKey("global", "mailingOptions", "resendDelay")
	private.FSMCreate()
	TSM.UI.MailingUI.RegisterTopLevelPage(L["Groups"], private.GetGroupsFrame)
end

function Groups.SendSelectedGroups(sendRepeat, isDryRun)
	sendRepeat = sendRepeat or false
	isDryRun = isDryRun or false
	if not private.visibleFrame then
		if not TSM.UI.MailingUI.ShowTab(L["Groups"], true) then
			return false
		end
	end
	if not private.isReady then
		private.pendingSendRepeat = sendRepeat
		private.pendingIsDryRun = isDryRun
		return true
	end
	return private.StartSendingSelectedGroups(sendRepeat, isDryRun)
end



-- ============================================================================
-- Groups UI
'@
    $changed = (Replace-ExactBlock -Content ([ref]$content) -Original $original -Patched $patched -Label "Groups.lua module functions") -or $changed

    $original = 'return UIElements.New("Frame", "groups")'
    $patched = 'local frame = UIElements.New("Frame", "groups")'
    $changed = (Replace-ExactBlock -Content ([ref]$content) -Original $original -Patched $patched -Label "Groups.lua frame creation") -or $changed

    $original = @'
		:SetScript("OnUpdate", private.FrameOnUpdate)
		:SetScript("OnHide", private.FrameOnHide)
end
'@
    $patched = @'
		:SetScript("OnUpdate", private.FrameOnUpdate)
		:SetScript("OnHide", private.FrameOnHide)
	private.visibleFrame = frame
	return frame
end
'@
    $changed = (Replace-ExactBlock -Content ([ref]$content) -Original $original -Patched $patched -Label "Groups.lua frame return") -or $changed

    $original = @'
function private.FrameOnUpdate(frame)
	frame:SetScript("OnUpdate", nil)
	private.GroupTreeOnGroupSelectionChanged(frame:GetElement("groupTree"))
	private.fsm:ProcessEvent("EV_FRAME_SHOW", frame)
end

function private.FrameOnHide(frame)
	private.fsm:ProcessEvent("EV_FRAME_HIDE")
end
'@
    $patched = @'
function private.FrameOnUpdate(frame)
	frame:SetScript("OnUpdate", nil)
	private.visibleFrame = frame
	private.GroupTreeOnGroupSelectionChanged(frame:GetElement("groupTree"))
	private.fsm:ProcessEvent("EV_FRAME_SHOW", frame)
	private.isReady = true
	if private.pendingSendRepeat ~= nil and private.pendingIsDryRun ~= nil then
		local sendRepeat = private.pendingSendRepeat
		local isDryRun = private.pendingIsDryRun
		private.pendingSendRepeat = nil
		private.pendingIsDryRun = nil
		private.StartSendingSelectedGroups(sendRepeat, isDryRun)
	end
end

function private.FrameOnHide(frame)
	private.visibleFrame = nil
	private.isReady = false
	private.pendingSendRepeat = nil
	private.pendingIsDryRun = nil
	private.fsm:ProcessEvent("EV_FRAME_HIDE")
end
'@
    $changed = (Replace-ExactBlock -Content ([ref]$content) -Original $original -Patched $patched -Label "Groups.lua frame lifecycle") -or $changed

    $original = @'
function private.MailBtnOnClick(button)
	private.fsm:ProcessEvent("EV_BUTTON_CLICKED", IsShiftKeyDown(), IsControlKeyDown())
end



-- ============================================================================
-- FSM
'@
    $patched = @'
function private.MailBtnOnClick(button)
	private.fsm:ProcessEvent("EV_BUTTON_CLICKED", IsShiftKeyDown(), IsControlKeyDown())
end

function private.StartSendingSelectedGroups(sendRepeat, isDryRun)
	local groupTree = private.visibleFrame and private.visibleFrame:GetElement("groupTree")
	if not groupTree or groupTree:IsSelectionCleared() then
		return false
	end
	private.fsm:ProcessEvent("EV_BUTTON_CLICKED", sendRepeat, isDryRun)
	return true
end



-- ============================================================================
-- FSM
'@
    $changed = (Replace-ExactBlock -Content ([ref]$content) -Original $original -Patched $patched -Label "Groups.lua send helper") -or $changed

    $original = @'
		:AddState(FSM.NewState("ST_HIDDEN")
			:SetOnEnter(function(context)
				TSM.Mailing.Send.KillThread()
				TSM.Mailing.Groups.KillThread()
				context.frame = nil
			end)
'@
    $patched = @'
		:AddState(FSM.NewState("ST_HIDDEN")
			:SetOnEnter(function(context)
				TSM.Mailing.Send.KillThread()
				TSM.Mailing.Groups.KillThread()
				context.frame = nil
				private.visibleFrame = nil
				private.isReady = false
				private.pendingSendRepeat = nil
				private.pendingIsDryRun = nil
			end)
'@
    $changed = (Replace-ExactBlock -Content ([ref]$content) -Original $original -Patched $patched -Label "Groups.lua FSM reset") -or $changed

    if ($changed) {
        Set-Content -LiteralPath $FilePath -Value $content -NoNewline
    }
    return $changed
}

function Update-TSMMailingOtherFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )

    $content = Get-Content -LiteralPath $FilePath -Raw
    $changed = $false

    $original = @'
local private = {
	settings = nil,
	frame = nil,
	fsm = nil,
}
'@
    $patched = @'
local private = {
	settings = nil,
	frame = nil,
	fsm = nil,
	isReady = false,
	pendingSendGold = false,
}
'@
    $changed = (Replace-ExactBlock -Content ([ref]$content) -Original $original -Patched $patched -Label "Other.lua private state") -or $changed

    $original = @'
function Groups.OnInitialize(settingsDB)
	private.settings = settingsDB:NewView()
		:AddKey("factionrealm", "internalData", "mailDisenchantablesChar")
		:AddKey("factionrealm", "internalData", "mailExcessGoldChar")
		:AddKey("factionrealm", "internalData", "mailExcessGoldLimit")
		:AddKey("global", "mailingOptions", "deMaxQuality")
	private.FSMCreate()
	TSM.UI.MailingUI.RegisterTopLevelPage(OTHER, private.GetOtherFrame)
end



-- ============================================================================
-- Other UI
'@
    $patched = @'
function Groups.OnInitialize(settingsDB)
	private.settings = settingsDB:NewView()
		:AddKey("factionrealm", "internalData", "mailDisenchantablesChar")
		:AddKey("factionrealm", "internalData", "mailExcessGoldChar")
		:AddKey("factionrealm", "internalData", "mailExcessGoldLimit")
		:AddKey("global", "mailingOptions", "deMaxQuality")
	private.FSMCreate()
	TSM.UI.MailingUI.RegisterTopLevelPage(OTHER, private.GetOtherFrame)
end

function Groups.SendExcessGold()
	if not TSM.UI.MailingUI.ShowTab(OTHER, true) then
		return false
	end
	if not private.isReady then
		private.pendingSendGold = true
		return true
	end
	return private.StartSendingExcessGold()
end



-- ============================================================================
-- Other UI
'@
    $changed = (Replace-ExactBlock -Content ([ref]$content) -Original $original -Patched $patched -Label "Other.lua module functions") -or $changed

    $original = @'
function private.FrameOnUpdate(frame)
	frame:SetScript("OnUpdate", nil)

	private.UpdateEnchantButton()
	private.UpdateGoldButton()

	private.fsm:ProcessEvent("EV_FRAME_SHOW", frame)
end

function private.FrameOnHide(frame)
	private.fsm:ProcessEvent("EV_FRAME_HIDE")
end
'@
    $patched = @'
function private.FrameOnUpdate(frame)
	frame:SetScript("OnUpdate", nil)

	private.UpdateEnchantButton()
	private.UpdateGoldButton()

	private.fsm:ProcessEvent("EV_FRAME_SHOW", frame)
	private.isReady = true
	if private.pendingSendGold then
		private.pendingSendGold = false
		private.StartSendingExcessGold()
	end
end

function private.FrameOnHide(frame)
	private.isReady = false
	private.pendingSendGold = false
	private.fsm:ProcessEvent("EV_FRAME_HIDE")
end
'@
    $changed = (Replace-ExactBlock -Content ([ref]$content) -Original $original -Patched $patched -Label "Other.lua frame lifecycle") -or $changed

    $original = @'
function private.GoldSendBtnOnClick(button)
	local money = private.GetSendMoney()
	private.fsm:ProcessEvent("EV_BUTTON_CLICKED", private.settings.mailExcessGoldChar, money)
end
'@
    $patched = @'
function private.GoldSendBtnOnClick(button)
	private.StartSendingExcessGold()
end

function private.StartSendingExcessGold()
	local recipient = private.settings.mailExcessGoldChar
	local money = private.GetSendMoney()
	if recipient == "" or recipient == PLAYER_NAME or recipient == PLAYER_NAME_REALM or money <= 0 then
		return false
	end
	private.fsm:ProcessEvent("EV_BUTTON_CLICKED", recipient, money)
	return true
end
'@
    $changed = (Replace-ExactBlock -Content ([ref]$content) -Original $original -Patched $patched -Label "Other.lua send helper") -or $changed

    if ($changed) {
        Set-Content -LiteralPath $FilePath -Value $content -NoNewline
    }
    return $changed
}

function Update-TSMMailingSendFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )

    $content = Get-Content -LiteralPath $FilePath -Raw
    $original = 'if Threading.WaitForEvent("MAIL_SUCCESS", "MAIL_FAILED") == "MAIL_SUCCESS" then'
    $patched = 'if Threading.WaitForEvent("MAIL_SEND_SUCCESS", "MAIL_SUCCESS", "MAIL_FAILED") ~= "MAIL_FAILED" then'
    $changed = Replace-ExactBlock -Content ([ref]$content) -Original $original -Patched $patched -Label "Service\\Mailing\\Send.lua success event"
    if ($changed) {
        Set-Content -LiteralPath $FilePath -Value $content -NoNewline
    }
    return $changed
}

function Update-TSMCraftedPriceFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )

    $content = Get-Content -LiteralPath $FilePath -Raw
    $original = @'
	-- YayaCraftedPrice integration
	if YayaCraftedPriceAPI and type(YayaCraftedPriceAPI.InitializeTSM) == "function" then
		YayaCraftedPriceAPI.InitializeTSM(TSM, CustomString)
	end
	if YayaCraftedPriceAPI and type(YayaCraftedPriceAPI.GetSmartAvgCrafted) == "function"
		and not CustomString.IsSourceRegistered("smartavgcrafted") then
		CustomString.RegisterSource(
			"YayaCraftedPrice",
			"smartAvgCrafted",
			"Smart Avg Crafted",
			YayaCraftedPriceAPI.GetSmartAvgCrafted,
			CustomString.SOURCE_TYPE.NORMAL
		)
		Inventory.RegisterDependentCustomSource("smartAvgCrafted")
	end

	-- Force a garbage collection
'@
    $patched = @'
	-- YayaCraftedPrice integration
	local function RegisterYayaCraftedPrice(api)
		if type(api) ~= "table" then
			return
		end
		if type(api.InitializeTSM) == "function" then
			api.InitializeTSM(TSM, CustomString)
		end
		if type(api.GetSmartAvgCrafted) == "function"
			and not CustomString.IsSourceRegistered("smartavgcrafted") then
			CustomString.RegisterSource(
				"YayaCraftedPrice",
				"smartAvgCrafted",
				"Smart Avg Crafted",
				api.GetSmartAvgCrafted,
				CustomString.SOURCE_TYPE.NORMAL
			)
			Inventory.RegisterDependentCustomSource("smartAvgCrafted")
		end
	end
	YayaCraftedPriceTSMRegister = RegisterYayaCraftedPrice
	RegisterYayaCraftedPrice(YayaCraftedPriceAPI)

	-- Force a garbage collection
'@
    $changed = Replace-ExactBlock -Content ([ref]$content) -Original $original -Patched $patched -Label "TradeSkillMaster.lua crafted price integration"
    if ($changed) {
        Set-Content -LiteralPath $FilePath -Value $content -NoNewline
    }
    return $changed
}

function Update-TSMAuctionScrollTableFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )

    $content = Get-Content -LiteralPath $FilePath -Raw
    $original = @'
function AuctionScrollTable.__private:_SetSelectedRow(selection, silent)
	local dataIndex = selection and Table.KeyByValue(self._rawData, selection) or nil
	local prevDataIndex = self._selection and Table.KeyByValue(self._rawData, self._selection) or nil
	if private.RowsEqual(selection, self._selection) and (not selection or dataIndex) then
		if dataIndex then
			self:_ScrollToRow(dataIndex)
		end
		return self
	end
	local prevRow = prevDataIndex and self:_GetRow(prevDataIndex) or nil
	if prevRow then
		prevRow:SetSelected(false)
	end
	if dataIndex then
		local newRow = self:_GetRow(dataIndex)
		if newRow then
			newRow:SetSelected(true)
		end
		self._selection = selection
		local baseItemString = selection:GetBaseItemString()
		self._selectionBaseItemString = baseItemString
		local settings = self:_GetSettingsValue()
		self._selectionBaseSortValue = self:_GetSortValue(selection, settings.sortCol, settings.sortAscending)
		local firstIndex = nil
		self._selectionSubRowIndex = nil
		for i, data in ipairs(self._rawData) do
			if not firstIndex and data:GetBaseItemString() == baseItemString then
				firstIndex = i
			end
			if data == selection then
				self._selectionSubRowIndex = i - firstIndex + 1
				break
			end
		end
		assert(self._selectionSubRowIndex)
		self:_ScrollToRow(dataIndex)
	else
		self._selection = nil
		self._selectionBaseItemString = nil
		self._selectionBaseSortValue = nil
		self._selectionSubRowIndex = nil
	end
	if not silent then
		self:_SendActionScript("OnSelectionChanged")
	end
end
'@
    $patched = @'
function AuctionScrollTable.__private:_SetSelectedRow(selection, silent)
	local dataIndex = selection and Table.KeyByValue(self._rawData, selection) or nil
	local prevDataIndex = self._selection and Table.KeyByValue(self._rawData, self._selection) or nil
	-- Auction results can be invalidated between rendering a row and clicking it.
	-- Do not compare or select a sub row after its raw data was released.
	if selection and selection:IsSubRow() and not selection:HasRawData() then
		selection = nil
		dataIndex = nil
	end
	if self._selection and self._selection:IsSubRow() and not self._selection:HasRawData() then
		self._selection = nil
	end
	if private.RowsEqual(selection, self._selection) and (not selection or dataIndex) then
		if dataIndex then
			self:_ScrollToRow(dataIndex)
		end
		return self
	end
	local prevRow = prevDataIndex and self:_GetRow(prevDataIndex) or nil
	if prevRow then
		prevRow:SetSelected(false)
	end
	if dataIndex then
		local newRow = self:_GetRow(dataIndex)
		if newRow then
			newRow:SetSelected(true)
		end
		self._selection = selection
		local baseItemString = selection:GetBaseItemString()
		self._selectionBaseItemString = baseItemString
		local settings = self:_GetSettingsValue()
		self._selectionBaseSortValue = self:_GetSortValue(selection, settings.sortCol, settings.sortAscending)
		local firstIndex = nil
		self._selectionSubRowIndex = nil
		for i, data in ipairs(self._rawData) do
			if not firstIndex and data:GetBaseItemString() == baseItemString then
				firstIndex = i
			end
			if data == selection then
				self._selectionSubRowIndex = i - firstIndex + 1
				break
			end
		end
		assert(self._selectionSubRowIndex)
		self:_ScrollToRow(dataIndex)
	else
		self._selection = nil
		self._selectionBaseItemString = nil
		self._selectionBaseSortValue = nil
		self._selectionSubRowIndex = nil
	end
	if not silent then
		self:_SendActionScript("OnSelectionChanged")
	end
end
'@
    $changed = Replace-ExactBlock -Content ([ref]$content) -Original $original -Patched $patched -Label "AuctionScrollTable stale selection guard"
    if ($changed) {
        Set-Content -LiteralPath $FilePath -Value $content -NoNewline
    }
    return $changed
}

function Update-TSMBagTrackingFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )

    $content = Get-Content -LiteralPath $FilePath -Raw
    $original = @'
function BagTracking.ItemWillGoInBag(itemString, bag)
	if bag == Container.GetBackpackContainer() or bag == Container.GetBankContainer() or Container.IsWarbankBag(bag) then
		return true
	end
	local itemFamily = Item.GetFamily(ItemInfo.GetLink(itemString), ItemInfo.GetClassId(itemString))
	local _, bagFamily = Container.GetNumFreeSlots(bag)
	if not bagFamily then
		return false
	end
	return bagFamily == 0 or bit.band(itemFamily, bagFamily) > 0
end
'@
    $patched = @'
function BagTracking.ItemWillGoInBag(itemString, bag)
	if bag == Container.GetBackpackContainer() or bag == Container.GetBankContainer() or Container.IsWarbankBag(bag) then
		return true
	end
	local reagentBag = Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag
	if reagentBag and bag == reagentBag then
		return ItemInfo.IsCraftingReagent(itemString) == true
	end
	local itemFamily = Item.GetFamily(ItemInfo.GetLink(itemString), ItemInfo.GetClassId(itemString))
	local _, bagFamily = Container.GetNumFreeSlots(bag)
	if not bagFamily then
		return false
	end
	return bagFamily == 0 or bit.band(itemFamily, bagFamily) > 0
end
'@
    $changed = Replace-ExactBlock -Content ([ref]$content) -Original $original -Patched $patched -Label "Inventory\\BagTracking reagent bag guard"
    if ($changed) {
        Set-Content -LiteralPath $FilePath -Value $content -NoNewline
    }
    return $changed
}

function Invoke-TSMMailingPatch {
    param(
        [string]$AddonPath,
        [switch]$Quiet
    )

    $resolvedAddonPath = Resolve-TSMAddonPath -AddonPath $AddonPath
    $version = Get-TSMAddonVersion -AddonPath $resolvedAddonPath

    $apiPath = Join-Path $resolvedAddonPath "Core\API.lua"
    $craftedPricePath = Join-Path $resolvedAddonPath "TradeSkillMaster.lua"
    $mailingCorePath = Join-Path $resolvedAddonPath "Core\UI\MailingUI\Core.lua"
    $mailingGroupsPath = Join-Path $resolvedAddonPath "Core\UI\MailingUI\Groups.lua"
    $mailingOtherPath = Join-Path $resolvedAddonPath "Core\UI\MailingUI\Other.lua"
    $mailingSendPath = Join-Path $resolvedAddonPath "Core\Service\Mailing\Send.lua"
    $auctionScrollTablePath = Join-Path $resolvedAddonPath "LibTSMUI\Source\AuctionHouse\AuctionScrollTable.lua"
    $bagTrackingPath = Join-Path $resolvedAddonPath "LibTSMService\Source\Inventory\BagTracking.lua"
    $shoppingOperationPath = Join-Path $resolvedAddonPath "LibTSMSystem\Source\Operation\ShoppingOperation.lua"
    $shoppingUiPath = Join-Path $resolvedAddonPath "Core\UI\MainUI\Operations\Shopping.lua"
    $shoppingGroupSearchPath = Join-Path $resolvedAddonPath "Core\Service\Shopping\GroupSearch.lua"

    $changed = $false
    $changed = (Update-TSMApiFile -FilePath $apiPath) -or $changed
    $changed = (Update-TSMCraftedPriceFile -FilePath $craftedPricePath) -or $changed
    $changed = (Update-TSMMailingCoreFile -FilePath $mailingCorePath) -or $changed
    $changed = (Update-TSMMailingGroupsFile -FilePath $mailingGroupsPath) -or $changed
    $changed = (Update-TSMMailingOtherFile -FilePath $mailingOtherPath) -or $changed
    $changed = (Update-TSMMailingSendFile -FilePath $mailingSendPath) -or $changed
    $changed = (Update-TSMAuctionScrollTableFile -FilePath $auctionScrollTablePath) -or $changed
    $changed = (Update-TSMBagTrackingFile -FilePath $bagTrackingPath) -or $changed
    $changed = (Update-TSMShoppingOperationFile -FilePath $shoppingOperationPath) -or $changed
    $changed = (Update-TSMShoppingUIFile -FilePath $shoppingUiPath) -or $changed
    $changed = (Update-TSMShoppingGroupSearchFile -FilePath $shoppingGroupSearchPath) -or $changed

    $status = if ($changed) { "patched" } else { "already patched" }
    Write-TSMAutoPatchLog -Message ("{0} ({1}) at {2}" -f $status, $version, $resolvedAddonPath) -Quiet:$Quiet

    return [pscustomobject]@{
        AddonPath = $resolvedAddonPath
        Version = $version
        Changed = $changed
        Status = $status
    }
}
