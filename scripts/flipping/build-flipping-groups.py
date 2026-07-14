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
    format_copper,
    resolve_paths,
)
from wow_tools.sources.tsm import (
    TSM_BROWSER_UA,
    TSM_PRICING_API_BASE,
    _get_access_token,
    _get_api_key,
    _region_id,
)

WOWHEAD_ITEMS_URL = "https://www.wowhead.com/items"
DEFAULT_CACHE_DIR = ROOT / "data" / "flipping" / "cache" / "wowhead-flipping"
DEFAULT_OUTPUT_DIR = ROOT / "data" / "flipping" / "generated" / "flipping-groups"
DEFAULT_MOUNT_FILE = ROOT / "data" / "flipping" / "generated" / "flipping-groups" / "flipping-mount.tsm.txt"
DEFAULT_TOYS_FILE = ROOT / "data" / "flipping" / "generated" / "flipping-groups" / "flipping-toys.tsm.txt"
DEFAULT_RECIPES_FILE = ROOT / "data" / "flipping" / "generated" / "flipping-groups" / "flipping-recipes.tsm.txt"
DEFAULT_TMOG_FILE = ROOT / "data" / "flipping" / "generated" / "flipping-groups" / "flipping-tmog.tsm.txt"
DEFAULT_HOUSING_FILE = ROOT / "data" / "flipping" / "generated" / "housing-groups" / "housing-all.tsm.txt"
FAST_SELL_RATE = 0.2
SLOW_MIN_SELL_RATE = 0.02
SLOW_MIN_SOLD_PER_DAY = 0.02
SLOW_MIN_PRICE_COPPER = 1_000 * 10_000
SLOW_MAX_PRICE_COPPER = 1_000_000 * 10_000
SLOW_LIMIT = 1_000

RECIPE_PATHS = [
    "/recipes/books",
    "/recipes/alchemy",
    "/recipes/blacksmithing",
    "/recipes/cooking",
    "/recipes/enchanting",
    "/recipes/engineering",
    "/recipes/fishing",
    "/recipes/inscription",
    "/recipes/jewelcrafting",
    "/recipes/leatherworking",
    "/recipes/mining",
    "/recipes/tailoring",
]

MISC_FLIP_PATHS = [
    "/miscellaneous/companions",
    "/miscellaneous/mounts",
    "/miscellaneous/mounts/ground",
    "/miscellaneous/mounts/flying",
    "/miscellaneous/mounts/aquatic",
]

WEAPON_TRANSMOG_PATHS = [
    "/weapons/daggers",
    "/weapons/fist-weapons",
    "/weapons/one-handed-axes",
    "/weapons/one-handed-maces",
    "/weapons/one-handed-swords",
    "/weapons/warglaives",
    "/weapons/polearms",
    "/weapons/staves",
    "/weapons/two-handed-axes",
    "/weapons/two-handed-maces",
    "/weapons/two-handed-swords",
    "/weapons/bows",
    "/weapons/crossbows",
    "/weapons/guns",
    "/weapons/wands",
    "/weapons/fishing-poles",
    "/weapons/miscellaneous",
]

ARMOR_TRANSMOG_PATHS = [
    f"/armor/{armor}/{armor}-{slot}"
    for armor in ("cloth", "leather", "mail", "plate")
    for slot in (
        "chest-armor",
        "foot-armor",
        "hand-armor",
        "head-armor",
        "leg-armor",
        "shoulder-armor",
        "belts",
        "bracers",
    )
] + [
    "/armor/cloaks",
    "/armor/off-hand-frills",
    "/armor/shields",
    "/armor/shirts",
    "/armor/tabards",
    "/armor/cosmetic",
]


