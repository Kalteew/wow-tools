# WCL M+ — audit sécurité et checklist QA

Audit statique du prototype local au 22/09/2026. Aucun déploiement public effectué.

## Résumé

Le worker HTTP est lié à `127.0.0.1`; la page overlay fonctionne dans un navigateur. Le companion n’est pas encore une application Overwolf exécutable. Les identifiants WCL restent côté worker et ne sont pas écrits par le code dans des journaux. Le rendu HTML utilise `textContent`, et les requêtes GraphQL utilisent `JSON.stringify` avec des variables séparées.

Les points bloquants avant diffusion sont : absence d’authentification/nonce sur l’API loopback, chemin de compatibilité amont configurable sans allowlist, absence de timeout et de rate limiting, limites incomplètes sur les tableaux/réponses/cache et absence de chiffrement du cache. La documentation distingue maintenant le fonctionnement actuel du protocole et des protections souhaités.

## Constats

| Sujet | État constaté | Risque | Priorité |
|---|---|---|---|
| Secrets WCL | Le worker lit `WCL_CLIENT_ID` et `WCL_CLIENT_SECRET`; `WCL_API_TOKEN` ne sert qu’au chemin de compatibilité. Les secrets et jetons restent en mémoire et les en-têtes ne sont pas journalisés. | Un autre processus local peut inspecter l’environnement ou la mémoire du worker. Aucun coffre OS n’est intégré. | P1 |
| Loopback | Le serveur écoute explicitement `127.0.0.1`; aucune authentification ni nonce n’est exigé. La réponse CORS par défaut accepte l’origine `null`. | Un programme local ou une page d’origine `null` peut interroger ou déclencher le worker. | P1 |
| SSRF | Le chemin WCL normal utilise les URL officielles fixes. Le chemin de compatibilité `WCL_MPLUS_ENDPOINT` accepte une URL définie dans l’environnement et l’appelle directement. | Si ce mode de compatibilité est configuré vers une cible non fiable, le worker pourrait joindre un service local ou interne. | P1 |
| JSON / DoS | Le corps entrant est limité à 1 Mo et le JSON invalide est rejeté. Aucun `Content-Type`, timeout, taille maximale de tableau ou taille de réponse/cache n’est imposé. | Épuisement mémoire/CPU, requêtes lentes et cache excessif. Le chemin de cache est sûr contre `../` grâce au nom base64url, mais pas contre un processus local qui remplacerait un fichier. | P1 |
| HTML | L’overlay construit ses nœuds avec `createElement` et `textContent`; aucun `innerHTML`/HTML fourni par WCL n’est injecté. | Risque XSS faible dans l’état actuel. À préserver lors de l’ajout de détails ou liens. | P2 |
| Lua | Aucun code Lua n’est utilisé par `wcl_mplus`; l’addon WoW n’est pas dans ce flux. | Pas de vecteur Lua identifié dans ce périmètre. | P3 |
| Données privées | Le cache conserve les résultats JSON localement; les logs/reportings du dépôt peuvent contenir des noms, rapports et métriques WCL. Le cache n’est ni chiffré ni borné par taille/LRU. | Exposition de données de personnages, rapports privés ou historiques sur un poste partagé et rétention excessive. | P1 |
| Rate limits | La concurrence du worker est limitée, mais il n’y a ni quota par fenêtre, ni `Retry-After`, ni backoff/circuit breaker, ni limite globale par endpoint. | Saturation locale et dépassement des quotas WCL. | P1 |
| Packaging | Pas de package Overwolf Electron exécutable ni de script de test global pour `wcl_mplus`; `ow-electron.json` est un descripteur interne et non le package/configuration runtime officiel. | La capture GEP et la surimpression en jeu ne sont pas installables pour un autre utilisateur à ce stade. | P1 |

## Injection et validation

