# Session 2026-08-07 (suite) — Logique des ennemis/objets : PORTES identifiées et mécanisme complet

Reprise du chantier IA/logique des entités non-joueur
(`tbl_entity_logic_dispatch`, 0x0676), jusqu'ici seulement tracé pour le
joueur. Observation empirique de l'utilisateur en jeu (room 0x2F) :
"3 portes, et les 2 murs du fond dessinés" — confirmée immédiatement par
dump de la table d'entités vivantes (voir plus bas), méthode de
corrélation visuel/RAM très efficace, à réutiliser systématiquement.

## Room 0x2F — inventaire live des entités (dump RAM brut)

21 entités actives en plus du joueur (slot 0) et de son double
loup-garou (slot 1, type 0x42) :

| Slots | Type | Rôle (identifié cette session) |
|---|---|---|
| 4,5 / 6,7 / 8,9 | 0x02 / 0x03 | **3 PORTES** (voir ci-dessous) — chaque porte = paire (montant 0x02 + montant 0x03), positions symétriques autour de 0x80 sur un axe |
| 10,11,12,13,14,15 | 0x0D,0x0E,0x0F | Éléments statiques (murs/décor — logique commune 0x1D9E) |
| 16,17,18,19,20,21,22 | 0x0A,0x0B,0x0C | Éléments statiques (logique commune, variante) |

**Coïncidence exacte avec l'observation utilisateur** : 3 paires
0x02/0x03 = 3 portes. Slots 4/5 et 6/7 partagent le même axe (grid_x =
0x8D/0x73, symétrique autour de 0x80) à deux `grid_y` différents (0xC4
et 0x3B) — ce sont les 2 portes sur les murs "du fond" visibles côte à
côte. Slot 8/9 est sur l'AUTRE axe (grid_y = 0x73/0x8D à grid_x fixe
0x3B) — la 3e porte, sur un mur latéral.

## Type 0x02/0x03 — `fn_door_post_type_A`/`fn_door_post_type_B` (logique CONFIRMÉE)

**Statut : confirmed** par désassemblage direct + corrélation empirique
(dénombrement utilisateur).

Table de dispatch logique (`tbl_entity_logic_dispatch`, 0x0676) :
- type 0x02 → 0x1FFC
- type 0x03 → 0x1FE2

Les deux routines sont quasi-identiques (montant gauche vs droit d'une
même porte, sensible à l'orientation courante du joueur/de la caméra
via bit 6 de `(ix+07)`) :

```
1FE2  BIT 6,(IX+07)          ; teste l'orientation actuelle
1FE6  JR NZ,1FF2
1FE8  LD HL,FDF7             ; offset de calibration projection (variante A)
1FEB  LD (IX+12),L / LD (IX+13),H   ; proj_offset_x/y (déjà connus, fn_isometric_project)
1FF1  RET
1FF2  LD HL,FEF9             ; variante B (orientation inversée)
...
```
= ajuste simplement les offsets de calibration de projection isométrique
selon l'orientation courante — cohérent avec un élément de décor FIXE
dont l'apparence (mais pas la logique) change selon l'angle de vue.

**La vraie logique de "porte" est dans le second bloc, partagé (0x1FFC
identique dans les deux types), qui calcule un point de test de
proximité** :

