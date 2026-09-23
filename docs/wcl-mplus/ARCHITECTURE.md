# Architecture et état du prototype

## Présent dans le dépôt

- `wcl_mplus/api/` : OAuth client credentials en mémoire, client GraphQL public, résolution de personnage et normalisation des métriques disponibles.
- `wcl_mplus/cache/` : cache JSON local par personnage avec TTL.
- `wcl_mplus/worker/` : serveur HTTP sur `127.0.0.1:28777`, endpoint de santé, réception de snapshots, déduplication et résolution WCL.
- `wcl_mplus/companion/app.js` : fonctions réutilisables pour parser et normaliser les données GEP `group_applicants`. Elles ne sont pas démarrées par une vraie application Overwolf.
- `wcl_mplus/overlay/` : page de démonstration autonome qui lit le dernier snapshot du worker et contient un simulateur.
- `addons/YayaWCLMPlus/` : addon facultatif, sans requête réseau ni connexion au worker.

Le guide [INSTALL.md](INSTALL.md) décrit ce qu’un autre utilisateur peut lancer aujourd’hui. Le protocole de `PROTOCOL.md` est une spécification plus large ; tous ses endpoints et états ne sont pas encore implémentés.

## Flux visé après intégration Overwolf

```text
Overwolf GEP / group_applicants
        │ écoute des mises à jour par le companion
        ▼
Worker local 127.0.0.1:28777 ─── OAuth/GraphQL ─── Warcraft Logs
        │ dernier snapshot par HTTP
        ▼
Surimpression Overwolf au-dessus de WoW
```

Overwolf documente bien `game_info/group_applicants` pour WoW Retail. Le dépôt ne contient pas encore le package Electron, l’initialisation GEP ou le démarrage automatique du companion : aucune candidature réelle ne suit actuellement tout ce flux.

## Affichage à chaud dans WoW

L’addon WoW n’a pas accès au socket HTTP local, au système de fichiers arbitraire ou au réseau web du PC. Les SavedVariables sont relues au chargement de l’addon ; une écriture externe ne modifie pas les tables Lua en mémoire. Une frame addon qui affiche le résultat exigerait donc un canal WoW autorisé ou un rechargement, qui n’existe pas dans ce prototype.

La voie prévue est une fenêtre Overwolf configurée comme overlay de jeu. Elle peut afficher des mises à jour reçues du worker sans `/reload`. Ce rendu reste à empaqueter et valider en jeu.

## Stockage et sécurité actuels

- Le worker utilise `WCL_CLIENT_ID` et `WCL_CLIENT_SECRET` depuis son environnement et garde le jeton d’accès en mémoire.
- Le cache JSON est local et non chiffré, sous `wcl_mplus/cache/data/`.
- Le serveur écoute sur `127.0.0.1`, mais ne demande pas encore de nonce ou d’authentification locale.
- Le rendu affiche le texte avec `textContent`; les clés WCL ne sont pas envoyées à la page overlay.
- Les résultats WCL ne sont pas encore bornés par la politique de rétention cible.

Ce prototype est prévu pour un seul PC de confiance. Il n’est pas prêt à être distribué comme application complète. Voir [SECURITY-QA.md](SECURITY-QA.md) avant toute distribution.

## Étapes restantes

1. Créer le projet Overwolf Electron avec les packages GEP et Overlay officiels, une fenêtre de fond et l’initialisation de `game_info`.
2. Relier l’événement `group_applicants` au worker et la page overlay au dernier snapshot.
3. Valider l’apparition, la disparition et le changement d’état des candidats en WoW réel, sans `/reload`.
4. Ajouter nonce loopback, limites de requêtes, allowlist WCL, expiration/purge du cache et instructions de création des identifiants utilisateur avant diffusion.
