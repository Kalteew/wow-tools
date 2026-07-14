from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Any

from wow_tools.cache import HttpCache
from wow_tools.alchemy_mastery import load_character_alchemy_masteries, recipe_mastery_bonus
from wow_tools.config import DB_PATH
from wow_tools.db import connect, latest_prices, upsert_item
from wow_tools.local_recipes import load_recipe_ownership_index, recipe_is_owned, recipe_ownership
from wow_tools.recipe_catalog import MarketProxyOption, default_favorite_spell_ids
from wow_tools.recipe_favorites import ensure_favorite_spell_ids, load_favorite_spell_ids
from wow_tools.recipe_discovery import discover_recipe_graph
from wow_tools.recipe_scoring import apply_balanced_recipe_scores
from wow_tools.reports import format_copper, format_number, save_report
from wow_tools.sources.tsm import sync_prices

VENDOR_COST_OVERRIDES = {
    3371: 100,
    65892: 45_000_000,
    65893: 27_000_000,
    44499: 30_000_000,
    44500: 15_000_000,
    44501: 10_000_000,
}

PROXY_OVERRIDES = {
}

SPECIAL_CURRENCY_REAGENTS = {
    124124: ("Blood of Sargeras", "Illnea Bloodthorn currency cost, no AH proxy"),
}

AH_CUT_FACTOR = 0.95


def _now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


class CycleDetected(RuntimeError):
    pass


@dataclass
class DynamicResolvedReagent:
    item_id: int
    label: str
    quantity: float
    total_cost_copper: int | None
    source: str
    note: str | None = None


@dataclass
class DynamicCraftOption:
    spell_id: int
    recipe_name: str
    unit_cost_copper: int
    reagents: list[DynamicResolvedReagent]
    output_multiplier: float = 1.0


@dataclass
class DynamicItemResolution:
    item_id: int
    item_name: str
    market_price_copper: int | None
    sale_rate: float | None
    avg_daily_sold: float | None
    cheapest_craft: DynamicCraftOption | None
    best_acquisition_copper: int | None
    best_source: str


def _preferred_price(row: dict[str, Any] | None) -> int | None:
    if not row:
        return None
    return (
        row.get("market_value_copper")
        or row.get("region_market_value_avg_copper")
        or row.get("min_buyout_copper")
        or row.get("historical_price_copper")
    )


def _item_name(item: dict[str, Any]) -> str:
    title = item.get("title") or ""
    if " - " in title:
        return title.split(" - ", 1)[0]
    return title or f"Item {item['item_id']}"


def _price_sync_ids(report: dict[str, Any]) -> list[int]:
    item_ids = []
    for item in report["items"]:
        item_id = int(item["item_id"])
        if item_id in VENDOR_COST_OVERRIDES or item_id in PROXY_OVERRIDES:
            continue
        item_ids.append(item_id)
    return sorted(set(item_ids))


def _seed_discovered_items(conn, report: dict[str, Any]) -> int:
    seeded = 0
    for item in report["items"]:
        item_id = int(item["item_id"])
        item_name = _item_name(item)
        upsert_item(
            conn,
            {
                "item_id": item_id,
                "profession": "unknown",
                "expansion_seed": item.get("expansion_detected") or "unknown",
                "expansion_detected": item.get("expansion_detected"),
                "category": "crafted",
                "family_name": item_name,
                "item_name": item_name,
                "wowhead_url": item.get("wowhead_url"),
                "icon_url": None,
                "description": item.get("description"),
                "item_level": None,
                "req_level": None,
                "wowhead_quality": None,
                "wowhead_popularity": None,
                "source_kind": "wowhead-created-by-discovery",
                "is_gatherable": 0,
                "metadata_json": None,
                "last_catalog_sync": "discovered",
            },
        )
        seeded += 1
    conn.commit()
    return seeded


