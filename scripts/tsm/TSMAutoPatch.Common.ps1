Set-StrictMode -Version Latest

# Primitives communes aux auto-patchs (validation Lua, ecriture atomique,
# rotation du journal, notifications, suivi des echecs).
. (Join-Path $PSScriptRoot "..\lib\AddonPatchCore.ps1")
$ErrorActionPreference = "Stop"

$script:TaskName = "TSM Auto Patch Watcher"
$script:WatcherMutexName = "Local\TSMAutoPatchWatcher"
$script:StartupLauncherName = "TSM Auto Patch Watcher.vbs"
$script:PatchTransaction = $null
$script:LuacCommand = $null
$script:LastLuaSyntaxError = $null
$script:OutputPathOverride = $null
$script:LogMaxBytes = 1MB
$script:LogRetainedFiles = 3
$script:DefaultAddonCandidates = @(
    "C:\Program Files (x86)\World of Warcraft\_retail_\Interface\AddOns\TradeSkillMaster",
    "C:\Program Files\World of Warcraft\_retail_\Interface\AddOns\TradeSkillMaster",
    "D:\World of Warcraft\_retail_\Interface\AddOns\TradeSkillMaster",
    "E:\World of Warcraft\_retail_\Interface\AddOns\TradeSkillMaster",
    (Join-Path $env:USERPROFILE "Games\World of Warcraft\_retail_\Interface\AddOns\TradeSkillMaster")
)

function Get-TSMAutoPatchLogPath {
    # Les tests redirigent le journal et le fichier d'etat vers un dossier
    # temporaire pour ne pas polluer le diagnostic reel.
    if ($script:OutputPathOverride) {
        return Join-Path $script:OutputPathOverride "tsm-auto-patch.log"
    }
    return Join-Path $PSScriptRoot "tsm-auto-patch.log"
}

function Set-TSMAutoPatchOutputPath {
    param(
        [AllowEmptyString()]
        [AllowNull()]
        [string]$Path
    )

    $script:OutputPathOverride = $Path
}

function Get-TSMAutoPatchStartupPath {
    return Join-Path ([Environment]::GetFolderPath("Startup")) $script:StartupLauncherName
}

function Invoke-TSMAutoPatchLogRotation {
    param(
        [Parameter(Mandatory = $true)]
        [string]$LogPath
    )

    Invoke-AddonPatchLogRotation -LogPath $LogPath
}

function Write-TSMAutoPatchLog {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        [switch]$Quiet
    )

    $logPath = Get-TSMAutoPatchLogPath
    try {
        Invoke-TSMAutoPatchLogRotation -LogPath $logPath
    } catch {
        # Une rotation qui echoue ne doit jamais empecher d'ecrire la ligne.
    }

    $line = "{0} {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Message
    Add-Content -LiteralPath $logPath -Value $line
    if (-not $Quiet) {
        Write-Host $line
    }
}

function Get-TSMAutoPatchStatusPath {
    if ($script:OutputPathOverride) {
        return Join-Path $script:OutputPathOverride "patch-status.json"
    }
    return Join-Path $PSScriptRoot "patch-status.json"
}

function Send-TSMAutoPatchNotification {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Title,
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    return Send-AddonPatchNotification -Title $Title -Message $Message
}

function Write-TSMAutoPatchStatus {
    <#
    .SYNOPSIS
        Ecrit l'etat du dernier passage du patch dans patch-status.json.

    .DESCRIPTION
        Sert de source de verite consultable a froid : quels patchs sont
        appliques, lesquels sont sautes faute de cible, lesquels echouent et
        depuis combien de passages consecutifs.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [AllowNull()]
        $Result,
        [Parameter(Mandatory = $true)]
        [hashtable]$ConsecutiveFailures,
        [string]$FatalError
    )

    $failures = New-Object System.Collections.Generic.List[object]
    if ($Result -and $Result.FailedPatches) {
        foreach ($failure in $Result.FailedPatches) {
            $failures.Add([pscustomobject]@{
                name = $failure.Name
                error = $failure.Error
                consecutiveFailures = [int]$ConsecutiveFailures[$failure.Name]
            })
        }
    }

    $skips = New-Object System.Collections.Generic.List[object]
    if ($Result -and $Result.SkippedPatches) {
        foreach ($skip in $Result.SkippedPatches) {
            $skips.Add([pscustomobject]@{ name = $skip.Name; reason = $skip.Reason })
        }
    }

    $payload = [pscustomobject]@{
        updatedAt = (Get-Date).ToString("o")
        healthy = (-not $FatalError) -and ($failures.Count -eq 0)
        addonPath = if ($Result) { $Result.AddonPath } else { $null }
        addonVersion = if ($Result) { $Result.Version } else { $null }
        status = if ($Result) { $Result.Status } else { "error" }
        fatalError = $FatalError
        appliedCount = if ($Result) { $Result.AppliedPatches.Count } else { 0 }
        failedPatches = $failures.ToArray()
        skippedPatches = $skips.ToArray()
    }

    try {
        $json = $payload | ConvertTo-Json -Depth 4
        [System.IO.File]::WriteAllText((Get-TSMAutoPatchStatusPath), $json, [System.Text.UTF8Encoding]::new($false))
    } catch {
        # L'ecriture de l'etat ne doit jamais interrompre le watcher.
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

function Convert-TSMPatchBlockText {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Text,
        [Parameter(Mandatory = $true)]
        [string]$Newline,
        [Parameter(Mandatory = $true)]
        [string]$Label
    )

    $normalized = [regex]::Replace($Text, "\r?\n", $Newline)

    # Les blocs de patch ecrivent leurs tabulations avec le marqueur litteral
    # deux caracteres backslash-t, pour survivre aux editeurs qui convertissent
    # les tabulations en espaces. La meme sequence a l'interieur d'une chaine Lua
    # est en revanche une vraie sequence d'echappement : l'expanser corromprait
    # le code source. On refuse alors explicitement au lieu de reecrire en
    # silence.
    $marker = [string][char]92 + "t"
    foreach ($line in ($normalized -split "\r?\n")) {
        $markerIndex = $line.IndexOf($marker, [System.StringComparison]::Ordinal)
        while ($markerIndex -ge 0) {
            $prefix = $line.Substring(0, $markerIndex)
            $quotesBefore = $prefix.Length - $prefix.Replace([string][char]34, "").Length
            if ($quotesBefore % 2 -eq 1) {
                throw "Ambiguous tab marker inside a Lua string in $Label. Use a real tab character on this line instead of the backslash-t marker: $line"
            }
            $markerIndex = $line.IndexOf($marker, $markerIndex + 2, [System.StringComparison]::Ordinal)
        }
    }

    return $normalized.Replace($marker, [string][char]9)
}

function Get-TSMPatchOccurrenceCount {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Haystack,
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Needle
    )

    if ([string]::IsNullOrEmpty($Needle)) {
        return 0
    }
    $count = 0
    $index = $Haystack.IndexOf($Needle, [System.StringComparison]::Ordinal)
    while ($index -ge 0) {
        $count++
        $index = $Haystack.IndexOf($Needle, $index + $Needle.Length, [System.StringComparison]::Ordinal)
    }
    return $count
}

