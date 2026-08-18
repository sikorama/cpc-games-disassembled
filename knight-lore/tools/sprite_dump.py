#!/usr/bin/env python3
"""Extracteur de sprites Knight Lore -> images bitmap (PNG), pour
validation visuelle du format struct_sprite_shape (voir docs/SYMBOLS.md
#2F02, #31E9, #2F8D -- format REEL confirme le 2026-08-10 (corrige
plusieurs fois le meme jour, voir shape_to_image() plus bas) : 2
bits/pixel, 4 pixels/octet, row_bytes=V directement, en-tete 3 octets.
L'hypothese initiale "monochrome 1 bit/pixel, 8 pixels/octet" citee
ici etait FAUSSE (rendu bruite) -- cette ligne n'a jamais ete mise a
jour apres coup, ne pas s'y fier).

Ne decode QUE ce que le format documente permet de savoir avec
certitude : chaque struct_sprite_shape connait sa propre taille exacte
(largeur+hauteur dans son en-tete), donc l'extraction par pointeur est
fiable meme si l'extent globale du blob resources (#4422+) ne l'est
pas -- pas besoin de "deviner" ou une forme s'arrete par rapport a la
suivante, seulement lire ce que son propre en-tete annonce.

Usage:
    sprite_dump.py [--dump <fichier.bin 64K>] [--out <dossier>]

Sans --dump, lit la RAM live de l'emulateur (127.0.0.1:8765/api/ram,
meme API que tools/disasm.py) -- necessite AMSpiriT-Lite lance avec
--web-server et une partie Knight Lore chargee (voir asm/README.md pour
la methode headless : SDL_VIDEODRIVER=offscreen LIBGL_ALWAYS_SOFTWARE=1).
Avec --dump, relit un dump RAM 64 Ko sauvegarde au prealable (voir
--save-dump) -- permet de rejouer l'extraction sans emulateur.

Sortie (--out, defaut tools/sprite_dump_out/) :
    sprite_XXXXXX-w-h.png   -- un fichier par forme UNIQUE (dedupliquee
                                par pointeur), nomme par son adresse
    contact_sheet.png       -- planche de contact avec toutes les formes
    manifest.json           -- {pointeur: {types: [...], w, h, flags}}
"""
import sys
import os
import json
import urllib.request

SYMBOLS_PATH = os.path.join(os.path.dirname(__file__), "..", "asm", "symbols.json")
BASE = "http://127.0.0.1:8765"

# Borne de sanite DURE confirmee (2026-08-10) : la table d'entrees
# deroulees de fn_blit_masked fait exactement 16*10 octets, donc
# col_bytes=V n'a de sens que pour V=1..16 -- au-dela, le pointeur ne
# designe pas un struct_sprite_shape valide.
MAX_ROW_BYTES = 16


def fetch_ram_live(addr=0, length=65536, view="cpu"):
    url = f"{BASE}/api/ram?addr={addr}&len={length}&view={view}"
    with urllib.request.urlopen(url) as r:
        data = json.load(r)
    raw = bytes.fromhex(data["hex"])
    buf = bytearray(65536)
    for i, b in enumerate(raw):
        buf[(addr + i) & 0xFFFF] = b
    return buf


def load_symtab():
    with open(SYMBOLS_PATH) as f:
        return json.load(f)


def find_symbol(symtab, addr_hex):
    for s in symtab["symbols"]:
        if s["addr"].upper() == addr_hex.upper():
            return s
    raise KeyError(f"symbole introuvable pour #{addr_hex} dans symbols.json")


def decode_dispatch_table(mem, base, count):
    """Retourne la liste des `count` pointeurs (word) a partir de `base`."""
    ptrs = []
    for i in range(count):
        addr = base + i * 2
        ptrs.append(mem[addr] | (mem[addr + 1] << 8))
    return ptrs


