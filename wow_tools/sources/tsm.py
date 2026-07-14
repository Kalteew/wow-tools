from __future__ import annotations

import json
import os
import re
from datetime import datetime, timezone
from typing import Any
import urllib.request

from wow_tools.cache import HttpCache
from wow_tools.config import TSM_ITEM_TTL_SECONDS
from wow_tools.http import fetch_text


UPDATED_AT_RE = re.compile(r'\\"updatedAt\\",\\"([^\\"]+)\\"')
TSM_AUTH_URL = "https://auth.tradeskillmaster.com/oauth2/token"
TSM_PRICING_API_BASE = "https://pricing-api.tradeskillmaster.com"
TSM_CLIENT_ID = "c260f00d-1071-409a-992f-dda2e5498536"
TSM_SCOPES = "app:realm-api app:pricing-api"
TSM_BROWSER_UA = (
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
    "AppleWebKit/537.36 (KHTML, like Gecko) "
    "Chrome/136.0.0.0 Safari/537.36"
)
TSM_REGION_ID_FALLBACKS = {
    "us": 1,
    "eu": 2,
    "kr": 3,
    "tw": 4,
}

_TOKEN_CACHE: dict[str, Any] = {
    "access_token": None,
}


def _now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def _region_id(region: str) -> int:
    override = os.environ.get("TSM_REGION_ID")
    if override:
        return int(override)
    region_id = TSM_REGION_ID_FALLBACKS.get(region.lower())
    if region_id is None:
        raise ValueError(
            f"No TSM region id mapping for {region!r}; set TSM_REGION_ID to override."
        )
    return region_id


def _get_api_key() -> str | None:
    return os.environ.get("TSM_API_KEY")


