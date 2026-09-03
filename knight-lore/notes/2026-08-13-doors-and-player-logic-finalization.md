# Session 2026-08-13 — finalisation de asm/code/doors_and_player_logic.asm

## Contexte

Poursuite du travail déjà fait sur ce fichier dans la même session (deux
autres agents avaient déjà résolu `fn_player_read_input` #2147-#21E8 et
entièrement désassemblé `entity_logic_mechanical.asm` /
`screen_addressing_and_tables.asm`). Il restait ~19 lignes `defb ...
non désassemblé` (~950 octets) répartis en 8 groupes, du plus petit (10
octets, tail de `fn_door_post_type_B`) au plus gros (~800 octets,
#240B-#26F7, quasiment toute la fin du fichier).

Méthode : décodage manuel octet par octet (via `z80dis.decode` en script
Python jetable, source RAM = `extra/dump_ref.bin`, émulateur live non
accessible cette session), un nouveau symbole `asm/symbols.json` par
point d'entrée réellement atteint (branche conditionnelle non couverte
par le désassemblage linéaire du symbole précédent), puis
`tools/gen_asm.py` sur chaque sous-plage jusqu'à 0 `non désassemblé`,
splice chirurgical dans le fichier (jamais de régénération complète du
fichier — la mise en page manuelle des commentaires ailleurs dans le
fichier est préservée). **33 nouveaux symboles ajoutés au total.**
Résultat final : `grep -c "non désassemblé"` = 0, et
`tools/gen_asm.py 1FE2 26F7` produit un flux d'instructions BYTE-EXACT
identique au fichier final (seule différence résiduelle : une
substitution cosmétique préexistante et non liée à ce travail, `ld
bc,#0038` dans `fn_door_cross_x_min`, que le générateur renommerait à
tort en `fn_im1_interrupt_handler` par collision de valeur — l'auteur
précédent avait déjà choisi de garder la forme brute, décision
respectée ici).

## Petits groupes (branches alternatives déjà connues)

