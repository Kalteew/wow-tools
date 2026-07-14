from __future__ import annotations

import argparse
import csv
import json
import re
import sys
import time
import urllib.request
from dataclasses import dataclass
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from wow_tools.account_pipeline import load_local_price_index
from wow_tools.local_account import format_copper
from wow_tools.sources.tsm import (
    TSM_BROWSER_UA,
    TSM_PRICING_API_BASE,
    _get_access_token,
    _get_api_key,
    _region_id,
)

BASE_URL = "https://www.wowhead.com/items/housing"
DEFAULT_CACHE_DIR = ROOT / "data" / "flipping" / "cache" / "wowhead-housing"
DEFAULT_OUTPUT_DIR = ROOT / "data" / "flipping" / "generated" / "housing-groups"
DEFAULT_SOURCE_IDS_FILE = ROOT / "data" / "flipping" / "housing-bou-wowhead-ids.txt"
FAST_SELL_RATE = 0.2


@dataclass(frozen=True)
class Segment:
    label: str
    path: str

    def url(self, id_range: tuple[int, int] | None = None) -> str:
        query = ""
        if id_range:
            query = f"?filter=151:151;2:4;{id_range[0]}:{id_range[1]}"
        return f"{BASE_URL}{self.path}{query}"


def _segments() -> list[Segment]:
    return [Segment("base", "")] + [Segment(f"quality-{quality}", f"/quality:{quality}") for quality in range(0, 5)]


def _safe_filename(label: str) -> str:
    return re.sub(r"[^A-Za-z0-9_.-]+", "-", label).strip("-") + ".html"


def _fetch(segment: Segment, cache_dir: Path, *, refresh: bool, id_range: tuple[int, int] | None = None) -> str:
    cache_dir.mkdir(parents=True, exist_ok=True)
    suffix = "" if id_range is None else f"-id-{id_range[0]}-{id_range[1]}"
    cache_path = cache_dir / _safe_filename(segment.label + suffix)
    if cache_path.exists() and not refresh:
        return cache_path.read_text(encoding="utf-8", errors="ignore")

    request = urllib.request.Request(
        segment.url(id_range),
        headers={
            "User-Agent": (
                "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
                "AppleWebKit/537.36 (KHTML, like Gecko) "
                "Chrome/126.0.0.0 Safari/537.36"
            ),
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
            "Accept-Language": "en-US,en;q=0.9,fr;q=0.8",
            "Referer": BASE_URL,
        },
    )
    last_error: Exception | None = None
    for attempt in range(1, 6):
        try:
            with urllib.request.urlopen(request, timeout=45) as response:
                text = response.read().decode("utf-8", errors="ignore")
            break
        except Exception as error:
            last_error = error
            if attempt == 5:
                if cache_path.exists():
                    print(f"Warning: using cached Wowhead segment after fetch failure: {cache_path}", file=sys.stderr)
                    return cache_path.read_text(encoding="utf-8", errors="ignore")
                raise
            time.sleep(attempt * 3)
    else:
        raise RuntimeError(f"Failed to fetch Wowhead segment: {segment.url(id_range)}") from last_error
    cache_path.write_text(text, encoding="utf-8")
    time.sleep(0.15)
    return text


def _extract_json_array(text: str) -> list[dict[str, Any]]:
    match = re.search(r"var listviewitems = (\[.*?\]);\s*new Listview", text, re.S)
    if not match:
        return []
    js = match.group(1)
    js = re.sub(r"([\{,])([A-Za-z_][A-Za-z0-9_]*):", r'\1"\2":', js)
    return json.loads(js)


def _extract_item_count(text: str) -> int | None:
    match = re.search(r'"numberOfItems":(\d+)', text)
    return int(match.group(1)) if match else None


def _source_label(row: dict[str, Any]) -> str:
    source = row.get("source")
    if isinstance(source, list):
        return ":".join(str(part) for part in source)
    return ""


