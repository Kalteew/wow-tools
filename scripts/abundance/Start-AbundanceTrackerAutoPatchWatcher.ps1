param([string]$AddonPath)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "AbundanceTrackerAutoPatch.Common.ps1")

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
        Write-AbundanceTrackerAutoPatchLog -Message "watcher recovered an abandoned mutex" -Quiet
    }
    if (-not $mutexOwned) {
        return
    }

    $resolvedAddonPath = Resolve-AbundanceTrackerAddonPath -AddonPath $AddonPath
    Invoke-AbundanceTrackerAutoPatch -AddonPath $resolvedAddonPath -Quiet | Out-Null

    $state = [hashtable]::Synchronized(@{ Pending = $false; LastEvent = Get-Date })
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

    Write-AbundanceTrackerAutoPatchLog -Message ("watcher started for {0}" -f $resolvedAddonPath) -Quiet
    $lastHeartbeat = Get-Date
    while ($true) {
        Start-Sleep -Seconds 2

        if ($state.Pending -and ((Get-Date) - $state.LastEvent).TotalSeconds -ge 3) {
            $state.Pending = $false
            try {
                Invoke-AbundanceTrackerAutoPatch -AddonPath $resolvedAddonPath -Quiet | Out-Null
            } catch {
                Write-AbundanceTrackerAutoPatchLog -Message ("watcher retry failed: {0}" -f $_.Exception.Message) -Quiet
            }
        }

        if (((Get-Date) - $lastHeartbeat).TotalMinutes -ge 30) {
            $lastHeartbeat = Get-Date
            try {
                Invoke-AbundanceTrackerAutoPatch -AddonPath $resolvedAddonPath -Quiet | Out-Null
            } catch {
                Write-AbundanceTrackerAutoPatchLog -Message ("heartbeat patch failed: {0}" -f $_.Exception.Message) -Quiet
            }
        }
    }
} finally {
    foreach ($subscription in $eventSubscriptions) {
        try { Unregister-Event -SubscriptionId $subscription.Id -ErrorAction SilentlyContinue } catch {}
        try { Remove-Job -Id $subscription.Id -Force -ErrorAction SilentlyContinue } catch {}
    }
    if ($watcher) {
        $watcher.EnableRaisingEvents = $false
        $watcher.Dispose()
    }
    if ($mutexOwned -and $mutex) {
        try { $mutex.ReleaseMutex() | Out-Null } catch {}
    }
    if ($mutex) { $mutex.Dispose() }
}
