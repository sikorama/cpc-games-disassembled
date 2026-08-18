; ============================================================
; pickups_and_transform.asm -- genere par tools/gen_asm.py, plage #1A19-#1D27
; Genere mecaniquement depuis la RAM live + asm/symbols.json.
; Ne pas editer les blocs de code a la main : relancer le generateur.
; ============================================================
        org #1A19
fn_pickup_proximity_test:
        ; Test AABB 3 axes (mêmes primitives que le moteur de collision générique,
        ; 0x254F/0x2564/0x2579) avec tolérance Z ±4, retourne carry si contact —
        ; utilisé par fn_bonus_life_pickup_logic (IX/IY swap pour tester contre le
        ; joueur en dur).
        push    bc
        ld    bc,fn_cold_boot_entry
        ld    l,c
        ld    h,c
        call    fn_aabb_axis_gap_x
        jr    nc,loc_1A3E
        call    fn_aabb_axis_gap_y
        jr    nc,loc_1A3E
        ld    a,(ix+off_grid_z_or_offset)
        sub    #04
        ld    (ix+off_grid_z_or_offset),a
        call    fn_aabb_axis_gap_z
        push    af
        ld    a,(ix+off_grid_z_or_offset)
        add    a,#04
        ld    (ix+off_grid_z_or_offset),a
        pop    af
loc_1A3E:
        pop    bc
        ret
