#!/usr/bin/env python3
"""Pixel-exact screenshot quantizer for Knight Lore RE.

The MCP `screenshot` tool (tools/mcp-emulator/server.py) already exposes
AMSpiriT-Lite's /api/screenshot endpoint — this script doesn't duplicate
that, it solves a different problem: the analysing agent has no native
image-vision capability in this environment, so a raw PNG is useless for
comparing a decoded sprite/glyph (RAM bytes -> pixels) against what is
actually on screen. Downsampling to grayscale ASCII-art (used earlier in
the session) loses colour information and is too lossy for pixel-exact
comparison.

This tool instead:
  1. fetches the current GA state (mode + active ink palette) via the
     amspirit MCP server's helper functions,
  2. fetches a screenshot,
  3. quantizes every pixel to the nearest active pen (Mode 0/1/2 aware),
  4. prints (or returns) a compact grid of pen indices for a chosen crop
     region — directly comparable to a hand-decoded 2bpp/1bpp bitmap.

Usage (from this directory, with the amspirit MCP venv active):
    python3 pixel_quantize.py [x0 y0 w h] [--scale N]

Prints a grid of digits (0-3 for Mode 1, 0-1 for Mode 2, 0-15 for Mode 0)
downsampled by --scale (default: auto-detect via run-length heuristic).
"""
import sys
import importlib.util
from pathlib import Path

AMSPIRIT_MCP_SERVER = "/var/home/siko/Code/Amspirit/amspirit-lite/tools/mcp-emulator/server.py"


def _load_server():
    # server.py does `import z80dis` (sibling module, not a package) —
    # its directory must be on sys.path before exec_module runs.
    server_dir = str(Path(AMSPIRIT_MCP_SERVER).parent)
    if server_dir not in sys.path:
        sys.path.insert(0, server_dir)
    spec = importlib.util.spec_from_file_location("amspirit_mcp_server", AMSPIRIT_MCP_SERVER)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"cannot load spec for {AMSPIRIT_MCP_SERVER}")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def rgb_from_packed(v: int):
    return ((v >> 16) & 0xFF, (v >> 8) & 0xFF, v & 0xFF)


def active_pen_count(mode: int) -> int:
    return {0: 16, 1: 4, 2: 2}.get(mode, 4)


def nearest_pen(rgb, palette):
    r, g, b = rgb
    best_i, best_d = 0, None
    for i, (pr, pg, pb) in enumerate(palette):
        d = (r - pr) ** 2 + (g - pg) ** 2 + (b - pb) ** 2
        if best_d is None or d < best_d:
            best_d, best_i = d, i
    return best_i


def detect_pixel_scale(img, x0, y0, w, h, palette):
    """Heuristic: scan several horizontal lines, find the most common run
    length of a constant nearest-pen value that is NOT the whole scanned
    width (i.e. skip solid-colour rows) -> that's the on-screen width (in
    real screenshot pixels) of one CPC pixel. CPC Mode 1 doubles pixels
    horizontally, so this is typically 2 on a 768px-wide crop (384 CPC
    pixels) and 1 vertically."""
    px = img.load()
    run_lengths = []
    for y in range(y0, min(y0 + h, img.size[1]), max(1, h // 8)):
        prev = None
        run_len = 0
        for x in range(x0, min(x0 + w, img.size[0])):
            pen = nearest_pen(px[x, y][:3], palette)
            if pen == prev:
                run_len += 1
            else:
                if prev is not None and 0 < run_len < w:
                    run_lengths.append(run_len)
                prev, run_len = pen, 1
        if 0 < run_len < w:
            run_lengths.append(run_len)
    if not run_lengths:
        return 1
    run_lengths.sort()
    # take the smallest run length seen more than once — a single stray
    # run of length 1 could be an anti-aliased edge, not the true pixel
    # size; the modal small value is more robust.
    from collections import Counter

    counts = Counter(run_lengths)
    candidates = [v for v in sorted(counts) if counts[v] >= 2]
    return candidates[0] if candidates else run_lengths[0]


def quantize_region(server, x0: int, y0: int, w: int, h: int, scale: "int | None" = None):
    from PIL import Image
    import io

    st = server.emu_state()
    ga = st["ga"]
    mode = ga["mode"]
    n_pens = active_pen_count(mode)
    palette = [rgb_from_packed(v) for v in ga["ink_rgb"][:n_pens]]

    img_obj = server.screenshot(crop=True, full=True)
    img = Image.open(io.BytesIO(img_obj.data)).convert("RGB")

    if scale is None:
        scale = detect_pixel_scale(img, x0, y0, w, h, palette)
    assert scale is not None

    px = img.load()
    grid = []
    yy = y0
    while yy < y0 + h and yy < img.size[1]:
        row = []
        xx = x0
        while xx < x0 + w and xx < img.size[0]:
            pen = nearest_pen(px[xx, yy][:3], palette)
            row.append(pen)
            xx += scale
        grid.append(row)
        yy += scale
    return grid, palette, mode, scale


def print_grid(grid):
    for row in grid:
        print("".join(str(v) for v in row))


if __name__ == "__main__":
    args = sys.argv[1:]
    scale = None
    if "--scale" in args:
        i = args.index("--scale")
        scale = int(args[i + 1])
        del args[i : i + 2]
    if len(args) >= 4:
        x0, y0, w, h = map(int, args[:4])
    else:
        x0, y0, w, h = 0, 0, 768, 272

    server = _load_server()
    grid, palette, mode, used_scale = quantize_region(server, x0, y0, w, h, scale)
    print(f"# mode={mode} palette={palette} detected_scale={used_scale} region=({x0},{y0},{w},{h})", file=sys.stderr)
    print_grid(grid)
