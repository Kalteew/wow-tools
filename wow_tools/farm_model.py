from __future__ import annotations

import json
from dataclasses import dataclass
from functools import lru_cache
from typing import Any

from wow_tools.config import HOURLY_ESTIMATES_PATH


@dataclass(frozen=True)
class FrequencyProfile:
    category: str
    acquisition_weight: float
    route_weight: float
    note: str


# Default expected quality mix for modern family variants. These weights are
# only used when the same family exists in multiple item qualities.
DEFAULT_QUALITY_DROP_WEIGHTS = {
    1: 0.72,
    2: 0.22,
    3: 0.06,
}


# These overrides model how often a family realistically appears during a
# dedicated gathering route. The goal is not perfect spawn simulation, but to
# avoid treating rare jackpot materials as if they were route anchors.
FREQUENCY_PROFILES: dict[tuple[str, str], FrequencyProfile] = {
    ("mining", "Copper Ore"): FrequencyProfile("dense_anchor", 1.00, 1.20, "ubiquitous starter ore"),
    ("mining", "Thorium Ore"): FrequencyProfile("wide_anchor", 1.00, 1.05, "widely routeable old-world ore"),
    ("herbalism", "Black Lotus"): FrequencyProfile("jackpot", 0.02, 0.70, "very rare end-node jackpot"),
    ("herbalism", "Ghost Mushroom"): FrequencyProfile("rare", 0.18, 0.75, "restricted cave herb"),
    ("herbalism", "Flame Cap"): FrequencyProfile("rare", 0.06, 0.60, "special low-frequency herb"),
    ("herbalism", "Fel Lotus"): FrequencyProfile("rare", 0.08, 0.80, "rare lotus from Outland routes"),
    ("mining", "Fel Iron Ore"): FrequencyProfile("dense_anchor", 1.00, 1.20, "dense Outland route staple"),
    ("mining", "Adamantite Ore"): FrequencyProfile("wide_anchor", 1.00, 1.05, "common Outland follow-up ore"),
    ("mining", "Khorium Ore"): FrequencyProfile("rare", 0.08, 0.75, "rare vein replacement"),
    ("mining", "Cobalt Ore"): FrequencyProfile("dense_anchor", 1.00, 1.35, "ubiquitous Northrend route staple"),
    ("mining", "Saronite Ore"): FrequencyProfile("wide_anchor", 1.00, 1.15, "high-volume Northrend ore"),
    ("herbalism", "Adder's Tongue"): FrequencyProfile("wide_anchor", 1.00, 1.10, "reliable Northrend herb"),
    ("mining", "Titanium Ore"): FrequencyProfile("uncommon", 0.18, 0.85, "rare Northrend vein replacement"),
    ("mining", "Elementium Ore"): FrequencyProfile("dense_anchor", 1.00, 1.15, "dense Cataclysm route ore"),
    ("mining", "Pyrite Ore"): FrequencyProfile("uncommon", 0.22, 0.85, "rarer Cataclysm ore"),
    ("herbalism", "Golden Lotus"): FrequencyProfile("uncommon", 0.20, 0.85, "rarer Pandaria herb"),
    ("mining", "Ghost Iron Ore"): FrequencyProfile("dense_anchor", 1.00, 1.35, "ubiquitous Pandaria ore"),
    ("mining", "Black Trillium Ore"): FrequencyProfile("uncommon", 0.16, 0.85, "rarer Pandaria ore"),
    ("mining", "White Trillium Ore"): FrequencyProfile("uncommon", 0.16, 0.85, "rarer Pandaria ore"),
    ("herbalism", "Green Tea Leaf"): FrequencyProfile("wide_anchor", 1.00, 1.10, "abundant Pandaria herb"),
    ("herbalism", "Silkweed"): FrequencyProfile("wide_anchor", 1.00, 1.10, "common Pandaria river herb"),
    ("mining", "Blackrock Ore"): FrequencyProfile("wide_anchor", 1.00, 1.10, "high-volume Draenor ore"),
    ("herbalism", "Talador Orchid"): FrequencyProfile("wide_anchor", 1.00, 1.10, "high-volume Draenor herb"),
    ("herbalism", "Felwort"): FrequencyProfile("rare", 0.12, 0.80, "low-frequency Legion herb"),
    ("mining", "Leystone Ore"): FrequencyProfile("dense_anchor", 1.00, 1.20, "very common Legion ore"),
    ("herbalism", "Dreamleaf"): FrequencyProfile("wide_anchor", 1.00, 1.10, "high-volume Legion herb"),
    ("herbalism", "Starlight Rose"): FrequencyProfile("uncommon", 0.45, 0.95, "valuable but routeable Legion herb"),
    ("herbalism", "Anchor Weed"): FrequencyProfile("uncommon", 0.18, 0.85, "rarer BfA herb"),
    ("mining", "Monelite Ore"): FrequencyProfile("wide_anchor", 1.00, 1.10, "common BfA ore"),
    ("mining", "Platinum Ore"): FrequencyProfile("uncommon", 0.18, 0.85, "rarer BfA ore"),
    ("herbalism", "Sea Stalk"): FrequencyProfile("wide_anchor", 1.00, 1.10, "common BfA herb"),
    ("herbalism", "Zin'anthid"): FrequencyProfile("uncommon", 0.42, 0.90, "zone-specific BfA herb"),
    ("herbalism", "Nightshade"): FrequencyProfile("uncommon", 0.22, 0.90, "rarer Shadowlands herb"),
    ("herbalism", "Death Blossom"): FrequencyProfile("dense_anchor", 1.00, 1.15, "most common Shadowlands herb"),
    ("herbalism", "First Flower"): FrequencyProfile("rare", 0.08, 0.80, "special Shadowlands herb"),
    ("mining", "Elethium Ore"): FrequencyProfile("uncommon", 0.18, 0.85, "rarer Shadowlands ore"),
    ("mining", "Progenium Ore"): FrequencyProfile("rare", 0.05, 0.75, "special Shadowlands ore"),
    ("herbalism", "Hochenblume"): FrequencyProfile("dense_anchor", 1.00, 1.15, "most common Dragonflight herb"),
    ("herbalism", "Writhebark"): FrequencyProfile("uncommon", 0.65, 0.95, "primary but less frequent Dragonflight herb"),
    ("herbalism", "Zaralek Glowspores"): FrequencyProfile("uncommon", 0.18, 0.80, "subzone-specific Dragonflight herb"),
    ("mining", "Serevite Ore"): FrequencyProfile("wide_anchor", 1.00, 1.10, "common Dragonflight ore"),
    ("mining", "Khaz'gorite Ore"): FrequencyProfile("rare", 0.12, 0.80, "rare Dragonflight ore"),
    ("mining", "Bismuth"): FrequencyProfile("wide_anchor", 1.00, 1.10, "high-volume TWW ore"),
    ("herbalism", "Mycobloom"): FrequencyProfile("wide_anchor", 1.00, 1.05, "common TWW herb"),
    ("mining", "Null Stone"): FrequencyProfile("rare", 0.12, 0.75, "rare TWW mining find"),
    ("herbalism", "Null Lotus"): FrequencyProfile("rare", 0.08, 0.75, "rare TWW herbalism find"),
    ("herbalism", "Nocturnal Lotus"): FrequencyProfile("rare", 0.08, 0.75, "rare Midnight lotus"),
    ("mining", "Dazzling Thorium"): FrequencyProfile("rare", 0.12, 0.80, "rare Midnight ore"),
    ("skinning", "Rugged Leather"): FrequencyProfile("dense_anchor", 1.00, 1.25, "high-density legacy leather route"),
    ("skinning", "Knothide Leather"): FrequencyProfile("dense_anchor", 1.00, 1.20, "dense Outland skinning staple"),
    ("skinning", "Borean Leather"): FrequencyProfile("dense_anchor", 1.00, 1.18, "reliable Northrend skinning staple"),
    ("skinning", "Savage Leather"): FrequencyProfile("dense_anchor", 1.00, 1.18, "high-density Cataclysm leather route"),
    ("skinning", "Mist-Touched Leather"): FrequencyProfile("wide_anchor", 1.00, 1.10, "common Pandaria leather route"),
    ("skinning", "Magnificent Hide"): FrequencyProfile("rare", 0.08, 0.75, "rare Pandaria skinning jackpot"),
    ("skinning", "Raw Beast Hide"): FrequencyProfile("wide_anchor", 1.00, 1.05, "standard Draenor leather route"),
    ("skinning", "Stonehide Leather"): FrequencyProfile("dense_anchor", 1.00, 1.25, "very common Legion leather route"),
    ("skinning", "Felhide"): FrequencyProfile("rare", 0.08, 0.75, "rare Legion skinning drop"),
    ("skinning", "Coarse Leather"): FrequencyProfile("dense_anchor", 1.00, 1.25, "very common BfA leather route"),
    ("skinning", "Tempest Hide"): FrequencyProfile("uncommon", 0.18, 0.85, "uncommon BfA hide"),
    ("skinning", "Desolate Leather"): FrequencyProfile("dense_anchor", 1.00, 1.20, "common Shadowlands leather"),
    ("skinning", "Callous Hide"): FrequencyProfile("uncommon", 0.18, 0.85, "uncommon Shadowlands hide"),
    ("skinning", "Heavy Desolate Leather"): FrequencyProfile("uncommon", 0.22, 0.85, "less common heavy Shadowlands leather"),
    ("skinning", "Heavy Callous Hide"): FrequencyProfile("rare", 0.08, 0.75, "rare heavy Shadowlands hide"),
    ("skinning", "Resilient Leather"): FrequencyProfile("dense_anchor", 1.00, 1.15, "common Dragonflight leather"),
    ("skinning", "Dense Hide"): FrequencyProfile("uncommon", 0.18, 0.85, "uncommon Dragonflight hide"),
    ("skinning", "Lustrous Scaled Hide"): FrequencyProfile("uncommon", 0.16, 0.85, "uncommon Dragonflight scaled hide"),
}


