# Yaya Reagent Sniper

Ajoute l’onglet `YRS` à l’hôtel des ventes.

## Onglet Reset de marché

L’onglet `Reset` analyse un catalogue local versionné de composants et permet d’acheter une seule recommandation sélectionnée par clic humain. Il ne lance aucune boucle d’achat et ne dépose rien automatiquement.

- sélecteur compact `Toutes extensions` ou extension précise, avec nombre d’IDs du catalogue avant filtrage ; le statut de lancement affiche ensuite le nombre réel de candidats au pré-scan ;
- catalogue v4 séparé en `Réactifs bruts` et `Consommables préparés`, avec une checkbox persistante par type ; les deux sont activés par défaut et les anciennes versions du catalogue restent compatibles ;
- catalogue issu de `wow-tools/data/wow.sqlite3`, combinant matières/réactifs et sorties de recettes, puis retirant les objets achetables au vendeur contre de l’or (`jsonequip.buyprice > 0`) ; les objets achetés avec de l’honneur restent conservés ;
- pipeline progressif : chaque lot de 100 composants est filtré puis analysé en profondeur avant de charger le lot suivant ; les résultats Blizzard à index discontinu sont tous conservés et un scan sans candidat deep s’arrête avec le détail des rejets ;
- bouton `Pause` / `Reprendre` pendant l’analyse des paliers : les opportunités déjà calculées restent achetables sans interrompre la progression sauvegardée ;
- chaque opportunité détectée suspend automatiquement le scan dix secondes afin de réserver immédiatement l’HV à l’achat ; le bouton d’action reste verrouillé 0,5 seconde, puis les clics répétés d’un autoclicker sont ignorés tant qu’une opération est active ; sans action, l’analyse reprend seule, tandis qu’un achat réussi relance toujours le scan dès que le transport Blizzard est prêt, même si le cycle précédent était terminé ;
- bouton `Scan continu` optionnel : relance automatiquement un nouveau cycle à chaque fin de scan ;
- scan continu en deux temps. Le **premier cycle** est le relevé profond : chaque composant est pré-scanné, son prix plancher est mémorisé, et son arbre de vente est analysé — c'est lui qui trouve les resets de marché. Les **cycles suivants** passent en snipe : le pré-scan par lots de 100 relit les planchers et seuls les composants dont le marché a bougé repartent en analyse profonde, ce qui raccourcit fortement le cycle et concentre les requêtes sur les nouvelles ventes sous-cotées ;
- un composant repart en analyse profonde s'il n'a pas encore de plancher mémorisé, si son plancher a baissé, ou si sa quantité totale a augmenté à plancher inchangé. La décision se prend par composant et non par numéro de cycle : une analyse interrompue est donc reprise au passage suivant. Les garde-fous existants s'appliquent avant : un plancher au-dessus de `Cible/réf. (%)` de la référence reste rejeté ;
- le plancher est mémorisé même pour les composants rejetés par les garde-fous — c'est justement leur chute ultérieure qui en fera une cible. Un composant sans offre voit son plancher oublié, afin que le retour d'une vente compte comme une baisse ;
- les cibles d'un lot sont analysées immédiatement, sans attendre la fin du catalogue, et triées par priorité : baisse de plancher d'abord (de la plus forte à la plus faible), puis volume ajouté, puis composants jamais analysés ;
- les planchers mémorisés vivent le temps de la session d'hôtel des ventes. Ils sont oubliés — et le cycle suivant repart en relevé profond complet — à la fermeture de l'HV, au changement d'extension ou de type, via le bouton `Cycle profond` du panneau `Paramètres`, par un clic droit sur `Scanner le marché`, et à l'expiration du réglage `Cycle profond (min)` ;
- un cycle snipe sans aucune baisse est le cas normal : il n'arrête plus le scan continu et affiche `Aucune baisse détectée • prochain cycle…`. Seul un cycle qui n'a rien pu évaluer du tout coupe le scan continu ;
- seuil `Seuil gold min. (po)` configurable : sous ce montant, les actions sont grisées, le scan est arrêté et aucune opération n’est lancée ; `0` désactive le seuil ;
- bouton `Blacklist` à côté de l’achat : l’item est retiré des opportunités et exclu des prochains scans ; l’onglet `Blacklist` des options permet de supprimer chaque exclusion ;
- ordre de scan par ancienneté décroissante : en `Toutes extensions`, le catalogue commence par Midnight et finit par Vanilla, les objets étant triés à l’intérieur de chaque extension. Un objet partagé entre deux extensions est retenu sous la plus récente qui le contient ;
- en `Toutes extensions`, chaque cycle repart donc systématiquement des extensions les plus récentes : la rotation persistante y est neutralisée, sans quoi le second cycle reprendrait au milieu de la liste ;
- rotation persistante sur une extension précise : l’ordre du catalogue reste fixe, mais chaque relance reprend après le dernier composant tenté ; les analyses incomplètes sont ainsi retentées après le reste de la liste ;
- lecture des auctions personnelles au début du scan : les quantités à tes prix sont retirées du calcul comme si tu les annulais ; le scan ne les annule jamais ;
- si tes auctions sont incluses dans une opportunité, le même clic les annule, vérifie leur disparition puis poursuit l’achat ;
- agrégation prix unitaire × quantité jusqu’au prochain palier réel ;
- coût à absorber, quantité, prix cible, profit net après 5 % de commission, ROI, risque et score sur 100 ;
- liquidité TSM (`DBRegionSoldPerDay` et `DBRegionSaleRate`) et horizon d’écoulement prudent ;
- exclusion des scans incomplets, références/liquidités manquantes, budgets dépassés, profits/ROI faibles et horizons trop longs ; les données expirées ne peuvent jamais lancer directement un achat ;
- réglages persistants : profit net minimum 250 po, ROI minimum 8 %, horizon maximum 7 jours, part de marché prudente 10 %, cible maximum 140 % de la référence et budget reset 500 000 po ; le budget effectif vaut toujours le minimum entre ce réglage et l’or du personnage courant ;
- réglage `Cycle profond (min)` : au-delà de ce délai, le cycle suivant oublie les planchers mémorisés et refait un relevé profond complet, afin de rattraper les marchés qui ont bougé sans que leur plancher ne baisse. 15 minutes par défaut, `0` désactive ;
- réglages Reset : score minimal de 0 à 100 (0 désactive le filtre) et case `Son à chaque nouvelle ligne`, appliqués sans rescanner grâce au cache ;
- priorité de maintien : les composants déjà présents dans tes sacs ajoutent jusqu’à 5 points au score, mais le stock restant ajoute un malus jusqu’à 8 points selon son horizon d’écoulement ; le compteur est rafraîchi sur `BAG_UPDATE_DELAYED` ;
- lignes sélectionnables, tooltip item exact, détail du scénario et états chargement/vide/erreur.
- tableau responsive calé sur le viewport réel : le nom utilise l’espace restant et les métriques secondaires passent dans le tooltip aux faibles largeurs, sans débordement horizontal ;
- une lecture profonde complète est directement achetable pendant dix secondes après le verrou initial de 0,5 seconde ; au clic, quantité, coût, cible et paliers en mémoire sont encore comparés avant `StartCommoditiesPurchase`, sans rescan réseau superflu ;
- si la profondeur change, devient incomplète ou expire, le bouton passe à `Actualiser` ; le clic suivant lance uniquement le rescan ciblé, puis un nouveau verrou de 0,5 seconde précède le clic d’achat, sans achat automatique après refresh ;
- le libellé du bouton d’action ne dépend que de l’état de la sélection, jamais d’un blocage passager : pendant un scan, le transport Blizzard se libère et s’occupe toutes les 100 ms, ce qui faisait auparavant alterner le bouton entre `Acheter le reset` et `Actualiser`. L’occupation du transport ne grise plus le bouton qu’au-delà de 0,4 seconde, et les widgets ne sont réécrits que sur changement réel ;
- un rafraîchissement des sacs pendant la fenêtre d’achat ne périme plus l’opportunité : la vérification profonde est conservée avec les paliers en cache ;
- les requêtes AH restent strictement sérialisées et privilégient l’événement Blizzard, avec une relance temporisée de secours si le signal throttle est perdu ; le scan de fond s’arrête à 85 recherches profondes sur 60 secondes afin de réserver 5 appels prioritaires au bouton, sans jamais dépasser 90 ; un message throttle perdu n’est pas rejoué aveuglément ;
- le prix unitaire direct et le total retournés par Blizzard doivent rester sous les plafonds immuables des paliers recommandés, le budget Reset relu et l’or disponible avant `ConfirmCommoditiesPurchase` ; aucune moyenne synthétique n’est acceptée ;
- cycle de vie explicite : le succès retire la ligne ; prix indisponible, refus ou timeout avant confirmation la passent à `Actualiser`, tandis qu’un prix hors garde-fous retire l’opportunité et qu’une issue inconnue après confirmation conserve la transaction en quarantaine cinq minutes ; fermer l’HV invalide les résultats et garde cette protection après confirmation.

