# YayaWCLMPlus

Addon Retail expérimental. Il ne fait pas partie du flux WCL M+ installé aujourd’hui.

- aucune requête réseau ;
- aucune écriture dans l'UI Blizzard protégée ;
- indicateur discret, masqué tant qu'aucun état n'est fourni ;
- debug désactivé par défaut (`/wclm debug` pour basculer).

L'addon ne calcule, ne récupère et n'affiche aucun parse. Il n'a pas de canal de
communication à chaud avec le worker local. Modifier des SavedVariables depuis un
autre programme ne mettrait pas à jour son état en jeu sans recharger l'interface.

Pour afficher les candidatures pendant que WoW tourne, la voie prévue est une
surimpression Overwolf ; voir `docs/wcl-mplus/INSTALL.md`. Ce dossier n'est pas requis
pour essayer le worker et la page de démonstration.
