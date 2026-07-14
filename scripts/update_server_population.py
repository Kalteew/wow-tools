from __future__ import annotations

import json
from pathlib import Path
from urllib.request import Request, urlopen


ROOT = Path(__file__).resolve().parents[1]
SERVER_JSON_PATH = ROOT / "server.json"
GRAPHQL_URL = "https://worldofwarcraft.blizzard.com/en-us/graphql"
PERSISTED_QUERY_HASH = "b37e546366a58e211e922b8c96cd1ff74249f564a49029cc9737fef3300ff175"
REALM_ALIASES = {
    "revolving fjord": "howling fjord",
    "gor'dunni": "gordunni",
    "свежеватель душ": "soulflayer",
    "пиратская бухта": "booty bay",
    "коль-лич": "lich king",
    "дракономор": "fordragon",
    "азурегос": "azuregos",
    "вечная песня": "eversong",
    "well of eternity": "pozzo dell'eternità",
}


def fetch_realm_populations() -> dict[str, dict[str, str]]:
    payload = {
        "operationName": "GetRealmStatusData",
        "variables": {"input": {"compoundRegionGameVersionSlug": "eu"}},
        "extensions": {
            "persistedQuery": {
                "version": 1,
                "sha256Hash": PERSISTED_QUERY_HASH,
            }
        },
    }
    request = Request(
        GRAPHQL_URL,
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json", "User-Agent": "wow-tools/0.1"},
        method="POST",
    )
    with urlopen(request, timeout=30) as response:
        body = json.loads(response.read().decode("utf-8"))

    realms = body["data"]["Realms"]
    return {
        realm["name"].casefold(): {
            "population": realm["population"]["name"],
            "population_slug": realm["population"]["slug"],
            "population_enum": realm["population"]["enum"],
        }
        for realm in realms
    }


def realm_lookup_name(name: str) -> str:
    lookup = name
    if lookup.startswith("Connected "):
        lookup = lookup[len("Connected ") :]
    return REALM_ALIASES.get(lookup.casefold(), lookup)


def main() -> int:
    realms = fetch_realm_populations()
    servers = json.loads(SERVER_JSON_PATH.read_text(encoding="utf-8"))

    updated = 0
    missing: list[str] = []

    for entry in servers:
        lookup = realm_lookup_name(entry["name"]).casefold()
        realm = realms.get(lookup)
        if realm is None:
            missing.append(entry["name"])
            continue
        entry["population"] = realm["population"]
        entry["population_slug"] = realm["population_slug"]
        entry["population_enum"] = realm["population_enum"]
        updated += 1

    SERVER_JSON_PATH.write_text(
        json.dumps(servers, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )

    print(f"updated={updated}")
    if missing:
        print("missing:")
        for name in missing:
            print(f"- {name.encode('unicode_escape').decode('ascii')}")
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
