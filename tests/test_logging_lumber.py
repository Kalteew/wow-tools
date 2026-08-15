from wow_tools.account_pipeline import _summarize_price_datasets
from wow_tools.logging_lumber import _lumber_price


def test_price_summary_exposes_avg_sell() -> None:
    summary = _summarize_price_datasets(
        {
            "AUCTIONDB_COMMODITY_SCAN_STAT": {"values": {"marketValue": 100}},
            "AUCTIONDB_REGION_SALE": {
                "values": {"regionSale": 250, "regionSalePercent": 20, "regionSoldPerDay": 30}
            },
        }
    )

    assert summary["region_sale_avg_copper"] == 250
    assert summary["sale_rate"] == 0.02
    assert summary["sold_per_day"] == 0.03


def test_lumber_price_prefers_avg_sell_with_fallback() -> None:
    assert _lumber_price({"region_sale_avg_copper": 250, "preferred_price_copper": 100}) == 250
    assert _lumber_price({"preferred_price_copper": 100}) == 100
