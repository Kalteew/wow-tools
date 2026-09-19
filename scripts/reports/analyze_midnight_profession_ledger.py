#!/usr/bin/env python3
"""Analyse the Midnight profession-gear stock and TSM ledger.

The report is deliberately account-wide: inter-realm flips are stored under
multiple realm keys in TSM, so restricting the analysis to Yayag/Hyjal would
hide most of the strategy.

The TSM ledger does not persist the tooltip text for every tool.  The report
therefore exposes two cleaned views:

* operational: ilvl >= 232, and only explicitly known Crafting Speed is
  removed; an unknown tool stat is kept, as requested by the user;
* strict: the same rule, but an unknown tool stat is shown separately instead
  of being counted as definitely sellable.

YayaWeeklyTracker's latest Warband-bank snapshot is used when it contains the
exact ilvl/stat tooltip result.  This is the only local source that can
recover Crafting Speed reliably for a stored item link.
"""

from __future__ import annotations

import argparse
import csv
import io
import json
import re
import statistics
import sys
from collections import Counter, defaultdict, deque
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

REPO_ROOT = Path(__file__).resolve().parents[2]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from wow_tools.account_pipeline import (  # noqa: E402
    _LOADDATA_RE,
    _decode_scaled_metric,
    _decode_appdata_values,
    _extract_appdata_item_blob,
    _iter_appdata_rows,
    _item_id_from_item_string,
    _lua_array_to_list,
    _parse_appdata_metadata,
    resolve_paths,
)
from wow_tools.lua_table import parse_lua_assignments  # noqa: E402


DEFAULT_RETAIL_ROOT = Path(r"C:\Program Files (x86)\World of Warcraft\_retail_")
DEFAULT_ACCOUNT_ROOT = DEFAULT_RETAIL_ROOT / "WTF" / "Account" / "417185157#1"
DEFAULT_OUTPUT_DIR = REPO_ROOT / "outputs"
COMMISSION = 0.05

# These are the Midnight profession equipment IDs present in the local TSM /
# addon catalog.  Accessories are intentionally not split by stat: they have
# no random secondary profession stat.
TOOL_IDS = (
    set(range(237946, 237949))
    | set(range(237950, 237953))
    | set(range(238009, 238021))
    | set(range(244174, 244178))
    | {244707, 244708, 244711, 244712, 244713, 244714, 244717, 244718}
    | set(range(245775, 245781))
)
ACCESSORY_IDS = (
    set(range(239635, 239647))
    | set(range(240955, 240961))
    | set(range(244615, 244631))
    | {244709, 244710, 244715, 244716, 244719, 244720}
)
GEAR_IDS = TOOL_IDS | ACCESSORY_IDS

RANK_BONUSES = {12498, 12499, 12500, 12501, 12502}
MAX_RANK_BONUS = 12502
RANK_LEVEL_ADD = {12498: 0, 12499: 6, 12500: 12, 12501: 19, 12502: 26}
CRAFTING_SPEED = "deftness"
STAT_FROM_BONUS = {8952: "resourcefulness", 8953: "multicrafting"}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--retail-root", type=Path, default=DEFAULT_RETAIL_ROOT)
    parser.add_argument("--account-root", type=Path, default=DEFAULT_ACCOUNT_ROOT)
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUTPUT_DIR)
    parser.add_argument("--commission", type=float, default=COMMISSION)
    parser.add_argument("--price-realm", default="Hyjal", help="Royaume local servant de référence pour la valorisation.")
    parser.add_argument("--quiet", action="store_true")
    return parser.parse_args()


def as_int(value: Any, default: int = 0) -> int:
    try:
        return int(value)
    except (TypeError, ValueError):
        return default


def normalize_item_string(value: str) -> str:
    value = str(value or "")
    return value if value.startswith("i:") else f"i:{value}"


def item_id_from_string(item_string: str) -> int | None:
    match = re.match(r"^i:(\d+)", item_string)
    return int(match.group(1)) if match else None


def parse_item_variant(item_string: str) -> dict[str, Any]:
    parts = item_string.split(":")
    item_id = item_id_from_string(item_string)
    result: dict[str, Any] = {
        "item_id": item_id,
        "bonus_ids": [],
        "modifiers": [],
        "modifier_29": None,
        "item_level_hint": None,
        "stat_hint": None,
        "has_variant_data": False,
    }
    if item_id is None or len(parts) < 4:
        return result
    stat_match = re.search(r":s:([^:]+)", item_string)
    if stat_match and stat_match.group(1) != "?":
        result["stat_hint"] = stat_match.group(1)
    # TSM compresses current holdings to i:<itemID>::i<itemLevel>.  This
    # keeps the ilvl, but intentionally drops the tool tooltip stat.
    if parts[3].startswith("i") and parts[3][1:].isdigit():
        result["item_level_hint"] = int(parts[3][1:])
        result["has_variant_data"] = True
        return result
    if not parts[3].isdigit():
        return result
    count = int(parts[3])
    bonus_values = parts[4 : 4 + count]
    result["bonus_ids"] = [int(value) for value in bonus_values if value.isdigit()]
    tail = parts[4 + count :]
    if tail and tail[0].isdigit():
        modifier_count = int(tail[0])
        values = tail[1 : 1 + modifier_count * 2]
        result["modifiers"] = [
            (int(values[index]), int(values[index + 1]))
            for index in range(0, len(values) - 1, 2)
            if values[index].isdigit() and values[index + 1].isdigit()
        ]
    result["modifier_29"] = next(
        (value for modifier_type, value in result["modifiers"] if modifier_type == 29),
        None,
    )
    result["has_variant_data"] = True
    return result


def parse_blizzard_link(link: str) -> dict[str, Any] | None:
    """Extract the same bonus/modifier information from a Blizzard item link."""
    match = re.search(r"\|Hitem:([^|]+)\|h", str(link or ""))
    if not match:
        return None
    raw = match.group(1)
    item_id_match = re.match(r"(\d+)", raw)
    if not item_id_match:
        return None
    item_id = int(item_id_match.group(1))
    marker = "::13:"
    marker_index = raw.find(marker)
    if marker_index < 0:
        return {"item_id": item_id, "bonus_ids": [], "modifiers": [], "modifier_29": None}
    tail = raw[marker_index + len(marker) :].split(":")
    if not tail or not tail[0].isdigit():
        return None
    count = int(tail[0])
    bonus_values = tail[1 : 1 + count]
    bonus_ids = [int(value) for value in bonus_values if value.isdigit()]
    modifier_tail = tail[1 + count :]
    modifiers: list[tuple[int, int]] = []
    if modifier_tail and modifier_tail[0].isdigit():
        modifier_count = int(modifier_tail[0])
        values = modifier_tail[1 : 1 + modifier_count * 2]
        modifiers = [
            (int(values[index]), int(values[index + 1]))
            for index in range(0, len(values) - 1, 2)
            if values[index].isdigit() and values[index + 1].isdigit()
        ]
    return {
        "item_id": item_id,
        "bonus_ids": bonus_ids,
        "modifiers": modifiers,
        "modifier_29": next((v for t, v in modifiers if t == 29), None),
    }