def _load_source_id_items(path: Path) -> tuple[list[dict[str, Any]], dict[str, Any]]:
    item_ids = [int(match.group(0)) for match in re.finditer(r"\d+", path.read_text(encoding="utf-8", errors="ignore"))]
    unique_ids = sorted(set(item_ids))
    rows = [
        {
            "item_id": item_id,
            "item_string": f"i:{item_id}",
            "name": f"Item {item_id}",
            "quality": "",
            "type": "housing-bou",
            "wowhead_popularity": "",
            "wowhead_source": "wowhead-housing-binds-when-used",
        }
        for item_id in unique_ids
    ]
    metadata = {
        "wowhead_url": "https://www.wowhead.com/items/housing?filter=4;1;0",
        "source_file": str(path),
        "source_total_tokens": len(item_ids),
        "source_unique_item_count": len(unique_ids),
        "source_duplicate_count": len(item_ids) - len(unique_ids),
        "exportable_item_count": len(rows),
        "segments": {},
        "declared_counts": {},
        "note": "Manual Wowhead Housing + Binds when used source list provided by user.",
    }
    return rows, metadata


def _collect_segment_rows(
    segment: Segment,
    cache_dir: Path,
    *,
    refresh: bool,
    id_range: tuple[int, int] | None = None,
    source_counts: dict[str, int],
    declared_counts: dict[str, int | None],
) -> dict[int, dict[str, Any]]:
    text = _fetch(segment, cache_dir, refresh=refresh, id_range=id_range)
    rows = _extract_json_array(text)
    declared = _extract_item_count(text)
    suffix = "" if id_range is None else f"-id-{id_range[0]}-{id_range[1]}"
    key = f"{segment.label}{suffix}"
    source_counts[key] = len(rows)
    declared_counts[key] = declared

    if id_range is None and declared and declared > len(rows):
        return _collect_segment_rows(
            segment,
            cache_dir,
            refresh=refresh,
            id_range=(200000, 300000),
            source_counts=source_counts,
            declared_counts=declared_counts,
        )

    if id_range is not None and declared and declared > len(rows) and id_range[0] < id_range[1]:
        low, high = id_range
        mid = (low + high) // 2
        left = _collect_segment_rows(
            segment,
            cache_dir,
            refresh=refresh,
            id_range=(low, mid),
            source_counts=source_counts,
            declared_counts=declared_counts,
        )
        right = _collect_segment_rows(
            segment,
            cache_dir,
            refresh=refresh,
            id_range=(mid + 1, high),
            source_counts=source_counts,
            declared_counts=declared_counts,
        )
        left.update(right)
        return left

    return {int(row["id"]): row for row in rows}


def _load_housing_items(cache_dir: Path, *, refresh: bool) -> tuple[list[dict[str, Any]], dict[str, Any]]:
    items: dict[int, dict[str, Any]] = {}
    source_counts: dict[str, int] = {}
    declared_counts: dict[str, int | None] = {}
    wowhead_count: int | None = None

    for segment in _segments():
        if segment.label == "base":
            text = _fetch(segment, cache_dir, refresh=refresh)
            wowhead_count = _extract_item_count(text)
            source_counts[segment.label] = len(_extract_json_array(text))
            declared_counts[segment.label] = wowhead_count
            continue

        segment_rows = _collect_segment_rows(
            segment,
            cache_dir,
            refresh=refresh,
            source_counts=source_counts,
            declared_counts=declared_counts,
        )
        for row in segment_rows.values():
            item_id = int(row["id"])
            items.setdefault(
                item_id,
                {
                    "item_id": item_id,
                    "item_string": f"i:{item_id}",
                    "name": row.get("name") or row.get("displayName") or f"Item {item_id}",
                    "quality": row.get("quality"),
                    "type": row.get("namedesc") or "",
                    "wowhead_popularity": row.get("popularity"),
                    "wowhead_source": _source_label(row),
                },
            )

    rows = sorted(items.values(), key=lambda item: (item["item_id"], item["name"]))
    metadata = {
        "wowhead_url": BASE_URL,
        "wowhead_number_of_items": wowhead_count,
        "exportable_item_count": len(rows),
        "segments": source_counts,
        "declared_counts": declared_counts,
        "note": "Wowhead list pages cap some result sets; this file is the union of quality buckets recursively split by item ID.",
    }
    return rows, metadata


