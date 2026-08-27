Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Primitives communes aux auto-patchs (validation Lua, ecriture atomique,
# rotation du journal, notifications, suivi des echecs).
. (Join-Path $PSScriptRoot "..\lib\AddonPatchCore.ps1")

$script:WatcherMutexName = "Local\AbundanceTrackerAutoPatchWatcher"
$script:StartupLauncherName = "AbundanceTracker Auto Patch Watcher.vbs"
$script:PatchMarker = "Yaya AbundanceTracker AutoPatch: secret-safe aura queries"
$script:VisibilityPatchMarker = "Yaya AbundanceTracker AutoPatch: automatic event visibility"
# Marqueur le plus recent : c'est lui que teste la detection "deja applique", et
# c'est donc lui qu'il faut ajouter en introduisant une nouvelle famille de
# blocs, sinon un fichier deja patche par une version anterieure serait
# considere comme a jour et le nouveau correctif ne serait jamais applique.
$script:CombatLogPatchMarker = "Yaya AbundanceTracker AutoPatch: no combat log registration"

function Get-AbundanceTrackerAutoPatchLogPath {
    return (Resolve-AddonPatchOutputPath -DefaultDirectory $PSScriptRoot -FileName "abundance-tracker-auto-patch.log")
}

function Get-AbundanceTrackerAutoPatchStartupPath {
    return (Join-Path ([Environment]::GetFolderPath("Startup")) $script:StartupLauncherName)
}

function Write-AbundanceTrackerAutoPatchLog {
    param(
        [Parameter(Mandatory = $true)][string]$Message,
        [switch]$Quiet
    )

    $logPath = Get-AbundanceTrackerAutoPatchLogPath
    New-Item -ItemType Directory -Path (Split-Path -Parent $logPath) -Force | Out-Null
    try {
        Invoke-AddonPatchLogRotation -LogPath $logPath
    } catch {
        # Une rotation qui echoue ne doit jamais empecher d'ecrire la ligne.
    }
    Add-Content -LiteralPath $logPath -Value ("[{0}] {1}" -f (Get-Date).ToString("s"), $Message) -Encoding UTF8
    if (-not $Quiet) {
        Write-Host $Message
    }
}

function Get-AbundanceTrackerAddonCandidates {
    $candidates = New-Object System.Collections.Generic.List[string]
    foreach ($root in @(
        [Environment]::GetEnvironmentVariable("ProgramFiles(x86)"),
        [Environment]::GetEnvironmentVariable("ProgramFiles")
    )) {
        if ($root) {
            $candidates.Add((Join-Path $root "World of Warcraft\_retail_\Interface\AddOns\AbundanceTracker"))
        }
    }
    $candidates.Add("C:\Program Files (x86)\World of Warcraft\_retail_\Interface\AddOns\AbundanceTracker")
    $candidates.Add("C:\Program Files\World of Warcraft\_retail_\Interface\AddOns\AbundanceTracker")
    return $candidates
}

function Resolve-AbundanceTrackerAddonPath {
    param([string]$AddonPath)

    if ($AddonPath) {
        $resolved = (Resolve-Path -LiteralPath $AddonPath -ErrorAction Stop).Path
        if (-not (Test-Path -LiteralPath (Join-Path $resolved "AbundanceTracker.toc") -PathType Leaf)) {
            throw "AbundanceTracker addon invalide: $resolved"
        }
        return $resolved
    }

    foreach ($candidate in (Get-AbundanceTrackerAddonCandidates)) {
        if (Test-Path -LiteralPath (Join-Path $candidate "AbundanceTracker.toc") -PathType Leaf) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }
    throw "AbundanceTracker introuvable. Passez -AddonPath explicitement."
}

function Get-AbundanceTrackerAddonVersion {
    param([Parameter(Mandatory = $true)][string]$AddonPath)

    $tocPath = Join-Path $AddonPath "AbundanceTracker.toc"
    $versionLine = Get-Content -LiteralPath $tocPath -ErrorAction Stop |
        Where-Object { $_ -match '^##\s*Version:\s*(.+)$' } |
        Select-Object -First 1
    if ($versionLine -and $versionLine -match '^##\s*Version:\s*(.+)$') {
        return $Matches[1].Trim()
    }
    return "unknown"
}

function Read-AbundanceTrackerTextFile {
    param([Parameter(Mandatory = $true)][string]$Path)

    $bytes = [IO.File]::ReadAllBytes($Path)
    $hasBom = $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
    $encoding = New-Object System.Text.UTF8Encoding($false, $true)
    $offset = if ($hasBom) { 3 } else { 0 }
    return [pscustomobject]@{
        Text = $encoding.GetString($bytes, $offset, $bytes.Length - $offset)
        HasBom = $hasBom
    }
}

function Write-AbundanceTrackerTextFileAtomically {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Text,
        [Parameter(Mandatory = $true)][bool]$HasBom
    )

    # Delegue a la primitive partagee : elle refuse d'ecrire un Lua dont la
    # syntaxe est incoherente et remplace le fichier via File::Replace, la
    # cible ne pouvant donc pas rester absente en cas de coupure.
    Write-AddonPatchTextAtomically -Path $Path -Text $Text -HasBom $HasBom -Label (Split-Path -Leaf $Path)
}

