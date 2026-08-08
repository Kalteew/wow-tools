# YayaContainerValues

Suit generiquement les items ouverts depuis les sacs et agrège les IDs/quantités obtenus par container.

- les ouvertures et sorties sont stockées dans `YayaContainerValuesDB`
- une ouverture est enregistrée dès qu'au moins un output objet est observé, même sans prix TSM
- seules les utilisations de slots marqués `hasLoot` par WoW ou signalées explicitement par un addon sont suivies
- les recettes, armes, armures, consommables de connaissance et vellums ne deviennent pas des containers
- les entrées vides et les faux containers connus sont supprimés au chargement
- l'item utilisé est lu dans le snapshot du slot pris avant la consommation, car le hook WoW s'exécute après
- si le hook d'utilisation ne fournit pas l'item, une consommation non ambiguë est détectée par différence d'inventaire
- le scan couvre aussi le sac de composants
- toutes les lignes de loot sont agrégées avant de finaliser une ouverture
- une seule ouverture est corrélée à la fois; une ouverture concurrente ambiguë est abandonnée plutôt que mélangée
- les événements `LOOT_OPENED` et `CHAT_MSG_LOOT` sont dédupliqués
- les outputs liés, équipement, armes, recettes et objets de quête sont exclus de la valeur Auction House
- la ligne de valeur est réappliquée après les rafraîchissements différés des tooltips
- `/ycv price <itemID>` affiche la valeur moyenne actuelle
- `/ycv` liste les containers connus
- affiche la valeur moyenne dans le tooltip du container
- la moyenne utilise les sources AuctionDB TSM au moment de la demande (`dbmarket`, puis sources régionales/historiques)
- les outputs sans prix TSM sont conservés mais ignorés dans la moyenne; si tous sont sans prix, la valeur reste inconnue

API publique :

- `YayaContainerValuesAPI.BeginOpening(itemID)` signale une ouverture lancée par un bouton sécurisé
- `YayaContainerValuesAPI.GetAverageValue(itemID)` retourne `valeur, ouvertures, état`