Les prix sont considérés expirés cinq minutes après la fin du scan complet, mais la ligne reste visible afin de permettre son rescan ciblé. Le catalogue couvre les matières/réactifs et les sorties de recettes consommables présents dans la base locale, avec recouvrements historiques conservés dans les extensions où ils sont utilisés ; les objets achetables au vendeur contre de l’or sont exclus à la génération, tandis que les objets achetés avec de l’honneur restent inclus ; `IsCommodity()` accepte les classes `Tradegoods` et `Consumable`, puis élimine les objets non vendables comme commodités. TSM ne fournit plus la liste à scanner : il sert uniquement à la référence de prix et à la liquidité. Sans ces données, le candidat reste connu mais est rejeté par les garde-fous ; les groupes TSM ne servent de fallback que si le fichier catalogue est absent ou vide. Les volumes journaliers TSM sont régionaux et servent d’estimation, pas de garantie de vente. L’achat direct réutilise le flux de commodities déjà éprouvé par l’onglet Sniper et garde l’onglet Reset affiché.

Pour régénérer le catalogue : depuis `wow-tools`, lancer `python scripts/wowhead/build_reagent_sniper_catalog.py`. Le script relit `wow.sqlite3`, dédoublonne les IDs par extension, exclut les `buyprice` vendeur en or et écrit le catalogue v3 ; l’addon filtre ensuite les non-commodités au chargement.

