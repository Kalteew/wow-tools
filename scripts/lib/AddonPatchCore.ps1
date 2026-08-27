<#
.SYNOPSIS
    Primitives communes aux auto-patchs d'addons (TSM, AbundanceTracker, WQT).

.DESCRIPTION
    Regroupe ce que les trois modules d'auto-patch faisaient chacun a leur
    facon, avec des niveaux de robustesse inegaux :

      - controle de syntaxe Lua avant ecriture, pour ne jamais laisser un bloc
        de remplacement casser l'addon au prochain rechargement ;
      - ecriture atomique preservant le BOM UTF-8 ;
      - rotation du journal ;
      - notification systeme, le watcher tournant fenetre masquee ;
      - suivi des echecs consecutifs, pour n'alerter que sur ce qui persiste.

    A dot-sourcer depuis le module de patch de chaque addon.

.NOTES
    Les variables $script: ci-dessous sont initialisees ici : sous
    Set-StrictMode -Version Latest, une variable non initialisee leve une
    erreur a la lecture.
#>

$script:AddonPatchLuacCommand = $null
$script:AddonPatchLastLuaError = $null
$script:AddonPatchLogMaxBytes = 1MB
$script:AddonPatchLogRetainedFiles = 3

# Les tests redirigent journaux et fichiers d'etat vers un dossier temporaire
# pour ne pas polluer le diagnostic des installations reelles.
$script:AddonPatchOutputOverride = $null

function Set-AddonPatchOutputPath {
    param(
        [AllowEmptyString()]
        [AllowNull()]
        [string]$Path
    )

    $script:AddonPatchOutputOverride = $Path
}

function Resolve-AddonPatchOutputPath {
    <#
    .SYNOPSIS
        Renvoie le chemin de sortie effectif pour un fichier de journal ou
        d'etat, en tenant compte d'une eventuelle redirection de test.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$DefaultDirectory,
        [Parameter(Mandatory = $true)]
        [string]$FileName
    )

    if ($script:AddonPatchOutputOverride) {
        return Join-Path $script:AddonPatchOutputOverride $FileName
    }
    return Join-Path $DefaultDirectory $FileName
}

function Get-AddonPatchLastLuaError {
    return $script:AddonPatchLastLuaError
}

function Get-AddonPatchLongBracketLevel {
    # Renvoie le niveau d'un long bracket Lua ouvrant a la position donnee
    # ([[ = 0, [=[ = 1, [==[ = 2 ...), ou -1 si ce n'est pas un long bracket.
    param(
        [Parameter(Mandatory = $true)]
        [string]$Content,
        [Parameter(Mandatory = $true)]
        [int]$Index
    )

    if ($Index -ge $Content.Length -or $Content[$Index] -ne '[') {
        return -1
    }
    $cursor = $Index + 1
    $level = 0
    while ($cursor -lt $Content.Length -and $Content[$cursor] -eq '=') {
        $level++
        $cursor++
    }
    if ($cursor -lt $Content.Length -and $Content[$cursor] -eq '[') {
        return $level
    }
    return -1
}

