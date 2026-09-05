#!/usr/bin/env python3
"""Extrait tbl_object_catalog (#417E..#429E) depuis un dump memoire.

CE QUE CETTE TABLE EST, ET CE QU'ELLE N'EST PAS
-----------------------------------------------
32 entrees de 9 octets, les 32 emplacements d'objets a ramasser du jeu.
Layout confirme (notes/2026-08-07-object-catalog-randomizer.md, recoupe avec
une RAM live) :

    +0        type            REECRIT A CHAQUE PARTIE (0x60-0x67)
    +1..+4    x, y, z, salle  TEMPLATE FIXE, jamais randomise
    +5..+8    x, y, z, salle  copie de travail, reecrite depuis +1..+4

Seuls +1..+4 sont des donnees. Le type et la copie de travail sont GENERES au
lancement par fn_catalog_randomize_types (#1D27) : cet outil ne les exporte
donc pas, et c'est deliberer -- exporter un type serait exporter le resultat
d'une partie particuliere, pas un fait du jeu (cf. docs/METHODOLOGY.md §24 :
un outil exporte des faits observes, jamais une politique).

Le dump de reference est d'ailleurs pris AVANT randomisation : ses octets +0
et +5..+8 valent tous zero, ce qui confirme le decoupage plutot que de le
contredire.

Usage :
    python3 tools/object_catalog.py [dump] [-o sortie.json]
"""

import argparse
import json
import pathlib
import sys

CATALOG_BASE = 0x417E
CATALOG_END = 0x429E
ENTRY_SIZE = 9
ENTRY_COUNT = (CATALOG_END - CATALOG_BASE) // ENTRY_SIZE  # 32

REPO_ROOT = pathlib.Path(__file__).resolve().parent.parent
DEFAULT_DUMP = REPO_ROOT / "extra" / "dump_ref.bin"
DEFAULT_OUT = REPO_ROOT / "web" / "src" / "data" / "assets" / "object_catalog.json"


def extract(data: bytes) -> list[dict]:
    if len(data) < CATALOG_END:
        sys.exit(
            f"dump trop court : {len(data):#x} octets, il en faut au moins {CATALOG_END:#x}"
        )

    entries = []
    for i in range(ENTRY_COUNT):
        off = CATALOG_BASE + i * ENTRY_SIZE
        raw = data[off : off + ENTRY_SIZE]
        entries.append(
            {
                "index": i,
                "addr": f"{off:04X}",
                # Seuls les 4 octets de template. Voir le docstring : le reste
                # est genere par la partie en cours.
                "grid_x": raw[1],
                "grid_y": raw[2],
                "grid_z": raw[3],
                "room": raw[4],
            }
        )
    return entries


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("dump", nargs="?", default=str(DEFAULT_DUMP))
    ap.add_argument("-o", "--out", default=str(DEFAULT_OUT))
    args = ap.parse_args()

    data = pathlib.Path(args.dump).read_bytes()
    entries = extract(data)

    payload = {
        "source": pathlib.Path(args.dump).name,
        "base": f"{CATALOG_BASE:04X}",
        "entry_size": ENTRY_SIZE,
        "count": len(entries),
        "note": (
            "Emplacements FIXES des objets a ramasser. Le TYPE (0x60-0x67) "
            "n'est pas ici : il est tire au lancement de chaque partie par "
            "fn_catalog_randomize_types (#1D27)."
        ),
        "entries": entries,
    }

    out = pathlib.Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")

    rooms = sorted({e["room"] for e in entries})
    print(f"{len(entries)} emplacements -> {out}")
    print(f"{len(rooms)} salles distinctes concernees")


if __name__ == "__main__":
    main()
