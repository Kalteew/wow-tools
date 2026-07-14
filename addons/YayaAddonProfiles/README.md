# Yaya Addon Profiles

Mini addon Retail pour gerer 2 profils d'addons par personnage.

Profils :

- `Jouer`
- `Gold`

Workflow :

- active les addons voulus pour un profil
- `/yap capture play` ou `/yap capture gold`
- ouvre `/yap`
- assigne `Jouer` ou `Gold` a chaque personnage connu

Commandes :

- `/yap` ouvre l'interface
- `/yap play` assigne et applique `Jouer` au perso courant
- `/yap gold` assigne et applique `Gold` au perso courant
- `/yap capture play|gold` capture les addons coches actuellement
- `/yap set Perso-Royaume play|gold` assigne un profil a un perso
- `/yap apply` applique le profil assigne au perso courant
- `/yap auto on|off` active/desactive l'application auto a la connexion

Note :

- l'addon force toujours `YayaAddonProfiles` actif dans les profils
- un changement d'addons demande un `/reload`
- pour charger peu d'addons des le login, utiliser aussi `scripts/wow-addon-profiles.ps1` hors jeu
- l'application auto in-game est desactivee par defaut; `AddOns.txt` reste la source principale
