Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "TSMAutoPatch.Common.ps1")

$startupPath = Get-TSMAutoPatchStartupPath
if (Test-Path -LiteralPath $startupPath) {
    Remove-Item -LiteralPath $startupPath -Force
    Write-TSMAutoPatchLog -Message ("startup launcher removed: {0}" -f $startupPath)
}

Write-Host ("Removed startup launcher: {0}" -f $startupPath)
