# Session 2026-08-06 (suite 2) — Le vrai moteur de rendu isométrique : premières routines

## Contexte

Correction méthodologique importante suite à un test de mouvement du
personnage (touches communiquées par l'utilisateur : Z/X tournent, S
avance, Z (rappel) sert aussi à sauter — une touche d'action, probablement
espace, existe mais reste sans effet pour l'instant).

## Erreur méthodologique corrigée : format d'adresse des breakpoints

`z80_breakpoints(['3186'])` (sans préfixe `0x`) est interprété comme
**décimal** (3186 = 0x0C72), pas hexadécimal — la doc de l'endpoint
(`src/doc/web_server_api.md`, section Z80 Breakpoints) précise bien
"decimal, hex (`0x…`)". Toujours utiliser `'0x3186'` explicitement.
Cette confusion explique plusieurs échecs de breakpoint dans la session
précédente.

## Révision majeure : 0x170D n'est PAS le moteur de rendu du personnage

Test : appui sur "s" (avance d'un pas), personnage visiblement déplacé à
l'écran (diff de captures d'écran : bbox de changement clairement localisé
sur la silhouette du personnage). **Breakpoint sur 0x170D jamais déclenché
pendant ce mouvement**, sur ~300 tentatives de poll. Vérification
complémentaire : `0x170D` n'est même pas touché par la codemap en 0.5s
d'inactivité totale (pas de texte affiché en continu au niveau du jeu,
contrairement au menu).

**Conclusion révisée** : 0x170D reste confirmée comme le moteur de rendu
de texte du menu (voir sessions précédentes), mais son éventuelle
réutilisation en jeu n'est PAS confirmée — les "appelants haute-adresse"
trouvés précédemment (0xABDE, 0xEBEC, 0xFC35, 0xFEF9, 0xFFB9) étaient des
**faux positifs** de la méthode de lecture de pile (SP ne contenait pas
une vraie adresse de retour à ces moments — probablement lu pendant un état
d'appel imbriqué où d'autres données étaient sur la pile). Toutes ces
adresses tombaient dans la zone écran (0xC000+) remplie de zéros
(désassemblage confirmé : `00 00 00...`), ce qui aurait dû alerter plus
tôt — une adresse de retour dans une zone de données pures est un signal
d'erreur de méthode, pas une vraie découverte.

**Leçon méthodologique pour la suite** : préférer systématiquement
`z80_history` (ordre garanti par l'émulateur) à la lecture manuelle de
SP pour retrouver un appelant. Toujours vérifier que l'adresse de retour
trouvée tombe dans une zone de CODE plausible (pas dans une plage connue
comme étant de la donnée/écran).

## CONFIRMÉ : 0x3186 tourne en continu (indépendamment de 0x170D)

Codemap sur 0.5s d'inactivité totale (aucune touche) :
- `0x170D` : non touché
- `0x16E5` (rendu de texte menu) : non touché
- `0x3186` : **touché** — donc appelé par autre chose que 0x170D/menu

Breakpoint correct (`'0x3186'`) → déclenché immédiatement. Trace
(`z80_history`) : appelant réel = `CALL 0x3186` à **0x2E79** (dans une
fonction qui commence au moins à 0x2E6C).

## NOUVELLE DÉCOUVERTE : 0x3195 — calcul d'adresse écran CPC (coordonnées → offset mémoire)

**Statut : confirmed** par désassemblage direct.

```
3195  E5         push   hl
3196  78         ld     a,b
3197  0F         rrca
3198  0F         rrca
3199  E63E       and    3E        ; b>>2, masqué sur 0x3E (indexe une table de 32 entrées)
319B  21B931     ld     hl,31B9   ; table de lookup ligne écran
319E  CF         rst    08        ; RST 08 = probablement un vecteur d'indexation table (à documenter)
319F  7E         ld     a,(hl)
31A0  23         inc    hl
31A1  66         ld     h,(hl)
31A2  6F         ld     l,a       ; HL = valeur lue dans la table (base ligne écran)
31A3  78         ld     a,b
31A4  2F         cpl
31A5  07         rlca
31A6  07         rlca
31A7  07         rlca
31A8  E638       and    38
31AA  B4         or     h
31AB  F6C0       or     C0        ; combine avec le octet haut existant + marqueur 0xC0
                                  ; (0xC0 = début de la zone écran CPC 0xC000!)
31AD  67         ld     h,a
31AE  79         ld     a,c
31AF  CB3F       srl    a
31B1  CB3F       srl    a
31B3  C608       add    a,08
31B5  CF         rst    08
31B6  EB         ex     de,hl
31B7  E1         pop    hl
31B8  C9         ret
```

Table à `0x31B9` (24 entrées word little-endian, vérifiées par lecture RAM
brute) : `0x0730, 0x06E0, 0x0690, 0x0640, 0x05F0, 0x05A0, 0x0550, 0x0500,
0x04B0, 0x0460, 0x0410, 0x03C0, 0x0370, 0x0320, 0x02D0, 0x0280, 0x0230,
0x01E0, 0x0190, 0x0140, 0x00F0, 0x00A0, 0x0050, 0x0000` — progression
arithmétique exacte, pas décroissant constant de `0x50` (80 décimal),
24 entrées. Cohérent avec **80 octets = une ligne de caractère complète
en Mode 1 CPC**, et 24 = un nombre plausible de bandes de 8 lignes dans
la hauteur utile de l'écran de jeu (24×8 = 192 lignes, proche des ~200
lignes visibles typiques). C'est très probablement une **table de base
d'adresse écran par bande de 8 lignes**, combinée ensuite avec `0xC0` en
octet haut pour retomber dans 0xC000-0xFFFF (zone écran confirmée par
l'utilisateur via CRTC R12/R13 = 0x3000 → base 0xC000).

**Interprétation d'ensemble** : `0x3195(B,C)` convertit une paire de
coordonnées (B=ligne/Y probable, C=colonne/X probable) en une adresse
écran CPC complète, via une table de correspondance pour la composante Y
(gérant le sous-adressage non-linéaire propre à l'écran CPC) et un calcul
direct pour la composante X. **C'est une pièce du moteur de conversion
coordonnée→adresse-écran**, cœur de tout renderer CPC.

`RST 08` mérite d'être élucidé : sur CPC, les vecteurs `RST` bas (0x00,
0x08, 0x10...) sont généralement réutilisés par le jeu lui-même (RAM
basse réécrite au démarrage) plutôt que le firmware — **à vérifier**
(désassembler 0x0008 directement).

## Fonction appelante (0x2E6C et alentours) — calcul de position + effacement

```
2E60  C0         ret    nz
2E61  3092       jr     nc,2DF5
2E63  85         add    a,l
2E64  D6C0       sub    C0
2E66  3804       jr     c,2E6C
2E68  ED44       neg
2E6A  85         add    a,l
2E6B  6F         ld     l,a
2E6C  78         ld     a,b
2E6D  85         add    a,l
2E6E  3D         dec    a
2E6F  47         ld     b,a
2E70  CD9531     call   3195      ; calcule l'adresse écran pour (B,C)
2E73  79         ld     a,c
2E74  4D         ld     c,l
2E75  6F         ld     l,a
2E76  78         ld     a,b
2E77  44         ld     b,h
2E78  67         ld     h,a
2E79  CD8631     call   3186      ; ajuste encore l'adresse (÷4 + 0x9000 -- à
                                  ; re-vérifier le rôle exact ici, peut-être
                                  ; réutilisé pour une raison différente du
                                  ; contexte "buffer de travail glyphe" vu
                                  ; au menu — même routine, contexte différent)
2E7C  3A7000     ld     a,(0070)  ; compteur/flag à 0x0070
2E7F  3C         inc    a
2E80  327000     ld     (0070),a
2E83  C5         push   bc
2E84  D5         push   de
2E85  E5         push   hl
2E86  AF         xor    a
2E87  CDC11D     call   1DC1      ; efface une zone rectangulaire (voir ci-dessous)
2E8A  C3F52D     jp     2DF5      ; retour à la boucle appelante
```

**Statut : CONFIRMED dans son ensemble** — complété par la découverte de
la boucle appelée finale `0x2E97-0x2EBF` (voir
`notes/2026-08-06-memory-zones-model.md`) : cette fonction
(`0x2E6C-0x2E8A`) calcule et EMPILE les 3 valeurs nécessaires à un futur
blit d'une entité (via `PUSH BC`/`PUSH DE`/`PUSH HL` en `0x2E83-0x2E85`,
dans l'ordre exact inverse du dépilage `POP HL`/`POP DE`/`POP BC` observé
dans la boucle finale `0x2EB2-0x2EB4`) :
- `BC` = adresse écran VRAM (calculée via `0x3195`, `fn_screen_addr_from_bc`)
- puis conversion en `HL` = pointeur buffer intermédiaire (via `0x3186`,
  `÷4 + 0x9000`)
- `(0x0070)` incrémenté à chaque appel = compteur de bandes en attente

Cette fonction efface (`call 1DC1`) IMMÉDIATEMENT une zone rectangulaire
à l'écran (probablement l'ancienne position de l'entité, avant son
nouveau rendu), MAIS empile les coordonnées pour le BLIT du nouveau
rendu qui sera effectué plus tard, en fin de frame, par la boucle
`0x2E97-0x2EBF` (`fn_blit_copy_line` en boucle). C'est le mécanisme
"empile pendant le rendu individuel, dépile et transfère en une passe
à la fin" qui explique l'architecture en deux temps du moteur (buffer
intermédiaire linéaire, VRAM entrelacée CPC) — voir
`notes/2026-08-06-memory-zones-model.md` pour la synthèse complète.

**Note sur 0x3186 dans ce contexte — RÉSOLU** : c'est bien la MÊME
routine (`HL=(HL>>2)+0x9000`) que celle identifiée pour le menu, mais
son rôle ici est maintenant confirmé sans ambiguïté : elle convertit
l'adresse VRAM déjà calculée par `0x3195` en un pointeur correspondant
dans le buffer intermédiaire (0x9000+, largeur 64 octets, axe Y
inversé) — PAS un deuxième buffer séparé. Les deux valeurs (VRAM via
0x3195, buffer intermédiaire via 0x3186) sont calculées à la suite l'une
de l'autre précisément parce qu'elles sont TOUTES LES DEUX empilées
juste après (voir ci-dessus) pour être consommées ensemble par
`fn_blit_copy_line` en fin de frame — ce n'est donc pas une ombre/masque
séparé, mais bien la paire (source buffer, destination écran) d'un seul
et même futur blit.

## 0x1DC1 — Effacement rectangulaire par déroulage de boucle (loop unrolling)

**Statut : confirmed** par désassemblage direct.

