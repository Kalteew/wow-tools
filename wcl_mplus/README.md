# WCL M+ local

Prototype local pour consulter Warcraft Logs Mythic+ pendant la préparation d’un groupe.

## État actuel

- Le worker local, le client OAuth/GraphQL WCL, le cache et la page overlay de démonstration sont présents.
- La page peut être ouverte dans un navigateur et affiche le dernier snapshot du worker.
- Le companion contient les fonctions de parsing et d’écoute GEP, mais il n’est pas encore empaqueté comme une vraie application Overwolf et n’est pas lancé automatiquement.
- L’addon WoW est facultatif et ne reçoit pas les données WCL.

Le guide [INSTALL.md](../docs/wcl-mplus/INSTALL.md) décrit l’installation locale de démonstration sur un autre PC et les limites à connaître.

## Installation

Suivre le [guide d’installation locale](../docs/wcl-mplus/INSTALL.md), qui demande les identifiants WCL de chaque utilisateur à l’invite masquée. Le worker écoute uniquement `127.0.0.1:28777`. Le cache est conservé localement dans `cache/data/`.

Pour le schéma des échanges : [PROTOCOL.md](../docs/wcl-mplus/PROTOCOL.md). Pour la sécurité du prototype : [SECURITY-QA.md](../docs/wcl-mplus/SECURITY-QA.md).