function Get-AbundanceTrackerSourceHash {
    param([Parameter(Mandatory = $true)][string]$Path)

    $sha256 = [Security.Cryptography.SHA256]::Create()
    try {
        return ([BitConverter]::ToString($sha256.ComputeHash([IO.File]::ReadAllBytes($Path)))).Replace("-", "")
    } finally {
        $sha256.Dispose()
    }
}

function Replace-AbundanceTrackerBlock {
    param(
        [Parameter(Mandatory = $true)][ref]$Content,
        [Parameter(Mandatory = $true)][string]$Original,
        [Parameter(Mandatory = $true)][string]$Patched,
        [Parameter(Mandatory = $true)][string]$Label
    )

    # Les blocs sont deja passes trimmes par les appelants : on normalise juste
    # les fins de ligne.
    $normalizedOriginal = [regex]::Replace($Original, "?
", "`n")
    $normalizedPatched = [regex]::Replace($Patched, "?
", "`n")
    if ($Content.Value.Contains($normalizedPatched)) {
        return $false
    }

    $occurrences = 0
    $index = $Content.Value.IndexOf($normalizedOriginal, [System.StringComparison]::Ordinal)
    while ($index -ge 0) {
        $occurrences++
        $index = $Content.Value.IndexOf($normalizedOriginal, $index + $normalizedOriginal.Length, [System.StringComparison]::Ordinal)
    }
    if ($occurrences -eq 0) {
        throw "Bloc AbundanceTracker attendu introuvable: $Label"
    }
    if ($occurrences -gt 1) {
        # Un ancrage qui matche plusieurs fois patcherait toutes les occurrences
        # sans que rien ne le signale.
        throw "Ancrage AbundanceTracker ambigu ($occurrences correspondances): $Label"
    }

    $Content.Value = $Content.Value.Replace($normalizedOriginal, $normalizedPatched)
    return $true
}

function Invoke-AbundanceTrackerAutoPatch {
    param(
        [string]$AddonPath,
        [switch]$Quiet,
        [switch]$DryRun
    )

    $resolvedAddonPath = Resolve-AbundanceTrackerAddonPath -AddonPath $AddonPath
    $version = Get-AbundanceTrackerAddonVersion -AddonPath $resolvedAddonPath
    $corePath = Join-Path $resolvedAddonPath "Core.lua"
    if (-not (Test-Path -LiteralPath $corePath -PathType Leaf)) {
        throw "Core.lua introuvable: $corePath"
    }

    $sourceHash = Get-AbundanceTrackerSourceHash -Path $corePath
    $file = Read-AbundanceTrackerTextFile -Path $corePath
    if ($file.Text.Contains($script:CombatLogPatchMarker)) {
        Write-AbundanceTrackerAutoPatchLog -Message ("already patched: AbundanceTracker {0}, SHA256 {1}" -f $version, $sourceHash) -Quiet:$Quiet
        return [pscustomobject]@{ Status = "AlreadyPatched"; Version = $version; Hash = $sourceHash; Path = $corePath }
    }

    $content = $file.Text.Replace("`r`n", "`n")
    $scanOriginal = @'
local function ScanBlessing()
    if not session.active then return end
    if not C_UnitAuras or not C_UnitAuras.GetAuraDataByIndex then return false end
    for i=1,40 do
        local aura=C_UnitAuras.GetAuraDataByIndex("player",i,"HELPFUL"); if not aura then break end
        local low = SafeAuraName(aura); if not low then break end
        if (low:find("bendici") and low:find("desgaste")) or (low:find("blessing") and low:find("attrition")) then
            session.blessingMult=math.max(session.blessingMult,2)
            local ok2,s = pcall(function() return aura.applications or 0 end); s = ok2 and s or 0
            if s>1 then session.blessingMult=math.max(session.blessingMult,s) end
            local ok3,pts = pcall(function() return aura.points end); pts = ok3 and pts or nil
            if pts then for _,v in ipairs(pts) do if v>1 and v<=10 then session.blessingMult=math.max(session.blessingMult,v) end end end
            Debug("[Blessing] mult="..session.blessingMult); return true
        elseif (low:find("abundan") and low:find("bonus")) or low:find("bonus event") then
            session.blessingMult=math.max(session.blessingMult,2)
            local ok2,s = pcall(function() return aura.applications or 0 end); s = ok2 and s or 0
            if s>1 then session.blessingMult=math.max(session.blessingMult,s) end
            Debug("[Blessing] mult="..session.blessingMult); return true
        end
    end
    return false
end
'@.Trim()

    $scanPatched = @'
-- Yaya AbundanceTracker AutoPatch: secret-safe aura queries
local function SafePlayerAuraBySpellID(spellID)
    if not C_UnitAuras or type(C_UnitAuras.GetPlayerAuraBySpellID) ~= "function" then return nil end
    local ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, spellID)
    if not ok then return nil end
    return aura
end

local function ScanBlessing()
    if not session.active then return end
    if SafePlayerAuraBySpellID(SID_BONUS_AURA) then
        session.blessingMult=math.max(session.blessingMult,2)
        Debug("[Blessing] mult="..session.blessingMult)
        return true
    end
    return false
end
'@.Trim()

    $findOriginal = @'
local function FindAbundanceBuff()
    if not C_UnitAuras or not C_UnitAuras.GetAuraDataByIndex then return false end
    for i=1,40 do
        local aura=C_UnitAuras.GetAuraDataByIndex("player",i,"HELPFUL"); if not aura then break end
        local low = SafeAuraName(aura); if not low then break end
        if low:find("abundan") or low:find("dundun") then return true end
        if low:find("bendici") and low:find("desgaste") then return true end
        if low:find("blessing") and low:find("attrition") then return true end
    end
    return false
end
'@.Trim()

    $findPatched = @'
local function FindAbundanceBuff()
    return SafePlayerAuraBySpellID(SID_HEALTH_AURA) ~= nil
        or SafePlayerAuraBySpellID(SID_BONUS_AURA) ~= nil
end
'@.Trim()

    $contextOriginal = @'
local function IsAbundanceContext()
    if session.active then return true end
    local bag = ReadWidget(WID_BAG)
    local altar = ReadWidget(WID_ALTAR)
    if bag ~= nil or altar ~= nil then return true end
    return false
end
'@.Trim()

    $contextPatched = @'
local function IsAbundanceContext()
    local bag = ReadWidget(WID_BAG)
    local altar = ReadWidget(WID_ALTAR)
    return bag ~= nil or altar ~= nil
end
'@.Trim()

    $stateOriginal = 'local function UpdateDisplay() end'
    $statePatched = @'
local function UpdateDisplay() end
local SetDisplayVisible
local SyncAbundanceContext
local lastAbundanceContext
'@.Trim()

    $startOriginal = 'LogMsg("=== EVENT START: "..session.zone.." ==="); Print(string.format(L["EVENT_DETECTED"], session.zone)); ScanBlessing()'
    $startPatched = @'
LogMsg("=== EVENT START: "..session.zone.." ==="); Print(string.format(L["EVENT_DETECTED"], session.zone)); ScanBlessing()
if SetDisplayVisible then SetDisplayVisible(true) end
'@.Trim()

    $displayOriginal = 'display:SetFrameStrata("HIGH"); display:SetFrameLevel(10)'
    $displayPatched = @'
display:SetFrameStrata("HIGH"); display:SetFrameLevel(10)

-- Yaya AbundanceTracker AutoPatch: automatic event visibility
SetDisplayVisible = function(visible)
    if visible then display:Show() else display:Hide() end
    isVisible=visible
    if db then db.visible=visible end
end

SyncAbundanceContext = function()
    local inContext=IsAbundanceContext()
    if inContext==lastAbundanceContext then
        if not inContext and display:IsShown() then SetDisplayVisible(false) end
        return inContext
    end
    lastAbundanceContext=inContext
    if inContext then
        LogMsg("=== ABUNDANCE CONTEXT ENTER ===")
        if not session.active then StartEvent() end
        SetDisplayVisible(true)
    else
        if session.active then StopEvent() end
        LogMsg("=== ABUNDANCE CONTEXT EXIT ===")
        SetDisplayVisible(false)
    end
    UpdateDisplay()
    return inContext
end
'@.Trim()

    $loadedOriginal = @'
display:SetScale(db.scale); if db.visible then display:Show() else display:Hide(); isVisible=false end
        UpdateMinimapPos(db.minimapAngle); Print(L["LOADED"]) end
'@.Trim()
    $loadedPatched = @'
display:SetScale(db.scale)
lastAbundanceContext=nil
UpdateMinimapPos(db.minimapAngle)
SyncAbundanceContext()
Print(L["LOADED"]) end
'@.Trim()

    $loginOriginal = @'
    elseif event=="PLAYER_LOGIN" or event=="PLAYER_ENTERING_WORLD" then
        if IsAbundanceContext() then OnAuraChange("player") end
'@.Trim()
    $loginPatched = @'
    elseif event=="PLAYER_LOGIN" or event=="PLAYER_ENTERING_WORLD" then
        SyncAbundanceContext()
        if IsAbundanceContext() then OnAuraChange("player") end
'@.Trim()

    $eventsOriginal = '"ADDON_LOADED","PLAYER_LOGIN","PLAYER_ENTERING_WORLD",'
    $eventsPatched = '"ADDON_LOADED","PLAYER_LOGIN","PLAYER_ENTERING_WORLD","ZONE_CHANGED","ZONE_CHANGED_INDOORS","ZONE_CHANGED_NEW_AREA",'

    $tickerOriginal = 'local sc=0; C_Timer.NewTicker(0.5, function()'
    $tickerPatched = 'local sc=0; C_Timer.NewTicker(0.5, function() SyncAbundanceContext()'

    $widgetEventOriginal = 'elseif event=="UPDATE_UI_WIDGET" then local w=...; if w and w.widgetID then OnWidgetUpdate(w.widgetID) end'
    $widgetEventPatched = 'elseif event=="UPDATE_UI_WIDGET" then SyncAbundanceContext(); local w=...; if w and w.widgetID then OnWidgetUpdate(w.widgetID) end'

    $powerShowOriginal = 'elseif event=="UNIT_POWER_BAR_SHOW" then local u=...; if u=="player" and not session.active and IsAbundanceContext() then StartEvent(); UpdateDisplay() end'
    $powerShowPatched = 'elseif event=="UNIT_POWER_BAR_SHOW" then SyncAbundanceContext()'

    $powerHideOriginal = 'elseif event=="UNIT_POWER_BAR_HIDE" then local u=...; if u=="player" and session.active then C_Timer.After(2, function() if session.active then StopEvent(); UpdateDisplay() end end) end'
    $powerHidePatched = 'elseif event=="UNIT_POWER_BAR_HIDE" then SyncAbundanceContext()'

    $auraEventOriginal = 'elseif event=="UNIT_AURA" then OnAuraChange(...)'
    $auraEventPatched = 'elseif event=="UNIT_AURA" then SyncAbundanceContext(); OnAuraChange(...)'

    $initialDisplayOriginal = 'display:Show(); UpdateDisplay()'
    $initialDisplayPatched = 'display:Hide(); UpdateDisplay()'

    # Cause du popup "action non autorisee" a chaque connexion, etablie par la
    # pile capturee : ABT:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED") emet
    # ADDON_ACTION_FORBIDDEN. En 12.1 cet evenement porte HasRestrictions et son
    # enregistrement est refuse aux addons ; C_CombatLogSecure, la seule autre
    # voie, est declare SecureOnly. Le pcall de TryRegisterEvents masque l'erreur
    # Lua mais pas le signal, qui est emis par le client et declenche le
    # dialogue.
    $combatLogEventsOriginal = '"UNIT_SPELLCAST_SUCCEEDED","COMBAT_LOG_EVENT_UNFILTERED",'
    $combatLogEventsPatched = @'
-- Yaya AbundanceTracker AutoPatch: no combat log registration
    -- COMBAT_LOG_EVENT_UNFILTERED n'est plus enregistre : en 12.1 son
    -- enregistrement est refuse aux addons et declenche le dialogue proposant de
    -- desactiver l'addon a chaque connexion. La branche OnCombatLog du
    -- gestionnaire d'evenements devient donc inatteignable. La benediction reste
    -- detectee par l'aura (ScanBlessing), par le cri du monstre
    -- (CHAT_MSG_MONSTER_YELL) et par le sort lance (UNIT_SPELLCAST_SUCCEEDED).
    "UNIT_SPELLCAST_SUCCEEDED",
'@.Trim()

    $changed = $false
    $changed = (Replace-AbundanceTrackerBlock -Content ([ref]$content) -Original $scanOriginal -Patched $scanPatched -Label "ScanBlessing") -or $changed
    $changed = (Replace-AbundanceTrackerBlock -Content ([ref]$content) -Original $findOriginal -Patched $findPatched -Label "FindAbundanceBuff") -or $changed
    $auraPatchPresent = $content.Contains($script:PatchMarker) -and -not $content.Contains("GetAuraDataByIndex")
    if ((-not $changed -and -not $auraPatchPresent) -or $content.Contains("GetAuraDataByIndex")) {
        throw "Le patch AbundanceTracker n'a pas supprimé toutes les lectures GetAuraDataByIndex."
    }

    # La famille de visibilite est sautee en bloc quand son marqueur est deja
    # present. S'en remettre a la detection par bloc ne suffit pas : celle-ci
    # compare le texte patche caractere pour caractere, or le Core.lua installe
    # peut avoir ete retouche a la main. Une simple difference d'indentation fait
    # alors echouer la comparaison, l'ancre d'origine est toujours trouvee, et le
    # bloc est reinsere une seconde fois. C'est exactement ce qui a duplique
    # SetDisplayVisible et SyncAbundanceContext lors de l'ajout de la famille
    # suivante.
    if (-not $content.Contains($script:VisibilityPatchMarker)) {
        $changed = (Replace-AbundanceTrackerBlock -Content ([ref]$content) -Original $contextOriginal -Patched $contextPatched -Label "IsAbundanceContext") -or $changed
        $changed = (Replace-AbundanceTrackerBlock -Content ([ref]$content) -Original $stateOriginal -Patched $statePatched -Label "visibility state") -or $changed
        $changed = (Replace-AbundanceTrackerBlock -Content ([ref]$content) -Original $startOriginal -Patched $startPatched -Label "StartEvent visibility") -or $changed
        $changed = (Replace-AbundanceTrackerBlock -Content ([ref]$content) -Original $displayOriginal -Patched $displayPatched -Label "visibility sync") -or $changed
        $changed = (Replace-AbundanceTrackerBlock -Content ([ref]$content) -Original $loadedOriginal -Patched $loadedPatched -Label "ADDON_LOADED visibility") -or $changed
        $changed = (Replace-AbundanceTrackerBlock -Content ([ref]$content) -Original $loginOriginal -Patched $loginPatched -Label "login visibility") -or $changed
        $changed = (Replace-AbundanceTrackerBlock -Content ([ref]$content) -Original $eventsOriginal -Patched $eventsPatched -Label "zone events") -or $changed
        $changed = (Replace-AbundanceTrackerBlock -Content ([ref]$content) -Original $tickerOriginal -Patched $tickerPatched -Label "context ticker") -or $changed
        $changed = (Replace-AbundanceTrackerBlock -Content ([ref]$content) -Original $widgetEventOriginal -Patched $widgetEventPatched -Label "widget visibility") -or $changed
        $changed = (Replace-AbundanceTrackerBlock -Content ([ref]$content) -Original $powerShowOriginal -Patched $powerShowPatched -Label "power bar show visibility") -or $changed
        $changed = (Replace-AbundanceTrackerBlock -Content ([ref]$content) -Original $powerHideOriginal -Patched $powerHidePatched -Label "power bar hide visibility") -or $changed
        $changed = (Replace-AbundanceTrackerBlock -Content ([ref]$content) -Original $auraEventOriginal -Patched $auraEventPatched -Label "aura visibility") -or $changed
        if ($content.Contains($initialDisplayOriginal)) {
            $content = $content.Replace($initialDisplayOriginal, $initialDisplayPatched)
            $changed = $true
        }
    }

    $changed = (Replace-AbundanceTrackerBlock -Content ([ref]$content) -Original $combatLogEventsOriginal -Patched $combatLogEventsPatched -Label "combat log registration") -or $changed
    if ($content.Contains($combatLogEventsOriginal)) {
        # Le seul echec qui compte ici : l'evenement reste dans ALL_EVENTS, donc
        # le popup reviendrait a chaque connexion. Son nom subsiste ailleurs dans
        # le fichier, sur la branche desormais morte du gestionnaire, ce qui est
        # attendu et ne doit pas faire echouer le patch.
        throw "Le patch AbundanceTracker laisse COMBAT_LOG_EVENT_UNFILTERED dans ALL_EVENTS."
    }
    if (-not $changed -or -not $content.Contains($script:VisibilityPatchMarker)) {
        throw "Le patch de visibilité AbundanceTracker n'a pas été appliqué."
    }
    if (-not $content.Contains($script:CombatLogPatchMarker)) {
        # Sans ce marqueur, la detection en tete de fonction considererait le
        # fichier comme non patche et le travail serait refait a chaque passage
        # du watcher.
        throw "Le patch AbundanceTracker n'a pas pose le marqueur de non-enregistrement du combat log."
    }

    $newline = if ($file.Text.Contains("`r`n")) { "`r`n" } else { "`n" }
    $patchedText = $content.Replace("`n", $newline)
    if ($DryRun) {
        Write-AbundanceTrackerAutoPatchLog -Message ("dry-run: AbundanceTracker {0} needs patch, SHA256 {1}" -f $version, $sourceHash) -Quiet:$Quiet
        return [pscustomobject]@{ Status = "NeedsPatch"; Version = $version; Hash = $sourceHash; Path = $corePath }
    }

    $backupRoot = Join-Path ([Environment]::GetFolderPath("LocalApplicationData")) "YayaTools\AbundanceTrackerAutoPatch\backups"
    New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
    $safeVersion = $version -replace '[^A-Za-z0-9._-]', '_'
    $backupPath = Join-Path $backupRoot ("Core.lua.{0}.{1}.bak" -f $safeVersion, (Get-Date).ToString("yyyyMMdd-HHmmss"))
    Copy-Item -LiteralPath $corePath -Destination $backupPath -Force
    Write-AbundanceTrackerTextFileAtomically -Path $corePath -Text $patchedText -HasBom $file.HasBom

    $patchedHash = Get-AbundanceTrackerSourceHash -Path $corePath
    Write-AbundanceTrackerAutoPatchLog -Message ("patched AbundanceTracker {0}: {1} -> {2}; backup={3}" -f $version, $sourceHash, $patchedHash, $backupPath) -Quiet:$Quiet
    return [pscustomobject]@{ Status = "Patched"; Version = $version; Hash = $patchedHash; Backup = $backupPath; Path = $corePath }
}
