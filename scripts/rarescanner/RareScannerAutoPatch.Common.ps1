Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "..\lib\AddonPatchCore.ps1")

$script:WatcherMutexName = "Local\RareScannerAutoPatchWatcher"
$script:StartupLauncherName = "RareScanner Auto Patch Watcher.vbs"
$script:PatchMarker = "Yaya RareScanner AutoPatch: hide alert after rare kill"
$script:PingPatchMarker = "Yaya RareScanner AutoPatch: ping alert target"

function Get-RareScannerAutoPatchLogPath {
    $defaultDirectory = Join-Path ([Environment]::GetFolderPath("LocalApplicationData")) "YayaTools\RareScannerAutoPatch"
    return (Resolve-AddonPatchOutputPath -DefaultDirectory $defaultDirectory -FileName "rare-scanner-auto-patch.log")
}

function Get-RareScannerAutoPatchStartupPath {
    return (Join-Path ([Environment]::GetFolderPath("Startup")) $script:StartupLauncherName)
}

function Write-RareScannerAutoPatchLog {
    param(
        [Parameter(Mandatory = $true)][string]$Message,
        [switch]$Quiet
    )

    $logPath = Get-RareScannerAutoPatchLogPath
    New-Item -ItemType Directory -Path (Split-Path -Parent $logPath) -Force | Out-Null
    try { Invoke-AddonPatchLogRotation -LogPath $logPath } catch {}
    Add-Content -LiteralPath $logPath -Value ("[{0}] {1}" -f (Get-Date).ToString("s"), $Message) -Encoding UTF8
    if (-not $Quiet) { Write-Host $Message }
}

function Get-RareScannerAddonCandidates {
    $candidates = New-Object System.Collections.Generic.List[string]
    foreach ($root in @(
        [Environment]::GetEnvironmentVariable("ProgramFiles(x86)"),
        [Environment]::GetEnvironmentVariable("ProgramFiles")
    )) {
        if ($root) {
            $candidates.Add((Join-Path $root "World of Warcraft\_retail_\Interface\AddOns\RareScanner"))
        }
    }
    $candidates.Add("C:\Program Files (x86)\World of Warcraft\_retail_\Interface\AddOns\RareScanner")
    $candidates.Add("C:\Program Files\World of Warcraft\_retail_\Interface\AddOns\RareScanner")
    return $candidates
}

function Resolve-RareScannerAddonPath {
    param([string]$AddonPath)

    if ($AddonPath) {
        $resolved = (Resolve-Path -LiteralPath $AddonPath -ErrorAction Stop).Path
        if (-not (Test-Path -LiteralPath (Join-Path $resolved "RareScanner.toc") -PathType Leaf)) {
            throw "Rare Scanner addon invalide: $resolved"
        }
        return $resolved
    }

    foreach ($candidate in (Get-RareScannerAddonCandidates)) {
        if (Test-Path -LiteralPath (Join-Path $candidate "RareScanner.toc") -PathType Leaf) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }
    throw "Rare Scanner introuvable. Passez -AddonPath explicitement."
}

function Get-RareScannerAddonVersion {
    param([Parameter(Mandatory = $true)][string]$AddonPath)

    $versionLine = Get-Content -LiteralPath (Join-Path $AddonPath "RareScanner.toc") -ErrorAction Stop |
        Where-Object { $_ -match '^##\s*Version:\s*(.+)$' } |
        Select-Object -First 1
    if ($versionLine -and $versionLine -match '^##\s*Version:\s*(.+)$') { return $Matches[1].Trim() }
    return "unknown"
}

function Get-RareScannerSourceHash {
    param([Parameter(Mandatory = $true)][string]$Path)
    $sha256 = [Security.Cryptography.SHA256]::Create()
    try {
        return ([BitConverter]::ToString($sha256.ComputeHash([IO.File]::ReadAllBytes($Path)))).Replace("-", "")
    } finally { $sha256.Dispose() }
}

