from __future__ import annotations

import html
import json
import re
import tempfile
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime, timezone
from pathlib import Path
from typing import Any
from urllib.parse import urljoin

from wow_tools.cache import HttpCache
from wow_tools.config import CACHE_DIR, ROOT_DIR
from wow_tools.http import fetch_text


WARCRAFT_MOUNTS_ROOT = "https://www.warcraftmounts.com/"
MOUNTS_CATALOG_PATH = ROOT_DIR / "data" / "mounts-catalog.json"
MOUNTS_CACHE_DIR = CACHE_DIR / "mounts"
MOUNTS_LIST_TTL_SECONDS = 7 * 24 * 60 * 60
MOUNTS_DETAIL_TTL_SECONDS = 30 * 24 * 60 * 60
MOUNTS_PAGE_SIZE = 25

_TAG_RE = re.compile(r"<[^>]+>", re.S)
_PATCH_RE = re.compile(r"\bPatch\s+(\d+)(?:\.\d+)?", re.I)
_WOWHEAD_RE = re.compile(r"href=['\"](https?://(?:www\.)?wowhead\.com/[^'\"]+)", re.I)
_EXPANSIONS = {
    1: "Classique",
    2: "The Burning Crusade",
    3: "Wrath of the Lich King",
    4: "Cataclysm",
    5: "Mists of Pandaria",
    6: "Warlords of Draenor",
    7: "Legion",
    8: "Battle for Azeroth",
    9: "Shadowlands",
    10: "Dragonflight",
    11: "The War Within",
    12: "Midnight",
}
_CATEGORY_LABELS = {
    "achievement": "Succès",
    "bmah": "Hôtel des ventes noir",
    "class": "Classe",
    "crafted": "Métier",
    "event": "Événement",
    "expansionfeature": "Fonctionnalité d’extension",
    "faction": "Race / faction",
    "loot": "Butin",
    "promo": "Promotion / boutique",
    "pvp": "JcJ",
    "quest": "Quête / exploration",
    "reputation": "Réputation",
    "retired": "Retirée",
    "unimplemented": "Non implémentée",
    "unused": "Apparence inutilisée",
    "vendor": "Vendeur",
}
_RMT_TERMS = (
    "blizzard shop",
    "trading card game",
    "collector's edition",
    "collector edition",
    "blizzcon",
    "recruit a friend",
    "recruit-a-friend",
    "real money",
    "promotional",
)


def _now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def _clean(value: str | None) -> str:
    if not value:
        return ""
    value = value.replace("<br>", " ").replace("<br/>", " ").replace("<br />", " ")
    return re.sub(r"\s+", " ", html.unescape(_TAG_RE.sub(" ", value))).strip()


def _absolute_url(value: str | None) -> str | None:
    if not value:
        return None
    return urljoin(WARCRAFT_MOUNTS_ROOT, html.unescape(value))


def parse_search_page(page: str) -> tuple[int | None, list[dict[str, Any]]]:
    total_match = re.search(r"of\s+([\d,]+)\s+mounts", page, re.I)
    total = int(total_match.group(1).replace(",", "")) if total_match else None
    records: list[dict[str, Any]] = []
    for row_match in re.finditer(r"<tr>(.*?)</tr>", page, re.I | re.S):
        cells = re.findall(r"<td[^>]*>(.*?)</td>", row_match.group(1), re.I | re.S)
        if len(cells) < 5:
            continue
        id_match = re.search(r"mount\.php\?mountid=(\d+)", cells[0], re.I)
        name_match = re.search(r"class=['\"]searchname['\"]>(.*?)</a>", cells[0], re.I | re.S)
        if not id_match or not name_match:
            continue
        image_match = re.search(r"<img[^>]+src=['\"]([^'\"]+)", cells[0], re.I)
        records.append(
            {
                "warcraft_mounts_id": int(id_match.group(1)),
                "name": _clean(name_match.group(1)),
                "list_image_url": _absolute_url(image_match.group(1)) if image_match else None,
                "required_level": _clean(cells[1]),
                "riding_skill": _clean(cells[2]),
                "travel_mode": _clean(cells[3]),
                "list_notes": _clean(cells[4]),
                "is_upcoming": "class='upcoming'" in cells[0].lower() or 'class="upcoming"' in cells[0].lower(),
            }
        )
    return total, records


