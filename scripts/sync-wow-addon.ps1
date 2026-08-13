param(
    [string[]]$AddonNames,
    [switch]$AllowDowngrade
)

$repoRoot = Split-Path -Parent $PSScriptRoot
$sourceRoot = Join-Path $repoRoot "addons"
$targetRoot = "C:\Program Files (x86)\World of Warcraft\_retail_\Interface\AddOns"

function Assert-PathWithinRoot {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [string]$Root
    )

    $fullPath = [System.IO.Path]::GetFullPath($Path)
    $fullRoot = [System.IO.Path]::GetFullPath($Root).TrimEnd('\')

    if ($fullPath -ne $fullRoot -and -not $fullPath.StartsWith($fullRoot + "\", [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Path out of root: $fullPath"
    }
}

function Get-RelativePath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$BasePath,
        [Parameter(Mandatory = $true)]
        [string]$FullPath
    )

    $baseUri = [System.Uri](([System.IO.Path]::GetFullPath($BasePath).TrimEnd('\')) + '\')
    $fullUri = [System.Uri]([System.IO.Path]::GetFullPath($FullPath))
    $relativeUri = $baseUri.MakeRelativeUri($fullUri)
    return [System.Uri]::UnescapeDataString($relativeUri.ToString()).Replace('/', '\')
}

function Get-AddonVersion {
    param(
        [Parameter(Mandatory = $true)]
        [string]$AddonPath
    )

    $tocFile = Get-ChildItem -LiteralPath $AddonPath -Filter "*.toc" -File | Select-Object -First 1
    if (-not $tocFile) {
        return $null
    }

    $versionLine = Select-String -LiteralPath $tocFile.FullName -Pattern '^## Version:\s*(.+?)\s*$' |
        Select-Object -First 1
    if (-not $versionLine) {
        return $null
    }

    $versionText = $versionLine.Matches[0].Groups[1].Value
    $numericVersion = [regex]::Match($versionText, '\d+(?:\.\d+){1,3}')
    $parsedVersion = $null
    if ($numericVersion.Success -and [System.Version]::TryParse($numericVersion.Value, [ref]$parsedVersion)) {
        return $parsedVersion
    }
    return $null
}

function Copy-AddonTree {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourcePath,
        [Parameter(Mandatory = $true)]
        [string]$TargetPath,
        [Parameter(Mandatory = $true)]
        [string]$TargetRoot
    )

    if (-not (Test-Path -LiteralPath $TargetPath -PathType Container)) {
        New-Item -ItemType Directory -Path $TargetPath -Force | Out-Null
    }

    $sourceEntries = Get-ChildItem -LiteralPath $SourcePath -Recurse -Force
    $sourceRelativePaths = @{}

    foreach ($entry in $sourceEntries) {
        $relativePath = Get-RelativePath -BasePath $SourcePath -FullPath $entry.FullName
        $sourceRelativePaths[$relativePath] = $true
        $destinationPath = Join-Path $TargetPath $relativePath
        Assert-PathWithinRoot -Path $destinationPath -Root $TargetRoot

        if ($entry.PSIsContainer) {
            if (-not (Test-Path -LiteralPath $destinationPath -PathType Container)) {
                New-Item -ItemType Directory -Path $destinationPath -Force | Out-Null
            }
            continue
        }

        $destinationParent = Split-Path -Parent $destinationPath
        if (-not (Test-Path -LiteralPath $destinationParent -PathType Container)) {
            New-Item -ItemType Directory -Path $destinationParent -Force | Out-Null
        }

        Copy-Item -LiteralPath $entry.FullName -Destination $destinationPath -Force
    }

    if (-not (Test-Path -LiteralPath $TargetPath -PathType Container)) {
        return
    }

    $targetEntries = Get-ChildItem -LiteralPath $TargetPath -Recurse -Force | Sort-Object FullName -Descending
    foreach ($entry in $targetEntries) {
        $relativePath = Get-RelativePath -BasePath $TargetPath -FullPath $entry.FullName
        if ($sourceRelativePaths.ContainsKey($relativePath)) {
            continue
        }

        try {
            Remove-Item -LiteralPath $entry.FullName -Recurse -Force -ErrorAction Stop
        } catch {
            Write-Warning ("Skipped removing {0}: {1}" -f $entry.FullName, $_.Exception.Message)
        }
    }
}

if (-not (Test-Path -LiteralPath $sourceRoot -PathType Container)) {
    throw "Source root missing: $sourceRoot"
}

if (-not (Test-Path -LiteralPath $targetRoot -PathType Container)) {
    throw "WoW AddOns folder missing: $targetRoot"
}

if (-not $AddonNames -or $AddonNames.Count -eq 0) {
    $AddonNames = Get-ChildItem -LiteralPath $sourceRoot -Directory | Select-Object -ExpandProperty Name
}

foreach ($addonName in $AddonNames) {
    $sourcePath = Join-Path $sourceRoot $addonName
    $targetPath = Join-Path $targetRoot $addonName

    if (-not (Test-Path -LiteralPath $sourcePath -PathType Container)) {
        throw "Addon missing in repo: $sourcePath"
    }

    Assert-PathWithinRoot -Path $targetPath -Root $targetRoot

    if ((Test-Path -LiteralPath $targetPath -PathType Container) -and -not $AllowDowngrade) {
        $sourceVersion = Get-AddonVersion -AddonPath $sourcePath
        $targetVersion = Get-AddonVersion -AddonPath $targetPath
        if ($sourceVersion -and $targetVersion -and $targetVersion -gt $sourceVersion) {
            throw (
                "Refusing to downgrade {0} from live version {1} to repo version {2}. " +
                "Import the live changes into the repo first, or pass -AllowDowngrade explicitly."
            ) -f $addonName, $targetVersion, $sourceVersion
        }
    }

    Copy-AddonTree -SourcePath $sourcePath -TargetPath $targetPath -TargetRoot $targetRoot
    Write-Output "Synced $addonName -> $targetPath"
}
