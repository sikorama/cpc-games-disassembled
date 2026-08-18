#!/usr/bin/env python3
"""Rendu de reference d'une salle, hors navigateur et hors emulateur.

RAISON D'ETRE. Le portage WebGL (web/) empile projection, matrices, UV et
tri en profondeur : quand le rendu est faux, on ne sait pas LEQUEL est
faux, et le seul retour disponible est "ca ne ressemble a rien". Ce script
reproduit la meme geometrie en ~100 lignes de PIL, sans GPU ni shader, et
produit un PNG regardable. Il sert de referentiel : si ce rendu-ci est bon
et pas celui du navigateur, le bug est dans la couche GL, pas dans la
comprehension du moteur -- et inversement.

PROJECTION -- ATTENTION, ce n'est PAS la formule de la ROM telle quelle.
    x = grid_x + grid_y + proj_offset_x                 (colonne GAUCHE)
    y = (grid_y - grid_x)//2 + grid_z + proj_offset_y   (BAS du sprite)
avec +Y vers le HAUT, soit le MIROIR VERTICAL de la formule de
asm/code/rendering_pipeline.asm:295 (ou screen_y croit vers le bas et designe
le HAUT du sprite).

Ce miroir n'est pas un bug, c'est la moitie d'une paire : les PNG de
tools/sprite_dump_out/ sont eux-memes des images MIROIR du rendu reel
(consequence du ROTATE_90 non explique de sprite_dump.py, cf.
notes/2026-08-13-sprite-rotation-investigation.md), et les deux miroirs se
composent en une image correcte. **En retourner une seule moitie casse tout**
-- essaye le 2026-08-15 : murs tete en bas, portes deplacees, cubes mal
empiles. Le vrai correctif, s'il en faut un, est cote sprite_dump.py.

ORIENTATION DES SPRITES : ce script TRANSCRIT l'echantillonnage du shader
(web/src/gl/spriteBatch.ts), il ne le re-deduit pas. C'est deliberé -- c'est
la seule facon de garantir qu'il montre ce que montre le moteur, donc qu'il
serve d'arbitre. Si le shader change, transcrire le nouveau, ne pas
"corriger" ici.

Trois methodes ont echoue a etablir cette orientation par le raisonnement
(2026-08-15), et leurs modes d'echec valent avertissement :
  - deduire la convention d'axe du desassemblage : exact sur la ROM, mais
    ignorait le miroir des PNG, donc faux pour le portage ;
  - juger "a l'oeil" si un sprite ISOLE est a l'endroit : un cube reste
    plausible sous plusieurs transformations (conclusion fausse deux fois) ;
  - "prouver" l'orientation par comparaison pixel a pixel a une reference :
    mesure exacte (ecart 0) mais CIBLE fausse -- une mesure ne vaut que ce
    que vaut sa reference.
Seule une CAPTURE DU JEU REEL a tranche. Bon critere de controle, parce qu'il
ne depend pas d'un sprite isole : les deux moities d'une porte (types
0x02+0x03) doivent se rejoindre en arche avec cle de voute ; sous la mauvaise
orientation elles s'ecartent en "V".

Usage :
    python3 tools/render_ref.py [salle_hex] [vue 0-3] [--hide-walls]
    python3 tools/render_ref.py 2e 0
"""
import json
import os
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SPRITES = os.path.join(ROOT, "web/public/sprites")
ROOMS = os.path.join(ROOT, "web/public/rooms/rooms_manifest.json")
GRID_CENTER = 0x80


def signed8(b):
    return b - 256 if b >= 128 else b


# Miroir de web/src/render/isoOffsets.ts -- valeurs remontees a
# fn_static_calib_vector_table (asm/code/objects_and_rooms_setup.asm:95).
BLOCK = (240, 248)
CALIB = {
    **{t: BLOCK for t in (0x07, 0x36, 0x37, 0x3E, 0x5B, 0x8F)},
    0x0A: (236, 255),
    0x0B: (244, 254),
    **{t: (248, 252) for t in (0x0C, 0x0D, 0x0E, 0x0F)},
    0x16: (244, 249),
    0x3F: BLOCK,
    **{t: (244, 3) for t in (0x1E, 0x1F, 0x9E, 0x9F)},
    **{t: (244, 250) for t in range(0x90, 0x9E)},
}
DOOR = {  # type -> (calibration bit6=0, calibration bit6=1)
    0x02: ((249, 253), (239, 254)),
    0x03: ((247, 253), (249, 254)),
}


def calib(type_, flags):
    if type_ in DOOR:
        x, y = DOOR[type_][1 if flags & 0x40 else 0]
    elif type_ in CALIB:
        x, y = CALIB[type_]
    else:
        return 0, 0  # type non encore calibre : pas de valeur inventee
    return signed8(x), signed8(y)


def load_sprite_index():
    with open(os.path.join(SPRITES, "manifest.json")) as f:
        manifest = json.load(f)
    index = {}
    for shape in manifest["shapes"].values():
        for type_hex in shape["types"]:
            index[int(type_hex, 16)] = shape
    return index