def _section(page: str, heading: str) -> str:
    match = re.search(
        rf"<h3[^>]*>{re.escape(heading)}[^<]*</h3>(.*?)(?=<h3|</span></span>|<form class='mountimagebox')",
        page,
        re.I | re.S,
    )
    return _clean(match.group(1)) if match else ""


def _source_sections(page: str) -> list[str]:
    values = re.findall(r"<h3>Source\s+\d+:</h3>\s*<ul>(.*?)</ul>", page, re.I | re.S)
    return [_clean(value) for value in values if _clean(value)]


def _category(body_class: str) -> str:
    tokens = [token for token in body_class.split() if token != "mount"]
    for token in tokens:
        if token in _CATEGORY_LABELS:
            return token
    return tokens[0] if tokens else "unknown"


def _expansion(introduced: str) -> str:
    match = _PATCH_RE.search(introduced)
    return _EXPANSIONS.get(int(match.group(1)), "Inconnue") if match else "Inconnue"


def _time_gate(text: str, category: str) -> str:
    lowered = text.casefold()
    if category == "bmah" or "black market auction house" in lowered:
        return "bmah"
    if any(term in lowered for term in ("timewalking", "holiday", "festival", "trading post", "world event")):
        return "seasonal"
    if any(term in lowered for term in ("weekly", "once a week", "per week", "raid lockout")):
        return "weekly"
    if any(term in lowered for term in ("daily", "every day", "per day")):
        return "daily"
    if any(term in lowered for term in ("rare spawn", "rarely", "time-lost", "world boss")):
        return "rare_spawn"
    return "none"


def _is_rmt(category: str, text: str) -> bool:
    lowered = text.casefold()
    return category == "promo" or any(term in lowered for term in _RMT_TERMS)


def _availability(
    category: str,
    *,
    retired: bool,
    upcoming: bool,
    currently_obtainable: bool = True,
) -> tuple[str, bool]:
    if retired or category == "retired":
        return "retired", False
    if upcoming:
        return "upcoming", False
    if not currently_obtainable:
        return ("unimplemented" if category in {"unimplemented", "unused"} else "retired"), False
    if category in {"unimplemented", "unused"}:
        return "unimplemented", False
    return "available", True


def _reliability(category: str, text: str, availability: str, is_rmt: bool, time_gate: str) -> tuple[int, str]:
    if availability != "available" or is_rmt:
        return 0, "Indisponible / RMT"
    lowered = text.casefold()
    if any(term in lowered for term in ("guaranteed", "100%", "100 %", "certain")):
        return 100, "100 % garanti"
    if category in {"achievement", "class", "crafted", "event", "faction", "pvp", "quest", "reputation", "vendor"}:
        if time_gate != "none":
            return 95, "Garanti, avec délai"
        return 100, "100 % objectif"
    if time_gate in {"bmah", "rare_spawn"}:
        return 10, "Très aléatoire"
    if category in {"loot", "bmah"} or any(term in lowered for term in ("drop", "dropped", "chance", "rare")):
        return 25, "Drop aléatoire"
    if time_gate != "none":
        return 70, "Dépend de la période"
    return 60, "Obtention à confirmer"


def _time_estimate(category: str, text: str, availability: str, is_rmt: bool, time_gate: str) -> tuple[str, float | None]:
    if availability != "available" or is_rmt:
        return "—", None
    if time_gate == "bmah":
        return "Indéterminé (rotation BMAH)", None
    if time_gate == "rare_spawn":
        return "Indéterminé (apparition rare)", None
    if time_gate == "seasonal":
        return "1 session + attente de l’événement", None
    if time_gate == "weekly":
        return "1–8 semaines", 168.0
    if time_gate == "daily":
        return "1–4 semaines", 168.0
    lowered = text.casefold()
    if category in {"reputation", "faction"} or "exalted" in lowered:
        return "2–20 h", 2.0
    if category in {"achievement", "pvp"}:
        return "1–12 h", 1.0
    if category in {"quest", "event", "vendor", "class", "crafted"}:
        return "10 min–4 h", 0.2
    if category in {"loot", "bmah"} or "drop" in lowered or "chance" in lowered:
        return "Indéterminé (RNG)", None
    return "À estimer", None


