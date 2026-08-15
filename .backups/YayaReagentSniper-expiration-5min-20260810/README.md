# Yaya Reagent Sniper

Ajoute l’onglet `YRS` à l’hôtel des ventes.

## Onglet Reset de marché

L’onglet `Reset` analyse un catalogue local versionné de composants et permet d’acheter une seule recommandation sélectionnée par clic humain. Il ne lance aucune boucle d’achat et ne dépose rien automatiquement.

- sélecteur compact `Toutes extensions` ou extension précise, avec nombre de composants avant le scan ;
- catalogue v3 de 1 863 identifiants issus de `wow-tools/data/wow.sqlite3`, combinant les matières `items.is_gatherable=1` et les réactifs `profession_recipes`/`recipe_reagents`, puis retirant les objets achetables au vendeur contre de l’or (`jsonequip.buyprice > 0`) : Vanilla 330, Burning Crusade 162, Wrath 103, Cataclysm 91, Mists 125, Warlords 46, Legion 146, BfA 138, Shadowlands 218, Dragonflight 252, The War Within 130 et Midnight 122 ; les objets achetés avec de l’honneur restent conservés ;
- pré-scan des composants par lots, puis lecture profonde et paginée des paliers de commodités ;
- lecture des auctions personnelles au début du scan : les quantités à tes prix sont retirées du calcul comme si tu les annulais, sans annulation automatique ;
- agrégation prix unitaire × quantité jusqu’au prochain palier réel ;
- coût à absorber, quantité, prix cible, profit net après 5 % de commission, ROI, risque et score sur 100 ;
- liquidité TSM (`DBRegionSoldPerDay` et `DBRegionSaleRate`) et horizon d’écoulement prudent ;
- exclusion des scans incomplets, références/liquidités manquantes, budgets dépassés, profits/ROI faibles et horizons trop longs ; les données expirées ne peuvent jamais lancer directement un achat ;
- réglages persistants : profit net minimum 250 po, ROI minimum 8 %, horizon maximum 7 jours, part de marché prudente 10 %, cible maximum 140 % de la référence et budget reset 500 000 po ;
- lignes sélectionnables, tooltip item exact, détail du scénario et états chargement/vide/erreur.
- tableau responsive calé sur le viewport réel : le nom utilise l’espace restant et les métriques secondaires passent dans le tooltip aux faibles largeurs, sans débordement horizontal ;
- bouton direct `Acheter le reset` sur une recommandation fraîche : il lance `StartCommoditiesPurchase` depuis ce clic, sans quitter l’onglet Reset ;
- après expiration, le bouton devient `Actualiser puis acheter` et rescanner profondément uniquement cet item. Si les garde-fous passent encore, un nouveau clic humain sur `Acheter le reset` est requis pour conserver le contexte de clic Blizzard ; les auctions personnelles prises en compte doivent être annulées manuellement avant l’achat ;
- le total retourné par Blizzard doit rester inférieur ou égal au coût des paliers recommandés, au budget Reset et à l’or disponible avant `ConfirmCommoditiesPurchase`. Offre indisponible, refus, dépassement ou timeout annulent proprement la transaction ; succès ou échec termine toujours cette unique tentative.
- cycle de vie explicite : succès, refus, prix indisponible ou trop élevé retirent la ligne et son cache ; timeout ou erreur API conservent la ligne en `Périmé` mais effacent son cache et imposent un rescan ; manque d’or ou budget insuffisant conserve la ligne en `Bloqué` et se réévalue avec l’or ou les paramètres ; fermer l’HV annule les timers et invalide tous les résultats visibles.

