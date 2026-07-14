from __future__ import annotations

import hashlib
import json
import time
from dataclasses import dataclass
from pathlib import Path


@dataclass
class CacheHit:
    text: str
    fetched_at: float


class HttpCache:
    def __init__(self, base_dir: Path) -> None:
        self.base_dir = base_dir
        self.base_dir.mkdir(parents=True, exist_ok=True)

    def _stem(self, url: str) -> str:
        return hashlib.sha256(url.encode("utf-8")).hexdigest()

    def _body_path(self, url: str) -> Path:
        return self.base_dir / f"{self._stem(url)}.txt"

    def _meta_path(self, url: str) -> Path:
        return self.base_dir / f"{self._stem(url)}.json"

    def get(self, url: str, ttl_seconds: int) -> CacheHit | None:
        body_path = self._body_path(url)
        meta_path = self._meta_path(url)
        if not body_path.exists() or not meta_path.exists():
            return None

        try:
            meta = json.loads(meta_path.read_text(encoding="utf-8"))
            fetched_at = float(meta["fetched_at"])
        except Exception:
            return None

        age = time.time() - fetched_at
        if age > ttl_seconds:
            return None

        try:
            text = body_path.read_text(encoding="utf-8")
        except Exception:
            return None

        return CacheHit(text=text, fetched_at=fetched_at)

    def put(self, url: str, text: str) -> None:
        fetched_at = time.time()
        body_path = self._body_path(url)
        meta_path = self._meta_path(url)
        body_path.write_text(text, encoding="utf-8")
        meta_path.write_text(
            json.dumps(
                {
                    "url": url,
                    "fetched_at": fetched_at,
                },
                indent=2,
                sort_keys=True,
            ),
            encoding="utf-8",
        )
