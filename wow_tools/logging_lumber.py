from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from wow_tools.account_pipeline import load_local_price_index
from wow_tools.db import connect


REPO_ROOT = Path(__file__).resolve().parents[1]
LOGGING_CONFIG_PATH = REPO_ROOT / "data" / "tsm" / "logging_groups.json"
AH_CUT_RATE = 0.05
SELL_RATE_MALUS_K = 0.10


def _lumber_price(summary: dict[str, Any]) -> int | None:
    for key in ("region_sale_avg_copper", "preferred_price_copper"):
        value = summary.get(key)
        if isinstance(value, int) and value > 0:
            return value
    return None


def _load_logging_config() -> dict[str, Any]:
    return json.loads(LOGGING_CONFIG_PATH.read_text(encoding="utf-8"))


def _load_recipe_map(conn, product_item_ids: list[int], wood_item_id: int) -> dict[int, dict[str, Any]]:
    if not product_item_ids:
        return {}
    placeholders = ",".join("?" for _ in product_item_ids)
    rows = conn.execute(
        f"""
        SELECT
            pr.spell_id,
            pr.output_item_id,
            pr.profession,
            pr.recipe_name,
            rr.reagent_item_id,
            rr.quantity,
            ri.item_name AS reagent_name
        FROM profession_recipes pr
        JOIN recipe_reagents rr ON rr.spell_id = pr.spell_id
        LEFT JOIN recipe_items ri ON ri.item_id = rr.reagent_item_id
        WHERE pr.output_item_id IN ({placeholders})
          AND EXISTS (
              SELECT 1
              FROM recipe_reagents wood_rr
              WHERE wood_rr.spell_id = pr.spell_id
                AND wood_rr.reagent_item_id = ?
          )
        ORDER BY pr.output_item_id, pr.spell_id, rr.reagent_order
        """,
        (*product_item_ids, wood_item_id),
    ).fetchall()

    recipe_map: dict[int, dict[str, Any]] = {}
    for row in rows:
        item_id = int(row["output_item_id"])
        recipe = recipe_map.setdefault(
            item_id,
            {
                "spell_id": int(row["spell_id"]),
                "profession": row["profession"],
                "recipe_name": row["recipe_name"],
                "reagents": [],
            },
        )
        if recipe["spell_id"] != int(row["spell_id"]):
            continue
        recipe["reagents"].append(
            {
                "item_id": int(row["reagent_item_id"]),
                "item_name": row["reagent_name"],
                "quantity": float(row["quantity"] or 0.0),
            }
        )
    return recipe_map


def _load_item_names(conn, item_ids: list[int]) -> dict[int, str]:
    if not item_ids:
        return {}
    placeholders = ",".join("?" for _ in item_ids)
    rows = conn.execute(
        f"SELECT item_id, item_name FROM recipe_items WHERE item_id IN ({placeholders})",
        item_ids,
    ).fetchall()
    return {int(item_id): str(item_name) for item_id, item_name in rows}


def _liquidity_factor(sell_rate: float) -> float:
    if sell_rate <= 0:
        return 0.0
    return sell_rate / (sell_rate + SELL_RATE_MALUS_K)


