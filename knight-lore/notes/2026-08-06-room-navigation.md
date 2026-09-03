# Session — Navigation entre salles (room transitions) : 0x2B8D, 0x1DFB, 0x2C3A

## Contexte

Suite de `notes/2026-08-06-init-sequence.md`. Désassemblage des 4
sous-routines appelées par `fn_init_room` (0x2A68). **Découverte majeure :
le mécanisme de transition entre salles voisines**, directement utile
pour le futur outil de cartographie automatique du monde évoqué par
l'utilisateur.

## 0x2C3A — Résolution "numéro de room" → position de référence/caméra

**Statut : confirmed** par désassemblage direct, **hypothesis** sur le
rôle exact de chaque champ.

```
2C3A  114701     ld     de,0147     ; DE = base d'une table (0x0147) -- LA MÊME
                                    ; que celle utilisée par 0x1DFB et 0x2BF9 !
2C3D  015D3D     ld     bc,3D5D     ; BC = limite haute de la zone de recherche
2C40  21DD33     ld     hl,33DD     ; HL = table de correspondance room -> données
2C43  7E         ld     a,(hl)
2C44  23         inc    hl
2C45  DDBE08     cp     (ix+08)     ; compare à (ix+08) -- probablement le
                                    ; "numéro de room courant" de l'entité/du jeu
2C48  2818       jr     z,2C62      ; trouvé -> traite l'entrée
2C4A  7E         ld     a,(hl)
2C4B  CF         rst    08          ; HL += A (avance de la taille de l'entrée courante)
2C4C  A7         and    a
2C4D  ED42       sbc    hl,bc       ; teste si HL dépasse la limite BC
2C4F  3003       jr     nc,2C54
2C51  09         add    hl,bc       ; sinon corrige et continue
2C52  18EF       jr     2C43

; --- entrée trouvée ---
2C54  213705     ld     hl,0537     ; (boucle de nettoyage : "0x537 = fin du tableau
                                    ; d'entités" -- efface la table 0x0147 avant
                                    ; de la repeupler, voir plus bas)
2C57  A7         and    a
2C58  ED52       sbc    hl,de
2C5A  C8         ret    z
2C5B  061C       ld     b,1C
2C5D  CD3100     call   0031        ; 0x0031 = routine "remplissage mémoire" vue au
                                    ; tout début (RST/vecteur bas, efface B×0x1C octets)
2C60  18F2       jr     2C54

2C62  46         ld     b,(hl)      ; B = octet suivant de l'entrée trouvée (taille ?)
2C63  23         inc    hl
2C64  7E         ld     a,(hl)
2C65  E607       and    07
2C67  327300     ld     (0073),a   ; (0x0073) = un champ décodé sur 3 bits
2C6A  D5         push   de
2C6B  EB         ex     de,hl
2C6C  1A         ld     a,(de)
2C6D  13         inc    de
2C6E  0F         rrca
2C6F  0F         rrca
2C70  0F         rrca
2C71  E61F       and    1F
2C73  4F         ld     c,a
2C74  87         add    a,a
2C75  81         add    a,c         ; C×3
2C76  21D433     ld     hl,33D4     ; table adjacente à 0x33DD (room->data), ×3 par entrée
2C79  CF         rst    08          ; HL += C×3
2C7A  7E         ld     a,(hl)
2C7B  23         inc    hl
2C7C  327100     ld     (0071),a   ; (0x0071) <- 1er octet  (référence/caméra X ?)
2C7F  7E         ld     a,(hl)
2C80  23         inc    hl
2C81  327200     ld     (0072),a   ; (0x0072) <- 2e octet   (référence/caméra Y ?)
2C84  7E         ld     a,(hl)
2C85  327400     ld     (0074),a   ; (0x0074) <- 3e octet   (?)
2C88  05         dec    b
2C89  05         dec    b
2C8A  EB         ex     de,hl
2C8B  D1         pop    de
2C8C  7E         ld     a,(hl)
2C8D  23         inc    hl
2C8E  FEFF       cp     FF          ; (suite non capturée dans ce relevé -- copie
                                    ; probablement B octets restants vers 0x0147)
```

