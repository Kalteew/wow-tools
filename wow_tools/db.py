from __future__ import annotations

import json
import sqlite3
from pathlib import Path
from typing import Any

from wow_tools.config import DB_PATH


def connect(db_path: Path = DB_PATH) -> sqlite3.Connection:
    db_path.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(db_path)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys = ON")
    init_db(conn)
    return conn


def init_db(conn: sqlite3.Connection) -> None:
    conn.executescript(
        """
        CREATE TABLE IF NOT EXISTS items (
            item_id INTEGER PRIMARY KEY,
            profession TEXT NOT NULL,
            expansion_seed TEXT NOT NULL,
            expansion_detected TEXT,
            category TEXT NOT NULL,
            family_name TEXT NOT NULL,
            item_name TEXT NOT NULL,
            wowhead_url TEXT,
            icon_url TEXT,
            description TEXT,
            item_level INTEGER,
            req_level INTEGER,
            wowhead_quality INTEGER,
            wowhead_popularity INTEGER,
            source_kind TEXT,
            is_gatherable INTEGER NOT NULL DEFAULT 1,
            metadata_json TEXT,
            last_catalog_sync TEXT NOT NULL
        );

        CREATE INDEX IF NOT EXISTS idx_items_profession
            ON items (profession, expansion_seed, family_name);

        CREATE TABLE IF NOT EXISTS price_snapshots (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            item_id INTEGER NOT NULL REFERENCES items(item_id),
            region TEXT NOT NULL,
            source TEXT NOT NULL,
            fetched_at TEXT NOT NULL,
            updated_at TEXT,
            available_quantity INTEGER,
            min_buyout_copper INTEGER,
            market_value_copper INTEGER,
            historical_price_copper INTEGER,
            region_market_value_avg_copper INTEGER,
            region_historical_price_copper INTEGER,
            region_sale_avg_copper INTEGER,
            region_sale_rate REAL,
            region_avg_daily_sold REAL,
            raw_payload_json TEXT
        );

        CREATE INDEX IF NOT EXISTS idx_price_snapshots_item_region
            ON price_snapshots (item_id, region, fetched_at DESC);

        CREATE TABLE IF NOT EXISTS recipe_items (
            item_id INTEGER PRIMARY KEY,
            item_name TEXT NOT NULL,
            icon TEXT,
            quality INTEGER,
            raw_payload_json TEXT,
            source_url TEXT NOT NULL,
            last_sync TEXT NOT NULL
        );

        CREATE INDEX IF NOT EXISTS idx_recipe_items_name
            ON recipe_items (item_name);

        CREATE TABLE IF NOT EXISTS profession_recipes (
            spell_id INTEGER PRIMARY KEY,
            profession TEXT NOT NULL,
            skill_line_id INTEGER NOT NULL,
            listview_id TEXT NOT NULL,
            listview_name TEXT NOT NULL,
            recipe_name TEXT NOT NULL,
            output_item_id INTEGER REFERENCES recipe_items(item_id),
            output_min_quantity REAL,
            output_max_quantity REAL,
            learned_at INTEGER,
            category_id INTEGER,
            has_optional_reagents INTEGER NOT NULL DEFAULT 0,
            raw_payload_json TEXT NOT NULL,
            source_url TEXT NOT NULL,
            last_sync TEXT NOT NULL
        );

        CREATE INDEX IF NOT EXISTS idx_profession_recipes_profession
            ON profession_recipes (profession, listview_name, recipe_name);

        CREATE INDEX IF NOT EXISTS idx_profession_recipes_output_item
            ON profession_recipes (output_item_id);

        CREATE TABLE IF NOT EXISTS recipe_reagents (
            spell_id INTEGER NOT NULL REFERENCES profession_recipes(spell_id) ON DELETE CASCADE,
            reagent_order INTEGER NOT NULL,
            reagent_item_id INTEGER NOT NULL REFERENCES recipe_items(item_id),
            quantity REAL NOT NULL,
            PRIMARY KEY (spell_id, reagent_order)
        );

        CREATE INDEX IF NOT EXISTS idx_recipe_reagents_item
            ON recipe_reagents (reagent_item_id);

        CREATE TABLE IF NOT EXISTS favorite_recipes (
            spell_id INTEGER PRIMARY KEY,
            created_at TEXT NOT NULL,
            seeded INTEGER NOT NULL DEFAULT 0
        );

        CREATE TABLE IF NOT EXISTS auction_catalog (
            item_id INTEGER PRIMARY KEY,
            item_name TEXT NOT NULL,
            source TEXT NOT NULL,
            updated_at TEXT NOT NULL
        );

        CREATE INDEX IF NOT EXISTS idx_auction_catalog_name
            ON auction_catalog (item_name COLLATE NOCASE);

        CREATE TABLE IF NOT EXISTS auction_realms (
            connected_realm_id INTEGER PRIMARY KEY,
            region TEXT NOT NULL,
            name TEXT NOT NULL,
            slug TEXT NOT NULL,
            realm_names_json TEXT NOT NULL,
            population TEXT,
            updated_at TEXT NOT NULL
        );

        CREATE INDEX IF NOT EXISTS idx_auction_realms_region
            ON auction_realms (region, name);

        CREATE TABLE IF NOT EXISTS auction_items (
            variant_key TEXT PRIMARY KEY,
            item_id INTEGER NOT NULL,
            item_level INTEGER NOT NULL DEFAULT 0,
            item_suffix INTEGER NOT NULL DEFAULT 0,
            item_name TEXT NOT NULL,
            icon_url TEXT,
            is_commodity INTEGER NOT NULL DEFAULT 0,
            last_seen_at TEXT NOT NULL,
            UNIQUE (item_id, item_level, item_suffix, is_commodity)
        );

        CREATE INDEX IF NOT EXISTS idx_auction_items_item
            ON auction_items (item_id, item_level, item_suffix);

        CREATE INDEX IF NOT EXISTS idx_auction_items_name
            ON auction_items (item_name COLLATE NOCASE);

        CREATE TABLE IF NOT EXISTS auction_snapshots (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            region TEXT NOT NULL,
            connected_realm_id INTEGER NOT NULL DEFAULT 0,
            fetched_at TEXT NOT NULL,
            api_last_modified TEXT,
            source TEXT NOT NULL,
            auction_count INTEGER NOT NULL DEFAULT 0,
            status TEXT NOT NULL DEFAULT 'ok',
            error TEXT
        );

        CREATE INDEX IF NOT EXISTS idx_auction_snapshots_latest
            ON auction_snapshots (region, connected_realm_id, fetched_at DESC);

        CREATE TABLE IF NOT EXISTS auction_prices (
            snapshot_id INTEGER NOT NULL REFERENCES auction_snapshots(id) ON DELETE CASCADE,
            variant_key TEXT NOT NULL REFERENCES auction_items(variant_key),
            min_unit_price_copper INTEGER,
            available_quantity INTEGER NOT NULL DEFAULT 0,
            listing_count INTEGER NOT NULL DEFAULT 0,
            PRIMARY KEY (snapshot_id, variant_key)
        );

        CREATE INDEX IF NOT EXISTS idx_auction_prices_variant
            ON auction_prices (variant_key, snapshot_id);
        """
    )
    auction_item_columns = {
        row[1] for row in conn.execute("PRAGMA table_info(auction_items)").fetchall()
    }
    if "icon_url" not in auction_item_columns:
        conn.execute("ALTER TABLE auction_items ADD COLUMN icon_url TEXT")
    conn.commit()


