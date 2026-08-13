from __future__ import annotations

import argparse
import json
from pathlib import Path

from wow_tools.account_pipeline import build_account_pipeline, render_account_digest, save_account_pipeline
from wow_tools.auction import (
    build_auction_report,
    render_auction_report,
    sync_auction_catalog,
    sync_auction_data,
    sync_auction_realms,
)
from wow_tools.cache import HttpCache
from wow_tools.config import CACHE_DIR, DB_PATH, DEFAULT_REGION
from wow_tools.currency_value import build_currency_value_report, render_currency_value_report
from wow_tools.db import connect
from wow_tools.profession_recipes import (
    default_professions as default_recipe_professions,
    query_recipes,
    render_recipe_query,
    supported_professions as supported_recipe_professions,
    sync_profession_recipes,
)
from wow_tools.dynamic_recipe_profit import (
    build_discovered_profit_report,
    render_discovered_profit_report,
    save_discovered_profit_report,
    sync_discovered_prices,
)
from wow_tools.local_account import (
    build_summary,
    find_items,
    load_local_state,
    lookup_local_prices,
    render_item_matches,
    render_price_lookup,
    render_summary,
)
from wow_tools.local_recipes import (
    build_recipe_ownership_report,
    render_recipe_ownership_report,
    save_recipe_ownership_report,
)
from wow_tools.mounts import sync_mount_catalog
from wow_tools.recipe_discovery import discover_recipe_graph, save_discovered_recipe_graph
from wow_tools.recipe_profit import (
    build_recipe_profit_report,
    render_recipe_profit_report,
    seed_recipe_items,
    sync_recipe_prices,
)
from wow_tools.restock_planner import build_restock_plan, render_restock_plan
from wow_tools.reports import (
    build_expansion_report,
    build_farmability_report,
    render_expansion_report,
    render_farmability_report,
    save_report,
)
from wow_tools.sources.tsm import sync_prices
from wow_tools.sources.wowhead import sync_catalog
from wow_tools.sources.blizzard import BlizzardApiError, BlizzardClient


def _professions_arg(value: list[str] | None) -> list[str]:
    return value or ["herbalism", "mining", "skinning"]


def _recipe_professions_arg(value: list[str] | None) -> list[str]:
    return value or default_recipe_professions()


def cmd_sync_catalog(args: argparse.Namespace) -> int:
    cache = HttpCache(CACHE_DIR)
    conn = connect(DB_PATH)
    summary = sync_catalog(conn, cache, _professions_arg(args.profession), force=args.force)
    print("Catalog sync complete")
    for profession, data in summary["professions"].items():
        print(f"- {profession}: {data['items']} items")
    if summary["missing"]:
        print(f"- missing seeds: {len(summary['missing'])}")
    return 0


def cmd_sync_mounts(args: argparse.Namespace) -> int:
    summary = sync_mount_catalog(force=args.force, max_workers=args.workers)
    print("Mount catalog sync complete")
    print(f"- mounts: {summary['count']}/{summary['reported']}")
    print(f"- currently obtainable: {summary['available']}")
    print(f"- no RMT: {summary['no_rmt']}")
    print(f"- detail failures: {summary['failures']}")
    print(f"- file: {summary['path']}")
    return 0


def cmd_sync_prices(args: argparse.Namespace) -> int:
    cache = HttpCache(CACHE_DIR)
    conn = connect(DB_PATH)
    summary = sync_prices(
        conn,
        cache,
        args.region,
        force=args.force,
        missing_only=args.missing_only,
        limit=args.limit,
        expansions=args.expansion,
        professions=args.profession,
        item_ids=args.item_id,
    )
    print("Price sync complete")
    print(f"- synced: {summary['synced']}")
    print(f"- failed: {len(summary['failed'])}")
    if summary["failed"]:
        for failure in summary["failed"][:10]:
            print(f"  - item {failure['item_id']}: {failure['error']}")
    return 0