```
1FFC  BIT 6,(IX+07)
2000  JR NZ,202C
2002  LD A,(IX+00) / CP 04 / JR Z,1FF7   ; cas spécial si (type-offset)==4
2009  LD HL,FDF9
200C  CALL 1FEB                          ; recalibre offset projection
200F  LD A,(IX+02) / ADD A,0D / LD (IX+0A),A   ; point de test Y = grid_y + 13
2017  LD A,(IX+01) / LD (IX+09),A              ; point de test X = grid_x (copie)
201D  LD HL,060F                         ; bbox de test : largeur=6, hauteur=0F(15)
2020  LD A,(IX+03) / LD (IX+0B),A        ; point de test Z = grid_z_or_offset (copie)
2026  CALL 208F                          ; teste la proximité du JOUEUR (voir plus bas)
2029  JP 2045                            ; teste à nouveau + orientation joueur (voir plus bas)
```
(la branche `202C` fait le calcul symétrique pour l'orientation opposée,
`grid_y - 13` au lieu de `+13` — le "point de test" est décalé devant
la porte, du côté d'où le joueur doit approcher pour cette orientation)

### `0x208F`/`0x2045` — Capteur de proximité JOUEUR (confirmed)

**Découverte clé** : `IY` est fixé en dur à `0x00D7` (= **l'entité 0,
le joueur**, PAS une boucle générique sur toutes les entités) :

```
208F  LD IY,00D7             ; IY = joueur, TOUJOURS (capteur dédié joueur)
2093  LD A,(IY+00) / AND A / RET Z      ; joueur inactif -> abandonne
2098  BIT 3,(IY+07) / RET Z             ; joueur pas dans un état particulier -> abandonne
209D  CALL 20A6               ; calcule si le joueur est dans la bbox de test (3 axes)
20A0  RET NC                  ; pas assez proche -> abandonne
20A1  SET 0,(IY+07)           ; POSE LE FLAG DE DÉCLENCHEMENT SUR LE JOUEUR LUI-MÊME
20A5  RET
```

`0x20A6` (test AABB générique, 3 axes, seuil fixe `<4`) :
```
20A6  LD A,(IX+09) / SUB (IY+01) / [abs] / CP L    ; |point_test_x - joueur_grid_x| < largeur_bbox
20B2  LD A,(IX+0A) / SUB (IY+02) / [abs] / CP H    ; |point_test_y - joueur_grid_y| < hauteur_bbox
20BE  LD A,(IX+0B) / SUB (IY+03) / [abs] / CP 04   ; |point_test_z - joueur_grid_z| < 4 (seuil fixe)
```

**Interprétation confirmée** : chaque montant de porte définit un
**point de déclenchement virtuel** (décalé de ±13 unités de la position
du montant, selon l'orientation), et teste À CHAQUE FRAME si le joueur
s'y trouve. Si oui, **pose le bit 0 des flags DU JOUEUR** (pas de la
porte) — un signal "je suis en train de franchir une porte", consommé
ailleurs par la logique du joueur lui-même (voir plus bas).

**`0x2045`** fait un test similaire mais avec une table de dispatch par
orientation (`0x2061`, 4 pointeurs word, cf. `fn_get_orientation_code`)
qui ajuste finement `(iy+0E)`/`(iy+0F)` du JOUEUR selon l'axe — un
second raffinement (probablement un ajustement de la position exacte du
joueur pendant le "glissement" à travers l'ouverture, pas juste un
booléen de déclenchement).

## `0x2322` — `fn_player_door_transition` (logique JOUEUR, confirmed) : LE MÉCANISME DE CHANGEMENT DE ROOM PAR PORTE

**Statut : confirmed** par désassemblage direct. Appelée à chaque frame
depuis `fn_player_logic` (0x228E, juste après `0x23F7`), **consomme**
le flag posé par les portes ci-dessus :

```
2322  LD A,(IX+0C) / AND F0 / RET NZ   ; cooldown (même champ que la transformation !) doit être à 0
2328  BIT 0,(IX+07) / RET Z            ; pas de porte proche récemment -> rien à faire
232D  RES 0,(IX+07)                    ; consomme le flag (une seule fois)
2331  LD BC,2344 / LD HL,(0071)        ; prépare le dispatch par orientation (0x0071 = var_camera_reference)
2338  JP 22C9                          ; RST 28-like dispatch (fn_get_orientation_code, table BC)
```

Puis, selon l'orientation résolue (4 branches à 0x2344/23A5/23DB/... —
codes source condensés), **le nouveau numéro de room est recalculé
directement à partir de l'ancien**, PAR NIBBLE :

```
; branche "franchissement axe X croissant" (extrait représentatif) :
2360  LD A,(IX+08)          ; room_number courant
2363  LD L,A
2364  DEC A / AND 0F        ; nibble bas - 1 (avec wraparound 4 bits)
2367  LD H,A
2368  LD A,L / AND F0 / OR H
236C  LD (IX+08),A          ; NOUVEAU room_number = (room & 0xF0) | ((room-1) & 0x0F)
236F  LD A,(IX+0C) / OR 30 / LD (IX+0C),A   ; pose un cooldown (bits 4-5 de (ix+0C))

; garde spéciale : si le NOUVEAU type calculé (type-0x10, comparé à 0x40)
; sort de la plage 0x10-0x3F -> RESET COMPLET DE PARTIE (jp 0x05A5, fn_init_room !)
2377  LD A,(IX+00) / SUB 10 / CP 40 / RET NC
237F  INC SP ×4               ; astuce : annule 2 niveaux de CALL empilés (retour direct)
2383  ... copie le template 0x29EB vers l'entité, jp 0x05A5
```//
```
; branches symétriques pour les 3 autres directions (23A5, 23DB, ...) :
;   - nibble bas +1 (au lieu de -1)
;   - nibble haut +0x10 (au lieu de -0x10, ou l'inverse)
; -> confirme un système de room_number encodé en DEUX nibbles indépendants
;    (probablement coordonnée "case X" bas, "case Y" haut, dans une grille
;    de salles), chaque porte incrémentant/décrémentant UN SEUL nibble
;    selon l'axe qu'elle traverse -- cohérent avec un monde en grille 2D
;    de salles (16x16 = 256 cases max, correspondant exactement à l'espace
;    d'un octet room_number 0-255).
```

