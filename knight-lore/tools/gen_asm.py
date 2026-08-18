#!/usr/bin/env python3
"""Générateur mécanique de source ASM annoté pour Knight Lore CPC.

Contrairement à tools/disasm.py (désassemblage brut), ce script produit
du source directement inséré dans asm/code/*.asm et asm/data/*.asm :

- désassemble linéairement les routines de type "code" au statut
  `confirmed` et substitue les noms symboliques dans les opérandes
  (call/jp/jr/ld (nnnn)/ld hl,nnnn -> nom si connu dans asm/symbols.json,
  sinon #nnnn) ;
- pour les symboles `hypothesis`/`unknown` et les tables sans taille
  confirmée : émet seulement un label + commentaire, jamais de code
  inventé ;
- pour tout octet non couvert par un symbole connu : `defb` réel (lu en
  direct sur l'émulateur), 16 par ligne, commenté "non désassemblé" ;
- ne descend jamais dans les zones réservées (RAM de travail, cf.
  reserved_ram_regions) : celles-ci deviennent un simple `ds`.

Le source généré ne porte PAS l'adresse ni les octets machine à chaque
ligne (asm/symbols.json + asm/labels.txt gardent cette information si
besoin) : seuls le label et le commentaire explicatif (`short`/`long` du
symbole) sont insérés en tête de chaque bloc.

Source RAM résolue automatiquement par tools/ram_source.py : émulateur live
(127.0.0.1:8765, même API que tools/disasm.py) si accessible, sinon repli
transparent sur le dump statique extra/dump_ref.bin (voir
docs/METHODOLOGY.md section 12 -- un message sur stderr indique laquelle a
servi). Aucune instruction n'est jamais fabriquée dans les deux cas : tout
octet émis vient d'une lecture RAM réelle (live ou capturée). Si ni l'un ni
l'autre n'est disponible, message d'erreur expliquant comment régénérer le
dump (tools/export_ram_dump.py, émulateur requis pour cette étape unique).

Usage:
    gen_asm.py <start_hex> <end_hex>   -- génère le listing pour [start,end)
"""
import sys, os, json, re, bisect, textwrap

sys.path.insert(0, "/var/home/siko/Code/Amspirit/amspirit-lite/tools/mcp-emulator")
import z80dis
from ram_source import fetch_ram

HEXP = "#"
SYMBOLS_PATH = os.path.join(os.path.dirname(__file__), "..", "asm", "symbols.json")
COMMENT_WIDTH = 72

OFF_MAP = {
    0x00: "off_type", 0x01: "off_grid_x", 0x02: "off_grid_y", 0x03: "off_grid_z_or_offset",
    0x04: "off_bbox_w", 0x05: "off_bbox_h", 0x06: "off_bbox_d", 0x07: "off_flags",
    0x08: "off_room_number", 0x0C: "off_cooldown_or_collision_flags", 0x0D: "off_state_flags_2",
    0x10: "off_transform_step_counter", 0x12: "off_proj_offset_x", 0x13: "off_proj_offset_y",
    0x14: "off_screen_w", 0x15: "off_screen_h", 0x16: "off_screen_x", 0x17: "off_screen_y",
    0x18: "off_screen_w_prev", 0x19: "off_screen_h_prev", 0x1A: "off_screen_x_prev", 0x1B: "off_screen_y_prev",
    0x1C: "off_type_mirror_plus_10", 0x1D: "off_pending_grid_x", 0x1E: "off_pending_grid_y",
    0x1F: "off_room_transition_extra", 0x23: "off_busy_flag",
}

# Uniquement hex MAJUSCULE : z80dis rend les litteraux hex en majuscule
# et les noms de registres en minuscule (de/af/bc/... seraient sinon pris
# pour des nibbles hexadecimaux valides -- bug reel rencontre au premier
# essai, corrige ici).
OPERAND_TOKEN = re.compile(
    r'(i[xy]\+)([0-9A-F]{2})(?![0-9A-F])'
    r'|(?<![0-9A-F])([0-9A-F]{4})(?![0-9A-F])'
    r'|(?<![0-9A-F])([0-9A-F]{2})(?![0-9A-F])'
)


