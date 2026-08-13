import os
from pathlib import Path


def _positive_env_int(name: str, default: int) -> int:
    try:
        return max(1, int(os.environ.get(name, str(default))))
    except ValueError:
        return default


ROOT_DIR = Path(__file__).resolve().parent.parent
DATA_DIR = ROOT_DIR / "data"
CACHE_DIR = DATA_DIR / "cache"
REPORT_DIR = DATA_DIR / "reports"
CALIBRATION_DIR = DATA_DIR / "calibration"
ACCOUNT_DIR = DATA_DIR / "account"
DB_PATH = DATA_DIR / "wow.sqlite3"
HOURLY_ESTIMATES_PATH = CALIBRATION_DIR / "hourly-estimates.json"

DEFAULT_REGION = "eu"
DEFAULT_HTTP_TIMEOUT = 30

WOWHEAD_LIST_TTL_SECONDS = 24 * 60 * 60
WOWHEAD_ITEM_TTL_SECONDS = 7 * 24 * 60 * 60
TSM_ITEM_TTL_SECONDS = 60 * 60

# Blizzard Retail Auction House integration.
BLIZZARD_API_TIMEOUT = 60
BLIZZARD_TOKEN_TTL_SECONDS = 23 * 60 * 60
BLIZZARD_CATALOG_TTL_SECONDS = 7 * 24 * 60 * 60
BLIZZARD_AUCTION_TTL_SECONDS = 30 * 60
AUCTION_SNAPSHOT_RETENTION_DAYS = _positive_env_int("WOW_AUCTION_RETENTION_DAYS", 30)
AUCTION_SNAPSHOT_RETENTION_PER_REALM = _positive_env_int("WOW_AUCTION_RETENTION_PER_REALM", 96)
