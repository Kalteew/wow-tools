from __future__ import annotations

import json
import re
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from wow_tools.config import ACCOUNT_DIR
from wow_tools.local_account import (
    _LOADDATA_RE,
    _aggregate_items,
    _decode_appdata_values,
    _extract_appdata_item_blob,
    _iter_appdata_rows,
    _parse_appdata_metadata,
    format_copper,
    format_timestamp,
    load_local_state,
    resolve_paths,
)
from wow_tools.lua_table import parse_lua_assignments

ITEM_ICON_RE = re.compile(r"\s*\|A:[^|]+\|a")


def build_account_pipeline(
    retail_root: str | Path | None = None,
    account_root: str | Path | None = None,
    *,
    top: int = 10,
) -> tuple[dict[str, Any], dict[str, Any]]:
    state = load_local_state(retail_root, account_root)
    saved_variables = Path(state["paths"]["saved_variables"])

    crafts = _load_optional_assignments(saved_variables / "DataStore_Crafts.lua").get("DataStore_Crafts_Characters", {})
    currencies = _load_optional_assignments(saved_variables / "DataStore_Currencies.lua")
    currency_chars = currencies.get("DataStore_Currencies_Characters", {})
    currency_max = currencies.get("DataStore_Currencies_Max", {})
    garrisons = _load_optional_assignments(saved_variables / "DataStore_Garrisons.lua")
    garrison_chars = garrisons.get("DataStore_Garrisons_Characters", {})
    garrison_missions = garrisons.get("DataStore_Garrisons_Missions", {})

    aggregated = _aggregate_items(state)
    item_ids = sorted(aggregated)
    price_index = load_local_price_index(item_ids, retail_root, account_root)

    character_rows = []
    for character in state["characters"]:
        index = character["index"]
        profession_rows = _extract_professions(crafts.get(index, {}))
        currency_rows = _extract_currencies(currency_chars.get(index, {}), currency_max)
        garrison_row = _extract_garrison(garrison_chars.get(index, {}), garrison_missions.get(index, {}))
        holdings = _build_character_holdings(aggregated, price_index, character["name"], top=top)
        character_rows.append(
            {
                "name": character["name"],
                "realm": character["realm"],
                "guid": character["guid"],
                "gold_copper": character["money_copper"],
                "gold_text": character["money_text"],
                "zone": character["zone"],
                "sub_zone": character["sub_zone"],
                "last_update_ts": character["last_update_ts"],
                "last_update": character["last_update"],
                "last_logout": character["last_logout"],
                "containers_last_update": character["containers_last_update"],
                "inventory_last_update": character["inventory_last_update"],
                "auctions_last_update": character["auctions_last_update"],
                "professions": profession_rows,
                "currencies": currency_rows,
                "garrison": garrison_row,
                "auction_listing_count": sum(
                    data.get("sources", {}).get("auctions", 0)
                    for data in (item["characters"].get(character["name"], {}) for item in aggregated.values())
                    if isinstance(data, dict)
                ),
                "top_holdings": holdings,
            }
        )

    item_rows = [_build_item_row(entry, price_index.get(item_id), top=top) for item_id, entry in sorted(aggregated.items())]
    item_rows.sort(
        key=lambda row: (
            row["value"]["liquid_inventory_score_copper"] or 0,
            row["value"]["inventory_value_copper"] or 0,
            row["total_count"],
        ),
        reverse=True,
    )

    generated_at = datetime.now(timezone.utc).astimezone().isoformat()
    snapshot = {
        "generated_at": generated_at,
        "paths": state["paths"],
        "character_count": len(character_rows),
        "tsm": state["tsm"],
        "characters": character_rows,
        "items": item_rows,
        "data_coverage": {
            "crafts_loaded": bool(crafts),
            "currencies_loaded": bool(currency_chars),
            "garrisons_loaded": bool(garrison_chars or garrison_missions),
            "priceable_item_count": sum(1 for row in item_rows if row["market"].get("preferred_price_copper") is not None),
        },
        "limitations": [
            "Only characters seen by the installed addons on this local WoW install are visible.",
            "Auction-only items may lack a resolved name when no local item link was captured.",
            "Local TSM sale metrics come from AppHelper snapshots and may lag behind the current AH state.",
        ],
    }
    digest = _build_digest(snapshot, top=top)
    return snapshot, digest


