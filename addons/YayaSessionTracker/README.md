# Yaya Session Tracker

Mini addon Retail pour suivre une session de jeu avec une petite frame GPH.

Ce que suit le MVP :

- une session = `login -> logout`
- nouvelle session a chaque reconnexion
- frame compacte mise a jour toutes les `15s`
- `XP/h` affiche si le perso n'est pas au niveau max
- `Coin/h` affiche les gains de Corrosive Coin (ID devise `3448`) si la session en contient
- gold net de session via `PLAYER_MONEY`
- items recuperes via `CHAT_MSG_LOOT`
- Corrosive Coin recupere via `CURRENCY_DISPLAY_UPDATE`
- valorisation via `TSM_API.GetCustomPriceValue(...)` avec `first(dbregionsaleavg, dbmarket, dbregionmarketavg, vendorsell)` : le prix moyen de vente region passe en premier, les anciennes sources enregistrees dans les settings sont migrees au chargement
- utilise aussi la moyenne de `YayaContainerValues` quand l'item est un container suivi
- les items gris sont valorises au prix vendeur
- bouton `R` dans le bandeau `Session` pour reinitialiser la session
- valeurs alignees a droite dans leur propre colonne, ligne `Total` (or + loot), et les cinq meilleurs objets de la session dans l'infobulle de la ligne `Loot`
- activites stockees pour :
- `Shadowlands mission table`
- `Replenish the Reservoir`
- missions Shadowlands enregistrees avec rewards snapshot
- containers de rewards de mission suivis a l'ouverture
- composants lootes dans ces containers avec snapshot gold

Ce qui est ignore :

- les items recuperes depuis la boite aux lettres
- les items `Warbound until Equipped`
- les items `Soulbound` / lies quand ramasses
- les transferts de gold entre tes propres persos
- les frais de courrier lies a ces transferts internes

SavedVariables :

- `YayaSessionTrackerDB.sessions`
- `YayaSessionTrackerDB.knownCharacters`
- `YayaSessionTrackerDB.activities`
- `YayaSessionTrackerDB.shadowlandsMissionHistory`
- `YayaSessionTrackerDB.shadowlandsMissionContainerHistory`
- `YayaSessionTrackerDB.pendingMissionContainers`

Commande :

- `/yst reset` pour remettre la frame a sa position par defaut

## Integration YayaFrame

La section Session est affichee dans la frame partagee `YayaFrame`, qui gere la position commune et le deplacement.
