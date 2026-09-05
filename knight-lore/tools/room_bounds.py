#!/usr/bin/env python3
"""Extrait la BORNE DE SALLE de chaque salle, depuis un dump memoire.

CE QUE C'EST
------------
`fn_entity_clamp_pending_x/_y` (#258F/#25BA), appelees par la primitive de
deplacement generique `fn_entity_movement_vector_resolve` (#23F7), empechent
TOUTE entite mobile de sortir de la salle. La borne n'est pas un rectangle de
murs : c'est un RAYON autour du centre de salle (0x80), compare ainsi :

    |coord + delta - 0x80| + demi_etendue  <  borne

Les bornes viennent de `tbl_room_master_coords` (#33D4), 3 entrees de 3 octets
(X, Y, Z), choisies par salle. C'est une calibration de RATIO D'ASPECT :

    entree 0 : (40,40,80)  salle carree
    entree 1 : (20,40,80)  salle plus haute que large  (X reduit de moitie)
    entree 2 : (40,20,80)  salle plus large que haute  (Y reduit de moitie)

SELECTION PAR SALLE
-------------------
`tbl_room_master_index` (#33DD), balayee lineairement par `fn_load_room_data`
jusqu'a `tbl_room_connection_ptrs` (#3D5D). Chaque entree :

    +0  room_id
    +1  skip_len   (l'entree suivante est a +1+skip_len)
    +2  field_byte : bits 0-2 = phase scintillement/jingle,
                     bits 3-7 = index dans tbl_room_master_coords

Usage :
    python3 tools/room_bounds.py [dump] [-o sortie.json]
"""

import argparse
import json
import pathlib
import sys

MASTER_COORDS = 0x33D4
MASTER_INDEX = 0x33DD
INDEX_END = 0x3D5D  # tbl_room_connection_ptrs : borne de fin du balayage
COORDS_ENTRIES = 3

REPO_ROOT = pathlib.Path(__file__).resolve().parent.parent
DEFAULT_DUMP = REPO_ROOT / "extra" / "dump_ref.bin"
DEFAULT_OUT = REPO_ROOT / "web" / "src" / "data" / "assets" / "room_bounds.json"


def extract(data: bytes) -> tuple[list[list[int]], dict[int, int]]:
    if len(data) < INDEX_END:
        sys.exit(f"dump trop court : {len(data):#x}, il en faut {INDEX_END:#x}")

    coords = [
        list(data[MASTER_COORDS + 3 * i : MASTER_COORDS + 3 * i + 3])
        for i in range(COORDS_ENTRIES)
    ]

    rooms: dict[int, int] = {}
    h = MASTER_INDEX
    while h < INDEX_END:
        room_id, skip_len, field_byte = data[h], data[h + 1], data[h + 2]
        idx = field_byte >> 3
        if idx >= COORDS_ENTRIES:
            sys.exit(f"salle {room_id:#04x} : index de coords hors table ({idx})")
        rooms[room_id] = idx
        h += 1 + skip_len
    return coords, rooms


def main() -> None:
    ap = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    ap.add_argument("dump", nargs="?", default=str(DEFAULT_DUMP))
    ap.add_argument("-o", "--out", default=str(DEFAULT_OUT))
    args = ap.parse_args()

    coords, rooms = extract(pathlib.Path(args.dump).read_bytes())

    payload = {
        "source": pathlib.Path(args.dump).name,
        "center": 0x80,
        "note": (
            "Borne = RAYON autour du centre 0x80, pas un rectangle de murs. "
            "Test de fn_entity_clamp_pending_x/_y : "
            "|coord + delta - 0x80| + demi_etendue < borne."
        ),
        # Les 3 calibrations, exportees telles quelles : c'est la donnee, et
        # chaque salle y renvoie par un index.
        "bounds": [{"x": c[0], "y": c[1], "z": c[2]} for c in coords],
        "by_room": {f"0x{r:02x}": idx for r, idx in sorted(rooms.items())},
    }

    out = pathlib.Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")

    counts: dict[int, int] = {}
    for idx in rooms.values():
        counts[idx] = counts.get(idx, 0) + 1
    print(f"{len(rooms)} salles -> {out}")
    for i, c in enumerate(coords):
        print(f"  index {i} ({c[0]:#04x},{c[1]:#04x},{c[2]:#04x}) : {counts.get(i, 0)} salles")


if __name__ == "__main__":
    main()