def save_account_pipeline(snapshot: dict[str, Any], digest: dict[str, Any]) -> dict[str, str]:
    ACCOUNT_DIR.mkdir(parents=True, exist_ok=True)
    snapshot_path = ACCOUNT_DIR / "account-snapshot.json"
    digest_path = ACCOUNT_DIR / "account-digest.json"
    markdown_path = ACCOUNT_DIR / "account-digest.md"
    snapshot_path.write_text(json.dumps(snapshot, ensure_ascii=False, indent=2), encoding="utf-8")
    digest_path.write_text(json.dumps(digest, ensure_ascii=False, indent=2), encoding="utf-8")
    markdown_path.write_text(render_account_digest(digest), encoding="utf-8")
    return {
        "snapshot_json": str(snapshot_path),
        "digest_json": str(digest_path),
        "digest_markdown": str(markdown_path),
    }


def render_account_digest(digest: dict[str, Any]) -> str:
    lines = [
        "Account Digest",
        f"- generated: {digest['generated_at']}",
        f"- visible characters: {digest['overview']['character_count']}",
        f"- total gold: {digest['overview']['total_gold_text']}",
        f"- estimated inventory value: {format_copper(digest['overview']['inventory_value_copper']) or '-'}",
        f"- estimated auction value: {format_copper(digest['overview']['auction_value_copper']) or '-'}",
        f"- TSM latest sync: {digest['freshness']['tsm_last_sync'] or 'unknown'}",
    ]
    if digest["freshness"]["stale_characters"]:
        lines.append(
            "- stale characters: "
            + ", ".join(
                f"{row['name']} ({row['last_update'] or 'unknown'})"
                for row in digest["freshness"]["stale_characters"]
            )
        )

    lines.append("")
    lines.append("Characters")
    for character in digest["characters"]:
        profession_text = ", ".join(_render_profession_brief(profession) for profession in character["professions"][:3]) or "no professions seen"
        lines.append(
            f"- {character['name']} ({character['realm']}): {character['gold_text']} | {profession_text} | "
            f"auctions={character['auction_listing_count']} | {character['last_update'] or 'unknown'}"
        )
        if character["top_holdings"]:
            lines.append("  top: " + "; ".join(_render_item_brief(item) for item in character["top_holdings"][:3]))

    lines.append("")
    lines.append("Top Liquid Inventory")
    for item in digest["highlights"]["top_liquid_inventory"]:
        lines.append(f"- {_render_item_brief(item)}")

    lines.append("")
    lines.append("Top Posted Auctions")
    if digest["highlights"]["top_posted_auctions"]:
        for item in digest["highlights"]["top_posted_auctions"]:
            lines.append(f"- {_render_item_brief(item)}")
    else:
        lines.append("- none with local pricing")

    return "\n".join(lines)


