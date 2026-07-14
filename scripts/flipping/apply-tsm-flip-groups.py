from __future__ import annotations

import json
import re
import shutil
import subprocess
import sys
from datetime import datetime
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from wow_tools.lua_table import parse_lua_assignments

GROUP_DIR = ROOT / "data" / "flipping" / "generated" / "flipping-groups"
TSM_PATH = Path(
    r"C:\Program Files (x86)\World of Warcraft\_retail_\WTF\Account\417185157#1\SavedVariables\TradeSkillMaster.lua"
)

CUSTOM_SOURCES = {
    "flipvalue": "first(dbregionsaleavg, dbregionmarketavg, dbhistorical)",
    "flipbuyfast": "min(35% dbregionmarketavg, 50% dbregionsaleavg, 40% dbhistorical)",
    "flipbuypremium": "min(25% dbregionmarketavg, 35% dbregionsaleavg, 30% dbhistorical)",
    "decorbuy": "ifgt(dbregionsalerate, 0.02, min(45% dbregionmarketavg, 60% dbregionsaleavg, 50% dbhistorical), min(30% dbregionmarketavg, 40% dbregionsaleavg, 35% dbhistorical))",
}

FLIP_GROUPS = [
    "FLIP",
    "FLIP`Housing",
    "FLIP`Mount",
    "FLIP`Toys",
    "FLIP`Recipes",
    "FLIP`Tmog",
    "FLIP`Test",
    "FLIP`Other Slow",
    "FLIP`Other Fast",
]


def _wow_is_running() -> bool:
    result = subprocess.run(
        ["powershell", "-NoProfile", "-Command", "Get-Process -Name Wow -ErrorAction SilentlyContinue"],
        capture_output=True,
        text=True,
        check=False,
    )
    return bool(result.stdout.strip())


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
            key_text = f"[{key}]" if isinstance(key, (int, float)) else f"[\"{_lua_escape(str(key))}\"]"
            lines.append(f"{child_pad}{key_text} = {_serialize_lua(child, indent + 2)},")
        lines.append(f"{pad}}}")
        return "\n".join(lines)
    raise TypeError(f"Unsupported Lua value: {type(value)!r}")


def _base_group(auction_op: str | None = None, shopping_op: str | None = None) -> dict[str, Any]:
    group = {
        "Shopping": {"override": True},
        "Mailing": {"override": True},
        "Auctioning": {"override": True},
        "Crafting": {"override": True},
        "Warehousing": {"override": True},
        "Vendoring": {"override": True},
        "Sniper": {"override": True},
    }
    if auction_op:
        group["Auctioning"] = {1: auction_op, "override": True}
    if shopping_op:
        group["Shopping"] = {1: shopping_op, "override": True}
    return group


def _ensure_group(groups: dict[str, Any], path: str, auction_op: str | None = None, shopping_op: str | None = None) -> None:
    if path not in groups:
        groups[path] = _base_group(auction_op, shopping_op)
        return
    groups[path].setdefault("Auctioning", {"override": True})
    groups[path].setdefault("Shopping", {"override": True})
    groups[path].setdefault("Mailing", {"override": True})
    groups[path].setdefault("Crafting", {"override": True})
    groups[path].setdefault("Warehousing", {"override": True})
    groups[path].setdefault("Vendoring", {"override": True})
    groups[path].setdefault("Sniper", {"override": True})
    if auction_op:
        groups[path]["Auctioning"] = {1: auction_op, "override": True}
    if shopping_op:
        groups[path]["Shopping"] = {1: shopping_op, "override": True}


def _load_item_strings(name: str) -> list[str]:
    path = GROUP_DIR / name
    if not path.exists():
        raise SystemExit(f"Missing group file: {path}. Run build-flipping-groups.py first.")
    return [line.strip() for line in path.read_text(encoding="utf-8").splitlines() if line.strip()]


def _remove_existing_flip(groups: dict[str, Any], items: dict[str, Any]) -> None:
    for item_key, group_path in list(items.items()):
        if isinstance(group_path, str) and (group_path == "FLIP" or group_path.startswith("FLIP`")):
            del items[item_key]
    for group_path in list(groups.keys()):
        if isinstance(group_path, str) and (group_path == "FLIP" or group_path.startswith("FLIP`")):
            del groups[group_path]


