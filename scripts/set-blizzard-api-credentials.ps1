[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

function Read-RequiredValue([string]$Prompt) {
    do {
        $value = (Read-Host $Prompt).Trim()
    } while ([string]::IsNullOrWhiteSpace($value))

    return $value
}

$clientId = Read-RequiredValue "Blizzard Client ID"
$secretSecure = Read-Host "Blizzard Client Secret" -AsSecureString
$secretPointer = [IntPtr]::Zero

try {
    $secretPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secretSecure)
    $clientSecret = ([Runtime.InteropServices.Marshal]::PtrToStringBSTR($secretPointer)).Trim()
}
finally {
    if ($secretPointer -ne [IntPtr]::Zero) {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($secretPointer)
    }
}

if ([string]::IsNullOrWhiteSpace($clientSecret)) {
    throw "Le Client Secret ne peut pas être vide."
}

[Environment]::SetEnvironmentVariable("BLIZZARD_CLIENT_ID", $clientId, "User")
[Environment]::SetEnvironmentVariable("BLIZZARD_CLIENT_SECRET", $clientSecret, "User")

$storedId = [Environment]::GetEnvironmentVariable("BLIZZARD_CLIENT_ID", "User")
$storedSecret = [Environment]::GetEnvironmentVariable("BLIZZARD_CLIENT_SECRET", "User")

if ($storedId -ne $clientId -or $storedSecret -ne $clientSecret) {
    throw "La vérification des variables Blizzard a échoué."
}

Write-Host "Identifiants Blizzard enregistrés pour ton compte Windows."
Write-Host "Ferme et rouvre WoW Tools pour qu'il les récupère."
