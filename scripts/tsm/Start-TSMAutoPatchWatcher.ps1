param(
    [string]$AddonPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "TSMAutoPatch.Common.ps1")

$mutex = New-Object System.Threading.Mutex($false, $script:WatcherMutexName)
if (-not $mutex.WaitOne(0, $false)) {
    exit 0
}

$watcher = $null
$eventSubscriptions = @()

try {
    $resolvedAddonPath = Resolve-TSMAddonPath -AddonPath $AddonPath
    Invoke-TSMMailingPatch -AddonPath $resolvedAddonPath -Quiet | Out-Null

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

        if ($state.Pending -and ((Get-Date) - $state.LastEvent).TotalSeconds -ge 3) {
            $state.Pending = $false
            try {
                Invoke-TSMMailingPatch -AddonPath $resolvedAddonPath -Quiet | Out-Null
            } catch {
                Write-TSMAutoPatchLog -Message ("watcher retry failed: {0}" -f $_.Exception.Message) -Quiet
            }
        }

        if (((Get-Date) - $lastHeartbeat).TotalMinutes -ge 30) {
            $lastHeartbeat = Get-Date
            try {
                Invoke-TSMMailingPatch -AddonPath $resolvedAddonPath -Quiet | Out-Null
            } catch {
                Write-TSMAutoPatchLog -Message ("heartbeat patch failed: {0}" -f $_.Exception.Message) -Quiet
            }
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
    $mutex.ReleaseMutex() | Out-Null
    $mutex.Dispose()
}
