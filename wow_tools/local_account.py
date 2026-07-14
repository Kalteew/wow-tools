from __future__ import annotations

import re
from datetime import datetime
from pathlib import Path
from typing import Any

from wow_tools.lua_table import parse_lua_assignments, parse_lua_value


_WOW_RETAIL_CANDIDATES = (
    Path(r"C:\Program Files (x86)\World of Warcraft\_retail_"),
    Path(r"C:\Program Files\World of Warcraft\_retail_"),
    Path(r"D:\World of Warcraft\_retail_"),
    Path(r"E:\World of Warcraft\_retail_"),
)
_LOADDATA_RE = re.compile(
    r'^select\(2, \.\.\.\)\.LoadData\("([^"]+)","([^"]+)",\[\[(.*)\]\]\)\s*(?:--<[^>]*>)?$'
)
_APPDATA_ROW_RE = re.compile(r'\{"?([^,"]+)"?,([^}]+)\}')
_ITEM_ID_RE = re.compile(r"\|Hitem:(\d+)")
_ITEM_NAME_RE = re.compile(r"\|h\[([^]]+)\]\|h")


def resolve_paths(
    retail_root: str | Path | None = None,
    account_root: str | Path | None = None,
) -> dict[str, str]:
    retail_path = _resolve_retail_root(retail_root)
    account_path = _resolve_account_root(retail_path, account_root)
    saved_variables = account_path / "SavedVariables"
    appdata_path = retail_path / "Interface" / "AddOns" / "TradeSkillMaster_AppHelper" / "AppData.lua"

    return {
        "retail_root": str(retail_path),
        "account_root": str(account_path),
        "saved_variables": str(saved_variables),
        "tsm_appdata": str(appdata_path),
    }


def load_local_state(
    retail_root: str | Path | None = None,
    account_root: str | Path | None = None,
) -> dict[str, Any]:
    paths = resolve_paths(retail_root, account_root)
    saved_variables = Path(paths["saved_variables"])

    manifest = _load_manifest(saved_variables / "DataStore.lua")
    characters_info = _load_indexed_table(saved_variables / "DataStore_Characters.lua", "DataStore_Characters_Info")
    containers = _load_indexed_table(saved_variables / "DataStore_Containers.lua", "DataStore_Containers_Characters")
    banks = _load_indexed_table(saved_variables / "DataStore_Containers.lua", "DataStore_Containers_Banks")
    reagents = _load_indexed_table(saved_variables / "DataStore_Containers.lua", "DataStore_Containers_Reagents")
    inventory = _load_indexed_table(saved_variables / "DataStore_Inventory.lua", "DataStore_Inventory_Characters")
    auctions = _load_indexed_table(saved_variables / "DataStore_Auctions.lua", "DataStore_Auctions_Characters")
    auctions_list = _load_indexed_table(saved_variables / "DataStore_Auctions.lua", "DataStore_Auctions_AuctionsList")
    warbank = _load_table(saved_variables / "DataStore_Containers.lua", "DataStore_Containers_Warbank")
    tsm_status = load_tsm_status(paths["tsm_appdata"])

    characters: list[dict[str, Any]] = []
    for index, key in sorted(manifest["keys"].items()):
        account, realm, name = key.split(".", 2)
        info = characters_info.get(index, {})
        character = {
            "index": index,
            "key": key,
            "account": account,
            "realm": realm,
            "name": name,
            "guid": manifest["guids"].get(index),
            "level": _decode_character_level(info.get("BaseInfo")),
            "money_copper": int(info.get("money", 0) or 0),
            "money_text": format_copper(int(info.get("money", 0) or 0)),
            "zone": info.get("zone"),
            "sub_zone": info.get("subZone"),
            "last_update_ts": int(info.get("lastUpdate", 0) or 0),
            "last_update": format_timestamp(info.get("lastUpdate")),
            "last_logout_ts": int(info.get("lastLogoutTimestamp", 0) or 0),
            "last_logout": format_timestamp(info.get("lastLogoutTimestamp")),
            "containers_last_update_ts": int(containers.get(index, {}).get("lastUpdate", 0) or 0),
            "containers_last_update": format_timestamp(containers.get(index, {}).get("lastUpdate")),
            "inventory_last_update_ts": int(inventory.get(index, {}).get("lastUpdate", 0) or 0),
            "inventory_last_update": format_timestamp(inventory.get(index, {}).get("lastUpdate")),
            "auctions_last_update_ts": int(auctions.get(index, {}).get("lastUpdate", 0) or 0),
            "auctions_last_update": format_timestamp(auctions.get(index, {}).get("lastUpdate")),
            "_containers": containers.get(index, {}),
            "_bank": banks.get(index, {}),
            "_reagents": reagents.get(index, {}),
            "_inventory": inventory.get(index, {}),
            "_auctions": auctions.get(index, {}),
            "_auctions_list": auctions_list.get(index, {}),
        }
        characters.append(character)

    return {
        "paths": paths,
        "tsm": tsm_status,
        "characters": characters,
        "_warbank": warbank,
    }


