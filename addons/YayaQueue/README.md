# YayaQueue

Addon Retail simple pour :

- ajouter une recette depuis l'UI Blizzard des metiers avec la quantite placee a cote du bouton `Ajouter YQ`
- afficher sur la page de fabrication une frame de sélection de qualité YQ, avec icônes de qualité, qualité maximale atteignable, concentration optionnelle, quantité conservée entre les recettes (réinitialisation configurable dans les options WoW, désactivée par défaut) avec reset `R` et choix automatique des réactifs les moins chers
- afficher cette frame comme une fenêtre flottante déplaçable, avec une icône par réactif et les quantités réparties par qualité
- afficher toujours `dump conc.` sur une recette visible, puis le griser si la concentration restante après les réservations de la queue ne permet pas d'ajouter au moins un craft tout en conservant le seuil de 500
- inclure le réactif actuellement sélectionné dans les slots requis sélectionnables (par exemple Mote of Primal Energy), même si l’API de transaction l’omet
- ajouter en une fois les first crafts connus non realises dont le cout CraftSim est strictement inferieur a 1000 po
- garder une frame flottante a l'ecran pour suivre la queue
- accepter des ajouts externes via `YayaQueueAPI.AddRecipe(...)`, des besoins supplementaires via `YayaQueueAPI.AddItem(...)`, leur lecture via `YayaQueueAPI.GetDirectItemQuantity(...)`, leur retrait via `YayaQueueAPI.RemoveItem(...)` et des cibles idempotentes via `YayaQueueAPI.SetItemTarget(...)`
- afficher ce qu'il reste a acheter a l'HV ou au marchand
- afficher un bouton unique d'achat groupé chez les marchands compatibles
- acheter automatiquement les composants manquants à l'ouverture d'un marchand compatible (désactivable avec `/yq vendor off`)
- exposer un onglet `YayaQueue` a l'HV, le selectionner par defaut quand des achats HV sont requis, avec un bouton unique `Rechercher tout` puis `Acheter suivant`
- persister le dernier prix unitaire observe a l'HV dans `YayaQueueDB` (region pour les commodities, royaume pour les autres objets) et le reutiliser pour les prix des reactifs
- comparer chaque achat au snapshot precedent; une hausse affiche une alerte dans le chat, joue un son, puis laisse l'achat automatique continuer
- afficher un bouton `Next` en bas de la queue pour avancer les crafts normaux et les patron orders, ouvrir automatiquement le bon onglet `Recipes` / `Patron Orders`, memoriser l’option concentration et proposer une etape `Mailbox` apres achat HV
- equiper automatiquement l’outil principal Multicraft ou Resourcefulness avant les crafts YayaQueue, avec confirmation en deux clics et regroupement de la queue pour limiter les changements d’outil
- à la première ouverture de chaque métier, ajouter le lot maximal de la recette favorite en concentration ; après le craft, réinjecter un craft si un remboursement d'Ingéniosité laisse assez de concentration
- reutiliser le bind scroll de `TSMMacro` quand cette macro existe : ses actions `Shopping Buyout` / `Craft Next` sont remplacees au login par des relais YQ, qui retombent sur TSM hors contexte YQ
- recalculer automatiquement les besoins selon l'inventaire courant
- choisir récursivement entre achat direct et fusion des rangs Gold Star, avec les Gold Stars déjà détenues par le personnage valorisées à 0 (jamais la banque de bataillon), puis exécuter les fusions nécessaires via `Next` avant le craft final
- lors du `dump conc.` et de l’auto-dump de concentration du favori, vider uniquement les réactifs de finition liés dans les sacs du personnage, y compris le sac de réactifs, par sous-lots Multicraft puis Resourcefulness puis Ingéniosité ; une réinjection après proc d’Ingéniosité applique les mêmes règles et ne se fait qu’après les réservations de concentration déjà présentes dans la queue

Notes :

