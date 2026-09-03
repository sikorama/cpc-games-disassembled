# Session 2026-08-07 (suite 6) — Room 0x6F : statues de crapaud, boule de cristal (objet sonore)

Suite de `notes/2026-08-07-room-5f-three-doors.md`. Nouvelle salle
(0x6F, toujours thème forêt). Utilisateur : "2 portes, une par laquelle
on vient d'arriver en Y, et une en X-. 3 blocs en bois, surmontés de 3
statues de crapauds. Au plafond 4 pics (qui vont tomber), et 1 boule de
cristal".

## Room 0x6F — inventaire live, corrélé à l'observation utilisateur

| Slots | Type | Rôle | Confirmation utilisateur |
|---|---|---|---|
| 4,5 / 6,7 | 0x04/0x05 | 2 portes (une axe Y, une axe X) | "2 portes, une [...] en Y, et une en X-" ✓ |
| 22,23,24 | 0x06 (×3) | 3 blocs en bois | "3 blocs en bois" ✓ EXACT |
| **25,26,27** | **0x16 (×3)** | **3 statues de crapaud**, MÊMES coordonnées x/y que les blocs 22-24, élévation différente (field3=0x8C vs 0x80 — posées AU-DESSUS) | "surmontés de 3 statues de crapauds" ✓ EXACT |
| 28-31 | 0x3F (×4) | 4 boules à pics au plafond (type déjà confirmé, room 0x4F) | "4 pics [au plafond]" ✓ EXACT |
| **2** | **0x66** | **La boule de cristal** (position isolée, loin du reste) | "1 boule de cristal" ✓ |

**Nouvelle confirmation de la technique de composition en couches** :
les statues de crapaud (0x16) partagent exactement les mêmes
coordonnées grid_x/grid_y que les blocs en bois (0x06) qu'elles
surmontent, seul le 3e champ (`field3`, élévation/profondeur) diffère
— exactement la même logique de superposition déjà vue pour les
"boules à pics" empilées sur leur propre axe Z. Confirme que le moteur
place fréquemment plusieurs entités à la même position XY avec des Z
différents pour composer une scène en couches (bloc + décor posé
dessus), plutôt que de fusionner les deux en un seul sprite.

## Type 0x16 — `fn_toad_statue_logic` (statue de crapaud, confirmed) — CONFIRMÉ IMMOBILE par l'utilisateur

**Statut : confirmed** par désassemblage direct (0x0676 → 0x108C).

```
108C  CALL 113F               ; force bit 5 de (ix+0D) (marqueur générique déjà vu)
108F  JP 1DA8                 ; calibration de projection isométrique (variante F9F4)
```

**Interprétation** : purement décoratif/statique — aucune logique de
mouvement, de collision ni de piège, juste le calage de la projection
isométrique. **Confirmé explicitement par l'utilisateur (2026-08-07)** :
"les crapauds ne bougent pas, ce sont des statues" — le mécanisme de
mort rencontré en jouant (voir plus bas) n'est PAS lié à ce type,
malgré une tentative d'association initiale erronée de ma part.

## Type 0x66 — `fn_crystal_ball_logic` (boule de cristal, confirmed)

**Statut : confirmed** par désassemblage direct (0x0676 → 0x1B2B).
Routine sensiblement plus riche que les décors purs :

```
1B2B  CALL 1D84               ; calibration projection (variante FEF4, non vue auparavant)
1B2E  RST 10                   ; applique un mouvement/vecteur (rst_apply_movement_vector) —
                                ; DONC PAS un objet parfaitement statique, un léger mouvement
                                ; (scintillement/lévitation ?) est appliqué à chaque tick
1B2F  BIT 0,(IX+0D) / JR NZ,1B39
1B35  CALL 1A40 / RET Z         ; sous-routine non explorée — condition de sortie anticipée
1B39  RES 0,(IX+0D)
1B3D  CALL 22A5                 ; sous-routine non explorée
1B40  JP 1AD2                   ; sous-routine non explorée

; --- suite : ARME LE MOTEUR SON (découverte clé) ---
1B43  LD IY,009B                ; struct_sound_channel_slot, CANAL 0 (déjà connu, moteur
                                 ;   d'effets sonores confirmé dans
                                 ;   notes/2026-08-07-transformation-sound.md)
1B47  CALL 096B                 ; avance/vérifie l'état du canal (sous-routine du moteur son)
1B4A  LD D,18 / ... / CALL 0A7B ; résout une fréquence (même mécanisme que le son de
                                 ;   transformation, 0x0A7B déjà rencontré dans
                                 ;   tbl_sound_dispatch)
1B56  LD A,0F / CALL 097D       ; joue la note (fn_psg_write_period_low/full, déjà connues)
1B5C  LD A,(0073) / INC A / AND 07 / LD (0073),A   ; incrémente un compteur cyclique 0-7
                                 ; (0x0073 = var_room_data_field, déjà connu — RÉUTILISÉ ici
                                 ;   comme compteur de phase du scintillement/son, PAS
                                 ;   nécessairement liée à la géométrie de la salle comme
                                 ;   supposé initialement — nouvelle piste, voir plus bas)
```

**Interprétation confirmée** : la boule de cristal n'est PAS un simple
décor statique — elle **joue un effet sonore périodique** via le canal
0 du moteur d'effets sonores (le même moteur déjà identifié pour le
son de la transformation jour/nuit), avec un léger mouvement appliqué
à chaque tick (`RST 10`) — cohérent avec un effet de "scintillement
magique" à la fois visuel et sonore, très caractéristique d'un objet
précieux/spécial dans ce type de jeu (souvent un indice de checkpoint,
un objet à collecter, ou un élément narratif).

