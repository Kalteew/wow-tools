param(
    [ValidateSet("status", "profiles", "list", "capture", "apply", "assign", "apply-assigned")]
    [string]$Action = "status",
    [string]$Profile,
    [string]$Character,
    [string]$Realm,
    [string]$Account,
    [string]$ConfigPath,
    [switch]$DryRun,
    [switch]$Force
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
if (-not $ConfigPath) {
    $ConfigPath = Join-Path $repoRoot "data\addon-profiles.json"
}

function Get-JsonProperty {
    param(
        [Parameter(Mandatory = $true)]$Object,
        [Parameter(Mandatory = $true)][string]$Name
    )

    $property = $Object.PSObject.Properties[$Name]
    if ($property) {
        return $property.Value
    }
    return $null
}

function Set-JsonProperty {
    param(
        [Parameter(Mandatory = $true)]$Object,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)]$Value
    )

    if ($Object.PSObject.Properties[$Name]) {
        $Object.$Name = $Value
    } else {
        $Object | Add-Member -NotePropertyName $Name -NotePropertyValue $Value
    }
}

function Read-Config {
    if (-not (Test-Path -LiteralPath $ConfigPath -PathType Leaf)) {
        throw "Config missing: $ConfigPath"
    }
    return Get-Content -Raw -LiteralPath $ConfigPath | ConvertFrom-Json
}

function Save-Config {
    param([Parameter(Mandatory = $true)]$Config)

    $json = $Config | ConvertTo-Json -Depth 12
    Set-Content -LiteralPath $ConfigPath -Value $json -Encoding UTF8
}

function Resolve-Context {
    param([Parameter(Mandatory = $true)]$Config)

    $retailRoot = $Config.retailRoot
    if (-not $retailRoot) {
        $retailRoot = "C:\Program Files (x86)\World of Warcraft\_retail_"
    }
    if (-not (Test-Path -LiteralPath $retailRoot -PathType Container)) {
        throw "Retail root missing: $retailRoot"
    }

    $accountName = if ($Account) { $Account } else { $Config.account }
    $accountRoot = $null
    $accountBase = Join-Path $retailRoot "WTF\Account"
    if ($accountName) {
        $accountRoot = Join-Path $accountBase $accountName
    } else {
        $accounts = @(Get-ChildItem -LiteralPath $accountBase -Directory)
        if ($accounts.Count -ne 1) {
            throw "Specify -Account. Found $($accounts.Count) accounts."
        }
        $accountRoot = $accounts[0].FullName
        $accountName = $accounts[0].Name
    }
    if (-not (Test-Path -LiteralPath $accountRoot -PathType Container)) {
        throw "Account root missing: $accountRoot"
    }

    $realmName = if ($Realm) { $Realm } elseif ($Config.realm) { $Config.realm } else { $null }
    if (-not $realmName) {
        $realms = @(Get-ChildItem -LiteralPath $accountRoot -Directory)
        if ($realms.Count -ne 1) {
            throw "Specify -Realm. Found $($realms.Count) realms."
        }
        $realmName = $realms[0].Name
    }

    $realmRoot = Join-Path $accountRoot $realmName
    if (-not (Test-Path -LiteralPath $realmRoot -PathType Container)) {
        throw "Realm root missing: $realmRoot"
    }

    return [pscustomobject]@{
        RetailRoot = (Resolve-Path -LiteralPath $retailRoot).Path
        AccountName = $accountName
        AccountRoot = (Resolve-Path -LiteralPath $accountRoot).Path
        RealmName = $realmName
        RealmRoot = (Resolve-Path -LiteralPath $realmRoot).Path
        AddOnsRoot = Join-Path $retailRoot "Interface\AddOns"
    }
}

