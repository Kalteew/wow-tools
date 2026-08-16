param(
    [string]$RepoRoot = (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)),
    [string]$TaskName = "YayaMarketReset - snapshot Yayag",
    [string]$Time = "07:55"
)

$ErrorActionPreference = "Stop"

$python = (Get-Command python.exe -ErrorAction Stop).Source
$scriptPath = Join-Path $RepoRoot "scripts\reports\daily_yayag_reset.py"
$outputDir = Join-Path $RepoRoot "data\reports"

if (-not (Test-Path -LiteralPath $scriptPath)) {
    throw "Script introuvable : $scriptPath"
}

$argumentText = "`"$scriptPath`" --output-dir `"$outputDir`" --quiet"
$action = New-ScheduledTaskAction -Execute $python -Argument $argumentText -WorkingDirectory $RepoRoot
$dailyTrigger = New-ScheduledTaskTrigger -Daily -At ([datetime]::ParseExact($Time, "HH:mm", $null))
$logonTrigger = New-ScheduledTaskTrigger -AtLogOn -User "$env:USERDOMAIN\$env:USERNAME"
$triggers = @($dailyTrigger, $logonTrigger)
$principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive -RunLevel Limited
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Minutes 30)

Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $triggers -Principal $principal -Settings $settings -Force | Out-Null
Write-Output "Tâche planifiée : $TaskName à $Time ou à l'ouverture de session"
Write-Output "Sorties : $outputDir"
