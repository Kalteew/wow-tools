from __future__ import annotations

import json
import sqlite3
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
DB_PATH = REPO_ROOT / "data" / "wow.sqlite3"
OUTPUT_PATH = REPO_ROOT / "data" / "tsm" / "logging_groups.json"

EXPANSIONS = [
    ("Classic", ("classic-",), ("alchemy", "enchanting", "engineering", "blacksmithing-plans", "jewelcrafting-designs", "leatherworking-patterns", "tailoring-patterns"), 245586),
    ("Outland", ("outland-",), (), 242691),
    ("Northrend", ("northrend-",), (), 251762),
    ("Cataclysm", ("cataclysm-",), (), 251764),
    ("Pandaria", ("pandaria-", "pandaren-"), (), 251763),
    ("Draenor", ("draenor-",), (), 251766),
    ("Legion", ("broken-isles-", "legion-"), (), 251767),
    ("Kul Tiras", ("kul-tiran-",), (), 251768),
    ("Dragonflight", ("dragon-isles-",), (), 251773),
    ("Shadowlands", ("shadowlands-",), (), 251772),
    ("Khaz Algar", ("khaz-algar-",), (), 248012),
    ("Midnight", ("midnight-",), (), 256963),
]

GLOBAL_EXCLUDE_TOKENS = (
    "potion",
    "staff",
    "flying machine",
    "powderkeg",
    "arrowheads",
)

EXPANSION_EXCLUDE_TOKENS = {
    "Legion": ("auto-hammer",),
}


def main() -> None:
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row

    config: dict[str, object] = {
        "group_root": "Logging",
        "auctioning": "#Default",
        "mailing": "#Default",
        "crafting_operation": {
            "name_template": "{expansion} Logging R1 P25g",
            "min_profit": "25g",
            "min_restock": "1",
            "max_restock": "1",
        },
        "expansions": [],
    }

    for expansion_label, prefixes, exact_ids, wood_item_id in EXPANSIONS:
        clauses = []
        params: list[object] = [wood_item_id]
        if prefixes:
            clauses.extend("pr.listview_id LIKE ?" for _ in prefixes)
            params.extend(f"{prefix}%" for prefix in prefixes)
        if exact_ids:
            clauses.extend("pr.listview_id = ?" for _ in exact_ids)
            params.extend(exact_ids)
        listview_sql = " OR ".join(clauses)
        rows = conn.execute(
            f"""
            SELECT DISTINCT
                pr.output_item_id,
                COALESCE(out.item_name, pr.recipe_name) AS output_name,
                rg.item_name AS wood_name
            FROM profession_recipes pr
            JOIN recipe_reagents rr ON rr.spell_id = pr.spell_id
            JOIN recipe_items rg ON rg.item_id = rr.reagent_item_id
            LEFT JOIN recipe_items out ON out.item_id = pr.output_item_id
            WHERE pr.raw_payload_json LIKE '%"cat": 11%'
              AND rr.reagent_item_id = ?
              AND ({listview_sql})
            ORDER BY output_name
            """,
            params,
        ).fetchall()

        if not rows:
            continue

        exclude_tokens = GLOBAL_EXCLUDE_TOKENS + EXPANSION_EXCLUDE_TOKENS.get(expansion_label, ())
        product_item_ids = []
        for row in rows:
            name = str(row["output_name"] or "").casefold()
            if any(token in name for token in exclude_tokens):
                continue
            output_item_id = row["output_item_id"]
            if output_item_id is None:
                continue
            product_item_ids.append(int(output_item_id))

        wood_name = str(rows[0]["wood_name"])
        config["expansions"].append(
            {
                "label": expansion_label,
                "wood_item_id": wood_item_id,
                "wood_name": wood_name,
                "product_item_ids": product_item_ids,
            }
        )

    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_PATH.write_text(json.dumps(config, indent=2), encoding="utf-8")
    print(f"Wrote: {OUTPUT_PATH}")


if __name__ == "__main__":
    main()
