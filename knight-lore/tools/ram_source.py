#!/usr/bin/env python3
"""Source unique de RAM pour les outils de désassemblage (disasm.py, gen_asm.py).

Ordre de résolution (transparent, pas de flag à passer) :
1. Émulateur AMSpiriT-Lite live (127.0.0.1:8765) si accessible -- source la
   plus fraîche, seule valable pour tout ce qui dépend d'un état runtime
   (RAM haute mutable, VRAM, I/O).
2. Sinon, `extra/dump_ref.bin` (dump statique du dépôt, capturé une fois
   après boot) -- suffisant pour tout le code et les tables statiques en
   #0000-#8FFF, cf. docs/METHODOLOGY.md section 12. Un message est émis sur
   stderr pour que l'utilisateur sache quelle source a réellement servi.
3. Si ni l'un ni l'autre : erreur explicite expliquant comment régénérer le
   dump (`tools/export_ram_dump.py`, émulateur requis pour cette étape
   unique).

Aucune instruction n'est jamais fabriquée dans les deux cas : les octets
viennent toujours d'une lecture RAM réelle (live ou capturée).
"""
import os
import sys
import json
import urllib.request

DUMP_PATH = os.path.join(os.path.dirname(__file__), "..", "extra", "dump_ref.bin")
BASE = "http://127.0.0.1:8765"


def fetch_ram(addr=0, length=65536, view="cpu", timeout=1.0):
    try:
        url = f"{BASE}/api/ram?addr={addr}&len={length}&view={view}"
        with urllib.request.urlopen(url, timeout=timeout) as r:
            data = json.load(r)
        raw = bytes.fromhex(data["hex"])
        buf = bytearray(65536)
        for i, b in enumerate(raw):
            buf[(addr + i) & 0xFFFF] = b
        return buf
    except Exception:
        pass

    if not os.path.exists(DUMP_PATH):
        sys.exit(
            "Erreur : émulateur non accessible sur 127.0.0.1:8765 ET "
            f"{os.path.relpath(DUMP_PATH)} absent.\n"
            "Générez le dump une fois (émulateur requis pour cette étape "
            "unique) via :\n"
            "    tools/export_ram_dump.py\n"
            "puis relancez cette commande -- elle fonctionnera hors-ligne "
            "ensuite."
        )
    print(
        f"[offline] émulateur non accessible -- utilisation de "
        f"{os.path.relpath(DUMP_PATH)}",
        file=sys.stderr,
    )
    with open(DUMP_PATH, "rb") as f:
        raw = f.read()
    buf = bytearray(65536)
    buf[: len(raw)] = raw
    return buf
