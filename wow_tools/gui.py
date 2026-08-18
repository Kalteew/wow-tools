from __future__ import annotations

import threading
import traceback
from dataclasses import dataclass
from datetime import datetime, timezone
import hashlib
import io
import re
import socket
import statistics
import urllib.error
import urllib.request
import webbrowser
from pathlib import Path
from typing import Any

import tkinter as tk
from tkinter import messagebox, ttk

try:
    from PIL import Image, ImageTk
except ImportError:  # pragma: no cover - Pillow is bundled on the desktop app
    Image = None
    ImageTk = None

from wow_tools.auction import (
    build_auction_report,
    sync_auction_catalog,
    sync_auction_data,
    sync_auction_realms,
    suggest_auction_items,
)
from wow_tools.cache import HttpCache
from wow_tools.config import CACHE_DIR, DB_PATH, DEFAULT_REGION
from wow_tools.db import connect
from wow_tools.dynamic_recipe_profit import build_discovered_profit_report
from wow_tools.logging_lumber import build_logging_lumber_report
from wow_tools.mounts import load_mount_catalog, sync_mount_catalog
from wow_tools.profession_recipes import default_professions as default_recipe_professions, sync_profession_recipes
from wow_tools.recipe_catalog import default_favorite_spell_ids
from wow_tools.recipe_favorites import ensure_favorite_spell_ids, set_favorite_spell_id
from wow_tools.recipe_profit import build_recipe_profit_report, seed_recipe_items, sync_recipe_prices
from wow_tools.local_account import load_character_profession_scans, load_yaya_profession_specializations
from wow_tools.reports import format_copper, format_number
from wow_tools.sources.blizzard import BlizzardClient

_GUI_SINGLE_INSTANCE_HOST = "127.0.0.1"
_GUI_SINGLE_INSTANCE_PORT = 46321


@dataclass
class _TabState:
    name: str
    kind: str
    region_var: tk.StringVar
    top_var: tk.IntVar
    min_sale_rate_var: tk.StringVar
    sync_var: tk.BooleanVar
    force_var: tk.BooleanVar
    retail_root_var: tk.StringVar
    account_root_var: tk.StringVar
    item_ids_var: tk.StringVar | None
    summary_var: tk.StringVar
    run_button: ttk.Button
    favorite_button: ttk.Button
    global_tree: ttk.Treeview
    owned_tree: ttk.Treeview
    details_text: tk.Text
    row_lookup: dict[str, dict[str, Any]]
    current_report: dict[str, Any] | None


@dataclass
class _CharactersTabState:
    summary_var: tk.StringVar
    filter_var: tk.StringVar
    filter_combo: ttk.Combobox
    refresh_button: ttk.Button
    tree: ttk.Treeview
    details_text: tk.Text
    row_lookup: dict[str, dict[str, Any]]
    current_report: dict[str, Any] | None


@dataclass
class _SpecializationTabState:
    summary_var: tk.StringVar
    filter_var: tk.StringVar
    filter_combo: ttk.Combobox
    refresh_button: ttk.Button
    copy_button: ttk.Button
    tree: ttk.Treeview
    hero_var: tk.StringVar
    subhero_var: tk.StringVar
    setup_var: tk.StringVar
    source_var: tk.StringVar
    tips_var: tk.StringVar
    phases_tree: ttk.Treeview
    row_lookup: dict[str, dict[str, Any]]
    current_report: dict[str, Any] | None


@dataclass
class _LumberTabState:
    summary_var: tk.StringVar
    region_var: tk.StringVar
    sync_var: tk.BooleanVar
    force_var: tk.BooleanVar
    refresh_button: ttk.Button
    tree: ttk.Treeview
    details_text: tk.Text
    row_lookup: dict[str, dict[str, Any]]
    current_report: dict[str, Any] | None


@dataclass
class _AuctionTabState:
    summary_var: tk.StringVar
    region_var: tk.StringVar
    query_var: tk.StringVar
    available_only_var: tk.BooleanVar
    search_entry: ttk.Entry
    suggestions: tk.Listbox
    suggestion_rows: list[dict[str, Any]]
    autocomplete_after: str | None
    selected_variant_key: str | None
    sort_column: str
    sort_reverse: bool
    tree: ttk.Treeview
    details_text: tk.Text
    search_button: ttk.Button
    realms_button: ttk.Button
    sync_button: ttk.Button
    row_lookup: dict[str, dict[str, Any]]
    icon_images: dict[str, Any]
    current_report: dict[str, Any] | None


@dataclass
class _ExchangeTabState:
    region_var: tk.StringVar
    query_var: tk.StringVar
    summary_var: tk.StringVar
    title_var: tk.StringVar
    subtitle_var: tk.StringVar
    search_entry: ttk.Entry
    suggestions: tk.Listbox
    suggestion_rows: list[dict[str, Any]]
    autocomplete_after: str | None
    selected_variant_key: str | None
    search_button: ttk.Button
    sync_button: ttk.Button
    open_button: ttk.Button
    back_button: ttk.Button
    overview_frame: ttk.Frame
    detail_frame: ttk.Frame
    overview_tree: ttk.Treeview
    detail_tree: ttk.Treeview
    detail_icon_label: ttk.Label
    chart: tk.Canvas
    overview_lookup: dict[str, dict[str, Any]]
    detail_lookup: dict[str, dict[str, Any]]
    icon_images: dict[str, Any]
    current_report: dict[str, Any] | None
    current_variant: dict[str, Any] | None
    overview_updating: bool
    open_first_after_search: bool
    overview_sort_column: str
    overview_sort_reverse: bool
    detail_sort_column: str
    detail_sort_reverse: bool


@dataclass
class _MountsTabState:
    summary_var: tk.StringVar
    query_var: tk.StringVar
    expansion_var: tk.StringVar
    availability_var: tk.StringVar
    no_rmt_var: tk.BooleanVar
    sort_var: tk.StringVar
    force_var: tk.BooleanVar
    expansion_combo: ttk.Combobox
    refresh_button: ttk.Button
    tree: ttk.Treeview
    details_text: tk.Text
    image_label: tk.Label
    open_button: ttk.Button
    row_lookup: dict[str, dict[str, Any]]
    all_rows: list[dict[str, Any]]
    icon_images: dict[str, Any]
    current_payload: dict[str, Any] | None


_PRIMARY_PROFESSIONS = {
    "alchemy",
    "blacksmithing",
    "enchanting",
    "engineering",
    "herbalism",
    "inscription",
    "jewelcrafting",
    "leatherworking",
    "mining",
    "skinning",
    "tailoring",
}

_SPECIALIZATION_PLANS: dict[str, dict[str, Any]] = {
    "Alchemy": {
        "track": "Transmutes / daily CD",
        "focus": "faible effort",
        "why": "Wondrous Synergist + motes, simple a relancer et rentable meme sans babysit AH.",
        "phases": [
            "0-30 KP: 10 Transmutation Authority -> 20 Metamorphic Mastery",
            "30-50 KP: 20 Synthesis Synergy",
            "50-80 KP: 10 Alchemical Mastery -> 20 Reduce",
        ],
        "next_steps": [
            "Si tu veux plus de volume, garde un outil Multicraft pour les motes.",
            "Si tu veux pousser la qualite, finis Transmutation Authority puis Alchemical Mastery.",
        ],
        "source_label": "WoW-Professions Alchemy",
        "source_url": "https://www.wow-professions.com/midnight/alchemy-specialization-guide-and-builds",
    },
    "Blacksmithing": {
        "track": "Alloys AH",
        "focus": "volume",
        "why": "Les alliages servent partout; c'est le chemin le plus simple pour monnayer la concentration.",
        "phases": [
            "0-40 KP: 40 The Old Ways",
            "40-60 KP: 20 Prolific Worker",
            "60-80 KP: 20 Resourceful Smith ou push qualite or",
        ],
        "next_steps": [
            "Quand tes outils sont bons, vise la branche Gold Quality Alloys.",
            "Ensuite seulement, ouvre Tool Stones ou Weaponstones si le marche suit.",
        ],
        "source_label": "WoW-Professions Blacksmithing",
        "source_url": "https://www.wow-professions.com/midnight/blacksmithing-specialization-guide-and-builds",
    },
    "Enchanting": {
        "track": "Concentration pure",
        "focus": "ultra low effort",
        "why": "Le setup le plus propre pour te connecter, cramer la concentration, vendre un enchant premium, repartir.",
        "phases": [
            "0-20 KP: 20 Spellbound Shatterer",
            "20-50 KP: 30 Infinite Ingenuity",
            "50+ KP: ouvre 1 famille d'enchants rentable puis prends Responsible Resources",
        ],
        "next_steps": [
            "Priorite recettes: Weapon/Ring/Chest ou Helm/Shoulder/Boots.",
            "Pense a lancer Shatter Essence avant la session craft.",
        ],
        "source_label": "WoW-Professions Enchanting",
        "source_url": "https://www.wow-professions.com/midnight/enchanting-specialization-guide-and-builds",
    },
    "Engineering": {
        "track": "Profession gear / orders",
        "focus": "concentration",
        "why": "Setup simple pour craft des outils/accs a haute qualite avec peu de micro-gestion.",
        "phases": [
            "0-10 KP: 10 Mandatory Tools ou Finishing Touches",
            "10-35 KP: 25 Market Mobility",
            "35-65 KP: 30 Recycling",
            "65-95 KP: 30 sous-spec choisie",
        ],
        "next_steps": [
            "Si tu fais surtout des reagents, garde un outil Multicraft en swap.",
            "Sinon pousse Resourcefulness pour economiser les mats sur les orders.",
        ],
        "source_label": "WoW-Professions Engineering",
        "source_url": "https://www.wow-professions.com/midnight/engineering-specialization-guide-and-builds",
    },
    "Herbalism": {
        "track": "Double gather / rendement",
        "focus": "gathering QoL",
        "why": "Le meilleur confort reste le mounted gather puis le rendement global sur toutes les herbes.",
        "phases": [
            "Druide 0-40 KP: 40 Bountiful Harvests",
            "Non-druide 0-40 KP: 40 Botany",
            "Puis 40-80 KP: 40 Bountiful Harvests",
            "80+ KP: specialise les herbes les plus cheres",
        ],
        "next_steps": [
            "Priorite metier: herbe la plus chere du moment pour plus de skill et de lotus.",
            "Overload seulement si les motes deviennent vraiment tres chers.",
        ],
        "source_label": "WoW-Professions Herbalism",
        "source_url": "https://www.wow-professions.com/midnight/herbalism-specialization-guide-and-builds",
    },
    "Inscription": {
        "track": "Missives / Contracts",
        "focus": "consommables",
        "why": "Workflow propre pour vendre en boucle des consommables et monter une base de qualite.",
        "phases": [
            "0-50 KP: 10 Calm Hands -> 20 Dextrous Diligence -> 20 Keen Eye",
            "50-140 KP: 30 sous-spec choisie -> 30 Parchment -> 30 Perfected Products",
        ],
        "next_steps": [
            "Choisis 1 ligne: Missives, Contracts ou Vantus et va au bout avant de split.",
            "Si tu veux plus de marge jour 1, tu peux rush la chaine Gold Quality avant Calm Hands.",
        ],
        "source_label": "WoW-Professions Inscription",
        "source_url": "https://www.wow-professions.com/midnight/inscription-specialization-guide-and-builds",
    },
    "Jewelcrafting": {
        "track": "Gemcutting AH",
        "focus": "volume",
        "why": "Les gems restent le chemin le plus simple a vendre en boucle sans attendre des orders.",
        "phases": [
            "0-5 KP: 5 Thoughtful Throughput",
            "5-35 KP: 30 Outrageous Output",
            "35-45 KP: 10 Thoughtful Throughput",
            "45-75 KP: 30 Skilled Savings",
        ],
        "next_steps": [
            "Ensuite specialise 1 couleur via Glamorous Gems pour atteindre la qualite or.",
            "Pour bijoux/orders, fais plutot 30 Alluring Accessories puis 40 sous-spec choisie.",
        ],
        "source_label": "WoW-Professions Jewelcrafting",
        "source_url": "https://www.wow-professions.com/midnight/jewelcrafting-specialization-guide-and-builds",
    },
    "Leatherworking": {
        "track": "Profession gear",
        "focus": "simple orders",
        "why": "Chemin direct et lisible: un investissement unique, puis tu peux pivoter sur resourcefulness ou armor.",
        "phases": [
            "0-30 KP: 30 Flawless Fortes",
            "30-60 KP: 30 Artisanal Accessories",
            "60-90 KP: 30 Waning Waste ou armor branch si besoin",
        ],
        "next_steps": [
            "Si tu veux plutot armor perso/orders: 30 root + 30 branche gauche/droite + 20 slot.",
            "Pour alt-army rapide, l'approche concentration via Learned Leatherworker reste propre.",
        ],
        "source_label": "WoW-Professions Leatherworking",
        "source_url": "https://www.wow-professions.com/midnight/leatherworking-specialization-guide-and-builds",
    },
    "Mining": {
        "track": "Double gather / rendement",
        "focus": "gathering QoL",
        "why": "Le plus gros gain pratique est le mounted mining, puis le skill global sur tous les minerais.",
        "phases": [
            "0-40 KP: 40 Meticulous Mining",
            "40-90 KP: 50 Plentiful Ores",
            "90+ KP: remplis les minerais les plus rentables",
        ],
        "next_steps": [
            "Si un minerai explose le marche, maxe-le avant les autres.",
            "Over-LODED seulement si les motes montent vraiment en valeur.",
        ],
        "source_label": "WoW-Professions Mining",
        "source_url": "https://www.wow-professions.com/midnight/mining-specialization-guide-and-builds",
    },
    "Skinning": {
        "track": "Hides / reagents rares",
        "focus": "gathering ciblé",
        "why": "Skinning profite bien d'un plan simple axe rares/hides plutot qu'un build disperse.",
        "phases": [
            "0-40 KP: monte la branche de tracking/tanning a 40",
            "40-80 KP: pousse la sous-spec du type de reagent vise a 40",
            "80+ KP: renforce le 2e type de cuir/ecaille que tu farm le plus",
        ],
        "next_steps": [
            "Objectif pratique: plus de reagents rares par skin avant de diversifier.",
            "Ici le preset est plus guide que script exact, car les routes Skinning Midnight ont plus bouge.",
        ],
        "source_label": "Wowhead Skinning",
        "source_url": "https://www.wowhead.com/guide/midnight/professions/skinning-overview-trainer-locations-hides-tracking-tools",
    },
    "Tailoring": {
        "track": "Bolts / CDs",
        "focus": "passif + volume",
        "why": "Bonne base alt-army: cooldowns, bolts et mats qui tournent sans devoir vendre du gear en continu.",
        "phases": [
            "0-20 KP: 20 Nimble Needlework",
            "20-50 KP: 30 Creative Efficiency",
            "50-90 KP: 10 Fiber Arts -> 30 Textile Utilization",
        ],
        "next_steps": [
            "Si tu veux surtout les CDs: ajoute 15 dans le 2e noeud puis 20 dans Arcanoweave ou Sunfire.",
            "Si tu mass craft les bolts, garde Multicraft puis Resourcefulness en prio.",
        ],
        "source_label": "WoW-Professions Tailoring",
        "source_url": "https://www.wow-professions.com/midnight/tailoring-specialization-guide-and-builds",
    },
}

_SPECIALIZATION_COMPLEMENTS: dict[str, list[str]] = {
    "Alchemy": ["Enchanting", "Tailoring", "Inscription"],
    "Blacksmithing": ["Inscription", "Enchanting", "Jewelcrafting"],
    "Enchanting": ["Tailoring", "Inscription", "Alchemy"],
    "Engineering": ["Mining", "Enchanting", "Alchemy"],
    "Herbalism": ["Alchemy", "Inscription", "Tailoring"],
    "Inscription": ["Enchanting", "Alchemy", "Tailoring"],
    "Jewelcrafting": ["Mining", "Enchanting", "Alchemy"],
    "Leatherworking": ["Skinning", "Enchanting", "Alchemy"],
    "Mining": ["Jewelcrafting", "Engineering", "Blacksmithing"],
    "Skinning": ["Leatherworking", "Alchemy", "Enchanting"],
    "Tailoring": ["Enchanting", "Alchemy", "Inscription"],
}

_SPECIALIZATION_DECISIONS: dict[str, list[dict[str, Any]]] = {
    "Alchemy": [
        {"node": "Transmutation Authority", "target": 10, "label": "ouvre l'axe transmute"},
        {"node": "Metamorphic Mastery", "target": 20, "label": "monte la valeur du transmute"},
        {"node": "Synthesis Synergy", "target": 20, "label": "ajoute la couche motes/synergy"},
        {"node": "Alchemical Mastery", "target": 10, "label": "stabilise la qualite"},
    ],
    "Blacksmithing": [
        {"node": "The Old Ways", "target": 40, "label": "rush la base alliages"},
        {"node": "Prolific Worker", "target": 20, "label": "augmente le volume"},
        {"node": "Resourceful Smith", "target": 20, "label": "ameliore la marge"},
    ],
    "Enchanting": [
        {"node": "Spellbound Shatterer", "target": 20, "label": "securise la base concentration"},
        {"node": "Infinite Ingenuity", "target": 30, "label": "maxe le coeur du setup"},
        {"node": "Responsible Resources", "target": 20, "label": "gratte la marge"},
    ],
    "Engineering": [
        {"node": "Market Mobility", "target": 25, "label": "ouvre le setup orders"},
        {"node": "Recycling", "target": 30, "label": "gagne en marge"},
    ],
    "Herbalism": [
        {"node": "Botany", "target": 40, "label": "prend le confort de farm"},
        {"node": "Bountiful Harvests", "target": 40, "label": "monte le rendement global"},
    ],
    "Inscription": [
        {"node": "Calm Hands", "target": 10, "label": "ouvre la ligne propre"},
        {"node": "Dextrous Diligence", "target": 20, "label": "ameliore la qualite"},
        {"node": "Keen Eye", "target": 20, "label": "stabilise le resultat"},
        {"node": "Perfected Products", "target": 30, "label": "pousse la qualite finale"},
    ],
    "Jewelcrafting": [
        {"node": "Thoughtful Throughput", "target": 15, "label": "ouvre la ligne gems"},
        {"node": "Outrageous Output", "target": 30, "label": "monte le volume"},
        {"node": "Skilled Savings", "target": 30, "label": "ameliore la marge"},
    ],
    "Leatherworking": [
        {"node": "Flawless Fortes", "target": 30, "label": "ouvre le coeur profession gear"},
        {"node": "Artisanal Accessories", "target": 30, "label": "valide le setup orders"},
        {"node": "Waning Waste", "target": 30, "label": "gratte la marge"},
    ],
    "Mining": [
        {"node": "Meticulous Mining", "target": 40, "label": "prend le confort de mine"},
        {"node": "Plentiful Ores", "target": 50, "label": "monte le rendement global"},
    ],
    "Skinning": [
        {"node": None, "target": 40, "label": "finis la branche rare / tracking que tu as commencee"},
        {"node": None, "target": 40, "label": "puis maxe le type de cuir le plus rentable"},
    ],
    "Tailoring": [
        {"node": "Nimble Needlework", "target": 20, "label": "ouvre la ligne bolts"},
        {"node": "Creative Efficiency", "target": 30, "label": "monte la marge"},
        {"node": "Fiber Arts", "target": 10, "label": "ouvre le sous-noeud mats"},
        {"node": "Textile Utilization", "target": 30, "label": "pousse le rendement"},
    ],
}


