from __future__ import annotations

import argparse
import json
import os
import sqlite3
import tempfile
from datetime import date
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
DB_PATH = REPO_ROOT / "data" / "wow.sqlite3"
DEFAULT_OUTPUT = REPO_ROOT / "addons" / "YayaReagentSniper" / "YayaReagentSniperCatalog.lua"


EXPANSIONS = (
    {
        "key": "classic",
        "label": "Vanilla",
        "source_label": "Classic",
        "raw_names": ("Classic",),
        "recipe_exact": (
            "Alchemy",
            "Blacksmithing Plans",
            "Classic Inscription",
            "Enchanting",
            "Engineering",
            "Jewelcrafting Designs",
            "Leatherworking Patterns",
            "Mining",
            "Old World Recipes",
            "Tailoring Patterns",
        ),
        "recipe_prefixes": (),
    },
    {
        "key": "burning_crusade",
        "label": "Burning Crusade",
        "source_label": "The Burning Crusade",
        "raw_names": ("The Burning Crusade",),
        "recipe_exact": ("Outlandish Dishes",),
        "recipe_prefixes": ("Outland ",),
    },
    {
        "key": "wrath",
        "label": "Wrath",
        "source_label": "Wrath of the Lich King",
        "raw_names": ("Wrath of the Lich King",),
        "recipe_exact": ("Recipes of the Cold North",),
        "recipe_prefixes": ("Northrend ",),
    },
    {
        "key": "cataclysm",
        "label": "Cataclysm",
        "source_label": "Cataclysm",
        "raw_names": ("Cataclysm",),
        "recipe_exact": (),
        "recipe_prefixes": ("Cataclysm ",),
    },
    {
        "key": "mists",
        "label": "Mists",
        "source_label": "Mists of Pandaria",
        "raw_names": ("Mists of Pandaria",),
        "recipe_exact": (),
        "recipe_prefixes": ("Pandaria ", "Pandaren "),
    },
    {
        "key": "warlords",
        "label": "Warlords",
        "source_label": "Warlords of Draenor",
        "raw_names": ("Warlords of Draenor",),
        "recipe_exact": ("Food of Draenor",),
        "recipe_prefixes": ("Draenor ",),
    },
    {
        "key": "legion",
        "label": "Legion",
        "source_label": "Legion",
        "raw_names": ("Legion",),
        "recipe_exact": ("Food of the Broken Isles",),
        "recipe_prefixes": ("Broken Isles ", "Legion "),
    },
    {
        "key": "bfa",
        "label": "BfA",
        "source_label": "Battle for Azeroth",
        "raw_names": ("Battle for Azeroth",),
        "recipe_exact": (),
        "recipe_prefixes": ("Kul Tiran ",),
    },
    {
        "key": "shadowlands",
        "label": "Shadowlands",
        "source_label": "Shadowlands",
        "raw_names": ("Shadowlands",),
        "recipe_exact": (),
        "recipe_prefixes": ("Shadowlands ",),
    },
    {
        "key": "dragonflight",
        "label": "Dragonflight",
        "source_label": "Dragonflight",
        "raw_names": ("Dragonflight",),
        "recipe_exact": (),
        "recipe_prefixes": ("Dragon Isles ",),
    },
    {
        "key": "the_war_within",
        "label": "The War Within",
        "source_label": "The War Within",
        "raw_names": ("The War Within",),
        "recipe_exact": (),
        "recipe_prefixes": ("Khaz Algar ",),
    },
    {
        "key": "midnight",
        "label": "Midnight",
        "source_label": "Midnight",
        "raw_names": ("Midnight",),
        "recipe_exact": (),
        "recipe_prefixes": ("Midnight ",),
    },
)


def _vendor_gold_item_ids(conn: sqlite3.Connection) -> set[int]:
    rows = conn.execute("SELECT item_id, raw_payload_json FROM recipe_items")
    vendor_gold_ids: set[int] = set()
    for row in rows:
        try:
            payload = json.loads(row[1] or "{}")
        except (TypeError, ValueError):
            continue
        equip = payload.get("jsonequip") or {}
        buyprice = equip.get("buyprice")
        if isinstance(buyprice, (int, float)) and buyprice > 0:
            vendor_gold_ids.add(int(row[0]))
    return vendor_gold_ids


