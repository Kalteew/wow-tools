# Yaya Reagent Sniper

Ajoute l’onglet `YRS` à l’hôtel des ventes.

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