DEFAULT_PROFILE = FrequencyProfile("anchor", 1.0, 1.0, "primary route material")


BASE_HOURLY_UNITS: dict[str, dict[str, float]] = {
    "Classic": {"mining": 360.0, "herbalism": 260.0, "skinning": 560.0},
    "The Burning Crusade": {"mining": 340.0, "herbalism": 245.0, "skinning": 520.0},
    "Wrath of the Lich King": {"mining": 390.0, "herbalism": 270.0, "skinning": 500.0},
    "Cataclysm": {"mining": 380.0, "herbalism": 260.0, "skinning": 540.0},
    "Mists of Pandaria": {"mining": 520.0, "herbalism": 320.0, "skinning": 400.0},
    "Warlords of Draenor": {"mining": 430.0, "herbalism": 300.0, "skinning": 340.0},
    "Legion": {"mining": 560.0, "herbalism": 340.0, "skinning": 850.0},
    "Battle for Azeroth": {"mining": 420.0, "herbalism": 300.0, "skinning": 950.0},
    "Shadowlands": {"mining": 360.0, "herbalism": 280.0, "skinning": 850.0},
    "Dragonflight": {"mining": 440.0, "herbalism": 300.0, "skinning": 620.0},
    "The War Within": {"mining": 460.0, "herbalism": 320.0, "skinning": 650.0},
    "Midnight": {"mining": 470.0, "herbalism": 330.0, "skinning": 675.0},
}


