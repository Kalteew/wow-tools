from __future__ import annotations

import json
import re
from typing import Any

from wow_tools.cache import HttpCache
from wow_tools.config import WOWHEAD_ITEM_TTL_SECONDS
from wow_tools.http import fetch_text
from wow_tools.reports import format_copper, format_number
from wow_tools.sources.tsm import fetch_item_price
from wow_tools.sources.wowhead import fetch_item_metadata


_LISTVIEW_MARKER = "new Listview({"
_STRING_FIELD_RE = re.compile(r'(?P<key>[A-Za-z_][A-Za-z0-9_]*)\s*:\s*(?P<quote>"|\')(?P<value>.*?)(?P=quote)', re.S)


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


def _extract_currency_for_items(html: str) -> list[dict[str, Any]]:
    index = 0

    while True:
        marker_index = html.find(_LISTVIEW_MARKER, index)
        if marker_index == -1:
            break
        object_start = html.find("{", marker_index)
        object_text, index = _scan_balanced(html, object_start, "{", "}")
        if "template: 'item'" not in object_text and 'template: "item"' not in object_text:
            continue
        if _extract_field_string(object_text, "id") != "currency-for":
            continue
        data_text = _extract_field_array(object_text, "data")
        if not data_text:
            break
        return json.loads(data_text)

    raise RuntimeError("Could not find Wowhead currency-for listview")


def _extract_currency_for_listview(html: str) -> list[dict[str, Any]]:
    return _extract_currency_for_items(html)


def _normalize_costs(raw_costs: Any) -> list[dict[str, int]]:
    if not isinstance(raw_costs, list):
        return []

    costs: list[dict[str, int]] = []
    for raw_cost in raw_costs:
        if not isinstance(raw_cost, list) or len(raw_cost) < 2:
            continue
        try:
            item_id = int(raw_cost[0])
            amount = int(raw_cost[1])
        except (TypeError, ValueError):
            continue
        costs.append({"item_id": item_id, "amount": amount})
    return costs


def _currency_cost_options(raw_cost: Any, currency_item_id: int) -> list[dict[str, Any]]:
    if not isinstance(raw_cost, list):
        return []

    options: list[dict[str, Any]] = []
    for entry in raw_cost:
        if not isinstance(entry, list) or len(entry) < 3:
            continue
        try:
            gold_cost_copper = int(entry[0] or 0)
        except (TypeError, ValueError):
            gold_cost_copper = 0

        item_costs = _normalize_costs(entry[1])
        currency_costs = _normalize_costs(entry[2])
        currency_cost = sum(cost["amount"] for cost in currency_costs if cost["item_id"] == currency_item_id)
        if currency_cost <= 0:
            continue

        options.append(
            {
                "currency_cost": currency_cost,
                "gold_cost_copper": gold_cost_copper,
                "item_costs": item_costs,
                "other_currency_costs": [cost for cost in currency_costs if cost["item_id"] != currency_item_id],
            }
        )

    return options


def _gold_only_cost_options(raw_cost: Any) -> list[int]:
    if not isinstance(raw_cost, list):
        return []

    options: list[int] = []
    for entry in raw_cost:
        if not isinstance(entry, list) or len(entry) < 3:
            continue
        try:
            gold_cost_copper = int(entry[0] or 0)
        except (TypeError, ValueError):
            continue
        if gold_cost_copper <= 0:
            continue
        if _normalize_costs(entry[1]) or _normalize_costs(entry[2]):
            continue
        options.append(gold_cost_copper)
    return options