function Replace-RareScannerBlock {
    param(
        [Parameter(Mandatory = $true)][ref]$Content,
        [Parameter(Mandatory = $true)][string]$Original,
        [Parameter(Mandatory = $true)][string]$Patched,
        [Parameter(Mandatory = $true)][string]$Label
    )

    $normalizedOriginal = $Original.Replace("`r`n", "`n").Trim()
    $normalizedPatched = $Patched.Replace("`r`n", "`n").Trim()
    if ($Content.Value.Contains($normalizedPatched)) { return $false }

    $occurrences = 0
    $index = $Content.Value.IndexOf($normalizedOriginal, [StringComparison]::Ordinal)
    while ($index -ge 0) {
        $occurrences++
        $index = $Content.Value.IndexOf($normalizedOriginal, $index + $normalizedOriginal.Length, [StringComparison]::Ordinal)
    }
    if ($occurrences -eq 0) { throw "Bloc Rare Scanner attendu introuvable: $Label" }
    if ($occurrences -gt 1) { throw "Ancrage Rare Scanner ambigu ($occurrences correspondances): $Label" }

    $Content.Value = $Content.Value.Replace($normalizedOriginal, $normalizedPatched)
    return $true
}

function Invoke-RareScannerAutoPatch {
    param(
        [string]$AddonPath,
        [switch]$Quiet,
        [switch]$DryRun
    )

    $resolvedAddonPath = Resolve-RareScannerAddonPath -AddonPath $AddonPath
    $version = Get-RareScannerAddonVersion -AddonPath $resolvedAddonPath
    $eventSourcePath = Join-Path $resolvedAddonPath "Core\Service\RSEventHandler.lua"
    $buttonSourcePath = Join-Path $resolvedAddonPath "RareScanner.lua"
    if (-not (Test-Path -LiteralPath $eventSourcePath -PathType Leaf)) {
        throw "RSEventHandler.lua introuvable: $eventSourcePath"
    }
    if (-not (Test-Path -LiteralPath $buttonSourcePath -PathType Leaf)) {
        throw "RareScanner.lua introuvable: $buttonSourcePath"
    }

    $eventFile = Read-AddonPatchTextFile -Path $eventSourcePath
    $buttonFile = Read-AddonPatchTextFile -Path $buttonSourcePath
    $eventAlreadyPatched = $eventFile.Text.Contains($script:PatchMarker)
    $buttonAlreadyPatched = $buttonFile.Text.Contains($script:PingPatchMarker)
    $sourceHash = (Get-RareScannerSourceHash -Path $eventSourcePath).ToLowerInvariant()
    if ($eventAlreadyPatched -and $buttonAlreadyPatched) {
        Write-RareScannerAutoPatchLog -Message ("already patched: RareScanner {0}, event SHA256 {1}" -f $version, $sourceHash) -Quiet:$Quiet
        return [pscustomobject]@{ Status = "AlreadyPatched"; Version = $version; Hash = $sourceHash; Path = $eventSourcePath }
    }

    $eventContent = $eventFile.Text.Replace("`r`n", "`n")
    $buttonContent = $buttonFile.Text.Replace("`r`n", "`n")
    $deathOriginal = @'
local function OnUnitDeath(attackerUnitguid, targetUnitdead)
	if (not issecretvalue(targetUnitdead) and targetUnitdead) then
		local _, _, _, _, _, id = strsplit("-", targetUnitdead)
		local npcID = id and tonumber(id) or nil

		local npcInfo = RSNpcDB.GetInternalNpcInfo(npcID)
		if (npcInfo) then
			RSEntityStateHandler.SetDeadNpc(npcID)
			RSNpcDB.IncreaseTimesKilled(targetUnitdead)
		end
	end
end
'@.Trim()

    $deathPatched = @'
-- Yaya RareScanner AutoPatch: hide alert after rare kill
local function OnUnitDeath(rareScannerButton, _, targetUnitdead)
	if (not issecretvalue(targetUnitdead) and targetUnitdead) then
		local _, _, _, _, _, id = strsplit("-", targetUnitdead)
		local npcID = id and tonumber(id) or nil

		local npcInfo = RSNpcDB.GetInternalNpcInfo(npcID)
		if (npcInfo) then
			RSEntityStateHandler.SetDeadNpc(npcID)
			RSNpcDB.IncreaseTimesKilled(targetUnitdead)

			-- The secure button cannot always be hidden during combat. HideButton
			-- already defers that case until PLAYER_REGEN_ENABLED.
			if (rareScannerButton and rareScannerButton.entityID == npcID and RSConstants.IsNpcAtlas(rareScannerButton.atlasName)) then
				rareScannerButton:HideButton()
			end
		end
	end
end
'@.Trim()

    $dispatchOriginal = @'
	elseif (event == "PARTY_KILL") then
		OnUnitDeath(...)
'@.Trim()
    $dispatchPatched = @'
	elseif (event == "PARTY_KILL") then
		OnUnitDeath(rareScannerButton, ...)
'@.Trim()

    $changed = $false
    if (-not $eventAlreadyPatched) {
        $changed = (Replace-RareScannerBlock -Content ([ref]$eventContent) -Original $deathOriginal -Patched $deathPatched -Label "OnUnitDeath") -or $changed
        $changed = (Replace-RareScannerBlock -Content ([ref]$eventContent) -Original $dispatchOriginal -Patched $dispatchPatched -Label "PARTY_KILL dispatch") -or $changed
    }

    $pingOriginal = @'
local isInInstance, _ = IsInInstance()
	if (isInInstance) then
		local pingCmd = SLASH_PING1 or "/ping"
		macrotext = string.format("%s\n%s [@target]", macrotext, pingCmd)
	end
'@.Trim()
    $pingPatched = @'
-- Yaya RareScanner AutoPatch: ping alert target
	local pingCmd = SLASH_PING1 or "/ping"
	macrotext = string.format("%s\n%s [@target]", macrotext, pingCmd)
'@.Trim()
    if (-not $buttonAlreadyPatched) {
        $changed = (Replace-RareScannerBlock -Content ([ref]$buttonContent) -Original $pingOriginal -Patched $pingPatched -Label "ping macro") -or $changed
    }
    if (-not $changed) { throw "Le patch Rare Scanner n'a rien modifie." }

    $eventNewline = if ($eventFile.Text.Contains("`r`n")) { "`r`n" } else { "`n" }
    $buttonNewline = if ($buttonFile.Text.Contains("`r`n")) { "`r`n" } else { "`n" }
    $patchedEventText = $eventContent.Replace("`n", $eventNewline)
    $patchedButtonText = $buttonContent.Replace("`n", $buttonNewline)
    if ($DryRun) {
        Write-RareScannerAutoPatchLog -Message ("dry-run: RareScanner {0} needs patch, event SHA256 {1}" -f $version, $sourceHash) -Quiet:$Quiet
        return [pscustomobject]@{ Status = "NeedsPatch"; Version = $version; Hash = $sourceHash; Path = $eventSourcePath; Paths = @($eventSourcePath, $buttonSourcePath) }
    }

    $backupRoot = Join-Path ([Environment]::GetFolderPath("LocalApplicationData")) "YayaTools\RareScannerAutoPatch\backups"
    New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
    $safeVersion = $version -replace '[^A-Za-z0-9._-]', '_'
    $stamp = (Get-Date).ToString("yyyyMMdd-HHmmss")
    $backupPaths = New-Object System.Collections.Generic.List[string]
    if (-not $eventAlreadyPatched) {
        $eventBackupPath = Join-Path $backupRoot ("RSEventHandler.lua.{0}.{1}.bak" -f $safeVersion, $stamp)
        Copy-Item -LiteralPath $eventSourcePath -Destination $eventBackupPath -Force
        [void]$backupPaths.Add($eventBackupPath)
        Write-AddonPatchTextAtomically -Path $eventSourcePath -Text $patchedEventText -HasBom $eventFile.HasBom -Label "RSEventHandler.lua"
    }
    if (-not $buttonAlreadyPatched) {
        $buttonBackupPath = Join-Path $backupRoot ("RareScanner.lua.{0}.{1}.bak" -f $safeVersion, $stamp)
        Copy-Item -LiteralPath $buttonSourcePath -Destination $buttonBackupPath -Force
        [void]$backupPaths.Add($buttonBackupPath)
        Write-AddonPatchTextAtomically -Path $buttonSourcePath -Text $patchedButtonText -HasBom $buttonFile.HasBom -Label "RareScanner.lua"
    }
    $patchedHash = Get-RareScannerSourceHash -Path $eventSourcePath
    Write-RareScannerAutoPatchLog -Message ("patched RareScanner {0}: event {1} -> {2}; backups={3}" -f $version, $sourceHash, $patchedHash, ($backupPaths -join ",")) -Quiet:$Quiet
    return [pscustomobject]@{ Status = "Patched"; Version = $version; Hash = $patchedHash; Backup = $backupPaths[0]; Backups = $backupPaths.ToArray(); Path = $eventSourcePath; Paths = @($eventSourcePath, $buttonSourcePath) }
}
