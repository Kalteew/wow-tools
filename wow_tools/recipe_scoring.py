from __future__ import annotations

import math
from typing import Any


def apply_balanced_recipe_scores(rows: list[dict[str, Any]]) -> None:
    if not rows:
        return

    profit_raw = [_profit_metric(row.get("net_profit_copper")) for row in rows]
    speed_raw = [_speed_metric(row.get("sale_rate")) for row in rows]
    profit_scores = _robust_minmax(profit_raw)
    speed_scores = _robust_minmax(speed_raw)

    for row, profit_score, speed_score in zip(rows, profit_scores, speed_scores):
        profitable = (row.get("net_profit_copper") or 0) > 0
        # Compress profit harder than sell rate so a very large jackpot does not
        # automatically dominate faster, lower-ticket crafts.
        row["profit_score"] = round((100.0 * profit_score) if profitable else 0.0, 2)
        row["speed_score"] = round(100.0 * speed_score, 2)
        row["balanced_score"] = round(
            (100.0 * ((0.55 * profit_score) + (0.45 * speed_score))) if profitable else 0.0,
            2,
        )


def _profit_metric(net_profit_copper: Any) -> float:
    profit_copper = int(net_profit_copper or 0)
    if profit_copper <= 0:
        return 0.0
    return math.log1p(profit_copper / 10_000.0)


def _speed_metric(sale_rate: Any) -> float:
    return math.sqrt(max(float(sale_rate or 0.0), 0.0))


def _robust_minmax(values: list[float]) -> list[float]:
    if not values:
        return []

    lower = _quantile(values, 0.10)
    upper = _quantile(values, 0.90)
    if upper <= lower:
        lower = min(values)
        upper = max(values)
    if upper <= lower:
        return [1.0 if value > 0 else 0.0 for value in values]

    scaled: list[float] = []
    for value in values:
        clamped = min(max(value, lower), upper)
        scaled.append((clamped - lower) / (upper - lower))
    return scaled


def _quantile(values: list[float], q: float) -> float:
    ordered = sorted(values)
    position = (len(ordered) - 1) * q
    low = int(math.floor(position))
    high = int(math.ceil(position))
    if low == high:
        return ordered[low]
    weight = position - low
    return ordered[low] * (1.0 - weight) + ordered[high] * weight