function Assert-PathWithinRoot {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Root
    )

    $fullPath = [System.IO.Path]::GetFullPath($Path)
    $fullRoot = [System.IO.Path]::GetFullPath($Root).TrimEnd('\')
    if ($fullPath -ne $fullRoot -and -not $fullPath.StartsWith($fullRoot + "\", [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Path out of root: $fullPath"
    }
}

function Assert-WowClosed {
    if ($Force) {
        return
    }
    $running = @(Get-Process -Name "Wow", "WowT", "WowClassic" -ErrorAction SilentlyContinue)
    if ($running.Count -gt 0) {
        throw "Close WoW before writing AddOns.txt, or rerun with -Force."
    }
}

function Get-CharacterRoot {
    param(
        [Parameter(Mandatory = $true)]$Context,
        [Parameter(Mandatory = $true)][string]$Name
    )

    $path = Join-Path $Context.RealmRoot $Name
    Assert-PathWithinRoot -Path $path -Root $Context.RealmRoot
    if (-not (Test-Path -LiteralPath $path -PathType Container)) {
        throw "Character missing: $($Context.RealmName)\$Name"
    }
    return $path
}

function Get-AddOnsFilePath {
    param(
        [Parameter(Mandatory = $true)]$Context,
        [Parameter(Mandatory = $true)][string]$Name
    )

    return Join-Path (Get-CharacterRoot -Context $Context -Name $Name) "AddOns.txt"
}

function Read-AddOnsFile {
    param([Parameter(Mandatory = $true)][string]$Path)

    $entries = [ordered]@{}
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return $entries
    }

    foreach ($line in Get-Content -LiteralPath $Path) {
        if ($line -match "^\s*(.+?)\s*:\s*(enabled|disabled)\s*$") {
            $entries[$matches[1]] = $matches[2]
        }
    }
    return $entries
}

function Get-EnabledAddOns {
    param([Parameter(Mandatory = $true)][string]$Path)

    $entries = Read-AddOnsFile -Path $Path
    $enabled = @()
    foreach ($name in $entries.Keys) {
        if ($entries[$name] -eq "enabled") {
            $enabled += $name
        }
    }
    return $enabled
}

function Get-KnownAddOns {
    param([Parameter(Mandatory = $true)]$Context)

    $names = @{}
    if (Test-Path -LiteralPath $Context.AddOnsRoot -PathType Container) {
        foreach ($addon in Get-ChildItem -LiteralPath $Context.AddOnsRoot -Directory) {
            $names[$addon.Name] = $true
        }
    }

    foreach ($file in Get-ChildItem -LiteralPath $Context.RealmRoot -Recurse -Filter AddOns.txt) {
        $entries = Read-AddOnsFile -Path $file.FullName
        foreach ($name in $entries.Keys) {
            $names[$name] = $true
        }
    }

    return @($names.Keys | Sort-Object)
}

function Get-Profile {
    param(
        [Parameter(Mandatory = $true)]$Config,
        [Parameter(Mandatory = $true)][string]$Name
    )

    $profiles = $Config.profiles
    $profileObject = Get-JsonProperty -Object $profiles -Name $Name
    if (-not $profileObject) {
        throw "Unknown profile: $Name"
    }
    return $profileObject
}

function Get-AssignmentKey {
    param(
        [Parameter(Mandatory = $true)]$Context,
        [Parameter(Mandatory = $true)][string]$Name
    )

    return "$($Context.RealmName)/$Name"
}

function Get-AssignedProfile {
    param(
        [Parameter(Mandatory = $true)]$Config,
        [Parameter(Mandatory = $true)]$Context,
        [Parameter(Mandatory = $true)][string]$Name
    )

    return Get-JsonProperty -Object $Config.assignments -Name (Get-AssignmentKey -Context $Context -Name $Name)
}

function Write-ProfileToCharacter {
    param(
        [Parameter(Mandatory = $true)]$Config,
        [Parameter(Mandatory = $true)]$Context,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$ProfileName
    )

    if (-not $DryRun) {
        Assert-WowClosed
    }

    $profileObject = Get-Profile -Config $Config -Name $ProfileName
    $enabledSet = @{}
    foreach ($addon in @($profileObject.enabled)) {
        if ($addon) {
            $enabledSet[[string]$addon] = $true
        }
    }

    $path = Get-AddOnsFilePath -Context $Context -Name $Name
    Assert-PathWithinRoot -Path $path -Root $Context.RealmRoot

    $knownAddons = Get-KnownAddOns -Context $Context
    foreach ($addon in $enabledSet.Keys) {
        if (-not ($knownAddons -contains $addon)) {
            $knownAddons += $addon
        }
    }
    $knownAddons = @($knownAddons | Sort-Object)

    if ($DryRun) {
        return [pscustomobject]@{
            Character = $Name
            Profile = $ProfileName
            Enabled = $enabledSet.Count
            Path = $path
            DryRun = $true
        }
    }

    if (Test-Path -LiteralPath $path -PathType Leaf) {
        $backup = "$path.bak.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        Copy-Item -LiteralPath $path -Destination $backup -Force
    }

    $lines = foreach ($addon in $knownAddons) {
        $state = if ($enabledSet.ContainsKey($addon)) { "enabled" } else { "disabled" }
        "{0}: {1}" -f $addon, $state
    }
    Set-Content -LiteralPath $path -Value $lines -Encoding UTF8

    [pscustomobject]@{
        Character = $Name
        Profile = $ProfileName
        Enabled = $enabledSet.Count
        Path = $path
        DryRun = $false
    }
}

