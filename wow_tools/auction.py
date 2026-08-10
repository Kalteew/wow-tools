from __future__ import annotations

import csv
import io
import json
import math
import re
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime, timezone
from typing import Any, Iterable

from wow_tools.cache import HttpCache
from wow_tools.config import (
    BLIZZARD_AUCTION_TTL_SECONDS,
    BLIZZARD_CATALOG_TTL_SECONDS,
)
from wow_tools.http import fetch_text
from wow_tools.sources.blizzard import BlizzardClient


TSM_REGION_CATALOG_URL = "https://public-data.tradeskillmaster.com/retail/{region}/region/items.csv"
SHATARI_ITEMS_URL = "https://raw.githubusercontent.com/erorus/shatari/master/items.all.json"
SHATARI_BONUSES_URL = "https://raw.githubusercontent.com/erorus/shatari/master/bonuses.json"


def _now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def _as_number(value: Any, default: float = 0.0) -> float:
    try:
        return float(value)
    except (TypeError, ValueError):
        return default


def _mapping_value(mapping: Any, key: int) -> Any:
    if not isinstance(mapping, dict):
        return None
    return mapping.get(str(key), mapping.get(key))


class ItemVariantDecoder:
    """Decode Blizzard auction bonus lists into stable item variants.

    The algorithm follows the public Shatari item-key implementation. The
    large static files are downloaded into the normal local HTTP cache only
    when the first AH synchronization needs them.
    """

    EQUIPMENT_CLASSES = {2, 4, 19}
    BATTLE_PET_CLASS = 17
    TIMEWALKER_LEVEL_MODIFIER = 9
    PLAYER_LEVEL_CAP = 90

    def __init__(self, item_data: dict[str, Any], bonus_data: dict[str, Any]) -> None:
        self.item_data = item_data
        self.bonus_data = bonus_data

    @classmethod
    def from_cache(cls, cache: HttpCache, *, force: bool = False) -> "ItemVariantDecoder":
        items = json.loads(
            fetch_text(
                SHATARI_ITEMS_URL,
                cache,
                BLIZZARD_AUCTION_TTL_SECONDS * 24,
                force=force,
            )
        )
        bonuses = json.loads(
            fetch_text(
                SHATARI_BONUSES_URL,
                cache,
                BLIZZARD_AUCTION_TTL_SECONDS * 24,
                force=force,
            )
        )
        return cls(items, bonuses)

    def _item(self, item_id: int) -> dict[str, Any]:
        item = _mapping_value(self.item_data, item_id)
        return item if isinstance(item, dict) else {}

    def icon_url(self, item_id: int) -> str | None:
        icon = str(self._item(item_id).get("icon") or "").strip()
        if not icon:
            return None
        return f"https://wow.zamimg.com/images/wow/icons/large/{icon}.jpg"

    def _bonus(self, category: str, bonus_id: int) -> Any:
        return _mapping_value(self.bonus_data.get("levelData", {}).get(category), bonus_id)

    def _curve_point(self, curve_id: Any, x: float) -> float:
        curve = curve_id
        if isinstance(curve_id, (int, str)):
            curve = _mapping_value(self.bonus_data.get("curvePoints"), int(curve_id))
        if not isinstance(curve, list) or not curve:
            return 0.0
        points = [(_as_number(point[0]), _as_number(point[1])) for point in curve if isinstance(point, list) and len(point) >= 2]
        if not points:
            return 0.0
        if x <= points[0][0]:
            return points[0][1]
        for index in range(1, len(points)):
            if x < points[index][0]:
                previous_x, previous_y = points[index - 1]
                next_x, next_y = points[index]
                pct = (x - previous_x) / (next_x - previous_x)
                return previous_y + pct * (next_y - previous_y)
        return points[-1][1]

    def decode(self, auction_item: dict[str, Any]) -> tuple[int, int]:
        item_id = int(auction_item.get("id") or 0)
        item = self._item(item_id)
        item_class = int(_as_number(item.get("class")))
        item_level = 0
        item_suffix = 0

        if item_class == self.BATTLE_PET_CLASS:
            species = int(_as_number(auction_item.get("pet_species_id")))
            breed = int(_as_number(auction_item.get("pet_breed_id"), 3))
            return species, (((breed - 3) % 10) + 3)

        if item_class not in self.EQUIPMENT_CLASSES:
            return item_level, item_suffix

        item_level = int(_as_number(item.get("itemLevel")))
        era = int(_as_number(item.get("squishEra")))
        era_adjust: dict[int, float] = {}
        bonuses = [int(_as_number(value)) for value in auction_item.get("bonus_lists") or []]

        player_level = self.PLAYER_LEVEL_CAP
        for modifier in auction_item.get("modifiers") or []:
            if int(_as_number(modifier.get("type"))) == self.TIMEWALKER_LEVEL_MODIFIER:
                player_level = _as_number(modifier.get("value"), player_level)

        def highest(category: str) -> list[Any]:
            rows = [self._bonus(category, bonus) for bonus in bonuses]
            return sorted((row for row in rows if row), key=lambda row: _as_number(row[0]), reverse=True)

        for row in highest("legacySet"):
            item_level = int(_as_number(row[1]))
            break
        for row in highest("contentTuning"):
            curve = row[1] if len(row) > 1 else None
            maximum = _as_number(row[2], player_level) if len(row) > 2 and row[2] else player_level
            item_level = round(self._curve_point(curve, min(player_level, maximum)))
            break
        for bonus in bonuses:
            amount = self._bonus("legacyAdjust", bonus)
            if amount:
                item_level += int(_as_number(amount))
        for row in highest("itemScalingSet"):
            level = _as_number(row[1]) if len(row) > 1 else item_level
            curve = row[2] if len(row) > 2 else None
            offset = _as_number(row[3]) if len(row) > 3 else 0
            item_level = round(self._curve_point(curve, level) if curve else level) + int(offset)
            era = int(_as_number(row[4])) if len(row) > 4 else era
            break
        for row in self._bonus_rows("eraCurveSet", bonuses):
            curve = row[0] if len(row) > 0 else None
            level = _as_number(row[1]) if len(row) > 1 and row[1] else item_level
            item_level = round(self._curve_point(curve, level))
            era = int(_as_number(row[2])) if len(row) > 2 else era
        for row in highest("itemScalingSetByPlayer"):
            level = _as_number(row[1]) if len(row) > 1 and row[1] else player_level
            curve = row[2] if len(row) > 2 else None
            offset = _as_number(row[3]) if len(row) > 3 else 0
            item_level = round(self._curve_point(curve, level) if curve else level) + int(offset)
            era = int(_as_number(row[4])) if len(row) > 4 else era
            break
        for row in self._bonus_rows("eraAdjust", bonuses):
            amount = _as_number(row[0]) if len(row) > 0 else 0
            fallback = _as_number(row[1]) if len(row) > 1 else amount
            check_era = int(_as_number(row[2])) if len(row) > 2 else era
            if check_era > era:
                era_adjust[check_era] = era_adjust.get(check_era, 0) + amount
                if era == 0:
                    era_adjust[2] = era_adjust.get(2, 0) + 4
            else:
                item_level += int(fallback if check_era < era else amount)
        for row in highest("adjust"):
            item_level += int(_as_number(row[1])) if len(row) > 1 else 0
            break

        for era_data in self.bonus_data.get("squishEras") or []:
            era_id = int(_as_number(era_data.get("id")))
            curve = era_data.get("curve")
            if era_id > era and curve:
                item_level = round(self._curve_point(curve, item_level))
            item_level += int(era_adjust.get(era_id, 0))
            if era_data.get("target"):
                break

        names = self.bonus_data.get("names") or {}
        suffix_rows = [
            _mapping_value(names, bonus)
            for bonus in bonuses
        ]
        suffix_rows = [row for row in suffix_rows if isinstance(row, list) and len(row) >= 2]
        if suffix_rows:
            suffix_rows.sort(key=lambda row: _as_number(row[0]), reverse=True)
            item_suffix = int(_as_number(suffix_rows[0][1]))
        return max(1, int(item_level)), item_suffix

    def _bonus_rows(self, category: str, bonuses: Iterable[int]) -> list[Any]:
        return [row for row in (self._bonus(category, bonus) for bonus in bonuses) if row]