def decode_shape(mem, addr):
    """Decode un struct_sprite_shape a `addr`. Retourne None si sentinelle
    (#00) ou si les valeurs sortent des bornes de sanite (pointeur pas un
    shape valide).

    row_bytes = V (bits0-5 de l'octet 0) -- CONFIRME 2026-08-10 en tracant
    en direct un vrai blit (breakpoint + single-step sur #30BB, variante
    "alignee") : la table d'entrees deroulees de fn_blit_masked fait
    EXACTEMENT 160 octets (#30E3-#3182 = 16*10), et l'entree choisie =
    base + ((-V)&0x0F)*10 -- ce qui, algebriquement pour V=1..16, fait
    executer exactement V unites de 10 octets avant la fin de la table.

    EN-TETE DE 3 OCTETS, PAS 2 -- CORRIGE 2026-08-10 (retour utilisateur :
    decalage constant de 4px/1 octet observe sur les sprites exportes,
    confirme en re-tracant la meme sequence live) : `#2F82` ("INC DE")
    consomme un 3e octet (offset+2) juste avant d'entrer dans la boucle de
    colonnes, immediatement apres avoir lu largeur (offset+0) ET hauteur
    (offset+1, lue en `#2F62`-`#2F64`). Ce 3e octet n'est PAS un plan de
    pixels -- il sert uniquement de test ("peek" en `#30D5`-`#30D9`, qui
    ajuste de -2 un decalage stocke dans AF' si non-nul) puis est saute
    sans etre stocke. Le payload reel commence donc a `addr+3`, pas
    `addr+2` -- l'ancien decalage expliquait le "sprite commence 4 pixels
    plus tot" observe visuellement (le rendu incluait a tort cet octet de
    test comme premiere colonne de pixels)."""
    b0 = mem[addr]
    if b0 == 0x00:
        return None
    row_bytes = b0 & 0x3F
    vflip = bool(b0 & 0x40)
    hflip = bool(b0 & 0x80)
    height = mem[addr + 1]
    if row_bytes == 0 or height == 0 or row_bytes > MAX_ROW_BYTES:
        return None
    rows = []
    pos = addr + 3
    for _ in range(height):
        rows.append(bytes(mem[pos + i] for i in range(row_bytes)))
        pos += row_bytes
    return {
        "addr": addr,
        "width": row_bytes * 4,
        "height": height,
        "row_bytes": row_bytes,
        "vflip": vflip,
        "hflip": hflip,
        "rows": rows,
        "size": 3 + row_bytes * height,
    }


def shape_to_image(shape, scale=6, aspect_2x=True):
    """Rend le bitmap en niveaux de gris.

    Pixel encoding CONFIRME 2026-08-10 : ce n'est PAS 1 bit = 1 pixel
    sequentiel (8 pixels/octet) comme l'hypothese initiale le supposait --
    verifie FAUX empiriquement (image bruitee, non reconnaissable). Le
    VRAI decodage, retrouve en lisant directement le contenu des tables
    masque/couleur #8200/#8300 (paire "alignee", shift=0) construites par
    fn_build_pixel_bitscatter_tables (#0829) : chaque octet source encode
    4 pixels (pas 8), pixel N utilisant la paire de bits (bit(7-N),
    bit(3-N)) -- EXACTEMENT l'agencement natif de l'ecran CPC Mode 1 (2
    bits/pixel, memes positions scramblees).

    Construction du bitmap (row_bytes=V lignes de header['height'] octets,
    voir decode_shape) au format NATUREL de la boucle de blit confirmee
    par trace live (#30E3-#3182, #2F86/#30B6) : la boucle interne (V
    unites) avance horizontalement (BC++, un octet ecran = 4 pixels), la
    boucle externe (height iterations, +#38/ligne) avance verticalement
    -- donc row_bytes*4 = largeur, height = hauteur, SANS transposition.

    Rotation de 90 degres (ROTATE_90, sens antihoraire) APPLIQUEE ICI,
    PAS DANS LE DECODAGE. Cause EXACTE toujours pas tracee (aucune
    transposition trouvee dans le blit ni dans
    fn_buffer_addr_from_vram/fn_blit_copy_line -- trace live directe le
    2026-08-13, BC avance de +64/ligne = la stride normale du buffer, DE
    de +V/ligne, adressage ligne-majeure standard de bout en bout, voir
    notes/2026-08-13-sprite-rotation-investigation.md) -- mais la
    NECESSITE et le SENS de cette rotation restent CONFIRMES le
    2026-08-13 : tentative d'inverser le sens (ROTATE_270) testee et
    REJETEE -- comparee au hash MD5 du rendu historique du rubis
    (#4687, reconnaissable comme diamant/gemme depuis 2026-08-10) ET a
    une vraie capture d'ecran de la bouteille (salle #00 slot 2,
    (ix+16)/(ix+17) verifies non-nuls avant capture), c'est bien
    ROTATE_90 (inchange) qui reproduit le rendu correct -- une
    comparaison visuelle ad-hoc plus tot dans la meme session avait
    semble suggerer l'inverse, mais s'est reveleee etre une erreur du
    script de test ponctuel, pas du code ici. Ne pas retenter ce
    changement sans repartir de ce constat."""
    from PIL import Image

    row_bytes = shape["row_bytes"]
    w = row_bytes * 4
    h = shape["height"]
    img = Image.new("L", (w, h))
    px = img.load()
    for y, row in enumerate(shape["rows"]):
        for bi, byte in enumerate(row):
            for n in range(4):
                hi = (byte >> (7 - n)) & 1
                lo = (byte >> (3 - n)) & 1
                val = hi * 2 + lo  # 0..3
                px[bi * 4 + n, y] = 255 - val * 85
    sx = scale * (2 if aspect_2x else 1)
    img = img.resize((w * sx, h * scale), Image.NEAREST)
    return img.transpose(Image.ROTATE_90)


