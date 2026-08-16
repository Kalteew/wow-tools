#!/usr/bin/env python3
"""Build the daily Yayag / Yaya Market Reset snapshot.

The script only reads WoW and TSM files. It writes a compact JSON snapshot and
Markdown summary so the morning assistant can consume prepared data instead of
re-parsing the full SavedVariables files.
"""

from __future__ import annotations

import argparse
import csv
import io
import json
import sqlite3
import sys
from collections import defaultdict, deque
from datetime import date, datetime, timedelta
from pathlib import Path
from typing import Any


REPO_ROOT = Path(__file__).resolve().parents[2]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from wow_tools.account_pipeline import load_local_price_index  # noqa: E402
from wow_tools.config import REPORT_DIR  # noqa: E402
from wow_tools.local_account import format_timestamp, load_tsm_status, resolve_paths  # noqa: E402
from wow_tools.lua_table import parse_lua_assignments  # noqa: E402


DEFAULT_RETAIL_ROOT = Path(r"C:\Program Files (x86)\World of Warcraft\_retail_")
DEFAULT_ACCOUNT_ROOT = DEFAULT_RETAIL_ROOT / "WTF" / "Account" / "417185157#1"
DEFAULT_ITEM_DB = REPO_ROOT / "data" / "wow.sqlite3"
PLAYER = "Yayag"
REALM = "Hyjal"
REGION = "EU"
COMMISSION = 0.05
BASE_CAPITAL_GOLD = 100_000
BAGS_INVESTMENT_GOLD = 1_000
REGION_DEMAND_HAIRCUT = 0.50
YAYA_MARKET_SHARE = 15.0


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Prépare le snapshot quotidien de Yayag.")
    parser.add_argument("--report-date", type=date.fromisoformat, help="Date de la veille au format YYYY-MM-DD.")
    parser.add_argument("--retail-root", type=Path, default=DEFAULT_RETAIL_ROOT)
    parser.add_argument("--account-root", type=Path, default=DEFAULT_ACCOUNT_ROOT)
    parser.add_argument("--item-db", type=Path, default=DEFAULT_ITEM_DB)
    parser.add_argument("--output-dir", type=Path, default=REPORT_DIR)
    parser.add_argument("--commission", type=float, default=COMMISSION)
    parser.add_argument("--market-share", type=float, default=YAYA_MARKET_SHARE)
    parser.add_argument("--demand-haircut", type=float, default=REGION_DEMAND_HAIRCUT)
    parser.add_argument("--base-capital", type=float, default=BASE_CAPITAL_GOLD)
    parser.add_argument("--bags-investment", type=float, default=BAGS_INVESTMENT_GOLD)
    parser.add_argument("--print-only", action="store_true", help="N'écrit pas les fichiers de sortie.")
    parser.add_argument("--quiet", action="store_true", help="N'imprime pas le Markdown final.")
    return parser.parse_args()


def local_datetime(timestamp: int | float | None) -> datetime | None:
    if not timestamp:
        return None
    return datetime.fromtimestamp(float(timestamp)).astimezone()


def parse_int(value: Any, default: int = 0) -> int:
    try:
        return int(value)
    except (TypeError, ValueError):
        return default


def gold(copper: int | float | None) -> float | None:
    if copper is None:
        return None
    return round(float(copper) / 10_000, 2)


def fmt_gold(copper: int | float | None) -> str:
    value = gold(copper)
    return "n/d" if value is None else f"{value:,.2f} po".replace(",", " ")


def fmt_qty(value: int | float | None) -> str:
    return "n/d" if value is None else f"{int(value):,}".replace(",", " ")


def fmt_pct(value: float | None) -> str:
    return "n/d" if value is None else f"{value * 100:.2f}%"


def item_id_from_string(item_string: str) -> int | None:
    head = item_string.removeprefix("i:").split(":", 1)[0]
    return int(head) if head.isdigit() else None


def normalize_item_string(value: str) -> str:
    return value if value.startswith("i:") else f"i:{value}"


def load_tsm_database(path: Path) -> dict[str, Any]:
    if not path.exists():
        raise FileNotFoundError(f"TSM SavedVariables introuvable : {path}")
    assignments = parse_lua_assignments(path.read_text(encoding="utf-8", errors="replace"))
    database = assignments.get("TradeSkillMasterDB")
    if not isinstance(database, dict):
        raise ValueError("TradeSkillMasterDB absent ou invalide")
    return database


