# Finalisation de entity_logic_mechanical.asm : 91 lignes "non désassemblé" résolues

## Constat de départ

`asm/code/entity_logic_mechanical.asm` (plage `#0FD8-#170D`) contenait 91
lignes `defb ... ; #XXXX non désassemblé` : le générateur mécanique
(`tools/gen_asm.py`) s'arrête toujours au premier saut/retour
inconditionnel rencontré en désassemblant *linéairement* depuis un point
d'entrée `confirmed` — sans jamais suivre les branches réelles (`jr c`,
`jr nz`, etc., qui restent conditionnelles pour lui). Toute queue de
branche qui n'est pas exactement la continuation linéaire du point
d'entrée retombe donc en `defb` brut, même si c'est du vrai code déjà
atteignable depuis un `jr`/`jp` déjà présent dans le fichier.

## Méthode

Phase hors-ligne uniquement (méthodologie section 13), avec un script
maison (`z80dis.decode` en boucle, sans passer par `gen_asm.py`) pour
désassembler à la main n'importe quelle plage `[start,end)` sans avoir
besoin d'enregistrer un symbole au préalable — juste pour explorer et
vérifier une hypothèse de découpage avant de la formaliser dans
`asm/symbols.json`. Chaque défassemblage manuel a été recroisé avec les
octets réels lus sur l'émulateur live (`curl .../api/ram`, disponible
toute la session) pour éliminer tout risque de fabrication.

**Piège rencontré et corrigé en cours de route** : marquer un symbole
`kind: "fn"` avec `status: "hypothesis"` fait que `gen_asm.py` **ne
désassemble PAS son corps du tout** (il retombe en `defb` brut malgré le
symbole présent) — contrairement à `kind: "tbl"`, où le statut n'a aucun
effet sur le dump. Toutes les entrées `fn` de cette passe ont donc été
posées en `status: "confirmed"` (le désassemblage byte-exact l'est
réellement), la prudence sur l'interprétation étant portée dans le texte
de `desc` ("HYPOTHESE ...") plutôt que dans le champ `status`. Deux gaps
avaient aussi été purement oubliés à la première passe (`fn_bouncing_ball_logic`
et `fn_melkhior_room_spawn_check` avaient chacun une queue non traitée) —
retrouvés seulement en relançant `gen_asm.py` sur le fichier entier et en
constatant qu'il restait des `non désassemblé` malgré les symboles déjà
ajoutés.

## Résultat

39 nouveaux symboles dans `asm/symbols.json` (détail complet dans
`docs/SYMBOLS.md`, section "Finalisation de entity_logic_mechanical.asm").
`grep -c "non désassemblé" asm/code/entity_logic_mechanical.asm` = 0.
Fichier entièrement régénéré (`tools/gen_asm.py 0FD8 170D`) et vérifié
octet pour octet identique à la version précédente sur toute la portion
déjà `confirmed` (comparaison automatisée des colonnes d'opcode hex,
209 instructions communes, 0 divergence) — aucune ligne existante n'a été
modifiée, seules les lignes `defb` ont été remplacées par du vrai code, et
quelques opérandes déjà présents ont gagné un nom symbolique (ex.
`call #113F` -> `call fn_entity_apply_decor_state_flags`).

## Points intéressants trouvés en chemin

- **`fn_guard_legs_logic_alt` (0x1027)** : un second point d'entrée
  complet dans la logique jambes du gardien, jamais atteint par le flux
  interne de `fn_guard_legs_logic` lui-même — cohérent avec l'hypothèse
  qu'il existe une entrée dédiée par jambe/sous-type (0x90-0x9D), sans
  preuve directe du site d'appel externe (pas cherché, hors périmètre de
  cette passe).
- **`fn_poltergeist_logic` (0x11B9)** colocalisée juste après son propre
  template de spawn `tbl_melkhior_spawn_template` (0x11A7) — même
  convention que le reste du fichier (spawn-check + logique de l'entité
  spawnée groupés). Confirme au passage un 2e appelant pour
  `fn_animation_cycle_4_tail` (0x1267), déjà identifié comme queue de
  `fn_animation_cycle_4`.
