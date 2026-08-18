#!/usr/bin/env python3
"""Nettoyage automatique des descriptions de asm/symbols.json : retire la
narration d'investigation (dates, "voir notes/...", statuts en gras,
references a l'utilisateur/la session) pour ne garder que le fait
technique. Produit un candidat 'long' + 'short' par entree, imprime le
resultat pour revue avant application definitive (voir migrate_symbols.py).
"""
import json
import re
import sys

DATE = r"20\d\d-\d\d-\d\d"

# Parentheses dont TOUT le contenu n'est que narration (contient une date,
# ou uniquement des mots de narration) -- a supprimer entierement.
NARRATIVE_PAREN = re.compile(
    r"\(([^()]*?)\)"
)

def _accent_variants(word):
    """genere les variantes accentuees/non-accentuees usuelles pour les
    marqueurs qui existent sous les deux formes dans le corpus (desc de
    symbols.json souvent sans accent, docs/SYMBOLS.md toujours avec)."""
    subs = {"E": "[EÉÈ]", "A": "[AÀÂ]"}
    out = ""
    for ch in word:
        out += subs.get(ch, ch)
    return out


NARRATIVE_WORDS_BASE = [
    "CONFIRME EMPIRIQUEMENT PAR L'UTILISATEUR", "CONFIRME PAR L'UTILISATEUR",
    "CONFIRME EMPIRIQUEMENT", "CONFIRME NUMERIQUEMENT", "CONFIRME EN DIRECT",
    "CONFIRME INDEPENDANT", "CONFIRME",
    "RESOLU EN ENTIER", "RESOLU PAR CALCUL ET CONFIRME EMPIRIQUEMENT",
    "RESOLU", "NOUVELLE DECOUVERTE", "DECOUVERTE", "CORRECTION", "PRECISE",
    "PRECISION", "NOUVEAU", "NOUVELLE", "BONUS NON CHERCHE", "BONUS",
    "REVISE", "MIS A JOUR", "MISE A JOUR", "SUITE LE", "ETAPE 2",
    "VALIDE EMPIRIQUEMENT", "VALIDATION PAR REASSEMBLAGE", "CORRIGE",
    "UPGRADE", "RAPPEL IMPORTANT", "ATTENTION", "IMPORTANT", "RESUME",
]
NARRATIVE_WORDS = NARRATIVE_WORDS_BASE + [_accent_variants(w) for w in NARRATIVE_WORDS_BASE]

USER_PHRASES = [
    r"\s*(,\s*)?(explicitement\s+)?par\s+l'utilisateur\b",
    r"question explicite de l'utilisateur",
    r"sur demande (explicite )?de l'utilisateur",
    r"retour utilisateur",
    r"[àa] la demande (explicite )?de l'utilisateur",
    r"l'utilisateur (a )?(confirm[ée]|propos[ée]|signal[ée]|demand[ée])",
    r"cette session\b", r"cette semaine\b", r"la session pr[ée]c[ée]dente\b",
    r"session utilisateur\b",
]

DOC_REF = re.compile(
    r"[Vv]oir\s+(notes|docs|asm)/[^,.;|]*[.|]?|"
    r"[Cc]f\.?\s+(notes|docs|asm)/[^,.;|]*[.|]?|"
    r"[Vv]oir\s+`(notes|docs|asm)/[^`]*`",
)

# Marqueurs qui rendent une clause ENTIEREMENT non technique (citation de
# doc, resolution d'une ancienne entree...) -- la clause entiere est
# supprimee plutot que d'essayer de la nettoyer mot a mot.
CLAUSE_KILL = re.compile(
    r"\.md\b|notes/|docs/SYMBOLS|docs/SESSION_SUMMARY|docs/MEMORY_MAP|"
    r"docs/README|asm/README|"
    r"RESOUT l'ancienne|RESOUT la citation|[Dd]eja cit[ée]e? sans nom|"
    r"jamais formalis[ée]e? en symbole avant",
)


def strip_dead_clauses(text):
    # decoupe en clauses par '. ' et ' -- ', en gardant les separateurs
    parts = re.split(r"(\. |\s--\s)", text)
    kept = []
    for i in range(0, len(parts), 2):
        clause = parts[i]
        sep = parts[i + 1] if i + 1 < len(parts) else ""
        if CLAUSE_KILL.search(clause):
            continue
        kept.append(clause + sep)
    out = "".join(kept)
    # une clause supprimee en tete laisse parfois un separateur orphelin
    out = re.sub(r"^(\. |--\s)+", "", out)
    return out


def strip_narrative_parens(text):
    def repl(m):
        inner = m.group(1)
        if re.search(DATE, inner):
            return ""
        low = inner.upper()
        if "UTILISATEUR" in low and len(inner) < 60:
            return ""
        if any(w in low for w in NARRATIVE_WORDS) and len(inner) < 60:
            return ""
        return m.group(0)
    # repeat: nested parens resolved outer-in is fine, single pass usually enough
    prev = None
    while prev != text:
        prev = text
        text = NARRATIVE_PAREN.sub(repl, text)
    return text