def cmd_sync_auction_catalog(args: argparse.Namespace) -> int:
    cache = HttpCache(CACHE_DIR)
    conn = connect(DB_PATH)
    summary = sync_auction_catalog(conn, cache, args.region, force=args.force)
    print("Auction catalog sync complete")
    print(f"- items: {summary['items']}")
    print(f"- source: {summary['source']}")
    return 0


def cmd_sync_auction_realms(args: argparse.Namespace) -> int:
    conn = connect(DB_PATH)
    try:
        summary = sync_auction_realms(conn, BlizzardClient(), args.region)
    except BlizzardApiError as exc:
        print(f"Blizzard: {exc}")
        return 2
    print("Blizzard realm sync complete")
    print(f"- connected realm groups: {summary['realms']}")
    return 0


def cmd_sync_auction_data(args: argparse.Namespace) -> int:
    cache = HttpCache(CACHE_DIR)
    conn = connect(DB_PATH)
    try:
        summary = sync_auction_data(
            conn,
            cache,
            args.region,
            force=args.force,
            realm_slugs=args.realm_slug,
            limit_realms=args.limit_realms,
            include_commodities=not args.no_commodities,
            workers=args.workers,
        )
    except BlizzardApiError as exc:
        print(f"Blizzard: {exc}")
        return 2
    print("Blizzard auction sync complete")
    print(f"- realms selected: {summary['realms']}")
    print(f"- realms synced: {summary['synced']}")
    print(f"- commodities: {summary['commodities']}")
    print(f"- failures: {len(summary['failed'])}")
    for failure in summary["failed"][:10]:
        print(f"  - {failure['name']}: {failure['error']}")
    return 0


def cmd_search_auctions(args: argparse.Namespace) -> int:
    conn = connect(DB_PATH)
    report = build_auction_report(conn, args.name, args.region, limit=args.limit)
    if args.json:
        print(json.dumps(report, ensure_ascii=False, indent=2))
    else:
        print(render_auction_report(report, max_rows=args.max_rows))
    return 0


def cmd_compare_expansions(args: argparse.Namespace) -> int:
    conn = connect(DB_PATH)
    report = build_expansion_report(conn, args.region, top=args.top)
    report_path = save_report(report, f"expansion-comparison-{args.region}.json")
    print(render_expansion_report(report))
    print("")
    print(f"Saved report: {report_path}")
    return 0


def cmd_compare_farmability(args: argparse.Namespace) -> int:
    conn = connect(DB_PATH)
    report = build_farmability_report(conn, args.region, top=args.top)
    report_path = save_report(report, f"farmability-comparison-{args.region}.json")
    print(render_farmability_report(report))
    print("")
    print(f"Saved report: {report_path}")
    return 0


def cmd_analyze_currency_for(args: argparse.Namespace) -> int:
    cache = HttpCache(CACHE_DIR)
    report = build_currency_value_report(
        cache,
        args.region,
        currency_item_id=args.item_id,
        force=args.force,
    )
    report_path = save_report(report, f"currency-value-{args.item_id}-{args.region}.json")
    if args.json:
        print(json.dumps(report, ensure_ascii=False, indent=2))
    else:
        print(render_currency_value_report(report, top=args.top))
        print("")
        print(f"Saved report: {report_path}")
    return 0


def cmd_bootstrap(args: argparse.Namespace) -> int:
    cache = HttpCache(CACHE_DIR)
    conn = connect(DB_PATH)
    sync_catalog(conn, cache, _professions_arg(args.profession), force=args.force)
    sync_prices(conn, cache, args.region, force=args.force, limit=args.limit)
    report = build_expansion_report(conn, args.region, top=args.top)
    report_path = save_report(report, f"expansion-comparison-{args.region}.json")
    print(render_expansion_report(report))
    print("")
    print(f"Saved report: {report_path}")
    return 0