- Les noms, royaumes et régions sont normalisés avant la clé de cache; la clé de fichier ne permet pas un chemin arbitraire.
- Les variables GraphQL sont envoyées comme données JSON; il n’y a pas de concaténation de valeur utilisateur dans la requête.
- `overlay.js` rend les champs utilisateur via `textContent`, ce qui neutralise les balises HTML dans l’overlay.
- `normalizeApplicant` conserve `raw` en mémoire pour l’adaptation GEP, mais `publicApplicant` l’enlève avant le POST au worker. Les tableaux et longueurs des champs restent à borner.
- La validation accepte tout tableau d’applicants et ne borne pas longueur, longueur des chaînes, profondeur JSON ou champs inconnus.

## Checklist de validation avant release

### Bloquants

- [ ] Générer un port dynamique et un fichier de session local avec permissions restrictives; exiger un nonce aléatoire sur chaque requête.
- [ ] Refuser toute origine non autorisée et vérifier `Content-Type: application/json`.
- [ ] Autoriser uniquement `https://www.warcraftlogs.com` pour l’endpoint amont; rejeter IP littérales, localhost, loopback, plages privées, redirections non autorisées et protocoles non HTTP(S).
- [ ] Ajouter timeout de connexion/réponse, taille maximale de réponse, quota par fenêtre, backoff borné sur 429/5xx et respect de `Retry-After`.
- [ ] Borner le nombre de candidats, la taille de chaque champ, la taille totale du payload et la taille/nombre d’entrées du cache.
- [ ] Ne jamais persister `raw`, token, secret client, code OAuth, URL d’autorisation complète ou réponse WCL brute.
- [ ] Chiffrer les tokens et données privées avec le coffre OS, ou documenter explicitement que le prototype n’est pas apte à stocker un compte réel.
- [ ] Définir un démarrage/arrêt de worker reproductible et faire correspondre le port annoncé au companion et à l’overlay.

### Tests automatisés à ajouter

- [ ] Requête sans nonce, origine incorrecte, méthode incorrecte et `Content-Type` incorrect : rejetés.
- [ ] Corps JSON > limite, tableau trop grand, champs très longs, JSON imbriqué et réponse amont > limite : rejetés sans croissance non bornée.
- [ ] Endpoint `localhost`, `127.0.0.1`, `::1`, RFC1918, metadata cloud, redirection vers ces hôtes et URL non HTTP(S) : rejetés.
- [ ] WCL 401/403/404/429/5xx, timeout et JSON invalide : états sûrs, sans retry illimité ni secret dans l’erreur.
- [ ] Cache : permissions 0600, corruption, expiration, eviction, symlink hostile, données privées et purge complète.
- [ ] Overlay : nom contenant HTML/Unicode/contrôle; vérifier qu’aucun HTML n’est interprété.
- [ ] GraphQL : variables contenant guillemets, retours ligne, caractères Unicode et payloads volumineux.
- [ ] Recherche automatisée de secrets dans logs, cache, bundles et artefacts de packaging.
- [ ] Test d’écoute : vérifier qu’aucun socket non-loopback n’est ouvert.

### Validation manuelle sans déploiement public

- [ ] Utiliser uniquement un compte WCL de test et des personnages/rapports non sensibles.
- [ ] Démarrer le worker sur une machine isolée, inspecter les sockets ouverts et les fichiers créés, puis purger cache/logs.
- [ ] Simuler un companion compromis et confirmer qu’il ne peut pas appeler WCL directement ni obtenir un token.
- [ ] Vérifier qu’un redémarrage, un port occupé, WCL indisponible et un worker arrêté laissent l’overlay dans un état lisible et sans données périmées présentées comme fraîches.
- [ ] Vérifier le contenu final du paquet : pas de `.env`, token, secret, cache, logs privés ni rapports WCL.

## Décision QA

**Non validé pour distribution ou compte WCL réel.** Le prototype est acceptable pour des tests locaux fictifs après ajout des contrôles loopback/SSRF/limites/rate limits ci-dessus. Aucun déploiement public ne doit être réalisé sur la base de l’état actuel.