def build_summary(state: dict[str, Any]) -> dict[str, Any]:
    characters = []
    total_gold = 0

    for character in state["characters"]:
        total_gold += character["money_copper"]
        characters.append(
            {
                "name": character["name"],
                "realm": character["realm"],
                "guid": character["guid"],
                "gold_copper": character["money_copper"],
                "gold_text": character["money_text"],
                "zone": character["zone"],
                "sub_zone": character["sub_zone"],
                "last_update": character["last_update"],
                "last_logout": character["last_logout"],
                "containers_last_update": character["containers_last_update"],
                "inventory_last_update": character["inventory_last_update"],
                "auctions_last_update": character["auctions_last_update"],
            }
        )

    datasets = state["tsm"].get("datasets", [])
    latest_download = max((dataset.get("download_time_ts", 0) or 0) for dataset in datasets) if datasets else 0

    return {
        "paths": state["paths"],
        "character_count": len(characters),
        "total_gold_copper": total_gold,
        "total_gold_text": format_copper(total_gold),
        "characters": characters,
        "tsm": state["tsm"],
        "tsm_latest_download_ts": latest_download,
        "tsm_latest_download": format_timestamp(latest_download),
    }


def render_summary(summary: dict[str, Any]) -> str:
    lines = [
        "Local WoW snapshot",
        f"- retail root: {summary['paths']['retail_root']}",
        f"- account root: {summary['paths']['account_root']}",
        f"- characters: {summary['character_count']}",
        f"- total gold: {summary['total_gold_text']}",
    ]

    app_info = summary["tsm"].get("app_info") or {}
    if app_info.get("last_sync"):
        lines.append(f"- TSM app sync: {app_info['last_sync']}")
    elif summary.get("tsm_latest_download"):
        lines.append(f"- latest TSM snapshot: {summary['tsm_latest_download']}")

    lines.append("")
    lines.append("Characters")
    for character in summary["characters"]:
        lines.append(
            f"- {character['name']} ({character['realm']}): {character['gold_text']} | {character['last_update'] or 'unknown'}"
        )

    return "\n".join(lines)


