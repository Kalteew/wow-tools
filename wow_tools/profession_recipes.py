from __future__ import annotations

import json
import re
from datetime import datetime, timezone
from typing import Any

from wow_tools.cache import HttpCache
from wow_tools.config import WOWHEAD_LIST_TTL_SECONDS
from wow_tools.db import (
    delete_profession_recipes,
    replace_recipe_reagents,
    upsert_profession_recipe,
    upsert_recipe_item,
)
from wow_tools.http import fetch_text


PROFESSION_SKILL_PAGES: dict[str, tuple[int, str]] = {
    "alchemy": (171, "alchemy"),
    "blacksmithing": (164, "blacksmithing"),
    "cooking": (185, "cooking"),
    "enchanting": (333, "enchanting"),
    "engineering": (202, "engineering"),
    "inscription": (773, "inscription"),
    "jewelcrafting": (755, "jewelcrafting"),
    "leatherworking": (165, "leatherworking"),
    "mining": (186, "mining"),
    "tailoring": (197, "tailoring"),
}

_LISTVIEW_MARKER = "new Listview({"
_GATHERER_MARKER = "WH.Gatherer.addData("
_STRING_FIELD_RE = re.compile(r'(?P<key>[A-Za-z_][A-Za-z0-9_]*)\s*:\s*(?P<quote>"|\')(?P<value>.*?)(?P=quote)', re.S)


def _now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def supported_professions() -> list[str]:
    return sorted(PROFESSION_SKILL_PAGES)


def default_professions() -> list[str]:
    return supported_professions()


def _skill_url(skill_id: int, slug: str) -> str:
    return f"https://www.wowhead.com/skill={skill_id}/{slug}"


def _scan_balanced(text: str, start: int, opener: str, closer: str) -> tuple[str, int]:
    depth = 0
    string_quote: str | None = None
    escaped = False

    for index in range(start, len(text)):
        char = text[index]
        if string_quote is not None:
            if escaped:
                escaped = False
                continue
            if char == "\\":
                escaped = True
                continue
            if char == string_quote:
                string_quote = None
            continue

        if char in ("'", '"'):
            string_quote = char
            continue
        if char == opener:
            depth += 1
            continue
        if char == closer:
            depth -= 1
            if depth == 0:
                return text[start : index + 1], index + 1

    raise RuntimeError(f"Could not find closing {closer!r}")


def _extract_field_string(object_text: str, key: str) -> str | None:
    for match in _STRING_FIELD_RE.finditer(object_text):
        if match.group("key") == key:
            return bytes(match.group("value"), "utf-8").decode("unicode_escape")
    return None


def _extract_field_array(object_text: str, key: str) -> str | None:
    marker = f"{key}:"
    index = object_text.find(marker)
    if index == -1:
        return None
    array_start = object_text.find("[", index + len(marker))
    if array_start == -1:
        return None
    array_text, _ = _scan_balanced(object_text, array_start, "[", "]")
    return array_text


def _extract_spell_listviews(html: str) -> list[dict[str, Any]]:
    listviews: list[dict[str, Any]] = []
    index = 0

    while True:
        marker_index = html.find(_LISTVIEW_MARKER, index)
        if marker_index == -1:
            break
        object_start = html.find("{", marker_index)
        object_text, index = _scan_balanced(html, object_start, "{", "}")
        if "template: 'spell'" not in object_text and 'template: "spell"' not in object_text:
            continue

        listview_id = _extract_field_string(object_text, "id")
        listview_name = _extract_field_string(object_text, "name")
        data_text = _extract_field_array(object_text, "data")
        if not listview_id or not listview_name or not data_text:
            continue
        if listview_id == "recipes":
            continue

        listviews.append(
            {
                "listview_id": listview_id,
                "listview_name": listview_name,
                "data": json.loads(data_text),
            }
        )

    return listviews


def _extract_item_payloads(html: str) -> dict[int, dict[str, Any]]:
    payloads: dict[int, dict[str, Any]] = {}
    index = 0

    while True:
        marker_index = html.find(_GATHERER_MARKER, index)
        if marker_index == -1:
            break
        args_start = marker_index + len(_GATHERER_MARKER)
        brace_start = html.find("{", args_start)
        call_prefix = html[args_start:brace_start]
        index = brace_start

        if not call_prefix.strip().startswith("3,"):
            continue

        object_text, index = _scan_balanced(html, brace_start, "{", "}")
        try:
            payload = json.loads(object_text)
        except json.JSONDecodeError:
            continue

        for item_id, item_data in payload.items():
            if not str(item_id).isdigit() or not isinstance(item_data, dict):
                continue
            payloads[int(item_id)] = item_data

    return payloads