def _normalize_spec_label(value: str | None) -> str:
    return re.sub(r"[^a-z0-9]+", "", (value or "").casefold())


def _is_specialization_tab_profession(profession: dict[str, Any]) -> bool:
    profession_name = str(profession.get("name") or "").casefold()
    if profession_name in _PRIMARY_PROFESSIONS:
        return True
    return profession_name == "cooking" and "midnight cooking" in str(profession.get("current_level_name") or "").casefold()


def _format_exchange_age(value: Any) -> str:
    raw = str(value or "").strip()
    if not raw:
        return "-"
    try:
        fetched_at = datetime.fromisoformat(raw.replace("Z", "+00:00"))
        age = max(0, int((datetime.now(timezone.utc) - fetched_at).total_seconds()))
    except (TypeError, ValueError):
        return raw
    if age < 60:
        return "à l’instant"
    if age < 3600:
        return f"il y a {age // 60} min"
    if age < 86400:
        return f"il y a {age // 3600} h"
    return f"il y a {age // 86400} j"


def _format_exchange_price(value: Any) -> str:
    if value is None:
        return "-"
    copper = int(value)
    gold, remainder = divmod(copper, 10_000)
    silver, copper = divmod(remainder, 100)
    if gold:
        parts = [f"{gold:,}g"]
        if silver:
            parts.append(f"{silver:02d}s")
        if copper:
            parts.append(f"{copper:02d}c")
        return " ".join(parts)
    if silver:
        return f"{silver}s {copper:02d}c"
    return f"{copper}c"


def _format_lumber_profession(value: Any) -> str:
    raw = str(value or "").strip()
    return raw.replace("_", " ").title() if raw else "-"


