from __future__ import annotations

import json
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from wow_tools.config import ACCOUNT_DIR
from wow_tools.local_account import resolve_paths
from wow_tools.lua_table import parse_lua_assignments

_RECIPE_ID_SHIFT = 7
_LEARNED_SHIFT = 2

_PROFESSION_ALIASES = {
    "alchemy": "alchemy",
    "alchimie": "alchemy",
    "archaeology": "archaeology",
    "archaeologie": "archaeology",
    "archéologie": "archaeology",
    "blacksmithing": "blacksmithing",
    "calligraphie": "inscription",
    "cooking": "cooking",
    "cuisine": "cooking",
    "couture": "tailoring",
    "cuir": "leatherworking",
    "depecage": "skinning",
    "dépeçage": "skinning",
    "enchantement": "enchanting",
    "enchanting": "enchanting",
    "engineering": "engineering",
    "fishing": "fishing",
    "forge": "blacksmithing",
    "herbalism": "herbalism",
    "herboristerie": "herbalism",
    "ingénierie": "engineering",
    "inscription": "inscription",
    "jewelcrafting": "jewelcrafting",
    "joaillerie": "jewelcrafting",
    "leatherworking": "leatherworking",
    "minage": "mining",
    "mining": "mining",
    "peche": "fishing",
    "pêche": "fishing",
    "skinning": "skinning",
    "tailoring": "tailoring",
    "travail": "leatherworking",
}


def load_recipe_ownership_index(
    retail_root: str | Path | None = None,
    account_root: str | Path | None = None,
) -> dict[str, Any]:
    paths = resolve_paths(retail_root, account_root)
    saved_variables = Path(paths["saved_variables"])
    datastore_path = saved_variables / "DataStore.lua"
    crafts_path = saved_variables / "DataStore_Crafts.lua"

    if not datastore_path.exists() or not crafts_path.exists():
        return {
            "paths": paths,
            "spell_id_to_owners": {},
            "profession_holders": {},
            "profession_scanned_holders": {},
        }

    manifest = parse_lua_assignments(datastore_path.read_text(encoding="utf-8", errors="replace"))
    crafts_data = parse_lua_assignments(crafts_path.read_text(encoding="utf-8", errors="replace"))
    character_keys = manifest.get("DataStore_CharacterIDs", {}).get("List", {})
    craft_characters = crafts_data.get("DataStore_Crafts_Characters", {})

    spell_id_to_owners: dict[int, list[str]] = {}
    profession_holders: dict[str, list[str]] = {}
    profession_scanned_holders: dict[str, list[str]] = {}

    for index, key in sorted(
        ((key, value) for key, value in character_keys.items() if isinstance(key, int) and isinstance(value, str)),
        key=lambda item: item[0],
    ):
        character_name = _character_name_from_key(key)
        character_raw = craft_characters.get(index, {})
        professions = character_raw.get("Professions", {}) if isinstance(character_raw, dict) else {}

        for _, profession_raw in sorted(
            ((key, value) for key, value in professions.items() if isinstance(key, int) and isinstance(value, dict)),
            key=lambda item: item[0],
        ):
            profession_key = _canonical_profession_key(
                profession_raw.get("Name"),
                profession_raw.get("CurrentLevelName"),
            )
            if not profession_key:
                continue

            _append_unique(profession_holders, profession_key, character_name)

            crafts = profession_raw.get("Crafts", {})
            has_craft_scan = False
            for _, craft_rows in sorted(
                ((key, value) for key, value in crafts.items() if isinstance(key, int) and isinstance(value, dict)),
                key=lambda item: item[0],
            ):
                for _, encoded_recipe in sorted(
                    ((key, value) for key, value in craft_rows.items() if isinstance(key, int) and isinstance(value, int)),
                    key=lambda item: item[0],
                ):
                    has_craft_scan = True
                    # DataStore_Crafts packs Retail recipe rows with the learned bit at 2
                    # and the recipe/spell id starting at bit 7.
                    spell_id = encoded_recipe >> _RECIPE_ID_SHIFT
                    learned = bool((encoded_recipe >> _LEARNED_SHIFT) & 1)
                    if learned:
                        _append_unique(spell_id_to_owners, spell_id, character_name)

            if has_craft_scan:
                _append_unique(profession_scanned_holders, profession_key, character_name)

    return {
        "paths": paths,
        "spell_id_to_owners": spell_id_to_owners,
        "profession_holders": profession_holders,
        "profession_scanned_holders": profession_scanned_holders,
    }