def _variant_key(item_id: int, item_level: int, item_suffix: int, is_commodity: bool) -> str:
    return f"{item_id}:{item_level}:{item_suffix}:{1 if is_commodity else 0}"


def _display_variant_name(item_name: str, item_level: int, item_suffix: int) -> str:
    if item_level:
        return f"{item_name} ({item_level})"
    if item_suffix:
        return f"{item_name} (variante {item_suffix})"
    return item_name


def aggregate_auctions(
    auctions: Iterable[dict[str, Any]],
    decoder: ItemVariantDecoder,
    catalog: dict[int, str],
    *,
    is_commodity: bool = False,
) -> dict[str, dict[str, Any]]:
    """Collapse Blizzard listings into one row per item variant."""
    grouped: dict[str, dict[str, Any]] = {}
    for auction in auctions:
        item = auction.get("item") or {}
        item_id = int(_as_number(item.get("id")))
        if not item_id:
            continue
        item_level, item_suffix = decoder.decode(item)
        quantity = max(1, int(_as_number(auction.get("quantity"), 1)))
        if is_commodity:
            unit_price = int(_as_number(auction.get("unit_price")))
        else:
            buyout = int(_as_number(auction.get("buyout")))
            unit_price = math.ceil(buyout / quantity) if buyout > 0 else 0
        if unit_price <= 0:
            continue
        key = _variant_key(item_id, item_level, item_suffix, is_commodity)
        row = grouped.setdefault(
            key,
            {
                "variant_key": key,
                "item_id": item_id,
                "item_level": item_level,
                "item_suffix": item_suffix,
                "item_name": catalog.get(item_id) or f"Item {item_id}",
                "icon_url": decoder.icon_url(item_id),
                "is_commodity": int(is_commodity),
                "min_unit_price_copper": unit_price,
                "available_quantity": 0,
                "listing_count": 0,
            },
        )
        row["min_unit_price_copper"] = min(row["min_unit_price_copper"], unit_price)
        row["available_quantity"] += quantity
        row["listing_count"] += 1
    return grouped