CATEGORY_HOURLY_WEIGHTS = {
    "dense_anchor": 1.35,
    "wide_anchor": 1.10,
    "anchor": 1.00,
    "uncommon": 0.35,
    "rare": 0.08,
    "jackpot": 0.02,
}


FAMILY_HOURLY_WEIGHT_OVERRIDES: dict[tuple[str, str], float] = {
    ("herbalism", "Black Lotus"): 0.015,
    ("herbalism", "Ghost Mushroom"): 0.12,
    ("herbalism", "Flame Cap"): 0.05,
    ("herbalism", "Fel Lotus"): 0.06,
    ("mining", "Khorium Ore"): 0.025,
    ("mining", "Cobalt Ore"): 1.35,
    ("mining", "Saronite Ore"): 1.15,
    ("mining", "Titanium Ore"): 0.15,
    ("mining", "Elementium Ore"): 1.15,
    ("herbalism", "Golden Lotus"): 0.18,
    ("mining", "Ghost Iron Ore"): 1.35,
    ("mining", "Black Trillium Ore"): 0.14,
    ("mining", "White Trillium Ore"): 0.14,
    ("herbalism", "Green Tea Leaf"): 1.10,
    ("herbalism", "Silkweed"): 1.10,
    ("herbalism", "Felwort"): 0.10,
    ("mining", "Leystone Ore"): 1.20,
    ("herbalism", "Dreamleaf"): 1.10,
    ("herbalism", "Starlight Rose"): 0.55,
    ("herbalism", "Anchor Weed"): 0.16,
    ("mining", "Monelite Ore"): 1.10,
    ("mining", "Platinum Ore"): 0.16,
    ("herbalism", "Sea Stalk"): 1.10,
    ("herbalism", "Nightshade"): 0.20,
    ("herbalism", "Death Blossom"): 1.15,
    ("herbalism", "First Flower"): 0.07,
    ("mining", "Elethium Ore"): 0.16,
    ("mining", "Progenium Ore"): 0.03,
    ("herbalism", "Hochenblume"): 1.15,
    ("herbalism", "Writhebark"): 0.55,
    ("herbalism", "Zaralek Glowspores"): 0.16,
    ("mining", "Serevite Ore"): 1.10,
    ("mining", "Khaz'gorite Ore"): 0.12,
    ("mining", "Bismuth"): 1.10,
    ("herbalism", "Mycobloom"): 1.05,
    ("mining", "Null Stone"): 0.08,
    ("herbalism", "Null Lotus"): 0.05,
    ("herbalism", "Nocturnal Lotus"): 0.05,
    ("mining", "Dazzling Thorium"): 0.08,
    ("skinning", "Rugged Leather"): 1.25,
    ("skinning", "Knothide Leather"): 1.20,
    ("skinning", "Borean Leather"): 1.18,
    ("skinning", "Savage Leather"): 1.18,
    ("skinning", "Mist-Touched Leather"): 1.10,
    ("skinning", "Raw Beast Hide"): 1.05,
    ("skinning", "Stonehide Leather"): 1.25,
    ("skinning", "Stormscale"): 1.10,
    ("skinning", "Coarse Leather"): 1.25,
    ("skinning", "Shimmerscale"): 1.05,
    ("skinning", "Desolate Leather"): 1.20,
    ("skinning", "Callous Hide"): 0.10,
    ("skinning", "Heavy Desolate Leather"): 0.18,
    ("skinning", "Heavy Callous Hide"): 0.06,
    ("skinning", "Resilient Leather"): 1.15,
    ("skinning", "Adamant Scales"): 1.05,
    ("skinning", "Dense Hide"): 0.08,
    ("skinning", "Lustrous Scaled Hide"): 0.05,
    ("skinning", "Tempest Hide"): 0.08,
    ("skinning", "Arctic Fur"): 0.02,
    ("skinning", "Pristine Hide"): 0.04,
    ("skinning", "Magnificent Hide"): 0.03,
    ("skinning", "Felhide"): 0.03,
    ("skinning", "Protogenic Pelt"): 0.05,
    ("skinning", "Mireslush Hide"): 0.04,
    ("skinning", "Stonecrust Hide"): 0.04,
    ("skinning", "Deathchill Hide"): 0.04,
    ("skinning", "Fire-Infused Hide"): 0.04,
}


