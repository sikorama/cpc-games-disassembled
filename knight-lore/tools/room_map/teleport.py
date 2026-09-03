#!/usr/bin/env python3
"""Room teleport tool for Knight Lore RE.

Technique

1. Pause the emulator (and confirm it actually took effect — the pause
   flag is not applied synchronously, see Client.set_paused).
2. Write and jump to a tiny 12-byte trampoline in scratch RAM (inside
   the entity table itself, which the room load about to run
   overwrites anyway) — see trampoline_for():
       LD A,room_id ; LD (00DF),A ; LD IX,00D7 ; JP 05A5
   All in ONE ram_write(execute=True) call — the web server keeps only
   one pending write at a time, so two separate calls (one for the
   room id, one for the trampoline) can silently coalesce and drop the
   first (confirmed the hard way). `LD IX,00D7` is NOT optional either:
   jumping straight to 0x05A5 (the game's own "reload current room"
   entry point, right before its `CALL fn_init_room`) leaves IX at
   whatever residual value the interrupted frame happened to have, and
   fn_load_room_data (0x2C3A) reads (IX+08) to pick which room's decor
   to load — skip it and you silently get the WRONG room's decor while
   the player's own room field looks correct.
3. Breakpoint at 0x05A8 (right after fn_init_room's CALL returns).
   Resume; it fires almost instantly. At this exact point ZERO frames
   of the main game loop have executed for the new room yet — no
   entity AI, no collision check has run — so there is no way for the
   player to have taken damage or moved.
4. Verify the room field actually changed and retry (a few times) if
   not — this whole sequence is intermittently flaky in a way not
   fully root-caused (occasionally lands on the breakpoint with the
   PREVIOUS room's decor still in place, no error). See teleport()'s
   docstring.
5. REVISED (2026-08-07): the room is NOT necessarily fully blitted the
   instant fn_init_room's CALL returns — a screenshot taken right at
   POST_INIT_BP can show the previous room's picture.
6. REVISED AGAIN (2026-08-14): step 5's original fix (advance a fixed
   `--settle-frames` count via a breakpoint on fn_main_loop) turned out
   to be racy, not just "usually enough": the real blit to VRAM is
   gated by var_render_disabled_flag (0x007D) — see
   wait_render_enabled()'s docstring for the full empirical diagnosis.
   Live measurement showed it ALWAYS clears within exactly 1 real frame
   regardless of room; the identical-screenshots-for-different-rooms bug
   this project hit came from the breakpoint-based frame COUNTING being
   unreliable (a new instance of this file's already-documented
   async/eventual-consistency races), not from the game actually needing
   more than 10 frames. Fixed by polling the flag itself via ram_read
   while running fully unpaused, with a wall-clock timeout as the safety
   net instead of a frame-count guess. See notes/2026-08-14-render-
   disabled-flag-settle-race.md. --settle-frames still exists, now
   purely as an optional COSMETIC extra wait (entity animation) applied
   AFTER correctness is already confirmed, measured via var_frame_counter
   polling rather than a breakpoint.

This is a REAL teleport, not a preview: the player entity's room field
is genuinely changed, and gameplay continues from the injected room
once you stop calling this tool. Use --restore to hop back to the
original room (position within the room is NOT preserved — fn_init_room
always resets the player to a fixed default grid position regardless of
target room, confirmed empirically; this is a game behavior, not a tool
limitation).

Usage (from this directory):
    python3 teleport.py 0x8D                       # peek one room, print + save screenshot
    python3 teleport.py --all --out out/            # sweep all 128 known rooms
    python3 teleport.py --rooms 0x8D,0xBB --restore # a few rooms, then hop back
"""
import argparse
import json
import sys
import time
from pathlib import Path

import httpx

BASE_URL = "http://127.0.0.1:8765"

ENTITY_BASE = 0x00D7
ENTITY_SIZE = 28
ENTITY_COUNT = 40  # confirmed 2026-08-07: the active per-room buffer is
                    # bounded to 0x0537 (= ENTITY_BASE + 40*28), NOT 128 —
                    # see notes/2026-08-07-pickup-sequence-hypothesis.md
RELOAD_ENTRY = 0x05A5      # `CALL 2A68` (fn_init_room) inside the restart sequence
POST_INIT_BP = 0x05A8      # right after that CALL returns
TRAMPOLINE_ADDR = 0x0500   # scratch: inside the entity table, overwritten by the
                            # room load that immediately follows — safe to clobber
