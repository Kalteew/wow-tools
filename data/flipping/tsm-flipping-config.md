# TSM Flipping Config

## Custom Sources

```text
flipvalue = first(dbregionsaleavg, dbregionmarketavg, dbhistorical)
flipbuyfast = min(35% dbregionmarketavg, 50% dbregionsaleavg, 40% dbhistorical)
flipbuypremium = min(25% dbregionmarketavg, 35% dbregionsaleavg, 30% dbhistorical)
decorbuy = ifgt(dbregionsalerate, 0.02, min(45% dbregionmarketavg, 60% dbregionsaleavg, 50% dbhistorical), min(30% dbregionmarketavg, 40% dbregionsaleavg, 35% dbhistorical))
```

## Groups

```text
FLIP
FLIP\Housing
FLIP\Other Slow
FLIP\Other Fast
```

## Operations

- `Flip Decor`: auctioning/shopping for housing, shopping max price `decorbuy`, restock `1`.
- `Flip Fast`: auctioning/shopping for other fast movers (`saleRate > 0.2`), shopping max price `flipbuyfast`, restock `2`.
- `Flip Premium`: shopping max price `flipbuypremium`, restock `1`.
- `Flip Rare`: auctioning for other slow movers.

## Slow Filter

`Other Slow` is a shortlist, not the full non-commodity dump:

- `saleRate >= 0.02`
- `soldPerDay >= 0.02`
- `price >= 1000g`
- `price <= 1M`
- top `1000` by `gold_per_slot_day`

## Commands

```powershell
python scripts\flipping\build-flipping-groups.py --region eu
python scripts\flipping\build-flip-lists.py
python scripts\flipping\apply-tsm-flip-groups.py
python scripts\flipping\apply-auctionator-sniping-lists.py
python scripts\flipping\apply-auctionator-sniping-lists.py --skip-web --allow-partial
.\scripts\wow-addon-profiles.ps1 apply -Character <banker> -Profile flipping -DryRun
```

`apply-tsm-flip-groups.py` refuses to run while `Wow.exe` is active.
`apply-auctionator-sniping-lists.py` writes complete TSM import files for all three sniping lists. It installs only lists with fully resolved names into Auctionator, backs up `Auctionator.lua` and `PointBlankSniper.lua`, then selects the best installed list in PBS.
`build-flipping-groups.py` writes `flipping-housing.tsm.txt`, `flipping-other-slow.tsm.txt`, and `flipping-other-fast.tsm.txt`.
By default, housing comes from `data/flipping/housing-bou-wowhead-ids.txt` (Wowhead Housing + Binds when used, 368 unique IDs) and other items come from TSM AppHelper non-commodity datasets.