def load_character_profession_scans(
    retail_root: str | Path | None = None,
    account_root: str | Path | None = None,
) -> dict[str, Any]:
    state = load_local_state(retail_root, account_root)
    saved_variables = Path(state["paths"]["saved_variables"])
    crafts = _load_optional_indexed_table(saved_variables / "DataStore_Crafts.lua", "DataStore_Crafts_Characters")

    characters: list[dict[str, Any]] = []
    characters_with_professions = 0
    scanned_profession_count = 0
    profession_count = 0

    for character in state["characters"]:
        craft_data = crafts.get(character["index"], {})
        professions = craft_data.get("Professions", {}) if isinstance(craft_data, dict) else {}
        ranks = craft_data.get("Ranks", {}) if isinstance(craft_data, dict) else {}
        profession_rows: list[dict[str, Any]] = []

        for slot, profession in sorted(
            ((key, value) for key, value in professions.items() if isinstance(key, int)),
            key=lambda item: item[0],
        ):
            if not isinstance(profession, dict):
                continue
            profession_name = profession.get("Name") or profession.get("CurrentLevelName") or f"Métier {slot}"
            recipes_scanned = bool(profession.get("Crafts")) or str(profession_name).casefold() in _NO_RECIPE_PROFESSIONS
            current_rank, maximum_rank = _decode_rank(ranks.get(slot))
            profession_rows.append(
                {
                    "slot": slot,
                    "name": profession_name,
                    "current_level_name": profession.get("CurrentLevelName"),
                    "rank_current": current_rank,
                    "rank_max": maximum_rank,
                    "recipes_scanned": recipes_scanned,
                }
            )

        if profession_rows:
            characters_with_professions += 1
        profession_count += len(profession_rows)
        scanned_profession_count += sum(1 for row in profession_rows if row["recipes_scanned"])

        characters.append(
            {
                "index": character["index"],
                "name": character["name"],
                "realm": character["realm"],
                "account": character["account"],
                "guid": character["guid"],
                "level": character.get("level"),
                "last_update": character["last_update"],
                "last_update_ts": character["last_update_ts"],
                "last_logout": character["last_logout"],
                "last_logout_ts": character["last_logout_ts"],
                "profession_count": len(profession_rows),
                "scanned_profession_count": sum(1 for row in profession_rows if row["recipes_scanned"]),
                "professions": profession_rows,
            }
        )

    characters.sort(
        key=lambda row: (
            row.get("last_logout_ts") or 0,
            row.get("level") or 0,
            row.get("name") or "",
        ),
        reverse=True,
    )

    return {
        "paths": state["paths"],
        "character_count": len(characters),
        "characters_with_professions": characters_with_professions,
        "profession_count": profession_count,
        "scanned_profession_count": scanned_profession_count,
        "characters": characters,
    }


def load_yaya_profession_specializations(
    retail_root: str | Path | None = None,
    account_root: str | Path | None = None,
) -> dict[str, Any]:
    paths = resolve_paths(retail_root, account_root)
    saved_variables = Path(paths["saved_variables"])
    snapshot_path = saved_variables / "YayaProfessionSpecializations.lua"

    result: dict[str, Any] = {
        "paths": paths,
        "exists": snapshot_path.exists(),
        "snapshot_path": str(snapshot_path),
        "characters": {},
        "last_updated": None,
    }
    if not snapshot_path.exists():
        return result

    data = parse_lua_assignments(snapshot_path.read_text(encoding="utf-8", errors="replace"))
    db = data.get("YayaProfessionSpecializationsDB", {})
    if not isinstance(db, dict):
        return result

    meta = db.get("meta", {})
    if isinstance(meta, dict):
        result["last_updated"] = format_timestamp(meta.get("lastUpdated"))
        result["last_updated_ts"] = meta.get("lastUpdated")
        result["last_source"] = meta.get("lastSource")

    characters = db.get("characters", {})
    if not isinstance(characters, dict):
        return result

    normalized_characters: dict[str, dict[str, Any]] = {}
    for key, snapshot in characters.items():
        if not isinstance(key, str) or not isinstance(snapshot, dict):
            continue

        professions: list[dict[str, Any]] = []
        raw_professions = snapshot.get("professions", {})
        if isinstance(raw_professions, dict):
            profession_values = [value for _, value in sorted(raw_professions.items()) if isinstance(value, dict)]
        else:
            profession_values = []

        for profession in profession_values:
            tabs: list[dict[str, Any]] = []
            raw_tabs = profession.get("tabs", {})
            if isinstance(raw_tabs, dict):
                tab_values = [value for _, value in sorted(raw_tabs.items()) if isinstance(value, dict)]
            else:
                tab_values = []

            for tab in tab_values:
                nodes: list[dict[str, Any]] = []
                raw_nodes = tab.get("nodes", {})
                if isinstance(raw_nodes, dict):
                    node_values = [value for _, value in sorted(raw_nodes.items()) if isinstance(value, dict)]
                else:
                    node_values = []

                for node in node_values:
                    nodes.append(
                        {
                            "path_id": node.get("pathID"),
                            "name": node.get("name"),
                            "state": node.get("state"),
                            "current_rank": node.get("currentRank"),
                            "max_ranks": node.get("maxRanks"),
                            "active_rank": node.get("activeRank"),
                        }
                    )

                tabs.append(
                    {
                        "tab_id": tab.get("tabID"),
                        "name": tab.get("name"),
                        "root_path_id": tab.get("rootPathID"),
                        "nodes": nodes,
                    }
                )

            professions.append(
                {
                    "skill_line_id": profession.get("skillLineID"),
                    "config_id": profession.get("configID"),
                    "profession_name": profession.get("professionName"),
                    "parent_profession_name": profession.get("parentProfessionName"),
                    "skill_level": profession.get("skillLevel"),
                    "max_skill_level": profession.get("maxSkillLevel"),
                    "tabs": tabs,
                }
            )

        normalized_characters[key] = {
            "captured_at": format_timestamp(snapshot.get("capturedAt")),
            "captured_at_ts": snapshot.get("capturedAt"),
            "player_name": snapshot.get("playerName"),
            "realm_name": snapshot.get("realmName"),
            "professions": professions,
        }

    result["characters"] = normalized_characters
    return result


