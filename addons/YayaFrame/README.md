# Yaya Frame

Frame commune partagee par les addons Yaya.

- possede la position, le chrome, le deplacement, la largeur et la hauteur globale ;
- masque toute la frame en combat quand `YayaFrameAPI:SetHideInCombat(true)` est active ;
- accueille des sections enregistrees par `YayaSessionTracker` et `YayaWeeklyTracker`.

## Chrome

Le conteneur porte un fond et une bordure de 1 px issus de `YayaCore.UI`, un bandeau de
titre qui sert de poignee de deplacement, et un bandeau par section avec chevron de repli.
Les sections ne peignent donc plus de fond : elles en superposaient un identique, ce qui
portait l'opacite reelle a environ 80 %.

Le bouton cadenas du bandeau fige la position. La souris n'est plus active sur toute la
surface du conteneur, ce qui supprime les deplacements accidentels et laisse passer les
clics vers les frames posees dessous.

## Repli des sections

Le repli est cooperatif. `YayaFrame` dessine le chevron et appelle le rappel enregistre par
la section ; c'est la section qui masque son contenu et ramene sa hauteur. Le conteneur ne
touche jamais a la visibilite de la frame d'une section, parce que le tracker hebdomadaire
pilote deja son propre `Show`/`Hide`.

L'etat est conserve dans `YayaFrameDB.collapsed`.

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

La largeur demandee est celle du contenu ; le conteneur y ajoute ses deux gouttieres, puis
borne le tout entre 200 et 520 pixels.

## Echelle

- `/yframe scale 1.25` : regle l'echelle du conteneur, entre 0.5 et 2.0 ;
- `/yframe scale` : affiche l'echelle courante ;
- `/yframe lock` : verrouille ou deverrouille la position ;
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
| `SetSectionTitle(id, title)` | titre affiche dans le bandeau d'une section |
| `EnsureSectionHeader(id)` | bandeau d'une section, pour y poser ses boutons |
| `SetSectionCollapseHandler(id, fn)` | rappel appele au repli et au depli |
| `IsSectionCollapsed(id)` / `SetSectionCollapsed(id, v)` / `ToggleSection(id)` | etat de repli |
| `IsLocked()` / `SetLocked(v)` | verrouillage de la position |

## Tests

`Tests/test_yayaframe.lua` charge le vrai `YayaCore/UI.lua`, puis verifie l'empilement, le
recalcul automatique apres un changement de hauteur, le chrome, le repli, le verrou, le
regroupement des demandes et l'absence de boucle de mise en page, avec des frames simulees.
Un dernier bloc verifie la degradation quand `YayaCore` est absent :

```
pwsh -NoProfile -File ..\..\scripts\Test-Addons.ps1 -LuaPath <dossier lua>
```