function Test-AddonPatchLuaSyntax {
    <#
    .SYNOPSIS
        Controle de coherence syntaxique d'une source Lua patchee.

    .DESCRIPTION
        Utilise luac -p lorsqu'il est disponible. A defaut, applique un controle
        autonome : tokenisation des commentaires et des chaines (courtes et
        longues), puis equilibrage des blocs ouvrants (function / if / do) et
        fermants (end).

        Le but n'est pas de valider tout Lua, mais d'attraper ce qui casse
        concretement un addon apres un patch : un end en trop ou en moins, une
        chaine non fermee.

        La raison de l'echec est lisible via Get-AddonPatchLastLuaError.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Content,
        [Parameter(Mandatory = $true)]
        [string]$Label
    )

    $script:AddonPatchLastLuaError = $null

    if ([string]::IsNullOrEmpty($Content)) {
        return $true
    }

    if ($null -eq $script:AddonPatchLuacCommand) {
        $found = $null
        foreach ($candidate in @("luac", "luac54", "luac5.4", "luac53", "luac5.3")) {
            $command = Get-Command $candidate -ErrorAction SilentlyContinue
            if ($command) {
                $found = $command.Source
                break
            }
        }
        # Chaine vide = recherche deja faite, aucun luac disponible.
        $script:AddonPatchLuacCommand = if ($found) { $found } else { "" }
    }

    if ($script:AddonPatchLuacCommand) {
        $tempPath = Join-Path ([System.IO.Path]::GetTempPath()) ("addon-lua-check-{0}.lua" -f [guid]::NewGuid().ToString("N"))
        try {
            [System.IO.File]::WriteAllText($tempPath, $Content, [System.Text.UTF8Encoding]::new($false))
            $output = & $script:AddonPatchLuacCommand "-p" $tempPath 2>&1
            if ($LASTEXITCODE -ne 0) {
                $script:AddonPatchLastLuaError = "luac -p a rejete $Label : $($output -join ' ')"
                return $false
            }
            return $true
        } catch {
            $script:AddonPatchLuacCommand = ""
        } finally {
            if (Test-Path -LiteralPath $tempPath) {
                Remove-Item -LiteralPath $tempPath -Force -ErrorAction SilentlyContinue
            }
        }
    }

    $length = $Content.Length
    $index = 0
    $line = 1
    $depth = 0
    $openLines = New-Object System.Collections.Generic.Stack[int]

    while ($index -lt $length) {
        $char = $Content[$index]

        if ($char -eq "`n") {
            $line++
            $index++
            continue
        }

        # Commentaire (court ou long)
        if ($char -eq '-' -and ($index + 1) -lt $length -and $Content[$index + 1] -eq '-') {
            $index += 2
            $level = Get-AddonPatchLongBracketLevel -Content $Content -Index $index
            if ($level -ge 0) {
                $closing = "]" + ("=" * $level) + "]"
                $closeIndex = $Content.IndexOf($closing, $index, [System.StringComparison]::Ordinal)
                if ($closeIndex -lt 0) {
                    $script:AddonPatchLastLuaError = "commentaire long non ferme dans $Label (ligne $line)"
                    return $false
                }
                $line += ($Content.Substring($index, $closeIndex - $index).Split("`n").Length - 1)
                $index = $closeIndex + $closing.Length
            } else {
                $newlineIndex = $Content.IndexOf("`n", $index)
                $index = if ($newlineIndex -lt 0) { $length } else { $newlineIndex }
            }
            continue
        }

        # Chaine longue
        if ($char -eq '[') {
            $level = Get-AddonPatchLongBracketLevel -Content $Content -Index $index
            if ($level -ge 0) {
                $opening = "[" + ("=" * $level) + "["
                $closing = "]" + ("=" * $level) + "]"
                $searchFrom = $index + $opening.Length
                $closeIndex = $Content.IndexOf($closing, $searchFrom, [System.StringComparison]::Ordinal)
                if ($closeIndex -lt 0) {
                    $script:AddonPatchLastLuaError = "chaine longue non fermee dans $Label (ligne $line)"
                    return $false
                }
                $line += ($Content.Substring($searchFrom, $closeIndex - $searchFrom).Split("`n").Length - 1)
                $index = $closeIndex + $closing.Length
                continue
            }
        }

        # Chaine courte
        if ($char -eq '"' -or $char -eq "'") {
            $quote = $char
            $index++
            $terminated = $false
            while ($index -lt $length) {
                $current = $Content[$index]
                if ($current -eq [char]92) {
                    # Un backslash echappe le caractere suivant, y compris le
                    # retour a la ligne qui prolonge alors la chaine.
                    $index += 2
                    continue
                }
                if ($current -eq "`n") {
                    break
                }
                if ($current -eq $quote) {
                    $terminated = $true
                    $index++
                    break
                }
                $index++
            }
            if (-not $terminated) {
                $script:AddonPatchLastLuaError = "chaine non fermee dans $Label (ligne $line)"
                return $false
            }
            continue
        }

        # Identifiant ou mot-cle
        if ([char]::IsLetter($char) -or $char -eq '_') {
            $start = $index
            while ($index -lt $length -and ([char]::IsLetterOrDigit($Content[$index]) -or $Content[$index] -eq '_')) {
                $index++
            }
            $word = $Content.Substring($start, $index - $start)
            # Lua est sensible a la casse : sans -CaseSensitive, PowerShell
            # ferait matcher un identifiant comme "If" ou "End" avec le mot-cle.
            switch -CaseSensitive ($word) {
                "function" { $depth++; $openLines.Push($line) }
                "if"       { $depth++; $openLines.Push($line) }
                "do"       { $depth++; $openLines.Push($line) }
                "end" {
                    $depth--
                    if ($depth -lt 0) {
                        $script:AddonPatchLastLuaError = "end en trop dans $Label (ligne $line)"
                        return $false
                    }
                    $openLines.Pop() | Out-Null
                }
            }
            continue
        }

        $index++
    }

    if ($depth -ne 0) {
        $openedAt = if ($openLines.Count -gt 0) { $openLines.Peek() } else { 0 }
        $script:AddonPatchLastLuaError = "$depth bloc(s) non ferme(s) dans $Label (dernier ouvert ligne $openedAt)"
        return $false
    }

    return $true
}

