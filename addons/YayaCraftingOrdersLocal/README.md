# YayaCraftingOrders

Addon personnel de commandes de mécènes.

Le dossier `YayaCraftingOrdersLocal` est volontairement distinct de l'ancien dossier CurseForge afin que le client ne propose plus de réinstaller l'ancien fork.

Fonctions:

- prix via `YayaCraftedPriceAPI` quand disponible, avec fallback `TradeSkillMaster`
- utilise la moyenne observée de `YayaContainerValues` en dernier fallback pour valoriser les containers connus (payouts, moxies, etc.)
- multi-selection des work orders
- ajout direct des commandes selectionnees dans `YayaQueue`
- à chaque ouverture d'un métier, uniquement à proximité de la station : demander les commandes de patrons en headless avec le métier résolu par `GetChildProfessionInfo()` puis `GetBaseProfessionInfo()` ; les nouveaux ordres éligibles sont ajoutés et les ordres absents du refresh sont retirés de `YayaQueue` ; l'onglet patrons reste un fallback borné de 3 secondes si la requête ou les données échouent
- à la première ouverture du métier, déclencher avec YayaQueue l'ajout de la recette favorite en concentration
- les commandes ajoutées dans `YayaQueue` conservent leur `orderID` et les `CraftingReagentInfo` joueur (`dataSlotIndex`) pour le flow direct de `Next` ; les réactifs client et de base restent à Blizzard
- une liste Blizzard vide est confirmée trois fois avant de synchroniser les suppressions YQ; un retour ultérieur de la commande peut la réinjecter pendant la même session
- bouton `TOUT` avec 4 modes:
  - tout
  - recettes connues
  - recettes rentables
  - recettes avec les materiaux disponibles

Notes:

- le calcul de profit depend du service de prix partage (TSM, snapshot AH, marchand, containers)
- une valeur partielle ou inconnue ne valide plus le profit ni l'auto-queue
- les moyennes de containers sont recalculées avec le prix TSM courant; elles restent indisponibles si un item observé n'a pas de prix
- l'ajout dans `YayaQueue` queue des crafts de work orders en mode `crafts`, sans se baser sur les outputs deja presents en inventaire
- le headless et le fallback visible gardent les conditions actuelles de push vers `YayaQueue` et une commande avec concentration n'est ajoutée que si la concentration disponible, après les réservations YQ, suffit
- une ouverture n'est marquée comme traitée qu'après le callback de requête et le passage d'auto-queue réussis ; les logs `/ypo debug` corrèlent les IDs enfant/base/onglet, la requête, le fallback et les quantités YQ
- la queue YQ reste l’autorité de déduplication par `orderID`; le cache de session ne bloque plus une réinjection lorsque l’entrée n’existe réellement plus
- après un échec ou un timeout de `Next`, YQ peut demander une resynchronisation headless de la commande ; l’UI des patrons reste un outil de consultation, pas une précondition du craft
- l'auto-queue utilise une valeur nette : KP 300g par défaut, first craft 1000g, montée en compétence 200g, moxie 4g par défaut ; les valeurs KP/Moxie sont modifiables dans les options et partagées par le compte ; la concentration coûte 3g/point en alchimie, 0g/point en travail du cuir et 1g ailleurs
- `/ypo debug` active ou desactive les traces de chargement pour la session
- `/ypo debug status` affiche un instantane de l'etat courant
