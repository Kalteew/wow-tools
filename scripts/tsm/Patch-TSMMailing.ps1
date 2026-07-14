param(
    [string]$AddonPath,
    [switch]$Quiet
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "TSMAutoPatch.Common.ps1")

try {
    $result = Invoke-TSMMailingPatch -AddonPath $AddonPath -Quiet:$Quiet
    if (-not $Quiet) {
        Write-Host ("Status: {0}" -f $result.Status)
    }
    exit 0
} catch {
    Write-TSMAutoPatchLog -Message ("patch failed: {0}" -f $_.Exception.Message) -Quiet:$Quiet
    if (-not $Quiet) {
        Write-Error $_
    }
    exit 1
}
