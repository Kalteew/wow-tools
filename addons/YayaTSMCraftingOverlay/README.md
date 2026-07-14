# Yaya TSM Crafting Overlay

Petit addon Retail qui ajoute un overlay sur la vue crafting TSM.

Comportement :

- s'attache a la fenetre TSM Crafting
- affiche le statut `First craft`
- affiche l'etat de concentration dispo / requise
- permet un mode `Only first`
- permet d'ajouter la recette courante a la queue TSM avec ou sans concentration

Limites :

- `Only first` agit sur le bouton de l'overlay, pas encore sur la liste TSM
- ne remplace pas encore les boutons natifs TSM
- depend de `C_TradeSkillUI.GetSelectedRecipeID()` pour suivre la recette courante
