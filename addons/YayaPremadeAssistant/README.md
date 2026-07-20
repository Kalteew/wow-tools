# Yaya Premade Assistant

Assistant Retail pour les groupes premades.

Par defaut, il :

- invite automatiquement les candidatures solo via leur nom
- accepte automatiquement les invitations des groupes auxquels tu as postule
- n'accepte jamais les invitations de groupe classiques inconnues
- propose un bouton pour les candidatures de plusieurs joueurs et la conversion raid
- propose aussi un bouton de secours si l'auto-accept echoue

Commandes :

- `/ypa` : affiche ou masque la fenetre
- `/ypa status`
- `/ypa on` ou `/ypa off`
- `/ypa leader on|off` : auto-invitation
- `/ypa accept on|off` : auto-acceptation
- `/ypa now` : traite immediatement
- `/ypa debug` : active ou desactive les logs

Blizzard bloque l'auto-invitation native des candidatures groupees. L'automatisation ne fonctionne que hors combat et respecte les limites de taille de l'activite.
