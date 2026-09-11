# Yaya Weekly Tracker

La section Hebdo est affichee dans la frame partagee `YayaFrame`, avec la section Session si `YayaSessionTracker` est installe. La position et le deplacement sont communs aux deux addons ; l'option de masquage en combat de YWT masque la frame partagee.

Le raccourci commun Yaya, configurable dans les raccourcis clavier des options Blizzard, declenche une seule action par appui : `NEXT` de YayaQueue en priorite, puis, quand sa fenetre est masquee, le bouton d'action YWT visible et disponible le plus bas. Tous les boutons d'action participent, y compris les conteneurs, traites, enchants et tresors ; les commandes du bandeau sont exclues. Un bouton grise ou masque n'est pas active. Le raccourci respecte les verrouillages et cooldowns des boutons.

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
- une ligne de metier s'etale sur trois lignes de texte au plus, decoupees entre jetons et jamais au milieu de l'un d'eux ; au-dela, un marqueur `+N` compte ce qui n'est pas affiche
- la ligne ne porte que des compteurs : les noms entiers de recettes, de livres et d'outils sont dans l'infobulle, qui donne le detail complet au survol
- si rien ne reste a faire pour un metier suivi, la ligne affiche `ok` tant qu'une autre action garde la frame ouverte
- si tous les metiers suivis sont `ok` et qu'aucune autre ligne ou bouton ne reste, la frame est masquee
- si la moxie depasse le seuil `Moxie : seuil d'alerte` des options (`600` par defaut, reglable de 0 a 2000), la ligne affiche sa valeur en orange, par exemple `moxie 612`
- `T` = tresors restants
- `loot` = connaissances restantes via coffres/loots cette semaine
- `dez` = connaissances restantes via desenchantement pour l'Enchantement
- `catchup inactif` = le catch-up Enchantement attend encore la weekly, les 2 loots ou les 6 drops de désenchantement ; `catchup x` = points de catch-up restants ; la ligne disparait quand il n'y a plus de catch-up
- `hebdo` = rappel quete hebdo trainer
- `traite` = rappel traite hebdo si le metier est a `25+` et que l'option `Tracker les traites (inscription)` est active
- `DMF` = Darkmoon Faire active et quete metier pas encore faite ce mois-ci
- `KP x` en rouge = plus de points de connaissance non depenses dans ce metier que le seuil `Points de connaissance non depenses` des options (`5` par defaut, reglable de 0 a 50)
- `+10KP xN` = livres de connaissance Midnight encore non consommes, leurs noms etant listes dans l'infobulle de la ligne ; les livres d'Abundance sont suivis a partir du niveau 90 pour Enchantement, Herboristerie, Minage et Depeçage ; si le livre est deja dans les sacs, le rappel est masque au profit du bouton `Utiliser KP`
- `moxie x/y` et `abondance x/y` = recapitulatif du cout des livres manquants ; la valeur passe en rouge si la monnaie manque
- si `Outils metiers` est active, les outils de metier rares ou superieurs, soulbound, equipes ou presents dans les sacs, sont verifies pour chaque metier Midnight appris ; un metier sans outil bleu/violet equipe affiche `outil non equipe`
- la meme option ajoute un rappel independant `outil RF` par metier Midnight suivi tant qu'aucun outil de statistique `Resourcefulness` **conforme** n'est possede, equipe ou en sac ; il s'ajoute a `outil non equipe` au lieu de le remplacer, et reste masque tant que le scan des outils est incomplet
- le rang compte autant que la statistique : un exemplaire Resourcefulness sous le seuil d'ilvl des options (`232` par defaut) ne satisfait pas l'exigence, et l'infobulle dit alors lequel des deux manque (`Aucun outil Resourcefulness possede` ou `Outil Resourcefulness possede mais sous le seuil de 232 d'ilvl`). Sans cette distinction le rappel disparaissait devant un outil rang 1, et rien ne proposait de le remplacer
- ce rappel ne concerne que les metiers de **craft** : `Resourcefulness` economise les reactifs d'un craft et n'a aucun usage en recolte, dont les outils jouent sur `Perception`, `Deftness` ou `Finesse`. Herboristerie, Minage et Depecage portent `gathering = true` dans `MIDNIGHT_PROFESSION_CONFIGS` et n'affichent donc aucun rappel RF ; leurs emplacements de metier restent verifies normalement
- ce rappel porte sur la **possession**, equipe ou en sac, et non sur le port : dans un flux multi-outil l'exemplaire porte change au fil des recettes, donc un outil garde en sac compte autant qu'un outil equipe
- si `Enchantements des outils` est active, YWT lit la stat aleatoire du tooltip du lien unique de chaque outil possede (jamais la stat generique de l'item de base) : un outil Multicrafting demande l'enchantement Multicrafting, les outils sans enchantement sont comptes dans `ench xN` et ceux a recuperer dans `outil xN`, le detail par outil etant donne par l'infobulle ; les boutons Warbank/YayaQueue utilisent ce meme enchantement cible ; les deux options sont actives par defaut
- les six stats d'outil Midnight sont gerees : Perception (`243965`), Resourcefulness (`243967`), Finesse (`243993`), Multicrafting (`243995`), Ingenuity (`244025`) et Deftness (`244023`) ; l'enchantement est valide par son `enchantID`, donc un rang 1 ou une mauvaise stat reste a corriger
- la stat est reconnue par les libelles rendus par le client, donc deja localises : les globals utilises sont `ITEM_MOD_<STAT>_SHORT` et `PROFESSIONS_OUTPUT_<STAT>_TITLE`, les variantes `ITEM_MOD_<STAT>_RATING*` n'existant pas. Les libelles sont des faux amis entre langues : en francais Resourcefulness s'affiche `Ingéniosité` et Ingenuity `Inventivité`, ce qui faisait classer tout outil RF comme outil Ingenuity et affichait `outil RF absent` a tort. Sur une meme ligne d'infobulle, le libelle le plus long l'emporte, jamais la premiere stat testee
- si `Equipement de metier` est active, les trois emplacements de metier de chaque metier Midnight suivi sont verifies, et le token `stuff xN` compte ceux a completer, son infobulle donnant le motif de chacun (`vide`, `rarete sous rare`, `ilvl 206 < 232`)
- les deux emplacements d'**accessoire** se jugent sur ce qu'ils portent : au moins rare, et ilvl au seuil. Les accessoires ne tournent pas, donc l'objet equipe est le bon critere
- l'emplacement d'**outil** se juge sur la **possession** d'au moins un outil conforme, equipe ou en sac, jamais sur l'outil porte. YayaQueue echange l'outil Multicraft et l'outil Resourcefulness selon la recette, donc ce qui est porte a un instant donne ne dit rien : un verdict sur le port ferait clignoter le rappel au rythme des echanges. Le motif affiche est alors `aucun outil conforme possede`
- la conformite d'un outil est arretee apres le scan des sacs : la rarete est deja filtree a l'entree du scan, reste l'ilvl lu sur le lien unique de chaque exemplaire. Un outil dont l'ilvl n'est pas lisible laisse l'emplacement d'outil sans verdict plutot que de le declarer fautif
- c'est la **nature** de l'emplacement qui decide, jamais l'objet qui s'y trouve : la position rendue par `GetProfessionSlots` distingue l'outil de ses accessoires
- le seuil vaut `232` par defaut et se lit `>=` : les equipements de metier **rares** plafonnent a l'ilvl 232 au rang de craft maximal, donc exiger strictement plus de 232 imposerait de l'epique et rendrait le rappel impossible a satisfaire en bleu. Le seuil d'ilvl (`Equipement de metier : ilvl minimal`, 1 a 400) et la rarete minimale (`Equipement de metier : rarete minimale`, rare ou epique) se reglent dans les options ; `/ywt stuff ilvl <n>` change aussi le seuil d'ilvl, `/ywt stuff ilvl` l'affiche, `/ywt stuff ilvl reset` le remet a `232`
- un emplacement dont la rarete ou l'ilvl ne sont pas encore charges n'est jamais compte comme fautif : les donnees de l'objet sont demandees et le rappel reste masque, comme pour les autres rappels d'outils
- un emplacement qui cumule rarete et ilvl insuffisants ne compte qu'une fois : le token compte les emplacements, pas les motifs
- pour l'alchimie, la meme option ajoute `MC` tant qu'aucun outil Multicrafting **conforme** n'est possede : YayaQueue equipe l'outil Multicrafting juste avant les crafts qui multicraftent, ce qui suppose d'en posseder un exemplaire en plus de l'outil Resourcefulness. Comme l'emplacement d'outil, ce rappel porte sur la **possession**, equipe ou en sac, jamais sur le port : l'echange renvoie en sac l'outil qui sort, donc un outil Multicrafting porte est deja en place et n'en reclame pas un second. Meme regle que le rappel RF : un exemplaire sous le seuil de rang ne compte pas, et l'infobulle le dit
- `Acheter stuff YQ xN +Me` (M enchantements) ajoute a la queue YayaQueue le rang rare de ce qui manque, **chaque demande portant la variante exigee** : un outil `Resourcefulness` ilvl >= seuil pour les metiers de craft, un outil `Multicrafting` ilvl >= seuil pour l'alchimie, un outil du rang seul pour les metiers de recolte (Resourcefulness n'y sert a rien), et autant d'accessoires distincts, sur le rang seul, qu'il y a d'emplacements d'accessoire fautifs
- les besoins d'outil suivent une seule source, `trackerUI.GetProfessionToolNeeds` : les rappels, le plan d'achat et la demande d'enchantement en decoulent. Un outil conforme mais de mauvaise statistique laisse donc le besoin ouvert, alors que l'emplacement, lui, est satisfait
- l'enchantement part avec l'outil : un outil `Resourcefulness` achete fait entrer son enchantement `243967` dans le meme plan, un outil `Multicrafting` son `243995`. Le besoin rejoint `requiredByItemID`, donc la Warbank est fouillee avant l'hotel des ventes et la quantite deja en file est deduite, exactement comme pour les autres enchantements. Un outil de recolte, achete sans statistique exigee, n'en demande aucun : la stat de l'exemplaire achete n'est pas connue d'avance
- rien n'est re-ajoute si la **meme variante** du meme objet est deja demandee dans la file : l'outil Resourcefulness et l'outil Multicrafting d'un metier partagent leur itemID, et un compte global faisait passer le second pour deja demande
- les itemIDs de ces rangs rares sont des **candidats** valides en jeu avant toute proposition : emplacement d'equipement (`INVTYPE_PROFESSION_TOOL` ou `INVTYPE_PROFESSION_GEAR`) et ligne de metier via `C_TradeSkillUI.GetSkillLineForGear`. Un candidat refuse n'est jamais mis en file, un candidat non encore charge laisse le plan en attente
- le rang de craft d'un objet ne change pas son itemID, seulement ses bonusId, et la statistique d'un outil est tiree au hasard sur l'exemplaire : c'est pourquoi la demande porte une variante et non un simple itemID. La statistique voyage par sa **cle interne**, et YayaQueue la relit **au tooltip** de chaque annonce, dans la langue du client, exactement comme le tracker lit les outils possedes
- le bonusId de statistique (`8952` Resourcefulness, `8953` Multicraft) ne peut pas servir de critere : il n'existe que sur un exemplaire craft **avec une Missive**. Un outil craft sans Missive n'en porte aucun, et c'est le cas de la plupart des annonces
- YayaQueue ecarte les annonces non conformes au lieu de prendre la moins chere : sans annonce conforme, la ligne HV reste a zero disponible plutot que d'acheter un rang 1 a statistique quelconque. Le stock possede est compte par variante, donc posseder un outil rang 1 n'annule plus la demande d'un outil rang maximal
- l'achat d'un equipement passe par la confirmation de prix eleve de YayaQueue des que l'annonce depasse `1,5x` le `dbrecent` TSM de l'itemID : ce prix melange les rangs, donc un rang maximal la declenche souvent. C'est un garde-fou, pas un bug
- `/ywt stuff` bascule le suivi, `/ywt stuff on` et `/ywt stuff off` le forcent ; la trace `gear[<skillLineID>]` de `/ywt log` donne le compte d'emplacements, les motifs, la possession d'un outil conforme (`tool=`), celle d'un outil Resourcefulness (`rfOwned=`, et `rfOk=` pour la version conforme), celle d'un outil Multicrafting (`mcOwned=`, et `mcOk=` pour la version conforme) et les besoins retenus (`needs=`). La trace `Profession gear plan` donne le plan d'achat complet : quantite d'equipements, d'enchantements, variante visee par chaque ligne, candidats refuses et statistiques non ciblables
- `Pull enchants Warbank` retire seulement la quantite necessaire des stacks connus de la Warbank ; son affichage est recalcule a l'ouverture de l'onglet Warbank et le bouton reste desactive si son contenu n'est pas connu
- `Acheter enchants YQ` ajoute uniquement les deficits non deja demandes dans YayaQueue, en tenant compte des sacs et de la Warbank ; le calcul est relance apres ajout
- son infobulle detaille le calcul par enchantement (`requis - sacs - banque - en file = a acheter`) et signale un stock Warbank inconnu ; la meme ligne est tracee dans `/ywt log` sous `Tool enchant plan`
- `Appliquer ...` apparait quand l'enchant requis est dans les sacs et cible l'outil equipe (slot d'inventaire) ou un outil de rechange rare+ soulbound present dans les sacs, libelle `Appliquer ... (sac)` ; l'enchant applique est toujours celui de la stat de l'outil vise, les outils equipes sont listes en premier et jusqu'a 20 boutons peuvent s'afficher
- apres confirmation que l'outil porte bien le nouvel `enchantID`, le bouton retire une unite de cet enchantement de la demande directe YayaQueue ; un clic annule ou echoue ne retire rien
- le rappel `moxie x` reste affiche meme si aucun tresor, livre ou recette ne reste dans `One time`
- les recettes manquantes suivies sont `Potion of Recklessness`, `Vicious Thalassian Flask of Honor`, `Concentrated Silvermoon Health Potion`, `Enchant Tool - Haranir Multicrafting` et `Gleeful Glamour - Haranir`, avec leur cout Moxie si necessaire ; leur etat connu utilise le tooltip Blizzard du personnage courant, comme Yaya Vendor Filter, puis les API metier en secours ; une recette ayant un cout Abundance n'est suivie qu'a partir du niveau 90
- `Vicious Thalassian Flask of Honor` est marquee comme achat hotel des ventes (`auctionHouse`) : elle est comptee dans `recHV xN`, son nom apparaissant dans l'infobulle, sans waypoint TomTom ni cout Moxie ou `Voidlight Marl` dans les rappels
- une recette suivie non apprise mais deja presente dans les sacs est retiree de `One time` ; un bouton `Utiliser recette` permet de la consommer directement
- le transfert de `Voidlight Marl` depuis les autres personnages est temporairement desactive ; son bouton reste masque pendant la stabilisation du flux Blizzard
- `Lost Legends` est suivie comme weekly par personnage des legendes Haranir
- la completion weekly de `Lost Legends` accepte la quete de selection (`89268`) et les variantes repetables `The Story of...` (`92716`, `92719` a `92725`) ; les quetes initiales (`88993` a `88999`) ne sont pas utilisees car leur completion historique est permanente
- `Research Console: Exploring the Void` est suivie comme weekly quand la quete est active
- les rappels recurrents sont affiches sous le titre `Hebdo` uniquement s'il reste quelque chose a faire ; les tresors, livres KP et recettes sont dans `One time`, sans lignes `ok`
- la consommation d'une recette suivie force aussi un refresh apres le sort de consommation, sans devoir ouvrir le metier
- le bloc couvre surtout la partie actionable des guides `Midnight` : tresors, repeatable loot, trainer, traite, Darkmoon
- si `TomTom` est installe et que `Waypoints des tresors Midnight` est active (defaut), l'addon ajoute automatiquement au login les waypoints des tresors `Midnight` encore non recuperes pour les metiers du personnage courant ; desactivee, l'option retire les waypoints poses et masque le bouton `TomTom tresors`
- les waypoints sont refresh quand un tresor passe en `fait`
- si TomTom est installe et que `Waypoints des vendeurs de livres KP` est active (defaut), un waypoint temporaire est aussi pose vers chaque vendeur de livre KP manquant (`Voidstorm`, `Silvermoon`, `Harandar`, `Zul'Aman`, `Coiled Isle` ou `Abundance`)
- si TomTom est installe et que `Waypoints des vendeurs de recettes` est active (defaut), un waypoint temporaire est aussi pose vers le vendeur des recettes suivies manquantes, uniquement quand la Moxie du metier suffit a les acheter : le budget est consomme recette par recette dans l'ordre de la liste, donc une Moxie insuffisante ne pose aucun point inutile et le point reapparait des que la Moxie remonte
- les trois options TomTom sont dans la categorie `TomTom` du panneau ; sans TomTom charge, elles n'ont aucun effet
- une recette sans vendeur (achat hotel des ventes) ne recoit jamais de waypoint et ne consomme pas ce budget Moxie
- l'addon n'impose pas la `CrazyArrow` de TomTom; il pose seulement les markers carte/minimap
- un bouton `Ouvrir payout` apparait si un `Artisan's Consortium Payout` est detecte dans les sacs; chaque clic cible un payout encore present et un clic excedentaire reste sans effet
- le meme bouton ouvre aussi tous les conteneurs Midnight ouvrables recenses dans la whitelist : caches, coffres, sacs, pochettes, satchels, offres, boites Prey et conteneurs de la Coiled Isle / Vaults of Atal'Utek, en alternant les slots disponibles
- les prismes de gemmes Midnight ouvrables sont inclus dans l'auto-ouverture : Amani Lapis, Tenebrous Amethyst, Sanguine Garnet et Harandar Peridot, dans leurs deux variantes d'item
- les `Weathered Mysterious Satchel` sont inclus dans l'auto-ouverture, dans leurs trois variantes de qualite : `235052` (vert), `235911` (bleu) et `236944` (epique) ; le `Pristine Mysterious Satchel` (`235054`, epique) l'est aussi
- des boutons independants `Ouvrir surplus` apparaissent pour les conteneurs de composants en surplus des 11 metiers Midnight reconnus, afin de pouvoir alterner les clics pendant leur ouverture
- des boutons `Fusionner` apparaissent pour les Resourceful Rebar (`247725`), Multicraft Matrix (`247719`) et Ingenious Identifier (`260630`) dès que 5 rang 1 sont dans les sacs ; un clic utilise 5 rang 1 pour créer leur version rang 2 (`247726`, `247724`, `247788`)
- les boutons d'action d'item (KP, recette, payout, surplus, fusion et traité) invalident leur cache et rafraichissent leur valeur dès le clic, puis se verrouillent pour bloquer le multiclic jusqu'à `BAG_UPDATE_DELAYED`
- le bouton `Utiliser KP` n'itère plus dans l'ordre des sacs : il sert un traité dès que le cooldown partagé des traités est écoulé, sinon les autres objets de connaissance, sinon le traité restant. Avec deux métiers Midnight cela donne `traité → autres KP → traité`, les objets intercalés laissant le cooldown s'écouler ; avec un seul traité, il part en premier comme avant
- ce déverrouillage est en plus soumis au cooldown réel de l'objet, lu via `C_Item.GetItemCooldown` : `IsUsableItem` ignore les cooldowns, si bien qu'un second traité restait cliquable pendant les 5 s, l'action partait, le serveur la rejetait en silence et le bouton semblait cassé. Le bouton reste grisé avec le temps restant affiché entre parenthèses, et se réactive seul
- les boutons payout et surplus n'utilisent pas de watchdog : ils itèrent sur les containers disponibles au fil des refreshs de sacs
- l'option `Proposer l'ouverture securisee des conteneurs YWT` est desactivee par defaut ; si elle est activee, les conteneurs suivis sont detectes hors combat, hors instance et hors interfaces sensibles, puis ouverts automatiquement via `C_Container.UseContainerItem`
- deux verdicts distincts sont persistes, et ils ne doivent jamais etre confondus :
  - `autoOpenForbidden` : le conteneur a declenche `ADDON_ACTION_BLOCKED` ou `ADDON_ACTION_FORBIDDEN`. Signal dur de Blizzard, propre a l'objet, pose **des la premiere erreur** : il n'est plus jamais tente automatiquement et passe uniquement par le bouton securise
- seul un blocage qui peut concerner l'usage de l'objet vaut refus du client. Le module mute son propre bouton securise juste avant la tentative, alors que le conteneur est deja en attente : un `ADDON_ACTION_BLOCKED` sur ce widget (`...AutoOpenButton:SetEnabled()`) etait attribue au conteneur et le condamnait a vie, sans qu'aucun `/reload` ne le rattrape. Ces blocages sont ignores pour le verdict, et les entrees deja ecrites ainsi sont retirees au chargement, sans toucher aux vrais refus
  - `autoOpenFailed` : refus transitoire (personnage indisponible, loot en retard, sacs pleins). Ce n'est pas un verdict mais une simple fenetre de grace de 90 s : elle expire seule et la premiere ouverture reussie l'efface
- ces deux categories sont les seules, et une seule est terminale. Tout conteneur qui n'est pas blackliste est retente indefiniment : apres 3 echecs il attend la grace de 90 s, le bouton securise reste propose entre-temps, puis l'ouverture automatique repart, en boucle, jusqu'a ce qu'il s'ouvre. Si le personnage est indisponible a l'expiration de la grace, la relance est repoussee sans etre abandonnee. Aucun conteneur ouvrable n'est donc range durablement parce que les sacs etaient pleins ou le loot en retard
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

Dans `Echap > Options > AddOns > Yaya Weekly Tracker` (ou `/ywt options`), le panneau est construit par le socle partage `YayaCore.Settings` a partir des descripteurs de l'addon : un rail de douze categories a gauche (`Affichage`, `Chat et journal`, `Quetes generales`, `Quetes Midnight`, `Ressources Midnight`, `Autres rappels`, `Metiers Midnight`, `Metiers affiches et ordre`, `TomTom`, `Marchand Abondance`, `Conteneurs`, `Recettes Midnight`), une page scrollable par categorie a droite, et sur chaque page des cases a cocher, des sliders pour les seuils numeriques, des listes deroulantes pour les choix fermes et, pour les metiers, une liste ordonnee avec une case de visibilite et des fleches `^` / `v` par ligne. Les widgets relisent la base a chaque ouverture du panneau et chaque changement declenche un rafraichissement du tracker. Les options account-wide permettent de :

- cacher integralement la frame en combat (desactive par defaut)
- activer ou desactiver le tracking d'`Abondance`, de la `Soiree`, de `Neighborhood`, de `Liadrin`, des world bosses Val/Naigtal, du world boss selon gold ou ilvl, de la weekly de Halduron, des `Sparks of Tides`, du `Shard of Dundun` au plafond, de `Jard`, de `Containing the Helsworn`, du `Great Vault`, de l'`Archeo Legion 5000g`, des traites, des weeklies metiers trainer, du DMF metiers, des loots metiers, du dez Enchantement, des outils metiers, des enchantements des outils, de l'equipement de metier, de chaque recette Midnight, de `Lost Legends` et de `Research Console: Exploring the Void` (tous actives par defaut)
- activer l'achat automatique des sacs de materiaux d'enchantement du marchand d'Abondance (desactive par defaut)
- activer l'achat automatique des `Fused Vitality` du marchand d'Abondance (desactive par defaut)
- regler les seuils numeriques, tous account-wide : ilvl equipe en dessous duquel le world boss reste utile (`250`), seuil d'alerte des points de connaissance non depenses (`5`), seuil d'alerte de Moxie (`600`), ilvl minimal (`232`) et rarete minimale (`rare`) de l'equipement de metier
- choisir la verbosite du chat (`chatVerbosity`) : `Silencieux` n'affiche que les reponses aux commandes `/ywt`, `Normal` (defaut) ajoute les erreurs (Warbank, YayaQueue absent), `Detaille` ajoute les actions automatiques (ajouts et retraits YayaQueue, rappel `/ywt help` au login). Les erreurs fatales du rafraichissement sont toujours affichees, quel que soit le niveau
- masquer des metiers Midnight (`hiddenProfessions`, case decochee dans la liste `Metiers affiches et leur ordre`) et choisir leur ordre (`professionOrder`, fleches `^` / `v`) : les lignes de metier et les boutons `Ouvrir surplus` suivent cet ordre ; un metier absent de la liste enregistree est ajoute en queue dans l'ordre par defaut, un ID inconnu est ignore
- activer le journal de debug (`debugEnabled`, desactive par defaut, equivalent de `/ywt debug on`)

Ces reglages sont decrits par `runtimeState.trackingOptions` (categorie, cle, type, defaut, bornes, effet), des tables de donnees sans logique : `trackerUI.RegisterOptions` les passe a `YayaCore.Settings.BuildPanel` avec la base du compte et `trackerUI.ApplySettingChange` comme `onChange`, qui applique l'effet du descripteur (`combat`, `gear`, `waypoints`, `professions`, `autoopen`) puis planifie un rafraichissement. Les seuils sont lus par `trackerUI.GetNumberSetting`, qui retombe sur le defaut du descripteur si la valeur enregistree est absente ou corrompue. Sans `YayaCore.Settings` charge, le panneau n'est pas construit et une erreur fatale est journalisee, le reste de l'addon fonctionne.

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

Erreur de rafraichissement :

- `UpdateTracker` tourne dans un `pcall` : quand il echoue, la section affiche
  une seule ligne rouge a la place de son contenu. Cette ligne est coupee par la
  largeur de la frame, donc elle ne dit plus que `YWT: erreur, voir le chat ou
  /ywt log` et le texte entier part ailleurs
- le texte complet est imprime une fois dans le chat et ecrit dans le journal
  persistant sous `YWT FATAL`, **sans dependre du mode debug** : c'est justement
  quand le debug est eteint que l'erreur surprend. Il se relit apres coup avec
  `/ywt log`, meme apres un `/reload`
- un rafraichissement echoue se repete plusieurs fois par seconde : seul le
  premier message d'une serie identique est imprime et journalise, pour ne pas
  ecraser l'historique

Tests hors jeu :

- `addons/YayaWeeklyTracker/Tests/test_tracker_refresh.lua` charge la suite Yaya
  complete avec un client simule (`Tests/wow_env.lua`) et un personnage
  alchimiste equipe (`Tests/game_state.lua`), rejoue le cycle d'evenements, puis
  echoue si le moindre message d'erreur apparait ou si le scan d'equipement de
  metier ne rend plus le verdict attendu
- `addons/YayaWeeklyTracker/Tests/test_settings.lua` charge la meme suite avec
  `YayaCore/Settings.lua`, puis verifie les reglages de bout en bout : chaque
  descripteur a un defaut, un type connu et des bornes coherentes ; le panneau
  porte ses douze categories et ses widgets ; cocher, glisser un slider ou
  choisir dans une liste ecrit la base et planifie un rafraichissement ;
  `OnShow` relit la base sans la reecrire ; le seuil KP change fait apparaitre
  le jeton `KP 3` ; `hiddenProfessions` et `professionOrder` (en base comme par
  les fleches et cases du widget) pilotent les lignes de metier ; en verbosite
  `Silencieux` les reponses `/ywt` et les erreurs fatales passent, les erreurs
  et actions ordinaires sont tues, et reviennent en `Normal` / `Detaille`
- ils se lancent avec le reste de la suite par
  `pwsh -NoProfile -File .\scripts\Test-Addons.ps1`
- ce que ces tests ne couvrent pas : les mesures reelles de frame, les boutons
  securises et tout ce qui depend du client. Une validation en jeu reste
  necessaire pour l'affichage et les clics

Commande :

- `/ywt` ou `/ywt help` pour lister les commandes
- `/ywt options` pour ouvrir le panneau d'options de l'addon
- `/ywt reset` pour remettre la frame a sa position par defaut
- `/ywt debug [on|off|now]` pour basculer le journal de debug ou forcer un rafraichissement
- `/ywt log [n|clear]` pour lire ou vider le journal persistant
- `/ywt stuff [on|off|ilvl n|ilvl reset]` pour l'equipement de metier et son seuil d'ilvl
- `/ywt traites` pour activer/desactiver `Tracker les traites (inscription)`
- `/ywt traites on|off` pour forcer l'etat de `Tracker les traites (inscription)`
- `/ywt autoopen [reset [all]]` pour le bilan ou la purge des verdicts d'auto-ouverture
- les reponses aux commandes s'affichent toujours, quelle que soit la verbosite du chat