def find_items(
    state: dict[str, Any],
    *,
    item_id: int | None = None,
    name: str | None = None,
) -> list[dict[str, Any]]:
    aggregated = _aggregate_items(state)
    records = list(aggregated.values())

    if item_id is not None:
        record = aggregated.get(item_id)
        return [record] if record else []

    if name:
        lowered = name.casefold()
        records = [
            record
            for record in records
            if record.get("name") and lowered in str(record["name"]).casefold()
        ]

    records.sort(key=lambda record: (-record["total_count"], record.get("name") or ""))
    return records


def render_item_matches(matches: list[dict[str, Any]]) -> str:
    if not matches:
        return "No local item match"

    lines: list[str] = []
    for match in matches[:15]:
        label = match.get("name") or f"Item {match['item_id']}"
        lines.append(f"{label} ({match['item_id']})")
        lines.append(f"- total: {match['total_count']}")
        character_rows = sorted(
            match["characters"].values(),
            key=lambda entry: (-entry["total_count"], entry["name"]),
        )
        for character in character_rows:
            source_bits = []
            for source, count in sorted(character["sources"].items()):
                if count:
                    source_bits.append(f"{source}={count}")
            source_text = ", ".join(source_bits) if source_bits else "unknown"
            lines.append(f"- {character['name']}: {character['total_count']} ({source_text})")
        lines.append("")

    return "\n".join(lines).rstrip()


def lookup_local_prices(
    item_id: int,
    retail_root: str | Path | None = None,
    account_root: str | Path | None = None,
) -> dict[str, Any]:
    paths = resolve_paths(retail_root, account_root)
    appdata_path = Path(paths["tsm_appdata"])
    if not appdata_path.exists():
        raise FileNotFoundError(f"TSM AppData file not found: {appdata_path}")

    exact_item_string = f"i:{item_id}"
    datasets: list[dict[str, Any]] = []
    app_info: dict[str, Any] | None = None

    for raw_line in appdata_path.read_text(encoding="utf-8", errors="replace").splitlines():
        match = _LOADDATA_RE.match(raw_line)
        if not match:
            continue

        tag, scope, payload = match.groups()
        metadata = _parse_appdata_metadata(payload)

        if tag == "APP_INFO":
            app_info = {
                "version": metadata.get("version"),
                "last_sync_ts": metadata.get("lastSync"),
                "last_sync": format_timestamp(metadata.get("lastSync")),
            }
            continue

        fields = _lua_array_to_list(metadata.get("fields", {}))
        item_blob = _extract_appdata_item_blob(payload)
        matches: list[dict[str, Any]] = []

        for item_string, raw_values in _iter_appdata_rows(item_blob):
            if item_string == exact_item_string or item_string.startswith(f"{exact_item_string}::"):
                decoded_values = _decode_appdata_values(fields, raw_values)
                matches.append(
                    {
                        "item_string": item_string,
                        "match_type": "exact" if item_string == exact_item_string else "variant",
                        "values": decoded_values,
                    }
                )

        if matches:
            exact_matches = [entry for entry in matches if entry["match_type"] == "exact"]
            selected = exact_matches[:1] if exact_matches else matches[:5]
            datasets.append(
                {
                    "tag": tag,
                    "scope": scope,
                    "download_time_ts": metadata.get("downloadTime"),
                    "download_time": format_timestamp(metadata.get("downloadTime")),
                    "fields": fields,
                    "matches": selected,
                }
            )

    return {
        "item_id": item_id,
        "paths": paths,
        "app_info": app_info,
        "datasets": datasets,
    }


