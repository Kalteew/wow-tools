from __future__ import annotations

import json
from collections import defaultdict
from pathlib import Path
from statistics import median
from typing import Any

from wow_tools.config import REPORT_DIR
from wow_tools.db import latest_prices
from wow_tools.farm_model import aggregate_family

ANCHOR_CATEGORIES = {"anchor", "wide_anchor", "dense_anchor"}


def format_copper(value: int | None) -> str:
    if value is None:
        return "-"
    gold = value // 10_000
    silver = (value % 10_000) // 100
    copper = value % 100
    if gold:
        return f"{gold}g {silver}s {copper}c"
    if silver:
        return f"{silver}s {copper}c"
    return f"{copper}c"


def format_number(value: float | int | None) -> str:
    if value is None:
        return "-"
    if isinstance(value, float):
        return f"{value:,.2f}"
    return f"{value:,}"


def _preferred_price(row: dict[str, Any]) -> int | None:
    return (
        row["market_value_copper"]
        or row["region_market_value_avg_copper"]
        or row["min_buyout_copper"]
        or row["historical_price_copper"]
    )


def build_expansion_report(conn, region: str, top: int = 5) -> dict[str, Any]:
    rows = [dict(row) for row in latest_prices(conn, region)]
    expansions: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for row in rows:
        expansions[row["expansion_seed"]].append(row)

    report_rows: list[dict[str, Any]] = []

    for expansion, items in expansions.items():
        priced = [row for row in items if _preferred_price(row) is not None]
        price_values = [_preferred_price(row) for row in priced if _preferred_price(row) is not None]
        velocity_rows = []
        for row in priced:
            price = _preferred_price(row)
            sold = row.get("region_avg_daily_sold")
            velocity = None
            if price is not None and sold is not None:
                velocity = price * sold
            velocity_rows.append((velocity or 0, row))

        velocity_rows.sort(key=lambda pair: pair[0], reverse=True)
        top_items = []
        for velocity, row in velocity_rows[:top]:
            top_items.append(
                {
                    "item_id": row["item_id"],
                    "family_name": row["family_name"],
                    "item_name": row["item_name"],
                    "profession": row["profession"],
                    "price_copper": _preferred_price(row),
                    "min_buyout_copper": row["min_buyout_copper"],
                    "market_value_copper": row["market_value_copper"],
                    "available_quantity": row["available_quantity"],
                    "region_sale_rate": row["region_sale_rate"],
                    "region_avg_daily_sold": row["region_avg_daily_sold"],
                    "velocity_proxy": velocity,
                }
            )

        report_rows.append(
            {
                "expansion": expansion,
                "tracked_items": len(items),
                "priced_items": len(priced),
                "median_price_copper": int(median(price_values)) if price_values else None,
                "max_price_copper": max(price_values) if price_values else None,
                "velocity_proxy_total": sum(pair[0] for pair in velocity_rows),
                "top_items": top_items,
            }
        )

    report_rows.sort(key=lambda row: row["velocity_proxy_total"], reverse=True)
    return {
        "region": region,
        "rows": report_rows,
    }


