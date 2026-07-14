from __future__ import annotations

import json
import math
import re
from dataclasses import dataclass
from typing import Any

from wow_tools.account_pipeline import load_local_price_index
from wow_tools.cache import HttpCache
from wow_tools.config import CACHE_DIR, WOWHEAD_ITEM_TTL_SECONDS
from wow_tools.http import fetch_text


DEFAULT_BUCKETS = [1, 2, 3, 5, 8, 12, 20, 50, 100, 200, 500]
BIND_ON_PICKUP_RE = re.compile(r"Binds when picked up|Soulbound", re.I)
BIND_ON_EQUIP_RE = re.compile(r"Binds when equipped|Warbound until equipped", re.I)
TOOLTIP_RE_TEMPLATE = r"g_items\[%s\]\.tooltip_enus = \"(.*?)\";"
NOSCRIPT_RE = re.compile(r"<noscript><table.*?</table>", re.I | re.S)


@dataclass(frozen=True)
class CategoryRule:
    name: str
    utility_factor: float
    stack_factor: float
    cap: int
    min_stock: int


CATEGORY_RULES: dict[str, CategoryRule] = {
    "component": CategoryRule("component", utility_factor=1.2, stack_factor=2.0, cap=200, min_stock=5),
    "alchemy-component": CategoryRule("alchemy-component", utility_factor=1.2, stack_factor=2.2, cap=200, min_stock=5),
    "alchemy-potion": CategoryRule("alchemy-potion", utility_factor=1.1, stack_factor=2.5, cap=100, min_stock=5),
    "alchemy-flask": CategoryRule("alchemy-flask", utility_factor=0.95, stack_factor=2.0, cap=50, min_stock=3),
    "alchemy-utility": CategoryRule("alchemy-utility", utility_factor=0.8, stack_factor=1.4, cap=20, min_stock=2),
    "alchemy-tool": CategoryRule("alchemy-tool", utility_factor=0.45, stack_factor=0.35, cap=3, min_stock=1),
    "alchemy-furniture": CategoryRule("alchemy-furniture", utility_factor=0.35, stack_factor=0.25, cap=2, min_stock=1),
    "tailoring-gear": CategoryRule("tailoring-gear", utility_factor=0.45, stack_factor=0.35, cap=5, min_stock=1),
    "tailoring-bag": CategoryRule("tailoring-bag", utility_factor=0.55, stack_factor=0.35, cap=2, min_stock=1),
    "tailoring-furniture": CategoryRule("tailoring-furniture", utility_factor=0.35, stack_factor=0.25, cap=2, min_stock=1),
    "tailoring-consumable": CategoryRule("tailoring-consumable", utility_factor=1.0, stack_factor=1.4, cap=20, min_stock=2),
    "blacksmithing-armor": CategoryRule("blacksmithing-armor", utility_factor=0.45, stack_factor=0.35, cap=5, min_stock=1),
    "blacksmithing-weapon": CategoryRule("blacksmithing-weapon", utility_factor=0.4, stack_factor=0.35, cap=4, min_stock=1),
    "blacksmithing-tool": CategoryRule("blacksmithing-tool", utility_factor=0.5, stack_factor=0.4, cap=3, min_stock=1),
    "blacksmithing-furniture": CategoryRule("blacksmithing-furniture", utility_factor=0.35, stack_factor=0.25, cap=2, min_stock=1),
    "blacksmithing-consumable": CategoryRule("blacksmithing-consumable", utility_factor=0.95, stack_factor=1.8, cap=50, min_stock=2),
    "enchanting-weapon": CategoryRule("enchanting-weapon", utility_factor=0.4, stack_factor=0.8, cap=3, min_stock=1),
    "enchanting-visual": CategoryRule("enchanting-visual", utility_factor=0.35, stack_factor=0.8, cap=2, min_stock=1),
    "enchanting-utility": CategoryRule("enchanting-utility", utility_factor=0.45, stack_factor=0.4, cap=3, min_stock=1),
    "enchanting-standard": CategoryRule("enchanting-standard", utility_factor=1.0, stack_factor=1.2, cap=12, min_stock=2),
    "inscription-gear": CategoryRule("inscription-gear", utility_factor=0.45, stack_factor=0.35, cap=5, min_stock=1),
    "inscription-tool": CategoryRule("inscription-tool", utility_factor=0.5, stack_factor=0.4, cap=3, min_stock=1),
    "inscription-furniture": CategoryRule("inscription-furniture", utility_factor=0.35, stack_factor=0.25, cap=2, min_stock=1),
    "inscription-darkmoon": CategoryRule("inscription-darkmoon", utility_factor=0.35, stack_factor=0.8, cap=3, min_stock=1),
    "inscription-contract": CategoryRule("inscription-contract", utility_factor=0.8, stack_factor=1.2, cap=12, min_stock=2),
    "inscription-missive": CategoryRule("inscription-missive", utility_factor=1.0, stack_factor=2.2, cap=100, min_stock=5),
    "inscription-consumable": CategoryRule("inscription-consumable", utility_factor=0.95, stack_factor=1.6, cap=20, min_stock=2),
    "jewelcrafting-gem": CategoryRule("jewelcrafting-gem", utility_factor=1.0, stack_factor=2.0, cap=100, min_stock=5),
    "jewelcrafting-gear": CategoryRule("jewelcrafting-gear", utility_factor=0.45, stack_factor=0.35, cap=5, min_stock=1),
    "jewelcrafting-tool": CategoryRule("jewelcrafting-tool", utility_factor=0.5, stack_factor=0.4, cap=3, min_stock=1),
    "jewelcrafting-furniture": CategoryRule("jewelcrafting-furniture", utility_factor=0.35, stack_factor=0.25, cap=2, min_stock=1),
    "jewelcrafting-consumable": CategoryRule("jewelcrafting-consumable", utility_factor=0.85, stack_factor=1.4, cap=20, min_stock=2),
    "leatherworking-armor": CategoryRule("leatherworking-armor", utility_factor=0.45, stack_factor=0.35, cap=5, min_stock=1),
    "leatherworking-bag": CategoryRule("leatherworking-bag", utility_factor=0.55, stack_factor=0.35, cap=2, min_stock=1),
    "leatherworking-furniture": CategoryRule("leatherworking-furniture", utility_factor=0.35, stack_factor=0.25, cap=2, min_stock=1),
    "leatherworking-consumable": CategoryRule("leatherworking-consumable", utility_factor=0.95, stack_factor=1.8, cap=50, min_stock=2),
    "engineering-component": CategoryRule("engineering-component", utility_factor=1.1, stack_factor=2.0, cap=200, min_stock=5),
    "engineering-gear": CategoryRule("engineering-gear", utility_factor=0.45, stack_factor=0.35, cap=5, min_stock=1),
    "engineering-tool": CategoryRule("engineering-tool", utility_factor=0.5, stack_factor=0.4, cap=3, min_stock=1),
    "engineering-utility": CategoryRule("engineering-utility", utility_factor=0.85, stack_factor=1.5, cap=20, min_stock=2),
    "engineering-furniture": CategoryRule("engineering-furniture", utility_factor=0.35, stack_factor=0.25, cap=2, min_stock=1),
    "engineering-companion": CategoryRule("engineering-companion", utility_factor=0.35, stack_factor=0.5, cap=2, min_stock=1),
    "cooking-feast": CategoryRule("cooking-feast", utility_factor=0.8, stack_factor=3.0, cap=20, min_stock=3),
    "cooking-standard": CategoryRule("cooking-standard", utility_factor=1.2, stack_factor=5.0, cap=500, min_stock=20),
}