def build_contact_sheet(images_and_labels, cell_pad=4):
    from PIL import Image, ImageDraw, ImageFont

    font = ImageFont.load_default()
    label_h = 12
    cell_w = max(img.width for img, _ in images_and_labels) + cell_pad * 2
    cell_h = max(img.height for img, _ in images_and_labels) + cell_pad * 2 + label_h
    cols = max(1, int(len(images_and_labels) ** 0.5 * 1.4))
    rows = (len(images_and_labels) + cols - 1) // cols

    sheet = Image.new("L", (cols * cell_w, rows * cell_h), color=200)
    draw = ImageDraw.Draw(sheet)
    for idx, (img, label) in enumerate(images_and_labels):
        col, row = idx % cols, idx // cols
        ox, oy = col * cell_w, row * cell_h
        draw.rectangle([ox, oy, ox + cell_w - 1, oy + cell_h - 1], outline=0)
        sheet.paste(img, (ox + cell_pad, oy + cell_pad))
        draw.text((ox + cell_pad, oy + cell_h - label_h), label, fill=0, font=font)
    return sheet


def main():
    args = sys.argv[1:]
    dump_path = None
    out_dir = os.path.join(os.path.dirname(__file__), "sprite_dump_out")
    if "--dump" in args:
        i = args.index("--dump")
        dump_path = args[i + 1]
        del args[i : i + 2]
    if "--out" in args:
        i = args.index("--out")
        out_dir = args[i + 1]
        del args[i : i + 2]

    os.makedirs(out_dir, exist_ok=True)

    if dump_path:
        with open(dump_path, "rb") as f:
            mem = bytearray(f.read())
        if len(mem) != 65536:
            print(f"attention : dump de {len(mem)} octets, 65536 attendus", file=sys.stderr)
    else:
        mem = fetch_ram_live()

    symtab = load_symtab()
    sym = find_symbol(symtab, "429E")
    base = int(sym["addr"], 16)
    count = sym["count"]  # 194, confirme 2026-08-10 -- voir docs/SYMBOLS.md #429E
    ptrs = decode_dispatch_table(mem, base, count)

    # dedup par pointeur : beaucoup de types partagent le meme shape
    by_ptr = {}
    for t, p in enumerate(ptrs):
        by_ptr.setdefault(p, []).append(t)

    manifest = {}
    images_and_labels = []
    skipped = []
    for ptr, types in sorted(by_ptr.items()):
        shape = decode_shape(mem, ptr)
        if shape is None:
            skipped.append((ptr, types))
            continue
        img = shape_to_image(shape)
        fname = f"sprite_{ptr:04X}_w{shape['width']}_h{shape['height']}.png"
        img.save(os.path.join(out_dir, fname))
        manifest[f"{ptr:04X}"] = {
            "types": [f"{t:02X}" for t in types],
            "width": shape["width"],
            "height": shape["height"],
            "vflip_state": shape["vflip"],
            "hflip_state": shape["hflip"],
            "size_bytes": shape["size"],
            "file": fname,
        }
        label = f"#{ptr:04X} t={','.join(f'{t:02X}' for t in types[:3])}{'..' if len(types) > 3 else ''}"
        images_and_labels.append((img, label))

    with open(os.path.join(out_dir, "manifest.json"), "w") as f:
        json.dump(
            {
                "tbl_sprite_dispatch_base": f"{base:04X}",
                "count": count,
                "unique_pointers": len(by_ptr),
                "decoded": len(manifest),
                "skipped_sentinel_or_invalid": [
                    {"ptr": f"{p:04X}", "types": [f"{t:02X}" for t in ts]} for p, ts in skipped
                ],
                "shapes": manifest,
            },
            f,
            indent=2,
        )

    if images_and_labels:
        sheet = build_contact_sheet(images_and_labels)
        sheet.save(os.path.join(out_dir, "contact_sheet.png"))

    print(f"{count} entrees de tbl_sprite_dispatch -> {len(by_ptr)} pointeurs uniques")
    print(f"{len(manifest)} formes decodees, {len(skipped)} ignorees (sentinelle #00 ou hors bornes)")
    print(f"sortie : {out_dir}/ (contact_sheet.png, manifest.json, {len(manifest)} PNG individuels)")


if __name__ == "__main__":
    main()
