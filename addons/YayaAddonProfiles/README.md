# Yaya Addon Profiles

Relie un personnage a un profil manuel de Simple Addon Manager. A chaque connexion, le profil et ses dependances sont compares aux addons actives ; tout ecart est corrige et sauvegarde immediatement. Par defaut aucune fenetre ne s'ouvre : la correction est ecrite et prend effet a la prochaine connexion. La case **Proposer le reload apres application**, ou `/yap reload on`, retablit la confirmation de reload immediat.

Les dependances dures declarees par les addons desires sont fermees transitivement avant toute comparaison. Sans cela, YAP desactivait un addon dont il dependait lui-meme : au login suivant il devenait `DEP_DISABLED`, ne chargeait plus, n'appliquait aucun profil, ne proposait aucun reload et ne pouvait plus se reparer. C'est ce qui a desactive `YayaCore`, puis toute la suite Yaya, sur un personnage.

`SimpleAddonManager`, YAP lui-meme et `!YayaErrorLog` sont toujours ajoutes au profil desire. Un profil qui desactive le gestionnaire ou l'applicateur se prive du moyen de se corriger ; un profil qui desactive le journal d'erreurs rend tout diagnostic impossible, alors que c'est justement lui qui capture les fautes des autres addons.

Les bases RaiderIO des regions etrangeres sont ignorees pendant la comparaison, car RaiderIO les desactive automatiquement au chargement.

Les addons que le client reactive de lui-meme (`BigWigs_*`, `LittleWigs*`, `M33kAurasArchive`, `Simulationcraft`) sont alignes sur leur etat courant quand ils ne figurent pas dans le profil, au lieu d'etre corriges a chaque connexion : ils produisaient un ecart presque systematique, donc un prompt de reload permanent qui noyait les vrais changements. S'ils sont explicitement dans le profil, le profil garde la main.

En mode confirmation, si les emplacements de popup sont tous occupes au login, la fenetre ne peut pas s'afficher : YAP le detecte via le retour de `StaticPopup_Show` et retombe sur un message dans le chat, au lieu de considerer la confirmation comme affichee. Une demande restee en suspens est signalee dans les traces a la session suivante, dans les deux modes.

## La fenetre

`/yap` ouvre la fenetre : choisir un profil a gauche, cocher plusieurs personnages a droite, puis les attribuer en une action, meme hors ligne. **Tout**, **Sans profil** et **Aucun** evitent les clics repetitifs ; un `Maj`-clic coche aussi une plage de personnages. L'addon active aussi son propre chargement et Simple Addon Manager pour chaque personnage cible.

Les deux colonnes defilent, ce qui leve la limite d'une quinzaine de profils au-dela de laquelle les boutons debordaient de la fenetre. Le profil choisi se lit a sa surbrillance, plus au fait que son bouton soit grise. La fenetre se deplace par son bandeau, retient sa position d'une session a l'autre, et le bouton `R` la ramene au centre si elle finit hors de l'ecran.

Les en-tetes **Nom**, **Niv.** et **Profil** trient la liste ; un second clic sur la colonne active inverse le sens, marque par un suffixe `^` ou `v`. Le choix est conserve au niveau du compte. Un niveau inconnu et un personnage sans profil sont toujours relegues en fin de liste, quel que soit le sens : c'est une absence de donnee, pas une valeur basse.

Le **niveau** est releve a la connexion du personnage et a chaque montee de niveau. Simple Addon Manager ne stocke pas cette information et il n'existe aucune API pour lire les autres personnages du compte : un personnage affiche `-` tant qu'il ne s'est pas connecte au moins une fois depuis l'installation de cette version. L'infobulle d'une ligne donne le profil, le niveau et la date de derniere connexion.

## Commandes

- `/yap profile <ProfilSAM>` : attribue le profil au personnage connecte.
- `/yap set <Perso-Royaume> <ProfilSAM>` : attribution hors ligne.
- `/yap status` : attribution du personnage connecte.
- `/yap reload [on|off]` : proposer un reload immediat, ou se contenter de sauvegarder pour la prochaine connexion.
- `/yap debug [on|off]` : affiche le dernier diagnostic persistant et active/desactive les traces detaillees.

## Donnees

Les attributions sont stockees dans `YayaAddonProfilesDB.assignments`, les personnages connus dans `.characters` (classe, couleur, GUID, niveau, derniere connexion). Les definitions et heritages de profils restent la source de verite de `SimpleAddonManagerDB`.

Le meme personnage pouvait figurer sous deux identifiants, selon que le royaume gardait ses espaces ou non : `GetRealmName` les conserve, alors que les cles de royaume de Simple Addon Manager varient. Les entrees partageant un GUID sont desormais fusionnees a chaque connexion sur la forme avec espaces, celle que le jeu regenere ; le niveau le plus haut, la derniere connexion la plus recente et l'assignation existante sont conserves. Le schema est marque `version = 4`.

Les preferences de compte sont `promptReload`, `sortKey`, `sortDesc`, `framePoint` et `debug`.