def load_item_names(path: Path, item_ids: set[int]) -> dict[int, str]:
    if not item_ids or not path.exists():
        return {}
    names: dict[int, str] = {}
    connection = sqlite3.connect(path)
    try:
        placeholders = ",".join("?" for _ in item_ids)
        query = f"SELECT item_id, item_name FROM auction_catalog WHERE item_id IN ({placeholders})"
        for item_id, name in connection.execute(query, tuple(sorted(item_ids))):
            names[int(item_id)] = str(name)
    finally:
        connection.close()
    return names


def parse_tsm_csv(database: dict[str, Any], key: str, player: str = PLAYER) -> list[dict[str, Any]]:
    raw = database.get(f"r@{REALM}@internalData@{key}", "")
    if not isinstance(raw, str):
        return []
    rows: list[dict[str, Any]] = []
    for row in csv.DictReader(io.StringIO(raw)):
        if row.get("player") != player:
            continue
        item_string = normalize_item_string(str(row.get("itemString", ""))) if row.get("itemString") else ""
        timestamp = parse_int(row.get("time"))
        if not item_string or not timestamp:
            continue
        quantity = parse_int(row.get("quantity"))
        price = parse_int(row.get("price"))
        rows.append(
            {
                "item_string": item_string,
                "item_id": item_id_from_string(item_string),
                "quantity": quantity,
                "unit_price_copper": price,
                "total_copper": quantity * price,
                "stack_size": parse_int(row.get("stackSize")),
                "time": timestamp,
                "time_local": local_datetime(timestamp).isoformat() if local_datetime(timestamp) else None,
                "source": row.get("source"),
                "other_player": row.get("otherPlayer"),
            }
        )
    return rows


def parse_tsm_event_csv(database: dict[str, Any], key: str, player: str = PLAYER) -> list[dict[str, Any]]:
    raw = database.get(f"r@{REALM}@internalData@{key}", "")
    if not isinstance(raw, str):
        return []
    rows: list[dict[str, Any]] = []
    for row in csv.DictReader(io.StringIO(raw)):
        if row.get("player") != player:
            continue
        timestamp = parse_int(row.get("time"))
        if not timestamp:
            continue
        rows.append(
            {
                "item_string": normalize_item_string(str(row.get("itemString", ""))) if row.get("itemString") else None,
                "item_id": item_id_from_string(str(row.get("itemString", ""))) if row.get("itemString") else None,
                "quantity": parse_int(row.get("quantity")),
                "time": timestamp,
                "time_local": local_datetime(timestamp).isoformat() if local_datetime(timestamp) else None,
            }
        )
    return rows


def parse_money_csv(database: dict[str, Any], key: str, report_date: date) -> list[dict[str, Any]]:
    raw = database.get(f"r@{REALM}@internalData@{key}", "")
    if not isinstance(raw, str):
        return []
    rows: list[dict[str, Any]] = []
    for row in csv.DictReader(io.StringIO(raw)):
        timestamp = parse_int(row.get("time"))
        when = local_datetime(timestamp)
        if row.get("player") != PLAYER or not when or when.date() != report_date:
            continue
        rows.append(
            {
                "type": row.get("type"),
                "amount_copper": parse_int(row.get("amount")),
                "other_player": row.get("otherPlayer"),
                "time": timestamp,
                "time_local": when.isoformat(),
            }
        )
    return rows


def daily_rows(rows: list[dict[str, Any]], report_date: date) -> list[dict[str, Any]]:
    return [row for row in rows if (local_datetime(row.get("time")) or datetime.min.astimezone()).date() == report_date]


