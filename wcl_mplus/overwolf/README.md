# WCL M+ — package Overwolf de développement

Ce dossier est le premier package Overwolf testable avec le client développeur. Il écoute `game_info/group_applicants`, transmet les candidatures au worker local et affiche le dernier résultat dans l’overlay.

## Lancement

1. Charger ce dossier comme application de développement dans Overwolf.
2. Démarrer le worker depuis `wcl_mplus/worker` avec les identifiants WCL.
3. Lancer WoW Retail et ouvrir la recherche de groupe.

Le package ne contient aucun secret WCL. L’overlay reste utilisable sans `/reload` ; le worker doit rester lancé sur le même PC.
