# wow-tools

Local WoW data toolbox focused on gathering professions and price lookups.

What it does:

- Builds a local SQLite catalog for `Herbalism`, `Mining`, and `Skinning`
- Enriches items from public Wowhead pages
- Caches raw HTTP responses locally for faster follow-up queries
- Pulls Retail EU pricing stats from public TradeSkillMaster item pages
- Produces an expansion comparison report for farming analysis
- Produces a rarity-aware farmability report with estimated `units/hr` and `gold/hr`
- Seeds a local legacy recipe graph and computes recursive `buy vs craft` profitability
- Builds a compact local account digest from SavedVariables and TSM AppHelper
- Compares current Blizzard Auction House prices by EU connected realm, including item-level variants
- Provides a complete mount catalogue tab with images, Wowhead links, expansion/availability/RMT filters, reliability score, and time estimates

Current scope:

- Retail only
- Pricing is region-based for commodities, which matters for herbs and ores
- Skinning materials are tracked too, but some leather-side families share the same farm and should be compared as alternative targets, not summed together
- Seeded around actually farmable raw gathering materials by expansion
- Recipe profitability currently starts from a curated legacy craft set and expands from there

Main commands:

```powershell
python -m wow_tools bootstrap --region eu
python -m wow_tools compare-expansions --region eu --top 5
python -m wow_tools compare-farmability --region eu --top 5
python -m wow_tools sync-catalog
python -m wow_tools sync-mounts
python -m wow_tools sync-prices --region eu
python -m wow_tools sync-recipes --region eu
python -m wow_tools analyze-recipes --region eu --top 10
python -m wow_tools analyze-recipes --region eu --top 10 --owned-only
python -m wow_tools discover-recipes --item-id 95416 --max-depth 4
python -m wow_tools analyze-discovered --item-id 95416 --item-id 65891 --region eu --max-depth 4 --sync
python -m wow_tools sync-profession-recipes
python -m wow_tools query-recipes --name "vial of the sands"
python -m wow_tools query-recipes --item-id 65891 --json
python -m wow_tools plan-restock --profession enchanting --expansion Midnight
python -m wow_tools analyze-currency-for
python -m wow_tools analyze-currency-for --item-id 116415
python -m wow_tools account-pipeline --top 10
python -m wow_tools gui
python -m wow_tools local-summary
python -m wow_tools local-items --name hearthstone
python -m wow_tools local-items --all --json
python -m wow_tools local-prices --item-id 124119
python -m wow_tools sync-auction-catalog --region eu
python -m wow_tools sync-auction-realms --region eu
python -m wow_tools sync-auction-data --region eu
python -m wow_tools search-auctions --name "Sin'dorei Jeweler's Loupes"
python scripts\flipping\build-flipping-groups.py --region eu
python scripts\flipping\build-flip-lists.py
python scripts\flipping\apply-tsm-flip-groups.py
python scripts\flipping\apply-auctionator-sniping-lists.py
python scripts\flipping\apply-auctionator-sniping-lists.py --skip-web --allow-partial
.\scripts\wow-addon-profiles.ps1 status
.\scripts\wow-addon-profiles.ps1 capture -Character CharacterName -Profile play
.\scripts\wow-addon-profiles.ps1 assign -Character AltName -Profile gold
.\scripts\wow-addon-profiles.ps1 apply-assigned
.\scripts\wow-addon-profiles.ps1 apply -Character AltName -Profile gold -DryRun
.\scripts\wow-addon-profiles.ps1 apply -Character AltName -Profile flipping -DryRun
```

Data is stored under:

- `data/wow.sqlite3`
- `data/cache`
- [data/calibration/hourly-estimates.json](data/calibration/hourly-estimates.json)
- `data/account`
- [data/flipping](data/flipping)
- `data/reports`

Key files:

