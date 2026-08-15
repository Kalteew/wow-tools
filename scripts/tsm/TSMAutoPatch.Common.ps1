Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$script:TaskName = "TSM Auto Patch Watcher"
$script:WatcherMutexName = "Local\TSMAutoPatchWatcher"
$script:StartupLauncherName = "TSM Auto Patch Watcher.vbs"
$script:PatchTransaction = $null
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
    $normalizedOriginal = $normalizedOriginal.Replace('\t', [string][char]9)
    $normalizedPatched = $normalizedPatched.Replace('\t', [string][char]9)

    if ($Content.Value.Contains($normalizedPatched)) {
        return $false
    }
    if (-not $Content.Value.Contains($normalizedOriginal)) {
        throw "Unexpected code in $Label."
    }

    $Content.Value = $Content.Value.Replace($normalizedOriginal, $normalizedPatched)
    return $true
}

function Replace-ExactBlockAny {
    param(
        [Parameter(Mandatory = $true)]
        [ref]$Content,
        [Parameter(Mandatory = $true)]
        [string[]]$Originals,
        [Parameter(Mandatory = $true)]
        [string]$Patched,
        [Parameter(Mandatory = $true)]
        [string]$Label
    )

    $newline = if ($Content.Value.Contains("`r`n")) { "`r`n" } else { "`n" }
    $normalizedPatched = [regex]::Replace($Patched, "\r?\n", $newline).Replace('\t', [string][char]9)
    if ($Content.Value.Contains($normalizedPatched)) {
        return $false
    }
    foreach ($original in $Originals) {
        $normalizedOriginal = [regex]::Replace($original, "\r?\n", $newline).Replace('\t', [string][char]9)
        if ($Content.Value.Contains($normalizedOriginal)) {
            $Content.Value = $Content.Value.Replace($normalizedOriginal, $normalizedPatched)
            return $true
        }
    }
    throw "Unexpected code in $Label."
}

function ConvertFrom-TSMPatchBytes {
    param(
        [Parameter(Mandatory = $true)]
        [byte[]]$Bytes
    )

    $hasUtf8Bom = $Bytes.Length -ge 3 -and $Bytes[0] -eq 0xEF -and $Bytes[1] -eq 0xBB -and $Bytes[2] -eq 0xBF
    $encoding = [System.Text.UTF8Encoding]::new($false, $true)
    try {
        $content = if ($hasUtf8Bom) {
            $encoding.GetString($Bytes, 3, $Bytes.Length - 3)
        } else {
            $encoding.GetString($Bytes)
        }
    } catch {
        throw "TSM patch only supports valid UTF-8 source files. $($_.Exception.Message)"
    }
    return [pscustomobject]@{
        Content = $content
        HasUtf8Bom = $hasUtf8Bom
    }
}

function ConvertTo-TSMPatchBytes {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Content,
        [Parameter(Mandatory = $true)]
        [bool]$HasUtf8Bom
    )

    $encoding = [System.Text.UTF8Encoding]::new($false, $true)
    $payload = $encoding.GetBytes($Content)
    if (-not $HasUtf8Bom) {
        return $payload
    }
    $result = New-Object byte[] ($payload.Length + 3)
    $result[0] = 0xEF
    $result[1] = 0xBB
    $result[2] = 0xBF
    [System.Array]::Copy($payload, 0, $result, 3, $payload.Length)
    return $result
}

function Write-TSMPatchBytesAtomically {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,
        [Parameter(Mandatory = $true)]
        [byte[]]$Bytes
    )

    $token = [guid]::NewGuid().ToString('N')
    $tempPath = "$FilePath.yaya-patch-$token.tmp"
    $replaceBackupPath = "$FilePath.yaya-patch-$token.bak"
    try {
        [System.IO.File]::WriteAllBytes($tempPath, $Bytes)
        [System.IO.File]::Replace($tempPath, $FilePath, $replaceBackupPath, $true)
    } finally {
        if (Test-Path -LiteralPath $tempPath) {
            Remove-Item -LiteralPath $tempPath -Force -ErrorAction SilentlyContinue
        }
        if (Test-Path -LiteralPath $replaceBackupPath) {
            Remove-Item -LiteralPath $replaceBackupPath -Force -ErrorAction SilentlyContinue
        }
    }
}

function Start-TSMPatchTransaction {
    param(
        [Parameter(Mandatory = $true)]
        [string]$AddonPath,
        [Parameter(Mandatory = $true)]
        [string[]]$FilePaths
    )

    if ($script:PatchTransaction) {
        throw "A TSM patch transaction is already active."
    }
    $resolvedRoot = [System.IO.Path]::GetFullPath($AddonPath).TrimEnd('\')
    $rootPrefix = $resolvedRoot + '\'
    $files = @{}
    foreach ($filePath in $FilePaths) {
        $resolvedPath = [System.IO.Path]::GetFullPath($filePath)
        if (-not $resolvedPath.StartsWith($rootPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
            throw "TSM patch target is outside the addon folder: $resolvedPath"
        }
        if (-not [System.IO.File]::Exists($resolvedPath)) {
            throw "TSM patch target does not exist: $resolvedPath"
        }
        $bytes = [System.IO.File]::ReadAllBytes($resolvedPath)
        $decoded = ConvertFrom-TSMPatchBytes -Bytes $bytes
        $files[$resolvedPath] = [pscustomobject]@{
            Path = $resolvedPath
            RelativePath = $resolvedPath.Substring($rootPrefix.Length)
            OriginalBytes = $bytes
            OriginalContent = $decoded.Content
            Content = $decoded.Content
            HasUtf8Bom = $decoded.HasUtf8Bom
            LastWriteTimeUtc = [System.IO.File]::GetLastWriteTimeUtc($resolvedPath)
            Changed = $false
        }
    }
    $script:PatchTransaction = [pscustomobject]@{
        AddonPath = $resolvedRoot
        Files = $files
    }
}

function Stop-TSMPatchTransaction {
    $script:PatchTransaction = $null
}

function Get-TSMPatchContent {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )

    $resolvedPath = [System.IO.Path]::GetFullPath($FilePath)
    if ($script:PatchTransaction) {
        if (-not $script:PatchTransaction.Files.ContainsKey($resolvedPath)) {
            throw "TSM patch target was not registered in the active transaction: $resolvedPath"
        }
        return $script:PatchTransaction.Files[$resolvedPath].Content
    }
    return (ConvertFrom-TSMPatchBytes -Bytes ([System.IO.File]::ReadAllBytes($resolvedPath))).Content
}

function Set-TSMPatchContent {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,
        [Parameter(Mandatory = $true)]
        [string]$Content
    )

    $resolvedPath = [System.IO.Path]::GetFullPath($FilePath)
    if ($script:PatchTransaction) {
        if (-not $script:PatchTransaction.Files.ContainsKey($resolvedPath)) {
            throw "TSM patch target was not registered in the active transaction: $resolvedPath"
        }
        $entry = $script:PatchTransaction.Files[$resolvedPath]
        $entry.Content = $Content
        $entry.Changed = $Content -cne $entry.OriginalContent
        return
    }
    $originalBytes = [System.IO.File]::ReadAllBytes($resolvedPath)
    $decoded = ConvertFrom-TSMPatchBytes -Bytes $originalBytes
    $bytes = ConvertTo-TSMPatchBytes -Content $Content -HasUtf8Bom $decoded.HasUtf8Bom
    Write-TSMPatchBytesAtomically -FilePath $resolvedPath -Bytes $bytes
}

