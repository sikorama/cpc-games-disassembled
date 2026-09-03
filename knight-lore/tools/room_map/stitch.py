#!/usr/bin/env python3
"""Assemble teleport.py's per-room screenshots into one world-map image.

Grid placement (confirmed + empirically validated 2026-08-07, see
docs/SESSION_SUMMARY.md §6/§7 and notes/2026-08-07-entity-logic-doors.md):
room_id's nibbles ARE the world-grid coordinates directly — x = low
nibble, y = high nibble. No adjacency-table decoding needed.

Crop rectangle: the isometric camera framing is at a FIXED screen
position for every room (same projection offsets, see
notes/2026-08-06-rendering-engine.md), so a single shared crop window
applied identically to every capture keeps tiles aligned when stitched.
CONTENT_CROP below was derived empirically (2026-08-07) by diffing two
different rooms' screenshots (player+walls hidden via
--hide-player --hide-decor) and taking the bounding box of what
differed — i.e. where room content can appear, as opposed to the
border/HUD which is identical regardless of room. Only checked against
2 sample rooms, not the full 128 — if tiles look clipped after a full
sweep, widen CONTENT_CROP and re-run (no emulator access needed, this
only touches saved PNGs).

Usage (from this directory, after a capture sweep):
    python3 teleport.py --all --out out/ --hide-player --hide-decor
    python3 stitch.py --dir out/ --out out/world_map.png
"""
import argparse
import json
from pathlib import Path

from PIL import Image,ImageDraw,ImageColor

# (left, top, right, bottom) in the 768x542 "crop=1,full=1,live=0" screenshot
# coordinate space — see module docstring.
CONTENT_CROP = (128, 82, 640, 420)
#CONTENT_CROP = (128, 82, 640, 500)

GRID_COLS = 16  # room_id low nibble
GRID_ROWS = 16  # room_id high nibble
OVERLAP_COEF =0.7

def load_manifest(out_dir: Path) -> dict:
    manifest_path = out_dir / "rooms_manifest.json"
    return json.loads(manifest_path.read_text())


def stitch(out_dir: Path, crop, dest: Path):
    manifest = load_manifest(out_dir)
    tile_w = crop[2] - crop[0]
    tile_h = crop[3] - crop[1]

    canvas = Image.new("RGB", ( int((GRID_COLS+GRID_ROWS) * tile_w *OVERLAP_COEF),
                                int((GRID_COLS+GRID_ROWS) * tile_h *OVERLAP_COEF) ),
                                (0, 0, 0) )

    # Iso Grid
    draw0 = ImageDraw.Draw(canvas)
    for x in range(64):
        draw0.line( [(0 ,int(  OVERLAP_COEF* (2*x * tile_h) + crop[1] )) ,
                     ( int(OVERLAP_COEF*2*x*tile_w), crop[1] ) ], ImageColor.getrgb("#323232") ,1)
        draw0.line( [(0 ,int(  OVERLAP_COEF*(2*(x-32) * tile_h+crop[3]-crop[1]) )) ,
                     ( int(OVERLAP_COEF*2*64*tile_w), int(OVERLAP_COEF*(2*(x+32)*tile_h+crop[3]-crop[1])) ) ], ImageColor.getrgb("#323232") ,1)



    placed, missing_png = 0, []

    for key, entry in manifest.items():
        room_id = int(key, 16)
        fname = entry.get("screenshot")
        if not fname:
            missing_png.append(key)
            continue
        img_path = out_dir / fname
        if not img_path.exists():
            missing_png.append(key)
            continue
        img = Image.open(img_path).convert("RGB").crop(crop)
        draw = ImageDraw.Draw(img)
#        draw.polygon( [(0,315-crop[1]),(350-crop[0],410-1-crop[1]),(410-crop[0],410-1-crop[1]),(640-1-crop[1],315-crop[1]),(640-1-crop[1],420-crop[1]),(0,420-crop[1]) ], ImageColor.getrgb("#000000"),ImageColor.getrgb("#FF0000") ,1)
        draw.polygon( [(0,             315-crop[1]),
                       (350-crop[0],   425-1-crop[1]),
                       (410-crop[0],   425-1-crop[1]),
                       (640-1-crop[0], 315-crop[1]),
                       (640-1-crop[0], 500-1-crop[1]),
                       (0,             500-1-crop[1]) ], ImageColor.getrgb("#000000"),ImageColor.getrgb("#FF0000") ,0)




        mask = img.convert("L").point(lambda i: 0 if i < 30 else 255)


        gy, gx = room_id & 0x0F , room_id >>4
        canvas.paste(img, (int((gx+gy) * tile_w * OVERLAP_COEF), int(OVERLAP_COEF * (gy-gx+16) * tile_h  )), mask)
        placed += 1

    canvas.save(dest)
    print(f"placed {placed}/{len(manifest)} rooms into {dest} "
          f"({GRID_COLS * tile_w}x{GRID_ROWS * tile_h}px, {tile_w}x{tile_h}/tile)")
    if missing_png:
        print(f"skipped (no screenshot on disk): {sorted(missing_png)}")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--dir", default=str(Path(__file__).parent / "out"),
                    help="directory containing rooms_manifest.json + room_0x*.png (teleport.py --out)")
    ap.add_argument("--out", default=None, help="output PNG path (default: <dir>/world_map.png)")
    ap.add_argument("--crop", default=None,
                    help="override crop rect as 'left,top,right,bottom' (default: CONTENT_CROP)")
    args = ap.parse_args()

    out_dir = Path(args.dir)
    dest = Path(args.out) if args.out else out_dir / "world_map.png"
    crop = tuple(int(v) for v in args.crop.split(",")) if args.crop else CONTENT_CROP

    stitch(out_dir, crop, dest)


if __name__ == "__main__":
    main()