def load_tsm_database(path: Path) -> dict[str, Any]:
    assignments = parse_lua_assignments(path.read_text(encoding="utf-8", errors="replace"))
    database = assignments.get("TradeSkillMasterDB")
    if not isinstance(database, dict):
        raise ValueError(f"TradeSkillMasterDB absent: {path}")
    return database


def load_tsm_item_names(path: Path) -> dict[int, str]:
    if not path.exists():
        return {}
    assignments = parse_lua_assignments(path.read_text(encoding="utf-8", errors="replace"))
    info = assignments.get("TSMItemInfoDB") or {}
    names: dict[int, str] = {}
    for chunk_id, name_blob in (info.get("names") or {}).items():
        item_blob = (info.get("itemStrings") or {}).get(chunk_id, "")
        for item_string, name in zip(str(item_blob).split(chr(2)), str(name_blob).split(chr(2))):
            item_id = item_id_from_string(item_string)
            if item_id is not None and name:
                names[item_id] = str(name)
    return names


def load_tooltip_snapshot(path: Path) -> dict[tuple[int, tuple[int, ...], int | None], dict[str, Any]]:
    if not path.exists():
        return {}
    assignments = parse_lua_assignments(path.read_text(encoding="utf-8", errors="replace"))
    account = assignments.get("YayaWeeklyTrackerAccountDB") or {}
    snapshot = account.get("warbankSnapshot") or {}
    result: dict[tuple[int, tuple[int, ...], int | None], dict[str, Any]] = {}
    for raw_id, record in (snapshot.get("itemsByID") or {}).items():
        item_id = as_int(raw_id)
        for instance in (record.get("instances") or {}).values():
            parsed = parse_blizzard_link(instance.get("link", ""))
            if not parsed:
                continue
            key = (item_id, tuple(sorted(parsed["bonus_ids"])), parsed.get("modifier_29"))
            result[key] = {
                "item_level": as_int(instance.get("itemLevel"), 0) or None,
                "stat_key": instance.get("statKey"),
                "stat_resolved": bool(instance.get("statResolved")),
            }
    return result


def canonical_item_string(parsed: dict[str, Any]) -> str:
    bonus_ids = parsed.get("bonus_ids") or []
    modifiers = parsed.get("modifiers") or []
    parts = [f"i:{parsed['item_id']}", "", str(len(bonus_ids)), *[str(value) for value in bonus_ids]]
    if modifiers:
        parts.extend([str(len(modifiers)), *[str(value) for pair in modifiers for value in pair]])
    return ":".join(parts)


def load_warbank_snapshot_rows(path: Path) -> list[dict[str, Any]]:
    if not path.exists():
        return []
    assignments = parse_lua_assignments(path.read_text(encoding="utf-8", errors="replace"))
    account = assignments.get("YayaWeeklyTrackerAccountDB") or {}
    snapshot = account.get("warbankSnapshot") or {}
    rows: list[dict[str, Any]] = []
    for raw_id, record in (snapshot.get("itemsByID") or {}).items():
        item_id = as_int(raw_id)
        if item_id not in GEAR_IDS:
            continue
        for instance in (record.get("instances") or {}).values():
            parsed = parse_blizzard_link(instance.get("link", ""))
            if not parsed:
                continue
            rows.append(
                {
                    "owner": "Warband bank",
                    "location": "warbank",
                    "item_string": canonical_item_string(parsed),
                    "item_id": item_id,
                    "quantity": max(1, as_int(instance.get("stackCount"), 1)),
                }
            )
    return rows


def load_stat_census_rows(path: Path) -> list[dict[str, Any]]:
    """Load the addon-side current stock census when it has a tooltip stat."""
    if not path.exists():
        return []
    assignments = parse_lua_assignments(path.read_text(encoding="utf-8", errors="replace"))
    database = assignments.get("YayaQueueDB") or {}
    characters = ((database.get("statCensus") or {}).get("characters") or {})
    scope_map = {"bags": "bag", "auctions": "auction", "mail": "mail", "bank": "bank"}
    rows: list[dict[str, Any]] = []
    for character_key, character in characters.items():
        if "-" not in str(character_key):
            continue
        character_name, realm = str(character_key).rsplit("-", 1)
        owner = f"{character_name} - {realm}"
        for source_scope, scope_data in (character.get("scopes") or {}).items():
            location = scope_map.get(source_scope)
            if not location:
                continue
            for raw_key, raw_quantity in (scope_data.get("counts") or {}).items():
                match = re.match(r"(\d+):(\d+):(.+)", str(raw_key))
                if not match:
                    continue
                item_id, item_level, stat_key = int(match.group(1)), int(match.group(2)), match.group(3)
                if item_id not in GEAR_IDS or as_int(raw_quantity) <= 0:
                    continue
                pseudo = f"i:{item_id}::i{item_level}:s:{stat_key}"
                rows.append(
                    {
                        "owner": owner,
                        "location": location,
                        "item_string": pseudo,
                        "item_id": item_id,
                        "quantity": as_int(raw_quantity),
                        "stat_key": None if stat_key == "?" else stat_key,
                        "item_level": item_level,
                    }
                )
    return rows


def replace_with_stat_census(
    holdings: list[dict[str, Any]],
    census_rows: list[dict[str, Any]],
) -> list[dict[str, Any]]:
    """Replace only the portion of TSM stock covered by the addon census."""
    if not census_rows:
        return holdings

    def owner_key(owner: str) -> str:
        parts = owner.split(" - ")
        return f"{parts[0]} - {parts[-1]}" if len(parts) >= 2 else owner

    available_exact: dict[tuple[str, str, int, int], int] = defaultdict(int)
    available_base: dict[tuple[str, str, int], int] = defaultdict(int)
    for row in holdings:
        parsed = parse_item_variant(row["item_string"])
        item_level = parsed.get("item_level_hint")
        base = (owner_key(row["owner"]), row["location"], row["item_id"])
        available_base[base] += row["quantity"]
        if item_level is not None:
            available_exact[(*base, item_level)] += row["quantity"]

    census_exact: dict[tuple[str, str, int, int], int] = defaultdict(int)
    census_base: dict[tuple[str, str, int], int] = defaultdict(int)
    for row in census_rows:
        exact = (row["owner"], row["location"], row["item_id"], row["item_level"])
        base = exact[:3]
        census_exact[exact] += row["quantity"]
        census_base[base] += row["quantity"]

    consumed_exact: dict[tuple[str, str, int, int], int] = defaultdict(int)
    consumed_base: dict[tuple[str, str, int], int] = defaultdict(int)
    output: list[dict[str, Any]] = []
    for row in holdings:
        parsed = parse_item_variant(row["item_string"])
        item_level = parsed.get("item_level_hint")
        base = (owner_key(row["owner"]), row["location"], row["item_id"])
        if item_level is not None:
            key = (*base, item_level)
            target = min(available_exact[key], census_exact[key])
            used = min(row["quantity"], max(0, target - consumed_exact[key]))
            consumed_exact[key] += used
        else:
            target = min(available_base[base], census_base[base])
            used = min(row["quantity"], max(0, target - consumed_base[base]))
            consumed_base[base] += used
        if used < row["quantity"]:
            residual = dict(row)
            residual["quantity"] = row["quantity"] - used
            output.append(residual)

    emitted_exact: dict[tuple[str, str, int, int], int] = defaultdict(int)
    emitted_base: dict[tuple[str, str, int], int] = defaultdict(int)
    for census_row in census_rows:
        key = (census_row["owner"], census_row["location"], census_row["item_id"], census_row["item_level"])
        base = key[:3]
        exact_capacity = min(available_exact[key], census_exact[key])
        if exact_capacity:
            qty_total = min(census_row["quantity"], exact_capacity - emitted_exact[key])
            emitted_exact[key] += max(0, qty_total)
        else:
            base_capacity = min(available_base[base], census_base[base])
            qty_total = min(census_row["quantity"], base_capacity - emitted_base[base])
            emitted_base[base] += max(0, qty_total)
        # The pseudo string is the same for multiple stats; make the stat
        # recoverable through a private field consumed by classify_item below.
        if qty_total > 0:
            exact = dict(census_row)
            exact["quantity"] = qty_total
            output.append(exact)
    return output