def sync_auction_catalog(
    conn,
    cache: HttpCache,
    region: str = "eu",
    *,
    force: bool = False,
) -> dict[str, Any]:
    url = TSM_REGION_CATALOG_URL.format(region=region.lower())
    text = fetch_text(url, cache, BLIZZARD_CATALOG_TTL_SECONDS, force=force)
    reader = csv.DictReader(io.StringIO(text))
    rows = 0
    now = _now_iso()
    for record in reader:
        raw_item_id = record.get("itemId") or record.get("item_id")
        item_name = (record.get("name") or "").strip()
        if not raw_item_id or not item_name:
            continue
        try:
            item_id = int(raw_item_id)
        except ValueError:
            continue
        conn.execute(
            """
            INSERT INTO auction_catalog (item_id, item_name, source, updated_at)
            VALUES (?, ?, ?, ?)
            ON CONFLICT(item_id) DO UPDATE SET
                item_name = excluded.item_name,
                source = excluded.source,
                updated_at = excluded.updated_at
            """,
            (item_id, item_name, "tsm-public-catalog", now),
        )
        rows += 1
    conn.commit()
    return {"region": region.lower(), "items": rows, "updated_at": now, "source": url}


def sync_auction_realms(conn, client: BlizzardClient, region: str = "eu") -> dict[str, Any]:
    realms = client.connected_realms(region)
    now = _now_iso()
    for realm in realms:
        conn.execute(
            """
            INSERT INTO auction_realms (
                connected_realm_id, region, name, slug, realm_names_json, population, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(connected_realm_id) DO UPDATE SET
                region = excluded.region,
                name = excluded.name,
                slug = excluded.slug,
                realm_names_json = excluded.realm_names_json,
                updated_at = excluded.updated_at
            """,
            (
                realm["connected_realm_id"],
                realm["region"],
                realm["name"],
                realm["slug"],
                json.dumps(realm.get("realm_names") or [], ensure_ascii=False),
                realm.get("population"),
                now,
            ),
        )
    conn.commit()
    return {"region": region.lower(), "realms": len(realms), "updated_at": now}


def _catalog_map(conn) -> dict[int, str]:
    rows = conn.execute("SELECT item_id, item_name FROM auction_catalog").fetchall()
    catalog = {int(row["item_id"]): str(row["item_name"]) for row in rows}
    for table in ("recipe_items", "items"):
        rows = conn.execute(f"SELECT item_id, item_name FROM {table}").fetchall()
        for row in rows:
            catalog.setdefault(int(row["item_id"]), str(row["item_name"]))
    return catalog


