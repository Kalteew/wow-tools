<#
.SYNOPSIS
    Tests de non-regression du moteur de patch TSM.

.DESCRIPTION
    Verifie les garde-fous du moteur de remplacement de blocs (unicite de
    l'ancrage, idempotence, expansion du marqueur de tabulation, validation de
    syntaxe Lua) sans jamais ecrire dans l'addon installe.

    Le dernier test, optionnel, execute un dry-run sur le TradeSkillMaster
    reellement installe : il ne modifie aucun fichier et signale simplement si
    un ancrage ne correspond plus a la version en place.

.EXAMPLE
    pwsh -NoProfile -File .\Test-TSMAutoPatch.ps1

.EXAMPLE
    pwsh -NoProfile -File .\Test-TSMAutoPatch.ps1 -SkipLiveDryRun
#>
param(
    [switch]$SkipLiveDryRun
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
$script:Backslash = [string][char]92
$script:Tab = [string][char]9

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

function Assert-Throws {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [Parameter(Mandatory = $true)]
        [scriptblock]$Action,
        [Parameter(Mandatory = $true)]
        [string]$ExpectedPattern
    )

    try {
        & $Action | Out-Null
        Assert-Test -Name $Name -Condition $false -Detail "aucune erreur levee"
    } catch {
        Assert-Test -Name $Name -Condition ($_.Exception.Message -like $ExpectedPattern) -Detail $_.Exception.Message
    }
}

Write-Host "Comptage d'occurrences" -ForegroundColor Cyan
Assert-Test -Name "aucune occurrence" -Condition ((Get-TSMPatchOccurrenceCount -Haystack "abc" -Needle "X") -eq 0)
Assert-Test -Name "deux occurrences" -Condition ((Get-TSMPatchOccurrenceCount -Haystack "aXbXc" -Needle "X") -eq 2)
Assert-Test -Name "occurrences chevauchantes comptees une fois" -Condition ((Get-TSMPatchOccurrenceCount -Haystack "aaaa" -Needle "aa") -eq 2)
Assert-Test -Name "aiguille vide" -Condition ((Get-TSMPatchOccurrenceCount -Haystack "abc" -Needle "") -eq 0)

Write-Host "Remplacement de bloc" -ForegroundColor Cyan
$content = "local a = 1`nlocal b = 2`n"
$changed = Replace-ExactBlock -Content ([ref]$content) -Original "local a = 1" -Patched "local a = 9" -Label "test"
Assert-Test -Name "ancrage unique applique" -Condition ($changed -and $content.Contains("local a = 9"))

$changed = Replace-ExactBlock -Content ([ref]$content) -Original "local a = 1" -Patched "local a = 9" -Label "test"
Assert-Test -Name "idempotence: second passage sans changement" -Condition (-not $changed)

$ambiguous = "local a = 1`nlocal a = 1`n"
Assert-Throws -Name "ancrage ambigu refuse" -ExpectedPattern "*Ambiguous anchor*2 matches*" -Action {
    Replace-ExactBlock -Content ([ref]$ambiguous) -Original "local a = 1" -Patched "local a = 2" -Label "test"
}

$missing = "local c = 3`n"
Assert-Throws -Name "ancrage absent refuse" -ExpectedPattern "*Unexpected code in test*" -Action {
    Replace-ExactBlock -Content ([ref]$missing) -Original "local a = 1" -Patched "local a = 2" -Label "test"
}

