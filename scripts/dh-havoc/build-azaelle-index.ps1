param(
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path,
  [string]$OutputPath = ''
)

$ErrorActionPreference = 'Stop'
if (-not $OutputPath) { $OutputPath = Join-Path $RepoRoot 'data\dh-havoc\azaelle-index.json' }
$canonicalName = 'Azåelle'
$rows = @()

foreach ($file in Get-ChildItem (Join-Path $RepoRoot 'logs\reports') -Filter '*.json' -File) {
  try { $report = Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json } catch { continue }
  $player = @($report.players) | Where-Object {
    $name = [string]$_.name
    ($name -and $name -ceq $canonicalName)
  } | Select-Object -First 1
  if (-not $player) { continue }
  $metrics = if ($report.playerMetrics.azaelle) { $report.playerMetrics.azaelle } else { $null }
  $rows += [ordered]@{
    sourcePath = $file.FullName
    reportCode = $report.reportCode
    fightID = $report.fightID
    capturedAt = $report.capturedAt
    season = $report.season
    patch = $report.patch
    contentType = $report.contentType
    buildContext = $report.buildContext
    fight = $report.fight
    player = $player
    metrics = $metrics
    rankings = $report.rankings
  }
}

$comparisonDir = Join-Path $RepoRoot 'logs\comparisons'
$comparisons = if (Test-Path $comparisonDir) { @(Get-ChildItem $comparisonDir -Recurse -File | Where-Object { $_.Name -match 'azaelle|browser-evidence|comparison-summary' } | ForEach-Object { $_.FullName }) } else { @() }
$result = [ordered]@{
  schemaVersion = 1
  generatedAt = (Get-Date).ToUniversalTime().ToString('o')
  character = [ordered]@{ name = $canonicalName; realm = 'Hyjal'; region = 'EU'; spec = 'Havoc' }
  reportCount = $rows.Count
  reports = $rows
  comparisonFiles = $comparisons
  policy = [ordered]@{ rankingsAreSeparate = $true; immutableSourceFiles = $true; rawEventsRemainInSourceReports = $true }
}
$parent = Split-Path $OutputPath -Parent
New-Item -ItemType Directory -Force -Path $parent | Out-Null
$result | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $OutputPath -Encoding UTF8
Write-Output "Indexed $($rows.Count) Azaelle report snapshots -> $OutputPath"