function Complete-TSMPatchTransaction {
    param(
        [switch]$DryRun
    )

    if (-not $script:PatchTransaction) {
        throw "No TSM patch transaction is active."
    }
    $transaction = $script:PatchTransaction
    $changedEntries = @($transaction.Files.Values | Where-Object { $_.Changed } | Sort-Object Path)
    if ($DryRun -or $changedEntries.Count -eq 0) {
        Stop-TSMPatchTransaction
        return [pscustomobject]@{
            ChangedCount = $changedEntries.Count
            BackupPath = $null
            DryRun = [bool]$DryRun
        }
    }

    $backupBase = Join-Path $env:LOCALAPPDATA "YayaTools\TSMAutoPatch\backups"
    $backupName = "{0}-{1}" -f (Get-Date -Format "yyyyMMdd-HHmmss"), ([guid]::NewGuid().ToString("N"))
    $backupPath = Join-Path $backupBase $backupName
    $attemptedEntries = New-Object System.Collections.Generic.List[object]
    $rollbackErrors = New-Object System.Collections.Generic.List[string]
    try {
        New-Item -ItemType Directory -Path $backupPath -Force | Out-Null
        $manifest = @()
        foreach ($entry in $changedEntries) {
            $diskBackupPath = Join-Path $backupPath $entry.RelativePath
            $diskBackupParent = Split-Path -Parent $diskBackupPath
            New-Item -ItemType Directory -Path $diskBackupParent -Force | Out-Null
            [System.IO.File]::WriteAllBytes($diskBackupPath, $entry.OriginalBytes)
            $manifest += [pscustomobject]@{
                Path = $entry.Path
                RelativePath = $entry.RelativePath
                LastWriteTimeUtc = $entry.LastWriteTimeUtc.ToString("o")
            }
        }
        $manifestPath = Join-Path $backupPath "manifest.json"
        $manifestJson = $manifest | ConvertTo-Json -Depth 3
        [System.IO.File]::WriteAllText($manifestPath, $manifestJson, [System.Text.UTF8Encoding]::new($false))

        foreach ($entry in $changedEntries) {
            $attemptedEntries.Add($entry)
            $bytes = ConvertTo-TSMPatchBytes -Content $entry.Content -HasUtf8Bom $entry.HasUtf8Bom
            Write-TSMPatchBytesAtomically -FilePath $entry.Path -Bytes $bytes
        }
    } catch {
        $patchError = $_.Exception.Message
        for ($index = $attemptedEntries.Count - 1; $index -ge 0; $index--) {
            $entry = $attemptedEntries[$index]
            try {
                Write-TSMPatchBytesAtomically -FilePath $entry.Path -Bytes $entry.OriginalBytes
                [System.IO.File]::SetLastWriteTimeUtc($entry.Path, $entry.LastWriteTimeUtc)
            } catch {
                $rollbackErrors.Add("$($entry.Path): $($_.Exception.Message)")
            }
        }
        if ($rollbackErrors.Count -gt 0) {
            throw "TSM patch failed: $patchError Rollback also failed: $($rollbackErrors -join '; '). Backup: $backupPath"
        }
        throw "TSM patch failed: $patchError All attempted files were rolled back. Backup: $backupPath"
    } finally {
        Stop-TSMPatchTransaction
    }

    return [pscustomobject]@{
        ChangedCount = $changedEntries.Count
        BackupPath = $backupPath
        DryRun = $false
    }
}

function Update-TSMShoppingOperationFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )

    $content = Get-TSMPatchContent -FilePath $FilePath
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
        Set-TSMPatchContent -FilePath $FilePath -Content $content
    }
    return $changed
}

function Update-TSMShoppingUIFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )

    $content = Get-TSMPatchContent -FilePath $FilePath
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
        Set-TSMPatchContent -FilePath $FilePath -Content $content
    }
    return $changed
}

function Update-TSMShoppingGroupSearchFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )

    $content = Get-TSMPatchContent -FilePath $FilePath
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
        Set-TSMPatchContent -FilePath $FilePath -Content $content
    }
    return $changed
}

function Update-TSMApiFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )

    $content = Get-TSMPatchContent -FilePath $FilePath
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
        Set-TSMPatchContent -FilePath $FilePath -Content $content
    }
    return $changed
}

function Update-TSMMailingCoreFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )

    $content = Get-TSMPatchContent -FilePath $FilePath
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
        Set-TSMPatchContent -FilePath $FilePath -Content $content
    }
    return $changed
}

function Update-TSMMailingGroupsFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )

    $content = Get-TSMPatchContent -FilePath $FilePath
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
        Set-TSMPatchContent -FilePath $FilePath -Content $content
    }
    return $changed
}

function Update-TSMMailingOtherFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )

    $content = Get-TSMPatchContent -FilePath $FilePath
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
        Set-TSMPatchContent -FilePath $FilePath -Content $content
    }
    return $changed
}

function Update-TSMMailingSendFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )

    $content = Get-TSMPatchContent -FilePath $FilePath
    $original = 'if Threading.WaitForEvent("MAIL_SUCCESS", "MAIL_FAILED") == "MAIL_SUCCESS" then'
    $patched = 'if Threading.WaitForEvent("MAIL_SEND_SUCCESS", "MAIL_SUCCESS", "MAIL_FAILED") ~= "MAIL_FAILED" then'
    $changed = Replace-ExactBlock -Content ([ref]$content) -Original $original -Patched $patched -Label "Service\\Mailing\\Send.lua success event"
    if ($changed) {
        Set-TSMPatchContent -FilePath $FilePath -Content $content
    }
    return $changed
}

function Update-TSMCraftedPriceFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )

    $content = Get-TSMPatchContent -FilePath $FilePath
    $originals = @()
    $originals += @'
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
    $originals += @'
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
    $changed = Replace-ExactBlockAny -Content ([ref]$content) -Originals $originals -Patched $patched -Label "TradeSkillMaster.lua crafted price integration"
    if ($changed) {
        Set-TSMPatchContent -FilePath $FilePath -Content $content
    }
    return $changed
}

function Update-TSMAuctionScrollTableFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )

    $content = Get-TSMPatchContent -FilePath $FilePath
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
        Set-TSMPatchContent -FilePath $FilePath -Content $content
    }
    return $changed
}

function Restore-TSMBagTrackingFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )

    $content = Get-TSMPatchContent -FilePath $FilePath
    $changed = $false

    $original = @'
\tprevQuantities = {},
}
'@
    $patched = @'
\tprevQuantities = {},
\tpendingItemData = {},
\tpendingItemDataSlots = {},
}
'@
    $changed = (Replace-ExactBlock -Content ([ref]$content) -Original $original -Patched $patched -Label "Inventory\\BagTracking pending item data state") -or $changed

    $original = @'
\tif LibTSMService.IsRetail() then
\t\tEvent.Register("BAG_UPDATE", private.HandleLogin)
'@
    $patched = @'