```
entrée: A = octet à écrire (0 dans le call vu ci-dessus -> efface avec 0),
        B = nombre de lignes, HL = adresse de départ (calculée par 3195/3186)
1DC1  F5         push   af
1DC2  78         ld     a,b
1DC3  ED44       neg               ; A = -B
1DC5  E60F       and    0F         ; masqué sur 4 bits -> B modulo 16 ?
1DC7  87         add    a,a        ; ×2
1DC8  32D61D     ld     (1DD6),a   ; PATCH DYNAMIQUE : modifie l'opérande
                                   ; immédiat d'une instruction plus bas
                                   ; (auto-modification de code -- technique
                                   ; delà jump-table/computed-jump classique
                                   ; pour dérouler une boucle de longueur
                                   ; variable)
1DCB  3E40       ld     a,40
1DCD  80         add    a,b
1DCE  ED44       neg
1DD0  5F         ld     e,a        ; DE = pas entre lignes consécutives (dépend de B)
1DD1  16FF       ld     d,FF
1DD3  41         ld     b,c        ; B = nouveau compteur (nombre de lignes réel)
1DD4  F1         pop    af         ; restaure A (valeur à écrire, 0 dans l'appel vu)
1DD5  1812       jr     1DE9       ; <- la cible réelle est patchée dynamiquement
                                   ;    (voir 0x1DD6 ci-dessus) pour sauter au
                                   ;    bon endroit dans la séquence déroulée
1DD7..1DF6:  (LD (HL),A / INC HL) × 12 répétées  -- écrit A et avance HL,
             12 fois de suite avant de reboucler
1DF7  19         add    hl,de      ; passe à la ligne suivante (DE = pas)
1DF8  10DB       djnz   1DD5       ; boucle B fois
1DFA  C9         ret
```

**Interprétation** : remplit un rectangle de largeur variable (jusqu'à 12
octets par ligne, ajusté dynamiquement via l'auto-modification du saut
d'entrée dans la séquence déroulée — pour gérer des largeurs < 12 sans
dupliquer le code) et B lignes de hauteur, avec un octet constant A. Le
`jr 1DE9` en 0x1DD5 est réécrit indirectement (pas lui-même, mais
l'usage réel de code auto-modifiant reste à confirmer précisément — le
`(1DD6)` patché est un octet à l'intérieur du flux, pas l'opérande du
`jr` — **à revérifier au désassembleur pas à pas, cette partie est une
hypothèse de lecture rapide, pas confirmée**).

C'est une technique très caractéristique des routines de blitting 8-bit
optimisées (loop unrolling + saut d'entrée variable pour gérer une largeur
dynamique sans coût de boucle interne) — cohérent avec un moteur de rendu
mature, probablement porté assez fidèlement depuis l'original ZX Spectrum
(où la même technique est monnaie courante).

## RST 08 élucidé : addition 16-bit HL += A

**Statut : confirmed** par désassemblage direct de `0x0008`.

```
0008  85         add    a,l
0009  6F         ld     l,a
000A  7C         ld     a,h
000B  CE00       adc    a,00
000D  67         ld     h,a
000E  C9         ret
```
= `HL = HL + A` (le Z80 n'a pas d'addition directe 16-bit + 8-bit ; ce
`RST` comble ce manque). Un `RST` (1 octet, ~11 T-states) est nettement
plus rapide et compact qu'un `CALL` (3 octets, ~17 T-states) — cohérent
avec une routine utilitaire très fréquemment invoquée (ex. indexation
dans une table avec un offset variable, comme vu dans 0x3195 à 0x319E et
0x31B5). Confirme l'intuition : les slots RST bas du Z80 sont réutilisés
par le jeu lui-même (pas le firmware CPC) pour ses primitives les plus
chaudes.

## 0x3186 en contexte jeu : ELUCIDÉ (partiellement) — pointe vers une zone de données statiques, pas un buffer mutable

Retour en jeu après un game over (40 "jours" in-game, cf. session
utilisateur), breakpoint posé directement sur l'appelant réel `0x2E79`
(`CALL 0x3186`) pour lire HL à l'entrée exacte :

```
HL en entrée = 0x7374
0x3186: HL = (0x7374 >> 2) + 0x9000 = 0x1CDD + 0x9000 = 0xACDD
```
Zone 0xACDD confirmée en RAM bank 2 (0x8000-0xBFFF, memmap). Contenu
autour de 0x9000 (base du buffer) : motifs répétitifs façon damier —
`33 88 33 88`, `66 CC 66 CC`, `AA 00`, `FF EE 11` — **pas des formes de
glyphe/sprite lisibles en 1bpp classique**, plutôt le genre de motif
qu'on associe à des **masques de hauteur/collision par cellule** dans un
moteur isométrique (chaque bit/paire de bits encodant l'état de plusieurs
cases de la grille).

**Test de mutabilité** : dump de 256 octets à 0x9000 avant/après un
mouvement du personnage (touche "s") — **aucun octet changé**. Donc cette
zone est très probablement une **table statique de données de room/niveau**
(pas un état de jeu qui varie frame par frame), cohérent avec des données
géométriques précalculées (masques de forme des blocs isométriques) plutôt
qu'un buffer de travail mutable comme au menu.

**Révision de l'hypothèse initiale** ("buffer de travail glyphe hors
écran") : au menu, 0x3186 pointait effectivement vers un buffer où
0x170D écrivait (mutable, réinitialisé au fil de l'affichage du texte).
En jeu, la même routine de calcul d'adresse est réutilisée pour un
usage différent — **indexer une table de données STATIQUES** (pas de
la même façon "buffer de travail écrit"). Donc 0x3186 = utilitaire
générique "adresse = source÷4 + 0x9000", employé dans (au moins) deux
contextes différents : écriture de buffer glyphe (menu) et lecture de
table de données de room (jeu). Cohérent avec le fait que ce soit une
petite routine utilitaire bon marché (5 instructions), le genre qu'on
réutilise partout sans lui donner un sens "métier" fixe.

**Reste à élucider** : quelles sont exactement ces données à 0x9000+
(masque de collision de la grille isométrique ? formes des blocs ?
tables de hauteur ?) — nécessite de corréler avec la position à l'écran
et la géométrie visible de la salle actuelle, pas juste un dump brut.



## Contexte global remonté : la vraie boucle de rendu (0x2DE2+)

Remontée en arrière depuis 0x2E60 jusqu'au véritable début de fonction
(marqué par les `RET` des routines précédentes). Structure complète
obtenue par désassemblage direct (`disassemble_range` 0x2D80-0x2E80).

### Trois primitives génériques juste avant (0x2D91-0x2DE1)

```
0x2D91-0x2D9A : remplissage mémoire simple (LD (HL),E / INC HL / DEC BC, boucle)
0x2D9B-0x2DB6 : effacement complet de l'écran (0xC000, 80 octets/ligne
                Mode 1, boucle imbriquée 0x19×0x50 avec gestion de
                l'entrelacement CRTC +0x0800/+0xC050) — CONFIRME
                indépendamment la table de 0x3195 (pas d'entrée à 0x50)
0x2DB7-0x2DBD : setup BC=0x3000, HL=0x9000 puis saute dans le remplissage
                générique (0x2D91) — donc 0x9000 fait au moins 0x3000
                octets (12288) de zone remplie/initialisée par endroits,
                cohérent avec plusieurs tables statiques successives
0x2DBF-0x2DE1 : copie rectangulaire écran→écran via LDIR (0x40 octets par
                ligne, 0xC0=192 lignes) — probablement une routine de
                défilement/copie de fond, pas directement liée à la
                boucle d'objets qui suit
```

### 0x2DE2-0x2E97 — LA boucle de rendu des entités (structure complète)

**Statut : confirmed** (désassemblage direct), **hypothesis** sur
l'interprétation métier des champs de structure.

```
2DE2  AF         xor    a
2DE3  327000     ld     (0070),a     ; compteur remis à 0 (objets traités ce tour)
2DE6  DDE5       push   ix
2DE8  3A7D00     ld     a,(007D)     ; flag global (pause rendu ? état "room stable" ?)
2DEB  A7         and    a
2DEC  C2972E     jp     nz,2E97      ; si non-zéro, sort tout de suite (rendu désactivé ?)
2DEF  212027     ld     hl,2720      ; HL = tête de la liste d'objets/entités
2DF2  229000     ld     (0090),hl    ; (0090) = curseur de parcours de liste

; --- boucle principale, une itération par entité ---
2DF5  2A9000     ld     hl,(0090)    ; recharge le curseur
2DF8  7E         ld     a,(hl)       ; lit l'octet courant (index/ID d'entité)
2DF9  23         inc    hl
2DFA  229000     ld     (0090),hl    ; avance le curseur pour le prochain tour
2DFD  FEFF       cp     FF           ; 0xFF = marqueur fin de liste
2DFF  CA972E     jp     z,2E97       ; fin de liste -> sortie
2E02  CD222C     call   2C22         ; résout l'ID en pointeur de structure objet (HL)
2E05  E5         push   hl
2E06  DDE1       pop    ix           ; IX = pointeur vers la structure de l'entité

2E08  DDCB076E   bit    5,(ix+07)    ; teste un flag à l'offset +07
2E0C  28E7       jr     z,2DF5       ; si bit 5 = 0 -> entité ignorée, itération suivante
2E0E  DDCB07AE   res    5,(ix+07)    ; sinon consomme le flag (traité une fois)

; --- calcul de bounding box écran à partir de 8 champs de la structure ---
; champs utilisés : (ix+14),(ix+15),(ix+16),(ix+17)  et
;                    (ix+18),(ix+19),(ix+1A),(ix+1B)
; deux groupes de 4 -- probablement (x_min,y_min,x_max,y_max) courant vs
; précédent, ou (x,y,largeur,hauteur) x2 (position actuelle + position à
; l'écran de la frame précédente, pour effacer l'ancienne empreinte)
2E12  DD7E16     ld     a,(ix+16)
2E15  DD961A     sub    (ix+1A)
2E18  DA8D2E     jp     c,2E8D       ; si (ix+16) < (ix+1A) -> branche alternative (2E8D+)
2E1B  DD4E1A     ld     c,(ix+1A)
2E1E  DD7E1A     ld     a,(ix+1A)
2E21  0F         rrca
2E22  0F         rrca              ; ÷4
2E23  E63F       and    3F         ; masque 6 bits (plage 0-63)
2E25  DD8618     add    a,(ix+18)
2E28  5F         ld     e,a
2E29  DD7E16     ld     a,(ix+16)
2E2C  0F         rrca
2E2D  0F         rrca
2E2E  E63F       and    3F
2E30  DD8614     add    a,(ix+14)
2E33  BB         cp     e
2E34  3801       jr     c,2E37
2E36  5F         ld     e,a         ; E = max(deux quantités calculées)
2E37  79         ld     a,c
2E38  0F         rrca
2E39  0F         rrca
2E3A  E63F       and    3F
2E3C  47         ld     b,a
2E3D  7B         ld     a,e
2E3E  90         sub    b
2E3F  67         ld     h,a         ; H = E - B  (largeur/hauteur de la bounding box ?)

2E40  DD7E17     ld     a,(ix+17)   ; même schéma avec le 2e groupe de champs
2E43  DD961B     sub    (ix+1B)
2E46  384A       jr     c,2E92
2E48  DD461B     ld     b,(ix+1B)
2E4B  DD7E1B     ld     a,(ix+1B)
2E4E  DD8619     add    a,(ix+19)
2E51  5F         ld     e,a
2E52  DD7E17     ld     a,(ix+17)
2E55  DD8615     add    a,(ix+15)
2E58  BB         cp     e
2E59  3001       jr     nc,2E5C
2E5B  7B         ld     a,e
2E5C  90         sub    b
2E5D  6F         ld     l,a         ; L = résultat correspondant (2e axe)

2E5E  78         ld     a,b
2E5F  FEC0       cp     C0
2E61  3092       jr     nc,2DF5     ; si b>=0xC0 -> entité hors champ, ignorée
2E63  85         add    a,l
2E64  D6C0       sub    C0
2E66  3804       jr     c,2E6C
2E68  ED44       neg
2E6A  85         add    a,l
2E6B  6F         ld     l,a         ; ajuste L (clipping ?)

2E6C  78         ld     a,b         ; B,C prêts -> (B,C) passés à 0x3195
2E6D  85         add    a,l
2E6E  3D         dec    a
2E6F  47         ld     b,a
2E70  CD9531     call   3195        ; (B,C) -> adresse écran (HL)
2E73  79         ld     a,c
2E74  4D         ld     c,l
2E75  6F         ld     l,a
2E76  78         ld     a,b
2E77  44         ld     b,h
2E78  67         ld     h,a
2E79  CD8631     call   3186        ; adresse table statique (données room)
2E7C  3A7000     ld     a,(0070)    ; incrémente le compteur d'entités traitées
2E7F  3C         inc    a
2E80  327000     ld     (0070),a
2E83  C5         push   bc
2E84  D5         push   de
2E85  E5         push   hl
2E86  AF         xor    a
2E87  CDC11D     call   1DC1        ; efface le rectangle (bounding box calculée)
2E8A  C3F52D     jp     2DF5        ; itération suivante
```

### Structure d'entité (hypothèse de layout, offsets vus jusqu'ici)

| Offset (IX+n) | Rôle hypothétique |
|---|---|
| +07 | Bit 5 = flag "à retraiter ce tour" (consommé par `RES 5,(ix+07)`) |
| +14, +15, +16, +17 | Groupe 1 : position/dimension courante (X,Y,W,H ?) |
| +18, +19, +1A, +1B | Groupe 2 : position/dimension précédente OU deuxième axe |

**Statut : hypothesis** — les offsets exacts sont confirmés par le
désassemblage, mais leur signification métier (quel champ = X, quel champ
= Y, quel champ = largeur/hauteur) reste à déduire, idéalement en
modifiant un champ via `ram_write` pendant que l'entité est visible et en
observant l'effet à l'écran (technique de "fuzzing corrélé" plutôt que
lecture statique).

### Interprétation d'ensemble

C'est la **boucle principale de rendu des entités du jeu** (personnage,
objets, blocs mobiles) : parcourt une liste terminée par 0xFF à partir de
`0x2720`, résout chaque ID en pointeur de structure via `0x2C22`, calcule
une bounding box écran à partir de champs de position/dimension (deux
calculs symétriques pour les deux axes), puis **efface systématiquement**
cette zone via `0x1DC1` avant de continuer à l'entité suivante — **le
dessin réel du sprite/tuile n'a pas encore été localisé** (cette fonction
ne fait qu'effacer ; le rendu proprement dit doit se faire soit avant cet
appel dans le même passage de boucle plus haut — non vu ici, soit dans
une passe séparée sur la même liste).