def summarize_transactions(
    buys: list[dict[str, Any]],
    sales: list[dict[str, Any]],
    report_date: date,
    commission: float,
) -> tuple[dict[str, Any], dict[str, Any], dict[str, deque[list[int]]]]:
    all_events = [(row["time"], 0, "buy", row) for row in buys] + [(row["time"], 1, "sale", row) for row in sales]
    all_events.sort(key=lambda event: (event[0], event[1]))
    queues: dict[str, deque[list[int]]] = defaultdict(deque)
    sale_costs: dict[int, tuple[int, int]] = {}

    for _, _, event_type, row in all_events:
        item_queue = queues[row["item_string"]]
        if event_type == "buy":
            item_queue.append([row["quantity"], row["unit_price_copper"]])
            continue
        remaining = row["quantity"]
        known_cost = 0
        while remaining and item_queue:
            lot_quantity, unit_cost = item_queue[0]
            used = min(remaining, lot_quantity)
            known_cost += used * unit_cost
            remaining -= used
            lot_quantity -= used
            if lot_quantity:
                item_queue[0][0] = lot_quantity
            else:
                item_queue.popleft()
        if local_datetime(row["time"]) and local_datetime(row["time"]).date() == report_date:
            sale_costs[id(row)] = (known_cost, remaining)

    def aggregate(rows: list[dict[str, Any]], kind: str) -> dict[str, Any]:
        selected = daily_rows(rows, report_date)
        by_item: dict[str, dict[str, Any]] = {}
        for row in selected:
            entry = by_item.setdefault(
                row["item_string"],
                {
                    "item_id": row["item_id"],
                    "quantity": 0,
                    "total_copper": 0,
                    "records": 0,
                    "unit_cost_copper": None,
                    "known_cost_copper": 0,
                    "unknown_quantity": 0,
                },
            )
            entry["quantity"] += row["quantity"]
            entry["total_copper"] += row["total_copper"]
            entry["records"] += 1
            if kind == "sale":
                known_cost, unknown_quantity = sale_costs.get(id(row), (0, row["quantity"]))
                entry["known_cost_copper"] += known_cost
                entry["unknown_quantity"] += unknown_quantity
        for entry in by_item.values():
            if entry["quantity"]:
                entry["unit_cost_copper"] = round(entry["total_copper"] / entry["quantity"], 2)
        return {
            "records": len(selected),
            "quantity": sum(row["quantity"] for row in selected),
            "total_copper": sum(row["total_copper"] for row in selected),
            "by_item": by_item,
        }

    purchases = aggregate(buys, "buy")
    sales_summary = aggregate(sales, "sale")
    sales_summary["net_after_commission_copper"] = round(sales_summary["total_copper"] * (1 - commission))
    sales_summary["known_cost_copper"] = sum(row["known_cost_copper"] for row in sales_summary["by_item"].values())
    sales_summary["unknown_quantity"] = sum(row["unknown_quantity"] for row in sales_summary["by_item"].values())
    sales_summary["realized_profit_after_commission_copper"] = (
        sales_summary["net_after_commission_copper"] - sales_summary["known_cost_copper"]
    )
    return purchases, sales_summary, queues


def current_costs(queues: dict[str, deque[list[int]]], holdings: dict[str, int]) -> dict[str, dict[str, Any]]:
    costs: dict[str, dict[str, Any]] = {}
    for item_string, quantity in holdings.items():
        remaining = quantity
        known_quantity = 0
        known_cost = 0
        for lot_quantity, unit_cost in queues.get(item_string, deque()):
            if remaining <= 0:
                break
            used = min(remaining, lot_quantity)
            known_quantity += used
            known_cost += used * unit_cost
            remaining -= used
        costs[item_string] = {
            "known_quantity": known_quantity,
            "known_cost_copper": known_cost,
            "unknown_quantity": max(0, quantity - known_quantity),
        }
    return costs


def load_holdings(database: dict[str, Any]) -> tuple[dict[str, dict[str, int]], dict[str, int]]:
    prefix = f"s@{PLAYER} - Horde - {REALM}@internalData@"
    locations: dict[str, dict[str, int]] = {}
    for location, suffix in (("bags", "bagQuantity"), ("auctions", "auctionQuantity"), ("bank", "bankQuantity"), ("mail", "mailQuantity")):
        raw = database.get(prefix + suffix, {})
        values = raw if isinstance(raw, dict) else {}
        locations[location] = {normalize_item_string(str(key)): parse_int(value) for key, value in values.items() if parse_int(value) > 0}
    combined: dict[str, int] = defaultdict(int)
    for values in locations.values():
        for item_string, quantity in values.items():
            combined[item_string] += quantity
    return locations, dict(combined)


def load_reset_settings(account_root: Path) -> dict[str, Any]:
    path = account_root / "SavedVariables" / "YayaReagentSniper.lua"
    if not path.exists():
        return {"exists": False, "path": str(path)}
    assignments = parse_lua_assignments(path.read_text(encoding="utf-8", errors="replace"))
    database = assignments.get("YayaReagentSniperDB", {})
    reset = database.get("reset", {}) if isinstance(database, dict) else {}
    fields = ("minROI", "minProfitGold", "maxDays", "marketShare", "maxTargetPct", "budgetGold", "minScore", "expansion", "continuous")
    return {
        "exists": True,
        "path": str(path),
        **{field: reset.get(field) for field in fields},
    }