def load_local_price_index(
    item_ids: list[int],
    retail_root: str | Path | None = None,
    account_root: str | Path | None = None,
) -> dict[int, dict[str, Any]]:
    paths = resolve_paths(retail_root, account_root)
    appdata_path = Path(paths["tsm_appdata"])
    if not appdata_path.exists():
        return {}

    targets = set(item_ids)
    by_item: dict[int, dict[str, Any]] = {}

    for raw_line in appdata_path.read_text(encoding="utf-8", errors="replace").splitlines():
        match = _LOADDATA_RE.match(raw_line)
        if not match:
            continue
        tag, scope, payload = match.groups()
        if tag == "APP_INFO":
            continue

        metadata = _parse_appdata_metadata(payload)
        fields = _lua_array_to_list(metadata.get("fields", {}))
        item_blob = _extract_appdata_item_blob(payload)

        for item_string, raw_values in _iter_appdata_rows(item_blob):
            item_id = _item_id_from_item_string(item_string)
            if item_id is None or item_id not in targets:
                continue
            values = _decode_appdata_values(fields, raw_values)
            record = by_item.setdefault(item_id, {"datasets": {}})
            record["datasets"][tag] = {
                "scope": scope,
                "download_time_ts": metadata.get("downloadTime"),
                "download_time": format_timestamp(metadata.get("downloadTime")),
                "values": values,
            }

    for item_id, record in by_item.items():
        record["summary"] = _summarize_price_datasets(record["datasets"])

    return by_item


def _build_digest(snapshot: dict[str, Any], *, top: int) -> dict[str, Any]:
    total_gold = sum(character["gold_copper"] for character in snapshot["characters"])
    inventory_value = sum(row["value"]["inventory_value_copper"] or 0 for row in snapshot["items"])
    auction_value = sum(row["value"]["auction_value_copper"] or 0 for row in snapshot["items"])
    newest_character_ts = max((character["last_update_ts"] or 0 for character in snapshot["characters"]), default=0)
    stale_characters = [
        {"name": character["name"], "last_update": character["last_update"]}
        for character in snapshot["characters"]
        if newest_character_ts and character["last_update_ts"] and character["last_update_ts"] < newest_character_ts - 24 * 60 * 60
    ]
    highlights = {
        "top_liquid_inventory": [
            _compact_highlight_row(row, kind="inventory")
            for row in _top_rows(
                snapshot["items"],
                key=lambda row: row["value"]["liquid_inventory_score_copper"] or 0,
                limit=top,
                predicate=lambda row: row["value"]["inventory_count"] > 0,
            )
        ],
        "top_posted_auctions": [
            _compact_highlight_row(row, kind="auction")
            for row in _top_rows(
                snapshot["items"],
                key=lambda row: row["value"]["auction_value_copper"] or 0,
                limit=top,
                predicate=lambda row: (row["value"]["auction_count"] > 0) and ((row["value"]["auction_value_copper"] or 0) > 0),
            )
        ],
        "top_gold_characters": sorted(
            (
                {
                    "name": character["name"],
                    "realm": character["realm"],
                    "gold_copper": character["gold_copper"],
                    "gold_text": character["gold_text"],
                }
                for character in snapshot["characters"]
            ),
            key=lambda row: row["gold_copper"],
            reverse=True,
        )[:top],
    }
    return {
        "generated_at": snapshot["generated_at"],
        "paths": snapshot["paths"],
        "overview": {
            "character_count": snapshot["character_count"],
            "total_gold_copper": total_gold,
            "total_gold_text": format_copper(total_gold),
            "inventory_value_copper": inventory_value,
            "inventory_value_text": format_copper(inventory_value),
            "auction_value_copper": auction_value,
            "auction_value_text": format_copper(auction_value),
        },
        "freshness": {
            "tsm_last_sync": snapshot["tsm"].get("app_info", {}).get("last_sync"),
            "stale_characters": stale_characters,
        },
        "characters": [
            {
                "name": character["name"],
                "realm": character["realm"],
                "gold_copper": character["gold_copper"],
                "gold_text": character["gold_text"],
                "last_update": character["last_update"],
                "auction_listing_count": character["auction_listing_count"],
                "professions": character["professions"],
                "top_holdings": character["top_holdings"],
            }
            for character in sorted(snapshot["characters"], key=lambda row: row["gold_copper"], reverse=True)
        ],
        "highlights": highlights,
        "limitations": snapshot["limitations"],
        "data_coverage": snapshot["data_coverage"],
    }


