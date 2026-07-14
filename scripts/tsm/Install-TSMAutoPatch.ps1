param(
    [string]$AddonPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "TSMAutoPatch.Common.ps1")

$resolvedAddonPath = Resolve-TSMAddonPath -AddonPath $AddonPath
$watcherPath = Join-Path $PSScriptRoot "Start-TSMAutoPatchWatcher.ps1"
$startupPath = Get-TSMAutoPatchStartupPath

Invoke-TSMMailingPatch -AddonPath $resolvedAddonPath | Out-Null

$startupContent = @"
Set shell = CreateObject("WScript.Shell")
shell.Run "powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File ""$watcherPath""", 0, False
"@
Set-Content -LiteralPath $startupPath -Value $startupContent -NoNewline
Write-TSMAutoPatchLog -Message ("startup launcher installed: {0}" -f $startupPath)

Start-Process -FilePath "powershell.exe" -ArgumentList @(
    "-NoProfile",
    "-WindowStyle", "Hidden",
    "-ExecutionPolicy", "Bypass",
    "-File", $watcherPath,
    "-AddonPath", $resolvedAddonPath
) -WindowStyle Hidden

Write-Host ("Installed. TSM path: {0}" -f $resolvedAddonPath)
Write-Host ("Startup launcher: {0}" -f $startupPath)