def price_details(price_record: dict[str, Any] | None, item_string: str) -> dict[str, Any]:
    datasets = (price_record or {}).get("datasets", {})
    commodity_data = datasets.get("AUCTIONDB_COMMODITY_DATA", {})
    commodity_scan = datasets.get("AUCTIONDB_COMMODITY_SCAN_STAT", {})
    noncommodity_data = datasets.get("AUCTIONDB_NON_COMMODITY_DATA", {})
    noncommodity_scan = datasets.get("AUCTIONDB_NON_COMMODITY_SCAN_STAT", {})
    region_sale = datasets.get("AUCTIONDB_REGION_SALE", {})

    is_commodity = bool(commodity_data or commodity_scan)
    market_dataset = commodity_scan if is_commodity else noncommodity_scan
    fallback_dataset = commodity_data if is_commodity else noncommodity_data
    market_values = market_dataset.get("values", {})
    fallback_values = fallback_dataset.get("values", {})
    market_value = market_values.get("marketValue") or fallback_values.get("marketValueRecent")
    min_buyout = fallback_values.get("minBuyout")
    sale_values = region_sale.get("values", {})
    sold_per_day_raw = sale_values.get("regionSoldPerDay")
    sale_percent_raw = sale_values.get("regionSalePercent")
    sold_per_day = round(sold_per_day_raw / 100, 2) if isinstance(sold_per_day_raw, (int, float)) else None
    sale_rate = round(sale_percent_raw / 10_000, 4) if isinstance(sale_percent_raw, (int, float)) else None
    source_dataset = "marketValue" if market_values.get("marketValue") else "marketValueRecent"
    scope = (market_dataset or fallback_dataset or region_sale).get("scope")
    freshness = {}
    for tag, dataset in (datasets or {}).items():
        freshness[tag] = dataset.get("download_time")
    return {
        "item_string": item_string,
        "region_scope": scope,
        "is_commodity": is_commodity,
        "market_value_copper": market_value,
        "market_value_source": source_dataset if market_value is not None else None,
        "min_buyout_copper": min_buyout,
        "region_sale_rate": sale_rate,
        "region_sold_per_day": sold_per_day,
        "region_sold_per_day_raw": sold_per_day_raw,
        "region_sale_percent_raw": sale_percent_raw,
        "freshness": freshness,
    }


def build_item_rows(
    holdings_by_location: dict[str, dict[str, int]],
    holdings: dict[str, int],
    costs: dict[str, dict[str, Any]],
    prices: dict[int, dict[str, Any]],
    names: dict[int, str],
    market_share: float,
    demand_haircut: float,
    commission: float,
) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for item_string, quantity in holdings.items():
        item_id = item_id_from_string(item_string)
        details = price_details(prices.get(item_id), item_string)
        market_value = details["market_value_copper"]
        gross_value = market_value * quantity if market_value is not None else None
        after_fee_value = round(gross_value * (1 - commission)) if gross_value is not None else None
        cost = costs.get(item_string, {})
        known_cost = cost.get("known_cost_copper", 0)
        latent = after_fee_value - known_cost if after_fee_value is not None and cost.get("known_quantity", 0) else None
        sold_per_day = details.get("region_sold_per_day")
        effective_daily = sold_per_day * demand_haircut * market_share / 100 if sold_per_day else None
        horizon = quantity / effective_daily if effective_daily else None
        rows.append(
            {
                "item_id": item_id,
                "item_string": item_string,
                "name": names.get(item_id or 0, f"Item {item_id or item_string}"),
                "quantity": quantity,
                "bags_quantity": holdings_by_location.get("bags", {}).get(item_string, 0),
                "bank_quantity": holdings_by_location.get("bank", {}).get(item_string, 0),
                "mail_quantity": holdings_by_location.get("mail", {}).get(item_string, 0),
                "auction_quantity": holdings_by_location.get("auctions", {}).get(item_string, 0),
                "market": details,
                "gross_value_copper": gross_value,
                "after_fee_value_copper": after_fee_value,
                "known_cost_copper": known_cost if cost.get("known_quantity", 0) else None,
                "known_cost_quantity": cost.get("known_quantity", 0),
                "unknown_cost_quantity": cost.get("unknown_quantity", quantity),
                "latent_after_fee_copper": latent,
                "adjusted_horizon_days": round(horizon, 1) if horizon is not None else None,
                "effective_daily_demand": round(effective_daily, 2) if effective_daily is not None else None,
            }
        )
    return sorted(rows, key=lambda row: row["gross_value_copper"] or 0, reverse=True)