def _preferred_price(summary: dict[str, Any]) -> int | None:
    return summary.get("preferred_price_copper")


def _direct_craft_cost_copper(recipe: dict[str, Any], price_index: dict[int, dict[str, Any]]) -> int | None:
    total = 0.0
    saw_price = False
    for reagent in recipe.get("reagents", []):
        item_id = reagent["item_id"]
        summary = price_index.get(item_id, {}).get("summary", {})
        price = _preferred_price(summary)
        if price is None:
            return None
        total += float(reagent["quantity"]) * price
        saw_price = True
    if not saw_price:
        return None
    output = recipe.get("output", {}) or {}
    quantity = output.get("min_quantity") or 1
    if quantity <= 0:
        quantity = 1
    return int(round(total / quantity))


def _cost_factor(cost_copper: int | None) -> float:
    if cost_copper is None:
        return 0.85
    if cost_copper <= 100_000:
        return 1.4
    if cost_copper <= 500_000:
        return 1.2
    if cost_copper <= 2_000_000:
        return 1.0
    if cost_copper <= 5_000_000:
        return 0.7
    if cost_copper <= 10_000_000:
        return 0.45
    return 0.25


def _fallback_sold_per_day(sale_rate: float | None) -> float:
    if sale_rate is None:
        return 1.0
    return max(1.0, sale_rate * 10.0)