Write-Host "Marqueur de tabulation" -ForegroundColor Cyan
$content = "${script:Tab}x = 1`n"
$changed = Replace-ExactBlock -Content ([ref]$content) `
    -Original ($script:Backslash + "tx = 1") `
    -Patched ($script:Backslash + "tx = 2") `
    -Label "test"
Assert-Test -Name "marqueur expanse en tabulation reelle" -Condition ($changed -and $content.Contains($script:Tab + "x = 2"))

$luaString = 'local s = "a"' + "`n"
Assert-Throws -Name "marqueur dans une chaine Lua refuse" -ExpectedPattern "*Ambiguous tab marker*" -Action {
    Replace-ExactBlock -Content ([ref]$luaString) `
        -Original 'local s = "a"' `
        -Patched ('local s = "a' + $script:Backslash + 't"') `
        -Label "test"
}

Write-Host "Alternatives d'ancrage" -ForegroundColor Cyan
$content = "local second = 2`n"
$changed = Replace-ExactBlockAny -Content ([ref]$content) `
    -Originals @("local first = 1", "local second = 2") `
    -Patched "local patched = 3" `
    -Label "test"
Assert-Test -Name "seconde alternative retenue" -Condition ($changed -and $content.Contains("local patched = 3"))

# Un patch qui ajoute du code apres son ancrage laisse l'ancrage vierge present
# dans le resultat. Comme Replace-ExactBlockAny s'arrete au premier ancrage
# trouve, lister le vierge avant la generation precedente ajouterait le bloc une
# seconde fois. Les alternatives doivent aller de la plus recente a la plus
# ancienne.
$content = "local anchor = 1`nlocal added = 2`n"
$changed = Replace-ExactBlockAny -Content ([ref]$content) `
    -Originals @("local anchor = 1`nlocal added = 2", "local anchor = 1") `
    -Patched "local anchor = 1`nlocal added = 3" `
    -Label "test"
Assert-Test -Name "generation recente prioritaire sur l'ancrage vierge" `
    -Condition ($changed -and $content -eq "local anchor = 1`nlocal added = 3`n") -Detail $content

Write-Host "Validation de syntaxe Lua" -ForegroundColor Cyan
Assert-Test -Name "source valide acceptee" -Condition (Test-TSMPatchLuaSyntax -Content "local function f()`n`treturn 1`nend`n" -Label "test")
Assert-Test -Name "end manquant refuse" -Condition (-not (Test-TSMPatchLuaSyntax -Content "local function f()`n`treturn 1`n" -Label "test"))
Assert-Test -Name "end en trop refuse" -Condition (-not (Test-TSMPatchLuaSyntax -Content "local function f()`nend`nend`n" -Label "test"))
Assert-Test -Name "chaine non fermee refusee" -Condition (-not (Test-TSMPatchLuaSyntax -Content "local s = `"abc`n" -Label "test"))
Assert-Test -Name "commentaire long ignore" -Condition (Test-TSMPatchLuaSyntax -Content "--[[ function end end ]]`nlocal a = 1`n" -Label "test")
Assert-Test -Name "mot-cle en sous-chaine ignore" -Condition (Test-TSMPatchLuaSyntax -Content "local sendMail = 1`nlocal theend = 2`n" -Label "test")
# Regression : TSM definit une methode :If(). PowerShell comparant les chaines
# sans tenir compte de la casse, "If" etait compte comme le mot-cle "if" et
# faisait echouer 20 fichiers TSM sur 530.
Assert-Test -Name "identifiant If (casse) non confondu avec if" -Condition (Test-TSMPatchLuaSyntax -Content "local x = t:If(a or b)`n" -Label "test")
Assert-Test -Name "identifiant End (casse) non confondu avec end" -Condition (-not (Test-TSMPatchLuaSyntax -Content "if a then`n`tt:End()`n" -Label "test"))
Assert-Test -Name "chaine longue ignoree" -Condition (Test-TSMPatchLuaSyntax -Content "local s = [[ function if do ]]`n" -Label "test")
Assert-Test -Name "for in do end equilibre" -Condition (Test-TSMPatchLuaSyntax -Content "for k, v in pairs(t) do`n`tprint(k)`nend`n" -Label "test")
Assert-Test -Name "repeat until sans end" -Condition (Test-TSMPatchLuaSyntax -Content "repeat`n`ta = a + 1`nuntil a > 3`n" -Label "test")
Assert-Test -Name "elseif ne compte pas comme bloc" -Condition (Test-TSMPatchLuaSyntax -Content "if a then`nelseif b then`nelse`nend`n" -Label "test")

if (-not $SkipLiveDryRun) {
    Write-Host "Dry-run sur le TSM installe" -ForegroundColor Cyan
    try {
        $result = Invoke-TSMMailingPatch -DryRun -Quiet
        Assert-Test -Name "dry-run sans exception" -Condition $true
        Write-Host ("        version={0} statut={1}" -f $result.Version, $result.Status)
        if ($result.FailedPatches -and $result.FailedPatches.Count -gt 0) {
            Write-Host ("        {0} patch(s) sans ancrage valide :" -f $result.FailedPatches.Count) -ForegroundColor Yellow
            foreach ($failure in $result.FailedPatches) {
                Write-Host ("          - {0}: {1}" -f $failure.Name, $failure.Error) -ForegroundColor Yellow
            }
        }
    } catch {
        Assert-Test -Name "dry-run sans exception" -Condition $false -Detail $_.Exception.Message
    }
}

Write-Host ""
if ($script:TestOutputPath -and (Test-Path -LiteralPath $script:TestOutputPath)) {
    Remove-Item -LiteralPath $script:TestOutputPath -Recurse -Force -ErrorAction SilentlyContinue
}
Set-TSMAutoPatchOutputPath -Path $null

Write-Host ("{0} reussis, {1} echoues" -f $script:Passed, $script:Failed) -ForegroundColor $(if ($script:Failed -eq 0) { "Green" } else { "Red" })
if ($script:Failed -gt 0) {
    exit 1
}