- `fn_door_post_type_B_flag_variant` (#1FF2), `fn_door_post_type_A_type4_variant`
  (#1FF7), `fn_door_post_type_A_flag_variant` (#202C) : variantes de
  calibration de projection déjà pressenties (bit6 de flags, ou
  type==0x04) mais jamais désassemblées — rejoignent des queues déjà
  connues (#1FEB, #200C, #2020).
- `tbl_door_proximity_fine_adjust_dispatch` (#2061) + `fn_door_fine_adjust_y`
  (#2069) + `fn_door_fine_adjust_x` (#207C) : la table de dispatch par
  orientation de porte déjà référencée en prose dans
  `fn_door_proximity_test_2` mais jamais désassemblée. Confirme
  exactement le rôle déjà supposé ("ajuste finement le glissement à
  travers l'ouverture") : porte orientée axe X -> nudge Y du joueur,
  porte orientée axe Y -> nudge X.
- `fn_player_logic_active_body` (#20E6) + `fn_player_logic_view_bounds_tail`
  (#2115) : le corps partagé de `fn_player_logic`/`fn_player_logic_night`,
  déjà décrit en prose de façon assez précise. **Correction apportée** :
  la prose existante disait que le culling (`fn_player_in_view_bounds`
  hors-champ) "saute" la gravité/porte — FAUX. Le désassemblage montre
  que `fn_player_gravity_and_door_dispatch` (#2253) est appelée dans les
  DEUX cas ; la seule différence est que le chemin hors-champ (via
  `fn_player_logic_view_bounds_tail`) traite spécialement le compteur de
  chute (ix+0B) avant de rejoindre exactement le même point (#20FD).
- `fn_player_walk_animation_no_advance` (#2246) : confirme mot pour mot
  la prose déjà écrite ("ne recycle pas sur type&7==2 ou 4").
- `fn_entity_clamp_pending_z` (#230C) + `fn_step_toward_zero` (#233B) :
  utilitaire de convergence signée vers 0, réutilisé ensuite massivement
  dans le gros bloc.

## Le gros bloc #23F7-#26F7 (~800 octets) — ce qu'il fait réellement

C'est la découverte la plus utile de cette session. Contrairement à ce
qu'une lecture rapide du contexte (appelé depuis
`fn_player_gravity_and_door_dispatch`) suggérait, **ce n'est pas du code
spécifique au joueur** : c'est le corps GÉNÉRIQUE de résolution de
mouvement, partagé par `RST 10` (`rst_apply_movement_vector`, #0010 —
confirmé par grep direct : `CALL #23F7` en #0013) et directement appelé
par le joueur. Une ancienne description (dans
`fn_player_gravity_and_door_dispatch`) le qualifiait à tort de simple
"queue de `fn_player_door_transition`" — corrigé dans le fichier et dans
`docs/SYMBOLS.md`.

### fn_entity_movement_vector_resolve (#23F7)

Résout le vecteur de déplacement en attente `(ix+09/0A/0B)` = deltas
X/Y/Z, **dans l'ordre Z puis X puis Y** (pas l'ordre habituel X/Y/Z).
Pour chaque axe, si le delta courant est non-nul :
1. **Clamp** contre une borne de salle (`fn_entity_clamp_pending_z/x/y`,
   #230C/#258F/#25BA — Z contre `var_room_data_field_2` #0074, X/Y
   contre `var_camera_reference`/`_y` #0071/#0072, le même champ que
   `fn_player_in_view_bounds`).
2. Si le delta clampé est ENCORE non-nul : **scan de collision solide**
   contre les 40 entités (`fn_entity_collide_axis_z/x/y`,
   #24EA/#244C/#249B).

L'ordre Z→X→Y explique un détail de conception élégant : les 3
primitives `fn_aabb_axis_gap_x/y/z` (#254F/#2564/#2579, jamais nommées
avant — déjà référencées en prose comme "primitives AABB" dans
`fn_probe_solid_support` #0DE1 et pour `rst_apply_movement_vector`)
prennent en paramètre implicite H/C/L. Au moment du scan X, H contient
déjà le delta Z **résolu** (l'axe précédent) et L vaut encore 0 (l'axe Y
pas encore traité) — donc chaque scan de collision teste le chevauchement
sur les 2 autres axes en utilisant le résultat FINAL pour les axes déjà
traités et 0 (position actuelle, pas de mouvement supposé) pour l'axe
pas encore traité. Confirmé bit à bit, pas juste déduit.

**Découverte annexe notable** : `fn_aabb_axis_gap_x`/`_y` sont
symétriques (somme des deux demi-largeurs/hauteurs), mais
`fn_aabb_axis_gap_z` (+ sa queue `fn_aabb_axis_gap_z_other_extent`
#258A) est **asymétrique** : selon le signe de l'écart de position,
utilise soit la profondeur de l'entité candidate (si elle est au-dessus
— on teste "est-ce que j'atterris sur son sommet"), soit sa propre
profondeur (si en-dessous — "est-ce que je cogne son dessous"). Cohérent
avec une sémantique de gravité réelle, pas une simple AABB générique.

Chaque scan de collision (`fn_entity_collide_axis_*`), en cas de
blocage, synchronise un bit de `state_flags_2` entre les deux entités
ET, si l'entité candidate a bit2 de ses flags actif, **propage le delta
du joueur vers elle** — c'est très probablement le mécanisme générique
de POUSSÉE (tables/blocs poussables déjà documentés en notes) exprimé
au niveau du moteur de collision générique, pas d'une logique dédiée
par type d'entité.

### fn_entity_fall_and_mark_overlap (#25FF) et fn_entity_materialize_dispatch_a/b (#2689/#268E)

`#25FF` est elle aussi générique : appelée directement (`JP`) par la
logique du type 0x08 "herse" (déjà documentée dans
`objects_and_rooms_setup.asm`, commentaire "mouvement/animation de
chute"), ET par 31 entrées de `tbl_entity_logic_dispatch`
(dispatch_and_sound.asm #06B6-#06D4 -> `fn_entity_materialize_dispatch_a`
#2689, #06F6-#0714 -> `fn_entity_materialize_dispatch_b` #268E — motif
calibration jour/nuit identique à `fn_player_logic`/`fn_player_logic_night`
mais pour d'autres types d'entité).

`#25FF` recalcule la bbox écran de l'entité (projection isométrique +
forme, `fn_entity_recompute_screen_bbox` #25E5) puis scanne les 40
entités et pose bit4 de leurs flags si leur empreinte EN ESPACE ÉCRAN
(pas grille) chevauche celle de l'entité courante. Rôle exact non
confirmé par test comportemental cette session — hypothèse : marquage
"à retraiter"/détection de support visuel, PAS un test AABB grille (qui
existe séparément via `fn_aabb_axis_gap_*`).

`fn_entity_materialize_dispatch_a/b`, si pas de matérialisation en
cours (même test bit6 `state_flags_2` -> `jp #17CC` que
`fn_player_logic_night`), copient 7 octets (grid_x..flags) DEPUIS le
slot d'entité **précédent en mémoire** (IX-0x1C, soit -1 structure de
28 octets) VERS l'entité courante — synchronisation sur un "partenaire"
de slot adjacent — puis `fn_entity_materialize_pick_subtype` (#26C3)
choisit le sous-type final : dans l'écrasante majorité des cas (254/256
tirages de `var_pseudo_random_acc`), `type = partenaire.type + 0x10` ;
dans les 2 cas rares restants (`fn_entity_materialize_subtype_low`/`_high`,
#26E1/#26EE), force les 3 bits bas du type à 0x06 ou 0x07 avant le
même `+0x10`. Puis reboucle sur `fn_entity_fall_and_mark_overlap`
(#25FF).

**Piste ouverte** (non résolue cette session, comportement non vérifié
en direct) : ce mécanisme "copie depuis le slot précédent + choix
aléatoire de sous-type + boucle de chute/marquage" ressemble à un
système générique de parenté jour/nuit ou parent/enfant entre slots
adjacents, mais aucun type précis n'a été identifié visuellement comme
utilisant ce chemin (les 31 entrées de dispatch couvrent une large
plage de types — à croiser avec `tbl_entity_logic_dispatch` complet
pour identifier lesquels).

## Corrections apportées aux descriptions existantes

- `fn_player_logic_night` (commentaire inline + résumé) : la prose
  disait que le culling "saute" la gravité/porte — corrigé (voir plus
  haut, `fn_player_logic_active_body`).
- `fn_player_gravity_and_door_dispatch` : `#23F7` n'est PAS une "queue
  de `fn_player_door_transition`", c'est `fn_entity_movement_vector_resolve`,
  routine générique partagée avec `RST 10`. Corrigé dans le fichier
  source et dans `docs/SYMBOLS.md`.

## Vérification finale

- `grep -c "non désassemblé" asm/code/doors_and_player_logic.asm` -> 0
- `python3 tools/gen_asm.py 1FE2 26F7` -> 0 `non désassemblé`, flux
  d'instructions identique octet pour octet au fichier final (diff
  automatisé sur les lignes d'instruction, ignorant labels/commentaires/
  wrapping) à l'exception de la substitution cosmétique préexistante
  `#0038` déjà mentionnée plus haut.
- Émulateur live non accessible cette session (`[offline] émulateur non
  accessible -- utilisation de extra/dump_ref.bin`) : pas de
  spot-check RAM live possible, mais cohérent avec le fait que ce fichier
  boote déjà pixel-perfect depuis cette même source.
