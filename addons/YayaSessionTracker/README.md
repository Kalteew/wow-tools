# Yaya Session Tracker

Mini addon Retail pour suivre une session de jeu avec une petite frame GPH.

Ce que suit le MVP :

- une session = `login -> logout`
- nouvelle session a chaque reconnexion
- frame compacte mise a jour toutes les `15s`
- `XP/h` affiche si le perso n'est pas au niveau max
- gold net de session via `PLAYER_MONEY`
- items recuperes via `CHAT_MSG_LOOT`
- valorisation via `TSM_API.GetCustomPriceValue(...)`
- utilise aussi la moyenne de `YayaContainerValues` quand l'item est un container suivi
- exceptions : les items gris et lies quand ramasses utilisent seulement le prix vendeur
- bouton `R` sur la frame pour reset la session
- activites stockees pour :
- `Shadowlands mission table`
- `Replenish the Reservoir`
- missions Shadowlands enregistrees avec rewards snapshot
- containers de rewards de mission suivis a l'ouverture
- composants lootes dans ces containers avec snapshot gold

Ce qui est ignore :

- les items recuperes depuis la boite aux lettres
- les items `Warbound until Equipped`
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
