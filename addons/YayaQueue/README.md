# YayaQueue

Addon Retail simple pour :

- ajouter une recette depuis l'UI Blizzard des metiers avec la quantite placee a cote du bouton `Ajouter YQ`
- afficher `dump conc.` sur une recette quand le metier ouvert depasse 500 concentration, puis ajouter le maximum de crafts concentrés permis par la concentration actuelle
- ajouter en une fois les first crafts connus non realises dont le cout CraftSim est strictement inferieur a 1000 po
- garder une frame flottante a l'ecran pour suivre la queue
- accepter des ajouts externes via `YayaQueueAPI.AddRecipe(...)`, des besoins supplementaires via `YayaQueueAPI.AddItem(...)`, leur retrait via `YayaQueueAPI.RemoveItem(...)` et des cibles idempotentes via `YayaQueueAPI.SetItemTarget(...)`
- afficher ce qu'il reste a acheter a l'HV ou au marchand
- afficher un bouton unique d'achat groupé chez les marchands compatibles
- exposer un onglet `YayaQueue` a l'HV avec un bouton unique `Rechercher tout` puis `Acheter suivant`
- afficher un bouton `Next` en bas de la queue pour avancer les crafts normaux et les patron orders, ouvrir automatiquement le bon onglet `Recipes` / `Patron Orders`, memoriser l'option concentration et proposer une etape `Mailbox` apres achat HV
- recalculer automatiquement les besoins selon l'inventaire courant

Notes :

- la queue est locale a l'addon, sans dependance obligatoire; l'ajout groupe des first crafts utilise CraftSim et sa source de prix
- par defaut la quantite correspond a un nombre de crafts, pas a un nombre d'outputs
- les first crafts deja en file, y compris via une commande patron hors recraft, et ceux dont un prix de composant est inconnu sont ignores; un composant lie sans prix AH est accepte a cout marginal nul seulement s'il est deja possede
- le bouton `first craft` n'est affiche que si la profession ouverte contient au moins une recette reellement ajoutable (cout, prix, queue et cooldown valides)
- les recettes a cooldown ne sont ajoutees que si une charge est disponible; les pools partages soustraient les crafts deja en queue puis reservent une charge par nouvel ajout
- les qualites de composants choisies par CraftSim sont memorisees puis transmises directement au craft; les composants simples restent geres automatiquement par Blizzard
- une recette sans plan CraftSim repasse explicitement en allocation automatique Blizzard afin qu'un ancien plan manuel ne bloque pas le craft
- la queue se decremente a chaque craft reussi de la recette correspondante
- `Next` reste verrouille pendant tout un lot de crafts et ne se reactive qu'au dernier craft confirme
- les reagents optionnels complexes ne sont pas encore memorises
- les items marchand sont detectes quand ils ont deja ete vus sur un marchand
- les items non-commodities a l'HV sont achetes une enchere a la fois
- les resultats de recherche provenant d'autres addons AH ne remplacent pas le cache de recherche `YayaQueue`
- un achat deja recu dans les sacs n'est pas recompte comme un faux envoi `Mailbox`
- `RemoveItem` ne retire que la demande directe ajoutee par un addon externe; les besoins des recettes restent intacts