def cmd_sync_recipes(args: argparse.Namespace) -> int:
    cache = HttpCache(CACHE_DIR)
    conn = connect(DB_PATH)
    recipe_summary = sync_profession_recipes(conn, cache, default_recipe_professions(), force=args.force)
    summary = sync_recipe_prices(conn, cache, args.region, force=args.force)
    print("Recipe graph sync complete")
    print(f"- professions: {len(recipe_summary['professions'])}")
    print(f"- recipes: {recipe_summary['recipes']}")
    print(f"- items: {recipe_summary['items']}")
    print(f"- seeded items: {summary['seeded']}")
    print(f"- tracked item ids: {summary['tracked_item_ids']}")
    print(f"- priced item ids: {summary['priced_item_ids']}")
    print(f"- synced prices: {summary['synced']}")
    print(f"- failed: {len(summary['failed'])}")
    if summary["failed"]:
        for failure in summary["failed"][:10]:
            print(f"  - item {failure['item_id']}: {failure['error']}")
    return 0


def cmd_analyze_recipes(args: argparse.Namespace) -> int:
    cache = HttpCache(CACHE_DIR)
    conn = connect(DB_PATH)
    if args.sync:
        sync_profession_recipes(conn, cache, default_recipe_professions(), force=args.force)
    seed_recipe_items(conn)
    if args.sync:
        sync_recipe_prices(conn, cache, args.region, force=args.force)
    report = build_recipe_profit_report(
        conn,
        args.region,
        top=args.top,
        min_sale_rate=args.min_sale_rate,
        owned_only=args.owned_only,
        retail_root=args.retail_root,
        account_root=args.account_root,
    )
    report_path = save_report(report, f"recipe-profitability-{args.region}.json")
    print(render_recipe_profit_report(report))
    print("")
    print(f"Saved report: {report_path}")
    return 0


def cmd_discover_recipes(args: argparse.Namespace) -> int:
    cache = HttpCache(CACHE_DIR)
    report = discover_recipe_graph(
        cache,
        item_ids=args.item_id,
        force=args.force,
        max_depth=args.max_depth,
    )
    label = "-".join(str(item_id) for item_id in (args.item_id or [])) or "analysis-targets"
    report_path = save_discovered_recipe_graph(report, label)
    print(f"Recipe discovery complete")
    print(f"- roots: {len(report['roots'])}")
    print(f"- discovered items: {len(report['items'])}")
    print(f"Saved report: {report_path}")
    return 0


def cmd_analyze_discovered(args: argparse.Namespace) -> int:
    cache = HttpCache(CACHE_DIR)
    if args.sync:
        summary = sync_discovered_prices(
            cache,
            args.region,
            item_ids=args.item_id,
            force=args.force,
            max_depth=args.max_depth,
        )
        print("Discovered graph sync complete")
        print(f"- seeded items: {summary['seeded']}")
        print(f"- discovered items: {summary['discovered_items']}")
        print(f"- priceable item ids: {summary['priceable_items']}")
        print(f"- synced prices: {summary['synced']}")
        print(f"- failed: {len(summary['failed'])}")
        if summary["failed"]:
            for failure in summary["failed"][:10]:
                print(f"  - item {failure['item_id']}: {failure['error']}")
        print("")
    report = build_discovered_profit_report(
        cache,
        args.region,
        item_ids=args.item_id,
        force=args.force,
        max_depth=args.max_depth,
        top=args.top,
        min_sale_rate=args.min_sale_rate,
        sync=False,
        owned_only=args.owned_only,
        retail_root=args.retail_root,
        account_root=args.account_root,
    )
    label = "-".join(str(item_id) for item_id in args.item_id)
    report_path = save_discovered_profit_report(report, label)
    print(render_discovered_profit_report(report))
    print("")
    print(f"Saved report: {report_path}")
    return 0


def cmd_sync_profession_recipes(args: argparse.Namespace) -> int:
    cache = HttpCache(CACHE_DIR)
    conn = connect(DB_PATH)
    summary = sync_profession_recipes(conn, cache, _recipe_professions_arg(args.profession), force=args.force)
    print("Profession recipe sync complete")
    print(f"- professions: {len(summary['professions'])}")
    print(f"- recipes: {summary['recipes']}")
    print(f"- items: {summary['items']}")
    for profession, data in summary["professions"].items():
        print(
            f"  - {profession}: recipes={data['recipes']} items={data['items']} listviews={data['listviews']}"
        )
    return 0