Le filtre de profit net exclut toute opportunité sous le seuil configuré, 250 po par défaut : les micro-resets à 20 po restent donc rejetés. Le score classe ensuite les opportunités : 48 % profit net, 22 % ROI, 10 % faible coût à absorber, 7 % liquidité (`DBRegionSaleRate`), 8 % vitesse d’écoulement et 5 % risque lié au prix cible face à la référence, puis applique la priorité et le malus du stock en sacs. Chaque composante est normalisée entre 0 et 1. Le profit utilise un pivot élevé `max(5 000 po, 5 × seuil minimum)`, le ROI va du minimum configuré à 100 %, le coût a un pivot à 10 % du budget, le sale rate est plafonné à 30 %, la vitesse va de zéro à l’horizon maximal, et le risque vaut 1 / 0,6 / 0,2 selon une cible sous 105 % / 112 % / au-delà de la référence. Le bonus stock va jusqu’à +5 points selon la part déjà détenue face à la quantité à absorber ; le malus va jusqu’à -8 points quand le stock représente un horizon complet de ventes configuré. La quantité et les ventes/jour alimentent la durée. À score égal, le profit net puis le ROI départagent les lignes.

Lors du premier chargement de cette version, les anciennes valeurs par défaut exactes (1 000 po, 15 %, 3 jours, 120 %) sont migrées vers les nouveaux défauts. Toute valeur différente, donc personnalisée, est conservée.