_cache = {}


def sprite_image(shape, flip):
    """PNG stocke -> image en espace JEU (largeur x hauteur du manifest)."""
    key = (shape["file"], flip)
    if key not in _cache:
        import numpy as np

        arr = np.asarray(Image.open(os.path.join(SPRITES, shape["file"])).convert("L"))
        ph, pw = arr.shape
        w, h = shape["width"], shape["height"]
        # TRANSCRIPTION EXACTE de l'echantillonnage du vertex shader
        # (web/src/gl/spriteBatch.ts) :
        #     v_uv = vec2(1.0 - cy, flip ? 1.0 - cx : cx)
        # plus UNPACK_FLIP_Y_WEBGL (actif dans gl/texture.ts), qui fait que
        # t=0 designe la DERNIERE ligne du PNG. D'ou :
        #     colonne PNG = (1 - cy) * pw
        #     ligne   PNG = (flip ? cx : 1 - cx) * ph
        # Transcrire le shader plutot que "re-deduire" l'orientation est
        # deliberé : c'est la seule facon de garantir que ce rendu de
        # reference montre bien ce que montre le moteur.
        cx = (np.arange(w) + 0.5) / w
        cy = (np.arange(h) + 0.5) / h
        png_col = np.clip(((1 - cy) * pw).astype(int), 0, pw - 1)  # indexe par la ligne ecran
        t = cx if flip else 1 - cx
        png_row = np.clip((t * ph).astype(int), 0, ph - 1)  # indexe par la colonne ecran
        _cache[key] = Image.fromarray(arr[np.ix_(png_row, png_col)].T)
    return _cache[key]


def rotate_grid(gx, gy, view):
    """Les 4 angles : on tourne les ENTREES de la projection, pas la camera."""
    dx, dy = gx - GRID_CENTER, gy - GRID_CENTER
    dx, dy = [(dx, dy), (dy, -dx), (-dx, -dy), (-dy, dx)][view]
    return GRID_CENTER + dx, GRID_CENTER + dy


def render(room_id, view=0, hide_walls=False, scale=3):
    with open(ROOMS) as f:
        rooms = json.load(f)
    sprites = load_sprite_index()

    draws = []
    for e in rooms["0x%02x" % room_id]["entities"]:
        type_ = int(e["type"], 16)
        shape = sprites.get(type_)
        if shape is None:
            continue  # type sans forme connue
        if hide_walls and 0x0A <= type_ <= 0x0F:
            continue
        gx, gy, gz = (int(v, 16) for v in e["grid"])
        flags = int(e["flags"], 16)
        rgx, rgy = rotate_grid(gx, gy, view)
        off_x, off_y = calib(type_, flags)
        # Espace projete du portage : +Y vers le HAUT, ancre BAS-gauche
        # (miroir vertical de l'espace ecran de la ROM -- voir l'en-tete).
        # `sy` est donc le BAS du sprite ; la conversion vers les coordonnees
        # image (+Y vers le bas) se fait une seule fois, au collage.
        sx = rgx + rgy + off_x
        sy = (rgy - rgx) // 2 + gz + off_y
        # Le PNG est un INSTANTANE du bit de miroir, pas un etat neutre : le
        # miroir reel est le XOR avec le bit6 de l'entite. Un quart de tour
        # equivaut a un miroir horizontal pour un objet a symetrie miroir.
        flip = bool(shape["vflip_state"]) != bool(flags & 0x40)
        if view in (1, 3):
            flip = not flip
        draws.append((-rgx + rgy - gz, sx, sy, shape, flip))

    if not draws:
        raise SystemExit("salle vide ou aucun sprite connu")
    draws.sort(key=lambda d: -d[0])  # peintre : du plus loin au plus pres

    min_x = min(d[1] for d in draws)
    max_x = max(d[1] + d[3]["width"] for d in draws)
    min_y = min(d[2] for d in draws)
    max_y = max(d[2] + d[3]["height"] for d in draws)
    w, h = max_x - min_x + 8, max_y - min_y + 8

    canvas = Image.new("L", (w, h), 255)
    for _, sx, sy, shape, flip in draws:
        img = sprite_image(shape, flip)
        mask = Image.eval(img, lambda v: 0 if v > 250 else 255)  # blanc = fond
        # sy est le BAS du sprite dans un espace +Y vers le haut : on retourne
        # ici, une seule fois, vers les coordonnees image (+Y vers le bas).
        top = max_y - (sy + shape["height"])
        canvas.paste(img, (sx - min_x + 4, top + 4), mask)
    return canvas.resize((w * scale, h * scale), Image.NEAREST)


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    room = int(args[0], 16) if args else 0
    view = int(args[1]) if len(args) > 1 else 0
    img = render(room, view, hide_walls="--hide-walls" in sys.argv)
    out = os.path.join(ROOT, "tools/render_ref_out")
    os.makedirs(out, exist_ok=True)
    path = os.path.join(out, "room_%02x_v%d.png" % (room, view))
    img.save(path)
    print(path, img.size)


if __name__ == "__main__":
    main()