MAIN_LOOP_ADDR = 0x05AE    # `fn_main_loop` (confirmed, docs/SYMBOLS.md) — runs once
                            # per frame. NO LONGER used as a breakpoint target (see
                            # advance_frames()'s docstring: re-arming a breakpoint on
                            # this exact address was found, 2026-08-14, to
                            # sometimes report a "hit" without a real frame having
                            # elapsed — a new instance of this same server's
                            # already-documented async races). Kept only as a
                            # documented address constant.

RENDER_DISABLED_FLAG_ADDR = 0x007D  # var_render_disabled_flag (confirmed,
                            # docs/SYMBOLS.md) — non-zero from the moment
                            # fn_init_room finishes until fn_render_disabled_
                            # one_time_setup (#062F) has done the ONE-TIME blit
                            # of the freshly loaded room from the intermediate
                            # render buffer (0x9000-0xBFFF) to real VRAM
                            # (fn_copy_screen_rect, #2DBF) and cleared it back to
                            # 0 — see wait_render_enabled()'s docstring for the
                            # full empirical story (2026-08-14).
FRAME_COUNTER_ADDR = 0x006A         # var_frame_counter (confirmed, docs/SYMBOLS.md):
                            # 16-bit, incremented exactly once per real
                            # fn_main_loop iteration by fn_frame_tick_and_mix
                            # (#05F7) — used as the ground truth for "how many
                            # real frames actually elapsed", since (see above)
                            # a breakpoint on fn_main_loop's own address turned
                            # out not to be trustworthy for that.

CONNECTIONS_ADDR = 0x0147  # tbl_room_connections (confirmed, docs/SYMBOLS.md): up to
CONNECTIONS_LEN = 4 * 56   # 4 entries of 56 bytes, populated fresh by fn_load_room_data
                            # for the CURRENT room — already valid at POST_INIT_BP.
                            # The exact field->neighbour-room mapping is NOT decoded yet
                            # (see notes/2026-08-06-world-map-attempt.md), so this is
                            # dumped raw for offline analysis, not parsed here.

# Projection-based visibility hiding (confirmed mechanism, NOT sprite-graphic
# patching — see hide_offscreen() docstring).
PROJ_Y_INPUT_OFFSET = 0x03   # entity field "grid_z_or_offset" (ix+03), confirmed
PROJ_Y_INPUT13_OFFSET = 0x13 # per-entity additive projection offset (ix+13), confirmed
PROJ_Y_RESULT_OFFSET = 0x17  # (ix+17), output of fn_projection (0x2EDC), confirmed
OFFSCREEN_Y_TARGET = 0xE0    # comfortably inside the >=0xC0 "skip draw" range


def trampoline_for(room_id: int) -> bytes:
    """LD A,room_id ; LD (00DF),A ; LD IX,00D7 ; JP 05A5 — one atomic
    12-byte program. The room_id write and the trampoline MUST be a
    SINGLE ram_write call: the web server holds only one pending write
    at a time, so two separate ram_write calls issued back-to-back can
    coalesce and silently drop the first one (found the hard way — a
    two-call version intermittently "teleported" while leaving the old
    room's decor in place, with no error). See
    notes/2026-08-07-room-teleport-tool-validated.md."""
    return bytes([0x3E, room_id & 0xFF, 0x32, 0xDF, 0x00, 0xDD, 0x21, 0xD7, 0x00, 0xC3, 0xA5, 0x05])

# The 128 confirmed room IDs from tbl_room_master_index (0x33DD), reused
# verbatim from the old dump_rooms.py (parsed 2026-08-06, unrelated to
# the teleport technique itself).
ALL_ROOM_IDS = [
    0, 1, 2, 3, 4, 8, 9, 10, 11, 12, 13, 14, 15, 16, 18, 20, 24, 29, 31, 32,
    33, 34, 36, 39, 40, 45, 46, 47, 48, 52, 55, 56, 63, 64, 65, 66, 67, 68,
    69, 70, 71, 72, 79, 84, 87, 88, 94, 95, 100, 103, 104, 106, 107, 108,
    109, 110, 111, 116, 117, 118, 119, 120, 121, 122, 131, 132, 133, 134,
    135, 136, 137, 138, 139, 140, 141, 142, 143, 147, 151, 152, 155, 159,
    163, 167, 168, 170, 171, 175, 179, 180, 183, 186, 187, 191, 195, 199,
    207, 208, 209, 210, 211, 214, 215, 216, 217, 221, 222, 223, 224, 226,
    227, 230, 231, 232, 233, 237, 239, 240, 241, 242, 243, 246, 247, 248,
    249, 253, 254, 255,
]