\tif LibTSMService.IsRetail() then
\t\tEvent.Register("ITEM_DATA_LOAD_RESULT", private.ItemDataLoadResultHandler)
\t\tEvent.Register("BAG_UPDATE", private.HandleLogin)
'@
    $changed = (Replace-ExactBlock -Content ([ref]$content) -Original $original -Patched $patched -Label "Inventory\\BagTracking item data event") -or $changed
    $originals = @()
    $originals += @'
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
    $changed = (Replace-ExactBlockAny -Content ([ref]$content) -Originals $originals -Patched $patched -Label "Inventory\\BagTracking restore reagent bag filtering") -or $changed

    $original = @'
function private.ScanBagSlot(bag, slot)
'@
    $patched = @'
function private.ClearPendingItemDataSlot(slotId)
\tlocal itemId = private.pendingItemDataSlots[slotId]
\tif not itemId then
\t\treturn
\tend
\tprivate.pendingItemDataSlots[slotId] = nil
\tlocal pending = private.pendingItemData[itemId]
\tif not pending then
\t\treturn
\tend
\tpending.slots[slotId] = nil
\tif not next(pending.slots) then
\t\tpending.token = pending.token + 1
\t\tprivate.pendingItemData[itemId] = nil
\tend
end

function private.RevalidatePendingItemData(itemId)
\tlocal pending = private.pendingItemData[itemId]
\tif not pending then
\t\treturn
\tend
\tpending.token = pending.token + 1
\tlocal slots = TempTable.Acquire()
\tfor slotId in pairs(pending.slots) do
\t\ttinsert(slots, slotId)
\tend
\tfor _, slotId in ipairs(slots) do
\t\tlocal bag, slot = SlotId.Split(slotId)
\t\tlocal currentItemId = Container.GetItemId(bag, slot)
\t\tlocal currentItemString = ItemString.Get(Container.GetItemLink(bag, slot))
\t\tif currentItemId ~= itemId or currentItemString then
\t\t\tprivate.ClearPendingItemDataSlot(slotId)
\t\t\tprivate.ScanBagSlot(bag, slot)
\t\tend
\tend
\tTempTable.Release(slots)
\tpending = private.pendingItemData[itemId]
\tif pending and pending.attempts < 3 then
\t\tprivate.RequestPendingItemData(itemId)
\tend
end

function private.RequestPendingItemData(itemId)
\tlocal pending = private.pendingItemData[itemId]
\tif not pending or pending.attempts >= 3 then
\t\treturn
\tend
\tlocal now = GetTime()
\tlocal delay = max(0, (pending.nextRequestTime or 0) - now)
\tif delay > 0 then
\t\tif pending.requestScheduled then
\t\t\treturn
\t\tend
\t\tpending.requestScheduled = true
\t\tlocal token = pending.token
\t\tC_Timer.After(delay, function()
\t\t\tlocal current = private.pendingItemData[itemId]
\t\t\tif current and current.token == token then
\t\t\t\tcurrent.requestScheduled = false
\t\t\t\tprivate.RequestPendingItemData(itemId)
\t\t\tend
\t\tend)
\t\treturn
\tend
\tpending.requestScheduled = false
\tpending.attempts = pending.attempts + 1
\tpending.nextRequestTime = now + 1
\tif C_Item and C_Item.RequestLoadItemDataByID then
\t\tC_Item.RequestLoadItemDataByID(itemId)
\telse
\t\tItemInfo.FetchInfo("i:"..itemId)
\tend
\tpending.token = pending.token + 1
\tlocal token = pending.token
\tC_Timer.After(1, function()
\t\tlocal current = private.pendingItemData[itemId]
\t\tif current and current.token == token then
\t\t\tprivate.RevalidatePendingItemData(itemId)
\t\tend
\tend)
end

function private.QueuePendingItemDataSlot(bag, slot, itemId)
\tlocal slotId = SlotId.Join(bag, slot)
\tlocal previousItemId = private.pendingItemDataSlots[slotId]
\tif previousItemId and previousItemId ~= itemId then
\t\tprivate.ClearPendingItemDataSlot(slotId)
\tend
\tlocal pending = private.pendingItemData[itemId]
\tif not pending then
\t\tpending = { slots = {}, attempts = 0, nextRequestTime = 0, requestScheduled = false, token = 0 }
\t\tprivate.pendingItemData[itemId] = pending
\tend
\tpending.slots[slotId] = true
\tprivate.pendingItemDataSlots[slotId] = itemId
\tprivate.RequestPendingItemData(itemId)
end

function private.ItemDataLoadResultHandler(_, itemId)
\tif private.pendingItemData[itemId] then
\t\tprivate.RevalidatePendingItemData(itemId)
\tend
end

function private.ScanBagSlot(bag, slot)
'@
    $changed = (Replace-ExactBlock -Content ([ref]$content) -Original $original -Patched $patched -Label "Inventory\\BagTracking targeted item data revalidation") -or $changed

    $scanBagSlotOriginals = @()
    $scanBagSlotOriginals += @'
function private.ScanBagSlot(bag, slot)
	local texture, quantity, _, link, itemId, isBound = Container.GetItemInfo(bag, slot)
	if quantity and not itemId then
		-- We are pending item info for this slot so try again later to scan it
		return false
	elseif quantity == 0 then
		-- This item is going away, so try again later to scan it
		return false
	end
'@
    $scanBagSlotOriginals += @'
function private.ScanBagSlot(bag, slot)
	local texture, quantity, _, link, itemId, isBound = Container.GetItemInfo(bag, slot)
	if not link and (Container.GetItemId(bag, slot) or Container.GetItemLink(bag, slot)) then
		-- The slot still contains an item, but its link is not ready yet.
		-- Keep the existing row and retry instead of deleting it.
		return false
	elseif quantity and not itemId then
		-- We are pending item info for this slot so try again later to scan it
		return false
	elseif quantity == 0 then
		-- This item is going away, so try again later to scan it
		return false
	end
'@
    $scanBagSlotPatched = @'
function private.ScanBagSlot(bag, slot)
	local texture, quantity, _, link, itemId, isBound = Container.GetItemInfo(bag, slot)
	local itemString = ItemString.Get(link)
	if (itemId or Container.GetItemId(bag, slot)) and not itemString then
		-- The slot still contains an item, but its link is missing or incomplete.
		-- Keep the existing row and retry instead of deleting it.
		return false
	elseif quantity and not itemId then
		-- We are pending item info for this slot so try again later to scan it
		return false
	elseif quantity == 0 then
		-- This item is going away, so try again later to scan it
		return false
	end
'@
    $scanBagSlotOriginals += $scanBagSlotPatched
    $scanBagSlotPatched = @'
