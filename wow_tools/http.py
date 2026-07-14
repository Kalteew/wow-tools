from __future__ import annotations

import time
import urllib.error
import urllib.request

from wow_tools.cache import HttpCache
from wow_tools.config import DEFAULT_HTTP_TIMEOUT


USER_AGENT = "wow-tools/0.1 (+local cache)"


def fetch_text(
    url: str,
    cache: HttpCache,
    ttl_seconds: int,
    *,
    force: bool = False,
    timeout: int = DEFAULT_HTTP_TIMEOUT,
) -> str:
    if not force:
        cached = cache.get(url, ttl_seconds)
        if cached is not None:
            return cached.text

    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    last_error: Exception | None = None

    for attempt in range(3):
        try:
            with urllib.request.urlopen(request, timeout=timeout) as response:
                payload = response.read().decode("utf-8", errors="replace")
            cache.put(url, payload)
            return payload
        except urllib.error.HTTPError as exc:
            last_error = exc
            if exc.code not in {429, 500, 502, 503, 504}:
                raise
        except urllib.error.URLError as exc:
            last_error = exc

        time.sleep(1 + attempt)

    if last_error is not None:
        raise last_error
    raise RuntimeError(f"Failed to fetch {url}")