def _select_best_cost(row: dict[str, Any], currency_item_id: int) -> dict[str, Any] | None:
    raw_cost = row.get("cost")
    if not isinstance(raw_cost, list):
        return None

    best_item = None
    best_item_key = None
    best_gold = None
    best_gold_key = None

    for cost_index, entry in enumerate(raw_cost):
        if not isinstance(entry, list) or len(entry) < 3:
            continue
        try:
            gold_cost_copper = int(entry[0] or 0)
        except (TypeError, ValueError):
            gold_cost_copper = 0

        item_costs = _normalize_costs(entry[1])
        currency_costs = _normalize_costs(entry[2])
        target_amount = sum(cost["amount"] for cost in currency_costs if cost["item_id"] == currency_item_id)

        if target_amount > 0:
            candidate = {
                "type": "item",
                "item_id": currency_item_id,
                "amount": target_amount,
                "cost_index": cost_index,
                "gold_cost_copper": gold_cost_copper,
                "item_costs": item_costs,
                "other_currency_costs": [cost for cost in currency_costs if cost["item_id"] != currency_item_id],
            }
            candidate_key = (
                candidate["amount"],
                candidate["gold_cost_copper"],
                len(candidate["item_costs"]) + len(candidate["other_currency_costs"]),
            )
            if best_item_key is None or candidate_key < best_item_key:
                best_item = candidate
                best_item_key = candidate_key
            continue

        if gold_cost_copper > 0 and not item_costs and not currency_costs:
            candidate = {
                "type": "gold",
                "copper": gold_cost_copper,
                "cost_index": cost_index,
            }
            candidate_key = (candidate["copper"], cost_index)
            if best_gold_key is None or candidate_key < best_gold_key:
                best_gold = candidate
                best_gold_key = candidate_key

    return best_item or best_gold


def _preferred_price(snapshot: dict[str, Any] | None) -> int | None:
    if not snapshot:
        return None
    return (
        snapshot.get("market_value_copper")
        or snapshot.get("region_market_value_avg_copper")
        or snapshot.get("min_buyout_copper")
        or snapshot.get("historical_price_copper")
    )


def _build_value_row(
    raw_item: dict[str, Any],
    currency_item_id: int,
    price_snapshot: dict[str, Any] | None,
    *,
    price_error: str | None = None,
) -> dict[str, Any] | None:
    options = _currency_cost_options(raw_item.get("cost"), currency_item_id)
    if not options:
        return None

    best_option = min(
        options,
        key=lambda option: (
            option["currency_cost"],
            option["gold_cost_copper"],
            len(option["item_costs"]) + len(option["other_currency_costs"]),
        ),
    )
    vendor_gold_options = sorted(_gold_only_cost_options(raw_item.get("cost")))
    market_value_copper = _preferred_price(price_snapshot)

    value_source = None
    value_copper = None
    if market_value_copper is not None:
        value_source = "market"
        value_copper = market_value_copper
    elif vendor_gold_options:
        value_source = "vendor-gold"
        value_copper = vendor_gold_options[0]

    net_value_copper = None
    copper_per_currency = None
    gold_per_currency = None
    if value_copper is not None:
        net_value_copper = value_copper - best_option["gold_cost_copper"]
        copper_per_currency = net_value_copper / best_option["currency_cost"]
        gold_per_currency = copper_per_currency / 10_000

    item_id = int(raw_item["id"])
    item_name = raw_item.get("displayName", raw_item.get("name")) or f"Item {item_id}"
    return {
        "item_id": item_id,
        "item_name": item_name,
        "wowhead_url": f"https://www.wowhead.com/item={item_id}",
        "quality": raw_item.get("quality"),
        "currency_cost": best_option["currency_cost"],
        "currency_cost_options": sorted({option["currency_cost"] for option in options}),
        "best_option_gold_cost_copper": best_option["gold_cost_copper"],
        "best_option_item_costs": best_option["item_costs"],
        "best_option_other_currency_costs": best_option["other_currency_costs"],
        "vendor_gold_cost_options_copper": vendor_gold_options,
        "market_value_copper": market_value_copper,
        "value_copper": value_copper,
        "value_source": value_source,
        "net_value_copper": net_value_copper,
        "copper_per_currency": copper_per_currency,
        "gold_per_currency": gold_per_currency,
        "market_source": price_snapshot.get("source") if price_snapshot else None,
        "market_sale_rate": price_snapshot.get("region_sale_rate") if price_snapshot else None,
        "market_avg_daily_sold": price_snapshot.get("region_avg_daily_sold") if price_snapshot else None,
        "price_error": price_error,
    }


