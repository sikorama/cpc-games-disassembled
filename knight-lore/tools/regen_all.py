#!/usr/bin/env python3
"""Régénère tous les fichiers de asm/code/*.asm et asm/data/*.asm.

Remplace les invocations manuelles répétées de tools/gen_asm.py décrites
dans asm/README.md : chaque fichier généré porte déjà sa plage dans son
en-tête (ligne 2, `plage #DEBUT-#FIN`) -- ce script la relit, régénère le
corps (tout ce qui suit les 5 lignes d'en-tête fixes) via les mêmes
fonctions que gen_asm.py, et réécrit le fichier à l'identique de ce que
produirait `gen_asm.py <debut> <fin>` collé après l'en-tête existant.

Une seule lecture RAM (live ou extra/dump_ref.bin, cf. ram_source.py) et
une seule passe de repérage des labels de saut générés (loc_XXXX) par
fichier -- pas de fetch répété.

Par défaut : dry-run, affiche pour chaque fichier si le contenu régénéré
diffère (et de combien de lignes). Passer --apply pour réécrire les
fichiers qui diffèrent. --file <chemin> limite à un seul fichier.

Usage:
    regen_all.py [--apply] [--file asm/code/xxx.asm]
"""
import sys, os, re, glob

sys.path.insert(0, os.path.dirname(__file__))
import gen_asm

ASM_ROOT = os.path.join(os.path.dirname(__file__), "..", "asm")
HEADER_LINES = 5  # les 5 lignes fixes avant le "org #..." régénéré
RANGE_RE = re.compile(r"plage #([0-9A-Fa-f]{4})-#([0-9A-Fa-f]{4})")


def discover_files():
    paths = sorted(glob.glob(os.path.join(ASM_ROOT, "code", "*.asm"))) + sorted(
        glob.glob(os.path.join(ASM_ROOT, "data", "*.asm"))
    )
    entries = []
    for path in paths:
        with open(path) as f:
            lines = f.readlines()
        m = RANGE_RE.search(lines[1]) if len(lines) > 1 else None
        if not m:
            print(f"[skip] {path} : pas de \"plage #DEBUT-#FIN\" en ligne 2", file=sys.stderr)
            continue
        entries.append((path, int(m.group(1), 16), int(m.group(2), 16), lines))
    return entries


def check_contiguity(entries):
    by_start = sorted(entries, key=lambda e: e[1])
    for (path_a, _sa, ea, _la), (path_b, sb, _eb, _lb) in zip(by_start, by_start[1:]):
        if ea != sb:
            print(
                f"[avertissement] trou/chevauchement entre {path_a} (fin #{ea:04X}) "
                f"et {path_b} (debut #{sb:04X})",
                file=sys.stderr,
            )


def regen_one(mem, symtab, operand_map, path, start, end, header_lines):
    jump_labels = gen_asm.collect_jump_labels(mem, symtab, operand_map, start, end)
    operand_map_ext = {**operand_map, **jump_labels}
    body = gen_asm.gen_range(mem, symtab, operand_map_ext, jump_labels, start, end)
    return "".join(header_lines[:HEADER_LINES]) + "\n".join(body) + "\n"


def main():
    args = sys.argv[1:]
    apply_ = "--apply" in args
    args = [a for a in args if a != "--apply"]
    only_file = None
    if "--file" in args:
        i = args.index("--file")
        only_file = os.path.abspath(args[i + 1])

    entries = discover_files()
    if only_file:
        entries = [e for e in entries if os.path.abspath(e[0]) == only_file]
        if not entries:
            print(f"fichier non trouve parmi les .asm generes: {only_file}", file=sys.stderr)
            sys.exit(1)
    check_contiguity(entries)

    symtab = gen_asm.load_symtab()
    operand_map = gen_asm.build_operand_map(symtab)
    mem = gen_asm.fetch_ram(0, 65536)

    changed = 0
    for path, start, end, header_lines in entries:
        new_content = regen_one(mem, symtab, operand_map, path, start, end, header_lines)
        with open(path) as f:
            old_content = f.read()
        if new_content == old_content:
            print(f"[ok]      {path} (inchangé)")
            continue
        changed += 1
        old_n, new_n = old_content.count("\n"), new_content.count("\n")
        if apply_:
            with open(path, "w") as f:
                f.write(new_content)
            print(f"[écrit]   {path} ({old_n} -> {new_n} lignes)")
        else:
            print(f"[diff]    {path} ({old_n} -> {new_n} lignes) -- relancer avec --apply")

    if not apply_ and changed:
        print(f"\n{changed} fichier(s) différent(s) -- dry-run, rien n'a été écrit.")


if __name__ == "__main__":
    main()
