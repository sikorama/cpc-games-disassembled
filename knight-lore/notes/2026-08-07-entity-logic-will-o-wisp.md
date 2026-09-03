# Session 2026-08-07 (suite 14) — Feux follets (0xB4/0xB5) identifiés : rebond sur axe Y

Suite de `notes/2026-08-07-entity-logic-pushable-table.md`. Nouvelle
salle (0x6B, thème pierre). L'utilisateur décrit : "8 blocs, 2 portes,
et surtout 2 feux follets, qui se déplacent selon Y et qui sont en
hauteur".

## Room 0x6B — inventaire live, corrélé à l'observation utilisateur

| Slots | Type | Rôle | Confirmation utilisateur |
|---|---|---|---|
| 4-7 | 0x02/0x03 | 2 portes | "2 portes" ✓ |
| 8,9,24-29 | 0x07 (×8) | 8 blocs | "8 blocs" ✓ EXACT |
| **30,31** | **0xB4 (×2)** | **LES FEUX FOLLETS**, grid_z=0xA4 (nettement plus haut que les blocs à 0x80/0x8C) | "2 feux follets, en hauteur" ✓ EXACT |

## Type 0xB4/0xB5 — `fn_will_o_wisp_logic` (confirmed)

**Statut : confirmed** par désassemblage direct (0x0676 → 0x10F4).

```
10F4  CALL 1D9E              ; calibration projection
10F7  LD (IX+0B),01          ; réarme un compteur/vecteur
10FB  BIT 1,(IX+0D)          ; teste le SENS courant (axe Y uniquement -- bit 1, PAS bit 0)
10FF  LD A,02
1101  JR NZ,1105
1103  NEG                     ; A = +2 ou -2 selon le sens
1105  LD (IX+0A),A            ; !!! ÉCRIT UNIQUEMENT (IX+0A) = COMPOSANTE Y !!!
                              ; (IX+09) [composante X] N'EST JAMAIS TOUCHÉ -> confirmé :
                              ; le feu follet ne se déplace QUE sur l'axe Y, jamais sur X.
1108  CALL 0A07               ; calcule la somme grid_x+grid_y+grid_z (test générique déjà vu)
110B  RST 10                  ; applique le déplacement (rst_apply_movement_vector)
110C  BIT 1,(IX+0C)           ; teste le FLAG DE COLLISION sur l'axe Y (bit 1 -- même
                              ; convention que fn_resolve_patrol_vector du gardien !)
1110  LD A,02
1112  JR Z,111D                ; si pas de collision, saute la bascule de sens
1114  XOR (IX+0D)              ; sinon : inverse le bit 1 de (ix+0D) -> CHANGE DE SENS
1117  LD (IX+0D),A
111A  CALL 09A6                ; ARME LE SON DE REBOND (même séquence 0x09AC que la
                              ; balle rebondissante, fn_bouncing_ball_logic) -- confirme
                              ; que 0x09A6 est un son de "rebond" générique, pas spécifique
                              ; à la balle.
111D  CALL 1260               ; cycle d'animation 4 phases (fn_animation_cycle_4)
1120  JR 1139                 ; force redessin
```

**Interprétation confirmée** : le feu follet oscille sur l'axe Y
UNIQUEMENT (jamais X), rebondit entre deux bornes en réutilisant
EXACTEMENT le même schéma de rebond par collision que la balle
rebondissante (`fn_bouncing_ball_logic`, 0x1148) et le mécanisme de
changement de direction du gardien (`fn_resolve_patrol_vector`,
0x12A5) : test du bit de collision sur `(ix+0C)`, puis bascule du bit
correspondant dans `(ix+0D)` — **troisième confirmation indépendante
de la même convention de bits collision** cette session (gardien,
table/mur, feu follet). Le son de rebond `0x09A6` est réutilisé sans
modification.

**Élévation confirmée empiriquement** : les deux entités sont à
`grid_z=0xA4`, nettement au-dessus des blocs (0x80/0x8C) — cohérent
avec l'observation "en hauteur".

**Variante voisine (probablement 0xB5)** : bloc `0x1122-0x1147`, un
scintillement pseudo-aléatoire du flag de rendu `(ix+07)` selon
`var_pseudo_random_acc` (0x006D) bit 6, conditionné par `(0x0082)&1` —
cohérent avec l'effet visuel de vacillement d'un feu follet (variation
aléatoire de visibilité/luminosité). Pas testé empiriquement en
détail, mais cohérent avec le nom proposé.

## Bonus méthodologique

Ce type confirme une fois de plus le pattern déjà établi cette
session : **le jeu réutilise systématiquement la même primitive
"oscillation + rebond par collision + son"** pour des entités très
différentes visuellement (balle, feu follet, grille mobile) — même
code de bas niveau, seule la sélection d'axe (X, Y, ou Z) et les
sprites changent. Une bonne partie du "bestiaire" de Knight Lore
repose donc sur un tout petit nombre de primitives de mouvement
génériques, ce qui simplifiera beaucoup la modélisation d'un futur
moteur réécrit (JS/C++) une fois le désassemblage complet.

## Prochaines étapes

1. ~~Vérifier empiriquement en direct que le feu follet ne bouge QUE
   sur Y (jamais X)~~ **FAIT ET CONFIRMÉ** : poll RAM sur ~8s, grid_x
   resté rigoureusement fixe à 0xA8 pendant que grid_y oscille de
   0x99 à 0x67 puis remonte — confirmation empirique exacte du
   désassemblage.
2. Confirmer la variante 0xB5 (scintillement) par observation directe
   si un feu follet change bien de type entre 0xB4/0xB5 au fil du
   temps.
3. Continuer l'inventaire du bestiaire — reste à rencontrer : les
   fantômes à déplacement aléatoire (catégorie 3 de la taxonomie
   utilisateur), toujours pas observés visuellement cette session.