Les prix sont considérés expirés deux minutes après la fin du scan complet, mais la ligne reste visible afin de permettre son rescan ciblé. Le catalogue couvre les matières premières de récolte et les réactifs de recettes présents dans la base locale, avec recouvrements historiques conservés dans les extensions où ils sont utilisés ; les objets achetables au vendeur contre de l’or sont exclus à la génération, tandis que les objets achetés avec de l’honneur restent inclus ; `IsCommodity()` élimine ensuite les objets non vendables comme commodités. TSM ne fournit plus la liste à scanner : il sert uniquement à la référence de prix et à la liquidité. Sans ces données, le candidat reste connu mais est rejeté par les garde-fous ; les groupes TSM ne servent de fallback que si le fichier catalogue est absent ou vide. Les volumes journaliers TSM sont régionaux et servent d’estimation, pas de garantie de vente. L’achat direct réutilise le flux de commodities déjà éprouvé par l’onglet Sniper et garde l’onglet Reset affiché.

Pour régénérer le catalogue : depuis `wow-tools`, lancer `python scripts/wowhead/build_reagent_sniper_catalog.py`. Le script relit `wow.sqlite3`, dédoublonne les IDs par extension, exclut les `buyprice` vendeur en or et écrit le catalogue v3 ; l’addon filtre ensuite les non-commodités au chargement.

Le filtre de profit net exclut toute opportunité sous le seuil configuré, 250 po par défaut : les micro-resets à 20 po restent donc rejetés. Le score classe ensuite les opportunités : 48 % profit net, 22 % ROI, 10 % faible coût à absorber, 7 % liquidité (`DBRegionSaleRate`), 8 % vitesse d’écoulement et 5 % risque lié au prix cible face à la référence. Chaque composante est normalisée entre 0 et 1. Le profit utilise un pivot élevé `max(5 000 po, 5 × seuil minimum)`, le ROI va du minimum configuré à 100 %, le coût a un pivot à 10 % du budget, le sale rate est plafonné à 30 %, la vitesse va de zéro à l’horizon maximal, et le risque vaut 1 / 0,6 / 0,2 selon une cible sous 105 % / 112 % / au-delà de la référence. La quantité et les ventes/jour n’ont pas de bonus séparé : elles alimentent les jours d’écoulement. À score égal, le profit net puis le ROI départagent les lignes.

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
- achat en un clic standard, puis confirmation automatique après revalidation du prix total Blizzard ;
- lancement de l’achat directement depuis le clic utilisateur, conformément aux restrictions d’actions protégées Blizzard ;
- bouton Acheter désactivé si l’or du personnage est inférieur au coût proposé, avec détail requis/disponible au survol et seconde vérification sur le total Blizzard ;
- récupération automatique du scan si l’hôtel des ventes ne répond pas à la demande d’achat ;
- retrait de la ligne uniquement lorsque Blizzard confirme que l’offre est indisponible ou refuse l’achat ;
- si la cotation exacte Blizzard dépasse le max TSM, la ligne est retirée immédiatement et ignorée pendant le cycle de scan suivant ;
- compteur de quantité achetée et d’or dépensé pour la session de scan ;
- champ `Or max / scan (po)` persistant, avec `0` pour désactiver la limite et blocage des achats dépassant le budget restant ;
- les lignes achetables passent avant les lignes bloquées, puis le tri par pourcentage max TSM reste appliqué dans chaque groupe ;
- une réponse de scan réussie retire immédiatement les lignes absentes ou devenues trop chères ; un timeout ne retire rien ;
- le scan continue pendant la détection, se met en pause au clic, retire la ligne après la transaction puis reprend ;
- si une requête de scan est encore en vol au clic, l’achat attend sa fin et le signal de disponibilité Blizzard afin d’éviter `Internal Auction Error` ;
- les opérations sans quantité maximale (`restockQuantity = 0`) sont ignorées pour éviter un achat non borné ;
- commande `/yrs debug on` pour tracer chaque étape du bouton Acheter et `/yrs status` pour afficher l’état courant.

Il n’y a volontairement pas de seuil ou de quantité locale : le prix et le besoin sont relus depuis l’opération Shopping TSM à chaque cycle.
