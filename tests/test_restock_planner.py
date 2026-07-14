from wow_tools.restock_planner import _classify_category, _extract_primary_bind_scope, _parse_bind_type_from_html, _round_to_bucket


def test_round_to_bucket_prefers_nearest_value() -> None:
    assert _round_to_bucket(4, [1, 2, 3, 5, 8]) == 3
    assert _round_to_bucket(6, [1, 2, 3, 5, 8]) == 5
    assert _round_to_bucket(430, [1, 5, 10, 100, 200, 500]) == 500


def test_classify_category_handles_tailoring_bags_and_enchant_weapons() -> None:
    tailoring_recipe = {
        "recipe_name": "Arcanoweave Reagent Rucksack",
        "output": {"item_id": 240158, "item_name": "Arcanoweave Reagent Rucksack"},
        "reagents": [],
    }
    enchanting_recipe = {
        "recipe_name": "Enchant Weapon - Strength of Halazzi",
        "output": {"item_id": 243968, "item_name": "Enchant Weapon - Strength of Halazzi"},
        "reagents": [],
    }
    assert (
        _classify_category("tailoring", tailoring_recipe, {"jsonequip": {"slotbak": 18}}, [tailoring_recipe])
        == "tailoring-bag"
    )
    assert (
        _classify_category("enchanting", enchanting_recipe, {"jsonequip": {}}, [enchanting_recipe])
        == "enchanting-weapon"
    )


def test_classify_category_handles_blacksmithing_and_inscription() -> None:
    blacksmith_recipe = {
        "recipe_name": "Refulgent Whetstone",
        "output": {"item_id": 1, "item_name": "Refulgent Whetstone"},
        "reagents": [],
    }
    inscription_recipe = {
        "recipe_name": "Thalassian Missive of Finesse",
        "output": {"item_id": 2, "item_name": "Thalassian Missive of Finesse"},
        "reagents": [],
    }

    assert (
        _classify_category("blacksmithing", blacksmith_recipe, {"jsonequip": {}}, [blacksmith_recipe])
        == "blacksmithing-consumable"
    )
    assert (
        _classify_category("inscription", inscription_recipe, {"jsonequip": {}}, [inscription_recipe])
        == "inscription-missive"
    )


def test_classify_category_handles_remaining_midnight_professions() -> None:
    alchemy_recipe = {
        "recipe_name": "Silvermoon Health Potion",
        "output": {"item_id": 3, "item_name": "Silvermoon Health Potion"},
        "reagents": [],
    }
    leatherworking_recipe = {
        "recipe_name": "Forest Hunter's Armor Kit",
        "output": {"item_id": 4, "item_name": "Forest Hunter's Armor Kit"},
        "reagents": [],
    }
    jewelcrafting_recipe = {
        "recipe_name": "Quick Amethyst",
        "output": {"item_id": 5, "item_name": "Quick Amethyst"},
        "reagents": [],
    }
    engineering_recipe = {
        "recipe_name": "Turbo-Junker's Multitool",
        "output": {"item_id": 6, "item_name": "Turbo-Junker's Multitool"},
        "reagents": [],
    }

    assert _classify_category("alchemy", alchemy_recipe, {"jsonequip": {}}, [alchemy_recipe]) == "alchemy-potion"
    assert (
        _classify_category("leatherworking", leatherworking_recipe, {"jsonequip": {}}, [leatherworking_recipe])
        == "leatherworking-consumable"
    )
    assert (
        _classify_category("jewelcrafting", jewelcrafting_recipe, {"jsonequip": {}}, [jewelcrafting_recipe])
        == "jewelcrafting-gem"
    )
    assert (
        _classify_category("engineering", engineering_recipe, {"jsonequip": {}}, [engineering_recipe])
        == "engineering-tool"
    )


def test_parse_bind_type_from_html_detects_bop_and_boe() -> None:
    assert _parse_bind_type_from_html("Item Level 44 Binds when picked up Trinket") == "bop"
    assert _parse_bind_type_from_html("Item Level 27 Binds when equipped Engineering Tool") == "boe"
    assert _parse_bind_type_from_html("Warbound until equipped") == "boe"
    assert _parse_bind_type_from_html("No bind text here") is None


def test_extract_primary_bind_scope_ignores_wowhead_filter_labels() -> None:
    html = (
        'g_items[239670].tooltip_enus = "<br>Binds when equipped<br>";'
        '..."name":"Binds when picked up","term":"bindswhenpickedup_stc"'
    )
    scope = _extract_primary_bind_scope(239670, html)
    assert _parse_bind_type_from_html(scope) == "boe"