def parse_mount_detail(page: str, listing: dict[str, Any]) -> dict[str, Any]:
    body_match = re.search(r"<body[^>]+class=['\"]([^'\"]+)", page, re.I)
    body_class = body_match.group(1) if body_match else "mount"
    category = _category(body_class)
    introduced = _section(page, "Introduced in:")
    sources = _source_sections(page)
    notes = _section(page, "Notes:")
    requirements = _section(page, "Riding Requirements:")
    text = " ".join([*sources, notes, requirements])
    # The default search result is the authoritative current-availability flag.
    # Source notes can mention retired historical rewards without making the mount retired.
    retired = "retired" in body_class.casefold()
    upcoming = bool(listing.get("is_upcoming")) or "upcoming" in body_class.casefold()
    availability, currently_obtainable = _availability(
        category,
        retired=retired,
        upcoming=upcoming,
        currently_obtainable=bool(listing.get("is_currently_obtainable", True)),
    )
    time_gate = _time_gate(text, category)
    is_rmt = _is_rmt(category, text)
    reliability_score, reliability_label = _reliability(category, text, availability, is_rmt, time_gate)
    estimate_label, estimate_hours = _time_estimate(category, text, availability, is_rmt, time_gate)
    image_match = re.search(r"property=['\"]og:image['\"] content=['\"]([^'\"]+)", page, re.I)
    if not image_match:
        image_match = re.search(r"class=['\"]mountimage['\"][^>]+src=['\"]([^'\"]+)", page, re.I)
    wowhead_urls = [_absolute_url(value) for value in _WOWHEAD_RE.findall(page)]
    wowhead_url = next((url for url in wowhead_urls if "/spell=" in (url or "")), None)
    wowhead_url = wowhead_url or next((url for url in wowhead_urls if "/item=" in (url or "")), None)
    wowhead_url = wowhead_url or (wowhead_urls[0] if wowhead_urls else None)
    mount_id_match = re.search(r"<h3[^>]*>Blizzard ID:</h3>\s*(\d+)", page, re.I)
    result = dict(listing)
    result.update(
        {
            "display_name": _clean(re.search(r"id=['\"]mountname['\"]>(.*?)</span>", page, re.I | re.S).group(1))
            if re.search(r"id=['\"]mountname['\"]>(.*?)</span>", page, re.I | re.S)
            else listing.get("name"),
            "category": category,
            "category_label": _CATEGORY_LABELS.get(category, category.title()),
            "sources": sources,
            "source_text": "\n".join(sources),
            "notes": notes,
            "requirements": requirements,
            "introduced": introduced,
            "expansion": _expansion(introduced),
            "image_url": _absolute_url(image_match.group(1)) if image_match else listing.get("list_image_url"),
            "wowhead_url": wowhead_url,
            "blizzard_id": int(mount_id_match.group(1)) if mount_id_match else None,
            "availability": availability,
            "currently_obtainable": currently_obtainable,
            "is_always_obtainable": currently_obtainable and time_gate == "none" and not is_rmt,
            "is_rmt": is_rmt,
            "time_gate": time_gate,
            "reliability_score": reliability_score,
            "reliability_label": reliability_label,
            "time_estimate": estimate_label,
            "estimated_hours": estimate_hours,
        }
    )
    return result


def _list_url(offset: int, *, include_retired: bool, include_upcoming: bool) -> str:
    url = f"{WARCRAFT_MOUNTS_ROOT}search.php?search=1&offset={offset}&side=2&sortby=name_asc"
    if include_retired:
        url += "&incretired=1"
    if include_upcoming:
        url += "&incupcoming=1"
    return url


def _fetch_listings(
    cache: HttpCache,
    *,
    force: bool,
    include_retired: bool,
    include_upcoming: bool,
    max_workers: int,
) -> tuple[int, dict[int, dict[str, Any]]]:
    first_page = fetch_text(
        _list_url(0, include_retired=include_retired, include_upcoming=include_upcoming),
        cache,
        MOUNTS_LIST_TTL_SECONDS,
        force=force,
    )
    total, first_records = parse_search_page(first_page)
    if not total:
        raise RuntimeError("Impossible de lire le nombre total de montures sur Warcraft Mounts.")
    records_by_id = {record["warcraft_mounts_id"]: record for record in first_records}
    offsets = range(MOUNTS_PAGE_SIZE, total, MOUNTS_PAGE_SIZE)
    with ThreadPoolExecutor(max_workers=max_workers) as executor:
        futures = {
            executor.submit(
                fetch_text,
                _list_url(offset, include_retired=include_retired, include_upcoming=include_upcoming),
                cache,
                MOUNTS_LIST_TTL_SECONDS,
                force=force,
            ): offset
            for offset in offsets
        }
        for future in as_completed(futures):
            _, records = parse_search_page(future.result())
            records_by_id.update({record["warcraft_mounts_id"]: record for record in records})
    return total, records_by_id