@dataclass(frozen=True)
class Segment:
    label: str
    path: str
    category: str
    filter_ids: tuple[int, ...] = ()
    filter_selects: tuple[int, ...] = ()
    filter_values: tuple[int, ...] = ()
    split_ranges: bool = True

    def url(self, *, id_range: tuple[int, int] | None = None) -> str:
        ids = list(self.filter_ids)
        selects = list(self.filter_selects)
        values = list(self.filter_values)
        if id_range:
            ids.extend([151, 151])
            selects.extend([2, 4])
            values.extend([id_range[0], id_range[1]])
        query = ""
        if ids:
            query = "?filter=" + ":".join(map(str, ids)) + ";" + ":".join(map(str, selects)) + ";" + ":".join(map(str, values))
        return f"{WOWHEAD_ITEMS_URL}{self.path}{query}"


def _housing_segments() -> list[Segment]:
    segments = [Segment("housing-base", "/housing", "housing")]
    for quality in range(0, 5):
        segments.append(Segment(f"housing-quality-{quality}", f"/housing/quality:{quality}", "housing"))
        for type_id in range(0, 6):
            segments.append(Segment(f"housing-quality-{quality}-type-{type_id}", f"/housing/quality:{quality}/type:{type_id}", "housing"))
    # Source/expansion filters are redundant with type + ID coverage and some
    # combinations return 403 on Wowhead. Keep the exhaustive path deterministic.
    for low in range(235000, 278000, 2000):
        high = low + 1999
        segments.append(
            Segment(
                f"housing-quality-2-type-0-id-{low}-{high}",
                "/housing/quality:2/type:0",
                "housing",
                (151, 151),
                (2, 4),
                (low, high),
            )
        )
    return segments


def _other_segments() -> list[Segment]:
    segments: list[Segment] = []
    for path in RECIPE_PATHS:
        segments.append(Segment(f"recipes{path.replace('/', '-')}", path, "recipe"))
    for path in MISC_FLIP_PATHS:
        category = "pet" if "companions" in path else "mount"
        segments.append(Segment(f"{category}{path.replace('/', '-')}", path, category))
    segments.append(Segment("toys", "", "toy", (216,), (1,), (0,)))
    for path in WEAPON_TRANSMOG_PATHS:
        segments.append(Segment(f"transmog{path.replace('/', '-')}", path, "transmog", (3, 178), (1, 1), (0, 0)))
    for path in ARMOR_TRANSMOG_PATHS:
        segments.append(Segment(f"transmog{path.replace('/', '-')}", path, "transmog", (3, 178), (1, 1), (0, 0)))
    return segments


def _safe_filename(label: str) -> str:
    return re.sub(r"[^A-Za-z0-9_.-]+", "-", label).strip("-") + ".html"


def _fetch(segment: Segment, cache_dir: Path, *, refresh: bool, id_range: tuple[int, int] | None = None) -> str:
    cache_dir.mkdir(parents=True, exist_ok=True)
    suffix = "" if id_range is None else f"-id-{id_range[0]}-{id_range[1]}"
    cache_path = cache_dir / _safe_filename(segment.label + suffix)
    if cache_path.exists() and not refresh:
        return cache_path.read_text(encoding="utf-8", errors="ignore")

    url = segment.url(id_range=id_range)
    request = urllib.request.Request(
        url,
        headers={
            "User-Agent": (
                "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
                "AppleWebKit/537.36 (KHTML, like Gecko) "
                "Chrome/126.0.0.0 Safari/537.36"
            ),
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
            "Accept-Language": "en-US,en;q=0.9,fr;q=0.8",
            "Referer": WOWHEAD_ITEMS_URL,
        },
    )
    for attempt in range(1, 6):
        try:
            with urllib.request.urlopen(request, timeout=60) as response:
                text = response.read().decode("utf-8", errors="ignore")
            break
        except urllib.error.HTTPError as error:
            if error.code not in {403, 429, 500, 502, 503, 504} or attempt == 5:
                raise RuntimeError(f"Failed to fetch Wowhead segment after {attempt} attempts: {url}") from error
            wait_seconds = 8 * attempt
            print(f"Retry {attempt}/5 after HTTP {error.code}: {url}", file=sys.stderr)
            time.sleep(wait_seconds)
    cache_path.write_text(text, encoding="utf-8")
    time.sleep(0.35)
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


