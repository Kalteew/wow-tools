Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Primitives communes aux auto-patchs (validation Lua, ecriture atomique,
# rotation du journal, notifications, suivi des echecs).
. (Join-Path $PSScriptRoot "..\lib\AddonPatchCore.ps1")

$script:TaskName = "WQT Auto Patch Watcher"
$script:WatcherMutexName = "Local\WQTAutoPatchWatcher"
$script:StartupLauncherName = "WQT Auto Patch Watcher.vbs"
$script:PatchMarker = "Yaya WQT AutoPatch: deferred ObjectiveTrackerManager hooks"

function Get-WQTAutoPatchLogPath {
    return (Resolve-AddonPatchOutputPath -DefaultDirectory $PSScriptRoot -FileName "wqt-auto-patch.log")
}

function Get-WQTAutoPatchStartupPath {
    $startup = [Environment]::GetFolderPath("Startup")
    return (Join-Path $startup $script:StartupLauncherName)
}

function Write-WQTAutoPatchLog {
    param(
        [Parameter(Mandatory = $true)][string]$Message,
        [switch]$Quiet
    )

    $logPath = Get-WQTAutoPatchLogPath
    New-Item -ItemType Directory -Path (Split-Path -Parent $logPath) -Force | Out-Null
    try {
        Invoke-AddonPatchLogRotation -LogPath $logPath
    } catch {
        # Une rotation qui echoue ne doit jamais empecher d'ecrire la ligne.
    }
    Add-Content -LiteralPath $logPath -Value ("[{0}] {1}" -f (Get-Date).ToString("s"), $Message) -Encoding UTF8
    if (-not $Quiet) {
        Write-Host $Message
    }
}

function Get-WQTAddonCandidates {
    $candidates = New-Object System.Collections.Generic.List[string]
    $programFilesX86 = [Environment]::GetEnvironmentVariable("ProgramFiles(x86)")
    $programFiles = [Environment]::GetEnvironmentVariable("ProgramFiles")

    foreach ($root in @($programFilesX86, $programFiles)) {
        if ($root) {
            $candidates.Add((Join-Path $root "World of Warcraft\_retail_\Interface\AddOns\WorldQuestTracker"))
        }
    }

    $candidates.Add("C:\Program Files (x86)\World of Warcraft\_retail_\Interface\AddOns\WorldQuestTracker")
    $candidates.Add("C:\Program Files\World of Warcraft\_retail_\Interface\AddOns\WorldQuestTracker")
    return $candidates
}

function Resolve-WQTAddonPath {
    param([string]$AddonPath)

    if ($AddonPath) {
        $resolved = (Resolve-Path -LiteralPath $AddonPath -ErrorAction Stop).Path
        if (-not (Test-Path -LiteralPath (Join-Path $resolved "WorldQuestTracker.toc") -PathType Leaf)) {
            throw "WQT addon invalide: $resolved"
        }
        return $resolved
    }

    foreach ($candidate in (Get-WQTAddonCandidates)) {
        if (Test-Path -LiteralPath (Join-Path $candidate "WorldQuestTracker.toc") -PathType Leaf) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }

    throw "WorldQuestTracker introuvable. Passez -AddonPath explicitement."
}

function Get-WQTAddonVersion {
    param([Parameter(Mandatory = $true)][string]$AddonPath)

    $tocPath = Join-Path $AddonPath "WorldQuestTracker.toc"
    $versionLine = Get-Content -LiteralPath $tocPath -ErrorAction Stop |
        Where-Object { $_ -match '^##\s*Version:\s*(.+)$' } |
        Select-Object -First 1
    if ($versionLine -and $versionLine -match '^##\s*Version:\s*(.+)$') {
        return $Matches[1].Trim()
    }
    return "unknown"
}

function Read-WQTTextFile {
    param([Parameter(Mandatory = $true)][string]$Path)

    $bytes = [IO.File]::ReadAllBytes($Path)
    $hasBom = $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
    $offset = if ($hasBom) { 3 } else { 0 }
    $encoding = New-Object System.Text.UTF8Encoding($false)
    $text = $encoding.GetString($bytes, $offset, $bytes.Length - $offset)
    return [pscustomobject]@{
        Text = $text
        HasBom = $hasBom
    }
}

function Write-WQTTextFileAtomically {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Text,
        [Parameter(Mandatory = $true)][bool]$HasBom
    )

    # Delegue a la primitive partagee : elle refuse d'ecrire un Lua dont la
    # syntaxe est incoherente et remplace le fichier via File::Replace.
    Write-AddonPatchTextAtomically -Path $Path -Text $Text -HasBom $HasBom -Label (Split-Path -Leaf $Path)
}

function Get-WQTSourceHash {
    param([Parameter(Mandatory = $true)][string]$Path)
    $sha256 = [Security.Cryptography.SHA256]::Create()
    try {
        return ([BitConverter]::ToString($sha256.ComputeHash([IO.File]::ReadAllBytes($Path)))).Replace("-", "")
    } finally {
        $sha256.Dispose()
    }
}