def sync_mount_catalog(
    output_path: Path = MOUNTS_CATALOG_PATH,
    *,
    force: bool = False,
    max_workers: int = 8,
) -> dict[str, Any]:
    cache = HttpCache(MOUNTS_CACHE_DIR)
    total, records_by_id = _fetch_listings(
        cache,
        force=force,
        include_retired=True,
        include_upcoming=True,
        max_workers=max_workers,
    )
    _, current_records = _fetch_listings(
        cache,
        force=force,
        include_retired=False,
        include_upcoming=False,
        max_workers=max_workers,
    )
    current_ids = set(current_records)
    for listing in records_by_id.values():
        listing["is_currently_obtainable"] = listing["warcraft_mounts_id"] in current_ids

    failures: list[dict[str, Any]] = []
    mounts: list[dict[str, Any]] = []
    detail_cache = HttpCache(MOUNTS_CACHE_DIR)

    def enrich(listing: dict[str, Any]) -> dict[str, Any]:
        mount_id = listing["warcraft_mounts_id"]
        url = f"{WARCRAFT_MOUNTS_ROOT}mount.php?mountid={mount_id}"
        try:
            page = fetch_text(url, detail_cache, MOUNTS_DETAIL_TTL_SECONDS, force=force)
            return parse_mount_detail(page, listing)
        except Exception as exc:  # keep the exhaustive index even if one page is transiently unavailable
            failures.append({"warcraft_mounts_id": mount_id, "error": str(exc)})
            fallback = dict(listing)
            fallback.update(
                {
                    "display_name": listing["name"],
                    "category": "unknown",
                    "category_label": "Inconnue",
                    "sources": [],
                    "source_text": "",
                    "notes": "",
                    "requirements": "",
                    "introduced": "",
                    "expansion": "Inconnue",
                    "image_url": listing.get("list_image_url"),
                    "wowhead_url": None,
                    "blizzard_id": None,
                    "availability": "upcoming" if listing.get("is_upcoming") else "available",
                    "currently_obtainable": bool(listing.get("is_currently_obtainable")) and not listing.get("is_upcoming", False),
                    "is_always_obtainable": False,
                    "is_rmt": False,
                    "time_gate": "unknown",
                    "reliability_score": 0,
                    "reliability_label": "Données incomplètes",
                    "time_estimate": "À vérifier",
                    "estimated_hours": None,
                }
            )
            return fallback

    with ThreadPoolExecutor(max_workers=max_workers) as executor:
        futures = [executor.submit(enrich, listing) for listing in records_by_id.values()]
        for future in as_completed(futures):
            mounts.append(future.result())

    mounts.sort(key=lambda row: (row.get("expansion", ""), row.get("display_name", "").casefold(), row["warcraft_mounts_id"]))
    payload = {
        "schema_version": 1,
        "source": "Warcraft Mounts",
        "source_url": f"{WARCRAFT_MOUNTS_ROOT}search.php?search=1&incretired=1&incupcoming=1",
        "synced_at": _now_iso(),
        "total_reported": total,
        "mounts": mounts,
        "detail_failures": failures,
    }
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile("w", encoding="utf-8", dir=output_path.parent, delete=False) as handle:
        json.dump(payload, handle, ensure_ascii=False, indent=2, sort_keys=True)
        temp_path = Path(handle.name)
    temp_path.replace(output_path)
    return {
        "count": len(mounts),
        "reported": total,
        "available": sum(1 for row in mounts if row.get("currently_obtainable")),
        "no_rmt": sum(1 for row in mounts if row.get("currently_obtainable") and not row.get("is_rmt")),
        "failures": len(failures),
        "path": str(output_path),
    }


def load_mount_catalog(path: Path = MOUNTS_CATALOG_PATH) -> dict[str, Any]:
    if not path.exists():
        return {"schema_version": 1, "mounts": [], "synced_at": None, "detail_failures": []}
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise RuntimeError(f"Catalogue de montures illisible: {path}: {exc}") from exc
    mounts = payload.get("mounts")
    if not isinstance(mounts, list):
        raise RuntimeError(f"Catalogue de montures invalide: {path}")
    return payload