def _save_snapshot(conn, *, region: str, connected_realm_id: int, source: str, aggregated: dict[str, dict[str, Any]], api_last_modified: str | None, auction_count: int, status: str = "ok", error: str | None = None) -> None:
    fetched_at = _now_iso()
    cursor = conn.execute(
        """
        INSERT INTO auction_snapshots (
            region, connected_realm_id, fetched_at, api_last_modified,
            source, auction_count, status, error
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        """,
        (region, connected_realm_id, fetched_at, api_last_modified, source, auction_count, status, error),
    )
    snapshot_id = cursor.lastrowid
    for row in aggregated.values():
        conn.execute(
            """
            INSERT INTO auction_items (
                variant_key, item_id, item_level, item_suffix, item_name, icon_url,
                is_commodity, last_seen_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(variant_key) DO UPDATE SET
                item_name = excluded.item_name,
                icon_url = COALESCE(excluded.icon_url, auction_items.icon_url),
                last_seen_at = excluded.last_seen_at
            """,
            (
                row["variant_key"], row["item_id"], row["item_level"], row["item_suffix"],
                row["item_name"], row.get("icon_url"), row["is_commodity"], fetched_at,
            ),
        )
        conn.execute(
            """
            INSERT INTO auction_prices (
                snapshot_id, variant_key, min_unit_price_copper,
                available_quantity, listing_count
            ) VALUES (?, ?, ?, ?, ?)
            """,
            (
                snapshot_id,
                row["variant_key"],
                row["min_unit_price_copper"],
                row["available_quantity"],
                row["listing_count"],
            ),
        )
    conn.commit()


def _sync_one_realm(realm: dict[str, Any], region: str, decoder: ItemVariantDecoder, catalog: dict[int, str]) -> dict[str, Any]:
    client = BlizzardClient()
    try:
        response = client.auctions(int(realm["connected_realm_id"]), region)
        auctions = response.payload.get("auctions") or []
        grouped = aggregate_auctions(auctions, decoder, catalog)
        return {
            "realm": realm,
            "aggregated": grouped,
            "auction_count": len(auctions),
            "api_last_modified": response.headers.get("last-modified"),
            "error": None,
        }
    except Exception as exc:  # Keep a partial EU sync useful.
        return {"realm": realm, "aggregated": {}, "auction_count": 0, "api_last_modified": None, "error": str(exc)}


def sync_auction_data(
    conn,
    cache: HttpCache,
    region: str = "eu",
    *,
    force: bool = False,
    realm_slugs: list[str] | None = None,
    limit_realms: int | None = None,
    include_commodities: bool = True,
    workers: int = 4,
) -> dict[str, Any]:
    region = region.lower()
    if not conn.execute("SELECT 1 FROM auction_catalog LIMIT 1").fetchone():
        sync_auction_catalog(conn, cache, region, force=force)
    if not conn.execute("SELECT 1 FROM auction_realms WHERE region = ? LIMIT 1", (region,)).fetchone():
        sync_auction_realms(conn, BlizzardClient(), region)

    decoder = ItemVariantDecoder.from_cache(cache, force=force)
    hydrate_auction_icons(conn, decoder)
    catalog = _catalog_map(conn)
    realms = [dict(row) for row in conn.execute("SELECT * FROM auction_realms WHERE region = ? ORDER BY name", (region,))]
    requested = {value.casefold() for value in (realm_slugs or [])}
    if requested:
        realms = [
            realm for realm in realms
            if str(realm["slug"]).casefold() in requested
            or str(realm["name"]).casefold() in requested
            or any(str(name).casefold() in requested for name in json.loads(realm["realm_names_json"] or "[]"))
        ]
    if limit_realms is not None:
        realms = realms[: max(0, limit_realms)]

    synced = 0
    failures: list[dict[str, Any]] = []
    with ThreadPoolExecutor(max_workers=max(1, workers)) as pool:
        futures = [pool.submit(_sync_one_realm, realm, region, decoder, catalog) for realm in realms]
        for index, future in enumerate(as_completed(futures), start=1):
            result = future.result()
            realm = result["realm"]
            _save_snapshot(
                conn,
                region=region,
                connected_realm_id=int(realm["connected_realm_id"]),
                source="blizzard-auctions",
                aggregated=result["aggregated"],
                api_last_modified=result["api_last_modified"],
                auction_count=result["auction_count"],
                status="error" if result["error"] else "ok",
                error=result["error"],
            )
            if result["error"]:
                failures.append({"connected_realm_id": realm["connected_realm_id"], "name": realm["name"], "error": result["error"]})
            else:
                synced += 1
            print(f"[sync-auction-data] {index}/{len(realms)} realms | ok={synced} failed={len(failures)}")

    commodities = 0
    if include_commodities:
        try:
            response = BlizzardClient().commodities(region)
            auctions = response.payload.get("auctions") or []
            grouped = aggregate_auctions(auctions, decoder, catalog, is_commodity=True)
            _save_snapshot(
                conn,
                region=region,
                connected_realm_id=0,
                source="blizzard-commodities",
                aggregated=grouped,
                api_last_modified=response.headers.get("last-modified"),
                auction_count=len(auctions),
            )
            commodities = 1
        except Exception as exc:
            failures.append({"connected_realm_id": 0, "name": "EU commodities", "error": str(exc)})
    return {"region": region, "realms": len(realms), "synced": synced, "commodities": commodities, "failed": failures}


