<#
.SYNOPSIS
    Valide les addons Lua du depot : syntaxe puis tests unitaires.

.DESCRIPTION
    Deux niveaux de verification :

      1. Syntaxe. Avec luac (Lua 5.1, la version du client WoW), chaque fichier
         est reellement compile : c'est le seul controle qui attrape une vraie
         erreur de syntaxe, un depassement de la limite de 200 variables
         locales par chunk, ou un bloc mal ferme. Sans luac, on retombe sur le
         controle d'equilibrage de scripts/lib/AddonPatchCore.ps1, nettement
         plus faible.

      2. Tests unitaires. Tout fichier addons/**/Tests/test_*.lua est execute
         avec l'interpreteur, depuis le dossier de son addon.

    Lua 5.1 pour Windows se recupere sur LuaBinaries
    (https://luabinaries.sourceforge.net), archive "Tools Executables". Aucune
    installation n'est necessaire : il suffit de pointer -LuaPath vers le
    dossier decompresse.

.PARAMETER LuaPath
    Dossier contenant lua5.1.exe et luac5.1.exe. A defaut, ils sont cherches
    dans le PATH.

.EXAMPLE
    pwsh -NoProfile -File .\Test-Addons.ps1

.EXAMPLE
    pwsh -NoProfile -File .\Test-Addons.ps1 -LuaPath C:\outils\lua
#>
param(
    [string]$LuaPath,
    [switch]$SkipUnitTests
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$addonsRoot = Join-Path $repoRoot "addons"

function Find-LuaTool {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Names
    )

    if ($LuaPath) {
        foreach ($name in $Names) {
            $candidate = Join-Path $LuaPath $name
            if (Test-Path -LiteralPath $candidate) {
                return $candidate
            }
        }
    }
    foreach ($name in $Names) {
        $command = Get-Command ($name -replace '\.exe$', '') -ErrorAction SilentlyContinue
        if ($command) {
            return $command.Source
        }
    }
    return $null
}

# Lua 5.1 plafonne un chunk a 200 variables locales. Un depassement est une
# erreur de compilation : l'addon entier ne s'execute pas, sans message parlant.
# Le controle d'equilibrage ne le voit pas, et sans luac rien ne l'attrapait.
# Cas reel : YayaWeeklyTracker.lua passe de 198 a 202 locaux, plus de section, ni
# de boutons, ni d'ouverture de conteneur.
$script:LuaMaxChunkLocals = 200

function Measure-LuaChunkLocals {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $count = 0
    foreach ($line in [System.IO.File]::ReadAllLines($Path)) {
        if (-not $line.StartsWith("local")) {
            continue
        }
        if ($line -match '^local\s+function\s+[A-Za-z_][A-Za-z0-9_]*') {
            $count++
            continue
        }
        if ($line -match '^local\s+([^=]+?)\s*(=|$)') {
            foreach ($name in ($Matches[1] -split ',')) {
                if ($name.Trim() -match '^[A-Za-z_][A-Za-z0-9_]*$') {
                    $count++
                }
            }
        }
    }
    return $count
}

$luac = Find-LuaTool -Names @("luac5.1.exe", "luac.exe", "luac54.exe")
$lua = Find-LuaTool -Names @("lua5.1.exe", "lua.exe", "lua54.exe")

$failed = 0
$checked = 0

Write-Host "Syntaxe des addons" -ForegroundColor Cyan
if ($luac) {
    Write-Host ("  compilateur : {0}" -f $luac)
    foreach ($file in Get-ChildItem -LiteralPath $addonsRoot -Recurse -Filter "*.lua" -File) {
        $checked++
        $output = & $luac -p $file.FullName 2>&1
        if ($LASTEXITCODE -ne 0) {
            $failed++
            Write-Host ("  ECHEC {0}" -f $file.FullName.Substring($addonsRoot.Length + 1)) -ForegroundColor Red
            Write-Host ("        {0}" -f ($output -join " ")) -ForegroundColor Red
        }
    }
    Write-Host ("  {0} fichiers compiles, {1} en erreur" -f $checked, $failed) -ForegroundColor $(if ($failed -eq 0) { "Green" } else { "Red" })
} else {
    Write-Host "  luac introuvable : repli sur le controle d'equilibrage" -ForegroundColor Yellow
    . (Join-Path $PSScriptRoot "lib\AddonPatchCore.ps1")
    foreach ($file in Get-ChildItem -LiteralPath $addonsRoot -Recurse -Filter "*.lua" -File) {
        $checked++
        if (-not (Test-AddonPatchLuaSyntax -Content ([System.IO.File]::ReadAllText($file.FullName)) -Label $file.Name)) {
            $failed++
            Write-Host ("  ECHEC {0} -> {1}" -f $file.Name, (Get-AddonPatchLastLuaError)) -ForegroundColor Red
        }
    }
    Write-Host ("  {0} fichiers verifies, {1} en erreur" -f $checked, $failed) -ForegroundColor $(if ($failed -eq 0) { "Green" } else { "Red" })
    Write-Host "  (indiquer -LuaPath pour une validation reelle)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Variables locales par chunk (limite Lua 5.1 : 200)" -ForegroundColor Cyan
$localsOver = 0
$localsTight = @()
foreach ($file in Get-ChildItem -LiteralPath $addonsRoot -Recurse -Filter "*.lua" -File) {
    $locals = Measure-LuaChunkLocals -Path $file.FullName
    $relative = $file.FullName.Substring($addonsRoot.Length + 1)
    if ($locals -gt $script:LuaMaxChunkLocals) {
        $localsOver++
        $failed++
        Write-Host ("  ECHEC {0} : {1} locaux, l'addon ne compilera pas" -f $relative, $locals) -ForegroundColor Red
    } elseif ($locals -gt ($script:LuaMaxChunkLocals - 15)) {
        $localsTight += ("{0} ({1})" -f $relative, $locals)
    }
}
if ($localsOver -eq 0) {
    Write-Host "  aucun depassement" -ForegroundColor Green
}
if ($localsTight.Count -gt 0) {
    Write-Host ("  marge faible : {0}" -f ($localsTight -join ", ")) -ForegroundColor Yellow
}

if (-not $SkipUnitTests) {
    Write-Host ""
    Write-Host "Tests unitaires" -ForegroundColor Cyan
    $testFiles = @(Get-ChildItem -LiteralPath $addonsRoot -Recurse -Filter "test_*.lua" -File |
        Where-Object { $_.Directory.Name -eq "Tests" })
    if (-not $lua) {
        Write-Host "  interpreteur introuvable : tests ignores" -ForegroundColor Yellow
    } elseif ($testFiles.Count -eq 0) {
        Write-Host "  aucun test trouve"
    } else {
        foreach ($test in $testFiles) {
            # Chaque suite s'execute depuis le dossier de son addon : les tests
            # chargent la source par un chemin relatif.
            $addonDir = Split-Path -Parent $test.Directory.FullName
            $relative = $test.FullName.Substring($addonDir.Length + 1)
            Write-Host ("  {0}" -f $test.FullName.Substring($addonsRoot.Length + 1))
            Push-Location $addonDir
            try {
                & $lua $relative
                if ($LASTEXITCODE -ne 0) {
                    $failed++
                }
            } finally {
                Pop-Location
            }
        }
    }
}

Write-Host ""
if ($failed -gt 0) {
    Write-Host ("{0} echec(s)" -f $failed) -ForegroundColor Red
    exit 1
}
Write-Host "Tout est vert" -ForegroundColor Green
