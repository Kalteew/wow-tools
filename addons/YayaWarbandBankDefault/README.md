# Yaya Warband Bank Default

Ouvre la banque directement sur le premier onglet de banque de bande (warband) au lieu
de l'onglet du personnage.

La selection est reappliquee a **chaque** ouverture de la banque. En revanche, si vous
changez d'onglet manuellement pendant que la fenetre est ouverte, l'addon ne force plus
rien jusqu'a la prochaine ouverture.

## Garanties

- L'addon ne s'arrete que sur un onglet de warbank **reellement achete** : il ne peut
  pas laisser affiche le panneau d'achat d'un nouvel onglet. C'est le defaut principal
  des versions <= 0.8.1, qui ne verifiaient que le *type* de banque et pas l'onglet
  selectionne, et qui atterrissaient donc sur la proposition d'achat sur les
  personnages n'ayant jamais achete d'onglet de banque perso.
- Si la banque de bande n'est pas consultable ici, ou si aucun onglet de warbank n'est
  achete, l'addon ne touche a rien et laisse le comportement Blizzard par defaut.
- Le petit bouton `+` d'achat d'onglet reste disponible, comme chez Blizzard.

## Interfaces prises en charge

- **banque Blizzard** : declencheur principal `BankFrame:SelectDefaultTab`, qui corrige
  la selection dans la meme frame que l'ouverture, donc sans clignotement de l'onglet
  du personnage ;
- **ElvUI** : hook sur `OpenBank` du module `Bags`, puis selection via le chemin natif
  d'ElvUI (`SelectBankTab`, comme son propre bouton Warband) ;
- **Ellesmere UI** et autres UI qui se contentent d'habiller la fenetre Blizzard : le
  chemin Blizzard s'applique tel quel. Si une UI tierce affiche sa propre fenetre de
  banque, l'addon lui laisse la main plutot que de desynchroniser les deux etats ;
  `/ywd probe` dit laquelle est active.

Si l'onglet de warbank n'est pas encore disponible a l'ouverture (donnees pas encore
arrivees), les tentatives sont echelonnees sur environ 4 secondes, puis l'addon attend
`BANK_TABS_CHANGED` pour retenter.

## Commandes

- `/ywd retry` : forcer une nouvelle tentative de selection ;
- `/ywd probe` : diagnostic complet (interface active, onglet cible, etat de
  `BankPanel`, onglets achetes par type, addons de banque charges, frames de banque
  visibles). C'est ce dump qu'il faut fournir pour ajouter le support d'une UI tierce ;
- `/ywd log [n|clear]` : afficher les `n` dernieres entrees du journal (30 par defaut) ;
- `/ywd debug` : basculer les messages de diagnostic dans le chat (`/ywd on`,
  `/ywd off`) ; `/ywbdebug` est un alias.

## Donnees

`YayaWarbandBankDefaultDB` conserve le drapeau de debug (donc persistant d'un `/reload`
a l'autre) et un journal circulaire borne a 200 entrees horodatees, lisible apres coup
depuis `WTF` ou via `/ywd log`.
