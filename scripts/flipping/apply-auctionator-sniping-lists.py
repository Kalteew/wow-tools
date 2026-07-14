from __future__ import annotations

import argparse
import csv
import html
import json
import re
import shutil
import subprocess
import sys
import time
import urllib.error
import urllib.request
from datetime import datetime
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]

GROUP_CSV = ROOT / "data" / "flipping" / "generated" / "flipping-groups" / "flipping-groups.csv"
OUTPUT_DIR = ROOT / "data" / "flipping" / "generated" / "sniping"
NAME_CACHE = ROOT / "data" / "flipping" / "cache" / "wowhead-flipping-names.json"
ITEM_PAGE_CACHE = ROOT / "data" / "flipping" / "cache" / "wowhead-item-names"
PET_INDEX_CACHE = ROOT / "data" / "flipping" / "cache" / "wowhead-pets.html"

AUCTIONATOR_PATH = Path(
    r"C:\Program Files (x86)\World of Warcraft\_retail_\WTF\Account\417185157#1\SavedVariables\Auctionator.lua"
)
PBS_PATH = Path(
    r"C:\Program Files (x86)\World of Warcraft\_retail_\WTF\Account\417185157#1\SavedVariables\PointBlankSniper.lua"
)

LISTS = {
    "housing": "FLIP Housing",
    "other-slow": "FLIP Other Slow",
    "other-fast": "FLIP Other Fast",
}
DEFAULT_PBS_LIST = "FLIP Other Fast"
PLACEHOLDER_RE = re.compile(r"^(Item|Pet) \d+$")
TITLE_SUFFIXES = (
    " - Item - World of Warcraft",
    " - NPC - World of Warcraft",
    " - Battle Pet - World of Warcraft",
    " - World of Warcraft",
)


def _wow_is_running() -> bool:
    result = subprocess.run(
        ["powershell", "-NoProfile", "-Command", "Get-Process -Name Wow -ErrorAction SilentlyContinue"],
        capture_output=True,
        text=True,
        check=False,
    )
    return bool(result.stdout.strip())


def _read_rows() -> dict[str, list[dict[str, str]]]:
    if not GROUP_CSV.exists():
        raise SystemExit(f"Missing groups CSV: {GROUP_CSV}. Run build-flipping-groups.py first.")
    rows: dict[str, list[dict[str, str]]] = {group: [] for group in LISTS}
    with GROUP_CSV.open("r", encoding="utf-8", newline="") as handle:
        for row in csv.DictReader(handle):
            group = row.get("group") or ""
            if group in rows:
                rows[group].append(row)
    missing = [group for group, group_rows in rows.items() if not group_rows]
    if missing:
        raise SystemExit(f"Missing generated rows for groups: {', '.join(missing)}")
    return rows


def _load_cache() -> dict[str, dict[str, str]]:
    if not NAME_CACHE.exists():
        return {}
    return json.loads(NAME_CACHE.read_text(encoding="utf-8"))


def _save_cache(cache: dict[str, dict[str, str]]) -> None:
    NAME_CACHE.parent.mkdir(parents=True, exist_ok=True)
    NAME_CACHE.write_text(json.dumps(cache, ensure_ascii=False, indent=2, sort_keys=True), encoding="utf-8")


def _clean_title(raw: str) -> str:
    value = html.unescape(re.sub(r"<.*?>", "", raw)).strip()
    for suffix in TITLE_SUFFIXES:
        if value.endswith(suffix):
            value = value[: -len(suffix)]
            break
    return re.sub(r"\s+", " ", value).strip()


def _extract_name(text: str) -> str | None:
    patterns = (
        r'<meta property="og:title" content="([^"]+)"',
        r"<title>(.*?)</title>",
        r"<h1[^>]*>(.*?)</h1>",
    )
    for pattern in patterns:
        match = re.search(pattern, text, re.S | re.I)
        if match:
            value = _clean_title(match.group(1))
            if value and value.lower() not in {"wowhead", "world of warcraft"}:
                return value
    return None


