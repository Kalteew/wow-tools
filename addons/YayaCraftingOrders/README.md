# YayaCraftingOrders

Fork perso de l'addon patron orders.

Fonctions:

- prix via `YayaCraftedPriceAPI` quand disponible, avec fallback `TradeSkillMaster`
- utilise la moyenne observée de `YayaContainerValues` en dernier fallback pour valoriser les containers connus (payouts, moxies, etc.)
- multi-selection des work orders
- ajout direct des commandes selectionnees dans `YayaQueue`
- à la première ouverture d'un métier, uniquement à proximité de la station : ouvrir les commandes de patrons pendant 2 secondes puis revenir à la recette favorite, une fois par métier et par session
- à la première ouverture du métier, déclencher avec YayaQueue l'ajout de la recette favorite en concentration
- les commandes ajoutees dans `YayaQueue` gardent maintenant leur `orderID` pour le bouton `Next`
- bouton `TOUT` avec 4 modes:
  - tout
  - recettes connues
  - recettes rentables
  - recettes avec les materiaux disponibles

Notes:

- le calcul de profit depend du service de prix partage (TSM, snapshot AH, marchand, containers)
- une valeur partielle ou inconnue ne valide plus le profit ni l'auto-queue
- les moyennes de containers sont recalculées avec le prix TSM courant; elles restent indisponibles si un item observé n'a pas de prix
- l'ajout dans `YayaQueue` queue des crafts de work orders en mode `crafts`, sans se baser sur les outputs deja presents en inventaire
- les commandes reçues pendant les 2 secondes sur l'onglet patrons gardent les conditions actuelles de push vers `YayaQueue` et une commande avec concentration n'est ajoutée que si la concentration disponible, après les réservations YQ, suffit
- l'auto-queue utilise une valeur nette : KP 1000g, first craft 1000g, montée en compétence 200g, moxie 5000/600g ; la concentration coûte 3g/point en alchimie et 1g ailleurs
- `/ypo debug` active ou desactive les traces de chargement pour la session
- `/ypo debug status` affiche un instantane de l'etat courant
