# Yaya TSM Mailing Fix

Correctif Retail ciblé, validé sur TSM 4.14.71, pour l'envoi des groupes :

- vérifie le verrou réel des emplacements de sac au lieu du cache TSM ;
- rafraîchit l'inventaire TSM juste avant un envoi de groupes.

Cela vise à éviter les objets laissés en sac jusqu'à leur déplacement manuel. Le
correctif dépend des modules internes de TSM et devra être revérifié après une
évolution majeure de l'addon.