def _collect_segments(segments: list[Segment], cache_dir: Path, *, refresh: bool) -> tuple[dict[int, dict[str, Any]], dict[str, Any]]:
    items: dict[int, dict[str, Any]] = {}
    segment_counts: dict[str, int] = {}
    segment_declared: dict[str, int | None] = {}
    skipped_ranges: list[str] = []

    for segment in segments:
        try:
            text = _fetch(segment, cache_dir, refresh=refresh)
        except RuntimeError as error:
            skipped_ranges.append(f"{segment.label}: {error}")
            print(f"Skipping segment after fetch failure: {segment.label}", file=sys.stderr)
            continue
        rows = _extract_json_array(text)
        declared = _extract_item_count(text)
        segment_counts[segment.label] = len(rows)
        segment_declared[segment.label] = declared

        ranges: list[tuple[int, int] | None] = [None]
        if segment.split_ranges and declared and declared > len(rows):
            ranges.extend((low, low + 24999) for low in range(0, 400000, 25000))

        for id_range in ranges:
            if id_range is not None:
                try:
                    text = _fetch(segment, cache_dir, refresh=refresh, id_range=id_range)
                except RuntimeError as error:
                    skipped_ranges.append(f"{segment.label} {id_range[0]}-{id_range[1]}: {error}")
                    print(f"Skipping range after fetch failure: {segment.label} {id_range[0]}-{id_range[1]}", file=sys.stderr)
                    continue
                rows = _extract_json_array(text)
                segment_counts[f"{segment.label}-id-{id_range[0]}-{id_range[1]}"] = len(rows)
            for row in rows:
                item_id = int(row["id"])
                if item_id <= 0:
                    continue
                existing = items.get(item_id)
                categories = set(existing.get("categories", "").split("|")) if existing else set()
                categories.add(segment.category)
                items[item_id] = {
                    "item_id": item_id,
                    "item_string": f"i:{item_id}",
                    "name": row.get("name") or row.get("displayName") or f"Item {item_id}",
                    "quality": row.get("quality"),
                    "type": row.get("namedesc") or segment.category,
                    "categories": "|".join(sorted(category for category in categories if category)),
                    "wowhead_popularity": row.get("popularity"),
                    "wowhead_source": _source_label(row),
                }

    return items, {"segments": segment_counts, "declared_counts": segment_declared, "skipped_ranges": skipped_ranges}


def _load_housing_file(path: Path) -> dict[int, dict[str, Any]]:
    item_ids: list[int] = []
    for line in path.read_text(encoding="utf-8").splitlines():
        value = line.strip()
        if not value:
            continue
        match = re.fullmatch(r"i:(\d+)", value)
        if not match:
            continue
        item_ids.append(int(match.group(1)))

    csv_rows: dict[int, dict[str, str]] = {}
    csv_path = path.with_name("housing-groups.csv")
    if csv_path.exists():
        with csv_path.open("r", encoding="utf-8", newline="") as handle:
            for row in csv.DictReader(handle):
                if row.get("item_id"):
                    csv_rows[int(row["item_id"])] = row

    items: dict[int, dict[str, Any]] = {}
    for item_id in sorted(set(item_ids)):
        csv_row = csv_rows.get(item_id, {})
        items[item_id] = {
            "item_id": item_id,
            "item_string": f"i:{item_id}",
            "name": csv_row.get("name") or f"Item {item_id}",
            "quality": csv_row.get("quality") or "",
            "type": csv_row.get("type") or "housing",
            "categories": "housing",
            "wowhead_popularity": csv_row.get("wowhead_popularity") or "",
            "wowhead_source": csv_row.get("wowhead_source") or "",
        }
    return items