def clean(desc):
    t = desc
    # markdown bold/code-span markers -> plain text (pas de markdown dans
    # un commentaire ASM)
    t = t.replace("**", "")
    t = t.replace("`", "")
    # drop clauses that are entirely doc-citation/meta, not technical fact
    t = strip_dead_clauses(t)
    # remove doc/notes references (voir notes/x.md, cf. docs/y.md, etc.)
    t = DOC_REF.sub("", t)
    # remove parens that are purely narrative (contain a date or narrative word)
    t = strip_narrative_parens(t)
    # remove bare dates left over (e.g. "le 2026-08-13")
    t = re.sub(r"\ble\s+" + DATE, "", t)
    t = re.sub(DATE, "", t)
    # remove leading narrative marker words (start of string or after ". "/" -- ")
    marker_alt = "|".join(sorted(NARRATIVE_WORDS, key=len, reverse=True))
    t = re.sub(r"(^|(?<=[.:]\s)|(?<=--\s))(" + marker_alt + r")\b\s*[:.]?\s*", "", t)
    # user-collaboration phrasing
    for pat in USER_PHRASES:
        t = re.sub(pat, "", t, flags=re.IGNORECASE)
    # dernier recours : toute mention residuelle de "l'utilisateur"/
    # "utilisateur" (adjectif de collaboration, jamais un terme technique
    # dans ce corpus) -- retrait brut du mot, la grammaire environnante
    # reste lisible dans l'immense majorite des cas rencontres.
    t = re.sub(r"\bde l'utilisateur\b", "", t, flags=re.IGNORECASE)
    t = re.sub(r"\bl'utilisateur\b", "", t, flags=re.IGNORECASE)
    t = re.sub(r"\butilisateur\b", "", t, flags=re.IGNORECASE)
    # cleanup artifacts: stray "()" "( )" "--  --" double spaces, leading punctuation
    t = re.sub(r"\(\s*[+\-]?\s*\)", "", t)
    t = re.sub(r"--\s*--", "--", t)
    t = re.sub(r"\s{2,}", " ", t)
    t = re.sub(r"^[\s:.,\-]+", "", t)
    t = re.sub(r"\(\s*[:,]\s*", "(", t)
    t = re.sub(r"\s+([.,;:])", r"\1", t)
    t = re.sub(r"^[A-Z]\)\s*", "", t)  # stray leftover close-paren fragments
    t = t.strip()
    # capitalize first letter for readability
    if t and t[0].islower():
        t = t[0].upper() + t[1:]
    return t


MAXLEN = 140


def _balanced(s):
    return s.count("(") == s.count(")")


def make_short(long_text):
    # first sentence up to first ". " or " -- " (whichever earlier)
    cut_candidates = []
    m = re.search(r"\.\s", long_text)
    if m:
        cut_candidates.append(m.start() + 1)
    m2 = re.search(r"\s--\s", long_text)
    if m2:
        cut_candidates.append(m2.start())
    if cut_candidates:
        cut = min(cut_candidates)
        short = long_text[:cut].strip().rstrip(".")
    else:
        short = long_text.strip()

    if len(short) <= MAXLEN and _balanced(short):
        return short

    # trop long (ou parenthese non fermee, ex: coupe a l'interieur d'une
    # incise) -- retomber sur le dernier point de coupe raisonnable qui
    # laisse des parentheses equilibrees, sans jamais ajouter de "..."
    # (un titre incomplet sans points de suspension reste plus propre
    # qu'une coupe qui donne l'impression que la phrase continue).
    best = None
    for m3 in re.finditer(r"[,;]\s|\s--\s", long_text[:MAXLEN + 40]):
        cand = long_text[: m3.start()].strip()
        if cand and _balanced(cand) and len(cand) <= MAXLEN:
            best = cand
    if best:
        return best.rstrip(".,;:")
    # dernier recours: couper au dernier espace avant MAXLEN, en reculant
    # jusqu'a retrouver des parentheses equilibrees
    cut = long_text.rfind(" ", 0, MAXLEN)
    while cut > 0 and not _balanced(long_text[:cut]):
        cut = long_text.rfind(" ", 0, cut)
    if cut > 0:
        return long_text[:cut].strip().rstrip(".,;:")
    return long_text[:MAXLEN].strip()


def main():
    d = json.load(open("asm/symbols.json"))
    out = []
    for s in d["symbols"]:
        long_ = clean(s["desc"])
        short_ = make_short(long_)
        out.append((s["addr"], s["name"], short_, long_))
    for addr, name, short_, long_ in out:
        print(f"=== {addr} {name} ===")
        print("SHORT:", short_)
        print("LONG: ", long_)
        print()


if __name__ == "__main__":
    main()
