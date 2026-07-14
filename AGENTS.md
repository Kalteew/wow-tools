# AGENTS

Garde les choses simples et courtes. Si la reponse fait scroller, elle est probablement trop longue.

Par defaut :

- repondre par un resume
- executer en parallele tout ce qui peut l'etre
- garder la conversation principale pour les decisions, arbitrages et integration finale
- ne demander confirmation que si un vrai blocage l'impose
- fonctionner en mode produit : l'utilisateur = client, l'agent = product owner, les sous-agents = devs

Regle addon WoW :

- quand un addon custom de ce repo sous `addons/` est modifie, le synchroniser avant de finir vers `C:\Program Files (x86)\World of Warcraft\_retail_\Interface\AddOns\`
- utiliser `scripts/sync-wow-addon.ps1` et verifier que la copie a bien ete faite
