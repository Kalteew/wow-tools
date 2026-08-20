# Yaya Reagent Sniper

Ajoute l’onglet `YRS` à l’hôtel des ventes.

## Onglet Reset de marché

L’onglet `Reset` analyse un catalogue local versionné de composants et permet d’acheter une seule recommandation sélectionnée par clic humain. Il ne lance aucune boucle d’achat et ne dépose rien automatiquement.

- sélecteur compact `Toutes extensions` ou extension précise, avec nombre d’IDs du catalogue avant filtrage ; le statut de lancement affiche ensuite le nombre réel de candidats au pré-scan ;
- catalogue v4 séparé en `Réactifs bruts` et `Consommables préparés`, avec une checkbox persistante par type ; les deux sont activés par défaut et les anciennes versions du catalogue restent compatibles ;
- catalogue issu de `wow-tools/data/wow.sqlite3`, combinant matières/réactifs et sorties de recettes, puis retirant les objets achetables au vendeur contre de l’or (`jsonequip.buyprice > 0`) ; les objets achetés avec de l’honneur restent conservés ;
- pipeline progressif : chaque lot de 100 composants est filtré puis analysé en profondeur avant de charger le lot suivant ; les résultats Blizzard à index discontinu sont tous conservés et un scan sans candidat deep s’arrête avec le détail des rejets ;
- bouton `Pause` / `Reprendre` pendant l’analyse des paliers : les opportunités déjà calculées restent achetables sans interrompre la progression sauvegardée ;
- chaque opportunité détectée suspend automatiquement le scan cinq secondes afin de réserver immédiatement l’HV à l’achat ; sans action, l’analyse reprend seule ; un appui sur le bouton d’action unique verrouille la cible, lance l’actualisation/achat et ignore les multiclics ;
- bouton `Scan continu` optionnel : relance automatiquement un nouveau cycle à chaque fin de scan ;
- seuil `Seuil gold min. (po)` configurable : sous ce montant, les actions sont grisées, le scan est arrêté et aucune opération n’est lancée ; `0` désactive le seuil ;
- bouton `Blacklist` à côté de l’achat : l’item est retiré des opportunités et exclu des prochains scans ; l’onglet `Blacklist` des options permet de supprimer chaque exclusion ;
- rotation persistante par extension : l’ordre du catalogue reste fixe, mais chaque relance reprend après le dernier composant tenté ; les analyses incomplètes sont ainsi retentées après le reste de la liste ;
- lecture des auctions personnelles au début du scan : les quantités à tes prix sont retirées du calcul comme si tu les annulais ; le scan ne les annule jamais ;
- si tes auctions sont incluses dans une opportunité, le même clic les annule, vérifie leur disparition puis poursuit l’achat ;
- agrégation prix unitaire × quantité jusqu’au prochain palier réel ;
- coût à absorber, quantité, prix cible, profit net après 5 % de commission, ROI, risque et score sur 100 ;
- liquidité TSM (`DBRegionSoldPerDay` et `DBRegionSaleRate`) et horizon d’écoulement prudent ;
- exclusion des scans incomplets, références/liquidités manquantes, budgets dépassés, profits/ROI faibles et horizons trop longs ; les données expirées ne peuvent jamais lancer directement un achat ;
- réglages persistants : profit net minimum 250 po, ROI minimum 8 %, horizon maximum 7 jours, part de marché prudente 10 %, cible maximum 140 % de la référence et budget reset 500 000 po ;
- réglages Reset : score minimal de 0 à 100 (0 désactive le filtre) et case `Son à chaque nouvelle ligne`, appliqués sans rescanner grâce au cache ;
- priorité de maintien : les composants déjà présents dans tes sacs ajoutent jusqu’à 5 points au score, mais le stock restant ajoute un malus jusqu’à 8 points selon son horizon d’écoulement ; le compteur est rafraîchi sur `BAG_UPDATE_DELAYED` ;
- lignes sélectionnables, tooltip item exact, détail du scénario et états chargement/vide/erreur.
- tableau responsive calé sur le viewport réel : le nom utilise l’espace restant et les métriques secondaires passent dans le tooltip aux faibles largeurs, sans débordement horizontal ;
- une lecture profonde complète est directement achetable pendant dix secondes ; au clic, quantité, coût, cible et paliers en mémoire sont encore comparés avant `StartCommoditiesPurchase`, sans rescan réseau superflu ;
- si la profondeur change, devient incomplète ou expire, le même clic lance un rescan ciblé et poursuit automatiquement uniquement si quantité, coût et cible restent identiques ; sinon l’achat est bloqué et le nouveau plan doit être accepté par un nouveau clic ;
- les requêtes AH restent strictement sérialisées et attendent l’événement Blizzard sans polling ; le scan de fond s’arrête à 85 recherches profondes sur 60 secondes afin de réserver 5 appels prioritaires au bouton, sans jamais dépasser 90 ; un message throttle perdu n’est pas rejoué aveuglément ;
- le total retourné par Blizzard doit rester inférieur ou égal au coût des paliers recommandés, au budget Reset et à l’or disponible avant `ConfirmCommoditiesPurchase`. Offre indisponible, refus, dépassement ou timeout annulent proprement la transaction ; succès ou échec termine toujours cette unique tentative.
- cycle de vie explicite : succès, prix indisponible ou trop élevé retirent la ligne et son cache ; timeout avant confirmation ou erreur API marque la ligne `Périmé`, tandis qu’une issue inconnue après confirmation bloque tout nouvel achat pendant cinq minutes pour empêcher d’attribuer un événement tardif au mauvais item ; manque d’or ou budget insuffisant conserve la ligne en `Bloqué` ; fermer l’HV annule les timers et invalide les résultats visibles.