## Mode Cancel & Repost

Deux cases indépendantes dans le panneau `Paramètres` de l'onglet Reset : `Annuler les sous-cotées` et `Remettre en vente`. L'une ou l'autre suffit à activer la phase de vente, et le même bouton d'action propose alors tour à tour d'acheter, d'annuler une enchère sous-cotée, ou de remettre une commodité en vente. Priorité : acheter, puis annuler, puis reposter. Les deux options sont séparées parce qu'une enchère annulée revient par courrier : on peut vouloir remettre en vente sans annuler.

- **une action par clic.** `C_AuctionHouse.CancelAuction` et `PostCommodity` sont des appels restreints par Blizzard : ils partent du clic courant et ne supportent ni file ni minuterie. Le libellé indique combien de cibles restent ;
- **une enchère annulée revient par courrier**, pas dans les sacs. Le cycle annuler → reposter ne boucle donc pas dans une seule visite à l'hôtel des ventes : il faut passer par la boîte aux lettres, comme avec TSM. Ce qui est reposté dans un cycle, ce sont les commodités déjà en sac — achats du Reset ou objets récupérés du courrier avant de venir ;
- **prix sourcés sur tes opérations Auctioning TSM.** `TSM_API` n'expose aucune opération : elles sont lues dans la table `TradeSkillMasterDB` vivante, qui reflète immédiatement les éditions faites dans l'interface de TSM. L'opération effective d'un objet suit le groupe, l'héritage de groupe, la chaîne `relationships`, et les exclusions par personnage ou royaume ;
- champs honorés : `minPrice`, `maxPrice`, `normalPrice`, `undercut`, `postCap`, `keepQuantity`, `duration`, les redirections `aboveMax` et `priceReset`, ainsi que `cancelUndercut`, `cancelRepost`, `cancelRepostThreshold` et `ignoreLowDuration`. En Retail il n'y a pas de taille de pile : la quantité postée vaut `min(postCap, disponible - keepQuantity - réserve de craft)` en une seule enchère ;
- **objets sans opération** : le prix undercut le marché mais ne descend jamais sous `first(105% smartavgbuy, 80% dbrecent)`. Sous ce plancher, l'objet n'est pas posté et reste en sac pour le cycle suivant ; si le plancher lui-même est introuvable, pas de mise en vente non plus. Aucun réglage de prix n'est ajouté à l'onglet ;
- **détection de la sous-cotation, à l'identique de TSM** : le critère est celui de `MakeCancelDecision` — si le lot le moins cher contient tes unités, tu es en tête de file et tu n'es pas sous-coté, quel que soit le nombre de vendeurs à ce prix. C'est `numOwnerItems` du premier résultat de recherche qui le dit ;
- une enchère est donc annulée dans deux cas : un prix strictement plus bas existe, ou un autre vendeur occupe ton prix et la file le place devant toi. Dans le second cas, remettre en vente au même prix te replace en tête (LIFO) ;
- **garde-fou anti-boucle** : quand un prix plus bas existe mais que la remise en vente ne pourrait pas descendre — plancher automatique ou `minPrice` de l'opération — l'enchère est laissée en place. Sans lui, elle serait annulée puis reposée à l'identique à chaque cycle, chaque annulation renvoyant la pile au courrier. Si la position dans la file est inconnue, rien n'est annulé ;
- `cancelRepost` annule aussi pour reposter plus haut quand la concurrence a disparu et que l'écart dépasse `cancelRepostThreshold`. `cancelUndercut = false` et `ignoreLowDuration` sont respectés ;
- **réserve de craft** : les quantités présentes dans la file de craft TSM sont retirées du disponible, afin de ne pas vendre des réactifs prévus pour un craft ;
- **seuil d'or** : sous `Seuil or min. (po)`, les phases d'achat sont sautées et le cycle enchaîne les cycles de vente sans interrompre le scan continu. Au-dessus du seuil, achat et vente alternent dans le même scan continu ;
- si Blizzard demande sa propre confirmation de mise en vente (prix très bas face au marché), le statut invite à valider sa fenêtre : cette confirmation ne peut pas être automatisée. Le plancher rend ce cas rare ;
- diagnostic : `RESET_SELL_CHECK` trace chaque enchère examinée avec ton prix, le prix du lot le moins cher, ta présence en tête de file, le prix de repost visé et le verdict ; `RESET_SELL_TARGETS`, `RESET_SELL_CANCEL` et `RESET_SELL_POST` couvrent le reste du flux ;
- les décisions de prix et d'annulation vivent dans `YayaReagentSniperSell.lua`, testé hors du jeu par `Tests/test_yayareagentsnipersell.lua`.

