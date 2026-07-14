from __future__ import annotations

import json
from collections import defaultdict
from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Any

from wow_tools.cache import HttpCache
from wow_tools.alchemy_mastery import load_character_alchemy_masteries, recipe_mastery_bonus
from wow_tools.config import DB_PATH
from wow_tools.db import connect, latest_prices, upsert_item
from wow_tools.local_recipes import load_recipe_ownership_index, recipe_is_owned, recipe_ownership
from wow_tools.recipe_catalog import (
    ItemSeed,
    RecipeSeed,
    ReagentSeed,
    default_favorite_spell_ids,
    recipes_by_output_item,
)
from wow_tools.recipe_favorites import ensure_favorite_spell_ids, load_favorite_spell_ids
from wow_tools.recipe_scoring import apply_balanced_recipe_scores
from wow_tools.reports import format_copper, format_number, save_report
from wow_tools.sources.tsm import sync_prices

AH_CUT_FACTOR = 0.95
SEED_RECIPE_OVERRIDES = recipes_by_output_item()
SPECIAL_CURRENCY_ITEM_IDS = {124124}
VENDOR_COST_OVERRIDES = {
    3371: 100,
    65892: 45_000_000,
    65893: 27_000_000,
    44499: 30_000_000,
    44500: 15_000_000,
    44501: 10_000_000,
}


@dataclass
class ResolvedReagent:
    label: str
    quantity: float
    total_cost_copper: int | None
    source: str
    note: str | None = None


@dataclass
class CraftOption:
    recipe: RecipeSeed
    unit_cost_copper: int
    reagents: list[ResolvedReagent]
    output_multiplier: float = 1.0


@dataclass
class ItemResolution:
    item: ItemSeed
    market_price_copper: int | None
    sale_rate: float | None
    avg_daily_sold: float | None
    cheapest_craft: CraftOption | None
    best_acquisition_copper: int | None
    best_source: str


class RecipeCycleDetected(RuntimeError):
    pass


def _now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def _preferred_price(row: dict[str, Any] | None) -> int | None:
    if not row:
        return None
    return (
        row.get("market_value_copper")
        or row.get("region_market_value_avg_copper")
        or row.get("min_buyout_copper")
        or row.get("historical_price_copper")
    )


def _recipe_item_row(item_id: int, item_name: str, source_url: str | None, quality: int | None) -> dict[str, Any]:
    return {
        "item_id": item_id,
        "profession": "crafting",
        "expansion_seed": "unknown",
        "expansion_detected": None,
        "category": "crafted",
        "family_name": item_name,
        "item_name": item_name,
        "wowhead_url": f"https://www.wowhead.com/item={item_id}",
        "icon_url": None,
        "description": None,
        "item_level": None,
        "req_level": None,
        "wowhead_quality": quality,
        "wowhead_popularity": None,
        "source_kind": "wowhead-profession-recipe",
        "is_gatherable": 0,
        "metadata_json": json.dumps({"recipe_item": True, "source_url": source_url}, sort_keys=True),
        "last_catalog_sync": _now_iso(),
    }


def seed_recipe_items(conn) -> int:
    seeded = 0
    existing_ids = {
        int(row["item_id"])
        for row in conn.execute("SELECT item_id FROM items")
    }
    rows = conn.execute(
        """
        SELECT item_id, item_name, icon, quality, source_url
        FROM recipe_items
        ORDER BY item_id
        """
    )
    for row in rows:
        item_id = int(row["item_id"])
        if item_id in existing_ids:
            continue
        item_name = row["item_name"] or f"Item {item_id}"
        upsert_item(conn, _recipe_item_row(item_id, item_name, row["source_url"], row["quality"]))
        seeded += 1
    conn.commit()
    return seeded


def _recipe_item_ids(conn) -> list[int]:
    excluded = SPECIAL_CURRENCY_ITEM_IDS | set(VENDOR_COST_OVERRIDES)
    return [
        int(row["item_id"])
        for row in conn.execute("SELECT item_id FROM recipe_items ORDER BY item_id")
        if int(row["item_id"]) not in excluded
    ]


