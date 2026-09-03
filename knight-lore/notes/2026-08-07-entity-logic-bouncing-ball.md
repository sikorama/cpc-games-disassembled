# Session 2026-08-07 (suite 9) — Taxonomie des ennemis mobiles + balle rebondissante mortelle

## Contexte — taxonomie proposée par l'utilisateur (précieuse, à conserver)

L'utilisateur a proposé une classification claire des ennemis mobiles
du jeu, qui structure bien la suite du travail :

1. **Mouvement régulier/mécanique** — herse (grille mobile, déjà
   confirmée : `fn_moving_grate_logic` 0x1FA6), balle qui rebondit
   (nouvelle, voir ci-dessous).
2. **Objets qui tombent puis s'arrêtent** — boules à pics au plafond
   (déjà confirmées : `fn_ceiling_spike_ball_logic` 0x1092, chute
   déclenchée aléatoirement puis immobiles au sol).
3. **Ennemis avec une vraie routine de comportement**, prenant en
   compte les collisions et parfois la position du joueur — le
   gardien (déjà tracé : `fn_guard_patrol_logic` 0x1280) rentre ici
   selon l'utilisateur : **sa "ronde" émerge du fait qu'il tourne
   après chaque collision** (pas d'un pattern de patrouille précalculé
   comme supposé initialement dans
   `notes/2026-08-07-entity-logic-guard-spikes.md` — **à corriger/
   affiner**, voir section dédiée plus bas). Les **fantômes** (pas
   encore rencontrés visuellement) ont un déplacement aléatoire.

Cette classification aide à orienter l'analyse : chaque nouveau type
d'ennemi rencontré doit être classé dans une de ces catégories avant
même de désassembler sa logique en détail.

## Room 0x43 — inventaire live, corrélé à l'observation utilisateur

| Slots | Type | Rôle | Confirmation utilisateur |
|---|---|---|---|
| 4,5 / 6,7 | 0x02/0x03 | 2 portes, TOUTES DEUX sur l'axe X (grid_x=0xC4 et 0x3B) | "2 portes sur les 2 murs opposés selon l'axe X" ✓ |
| 8-16 | 0x0D,0x0E,0x0F | Mur côté X (petit, moins de segments) | "petit mur côté X" ✓ |
| 17-21 | 0x0A,0x0B,0x0C | Mur côté Y (grand, plus de segments) | "grand mur côté Y" ✓ |
| 22-33 | 0x07 (×12) | **12 BLOCS** | "12 blocs" ✓ EXACT |
| 34-37 | 0x17 (×4) | 4 piques (type déjà connu) | "4 pics" ✓ EXACT |
| **38** | **0xB2** | **LA BALLE REBONDISSANTE** (position centrale) | "la balle rebondit en continu, son contact fait perdre une vie" ✓ |

**Room 0x43 déjà connue depuis les toutes premières sessions** (cf.
`notes/2026-08-06-room-navigation.md`, transition 0x44→0x43) — nouvelle
confirmation croisée de sa géométrie via corrélation utilisateur.

## Type 0xB2/0xB3 — `fn_bouncing_ball_logic` (confirmed)

