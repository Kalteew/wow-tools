<#
.SYNOPSIS
    Tests de scenario du patch TSM sur une copie jetable de l'addon.

.DESCRIPTION
    Copie l'installation TradeSkillMaster dans un dossier temporaire, puis y
    simule les pannes reelles observees dans le journal :

      - un fichier cible supprime par une mise a jour de l'addon (incident du
        2026-08-23 sur Locale\*.lua, qui faisait echouer la totalite du patch) ;
      - un ancrage devenu introuvable (les 118 echecs consecutifs sur
        Core\API.lua) : les autres patchs doivent continuer a s'appliquer ;
      - un ancrage present en double, qui patcherait plusieurs endroits ;
      - un fichier structurel manquant, qui doit lever une erreur lisible ;
      - une transaction produisant du Lua invalide, qui ne doit rien ecrire.

    L'installation reelle n'est jamais modifiee.

.EXAMPLE
    pwsh -NoProfile -File .\Test-TSMAutoPatchScenarios.ps1
#>
param(
    [string]$AddonPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "TSMAutoPatch.Common.ps1")

# Journal et fichier d'etat rediriges : les tests ne doivent pas polluer
# le diagnostic de l'installation reelle.
$script:TestOutputPath = Join-Path ([System.IO.Path]::GetTempPath()) ("tsm-patch-test-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $script:TestOutputPath -Force | Out-Null
Set-TSMAutoPatchOutputPath -Path $script:TestOutputPath

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

$source = Resolve-TSMAddonPath -AddonPath $AddonPath
$sandboxRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("tsm-patch-scenarios-" + [guid]::NewGuid().ToString("N"))

function New-Sandbox {
    <#
        Chaque scenario part d'une copie neuve : un patch applique dans un
        scenario ne doit pas influencer le suivant.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    $parent = Join-Path $sandboxRoot $Name
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
    # -LiteralPath sur le dossier lui-meme : le chemin source contient "(x86)",
    # qu'un -Path avec joker interpreterait.
    Copy-Item -LiteralPath $source -Destination $parent -Recurse -Force
    return (Join-Path $parent (Split-Path -Leaf $source))
}

try {
    Write-Host ("Source  : {0}" -f $source)
    Write-Host ("Sandbox : {0}" -f $sandboxRoot)
    Write-Host ""

    Write-Host "Scenario 1 - fichier optionnel supprime (incident Locale\*.lua)" -ForegroundColor Cyan
    $sandbox = New-Sandbox -Name "missing-optional"
    Remove-Item -LiteralPath (Join-Path $sandbox "Locale\frFR.lua") -Force
    Remove-Item -LiteralPath (Join-Path $sandbox "Locale\deDE.lua") -Force
    try {
        $result = Invoke-TSMMailingPatch -AddonPath $sandbox -DryRun -Quiet
        Assert-Test -Name "le patch ne leve pas d'exception" -Condition $true
        $skippedNames = @($result.SkippedPatches | ForEach-Object { $_.Name })
        Assert-Test -Name "les deux locales absentes sont sautees" `
            -Condition (($skippedNames -contains "Locale frFR") -and ($skippedNames -contains "Locale deDE")) `
            -Detail ($skippedNames -join ", ")
        Assert-Test -Name "les autres patchs sont bien evalues" `
            -Condition ($result.AppliedPatches.Count -ge 15) `
            -Detail "appliques=$($result.AppliedPatches.Count)"
        Assert-Test -Name "aucun patch en echec" -Condition ($result.FailedPatches.Count -eq 0) `
            -Detail (($result.FailedPatches | ForEach-Object { $_.Name }) -join ", ")
    } catch {
        Assert-Test -Name "le patch ne leve pas d'exception" -Condition $false -Detail $_.Exception.Message
    }

    Write-Host "Scenario 2 - ancrage introuvable (incident Core\API.lua)" -ForegroundColor Cyan
    $sandbox = New-Sandbox -Name "broken-anchor"
    $apiFile = Join-Path $sandbox "Core\API.lua"
    $apiText = [System.IO.File]::ReadAllText($apiFile)
    # On casse a la fois la forme patchee et la forme d'origine pour forcer un
    # echec d'ancrage, comme apres une refonte du fichier en amont.
    $apiText = $apiText.Replace("local Money = TSM.LibTSMUtil:Include(", "local Money = TSM.LibTSMUtil:IncludeRenamed(")
    [System.IO.File]::WriteAllText($apiFile, $apiText)
    try {
        $result = Invoke-TSMMailingPatch -AddonPath $sandbox -DryRun -Quiet
        Assert-Test -Name "le patch ne leve pas d'exception" -Condition $true
        $failedNames = @($result.FailedPatches | ForEach-Object { $_.Name })
        Assert-Test -Name "le patch API est signale en echec" -Condition ($failedNames -contains "API hooks") `
            -Detail ($failedNames -join ", ")
        Assert-Test -Name "les autres patchs continuent" -Condition ($result.AppliedPatches.Count -ge 15) `
            -Detail "appliques=$($result.AppliedPatches.Count)"
        Assert-Test -Name "le statut mentionne l'echec" -Condition ($result.Status -like "*failed patch*") `
            -Detail $result.Status
    } catch {
        Assert-Test -Name "le patch ne leve pas d'exception" -Condition $false -Detail $_.Exception.Message
    }

    Write-Host "Scenario 3 - fichier structurel manquant" -ForegroundColor Cyan
    $sandbox = New-Sandbox -Name "missing-required"
    Remove-Item -LiteralPath (Join-Path $sandbox "Core\API.lua") -Force
    try {
        Invoke-TSMMailingPatch -AddonPath $sandbox -DryRun -Quiet | Out-Null
        Assert-Test -Name "une erreur est levee" -Condition $false -Detail "aucune erreur"
    } catch {
        $message = $_.Exception.Message
        Assert-Test -Name "une erreur est levee" -Condition $true
        Assert-Test -Name "l'erreur nomme le fichier manquant" -Condition ($message -like "*Core\API.lua*") -Detail $message
        Assert-Test -Name "l'erreur reste lisible (une cible par ligne)" `
            -Condition (($message -split "`n").Count -le 4) `
            -Detail "$(($message -split "`n").Count) ligne(s)"
        Stop-TSMPatchTransaction
    }

    Write-Host "Scenario 4 - ancrage present en double" -ForegroundColor Cyan
    $content = "local Money = 1`nlocal Money = 1`n"
    try {
        Replace-ExactBlock -Content ([ref]$content) -Original "local Money = 1" -Patched "local Money = 2" -Label "double" | Out-Null
        Assert-Test -Name "l'ancrage ambigu est refuse" -Condition $false -Detail "aucune erreur"
    } catch {
        Assert-Test -Name "l'ancrage ambigu est refuse" -Condition ($_.Exception.Message -like "*Ambiguous anchor*") -Detail $_.Exception.Message
    }

    Write-Host "Scenario 5 - transaction produisant du Lua invalide" -ForegroundColor Cyan
    $sandbox = New-Sandbox -Name "invalid-lua"
    $targetFile = Join-Path $sandbox "Core\API.lua"
    $before = [System.IO.File]::ReadAllBytes($targetFile)
    Start-TSMPatchTransaction -AddonPath $sandbox -FilePaths @($targetFile)
    try {
        $broken = (Get-TSMPatchContent -FilePath $targetFile) + "`nfunction Oops()`n"
        Set-TSMPatchContent -FilePath $targetFile -Content $broken
        Complete-TSMPatchTransaction | Out-Null
        Assert-Test -Name "la transaction est refusee" -Condition $false -Detail "aucune erreur"
    } catch {
        Assert-Test -Name "la transaction est refusee" -Condition ($_.Exception.Message -like "*invalid Lua*") -Detail $_.Exception.Message
        $after = [System.IO.File]::ReadAllBytes($targetFile)
        Assert-Test -Name "le fichier n'a pas ete modifie" `
            -Condition ([System.Linq.Enumerable]::SequenceEqual([byte[]]$before, [byte[]]$after))
    } finally {
        Stop-TSMPatchTransaction
    }

    Write-Host "Scenario 6 - cycle d'alerte sur echec persistant" -ForegroundColor Cyan
    $sandbox = New-Sandbox -Name "alert-cycle"
    $apiFile = Join-Path $sandbox "Core\API.lua"
    $intact = [System.IO.File]::ReadAllText($apiFile)
    $broken = $intact.Replace("local Money = TSM.LibTSMUtil:Include(", "local Money = TSM.LibTSMUtil:IncludeRenamed(")
    $tracker = New-TSMAutoPatchRunTracker

    [System.IO.File]::WriteAllText($apiFile, $broken)
    $run = Invoke-TSMAutoPatchRun -AddonPath $sandbox -Tracker $tracker -Origin "test" -AlertThreshold 2 -Notify $false -DryRun
    Assert-Test -Name "1er echec: compte a 1, pas d'alerte" `
        -Condition (($tracker.FailureCounts["API hooks"] -eq 1) -and ($run.Notifications.Count -eq 0)) `
        -Detail "count=$($tracker.FailureCounts['API hooks']) notifs=$($run.Notifications.Count)"

    $run = Invoke-TSMAutoPatchRun -AddonPath $sandbox -Tracker $tracker -Origin "test" -AlertThreshold 2 -Notify $false -DryRun
    Assert-Test -Name "2e echec: seuil atteint, une alerte" `
        -Condition ((@($run.Notifications | Where-Object { $_.Kind -eq "failed" })).Count -eq 1) `
        -Detail "notifs=$($run.Notifications.Count)"

    $run = Invoke-TSMAutoPatchRun -AddonPath $sandbox -Tracker $tracker -Origin "test" -AlertThreshold 2 -Notify $false -DryRun
    Assert-Test -Name "3e echec: pas d'alerte repetee" -Condition ($run.Notifications.Count -eq 0) `
        -Detail "notifs=$($run.Notifications.Count)"

    [System.IO.File]::WriteAllText($apiFile, $intact)
    $run = Invoke-TSMAutoPatchRun -AddonPath $sandbox -Tracker $tracker -Origin "test" -AlertThreshold 2 -Notify $false -DryRun
    Assert-Test -Name "retablissement: compteur remis a zero et alerte levee" `
        -Condition ((-not $tracker.FailureCounts.ContainsKey("API hooks")) -and ((@($run.Notifications | Where-Object { $_.Kind -eq "recovered" })).Count -eq 1)) `
        -Detail "restants=$($tracker.FailureCounts.Keys -join ',') notifs=$($run.Notifications.Count)"

    Remove-Item -LiteralPath $apiFile -Force
    $run = Invoke-TSMAutoPatchRun -AddonPath $sandbox -Tracker $tracker -Origin "test" -AlertThreshold 2 -Notify $false -DryRun
    Assert-Test -Name "erreur fatale: capturee et notifiee une fois" `
        -Condition (($null -ne $run.FatalError) -and ((@($run.Notifications | Where-Object { $_.Kind -eq "fatal" })).Count -eq 1)) `
        -Detail "fatal=$($run.FatalError)"

} finally {
    foreach ($path in @($sandboxRoot, $script:TestOutputPath)) {
        if ($path -and (Test-Path -LiteralPath $path)) {
            Remove-Item -LiteralPath $path -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    Set-TSMAutoPatchOutputPath -Path $null
}

Write-Host ""
Write-Host ("{0} reussis, {1} echoues" -f $script:Passed, $script:Failed) -ForegroundColor $(if ($script:Failed -eq 0) { "Green" } else { "Red" })
if ($script:Failed -gt 0) {
    exit 1
}