def _load_tsm_region_dump(region: str, cache_dir: Path, *, refresh: bool) -> dict[int, dict[str, Any]]:
    cache_dir.mkdir(parents=True, exist_ok=True)
    cache_path = cache_dir / f"tsm-region-{region.lower()}.json"
    if cache_path.exists() and not refresh:
        payload = json.loads(cache_path.read_text(encoding="utf-8"))
    else:
        api_key = _get_api_key()
        if not api_key:
            raise SystemExit("TSM_API_KEY is required for region dump classification.")
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


def _normalize_tsm_item_string(value: str) -> str | None:
    if value.isdigit():
        return f"i:{value}"
    match = re.match(r"i:(\d+)", value)
    if match:
        return f"i:{match.group(1)}"
    match = re.match(r"p:(\d+)", value)
    if match:
        return f"p:{match.group(1)}"
    return None


def _item_number(item_string: str) -> int:
    match = re.match(r"[ip]:(\d+)", item_string)
    return int(match.group(1)) if match else 0


def _decode_scaled_metric(value: Any) -> float | None:
    return round(value / 1000.0, 3) if isinstance(value, int) else None


def _first_int(*values: Any) -> int | None:
    for value in values:
        if isinstance(value, int) and value > 0:
            return value
    return None


def _load_apphelper_other_rows(housing: dict[int, dict[str, Any]], appdata_path: Path | None) -> tuple[list[dict[str, Any]], dict[str, Any]]:
    if appdata_path is None:
        appdata_path = Path(resolve_paths()["tsm_appdata"])
    if not appdata_path.exists():
        raise SystemExit(f"TSM AppHelper AppData.lua not found: {appdata_path}")

    relevant_tags = {
        "AUCTIONDB_NON_COMMODITY_DATA",
        "AUCTIONDB_NON_COMMODITY_SCAN_STAT",
        "AUCTIONDB_NON_COMMODITY_HISTORICAL",
        "AUCTIONDB_REGION_STAT",
        "AUCTIONDB_REGION_HISTORICAL",
        "AUCTIONDB_REGION_SALE",
    }
    datasets_by_item: dict[str, dict[str, dict[str, int]]] = {}
    noncommodity_items: set[str] = set()
    commodity_items: set[str] = set()
    dataset_counts: dict[str, int] = {}

    for raw_line in appdata_path.read_text(encoding="utf-8", errors="replace").splitlines():
        match = _LOADDATA_RE.match(raw_line)
        if not match:
            continue
        tag, _scope, payload = match.groups()
        if tag == "APP_INFO" or not tag.startswith("AUCTIONDB_"):
            continue

        metadata = _parse_appdata_metadata(payload)
        fields = _lua_array_to_list(metadata.get("fields", {}))
        if not fields:
            continue
        try:
            item_blob = _extract_appdata_item_blob(payload)
        except ValueError:
            continue

        count = 0
        for raw_item_string, raw_values in _iter_appdata_rows(item_blob):
            item_string = _normalize_tsm_item_string(raw_item_string)
            if not item_string:
                continue
            if tag.startswith("AUCTIONDB_COMMODITY"):
                commodity_items.add(item_string)
            if "NON_COMMODITY" in tag:
                noncommodity_items.add(item_string)
            if tag in relevant_tags:
                datasets_by_item.setdefault(item_string, {})[tag] = _decode_appdata_values(fields, raw_values)
                count += 1
        dataset_counts[tag] = dataset_counts.get(tag, 0) + count

    housing_items = {f"i:{item_id}" for item_id in housing}
    candidates = sorted(noncommodity_items - commodity_items - housing_items, key=lambda item: (item.startswith("p:"), _item_number(item), item))
    rows: list[dict[str, Any]] = []
    for item_string in candidates:
        datasets = datasets_by_item.get(item_string, {})
        region_sale = datasets.get("AUCTIONDB_REGION_SALE", {})
        noncommodity_data = datasets.get("AUCTIONDB_NON_COMMODITY_DATA", {})
        noncommodity_scan = datasets.get("AUCTIONDB_NON_COMMODITY_SCAN_STAT", {})
        region_stat = datasets.get("AUCTIONDB_REGION_STAT", {})
        region_historical = datasets.get("AUCTIONDB_REGION_HISTORICAL", {})
        noncommodity_historical = datasets.get("AUCTIONDB_NON_COMMODITY_HISTORICAL", {})

        sale_rate = _decode_scaled_metric(region_sale.get("regionSalePercent"))
        sold_per_day = _decode_scaled_metric(region_sale.get("regionSoldPerDay"))
        price_copper = _first_int(
            noncommodity_data.get("minBuyout"),
            noncommodity_scan.get("marketValue"),
            noncommodity_data.get("marketValueRecent"),
            region_stat.get("regionMarketValue"),
            region_historical.get("regionHistorical"),
            noncommodity_historical.get("historical"),
        )
        group = "other-fast" if sale_rate is not None and sale_rate > FAST_SELL_RATE else "other-slow"
        item_number = _item_number(item_string)
        rows.append(
            {
                "group": group,
                "item_id": item_number,
                "item_string": item_string,
                "name": ("Pet" if item_string.startswith("p:") else "Item") + f" {item_number}",
                "categories": "other-non-commodity",
                "quality": "",
                "type": "pet" if item_string.startswith("p:") else "non-commodity",
                "sale_rate": sale_rate if sale_rate is not None else "",
                "sold_per_day": sold_per_day if sold_per_day is not None else "",
                "quantity": noncommodity_data.get("numAuctions") or "",
                "price_copper": price_copper or "",
                "price_text": format_copper(price_copper) or "",
                "gold_per_slot_day": _gold_per_slot_day(price_copper, sale_rate),
                "wowhead_popularity": "",
                "wowhead_source": "",
            }
        )
    return rows, {
        "source_file": str(appdata_path),
        "source": "TSM AppHelper non-commodity datasets",
        "dataset_counts": dataset_counts,
        "candidate_count": len(candidates),
        "excluded_housing_count": len(housing_items),
        "excluded_commodity_count": len(commodity_items),
    }