def family_frequency_profile(profession: str, family_name: str) -> FrequencyProfile:
    profile = FREQUENCY_PROFILES.get((profession, family_name))
    if profile:
        return profile
    if profession == "skinning":
        return infer_skinning_profile(family_name)
    return DEFAULT_PROFILE


def infer_skinning_profile(family_name: str) -> FrequencyProfile:
    normalized = family_name.casefold()
    if "scrap" in normalized:
        return FrequencyProfile("dense_anchor", 1.00, 1.10, "frequent skinning byproduct")
    if any(
        keyword in normalized
        for keyword in ("hide", "pelt", "fur", "fleece", "plumage", "claw", "fang", "fin", "horn", "setae", "canine", "morsel")
    ):
        return FrequencyProfile("rare", 0.10, 0.80, "low-frequency skinning premium material")
    if any(keyword in normalized for keyword in ("scale", "scales", "bone", "chitin", "sinew", "shell", "carapace")):
        return FrequencyProfile("wide_anchor", 1.00, 1.05, "regular skinning side material")
    if "leather" in normalized:
        return FrequencyProfile("dense_anchor", 1.00, 1.15, "common route skinning material")
    return FrequencyProfile("anchor", 1.0, 1.0, "generic skinning material")


@lru_cache(maxsize=1)
def _load_hourly_estimates() -> dict[tuple[str, str, str], dict[str, Any]]:
    if not HOURLY_ESTIMATES_PATH.exists():
        return {}

    payload = json.loads(HOURLY_ESTIMATES_PATH.read_text(encoding="utf-8"))
    entries: dict[tuple[str, str, str], dict[str, Any]] = {}
    for entry in payload.get("entries", []):
        key = (entry["expansion"], entry["profession"], entry["family_name"])
        entries[key] = entry
    return entries