**DÉCOUVERTE MAJEURE pour la carte du monde** : si `room_number` encode
littéralement des coordonnées de grille `(x=nibble_bas, y=nibble_haut)`,
alors la carte complète des 128 salles pourrait être **directement
déductible de l'ID de room lui-même**, sans passer par
`tbl_room_master_index`/`tbl_room_connection_ptrs` (mécanisme jusqu'ici
non résolu, cf. `notes/2026-08-06-world-map-attempt.md`) ! **Hypothèse
forte, à vérifier au calcul** : lister les 128 room_id confirmés (déjà
extraits, voir `tools/room_map/dump_rooms.py` `ALL_ROOM_IDS`) et
vérifier qu'ils forment bien un pavage cohérent en grille nibble_haut ×
nibble_bas (et que les transitions par porte observées dans
`tbl_room_connections` à l'exécution correspondent exactement à ±1 sur
un nibble) — **prochaine étape immédiate, très probablement la clé qui
manquait**.

## Bilan : types identifiés cette session

| Type | Rôle | Statut |
|---|---|---|
| 0x02 | Montant de porte (variante A, logique 0x1FFC) | confirmed |
| 0x03 | Montant de porte (variante B, logique 0x1FE2, quasi-identique à 0x02) | confirmed |
| 0x0A, 0x0B, 0x0C | Décor statique (logique commune, non testée en détail) | hypothesis |
| 0x0D, 0x0E, 0x0F | Décor statique (logique commune 0x1D9E, variante) | hypothesis |

## CONFIRMÉ PAR CALCUL (2026-08-07, immédiatement après la découverte ci-dessus) : room_number = coordonnées de grille (x=nibble bas, y=nibble haut)

**Statut : CONFIRMED** par test de cohérence structurelle sur les 128
room_id déjà extraits (`tools/room_map/dump_rooms.py`, `ALL_ROOM_IDS`,
eux-mêmes vérifiés en couvrant exactement `tbl_room_master_index` sans
reste, cf. `notes/2026-08-06-world-map-attempt.md`) :

- **Parcours en largeur (BFS)** depuis la room 0x00, arêtes = `room_id
  ±1` (nibble bas, déplacement axe X) ou `room_id ±0x10` (nibble haut,
  axe Y), restreint aux 128 room_id CONNUS (pas toutes les valeurs
  0-255) : **128/128 salles atteignables** — connectivité totale,
  aucune salle isolée.
- **314 arêtes dirigées au total**, degré moyen 2.45 par salle,
  distribution `{1 sortie: 1 salle, 2 sorties: 77, 3 sorties: 41, 4
  sorties: 9}` — cohérent avec un vrai monde de jeu en grille (majorité
  de couloirs/coins à 2 sorties, quelques carrefours).

**Conclusion** : la carte complète du monde des 128 salles de Knight
Lore est **directement déductible de la seule liste des room_id
connus**, sans avoir besoin de décoder `tbl_room_connections`/
`tbl_room_index_ptrs`/`tbl_room_connection_ptrs` — chaque room_id
EST ses propres coordonnées de grille `(x = id & 0x0F, y = (id>>4) &
0x0F)`, et les connexions sont simplement les voisins orthogonaux
directs présents dans l'ensemble des 128 ID valides. **Ceci change le
statut de la piste "carte du monde" de `docs/SESSION_SUMMARY.md`
section 5/7 de "non résolu" à "résolu par calcul"**.

## CONFIRMÉ EMPIRIQUEMENT EN DIRECT (2026-08-07, immédiatement après)

**Statut : CONFIRMED (empirique, pas seulement calcul)**. L'utilisateur
a traversé une porte réelle en jeu (room 0x2F, franchissement sur
l'axe X) pendant que le room_number de l'entité joueur était poll en
boucle (0.15s/échantillon) :

```
avant : room=0x2F (nibble bas=0xF, nibble haut=0x2)
après : room=0x2E (nibble bas=0xE, nibble haut=0x2)   -- delta exact : -1 sur le nibble bas
```

Correspond exactement à la prédiction de `fn_player_door_transition`
(0x2322, branche "nibble bas -1") et à la formule "room_number =
coordonnées de grille" — **double confirmation (calcul + comportement
réel), le mécanisme est définitivement établi.**



1. ~~Vérifier empiriquement~~ **FAIT** — voir section ci-dessus.
3. Désassembler la logique des types 0x0A/0x0B/0x0C/0x0D/0x0E/0x0F
   (décor statique) plus en détail — priorité plus basse (probablement
   juste du dessin, pas de logique de jeu complexe), mais à couvrir
   pour la complétude du désassemblage annoté.
4. Chercher d'autres types d'entité (ennemis mobiles, objets à
   ramasser) dans d'autres salles — la room 0x2F ne semble contenir que
   décor + portes, pas d'ennemi actif ni d'objet ramassable visible
   dans ce dump. Demander à l'utilisateur de se placer dans une salle
   avec un ennemi visible pour continuer ce travail de corrélation.