class _DynamicRecipeAnalyzer:
    def __init__(
        self,
        graph: dict[int, dict[str, Any]],
        price_rows: dict[int, dict[str, Any]],
        spell_output_multipliers: dict[int, float],
    ):
        self.graph = graph
        self.price_rows = price_rows
        self.spell_output_multipliers = spell_output_multipliers
        self._memo: dict[int, DynamicItemResolution] = {}
        self._visiting: set[int] = set()

    def resolve_item(self, item_id: int) -> DynamicItemResolution:
        cached = self._memo.get(item_id)
        if cached is not None:
            return cached
        if item_id in self._visiting:
            raise CycleDetected(str(item_id))

        item = self.graph.get(item_id, {"item_id": item_id, "title": f"Item {item_id}", "created_by": []})
        self._visiting.add(item_id)

        price_row = self.price_rows.get(item_id)
        market_price = _preferred_price(price_row)
        sale_rate = price_row.get("region_sale_rate") if price_row else None
        avg_daily_sold = price_row.get("region_avg_daily_sold") if price_row else None

        craft_options: list[DynamicCraftOption] = []
        for spell in item.get("created_by", []):
            reagents = spell.get("reagents")
            creates = spell.get("creates") or [item_id, 1, 1]
            output_qty = float(creates[1] if len(creates) > 1 else 1)
            output_multiplier = self.spell_output_multipliers.get(int(spell["id"]), 1.0)
            effective_output_qty = output_qty * output_multiplier
            if not reagents:
                continue
            resolved_reagents: list[DynamicResolvedReagent] = []
            total_cost = 0
            failed = False
            for reagent_item_id, reagent_qty in reagents:
                try:
                    resolved = self._resolve_reagent(int(reagent_item_id), float(reagent_qty))
                except CycleDetected:
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
                DynamicCraftOption(
                    spell_id=int(spell["id"]),
                    recipe_name=str(spell.get("displayName") or spell.get("name") or f"Spell {spell['id']}"),
                    unit_cost_copper=int(round(total_cost / effective_output_qty)),
                    reagents=resolved_reagents,
                    output_multiplier=output_multiplier,
                )
            )

        cheapest_craft = min(craft_options, key=lambda option: option.unit_cost_copper) if craft_options else None
        best_source = "unavailable"
        best_cost: int | None = None

        if item_id in VENDOR_COST_OVERRIDES:
            best_cost = VENDOR_COST_OVERRIDES[item_id]
            best_source = "vendor"
        elif item_id in PROXY_OVERRIDES:
            proxy_cost = self._best_proxy_cost(item_id)
            if proxy_cost is not None:
                best_cost = proxy_cost
                best_source = "proxy"

        if market_price is not None and (best_cost is None or market_price < best_cost):
            best_cost = market_price
            best_source = "buy"
        if cheapest_craft is not None and (best_cost is None or cheapest_craft.unit_cost_copper < best_cost):
            best_cost = cheapest_craft.unit_cost_copper
            best_source = cheapest_craft.recipe_name

        resolution = DynamicItemResolution(
            item_id=item_id,
            item_name=_item_name(item),
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

    def _best_proxy_cost(self, item_id: int) -> int | None:
        options = PROXY_OVERRIDES.get(item_id, ())
        best: int | None = None
        for option in options:
            row = self.price_rows.get(option.item_id)
            market_price = _preferred_price(row)
            if market_price is None:
                continue
            cost = int(round(market_price * option.quantity))
            if best is None or cost > best:
                best = cost
        return best

    def _resolve_reagent(self, item_id: int, quantity: float) -> DynamicResolvedReagent:
        item = self.graph.get(item_id, {"item_id": item_id, "title": f"Item {item_id}"})
        label = _item_name(item)

        if item_id in SPECIAL_CURRENCY_REAGENTS:
            currency_label, note = SPECIAL_CURRENCY_REAGENTS[item_id]
            return DynamicResolvedReagent(
                item_id=item_id,
                label=currency_label,
                quantity=quantity,
                total_cost_copper=0,
                source="currency",
                note=note,
            )

        if item_id in VENDOR_COST_OVERRIDES:
            return DynamicResolvedReagent(
                item_id=item_id,
                label=label,
                quantity=quantity,
                total_cost_copper=int(round(VENDOR_COST_OVERRIDES[item_id] * quantity)),
                source="vendor",
            )

        if item_id in PROXY_OVERRIDES:
            best_cost = self._best_proxy_cost(item_id)
            best_note = None
            best_source = "proxy-missing"
            if best_cost is not None:
                for option in PROXY_OVERRIDES[item_id]:
                    row = self.price_rows.get(option.item_id)
                    market_price = _preferred_price(row)
                    if market_price is None:
                        continue
                    cost = int(round(market_price * option.quantity))
                    if cost == best_cost:
                        best_note = option.note
                        best_source = f"proxy:{_item_name(self.graph[option.item_id])}"
                        break
            return DynamicResolvedReagent(
                item_id=item_id,
                label=label,
                quantity=quantity,
                total_cost_copper=int(round(best_cost * quantity)) if best_cost is not None else None,
                source=best_source,
                note=best_note,
            )

        resolution = self.resolve_item(item_id)
        total_cost = None
        if resolution.best_acquisition_copper is not None:
            total_cost = int(round(resolution.best_acquisition_copper * quantity))
        return DynamicResolvedReagent(
            item_id=item_id,
            label=label,
            quantity=quantity,
            total_cost_copper=total_cost,
            source=resolution.best_source,
        )


def sync_discovered_prices(
    cache: HttpCache,
    region: str,
    *,
    item_ids: list[int],
    force: bool = False,
    max_depth: int = 4,
) -> dict[str, Any]:
    report = discover_recipe_graph(cache, item_ids=item_ids, force=force, max_depth=max_depth)
    conn = connect(DB_PATH)
    seeded = _seed_discovered_items(conn, report)
    ids = _price_sync_ids(report)
    summary = sync_prices(conn, cache, region, force=force, item_ids=ids)
    summary["seeded"] = seeded
    summary["discovered_items"] = len(report["items"])
    summary["priceable_items"] = len(ids)
    summary["report"] = report
    return summary


def build_discovered_profit_report(
    cache: HttpCache,
    region: str,
    *,
    item_ids: list[int],
    force: bool = False,
    max_depth: int = 4,
    top: int = 20,
    min_sale_rate: float = 0.0,
    sync: bool = False,
    owned_only: bool = False,
    retail_root: str | None = None,
    account_root: str | None = None,
) -> dict[str, Any]:
    generated_at = _now_iso()
    report = discover_recipe_graph(cache, item_ids=item_ids, force=force, max_depth=max_depth)
    if sync:
        conn = connect(DB_PATH)
        _seed_discovered_items(conn, report)
        sync_prices(conn, cache, region, force=force, item_ids=_price_sync_ids(report))

    conn = connect(DB_PATH)
    _seed_discovered_items(conn, report)
    rows = [dict(row) for row in latest_prices(conn, region)]
    price_rows = {row["item_id"]: row for row in rows}
    profession_by_spell_id = {
        int(row["spell_id"]): row["profession"]
        for row in conn.execute("SELECT spell_id, profession FROM profession_recipes")
    }
    graph = {int(item["item_id"]): item for item in report["items"]}
    try:
        # Ownership is refreshed from local SavedVariables on every analysis run.
        ownership_index = load_recipe_ownership_index(retail_root, account_root)
    except FileNotFoundError:
        ownership_index = None
    mastery_index = load_character_alchemy_masteries(retail_root, account_root)
    ensure_favorite_spell_ids(conn, default_favorite_spell_ids())
    favorite_spell_ids = load_favorite_spell_ids(conn)

    spell_output_multipliers: dict[int, float] = {}
    for item in report["items"]:
        for spell in item.get("created_by", []):
            spell_id = int(spell["id"])
            profession = profession_by_spell_id.get(spell_id)
            ownership = recipe_ownership(
                ownership_index,
                spell_id=spell_id,
                profession=profession,
            )
            multiplier, _, _ = recipe_mastery_bonus(
                str(spell.get("displayName") or spell.get("name") or f"Spell {spell_id}"),
                profession,
                recipe_expansion=item.get("expansion_detected"),
                known_by=ownership["known_by"],
                mastery_index=mastery_index,
            )
            if multiplier != 1.0:
                spell_output_multipliers[spell_id] = multiplier

    analyzer = _DynamicRecipeAnalyzer(graph, price_rows, spell_output_multipliers)

    result_rows: list[dict[str, Any]] = []
    for item_id in item_ids:
        if item_id not in graph:
            continue
        resolution = analyzer.resolve_item(item_id)
        craft = resolution.cheapest_craft
        sale_price = resolution.market_price_copper
        sale_rate = resolution.sale_rate or 0.0
        if craft is None or sale_rate < min_sale_rate:
            continue
        sale_net = int(round(sale_price * AH_CUT_FACTOR)) if sale_price is not None else None
        net_profit = (sale_net - craft.unit_cost_copper) if sale_net is not None else None
        margin = (net_profit / craft.unit_cost_copper) if craft.unit_cost_copper and net_profit is not None else None
        liquidity_score = int(round(net_profit * sale_rate)) if net_profit is not None else 0
        ownership = recipe_ownership(
            ownership_index,
            spell_id=craft.spell_id,
            profession=profession_by_spell_id.get(craft.spell_id),
        )
        mastery_multiplier, mastery_branch, mastery_owner = recipe_mastery_bonus(
            craft.recipe_name,
            profession_by_spell_id.get(craft.spell_id),
            recipe_expansion=graph.get(item_id, {}).get("expansion_detected"),
            known_by=ownership["known_by"],
            mastery_index=mastery_index,
        )
        result_rows.append(
            {
                "item_id": item_id,
                "item_name": resolution.item_name,
                "spell_id": craft.spell_id,
                "sale_price_copper": sale_price,
                "sale_net_after_ah_copper": sale_net,
                "craft_cost_copper": craft.unit_cost_copper,
                "craft_output_multiplier": mastery_multiplier if mastery_multiplier else 1.0,
                "craft_mastery_branch": mastery_branch,
                "craft_mastery_owner": mastery_owner,
                "net_profit_copper": net_profit,
                "margin_ratio": margin,
                "sale_rate": resolution.sale_rate,
                "avg_daily_sold": resolution.avg_daily_sold,
                "best_recipe_name": craft.recipe_name,
                "recipe_ownership_status": ownership["status"],
                "recipe_known_by": ownership["known_by"],
                "profession_holders": ownership["profession_holders"],
                "profession_scanned_holders": ownership["profession_scanned_holders"],
                "recipe_owned": recipe_is_owned(ownership),
                "recipe_favorite": craft.spell_id in favorite_spell_ids,
                "inputs": [
                    {
                        "item_id": reagent.item_id,
                        "label": reagent.label,
                        "quantity": reagent.quantity,
                        "total_cost_copper": reagent.total_cost_copper,
                        "source": reagent.source,
                        "note": reagent.note,
                    }
                    for reagent in craft.reagents
                ],
                "liquidity_score_copper": liquidity_score,
            }
        )

    apply_balanced_recipe_scores(result_rows)
    result_rows.sort(
        key=lambda row: (
            (row["net_profit_copper"] or 0) > 0,
            row["balanced_score"],
            row["net_profit_copper"] or 0,
            row["sale_rate"] or 0,
            row["avg_daily_sold"] or 0,
        ),
        reverse=True,
    )
    owned_rows = [row for row in result_rows if row["recipe_owned"]]
    visible_rows = owned_rows if owned_only else result_rows
    return {
        "region": region,
        "roots": item_ids,
        "max_depth": max_depth,
        "generated_at": generated_at,
        "ownership_refreshed_at": generated_at,
        "ownership_source": "live-datastore" if ownership_index is not None else "unavailable",
        "ownership_paths": ownership_index.get("paths") if ownership_index else None,
        "owned_only": owned_only,
        "rows": visible_rows[:top],
        "all_rows": result_rows[:top],
        "owned_rows": owned_rows[:top],
        "all_rows_total": len(result_rows),
        "owned_rows_total": len(owned_rows),
    }


def render_discovered_profit_report(report: dict[str, Any]) -> str:
    lines = [
        f"Discovered recipe profitability for region {report['region'].upper()}",
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
        _append_discovered_rows(lines, owned_rows)
        return "\n".join(lines).rstrip()

    if not all_rows:
        lines.append("No recipe rows matched the current filters")
        return "\n".join(lines)

    lines.append(_section_title("Global recipes", all_rows, report.get("all_rows_total")))
    _append_discovered_rows(lines, all_rows)
    lines.append("")
    lines.append(_section_title("Owned recipes", owned_rows, report.get("owned_rows_total")))
    if owned_rows:
        _append_discovered_rows(lines, owned_rows)
    else:
        lines.append("No locally owned recipe rows matched the current filters")
    return "\n".join(lines).rstrip()


def _append_discovered_rows(lines: list[str], rows: list[dict[str, Any]]) -> None:
    for row in rows:
        bonus_text = ""
        if (row.get("craft_output_multiplier") or 1.0) > 1.0:
            bonus_text = f" bonus=x{format_number(row.get('craft_output_multiplier') or 1.0)}"
        lines.append(
            (
                f"{row['item_name']} "
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
        lines.append(f"  - recipe: {row['best_recipe_name']} | spell={row['spell_id']}")
        lines.append(f"  - ownership: {_render_recipe_ownership(row)}")
        bits = []
        for reagent in row["inputs"]:
            bit = (
                f"{reagent['label']} x{format_number(reagent['quantity'])}="
                f"{format_copper(reagent['total_cost_copper'])} via {reagent['source']}"
            )
            if reagent["note"]:
                bit += f" ({reagent['note']})"
            bits.append(bit)
        lines.append(f"  - inputs: {'; '.join(bits)}")
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


def save_discovered_profit_report(report: dict[str, Any], label: str) -> str:
    path = save_report(report, f"discovered-profitability-{label}.json")
    return str(path)
