<#
.SYNOPSIS
    Test du patch AbundanceTracker sur une copie jetable de l'addon.

.DESCRIPTION
    Verifie le chemin d'ecriture complet, qu'un dry-run ne peut pas couvrir :

      - le Core.lua de l'installation, tel quel, aboutit a un fichier portant
        tous les marqueurs, y compris quand il est deja patche par une version
        anterieure du script et que ses ancres d'origine ont disparu ;
      - un Core.lua non patche (repris d'une sauvegarde d'avant patch) est
        patche sans erreur et le resultat est du Lua syntaxiquement coherent ;
      - un second passage est idempotent ;
      - un ancrage present en double est refuse ;
      - une source Lua incoherente est refusee avant ecriture, le fichier
        restant intact.

    L'installation reelle n'est jamais modifiee.

.EXAMPLE
    pwsh -NoProfile -File .\Test-AbundanceTrackerAutoPatch.ps1
#>
param(
    [string]$AddonPath,
    # Core.lua d'avant patch ; par defaut la sauvegarde la plus recente ecrite
    # par le patch lui-meme.
    [string]$UnpatchedCorePath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "AbundanceTrackerAutoPatch.Common.ps1")

# Journal redirige : les tests ne doivent pas polluer le diagnostic de
# l'installation reelle.
$script:TestOutputPath = Join-Path ([System.IO.Path]::GetTempPath()) ("abundance-patch-test-log-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $script:TestOutputPath -Force | Out-Null
Set-AddonPatchOutputPath -Path $script:TestOutputPath

$script:Passed = 0
$script:Failed = 0

function Assert-Test {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [Parameter(Mandatory = $true)]
        [bool]$Condition,
        [string]$Detail
    )

    if ($Condition) {
        $script:Passed++
        Write-Host ("  OK    {0}" -f $Name) -ForegroundColor Green
    } else {
        $script:Failed++
        Write-Host ("  ECHEC {0}{1}" -f $Name, $(if ($Detail) { " -> $Detail" } else { "" })) -ForegroundColor Red
    }
}

function Get-MarkerCount {
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        [Parameter(Mandatory = $true)][string]$Marker
    )

    return ([regex]::Matches($Text, [regex]::Escape($Marker))).Count
}

# Un marqueur en double signale un bloc reinsere par-dessus lui-meme : le Lua
# reste syntaxiquement valide et la verification de syntaxe ne voit rien, mais
# les fonctions concernees sont definies deux fois.
function Assert-MarkersUnique {
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        [Parameter(Mandatory = $true)][string]$Case
    )

    $aura = Get-MarkerCount -Text $Text -Marker $script:PatchMarker
    $visibility = Get-MarkerCount -Text $Text -Marker $script:VisibilityPatchMarker
    $combatLog = Get-MarkerCount -Text $Text -Marker $script:CombatLogPatchMarker
    Assert-Test -Name ("aucun bloc duplique ({0})" -f $Case) `
        -Condition ($aura -eq 1 -and $visibility -eq 1 -and $combatLog -eq 1) `
        -Detail ("aura={0}, visibilite={1}, combat log={2}" -f $aura, $visibility, $combatLog)
}

$source = Resolve-AbundanceTrackerAddonPath -AddonPath $AddonPath
$sandboxRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("abundance-patch-test-" + [guid]::NewGuid().ToString("N"))

if (-not $UnpatchedCorePath) {
    $backupRoot = Join-Path ([Environment]::GetFolderPath("LocalApplicationData")) "YayaTools\AbundanceTrackerAutoPatch\backups"
    $candidate = Get-ChildItem -LiteralPath $backupRoot -Filter "Core.lua.*.bak" -File -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
    if ($candidate) {
        $UnpatchedCorePath = $candidate.FullName
    }
}

