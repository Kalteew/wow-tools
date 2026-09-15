# wow-tools

Carte du dépôt, pour ne pas le réexplorer à chaque session. Les conventions de
travail sont dans @AGENTS.md ; la liste complète des commandes CLI est dans
`README.md` (ne pas la dupliquer ici).

## Structure

| Dossier | Contenu |
|---|---|
| `addons/` | 14 addons Retail maison (suite Yaya). **Source canonique** : le client WoW n'en reçoit qu'une copie. |
| `wow_tools/` | Package Python, CLI `python -m wow_tools <commande>`. Base locale : `data/wow.sqlite3`. |
| `scripts/` | Outillage PowerShell + Python : sync addon, auto-patch d'addons tiers, flipping, rapports. |
| `tests/` | Tests Python (`python -m pytest tests`). Les tests Lua vivent dans `addons/*/Tests/test_*.lua`. |
| `data/`, `server.json` | Données générées ou synchronisées. Ne pas éditer à la main. |

Aucun fichier de dépendances Python : les scripts tournent sur la
bibliothèque standard plus ce qui est déjà installé.

## La suite d'addons

`YayaCore` est la base de tout (monnaie, prix TSM, journal, objets, infobulles,
tokens d'UI). `YayaFrame` héberge les sections de `YayaWeeklyTracker` et
`YayaSessionTracker`. La plupart exigent **TradeSkillMaster** en plus.

| Addon | Rôle |
|---|---|
| `!YayaErrorLog` | Capture persistante des erreurs Lua et actions bloquées. Le `!` est volontaire : il force le chargement en premier. |
| `YayaQueue` | File de craft → tâches d'achat à l'hôtel des ventes et chez les vendeurs. |
| `YayaCraftingOrdersLocal` | Panneau de commandes de patron, avec prix TSM et renvoi vers YayaQueue. |
| `YayaWeeklyTracker` | Tracker hebdomadaire près de la frame joueur (métiers, quêtes, world bosses). |
| `YayaReagentSniper` | Sniper de réactifs et analyse de resets par catalogue de récolte. |
| `YayaSessionTracker` | Or/heure de session, avec filtrage du butin et du courrier interne. |
| `YayaCraftedPrice` | Snapshots de coût de craft, expose `smartAvgCrafted` à TSM. |
| `YayaContainerValues` | Estime la valeur des conteneurs depuis les ouvertures observées. |
| `YayaAddonProfiles` | Réapplique les profils Simple Addon Manager par personnage. |
| `YayaVendorFilter` | Masque chez les vendeurs les recettes connues et objets déjà collectionnés. |
| `YayaWarbandBankDefault` | Ouvre la banque sur l'onglet banque de confrérie. |
| `YayaProfessionSpecializations` | Dump des arbres de spécialisation vers les SavedVariables. |
| `YayaCore`, `YayaFrame` | Socle partagé : implémentations communes et frame hôte. |

## Après toute modification d'un addon

1. Valider : `pwsh scripts/Test-Addons.ps1` (syntaxe puis tests unitaires Lua).
   Compile chaque fichier avec `luac` 5.1 — seul contrôle qui attrape une vraie
   erreur de syntaxe ou le dépassement des 200 locals. Sans `luac`, le repli est
   un simple équilibrage de blocs, beaucoup plus faible ; sur une machine neuve,
   récupérer Lua 5.1 sur LuaBinaries et passer `-LuaPath <dossier>`.
2. Bumper `## Version` dans le `.toc`.
3. Synchroniser : `pwsh scripts/sync-wow-addon.ps1 -AddonNames <nom>` vers
   `C:\Program Files (x86)\World of Warcraft\_retail_\Interface\AddOns`,
   et **vérifier que la copie a eu lieu**.

Si le sync refuse en annonçant une version live supérieure, le client est en
avance sur le dépôt : réimporter les changements live dans le dépôt avant de
resynchroniser. Ne pas forcer `-AllowDowngrade` sans avoir regardé le diff.

## Naviguer dans les fichiers monolithiques

`YayaQueue/YayaQueue.lua` (19 k lignes, ~220 k tokens),
`YayaWeeklyTracker.lua` (11 k) et `YayaCraftingOrdersLocal/BrowsePane.lua`
(8 k, 277 fonctions) ne doivent **jamais** être lus en entier.

Ces fichiers n'ont pas de bannières de section, mais chaque fonction notable
porte un commentaire `--- `. Pour obtenir un index bon marché :

```bash
grep -n '^--- ' addons/YayaQueue/YayaQueue.lua
```

Puis lire la plage utile avec `sed -n '<début>,<fin>p'`. Préférer `Edit` à
`Write` sur ces fichiers : une réécriture complète coûte le fichier entier.

## Pièges qui cassent en silence

- **200 locals par chunk** (limite Lua 5.1). `BrowsePane`, `YayaWeeklyTracker`
  et `YayaQueue` frôlent le plafond (196 à 199) : un `local` de chunk en trop
  casse l'addon entier, sans erreur visible. D'où l'étape `luac`. Dans ces
  fichiers, préférer un champ de table à un nouveau `local` de premier niveau.
- **Fins de ligne mixtes.** Git stocke tout en LF, `core.autocrlf` rend l'arbre
  en CRLF. Lire en newlines universelles, réécrire en LF.
- **Watchers d'auto-patch** (`scripts/{tsm,abundance,wqt}/`). Ils sondent toutes
  les 2 s et réappliquent le patch. Modifier un `*AutoPatch.Common.ps1` sans
  relancer le watcher : le correctif est reverté ~7 s plus tard.
