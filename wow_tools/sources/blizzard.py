from __future__ import annotations

import base64
import json
import os
import re
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass
from typing import Any

from wow_tools.config import BLIZZARD_API_TIMEOUT, BLIZZARD_TOKEN_TTL_SECONDS


_REGION_ORIGINS = {
    "us": "us",
    "eu": "eu",
    "kr": "kr",
    "tw": "tw",
}


class BlizzardApiError(RuntimeError):
    """Raised when the Blizzard API cannot answer a request."""


@dataclass
class BlizzardResponse:
    payload: dict[str, Any]
    headers: dict[str, str]


def _credentials() -> tuple[str, str]:
    client_id = os.environ.get("BLIZZARD_CLIENT_ID", "").strip()
    client_secret = os.environ.get("BLIZZARD_CLIENT_SECRET", "").strip()
    if not client_id or not client_secret:
        raise BlizzardApiError(
            "Configure BLIZZARD_CLIENT_ID et BLIZZARD_CLIENT_SECRET avant d'interroger Blizzard."
        )
    return client_id, client_secret


class BlizzardClient:
    """Small client for the Retail dynamic EU namespace."""

    def __init__(self, *, timeout: int = BLIZZARD_API_TIMEOUT) -> None:
        self.timeout = timeout
        self._access_token: str | None = None
        self._token_expires_at = 0.0
        self._token_lock = threading.Lock()

    def _get_access_token(self) -> str:
        if self._access_token and time.time() < self._token_expires_at:
            return self._access_token
        with self._token_lock:
            if self._access_token and time.time() < self._token_expires_at:
                return self._access_token
            client_id, client_secret = _credentials()
            basic = base64.b64encode(f"{client_id}:{client_secret}".encode("utf-8")).decode("ascii")
            request = urllib.request.Request(
                "https://oauth.battle.net/token",
                data=urllib.parse.urlencode({"grant_type": "client_credentials"}).encode("ascii"),
                method="POST",
                headers={
                    "Authorization": f"Basic {basic}",
                    "Content-Type": "application/x-www-form-urlencoded",
                    "Accept": "application/json",
                    "User-Agent": "wow-tools/0.1",
                },
            )
            try:
                with urllib.request.urlopen(request, timeout=self.timeout) as response:
                    payload = json.loads(response.read().decode("utf-8"))
            except (urllib.error.HTTPError, urllib.error.URLError, json.JSONDecodeError) as exc:
                raise BlizzardApiError(f"Authentification Blizzard impossible: {exc}") from exc

            self._access_token = str(payload.get("access_token") or "")
            if not self._access_token:
                raise BlizzardApiError("Blizzard n'a pas renvoyé de jeton OAuth.")
            lifetime = int(payload.get("expires_in") or BLIZZARD_TOKEN_TTL_SECONDS)
            self._token_expires_at = time.time() + max(60, lifetime - 60)
            return self._access_token

    def get(self, path: str, region: str = "eu", *, locale: str | None = None) -> BlizzardResponse:
        region = region.lower()
        origin = _REGION_ORIGINS.get(region)
        if origin is None:
            raise ValueError(f"Région Blizzard inconnue: {region}")
        locale = locale or os.environ.get("BLIZZARD_LOCALE", "en_GB")
        query = urllib.parse.urlencode(
            {
                "namespace": f"dynamic-{region}",
                "locale": locale,
            }
        )
        url = f"https://{origin}.api.blizzard.com{path}?{query}"

        for attempt in range(3):
            request = urllib.request.Request(
                url,
                headers={
                    "Authorization": f"Bearer {self._get_access_token()}",
                    "Accept": "application/json",
                    "User-Agent": "wow-tools/0.1",
                },
            )
            try:
                with urllib.request.urlopen(request, timeout=self.timeout) as response:
                    raw = response.read().decode("utf-8")
                    payload = json.loads(raw)
                    headers = {key.lower(): value for key, value in response.headers.items()}
                    return BlizzardResponse(payload=payload, headers=headers)
            except urllib.error.HTTPError as exc:
                if exc.code == 401 and attempt == 0:
                    self._access_token = None
                    self._token_expires_at = 0
                    continue
                if exc.code not in {429, 500, 502, 503, 504}:
                    detail = exc.read().decode("utf-8", errors="replace")
                    raise BlizzardApiError(f"Blizzard HTTP {exc.code} sur {path}: {detail[:300]}") from exc
                retry_after = exc.headers.get("Retry-After")
                delay = float(retry_after) if retry_after and retry_after.isdigit() else 2 ** attempt
            except (urllib.error.URLError, TimeoutError, json.JSONDecodeError) as exc:
                if attempt == 2:
                    raise BlizzardApiError(f"Blizzard indisponible sur {path}: {exc}") from exc
                delay = 2 ** attempt
            time.sleep(delay)

        raise BlizzardApiError(f"Blizzard n'a pas répondu sur {path}")

    def connected_realms(self, region: str = "eu") -> list[dict[str, Any]]:
        index = self.get("/data/wow/connected-realm/index", region).payload
        hrefs = index.get("connected_realms") or []
        realms: list[dict[str, Any]] = []
        for record in hrefs:
            href = str(record.get("href") or "")
            match = re.search(r"/connected-realm/(\d+)", href)
            if not match:
                continue
            connected_realm_id = int(match.group(1))
            detail = self.get(f"/data/wow/connected-realm/{connected_realm_id}", region).payload
            realm_records = detail.get("realms") or []
            realm_names = [str(row.get("name") or "") for row in realm_records if row.get("name")]
            realm_slugs = [str(row.get("slug") or "") for row in realm_records if row.get("slug")]
            group_name = str(detail.get("name") or (realm_names[0] if realm_names else connected_realm_id))
            group_slug = str(detail.get("slug") or (realm_slugs[0] if realm_slugs else group_name))
            realms.append(
                {
                    "connected_realm_id": connected_realm_id,
                    "region": region.lower(),
                    "name": group_name,
                    "slug": group_slug,
                    "realm_names": realm_names,
                    "population": None,
                    "raw_payload": detail,
                }
            )
        return realms

    def auctions(self, connected_realm_id: int, region: str = "eu") -> BlizzardResponse:
        return self.get(f"/data/wow/connected-realm/{connected_realm_id}/auctions", region)

    def commodities(self, region: str = "eu") -> BlizzardResponse:
        return self.get("/data/wow/auctions/commodities", region)