def recipe_ownership(
    ownership_index: dict[str, Any] | None,
    *,
    spell_id: int | None,
    profession: str | None,
) -> dict[str, Any]:
    if not ownership_index:
        return {
            "status": "unknown",
            "known_by": [],
            "profession_holders": [],
            "profession_scanned_holders": [],
        }

    profession_key = _canonical_profession_key(profession, profession)
    spell_id_to_owners = ownership_index.get("spell_id_to_owners", {})
    profession_holders_index = ownership_index.get("profession_holders", {})
    profession_scanned_index = ownership_index.get("profession_scanned_holders", {})

    known_by = list(spell_id_to_owners.get(spell_id, [])) if spell_id is not None else []
    profession_holders = list(profession_holders_index.get(profession_key, [])) if profession_key else []
    profession_scanned_holders = list(profession_scanned_index.get(profession_key, [])) if profession_key else []

    if known_by:
        status = "known"
    elif spell_id is None:
        status = "unknown"
    elif profession_scanned_holders:
        status = "not_known"
    elif profession_holders:
        status = "unscanned"
    elif profession_key:
        status = "no_profession"
    else:
        status = "unknown"

    return {
        "status": status,
        "known_by": known_by,
        "profession_holders": profession_holders,
        "profession_scanned_holders": profession_scanned_holders,
    }


def recipe_is_owned(ownership: dict[str, Any]) -> bool:
    return bool(ownership.get("known_by"))


def build_recipe_ownership_report(
    *,
    spell_id: int,
    profession: str | None = None,
    retail_root: str | Path | None = None,
    account_root: str | Path | None = None,
) -> dict[str, Any]:
    ownership_index = load_recipe_ownership_index(retail_root, account_root)
    ownership = recipe_ownership(
        ownership_index,
        spell_id=spell_id,
        profession=profession,
    )
    known_by = list(ownership.get("known_by", []))
    profession_holders = list(ownership.get("profession_holders", []))
    profession_scanned_holders = list(ownership.get("profession_scanned_holders", []))
    known_set = set(known_by)
    scanned_set = set(profession_scanned_holders)

    return {
        "generated_at": datetime.now(timezone.utc).astimezone().isoformat(),
        "paths": ownership_index.get("paths", {}),
        "spell_id": spell_id,
        "profession": profession,
        "status": ownership.get("status"),
        "known_by": known_by,
        "profession_holders": profession_holders,
        "profession_scanned_holders": profession_scanned_holders,
        "scanned_without_recipe": [name for name in profession_scanned_holders if name not in known_set],
        "unscanned_profession_holders": [name for name in profession_holders if name not in scanned_set],
    }


def render_recipe_ownership_report(report: dict[str, Any]) -> str:
    lines = [
        "Recipe Ownership",
        f"- generated: {report.get('generated_at') or 'unknown'}",
        f"- spell id: {report['spell_id']}",
        f"- profession: {report.get('profession') or 'unknown'}",
        f"- status: {report.get('status') or 'unknown'}",
        f"- known by ({len(report.get('known_by', []))}): {', '.join(report.get('known_by', [])) or 'none'}",
    ]
    if report.get("scanned_without_recipe"):
        lines.append(
            f"- scanned without recipe ({len(report['scanned_without_recipe'])}): "
            + ", ".join(report["scanned_without_recipe"])
        )
    if report.get("unscanned_profession_holders"):
        lines.append(
            f"- unscanned profession holders ({len(report['unscanned_profession_holders'])}): "
            + ", ".join(report["unscanned_profession_holders"])
        )
    return "\n".join(lines)


def save_recipe_ownership_report(report: dict[str, Any], slug: str) -> dict[str, str]:
    ACCOUNT_DIR.mkdir(parents=True, exist_ok=True)
    json_path = ACCOUNT_DIR / f"{slug}.json"
    markdown_path = ACCOUNT_DIR / f"{slug}.md"
    json_path.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    markdown_path.write_text(render_recipe_ownership_report(report), encoding="utf-8")
    return {
        "json": str(json_path),
        "markdown": str(markdown_path),
    }


def _canonical_profession_key(name: Any, current_level_name: Any) -> str | None:
    candidates: list[str] = []
    for value in (name, current_level_name):
        if isinstance(value, str) and value.strip():
            lowered = value.casefold()
            candidates.append(lowered)
            candidates.extend(token for token in lowered.split() if token)

    for candidate in candidates:
        profession_key = _PROFESSION_ALIASES.get(candidate)
        if profession_key:
            return profession_key

    for candidate in candidates:
        for alias, profession_key in _PROFESSION_ALIASES.items():
            if candidate.endswith(f" {alias}"):
                return profession_key

    return name.casefold() if isinstance(name, str) and name else None


def _character_name_from_key(key: str) -> str:
    parts = key.split(".", 2)
    if len(parts) == 3:
        return parts[2]
    return key


def _append_unique(index: dict[Any, list[str]], key: Any, value: str) -> None:
    bucket = index.setdefault(key, [])
    if value not in bucket:
        bucket.append(value)
