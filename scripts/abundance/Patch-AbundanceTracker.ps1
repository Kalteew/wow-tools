param(
    [string]$AddonPath,
    [switch]$Quiet,
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "AbundanceTrackerAutoPatch.Common.ps1")

try {
    $result = Invoke-AbundanceTrackerAutoPatch -AddonPath $AddonPath -Quiet:$Quiet -DryRun:$DryRun
    if (-not $Quiet) {
        Write-Host ("Status: {0}" -f $result.Status)
    }
    exit 0
} catch {
    Write-AbundanceTrackerAutoPatchLog -Message ("patch failed: {0}" -f $_.Exception.Message) -Quiet:$Quiet
    if (-not $Quiet) {
        Write-Error $_
    }
    exit 1
}