def _build_character_holdings(
    aggregated: dict[int, dict[str, Any]],
    price_index: dict[int, dict[str, Any]],
    character_name: str,
    *,
    top: int,
) -> list[dict[str, Any]]:
    rows = []
    for item_id, entry in aggregated.items():
        character = entry["characters"].get(character_name)
        if not character:
            continue
        inventory_count = sum(character["sources"].get(source, 0) for source in ("bags", "bank", "reagents", "warbank"))
        auction_count = character["sources"].get("auctions", 0)
        if inventory_count <= 0 and auction_count <= 0:
            continue
        price_summary = price_index.get(item_id, {}).get("summary", {})
        preferred_price = price_summary.get("preferred_price_copper")
        total_value = preferred_price * (inventory_count + auction_count) if preferred_price is not None else None
        rows.append(
            {
                "item_id": item_id,
                "name": _item_label(entry.get("name"), item_id),
                "count": inventory_count + auction_count,
                "inventory_count": inventory_count,
                "auction_count": auction_count,
                "preferred_price_copper": preferred_price,
                "preferred_price_text": format_copper(preferred_price),
                "total_value_copper": total_value,
                "total_value_text": format_copper(total_value),
                "sale_rate": price_summary.get("sale_rate"),
            }
        )
    rows.sort(key=lambda row: (row["total_value_copper"] or 0, row["count"]), reverse=True)
    return rows[:top]


def _build_item_row(entry: dict[str, Any], price_record: dict[str, Any] | None, *, top: int) -> dict[str, Any]:
    price_summary = (price_record or {}).get("summary", {})
    inventory_count = sum(entry["sources"].get(source, 0) for source in ("bags", "bank", "reagents", "warbank"))
    auction_count = entry["sources"].get("auctions", 0)
    equipment_count = entry["sources"].get("equipment", 0)
    preferred_price = price_summary.get("preferred_price_copper")
    inventory_value = preferred_price * inventory_count if preferred_price is not None else None
    auction_value = preferred_price * auction_count if preferred_price is not None else None
    liquid_score = None
    if inventory_value is not None and price_summary.get("sale_rate") is not None:
        liquid_score = int(round(inventory_value * price_summary["sale_rate"]))
    character_rows = sorted(
        (
            {"name": row["name"], "count": row["total_count"], "sources": row["sources"]}
            for row in entry["characters"].values()
        ),
        key=lambda row: row["count"],
        reverse=True,
    )[:top]
    return {
        "item_id": entry["item_id"],
        "name": _item_label(entry.get("name"), entry["item_id"]),
        "total_count": entry["total_count"],
        "sources": entry["sources"],
        "characters": character_rows,
        "market": price_summary,
        "value": {
            "inventory_count": inventory_count,
            "auction_count": auction_count,
            "equipment_count": equipment_count,
            "inventory_value_copper": inventory_value,
            "inventory_value_text": format_copper(inventory_value),
            "auction_value_copper": auction_value,
            "auction_value_text": format_copper(auction_value),
            "liquid_inventory_score_copper": liquid_score,
            "liquid_inventory_score_text": format_copper(liquid_score),
        },
    }


def _extract_professions(raw: dict[str, Any]) -> list[dict[str, Any]]:
    professions = raw.get("Professions", {}) if isinstance(raw, dict) else {}
    ranks = raw.get("Ranks", {}) if isinstance(raw, dict) else {}
    rows: list[dict[str, Any]] = []
    for index, profession in sorted(((key, value) for key, value in professions.items() if isinstance(key, int)), key=lambda item: item[0]):
        if not isinstance(profession, dict):
            continue
        current, maximum = _decode_rank(ranks.get(index))
        rows.append(
            {
                "name": profession.get("Name"),
                "current_level_name": profession.get("CurrentLevelName"),
                "rank_current": current,
                "rank_max": maximum,
            }
        )
    return rows