def load_names_and_snapshot(account_root: Path) -> tuple[
    dict[int, str],
    dict[tuple[int, tuple[int, ...], int | None], dict[str, Any]],
    list[dict[str, Any]],
    list[dict[str, Any]],
]:
    saved = account_root / "SavedVariables"
    return (
        load_tsm_item_names(saved / "TradeSkillMaster.lua"),
        load_tooltip_snapshot(saved / "YayaWeeklyTracker.lua"),
        load_warbank_snapshot_rows(saved / "YayaWeeklyTracker.lua"),
        load_stat_census_rows(saved / "YayaQueue.lua"),
    )


def load_events(database: dict[str, Any]) -> list[dict[str, Any]]:
    events: list[dict[str, Any]] = []
    for key, raw in database.items():
        if not isinstance(key, str) or "@internalData@csv" not in key or not isinstance(raw, str):
            continue
        realm_match = re.match(r"r@(.*)@internalData@csv(Buys|Sales)$", key)
        if not realm_match:
            continue
        realm, kind = realm_match.groups()
        for row in csv.DictReader(io.StringIO(raw)):
            if row.get("source") != "Auction":
                continue
            item_string = normalize_item_string(row.get("itemString", "")) if row.get("itemString") else ""
            item_id = item_id_from_string(item_string)
            if not item_string or item_id not in GEAR_IDS:
                continue
            quantity = as_int(row.get("quantity"))
            timestamp = as_int(row.get("time"))
            if quantity <= 0 or timestamp <= 0:
                continue
            unit_price = as_int(row.get("price"))
            events.append(
                {
                    "kind": "buy" if kind == "Buys" else "sale",
                    "time": timestamp,
                    "realm": realm,
                    "player": row.get("player"),
                    "item_string": item_string,
                    "item_id": item_id,
                    "quantity": quantity,
                    "unit_price_copper": unit_price,
                    "total_copper": quantity * unit_price,
                }
            )
    events.sort(key=lambda row: (row["time"], 0 if row["kind"] == "buy" else 1))
    return events


def load_holdings(database: dict[str, Any]) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for key, raw in database.items():
        if not isinstance(key, str) or not key.endswith("Quantity") or not isinstance(raw, dict):
            continue
        if "@internalData@" not in key:
            continue
        prefix, location = key.split("@internalData@", 1)
        if location not in {"bagQuantity", "auctionQuantity", "bankQuantity", "mailQuantity", "warbankQuantity"}:
            continue
        owner = prefix[2:] if prefix.startswith("s@") else "Warband bank"
        for raw_item_string, raw_quantity in raw.items():
            quantity = as_int(raw_quantity)
            item_string = normalize_item_string(str(raw_item_string))
            item_id = item_id_from_string(item_string)
            if quantity > 0 and item_id in GEAR_IDS:
                rows.append(
                    {
                        "owner": owner,
                        "location": location.removesuffix("Quantity"),
                        "item_string": item_string,
                        "item_id": item_id,
                        "quantity": quantity,
                    }
                )
    return rows


def classify_item(
    item_string: str,
    tooltip_snapshot: dict[tuple[int, tuple[int, ...], int | None], dict[str, Any]],
) -> dict[str, Any]:
    parsed = parse_item_variant(item_string)
    item_id = parsed["item_id"]
    item_type = "tool" if item_id in TOOL_IDS else "accessory" if item_id in ACCESSORY_IDS else None
    bonus_ids = tuple(sorted(parsed["bonus_ids"]))
    snapshot = tooltip_snapshot.get((item_id, bonus_ids, parsed.get("modifier_29")))
    if snapshot is None:
        # Some normalized strings omit extra modifiers.  Fall back to the
        # exact bonus set only when it identifies one unique snapshot result.
        candidates = [
            value
            for (candidate_id, candidate_bonuses, _), value in tooltip_snapshot.items()
            if candidate_id == item_id and candidate_bonuses == bonus_ids
        ]
        if len(candidates) == 1:
            snapshot = candidates[0]

    bonus_set = set(parsed["bonus_ids"])
    item_level = snapshot.get("item_level") if snapshot else parsed.get("item_level_hint")
    if item_level is None:
        rank_bonus = next((bonus for bonus in RANK_BONUSES if bonus in bonus_set), None)
        if 12253 in bonus_set:
            item_level = 206 + (RANK_LEVEL_ADD.get(rank_bonus, 0) if rank_bonus is not None else 0)
        elif 12252 in bonus_set:
            item_level = 180 + (RANK_LEVEL_ADD.get(rank_bonus, 0) if rank_bonus is not None else 0)
        elif rank_bonus is not None:
            item_level = RANK_LEVEL_ADD[rank_bonus]

    if item_level is None:
        ilvl_state = "unknown"
    elif item_level >= 232:
        ilvl_state = "gte_232"
    else:
        ilvl_state = "lt_232"

    stat_key = parsed.get("stat_hint") or (snapshot.get("stat_key") if snapshot else None)
    if stat_key is None:
        for bonus_id, candidate in STAT_FROM_BONUS.items():
            if bonus_id in bonus_set:
                stat_key = candidate
                break
    stat_state = "not_applicable" if item_type == "accessory" else (
        "crafting_speed" if stat_key == CRAFTING_SPEED else "known_non_crafting_speed" if stat_key else "unknown"
    )

    if ilvl_state == "lt_232":
        operational_bucket = strict_bucket = "polluting_ilvl_lt_232"
    elif ilvl_state == "unknown":
        operational_bucket = strict_bucket = "unknown_ilvl"
    elif item_type == "accessory":
        operational_bucket = strict_bucket = "relevant"
    elif stat_state == "crafting_speed":
        operational_bucket = strict_bucket = "polluting_crafting_speed"
    elif stat_state == "unknown":
        operational_bucket = "relevant"
        strict_bucket = "unknown_tool_stat"
    else:
        operational_bucket = strict_bucket = "relevant"

    return {
        "item_id": item_id,
        "item_type": item_type,
        "item_level": item_level,
        "ilvl_state": ilvl_state,
        "stat_key": stat_key,
        "stat_state": stat_state,
        "operational_bucket": operational_bucket,
        "strict_bucket": strict_bucket,
        "bonus_ids": list(parsed["bonus_ids"]),
        "modifier_29": parsed.get("modifier_29"),
    }