def _round_to_bucket(value: int, buckets: list[int]) -> int:
    best = buckets[0]
    best_distance = abs(best - value)
    for bucket in buckets[1:]:
        distance = abs(bucket - value)
        if distance < best_distance:
            best = bucket
            best_distance = distance
    return best


def _is_component(output_item_id: int | None, recipe_rows: list[dict[str, Any]]) -> bool:
    if output_item_id is None:
        return False
    reagent_ids = {
        reagent["item_id"]
        for row in recipe_rows
        for reagent in row.get("reagents", [])
    }
    return output_item_id in reagent_ids


def _parse_bind_type_from_html(html: str) -> str | None:
    if BIND_ON_PICKUP_RE.search(html):
        return "bop"
    if BIND_ON_EQUIP_RE.search(html):
        return "boe"
    return None


def _extract_primary_bind_scope(item_id: int, html: str) -> str:
    tooltip_re = re.compile(TOOLTIP_RE_TEMPLATE % re.escape(str(item_id)), re.I | re.S)
    match = tooltip_re.search(html)
    if match:
        return match.group(1)
    noscript_match = NOSCRIPT_RE.search(html)
    if noscript_match:
        return noscript_match.group(0)
    return html


def _load_bind_type(item_id: int, wowhead_cache: HttpCache) -> str | None:
    url = f"https://www.wowhead.com/item={item_id}"
    try:
        html = fetch_text(url, wowhead_cache, WOWHEAD_ITEM_TTL_SECONDS)
    except Exception:
        return None
    return _parse_bind_type_from_html(_extract_primary_bind_scope(item_id, html))


