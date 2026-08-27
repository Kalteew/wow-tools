param([string]$AddonPath)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "AbundanceTrackerAutoPatch.Common.ps1")

$resolvedAddonPath = Resolve-AbundanceTrackerAddonPath -AddonPath $AddonPath
$watcherPath = Join-Path $PSScriptRoot "Start-AbundanceTrackerAutoPatchWatcher.ps1"
$startupPath = Get-AbundanceTrackerAutoPatchStartupPath

Invoke-AbundanceTrackerAutoPatch -AddonPath $resolvedAddonPath | Out-Null

$startupContent = @"
Set shell = CreateObject("WScript.Shell")
shell.Run "powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File ""$watcherPath""", 0, False
"@
Set-Content -LiteralPath $startupPath -Value $startupContent -NoNewline
Write-AbundanceTrackerAutoPatchLog -Message ("startup launcher installed: {0}" -f $startupPath)

Start-Process -FilePath "powershell.exe" -ArgumentList @(
    "-NoProfile",
    "-WindowStyle", "Hidden",
    "-ExecutionPolicy", "Bypass",
    "-File", $watcherPath,
    "-AddonPath", ('"{0}"' -f $resolvedAddonPath)
) -WindowStyle Hidden

Write-Host ("Installed. AbundanceTracker path: {0}" -f $resolvedAddonPath)
Write-Host ("Startup launcher: {0}" -f $startupPath)