def _query_ids(
    conn: sqlite3.Connection,
    expansion: dict[str, object],
    vendor_gold_ids: set[int],
) -> tuple[list[int], list[int]]:
    raw_names = tuple(expansion["raw_names"])
    raw_marks = ", ".join("?" for _ in raw_names)
    raw_rows = conn.execute(
        f"SELECT item_id FROM items WHERE is_gatherable = 1 AND expansion_seed IN ({raw_marks})",
        raw_names,
    )
    ids = {int(row[0]) for row in raw_rows}

    exact_names = tuple(expansion["recipe_exact"])
    prefixes = tuple(expansion["recipe_prefixes"])
    conditions: list[str] = []
    params: list[str] = []
    for name in exact_names:
        conditions.append("TRIM(r.listview_name) = ?")
        params.append(str(name))
    for prefix in prefixes:
        conditions.append("TRIM(r.listview_name) LIKE ?")
        params.append(f"{prefix}%")
    prepared_ids: set[int] = set()
    if conditions:
        rows = conn.execute(
            """
            SELECT DISTINCT rr.reagent_item_id
            FROM profession_recipes r
            JOIN recipe_reagents rr ON rr.spell_id = r.spell_id
            WHERE """
            + " OR ".join(conditions),
            params,
        )
        ids.update(int(row[0]) for row in rows)
        rows = conn.execute(
            """
            SELECT DISTINCT r.output_item_id
            FROM profession_recipes r
            WHERE r.output_item_id IS NOT NULL AND ("""
            + " OR ".join(conditions)
            + ")",
            params,
        )
        prepared_ids.update(int(row[0]) for row in rows)
    raw_ids = sorted(item_id for item_id in ids if item_id > 0 and item_id not in vendor_gold_ids)
    prepared_ids = sorted(item_id for item_id in prepared_ids if item_id > 0 and item_id not in vendor_gold_ids)
    return raw_ids, prepared_ids


def _lua_list(values: list[int], indent: str = "\t\t\t") -> str:
    if not values:
        return "{}"
    lines: list[str] = []
    for start in range(0, len(values), 16):
        chunk = values[start : start + 16]
        lines.append(indent + ", ".join(str(value) for value in chunk) + ",")
    return "{\n" + "\n".join(lines) + "\n\t\t}"


def render_catalog(catalog: dict[str, tuple[list[int], list[int]]]) -> str:
    total = sum(len(raw) + len(prepared) for raw, prepared in catalog.values())
    lines = [
        f"-- Catalogue local v4, généré depuis wow-tools/data/wow.sqlite3 le {date.today().isoformat()}.",
        "-- Périmètre : réactifs bruts/intermédiaires et sorties de recettes par extension.",
        "-- Les IDs sont dédoublonnés à l'intérieur de chaque extension ; YayaReagentSniper",
        "-- exclut les objets achetables au vendeur contre de l'or (jsonequip.buyprice > 0).",
        "-- Les objets achetés avec de l'honneur restent inclus lorsqu'ils n'ont pas de buyprice en or.",
        "-- filtre ensuite les entrées qui ne sont pas des commodités/réactifs consommables via IsCommodity().",
        f"-- Total des entrées par extension et type (avec recouvrements historiques) : {total}.",
        "YayaReagentSniperCatalog = {",
        "\tversion = 4,",
        '\tscope = "crafting_components_and_consumables",',
        '\tsource = "wow-tools/wow.sqlite3:items:is_gatherable + profession_recipes:recipe_reagents + profession_recipes:output_item_id - recipe_items:jsonequip.buyprice",',
        "\texpansions = {",
    ]
    for expansion in EXPANSIONS:
        key = str(expansion["key"])
        label = str(expansion["label"])
        source_label = str(expansion["source_label"])
        raw_ids, prepared_ids = catalog[key]
        lines.extend(
            [
                f"\t\t{key} = {{",
                f'\t\t\tlabel = "{label}",',
                f'\t\t\tsourceLabel = "{source_label}",',
                f"\t\t\trawItemIDs = {_lua_list(raw_ids)},",
                f"\t\t\tpreparedItemIDs = {_lua_list(prepared_ids)},",
                "\t\t},",
            ]
        )
    lines.extend(["\t},", "}", ""])
    return "\n".join(lines)


def write_atomic(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary: Path | None = None
    try:
        with tempfile.NamedTemporaryFile(
            "w",
            encoding="utf-8",
            newline="\n",
            dir=path.parent,
            prefix=f".{path.name}.",
            suffix=".tmp",
            delete=False,
        ) as handle:
            handle.write(text)
            handle.flush()
            os.fsync(handle.fileno())
            temporary = Path(handle.name)
        os.replace(temporary, path)
    finally:
        if temporary and temporary.exists():
            temporary.unlink()


def main() -> None:
    parser = argparse.ArgumentParser(description="Build the YayaReagentSniper component catalog")
    parser.add_argument("--db", type=Path, default=DB_PATH)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    with sqlite3.connect(args.db) as conn:
        vendor_gold_ids = _vendor_gold_item_ids(conn)
        catalog = {
            str(expansion["key"]): _query_ids(conn, expansion, vendor_gold_ids)
            for expansion in EXPANSIONS
        }
    rendered = render_catalog(catalog)
    print("Catalog counts:")
    print("\n".join(
        f"- {key}: raw={len(raw)} prepared={len(prepared)}"
        for key, (raw, prepared) in catalog.items()
    ))
    print(f"- total with per-expansion overlap: {sum(len(raw) + len(prepared) for raw, prepared in catalog.values())}")
    print(f"- vendor-gold IDs excluded from source: {len(vendor_gold_ids)}")
    if args.dry_run:
        return
    write_atomic(args.output, rendered)
    print(f"Wrote: {args.output}")


if __name__ == "__main__":
    main()