def _item_name(item_id: int, item_data: dict[int, dict[str, Any]]) -> str:
    payload = item_data.get(item_id, {})
    return str(payload.get("displayName") or payload.get("name_enus") or payload.get("name") or f"Item {item_id}")


def _normalize_quantity(creates: list[Any] | None) -> tuple[float | None, float | None]:
    if not creates or len(creates) < 2:
        return None, None
    minimum = float(creates[1])
    maximum = float(creates[2] if len(creates) > 2 else creates[1])
    return minimum, maximum


def sync_profession_recipes(
    conn,
    cache: HttpCache,
    professions: list[str],
    *,
    force: bool = False,
) -> dict[str, Any]:
    synced_at = _now_iso()
    summary: dict[str, Any] = {
        "synced_at": synced_at,
        "professions": {},
        "recipes": 0,
        "items": 0,
    }

    for profession in professions:
        skill_id, slug = PROFESSION_SKILL_PAGES[profession]
        source_url = _skill_url(skill_id, slug)
        html = fetch_text(source_url, cache, WOWHEAD_LIST_TTL_SECONDS, force=force)
        listviews = _extract_spell_listviews(html)
        item_payloads = _extract_item_payloads(html)

        delete_profession_recipes(conn, profession)

        seen_items: set[int] = set()
        seen_spells: set[int] = set()
        recipes_synced = 0

        for item_id, payload in item_payloads.items():
            upsert_recipe_item(
                conn,
                {
                    "item_id": item_id,
                    "item_name": _item_name(item_id, item_payloads),
                    "icon": payload.get("icon"),
                    "quality": payload.get("quality"),
                    "raw_payload_json": payload,
                    "source_url": source_url,
                    "last_sync": synced_at,
                },
            )
            seen_items.add(item_id)

        for listview in listviews:
            for recipe in listview["data"]:
                spell_id = int(recipe["id"])
                if spell_id in seen_spells:
                    continue
                seen_spells.add(spell_id)

                creates = recipe.get("creates") or []
                output_item_id = int(creates[0]) if creates else None
                min_quantity, max_quantity = _normalize_quantity(creates)
                raw_reagents = recipe.get("reagents") or []
                reagent_rows: list[dict[str, Any]] = []

                for reagent_order, raw_reagent in enumerate(raw_reagents, start=1):
                    if not raw_reagent or len(raw_reagent) < 2:
                        continue
                    reagent_item_id = int(raw_reagent[0])
                    quantity = float(raw_reagent[1])
                    if reagent_item_id not in seen_items:
                        upsert_recipe_item(
                            conn,
                            {
                                "item_id": reagent_item_id,
                                "item_name": _item_name(reagent_item_id, item_payloads),
                                "icon": item_payloads.get(reagent_item_id, {}).get("icon"),
                                "quality": item_payloads.get(reagent_item_id, {}).get("quality"),
                                "raw_payload_json": item_payloads.get(reagent_item_id),
                                "source_url": source_url,
                                "last_sync": synced_at,
                            },
                        )
                        seen_items.add(reagent_item_id)
                    reagent_rows.append(
                        {
                            "spell_id": spell_id,
                            "reagent_order": reagent_order,
                            "reagent_item_id": reagent_item_id,
                            "quantity": quantity,
                        }
                    )

                if output_item_id is not None and output_item_id not in seen_items:
                    upsert_recipe_item(
                        conn,
                        {
                            "item_id": output_item_id,
                            "item_name": _item_name(output_item_id, item_payloads),
                            "icon": item_payloads.get(output_item_id, {}).get("icon"),
                            "quality": item_payloads.get(output_item_id, {}).get("quality"),
                            "raw_payload_json": item_payloads.get(output_item_id),
                            "source_url": source_url,
                            "last_sync": synced_at,
                        },
                    )
                    seen_items.add(output_item_id)

                upsert_profession_recipe(
                    conn,
                    {
                        "spell_id": spell_id,
                        "profession": profession,
                        "skill_line_id": skill_id,
                        "listview_id": listview["listview_id"],
                        "listview_name": listview["listview_name"],
                        "recipe_name": recipe.get("displayName") or recipe.get("name") or f"Spell {spell_id}",
                        "output_item_id": output_item_id,
                        "output_min_quantity": min_quantity,
                        "output_max_quantity": max_quantity,
                        "learned_at": recipe.get("learnedat"),
                        "category_id": recipe.get("cat"),
                        "has_optional_reagents": 1 if recipe.get("optionalReagents") else 0,
                        "raw_payload_json": recipe,
                        "source_url": source_url,
                        "last_sync": synced_at,
                    },
                )
                replace_recipe_reagents(conn, spell_id, reagent_rows)
                recipes_synced += 1

        conn.commit()
        summary["professions"][profession] = {
            "recipes": recipes_synced,
            "items": len(seen_items),
            "listviews": len(listviews),
            "source_url": source_url,
        }
        summary["recipes"] += recipes_synced
        summary["items"] += len(seen_items)

    return summary


