Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "RareScannerAutoPatch.Common.ps1")

$startupPath = Get-RareScannerAutoPatchStartupPath
if (Test-Path -LiteralPath $startupPath) {
    Remove-Item -LiteralPath $startupPath -Force
    Write-RareScannerAutoPatchLog -Message ("startup launcher removed: {0}" -f $startupPath)
}
Write-Host ("Removed startup launcher: {0}" -f $startupPath)