function private.ScanBagSlot(bag, slot)
\tlocal texture, quantity, _, link, itemId, isBound = Container.GetItemInfo(bag, slot)
\tlocal itemString = ItemString.Get(link)
\tlocal pendingItemId = itemId or Container.GetItemId(bag, slot)
\tlocal slotId = SlotId.Join(bag, slot)
\tif pendingItemId and not itemString then
\t\t-- Keep the existing row and revalidate only this slot after item data loads.
\t\tprivate.QueuePendingItemDataSlot(bag, slot, pendingItemId)
\t\treturn true
\telseif quantity and not itemId then
\t\t-- We are pending item info for this slot so try again later to scan it
\t\treturn false
\telseif quantity == 0 then
\t\t-- This item is going away, so try again later to scan it
\t\treturn false
\tend
\tprivate.ClearPendingItemDataSlot(slotId)
'@
    $scanBagSlotOriginals += $scanBagSlotPatched
    $scanBagSlotPatched = @'
function private.ScanBagSlot(bag, slot)
\tlocal texture, quantity, _, link, itemId, isBound = Container.GetItemInfo(bag, slot)
\tlocal itemString = ItemString.Get(link)
\tlocal pendingItemId = itemId or Container.GetItemId(bag, slot)
\tlocal slotId = SlotId.Join(bag, slot)
\tlocal itemExists = C_Item and C_Item.DoesItemExist and ItemLocation and ItemLocation.CreateFromBagAndSlot and C_Item.DoesItemExist(ItemLocation:CreateFromBagAndSlot(bag, slot))
\tif (pendingItemId or itemExists) and not itemString then
\t\t-- Keep the last-known row and revalidate only this slot after item data loads.
\t\tif type(YayaReagentSniperTrace) == "function" then
\t\t\tYayaReagentSniperTrace(pendingItemId and "TSM_BAG_ID_ONLY" or "TSM_BAG_INFO_NIL", "slot=%s:%s id=%s quantity=%s quality=nil link=%s bound=%s exists=%s", tostring(bag), tostring(slot), tostring(pendingItemId), tostring(quantity), tostring(link), tostring(isBound), tostring(itemExists))
\t\tend
\t\tif pendingItemId then
\t\t\tprivate.QueuePendingItemDataSlot(bag, slot, pendingItemId)
\t\tend
\t\treturn true
\telseif quantity and not itemId then
\t\t-- We are pending item info for this slot so try again later to scan it.
\t\tif type(YayaReagentSniperTrace) == "function" then
\t\t\tYayaReagentSniperTrace("TSM_BAG_NO_ID", "slot=%s:%s quantity=%s link=%s bound=%s", tostring(bag), tostring(slot), tostring(quantity), tostring(link), tostring(isBound))
\t\tend
\t\treturn false
\telseif quantity == 0 then
\t\t-- This item is going away, so try again later to scan it
\t\treturn false
\tend
\tprivate.ClearPendingItemDataSlot(slotId)
'@
    $changed = (Replace-ExactBlockAny -Content ([ref]$content) -Originals $scanBagSlotOriginals -Patched $scanBagSlotPatched -Label "Inventory\\BagTracking pending item link guard") -or $changed

    $cleanupOriginals = @()
    $cleanupOriginals += @'
	private.ClearPendingItemDataSlot(slotId)
	local itemString = ItemString.Get(link)
	local levelItemString = itemString and ItemString.ToLevel(itemString)
	local slotId = SlotId.Join(bag, slot)
'@
    $cleanupOriginals += @'
	private.ClearPendingItemDataSlot(slotId)
	local levelItemString = itemString and ItemString.ToLevel(itemString)
	local slotId = SlotId.Join(bag, slot)
'@
    $patched = @'
	private.ClearPendingItemDataSlot(slotId)
	local levelItemString = itemString and ItemString.ToLevel(itemString)
'@
    $changed = (Replace-ExactBlockAny -Content ([ref]$content) -Originals $cleanupOriginals -Patched $patched -Label "Inventory\\BagTracking reuse parsed item string") -or $changed
    if ($changed) {
        Set-TSMPatchContent -FilePath $FilePath -Content $content
    }
    return $changed
}

function Update-TSMPostScanDebugFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )

    $content = Get-TSMPatchContent -FilePath $FilePath
    $changed = $false

    $original = @'
local AuctionHouseWrapper = TSM.LibTSMWoW:Include("API.AuctionHouseWrapper")
'@
    $patched = @'
local AuctionHouse = TSM.LibTSMWoW:Include("API.AuctionHouse")
local AuctionHouseWrapper = TSM.LibTSMWoW:Include("API.AuctionHouseWrapper")
'@
    $changed = (Replace-ExactBlock -Content ([ref]$content) -Original $original -Patched $patched -Label "Auctioning\\PostScan auction house API") -or $changed

    $original = @'
for _, slotId in Container.GetBagSlotIterator() do
'@
    $patched = @'
for slotId in Container.GetBagSlotIterator() do
'@
    $changed = (Replace-ExactBlock -Content ([ref]$content) -Original $original -Patched $patched -Label "Auctioning\\PostScan bag iterator slotId") -or $changed

    $postMissOriginals = @()
    $postMissOriginals += @'
\tif not bag or not slot then
\t\t-- this item was likely removed from the player's bags, so just give up
\t\tLog.Err("Failed to find initial bag / slot (%s, %d)", itemString, quantity)
\t\treturn nil, true
\tend
'@
    $postMissOriginals += @'
\tif not bag or not slot then
\t\t-- this item was likely removed from the player's bags, so just give up
\t\tlocal targetBaseItemString = ItemString.GetBaseFast(itemString)
\t\tlocal candidateCount = 0
\t\tfor slotId in Container.GetBagSlotIterator() do
\t\t\tlocal candidateBag, candidateSlot = SlotId.Split(slotId)
\t\t\tlocal candidateLink = Container.GetItemLink(candidateBag, candidateSlot)
\t\t\tlocal candidateItemString = ItemString.Get(candidateLink)
\t\t\tif candidateItemString and ItemString.GetBaseFast(candidateItemString) == targetBaseItemString then
\t\t\t\tlocal _, candidateQuantity, candidateQuality, _, candidateItemId = Container.GetItemInfo(candidateBag, candidateSlot)
\t\t\t\tcandidateCount = candidateCount + 1
\t\t\t\tLog.Warn("[YayaTSM] post-miss target=%s qty=%s candidate=%d,%d item=%s id=%s stack=%s quality=%s", itemString, tostring(quantity), candidateBag, candidateSlot, candidateItemString, tostring(candidateItemId), tostring(candidateQuantity), tostring(candidateQuality))
\t\t\tend
\t\tend
\t\tLog.Warn("[YayaTSM] post-miss target=%s qty=%s base=%s candidates=%d", itemString, tostring(quantity), targetBaseItemString, candidateCount)
\t\tChatMessage.PrintfUser("[YayaTSM] post-miss %s x%s - candidats même base: %d", ItemInfo.GetLink(itemString), tostring(quantity), candidateCount)
\t\tLog.Err("Failed to find initial bag / slot (%s, %d)", itemString, quantity)
\t\treturn nil, true
\tend
'@
    $postMissPatched = @'