Les prix sont considérés expirés cinq minutes après la fin du scan complet, mais la ligne reste visible afin de permettre son rescan ciblé. Le catalogue couvre les matières/réactifs et les sorties de recettes consommables présents dans la base locale, avec recouvrements historiques conservés dans les extensions où ils sont utilisés ; les objets achetables au vendeur contre de l’or sont exclus à la génération, tandis que les objets achetés avec de l’honneur restent inclus ; `IsCommodity()` accepte les classes `Tradegoods` et `Consumable`, puis élimine les objets non vendables comme commodités. TSM ne fournit plus la liste à scanner : il sert uniquement à la référence de prix et à la liquidité. Sans ces données, le candidat reste connu mais est rejeté par les garde-fous ; les groupes TSM ne servent de fallback que si le fichier catalogue est absent ou vide. Les volumes journaliers TSM sont régionaux et servent d’estimation, pas de garantie de vente. L’achat direct réutilise le flux de commodities déjà éprouvé par l’onglet Sniper et garde l’onglet Reset affiché.

Pour régénérer le catalogue : depuis `wow-tools`, lancer `python scripts/wowhead/build_reagent_sniper_catalog.py`. Le script relit `wow.sqlite3`, dédoublonne les IDs par extension, exclut les `buyprice` vendeur en or et écrit le catalogue v3 ; l’addon filtre ensuite les non-commodités au chargement.

Le filtre de profit net exclut toute opportunité sous le seuil configuré, 250 po par défaut : les micro-resets à 20 po restent donc rejetés. Le score classe ensuite les opportunités : 48 % profit net, 22 % ROI, 10 % faible coût à absorber, 7 % liquidité (`DBRegionSaleRate`), 8 % vitesse d’écoulement et 5 % risque lié au prix cible face à la référence, puis applique la priorité et le malus du stock en sacs. Chaque composante est normalisée entre 0 et 1. Le profit utilise un pivot élevé `max(5 000 po, 5 × seuil minimum)`, le ROI va du minimum configuré à 100 %, le coût a un pivot à 10 % du budget, le sale rate est plafonné à 30 %, la vitesse va de zéro à l’horizon maximal, et le risque vaut 1 / 0,6 / 0,2 selon une cible sous 105 % / 112 % / au-delà de la référence. Le bonus stock va jusqu’à +5 points selon la part déjà détenue face à la quantité à absorber ; le malus va jusqu’à -8 points quand le stock représente un horizon complet de ventes configuré. La quantité et les ventes/jour alimentent la durée. À score égal, le profit net puis le ROI départagent les lignes.