def _classify_category(profession: str, recipe: dict[str, Any], raw_payload: dict[str, Any], recipe_rows: list[dict[str, Any]]) -> str:
    item_name = (recipe.get("output", {}) or {}).get("item_name") or recipe["recipe_name"]
    lower_name = item_name.casefold()
    output_item_id = (recipe.get("output", {}) or {}).get("item_id")
    jsonequip = raw_payload.get("jsonequip") or {}
    slotbak = jsonequip.get("slotbak")

    if _is_component(output_item_id, recipe_rows):
        return "component"

    if profession == "tailoring":
        if any(token in lower_name for token in ("bag", "backpack", "satchel", "rucksack", "saddlebag")) or slotbak == 18:
            return "tailoring-bag"
        if any(token in lower_name for token in ("spellthread", "lining", "bandage")):
            return "tailoring-consumable"
        if any(token in lower_name for token in ("pillow", "cushion", "bed", "curtains", "carpet")):
            return "tailoring-furniture"
        return "tailoring-gear"

    if profession == "alchemy":
        if any(token in lower_name for token in ("extract", "flora", "rocks", "rune-prism", "rune prism")):
            return "alchemy-component"
        if any(token in lower_name for token in ("fountain", "vat", "censer")):
            return "alchemy-furniture"
        if any(token in lower_name for token in ("stone", "synergist")):
            return "alchemy-tool"
        if any(token in lower_name for token in ("flask", "phial", "cauldron")):
            return "alchemy-flask"
        if any(token in lower_name for token in ("potion", "tonic", "serum", "tincture", "draught")):
            return "alchemy-potion"
        return "alchemy-utility"

    if profession == "enchanting":
        if lower_name.startswith("enchant weapon"):
            return "enchanting-weapon"
        if lower_name.startswith("illusory adornment") or lower_name.startswith("endless codex"):
            return "enchanting-visual"
        if any(token in lower_name for token in ("rod", "wand", "focus", "tome", "broom", "campfire", "pick", "hammer", "repository", "sunwine")):
            return "enchanting-utility"
        return "enchanting-standard"

    if profession == "blacksmithing":
        if any(token in lower_name for token in ("ingot", "alloy")):
            return "component"
        if any(token in lower_name for token in ("whetstone", "weightstone", "razorstone", "repair hammer", "skeleton key")):
            return "blacksmithing-consumable"
        if any(token in lower_name for token in ("anvil", "hanger")):
            return "blacksmithing-furniture"
        if any(token in lower_name for token in ("hammer", "toolbox", "pickaxe", "sickle", "knife", "needle set", "toolset", "fishhook")):
            return "blacksmithing-tool"
        if any(token in lower_name for token in ("basinet", "bracers", "bulwark", "chestplate", "gauntlets", "greatbelt", "greaves", "leggings", "pauldrons", "cover", "girdle", "legguards", "mantle", "march", "rebuke", "resolve", "shelter", "plate ", "waistguard", "sabatons", "armguards", "breastplate", "helm", "palisade")):
            return "blacksmithing-armor"
        return "blacksmithing-weapon"

    if profession == "inscription":
        if any(token in lower_name for token in ("ink", "codified")):
            return "component"
        if any(token in lower_name for token in ("quill", "rolling pin", "mixing rod")):
            return "inscription-tool"
        if any(token in lower_name for token in ("shelf", "shelves", "bookcase", "bench", "signpost", "tome", "book", "scroll", "cask")):
            return "inscription-furniture"
        if any(token in lower_name for token in ("darkmoon dominion", "darkmoon sigil")):
            return "inscription-darkmoon"
        if any(token in lower_name for token in ("contract:", "treatise")):
            return "inscription-contract"
        if "missive" in lower_name:
            return "inscription-missive"
        if any(token in lower_name for token in ("vantus rune", "trust", "cipher")):
            return "inscription-consumable"
        return "inscription-gear"

    if profession == "jewelcrafting":
        if any(token in lower_name for token in ("prism", "crushing")):
            return "jewelcrafting-consumable"
        if any(token in lower_name for token in ("lyre", "harp", "statue", "hourglass", "armillary")):
            return "jewelcrafting-furniture"
        if any(token in lower_name for token in ("loupes", "lens", "bifocals", "spectacles", "focuser", "iris", "magnifying glass", "shard")):
            return "jewelcrafting-tool"
        if any(token in lower_name for token in ("amulet", "band", "charm", "torque", "signet", "chalice", "vial")):
            return "jewelcrafting-gear"
        if any(token in lower_name for token in ("amethyst", "garnet", "lapis", "peridot", "diamond", "heliotrope")):
            return "jewelcrafting-gem"
        return "component"

    if profession == "leatherworking":
        if any(token in lower_name for token in ("hide", "strand")):
            return "component"
        if any(token in lower_name for token in ("bag", "backpack", "satchel", "pack")):
            return "leatherworking-bag"
        if any(token in lower_name for token in ("rug", "bed", "shelf", "pillow", "table", "chair")):
            return "leatherworking-furniture"
        if any(token in lower_name for token in ("armor kit", "banding", "binding", "drums", "weapon wrap", "harness", "charm")):
            return "leatherworking-consumable"
        return "leatherworking-armor"

    if profession == "engineering":
        if any(token in lower_name for token in ("cogwheel", "gear", "sprocket", "crystal", "binding")):
            return "engineering-component"
        if any(token in lower_name for token in ("lightpost", "stargazer", "projector", "warp orb", "lamp")):
            return "engineering-furniture"
        if any(token in lower_name for token in ("curator of booms", "scorcher of souls", "nonchalant pup", "travel-sized", "w-47ch d0g", "m3ddy", "hush", "bop")):
            return "engineering-companion"
        if any(token in lower_name for token in ("multitool", "rod", "snippers", "hardhat", "headlamp", "reeler", "rock assister", "grippers")):
            return "engineering-tool"
        if any(token in lower_name for token in ("wormhole", "boomshots", "keychain", "ankle primers", "red button", "soul link", "bands", "bracelets", "clonkers")):
            return "engineering-utility"
        return "engineering-gear"

    if profession == "cooking":
        if any(token in lower_name for token in ("feast", "celebration", "parade", "medley", "roast")):
            return "cooking-feast"
        return "cooking-standard"

    return "component"


