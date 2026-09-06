#!/usr/bin/env python3
"""Montre quels itemStrings TSM se regroupent sous la meme cle de stats.

Le posting a l'HV identifie un objet par « meme niveau d'objet, memes stats »
(ItemString.ToStatKey, ajoute par TSMAutoPatch.Common.ps1). Deux itemStrings
peuvent differer sans que l'objet ne vaille autre chose : LibBonusId classe les
bonusIds en deux familles, ceux qui portent un effet mecanique (data.bonuses :
op scale/add/set) et ceux qui n'ajoutent qu'une ligne d'infobulle
(data.tooltipBonuses). BonusIds.Filter garde les deux, donc l'itemString conserve
des bonusIds purement cosmetiques.

Cet outil decode les donnees de LibBonusId livrees avec le TSM installe, lit les
itemStrings observes dans les SavedVariables de TSM, et affiche pour un item les
groupes que la cle de stats fera fusionner.

Usage :
    python scripts/tsm/inspect_stat_key_grouping.py 245778
    python scripts/tsm/inspect_stat_key_grouping.py --top 15

Le regroupement affiché est une approximation lisible : TSM compare le niveau
d'objet calcule, pas l'ensemble des bonusIds mecaniques. Deux jeux de bonusIds
mecaniques differents mais de meme niveau fusionneraient aussi.
"""
from __future__ import annotations

import argparse
import base64
import collections
import re
import struct
import sys
import zlib
from pathlib import Path

RETAIL_CANDIDATES = (
    r"C:\Program Files (x86)\World of Warcraft\_retail_",
    r"C:\Program Files\World of Warcraft\_retail_",
    r"D:\World of Warcraft\_retail_",
    r"E:\World of Warcraft\_retail_",
)

# Types de modificateurs que TSM conserve dans l'itemString comme etant des stats
# (LibTSMTypes\Source\Item\ItemString.lua, EXTRA_STAT_MODIFIER_TYPES).
STAT_MODIFIER_TYPES = {29, 30}
# BonusIds.GetCraftingStatModifier : bonusIds equivalents a un modificateur de stat.
BONUS_ID_TO_STAT_MODIFIER = {6647: 32, 6649: 36, 6650: 40, 6648: 49}


def find_retail_root() -> Path:
    for candidate in RETAIL_CANDIDATES:
        path = Path(candidate)
        if (path / "Interface" / "AddOns" / "TradeSkillMaster").is_dir():
            return path
    raise SystemExit("Installation Retail avec TradeSkillMaster introuvable.")


def cbor_load(buf: bytes, pos: int = 0):
    head = buf[pos]
    pos += 1
    major, info = head >> 5, head & 0x1F

    if info < 24:
        value = info
    elif info == 24:
        value, pos = buf[pos], pos + 1
    elif info in (25, 26, 27):
        width = {25: 2, 26: 4, 27: 8}[info]
        value, pos = int.from_bytes(buf[pos:pos + width], "big"), pos + width
    else:
        raise ValueError(f"info CBOR non geree: {info}")

    if major == 0:
        return value, pos
    if major == 1:
        return -1 - value, pos
    if major in (2, 3):
        raw, pos = buf[pos:pos + value], pos + value
        return (raw.decode("utf-8") if major == 3 else raw), pos
    if major == 4:
        out = []
        for _ in range(value):
            item, pos = cbor_load(buf, pos)
            out.append(item)
        return out, pos
    if major == 5:
        out = {}
        for _ in range(value):
            key, pos = cbor_load(buf, pos)
            val, pos = cbor_load(buf, pos)
            out[key] = val
        return out, pos
    if major == 7:
        if info in (20, 21):
            return info == 21, pos
        if info == 22:
            return None, pos
        fmt = {25: ">e", 26: ">f", 27: ">d"}.get(info)
        if fmt:
            width = struct.calcsize(fmt)
            return struct.unpack(fmt, buf[pos - width:pos])[0], pos
    raise ValueError(f"type CBOR non gere: major={major} info={info}")


def load_bonus_data(retail_root: Path) -> dict:
    data_lua = (
        retail_root / "Interface" / "AddOns" / "TradeSkillMaster"
        / "External" / "LibBonusId" / "Data.lua"
    )
    match = re.search(r'local DATA = "(.*?)"\n', data_lua.read_text(encoding="utf-8"), re.S)
    if not match:
        raise SystemExit(f"Blob de donnees introuvable dans {data_lua}")
    payload = zlib.decompress(base64.b64decode(match.group(1)), -15)
    return cbor_load(payload)[0]


def as_int_keyed(table) -> dict:
    """Les cles du blob CBOR peuvent arriver en nombre ou en chaine."""
    if not isinstance(table, dict):
        return {}
    return {int(key): value for key, value in table.items()}


