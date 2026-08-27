# YayaCraftingOrders

Addon personnel de commandes de mécènes.

Le dossier `YayaCraftingOrdersLocal` est volontairement distinct de l'ancien dossier CurseForge afin que le client ne propose plus de réinstaller l'ancien fork.

Fonctions:

- prix via `YayaCraftedPriceAPI` quand disponible, avec fallback `TradeSkillMaster`
- utilise la moyenne observée de `YayaContainerValues` en dernier fallback pour valoriser les containers connus (payouts, moxies, etc.)
- multi-selection des work orders
- ajout direct des commandes selectionnees dans `YayaQueue`
- envoyer les commandes automatiques vers `YayaQueue` avec le plan de réactifs minimal, donc rang 1 ; une exigence de qualité client n'active pas l'achat automatique de rangs supérieurs
- à chaque ouverture d'un métier, uniquement à proximité de la station : attendre la stabilisation du nouvel ID métier et `CRAFTINGORDERS_CAN_REQUEST`, puis demander les commandes de patrons en headless avec le métier résolu par `GetChildProfessionInfo()` puis `GetBaseProfessionInfo()` ; les changements directs entre deux métiers et les refus temporaires sont retentés de façon bornée ; une réponse vide ou une donnée indisponible bascule vers l'onglet patrons comme fallback visible
- charge toutes les pages Blizzard des commandes de patrons et ignore les filtres natifs de l'onglet, puis applique uniquement les filtres propres à YPO
- le token `CRAFTINGORDERS_CAN_REQUEST` est étiqueté avec le métier du flux en cours, y compris quand une requête est déjà en vol ; `GetProfessionSnapshot()` retarde d'une ouverture et fournissait une étiquette erronée
- ce token est traité comme un déblocage de throttle côté serveur, pas comme un droit attaché à un métier : une étiquette qui ne correspond pas au flux est acceptée en signalant la dérive (`profession-drift`), au lieu de bloquer le headless jusqu'au fallback visible
- à chaque changement de métier, l'état du token est remis à neutre : il décrivait la requête du métier précédent, si bien que le premier métier de la session démarrait en `bootstrap` avec une requête immédiate tandis que les suivants héritaient d'un token `consumed` et devaient attendre. C'est cette asymétrie qui rendait l'ouverture du second métier aléatoire
- si le token n'arrive pas, YPO retente la récupération headless avec un recul progressif (1 s, 2 s, 4 s...), puis bascule vers le fallback visible à 10 secondes au total
- une requête émise sans autorisation du serveur (`bootstrap` ou récupération forcée) ne consomme pas le budget de 3 requêtes headless : elle peut être ignorée en silence, et son propre timer de timeout la borne déjà
- surtout, une telle requête ne reçoit **jamais** de callback : le serveur répond à la place par `CRAFTINGORDERS_CAN_REQUEST`. Ce token est donc traité comme la réponse à la requête en vol : celle-ci est abandonnée, son `requestID` invalidé, et une nouvelle requête part immédiatement avec `tokenReason=ready`. Sans cela le flux restait bloqué sur `requesting=true` pendant les 10 secondes du timeout, puis basculait sur le flux visible — le symptôme observé sur l'ouverture d'un métier après le premier
- à la première ouverture du métier, déclencher avec YayaQueue l'ajout de la recette favorite en concentration puis le scan des first crafts, que le chemin headless ou le fallback visible ait été utilisé
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
- une ouverture n'est marquée comme traitée qu'après le callback de requête et le passage d'auto-queue réussis ; les logs `/ypo debug` corrèlent les IDs enfant/base/onglet, les anciens/nouveaux flows lors d'un changement direct de métier, le token de requête, les callbacks et la reconstruction de liste
- la queue YQ reste l’autorité de déduplication par `orderID`; le cache de session ne bloque plus une réinjection lorsque l’entrée n’existe réellement plus
- après un échec ou un timeout de `Next`, YQ peut demander une resynchronisation headless de la commande ; l’UI des patrons reste un outil de consultation, pas une précondition du craft
- l'auto-queue utilise une valeur nette : KP 1000g de référence par défaut, appliquée selon `référence × (1 - KP investis / KP max)` (87 % investis = 130g/KP), first craft 1000g, montée en compétence 200g, moxie 4g par défaut ; les valeurs KP/Moxie sont modifiables dans les options et partagées par le compte ; la concentration coûte 3g/point en alchimie, 0g/point en travail du cuir et 1g ailleurs
- `/ypo debug` active ou desactive les traces de chargement pour la session
- `/ypo debug status` affiche un instantane de l'etat courant
- les 400 dernières traces sont conservées dans `YayaCraftingOrdersDebug` et restent lisibles dans les SavedVariables après `/reload` ou déconnexion