def hydrate_auction_icons(conn, decoder: ItemVariantDecoder) -> int:
    """Backfill icon URLs for snapshots created before icon support existed."""
    rows = conn.execute(
        "SELECT variant_key, item_id FROM auction_items WHERE icon_url IS NULL"
    ).fetchall()
    updated = 0
    for row in rows:
        icon_url = decoder.icon_url(int(row["item_id"]))
        if not icon_url:
            continue
        conn.execute(
            "UPDATE auction_items SET icon_url = ? WHERE variant_key = ?",
            (icon_url, row["variant_key"]),
        )
        updated += 1
    if updated:
        conn.commit()
    return updated


def search_auction_items(
    conn,
    query: str,
    *,
    limit: int = 50,
    prefix_only: bool = False,
) -> list[dict[str, Any]]:
    query = query.strip()
    if not query:
        return []
    pattern = f"{query}%" if prefix_only else f"%{query}%"
    order_prefix = f"{query}%"
    rows = conn.execute(
        """
        SELECT item_id, item_name
        FROM auction_catalog
        WHERE item_name LIKE ? COLLATE NOCASE
        ORDER BY CASE WHEN lower(item_name) = lower(?) THEN 0 ELSE 1 END,
                 CASE WHEN lower(item_name) LIKE lower(?) THEN 0 ELSE 1 END,
                 item_name COLLATE NOCASE
        LIMIT ?
        """,
        (pattern, query, order_prefix, limit),
    ).fetchall()
    if not rows:
        rows = conn.execute(
            """
            SELECT item_id, item_name
            FROM (
                SELECT item_id, item_name FROM auction_items
                WHERE item_name LIKE ? COLLATE NOCASE
                UNION
                SELECT item_id, item_name FROM recipe_items
                WHERE item_name LIKE ? COLLATE NOCASE
                UNION
                SELECT item_id, item_name FROM items
                WHERE item_name LIKE ? COLLATE NOCASE
            ) candidates
            ORDER BY CASE WHEN lower(item_name) = lower(?) THEN 0 ELSE 1 END,
                     CASE WHEN lower(item_name) LIKE lower(?) THEN 0 ELSE 1 END,
                     item_name COLLATE NOCASE
            LIMIT ?
            """,
            (pattern, pattern, pattern, query, order_prefix, limit),
        ).fetchall()
    return [{"item_id": int(row["item_id"]), "item_name": str(row["item_name"])} for row in rows]