def _row_from_recipe(
    profession: str,
    recipe: dict[str, Any],
    raw_payload: dict[str, Any],
    price_index: dict[int, dict[str, Any]],
    recipe_rows: list[dict[str, Any]],
    buckets: list[int],
) -> dict[str, Any]:
    output = recipe.get("output", {}) or {}
    item_id = output.get("item_id")
    item_name = output.get("item_name") or recipe["recipe_name"]
    category_name = _classify_category(profession, recipe, raw_payload, recipe_rows)
    category = CATEGORY_RULES[category_name]
    summary = price_index.get(item_id, {}).get("summary", {})
    sold_per_day = summary.get("sold_per_day")
    sale_rate = summary.get("sale_rate")
    demand = sold_per_day if sold_per_day is not None else _fallback_sold_per_day(sale_rate)
    craft_cost_copper = _direct_craft_cost_copper(recipe, price_index)
    raw_stock = demand * category.utility_factor * category.stack_factor * _cost_factor(craft_cost_copper)
    optimal_stock = max(category.min_stock, min(category.cap, int(math.ceil(raw_stock))))
    bucket = _round_to_bucket(optimal_stock, buckets)
    bucket = max(category.min_stock, min(category.cap, bucket))
    return {
        "item_id": item_id,
        "item_name": item_name,
        "recipe_name": recipe["recipe_name"],
        "category": category_name,
        "sold_per_day": sold_per_day,
        "sale_rate": sale_rate,
        "craft_cost_copper": craft_cost_copper,
        "craft_cost_text": _format_copper(craft_cost_copper),
        "market_price_copper": summary.get("preferred_price_copper"),
        "market_price_text": summary.get("preferred_price_text"),
        "raw_restock_score": round(raw_stock, 3),
        "optimal_stock": optimal_stock,
        "bucket": bucket,
        "cap": category.cap,
        "min_stock": category.min_stock,
    }


def build_restock_plan(
    conn,
    *,
    profession: str,
    expansion: str,
    retail_root: str | None = None,
    account_root: str | None = None,
    buckets: list[int] | None = None,
) -> dict[str, Any]:
    recipe_rows = _load_recipes_for_expansion(conn, profession, expansion)
    item_ids = sorted({row["output"]["item_id"] for row in recipe_rows if row.get("output", {}).get("item_id")})
    referenced_ids = sorted(
        {
            item_id
            for row in recipe_rows
            for item_id in [row.get("output", {}).get("item_id"), *[r["item_id"] for r in row.get("reagents", [])]]
            if item_id
        }
    )
    price_index = load_local_price_index(referenced_ids, retail_root, account_root)
    selected_buckets = buckets or list(DEFAULT_BUCKETS)
    wowhead_cache = HttpCache(CACHE_DIR)

    by_item: dict[int, dict[str, Any]] = {}
    for row in recipe_rows:
        item_id = row.get("output", {}).get("item_id")
        if not item_id:
            continue
        existing = by_item.get(item_id)
        raw_payload = {}
        try:
            raw_payload = json.loads(conn.execute("SELECT raw_payload_json FROM recipe_items WHERE item_id = ?", (item_id,)).fetchone()[0] or "{}")
        except Exception:
            raw_payload = {}
        if _load_bind_type(item_id, wowhead_cache) == "bop":
            continue
        candidate = _row_from_recipe(profession, row, raw_payload, price_index, recipe_rows, selected_buckets)
        if existing is None or candidate["optimal_stock"] > existing["optimal_stock"]:
            by_item[item_id] = candidate

    rows = sorted(by_item.values(), key=lambda row: (row["bucket"], row["category"], row["item_name"]))
    bucket_summary: dict[int, int] = {}
    category_summary: dict[str, int] = {}
    for row in rows:
        bucket_summary[row["bucket"]] = bucket_summary.get(row["bucket"], 0) + 1
        category_summary[row["category"]] = category_summary.get(row["category"], 0) + 1

    return {
        "profession": profession,
        "expansion": expansion,
        "item_count": len(rows),
        "bucket_summary": dict(sorted(bucket_summary.items())),
        "category_summary": dict(sorted(category_summary.items())),
        "rows": rows,
    }


