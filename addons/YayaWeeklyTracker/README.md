# Yaya Weekly Tracker

Mini addon Retail qui affiche une petite frame a cote du `PlayerFrame` pour suivre :

- `Archeo Legion 5000g dispo` en premiere ligne si la rotation `Worth Its Weight` est active
- `Visions N'Zoth (hebdo)` via l'assaut majeur actif
- `Visions N'Zoth (bi-hebdo)` via l'assaut mineur actif
- `Jard`
- `Containing the Helsworn` si la recompense est du gold brut
- un resume `Midnight` par metier appris sur le perso courant

Resume `Midnight` :

- l'addon n'affiche que les metiers `Midnight` appris sur le personnage
- chaque ligne est compacte, par exemple `Alch: T8/8 loot 2/2 hebdo traite DMF`
- si rien ne reste a faire pour un metier suivi, la ligne reste visible avec `ok`
- si la concentration depasse `750`, la ligne affiche sa valeur en orange, par exemple `conc. 812`
- `T` = tresors restants
- `loot` = connaissances restantes via coffres/loots cette semaine
- `dez` = connaissances restantes via desenchantement pour l'Enchantement
- `hebdo` = rappel quete hebdo trainer
- `traite` = rappel traite hebdo si le metier est a `25+` et que l'option `Tracker les traites (inscription)` est active
- `DMF` = Darkmoon Faire active et quete metier pas encore faite ce mois-ci
- le bloc couvre surtout la partie actionable des guides `Midnight` : tresors, repeatable loot, trainer, traite, Darkmoon
- si `TomTom` est installe, l'addon ajoute automatiquement au login les waypoints des tresors `Midnight` encore non recuperes pour les metiers du personnage courant
- les waypoints sont refresh quand un tresor passe en `fait`
- l'addon n'impose pas la `CrazyArrow` de TomTom; il pose seulement les markers carte/minimap
- un bouton `Ouvrir payout` apparait si un `Artisan's Consortium Payout` est detecte dans les sacs
- un bouton `YQ Ench ...` apparait si la weekly `Midnight Enchanting` active demande un reagent manquant; il ajoute l'achat a `YayaQueue`

Etat des lignes :

- `a faire`
- `a debloquer`
- ligne masquee si deja faite

Note :

- les lignes `Visions N'Zoth (hebdo)` et `Visions N'Zoth (bi-hebdo)` sont actuellement desactivees dans l'UI
- `Replenish the Reservoir` est actuellement desactive dans l'UI

Exception :

- `Jard` n'affiche jamais `a debloquer`

La position de la frame est conservee entre les personnages.

L'addon enregistre aussi en account-wide les personnages qui connaissent `Jard` dans `YayaWeeklyTrackerAccountDB.jardOwners`.

Il enregistre aussi les ouvertures des coffres d'assaut N'Zoth dans `YayaWeeklyTrackerAccountDB.nzothCacheHistory`.

Tracking N'Zoth :

- source du coffre via `QUEST_TURNED_IN` sur :
- majeurs : `57157`, `56064`
- mineurs : `55350`, `56308`, `57008`, `57728`
- ouverture des coffres via :
- `Cache of the Black Empire` (`173372`)
- `Cache of the Fallen Mogu` (`174958`)
- `Cache of the Mantid Swarm` (`174959`)
- `Cache of the Aqir Swarm` (`174960`)
- `Cache of the Amathet` (`174961`)
- snapshot avant/apres ouverture pour :
- `gold`
- `War Resources` (`1560`)
- `Corrupted Mementos` (`1719`)
- `Coalescing Visions` (`1755`)
- contexte stocke :
- perso / zone
- rang + ilvl de cape si detectables
- cape legendaire :
- obtenue ou non
- rang `1-15` via la chaine d'upgrade `8.3`
- quete d'upgrade active / dernier palier valide
- niveau + ilvl du Heart of Azeroth si detectables
- quetes actives + etat assauts
- progression de la suite 8.3 :
- etape courante
- dernier jalon valide
- prochain jalon attendu
- progression `Ny'alotha, the Waking City` :
- lockouts hebdo
- vue `ever killed` via achievements de pallier
- flag `nzothKilled`
- messages de loot/currency recus pendant l'ouverture

Le champ `reward.got2000Gold` permet de filtrer directement les coffres qui ont donne les `2000g`.

Hypotheses actuellement codees :

- `Visions N'Zoth` = assauts actifs BFA, debloques via `Restored Hope` (`56542`)
- `Containing the Helsworn` (`64273`) est trackee uniquement si la recompense est du gold brut
- `Archeo Legion 5000g dispo` = rotation EU `Worth Its Weight` (`41174` -> `41176`), avec debut d'ancrage le `2025-04-02`

IDs utilises :

- `Restored Hope` = `56542`
- `Jard's Peculiar Energy Source` (sort) = `139176`
- `Replenish the Reservoir` = `61981`, `61982`, `61983`, `61984`
- `Victory in Our Name` = `63622`
- `Containing the Helsworn` = `64273`
- `Worth Its Weight` = `41174`
- `Fit for an Elven Queen` = `41175`
- `Sifting Through the Rubble` = `41176`
- `Cache of the Black Empire` = `173372`
- `Cache of the Fallen Mogu` = `174958`
- `Cache of the Mantid Swarm` = `174959`
- `Cache of the Aqir Swarm` = `174960`
- `Cache of the Amathet` = `174961`
- `War Resources` = `1560`
- `Corrupted Mementos` = `1719`
- `Coalescing Visions` = `1755`
- `Ny'alotha, the Waking City` map = `10522`

Assauts N'Zoth :

- majeurs : `57157`, `56064`
- mineurs : `55350`, `56308`, `57008`, `57728`

Commande :

- `/ywt reset` pour remettre la frame a sa position par defaut
- `/ywt traites` pour activer/desactiver `Tracker les traites (inscription)`
- `/ywt traites on|off` pour forcer l'etat de `Tracker les traites (inscription)`
