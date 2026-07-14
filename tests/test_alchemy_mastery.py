from __future__ import annotations

import unittest

from wow_tools.alchemy_mastery import recipe_mastery_bonus


class RecipeAlchemyMasteryTests(unittest.TestCase):
    def test_transmutation_mastery_applies_to_legacy_expansions(self) -> None:
        multiplier, branch, owner = recipe_mastery_bonus(
            "Transmute: Truegold",
            "alchemy",
            recipe_expansion="cataclysm",
            known_by=["Alice"],
            mastery_index={"Alice": {"transmutation"}},
        )

        self.assertEqual(multiplier, 1.2)
        self.assertEqual(branch, "transmutation")
        self.assertEqual(owner, "Alice")

    def test_transmutation_mastery_accepts_display_names(self) -> None:
        multiplier, branch, owner = recipe_mastery_bonus(
            "Transmute: Living Steel",
            "alchemy",
            recipe_expansion="Mists of Pandaria",
            known_by=["Alice"],
            mastery_index={"Alice": {"transmutation"}},
        )

        self.assertEqual(multiplier, 1.2)
        self.assertEqual(branch, "transmutation")
        self.assertEqual(owner, "Alice")

    def test_transmutation_mastery_does_not_apply_to_modern_expansions(self) -> None:
        multiplier, branch, owner = recipe_mastery_bonus(
            "Transmute: Dracothyst",
            "alchemy",
            recipe_expansion="dragonflight",
            known_by=["Alice"],
            mastery_index={"Alice": {"transmutation"}},
        )

        self.assertEqual(multiplier, 1.0)
        self.assertIsNone(branch)
        self.assertIsNone(owner)


if __name__ == "__main__":
    unittest.main()