**Nouvelle piste sur `(0x0073)`** : précédemment documenté comme
`var_room_data_field` ("champ 3 bits décodé par fn_load_room_data,
rôle exact incertain"). Cette routine le réutilise comme un simple
**compteur cyclique 0-7** pour faire avancer la phase du scintillement/
son — pourrait être une variable RÉUTILISÉE pour plusieurs usages
(comme déjà vu pour `(0x0077)`, `var_transform_flag_and_saved_type`),
pas un champ dédié à la géométrie de salle comme précédemment supposé.
À garder à l'esprit pour la suite (piège potentiel si on suppose un
seul rôle fixe pour cet octet).

## CONFIRMÉ EMPIRIQUEMENT EN DIRECT (2026-08-07, immédiatement après) : ramassage + chute séquentielle

**Statut : CONFIRMED (empirique)**. L'utilisateur a poussé la boule de
cristal (un petit son produit — PAS un scintillement permanent comme
initialement supposé à tort, corrigé : le son n'est déclenché QUE par
une interaction, pas en continu), puis l'a ramassée, pendant que le
slot de son entité (slot 2, type 0x66) était surveillé par polling RAM
(0.1s/échantillon) :

```
t=0.0-5.3s   type=0x66 (boule de cristal normale, légers mouvements de poussée observés)
t=5.4s       type=0x01
t=5.5s       type=0x00   <- disparue de la table d'entités (ramassée, "dans mon inventaire")
```

**Immédiatement après** (dans la même fenêtre d'observation), les 4
boules à pics au plafond (slots 28-31, déjà identifiées) sont tombées
**une par une, séquentiellement**, confirmé par la chute progressive de
leur champ `field3` (grid_z_or_offset, l'élévation) :

```
slot 29 : field3 0xB0 -> 0x80 entre t=6.8s et t=8.3s  (tombe en 1ère)
slot 31 : field3 0xBC -> 0x8C entre t=9.1s et t=12.0s (tombe en 2e)
slot 28 : field3 0xB0 -> 0x80 entre t=13.2s et t=15.0s (tombe en 3e)
slot 30 : field3 0xBC -> 0x8C entre t=15.2s et t=20.0s (tombe en 4e, dernière)
```

**Confirme exactement le mécanisme désassemblé dans
`fn_ceiling_spike_ball_logic`** (0x1092, voir
`notes/2026-08-07-entity-logic-ceiling-spikes.md`) : le verrou partagé
`(0x0085)` garantit qu'**une seule boule tombe à la fois** — observé
sans ambiguïté ici (les 4 chutes ne se chevauchent jamais dans le
temps, chacune se termine avant que la suivante ne commence). Après la
chute (field3 stabilisé à 0x80/0x8C), chaque boule oscille légèrement
autour de sa position finale (visible dans les flags qui continuent de
varier) — cohérent avec un état "tombée au sol, immobile mais
présente" (l'objet reste un danger de collision au sol, pas juste un
effet visuel ponctuel).

**Correction de l'hypothèse initiale sur le son** : la routine
`fn_crystal_ball_logic` arme bien le moteur son (confirmé par
désassemblage), mais **seulement lors d'une interaction du joueur avec
l'objet** (le pousser), pas en boucle permanente comme l'analyse
initiale du désassemblage semblait suggérer — la garde `BIT 0,(IX+0D) /
JR NZ,1B39` (voir désassemblage ci-dessus) filtre probablement
exactement cette condition ("vient d'être poussée"), point qui avait
été mal interprété à la première lecture. **Leçon méthodologique** :
même un désassemblage qui semble clair peut cacher une condition de
garde plus restrictive que prévu — l'observation empirique reste
indispensable pour confirmer QUAND un effet se déclenche réellement,
pas seulement CE QU'il fait.

## Prochaines étapes

1. **Désassembler `0x1A40`, `0x22A5`, `0x1AD2`** (sous-appels non
   explorés de `fn_crystal_ball_logic`) — pourraient révéler le détail
   exact du ramassage (objet consommable confirmé empiriquement,
   mécanisme précis encore non tracé).
2. **Désassembler `0x0A22`** (routine d'impact des boules à pics à la
   fin de leur chute, mentionnée dans
   `notes/2026-08-07-entity-logic-ceiling-spikes.md`) — confirmé
   empiriquement que les boules restent au sol après la chute
   (probable danger de collision permanent, pas juste un effet
   ponctuel).
3. Continuer à vérifier si `(0x0073)` a d'autres usages ailleurs dans
   le code (recherche déjà partiellement faite pour `fn_load_room_data`,
   à recouper avec ce nouvel usage).
4. Poursuivre l'inventaire des types de "décor posé en couche"
   (statue sur bloc, comme ici) — pattern maintenant identifié deux
   fois (boules à pics empilées sur leur axe Z, statues sur blocs) —
   chercher s'il existe une routine générique de composition en
   couches plutôt que des paires ad hoc par thème.
5. Chercher d'autres objets "ramassables" (comme la boule de cristal)
   dans les prochaines salles pour confirmer le pattern
   type-normal → 0x01 → 0x00 (disparition) comme signature générique du
   ramassage — pourrait être réutilisable pour identifier rapidement
   tout futur objet collectable sans avoir à demander confirmation
   utilisateur à chaque fois.