# Known type IDs -> short label, from docs/SYMBOLS.md (2026-08-07 state).
# Used only to annotate manifest output for readability; NOT authoritative
# — cross-check docs/SYMBOLS.md for status (confirmed vs hypothesis).
KNOWN_TYPES = {
    0x02: "door_post_A", 0x03: "door_post_B",
    0x04: "door_post_A_forest", 0x05: "door_post_B_forest",
    0x06: "block_static_A", 0x07: "block_static_B",
    0x09: "moving_grate", 0x16: "toad_statue", 0x17: "floor_spikes",
    0x1E: "guard_body", 0x1F: "guard_body_walk",
    0x36: "moving_block_A", 0x37: "moving_block_B",  # same logic, different speed/pattern params
    0x3E: "pushable_block", 0x3F: "ceiling_spike_ball",
    0x50: "ghost", 0x51: "ghost", 0x52: "ghost", 0x53: "ghost",
    0x54: "pushable_table", 0x55: "sliding_chest",
    0x56: "will_o_wisp_variant",  # same sprite as 0xB4, different logic
    0x60: "pickup_diamond", 0x64: "pickup_cup", 0x65: "pickup_bottle",
    0x66: "pickup_crystal_ball", 0x67: "pickup_bonus_life",
    0x80: "wall_segment",
    0x8D: "wizard_or_cauldron", 0x8E: "wizard_or_cauldron", 0x9E: "wizard_cauldron_animation",  # room 0x88 only
    0x8F: "dormant_block",  # looks like a plain block until a flag triggers a transform into 0xB8
    0x90: "guard_legs", 0x91: "guard_legs", 0x92: "guard_legs", 0x93: "guard_legs",
    0x94: "guard_legs", 0x95: "guard_legs",
    # 0x96/0x97 deliberately NOT guard_legs — confirmed different logic+sprite,
    # still unidentified (see notes/2026-08-07-full-sweep-entity-identification.md)
    0x98: "guard_legs", 0x99: "guard_legs", 0x9A: "guard_legs", 0x9B: "guard_legs",
    0x9C: "guard_legs", 0x9D: "guard_legs",
    0xA4: "pusher", 0xA5: "pusher", 0xA6: "pusher", 0xA7: "pusher",
    0xB2: "bouncing_ball", 0xB3: "bouncing_ball",
    0xB4: "will_o_wisp", 0xB5: "will_o_wisp",
    0xB6: "ball_chase_or_flee_player_form_dependent",
    0xB8: "block_transform_animation_step",  # increments its own type each frame
    0x5B: "sinking_cube",  # descends under the player's weight (pressure-plate-like)
}
for _t in range(0x0A, 0x10):
    KNOWN_TYPES.setdefault(_t, "wall")
for _t in range(0x61, 0x65):
    KNOWN_TYPES.setdefault(_t, "pickup_crystal_family_unidentified")
# Player type families (day/night/transform/jump/materialize) deliberately
# left unlabeled here — entity slot 0 is always the player, no need to guess.

# Types worth stripping out when producing a "readable" map (pure static
# decor with no gameplay identity of its own) — per user request 2026-08-07.
DECOR_TYPES = {0x80} | set(range(0x0A, 0x10)) | {0x06, 0x07}

# Subset of DECOR_TYPES that are actual room-boundary walls, for --hide-decor.
# Deliberately EXCLUDES 0x06/0x07 (static blocks/"cubes"): user feedback
# 2026-08-07 — --hide-decor was removing those too, but they're worth
# keeping visible in a stitched map (unlike literal boundary wall segments).
WALL_TYPES = {0x80} | set(range(0x0A, 0x10))