def suggest_auction_items(conn, query: str, *, limit: int = 50) -> list[dict[str, Any]]:
    """Return fast local suggestions from the full item catalog and AH variants."""
    query = query.strip()
    if not query:
        return []
    pattern = f"%{query}%"
    prefix = f"{query}%"
    base_rows = conn.execute(
        """
        SELECT MIN(item_id) AS item_id, item_name
        FROM (
            SELECT item_id, item_name FROM auction_catalog
            WHERE item_name LIKE ? COLLATE NOCASE
            UNION
            SELECT item_id, item_name FROM recipe_items
            WHERE item_name LIKE ? COLLATE NOCASE
            UNION
            SELECT item_id, item_name FROM items
            WHERE item_name LIKE ? COLLATE NOCASE
        ) candidates
        GROUP BY item_name
        ORDER BY CASE WHEN lower(item_name) = lower(?) THEN 0 ELSE 1 END,
                 CASE WHEN lower(item_name) LIKE lower(?) THEN 0 ELSE 1 END,
                 length(item_name),
                 item_name COLLATE NOCASE
        LIMIT ?
        """,
        (pattern, pattern, pattern, query, prefix, max(limit * 4, 32)),
    ).fetchall()

    # Keep locally observed objects searchable even if an older catalog snapshot
    # does not contain them.
    if not base_rows:
        base_rows = conn.execute(
            """
            SELECT MIN(item_id) AS item_id, item_name
            FROM auction_items
            WHERE item_name LIKE ? COLLATE NOCASE
            GROUP BY item_name
            ORDER BY CASE WHEN lower(item_name) = lower(?) THEN 0 ELSE 1 END,
                     CASE WHEN lower(item_name) LIKE lower(?) THEN 0 ELSE 1 END,
                     length(item_name),
                     item_name COLLATE NOCASE
            LIMIT ?
            """,
            (pattern, query, prefix, max(limit * 4, 32)),
        ).fetchall()

    if not base_rows:
        return []

    names = [str(row["item_name"]) for row in base_rows]
    name_placeholders = ",".join("?" for _ in names)
    variant_rows = conn.execute(
        f"""
        SELECT variant_key, item_id, item_name, item_level, item_suffix
        FROM auction_items
        WHERE item_name IN ({name_placeholders})
        ORDER BY item_name COLLATE NOCASE, item_level, item_suffix
        """,
        names,
    ).fetchall()
    variants_by_name: dict[str, list[Any]] = {}
    for row in variant_rows:
        variants_by_name.setdefault(str(row["item_name"]).casefold(), []).append(row)

    suggestions: list[dict[str, Any]] = []
    expand_variants = len(base_rows) == 1 or any(
        str(row["item_name"]).casefold() == query.casefold() for row in base_rows
    )
    for row in base_rows:
        item_name = str(row["item_name"])
        variants = variants_by_name.get(item_name.casefold(), [])
        if expand_variants and variants:
            for variant in variants:
                suggestions.append(
                    {
                        "item_id": int(variant["item_id"]),
                        "item_name": item_name,
                        "display_name": _display_variant_name(
                            item_name, int(variant["item_level"]), int(variant["item_suffix"])
                        ),
                        "search_name": item_name,
                        "variant_key": str(variant["variant_key"]),
                    }
                )
                if len(suggestions) >= limit:
                    return suggestions
            continue
        suggestions.append(
            {
                "item_id": int(row["item_id"]),
                "item_name": item_name,
                "display_name": item_name,
                "search_name": item_name,
                "variant_key": None,
            }
        )
        if len(suggestions) >= limit:
            break
    return suggestions