def _load_recipes_for_expansion(conn, profession: str, expansion: str) -> list[dict[str, Any]]:
    rows = conn.execute(
        """
        SELECT
            r.spell_id,
            r.profession,
            r.listview_name,
            r.recipe_name,
            r.output_item_id,
            r.output_min_quantity,
            r.output_max_quantity,
            i.item_name AS output_item_name
        FROM profession_recipes r
        LEFT JOIN recipe_items i ON i.item_id = r.output_item_id
        WHERE r.profession = ?
          AND LOWER(r.listview_name) LIKE ?
          AND r.output_item_id IS NOT NULL
        ORDER BY r.recipe_name, r.spell_id
        """,
        (profession, f"%{expansion.casefold()}%"),
    )
    results: list[dict[str, Any]] = []
    for row in rows:
        recipe = {
            "spell_id": row["spell_id"],
            "profession": row["profession"],
            "expansion": row["listview_name"],
            "recipe_name": row["recipe_name"],
            "output": {
                "item_id": row["output_item_id"],
                "item_name": row["output_item_name"] or f"Item {row['output_item_id']}",
                "min_quantity": row["output_min_quantity"],
                "max_quantity": row["output_max_quantity"],
            },
            "reagents": [],
        }
        reagent_rows = conn.execute(
            """
            SELECT rr.reagent_item_id, rr.quantity, ri.item_name
            FROM recipe_reagents rr
            LEFT JOIN recipe_items ri ON ri.item_id = rr.reagent_item_id
            WHERE rr.spell_id = ?
            ORDER BY rr.reagent_order
            """,
            (row["spell_id"],),
        )
        recipe["reagents"] = [
            {
                "item_id": reagent["reagent_item_id"],
                "item_name": reagent["item_name"] or f"Item {reagent['reagent_item_id']}",
                "quantity": reagent["quantity"],
            }
            for reagent in reagent_rows
        ]
        results.append(recipe)
    return results


def render_restock_plan(report: dict[str, Any]) -> str:
    lines = [
        f"Restock plan: {report['profession']} | {report['expansion']}",
        f"- items: {report['item_count']}",
        "- buckets: "
        + ", ".join(f"{bucket}={count}" for bucket, count in report["bucket_summary"].items()),
        "- categories: "
        + ", ".join(f"{name}={count}" for name, count in report["category_summary"].items()),
        "",
    ]
    for row in report["rows"]:
        sold = f"{row['sold_per_day']:.3f}" if row["sold_per_day"] is not None else "?"
        rate = f"{row['sale_rate']:.3f}" if row["sale_rate"] is not None else "?"
        lines.append(
            f"- {row['item_name']} ({row['item_id']}) | {row['category']} | bucket={row['bucket']} | "
            f"optimal={row['optimal_stock']} | sold/day={sold} | sale_rate={rate} | craft={row['craft_cost_text'] or '?'}"
        )
    return "\n".join(lines)


def _format_copper(value: int | None) -> str | None:
    if value is None:
        return None
    gold, remainder = divmod(int(value), 10_000)
    silver, copper = divmod(remainder, 100)
    return f"{gold}g {silver}s {copper}c"
