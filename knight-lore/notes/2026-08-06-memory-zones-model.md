# Modèle de mémoire global (confirmé) — proposé par l'utilisateur, vérifié par codemap

## Hypothèse (utilisateur) — À PRENDRE COMME INDICATIF, PAS COMME UN DÉCOUPAGE STRICT

**Précision importante de l'utilisateur** : l'observation des 4 zones de
16K est donnée à titre indicatif ("grosso modo"), pas comme un découpage
strict et net. En particulier, le buffer "façon texte Speccy" n'occupe
très probablement PAS la totalité des 16K de la zone 0x8000-0xC000 — sa
taille réelle reste à déterminer (probablement beaucoup plus petite,
cohérent avec une grille de cellules texte qui n'a pas besoin d'autant
d'espace). Le reste de cet intervalle sert sans doute à d'autres choses
(données de room actives, structures de jeu, etc. — non encore identifié).

Le jeu utilise une architecture mémoire visible en 4 zones **grossières**
de ~16K chacune, cohérente avec un rendu en deux temps expliqué par le
portage ZX Spectrum → CPC :

- Le ZX Spectrum a un mode d'affichage "texte" (grille de caractères
  32×24 avec attributs de couleur par cellule) qui n'existe pas nativement
  sur CPC (framebuffer bitmap direct). Le portage semble avoir conservé
  cette logique de rendu en deux étages : un premier buffer "façon
  texte/tuile" est rempli, puis converti/copié vers la VRAM réelle du CPC.
- En plus de cette couche héritée du Spectrum, il y a la couche de
  projection **isométrique** (mise en évidence précédemment :
  `fn_isometric_project`, `fn_resolve_sprite_shape`, `fn_blit_masked`)
  qui doit s'insérer quelque part dans ce pipeline à deux temps.

## Vérification par codemap (0.0000-0xFFFF, découpage en 4 zones de 16K)

**Statut : CONFIRMED** — codemap dynamique relevée pendant 3s de jeu actif
(mouvement du joueur en cours), avant/après clear :

```
code            0x0000-0x4000: 1387 adresses exécutées / 16384
ressources      0x4000-0x8000: 0 adresses exécutées / 16384
buffer texte    0x8000-0xC000: 0 adresses exécutées / 16384
VRAM            0xC000-0x10000: 0 adresses exécutées / 16384
```

**Interprétation** : la zone `0x0000-0x4000` est la SEULE contenant des
instructions machine réellement exécutées par le Z80 — cohérent avec
"tout le code du jeu tient dans les 16 premiers K". Les trois autres
zones ont zéro adresse exécutée pendant la fenêtre observée, confirmant
qu'elles sont exclusivement des zones de DONNÉES (jamais interprétées
comme du code), quel que soit leur rôle spécifique.

## Correspondance avec les découvertes déjà faites indépendamment

Ce découpage en 4 zones recoupe et unifie plusieurs symboles déjà
identifiés séparément dans `docs/SYMBOLS.md` :

| Zone | Rôle (hypothèse utilisateur) | Symboles déjà confirmés dans cette zone |
|---|---|---|
| 0x0000-0x4000 | Code | Toutes les routines `fn_*` (fn_render_entities, fn_check_collisions, fn_room_transition, etc.) |
| 0x4000-0x8000 | Ressources (sprites, tables statiques) | `tbl_object_catalog` (0x417E), `tbl_sprite_dispatch` (0x429E), données de forme de sprite dispersées (0x4422-0x7DB9 observé), `tbl_room_master_index`/`tbl_room_master_coords` (0x33D4-0x3D5D), `tbl_room_index_ptrs` (0x3E6E) |
| 0x8000-0xC000 | Buffer intermédiaire ("mode texte" hérité du Spectrum) | Buffer de travail de `fn_menu_glyph_unpack`/0x3186 (calcul `HL=(HL>>2)+0x9000`, confirmé pointer dans cette zone lors des tests du menu ET en jeu) |
| 0xC000-0x10000 | VRAM réelle CPC | Confirmé par CRTC R12/R13 (utilisateur, base 0xC000), toutes les routines de blit finales (`fn_blit_copy_line`, `fn_blit_masked`, `fn_clear_screen`) écrivent ici en dernière étape |

