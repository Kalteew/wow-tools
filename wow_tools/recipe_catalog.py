from __future__ import annotations

from collections import defaultdict
from dataclasses import dataclass, field


@dataclass(frozen=True)
class ItemSeed:
    item_id: int
    item_name: str
    expansion: str
    profession: str
    category: str
    family_name: str | None = None
    auctionable: bool = True
    analysis_target: bool = False


@dataclass(frozen=True)
class MarketProxyOption:
    item_id: int
    quantity: float
    note: str | None = None


@dataclass(frozen=True)
class ReagentSeed:
    quantity: float
    item_id: int | None = None
    name: str | None = None
    vendor_cost_copper: int | None = None
    proxy_options: tuple[MarketProxyOption, ...] = ()


@dataclass(frozen=True)
class RecipeSeed:
    recipe_id: str
    recipe_name: str
    output_item_id: int
    output_quantity: float
    expansion: str
    profession: str
    reagents: tuple[ReagentSeed, ...]
    cooldown_days: float | None = None
    notes: tuple[str, ...] = ()
    spell_id: int | None = None


ITEMS: tuple[ItemSeed, ...] = (
    ItemSeed(72095, "Trillium Bar", "mists-of-pandaria", "mining", "material"),
    ItemSeed(72096, "Ghost Iron Bar", "mists-of-pandaria", "mining", "material"),
    ItemSeed(72104, "Living Steel", "mists-of-pandaria", "alchemy", "material", analysis_target=True),
    ItemSeed(94113, "Jard's Peculiar Energy Source", "mists-of-pandaria", "engineering", "material", auctionable=False),
    ItemSeed(95416, "Sky Golem", "mists-of-pandaria", "engineering", "mount", analysis_target=True),
    ItemSeed(51950, "Pyrium Bar", "cataclysm", "mining", "material"),
    ItemSeed(52325, "Volatile Fire", "cataclysm", "alchemy", "material"),
    ItemSeed(52326, "Volatile Water", "cataclysm", "alchemy", "material"),
    ItemSeed(52328, "Volatile Air", "cataclysm", "alchemy", "material"),
    ItemSeed(56850, "Deepstone Oil", "cataclysm", "alchemy", "material"),
    ItemSeed(58084, "Flask of the Winds", "cataclysm", "alchemy", "consumable"),
    ItemSeed(58087, "Flask of Titanic Strength", "cataclysm", "alchemy", "consumable"),
    ItemSeed(58480, "Truegold", "cataclysm", "alchemy", "material", analysis_target=True),
    ItemSeed(65891, "Vial of the Sands", "cataclysm", "alchemy", "mount", analysis_target=True),
    ItemSeed(35624, "Eternal Earth", "wrath-of-the-lich-king", "mining", "material"),
    ItemSeed(35627, "Eternal Shadow", "wrath-of-the-lich-king", "mining", "material"),
    ItemSeed(36860, "Eternal Fire", "wrath-of-the-lich-king", "mining", "material"),
    ItemSeed(36910, "Titanium Bar", "wrath-of-the-lich-king", "mining", "material"),
    ItemSeed(36916, "Cobalt Bar", "wrath-of-the-lich-king", "mining", "material"),
    ItemSeed(37663, "Titansteel Bar", "wrath-of-the-lich-king", "mining", "material", analysis_target=True),
    ItemSeed(39681, "Handful of Cobalt Bolts", "wrath-of-the-lich-king", "engineering", "material"),
    ItemSeed(41508, "Mechano-Hog", "wrath-of-the-lich-king", "engineering", "mount", analysis_target=True),
    ItemSeed(44128, "Arctic Fur", "wrath-of-the-lich-king", "skinning", "material"),
    ItemSeed(123918, "Leystone Ore", "legion", "mining", "material"),
    ItemSeed(123919, "Felslate", "legion", "mining", "material"),
    ItemSeed(124113, "Felhide", "legion", "skinning", "material"),
    ItemSeed(124440, "Arkhana", "legion", "enchanting", "material"),
    ItemSeed(124444, "Infernal Brimstone", "legion", "mining", "material"),
    ItemSeed(124461, "Demonsteel Bar", "legion", "blacksmithing", "material"),
    ItemSeed(124117, "Lean Shank", "legion", "cooking", "material"),
    ItemSeed(124120, "Leyblood", "legion", "herbalism", "material"),
    ItemSeed(137686, "Steelbound Harness", "legion", "blacksmithing", "mount", analysis_target=True),
)


