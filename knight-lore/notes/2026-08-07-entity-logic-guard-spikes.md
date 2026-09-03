# Session 2026-08-07 (suite 2) — Premiers ennemis/pièges tracés : gardien + piques

Suite immédiate de `notes/2026-08-07-entity-logic-doors.md` (portes).
Room 0x2E, décrite par l'utilisateur : "moins grande [que 0x2F], murs
du fond avec celui vers X- moins large, 1 gardien qui fait sa ronde
avec 8 piques au sol autour de lui, et 2 portes de chaque côté de
l'axe C". Corrélation directe avec le dump RAM, confirmée exacte.

## Room 0x2E — inventaire live (dump RAM), corrélé à l'observation utilisateur

| Slots | Type | Rôle | Confirmation utilisateur |
|---|---|---|---|
| 4,5 / 6,7 | 0x02/0x03 | 2 portes (grid_x=0xC4/0x3B, symétriques) | "2 portes de chaque côté de l'axe C" ✓ |
| 8-16 | 0x0D,0x0E,0x0F | Murs/décor (plusieurs variantes) | "je soupçonne plusieurs sprites pour les murs" ✓ |
| 17-21 | 0x0A,0x0B,0x0C | Décor statique (2e groupe) | murs du fond, largeur asymétrique observée |
| **22-29** | **0x17 (×8)** | **PIQUES AU SOL** — disposées en cercle (coordonnées symétriques autour du centre) | "8 piques au sol autour du gardien" ✓ EXACT |
| **30** | **0x1E** | **LE GARDIEN** (corps/logique de patrouille) | "1 gardien qui fait sa ronde" ✓ |
| **31** | **0x94** | Compagnon du gardien, même position exacte (grid_x/y identiques à slot 30) — arme/hache ? | (non mentionné par l'utilisateur, probablement l'arme portée) |

**Méthode validée une fois de plus** : dump brut de la table d'entités
vivantes + comparaison au dénombrement visuel de l'utilisateur → permet
d'identifier instantanément quel(s) slot(s) correspond(ent) à quel
élément visible, sans avoir à décoder un seul sprite. Bien plus rapide
que d'essayer de deviner depuis le seul désassemblage.

## Type 0x17 — `fn_spike_logic` (piques, confirmed)

**Statut : confirmed** par désassemblage direct (`tbl_entity_logic_dispatch`
0x0676 → 0x10CE pour le type 0x17).

```
10CE  CALL 113F              ; force bit 5 de (ix+0D) -- ? (marqueur d'état)
10D1  JP 1D8F                ; recalibre offsets de projection (variante F8F0)

10D4  CALL 1D9E              ; variante de calibration FCF8
10D7  LD (IX+0B),01
10DB  BIT 0,(IX+0D) / [±2 selon bit] / LD (IX+09),A
10E8  CALL 0A07              ; calcule une SOMME de 3 champs (ix+01)+(ix+02)+(ix+03), inversée (CPL)
10EB  RST 10                 ; primitive non encore élucidée (probablement HL -= A ou similaire)
10EC  BIT 0,(IX+0C) / ...

; -- oscillation périodique --
1122  CALL 1D9E
1125  LD A,(0082) / AND 01 / RET Z         ; throttle 1 frame/2 (var_entity_update_counter, déjà connu)
112B  LD A,(006D) / AND 40                  ; var_pseudo_random_acc, bit 6
112E  XOR (IX+07) / LD (IX+07),A            ; bascule bit 6 des flags -> variation visuelle pseudo-aléatoire
1136  CALL 1260                             ; avance l'animation (cycle 4 frames, voir ci-dessous)
```

**Interprétation (hypothesis raisonnable, cohérente avec l'observation
visuelle)** : les piques oscillent (montent/descendent, ou tournent en
cercle) selon un motif à la fois périodique (throttle 2 frames) et
légèrement aléatoire (XOR avec `var_pseudo_random_acc`), avec un cycle
d'animation à 4 frames (`0x1260`). Le fait que 8 instances soient
disposées symétriquement en cercle autour du gardien est cohérent avec
un piège classique "anneau de piques" qui doit être évité en
contournant le centre — logique de jeu simple mais visuellement
frappante, correspondant exactement à ce que l'utilisateur observe.