def load_exact_price_index(item_ids: set[int], retail_root: Path, account_root: Path) -> dict[str, dict[str, Any]]:
    """Load AppHelper prices by exact item string and scope.

    The generic account pipeline intentionally aggregates by base item ID. That
    is not safe here: the same profession item ID has several ilvl variants.
    """
    appdata_path = Path(resolve_paths(retail_root, account_root)["tsm_appdata"])
    if not appdata_path.exists():
        return {}
    by_item_string: dict[str, dict[str, Any]] = {}
    for raw_line in appdata_path.read_text(encoding="utf-8", errors="replace").splitlines():
        match = _LOADDATA_RE.match(raw_line)
        if not match:
            continue
        tag, scope, payload = match.groups()
        if tag == "APP_INFO":
            continue
        metadata = _parse_appdata_metadata(payload)
        fields = _lua_array_to_list(metadata.get("fields", {}))
        for raw_item_string, raw_values in _iter_appdata_rows(_extract_appdata_item_blob(payload)):
            if _item_id_from_item_string(raw_item_string) not in item_ids:
                continue
            item_string = normalize_item_string(raw_item_string)
            record = by_item_string.setdefault(item_string, {"scopes": {}})
            scope_record = record["scopes"].setdefault(scope, {"datasets": {}})
            scope_record["datasets"][tag] = {
                "download_time_ts": metadata.get("downloadTime"),
                "download_time": metadata.get("downloadTime"),
                "values": _decode_appdata_values(fields, raw_values),
            }
    return by_item_string


def _scope_values(record: dict[str, Any], scope: str, tag: str) -> dict[str, Any]:
    return (((record.get("scopes") or {}).get(scope) or {}).get("datasets") or {}).get(tag, {}).get("values", {}) or {}


def variant_prices(
    record: dict[str, Any] | None,
    local_scope: str,
    fallback_records: list[dict[str, Any] | None] | None = None,
) -> dict[str, Any]:
    candidates = [record, *(fallback_records or [])]
    local_preferred = None
    local_found = False
    region_market_value = None
    region_sale_value = None
    region_sale_rate = None
    for candidate in candidates:
        if not candidate:
            continue
        local_data = _scope_values(candidate, local_scope, "AUCTIONDB_NON_COMMODITY_DATA")
        local_scan = _scope_values(candidate, local_scope, "AUCTIONDB_NON_COMMODITY_SCAN_STAT")
        local_historical = _scope_values(candidate, local_scope, "AUCTIONDB_NON_COMMODITY_HISTORICAL")
        region_market = _scope_values(candidate, "EU", "AUCTIONDB_REGION_STAT")
        region_sale = _scope_values(candidate, "EU", "AUCTIONDB_REGION_SALE")
        local_market = local_scan.get("marketValue") or local_data.get("marketValueRecent") or local_historical.get("historical")
        local_min_buyout = local_data.get("minBuyout")
        if not local_found and (local_min_buyout or local_market):
            local_preferred = local_min_buyout or local_market
            local_found = True
        if region_market_value is None and region_market.get("regionMarketValue"):
            region_market_value = region_market["regionMarketValue"]
        if region_sale_value is None and region_sale.get("regionSale"):
            region_sale_value = region_sale["regionSale"]
            region_sale_rate = _decode_scaled_metric(region_sale.get("regionSalePercent"))
    return {
        "local_preferred_copper": local_preferred,
        "local_scope": local_scope if local_found else None,
        "region_market_copper": region_market_value,
        "region_sale_avg_copper": region_sale_value,
        "region_sale_rate": region_sale_rate,
    }


def money(value: int | float | None) -> str:
    if value is None:
        return "n/d"
    return f"{value / 10000:,.2f} po".replace(",", " ")


def qty(value: int | float | None) -> str:
    return f"{int(value or 0):,}".replace(",", " ")


def pct(value: float | None) -> str:
    return "n/d" if value is None else f"{value * 100:.1f}%"


def variant_label(meta: dict[str, Any]) -> str:
    if meta["item_level"] is None:
        return "inconnu"
    return f"ilvl {meta['item_level']}" + (f" / {meta['stat_key']}" if meta["stat_key"] else "")


def empty_metric() -> dict[str, Any]:
    return {
        "purchases_qty": 0,
        "purchases_copper": 0,
        "sales_qty": 0,
        "revenue_copper": 0,
        "known_sale_qty": 0,
        "known_cost_copper": 0,
        "known_revenue_copper": 0,
        "unknown_sale_qty": 0,
        "delay_samples": [],
        "current_qty": 0,
        "current_value_copper": 0,
        "current_value_known": 0,
        "current_cost_basis_copper": 0,
        "current_cost_basis_known_qty": 0,
    }


def add_event_metric(metric: dict[str, Any], event: dict[str, Any], commission: float, cost_info: dict[str, Any] | None = None) -> None:
    if event["kind"] == "buy":
        metric["purchases_qty"] += event["quantity"]
        metric["purchases_copper"] += event["total_copper"]
        return
    metric["sales_qty"] += event["quantity"]
    metric["revenue_copper"] += event["total_copper"]
    if cost_info:
        known_qty = cost_info["known_qty"]
        metric["known_sale_qty"] += known_qty
        metric["unknown_sale_qty"] += cost_info["unknown_qty"]
        metric["known_cost_copper"] += cost_info["known_cost_copper"]
        metric["known_revenue_copper"] += known_qty * event["unit_price_copper"]
        metric["delay_samples"].extend([cost_info["delay_days"]] * known_qty)
    else:
        metric["unknown_sale_qty"] += event["quantity"]


def finalize_metric(metric: dict[str, Any], current_qty: int | None = None) -> dict[str, Any]:
    metric = dict(metric)
    metric["net_revenue_copper"] = round(metric["revenue_copper"] * (1 - COMMISSION))
    metric["known_net_revenue_copper"] = round(metric["known_revenue_copper"] * (1 - COMMISSION))
    metric["profit_after_commission_copper"] = metric["known_net_revenue_copper"] - metric["known_cost_copper"]
    metric["margin_on_known_sales"] = (
        metric["profit_after_commission_copper"] / metric["known_net_revenue_copper"]
        if metric["known_net_revenue_copper"]
        else None
    )
    stock = metric["current_qty"] if current_qty is None else current_qty
    metric["rotation_proxy"] = metric["sales_qty"] / stock if stock else None
    metric["sell_through_proxy"] = metric["sales_qty"] / (metric["sales_qty"] + stock) if metric["sales_qty"] + stock else None
    samples = metric.pop("delay_samples", [])
    metric["average_delay_days"] = sum(samples) / len(samples) if samples else None
    metric["median_delay_days"] = statistics.median(samples) if samples else None
    return metric