def load_symtab():
    with open(SYMBOLS_PATH) as f:
        return json.load(f)


def a(hexstr):
    return int(hexstr, 16)


def build_operand_map(symtab):
    m = {}
    for k, v in symtab.get("operand_symbols", {}).items():
        if k.startswith("_"):
            continue
        m[a(k)] = v
    for s in symtab["symbols"]:
        if s.get("name"):
            m[a(s["addr"])] = s["name"]
    return m


def substitute_ops(ops, operand_map):
    if not ops:
        return ops

    def repl(m):
        if m.group(1):  # (ix+NN) / (iy+NN)
            off = int(m.group(2), 16)
            name = OFF_MAP.get(off)
            return m.group(1) + (name if name else HEXP + m.group(2))
        if m.group(3):  # litteral 16 bits
            val = int(m.group(3), 16)
            name = operand_map.get(val)
            return name if name else HEXP + m.group(3)
        return HEXP + m.group(4)  # litteral 8 bits

    return OPERAND_TOKEN.sub(repl, ops)


def is_block_end(mnem, ops):
    if mnem == "ret":
        return not ops
    if mnem in ("jp", "jr"):
        return "," not in (ops or "")
    if mnem in ("reti", "retn"):
        return True
    return False


JUMP_MNEMS = ("jp", "jr", "call", "djnz")
JUMP_TARGET = re.compile(r'^(?:[A-Za-z]+,)?([0-9A-F]{4})$')


def jump_target(mnem, ops):
    """Adresse cible d'un jp/jr/call/djnz, ou None (cible non litterale,
    ex. `jp (hl)`, ou instruction sans rapport)."""
    if mnem not in JUMP_MNEMS or not ops:
        return None
    m = JUMP_TARGET.match(ops)
    return int(m.group(1), 16) if m else None


def decode_code_instrs(mem, pos, nxt, decode_full_range):
    """Decode [pos, nxt) comme des instructions z80 ; retourne la liste
    (addr, mnem, ops, size) et la position finale. Pure fonction des
    octets memoire (independante de operand_map/labels), reutilisable a
    l'identique pour la passe de reperage des cibles de saut et pour la
    passe d'emission finale."""
    instrs = []
    cur = pos
    while cur < nxt:
        try:
            mnem, ops, size = z80dis.decode(mem, cur)
        except Exception:
            break
        if size <= 0:
            break
        instrs.append((cur, mnem, ops, size))
        end = is_block_end(mnem, ops)
        cur += size
        if end and not decode_full_range:
            break
    return instrs, cur


def collect_jump_labels(mem, symtab, operand_map, start, end):
    """Passe de reperage : decode tout le code confirmed de [start, end)
    et attribue un label `loc_XXXX` a toute cible de jp/jr/call/djnz qui
    tombe pile sur une adresse d'instruction decodee de cette plage mais
    n'a pas deja de nom dans operand_map (cas typique : boucle interne
    sans symbole dedie). Sans cela gen_asm émettrait l'adresse en dur
    (#XXXX), ce qui casse la relogeabilite du listing."""
    all_syms = sorted(symtab["symbols"], key=lambda s: a(s["addr"]))
    all_addrs = [a(s["addr"]) for s in all_syms]
    syms = sorted(
        (s for s in symtab["symbols"] if start <= a(s["addr"]) < end),
        key=lambda s: a(s["addr"]),
    )
    reserved = [
        (a(r["start"]), a(r["end"]))
        for r in symtab.get("reserved_ram_regions", [])
        if a(r["start"]) < end and a(r["end"]) > start
    ]
    instr_addrs = {}
    pos = start
    idx = 0
    while pos < end:
        res = next((r for r in reserved if r[0] <= pos < r[1]), None)
        if res:
            pos = min(res[1], end)
            continue
        if idx < len(syms) and a(syms[idx]["addr"]) == pos:
            sym = syms[idx]
            if idx + 1 < len(syms):
                nxt = a(syms[idx + 1]["addr"])
            else:
                gidx = bisect.bisect_right(all_addrs, pos)
                nxt = all_addrs[gidx] if gidx < len(all_addrs) and all_addrs[gidx] <= end else end
            for r in reserved:
                if pos < r[0] < nxt:
                    nxt = r[0]
            if sym["type"] == "code" and sym["status"] == "confirmed":
                instrs, newpos = decode_code_instrs(mem, pos, nxt, sym.get("decode_full_range"))
                for addr, mnem, ops, _size in instrs:
                    instr_addrs[addr] = (mnem, ops)
                pos = newpos
            else:
                pos = _data_end(sym, pos)
            idx += 1
            continue
        nxt = end
        if idx < len(syms):
            nxt = min(nxt, a(syms[idx]["addr"]))
        for r in reserved:
            if pos < r[0] < nxt:
                nxt = r[0]
        pos = nxt

    labels = {}
    for _addr, (mnem, ops) in instr_addrs.items():
        tgt = jump_target(mnem, ops)
        if tgt is None or tgt in operand_map or tgt not in instr_addrs:
            continue
        if tgt not in labels:
            labels[tgt] = f"loc_{tgt:04X}"
    return labels


