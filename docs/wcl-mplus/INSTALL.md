# Installation locale WCL M+

Ce guide concerne le prototype Windows actuel. Il fonctionne sans serveur public : le worker et son cache restent sur le PC ; seul le worker contacte Warcraft Logs.

## Ce qui fonctionne aujourd’hui

Le worker local peut interroger WCL, garder un cache local et fournir le dernier résultat à la page `wcl_mplus/overlay/index.html`. Cette page de démonstration s’ouvre dans un navigateur séparé et contient un simulateur JSON.

La détection automatique des candidats en jeu n’est pas encore installable sur un autre PC : `wcl_mplus/companion/ow-electron.json` est un descripteur de prototype, pas la configuration d’une application Overwolf empaquetée, et le companion n’a pas encore de démarrage relié au client Overwolf. La page overlay ne recevra donc pas encore automatiquement les candidats de la recherche de groupe.

## Prérequis

- Windows 10/11.
- Node.js 18 ou plus récent.
- Un compte Warcraft Logs et une application API personnelle créée dans [les réglages API WCL](https://www.warcraftlogs.com/api/).
- Overwolf n’est pas nécessaire pour essayer le worker et la page de démonstration. Il sera nécessaire pour la future capture automatique et l’affichage en surimpression dans le jeu.

Chaque personne doit utiliser ses propres identifiants WCL. Ne partagez pas le `Client Secret` dans le code, une archive ou un dépôt. Il reste uniquement dans l’environnement local du worker.

## Copier les fichiers sur l’autre PC

Copier le seul dossier `wcl_mplus/` dans un emplacement local, par exemple `C:\WCL-MPlus`. Ne pas copier tout le dépôt : il contient d’autres données locales, journaux et rapports sans rapport avec l’installation.

Ouvrir PowerShell dans le dossier copié. Saisir le Client ID puis le Client Secret à l’invite masquée, démarrer le worker et effacer les variables quand il s’arrête :

```powershell
$env:WCL_CLIENT_ID = Read-Host 'WCL Client ID'
$secureSecret = Read-Host 'WCL Client Secret' -AsSecureString
$secretPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureSecret)
try {
    $env:WCL_CLIENT_SECRET = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($secretPointer)
    node .\worker\server.js
}
finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($secretPointer)
    Remove-Item Env:WCL_CLIENT_ID -ErrorAction SilentlyContinue
    Remove-Item Env:WCL_CLIENT_SECRET -ErrorAction SilentlyContinue
}
```

Garder cette fenêtre ouverte pendant l’utilisation. Le service n’écoute que sur `127.0.0.1:28777`.

Dans une seconde fenêtre PowerShell, vérifier le démarrage :

```powershell
Invoke-RestMethod http://127.0.0.1:28777/v1/health
```

## Ouvrir la page de démonstration

Depuis le dossier `C:\WCL-MPlus`, ouvrir `overlay\index.html` dans un navigateur. La page interroge le worker local et son simulateur JSON permet de vérifier le rendu sans envoyer de requête WCL.

Cette page est une fenêtre navigateur classique : elle ne se place pas encore au-dessus de WoW et n’observe pas les candidatures réelles. Le mode `--dry-run` permet de lancer le worker sans appeler WCL, mais il ne produit que des états d’attente.

## Afficher les informations en jeu sans `/reload`

Une frame créée par un addon WoW ne peut pas recevoir directement les réponses HTTP du worker ni lire le cache du PC. Les SavedVariables ne forment pas un canal de mise à jour à chaud ; les modifier depuis un autre programme ne met pas à jour l’état Lua déjà chargé en jeu. L’addon livré est donc facultatif et n’affiche pas de parse.

La solution adaptée est une vraie application Overwolf avec GEP et son package d’overlay : elle peut lire `game_info/group_applicants`, appeler le worker local et dessiner une surimpression dans WoW, sans `/reload`. Overwolf documente bien `group_applicants` pour WoW Retail, mais le packaging et le branchement au runtime Overwolf restent à réaliser dans ce projet. Le prochain jalon est une application Overwolf lançable en mode développement, puis un test en jeu ; cette étape ne demande pas de serveur public.

Références : [données WoW GEP Overwolf](https://dev.overwolf.com/ow-native/live-game-data-gep/supported-games/world-of-warcraft/), [première application Overwolf Electron](https://dev.overwolf.com/ow-electron/getting-started/onboarding-resources/first-app/), [API WCL](https://www.warcraftlogs.com/api/docs).

## Données locales

Le cache se trouve dans `cache/data/`. Il peut être supprimé lorsque le worker est arrêté pour effacer les résultats locaux. Il n’est pas chiffré dans cette version. Ne pas utiliser ce prototype sur un poste partagé ou avec des résultats que l’on ne souhaite pas conserver en clair.