def _auctioning_op(duration: int, min_price: str, normal_price: str, max_price: str) -> dict[str, Any]:
    return {
        "cancelRepost": True,
        "normalPrice": normal_price,
        "duration": duration,
        "keepQuantity": "0",
        "postCap": "1",
        "bidPercent": 1,
        "relationships": {},
        "maxPrice": max_price,
        "ignoreLowDuration": 0,
        "ignoreFactionrealm": {},
        "cancelRepostThreshold": "250g",
        "maxExpires": "0",
        "priceReset": "none",
        "undercut": "0c",
        "aboveMax": "maxPrice",
        "minPrice": min_price,
        "cancelUndercut": True,
        "ignorePlayer": {},
    }


def _shopping_op(max_price: str, restock_quantity: str = "1") -> dict[str, Any]:
    return {
        "ignoreFactionrealm": {},
        "relationships": {},
        "maxPrice": max_price,
        "restockQuantity": restock_quantity,
        "ignorePlayer": {},
        "restockSources": {
            "alts": True,
            "auctions": True,
            "guild": False,
            "bank": True,
        },
        "showAboveMaxPrice": False,
    }


def main() -> int:
    if _wow_is_running():
        raise SystemExit("WoW.exe is running. Close the game before applying TSM flip groups.")
    if not TSM_PATH.exists():
        raise SystemExit(f"TSM SavedVariables not found: {TSM_PATH}")

    timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    backup_path = TSM_PATH.with_name(f"{TSM_PATH.name}.{timestamp}.flip-groups.bak")
    shutil.copy2(TSM_PATH, backup_path)

    assignments = parse_lua_assignments(TSM_PATH.read_text(encoding="utf-8", errors="replace"))
    db = assignments["TradeSkillMasterDB"]
    groups = db["p@Default@userData@groups"]
    items = db["p@Default@userData@items"]
    operations = db["p@Default@userData@operations"]
    custom_sources = db.setdefault("g@ @userData@customPriceSources", {})
    custom_formats = db.setdefault("g@ @userData@customPriceSourceFormat", {})

    for name, formula in CUSTOM_SOURCES.items():
        custom_sources[name] = formula
        custom_formats[name] = "gold"

    auctioning = operations.setdefault("Auctioning", {})
    shopping = operations.setdefault("Shopping", {})
    auctioning["Flip Decor"] = _auctioning_op(
        2,
        "max(120% avgBuy, 60% dbregionmarketavg, 80% dbregionsaleavg)",
        "120% dbregionmarketavg",
        "300% dbregionmarketavg",
    )
    auctioning["Flip Mount"] = _auctioning_op(
        2,
        "max(110% avgBuy, 50% dbregionmarketavg, 75% dbregionsaleavg)",
        "110% dbregionmarketavg",
        "250% dbregionmarketavg",
    )
    auctioning["Flip Fast"] = _auctioning_op(
        2,
        "max(115% avgBuy, 40% dbregionmarketavg, 70% dbregionsaleavg)",
        "100% dbregionmarketavg",
        "200% dbregionmarketavg",
    )
    auctioning["Flip Rare"] = _auctioning_op(
        2,
        "max(150% avgBuy, 50% dbregionmarketavg)",
        "150% dbregionmarketavg",
        "500% dbregionmarketavg",
    )
    auctioning["Flip Tmog"] = _auctioning_op(
        2,
        "max(140% avgBuy, 45% dbregionmarketavg, 65% dbregionsaleavg)",
        "140% dbregionmarketavg",
        "400% dbregionmarketavg",
    )
    shopping["Flip Decor"] = _shopping_op("decorbuy", "1")
    shopping["Flip Mount"] = _shopping_op("flipbuyfast", "1")
    shopping["Flip Toys"] = _shopping_op("flipbuypremium", "1")
    shopping["Flip Recipes"] = _shopping_op("flipbuypremium", "1")
    shopping["Flip Tmog"] = _shopping_op("flipbuypremium", "1")
    shopping["Flip Fast"] = _shopping_op("flipbuyfast", "2")
    shopping["Flip Premium"] = _shopping_op("flipbuypremium", "1")

    _remove_existing_flip(groups, items)
    for path in FLIP_GROUPS:
        if path == "FLIP`Housing":
            _ensure_group(groups, path, "Flip Decor", "Flip Decor")
        elif path == "FLIP`Mount":
            _ensure_group(groups, path, "Flip Mount", "Flip Mount")
        elif path == "FLIP`Toys":
            _ensure_group(groups, path, "Flip Toys", "Flip Toys")
        elif path == "FLIP`Recipes":
            _ensure_group(groups, path, "Flip Recipes", "Flip Recipes")
        elif path == "FLIP`Tmog":
            _ensure_group(groups, path, "Flip Tmog", "Flip Tmog")
        elif path == "FLIP`Test":
            _ensure_group(groups, path)
        elif path == "FLIP`Other Fast":
            _ensure_group(groups, path, "Flip Fast", "Flip Fast")
        elif path == "FLIP`Other Slow":
            _ensure_group(groups, path, "Flip Rare", "Flip Premium")
        else:
            _ensure_group(groups, path)

    housing_items = set(_load_item_strings("flipping-housing.tsm.txt"))
    mount_items = set(_load_item_strings("flipping-mount.tsm.txt"))
    toy_items = set(_load_item_strings("flipping-toys.tsm.txt"))
    recipe_items = set(_load_item_strings("flipping-recipes.tsm.txt"))
    tmog_items = set(_load_item_strings("flipping-tmog.tsm.txt"))
    slow_items = set(_load_item_strings("flipping-other-slow.tsm.txt"))
    fast_items = set(_load_item_strings("flipping-other-fast.tsm.txt"))
    overlaps = {
        "housing/slow": housing_items & slow_items,
        "housing/fast": housing_items & fast_items,
        "housing/mount": housing_items & mount_items,
        "housing/toys": housing_items & toy_items,
        "housing/recipes": housing_items & recipe_items,
        "mount/slow": mount_items & slow_items,
        "mount/fast": mount_items & fast_items,
        "mount/toys": mount_items & toy_items,
        "mount/recipes": mount_items & recipe_items,
        "mount/tmog": mount_items & tmog_items,
        "toys/slow": toy_items & slow_items,
        "toys/fast": toy_items & fast_items,
        "toys/recipes": toy_items & recipe_items,
        "toys/tmog": toy_items & tmog_items,
        "recipes/slow": recipe_items & slow_items,
        "recipes/fast": recipe_items & fast_items,
        "recipes/tmog": recipe_items & tmog_items,
        "tmog/slow": tmog_items & slow_items,
        "tmog/fast": tmog_items & fast_items,
        "slow/fast": slow_items & fast_items,
    }
    bad_overlaps = {name: values for name, values in overlaps.items() if values}
    if bad_overlaps:
        detail = ", ".join(f"{name}={len(values)}" for name, values in bad_overlaps.items())
        raise SystemExit(f"Flipping group files overlap: {detail}.")

    for item_string in sorted(housing_items):
        items[item_string] = "FLIP`Housing"
    for item_string in sorted(mount_items):
        items[item_string] = "FLIP`Mount"
    for item_string in sorted(toy_items):
        items[item_string] = "FLIP`Toys"
    for item_string in sorted(recipe_items):
        items[item_string] = "FLIP`Recipes"
    for item_string in sorted(tmog_items):
        items[item_string] = "FLIP`Tmog"
    for item_string in sorted(slow_items):
        items[item_string] = "FLIP`Other Slow"
    for item_string in sorted(fast_items):
        items[item_string] = "FLIP`Other Fast"

    TSM_PATH.write_text("TradeSkillMasterDB = " + _serialize_lua(db) + "\n", encoding="utf-8")

    reparsed = parse_lua_assignments(TSM_PATH.read_text(encoding="utf-8", errors="replace"))
    if "TradeSkillMasterDB" not in reparsed:
        shutil.copy2(backup_path, TSM_PATH)
        raise SystemExit("Validation failed; restored backup.")

    print(f"Backup: {backup_path}")
    print(f"Updated: {TSM_PATH}")
    print(f"Housing: {len(housing_items)}")
    print(f"Mount: {len(mount_items)}")
    print(f"Toys: {len(toy_items)}")
    print(f"Recipes: {len(recipe_items)}")
    print(f"Tmog: {len(tmog_items)}")
    print(f"Other slow: {len(slow_items)}")
    print(f"Other fast: {len(fast_items)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