def sourced_hourly_estimate(expansion: str, profession: str, family_name: str) -> dict[str, Any] | None:
    return _load_hourly_estimates().get((expansion, profession, family_name))


def base_hourly_units(expansion: str, profession: str) -> float:
    expansion_data = BASE_HOURLY_UNITS.get(expansion)
    if expansion_data and profession in expansion_data:
        return expansion_data[profession]
    fallback = {"mining": 360.0, "herbalism": 260.0, "skinning": 450.0}
    return fallback[profession]


def family_hourly_weight(profession: str, family_name: str, category: str) -> float:
    override = FAMILY_HOURLY_WEIGHT_OVERRIDES.get((profession, family_name))
    if override is not None:
        return override
    if profession == "skinning":
        return infer_skinning_hourly_weight(family_name)
    return CATEGORY_HOURLY_WEIGHTS.get(category, 1.0)


def infer_skinning_hourly_weight(family_name: str) -> float:
    normalized = family_name.casefold()
    if "scrap" in normalized:
        return 1.10
    if any(
        keyword in normalized
        for keyword in ("hide", "pelt", "fur", "fleece", "plumage", "claw", "fang", "fin", "horn", "setae", "canine", "morsel")
    ):
        return 0.03
    if any(keyword in normalized for keyword in ("scale", "scales", "bone", "chitin", "sinew", "shell", "carapace")):
        return 1.05
    if "leather" in normalized:
        return 1.15
    return 1.0


def hourly_estimate(expansion: str, profession: str, family_name: str, category: str) -> dict[str, Any]:
    base_units = base_hourly_units(expansion, profession)
    sourced = sourced_hourly_estimate(expansion, profession, family_name)
    if sourced:
        units = sourced["units_per_hour"]
        typical = float(units["typical"])
        low = float(units.get("low", typical))
        high = float(units.get("high", typical))
        hourly_weight = typical / base_units if base_units > 0 else 1.0
        return {
            "low": low,
            "typical": typical,
            "high": high,
            "hourly_weight": hourly_weight,
            "method": "sourced",
            "sourced": True,
            "source_urls": sourced.get("source_urls", []),
            "source_note": sourced.get("source_note"),
            "route_hint": sourced.get("route_hint"),
        }

    hourly_weight = family_hourly_weight(profession, family_name, category)
    typical = base_units * hourly_weight
    method = "inferred" if (profession, family_name) in FAMILY_HOURLY_WEIGHT_OVERRIDES or category != "anchor" else "heuristic"
    return {
        "low": typical,
        "typical": typical,
        "high": typical,
        "hourly_weight": hourly_weight,
        "method": method,
        "sourced": False,
        "source_urls": [],
        "source_note": None,
        "route_hint": None,
    }


def normalized_quality_weights(qualities: set[int]) -> dict[int, float]:
    if not qualities:
        return {}
    if len(qualities) == 1:
        quality = next(iter(qualities))
        return {quality: 1.0}

    raw_weights = {quality: DEFAULT_QUALITY_DROP_WEIGHTS.get(quality, 0.0) for quality in qualities}
    total = sum(raw_weights.values())
    if total <= 0:
        even_weight = 1.0 / len(qualities)
        return {quality: even_weight for quality in qualities}
    return {quality: weight / total for quality, weight in raw_weights.items()}


