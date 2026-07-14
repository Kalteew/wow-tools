from __future__ import annotations

import importlib
import unittest


def _load_currency_value_module():
    try:
        return importlib.import_module("wow_tools.currency_value")
    except ModuleNotFoundError as exc:
        if exc.name == "wow_tools.currency_value":
            raise unittest.SkipTest("wow_tools.currency_value is not available yet") from exc
        raise


class CurrencyValueHelpersTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.mod = _load_currency_value_module()

    def test_extract_currency_for_listview_rows(self) -> None:
        html = """
        <script>
        new Listview({
            template: 'item',
            id: 'currency-for',
            data: [{"id":111,"name":"Charm Purchase","cost":[[0,[],[[163036,25]]]]}]
        });
        </script>
        """

        rows = self.mod._extract_currency_for_listview(html)

        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0]["id"], 111)
        self.assertEqual(rows[0]["name"], "Charm Purchase")

    def test_select_best_cost_prefers_lowest_polished_pet_charm_cost(self) -> None:
        row = {
            "id": 222,
            "name": "Battle Pet",
            "cost": [
                [0, [], [[163036, 20]]],
                [0, [], [[163036, 12]]],
                [500_000, [], []],
                [0, [], [[1220, 8]]],
            ],
        }

        best = self.mod._select_best_cost(row, currency_item_id=163036)

        self.assertEqual(best["type"], "item")
        self.assertEqual(best["item_id"], 163036)
        self.assertEqual(best["amount"], 12)
        self.assertEqual(best["cost_index"], 1)

    def test_select_best_cost_falls_back_to_gold_only_option(self) -> None:
        row = {
            "id": 333,
            "name": "Vendor Toy",
            "cost": [
                [250_000, [], []],
                [0, [[1813, 30]], []],
            ],
        }

        best = self.mod._select_best_cost(row, currency_item_id=163036)

        self.assertEqual(best["type"], "gold")
        self.assertEqual(best["copper"], 250_000)
        self.assertEqual(best["cost_index"], 0)


if __name__ == "__main__":
    unittest.main()