\tif not bag or not slot then
\t\t-- The inventory cache may be behind the live bags while item data is loading.
\t\tlocal targetItemId = ItemString.ToId(itemString)
\t\tlocal candidateCount = 0
\t\tlocal candidateTotal = 0
\t\tlocal pendingCandidateCount = 0
\t\tfor slotId in Container.GetBagSlotIterator() do
\t\t\tlocal candidateBag, candidateSlot = SlotId.Split(slotId)
\t\t\tlocal _, candidateQuantity, candidateQuality, candidateLink, candidateItemId = Container.GetItemInfo(candidateBag, candidateSlot)
\t\t\tcandidateItemId = candidateItemId or Container.GetItemId(candidateBag, candidateSlot)
\t\t\tlocal candidateItemString = ItemString.Get(candidateLink)
\t\t\tlocal sameTarget = candidateItemString and Group.TranslateItemString(candidateItemString) == itemString
\t\t\tlocal pendingTarget = not candidateItemString and candidateItemId == targetItemId
\t\t\tif sameTarget or pendingTarget then
\t\t\t\tcandidateQuantity = candidateQuantity or 0
\t\t\t\tcandidateCount = candidateCount + 1
\t\t\t\tcandidateTotal = candidateTotal + candidateQuantity
\t\t\t\tif pendingTarget then
\t\t\t\t\tpendingCandidateCount = pendingCandidateCount + 1
\t\t\t\tend
\t\t\t\tLog.Warn("[YayaTSM] post-miss target=%s qty=%s candidate=%d,%d item=%s id=%s stack=%s quality=%s pending=%s", itemString, tostring(quantity), candidateBag, candidateSlot, tostring(candidateItemString), tostring(candidateItemId), tostring(candidateQuantity), tostring(candidateQuality), tostring(pendingTarget))
\t\t\tend
\t\tend
\t\tif pendingCandidateCount > 0 or candidateTotal >= quantity then
\t\t\tLog.Warn("[YayaTSM] post-miss target=%s qty=%s candidates=%d total=%d pending=%d - retrying bag data", itemString, tostring(quantity), candidateCount, candidateTotal, pendingCandidateCount)
\t\t\tprivate.DebugLogInsert(itemString, "Pending bag item info")
\t\t\treturn nil, nil
\t\telse
\t\t\tLog.Err("Failed to find initial bag / slot (%s, %d)", itemString, quantity)
\t\t\treturn nil, true
\t\tend
\tend
'@
    $postMissOriginals += $postMissPatched
    $postMissPatched = @'
\tif not bag or not slot then
\t\t-- The inventory cache may be behind the live bags while item data is loading.
\t\tlocal targetItemId = ItemString.ToId(itemString)
\t\tlocal candidateCount = 0
\t\tlocal candidateTotal = 0
\t\tlocal pendingCandidateCount = 0
\t\tfor slotId in Container.GetBagSlotIterator() do
\t\t\tlocal candidateBag, candidateSlot = SlotId.Split(slotId)
\t\t\tlocal _, candidateQuantity, candidateQuality, candidateLink, candidateItemId, candidateIsBound = Container.GetItemInfo(candidateBag, candidateSlot)
\t\t\tcandidateItemId = candidateItemId or Container.GetItemId(candidateBag, candidateSlot)
\t\t\tlocal candidateItemString = ItemString.Get(candidateLink)
\t\t\tlocal sameTarget = candidateItemString and Group.TranslateItemString(candidateItemString) == itemString
\t\t\tlocal pendingTarget = not candidateItemString and candidateItemId == targetItemId
\t\t\tlocal candidateIsSellable = candidateIsBound == false and AuctionHouse.IsSellable(candidateBag, candidateSlot)
\t\t\tif (sameTarget or pendingTarget) and candidateIsSellable then
\t\t\t\tcandidateQuantity = candidateQuantity or 0
\t\t\t\tcandidateCount = candidateCount + 1
\t\t\t\tcandidateTotal = candidateTotal + candidateQuantity
\t\t\t\tif pendingTarget then
\t\t\t\t\tpendingCandidateCount = pendingCandidateCount + 1
\t\t\t\tend
\t\t\t\tLog.Warn("[YayaTSM] post-miss target=%s qty=%s candidate=%d,%d item=%s id=%s stack=%s quality=%s bound=%s sellable=%s pending=%s", itemString, tostring(quantity), candidateBag, candidateSlot, tostring(candidateItemString), tostring(candidateItemId), tostring(candidateQuantity), tostring(candidateQuality), tostring(candidateIsBound), tostring(candidateIsSellable), tostring(pendingTarget))
\t\t\tend
\t\tend
\t\tif pendingCandidateCount > 0 or candidateTotal >= quantity then
\t\t\tLog.Warn("[YayaTSM] post-miss target=%s qty=%s candidates=%d total=%d pending=%d - retrying bag data", itemString, tostring(quantity), candidateCount, candidateTotal, pendingCandidateCount)
\t\t\tprivate.DebugLogInsert(itemString, "Pending bag item info")
\t\t\treturn nil, nil
\t\telse
\t\t\tLog.Err("Failed to find initial bag / slot (%s, %d)", itemString, quantity)
\t\t\treturn nil, true
\t\tend
\tend
'@
    $postMissOriginals += $postMissPatched
    $postMissPatched = @'
\tif not bag or not slot then
\t\t-- The inventory cache may be behind the live bags while item data is loading.
\t\tlocal targetItemId = ItemString.ToId(itemString)
\t\tlocal targetPetCageId = strmatch(itemString, "^p:") and ItemString.ToId(ItemString.GetPetCage()) or nil
\t\tlocal candidateCount = 0
\t\tlocal candidateTotal = 0
\t\tlocal pendingCandidateCount = 0
\t\tfor slotId in Container.GetBagSlotIterator() do
\t\t\tlocal candidateBag, candidateSlot = SlotId.Split(slotId)
\t\t\tlocal _, candidateQuantity, candidateQuality, candidateLink, candidateItemId, candidateIsBound = Container.GetItemInfo(candidateBag, candidateSlot)
\t\t\tcandidateItemId = candidateItemId or Container.GetItemId(candidateBag, candidateSlot)
\t\t\tlocal candidateItemString = ItemString.Get(candidateLink)
\t\t\tlocal sameTarget = candidateItemString and Group.TranslateItemString(candidateItemString) == itemString
\t\t\tlocal pendingTarget = not candidateItemString and candidateItemId and (candidateItemId == targetItemId or candidateItemId == targetPetCageId)
\t\t\tlocal candidateIsSellable = candidateIsBound == false and AuctionHouse.IsSellable(candidateBag, candidateSlot)
\t\t\tif sameTarget or pendingTarget then
\t\t\t\tcandidateQuantity = candidateQuantity or 0
\t\t\t\tcandidateCount = candidateCount + 1
\t\t\t\tif candidateIsSellable then
\t\t\t\t\tcandidateTotal = candidateTotal + candidateQuantity
\t\t\t\tend
\t\t\t\tlocal incomplete = pendingTarget or candidateIsBound == nil
\t\t\t\tif incomplete then
\t\t\t\t\tpendingCandidateCount = pendingCandidateCount + 1
\t\t\t\tend
\t\t\t\tLog.Warn("[YayaTSM] post-miss target=%s qty=%s candidate=%d,%d item=%s id=%s stack=%s quality=%s bound=%s sellable=%s pending=%s", itemString, tostring(quantity), candidateBag, candidateSlot, tostring(candidateItemString), tostring(candidateItemId), tostring(candidateQuantity), tostring(candidateQuality), tostring(candidateIsBound), tostring(candidateIsSellable), tostring(incomplete))
\t\t\t\tif type(YayaReagentSniperTrace) == "function" then
\t\t\t\t\tYayaReagentSniperTrace("TSM_POST_CANDIDATE", "target=%s qty=%s slot=%d:%d item=%s id=%s stack=%s quality=%s bound=%s sellable=%s pending=%s", itemString, tostring(quantity), candidateBag, candidateSlot, tostring(candidateItemString), tostring(candidateItemId), tostring(candidateQuantity), tostring(candidateQuality), tostring(candidateIsBound), tostring(candidateIsSellable), tostring(incomplete))
\t\t\t\tend
\t\t\tend
\t\tend
\t\tif type(YayaReagentSniperTrace) == "function" then
\t\t\tYayaReagentSniperTrace("TSM_POST_MISS", "target=%s qty=%s candidates=%d total=%d pending=%d", itemString, tostring(quantity), candidateCount, candidateTotal, pendingCandidateCount)
\t\tend
\t\tif pendingCandidateCount > 0 or candidateTotal >= quantity then
\t\t\tLog.Warn("[YayaTSM] post-miss target=%s qty=%s candidates=%d total=%d pending=%d - retrying bag data", itemString, tostring(quantity), candidateCount, candidateTotal, pendingCandidateCount)
\t\t\tprivate.DebugLogInsert(itemString, "Pending bag item info")
\t\t\treturn nil, nil
\t\telse
\t\t\tLog.Err("Failed to find initial bag / slot (%s, %d)", itemString, quantity)
\t\t\treturn nil, true
\t\tend
\tend
'@
    $changed = (Replace-ExactBlockAny -Content ([ref]$content) -Originals $postMissOriginals -Patched $postMissPatched -Label "Auctioning\\PostScan missing item recovery") -or $changed

    $original = @'
