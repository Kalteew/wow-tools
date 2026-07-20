from __future__ import annotations

import json
import os
import subprocess
import sys
from datetime import datetime
from pathlib import Path
from typing import Any

REPO_ROOT = Path(__file__).resolve().parents[2]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from wow_tools.lua_table import parse_lua_assignments
from wow_tools.local_account import resolve_paths


TSM_PATH: Path
CONFIG_PATH = REPO_ROOT / "data" / "tsm" / "logging_groups.json"


def _configure_local_paths() -> None:
    global TSM_PATH
    paths = resolve_paths(
        retail_root=os.environ.get("WOW_RETAIL_ROOT"),
        account_root=os.environ.get("WOW_ACCOUNT_ROOT"),
    )
    TSM_PATH = Path(paths["saved_variables"]) / "TradeSkillMaster.lua"


def _wow_is_running() -> bool:
    result = subprocess.run(
        ["tasklist", "/FI", "IMAGENAME eq WoW.exe", "/FO", "CSV", "/NH"],
        capture_output=True,
        text=True,
        check=False,
    )
    return "WoW.exe" in result.stdout


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
    elif crafting_op:
        groups[path]["Crafting"] = {1: crafting_op, "override": True}


def _ensure_parents(groups: dict[str, Any], path: str) -> None:
    parts = path.split("`")
    for idx in range(1, len(parts)):
        _ensure_group(groups, "`".join(parts[:idx]), None)


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


def _remove_logging(groups: dict[str, Any], items: dict[str, Any]) -> None:
    for item_key, group_path in list(items.items()):
        if isinstance(group_path, str) and (group_path == "Logging" or group_path.startswith("Logging`")):
            del items[item_key]

    for group_path in list(groups.keys()):
        if group_path == "Logging" or group_path.startswith("Logging`"):
            del groups[group_path]


def main() -> None:
    _configure_local_paths()
    if _wow_is_running():
        raise SystemExit("WoW.exe is running. Close the game before applying logging groups.")

    config = json.loads(CONFIG_PATH.read_text(encoding="utf-8"))
    op_cfg = config["crafting_operation"]

    timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    backup_path = TSM_PATH.with_name(f"{TSM_PATH.name}.{timestamp}.logging-groups.bak")
    backup_path.write_text(TSM_PATH.read_text(encoding="utf-8", errors="replace"), encoding="utf-8")

    assignments = parse_lua_assignments(TSM_PATH.read_text(encoding="utf-8", errors="replace"))
    db = assignments["TradeSkillMasterDB"]
    groups = db["p@Default@userData@groups"]
    items = db["p@Default@userData@items"]
    operations = db["p@Default@userData@operations"]["Crafting"]

    _remove_logging(groups, items)
    _ensure_group(groups, "Logging", None)

    product_total = 0
    for expansion in config["expansions"]:
        label = expansion["label"]
        expansion_root = f"Logging`{label}"
        wood_group = f"{expansion_root}`Wood"
        product_group = f"{expansion_root}`Metier"
        op_name = op_cfg["name_template"].format(expansion=label)

        operations[op_name] = {
            "craftPriceMethod": "",
            "ignoreFactionrealm": {},
            "ignorePlayer": {},
            "maxRestock": op_cfg["max_restock"],
            "minProfit": op_cfg["min_profit"],
            "minRestock": op_cfg["min_restock"],
            "relationships": {},
        }

        for path, crafting_op in (
            (expansion_root, None),
            (wood_group, None),
            (product_group, op_name),
        ):
            _ensure_parents(groups, path)
            _ensure_group(groups, path, crafting_op)

        items[f"i:{expansion['wood_item_id']}"] = wood_group
        for item_id in expansion["product_item_ids"]:
            items[f"i:{item_id}"] = product_group
        product_total += len(expansion["product_item_ids"])

    output = "TradeSkillMasterDB = " + _serialize_lua(db) + "\n"
    TSM_PATH.write_text(output, encoding="utf-8")
    print(f"Backup: {backup_path}")
    print(f"Updated: {TSM_PATH}")
    print(f"Expansions: {len(config['expansions'])}")
    print(f"Products: {product_total}")


if __name__ == "__main__":
    main()
