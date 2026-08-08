# YayaCraftedPrice

Ajoute dans TSM la source `smartAvgCrafted` et expose le service partagé `YayaCraftedPriceAPI.GetPriceQuote`.

- Un snapshot est enregistré à chaque craft réussi sous l'itemString exact (qualité et niveau conservés), tandis que la lecture regroupe les variantes équivalentes au niveau TSM pour les prix.
- Le coût enregistré est ajusté avec la quantité réellement produite (multicraft) et les réactifs retournés par Resourcefulness.
- La capture couvre aussi les crafts lancés via `C_TradeSkillUI.CraftRecipe`, utilisé par YayaQueue.
- Les allocations de réactifs fournies par YayaQueue sont utilisées quand elles sont disponibles.
- `GetPriceQuote` centralise l'ordre : `SmartAvgBuy`, snapshot AH, `VendorBuy`, `dbminbuyout`, `dbmarket`, puis containers.
- Un prix absent reste inconnu ; il n'est jamais converti en zéro.
- La source prend la quantité actuellement possédée via `NumInventory`, puis les snapshots les plus récents jusqu'à couvrir cette quantité.
- Le tooltip réessaie après son remplissage, réinitialise son marqueur à chaque changement d'item et utilise le compteur d'inventaire Blizzard en fallback.
- `/ycp debug` active ou désactive les logs de capture et affiche l'état TSM, des hooks et des snapshots.