def _load_recipe_rows(conn, where_sql: str, params: tuple[Any, ...]) -> list[dict[str, Any]]:
    rows = conn.execute(
        f"""
        SELECT
            r.spell_id,
            r.profession,
            r.skill_line_id,
            r.listview_id,
            r.listview_name,
            r.recipe_name,
            r.output_item_id,
            r.output_min_quantity,
            r.output_max_quantity,
            r.learned_at,
            r.category_id,
            r.has_optional_reagents,
            r.raw_payload_json,
            i.item_name AS output_item_name
        FROM profession_recipes r
        LEFT JOIN recipe_items i
            ON i.item_id = r.output_item_id
        {where_sql}
        ORDER BY r.profession, r.listview_name, r.recipe_name, r.spell_id
        """,
        params,
    )
    results = []
    for row in rows:
        entry = dict(row)
        entry["raw_payload_json"] = json.loads(entry["raw_payload_json"])
        results.append(entry)
    return results


def _load_reagents(conn, spell_id: int) -> list[dict[str, Any]]:
    rows = conn.execute(
        """
        SELECT
            rr.reagent_order,
            rr.reagent_item_id,
            rr.quantity,
            ri.item_name AS reagent_item_name
        FROM recipe_reagents rr
        LEFT JOIN recipe_items ri
            ON ri.item_id = rr.reagent_item_id
        WHERE rr.spell_id = ?
        ORDER BY rr.reagent_order
        """,
        (spell_id,),
    )
    return [dict(row) for row in rows]


def _serialize_recipe_row(recipe_row: dict[str, Any]) -> dict[str, Any]:
    raw_payload = recipe_row["raw_payload_json"]
    return {
        "spell_id": recipe_row["spell_id"],
        "profession": recipe_row["profession"],
        "skill_line_id": recipe_row["skill_line_id"],
        "expansion": recipe_row["listview_name"],
        "recipe_name": recipe_row["recipe_name"],
        "output": {
            "item_id": recipe_row["output_item_id"],
            "item_name": recipe_row["output_item_name"] or (f"Item {recipe_row['output_item_id']}" if recipe_row["output_item_id"] else None),
            "min_quantity": recipe_row["output_min_quantity"],
            "max_quantity": recipe_row["output_max_quantity"],
        },
        "learned_at": recipe_row["learned_at"],
        "category_id": recipe_row["category_id"],
        "has_optional_reagents": bool(recipe_row["has_optional_reagents"]),
        "optional_reagents": raw_payload.get("optionalReagents") or [],
    }


def _build_recipe_tree(
    conn,
    recipe_row: dict[str, Any],
    *,
    max_depth: int,
    visited_items: set[int],
    referenced_item_ids: set[int],
) -> dict[str, Any]:
    node = _serialize_recipe_row(recipe_row)
    output_item_id = recipe_row["output_item_id"]
    if output_item_id is not None:
        referenced_item_ids.add(int(output_item_id))

    reagents: list[dict[str, Any]] = []
    for reagent in _load_reagents(conn, recipe_row["spell_id"]):
        reagent_item_id = int(reagent["reagent_item_id"])
        referenced_item_ids.add(reagent_item_id)
        reagent_node = {
            "item_id": reagent_item_id,
            "item_name": reagent["reagent_item_name"] or f"Item {reagent_item_id}",
            "quantity": reagent["quantity"],
            "recipes": [],
        }

        if max_depth > 0 and reagent_item_id not in visited_items:
            child_recipes = _load_recipe_rows(
                conn,
                "WHERE r.output_item_id = ?",
                (reagent_item_id,),
            )
            if child_recipes:
                reagent_node["recipes"] = [
                    _build_recipe_tree(
                        conn,
                        child_recipe,
                        max_depth=max_depth - 1,
                        visited_items=visited_items | {reagent_item_id},
                        referenced_item_ids=referenced_item_ids,
                    )
                    for child_recipe in child_recipes
                ]

        reagents.append(reagent_node)

    node["reagents"] = reagents
    return node


