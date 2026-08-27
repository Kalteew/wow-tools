param(
    [string]$AddonPath,
    # Nombre d'echecs consecutifs d'un meme patch avant de notifier. A 1 le
    # bruit serait constant pendant une mise a jour de l'addon (fichiers
    # reecrits un par un) ; a 2 on ne notifie que ce qui persiste.
    [int]$AlertThreshold = 2,
    [int]$HeartbeatMinutes = 30
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "TSMAutoPatch.Common.ps1")

$mutex = $null
$mutexOwned = $false
$watcher = $null
$eventSubscriptions = @()

try {
    $mutex = New-Object System.Threading.Mutex($false, $script:WatcherMutexName)
    try {
        $mutexOwned = $mutex.WaitOne(0, $false)
    } catch [System.Threading.AbandonedMutexException] {
        $mutexOwned = $true
        Write-TSMAutoPatchLog -Message "watcher recovered an abandoned mutex" -Quiet
    }
    if (-not $mutexOwned) {
        return
    }

    $resolvedAddonPath = Resolve-TSMAddonPath -AddonPath $AddonPath
    $tracker = New-TSMAutoPatchRunTracker

    Invoke-TSMAutoPatchRun -AddonPath $resolvedAddonPath -Tracker $tracker -Origin "startup" -AlertThreshold $AlertThreshold | Out-Null

    $state = [hashtable]::Synchronized(@{
        Pending = $false
        LastEvent = Get-Date
    })

    $watcher = New-Object System.IO.FileSystemWatcher
    $watcher.Path = $resolvedAddonPath
    $watcher.Filter = "*"
    $watcher.IncludeSubdirectories = $true
    $watcher.NotifyFilter = [System.IO.NotifyFilters]'FileName, DirectoryName, LastWrite, Size'
    $watcher.EnableRaisingEvents = $true

    foreach ($eventName in @("Changed", "Created", "Deleted", "Renamed")) {
        $eventSubscriptions += Register-ObjectEvent -InputObject $watcher -EventName $eventName -Action {
            $state.Pending = $true
            $state.LastEvent = Get-Date
        }
    }

    Write-TSMAutoPatchLog -Message ("watcher started for {0}" -f $resolvedAddonPath) -Quiet

    $lastHeartbeat = Get-Date
    while ($true) {
        Start-Sleep -Seconds 2

        # On attend 3 secondes de calme : une mise a jour de l'addon reecrit
        # des dizaines de fichiers, inutile de patcher a chaque evenement.
        if ($state.Pending -and ((Get-Date) - $state.LastEvent).TotalSeconds -ge 3) {
            $state.Pending = $false
            Invoke-TSMAutoPatchRun -AddonPath $resolvedAddonPath -Tracker $tracker -Origin "watcher retry" -AlertThreshold $AlertThreshold | Out-Null
        }

        if (((Get-Date) - $lastHeartbeat).TotalMinutes -ge $HeartbeatMinutes) {
            $lastHeartbeat = Get-Date
            Invoke-TSMAutoPatchRun -AddonPath $resolvedAddonPath -Tracker $tracker -Origin "heartbeat" -AlertThreshold $AlertThreshold | Out-Null
        }
    }
} finally {
    foreach ($subscription in $eventSubscriptions) {
        try {
            Unregister-Event -SubscriptionId $subscription.Id -ErrorAction SilentlyContinue
        } catch {
        }
        try {
            Remove-Job -Id $subscription.Id -Force -ErrorAction SilentlyContinue
        } catch {
        }
    }
    if ($watcher) {
        $watcher.EnableRaisingEvents = $false
        $watcher.Dispose()
    }
    if ($mutexOwned -and $mutex) {
        try {
            $mutex.ReleaseMutex() | Out-Null
        } catch {
        }
    }
    if ($mutex) {
        $mutex.Dispose()
    }
}