**Ce découpage donne un cadre de lecture clair pour la suite de
l'analyse** : toute adresse dans `0x4000-0x8000` est presque certainement
une ressource statique (sprite, table de niveau) ; toute adresse dans
`0x8000-0xC000` est un état de rendu intermédiaire (probablement la
"couche texte/tuile" émulée) ; `0xC000+` est toujours la sortie finale
vers l'écran physique.

## Piste pour clarifier le rôle exact du buffer 0x8000-0xC000

**Hypothèse à vérifier plus tard** : si ce buffer joue effectivement le
rôle d'une grille "texte" façon Spectrum (32×24 cellules de 8×8 pixels
avant projection isométrique), sa taille utile devrait être proche de
32×24×8 = 6144 octets par plan (bien inférieure aux 16K disponibles) —
à vérifier en dumpant méthodiquement cette zone et en cherchant une
structure régulière (motif répétitif tous les N octets, cohérent avec
une grille de cellules de taille fixe). Cette vérification n'a pas
encore été faite — statut de l'hypothèse détaillée : **hypothesis**, la
zone en tant que "buffer intermédiaire" est confirmée par codemap, mais
son organisation interne précise (grille de cellules texte + attributs)
reste à démontrer.

## CONFIRMÉ : le buffer intermédiaire est réécrit en continu, même sans mouvement

**Observation de l'utilisateur, vérifiée empiriquement** : le buffer
`0x8000-0xC000` change en continu, même quand le joueur ne bouge pas.

**Test effectué** : dump de `0x8000` à `0xC000` (16K), attente 0.5s (jeu
actif, aucune touche envoyée), nouveau dump, comparaison octet par octet.

**Résultat** : **57 octets modifiés** sur cette seule fenêtre de 0.5s,
dispersés entre `0x80DA` et environ `0x95F1` — confirmant une écriture
continue même à l'arrêt apparent du joueur.

**Explication trouvée** : `fn_isometric_project` (0x2EDC) est appelée en
continu (breakpoint déclenché en boucle sans aucune action), avec des
`IX` différents à chaque fois — donc **la boucle de rendu traite TOUTES
les entités actives à chaque frame**, pas seulement le joueur (objets
animés, décor mobile, etc. continuent d'être "redessinés" même si le
joueur est immobile). C'est cohérent avec l'absence de "dirty rect"
optimisé — le moteur redessine systématiquement, ce qui explique le coût
CPU déjà noté comme probable symptôme du portage (voir intro du projet).

**Confirmation que 0x3186 est la routine d'écriture dans ce buffer** :
breakpoint sur `0x3186` (8 déclenchements consécutifs, entités
différentes à chaque fois) donne des adresses source variées, dont les
destinations calculées (`(HL>>2)+0x9000`) tombent dans une fourchette
`0xACEA-0xB42A` — cohérente avec (mais pas strictement identique à) la
zone où les octets modifiés avaient été observés. **Confirme que 0x3186
est appelée une fois par entité active et par frame**, ce qui explique
le "redessin permanent" : chaque entité active, même immobile, refait
son calcul d'adresse de buffer à chaque tour de la boucle de rendu.

**Reste à élucider** : quelle routine écrit VRAIMENT les octets dans ce
buffer après le calcul d'adresse par `0x3186` (elle-même ne fait que
calculer HL, elle n'écrit rien) — probablement `fn_blit_masked`
(0x2F8D+) ou une variante, mais ciblant ce buffer intermédiaire plutôt
que la VRAM directement dans certains contextes. À tracer avec un
breakpoint sur l'écriture effective (ex: poser le breakpoint juste après
le retour de 0x3186 dans son appelant, et suivre ce qui se passe avec
HL ensuite).