\tif not bagItemString or Group.TranslateItemString(bagItemString) ~= itemString then
\t\t-- something changed with the player's bags so we can't post the item right now
\t\tTempTable.Release(removeContext)
\t\tprivate.DebugLogInsert(itemString, "Bags changed")
\t\treturn nil, nil
\tend
'@
    $patched = @'
\tif not bagItemString or Group.TranslateItemString(bagItemString) ~= itemString then
\t\t-- something changed with the player's bags so we can't post the item right now
\t\tLog.Warn("[YayaTSM] post-bags-changed target=%s bag=%s slot=%s actual=%s translated=%s", itemString, tostring(bag), tostring(slot), tostring(bagItemString), tostring(bagItemString and Group.TranslateItemString(bagItemString)))
\t\tTempTable.Release(removeContext)
\t\tprivate.DebugLogInsert(itemString, "Bags changed")
\t\treturn nil, nil
\tend
'@
    $bagMismatchOriginals = @($original, $patched)
    $patched = @'
\tif not bagItemString or Group.TranslateItemString(bagItemString) ~= itemString then
\t\t-- something changed with the player's bags so we can't post the item right now
\t\tLog.Warn("[YayaTSM] post-bags-changed target=%s bag=%s slot=%s actual=%s translated=%s", itemString, tostring(bag), tostring(slot), tostring(bagItemString), tostring(bagItemString and Group.TranslateItemString(bagItemString)))
\t\tif type(YayaReagentSniperTrace) == "function" then
\t\t\tYayaReagentSniperTrace("TSM_POST_STRING_MISMATCH", "target=%s slot=%s:%s actual=%s translated=%s rawLink=%s", itemString, tostring(bag), tostring(slot), tostring(bagItemString), tostring(bagItemString and Group.TranslateItemString(bagItemString)), tostring(Container.GetItemLink(bag, slot)))
\t\tend
\t\tTempTable.Release(removeContext)
\t\tprivate.DebugLogInsert(itemString, "Bags changed")
\t\treturn nil, nil
\tend
'@
    $changed = (Replace-ExactBlockAny -Content ([ref]$content) -Originals $bagMismatchOriginals -Patched $patched -Label "Auctioning\\PostScan bag mismatch diagnostics") -or $changed

    $postInfoOriginals = @()
    $postInfoOriginals += @'
\tlocal _, _, quality = Container.GetItemInfo(bag, slot)
\tif not quality or quality == -1 then
\t\t-- the game client doesn't have item info cached for this item, so we can't post it yet
\t\tTempTable.Release(removeContext)
\t\tprivate.DebugLogInsert(itemString, "No item info")
\t\treturn nil, nil
\tend
'@
    $postInfoOriginals += @'
\tlocal _, stackCount, quality, currentLink, currentItemId = Container.GetItemInfo(bag, slot)
\tif not quality or quality == -1 then
\t\t-- the game client doesn't have item info cached for this item, so we can't post it yet
\t\tLog.Warn("[YayaTSM] post-no-info target=%s bag=%s slot=%s link=%s id=%s stack=%s quality=%s", itemString, tostring(bag), tostring(slot), tostring(currentLink), tostring(currentItemId), tostring(stackCount), tostring(quality))
\t\tTempTable.Release(removeContext)
\t\tprivate.DebugLogInsert(itemString, "No item info")
\t\treturn nil, nil
\tend
'@
    $postInfoPatched = @'
\tlocal _, stackCount, quality, currentLink, currentItemId = Container.GetItemInfo(bag, slot)
\tif not quality or quality == -1 then
\t\tquality = ItemInfo.GetQuality(itemString)
\tend
\tif not quality or quality == -1 then
\t\t-- The container API can lag behind TSM's item cache. Ask TSM to refresh,
\t\t-- then retry without discarding the bag reservation.
\t\tItemInfo.FetchInfo(itemString)
\t\tLog.Warn("[YayaTSM] post-no-info target=%s bag=%s slot=%s link=%s id=%s stack=%s quality=%s", itemString, tostring(bag), tostring(slot), tostring(currentLink), tostring(currentItemId), tostring(stackCount), tostring(quality))
\t\tTempTable.Release(removeContext)
\t\tprivate.DebugLogInsert(itemString, "No item info")
\t\treturn nil, nil
\tend
'@
    $postInfoOriginals += $postInfoPatched
    $postInfoPatched = @'
\tlocal _, stackCount, quality, currentLink, currentItemId, currentIsBound = Container.GetItemInfo(bag, slot)
\tlocal currentIsSellable = currentIsBound == false and AuctionHouse.IsSellable(bag, slot)
\tif not currentIsSellable then
\t\tLog.Warn("[YayaTSM] post-unsellable target=%s bag=%s slot=%s link=%s id=%s bound=%s sellable=%s", itemString, tostring(bag), tostring(slot), tostring(currentLink), tostring(currentItemId), tostring(currentIsBound), tostring(currentIsSellable))
\t\tTempTable.Release(removeContext)
\t\tprivate.DebugLogInsert(itemString, "Bound or unsellable")
\t\treturn nil, true
\tend
\tif not quality or quality == -1 then
\t\tquality = ItemInfo.GetQuality(itemString)
\tend
\tif not quality or quality == -1 then
\t\t-- The container API can lag behind TSM's item cache. Ask TSM to refresh,
\t\t-- then retry without discarding the bag reservation.
\t\tItemInfo.FetchInfo(itemString)
\t\tLog.Warn("[YayaTSM] post-no-info target=%s bag=%s slot=%s link=%s id=%s stack=%s quality=%s", itemString, tostring(bag), tostring(slot), tostring(currentLink), tostring(currentItemId), tostring(stackCount), tostring(quality))
\t\tTempTable.Release(removeContext)
\t\tprivate.DebugLogInsert(itemString, "No item info")
\t\treturn nil, nil
\tend
'@
    $postInfoOriginals += $postInfoPatched
    $postInfoPatched = @'