- [wow_tools/cli.py](wow_tools/cli.py)
- [wow_tools/farm_model.py](wow_tools/farm_model.py)
- [wow_tools/seeds.py](wow_tools/seeds.py)
- [wow_tools/sources/wowhead.py](wow_tools/sources/wowhead.py)
- [wow_tools/sources/tsm.py](wow_tools/sources/tsm.py)
- [wow_tools/auction.py](wow_tools/auction.py)
- [wow_tools/sources/blizzard.py](wow_tools/sources/blizzard.py)
- [wow_tools/local_account.py](wow_tools/local_account.py)
- [wow_tools/mounts.py](wow_tools/mounts.py)

Bundled addons:

- [addons/YayaWeeklyTracker](addons/YayaWeeklyTracker)
- [addons/YayaSessionTracker](addons/YayaSessionTracker)
- [addons/YayaTSMLiveMinBuyout](addons/YayaTSMLiveMinBuyout)
- [addons/YayaTSMMailingFix](addons/YayaTSMMailingFix)
- [addons/YayaCompanionTargeter](addons/YayaCompanionTargeter)
- [addons/YayaCovenantWormhole](addons/YayaCovenantWormhole)
- [addons/YayaAddonProfiles](addons/YayaAddonProfiles)
- [addons/YayaProfessionSpecializations](addons/YayaProfessionSpecializations)
- [addons/YayaPremadeAssistant](addons/YayaPremadeAssistant)
- [addons/YayaReagentSniper](addons/YayaReagentSniper)

Notes:

- `Hyjal` does not change herb/ore commodity prices on Retail because commodity AH listings are region-wide.
- The comparison report uses both unit price and a demand proxy based on TSM sale stats.
- The farmability report uses a route-weighted model: it downweights rare replacement nodes like `Black Lotus`, `Khorium Ore`, or `Nocturnal Lotus`, gives a modest bonus to dense route staples like `Cobalt Ore`, `Ghost Iron Ore`, `Leystone Ore`, or `Coarse Leather`, and estimates average `units/hr` and `gold/hr` for each family.
- If `data/calibration/hourly-estimates.json` contains sourced route observations, the model uses those before falling back to heuristics.
- For `Skinning`, when the web has no direct `units/hr` report, the model falls back to expansion baselines plus family-type ratios derived from neighboring expansions.
- If you set `TSM_API_KEY`, the tool uses the official TSM pricing API instead of the slower public HTML fallback.
- `sync-recipes` seeds a local item universe for targeted craft analysis, then snapshots only that subset of TSM prices into SQLite.
- `analyze-recipes` resolves the recipe tree recursively, chooses the cheaper path for each ingredient (`buy` vs `craft`), adds a balanced `profit + sell rate` score, refreshes recipe ownership from `DataStore_Crafts` on every run, and shows both the global ranking and the locally owned subset.
- `analyze-recipes --owned-only` keeps only recipes confirmed as learned locally in `DataStore_Crafts`.
- `discover-recipes` walks Wowhead `created-by-spell` tabs from one or more item ids and exports the discovered recipe graph to a local JSON report.
- `analyze-discovered` takes arbitrary output item ids, discovers their Wowhead recipe graph, snapshots the needed TSM prices locally, scores the resulting crafts with the same balanced ranking, refreshes recipe ownership from `DataStore_Crafts` on every run, and shows both the global ranking and the locally owned subset when the spell id is known.
- `analyze-discovered --owned-only` applies the same strict local ownership filter when the discovered recipe spell id can be matched.
- `gui` opens a native Windows `tkinter` interface with recipe tabs, a scanned-characters tab, a `Spécialisation` tab for Midnight gold/concentration planning, and a `Lumber` tab that ranks which woods look worth farming from local TSM pricing plus linked logging-product demand.
- The `Montures` tab loads `data/mounts-catalog.json`, keeps obtainable/retired/upcoming entries, excludes RMT by default, and sorts deterministic objectives above random drops. `sync-mounts` refreshes the 1,400+ entry source catalogue and preserves the source timestamp and failed-detail count.
- `sync-profession-recipes` builds a local SQLite recipe catalog for supported profession skill pages, including outputs, reagents, and item ids needed for later profitability work.
- `query-recipes` searches that local recipe catalog or expands a recursive tree for one crafted output item in plain text or JSON.
- `plan-restock` uses local recipe outputs plus local TSM AppHelper sale metrics to recommend a per-item restock target and bucket summary for one profession expansion such as `Midnight`.
- `analyze-currency-for` reads the Wowhead `currency-for` listview for one currency item, defaults to `Polished Pet Charm` (`163036`), prefers the cheapest charm cost when several vendors exist, and falls back to a gold-only vendor value when the market has no usable price.
- `account-pipeline` reads local SavedVariables once, normalizes the useful bits, and writes:
  - `data/account/account-snapshot.json`: full normalized local snapshot
  - `data/account/account-digest.json`: compact decision-oriented summary
  - `data/account/account-digest.md`: short human-readable recap