function Read-AddonPatchTextFile {
    <#
    .SYNOPSIS
        Lit un fichier source en signalant la presence d'un BOM UTF-8.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $bytes = [System.IO.File]::ReadAllBytes($Path)
    $hasBom = $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
    $encoding = [System.Text.UTF8Encoding]::new($false, $true)
    $offset = if ($hasBom) { 3 } else { 0 }
    try {
        $text = $encoding.GetString($bytes, $offset, $bytes.Length - $offset)
    } catch {
        throw "Le patch ne prend en charge que des sources UTF-8 valides ($Path). $($_.Exception.Message)"
    }
    return [pscustomobject]@{
        Text = $text
        HasBom = $hasBom
        Bytes = $bytes
    }
}

function Write-AddonPatchBytesAtomically {
    <#
    .SYNOPSIS
        Remplace un fichier de facon atomique.

    .DESCRIPTION
        File::Replace conserve l'entree de repertoire d'origine et cree une
        sauvegarde temporaire le temps du basculement, contrairement a un
        Move-Item -Force qui peut laisser la cible absente en cas de coupure.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,
        [Parameter(Mandatory = $true)]
        [byte[]]$Bytes
    )

    $token = [guid]::NewGuid().ToString('N')
    $tempPath = "$FilePath.yaya-patch-$token.tmp"
    $replaceBackupPath = "$FilePath.yaya-patch-$token.bak"
    try {
        [System.IO.File]::WriteAllBytes($tempPath, $Bytes)
        [System.IO.File]::Replace($tempPath, $FilePath, $replaceBackupPath, $true)
    } finally {
        foreach ($leftover in @($tempPath, $replaceBackupPath)) {
            if (Test-Path -LiteralPath $leftover) {
                Remove-Item -LiteralPath $leftover -Force -ErrorAction SilentlyContinue
            }
        }
    }
}

function Write-AddonPatchTextAtomically {
    <#
    .SYNOPSIS
        Ecrit un texte Lua apres validation de sa syntaxe.

    .DESCRIPTION
        Refuse d'ecrire une source dont la syntaxe est incoherente : c'est le
        garde-fou qui evite de casser l'addon jusqu'au prochain patch reussi.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [string]$Text,
        [Parameter(Mandatory = $true)]
        [bool]$HasBom,
        [Parameter(Mandatory = $true)]
        [string]$Label,
        [switch]$SkipSyntaxCheck
    )

    if (-not $SkipSyntaxCheck) {
        if (-not (Test-AddonPatchLuaSyntax -Content $Text -Label $Label)) {
            throw "Patch refuse, Lua invalide : $(Get-AddonPatchLastLuaError)"
        }
    }

    $encoding = [System.Text.UTF8Encoding]::new($false, $true)
    $payload = $encoding.GetBytes($Text)
    if ($HasBom) {
        $withBom = New-Object byte[] ($payload.Length + 3)
        $withBom[0] = 0xEF
        $withBom[1] = 0xBB
        $withBom[2] = 0xBF
        [System.Array]::Copy($payload, 0, $withBom, 3, $payload.Length)
        $payload = $withBom
    }
    Write-AddonPatchBytesAtomically -FilePath $Path -Bytes $payload
}

function Invoke-AddonPatchLogRotation {
    <#
    .SYNOPSIS
        Fait tourner un journal qui depasse la taille maximale.

    .DESCRIPTION
        Les watchers ecrivent au moins une ligne toutes les 30 minutes : sans
        rotation les journaux grossissent indefiniment. On conserve le fichier
        courant plus $script:AddonPatchLogRetainedFiles archives numerotees.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$LogPath
    )

    $existing = Get-Item -LiteralPath $LogPath -ErrorAction SilentlyContinue
    if (-not $existing -or $existing.Length -lt $script:AddonPatchLogMaxBytes) {
        return
    }

    $retain = $script:AddonPatchLogRetainedFiles
    $oldest = "$LogPath.$retain"
    if (Test-Path -LiteralPath $oldest) {
        Remove-Item -LiteralPath $oldest -Force -ErrorAction SilentlyContinue
    }
    for ($index = $retain - 1; $index -ge 1; $index--) {
        $source = "$LogPath.$index"
        if (Test-Path -LiteralPath $source) {
            Move-Item -LiteralPath $source -Destination "$LogPath.$($index + 1)" -Force -ErrorAction SilentlyContinue
        }
    }
    Move-Item -LiteralPath $LogPath -Destination "$LogPath.1" -Force -ErrorAction SilentlyContinue
}