class Client:
    def __init__(self, base_url: str = BASE_URL):
        self.c = httpx.Client(base_url=base_url, timeout=10.0)

    def state(self):
        return self.c.get("/api/state").json()

    def ram_read(self, addr: int, length: int, view: str = "cpu") -> bytes:
        r = self.c.get("/api/ram", params={"addr": addr, "len": length, "bank": 0, "view": view}).json()
        return bytes.fromhex(r["hex"])

    def ram_write(self, addr: int, data: bytes = b"", execute: bool = False, entry: int = None,
                  verify: bool = True, verify_timeout_s: float = 1.0):
        """POST /api/ram is NOT applied synchronously — CONFIRMED 2026-08-10
        (see notes/2026-08-07-room-teleport-tool-validated.md's "one pending
        write at a time" note, this is the same underlying issue seen from a
        different angle): the emulator queues the write and applies it on
        its own loop tick, so a ram_read() issued right after a ram_write()
        can race and return the OLD bytes — reproduced directly: writing 1120
        bytes then reading back immediately failed nondeterministically,
        while the same write followed by a 50ms sleep always landed. This
        was the root cause of `--hide-player`/`--hide-decor` silently doing
        nothing (hide_offscreen()'s write to the whole entity table would
        sometimes not have landed yet by the time advance_frames() resumed
        the CPU, so the very first frame — and everything screenshotted
        after — used the stale, un-hidden entity data).

        Default now polls ram_read() back until the write is confirmed
        (or verify_timeout_s elapses, raising TimeoutError — better to fail
        loudly than silently ship a screenshot built on a write that never
        landed). `execute=True` trampoline writes pass verify=False: their
        target bytes get overwritten by the jump's own effects (the room
        load clobbers the trampoline scratch area on purpose, see
        trampoline_for()'s docstring), so reading them back to confirm is
        meaningless — that call site relies on wait_paused_at() instead,
        which is its own confirmation that execution actually reached the
        trampoline and jumped."""
        body = {"addr": addr, "data": data.hex(), "exec": execute}
        if entry is not None:
            body["entry"] = entry
        self.c.post("/api/ram", json=body)
        if not verify or not data:
            return
        deadline = time.monotonic() + verify_timeout_s
        while time.monotonic() < deadline:
            if self.ram_read(addr, len(data)) == data:
                return
            time.sleep(0.02)
        raise TimeoutError(f"ram_write to 0x{addr:04X} ({len(data)} bytes) never landed within {verify_timeout_s}s")

    def set_breakpoints(self, addrs):
        self.c.post("/api/z80_bp", content=",".join(addrs))

    def set_paused(self, paused: bool, confirm: bool = False, timeout_s: float = 2.0):
        self.c.post("/api/config", json={"paused": paused})
        if not confirm:
            return
        # POST /api/config does not take effect synchronously — the emulator
        # runs on its own loop and can keep executing several more frames
        # before the pause flag is actually observed. Writing RAM/PC before
        # pause is CONFIRMED races against that still-running loop (found the
        # hard way: room-id writes silently got lost/overwritten). Always
        # confirm=True before any write you need to land cleanly.
        deadline = time.monotonic() + timeout_s
        while time.monotonic() < deadline:
            if self.state()["emu"]["paused"] == paused:
                return
            time.sleep(0.01)
        raise TimeoutError(f"emulator never reached paused={paused} within {timeout_s}s")

    def screenshot(self) -> bytes:
        # live=0 is NOT the default while paused (web_handle.cpp defaults
        # `live` to 1 whenever paused, favouring the beam-position debug
        # composite over the settled frame) — always pass it explicitly, or
        # every screenshot taken right after a breakpoint silently mixes in
        # a partial/mid-render buffer instead of the complete one. See
        # server-issues-to-fix.md discussion (this isn't a server bug, just
        # an easy default to miss) and notes/2026-08-07-room-teleport-tool-validated.md.
        r = self.c.get("/api/screenshot", params={"crop": 1, "full": 1, "live": 0})
        return r.content

    def wait_paused_at(self, pc: int, timeout_s: float = 3.0, poll_s: float = 0.02):
        deadline = time.monotonic() + timeout_s
        while time.monotonic() < deadline:
            st = self.state()
            if st["emu"]["paused"] and st["z80"]["PC"] == pc:
                return st
            time.sleep(poll_s)
        raise TimeoutError(f"never paused at 0x{pc:04X} within {timeout_s}s")