def iter_saved_item_strings(retail_root: Path):
    account_root = retail_root / "WTF" / "Account"
    if not account_root.is_dir():
        return
    pattern = re.compile(r"i:\d+::?[0-9:]+")
    for saved in account_root.glob("*/SavedVariables/TradeSkillMaster.lua"):
        for found in pattern.findall(saved.read_text(encoding="utf-8", errors="ignore")):
            yield found


def parse_item_string(item_string: str):
    """Rend (itemId, bonusIds, modifiers) au format itemString de TSM.

    Format : i:<id>:<rand>:<nbBonus>:<bonus...>:<nbModifs>:<type>:<valeur>...
    """
    parts = item_string.split(":")
    if len(parts) < 2 or parts[0] != "i":
        return None, [], []
    item_id = int(parts[1])
    rest = parts[3:]
    if not rest or not rest[0].isdigit():
        return item_id, [], []
    num_bonus = int(rest[0])
    bonus_ids = [int(value) for value in rest[1:1 + num_bonus] if value.isdigit()]
    tail = rest[1 + num_bonus:]
    modifiers = []
    if tail and tail[0].isdigit():
        num_mod = int(tail[0])
        values = [int(value) for value in tail[1:1 + num_mod * 2] if value.isdigit()]
        modifiers = list(zip(values[0::2], values[1::2]))
    return item_id, bonus_ids, modifiers


def stat_modifiers(bonus_ids, modifiers) -> tuple:
    stats = [BONUS_ID_TO_STAT_MODIFIER[bid] for bid in bonus_ids if bid in BONUS_ID_TO_STAT_MODIFIER]
    stats += [value for mod_type, value in modifiers if mod_type in STAT_MODIFIER_TYPES]
    return tuple(sorted(stats))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("item_id", nargs="?", type=int, help="itemId a inspecter")
    parser.add_argument("--top", type=int, default=0, help="lister les N items ayant le plus de variantes")
    args = parser.parse_args()

    # La console Windows est en cp1252 par defaut : sans ca, les guillemets
    # francais sortent en mojibake.
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    except (AttributeError, ValueError):
        pass

    retail_root = find_retail_root()
    data = load_bonus_data(retail_root)
    mechanical = set(as_int_keyed(data.get("bonuses")))
    tooltip_only = set(as_int_keyed(data.get("tooltipBonuses"))) - mechanical
    print(f"LibBonusId build {data.get('build')} : "
          f"{len(mechanical)} bonusIds mecaniques, {len(tooltip_only)} purement d'infobulle")

    by_item = collections.defaultdict(set)
    for item_string in iter_saved_item_strings(retail_root):
        item_id, bonus_ids, _ = parse_item_string(item_string)
        if item_id and bonus_ids:
            by_item[item_id].add(item_string)

    if args.top:
        print("\nItems avec le plus de variantes observees :")
        for item_id, strings in sorted(by_item.items(), key=lambda kv: -len(kv[1]))[:args.top]:
            print(f"  {item_id:>7}  {len(strings)} variantes")
        return 0

    if not args.item_id:
        parser.error("donner un itemId, ou --top N")

    variants = sorted(by_item.get(args.item_id, ()))
    if not variants:
        print(f"\nAucune variante observee pour {args.item_id}.")
        return 1

    groups = collections.defaultdict(list)
    for item_string in variants:
        _, bonus_ids, modifiers = parse_item_string(item_string)
        key = (tuple(sorted(bid for bid in bonus_ids if bid in mechanical)),
               stat_modifiers(bonus_ids, modifiers))
        groups[key].append(item_string)

    print(f"\n{args.item_id} : {len(variants)} itemStrings observes, "
          f"{len(groups)} groupes « meme niveau d'objet, memes stats »\n")
    for (mech, stats), strings in sorted(groups.items()):
        detail = ", ".join(
            f"{bid}({data['bonuses'].get(bid, data['bonuses'].get(str(bid), {})).get('op', '?')}"
            f"{'+' + str(data['bonuses'].get(bid, data['bonuses'].get(str(bid), {})).get('amount')) if data['bonuses'].get(bid, data['bonuses'].get(str(bid), {})).get('amount') else ''})"
            for bid in mech
        ) or "aucun"
        print(f"  bonus mecaniques : {detail}")
        print(f"  stats            : {', '.join(map(str, stats)) or 'aucune'}")
        for item_string in strings:
            _, bonus_ids, _ = parse_item_string(item_string)
            dropped = [bid for bid in bonus_ids if bid not in mech]
            note = f"   (ignores : {', '.join(map(str, dropped))})" if dropped else ""
            print(f"    {item_string}{note}")
        print()
    return 0


if __name__ == "__main__":
    sys.exit(main())
