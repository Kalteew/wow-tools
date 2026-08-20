# Yaya Addon Profiles

Relie un personnage a un profil manuel de Simple Addon Manager. A chaque connexion, le profil et ses dependances sont compares aux addons actives ; tout ecart est corrige puis l'UI est rechargee.

`/yap` ouvre la fenetre : choisir un profil a gauche, cocher plusieurs personnages a droite, puis les attribuer en une action, meme hors ligne. **Tout**, **Sans profil** et **Aucun** evitent les clics repetitifs ; un `Maj`-clic coche aussi une plage de personnages. L'addon active aussi son propre chargement et Simple Addon Manager pour chaque personnage cible.

Commandes :

- `/yap profile <ProfilSAM>` : attribue le profil au personnage connecte.
- `/yap set <Perso-Royaume> <ProfilSAM>` : attribution hors ligne.
- `/yap status` : attribution du personnage connecte.

Les attributions sont stockees dans `YayaAddonProfilesDB.assignments`. Les definitions et heritages restent la source de verite de `SimpleAddonManagerDB`.
