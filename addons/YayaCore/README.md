# Yaya Core

Implementations partagees par la suite d'addons Yaya. Chaque addon gardait sa
propre copie du formatage monetaire, du wrapper `TSM_API` et de la purge des
journaux de debug : huit variantes du premier, quatre du deuxieme, neuf du
troisieme. Un correctif devait donc etre reporte a la main dans chaque addon.

Les addons consommateurs conservent leurs fonctions locales : seul le corps
appelle desormais ce module, les sites d'appel existants ne changent pas.

## Modules

### `YayaCore.UI`

Le design system de la suite : la source de verite unique pour les couleurs,
les espacements, les polices et les fabriques de widgets. Il remplace sept
teintes de fond concurrentes, trois recettes de zebrure, deux familles de
backdrop et trois familles d'accent.

**Regle d'acces.** Consommer par acces de champ (`YayaCore.UI.PAD.md`), qui ne
coute aucune variable locale, ou au plus **un** `local UI = YayaCore.UI` par
fichier. `YayaWeeklyTracker.lua` et `YayaQueue.lua` sont a 198 et 196 variables
locales de chunk sur les 200 que Lua 5.1 autorise ; depasser la limite empeche
l'addon entier de charger, sans message clair en jeu.

**Tokens.** `UI.COLOR` (17 couleurs RGBA, accent menthe), `UI.HEX` (les memes en
balisage inline), `UI.PAD` (`xs 2` a `xl 14`), `UI.SIZE` (hauteurs de ligne,
icones, `contentW 192` pour la largeur utile d'une section), `UI.FONT` (quatre
roles plus `heading` pour les canevas Settings), `UI.BACKDROP` (recette unique,
filet de 1 px), `UI.TEXT` (texte multi-lignes plafonne).

`UI.ACTION` porte la geometrie des boutons d'action et **conditionne
l'autoclicker de l'utilisateur** : la modifier oblige a repointer l'autoclicker.
Voir l'avertissement en tete de `UI.lua`.

**Couleur et texte.** `Colorize(tone, text)`, `Unpack(color, alpha)`,
`SetFont(fontString, name)`, `BoundLabel(fontString, justify)` pour borner un
libelle a une ligne, `StripMarkup(text)`, `MeasureWidth(text, font)`,
`LineHeight(fontString)`, `ResolveWidth(region, fallback)`.

**Texte sur plusieurs lignes.** `PackLines(tokens, opts)` repartit des jetons
sur au plus `maxLines` lignes en posant lui-meme les retours a la ligne, donc
sans jamais couper un jeton et en connaissant le nombre de lignes **avant**
d'ecrire le texte ; `WrapLabel(fontString, opts)` bascule un libelle en
multi-lignes avec une largeur explicite ; `FitLabel(...)` pose le texte et rend
la hauteur a reserver ; `IsLabelTruncated(fontString)` ne vaut qu'apres une
passe de rendu, donc a l'entree de la souris.

**Fabriques.** `ApplyPanelBackdrop(frame, opts)`, `CreateDivider(parent, opts)`
(`opts.vertical` pour un filet vertical), `CreateButton(parent, text, opts)`,
`BindButtonLabel(button, text)` qui borne le libelle interne d'un bouton et
rend son texte complet au survol, `CreateGlyphButton(parent, kind, opts)` pour
les commandes `R` et cadenas du bandeau, `CreateCheckbox(parent, text, opts)`,
`CreateCloseButton(header, frameToClose, opts)`, `CreateHeader(parent, title,
opts)`, `CreateRow` / `DecorateRow`, `CreateScrollList(parent, opts)` et
`StackLayout(parent, opts)`.

Toutes les fabriques **degradent en `nil`** plutot que de lever quand le client
n'expose pas ce qu'elles demandent : l'appelant doit traiter ce cas.

### `YayaCore.ActionBinding`

Raccourci Blizzard `Yaya > Action suivante (YQ / YWT)`, sans touche imposee.
`RegisterProvider(name, getter)` enregistre `queue` ou `weekly` ; le getter
renvoie le panneau prioritaire et la liste de boutons d'action. YQ visible
bloque le repli meme si NEXT est grise. Sinon, selection du bouton YWT visible
et actif le plus bas, en tenant compte de son echelle. Un clic securise au
relachement, sans boucle ni double execution ; desactive en combat.
La declaration XML demande aussi `runOnUp="true"` : l'enregistrement `AnyUp`
du bouton seul ne suffit pas a recevoir le relachement du raccourci.
La categorie est le texte fixe `Yaya` : elle n'utilise pas de globale addon
dans l'interface Blizzard, ce qui evite que le raccourci disparaisse a cause du
taint. Le libelle est fourni par `description` dans `Bindings.xml`.

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
