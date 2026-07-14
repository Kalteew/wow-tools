from __future__ import annotations

import argparse
import csv
import json
import re
import sys
import time
import urllib.error
import urllib.request
from dataclasses import dataclass
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from wow_tools.local_account import (
    _LOADDATA_RE,
    _decode_appdata_values,
    _extract_appdata_item_blob,
    _iter_appdata_rows,
    _lua_array_to_list,
    _parse_appdata_metadata,
    resolve_paths,
)

WOWHEAD_ITEMS_URL = "https://www.wowhead.com/items"
LISTVIEW_RE = re.compile(r"var listviewitems = (\[.*?\]);\s*new Listview", re.S)
UNQUOTED_KEY_RE = re.compile(r'([{\[,])([A-Za-z_][A-Za-z0-9_]*)\s*:') 
ITEM_COUNT_RE = re.compile(r'"numberOfItems":(\d+)')
DEFAULT_CACHE_DIR = ROOT / "data" / "cache" / "wowhead-all-items"
DEFAULT_OUTPUT_DIR = ROOT / "data" / "reports"
DEFAULT_MIN_ID = 1
DEFAULT_MAX_ID = 280000
DEFAULT_STEP = 5000
_LAST_FETCH_TS = 0.0


@dataclass(frozen=True)
class RangeTask:
    low: int
    high: int

    @property
    def key(self) -> str:
        return f"{self.low}-{self.high}"

    def url(self) -> str:
        return f"{WOWHEAD_ITEMS_URL}?filter=151:151;2:4;{self.low}:{self.high}"


def _safe_filename(value: str) -> str:
    return re.sub(r"[^A-Za-z0-9_.-]+", "-", value).strip("-")


def _cache_path(cache_dir: Path, task: RangeTask) -> Path:
    return cache_dir / f"{_safe_filename(task.key)}.html"


def _respect_rate_limit() -> None:
    global _LAST_FETCH_TS
    elapsed = time.time() - _LAST_FETCH_TS
    minimum_delay = 1.25
    if elapsed < minimum_delay:
        time.sleep(minimum_delay - elapsed)
    _LAST_FETCH_TS = time.time()


def _fetch_range(task: RangeTask, cache_dir: Path, *, refresh: bool) -> str:
    cache_dir.mkdir(parents=True, exist_ok=True)
    cache_path = _cache_path(cache_dir, task)
    if cache_path.exists() and not refresh:
        return cache_path.read_text(encoding="utf-8", errors="ignore")

    request = urllib.request.Request(
        task.url(),
        headers={
            "User-Agent": "Mozilla/5.0",
        },
    )

    last_error: Exception | None = None
    for attempt in range(1, 6):
        try:
            _respect_rate_limit()
            with urllib.request.urlopen(request, timeout=60) as response:
                text = response.read().decode("utf-8", errors="ignore")
            cache_path.write_text(text, encoding="utf-8")
            return text
        except urllib.error.HTTPError as error:
            last_error = error
            if error.code not in {403, 429, 500, 502, 503, 504} or attempt == 5:
                break
            time.sleep(attempt * 12)
        except Exception as error:  # pragma: no cover - network fallback
            last_error = error
            if attempt == 5:
                break
            time.sleep(attempt * 3)

    if cache_path.exists():
        return cache_path.read_text(encoding="utf-8", errors="ignore")
    raise RuntimeError(f"Failed to fetch Wowhead range {task.key}") from last_error


def _parse_rows(html: str) -> tuple[list[dict[str, Any]], int | None]:
    match = LISTVIEW_RE.search(html)
    rows: list[dict[str, Any]] = []
    if match:
        payload = UNQUOTED_KEY_RE.sub(r'\1"\2":', match.group(1))
        rows = json.loads(payload)
    count_match = ITEM_COUNT_RE.search(html)
    declared = int(count_match.group(1)) if count_match else None
    return rows, declared


def _split_task(task: RangeTask) -> tuple[RangeTask, RangeTask]:
    mid = (task.low + task.high) // 2
    return RangeTask(task.low, mid), RangeTask(mid + 1, task.high)