\tlocal _, stackCount, quality, currentLink, currentItemId, currentIsBound = Container.GetItemInfo(bag, slot)
\tlocal currentIsSellable = currentIsBound == false and AuctionHouse.IsSellable(bag, slot)
\tif currentIsBound == nil or not currentLink or not currentItemId then
\t\tLog.Warn("[YayaTSM] post-incomplete target=%s bag=%s slot=%s link=%s id=%s bound=%s sellable=%s", itemString, tostring(bag), tostring(slot), tostring(currentLink), tostring(currentItemId), tostring(currentIsBound), tostring(currentIsSellable))
\t\tif type(YayaReagentSniperTrace) == "function" then
\t\t\tYayaReagentSniperTrace("TSM_POST_INCOMPLETE", "target=%s slot=%s:%s link=%s id=%s stack=%s quality=%s bound=%s sellable=%s", itemString, tostring(bag), tostring(slot), tostring(currentLink), tostring(currentItemId), tostring(stackCount), tostring(quality), tostring(currentIsBound), tostring(currentIsSellable))
\t\tend
\t\tTempTable.Release(removeContext)
\t\tprivate.DebugLogInsert(itemString, "Incomplete bag item info")
\t\treturn nil, nil
\tend
\tif not currentIsSellable then
\t\tLog.Warn("[YayaTSM] post-unsellable target=%s bag=%s slot=%s link=%s id=%s bound=%s sellable=%s", itemString, tostring(bag), tostring(slot), tostring(currentLink), tostring(currentItemId), tostring(currentIsBound), tostring(currentIsSellable))
\t\tif type(YayaReagentSniperTrace) == "function" then
\t\t\tYayaReagentSniperTrace("TSM_POST_UNSELLABLE", "target=%s slot=%s:%s id=%s bound=%s sellable=%s", itemString, tostring(bag), tostring(slot), tostring(currentItemId), tostring(currentIsBound), tostring(currentIsSellable))
\t\tend
\t\tTempTable.Release(removeContext)
\t\tprivate.DebugLogInsert(itemString, "Bound or unsellable")
\t\treturn nil, currentIsBound == true and true or nil
\tend
\tif not quality or quality == -1 then
\t\tquality = ItemInfo.GetQuality(itemString)
\tend
\tif not quality or quality == -1 then
\t\t-- The container API can lag behind TSM's item cache. Ask TSM to refresh,
\t\t-- then retry without discarding the bag reservation.
\t\tItemInfo.FetchInfo(itemString)
\t\tLog.Warn("[YayaTSM] post-no-info target=%s bag=%s slot=%s link=%s id=%s stack=%s quality=%s", itemString, tostring(bag), tostring(slot), tostring(currentLink), tostring(currentItemId), tostring(stackCount), tostring(quality))
\t\tif type(YayaReagentSniperTrace) == "function" then
\t\t\tYayaReagentSniperTrace("TSM_POST_NO_QUALITY", "target=%s slot=%s:%s id=%s stack=%s", itemString, tostring(bag), tostring(slot), tostring(currentItemId), tostring(stackCount))
\t\tend
\t\tTempTable.Release(removeContext)
\t\tprivate.DebugLogInsert(itemString, "No item info")
\t\treturn nil, nil
\tend
'@
    $changed = (Replace-ExactBlockAny -Content ([ref]$content) -Originals $postInfoOriginals -Patched $postInfoPatched -Label "Auctioning\\PostScan item info recovery") -or $changed

    if ($changed) {
        Set-TSMPatchContent -FilePath $FilePath -Content $content
    }
    return $changed
}

function Update-TSMBankingFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )

    $content = Get-TSMPatchContent -FilePath $FilePath
    $changed = $false

    $original = @'
\t\t-- Do all the pending moves
\t\tfor slotId, targetSlotId in pairs(slotIds) do
\t\t\tcontext:MoveSlot(slotId, targetSlotId, slotMoveQuantity[slotId])
\t\t\tThreading.Yield()
\t\t\tif private.openFrame == "GUILD_BANK" then
\t\t\t\tmovedSlotId = slotId
\t\t\t\tbreak
\t\t\tend
\t\tend
'@
    $patched = @'
\t\t-- Move Warbank items one at a time to avoid burst transfers.
\t\tfor slotId, targetSlotId in pairs(slotIds) do
\t\t\tcontext:MoveSlot(slotId, targetSlotId, slotMoveQuantity[slotId])
\t\t\tThreading.Yield()
\t\t\tif private.openFrame == "GUILD_BANK" or private.openFrame == "WARBANK" then
\t\t\t\tmovedSlotId = slotId
\t\t\t\tbreak
\t\t\tend
\t\tend
'@
    $changed = (Replace-ExactBlock -Content ([ref]$content) -Original $original -Patched $patched -Label "Banking\\Core.lua Warbank sequential move") -or $changed

    $original = @'
\t\t\t\tif private.openFrame ~= "GUILD_BANK" or slotId == movedSlotId then
'@
    $patched = @'
\t\t\t\tif (private.openFrame ~= "GUILD_BANK" and private.openFrame ~= "WARBANK") or slotId == movedSlotId then
'@
    $changed = (Replace-ExactBlock -Content ([ref]$content) -Original $original -Patched $patched -Label "Banking\\Core.lua Warbank move confirmation") -or $changed

    $original = @'
\t\t\tif didMove then
\t\t\t\tcallback("PROGRESS", numDone / numMoves)
\t\t\tend
'@
    $patched = @'
\t\t\tif didMove then
\t\t\t\tcallback("PROGRESS", numDone / numMoves)
\t\t\t\tif private.openFrame == "WARBANK" then
\t\t\t\t\tThreading.Sleep(0.1)
\t\t\t\tend
\t\t\tend
'@
    $changed = (Replace-ExactBlock -Content ([ref]$content) -Original $original -Patched $patched -Label "Banking\\Core.lua Warbank move pacing") -or $changed

    if ($changed) {
        Set-TSMPatchContent -FilePath $FilePath -Content $content
    }
    return $changed
}