def _gold_per_slot_day(price_copper: int | None, sale_rate: float | None) -> float:
    if not price_copper or sale_rate is None:
        return 0.0
    return round((price_copper * sale_rate) / 10000, 2)


def _float_value(value: Any) -> float:
    if value in ("", None):
        return 0.0
    try:
        return float(value)
    except (TypeError, ValueError):
        return 0.0


def _passes_slow_filter(row: dict[str, Any]) -> bool:
    price_copper = _float_value(row.get("price_copper"))
    return (
        _float_value(row.get("sale_rate")) >= SLOW_MIN_SELL_RATE
        and _float_value(row.get("sold_per_day")) >= SLOW_MIN_SOLD_PER_DAY
        and price_copper >= SLOW_MIN_PRICE_COPPER
        and price_copper <= SLOW_MAX_PRICE_COPPER
    )


def _enrich(rows: list[dict[str, Any]], region_dump: dict[int, dict[str, Any]], bucket: str) -> list[dict[str, Any]]:
    enriched = []
    for row in rows:
        item_id = int(row["item_id"])
        pricing = region_dump.get(item_id) or {}
        sale_rate = pricing.get("saleRate")
        price_copper = pricing.get("marketValue")
        group = bucket if bucket == "housing" else ("other-fast" if sale_rate is not None and sale_rate > FAST_SELL_RATE else "other-slow")
        enriched.append(
            {
                **row,
                "group": group,
                "sale_rate": sale_rate if sale_rate is not None else "",
                "sold_per_day": pricing.get("soldPerDay") if pricing.get("soldPerDay") is not None else "",
                "quantity": pricing.get("quantity") if pricing.get("quantity") is not None else "",
                "price_copper": price_copper or "",
                "price_text": format_copper(price_copper) or "",
                "gold_per_slot_day": _gold_per_slot_day(price_copper, sale_rate),
            }
        )
    return enriched


