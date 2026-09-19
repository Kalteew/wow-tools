# Historique Warcraft Logs

- `requests.jsonl` contient un enregistrement par appel au MCP Warcraft Logs.
- `reports/<code>.json` contient la fiche réutilisable d'un report : fight, joueurs, métriques, morts, ressenti et conclusions.
- Les réponses sont résumées et bornées ; aucun secret ou jeton n'est stocké.
- Une requête identique doit être relue depuis cet historique. Un rafraîchissement n'est fait que sur demande explicite.
- Le focus par défaut est Kalteew. Azaelle est ajouté lorsqu'il apparaît dans la clé.
