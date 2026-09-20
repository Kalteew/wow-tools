param([string]$AddonPath)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "RareScannerAutoPatch.Common.ps1")

$resolvedAddonPath = Resolve-RareScannerAddonPath -AddonPath $AddonPath
$watcherPath = Join-Path $PSScriptRoot "Start-RareScannerAutoPatchWatcher.ps1"
$startupPath = Get-RareScannerAutoPatchStartupPath

Invoke-RareScannerAutoPatch -AddonPath $resolvedAddonPath | Out-Null

$startupContent = @"
Set shell = CreateObject("WScript.Shell")
shell.Run "powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File ""$watcherPath""", 0, False
"@
Set-Content -LiteralPath $startupPath -Value $startupContent -NoNewline
Write-RareScannerAutoPatchLog -Message ("startup launcher installed: {0}" -f $startupPath)

Start-Process -FilePath "powershell.exe" -ArgumentList @(
    "-NoProfile", "-WindowStyle", "Hidden", "-ExecutionPolicy", "Bypass",
    "-File", $watcherPath, "-AddonPath", ('"{0}"' -f $resolvedAddonPath)
) -WindowStyle Hidden

Write-Host ("Installed. RareScanner path: {0}" -f $resolvedAddonPath)
Write-Host ("Startup launcher: {0}" -f $startupPath)