- `local-summary` reads your local WoW `SavedVariables` plus TSM `AppData.lua` to expose alts, gold, and local TSM sync freshness.
- Local patching scripts auto-detect the most recent account; set `WOW_RETAIL_ROOT` or `WOW_ACCOUNT_ROOT` to override it.
- `local-items` aggregates observed items across character bags, equipment, auctions, bank, reagent bank, and warband bank if those sections were scanned in-game.
- `local-items --all --json` dumps the full observed account inventory snapshot across all scanned characters and warband storage.
- `local-prices` reads the local TSM AppHelper datasets directly from `Interface\AddOns\TradeSkillMaster_AppHelper\AppData.lua`.
- The AH comparator uses Blizzard's Retail API for prices and connected-realm data. Set `BLIZZARD_CLIENT_ID` and `BLIZZARD_CLIENT_SECRET` first.
- PowerShell example: `$env:BLIZZARD_CLIENT_ID = "..."; $env:BLIZZARD_CLIENT_SECRET = "..."`.
- `sync-auction-catalog` downloads only item names from the public TSM region catalog; it does not provide AH prices or item ranks.
- `sync-auction-data` stores local snapshots under `data/wow.sqlite3`, reuses one Blizzard client/token per collection, decodes item bonus lists with the public [Shatari item-key algorithm](https://github.com/erorus/shatari/blob/master/src/itemKey.js), and keeps commodities at EU scope. Retention defaults to 30 days and 96 snapshots per realm; override with `WOW_AUCTION_RETENTION_DAYS` and `WOW_AUCTION_RETENTION_PER_REALM`.
- `scripts/wowhead/build_reagent_sniper_catalog.py` writes atomically to the repo addon by default; `--output` can target another explicit path.
- `search-auctions` shows one line per connected realm group. Missing listings are shown as `-`; old snapshots remain available locally for history.
- `scripts/flipping/build-flipping-groups.py` builds the three flip TSM lists: housing, other fast (`saleRate > 0.2`), and an other slow shortlist (`saleRate >= 0.02`, `soldPerDay >= 0.02`, `1000g <= price <= 1M`, top 1000 by slot value).
- `scripts/flipping/build-flip-lists.py` builds housing decor flip lists from local TSM AppHelper data and excludes commodities/watch items.
- `scripts/flipping/apply-tsm-flip-groups.py` backs up and patches TSM flip groups/operations only when WoW is closed.
- `scripts/flipping/apply-auctionator-sniping-lists.py` builds matching Auctionator/PBS sniping files, always writes complete TSM import files, installs only fully named Auctionator lists, and backs up Auctionator/PBS SavedVariables.
- `YayaTSMLiveMinBuyout` overlays TSM `DBMinBuyout` with live AH search prices for the current session.
- `YayaTSMMailingFix` refreshes TSM bag tracking before group mailing and uses the live bag-slot lock state so items are not silently skipped.
- `YayaCompanionTargeter` auto-targets known Shadowlands companion XP items to the lowest-level eligible companion, with an optional tracked-only shortlist mode.
- `YayaCovenantWormhole` auto-selects the Shadowlands wormhole destination that matches the active covenant, unless `Shift` is held.
- `YayaAddonProfiles` manages addon profiles including `Jouer`, `Gold`, and `Flipping`, with per-character assignments and quick capture/apply commands.
- `YayaPremadeAssistant` automatically invites solo premade applicants by name and accepts invitations from groups you applied to; grouped applicants use a manual button.
- `scripts/wow-addon-profiles.ps1` writes Blizzard `WTF/.../AddOns.txt` per character, so a low profile is active before first login.
- On Windows you can also launch [wow_tools_gui.pyw](wow_tools_gui.pyw) directly to open the GUI without using the CLI.

## Bootstrap complet sous Windows

Copier ce prompt dans Codex pour reconstruire l'environnement `wow-tools`, les skills et les addons :

```text
Configure entièrement mon environnement WoW sous Windows. Exécute les actions, ne te contente pas de les expliquer.

Chemins :
- dépôt : %USERPROFILE%\source\tools\wow-tools
- skills Codex : %USERPROFILE%\.codex\skills
- addons Retail : C:\Program Files (x86)\World of Warcraft\_retail_\Interface\AddOns

Actions :

1. Vérifie Git, Python, Node.js et PowerShell. Installe uniquement les prérequis manquants.

2. Crée %USERPROFILE%\source\tools si nécessaire, puis clone :
   https://github.com/Kalteew/wow-tools.git

   Si le dépôt existe déjà, préserve les modifications locales et fais seulement une mise à jour fast-forward sûre.

3. Dans wow-tools, installe les dépendances :
   - npm ci
   - npx playwright install chromium
   - vérifie Python avec : python -m unittest discover -s tests

4. Crée le dossier des skills Codex et installe/restaure tous les skills WoW, TSM et Yaya disponibles dans mon profil. Minimum attendu :
   - world-of-warcraft
   - wow-addon-development
   - wow-local-account-data
   - wow-profession-recipes
   - wow-realm-population
   - wow-flipping-housing
   - tsm-api
   - tsm-docs
   - tsm-restock-groups
   - yaya-queue-crafting-orders
   - yaya-weekly-tracker

   Utilise le gestionnaire de skills disponible. Ne réécris pas un skill existant valide. Vérifie la présence de chaque SKILL.md et signale clairement toute source introuvable.

5. Vérifie que WoW Retail est fermé. Sauvegarde les dossiers d'addons existants avant remplacement, sans toucher à WTF ni aux SavedVariables.

6. Depuis la racine du dépôt, installe ces addons avec le script officiel :
   .\scripts\sync-wow-addon.ps1 -AddonNames YayaWeeklyTracker,YayaQueue,YayaSessionTracker,YayaCraftingOrdersLocal

7. Installe la dernière version stable Retail de TomTom depuis sa source officielle :
   https://www.curseforge.com/wow/addons/tomtom

   Utilise CurseForge si disponible, sinon télécharge l'archive officielle et extrais-la correctement dans le dossier AddOns. Le résultat attendu est :
   ...\AddOns\TomTom\TomTom.toc

8. Valide :
   - les 5 fichiers .toc sont présents ;
   - les 4 addons Yaya installés correspondent au dépôt, par comparaison de hash ;
   - TomTom est une version Retail stable ;
   - aucune archive ou arborescence imbriquée incorrecte ne reste dans AddOns ;
   - le dépôt Git est opérationnel.

9. Termine par un résumé très court :
   - dépôt et branche ;
   - dépendances ;
   - skills installés/manquants ;
   - addons installés ;
   - emplacement des sauvegardes ;
   - éventuels blocages.

Travaille de manière autonome, préserve toute donnée existante et ne demande confirmation qu'en cas de vrai blocage ou d'action destructive ambiguë.
```
