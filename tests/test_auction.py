import sqlite3
import unittest

from wow_tools.auction import (
    ItemVariantDecoder,
    _save_snapshot,
    aggregate_auctions,
    build_auction_report,
    suggest_auction_items,
)
from wow_tools.db import init_db


class AuctionHelpersTests(unittest.TestCase):
    def setUp(self) -> None:
        self.decoder = ItemVariantDecoder(
            {"123": {"class": 19, "itemLevel": 200}},
            {
            "names": {"9001": [10, 206]},
            "levelData": {"adjust": {"9001": [1, 6], "9002": [1, 12]}},
                "squishEras": [],
            },
        )

    def test_decoder_applies_item_bonus_level_and_suffix(self) -> None:
        item_level, item_suffix = self.decoder.decode({"id": 123, "bonus_lists": [9001]})
        self.assertEqual(item_level, 206)
        self.assertEqual(item_suffix, 206)

    def test_aggregate_uses_unit_price_for_stacks(self) -> None:
        grouped = aggregate_auctions(
            [
                {"item": {"id": 123, "bonus_lists": [9001]}, "quantity": 2, "buyout": 1000},
                {"item": {"id": 123, "bonus_lists": [9001]}, "quantity": 1, "buyout": 700},
            ],
            self.decoder,
            {123: "Test Loupes"},
        )
        row = next(iter(grouped.values()))
        self.assertEqual(row["item_level"], 206)
        self.assertEqual(row["min_unit_price_copper"], 500)
        self.assertEqual(row["available_quantity"], 3)
        self.assertEqual(row["listing_count"], 2)

    def test_report_returns_one_row_per_connected_group(self) -> None:
        conn = sqlite3.connect(":memory:")
        conn.row_factory = sqlite3.Row
        init_db(conn)
        conn.execute(
            "INSERT INTO auction_catalog (item_id, item_name, source, updated_at) VALUES (?, ?, ?, ?)",
            (123, "Test Loupes", "test", "now"),
        )
        conn.execute(
            """
            INSERT INTO auction_realms (
                connected_realm_id, region, name, slug, realm_names_json, population, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?)
            """,
            (42, "eu", "Connected Test", "connected-test", "[\"Test\"]", "Low", "now"),
        )
        grouped = aggregate_auctions(
            [{"item": {"id": 123, "bonus_lists": [9001]}, "quantity": 2, "buyout": 1000}],
            self.decoder,
            {123: "Test Loupes"},
        )
        _save_snapshot(
            conn,
            region="eu",
            connected_realm_id=42,
            source="test",
            aggregated=grouped,
            api_last_modified=None,
            auction_count=1,
        )
        report = build_auction_report(conn, "test loupes", "eu")
        self.assertEqual(report["realm_count"], 1)
        self.assertEqual(report["variants"][0]["label"], "Test Loupes (206)")
        self.assertEqual(report["variants"][0]["realm_rows"][0]["price_copper"], 500)
        self.assertEqual(report["variants"][0]["realm_rows"][0]["available_quantity"], 2)

    def test_suggestions_keep_rank_and_report_can_filter_it(self) -> None:
        conn = sqlite3.connect(":memory:")
        conn.row_factory = sqlite3.Row
        init_db(conn)
        conn.execute(
            "INSERT INTO auction_catalog (item_id, item_name, source, updated_at) VALUES (?, ?, ?, ?)",
            (123, "Test Loupes", "test", "now"),
        )
        conn.execute(
            """
            INSERT INTO auction_realms (
                connected_realm_id, region, name, slug, realm_names_json, population, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?)
            """,
            (42, "eu", "Connected Test", "connected-test", "[\"Test\"]", "Low", "now"),
        )
        grouped = aggregate_auctions(
            [
                {"item": {"id": 123, "bonus_lists": [9001]}, "quantity": 1, "buyout": 1000},
                {"item": {"id": 123, "bonus_lists": [9002]}, "quantity": 1, "buyout": 2000},
            ],
            self.decoder,
            {123: "Test Loupes"},
        )
        _save_snapshot(
            conn,
            region="eu",
            connected_realm_id=42,
            source="test",
            aggregated=grouped,
            api_last_modified=None,
            auction_count=2,
        )

        suggestions = suggest_auction_items(conn, "test loupes")
        self.assertEqual([row["display_name"] for row in suggestions], ["Test Loupes (206)", "Test Loupes (212)"])
        report = build_auction_report(conn, "test loupes", "eu", variant_key=suggestions[1]["variant_key"])
        self.assertEqual([row["label"] for row in report["variants"]], ["Test Loupes (212)"])

    def test_suggestions_include_catalog_items_and_match_inside_name(self) -> None:
        conn = sqlite3.connect(":memory:")
        conn.row_factory = sqlite3.Row
        init_db(conn)
        conn.execute(
            "INSERT INTO auction_catalog (item_id, item_name, source, updated_at) VALUES (?, ?, ?, ?)",
            (456, "Brilliant Alchemist's Stone", "test", "now"),
        )
        suggestions = suggest_auction_items(conn, "Alchemist's Stone")
        self.assertEqual(suggestions[0]["display_name"], "Brilliant Alchemist's Stone")
        self.assertIsNone(suggestions[0]["variant_key"])


if __name__ == "__main__":
    unittest.main()