**Interprétation** : `0x33DD` est une **table indexée par numéro de room**
(`(ix+08)`), chaque entrée ayant une taille variable (`A` = longueur,
utilisé pour l'avance `RST 08`). Une fois l'entrée trouvée, un champ à 3
bits est extrait (`(0x0073)`), et une table sœur `0x33D4` (indexée ×3,
donc probablement des triplets) donne 3 octets stockés dans
`(0x0071)/(0x0072)/(0x0074)` — **très probablement les coordonnées de la
salle dans la carte du monde (X, Y, + un 3e paramètre)**, utilisées comme
référence de caméra/positionnement (cohérent avec l'usage déjà repéré de
`(0x0071)` dans `fn_player_in_view_bounds`, 0x2122).

**Puis la suite (non capturée en un seul appel, à re-vérifier) copie
apparemment des données vers la table `0x0147`** (celle utilisée par
`0x1DFB`/`0x2BF9`) — probablement la **liste des connexions/objets de
la room courante**.

## 0x1DFB — Peuplement d'entités depuis un catalogue d'objets (0x417E-0x429E)

**Statut : confirmed** par désassemblage direct, **hypothesis** sur le
rôle métier.

```
1DFB  110F01     ld     de,010F     ; DE = curseur d'écriture (dans la zone 0x0147+?)
1DFE  D9         exx                ; bascule vers les registres alternatifs
1DFF  FD217E41   ld     iy,417E     ; IY = base d'un catalogue d'objets, pas de 9 octets
1E03  DD4608     ld     b,(ix+08)   ; B = numéro de room courant (même champ que 0x2C3A !)
1E06  FD7E00     ld     a,(iy+00)
1E09  A7         and    a
1E0A  283C       jr     z,1E48      ; entrée vide -> ignore, entrée suivante
1E0C  FD7E08     ld     a,(iy+08)
1E0F  B8         cp     b           ; compare le numéro de room de l'entrée à B
1E10  2036       jr     nz,1E48     ; pas cette room -> ignore
1E12  FDE5       push   iy
1E14  D9         exx
1E15  E1         pop    hl          ; HL = pointeur de l'entrée trouvée (registres normaux)
1E16  E5         push   hl
1E17  7E         ld     a,(hl)      ; copie plusieurs champs vers DE (voir ci-dessous)
1E18  23         inc    hl
1E19  12         ld     (de),a
1E1A  13         inc    de
1E1B..1E1E        inc    hl (×4)    ; saute 4 octets de l'entrée source
1E1F  010300     ld     bc,0003
1E22  EDB0       ldir              ; copie 3 octets supplémentaires
1E24  EB         ex     de,hl
1E25  3605       ld     (hl),05
1E27  23         inc    hl
1E28  3605       ld     (hl),05
1E2A  23         inc    hl
1E2B  360C       ld     (hl),0C
1E2D  23         inc    hl
1E2E  3614       ld     (hl),14     ; écrit 4 constantes fixes (05,05,0C,14) --
                                    ; probablement des dimensions/bounding box
                                    ; par défaut pour un objet nouvellement créé
1E30  23         inc    hl
1E31  EB         ex     de,hl
1E32  7E         ld     a,(hl)      ; copie encore un champ
1E33  23         inc    hl
1E34  12         ld     (de),a
1E35  13         inc    de
1E36  0607       ld     b,07
1E38  CD3100     call   0031        ; efface 7 octets (routine remplissage déjà connue)
1E3B  C1         pop    bc
1E3C  79         ld     a,c
1E3D  12         ld     (de),a
1E3E  13         inc    de
1E3F  78         ld     a,b
1E40  12         ld     (de),a      ; écrit le pointeur original (BC = adresse
                                    ; de l'entrée catalogue) dans la nouvelle
                                    ; structure -- référence arrière vers le
                                    ; "modèle" de l'objet ?
1E41  13         inc    de
1E42  060A       ld     b,0A
1E44  CD3100     call   0031        ; efface 10 octets supplémentaires
1E47  D9         exx

1E48  110900     ld     de,0009
1E4B  FD19       add    iy,de       ; IY += 9 (entrée catalogue suivante)
1E4D  FDE5       push   iy
1E4F  E1         pop    hl
1E50  119E42     ld     de,429E     ; limite = 0x429E (tbl_sprite_dispatch !)
1E53  A7         and    a
1E54  ED52       sbc    hl,de
1E56  38AE       jr     c,1E06      ; tant que IY < 0x429E, continue le parcours
1E58  D9         exx

1E59  214701     ld     hl,0147     ; nettoyage final : efface le reste de 0x0147
1E5C  A7         and    a
1E5D  ED52       sbc    hl,de       ; (DE encore = 0x429E ici -- incohérent avec le
                                    ; commentaire, à revérifier -- possible copie/
                                    ; réutilisation de DE d'un autre contexte)
1E5F  C8         ret    z
1E60  061C       ld     b,1C
1E62  CD3100     call   0031
1E65  18F2       jr     1E59
```

**Interprétation (hypothesis raisonnable)** : `0x417E-0x429E`
(exactement 0x120 = 288 octets = 32 entrées de 9 octets) est un
**catalogue statique d'objets par room** — chaque entrée décrit un objet
présent dans une salle donnée (champ `+08` = numéro de room), et cette
routine "instancie" les objets appartenant à la room courante en les
copiant dans la zone `0x0147+` avec des valeurs par défaut ajoutées
(dimensions `05,05,0C,14`). C'est cohérent avec un système où chaque
salle a un petit nombre d'objets fixes (clés, leviers, blocs spéciaux)
décrits une fois dans une table globale, instanciés seulement quand le
joueur entre dans la salle correspondante — économise la mémoire par
rapport à stocker 128 entités actives en permanence pour tout le monde.

**Confirme aussi** : `0x429E` sert de sentinelle/limite de fin pour CE
catalogue (32 entrées, 0x417E+9×32=0x429E exact) — donc `0x417E-0x429E`
et `tbl_sprite_dispatch` (0x429E+) sont deux tables ADJACENTES et
DISTINCTES en mémoire, la première terminant exactement là où l'autre
commence. Pas une coïncidence — probablement organisées ainsi
volontairement par les développeurs originaux.

## 0x2B8D — Transition de salle (sortie par un bord → entrée dans la salle adjacente)

**Statut : confirmed** par désassemblage direct — **DÉCOUVERTE CLÉ pour
la cartographie automatique du monde**.

```
2B8D  3A7100     ld     a,(0071)    ; référence room courante (X), voir 0x2C3A
2B90  D602       sub    02
2B92  6F         ld     l,a
2B93  3A7200     ld     a,(0072)    ; référence room courante (Y)
2B96  D602       sub    02
2B98  67         ld     h,a         ; HL = référence "voisinage" (ref - 2 sur les 2 axes)

2B99  DD7E01     ld     a,(ix+01)   ; teste la coordonnée X du joueur (ix+01)
2B9C  A7         and    a
2B9D  284D       jr     z,2BEC      ; ix+01 == 0    -> sortie par un bord (2BEC)
2B9F  3C         inc    a
2BA0  283A       jr     z,2BDC      ; ix+01 == 0xFF -> sortie par le bord opposé (2BDC)
2BA2  DD7E02     ld     a,(ix+02)   ; sinon teste Y (ix+02)
2BA5  A7         and    a
2BA6  2827       jr     z,2BCF      ; ix+02 == 0    -> sortie par un bord (2BCF)
2BA8  3C         inc    a
2BA9  2801       jr     z,2BAC      ; ix+02 == 0xFF -> sortie par le bord opposé (2BAC)
2BAB  C9         ret                ; ni l'un ni l'autre -> pas de transition, sort

; --- 4 cas de transition, chacun avec un "code de direction" C distinct ---
2BAC  0EC8       ld     c,C8        ; code 0xC8 -- direction "bas" ? (Y max)
2BAE  CDF92B     call   2BF9        ; résout la room voisine dans cette direction
2BB1  3E80       ld     a,80
2BB3  94         sub    h
2BB4  DD9605     sub    (ix+05)
2BB7  DD7702     ld     (ix+02),a   ; replace le joueur de l'autre côté (Y) de la
                                    ; nouvelle salle -- calcul symétrique au bord opposé
2BBA  DDCB07E6   set    4,(ix+07)   ; flag "vient de changer de salle" ?
2BBE  DDCB23E6   set    4,(ix+23)   ; idem sur un autre champ
2BC2  DD7E01     ld     a,(ix+01)
2BC5  DD771D     ld     (ix+1D),a   ; sauvegarde position (transition en cours ?)
2BC8  DD7E02     ld     a,(ix+02)
2BCB  DD771E     ld     (ix+1E),a
2BCE  C9         ret

2BCF  0E51       ld     c,51        ; code 0x51 -- direction "haut" ?
2BD1  CDF92B     call   2BF9
2BD4  7C         ld     a,h
2BD5  C680       add    a,80
2BD7  DD8605     add    a,(ix+05)
2BDA  18DB       jr     2BB7        ; rejoint le calcul de repositionnement Y

2BDC  0EAE       ld     c,AE        ; code 0xAE -- direction "droite" ?
2BDE  CDF92B     call   2BF9
2BE1  3E80       ld     a,80
2BE3  95         sub    l
2BE4  DD9604     sub    (ix+04)
2BE7  DD7701     ld     (ix+01),a   ; repositionne X
2BEA  18CE       jr     2BBA

2BEC  0E37       ld     c,37        ; code 0x37 -- direction "gauche" ?
2BEE  CDF92B     call   2BF9
2BF1  7D         ld     a,l
2BF2  C680       add    a,80
2BF4  DD8604     add    a,(ix+04)
2BF7  18EE       jr     2BE7

; --- 0x2BF9 : résout la room voisine à partir d'un code de direction ---
2BF9  FD214701   ld     iy,0147     ; table de connexions (SAME 0x0147 que 0x1DFB/0x2C3A !)
2BFD  113800     ld     de,0038     ; pas de 0x38 = 56 octets par entrée
2C00  0604       ld     b,04        ; jusqu'à 4 entrées testées
2C02  FD7E00     ld     a,(iy+00)
2C05  FE06       cp     06
2C07  D0         ret    nc          ; entrée invalide (>=6) -> pas de voisin, abandonne
2C08  FD7E01     ld     a,(iy+01)
2C0B  FD8602     add    a,(iy+02)
2C0E  B9         cp     c           ; compare (iy+01)+(iy+02) au code de direction C
2C0F  2805       jr     z,2C16      ; trouvé -> traite
2C11  FD19       add    iy,de       ; sinon entrée suivante (+56 octets)
2C13  10ED       djnz   2C02
2C15  C9         ret                ; aucune entrée ne correspond -> pas de transition

2C16  FD7E03     ld     a,(iy+03)
2C19  DD7703     ld     (ix+03),a   ; <-- NOUVEAU NUMÉRO DE ROOM (ou room-lié),
                                    ;     stocké dans (ix+03) du joueur !
2C1C  C60C       add    a,0C
2C1E  DD771F     ld     (ix+1F),a  ; dérivé, stocké aussi
2C21  C9         ret
```

**Interprétation d'ensemble — MÉCANISME DE NAVIGATION ENTRE SALLES
CONFIRMÉ** :

1. Quand le joueur atteint un bord de l'écran/de la grille (`(ix+01)`
   ou `(ix+02)` == 0 ou 0xFF), le jeu détecte une tentative de sortie de
   la salle courante par l'un des 4 côtés.