RECIPES: tuple[RecipeSeed, ...] = (
    RecipeSeed(
        recipe_id="living-steel",
        recipe_name="Transmute: Living Steel",
        output_item_id=72104,
        output_quantity=1,
        expansion="mists-of-pandaria",
        profession="alchemy",
        cooldown_days=1,
        reagents=(
            ReagentSeed(item_id=72095, quantity=6),
        ),
        spell_id=114780,
    ),
    RecipeSeed(
        recipe_id="jards-energy-source",
        recipe_name="Jard's Peculiar Energy Source",
        output_item_id=94113,
        output_quantity=1,
        expansion="mists-of-pandaria",
        profession="engineering",
        cooldown_days=1,
        reagents=(
            ReagentSeed(item_id=72096, quantity=10),
        ),
        spell_id=139176,
    ),
    RecipeSeed(
        recipe_id="sky-golem",
        recipe_name="Sky Golem",
        output_item_id=95416,
        output_quantity=1,
        expansion="mists-of-pandaria",
        profession="engineering",
        reagents=(
            ReagentSeed(item_id=94113, quantity=30),
            ReagentSeed(item_id=72104, quantity=30),
        ),
        spell_id=139192,
    ),
    RecipeSeed(
        recipe_id="truegold",
        recipe_name="Transmute: Truegold",
        output_item_id=58480,
        output_quantity=1,
        expansion="cataclysm",
        profession="alchemy",
        reagents=(
            ReagentSeed(item_id=51950, quantity=3),
            ReagentSeed(item_id=52325, quantity=10),
            ReagentSeed(item_id=52328, quantity=10),
            ReagentSeed(item_id=52326, quantity=10),
        ),
        notes=("Retail no longer appears to enforce the old Cataclysm cooldown here.",),
        spell_id=80243,
    ),
    RecipeSeed(
        recipe_id="vial-of-the-sands",
        recipe_name="Vial of the Sands",
        output_item_id=65891,
        output_quantity=1,
        expansion="cataclysm",
        profession="alchemy",
        reagents=(
            ReagentSeed(name="Pyrium-Laced Crystalline Vial", quantity=1, vendor_cost_copper=45_000_000),
            ReagentSeed(name="Sands of Time", quantity=8, vendor_cost_copper=27_000_000),
            ReagentSeed(item_id=58480, quantity=12),
            ReagentSeed(item_id=58084, quantity=8),
            ReagentSeed(item_id=58087, quantity=8),
            ReagentSeed(item_id=56850, quantity=8),
        ),
        notes=("Vendor costs assume the long-standing 4.5k + 2.7k retail Uldum prices.",),
        spell_id=93328,
    ),
    RecipeSeed(
        recipe_id="titansteel",
        recipe_name="Smelt Titansteel",
        output_item_id=37663,
        output_quantity=1,
        expansion="wrath-of-the-lich-king",
        profession="mining",
        reagents=(
            ReagentSeed(item_id=36910, quantity=3),
            ReagentSeed(item_id=36860, quantity=1),
            ReagentSeed(item_id=35624, quantity=1),
            ReagentSeed(item_id=35627, quantity=1),
        ),
        spell_id=55208,
    ),
    RecipeSeed(
        recipe_id="handful-of-cobalt-bolts",
        recipe_name="Handful of Cobalt Bolts",
        output_item_id=39681,
        output_quantity=2,
        expansion="wrath-of-the-lich-king",
        profession="engineering",
        reagents=(
            ReagentSeed(item_id=36916, quantity=2),
        ),
        notes=("Wowhead shows a base craft yield of 2 bolts.",),
        spell_id=56349,
    ),
    RecipeSeed(
        recipe_id="mechano-hog",
        recipe_name="Mechano-Hog",
        output_item_id=41508,
        output_quantity=1,
        expansion="wrath-of-the-lich-king",
        profession="engineering",
        reagents=(
            ReagentSeed(item_id=37663, quantity=12),
            ReagentSeed(item_id=39681, quantity=40),
            ReagentSeed(item_id=44128, quantity=2),
            ReagentSeed(name="Salvaged Iron Golem Parts", quantity=1, vendor_cost_copper=30_000_000),
            ReagentSeed(name="Goblin-Machined Piston", quantity=8, vendor_cost_copper=10_000_000),
            ReagentSeed(name="Elementium-Plated Exhaust Pipe", quantity=1, vendor_cost_copper=15_000_000),
        ),
        notes=("Vendor-only engineering parts use the long-standing 12.5k gold total.",),
        spell_id=60866,
    ),
    RecipeSeed(
        recipe_id="demonsteel-bar",
        recipe_name="Demonsteel Bar",
        output_item_id=124461,
        output_quantity=1,
        expansion="legion",
        profession="blacksmithing",
        reagents=(
            ReagentSeed(item_id=123918, quantity=1),
            ReagentSeed(item_id=123919, quantity=2),
        ),
        spell_id=184442,
    ),
    RecipeSeed(
        recipe_id="steelbound-harness",
        recipe_name="Fel Core Hound Harness",
        output_item_id=137686,
        output_quantity=1,
        expansion="legion",
        profession="blacksmithing",
        reagents=(
            ReagentSeed(item_id=124461, quantity=100),
            ReagentSeed(
                name="Blood of Sargeras",
                quantity=50,
            ),
            ReagentSeed(item_id=124444, quantity=10),
            ReagentSeed(item_id=124113, quantity=10),
        ),
        notes=("Blood of Sargeras is a currency cost, not a direct auction purchase.",),
        spell_id=213916,
    ),
)