def transfer_summary(database: dict[str, Any], report_date: date) -> dict[str, Any]:
    incomes = parse_money_csv(database, "csvIncome", report_date)
    expenses = parse_money_csv(database, "csvExpense", report_date)
    return {
        "income": incomes,
        "expense": expenses,
        "income_copper": sum(row["amount_copper"] for row in incomes),
        "expense_copper": sum(row["amount_copper"] for row in expenses),
        "net_copper": sum(row["amount_copper"] for row in incomes) - sum(row["amount_copper"] for row in expenses),
    }


def summarize_freshness(appdata_status: dict[str, Any], saved_variables: Path, sniper_path: Path) -> dict[str, Any]:
    return {
        "appdata_file_modified": appdata_status.get("file_modified"),
        "appdata_file_modified_ts": appdata_status.get("file_modified_ts"),
        "tsm_app_sync": (appdata_status.get("app_info") or {}).get("last_sync"),
        "tsm_app_sync_ts": (appdata_status.get("app_info") or {}).get("last_sync_ts"),
        "datasets": appdata_status.get("datasets", []),
        "trade_skill_master_file_modified": format_timestamp(saved_variables.stat().st_mtime) if saved_variables.exists() else None,
        "yaya_reset_file_modified": format_timestamp(sniper_path.stat().st_mtime) if sniper_path.exists() else None,
    }


