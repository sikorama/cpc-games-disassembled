# Idée notée pour plus tard — rotation de salle par pas de 90° (vues 4 angles)

Proposée par l'utilisateur le 2026-08-07, après la mise en pause de
l'outil de cartographie automatique (voir
`notes/2026-08-07-room-mapping-tool-failure.md`).

## L'idée

En principe, il devrait être possible d'appliquer une rotation par pas
de quart de tour à une salle affichée, en manipulant directement les
paramètres de la projection isométrique déjà entièrement comprise
(`fn_isometric_project`, 0x2EDC — voir `docs/SYMBOLS.md`/
`docs/MEMORY_MAP.md`) plutôt que les données de la salle elle-même.
Chaque salle pourrait ainsi être vue selon 4 angles différents — utile
pour une cartographie/documentation visuelle plus riche, ou pour
vérifier visuellement la géométrie 3D réelle d'une salle (les jeux
isométriques de ce type modélisent en interne un espace 3D, dont une
seule projection 2D fixe est montrée à l'écran).

## Pourquoi c'est plausible (repères techniques déjà connus)

- La projection isométrique est **confirmée** et **entièrement
  formulée** :
  `screen_x = grid_x + grid_y - 0x80 + proj_offset_x`
  `screen_y = (grid_y - grid_x + 0x80)/2 + grid_z_or_offset - 0x68 + proj_offset_y`
  (voir `docs/MEMORY_MAP.md` section "0x2EDC-0x2F01" et
  `docs/SYMBOLS.md` entrée `fn_isometric_project`). Une rotation de 90°
  dans l'espace de la grille 3D sous-jacente correspond à une
  permutation/inversion de signe simple des rôles de `grid_x`/`grid_y`
  (et potentiellement `grid_z_or_offset` selon l'axe de rotation
  choisi) — **exactement le genre de transformation qu'on peut injecter
  en patchant les registres/valeurs juste avant l'appel à
  `fn_isometric_project`**, sans toucher aux données de salle
  elles-mêmes (tables statiques `tbl_room_master_index`, catalogue
  d'objets, etc.).
- `fn_get_orientation_code` (0x22D0) calcule déjà un code d'orientation
  2 bits à partir de bits de flags d'entité + de type — l'existence
  même d'un tel code confirme que le jeu gère plusieurs orientations
  d'affichage par sprite (via `fn_resolve_sprite_shape`/0x31E9, le
  mécanisme de flip/miroir déjà confirmé) — un précédent direct pour
  l'idée de "changer l'angle de vue" en manipulant un paramètre global
  plutôt que les données brutes.
- Le pipeline complet de rendu (culling → collision → projection →
  résolution de forme → blit) est déjà tracé de bout en bout (voir
  `docs/SESSION_SUMMARY.md` section 2/3) — assez de terrain connu pour
  identifier précisément OÙ intercepter/patcher la transformation de
  coordonnées sans devoir tout redésassembler.

## Ce qui reste à vérifier avant de tenter concrètement (prochaine session)

1. **Isoler la vraie transformation 3D→2D complète**, pas seulement la
   projection écran finale — `fn_isometric_project` prend `grid_x`/
   `grid_y`/`grid_z_or_offset` déjà résolus par entité ; il faut
   comprendre si une rotation cohérente de la SALLE ENTIÈRE (pas juste
   une entité isolée) nécessite de transformer ces 3 champs pour
   TOUTES les entités de la salle simultanément (probable), et si un
   axe de rotation supplémentaire (profondeur/hauteur, `grid_z_or_offset`)
   entre en jeu pour une vraie rotation 3D plutôt qu'un simple mirroir
   2D.
2. **Vérifier que la géométrie de fond (pas seulement les entités)**
   suit la même transformation — le "buffer intermédiaire" (zone
   0x8000-0xBFFF, image pré-rendue de la géométrie de la salle avec axe
   Y inversé, voir `docs/MEMORY_MAP.md` section "Modèle mémoire
   global") est-il généré à partir des mêmes coordonnées de grille, ou
   est-ce une image figée indépendante qu'il faudrait re-générer
   entièrement pour chaque angle (auquel cas la rotation ne serait
   PEUT-ÊTRE PAS un simple changement de paramètre, contrairement à ce
   qu'on espère) ? **Point d'incertitude le plus important à lever
   avant d'investir du temps là-dessus.**
3. Une fois 1-2 vérifiés : test empirique minimal — patcher une seule
   entité visible (ex: le joueur) avec des coordonnées transformées
   (échange grid_x/grid_y, ou négation d'un axe) et observer si le
   rendu de CETTE entité seule tourne de façon cohérente avant
   d'étendre à toute la salle.

## Statut

**Idée non testée, notée pour une session future** — à explorer une
fois les prérequis de la cartographie automatique (mécanisme de mort/
réapparition, randomiseur d'objets — voir
`notes/2026-08-07-room-mapping-tool-failure.md`) mieux compris, et
idéalement en parallèle de l'objectif de cartographie complète (une
"vue à 4 angles" par salle serait un vrai plus pour l'outil final, pas
juste une curiosité technique).