class ProfitabilityGui:
    def __init__(self, root: tk.Tk):
        self.root = root
        self.root.title("WoW Tools - Marché EU")
        # Keep the native Windows frame so the app appears in the taskbar and Alt-Tab.
        self.root.overrideredirect(False)
        self.root.configure(background="#0b0908")
        self.root.geometry("1400x900+60+40")
        self.root.minsize(1100, 760)
        self._setup_style()
        self._build_window_chrome()
        self._tabs: list[_TabState] = []

        conn = connect(DB_PATH)
        ensure_favorite_spell_ids(conn, default_favorite_spell_ids())
        conn.close()

        container = ttk.Frame(self.content_host, padding=12, style="Exchange.TFrame")
        container.pack(fill="both", expand=True)

        notebook = ttk.Notebook(container)
        notebook.pack(fill="both", expand=True)

        self.recipes_tab = self._build_tab(notebook, "Recettes", kind="recipes")
        self.favorites_tab = self._build_tab(notebook, "Favoris", kind="favorites")
        self.discovered_tab = self._build_tab(notebook, "Découvertes", kind="discovered")
        self.characters_tab = self._build_characters_tab(notebook)
        self._refresh_character_tab(self.characters_tab)
        self.specialization_tab = self._build_specialization_tab(notebook)
        self._refresh_specialization_tab(self.specialization_tab)
        self.lumber_tab = self._build_lumber_tab(notebook)
        self._refresh_lumber_tab(self.lumber_tab)
        self.mounts_tab = self._build_mounts_tab(notebook)
        self._load_mounts_tab(self.mounts_tab)
        self.auction_tab = self._build_auction_tab(notebook)
        self.exchange_tab = self._build_exchange_tab(notebook)
        notebook.select(notebook.tabs()[-1])
        self.root.after(500, lambda: self._start_exchange_search(self.exchange_tab))

    def _build_window_chrome(self) -> None:
        shell = tk.Frame(
            self.root,
            background="#7d6428",
            highlightbackground="#b1923a",
            highlightcolor="#b1923a",
            highlightthickness=1,
        )
        shell.pack(fill="both", expand=True, padx=4, pady=4)
        self.window_shell = shell

        titlebar = tk.Frame(shell, background="#241b19", height=30)
        titlebar.pack(fill="x", padx=2, pady=(2, 0))
        titlebar.pack_propagate(False)
        self.titlebar = titlebar

        title = tk.Label(
            titlebar,
            text="WoW Tools  ·  Marché EU",
            background="#241b19",
            foreground="#f1c62f",
            font=("Segoe UI", 10, "bold"),
            anchor="w",
            padx=10,
        )
        title.pack(side="left", fill="both", expand=True)

        close_button = tk.Button(
            titlebar,
            text="×",
            command=self.root.destroy,
            background="#760000",
            foreground="#ffe36a",
            activebackground="#a51a10",
            activeforeground="#fff1c2",
            relief="flat",
            borderwidth=0,
            font=("Segoe UI Symbol", 13, "bold"),
            width=3,
            cursor="hand2",
        )
        close_button.pack(side="right", fill="y", padx=(0, 2), pady=2)

        self.content_host = tk.Frame(shell, background="#111010")
        self.content_host.pack(fill="both", expand=True, padx=2, pady=(0, 2))

        titlebar.bind("<ButtonPress-1>", self._start_window_drag)
        titlebar.bind("<B1-Motion>", self._drag_window)
        title.bind("<ButtonPress-1>", self._start_window_drag)
        title.bind("<B1-Motion>", self._drag_window)

    def _start_window_drag(self, event: tk.Event) -> None:
        self._window_drag_offset = (
            event.x_root - self.root.winfo_x(),
            event.y_root - self.root.winfo_y(),
        )

    def _drag_window(self, event: tk.Event) -> None:
        offset_x, offset_y = getattr(self, "_window_drag_offset", (0, 0))
        self.root.geometry(f"+{event.x_root - offset_x}+{event.y_root - offset_y}")

    def _setup_style(self) -> None:
        style = ttk.Style(self.root)
        for theme in ("clam", "vista", "default"):
            if theme in style.theme_names():
                style.theme_use(theme)
                break
        style.configure("Header.TLabel", font=("Segoe UI", 12, "bold"))
        style.configure("Summary.TLabel", font=("Segoe UI", 10))
        style.configure("SpecHero.TLabel", font=("Segoe UI", 14, "bold"))
        style.configure("SpecSubhero.TLabel", font=("Segoe UI", 10))
        style.configure("SpecKey.TLabel", font=("Segoe UI", 9, "bold"))
        style.configure("SpecValue.TLabel", font=("Segoe UI", 10))
        style.configure("AuctionTitle.TLabel", font=("Segoe UI", 17, "bold"), foreground="#173b63")
        style.configure("AuctionSubtitle.TLabel", font=("Segoe UI", 9), foreground="#687483")
        style.configure("AuctionKey.TLabel", font=("Segoe UI", 9, "bold"))
        style.configure("AuctionAccent.TButton", font=("Segoe UI", 9, "bold"))
        style.configure("Auction.Treeview", rowheight=34, font=("Segoe UI", 10))
        style.configure("Auction.Treeview.Heading", font=("Segoe UI", 9, "bold"))
        style.configure("Category.TLabel", anchor="w", font=("Segoe UI", 9), padding=(8, 5))

        exchange_bg = "#111010"
        exchange_panel = "#1c1818"
        exchange_bar = "#2d2524"
        exchange_gold = "#f1c62f"
        exchange_text = "#eee9e2"
        exchange_muted = "#b8aaa0"
        exchange_red = "#760000"
        style.configure("Exchange.TFrame", background=exchange_bg)
        style.configure("Exchange.TPanedwindow", background=exchange_bg)
        style.configure("Exchange.TLabel", background=exchange_bg, foreground=exchange_text)
        style.configure("Exchange.Title.TLabel", background=exchange_bg, foreground=exchange_gold, font=("Segoe UI", 17, "bold"))
        style.configure("Exchange.Muted.TLabel", background=exchange_bg, foreground=exchange_muted, font=("Segoe UI", 9))
        style.configure("Exchange.Key.TLabel", background=exchange_panel, foreground=exchange_gold, font=("Segoe UI", 9, "bold"))
        style.configure("Exchange.TLabelframe", background=exchange_bg, foreground=exchange_gold, bordercolor="#51453d", relief="solid")
        style.configure("Exchange.TLabelframe.Label", background=exchange_bg, foreground=exchange_gold, font=("Segoe UI", 9, "bold"))
        style.configure("Exchange.Category.TLabel", background=exchange_bar, foreground=exchange_gold, anchor="w", padding=(9, 5), font=("Segoe UI", 9, "bold"))
        style.configure("Exchange.TButton", background=exchange_red, foreground=exchange_gold, bordercolor="#b69a32", lightcolor="#a91b12", darkcolor="#3b0000", padding=(12, 5), font=("Segoe UI", 9, "bold"))
        style.map("Exchange.TButton", background=[("active", "#a51a10"), ("pressed", "#4b0000")], foreground=[("disabled", "#77706b"), ("!disabled", exchange_gold)])
        style.configure("Exchange.TEntry", fieldbackground=exchange_panel, foreground=exchange_text, insertcolor=exchange_gold, bordercolor="#66544a")
        style.configure("Exchange.TCombobox", fieldbackground=exchange_panel, background=exchange_panel, foreground=exchange_text, arrowcolor=exchange_gold, bordercolor="#66544a")
        style.map("Exchange.TCombobox", fieldbackground=[("readonly", exchange_panel)], foreground=[("readonly", exchange_text)])
        style.configure("Exchange.Treeview", background=exchange_bg, fieldbackground=exchange_bg, foreground=exchange_text, rowheight=32, font=("Segoe UI", 10), bordercolor="#51453d")
        style.configure("Exchange.Treeview.Heading", background=exchange_bar, foreground=exchange_gold, relief="flat", font=("Segoe UI", 9, "bold"))
        style.map("Exchange.Treeview", background=[("selected", "#75170f")], foreground=[("selected", "#fff1c2")])
        style.configure("Exchange.TScrollbar", background=exchange_bar, troughcolor=exchange_bg, bordercolor=exchange_bg, arrowcolor=exchange_gold)
        style.configure("TNotebook", background=exchange_bg, borderwidth=0)
        style.configure("TNotebook.Tab", background=exchange_bar, foreground=exchange_gold, padding=(12, 5), font=("Segoe UI", 9, "bold"))
        style.map("TNotebook.Tab", background=[("selected", exchange_red)], foreground=[("selected", "#fff1c2")])

    def _build_tab(self, notebook: ttk.Notebook, title: str, *, kind: str) -> _TabState:
        frame = ttk.Frame(notebook, padding=10)
        notebook.add(frame, text=title)
        frame.columnconfigure(0, weight=1)
        frame.rowconfigure(2, weight=1)
        frame.rowconfigure(3, weight=1)

        controls = ttk.LabelFrame(frame, text="Paramètres", padding=10)
        controls.grid(row=0, column=0, sticky="ew")
        for column in range(6):
            controls.columnconfigure(column, weight=1 if column in (1, 3, 5) else 0)

        region_var = tk.StringVar(value=DEFAULT_REGION.upper())
        discovered = kind == "discovered"
        top_var = tk.IntVar(value=0 if not discovered else 20)
        min_sale_rate_var = tk.StringVar(value="0.0")
        sync_var = tk.BooleanVar(value=False)
        force_var = tk.BooleanVar(value=False)
        retail_root_var = tk.StringVar()
        account_root_var = tk.StringVar()
        item_ids_var = tk.StringVar(value="95416, 65891") if discovered else None
        summary_var = tk.StringVar(value="Prêt")

        row = 0
        if discovered and item_ids_var is not None:
            ttk.Label(controls, text="Item IDs").grid(row=row, column=0, sticky="w", padx=(0, 8), pady=4)
            ttk.Entry(controls, textvariable=item_ids_var).grid(
                row=row, column=1, columnspan=5, sticky="ew", pady=4
            )
            row += 1

        ttk.Label(controls, text="Région").grid(row=row, column=0, sticky="w", padx=(0, 8), pady=4)
        ttk.Combobox(controls, textvariable=region_var, values=["EU", "US"], state="readonly", width=8).grid(
            row=row, column=1, sticky="w", pady=4
        )
        ttk.Label(controls, text="Top (0 = tout)").grid(row=row, column=2, sticky="w", padx=(12, 8), pady=4)
        ttk.Spinbox(controls, from_=0, to=100000, textvariable=top_var, width=10).grid(
            row=row, column=3, sticky="w", pady=4
        )
        ttk.Label(controls, text="Sell rate min").grid(row=row, column=4, sticky="w", padx=(12, 8), pady=4)
        ttk.Entry(controls, textvariable=min_sale_rate_var, width=10).grid(row=row, column=5, sticky="w", pady=4)
        row += 1

        ttk.Label(controls, text="Retail root").grid(row=row, column=0, sticky="w", padx=(0, 8), pady=4)
        ttk.Entry(controls, textvariable=retail_root_var).grid(row=row, column=1, columnspan=2, sticky="ew", pady=4)
        ttk.Label(controls, text="Account root").grid(row=row, column=3, sticky="w", padx=(12, 8), pady=4)
        ttk.Entry(controls, textvariable=account_root_var).grid(row=row, column=4, columnspan=2, sticky="ew", pady=4)
        row += 1

        checks = ttk.Frame(controls)
        checks.grid(row=row, column=0, columnspan=6, sticky="ew", pady=(6, 0))
        ttk.Checkbutton(checks, text="Sync prices avant analyse", variable=sync_var).pack(side="left")
        ttk.Checkbutton(checks, text="Force refresh", variable=force_var).pack(side="left", padx=(12, 0))
        favorite_button = ttk.Button(checks, text="Basculer favori")
        favorite_button.pack(side="right")
        run_button = ttk.Button(checks, text="Analyser")
        run_button.pack(side="right", padx=(0, 8))

        ttk.Label(frame, textvariable=summary_var, style="Summary.TLabel").grid(
            row=1, column=0, sticky="ew", pady=(10, 8)
        )

        results = ttk.Panedwindow(frame, orient="vertical")
        results.grid(row=2, column=0, sticky="nsew")

        trees = ttk.Panedwindow(results, orient="horizontal")
        results.add(trees, weight=4)

        global_tree = self._build_tree(trees, "Global")
        owned_tree = self._build_tree(trees, "Possédées")

        details_box = ttk.LabelFrame(frame, text="Détails", padding=8)
        details_box.grid(row=3, column=0, sticky="nsew", pady=(10, 0))
        details_box.columnconfigure(0, weight=1)
        details_box.rowconfigure(0, weight=1)
        details_text = tk.Text(details_box, wrap="word", height=10, font=("Consolas", 10))
        details_text.grid(row=0, column=0, sticky="nsew")
        details_text.configure(state="disabled")

        state = _TabState(
            name=title,
            kind=kind,
            region_var=region_var,
            top_var=top_var,
            min_sale_rate_var=min_sale_rate_var,
            sync_var=sync_var,
            force_var=force_var,
            retail_root_var=retail_root_var,
            account_root_var=account_root_var,
            item_ids_var=item_ids_var,
            summary_var=summary_var,
            run_button=run_button,
            favorite_button=favorite_button,
            global_tree=global_tree,
            owned_tree=owned_tree,
            details_text=details_text,
            row_lookup={},
            current_report=None,
        )
        run_button.configure(command=lambda current=state: self._start_analysis(current))
        favorite_button.configure(command=lambda current=state: self._toggle_favorite(current))
        for tree in (global_tree, owned_tree):
            tree.bind("<<TreeviewSelect>>", lambda event, current=state: self._show_selected_row(current, event.widget))
        self._tabs.append(state)
        return state

    def _build_tree(self, parent: ttk.Panedwindow, title: str) -> ttk.Treeview:
        frame = ttk.LabelFrame(parent, text=title, padding=8)
        parent.add(frame, weight=1)
        frame.columnconfigure(0, weight=1)
        frame.rowconfigure(0, weight=1)

        columns = ("item", "profession", "recipe", "profit", "score", "sale_rate", "sold", "ownership")
        tree = ttk.Treeview(frame, columns=columns, show="headings", height=12)
        tree.grid(row=0, column=0, sticky="nsew")

        headings = {
            "item": ("Item", 220),
            "profession": ("Métier", 110),
            "recipe": ("Recette", 220),
            "profit": ("Profit", 110),
            "score": ("Score", 80),
            "sale_rate": ("Sell rate", 80),
            "sold": ("Ventes/j", 90),
            "ownership": ("Possession", 240),
        }
        for column, (label, width) in headings.items():
            tree.heading(column, text=label)
            tree.column(column, width=width, anchor="w")

        scrollbar = ttk.Scrollbar(frame, orient="vertical", command=tree.yview)
        scrollbar.grid(row=0, column=1, sticky="ns")
        tree.configure(yscrollcommand=scrollbar.set)
        return tree

    def _build_characters_tab(self, notebook: ttk.Notebook) -> _CharactersTabState:
        frame = ttk.Frame(notebook, padding=10)
        notebook.add(frame, text="Personnages")
        frame.columnconfigure(0, weight=1)
        frame.rowconfigure(2, weight=3)
        frame.rowconfigure(3, weight=2)

        header = ttk.Frame(frame)
        header.grid(row=0, column=0, sticky="ew")
        header.columnconfigure(0, weight=1)
        ttk.Label(header, text="Personnages et métiers scannés", style="Header.TLabel").grid(row=0, column=0, sticky="w")

        controls = ttk.Frame(header)
        controls.grid(row=0, column=1, sticky="e")

        filter_var = tk.StringVar(value="Tous")
        ttk.Label(controls, text="Filtre métier").pack(side="left", padx=(0, 8))
        filter_combo = ttk.Combobox(controls, textvariable=filter_var, values=["Tous"], state="readonly", width=22)
        filter_combo.pack(side="left")
        refresh_button = ttk.Button(controls, text="Rafraîchir")
        refresh_button.pack(side="left", padx=(8, 0))

        summary_var = tk.StringVar(value="Prêt")
        ttk.Label(frame, textvariable=summary_var, style="Summary.TLabel").grid(
            row=1, column=0, sticky="ew", pady=(8, 8)
        )

        tree_frame = ttk.Frame(frame)
        tree_frame.grid(row=2, column=0, sticky="nsew")
        tree_frame.columnconfigure(0, weight=1)
        tree_frame.rowconfigure(0, weight=1)

        columns = ("character", "realm", "level", "professions", "recipes_scanned", "last_connection")
        tree = ttk.Treeview(tree_frame, columns=columns, show="headings", height=12)
        tree.grid(row=0, column=0, sticky="nsew")

        headings = {
            "character": ("Personnage", 180),
            "realm": ("Royaume", 120),
            "level": ("Niv.", 70),
            "professions": ("Métiers", 460),
            "recipes_scanned": ("Scanné", 100),
            "last_connection": ("Dernière connexion", 170),
        }
        for column, (label, width) in headings.items():
            tree.heading(column, text=label)
            tree.column(
                column,
                width=width,
                anchor="center" if column in {"level", "recipes_scanned"} else "w",
            )

        scrollbar = ttk.Scrollbar(tree_frame, orient="vertical", command=tree.yview)
        scrollbar.grid(row=0, column=1, sticky="ns")
        tree.configure(yscrollcommand=scrollbar.set)

        details_box = ttk.LabelFrame(frame, text="Détails", padding=8)
        details_box.grid(row=3, column=0, sticky="nsew", pady=(10, 0))
        details_box.columnconfigure(0, weight=1)
        details_box.rowconfigure(0, weight=1)
        details_text = tk.Text(details_box, wrap="word", height=10, font=("Consolas", 10))
        details_text.grid(row=0, column=0, sticky="nsew")
        details_text.configure(state="disabled")

        state = _CharactersTabState(
            summary_var=summary_var,
            filter_var=filter_var,
            filter_combo=filter_combo,
            refresh_button=refresh_button,
            tree=tree,
            details_text=details_text,
            row_lookup={},
            current_report=None,
        )
        refresh_button.configure(command=lambda current=state: self._refresh_character_tab(current))
        filter_combo.bind("<<ComboboxSelected>>", lambda event, current=state: self._apply_character_filter(current))
        tree.bind("<<TreeviewSelect>>", lambda event, current=state: self._show_selected_character(current, event.widget))
        return state

    def _build_specialization_tab(self, notebook: ttk.Notebook) -> _SpecializationTabState:
        frame = ttk.Frame(notebook, padding=10)
        notebook.add(frame, text="Spécialisation")
        frame.columnconfigure(0, weight=1)
        frame.rowconfigure(2, weight=3)
        frame.rowconfigure(3, weight=2)

        header = ttk.Frame(frame)
        header.grid(row=0, column=0, sticky="ew")
        header.columnconfigure(0, weight=1)
        ttk.Label(header, text="Setup gold / concentration Midnight", style="Header.TLabel").grid(
            row=0, column=0, sticky="w"
        )

        controls = ttk.Frame(header)
        controls.grid(row=0, column=1, sticky="e")

        filter_var = tk.StringVar(value="Tous")
        ttk.Label(controls, text="Vue").pack(side="left", padx=(0, 8))
        filter_combo = ttk.Combobox(
            controls,
            textvariable=filter_var,
            values=["Tous", "Prêts", "À compléter", "Sans plan"],
            state="readonly",
            width=14,
        )
        filter_combo.pack(side="left")
        copy_button = ttk.Button(controls, text="Copier le plan")
        copy_button.pack(side="left", padx=(8, 0))
        refresh_button = ttk.Button(controls, text="Rafraîchir")
        refresh_button.pack(side="left", padx=(8, 0))

        summary_var = tk.StringVar(value="Prêt")
        ttk.Label(frame, textvariable=summary_var, style="Summary.TLabel").grid(
            row=1, column=0, sticky="ew", pady=(8, 8)
        )

        tree_frame = ttk.Frame(frame)
        tree_frame.grid(row=2, column=0, sticky="nsew")
        tree_frame.columnconfigure(0, weight=1)
        tree_frame.rowconfigure(0, weight=1)

        columns = ("character", "professions", "setup", "status")
        tree = ttk.Treeview(tree_frame, columns=columns, show="headings", height=12)
        tree.grid(row=0, column=0, sticky="nsew")

        headings = {
            "character": ("Personnage", 180),
            "professions": ("Métiers", 230),
            "setup": ("Trajectoire", 360),
            "status": ("État", 110),
        }
        for column, (label, width) in headings.items():
            tree.heading(column, text=label)
            tree.column(column, width=width, anchor="w")

        scrollbar = ttk.Scrollbar(tree_frame, orient="vertical", command=tree.yview)
        scrollbar.grid(row=0, column=1, sticky="ns")
        tree.configure(yscrollcommand=scrollbar.set)

        details_box = ttk.LabelFrame(frame, text="Plan rapide", padding=10)
        details_box.grid(row=3, column=0, sticky="nsew", pady=(10, 0))
        details_box.columnconfigure(0, weight=1)
        details_box.rowconfigure(3, weight=1)

        hero_var = tk.StringVar(value="Choisis un personnage")
        subhero_var = tk.StringVar(value="Le plan affichera juste le setup utile.")
        setup_var = tk.StringVar(value="-")
        source_var = tk.StringVar(value="-")
        tips_var = tk.StringVar(value="-")

        ttk.Label(details_box, textvariable=hero_var, style="SpecHero.TLabel").grid(row=0, column=0, sticky="w")
        ttk.Label(details_box, textvariable=subhero_var, style="SpecSubhero.TLabel").grid(
            row=1, column=0, sticky="w", pady=(2, 10)
        )

        meta_grid = ttk.Frame(details_box)
        meta_grid.grid(row=2, column=0, sticky="ew", pady=(0, 10))
        meta_grid.columnconfigure(1, weight=1)
        ttk.Label(meta_grid, text="Setup", style="SpecKey.TLabel").grid(row=0, column=0, sticky="nw", padx=(0, 8))
        ttk.Label(meta_grid, textvariable=setup_var, style="SpecValue.TLabel").grid(row=0, column=1, sticky="nw")
        ttk.Label(meta_grid, text="Tips", style="SpecKey.TLabel").grid(row=1, column=0, sticky="nw", padx=(0, 8), pady=(6, 0))
        ttk.Label(meta_grid, textvariable=tips_var, style="SpecValue.TLabel", wraplength=920, justify="left").grid(
            row=1, column=1, sticky="nw", pady=(6, 0)
        )
        ttk.Label(meta_grid, text="Source", style="SpecKey.TLabel").grid(row=2, column=0, sticky="nw", padx=(0, 8), pady=(6, 0))
        ttk.Label(meta_grid, textvariable=source_var, style="SpecValue.TLabel", wraplength=920, justify="left").grid(
            row=2, column=1, sticky="nw", pady=(6, 0)
        )

        phases_tree = ttk.Treeview(details_box, columns=("profession", "phase"), show="headings", height=6)
        phases_tree.grid(row=3, column=0, sticky="nsew")
        phases_tree.heading("profession", text="Métier")
        phases_tree.heading("phase", text="Points utiles")
        phases_tree.column("profession", width=170, anchor="w")
        phases_tree.column("phase", width=760, anchor="w")
        phase_scrollbar = ttk.Scrollbar(details_box, orient="vertical", command=phases_tree.yview)
        phase_scrollbar.grid(row=3, column=1, sticky="ns")
        phases_tree.configure(yscrollcommand=phase_scrollbar.set)

        state = _SpecializationTabState(
            summary_var=summary_var,
            filter_var=filter_var,
            filter_combo=filter_combo,
            refresh_button=refresh_button,
            copy_button=copy_button,
            tree=tree,
            hero_var=hero_var,
            subhero_var=subhero_var,
            setup_var=setup_var,
            source_var=source_var,
            tips_var=tips_var,
            phases_tree=phases_tree,
            row_lookup={},
            current_report=None,
        )
        refresh_button.configure(command=lambda current=state: self._refresh_specialization_tab(current))
        copy_button.configure(command=lambda current=state: self._copy_specialization_plan(current))
        filter_combo.bind("<<ComboboxSelected>>", lambda event, current=state: self._apply_specialization_filter(current))
        tree.bind("<<TreeviewSelect>>", lambda event, current=state: self._show_selected_specialization(current, event.widget))
        return state

    def _build_lumber_tab(self, notebook: ttk.Notebook) -> _LumberTabState:
        frame = ttk.Frame(notebook, padding=10)
        notebook.add(frame, text="Lumber")
        frame.columnconfigure(0, weight=1)
        frame.rowconfigure(2, weight=3)
        frame.rowconfigure(3, weight=2)

        header = ttk.Frame(frame)
        header.grid(row=0, column=0, sticky="ew")
        header.columnconfigure(0, weight=1)
        ttk.Label(header, text="Bois à farm", style="Header.TLabel").grid(row=0, column=0, sticky="w")

        controls = ttk.Frame(header)
        controls.grid(row=0, column=1, sticky="e")

        region_var = tk.StringVar(value=DEFAULT_REGION.upper())
        sync_var = tk.BooleanVar(value=False)
        force_var = tk.BooleanVar(value=False)

        ttk.Label(controls, text="Région").pack(side="left", padx=(0, 8))
        ttk.Combobox(controls, textvariable=region_var, values=["EU", "US"], state="readonly", width=8).pack(side="left")
        ttk.Checkbutton(controls, text="Sync prices", variable=sync_var).pack(side="left", padx=(12, 0))
        ttk.Checkbutton(controls, text="Force", variable=force_var).pack(side="left", padx=(8, 0))
        refresh_button = ttk.Button(controls, text="Rafraîchir")
        refresh_button.pack(side="left", padx=(8, 0))

        summary_var = tk.StringVar(value="Prêt")
        ttk.Label(frame, textvariable=summary_var, style="Summary.TLabel").grid(
            row=1, column=0, sticky="ew", pady=(8, 8)
        )

        tree_frame = ttk.Frame(frame)
        tree_frame.grid(row=2, column=0, sticky="nsew")
        tree_frame.columnconfigure(0, weight=1)
        tree_frame.rowconfigure(0, weight=1)

        columns = (
            "expansion",
            "wood",
            "profession",
            "value",
            "profit",
            "sale_rate",
            "products",
            "marketed",
            "wood_price",
        )
        tree = ttk.Treeview(tree_frame, columns=columns, show="headings", height=12)
        tree.grid(row=0, column=0, sticky="nsew")

        headings = {
            "expansion": ("Extension", 120),
            "wood": ("Bois", 200),
            "profession": ("Meilleur métier", 130),
            "value": ("Valeur/bois", 100),
            "profit": ("Profit moy", 100),
            "sale_rate": ("SR moy", 80),
            "products": ("Produits", 70),
            "marketed": ("Pricés", 70),
            "wood_price": ("Prix avgSell", 100),
        }
        for column, (label, width) in headings.items():
            tree.heading(column, text=label)
            tree.column(column, width=width, anchor="w")

        scrollbar = ttk.Scrollbar(tree_frame, orient="vertical", command=tree.yview)
        scrollbar.grid(row=0, column=1, sticky="ns")
        tree.configure(yscrollcommand=scrollbar.set)

        details_box = ttk.LabelFrame(frame, text="Détails", padding=8)
        details_box.grid(row=3, column=0, sticky="nsew", pady=(10, 0))
        details_box.columnconfigure(0, weight=1)
        details_box.rowconfigure(0, weight=1)
        details_text = tk.Text(details_box, wrap="word", height=10, font=("Consolas", 10))
        details_text.grid(row=0, column=0, sticky="nsew")
        details_text.configure(state="disabled")

        state = _LumberTabState(
            summary_var=summary_var,
            region_var=region_var,
            sync_var=sync_var,
            force_var=force_var,
            refresh_button=refresh_button,
            tree=tree,
            details_text=details_text,
            row_lookup={},
            current_report=None,
        )
        refresh_button.configure(command=lambda current=state: self._refresh_lumber_tab(current))
        tree.bind("<<TreeviewSelect>>", lambda event, current=state: self._show_selected_lumber(current, event.widget))
        return state

    def _build_mounts_tab(self, notebook: ttk.Notebook) -> _MountsTabState:
        frame = ttk.Frame(notebook, padding=10)
        notebook.add(frame, text="Montures")
        frame.columnconfigure(0, weight=1)
        frame.rowconfigure(3, weight=1)

        header = ttk.Frame(frame)
        header.grid(row=0, column=0, sticky="ew", pady=(0, 8))
        header.columnconfigure(0, weight=1)
        ttk.Label(header, text="Catalogue des montures", style="Header.TLabel").grid(row=0, column=0, sticky="w")
        ttk.Label(
            header,
            text="Liste exhaustive · fiabilité d’obtention · timegates · filtre sans RMT",
            style="Summary.TLabel",
        ).grid(row=1, column=0, sticky="w", pady=(2, 0))

        controls = ttk.LabelFrame(frame, text="Filtres", padding=8)
        controls.grid(row=1, column=0, sticky="ew")
        controls.columnconfigure(1, weight=1)
        controls.columnconfigure(3, weight=1)
        controls.columnconfigure(5, weight=1)

        query_var = tk.StringVar()
        expansion_var = tk.StringVar(value="Toutes")
        availability_var = tk.StringVar(value="Toutes")
        no_rmt_var = tk.BooleanVar(value=True)
        sort_var = tk.StringVar(value="Fiabilité ↓")
        force_var = tk.BooleanVar(value=False)

        ttk.Label(controls, text="Rechercher").grid(row=0, column=0, sticky="w", padx=(0, 6), pady=4)
        search_entry = ttk.Entry(controls, textvariable=query_var)
        search_entry.grid(row=0, column=1, sticky="ew", pady=4)
        ttk.Label(controls, text="Extension").grid(row=0, column=2, sticky="w", padx=(14, 6), pady=4)
        expansion_combo = ttk.Combobox(controls, textvariable=expansion_var, values=["Toutes"], state="readonly", width=24)
        expansion_combo.grid(row=0, column=3, sticky="ew", pady=4)
        ttk.Label(controls, text="Disponibilité").grid(row=0, column=4, sticky="w", padx=(14, 6), pady=4)
        availability_combo = ttk.Combobox(
            controls,
            textvariable=availability_var,
            values=["Toutes", "Toujours obtenables", "Obtenables maintenant", "Retirées", "À venir", "Non implémentées"],
            state="readonly",
            width=24,
        )
        availability_combo.grid(row=0, column=5, sticky="ew", pady=4)

        ttk.Label(controls, text="Tri").grid(row=1, column=0, sticky="w", padx=(0, 6), pady=4)
        sort_combo = ttk.Combobox(
            controls,
            textvariable=sort_var,
            values=["Fiabilité ↓", "Temps estimé ↑", "Nom A→Z", "Extension"],
            state="readonly",
            width=24,
        )
        sort_combo.grid(row=1, column=1, sticky="w", pady=4)
        ttk.Checkbutton(controls, text="Exclure RMT / boutique", variable=no_rmt_var).grid(
            row=1, column=2, columnspan=2, sticky="w", padx=(14, 0), pady=4
        )
        ttk.Checkbutton(controls, text="Forcer la synchronisation", variable=force_var).grid(
            row=1, column=4, sticky="w", padx=(14, 0), pady=4
        )
        refresh_button = ttk.Button(controls, text="Synchroniser le catalogue")
        refresh_button.grid(row=1, column=5, sticky="e", pady=4)

        summary_var = tk.StringVar(value="Catalogue absent : synchronise le catalogue pour charger toutes les montures.")
        ttk.Label(frame, textvariable=summary_var, style="Summary.TLabel").grid(
            row=2, column=0, sticky="ew", pady=(8, 8)
        )

        body = ttk.Panedwindow(frame, orient="horizontal")
        body.grid(row=3, column=0, sticky="nsew")

        tree_frame = ttk.Frame(body)
        tree_frame.columnconfigure(0, weight=1)
        tree_frame.rowconfigure(0, weight=1)
        body.add(tree_frame, weight=3)
        columns = ("expansion", "source", "availability", "reliability", "time")
        tree = ttk.Treeview(tree_frame, columns=columns, show="tree headings", height=20)
        tree.grid(row=0, column=0, sticky="nsew")
        tree.heading("#0", text="Monture")
        tree.column("#0", width=270, anchor="w")
        headings = {
            "expansion": ("Extension", 145),
            "source": ("Source", 155),
            "availability": ("État", 120),
            "reliability": ("Fiabilité", 135),
            "time": ("Temps estimé", 180),
        }
        for column, (label, width) in headings.items():
            tree.heading(column, text=label)
            tree.column(column, width=width, anchor="w")
        tree.tag_configure("unavailable", foreground="#9a7770")
        tree.tag_configure("rmt", foreground="#a48b83")
        scrollbar = ttk.Scrollbar(tree_frame, orient="vertical", command=tree.yview)
        scrollbar.grid(row=0, column=1, sticky="ns")
        tree.configure(yscrollcommand=scrollbar.set)

        details_box = ttk.LabelFrame(body, text="Détails", padding=8)
        details_box.columnconfigure(0, weight=1)
        details_box.rowconfigure(2, weight=1)
        body.add(details_box, weight=2)
        image_label = tk.Label(
            details_box,
            text="Sélectionne une monture",
            background="#171313",
            foreground="#d8c6bd",
            height=8,
            anchor="center",
        )
        image_label.grid(row=0, column=0, sticky="ew", pady=(0, 8))
        open_button = ttk.Button(details_box, text="Ouvrir le lien Wowhead", state="disabled")
        open_button.grid(row=1, column=0, sticky="e", pady=(0, 8))
        details_text = tk.Text(details_box, wrap="word", height=16, font=("Consolas", 9))
        details_text.grid(row=2, column=0, sticky="nsew")
        details_text.configure(state="disabled")

        state = _MountsTabState(
            summary_var=summary_var,
            query_var=query_var,
            expansion_var=expansion_var,
            availability_var=availability_var,
            no_rmt_var=no_rmt_var,
            sort_var=sort_var,
            force_var=force_var,
            expansion_combo=expansion_combo,
            refresh_button=refresh_button,
            tree=tree,
            details_text=details_text,
            image_label=image_label,
            open_button=open_button,
            row_lookup={},
            all_rows=[],
            icon_images={},
            current_payload=None,
        )
        refresh_button.configure(command=lambda current=state: self._start_mount_catalog_sync(current))
        open_button.configure(command=lambda current=state: self._open_selected_mount(current))
        for variable in (query_var, expansion_var, availability_var, no_rmt_var, sort_var):
            variable.trace_add("write", lambda *_args, current=state: self._apply_mount_filters(current))
        expansion_combo.bind("<<ComboboxSelected>>", lambda _event, current=state: self._apply_mount_filters(current))
        availability_combo.bind("<<ComboboxSelected>>", lambda _event, current=state: self._apply_mount_filters(current))
        sort_combo.bind("<<ComboboxSelected>>", lambda _event, current=state: self._apply_mount_filters(current))
        tree.bind("<<TreeviewSelect>>", lambda event, current=state: self._show_selected_mount(current, event.widget))
        return state

    def _build_auction_tab(self, notebook: ttk.Notebook) -> _AuctionTabState:
        frame = ttk.Frame(notebook, padding=10)
        notebook.add(frame, text="Comparateur AH")
        frame.columnconfigure(0, weight=1)
        frame.rowconfigure(3, weight=3)
        frame.rowconfigure(4, weight=2)

        header = ttk.Frame(frame)
        header.grid(row=0, column=0, sticky="ew", pady=(0, 8))
        header.columnconfigure(0, weight=1)
        ttk.Label(header, text="Marché européen", style="AuctionTitle.TLabel").grid(row=0, column=0, sticky="w")
        ttk.Label(
            header,
            text="Prix actuels par groupe de royaumes connectés · rangs décodés · icônes WoW",
            style="AuctionSubtitle.TLabel",
        ).grid(row=1, column=0, sticky="w", pady=(2, 0))

        controls = ttk.LabelFrame(frame, text="Rechercher un objet", padding=10)
        controls.grid(row=1, column=0, sticky="ew")
        controls.columnconfigure(3, weight=1)
        region_var = tk.StringVar(value=DEFAULT_REGION.upper())
        query_var = tk.StringVar()
        available_only_var = tk.BooleanVar(value=False)
        ttk.Label(controls, text="Région", style="AuctionKey.TLabel").grid(row=0, column=0, padx=(0, 8), pady=4)
        ttk.Combobox(controls, textvariable=region_var, values=["EU"], state="readonly", width=8).grid(
            row=0, column=1, sticky="w", pady=4
        )
        ttk.Label(controls, text="Objet", style="AuctionKey.TLabel").grid(row=0, column=2, padx=(16, 8), pady=4)
        search_entry = ttk.Entry(controls, textvariable=query_var, font=("Segoe UI", 11))
        search_entry.grid(row=0, column=3, sticky="ew", pady=4)
        autocomplete_box = ttk.Frame(controls)
        autocomplete_box.grid(row=1, column=3, sticky="ew", pady=(0, 2))
        autocomplete_box.columnconfigure(0, weight=1)
        suggestions = tk.Listbox(
            autocomplete_box,
            height=6,
            activestyle="none",
            selectmode="browse",
            font=("Segoe UI", 10),
            background="#ffffff",
            foreground="#202020",
            selectbackground="#2f6fae",
            selectforeground="#ffffff",
            relief="solid",
            borderwidth=1,
            highlightthickness=0,
        )
        suggestions.grid(row=0, column=0, sticky="ew")
        suggestions.grid_remove()
        search_button = ttk.Button(controls, text="Rechercher", style="AuctionAccent.TButton")
        search_button.grid(row=0, column=4, padx=(8, 0), pady=4)
        realms_button = ttk.Button(controls, text="Royaumes")
        realms_button.grid(row=0, column=5, padx=(8, 0), pady=4)
        sync_button = ttk.Button(controls, text="Actualiser les prix")
        sync_button.grid(row=0, column=6, padx=(8, 0), pady=4)
        ttk.Checkbutton(
            controls,
            text="Masquer les groupes vides",
            variable=available_only_var,
        ).grid(row=2, column=3, sticky="w", pady=(4, 0))

        summary_var = tk.StringVar(value="Synchronise l’AH Blizzard une fois, puis recherche n’importe quel objet.")
        ttk.Label(frame, textvariable=summary_var, style="Summary.TLabel").grid(
            row=2, column=0, sticky="ew", pady=(10, 8)
        )

        tree_frame = ttk.Frame(frame)
        tree_frame.grid(row=3, column=0, sticky="nsew")
        tree_frame.columnconfigure(0, weight=1)
        tree_frame.rowconfigure(0, weight=1)
        columns = ("variant", "realm", "price", "quantity", "listings", "updated")
        tree = ttk.Treeview(tree_frame, columns=columns, show="headings", height=18, style="Auction.Treeview")
        tree.grid(row=0, column=0, sticky="nsew")
        headings = {
            "variant": ("Objet / rang", 310),
            "realm": ("Groupe EU", 220),
            "price": ("Prix minimum", 140),
            "quantity": ("Quantité", 90),
            "listings": ("Annonces", 90),
            "updated": ("Actualisé", 180),
        }
        for column, (label, width) in headings.items():
            tree.heading(column, text=label)
            tree.column(column, width=width, anchor="w")
        tree.tag_configure("best", background="#fff4cf", foreground="#2f2610")
        tree.tag_configure("empty", foreground="#8c8c8c")
        scrollbar = ttk.Scrollbar(tree_frame, orient="vertical", command=tree.yview)
        scrollbar.grid(row=0, column=1, sticky="ns")
        tree.configure(yscrollcommand=scrollbar.set)

        details_box = ttk.LabelFrame(frame, text="Sélection", padding=10)
        details_box.grid(row=4, column=0, sticky="nsew", pady=(10, 0))
        details_box.columnconfigure(0, weight=1)
        details_box.rowconfigure(0, weight=1)
        details_text = tk.Text(
            details_box,
            wrap="word",
            height=8,
            font=("Segoe UI", 10),
            background="#f7f7f7",
            foreground="#202020",
            relief="flat",
            padx=8,
            pady=8,
        )
        details_text.grid(row=0, column=0, sticky="nsew")
        details_text.configure(state="disabled")

        state = _AuctionTabState(
            summary_var=summary_var,
            region_var=region_var,
            query_var=query_var,
            available_only_var=available_only_var,
            search_entry=search_entry,
            suggestions=suggestions,
            suggestion_rows=[],
            autocomplete_after=None,
            selected_variant_key=None,
            sort_column="price",
            sort_reverse=False,
            tree=tree,
            details_text=details_text,
            search_button=search_button,
            realms_button=realms_button,
            sync_button=sync_button,
            row_lookup={},
            icon_images={},
            current_report=None,
        )
        search_button.configure(command=lambda current=state: self._start_auction_search(current))
        realms_button.configure(command=lambda current=state: self._start_auction_realms(current))
        sync_button.configure(command=lambda current=state: self._start_auction_sync(current))
        search_entry.bind("<KeyRelease>", lambda event, current=state: self._schedule_auction_autocomplete(current, event))
        search_entry.bind("<Down>", lambda _event, current=state: self._focus_auction_suggestions(current))
        search_entry.bind("<Escape>", lambda _event, current=state: self._hide_auction_suggestions(current))
        search_entry.bind("<Return>", lambda _event, current=state: self._handle_auction_return(current))
        suggestions.bind("<<ListboxSelect>>", lambda _event, current=state: self._select_auction_suggestion(current))
        suggestions.bind("<Return>", lambda _event, current=state: self._select_auction_suggestion(current))
        for column in columns:
            tree.heading(column, command=lambda current=state, selected_column=column: self._sort_auction_tree(current, selected_column))
        available_only_var.trace_add("write", lambda *_args, current=state: self._refresh_auction_filter(current))
        tree.bind("<<TreeviewSelect>>", lambda event, current=state: self._show_selected_auction(current, event.widget))
        return state

    def _build_exchange_tab(self, notebook: ttk.Notebook) -> _ExchangeTabState:
        frame = ttk.Frame(notebook, padding=10, style="Exchange.TFrame")
        notebook.add(frame, text="Undermine AH")
        frame.columnconfigure(0, weight=1)
        frame.rowconfigure(1, weight=1)

        header = ttk.Frame(frame, style="Exchange.TFrame")
        header.grid(row=0, column=0, sticky="ew", pady=(0, 8))
        header.columnconfigure(0, weight=1)
        ttk.Label(header, text="Undermine Exchange · EU", style="Exchange.Title.TLabel").grid(
            row=0, column=0, sticky="w"
        )
        ttk.Label(
            header,
            text="Recherche par objet, rang et groupe de royaumes · données Blizzard locales",
            style="Exchange.Muted.TLabel",
        ).grid(row=1, column=0, sticky="w", pady=(2, 0))

        body = ttk.Panedwindow(frame, orient="horizontal", style="Exchange.TPanedwindow")
        body.grid(row=1, column=0, sticky="nsew")

        categories = ttk.LabelFrame(body, text="Catégories", padding=8, style="Exchange.TLabelframe")
        body.add(categories, weight=0)
        for category in (
            "Weapons",
            "Armor",
            "Containers",
            "Gems",
            "Item Enhancements",
            "Consumables",
            "Reagents",
            "Recipes",
            "Profession Equipment",
            "Housing",
            "Battle Pets",
            "Miscellaneous",
        ):
            ttk.Label(categories, text=category, width=22, style="Exchange.Category.TLabel").pack(
                fill="x", pady=2
            )

        right = ttk.Frame(body, padding=(10, 0, 0, 0), style="Exchange.TFrame")
        right.columnconfigure(0, weight=1)
        right.rowconfigure(2, weight=1)
        body.add(right, weight=1)

        controls = ttk.LabelFrame(right, text="Recherche", padding=8, style="Exchange.TLabelframe")
        controls.grid(row=0, column=0, sticky="ew")
        controls.columnconfigure(3, weight=1)
        region_var = tk.StringVar(value="EU")
        query_var = tk.StringVar(value="Sin'dorei Alchemist's Hat")
        ttk.Label(controls, text="Région", style="Exchange.Key.TLabel").grid(row=0, column=0, padx=(0, 8))
        ttk.Combobox(controls, textvariable=region_var, values=["EU"], state="readonly", width=8, style="Exchange.TCombobox").grid(
            row=0, column=1, sticky="w"
        )
        ttk.Label(controls, text="Objet", style="Exchange.Key.TLabel").grid(row=0, column=2, padx=(16, 8))
        search_entry = ttk.Entry(controls, textvariable=query_var, font=("Segoe UI", 11), style="Exchange.TEntry")
        search_entry.grid(row=0, column=3, sticky="ew")
        suggestions = tk.Listbox(
            controls,
            height=8,
            activestyle="none",
            selectmode="browse",
            font=("Segoe UI", 10),
            background="#1c1818",
            foreground="#eee9e2",
            selectbackground="#75170f",
            selectforeground="#fff1c2",
            relief="solid",
            borderwidth=1,
            highlightthickness=0,
        )
        suggestions.grid(row=1, column=3, sticky="ew", pady=(4, 0))
        suggestions.grid_remove()
        search_button = ttk.Button(controls, text="Search", style="Exchange.TButton")
        search_button.grid(row=0, column=4, padx=(8, 0))
        sync_button = ttk.Button(controls, text="Refresh AH", style="Exchange.TButton")
        sync_button.grid(row=0, column=5, padx=(8, 0))

        summary_var = tk.StringVar(value="Recherche en cours…")
        ttk.Label(right, textvariable=summary_var, style="Exchange.Muted.TLabel").grid(
            row=1, column=0, sticky="ew", pady=(8, 8)
        )

        content = ttk.Frame(right, style="Exchange.TFrame")
        content.grid(row=2, column=0, sticky="nsew")
        content.columnconfigure(0, weight=1)
        content.rowconfigure(0, weight=1)

        overview_frame = ttk.Frame(content, style="Exchange.TFrame")
        overview_frame.grid(row=0, column=0, sticky="nsew")
        overview_frame.columnconfigure(0, weight=1)
        overview_frame.rowconfigure(1, weight=1)
        overview_header = ttk.Frame(overview_frame, style="Exchange.TFrame")
        overview_header.grid(row=0, column=0, sticky="ew", pady=(0, 6))
        overview_header.columnconfigure(0, weight=1)
        ttk.Label(
            overview_header,
            text="Clique sur une variante pour voir les prix par royaume · ★ = meilleur prix",
            style="Exchange.Muted.TLabel",
        ).grid(row=0, column=0, sticky="w")
        open_button = ttk.Button(overview_header, text="Ouvrir le détail", style="Exchange.TButton", state="disabled")
        open_button.grid(row=0, column=1, sticky="e")
        open_button.grid_remove()
        overview_tree = ttk.Treeview(
            overview_frame,
            columns=("price", "name", "available", "realms"),
            show="tree headings",
            style="Exchange.Treeview",
        )
        overview_tree.grid(row=1, column=0, sticky="nsew")
        overview_tree.heading("#0", text="")
        overview_tree.column("#0", width=42, minwidth=42, stretch=False, anchor="center")
        overview_headings = {
            "price": ("Price", 150),
            "name": ("Name", 390),
            "available": ("Available", 120),
            "realms": ("Realms", 100),
        }
        for column, (label, width) in overview_headings.items():
            overview_tree.heading(column, text=label)
            overview_tree.column(column, width=width, anchor="w")
        overview_tree.tag_configure("best", background="#fff4cf", foreground="#2f2610")
        overview_scroll = ttk.Scrollbar(overview_frame, orient="vertical", command=overview_tree.yview)
        overview_scroll.grid(row=1, column=1, sticky="ns")
        overview_tree.configure(yscrollcommand=overview_scroll.set)

        detail_frame = ttk.Frame(content, style="Exchange.TFrame")
        detail_frame.grid(row=0, column=0, sticky="nsew")
        detail_frame.columnconfigure(0, weight=1)
        detail_frame.rowconfigure(2, weight=1)
        detail_frame.grid_remove()
        detail_header = ttk.Frame(detail_frame, style="Exchange.TFrame")
        detail_header.grid(row=0, column=0, sticky="ew", pady=(0, 8))
        detail_header.columnconfigure(2, weight=1)
        back_button = ttk.Button(detail_header, text="← Back", style="Exchange.TButton")
        back_button.grid(row=0, column=0, rowspan=2, padx=(0, 10))
        detail_icon_label = ttk.Label(detail_header, style="Exchange.TLabel")
        detail_icon_label.grid(row=0, column=1, rowspan=2, padx=(0, 8))
        title_var = tk.StringVar(value="Objet")
        subtitle_var = tk.StringVar(value="")
        ttk.Label(detail_header, textvariable=title_var, style="Exchange.Title.TLabel").grid(row=0, column=2, sticky="w")
        ttk.Label(detail_header, textvariable=subtitle_var, style="Exchange.Muted.TLabel").grid(row=1, column=2, sticky="w")

        chart = tk.Canvas(detail_frame, height=210, background="#201c1c", highlightthickness=0)
        chart.grid(row=1, column=0, sticky="ew", pady=(0, 10))
        detail_tree = ttk.Treeview(
            detail_frame,
            columns=("realm", "price", "quantity", "listings", "updated"),
            show="headings",
            style="Exchange.Treeview",
        )
        detail_tree.grid(row=2, column=0, sticky="nsew")
        detail_headings = {
            "realm": ("Realm", 260),
            "price": ("Price", 150),
            "quantity": ("Quantity", 110),
            "listings": ("Listings", 100),
            "updated": ("Updated", 190),
        }
        for column, (label, width) in detail_headings.items():
            detail_tree.heading(column, text=label)
            detail_tree.column(column, width=width, anchor="w")
        detail_scroll = ttk.Scrollbar(detail_frame, orient="vertical", command=detail_tree.yview)
        detail_scroll.grid(row=2, column=1, sticky="ns")
        detail_tree.configure(yscrollcommand=detail_scroll.set)

        state = _ExchangeTabState(
            region_var=region_var,
            query_var=query_var,
            summary_var=summary_var,
            title_var=title_var,
            subtitle_var=subtitle_var,
            search_entry=search_entry,
            suggestions=suggestions,
            suggestion_rows=[],
            autocomplete_after=None,
            selected_variant_key=None,
            search_button=search_button,
            sync_button=sync_button,
            open_button=open_button,
            back_button=back_button,
            overview_frame=overview_frame,
            detail_frame=detail_frame,
            overview_tree=overview_tree,
            detail_tree=detail_tree,
            detail_icon_label=detail_icon_label,
            chart=chart,
            overview_lookup={},
            detail_lookup={},
            icon_images={},
            current_report=None,
            current_variant=None,
            overview_updating=False,
            open_first_after_search=False,
            overview_sort_column="name",
            overview_sort_reverse=False,
            detail_sort_column="price",
            detail_sort_reverse=False,
        )
        search_button.configure(command=lambda current=state: self._start_exchange_search(current))
        sync_button.configure(command=lambda current=state: self._start_exchange_sync(current))
        open_button.configure(command=lambda current=state: self._open_exchange_detail(current))
        back_button.configure(command=lambda current=state: self._close_exchange_detail(current))
        search_entry.bind("<KeyRelease>", lambda event, current=state: self._schedule_exchange_autocomplete(current, event))
        search_entry.bind("<Down>", lambda _event, current=state: self._focus_exchange_suggestions(current))
        search_entry.bind("<Escape>", lambda _event, current=state: self._hide_exchange_suggestions(current))
        search_entry.bind("<Return>", lambda _event, current=state: self._handle_exchange_return(current))
        suggestions.bind("<<ListboxSelect>>", lambda _event, current=state: self._select_exchange_suggestion(current))
        suggestions.bind("<Return>", lambda _event, current=state: self._select_exchange_suggestion(current))
        overview_tree.bind("<<TreeviewSelect>>", lambda _event, current=state: self._exchange_selection_changed(current))
        detail_tree.bind("<<TreeviewSelect>>", lambda _event, current=state: self._exchange_detail_selection_changed(current))
        for column in overview_headings:
            overview_tree.heading(column, command=lambda current=state, selected_column=column: self._sort_exchange_overview(current, selected_column))
        for column in detail_headings:
            detail_tree.heading(column, command=lambda current=state, selected_column=column: self._sort_exchange_detail(current, selected_column))
        return state

    def _schedule_exchange_autocomplete(self, state: _ExchangeTabState, event: tk.Event) -> None:
        if event.keysym in {"Up", "Down", "Return", "Escape"}:
            return
        state.selected_variant_key = None
        state.open_first_after_search = False
        if state.autocomplete_after is not None:
            try:
                self.root.after_cancel(state.autocomplete_after)
            except tk.TclError:
                pass
            state.autocomplete_after = None
        query = state.query_var.get().strip()
        if len(query) < 2:
            self._hide_exchange_suggestions(state)
            return
        state.autocomplete_after = self.root.after(
            180,
            lambda current=state, current_query=query: self._start_exchange_autocomplete(current, current_query),
        )

    def _start_exchange_autocomplete(self, state: _ExchangeTabState, query: str) -> None:
        state.autocomplete_after = None
        threading.Thread(
            target=self._run_exchange_autocomplete,
            args=(state, query),
            daemon=True,
        ).start()

    def _run_exchange_autocomplete(self, state: _ExchangeTabState, query: str) -> None:
        try:
            conn = connect(DB_PATH)
            rows = suggest_auction_items(conn, query, limit=8)
            conn.close()
        except Exception:
            return
        self.root.after(
            0,
            lambda current=state, current_query=query, current_rows=rows: self._apply_exchange_suggestions(
                current, current_query, current_rows
            ),
        )

    def _apply_exchange_suggestions(
        self,
        state: _ExchangeTabState,
        query: str,
        rows: list[dict[str, Any]],
    ) -> None:
        if state.query_var.get().strip() != query:
            return
        state.suggestions.delete(0, tk.END)
        state.suggestion_rows = rows
        for row in rows:
            state.suggestions.insert(tk.END, row.get("display_name") or row.get("item_name") or "-")
        if rows:
            state.suggestions.grid()
            state.suggestions.activate(0)
        else:
            self._hide_exchange_suggestions(state)

    def _focus_exchange_suggestions(self, state: _ExchangeTabState) -> str:
        if state.suggestions.winfo_ismapped() and state.suggestion_rows:
            state.suggestions.focus_set()
            state.suggestions.selection_set(0)
            state.suggestions.activate(0)
        return "break"

    def _select_exchange_suggestion(self, state: _ExchangeTabState) -> str:
        selection = state.suggestions.curselection()
        if not selection and state.suggestion_rows:
            selection = (0,)
        if not selection or selection[0] >= len(state.suggestion_rows):
            return "break"
        row = state.suggestion_rows[selection[0]]
        state.query_var.set(str(row.get("search_name") or row.get("item_name") or ""))
        state.selected_variant_key = row.get("variant_key")
        state.open_first_after_search = False
        self._hide_exchange_suggestions(state)
        state.search_entry.focus_set()
        self._start_exchange_search(state)
        return "break"

    def _handle_exchange_return(self, state: _ExchangeTabState) -> str:
        if state.suggestions.winfo_ismapped() and state.suggestion_rows:
            return self._select_exchange_suggestion(state)
        self._start_exchange_search(state)
        return "break"

    def _hide_exchange_suggestions(self, state: _ExchangeTabState) -> None:
        state.suggestions.grid_remove()
        state.suggestions.selection_clear(0, tk.END)
        state.suggestion_rows = []

    def _start_exchange_search(self, state: _ExchangeTabState) -> None:
        self._hide_exchange_suggestions(state)
        state.search_button.configure(state="disabled")
        state.summary_var.set("Recherche des variantes et des prix…")
        params = {
            "region": state.region_var.get().strip().lower() or DEFAULT_REGION,
            "query": state.query_var.get().strip(),
            "variant_key": state.selected_variant_key,
        }
        threading.Thread(target=self._run_exchange_search, args=(state, params), daemon=True).start()

    def _run_exchange_search(self, state: _ExchangeTabState, params: dict[str, Any]) -> None:
        try:
            conn = connect(DB_PATH)
            report = build_auction_report(
                conn,
                params["query"],
                params["region"],
                variant_key=params["variant_key"],
            )
            conn.close()
            report["icon_bytes"] = self._fetch_auction_icon_bytes(report)
        except Exception as exc:  # pragma: no cover - GUI error path
            details = traceback.format_exc()
            self.root.after(0, lambda error=exc, trace=details: self._handle_exchange_error(state, error, trace, "Recherche"))
            return
        self.root.after(0, lambda: self._apply_exchange_report(state, report))

    def _apply_exchange_report(self, state: _ExchangeTabState, report: dict[str, Any]) -> None:
        state.overview_updating = True
        self._hide_exchange_suggestions(state)
        state.current_report = report
        state.current_variant = None
        state.detail_frame.grid_remove()
        state.overview_frame.grid()
        state.overview_lookup.clear()
        state.detail_lookup.clear()
        state.icon_images.clear()
        for item in state.overview_tree.get_children():
            state.overview_tree.delete(item)
        for item in state.detail_tree.get_children():
            state.detail_tree.delete(item)

        icon_bytes = report.get("icon_bytes") or {}
        if Image is not None and ImageTk is not None:
            for icon_url, payload in icon_bytes.items():
                try:
                    image = Image.open(io.BytesIO(payload)).convert("RGBA")
                    image.thumbnail((30, 30), Image.Resampling.LANCZOS)
                    state.icon_images[icon_url] = ImageTk.PhotoImage(image, master=self.root)
                except Exception:
                    continue

        all_prices = [
            int(row["price_copper"])
            for variant in report.get("variants") or []
            for row in variant.get("realm_rows") or []
            if row.get("has_listing") and row.get("price_copper") is not None
        ]
        global_best = min(all_prices) if all_prices else None
        for index, variant in enumerate(report.get("variants") or []):
            available_rows = [row for row in variant.get("realm_rows") or [] if row.get("has_listing")]
            prices = [row.get("price_copper") for row in available_rows if row.get("price_copper") is not None]
            is_best = bool(prices and min(prices) == global_best)
            row_id = f"exchange-{index}"
            state.overview_lookup[row_id] = variant
            state.overview_tree.insert(
                "",
                "end",
                iid=row_id,
                values=(
                    f"★ {_format_exchange_price(min(prices) if prices else None)}" if is_best else _format_exchange_price(min(prices) if prices else None),
                    variant.get("label") or "-",
                    sum(int(row.get("available_quantity") or 0) for row in available_rows),
                    len(available_rows),
                ),
                image=state.icon_images.get(variant.get("icon_url")),
                tags=(),
            )

        if report.get("matches"):
            state.summary_var.set(
                f"{len(report.get('variants') or [])} rang(s) trouvé(s) · "
                f"{report.get('realm_count', 0)} groupes EU · double-clique pour le détail"
            )
        else:
            state.summary_var.set("Aucun objet trouvé dans le catalogue local.")
        state.open_button.configure(state="disabled")
        state.search_button.configure(state="normal")
        self._sort_exchange_overview(state, state.overview_sort_column, toggle=False)
        state.overview_updating = False

        children = state.overview_tree.get_children()
        if children:
            if state.open_first_after_search:
                state.open_first_after_search = False
                self.root.after(120, lambda: self._open_exchange_detail(state))

    def _exchange_selection_changed(self, state: _ExchangeTabState) -> None:
        if state.overview_updating:
            return
        if state.overview_tree.selection():
            self._open_exchange_detail(state)

    def _open_exchange_detail(self, state: _ExchangeTabState) -> None:
        selection = state.overview_tree.selection()
        if not selection:
            children = state.overview_tree.get_children()
            if not children:
                return
            selection = (children[0],)
            state.overview_tree.selection_set(selection[0])
        variant = state.overview_lookup.get(selection[0])
        if variant is None:
            return
        state.current_variant = variant
        state.overview_frame.grid_remove()
        state.detail_frame.grid()
        state.title_var.set(variant.get("label") or "Objet")
        state.detail_icon_label.configure(image=state.icon_images.get(variant.get("icon_url"), ""))
        listed = [row for row in variant.get("realm_rows") or [] if row.get("has_listing")]
        prices = [row.get("price_copper") for row in listed if row.get("price_copper") is not None]
        state.subtitle_var.set(
            f"{len(listed)} groupes avec une annonce · minimum {_format_exchange_price(min(prices) if prices else None)} · "
            "utilise Back pour revenir aux variantes"
        )
        state.summary_var.set(
            f"{variant.get('label') or 'Objet'} · {len(listed)} groupes avec une annonce · "
            f"minimum {_format_exchange_price(min(prices) if prices else None)}"
        )
        state.detail_lookup.clear()
        for item in state.detail_tree.get_children():
            state.detail_tree.delete(item)
        best_price = min(prices) if prices else None
        for index, realm in enumerate(variant.get("realm_rows") or []):
            row_id = f"exchange-realm-{index}"
            state.detail_lookup[row_id] = realm
            tags = []
            if not realm.get("has_listing"):
                tags.append("empty")
            elif realm.get("price_copper") == best_price:
                tags.append("best")
            state.detail_tree.insert(
                "",
                "end",
                iid=row_id,
                values=(
                    realm.get("name") or "-",
                    _format_exchange_price(realm.get("price_copper")),
                    realm.get("available_quantity") or 0,
                    realm.get("listing_count") or 0,
                    _format_exchange_age(realm.get("fetched_at")),
                ),
                tags=tags,
            )
        state.detail_tree.tag_configure("best", background="#fff4cf", foreground="#2f2610")
        state.detail_tree.tag_configure("empty", foreground="#8c8c8c")
        self._draw_exchange_chart(state, variant)
        self._sort_exchange_detail(state, state.detail_sort_column, toggle=False)

    def _close_exchange_detail(self, state: _ExchangeTabState) -> None:
        state.detail_frame.grid_remove()
        state.overview_frame.grid()
        state.current_variant = None
        selection = state.overview_tree.selection()
        if selection:
            state.overview_tree.selection_remove(*selection)
        state.overview_tree.focus("")
        state.summary_var.set(
            f"{len(state.current_report.get('variants') or []) if state.current_report else 0} rang(s) · "
            "sélectionne une ligne pour ouvrir le détail"
        )

    def _draw_exchange_chart(self, state: _ExchangeTabState, variant: dict[str, Any]) -> None:
        canvas = state.chart
        canvas.delete("all")
        canvas.update_idletasks()
        width = max(650, canvas.winfo_width())
        height = max(180, canvas.winfo_height())
        rows = [row for row in variant.get("realm_rows") or [] if row.get("price_copper") is not None]
        rows.sort(key=lambda row: int(row.get("price_copper") or 0))
        if not rows:
            canvas.create_text(width / 2, height / 2, text="Aucune annonce pour cette variante", fill="#eeeeee")
            return
        if len(rows) > 90:
            step = max(1, len(rows) // 90)
            rows = rows[::step]
        left, right, top, bottom = 28, 16, 20, 28
        plot_width = width - left - right
        plot_height = height - top - bottom
        max_price = max(int(row.get("price_copper") or 0) for row in rows) or 1
        max_quantity = max(int(row.get("available_quantity") or 0) for row in rows) or 1
        bar_width = max(3, plot_width / max(1, len(rows)) - 2)
        for index, row in enumerate(rows):
            x0 = left + index * (plot_width / len(rows)) + 1
            x1 = x0 + bar_width
            price_height = plot_height * (int(row.get("price_copper") or 0) / max_price)
            quantity_height = plot_height * 0.3 * (int(row.get("available_quantity") or 0) / max_quantity)
            canvas.create_rectangle(x0, top + plot_height - price_height, x1, top + plot_height, fill="#7572f2", outline="#aaa7ff")
            canvas.create_rectangle(x0, top + plot_height - quantity_height, x1, top + plot_height, fill="#e36d78", outline="")
        median_price = statistics.median(int(row.get("price_copper") or 0) for row in rows)
        median_x = left + plot_width * (median_price / max_price)
        canvas.create_line(median_x, top, median_x, top + plot_height, fill="#eeeeee", dash=(3, 3))
        canvas.create_text(left, 10, anchor="w", text="Prix", fill="#bdbaff", font=("Segoe UI", 9, "bold"))
        canvas.create_text(width - right, 10, anchor="e", text=f"Médiane {_format_exchange_price(int(median_price))}", fill="#eeeeee", font=("Segoe UI", 9))
        canvas.create_text(left, height - 10, anchor="w", text="violet = prix · rouge = quantité", fill="#dddddd", font=("Segoe UI", 8))

    def _exchange_detail_selection_changed(self, state: _ExchangeTabState) -> None:
        selection = state.detail_tree.selection()
        if not selection:
            return
        row = state.detail_lookup.get(selection[0])
        if row:
            state.summary_var.set(
                f"{row.get('name') or '-'} · {_format_exchange_price(row.get('price_copper'))} · "
                f"{row.get('available_quantity') or 0} disponible(s)"
            )

    def _sort_exchange_overview(self, state: _ExchangeTabState, column: str, *, toggle: bool = True) -> None:
        if toggle:
            if state.overview_sort_column == column:
                state.overview_sort_reverse = not state.overview_sort_reverse
            else:
                state.overview_sort_column = column
                state.overview_sort_reverse = False
        ids = list(state.overview_tree.get_children())

        def key(item_id: str) -> Any:
            variant = state.overview_lookup[item_id]
            rows = [row for row in variant.get("realm_rows") or [] if row.get("price_copper") is not None]
            prices = [int(row["price_copper"]) for row in rows]
            values = {
                "price": min(prices) if prices else 0,
                "name": str(variant.get("label") or "").casefold(),
                "available": sum(int(row.get("available_quantity") or 0) for row in rows),
                "realms": len(rows),
            }
            return values.get(state.overview_sort_column, "")

        ids.sort(key=key, reverse=state.overview_sort_reverse)
        for index, item_id in enumerate(ids):
            state.overview_tree.move(item_id, "", index)
        labels = {"price": "Price", "name": "Name", "available": "Available", "realms": "Realms"}
        for heading, label in labels.items():
            arrow = " ↓" if heading == state.overview_sort_column and state.overview_sort_reverse else " ↑" if heading == state.overview_sort_column else ""
            state.overview_tree.heading(heading, text=label + arrow)

    def _sort_exchange_detail(self, state: _ExchangeTabState, column: str, *, toggle: bool = True) -> None:
        if toggle:
            if state.detail_sort_column == column:
                state.detail_sort_reverse = not state.detail_sort_reverse
            else:
                state.detail_sort_column = column
                state.detail_sort_reverse = False
        ids = list(state.detail_tree.get_children())

        def key(item_id: str) -> Any:
            row = state.detail_lookup[item_id]
            values = {
                "realm": str(row.get("name") or "").casefold(),
                "price": row.get("price_copper") or 0,
                "quantity": int(row.get("available_quantity") or 0),
                "listings": int(row.get("listing_count") or 0),
                "updated": str(row.get("fetched_at") or ""),
            }
            return values.get(state.detail_sort_column, "")

        listed_ids = [item_id for item_id in ids if state.detail_lookup[item_id].get("has_listing")]
        empty_ids = [item_id for item_id in ids if not state.detail_lookup[item_id].get("has_listing")]
        listed_ids.sort(key=key, reverse=state.detail_sort_reverse)
        for index, item_id in enumerate(listed_ids + empty_ids):
            state.detail_tree.move(item_id, "", index)
        labels = {"realm": "Realm", "price": "Price", "quantity": "Quantity", "listings": "Listings", "updated": "Updated"}
        for heading, label in labels.items():
            arrow = " ↓" if heading == state.detail_sort_column and state.detail_sort_reverse else " ↑" if heading == state.detail_sort_column else ""
            state.detail_tree.heading(heading, text=label + arrow)

    def _start_exchange_sync(self, state: _ExchangeTabState) -> None:
        state.sync_button.configure(state="disabled")
        state.search_button.configure(state="disabled")
        state.summary_var.set("Synchronisation AH EU en cours…")
        params = {
            "region": state.region_var.get().strip().lower() or DEFAULT_REGION,
            "query": state.query_var.get().strip(),
            "variant_key": state.selected_variant_key,
        }
        threading.Thread(target=self._run_exchange_sync, args=(state, params), daemon=True).start()

    def _run_exchange_sync(self, state: _ExchangeTabState, params: dict[str, Any]) -> None:
        try:
            conn = connect(DB_PATH)
            cache = HttpCache(CACHE_DIR)
            region = params["region"]
            # The button is an explicit refresh: bypass the long-lived static
            # catalogue/decoder caches as well as fetching fresh AH snapshots.
            sync_auction_catalog(conn, cache, region, force=True)
            summary = sync_auction_data(conn, cache, region, force=True)
            report = build_auction_report(
                conn,
                params["query"],
                region,
                variant_key=params["variant_key"],
            )
            conn.close()
            report["icon_bytes"] = self._fetch_auction_icon_bytes(report)
        except Exception as exc:  # pragma: no cover - GUI error path
            details = traceback.format_exc()
            self.root.after(0, lambda error=exc, trace=details: self._handle_exchange_error(state, error, trace, "Synchronisation AH"))
            return
        self.root.after(0, lambda: self._apply_exchange_sync(state, summary, report))

    def _apply_exchange_sync(self, state: _ExchangeTabState, summary: dict[str, Any], report: dict[str, Any]) -> None:
        state.sync_button.configure(state="normal")
        state.search_button.configure(state="normal")
        state.open_first_after_search = False
        self._apply_exchange_report(state, report)
        first_failure = (summary.get("failed") or [{}])[0].get("error")
        failure_hint = f" · {first_failure}" if first_failure else ""
        state.summary_var.set(
            f"AH synchronisée : {summary['synced']}/{summary['realms']} groupes · "
            f"commodités EU : {summary['commodities']} · échecs : {len(summary['failed'])}{failure_hint}"
        )

    def _handle_exchange_error(self, state: _ExchangeTabState, error: Exception, details: str, operation: str) -> None:
        state.sync_button.configure(state="normal")
        state.search_button.configure(state="normal")
        state.summary_var.set("Erreur")
        messagebox.showerror(operation, str(error), parent=self.root)

    def _refresh_character_tab(self, state: _CharactersTabState) -> None:
        state.refresh_button.configure(state="disabled")
        try:
            report = load_character_profession_scans()
        except Exception as exc:  # pragma: no cover - GUI error path
            details = traceback.format_exc()
            self._set_character_details(state, details)
            state.summary_var.set("Erreur")
            messagebox.showerror("Personnages", str(exc), parent=self.root)
        else:
            state.current_report = report
            self._update_character_filter_options(state, report)
            self._apply_character_report(state, report)
        finally:
            state.refresh_button.configure(state="normal")

    def _apply_character_report(self, state: _CharactersTabState, report: dict[str, Any]) -> None:
        selected_filter = state.filter_var.get().strip() or "Tous"
        for item in state.tree.get_children():
            state.tree.delete(item)
        state.row_lookup.clear()

        characters = report.get("characters", [])
        visible_characters = [character for character in characters if self._character_matches_filter(character, selected_filter)]

        first_row_id: str | None = None
        for index, character in enumerate(visible_characters):
            row_id = f"character-{index}"
            if first_row_id is None:
                first_row_id = row_id
            state.row_lookup[row_id] = character
            professions = character.get("professions") or []
            professions_text = self._render_character_professions(professions)
            scanned_count = character.get("scanned_profession_count", 0) or 0
            profession_count = character.get("profession_count", 0) or 0
            if profession_count <= 0:
                scanned_text = "-"
            else:
                scanned_text = "oui" if scanned_count >= profession_count else "non"
            values = (
                character.get("name") or "-",
                character.get("realm") or "-",
                character.get("level") or "-",
                professions_text,
                scanned_text,
                character.get("last_logout") or character.get("last_update") or "-",
            )
            state.tree.insert("", "end", iid=row_id, values=values)

        total_characters = report.get("character_count", 0) or 0
        visible_character_count = len(visible_characters)
        visible_profession_count = sum((character.get("profession_count", 0) or 0) for character in visible_characters)
        visible_scanned_professions = sum((character.get("scanned_profession_count", 0) or 0) for character in visible_characters)
        summary = f"{visible_character_count}/{total_characters} personnages"
        if selected_filter != "Tous":
            summary += f" | filtre: {selected_filter}"
        if visible_profession_count:
            summary += f" | {visible_scanned_professions}/{visible_profession_count} métiers scannés"
        else:
            summary += " | aucun métier"
        state.summary_var.set(summary)
        if first_row_id is not None:
            first_row_id = state.tree.get_children()[0] if state.tree.get_children() else first_row_id
            state.tree.selection_set(first_row_id)
            state.tree.focus(first_row_id)
            self._set_character_details(state, self._render_character_details(visible_characters[0]))
        else:
            self._set_character_details(state, "Aucun personnage trouvé pour ce filtre.")

    def _apply_character_filter(self, state: _CharactersTabState) -> None:
        report = state.current_report
        if report is None:
            return
        self._apply_character_report(state, report)

    def _update_character_filter_options(self, state: _CharactersTabState, report: dict[str, Any]) -> None:
        professions = sorted(
            {
                str(profession.get("name"))
                for character in report.get("characters", [])
                for profession in (character.get("professions") or [])
                if profession.get("name")
            },
            key=str.casefold,
        )
        options = ["Tous", *professions]
        current = state.filter_var.get().strip() or "Tous"
        if current not in options:
            current = "Tous"
        state.filter_combo.configure(values=options)
        state.filter_var.set(current)

    def _refresh_specialization_tab(self, state: _SpecializationTabState) -> None:
        state.refresh_button.configure(state="disabled")
        try:
            report = load_character_profession_scans()
            report["spec_dump"] = load_yaya_profession_specializations()
            report["rows"] = self._build_specialization_rows(report)
        except Exception as exc:  # pragma: no cover - GUI error path
            details = traceback.format_exc()
            self._set_specialization_empty(state, "Erreur", str(exc))
            state.summary_var.set("Erreur")
            messagebox.showerror("Spécialisation", str(exc), parent=self.root)
        else:
            state.current_report = report
            self._apply_specialization_report(state, report)
        finally:
            state.refresh_button.configure(state="normal")

    def _refresh_lumber_tab(self, state: _LumberTabState) -> None:
        state.refresh_button.configure(state="disabled")
        state.summary_var.set("Analyse en cours...")
        params = {
            "region": state.region_var.get().strip().lower() or DEFAULT_REGION,
            "sync": bool(state.sync_var.get()),
            "force": bool(state.force_var.get()),
        }
        worker = threading.Thread(target=self._run_lumber_refresh, args=(state, params), daemon=True)
        worker.start()

    def _load_mounts_tab(self, state: _MountsTabState) -> None:
        try:
            payload = load_mount_catalog()
        except Exception as exc:  # pragma: no cover - GUI error path
            state.summary_var.set("Catalogue illisible")
            self._set_mount_details(state, str(exc))
            return
        state.current_payload = payload
        state.all_rows = list(payload.get("mounts") or [])
        expansions = sorted({str(row.get("expansion") or "Inconnue") for row in state.all_rows})
        state.expansion_combo.configure(values=["Toutes", *expansions])
        self._apply_mount_filters(state)

    def _start_mount_catalog_sync(self, state: _MountsTabState) -> None:
        state.refresh_button.configure(state="disabled")
        state.summary_var.set("Synchronisation du catalogue des montures en cours...")
        worker = threading.Thread(
            target=self._run_mount_catalog_sync,
            args=(state, bool(state.force_var.get())),
            daemon=True,
        )
        worker.start()

    def _run_mount_catalog_sync(self, state: _MountsTabState, force: bool) -> None:
        try:
            summary = sync_mount_catalog(force=force)
            payload = load_mount_catalog()
        except Exception as exc:  # pragma: no cover - GUI error path
            details = traceback.format_exc()
            self.root.after(0, lambda error=exc, trace=details: self._handle_mount_sync_error(state, error, trace))
            return
        self.root.after(0, lambda: self._apply_mount_catalog(state, payload, summary))

    def _apply_mount_catalog(
        self,
        state: _MountsTabState,
        payload: dict[str, Any],
        summary: dict[str, Any],
    ) -> None:
        state.refresh_button.configure(state="normal")
        state.current_payload = payload
        state.all_rows = list(payload.get("mounts") or [])
        expansions = sorted({str(row.get("expansion") or "Inconnue") for row in state.all_rows})
        state.expansion_combo.configure(values=["Toutes", *expansions])
        self._apply_mount_filters(state)
        if summary.get("failures"):
            state.summary_var.set(
                f"{summary.get('count', 0)} montures synchronisées | "
                f"{summary.get('failures')} détails à vérifier | source Warcraft Mounts"
            )

    def _apply_mount_filters(self, state: _MountsTabState) -> None:
        rows = list(state.all_rows)
        query = state.query_var.get().strip().casefold()
        expansion = state.expansion_var.get()
        availability = state.availability_var.get()
        if query:
            rows = [
                row
                for row in rows
                if query in " ".join(
                    str(row.get(key) or "")
                    for key in ("display_name", "name", "source_text", "notes", "category_label")
                ).casefold()
            ]
        if expansion and expansion != "Toutes":
            rows = [row for row in rows if row.get("expansion") == expansion]
        if state.no_rmt_var.get():
            rows = [row for row in rows if not row.get("is_rmt")]
        if availability == "Toujours obtenables":
            rows = [row for row in rows if row.get("is_always_obtainable")]
        elif availability == "Obtenables maintenant":
            rows = [row for row in rows if row.get("currently_obtainable")]
        elif availability == "Retirées":
            rows = [row for row in rows if row.get("availability") == "retired"]
        elif availability == "À venir":
            rows = [row for row in rows if row.get("availability") == "upcoming"]
        elif availability == "Non implémentées":
            rows = [row for row in rows if row.get("availability") == "unimplemented"]

        sort_mode = state.sort_var.get()
        if sort_mode == "Temps estimé ↑":
            rows.sort(key=lambda row: (row.get("estimated_hours") is None, row.get("estimated_hours") or 0, str(row.get("display_name") or "").casefold()))
        elif sort_mode == "Nom A→Z":
            rows.sort(key=lambda row: str(row.get("display_name") or row.get("name") or "").casefold())
        elif sort_mode == "Extension":
            rows.sort(key=lambda row: (str(row.get("expansion") or ""), str(row.get("display_name") or "").casefold()))
        else:
            rows.sort(
                key=lambda row: (
                    -int(row.get("reliability_score") or 0),
                    row.get("estimated_hours") is None,
                    row.get("estimated_hours") or 0,
                    str(row.get("display_name") or row.get("name") or "").casefold(),
                )
            )

        for item in state.tree.get_children():
            state.tree.delete(item)
        state.row_lookup.clear()
        first_row_id: str | None = None
        for row in rows:
            mount_id = str(row.get("warcraft_mounts_id") or row.get("blizzard_id") or len(state.row_lookup))
            row_id = f"mount-{mount_id}"
            state.row_lookup[row_id] = row
            if first_row_id is None:
                first_row_id = row_id
            tags: list[str] = []
            if row.get("availability") != "available":
                tags.append("unavailable")
            if row.get("is_rmt"):
                tags.append("rmt")
            insert_options = {
                "iid": row_id,
                "text": row.get("display_name") or row.get("name") or "-",
                "values": (
                    row.get("expansion") or "-",
                    row.get("category_label") or "-",
                    self._mount_availability_label(row),
                    f"{row.get('reliability_score', 0)}/100",
                    row.get("time_estimate") or "-",
                ),
                "tags": tags,
            }
            image = state.icon_images.get(row.get("image_url") or "")
            if image is not None:
                insert_options["image"] = image
            state.tree.insert("", "end", **insert_options)

        total = len(state.all_rows)
        available = sum(1 for row in state.all_rows if row.get("currently_obtainable"))
        visible = len(rows)
        synced_at = (state.current_payload or {}).get("synced_at") or "jamais"
        state.summary_var.set(f"{visible}/{total} affichées | {available} disponibles maintenant | catalogue : {synced_at[:10]}")
        if first_row_id is not None:
            state.tree.selection_set(first_row_id)
            state.tree.focus(first_row_id)
            self._show_selected_mount(state, state.tree)
        else:
            self._set_mount_details(state, "Aucune monture ne correspond aux filtres.")
            state.image_label.configure(image="", text="Aucune sélection")
            state.open_button.configure(state="disabled")

    def _mount_availability_label(self, row: dict[str, Any]) -> str:
        return {
            "available": "Disponible",
            "retired": "Retirée",
            "upcoming": "À venir",
            "unimplemented": "Non implémentée",
        }.get(str(row.get("availability") or ""), "À vérifier")

    def _show_selected_mount(self, state: _MountsTabState, tree: ttk.Treeview) -> None:
        selection = tree.selection()
        if not selection:
            return
        row = state.row_lookup.get(selection[0])
        if row is None:
            return
        self._set_mount_details(state, self._render_mount_details(row))
        state.open_button.configure(state="normal" if row.get("wowhead_url") else "disabled")
        self._start_mount_image_load(state, row)

    def _start_mount_image_load(self, state: _MountsTabState, row: dict[str, Any]) -> None:
        image_url = str(row.get("image_url") or "")
        if not image_url or Image is None or ImageTk is None:
            state.image_label.configure(image="", text="Image indisponible")
            return
        cached_image = state.icon_images.get(image_url)
        if cached_image is not None:
            state.image_label.configure(image=cached_image, text="")
            return

        mount_id = str(row.get("warcraft_mounts_id") or row.get("blizzard_id") or "")
        state.image_label.configure(image="", text="Chargement de l’image…")

        def worker() -> None:
            try:
                request = urllib.request.Request(image_url, headers={"User-Agent": "wow-tools/0.1", "Accept": "image/*"})
                with urllib.request.urlopen(request, timeout=10) as response:
                    payload = response.read()
            except Exception:
                payload = None
            self.root.after(0, lambda: self._apply_mount_image(state, image_url, mount_id, payload))

        threading.Thread(target=worker, daemon=True).start()

    def _apply_mount_image(
        self,
        state: _MountsTabState,
        image_url: str,
        mount_id: str,
        payload: bytes | None,
    ) -> None:
        if not payload:
            state.image_label.configure(image="", text="Image indisponible")
            return
        try:
            image = Image.open(io.BytesIO(payload)).convert("RGBA")
            image.thumbnail((420, 220), Image.Resampling.LANCZOS)
            photo = ImageTk.PhotoImage(image, master=self.root)
        except Exception:
            state.image_label.configure(image="", text="Image indisponible")
            return
        state.icon_images[image_url] = photo
        selected = state.tree.selection()
        selected_row = state.row_lookup.get(selected[0]) if selected else None
        selected_id = str((selected_row or {}).get("warcraft_mounts_id") or (selected_row or {}).get("blizzard_id") or "")
        if selected_id == mount_id:
            state.image_label.configure(image=photo, text="")

    def _open_selected_mount(self, state: _MountsTabState) -> None:
        selection = state.tree.selection()
        row = state.row_lookup.get(selection[0]) if selection else None
        url = str((row or {}).get("wowhead_url") or "")
        if url:
            webbrowser.open(url)

    def _set_mount_details(self, state: _MountsTabState, text: str) -> None:
        state.details_text.configure(state="normal")
        state.details_text.delete("1.0", "end")
        state.details_text.insert("1.0", text)
        state.details_text.configure(state="disabled")

    def _render_mount_details(self, row: dict[str, Any]) -> str:
        lines = [
            f"Monture: {row.get('display_name') or row.get('name') or '-'}",
            f"Extension: {row.get('expansion') or '-'}",
            f"Source: {row.get('category_label') or '-'}",
            f"État: {self._mount_availability_label(row)}",
            f"Sans RMT: {'oui' if not row.get('is_rmt') else 'non'}",
            f"Fiabilité: {row.get('reliability_score', 0)}/100 — {row.get('reliability_label') or '-'}",
            f"Timegate: {row.get('time_gate') or '-'}",
            f"Temps estimé: {row.get('time_estimate') or '-'}",
            f"Niveau requis: {row.get('required_level') or '-'}",
            f"Mode de déplacement: {row.get('travel_mode') or '-'}",
            "",
            "Obtention",
        ]
        sources = row.get("sources") or []
        lines.extend(f"- {source}" for source in sources)
        if not sources:
            lines.append("- Source détaillée indisponible")
        if row.get("notes"):
            lines.extend(["", f"Notes: {row['notes']}"])
        lines.extend(["", f"Wowhead: {row.get('wowhead_url') or 'lien indisponible'}"])
        return "\n".join(lines)

    def _handle_mount_sync_error(self, state: _MountsTabState, error: Exception, details: str) -> None:
        state.refresh_button.configure(state="normal")
        state.summary_var.set("Synchronisation impossible")
        self._set_mount_details(state, details)
        messagebox.showerror("Catalogue des montures", str(error), parent=self.root)

    def _run_lumber_refresh(self, state: _LumberTabState, params: dict[str, Any]) -> None:
        try:
            region = params["region"]
            conn = connect(DB_PATH)
            if params["sync"]:
                cache = HttpCache(CACHE_DIR)
                sync_recipe_prices(conn, cache, region, force=params["force"])
            conn.close()
            report = build_logging_lumber_report(region)
        except Exception as exc:  # pragma: no cover - GUI error path
            details = traceback.format_exc()
            self.root.after(0, lambda error=exc, trace=details: self._handle_lumber_error(state, error, trace))
            return
        self.root.after(0, lambda: self._apply_lumber_report(state, report))

    def _apply_lumber_report(self, state: _LumberTabState, report: dict[str, Any]) -> None:
        state.current_report = report
        state.row_lookup.clear()
        for item in state.tree.get_children():
            state.tree.delete(item)

        first_row_id: str | None = None
        rows = report.get("rows", [])
        for index, row in enumerate(rows):
            row_id = f"lumber-{index}"
            if first_row_id is None:
                first_row_id = row_id
            state.row_lookup[row_id] = row
            values = (
                row.get("expansion") or "-",
                row.get("wood_name") or "-",
                _format_lumber_profession(row.get("best_profession")),
                format_copper(row.get("estimated_value_per_wood_copper")),
                format_copper(row.get("avg_craft_profit_copper")),
                format_number(row.get("avg_product_sell_rate")),
                row.get("product_count") or 0,
                row.get("product_market_count") or 0,
                format_copper(row.get("wood_price_copper")),
            )
            state.tree.insert("", "end", iid=row_id, values=values)

        region = str(report.get("region") or DEFAULT_REGION).upper()
        has_live_data = any((row.get("estimated_value_per_wood_copper") or 0) != 0 for row in rows)
        summary = f"{len(rows)} bois | région {region} | base prix avgSell | valeur = profit craft moyen avec malus sell rate"
        if not has_live_data:
            summary += " | coche Sync prices"
        state.summary_var.set(summary)
        if first_row_id is not None:
            state.tree.selection_set(first_row_id)
            state.tree.focus(first_row_id)
            self._set_lumber_details(state, self._render_lumber_details(rows[0]))
        else:
            self._set_lumber_details(state, "Aucune donnée lumber trouvée.")
        state.refresh_button.configure(state="normal")

    def _show_selected_lumber(self, state: _LumberTabState, tree: ttk.Treeview) -> None:
        selection = tree.selection()
        if not selection:
            return
        row = state.row_lookup.get(selection[0])
        if row is None:
            return
        self._set_lumber_details(state, self._render_lumber_details(row))

    def _set_lumber_details(self, state: _LumberTabState, text: str) -> None:
        state.details_text.configure(state="normal")
        state.details_text.delete("1.0", "end")
        state.details_text.insert("1.0", text)
        state.details_text.configure(state="disabled")

    def _handle_lumber_error(self, state: _LumberTabState, error: Exception, details: str) -> None:
        state.refresh_button.configure(state="normal")
        state.summary_var.set("Erreur")
        self._set_lumber_details(state, details)
        messagebox.showerror("Lumber", str(error), parent=self.root)

    def _render_lumber_details(self, row: dict[str, Any]) -> str:
        lines = [
            f"Extension: {row.get('expansion') or '-'}",
            f"Bois: {row.get('wood_name') or '-'} ({row.get('wood_item_id') or '-'})",
            f"Meilleur métier par bois: {_format_lumber_profession(row.get('best_profession'))}",
            f"Prix bois (avgSell): {format_copper(row.get('wood_price_copper'))}",
            f"Produits logging: {row.get('product_count') or 0}",
            f"Produits pricés: {row.get('product_market_count') or 0}",
            f"Profit craft moyen: {format_copper(row.get('avg_craft_profit_copper'))}",
            f"Sell rate moyen: {format_number(row.get('avg_product_sell_rate'))}",
            f"Malus moyen: {format_number(row.get('avg_liquidity_factor'))}",
            f"Valeur estimée / bois: {format_copper(row.get('estimated_value_per_wood_copper'))}",
            f"Formule: profit_net = prix_vente*0.95 - cout_craft",
            f"Formule: facteur = sell_rate / (sell_rate + 0.10)",
            f"Formule finale: moyenne((profit_net * facteur) / qte_bois)",
            "",
            "Top produits",
        ]
        for product in row.get("top_products") or []:
            lines.append(
                f"- [{_format_lumber_profession(product.get('profession'))}] "
                f"{product.get('item_name') or product['item_id']}: "
                f"profit {format_copper(product.get('craft_profit_copper'))} | "
                f"sr {format_number(product.get('sell_rate'))} | "
                f"qte bois {format_number(product.get('wood_quantity'))} | "
                f"val/bois {format_copper(int(round(product.get('adjusted_profit_per_wood') or 0)))}"
            )
        if not row.get("top_products"):
            lines.append("- aucun produit pricé localement")
        return "\n".join(lines)

    def _schedule_auction_autocomplete(self, state: _AuctionTabState, event: tk.Event) -> None:
        if event.keysym in {"Up", "Down", "Return", "Escape"}:
            return
        state.selected_variant_key = None
        if state.autocomplete_after is not None:
            try:
                self.root.after_cancel(state.autocomplete_after)
            except tk.TclError:
                pass
            state.autocomplete_after = None
        query = state.query_var.get().strip()
        if len(query) < 2:
            self._hide_auction_suggestions(state)
            return
        state.autocomplete_after = self.root.after(
            180,
            lambda current=state, current_query=query: self._start_auction_autocomplete(current, current_query),
        )

    def _start_auction_autocomplete(self, state: _AuctionTabState, query: str) -> None:
        state.autocomplete_after = None
        worker = threading.Thread(target=self._run_auction_autocomplete, args=(state, query), daemon=True)
        worker.start()

    def _run_auction_autocomplete(self, state: _AuctionTabState, query: str) -> None:
        try:
            conn = connect(DB_PATH)
            rows = suggest_auction_items(conn, query, limit=8)
            conn.close()
        except Exception:
            return
        self.root.after(
            0,
            lambda current=state, current_query=query, current_rows=rows: self._apply_auction_suggestions(
                current, current_query, current_rows
            ),
        )

    def _apply_auction_suggestions(
        self,
        state: _AuctionTabState,
        query: str,
        rows: list[dict[str, Any]],
    ) -> None:
        if state.query_var.get().strip() != query:
            return
        state.suggestions.delete(0, tk.END)
        state.suggestion_rows = rows
        for row in rows:
            state.suggestions.insert(tk.END, row.get("display_name") or row.get("item_name") or "-")
        if rows:
            state.suggestions.grid()
            state.suggestions.activate(0)
        else:
            self._hide_auction_suggestions(state)

    def _focus_auction_suggestions(self, state: _AuctionTabState) -> str:
        if state.suggestions.winfo_ismapped() and state.suggestion_rows:
            state.suggestions.focus_set()
            state.suggestions.selection_set(0)
            state.suggestions.activate(0)
        return "break"

    def _select_auction_suggestion(self, state: _AuctionTabState) -> str:
        selection = state.suggestions.curselection()
        if not selection and state.suggestion_rows:
            selection = (0,)
        if not selection or selection[0] >= len(state.suggestion_rows):
            return "break"
        row = state.suggestion_rows[selection[0]]
        state.query_var.set(str(row.get("search_name") or row.get("item_name") or ""))
        state.selected_variant_key = row.get("variant_key")
        self._hide_auction_suggestions(state)
        state.search_entry.focus_set()
        self._start_auction_search(state)
        return "break"

    def _handle_auction_return(self, state: _AuctionTabState) -> str:
        if state.suggestions.winfo_ismapped() and state.suggestion_rows:
            return self._select_auction_suggestion(state)
        self._start_auction_search(state)
        return "break"

    def _hide_auction_suggestions(self, state: _AuctionTabState) -> None:
        state.suggestions.grid_remove()
        state.suggestions.selection_clear(0, tk.END)
        state.suggestion_rows = []

    def _start_auction_search(self, state: _AuctionTabState) -> None:
        query = state.query_var.get().strip()
        if not query:
            state.summary_var.set("Tape un nom d’objet.")
            return
        self._hide_auction_suggestions(state)
        state.search_button.configure(state="disabled")
        state.summary_var.set("Recherche locale en cours...")
        params = {
            "query": query,
            "region": state.region_var.get().strip().lower() or DEFAULT_REGION,
            "variant_key": state.selected_variant_key,
        }
        worker = threading.Thread(target=self._run_auction_search, args=(state, params), daemon=True)
        worker.start()

    def _run_auction_search(self, state: _AuctionTabState, params: dict[str, Any]) -> None:
        try:
            conn = connect(DB_PATH)
            report = build_auction_report(
                conn,
                params["query"],
                params["region"],
                variant_key=params["variant_key"],
            )
            conn.close()
            report["icon_bytes"] = self._fetch_auction_icon_bytes(report)
        except Exception as exc:  # pragma: no cover - GUI error path
            details = traceback.format_exc()
            self.root.after(0, lambda error=exc, trace=details: self._handle_auction_error(state, error, trace, "Recherche"))
            return
        self.root.after(0, lambda: self._apply_auction_report(state, report))

    def _start_auction_realms(self, state: _AuctionTabState) -> None:
        state.realms_button.configure(state="disabled")
        state.summary_var.set("Récupération des groupes de royaumes Blizzard...")
        region = state.region_var.get().strip().lower() or DEFAULT_REGION
        worker = threading.Thread(target=self._run_auction_realms, args=(state, region), daemon=True)
        worker.start()

    def _run_auction_realms(self, state: _AuctionTabState, region: str) -> None:
        try:
            conn = connect(DB_PATH)
            summary = sync_auction_realms(
                conn,
                BlizzardClient(),
                region,
            )
            conn.close()
        except Exception as exc:  # pragma: no cover - GUI error path
            details = traceback.format_exc()
            self.root.after(0, lambda error=exc, trace=details: self._handle_auction_error(state, error, trace, "Royaumes"))
            return
        self.root.after(0, lambda: self._auction_operation_done(state, f"{summary['realms']} groupes de royaumes enregistrés."))

    def _start_auction_sync(self, state: _AuctionTabState) -> None:
        state.sync_button.configure(state="disabled")
        state.realms_button.configure(state="disabled")
        state.search_button.configure(state="disabled")
        state.summary_var.set("Synchronisation AH Blizzard en cours : plusieurs minutes possibles...")
        params = {
            "region": state.region_var.get().strip().lower() or DEFAULT_REGION,
            "query": state.query_var.get().strip(),
            "variant_key": state.selected_variant_key,
        }
        worker = threading.Thread(target=self._run_auction_sync, args=(state, params), daemon=True)
        worker.start()

    def _run_auction_sync(self, state: _AuctionTabState, params: dict[str, Any]) -> None:
        try:
            conn = connect(DB_PATH)
            cache = HttpCache(CACHE_DIR)
            region = params["region"]
            sync_auction_catalog(conn, cache, region)
            summary = sync_auction_data(conn, cache, region)
            report = (
                build_auction_report(
                    conn,
                    params["query"],
                    region,
                    variant_key=params["variant_key"],
                )
                if params["query"]
                else None
            )
            conn.close()
            if report is not None:
                report["icon_bytes"] = self._fetch_auction_icon_bytes(report)
        except Exception as exc:  # pragma: no cover - GUI error path
            details = traceback.format_exc()
            self.root.after(0, lambda error=exc, trace=details: self._handle_auction_error(state, error, trace, "Synchronisation AH"))
            return
        self.root.after(0, lambda: self._apply_auction_sync(state, summary, report))

    def _auction_operation_done(self, state: _AuctionTabState, message: str) -> None:
        state.realms_button.configure(state="normal")
        state.sync_button.configure(state="normal")
        state.search_button.configure(state="normal")

    def _sort_auction_tree(self, state: _AuctionTabState, column: str, *, toggle: bool = True) -> None:
        if toggle:
            if state.sort_column == column:
                state.sort_reverse = not state.sort_reverse
            else:
                state.sort_column = column
                state.sort_reverse = False

        item_ids = list(state.tree.get_children())
        rows_with_price = [
            item_id for item_id in item_ids if state.row_lookup[item_id]["realm"].get("price_copper") is not None
        ]
        rows_without_price = [
            item_id for item_id in item_ids if state.row_lookup[item_id]["realm"].get("price_copper") is None
        ]

        def key(item_id: str) -> Any:
            row = state.row_lookup[item_id]
            variant = row["variant"]
            realm = row["realm"]
            values = {
                "variant": str(variant.get("label") or "").casefold(),
                "realm": str(realm.get("name") or "").casefold(),
                "price": realm.get("price_copper") or 0,
                "quantity": int(realm.get("available_quantity") or 0),
                "listings": int(realm.get("listing_count") or 0),
                "updated": str(realm.get("fetched_at") or ""),
            }
            return values.get(state.sort_column, "")

        rows_with_price.sort(key=key, reverse=state.sort_reverse)
        ordered = rows_with_price + rows_without_price
        for index, item_id in enumerate(ordered):
            state.tree.move(item_id, "", index)

        labels = {
            "variant": "Objet / rang",
            "realm": "Groupe EU",
            "price": "Prix minimum",
            "quantity": "Quantité",
            "listings": "Annonces",
            "updated": "Actualisé",
        }
        for heading, label in labels.items():
            arrow = " ↓" if heading == state.sort_column and state.sort_reverse else " ↑" if heading == state.sort_column else ""
            state.tree.heading(heading, text=label + arrow)
        state.summary_var.set(message)

    def _apply_auction_sync(self, state: _AuctionTabState, summary: dict[str, Any], report: dict[str, Any] | None) -> None:
        self._auction_operation_done(
            state,
            f"AH synchronisée : {summary['synced']}/{summary['realms']} groupes | "
            f"commodités EU: {summary['commodities']} | échecs: {len(summary['failed'])}",
        )
        if report is not None:
            self._apply_auction_report(state, report)

    def _apply_auction_report(self, state: _AuctionTabState, report: dict[str, Any]) -> None:
        self._hide_auction_suggestions(state)
        state.current_report = report
        state.row_lookup.clear()
        state.icon_images.clear()
        for item in state.tree.get_children():
            state.tree.delete(item)

        icon_bytes = report.get("icon_bytes") or {}
        if Image is not None and ImageTk is not None:
            for icon_url, payload in icon_bytes.items():
                try:
                    image = Image.open(io.BytesIO(payload)).convert("RGBA")
                    image.thumbnail((30, 30), Image.Resampling.LANCZOS)
                    state.icon_images[icon_url] = ImageTk.PhotoImage(image, master=self.root)
                except Exception:
                    continue

        first_row_id: str | None = None
        row_index = 0
        for variant in report.get("variants") or []:
            available_rows = [
                realm for realm in variant.get("realm_rows") or [] if realm.get("has_listing")
            ]
            best_price = min(
                (realm.get("price_copper") for realm in available_rows if realm.get("price_copper") is not None),
                default=None,
            )
            for realm in variant.get("realm_rows") or []:
                if state.available_only_var.get() and not realm.get("has_listing"):
                    continue
                row_id = f"auction-{row_index}"
                row_index += 1
                if first_row_id is None:
                    first_row_id = row_id
                row = {"variant": variant, "realm": realm}
                state.row_lookup[row_id] = row
                tags: list[str] = []
                if not realm.get("has_listing"):
                    tags.append("empty")
                elif best_price is not None and realm.get("price_copper") == best_price:
                    tags.append("best")
                state.tree.insert(
                    "",
                    "end",
                    iid=row_id,
                    values=(
                        variant.get("label") or "-",
                        realm.get("name") or "-",
                        format_copper(realm.get("price_copper")),
                        realm.get("available_quantity") or 0,
                        realm.get("listing_count") or 0,
                        realm.get("fetched_at") or "-",
                    ),
                    image=state.icon_images.get(variant.get("icon_url")),
                    tags=tags,
                )
        if report.get("matches"):
            state.summary_var.set(
                f"{len(report.get('variants') or [])} variantes | "
                f"{report.get('realm_count', 0)} groupes EU | "
                f"snapshot: {report.get('latest_snapshot') or 'aucun'}"
            )
        else:
            state.summary_var.set("Aucun item trouvé. Lance « Synchroniser AH » si le catalogue est vide.")
        if first_row_id is not None:
            state.tree.selection_set(first_row_id)
            state.tree.focus(first_row_id)
            self._set_auction_details(state, self._render_auction_row(state.row_lookup[first_row_id]))
        else:
            self._set_auction_details(state, "Aucune donnée de prix. Synchronise l’AH Blizzard.")
        state.search_button.configure(state="normal")

    def _refresh_auction_filter(self, state: _AuctionTabState) -> None:
        if state.current_report is not None:
            self._apply_auction_report(state, state.current_report)

    def _fetch_auction_icon_bytes(self, report: dict[str, Any]) -> dict[str, bytes]:
        """Download only the few icons needed by the current search and cache them."""
        urls = {
            variant.get("icon_url")
            for variant in report.get("variants") or []
            if variant.get("icon_url")
        }
        icon_cache_dir = Path(CACHE_DIR) / "wow-icons"
        icon_cache_dir.mkdir(parents=True, exist_ok=True)
        result: dict[str, bytes] = {}
        for url in list(urls)[:32]:
            cache_path = icon_cache_dir / f"{hashlib.sha256(url.encode('utf-8')).hexdigest()}.jpg"
            try:
                payload = cache_path.read_bytes() if cache_path.exists() else None
                if payload is None:
                    request = urllib.request.Request(
                        url,
                        headers={"User-Agent": "wow-tools/0.1", "Accept": "image/jpeg,image/*"},
                    )
                    with urllib.request.urlopen(request, timeout=10) as response:
                        payload = response.read()
                    cache_path.write_bytes(payload)
                if payload:
                    result[url] = payload
            except (OSError, urllib.error.URLError):
                continue
        return result

    def _show_selected_auction(self, state: _AuctionTabState, tree: ttk.Treeview) -> None:
        selection = tree.selection()
        if not selection:
            return
        row = state.row_lookup.get(selection[0])
        if row is not None:
            self._set_auction_details(state, self._render_auction_row(row))

    def _set_auction_details(self, state: _AuctionTabState, text: str) -> None:
        state.details_text.configure(state="normal")
        state.details_text.delete("1.0", "end")
        state.details_text.insert("1.0", text)
        state.details_text.configure(state="disabled")

    def _render_auction_row(self, row: dict[str, Any]) -> str:
        variant = row["variant"]
        realm = row["realm"]
        return "\n".join(
            [
                f"Objet: {variant.get('label') or '-'}",
                f"Item ID: {variant.get('item_id') or '-'}",
                f"Niveau/rang décodé: {variant.get('item_level') or '-'}",
                f"Groupe: {realm.get('name') or '-'}",
                f"Prix unitaire minimum: {format_copper(realm.get('price_copper'))}",
                f"Quantité disponible: {realm.get('available_quantity') or 0}",
                f"Annonces: {realm.get('listing_count') or 0}",
                f"Snapshot: {realm.get('fetched_at') or '-'}",
                "",
                "Les prix d’objets non-commodités sont par groupe de royaumes connectés. Les commodités sont affichées au niveau EU.",
            ]
        )

    def _handle_auction_error(self, state: _AuctionTabState, error: Exception, details: str, operation: str) -> None:
        self._auction_operation_done(state, "Erreur")
        self._set_auction_details(state, details)
        messagebox.showerror(operation, str(error), parent=self.root)

    def _build_specialization_rows(self, report: dict[str, Any]) -> list[dict[str, Any]]:
        rows: list[dict[str, Any]] = []
        spec_dump = report.get("spec_dump", {})
        spec_characters = spec_dump.get("characters", {}) if isinstance(spec_dump, dict) else {}
        for character in report.get("characters", []):
            level = character.get("level")
            if not isinstance(level, int) or level <= 80:
                continue
            primary_professions = [
                profession
                for profession in character.get("professions") or []
                if _is_specialization_tab_profession(profession)
            ]
            character_key = f"{character.get('realm')}.{character.get('name')}"
            spec_snapshot = spec_characters.get(character_key)
            supported = [
                profession
                for profession in primary_professions
                if (profession.get("name") or "") in _SPECIALIZATION_PLANS
            ]
            supported_names = [profession.get("name") or "" for profession in supported]
            if len(supported_names) >= 2:
                status = "Prêt"
                setup = " + ".join(supported_names[:2])
                focus = "double moteur"
            elif len(supported_names) == 1:
                status = "À compléter"
                complement = (_SPECIALIZATION_COMPLEMENTS.get(supported_names[0], []) or ["à choisir"])[0]
                setup = f"{supported_names[0]} + {complement}"
                focus = "1 métier fort"
            else:
                status = "Sans plan"
                setup = "Reroll métier conseillé"
                focus = "aucun preset"

            profession_labels = [profession.get("name") or "Inconnu" for profession in primary_professions[:2]]
            tracks = [
                _SPECIALIZATION_PLANS[name]["track"]
                for name in supported_names[:2]
                if name in _SPECIALIZATION_PLANS
            ]
            recommendations = self._build_specialization_recommendations(supported_names, spec_snapshot)
            rows.append(
                {
                    "name": character.get("name") or "-",
                    "realm": character.get("realm") or "-",
                    "level": level,
                    "last_logout": character.get("last_logout") or character.get("last_update") or "-",
                    "last_logout_ts": character.get("last_logout_ts") or character.get("last_update_ts") or 0,
                    "professions": primary_professions,
                    "profession_names": profession_labels,
                    "supported_professions": supported_names,
                    "setup": setup,
                    "focus": focus,
                    "status": status,
                    "tracks": tracks,
                    "spec_snapshot": spec_snapshot,
                    "has_live_spec": bool(spec_snapshot),
                    "recommendations": recommendations,
                }
            )
        rows.sort(
            key=lambda row: (
                -(row.get("last_logout_ts") or 0),
                row["name"].casefold(),
            )
        )
        return rows

    def _build_specialization_recommendations(
        self,
        supported_names: list[str],
        spec_snapshot: dict[str, Any] | None,
    ) -> list[dict[str, str]]:
        recommendations: list[dict[str, str]] = []
        live_professions = self._profession_snapshot_lookup(spec_snapshot)

        for profession_name in supported_names[:2]:
            decisions = _SPECIALIZATION_DECISIONS.get(profession_name, [])
            live_profession = live_professions.get(_normalize_spec_label(profession_name))
            node_lookup = self._build_node_rank_lookup(live_profession)

            if live_profession and decisions:
                upcoming_steps: list[dict[str, str]] = []
                for decision in decisions:
                    node_name = decision.get("node")
                    target = int(decision.get("target") or 0)
                    if node_name:
                        current = node_lookup.get(_normalize_spec_label(node_name), {}).get("current_rank", 0)
                        step_label = f"{node_name}: {current}/{target}"
                        step_reason = decision.get("label") or "prochain palier"
                        if current < target:
                            upcoming_steps.append(
                                {
                                    "profession": profession_name,
                                    "step": step_label,
                                    "reason": step_reason,
                                }
                            )
                        elif upcoming_steps:
                            upcoming_steps.append(
                                {
                                    "profession": profession_name,
                                    "step": f"{node_name}: {target}/{target}",
                                    "reason": step_reason,
                                }
                            )
                    else:
                        invested = max((entry.get("current_rank", 0) for entry in node_lookup.values()), default=0)
                        upcoming_steps.append(
                            {
                                "profession": profession_name,
                                "step": f"Branche active: {invested}/{target}",
                                "reason": decision.get("label") or "continue la branche active",
                            }
                        )
                    if len(upcoming_steps) >= 3:
                        break

                if upcoming_steps:
                    recommendations.extend(upcoming_steps[:3])
                else:
                    recommendations.append(
                        {
                            "profession": profession_name,
                            "step": "Plan principal terminé",
                            "reason": _SPECIALIZATION_PLANS[profession_name]["next_steps"][0],
                        }
                    )
            else:
                fallback = _SPECIALIZATION_PLANS.get(profession_name)
                if fallback is None:
                    continue
                recommendations.append(
                    {
                        "profession": profession_name,
                        "step": fallback["phases"][0],
                        "reason": "pas de dump pour ce perso",
                    }
                )

        return recommendations

    def _profession_snapshot_lookup(self, spec_snapshot: dict[str, Any] | None) -> dict[str, dict[str, Any]]:
        if not spec_snapshot:
            return {}
        lookup: dict[str, dict[str, Any]] = {}
        for profession in spec_snapshot.get("professions", []) or []:
            profession_name = profession.get("profession_name")
            parent_name = profession.get("parent_profession_name")
            keys = []
            if profession_name:
                keys.append(_normalize_spec_label(str(profession_name)))
            if parent_name:
                keys.append(_normalize_spec_label(str(parent_name)))

            for key in keys:
                existing = lookup.get(key)
                if existing is None:
                    lookup[key] = profession
                    continue

                profession_label = str(profession.get("profession_name") or "")
                existing_label = str(existing.get("profession_name") or "")
                if "Midnight" in profession_label and "Midnight" not in existing_label:
                    lookup[key] = profession
        return lookup

    def _build_node_rank_lookup(self, profession_snapshot: dict[str, Any] | None) -> dict[str, dict[str, Any]]:
        if not profession_snapshot:
            return {}
        lookup: dict[str, dict[str, Any]] = {}
        for tab in profession_snapshot.get("tabs", []) or []:
            for node in tab.get("nodes", []) or []:
                name = node.get("name")
                if not name:
                    continue
                key = _normalize_spec_label(str(name))
                existing = lookup.get(key)
                if existing is None or int(node.get("current_rank") or 0) > int(existing.get("current_rank") or 0):
                    lookup[key] = node
        return lookup

    def _apply_specialization_filter(self, state: _SpecializationTabState) -> None:
        report = state.current_report
        if report is None:
            return
        self._apply_specialization_report(state, report)

    def _apply_specialization_report(self, state: _SpecializationTabState, report: dict[str, Any]) -> None:
        selected_filter = state.filter_var.get().strip() or "Tous"
        for item in state.tree.get_children():
            state.tree.delete(item)
        state.row_lookup.clear()

        visible_rows = [row for row in report.get("rows", []) if self._specialization_matches_filter(row, selected_filter)]
        first_row_id: str | None = None
        for index, row in enumerate(visible_rows):
            row_id = f"specialization-{index}"
            if first_row_id is None:
                first_row_id = row_id
            state.row_lookup[row_id] = row
            professions = " / ".join(row.get("profession_names") or []) or "Aucun métier"
            recommendations = row.get("recommendations") or []
            if recommendations:
                first_steps: list[str] = []
                seen_professions: set[str] = set()
                for entry in recommendations:
                    profession = entry["profession"]
                    if profession in seen_professions:
                        continue
                    seen_professions.add(profession)
                    first_steps.append(f"{profession}: {entry['step']}")
                    if len(first_steps) >= 2:
                        break
                tracks = " | ".join(first_steps)
            else:
                tracks = " | ".join(row.get("tracks") or []) or (row.get("focus") or "-")
            values = (
                row.get("name") or "-",
                professions,
                tracks,
                row.get("status") or "-",
            )
            state.tree.insert("", "end", iid=row_id, values=values)

        rows = report.get("rows", [])
        ready_count = sum(1 for row in rows if row.get("status") == "Prêt")
        partial_count = sum(1 for row in rows if row.get("status") == "À compléter")
        live_count = sum(1 for row in rows if row.get("has_live_spec"))
        summary = f"{len(visible_rows)}/{len(rows)} persos | dump live: {live_count} | prêts: {ready_count} | à compléter: {partial_count}"
        if selected_filter != "Tous":
            summary += f" | filtre: {selected_filter}"
        state.summary_var.set(summary)

        if first_row_id is not None:
            state.tree.selection_set(first_row_id)
            state.tree.focus(first_row_id)
            self._set_specialization_details(state, visible_rows[0])
        else:
            self._set_specialization_empty(state, "Aucun personnage", "Aucun plan pour ce filtre.")

    def _specialization_matches_filter(self, row: dict[str, Any], selected_filter: str) -> bool:
        if selected_filter == "Tous":
            return True
        return row.get("status") == selected_filter

    def _show_selected_specialization(self, state: _SpecializationTabState, tree: ttk.Treeview) -> None:
        selection = tree.selection()
        if not selection:
            return
        row = state.row_lookup.get(selection[0])
        if row is None:
            return
        self._set_specialization_details(state, row)

    def _set_specialization_empty(self, state: _SpecializationTabState, title: str, subtitle: str) -> None:
        state.hero_var.set(title)
        state.subhero_var.set(subtitle)
        state.setup_var.set("-")
        state.source_var.set("-")
        state.tips_var.set("-")
        for item in state.phases_tree.get_children():
            state.phases_tree.delete(item)

    def _set_specialization_details(self, state: _SpecializationTabState, row: dict[str, Any]) -> None:
        professions = " / ".join(row.get("profession_names") or []) or "Aucun métier"
        state.hero_var.set(f"{row.get('name') or '-'} · {professions}")
        state.subhero_var.set(
            f"{row.get('status') or '-'} · niveau {row.get('level') or '-'} · {row.get('last_logout') or '-'}"
        )
        state.setup_var.set(row.get("setup") or "-")

        tips: list[str] = []
        sources: list[str] = []
        recommendations = row.get("recommendations") or []
        for recommendation in recommendations[:2]:
            tips.append(f"{recommendation['profession']}: {recommendation['reason']}")
        for profession_name in row.get("supported_professions") or []:
            plan = _SPECIALIZATION_PLANS.get(profession_name)
            if plan is None:
                continue
            sources.append(plan["source_label"])
        if row.get("has_live_spec"):
            state.tips_var.set(" | ".join(tips[:2]) or "Aucune recommandation calculée.")
        else:
            state.tips_var.set("Fais /yayaspec dump en jeu pour passer en mode decision live.")
        state.source_var.set(" | ".join(sources[:2]) or "-")

        for item in state.phases_tree.get_children():
            state.phases_tree.delete(item)
        phase_index = 0
        if recommendations:
            for recommendation in recommendations:
                state.phases_tree.insert(
                    "",
                    "end",
                    iid=f"phase-{phase_index}",
                    values=(recommendation["profession"], f"{recommendation['step']} -> {recommendation['reason']}"),
                )
                phase_index += 1
        else:
            for profession_name in row.get("supported_professions") or []:
                plan = _SPECIALIZATION_PLANS.get(profession_name)
                if plan is None:
                    continue
                for phase in plan.get("phases", [])[:2]:
                    state.phases_tree.insert("", "end", iid=f"phase-{phase_index}", values=(profession_name, phase))
                    phase_index += 1

    def _copy_specialization_plan(self, state: _SpecializationTabState) -> None:
        selection = state.tree.selection()
        if not selection:
            messagebox.showinfo("Spécialisation", "Sélectionne un personnage d'abord.", parent=self.root)
            return
        row = state.row_lookup.get(selection[0])
        if row is None:
            return
        payload = self._render_specialization_copy(row)
        self.root.clipboard_clear()
        self.root.clipboard_append(payload)
        messagebox.showinfo("Spécialisation", "Plan copié.", parent=self.root)

    def _render_specialization_copy(self, row: dict[str, Any]) -> str:
        lines = [
            f"Personnage: {row.get('name') or '-'}",
            f"Royaume: {row.get('realm') or '-'}",
            f"Niveau: {row.get('level') or '-'}",
            f"Derniere connexion: {row.get('last_logout') or '-'}",
            f"Etat: {row.get('status') or '-'}",
            f"Setup cible: {row.get('setup') or '-'}",
            "",
        ]
        professions = row.get("professions") or []
        if professions:
            lines.append("Metiers detectes")
            for profession in professions[:2]:
                rank = ""
                if profession.get("rank_current") is not None and profession.get("rank_max") is not None:
                    rank = f" {profession['rank_current']}/{profession['rank_max']}"
                level_name = profession.get("current_level_name") or "tier inconnu"
                lines.append(f"- {profession.get('name') or 'Inconnu'}{rank} [{level_name}]")
            lines.append("")

        supported = row.get("supported_professions") or []
        if supported:
            lines.append("Plan recommande")
            for profession_name in supported[:2]:
                plan = _SPECIALIZATION_PLANS.get(profession_name)
                if plan is None:
                    continue
                lines.append("")
                lines.append(f"[{profession_name}] {plan['track']} ({plan['focus']})")
                lines.append(f"Pourquoi: {plan['why']}")
                matching_profession = next(
                    (profession for profession in professions if (profession.get("name") or "") == profession_name),
                    None,
                )
                if matching_profession is not None and "Midnight" not in str(
                    matching_profession.get("current_level_name") or ""
                ):
                    lines.append("Note: metier detecte mais tier Midnight pas encore monte.")
                for phase in plan.get("phases", []):
                    lines.append(f"- {phase}")
                next_steps = plan.get("next_steps") or []
                if next_steps:
                    lines.append("Suite:")
                    for step in next_steps:
                        lines.append(f"- {step}")
                lines.append(f"Source: {plan['source_label']} - {plan['source_url']}")
        else:
            lines.append("Plan recommande")
            lines.append("- Aucun preset Midnight concentration pour les metiers detectes.")

        if len(supported) == 1:
            complement_targets = _SPECIALIZATION_COMPLEMENTS.get(supported[0], [])
            if complement_targets:
                lines.append("")
                lines.append("Complement conseille")
                lines.append(f"- Ajoute plutot: {', '.join(complement_targets)}")
        elif len(supported) == 0:
            lines.append("")
            lines.append("Suggestion simple")
            lines.append("- Base la plus simple: Enchanting + Tailoring")
            lines.append("- Variante plus volume: Alchemy + Inscription")

        return "\n".join(lines)

    def _character_matches_filter(self, character: dict[str, Any], selected_filter: str) -> bool:
        if selected_filter == "Tous":
            return True
        for profession in character.get("professions") or []:
            if str(profession.get("name") or "").casefold() == selected_filter.casefold():
                return True
        return False

    def _show_selected_character(self, state: _CharactersTabState, tree: ttk.Treeview) -> None:
        selection = tree.selection()
        if not selection:
            return
        row = state.row_lookup.get(selection[0])
        if row is None:
            return
        self._set_character_details(state, self._render_character_details(row))

    def _set_character_details(self, state: _CharactersTabState, text: str) -> None:
        state.details_text.configure(state="normal")
        state.details_text.delete("1.0", "end")
        state.details_text.insert("1.0", text)
        state.details_text.configure(state="disabled")

    def _render_character_professions(self, professions: list[dict[str, Any]]) -> str:
        if not professions:
            return "Aucun métier"
        return ", ".join(profession.get("name") or "Inconnu" for profession in professions)

    def _render_character_profession(self, profession: dict[str, Any]) -> str:
        rank = ""
        if profession.get("rank_current") is not None and profession.get("rank_max") is not None:
            rank = f" {profession['rank_current']}/{profession['rank_max']}"
        tier = f" [{profession['current_level_name']}]" if profession.get("current_level_name") else ""
        status = "oui" if profession.get("recipes_scanned") else "non"
        return f"{profession.get('name') or 'Inconnu'}{rank}{tier}: {status}"

    def _render_character_details(self, row: dict[str, Any]) -> str:
        professions = row.get("professions") or []
        profession_count = row.get("profession_count", 0) or 0
        scanned_count = row.get("scanned_profession_count", 0) or 0

        lines = [
            f"Personnage: {row.get('name') or '-'}",
            f"Royaume: {row.get('realm') or '-'}",
            f"Compte: {row.get('account') or '-'}",
            f"Niveau: {row.get('level') or '-'}",
            f"Dernière connexion: {row.get('last_logout') or row.get('last_update') or '-'}",
            f"Métiers détectés: {profession_count}",
        ]
        if profession_count:
            lines.append(f"Recettes scannées: {scanned_count}/{profession_count}")
        else:
            lines.append("Recettes scannées: aucun métier détecté")

        if professions:
            lines.append("")
            lines.append("Métiers")
            for profession in professions:
                lines.append(f"- {self._render_character_profession(profession)}")

        return "\n".join(lines)

    def _start_analysis(self, state: _TabState) -> None:
        try:
            params = self._collect_params(state)
        except ValueError as exc:
            messagebox.showerror("Paramètres invalides", str(exc), parent=self.root)
            return

        state.run_button.configure(state="disabled")
        state.summary_var.set("Analyse en cours...")
        # Run the analysis off the UI thread so price refreshes do not freeze the window.
        worker = threading.Thread(target=self._run_analysis, args=(state, params), daemon=True)
        worker.start()

    def _collect_params(self, state: _TabState) -> dict[str, Any]:
        region = state.region_var.get().strip().lower() or DEFAULT_REGION
        if region not in {"eu", "us"}:
            raise ValueError("La région doit être EU ou US.")

        try:
            min_sale_rate = float(state.min_sale_rate_var.get().strip() or "0")
        except ValueError as exc:
            raise ValueError("Sell rate min doit être un nombre.") from exc

        params = {
            "region": region,
            "top": int(state.top_var.get()),
            "min_sale_rate": min_sale_rate,
            "sync": bool(state.sync_var.get()),
            "force": bool(state.force_var.get()),
            "retail_root": state.retail_root_var.get().strip() or None,
            "account_root": state.account_root_var.get().strip() or None,
        }
        if state.kind == "discovered" and state.item_ids_var is not None:
            params["item_ids"] = self._parse_item_ids(state.item_ids_var.get())
        return params

    def _run_analysis(self, state: _TabState, params: dict[str, Any]) -> None:
        try:
            report = self._build_report(state, params)
        except Exception as exc:  # pragma: no cover - GUI error path
            details = traceback.format_exc()
            self.root.after(0, lambda error=exc, trace=details: self._handle_error(state, error, trace))
            return
        self.root.after(0, lambda: self._apply_report(state, report))

    def _build_report(self, state: _TabState, params: dict[str, Any]) -> dict[str, Any]:
        if state.kind == "discovered":
            cache = HttpCache(CACHE_DIR)
            return build_discovered_profit_report(
                cache,
                params["region"],
                item_ids=params["item_ids"],
                force=params["force"],
                max_depth=4,
                top=params["top"],
                min_sale_rate=params["min_sale_rate"],
                sync=params["sync"],
                retail_root=params["retail_root"],
                account_root=params["account_root"],
            )

        conn = connect(DB_PATH)
        if params["sync"]:
            cache = HttpCache(CACHE_DIR)
            sync_profession_recipes(conn, cache, default_recipe_professions(), force=params["force"])
        seed_recipe_items(conn)
        if params["sync"]:
            cache = HttpCache(CACHE_DIR)
            sync_recipe_prices(conn, cache, params["region"], force=params["force"])
        return build_recipe_profit_report(
            conn,
            params["region"],
            top=params["top"],
            min_sale_rate=params["min_sale_rate"],
            retail_root=params["retail_root"],
            account_root=params["account_root"],
        )

    def _apply_report(self, state: _TabState, report: dict[str, Any]) -> None:
        state.current_report = report
        state.row_lookup.clear()
        all_rows = report.get("all_rows", [])
        owned_rows = report.get("owned_rows", [])
        if state.kind == "favorites":
            all_rows = [row for row in all_rows if row.get("recipe_favorite")]
            owned_rows = [row for row in owned_rows if row.get("recipe_favorite")]
        self._fill_tree(state, state.global_tree, "global", all_rows)
        self._fill_tree(state, state.owned_tree, "owned", owned_rows)
        self._set_details(state, "")
        if state.kind == "favorites":
            state.summary_var.set(
                "Favoris: "
                f"{len(all_rows)} | "
                "Possédées: "
                f"{len(owned_rows)} | "
                f"Ownership: {report.get('ownership_source', 'unknown')}"
            )
        else:
            state.summary_var.set(
                "Global: "
                f"{len(report.get('all_rows', []))}/{report.get('all_rows_total', 0)} | "
                "Possédées: "
                f"{len(report.get('owned_rows', []))}/{report.get('owned_rows_total', 0)} | "
                f"Ownership: {report.get('ownership_source', 'unknown')}"
            )
        state.run_button.configure(state="normal")

    def _fill_tree(self, state: _TabState, tree: ttk.Treeview, prefix: str, rows: list[dict[str, Any]]) -> None:
        for item in tree.get_children():
            tree.delete(item)
        for index, row in enumerate(rows):
            row_id = f"{prefix}-{index}"
            state.row_lookup[row_id] = row
            recipe_name = row.get("recipe_name") or row.get("best_recipe_name") or "-"
            profession = row.get("profession") or "-"
            item_name = row.get("item_name") or "-"
            if row.get("recipe_favorite"):
                item_name = f"★ {item_name}"
            values = (
                item_name,
                profession,
                recipe_name,
                format_copper(row.get("net_profit_copper")),
                format_number(row.get("balanced_score")),
                format_number(row.get("sale_rate")),
                format_number(row.get("avg_daily_sold")),
                self._ownership_label(row),
            )
            tree.insert("", "end", iid=row_id, values=values)

    def _show_selected_row(self, state: _TabState, tree: ttk.Treeview) -> None:
        selection = tree.selection()
        if not selection:
            return
        row = state.row_lookup.get(selection[0])
        if row is None:
            return
        self._set_details(state, self._render_details(row))

    def _set_details(self, state: _TabState, text: str) -> None:
        state.details_text.configure(state="normal")
        state.details_text.delete("1.0", "end")
        state.details_text.insert("1.0", text)
        state.details_text.configure(state="disabled")

    def _handle_error(self, state: _TabState, error: Exception, details: str) -> None:
        state.run_button.configure(state="normal")
        state.summary_var.set("Erreur")
        self._set_details(state, details)
        messagebox.showerror("Analyse impossible", str(error), parent=self.root)

    def _render_details(self, row: dict[str, Any]) -> str:
        lines = [
            f"Item: {row.get('item_name', '-')}",
            f"Recette: {row.get('recipe_name') or row.get('best_recipe_name') or '-'}",
            f"Spell ID: {row.get('spell_id') or '-'}",
            f"Métier: {row.get('profession') or '-'}",
            f"Possession: {self._ownership_label(row)}",
            f"Favori: {'oui' if row.get('recipe_favorite') else 'non'}",
            f"Prix vente: {format_copper(row.get('sale_price_copper'))}",
            f"Net AH: {format_copper(row.get('sale_net_after_ah_copper'))}",
            f"Coût craft: {format_copper(row.get('craft_cost_copper'))}",
        ]
        multiplier = row.get("craft_output_multiplier") or 1.0
        if multiplier > 1.0:
            branch = row.get("craft_mastery_branch") or "-"
            owner = row.get("craft_mastery_owner")
            bonus_line = f"Bonus maîtrise: x{format_number(multiplier)} ({branch}"
            if owner:
                bonus_line += f", {owner}"
            bonus_line += ")"
            lines.append(bonus_line)
        lines.extend([
            f"Profit: {format_copper(row.get('net_profit_copper'))}",
            f"Marge: {format_number((row.get('margin_ratio') or 0) * 100)}%",
            f"Sell rate: {format_number(row.get('sale_rate'))}",
            f"Ventes/jour: {format_number(row.get('avg_daily_sold'))}",
            f"Score: {format_number(row.get('balanced_score'))}",
        ])
        notes = row.get("recipe_notes") or []
        if notes:
            lines.append("")
            lines.append("Notes:")
            for note in notes:
                lines.append(f"- {note}")

        inputs = row.get("inputs") or []
        if inputs:
            lines.append("")
            lines.append("Inputs:")
            for reagent in inputs:
                line = (
                    f"- {reagent['label']} x{format_number(reagent['quantity'])} "
                    f"= {format_copper(reagent['total_cost_copper'])} via {reagent['source']}"
                )
                if reagent.get("note"):
                    line += f" ({reagent['note']})"
                lines.append(line)
        return "\n".join(lines)

    def _ownership_label(self, row: dict[str, Any]) -> str:
        known_by = row.get("recipe_known_by") or []
        status = row.get("recipe_ownership_status")
        if known_by:
            return "Known: " + ", ".join(known_by)
        if status == "not_known":
            scanned = row.get("profession_scanned_holders") or []
            suffix = f" ({', '.join(scanned)})" if scanned else ""
            return "Absent sur persos scannés" + suffix
        if status == "unscanned":
            holders = row.get("profession_holders") or []
            suffix = f" ({', '.join(holders)})" if holders else ""
            return "Métier vu, recettes non scannées" + suffix
        if status == "no_profession":
            return "Aucun perso avec ce métier"
        return "Inconnu"

    def _toggle_favorite(self, state: _TabState) -> None:
        row = self._selected_row(state)
        if row is None:
            messagebox.showinfo("Favoris", "Sélectionne une recette d'abord.", parent=self.root)
            return
        spell_id = row.get("spell_id")
        if spell_id is None:
            messagebox.showinfo("Favoris", "Cette ligne n'a pas de spell id.", parent=self.root)
            return

        enabled = not bool(row.get("recipe_favorite"))
        conn = connect(DB_PATH)
        set_favorite_spell_id(conn, int(spell_id), enabled)
        conn.close()

        for tab in self._tabs:
            report = tab.current_report
            if report is None:
                continue
            self._set_report_favorite_flag(report, int(spell_id), enabled)
            self._apply_report(tab, report)

    def _selected_row(self, state: _TabState) -> dict[str, Any] | None:
        for tree in (state.global_tree, state.owned_tree):
            selection = tree.selection()
            if not selection:
                continue
            row = state.row_lookup.get(selection[0])
            if row is not None:
                return row
        return None

    def _set_report_favorite_flag(self, report: dict[str, Any], spell_id: int, enabled: bool) -> None:
        for key in ("all_rows", "owned_rows", "rows"):
            rows = report.get(key)
            if not isinstance(rows, list):
                continue
            for row in rows:
                if row.get("spell_id") == spell_id:
                    row["recipe_favorite"] = enabled

    def _parse_item_ids(self, raw: str) -> list[int]:
        item_ids: list[int] = []
        for chunk in re.split(r"[\s,;]+", raw):
            value = chunk.strip()
            if not value:
                continue
            item_ids.append(int(value))
        if not item_ids:
            raise ValueError("Ajoute au moins un item id.")
        return item_ids


def launch_gui() -> int:
    root = tk.Tk()
    _install_single_instance_listener(root)
    ProfitabilityGui(root)
    root.mainloop()
    return 0


def _install_single_instance_listener(root: tk.Tk) -> None:
    def listener() -> None:
        server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        try:
            server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            server.bind((_GUI_SINGLE_INSTANCE_HOST, _GUI_SINGLE_INSTANCE_PORT))
            server.listen(1)
            while True:
                conn, _ = server.accept()
                with conn:
                    try:
                        conn.recv(32)
                    except OSError:
                        pass
                root.after(0, root.destroy)
                break
        except OSError:
            pass
        finally:
            try:
                server.close()
            except OSError:
                pass

    thread = threading.Thread(target=listener, daemon=True)
    thread.start()


def main() -> int:
    return launch_gui()