def _weighted_mean(pairs: list[tuple[float, float]]) -> float | None:
    total_weight = sum(weight for _, weight in pairs if weight > 0)
    if total_weight <= 0:
        return None
    return sum(value * weight for value, weight in pairs if weight > 0) / total_weight


def _preferred_price(row: dict[str, Any]) -> float:
    return float(
        row.get("price_copper")
        or row.get("market_value_copper")
        or row.get("region_market_value_avg_copper")
        or row.get("min_buyout_copper")
        or row.get("historical_price_copper")
        or 0
    )


def aggregate_family(rows: list[dict[str, Any]]) -> dict[str, Any]:
    if not rows:
        raise ValueError("aggregate_family requires at least one row")

    first = rows[0]
    qualities = {int(row["wowhead_quality"]) for row in rows if row.get("wowhead_quality") is not None}
    quality_weights = normalized_quality_weights(qualities)
    profile = family_frequency_profile(first["profession"], first["family_name"])
    farm_weight = profile.acquisition_weight * profile.route_weight
    estimate = hourly_estimate(
        first["expansion_seed"],
        first["profession"],
        first["family_name"],
        profile.category,
    )
    hourly_weight = float(estimate["hourly_weight"])
    estimated_units_per_hour = float(estimate["typical"])
    estimated_units_per_hour_low = float(estimate["low"])
    estimated_units_per_hour_high = float(estimate["high"])

    expected_unit_value = 0.0
    weighted_price_pairs: list[tuple[float, float]] = []
    total_available_quantity = 0
    total_daily_sold = 0.0
    sale_rate_pairs: list[tuple[float, float]] = []

    variants: list[dict[str, Any]] = []
    for row in rows:
        quality = row.get("wowhead_quality")
        quality_weight = quality_weights.get(int(quality), 0.0) if quality is not None else 0.0
        price = _preferred_price(row)
        sold_per_day = float(row["region_avg_daily_sold"] or 0)
        sale_rate = float(row["region_sale_rate"] or 0)
        available_quantity = int(row["available_quantity"] or 0)

        expected_unit_value += price * quality_weight
        weighted_price_pairs.append((price, quality_weight))
        total_available_quantity += available_quantity
        total_daily_sold += sold_per_day
        if sold_per_day > 0:
            sale_rate_pairs.append((sale_rate, sold_per_day))

        variants.append(
            {
                "item_id": row["item_id"],
                "item_name": row["item_name"],
                "wowhead_quality": quality,
                "price_copper": int(price),
                "quality_weight": quality_weight,
                "region_avg_daily_sold": sold_per_day,
            }
        )

    blended_sale_rate = _weighted_mean(sale_rate_pairs)
    raw_market_score = expected_unit_value * total_daily_sold
    rarity_adjusted_score = raw_market_score * farm_weight

    return {
        "expansion": first["expansion_seed"],
        "profession": first["profession"],
        "family_name": first["family_name"],
        "profile_category": profile.category,
        "acquisition_weight": profile.acquisition_weight,
        "route_weight": profile.route_weight,
        "farm_weight": farm_weight,
        "profile_note": profile.note,
        "expected_unit_value_copper": int(round(expected_unit_value)),
        "total_daily_sold": total_daily_sold,
        "available_quantity": total_available_quantity,
        "blended_sale_rate": blended_sale_rate,
        "hourly_weight": hourly_weight,
        "hourly_method": estimate["method"],
        "hourly_sourced": estimate["sourced"],
        "hourly_source_urls": estimate["source_urls"],
        "hourly_source_note": estimate["source_note"],
        "route_hint": estimate["route_hint"],
        "estimated_units_per_hour_low": estimated_units_per_hour_low,
        "estimated_units_per_hour": estimated_units_per_hour,
        "estimated_units_per_hour_high": estimated_units_per_hour_high,
        "estimated_gold_per_hour_low_copper": int(round(expected_unit_value * estimated_units_per_hour_low)),
        "estimated_gold_per_hour_copper": int(round(expected_unit_value * estimated_units_per_hour)),
        "estimated_gold_per_hour_high_copper": int(round(expected_unit_value * estimated_units_per_hour_high)),
        "raw_market_score": raw_market_score,
        "rarity_adjusted_score": rarity_adjusted_score,
        "variants": variants,
    }