function Send-AddonPatchNotification {
    <#
    .SYNOPSIS
        Affiche une notification systeme decrivant un patch en echec.

    .DESCRIPTION
        Les watchers tournent fenetre masquee : sans notification, un ancrage
        perime n'est visible que dans le journal. En aout 2026 un meme patch TSM
        a ainsi echoue 118 fois de suite (environ 59 heures) sans que rien ne le
        signale.

        Deux canaux sont tentes : toast WinRT (disponible sous Windows
        PowerShell, le contexte des watchers) puis infobulle NotifyIcon
        (PowerShell 7).
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Title,
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    try {
        [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
        [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom, ContentType = WindowsRuntime] | Out-Null
        $template = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent([Windows.UI.Notifications.ToastTemplateType]::ToastText02)
        $texts = $template.GetElementsByTagName("text")
        $texts.Item(0).AppendChild($template.CreateTextNode($Title)) | Out-Null
        $texts.Item(1).AppendChild($template.CreateTextNode($Message)) | Out-Null
        $notifier = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier("{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\WindowsPowerShell\v1.0\powershell.exe")
        $notifier.Show([Windows.UI.Notifications.ToastNotification]::new($template))
        return $true
    } catch {
        # WinRT indisponible (PowerShell 7) : on tente l'infobulle.
    }

    try {
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
        $icon = New-Object System.Windows.Forms.NotifyIcon
        try {
            $icon.Icon = [System.Drawing.SystemIcons]::Warning
            $icon.Visible = $true
            $icon.ShowBalloonTip(10000, $Title, $Message, [System.Windows.Forms.ToolTipIcon]::Warning)
            Start-Sleep -Milliseconds 400
            return $true
        } finally {
            $icon.Visible = $false
            $icon.Dispose()
        }
    } catch {
        return $false
    }
}

function New-AddonPatchFailureTracker {
    <#
    .SYNOPSIS
        Etat de suivi des echecs consecutifs, partage entre deux passages.
    #>
    return [pscustomobject]@{
        FailureCounts = @{}
        AlertedPatches = @{}
    }
}

function Update-AddonPatchFailureTracker {
    <#
    .SYNOPSIS
        Met a jour le suivi et renvoie les notifications a emettre.

    .DESCRIPTION
        C'est la persistance d'un echec, non son occurrence isolee, qui merite
        une notification : pendant une mise a jour d'addon les fichiers sont
        reecrits un par un et un ancrage peut manquer une seule fois. On
        notifie donc au bout de -AlertThreshold passages consecutifs, une seule
        fois, puis on signale le retablissement.

    .PARAMETER CurrentFailures
        Table nom de patch -> message d'erreur pour le passage courant. Vide
        lorsque tout va bien.
    #>
    param(
        [Parameter(Mandatory = $true)]
        $Tracker,
        [Parameter(Mandatory = $true)]
        [hashtable]$CurrentFailures,
        [int]$AlertThreshold = 2,
        [string]$Subject = "Patch"
    )

    $notifications = New-Object System.Collections.Generic.List[object]
    $counts = $Tracker.FailureCounts
    $alerted = $Tracker.AlertedPatches

    foreach ($name in @($counts.Keys)) {
        if (-not $CurrentFailures.ContainsKey($name)) {
            $counts.Remove($name)
            if ($alerted.ContainsKey($name)) {
                $alerted.Remove($name)
                $notifications.Add([pscustomobject]@{
                    Kind = "recovered"
                    Name = $name
                    Title = "$Subject retabli"
                    Message = ("Le patch {0} s'applique a nouveau." -f $name)
                })
            }
        }
    }

    foreach ($name in $CurrentFailures.Keys) {
        $count = 1
        if ($counts.ContainsKey($name)) {
            $count = [int]$counts[$name] + 1
        }
        $counts[$name] = $count

        if ($count -ge $AlertThreshold -and -not $alerted.ContainsKey($name)) {
            $alerted[$name] = $true
            $notifications.Add([pscustomobject]@{
                Kind = "failed"
                Name = $name
                Count = $count
                Title = "$Subject en echec"
                Message = ("{0} echoue depuis {1} passages. Detail : {2}" -f $name, $count, $CurrentFailures[$name])
            })
        }
    }

    return $notifications.ToArray()
}