def sync_recipe_prices(conn, cache: HttpCache, region: str, *, force: bool = False) -> dict[str, Any]:
    seeded = seed_recipe_items(conn)
    price_ids = _recipe_item_ids(conn)
    summary = sync_prices(
        conn,
        cache,
        region,
        force=force,
        item_ids=price_ids,
    )
    summary["seeded"] = seeded
    summary["tracked_item_ids"] = len(price_ids)
    summary["priced_item_ids"] = len(price_ids)
    return summary


def _load_recipe_catalog(conn) -> dict[int, ItemSeed]:
    catalog: dict[int, ItemSeed] = {}
    for row in conn.execute("SELECT item_id, item_name FROM recipe_items ORDER BY item_id"):
        item_id = int(row["item_id"])
        item_name = row["item_name"] or f"Item {item_id}"
        catalog[item_id] = ItemSeed(
            item_id=item_id,
            item_name=item_name,
            expansion="unknown",
            profession="crafted",
            category="crafted",
            family_name=item_name,
            auctionable=True,
            analysis_target=False,
        )
    return catalog


def _recipe_output_quantity(min_quantity: float | None, max_quantity: float | None) -> float:
    if min_quantity is None and max_quantity is None:
        return 1.0
    if min_quantity is None:
        return float(max_quantity or 1.0) or 1.0
    if max_quantity is None:
        return float(min_quantity) or 1.0
    if max_quantity < min_quantity:
        return float(min_quantity) or 1.0
    if min_quantity == max_quantity:
        return float(min_quantity) or 1.0
    return ((float(min_quantity) + float(max_quantity)) / 2.0) or 1.0


def _load_recipe_graph(conn) -> dict[int, list[RecipeSeed]]:
    recipe_rows = list(
        conn.execute(
            """
            SELECT
                r.spell_id,
                r.profession,
                r.recipe_name,
                r.output_item_id,
                r.output_min_quantity,
                r.output_max_quantity,
                r.listview_name
            FROM profession_recipes r
            WHERE r.output_item_id IS NOT NULL
            ORDER BY r.output_item_id, r.profession, r.recipe_name, r.spell_id
            """
        )
    )
    reagents_by_spell: dict[int, list[ReagentSeed]] = defaultdict(list)
    for row in conn.execute(
        """
        SELECT
            rr.spell_id,
            rr.reagent_item_id,
            rr.quantity
        FROM recipe_reagents rr
        ORDER BY rr.spell_id, rr.reagent_order
        """
    ):
        reagents_by_spell[int(row["spell_id"])].append(
            ReagentSeed(
                item_id=int(row["reagent_item_id"]),
                quantity=float(row["quantity"]),
            )
        )

    recipes_by_output: dict[int, list[RecipeSeed]] = defaultdict(list)
    for row in recipe_rows:
        spell_id = int(row["spell_id"])
        output_item_id = int(row["output_item_id"])
        output_quantity = _recipe_output_quantity(row["output_min_quantity"], row["output_max_quantity"])
        notes: tuple[str, ...] = ()
        if row["output_min_quantity"] is not None and row["output_max_quantity"] is not None:
            min_quantity = float(row["output_min_quantity"])
            max_quantity = float(row["output_max_quantity"])
            if min_quantity != max_quantity:
                notes = (f"Estimated average output {output_quantity:g} from WoWhead craft range.",)
        recipe = RecipeSeed(
            recipe_id=f"spell-{spell_id}",
            recipe_name=str(row["recipe_name"] or f"Spell {spell_id}"),
            output_item_id=output_item_id,
            output_quantity=output_quantity,
            expansion=str(row["listview_name"] or "unknown"),
            profession=str(row["profession"] or "unknown"),
            reagents=tuple(reagents_by_spell.get(spell_id, ())),
            notes=notes,
            spell_id=spell_id,
        )
        recipes_by_output[output_item_id].append(recipe)

    for output_item_id, recipe_list in SEED_RECIPE_OVERRIDES.items():
        recipes_by_output[output_item_id] = list(recipe_list)

    return dict(recipes_by_output)