def _sort_key(row: dict[str, Any]) -> tuple[bool, float, int, str]:
    gold_per_currency = row.get("gold_per_currency")
    return (
        gold_per_currency is None,
        -(gold_per_currency or 0.0),
        row["currency_cost"],
        row["item_name"].lower(),
    )


def build_currency_value_report(
    cache: HttpCache,
    region: str,
    *,
    currency_item_id: int = 163036,
    force: bool = False,
) -> dict[str, Any]:
    metadata = fetch_item_metadata(currency_item_id, cache, force=force)
    html = fetch_text(
        f"https://www.wowhead.com/item={currency_item_id}",
        cache,
        WOWHEAD_ITEM_TTL_SECONDS,
        force=force,
    )
    raw_items = _extract_currency_for_items(html)

    rows: list[dict[str, Any]] = []
    failed_price_fetches = 0

    for raw_item in raw_items:
        item_id = int(raw_item["id"])
        price_snapshot = None
        price_error = None
        try:
            price_snapshot = fetch_item_price(item_id, region, cache, force=force)
        except Exception as exc:
            price_error = str(exc)
            failed_price_fetches += 1

        row = _build_value_row(raw_item, currency_item_id, price_snapshot, price_error=price_error)
        if row is not None:
            rows.append(row)

    rows.sort(key=_sort_key)

    valued_rows = [row for row in rows if row["gold_per_currency"] is not None]
    market_rows = [row for row in valued_rows if row["value_source"] == "market"]
    vendor_rows = [row for row in valued_rows if row["value_source"] == "vendor-gold"]

    return {
        "region": region,
        "currency_item_id": currency_item_id,
        "currency_name": metadata.get("title") or f"Item {currency_item_id}",
        "currency_wowhead_url": metadata.get("wowhead_url") or f"https://www.wowhead.com/item={currency_item_id}",
        "rows": rows,
        "summary": {
            "items": len(rows),
            "valued_items": len(valued_rows),
            "market_items": len(market_rows),
            "vendor_gold_fallback_items": len(vendor_rows),
            "missing_value_items": len(rows) - len(valued_rows),
            "failed_price_fetches": failed_price_fetches,
        },
    }


def render_currency_value_report(report: dict[str, Any], *, top: int = 0) -> str:
    rows = report["rows"]
    if top > 0:
        rows = rows[:top]

    summary = report["summary"]
    currency_label = "gold/charm" if "charm" in report["currency_name"].lower() else "gold/currency"

    lines = [
        f"{report['currency_name']} value for region {report['region'].upper()}",
        (
            f"items={summary['items']} "
            f"valued={summary['valued_items']} "
            f"market={summary['market_items']} "
            f"vendor_fallback={summary['vendor_gold_fallback_items']} "
            f"missing={summary['missing_value_items']}"
        ),
        "",
    ]

    for index, row in enumerate(rows, start=1):
        parts = [
            f"{index}. {row['item_name']} ({row['item_id']})",
            f"cost={row['currency_cost']}",
        ]
        if len(row["currency_cost_options"]) > 1:
            parts.append(
                "alts=" + ",".join(str(value) for value in row["currency_cost_options"])
            )
        if row["best_option_gold_cost_copper"]:
            parts.append(f"+gold={format_copper(row['best_option_gold_cost_copper'])}")
        if row["value_copper"] is not None:
            parts.append(f"value={format_copper(row['value_copper'])}")
            parts.append(f"source={row['value_source']}")
            parts.append(f"{currency_label}={row['gold_per_currency']:,.2f}")
        else:
            parts.append("value=-")
        if row["market_sale_rate"] is not None:
            parts.append(f"sale_rate={format_number(row['market_sale_rate'])}")
        if row["market_avg_daily_sold"] is not None:
            parts.append(f"sold/day={format_number(row['market_avg_daily_sold'])}")
        lines.append(" | ".join(parts))

    return "\n".join(lines).rstrip()
