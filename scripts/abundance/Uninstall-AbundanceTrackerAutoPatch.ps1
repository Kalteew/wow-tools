Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "AbundanceTrackerAutoPatch.Common.ps1")

$startupPath = Get-AbundanceTrackerAutoPatchStartupPath
if (Test-Path -LiteralPath $startupPath) {
    Remove-Item -LiteralPath $startupPath -Force
    Write-AbundanceTrackerAutoPatchLog -Message ("startup launcher removed: {0}" -f $startupPath)
}

Write-Host ("Removed startup launcher: {0}" -f $startupPath)