def render_price_lookup(result: dict[str, Any]) -> str:
    if not result["datasets"]:
        return f"No local TSM price match for item {result['item_id']}"

    lines = [f"Local TSM data for item {result['item_id']}"]
    if result.get("app_info", {}).get("last_sync"):
        lines.append(f"- app sync: {result['app_info']['last_sync']}")

    for dataset in result["datasets"]:
        lines.append(f"- {dataset['tag']} ({dataset['scope']}) | {dataset['download_time'] or 'unknown'}")
        for match in dataset["matches"]:
            lines.append(f"  - {match['item_string']}")
            for field, value in match["values"].items():
                lines.append(f"    - {field}: {_render_price_field(field, value)}")

    return "\n".join(lines)


def load_tsm_status(appdata_path: str | Path) -> dict[str, Any]:
    path = Path(appdata_path)
    status: dict[str, Any] = {
        "appdata_path": str(path),
        "exists": path.exists(),
    }
    if not path.exists():
        return status

    status["file_modified"] = format_timestamp(path.stat().st_mtime)
    status["file_modified_ts"] = int(path.stat().st_mtime)
    status["datasets"] = []

    for raw_line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        match = _LOADDATA_RE.match(raw_line)
        if not match:
            continue

        tag, scope, payload = match.groups()
        metadata = _parse_appdata_metadata(payload)

        if tag == "APP_INFO":
            status["app_info"] = {
                "version": metadata.get("version"),
                "last_sync_ts": metadata.get("lastSync"),
                "last_sync": format_timestamp(metadata.get("lastSync")),
            }
            continue

        status["datasets"].append(
            {
                "tag": tag,
                "scope": scope,
                "download_time_ts": metadata.get("downloadTime"),
                "download_time": format_timestamp(metadata.get("downloadTime")),
                "fields": _lua_array_to_list(metadata.get("fields", {})),
            }
        )

    return status


def format_copper(value: int | None) -> str | None:
    if value is None:
        return None
    gold, remainder = divmod(int(value), 10_000)
    silver, copper = divmod(remainder, 100)
    return f"{gold}g {silver}s {copper}c"


def format_timestamp(value: Any) -> str | None:
    if value in (None, 0, ""):
        return None
    return datetime.fromtimestamp(float(value)).astimezone().strftime("%Y-%m-%d %H:%M:%S %z")


def _resolve_retail_root(retail_root: str | Path | None) -> Path:
    if retail_root:
        path = Path(retail_root)
        if not path.exists():
            raise FileNotFoundError(f"Retail root not found: {path}")
        return path

    for candidate in _WOW_RETAIL_CANDIDATES:
        if candidate.exists():
            return candidate

    raise FileNotFoundError("World of Warcraft retail root not found")


def _resolve_account_root(retail_root: Path, account_root: str | Path | None) -> Path:
    if account_root:
        path = Path(account_root)
        if not path.exists():
            raise FileNotFoundError(f"Account root not found: {path}")
        return path

    account_dir = retail_root / "WTF" / "Account"
    if not account_dir.exists():
        raise FileNotFoundError(f"Account directory not found: {account_dir}")

    candidates = []
    for child in account_dir.iterdir():
        if not child.is_dir():
            continue
        probe = child / "SavedVariables" / "DataStore.lua"
        if probe.exists():
            candidates.append((probe.stat().st_mtime, child))

    if not candidates:
        raise FileNotFoundError(f"No account SavedVariables found under {account_dir}")

    candidates.sort(key=lambda item: item[0], reverse=True)
    return candidates[0][1]