## Prochaines pistes prioritaires

1. **Trouver la routine de DESSIN réelle** (pas juste l'effacement) — soit
   juste après le `jp 2DF5` en repassant sur la liste, soit ailleurs dans
   le flot d'exécution global (avant/après cette fonction). Poser des
   breakpoints sur des CALL non encore identifiés pendant que le
   personnage est visible et bouge.
2. **Résoudre 0x2C22** (résolution ID→pointeur d'entité) — probablement
   une simple indexation dans un tableau de structures de taille fixe.
3. **Corréler les champs (ix+14..1B) avec des changements visibles** —
   modifier un champ via `ram_write` pendant que l'entité concernée est
   à l'écran (le personnage par exemple) et observer l'effet.
4. **Élucider `(0x2720)`** — la liste d'entités elle-même (dump direct,
   voir combien d'entrées, si elles pointent vers des offsets fixes ou
   des indices).
5. **`(0x007D)`** — flag testé en tout début (`0x2DE8`), qui désactive
   complètement le rendu si non-zéro. Pourrait être lié à la pause du
   jeu, un état de transition entre salles, ou l'écran de mort/de score.

## MISE À JOUR : 0x2C22 confirmé numériquement — taille de structure = 28 octets

**Statut : confirmed** par désassemblage direct + vérification par calcul.

```
2C22  C5         push   bc
2C23  E67F       and    7F        ; ID masqué sur 7 bits (0-127)
2C25  6F         ld     l,a
2C26  2600       ld     h,00
2C28  29         add    hl,hl     ; ×2
2C29  29         add    hl,hl     ; ×4
2C2A  29         add    hl,hl     ; ×8
2C2B  4D         ld     c,l
2C2C  44         ld     b,h       ; BC = ID×8
2C2D  29         add    hl,hl     ; ×16
2C2E  09         add    hl,bc     ; +×8 = ×24
2C2F  CB38       srl    b
2C31  CB19       rr     c         ; BC = ID×4
2C33  09         add    hl,bc     ; +×4 = ×28
2C34  01D700     ld     bc,00D7
2C37  09         add    hl,bc     ; + base 0x00D7
2C38  C1         pop    bc
2C39  C9         ret
```
= `HL = ID × 28 + 0x00D7`. **Confirme exactement** les offsets de champ
observés dans la boucle de rendu (+07, +14..+1B, max +1B=27 < 28) — la
table d'entités est bien un tableau de structures de **28 octets**
chacune, en zero-page (RAM basse, base 0x00D7). Occupe donc
`0x00D7 + 128×28 = 0x0DD7` au maximum (128 entités possibles, masque
0x7F), mais le nombre réel d'entités actives dans une salle est
sûrement bien inférieur.

## MISE À JOUR MAJEURE : le pipeline de dessin réel trouvé (0x2EDC-0x2F6E+)

Après la boucle d'effacement (0x2DE2-0x2E97), le code continue en
0x2E97-0x2EBF avec un **second passage sur la liste**, cette fois pour
DESSINER (pas juste effacer) :

```
2E97  CD5027     call   2750      ; ? (non exploré)
2E9A  CD441C     call   1C44      ; ?
2E9D  CD0218     call   1802      ; ?
2EA0  217000     ld     hl,0070
2EA3  3A8400     ld     a,(0084)  ; accumulateur global
2EA6  86         add    a,(hl)    ; += compteur d'entités traitées (0070)
2EA7  328400     ld     (0084),a
2EAA  217000     ld     hl,0070
2EAD  7E         ld     a,(hl)
2EAE  A7         and    a
2EAF  280C       jr     z,2EBD    ; si compteur = 0 -> fin
2EB1  35         dec    (hl)      ; décrémente le compteur
2EB2  E1         pop    hl        ; dépile les BC/DE/HL sauvés par la
2EB3  D1         pop    de        ; boucle d'effacement (0x2E83-0x2E85) --
2EB4  C1         pop    bc        ; donc réutilise les adresses déjà calculées !
2EB5  78         ld     a,b
2EB6  41         ld     b,c
2EB7  4F         ld     c,a
2EB8  CDC02E     call   2EC0      ; <-- DESSIN (copie, pas remplissage)
2EBB  18ED       jr     2EAA      ; boucle sur le compteur
2EBD  DDE1       pop    ix
2EBF  C9         ret
```

**Donc la boucle 0x2DE2 fait DEUX choses en une seule passe sur la
liste** : elle empile (PUSH) les adresses calculées à chaque itération
(voir 0x2E83-0x2E85 dans la section précédente) pendant l'effacement,
PUIS les redépile ici pour dessiner avec les MÊMES adresses. Pas deux
passes séparées sur la liste comme supposé précédemment — une seule
passe qui empile tout, puis un deuxième mini-passage qui dépile et
dessine, dans la même invocation de fonction. Plus économe qu'un second
parcours complet de la liste.

### 0x2EC0 — Routine de DESSIN (copie de bloc, pas remplissage constant)

**Statut : confirmed** par désassemblage direct — différence clé avec
0x1DC1 : celle-ci utilise `LDIR` (copie source→dest) au lieu de
`LD (HL),A` répété (remplissage constant).

```
2EC0  C5         push   bc
2EC1  E5         push   hl
2EC2  D5         push   de
2EC3  0600       ld     b,00
2EC5  EDB0       ldir            ; copie C octets depuis HL vers DE (B=0,C=largeur)
2EC7  D1         pop    de
2EC8  210008     ld     hl,0800
2ECB  19         add    hl,de
2ECC  3004       jr     nc,2ED2
2ECE  1150C0     ld     de,C050
2ED1  19         add    hl,de   ; même calcul d'entrelacement CRTC que 0x2D9B (effacement écran)
2ED2  EB         ex     de,hl
2ED3  E1         pop    hl
2ED4  01C0FF     ld     bc,FFC0
2ED7  09         add    hl,bc
2ED8  C1         pop    bc
2ED9  10E5       djnz   2EC0     ; boucle sur B lignes
2EDB  C9         ret
```
**Rôle confirmé** : copie un bloc source (probablement un sprite
pré-rendu en RAM, source = HL avant l'appel) vers l'écran (dest = DE),
ligne par ligne, avec la même gestion d'entrelacement CRTC que les
routines d'effacement. **C'est la routine de blit du sprite.**

### 0x2EDC-0x2F01 — Projection isométrique (coordonnées monde → écran)

**Statut : confirmed** par désassemblage direct, **hypothesis** sur
l'interprétation "isométrique".

```
2EDC  DD7E01     ld     a,(ix+01)
2EDF  DD8602     add    a,(ix+02)
2EE2  D680       sub    80
2EE4  DD8612     add    a,(ix+12)
2EE7  DD7716     ld     (ix+16),a   ; (ix+16) = (ix+01)+(ix+02)-0x80+(ix+12)
2EEA  DD7E02     ld     a,(ix+02)
2EED  DD9601     sub    (ix+01)
2EF0  C680       add    a,80
2EF2  CB3F       srl    a
2EF4  DD8603     add    a,(ix+03)
2EF7  D668       sub    68
2EF9  DD8613     add    a,(ix+13)
2EFC  DD7717     ld     (ix+17),a   ; (ix+17) = ((ix+02)-(ix+01)+0x80)/2+(ix+03)-0x68+(ix+13)
2EFF  FEC0       cp     C0
2F01  C9         ret               ; carry set si (ix+17) < 0xC0 -> visible ?
```
Combine `(ix+01)` et `(ix+02)` par **somme** pour une coordonnée et par
**différence divisée par 2** pour l'autre — c'est exactement la formule
d'une **projection isométrique classique** (X_écran = X+Y, Y_écran =
(Y-X)/2, à des offsets/échelles près) : deux coordonnées "monde" (probable
X,Y d'une grille 3D) combinées pour donner une position écran en losange.
`(ix+12)`/`(ix+13)` sont des offsets additionnels (peut-être la
composante Z/hauteur, ou un décalage de salle). **Très forte hypothèse
que (ix+01),(ix+02) sont des coordonnées de grille 3D (X,Y du monde
isométrique)** — cohérent avec le nom du moteur ("Filmation" dans la
scène retro, mais on ne s'appuie pas sur ce nom externe, seulement sur la
structure observée).

### 0x2F02-0x2F16 — Résolution de forme via table de sprite (0x429E)

**Statut : confirmed** par désassemblage direct.

```
2F02  DD6E00     ld     l,(ix+00)   ; (ix+00) = ID/type de sprite
2F05  2600       ld     h,00
2F07  29         add    hl,hl       ; ×2 (table de pointeurs word)
2F08  019E42     ld     bc,429E     ; base table de pointeurs de sprite
2F0B  09         add    hl,bc
2F0C  5E         ld     e,(hl)
2F0D  23         inc    hl
2F0E  56         ld     d,(hl)      ; DE = pointeur vers données de ce type de sprite
2F0F  1A         ld     a,(de)
2F10  A7         and    a
2F11  C2E931     jp     nz,31E9     ; si premier octet non-nul -> saut vers 0x31E9
2F14  33         inc    sp
2F15  33         inc    sp          ; désempile 2 octets (annule un appel imbriqué)
2F16  C9         ret
```
`(ix+00)` = **type/ID de sprite**, indexe une table de pointeurs à
`0x429E` (table de dispatch par type d'entité — cohérent avec un jeu qui
a plusieurs types d'objets : joueur, blocs, ennemis, items).

### 0x2F17-0x2F6E+ — Suite du pipeline de dessin (auto-modification dense)

**Statut : hypothesis, désassemblage brut confirmé, interprétation
partielle.**

```
2F17  DD7E00     ld     a,(ix+00)
2F1A  FE01       cp     01
2F1C  2005       jr     nz,2F23
2F1E  DD360000   ld     (ix+00),00  ; si type==1, le remet à 0 (désactive l'entité ?) puis RET
2F22  C9         ret
2F23  DDCB07A6   res    4,(ix+07)   ; consomme un autre flag (bit 4 cette fois, pas bit 5)
2F27  CDDC2E     call   2EDC        ; projection isométrique (voir ci-dessus)
2F2A  D0         ret    nc          ; si hors champ -> sort
2F2B  CD022F     call   2F02        ; résolution de forme (voir ci-dessus)
2F2E  1A         ld     a,(de)
2F2F  E63F       and    3F
2F31  2F         cpl
2F32  C641       add    a,41
2F34  32AF30     ld     (30AF),a    ; PATCH DYNAMIQUE : modifie un opérande
                                    ; immédiat ailleurs dans le code (0x30AF)
2F37  DD7E16     ld     a,(ix+16)
2F3A  E603       and    03
2F3C  CABB30     jp     z,30BB
2F3F  CB27       sla    a
2F41  CB27       sla    a
2F43  08         ex     af,af'
2F44  1A         ld     a,(de)
2F45  13         inc    de
2F46  E63F       and    3F
2F48  3C         inc    a
2F49  DD7714     ld     (ix+14),a   ; réécrit (ix+14) -- dimension du sprite ?
2F4C  3D         dec    a
2F4D  ED44       neg
2F4F  E60F       and    0F
2F51  6F         ld     l,a
2F52  2600       ld     h,00
2F54  29         add    hl,hl
2F55  4D         ld     c,l
2F56  44         ld     b,h
2F57  29         add    hl,hl
2F58  29         add    hl,hl
2F59  29         add    hl,hl
2F5A  09         add    hl,bc
2F5B  018D2F     ld     bc,2F8D
2F5E  09         add    hl,bc
2F5F  228B2F     ld     (2F8B),hl   ; PATCH DYNAMIQUE : écrit une adresse
                                    ; cible dans le code en 0x2F8B (probable
                                    ; opérande d'un JP à cet endroit -- table
                                    ; de dispatch selon la largeur du sprite,
                                    ; sélectionnant une routine de blit
                                    ; spécialisée par largeur ?)
2F62  1A         ld     a,(de)
2F63  13         inc    de
2F64  DD7715     ld     (ix+15),a   ; réécrit (ix+15)
```

**Interprétation d'ensemble (hypothesis)** : après avoir résolu le
pointeur de forme via `0x2F02`, cette section lit des octets de
définition de forme (`(DE)` avancé à chaque lecture) pour reconstituer
dynamiquement les dimensions (`(ix+14)`, `(ix+15)`) et sélectionner, via
auto-modification de code (`0x2F5F` patchant `0x2F8B`), une routine de
blit spécialisée selon la largeur du sprite — technique classique pour
éviter une boucle générique lente (spécialisation par taille, chaque
variante de largeur ayant sa propre routine optimisée sans test de
largeur en boucle interne). **Nécessite un traçage pas-à-pas
supplémentaire pour confirmer le sens exact de chaque champ** — c'est la
zone la plus dense en heuristique de code auto-modifiant vue jusqu'ici.

## Prochaines pistes prioritaires (mise à jour)

1. **Désassembler 0x31E9 et 0x429E** (table de pointeurs par type de
   sprite) et 0x2F8D+ (les routines de blit spécialisées par largeur,
   probablement plusieurs variantes proches en mémoire).
2. **Tracer pas-à-pas 0x2F17-0x2F6E** avec des valeurs réelles (breakpoint
   + z80_step + lecture des champs ix) pour confirmer l'interprétation
   "dimensions + sélection de routine de blit".
3. Toujours en attente : élucider `(0x2720)` (liste d'entités elle-même),
   `(0x007D)` (flag global de rendu), et les trois `CALL` non explorés en
   tout début de 0x2E97 (0x2750, 0x1C44, 0x1802).
4. Vérifier l'hypothèse de projection isométrique de 0x2EDC en modifiant
   `(ix+01)`/`(ix+02)` de l'entité "joueur" via `ram_write` pendant que le
   personnage est visible, et observer le déplacement à l'écran — test
   crucial pour confirmer que ces champs sont bien des coordonnées de
   grille 3D.

## CONFIRMÉ NUMÉRIQUEMENT ET VISUELLEMENT : projection isométrique 0x2EDC validée

**Statut : confirmed** (double vérification : calcul exact + effet visuel
observé).

### Identification de l'entité 0 = joueur

Dump de la liste `0x2720` (le buffer par-frame consommé par la boucle de
rendu, pas une liste statique de niveau — voir ci-dessous) : contenu
stable `80 01 FF ...` en l'absence d'input, changeant légèrement (`00↔80`
sur le premier octet) après une touche de mouvement — cohérent avec le
bit 7 (`0x80`) comme flag "visible/actif" sur l'entité, masqué par
`AND 0x7F` dans `0x2C22`. Deux entités actives dans cette room (ID 0 et
ID 1) — l'entité ID=0 est identifiée comme le **joueur** (hypothèse forte,
non contredite par les tests suivants).

### Piège d'indexation corrigé : les offsets `(ix+NN)` sont en HEXADÉCIMAL

**Erreur initiale commise puis corrigée** : en recalculant à la main la
formule de projection avec les valeurs dumpées, une confusion entre
offset hexadécimal affiché par le désassembleur (`(ix+12)` = offset
**0x12** = 18 décimal) et offset décimal a donné un résultat qui NE
correspondait PAS à la valeur observée. Toujours relire l'offset
affiché comme un nombre hexadécimal, jamais décimal, en le convertissant
explicitement avant tout calcul.

### Dump complet de la structure entité 0 (base 0x00D7)

```
(ix+00): 0x32   -- probablement type/ID de sprite (indexe 0x429E)
(ix+01): 0x6E   -- coordonnée A (utilisée en SOMME dans la projection)
(ix+02): 0x80   -- coordonnée B (utilisée en SOMME et DIFFÉRENCE)
(ix+03): 0x80   -- coordonnée C (offset additif du 2e axe)
(ix+04): 0x05
(ix+05): 0x05
(ix+06): 0x17
(ix+07): 0x0C   -- flags (bit 5 utilisé par la boucle de rendu, bit 4 par 0x2F23)
(ix+08): 0xB3
(ix+09)-(ix+11): 0x00 (dans cette room/état)
(ix+12): 0xF4   -- offset additif de la projection, axe (ix+16)
(ix+13): 0xF9   -- offset additif de la projection, axe (ix+17)
(ix+14): 0x07   -- bounding box (calculée dans la boucle de rendu)
(ix+15): 0x10
(ix+16): 0x62   -- position écran projetée, axe 1 (RÉSULTAT de 0x2EDC)
(ix+17): 0x5A   -- position écran projetée, axe 2 (RÉSULTAT de 0x2EDC)
(ix+18): 0x07   -- copie/valeur précédente de (ix+14)
(ix+19): 0x10   -- copie/valeur précédente de (ix+15)
(ix+1A): 0x62   -- copie/valeur précédente de (ix+16)
(ix+1B): 0x5A   -- copie/valeur précédente de (ix+17)
```
Les deux groupes `(ix+14..17)` et `(ix+18..1B)` sont identiques quand
rien n'a bougé récemment — **confirme l'hypothèse "position courante vs
position précédente"** posée plus haut : le second groupe est la trace
de la frame précédente, utilisée par la boucle d'effacement (0x2DE2+)
pour effacer l'ancienne empreinte avant que la nouvelle position ne soit
dessinée.

### Vérification par calcul exact

Avec les valeurs réelles dumpées ci-dessus :
```
(ix+16) = (ix+01) + (ix+02) - 0x80 + (ix+12)
        = 0x6E + 0x80 - 0x80 + 0xF4 (mod 256)
        = 0x62   ✓ (valeur observée : 0x62)

(ix+17) = (((ix+02) - (ix+01) + 0x80) mod 256) >> 1 + (ix+03) - 0x68 + (ix+13)
        = (((0x80-0x6E+0x80) mod 256) >> 1) + 0x80 - 0x68 + 0xF9 (mod 256)
        = 0x5A   ✓ (valeur observée : 0x5A)
```
**Les deux formules produisent exactement les valeurs observées en RAM**
— la lecture du désassemblage est donc correcte au bit près.

### Vérification comportementale (test décisif)

`ram_write` sur `(ix+01)` de l'entité 0 (0x00D7+1 = 0x00D8), `+0x10` par
rapport à la valeur courante, pendant que le personnage est visible à
l'écran :
- Capture d'écran avant/après (`ImageChops.difference` + `getbbox()`) :
  zone de changement localisée (bbox ~76×76 px) exactement là où le
  personnage se trouvait.
- **Inspection visuelle (ASCII-art zoomé) : le personnage s'est déplacé
  en diagonale bas-droite** — exactement le mouvement attendu d'une vraie
  projection isométrique quand on augmente une seule des deux coordonnées
  combinées par somme (le déplacement apparent combine un déplacement
  horizontal ET vertical, jamais un axe pur, signature caractéristique
  d'une vue en losange).

**Conclusion : 0x2EDC est définitivement confirmée comme la routine de
projection isométrique (coordonnées "monde" 2D → position écran en
losange), avec (ix+01)/(ix+02) comme les deux coordonnées de grille
combinées.** C'est la pièce la plus importante comprise jusqu'ici pour
la réécriture future du moteur.

### Révision : 0x2720 n'est pas une liste statique de niveau

Contrairement à l'hypothèse initiale ("liste d'entités du niveau"), le
buffer à `0x2720` est **reconstruit dynamiquement chaque frame** avec les
IDs des entités actuellement à traiter (contenu stable en l'absence
d'action, mais différent d'un lancement à l'autre du breakpoint/dump —
et le bit 7 du premier octet change avec l'input). Il faudra retrouver
la routine qui REMPLIT ce buffer (probablement une passe de
tri/culling — décider quelles entités sont dans le champ de la caméra
avant de les passer à la boucle de rendu) — **nouvelle piste prioritaire**.

## TROUVÉ : 0x26F7 remplit 0x2720 — la passe de culling/filtrage

**Statut : confirmed** par désassemblage direct.

```
26F7  DDE5       push   ix
26F9  0628       ld     b,28        ; B = 0x28 = 40 -- parcourt 40 entités
26FB  111C00     ld     de,001C     ; DE = 0x1C = 28 (taille de structure)
26FE  DD21D700   ld     ix,00D7     ; IX = début du tableau d'entités
2702  212027     ld     hl,2720     ; HL = curseur d'écriture dans le buffer
2705  0E00       ld     c,00        ; C = index de l'entité courante

; --- boucle de filtrage, une itération par entité (40 au total) ---
2707  DD7E00     ld     a,(ix+00)   ; (ix+00) = type/ID de sprite
270A  A7         and    a
270B  2808       jr     z,2715      ; type==0 -> entité vide, ignorée (pas d'écriture)
270D  DDCB0766   bit    4,(ix+07)   ; teste le bit 4 du flag (ix+07)
2711  2802       jr     z,2715      ; bit 4 == 0 -> ignorée (pas active/visible ?)
2713  71         ld     (hl),c      ; écrit l'INDEX de l'entité (pas son ID direct)
2714  23         inc    hl
2715  0C         inc    c           ; index suivant (que l'entité ait été gardée ou non)
2716  DD19       add    ix,de       ; passe à l'entité suivante (+28 octets)
2718  10ED       djnz   2707        ; boucle 40 fois
271A  3EFF       ld     a,FF
271C  77         ld     (hl),a      ; marqueur de fin de liste
271D  DDE1       pop    ix
271F  C9         ret
```

**Rôle confirmé** : filtre les 40 premières entités du tableau (sur 128
possibles au total, cf. 0x2C22) selon deux critères — type de sprite
non-nul (`(ix+00)≠0`, l'entité "existe") ET bit 4 de `(ix+07)` actif
(un flag distinct du bit 5 utilisé plus tard dans la boucle de rendu,
peut-être "dans la room courante" ou "visible depuis la caméra"). Les
index (pas les IDs bruts — quoique équivalent ici car C incrémente en
même temps que le parcours) des entités retenues sont écrits dans
`0x2720`, terminé par `0xFF`. **C'est exactement la passe de
culling/filtrage anticipée.**

Note amusante : `0x2720` lui-même est désassemblé comme du code juste
après cette routine (`0x2720: ADD A,B` etc.) dans une lecture linéaire —
confirme une fois de plus qu'il s'agit d'une **zone de données** située
immédiatement après le code de `0x26F7`, pas d'instructions réelles (cf.
méthodologie section 5, désambiguïsation code/données).

## Boucle principale de frame remontée (0x05AE-0x0620+)

**Statut : confirmed** par désassemblage direct — contexte le plus large
obtenu jusqu'ici sur le déroulement d'une frame de jeu.

```
05AE  DD21D700   ld     ix,00D7      ; IX = début du tableau d'entités (128 max)
05B2  310081     ld     sp,8100
05B5  CD790D     call   0D79         ; ? (par entité, à explorer)
05B8  218200     ld     hl,0082
05BB  34         inc    (hl)         ; compteur d'entités traitées
05BC  DD7E14     ld     a,(ix+14)
05BF  DD7718     ld     (ix+18),a    ; sauvegarde position courante -> "précédente"
05C2  DD7E15     ld     a,(ix+15)
05C5  DD7719     ld     (ix+19),a
05C8  DD7E16     ld     a,(ix+16)
05CB  DD771A     ld     (ix+1A),a
05CE  DD7E17     ld     a,(ix+17)
05D1  DD771B     ld     (ix+1B),a
05D4  DD6E00     ld     l,(ix+00)    ; L = type/ID de sprite de cette entité
05D7  017606     ld     bc,0676
05DA  EF         rst    28           ; RST 28 avec BC=0x0676 -- vecteur à
                                     ; élucider (probablement dispatch par
                                     ; type de sprite, logique/IA par entité)
05DB  ED5F       ld     a,r          ; lit le registre R (compteur d'interruptions,
                                     ; souvent utilisé comme source de "hasard")
05DD  4F         ld     c,a
05DE  3A6D00     ld     a,(006D)
05E1  81         add    a,c
05E2  326D00     ld     (006D),a     ; accumulateur pseudo-aléatoire basé sur R
05E5  011C00     ld     bc,001C
05E8  DD09       add    ix,bc        ; IX += 28 (entité suivante)
05EA  DDE5       push   ix
05EC  E1         pop    hl
05ED  013705     ld     bc,0537
05F0  A7         and    a
05F1  ED42       sbc    hl,bc
05F3  3002       jr     nc,05F7      ; si IX >= 0x0537 (fin du tableau, 128 entités) -> continue
05F5  18BB       jr     05B2         ; sinon boucle sur l'entité suivante

05F7  2A6A00     ld     hl,(006A)
05FA  23         inc    hl
05FB  226A00     ld     (006A),hl    ; incrémente un compteur global (frame ? tick ?)
05FE  3A6D00     ld     a,(006D)
0601  86         add    a,(hl)
0602  85         add    a,l
0603  84         add    a,h
0604  326D00     ld     (006D),a     ; mélange encore l'accumulateur pseudo-aléatoire
0607  217800     ld     hl,0078
060A  CBC6       set    0,(hl)       ; positionne un flag bit 0 à (0x0078)
060C  CD6D2D     call   2D6D         ; ? (à explorer)
060F  CD8811     call   1188         ; ?
0612  CDF726     call   26F7         ; <- REMPLIT 0x2720 (culling, voir ci-dessus)
0615  CDE22D     call   2DE2         ; boucle de rendu (efface+dessine, voir ci-dessus)
0618  3A8400     ld     a,(0084)
...
```

**Interprétation d'ensemble** : c'est la vraie boucle de frame du jeu.
Pour CHAQUE entité (jusqu'à 128), avant tout rendu : sauvegarde sa
position en "précédente", puis exécute une routine par-entité via `RST
28` (dispatch probable selon le type, logique de jeu/IA/physique — pas
encore désassemblée), et alimente un accumulateur pseudo-aléatoire à
partir du registre R (technique classique 8-bit pour obtenir de
l'aléatoire sans vrai générateur matériel). Une fois toutes les entités
mises à jour, un compteur global est incrémenté, puis vient le culling
(`0x26F7`) et le rendu (`0x2DE2`).

## Prochaines pistes prioritaires (mise à jour 2)

1. **Désassembler le vecteur `RST 28`** (adresse `0x0028`, déjà vue dans
   le vecteur RST bas — `JP HL` indirect avec BC comme paramètre,
   probablement une table de dispatch par type d'entité comme 0x429E
   mais pour la LOGIQUE plutôt que le rendu). **FAIT** (voir plus haut).
2. **Désassembler `0x0D79`, `0x2D6D`, `0x1188`** — trois routines
   appelées une fois par frame, rôle encore inconnu. **FAIT** (voir plus
   haut).
3. Continuer le pipeline dense de `0x2F17+` (sélection de routine de blit
   par largeur) — toujours en attente d'un traçage pas-à-pas. **FAIT**
   (voir section "0x2D5E et 0x2F8D+" ci-dessous).
4. Désassembler `0x31E9` et `0x429E` (tables de sprite). **FAIT** (voir
   plus haut).

## 0x2D5E et 0x2F8D+ : multiplication 8×8 + blit masqué avec transparence

**Statut : confirmed** par désassemblage direct.

### 0x2D5E — Multiplication 8×8→16 bits (shift-and-add classique)

```
2D5E  C5         push   bc
2D5F  210000     ld     hl,0000
2D62  0608       ld     b,08
2D64  29         add    hl,hl      ; HL ×= 2
2D65  07         rlca              ; décale A, teste le bit sortant
2D66  3001       jr     nc,2D69
2D68  19         add    hl,de      ; si bit posé, HL += DE
2D69  10F9       djnz   2D64       ; répète 8 fois (8 bits de A)
2D6B  C1         pop    bc
2D6C  C9         ret
```
= `HL = A × DE` (multiplication 8×16→16 bits par décalage, algorithme
shift-and-add standard). Utilisée dans `0x31E9` (flip de sprite) pour
calculer la taille totale en octets du sprite (largeur × hauteur) avant
l'échange de paires.

### 0x2F8D+ — Blit de sprite AVEC MASQUE (transparence)

**Découverte majeure**, confirme le mécanisme de transparence du rendu.
Motif répété (bloc de 8 instructions / 16 octets) vu dans `0x2F8D-0x2FE0` :

```
1A         ld     a,(de)     ; charge un octet du masque/forme source, avance DE
13         inc    de
6F         ld     l,a
0A         ld     a,(bc)     ; lit l'octet ÉCRAN actuel (fond derrière le sprite)
A6         and    (hl)       ; ET avec (HL) -- 1er plan (masque AND, efface les
                              ; pixels qui seront remplacés par le sprite)
24         inc    h
B6         or     (hl)        ; OU avec (HL) -- 2e plan (couleur du sprite,
                              ; ajoutée aux pixels du fond conservés)
24         inc    h
02         ld     (bc),a      ; écrit le résultat à l'écran
0C         inc    c           ; colonne suivante
```
= technique classique **"mask-then-or"** pour du sprite avec transparence
sur fond CPC : `écran = (écran AND masque) OR couleur`. `HL` (avant
chaque `INC H`) pointe successivement vers le plan masque (page N) puis
couleur (page N+1) — deux banques adjacentes de 256 octets (`INC H` sans
toucher L = saut de page entière), probablement les deux moitiés d'une
zone de sprite pré-calculée où chaque forme a son masque ET sa couleur
stockés en pages consécutives. Motif répété une fois par colonne de la
largeur du sprite (déroulage/loop-unrolling comme `0x1DC1`, cohérent avec
la sélection dynamique de variante par largeur patchée en `0x2F5F` vue
précédemment — `0x2F8D` est le DÉBUT d'une série de variantes, chacune
gérant une largeur fixe différente sans boucle interne).

**Conclusion sur le pipeline de rendu complet** : le moteur ne dessine
JAMAIS un sprite en écrasant bêtement les pixels — il applique toujours
un masque pour préserver le fond hors de la silhouette réelle du sprite
(essentiel pour un rendu isométrique où les formes ne sont pas
rectangulaires). Combiné à la routine de flip en place (`0x31E9`), le
pipeline complet de dessin d'une entité est maintenant : projection
isométrique (`0x2EDC`) → résolution de forme + flip si besoin (`0x2F02`/
`0x31E9`) → sélection de la variante de blit par largeur (patch dynamique
en `0x2F5F`) → blit masqué colonne par colonne (`0x2F8D`+ et ses
variantes voisines).

## RST 28 élucidé : dispatch générique par table (JP indirect calculé)

**Statut : confirmed** par désassemblage direct.

```
0028  2600       ld     h,00
002A  29         add    hl,hl       ; HL = L×2 (index de table, word par entrée)
002B  09         add    hl,bc       ; + base de table (passée dans BC par l'appelant)
002C  7E         ld     a,(hl)
002D  23         inc    hl
002E  66         ld     h,(hl)
002F  6F         ld     l,a         ; HL = pointeur lu dans la table
0030  E9         jp     hl          ; saut indirect
```
= `JP (table[L])` où `table` est passée en `BC`. Signature identique à
`0x2F02` (résolution de forme par type de sprite) mais généralisée avec
la base de table en paramètre plutôt que fixée en dur — utilisée comme
primitive de dispatch générique, réutilisable pour n'importe quelle
table indexée par le même type d'ID.

**Table de logique par type d'entité, base 0x0676** (appelée depuis la
boucle principale de frame avec `L=(ix+00)`, `BC=0x0676`) — pendant
logique/IA de la table de rendu `0x429E`. Premières entrées (20 lues) :
`0x0895, 0x0895, 0x1FFC, 0x1FE2, 0x1FFC, 0x1FE2, 0x1D8F, 0x1D8F, 0x1F35,
0x1FA6, 0x1D94, 0x1D99, 0x1D9E, 0x1D9E, 0x1D9E, 0x1D9E, 0x20CB, 0x20CB,
0x20CB, 0x20CB` — plusieurs types d'entités consécutifs partagent la
même routine (paires, groupes de 4), cohérent avec des variantes d'un
même type (orientations, sous-types).

## Boucle principale de frame — synthèse structurelle

Ordre confirmé des opérations par frame (voir `0x05AE-0x0620`) :
1. **Pour chaque entité (jusqu'à 128)** : sauvegarde position→précédente,
   dispatch logique/IA via `RST 28` (table `0x0676`), mise à jour d'un
   accumulateur pseudo-aléatoire basé sur le registre R.
2. Incrément d'un compteur global de frame `(0x006A)`.
3. Trois routines non explorées (`0x2D6D`, `0x1188`) — à faire.
4. **Culling** (`0x26F7`) : filtre les 40 premières entités (type≠0 ET
   bit 4 de `(ix+07)` actif) dans le buffer `0x2720`.
5. **Rendu** (`0x2DE2`) : pour chaque entité du buffer filtré, efface
   l'ancienne empreinte puis dessine à la nouvelle position (via
   `0x2EDC` projection isométrique + `0x2EC0` blit).

C'est une structure de boucle de jeu très classique (update logique
toutes entités → culling → rendu), cohérente avec ce qu'on attendrait
d'un moteur de jeu 8-bit optimisé.

## LOGIQUE DU JOUEUR : routine 0x20CB (type d'entité 0x12), première analyse

**Statut : hypothesis sur l'interprétation, désassemblage direct
confirmé, ET confirmation empirique partielle (mouvement de (ix+01)).**

Résolue via `RST 28` avec `BC=0x0676`, `L=(ix+00)=0x12` (type de
l'entité 0 = joueur). Table `0x0676+0x12*2` → pointeur `0x20CB`,
correspond exactement aux 4 entrées identiques (`0x20CB` répété ×4) déjà
notées dans le dump de la table.

```
20CB  CD891D     call   1D89       ; ou 1DA8 selon bit 6 de (ix+0D)
20CE  1803       jr     20D3
20D0  CDA81D     call   1DA8
20D3  DDCB0D76   bit    6,(ix+0D)
20D7  280D       jr     z,20E6
...
20E6  CDB01B     call   1BB0       ; plusieurs sous-routines par-frame du joueur
20E9  CDB728     call   28B7       ; (non explorées : gravité ? collision sol ?)
20EC  CDAA18     call   18AA
20EF  CD4721     call   2147       ; <- lecture input + résolution direction
20F2  CDF021     call   21F0
20F5  CD1422     call   2214
20F8  CD2221     call   2122       ; teste si le joueur est dans les limites visibles
20FB  3018       jr     nc,2115
20FD  DDCB23CE   set    1,(ix+23)  ; verrou temporaire pendant 0x2253
2101  CD5322     call   2253
2104  DDCB238E   res    1,(ix+23)
2108  DD7E0C     ld     a,(ix+0C)
210B  D610       sub    10
210D  3803       jr     c,2112
210F  DD770C     ld     (ix+0C),a  ; décrémente un compteur (ix+0C) par pas de 0x10
2112  C37B1F     jp     1F7B
```

### 0x2122 — Test des limites visibles (culling caméra ?)

```
2122  2A7100     ld     hl,(0071)   ; position de référence globale (caméra ?)
2125  7D         ld     a,l
2126  DD9604     sub    (ix+04)     ; - offset de l'entité
2129  6F         ld     l,a
212A  7C         ld     a,h
212B  DD9605     sub    (ix+05)
212E  67         ld     h,a
212F  DD7E01     ld     a,(ix+01)   ; compare à |(ix+01)-0x80| et |(ix+02)-0x80|
2132  D680       sub    80
2134  F23921     jp     p,2139
2137  ED44       neg
2139  BD         cp     l
213A  D0         ret    nc          ; hors limite -> ret avec carry clear
213B  DD7E02     ld     a,(ix+02)
213E  D680       sub    80
2140  F24521     jp     p,2145
2143  ED44       neg
2145  BC         cp     h
2146  C9         ret                ; carry set si dans les limites
```
Compare la distance de l'entité (par rapport au centre `0x80`) à une
zone déterminée par `(0x0071)` et les offsets `(ix+04)/(ix+05)` — très
probablement un **test de proximité caméra/écran visible**, similaire en
esprit au clipping déjà vu dans la boucle de rendu (`0x2E5E: cp C0`).

### 0x2147 — Lecture input et résolution de direction (LA routine de contrôle)

```
2147  216C00     ld     hl,006C     ; (0x006C) = état input global (bits de direction ?)
214A  7E         ld     a,(hl)
214B  E602       and    02
214D  284B       jr     z,219A      ; bit1=0 -> saut (animation/pas de mouvement)
214F  CB5E       bit    3,(hl)
2151  2847       jr     z,219A
2153  DD7E0C     ld     a,(ix+0C)
2156  E6F0       and    F0
2158  C0         ret    nz          ; timer de cooldown actif -> ignore l'input
2159  DDCB0C56   bit    2,(ix+0C)
215D  C8         ret    z
215E  CB41       bit    0,c         ; teste C bit par bit : 4 directions
2160  2004       jr     nz,2166
2162  CB51       bit    2,c
2164  200F       jr     nz,2175
2166  CB49       bit    1,c
2168  2017       jr     nz,2181
216A  CB61       bit    4,c
216C  201A       jr     nz,2188
216E  CB41       bit    0,c
2170  201F       jr     nz,2191
2172  CB91       res    2,c
2174  C9         ret
2175  CDD022     call   22D0        ; résout orientation actuelle (voir 0x22D0)
2178  FE02       cp     02
217A  281B       jr     z,2197
...
21CF  DD7E00     ld     a,(ix+00)
21D2  EE08       xor    08          ; bascule le TYPE de sprite (bit 3) -- change
21D4  DD7700     ld     (ix+00),a   ; carrément de forme selon la direction, pas
                                    ; juste un flip (deux jeux de sprites distincts)
21D7  DD7E07     ld     a,(ix+07)
21DA  EE40       xor    40          ; bascule un bit du flag -- second axe d'orientation
21DC  DD7707     ld     (ix+07),a
21DF  DD7E00     ld     a,(ix+00)
21E2  C610       add    a,10
21E4  DD771C     ld     (ix+1C),a  ; enregistre le type "en cours d'animation" ?
```
**`C` (le registre bas de `BC`) code la direction demandée** en bitmask
(bit0/bit2/bit1/bit4 testés successivement) — probablement passé par
l'appelant (à tracer : d'où vient `C` avant l'appel à `0x20CB`, sûrement
dérivé de `(0x006C)` ou d'un registre clavier scanné séparément).

**Effet confirmé empiriquement** : la touche "avancer" (S) fait
diminuer `(ix+01)` de l'entité joueur par pas de 3 (0x80→0x7D→0x7A→
0x77→0x74 sur 6 appuis, cohérent avec le pas ±3 vu dans `0x22E4-0x230A`
qui modifie `(ix+09)/(ix+0A)` — la vraie coordonnée modifiée observée
est `(ix+01)` directement, pas `(ix+09)/(ix+0A)` qui restent à 0 dans ce
test, donc soit la vélocité est appliquée et remise à 0 dans le même
tick sans qu'on l'attrape entre deux dumps HTTP, soit `(ix+09)/(ix+0A)`
servent à autre chose — **à revérifier avec un breakpoint synchronisé
plutôt qu'un polling manuel**, cf. méthodologie).

### 0x22D0 — Résolution de code d'orientation (2 bits, depuis type+flag)

```
22D0  DD7E07     ld     a,(ix+07)
22D3  0F         rrca
22D4  0F         rrca
22D5  E610       and    10
22D7  6F         ld     l,a
22D8  DD7E00     ld     a,(ix+00)
22DB  E608       and    08
22DD  B5         or     l
22DE  0F         rrca
22DF  0F         rrca
22E0  0F         rrca
22E1  E603       and    03
22E3  C9         ret
```
Combine le bit 4 de `(ix+07)` et le bit 3 de `(ix+00)` en un code
d'orientation 0-3 (2 bits) — confirme que l'orientation du personnage
est encodée à cheval sur DEUX champs distincts (type de sprite ET flag),
pas dans un seul octet dédié — cohérent avec `0x21CF/0x21D7` qui les
modifient tous les deux ensemble à chaque changement de direction.

## Tentative infructueuse : tracer l'origine exacte de C (registre direction)

**Statut : non résolu — limite méthodologique rencontrée, documentée
honnêtement plutôt que de forcer une conclusion non vérifiée.**

Deux approches tentées pour capturer la valeur de `C` au moment précis
du test `BIT 0,C` (`0x215E`), sans succès :

1. **Breakpoint direct sur `0x215E`** (~150 polls de 20ms = 3s
   d'attente, avec envoi simultané de 20 répétitions de la touche "S") :
   ne s'est jamais déclenché. Pourtant le mouvement du joueur continue de
   fonctionner pendant ce test (vérifié séparément) — donc soit le garde
   `(ix+0C) AND 0xF0` (cooldown) bloque presque tout le temps l'exécution
   de ce chemin précis, soit le déplacement emprunte un autre chemin de
   code que celui lu dans le désassemblage statique.
2. **Single-step depuis `0x20CB`** (breakpoint d'entrée réussi, puis
   step-by-step) : après 150 pas, le flux était encore dans les toutes
   premières sous-routines (`0x1BB0`, `0x28B7`/`0x28C1`) — jamais arrivé
   à `0x2147`. Une deuxième tentative de 400 pas s'est retrouvée bloquée
   dans la boucle d'attente matérielle `0x0ED3`/`0x0EDD`/`0x0D84` (lecture
   clavier via PSG, DI/EI + polling de statut) sans progresser vers
   `0x2147` non plus.

**Conclusion honnête** : soit la routine de lecture d'input du joueur
emprunte un chemin différent de `0x2147` dans ce contexte précis (peut-
être que `0x2147` n'est appelée que sous certaines conditions non
remplies pendant ces tests — ex. uniquement après un certain compteur de
frames, ou seulement si le joueur n'est pas déjà en mouvement), soit le
coût en pas Z80 réels pour atteindre ce point est simplement trop élevé
pour cette méthode de traçage sur cet environnement HTTP. **Ne pas
prendre pour acquis que `C` vient bien de `(0x006C)` tel que lu
initialement** — c'était une hypothèse de lecture du désassemblage
statique (`0x2147: LD HL,006C / LD A,(HL)`), jamais confirmée
dynamiquement. Cette hypothèse reste la plus probable vu le
désassemblage, mais son statut doit rester `hypothesis`, pas `confirmed`.

**Piste alternative pour une prochaine session** : plutôt que de tracer
depuis l'intérieur de la routine du joueur, poser un breakpoint
directement sur l'écriture de `(0x006C)` n'est pas possible (pas de
watchpoint mémoire dans l'API MCP actuelle) — mais on pourrait chercher
dans le code les instructions `LD (006C),...` par une recherche de motif
sur un dump RAM complet désassemblé bloc par bloc, ou tracer depuis la
routine de scan clavier bas niveau elle-même (`0x0D84`/`0x0DBD`) en
remontant vers ses appelants avec `z80_history`, plutôt que de descendre
depuis `0x20CB`.

## RÉSOLU (session suivante, désassemblage de 0x28B7) : la vraie routine de lecture d'input

**Statut : confirmed** par désassemblage direct — répond enfin à la
question laissée ouverte ci-dessus.

En désassemblant la suite de la routine de collision (`0x2750`), on
tombe sur `0x28B7`, appelée juste après le traitement des collisions
(`0x28A4: call 2F17` puis retour à la boucle) — **c'est la vraie
routine de scan input, exécutée une fois par frame dans ce contexte
(pas dans `0x20CB` comme on cherchait précédemment)** :

```
28B7  3A8900     ld     a,(0089)
28BA  4F         ld     c,a
28BB  3A8A00     ld     a,(008A)
28BE  B1         or     c
28BF  0E00       ld     c,00
28C1  C20129     jp     nz,2901     ; si (0089) ou (008A) non-nul -> mode spécial (0x2901)
28C4  3A6C00     ld     a,(006C)
28C7  E602       and    02
28C9  2847       jr     z,2912      ; bit 1 de (006C) = 0 -> mode JOYSTICK (0x2912)
                                    ; bit 1 = 1 -> mode CLAVIER (suite ci-dessous)
; --- mode clavier : deux lectures de ligne clavier PSG, combinées ---
28CB  3E06       ld     a,06
28CD  CDD30E     call   0ED3        ; lit la ligne clavier n°6 (scan PSG)
28D0  4F         ld     c,a
28D1  C5         push   bc
28D2  3E09       ld     a,09
28D4  CDD30E     call   0ED3        ; lit la ligne clavier n°9
28D7  C1         pop    bc
28D8  B1         or     c
28D9  0E00       ld     c,00
28DB  CB47       bit    0,a
28DD  2802       jr     z,28E1
28DF  CBD1       set    2,c         ; bit0 du scan -> bit2 de C  (direction 1)
28E1  CB4F       bit    1,a
28E3  2802       jr     z,28E7
28E5  CBE1       set    4,c         ; bit1 -> bit4 de C          (direction 2)
28E7  CB57       bit    2,a
28E9  2802       jr     z,28ED
28EB  CBC1       set    0,c         ; bit2 -> bit0 de C          (direction 3)
28ED  CB5F       bit    3,a
28EF  2802       jr     z,28F3
28F1  CBC9       set    1,c         ; bit3 -> bit1 de C          (direction 4)
28F3  CB67       bit    4,a
28F5  2802       jr     z,28F9
28F7  CBD9       set    3,c         ; bit4 -> bit3 de C          (action ?)
28F9  CB6F       bit    5,a
28FB  2802       jr     z,28FF
28FD  CBE9       set    5,c         ; bit5 -> bit5 de C          (action ?)
28FF  1800       jr     2901

; --- 0x2901 : lit une 3e ligne clavier (ou fusionne le mode spécial), stocke le résultat ---
2901  3E05       ld     a,05
2903  C5         push   bc
2904  CDD30E     call   0ED3        ; lit la ligne clavier n°5
2907  C1         pop    bc
2908  0F         rrca
2909  0F         rrca
290A  E620       and    20
290C  B1         or     c
290D  4F         ld     c,a
290E  327B00     ld     (007B),a    ; <-- RÉSULTAT FINAL stocké à (0x007B), PAS (0x006C) !
2911  C9         ret

; --- mode joystick (si bit1 de (006C) == 0) : 5 tables de masques bit ---
2912  215C29     ld     hl,295C
2915  CD4629     call   2946
2918  2802       jr     z,291C
291A  CBC1       set    0,c
291C  216929     ld     hl,2969
...                                 ; 5 tables successives (2946 appelée 5×),
                                    ; chacune positionnant un bit distinct de C
                                    ; (bit0..bit4) -- 5 directions/actions
2944  18BB       jr     2901        ; rejoint le flux commun, stocke dans (0x007B)

; --- 0x2946 : teste une table de (ligne_clavier, masque) terminée par 0xFF ---
2946  0600       ld     b,00
2948  7E         ld     a,(hl)
2949  23         inc    hl
294A  FEFF       cp     FF
294C  280B       jr     z,2959      ; fin de table -> B = résultat accumulé
294E  C5         push   bc
294F  CDD30E     call   0ED3        ; lit la ligne clavier (A = numéro)
2952  C1         pop    bc
2953  A6         and    (hl)        ; masque avec l'octet suivant de la table
2954  23         inc    hl
2955  B0         or     b           ; accumule dans B
2956  47         ld     b,a
2957  18EF       jr     2948
2959  78         ld     a,b
295A  A7         and    a
295B  C9         ret
```

**Tables de masques du mode joystick (0x295C-0x2988), décodées** —
chaque table = liste de paires (ligne clavier, masque bit), terminée
par `0xFF` :
```
table 1 (bit0, direction ?) : (8,0x80) (7,0x40) (6,0x40) (4,0x40) (3,0x80) (2,0x40)
table 2 (bit1, direction ?) : (7,0x80) (6,0x80) (5,0x40) (4,0x80) (3,0x40)
table 3 (bit2, direction ?) : (8,0x20) (7,0x30) (6,0x30) (5,0x30) (4,0x30) (3,0x30) (2,0x08)
table 4 (bit3, direction ?) : (8,0x08) (7,0x0C) (6,0x0C) (5,0x0C) (4,0x0C) (3,0x0C) (2,0x02)
table 5 (bit4, action ?)    : (8,0x03) (7,0x03) (6,0x03)
```
Chaque table teste plusieurs lignes de la matrice clavier CPC (le
joystick CPC standard est câblé pour partager les lignes de scan avec
le clavier — un ou plusieurs bits de plusieurs lignes différentes selon
le modèle/port de joystick), confirmant que `0x2946` gère à la fois
clavier ET joystick physique selon le même mécanisme bas niveau
(`0x0ED3` = lecture d'une ligne de matrice).

**Correction majeure par rapport à l'hypothèse précédente** : le résultat
de la lecture d'input est stocké à **`(0x007B)`**, pas `(0x006C)` comme
supposé initialement en lisant `0x2147` de manière isolée. `(0x006C)`
sert de **sélecteur de mode** (bit 1 : clavier vs joystick) et
`(0x0089)`/`(0x008A)` de garde pour un mode spécial non encore exploré
(`0x2901` direct). Il faudra revérifier `0x2147` (dans la logique du
joueur) à la lumière de cette découverte — soit il lit `(0x007B)` sous
un autre nom d'adresse mal recopié, soit il y a deux registres d'input
différents pour deux besoins différents (input brut vs input "consommé
une fois par frame").

## Prochaines pistes prioritaires (mise à jour 3 — logique de jeu)

1. **Retracer avec un breakpoint synchronisé** (pas du polling manuel)
   l'effet exact d'une pression de touche sur `(ix+01)` ET `(ix+09)/
   (ix+0A)` pour comprendre le rôle exact de la paire "vélocité" par
   rapport à la coordonnée de grille directe.
2. **Trouver l'origine de `C`** dans `0x20CB` — qui la remplit avant
   l'appel (probablement dans la boucle `0x05AE`, à tracer), et le lien
   avec `(0x006C)` (registre d'état input global).
3. **Désassembler `0x1D89`/`0x1DA8`/`0x1BB0`/`0x28B7`/`0x18AA`/`0x21F0`/
   `0x2214`/`0x2253`** — sous-routines du joueur non explorées (gravité,
   collision, animation).
4. **Comparer avec la logique d'un bloc/objet non-joueur** (une autre
   entrée de la table `0x0676`, ex: `0x0895` vu deux fois en tête de
   table) pour voir en quoi la logique du joueur diffère de celle des
   objets statiques/mobiles.

## Trois routines par-frame élucidées (0x0D79, 0x2D6D, 0x1188)

**Statut : hypothesis raisonnable, désassemblage direct confirmé** — pas
de vérification comportementale poussée sur celles-ci (moins critiques
pour le rendu que les précédentes).

### 0x0D79 — Armement d'un flag de synchronisation + EI

```
0D79  FB         ei
0D7A  3E01       ld     a,01
0D7C  326F00     ld     (006F),a
0D7F  C9         ret
```
Active les interruptions et positionne `(0x006F)=1`. `0x0D84` (voisine)
fait `DI` puis teste `(0x006F)` : renvoie tôt si nul, sinon `EI` — donc
`(0x006F)` s'apparente à un flag "interruptions permises/synchro prête",
consommé ailleurs. **Hypothèse** : synchronisation avec l'interruption
vidéo (VSYNC) ou le scan clavier périodique — cohérent avec le fait que
les routines voisines (`0x0D8C`/`0x0DA7`) pilotent directement des ports
d'IO (`0xF400`/`0xF600`/`0xF700` — ports PSG/CRTC classiques du CPC,
utilisés notamment pour le scan clavier via le PSG AY-3-8912).

### 0x2D6D — Attente de synchronisation (probable scan clavier/PSG)

```
2D6D  3E02       ld     a,02
2D6F  CDD30E     call   0ED3      ; lit un statut (A=2 = sélection ?)
2D72  CB6F       bit    5,a
2D74  C8         ret    z
; boucle : attend bit5=0 puis bit5=1 (deux transitions)
```
`0x0ED3` (routine appelée) fait `DI`, appelle `0x0EDD` (qui appelle
`0x0DBD` — pilotage ports PSG/CRTC vus ci-dessus) puis `0x0D84`, `EI`.
**Hypothèse forte** : `0x2D6D` attend une transition de statut
correspondant au scan clavier du CPC (le clavier est lu via le PSG sur
CPC — méthode standard), synchronisant la lecture d'input avec le
rythme d'interruption plutôt que de la faire à un moment arbitraire de
la frame. Pas vérifié par test comportemental (ex: bloquer l'input et
voir si la fonction boucle indéfiniment) — **à faire si besoin de
certitude supérieure**.

## Tables de sprite 0x429E et 0x31E9 : dispatch + logique de miroir/flip

**Statut : hypothesis sur l'interprétation, désassemblage direct confirmé.**

### 0x429E — Table de pointeurs de sprite (32 entrées lues)

`0x4422, 0x4422, 0x5AC6, 0x5C01, 0x6197, 0x6286, 0x5678, 0x59DB, 0x7BD7,
0x7BD7, 0x5ED5, 0x5FD2, 0x6065, 0x5C90, 0x5D4F, 0x5E12, 0x6BC0, 0x6C23,
0x6C86, 0x6CE9, 0x6C86, 0x6C23, 0x7DB9, 0x5595, 0x6D4C, 0x6DB5, 0x6E1E,
0x6E87, 0x6E1E, 0x6DB5, 0x4BA0, 0x4C2D` — pointeurs vers des zones de
données dispersées en RAM haute (0x4000-0x7FFF, bank 1). Plusieurs
motifs de symétrie visibles (`0x6C86,0x6CE9,0x6C86,0x6C23` — palindrome
partiel) suggèrent des variantes liées d'un même sprite plutôt que des
formes indépendantes — cohérent avec l'hypothèse de flip/miroir ci-dessous.

### 0x31E9 — Logique de flip/miroir de sprite en place

**Découverte importante.** Testée quand le premier octet de la donnée de
sprite (`(DE)`, résolu via `0x429E`) est non-nul (cf. `0x2F0F-0x2F11`).

```
31E9  D5         push   de
31EA  1A         ld     a,(de)
31EB  DDAE07     xor    (ix+07)   ; compare l'octet de données au flag
                                  ; d'entité (ix+07) -- teste si ils diffèrent
31EE  E680       and    80        ; sur le bit 7
31F0  282E       jr     z,3220    ; si identiques -> pas de flip nécessaire, passe au bit 6
31F2  1A         ld     a,(de)
31F3  EE80       xor    80        ; sinon, inverse le bit 7 des données stockées
31F5  12         ld     (de),a    ; (marque "déjà flippé dans ce sens")
31F6  E63F       and    3F        ; B = taille du sprite (masqué sur 6 bits)
31F8  47         ld     b,a
31F9  13         inc    de
31FA  1A         ld     a,(de)
31FB  4F         ld     c,a       ; C = hauteur ?
31FC  13         inc    de
31FD  13         inc    de
31FE  D5         push   de
31FF  58         ld     e,b
3200  1600       ld     d,00
3202  CD5E2D     call   2D5E      ; calcule un décalage (à explorer)
3205  D1         pop    de
3206  19         add    hl,de
3207  EB         ex     de,hl
3208  78         ld     a,b
3209  CF         rst    08        ; HL += B
320A  1B         dec    de
320B  2B         dec    hl
320C  CB39       srl    c
320E  C5         push   bc
320F  1A         ld     a,(de)    ; --- boucle d'échange par paires ---
3210  4E         ld     c,(hl)
3211  77         ld     (hl),a
3212  79         ld     a,c
3213  12         ld     (de),a    ; échange (DE) <-> (HL)
3214  2B         dec    hl
3215  1B         dec    de
3216  10F7       djnz   320F      ; répète B fois (largeur du sprite)
3218  C1         pop    bc
3219  78         ld     a,b
321A  CB27       sla    a
321C  CF         rst    08
321D  0D         dec    c
321E  20EE       jr     nz,320E   ; répète pour chaque ligne (C/2 lignes)
3220  D1         pop    de
; --- même logique répétée pour le bit 6 (autre axe de flip ?) ---
3221  D5         push   de
3222  1A         ld     a,(de)
3223  DDAE07     xor    (ix+07)
3226  E640       and    40
3228  2839       jr     z,3263
322A  1A         ld     a,(de)
322B  EE40       xor    40
322D  12         ld     (de),a
322E  13         inc    de
322F  E63F       and    3F
```

**Interprétation** : c'est une routine de **flip/miroir de sprite EN
PLACE** (modifie directement les données stockées, pas une copie) —
échange les octets par paires symétriques (boucle `DEC HL`/`DEC DE`
convergents), pour un total de B×C/2 échanges. Le bit 7 de `(ix+07)`
pilote un axe de flip (probablement horizontal), le bit 6 (logique
symétrique juste après) pilote probablement l'autre axe (vertical) ou
une rotation. Le premier octet de la donnée de sprite sert de **marqueur
d'état courant du flip** (comparé au flag de l'entité pour savoir si un
nouveau flip est nécessaire) — évite de re-flipper à chaque frame si
l'orientation n'a pas changé depuis la dernière fois.

**Cohérence avec 0x2F23** (`RES 4,(ix+07)` vu dans le pipeline de dessin)
: probablement un bit distinct (bit 4) contrôlant si le flip doit être
recalculé ce tour, séparé des bits 6/7 qui encodent l'orientation cible.

**Économie de mémoire clé** : au lieu de stocker deux sprites séparés
(miroir gauche/droite), le jeu stocke UNE forme et la flippe en place
à la demande — explique pourquoi 0x429E a des pointeurs répétés/liés
entre entrées voisines (variantes d'orientation d'un même sprite de
base).

### 0x1188 — Initialisation conditionnelle (probable premier tour de room)

```
1188  3ADF00     ld     a,(00DF)
118B  FE88       cp     88
118D  C0         ret    nz        ; si (0x00DF) != 0x88 -> ne fait rien
118E  112B01     ld     de,012B
1191  1A         ld     a,(de)
1192  A7         and    a
1193  C0         ret    nz        ; si (0x012B) != 0 -> ne fait rien
1194  3A8900     ld     a,(0089)
1197  A7         and    a
1198  C0         ret    nz        ; si (0x0089) != 0 -> ne fait rien
1199  21A711     ld     hl,11A7
119C  011200     ld     bc,0012   ; 0x12 = 18 octets à copier
119F  D5         push   de
11A0  DDE1       pop    ix
11A2  EDB0       ldir            ; copie 18 octets depuis 0x11A7 vers (de)=0x012B
11A4  C3841D     jp     1D84
```
Trois flags/gardes successifs (`(0x00DF)==0x88`, `(0x012B)==0`,
`(0x0089)==0`) avant d'exécuter une copie de 18 octets d'un template
figé (`0x11A7`) vers `0x012B`. **Hypothèse** : initialisation ponctuelle
d'une structure (nouvelle entité créée dynamiquement ? réinitialisation
d'un compteur de room ?) qui ne doit se produire qu'une fois — le triple
garde évite une réexécution à chaque frame. Rôle exact du template de 18
octets non déterminé — nécessiterait de dumper `0x11A7` et de comparer à
la structure d'entité connue (28 octets, donc ce n'est pas une entité
complète — peut-être une sous-structure ou une autre table).

## Outils / méthode

- Correction du bug de préfixe hex sur `z80_breakpoints`.
- `z80_history` après N `z80_step` groupés — méthode fiable validée deux
  fois maintenant (menu et jeu).
- `disassemble_range` sur les tables de données (`0x31B9`) pour lire les
  constantes brutes en hex plutôt que désassemblées à tort en pseudo-code
  Z80 (les deux se mélangent dans une même zone mémoire — code puis
  table de données immédiatement après, sans séparation).