### `0x1260` — Cycle d'animation générique 4 frames (confirmed)

```
1260  LD A,(IX+00)
1263  XOR 01 / JR 1273           ; branche A : bascule juste le bit 0 du type
1267  LD A,(IX+00) / LD C,A
126B  AND FC / LD B,A            ; conserve les 6 bits hauts
126E  LD A,C / INC A / AND 03    ; incrémente les 2 bits bas (mod 4)
1272  OR B
1273  LD (IX+00),A               ; nouveau type = base + phase(0-3)
```
Pattern générique "cycle d'animation à 4 phases encodées dans les 2
bits bas du type" — **potentiellement réutilisé par d'autres entités
animées** (à vérifier sur d'autres types rencontrés).

## Type 0x1E — `fn_guard_patrol_logic` (le gardien, confirmed)

**Statut : confirmed** par désassemblage direct (0x0676 → 0x1280).

```
1280  CALL 1DBC               ; calibration projection (variante FE00/07F4)
1283  RST 10                   ; primitive non élucidée (probablement liée au déplacement)
1284  CALL 12A5                ; résout un vecteur de déplacement (HL) par direction, voir plus bas
1287  LD (IX+09),L / LD (IX+25),L    ; sauvegarde position de test (et copie à +0x25 -- 2e "instance" ?)
128D  LD (IX+0A),H / LD (IX+26),H
1293  LD A,(IX+01) / LD (IX+1D),A    ; sauvegarde grid_x -> pending_grid_x (même champ que fn_room_transition !)
1299  LD A,(IX+02) / LD (IX+1E),A    ; sauvegarde grid_y -> pending_grid_y
129F  CALL 1055                ; sous-routine non explorée (probablement mouvement effectif)
12A2  JP 1139                  ; -> force bit 5 de (ix+0D) + calibration projection F8F0 (cf. type 0x17)
```

### `0x12A5` — Résolution du vecteur de déplacement par direction (confirmed)

```
12A5  LD BC,12B1              ; table de dispatch (RST 28, 4 entrées word)
12A8  LD A,(IX+0D) / AND 03 / LD L,A   ; direction courante (0-3), champ (ix+0D) déjà vu partagé avec fn_spike_logic
12AE  JP 0028                  ; RST 28 dispatch générique
```

Table à `0x12B1` (4 pointeurs, un par direction) menant chacun à un
petit bloc qui charge un vecteur HL fixe (`0x00FE`=-2/0, `0x0002`=+2/0,
`0xFE00`=0/-2, `0x0200`=0/+2 — les 4 directions cardinales, pas de
axe -0x28D4 comme suggérait une lecture rapide) et, selon `bit 0/1 de
(ix+0C)`, ajuste éventuellement la valeur pour un déplacement diagonal
ou une variation de vitesse.

**Interprétation d'ensemble (CONFIRMÉ EMPIRIQUEMENT par observation
utilisateur 2026-08-07)** : le gardien se déplace de façon cyclique
selon une direction stockée dans `(ix+0D)&3` (le MÊME champ bas-niveau
que celui utilisé par les piques pour leur propre variation —
probablement un champ générique "état/phase directionnelle" partagé
par le moteur de logique d'entité, pas spécifique au gardien), avec un
vecteur de déplacement fixe de ±2 unités par tick selon l'axe.
**Confirmé par l'utilisateur : le gardien change de direction 4 fois
par ronde complète** — correspond exactement aux 4 entrées de la table
de dispatch `0x12B1` (une direction cardinale par valeur de `(ix+0D)&3`,
0-3) — la "ronde" est donc un parcours cyclique à 4 segments
orthogonaux (probablement un rectangle/carré autour du centre de la
salle, cohérent avec le cercle de piques qu'il entoure).

**Animation de marche — PRÉCISÉ après vérification empirique (poll RAM
en direct, deux passes)** : au niveau du champ `type` seul, le gardien
alterne uniquement entre **`0x1E` et `0x1F`** (un seul bit de
différence, bit 0) — un cycle à 2 valeurs, pas 4. MAIS un second poll,
suivant simultanément le `type` ET le bit 6 des flags `(ix+07)` (le
bit d'orientation/miroir déjà connu, cf. `fn_get_orientation_code`),
révèle que les DEUX bits varient indépendamment au fil du temps
(observé : `1F/0`, `1F/1`, `1E/0`, `1E/1`, `1F/0`...) — soit **4
combinaisons visuelles distinctes au total** (2 valeurs de type × 2
états de miroir). **Ceci confirme et explique précisément l'observation
de l'utilisateur** ("l'animation a l'air de faire 4 frames") : à
l'écran, ces 4 combinaisons produisent bien 4 poses visuellement
différentes (2 sprites de base, chacun avec sa version miroir), même
si le mécanisme sous-jacent est un battement à 2 phases (`0x1055`,
`fn_guard_walk_animation_toggle`, comparaison des composantes du
vecteur de déplacement) combiné à un flip d'orientation indépendant
(mécanisme déjà connu, pas spécifique au gardien) plutôt qu'un vrai
cycle à 4 sprites distincts comme chez les piques
(`fn_animation_cycle_4`, 0x1260). Les types `0x20-0x23` observés dans
la table de dispatch voisine appartiennent à une famille de logique
DIFFÉRENTE (`0x2689`, liée à `var_pseudo_random_acc` — objet/piège
distinct, sans rapport avec la marche du gardien).

## Type 0x94 (et plage 0x90-0x9D) — DEUXIÈME MOITIÉ DU SPRITE DU GARDIEN (RÉVISÉ après correction utilisateur)

**Statut : confirmed (RÉVISÉ)** — l'hypothèse initiale ("compagnon du
gardien, probable arme/hache") était **fausse**, corrigée par
l'utilisateur qui confirme que le gardien observé n'a ni arme ni
compagnon visible. Nouvelle analyse par poll RAM en direct (0.15s/
échantillon, ~30 échantillons) :

- Le type de ce slot cycle en fait à travers **une dizaine de valeurs
  différentes** (`0x90` à `0x9D`), toutes dispatchées vers la MÊME
  logique `0x0FD8`, avec des sprites tous distincts (table
  `tbl_sprite_dispatch`) — pas 2 phases comme suggéré initialement.
- Sa position de grille (`grid_x`/`grid_y`) **suit celle du gardien
  (slot 30) avec un léger décalage/retard** (une trace/traînée dans le
  temps, pas la même position exacte instantanée) — pas un objet
  statique posé au sol.

**Interprétation révisée (hypothesis solide, cohérente avec la
correction utilisateur)** : ce slot n'est PAS un compagnon/arme
distinct mais très probablement **la seconde moitié du sprite visuel
du gardien** (ex: les jambes, animées séparément du buste/torse
principal pour donner l'illusion fluide de la marche sans devoir
stocker un sprite combiné pour chaque paire torse×jambes) — une
technique de composition de sprite en 2 parties, chaque partie étant
une entité de jeu séparée mais rendue à une position quasi-identique
pour former une seule silhouette cohérente à l'écran. Le décalage
temporel observé (la position de ce slot suit celle du gardien avec un
temps de retard) est cohérent avec des jambes qui "suivent" le
déplacement du torse au fil de l'animation de marche.

**Renommage** : `fn_guard_weapon_logic` (0x0FD8) → **`fn_guard_legs_logic`**
(nom révisé, à corriger dans `docs/SYMBOLS.md`).

## RST 10 (0x0010) — ÉLUCIDÉ : addition d'un vecteur 3D à une position (confirmed)

**Statut : confirmed** par désassemblage direct.

```
0010  DEC (IX+0B)             ; décrémente un compteur/timer de l'entité appelante
0013  CALL 23F7                ; sous-appel générique (voir plus bas — pas lié au déplacement)
0016  PUSH IX / POP DE / INC DE   ; DE = IX+1 (pointeur sur le CHAMP +01 de l'entité, i.e. grid_x)
001A  LD HL,0008 / ADD HL,DE  ; HL = DE+8 (= IX+9, i.e. le champ +09 -- le "vecteur de déplacement"
                               ;   déjà résolu par l'appelant, ex: fn_guard_patrol_logic 0x12A5,
                               ;   fn_spike_logic 0x10E8/0A07)
001E  LD B,03                 ; 3 itérations = 3 axes (grid_x, grid_y, grid_z_or_offset)
0020  LD A,(DE) / ADD A,(HL) / LD (DE),A   ; position[axe] += vecteur[axe]
0023  INC HL / INC DE
0025  DJNZ 0020
0027  RET
```

**Interprétation confirmée** : `RST 10` = **`entité.position[0..2] +=
entité.champ[9..B]`** (les 3 champs `grid_x/grid_y/grid_z_or_offset`,
offsets +01/+02/+03, reçoivent l'addition des 3 octets stockés en
+09/+0A/+0B) — la primitive de DÉPLACEMENT générique utilisée par
toutes les entités mobiles (gardien, piques...), une fois qu'elles ont
résolu leur vecteur de déplacement du tick courant dans ces 3 champs
tampon. Cohérent avec le motif déjà vu : `fn_guard_patrol_logic`
(0x1280) résout un vecteur dans `(ix+09)/(ix+0A)` puis `RST 10`
l'applique ; `fn_spike_logic` fait de même. **Cette primitive mérite un
nom symbolique de premier plan** (`rst_apply_movement_vector`) au même
titre que `rst_add_hl_a` (0x0008) — c'est le cœur du mouvement de
TOUTES les entités du jeu (probablement invoquée aussi par
`fn_player_logic`, à vérifier).

**Effet de bord non lié au déplacement, découvert par la même
occasion** : `RST 10` appelle systématiquement `0x23F7` en tout
premier — décrémente le compteur `(ix+0B)` de l'entité (rôle exact à
élucider, distinct du vecteur de déplacement lui-même) puis pose le
bit 1 des flags si pas déjà fait, avec des sous-appels (`0x230C`,
`0x24EA`) non encore explorés. **Ne pas confondre `(ix+0B)` "compteur
décrémenté par 0x23F7" avec le "champ +0B = 3e composante du vecteur de
déplacement" lu par `RST 10` lui-même** — ce sont deux usages
DIFFÉRENTS du même octet à des moments différents de la frame (l'un en
prélude via 0x23F7, l'autre par la boucle `0020-0025`) : **point de
prudence à garder en tête pour la suite** (piège potentiel si on
suppose un seul rôle fixe pour ce champ).

## Prochaines étapes

1. **Désassembler `0x1055`** (mouvement effectif du gardien, appelée
   depuis `0x1280`) et `0x2231` (sous-appel du type 0x94) — pas encore
   fait, complèteraient la logique du gardien.
2. **Comprendre la primitive `RST 10`** (vue dans plusieurs routines
   d'entités : piques 0x10EB, gardien 0x1283) — jamais désassemblée
   directement jusqu'ici, probablement une primitive arithmétique
   fréquente comme RST 08 (HL+=A) mais avec une opération différente.
3. **Vérifier visuellement le rôle du type 0x94** — demander à
   l'utilisateur s'il distingue une arme séparée du corps du gardien.
4. **Chercher d'autres types d'ennemis mobiles** (loups, gobelins
   mentionnés dans le README) dans d'autres salles — la room 0x2E ne
   contient qu'un seul type d'ennemi actif (le gardien).