def _load_manifest(path: Path) -> dict[str, dict[int, str]]:
    data = parse_lua_assignments(path.read_text(encoding="utf-8", errors="replace"))
    keys = _indexed_string_map(data.get("DataStore_CharacterIDs", {}).get("List", {}))
    guids = _indexed_string_map(data.get("DataStore_CharacterGUIDs", {}))
    return {
        "keys": keys,
        "guids": guids,
    }


def _load_indexed_table(path: Path, variable_name: str) -> dict[int, dict[str, Any]]:
    table = _load_table(path, variable_name)
    result: dict[int, dict[str, Any]] = {}
    for key, value in table.items():
        if isinstance(key, int) and isinstance(value, dict):
            result[key] = value
    return result


def _load_optional_indexed_table(path: Path, variable_name: str) -> dict[int, dict[str, Any]]:
    if not path.exists():
        return {}
    return _load_indexed_table(path, variable_name)


def _load_table(path: Path, variable_name: str) -> dict[Any, Any]:
    data = parse_lua_assignments(path.read_text(encoding="utf-8", errors="replace"))
    value = data.get(variable_name, {})
    return value if isinstance(value, dict) else {}


def _indexed_string_map(table: dict[Any, Any]) -> dict[int, str]:
    result: dict[int, str] = {}
    for key, value in table.items():
        if isinstance(key, int) and isinstance(value, str):
            result[key] = value
    return result


def _decode_character_level(value: Any) -> int | None:
    if not isinstance(value, int):
        return None
    return value & 0x7F


def _decode_rank(value: Any) -> tuple[int | None, int | None]:
    if not isinstance(value, int):
        return None, None
    return value & 0xFFFF, value >> 16


_NO_RECIPE_PROFESSIONS = {
    "archaeology",
    "fishing",
    "herbalism",
    "mining",
    "skinning",
}


def _aggregate_items(state: dict[str, Any]) -> dict[int, dict[str, Any]]:
    aggregated: dict[int, dict[str, Any]] = {}

    for character in state["characters"]:
        for source, item in _iter_character_items(character):
            _add_item(aggregated, character["name"], source, item)

    for item in _iter_warbank_items(state.get("_warbank", {})):
        _add_item(aggregated, "Warband", "warbank", item)

    return aggregated


def _iter_character_items(character: dict[str, Any]):
    yield from _iter_container_collection(character.get("_containers", {}).get("Containers", {}), "bags")
    yield from _iter_slot_collection(character.get("_bank", {}), "bank")
    yield from _iter_slot_collection(character.get("_reagents", {}), "reagents")
    yield from _iter_equipped_items(character.get("_inventory", {}).get("Inventory", {}))
    yield from _iter_auctions(character.get("_auctions_list", {}))


def _iter_container_collection(containers: dict[Any, Any], source: str):
    for _, bag in sorted(((key, value) for key, value in containers.items() if isinstance(key, int)), key=lambda item: item[0]):
        if isinstance(bag, dict):
            yield from _iter_slot_collection(bag, source)


def _iter_slot_collection(container: dict[Any, Any], source: str):
    items = container.get("items", {}) if isinstance(container, dict) else {}
    links = container.get("links", {}) if isinstance(container, dict) else {}
    for slot_id, slot in sorted(((key, value) for key, value in items.items() if isinstance(key, int)), key=lambda item: item[0]):
        if slot is None:
            continue
        item_id, count = _decode_datastore_slot(int(slot))
        link = links.get(slot_id) if isinstance(links, dict) else None
        yield source, {
            "item_id": item_id,
            "count": count,
            "link": link,
            "name": _extract_item_name(link),
        }


def _iter_equipped_items(inventory: dict[Any, Any]):
    for _, link in sorted(((key, value) for key, value in inventory.items() if isinstance(key, int)), key=lambda item: item[0]):
        if not isinstance(link, str):
            continue
        item_id = _extract_item_id(link)
        if item_id is None:
            continue
        yield "equipment", {
            "item_id": item_id,
            "count": 1,
            "link": link,
            "name": _extract_item_name(link),
        }


def _iter_auctions(auctions: dict[Any, Any]):
    for _, record in sorted(((key, value) for key, value in auctions.items() if isinstance(key, int)), key=lambda item: item[0]):
        if not isinstance(record, str):
            continue
        parsed = _parse_auction_record(record)
        if parsed:
            yield "auctions", parsed


