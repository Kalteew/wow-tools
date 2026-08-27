# Yaya Core

Implementations partagees par la suite d'addons Yaya. Chaque addon gardait sa
propre copie du formatage monetaire, du wrapper `TSM_API` et de la purge des
journaux de debug : huit variantes du premier, quatre du deuxieme, neuf du
troisieme. Un correctif devait donc etre reporte a la main dans chaque addon.

Les addons consommateurs conservent leurs fonctions locales : seul le corps
appelle desormais ce module, les sites d'appel existants ne changent pas.

## Modules

### `YayaCore.Money`

- `Format(copper, opts)` : affichage standard de WoW. `opts.zeroText` remplace
  un montant nul ou negatif, `opts.clampNegative` ramene les negatifs a zero.
- `FormatCompact(copper)` : forme courte pour les affichages etroits
  (`15.0k`, `150g`, `25s`, `45c`), signe compris.
- `FormatGoldOnly(copper, signed)` : or uniquement, suivi de l'icone de piece.
- `GetGoldIconMarkup()` : balisage de l'icone, avec repli si
  `CreateTextureMarkup` est absent.

### `YayaCore.Price`

Acces unifie a TradeSkillMaster, `pcall` compris.

- `IsAvailable()` : TSM expose-t-il les fonctions necessaires.
- `ToItemString(item)` : accepte un itemID, un lien ou une chaine TSM.
- `Get(item, source)` : valeur en cuivre, ou `nil` si TSM est absent, l'objet
  inconnu, la source invalide ou le prix nul.

### `YayaCore.RingBuffer`

Journal borne sans recopie. Les addons purgeaient par `table.remove(store, 1)`
repete, ce qui recopie tout le tableau a chaque entree : sur un journal de 400
lignes, 400 deplacements par nouvelle ligne.

- `Push(store, entry, limit)` : ecriture en place, entree de n'importe quel type.
- `Read(store, count)` : restitution dans l'ordre chronologique.

Un journal ecrit par l'ancienne version est repris sans perte : tant que la
limite n'est pas atteinte, l'ajout reste lineaire.

### `YayaCore.Log`

- `New(addonName, opts)` : renvoie un journal avec `Print`, `Append` et `Read`.
  `opts.store` fournit la table de stockage, `opts.limit` sa taille, `opts.color`
  et `opts.prefix` l'apparence dans le chat.

### `YayaCore.Item`

- `Load(itemID, callback)` : rappelle immediatement si les donnees sont en
  cache, sinon a l'arrivee de `ITEM_DATA_LOAD_RESULT`. Les demandes concurrentes
  pour un meme objet partagent une seule requete.

### `YayaCore.Tooltip`

- `Attach(frame, provider, opts)` : branche `OnEnter`/`OnLeave` sur une frame,
  `provider(tooltip, frame)` remplissant l'infobulle.

Les infobulles existantes n'ont pas ete migrees : elles utilisent quatre ancres
differentes, melangent `AddLine` et `SetHyperlink`, et seuls trois `OnLeave` sur
quarante-quatre se contentent de masquer l'infobulle. Il n'y avait pas de
duplication reelle a eliminer. Cette fonction sert aux nouveaux usages simples.

### `YayaCore.Schedule`

- `NewToken()` : planificateur dont chaque demande annule la precedente.
  `C_Timer.After` n'etant pas annulable, un jeton est compare a l'echeance pour
  ignorer les rappels perimes. Sans `C_Timer`, le rappel est immediat.

## Dependance

Les addons consommateurs declarent `## Dependencies: YayaCore`. WoW garantit
alors l'ordre de chargement, et refuse de charger un addon dont la dependance
est absente ou desactivee.

## Tests

`Tests/test_yayacore.lua` s'execute hors du jeu avec Lua 5.1, l'API WoW etant
remplacee par des doublures :

```
pwsh -NoProfile -File ..\..\scripts\Test-Addons.ps1 -LuaPath <dossier lua>
```

Le script compile aussi tous les addons du depot avec `luac -p`, seul controle
qui attrape une vraie erreur de syntaxe ou un depassement de la limite Lua de
200 variables locales par chunk. Lua 5.1 pour Windows se recupere sur
[LuaBinaries](https://luabinaries.sourceforge.net), sans installation.