def _data_end(sym, pos):
    if sym.get("literal_bytes"):
        return pos + len(sym["literal_bytes"])
    if sym.get("literal_words"):
        return pos + 2 * len(sym["literal_words"])
    if sym.get("count"):
        return pos + sym["count"] * sym.get("elem_size", 1)
    return pos


def comment_block(status, short, long_):
    """En-tete de commentaire pour un label : statut (seulement si pas
    confirmed, pour ne pas alourdir le cas normal) + explication complete
    (long, ou short si long est vide/identique), repliee en plusieurs
    lignes."""
    tag = f"[{status}] " if status != "confirmed" else ""
    text = long_ or short or ""
    if not text:
        return []
    wrapped = textwrap.wrap(tag + text, COMMENT_WIDTH)
    return [f"        ; {line}" for line in wrapped]


def defb_dump(mem, start, end, comment=None):
    lines = []
    if comment:
        lines.append(f"        ; {comment}")
    pos = start
    while pos < end:
        chunk_end = min(pos + 16, end)
        vals = ",".join(f"{HEXP}{mem[i]:02X}" for i in range(pos, chunk_end))
        lines.append(f"        defb {vals}")
        pos = chunk_end
    return lines


def defw_dump(mem, start, count):
    lines = []
    pos = start
    for _ in range(count):
        val = mem[pos] | (mem[pos + 1] << 8)
        lines.append(f"        defw {HEXP}{val:04X}")
        pos += 2
    return lines, pos


def emit_symbol(mem, sym, pos, nxt, operand_map, jump_labels):
    name = sym.get("name")
    label = name if name else f"unk_{pos:04X}"
    status = sym["status"]
    header = [f"{label}:"] + comment_block(status, sym.get("short"), sym.get("long"))
    kind = sym["type"]

    if kind == "data":
        if sym.get("literal_bytes"):
            vals = ",".join(f"{HEXP}{b}" for b in sym["literal_bytes"])
            return pos + len(sym["literal_bytes"]), header + [f"        defb {vals}"]
        if sym.get("literal_words"):
            lines = list(header)
            for w in sym["literal_words"]:
                lines.append(f"        defw {HEXP}{w}")
            return pos + 2 * len(sym["literal_words"]), lines
        if sym.get("count"):
            elem_size = sym.get("elem_size", 1)
            count = sym["count"]
            if elem_size == 2:
                lines, endpos = defw_dump(mem, pos, count)
                return endpos, header + lines
            else:
                size = count * elem_size
                return pos + size, header + defb_dump(mem, pos, pos + size)
        # extent inconnue : juste le label, le contenu tombe en "non desassemble"
        return pos, header

    # kind == code
    if status != "confirmed":
        return pos, header

    # decode_code_instrs porte les regles de fin de bloc (ret/jp
    # inconditionnel = fin, sauf decode_full_range explicite -- cf.
    # commentaire historique sur fn_check_collisions/#27FE) ; ici on ne
    # fait plus qu'emettre le texte, une cible de saut interne sans nom
    # recoit le label `loc_XXXX` genere par collect_jump_labels pour que
    # le jp/jr correspondant ne reference jamais une adresse en dur.
    lines = list(header)
    instrs, cur = decode_code_instrs(mem, pos, nxt, sym.get("decode_full_range"))
    for addr, mnem, ops, _size in instrs:
        label = jump_labels.get(addr)
        if label:
            lines.append(f"{label}:")
        sub_ops = substitute_ops(ops, operand_map)
        text = f"{mnem}    {sub_ops}".rstrip()
        lines.append(f"        {text}")
    return cur, lines