def _iter_warbank_items(warbank: dict[Any, Any]):
    for _, tab in sorted(((key, value) for key, value in warbank.items() if isinstance(value, dict)), key=lambda item: str(item[0])):
        yield from (item for _, item in _iter_slot_collection(tab, "warbank"))


def _add_item(
    aggregated: dict[int, dict[str, Any]],
    owner_name: str,
    source: str,
    item: dict[str, Any],
) -> None:
    item_id = item["item_id"]
    entry = aggregated.setdefault(
        item_id,
        {
            "item_id": item_id,
            "name": item.get("name"),
            "total_count": 0,
            "sources": {},
            "characters": {},
        },
    )
    if not entry.get("name") and item.get("name"):
        entry["name"] = item["name"]

    entry["total_count"] += item["count"]
    entry["sources"][source] = entry["sources"].get(source, 0) + item["count"]

    character_entry = entry["characters"].setdefault(
        owner_name,
        {
            "name": owner_name,
            "total_count": 0,
            "sources": {},
        },
    )
    character_entry["total_count"] += item["count"]
    character_entry["sources"][source] = character_entry["sources"].get(source, 0) + item["count"]


def _decode_datastore_slot(slot: int) -> tuple[int, int]:
    version = (slot >> 13) & 0b111
    count_bits = 16 if version == 0 else 10
    count_mask = (1 << count_bits) - 1
    count = slot & count_mask
    item_id = slot >> count_bits
    return item_id, count


def _extract_item_id(link: str | None) -> int | None:
    if not isinstance(link, str):
        return None
    match = _ITEM_ID_RE.search(link)
    return int(match.group(1)) if match else None


def _extract_item_name(link: str | None) -> str | None:
    if not isinstance(link, str):
        return None
    match = _ITEM_NAME_RE.search(link)
    return match.group(1) if match else None


def _parse_auction_record(record: str) -> dict[str, Any] | None:
    parts = record.split("|")
    if len(parts) < 3:
        return None
    try:
        item_id = int(parts[1])
        count = int(parts[2] or 0)
    except ValueError:
        return None
    return {
        "item_id": item_id,
        "count": count,
        "link": None,
        "name": None,
    }


def _parse_appdata_metadata(payload: str) -> dict[str, Any]:
    if ",data={" in payload:
        metadata_end = payload.index(",data={")
        metadata_payload = payload[:metadata_end] + "}"
    else:
        metadata_payload = payload
    value = parse_lua_value(metadata_payload)
    return value if isinstance(value, dict) else {}


def _extract_appdata_item_blob(payload: str) -> str:
    marker = ",data={"
    data_start = payload.index(marker) + len(marker)
    return payload[data_start:-2]


def _iter_appdata_rows(item_blob: str):
    for match in _APPDATA_ROW_RE.finditer(item_blob):
        item_string, raw_values = match.groups()
        if item_string.isdigit():
            item_string = f"i:{item_string}"
        yield item_string, raw_values


def _decode_appdata_values(fields: list[str], raw_values: str) -> dict[str, int]:
    values = raw_values.split(",")
    decoded: dict[str, int] = {}
    for field, value in zip(fields[1:], values):
        decoded[field] = _decode_tsm_base32(value)
    return decoded


def _decode_tsm_base32(value: str) -> int:
    if len(value) > 6:
        return int(value[-6:], 32) + int(value[:-6], 32) * (2**30)
    return int(value, 32)


def _lua_array_to_list(value: Any) -> list[Any]:
    if not isinstance(value, dict):
        return []
    return [item for _, item in sorted(((key, item) for key, item in value.items() if isinstance(key, int)), key=lambda entry: entry[0])]


def _render_price_field(field: str, value: int) -> str:
    non_currency_fields = {"numAuctions", "regionSoldPerDay", "regionSalePercent", "saleRate"}
    if field in non_currency_fields:
        return str(value)
    if any(token in field.lower() for token in ("buyout", "value", "historical", "sale")):
        return f"{value} ({format_copper(value)})"
    return str(value)