def upsert_item(conn: sqlite3.Connection, item: dict[str, Any]) -> None:
    conn.execute(
        """
        INSERT INTO items (
            item_id,
            profession,
            expansion_seed,
            expansion_detected,
            category,
            family_name,
            item_name,
            wowhead_url,
            icon_url,
            description,
            item_level,
            req_level,
            wowhead_quality,
            wowhead_popularity,
            source_kind,
            is_gatherable,
            metadata_json,
            last_catalog_sync
        ) VALUES (
            :item_id,
            :profession,
            :expansion_seed,
            :expansion_detected,
            :category,
            :family_name,
            :item_name,
            :wowhead_url,
            :icon_url,
            :description,
            :item_level,
            :req_level,
            :wowhead_quality,
            :wowhead_popularity,
            :source_kind,
            :is_gatherable,
            :metadata_json,
            :last_catalog_sync
        )
        ON CONFLICT(item_id) DO UPDATE SET
            profession = excluded.profession,
            expansion_seed = excluded.expansion_seed,
            expansion_detected = excluded.expansion_detected,
            category = excluded.category,
            family_name = excluded.family_name,
            item_name = excluded.item_name,
            wowhead_url = excluded.wowhead_url,
            icon_url = excluded.icon_url,
            description = excluded.description,
            item_level = excluded.item_level,
            req_level = excluded.req_level,
            wowhead_quality = excluded.wowhead_quality,
            wowhead_popularity = excluded.wowhead_popularity,
            source_kind = excluded.source_kind,
            is_gatherable = excluded.is_gatherable,
            metadata_json = excluded.metadata_json,
            last_catalog_sync = excluded.last_catalog_sync
        """,
        item,
    )


def insert_price_snapshot(conn: sqlite3.Connection, snapshot: dict[str, Any]) -> None:
    payload = dict(snapshot)
    raw_payload_json = payload.pop("raw_payload_json", None)
    if raw_payload_json is not None and not isinstance(raw_payload_json, str):
        payload["raw_payload_json"] = json.dumps(raw_payload_json, sort_keys=True)
    else:
        payload["raw_payload_json"] = raw_payload_json

    conn.execute(
        """
        INSERT INTO price_snapshots (
            item_id,
            region,
            source,
            fetched_at,
            updated_at,
            available_quantity,
            min_buyout_copper,
            market_value_copper,
            historical_price_copper,
            region_market_value_avg_copper,
            region_historical_price_copper,
            region_sale_avg_copper,
            region_sale_rate,
            region_avg_daily_sold,
            raw_payload_json
        ) VALUES (
            :item_id,
            :region,
            :source,
            :fetched_at,
            :updated_at,
            :available_quantity,
            :min_buyout_copper,
            :market_value_copper,
            :historical_price_copper,
            :region_market_value_avg_copper,
            :region_historical_price_copper,
            :region_sale_avg_copper,
            :region_sale_rate,
            :region_avg_daily_sold,
            :raw_payload_json
        )
        """,
        payload,
    )