class _RecipeAnalyzer:
    def __init__(
        self,
        catalog: dict[int, ItemSeed],
        recipes_by_output: dict[int, list[RecipeSeed]],
        price_rows: dict[int, dict[str, Any]],
        recipe_output_multipliers: dict[int, float],
    ):
        self.catalog = catalog
        self.recipes_by_output = recipes_by_output
        self.price_rows = price_rows
        self.recipe_output_multipliers = recipe_output_multipliers
        self._memo: dict[int, ItemResolution] = {}
        self._visiting: set[int] = set()
        self._fallback_catalog: dict[int, ItemSeed] = {}

    def _catalog_item(self, item_id: int) -> ItemSeed:
        item = self.catalog.get(item_id)
        if item is not None:
            return item
        cached = self._fallback_catalog.get(item_id)
        if cached is not None:
            return cached
        placeholder = ItemSeed(
            item_id=item_id,
            item_name=f"Item {item_id}",
            expansion="unknown",
            profession="crafted",
            category="crafted",
            family_name=f"Item {item_id}",
            auctionable=True,
            analysis_target=False,
        )
        self._fallback_catalog[item_id] = placeholder
        return placeholder

    def resolve_item(self, item_id: int) -> ItemResolution:
        cached = self._memo.get(item_id)
        if cached is not None:
            return cached
        if item_id in self._visiting:
            raise RecipeCycleDetected(str(item_id))

        self._visiting.add(item_id)
        item = self._catalog_item(item_id)
        price_row = self.price_rows.get(item_id)
        market_price = _preferred_price(price_row)
        sale_rate = price_row.get("region_sale_rate") if price_row else None
        avg_daily_sold = price_row.get("region_avg_daily_sold") if price_row else None

        craft_options: list[CraftOption] = []
        for recipe in self.recipes_by_output.get(item_id, []):
            resolved_reagents: list[ResolvedReagent] = []
            total_cost = 0
            failed = False
            output_multiplier = self.recipe_output_multipliers.get(recipe.spell_id, 1.0) if recipe.spell_id is not None else 1.0
            effective_output_quantity = recipe.output_quantity * output_multiplier
            for reagent in recipe.reagents:
                try:
                    resolved = self._resolve_reagent(reagent)
                except RecipeCycleDetected:
                    failed = True
                    break
                resolved_reagents.append(resolved)
                if resolved.total_cost_copper is None:
                    failed = True
                    break
                total_cost += resolved.total_cost_copper
            if failed:
                continue
            craft_options.append(
                CraftOption(
                    recipe=recipe,
                    unit_cost_copper=int(round(total_cost / effective_output_quantity)),
                    reagents=resolved_reagents,
                    output_multiplier=output_multiplier,
                )
            )

        cheapest_craft = min(craft_options, key=lambda option: option.unit_cost_copper) if craft_options else None

        best_source = "unavailable"
        best_cost: int | None = None
        if item.auctionable and market_price is not None:
            best_cost = market_price
            best_source = "buy"
        if cheapest_craft is not None and (best_cost is None or cheapest_craft.unit_cost_copper < best_cost):
            best_cost = cheapest_craft.unit_cost_copper
            best_source = cheapest_craft.recipe.recipe_name

        resolution = ItemResolution(
            item=item,
            market_price_copper=market_price,
            sale_rate=sale_rate,
            avg_daily_sold=avg_daily_sold,
            cheapest_craft=cheapest_craft,
            best_acquisition_copper=best_cost,
            best_source=best_source,
        )
        self._memo[item_id] = resolution
        self._visiting.remove(item_id)
        return resolution

    def _resolve_reagent(self, reagent: ReagentSeed) -> ResolvedReagent:
        if reagent.item_id in SPECIAL_CURRENCY_ITEM_IDS or reagent.name == "Blood of Sargeras":
            item = self._catalog_item(reagent.item_id) if reagent.item_id is not None else None
            return ResolvedReagent(
                label=item.item_name if item is not None else (reagent.name or "Blood of Sargeras"),
                quantity=reagent.quantity,
                total_cost_copper=0,
                source="currency",
                note="Illnea Bloodthorn currency cost, no AH proxy",
            )

        if reagent.item_id is not None:
            if reagent.item_id in VENDOR_COST_OVERRIDES:
                return ResolvedReagent(
                    label=self._catalog_item(reagent.item_id).item_name,
                    quantity=reagent.quantity,
                    total_cost_copper=int(round(VENDOR_COST_OVERRIDES[reagent.item_id] * reagent.quantity)),
                    source="vendor",
                )
            item_resolution = self.resolve_item(reagent.item_id)
            total_cost = None
            if item_resolution.best_acquisition_copper is not None:
                total_cost = int(round(item_resolution.best_acquisition_copper * reagent.quantity))
            return ResolvedReagent(
                label=self._catalog_item(reagent.item_id).item_name,
                quantity=reagent.quantity,
                total_cost_copper=total_cost,
                source=item_resolution.best_source,
            )

        if reagent.vendor_cost_copper is not None:
            return ResolvedReagent(
                label=reagent.name or "Vendor reagent",
                quantity=reagent.quantity,
                total_cost_copper=int(round(reagent.vendor_cost_copper * reagent.quantity)),
                source="vendor",
            )

        return ResolvedReagent(
            label=reagent.name or "Unknown reagent",
            quantity=reagent.quantity,
            total_cost_copper=None,
            source="unpriced",
        )


