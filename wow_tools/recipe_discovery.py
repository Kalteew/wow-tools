from __future__ import annotations

import json
import re
from collections import deque
from typing import Any

from wow_tools.cache import HttpCache
from wow_tools.config import WOWHEAD_ITEM_TTL_SECONDS
from wow_tools.http import fetch_text
from wow_tools.recipe_catalog import analysis_targets
from wow_tools.reports import save_report
from wow_tools.sources.wowhead import fetch_item_metadata

CREATED_BY_RE = re.compile(
    r"id:\s*'created-by-spell'.*?data:\s*(\[[\s\S]*?\])\s*,\s*\}\);",
    re.S,
)


def fetch_created_by_spells(item_id: int, cache: HttpCache, *, force: bool = False) -> list[dict[str, Any]]:
    url = f"https://www.wowhead.com/item={item_id}"
    html = fetch_text(url, cache, WOWHEAD_ITEM_TTL_SECONDS, force=force)
    match = CREATED_BY_RE.search(html)
    if not match:
        return []
    return json.loads(match.group(1))


def _default_target_item_ids() -> list[int]:
    return [item.item_id for item in analysis_targets()]


def discover_recipe_graph(
    cache: HttpCache,
    *,
    item_ids: list[int] | None = None,
    force: bool = False,
    max_depth: int = 4,
) -> dict[str, Any]:
    roots = item_ids or _default_target_item_ids()
    queue: deque[tuple[int, int]] = deque((item_id, 0) for item_id in roots)
    seen: set[int] = set()
    items: dict[int, dict[str, Any]] = {}

    while queue:
        item_id, depth = queue.popleft()
        if item_id in seen:
            continue
        seen.add(item_id)

        metadata = fetch_item_metadata(item_id, cache, force=force)
        created_by = fetch_created_by_spells(item_id, cache, force=force)
        item_entry = {
            "item_id": item_id,
            "title": metadata.get("title"),
            "wowhead_url": metadata.get("wowhead_url"),
            "description": metadata.get("description"),
            "expansion_detected": metadata.get("expansion_detected"),
            "created_by": created_by,
        }
        items[item_id] = item_entry

        if depth >= max_depth:
            continue

        for spell in created_by:
            for reagent in spell.get("reagents", []):
                if not reagent:
                    continue
                reagent_item_id = int(reagent[0])
                if reagent_item_id not in seen:
                    queue.append((reagent_item_id, depth + 1))

    report = {
        "roots": roots,
        "max_depth": max_depth,
        "items": [items[item_id] for item_id in sorted(items)],
    }
    return report


def save_discovered_recipe_graph(report: dict[str, Any], label: str) -> str:
    path = save_report(report, f"recipe-discovery-{label}.json")
    return str(path)
