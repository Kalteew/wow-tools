from __future__ import annotations

import re
import sqlite3
from datetime import datetime
from pathlib import Path
from typing import Any

from wow_tools.config import DB_PATH
from wow_tools.lua_table import parse_lua_assignments
from wow_tools.restock_planner import build_restock_plan


TSM_PATH = Path(
    r"C:\Program Files (x86)\World of Warcraft\_retail_\WTF\Account\417185157#1\SavedVariables\TradeSkillMaster.lua"
)
TARGET_PROFESSIONS = [
    "tailoring",
    "enchanting",
    "cooking",
    "blacksmithing",
    "inscription",
    "alchemy",
    "leatherworking",
    "jewelcrafting",
    "engineering",
]
PROFESSION_LABELS = {
    "tailoring": "Tailoring",
    "enchanting": "Enchanting",
    "cooking": "Cooking",
    "blacksmithing": "Blacksmithing",
    "inscription": "Inscription",
    "alchemy": "Alchemy",
    "leatherworking": "Leatherworking",
    "jewelcrafting": "Jewelcrafting",
    "engineering": "Engineering",
}
CATEGORY_LABELS = {
    "tailoring-gear": "Gear",
    "tailoring-bag": "Bags",
    "tailoring-furniture": "Furniture",
    "tailoring-consumable": "Consumables",
    "component": "Components",
    "alchemy-component": "Components",
    "alchemy-potion": "Potions",
    "alchemy-flask": "Flasks",
    "alchemy-utility": "Utility",
    "alchemy-tool": "Tools",
    "alchemy-furniture": "Furniture",
    "enchanting-weapon": "Weapon",
    "enchanting-visual": "Visual",
    "enchanting-utility": "Utility",
    "enchanting-standard": "Standard",
    "blacksmithing-armor": "Armor",
    "blacksmithing-weapon": "Weapons",
    "blacksmithing-tool": "Tools",
    "blacksmithing-furniture": "Furniture",
    "blacksmithing-consumable": "Consumables",
    "inscription-gear": "Gear",
    "inscription-tool": "Tools",
    "inscription-furniture": "Furniture",
    "inscription-darkmoon": "Darkmoon",
    "inscription-contract": "Contracts",
    "inscription-missive": "Missives",
    "inscription-consumable": "Consumables",
    "jewelcrafting-gem": "Gems",
    "jewelcrafting-gear": "Gear",
    "jewelcrafting-tool": "Tools",
    "jewelcrafting-furniture": "Furniture",
    "jewelcrafting-consumable": "Consumables",
    "leatherworking-armor": "Armor",
    "leatherworking-bag": "Bags",
    "leatherworking-furniture": "Furniture",
    "leatherworking-consumable": "Consumables",
    "engineering-component": "Components",
    "engineering-gear": "Gear",
    "engineering-tool": "Tools",
    "engineering-utility": "Utility",
    "engineering-furniture": "Furniture",
    "engineering-companion": "Companions",
    "cooking-feast": "Feasts",
    "cooking-standard": "Food",
}
GEAR_CATEGORIES = {
    "tailoring-gear",
    "blacksmithing-armor",
    "blacksmithing-weapon",
    "inscription-gear",
    "jewelcrafting-gear",
    "leatherworking-armor",
    "engineering-gear",
}
PREMIUM_CATEGORIES = GEAR_CATEGORIES | {
    "tailoring-bag",
    "alchemy-tool",
    "alchemy-furniture",
    "enchanting-weapon",
    "enchanting-utility",
    "enchanting-visual",
    "blacksmithing-tool",
    "blacksmithing-furniture",
    "inscription-tool",
    "inscription-furniture",
    "inscription-darkmoon",
    "jewelcrafting-tool",
    "jewelcrafting-furniture",
    "leatherworking-bag",
    "leatherworking-furniture",
    "engineering-tool",
    "engineering-furniture",
}
MIDNIGHT_GROUP_RE = re.compile(
    r"^(?:Midnight`(?:Tailoring|Enchanting|Cooking|Blacksmithing|Inscription|Alchemy|Leatherworking|Jewelcrafting|Engineering)"
    r"|(?:Tailoring|Enchanting|Cooking|Blacksmithing|Inscription|Alchemy|Leatherworking|Jewelcrafting|Engineering)`Midnight)(?:`|$)"
)