def cmd_query_recipes(args: argparse.Namespace) -> int:
    conn = connect(DB_PATH)
    result = query_recipes(
        conn,
        item_id=args.item_id,
        spell_id=args.spell_id,
        name=args.name,
        professions=args.profession,
        max_depth=args.max_depth,
        limit=args.limit,
    )
    if args.json:
        print(json.dumps(result, ensure_ascii=False, indent=2))
    else:
        print(render_recipe_query(result))
    return 0


def cmd_local_summary(args: argparse.Namespace) -> int:
    state = load_local_state(args.retail_root, args.account_root)
    summary = build_summary(state)
    if args.json:
        print(json.dumps(summary, ensure_ascii=False, indent=2))
    else:
        print(render_summary(summary))
    return 0


def cmd_local_items(args: argparse.Namespace) -> int:
    if not args.all and args.item_id is None and not args.name:
        raise ValueError("local-items requires --item-id or --name")
    state = load_local_state(args.retail_root, args.account_root)
    matches = find_items(state, item_id=args.item_id, name=args.name)
    if args.json:
        print(json.dumps(matches, ensure_ascii=False, indent=2))
    else:
        print(render_item_matches(matches))
    return 0


def cmd_local_prices(args: argparse.Namespace) -> int:
    result = lookup_local_prices(args.item_id, args.retail_root, args.account_root)
    if args.json:
        print(json.dumps(result, ensure_ascii=False, indent=2))
    else:
        print(render_price_lookup(result))
    return 0


def cmd_local_recipe_owners(args: argparse.Namespace) -> int:
    report = build_recipe_ownership_report(
        spell_id=args.spell_id,
        profession=args.profession,
        retail_root=args.retail_root,
        account_root=args.account_root,
    )
    saved_paths = save_recipe_ownership_report(report, args.save_name) if args.save_name else None
    if args.json:
        print(json.dumps(report, ensure_ascii=False, indent=2))
    else:
        print(render_recipe_ownership_report(report))
        if saved_paths:
            print("")
            print(f"Saved json: {saved_paths['json']}")
            print(f"Saved markdown: {saved_paths['markdown']}")
    return 0


def cmd_account_pipeline(args: argparse.Namespace) -> int:
    snapshot, digest = build_account_pipeline(args.retail_root, args.account_root, top=args.top)
    paths = save_account_pipeline(snapshot, digest)
    if args.snapshot_json:
        print(json.dumps(snapshot, ensure_ascii=False, indent=2))
    elif args.json:
        print(json.dumps(digest, ensure_ascii=False, indent=2))
    else:
        print(render_account_digest(digest))
        print("")
        print(f"Saved digest: {paths['digest_json']}")
        print(f"Saved markdown: {paths['digest_markdown']}")
        print(f"Saved snapshot: {paths['snapshot_json']}")
    return 0


def cmd_plan_restock(args: argparse.Namespace) -> int:
    conn = connect(DB_PATH)
    report = build_restock_plan(
        conn,
        profession=args.profession,
        expansion=args.expansion,
        retail_root=args.retail_root,
        account_root=args.account_root,
        buckets=args.bucket,
    )
    if args.json:
        print(json.dumps(report, ensure_ascii=False, indent=2))
    else:
        print(render_restock_plan(report))
    return 0


