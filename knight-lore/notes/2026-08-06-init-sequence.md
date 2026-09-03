# Session — Poursuite du désassemblage après la collision (0x2988+)

## Contexte

Suite de `notes/2026-08-06-collision.md`. Après la découverte de
`0x28B7` (vraie routine de scan input), poursuite de la lecture linéaire
au-delà de `0x2988`.

## Frontières code/données identifiées

Deux zones de données statiques traversées avant de retrouver du vrai
code, confirmées par relecture brute (`ram_read`) plutôt que par la
désassemblage aveugle (cf. méthodologie section 5) :

1. **`0x2988-0x29B3`** : fin des tables de masques joystick (5e table)
   + une petite table finale `(0,0xFF),(1,0xFF),...,(8,0xFF),0xFF` —
   rôle exact non déterminé (peut-être une table de "aucune ligne
   clavier" utilisée comme valeur par défaut/sentinelle).
2. **`0x29EB-0x2A22`** (0x38 = 56 octets) : template de données copié
   par `LDIR` depuis `0x29B4` (`LD HL,29EB` / `LD DE,00D7` / `BC=0x38` /
   `LDIR`) — donc ce bloc est **copié vers la base du tableau
   d'entités** (`0x00D7`) lors d'une init. 56 octets = exactement 2×28
   (taille de structure confirmée précédemment) — **initialise
   probablement les 2 premières entités** (joueur + une autre) avec des
   valeurs de départ fixes à chaque (re)lancement de partie/niveau.

## 0x29B4-0x2A63 — Routine d'initialisation (probable reset de partie/niveau)

**Statut : confirmed** par désassemblage direct, **hypothesis** sur le
rôle exact (reset complet vs reset de room).

```
29B4  21EB29     ld     hl,29EB     ; source = template de données
29B7  11D700     ld     de,00D7     ; dest = base du tableau d'entités
29BA  D5         push   de
29BB  DDE1       pop    ix
29BD  013800     ld     bc,0038     ; 0x38 = 56 octets = 2 structures de 28 octets
29C0  EDB0       ldir              ; copie le template -> initialise 2 entités
29C2  AF         xor    a
29C3  327700     ld     (0077),a   ; remet (0077) à 0
29C6  218000     ld     hl,0080
29C9  35         dec    (hl)       ; décrémente (0080)
29CA  FAFB12     jp     m,12FB     ; si négatif -> saute ailleurs (0x12FB, non exploré)
29CD  3AFA1C     ld     a,(1CFA)
29D0  0F         rrca
29D1  0F         rrca
29D2  0F         rrca
29D3  E620       and    20
29D5  4F         ld     c,a
29D6  DD7E10     ld     a,(ix+10)
29D9  E61F       and    1F
29DB  81         add    a,c
29DC  DD7710     ld     (ix+10),a  ; combine (1CFA) et (ix+10), réécrit (ix+10)
29DF  DD7E2C     ld     a,(ix+2C)  ; <-- offset +2C = 44, DEPASSE la taille de
                                   ; structure connue (28 octets/entité) --
                                   ; soit cette routine indexe la 2e entité du
                                   ; bloc copié (IX+28+16 = IX+44, cohérent avec
                                   ; "2e entité, champ +16"), soit il y a un
                                   ; champ de structure encore inconnu
29E2  E60F       and    0F
29E4  81         add    a,c
29E5  C620       add    a,20
29E7  DD772C     ld     (ix+2C),a
29EA  C9         ret
```

**Note sur `(ix+2C)`** : `0x2C = 44 = 28 + 16`. Si IX pointe toujours
sur la base du tableau (`0x00D7`), alors `(ix+2C)` correspond au champ
`+16` (`0x10`) de la DEUXIÈME entité (offset 28 + 16). Cohérent avec
`(ix+10)` traité juste avant pour la première entité — **la routine
traite deux entités consécutives avec la même logique** (probablement
initialisation de la position/orientation projetée de chacune).

### 0x2A32+ — Suite (setup de table par variante + appel de la vraie init de room)

```
2A32  1E21       ld     e,21
2A34  23         inc    hl
2A35  2A11EB     ld     hl,(EB11)    ; lit un pointeur en RAM haute (0xEB11 - table
                                     ; de données de room ? à vérifier, zone très
                                     ; haute jamais visitée jusqu'ici)
2A38  29         add    hl,hl
2A39  010800     ld     bc,0008
2A3C  EDB0       ldir                ; copie 8 octets
2A3E  11072A     ld     de,2A07
2A41  010800     ld     bc,0008
2A44  EDB0       ldir                ; copie encore 8 octets (PATCH DE CODE : la
                                     ; destination 0x2A07 est en pleine zone de
                                     ; code/données qu'on vient de traverser --
                                     ; auto-modification probable de tables
                                     ; utilisées par une routine voisine)
2A46  3E12       ld     a,12
2A48  32FB29     ld     (29FB),a     ; PATCH: écrit 0x12 à l'adresse 0x29FB
2A4B  3E22       ld     a,22
2A4D  32172A     ld     (2A17),a     ; PATCH: écrit 0x22 à l'adresse 0x2A17
2A50  3A6800     ld     a,(0068)
2A53  E603       and    03           ; sélectionne une variante 0-3
2A55  6F         ld     l,a
2A56  2600       ld     h,00
2A58  01642A     ld     bc,2A64      ; table de 4 octets (une par variante)
2A5B  09         add    hl,bc
2A5C  7E         ld     a,(hl)
2A5D  32F329     ld     (29F3),a     ; PATCH: écrit la valeur choisie à 0x29F3
2A60  320F2A     ld     (2A0F),a     ; PATCH: et aussi à 0x2A0F
2A63  C9         ret
```
**Beaucoup de code auto-modifiant** (patchs d'opérandes à plusieurs
adresses dans la zone qu'on vient de traverser) — cohérent avec le
motif déjà repéré dans le pipeline de dessin (`0x2F34`/`0x2F5F`) :
sélection dynamique de variante de comportement selon `(0x0068)` (un
compteur/état global, probablement lié à la progression du jeu ou à la
salle courante).

### 0x2A68+ — Séquence d'initialisation de niveau/room (DÉCOUVERTE CLÉ)

**Statut : confirmed** par désassemblage direct, **hypothesis forte**
sur le rôle "reset de room".

```
2A68  3A7800     ld     a,(0078)
2A6B  A7         and    a
2A6C  2803       jr     z,2A71
2A6E  CD671E     call   1E67         ; si (0078) != 0, routine additionnelle
2A71  CDB72D     call   2DB7         ; efface l'écran complet (routine déjà connue !)
2A74  CD3A2C     call   2C3A         ; ?
2A77  CDFB1D     call   1DFB         ; ?
2A7A  CD8D2B     call   2B8D         ; ?
2A7D  AF         xor    a
2A7E  327500     ld     (0075),a     ; remet à 0 plusieurs compteurs/flags globaux
2A81  327600     ld     (0076),a
2A84  328300     ld     (0083),a
2A87  328500     ld     (0085),a
2A8A  3E01       ld     a,01
2A8C  327D00     ld     (007D),a     ; <-- POSITIONNE LE FLAG DE DÉSACTIVATION DU
                                     ;     RENDU À 1 !! (0x007D est testé dans la
                                     ;     boucle de rendu 0x2DE8 : "si non-zéro,
                                     ;     sort tout de suite" -- donc le rendu
                                     ;     est explicitement DÉSACTIVÉ pendant
                                     ;     cette phase d'initialisation)
2A8F  3ADF00     ld     a,(00DF)
2A92  E601       and    01
2A94  328600     ld     (0086),a
2A97  C39A2A     jp     2A9A
```

**C'est la première fois qu'on voit qui ÉCRIT `(0x007D)`** — confirme
et complète l'hypothèse posée dans `notes/2026-08-06-rendering-engine.md`
("Pourrait être lié à la pause du jeu, un état de transition entre
salles, ou l'écran de mort/de score"). Le contexte (appel à l'effacement
d'écran complet `0x2DB7`, remise à zéro de plusieurs compteurs globaux,
juste après avoir initialisé 2 entités depuis un template figé) est
**fortement cohérent avec une routine de reset de room/niveau** : à
chaque nouvelle salle (ou au lancement d'une partie), le jeu efface
l'écran, réinitialise l'état des 2 premières entités (joueur + une
autre — objet clé de la salle ?), désactive le rendu le temps de tout
remettre en place, puis (présumément, à vérifier plus loin) réactive le
rendu une fois la nouvelle salle prête.

## Prochaines pistes

1. **Désassembler `0x2C3A`, `0x1DFB`, `0x2B8D`, `0x1E67`** — les 4
   sous-routines appelées dans cette séquence d'init, non explorées.
2. **Trouver où `(0x007D)` est remis à 0** (réactivation du rendu après
   l'init) — chercher un `LD (007D),00` ou `XOR A / LD (007D),A`
   ailleurs dans le code.
3. **`(0xEB11)` — RÉSOLU 2026-08-07** : pas un pointeur vers une table
   de définition de room comme supposé ici — l'adresse tombe dans la
   VRAM (bank 3, 0xC000-0xFFFF), confirmé par test empirique
   (`ram_write` → pixel visible à l'écran). Voir `docs/SYMBOLS.md`.
4. Vérifier si `(0x0068)` correspond au numéro de salle/niveau courant
   (cohérent avec son usage en sélecteur de variante 0-3 à `0x2A50`).

## Outils / méthode

- Vérification systématique des frontières code/données par relecture
  brute (`ram_read`) avant d'interpréter un désassemblage qui semble
  produire des motifs improbables (répétition de `nop`, valeurs très
  régulières) — cf. méthodologie section 5, appliquée deux fois dans
  cette section pour confirmer où le vrai code reprend.
