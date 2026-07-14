# Yaya TSM Live Min Buyout

Petit addon Retail qui remplace `DBMinBuyout` de TSM en session quand tu fais une recherche a l'HV.

Comportement :

- hook `SendSearchQuery` et `SendSellSearchQuery`
- lit les resultats `ITEM_SEARCH_RESULTS_UPDATED` et `COMMODITY_SEARCH_RESULTS_UPDATED`
- calcule le plus bas buyout unitaire vu pour l'item recherche
- remplace `DBMinBuyout` de TSM en memoire pour la session
- fallback automatique sur la valeur normale TSM si aucun prix live n'a ete vu

Limites :

- pas de persistance
- pas de sync globale
- ne touche pas a `TradeSkillMaster_AppHelper`
- depend de l'API interne exposee indirectement par TSM, donc a revalider si TSM change fortement
