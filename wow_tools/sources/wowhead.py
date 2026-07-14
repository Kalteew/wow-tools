from __future__ import annotations

import json
import re
from collections import defaultdict
from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Any

from wow_tools.cache import HttpCache
from wow_tools.config import WOWHEAD_ITEM_TTL_SECONDS, WOWHEAD_LIST_TTL_SECONDS
from wow_tools.http import fetch_text
from wow_tools.seeds import GATHERABLE_SEEDS, WOWHEAD_CATEGORY_URLS


LISTVIEW_RE = re.compile(r"var listviewitems = (\[.*?\]);\s*new Listview", re.S)
UNQUOTED_KEY_RE = re.compile(r'([{\[,])([A-Za-z_][A-Za-z0-9_]*)\s*:')
TITLE_RE = re.compile(r"<title>(.*?)</title>", re.S | re.I)
DESCRIPTION_RE = re.compile(r'<meta name="description" content="(.*?)"', re.I)
CANONICAL_RE = re.compile(r'<link rel="canonical" href="(.*?)"', re.I)
IMAGE_RE = re.compile(r'<link rel="image_src" href="(.*?)"', re.I)
EXPANSION_RE = re.compile(r"World of Warcraft: ([^.]+)\.")


@dataclass
class CatalogMatch:
    profession: str
    expansion_seed: str
    family_name: str
    raw_item: dict[str, Any]


def _now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def _category_for_profession(profession: str) -> str:
    if profession == "herbalism":
        return "herb"
    if profession == "mining":
        return "ore"
    if profession == "skinning":
        return "leather"
    raise ValueError(f"Unsupported profession: {profession}")


def fetch_listview_items(profession: str, cache: HttpCache, *, force: bool = False) -> list[dict[str, Any]]:
    url = WOWHEAD_CATEGORY_URLS[profession]
    html = fetch_text(url, cache, WOWHEAD_LIST_TTL_SECONDS, force=force)
    match = LISTVIEW_RE.search(html)
    if not match:
        raise RuntimeError(f"Could not find Wowhead listviewitems payload for {url}")
    payload = UNQUOTED_KEY_RE.sub(r'\1"\2":', match.group(1))
    return json.loads(payload)


def resolve_seed_matches(profession: str, cache: HttpCache, *, force: bool = False) -> tuple[list[CatalogMatch], list[str]]:
    listview_items = fetch_listview_items(profession, cache, force=force)
    by_name: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for item in listview_items:
        by_name[item.get("displayName", item.get("name"))].append(item)

    matches: list[CatalogMatch] = []
    missing: list[str] = []
    seen_ids: set[int] = set()

    for expansion, family_names in GATHERABLE_SEEDS[profession].items():
        for family_name in family_names:
            raw_items = by_name.get(family_name, [])
            if not raw_items:
                missing.append(f"{profession}:{expansion}:{family_name}")
                continue
            for raw_item in raw_items:
                item_id = int(raw_item["id"])
                if item_id in seen_ids:
                    continue
                seen_ids.add(item_id)
                matches.append(
                    CatalogMatch(
                        profession=profession,
                        expansion_seed=expansion,
                        family_name=family_name,
                        raw_item=raw_item,
                    )
                )

    matches.sort(key=lambda match: (match.expansion_seed, match.family_name, int(match.raw_item["id"])))
    return matches, missing


def fetch_item_metadata(item_id: int, cache: HttpCache, *, force: bool = False) -> dict[str, Any]:
    url = f"https://www.wowhead.com/item={item_id}"
    html = fetch_text(url, cache, WOWHEAD_ITEM_TTL_SECONDS, force=force)

    title_match = TITLE_RE.search(html)
    description_match = DESCRIPTION_RE.search(html)
    canonical_match = CANONICAL_RE.search(html)
    image_match = IMAGE_RE.search(html)

    description = description_match.group(1) if description_match else None
    expansion_match = EXPANSION_RE.search(description or "")

    return {
        "wowhead_url": canonical_match.group(1) if canonical_match else url,
        "title": title_match.group(1) if title_match else None,
        "description": description,
        "icon_url": image_match.group(1) if image_match else None,
        "expansion_detected": expansion_match.group(1) if expansion_match else None,
    }


def sync_catalog(conn, cache: HttpCache, professions: list[str], *, force: bool = False) -> dict[str, Any]:
    from wow_tools.db import upsert_item

    summary: dict[str, Any] = {"professions": {}, "missing": []}

    for profession in professions:
        matches, missing = resolve_seed_matches(profession, cache, force=force)
        summary["missing"].extend(missing)
        inserted = 0
        item_pages_blocked = False

        for match in matches:
            item_id = int(match.raw_item["id"])
            if item_pages_blocked:
                metadata = {
                    "wowhead_url": f"https://www.wowhead.com/item={item_id}",
                    "title": match.raw_item.get("displayName", match.raw_item.get("name")),
                    "description": None,
                    "icon_url": None,
                    "expansion_detected": None,
                    "fetch_error": "item-page-fetch-disabled-after-block",
                }
            else:
                try:
                    metadata = fetch_item_metadata(item_id, cache, force=force)
                except Exception as exc:
                    if "403" in str(exc):
                        item_pages_blocked = True
                    metadata = {
                        "wowhead_url": f"https://www.wowhead.com/item={item_id}",
                        "title": match.raw_item.get("displayName", match.raw_item.get("name")),
                        "description": None,
                        "icon_url": None,
                        "expansion_detected": None,
                        "fetch_error": str(exc),
                    }
            item_row = {
                "item_id": item_id,
                "profession": match.profession,
                "expansion_seed": match.expansion_seed,
                "expansion_detected": metadata["expansion_detected"],
                "category": _category_for_profession(match.profession),
                "family_name": match.family_name,
                "item_name": match.raw_item.get("displayName", match.raw_item.get("name")),
                "wowhead_url": metadata["wowhead_url"],
                "icon_url": metadata["icon_url"],
                "description": metadata["description"],
                "item_level": match.raw_item.get("level"),
                "req_level": match.raw_item.get("reqlevel"),
                "wowhead_quality": match.raw_item.get("quality"),
                "wowhead_popularity": match.raw_item.get("popularity"),
                "source_kind": "wowhead-public-html",
                "is_gatherable": 1,
                "metadata_json": json.dumps(
                    {
                        "listview": match.raw_item,
                        "item_page": metadata,
                    },
                    sort_keys=True,
                ),
                "last_catalog_sync": _now_iso(),
            }
            upsert_item(conn, item_row)
            inserted += 1

        conn.commit()
        summary["professions"][profession] = {"items": inserted}

    return summary
