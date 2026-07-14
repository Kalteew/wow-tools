from __future__ import annotations

import argparse
import csv
import json
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from wow_tools.account_pipeline import load_local_price_index

DEFAULT_SEED = ROOT / "data" / "flipping" / "housing-decor-seed.json"
DEFAULT_OUTPUT_DIR = ROOT / "data" / "flipping" / "generated"


def _flatten_seed(seed: dict[str, Any]) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for tier, entries in seed.get("groups", {}).items():
        for entry in entries:
            row = dict(entry)
            row["tier"] = tier
            rows.append(row)
    return rows


def _score_gold_per_slot_day(price_copper: int | None, sale_rate: float | None) -> float:
    if not price_copper or not sale_rate:
        return 0.0
    return round((price_copper * sale_rate) / 10_000, 2)


def _build_rows(seed_path: Path) -> list[dict[str, Any]]:
    seed = json.loads(seed_path.read_text(encoding="utf-8"))
    seed_rows = _flatten_seed(seed)
    item_ids = sorted({int(row["item_id"]) for row in seed_rows})
    price_index = load_local_price_index(item_ids)

    output_rows: list[dict[str, Any]] = []
    for row in seed_rows:
        item_id = int(row["item_id"])
        summary = (price_index.get(item_id) or {}).get("summary", {})
        is_commodity = bool(summary.get("is_commodity"))
        sale_rate = summary.get("sale_rate")
        price_copper = summary.get("preferred_price_copper")
        tier = row["tier"]
        included = tier != "watch" and not is_commodity
        reason = row.get("reason") or ""
        if is_commodity:
            reason = "excluded: commodity pricing"
        elif tier == "watch":
            reason = reason or "watch only"

        output_rows.append(
            {
                "tier": tier,
                "item_id": item_id,
                "item_string": f"i:{item_id}",
                "name": row["name"],
                "profession": row.get("profession", ""),
                "included": "yes" if included else "no",
                "reason": reason,
                "price_copper": price_copper or "",
                "price_text": summary.get("preferred_price_text") or "",
                "min_buyout_text": summary.get("min_buyout_text") or "",
                "market_value_text": summary.get("market_value_text") or "",
                "sale_rate": sale_rate if sale_rate is not None else "",
                "sold_per_day": summary.get("sold_per_day") if summary.get("sold_per_day") is not None else "",
                "is_commodity": "yes" if is_commodity else "no",
                "gold_per_slot_day": _score_gold_per_slot_day(price_copper, sale_rate),
            }
        )

    return sorted(
        output_rows,
        key=lambda item: (
            item["included"] == "yes",
            float(item["gold_per_slot_day"] or 0),
            item["tier"] == "high",
        ),
        reverse=True,
    )


def _write_csv(path: Path, rows: list[dict[str, Any]]) -> None:
    fields = [
        "tier",
        "item_id",
        "item_string",
        "name",
        "profession",
        "included",
        "reason",
        "price_copper",
        "price_text",
        "min_buyout_text",
        "market_value_text",
        "sale_rate",
        "sold_per_day",
        "is_commodity",
        "gold_per_slot_day",
    ]
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields)
        writer.writeheader()
        writer.writerows(rows)


def _write_lines(path: Path, lines: list[str]) -> None:
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def build(seed_path: Path, output_dir: Path) -> dict[str, Path]:
    rows = _build_rows(seed_path)
    output_dir.mkdir(parents=True, exist_ok=True)
    included = [row for row in rows if row["included"] == "yes"]
    watch = [row for row in rows if row["included"] != "yes"]

    csv_path = output_dir / "housing-priority.csv"
    pbs_path = output_dir / "pbs-housing.txt"
    pbs_names_path = output_dir / "pbs-housing-names.txt"
    tsm_path = output_dir / "tsm-items-housing.txt"
    watch_path = output_dir / "housing-watch-exclude.txt"

    _write_csv(csv_path, rows)
    _write_lines(pbs_path, [str(row["item_id"]) for row in included])
    _write_lines(pbs_names_path, [row["name"] for row in included])
    _write_lines(tsm_path, [row["item_string"] for row in included])
    _write_lines(watch_path, [f"{row['item_id']} {row['name']} - {row['reason']}" for row in watch])

    return {
        "csv": csv_path,
        "pbs": pbs_path,
        "pbs_names": pbs_names_path,
        "tsm": tsm_path,
        "watch": watch_path,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Build housing decor flip lists from local TSM AppHelper data.")
    parser.add_argument("--seed", type=Path, default=DEFAULT_SEED)
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUTPUT_DIR)
    args = parser.parse_args()

    paths = build(args.seed, args.output_dir)
    for label, path in paths.items():
        print(f"{label}: {path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
