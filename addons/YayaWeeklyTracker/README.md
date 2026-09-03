# Yaya Weekly Tracker

La section Hebdo est affichee dans la frame partagee `YayaFrame`, avec la section Session si `YayaSessionTracker` est installe. La position et le deplacement sont communs aux deux addons ; l'option de masquage en combat de YWT masque la frame partagee.

Mini addon Retail qui affiche une petite frame a cote du `PlayerFrame` pour suivre :

- `Archeo Legion 5000g dispo` en premiere ligne si la rotation `Worth Its Weight` est active
- `Visions N'Zoth (hebdo)` via l'assaut majeur actif
- `Visions N'Zoth (bi-hebdo)` via l'assaut mineur actif
- `Jard`
- `Containing the Helsworn` si la recompense est du gold brut
- `Great Vault: a ouvrir` quand une recompense est disponible
- `Abondance` a partir du niveau 80
- `Shard of Dundun: 8/8 a depenser` a partir du niveau 90 quand le plafond de monnaie est atteint
- `Sparks of Tides: N/X` via `Tidal Spark Dust`, qui conserve les Sparks obtenus y compris les catch-ups; le suivi s'active au niveau 90 avec un ilvl equipe d'au moins 270; la ligne devient `X/X` verte tant qu'un `Spark of Tides` reste a depenser, puis disparait
- le world boss `Midnight` actif selon les options `World boss si gold` et `World boss si ilvl`, au niveau 90 ; il reste toujours tracke si l'objectif Liadrin actif est `Midnight: World Boss`
- le world boss de la rotation `Val`/`Naigtal` au niveau 90 ; un seul boss est affiche selon la quete active de la semaine (`Imperator Pertinax` ou `Nexus-Captain Leth'ir`)
- `Defense des runestones` de la Soiree de Saltheril, au niveau 90
- la weekly de Halduron uniquement quand `Hope in the Darkest Corners` est active
- la weekly `Neighborhood` au niveau 90, avec son nom quand elle est dans le journal et une completion partagee par tout le Warband
- la weekly de Liadrin quand son wrapper ou son objectif choisi est actif
- un resume `Midnight` par metier appris sur le perso courant, a partir du niveau 80

Resume `Midnight` :