function Test-TSMPatchAnchor {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Haystack,
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Needle,
        [Parameter(Mandatory = $true)]
        [string]$Label
    )

    $occurrences = Get-TSMPatchOccurrenceCount -Haystack $Haystack -Needle $Needle
    if ($occurrences -eq 0) {
        return $false
    }
    if ($occurrences -gt 1) {
        # Un ancrage qui matche plusieurs fois patcherait toutes les occurrences
        # d'un coup sans que rien ne le signale. On prefere echouer bruyamment.
        throw "Ambiguous anchor in $Label ($occurrences matches). Widen the anchor so that it matches exactly once."
    }
    return $true
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
    $normalizedOriginal = Convert-TSMPatchBlockText -Text $Original -Newline $newline -Label $Label
    $normalizedPatched = Convert-TSMPatchBlockText -Text $Patched -Newline $newline -Label $Label

    if ($Content.Value.Contains($normalizedPatched)) {
        return $false
    }
    if (-not (Test-TSMPatchAnchor -Haystack $Content.Value -Needle $normalizedOriginal -Label $Label)) {
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
    $normalizedPatched = Convert-TSMPatchBlockText -Text $Patched -Newline $newline -Label $Label
    if ($Content.Value.Contains($normalizedPatched)) {
        return $false
    }
    foreach ($original in $Originals) {
        $normalizedOriginal = Convert-TSMPatchBlockText -Text $original -Newline $newline -Label $Label
        if (Test-TSMPatchAnchor -Haystack $Content.Value -Needle $normalizedOriginal -Label $Label) {
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

    Write-AddonPatchBytesAtomically -FilePath $FilePath -Bytes $Bytes
}

function Test-TSMPatchLuaSyntax {
    # Delegue a la primitive partagee ; conserve pour ne pas toucher aux
    # appelants et aux tests existants.
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Content,
        [Parameter(Mandatory = $true)]
        [string]$Label
    )

    $valid = Test-AddonPatchLuaSyntax -Content $Content -Label $Label
    $script:LastLuaSyntaxError = Get-AddonPatchLastLuaError
    return $valid
}

function Start-TSMPatchTransaction {
    <#
    .SYNOPSIS
        Ouvre une transaction de patch sur un jeu de fichiers de l'addon.

    .DESCRIPTION
        Les chemins passes via -FilePaths sont obligatoires : leur absence
        interrompt le patch. Ceux passes via -OptionalFilePaths sont ignores
        lorsqu'ils n'existent pas (fichier deplace ou supprime par une mise a
        jour de l'addon) : les patchs qui les ciblent sont alors sautes au lieu
        de faire echouer l'ensemble.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$AddonPath,
        [Parameter(Mandatory = $true)]
        [string[]]$FilePaths,
        [string[]]$OptionalFilePaths = @()
    )

    if ($script:PatchTransaction) {
        throw "A TSM patch transaction is already active."
    }
    $resolvedRoot = [System.IO.Path]::GetFullPath($AddonPath).TrimEnd('\')
    $rootPrefix = $resolvedRoot + '\'
    $files = @{}
    $skipped = New-Object System.Collections.Generic.List[string]
    $missingRequired = New-Object System.Collections.Generic.List[string]

    foreach ($entry in @(
        @{ Paths = $FilePaths; Required = $true },
        @{ Paths = $OptionalFilePaths; Required = $false }
    )) {
        foreach ($filePath in $entry.Paths) {
            $resolvedPath = [System.IO.Path]::GetFullPath($filePath)
            if (-not $resolvedPath.StartsWith($rootPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
                throw "TSM patch target is outside the addon folder: $resolvedPath"
            }
            if (-not [System.IO.File]::Exists($resolvedPath)) {
                if ($entry.Required) {
                    $missingRequired.Add($resolvedPath)
                } else {
                    $skipped.Add($resolvedPath.Substring($rootPrefix.Length))
                }
                continue
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
    }

    if ($missingRequired.Count -gt 0) {
        # Un fichier du coeur a disparu : le patch ne peut pas etre coherent.
        # On liste chaque chemin sur sa propre ligne, l'ancienne version les
        # concatenait en un seul message illisible.
        throw ("TSM patch targets do not exist:" + [Environment]::NewLine + (($missingRequired | ForEach-Object { "  - $_" }) -join [Environment]::NewLine))
    }

    $script:PatchTransaction = [pscustomobject]@{
        AddonPath = $resolvedRoot
        Files = $files
        SkippedTargets = $skipped.ToArray()
    }
}

function Stop-TSMPatchTransaction {
    $script:PatchTransaction = $null
}

function Get-TSMPatchSkippedTargets {
    if (-not $script:PatchTransaction) {
        return @()
    }
    return $script:PatchTransaction.SkippedTargets
}

function Test-TSMPatchTarget {
    <#
    .SYNOPSIS
        Indique si un fichier cible fait partie de la transaction en cours.

    .DESCRIPTION
        Permet aux patchs qui visent un fichier optionnel de se sauter
        proprement lorsque la mise a jour de l'addon l'a fait disparaitre.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )

    if (-not $script:PatchTransaction) {
        return [System.IO.File]::Exists([System.IO.Path]::GetFullPath($FilePath))
    }
    return $script:PatchTransaction.Files.ContainsKey([System.IO.Path]::GetFullPath($FilePath))
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
    $skippedTargets = @($transaction.SkippedTargets)

    # Verification de syntaxe avant toute ecriture : un bloc de remplacement qui
    # laisse un end en trop produirait du Lua invalide et casserait l'addon au
    # prochain rechargement de l'interface.
    $invalid = New-Object System.Collections.Generic.List[string]
    foreach ($entry in $changedEntries) {
        if (-not (Test-TSMPatchLuaSyntax -Content $entry.Content -Label $entry.RelativePath)) {
            $invalid.Add("$($entry.RelativePath): $script:LastLuaSyntaxError")
        }
    }
    if ($invalid.Count -gt 0) {
        Stop-TSMPatchTransaction
        throw ("TSM patch produced invalid Lua, nothing was written:" + [Environment]::NewLine + (($invalid | ForEach-Object { "  - $_" }) -join [Environment]::NewLine))
    }

    if ($DryRun -or $changedEntries.Count -eq 0) {
        Stop-TSMPatchTransaction
        return [pscustomobject]@{
            ChangedCount = $changedEntries.Count
            ChangedFiles = @($changedEntries | ForEach-Object { $_.RelativePath })
            SkippedTargets = $skippedTargets
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
        $manifest = New-Object System.Collections.Generic.List[object]
        foreach ($entry in $changedEntries) {
            $diskBackupPath = Join-Path $backupPath $entry.RelativePath
            $diskBackupParent = Split-Path -Parent $diskBackupPath
            New-Item -ItemType Directory -Path $diskBackupParent -Force | Out-Null
            [System.IO.File]::WriteAllBytes($diskBackupPath, $entry.OriginalBytes)
            $manifest.Add([pscustomobject]@{
                Path = $entry.Path
                RelativePath = $entry.RelativePath
                LastWriteTimeUtc = $entry.LastWriteTimeUtc.ToString("o")
            })
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
        ChangedFiles = @($changedEntries | ForEach-Object { $_.RelativePath })
        SkippedTargets = $skippedTargets
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

    # La cle qui decide de ce qui est un seul et meme objet a vendre. L'exposer
    # permet de la lire en jeu sans deviner :
    #   /run local n={} for b=0,5 do for s=1,C_Container.GetContainerNumSlots(b) do local l=C_Container.GetContainerItemLink(b,s) if l then local k=TSM_API.GetItemStatKey(l) if k then n[k]=(n[k] or 0)+1 end end end end for k,v in pairs(n) do print(k,v) end
    $original = @'
--- Gets the path to the group which a specific item is in.
-- @within Group
'@
    $patched = @'
--- Gets the key which decides what counts as one and the same item to sell.
-- Items sharing an item level and stats share this key, whatever cosmetic bonus
-- IDs they carry.
-- @within Item
-- @tparam string item An item string, link or id
-- @treturn string The stat key, or nil if the item could not be parsed
function TSM_API.GetItemStatKey(item)
\tprivate.CheckCallMethod(item)
\tlocal itemString = ItemString.Get(item)
\tif not itemString then
\t\treturn nil
\tend
\treturn ItemString.ToStatKey(itemString)
end

--- Gets the path to the group which a specific item is in.
-- @within Group
'@
    $changed = (Replace-ExactBlock -Content ([ref]$content) -Original $original -Patched $patched -Label "Core\\API.lua stat key") -or $changed

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

function Update-TSMMailingInboxFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )

    # TSM ne remet private.frame a nil que depuis le script OnHide du cadre boite
    # de reception. Quand ce cadre est libere sans que OnHide parte, la reference
    # survit et le minuteur d'une seconde tape dans un element vide :
    # "Element (inbox) has no child with id: 'top'", une fois par seconde jusqu'au
    # /reload. UpdateButtons se protege deja avec HasChildById("top") ; on applique
    # la meme garde au compte a rebours, puis on demonte proprement la reference
    # (sinon l'assert de GetInboxMailsFrame casse la prochaine ouverture de la
    # boite aux lettres).
    $content = Get-TSMPatchContent -FilePath $FilePath
    $original = @'
function private.UpdateCountDown(force)
	if not force then
		private.updateCounterTimer:RunForTime(1)
	end
	if not private.frame then
		return
	end
'@
    $patched = @'
function private.UpdateCountDown(force)
	if not force then
		private.updateCounterTimer:RunForTime(1)
	end
	if not private.frame then
		return
	end
	if not private.frame:HasChildById("top") then
		-- The inbox frame was released without its OnHide script running, so this
		-- reference is stale. Tear it down once instead of erroring on every tick.
		private.frame = nil
		if private.inboxQueryCancellable then
			private.inboxQueryCancellable:Cancel()
			private.inboxQueryCancellable = nil
		end
		private.fsm:ProcessEvent("EV_FRAME_HIDE")
		return
	end
'@

    $changed = Replace-ExactBlock -Content ([ref]$content) -Original $original -Patched $patched -Label "Core\\UI\\MailingUI\\Inbox.lua"
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

    # Les objets a stats aleatoires (batons de metier Multicraft ou
    # Ressourcefulness, equipement craft) partagent un item de base. TSM ramene
    # chaque objet des sacs a l'itemString du groupe, donc toutes les variantes
    # fusionnent : l'undercut se calcule contre la moins chere toutes stats
    # confondues, et le postCap plafonne l'item de base au lieu de chaque stat.
    #
    # L'identite de vente devient donc la cle ItemString.ToStatKey, « meme niveau
    # d'objet, memes stats ». Elle ignore les bonusIds qui n'ajoutent qu'une ligne
    # d'infobulle : deux batons identiques en jeu ne comptent que pour un.
    # L'itemString exact reste ce qu'on transporte (prix, liens, journal), la cle
    # ne sert qu'a regrouper et a comparer.
    # Replace-ExactBlockAny s'arrete au premier ancrage trouve, et l'ancrage
    # vierge est un suffixe du bloc patche : la generation la plus recente doit
    # donc etre essayee en premier.
    $helperOriginals = @()
    $helperOriginals += @'
function private.GetVariantItemString(itemString)
\t-- Items with random stats are posted variant by variant: undercut only against
\t-- listings sharing the same stats, and apply the post cap per stat.
\tlocal groupItemString = Group.TranslateItemString(itemString)
\tif itemString == groupItemString then
\t\t-- The variant itself is grouped, so TSM already keeps it distinct
\t\treturn groupItemString
\tend
\tif itemString == ItemString.GetBaseFast(itemString) then
\t\treturn groupItemString
\tend
\tif ItemInfo.IsCommodity(itemString) ~= false then
\t\t-- Commodity sub rows carry the base item link, so a variant key would never
\t\t-- match. A nil result means the item info is not loaded yet.
\t\treturn groupItemString
\tend
\tif not Group.GetPathByItem(itemString) then
\t\treturn groupItemString
\tend
\treturn itemString
end

function private.GetVariantStatKey(itemString)
\t-- The sale identity: everything with the same item level and the same stats is
\t-- one and the same thing to post, whatever cosmetic bonusIds it carries.
\treturn ItemString.ToStatKey(private.GetVariantItemString(itemString))
end

function private.OnGroupsOperationsChanged()
\tprivate.operationsChangedTimer:RunForFrames(1)
end
'@
    $helperOriginals += @'
function private.OnGroupsOperationsChanged()
\tprivate.operationsChangedTimer:RunForFrames(1)
end
'@
    $patched = @'
function private.GetVariantItemString(itemString)
\t-- The itemString carried around for prices, links and the log. Any member of the
\t-- stat group will do, so keep the one the bag actually holds.
\tif not ItemString.IsItem(itemString) then
\t\t-- Battle pets keep TSM's own grouping
\t\treturn Group.TranslateItemString(itemString)
\tend
\treturn itemString
end

function private.GetVariantStatKey(itemString)
\t-- The sale identity: same item level and same stats is one and the same thing to
\t-- post, whatever cosmetic bonusIds it carries. Derived from the itemString alone
\t-- and never from the item cache: ItemInfo.IsCommodity answers nil until
\t-- GetMaxStack is known, per itemString, so a key that consulted it split one and
\t-- the same rod across several lines and multiplied the post cap by as many.
\tif not ItemString.IsItem(itemString) then
\t\treturn Group.TranslateItemString(itemString)
\tend
\treturn ItemString.ToStatKey(itemString)
end

function private.OnGroupsOperationsChanged()
\tprivate.operationsChangedTimer:RunForFrames(1)
end
'@
    $changed = (Replace-ExactBlockAny -Content ([ref]$content) -Originals $helperOriginals -Patched $patched -Label "Auctioning\\PostScan variant stat key helpers") -or $changed

    $original = @'
\tprivate.bagDB = Database.NewSchema("AUCTIONING_POST_BAGS")
\t\t:AddStringField("itemString")
\t\t:AddNumberField("bag")
\t\t:AddNumberField("slot")
\t\t:AddNumberField("quantity")
\t\t:AddUniqueNumberField("slotId")
\t\t:AddIndex("itemString")
\t\t:AddIndex("slotId")
\t\t:Commit()
'@
    $patched = @'
\tprivate.bagDB = Database.NewSchema("AUCTIONING_POST_BAGS")
\t\t:AddStringField("itemString")
\t\t:AddStringField("statKey")
\t\t:AddNumberField("bag")
\t\t:AddNumberField("slot")
\t\t:AddNumberField("quantity")
\t\t:AddUniqueNumberField("slotId")
\t\t:AddIndex("itemString")
\t\t:AddIndex("statKey")
\t\t:AddIndex("slotId")
\t\t:Commit()
'@
    $changed = (Replace-ExactBlock -Content ([ref]$content) -Original $original -Patched $patched -Label "Auctioning\\PostScan bag DB stat key field") -or $changed

    $original = @'
\treturn BagTracking.CreateQueryBagsAuctionable()
\t\t:VirtualField("autoBaseItemString", "string", Group.TranslateItemString, "itemString")
\t\t:VirtualField("name", "string", ItemInfo.GetName, "autoBaseItemString", "")
\t\t:VirtualField("groupPath", "string", Group.GetPathByItem, "itemString", "")
\t\t:Distinct("autoBaseItemString")
'@
    $patched = @'
\treturn BagTracking.CreateQueryBagsAuctionable()
\t\t:VirtualField("autoBaseItemString", "string", private.GetVariantItemString, "itemString")
\t\t:VirtualField("statKey", "string", private.GetVariantStatKey, "itemString")
\t\t:VirtualField("name", "string", ItemInfo.GetName, "autoBaseItemString", "")
\t\t:VirtualField("groupPath", "string", Group.GetPathByItem, "itemString", "")
\t\t:Distinct("statKey")
'@
    $changed = (Replace-ExactBlock -Content ([ref]$content) -Original $original -Patched $patched -Label "Auctioning\\PostScan bags query stat key") -or $changed

    $original = @'
\tlocal query = BagTracking.CreateQueryBagsAuctionable()
\t\t:VirtualField("autoBaseItemString", "string", Group.TranslateItemString, "itemString")
\t\t:Select("autoBaseItemString")
'@
    $patched = @'
\tlocal query = BagTracking.CreateQueryBagsAuctionable()
\t\t:VirtualField("autoBaseItemString", "string", private.GetVariantItemString, "itemString")
\t\t:Select("autoBaseItemString")
'@
    $changed = (Replace-ExactBlock -Content ([ref]$content) -Original $original -Patched $patched -Label "Auctioning\\PostScan operation DB variant key") -or $changed

    $original = @'
\t\t:VirtualField("autoBaseItemString", "string", Group.TranslateItemString, "itemString")
\t\t:Select("slotId", "bag", "slot", "autoBaseItemString", "quantity")
\tfor _, slotId, bag, slot, itemString, quantity in query:Iterator() do
\t\tprivate.DebugLogInsert(itemString, "Updating bag DB with %d in %d, %d", quantity, bag, slot)
\t\tprivate.bagDB:BulkInsertNewRow(itemString, bag, slot, quantity, slotId)
\tend
'@
    $patched = @'
\t\t:VirtualField("autoBaseItemString", "string", private.GetVariantItemString, "itemString")
\t\t:Select("slotId", "bag", "slot", "autoBaseItemString", "quantity")
\tfor _, slotId, bag, slot, itemString, quantity in query:Iterator() do
\t\tprivate.DebugLogInsert(itemString, "Updating bag DB with %d in %d, %d", quantity, bag, slot)
\t\tprivate.bagDB:BulkInsertNewRow(itemString, ItemString.ToStatKey(itemString), bag, slot, quantity, slotId)
\tend
'@
    $changed = (Replace-ExactBlock -Content ([ref]$content) -Original $original -Patched $patched -Label "Auctioning\\PostScan bag DB stat key value") -or $changed

    # Le scan raisonne par classe de stats. L'itemString retenu pour chaque classe
    # n'est qu'un representant : tout ce qui compte est retrouve par la cle.
    $original = @'
\t-- get the state of the player's bags
\tlocal bagCounts = TempTable.Acquire()
\tlocal bagQuery = private.bagDB:NewQuery()
\t\t:Select("itemString", "quantity")
\tfor _, itemString, quantity in bagQuery:Iterator() do
\t\tbagCounts[itemString] = (bagCounts[itemString] or 0) + quantity
\tend
\tbagQuery:Release()

\t-- generate the list of items we want to scan for
\twipe(private.itemList)
\tfor itemString, numHave in pairs(bagCounts) do
\t\tprivate.DebugLogInsert(itemString, "Scan thread has %d", numHave)
\t\tlocal groupPath = Group.GetPathByItem(itemString)
\t\tlocal contextFilter = scanContext.isItems and itemString or groupPath
\t\tif groupPath and tContains(scanContext, contextFilter) and private.CanPostItem(itemString, groupPath, numHave) then
\t\t\ttinsert(private.itemList, itemString)
\t\tend
\tend
\tTempTable.Release(bagCounts)
'@
    $patched = @'
\t-- get the state of the player's bags, grouped by item level and stats
\tlocal bagCounts = TempTable.Acquire()
\tlocal bagItems = TempTable.Acquire()
\tlocal bagQuery = private.bagDB:NewQuery()
\t\t:Select("itemString", "statKey", "quantity")
\t\t:OrderBy("slotId", true)
\tfor _, itemString, statKey, quantity in bagQuery:Iterator() do
\t\tbagCounts[statKey] = (bagCounts[statKey] or 0) + quantity
\t\tbagItems[statKey] = bagItems[statKey] or itemString
\tend
\tbagQuery:Release()

\t-- generate the list of items we want to scan for
\twipe(private.itemList)
\tfor statKey, numHave in pairs(bagCounts) do
\t\tlocal itemString = bagItems[statKey]
\t\tprivate.DebugLogInsert(itemString, "Scan thread has %d", numHave)
\t\tlocal groupPath = Group.GetPathByItem(itemString)
\t\tlocal isSelected = nil
\t\tif scanContext.isItems then
\t\t\t-- The selection carries whichever member of the stat group the item list
\t\t\t-- happened to show, or the base item for searches saved before posting
\t\t\t-- became stat aware.
\t\t\tisSelected = false
\t\t\tlocal groupItemString = Group.TranslateItemString(itemString)
\t\t\tfor _, contextItemString in ipairs(scanContext) do
\t\t\t\tif contextItemString == groupItemString or ItemString.ToStatKey(contextItemString) == statKey then
\t\t\t\t\tisSelected = true
\t\t\t\t\tbreak
\t\t\t\tend
\t\t\tend
\t\telse
\t\t\tisSelected = groupPath and tContains(scanContext, groupPath) or false
\t\tend
\t\tif groupPath and isSelected and private.CanPostItem(itemString, groupPath, numHave) then
\t\t\ttinsert(private.itemList, itemString)
\t\tend
\tend
\tTempTable.Release(bagItems)
\tTempTable.Release(bagCounts)
'@
    $changed = (Replace-ExactBlock -Content ([ref]$content) -Original $original -Patched $patched -Label "Auctioning\\PostScan scan thread stat groups") -or $changed

    $original = @'
\tfor _, query in auctionScan:QueryIterator() do
\t\tquery:SetIsBrowseDoneFunction(private.QueryIsBrowseDoneFunction)
\t\tquery:AddCustomFilter(private.QueryBuyoutFilter)
\tend
'@
    $patched = @'
\tfor _, query in auctionScan:QueryIterator() do
\t\tquery:SetIsBrowseDoneFunction(private.QueryIsBrowseDoneFunction)
\t\tquery:AddCustomFilter(private.QueryBuyoutFilter)
\t\tquery:SetMatchByStats(true)
\tend
'@
    $changed = (Replace-ExactBlock -Content ([ref]$content) -Original $original -Patched $patched -Label "Auctioning\\PostScan query stat matching") -or $changed

    $original = @'
\t\t\tlocal bagQuery = private.bagDB:NewQuery()
\t\t\t\t:Select("quantity", "bag", "slot")
\t\t\t\t:Equal("itemString", itemString)
'@
    $patched = @'
\t\t\tlocal bagQuery = private.bagDB:NewQuery()
\t\t\t\t:Select("quantity", "bag", "slot")
\t\t\t\t:Equal("statKey", ItemString.ToStatKey(itemString))
'@
    $changed = (Replace-ExactBlock -Content ([ref]$content) -Original $original -Patched $patched -Label "Auctioning\\PostScan numHave by stat key") -or $changed

    $original = @'
function private.GetPostBagSlot(itemString, quantity)
\t-- start with the slot which is closest to the desired stack size
\tlocal bag, slot = private.bagDB:NewQuery()
\t\t:Select("bag", "slot")
\t\t:Equal("itemString", itemString)
\t\t:GreaterThanOrEqual("quantity", quantity)
\t\t:OrderBy("quantity", true)
\t\t:GetFirstResultAndRelease()
\tif not bag then
\t\tbag, slot = private.bagDB:NewQuery()
\t\t\t:Select("bag", "slot")
\t\t\t:Equal("itemString", itemString)
\t\t\t:LessThanOrEqual("quantity", quantity)
\t\t\t:OrderBy("quantity", false)
\t\t\t:GetFirstResultAndRelease()
\tend
'@
    $patched = @'
function private.GetPostBagSlot(itemString, quantity)
\t-- Any bag slot with the same item level and stats will do: the queued
\t-- itemString is only one representative of its stat group.
\tlocal statKey = ItemString.ToStatKey(itemString)
\t-- start with the slot which is closest to the desired stack size
\tlocal bag, slot = private.bagDB:NewQuery()
\t\t:Select("bag", "slot")
\t\t:Equal("statKey", statKey)
\t\t:GreaterThanOrEqual("quantity", quantity)
\t\t:OrderBy("quantity", true)
\t\t:GetFirstResultAndRelease()
\tif not bag then
\t\tbag, slot = private.bagDB:NewQuery()
\t\t\t:Select("bag", "slot")
\t\t\t:Equal("statKey", statKey)
\t\t\t:LessThanOrEqual("quantity", quantity)
\t\t\t:OrderBy("quantity", false)
\t\t\t:GetFirstResultAndRelease()
\tend
'@
    $changed = (Replace-ExactBlock -Content ([ref]$content) -Original $original -Patched $patched -Label "Auctioning\\PostScan bag slot by stat key") -or $changed

    $original = @'
function private.ItemBagSlotHelper(itemString, bag, slot, quantity, removeContext)
\tlocal slotId = SlotId.Join(bag, slot)
'@
    $patched = @'
function private.ItemBagSlotHelper(itemString, bag, slot, quantity, removeContext)
\tlocal slotId = SlotId.Join(bag, slot)
\tlocal statKey = ItemString.ToStatKey(itemString)
'@
    $changed = (Replace-ExactBlock -Content ([ref]$content) -Original $original -Patched $patched -Label "Auctioning\\PostScan bag slot helper stat key") -or $changed

    $original = @'
\t\t:Select("slotId", "bag", "slot")
\t\t:Equal("itemString", itemString)
\t\t:LessThan("slotId", slotId)
'@
    $patched = @'
\t\t:Select("slotId", "bag", "slot")
\t\t:Equal("statKey", statKey)
\t\t:LessThan("slotId", slotId)
'@
    $changed = (Replace-ExactBlock -Content ([ref]$content) -Original $original -Patched $patched -Label "Auctioning\\PostScan lower slot by stat key") -or $changed

    $original = @'
\t\t:Select("slotId", "quantity")
\t\t:Equal("itemString", itemString)
\t\t:LessThan("slotId", slotId)
'@
    $patched = @'
\t\t:Select("slotId", "quantity")
\t\t:Equal("statKey", statKey)
\t\t:LessThan("slotId", slotId)
'@
    $changed = (Replace-ExactBlock -Content ([ref]$content) -Original $original -Patched $patched -Label "Auctioning\\PostScan combined slots by stat key") -or $changed

    $original = @'
\t\t:Select("bag", "slot")
\t\t:Equal("itemString", itemString)
\t\t:GreaterThan("slotId", slotId)
'@
    $patched = @'
\t\t:Select("bag", "slot")
\t\t:Equal("statKey", statKey)
\t\t:GreaterThan("slotId", slotId)
'@
    $changed = (Replace-ExactBlock -Content ([ref]$content) -Original $original -Patched $patched -Label "Auctioning\\PostScan higher slot by stat key") -or $changed

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
\t\t\tlocal sameTarget = candidateItemString and private.GetVariantStatKey(candidateItemString) == statKey
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
    $bagMismatchOriginals += $patched
    $patched = @'
\tif not bagItemString or private.GetVariantStatKey(bagItemString) ~= statKey then
\t\t-- something changed with the player's bags so we can't post the item right now
\t\tLog.Warn("[YayaTSM] post-bags-changed target=%s bag=%s slot=%s actual=%s statKey=%s", itemString, tostring(bag), tostring(slot), tostring(bagItemString), tostring(bagItemString and private.GetVariantStatKey(bagItemString)))
\t\tif type(YayaReagentSniperTrace) == "function" then
\t\t\tYayaReagentSniperTrace("TSM_POST_STRING_MISMATCH", "target=%s slot=%s:%s actual=%s statKey=%s rawLink=%s", itemString, tostring(bag), tostring(slot), tostring(bagItemString), tostring(bagItemString and private.GetVariantStatKey(bagItemString)), tostring(Container.GetItemLink(bag, slot)))
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

function Update-TSMItemStringFile {
    <#
    .SYNOPSIS
        Ajoute ItemString.ToStatKey : la cle « meme niveau d'objet, memes stats ».

    .DESCRIPTION
        Deux itemStrings TSM peuvent differer sans que l'objet ne vaille autre
        chose. LibBonusId classe les bonusIds en deux familles : ceux qui portent
        un effet mecanique (data.bonuses, op scale/add/set) et ceux qui n'ajoutent
        qu'une ligne d'infobulle (data.tooltipBonuses). BonusIds.Filter garde les
        deux, donc l'itemString conserve des bonusIds purement cosmetiques.

        Constate sur le baton d'alchimie (i:245778) : 12500/12501/12502 valent
        +12/+19/+26 niveaux d'objet (les rangs de craft), tandis que 8952, 8953 et
        12251 n'ont aucune entree mecanique. Deux batons identiques en niveau et
        en stat portaient donc deux itemStrings differents.

        ToLevel resout deja la partie niveau d'objet, puisqu'il calcule le niveau
        a partir de tous les bonusIds : les cosmetiques n'y contribuent pas et
        disparaissent. Il reste a lui adjoindre les modificateurs de stats
        (types 29 et 30, plus les bonusIds de stat d'artisanat), que
        GetStatModifiers sait deja extraire. La cle produite n'est pas un
        itemString et ne doit jamais etre utilisee comme tel : le separateur "|"
        l'exclut de la grammaire des itemStrings.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )

    $content = Get-TSMPatchContent -FilePath $FilePath
    $changed = $false

    $original = @'
local private = {
\titemStringCache = {},
\tbaseItemStringMap = nil,
\tbaseItemStringReader = nil,
\tlevelItemStringMap = nil,
\thasNonBaseItemStrings = {},
\tbonusIdsTemp = {},
\tmodifiersTemp = {},
\tmodifiersValueTemp = {},
\textraStatModifiersTemp = {},
}
'@
    $patched = @'
local private = {
\titemStringCache = {},
\tbaseItemStringMap = nil,
\tbaseItemStringReader = nil,
\tlevelItemStringMap = nil,
\thasNonBaseItemStrings = {},
\tbonusIdsTemp = {},
\tmodifiersTemp = {},
\tmodifiersValueTemp = {},
\textraStatModifiersTemp = {},
\tstatKeyCache = {},
\tstatKeyTemp = {},
}
'@
    $changed = (Replace-ExactBlock -Content ([ref]$content) -Original $original -Patched $patched -Label "LibTSMTypes\\ItemString stat key state") -or $changed

    $original = @'
---Gets a list of stat modifier values which are present in an itemString
---@param itemString string An itemString to get the stat modifiers of
---@param fromBonusIdsOnly boolean Only get equivalent modifiers from bonusIds
---@param resultTbl table The table to store the results in
function ItemString.GetStatModifiers(itemString, fromBonusIdsOnly, resultTbl)
'@
    $patched = @'
---Converts an itemString into a key which is equal for items with the same item level and stats.
---Bonus IDs which only add a tooltip line (crafter marks, hidden flags) are ignored, since they
---change the itemString without changing what the item is or what it is worth.
---The result is NOT an itemString: the "|" separator keeps it out of that grammar on purpose.
---@param itemString string An itemString to get the stat key of
---@return string
function ItemString.ToStatKey(itemString)
\tif not itemString then
\t\treturn nil
\tend
\tlocal key = private.statKeyCache[itemString]
\tif key then
\t\treturn key
\tend
\t-- ToLevel computes the item level from every bonusId, so the cosmetic ones
\t-- contribute nothing and drop out on their own.
\tkey = ItemString.ToLevel(itemString)
\twipe(private.statKeyTemp)
\tItemString.GetStatModifiers(itemString, false, private.statKeyTemp)
\tif #private.statKeyTemp > 0 then
\t\tsort(private.statKeyTemp)
\t\tkey = key.."|"..table.concat(private.statKeyTemp, ",")
\tend
\twipe(private.statKeyTemp)
\tprivate.statKeyCache[itemString] = key
\treturn key
end

---Gets a list of stat modifier values which are present in an itemString
---@param itemString string An itemString to get the stat modifiers of
---@param fromBonusIdsOnly boolean Only get equivalent modifiers from bonusIds
---@param resultTbl table The table to store the results in
function ItemString.GetStatModifiers(itemString, fromBonusIdsOnly, resultTbl)
'@
    $changed = (Replace-ExactBlock -Content ([ref]$content) -Original $original -Patched $patched -Label "LibTSMTypes\\ItemString ToStatKey") -or $changed

    if ($changed) {
        Set-TSMPatchContent -FilePath $FilePath -Content $content
    }
    return $changed
}

function Update-TSMAuctionQueryFile {
    <#
    .SYNOPSIS
        Permet a une requete de scan de rapprocher les sous-lignes par stats.

    .DESCRIPTION
        AuctionQuery ne connait que trois granularites : item de base, niveau
        d'objet, itemString exact. Le posting par variante en demande une
        quatrieme, « meme niveau d'objet et memes stats ». Plutot que de changer
        le comportement de tout le monde (l'achat groupe et le sniper passent par
        les memes fonctions), on ajoute un interrupteur par requete, que seuls les
        scans de post et d'annulation activent.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )

    $content = Get-TSMPatchContent -FilePath $FilePath
    $changed = $false

    $original = @'
local ITEM_SPECIFIC = newproxy()
local ITEM_BASE = newproxy()
'@
    $patched = @'
local ITEM_SPECIFIC = newproxy()
local ITEM_BASE = newproxy()
local ITEM_STAT_KEY = newproxy()
'@
    $changed = (Replace-ExactBlock -Content ([ref]$content) -Original $original -Patched $patched -Label "AuctionScan\\Query stat key marker") -or $changed

    $original = @'
\tself._items = {}
\tself._customFilters = {}
'@
    $patched = @'
\tself._items = {}
\tself._matchByStats = false
\tself._customFilters = {}
'@
    $changed = (Replace-ExactBlock -Content ([ref]$content) -Original $original -Patched $patched -Label "AuctionScan\\Query init flag") -or $changed

    $original = @'
\twipe(self._items)
\twipe(self._customFilters)
'@
    $patched = @'
\twipe(self._items)
\tself._matchByStats = false
\twipe(self._customFilters)
'@
    $changed = (Replace-ExactBlock -Content ([ref]$content) -Original $original -Patched $patched -Label "AuctionScan\\Query release flag") -or $changed

    $original = @'
\t\tfor _, itemString in ipairs(items) do
\t\t\tlocal baseItemString = ItemString.GetBaseFast(itemString)
\t\t\tself._items[itemString] = ITEM_SPECIFIC
\t\t\tif baseItemString ~= itemString then
\t\t\t\tself._items[baseItemString] = self._items[baseItemString] or ITEM_BASE
\t\t\tend
\t\tend
'@
    $patched = @'
\t\tfor _, itemString in ipairs(items) do
\t\t\tlocal baseItemString = ItemString.GetBaseFast(itemString)
\t\t\tself._items[itemString] = ITEM_SPECIFIC
\t\t\tlocal statKey = ItemString.ToStatKey(itemString)
\t\t\tif statKey and statKey ~= itemString then
\t\t\t\t-- Registered under its own marker so ItemIterator keeps yielding real
\t\t\t\t-- itemStrings only.
\t\t\t\tself._items[statKey] = ITEM_STAT_KEY
\t\t\tend
\t\t\tif baseItemString ~= itemString then
\t\t\t\tself._items[baseItemString] = self._items[baseItemString] or ITEM_BASE
\t\t\tend
\t\tend
'@
    $changed = (Replace-ExactBlock -Content ([ref]$content) -Original $original -Patched $patched -Label "AuctionScan\\Query SetItems stat keys") -or $changed

    $original = @'
---Adds a custom filter function.
'@
    $patched = @'
---Sets whether or not sub rows are matched by item level and stats instead of by exact itemString.
---@param matchByStats boolean
---@return AuctionQuery
function AuctionQuery:SetMatchByStats(matchByStats)
\tself._matchByStats = matchByStats and true or false
\treturn self
end

---Adds a custom filter function.
'@
    $changed = (Replace-ExactBlock -Content ([ref]$content) -Original $original -Patched $patched -Label "AuctionScan\\Query SetMatchByStats") -or $changed

    $original = @'
\t\t\tif (isBaseItemString and subRowBaseItemString == itemString) or (isLevelItemString and ItemString.ToLevel(subRowItemString) == itemString) or (not isBaseItemString and not isLevelItemString and subRowItemString == itemString) then
'@
    $patched = @'
\t\t\tlocal isSpecificMatch = nil
\t\t\tif self._matchByStats then
\t\t\t\t-- Two itemStrings can differ by bonusIds which only add a tooltip line
\t\t\t\t-- while the item level and the stats are the same.
\t\t\t\tisSpecificMatch = ItemString.ToStatKey(subRowItemString) == ItemString.ToStatKey(itemString)
\t\t\telse
\t\t\t\tisSpecificMatch = subRowItemString == itemString
\t\t\tend
\t\t\tif (isBaseItemString and subRowBaseItemString == itemString) or (isLevelItemString and ItemString.ToLevel(subRowItemString) == itemString) or (not isBaseItemString and not isLevelItemString and isSpecificMatch) then
'@
    $changed = (Replace-ExactBlock -Content ([ref]$content) -Original $original -Patched $patched -Label "AuctionScan\\Query ItemSubRowIterator stat match") -or $changed

    $original = @'
\t\tlocal levelItemString = itemString and ItemString.ToLevel(itemString)
\t\tif isSubRow and itemString and self._items[itemString] ~= ITEM_SPECIFIC and self._items[levelItemString] ~= ITEM_SPECIFIC and self._items[baseItemString] ~= ITEM_SPECIFIC then
'@
    $patched = @'
\t\tlocal levelItemString = itemString and ItemString.ToLevel(itemString)
\t\tlocal statKey = (self._matchByStats and itemString) and ItemString.ToStatKey(itemString) or nil
\t\tif isSubRow and itemString and self._items[itemString] ~= ITEM_SPECIFIC and self._items[levelItemString] ~= ITEM_SPECIFIC and self._items[baseItemString] ~= ITEM_SPECIFIC and (not statKey or self._items[statKey] ~= ITEM_STAT_KEY) then
'@
    $changed = (Replace-ExactBlock -Content ([ref]$content) -Original $original -Patched $patched -Label "AuctionScan\\Query IsFiltered stat match") -or $changed

    if ($changed) {
        Set-TSMPatchContent -FilePath $FilePath -Content $content
    }
    return $changed
}

function Update-TSMCancelScanFile {
    <#
    .SYNOPSIS
        Aligne l'annulation sur le posting par cle de stats.

    .DESCRIPTION
        Sans ce patch, TSM annulerait un baton Multicraft parce qu'un baton
        Ressourcefulness est moins cher : le scan d'annulation ramene lui aussi
        chaque annonce a l'itemString du groupe. On lui donne la meme identite de
        vente que PostScan, et la requete sur mes propres encheres compare
        desormais la cle « meme niveau d'objet, memes stats » plutot que
        l'itemString caractere pour caractere.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )

    $content = Get-TSMPatchContent -FilePath $FilePath
    $changed = $false

    $helperOriginals = @()
    $helperOriginals += @'
function private.GetVariantItemString(itemString)
\t-- Items with random stats are cancelled variant by variant, to stay in sync
\t-- with how PostScan prices them.
\tlocal groupItemString = Group.TranslateItemString(itemString)
\tif itemString == groupItemString then
\t\t-- The variant itself is grouped, so TSM already keeps it distinct
\t\treturn groupItemString
\tend
\tif itemString == ItemString.GetBaseFast(itemString) then
\t\treturn groupItemString
\tend
\tif ItemInfo.IsCommodity(itemString) ~= false then
\t\t-- Commodity sub rows carry the base item link, so a variant key would never
\t\t-- match. A nil result means the item info is not loaded yet.
\t\treturn groupItemString
\tend
\tif not Group.GetPathByItem(itemString) then
\t\treturn groupItemString
\tend
\treturn itemString
end

function private.GetVariantStatKey(itemString)
\treturn ItemString.ToStatKey(private.GetVariantItemString(itemString))
end

function private.CanCancelItem(itemString, groupList)
\tlocal groupPath = Group.GetPathByItem(itemString)
'@
    $helperOriginals += @'
function private.CanCancelItem(itemString, groupList)
\tlocal groupPath = Group.GetPathByItem(itemString)
'@
    $patched = @'
function private.GetVariantItemString(itemString)
\t-- Any member of the stat group will do as the itemString we carry around.
\tif not ItemString.IsItem(itemString) then
\t\t-- Battle pets keep TSM's own grouping
\t\treturn Group.TranslateItemString(itemString)
\tend
\treturn itemString
end

function private.GetVariantStatKey(itemString)
\t-- Same identity as PostScan, and derived from the itemString alone so it cannot
\t-- move with the item cache.
\tif not ItemString.IsItem(itemString) then
\t\treturn Group.TranslateItemString(itemString)
\tend
\treturn ItemString.ToStatKey(itemString)
end

function private.CanCancelItem(itemString, groupList)
\tlocal groupPath = Group.GetPathByItem(itemString)
'@
    $changed = (Replace-ExactBlockAny -Content ([ref]$content) -Originals $helperOriginals -Patched $patched -Label "Auctioning\\CancelScan variant stat key helpers") -or $changed

    $original = @'
\tlocal query = Auction.NewIndexQuery()
\t\t:Equal("isSold", false)
\t\t:VirtualField("autoBaseItemString", "string", Group.TranslateItemString, "itemString")
\t\t:Select("autoBaseItemString")
'@
    $patched = @'
\tlocal query = Auction.NewIndexQuery()
\t\t:Equal("isSold", false)
\t\t:VirtualField("autoBaseItemString", "string", private.GetVariantItemString, "itemString")
\t\t:Select("autoBaseItemString")
'@
    $changed = (Replace-ExactBlock -Content ([ref]$content) -Original $original -Patched $patched -Label "Auctioning\\CancelScan scan list variant key") -or $changed

    $original = @'
\tfor _, itemString in query:Iterator() do
\t\tif not processedItems[itemString] and private.CanCancelItem(itemString, groupList) then
\t\t\ttinsert(private.itemList, itemString)
\t\tend
\t\tprocessedItems[itemString] = true
\tend
'@
    $patched = @'
\tfor _, itemString in query:Iterator() do
\t\t-- One entry per stat group: two auctions of the same tool differing only by a
\t\t-- cosmetic bonusId are the same thing to cancel.
\t\tlocal statKey = ItemString.ToStatKey(itemString)
\t\tif not processedItems[statKey] and private.CanCancelItem(itemString, groupList) then
\t\t\ttinsert(private.itemList, itemString)
\t\tend
\t\tprocessedItems[statKey] = true
\tend
'@
    $changed = (Replace-ExactBlock -Content ([ref]$content) -Original $original -Patched $patched -Label "Auctioning\\CancelScan stat groups") -or $changed

    $original = @'
\tfor _, query2 in auctionScan:QueryIterator() do
\t\tquery2:AddCustomFilter(private.QueryBuyoutFilter)
\tend
'@
    $patched = @'
\tfor _, query2 in auctionScan:QueryIterator() do
\t\tquery2:AddCustomFilter(private.QueryBuyoutFilter)
\t\tquery2:SetMatchByStats(true)
\tend
'@
    $changed = (Replace-ExactBlock -Content ([ref]$content) -Original $original -Patched $patched -Label "Auctioning\\CancelScan query stat matching") -or $changed

    $original = @'
\treturn Auction.NewIndexQuery()
\t\t:Equal("isSold", false)
\t\t:Equal(itemStringField, itemString)
\t\t:VirtualField("autoBaseItemString", "string", Group.TranslateItemString, "itemString")
\t\t:Equal("autoBaseItemString", autoBaseItemString)
\t\t:OrderBy("auctionId", false)
'@
    $patched = @'
\tif itemStringField == "itemString" then
\t\t-- Match every auction sharing the item level and the stats, not only the ones
\t\t-- whose itemString is character for character identical.
\t\treturn Auction.NewIndexQuery()
\t\t\t:Equal("isSold", false)
\t\t\t:Equal("baseItemString", ItemString.GetBaseFast(itemString))
\t\t\t:VirtualField("statKey", "string", ItemString.ToStatKey, "itemString")
\t\t\t:Equal("statKey", ItemString.ToStatKey(itemString))
\t\t\t:VirtualField("autoBaseItemString", "string", private.GetVariantItemString, "itemString")
\t\t\t:OrderBy("auctionId", false)
\tend
\treturn Auction.NewIndexQuery()
\t\t:Equal("isSold", false)
\t\t:Equal(itemStringField, itemString)
\t\t:VirtualField("autoBaseItemString", "string", private.GetVariantItemString, "itemString")
\t\t:Equal("autoBaseItemString", autoBaseItemString)
\t\t:OrderBy("auctionId", false)
'@
    $changed = (Replace-ExactBlock -Content ([ref]$content) -Original $original -Patched $patched -Label "Auctioning\\CancelScan auctions query stat key") -or $changed

    if ($changed) {
        Set-TSMPatchContent -FilePath $FilePath -Content $content
    }
    return $changed
}

function Update-TSMAuctioningBagScrollTableFile {
    <#
    .SYNOPSIS
        Distingue les groupes de stats dans la liste "Post Items from Bags".

    .DESCRIPTION
        Le posting par cle de stats fait apparaitre une ligne par couple
        (niveau d'objet, stats). Sans libelle, deux batons afficheraient
        exactement le meme nom. La stat tiree au sort d'un outil de metier n'est
        pas dans GetItemStats, qui decrit l'item de base : elle n'existe que dans
        l'infobulle du lien de l'exemplaire. On lit donc l'infobulle, et on
        affiche le niveau d'objet a cote, puisque c'est l'autre moitie de la cle.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )

    $content = Get-TSMPatchContent -FilePath $FilePath
    $changed = $false

    $original = @'
local Table = LibTSMUI:From("LibTSMUtil"):Include("Lua.Table")
local private = {
\tselectedTemp = {},
}
'@
    $patched = @'
local Table = LibTSMUI:From("LibTSMUtil"):Include("Lua.Table")
local ItemString = LibTSMUI:From("LibTSMTypes"):Include("Item.ItemString")
local ItemInfo = LibTSMUI:From("LibTSMService"):Include("Item.ItemInfo")
local private = {
\tselectedTemp = {},
\tvariantSuffixCache = {},
\tvariantStatNames = nil,
}
local VARIANT_STAT_KEYS = {
\t"ITEM_MOD_MULTICRAFT_RATING_SHORT",
\t"ITEM_MOD_RESOURCEFULNESS_RATING_SHORT",
\t"ITEM_MOD_CRAFTING_SPEED_RATING_SHORT",
\t"ITEM_MOD_INSPIRATION_RATING_SHORT",
\t"ITEM_MOD_FINESSE_RATING_SHORT",
\t"ITEM_MOD_DEFTNESS_RATING_SHORT",
\t"ITEM_MOD_PERCEPTION_RATING_SHORT",
\t"ITEM_MOD_INGENUITY_RATING_SHORT",
}
'@
    $changed = (Replace-ExactBlock -Content ([ref]$content) -Original $original -Patched $patched -Label "LibTSMUI\\AuctioningBagScrollTable includes") -or $changed

    $original = @'
\t\ttinsert(self._data.item, "|T"..itemTexture..":0|t "..(UIUtils.GetDisplayItemName(autoBaseItemString) or "?"))
'@
    $patched = @'
\t\ttinsert(self._data.item, "|T"..itemTexture..":0|t "..(UIUtils.GetDisplayItemName(autoBaseItemString) or "?")..private.GetVariantSuffix(autoBaseItemString))
'@
    $changed = (Replace-ExactBlock -Content ([ref]$content) -Original $original -Patched $patched -Label "LibTSMUI\\AuctioningBagScrollTable variant label") -or $changed

    $original = @'
\tlocal settingsValue = self:_GetSettingsValue()
\tself._query:ResetOrderBy()
\t\t:OrderBy(COL_INFO[settingsValue.sortCol].sortField, settingsValue.sortAscending)
\tself:_HandleQueryUpdate()
end
'@
    $patched = @'
\tlocal settingsValue = self:_GetSettingsValue()
\tself._query:ResetOrderBy()
\t\t:OrderBy(COL_INFO[settingsValue.sortCol].sortField, settingsValue.sortAscending)
\tself:_HandleQueryUpdate()
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.GetVariantStatNames()
\tif not private.variantStatNames then
\t\tprivate.variantStatNames = {}
\t\tfor _, key in ipairs(VARIANT_STAT_KEYS) do
\t\t\tlocal name = _G[key]
\t\t\tif type(name) == "string" and name ~= "" then
\t\t\t\ttinsert(private.variantStatNames, name)
\t\t\tend
\t\tend
\tend
\treturn private.variantStatNames
end

function private.GetVariantSuffix(itemString)
\t-- Posting groups items by item level and stats, so two rows can carry the same
\t-- item name. Show what actually tells them apart.
\tif not itemString or itemString == ItemString.GetBaseFast(itemString) then
\t\treturn ""
\tend
\tlocal cached = private.variantSuffixCache[itemString]
\tif cached then
\t\treturn cached
\tend
\tlocal parts = nil
\tlocal itemLevel = ItemString.GetItemLevel(itemString)
\tif itemLevel then
\t\tparts = tostring(itemLevel)
\tend
\tlocal statName = nil
\tlocal link = ItemInfo.GetLink(itemString)
\tif link and C_TooltipInfo and C_TooltipInfo.GetHyperlink then
\t\t-- The rolled crafting stat of a profession tool is not in GetItemStats, which
\t\t-- describes the base item. Only the tooltip of this exact link carries it.
\t\tlocal tooltipData = C_TooltipInfo.GetHyperlink(link)
\t\tif type(tooltipData) == "table" and type(tooltipData.lines) == "table" then
\t\t\tfor _, line in ipairs(tooltipData.lines) do
\t\t\t\tif not statName and type(line.leftText) == "string" then
\t\t\t\t\tfor _, name in ipairs(private.GetVariantStatNames()) do
\t\t\t\t\t\tif not statName and strfind(line.leftText, name, 1, true) then
\t\t\t\t\t\t\tstatName = name
\t\t\t\t\t\tend
\t\t\t\t\tend
\t\t\t\tend
\t\t\tend
\t\tend
\tend
\tif statName then
\t\tparts = parts and (parts..", "..statName) or statName
\tend
\tlocal suffix = parts and (" ("..parts..")") or ""
\tif statName then
\t\t-- The tooltip is only complete once the client has cached the item, so only
\t\t-- memoize a label we know is final.
\t\tprivate.variantSuffixCache[itemString] = suffix
\tend
\treturn suffix
end
'@
    $changed = (Replace-ExactBlock -Content ([ref]$content) -Original $original -Patched $patched -Label "LibTSMUI\\AuctioningBagScrollTable variant suffix helper") -or $changed

    if ($changed) {
        Set-TSMPatchContent -FilePath $FilePath -Content $content
    }
    return $changed
}

function Update-TSMSchemaFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )

    $content = Get-TSMPatchContent -FilePath $FilePath
    $changed = $false

    $original = @'
	-- [133] updated global.auctionUIContext.{auctioningAuctionScrollingTable,myAuctionsScrollingTable,shoppingAuctionScrollingTable,sniperScrollingTable}, factionrealm.auctioningOptions.whitelist
	return Settings.NewSchema(133, 10)
'@
    $patched = @'
	-- [133] updated global.auctionUIContext.{auctioningAuctionScrollingTable,myAuctionsScrollingTable,shoppingAuctionScrollingTable,sniperScrollingTable}, factionrealm.auctioningOptions.whitelist
	-- [134] added global.coreOptions.goldToKeepOnCharacter
	return Settings.NewSchema(134, 10)
'@
    $changed = (Replace-ExactBlock -Content ([ref]$content) -Original $original -Patched $patched -Label "LibTSMSystem\\Source\\AddonSettings\\Schema.lua version") -or $changed

    $original = @'
				:AddBoolean("regionWide", false, 119)
'@
    $patched = @'
				:AddBoolean("regionWide", false, 119)
				:AddNumber("goldToKeepOnCharacter", 0, 134)
'@
    $changed = (Replace-ExactBlock -Content ([ref]$content) -Original $original -Patched $patched -Label "LibTSMSystem\\Source\\AddonSettings\\Schema.lua gold setting") -or $changed

    if ($changed) {
        Set-TSMPatchContent -FilePath $FilePath -Content $content
    }
    return $changed
}

function Update-TSMLocaleFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )

    $content = Get-TSMPatchContent -FilePath $FilePath
    $changed = $false

    $original = @'
-- LOCALE STRINGS END HERE
'@
    $patched = @'
L["The amount of gold to keep on the character when balancing gold with the Warbank."] = "The amount of gold to keep on the character when balancing gold with the Warbank."
L["Gold to keep on character"] = "Gold to keep on character"
L["Gold pieces"] = "Gold pieces"
L["Deposit excess gold"] = "Deposit excess gold"
L["Withdraw gold"] = "Withdraw gold"
L["Gold is balanced"] = "Gold is balanced"
-- LOCALE STRINGS END HERE
'@
    $changed = (Replace-ExactBlock -Content ([ref]$content) -Original $original -Patched $patched -Label "Locale strings") -or $changed

    if ($changed) {
        Set-TSMPatchContent -FilePath $FilePath -Content $content
    }
    return $changed
}

function Update-TSMGeneralSettingsFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )

    $content = Get-TSMPatchContent -FilePath $FilePath
    $changed = $false

    $original = @'
	auctionDBAltRealm = L["Loads AuctionDB data for an additional realm for display in the tooltip."],
}
'@
    $patched = @'
	auctionDBAltRealm = L["Loads AuctionDB data for an additional realm for display in the tooltip."],
	goldToKeepOnCharacter = L["The amount of gold to keep on the character when balancing gold with the Warbank."],
}
'@
    $changed = (Replace-ExactBlock -Content ([ref]$content) -Original $original -Patched $patched -Label "Core\\UI\\MainUI\\Settings\\General.lua gold tooltip") -or $changed

    $original = @'
		:AddKey("global", "coreOptions", "groupPriceSource")
		:AddKey("global", "coreOptions", "destroyValueSource")
'@
    $patched = @'
		:AddKey("global", "coreOptions", "groupPriceSource")
		:AddKey("global", "coreOptions", "destroyValueSource")
		:AddKey("global", "coreOptions", "goldToKeepOnCharacter")
'@
    $changed = (Replace-ExactBlock -Content ([ref]$content) -Original $original -Patched $patched -Label "Core\\UI\\MainUI\\Settings\\General.lua gold setting") -or $changed

    $original = @'
			:AddChild(TSM.MainUI.Settings.CreateInputWithReset("generalGroupPriceField", L["Filter group item lists based on the following price source"], private.settings, "groupPriceSource", nil, nil, SETTING_TOOLTIPS.groupPriceSource))
			:AddChild(UIElements.New("Frame", "dropdownLabelLine")
'@
    $patched = @'
			:AddChild(TSM.MainUI.Settings.CreateInputWithReset("generalGroupPriceField", L["Filter group item lists based on the following price source"], private.settings, "groupPriceSource", nil, nil, SETTING_TOOLTIPS.groupPriceSource))
			:AddChild(UIElements.New("Text", "goldToKeepLabel")
				:SetHeight(18)
				:SetMargin(0, 0, 0, 4)
				:SetFont("BODY_BODY2_MEDIUM")
				:SetText(L["Gold to keep on character"])
			)
			:AddChild(UIElements.New("Frame", "goldToKeepFrame")
				:SetLayout("HORIZONTAL")
				:SetHeight(24)
				:SetMargin(0, 0, 0, 12)
				:AddChild(UIElements.New("Input", "goldToKeepInput")
					:SetMargin(0, 8, 0, 0)
					:SetBackgroundColor("ACTIVE_BG")
					:SetValidateFunc("NUMBER", "0:1000000000")
					:SetSettingInfo(private.settings, "goldToKeepOnCharacter")
					:SetTooltip(SETTING_TOOLTIPS.goldToKeepOnCharacter, "__parent")
				)
				:AddChild(UIElements.New("Text", "label")
					:SetSize("AUTO", 16)
					:SetFont("BODY_BODY3")
					:SetText(L["Gold pieces"])
				)
			)
			:AddChild(UIElements.New("Frame", "dropdownLabelLine")
'@
    $changed = (Replace-ExactBlock -Content ([ref]$content) -Original $original -Patched $patched -Label "Core\\UI\\MainUI\\Settings\\General.lua gold input") -or $changed

    if ($changed) {
        Set-TSMPatchContent -FilePath $FilePath -Content $content
    }
    return $changed
}

function Update-TSMBankingUIFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )

    $content = Get-TSMPatchContent -FilePath $FilePath
    $changed = $false

    $original = @'
local ClientInfo = TSM.LibTSMWoW:Include("Util.ClientInfo")
local L = TSM.Locale.GetTable()
'@
    $patched = @'
local ClientInfo = TSM.LibTSMWoW:Include("Util.ClientInfo")
local Event = TSM.LibTSMWoW:Include("Service.Event")
local L = TSM.Locale.GetTable()
'@
    $changed = (Replace-ExactBlock -Content ([ref]$content) -Original $original -Patched $patched -Label "Core\\UI\\BankingUI\\Core.lua event API") -or $changed

    $original = @'
		:AddKey("global", "bankingUIContext", "tab")
		:AddKey("char", "bankingUIContext", "warehousingGroupTree")
'@
    $patched = @'
		:AddKey("global", "bankingUIContext", "tab")
		:AddKey("global", "coreOptions", "goldToKeepOnCharacter")
		:AddKey("char", "bankingUIContext", "warehousingGroupTree")
'@
    $changed = (Replace-ExactBlock -Content ([ref]$content) -Original $original -Patched $patched -Label "Core\\UI\\BankingUI\\Core.lua gold setting") -or $changed

    $original = @'
			:AddChild(UIElements.New("Frame", "footer")
				:SetLayout("VERTICAL")
				:SetHeight(ClientInfo.IsRetail() and 202 or 170)
'@
    $patched = @'
			:AddChild(UIElements.New("Frame", "footer")
				:SetLayout("VERTICAL")
				:SetHeight(ClientInfo.IsRetail() and 234 or 170)
'@
    $changed = (Replace-ExactBlock -Content ([ref]$content) -Original $original -Patched $patched -Label "Core\\UI\\BankingUI\\Core.lua footer height") -or $changed

    $original = @'
	else
		error("Unexpected module: "..tostring(private.settings.tab))
	end
	footerButtonsFrame:Draw()
end
'@
    $patched = @'
	else
		error("Unexpected module: "..tostring(private.settings.tab))
	end
	footerButtonsFrame:AddChildIf(ClientInfo.IsRetail(), UIElements.New("ActionButton", "balanceGoldBtn")
		:SetHeight(24)
		:SetMargin(0, 0, 8, 0)
		:SetFont("BODY_BODY2_MEDIUM")
		:SetContext(private.BalanceCharacterGold)
		:SetScript("OnClick", private.SimpleBtnOnClick)
	)
	footerButtonsFrame:Draw()
end
'@
    $changed = (Replace-ExactBlock -Content ([ref]$content) -Original $original -Patched $patched -Label "Core\\UI\\BankingUI\\Core.lua balance button") -or $changed

    $balanceFunction = @'
function private.BalanceCharacterGold(callback)
	local targetMoney = max(0, floor(private.settings.goldToKeepOnCharacter or 0)) * COPPER_PER_GOLD
	local playerMoney = GetMoney()
	local warbankMoney = C_Bank.FetchDepositedMoney(Enum.BankType.Account) or 0
	local difference = targetMoney - playerMoney
	if difference > 0 then
		C_Bank.WithdrawMoney(Enum.BankType.Account, min(difference, warbankMoney))
	elseif difference < 0 then
		C_Bank.DepositMoney(Enum.BankType.Account, -difference)
	end
	-- Les callbacks doivent sortir de la transition FSM avant d'etre emis.
	-- BalanceCharacterGold est le seul startFunc synchrone de cette machine a
	-- etats : appeles ici, PROGRESS et DONE arrivaient pendant _inTransition et
	-- LibTSMUtil les jetait avec un simple Log.Warn, laissant ST_PROCESSING actif
	-- indefiniment. context.progress restait alors a 0, valeur vraie en Lua, donc
	-- le bouton restait enfonce et grise sur "Gold is balanced" jusqu'a la
	-- fermeture de la banque. Deux timers distincts pour eviter toute reentrance
	-- entre EV_THREAD_PROGRESS et EV_THREAD_DONE.
	C_Timer.After(0, function()
		callback("PROGRESS", 1)
	end)
	C_Timer.After(0, function()
		callback("DONE")
	end)
end
'@
    $newline = if ($content.Contains("`r`n")) { "`r`n" } else { "`n" }
    $normalizedBalanceFunction = [regex]::Replace($balanceFunction.TrimEnd("`r", "`n"), "\r?\n", $newline) + $newline + $newline
    $balanceMarker = "function private.BalanceCharacterGold(callback)"
    $simpleMarker = "function private.SimpleBtnOnClick(button)"
    $balanceStart = $content.IndexOf($balanceMarker, [System.StringComparison]::Ordinal)
    $simpleStart = $content.IndexOf($simpleMarker, [System.StringComparison]::Ordinal)
    if ($simpleStart -lt 0) {
        throw "Unexpected code in Core\\UI\\BankingUI\\Core.lua balance action."
    }
    if ($balanceStart -lt 0) {
        $content = $content.Insert($simpleStart, $normalizedBalanceFunction)
        $changed = $true
    } else {
        $simpleStart = $content.IndexOf($simpleMarker, $balanceStart, [System.StringComparison]::Ordinal)
        if ($simpleStart -lt 0) {
            throw "Unexpected code in Core\\UI\\BankingUI\\Core.lua balance action."
        }
        $currentBalanceFunctions = $content.Substring($balanceStart, $simpleStart - $balanceStart)
        if ($currentBalanceFunctions -cne $normalizedBalanceFunction) {
            $content = $content.Substring(0, $balanceStart) + $normalizedBalanceFunction + $content.Substring($simpleStart)
            $changed = $true
        }
    }

    $original = @'
		-- Update the action button state
		context.frame:SetTitle(context.isWarBank and L["Warbank"] or BANK)
		local footerButtonsFrame = context.frame:GetElement("content.footer.buttons")
		if private.settings.tab == "Warehousing" then
'@
    $patched = @'
		-- Update the action button state
		context.frame:SetTitle(context.isWarBank and L["Warbank"] or BANK)
		local footerButtonsFrame = context.frame:GetElement("content.footer.buttons")
		if ClientInfo.IsRetail() then
			local balanceGoldBtn = footerButtonsFrame:GetElement("balanceGoldBtn")
			balanceGoldBtn:SetShown(context.isWarBank)
			if context.isWarBank then
				local targetMoney = max(0, floor(private.settings.goldToKeepOnCharacter or 0)) * COPPER_PER_GOLD
				local playerMoney = GetMoney()
				local warbankMoney = C_Bank.FetchDepositedMoney(Enum.BankType.Account) or 0
				local difference = playerMoney - targetMoney
				local canBalance = difference ~= 0 and (difference > 0 or warbankMoney > 0)
				balanceGoldBtn
					:SetDisabled(context.progress or not canBalance)
					:SetText(difference > 0 and L["Deposit excess gold"] or difference < 0 and L["Withdraw gold"] or L["Gold is balanced"])
			end
		end
		if private.settings.tab == "Warehousing" then
'@
    $changed = (Replace-ExactBlock -Content ([ref]$content) -Original $original -Patched $patched -Label "Core\\UI\\BankingUI\\Core.lua balance state") -or $changed

    $original = @'
		:AddDefaultEventTransition("EV_BANK_CLOSED", "ST_CLOSED")
		:Init("ST_CLOSED", fsmContext)
'@
    $patched = @'
		:AddDefaultEventTransition("EV_BANK_CLOSED", "ST_CLOSED")
		:Init("ST_CLOSED", fsmContext)

	if ClientInfo.IsRetail() then
		local function MoneyChanged()
			if fsmContext.frame then
				UpdateFrame(fsmContext)
			end
		end
		Event.Register("PLAYER_MONEY", MoneyChanged)
		Event.Register("ACCOUNT_MONEY", MoneyChanged)
	end
'@
    $changed = (Replace-ExactBlock -Content ([ref]$content) -Original $original -Patched $patched -Label "Core\\UI\\BankingUI\\Core.lua money refresh") -or $changed

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

function Update-TSMContainerApiFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )

    $content = Get-TSMPatchContent -FilePath $FilePath
    $changed = $false

    # C_Bank.IsItemAllowedInBankType leve une erreur Lua si l'ItemLocation ne
    # designe plus aucun objet. Cela arrive des qu'un deplacement precedent a
    # vide la case pendant que le thread BANKING_MOVE evalue encore ses cibles,
    # typiquement en enchainant vite les boutons de la Banking UI :
    #   Container.lua:301: bad argument #2 to 'IsItemAllowedInBankType'
    # TSM applique deja exactement ce garde ailleurs (AuctionHouse.lua, ligne 91
    # environ) ; il manque seulement ici. Une case vide n'accepte aucun depot,
    # donc false est la bonne reponse et l'appelant passe a l'emplacement suivant.
    $original = @'
function Container.CanDepositIntoWarbank(bag, slot)
\tif not ClientInfo.HasFeature(ClientInfo.FEATURES.WARBAND_BANK) then
\t\treturn false
\tend
\tprivate.itemLocation:SetBagAndSlot(bag, slot)
\treturn C_Bank.IsItemAllowedInBankType(Enum.BankType.Account, private.itemLocation)
end
'@
    $patched = @'
function Container.CanDepositIntoWarbank(bag, slot)
\tif not ClientInfo.HasFeature(ClientInfo.FEATURES.WARBAND_BANK) then
\t\treturn false
\tend
\tprivate.itemLocation:SetBagAndSlot(bag, slot)
\tif not private.itemLocation:IsValid() then
\t\treturn false
\tend
\treturn C_Bank.IsItemAllowedInBankType(Enum.BankType.Account, private.itemLocation)
end
'@
    $changed = (Replace-ExactBlock -Content ([ref]$content) -Original $original -Patched $patched -Label "LibTSMWoW\\Source\\API\\Container.lua warbank deposit guard") -or $changed

    if ($changed) {
        Set-TSMPatchContent -FilePath $FilePath -Content $content
    }
    return $changed
}

function Invoke-TSMMailingPatch {
    <#
    .SYNOPSIS
        Applique l'ensemble des patchs personnels a TradeSkillMaster.

    .DESCRIPTION
        Chaque patch est isole : un ancrage qui ne correspond plus a la version
        installee est signale comme echoue sans annuler les autres. Seuls
        Core\API.lua et TradeSkillMaster.lua sont obligatoires (leur absence
        signifie que le dossier n'est pas une installation TSM valide) ; les
        autres cibles sont optionnelles et leurs patchs sont sautes si une mise
        a jour de l'addon les a deplacees.

        Le resultat expose AppliedPatches / FailedPatches / SkippedPatches pour
        que l'appelant puisse alerter au lieu de decouvrir l'echec dans le log.
    #>
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
    $mailingInboxPath = Join-Path $resolvedAddonPath "Core\UI\MailingUI\Inbox.lua"
    $mailingGroupsPath = Join-Path $resolvedAddonPath "Core\UI\MailingUI\Groups.lua"
    $mailingOtherPath = Join-Path $resolvedAddonPath "Core\UI\MailingUI\Other.lua"
    $mailingSendPath = Join-Path $resolvedAddonPath "Core\Service\Mailing\Send.lua"
    $auctionScrollTablePath = Join-Path $resolvedAddonPath "LibTSMUI\Source\AuctionHouse\AuctionScrollTable.lua"
    $bagTrackingPath = Join-Path $resolvedAddonPath "LibTSMService\Source\Inventory\BagTracking.lua"
    $bankingCorePath = Join-Path $resolvedAddonPath "Core\Service\Banking\Core.lua"
    $postScanPath = Join-Path $resolvedAddonPath "Core\Service\Auctioning\PostScan.lua"
    $cancelScanPath = Join-Path $resolvedAddonPath "Core\Service\Auctioning\CancelScan.lua"
    $auctioningBagScrollTablePath = Join-Path $resolvedAddonPath "LibTSMUI\Source\AuctionHouse\AuctioningBagScrollTable.lua"
    $itemStringPath = Join-Path $resolvedAddonPath "LibTSMTypes\Source\Item\ItemString.lua"
    $auctionQueryPath = Join-Path $resolvedAddonPath "LibTSMService\Source\AuctionScan\Classes\Query.lua"
    $craftingUiPath = Join-Path $resolvedAddonPath "Core\UI\CraftingUI\Core.lua"
    $auctionUiPath = Join-Path $resolvedAddonPath "Core\UI\AuctionUI\Core.lua"
    $shoppingOperationPath = Join-Path $resolvedAddonPath "LibTSMSystem\Source\Operation\ShoppingOperation.lua"
    $shoppingUiPath = Join-Path $resolvedAddonPath "Core\UI\MainUI\Operations\Shopping.lua"
    $shoppingGroupSearchPath = Join-Path $resolvedAddonPath "Core\Service\Shopping\GroupSearch.lua"
    $schemaPath = Join-Path $resolvedAddonPath "LibTSMSystem\Source\AddonSettings\Schema.lua"
    $generalSettingsPath = Join-Path $resolvedAddonPath "Core\UI\MainUI\Settings\General.lua"
    $bankingUiPath = Join-Path $resolvedAddonPath "Core\UI\BankingUI\Core.lua"
    $containerApiPath = Join-Path $resolvedAddonPath "LibTSMWoW\Source\API\Container.lua"
    $localePaths = @(
        "enUS.lua",
        "deDE.lua",
        "esES.lua",
        "esMX.lua",
        "frFR.lua",
        "itIT.lua",
        "koKR.lua",
        "ptBR.lua",
        "ruRU.lua",
        "zhCN.lua",
        "zhTW.lua"
    ) | ForEach-Object { Join-Path $resolvedAddonPath "Locale\$_" }

    # Ces deux fichiers structurent l'addon depuis toujours : s'ils manquent, le
    # dossier cible n'est pas une installation TradeSkillMaster.
    $requiredPaths = @($apiPath, $craftedPricePath)
    $optionalPaths = @(
        $mailingCorePath,
        $mailingInboxPath,
        $mailingGroupsPath,
        $mailingOtherPath,
        $mailingSendPath,
        $auctionScrollTablePath,
        $bagTrackingPath,
        $bankingCorePath,
        $postScanPath,
        $cancelScanPath,
        $auctioningBagScrollTablePath,
        $itemStringPath,
        $auctionQueryPath,
        $craftingUiPath,
        $auctionUiPath,
        $shoppingOperationPath,
        $shoppingUiPath,
        $shoppingGroupSearchPath,
        $schemaPath,
        $generalSettingsPath,
        $bankingUiPath,
        $containerApiPath
    ) + $localePaths

    $patches = New-Object System.Collections.Generic.List[object]
    $patches.Add(@{ Name = "API hooks";              Targets = @($apiPath);                 Action = { Update-TSMApiFile -FilePath $apiPath } })
    $patches.Add(@{ Name = "Crafted price source";   Targets = @($craftedPricePath);         Action = { Update-TSMCraftedPriceFile -FilePath $craftedPricePath } })
    $patches.Add(@{ Name = "Mailing UI core";        Targets = @($mailingCorePath);          Action = { Update-TSMMailingCoreFile -FilePath $mailingCorePath } })
    $patches.Add(@{ Name = "Mailing UI inbox";       Targets = @($mailingInboxPath);         Action = { Update-TSMMailingInboxFile -FilePath $mailingInboxPath } })
    $patches.Add(@{ Name = "Mailing UI groups";      Targets = @($mailingGroupsPath);        Action = { Update-TSMMailingGroupsFile -FilePath $mailingGroupsPath } })
    $patches.Add(@{ Name = "Mailing UI other";       Targets = @($mailingOtherPath);         Action = { Update-TSMMailingOtherFile -FilePath $mailingOtherPath } })
    $patches.Add(@{ Name = "Mailing send";           Targets = @($mailingSendPath);          Action = { Update-TSMMailingSendFile -FilePath $mailingSendPath } })
    $patches.Add(@{ Name = "Auction scroll table";   Targets = @($auctionScrollTablePath);   Action = { Update-TSMAuctionScrollTableFile -FilePath $auctionScrollTablePath } })
    $patches.Add(@{ Name = "Bag tracking";           Targets = @($bagTrackingPath);          Action = { Restore-TSMBagTrackingFile -FilePath $bagTrackingPath } })
    $patches.Add(@{ Name = "Banking";                Targets = @($bankingCorePath);          Action = { Update-TSMBankingFile -FilePath $bankingCorePath } })
    $patches.Add(@{ Name = "Item string stat key"; Targets = @($itemStringPath);           Action = { Update-TSMItemStringFile -FilePath $itemStringPath } })
    $patches.Add(@{ Name = "Auction query stats";  Targets = @($auctionQueryPath);         Action = { Update-TSMAuctionQueryFile -FilePath $auctionQueryPath } })
    $patches.Add(@{ Name = "Post scan debug";        Targets = @($postScanPath);             Action = { Update-TSMPostScanDebugFile -FilePath $postScanPath } })
    $patches.Add(@{ Name = "Cancel scan";            Targets = @($cancelScanPath);           Action = { Update-TSMCancelScanFile -FilePath $cancelScanPath } })
    $patches.Add(@{ Name = "Auctioning bag list";    Targets = @($auctioningBagScrollTablePath); Action = { Update-TSMAuctioningBagScrollTableFile -FilePath $auctioningBagScrollTablePath } })
    $patches.Add(@{ Name = "Default UI compat";      Targets = @($craftingUiPath, $auctionUiPath); Action = { Update-TSMDefaultUICompatibilityFiles -CraftingFilePath $craftingUiPath -AuctionFilePath $auctionUiPath } })
    $patches.Add(@{ Name = "Shopping operation";     Targets = @($shoppingOperationPath);    Action = { Update-TSMShoppingOperationFile -FilePath $shoppingOperationPath } })
    $patches.Add(@{ Name = "Shopping UI";            Targets = @($shoppingUiPath);           Action = { Update-TSMShoppingUIFile -FilePath $shoppingUiPath } })
    $patches.Add(@{ Name = "Shopping group search";  Targets = @($shoppingGroupSearchPath);  Action = { Update-TSMShoppingGroupSearchFile -FilePath $shoppingGroupSearchPath } })
    $patches.Add(@{ Name = "Settings schema";        Targets = @($schemaPath);               Action = { Update-TSMSchemaFile -FilePath $schemaPath } })
    $patches.Add(@{ Name = "General settings";       Targets = @($generalSettingsPath);      Action = { Update-TSMGeneralSettingsFile -FilePath $generalSettingsPath } })
    $patches.Add(@{ Name = "Banking UI";             Targets = @($bankingUiPath);            Action = { Update-TSMBankingUIFile -FilePath $bankingUiPath } })
    $patches.Add(@{ Name = "Container API";          Targets = @($containerApiPath);         Action = { Update-TSMContainerApiFile -FilePath $containerApiPath } })
    # Le chemin arrive en argument : un scriptblock qui capturerait $localePath
    # verrait la derniere valeur de la boucle au moment de l'invocation.
    $localeAction = { param($Path) Update-TSMLocaleFile -FilePath $Path }
    foreach ($localePath in $localePaths) {
        $patches.Add(@{
            Name = "Locale $([System.IO.Path]::GetFileNameWithoutExtension($localePath))"
            Targets = @($localePath)
            Action = $localeAction
        })
    }

    Start-TSMPatchTransaction -AddonPath $resolvedAddonPath -FilePaths $requiredPaths -OptionalFilePaths $optionalPaths

    $appliedPatches = New-Object System.Collections.Generic.List[string]
    $failedPatches = New-Object System.Collections.Generic.List[object]
    $skippedPatches = New-Object System.Collections.Generic.List[object]
    try {
        foreach ($patch in $patches) {
            $missingTarget = $null
            foreach ($target in $patch.Targets) {
                if (-not (Test-TSMPatchTarget -FilePath $target)) {
                    $missingTarget = $target
                    break
                }
            }
            if ($missingTarget) {
                $skippedPatches.Add([pscustomobject]@{
                    Name = $patch.Name
                    Reason = "cible absente: $($missingTarget.Substring($resolvedAddonPath.Length + 1))"
                })
                continue
            }

            try {
                # La premiere cible est passee en argument : les scriptblocks qui
                # referencent directement leur variable l'ignorent via $args.
                & $patch.Action $patch.Targets[0] | Out-Null
                $appliedPatches.Add($patch.Name)
            } catch {
                # Un ancrage perime ne doit pas empecher les autres patchs de
                # s'appliquer : on enregistre l'echec et on continue.
                $failedPatches.Add([pscustomobject]@{
                    Name = $patch.Name
                    Error = $_.Exception.Message
                })
            }
        }
        $transactionResult = Complete-TSMPatchTransaction -DryRun:$DryRun
    } catch {
        Stop-TSMPatchTransaction
        throw
    }

    $changed = $transactionResult.ChangedCount -gt 0
    $status = if ($DryRun -and $changed) { "would patch" } elseif ($changed) { "patched" } else { "already patched" }
    if ($failedPatches.Count -gt 0) {
        $status = "$status with $($failedPatches.Count) failed patch(es)"
    }

    if (-not $DryRun) {
        $backupSuffix = if ($transactionResult.BackupPath) { " backup=$($transactionResult.BackupPath)" } else { "" }
        Write-TSMAutoPatchLog -Message ("{0} ({1}) at {2}{3}" -f $status, $version, $resolvedAddonPath, $backupSuffix) -Quiet:$Quiet
        foreach ($failure in $failedPatches) {
            Write-TSMAutoPatchLog -Message ("  patch failed [{0}]: {1}" -f $failure.Name, $failure.Error) -Quiet:$Quiet
        }
        foreach ($skip in $skippedPatches) {
            Write-TSMAutoPatchLog -Message ("  patch skipped [{0}]: {1}" -f $skip.Name, $skip.Reason) -Quiet:$Quiet
        }
    }

    return [pscustomobject]@{
        AddonPath = $resolvedAddonPath
        Version = $version
        Changed = $changed
        Status = $status
        DryRun = [bool]$DryRun
        BackupPath = $transactionResult.BackupPath
        ChangedFiles = $transactionResult.ChangedFiles
        AppliedPatches = $appliedPatches.ToArray()
        FailedPatches = $failedPatches.ToArray()
        SkippedPatches = $skippedPatches.ToArray()
    }
}

function New-TSMAutoPatchRunTracker {
    <#
    .SYNOPSIS
        Cree l'etat de suivi partage entre deux passages du patch.

    .DESCRIPTION
        FailureCounts compte les echecs consecutifs par patch, AlertedPatches
        retient ceux pour lesquels une notification a deja ete envoyee, afin de
        ne pas repeter la meme alerte a chaque passage.
    #>
    return [pscustomobject]@{
        FailureCounts = @{}
        AlertedPatches = @{}
    }
}

function Invoke-TSMAutoPatchRun {
    <#
    .SYNOPSIS
        Applique le patch en suivant la persistance des echecs.

    .DESCRIPTION
        C'est la persistance d'un echec, et non son occurrence isolee, qui
        merite une notification : pendant une mise a jour de l'addon les
        fichiers sont reecrits un par un et un ancrage peut manquer
        temporairement. On notifie donc au bout de -AlertThreshold passages
        consecutifs en echec, une seule fois, puis on signale le retablissement.

    .PARAMETER Tracker
        Objet renvoye par New-TSMAutoPatchRunTracker, conserve entre les appels.

    .PARAMETER Notify
        Mettre a $false pour tester la logique sans emettre de notification.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$AddonPath,
        [Parameter(Mandatory = $true)]
        $Tracker,
        [Parameter(Mandatory = $true)]
        [string]$Origin,
        [int]$AlertThreshold = 2,
        [bool]$Notify = $true,
        [switch]$DryRun
    )

    $notifications = New-Object System.Collections.Generic.List[object]
    $failureCounts = $Tracker.FailureCounts
    $alertedPatches = $Tracker.AlertedPatches

    try {
        $result = Invoke-TSMMailingPatch -AddonPath $AddonPath -Quiet -DryRun:$DryRun
    } catch {
        $message = $_.Exception.Message
        Write-TSMAutoPatchLog -Message ("{0} patch failed: {1}" -f $Origin, $message) -Quiet
        Write-TSMAutoPatchStatus -Result $null -ConsecutiveFailures $failureCounts -FatalError $message
        if (-not $alertedPatches.ContainsKey("__fatal__")) {
            $alertedPatches["__fatal__"] = $true
            $notifications.Add([pscustomobject]@{ Kind = "fatal"; Name = "__fatal__"; Title = "Patch TSM interrompu"; Message = $message })
            if ($Notify) {
                Send-TSMAutoPatchNotification -Title "Patch TSM interrompu" -Message $message | Out-Null
            }
        }
        return [pscustomobject]@{
            Result = $null
            FatalError = $message
            Notifications = $notifications.ToArray()
        }
    }

    $alertedPatches.Remove("__fatal__")

    $currentFailures = @{}
    foreach ($failure in $result.FailedPatches) {
        $currentFailures[$failure.Name] = $failure.Error
    }

    # Un patch qui refonctionne remet son compteur a zero et leve son alerte.
    foreach ($name in @($failureCounts.Keys)) {
        if (-not $currentFailures.ContainsKey($name)) {
            $failureCounts.Remove($name)
            if ($alertedPatches.ContainsKey($name)) {
                $alertedPatches.Remove($name)
                Write-TSMAutoPatchLog -Message ("patch recovered [{0}]" -f $name) -Quiet
                $title = "Patch TSM retabli"
                $message = "Le patch {0} s'applique a nouveau." -f $name
                $notifications.Add([pscustomobject]@{ Kind = "recovered"; Name = $name; Title = $title; Message = $message })
                if ($Notify) {
                    Send-TSMAutoPatchNotification -Title $title -Message $message | Out-Null
                }
            }
        }
    }

    foreach ($name in $currentFailures.Keys) {
        $count = 1
        if ($failureCounts.ContainsKey($name)) {
            $count = [int]$failureCounts[$name] + 1
        }
        $failureCounts[$name] = $count

        if ($count -ge $AlertThreshold -and -not $alertedPatches.ContainsKey($name)) {
            $alertedPatches[$name] = $true
            $title = "Patch TSM en echec"
            $message = "{0} echoue depuis {1} passages (TSM {2}). Detail : {3}" -f $name, $count, $result.Version, $currentFailures[$name]
            Write-TSMAutoPatchLog -Message ("ALERT patch [{0}] failed {1} consecutive runs: {2}" -f $name, $count, $currentFailures[$name]) -Quiet
            $notifications.Add([pscustomobject]@{ Kind = "failed"; Name = $name; Title = $title; Message = $message })
            if ($Notify) {
                Send-TSMAutoPatchNotification -Title $title -Message $message | Out-Null
            }
        }
    }

    Write-TSMAutoPatchStatus -Result $result -ConsecutiveFailures $failureCounts

    return [pscustomobject]@{
        Result = $result
        FatalError = $null
        Notifications = $notifications.ToArray()
    }
}

