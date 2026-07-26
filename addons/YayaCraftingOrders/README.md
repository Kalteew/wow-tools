# YayaCraftingOrders

Fork perso de l'addon patron orders.

Fonctions:

- prix via `TradeSkillMaster`
- utilise la moyenne observée de `YayaContainerValues` pour valoriser les containers connus (payouts, moxies, etc.)
- multi-selection des work orders
- ajout direct des commandes selectionnees dans `YayaQueue`
- les commandes ajoutees dans `YayaQueue` gardent maintenant leur `orderID` pour le bouton `Next`
- bouton `TOUT` avec 4 modes:
  - tout
  - recettes connues
  - recettes rentables
  - recettes avec les materiaux disponibles

Notes:

- le calcul de profit depend des donnees TSM
- les moyennes de containers sont recalculées avec le prix TSM courant; elles restent indisponibles si un item observé n'a pas de prix
- l'ajout dans `YayaQueue` queue des crafts de work orders en mode `crafts`, sans se baser sur les outputs deja presents en inventaire
- `/ypo debug` active ou desactive les traces de chargement pour la session
- `/ypo debug status` affiche un instantane de l'etat courant
