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
    "C:\Users\Yaya\Games\World of Warcraft\_retail_\Interface\AddOns\TradeSkillMaster"
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

    if ($Content.Value.Contains($Patched)) {
        return $false
    }
    if (-not $Content.Value.Contains($Original)) {
        throw "Unexpected code in $Label."
    }

    $Content.Value = $Content.Value.Replace($Original, $Patched)
    return $true
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
    $changed = (Replace-ExactBlock -Content ([ref]$content) -Original $original -Patched $patched -Label "Core\\API.lua UI hooks") -or $changed

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

function Invoke-TSMMailingPatch {
    param(
        [string]$AddonPath,
        [switch]$Quiet
    )

    $resolvedAddonPath = Resolve-TSMAddonPath -AddonPath $AddonPath
    $version = Get-TSMAddonVersion -AddonPath $resolvedAddonPath

    $apiPath = Join-Path $resolvedAddonPath "Core\API.lua"
    $mailingCorePath = Join-Path $resolvedAddonPath "Core\UI\MailingUI\Core.lua"
    $mailingGroupsPath = Join-Path $resolvedAddonPath "Core\UI\MailingUI\Groups.lua"
    $mailingOtherPath = Join-Path $resolvedAddonPath "Core\UI\MailingUI\Other.lua"

    $changed = $false
    $changed = (Update-TSMApiFile -FilePath $apiPath) -or $changed
    $changed = (Update-TSMMailingCoreFile -FilePath $mailingCorePath) -or $changed
    $changed = (Update-TSMMailingGroupsFile -FilePath $mailingGroupsPath) -or $changed
    $changed = (Update-TSMMailingOtherFile -FilePath $mailingOtherPath) -or $changed

    $status = if ($changed) { "patched" } else { "already patched" }
    Write-TSMAutoPatchLog -Message ("{0} ({1}) at {2}" -f $status, $version, $resolvedAddonPath) -Quiet:$Quiet

    return [pscustomobject]@{
        AddonPath = $resolvedAddonPath
        Version = $version
        Changed = $changed
        Status = $status
    }
}
