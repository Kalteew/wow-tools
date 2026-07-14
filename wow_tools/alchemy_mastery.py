from __future__ import annotations

import json
from pathlib import Path
from typing import Any, Literal

from wow_tools.local_account import resolve_paths
from wow_tools.lua_table import parse_lua_assignments

AlchemyMastery = Literal["transmutation", "potions", "flasks"]

ALCHEMY_OUTPUT_MULTIPLIER = 1.2

_TRANSMUTATION_MASTERY_EXPANSIONS = {
    "classic",
    "burning-crusade",
    "wrath-of-the-lich-king",
    "cataclysm",
    "mists-of-pandaria",
}

_EXPANSION_ALIASES = {
    "classic": "classic",
    "vanilla": "classic",
    "the burning crusade": "burning-crusade",
    "burning crusade": "burning-crusade",
    "tbc": "burning-crusade",
    "wrath of the lich king": "wrath-of-the-lich-king",
    "wotlk": "wrath-of-the-lich-king",
    "cataclysm": "cataclysm",
    "mists of pandaria": "mists-of-pandaria",
    "mop": "mists-of-pandaria",
    "warlords of draenor": "warlords-of-draenor",
    "legion": "legion",
    "battle for azeroth": "battle-for-azeroth",
    "bfa": "battle-for-azeroth",
    "shadowlands": "shadowlands",
    "dragonflight": "dragonflight",
    "the war within": "the-war-within",
    "tww": "the-war-within",
}

# The node ids below come from the local AllTheThings reference DB.
# They are intentionally broad enough to catch the relevant alchemy branches
# without requiring a live Wowhead lookup.
_NODE_ID_TO_MASTERY: dict[int, set[AlchemyMastery]] = {
    19483: {"potions"},
    19484: {"potions"},
    19485: {"potions"},
    19486: {"potions"},
    19487: {"potions"},
    99041: {"potions"},
    107101: {"potions"},
    107102: {"potions"},
    107104: {"potions"},
    107105: {"potions"},
    107107: {"potions"},
    22479: {"flasks"},
    22480: {"flasks"},
    22481: {"flasks"},
    22482: {"flasks"},
    22483: {"flasks"},
    98951: {"flasks"},
    98953: {"flasks"},
    107208: {"flasks"},
    107211: {"flasks"},
    107212: {"flasks"},
    107213: {"flasks"},
    107214: {"flasks"},
    19538: {"transmutation"},
    99058: {"transmutation"},
    99059: {"transmutation"},
    107254: {"transmutation"},
    107255: {"transmutation"},
    107256: {"transmutation"},
    107257: {"transmutation"},
}


def load_character_alchemy_masteries(
    retail_root: str | Path | None = None,
    account_root: str | Path | None = None,
) -> dict[str, set[AlchemyMastery]]:
    paths = resolve_paths(retail_root, account_root)
    saved_variables = Path(paths["saved_variables"])
    mastery_index = _load_override_masteries(saved_variables)
    att_path = saved_variables / "AllTheThings.lua"
    if not att_path.exists():
        return mastery_index

    parsed = parse_lua_assignments(att_path.read_text(encoding="utf-8", errors="replace"))
    characters = parsed.get("ATTCharacterData", {})

    for _, character in characters.items():
        if not isinstance(character, dict):
            continue
        name = character.get("name")
        if not isinstance(name, str) or not name.strip():
            continue

        branches = _masteries_from_nodes(character.get("ProfessionNodes", {}))
        if branches:
            mastery_index.setdefault(name, set()).update(branches)

    return mastery_index


def recipe_alchemy_branch(recipe_name: str | None, profession: str | None = None) -> AlchemyMastery | None:
    if profession is not None and profession.casefold() != "alchemy":
        return None

    name = (recipe_name or "").casefold()
    if not name:
        return None

    if (
        name.startswith("transmute:")
        or "transmutation" in name
        or "thaumaturgy" in name
        or "metamorphic" in name
        or "synthesis" in name
    ):
        return "transmutation"

    if "potion" in name or "draught" in name or "tonic" in name or "elixir" in name or "philter" in name:
        return "potions"

    if "flask" in name or "phial" in name or "libation" in name:
        return "flasks"

    return None


def recipe_mastery_bonus(
    recipe_name: str | None,
    profession: str | None,
    *,
    recipe_expansion: str | None = None,
    known_by: list[str],
    mastery_index: dict[str, set[AlchemyMastery]],
) -> tuple[float, AlchemyMastery | None, str | None]:
    branch = recipe_alchemy_branch(recipe_name, profession)
    if branch is None or not known_by:
        return 1.0, branch, None

    if branch == "transmutation" and not _transmutation_mastery_applies(recipe_expansion):
        return 1.0, None, None

    for owner in known_by:
        branches = mastery_index.get(owner)
        if branches and branch in branches:
            return ALCHEMY_OUTPUT_MULTIPLIER, branch, owner

    return 1.0, branch, None


def _masteries_from_nodes(nodes: Any) -> set[AlchemyMastery]:
    if not isinstance(nodes, dict):
        return set()

    branches: set[AlchemyMastery] = set()
    for node_id, value in nodes.items():
        if not isinstance(node_id, int):
            continue
        branches.update(_NODE_ID_TO_MASTERY.get(node_id, ()))
        # Some saved variables store booleans or counters; the value itself is
        # not needed here, only the node id.
        _ = value
    return branches


def _load_override_masteries(saved_variables: Path) -> dict[str, set[AlchemyMastery]]:
    override_path = saved_variables / "AlchemyMasteries.json"
    if not override_path.exists():
        return {}

    try:
        payload = json.loads(override_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return {}

    if not isinstance(payload, dict):
        return {}

    mastery_index: dict[str, set[AlchemyMastery]] = {}
    for raw_name, raw_value in payload.items():
        if not isinstance(raw_name, str) or not raw_name.strip():
            continue
        branches = _normalize_mastery_override(raw_value)
        if branches:
            mastery_index[raw_name] = branches
    return mastery_index


def _normalize_mastery_override(value: Any) -> set[AlchemyMastery]:
    branches: set[AlchemyMastery] = set()
    raw_values: list[Any]
    if isinstance(value, str):
        raw_values = [value]
    elif isinstance(value, list):
        raw_values = value
    else:
        return branches

    for raw_value in raw_values:
        if not isinstance(raw_value, str):
            continue
        normalized = raw_value.casefold().strip()
        if normalized in {"transmutation", "potions", "flasks"}:
            branches.add(normalized)
    return branches


def _transmutation_mastery_applies(recipe_expansion: str | None) -> bool:
    normalized = _normalize_expansion(recipe_expansion)
    return normalized in _TRANSMUTATION_MASTERY_EXPANSIONS


def _normalize_expansion(value: str | None) -> str | None:
    if not isinstance(value, str):
        return None

    normalized = value.casefold().strip()
    if not normalized:
        return None

    normalized = normalized.replace("’", "'")
    normalized = normalized.replace("_", " ")
    normalized = normalized.replace("-", " ")
    normalized = " ".join(normalized.split())
    return _EXPANSION_ALIASES.get(normalized, normalized)