- la queue est locale a l'addon, sans dependance obligatoire; l'ajout groupe des first crafts utilise CraftSim et sa source de prix
- par defaut la quantite correspond a un nombre de crafts, pas a un nombre d'outputs
- les first crafts deja en file, y compris via une commande patron hors recraft, et ceux dont un prix de composant est inconnu sont ignores; un composant lie sans prix AH est accepte a cout marginal nul seulement s'il est deja possede
- le bouton `first craft` n'est affiche que si la profession ouverte contient au moins une recette reellement ajoutable (cout, prix, queue et cooldown valides)
- les recettes a cooldown ne sont ajoutees que si une charge est disponible; les pools partages soustraient les crafts deja en queue puis reservent une charge par nouvel ajout
- les qualites de composants choisies par CraftSim sont memorisees puis transmises directement au craft; les composants simples restent geres automatiquement par Blizzard
- le sélecteur utilise un solveur de coût exact par points de compétence : toutes les répartitions entières R1/R2/R3 restent possibles (`41/59` compris), mais les devis sont pré-calculés par paliers `SmartAvgBuy`/marché et les seuils Blizzard sont affinés par dichotomie ; les lignes sont calibrées sur `0`, `1`, `N-1` et `N`, et un modèle non linéaire est refusé au lieu d'afficher un faux optimum
- une recette à plusieurs lignes de réactifs qualité utilise les poids entiers exposés par CraftSim; si ces poids manquent, YQ signale l'optimum exact indisponible au lieu d'approximer
- le solveur garde en cache les plans de plusieurs recettes pendant toute la session et répartit un calcul inédit sur plusieurs frames (2 ms maximum) ; un craft ou la fermeture du métier ne vide plus ce cache, et coût/profit restent masqués pendant le calcul
- le coût des réactifs passe par `YayaCraftedPriceAPI` quand il est chargé : `SmartAvgBuy` jusqu'à la quantité couverte par `NumInventory`, puis snapshot AH, `vendorbuy`, `dbminbuyout`, `dbmarket` estimé et moyenne container; les outputs craftés conservent leur itemString exact et le profit après 5 % de commission HV
- les snapshots AH n'ont pas de TTL; TSM reste le repli quand aucun snapshot n'est disponible, sans comparaison de date car l'API TSM publique ne l'expose pas
- avec concentration, l'optimiseur exige exactement le rang précédent sans concentration puis vérifie le gain d'un rang avec l'API Blizzard ; il choisit uniquement le plan le moins cher en or, la concentration disponible servant seulement à autoriser le lot complet
- les coches concentration, finishing et Gold Star ainsi que la qualité désirée persistent entre les recettes; la qualité atteignable la plus proche est choisie si nécessaire
- la coche Gold Star est aussi mémorisée entre les sessions du personnage
- finishing est coché par défaut, mais le plan sans finishing reste toujours en concurrence et gagne s'il est moins cher ou si le finishing est inutile
- la ligne `Stock` affiche `C` (personnage courant, sacs/banque/courrier/AHV) et `W` (alts suivis, banque de bataillon et AH) via l’API TSM, en interrogeant le `levelItemString` exact des équipements ; les autres royaumes couverts par TSM sont inclus. Le repli natif ne filtre que les objets soulbound et affiche `?` si une banque n’a jamais été lisible
- les entrées ajoutées via la frame qualité mémorisent `targetQuality`, les allocations exactes, les optionnels retenus et l’option concentration
- pour un patron order, `Next` applique aussi `SetApplyConcentration` à la transaction de commande avant le craft ; le flag du contexte YCO ne reste pas limité aux crafts normaux
- chaque ajout d’une entrée avec concentration ajoute une demande de phial Haranir d’ingéniosité (R1 par défaut, R2 configurable via `/yq options`); le même bouton sécurisé `Next: Phial` consomme la phial depuis les sacs avant le craft normal ou le patron order si le buff est absent, puis redevient `Next: Craft` après confirmation du buff
- les achats marchand de phials Haranir d’ingéniosité se font par 10 minimum afin de conserver un buffer
- l’utilisation automatique des phials peut être désactivée dans `/yq options`; les demandes automatiques déjà présentes sont masquées pendant la désactivation
- une session YQ ne crée qu’une seule demande automatique de phial, même si plusieurs entrées concentration sont ajoutées
- une recette sans plan CraftSim repasse explicitement en allocation automatique Blizzard afin qu'un ancien plan manuel ne bloque pas le craft
- la queue se decremente a chaque craft reussi de la recette correspondante
- `Next` reste verrouille pendant tout un lot de crafts et ne se reactive qu'au dernier craft confirme
- la fenêtre qualité propose les réactifs optionnels de métier après les réactifs : leur difficulté, leur coût et leur allocation sont recalculés puis mémorisés dans la queue ; les missives impossibles pour la qualité choisie sont grisées
- `/yq opttest` exécute les tests internes du solveur, dont les répartitions `41/59`, les coûts à paliers, l’affinage des seuils, les trois rangs et les rangs supérieurs moins chers
- les items marchand sont detectes quand ils ont deja ete vus sur un marchand
- l'achat automatique marchand lance une seule séquence par ouverture ; chaque item accepté n'est soumis qu'une fois, avec vérification des sacs et jusqu'à 10 relances pour les échecs
- les items non-commodities a l'HV sont achetes une enchere a la fois
- le choix d’outil de craft ne calcule aucune rentabilité : il applique uniquement Multicraft puis Resourcefulness selon les statistiques de la recette
- les resultats de recherche provenant d'autres addons AH ne remplacent pas le cache de recherche `YayaQueue`
- la fermeture de l'HV invalide le cache de recherche afin que le retour dans l'onglet relance une recherche propre
- un achat deja recu dans les sacs n'est pas recompte comme un faux envoi `Mailbox`
- `RemoveItem` ne retire que la demande directe ajoutee par un addon externe; les besoins des recettes restent intacts