def _get_access_token(api_key: str) -> str:
    cached_token = _TOKEN_CACHE.get("access_token")
    if cached_token:
        return str(cached_token)

    body = json.dumps(
        {
            "client_id": TSM_CLIENT_ID,
            "grant_type": "api_token",
            "scope": TSM_SCOPES,
            "token": api_key,
        }
    ).encode("utf-8")
    request = urllib.request.Request(
        TSM_AUTH_URL,
        data=body,
        method="POST",
        headers={
            "Content-Type": "application/json",
            "Accept": "application/json",
            "User-Agent": TSM_BROWSER_UA,
        },
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        payload = json.loads(response.read().decode("utf-8"))
    access_token = payload["access_token"]
    _TOKEN_CACHE["access_token"] = access_token
    return access_token


def _fetch_item_price_via_api(item_id: int, region: str) -> dict[str, Any]:
    api_key = _get_api_key()
    if not api_key:
        raise RuntimeError("TSM_API_KEY is not configured")

    access_token = _get_access_token(api_key)
    region_id = _region_id(region)
    url = f"{TSM_PRICING_API_BASE}/region/{region_id}/item/{item_id}"
    request = urllib.request.Request(
        url,
        headers={
            "Authorization": f"Bearer {access_token}",
            "Accept": "application/json",
            "User-Agent": TSM_BROWSER_UA,
        },
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        payload = json.loads(response.read().decode("utf-8"))

    return {
        "item_id": item_id,
        "region": region,
        "source": "tsm-api",
        "fetched_at": _now_iso(),
        "updated_at": None,
        "available_quantity": payload.get("quantity"),
        "min_buyout_copper": None,
        "market_value_copper": payload.get("marketValue"),
        "historical_price_copper": payload.get("historical"),
        "region_market_value_avg_copper": payload.get("marketValue"),
        "region_historical_price_copper": payload.get("historical"),
        "region_sale_avg_copper": payload.get("avgSalePrice"),
        "region_sale_rate": payload.get("saleRate"),
        "region_avg_daily_sold": payload.get("soldPerDay"),
        "raw_payload_json": payload,
    }


def _label_block(html: str, label: str) -> str | None:
    pattern = re.compile(
        re.escape(f">{label}</div><div class=\"text-base box-border\">") + r"(.*?)</div></div>",
        re.S,
    )
    match = pattern.search(html)
    if match:
        return match.group(1)
    return None


def _parse_int_text(value: str | None) -> int | None:
    if value is None:
        return None
    cleaned = re.sub(r"[^\d]", "", value)
    if not cleaned:
        return None
    return int(cleaned)


def _parse_float_text(value: str | None) -> float | None:
    if value is None:
        return None
    cleaned = value.replace(",", "").strip()
    if not cleaned:
        return None
    try:
        return float(cleaned)
    except ValueError:
        return None


def _strip_tags(html: str) -> str:
    html = re.sub(r"<!--.*?-->", "", html, flags=re.S)
    html = re.sub(r"<[^>]+>", "", html)
    return html.strip()


def _parse_currency_copper(block_html: str | None) -> int | None:
    if block_html is None:
        return None

    gold_match = re.search(r">([\d,]+)<span class=\"text-gold\">g</span>", block_html)
    silver_match = re.search(r">([\d,]+)<span class=\"text-silver\">s</span>", block_html)
    copper_match = re.search(r">([\d,]+)<span class=\"text-copper\">c</span>", block_html)

    gold = int(gold_match.group(1).replace(",", "")) if gold_match else 0
    silver = int(silver_match.group(1).replace(",", "")) if silver_match else 0
    copper = int(copper_match.group(1).replace(",", "")) if copper_match else 0

    if not gold_match and not silver_match and not copper_match:
        return None
    return gold * 10_000 + silver * 100 + copper


def fetch_item_price(item_id: int, region: str, cache: HttpCache, *, force: bool = False) -> dict[str, Any]:
    api_key = _get_api_key()
    if api_key:
        return _fetch_item_price_via_api(item_id, region)

    url = f"https://tradeskillmaster.com/retail/{region}/items/{item_id}"
    html = fetch_text(url, cache, TSM_ITEM_TTL_SECONDS, force=force)

    available_quantity = _parse_int_text(_strip_tags(_label_block(html, "Available Quantity") or ""))
    min_buyout = _parse_currency_copper(_label_block(html, "Min Buyout"))
    market_value = _parse_currency_copper(_label_block(html, "Market Value"))
    historical_price = _parse_currency_copper(_label_block(html, "Historical Price"))
    region_market_value_avg = _parse_currency_copper(_label_block(html, "Region Market Value Avg"))
    region_historical_price = _parse_currency_copper(_label_block(html, "Region Historical Price"))
    region_sale_avg = _parse_currency_copper(_label_block(html, "Region Sale Avg"))
    region_sale_rate = _parse_float_text(_strip_tags(_label_block(html, "Region Sale Rate") or ""))
    region_avg_daily_sold = _parse_float_text(_strip_tags(_label_block(html, "Region Avg Daily Sold") or ""))

    updated_at_match = UPDATED_AT_RE.search(html)
    updated_at = updated_at_match.group(1) if updated_at_match else None

    return {
        "item_id": item_id,
        "region": region,
        "source": "tsm-public-html",
        "fetched_at": _now_iso(),
        "updated_at": updated_at,
        "available_quantity": available_quantity,
        "min_buyout_copper": min_buyout,
        "market_value_copper": market_value,
        "historical_price_copper": historical_price,
        "region_market_value_avg_copper": region_market_value_avg,
        "region_historical_price_copper": region_historical_price,
        "region_sale_avg_copper": region_sale_avg,
        "region_sale_rate": region_sale_rate,
        "region_avg_daily_sold": region_avg_daily_sold,
        "raw_payload_json": {
            "url": url,
        },
    }


def sync_prices(
    conn,
    cache: HttpCache,
    region: str,
    *,
    force: bool = False,
    missing_only: bool = False,
    limit: int | None = None,
    expansions: list[str] | None = None,
    professions: list[str] | None = None,
    item_ids: list[int] | None = None,
) -> dict[str, Any]:
    from wow_tools.db import insert_price_snapshot

    where_clauses = []
    params: list[Any] = []
    if expansions:
        where_clauses.append(f"i.expansion_seed IN ({','.join('?' for _ in expansions)})")
        params.extend(expansions)
    if professions:
        where_clauses.append(f"i.profession IN ({','.join('?' for _ in professions)})")
        params.extend(professions)
    if item_ids:
        where_clauses.append(f"i.item_id IN ({','.join('?' for _ in item_ids)})")
        params.extend(item_ids)

    if missing_only:
        base_sql = """
            SELECT i.item_id
            FROM items i
            LEFT JOIN (
                SELECT DISTINCT item_id
                FROM price_snapshots
                WHERE region = ?
            ) priced
                ON priced.item_id = i.item_id
            WHERE priced.item_id IS NULL
        """
        sql_params: list[Any] = [region]
        if where_clauses:
            base_sql += " AND " + " AND ".join(where_clauses)
            sql_params.extend(params)
        base_sql += " ORDER BY i.item_id"
        item_rows = list(conn.execute(base_sql, sql_params))
    else:
        base_sql = "SELECT i.item_id FROM items i"
        if where_clauses:
            base_sql += " WHERE " + " AND ".join(where_clauses)
        base_sql += " ORDER BY i.item_id"
        item_rows = list(conn.execute(base_sql, params))

    if limit is not None:
        item_rows = item_rows[:limit]

    synced = 0
    failures: list[dict[str, Any]] = []
    total = len(item_rows)

    for index, row in enumerate(item_rows, start=1):
        item_id = int(row["item_id"])
        try:
            snapshot = fetch_item_price(item_id, region, cache, force=force)
            insert_price_snapshot(conn, snapshot)
            conn.commit()
            synced += 1
        except Exception as exc:
            failures.append({"item_id": item_id, "error": str(exc)})
            conn.commit()

        if index % 25 == 0 or index == total:
            print(f"[sync-prices] progress {index}/{total} synced={synced} failed={len(failures)}")

    return {"synced": synced, "failed": failures}