def wait_render_enabled(client: Client, timeout_s: float = 2.0, poll_s: float = 0.01) -> bool:
    """THE FIX for the 2026-08-14 stale-screenshot bug (see
    notes/2026-08-14-render-disabled-flag-settle-race.md). Root-caused
    empirically, not guessed:

    docs/SYMBOLS.md already documented that `fn_init_room` (#2A68) sets
    `var_render_disabled_flag` (#007D) = 1 at the end of loading a room,
    and that `fn_render_disabled_one_time_setup` (#062F) — called
    unconditionally every frame from `fn_main_loop`, but itself gated on
    that flag — does the actual one-time work of blitting the freshly
    rendered room from the intermediate buffer (0x9000-0xBFFF) to real
    VRAM (`fn_copy_screen_rect`, #2DBF) and THEN clears the flag back to
    0. This function was written on the hypothesis (from the task brief)
    that this hand-off might take a variable, sometimes-more-than-10-
    frame number of real fn_main_loop iterations depending on room
    complexity — which is why the old code advanced a flat
    `--settle-frames` count and hoped for the best.

    Live measurement (2026-08-14, polling both var_frame_counter #006A
    and this flag while running completely unpaused, no breakpoints)
    DISPROVED that hypothesis: for every room tested — including the
    known-bad ones (0x44/0x45/0x46/0xab/0xaf/0xb3/0xb4/0x97/0x98/0xc3/
    0xc7) and known-good ones (0x47/0x48) — var_frame_counter advances
    by EXACTLY 1 between POST_INIT_BP and the flag clearing. The
    materialization is not slow or room-dependent at all; it always
    completes on the very first real frame.

    So the actual bug was never in the game's timing — it was in how
    the OLD advance_frames() measured frames: it re-armed a breakpoint
    on fn_main_loop's own address (0x05AE) and resumed N times. Direct
    side-by-side instrumentation (multi-breakpoint trace vs.
    var_frame_counter deltas) caught this breakpoint reporting a "hit"
    on 0x05AE with var_frame_counter NOT having advanced in between —
    i.e. the same class of async/eventual-consistency race already
    documented elsewhere in this file for ram_write() and set_paused()
    (the emulator's breakpoint/pause machinery runs on its own loop, not
    synchronously with the request that armed it). A flat 10-iteration
    loop over a sometimes-phantom breakpoint could, in the worst case,
    "complete" all 10 iterations while the CPU made far less real
    progress than that — leaving var_render_disabled_flag still set and
    the screen showing genuinely stale VRAM content, which is exactly
    the identical-PNG-across-different-rooms symptom this was chasing.

    The fix: don't use a breakpoint to count frames at all. Run
    completely unpaused and poll the flag itself directly via ram_read
    (same "poll the real signal, not a proxy for it" philosophy as
    wait_paused_at()/ram_write()'s verify loop elsewhere in this file).
    Returns True once the flag reads 0 (room is genuinely on real VRAM
    now), or False if timeout_s elapses first (safety net, NOT expected
    in normal operation given the measurement above — a caller should
    warn loudly rather than silently ship a possibly-stale screenshot).
    Leaves the emulator PAUSED on return either way, ready for a
    screenshot."""
    client.set_breakpoints([])
    client.set_paused(False)
    deadline = time.monotonic() + timeout_s
    while time.monotonic() < deadline:
        if client.ram_read(RENDER_DISABLED_FLAG_ADDR, 1)[0] == 0:
            client.set_paused(True, confirm=True)
            return True
        time.sleep(poll_s)
    client.set_paused(True, confirm=True)
    return False


def advance_frames(client: Client, n: int, timeout_s: float = 3.0):
    """Advance (at least) n REAL frames, measured via var_frame_counter
    (#006A, 16-bit, incremented exactly once per fn_main_loop iteration)
    polled while running unpaused — NOT via a breakpoint on fn_main_loop's
    own address. An earlier version of this function did exactly that
    (break on 0x05AE, resume, repeat n times) and was found 2026-08-14 to
    be unreliable: re-arming a breakpoint on the address you just paused
    at can report a "hit" without the emulator's own frame counter having
    advanced in between (see wait_render_enabled()'s docstring for the
    full diagnosis — this is what actually caused the stale-screenshot
    bug this file used to have, not room-dependent rendering timing).
    Polling the game's own frame counter sidesteps that breakpoint race
    entirely, at the cost of needing a wall-clock timeout as a safety net
    (raises TimeoutError if n frames don't elapse in time — should not
    happen in normal operation).

    Used here only for a small cosmetic settle AFTER
    wait_render_enabled() has already confirmed the room is genuinely on
    VRAM — entity animation (e.g. a moving ceiling-spike-ball) can still
    visibly shift for a couple of frames after that point, which is
    fine/expected, not a correctness issue like the stale-VRAM bug was."""
    client.set_breakpoints([])
    fc0 = int.from_bytes(client.ram_read(FRAME_COUNTER_ADDR, 2), "little")
    client.set_paused(False)
    deadline = time.monotonic() + timeout_s
    while time.monotonic() < deadline:
        fc = int.from_bytes(client.ram_read(FRAME_COUNTER_ADDR, 2), "little")
        if ((fc - fc0) & 0xFFFF) >= n:
            client.set_paused(True, confirm=True)
            return
        time.sleep(0.005)
    client.set_paused(True, confirm=True)
    raise TimeoutError(f"only advanced {((fc - fc0) & 0xFFFF)}/{n} frames within {timeout_s}s")