function Invoke-WQTAutoPatch {
    param(
        [string]$AddonPath,
        [switch]$Quiet,
        [switch]$DryRun
    )

    $resolvedAddonPath = Resolve-WQTAddonPath -AddonPath $AddonPath
    $version = Get-WQTAddonVersion -AddonPath $resolvedAddonPath
    $sourcePath = Join-Path $resolvedAddonPath "WorldQuestTracker_Tracker.lua"
    if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
        throw "Fichier WQT introuvable: $sourcePath"
    }

    $sourceHash = Get-WQTSourceHash -Path $sourcePath
    $file = Read-WQTTextFile -Path $sourcePath
    if ($file.Text.Contains($script:PatchMarker)) {
        Write-WQTAutoPatchLog -Message ("already patched: WQT {0}, SHA256 {1}" -f $version, $sourceHash) -Quiet:$Quiet
        return [pscustomobject]@{ Status = "AlreadyPatched"; Version = $version; Hash = $sourceHash; Path = $sourcePath }
    }

    $text = $file.Text.Replace("`r`n", "`n")
    $pattern = '(?m)^hooksecurefunc\(ObjectiveTrackerManager, "UpdateAll", function\(\)\n[ \t]+On_ObjectiveTracker_Update\(\)(?:[ \t]+--v11)?\nend\)\nhooksecurefunc\(ObjectiveTrackerManager, "UpdateModule", function\(\)\n[ \t]+On_ObjectiveTracker_Update\(\)(?:[ \t]+--v11)?\nend\)'
    # $matches est une variable automatique de PowerShell : on utilise un nom
    # propre pour eviter toute collision avec l'operateur -match.
    $blockMatches = [regex]::Matches($text, $pattern)
    if ($blockMatches.Count -ne 1) {
        throw ("Bloc WQT attendu introuvable ou ambigu (matches={0}, version={1}, SHA256={2})." -f $blockMatches.Count, $version, $sourceHash)
    }

    $replacement = @"
-- $($script:PatchMarker)
-- Run after Blizzard finishes rebuilding the native objective tracker and coalesce
-- UpdateAll/UpdateModule bursts from Retail's ObjectiveTrackerManager.
local wqtObjectiveTrackerUpdatePending = false
local ScheduleWQTObjectiveTrackerUpdate = function()
    if (wqtObjectiveTrackerUpdatePending) then
        return
    end
    wqtObjectiveTrackerUpdatePending = true
    C_Timer.After(0, function()
        wqtObjectiveTrackerUpdatePending = false
        local ok, err = pcall(On_ObjectiveTracker_Update)
        if (not ok) then
            print("|cFFFFAA00World Quest Tracker AutoPatch|r: " .. tostring(err))
        end
    end)
end

hooksecurefunc(ObjectiveTrackerManager, "UpdateAll", ScheduleWQTObjectiveTrackerUpdate)
hooksecurefunc(ObjectiveTrackerManager, "UpdateModule", ScheduleWQTObjectiveTrackerUpdate)
"@.Trim()
    $replacement = $replacement.Replace("`r`n", "`n")

    $match = $blockMatches[0]
    $patchedText = $text.Remove($match.Index, $match.Length).Insert($match.Index, $replacement)
    $newline = if ($file.Text.Contains("`r`n")) { "`r`n" } else { "`n" }
    $patchedText = $patchedText.Replace("`n", $newline)

    if ($DryRun) {
        Write-WQTAutoPatchLog -Message ("dry-run: WQT {0} needs patch, SHA256 {1}" -f $version, $sourceHash) -Quiet:$Quiet
        return [pscustomobject]@{ Status = "NeedsPatch"; Version = $version; Hash = $sourceHash; Path = $sourcePath }
    }

    $backupRoot = Join-Path ([Environment]::GetFolderPath("LocalApplicationData")) "YayaTools\WQTAutoPatch\backups"
    New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
    $safeVersion = $version -replace '[^A-Za-z0-9._-]', '_'
    $backupPath = Join-Path $backupRoot ("WorldQuestTracker_Tracker.lua.{0}.{1}.bak" -f $safeVersion, (Get-Date).ToString("yyyyMMdd-HHmmss"))
    Copy-Item -LiteralPath $sourcePath -Destination $backupPath -Force

    Write-WQTTextFileAtomically -Path $sourcePath -Text $patchedText -HasBom $file.HasBom
    $patchedHash = Get-WQTSourceHash -Path $sourcePath
    Write-WQTAutoPatchLog -Message ("patched WQT {0}: {1} -> {2}; backup={3}" -f $version, $sourceHash, $patchedHash, $backupPath) -Quiet:$Quiet
    return [pscustomobject]@{ Status = "Patched"; Version = $version; Hash = $patchedHash; Backup = $backupPath; Path = $sourcePath }
}
