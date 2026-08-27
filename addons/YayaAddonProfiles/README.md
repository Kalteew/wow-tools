# Yaya Addon Profiles

Relie un personnage a un profil manuel de Simple Addon Manager. A chaque connexion, le profil et ses dependances sont compares aux addons actives ; tout ecart est corrige et sauvegarde immediatement. Le reload propose ensuite est facultatif : sans reload, le profil sera actif a la prochaine connexion.

Les dependances dures declarees par les addons desires sont fermees transitivement avant toute comparaison. Sans cela, YAP desactivait un addon dont il dependait lui-meme : au login suivant il devenait `DEP_DISABLED`, ne chargeait plus, n'appliquait aucun profil, ne proposait aucun reload et ne pouvait plus se reparer. C'est ce qui a desactive `YayaCore`, puis toute la suite Yaya, sur un personnage.

`SimpleAddonManager`, YAP lui-meme et `!YayaErrorLog` sont toujours ajoutes au profil desire. Un profil qui desactive le gestionnaire ou l'applicateur se prive du moyen de se corriger ; un profil qui desactive le journal d'erreurs rend tout diagnostic impossible, alors que c'est justement lui qui capture les fautes des autres addons.

Les bases RaiderIO des regions etrangeres sont ignorees pendant la comparaison, car RaiderIO les desactive automatiquement au chargement.

Les addons que le client reactive de lui-meme (`BigWigs_*`, `LittleWigs*`, `M33kAurasArchive`, `Simulationcraft`) sont alignes sur leur etat courant quand ils ne figurent pas dans le profil, au lieu d'etre corriges a chaque connexion : ils produisaient un ecart presque systematique, donc un prompt de reload permanent qui noyait les vrais changements. S'ils sont explicitement dans le profil, le profil garde la main.

Si les emplacements de popup sont tous occupes au login, la confirmation de reload ne peut pas s'afficher : YAP le detecte via le retour de `StaticPopup_Show` et retombe sur un message dans le chat, au lieu de considerer la confirmation comme affichee. Une demande restee en suspens est signalee dans les traces a la session suivante.

`/yap` ouvre la fenetre : choisir un profil a gauche, cocher plusieurs personnages a droite, puis les attribuer en une action, meme hors ligne. **Tout**, **Sans profil** et **Aucun** evitent les clics repetitifs ; un `Maj`-clic coche aussi une plage de personnages. L'addon active aussi son propre chargement et Simple Addon Manager pour chaque personnage cible.

Commandes :

- `/yap profile <ProfilSAM>` : attribue le profil au personnage connecte.
- `/yap set <Perso-Royaume> <ProfilSAM>` : attribution hors ligne.
- `/yap status` : attribution du personnage connecte.

`/yap debug [on|off]` affiche le dernier diagnostic persistant et active/desactive les traces detaillees.

Les attributions sont stockees dans `YayaAddonProfilesDB.assignments`. Les definitions et heritages restent la source de verite de `SimpleAddonManagerDB`.