def _wowhead_url(item_string: str) -> str:
    kind, raw_id = item_string.split(":", 1)
    if kind == "p":
        return f"https://www.wowhead.com/battle-pet/{raw_id}"
    return f"https://www.wowhead.com/item={raw_id}"


def _fetch_url(url: str, cache_path: Path | None = None) -> str:
    if cache_path is not None and cache_path.exists():
        return cache_path.read_text(encoding="utf-8", errors="ignore")
    request = urllib.request.Request(
        url,
        headers={
            "User-Agent": (
                "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
                "AppleWebKit/537.36 (KHTML, like Gecko) "
                "Chrome/126.0 Safari/537.36"
            ),
            "Accept-Language": "en-US,en;q=0.9,fr;q=0.8",
        },
    )
    last_error: Exception | None = None
    for attempt in range(1, 4):
        try:
            with urllib.request.urlopen(request, timeout=12) as response:
                text = response.read().decode("utf-8", errors="ignore")
            return text
        except urllib.error.HTTPError as error:
            if error.code in {403, 404}:
                raise RuntimeError(f"HTTP Error {error.code}: {error.reason}") from error
            last_error = error
            time.sleep(attempt * 1.0)
        except (urllib.error.URLError, TimeoutError, RuntimeError) as error:
            last_error = error
            time.sleep(attempt * 1.0)
    raise RuntimeError(f"{url}: {last_error}")


def _fetch_name(item_string: str) -> dict[str, str]:
    url = _wowhead_url(item_string)
    text = _fetch_url(url)
    name = _extract_name(text)
    if not name:
        raise RuntimeError(f"Could not parse Wowhead title for {item_string}")
    return {"name": name, "source": url}


def _fetch_item_name_exact(item_id: int) -> dict[str, str]:
    url = f"https://www.wowhead.com/items?filter=151:151;2:4;{item_id}:{item_id}"
    cache_path = ITEM_PAGE_CACHE / f"item-{item_id}.html"
    text = _fetch_url(url, cache_path)
    if not cache_path.exists():
        cache_path.write_text(text, encoding="utf-8")
    for row in _extract_json_array(text):
        if int(row.get("id") or 0) == item_id:
            name = row.get("name") or row.get("displayName")
            if name:
                return {"name": str(name), "source": url}
    return _fetch_name(f"i:{item_id}")


def _extract_json_array(text: str) -> list[dict[str, Any]]:
    match = re.search(r"var listviewitems = (\[.*?\]);\s*new Listview", text, re.S)
    if not match:
        return []
    js = re.sub(r"([\{,])([A-Za-z_][A-Za-z0-9_]*):", r'\1"\2":', match.group(1))
    return json.loads(js)


def _declared_item_count(text: str) -> int | None:
    match = re.search(r'"numberOfItems":(\d+)', text)
    return int(match.group(1)) if match else None