def query_recipes(
    conn,
    *,
    item_id: int | None = None,
    spell_id: int | None = None,
    name: str | None = None,
    professions: list[str] | None = None,
    max_depth: int = 3,
    limit: int = 20,
) -> dict[str, Any]:
    if item_id is not None:
        recipe_rows = _load_recipe_rows(conn, "WHERE r.output_item_id = ?", (item_id,))
        query = {"item_id": item_id, "max_depth": max_depth}
        mode = "tree"
    elif spell_id is not None:
        recipe_rows = _load_recipe_rows(conn, "WHERE r.spell_id = ?", (spell_id,))
        query = {"spell_id": spell_id, "max_depth": max_depth}
        mode = "tree"
    else:
        where_clauses: list[str] = []
        params: list[Any] = []
        if name:
            where_clauses.append("(LOWER(r.recipe_name) LIKE ? OR LOWER(COALESCE(i.item_name, '')) LIKE ?)")
            like = f"%{name.casefold()}%"
            params.extend([like, like])
        if professions:
            where_clauses.append(f"r.profession IN ({','.join('?' for _ in professions)})")
            params.extend(professions)
        if not where_clauses:
            raise ValueError("query-recipes requires --item-id, --spell-id, --name, or --profession")
        where_sql = "WHERE " + " AND ".join(where_clauses)
        recipe_rows = _load_recipe_rows(conn, where_sql, tuple(params))[:limit]
        query = {"name": name, "professions": professions or [], "limit": limit}
        mode = "search"

    if mode == "search":
        return {
            "mode": mode,
            "query": query,
            "count": len(recipe_rows),
            "rows": [_serialize_recipe_row(recipe_row) for recipe_row in recipe_rows],
        }

    referenced_item_ids: set[int] = set()
    rows = [
        _build_recipe_tree(
            conn,
            recipe_row,
            max_depth=max_depth,
            visited_items={item_id} if item_id is not None else ({recipe_row["output_item_id"]} if recipe_row["output_item_id"] else set()),
            referenced_item_ids=referenced_item_ids,
        )
        for recipe_row in recipe_rows
    ]
    return {
        "mode": mode,
        "query": query,
        "count": len(rows),
        "referenced_item_ids": sorted(referenced_item_ids),
        "rows": rows,
    }


def _render_tree_recipe(node: dict[str, Any], indent: int = 0) -> list[str]:
    prefix = "  " * indent
    output = node["output"]
    output_name = output["item_name"] or node["recipe_name"]
    quantity = output["min_quantity"]
    lines = [
        f"{prefix}- [{node['profession']}] {node['recipe_name']} -> {output_name}"
        + (f" x{quantity:g}" if quantity else "")
    ]
    for reagent in node["reagents"]:
        lines.append(f"{prefix}  - {reagent['item_name']} ({reagent['item_id']}) x{reagent['quantity']:g}")
        for child in reagent["recipes"]:
            lines.extend(_render_tree_recipe(child, indent + 2))
    return lines


def render_recipe_query(result: dict[str, Any]) -> str:
    if result["mode"] == "search":
        if not result["rows"]:
            return "No matching recipes"
        lines = [f"Recipe matches: {result['count']}"]
        for row in result["rows"]:
            output = row["output"]
            output_label = output["item_name"] or "no output item"
            lines.append(
                f"- [{row['profession']}] {row['recipe_name']} | {row['expansion']} | spell={row['spell_id']} | output={output_label}"
            )
        return "\n".join(lines)

    if not result["rows"]:
        return "No local recipe tree match"

    lines = [f"Recipe trees: {result['count']}"]
    for row in result["rows"]:
        lines.extend(_render_tree_recipe(row))
    lines.append("")
    lines.append(f"Referenced item ids: {', '.join(str(item_id) for item_id in result['referenced_item_ids'])}")
    return "\n".join(lines).rstrip()