def build_farmability_report(conn, region: str, top: int = 5) -> dict[str, Any]:
    rows = [dict(row) for row in latest_prices(conn, region)]
    families: dict[tuple[str, str, str], list[dict[str, Any]]] = defaultdict(list)
    for row in rows:
        key = (row["expansion_seed"], row["profession"], row["family_name"])
        row["price_copper"] = _preferred_price(row)
        families[key].append(row)

    by_expansion: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for family_rows in families.values():
        aggregate = aggregate_family(family_rows)
        by_expansion[aggregate["expansion"]].append(aggregate)

    report_rows: list[dict[str, Any]] = []
    for expansion, family_rows in by_expansion.items():
        sorted_by_adjusted = sorted(
            family_rows,
            key=lambda row: row["rarity_adjusted_score"],
            reverse=True,
        )
        top_materials = []
        for family in sorted_by_adjusted[:top]:
            top_materials.append(
                {
                    "family_name": family["family_name"],
                    "profession": family["profession"],
                    "profile_category": family["profile_category"],
                    "acquisition_weight": family["acquisition_weight"],
                    "route_weight": family["route_weight"],
                    "farm_weight": family["farm_weight"],
                    "profile_note": family["profile_note"],
                    "expected_unit_value_copper": family["expected_unit_value_copper"],
                    "total_daily_sold": family["total_daily_sold"],
                    "blended_sale_rate": family["blended_sale_rate"],
                    "hourly_sourced": family["hourly_sourced"],
                    "hourly_source_urls": family["hourly_source_urls"],
                    "hourly_source_note": family["hourly_source_note"],
                    "route_hint": family["route_hint"],
                    "estimated_units_per_hour_low": family["estimated_units_per_hour_low"],
                    "estimated_units_per_hour": family["estimated_units_per_hour"],
                    "estimated_units_per_hour_high": family["estimated_units_per_hour_high"],
                    "estimated_gold_per_hour_low_copper": family["estimated_gold_per_hour_low_copper"],
                    "estimated_gold_per_hour_copper": family["estimated_gold_per_hour_copper"],
                    "estimated_gold_per_hour_high_copper": family["estimated_gold_per_hour_high_copper"],
                    "hourly_weight": family["hourly_weight"],
                    "rarity_adjusted_score": family["rarity_adjusted_score"],
                }
            )

        anchor_score = sum(
            row["rarity_adjusted_score"]
            for row in family_rows
            if row["profile_category"] in ANCHOR_CATEGORIES
        )
        jackpot_score = sum(
            row["rarity_adjusted_score"]
            for row in family_rows
            if row["profile_category"] not in ANCHOR_CATEGORIES
        )
        expected_values = [row["expected_unit_value_copper"] for row in family_rows if row["expected_unit_value_copper"]]
        hourly_values = [row["estimated_units_per_hour"] for row in family_rows if row["estimated_units_per_hour"]]
        best_gold_per_hour = max(
            (row["estimated_gold_per_hour_copper"] for row in family_rows),
            default=None,
        )

        report_rows.append(
            {
                "expansion": expansion,
                "tracked_families": len(family_rows),
                "median_expected_unit_copper": int(median(expected_values)) if expected_values else None,
                "median_estimated_units_per_hour": round(median(hourly_values), 2) if hourly_values else None,
                "best_estimated_gold_per_hour_copper": best_gold_per_hour,
                "anchor_score": anchor_score,
                "jackpot_score": jackpot_score,
                "total_farmability_score": anchor_score + jackpot_score,
                "top_materials": top_materials,
            }
        )

    report_rows.sort(key=lambda row: row["total_farmability_score"], reverse=True)
    return {"region": region, "rows": report_rows}


def save_report(report: dict[str, Any], filename: str) -> Path:
    REPORT_DIR.mkdir(parents=True, exist_ok=True)
    output_path = REPORT_DIR / filename
    output_path.write_text(json.dumps(report, indent=2, sort_keys=True), encoding="utf-8")
    return output_path


def render_expansion_report(report: dict[str, Any]) -> str:
    lines = []
    lines.append(f"Expansion comparison for region {report['region'].upper()}")
    lines.append("")
    for row in report["rows"]:
        lines.append(
            (
                f"{row['expansion']}: "
                f"tracked={row['tracked_items']} "
                f"priced={row['priced_items']} "
                f"median={format_copper(row['median_price_copper'])} "
                f"max={format_copper(row['max_price_copper'])} "
                f"velocity_proxy={format_number(row['velocity_proxy_total'])}"
            )
        )
        for item in row["top_items"]:
            lines.append(
                "  - "
                f"{item['item_name']} [{item['profession']}] "
                f"price={format_copper(item['price_copper'])} "
                f"sold/day={format_number(item['region_avg_daily_sold'])} "
                f"sale_rate={format_number(item['region_sale_rate'])}"
            )
        lines.append("")
    return "\n".join(lines).rstrip()


def render_farmability_report(report: dict[str, Any]) -> str:
    lines = []
    lines.append(f"Farmability comparison for region {report['region'].upper()}")
    lines.append("")
    for row in report["rows"]:
        lines.append(
            (
                f"{row['expansion']}: "
                f"families={row['tracked_families']} "
                f"median_expected={format_copper(row['median_expected_unit_copper'])} "
                f"median_units/hr={format_number(row['median_estimated_units_per_hour'])} "
                f"best_gold/hr={format_copper(row['best_estimated_gold_per_hour_copper'])} "
                f"anchor_score={format_number(row['anchor_score'])} "
                f"jackpot_score={format_number(row['jackpot_score'])} "
                f"total={format_number(row['total_farmability_score'])}"
            )
        )
        for material in row["top_materials"]:
            lines.append(
                "  - "
                f"{material['family_name']} [{material['profession']}] "
                f"class={material['profile_category']} "
                f"expected={format_copper(material['expected_unit_value_copper'])} "
                f"units/hr={format_number(material['estimated_units_per_hour'])} "
                f"[{format_number(material['estimated_units_per_hour_low'])}-{format_number(material['estimated_units_per_hour_high'])}] "
                f"gold/hr={format_copper(material['estimated_gold_per_hour_copper'])} "
                f"sold/day={format_number(material['total_daily_sold'])} "
                f"sale_rate={format_number(material['blended_sale_rate'])} "
                f"spawn={material['acquisition_weight']:.2f} "
                f"route={material['route_weight']:.2f} "
                f"market_weight={material['farm_weight']:.2f} "
                f"hourly={material['hourly_weight']:.2f}"
            )
        lines.append("")
    return "\n".join(lines).rstrip()
