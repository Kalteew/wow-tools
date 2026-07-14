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
python scripts\flipping\build-flipping-groups.py --region eu
python scripts\flipping\build-flip-lists.py
python scripts\flipping\apply-tsm-flip-groups.py
python scripts\flipping\apply-auctionator-sniping-lists.py
python scripts\flipping\apply-auctionator-sniping-lists.py --skip-web --allow-partial
.\scripts\wow-addon-profiles.ps1 status
.\scripts\wow-addon-profiles.ps1 capture -Character Kalteew -Profile play
.\scripts\wow-addon-profiles.ps1 assign -Character Yayatest -Profile gold
.\scripts\wow-addon-profiles.ps1 apply-assigned
.\scripts\wow-addon-profiles.ps1 apply -Character Yayatest -Profile gold -DryRun
.\scripts\wow-addon-profiles.ps1 apply -Character Yayatest -Profile flipping -DryRun
```

Data is stored under:

- [data/wow.sqlite3](C:/Users/Yaya/source/tools/wow-tools/data/wow.sqlite3)
- [data/cache](C:/Users/Yaya/source/tools/wow-tools/data/cache)
- [data/calibration/hourly-estimates.json](C:/Users/Yaya/source/tools/wow-tools/data/calibration/hourly-estimates.json)
- [data/account](C:/Users/Yaya/source/tools/wow-tools/data/account)
- [data/flipping](C:/Users/Yaya/source/tools/wow-tools/data/flipping)
- [data/reports](C:/Users/Yaya/source/tools/wow-tools/data/reports)

Key files:

- [wow_tools/cli.py](C:/Users/Yaya/source/tools/wow-tools/wow_tools/cli.py)
- [wow_tools/farm_model.py](C:/Users/Yaya/source/tools/wow-tools/wow_tools/farm_model.py)
- [wow_tools/seeds.py](C:/Users/Yaya/source/tools/wow-tools/wow_tools/seeds.py)
- [wow_tools/sources/wowhead.py](C:/Users/Yaya/source/tools/wow-tools/wow_tools/sources/wowhead.py)
- [wow_tools/sources/tsm.py](C:/Users/Yaya/source/tools/wow-tools/wow_tools/sources/tsm.py)
- [wow_tools/local_account.py](C:/Users/Yaya/source/tools/wow-tools/wow_tools/local_account.py)

Bundled addons:

- [addons/YayaWeeklyTracker](C:/Users/Yaya/source/tools/wow-tools/addons/YayaWeeklyTracker)
- [addons/YayaSessionTracker](C:/Users/Yaya/source/tools/wow-tools/addons/YayaSessionTracker)
- [addons/YayaTSMLiveMinBuyout](C:/Users/Yaya/source/tools/wow-tools/addons/YayaTSMLiveMinBuyout)
- [addons/YayaCompanionTargeter](C:/Users/Yaya/source/tools/wow-tools/addons/YayaCompanionTargeter)
- [addons/YayaCovenantWormhole](C:/Users/Yaya/source/tools/wow-tools/addons/YayaCovenantWormhole)
- [addons/YayaAddonProfiles](C:/Users/Yaya/source/tools/wow-tools/addons/YayaAddonProfiles)
- [addons/YayaProfessionSpecializations](C:/Users/Yaya/source/tools/wow-tools/addons/YayaProfessionSpecializations)

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
- `sync-profession-recipes` builds a local SQLite recipe catalog for supported profession skill pages, including outputs, reagents, and item ids needed for later profitability work.
- `query-recipes` searches that local recipe catalog or expands a recursive tree for one crafted output item in plain text or JSON.
- `plan-restock` uses local recipe outputs plus local TSM AppHelper sale metrics to recommend a per-item restock target and bucket summary for one profession expansion such as `Midnight`.
- `analyze-currency-for` reads the Wowhead `currency-for` listview for one currency item, defaults to `Polished Pet Charm` (`163036`), prefers the cheapest charm cost when several vendors exist, and falls back to a gold-only vendor value when the market has no usable price.
- `account-pipeline` reads local SavedVariables once, normalizes the useful bits, and writes:
  - `data/account/account-snapshot.json`: full normalized local snapshot
  - `data/account/account-digest.json`: compact decision-oriented summary
  - `data/account/account-digest.md`: short human-readable recap
- `local-summary` reads your local WoW `SavedVariables` plus TSM `AppData.lua` to expose alts, gold, and local TSM sync freshness.
- `local-items` aggregates observed items across character bags, equipment, auctions, bank, reagent bank, and warband bank if those sections were scanned in-game.
- `local-items --all --json` dumps the full observed account inventory snapshot across all scanned characters and warband storage.
- `local-prices` reads the local TSM AppHelper datasets directly from `Interface\AddOns\TradeSkillMaster_AppHelper\AppData.lua`.
- `scripts/flipping/build-flipping-groups.py` builds the three flip TSM lists: housing, other fast (`saleRate > 0.2`), and an other slow shortlist (`saleRate >= 0.02`, `soldPerDay >= 0.02`, `1000g <= price <= 1M`, top 1000 by slot value).
- `scripts/flipping/build-flip-lists.py` builds housing decor flip lists from local TSM AppHelper data and excludes commodities/watch items.
- `scripts/flipping/apply-tsm-flip-groups.py` backs up and patches TSM flip groups/operations only when WoW is closed.
- `scripts/flipping/apply-auctionator-sniping-lists.py` builds matching Auctionator/PBS sniping files, always writes complete TSM import files, installs only fully named Auctionator lists, and backs up Auctionator/PBS SavedVariables.
- `YayaTSMLiveMinBuyout` overlays TSM `DBMinBuyout` with live AH search prices for the current session.
- `YayaCompanionTargeter` auto-targets known Shadowlands companion XP items to the lowest-level eligible companion, with an optional tracked-only shortlist mode.
- `YayaCovenantWormhole` auto-selects the Shadowlands wormhole destination that matches the active covenant, unless `Shift` is held.
- `YayaAddonProfiles` manages addon profiles including `Jouer`, `Gold`, and `Flipping`, with per-character assignments and quick capture/apply commands.
- `scripts/wow-addon-profiles.ps1` writes Blizzard `WTF/.../AddOns.txt` per character, so a low profile is active before first login.
- On Windows you can also launch [wow_tools_gui.pyw](C:/Users/Yaya/source/tools/wow-tools/wow_tools_gui.pyw) directly to open the GUI without using the CLI.