def _extract_currencies(raw: dict[str, Any], currency_max: dict[Any, Any]) -> list[dict[str, Any]]:
    totals = raw.get("Totals", {}) if isinstance(raw, dict) else {}
    rows = []
    for currency_id, amount in sorted(
        ((int(key), int(value)) for key, value in totals.items() if isinstance(key, int) and value not in (None, 0)),
        key=lambda item: item[1],
        reverse=True,
    ):
        rows.append(
            {
                "currency_id": currency_id,
                "amount": amount,
                "max_amount": int(currency_max.get(currency_id, 0) or 0),
            }
        )
    return rows[:12]


def _extract_garrison(character_raw: dict[str, Any], mission_raw: dict[str, Any]) -> dict[str, Any]:
    return {
        "last_update": format_timestamp(character_raw.get("lastUpdate")) if isinstance(character_raw, dict) else None,
        "last_resource_collection": format_timestamp(character_raw.get("lastResourceCollection")) if isinstance(character_raw, dict) else None,
        "active_missions": _count_nested_array_entries(mission_raw.get("Active", {})) if isinstance(mission_raw, dict) else 0,
        "available_missions": _count_nested_array_entries(mission_raw.get("Available", {})) if isinstance(mission_raw, dict) else 0,
    }


def _count_nested_array_entries(value: Any) -> int:
    if not isinstance(value, dict):
        return 0
    total = 0
    for _, child in sorted(((key, item) for key, item in value.items() if isinstance(key, int)), key=lambda row: row[0]):
        if isinstance(child, dict):
            total += len([item for key, item in child.items() if isinstance(key, int)])
        else:
            total += 1
    return total


def _decode_rank(value: Any) -> tuple[int | None, int | None]:
    if not isinstance(value, int):
        return None, None
    return value & 0xFFFF, value >> 16


def _item_label(name: str | None, item_id: int) -> str:
    return ITEM_ICON_RE.sub("", name) if name else f"Item {item_id}"


def _summarize_price_datasets(datasets: dict[str, dict[str, Any]]) -> dict[str, Any]:
    commodity_data = datasets.get("AUCTIONDB_COMMODITY_DATA", {}).get("values", {})
    commodity_scan = datasets.get("AUCTIONDB_COMMODITY_SCAN_STAT", {}).get("values", {})
    noncommodity_data = datasets.get("AUCTIONDB_NON_COMMODITY_DATA", {}).get("values", {})
    noncommodity_scan = datasets.get("AUCTIONDB_NON_COMMODITY_SCAN_STAT", {}).get("values", {})
    region_stat = datasets.get("AUCTIONDB_REGION_STAT", {}).get("values", {})
    region_sale = datasets.get("AUCTIONDB_REGION_SALE", {}).get("values", {})
    historical = datasets.get("AUCTIONDB_REGION_HISTORICAL", {}).get("values", {})
    commodity_historical = datasets.get("AUCTIONDB_COMMODITY_HISTORICAL", {}).get("values", {})
    noncommodity_historical = datasets.get("AUCTIONDB_NON_COMMODITY_HISTORICAL", {}).get("values", {})
    market_value = (
        commodity_scan.get("marketValue")
        or commodity_data.get("marketValueRecent")
        or noncommodity_scan.get("marketValue")
        or noncommodity_data.get("marketValueRecent")
        or region_stat.get("regionMarketValue")
    )
    min_buyout = commodity_data.get("minBuyout") or noncommodity_data.get("minBuyout")
    preferred_price = (
        min_buyout
        or market_value
        or region_stat.get("regionMarketValue")
        or historical.get("regionHistorical")
        or commodity_historical.get("historical")
        or noncommodity_historical.get("historical")
    )
    return {
        "is_commodity": bool(commodity_data or commodity_scan),
        "preferred_price_copper": preferred_price,
        "preferred_price_text": format_copper(preferred_price),
        "market_value_copper": market_value,
        "market_value_text": format_copper(market_value),
        "min_buyout_copper": min_buyout,
        "min_buyout_text": format_copper(min_buyout),
        "region_sale_avg_copper": region_sale.get("regionSale"),
        "region_sale_avg_text": format_copper(region_sale.get("regionSale")),
        "sale_rate": _decode_scaled_metric(region_sale.get("regionSalePercent")),
        "sold_per_day": _decode_scaled_metric(region_sale.get("regionSoldPerDay")),
        "dataset_scope": (
            datasets.get("AUCTIONDB_COMMODITY_DATA", {}).get("scope")
            or datasets.get("AUCTIONDB_NON_COMMODITY_DATA", {}).get("scope")
            or datasets.get("AUCTIONDB_REGION_STAT", {}).get("scope")
        ),
    }


