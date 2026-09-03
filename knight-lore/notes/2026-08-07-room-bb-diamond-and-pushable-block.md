# Session 2026-08-07 (suite 18) — Salle 0xBB : identification "diamant" + bloc poussable (0x3E)

## Contexte

Le joueur (partie en cours de l'utilisateur, sans reset) est passé de la
salle 0x8D (voir `notes/2026-08-07-object-catalog-randomizer.md`) à la
salle 0xBB. L'utilisateur décrit son contenu : "un nouvel objet, à
ramasser dans cette pièce : le diamant. Le reste tu connais : portes,
fantôme, blocs, mur."

Dump en lecture seule de la table d'entités (0x00D7, 128 slots), filtré
sur `room==0xBB` :

```
id  0 type=0x32 room=0xBB  (joueur, forme nuit)
id  2 type=0x60 room=0xBB grid=(0x79,0x9F,0xA4)   <- "le diamant"
id  4 type=0x02 room=0xBB   \  2 portes (paires de montants,
id  5 type=0x03 room=0xBB   /  déjà confirmé fn_door_post_type_A/B)
id  6 type=0x02 room=0xBB   \
id  7 type=0x03 room=0xBB   /
id  8-20        type=0x0A-0x0F room=0xBB   <- "mur" (déjà en hypothèse)
id 21 type=0x50 room=0xBB   <- "fantôme" (déjà confirmé fn_ghost_wander_logic)
id 22 type=0x3E room=0xBB grid=(0x7C,0x9C,0x8C)  \  <- "blocs" (NOUVEAU,
id 23 type=0x3E room=0xBB grid=(0x7C,0x9C,0x98)  /     voir ci-dessous)
```

## Identification "diamant" = type 0x60 (CONFIRMED par l'utilisateur)

Type 0x60 fait partie de la famille déjà connue des 7 sprites partageant
`fn_crystal_ball_logic` (0x1B2B) — seul 0x66 avait un nom visuel confirmé
("boule de cristal"). L'utilisateur identifie maintenant 0x60 comme
"le diamant" — première identification visuelle d'un second membre de
cette famille de 7.

| Type | Nom visuel confirmé | Sprite (`tbl_sprite_dispatch`) |
|---|---|---|
| 0x60 | **diamant** (CONFIRMED 2026-08-07, utilisateur) | 0x4687 |
| 0x61-0x65 | inconnu | 0x4600/0x446B/0x4702/0x4795/0x456D |
| 0x65 | **bouteille** (CONFIRMED 2026-08-07, utilisateur, salle 0xBA) | 0x456D |
| 0x66 | boule de cristal (confirmed, session précédente) | 0x44EC |

## DÉCOUVERTE : `fn_pushable_block_logic` (0x1D53), type 0x3E — "bloc poussable"

**Statut : confirmed (désassemblage + recoupements structurels forts),
identification visuelle "blocs" par l'utilisateur pour cette salle.**

```
1D53  CALL 1D8F     ; MÊME calibration de projection que les blocs
                     ;   statiques 0x06/0x07 (fn 0x1D8F)
1D56  CALL 22A5      ; annule le vecteur de déplacement dès la fin du
                     ;   contact — EXACTEMENT le même appel que
                     ;   fn_pushable_table_logic (0x1D71, type 0x54) qui
                     ;   "s'arrête net dès la fin du contact" (déjà
                     ;   confirmé empiriquement, voir
                     ;   notes/2026-08-07-entity-logic-pushable-table.md)
1D59  RST 10         ; applique le vecteur de déplacement courant
1D5A  CALL 1A40      ; teste si (ix+09)|(ix+0A)|(ix+0B) != 0 (vecteur
                     ;   de déplacement non nul -> le bloc est en train
                     ;   d'être poussé)
1D5D  JP Z,1F7B      ; si vecteur nul -> idle (tail partagé)
1D60  CALL 0A07       ; sinon : calcule un "hash" de position
                     ;   (somme (ix+01)+(ix+02)+(ix+03), complémentée)
                     ;   et l'arme comme paramètre du moteur son (mêmes
                     ;   adresses 0x0A49/0x0A4A que fn_bonus_life_pickup_logic
                     ;   utilise pour armer un son) — un son de
                     ;   déplacement dont la hauteur dépend de la
                     ;   POSITION du bloc, pas une séquence fixe
1D63  JP 1F7B         ; tail partagé
```

**Sprite partagé avec le bloc statique** : `tbl_sprite_dispatch[0x3E]` =
`tbl_sprite_dispatch[0x07]` = **0x59DB**, exactement le même pointeur —
0x3E est donc visuellement IDENTIQUE au bloc décoratif statique 0x07,
seule sa logique diffère (poussable au lieu de purement statique).

**Empilement confirmé par les données** : les deux instances (id 22/23)
partagent exactement le même grid_x/grid_y (0x7C, 0x9C) et diffèrent
seulement de grid_z (0x8C vs 0x98, delta = 0x0C) — **exactement le delta
d'élévation "sur la table" déjà confirmé empiriquement**
(`notes/2026-08-07-jump-on-table.md` : "0x80 = au sol, 0x8C = sur la
table, élévation +0x0C") : ce sont donc littéralement DEUX BLOCS
POUSSABLES EMPILÉS, l'un posé sur l'autre.

**Renommage/nouvelle entrée** : `fn_pushable_block_logic` (0x1D53),
type d'entité 0x3E — "bloc poussable" (même famille comportementale que
la table poussable 0x54, mais visuellement un simple bloc, et avec un
son de déplacement positionnel plutôt qu'une séquence fixe).

## Mise à jour 2026-08-07 : "bouteille" = type 0x65 (salle 0xBA)

Confirmé par l'utilisateur dans une salle ultérieure (0xBA) : entité id 2,
`type=0x65`, seule entrée non-décor de la salle (le reste : joueur,
2 portes, murs 0x0A-0x0F, 6 blocs statiques 0x07, 10 piques 0x17 — tous
déjà connus, rien de nouveau côté décor cette fois).

## Prochaines étapes

1. Identifier visuellement les 4 autres membres encore inconnus de la
   famille "boule de cristal" (0x61, 0x62, 0x63, 0x64) au fil des salles
   rencontrées. Progression : 0x60=diamant, 0x65=bouteille,
   0x66=boule de cristal — 3/7 identifiés.
2. Vérifier si le bloc poussable (0x3E) glisse après relâchement comme le
   coffre (0x55) ou s'arrête net comme la table (0x54) — le
   désassemblage montre `CALL 0x22A5` (arrêt net), donc prédiction :
   comportement "table", pas "coffre". Pas encore vérifié en direct.
3. Décoder plus finement le "hash de position -> son" de `0x0A07` (à
   comparer avec le format déjà connu de `tbl_sound_dispatch`).
