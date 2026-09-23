# Contrat local WCL Mythique+

Spécification cible, version `1.0`. Transport prévu : HTTP JSON pour les commandes, WebSocket ou SSE pour les événements. Encodage UTF-8. Toutes les dates sont ISO-8601 UTC. Le worker actuel n’implémente qu’une partie de ces routes ; voir `ARCHITECTURE.md` pour l’état réel.

## Règles communes

- `protocolVersion` est obligatoire sur chaque message.
- `requestId` est un UUID généré par l’émetteur; il sert à corréler requête, réponse et erreur.
- Les champs inconnus doivent être ignorés pour permettre l’évolution additive.
- Les noms de royaume sont normalisés en slug; les noms de personnage conservent leur casse d’affichage mais la comparaison est insensible à la casse.
- Une réponse peut être `stale`; l’interface doit alors afficher la date `fetchedAt`.

## Handshake

`GET /v1/session`

```json
{
  "protocolVersion": "1.0",
  "sessionId": "2c2c8d2e-0c8d-4ea5-89f4-c75bb1b0b2ae",
  "workerVersion": "0.1.0",
  "capabilities": ["applicants", "mplusSummary", "stream"],
  "expiresAt": "2026-09-22T18:00:00Z"
}
```

Le header `X-Session-Nonce` ou un équivalent de session est requis pour les appels suivants. Une incompatibilité majeure retourne `PROTOCOL_UNSUPPORTED`.

## Événement GEP → companion

```json
{
  "protocolVersion": "1.0",
  "eventId": "gep-8f4c",
  "eventType": "group_applicants",
  "sequence": 1842,
  "observedAt": "2026-09-22T16:42:01Z",
  "groupId": "local-group-17",
  "applicants": [
    {
      "applicantId": "ow-123",
      "name": "Kalteew",
      "realm": "Hyjal",
      "region": "eu",
      "classId": 1,
      "role": "TANK",
      "source": "overwolf"
    }
  ]
}
```

Le snapshot remplace l’état connu du groupe. Un événement identique est sans effet. Si `sequence` recule, il est accepté uniquement si `eventId` est nouveau et marqué `outOfOrder: true`; le worker ne doit jamais supprimer un état plus récent.

## Companion → worker

`POST /v1/applicants/snapshot`

```json
{
  "protocolVersion": "1.0",
  "requestId": "f2e5d3d4-a08d-4c07-a37d-86b81cc94b0e",
  "groupId": "local-group-17",
  "mode": "snapshot",
  "applicants": [
    {
      "applicantId": "ow-123",
      "name": "Kalteew",
      "realmSlug": "hyjal",
      "region": "eu",
      "role": "TANK"
    }
  ]
}
```

Réponse synchrone : `200 OK` avec l’état courant du snapshot. Le companion envoie la liste courante du groupe, mais ajoute `newApplicants` pour identifier les entrées réellement nouvelles. Le cache local évite de relancer WCL pour les identités déjà fraîches.

`GET /v1/applicants/latest` renvoie le dernier snapshot consommable par l’overlay. Au démarrage, il renvoie `status=idle` et une liste vide.

## Worker → overlay

```json
{
  "protocolVersion": "1.0",
  "messageType": "applicant_update",
  "requestId": "f2e5d3d4-a08d-4c07-a37d-86b81cc94b0e",
  "groupId": "local-group-17",
  "status": "ready",
  "updatedAt": "2026-09-22T16:42:08Z",
  "applicants": [
    {
      "applicantId": "ow-123",
      "character": {"name": "Kalteew", "realm": "Hyjal", "region": "eu"},
      "resolution": "resolved",
      "mplus": {
        "score": 2450,
        "recentRuns": 12,
        "bestKeyLevel": 18,
        "lastRunAt": "2026-09-21T20:12:00Z"
      },
      "dataState": "fresh",
      "fetchedAt": "2026-09-22T16:42:07Z",
      "expiresAt": "2026-09-22T16:57:07Z"
    }
  ]
}
```

Le champ `mplus` peut être `null` lorsque `resolution` vaut `not_found`, `private` ou `unavailable`. L’overlay ne déduit jamais une valeur manquante.

## Statuts

État global : `idle`, `queued`, `loading`, `ready`, `partial`, `stale`, `error`, `offline`.

Résolution : `unresolved`, `resolved`, `ambiguous`, `not_found`, `private`.

État de donnée : `fresh`, `stale`, `missing`, `forbidden`, `unavailable`.

Une erreur partielle ne doit pas masquer les candidats déjà résolus. Les erreurs utilisent :

```json
{
  "protocolVersion": "1.0",
  "messageType": "error",
  "requestId": "f2e5d3d4-a08d-4c07-a37d-86b81cc94b0e",
  "code": "WCL_RATE_LIMITED",
  "retryable": true,
  "retryAfterSeconds": 30,
  "message": "Données temporairement indisponibles"
}
```

Codes minimaux : `INVALID_JSON`, `PROTOCOL_UNSUPPORTED`, `UNAUTHORIZED_LOCAL_SESSION`, `WCL_AUTH_REQUIRED`, `WCL_RATE_LIMITED`, `WCL_FORBIDDEN`, `WCL_NOT_FOUND`, `WCL_UPSTREAM_ERROR`, `CACHE_CORRUPT`, `QUEUE_FULL`.

## Déduplication et TTL

- `eventId` déduplique les événements GEP pendant au moins 24 h.
- `requestId` déduplique une commande pendant 10 min; une répétition retourne le même résultat connu.
- `canonicalCharacterKey = lower(region) + ":" + lower(realmSlug) + ":" + Unicode-NFC(lower(name))`.
- Une résolution de personnage est conservée 24 h.
- Un résumé M+ est frais 15 min; après expiration il peut être servi en `stale` pendant 5 min le temps du refresh.
- Une erreur négative est mise en cache 60 s pour éviter les boucles.
- Les jobs identiques fusionnent; le plus récent `observedAt` gagne.

## OAuth et confidentialité

OAuth ne transite jamais par le protocole overlay. Le worker expose seulement `GET /v1/auth/status`, `POST /v1/auth/start` et `POST /v1/auth/logout`, sans retourner de token. Les tokens sont conservés dans le coffre-fort OS; le flux de callback est à usage unique et expire rapidement.

Les payloads excluent notes, messages, identifiants Overwolf non nécessaires et réponses GraphQL brutes. Les logs ne doivent contenir que `requestId`, code d’erreur, durée et compteurs. Les champs personnels sont effacés lors du logout ou d’une demande “vider les données”.

## Matrice de tests du contrat

| Cas | Résultat attendu |
|---|---|
| Deux snapshots identiques | Un seul job, aucune duplication dans l’overlay |
| Candidats A/B puis B/C | A retiré, B conservé, C ajouté |
| WCL 429 | `partial` ou cache `stale`, retry différé |
| Personnage privé | `resolution=private`, pas de boucle de retry |
| Token expiré | `WCL_AUTH_REQUIRED`, aucune fuite de token |
| Worker arrêté | `offline`, overlay encore navigable |
| Payload > limite | `INVALID_JSON` ou `QUEUE_FULL`, connexion conservée |
| Événement hors ordre | État récent conservé, métrique de diagnostic incrémentée |
| Cache expiré | Valeur éventuellement affichée avec `stale=true`, refresh lancé |