def build_report(
    database: dict[str, Any],
    names: dict[int, str],
    tooltip_snapshot: dict[tuple[int, tuple[int, ...], int | None], dict[str, Any]],
    tooltip_snapshot_rows: list[dict[str, Any]],
    stat_census_rows: list[dict[str, Any]],
    price_index: dict[str, dict[str, Any]],
    commission: float,
    price_realm: str,
) -> dict[str, Any]:
    events = load_events(database)
    holdings = replace_with_stat_census(load_holdings(database), stat_census_rows)
    # TSM compresses warband-bank gear to i:<id>::i<level>, while the tracker
    # snapshot keeps the exact item link, ilvl, and tooltip stat. Replace the
    # corresponding TSM warbank rows with that more precise snapshot.
    if tooltip_snapshot_rows:
        snapshot_ids = {row["item_id"] for row in tooltip_snapshot_rows}
        holdings = [
            row for row in holdings
            if not (row["location"] == "warbank" and row["item_id"] in snapshot_ids)
        ]
        holdings.extend(tooltip_snapshot_rows)
    metadata_cache: dict[str, dict[str, Any]] = {}

    def meta(item_string: str) -> dict[str, Any]:
        if item_string not in metadata_cache:
            metadata_cache[item_string] = classify_item(item_string, tooltip_snapshot)
        return metadata_cache[item_string]

    # FIFO by base item ID is the best available ledger match for inter-realm
    # trading. Exact item-string matching would lose sales when TSM collapsed a
    # link to a bare item ID, so the report states this limitation explicitly.
    queues: dict[int, deque[list[Any]]] = defaultdict(deque)
    sale_costs: dict[int, dict[str, Any]] = {}
    sale_allocations: dict[int, list[dict[str, Any]]] = {}
    for index, event in enumerate(events):
        if event["kind"] == "buy":
            queues[event["item_id"]].append(
                [event["quantity"], event["unit_price_copper"], event["time"], meta(event["item_string"])]
            )
            continue
        remaining = event["quantity"]
        known_qty = 0
        known_cost = 0
        delays: list[int] = []
        allocations: list[dict[str, Any]] = []
        while remaining and queues[event["item_id"]]:
            lot_qty, unit_cost, buy_time, lot_metadata = queues[event["item_id"]][0]
            used = min(remaining, lot_qty)
            known_qty += used
            known_cost += used * unit_cost
            delay_days = max(0, event["time"] - buy_time) // 86400
            delays.extend([delay_days] * used)
            allocations.append(
                {
                    "quantity": used,
                    "metadata": lot_metadata,
                    "known_cost_copper": used * unit_cost,
                    "delay_days": delay_days,
                }
            )
            remaining -= used
            lot_qty -= used
            if lot_qty:
                queues[event["item_id"]][0][0] = lot_qty
            else:
                queues[event["item_id"]].popleft()
        sale_allocations[index] = allocations
        sale_costs[index] = {
            "known_qty": known_qty,
            "unknown_qty": remaining,
            "known_cost_copper": known_cost,
            "delay_days": statistics.median(delays) if delays else 0,
        }

    # Allocate the remaining FIFO cost basis to the current stock by base item
    # ID. This is exact for a single variant and an approximation when variants
    # of the same item ID are mixed.
    cost_by_item: dict[int, dict[str, Any]] = {}
    for item_id, lots in queues.items():
        known_qty = sum(lot[0] for lot in lots)
        known_cost = sum(lot[0] * lot[1] for lot in lots)
        cost_by_item[item_id] = {
            "known_qty": known_qty,
            "known_cost_copper": known_cost,
            "unit_cost_copper": known_cost / known_qty if known_qty else None,
        }

    stock_variants: dict[str, dict[str, Any]] = {}
    for row in holdings:
        entry = stock_variants.setdefault(
            row["item_string"],
            {
                "item_string": row["item_string"],
                "item_id": row["item_id"],
                "quantity": 0,
                "locations": Counter(),
            },
        )
        entry["quantity"] += row["quantity"]
        entry["locations"][row["location"]] += row["quantity"]

    for entry in stock_variants.values():
        item_id = entry["item_id"]
        metadata = meta(entry["item_string"])
        fallback_records = [price_index.get(f"i:{item_id}")]
        if metadata.get("item_level"):
            fallback_records.insert(0, price_index.get(f"i:{item_id}::i{metadata['item_level']}"))
        prices = variant_prices(price_index.get(entry["item_string"]), price_realm, fallback_records)
        unit_price = prices["local_preferred_copper"]
        region_market_price = prices["region_market_copper"]
        region_sale_price = prices["region_sale_avg_copper"]
        cost = cost_by_item.get(item_id) or {}
        entry.update(
            {
                "name": names.get(item_id, f"Item {item_id}"),
                "metadata": metadata,
                "variant_label": variant_label(metadata),
                "locations": dict(entry["locations"]),
                "unit_price_copper": unit_price,
                "price_scope": prices["local_scope"],
                "market_value_copper": unit_price * entry["quantity"] if unit_price is not None else None,
                "region_market_unit_price_copper": region_market_price,
                "region_market_value_copper": region_market_price * entry["quantity"] if region_market_price is not None else None,
                "region_sale_avg_unit_price_copper": region_sale_price,
                "region_sale_avg_value_copper": region_sale_price * entry["quantity"] if region_sale_price is not None else None,
                "cost_basis_copper": round((cost.get("unit_cost_copper") or 0) * min(entry["quantity"], as_int(cost.get("known_qty")))) if cost.get("unit_cost_copper") is not None else None,
                "cost_basis_known": min(entry["quantity"], as_int(cost.get("known_qty"))),
            }
        )

    stock_by_item: dict[int, dict[str, Any]] = defaultdict(lambda: {"quantity": 0, "value": 0, "value_known": 0, "cost_basis": 0, "cost_known_qty": 0})
    for entry in stock_variants.values():
        aggregate = stock_by_item[entry["item_id"]]
        aggregate["quantity"] += entry["quantity"]
        if entry["market_value_copper"] is not None:
            aggregate["value"] += entry["market_value_copper"]
            aggregate["value_known"] += entry["market_value_copper"]
        if entry["cost_basis_copper"] is not None:
            aggregate["cost_basis"] += entry["cost_basis_copper"]
            aggregate["cost_known_qty"] += entry["cost_basis_known"]

    def current_for_bucket(bucket: str) -> dict[str, Any]:
        result = {"quantity": 0, "value_copper": 0, "priced_qty": 0, "cost_basis_copper": 0, "cost_known_qty": 0}
        for entry in stock_variants.values():
            if entry["metadata"][bucket] == "relevant":
                result["quantity"] += entry["quantity"]
                if entry["market_value_copper"] is not None:
                    result["value_copper"] += entry["market_value_copper"]
                    result["priced_qty"] += entry["quantity"]
                if entry["cost_basis_copper"] is not None:
                    result["cost_basis_copper"] += entry["cost_basis_copper"]
                    result["cost_known_qty"] += entry["cost_basis_known"]
        return result

    def stock_buckets(bucket_name: str, price_field: str = "market_value_copper") -> dict[str, Any]:
        result: dict[str, Any] = defaultdict(lambda: {"quantity": 0, "value_copper": 0, "priced_qty": 0, "cost_basis_copper": 0, "cost_known_qty": 0})
        for entry in stock_variants.values():
            bucket = entry["metadata"][bucket_name]
            row = result[bucket]
            row["quantity"] += entry["quantity"]
            value = entry.get(price_field)
            if value is not None:
                row["value_copper"] += value
                row["priced_qty"] += entry["quantity"]
            if entry["cost_basis_copper"] is not None:
                row["cost_basis_copper"] += entry["cost_basis_copper"]
                row["cost_known_qty"] += entry["cost_basis_known"]
        return dict(result)

    def current_valuation(price_field: str, bucket_name: str | None = None, bucket_value: str | None = None) -> dict[str, Any]:
        result = {"quantity": 0, "value_copper": 0, "priced_qty": 0, "cost_basis_copper": 0, "cost_known_qty": 0}
        for entry in stock_variants.values():
            if bucket_name and entry["metadata"].get(bucket_name) != bucket_value:
                continue
            result["quantity"] += entry["quantity"]
            value = entry.get(price_field)
            if value is not None:
                result["value_copper"] += value
                result["priced_qty"] += entry["quantity"]
            if entry["cost_basis_copper"] is not None:
                result["cost_basis_copper"] += entry["cost_basis_copper"]
                result["cost_known_qty"] += entry["cost_basis_known"]
        return result

    current_raw = current_valuation("market_value_copper")
    current_operational = current_valuation("market_value_copper", "operational_bucket", "relevant")
    current_strict = current_valuation("market_value_copper", "strict_bucket", "relevant")

    metric_views = {
        "raw": lambda m: True,
        "operational_relevant": lambda m: m["operational_bucket"] == "relevant",
        "strict_relevant": lambda m: m["strict_bucket"] == "relevant",
    }

    def collect_metrics(predicate, infer_unknown_sales: bool = False) -> dict[str, Any]:
        overall = empty_metric()
        by_type: dict[str, dict[str, Any]] = {"tool": empty_metric(), "accessory": empty_metric()}
        by_realm: dict[str, dict[str, Any]] = {}
        by_item: dict[int, dict[str, Any]] = {}
        for index, event in enumerate(events):
            metadata = meta(event["item_string"])
            if infer_unknown_sales and event["kind"] == "sale" and metadata["ilvl_state"] == "unknown":
                # TSM often stores a sale as bare i:<id>. Reuse the FIFO buy
                # lots to recover the classification whenever the purchased
                # lot itself had enough variant information.
                for allocation in sale_allocations.get(index, []):
                    allocation_metadata = allocation["metadata"]
                    if not predicate(allocation_metadata):
                        continue
                    slice_event = dict(event)
                    slice_event["quantity"] = allocation["quantity"]
                    slice_event["total_copper"] = allocation["quantity"] * event["unit_price_copper"]
                    slice_cost = {
                        "known_qty": allocation["quantity"],
                        "unknown_qty": 0,
                        "known_cost_copper": allocation["known_cost_copper"],
                        "delay_days": allocation["delay_days"],
                    }
                    add_event_metric(overall, slice_event, commission, slice_cost)
                    realm_metric = by_realm.setdefault(event["realm"], empty_metric())
                    add_event_metric(realm_metric, slice_event, commission, slice_cost)
                    category = allocation_metadata["item_type"]
                    add_event_metric(by_type[category], slice_event, commission, slice_cost)
                    item_metric = by_item.setdefault(event["item_id"], empty_metric())
                    add_event_metric(item_metric, slice_event, commission, slice_cost)
                continue
            if not predicate(metadata):
                continue
            add_event_metric(overall, event, commission, sale_costs.get(index))
            realm_metric = by_realm.setdefault(event["realm"], empty_metric())
            add_event_metric(realm_metric, event, commission, sale_costs.get(index))
            by_type[metadata["item_type"]] = by_type.get(metadata["item_type"], empty_metric())
            add_event_metric(by_type[metadata["item_type"]], event, commission, sale_costs.get(index))
            item_metric = by_item.setdefault(event["item_id"], empty_metric())
            add_event_metric(item_metric, event, commission, sale_costs.get(index))

        return {"overall": overall, "by_type": by_type, "by_realm": by_realm, "by_item": by_item}

    raw_metrics = collect_metrics(metric_views["raw"])
    operational_metrics = collect_metrics(metric_views["operational_relevant"], infer_unknown_sales=True)
    strict_metrics = collect_metrics(metric_views["strict_relevant"], infer_unknown_sales=True)

    current_for_view = {
        "raw": current_raw,
        "operational_relevant": current_operational,
        "strict_relevant": current_strict,
    }
    for view_name, bundle in (("raw", raw_metrics), ("operational_relevant", operational_metrics), ("strict_relevant", strict_metrics)):
        current = current_for_view[view_name]
        for metric in [bundle["overall"], *bundle["by_type"].values(), *bundle["by_item"].values()]:
            metric["current_qty"] = current["quantity"] if metric is bundle["overall"] else metric.get("current_qty", 0)
            metric["current_value_copper"] = current["value_copper"] if metric is bundle["overall"] else metric.get("current_value_copper", 0)
        bundle["overall"] = finalize_metric(bundle["overall"], current["quantity"])
        for category, metric in bundle["by_type"].items():
            current_category_qty = sum(
                entry["quantity"]
                for entry in stock_variants.values()
                if entry["metadata"]["item_type"] == category
                and ((view_name == "raw" and True) or (view_name == "operational_relevant" and entry["metadata"]["operational_bucket"] == "relevant") or (view_name == "strict_relevant" and entry["metadata"]["strict_bucket"] == "relevant"))
            )
            metric = finalize_metric(metric, current_category_qty)
            metric["current_qty"] = current_category_qty
            bundle["by_type"][category] = metric
        for realm, metric in bundle["by_realm"].items():
            bundle["by_realm"][realm] = finalize_metric(metric, 0)
        for item_id, metric in bundle["by_item"].items():
            current_item_qty = sum(
                entry["quantity"]
                for entry in stock_variants.values()
                if entry["item_id"] == item_id
                and ((view_name == "raw" and True) or (view_name == "operational_relevant" and entry["metadata"]["operational_bucket"] == "relevant") or (view_name == "strict_relevant" and entry["metadata"]["strict_bucket"] == "relevant"))
            )
            metric = finalize_metric(metric, current_item_qty)
            metric["current_qty"] = current_item_qty
            metric["name"] = names.get(item_id, f"Item {item_id}")
            metric["item_id"] = item_id
            bundle["by_item"][item_id] = metric

    # Add current stock financial data to the overall metrics.
    for bundle, current in ((raw_metrics, current_raw), (operational_metrics, current_operational), (strict_metrics, current_strict)):
        bundle["overall"].update(
            {
                "current_qty": current["quantity"],
                "current_value_copper": current["value_copper"],
                "current_value_priced_qty": current["priced_qty"],
                "current_cost_basis_copper": current["cost_basis_copper"],
                "current_cost_basis_known_qty": current["cost_known_qty"],
            }
        )

    generated_at = datetime.now(timezone.utc).astimezone().isoformat()
    period = {
        "from": min((event["time"] for event in events), default=None),
        "to": max((event["time"] for event in events), default=None),
        "from_iso": datetime.fromtimestamp(min(event["time"] for event in events), tz=timezone.utc).astimezone().isoformat() if events else None,
        "to_iso": datetime.fromtimestamp(max(event["time"] for event in events), tz=timezone.utc).astimezone().isoformat() if events else None,
        "event_count": len(events),
    }

    def serialize_stock_bucket(bucket_name: str, price_field: str = "market_value_copper") -> dict[str, Any]:
        return {
            bucket: {
                "quantity": row["quantity"],
                "value_copper": row["value_copper"],
                "priced_qty": row["priced_qty"],
                "cost_basis_copper": row["cost_basis_copper"],
                "cost_known_qty": row["cost_known_qty"],
            }
            for bucket, row in stock_buckets(bucket_name, price_field).items()
        }

    regional_valuations = {}
    for valuation_name, price_field in (
        ("local_preferred", "market_value_copper"),
        ("eu_region_market", "region_market_value_copper"),
        ("eu_region_sale_avg", "region_sale_avg_value_copper"),
    ):
        regional_valuations[valuation_name] = {
            "raw": current_valuation(price_field),
            "operational_relevant": current_valuation(price_field, "operational_bucket", "relevant"),
            "strict_relevant": current_valuation(price_field, "strict_bucket", "relevant"),
            "operational_buckets": serialize_stock_bucket("operational_bucket", price_field),
            "strict_buckets": serialize_stock_bucket("strict_bucket", price_field),
        }

    stock_rows = []
    for entry in sorted(stock_variants.values(), key=lambda row: (row["item_id"], row["item_string"])):
        row = dict(entry)
        row["locations"] = dict(row["locations"])
        stock_rows.append(row)

    return {
        "generated_at": generated_at,
        "scope": {
            "account_root": str(DEFAULT_ACCOUNT_ROOT),
            "realms": sorted({event["realm"] for event in events}),
            "source": "TSM Auction csvBuys/csvSales + current TSM quantities",
            "stock_locations": ["bags", "bank", "mail", "auctions", "warbank"],
            "commission": commission,
            "price_realm": price_realm,
        },
        "period": period,
        "definitions": {
            "accessory": "ilvl >= 232; no stat filter",
            "tool": "ilvl >= 232; Crafting Speed excluded",
            "operational_view": "unknown tool stats are retained because the ledger cannot prove they are Crafting Speed",
            "strict_view": "unknown tool stats are shown separately and excluded from definitely-relevant totals",
        },
        "current_stock": {
            "raw": current_raw,
            "operational_relevant": current_operational,
            "strict_relevant": current_strict,
            "operational_buckets": serialize_stock_bucket("operational_bucket"),
            "strict_buckets": serialize_stock_bucket("strict_bucket"),
            "regional_valuations": regional_valuations,
            "variants": stock_rows,
        },
        "ledger": {
            "raw": raw_metrics,
            "operational_relevant": operational_metrics,
            "strict_relevant": strict_metrics,
        },
        "notes": [
            "All currently tracked account realm keys are included because this is an inter-realm strategy.",
            "TSM current quantities are split by bags, bank, mail, posted auctions, and warband bank.",
            "FIFO costs are matched by base item ID across realms; exact variant matching is not always possible when TSM stored a bare item ID.",
            "The local stock valuation uses exact item-string prices from the selected realm; EU regionMarketValue and EU regionSale are included as inter-realm signals.",
            "YayaQueue statCensus and the latest YayaWeeklyTracker warbank snapshot resolve only the currently scanned subset of tool stats.",
            "Crafting Speed is only counted when the local tooltip snapshot resolves statKey=deftness. TSM alone does not store the tooltip stat for most tools.",
        ],
    }