Lors du premier chargement de cette version, les anciennes valeurs par défaut exactes (1 000 po, 15 %, 3 jours, 120 %) sont migrées vers les nouveaux défauts. Toute valeur différente, donc personnalisée, est conservée.

- liste à gauche des groupes contenant des réactifs avec une opération `Shopping` ;
- uniquement les items ayant une opération `Shopping` TSM valide ;
- bouton `Start scanning` puis recherche par lots de 100 clés, inspirée de PBS, avec reprise immédiate dès que le throttling se libère ;
- alerte sonore et message lorsqu’un prix est inférieur ou égal au `maxPrice` de l’opération ;
- affichage du prix max TSM et du pourcentage payé par rapport à ce max ;
- tri croissant des résultats sur ce pourcentage du max TSM, puis par identifiant d’item ;
- résultats présentés en colonnes fixes avec défilement et pourcentage du max TSM ;
- icône, nom chargé et tooltip WoW pour chaque réactif ;
- icône de qualité affichée à côté du nom et une seule ligne par item ;
- quantité strictement déterminée par `minRestock`, un `restockQuantity` positif et les `restockSources` TSM ;
- les achats confirmés sont comptés immédiatement comme stock en transit, puis réconciliés lorsque TSM les voit dans le courrier ou les sacs ;
- une alerte verte « rien à sniper » distingue les besoins déjà couverts d’un groupe vide, d’une opération invalide ou d’un scan sans résultat ;
- bouton `Actualiser` avant achat : le clic met le scan en pause, relit l’item auprès de Blizzard, puis devient `Acheter` ;
- l’achat de commodité est lancé uniquement après cette relecture ciblée et le total Blizzard est encore revalidé avant confirmation ;
- bouton Acheter désactivé si l’or du personnage est inférieur au coût proposé, avec détail requis/disponible au survol et seconde vérification sur le total Blizzard ;
- récupération automatique du scan si l’hôtel des ventes ne répond pas à la demande d’achat ;
- les lignes restent stables pendant les cycles : une absence, un timeout, un refus ou un prix périmé les marque `Périmé` sans les supprimer ;
- après un achat confirmé, la ligne est retirée lorsque le besoin TSM est réconcilié ;
- compteur de quantité achetée et d’or dépensé pour la session de scan ;
- champ `Or max / scan (po)` persistant, avec `0` pour désactiver la limite et blocage des achats dépassant le budget restant ;
- les lignes achetables passent avant les lignes bloquées, puis le tri par pourcentage max TSM reste appliqué dans chaque groupe ;
- une réponse de scan réussie met à jour les lignes existantes sans les recréer ; les lignes absentes ou devenues trop chères passent en `Périmé` en fin de cycle ; un timeout ne retire rien ;
- le scan continue pendant la détection, se met en pause au clic `Actualiser`/`Acheter`, puis reprend après la transaction ou l’échec ;
- si une requête de scan est encore en vol au clic, l’achat attend sa fin et le signal de disponibilité Blizzard afin d’éviter `Internal Auction Error` ;
- quitter l’onglet YRS ou Reset arrête le scan, annule ses timers et abandonne toute transaction YRS encore ouverte afin de laisser TSM/Auctionator reprendre l’hôtel des ventes ;
- tant qu’aucun onglet YRS/Reset n’est affiché, l’addon reste strictement dormant : aucun parcours des groupes TSM, aucun recalcul d’inventaire et aucune demande d’information d’objet ;
- les noms, icônes et rangs complets ne sont chargés que pour les opportunités réellement affichées, jamais pour toute la liste Shopping à l’ouverture de l’HV ;
- les opérations sans quantité maximale (`restockQuantity = 0`) sont ignorées pour éviter un achat non borné ;
- diagnostic temporaire persistant activé par défaut : transitions de slots, pertes/restaurations de liens, demandes d’items et requêtes AH sont conservées dans `YayaReagentSniperDB.diagnosticLog` (1 200 lignes maximum) ;
- commandes `/yrs debug on` pour afficher les traces en direct, `/yrs diag dump 40` pour les dernières lignes, `/yrs diag clear` pour vider le journal et `/yrs status` pour l’état courant.

Il n’y a volontairement pas de seuil ou de quantité locale : le prix et le besoin sont relus depuis l’opération Shopping TSM à chaque cycle.