def _collect_wowhead_items(
    cache_dir: Path,
    *,
    refresh: bool,
    min_id: int,
    max_id: int,
    step: int,
) -> tuple[dict[int, dict[str, Any]], dict[str, Any]]:
    items: dict[int, dict[str, Any]] = {}
    pending = [RangeTask(low, min(low + step - 1, max_id)) for low in range(min_id, max_id + 1, step)]
    pending.reverse()
    visited = 0
    split_ranges = 0
    empty_ranges = 0
    skipped_ranges: list[str] = []

    while pending:
        task = pending.pop()
        try:
            html = _fetch_range(task, cache_dir, refresh=refresh)
        except Exception as error:
            skipped_ranges.append(f"{task.key}: {error}")
            print(f"[wowhead] skipped={task.key} error={error}", flush=True)
            continue
        rows, declared = _parse_rows(html)
        visited += 1

        if not rows:
            empty_ranges += 1
            continue

        if declared and declared > len(rows) and task.low < task.high:
            left, right = _split_task(task)
            pending.extend([right, left])
            split_ranges += 1
            continue

        for row in rows:
            item_id = int(row.get("id") or 0)
            if item_id <= 0:
                continue
            existing = items.get(item_id, {})
            items[item_id] = {
                "item_id": item_id,
                "name": row.get("name") or row.get("displayName") or existing.get("name") or f"Item {item_id}",
                "quality": row.get("quality"),
                "item_level": row.get("level"),
                "required_level": row.get("reqlevel"),
                "class_id": row.get("classs"),
                "subclass_id": row.get("subclass"),
                "slot_id": row.get("slot"),
                "wowhead_popularity": row.get("popularity"),
                "wowhead_url": f"https://www.wowhead.com/item={item_id}",
            }

        if visited % 25 == 0:
            print(f"[wowhead] ranges={visited} items={len(items)} pending={len(pending)}", flush=True)

    summary = {
        "ranges_visited": visited,
        "ranges_split": split_ranges,
        "empty_ranges": empty_ranges,
        "item_count": len(items),
        "min_id": min_id,
        "max_id": max_id,
        "step": step,
        "skipped_ranges": skipped_ranges,
    }
    return items, summary


def _normalize_item_string(value: str) -> str | None:
    if value.isdigit():
        return f"i:{value}"
    match = re.match(r"i:(\d+)", value)
    if match:
        return f"i:{match.group(1)}"
    return None


def _decode_scaled_metric(value: Any) -> float | None:
    if not isinstance(value, int):
        return None
    return round(value / 1000.0, 3)


def _load_tsm_index(retail_root: str | Path | None = None, account_root: str | Path | None = None) -> tuple[dict[str, dict[str, Any]], dict[str, Any]]:
    paths = resolve_paths(retail_root, account_root)
    appdata_path = Path(paths["tsm_appdata"])
    if not appdata_path.exists():
        raise FileNotFoundError(f"TSM AppHelper not found: {appdata_path}")

    by_item: dict[str, dict[str, Any]] = {}
    dataset_count = 0

    for raw_line in appdata_path.read_text(encoding="utf-8", errors="replace").splitlines():
        match = _LOADDATA_RE.match(raw_line)
        if not match:
            continue

        tag, scope, payload = match.groups()
        metadata = _parse_appdata_metadata(payload)
        if tag == "APP_INFO":
            continue
        if tag not in {"AUCTIONDB_COMMODITY_DATA", "AUCTIONDB_NON_COMMODITY_DATA", "AUCTIONDB_REGION_SALE"}:
            continue

        dataset_count += 1
        fields = _lua_array_to_list(metadata.get("fields", {}))
        item_blob = _extract_appdata_item_blob(payload)

        for raw_item_string, raw_values in _iter_appdata_rows(item_blob):
            item_string = _normalize_item_string(raw_item_string)
            if not item_string:
                continue

            entry = by_item.setdefault(
                item_string,
                {
                    "commodity_scopes": set(),
                    "noncommodity_scopes": set(),
                    "sale_scopes": set(),
                    "min_buyout": None,
                    "num_auctions": None,
                    "market_value_recent": None,
                    "region_sale_percent": None,
                    "region_sold_per_day": None,
                },
            )
            decoded = _decode_appdata_values(fields, raw_values)

            if tag == "AUCTIONDB_COMMODITY_DATA":
                entry["commodity_scopes"].add(scope)
                entry["min_buyout"] = decoded.get("minBuyout") or entry["min_buyout"]
                entry["num_auctions"] = decoded.get("numAuctions") or entry["num_auctions"]
                entry["market_value_recent"] = decoded.get("marketValueRecent") or entry["market_value_recent"]
            elif tag == "AUCTIONDB_NON_COMMODITY_DATA":
                entry["noncommodity_scopes"].add(scope)
                entry["min_buyout"] = decoded.get("minBuyout") or entry["min_buyout"]
                entry["num_auctions"] = decoded.get("numAuctions") or entry["num_auctions"]
                entry["market_value_recent"] = decoded.get("marketValueRecent") or entry["market_value_recent"]
            elif tag == "AUCTIONDB_REGION_SALE":
                entry["sale_scopes"].add(scope)
                entry["region_sale_percent"] = decoded.get("regionSalePercent") or entry["region_sale_percent"]
                entry["region_sold_per_day"] = decoded.get("regionSoldPerDay") or entry["region_sold_per_day"]

    summary = {
        "appdata_path": str(appdata_path),
        "dataset_count": dataset_count,
        "item_strings": len(by_item),
    }
    return by_item, summary