def items_by_id() -> dict[int, ItemSeed]:
    return {item.item_id: item for item in ITEMS}


def recipes_by_output_item() -> dict[int, list[RecipeSeed]]:
    grouped: dict[int, list[RecipeSeed]] = defaultdict(list)
    for recipe in RECIPES:
        grouped[recipe.output_item_id].append(recipe)
    return dict(grouped)


def tracked_item_ids() -> list[int]:
    item_ids = {item.item_id for item in ITEMS}
    for recipe in RECIPES:
        item_ids.add(recipe.output_item_id)
        for reagent in recipe.reagents:
            if reagent.item_id is not None:
                item_ids.add(reagent.item_id)
            for proxy in reagent.proxy_options:
                item_ids.add(proxy.item_id)
    return sorted(item_ids)


def priceable_item_ids() -> list[int]:
    item_ids = {item.item_id for item in ITEMS if item.auctionable}
    for recipe in RECIPES:
        for reagent in recipe.reagents:
            if reagent.item_id is not None and CATALOG_LOOKUP[reagent.item_id].auctionable:
                item_ids.add(reagent.item_id)
            for proxy in reagent.proxy_options:
                item_ids.add(proxy.item_id)
    return sorted(item_ids)


def analysis_targets() -> list[ItemSeed]:
    output_ids = {recipe.output_item_id for recipe in RECIPES}
    return [item for item in ITEMS if item.item_id in output_ids]


def default_favorite_spell_ids() -> list[int]:
    return [recipe.spell_id for recipe in RECIPES if recipe.spell_id is not None and CATALOG_LOOKUP[recipe.output_item_id].analysis_target]


CATALOG_LOOKUP = items_by_id()