def _write_lines(path: Path, rows: list[dict[str, Any]]) -> None:
    path.write_text("\n".join(row["item_string"] for row in rows) + ("\n" if rows else ""), encoding="utf-8")


def _write_csv(path: Path, rows: list[dict[str, Any]]) -> None:
    fields = [
        "group",
        "item_id",
        "item_string",
        "name",
        "categories",
        "quality",
        "type",
        "sale_rate",
        "sold_per_day",
        "quantity",
        "price_copper",
        "price_text",
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
    region: str,
    housing_file: Path | None,
    mount_file: Path | None,
    toys_file: Path | None,
    recipes_file: Path | None,
    tmog_file: Path | None,
    other_source: str,
    appdata_path: Path | None,
) -> dict[str, Any]:
    output_dir.mkdir(parents=True, exist_ok=True)
    if housing_file and housing_file.exists():
        housing = _load_housing_file(housing_file)
        housing_meta = {
            "source_file": str(housing_file),
            "segments": {},
            "declared_counts": {},
            "skipped_ranges": [],
        }
    else:
        housing, housing_meta = _collect_segments(_housing_segments(), cache_dir, refresh=refresh)

    region_dump = _load_tsm_region_dump(region, cache_dir, refresh=refresh)
    housing_rows = _enrich(sorted(housing.values(), key=lambda row: int(row["item_id"])), region_dump, "housing")
    if other_source == "apphelper":
        other_rows, other_meta = _load_apphelper_other_rows(housing, appdata_path)
    else:
        other, other_meta = _collect_segments(_other_segments(), cache_dir, refresh=refresh)
        for item_id in list(other):
            if item_id in housing:
                del other[item_id]
        other_rows = _enrich(list(other.values()), region_dump, "other")
    other_raw_count = len(other_rows)
    other_fast = [row for row in other_rows if row["group"] == "other-fast"]
    other_slow_raw = [row for row in other_rows if row["group"] == "other-slow"]
    mount_items: set[str] = set()
    if mount_file and mount_file.exists():
        mount_items = {
            line.strip()
            for line in mount_file.read_text(encoding="utf-8").splitlines()
            if line.strip()
        }
    toy_items: set[str] = set()
    if toys_file and toys_file.exists():
        toy_items = {
            line.strip()
            for line in toys_file.read_text(encoding="utf-8").splitlines()
            if line.strip()
        }
    recipe_items: set[str] = set()
    if recipes_file and recipes_file.exists():
        recipe_items = {
            line.strip()
            for line in recipes_file.read_text(encoding="utf-8").splitlines()
            if line.strip()
        }
    tmog_items: set[str] = set()
    if tmog_file and tmog_file.exists():
        tmog_items = {
            line.strip()
            for line in tmog_file.read_text(encoding="utf-8").splitlines()
            if line.strip()
        }
    if mount_items:
        other_slow_raw = [row for row in other_slow_raw if row["item_string"] not in mount_items]
    if toy_items:
        other_slow_raw = [row for row in other_slow_raw if row["item_string"] not in toy_items]
        other_fast = [row for row in other_fast if row["item_string"] not in toy_items]
    if recipe_items:
        other_slow_raw = [row for row in other_slow_raw if row["item_string"] not in recipe_items]
        other_fast = [row for row in other_fast if row["item_string"] not in recipe_items]
    if tmog_items:
        other_slow_raw = [row for row in other_slow_raw if row["item_string"] not in tmog_items]
        other_fast = [row for row in other_fast if row["item_string"] not in tmog_items]
    other_slow_candidates = [row for row in other_slow_raw if _passes_slow_filter(row)]
    other_slow_candidates.sort(
        key=lambda row: (
            _float_value(row.get("gold_per_slot_day")),
            _float_value(row.get("sale_rate")),
            _float_value(row.get("price_copper")),
            -int(row["item_id"]),
        ),
        reverse=True,
    )
    other_slow = other_slow_candidates[:SLOW_LIMIT]
    other_rows = other_fast + other_slow

    paths = {
        "housing": output_dir / "flipping-housing.tsm.txt",
        "other_slow": output_dir / "flipping-other-slow.tsm.txt",
        "other_fast": output_dir / "flipping-other-fast.tsm.txt",
        "csv": output_dir / "flipping-groups.csv",
        "summary": output_dir / "flipping-groups-summary.json",
    }
    _write_lines(paths["housing"], housing_rows)
    _write_lines(paths["other_slow"], other_slow)
    _write_lines(paths["other_fast"], other_fast)
    _write_csv(paths["csv"], housing_rows + other_rows)

    summary = {
        "wowhead_sources": {
            "housing": "https://www.wowhead.com/items/housing",
            "other": "TSM AppHelper non-commodity universe" if other_source == "apphelper" else "recipes, companions, mounts, toys, BoE transmogrifiable armor/weapons",
        },
        "price_source": "tsm-api-region-dump + tsm-apphelper" if other_source == "apphelper" else "tsm-api-region-dump",
        "region": region,
        "other_source": other_source,
        "fast_threshold": FAST_SELL_RATE,
        "slow_filters": {
            "min_sale_rate": SLOW_MIN_SELL_RATE,
            "min_sold_per_day": SLOW_MIN_SOLD_PER_DAY,
            "min_price_copper": SLOW_MIN_PRICE_COPPER,
            "min_price_text": format_copper(SLOW_MIN_PRICE_COPPER),
            "max_price_copper": SLOW_MAX_PRICE_COPPER,
            "max_price_text": format_copper(SLOW_MAX_PRICE_COPPER),
            "limit": SLOW_LIMIT,
            "sort": "gold_per_slot_day desc, sale_rate desc, price desc",
        },
        "groups": {
            "housing": len(housing_rows),
            "other_slow": len(other_slow),
            "other_fast": len(other_fast),
        },
        "raw_counts": {
            "other_all_before_filter": other_raw_count,
            "other_slow_before_filter": len(other_slow_raw),
            "other_slow_after_thresholds": len(other_slow_candidates),
        },
        "metadata": {
            "housing": housing_meta,
            "other": other_meta,
        },
        "outputs": {key: str(path) for key, path in paths.items()},
    }
    paths["summary"].write_text(json.dumps(summary, ensure_ascii=False, indent=2), encoding="utf-8")
    return summary