def _normalized_bucket(profession: str, row: dict[str, Any]) -> int:
    category = row["category"]
    bucket = int(row["bucket"])

    if category in GEAR_CATEGORIES:
        return 5 if bucket >= 5 else 3
    if category in {"tailoring-bag", "blacksmithing-tool", "blacksmithing-furniture", "inscription-tool", "inscription-furniture", "inscription-darkmoon", "jewelcrafting-tool", "jewelcrafting-furniture", "leatherworking-bag", "leatherworking-furniture", "engineering-tool", "engineering-furniture"}:
        return 1
    if category == "cooking-standard":
        return 500
    if category == "cooking-feast":
        return 20
    if category == "alchemy-potion":
        return 100
    if category == "alchemy-flask":
        return 50
    if category == "alchemy-component":
        return 200
    if category == "component":
        if profession in {"alchemy", "inscription", "blacksmithing", "jewelcrafting", "engineering"}:
            return 200 if bucket >= 100 else max(5, bucket)
        return bucket
    if category == "alchemy-utility":
        return 20 if bucket >= 20 else 2
    if category == "alchemy-tool":
        return 3 if bucket >= 3 else 1
    if category == "tailoring-consumable":
        return 20 if bucket >= 20 else 5 if bucket >= 5 else 2
    if category == "enchanting-standard":
        return 12 if bucket >= 10 else 8 if bucket >= 8 else 3 if bucket >= 3 else 2
    if category == "enchanting-weapon":
        return 3 if bucket >= 3 else 2
    if category == "enchanting-visual":
        return 2 if bucket >= 2 else 1
    if category == "blacksmithing-consumable":
        return 50 if bucket >= 50 else 2
    if category == "inscription-contract":
        return 5 if bucket >= 5 else 2
    if category == "inscription-missive":
        return 100 if bucket >= 100 else 50 if bucket >= 50 else 20 if bucket >= 20 else 5
    if category == "inscription-consumable":
        return 20
    if category == "jewelcrafting-gem":
        if bucket >= 100:
            return 100
        if bucket >= 50:
            return 50
        if bucket >= 20:
            return 20
        return 5
    if category == "jewelcrafting-consumable":
        return 20 if bucket >= 20 else 2
    if category == "leatherworking-consumable":
        if bucket >= 50:
            return 50
        if bucket >= 20:
            return 20
        if bucket >= 5:
            return 5
        return 2
    if category == "engineering-component":
        if bucket >= 100:
            return 100
        if bucket >= 20:
            return 20
        return 5
    if category == "engineering-utility":
        return 20 if bucket >= 20 else 5 if bucket >= 5 else 2
    if category == "engineering-companion":
        return 2 if bucket >= 2 else 1
    return bucket


def _min_profit(bucket: int, profession: str, category: str) -> str:
    if profession == "cooking" or bucket >= 100:
        return "2g"
    if bucket >= 50:
        return "5g"
    if category in PREMIUM_CATEGORIES:
        return "25g"
    return "10g"


def _operation_name(bucket: int, min_profit: str) -> str:
    return f"Midnight R{bucket} P{min_profit}"


def _base_group(crafting_op: str | None) -> dict[str, Any]:
    group = {
        "Auctioning": {1: "#Default"},
        "Crafting": {},
        "Mailing": {1: "#Default"},
        "Shopping": {},
        "Sniper": {"override": True},
        "Vendoring": {"override": True},
        "Warehousing": {"override": True},
    }
    if crafting_op:
        group["Crafting"] = {1: crafting_op, "override": True}
    return group


def _ensure_group(groups: dict[str, Any], path: str, crafting_op: str | None) -> None:
    if path not in groups:
        groups[path] = _base_group(crafting_op)
        return
    if crafting_op:
        groups[path]["Crafting"] = {1: crafting_op, "override": True}


def _ensure_parents(groups: dict[str, Any], path: str) -> None:
    parts = path.split("`")
    for idx in range(1, len(parts)):
        parent = "`".join(parts[:idx])
        _ensure_group(groups, parent, None)


def _lua_escape(value: str) -> str:
    return (
        value.replace("\\", "\\\\")
        .replace('"', '\\"')
        .replace("\n", "\\n")
        .replace("\r", "\\r")
        .replace("\t", "\\t")
    )