def upsert_recipe_item(conn: sqlite3.Connection, item: dict[str, Any]) -> None:
    payload = dict(item)
    raw_payload_json = payload.get("raw_payload_json")
    if raw_payload_json is not None and not isinstance(raw_payload_json, str):
        payload["raw_payload_json"] = json.dumps(raw_payload_json, sort_keys=True)

    conn.execute(
        """
        INSERT INTO recipe_items (
            item_id,
            item_name,
            icon,
            quality,
            raw_payload_json,
            source_url,
            last_sync
        ) VALUES (
            :item_id,
            :item_name,
            :icon,
            :quality,
            :raw_payload_json,
            :source_url,
            :last_sync
        )
        ON CONFLICT(item_id) DO UPDATE SET
            item_name = excluded.item_name,
            icon = excluded.icon,
            quality = excluded.quality,
            raw_payload_json = excluded.raw_payload_json,
            source_url = excluded.source_url,
            last_sync = excluded.last_sync
        """,
        payload,
    )


def upsert_profession_recipe(conn: sqlite3.Connection, recipe: dict[str, Any]) -> None:
    payload = dict(recipe)
    raw_payload_json = payload.get("raw_payload_json")
    if raw_payload_json is not None and not isinstance(raw_payload_json, str):
        payload["raw_payload_json"] = json.dumps(raw_payload_json, sort_keys=True)

    conn.execute(
        """
        INSERT INTO profession_recipes (
            spell_id,
            profession,
            skill_line_id,
            listview_id,
            listview_name,
            recipe_name,
            output_item_id,
            output_min_quantity,
            output_max_quantity,
            learned_at,
            category_id,
            has_optional_reagents,
            raw_payload_json,
            source_url,
            last_sync
        ) VALUES (
            :spell_id,
            :profession,
            :skill_line_id,
            :listview_id,
            :listview_name,
            :recipe_name,
            :output_item_id,
            :output_min_quantity,
            :output_max_quantity,
            :learned_at,
            :category_id,
            :has_optional_reagents,
            :raw_payload_json,
            :source_url,
            :last_sync
        )
        ON CONFLICT(spell_id) DO UPDATE SET
            profession = excluded.profession,
            skill_line_id = excluded.skill_line_id,
            listview_id = excluded.listview_id,
            listview_name = excluded.listview_name,
            recipe_name = excluded.recipe_name,
            output_item_id = excluded.output_item_id,
            output_min_quantity = excluded.output_min_quantity,
            output_max_quantity = excluded.output_max_quantity,
            learned_at = excluded.learned_at,
            category_id = excluded.category_id,
            has_optional_reagents = excluded.has_optional_reagents,
            raw_payload_json = excluded.raw_payload_json,
            source_url = excluded.source_url,
            last_sync = excluded.last_sync
        """,
        payload,
    )


def replace_recipe_reagents(conn: sqlite3.Connection, spell_id: int, reagents: list[dict[str, Any]]) -> None:
    conn.execute("DELETE FROM recipe_reagents WHERE spell_id = ?", (spell_id,))
    if not reagents:
        return
    conn.executemany(
        """
        INSERT INTO recipe_reagents (
            spell_id,
            reagent_order,
            reagent_item_id,
            quantity
        ) VALUES (
            :spell_id,
            :reagent_order,
            :reagent_item_id,
            :quantity
        )
        """,
        reagents,
    )


def delete_profession_recipes(conn: sqlite3.Connection, profession: str) -> None:
    conn.execute("DELETE FROM profession_recipes WHERE profession = ?", (profession,))


def latest_prices(conn: sqlite3.Connection, region: str) -> list[sqlite3.Row]:
    return list(
        conn.execute(
            """
            SELECT
                i.*,
                ps.region,
                ps.source,
                ps.fetched_at,
                ps.updated_at,
                ps.available_quantity,
                ps.min_buyout_copper,
                ps.market_value_copper,
                ps.historical_price_copper,
                ps.region_market_value_avg_copper,
                ps.region_historical_price_copper,
                ps.region_sale_avg_copper,
                ps.region_sale_rate,
                ps.region_avg_daily_sold
            FROM items i
            JOIN (
                SELECT p1.*
                FROM price_snapshots p1
                JOIN (
                    SELECT item_id, region, MAX(fetched_at) AS max_fetched_at
                    FROM price_snapshots
                    WHERE region = ?
                    GROUP BY item_id, region
                ) latest
                    ON latest.item_id = p1.item_id
                    AND latest.region = p1.region
                    AND latest.max_fetched_at = p1.fetched_at
            ) ps
                ON ps.item_id = i.item_id
            WHERE ps.region = ?
            ORDER BY i.expansion_seed, i.family_name, i.item_id
            """,
            (region, region),
        )
    )