def _item_ranges(ids: list[int], size: int = 2000) -> list[tuple[int, int]]:
    ranges = {(item_id // size) * size for item_id in ids}
    return [(low, low + size - 1) for low in sorted(ranges)]


def _resolve_item_names_by_ranges(item_ids: set[int], cache: dict[str, dict[str, str]]) -> None:
    missing = {item_id for item_id in item_ids if f"i:{item_id}" not in cache}
    if not missing:
        return
    ITEM_PAGE_CACHE.mkdir(parents=True, exist_ok=True)
    print(f"Resolving item names by Wowhead ranges: {len(missing)}", flush=True)
    completed = 0
    for low, high in _item_ranges(sorted(missing)):
        if low < 20000:
            continue
        url = f"https://www.wowhead.com/items?filter=151:151;2:4;{low}:{high}"
        cache_path = ITEM_PAGE_CACHE / f"items-{low}-{high}.html"
        try:
            text = _fetch_url(url, cache_path)
        except RuntimeError as error:
            print(f"Skipping item range {low}-{high}: {error}", flush=True)
            continue
        if not cache_path.exists():
            cache_path.write_text(text, encoding="utf-8")
        rows = _extract_json_array(text)
        declared = _declared_item_count(text)
        if declared and declared > len(rows) and high > low:
            mid = (low + high) // 2
            for sub_low, sub_high in ((low, mid), (mid + 1, high)):
                sub_ids = {item_id for item_id in missing if sub_low <= item_id <= sub_high}
                if sub_ids:
                    _resolve_item_names_by_ranges(sub_ids, cache)
            continue
        for row in rows:
            item_id = int(row.get("id") or 0)
            if item_id in missing:
                name = row.get("name") or row.get("displayName")
                if name:
                    cache[f"i:{item_id}"] = {"name": str(name), "source": url}
        completed += 1
        if completed % 10 == 0:
            _save_cache(cache)
            print(f"Processed item ranges: {completed}", flush=True)
    _save_cache(cache)


def _resolve_pet_names_from_index(pet_ids: set[int], cache: dict[str, dict[str, str]]) -> None:
    missing = {pet_id for pet_id in pet_ids if f"p:{pet_id}" not in cache}
    if not missing:
        return
    print(f"Resolving pet names from Wowhead index: {len(missing)}", flush=True)
    url = "https://www.wowhead.com/battle-pets"
    text = _fetch_url(url, PET_INDEX_CACHE)
    if not PET_INDEX_CACHE.exists():
        PET_INDEX_CACHE.write_text(text, encoding="utf-8")
    for match in re.finditer(r'"species":(\d+).*?"name":"((?:\\.|[^"])*)"', text):
        pet_id = int(match.group(1))
        if pet_id in missing:
            name = html.unescape(match.group(2).encode("utf-8").decode("unicode_escape"))
            cache[f"p:{pet_id}"] = {"name": name, "source": url}
    _save_cache(cache)


def _needs_resolution(row: dict[str, str]) -> bool:
    name = row.get("name") or ""
    return not name or bool(PLACEHOLDER_RE.match(name))


def _resolve_names_from_local_item_links(rows_by_group: dict[str, list[dict[str, str]]], cache: dict[str, dict[str, str]]) -> None:
    item_ids = {
        int(row["item_string"].split(":", 1)[1])
        for rows in rows_by_group.values()
        for row in rows
        if row["item_string"].startswith("i:") and row["item_string"] not in cache
    }
    if not item_ids:
        return
    roots = [
        Path(r"C:\Program Files (x86)\World of Warcraft\_retail_\WTF\Account\417185157#1\SavedVariables"),
        Path(r"C:\Program Files (x86)\World of Warcraft\_retail_\Interface\AddOns\TradeSkillMaster"),
    ]
    pattern = re.compile(r"Hitem:(\d+)[^|]*\|h\[([^\]]+)\]\|h")
    for root in roots:
        if not root.exists():
            continue
        for path in root.rglob("*.lua"):
            try:
                text = path.read_text(encoding="utf-8", errors="ignore")
            except OSError:
                continue
            for match in pattern.finditer(text):
                item_id = int(match.group(1))
                item_string = f"i:{item_id}"
                if item_id in item_ids and item_string not in cache:
                    name = re.sub(r" \|A:.*$", "", match.group(2)).strip()
                    if name:
                        cache[item_string] = {"name": name, "source": str(path)}


def _resolve_names(rows_by_group: dict[str, list[dict[str, str]]], *, workers: int, skip_web: bool) -> dict[str, dict[str, str]]:
    cache = _load_cache()
    needed: list[str] = []
    for rows in rows_by_group.values():
        for row in rows:
            item_string = row["item_string"]
            if _needs_resolution(row) and item_string not in cache:
                needed.append(item_string)
            elif not _needs_resolution(row) and item_string not in cache:
                cache[item_string] = {"name": row["name"], "source": "local flipping-groups.csv"}

    _resolve_names_from_local_item_links(rows_by_group, cache)
    if skip_web:
        _save_cache(cache)
        return cache

    needed = sorted(set(needed))
    if needed:
        item_ids = {int(item.split(":", 1)[1]) for item in needed if item.startswith("i:")}
        pet_ids = {int(item.split(":", 1)[1]) for item in needed if item.startswith("p:")}
        _resolve_item_names_by_ranges(item_ids, cache)
        try:
            _resolve_pet_names_from_index(pet_ids, cache)
        except RuntimeError as error:
            print(f"Skipping pet index: {error}", flush=True)

        still_missing = [item for item in needed if item not in cache]
        if still_missing:
            print(f"Resolving single Wowhead pages: {len(still_missing)}", flush=True)
            for index, item in enumerate(still_missing, start=1):
                if item.startswith("i:"):
                    cache[item] = _fetch_item_name_exact(int(item.split(":", 1)[1]))
                else:
                    cache[item] = _fetch_name(item)
                if index % 10 == 0:
                    print(f"Resolved singles: {index}/{len(still_missing)}", flush=True)
                    _save_cache(cache)
        _save_cache(cache)
    return cache


def _auctionator_search_string(name: str) -> str:
    # Matches Auctionator.API.v1.ConvertToSearchString({ searchString=name, isExact=true }).
    return f'"{name}";;;;;;;;;;;#;;'


def _dedupe(values: list[str]) -> list[str]:
    seen: set[str] = set()
    result: list[str] = []
    for value in values:
        if value not in seen:
            seen.add(value)
            result.append(value)
    return result


def _build_lists(
    rows_by_group: dict[str, list[dict[str, str]]], cache: dict[str, dict[str, str]]
) -> tuple[dict[str, list[str]], dict[str, list[str]], list[str]]:
    search_lists: dict[str, list[str]] = {}
    tsm_lists: dict[str, list[str]] = {}
    unresolved: list[str] = []
    for group, rows in rows_by_group.items():
        search_terms: list[str] = []
        item_strings: list[str] = []
        for row in rows:
            item_string = row["item_string"]
            item_strings.append(item_string)
            name = cache.get(item_string, {}).get("name")
            if not name:
                unresolved.append(item_string)
                continue
            search_terms.append(_auctionator_search_string(name))
        search_lists[LISTS[group]] = _dedupe(search_terms)
        tsm_lists[LISTS[group]] = _dedupe(item_strings)
    return search_lists, tsm_lists, unresolved


def _write_generated_files(search_lists: dict[str, list[str]], tsm_lists: dict[str, list[str]]) -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    batch_lines: list[str] = []
    for list_name, terms in search_lists.items():
        slug = list_name.lower().replace(" ", "-")
        batch = list_name + "^" + "^".join(terms)
        batch_lines.append(batch)
        (OUTPUT_DIR / f"auctionator-import-{slug}.txt").write_text(batch + "\n", encoding="utf-8")
        (OUTPUT_DIR / f"pbs-{slug}.txt").write_text("\n".join(terms) + "\n", encoding="utf-8")
    for list_name, items in tsm_lists.items():
        slug = list_name.lower().replace(" ", "-")
        (OUTPUT_DIR / f"tsm-import-{slug}.txt").write_text(",".join(items) + "\n", encoding="utf-8")
    (OUTPUT_DIR / "auctionator-batch-import-all.txt").write_text("\n".join(batch_lines) + "\n", encoding="utf-8")


def _lua_escape(value: str) -> str:
    return (
        value.replace("\\", "\\\\")
        .replace('"', '\\"')
        .replace("\n", "\\n")
        .replace("\r", "\\r")
        .replace("\t", "\\t")
    )


def _serialize_list_block(list_name: str, items: list[str]) -> str:
    lines = ["{", '["items"] = {']
    for item in items:
        lines.append(f'"{_lua_escape(item)}",')
    lines.extend(["},", f'["name"] = "{_lua_escape(list_name)}",', '["isTemporary"] = false,', "},"])
    return "\n".join(lines)


def _lua_unescape(value: str) -> str:
    return bytes(value, "utf-8").decode("unicode_escape")


def _extract_list_blocks(shopping_block: str) -> list[str]:
    start = shopping_block.find("{")
    if start < 0:
        return []
    blocks: list[str] = []
    in_string = False
    escaped = False
    depth = 0
    block_start: int | None = None
    for index in range(start, len(shopping_block)):
        char = shopping_block[index]
        if in_string:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == '"':
                in_string = False
            continue
        if char == '"':
            in_string = True
            continue
        if char == "{":
            depth += 1
            if depth == 2:
                block_start = index
        elif char == "}":
            if depth == 2 and block_start is not None:
                end = index + 1
                while end < len(shopping_block) and shopping_block[end] in ",\r\n\t ":
                    end += 1
                    if shopping_block[end - 1] == ",":
                        break
                blocks.append(shopping_block[block_start:end].strip())
                block_start = None
            depth -= 1
    return blocks


def _block_name(block: str) -> str | None:
    match = re.search(r'\["name"\]\s*=\s*"((?:\\.|[^"])*)"', block)
    return _lua_unescape(match.group(1)) if match else None


def _patch_auctionator(search_lists: dict[str, list[str]], *, dry_run: bool) -> Path | None:
    if not AUCTIONATOR_PATH.exists():
        raise SystemExit(f"Auctionator SavedVariables not found: {AUCTIONATOR_PATH}")

    text = AUCTIONATOR_PATH.read_text(encoding="utf-8", errors="replace")
    start = text.find("AUCTIONATOR_SHOPPING_LISTS = {")
    marker = text.find("\nAUCTIONATOR_PRICE_DATABASE", start)
    if start < 0 or marker < 0:
        raise SystemExit("Could not locate AUCTIONATOR_SHOPPING_LISTS block.")

    current_block = text[start:marker]
    target_names = set(search_lists)
    kept_blocks = [block for block in _extract_list_blocks(current_block) if _block_name(block) not in target_names]
    new_blocks = [_serialize_list_block(name, search_lists[name]) for name in LISTS.values() if name in search_lists]
    new_block = "AUCTIONATOR_SHOPPING_LISTS = {\n" + "\n".join(kept_blocks + new_blocks) + "\n}\n"
    patched = text[:start] + new_block + text[marker + 1 :]

    if dry_run:
        return None
    timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    backup = AUCTIONATOR_PATH.with_name(f"{AUCTIONATOR_PATH.name}.{timestamp}.sniping-lists.bak")
    shutil.copy2(AUCTIONATOR_PATH, backup)
    AUCTIONATOR_PATH.write_text(patched, encoding="utf-8")
    return backup


def _patch_pbs_current_list(list_name: str, *, dry_run: bool) -> Path | None:
    if not PBS_PATH.exists():
        raise SystemExit(f"PointBlankSniper SavedVariables not found: {PBS_PATH}")
    text = PBS_PATH.read_text(encoding="utf-8", errors="replace")
    escaped = _lua_escape(list_name)
    if re.search(r'\["current_list"\]\s*=', text):
        patched = re.sub(r'\["current_list"\]\s*=\s*"((?:\\.|[^"])*)"', f'["current_list"] = "{escaped}"', text, count=1)
    else:
        patched = text.replace("POINT_BLANK_SNIPER_CONFIG = {\n", f'POINT_BLANK_SNIPER_CONFIG = {{\n["current_list"] = "{escaped}",\n', 1)
    if dry_run:
        return None
    timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    backup = PBS_PATH.with_name(f"{PBS_PATH.name}.{timestamp}.sniping-lists.bak")
    shutil.copy2(PBS_PATH, backup)
    PBS_PATH.write_text(patched, encoding="utf-8")
    return backup


def _validate_saved_variables(expected_counts: dict[str, int], pbs_current_list: str) -> None:
    text = AUCTIONATOR_PATH.read_text(encoding="utf-8", errors="replace")
    start = text.find("AUCTIONATOR_SHOPPING_LISTS = {")
    marker = text.find("\nAUCTIONATOR_PRICE_DATABASE", start)
    block = text[start:marker]
    for name, expected in expected_counts.items():
        if f'["name"] = "{_lua_escape(name)}"' not in block:
            raise SystemExit(f"Validation failed: missing Auctionator list {name}")
        list_index = block.find(f'["name"] = "{_lua_escape(name)}"')
        list_start = block.rfind('["items"] = {', 0, list_index)
        list_end = block.find("},", list_start)
        item_count = block[list_start:list_end].count('",')
        if item_count != expected:
            raise SystemExit(f"Validation failed: {name} has {item_count}, expected {expected}")

    pbs_text = PBS_PATH.read_text(encoding="utf-8", errors="replace")
    if f'["current_list"] = "{_lua_escape(pbs_current_list)}"' not in pbs_text:
        raise SystemExit("Validation failed: PBS current_list was not updated.")


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate and apply Auctionator/PBS sniping shopping lists for flip groups.")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--skip-web", action="store_true")
    parser.add_argument("--allow-partial", action="store_true")
    parser.add_argument("--workers", type=int, default=6)
    args = parser.parse_args()

    if _wow_is_running():
        raise SystemExit("WoW.exe is running. Close the game before patching Auctionator/PBS SavedVariables.")

    rows_by_group = _read_rows()
    cache = _resolve_names(rows_by_group, workers=args.workers, skip_web=args.skip_web)
    search_lists, tsm_lists, unresolved = _build_lists(rows_by_group, cache)
    _write_generated_files(search_lists, tsm_lists)
    if unresolved:
        (OUTPUT_DIR / "unresolved.txt").write_text("\n".join(unresolved) + "\n", encoding="utf-8")
        if not args.allow_partial:
            raise SystemExit(f"Unresolved names: {len(unresolved)}. See {OUTPUT_DIR / 'unresolved.txt'}")

    unresolved_by_list = {name: 0 for name in LISTS.values()}
    group_by_item = {
        row["item_string"]: group
        for group, rows in rows_by_group.items()
        for row in rows
    }
    for item in unresolved:
        group = group_by_item.get(item)
        if group:
            unresolved_by_list[LISTS[group]] += 1
    installable_lists = {
        name: items
        for name, items in search_lists.items()
        if unresolved_by_list.get(name, 0) == 0
    }
    if not installable_lists:
        raise SystemExit("No complete Auctionator shopping list can be installed.")
    pbs_current_list = DEFAULT_PBS_LIST if DEFAULT_PBS_LIST in installable_lists else next(iter(installable_lists))

    auctionator_backup = _patch_auctionator(installable_lists, dry_run=args.dry_run)
    pbs_backup = _patch_pbs_current_list(pbs_current_list, dry_run=args.dry_run)
    if not args.dry_run:
        _validate_saved_variables({name: len(items) for name, items in installable_lists.items()}, pbs_current_list)

    summary = {
        "complete_auctionator_lists": {name: len(items) for name, items in installable_lists.items()},
        "generated_tsm_imports": {name: len(items) for name, items in tsm_lists.items()},
        "unresolved_name_count": len(unresolved),
        "skipped_auctionator_lists": {name: count for name, count in unresolved_by_list.items() if count},
        "outputs": str(OUTPUT_DIR),
        "auctionator": str(AUCTIONATOR_PATH),
        "auctionator_backup": str(auctionator_backup) if auctionator_backup else None,
        "point_blank_sniper": str(PBS_PATH),
        "point_blank_sniper_backup": str(pbs_backup) if pbs_backup else None,
        "pbs_current_list": pbs_current_list,
    }
    (OUTPUT_DIR / "sniping-lists-summary.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(summary, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
