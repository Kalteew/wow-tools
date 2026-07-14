from __future__ import annotations

from datetime import datetime, timezone
from typing import Any, Iterable


def _now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def load_favorite_spell_ids(conn) -> set[int]:
    return {int(row["spell_id"]) for row in conn.execute("SELECT spell_id FROM favorite_recipes")}


def ensure_favorite_spell_ids(conn, spell_ids: Iterable[int]) -> int:
    existing = load_favorite_spell_ids(conn)
    if existing:
        return 0

    inserted = 0
    for spell_id in spell_ids:
        spell_id = int(spell_id)
        if spell_id in existing:
            continue
        conn.execute(
            """
            INSERT INTO favorite_recipes (spell_id, created_at, seeded)
            VALUES (?, ?, 1)
            """,
            (spell_id, _now_iso()),
        )
        inserted += 1
    if inserted:
        conn.commit()
    return inserted


def set_favorite_spell_id(conn, spell_id: int, enabled: bool) -> None:
    spell_id = int(spell_id)
    if enabled:
        conn.execute(
            """
            INSERT INTO favorite_recipes (spell_id, created_at, seeded)
            VALUES (?, ?, 0)
            ON CONFLICT(spell_id) DO UPDATE SET
                created_at = excluded.created_at,
                seeded = excluded.seeded
            """,
            (spell_id, _now_iso()),
        )
    else:
        conn.execute("DELETE FROM favorite_recipes WHERE spell_id = ?", (spell_id,))
    conn.commit()


def favorite_spell_ids_from_rows(rows: list[dict[str, Any]]) -> set[int]:
    return {
        int(row["spell_id"])
        for row in rows
        if row.get("recipe_favorite") and row.get("spell_id") is not None
    }