- l'addon n'affiche que les metiers `Midnight` appris sur le personnage
- si les donnees de metier ne sont pas encore chargees, l'addon ouvre puis referme un des metiers appris au prochain appui clavier pour initialiser leur suivi
- chaque ligne est compacte, par exemple `Alch: T8/8 loot 2/2 hebdo traite DMF`, avec le statut dans sa propre colonne à droite et une zébrure une ligne sur deux
- la section se replie depuis le chevron de son bandeau `Hebdo`, et l'état est conservé entre les sessions
- les lignes longues se replient avec une hauteur adaptee, sans chevaucher la ligne suivante
- si rien ne reste a faire pour un metier suivi, la ligne affiche `ok` tant qu'une autre action garde la frame ouverte
- si tous les metiers suivis sont `ok` et qu'aucune autre ligne ou bouton ne reste, la frame est masquee
- si la moxie depasse `600`, la ligne affiche sa valeur en orange, par exemple `moxie 612`
- `T` = tresors restants
- `loot` = connaissances restantes via coffres/loots cette semaine
- `dez` = connaissances restantes via desenchantement pour l'Enchantement
- `catchup inactif` = le catch-up Enchantement attend encore la weekly, les 2 loots ou les 6 drops de désenchantement ; `catchup restant : x` = points de catch-up restants ; la ligne disparait quand il n'y a plus de catch-up
- `hebdo` = rappel quete hebdo trainer
- `traite` = rappel traite hebdo si le metier est a `25+` et que l'option `Tracker les traites (inscription)` est active
- `DMF` = Darkmoon Faire active et quete metier pas encore faite ce mois-ci
- `KP x a placer` en rouge = plus de `5` points de connaissance non depenses dans ce metier
- `+10KP (zone)` = livre de connaissance Midnight encore non consomme ; les livres d'Abundance sont suivis a partir du niveau 90 pour Enchantement, Herboristerie, Minage et Depeçage ; si le livre est deja dans les sacs, le rappel est masque au profit du bouton `Utiliser KP`
- `moxie x/y` et `abondance x/y` = recapitulatif du cout des livres manquants ; la valeur passe en rouge si la monnaie manque
- si `Outils metiers` est active, les outils de metier rares ou superieurs, soulbound, equipes ou presents dans les sacs, sont verifies pour chaque metier Midnight appris ; un metier sans outil bleu/violet equipe affiche `outil non equipe`
- la meme option ajoute un rappel independant `outil RF absent` par metier Midnight suivi tant qu'aucun outil de statistique `Resourcefulness` n'est possede, equipe ou en sac ; il s'ajoute a `outil non equipe` au lieu de le remplacer, et reste masque tant que le scan des outils est incomplet
- si `Enchantements des outils` est active, YWT lit la stat aleatoire du tooltip du lien unique de chaque outil possede (jamais la stat generique de l'item de base) : un outil Multicrafting demande l'enchantement Multicrafting, un outil sans enchantement affiche `outil sans enchant MC x1`, et un outil avec une mauvaise stat apparait dans `One time` (`outil MC x1`, `outil RF x1`, etc.) ; les boutons Warbank/YayaQueue utilisent ce meme enchantement cible ; les deux options sont actives par defaut
- les six stats d'outil Midnight sont gerees : Perception (`243965`), Resourcefulness (`243967`), Finesse (`243993`), Multicrafting (`243995`), Ingenuity (`244025`) et Deftness (`244023`) ; l'enchantement est valide par son `enchantID`, donc un rang 1 ou une mauvaise stat reste a corriger
- `Pull enchants Warbank` retire seulement la quantite necessaire des stacks connus de la Warbank ; son affichage est recalcule a l'ouverture de l'onglet Warbank et le bouton reste desactive si son contenu n'est pas connu
- `Acheter enchants YQ` ajoute uniquement les deficits non deja demandes dans YayaQueue, en tenant compte des sacs et de la Warbank ; le calcul est relance apres ajout
- son infobulle detaille le calcul par enchantement (`requis - sacs - banque - en file = a acheter`) et signale un stock Warbank inconnu ; la meme ligne est tracee dans `/ywt log` sous `Tool enchant plan`
- `Appliquer ...` apparait quand l'enchant requis est dans les sacs et cible l'outil equipe (slot d'inventaire) ou un outil de rechange rare+ soulbound present dans les sacs, libelle `Appliquer ... (sac)` ; l'enchant applique est toujours celui de la stat de l'outil vise, les outils equipes sont listes en premier et jusqu'a 20 boutons peuvent s'afficher
- apres confirmation que l'outil porte bien le nouvel `enchantID`, le bouton retire une unite de cet enchantement de la demande directe YayaQueue ; un clic annule ou echoue ne retire rien
- le rappel `moxie x` reste affiche meme si aucun tresor, livre ou recette ne reste dans `One time`
- les recettes manquantes suivies sont `Potion of Recklessness`, `Vicious Thalassian Flask of Honor`, `Concentrated Silvermoon Health Potion`, `Enchant Tool - Haranir Multicrafting` et `Gleeful Glamour - Haranir`, avec leur cout Moxie si necessaire ; leur etat connu utilise le tooltip Blizzard du personnage courant, comme Yaya Vendor Filter, puis les API metier en secours ; une recette ayant un cout Abundance n'est suivie qu'a partir du niveau 90
- `Vicious Thalassian Flask of Honor` est marquee comme achat hotel des ventes (`auctionHouse`) : elle s'affiche en `recette HV (...)`, sans waypoint TomTom ni cout Moxie ou `Voidlight Marl` dans les rappels
- une recette suivie non apprise mais deja presente dans les sacs est retiree de `One time` ; un bouton `Utiliser recette` permet de la consommer directement
- le transfert de `Voidlight Marl` depuis les autres personnages est temporairement desactive ; son bouton reste masque pendant la stabilisation du flux Blizzard
- `Lost Legends` est suivie comme weekly par personnage des legendes Haranir
- la completion weekly de `Lost Legends` accepte la quete de selection (`89268`) et les variantes repetables `The Story of...` (`92716`, `92719` a `92725`) ; les quetes initiales (`88993` a `88999`) ne sont pas utilisees car leur completion historique est permanente
- `Research Console: Exploring the Void` est suivie comme weekly quand la quete est active
- les rappels recurrents sont affiches sous le titre `Hebdo` uniquement s'il reste quelque chose a faire ; les tresors, livres KP et recettes sont dans `One time`, sans lignes `ok`
- la consommation d'une recette suivie force aussi un refresh apres le sort de consommation, sans devoir ouvrir le metier
- le bloc couvre surtout la partie actionable des guides `Midnight` : tresors, repeatable loot, trainer, traite, Darkmoon
- si `TomTom` est installe, l'addon ajoute automatiquement au login les waypoints des tresors `Midnight` encore non recuperes pour les metiers du personnage courant
- les waypoints sont refresh quand un tresor passe en `fait`
- si TomTom est installe, un waypoint temporaire est aussi pose vers chaque vendeur de livre KP manquant (`Voidstorm`, `Silvermoon`, `Harandar`, `Zul'Aman`, `Coiled Isle` ou `Abundance`)
- si TomTom est installe, un waypoint temporaire est aussi pose vers le vendeur des recettes suivies manquantes, uniquement quand la Moxie du metier suffit a les acheter : le budget est consomme recette par recette dans l'ordre de la liste, donc une Moxie insuffisante ne pose aucun point inutile et le point reapparait des que la Moxie remonte
- une recette sans vendeur (achat hotel des ventes) ne recoit jamais de waypoint et ne consomme pas ce budget Moxie
- l'addon n'impose pas la `CrazyArrow` de TomTom; il pose seulement les markers carte/minimap
- un bouton `Ouvrir payout` apparait si un `Artisan's Consortium Payout` est detecte dans les sacs; chaque clic cible un payout encore present et un clic excedentaire reste sans effet
- le meme bouton ouvre aussi tous les conteneurs Midnight ouvrables recenses dans la whitelist : caches, coffres, sacs, pochettes, satchels, offres, boites Prey et conteneurs de la Coiled Isle / Vaults of Atal'Utek, en alternant les slots disponibles
- les prismes de gemmes Midnight ouvrables sont inclus dans l'auto-ouverture : Amani Lapis, Tenebrous Amethyst, Sanguine Garnet et Harandar Peridot, dans leurs deux variantes d'item
- des boutons independants `Ouvrir surplus` apparaissent pour les conteneurs de composants en surplus des 11 metiers Midnight reconnus, afin de pouvoir alterner les clics pendant leur ouverture
- des boutons `Fusionner` apparaissent pour les Resourceful Rebar (`247725`), Multicraft Matrix (`247719`) et Ingenious Identifier (`260630`) dès que 5 rang 1 sont dans les sacs ; un clic utilise 5 rang 1 pour créer leur version rang 2 (`247726`, `247724`, `247788`)
- les boutons d'action d'item (KP, recette, payout, surplus, fusion et traité) invalident leur cache et rafraichissent leur valeur dès le clic, puis se verrouillent pour bloquer le multiclic jusqu'à `BAG_UPDATE_DELAYED`
- le bouton `Utiliser KP` n'itère plus dans l'ordre des sacs : il sert un traité dès que le cooldown partagé des traités est écoulé, sinon les autres objets de connaissance, sinon le traité restant. Avec deux métiers Midnight cela donne `traité → autres KP → traité`, les objets intercalés laissant le cooldown s'écouler ; avec un seul traité, il part en premier comme avant
- ce déverrouillage est en plus soumis au cooldown réel de l'objet, lu via `C_Item.GetItemCooldown` : `IsUsableItem` ignore les cooldowns, si bien qu'un second traité restait cliquable pendant les 5 s, l'action partait, le serveur la rejetait en silence et le bouton semblait cassé. Le bouton reste grisé avec le temps restant affiché entre parenthèses, et se réactive seul
- les boutons payout et surplus n'utilisent pas de watchdog : ils itèrent sur les containers disponibles au fil des refreshs de sacs
- l'option `Proposer l'ouverture securisee des conteneurs YWT` est desactivee par defaut ; si elle est activee, les conteneurs suivis sont detectes hors combat, hors instance et hors interfaces sensibles, puis ouverts automatiquement via `C_Container.UseContainerItem`
- deux verdicts distincts sont persistes, et ils ne doivent jamais etre confondus :
  - `autoOpenForbidden` : le conteneur a declenche `ADDON_ACTION_BLOCKED` ou `ADDON_ACTION_FORBIDDEN`. Signal dur de Blizzard, propre a l'objet : il n'est plus jamais tente automatiquement et passe uniquement par le bouton securise
  - `autoOpenFailed` : refus transitoire (personnage indisponible, loot en retard, sacs pleins). Verdict a duree de vie limitee, jamais definitif, efface par la premiere ouverture reussie
- un conteneur reserve au bouton securise ne bloque plus les suivants : le refus porte sur l'objet, la file continue d'avancer et l'ouverture automatique des autres conteneurs se poursuit
- avant mise en file, chaque candidat est valide en jeu : un conteneur ouvrable expose un effet d'utilisation (`C_Item.GetItemSpell`) et n'est pas verrouille. La whitelist declarative contient des objets qui ne s'ouvrent pas par clic ; ils sont ecartes sans audit manuel. Un objet dont la donnee n'est pas encore chargee est laisse passer, et sa donnee demandee
- une ouverture n'est comptee comme reussie que si le total detenu baisse **et** qu'un evenement de sac ou de loot a ete observe : la condition precedente concluait des que l'objet quittait son emplacement, si bien qu'un tri de sac ou un regroupement de pile marquait le conteneur ouvrable pour toujours
- `/ywt autoopen` affiche le decompte des trois tables ; `/ywt autoopen reset` purge les refus et les succes, `/ywt autoopen reset all` purge aussi les conteneurs interdits par Blizzard
- le bouton disparait des que son conteneur n'est plus dans l'emplacement de sac suivi ; les boutons YWT d'ouverture sont masques pendant le combat ou en instance par le state driver de leur parent, jamais par un `Hide` sous lockdown
- `UpdateTracker` est seul maitre de l'affichage du bouton d'ouverture : il lit l'etat du module, ancre le bouton, puis l'affiche. Le module se contentait auparavant de l'afficher avant de demander un rafraichissement, d'ou un bouton apparaissant sans position puis decale sur deux frames
- apres chaque recuperation depuis la boite aux lettres, elle attend 0,5 s apres le dernier evenement de courrier avant de rescanner les sacs
- les consommables KP restent volontairement manuels : WoW refuse leur utilisation automatique
- si `Tracker les traites (inscription)` est active, un bouton par traite hebdomadaire manquant est recalcule a l'ouverture de l'onglet Warbank et apparait lorsqu'un stack correspondant y est present ; il disparait si ce traite est deja dans les sacs ; le clic retire un seul traite et laisse le reste du stack dans la Warbank
- si YayaContainerValues est charge, ses hooks suivent l'utilisation réelle de l'item afin d'éviter les doubles signalements lors des clics rapides
- si la weekly `Midnight Enchanting` active demande un reagent manquant, YWT ajoute automatiquement la quantite complete a la queue YayaQueue, sans bouton et sans doublon aux refreshs
- quand cette weekly est rendue, YWT retire uniquement la quantite qu'il a automatiquement ajoutee, sans toucher aux besoins des recettes ni a une demande deja existante
- si l'option est activee et que le personnage connait l'Enchantement, YWT achete automatiquement tous les `Pouch of Mystic Grindings` achetables a l'ouverture d'un marchand d'Abondance
- si l'option correspondante est activee, YWT achete aussi automatiquement tous les `Fused Vitality` achetables a l'ouverture d'un marchand d'Abondance
- si les deux options sont actives, les sacs de materiaux d'enchantement sont achetes avant les `Fused Vitality`

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

Dans `Echap > Options > AddOns > Yaya Weekly Tracker`, les options account-wide permettent de :

- cacher integralement la frame en combat (desactive par defaut)
- activer ou desactiver le tracking d'`Abondance`, de la `Soiree`, de `Neighborhood`, de `Liadrin`, des world bosses Val/Naigtal, du world boss selon gold ou ilvl, des `Sparks of Tides`, des traites, des weeklies metiers trainer, du DMF metiers, des loots metiers, du dez Enchantement, des outils metiers, des enchantements des outils, de chaque recette Midnight, de `Lost Legends` et de `Research Console: Exploring the Void` (tous actives par defaut)
- activer l'achat automatique des sacs de materiaux d'enchantement du marchand d'Abondance (desactive par defaut)
- activer l'achat automatique des `Fused Vitality` du marchand d'Abondance (desactive par defaut)

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
- world boss `Val` = `96473` (normal), `96295` (Heroic) ; boss `Imperator Pertinax`
- world boss `Naigtal` = `96472` (normal), `96709` (Heroic) ; boss `Nexus-Captain Leth'ir`
- `Fortify the Runestones` = `90573`, `90574`, `90575`, `90576`
- `Hope in the Darkest Corners` = `95468`
- `Lost Legends` = `89268`, `92716`, `92719`-`92725` (weekly par personnage, niveau minimum `80` ; `88993`-`88999` = quetes initiales historiques)
- `Research Console: Exploring the Void` = `94790`
- weekly `Neighborhood` = `95413`, `95416`, `95438`, `95440` (breadcrumbs `95439`, `95482`)
- weekly de Liadrin = wrapper `93744`; objectifs `93766`, `93767`, `93769`, `93889`, `93890`, `93892`, `93909`, `93910`, `93911`, `93912`, `93913`, `94457`, `95842`, `95843`
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
- `Shard of Dundun` = monnaie `3376`, plafond `8`
- `Tidal Spark Dust` = monnaie `3509`; `Spark of Tides` = item `274476`
- `Voidlight Marl` = monnaie `3316`, transferable entre personnages Warband
- `Pouch of Mystic Grindings` = `250755`, sac de materiaux d'Enchantement vendu par le marchand d'Abondance
- `Fused Vitality` = `245345`, vendu par le marchand d'Abondance
- `Unalloyed Abundance` = monnaie `3377`
- `Ny'alotha, the Waking City` map = `10522`

Assauts N'Zoth :

- majeurs : `57157`, `56064`
- mineurs : `55350`, `56308`, `57008`, `57728`

Commande :

- `/ywt reset` pour remettre la frame a sa position par defaut
- `/ywt traites` pour activer/desactiver `Tracker les traites (inscription)`
- `/ywt traites on|off` pour forcer l'etat de `Tracker les traites (inscription)`
