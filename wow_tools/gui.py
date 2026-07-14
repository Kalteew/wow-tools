from __future__ import annotations

import threading
import traceback
from dataclasses import dataclass
import re
import socket
from typing import Any

import tkinter as tk
from tkinter import messagebox, ttk

from wow_tools.cache import HttpCache
from wow_tools.config import CACHE_DIR, DB_PATH, DEFAULT_REGION
from wow_tools.db import connect
from wow_tools.dynamic_recipe_profit import build_discovered_profit_report
from wow_tools.logging_lumber import build_logging_lumber_report
from wow_tools.profession_recipes import default_professions as default_recipe_professions, sync_profession_recipes
from wow_tools.recipe_catalog import default_favorite_spell_ids
from wow_tools.recipe_favorites import ensure_favorite_spell_ids, set_favorite_spell_id
from wow_tools.recipe_profit import build_recipe_profit_report, seed_recipe_items, sync_recipe_prices
from wow_tools.local_account import load_character_profession_scans, load_yaya_profession_specializations
from wow_tools.reports import format_copper, format_number

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


class ProfitabilityGui:
    def __init__(self, root: tk.Tk):
        self.root = root
        self.root.title("WoW Tools - Recipe Profitability")
        self.root.geometry("1400x900")
        self.root.minsize(1100, 760)
        self._setup_style()
        self._tabs: list[_TabState] = []

        conn = connect(DB_PATH)
        ensure_favorite_spell_ids(conn, default_favorite_spell_ids())
        conn.close()

        container = ttk.Frame(root, padding=12)
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

    def _setup_style(self) -> None:
        style = ttk.Style(self.root)
        for theme in ("vista", "clam", "default"):
            if theme in style.theme_names():
                style.theme_use(theme)
                break
        style.configure("Header.TLabel", font=("Segoe UI", 12, "bold"))
        style.configure("Summary.TLabel", font=("Segoe UI", 10))
        style.configure("SpecHero.TLabel", font=("Segoe UI", 14, "bold"))
        style.configure("SpecSubhero.TLabel", font=("Segoe UI", 10))
        style.configure("SpecKey.TLabel", font=("Segoe UI", 9, "bold"))
        style.configure("SpecValue.TLabel", font=("Segoe UI", 10))

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

        columns = ("expansion", "wood", "value", "profit", "sale_rate", "products", "marketed", "wood_price")
        tree = ttk.Treeview(tree_frame, columns=columns, show="headings", height=12)
        tree.grid(row=0, column=0, sticky="nsew")

        headings = {
            "expansion": ("Extension", 120),
            "wood": ("Bois", 200),
            "value": ("Valeur/bois", 100),
            "profit": ("Profit moy", 100),
            "sale_rate": ("SR moy", 80),
            "products": ("Produits", 70),
            "marketed": ("Pricés", 70),
            "wood_price": ("Prix bois", 100),
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
        worker = threading.Thread(target=self._run_lumber_refresh, args=(state,), daemon=True)
        worker.start()

    def _run_lumber_refresh(self, state: _LumberTabState) -> None:
        try:
            region = state.region_var.get().strip().lower() or DEFAULT_REGION
            conn = connect(DB_PATH)
            if state.sync_var.get():
                cache = HttpCache(CACHE_DIR)
                sync_recipe_prices(conn, cache, region, force=bool(state.force_var.get()))
            conn.close()
            report = build_logging_lumber_report(region)
        except Exception as exc:  # pragma: no cover - GUI error path
            details = traceback.format_exc()
            self.root.after(0, lambda: self._handle_lumber_error(state, exc, details))
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
        summary = f"{len(rows)} bois | région {region} | valeur = profit craft moyen avec malus sell rate"
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
            f"Prix bois: {format_copper(row.get('wood_price_copper'))}",
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
                f"- {product.get('item_name') or product['item_id']}: "
                f"profit {format_copper(product.get('craft_profit_copper'))} | "
                f"sr {format_number(product.get('sell_rate'))} | "
                f"qte bois {format_number(product.get('wood_quantity'))} | "
                f"val/bois {format_copper(int(round(product.get('adjusted_profit_per_wood') or 0)))}"
            )
        if not row.get("top_products"):
            lines.append("- aucun produit pricé localement")
        return "\n".join(lines)

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
            self.root.after(0, lambda: self._handle_error(state, exc, details))
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
