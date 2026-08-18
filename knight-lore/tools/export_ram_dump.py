#!/usr/bin/env python3
"""Capture ponctuelle du dump RAM statique utilisé par le travail hors-ligne.

À lancer UNE FOIS (ou pour rafraîchir) pendant qu'AMSpiriT-Lite tourne avec
--web-server, quand l'état voulu est atteint (typiquement : juste après
boot, une fois fn_build_pixel_bitscatter_tables passée -- voir #0829 dans
docs/SYMBOLS.md). Le fichier produit (extra/dump_ref.bin par défaut) est
ensuite utilisé automatiquement par tools/disasm.py et tools/gen_asm.py dès
que l'émulateur n'est pas accessible -- pas besoin de le lancer à chaque
session, seulement quand le dump existant est absent ou trop périmé pour
la zone qu'on veut désassembler.

Limite à garder en tête (cf. docs/METHODOLOGY.md section 12) : c'est une
PHOTO figée d'un instant -- valable pour le code et les tables statiques,
invalide pour tout ce qui dépend d'un état runtime (RAM haute mutable,
VRAM, I/O, variables de partie en cours).

Usage:
    export_ram_dump.py [--out CHEMIN] [--addr HEX] [--len N]

Défaut : #0000-#8FFF (36864 octets, la zone code + tables statiques),
cohérent avec le dump actuel du dépôt.
"""
import argparse
import json
import os
import sys
import urllib.request

BASE = "http://127.0.0.1:8765"
DEFAULT_OUT = os.path.join(os.path.dirname(__file__), "..", "extra", "dump_ref.bin")


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--out", default=DEFAULT_OUT)
    ap.add_argument("--addr", default="0000", help="adresse de départ, hex sans préfixe")
    ap.add_argument("--len", type=int, default=0x9000, help="longueur en octets (décimal)")
    args = ap.parse_args()

    addr = int(args.addr, 16)
    url = f"{BASE}/api/ram?addr={addr}&len={args.len}&view=cpu"
    try:
        with urllib.request.urlopen(url, timeout=3) as r:
            data = json.load(r)
    except Exception as e:
        sys.exit(
            f"Impossible de joindre l'émulateur sur {BASE} ({e}).\n"
            "Cet outil a justement besoin de l'émulateur live -- lancez "
            "AMSpiriT-Lite avec --web-server et réessayez."
        )
    raw = bytes.fromhex(data["hex"])
    with open(args.out, "wb") as f:
        f.write(raw)
    print(f"{len(raw)} octets ({args.addr}-{addr+len(raw)-1:04X}) écrits dans {args.out}")


if __name__ == "__main__":
    main()