def hide_offscreen(raw: bytearray, slots):
    """Patch chosen entity slots so the game's OWN visibility check
    (fn_projection 0x2EDC computing (ix+17), then `CP 0xC0` / `RET NC`
    at its caller 0x2F2A) skips drawing them entirely — confirmed
    mechanism, see notes/2026-08-06-rendering-engine.md ("CONFIRMÉ
    NUMÉRIQUEMENT ET VISUELLEMENT"). Deliberately does NOT touch sprite
    bitmap data: that blit format (fn_resolve_sprite_shape 0x2F02
    onward) is still only partially understood ("hypothesis,
    interprétation partielle" as of 2026-08-06) — patching it blind
    would risk corrupting rendering in unpredictable ways. Nudging the
    entity out of the visible projection range is a much smaller,
    fully-confirmed lever for the same visual result (no sprite drawn
    at all), reusable identically for the player and for wall/decor
    entities.

    Only (ix+03) is modified. Z80 8-bit add/sub is modular, and (ix+03)
    enters the (ix+17) formula as a plain additive term (see 0x2EEA-
    0x2EFC): shifting it by `delta` shifts the final (ix+17) by exactly
    `delta` mod 256, regardless of the entity's other projection inputs
    ((ix+01), (ix+02), (ix+13)) — so this works without needing to read
    a "current" (ix+17) (which would be stale: it's the OUTPUT of last
    frame's render, not yet recomputed for a just-loaded room; instead
    this recomputes what (ix+17) is *about to become* from the
    already-fresh (ix+01)/(ix+02)/(ix+03)/(ix+13) fn_init_room just
    populated)."""
    for i in slots:
        base = i * ENTITY_SIZE
        a = raw[base + 0x01]
        b = raw[base + 0x02]
        c = raw[base + PROJ_Y_INPUT_OFFSET]
        off13 = raw[base + PROJ_Y_INPUT13_OFFSET]
        step = (((b - a) & 0xFF) + 0x80) & 0xFF
        step >>= 1
        step = (step + c) & 0xFF
        step = (step - 0x68) & 0xFF
        predicted17 = (step + off13) & 0xFF
        delta = (OFFSCREEN_Y_TARGET - predicted17) & 0xFF
        raw[base + PROJ_Y_INPUT_OFFSET] = (c + delta) & 0xFF


