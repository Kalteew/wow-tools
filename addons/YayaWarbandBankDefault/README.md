# Yaya Warband Bank Default

Ouvre la banque directement sur l'onglet de banque de bande (warband) au lieu de
l'onglet du personnage.

La selection ne s'applique qu'a la premiere ouverture de la banque apres la
connexion : les changements d'onglet faits manuellement ensuite sont respectes.

Interfaces prises en charge :

- la banque Blizzard par defaut ;
- la banque d'ElvUI, via un hook sur son module `Bags` lorsque l'addon est
  present.

Si l'onglet de banque de bande n'est pas encore disponible au moment de
l'ouverture (donnees pas encore chargees), la selection est reprogrammee puis
abandonnee proprement au bout de quelques tentatives.

Commandes :

- `/ywd retry` : forcer une nouvelle tentative de selection ;
- `/ywd debug` : basculer les messages de diagnostic (`/ywd on`, `/ywd off`) ;
  `/ywbdebug` est un alias.

L'addon ne conserve aucun reglage : il n'a pas de `SavedVariables`. Le mode
debug est desactive a chaque rechargement.