def build_recipe_profit_report(
    conn,
    region: str,
    *,
    top: int = 0,
    min_sale_rate: float = 0.0,
    owned_only: bool = False,
    retail_root: str | None = None,
    account_root: str | None = None,
) -> dict[str, Any]:
    generated_at = _now_iso()
    seed_recipe_items(conn)
    catalog = _load_recipe_catalog(conn)
    recipes_by_output = _load_recipe_graph(conn)
    rows = [dict(row) for row in latest_prices(conn, region)]
    price_rows = {row["item_id"]: row for row in rows}
    try:
        # Ownership is refreshed from local SavedVariables on every analysis run.
        ownership_index = load_recipe_ownership_index(retail_root, account_root)
    except FileNotFoundError:
        ownership_index = None
    mastery_index = load_character_alchemy_masteries(retail_root, account_root)
    ensure_favorite_spell_ids(conn, default_favorite_spell_ids())
    favorite_spell_ids = load_favorite_spell_ids(conn)

    recipe_output_multipliers: dict[int, float] = {}
    for recipe_list in recipes_by_output.values():
        for recipe in recipe_list:
            if recipe.spell_id is None:
                continue
            ownership = recipe_ownership(
                ownership_index,
                spell_id=recipe.spell_id,
                profession=recipe.profession,
            )
            multiplier, _, _ = recipe_mastery_bonus(
                recipe.recipe_name,
                recipe.profession,
                recipe_expansion=recipe.expansion,
                known_by=ownership["known_by"],
                mastery_index=mastery_index,
            )
            if multiplier != 1.0:
                recipe_output_multipliers[recipe.spell_id] = multiplier

    analyzer = _RecipeAnalyzer(catalog, recipes_by_output, price_rows, recipe_output_multipliers)

    def _resolve_recipe_inputs(recipe: RecipeSeed) -> tuple[list[ResolvedReagent], int | None]:
        resolved_reagents: list[ResolvedReagent] = []
        total_cost = 0
        failed = False
        for reagent in recipe.reagents:
            try:
                resolved = analyzer._resolve_reagent(reagent)
            except RecipeCycleDetected:
                resolved = ResolvedReagent(
                    label=reagent.name or (analyzer._catalog_item(reagent.item_id).item_name if reagent.item_id is not None else "Cycle reagent"),
                    quantity=reagent.quantity,
                    total_cost_copper=None,
                    source="cycle",
                    note="Recipe cycle detected",
                )
                failed = True
            resolved_reagents.append(resolved)
            if resolved.total_cost_copper is None:
                failed = True
            else:
                total_cost += resolved.total_cost_copper
        unit_cost = int(round(total_cost / recipe.output_quantity)) if not failed else None
        return resolved_reagents, unit_cost

    report_rows: list[dict[str, Any]] = []
    for item_id in sorted(recipes_by_output):
        resolution = analyzer.resolve_item(item_id)
        craft = resolution.cheapest_craft
        sale_price = resolution.market_price_copper
        sale_rate = resolution.sale_rate or 0.0
        if sale_rate < min_sale_rate:
            continue

        if craft is not None:
            selected_recipe = craft.recipe
            selected_inputs = craft.reagents
            craft_cost_copper = craft.unit_cost_copper
        else:
            selected_recipe = recipes_by_output[item_id][0]
            selected_inputs, craft_cost_copper = _resolve_recipe_inputs(selected_recipe)

        sale_net = int(round(sale_price * AH_CUT_FACTOR)) if sale_price is not None else None
        net_profit = (sale_net - craft_cost_copper) if sale_net is not None and craft_cost_copper is not None else None
        margin = (net_profit / craft_cost_copper) if craft_cost_copper and net_profit is not None else None
        liquidity_score = int(round(net_profit * sale_rate)) if net_profit is not None else 0
        ownership = recipe_ownership(
            ownership_index,
            spell_id=selected_recipe.spell_id,
            profession=selected_recipe.profession,
        )
        mastery_multiplier, mastery_branch, mastery_owner = recipe_mastery_bonus(
            selected_recipe.recipe_name,
            selected_recipe.profession,
            recipe_expansion=selected_recipe.expansion,
            known_by=ownership["known_by"],
            mastery_index=mastery_index,
        )
        craft_multiplier = mastery_multiplier

        report_rows.append(
            {
                "item_id": item_id,
                "item_name": resolution.item.item_name,
                "expansion": selected_recipe.expansion,
                "profession": selected_recipe.profession,
                "category": resolution.item.category,
                "recipe_name": selected_recipe.recipe_name,
                "spell_id": selected_recipe.spell_id,
                "recipe_notes": list(selected_recipe.notes),
                "recipe_ownership_status": ownership["status"],
                "recipe_known_by": ownership["known_by"],
                "profession_holders": ownership["profession_holders"],
                "profession_scanned_holders": ownership["profession_scanned_holders"],
                "recipe_owned": recipe_is_owned(ownership),
                "recipe_favorite": selected_recipe.spell_id in favorite_spell_ids if selected_recipe.spell_id is not None else False,
                "sale_price_copper": sale_price,
                "sale_net_after_ah_copper": sale_net,
                "craft_cost_copper": craft_cost_copper,
                "craft_output_multiplier": craft_multiplier if craft_multiplier else 1.0,
                "craft_mastery_branch": mastery_branch,
                "craft_mastery_owner": mastery_owner,
                "net_profit_copper": net_profit,
                "margin_ratio": margin,
                "sale_rate": resolution.sale_rate,
                "avg_daily_sold": resolution.avg_daily_sold,
                "available_quantity": price_rows.get(item_id, {}).get("available_quantity"),
                "liquidity_score_copper": liquidity_score,
                "inputs": [
                    {
                        "label": reagent.label,
                        "quantity": reagent.quantity,
                        "total_cost_copper": reagent.total_cost_copper,
                        "source": reagent.source,
                        "note": reagent.note,
                    }
                    for reagent in selected_inputs
                ],
            }
        )

    apply_balanced_recipe_scores(report_rows)
    report_rows.sort(
        key=lambda row: (
            (row["net_profit_copper"] or 0) > 0,
            row["balanced_score"],
            row["net_profit_copper"] or 0,
            row["sale_rate"] or 0,
            row["avg_daily_sold"] or 0,
        ),
        reverse=True,
    )
    owned_rows = [row for row in report_rows if row["recipe_owned"]]
    visible_rows = owned_rows if owned_only else report_rows

    def _cap(rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
        if top and top > 0:
            return rows[:top]
        return rows

    return {
        "region": region,
        "generated_at": generated_at,
        "ownership_refreshed_at": generated_at,
        "ownership_source": "live-datastore" if ownership_index is not None else "unavailable",
        "ownership_paths": ownership_index.get("paths") if ownership_index else None,
        "owned_only": owned_only,
        "rows": _cap(visible_rows),
        "all_rows": _cap(report_rows),
        "owned_rows": _cap(owned_rows),
        "all_rows_total": len(report_rows),
        "owned_rows_total": len(owned_rows),
    }


def render_recipe_profit_report(report: dict[str, Any]) -> str:
    lines = [
        f"Recipe profitability for region {report['region'].upper()}",
        f"Ownership refresh: {_ownership_refresh_label(report)}",
        "",
    ]
    all_rows = report.get("all_rows", report.get("rows", []))
    owned_rows = report.get("owned_rows", [])
    if report.get("owned_only"):
        lines.append(_section_title("Owned recipes", owned_rows, report.get("owned_rows_total")))
        if not owned_rows:
            lines.append("No locally owned recipe rows matched the current filters")
            return "\n".join(lines)
        _append_recipe_rows(lines, owned_rows)
        return "\n".join(lines).rstrip()

    if not all_rows:
        lines.append("No recipe rows matched the current filters")
        return "\n".join(lines)

    lines.append(_section_title("Global recipes", all_rows, report.get("all_rows_total")))
    _append_recipe_rows(lines, all_rows)
    lines.append("")
    lines.append(_section_title("Owned recipes", owned_rows, report.get("owned_rows_total")))
    if owned_rows:
        _append_recipe_rows(lines, owned_rows)
    else:
        lines.append("No locally owned recipe rows matched the current filters")
    return "\n".join(lines).rstrip()


def _append_recipe_rows(lines: list[str], rows: list[dict[str, Any]]) -> None:
    for row in rows:
        bonus_text = ""
        if (row.get("craft_output_multiplier") or 1.0) > 1.0:
            bonus_text = f" bonus=x{format_number(row.get('craft_output_multiplier') or 1.0)}"
        lines.append(
            (
                f"{row['item_name']} [{row['profession']}/{row['category']}] "
                f"sale={format_copper(row['sale_price_copper'])} "
                f"net={format_copper(row['sale_net_after_ah_copper'])} "
                f"craft={format_copper(row['craft_cost_copper'])}{bonus_text} "
                f"profit={format_copper(row['net_profit_copper'])} "
                f"margin={format_number((row['margin_ratio'] or 0) * 100)}% "
                f"sale_rate={format_number(row['sale_rate'])} "
                f"sold/day={format_number(row['avg_daily_sold'])} "
                f"score={format_number(row['balanced_score'])}"
            )
        )
        recipe_line = f"  - recipe: {row['recipe_name']}"
        if row.get("spell_id") is not None:
            recipe_line += f" | spell={row['spell_id']}"
        lines.append(recipe_line)
        lines.append(f"  - ownership: {_render_recipe_ownership(row)}")
        if row["recipe_notes"]:
            lines.append(f"  - notes: {'; '.join(row['recipe_notes'])}")
        input_bits = []
        for reagent in row["inputs"]:
            cost = format_copper(reagent["total_cost_copper"])
            bit = f"{reagent['label']} x{format_number(reagent['quantity'])}={cost} via {reagent['source']}"
            if reagent["note"]:
                bit += f" ({reagent['note']})"
            input_bits.append(bit)
        lines.append(f"  - inputs: {'; '.join(input_bits)}")
        lines.append("")


def _section_title(label: str, rows: list[dict[str, Any]], total: int | None) -> str:
    if total is None:
        return label
    return f"{label} ({len(rows)}/{total})"


def _ownership_refresh_label(report: dict[str, Any]) -> str:
    return "live DataStore_Crafts read" if report.get("ownership_source") == "live-datastore" else "unavailable"


def _render_recipe_ownership(row: dict[str, Any]) -> str:
    known_by = row.get("recipe_known_by") or []
    status = row.get("recipe_ownership_status")
    if known_by:
        return "known by " + ", ".join(known_by)
    if status == "not_known":
        scanned = row.get("profession_scanned_holders") or []
        return "not known on scanned crafters" + (f" ({', '.join(scanned)})" if scanned else "")
    if status == "unscanned":
        holders = row.get("profession_holders") or []
        return "profession seen but recipes unscanned" + (f" ({', '.join(holders)})" if holders else "")
    if status == "no_profession":
        return "no character with that profession seen locally"
    return "unknown"


def analyze_recipes(region: str, *, top: int = 0, min_sale_rate: float = 0.0) -> dict[str, Any]:
    conn = connect(DB_PATH)
    seed_recipe_items(conn)
    report = build_recipe_profit_report(conn, region, top=top, min_sale_rate=min_sale_rate)
    save_report(report, f"recipe-profitability-{region}.json")
    return report