def teleport(client: Client, room_id: int, max_attempts: int = 8,
             settle_frames: int = 10, hide_player: bool = False,
             hide_decor: bool = False) -> dict:
    """Teleport the live player to room_id. Returns
    {room_id, verified, entities: [...], screenshot: bytes}.

    `verified` is True iff the player entity's own room field AND every
    non-empty decor entity's room field read back as room_id.

    Retries internally: this whole sequence (pause, arm breakpoint,
    one atomic write+PC-redirect, resume, land on the breakpoint) is
    intermittently flaky in a way not fully root-caused — most of the
    time it works first try, but occasionally the room silently fails
    to reload and the breakpoint is hit with the PREVIOUS room's decor
    still in place (no error, just stale data — only caught by
    checking the actual room field). A flat delay between attempts did
    NOT reproduce/fix it (tested), so this is not simply "too fast" —
    treat it as a rare race in the emulator's web-request handling and
    retry rather than trust a single attempt. See
    notes/2026-08-07-room-teleport-tool-validated.md.

    IMPORTANT: the retry check must look at the WHOLE entity table, not
    just the player's own room field — found the hard way, a partial
    reload can leave the player's field correctly updated while some
    decor entity is still holding the PREVIOUS room's value (verified
    only by parsing every slot, not a single byte).

    Before any of that settling, wait_render_enabled() blocks (with a
    timeout, see its docstring) until var_render_disabled_flag genuinely
    clears — i.e. until the freshly loaded room has actually been
    blitted to real VRAM — rather than assuming a fixed frame count got
    there (see wait_render_enabled()'s docstring for the empirical
    2026-08-14 root-cause story: it never actually took more than 1 real
    frame, but the OLD breakpoint-based counting could silently
    undercount real progress).

    settle_frames > 0 THEN means real main-loop frames additionally run
    before the screenshot (see advance_frames()), purely as a cosmetic
    buffer past that correctness point — entity AI and collision DO run
    during that window, unlike the zero-frame POST_INIT_BP moment. This
    reopens a previously-documented failure mode (see
    notes/2026-08-07-room-mapping-tool-failure.md): the player spawns at
    a fixed default grid position that can overlap an enemy, and dying
    silently swaps the room field to a respawn room WITHOUT any visible
    error — a naive caller would screenshot and log the WRONG room as
    if it were the requested one. So the post-settle player room field
    is re-checked against room_id below and, if it drifted, the whole
    attempt (not just the settle) is retried from a fresh teleport —
    same philosophy as the stale-decor retry above, just checked at a
    later point in the sequence."""
    raw = None
    entities = []
    connections = b""
    verified = False
    for attempt in range(max_attempts):
        client.set_paused(True, confirm=True)
        # Clear breakpoints before re-arming the same address: the emulator
        # suppresses a breakpoint you're CURRENTLY sitting on (so a normal
        # step/continue can leave it) — re-posting the SAME address while
        # still paused there can keep that suppression active across the
        # jump we're about to make, causing it to sail through 0x05A8
        # without stopping. An empty set first forces the suppress off.
        client.set_breakpoints([])
        client.set_breakpoints([f"0x{POST_INIT_BP:04X}"])
        client.ram_write(TRAMPOLINE_ADDR, trampoline_for(room_id), execute=True, entry=TRAMPOLINE_ADDR, verify=False)
        client.wait_paused_at(POST_INIT_BP)

        raw = client.ram_read(ENTITY_BASE, ENTITY_COUNT * ENTITY_SIZE)
        entities = []
        verified = True
        for i in range(ENTITY_COUNT):
            e = raw[i * ENTITY_SIZE:(i + 1) * ENTITY_SIZE]
            t = e[0]
            if t == 0:
                continue
            room = e[8]
            if i != 1 and room != (room_id & 0xFF):
                # slot 1 (the 2nd fixed template entity) keeps its own
                # independent room field, unrelated to the teleport target —
                # not a verification failure, see fn_init_room_selection.
                verified = False
            entities.append({
                "slot": i,
                "type": f"0x{t:02x}",
                "label": KNOWN_TYPES.get(t, "?"),
                "grid": [f"0x{e[1]:02x}", f"0x{e[2]:02x}", f"0x{e[3]:02x}"],
                "flags": f"0x{e[7]:02x}",
                "room": f"0x{room:02x}",
                "is_decor": t in DECOR_TYPES,
                "is_wall": t in WALL_TYPES,
            })
        if not verified:
            stale_rooms = sorted({e["room"] for e in entities if e["room"] != f"0x{room_id & 0xFF:02x}"})
            print(f"  retry {attempt + 1}/{max_attempts}: some entities still show stale room(s) {stale_rooms} instead of 0x{room_id:02x}", file=sys.stderr)
            continue

        # tbl_room_connections (0x0147) is valid at this exact point — freshly
        # populated by the fn_load_room_data call that just returned. Dumped
        # raw for offline analysis (see docs/SESSION_SUMMARY.md §6: the
        # room_id nibbles already give the world-map grid position, so this
        # is a cross-check on adjacency, not the map's own coordinate source).
        connections = client.ram_read(CONNECTIONS_ADDR, CONNECTIONS_LEN)

        if hide_player or hide_decor:
            slots = [e["slot"] for e in entities
                     if (hide_player and e["slot"] == 0) or (hide_decor and e["is_wall"])]
            if slots:
                raw = bytearray(raw)
                hide_offscreen(raw, slots)
                client.ram_write(ENTITY_BASE, bytes(raw))

        client.set_breakpoints([])
        if not wait_render_enabled(client):
            print(f"  WARNING: var_render_disabled_flag never cleared within timeout for room 0x{room_id:02x} — "
                  f"screenshot may show stale VRAM (see wait_render_enabled() docstring)", file=sys.stderr)
        if settle_frames > 0:
            advance_frames(client, settle_frames)

        post_settle_room = client.ram_read(ENTITY_BASE, ENTITY_SIZE)[8]
        if post_settle_room != (room_id & 0xFF):
            print(f"  retry {attempt + 1}/{max_attempts}: player room drifted to 0x{post_settle_room:02x} "
                  f"during the {settle_frames}-frame settle (died/respawned?) — redoing the teleport", file=sys.stderr)
            verified = False
            continue
        break

    client.set_breakpoints([])
    png = client.screenshot()

    return {
        "room_id": f"0x{room_id:02x}",
        "verified": verified,
        "entities": entities,
        "screenshot": png,
        "connections": connections.hex(),
    }