def _serialize_lua(value: Any, indent: int = 0) -> str:
    if value is None:
        return "nil"
    if value is True:
        return "true"
    if value is False:
        return "false"
    if isinstance(value, (int, float)):
        return str(value)
    if isinstance(value, str):
        return f"\"{_lua_escape(value)}\""
    if isinstance(value, dict):
        if not value:
            return "{}"
        pad = " " * indent
        child_pad = " " * (indent + 2)
        lines = ["{"]
        for key, child in value.items():
            if isinstance(key, (int, float)):
                key_text = f"[{key}]"
            else:
                key_text = f"[\"{_lua_escape(str(key))}\"]"
            lines.append(f"{child_pad}{key_text} = {_serialize_lua(child, indent + 2)},")
        lines.append(f"{pad}}}")
        return "\n".join(lines)
    raise TypeError(f"Unsupported Lua value: {type(value)!r}")


def _walk_lua(value: Any):
    if isinstance(value, dict):
        yield value
        for child in value.values():
            yield from _walk_lua(child)
        return
    if isinstance(value, list):
        for child in value:
            yield from _walk_lua(child)


def _tsm_crafted_item_strings(db: dict[str, Any]) -> dict[int, set[str]]:
    result: dict[int, set[str]] = {}
    valid_professions = set(PROFESSION_LABELS.values())

    for node in _walk_lua(db):
        item_string = node.get("itemString")
        profession = node.get("profession")
        if not isinstance(item_string, str) or not isinstance(profession, str):
            continue
        if profession not in valid_professions or not item_string.startswith("i:"):
            continue
        match = re.match(r"i:(\d+)", item_string)
        if not match:
            continue
        item_id = int(match.group(1))
        result.setdefault(item_id, set()).add(item_string)

    return result


def main() -> None:
    timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    backup_path = TSM_PATH.with_name(f"{TSM_PATH.name}.{timestamp}.midnight-fix.bak")
    backup_path.write_text(TSM_PATH.read_text(encoding="utf-8", errors="replace"), encoding="utf-8")

    assignments = parse_lua_assignments(TSM_PATH.read_text(encoding="utf-8", errors="replace"))
    db = assignments["TradeSkillMasterDB"]
    groups = db["p@Default@userData@groups"]
    items = db["p@Default@userData@items"]
    operations = db["p@Default@userData@operations"]["Crafting"]
    crafted_item_strings = _tsm_crafted_item_strings(db)

    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    plans = {
        profession: build_restock_plan(conn, profession=profession, expansion="Midnight")
        for profession in TARGET_PROFESSIONS
    }
    conn.close()

    for item_key, group_path in list(items.items()):
        if not isinstance(item_key, str) or not item_key.startswith("i:"):
            continue
        if isinstance(group_path, str) and MIDNIGHT_GROUP_RE.match(group_path):
            del items[item_key]

    for group_path in list(groups.keys()):
        if isinstance(group_path, str) and MIDNIGHT_GROUP_RE.match(group_path):
            del groups[group_path]

    for op_name in list(operations.keys()):
        if isinstance(op_name, str) and op_name.startswith("Midnight R"):
            del operations[op_name]

    _ensure_group(groups, "Midnight", None)

    desired_groups: dict[str, str] = {}
    for profession, report in plans.items():
        profession_label = PROFESSION_LABELS[profession]
        profession_path = f"Midnight`{profession_label}"
        _ensure_group(groups, profession_path, None)

        for row in report["rows"]:
            bucket = _normalized_bucket(profession, row)
            min_profit = _min_profit(bucket, profession, row["category"])
            op_name = _operation_name(bucket, min_profit)
            operations[op_name] = {
                "craftPriceMethod": "",
                "ignoreFactionrealm": {},
                "ignorePlayer": {},
                "maxRestock": str(bucket),
                "minProfit": min_profit,
                "minRestock": str(bucket),
                "relationships": {},
            }

            category_label = CATEGORY_LABELS[row["category"]]
            category_path = f"{profession_path}`{category_label}"
            group_path = f"{category_path}`Restock {bucket}"
            _ensure_parents(groups, group_path)
            _ensure_group(groups, group_path, op_name)
            item_strings = crafted_item_strings.get(int(row["item_id"])) or {f"i:{row['item_id']}"}
            for item_string in item_strings:
                desired_groups[item_string] = group_path

    items.update(desired_groups)

    output = "TradeSkillMasterDB = " + _serialize_lua(db) + "\n"
    TSM_PATH.write_text(output, encoding="utf-8")
    print(f"Backup: {backup_path}")
    print(f"Updated: {TSM_PATH}")
    print(f"Items remapped: {len(desired_groups)}")


if __name__ == "__main__":
    main()