def _decode_scaled_metric(value: Any) -> float | None:
    if not isinstance(value, int):
        return None
    return round(value / 1000.0, 3)


def _item_id_from_item_string(item_string: str) -> int | None:
    if item_string.startswith("i:"):
        item_string = item_string[2:]
    head = item_string.split(":", 1)[0]
    return int(head) if head.isdigit() else None


def _load_optional_assignments(path: Path) -> dict[str, Any]:
    if not path.exists():
        return {}
    return parse_lua_assignments(path.read_text(encoding="utf-8", errors="replace"))


def _lua_array_to_list(value: Any) -> list[Any]:
    if not isinstance(value, dict):
        return []
    return [item for _, item in sorted(((key, item) for key, item in value.items() if isinstance(key, int)), key=lambda row: row[0])]


def _top_rows(rows: list[dict[str, Any]], *, key, limit: int, predicate=None) -> list[dict[str, Any]]:
    filtered = rows if predicate is None else [row for row in rows if predicate(row)]
    return sorted(filtered, key=key, reverse=True)[:limit]


def _render_profession_brief(profession: dict[str, Any]) -> str:
    rank = ""
    if profession.get("rank_current") is not None and profession.get("rank_max") is not None:
        rank = f" {profession['rank_current']}/{profession['rank_max']}"
    tier = f" [{profession['current_level_name']}]" if profession.get("current_level_name") else ""
    return f"{profession.get('name') or 'Unknown'}{rank}{tier}"


def _render_item_brief(item: dict[str, Any]) -> str:
    count = item.get("count", item.get("total_count", 0))
    bits = [f"{item['name']} x{count}"]
    total_value_text = item.get("total_value_text")
    value_block = item.get("value", {}) if isinstance(item.get("value"), dict) else {}
    if not total_value_text:
        if (value_block.get("inventory_count") or 0) > 0:
            total_value_text = value_block.get("inventory_value_text")
        elif (value_block.get("auction_count") or 0) > 0:
            total_value_text = value_block.get("auction_value_text")
        else:
            total_value_text = value_block.get("inventory_value_text") or value_block.get("auction_value_text")
    if total_value_text:
        bits.append(total_value_text)
    sale_rate = item.get("sale_rate")
    if sale_rate is None and isinstance(item.get("market"), dict):
        sale_rate = item["market"].get("sale_rate")
    if sale_rate is not None:
        bits.append(f"sale_rate={sale_rate:.3f}")
    return " | ".join(bits)


def _compact_highlight_row(row: dict[str, Any], *, kind: str) -> dict[str, Any]:
    value = row.get("value", {})
    market = row.get("market", {})
    if kind == "auction":
        count = value.get("auction_count", 0)
        total_value_copper = value.get("auction_value_copper")
        total_value_text = value.get("auction_value_text")
    else:
        count = value.get("inventory_count", 0)
        total_value_copper = value.get("inventory_value_copper")
        total_value_text = value.get("inventory_value_text")
    return {
        "item_id": row["item_id"],
        "name": row["name"],
        "count": count,
        "total_value_copper": total_value_copper,
        "total_value_text": total_value_text,
        "sale_rate": market.get("sale_rate"),
    }