function Update-TSMDefaultUICompatibilityFiles {
    param(
        [Parameter(Mandatory = $true)]
        [string]$CraftingFilePath,
        [Parameter(Mandatory = $true)]
        [string]$AuctionFilePath
    )

    $craftingContent = Get-TSMPatchContent -FilePath $CraftingFilePath
    $craftingOriginal = @'
				if private.craftOpen then
					UIParent_OnEvent(UIParent, "CRAFT_SHOW")
					UpdateDefaultCraftButton()
				else
					UIParent_OnEvent(UIParent, "TRADE_SKILL_SHOW")
				end
				local defaultFrame = ClientInfo.IsRetail() and ProfessionsFrame or TradeSkillFrame
'@
    $craftingPatched = @'
				local defaultFrame = ClientInfo.IsRetail() and ProfessionsFrame or TradeSkillFrame
				if private.craftOpen then
					if type(UIParent_OnEvent) == "function" then
						UIParent_OnEvent(UIParent, "CRAFT_SHOW")
					elseif CraftFrame then
						CraftFrame:Show()
					end
					UpdateDefaultCraftButton()
				else
					if type(UIParent_OnEvent) == "function" then
						UIParent_OnEvent(UIParent, "TRADE_SKILL_SHOW")
					elseif defaultFrame then
						defaultFrame:Show()
					end
				end
'@
    $changed = $false
    if (-not $craftingContent.Contains("GameEvent.HandleCraftShow")) {
        $changed = Replace-ExactBlock -Content ([ref]$craftingContent) -Original $craftingOriginal -Patched $craftingPatched -Label "Core\\UI\\CraftingUI\\Core.lua removed UIParent_OnEvent"
    }
    if ($changed) {
        Set-TSMPatchContent -FilePath $CraftingFilePath -Content $craftingContent
    }

    $auctionContent = Get-TSMPatchContent -FilePath $AuctionFilePath
    $auctionChanged = $false
    if ($auctionContent.Contains("GameEvent.HandleAuctionHouseShow")) {
        return $changed
    }
    $auctionOriginal = @'
	if private.settings.showDefault then
		if ClientInfo.IsVanillaClassic() or ClientInfo.IsBCClassic() then
			UIParent_OnEvent(UIParent, "AUCTION_HOUSE_SHOW")
		end
	else
'@
    $auctionPatched = @'
	if private.settings.showDefault then
		if ClientInfo.IsVanillaClassic() or ClientInfo.IsBCClassic() then
			if type(UIParent_OnEvent) == "function" then
				UIParent_OnEvent(UIParent, "AUCTION_HOUSE_SHOW")
			elseif private.defaultFrame then
				private.defaultFrame:Show()
			end
		end
	else
'@
    $auctionChanged = (Replace-ExactBlock -Content ([ref]$auctionContent) -Original $auctionOriginal -Patched $auctionPatched -Label "Core\\UI\\AuctionUI\\Core.lua removed UIParent_OnEvent") -or $auctionChanged

    $auctionOriginal = @'
	UIParent_OnEvent(UIParent, "AUCTION_HOUSE_SHOW")
	private.isSwitching = false
'@
    $auctionPatched = @'
	if type(UIParent_OnEvent) == "function" then
		UIParent_OnEvent(UIParent, "AUCTION_HOUSE_SHOW")
	elseif private.defaultFrame then
		private.defaultFrame:Show()
	end
	private.isSwitching = false
'@
    $auctionChanged = (Replace-ExactBlock -Content ([ref]$auctionContent) -Original $auctionOriginal -Patched $auctionPatched -Label "Core\\UI\\AuctionUI\\Core.lua switch fallback") -or $auctionChanged
    if ($auctionChanged) {
        Set-TSMPatchContent -FilePath $AuctionFilePath -Content $auctionContent
    }

    return $changed -or $auctionChanged
}

function Invoke-TSMMailingPatch {
    param(
        [string]$AddonPath,
        [switch]$Quiet,
        [switch]$DryRun
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
    $bankingCorePath = Join-Path $resolvedAddonPath "Core\Service\Banking\Core.lua"
    $postScanPath = Join-Path $resolvedAddonPath "Core\Service\Auctioning\PostScan.lua"
    $craftingUiPath = Join-Path $resolvedAddonPath "Core\UI\CraftingUI\Core.lua"
    $auctionUiPath = Join-Path $resolvedAddonPath "Core\UI\AuctionUI\Core.lua"
    $shoppingOperationPath = Join-Path $resolvedAddonPath "LibTSMSystem\Source\Operation\ShoppingOperation.lua"
    $shoppingUiPath = Join-Path $resolvedAddonPath "Core\UI\MainUI\Operations\Shopping.lua"
    $shoppingGroupSearchPath = Join-Path $resolvedAddonPath "Core\Service\Shopping\GroupSearch.lua"

    $targetPaths = @(
        $apiPath,
        $craftedPricePath,
        $mailingCorePath,
        $mailingGroupsPath,
        $mailingOtherPath,
        $mailingSendPath,
        $auctionScrollTablePath,
        $bagTrackingPath,
        $bankingCorePath,
        $postScanPath,
        $craftingUiPath,
        $auctionUiPath,
        $shoppingOperationPath,
        $shoppingUiPath,
        $shoppingGroupSearchPath
    )
    Start-TSMPatchTransaction -AddonPath $resolvedAddonPath -FilePaths $targetPaths
    try {
        $changed = $false
        $changed = (Update-TSMApiFile -FilePath $apiPath) -or $changed
        $changed = (Update-TSMCraftedPriceFile -FilePath $craftedPricePath) -or $changed
        $changed = (Update-TSMMailingCoreFile -FilePath $mailingCorePath) -or $changed
        $changed = (Update-TSMMailingGroupsFile -FilePath $mailingGroupsPath) -or $changed
        $changed = (Update-TSMMailingOtherFile -FilePath $mailingOtherPath) -or $changed
        $changed = (Update-TSMMailingSendFile -FilePath $mailingSendPath) -or $changed
        $changed = (Update-TSMAuctionScrollTableFile -FilePath $auctionScrollTablePath) -or $changed
        $changed = (Restore-TSMBagTrackingFile -FilePath $bagTrackingPath) -or $changed
        $changed = (Update-TSMBankingFile -FilePath $bankingCorePath) -or $changed
        $changed = (Update-TSMPostScanDebugFile -FilePath $postScanPath) -or $changed
        $changed = (Update-TSMDefaultUICompatibilityFiles -CraftingFilePath $craftingUiPath -AuctionFilePath $auctionUiPath) -or $changed
        $changed = (Update-TSMShoppingOperationFile -FilePath $shoppingOperationPath) -or $changed
        $changed = (Update-TSMShoppingUIFile -FilePath $shoppingUiPath) -or $changed
        $changed = (Update-TSMShoppingGroupSearchFile -FilePath $shoppingGroupSearchPath) -or $changed
        $transactionResult = Complete-TSMPatchTransaction -DryRun:$DryRun
    } catch {
        Stop-TSMPatchTransaction
        throw
    }

    $changed = $transactionResult.ChangedCount -gt 0
    $status = if ($DryRun -and $changed) { "would patch" } elseif ($changed) { "patched" } else { "already patched" }
    if (-not $DryRun) {
        $backupSuffix = if ($transactionResult.BackupPath) { " backup=$($transactionResult.BackupPath)" } else { "" }
        Write-TSMAutoPatchLog -Message ("{0} ({1}) at {2}{3}" -f $status, $version, $resolvedAddonPath, $backupSuffix) -Quiet:$Quiet
    }

    return [pscustomobject]@{
        AddonPath = $resolvedAddonPath
        Version = $version
        Changed = $changed
        Status = $status
        DryRun = [bool]$DryRun
        BackupPath = $transactionResult.BackupPath
    }
}