## CONFIRMÉ : le buffer 0x9000-0xC000 contient une image pré-rendue de la salle (largeur 64 octets)

**Découverte de l'utilisateur** : en observant la heatmap/densité du
buffer, reconnaissance visuelle du contour de la pièce isométrique dans
la zone `0x9000-0xBFFF`, avec une largeur de ligne de **64 octets** (pas
80, donc PAS alignée sur la largeur d'écran physique CPC).

**Vérifié par dump + rendu ASCII densité (popcount par octet)** :
`0x9000-0xC000` (192 lignes de 64 octets) montre clairement :
- Un contour en losange/octogone (diagonales convergentes visibles en
  haut ~0x9080-0x9540 et en bas ~0xBA80-0xBF40) — exactement la
  signature d'une pièce vue en projection isométrique.
- Des blocs de contenu structuré à l'intérieur du losange, à intervalles
  réguliers verticaux (~0x9800, 0x9E00, 0xA600, 0xAC00, 0xB000, 0xB600)
  — cohérent avec des entités/objets/décor placés à des positions
  précises dans la salle.
- Bordures constantes `::` sur les côtés (colonnes 0-1 et 62-63 de
  chaque ligne) qui encadrent tout le buffer — probablement une marge
  ou un identifiant de ligne non lié au contenu visuel.

**Conclusion (hypothesis solide, pas encore prouvée à 100%)** : ce
buffer N'EST PAS une grille de caractères abstraite façon "mode texte
Speccy" comme l'hypothèse initiale le supposait — c'est plus probablement
un **framebuffer intermédiaire pré-blitté** contenant déjà la géométrie
ET les entités de la salle sous forme de pixels (largeur 64 octets =
probablement 128 ou 256 pixels selon le mode graphique CPC utilisé),
qui est ensuite copié/transformé vers la VRAM réelle (`0xC000+`) par une
routine de blit finale (possiblement avec un décalage/redimensionnement,
étant donné que la largeur diffère de celle de l'écran physique 80
octets/ligne).

**Prochaine étape naturelle** : comparer ce buffer avec la capture
d'écran réelle de la même salle (déjà prise, `/tmp/room44_screen.png`)
pour voir si la forme correspond visuellement (même orientation, mêmes
proportions), et chercher la routine de copie finale
buffer-intermédiaire → VRAM (probablement une simple copie ligne par
ligne avec un décalage de largeur, ou un blit avec mise à l'échelle).

## CONFIRMÉ : l'axe Y est inversé entre le buffer intermédiaire et la VRAM finale

**Observation de l'utilisateur, précisée** :

- **VRAM (0xC000+)** : orientation "normale" (standard CPC) — adresse
  basse (proche 0xC000) = coin **haut**-gauche de l'écran physique,
  adresse croissante = vers le bas de l'écran.
- **Buffer intermédiaire (0x9000+)** : orientation **inversée** —
  adresse basse (proche 0x9000) = coin **bas**-gauche de la scène
  rendue, adresse croissante = vers le **haut** de la scène.

**Preuve utilisée** : animation HUD d'un sprite soleil/lune (indicateur
de cycle jour/nuit, visible dans le coin bas-droit de l'écran final).
Suivi de sa position dans le buffer intermédiaire sur 5 frames
consécutives : adresses `0x902E, 0x906E, 0x90AE, 0x90EE, 0x912E` (colonne
fixe 46, largeur de ligne 64), soit lignes `0, 1, 2, 3, 4` — progression
strictement croissante en adresse au fil du temps. Si le buffer avait la
même orientation que la VRAM (adresse croissante = vers le bas), ce
sprite bas-droit de l'écran serait resté proche du MAXIMUM d'adresse
(~0xBFxx), pas du minimum (~0x90xx) dès le début de l'animation.

**Conséquence pour la suite** : la routine de copie finale
buffer-intermédiaire → VRAM doit nécessairement faire un **flip
vertical** en plus de tout changement de largeur de ligne (déjà noté :
64 octets/ligne dans le buffer vs ~80 dans la VRAM Mode 1 standard CPC)
— probablement implémentée par une boucle qui décrémente un pointeur
source (lit le buffer de la fin vers le début) pendant qu'elle
incrémente un pointeur destination (écrit la VRAM du début vers la fin),
ou l'inverse. C'est une signature de code reconnaissable à chercher :
`DEC HL` / `INC DE` (ou l'inverse) dans la même boucle de copie, avec
des largeurs de ligne différentes entre les deux (64 vs ~80).

## CONFIRMÉ : fn_blit_copy_line (0x2EC0) est la routine de flip Y + entrelacement CRTC

**Statut : CONFIRMED** par désassemblage direct — exactement la
signature prédite ci-dessus.

```
2EC0  C5         push   bc
2EC1  E5         push   hl
2EC2  D5         push   de
2EC3  0600       ld     b,00
2EC5  EDB0       ldir              ; copie C octets (largeur fixée par appelant)
2EC7  D1         pop    de
2EC8  210008     ld     hl,0800   ; +0x0800 = saut standard entrelacement CRTC CPC
2ECB  19         add    hl,de
2ECC  3004       jr     nc,2ED2   ; si pas de dépassement, direct
2ECE  1150C0     ld     de,C050   ; sinon, correction fin-de-bande CRTC (+0xC050)
2ED1  19         add    hl,de
2ED2  EB         ex     de,hl     ; DE = nouvelle destination VRAM (ligne suivante,
                                  ;      gère l'entrelacement standard CPC Mode 1)
2ED3  E1         pop    hl
2ED4  01C0FF     ld     bc,FFC0   ; BC = -64 (0xFFC0 en complément à 2)
2ED7  09         add    hl,bc     ; HL -= 64  <-- SOURCE RECULE DE LA LARGEUR DU BUFFER
2ED8  C1         pop    bc
2ED9  10E5       djnz   2EC0      ; boucle sur B lignes
2EDB  C9         ret
```

**Confirme numériquement et exactement** :
1. **Largeur du buffer intermédiaire = 64 octets** (`0xFFC0` = -64 en
   complément à 2) — exactement la valeur que l'utilisateur avait
   identifiée visuellement.
2. **Flip vertical explicite** : le pointeur SOURCE (buffer
   intermédiaire) recule de 64 à chaque ligne (`HL -= 64`), donc il est
   parcouru de la fin vers le début — alors que le pointeur DESTINATION
   (VRAM) avance normalement avec la logique d'entrelacement CRTC CPC
   standard (`+0x0800` par ligne, `+0xC050` de correction tous les 8
   lignes). C'est exactement le mécanisme qui inverse l'axe Y entre les
   deux représentations.
3. **Confirme aussi l'hypothèse du "Speccy port"** de l'utilisateur : le
   moteur de rendu isométrique d'origine (conçu pour l'écran linéaire du
   Spectrum) écrit tel quel dans le buffer intermédiaire linéaire (0x9000+,
   axe Y "normal" pour un moteur écran-linéaire classique), et SEULE la
   routine de recopie finale vers la VRAM CPC gère la conversion vers le
   format entrelacé CPC — évitant de casser/adapter le moteur de rendu
   isométrique original. Exactement la logique de moindre effort de
   portage décrite par l'utilisateur.

**Reste à élucider** : où `fn_blit_copy_line` est appelée (quel
appelant fixe B=nombre de lignes et calcule HL/DE de départ), et le
lien précis avec la largeur VRAM réelle (le buffer fait 64 octets/ligne,
largeur VRAM Mode 0/1 CPC = 80 octets/ligne pour l'écran complet — la
zone de jeu isométrique doit occuper une fenêtre plus étroite que
l'écran total, cohérent avec le HUD visible sur les côtés).

## CONFIRMÉ : la boucle qui pilote fn_blit_copy_line, et le lien avec (0x0084)

**Statut : CONFIRMED** par désassemblage direct (breakpoint sur
0x2EC0, remontée à l'appelant 0x2EBB, désassemblage de 0x2E97-0x2EBF).

```
2E97  CD5027     call   2750       ; fn_check_collisions (remet (0x0084)=0 en tête)
2E9A  CD441C     call   1C44       ; non tracé
2E9D  CD0218     call   1802       ; non tracé
2EA0  217000     ld     hl,0070    ; (0x0070) = compteur de "bandes" à transférer
2EA3  3A8400     ld     a,(0084)
2EA6  86         add    a,(hl)
2EA7  328400     ld     (0084),a   ; (0x0084) += (0x0070) -- ACCUMULATEUR, lien confirmé
2EAA  217000     ld     hl,0070
2EAD  7E         ld     a,(hl)
2EAE  A7         and    a
2EAF  280C       jr     z,2EBD     ; (0x0070)==0 -> fin (pop ix, ret)
2EB1  35         dec    (hl)       ; (0x0070) -= 1
2EB2  E1         pop    hl         ; dépile HL (source, buffer intermédiaire)
2EB3  D1         pop    de         ; dépile DE (dest, VRAM)
2EB4  C1         pop    bc         ; dépile BC (largeur/hauteur empilées avant)
2EB5  78         ld     a,b
2EB6  41         ld     b,c        ; B = ancien C (nb de lignes pour ce blit)
2EB7  4F         ld     c,a        ; C = ancien B (largeur en octets, réutilisée
                                   ;     par LDIR dans fn_blit_copy_line)
2EB8  CDC02E     call   2EC0       ; fn_blit_copy_line
2EBB  18ED       jr     2EAA       ; boucle jusqu'à (0x0070)==0
2EBD  DDE1       pop    ix
2EBF  C9         ret
```

**Interprétation confirmée** :
- **`(0x0070)` = compteur de "bandes" à recopier** vers la VRAM ce tour
  de frame — chaque bande correspond très probablement à UNE ENTITÉ
  RENDUE (le buffer intermédiaire accumule les rendus individuels des
  entités, avec leurs coordonnées `HL/DE/BC` empilées sur la pile au fur
  et à mesure du rendu de chacune, PUIS cette boucle finale les dépile
  toutes d'un coup et effectue les transferts réels vers l'écran).
- **`(0x0084)` confirmé comme accumulateur cumulatif du nombre total de
  bandes traitées** (across plusieurs frames ou for stats/debug ?),
  incrémenté de `(0x0070)` à chaque frame — explique pourquoi
  `fn_check_collisions` (qui le remet à 0 en tête de fonction) avait un
  effet de bord nécessaire : sans cette remise à zéro, l'accumulateur
  dériverait frame après frame de façon incontrôlée.
- **Confirme le modèle "empile pendant le rendu, dépile au blit final"**
  déjà pressenti : la boucle de rendu de chaque entité individuelle doit
  empiler (`PUSH BC`/`PUSH DE`/`PUSH HL`) ses paramètres de blit avant de
  passer à l'entité suivante, plutôt que d'appeler `fn_blit_copy_line`
  immédiatement — technique qui permet de dessiner toutes les entités
  dans le buffer intermédiaire d'abord, puis de les transférer en bloc
  à la fin (cohérent avec l'architecture en 2 temps confirmée
  précédemment).

**Reste à élucider** : où et comment `PUSH HL/DE/BC` + incrément de
`(0x0070)` ont lieu pendant le rendu de chaque entité (probablement dans
`fn_render_entities` / `fn_isometric_project`, pas encore tracé
précisément) ; le rôle exact de `0x1C44` et `0x1802` (appelées juste
avant ce bloc, jamais explorées).