def _gold_per_slot_day(price_copper: int | None, sale_rate: float | None) -> float:
    if not price_copper or sale_rate is None:
        return 0.0
    return round((price_copper * sale_rate) / 10000, 2)


def _load_tsm_region_dump(region: str, cache_dir: Path, *, refresh: bool) -> dict[int, dict[str, Any]]:
    api_key = _get_api_key()
    if not api_key:
        return {}

    cache_dir.mkdir(parents=True, exist_ok=True)
    cache_path = cache_dir / f"tsm-region-{region.lower()}.json"
    if cache_path.exists() and not refresh:
        payload = json.loads(cache_path.read_text(encoding="utf-8"))
    else:
        token = _get_access_token(api_key)
        url = f"{TSM_PRICING_API_BASE}/region/{_region_id(region)}"
        request = urllib.request.Request(
            url,
            headers={
                "Authorization": f"Bearer {token}",
                "Accept": "application/json",
                "User-Agent": TSM_BROWSER_UA,
            },
        )
        with urllib.request.urlopen(request, timeout=120) as response:
            payload = json.loads(response.read().decode("utf-8"))
        cache_path.write_text(json.dumps(payload, ensure_ascii=False), encoding="utf-8")

    return {int(row["itemId"]): row for row in payload if row.get("itemId") is not None}


def _enrich_with_tsm_api(rows: list[dict[str, Any]], region_dump: dict[int, dict[str, Any]]) -> list[dict[str, Any]]:
    enriched: list[dict[str, Any]] = []
    for row in rows:
        item_id = int(row["item_id"])
        pricing = region_dump.get(item_id) or {}
        sale_rate = pricing.get("saleRate")
        price_copper = pricing.get("marketValue")
        group = "fast" if sale_rate is not None and sale_rate > FAST_SELL_RATE else "slow"
        enriched.append(
            {
                **row,
                "group": group,
                "sale_rate": sale_rate if sale_rate is not None else "",
                "sold_per_day": pricing.get("soldPerDay") if pricing.get("soldPerDay") is not None else "",
                "price_copper": price_copper or "",
                "price_text": format_copper(price_copper) or "",
                "market_value_text": format_copper(price_copper) or "",
                "min_buyout_text": "",
                "is_commodity": "unknown",
                "gold_per_slot_day": _gold_per_slot_day(price_copper, sale_rate),
            }
        )
    return enriched


