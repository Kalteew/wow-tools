# Yaya Companion Targeter

Mini addon Retail pour les items d'XP de compagnons Shadowlands.

Ce qu'il fait :

- detecte les items de type `188655`, `188656`, `188657` et `186472`
- cible automatiquement le companion eligibile au plus bas niveau
- annule le ciblage s'il n'y a personne d'eligibile
- bypass manuel avec `Alt` maintenu

Modes :

- `all` : prend le companion eligibile le plus bas niveau
- `tracked` : prend le plus bas niveau parmi une shortlist definie a l'avance

Commandes :

- `/yct` ou `/yct status`
- `/yct on`
- `/yct off`
- `/yct all`
- `/yct tracked`
- `/yct verbose` pour activer/desactiver les logs
- `/yct track` pour ajouter/retirer le companion actuellement ouvert dans `Companions`
- `/yct list`
- `/yct clear`

Exemple simple :

1. Ouvre la table de mission Shadowlands.
2. Ouvre un companion.
3. `/yct track`
4. Repete pour 2-3 companions si tu veux une shortlist.
5. `/yct tracked`
6. Clique tes items d'XP, l'addon prendra automatiquement le plus bas niveau de la shortlist.
