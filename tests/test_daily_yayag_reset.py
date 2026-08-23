from __future__ import annotations

import importlib.util
import unittest
from pathlib import Path


def _load_daily_reset_module():
    path = Path(__file__).parents[1] / "scripts" / "reports" / "daily_yayag_reset.py"
    spec = importlib.util.spec_from_file_location("daily_yayag_reset", path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Unable to load {path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class DailyYayagResetTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.mod = _load_daily_reset_module()

    def test_ratio_format_handles_no_recorded_sales(self) -> None:
        self.assertEqual(self.mod.fmt_ratio(None), "n/d")
        self.assertEqual(self.mod.fmt_ratio(13.17), "13.17")


if __name__ == "__main__":
    unittest.main()
