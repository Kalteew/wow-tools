param(
    [string]$AddonPath,
    [int]$AlertThreshold = 2,
    [int]$HeartbeatMinutes = 30
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "RareScannerAutoPatch.Common.ps1")

Start-AddonPatchWatcher `
    -AddonName "RareScanner" `
    -AddonPath $AddonPath `
    -MutexName $script:WatcherMutexName `
    -ResolveAddonPathAction { param($path) Resolve-RareScannerAddonPath -AddonPath $path } `
    -PatchAction { param($path) Invoke-RareScannerAutoPatch -AddonPath $path -Quiet } `
    -LogAction { param($message) Write-RareScannerAutoPatchLog -Message $message -Quiet } `
    -PatchModulePath $PSScriptRoot `
    -AlertThreshold $AlertThreshold `
    -HeartbeatMinutes $HeartbeatMinutes `
    -Notify $true `
    -LaunchCodexRepair $true