def gen_range(mem, symtab, operand_map, jump_labels, start, end):
    all_syms = sorted(symtab["symbols"], key=lambda s: a(s["addr"]))
    all_addrs = [a(s["addr"]) for s in all_syms]
    syms = sorted(
        (s for s in symtab["symbols"] if start <= a(s["addr"]) < end),
        key=lambda s: a(s["addr"]),
    )
    reserved = [
        (a(r["start"]), a(r["end"]), r["label"], r["short"])
        for r in symtab.get("reserved_ram_regions", [])
        if a(r["start"]) < end and a(r["end"]) > start
    ]
    lines = [f"        org {HEXP}{start:04X}"]
    pos = start
    idx = 0
    while pos < end:
        res = next((r for r in reserved if r[0] <= pos < r[1]), None)
        if res:
            r_end = min(res[1], end)
            lines.append(f"{res[2]}:")
            lines.extend(f"        ; {ln}" for ln in textwrap.wrap(res[3], COMMENT_WIDTH))
            lines.append(f"        ds {HEXP}{r_end - pos:04X}")
            pos = r_end
            continue

        if idx < len(syms) and a(syms[idx]["addr"]) == pos:
            sym = syms[idx]
            if idx + 1 < len(syms):
                nxt = a(syms[idx + 1]["addr"])
            else:
                # Dernier symbole de CETTE plage (decoupage par fichier) :
                # utiliser le symbole global suivant s'il existe et ne
                # depasse pas `end` -- le decoupage de knight_lore.asm est
                # contigu, donc c'est normalement le meme symbole que
                # celui qui ouvre le fichier suivant.
                gidx = bisect.bisect_right(all_addrs, pos)
                nxt = all_addrs[gidx] if gidx < len(all_addrs) and all_addrs[gidx] <= end else end
            for r in reserved:
                if pos < r[0] < nxt:
                    nxt = r[0]
            newpos, out = emit_symbol(mem, sym, pos, nxt, operand_map, jump_labels)
            lines.extend(out)
            pos = newpos
            idx += 1
            continue

        nxt = end
        if idx < len(syms):
            nxt = min(nxt, a(syms[idx]["addr"]))
        for r in reserved:
            if pos < r[0] < nxt:
                nxt = r[0]
        lines.extend(defb_dump(mem, pos, nxt, comment="non désassemblé"))
        pos = nxt
    return lines


def main():
    if len(sys.argv) != 3:
        print(__doc__)
        sys.exit(1)
    start = int(sys.argv[1], 16)
    end = int(sys.argv[2], 16)
    symtab = load_symtab()
    operand_map = build_operand_map(symtab)
    mem = fetch_ram(0, 65536)
    # Passe 1 : repere les cibles de jp/jr/call/djnz internes sans nom
    # existant (typiquement des boucles) et leur attribue un label
    # `loc_XXXX`, insere ci-dessous dans le code par emit_symbol -- sans
    # quoi le saut correspondant serait emis avec une adresse en dur,
    # non relogeable.
    jump_labels = collect_jump_labels(mem, symtab, operand_map, start, end)
    operand_map_ext = {**operand_map, **jump_labels}
    for line in gen_range(mem, symtab, operand_map_ext, jump_labels, start, end):
        print(line)


if __name__ == "__main__":
    main()