function Show-Profiles {
    param([Parameter(Mandatory = $true)]$Config)

    foreach ($profileProperty in $Config.profiles.PSObject.Properties | Sort-Object Name) {
        $profileObject = $profileProperty.Value
        [pscustomobject]@{
            Profile = $profileProperty.Name
            Label = $profileObject.label
            Enabled = @($profileObject.enabled).Count
        }
    }
}

function Show-Characters {
    param(
        [Parameter(Mandatory = $true)]$Config,
        [Parameter(Mandatory = $true)]$Context
    )

    foreach ($dir in Get-ChildItem -LiteralPath $Context.RealmRoot -Directory | Sort-Object Name) {
        $path = Join-Path $dir.FullName "AddOns.txt"
        $enabled = if (Test-Path -LiteralPath $path -PathType Leaf) { @(Get-EnabledAddOns -Path $path).Count } else { 0 }
        [pscustomobject]@{
            Character = $dir.Name
            Assigned = Get-AssignedProfile -Config $Config -Context $Context -Name $dir.Name
            EnabledNow = $enabled
        }
    }
}

$config = Read-Config
$context = Resolve-Context -Config $config

switch ($Action) {
    "profiles" {
        Show-Profiles -Config $config | Format-Table -AutoSize
    }
    "list" {
        Show-Characters -Config $config -Context $context | Format-Table -AutoSize
    }
    "status" {
        Write-Output "Config: $ConfigPath"
        Write-Output "Realm: $($context.AccountName)\$($context.RealmName)"
        Show-Profiles -Config $config | Format-Table -AutoSize
        Show-Characters -Config $config -Context $context | Format-Table -AutoSize
    }
    "capture" {
        if (-not $Character -or -not $Profile) {
            throw "Usage: -Action capture -Character CharacterName -Profile play"
        }
        $path = Get-AddOnsFilePath -Context $context -Name $Character
        $profileObject = Get-Profile -Config $config -Name $Profile
        $profileObject.enabled = @(Get-EnabledAddOns -Path $path)
        $profileObject.updatedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Save-Config -Config $config
        Write-Output "Captured $Profile from $Character ($(@($profileObject.enabled).Count) enabled addons)."
    }
    "assign" {
        if (-not $Character -or -not $Profile) {
            throw "Usage: -Action assign -Character CharacterName -Profile gold"
        }
        Get-Profile -Config $config -Name $Profile | Out-Null
        Get-CharacterRoot -Context $context -Name $Character | Out-Null
        Set-JsonProperty -Object $config.assignments -Name (Get-AssignmentKey -Context $context -Name $Character) -Value $Profile
        Save-Config -Config $config
        Write-Output "Assigned $Character -> $Profile."
    }
    "apply" {
        if (-not $Character) {
            throw "Usage: -Action apply -Character CharacterName [-Profile gold]"
        }
        $profileToApply = if ($Profile) { $Profile } else { Get-AssignedProfile -Config $config -Context $context -Name $Character }
        if (-not $profileToApply) {
            throw "No profile assigned to $Character. Use -Profile or -Action assign."
        }
        Write-ProfileToCharacter -Config $config -Context $context -Name $Character -ProfileName $profileToApply | Format-List
    }
    "apply-assigned" {
        $targets = @()
        if ($Character) {
            $targets += $Character
        } else {
            foreach ($assignment in $config.assignments.PSObject.Properties) {
                $parts = $assignment.Name -split "/", 2
                if ($parts.Count -eq 2 -and $parts[0] -eq $context.RealmName) {
                    $targets += $parts[1]
                }
            }
        }
        if ($targets.Count -eq 0) {
            Write-Output "No assigned characters."
            return
        }
        foreach ($target in $targets) {
            $profileToApply = Get-AssignedProfile -Config $config -Context $context -Name $target
            if ($profileToApply) {
                Write-ProfileToCharacter -Config $config -Context $context -Name $target -ProfileName $profileToApply
            }
        }
    }
}
