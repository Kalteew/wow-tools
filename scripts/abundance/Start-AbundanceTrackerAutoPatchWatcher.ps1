param(
    [string]$AddonPath,
    [int]$AlertThreshold = 2,
    [int]$HeartbeatMinutes = 30
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "AbundanceTrackerAutoPatch.Common.ps1")

Start-AddonPatchWatcher `
    -AddonName "AbundanceTracker" `
    -AddonPath $AddonPath `
    -MutexName $script:WatcherMutexName `
    -ResolveAddonPathAction { param($path) Resolve-AbundanceTrackerAddonPath -AddonPath $path } `
    -PatchAction { param($path) Invoke-AbundanceTrackerAutoPatch -AddonPath $path -Quiet } `
    -LogAction { param($message) Write-AbundanceTrackerAutoPatchLog -Message $message -Quiet } `
    -PatchModulePath $PSScriptRoot `
    -AlertThreshold $AlertThreshold `
    -HeartbeatMinutes $HeartbeatMinutes `
    -Notify $true `
    -LaunchCodexRepair $true