fn_pending_vector_zero_test:
        ; Teste si le vecteur en attente (pending_vector_x/pending_vector_y
        ; +0x09/+0x0A, vertical_counter +0x0B) est nul (OR des 3 octets, Z si tout
        ; à zéro). Utilisée par fn_crystal_ball_logic (#1B35, call #1A40 / ret z)
        ; pour détecter la fin d'un déplacement en cours
        ld    a,(ix+#09)
        or    (ix+#0A)
        or    (ix+#0B)
        ret
fn_bonus_life_pickup_logic:
        ; Logique du type d'entité 0x67 — le 8e des 8 types tirés par
        ; fn_catalog_randomize_types, DIFFÉRENT des 7 autres (0x60-0x66, tous
        ; fn_crystal_ball_logic). Teste la proximité du joueur
        ; (fn_pickup_proximity_test 0x1A19, IX forcé à 0x00D7 = joueur); si
        ; contact: INC (0x0080) (var_life_counter, VIE SUPPLÉMENTAIRE), arme le
        ; moteur son, affiche un message en réutilisant le moteur de texte du MENU
        ; (fn_menu_draw_string/0x170D, patch (0x008C)=tbl_menu_font), force un
        ; blit immédiat. En ramassant l'objet dans sa partie en cours (salle 0x8D,
        ; sans reset): "une vie, qu'on peut ramasser mais pas conserver dans
        ; l'inventaire des objets" — correspond exactement au désassemblage
        ; (aucune écriture de var_object_notify_flag/tbl_hud_slot_icons, à la
        ; différence du chemin normal d'objet). Contenu exact du message HUD et de
        ; la séquence sonore 0x0040 encore non décodés. (désassemblage direct de
        ; la suite #1A6A-1A90): au contact, SET bit3,(type), PUIS lit
        ; (ix+10)/(ix+11) comme pointeur (même rôle que pour les entités objets
        ; 0x60-0x66, voir fn_object_catalog_writeback) et écrit 0x00 à cette
        ; adresse — zère le champ type de sa PROPRE entrée tbl_object_catalog,
        ; cohérent avec "pas conservé dans l'inventaire" (contrairement aux 7
        ; autres, aucune trace dans tbl_hud_slot_icons, juste le catalogue mis à
        ; jour directement).
        call    fn_static_calib_vector_table
        push    ix
        pop    iy
        ld    ix,struct_entities_base
        inc    (ix+off_bbox_w)
        inc    (ix+off_bbox_h)
        call    fn_pickup_proximity_test
        dec    (ix+off_bbox_w)
        dec    (ix+off_bbox_h)
        push    iy
        pop    ix
        jr    nc,loc_1A90
        set    3,(ix+off_type)
        call    #1D84
        ld    l,(ix+off_transform_step_counter)
        ld    h,(ix+#11)
        ld    (hl),#00
        ld    hl,var_life_counter
        inc    (hl)
        xor    a
        ld    (var_room_reset_flag_5),a
        ld    hl,#0040
        call    #0A14
        call    fn_hud_render_secondary_counter
        ld    bc,buf_visible_entities
        call    fn_hud_icon_redraw_8x4
loc_1A90:
        jp    #1D74
fn_treasure_settle_and_sequence_check:
        ; Corrigée après un test négatif (breakpoints sur 0x1AE9/0x1B02 non
        ; déclenchés en reposant/reprenant le "diamant", type 0x60 — ce code N'EST
        ; PAS dispatché par la famille 0x60-0x67 comme supposé initialement, mais
        ; par 0x68-0x6E, confirmé par scan exhaustif de
        ; tbl_entity_logic_dispatch). Fait converger grid_x/grid_y vers 0x80 et
        ; tomber grid_z jusqu'au sol (RST 10 en boucle, tail
        ; fn_treasure_settle_ground_check #1AD8), puis
        ; (fn_treasure_pickup_sequence_advance #1AE5) compare type&7 à
        ; tbl_pickup_sequence_order[var_pickup_sequence_counter] (lookup via
        ; fn_pickup_sequence_lookup #1B14) — si ça correspond: compteur+=1, jingle
        ; (fn_pickup_sequence_jingle 0x1B43), et au 14e succès déclenche
        ; fn_pickup_sequence_complete_transform (0x1B76). Désassemblage CONFIRME
        ; structurellement l'hypothèse au bit près — asm. Les 7 types 0x68-0x6E
        ; partagent EXACTEMENT les sprites de 0x60-0x66 (décalage +8) mais le
        ; mécanisme de création d'une entité 0x68-0x6E reste NON localisé (pas via
        ; fn_catalog_randomize_types, pas via fn_collision_effect). PISTE MAJEURE
        ; (confirmée empiriquement pour le mécanisme d'INDICE, pas encore pour la
        ; CRÉATION d'entité): ce puzzle est très probablement celui du chaudron de
        ; Melkhior (salle 0x88) — le poltergeist spawné par
        ; fn_melkhior_room_spawn_check (#1188) affiche l'objet attendu via les
        ; types-indices 0xA8-0xAF (voir cette entrée et la constante 0xA8-0xAF ci-
        ; dessous), confirmé ("indique quel objet déposer ensuite"). Le
        ; déclencheur de création d'entité 0x68-0x6E est probablement l'action de
        ; DÉPOSER un objet spécifiquement dans/près du chaudron (via
        ; fn_player_use_held_object #18AA) plutôt qu'ailleurs — reste à vérifier
        ; en direct.
        call    #1D84
        ld    a,(ix+off_grid_x)
        sub    #80
        jr    z,loc_1AA4
        ld    a,#01
        jp    m,loc_1AA4
        neg
loc_1AA4:
        ld    (ix+#09),a
        ld    a,(ix+off_grid_y)
        sub    #80
        jr    z,loc_1AB5
        ld    a,#01
        jp    m,loc_1AB5
        neg
loc_1AB5:
        ld    (ix+#0A),a
        ld    a,(ix+off_grid_x)
        cp    #80
        jr    nz,loc_1AC4
        xor    (ix+off_grid_y)
        jr    z,fn_treasure_settle_ground_check
loc_1AC4:
        ld    a,(ix+off_grid_z_or_offset)
        cp    #98
        ld    a,#01
        jr    nc,loc_1ACE
        inc    a
loc_1ACE:
        ld    (ix+#0B),a
loc_1AD1:
        rst    #10
loc_1AD2:
        call    fn_position_pitch_sound_arm
        jp    #1F7B
fn_treasure_settle_ground_check:
        ; Suite de fn_treasure_settle_and_sequence_check (#1A93): teste si grid_z
        ; a atteint 0x80 (sol); sinon pose bit1 de flags (+0x07) et reboucle sur
        ; l'application du vecteur (#1AD1) jusqu'à atterrissage effectif
        ld    a,#80
        cp    (ix+off_grid_z_or_offset)
        jr    nc,fn_treasure_pickup_sequence_advance
        set    1,(ix+off_flags)
        jr    loc_1AD1
fn_treasure_pickup_sequence_advance:
        ; Force grid_z=#80 (pose au sol), lit
        ; tbl_pickup_sequence_order[var_pickup_sequence_counter] via
        ; fn_pickup_sequence_lookup, compare a (off_type AND 7) ; si egal :
        ; var_pickup_sequence_counter+=1, joue fn_pickup_sequence_jingle, et si le
        ; compteur atteint 14 appelle fn_pickup_sequence_complete_transform. Dans
        ; tous les cas : remet var_special_input_mode_2=0, efface le pointeur
        ; catalogue objet, puis reprend l'idle generique.
        ld    (ix+off_grid_z_or_offset),#80
        call    fn_pickup_sequence_lookup
        ld    a,(ix+off_type)
        and    #07
        cp    (hl)
        jr    nz,loc_1B05
        ld    hl,var_pickup_sequence_counter
        inc    (hl)
        call    fn_pickup_sequence_jingle
        ld    a,(var_pickup_sequence_counter)
        cp    #0E
        jr    nz,loc_1B05
        call    fn_pickup_sequence_complete_transform
loc_1B05:
        xor    a
        ld    (var_special_input_mode_2),a
        ld    l,(ix+off_transform_step_counter)
        ld    h,(ix+#11)
        ld    (hl),#00
        jp    #1239
fn_pickup_sequence_lookup:
        ; HL = tbl_pickup_sequence_order + var_pickup_sequence_counter, tail-jump
        ; dans rst_add_hl_a (#0008) qui RET directement vers l'appelant de
        ; fn_pickup_sequence_lookup
        ld    a,(var_pickup_sequence_counter)
        ld    hl,tbl_pickup_sequence_order
        jp    rst_add_hl_a
tbl_pickup_sequence_order:
        ; 14 octets exactement (borne confirmée par cp #0E en #1AFE): 01 02 04 00
        ; 01 02 03 04 05 06 03 05 00 06 (transcription du jour où capturé) — ordre
        ; attendu (type&7) pour le puzzle de collecte de
        ; fn_treasure_settle_and_sequence_check, consommé via
        ; fn_pickup_sequence_lookup (#1B14). Chaque valeur 0-6 apparaît exactement
        ; 2 fois. Cette table n'est PAS fixe — fn_shuffle_pickup_sequence_order
        ; (#0E28) la fait tourner (rotation circulaire) d'un nombre de positions
        ; pseudo-aléatoire (4-7) une fois au lancement de chaque partie, donc le
        ; contenu ci-dessus n'est qu'un instantané valable pour la partie où il a
        ; été transcrit.
        defb #01,#02,#04,#00,#01,#02,#03,#04,#05,#06,#03,#05,#00,#06
fn_crystal_ball_logic:
        ; Logique du type d'entité 0x66 (boule de cristal) — applique un léger
        ; mouvement (RST 10) ET arme le moteur d'effets sonores (canal 0,
        ; struct_sound_channel_slot 0x009B) UNIQUEMENT lors d'une interaction du
        ; joueur (poussée), pas en boucle permanente. Ramassable (disparaît de la
        ; table d'entités via type -> 0x01 -> 0x00, "objet dans l'inventaire").
        ; Cycle de phase via (0x0073) réutilisé comme compteur 0-7.
        call    #1D84
        rst    #10
        bit    0,(ix+off_state_flags_2)
        jr    nz,loc_1B39
        call    fn_pending_vector_zero_test
        ret    z
loc_1B39:
        res    0,(ix+off_state_flags_2)
        call    #22A5
        jp    loc_1AD2
fn_pickup_sequence_jingle:
        ; Joue le flash de couleur Gate Array synchronise avec le son via
        ; fn_gate_array_config_stream, appelee a chaque etape validee du puzzle de
        ; collecte.
        ld    iy,struct_sound_channel_slot
        call    fn_sound_toggle_mixer_bit_b
        ld    d,#18
loc_1B4C:
        ld    a,d
        rlca
        rlca
        ld    l,a
        ld    h,#00
        push    de
        call    fn_sound_write_period_hl
        ld    a,#0F
        call    fn_sound_write_volume
        pop    de
        ld    a,(var_sparkle_and_jingle_phase)
        inc    a
        and    #07
        ld    (var_sparkle_and_jingle_phase),a
        call    fn_gate_array_palette_cycle
        ld    bc,#2000
loc_1B6B:
        dec    bc
        ld    a,b
        or    c
        jr    nz,loc_1B6B
        dec    d
        jr    nz,loc_1B4C
        jp    #0914
fn_pickup_sequence_complete_transform:
        ; Pose var_special_input_mode_1=1 (probable gel de la logique joueur/HUD),
        ; force les slots d'entite 3-13 a type=0x01, puis convertit tout slot de
        ; type 0x07 (bloc statique) en type=0x83 (fn_hostile_patrol_logic) parmi
        ; les slots 3-39 (borne #0537 = struct_entities_base + 40x28).
        ld    a,#01
        ld    (var_special_input_mode_1),a
        push    ix
        ld    ix,#012B
        ld    de,#001C
        ld    b,#0B
loc_1B86:
        push    bc
        push    de
        call    #1F7B
        pop    de
        pop    bc
        ld    (ix+off_type),#01
        add    ix,de
        djnz    loc_1B86
        ld    bc,fn_boot_init_and_new_game
loc_1B98:
        ld    a,(ix+off_type)
        cp    #07
        jr    nz,loc_1BA3
        ld    (ix+off_type),#83
loc_1BA3:
        add    ix,de
        push    ix
        pop    hl
        and    a
        sbc    hl,bc
        jr    c,loc_1B98
        pop    ix
        ret
fn_player_transform_trigger:
        ; Appelée chaque frame depuis fn_player_logic (0x20E6) tant que le joueur
        ; est en forme stable. Si var_transform_flag_and_saved_type (0x0077)
        ; demande une transformation ET que le cooldown (ix+0C) est écoulé:
        ; sauvegarde le type courant dans (0077), initialise le compteur de sous-
        ; étapes (ix+10)=8, force le redessin, PUIS enchaîne directement (via INC
        ; SP ×2 pour sauter le RET) dans le tail partagé de
        ; fn_player_transform_tick sans revenir à l'appelant cette frame.
        ld    a,(var_transform_flag_and_saved_type)
        and    a
        ret    z
        ld    a,(ix+off_cooldown_or_collision_flags)
        and    #F0
        ret    nz
        bit    3,(ix+off_cooldown_or_collision_flags)
        ret    nz
        inc    sp
        inc    sp
        ld    a,(ix+off_type)
        ld    (var_transform_flag_and_saved_type),a
        ld    (ix+off_transform_step_counter),#08
        push    ix
        ld    de,#001C
        add    ix,de
        ld    (ix+off_type),#01
        call    #1F7B
        pop    ix
        call    #1D99
        jr    loc_1C04
fn_player_transform_tick:
        ; Dispatch logique des 4 types transitoires 0x5C-0x5F
        ; (tbl_entity_logic_dispatch). Choisit à chaque tick (throttlé 1 frame/4)
        ; un type transitoire pseudo-aléatoire parmi 0x5C-0x5F (jamais le même 2
        ; fois de suite), bascule bit 6 de (ix+07) (tremblement visuel),
        ; décrémente (ix+10); à 0, saute vers la complétion (0x1C24).
        call    #1D99
        bit    6,(ix+off_state_flags_2)
        jr    z,fn_player_transform_tick_pick_type
        ld    a,(var_special_input_mode_1)
        and    a
        jr    nz,fn_player_transform_tick_pick_type
        jp    #17CC
fn_player_transform_tick_pick_type:
        ; Tire un type parmi 0x5C-0x5F pour l'etape courante de l'animation de
        ; transformation jour/nuit du joueur.
        ld    a,(var_frame_counter)
        and    #03
        ret    nz
        ld    hl,tbl_sound_descriptor_sweep_nibble_swap
        call    fn_sound_arm_channel_2
        dec    (ix+off_transform_step_counter)
        jr    z,fn_player_transform_complete
loc_1C04:
        ld    a,r
        ld    c,a
        ld    a,(var_pseudo_random_acc)
        add    a,c
        and    #03
        or    #5C
        cp    (ix+off_type)
        jr    nz,loc_1C16
        xor    #01
loc_1C16:
        ld    (ix+off_type),a
        ld    a,(ix+off_flags)
        xor    #40
        ld    (ix+off_flags),a
        jp    #1F7B
fn_player_transform_complete:
        ; Complétion de la transformation: type_final = (0077) XOR 0x20 -- la
        ; bascule 0x14 (jour) <-> 0x34 (nuit) -- écrit (ix+00) et
        ; (ix+1C)=type_final+0x10, remet (0077)=0 (idle), ajuste finement (ix+13)
        ; selon bit5 du type final.
        ld    a,(var_transform_flag_and_saved_type)
        xor    #20
        ld    (ix+off_type),a
        add    a,#10
        ld    (ix+off_type_mirror_plus_10),a
        xor    a
        ld    (var_transform_flag_and_saved_type),a
        call    #1D89
        bit    5,(ix+off_type)
        jr    z,loc_1C41
        dec    (ix+off_proj_offset_y)
loc_1C41:
        jp    #1F7B
fn_hud_day_night_cycle:
        ; Anime le HUD soleil/lune (cycle jour/nuit), incrémente var_day_counter
        ; (0x007F) quand le cycle boucle.
        ld    a,(var_frame_counter)
        and    #07
        ret    nz
        ld    ix,var_day_night_flag
        inc    (ix+off_screen_x)
        ld    a,(var_special_input_mode_1)
        and    a
        ret    nz
        ld    a,(ix+off_screen_x)
        cp    #E1
        jr    z,fn_hud_day_night_cycle_end
        ld    a,(ix+off_screen_x)
        add    a,#10
        ld    hl,tbl_hud_sun_moon_height_curve
        rrca
        rrca
        and    #0F
        rst    #08
        ld    a,(hl)
        ld    (ix+off_screen_y),a
loc_1C6E:
        ld    bc,#1F0C
        ld    hl,#97EE
        push    bc
        push    hl
        ld    a,c
        ld    c,b
        ld    b,a
        xor    a
        call    fn_fill_rect
        call    #2F2B
        ld    ix,#1877
        ld    (ix+off_flags),#00
        ld    (ix+off_type),#5A
        ld    (ix+off_screen_x),#B0
        ld    (ix+off_screen_y),#00
        call    #2F2B
        ld    (ix+off_screen_x),#D0
        ld    (ix+off_type),#BA
        call    #2F2B
        pop    hl
        pop    bc
        ld    de,#C676
        ld    a,(var_render_disabled_flag)
        and    a
        ret    nz
        jp    fn_blit_copy_line
fn_hud_day_night_cycle_end:
        ; Fin de cycle de fn_hud_day_night_cycle (49 paliers x8 frames): bascule
        ; bit0 de off_type (0x58<->0x59, icône soleil/lune), remet l'icône en
        ; position écran initiale (off_screen_x=0xB0), pose
        ; var_transform_flag_and_saved_type=1 (DEMANDE de transformation joueur),
        ; puis si bit0 de var_day_night_flag est nul (nuit->jour): incrémente
        ; var_day_counter (BCD), teste le passage à 0x40 (jp
        ; z,fn_game_over_or_daycycle_end), sinon redessine le compteur de jours et
        ; l'icône (fn_hud_icon_redraw_8x4 #1CDF)
        ld    a,(ix+off_type)
        xor    #01
        ld    (ix+off_type),a
        ld    (ix+off_screen_x),#B0
        ld    a,#01
        ld    (var_transform_flag_and_saved_type),a
        ld    a,(var_day_night_flag)
        and    #01
        ret    nz
        ld    hl,var_day_counter
        ld    a,(hl)
        add    a,#01
        daa
        ld    (hl),a
        cp    #40
        jp    z,fn_game_over_or_daycycle_end
        call    fn_hud_render_day_counter
        ld    bc,#0778
        call    fn_hud_icon_redraw_8x4
        jp    loc_1C6E
fn_hud_icon_redraw_8x4:
        ; Helper de redessin d'icône HUD 8x4 (BC=coordonnées écran):
        ; fn_screen_addr_from_bc (#3195) + fn_buffer_addr_from_vram (#3186) puis
        ; jp fn_blit_copy_line (#2EC0) avec BC=#0804. Partagé par
        ; fn_bonus_life_pickup_logic (#1A8D, icône de vie) et
        ; fn_hud_day_night_cycle_end (#1CD9, icône soleil/lune)
        call    fn_screen_addr_from_bc
        ld    l,c
        ld    h,b
        call    fn_buffer_addr_from_vram
        ld    bc,#0804
        jp    fn_blit_copy_line
tbl_hud_sun_moon_height_curve:
        ; 13 octets, rampe symétrique 05 06 07 08 09 0A 0A 09 08 07 06 05 05,
        ; indexée par fn_hud_day_night_cycle (#1C62) pour fixer off_screen_y de
        ; l'icône soleil/lune. Off_screen_x n'avançant que par pas de 0x10, seuls
        ; les index 0/4/8/12 (valeurs 05/09/08/05) sont réellement lus après le
        ; double RRCA d'indexation — les 9 autres octets de la rampe ne sont
        ; jamais adressés par ce mécanisme précis. Immédiatement suivie par
        ; var_day_night_flag (#1CFA), simple juxtaposition mémoire, pas un octet
        ; de table
        defb #05,#06,#07,#08,#09,#0A,#0A,#09,#08,#07,#06,#05,#05
ram_var_day_night_flag_pseudo_entity:
        ; Pseudo-entite HUD jour/nuit: reutilise integralement le layout
        ; struct_entities_base
        ds #001C
fn_hud_day_night_icon_init:
        ; Initialise la pseudo-entité HUD jour/nuit (var_day_night_flag #1CFA
        ; traitée comme IX de struct entité): off_type=0x58, off_screen_x=0xB0,
        ; off_screen_y=0x09
        ld    ix,var_day_night_flag
        ld    (ix+off_type),#58
        ld    (ix+off_screen_x),#B0
        ld    (ix+off_screen_y),#09
        ret