## Onglet YRS — restock Shopping TSM

- la sélection d’un groupe construit tous les besoins Shopping `i:` valides, commodités et enchères unitaires ;
- la recherche démarre automatiquement, sérialise une requête par item et conserve les cotations sans expiration pendant la session de l’HV ;
- un bouton fixe suit le flow YayaQueue : `Recherche…`, `Acheter suivant`, `Achat…`, `Rechercher tout` ou `Rien à acheter` ; les clics répétés pendant une opération sont ignorés ;
- le bouton `Passer`, placé à côté de l’achat, retire la cible suivante et ignore cet item pour la session courante, jusqu’au prochain `/reload` ;
- la liste scrollable n’a pas de plafond de données ; elle affiche prix unitaire, `% max`, quantité achetée et coût total de la ligne, avec la prochaine cible surlignée ;
- les offres achetables sont triées par `% max` croissant, puis par item ; les offres bloquées restent visibles après elles ;
- `showAboveMaxPrice` désactivé bloque les offres au-dessus du max ; activé, il retire tout plafond de prix, y compris si la cotation monte entre recherche et confirmation ;
- la checkbox persistante `Acheter au-dessus du max` sert de coupe-circuit global sur la page : elle doit être cochée en plus de l’autorisation de l’opération Shopping TSM ;
- le `% max` reste toujours visible et passe en alerte au-dessus de 100 %, avec message et son optionnel, sans popup ni confirmation supplémentaire ;
- les seules limites d’un achat autorisé au-dessus du max sont le besoin TSM restant, l’or disponible et le budget de session (`0` = illimité) ;
- le seuil persistant `Stock manquant min. (%)` filtre les restocks selon la part manquante de la cible TSM (`50` exige au moins 50 % manquants, `0` désactive le filtre) ;
- les commodités utilisent `StartCommoditiesPurchase`, relisent politique, quantité, or et budget sur la cotation Blizzard, puis confirment automatiquement ;
- les appels d’achat restreints (`StartCommoditiesPurchase` et `PlaceBid`) partent immédiatement du clic courant, jamais d’un timer ou d’un événement throttle, comme dans YayaQueue ; YRS n’invente plus de timeout local de cotation à 5 secondes ;
- les enchères unitaires conservent l’`auctionID` exact et n’appellent `PlaceBid` que si le stack complet tient encore dans le besoin TSM ;
- un succès ajoute la quantité au stock en transit, retire uniquement la cotation achetée et laisse immédiatement le bouton servir la suivante ;
- après un succès, le bouton suivant redevient cliquable sans attendre le signal throttle ; si Blizzard n’est pas encore prêt, cette attente reste interne à la nouvelle transaction ;
- une erreur invalide uniquement l’item concerné ; les autres cotations restent utilisables ;
- une hausse réellement refusée par le plafond TSM met à jour la ligne et la laisse visible mais bloquée, sans rescan automatique ni boucle de sélection ;
- les protections par génération, drainage et quarantaine empêchent un événement tardif de valider la transaction suivante ;
- `YayaReagentSniperAPI.IsAuctionContextActive()` et `OnAuctionActionClick()` exposent le relais du bouton unique ;
- commandes de diagnostic : `/yrs debug on`, `/yrs diag dump 40`, `/yrs diag clear` et `/yrs status`.