def _enrich_with_local_tsm(rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    price_index = load_local_price_index([int(row["item_id"]) for row in rows])
    enriched: list[dict[str, Any]] = []
    for row in rows:
        item_id = int(row["item_id"])
        summary = (price_index.get(item_id) or {}).get("summary", {})
        sale_rate = summary.get("sale_rate")
        price_copper = summary.get("preferred_price_copper")
        group = "fast" if sale_rate is not None and sale_rate > FAST_SELL_RATE else "slow"
        enriched.append(
            {
                **row,
                "group": group,
                "sale_rate": sale_rate if sale_rate is not None else "",
                "sold_per_day": summary.get("sold_per_day") if summary.get("sold_per_day") is not None else "",
                "price_copper": price_copper or "",
                "price_text": summary.get("preferred_price_text") or "",
                "market_value_text": summary.get("market_value_text") or "",
                "min_buyout_text": summary.get("min_buyout_text") or "",
                "is_commodity": "yes" if summary.get("is_commodity") else "no",
                "gold_per_slot_day": _gold_per_slot_day(price_copper, sale_rate),
            }
        )

    return enriched


def _sort_rows(rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    return sorted(
        rows,
        key=lambda row: (
            row["group"] == "fast",
            float(row["sale_rate"] or 0),
            float(row["gold_per_slot_day"] or 0),
            -int(row["item_id"]),
        ),
        reverse=True,
    )


def _write_lines(path: Path, rows: list[dict[str, Any]]) -> None:
    path.write_text("\n".join(row["item_string"] for row in rows) + ("\n" if rows else ""), encoding="utf-8")


def _write_csv(path: Path, rows: list[dict[str, Any]]) -> None:
    fields = [
        "group",
        "item_id",
        "item_string",
        "name",
        "quality",
        "type",
        "sale_rate",
        "sold_per_day",
        "price_copper",
        "price_text",
        "market_value_text",
        "min_buyout_text",
        "is_commodity",
        "gold_per_slot_day",
        "wowhead_popularity",
        "wowhead_source",
    ]
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields)
        writer.writeheader()
        writer.writerows(rows)


def build(
    output_dir: Path,
    cache_dir: Path,
    *,
    refresh: bool,
    price_source: str,
    region: str,
    source_ids_file: Path | None,
) -> dict[str, Any]:
    output_dir.mkdir(parents=True, exist_ok=True)
    if source_ids_file and source_ids_file.exists():
        housing_rows, metadata = _load_source_id_items(source_ids_file)
    else:
        housing_rows, metadata = _load_housing_items(cache_dir, refresh=refresh)
    effective_price_source = price_source
    if effective_price_source == "auto":
        effective_price_source = "tsm-api" if _get_api_key() else "local-apphelper"
    if effective_price_source == "tsm-api":
        rows = _enrich_with_tsm_api(housing_rows, _load_tsm_region_dump(region, cache_dir, refresh=refresh))
    else:
        rows = _enrich_with_local_tsm(housing_rows)
    rows = _sort_rows(rows)
    all_rows = sorted(rows, key=lambda row: int(row["item_id"]))
    fast_rows = [row for row in rows if row["group"] == "fast"]
    slow_rows = [row for row in rows if row["group"] == "slow"]

    paths = {
        "all": output_dir / "housing-all.tsm.txt",
        "slow": output_dir / "housing-slow.tsm.txt",
        "fast": output_dir / "housing-fast.tsm.txt",
        "csv": output_dir / "housing-groups.csv",
        "summary": output_dir / "housing-groups-summary.json",
    }
    _write_lines(paths["all"], all_rows)
    _write_lines(paths["slow"], slow_rows)
    _write_lines(paths["fast"], fast_rows)
    _write_csv(paths["csv"], rows)

    summary = {
        **metadata,
        "fast_threshold": FAST_SELL_RATE,
        "price_source": effective_price_source,
        "region": region,
        "groups": {
            "all": len(all_rows),
            "slow": len(slow_rows),
            "fast": len(fast_rows),
        },
        "outputs": {key: str(path) for key, path in paths.items()},
    }
    paths["summary"].write_text(json.dumps(summary, ensure_ascii=False, indent=2), encoding="utf-8")
    return summary


def main() -> int:
    parser = argparse.ArgumentParser(description="Build all/slow/fast WoW housing TSM group files.")
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUTPUT_DIR)
    parser.add_argument("--cache-dir", type=Path, default=DEFAULT_CACHE_DIR)
    parser.add_argument("--source-ids-file", type=Path, default=DEFAULT_SOURCE_IDS_FILE)
    parser.add_argument("--price-source", choices=["auto", "tsm-api", "local-apphelper"], default="auto")
    parser.add_argument("--region", default="eu")
    parser.add_argument("--refresh", action="store_true")
    args = parser.parse_args()

    summary = build(
        args.output_dir,
        args.cache_dir,
        refresh=args.refresh,
        price_source=args.price_source,
        region=args.region,
        source_ids_file=args.source_ids_file,
    )
    print(json.dumps(summary, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
