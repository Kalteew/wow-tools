# Yaya Warband Bank Default

Ouvre la banque directement sur le premier onglet de banque de bande (warband) quand
l'interface peut le faire sans contaminer l'etat Blizzard.

ElvUI reapplique la selection a **chaque** ouverture. Avec l'interface Blizzard, l'addon
ne force aucun onglet : il privilegie le depot fiable depuis les sacs.

## Garanties

- ElvUI ne selectionne qu'un onglet de warbank **reellement achete** : il ne peut pas
  laisser affiche le panneau d'achat d'un nouvel onglet.
- Si la banque de bande n'est pas consultable ici, ou si aucun onglet de warbank n'est
  achete, l'addon ne touche a rien et laisse le comportement Blizzard par defaut.
- Le petit bouton `+` d'achat d'onglet reste disponible, comme chez Blizzard.

## Interfaces prises en charge

- **banque Blizzard** : aucune ecriture ni manipulation de `BankPanel`. Blizzard garde
  son ouverture native ; cela preserve le clic droit des sacs. Si l'onglet personnel
  s'ouvre, cliquez une fois sur l'onglet Warband ;
- **ElvUI** : hook sur `OpenBank` du module `Bags`, puis selection via le chemin natif
  d'ElvUI (`SelectBankTab`, comme son propre bouton Warband) ;
- **Ellesmere UI** et autres UI qui se contentent d'habiller la fenetre Blizzard : le
  chemin Blizzard natif s'applique. Si une UI tierce affiche sa propre fenetre de
  banque, l'addon lui laisse la main plutot que de desynchroniser les deux etats ;
  `/ywd probe` dit laquelle est active.

ElvUI reste selectionne automatiquement via son propre chemin natif. La banque Blizzard
n'est jamais forcee par l'addon : appeler `SetTab` ou `SelectTab` depuis un addon rend
`BankPanel.bankType` taint et bloque `C_Container.UseContainerItem` au clic droit.

## Commandes

- `/ywd retry` : forcer une nouvelle tentative sur une UI geree (notamment ElvUI) ;
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
