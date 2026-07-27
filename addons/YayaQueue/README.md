# YayaQueue

Addon Retail simple pour :

- ajouter une recette depuis l'UI Blizzard des metiers avec la quantite placee a cote du bouton `Ajouter YQ`
- afficher sur la page de fabrication une frame de sélection de qualité YQ, avec icônes de qualité, qualité maximale atteignable, concentration optionnelle, quantité conservée entre les recettes avec reset `R` et choix automatique des réactifs les moins chers
- afficher cette frame comme une fenêtre flottante déplaçable, avec une icône par réactif et les quantités réparties par qualité
- afficher toujours `dump conc.` sur une recette visible, puis le griser si la concentration restante après la queue ne permet pas d'ajouter au moins un craft tout en conservant le seuil de 500
- inclure le réactif actuellement sélectionné dans les slots requis sélectionnables (par exemple Mote of Primal Energy), même si l’API de transaction l’omet
- ajouter en une fois les first crafts connus non realises dont le cout CraftSim est strictement inferieur a 1000 po
- garder une frame flottante a l'ecran pour suivre la queue
- accepter des ajouts externes via `YayaQueueAPI.AddRecipe(...)`, des besoins supplementaires via `YayaQueueAPI.AddItem(...)`, leur retrait via `YayaQueueAPI.RemoveItem(...)` et des cibles idempotentes via `YayaQueueAPI.SetItemTarget(...)`
- afficher ce qu'il reste a acheter a l'HV ou au marchand
- afficher un bouton unique d'achat groupé chez les marchands compatibles
- acheter automatiquement les composants manquants à l'ouverture d'un marchand compatible (désactivable avec `/yq vendor off`)
- exposer un onglet `YayaQueue` a l'HV, le selectionner par defaut quand des achats HV sont requis, avec un bouton unique `Rechercher tout` puis `Acheter suivant`
- afficher un bouton `Next` en bas de la queue pour avancer les crafts normaux et les patron orders, ouvrir automatiquement le bon onglet `Recipes` / `Patron Orders`, memoriser l'option concentration et proposer une etape `Mailbox` apres achat HV
- reutiliser le bind scroll de `TSMMacro` quand cette macro existe : ses actions `Shopping Buyout` / `Craft Next` sont remplacees au login par des relais YQ, qui retombent sur TSM hors contexte YQ
- recalculer automatiquement les besoins selon l'inventaire courant

Notes :

- la queue est locale a l'addon, sans dependance obligatoire; l'ajout groupe des first crafts utilise CraftSim et sa source de prix
- par defaut la quantite correspond a un nombre de crafts, pas a un nombre d'outputs
- les first crafts deja en file, y compris via une commande patron hors recraft, et ceux dont un prix de composant est inconnu sont ignores; un composant lie sans prix AH est accepte a cout marginal nul seulement s'il est deja possede
- le bouton `first craft` n'est affiche que si la profession ouverte contient au moins une recette reellement ajoutable (cout, prix, queue et cooldown valides)
- les recettes a cooldown ne sont ajoutees que si une charge est disponible; les pools partages soustraient les crafts deja en queue puis reservent une charge par nouvel ajout
- les qualites de composants choisies par CraftSim sont memorisees puis transmises directement au craft; les composants simples restent geres automatiquement par Blizzard
- le bouton de sélection de qualité fonctionne sans CraftSim en simulant les allocations mixtes via l'API native de métier et optimise la qualité de résultat exacte sélectionnée; les composants fixes et automatiques restent hors de l'appel de simulation Blizzard comme dans CraftSim, Midnight utilise 2 qualités de réactifs tandis que les équipements conservent jusqu'à 5 qualités de résultat
- la frame qualité affiche le `dbminbuyout` TSM du résultat exact et un profit estimé par qualité après commission HV de 5 % et coût complet des réactifs en or; un équipement est chiffré avec son niveau d'objet exact, les composants marchand utilisent `vendorbuy`, les monnaies de métier sont exclues comme dans CraftSim et une donnée d'objet inconnue reste affichée `?`
- `Ajouter YQ` est bloqué si la concentration restante après la queue et le seuil de 500 ne couvre pas tout le lot; décocher la concentration resélectionne la qualité maximale atteignable sans elle
- les entrées ajoutées via la frame qualité mémorisent `targetQuality`, les réactifs qualité sélectionnés et l'option concentration
- une recette sans plan CraftSim repasse explicitement en allocation automatique Blizzard afin qu'un ancien plan manuel ne bloque pas le craft
- la queue se decremente a chaque craft reussi de la recette correspondante
- `Next` reste verrouille pendant tout un lot de crafts et ne se reactive qu'au dernier craft confirme
- les reagents optionnels complexes ne sont pas encore memorises
- les items marchand sont detectes quand ils ont deja ete vus sur un marchand
- l'achat automatique marchand lance une seule séquence par ouverture ; chaque item accepté n'est soumis qu'une fois, avec vérification des sacs et jusqu'à 10 relances pour les échecs
- les items non-commodities a l'HV sont achetes une enchere a la fois
- les resultats de recherche provenant d'autres addons AH ne remplacent pas le cache de recherche `YayaQueue`
- un achat deja recu dans les sacs n'est pas recompte comme un faux envoi `Mailbox`
- `RemoveItem` ne retire que la demande directe ajoutee par un addon externe; les besoins des recettes restent intacts