def restore(client: Client, original_room_id: int):
    teleport(client, original_room_id)
    client.set_paused(False)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("room", nargs="?", help="single room id (hex like 0x8D or decimal) to peek")
    ap.add_argument("--rooms", default="", help="comma-separated room ids for a sweep")
    ap.add_argument("--all", action="store_true", help="sweep all 128 known room ids")
    ap.add_argument("--out", default=str(Path(__file__).parent / "out"), help="output dir for screenshots + manifest")
    ap.add_argument("--restore", action="store_true", help="teleport back to the original room when done")
    ap.add_argument("--no-screenshot", action="store_true", help="skip saving PNGs (entities only, faster)")
    ap.add_argument("--settle-frames", type=int, default=10,
                    help="EXTRA cosmetic frames to advance after the room is confirmed on real VRAM "
                         "(default 10) — correctness no longer depends on this value: teleport() always "
                         "waits for var_render_disabled_flag to clear first (see wait_render_enabled()), "
                         "this just lets a couple more frames of entity animation play out before the shot")
    ap.add_argument("--hide-player", action="store_true",
                    help="push the player entity out of the visible projection range before the screenshot")
    ap.add_argument("--hide-decor", action="store_true",
                    help="same, for every WALL_TYPES (room-boundary wall segment) entity — for "
                         "map-stitching capture. Deliberately keeps static blocks/'cubes' (0x06/0x07) visible.")
    args = ap.parse_args()

    if args.room:
        room_ids = [int(args.room, 0)]
    elif args.rooms:
        room_ids = [int(x, 0) for x in args.rooms.split(",")]
    elif args.all:
        room_ids = list(ALL_ROOM_IDS)
    else:
        ap.error("give a room id, --rooms, or --all")
        return

    client = Client()
    original_room_id = None
    if args.restore:
        player = client.ram_read(ENTITY_BASE, ENTITY_SIZE)
        original_room_id = player[8]
        print(f"will restore to original room 0x{original_room_id:02X} when done", file=sys.stderr)

    out_dir = Path(args.out)
    out_dir.mkdir(parents=True, exist_ok=True)
    manifest = {}

    def do_one(room_id, label):
        print(f"{label} room 0x{room_id:02X} ...", file=sys.stderr)
        result = teleport(client, room_id, settle_frames=args.settle_frames,
                           hide_player=args.hide_player, hide_decor=args.hide_decor)
        if not result["verified"]:
            print("  WARNING: room-field mismatch on some entities — teleport may have failed", file=sys.stderr)
        entry = {
            "verified": result["verified"],
            "entities": [e for e in result["entities"]],
            "connections_0147": result["connections"],
        }
        if not args.no_screenshot:
            fname = out_dir / f"room_0x{room_id:02x}.png"
            fname.write_bytes(result["screenshot"])
            entry["screenshot"] = fname.name
        n_decor = sum(1 for e in result["entities"] if e["is_decor"])
        print(f"  -> {len(result['entities'])} entities ({n_decor} decor, verified={result['verified']})", file=sys.stderr)
        return entry

    try:
        for idx, room_id in enumerate(room_ids):
            manifest[f"0x{room_id & 0xFF:02x}"] = do_one(room_id, f"[{idx + 1}/{len(room_ids)}]")

        # Straggler pass: even with retries inside teleport(), a room can
        # still come out unverified (see notes/2026-08-07-room-teleport-tool-validated.md
        # and server-issues-to-fix.md — a probabilistic server-side race,
        # not fixed by more attempts alone every time). Re-attempt just the
        # ones that failed, a couple more full passes, rather than silently
        # shipping a manifest with known-bad entries.
        for round_n in range(2):
            stragglers = [rid for rid in room_ids if not manifest[f"0x{rid & 0xFF:02x}"]["verified"]]
            if not stragglers:
                break
            print(f"straggler pass {round_n + 1}: retrying {len(stragglers)} unverified room(s): {[hex(r) for r in stragglers]}", file=sys.stderr)
            for room_id in stragglers:
                manifest[f"0x{room_id & 0xFF:02x}"] = do_one(room_id, "  [straggler]")
        remaining = [rid for rid in room_ids if not manifest[f"0x{rid & 0xFF:02x}"]["verified"]]
        if remaining:
            print(f"WARNING: {len(remaining)} room(s) never verified after all retries: {[hex(r) for r in remaining]}", file=sys.stderr)
    finally:
        if args.restore and original_room_id is not None:
            print(f"restoring to 0x{original_room_id:02X}", file=sys.stderr)
            restore(client, original_room_id)
        else:
            client.set_paused(False)

    manifest_path = out_dir / "rooms_manifest.json"
    manifest_path.write_text(json.dumps(manifest, indent=2))
    print(f"Done. Manifest: {manifest_path}", file=sys.stderr)


if __name__ == "__main__":
    main()
