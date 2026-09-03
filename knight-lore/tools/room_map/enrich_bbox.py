#!/usr/bin/env python3
"""Enrichit rooms_manifest.json avec les VRAIES bbox_w/h/d des entités de
décor de jonction (murs, portes, blocs...), extraites de la table ROM
statique tbl_room_connection_detail_* (#3E9E-#417E), déjà intégralement
désassemblée et confirmée (docs/SYMBOLS.md #0x3E9E, "RÉSOLU 2026-08-13") :
chunks de 8 octets (type, grid_x, grid_y, grid_z, bbox_w, bbox_h, bbox_d,
flags) concaténés, séparés par un octet sentinelle 0x00 marquant chaque
fin de bloc.

Ne nécessite PAS d'émulateur live : cette zone est statique (des
templates ROM, pas de l'état de partie), vérifiée octet pour octet
identique dans extra/dump_ref.bin.

Correspondance par tuple EXACT (type, grid_x, grid_y, grid_z, flags) --
une entité réelle de salle qui correspond à un template est une copie
octet pour octet de ce template (confirmé empiriquement, voir
docs/SYMBOLS.md #0x3E9E), donc une correspondance exacte garantit la
bonne bbox. Aucune correspondance = aucun champ ajouté (le fallback est
géré côté web/src/physics/obstacles.ts, pas une valeur inventée ici).

Usage:
    enrich_bbox.py [--dump <fichier.bin>] [--manifest <rooms_manifest.json>]
"""
import sys
import os
import json

BBOX_TABLE_START = 0x3E9E
BBOX_TABLE_END = 0x417E


def parse_bbox_table(mem: bytes) -> dict:
    """Retourne {(type, grid_x, grid_y, grid_z, flags): (bbox_w, bbox_h, bbox_d)}."""
    table = {}
    addr = BBOX_TABLE_START
    count = 0
    while addr < BBOX_TABLE_END:
        chunk = mem[addr : addr + 8]
        if len(chunk) < 8:
            break
        entity_type, gx, gy, gz, bbox_w, bbox_h, bbox_d, flags = chunk
        table[(entity_type, gx, gy, gz, flags)] = (bbox_w, bbox_h, bbox_d)
        count += 1
        addr += 8
        if addr < len(mem) and mem[addr] == 0x00:
            addr += 1  # octet sentinelle de fin de bloc, pas un chunk
    print(f"table bbox : {count} entrées parsées ({BBOX_TABLE_START:04X}-{BBOX_TABLE_END:04X})", file=sys.stderr)
    return table


def main():
    args = sys.argv[1:]
    here = os.path.dirname(__file__)
    dump_path = os.path.join(here, "..", "..", "extra", "dump_ref.bin")
    manifest_path = os.path.join(here, "out", "rooms_manifest.json")
    if "--dump" in args:
        i = args.index("--dump")
        dump_path = args[i + 1]
        del args[i : i + 2]
    if "--manifest" in args:
        i = args.index("--manifest")
        manifest_path = args[i + 1]
        del args[i : i + 2]

    with open(dump_path, "rb") as f:
        mem = f.read()
    table = parse_bbox_table(mem)

    with open(manifest_path) as f:
        manifest = json.load(f)

    matched = 0
    total = 0
    for room in manifest.values():
        for entity in room["entities"]:
            total += 1
            key = (
                int(entity["type"], 16),
                int(entity["grid"][0], 16),
                int(entity["grid"][1], 16),
                int(entity["grid"][2], 16),
                int(entity["flags"], 16),
            )
            bbox = table.get(key)
            if bbox is None:
                continue
            entity["bbox_w"] = f"0x{bbox[0]:02x}"
            entity["bbox_h"] = f"0x{bbox[1]:02x}"
            entity["bbox_d"] = f"0x{bbox[2]:02x}"
            matched += 1

    print(f"entités enrichies : {matched}/{total}", file=sys.stderr)

    with open(manifest_path, "w") as f:
        json.dump(manifest, f, indent=2)
        f.write("\n")
    print(f"écrit : {manifest_path}", file=sys.stderr)


if __name__ == "__main__":
    main()
