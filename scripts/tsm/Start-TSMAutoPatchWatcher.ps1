param(
    [string]$AddonPath,
    [int]$AlertThreshold = 2,
    [int]$HeartbeatMinutes = 30
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "TSMAutoPatch.Common.ps1")

Start-AddonPatchWatcher `
    -AddonName "TSM" `
    -AddonPath $AddonPath `
    -MutexName $script:WatcherMutexName `
    -ResolveAddonPathAction { param($path) Resolve-TSMAddonPath -AddonPath $path } `
    -PatchAction { param($path) Invoke-TSMMailingPatch -AddonPath $path -Quiet } `
    -LogAction { param($message) Write-TSMAutoPatchLog -Message $message -Quiet } `
    -StatusAction { param($result, $failureCounts, $fatalError) Write-TSMAutoPatchStatus -Result $result -ConsecutiveFailures $failureCounts -FatalError $fatalError } `
    -PatchModulePath $PSScriptRoot `
    -AlertThreshold $AlertThreshold `
    -HeartbeatMinutes $HeartbeatMinutes `
    -Notify $true `
    -LaunchCodexRepair $true