2. Un **code de direction fixe** (`0xC8`, `0x51`, `0xAE`, `0x37` — un par
   côté) est utilisé pour chercher, dans une **table de connexions locale
   à la room courante** (`0x0147`, jusqu'à 4 entrées de 56 octets — cf.
   peuplée par `0x2C3A`/`0x1DFB` à l'entrée dans la room), la définition
   de la salle voisine dans cette direction précise.
3. Si trouvée, le **numéro de la nouvelle room** est récupéré (`(iy+03)`
   → `(ix+03)` du joueur) et le joueur est **repositionné symétriquement
   de l'autre côté** de la nouvelle salle (calculs `0x80 - coordonnée`).
4. Si aucune entrée ne correspond (mur, pas de salle dans cette
   direction), rien ne se passe (`RET` sans transition).

**Ceci est exactement le mécanisme qu'il faudra automatiser pour l'outil
de cartographie du monde** : connaissant le numéro de room courant
(`(ix+08)` de l'entité "room globale", ou via `(0x0071)/(0x0072)`), on
peut lire la table de connexions (`0x0147`, ou directement la table
maître `0x33DD`/`0x33D4` via `0x2C3A`) pour connaître les 4 voisins de
chaque salle sans avoir à explorer le jeu manuellement pièce par pièce —
il suffira de suivre le graphe de connexions déduit de ces tables et
prendre une capture d'écran (+ dump RAM) à chaque nœud visité.

## Prochaines pistes

1. **Dumper et décoder `0x33DD`/`0x33D4`** (table maître room→données) —
   ça devrait donner directement la carte complète des salles et leurs
   connexions, SANS avoir à parcourir le jeu pas à pas.
2. **Dumper `0x417E-0x429E`** (catalogue d'objets, 32 entrées de 9
   octets) — donnerait la liste de tous les objets spéciaux du jeu et
   leur room d'appartenance.
3. Vérifier `(ix+08)` du joueur (ou d'une entité "état global" — peut-
   être pas le joueur mais une entité 128 spéciale) pour confirmer que
   c'est bien le numéro de room courant.
4. Confirmer par un test empirique : provoquer une sortie de salle (aller
   au bord de l'écran en jeu) et observer le changement de room/écran.

## Outils / méthode

- Reconnaissance du motif "table à pas fixe, parcourue avec comparaison
  et arrêt anticipé (DJNZ + CP)" comme technique classique de recherche
  linéaire dans une petite table — cohérent avec la méthodologie déjà
  établie (structures indexées par calcul explicite).
- Repérage d'une **sentinelle de table par adjacence** (0x417E-0x429E se
  termine exactement où 0x429E commence) — signal fort que deux tables
  voisines ont été dimensionnées intentionnellement par les développeurs
  originaux, utile pour deviner la taille d'une table qu'on n'a pas
  encore trouvée explicitement bornée dans le code.