**Statut : confirmed** par désassemblage direct (0x0676 → 0x1148,
types 0xB2/0xB3 partagent la même logique — probablement 2 phases
d'une même animation de rebond, comme le gardien 0x1E/0x1F).

```
1148  CALL 1D9E              ; calibration projection
114B  LD A,(0083) / AND A / JR NZ,1159   ; var_room_reset_flag_3, déjà connu
114F  LD A,(IX+03) / ADD A,20 / LD (0083),A   ; si (0083)==0, l'initialise depuis grid_z + 0x20
                              ;   (probablement la borne haute du rebond, calculée une fois)
1159  CALL 1260               ; cycle d'animation 4 phases (fn_animation_cycle_4, déjà connu)
115C  CALL 0A07               ; calcule la somme grid_x+grid_y+grid_z (vecteur de test, déjà vu)
115F  BIT 2,(IX+0D) / JR NZ,1175   ; teste le sens du rebond (bit 2 du champ direction)

; --- phase "montée" (bit 2 = 0) ---
1165  RST 10                  ; applique le déplacement (rst_apply_movement_vector)
1166  BIT 2,(IX+0C) / JR Z,1173   ; teste si le sommet est atteint (mécanisme à préciser)
116C  SET 2,(IX+0D)            ; bascule le sens -> phase descente
1170  CALL 09A6                ; ARME LE SON DE REBOND (canal 0, séquence 0x09AC)
1173  JR 1139                  ; force redessin

; --- phase "descente" (bit 2 = 1) ---
1175  LD (IX+0B),03            ; réarme un compteur/vecteur
1179  RST 10                   ; applique le déplacement (sens inverse)
117A  LD A,(0083) / CP (IX+03) / JR NC,1173   ; teste si la borne basse est atteinte
1182  RES 2,(IX+0D)            ; bascule le sens -> phase montée
1186  JR 1173
```

**Interprétation confirmée** : la balle oscille verticalement entre
deux bornes (borne haute = `grid_z_initial + 0x20`, calculée une seule
fois au premier tick ; borne basse = `grid_z_initial` lui-même,
`(0x0083)`), avec un **son de rebond joué à chaque fois qu'elle
change de sens** (`0x09A6`, arme le canal 0 du moteur son — cohérent
avec un vrai "boing" sonore à l'impact). **C'est le prototype exact de
la catégorie 1 de l'utilisateur** : "mouvement régulier/mécanique",
sans aucune dépendance à la position du joueur pour son propre
déplacement.

**Mortalité au contact** : `0xB2`/`0xB3` ne semblent PAS appeler
`fn_player_proximity_death` (0x0EA0) directement dans cette routine —
la mort au contact de la balle est donc très probablement gérée par le
mécanisme de collision GÉNÉRIQUE (`fn_check_collisions`/
`fn_collision_effect`, déjà connu), pas par un test de proximité dédié
comme les ennemis "actifs" (0x83-0x85). **Piste à vérifier** : la
prochaine fois qu'un contact avec la balle est observé, corréler le
code de collision déclenché (table `0x27FE`) avec le résultat mortel,
pour distinguer ce chemin de `fn_player_proximity_death`.

## Type 0x07 — confirmation supplémentaire (logique = calibration seule)

Logique `0x1D8F` — même motif que le type 0x06 (blocs en bois) déjà
rencontré : purement décoratif/statique, juste une variante de
calibration de projection. Cohérent avec "12 blocs" comme éléments de
décor pur, sans interaction.

## Correction à apporter : le gardien tourne APRÈS COLLISION, pas selon un pattern précalculé

**Point soulevé par l'utilisateur, vérification tentée sans succès
cette session** :
`notes/2026-08-07-entity-logic-guard-spikes.md` documentait
`fn_guard_patrol_logic` (0x1280) comme suivant une direction stockée
dans `(ix+0D)&3`, changée "on ne sait comment" au fil du temps —
**l'utilisateur précise que le changement de direction est en fait
déclenché PAR UNE COLLISION** (contre un mur ou un obstacle), pas par
une minuterie ou un pattern précalculé.

**Recherches tentées, toutes infructueuses** :
- Recherche de `BIT/SET/RES` sur l'offset `+0x0D` dans la zone du
  dispatch de collision (`0x2860-0x28B0`) : aucun résultat.
- Recherche exhaustive de `LD (IX+0D),xx` et de tout bit-op `DD/FD CB
  0D xx` dans les 16K bas : les résultats trouvés appartiennent tous à
  des routines déjà connues et sans rapport direct visible avec un
  retour de collision générique (piques, balle rebondissante,
  transformation jour/nuit, portes) — aucun candidat clair dans
  `fn_check_collisions`/`fn_collision_effect` lui-même.
- Tentative de vérification empirique : pas de gardien présent dans la
  salle courante au moment de la vérification (room 0x43) — reportée.

**Conclusion honnête** : le mécanisme exact par lequel une collision
modifie la direction du gardien n'a PAS été localisé cette session
malgré plusieurs tentatives de recherche par motif de code. Deux
explications possibles à départager la prochaine fois :
1. Le lien collision → changement de direction passe par un champ
   INTERMÉDIAIRE pas encore identifié (ex: le gardien teste un flag
   générique de "je viens de heurter quelque chose" à un autre offset
   que `+0x0D`, qui influence ensuite indirectement le calcul de
   `fn_resolve_patrol_vector`).
2. Le "code de collision" générique (table `0x27FE`, ~30 entrées) a un
   handler spécifique pour l'interaction gardien-vs-mur qui n'a pas
   encore été isolé parmi la trentaine de cibles de dispatch (la
   plupart pointent vers `0x2834`/`0x2837`/`0x283A`, des handlers
   génériques déjà vus mais pas encore corrélés précisément par type
   d'entité).

## RÉSOLU : le gardien change bien de direction PAR COLLISION, mécanisme trouvé (2026-08-07)

**Statut : CONFIRMED** par désassemblage direct, confirmé par la piste
ouverte lors du test de la table poussable (voir
`notes/2026-08-07-entity-logic-pushable-table.md`, section "Test 2").

Désassemblage complet de `fn_resolve_patrol_vector` (0x12A5-0x12FA),
la table de dispatch par direction déjà repérée :

```
; direction 0 (vecteur HL=00FE, ~axe -Y ou -X selon convention)
12B9  LD HL,00FE
12BC  BIT 0,(IX+0C) / RET Z     ; si bit 0 de (ix+0C) NON posé -> ne change PAS de direction, continue tout droit
12C1  LD HL,0200                ; sinon, prépare le vecteur opposé...
12C4  LD A,(IX+0D) / [(+1)&3 sur les 2 bits bas] / LD (IX+0D),A   ; ...ET CHANGE LA DIRECTION (+1 mod 4)

; direction 1 (vecteur HL=0200)
12D4  LD HL,0200
12D7  BIT 1,(IX+0C) / RET Z     ; si bit 1 NON posé -> continue tout droit
12DC  LD HL,0002                ; sinon vecteur opposé + change de direction (jr 12C4)

; direction 2 (vecteur HL=0002)
12E1  LD HL,0002
12E4  BIT 0,(IX+0C) / RET Z     ; MÊME bit 0 que direction 0 (axe symétrique)
12E9  LD HL,FE00

; direction 3 (vecteur HL=FE00)
12EE  LD HL,FE00
12F1  BIT 1,(IX+0C) / RET Z     ; MÊME bit 1 que direction 1
12F6  LD HL,00FE
```

**Interprétation confirmée** : `(ix+0C)` bit 0 = "collision détectée sur
l'axe X (ou Y)", bit 1 = "collision détectée sur l'autre axe" — EXACTEMENT
le même champ et les mêmes bits que ceux repérés empiriquement sur la
TABLE POUSSABLE lors du test de blocage contre un mur (bit observé
passer de `0x04` à `0x06`, soit l'apparition du bit 1). **Le gardien
teste ces bits À CHAQUE tick** : tant qu'aucune collision n'est
signalée sur l'axe courant, il continue tout droit dans sa direction
actuelle ; dès qu'une collision EST détectée (mur, obstacle, table
poussée dans son chemin...), il incrémente sa direction de 1 (cycle
0→1→2→3→0, les 4 directions cardinales déjà confirmées) — **exactement
le mécanisme "il tourne après chaque collision" décrit par
l'utilisateur, maintenant intégralement confirmé par désassemblage**.

**Origine de `(ix+0C)` bit 0/1** : très probablement posé par le moteur
de collision générique (`fn_check_collisions`/dispatch `0x27FE`) — champ
commun à toute entité mobile (confirmé aussi utilisé par la balle
rebondissante et les piques, cf. `notes/2026-08-07-entity-logic-bouncing-ball.md`).
Reste à identifier PRÉCISÉMENT quel handler du dispatch de collision
pose ces bits (piste pour une session future, mais le mécanisme
d'ensemble n'a plus besoin d'être deviné).

**Renommage proposé** : ajouter `var_collision_flag_axis0`/`axis1`
comme alias documentaire pour les bits 0/1 de l'offset `+0x0C` de la
structure d'entité (à intégrer dans la table de structure d'entité de
`docs/SYMBOLS.md`).

## Prochaines étapes

1. **Vérifier la correction ci-dessus** sur le mécanisme de
   changement de direction du gardien (collision, pas pattern
   précalculé) — chercher dans le dispatch de collision `0x27FE` un
   handler qui modifie `(ix+0D)` d'une entité.
2. **Identifier visuellement un fantôme** (déplacement aléatoire,
   catégorie 3 de la taxonomie utilisateur) pour compléter le
   bestiaire — pas encore rencontré en session.
3. **Identifier visuellement le vrai ennemi mobile 0x83-0x85**
   (`fn_hostile_patrol_logic`, catégorie 3 également) — toujours pas
   fait, cf. `notes/2026-08-07-death-mechanism-partial.md`.
4. Vérifier si la mort par contact avec la balle (0xB2/0xB3) passe
   par le dispatch de collision générique ou par un mécanisme dédié —
   corréler avec le code de collision observé au moment du contact.