def fmt_days(value: float | None) -> str:
    return "n/d" if value is None else f"{value:.1f} j"


def render_report(report: dict[str, Any]) -> str:
    current = report["current_stock"]
    valuations = current.get("regional_valuations", {})
    local_value = valuations.get("local_preferred", {})
    region_market_value = valuations.get("eu_region_market", {})
    region_sale_value = valuations.get("eu_region_sale_avg", {})
    raw = report["ledger"]["raw"]["overall"]
    operational = report["ledger"]["operational_relevant"]["overall"]
    strict = report["ledger"]["strict_relevant"]["overall"]
    lines = [
        "# Analyse du ledger — équipement de profession Midnight",
        "",
        f"Généré le {report['generated_at']}. Périmètre : compte TSM actif, tous royaumes suivis, transactions `Auction` uniquement. Prix local de référence : {report['scope'].get('price_realm', 'n/d')}.",
        f"Période du ledger : {report['period']['from_iso'] or 'n/d'} → {report['period']['to_iso'] or 'n/d'} ({qty(report['period']['event_count'])} lignes).",
        "",
        "## Résumé décisionnel",
        "",
        f"- Stock brut : **{qty(current['raw']['quantity'])} objets** ; valorisation locale **{money(local_value.get('raw', {}).get('value_copper'))}**, EU market **{money(region_market_value.get('raw', {}).get('value_copper'))}**, EU sale avg **{money(region_sale_value.get('raw', {}).get('value_copper'))}**.",
        f"- Stock vendable opérationnel : **{qty(current['operational_relevant']['quantity'])}** ; local **{money(local_value.get('operational_relevant', {}).get('value_copper'))}**, EU market **{money(region_market_value.get('operational_relevant', {}).get('value_copper'))}**, EU sale avg **{money(region_sale_value.get('operational_relevant', {}).get('value_copper'))}**.",
        f"- Coût d’achat FIFO retrouvé pour le stock : **{money(current['raw'].get('cost_basis_copper'))}** sur **{qty(current['raw'].get('cost_known_qty'))} objets** ; le reste est hors fenêtre de coût ou sans correspondance.",
        f"- Stock vendable certain : **{qty(current['strict_relevant']['quantity'])}** ; inconnus à vérifier : **{qty(current['strict_buckets'].get('unknown_tool_stat', {}).get('quantity', 0) + current['strict_buckets'].get('unknown_ilvl', {}).get('quantity', 0))}**.",
        f"- Achats / ventes pertinents opérationnels : **{qty(operational['purchases_qty'])} / {qty(operational['sales_qty'])}** ; CA **{money(operational['revenue_copper'])}** ; bénéfice connu après 5 % **{money(operational['profit_after_commission_copper'])}**.",
        f"- Rotation proxy du stock pertinent : **{operational['rotation_proxy']:.2f}×** ; délai médian achat→vente : **{fmt_days(operational['median_delay_days'])}**." if operational['rotation_proxy'] is not None else "- Rotation et délai : n/d.",
        "",
        "La vue opérationnelle applique exactement le filtre demandé autant que le ledger le permet : les outils 232 dont la stat n’est pas conservée par TSM restent inclus. La vue stricte retire ces outils inconnus afin de fournir une borne basse fiable.",
        "",
        "## Stock courant",
        "",
        "| Vue | Objets | Local | EU market | EU sale avg | Commentaire |",
        "|---|---:|---:|---:|---:|---|",
        f"| Brut | {qty(current['raw']['quantity'])} | {money(local_value.get('raw', {}).get('value_copper'))} | {money(region_market_value.get('raw', {}).get('value_copper'))} | {money(region_sale_value.get('raw', {}).get('value_copper'))} | tous accessoires/outils reconnus |",
        f"| Pertinent opérationnel | {qty(current['operational_relevant']['quantity'])} | {money(local_value.get('operational_relevant', {}).get('value_copper'))} | {money(region_market_value.get('operational_relevant', {}).get('value_copper'))} | {money(region_sale_value.get('operational_relevant', {}).get('value_copper'))} | 232+, CS explicitement identifié exclu |",
        f"| Pertinent certain | {qty(current['strict_relevant']['quantity'])} | {money(local_value.get('strict_relevant', {}).get('value_copper'))} | {money(region_market_value.get('strict_relevant', {}).get('value_copper'))} | {money(region_sale_value.get('strict_relevant', {}).get('value_copper'))} | outils à stat inconnue exclus |",
        "",
        "### Pollution / incertitude",
        "",
        "| Catégorie | Objets | Local | EU market | EU sale avg | Coût d’achat retrouvé |",
        "|---|---:|---:|---:|---:|---:|",
    ]
    buckets = current["operational_buckets"]
    for key, label in (
        ("polluting_ilvl_lt_232", "ilvl <232"),
        ("polluting_crafting_speed", "outils Crafting Speed identifiés"),
        ("unknown_ilvl", "variante ilvl inconnue"),
    ):
        row = buckets.get(key, {"quantity": 0, "value_copper": 0})
        local_row = local_value.get("operational_buckets", {}).get(key, {})
        market_row = region_market_value.get("operational_buckets", {}).get(key, {})
        sale_row = region_sale_value.get("operational_buckets", {}).get(key, {})
        lines.append(f"| {label} | {qty(row['quantity'])} | {money(local_row.get('value_copper'))} | {money(market_row.get('value_copper'))} | {money(sale_row.get('value_copper'))} | {money(row.get('cost_basis_copper'))} |")
    strict_unknown = current["strict_buckets"].get("unknown_tool_stat", {"quantity": 0, "value_copper": 0, "cost_basis_copper": 0})
    local_row = local_value.get("strict_buckets", {}).get("unknown_tool_stat", {})
    market_row = region_market_value.get("strict_buckets", {}).get("unknown_tool_stat", {})
    sale_row = region_sale_value.get("strict_buckets", {}).get("unknown_tool_stat", {})
    lines.append(f"| Outils 232 stat inconnue | {qty(strict_unknown['quantity'])} | {money(local_row.get('value_copper'))} | {money(market_row.get('value_copper'))} | {money(sale_row.get('value_copper'))} | {money(strict_unknown.get('cost_basis_copper'))} |")
    lines += [
        "",
        "## Performance du ledger",
        "",
        "| Vue | Achats | Ventes | CA | Bénéfice connu net | Marge connue | Délai médian |",
        "|---|---:|---:|---:|---:|---:|---:|",
    ]
    for label, metric in (("Brut", raw), ("Pertinent opérationnel", operational), ("Pertinent certain", strict)):
        lines.append(
            f"| {label} | {qty(metric['purchases_qty'])} | {qty(metric['sales_qty'])} | {money(metric['revenue_copper'])} | {money(metric['profit_after_commission_copper'])} | {pct(metric['margin_on_known_sales'])} | {fmt_days(metric['median_delay_days'])} |"
        )
    lines += [
        "",
        "## Par royaume de vente",
        "",
        "Les ventes sont affectées au royaume où TSM les a enregistrées. Cela permet de distinguer le résultat Hyjal du reste de la stratégie interserveur.",
        "",
        "| Vue | Royaume | Ventes | CA | Bénéfice connu net | Marge connue | Délai médian |",
        "|---|---|---:|---:|---:|---:|---:|",
    ]
    for view_name, label in (("operational_relevant", "Pertinent opérationnel"), ("strict_relevant", "Pertinent certain")):
        realm_rows = sorted(
            report["ledger"][view_name]["by_realm"].items(),
            key=lambda item: (item[1].get("revenue_copper", 0), item[1].get("sales_qty", 0)),
            reverse=True,
        )
        for realm, metric in realm_rows:
            if not metric.get("sales_qty"):
                continue
            lines.append(
                f"| {label} | {realm} | {qty(metric['sales_qty'])} | {money(metric['revenue_copper'])} | {money(metric['profit_after_commission_copper'])} | {pct(metric['margin_on_known_sales'])} | {fmt_days(metric['median_delay_days'])} |"
            )
    lines += [
        "",
        "## Par type",
        "",
        "| Vue / type | Stock actuel | Ventes | CA | Bénéfice connu net | Rotation proxy |",
        "|---|---:|---:|---:|---:|---:|",
    ]
    for view_name, label in (("raw", "Brut"), ("operational_relevant", "Pertinent opérationnel"), ("strict_relevant", "Pertinent certain")):
        bundle = report["ledger"][view_name]
        for category in ("tool", "accessory"):
            metric = bundle["by_type"].get(category, empty_metric())
            lines.append(f"| {label} / {category} | {qty(metric.get('current_qty'))} | {qty(metric.get('sales_qty'))} | {money(metric.get('revenue_copper'))} | {money(metric.get('profit_after_commission_copper'))} | {metric.get('rotation_proxy'):.2f}× |" if metric.get("rotation_proxy") is not None else f"| {label} / {category} | {qty(metric.get('current_qty'))} | {qty(metric.get('sales_qty'))} | {money(metric.get('revenue_copper'))} | {money(metric.get('profit_after_commission_copper'))} | n/d |")
    lines += [
        "",
        "## Références ayant réellement tourné",
        "",
        "Classement opérationnel par ventes, puis CA. Les lignes avec ventes nulles restent visibles dans le JSON.",
        "",
        "| Objet | Stock | Achats | Ventes | CA | Bénéfice connu net | Délai médian |",
        "|---|---:|---:|---:|---:|---:|---:|",
    ]
    operational_items = sorted(
        report["ledger"]["operational_relevant"]["by_item"].values(),
        key=lambda row: (row.get("sales_qty", 0), row.get("revenue_copper", 0)),
        reverse=True,
    )
    stock_by_item = defaultdict(int)
    for entry in current["variants"]:
        if entry["metadata"]["operational_bucket"] == "relevant":
            stock_by_item[entry["item_id"]] += entry["quantity"]
    for metric in operational_items[:20]:
        lines.append(f"| {metric['name']} ({metric['item_id']}) | {qty(stock_by_item[metric['item_id']])} | {qty(metric['purchases_qty'])} | {qty(metric['sales_qty'])} | {money(metric['revenue_copper'])} | {money(metric['profit_after_commission_copper'])} | {fmt_days(metric['median_delay_days'])} |")
    lines += [
        "",
        "## Limites à garder en tête",
        "",
    ]
    lines.extend(f"- {note}" for note in report["notes"])
    lines.append("")
    return "\n".join(lines)


def main() -> int:
    args = parse_args()
    saved = args.account_root / "SavedVariables"
    database = load_tsm_database(saved / "TradeSkillMaster.lua")
    names, tooltip_snapshot, tooltip_snapshot_rows, stat_census_rows = load_names_and_snapshot(args.account_root)
    report = build_report(
        database,
        names,
        tooltip_snapshot,
        tooltip_snapshot_rows,
        stat_census_rows,
        load_exact_price_index(GEAR_IDS, args.retail_root, args.account_root),
        args.commission,
        args.price_realm,
    )
    # Keep the caller-provided scope path accurate in the artifact.
    report["scope"]["account_root"] = str(args.account_root)
    args.output_dir.mkdir(parents=True, exist_ok=True)
    json_path = args.output_dir / "midnight-profession-ledger-analysis.json"
    markdown_path = args.output_dir / "midnight-profession-ledger-analysis.md"
    json_path.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    markdown = render_report(report)
    markdown_path.write_text(markdown, encoding="utf-8")
    if not args.quiet:
        print(markdown)
        print(f"\nJSON: {json_path}\nMarkdown: {markdown_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
