# YayaQueue

Addon Retail simple pour :

- ajouter une recette depuis l'UI Blizzard des metiers avec une quantite
- garder une frame flottante a l'ecran pour suivre la queue et regler la quantite
- accepter des ajouts externes via `YayaQueueAPI.AddRecipe(...)`
- afficher ce qu'il reste a acheter a l'HV ou au marchand
- afficher des boutons d'achat direct chez les marchands compatibles
- exposer un onglet `YayaQueue` a l'HV avec un bouton unique `Rechercher tout` puis `Acheter suivant`
- afficher un bouton `Next` en bas de la queue pour avancer les crafts normaux et les patron orders, avec memorisation de l'option concentration et une etape `Mailbox` apres achat HV
- recalculer automatiquement les besoins selon l'inventaire courant

Notes :

- la queue est locale a l'addon, sans dependance TSM
- par defaut la quantite correspond a un nombre de crafts, pas a un nombre d'outputs
- la queue se decremente a chaque craft reussi de la recette correspondante
- les reagents optionnels complexes ne sont pas encore memorises
- les items marchand sont detectes quand ils ont deja ete vus sur un marchand
- les items non-commodities a l'HV sont achetes une enchere a la fois