def build_logging_lumber_report(region: str) -> dict[str, Any]:
    config = _load_logging_config()
    expansions = config.get("expansions", [])

    conn = connect()
    try:
        all_snapshot_ids: set[int] = set()
        for expansion in expansions:
            all_snapshot_ids.add(int(expansion["wood_item_id"]))
            all_snapshot_ids.update(int(item_id) for item_id in expansion.get("product_item_ids", []))

        recipe_maps = {
            expansion["label"]: _load_recipe_map(
                conn,
                [int(item_id) for item_id in expansion.get("product_item_ids", [])],
                int(expansion["wood_item_id"]),
            )
            for expansion in expansions
        }

        for recipe_map in recipe_maps.values():
            for recipe in recipe_map.values():
                for reagent in recipe["reagents"]:
                    all_snapshot_ids.add(int(reagent["item_id"]))

        price_index = load_local_price_index(sorted(all_snapshot_ids))
        item_names = _load_item_names(conn, sorted(all_snapshot_ids))

        rows: list[dict[str, Any]] = []
        for expansion in expansions:
            label = expansion["label"]
            wood_item_id = int(expansion["wood_item_id"])
            product_item_ids = [int(item_id) for item_id in expansion.get("product_item_ids", [])]
            wood_summary = (price_index.get(wood_item_id) or {}).get("summary", {})
            wood_price = _lumber_price(wood_summary)
            wood_daily = float(wood_summary.get("sold_per_day") or 0.0)
            wood_sale_rate = float(wood_summary.get("sale_rate") or 0.0)

            recipe_map = recipe_maps.get(label, {})
            product_rows: list[dict[str, Any]] = []
            for item_id in product_item_ids:
                product_summary = (price_index.get(item_id) or {}).get("summary", {})
                recipe = recipe_map.get(item_id)
                sale_price = _lumber_price(product_summary)
                if sale_price is None or not recipe:
                    continue
                sell_rate = float(product_summary.get("sale_rate") or 0.0)
                avg_daily_sold = float(product_summary.get("sold_per_day") or 0.0)

                non_wood_cost_copper = 0.0
                has_full_cost = True
                wood_quantity = 0.0
                for reagent in recipe["reagents"]:
                    reagent_id = int(reagent["item_id"])
                    reagent_quantity = float(reagent["quantity"] or 0.0)
                    if reagent_id == wood_item_id:
                        wood_quantity += reagent_quantity
                        continue
                    reagent_price = _lumber_price((price_index.get(reagent_id) or {}).get("summary") or {})
                    if reagent_price is None:
                        has_full_cost = False
                        break
                    non_wood_cost_copper += reagent_price * reagent_quantity

                if not has_full_cost or wood_quantity <= 0:
                    continue

                net_sale_copper = float(sale_price) * (1.0 - AH_CUT_RATE)
                craft_profit_copper = net_sale_copper - non_wood_cost_copper
                liquidity_factor = _liquidity_factor(sell_rate)
                adjusted_profit_copper = craft_profit_copper * liquidity_factor
                adjusted_profit_per_wood = adjusted_profit_copper / wood_quantity

                product_rows.append(
                    {
                        "item_id": item_id,
                        "item_name": item_names.get(item_id),
                        "profession": recipe["profession"],
                        "recipe_name": recipe["recipe_name"],
                        "wood_quantity": wood_quantity,
                        "sale_price_copper": sale_price,
                        "craft_cost_copper": int(round(non_wood_cost_copper)),
                        "craft_profit_copper": int(round(craft_profit_copper)),
                        "sell_rate": sell_rate,
                        "avg_daily_sold": avg_daily_sold,
                        "liquidity_factor": liquidity_factor,
                        "adjusted_profit_copper": int(round(adjusted_profit_copper)),
                        "adjusted_profit_per_wood": adjusted_profit_per_wood,
                    }
                )

            product_rows.sort(
                key=lambda row: (
                    -(row.get("adjusted_profit_per_wood") or 0.0),
                    -(row.get("avg_daily_sold") or 0.0),
                    -(row.get("sell_rate") or 0.0),
                )
            )

            avg_profit_copper = (
                sum(row["craft_profit_copper"] for row in product_rows) / len(product_rows) if product_rows else 0.0
            )
            avg_sell_rate = (
                sum(row["sell_rate"] for row in product_rows) / len(product_rows) if product_rows else 0.0
            )
            avg_liquidity = (
                sum(row["liquidity_factor"] for row in product_rows) / len(product_rows) if product_rows else 0.0
            )
            avg_value_per_wood = (
                sum(row["adjusted_profit_per_wood"] for row in product_rows) / len(product_rows) if product_rows else 0.0
            )
            best_product = product_rows[0] if product_rows else None

            rows.append(
                {
                    "expansion": label,
                    "wood_item_id": wood_item_id,
                    "wood_name": expansion["wood_name"],
                    "wood_price_copper": wood_price,
                    "wood_sale_rate": wood_sale_rate,
                    "wood_avg_daily_sold": wood_daily,
                    "product_count": len(product_item_ids),
                    "product_market_count": len(product_rows),
                    "avg_craft_profit_copper": int(round(avg_profit_copper)),
                    "avg_product_sell_rate": avg_sell_rate,
                    "avg_liquidity_factor": avg_liquidity,
                    "estimated_value_per_wood_copper": int(round(avg_value_per_wood)),
                    "best_profession": best_product.get("profession") if best_product else None,
                    "top_products": product_rows[:5],
                }
            )
    finally:
        conn.close()

    rows.sort(
        key=lambda row: (
            -(row.get("estimated_value_per_wood_copper") or 0),
            -(row.get("avg_craft_profit_copper") or 0),
            row.get("expansion") or "",
        )
    )

    return {
        "region": region,
        "price_source": "avgSell (TSM regionSale), fallback preferred price",
        "formula": "avg((sale*0.95 - non_wood_cost) * (sell_rate/(sell_rate+0.10)) / wood_qty)",
        "row_count": len(rows),
        "rows": rows,
    }