def build_auction_report(
    conn,
    query: str,
    region: str = "eu",
    *,
    limit: int = 50,
    variant_key: str | None = None,
) -> dict[str, Any]:
    matches = search_auction_items(conn, query, limit=limit)
    item_ids = [row["item_id"] for row in matches]
    if not item_ids:
        return {"query": query, "region": region, "matches": [], "variants": [], "realm_count": 0}

    placeholders = ",".join("?" for _ in item_ids)
    variant_sql = (
        f"SELECT * FROM auction_items WHERE item_id IN ({placeholders})"
        + (" AND variant_key = ?" if variant_key else "")
        + " ORDER BY is_commodity, item_level, item_suffix"
    )
    variant_params = item_ids + ([variant_key] if variant_key else [])
    variants = [dict(row) for row in conn.execute(variant_sql, variant_params)]
    realms = [dict(row) for row in conn.execute("SELECT * FROM auction_realms WHERE region = ? ORDER BY name", (region,))]
    latest_rows = conn.execute(
        """
        SELECT s.*
        FROM auction_snapshots s
        JOIN (
            SELECT connected_realm_id, MAX(fetched_at) AS fetched_at
            FROM auction_snapshots
            WHERE region = ? AND status = 'ok'
            GROUP BY connected_realm_id
        ) latest
            ON latest.connected_realm_id = s.connected_realm_id
            AND latest.fetched_at = s.fetched_at
        WHERE s.region = ? AND s.status = 'ok'
        """,
        (region, region),
    ).fetchall()
    latest = {int(row["connected_realm_id"]): dict(row) for row in latest_rows}
    snapshot_ids = [row["id"] for row in latest_rows]
    price_map: dict[tuple[int, str], dict[str, Any]] = {}
    if snapshot_ids and variants:
        snapshot_placeholders = ",".join("?" for _ in snapshot_ids)
        item_placeholders = ",".join("?" for _ in item_ids)
        variant_filter = " AND ai.variant_key = ?" if variant_key else ""
        price_params: list[Any] = snapshot_ids + item_ids + ([variant_key] if variant_key else [])
        price_rows = conn.execute(
            f"""
            SELECT p.*
            FROM auction_prices p
            JOIN auction_items ai ON ai.variant_key = p.variant_key
            WHERE p.snapshot_id IN ({snapshot_placeholders})
              AND ai.item_id IN ({item_placeholders})
              {variant_filter}
            """,
            price_params,
        ).fetchall()
        for row in price_rows:
            price_map[(int(row["snapshot_id"]), str(row["variant_key"]))] = dict(row)

    report_variants: list[dict[str, Any]] = []
    for variant in variants:
        item_name = variant["item_name"]
        variant_report = {
            "variant_key": variant["variant_key"],
            "item_id": variant["item_id"],
            "item_name": item_name,
            "label": _display_variant_name(item_name, variant["item_level"], variant["item_suffix"]),
            "icon_url": variant.get("icon_url"),
            "item_level": variant["item_level"],
            "item_suffix": variant["item_suffix"],
            "is_commodity": bool(variant["is_commodity"]),
            "realm_rows": [],
        }
        realm_rows = [{"connected_realm_id": 0, "name": "EU commodities"}] if variant["is_commodity"] else realms
        for realm in realm_rows:
            connected_realm_id = int(realm["connected_realm_id"])
            snapshot = latest.get(connected_realm_id)
            price = price_map.get((int(snapshot["id"]), variant["variant_key"])) if snapshot else None
            variant_report["realm_rows"].append(
                {
                    "connected_realm_id": connected_realm_id,
                    "name": realm["name"],
                    "price_copper": price["min_unit_price_copper"] if price else None,
                    "available_quantity": price["available_quantity"] if price else 0,
                    "listing_count": price["listing_count"] if price else 0,
                    "fetched_at": snapshot["fetched_at"] if snapshot else None,
                    "has_listing": bool(price),
                }
            )
        report_variants.append(variant_report)

    return {
        "query": query,
        "region": region,
        "matches": matches,
        "variants": report_variants,
        "realm_count": len(realms),
        "latest_snapshot": max((row["fetched_at"] for row in latest.values()), default=None),
    }


def render_auction_report(report: dict[str, Any], *, max_rows: int = 100) -> str:
    lines = [f"Recherche AH EU: {report.get('query') or '-'}"]
    if not report.get("matches"):
        return "\n".join(lines + ["Aucun item trouvé. Lance d'abord sync-auction-catalog si nécessaire."])
    lines.append(f"Items: {len(report['matches'])} | groupes suivis: {report.get('realm_count', 0)}")
    rows = 0
    for variant in report.get("variants") or []:
        lines.append("")
        lines.append(str(variant["label"]))
        for realm in variant.get("realm_rows") or []:
            if rows >= max_rows:
                lines.append("... lignes supplémentaires masquées")
                return "\n".join(lines)
            price = format_copper(realm.get("price_copper"))
            lines.append(
                f"  {realm['name']}: {price} | qty={realm.get('available_quantity', 0)} | annonces={realm.get('listing_count', 0)}"
            )
            rows += 1
    return "\n".join(lines)


def format_copper(value: int | None) -> str:
    if value is None:
        return "-"
    gold, rest = divmod(int(value), 10_000)
    silver, copper = divmod(rest, 100)
    if gold:
        return f"{gold:,}g {silver:02d}s {copper:02d}c"
    if silver:
        return f"{silver}s {copper:02d}c"
    return f"{copper}c"