- **`fn_cauldron_logic` (0x1277) / `fn_cauldron_icon_logic` (0x127A)** :
  les stubs de calibration des types 0x8D/0x8E étaient déjà décrits en
  prose dans `docs/SYMBOLS.md` depuis 2026-08-07 ("logique = stub de
  calibration `JP 1DB2`" / "`LD HL,0CE8/JP 1FEB`") mais sans jamais avoir
  reçu d'adresse ni de symbole formel — cette passe les résout
  définitivement (adresses mises à jour dans les entrées 0x8D/0x8E).
- **`tbl_guard_patrol_vector_dispatch` (0x12B1)** : exactement le motif
  déjà documenté pour `tbl_player_forward_vector_dispatch`
  (`asm/code/doors_and_player_logic.asm`) — RST 28, 4 entrées par
  orientation, vecteur par défaut + demi-tour sur collision. Confirme que
  ce motif de dispatch générique (déjà repéré section 9 de
  `docs/METHODOLOGY.md`) est réutilisé au moins deux fois dans le moteur.
- **`fn_control_mode_menu` (0x15C2)** : résout PARTIELLEMENT une citation
  déjà présente ("CALL #15C2 non identifiée", entrée `fn_boot_init_and_new_game`).
  Le corps manipule directement bit0/bit1 de `var_input_mode_flag`
  (0x006C) via lecture clavier — exactement les 2 bits déjà documentés
  ailleurs (`fn_player_read_input`, 0x2147) comme distinguant les modes
  "2 JOYSTICK"/"3 DIRECTIONAL CONTROL". Hypothèse forte que c'est l'écran
  de sélection du mode de contrôle, PAS vérifiée par test comportemental
  (aucun breakpoint posé cette session, uniquement du désassemblage
  hors-ligne).
- **`fn_hud_render_day_counter` (0x154B) / `fn_hud_render_secondary_counter`
  (0x155E)** : résolvent la citation groupée déjà présente dans l'entrée
  `fn_render_disabled_one_time_setup` ("#158D, #154B, #155E (HUD ?)") —
  deux appels quasi-identiques à un helper partagé `fn_hud_render_bcd_digits`
  (0x1571, 4 appelants confirmés maintenant) avec des positions écran et
  des sources différentes.

## La découverte principale : deux blocs de données texte encodées

Deux zones ont été identifiées comme DONNÉES (pas du code) par la méthode
de la section 5/7quater de `docs/METHODOLOGY.md` (désassemblage linéaire
incohérent + regroupement en segments terminés par un octet ≥0x80, la
même convention "terminateur bit7" que `fn_menu_draw_string`) :

1. **`tbl_game_over_screen_strings_a`/`tbl_game_over_screen_strings_b`**
   (0x13B7-0x149B + 0x14AC-0x14F4, 302 octets, séparés par
   `tbl_game_over_screen_message_ptrs` à 0x149C — 8 mots).
2. **`tbl_menu_or_status_data`** (0x167B-0x16D9, 95 octets), juste avant
   `fn_control_mode_menu` et juste après `fn_menu_draw_string_reset_font`.

**Ce qui est CONFIRMÉ** (propriétés structurelles objectives, pas une
impression visuelle) :
- Le code déjà `confirmed` de `fn_game_over_screen_sequence` calcule
  littéralement `LD BC,#149C / ADD HL,BC` puis lit un mot 16 bits — la
  table de 8 pointeurs à 0x149C est donc un vrai tableau de dispatch, pas
  une coïncidence de lecture.
- Les 8 valeurs lues dans cette table (0x14AC, 0x14B4, 0x14BD, 0x14C5,
  0x14CD, 0x14D7, 0x14E2, 0x14EA) tombent CHACUNE exactement sur une
  frontière de segment bit7-terminé de `tbl_game_over_screen_strings_b` —
  vérifié par calcul (script Python, découpage par octet ≥0x80), pas par
  inspection visuelle.
- Les adresses `#1431`/`#1437`/`#1443`, déjà citées littéralement dans le
  code `confirmed` de `fn_game_over_screen_sequence` (chargées dans
  DE/HL avant `CALL #176B`), tombent elles aussi exactement sur des
  frontières de segment de `tbl_game_over_screen_strings_a`.

**Ce qui reste HYPOTHÈSE** : le contenu textuel réel. Les octets sont
dans la plage 0x0A-0x26 (indices de glyphes probables, avec 0x26 très
fréquent — probable séparateur/espace), cohérent avec un rendu via
`fn_menu_draw_string`/`tbl_menu_font` (0x3294), mais **aucune table
glyphe→caractère n'a été établie dans ce projet à ce jour** — donc
impossible de dire avec certitude si ces 8+N messages sont "GAME OVER",
"PLAY AGAIN", des noms de salle, ou autre chose. Ne pas présenter cette
lecture comme acquise sans avoir d'abord établi/vérifié une table de
correspondance glyphe→caractère (piste ouverte pour une session future,
probablement en croisant le rendu écran réel d'un message connu avec son
contenu RAM, comme fait pour d'autres décodages de ce projet).

**Détail non tranché** : l'octet à `#167C` (2e octet de
`tbl_menu_or_status_data`) est aussi écrit comme variable mutable par
`fn_control_mode_menu_palette_indicator_update` (valeurs #0F/#FF selon
bit3 de `var_input_mode_flag`). Réutilisation délibérée d'un octet de
donnée comme scratch (pattern déjà vu dans ce projet pour le code
auto-modifiant, cf. méthodologie section 9) ou chevauchement fortuit entre
deux zones adjacentes ? Pas déterminé — noté tel quel dans
`asm/symbols.json` plutôt que de trancher sans preuve.

## Piste ouverte pour une session future

- Établir une table glyphe→caractère (comparaison capture d'écran réelle
  de l'écran de fin de partie vs contenu RAM à ces adresses) pour décoder
  enfin `tbl_game_over_screen_strings_a`/`_b` et confirmer/infirmer
  l'hypothèse "messages de fin de partie".
- Vérifier en direct (breakpoint) si `fn_control_mode_menu` (0x15C2) est
  bien l'écran de sélection "2 JOYSTICK"/"3 DIRECTIONAL CONTROL" — la
  correspondance de bits est forte mais pas testée comportementalement.
- Site(s) d'appel externe de `fn_guard_legs_logic_alt` (0x1027) : quel
  type d'entité/quelle table de dispatch y saute directement ? Pas
  recherché cette session.