def load_previous_state(path: Path, report_date: str) -> dict[str, Any] | None:
    if not path.exists():
        return None
    try:
        state = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return None
    current = state.get("current") or {}
    previous = state.get("previous")
    if current.get("report_date") == report_date:
        if isinstance(previous, dict) and previous.get("report_date") != report_date:
            return previous
        fallback_path = path.parent / f"yayag-market-reset-{(date.fromisoformat(report_date) - timedelta(days=1)).isoformat()}.json"
        try:
            fallback = json.loads(fallback_path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            return None
        return {"report_date": fallback.get("report_date"), "capital": fallback.get("capital", {})}
    return current


def build_report(args: argparse.Namespace) -> dict[str, Any]:
    paths = resolve_paths(args.retail_root, args.account_root)
    account_root = Path(paths["account_root"])
    saved_variables = account_root / "SavedVariables"
    tsm_path = saved_variables / "TradeSkillMaster.lua"
    sniper_path = saved_variables / "YayaReagentSniper.lua"
    database = load_tsm_database(tsm_path)
    report_date = args.report_date or (datetime.now().astimezone().date() - timedelta(days=1))

    buys = [row for row in parse_tsm_csv(database, "csvBuys") if row.get("source") == "Auction"]
    sales = [row for row in parse_tsm_csv(database, "csvSales") if row.get("source") == "Auction"]
    cancelled = parse_tsm_event_csv(database, "csvCancelled")
    expired = parse_tsm_event_csv(database, "csvExpired")
    purchases, sales_summary, queues = summarize_transactions(buys, sales, report_date, args.commission)
    locations, holdings = load_holdings(database)
    costs = current_costs(queues, holdings)
    item_ids = {item_id for item_id in (item_id_from_string(value) for value in holdings) if item_id is not None}
    item_ids.update(row["item_id"] for row in daily_rows(buys + sales, report_date) if row.get("item_id") is not None)
    names = load_item_names(args.item_db, item_ids)
    price_index = load_local_price_index(sorted(item_ids), args.retail_root, args.account_root)
    item_rows = build_item_rows(
        locations,
        holdings,
        costs,
        price_index,
        names,
        args.market_share,
        args.demand_haircut,
        args.commission,
    )

    cash_copper = parse_int(database.get(f"s@{PLAYER} - Horde - {REALM}@internalData@money"))
    stock_rows = [row for row in item_rows if row["bags_quantity"] or row["bank_quantity"] or row["mail_quantity"]]
    auction_rows = [row for row in item_rows if row["auction_quantity"]]
    stock_gross = sum(row["gross_value_copper"] or 0 for row in stock_rows)
    auction_gross = sum(row["gross_value_copper"] or 0 for row in auction_rows)
    holdings_gross = stock_gross + auction_gross
    holdings_after_fee = round(holdings_gross * (1 - args.commission))
    total_gross = cash_copper + holdings_gross
    total_after_fee = cash_copper + holdings_after_fee
    known_latent = sum(row["latent_after_fee_copper"] or 0 for row in item_rows)
    known_current_cost = sum(row["known_cost_copper"] or 0 for row in item_rows)
    unknown_current_quantity = sum(row["unknown_cost_quantity"] for row in item_rows)
    daily_cancelled = daily_rows(cancelled, report_date)
    daily_expired = daily_rows(expired, report_date)
    transfers = transfer_summary(database, report_date)
    reset_settings = load_reset_settings(account_root)

    appdata_status = load_tsm_status(paths["tsm_appdata"])
    freshness = summarize_freshness(appdata_status, tsm_path, sniper_path)
    signature = "|".join(
        [
            str(tsm_path.stat().st_mtime_ns),
            str(Path(paths["tsm_appdata"]).stat().st_mtime_ns),
            str(cash_copper),
            str(total_gross),
        ]
    )
    state_path = args.output_dir / "yayag-market-reset-state.json"
    previous = load_previous_state(state_path, report_date.isoformat())
    previous_total = previous.get("capital", {}).get("total_gross_copper") if previous else None

    concentration = None
    if holdings_gross:
        concentration = sum(row["gross_value_copper"] or 0 for row in item_rows[:5]) / holdings_gross
    net_reinvestment = purchases["total_copper"] - sales_summary["net_after_commission_copper"]
    known_return = None
    if sales_summary["known_cost_copper"]:
        known_return = sales_summary["realized_profit_after_commission_copper"] / sales_summary["known_cost_copper"]

    slow_rows = [
        row
        for row in item_rows
        if row["auction_quantity"] and row["adjusted_horizon_days"] is not None and row["adjusted_horizon_days"] > 3
    ]
    slow_rows.sort(key=lambda row: (row["adjusted_horizon_days"] or 0, row["gross_value_copper"] or 0), reverse=True)
    negative_rows = [row for row in item_rows if (row["latent_after_fee_copper"] or 0) < -10_000]
    missing_price_qty = sum(row["quantity"] for row in item_rows if row["gross_value_copper"] is None)
    anomalies: list[str] = []
    if not buys and not sales and not cancelled and not expired:
        anomalies.append("Aucune opération du jour dans le Ledger TSM : l’absence de ligne ne prouve pas l’absence de transaction tant que courrier/TSM n’ont pas été récupérés et sauvegardés.")
    if transfers["net_copper"]:
        anomalies.append(f"Flux hors marché détecté : transferts/flux nets de {fmt_gold(transfers['net_copper'])} vers Yayag (à séparer du résultat commercial).")
    if daily_expired:
        anomalies.append(f"{fmt_qty(sum(row['quantity'] for row in daily_expired))} unités expirées hier : signal de rotation insuffisante ou de prix de sortie trop haut.")
    if missing_price_qty:
        anomalies.append(f"{fmt_qty(missing_price_qty)} unités sans valeur TSM locale : valeur globale sous-estimée.")
    if unknown_current_quantity:
        anomalies.append(f"Coût d’acquisition inconnu pour {fmt_qty(unknown_current_quantity)} unités : latent partiel seulement.")
    if negative_rows:
        anomalies.append("Certaines positions sont latentes négatives après 5 % de commission : ne pas attendre le marketValue pour les considérer saines.")

    return {
        "schema_version": 1,
        "generated_at": datetime.now().astimezone().isoformat(),
        "report_date": report_date.isoformat(),
        "scope": {"player": PLAYER, "realm": REALM, "region": REGION},
        "sources": {
            "trade_skill_master": str(tsm_path),
            "appdata": paths["tsm_appdata"],
            "reset_settings": str(sniper_path),
            "item_catalog": str(args.item_db),
        },
        "item_names": {str(item_id): name for item_id, name in names.items()},
        "parameters": {
            "commission": args.commission,
            "market_share": args.market_share,
            "region_demand_haircut": args.demand_haircut,
            "base_capital_gold": args.base_capital,
            "bags_investment_gold": args.bags_investment,
        },
        "capital": {
            "cash_copper": cash_copper,
            "stock_gross_copper": stock_gross,
            "auction_gross_copper": auction_gross,
            "holdings_gross_copper": holdings_gross,
            "holdings_after_fee_copper": holdings_after_fee,
            "total_gross_copper": total_gross,
            "total_after_fee_copper": total_after_fee,
            "previous_total_gross_copper": previous_total,
            "change_vs_previous_gross_copper": total_gross - previous_total if previous_total is not None else None,
            "growth_vs_base_copper": total_gross - round(args.base_capital * 10_000),
            "cash_ratio": cash_copper / total_gross if total_gross else None,
            "top5_concentration": concentration,
        },
        "reinvestment": {
            "purchases": purchases,
            "sales": sales_summary,
            "net_reinvestment_copper": net_reinvestment,
            "purchases_pct_previous_capital": purchases["total_copper"] / previous_total if previous_total else None,
            "purchase_to_net_sales_ratio": purchases["total_copper"] / sales_summary["net_after_commission_copper"] if sales_summary["net_after_commission_copper"] else None,
        },
        "rotation": {
            "cancelled_records": len(daily_rows(cancelled, report_date)),
            "cancelled_quantity": sum(row["quantity"] for row in daily_rows(cancelled, report_date)),
            "expired_records": len(daily_expired),
            "expired_quantity": sum(row["quantity"] for row in daily_expired),
            "auction_quantity": sum(row["quantity"] for row in auction_rows),
            "stock_quantity": sum(row["quantity"] for row in stock_rows),
            "unknown_age": True,
            "slow_items": slow_rows[:10],
        },
        "result": {
            "realized_profit_after_commission_copper": sales_summary["realized_profit_after_commission_copper"],
            "realized_return_on_known_cost": known_return,
            "latent_profit_after_fee_copper": known_latent,
            "known_current_cost_copper": known_current_cost,
            "unknown_current_cost_quantity": unknown_current_quantity,
        },
        "transfers": transfers,
        "holdings": {"items": item_rows, "stock": stock_rows, "auctions": auction_rows},
        "reset_settings": reset_settings,
        "freshness": freshness,
        "anomalies": anomalies,
        "signature": signature,
        "previous_state": previous,
    }


def item_line(row: dict[str, Any], value_key: str = "gross_value_copper") -> str:
    market = row.get("market", {})
    rate = fmt_pct(market.get("region_sale_rate"))
    horizon = f"{row['adjusted_horizon_days']:.1f} j" if row.get("adjusted_horizon_days") is not None else "n/d"
    return f"{row['name']} x{fmt_qty(row['quantity'])} — {fmt_gold(row.get(value_key))}, sale EU {rate}, horizon prudent {horizon}"


def render_markdown(report: dict[str, Any]) -> str:
    capital = report["capital"]
    reinvestment = report["reinvestment"]
    sales = reinvestment["sales"]
    purchases = reinvestment["purchases"]
    result = report["result"]
    rotation = report["rotation"]
    settings = report["reset_settings"]
    delta = capital.get("change_vs_previous_gross_copper")
    delta_text = "n/d" if delta is None else ("+" if delta >= 0 else "") + fmt_gold(delta)
    lines = [
        f"# Yayag — Yaya Market Reset — {report['report_date']}",
        "",
        f"## 1. Capital : {fmt_gold(capital['total_gross_copper'])} brut TSM | {fmt_gold(capital['total_after_fee_copper'])} indicatif après 5 % | liquide {fmt_gold(capital['cash_copper'])}",
        f"Stock {fmt_gold(capital['stock_gross_copper'])} + enchères {fmt_gold(capital['auction_gross_copper'])} ; variation snapshot {delta_text} ; croissance vs base 100k {fmt_gold(capital['growth_vs_base_copper'])}.",
        "",
        f"## 2. Réinvestissement : {fmt_gold(purchases['total_copper'])} achetés ({fmt_qty(purchases['quantity'])} unités, coût moyen {fmt_gold(purchases['total_copper'] / purchases['quantity']) if purchases['quantity'] else 'n/d'})",
        f"Ventes : {fmt_gold(sales['total_copper'])} brut, {fmt_gold(sales['net_after_commission_copper'])} net après 5 % ; réinvestissement net achats − ventes nettes : {fmt_gold(reinvestment['net_reinvestment_copper'])}.",
        "Achats principaux :",
    ]
    for row in sorted(purchases["by_item"].items(), key=lambda item: item[1]["total_copper"], reverse=True)[:5]:
        item_string, data = row
        name = report["item_names"].get(str(data.get("item_id")), item_string)
        lines.append(f"- {name} x{fmt_qty(data['quantity'])} — {fmt_gold(data['total_copper'])}")
    lines.extend(
        [
            "",
            f"## 3. Rotation : {fmt_qty(sales['quantity'])} vendus ; ratio achats/ventes nettes {reinvestment['purchase_to_net_sales_ratio']:.2f} si calculable ; {fmt_qty(rotation['cancelled_quantity'])} annulés, {fmt_qty(rotation['expired_quantity'])} expirés.",
            "",
            "## 4. Stock / enchères : top immobilisations",
        ]
    )
    for row in rotation["slow_items"][:5]:
        lines.append(f"- {item_line(row)}")
    if not rotation["slow_items"]:
        lines.append("- aucune position lente calculable")
    lines.extend(
        [
            "",
            f"## 5. Résultat : réalisé {fmt_gold(result['realized_profit_after_commission_copper'])} ({fmt_pct(result['realized_return_on_known_cost'])} sur coût connu) ; latent après frais {fmt_gold(result['latent_profit_after_fee_copper'])}.",
            "Le latent exclut les coûts inconnus ; marketValue est une valeur indicative, jamais une vente garantie.",
            "",
            "## 6. Anomalies / fraîcheur",
        ]
    )
    for anomaly in report["anomalies"][:6]:
        lines.append(f"- {anomaly}")
    if not report["anomalies"]:
        lines.append("- aucune anomalie détectée")
    lines.append(f"- TSM AppHelper : {report['freshness'].get('tsm_app_sync') or 'n/d'} ; fichier AppData : {report['freshness'].get('appdata_file_modified') or 'n/d'}.")
    lines.append("- Ledger TSM : achats/ventes surtout visibles après récupération du courrier et sauvegarde ; une ligne absente ne prouve pas l’absence de transaction.")
    if settings.get("exists"):
        lines.append(
            f"- Reset actuel : minROI {settings.get('minROI')} %, minProfit {settings.get('minProfitGold')} po, maxDays {settings.get('maxDays')}, "
            f"marketShare {settings.get('marketShare')} %, cible {settings.get('maxTargetPct')} %, budget {settings.get('budgetGold')} po, minScore {settings.get('minScore')}."
        )
    lines.append("- DBRegionSoldPerDay = moyenne régionale EU par hôtel/jour ; décote appliquée 50 %, pas une prévision garantie pour Yayag.")
    lines.append("")
    lines.append("## Décision du jour")
    decisions = []
    if rotation["expired_quantity"] > max(10_000, rotation["auction_quantity"] * 0.25):
        decisions.append("P1 — baisser de façon ciblée le minPrice TSM sur les items liquides expirants, réduire les lots et relister plus souvent ; ne pas réduire uniformément.")
    if reinvestment["net_reinvestment_copper"] > 0 and capital["change_vs_previous_gross_copper"] is not None and capital["change_vs_previous_gross_copper"] <= 0:
        decisions.append("P1 — réduire budget/marketShare du Reset et relever minScore ou minROI : les achats dépassent les sorties sans croissance du portefeuille.")
    elif reinvestment["net_reinvestment_copper"] <= 0 and capital["change_vs_previous_gross_copper"] is not None and capital["change_vs_previous_gross_copper"] > 0:
        decisions.append("P1 — conserver la sélection ; le capital se libère et la valeur progresse. Augmenter le budget seulement par petits paliers.")
    if settings.get("minScore") == 0:
        decisions.append("P2 — tester minScore 20–25 pour filtrer les offres à faible profondeur ; conserver minROI/minProfit comme garde-fous.")
    if rotation["slow_items"]:
        decisions.append("P2 — sortir progressivement les positions avec horizon prudent > 3 jours ou latent négatif ; priorité à la libération du capital.")
    if not decisions:
        decisions.append("P1 — conserver les paramètres et attendre une tendance glissante de 3 jours avant tout changement.")
    lines.extend(f"- {decision}" for decision in decisions[:3])
    return "\n".join(lines) + "\n"


def write_outputs(report: dict[str, Any], output_dir: Path) -> tuple[Path, Path]:
    output_dir.mkdir(parents=True, exist_ok=True)
    report_date = report["report_date"]
    json_path = output_dir / f"yayag-market-reset-{report_date}.json"
    markdown_path = output_dir / f"yayag-market-reset-{report_date}.md"
    state_path = output_dir / "yayag-market-reset-state.json"
    state = {
        "signature": report["signature"],
        "current": {
            "report_date": report["report_date"],
            "generated_at": report["generated_at"],
            "capital": report["capital"],
        },
        "previous": report.get("previous_state"),
    }
    json_path.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    markdown_path.write_text(render_markdown(report), encoding="utf-8")
    state_path.write_text(json.dumps(state, ensure_ascii=False, indent=2), encoding="utf-8")
    return json_path, markdown_path


def main() -> int:
    args = parse_args()
    try:
        report = build_report(args)
        markdown = render_markdown(report)
        if not args.print_only:
            json_path, markdown_path = write_outputs(report, args.output_dir)
            if not args.quiet:
                print(f"Snapshot prêt : {json_path}")
                print(f"Résumé prêt : {markdown_path}")
        if not args.quiet:
            print(markdown)
        return 0
    except Exception as exc:  # noqa: BLE001 - useful error for scheduled execution
        print(f"ERREUR daily_yayag_reset : {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
