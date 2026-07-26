# Yaya Weekly Tracker

La section Hebdo est affichee dans la frame partagee `YayaFrame`, avec la section Session si `YayaSessionTracker` est installe. La position et le deplacement sont communs aux deux addons ; l'option de masquage en combat de YWT masque la frame partagee.

Mini addon Retail qui affiche une petite frame a cote du `PlayerFrame` pour suivre :

- `Archeo Legion 5000g dispo` en premiere ligne si la rotation `Worth Its Weight` est active
- `Visions N'Zoth (hebdo)` via l'assaut majeur actif
- `Visions N'Zoth (bi-hebdo)` via l'assaut mineur actif
- `Jard`
- `Containing the Helsworn` si la recompense est du gold brut
- `Abondance` a partir du niveau 80
- le world boss `Midnight` actif s'il donne de l'or, ou si l'ilvl equipe moyen du personnage est inferieur a `250`, au niveau 90
- `Defense des runestones` de la Soiree de Saltheril, au niveau 90
- la weekly de Halduron uniquement quand `Hope in the Darkest Corners` est active
- la weekly `Neighborhood` au niveau 90, avec son nom quand elle est dans le journal et une completion partagee par tout le Warband
- la weekly de Liadrin quand son wrapper ou son objectif choisi est actif
- un resume `Midnight` par metier appris sur le perso courant, a partir du niveau 80

Resume `Midnight` :

- l'addon n'affiche que les metiers `Midnight` appris sur le personnage
- chaque ligne est compacte, par exemple `Alch: T8/8 loot 2/2 hebdo traite DMF`
- les lignes longues se replient avec une hauteur adaptee, sans chevaucher la ligne suivante
- si rien ne reste a faire pour un metier suivi, la ligne affiche `ok` tant qu'une autre action garde la frame ouverte
- si tous les metiers suivis sont `ok` et qu'aucune autre ligne ou bouton ne reste, la frame est masquee
- si la moxie depasse `600`, la ligne affiche sa valeur en orange, par exemple `moxie 612`
- `T` = tresors restants
- `loot` = connaissances restantes via coffres/loots cette semaine
- `dez` = connaissances restantes via desenchantement pour l'Enchantement
- `hebdo` = rappel quete hebdo trainer
- `traite` = rappel traite hebdo si le metier est a `25+` et que l'option `Tracker les traites (inscription)` est active
- `DMF` = Darkmoon Faire active et quete metier pas encore faite ce mois-ci
- `+10KP (zone)` = livre de connaissance Midnight encore non consomme ; les livres d'Abundance sont suivis en plus pour Enchantement, Herboristerie, Minage et Depeçage
- `moxie x/y` et `abondance x/y` = recapitulatif du cout des livres manquants ; la valeur passe en rouge si la monnaie manque
- les recettes manquantes suivies sont `Potion of Recklessness`, `Enchant Tool - Haranir Multicrafting` et `Gleeful Glamour - Haranir`, avec leur cout Moxie si necessaire
- les rappels recurrents et les objectifs ponctuels sont affiches sur des lignes separees ; les livres KP et recettes apparaissent dans la ligne `1x`
- le bloc couvre surtout la partie actionable des guides `Midnight` : tresors, repeatable loot, trainer, traite, Darkmoon
- si `TomTom` est installe, l'addon ajoute automatiquement au login les waypoints des tresors `Midnight` encore non recuperes pour les metiers du personnage courant
- les waypoints sont refresh quand un tresor passe en `fait`
- si TomTom est installe, un waypoint temporaire est aussi pose vers chaque vendeur de livre KP manquant (`Voidstorm`, `Silvermoon`, `Harandar`, `Zul'Aman` ou `Abundance`)
- si TomTom est installe, un waypoint temporaire est aussi pose vers le vendeur des recettes suivies manquantes
- l'addon n'impose pas la `CrazyArrow` de TomTom; il pose seulement les markers carte/minimap
- un bouton `Ouvrir payout` apparait si un `Artisan's Consortium Payout` est detecte dans les sacs; chaque clic cible un payout encore present et un clic excedentaire reste sans effet
- des boutons independants `Ouvrir surplus` apparaissent pour les conteneurs de composants en surplus des 11 metiers Midnight reconnus, afin de pouvoir alterner les clics pendant leur ouverture
- si YayaContainerValues est charge, ces boutons lui signalent l'item avant l'ouverture afin d'attribuer correctement les outputs
- un bouton `YQ Ench +...` apparait si la weekly `Midnight Enchanting` active demande un reagent manquant; chaque clic ajoute la quantite complete de la weekly a la queue existante, en plus des besoins des crafts deja presents
- quand cette weekly est rendue, YWT retire sa quantite complete de la demande directe YayaQueue sans toucher aux besoins des recettes

Etat des lignes :

- `a faire`
- `a debloquer`
- ligne masquee si deja faite

Note :

- les lignes `Visions N'Zoth (hebdo)` et `Visions N'Zoth (bi-hebdo)` sont actuellement desactivees dans l'UI
- `Replenish the Reservoir` est actuellement desactive dans l'UI

Exception :

- `Jard` n'affiche jamais `a debloquer`

La frame est ancree par son coin haut gauche et s'etend vers le bas droite. Sa position est conservee entre les personnages.

Dans `Echap > Options > AddOns > Yaya Weekly Tracker`, l'option account-wide `Cacher integralement la frame en combat` masque toute la frame et ses boutons jusqu'a la fin du combat. Elle est desactivee par defaut.

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
- `Abundant Offerings` = `89507`
- world bosses `Midnight` = `92560`, `92123`, `92034`, `92636`
- `Fortify the Runestones` = `90573`, `90574`, `90575`, `90576`
- `Hope in the Darkest Corners` = `95468`
- weekly `Neighborhood` = `95413`, `95416`, `95438`, `95440` (breadcrumbs `95439`, `95482`)
- weekly de Liadrin = wrapper `93744`; objectifs `93766`, `93767`, `93769`, `93889`, `93890`, `93891`, `93892`, `93909`, `93910`, `93911`, `93912`, `93913`, `94457`, `95842`, `95843`
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
