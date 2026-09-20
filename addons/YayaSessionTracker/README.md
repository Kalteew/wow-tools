# Yaya Session Tracker

Mini addon Retail pour suivre une session de jeu avec une petite frame GPH.

Ce que suit le MVP :

- une session = `login -> logout`
- nouvelle session a chaque reconnexion
- frame compacte mise a jour toutes les `15s`
- `XP/h` ou `Niveaux/h` s'affiche selon la vue active, jamais les deux dans le dashboard
- sessions XP dediees : elles commencent au premier gain d'XP reel, ferment apres
  3 minutes sans gain, se decoupent lors d'un changement de specialisation et
  s'arretent au niveau 80 dans le mode `Niveaux 1-80` (aucun recours a `/played`) ;
  le mode `Niveaux 80-90` utilise un historique XP separe
- historique XP avec classe, specialisation, role, zone, niveau de depart/fin,
  tranche de niveau 10 par defaut, XP gagnee, temps actif, XP/h, nombre de gains et plus
  gros gain
- repartition XP par source (`Quêtes`, `Combats`, `Donjons`, `Autre / inconnue`) avec XP/h
  et Niveaux/h ; les anciennes sessions sont conservees dans `Autre / inconnue`
- statistiques cumulees par classe, specialisation, zone, tranche de niveau et couple
  zone/tranche ; `/yst xp` les affiche dans le chat
- `Coin/h` affiche les gains de Corrosive Coin (ID devise `3448`) si la session en contient
- gold net de session via `PLAYER_MONEY`
- items recuperes via `CHAT_MSG_LOOT`
- Corrosive Coin recupere via `CURRENCY_DISPLAY_UPDATE`
- valorisation via `TSM_API.GetCustomPriceValue(...)` avec `first(dbregionsaleavg, dbmarket, dbregionmarketavg, vendorsell)` : le prix moyen de vente region passe en premier, les anciennes sources enregistrees dans les settings sont migrees au chargement
- utilise aussi la moyenne de `YayaContainerValues` quand l'item est un container suivi
- les items gris sont valorises au prix vendeur
- bouton `R` dans le bandeau `Session` pour reinitialiser la session
- bouton `Stats` dans le bandeau `Session` pour ouvrir le dashboard KPI XP
- dashboard KPI avec filtres chaines Classe -> Spe -> Zone -> Niveau, graphiques recalcules,
  barres par classe/spe, zones, tranches de niveau et tendance des sessions
- graphique KPI dedie aux sources XP, disponible en XP/h ou Niveaux/h
- lignes de classe et de specialisation colorees selon la classe WoW ; l'agregat de classe
  indique le nombre de spes couvertes et disparait quand une seule spe le rend redondant
- boutons persistants du dashboard : jeu de donnees `Niveaux 1-80` ou `Niveaux 80-90`, XP/h ou Niveaux/h, et tranches de 5, 10 ou 20 niveaux
- zones XP regroupées par zone de carte, pas par sous-zone ; les anciennes salles connues sont fusionnées
- `/yst stats` ouvre ou ferme aussi le dashboard ; `/yst xp` conserve le resume texte
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
- `YayaSessionTrackerDB.xpSessions`
- `YayaSessionTrackerDB.xpSessions80to90`
- `YayaSessionTrackerDB.activeXPSession` et `YayaSessionTrackerDB.activeXPSession80to90`
- `YayaSessionTrackerDB.nextXPSessionID`
- `YayaSessionTrackerDB.knownCharacters`
- `YayaSessionTrackerDB.activities`
- `YayaSessionTrackerDB.shadowlandsMissionHistory`
- `YayaSessionTrackerDB.shadowlandsMissionContainerHistory`
- `YayaSessionTrackerDB.pendingMissionContainers`

Commande :

- `/yst reset` pour remettre la frame a sa position par defaut

## Integration YayaFrame

La section Session est affichee dans la frame partagee `YayaFrame`, qui gere la position commune et le deplacement.