def main() -> int:
    parser = argparse.ArgumentParser(description="Build TSM files for housing, other slow, and other fast flip groups.")
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUTPUT_DIR)
    parser.add_argument("--cache-dir", type=Path, default=DEFAULT_CACHE_DIR)
    parser.add_argument("--housing-file", type=Path, default=DEFAULT_HOUSING_FILE)
    parser.add_argument("--mount-file", type=Path, default=DEFAULT_MOUNT_FILE)
    parser.add_argument("--toys-file", type=Path, default=DEFAULT_TOYS_FILE)
    parser.add_argument("--recipes-file", type=Path, default=DEFAULT_RECIPES_FILE)
    parser.add_argument("--tmog-file", type=Path, default=DEFAULT_TMOG_FILE)
    parser.add_argument("--other-source", choices=("apphelper", "wowhead"), default="apphelper")
    parser.add_argument("--appdata-path", type=Path)
    parser.add_argument("--region", default="eu")
    parser.add_argument("--refresh", action="store_true")
    args = parser.parse_args()
    print(
        json.dumps(
            build(
                args.output_dir,
                args.cache_dir,
                refresh=args.refresh,
                region=args.region,
                housing_file=args.housing_file,
                mount_file=args.mount_file,
                toys_file=args.toys_file,
                recipes_file=args.recipes_file,
                tmog_file=args.tmog_file,
                other_source=args.other_source,
                appdata_path=args.appdata_path,
            ),
            ensure_ascii=False,
            indent=2,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
