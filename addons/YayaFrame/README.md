# Yaya Frame

Frame commune partagee par les addons Yaya.

- possede la position, le fond, le deplacement, la largeur et la hauteur globale ;
- masque toute la frame en combat quand `YayaFrameAPI:SetHideInCombat(true)` est active ;
- accueille des sections enregistrees par `YayaSessionTracker` et `YayaWeeklyTracker`.

La position est stockee dans `YayaFrameDB`. `/yst reset` et `/ywt reset` la
reinitialisent egalement.

## Mise en page automatique

Une section n'a plus a signaler ses changements de taille. `AttachSection` pose
un `OnSizeChanged`, un `OnShow` et un `OnHide` sur la frame attachee, et la mise
en page se recalcule seule.

Auparavant, chaque section devait appeler `YayaFrameAPI:Refresh()` apres avoir
change sa hauteur. La convention n'etait pas toujours respectee — le tracker
hebdomadaire avait au moins un `SetHeight` sans `Refresh` — et les sections
pouvaient se superposer.

Les demandes sont regroupees : plusieurs changements dans la meme frame de rendu
ne produisent qu'une seule mise en page. Un verrou empeche le redimensionnement
declenche par la mise en page de la relancer indefiniment.

Les appels manuels a `Refresh()` restent valides et sans effet de bord.

## Largeur

Le conteneur fait 200 pixels par defaut, comme auparavant. Une section peut
demander davantage :

```lua
YayaFrameAPI:SetSectionWidth("MaSection", 320)
```

La largeur retenue est celle de la section la plus large, bornee entre 200 et
520 pixels.

## Echelle

- `/yframe scale 1.25` : regle l'echelle du conteneur, entre 0.5 et 2.0 ;
- `/yframe scale` : affiche l'echelle courante ;
- `/yframe reset` : reinitialise la position.

L'echelle est conservee dans `YayaFrameDB` et reappliquee a la connexion.

## API

| Fonction | Role |
| --- | --- |
| `GetFrame()` | conteneur, cree au besoin |
| `AttachSection(id, frame, order)` | attache une section, `order` croissant de haut en bas |
| `DetachSection(id)` | retire une section |
| `SetSectionWidth(id, width)` | largeur souhaitee d'une section |
| `Refresh()` | demande une mise en page regroupee |
| `RefreshNow()` | mise en page immediate |
| `SetScale(scale)` / `GetScale()` | echelle du conteneur |
| `SavePosition()` / `ApplyPosition()` / `ResetPosition()` | position |
| `SetHideInCombat(enabled)` | masquage en combat |

## Tests

`Tests/test_yayaframe.lua` verifie l'empilement, le recalcul automatique apres
un changement de hauteur, le regroupement des demandes et l'absence de boucle de
mise en page, avec des frames simulees :

```
pwsh -NoProfile -File ..\..\scripts\Test-Addons.ps1 -LuaPath <dossier lua>
```