def cmd_gui(args: argparse.Namespace) -> int:
    from wow_tools.gui import launch_gui

    return launch_gui()


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Local WoW data toolbox")
    subparsers = parser.add_subparsers(dest="command", required=True)

    sync_catalog_parser = subparsers.add_parser("sync-catalog", help="Sync Wowhead catalog")
    sync_catalog_parser.add_argument("--profession", action="append", choices=["herbalism", "mining", "skinning"])
    sync_catalog_parser.add_argument("--force", action="store_true")
    sync_catalog_parser.set_defaults(func=cmd_sync_catalog)

    sync_mounts_parser = subparsers.add_parser(
        "sync-mounts",
        help="Sync the exhaustive mount catalog with availability and Wowhead links",
    )
    sync_mounts_parser.add_argument("--force", action="store_true")
    sync_mounts_parser.add_argument("--workers", type=int, default=8)
    sync_mounts_parser.set_defaults(func=cmd_sync_mounts)

    sync_prices_parser = subparsers.add_parser("sync-prices", help="Sync TSM prices")
    sync_prices_parser.add_argument("--region", default=DEFAULT_REGION)
    sync_prices_parser.add_argument("--force", action="store_true")
    sync_prices_parser.add_argument("--missing-only", action="store_true")
    sync_prices_parser.add_argument("--limit", type=int)
    sync_prices_parser.add_argument("--expansion", action="append")
    sync_prices_parser.add_argument("--profession", action="append", choices=["herbalism", "mining", "skinning"])
    sync_prices_parser.add_argument("--item-id", action="append", type=int)
    sync_prices_parser.set_defaults(func=cmd_sync_prices)

    sync_auction_catalog_parser = subparsers.add_parser(
        "sync-auction-catalog",
        help="Sync item names used by the Blizzard Auction House search",
    )
    sync_auction_catalog_parser.add_argument("--region", default=DEFAULT_REGION)
    sync_auction_catalog_parser.add_argument("--force", action="store_true")
    sync_auction_catalog_parser.set_defaults(func=cmd_sync_auction_catalog)

    sync_auction_realms_parser = subparsers.add_parser(
        "sync-auction-realms",
        help="Sync Blizzard connected realm groups",
    )
    sync_auction_realms_parser.add_argument("--region", default=DEFAULT_REGION)
    sync_auction_realms_parser.set_defaults(func=cmd_sync_auction_realms)

    sync_auction_data_parser = subparsers.add_parser(
        "sync-auction-data",
        help="Sync current Blizzard Auction House data for connected realms",
    )
    sync_auction_data_parser.add_argument("--region", default=DEFAULT_REGION)
    sync_auction_data_parser.add_argument("--realm-slug", action="append")
    sync_auction_data_parser.add_argument("--limit-realms", type=int)
    sync_auction_data_parser.add_argument("--workers", type=int, default=4)
    sync_auction_data_parser.add_argument("--no-commodities", action="store_true")
    sync_auction_data_parser.add_argument("--force", action="store_true")
    sync_auction_data_parser.set_defaults(func=cmd_sync_auction_data)

    search_auctions_parser = subparsers.add_parser(
        "search-auctions",
        help="Search an item name and compare its EU connected realm prices",
    )
    search_auctions_parser.add_argument("--name", required=True)
    search_auctions_parser.add_argument("--region", default=DEFAULT_REGION)
    search_auctions_parser.add_argument("--limit", type=int, default=50)
    search_auctions_parser.add_argument("--max-rows", type=int, default=100)
    search_auctions_parser.add_argument("--json", action="store_true")
    search_auctions_parser.set_defaults(func=cmd_search_auctions)

    compare_parser = subparsers.add_parser("compare-expansions", help="Compare expansions")
    compare_parser.add_argument("--region", default=DEFAULT_REGION)
    compare_parser.add_argument("--top", type=int, default=5)
    compare_parser.set_defaults(func=cmd_compare_expansions)

    farmability_parser = subparsers.add_parser("compare-farmability", help="Compare farmability with rarity weighting")
    farmability_parser.add_argument("--region", default=DEFAULT_REGION)
    farmability_parser.add_argument("--top", type=int, default=5)
    farmability_parser.set_defaults(func=cmd_compare_farmability)

    currency_parser = subparsers.add_parser(
        "analyze-currency-for",
        help="Calculate gold per currency unit for Wowhead currency-for items",
    )
    currency_parser.add_argument("--item-id", type=int, default=163036)
    currency_parser.add_argument("--region", default=DEFAULT_REGION)
    currency_parser.add_argument("--top", type=int, default=0)
    currency_parser.add_argument("--force", action="store_true")
    currency_parser.add_argument("--json", action="store_true")
    currency_parser.set_defaults(func=cmd_analyze_currency_for)

    bootstrap_parser = subparsers.add_parser("bootstrap", help="Sync everything and build report")
    bootstrap_parser.add_argument("--profession", action="append", choices=["herbalism", "mining", "skinning"])
    bootstrap_parser.add_argument("--region", default=DEFAULT_REGION)
    bootstrap_parser.add_argument("--top", type=int, default=5)
    bootstrap_parser.add_argument("--force", action="store_true")
    bootstrap_parser.add_argument("--limit", type=int)
    bootstrap_parser.set_defaults(func=cmd_bootstrap)

    sync_recipes_parser = subparsers.add_parser("sync-recipes", help="Sync all profession recipes, items, and prices")
    sync_recipes_parser.add_argument("--region", default=DEFAULT_REGION)
    sync_recipes_parser.add_argument("--force", action="store_true")
    sync_recipes_parser.set_defaults(func=cmd_sync_recipes)

    analyze_recipes_parser = subparsers.add_parser("analyze-recipes", help="Analyze all local profession recipes")
    analyze_recipes_parser.add_argument("--region", default=DEFAULT_REGION)
    analyze_recipes_parser.add_argument("--top", type=int, default=0)
    analyze_recipes_parser.add_argument("--min-sale-rate", type=float, default=0.0)
    analyze_recipes_parser.add_argument("--sync", action="store_true")
    analyze_recipes_parser.add_argument("--force", action="store_true")
    analyze_recipes_parser.add_argument("--owned-only", action="store_true")
    analyze_recipes_parser.add_argument("--retail-root")
    analyze_recipes_parser.add_argument("--account-root")
    analyze_recipes_parser.set_defaults(func=cmd_analyze_recipes)

    discover_recipes_parser = subparsers.add_parser("discover-recipes", help="Discover created-by recipe graph from Wowhead item pages")
    discover_recipes_parser.add_argument("--item-id", action="append", type=int)
    discover_recipes_parser.add_argument("--max-depth", type=int, default=4)
    discover_recipes_parser.add_argument("--force", action="store_true")
    discover_recipes_parser.set_defaults(func=cmd_discover_recipes)

    analyze_discovered_parser = subparsers.add_parser("analyze-discovered", help="Analyze profitability from a discovered Wowhead recipe graph")
    analyze_discovered_parser.add_argument("--item-id", action="append", type=int, required=True)
    analyze_discovered_parser.add_argument("--region", default=DEFAULT_REGION)
    analyze_discovered_parser.add_argument("--max-depth", type=int, default=4)
    analyze_discovered_parser.add_argument("--top", type=int, default=20)
    analyze_discovered_parser.add_argument("--min-sale-rate", type=float, default=0.0)
    analyze_discovered_parser.add_argument("--sync", action="store_true")
    analyze_discovered_parser.add_argument("--force", action="store_true")
    analyze_discovered_parser.add_argument("--owned-only", action="store_true")
    analyze_discovered_parser.add_argument("--retail-root")
    analyze_discovered_parser.add_argument("--account-root")
    analyze_discovered_parser.set_defaults(func=cmd_analyze_discovered)

    sync_profession_recipes_parser = subparsers.add_parser(
        "sync-profession-recipes",
        help="Sync local profession recipe trees from Wowhead skill pages",
    )
    sync_profession_recipes_parser.add_argument(
        "--profession",
        action="append",
        choices=supported_recipe_professions(),
    )
    sync_profession_recipes_parser.add_argument("--force", action="store_true")
    sync_profession_recipes_parser.set_defaults(func=cmd_sync_profession_recipes)

    query_recipes_parser = subparsers.add_parser(
        "query-recipes",
        help="Query local profession recipe trees",
    )
    query_recipes_parser.add_argument("--item-id", type=int)
    query_recipes_parser.add_argument("--spell-id", type=int)
    query_recipes_parser.add_argument("--name")
    query_recipes_parser.add_argument(
        "--profession",
        action="append",
        choices=supported_recipe_professions(),
    )
    query_recipes_parser.add_argument("--max-depth", type=int, default=3)
    query_recipes_parser.add_argument("--limit", type=int, default=20)
    query_recipes_parser.add_argument("--json", action="store_true")
    query_recipes_parser.set_defaults(func=cmd_query_recipes)

    local_summary_parser = subparsers.add_parser("local-summary", help="Summarize local WoW account data from SavedVariables")
    local_summary_parser.add_argument("--retail-root")
    local_summary_parser.add_argument("--account-root")
    local_summary_parser.add_argument("--json", action="store_true")
    local_summary_parser.set_defaults(func=cmd_local_summary)

    local_items_parser = subparsers.add_parser("local-items", help="Find item counts across local character data")
    local_items_parser.add_argument("--retail-root")
    local_items_parser.add_argument("--account-root")
    local_items_parser.add_argument("--item-id", type=int)
    local_items_parser.add_argument("--name")
    local_items_parser.add_argument("--all", action="store_true")
    local_items_parser.add_argument("--json", action="store_true")
    local_items_parser.set_defaults(func=cmd_local_items)

    local_prices_parser = subparsers.add_parser("local-prices", help="Lookup local TSM AppHelper pricing data for one item id")
    local_prices_parser.add_argument("--retail-root")
    local_prices_parser.add_argument("--account-root")
    local_prices_parser.add_argument("--item-id", type=int, required=True)
    local_prices_parser.add_argument("--json", action="store_true")
    local_prices_parser.set_defaults(func=cmd_local_prices)

    local_recipe_owners_parser = subparsers.add_parser(
        "local-recipe-owners",
        help="List local characters who know a specific recipe spell",
    )
    local_recipe_owners_parser.add_argument("--retail-root")
    local_recipe_owners_parser.add_argument("--account-root")
    local_recipe_owners_parser.add_argument("--spell-id", type=int, required=True)
    local_recipe_owners_parser.add_argument("--profession")
    local_recipe_owners_parser.add_argument("--save-name")
    local_recipe_owners_parser.add_argument("--json", action="store_true")
    local_recipe_owners_parser.set_defaults(func=cmd_local_recipe_owners)

    account_pipeline_parser = subparsers.add_parser(
        "account-pipeline",
        help="Build a compact local account digest from WoW SavedVariables and TSM AppHelper",
    )
    account_pipeline_parser.add_argument("--retail-root")
    account_pipeline_parser.add_argument("--account-root")
    account_pipeline_parser.add_argument("--top", type=int, default=10)
    account_pipeline_parser.add_argument("--json", action="store_true")
    account_pipeline_parser.add_argument(
        "--snapshot-json",
        action="store_true",
        help="Print the full normalized snapshot instead of the compact digest",
    )
    account_pipeline_parser.set_defaults(func=cmd_account_pipeline)

    plan_restock_parser = subparsers.add_parser(
        "plan-restock",
        help="Recommend restock buckets for a profession expansion from local TSM sale data",
    )
    plan_restock_parser.add_argument("--profession", required=True, choices=supported_recipe_professions())
    plan_restock_parser.add_argument("--expansion", required=True, help="Listview/expansion label such as 'Midnight'")
    plan_restock_parser.add_argument("--bucket", action="append", type=int, help="Override bucket list, may be repeated")
    plan_restock_parser.add_argument("--retail-root")
    plan_restock_parser.add_argument("--account-root")
    plan_restock_parser.add_argument("--json", action="store_true")
    plan_restock_parser.set_defaults(func=cmd_plan_restock)

    gui_parser = subparsers.add_parser("gui", help="Launch the Windows GUI")
    gui_parser.set_defaults(func=cmd_gui)

    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    return args.func(args)