try {
    Write-Host ("Source  : {0}" -f $source)
    Write-Host ("Sandbox : {0}" -f $sandboxRoot)
    Write-Host ""

    New-Item -ItemType Directory -Path $sandboxRoot -Force | Out-Null
    Copy-Item -LiteralPath $source -Destination $sandboxRoot -Recurse -Force
    $sandbox = Join-Path $sandboxRoot (Split-Path -Leaf $source)
    $corePath = Join-Path $sandbox "Core.lua"

    # Etat reel de l'installation, teste avant tout remplacement par une
    # sauvegarde vierge. C'est le cas le plus delicat : le fichier peut deja
    # etre patche par une version anterieure du script, ses ancres d'origine
    # ayant alors disparu. On verifie l'etat final plutot que le chemin
    # emprunte, pour que le test vaille aussi bien sur une installation deja a
    # jour que sur une installation en retard d'une famille de blocs.
    Write-Host "Patch de l'installation telle quelle" -ForegroundColor Cyan
    $liveResult = Invoke-AbundanceTrackerAutoPatch -AddonPath $sandbox -Quiet
    Assert-Test -Name "le patch aboutit" `
        -Condition ($liveResult.Status -in @("Patched", "AlreadyPatched")) -Detail $liveResult.Status

    $liveText = [System.IO.File]::ReadAllText($corePath)
    Assert-Test -Name "le resultat est du Lua coherent" `
        -Condition (Test-AddonPatchLuaSyntax -Content $liveText -Label "Core.lua") `
        -Detail (Get-AddonPatchLastLuaError)
    Assert-Test -Name "COMBAT_LOG_EVENT_UNFILTERED quitte ALL_EVENTS" `
        -Condition (-not $liveText.Contains('"UNIT_SPELLCAST_SUCCEEDED","COMBAT_LOG_EVENT_UNFILTERED",'))
    Assert-Test -Name "le marqueur combat log est pose" `
        -Condition ($liveText.Contains($script:CombatLogPatchMarker))
    Assert-MarkersUnique -Text $liveText -Case "installation telle quelle"

    # Repasser une seconde fois ne doit rien reecrire : c'est la garantie que le
    # watcher, qui repasse toutes les 30 minutes, n'empile pas les blocs.
    $liveAgain = Invoke-AbundanceTrackerAutoPatch -AddonPath $sandbox -Quiet
    Assert-Test -Name "second passage idempotent" `
        -Condition ($liveAgain.Status -eq "AlreadyPatched") -Detail $liveAgain.Status
    Assert-MarkersUnique -Text ([System.IO.File]::ReadAllText($corePath)) -Case "apres second passage"
    Write-Host ""

    if ($UnpatchedCorePath -and (Test-Path -LiteralPath $UnpatchedCorePath)) {
        Write-Host "Patch reel sur un Core.lua non patche" -ForegroundColor Cyan
        Copy-Item -LiteralPath $UnpatchedCorePath -Destination $corePath -Force

        $result = Invoke-AbundanceTrackerAutoPatch -AddonPath $sandbox -Quiet
        Assert-Test -Name "le patch s'applique" -Condition ($result.Status -eq "Patched") -Detail $result.Status

        $patched = [System.IO.File]::ReadAllText($corePath)
        Assert-Test -Name "le resultat est du Lua coherent" `
            -Condition (Test-AddonPatchLuaSyntax -Content $patched -Label "Core.lua") `
            -Detail (Get-AddonPatchLastLuaError)
        Assert-Test -Name "plus aucune lecture GetAuraDataByIndex" -Condition (-not $patched.Contains("GetAuraDataByIndex"))
        Assert-Test -Name "COMBAT_LOG_EVENT_UNFILTERED quitte ALL_EVENTS" `
            -Condition (-not $patched.Contains('"UNIT_SPELLCAST_SUCCEEDED","COMBAT_LOG_EVENT_UNFILTERED",'))
        Assert-Test -Name "le marqueur combat log est pose" `
            -Condition ($patched.Contains($script:CombatLogPatchMarker))
        Assert-MarkersUnique -Text $patched -Case "depuis un fichier vierge"

        $again = Invoke-AbundanceTrackerAutoPatch -AddonPath $sandbox -Quiet
        Assert-Test -Name "second passage idempotent" -Condition ($again.Status -eq "AlreadyPatched") -Detail $again.Status
    } else {
        Write-Host "Patch reel : ignore, aucun Core.lua non patche disponible" -ForegroundColor Yellow
        Write-Host "  (indiquer -UnpatchedCorePath pour couvrir ce cas)" -ForegroundColor Yellow
    }

    Write-Host "Garde-fous du moteur de remplacement" -ForegroundColor Cyan
    $doubled = "local a = 1`nlocal a = 1`n"
    try {
        Replace-AbundanceTrackerBlock -Content ([ref]$doubled) -Original "local a = 1" -Patched "local a = 2" -Label "double" | Out-Null
        Assert-Test -Name "ancrage ambigu refuse" -Condition $false -Detail "aucune erreur"
    } catch {
        Assert-Test -Name "ancrage ambigu refuse" -Condition ($_.Exception.Message -like "*ambigu*") -Detail $_.Exception.Message
    }

    $absent = "local b = 2`n"
    try {
        Replace-AbundanceTrackerBlock -Content ([ref]$absent) -Original "local a = 1" -Patched "local a = 2" -Label "absent" | Out-Null
        Assert-Test -Name "ancrage absent refuse" -Condition $false -Detail "aucune erreur"
    } catch {
        Assert-Test -Name "ancrage absent refuse" -Condition ($_.Exception.Message -like "*introuvable*") -Detail $_.Exception.Message
    }

    Write-Host "Refus d'ecrire du Lua invalide" -ForegroundColor Cyan
    $probe = Join-Path $sandboxRoot "probe.lua"
    [System.IO.File]::WriteAllText($probe, "local a = 1`n")
    $before = [System.IO.File]::ReadAllBytes($probe)
    try {
        Write-AbundanceTrackerTextFileAtomically -Path $probe -Text "function Oops()`n" -HasBom $false
        Assert-Test -Name "l'ecriture est refusee" -Condition $false -Detail "aucune erreur"
    } catch {
        Assert-Test -Name "l'ecriture est refusee" -Condition ($_.Exception.Message -like "*Lua invalide*") -Detail $_.Exception.Message
        $after = [System.IO.File]::ReadAllBytes($probe)
        Assert-Test -Name "le fichier est intact" -Condition ([System.Linq.Enumerable]::SequenceEqual([byte[]]$before, [byte[]]$after))
    }

    Write-Host "Ecriture valide acceptee" -ForegroundColor Cyan
    Write-AbundanceTrackerTextFileAtomically -Path $probe -Text "local a = 2`n" -HasBom $false
    Assert-Test -Name "le contenu valide est ecrit" -Condition ([System.IO.File]::ReadAllText($probe).Contains("local a = 2"))

} finally {
    if (Test-Path -LiteralPath $sandboxRoot) {
        Remove-Item -LiteralPath $sandboxRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Write-Host ""
if ($script:TestOutputPath -and (Test-Path -LiteralPath $script:TestOutputPath)) {
    Remove-Item -LiteralPath $script:TestOutputPath -Recurse -Force -ErrorAction SilentlyContinue
}
Set-AddonPatchOutputPath -Path $null

Write-Host ("{0} reussis, {1} echoues" -f $script:Passed, $script:Failed) -ForegroundColor $(if ($script:Failed -eq 0) { "Green" } else { "Red" })
if ($script:Failed -gt 0) {
    exit 1
}