def _row_with_tsm(item: dict[str, Any], tsm_entry: dict[str, Any] | None) -> dict[str, Any]:
    row = dict(item)
    if not tsm_entry:
        row.update(
            {
                "tsm_present": False,
                "ah_type": "unknown",
                "commodity_scopes": "",
                "noncommodity_scopes": "",
                "sale_scopes": "",
                "min_buyout": None,
                "num_auctions": None,
                "market_value_recent": None,
                "region_sale_percent": None,
                "region_sale_rate": None,
                "region_sold_per_day": None,
            }
        )
        return row

    commodity_scopes = sorted(tsm_entry["commodity_scopes"])
    noncommodity_scopes = sorted(tsm_entry["noncommodity_scopes"])
    sale_scopes = sorted(tsm_entry["sale_scopes"])

    if commodity_scopes and not noncommodity_scopes:
        ah_type = "commodity"
    elif noncommodity_scopes and not commodity_scopes:
        ah_type = "non-commodity"
    elif commodity_scopes and noncommodity_scopes:
        ah_type = "mixed"
    else:
        ah_type = "unknown"

    row.update(
        {
            "tsm_present": True,
            "ah_type": ah_type,
            "commodity_scopes": "|".join(commodity_scopes),
            "noncommodity_scopes": "|".join(noncommodity_scopes),
            "sale_scopes": "|".join(sale_scopes),
            "min_buyout": tsm_entry["min_buyout"],
            "num_auctions": tsm_entry["num_auctions"],
            "market_value_recent": tsm_entry["market_value_recent"],
            "region_sale_percent": tsm_entry["region_sale_percent"],
            "region_sale_rate": _decode_scaled_metric(tsm_entry["region_sale_percent"]),
            "region_sold_per_day": _decode_scaled_metric(tsm_entry["region_sold_per_day"]),
        }
    )
    return row


def _write_outputs(rows: list[dict[str, Any]], output_dir: Path, export_name: str, metadata: dict[str, Any]) -> dict[str, str]:
    output_dir.mkdir(parents=True, exist_ok=True)
    json_path = output_dir / f"{export_name}.json"
    csv_path = output_dir / f"{export_name}.csv"
    metadata_path = output_dir / f"{export_name}.meta.json"

    json_path.write_text(json.dumps(rows, ensure_ascii=False, indent=2), encoding="utf-8")

    fieldnames = [
        "item_id",
        "name",
        "quality",
        "item_level",
        "required_level",
        "class_id",
        "subclass_id",
        "slot_id",
        "wowhead_popularity",
        "wowhead_url",
        "tsm_present",
        "ah_type",
        "commodity_scopes",
        "noncommodity_scopes",
        "sale_scopes",
        "min_buyout",
        "num_auctions",
        "market_value_recent",
        "region_sale_percent",
        "region_sale_rate",
        "region_sold_per_day",
    ]
    with csv_path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)

    metadata_path.write_text(json.dumps(metadata, ensure_ascii=False, indent=2), encoding="utf-8")
    return {
        "json": str(json_path),
        "csv": str(csv_path),
        "meta": str(metadata_path),
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Export all Wowhead items enriched with local TSM AppHelper data")
    parser.add_argument("--refresh", action="store_true", help="Ignore cached Wowhead HTML")
    parser.add_argument("--min-id", type=int, default=DEFAULT_MIN_ID)
    parser.add_argument("--max-id", type=int, default=DEFAULT_MAX_ID)
    parser.add_argument("--step", type=int, default=DEFAULT_STEP)
    parser.add_argument("--cache-dir", type=Path, default=DEFAULT_CACHE_DIR)
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUTPUT_DIR)
    parser.add_argument("--export-name", default="wowhead-all-items-with-tsm")
    parser.add_argument("--retail-root")
    parser.add_argument("--account-root")
    return parser


def main() -> int:
    args = build_parser().parse_args()
    wowhead_items, wowhead_summary = _collect_wowhead_items(
        args.cache_dir,
        refresh=args.refresh,
        min_id=args.min_id,
        max_id=args.max_id,
        step=args.step,
    )
    tsm_index, tsm_summary = _load_tsm_index(args.retail_root, args.account_root)

    rows = [
        _row_with_tsm(item, tsm_index.get(f"i:{item_id}"))
        for item_id, item in sorted(wowhead_items.items())
    ]

    outputs = _write_outputs(
        rows,
        args.output_dir,
        args.export_name,
        {
            "wowhead": wowhead_summary,
            "tsm": tsm_summary,
            "rows": len(rows),
            "tsm_present": sum(1 for row in rows if row["tsm_present"]),
            "commodity": sum(1 for row in rows if row["ah_type"] == "commodity"),
            "non_commodity": sum(1 for row in rows if row["ah_type"] == "non-commodity"),
            "mixed": sum(1 for row in rows if row["ah_type"] == "mixed"),
            "unknown": sum(1 for row in rows if row["ah_type"] == "unknown"),
        },
    )

    print("Export complete")
    print(f"- rows: {len(rows)}")
    print(f"- with TSM: {sum(1 for row in rows if row['tsm_present'])}")
    print(f"- commodity: {sum(1 for row in rows if row['ah_type'] == 'commodity')}")
    print(f"- non-commodity: {sum(1 for row in rows if row['ah_type'] == 'non-commodity')}")
    print(f"- mixed: {sum(1 for row in rows if row['ah_type'] == 'mixed')}")
    print(f"- unknown: {sum(1 for row in rows if row['ah_type'] == 'unknown')}")
    print(f"- json: {outputs['json']}")
    print(f"- csv: {outputs['csv']}")
    print(f"- meta: {outputs['meta']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
