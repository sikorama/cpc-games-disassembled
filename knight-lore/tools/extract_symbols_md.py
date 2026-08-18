#!/usr/bin/env python3
"""Extrait les lignes de tableau de docs/SYMBOLS.md (Addr | Name | Statut |
Description) indexees par adresse 4-hex majuscule, pour reutilisation par
migrate_symbols.py comme source privilegiee (plus riche/plus a jour que
asm/symbols.json pour les symboles qui existent dans les deux)."""
import re

ROW = re.compile(r"^\|\s*(0x[0-9A-Fa-f]{4}(?:\s*,\s*0x[0-9A-Fa-f]{4})*)\s*\|([^|]*)\|([^|]*)\|(.*)\|\s*$")


def extract(path="docs/SYMBOLS.md"):
    out = {}
    with open(path) as f:
        for line in f:
            m = ROW.match(line.rstrip("\n"))
            if not m:
                continue
            addrs_raw, name, status, desc = m.groups()
            addrs = [x.strip()[2:].upper().zfill(4) for x in addrs_raw.split(",")]
            for addr in addrs:
                out[addr] = desc.strip()
    return out


if __name__ == "__main__":
    d = extract()
    print(len(d), "adresses extraites")
    for addr in list(d)[:3]:
        print(addr, "->", d[addr][:150])
