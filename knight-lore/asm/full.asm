        org #0000
fn_cold_boot_entry:
        ; POINT D'ENTRÉE MACHINE: DI / LD SP,#8100 / JP #0537 — 4 octets utiles
        ; avant le vecteur RST 08. Le premier octet est 0xF3 (DI), pas NOP (0x00)
        ; comme précédemment transcrit — erreur détectée en croisant une vraie
        ; passe de réassemblage rasm du source ASM contre un dump RAM live
        ; (confirmé identique sur 8 snapshots indépendants pris à des dates
        ; différentes). DI avant l'initialisation de la pile est la séquence de
        ; boot Z80 standard, cohérente avec l'enchaînement observé. Enchaîne
        ; directement dans fn_boot_init_and_new_game.
        di
        ld    sp,STACK_TOP_INIT
        jp    fn_boot_init_and_new_game
        ; non désassemblé
        defb #00
rst_add_hl_a:
        ; RST 08: HL = HL + A (addition 16+8 bits, primitive manquante du Z80)
        add    a,l
        ld    l,a
        ld    a,h
        adc    a,#00
        ld    h,a
        ret
        ; non désassemblé
        defb #00
rst_apply_movement_vector:
        ; RST 10: entité.position[grid_x/y/z] += entité.champ[+09/+0A/+0B] (3
        ; octets) — primitive de déplacement générique utilisée par toutes les
        ; entités mobiles une fois leur vecteur de déplacement résolu dans les
        ; champs +09..+0B. Appelle aussi fn_entity_movement_vector_resolve en
        ; prélude (décrémente (ix+0B) AVANT que RST 10 ne le lise comme vecteur —
        ; deux usages différents du même octet à des moments différents, piège
        ; potentiel).
        dec    (ix+#0B)
        call    fn_entity_movement_vector_resolve
loc_0016:
        push    ix
        pop    de
        inc    de
        ld    hl,rst_add_hl_a
        add    hl,de
        ld    b,#03
loc_0020:
        ld    a,(de)
        add    a,(hl)
        ld    (de),a
        inc    hl
        inc    de
        djnz    loc_0020
        ret
rst_dispatch_table:
        ; RST 28: dispatch générique — HL = table[L] (word, BC=base table), puis
        ; JP (HL)
        ld    h,#00
        add    hl,hl
        add    hl,bc
        ld    a,(hl)
        inc    hl
        ld    h,(hl)
        ld    l,a
        jp    hl
fn_zero_fill_de:
        ; (en préparant le désassemblage contigu #0000-#4000): XOR A / LD (DE),A /
        ; INC DE, B fois (DJNZ) — remplissage mémoire à zéro générique, variante
        ; "DE" de fn_mem_fill_simple (0x2D91, variante "HL")
        xor    a
loc_0032:
        ld    (de),a
        inc    de
        djnz    loc_0032
        ret
        ; non désassemblé
        defb #00
fn_im1_interrupt_handler:
        ; Le VRAI vecteur d'interruption IM1 (adresse fixe matérielle Z80) — PUSH
        ; AF/BC/DE/HL/IY, CALL fn_sound_engine_tick (0x08CC), POP (ordre inverse),
        ; EI, RET.
        push    af
        push    bc
        push    de
        push    hl
        push    iy
        call    fn_sound_engine_tick
        pop    iy
        pop    hl
        pop    de
        pop    bc
        pop    af
        ei
        ret
fn_gate_array_config_stream:
        ; Source des données (HL) RÉSOLUE: au moins un appelant est
        ; fn_gate_array_palette_cycle (#07EE), qui sélectionne un des 4 flux de
        ; tbl_palette_stream_ptrs (#07FD) selon var_sparkle_and_jingle_phase
        ; (#0073) — voir ces entrées
        ld    bc,#7F00
loc_004C:
        ld    a,(hl)
        inc    hl
        cp    #FF
        ret    z
        out    (c),a
        jr    loc_004C
tbl_ga_config_stream_boot:
        ; 13 octets (#0055-#0061) : #0055-#0060 (12 octets, termine par #FF a
        ; #0060) est le script de config Gate Array (mode ecran + encres) consomme
        ; par fn_gate_array_config_stream (#0049), appele 2 fois avec HL=#0055
        ; depuis le code du menu (#15DC/#15EB). PAS de l'etat de partie
        ; (contrairement au reste de la zone #0055-00D6, ds/runtime) :
        ; fn_mem_fill_simple ne touche jamais #0055-#0067, donc rien ne le
        ; reinitialise. Sans ce terminateur, la boucle d'ecriture de
        ; fn_gate_array_config_stream ne s'arrete plus normalement. L'octet #0061
        ; suit immediatement le terminateur ; role exact non trace.
        defb #8D,#10,#54,#00,#54,#01,#4A,#02,#55,#03,#55,#FF,#00
zone_var_ram_basse:
        ; Zone de variables RAM basse (zero-page-like):
        ; var_*/tbl_hud_slot_icons/struct_sound_channel_slot
        ds #0075
struct_entities_base:
        ; Tableau actif de 40 structures d'entite (28 octets chacune, off_* voir
        ; include/entity_struct.equ.asm): etat runtime mutable
        ds #0460
fn_boot_init_and_new_game:
        ; RÉSOUT le point d'entrée du jeu (précédé de 7 octets de bourrage
        ; 0x0530-0x0536). Remplit (0x0068)+0x04CF avec fn_mem_fill_simple, PUIS
        ; rejoint le code partagé avec fn_restart_from_menu (0x0542): arme les
        ; registres PSG (ports #F700/#F600), passe en IM1, efface
        ; (0x0078)/(0x29F7), initialise (0x0080)=5, accumule
        ; (0x0068)+=var_frame_counter, efface l'écran (fn_clear_screen), puis CALL
        ; fn_build_pixel_bitscatter_tables et teste un octet dérivé de (0x056E):
        ; si la condition n'est pas remplie, RET (boucle d'attente, rappelé tant
        ; qu'aucune sélection valide); sinon enchaîne la séquence de nouvelle
        ; partie déjà connue (CALL fn_init_room_selection #0599, CALL #1D16 #059C,
        ; CALL fn_catalog_randomize_types #059F, CALL fn_init_room_entities #05A2,
        ; CALL fn_init_room #05A5) puis tombe dans fn_main_loop (#05AE).
        ; Désassemblage complet vérifié via tools/disasm.py 0530 - 0620.
        ld    hl,var_newgame_random_seed
        ld    bc,#04CF
        call    fn_mem_fill_simple
        jr    loc_054B
fn_restart_from_menu:
        ; 2e point d'entrée, variante de fn_boot_init_and_new_game qui saute le
        ; remplissage mémoire initial (remplit (0x0070)+0x04C7 à la place) puis
        ; rejoint le même code partagé. L'HYPOTHÈSE ("le point d'entrée, a priori
        ; c'est le menu du jeu, comme après un game over"): c'est exactement la
        ; cible de jp #0542 utilisée par fn_game_over_or_daycycle_end (#12FB) pour
        ; revenir "au menu" après un game over/fin de cycle — même code que le
        ; tout premier lancement, juste sans refaire le remplissage mémoire déjà
        ; fait au boot froid.
        ld    hl,var_blit_stack_counter
        ld    bc,#04C7
        call    fn_mem_fill_simple
loc_054B:
        call    fn_arm_interrupt_flag
        ld    bc,PORT_PSG_SELECT
        ld    a,#82
        out    (c),a
        ld    bc,PORT_PSG_LATCH
        xor    a
        out    (c),a
        ld    hl,tbl_psg_reset_stream
        call    fn_psg_register_init_stream
        ld    a,#3F
        ld    (var_sound_mixer_mask),a
        im    1
        xor    a
        ld    (var_room_transition_flag),a
        ld    (#29F7),a
        ld    a,#05
        ld    (var_life_counter),a
        ld    hl,var_newgame_random_seed
        ld    a,(var_frame_counter)
        add    a,(hl)
        ld    (hl),a
        call    fn_clear_screen
        call    fn_build_pixel_bitscatter_tables
        ld    hl,#056E
        inc    hl
        inc    hl
        ld    a,(hl)
        sla    a
        cp    #0A
        ret    nz
        call    fn_control_mode_menu
        ld    hl,tbl_sound_program_ptrs_unused_a
        call    fn_sound_program_channel_setup
        call    fn_shuffle_pickup_sequence_order
        call    fn_init_room_selection
        call    fn_hud_day_night_icon_init
        call    fn_catalog_randomize_types
        call    fn_init_room_entities
loc_05A5:
        call    fn_init_room
loc_05A8:
        ld    a,(var_frame_counter)
        ld    (var_entity_update_counter),a
fn_main_loop:
        ; BOUCLE PRINCIPALE DE JEU. IX=struct_entities_base, SP=#8100 (reset pile
        ; — répété à CHAQUE itération d'entité, PAS une seule fois par frame, voir
        ; ci-dessous), sauvegarde position courante->précédente (+14..17 ->
        ; +18..1B) pour chaque entité, CALL fn_arm_interrupt_flag (répété par
        ; entité aussi), incrémente var_entity_update_counter, dispatch logique/IA
        ; via RST 28 (table tbl_entity_logic_dispatch) à
        ; fn_main_loop_entity_dispatch (#05D4), mélange var_pseudo_random_acc UNE
        ; 1re FOIS ce tour, avance IX de 28 octets, boucle tant que IX < #0537
        ; (boucle PAR ENTITÉ, #05B2-#05F5). Puis, UNE FOIS par frame (pas par
        ; entité): fn_frame_tick_and_mix (#05F7 — incrémente var_frame_counter 16
        ; BITS et mélange var_pseudo_random_acc une 2e fois, formule complète
        ; vérifiée en direct, voir son entrée),
        ; fn_arm_room_transition_flag_and_wait (#0607 — pose inconditionnellement
        ; bit0 de var_room_transition_flag, fn_wait_keyboard_sync #2D6D, #1188 non
        ; identifiée, fn_cull_entities #26F7, fn_render_entities #2DE2),
        ; fn_render_workload_pacing_delay (#0618, NOUVEAU — délai de calage
        ; dépendant de la charge de rendu), fn_render_disabled_one_time_setup
        ; (#062F, NOUVEAU — init unique pendant la matérialisation, explique le
        ; cycle de vie de var_render_disabled_flag),
        ; fn_frame_end_player_alive_check (#0658, NOUVEAU — LE VRAI POINT DE
        ; BOUCLE PAR FRAME, distinct de la boucle par entité: JP #05A2 si joueur
        ; totalement invalide, sinon JP #05A8 qui referme la boucle vers #05AE).
        ld    ix,struct_entities_base
loc_05B2:
        ld    sp,STACK_TOP_INIT
        call    fn_arm_interrupt_flag
        ld    hl,var_entity_update_counter
        inc    (hl)
        ld    a,(ix+off_screen_w)
        ld    (ix+off_screen_w_prev),a
        ld    a,(ix+off_screen_h)
        ld    (ix+off_screen_h_prev),a
        ld    a,(ix+off_screen_x)
        ld    (ix+off_screen_x_prev),a
        ld    a,(ix+off_screen_y)
        ld    (ix+off_screen_y_prev),a
fn_main_loop_entity_dispatch:
        ; Point de dispatch par entité À L'INTÉRIEUR de fn_main_loop (#05AE):
        ; L=(ix+00), BC=tbl_entity_logic_dispatch, RST 28. Cible d'un jp #05D4
        ; externe (fn_player_materialize_anim_end, #17BC) — donc un vrai point de
        ; reprise nommé, pas seulement une adresse interne de boucle
        ld    l,(ix+off_type)
        ld    bc,tbl_entity_logic_dispatch
        rst    #28
        ld    a,r
        ld    c,a
        ld    a,(var_pseudo_random_acc)
        add    a,c
        ld    (var_pseudo_random_acc),a
        ld    bc,#001C
        add    ix,bc
        push    ix
        pop    hl
        ld    bc,fn_boot_init_and_new_game
        and    a
        sbc    hl,bc
        jr    nc,fn_frame_tick_and_mix
        jr    loc_05B2
fn_frame_tick_and_mix:
        ; Incrémente var_frame_counter (16 bits) et mélange var_pseudo_random_acc
        ; une 2e fois ce tour (la 1re est faite par entité, voir
        ; var_pseudo_random_acc). Formule et vérification numérique détaillées
        ; dans l'entrée var_pseudo_random_acc ci-dessous
        ld    hl,(var_frame_counter)
        inc    hl
        ld    (var_frame_counter),hl
        ld    a,(var_pseudo_random_acc)
        add    a,(hl)
        add    a,l
        add    a,h
        ld    (var_pseudo_random_acc),a
fn_arm_room_transition_flag_and_wait:
        ; Pose inconditionnellement bit0 de var_room_transition_flag (#0078)
        ; chaque frame, puis CALL fn_wait_keyboard_sync (#2D6D), CALL
        ; fn_melkhior_room_spawn_check, fn_cull_entities (#26F7),
        ; fn_render_entities (#2DE2)
        ld    hl,var_room_transition_flag
        set    0,(hl)
        call    fn_wait_keyboard_sync
        call    fn_melkhior_room_spawn_check
        call    fn_cull_entities
        call    fn_render_entities
fn_render_workload_pacing_delay:
        ; Lit var_blit_stack_accumulator (#0084), calcule B=6-(0084); si
        ; (0084)>=6, aucun délai; sinon boucle d'attente active dont la durée
        ; diminue quand la charge de rendu de la frame augmente. Mécanisme de
        ; calage de frame jamais documenté avant
        ld    a,(var_blit_stack_accumulator)
        neg
        add    a,#06
        ld    b,a
        jp    m,fn_render_disabled_one_time_setup
        jr    z,fn_render_disabled_one_time_setup
loc_0625:
        ld    hl,#0500
        dec    hl
        ld    a,l
        or    h
        jr    nz,#0628
        djnz    loc_0625
fn_render_disabled_one_time_setup:
        ; Bloc exécuté UNE SEULE FOIS pendant que var_render_disabled_flag (#007D)
        ; est non-nul (matérialisation en cours): CALL #180B, CALL #2AD6 (table de
        ; calibration décor/HUD, voir fn_init_room), IX=var_day_night_flag(#1CFA),
        ; CALL #1C51, #158D, #154B, #155E (HUD ?), fn_copy_screen_rect,
        ; fn_gate_array_palette_cycle, fn_reset_all_entity_processing_flag (#0668)
        ; — puis remet var_render_disabled_flag=0, ce qui EXPLIQUE précisément son
        ; cycle de vie déjà documenté
        ld    a,(var_render_disabled_flag)
        and    a
        jr    z,#0654
        call    loc_180B
        call    fn_hud_decor_calibration
        ld    ix,var_day_night_flag
        call    loc_1C51
        call    fn_hud_render_minifont_message
        call    fn_hud_render_day_counter
        call    fn_hud_render_secondary_counter
        call    fn_copy_screen_rect
        call    fn_gate_array_palette_cycle
        call    fn_reset_all_entity_processing_flag
        xor    a
        ld    (var_render_disabled_flag),a
fn_frame_end_player_alive_check:
        ; Exécutée CHAQUE FRAME en fin de fn_main_loop: teste
        ; (0x00D7+0x00)\|(0x00D7+0x1C) (type du joueur OR son type_mirror_plus_10)
        ; — si les deux sont nuls (filet de sécurité, jamais vu déclenché en usage
        ; normal): JP #05A2 (fn_init_room_entities, reset complet); sinon JP #05A8
        ; (queue partagée de fn_boot_init_and_new_game/fn_restart_from_menu,
        ; retombe normalement dans fn_main_loop pour la frame suivante). C'est le
        ; vrai point de boucle PAR FRAME, distinct de la boucle par entité
        ; (#05B2-#05F5)
        ld    ix,struct_entities_base
        ld    a,(ix+off_type)
        or    (ix+off_type_mirror_plus_10)
        jp    z,#05A2
        jp    loc_05A8
fn_reset_all_entity_processing_flag:
        ; Boucle sur les 40 slots d'entité et efface bit5 ("en cours de
        ; traitement") de chacun. Appelée par fn_render_disabled_one_time_setup
        ; lors de la (re)matérialisation
        ld    b,#28
        ld    de,#001C
        ld    hl,#00DE
loc_0670:
        res    5,(hl)
        add    hl,de
        djnz    loc_0670
        ret
tbl_entity_logic_dispatch:
        ; Table de pointeurs word, dispatch logique par type d'entité. EXTENT
        ; CONFIRMÉE: exactement 188 entrées (#0676-#07ED), types #00-#BB — vérifié
        ; en décodant chaque mot comme pointeur et en confirmant qu'il tombe dans
        ; #0000-#3FFF (zone code) jusqu'à l'entrée 187 incluse (type 0xBB, celui
        ; produit par fn_collision_effect, pointe vers #17F4); l'entrée 188
        ; (#07EE) sort de la plage code car ce n'est pas une entrée de table mais
        ; le début de la routine suivante (voir ci-dessous) — AUDIT COMPLET
        ; 2026-08-14 : sur les 51 cibles distinctes referencees par les 188
        ; entrees, les 3 dernieres jamais desassemblees/nommees (#1DB2 types
        ; 0x58/0x59/0x5A, #1D7F type 0x80, #17F4 types 0xB9/0xBB) sont maintenant
        ; resolues -- voir fn_static_calib_vector_table et
        ; fn_pickup_catalog_ptr_clear_and_idle. tbl_entity_logic_dispatch est donc
        ; 188/188 traite (aucune entree restant a l'etat brut/non-desassemble ;
        ; quelques types restent 'hypothesis' sur l'identification VISUELLE seule,
        ; pas sur la logique).
        defw #0895
        defw #0895
        defw #1FFC
        defw #1FE2
        defw #1FFC
        defw #1FE2
        defw #1D8F
        defw #1D8F
        defw #1F35
        defw #1FA6
        defw #1D94
        defw #1D99
        defw #1D9E
        defw #1D9E
        defw #1D9E
        defw #1D9E
        defw #20CB
        defw #20CB
        defw #20CB
        defw #20CB
        defw #20CB
        defw #20CB
        defw #108C
        defw #10CE
        defw #20CB
        defw #20CB
        defw #20CB
        defw #20CB
        defw #20CB
        defw #20CB
        defw #1280
        defw #1280
        defw #2689
        defw #2689
        defw #2689
        defw #2689
        defw #2689
        defw #2689
        defw #2689
        defw #2689
        defw #2689
        defw #2689
        defw #2689
        defw #2689
        defw #2689
        defw #2689
        defw #2689
        defw #2689
        defw #20D0
        defw #20D0
        defw #20D0
        defw #20D0
        defw #20D0
        defw #20D0
        defw #0F98
        defw #0F93
        defw #20D0
        defw #20D0
        defw #20D0
        defw #20D0
        defw #20D0
        defw #20D0
        defw #1D53
        defw #1092
        defw #268E
        defw #268E
        defw #268E
        defw #268E
        defw #268E
        defw #268E
        defw #268E
        defw #268E
        defw #268E
        defw #268E
        defw #268E
        defw #268E
        defw #268E
        defw #268E
        defw #268E
        defw #268E
        defw #1EA1
        defw #1EA1
        defw #1EA1
        defw #1EA1
        defw #1D71
        defw #1D66
        defw #10D4
        defw #10D4
        defw #1DB2
        defw #1DB2
        defw #1DB2
        defw #0F67
        defw #1BE1
        defw #1BE1
        defw #1BE1
        defw #1BE1
        defw #1B2B
        defw #1B2B
        defw #1B2B
        defw #1B2B
        defw #1B2B
        defw #1B2B
        defw #1B2B
        defw #1A4A
        defw #1A93
        defw #1A93
        defw #1A93
        defw #1A93
        defw #1A93
        defw #1A93
        defw #1A93
        defw #1239
        defw #17DC
        defw #17DC
        defw #17DC
        defw #17DC
        defw #17DC
        defw #17DC
        defw #17DC
        defw #17FC
        defw #17A7
        defw #17A7
        defw #17A7
        defw #17A7
        defw #17A7
        defw #17A7
        defw #17A7
        defw #17BC
        defw #1D7F
        defw #0895
        defw #0895
        defw #0E4A
        defw #0E4A
        defw #0E4A
        defw #0895
        defw #0895
        defw #0895
        defw #0895
        defw #0895
        defw #0895
        defw #0895
        defw #1277
        defw #127A
        defw #0F84
        defw #0FD8
        defw #0FD8
        defw #0FD8
        defw #0FD8
        defw #0FD8
        defw #0FD8
        defw #1027
        defw #1027
        defw #0FD8
        defw #0FD8
        defw #0FD8
        defw #0FD8
        defw #0FD8
        defw #0FD8
        defw #1280
        defw #1280
        defw #11B9
        defw #11B9
        defw #11B9
        defw #11B9
        defw #1209
        defw #1209
        defw #1209
        defw #1209
        defw #1200
        defw #1200
        defw #1200
        defw #1200
        defw #1200
        defw #1200
        defw #1200
        defw #1200
        defw #1122
        defw #1122
        defw #1148
        defw #1148
        defw #10F4
        defw #10F4
        defw #0EE5
        defw #0EE5
        defw #17D6
        defw #17F4
        defw #0895
        defw #17F4
fn_gate_array_palette_cycle:
        ; Routine immédiatement adjacente à la fin de tbl_entity_logic_dispatch
        ; (trouvée en en vérifiant l'extent). Lit var_sparkle_and_jingle_phase
        ; (#0073, compteur 0-7, ex-var_room_data_field — renommé, voir plus bas),
        ; le double et va chercher un pointeur dans tbl_palette_stream_ptrs
        ; (#07FD), puis JP (pas CALL) dans fn_gate_array_config_stream (#0049)
        ; avec HL = flux choisi. Appelée depuis fn_pickup_sequence_jingle (#1B43,
        ; qui incrémente #0073 mod 8 puis appelle #07EE 24 fois dans sa boucle) ET
        ; depuis la séquence boot/restart
        ; (fn_boot_init_and_new_game/fn_restart_from_menu, vers #0649) pour
        ; réinitialiser la palette.
        ld    a,(var_sparkle_and_jingle_phase)
        ld    hl,tbl_palette_stream_ptrs
        add    a,a
        rst    #08
        ld    a,(hl)
        inc    hl
        ld    h,(hl)
        ld    l,a
        jp    fn_gate_array_config_stream
tbl_palette_stream_ptrs:
        ; 8 pointeurs word (mais 4 flux distincts seulement, chacun répété 2×)
        ; vers des flux de configuration Gate Array consommés par
        ; fn_gate_array_config_stream via fn_gate_array_palette_cycle: #0814,
        ; #081B, #0822, #080D (puis répétition). Chaque flux est une séquence de 3
        ; paires (registre-ink, couleur) terminée par 0xFF, ex. #080D: 01 4E 02 4A
        ; 03 4B FF. Occupe #07FD-#080C; les flux eux-mêmes (#080D-#0828) suivent
        ; immédiatement.
        defw #0814
        defw #081B
        defw #0822
        defw #080D
        defw #0814
        defw #081B
        defw #0822
        defw #080D
tbl_palette_stream_phase3:
        ; Flux GA phase 3 de tbl_palette_stream_ptrs (#07FD, entrees 3 et 7) --
        ; meme format, deja cite comme exemple dans la description de
        ; fn_gate_array_palette_cycle (#07EE): ink1=#4E,ink2=#4A,ink3=#4B.
        defb #01,#4E,#02,#4A,#03,#4B,#FF
tbl_palette_stream_phase0:
        ; Flux GA phase 0 de tbl_palette_stream_ptrs (#07FD, entrees 0 et 4, index
        ; pair depuis var_sparkle_and_jingle_phase double) -- 3 paires (registre-
        ; ink,couleur) terminees #FF, consommees par fn_gate_array_config_stream
        ; (#0049) via fn_gate_array_palette_cycle (#07EE):
        ; ink1=#52,ink2=#53,ink3=#4D.
        defb #01,#52,#02,#53,#03,#4D,#FF
tbl_palette_stream_phase1:
        ; Flux GA phase 1 de tbl_palette_stream_ptrs (#07FD, entrees 1 et 5) --
        ; meme format (voir tbl_palette_stream_phase0 #0814):
        ; ink1=#55,ink2=#53,ink3=#4A.
        defb #01,#55,#02,#53,#03,#4A,#FF
tbl_palette_stream_phase2:
        ; Flux GA phase 2 de tbl_palette_stream_ptrs (#07FD, entrees 2 et 6) --
        ; meme format: ink1=#4C,ink2=#4A,ink3=#4B.
        defb #01,#4C,#02,#4A,#03,#4B,#FF
fn_build_pixel_bitscatter_tables:
        ; Appelée depuis fn_boot_init_and_new_game/fn_restart_from_menu (#057F) —
        ; PAS le menu (ancienne hypothèse fausse, jamais vérifiée par
        ; désassemblage direct jusqu'ici). Désassemblage direct (tools/disasm.py
        ; 0829 - 0900): construit, au boot, un jeu de tables de conversion "bit-
        ; scatter" (256 octets chacune) à #8200/#8300 (motif tournant
        ; #11/#22/#44/#88, AND/OR/XOR accumulés sur l'index), puis (#0854) une 3e
        ; table à #8100 à partir de #8300 (motif vérifié en dump live:
        ; 00,11,22,...,FF, nibble dupliqué), puis (#086E) une 4e passe combinant
        ; #8200/#8300 via deux sous-routines de rotation de bits
        ; (fn_pixel_bit_scatter_lo #0896, fn_pixel_bit_scatter_hi #08A9).
        ; Vérification live déterminante: dump/diff répété de #8100-#8FFF (100
        ; échantillons cumulés sur plusieurs runs, ~44s, y compris une transition
        ; de salle) montre un contenu totalement statique — cohérent avec un
        ; calcul fait UNE SEULE FOIS au boot, jamais recalculé en jeu. Rôle
        ; CONFIRMÉ pour 14 des 15 tables: fn_blit_masked utilise #8200-#8FFF comme
        ; paires masque/couleur (une paire pour l'alignement byte, 3 triplets
        ; masque/couleur ×2-octets-écran pour les décalages sub-octet 1/2/3).
        ; Seule #8100 (nibble dupliqué) reste sans usage tracé — piste ouverte
        ; mineure.
        ld    hl,#8200
        ld    bc,fn_cold_boot_entry
        ld    e,#11
        ld    d,#04
        ld    a,l
        and    e
        ld    a,b
        jr    nz,#083A
        or    e
        ld    b,a
        rlc    e
        dec    d
        jr    nz,#0833
        ld    d,#04
        ld    a,l
        and    e
        jr    z,#0846
        xor    e
        or    c
        ld    c,a
        rlc    e
        dec    d
        jr    nz,#0841
        ld    (hl),b
        inc    h
        ld    (hl),a
        dec    h
        inc    l
        jr    nz,#082C
        ld    hl,#8300
        ld    de,STACK_TOP_INIT
        ld    c,#11
        ld    b,(hl)
        ld    a,b
        and    c
        jr    z,#0864
        ld    a,b
        or    c
        ld    b,a
        rlc    c
        jr    nc,#085D
        ld    a,b
        ld    (de),a
        inc    e
        inc    l
        jr    nz,#085C
        ld    hl,#8200
        ld    d,(hl)
        inc    h
        ld    b,(hl)
        inc    h
        ld    c,#00
        ld    e,#FF
        ld    a,#03
        ex    af,af'
        call    fn_pixel_bit_scatter_lo
        call    fn_pixel_bit_scatter_hi
        ld    (hl),d
        inc    h
        ld    (hl),b
        inc    h
        ld    (hl),e
        inc    h
        ld    (hl),c
        inc    h
        ex    af,af'
        dec    a
        jr    nz,#087B
        ld    a,h
        sub    #0E
        ld    h,a
        inc    l
        jr    nz,#0871
fn_sound_state_idle:
        ; Etat 0 de tbl_sound_dispatch: canal inactif, RET immediat (rien a jouer)
        ret
fn_pixel_bit_scatter_lo:
        ; Sous-routine de rotation de bits utilisee par
        ; fn_build_pixel_bitscatter_tables (#0829) pour construire les tables
        ; #8200/#8300 au boot -- deja decrite en prose dans cette entree,
        ; formalisee ici. Purement liee au rendu graphique, sans rapport avec le
        ; moteur son malgre sa position physique entre deux routines son
        ; (fn_sound_arm_channel_2/0 #08BE/#08C3 et fn_sound_engine_tick #08CC)
        ld    a,e
        rrca
        and    #77
        ld    e,a
        ld    a,d
        rlca
        rlca
        rlca
        and    #88
        or    e
        ld    e,a
        ld    a,d
        rrca
        or    #88
        ld    d,a
        ret
fn_pixel_bit_scatter_hi:
        ; Variante haute de fn_pixel_bit_scatter_lo (#0896), meme contexte
        ; (fn_build_pixel_bitscatter_tables #0829)
        srl    c
        ld    a,b
        rlca
        rlca
        rlca
        and    #88
        or    c
        ld    c,a
        ld    a,b
        rrca
        and    #77
        ld    b,a
        ret
fn_sound_arm_channel_1:
        ; 3e point d'entree d'armement de canal (troisieme, apres
        ; fn_sound_arm_channel_2 #08BE et fn_sound_arm_channel_0 #08C3, jamais
        ; repere avant ): DE=#009F (canal 1), LDIR 4 octets depuis HL
        ; (descripteur) vers le slot. Utilise par fn_sound_effect_click_positional
        ; (#09CB, via #09BD) et fn_position_pitch_sound_arm (#0A07) / son variant
        ; #0A22
        ld    de,#009F
        jr    loc_08C6
fn_sound_arm_channel_2:
        ; Copie (LDIR 4 octets) un descripteur de séquence sonore (HL=pointeur,
        ; passé par l'appelant) vers le slot du canal 2 (0x00A3) ou canal 0
        ; (0x009B) — arme un effet sonore. Appelée par fn_player_transform_tick
        ; (0x1BFC) avec HL=0x0A6E (canal 2) à chaque tick de l'animation de
        ; transformation.
        ld    de,#00A3
        jr    loc_08C6
fn_sound_arm_channel_0:
        ; Copie (LDIR 4 octets) un descripteur de séquence sonore (HL=pointeur,
        ; passé par l'appelant) vers le slot du canal 2 (0x00A3) ou canal 0
        ; (0x009B) — arme un effet sonore. Appelée par fn_player_transform_tick
        ; (0x1BFC) avec HL=0x0A6E (canal 2) à chaque tick de l'animation de
        ; transformation.
        ld    de,struct_sound_channel_slot
loc_08C6:
        ld    bc,#0004
        ldir
        ret
fn_sound_engine_tick:
        ; Boucle de tick des 3 canaux du moteur d'effets sonores, appelée PAR
        ; L'INTERRUPTION IM1 (0x0038, 300Hz, PAS la boucle de jeu) — dispatch
        ; chaque canal (struct_sound_channel_slot, 4 octets
        ; [état][compteur][paramA][paramB], base 0x009B/0x009F/0x00A3) via
        ; tbl_sound_dispatch (0x08E8) selon son octet d'état (0-7). 8
        ; gestionnaires d'état intégralement décodés: 0=idle (0x0895), 1=bruit à
        ; volume+hauteur décroissants (fn_sound_effect_noise_decay 0x0992,
        ; matérialisation), 2=glissando linéaire volume max
        ; (fn_sound_effect_sweep_linear 0x09B0, son de rebond confirmé), 3=clic
        ; positionnel (fn_sound_effect_click_positional 0x09CB, réutilise
        ; tbl_sound_chromatic_periods 0x0BA8 partagée avec le lecteur de jingle
        ; 0x0A97), 4=note fixe décroissante (fn_sound_effect_note_fixed_decay
        ; 0x0A33), 5=glissando "brouillé" (fn_sound_effect_sweep_scrambled
        ; 0x0A5E), 6=glissando nibble-swap (fn_sound_effect_sweep_nibble_swap
        ; 0x0A72, son de transformation confirmé), 7=ton fixe exact
        ; (fn_sound_effect_tone_fixed 0x0A4B, utilisé par
        ; fn_pushable_block_logic/fn_position_pitch_sound_arm 0x0A07). Bonus: 3e
        ; point d'armement fn_sound_arm_channel_1 (0x08B9) jamais repéré avant,
        ; formalisation de fn_pixel_bit_scatter_lo/_hi.
        ld    iy,struct_sound_channel_slot
        ld    l,(iy+off_type)
        ld    bc,tbl_sound_dispatch
        rst    #28
        ld    de,#0004
        add    iy,de
        push    iy
        pop    hl
        ld    de,#00A7
        and    a
        sbc    hl,de
        jr    c,#08D0
        ret
tbl_sound_dispatch:
        ; Table de dispatch (word, 8 entrées) indexée par l'octet d'état de chaque
        ; canal son (struct_sound_channel_slot).
        defw #0895
        defw #0992
        defw #09B0
        defw #09CB
        defw #0A33
        defw #0A5E
        defw #0A72
        defw #0A4B
fn_sound_channel_index:
        ; HL=IY-#009B, puis /4 (SRL x2) +1 -> A = numero de canal courant (1,2,3)
        ; depuis le pointeur IY d'un slot struct_sound_channel_slot. Utilise par
        ; de nombreux gestionnaires d'etat pour calculer le registre PSG
        ; (frequence = (canal-1)*2, volume = canal+7)
        push    iy
        pop    hl
        ld    bc,struct_sound_channel_slot
        and    a
        sbc    hl,bc
        ld    a,l
        srl    a
        srl    a
        inc    a
        ret
fn_sound_tick_channel:
        ; Routine de tick partagee par les etats 2-7: bascule un bit du mixer PSG
        ; pour ce canal (fn_sound_toggle_mixer_bit_b #096B), decremente (iy+1)
        ; (compteur de duree). Si non-nul, RET normalement (A=compteur decremente,
        ; consomme par l'appelant -- meme mecanisme (a partir de #090B) utilise
        ; seul par l'etat 1 (fn_sound_effect_noise_decay #0992, sans le bascule-
        ; mixer de tete)). Si le compteur atteint 0: coupe le volume PSG de ce
        ; canal (silence), pose des bits dans var_sound_mixer_mask (#0098) selon
        ; le numero de canal (signalisation de fin d'effet), PUIS ecrase (iy+0)=0
        ; (retour a l'etat idle) et fait un double-RET (INC SP x2) pour sortir
        ; directement JUSQU'A l'appelant de fn_sound_engine_tick (#08CC) -- saute
        ; le reste du gestionnaire d'etat appelant
        call    fn_sound_toggle_mixer_bit_b
loc_090B:
        dec    (iy+off_grid_x)
        ld    a,(iy+off_grid_x)
        ret    nz
        inc    sp
        inc    sp
loc_0914:
        ld    (iy+off_type),#00
        call    fn_sound_channel_index
        push    af
        add    a,#07
        ld    e,a
        ld    d,#00
        call    fn_psg_write_period_low
        ld    e,#00
        call    fn_psg_write_period_full
        pop    af
        ld    hl,var_sound_mixer_mask
        cp    #01
        jr    z,fn_sound_mixer_signal_ch1
        cp    #02
        jr    z,fn_sound_mixer_signal_ch2
        ld    a,#24
loc_0937:
        or    (hl)
        ld    (hl),a
        ret
fn_sound_mixer_signal_ch1:
        ; Queue alternative de fn_sound_tick_channel (#0908), atteinte par 'jr
        ; z,#093A' (#092F) quand le numero de canal (A, calcule par
        ; fn_sound_channel_index #08F8) vaut 1: pose A=#09 (bits mixer tone+bruit
        ; du canal 1, #0100+#1000... Motif #001001) puis rejoint la queue commune
        ; a #0937 (OR (HL) / LD (HL),A / RET) qui accumule ce bit dans
        ; var_sound_mixer_mask (#0098) -- signale la fin d'effet pour ce canal
        ; specifique.
        ld    a,#09
        jr    loc_0937
fn_sound_mixer_signal_ch2:
        ; Queue alternative de fn_sound_tick_channel (#0908), atteinte par 'jr
        ; z,#093E' (#0933) quand le canal vaut 2: pose A=#12 (motif bits mixer du
        ; canal 2) puis rejoint #0937 (meme queue que fn_sound_mixer_signal_ch1
        ; #093A). Le cas canal 3 (ni #01 ni #02) tombe directement dans le code
        ; existant a #0935 (A=#24).
        ld    a,#12
        jr    loc_0937
fn_sound_write_noise_period:
        ; Ecrit A comme periode du generateur de bruit PSG (registre 6, seul et
        ; unique par puce -- PAS par canal). Utilise par
        ; fn_sound_effect_noise_decay (#0992, etat 1)
        push    af
        ld    de,#0006
        call    fn_psg_write_period_low
        pop    af
        ld    e,a
        jp    fn_psg_write_period_full
fn_sound_toggle_mixer_bit_a:
        ; Variante A du bascule-bit mixer (voir fn_sound_toggle_mixer_bit_b #096B,
        ; quasi-identique): calcule le bit du registre mixer PSG (7) correspondant
        ; a ce canal (position derivee du numero de canal, ajustee si canal==3),
        ; l'efface dans var_sound_mixer_mask (#0098) (ET logique -- ACTIVE le
        ; bruit/ton pour ce canal), puis ecrit le masque complet au registre
        ; mixer. Utilise par fn_sound_effect_noise_decay (#0992, etat 1)
        ld    de,#0007
        call    fn_psg_write_period_low
        call    fn_sound_channel_index
        cp    #03
        jr    nz,#095C
        inc    a
        rlca
        rlca
        rlca
        and    #38
loc_0961:
        cpl
        ld    hl,var_sound_mixer_mask
        and    (hl)
        ld    (hl),a
        ld    e,a
        jp    fn_psg_write_period_full
fn_sound_toggle_mixer_bit_b:
        ; Variante B du bascule-bit mixer, memes calculs que
        ; fn_sound_toggle_mixer_bit_a (#094E) mais point d'entree legerement
        ; different (saute le premier calcul redondant) -- rejoint la meme queue
        ; partagee (#0961). Utilise par fn_sound_tick_channel (#0908, donc par les
        ; etats 2-7)
        ld    de,#0007
        call    fn_psg_write_period_low
        call    fn_sound_channel_index
        cp    #03
        jr    nz,#0979
        inc    a
        jr    loc_0961
fn_sound_set_volume_max:
        ; A=#0F (15, volume max) puis tombe dans fn_sound_write_volume (#097D).
        ; Utilise en fin des etats 2 (sweep lineaire), 5 (sweep scramble) et 6
        ; (sweep nibble-swap) -- ces 3 etats jouent donc toujours a volume fixe
        ; max, seule la hauteur varie
        ld    a,#0F
fn_sound_write_volume:
        ; Ecrit A comme volume PSG du canal courant (registre canal+7, calcule via
        ; fn_sound_channel_index #08F8). Utilise par fn_sound_set_volume_max
        ; (#097B, A=15 fixe) et par les etats 1/4 (volume decroissant calcule
        ; depuis le compteur de duree)
        push    af
        call    fn_sound_channel_index
        add    a,#07
        ld    e,a
        ld    d,#00
        call    fn_psg_write_period_low
        pop    af
        ld    e,a
        jp    fn_psg_write_period_full
tbl_sound_descriptor_noise_decay:
        ; Descripteur [etat1,compteur#1F,0,0] du gestionnaire
        ; fn_sound_effect_noise_decay (#0992) -- Arme par
        ; fn_player_materialize_anim (#17D6) et par #1F44.
        defb #01,#1F,#00,#00
fn_sound_effect_noise_decay:
        ; Gestionnaire d'etat 1 de tbl_sound_dispatch: effet de BRUIT a volume ET
        ; hauteur DECROISSANTS (bascule le mixer via fn_sound_toggle_mixer_bit_a
        ; #094E, decremente la duree via fn_sound_decrement_and_check #090B,
        ; volume=compteur/2, periode de bruit=complement(compteur)&#1F via
        ; fn_sound_write_noise_period #0942) -- typique d'un effet d'IMPACT/THUD
        ; qui s'eteint progressivement. Descripteur connu: #098E (etat1,
        ; compteur#1F), arme par fn_player_materialize_anim (#17D6, sequence de
        ; (dis/re)materialisation du joueur) et par une 2e routine non identifiee
        ; (#1F44, test bit2 de (ix+0C))
        call    fn_sound_toggle_mixer_bit_a
        call    loc_090B
        srl    a
        call    fn_sound_write_volume
        ld    a,(iy+off_grid_x)
        cpl
        and    #1F
        jp    fn_sound_write_noise_period
fn_sound_trigger_bounce:
        ; Arme le canal 0 (fn_sound_arm_channel_0 #08C3) avec le descripteur #09AC
        ; (etat2, compteur#1F) -- LE son de rebond generique. Appele par
        ; fn_bouncing_ball_logic et par fn_ball_chase_flee_logic (#0EE5, via #0F30
        ; -- meme famille 'bulle volcanique') et fn_will_o_wisp_logic (#10F4, via
        ; #111A -- deja documentee comme rebondissant selon le meme schema que la
        ; balle)
        ld    hl,tbl_sound_descriptor_bounce
        jp    fn_sound_arm_channel_0
tbl_sound_descriptor_bounce:
        ; Descripteur [etat2,compteur#1F,0,0] de fn_sound_effect_sweep_linear
        ; (#09B0) -- LE son de rebond generique, arme par fn_sound_trigger_bounce
        ; (#09A6).
        defb #02,#1F,#00,#00
fn_sound_effect_sweep_linear:
        ; Gestionnaire d'etat 2: effet de GLISSANDO lineaire a volume fixe max
        ; (fn_sound_set_volume_max #097B) -- periode PSG = #0100 + compteur*2
        ; (decroit lineairement avec la duree, via fn_sound_write_period_hl
        ; #0A7B), donne un "boing" descendant classique. Descripteur #09AC, armee
        ; par fn_sound_trigger_bounce (#09A6) -- LE son de rebond de balle/entite
        call    fn_sound_tick_channel
        rlca
        ld    l,a
        ld    h,#01
        call    fn_sound_write_period_hl
        jp    fn_sound_set_volume_max
fn_sound_trigger_click_and_advance:
        ; Sous-etape de fn_sound_effect_click_positional : avance l'index de
        ; lecture dans tbl_sound_chromatic_periods et arme le canal suivant.
        ld    hl,var_sound_click_pitch_index
        inc    (hl)
        ld    hl,tbl_sound_descriptor_click
        jp    fn_sound_arm_channel_2
tbl_sound_descriptor_click:
        ; Descripteur [etat3,compteur#17,0,0] de fn_sound_effect_click_positional
        ; (#09CB) -- arme par fn_sound_trigger_click_and_advance (#09BD).
        defb #03,#17,#00,#00
fn_sound_effect_click_positional:
        ; Gestionnaire d'etat 3: CLIC dont le VOLUME depend de la position du
        ; joueur en cache (var #00D8/#00D9, combinaison rotative -> volume 8-15)
        ; et dont la HAUTEUR est choisie dans tbl_sound_click_pitch_palette
        ; (#09FF, 8 entrees) indexee par var_sound_click_pitch_index (#009A) mod
        ; 8, elle-meme un INDEX vers tbl_sound_chromatic_periods (#0BA8) --
        ; Descripteur #09C7, armee par fn_sound_trigger_click_and_advance (#09BD)
        call    fn_sound_tick_channel
        ld    a,(#00D8)
        srl    a
        ld    c,a
        ld    a,(#00D9)
        neg
        srl    a
        add    a,c
        rrca
        rrca
        rrca
        rrca
        rrca
        and    #07
        add    a,#08
        call    fn_sound_write_volume
        ld    a,(var_sound_click_pitch_index)
        and    #07
        ld    hl,tbl_sound_click_pitch_palette
        rst    #08
        ld    a,(hl)
        sla    a
        ld    hl,tbl_sound_opcode_dispatch
        rst    #08
        ld    a,(hl)
        inc    hl
        ld    h,(hl)
        ld    l,a
        jp    fn_sound_write_period_hl
tbl_sound_click_pitch_palette:
        ; 8 index (octet) dans tbl_sound_chromatic_periods (#0BA8, meme table que
        ; le lecteur de jingle bloquant #0A97): #25,#27,#28,#2A,#28,#27,#25,#23 --
        ; un petit motif de vibrato (monte puis redescend de qq demi-tons) utilise
        ; par fn_sound_effect_click_positional (#09CB), selectionne via
        ; var_sound_click_pitch_index (#009A) mod 8
        defb #25,#27,#28,#2A,#28,#27,#25,#23
fn_position_pitch_sound_arm:
        ; Calcule complément(grid_x+grid_y+grid_z) de l'entité et l'écrit comme
        ; octet bas de la période PSG dans le descripteur #0A47 (état 7 =
        ; fn_sound_effect_tone_fixed 0x0A4B, compteur court #07), puis arme le
        ; canal 1 (fn_sound_arm_channel_1 0x0A07→0x08B9) — un BLIP répété de
        ; hauteur dérivée de la position (confirme le "son de déplacement à
        ; hauteur variable" déjà supposé). Mêmes adresses #0A49/#0A4A réutilisées
        ; par fn_bonus_life_pickup_logic/0x0A14 (autre appelant, écrit le même
        ; descripteur avec un paramètre différent). Utilisé par
        ; fn_pushable_block_logic, ET par fn_will_o_wisp_logic (0x10F4/0x1108) et
        ; fn_moving_block_logic (0x0F98/0x0FA6).
        ld    a,(ix+off_grid_x)
        add    a,(ix+off_grid_y)
        add    a,(ix+off_grid_z_or_offset)
        cpl
        ld    l,a
        ld    h,#00
loc_0A14:
        ld    a,l
        ld    (#0A4A),a
        ld    a,h
        ld    (#0A49),a
        ld    hl,tbl_sound_descriptor_tone_fixed
        jp    fn_sound_arm_channel_1
fn_sound_arm_position_pitch_ch1:
        ; Variante de fn_position_pitch_sound_arm (#0A07) utilisant SEULEMENT
        ; complement((ix+03)) (pas la somme des 3 axes) comme parametre de
        ; hauteur, ecrit dans le descripteur #0A2F (etat 4,
        ; fn_sound_effect_note_fixed_decay #0A33, compteur#1F -- note a volume
        ; DECROISSANT, pas un blip repete comme #0A07), arme le canal 1.
        ; Appelants: fn_sinking_cube_logic (#0F67, via #0F7E -- clic de descente
        ; du cube-piege) et fn_ceiling_spike_ball_logic (#1092, via #10BD -- clic
        ; de contact des pics)
        ld    a,(ix+off_grid_z_or_offset)
        cpl
        ld    (#0A32),a
        ld    hl,tbl_sound_descriptor_note_fixed_decay
        jp    fn_sound_arm_channel_1
tbl_sound_descriptor_note_fixed_decay:
        ; Descripteur [etat4,compteur#1F,0,param] de
        ; fn_sound_effect_note_fixed_decay (#0A33) -- param (octet+3) ecrit
        ; dynamiquement par fn_sound_arm_position_pitch_ch1 (#0A22, a #0A32) avant
        ; chaque armement; #7F est la valeur figee au moment du dump RAM (reliquat
        ; du dernier armement), pas une constante.
        defb #04,#1F,#00,#7F
fn_sound_effect_note_fixed_decay:
        ; Gestionnaire d'etat 4: NOTE a hauteur FIXE (lue directement depuis
        ; (iy+03) du descripteur, ecrite via fn_sound_write_period_hl #0A7B) et
        ; VOLUME DECROISSANT (rotation-droite(compteur)&#0F, via
        ; fn_sound_write_volume #097D) -- une note "pincee" classique qui
        ; s'eteint. Descripteur #0A2F, armee par fn_sound_arm_position_pitch_ch1
        ; (#0A22)
        call    fn_sound_tick_channel
        ld    l,(iy+off_grid_z_or_offset)
        ld    h,#00
        call    fn_sound_write_period_hl
        ld    a,(iy+off_grid_x)
        rrca
        and    #0F
        jp    fn_sound_write_volume
tbl_sound_descriptor_tone_fixed:
        ; Descripteur [etat7,compteur#07,paramA,paramB] de
        ; fn_sound_effect_tone_fixed (#0A4B) -- paramA/paramB (octets+2/+3) ecrits
        ; dynamiquement par fn_position_pitch_sound_arm (#0A07, a #0A49/#0A4A)
        ; avant chaque armement; #00/#40 sont les valeurs figees au moment du dump
        ; RAM (reliquat du dernier armement).
        defb #07,#07,#00,#40
fn_sound_effect_tone_fixed:
        ; Gestionnaire d'etat 7: TON a periode 16 bits FIXE lue directement depuis
        ; (iy+02)/(iy+03) du descripteur (via fn_sound_write_period_hl #0A7B) et
        ; volume fixe max (fn_sound_set_volume_max #097B) -- le commande de ton la
        ; plus "directe" (frequence exacte specifiee par l'appelant, pas de
        ; calcul). Descripteur #0A47, armee par fn_position_pitch_sound_arm
        ; (#0A07)
        call    fn_sound_tick_channel
        ld    l,(iy+off_grid_z_or_offset)
        ld    h,(iy+off_grid_y)
        call    fn_sound_write_period_hl
        jp    fn_sound_set_volume_max
tbl_sound_descriptor_sweep_scrambled:
        ; Descripteur [etat5,compteur#1F,0,0] de fn_sound_effect_sweep_scrambled
        ; (#0A5E) --
        defb #05,#1F,#00,#00
fn_sound_effect_sweep_scrambled:
        ; Gestionnaire d'etat 5: glissando a volume fixe max
        ; (fn_sound_set_volume_max #097B), periode = ROL2(compteur) XOR #A0 --
        ; variante "brouillee" du sweep de fn_sound_effect_sweep_linear (#09B0),
        ; effet plus dissonant/glitch. Descripteur #0A5A (compteur #1F) arme
        ; directement par fn_sound_arm_channel_1 (#08B9) depuis une routine de
        ; reaction de collision generique non identifiee precisement (#220C, entre
        ; fn_player_read_input #2147 et fn_get_orientation_code #22D0 -- voir
        ; #09BD ci-dessous pour le meme voisinage)
        call    fn_sound_tick_channel
        rlca
        rlca
        xor    #A0
loc_0A65:
        ld    l,a
        ld    h,#00
        call    fn_sound_write_period_hl
        jp    fn_sound_set_volume_max
tbl_sound_descriptor_sweep_nibble_swap:
        ; Descripteur [etat6,compteur#1F,0,0] de fn_sound_effect_sweep_nibble_swap
        ; (#0A72) --
        defb #06,#1F,#00,#00
fn_sound_effect_sweep_nibble_swap:
        ; Gestionnaire d'etat 6: periode = ROL4(compteur) (= echange des nibbles),
        ; PUIS tombe directement dans le corps de fn_sound_effect_sweep_scrambled
        ; (#0A5E, a partir du XOR #A0) -- partage entierement sa queue (ecriture
        ; periode + volume max). Descripteur #0A6E, armee par
        ; fn_player_transform_tick (#1BFC) --
        call    fn_sound_tick_channel
        rlca
        rlca
        rlca
        rlca
        jr    loc_0A65
fn_sound_write_period_hl:
        ; Ecrit HL comme periode PSG 16 bits (fine+coarse) du canal courant
        ; (registres (canal-1)*2 / +1, canal calcule via fn_sound_channel_index
        ; #08F8). Utilisee par tous les gestionnaires d'etat qui jouent un ton
        ; (2,3,4,5,6,7)
        push    hl
        call    fn_sound_channel_index
        dec    a
        sla    a
        ld    e,a
        ld    d,#00
        call    fn_psg_write_period_low
        pop    hl
        push    de
        ld    e,l
        call    fn_psg_write_period_full
        pop    de
        inc    e
        call    fn_psg_write_period_low
        ld    e,h
        jp    fn_psg_write_period_full
fn_sound_program_play_blocking:
        ; Lecteur de programme sonore PSG 3 canaux, BLOQUANT (busy-wait,
        ; contrairement a fn_sound_engine_tick qui est tickee par IM1). Appelee
        ; pour jouer le jingle de fin de partie. Init : DI,
        ; fn_psg_register_init_stream (HL=#0C36), charge 3 canaux dans des slots
        ; de 7 octets a #1877 (+0/+1=pointeur programme, +2/+3=compteur de duree,
        ; +4=mode de volume courant, +5/+6=copie du pointeur de depart pour LOOP).
        ; Boucle round-robin sur les 3 canaux : decompte +2/+3, et a 0 appelle
        ; fn_sound_program_step.
        ld    a,#01
        jr    loc_0A9C
fn_sound_program_channel_setup:
        ; Charge un canal du lecteur de jingle bloquant (slot de 7 octets a #1877
        ; + offset canal) depuis un pointeur programme fourni par l'appelant.
        xor    a
loc_0A9C:
        ld    (#0099),a
        call    fn_disarm_interrupt_flag
        push    hl
        ld    hl,tbl_psg_init_stream_default
        call    fn_psg_register_init_stream
        pop    hl
        ld    iy,#1877
        ld    de,#0007
        ld    b,#03
loc_0AB3:
        ld    a,(hl)
        inc    hl
        ld    (iy+off_type),a
        ld    (iy+off_bbox_h),a
        ld    a,(hl)
        inc    hl
        ld    (iy+off_grid_x),a
        ld    (iy+off_bbox_d),a
        xor    a
        ld    (iy+off_grid_y),a
        ld    (iy+off_grid_z_or_offset),a
        add    iy,de
        djnz    loc_0AB3
loc_0ACE:
        ld    iy,#1877
        ld    a,#03
        ex    af,af'
        ld    l,(iy+off_grid_y)
        ld    h,(iy+off_grid_z_or_offset)
        ld    a,l
        or    h
        jr    z,fn_sound_program_step
        dec    hl
        ld    (iy+off_grid_y),l
        ld    (iy+off_grid_z_or_offset),h
loc_0AE6:
        ld    de,#0007
        add    iy,de
        ex    af,af'
        dec    a
        jp    nz,#0AD4
        jp    loc_0ACE
fn_sound_program_step:
        ; Appelee quand le compteur de duree d'un canal atteint 0. Sonde clavier
        ; (fn_read_keyboard_row_raw) + joystick (fn_read_joystick_table) pour
        ; permettre d'ecourter le jingle, lit l'octet suivant du programme du
        ; canal, dispatch commande (RST 28 via tbl_sound_opcode_dispatch) ou note
        ; (fn_sound_note_apply).
        ld    a,(#0099)
        and    a
        jr    z,#0B05
        call    fn_read_keyboard_row_raw
        ld    hl,tbl_wait_any_key_all_rows
        call    fn_read_joystick_table
        jp    nz,#0C20
        ld    l,(iy+off_type)
        ld    h,(iy+off_grid_x)
        ld    a,(hl)
        inc    hl
        ld    (iy+off_type),l
        ld    (iy+off_grid_x),h
        push    af
        cp    #08
        jr    nc,fn_sound_note_apply
        ld    l,a
        ld    bc,tbl_sound_opcode_dispatch
        jp    rst_dispatch_table
fn_sound_note_apply:
        ; Décode un octet de programme >=8 comme une NOTE (bits7-6=durée,
        ; bits5-0=hauteur, voir 0x0A97), écrit la période PSG correspondante,
        ; applique le mode de volume courant (tbl_sound_volume_mode_dispatch
        ; 0x0B5D). Octets #38-#3F (et alias) invalides — sortiraient de
        ; tbl_sound_chromatic_periods, jamais utilisés en pratique
        rlca
        rlca
        rlca
        and    #06
        ld    hl,tbl_sound_note_durations
        rst    #08
        ld    a,(hl)
        inc    hl
        ld    (iy+off_grid_y),a
        ld    a,(hl)
        ld    (iy+off_grid_z_or_offset),a
        pop    af
        rlca
        and    #7E
        ld    hl,tbl_sound_opcode_dispatch
        rst    #08
        ld    d,#00
        ex    af,af'
        ld    e,a
        ex    af,af'
        dec    e
        sla    e
        push    de
        call    fn_psg_write_period_low
        ld    e,(hl)
        inc    hl
        call    fn_psg_write_period_full
        pop    de
        inc    e
        call    fn_psg_write_period_low
        ld    e,(hl)
        call    fn_psg_write_period_full
        ld    l,(iy+off_bbox_w)
        ld    bc,tbl_sound_volume_mode_dispatch
        rst    #28
        jp    loc_0AE6
tbl_sound_volume_mode_dispatch:
        ; 4 entrées (word), indexées par +4 du canal: fn_sound_volume_mute
        ; (0x0B65, volume 0), fn_sound_volume_mid (0x0B77, volume 7),
        ; fn_sound_volume_max (0x0B7C, volume #0F), fn_sound_volume_envelope
        ; (0x0B81, mode enveloppe matérielle + reset forme d'enveloppe). Seules 4
        ; entrées existent — un +4=4 ou 5 (accepté sans erreur par
        ; tbl_sound_opcode_dispatch) ferait sauter hors table vers #0011 (adresse
        ; invalide), jamais déclenché par les données réelles
        defw #0B65
        defw #0B77
        defw #0B7C
        defw #0B81
fn_sound_volume_mute:
        ; Mode de volume 0: ecrit 0 (silence) dans le registre volume PSG du canal
        ; courant (8/9/10 pour canal A/B/C, calcule depuis le compteur de canal
        ; via af'). Pose par la commande de programme sonore #00 -- artefact du
        ; generateur: le 'LD DE,fn_cold_boot_entry' affiche dans l'asm genere est
        ; une COINCIDENCE NUMERIQUE (l'immediat charge est bien la valeur 0, pas
        ; un appel au boot -- gen_asm.py substitue tout operande #0000 par le nom
        ; du symbole a cette adresse, sans distinguer adresse de donnee immediate)
        ld    de,fn_cold_boot_entry
loc_0B68:
        push    de
        ex    af,af'
        ld    e,a
        ex    af,af'
        ld    a,e
        add    a,#07
        ld    e,a
        call    fn_psg_write_period_low
        pop    de
        jp    fn_psg_write_period_full
fn_sound_volume_mid:
        ; Mode de volume 1: ecrit 7 (volume moyen fixe) dans le registre volume
        ; PSG du canal courant. Pose par la commande de programme sonore #01
        ld    de,#0007
        jr    loc_0B68
fn_sound_volume_max:
        ; Mode de volume 2: ecrit #0F (15, volume max fixe) dans le registre
        ; volume PSG du canal courant. Pose par la commande de programme sonore
        ; #02
        ld    de,#000F
        jr    loc_0B68
fn_sound_volume_envelope:
        ; Mode de volume 3: ecrit #10 (bit4=1, mode enveloppe materielle PSG) dans
        ; le registre volume du canal courant, PUIS reinitialise le registre de
        ; forme d'enveloppe (13) a 0 via fn_psg_register_init_stream (#0D67,
        ; donnees #0B8D: #0D,#00,#FF). Pose par la commande de programme sonore
        ; #03 -- typique d'un son perussif/pluck (enveloppe materielle plutot que
        ; volume fixe) -- artefact du generateur: le 'LD
        ; DE,rst_apply_movement_vector' affiche est une COINCIDENCE NUMERIQUE
        ; (l'immediat charge est bien la valeur #0010=16, pas un appel a RST 10 --
        ; meme limitation de substitution que #0B65)
        ld    de,rst_apply_movement_vector
        call    loc_0B68
        ld    hl,tbl_psg_envelope_shape_reset
        jp    fn_psg_register_init_stream
tbl_psg_envelope_shape_reset:
        ; Flux fn_psg_register_init_stream (#0D67) de 1 registre: reg13(forme
        ; d'enveloppe)=0, terminateur #FF. Utilise par fn_sound_volume_envelope
        ; (#0B81, mode de volume 3).
        defb #0D,#00,#FF
tbl_sound_note_durations:
        ; 4 durées de note (word LE), indexées par les bits 7-6 d'un octet de note
        ; (AND #06 après rotation) dans fn_sound_note_apply (0x0B1F): #0400,
        ; #0800, #0C00, #1000 — progression linéaire (×1,×2,×3,×4 d'une unité de
        ; base)
        defw #0400
        defw #0800
        defw #0C00
        defw #1000
tbl_sound_opcode_dispatch:
        ; Octet de programme sonore <8 = commande (via fn_sound_program_step) :
        ; #00-#05 -> fn_sound_cmd_store_param (stocke la valeur brute 0-5 dans
        ; (iy+4) comme mode de volume courant, seuls 0-3 sont surs, voir
        ; tbl_sound_volume_mode_dispatch) ; #06 -> fn_sound_cmd_loop ; #07 ->
        ; fn_sound_cmd_end.
        defw #0C18
        defw #0C18
        defw #0C18
        defw #0C18
        defw #0C18
        defw #0C18
        defw #0C26
        defw #0C1F
tbl_sound_chromatic_periods:
        ; 56 périodes PSG (word LE), gamme chromatique D2→A6 (voir 0x0A97 pour la
        ; validation par calcul de fréquence). Indexée par octet_programme AND
        ; #3F. Extent (56, pas 64) confirmée: les 8 index suivants tomberaient
        ; dans le code des gestionnaires de commande
        defw #0353
        defw #0324
        defw #02F6
        defw #02CC
        defw #02A4
        defw #027E
        defw #025A
        defw #0238
        defw #0218
        defw #01FA
        defw #01DE
        defw #01C3
        defw #01AA
        defw #0192
        defw #017B
        defw #0166
        defw #0152
        defw #013F
        defw #012D
        defw #011C
        defw #010C
        defw #00FD
        defw #00EF
        defw #00E1
        defw #00D5
        defw #00C9
        defw #00BE
        defw #00B3
        defw #00A9
        defw #009F
        defw #0096
        defw #008E
        defw #0086
        defw #007F
        defw #0077
        defw #0071
        defw #006A
        defw #0064
        defw #005F
        defw #0059
        defw #0054
        defw #0050
        defw #004B
        defw #0047
        defw #0043
        defw #003F
        defw #003C
        defw #0038
        defw #0035
        defw #0032
        defw #002F
        defw #002D
        defw #002A
        defw #0028
        defw #0026
        defw #0024
fn_sound_cmd_store_param:
        ; Commande de programme sonore #00-#05: stocke la valeur brute de l'octet
        ; (0-5) dans (iy+4) du canal courant -- mode de volume/instrument qui sera
        ; applique par la PROCHAINE note (voir tbl_sound_volume_mode_dispatch
        ; #0B5D). Revient a fn_sound_program_step (#0AF3, verif abandon + octet
        ; suivant)
        pop    af
        ld    (iy+off_bbox_w),a
        jp    fn_sound_program_step
fn_sound_cmd_end:
        ; Commande de programme sonore #07: FIN du programme sonore. Coupe le
        ; mixer PSG (registre 7 = #3F, tons+bruit desactives sur les 3 canaux) et
        ; remet les 3 volumes a 0 via fn_psg_register_init_stream (#0D67, donnees
        ; #0D5E). Comme cette routine finit par RET, cela deroule la pile jusqu'a
        ; l'appelant ORIGINAL de fn_sound_program_play_blocking (#0A97) -- END
        ; termine tout le jingle des qu'UN SEUL canal l'atteint, pas seulement ce
        ; canal
        pop    af
        ld    hl,tbl_psg_reset_stream
        jp    fn_psg_register_init_stream
fn_sound_cmd_loop:
        ; Commande de programme sonore #06: LOOP -- recopie le pointeur de depart
        ; sauvegarde (iy+5)/(iy+6) dans le pointeur de programme courant
        ; (iy+0)/(iy+1), fait donc rejouer le canal depuis le debut indefiniment.
        ; Revient a fn_sound_program_step (#0AF3)
        pop    af
        ld    a,(iy+off_bbox_h)
        ld    (iy+off_type),a
        ld    a,(iy+off_bbox_d)
        ld    (iy+off_grid_x),a
        jp    fn_sound_program_step
tbl_psg_init_stream_default:
        ; Flux fn_psg_register_init_stream (#0D67) fixe, HL=#0C36 code en dur dans
        ; fn_sound_program_play_blocking (#0A97): reg8/9/10(volumes A/B/C)=0
        ; (silence), reg7(mixer)=#38 (tons ON / bruit OFF sur les 3 canaux),
        ; reg11/12(periode d'enveloppe fine/coarse)=0/#08, terminateur #FF. Decode
        ; octet-par-octet, verifie coherent de bout en bout (17 segments contigus,
        ; aucun octet residuel).
        defb #08,#00,#09,#00,#0A,#00,#07,#38,#0B,#00,#0C,#08,#FF
tbl_sound_program_ptrs_unused_a:
        ; [hypothesis] Reliquat inutilise ou appelant non encore identifie.
        ; Ch2/ch3 pointent vers des programmes reels et coherents
        ; (tbl_sound_program_unused_a_ch2/_ch3), donc pas des octets aleatoires.
        defw #0D5B
        defw #0D01
        defw #0CF5
tbl_sound_program_ptrs_gameover:
        ; Triplet de pointeurs canal (word LE) [ch1=#0D5B,ch2=#0D2D,ch3=#0D0B] --
        ; jingle de l'ECRAN DE GAME OVER, parametre HL de l'appel
        ; fn_sound_program_play_blocking (#0A97) depuis
        ; fn_game_over_or_daycycle_end (#1374,
        ; asm/code/entity_logic_mechanical.asm).
        defw #0D5B
        defw #0D2D
        defw #0D0B
tbl_sound_program_ptrs_unused_b:
        ; [hypothesis] Triplet de pointeurs canal (word LE)
        ; [ch1=#0D5B,ch2=#0D51,ch3=#0D37], meme format que
        ; tbl_sound_program_ptrs_gameover (#0C49) -- AUCUN appelant trouve par
        ; recherche statique dans les fichiers.asm actuellement generes. Ch2/ch3
        ; pointent vers des programmes reels et coherents
        ; (tbl_sound_program_unused_b_ch2/_ch3) -- candidat pour identification
        ; empirique (jingle non repere par recherche de HL=#0C4F dans le code).
        defw #0D5B
        defw #0D51
        defw #0D37
tbl_sound_program_ptrs_control_menu:
        ; Triplet de pointeurs canal (word LE) [ch1=#0D5B,ch2=#0CC5,ch3=#0C61] --
        ; jingle de l'ECRAN DE SELECTION DU MODE DE CONTROLE, parametre HL de
        ; l'appel fn_sound_program_play_blocking (#0A97) depuis
        ; fn_control_mode_menu (#15E5, asm/code/entity_logic_mechanical.asm).
        ; Fn_sound_program_play_blocking (#0A97) citait ce site comme 'day-cycle-
        ; end' par proximite de code avec fn_game_over_or_daycycle_end --
        ; verification directe de l'appelant (#15E5) montre qu'il s'agit en
        ; realite de fn_control_mode_menu (ecran affiche au demarrage/redemarrage
        ; pour choisir JOYSTICK vs DIRECTIONAL CONTROL), sans rapport avec le
        ; cycle jour/nuit.
        defw #0D5B
        defw #0CC5
        defw #0C61
tbl_sound_program_ptrs_unused_c:
        ; [hypothesis] Triplet de pointeurs canal (word LE)
        ; [ch1=#0D5B,ch2=#0D5B,ch3=#0CEF] (ch1 ET ch2 identiques -- les 2 seraient
        ; silencieux/en boucle) -- AUCUN appelant trouve par recherche statique.
        ; Ch3 pointe vers un court programme reel (tbl_sound_program_unused_c_ch3,
        ; arpege chromatique D6-D#6-E6-F6 en mode enveloppe).
        defw #0D5B
        defw #0D5B
        defw #0CEF
tbl_sound_program_control_menu_ch3:
        ; Programme sonore du canal 3 du jingle ecran de selection de mode
        ; (tbl_sound_program_ptrs_control_menu #0C55): cmd2(volume max) puis 99
        ; notes courtes (duree0) formant une melodie rapide repetee 2x (motif
        ; F4/F5/G#5/C6 puis C4/D#5/D5/C5 x2, puis C#4/C6 x4, D#4/C6 x4, F4/C6 x6),
        ; cmd7(FIN). 100 octets, #0C61-#0CC4.
        defb #02,#1B,#27,#1B,#27,#1B,#2A,#2E,#1B,#27,#1B,#27,#1B,#2A,#1B,#2E
        defb #16,#25,#16,#24,#16,#22,#16,#22,#16,#25,#16,#24,#16,#22,#16,#22
        defb #16,#22,#1B,#27,#1B,#27,#1B,#2A,#2E,#1B,#27,#1B,#27,#1B,#2A,#1B
        defb #2E,#16,#25,#16,#24,#16,#22,#16,#22,#16,#25,#16,#24,#16,#22,#16
        defb #22,#16,#22,#17,#2E,#17,#2E,#17,#2E,#17,#2E,#19,#2E,#19,#2E,#19
        defb #2E,#19,#2E,#1B,#2E,#1B,#2E,#1B,#2E,#1B,#2E,#1B,#2E,#1B,#2E,#1B
        defb #2E,#1B,#2E,#07
tbl_sound_program_control_menu_ch2:
        ; Programme sonore du canal 2 du jingle ecran de selection de mode
        ; (tbl_sound_program_ptrs_control_menu #0C55): cmd2(volume max) puis motif
        ; F3-G#3 repete avec ornements D#3-F3-G3 et notes tenues, cmd7(FIN). 42
        ; octets, #0CC5-#0CEE.
        defb #02,#CF,#D2,#CF,#D2,#0D,#0F,#11,#4D,#8A,#0D,#0F,#11,#4D,#8A,#0A
        defb #CF,#D2,#CF,#D2,#0D,#0F,#11,#4D,#8A,#0D,#0F,#11,#4D,#8A,#0A,#CF
        defb #CF,#4F,#52,#51,#4D,#CF,#CF,#CF,#CF,#07
tbl_sound_program_unused_c_ch3:
        ; [hypothesis] Programme sonore du canal 3 pointe par
        ; tbl_sound_program_ptrs_unused_c (#0C5B, aucun appelant trouve):
        ; cmd3(mode enveloppe) puis arpege chromatique montant D6-D#6-E6-F6
        ; (durees courtes), cmd7(FIN). 6 octets, #0CEF-#0CF4.
        defb #03,#30,#31,#32,#33,#07
tbl_sound_program_unused_a_ch3:
        ; [hypothesis] Programme sonore du canal 3 pointe par
        ; tbl_sound_program_ptrs_unused_a (#0C43, aucun appelant trouve):
        ; cmd2(volume max) puis notes D6-F6-E6-A5-D6-C6-A5-C6-D6-D6(longue),
        ; cmd7(FIN). 12 octets, #0CF5-#0D00.
        defb #02,#70,#73,#72,#6B,#30,#2E,#2B,#2E,#30,#B0,#07
tbl_sound_program_unused_a_ch2:
        ; [hypothesis] Programme sonore du canal 2 pointe par
        ; tbl_sound_program_ptrs_unused_a (#0C43, aucun appelant trouve):
        ; cmd2(volume max) puis notes D5-D5-E5-E5-F5-G5-D5-D5, cmd7(FIN). 10
        ; octets, #0D01-#0D0A.
        defb #02,#64,#64,#66,#66,#67,#69,#64,#64,#07
tbl_sound_program_gameover_ch3:
        ; Programme sonore du canal 3 (arpege decoratif) du jingle game over
        ; (tbl_sound_program_ptrs_gameover #0C49): cmd3(mode enveloppe) puis 33
        ; notes courtes (duree0) en boucle de motifs de 4 (C6-C#4-F5-C#4, puis
        ; variantes montant en hauteur), cmd7(FIN). 34 octets, #0D0B-#0D2C.
        defb #03,#2E,#17,#27,#17,#2E,#17,#27,#17,#2C,#19,#27,#19,#2C,#19,#27
        defb #19,#2A,#1B,#27,#1B,#2A,#1B,#27,#1B,#2A,#1B,#27,#1B,#2A,#1B,#27
        defb #1B,#07
tbl_sound_program_gameover_ch2:
        ; Programme sonore du canal 2 (melodie principale) du jingle game over
        ; (tbl_sound_program_ptrs_gameover #0C49): cmd2(volume max) puis
        ; C#3-C#3-D#3-D#3-F3-F3-F3-F3 (notes longues, duree3), cmd7(FIN). 10
        ; octets, #0D2D-#0D36.
        defb #02,#CB,#CB,#CD,#CD,#CF,#CF,#CF,#CF,#07
tbl_sound_program_unused_b_ch3:
        ; [hypothesis] Programme sonore du canal 3 pointe par
        ; tbl_sound_program_ptrs_unused_b (#0C4F, aucun appelant trouve): 26 notes
        ; courtes (duree0) sans commande de volume initiale (mode herite du canal
        ; precedent), motif ascendant/descendant F5-G5-G#5..., derniere note
        ; duree2. #0D37-#0D50.
        defb #27,#29,#2A,#27,#29,#2A,#2C,#29,#2A,#2C,#2E,#2A,#29,#2A,#2C,#29
        defb #27,#29,#2A,#27,#26,#27,#29,#26,#A7,#07
tbl_sound_program_unused_b_ch2:
        ; [hypothesis] Programme sonore du canal 2 pointe par
        ; tbl_sound_program_ptrs_unused_b (#0C4F, aucun appelant trouve): 9 notes
        ; duree2 (F4-C4-D#4-A#3-F4-C4-G#3-G#3-G#3, sans commande de volume
        ; initiale), cmd7(FIN). 10 octets, #0D51-#0D5A.
        defb #9B,#96,#99,#94,#9B,#96,#92,#92,#92,#07
tbl_sound_program_ch1_silent:
        ; Programme du canal 1, PARTAGE par les 5 triplets de pointeurs de ce bloc
        ; (tbl_sound_program_ptrs_gameover/_control_menu/_unused_a/_b/_c):
        ; cmd0(volume=0, silence) puis 1 note D2 duree3 (jouee a volume nul, donc
        ; inaudible), cmd6(LOOP). 3 octets, #0D5B-#0D5D --
        defb #00,#C0,#06
tbl_psg_reset_stream:
        ; Flux fn_psg_register_init_stream (#0D67) utilise par fn_sound_cmd_end
        ; (#0C1F, commande #07/FIN): reg7(mixer)=#3F (tons+bruit OFF sur les 3
        ; canaux), reg8/9/10(volumes)=0, terminateur #FF. 9 octets, #0D5E-#0D66
        ; (le #FF final est le dernier octet du sous-bloc de donnees #0C36-#0D66,
        ; immediatement suivi par fn_psg_register_init_stream #0D67 en code).
        defb #07,#3F,#08,#00,#09,#00,#0A,#00,#FF
fn_psg_register_init_stream:
        ; Flux d'initialisation de registres PSG: lit (HL)=registre,
        ; (HL+1)=période, écrit via fn_psg_write_period_low/full (0x0D8C/0x0DA7),
        ; avance HL de 2, jusqu'à l'octet terminal #FF. Même motif générique que
        ; fn_gate_array_config_stream (0x0049) mais pour le PSG. Appelé par
        ; fn_sound_program_play_blocking (0x0A97) avec HL=#0C36
        ld    d,#00
loc_0D69:
        ld    a,(hl)
        inc    hl
        cp    #FF
        ret    z
        ld    e,a
        call    fn_psg_write_period_low
        ld    e,(hl)
        inc    hl
        call    fn_psg_write_period_full
        jr    loc_0D69
fn_arm_interrupt_flag:
        ; EI + (0x006F)=1 puis RET — signal "synchro prête" consommé par
        ; fn_check_interrupt_flag (0x0D84). Appelée depuis
        ; fn_boot_init_and_new_game/fn_restart_from_menu (0x054B) ET depuis
        ; fn_main_loop (0x05B5, tout début de chaque frame) — donc réarmée
        ; systématiquement une fois par frame, pas juste au boot. Voir
        ; 0x0D80/0x0D84
        ei
        ld    a,#01
loc_0D7C:
        ld    (var_interrupt_sync_flag),a
        ret
fn_disarm_interrupt_flag:
        ; Point d'entree alternatif partageant la queue de fn_arm_interrupt_flag
        ; (memes 2 derniers octets) : DI puis XOR A (au lieu de EI/LD A,1) avant
        ; de rejoindre var_interrupt_sync_flag=A ; RET -- donc
        ; var_interrupt_sync_flag=0 avec interruptions coupees, l'inverse exact de
        ; fn_arm_interrupt_flag. Seul appelant : fn_sound_program_play_blocking.
        di
        xor    a
        jr    loc_0D7C
fn_check_interrupt_flag:
        ; DI, teste (0x006F): si zéro, RET directement (laisse les interruptions
        ; coupées); si non-nul, EI puis RET. Utilisé en fin de
        ; fn_read_keyboard_line (0x0ED3, via 0x0ED8) — encadre le scan clavier
        ; dans une section critique DI, ne réautorisant les interruptions qu'après
        ; coup ET seulement si le flag de synchro était posé. Voir 0x0D79
        di
        ld    a,(var_interrupt_sync_flag)
        and    a
        ret    z
        ei
        ret
fn_psg_write_period_low:
        ; (était hypothesis "PSG/CRTC" vague): sélectionnent le registre PSG
        ; "période canal" via port 0xF700 (select) + 0xF400 (data) + 0xF600 (latch
        ; haut), écrivent la fréquence (DE) — cœur du moteur d'effets sonores
        ; (fn_sound_engine_tick 0x08CC / tbl_sound_dispatch 0x08E8). Les mêmes
        ; ports sont réutilisés par le scan clavier (multiplexage classique CPC).
        ld    bc,PORT_PSG_SELECT
        ld    a,#82
        out    (c),a
        ld    bc,PORT_PSG_DATA
        out    (c),e
        ld    bc,PORT_PSG_LATCH
        ld    a,d
        and    #3F
        or    #C0
loc_0DA0:
        out    (c),a
        and    #3F
        out    (c),a
        ret
fn_psg_write_period_full:
        ; (était hypothesis "PSG/CRTC" vague): sélectionnent le registre PSG
        ; "période canal" via port 0xF700 (select) + 0xF400 (data) + 0xF600 (latch
        ; haut), écrivent la fréquence (DE) — cœur du moteur d'effets sonores
        ; (fn_sound_engine_tick 0x08CC / tbl_sound_dispatch 0x08E8). Les mêmes
        ; ports sont réutilisés par le scan clavier (multiplexage classique CPC).
        ld    bc,PORT_PSG_SELECT
        ld    a,#82
        out    (c),a
        ld    bc,PORT_PSG_DATA
        out    (c),e
        ld    bc,PORT_PSG_LATCH
        ld    a,d
        and    #3F
        or    #80
        jr    loc_0DA0
fn_psg_select_and_read:
        ; CALL 0x0D8C (arme la période bas + haut&0xC0 du registre 14/I-O port A
        ; via E/D), PUIS reconfigure le registre 14 en MODE LECTURE
        ; ((D&0x3F)\|0x40 écrit au port 0xF600, bit6 = sens lecture du port PSG
        ; I/O A) et lit la valeur en retour via IN A,(0xF400) — remet ensuite le
        ; registre en mode écriture (D&0x3F sans le bit6) avant de RET avec le
        ; résultat en A. Confirme le mécanisme matériel exact du scan clavier CPC:
        ; le clavier n'est PAS lu par un port dédié mais MULTIPLEXÉ sur le port
        ; I/O du PSG (sélection de ligne = écriture du n° de ligne au port PSG en
        ; mode écriture, lecture de la ligne = même registre repassé en mode
        ; lecture) — cohérent avec fn_read_keyboard_line (0x0ED3, voir 0x0EDD) qui
        ; l'utilise ainsi.
        call    fn_psg_write_period_low
        ld    bc,PORT_PSG_SELECT
        ld    a,#92
        out    (c),a
        ld    bc,PORT_PSG_LATCH
        ld    a,d
        and    #3F
        or    #40
        out    (c),a
        ld    bc,PORT_PSG_DATA
        in    a,(c)
        push    af
        ld    bc,PORT_PSG_LATCH
        ld    a,d
        and    #3F
        out    (c),a
        pop    af
        ret
fn_probe_solid_support:
        ; Reutilise les 3 primitives AABB de fn_check_collisions
        ; (#254F/#2564/#2579), boucle sur les 40 slots (filtre actif + pas soi-
        ; meme), retourne CARRY si trouve. Utilisee par fn_player_use_held_object
        ; (grid_z temporairement +0x0C) pour valider si un boost de hauteur
        ; atterrirait sur un support solide.
        push    bc
        push    de
        push    hl
        push    iy
        ld    iy,struct_entities_base
        ld    b,#28
        ld    c,#00
        ld    l,c
        ld    h,c
        set    1,(ix+off_flags)
loc_0DF4:
        call    fn_probe_entity_is_active_other
        jr    z,fn_probe_solid_support_next
        call    fn_aabb_axis_gap_x
        jr    nc,fn_probe_solid_support_next
        call    fn_aabb_axis_gap_y
        jr    nc,fn_probe_solid_support_next
        call    fn_aabb_axis_gap_z
        jr    nc,fn_probe_solid_support_next
loc_0E08:
        pop    iy
        pop    hl
        pop    de
        pop    bc
        res    1,(ix+off_flags)
        ret
fn_probe_solid_support_next:
        ; Queue de boucle de fn_probe_solid_support (#0DE1): avance IY de 28
        ; octets, DJNZ vers #0DF4 pour l'entite suivante; boucle epuisee -> AND A
        ; (carry clear) puis rejoint la queue de sortie #0E08.
        ld    de,#001C
        add    iy,de
        djnz    loc_0DF4
        and    a
        jr    loc_0E08
fn_probe_entity_is_active_other:
        ; Helper de fn_probe_solid_support (#0DE1) -- retourne Z (a ignorer) si
        ; (iy+00)==0 (slot inactif) OU si bit1 de (iy+07) est CLEAR-avant-
        ; complement (teste en fait si CE slot est celui qui vient d'avoir son
        ; bit1 pose, i.e. L'entite appelante elle-meme) -- filtre 'actif et pas
        ; moi'.
        ld    a,(iy+off_type)
        and    a
        ret    z
        ld    a,(iy+off_flags)
        cpl
        and    #02
        ret
fn_shuffle_pickup_sequence_order:
        ; Appelée une fois au lancement d'une partie (#0596, dans
        ; fn_boot_init_and_new_game), fait tourner circulairement les 14 octets de
        ; tbl_pickup_sequence_order d'un nombre pseudo-aléatoire de positions
        ; (4-7) — l'ordre du puzzle de collecte est donc mélangé chaque partie
        ld    a,(var_newgame_random_seed)
        and    #03
        or    #04
        ld    c,a
        ld    b,#0D
        ld    iy,tbl_pickup_sequence_order
        ld    e,(iy+off_type)
loc_0E39:
        ld    a,(iy+off_grid_x)
        ld    (iy+off_type),a
        inc    iy
        djnz    loc_0E39
        ld    (iy+off_type),e
        dec    c
        jr    nz,#0E30
        ret
fn_hostile_patrol_logic:
        ; Logique des types d'entité 0x83-0x85 (0x82 utilise une logique
        ; différente, 0x0895, probable état "au repos"). Si grid_z_or_offset <
        ; 0xA4: mouvement de patrouille (vecteur dérivé de position propre, RST
        ; 10) + variante pseudo-aléatoire du type. Teste TOUJOURS la mort du
        ; joueur via fn_player_proximity_death (0x0EA0). PAS liée aux statues de
        ; crapaud (0x16), qui sont confirmées immobiles — le vrai élément visuel
        ; correspondant à 0x83-0x85 reste à identifier en jeu.
        call    loc_1D84
        ld    a,(ix+off_grid_z_or_offset)
        cp    #A4
        jr    nc,fn_player_proximity_death
        ld    (ix+#0B),#03
        ld    a,(ix+off_grid_x)
        rlca
        and    #01
        ld    l,a
        ld    a,(ix+off_grid_y)
        and    #80
        or    l
        rlca
        and    #03
        ld    l,a
        ld    bc,tbl_hostile_patrol_diag_dispatch
        jp    rst_dispatch_table
tbl_hostile_patrol_diag_dispatch:
        ; Table de dispatch (word, 4 entrees) indexee par un code 2 bits (parite
        ; de grid_x combinee au signe/bit7 de grid_y) dans fn_hostile_patrol_logic
        ; (#0E4A, via rst_dispatch_table #0028) -- choisit un des 4 vecteurs de
        ; deplacement en diagonale (fn_hostile_patrol_diag0..3,
        ; #0E77/#0E91/#0E96/#0E9B).
        defw #0E77
        defw #0E91
        defw #0E96
        defw #0E9B
fn_hostile_patrol_diag0:
        ; Variante diagonale 0 de la logique de patrouille ennemie -- meme famille
        ; que fn_hostile_patrol_logic, direction fixee.
        ld    hl,#04FC
loc_0E7A:
        ld    (ix+#09),l
        ld    (ix+#0A),h
        ld    a,(var_pseudo_random_acc)
        and    #03
        jr    nz,#0E88
        inc    a
        add    a,#82
        ld    (ix+off_type),a
loc_0E8D:
        rst    #10
        jp    loc_1F7B
fn_hostile_patrol_diag1:
        ; Diagonale 1: HL=#0404 puis JR vers la queue commune de
        ; fn_hostile_patrol_diag0 (#0E7A, stockage vecteur + suite).
        ld    hl,#0404
        jr    loc_0E7A
fn_hostile_patrol_diag2:
        ; Diagonale 2: HL=#FCFC puis JR vers la queue commune de
        ; fn_hostile_patrol_diag0 (#0E7A).
        ld    hl,#FCFC
        jr    loc_0E7A
fn_hostile_patrol_diag3:
        ; Diagonale 3: HL=#FC04 puis JR vers la queue commune de
        ; fn_hostile_patrol_diag0 (#0E7A) -- boucle complete des 4 diagonales
        ; (#04FC/#0404/#FCFC/#FC04, cf. Les 4 orientations cardinales de
        ; fn_guard_patrol_vector_o0..o3 #12A9-#12F9 mais ici en diagonale).
        ld    hl,#FC04
        jr    loc_0E7A
fn_player_proximity_death:
        ; Test de proximité 2D joueur/entité (PAS le AABB 3D générique de
        ; fn_check_collisions): si |player_x-ix+01|<6 ET |player_y-ix+02|<6
        ; (utilise (0x00D8)/(0x00D9), position joueur potentiellement mise en
        ; cache), saut direct vers 0x12FB (fn_game_over_or_daycycle_end, retour
        ; COMPLET au menu). Une mort réelle observée en direct (perte de vie avec
        ; vies restantes) n'a PAS emprunté ce chemin (0x12FB jamais atteint, salle
        ; restée inchangée) — le vrai mécanisme de "mort douce" est
        ; fn_player_door_transition (voir ci-dessous). Le rôle exact de
        ; fn_player_proximity_death reste à élucider (peut-être réservé à la toute
        ; dernière vie, ou à un contact avec un type d'ennemi spécifique non
        ; encore rencontré).
        ld    a,(#00D8)
        sub    (ix+off_grid_x)
        jp    p,#0EAB
        neg
        cp    #06
        jr    nc,#0EBF
        ld    a,(#00D9)
        sub    (ix+off_grid_y)
        jp    p,#0EBA
        neg
        cp    #06
        jp    c,fn_game_over_or_daycycle_end
        set    7,(ix+off_state_flags_2)
        set    1,(ix+off_flags)
        ld    (ix+#0B),#01
        ld    bc,#0404
        call    fn_vector_toward_player
        jr    loc_0E8D
fn_read_keyboard_line:
        ; Lit une ligne de la matrice clavier CPC (A=n° de ligne), retour dans A
        di
        call    fn_read_keyboard_row_raw
        push    af
        call    fn_check_interrupt_flag
        pop    af
        ret
fn_read_keyboard_row_raw:
        ; Petit helper appelé par fn_read_keyboard_line (0x0ED3→0x0ED4): D=A
        ; (numéro de ligne demandé), E=0x0E (registre PSG 14 = port I/O A), CALL
        ; 0x0DBD (fn_psg_select_and_read), puis CPL (complémente le résultat — la
        ; matrice clavier CPC est active-bas, donc ce complément rend les bits "1
        ; = touche pressée") et RET. Second appelant: 0x0AF9, DANS
        ; fn_sound_program_play_blocking (0x0A97) — utilisé là pour sonder une
        ; touche et permettre d'écourter le jingle de game-over, PAS un second
        ; chemin de scan clavier générique (voir 0x0A97/0x0D80)
        ld    d,a
        ld    e,#0E
        call    fn_psg_select_and_read
        cpl
        ret
fn_ball_chase_flee_logic:
        ; (salle 0x08, type 0xB6) — voir la table des constantes ci-dessous pour
        ; le détail complet (patch d'opcode JR NC/JR C selon la forme jour/nuit du
        ; joueur). Formalisée en symbole/asm: joue fn_sound_trigger_bounce
        ; (0x09A6) sur collision.
        call    loc_1D9E
        ld    l,(ix+#09)
        ld    h,(ix+#0A)
        push    hl
        ld    a,(ix+#0B)
        ld    (#0088),a
        rst    #10
        pop    hl
        ld    (ix+#09),l
        ld    (ix+#0A),h
        ld    a,(struct_entities_base)
        sub    #10
        cp    #20
        ld    a,#30
        jr    nc,#0F0A
        add    a,#08
        ld    (#0F41),a
        ld    (#0F5A),a
        ld    a,(var_player_room_number)
        and    #01
        ld    a,#04
        jr    z,#0F20
        ld    b,a
        ld    a,(var_pseudo_random_acc)
        and    #03
        add    a,b
        bit    2,(ix+off_cooldown_or_collision_flags)
        jr    z,loc_0F4C
        ld    (ix+#0B),a
        ld    a,(#0088)
        and    a
        jp    p,#0F33
        call    fn_sound_trigger_bounce
        ld    a,r
        and    #01
        jr    z,fn_ball_chase_flee_alt_vector
        ld    a,(#00D9)
        cp    (ix+off_grid_y)
        ld    a,#02
        jr    nc,#0F45
        neg
        ld    (ix+#0A),a
        ld    (ix+#09),#00
loc_0F4C:
        call    fn_animation_cycle_4
        jp    loc_1139
fn_ball_chase_flee_alt_vector:
        ; Branche alternative de calcul de vecteur de fn_ball_chase_flee_logic
        ; (#0EE5), deja annoncee en prose dans sa description ('queue partagee
        ; avec une branche alternative de calcul de vecteur #0F52-#0F66'). Compare
        ; (#00D8) (position joueur) a (ix+01) (grid_x entite) pour choisir +2/-2
        ; en (ix+09), pose (ix+0A)=0, puis JR vers #0F4C (fn_animation_cycle_4 +
        ; JP #1139) -- rejoint la queue normale de la routine.
        ld    a,(#00D8)
        cp    (ix+off_grid_x)
        ld    a,#02
        jr    nc,#0F5E
        neg
        ld    (ix+#09),a
        ld    (ix+#0A),#00
        jr    loc_0F4C
fn_sinking_cube_logic:
        ; Formalisée en symbole/asm. Flag bit3 de (ix+0D) déclenché une fois puis
        ; consommé (RES), applique le vecteur (RST 10), arme
        ; fn_sound_arm_position_pitch_ch1 (0x0A22, hauteur dérivée de grid_z) sur
        ; collision. Mécanisme exact de la descente (grid_z) toujours pas trouvé
        ; dans cette routine — piste ouverte.
        call    loc_1D8F
        bit    3,(ix+off_state_flags_2)
        ret    z
        res    3,(ix+off_state_flags_2)
        ld    (ix+#0B),#00
        rst    #10
        bit    2,(ix+off_cooldown_or_collision_flags)
        jr    nz,#0F81
        call    fn_sound_arm_position_pitch_ch1
        jp    loc_1F7B
fn_dormant_block_transform:
        ; Formalisée en symbole/asm. Si le flag bit3 de (ix+0D) est posé: force le
        ; type à 0xB8 et saute dans fn_player_materialize_anim (0x17D6) —
        ; réutilise la séquence d'animation par étapes du joueur
        call    loc_1D8F
        bit    3,(ix+off_state_flags_2)
        ret    z
        ld    (ix+off_type),#B8
        jp    loc_17D6
fn_moving_block_logic_type37:
        ; Formalisées en symbole/asm. Même corps partagé (paramètre HL différent:
        ; #020A pour 0x37 via 0x0F93→JR, #0109 pour 0x36 via 0x0F98 direct —
        ; corrige une transcription antérieure #0A02 pour 0x37, probablement des
        ; octets inversés). Arme fn_position_pitch_sound_arm (0x0A07) — son de
        ; déplacement à hauteur dépendant de la position, calcule un vecteur
        ; cyclique via var_frame_counter
        ld    hl,#020A
        jr    loc_0F9B
fn_moving_block_logic:
        ; Formalisées en symbole/asm. Même corps partagé (paramètre HL différent:
        ; #020A pour 0x37 via 0x0F93→JR, #0109 pour 0x36 via 0x0F98 direct —
        ; corrige une transcription antérieure #0A02 pour 0x37, probablement des
        ; octets inversés). Arme fn_position_pitch_sound_arm (0x0A07) — son de
        ; déplacement à hauteur dépendant de la position, calcule un vecteur
        ; cyclique via var_frame_counter
        ld    hl,#0109
loc_0F9B:
        ld    a,h
        ld    (#0FBF),a
        ld    a,l
        ld    (#0FD0),a
        call    loc_1D8F
        call    fn_position_pitch_sound_arm
        push    ix
        pop    bc
        ld    a,c
        rrca
        and    #10
        ld    c,a
        ld    a,(var_frame_counter)
        add    a,c
        bit    4,a
        jr    z,#0FBA
        cpl
        and    #0F
        ld    c,a
        ld    a,(ix+off_grid_x)
        add    a,#08
        and    #0F
        cp    c
        jp    z,loc_1F7B
        ld    a,#01
        jr    c,#0FCE
        neg
        ld    (ix+#09),a
        ld    (ix+#0B),#01
        jp    loc_0E8D
fn_guard_legs_logic:
        ; (était "fn_guard_weapon_logic", hypothèse d'arme infirmée — le gardien
        ; observé n'a ni arme ni compagnon). Logique partagée par les types
        ; 0x90-0x9D (~10 valeurs, tous dispatchés ici) — position de grille suit
        ; celle du gardien (0x1E/0x1F) avec un léger décalage temporel. Très
        ; probablement la SECONDE MOITIÉ du sprite visuel du gardien (jambes,
        ; animées séparément du torse pour l'animation de marche) plutôt qu'une
        ; entité distincte.
        call    loc_1D89
        ld    a,(ix+#09)
        or    (ix+#0A)
        ret    z
        ld    a,(var_frame_counter)
        rrca
        rrca
        and    #47
        add    a,#40
        ld    l,a
        ld    h,#01
        call    loc_0A14
        ld    a,(ix+#09)
        cp    (ix+#0A)
        jr    c,fn_guard_legs_branch_carry
        bit    7,a
        jr    nz,fn_guard_legs_branch_reset_type
        set    3,(ix+off_type)
loc_1001:
        res    6,(ix+off_flags)
loc_1005:
        call    loc_2231
        jp    loc_1F7B
fn_guard_legs_branch_reset_type:
        ; Cible de "jr nz,#100B" (#0FFB) dans fn_guard_legs_logic: RES
        ; 3,(ix+off_type) puis JR #1001 -- rejoint la queue commune (res bit6
        ; flags, call #2231, jp #1F7B). Branche "bit7 de a pose" (jambe dans
        ; l'autre sens).
        res    3,(ix+off_type)
        jr    loc_1001
fn_guard_legs_branch_carry:
        ; Cible de "jr c,#1011" (#0FF7) dans fn_guard_legs_logic: teste BIT
        ; 7,(ix+0A), branche vers fn_guard_legs_branch_carry_reset (#1021) si Z,
        ; sinon SET 3,(ix+off_type) / SET 6,(ix+off_flags) puis JR #1005 (queue
        ; commune call #2231/jp #1F7B).
        bit    7,(ix+#0A)
        jr    z,fn_guard_legs_branch_carry_reset
        set    3,(ix+off_type)
loc_101B:
        set    6,(ix+off_flags)
        jr    loc_1005
fn_guard_legs_branch_carry_reset:
        ; Cible de "jr z,#1021" depuis fn_guard_legs_branch_carry (#1015): RES
        ; 3,(ix+off_type) puis JR #101B (rejoint SET 6,(ix+off_flags)/JR #1005 de
        ; fn_guard_legs_branch_carry).
        res    3,(ix+off_type)
        jr    loc_101B
fn_guard_legs_logic_alt:
        ; Second point d'entree complet dans la logique jambes (types 0x90-0x9D),
        ; jamais atteint par le flux interne de fn_guard_legs_logic -- tres
        ; probablement une entree de dispatch dediee a une jambe/sous-type
        ; different (gauche/droite ?) partageant le meme corps. CALL #1DB7
        ; (calibration), teste bit0,(ix+off_state_flags_2) pour choisir le signe
        ; (NEG ou non) du vecteur ecrit dans (ix+09)/(ix+25) (mirroir), CALL
        ; fn_guard_walk_animation_toggle (#1055), RST 10 (application vecteur),
        ; teste bit0,(ix+off_cooldown_or_collision_flags) pour basculer bit0 de
        ; state_flags_2 (toggle direction), puis copie grid_x->pending_grid_x et
        ; JP #1139 (queue partagee, meme cible que fn_guard_patrol_logic #12A2).
        call    loc_1DB7
        bit    0,(ix+off_state_flags_2)
        ld    a,#02
        jr    nz,#1034
        neg
        ld    (ix+#09),a
        ld    (ix+#25),a
        call    fn_guard_walk_animation_toggle
        rst    #10
        bit    0,(ix+off_cooldown_or_collision_flags)
        jr    z,#104C
        ld    a,(ix+off_state_flags_2)
        xor    #01
        ld    (ix+off_state_flags_2),a
        ld    a,(ix+off_grid_x)
        ld    (ix+off_pending_grid_x),a
        jp    loc_1139
fn_guard_walk_animation_toggle:
        ; Pose le bit 0 du type (0x1E<->0x1F) ET le bit 6 des flags selon l'axe
        ; DOMINANT du vecteur de déplacement (ix+09)/(ix+0A) puis son signe.
        ; CORRIGÉ 2026-09-04 : ce n'est PAS un "battement de marche 2 phases"
        ; comme le disait ce commentaire -- les deux bits sont dérivés du signe
        ; du vecteur, donc c'est un CODE D'ORIENTATION, la même grandeur que
        ; (flags.bit6 << 1) | type.bit3 chez le joueur (fn_get_orientation_code
        ; #22D0), au bit près : le corps du garde loge son sélecteur de dessin
        ; en type.bit0 et non type.bit3. Les "4 combinaisons visuelles" sont
        ; les 4 orientations, pas 2 phases x 2 miroirs. Même structure que
        ; fn_guard_legs_logic (#0FD8) ci-dessus. La phase de marche, elle, vit
        ; dans les 3 bits bas du type et est avancée par le recycleur #2231.
        ld    a,(ix+#09)
        or    (ix+#0A)
        ret    z
        ld    a,(ix+#09)
        cp    (ix+#0A)
        jr    c,fn_guard_walk_animation_toggle_branch_a
        bit    7,a
        jr    nz,fn_guard_walk_animation_toggle_branch_b
        set    0,(ix+off_type)
loc_106C:
        res    6,(ix+off_flags)
        ret
fn_guard_walk_animation_toggle_branch_b:
        ; Cible de "jr nz,#1071" (#1066): RES 0,(ix+off_type) puis JR #106C --
        ; rejoint la queue commune (res bit6 flags, ret).
        res    0,(ix+off_type)
        jr    loc_106C
fn_guard_walk_animation_toggle_branch_a:
        ; Cible de "jr c,#1077" (#1062): teste BIT 7,(ix+0A), branche vers
        ; fn_guard_walk_animation_toggle_branch_a_reset (#1086) si Z, sinon SET
        ; 0,(ix+off_type) / SET 6,(ix+off_flags) / RET.
        bit    7,(ix+#0A)
        jr    z,fn_guard_walk_animation_toggle_branch_a_reset
        set    0,(ix+off_type)
loc_1081:
        set    6,(ix+off_flags)
        ret
fn_guard_walk_animation_toggle_branch_a_reset:
        ; Cible de "jr z,#1086" depuis fn_guard_walk_animation_toggle_branch_a
        ; (#107B): RES 0,(ix+off_type) puis JR #1081 (rejoint SET
        ; 6,(ix+off_flags)/RET).
        res    0,(ix+off_type)
        jr    loc_1081
fn_toad_statue_logic:
        ; Logique du type d'entité 0x16 (statue de crapaud) — calibration de
        ; projection seule, purement décoratif/statique. Superposé (même grid_x/y,
        ; field3 différent) aux blocs en bois (0x06) qu'il surmonte.
        call    fn_entity_apply_decor_state_flags
        jp    loc_1DA8
fn_ceiling_spike_ball_logic:
        ; Logique du type d'entité 0x3F (boules à pics au plafond) — teste
        ; var_pseudo_random_acc (0x006D) < 0x10 pour se déclencher (piège pseudo-
        ; aléatoire, ~6%/tick), verrouille var_room_reset_flag_4 (0x0085) pour
        ; garantir une seule boule active à la fois par salle, applique la chute
        ; via RST 10. 12 occurrences dans la table d'entités correspondant
        ; exactement aux "boules à pics au plafond" (11 comptées visuellement + 1
        ; masquée, comme soupçonné). Bonus: sur collision (bit2 de (ix+0C)) après
        ; la chute, arme fn_sound_arm_position_pitch_ch1 (0x0A22, via 0x10BD) —
        ; clic d'impact dont la hauteur dépend de grid_z
        call    fn_entity_apply_decor_state_flags
        call    loc_1D8F
        ld    a,(var_room_reset_flag_5)
        and    a
        ret    nz
        bit    2,(ix+off_state_flags_2)
        jr    nz,fn_ceiling_spike_ball_logic_tail
        ld    hl,var_room_reset_flag_4
        ld    a,(hl)
        and    a
        ret    nz
        ld    a,(var_pseudo_random_acc)
        cp    #10
        ret    nc
        set    2,(ix+off_state_flags_2)
        ld    (hl),#01
        ret
fn_ceiling_spike_ball_logic_tail:
        rst    #10
        bit    2,(ix+off_cooldown_or_collision_flags)
        jr    nz,fn_ceiling_spike_ball_logic_tail_reset
        call    fn_sound_arm_position_pitch_ch1
loc_10C0:
        jp    loc_1F7B
fn_ceiling_spike_ball_logic_tail_reset:
        ; Cible de "jr nz,#10C3" depuis fn_ceiling_spike_ball_logic_tail (#10BB):
        ; RES 2,(ix+off_state_flags_2), remet var_room_reset_flag_4 (#0085) a 0,
        ; puis JR vers le JP #1F7B de fn_ceiling_spike_ball_logic_tail.
        res    2,(ix+off_state_flags_2)
        ld    hl,var_room_reset_flag_4
        ld    (hl),#00
        jr    loc_10C0
fn_spike_logic:
        ; Logique du type d'entité 0x17 (piques au sol) — oscillation périodique
        ; (throttle 2 frames) avec variation pseudo-aléatoire (XOR avec
        ; var_pseudo_random_acc bit 6), cycle d'animation 4 phases via
        ; fn_animation_cycle_4 (0x1260).
        call    fn_entity_apply_decor_state_flags
        jp    loc_1D8F
fn_spike_logic_tail:
        ; Suite de fn_spike_logic (apres le CALL #113F/JP #1D8F initial): CALL
        ; #1D9E (calibration, meme famille que will-o-wisp/bouncing-ball), LD
        ; (ix+0B),1, teste bit0,(ix+off_state_flags_2) pour choisir le signe du
        ; vecteur ecrit dans (ix+09), CALL fn_position_pitch_sound_arm (#0A07),
        ; RST 10, teste bit0,(ix+off_cooldown_or_collision_flags), puis JR #1112
        ; -- rejoint en plein milieu de fn_will_o_wisp_logic (partage la meme
        ; queue "cooldown -> toggle -> animation -> tail").
        call    loc_1D9E
        ld    (ix+#0B),#01
        bit    0,(ix+off_state_flags_2)
        ld    a,#02
        jr    nz,#10E5
        neg
        ld    (ix+#09),a
        call    fn_position_pitch_sound_arm
        rst    #10
        bit    0,(ix+off_cooldown_or_collision_flags)
        ld    a,#01
        jr    loc_1112
fn_will_o_wisp_logic:
        ; Logique du type d'entité 0xB4 (feu follet) — oscille UNIQUEMENT sur
        ; l'axe Y (le champ (ix+09), composante X, n'est jamais écrit), rebond par
        ; collision selon le même schéma que fn_bouncing_ball_logic et
        ; fn_resolve_patrol_vector (test bit 1 de (ix+0C), bascule bit 1 de
        ; (ix+0D)), joue le même son de rebond générique (0x09A6/0x09AC) que la
        ; balle rebondissante. "2 feux follets, qui se déplacent selon Y et qui
        ; sont en hauteur" — grid_z=0xA4 (nettement au-dessus des blocs),
        ; mouvement Y confirmé par poll RAM (grid_x rigoureusement fixe). Variante
        ; 0x1122 (probable type 0xB5): scintillement pseudo-aléatoire du flag de
        ; rendu selon var_pseudo_random_acc.
        call    loc_1D9E
        ld    (ix+#0B),#01
        bit    1,(ix+off_state_flags_2)
        ld    a,#02
        jr    nz,#1105
        neg
        ld    (ix+#0A),a
        call    fn_position_pitch_sound_arm
        rst    #10
        bit    1,(ix+off_cooldown_or_collision_flags)
        ld    a,#02
loc_1112:
        jr    z,#111D
        xor    (ix+off_state_flags_2)
        ld    (ix+off_state_flags_2),a
        call    fn_sound_trigger_bounce
        call    fn_animation_cycle_4
        jr    loc_1139
fn_will_o_wisp_logic_tail:
        ; Suite de fn_will_o_wisp_logic (apres "jr #1139", #1120): CALL #1D9E,
        ; teste bit0 de var_entity_update_counter (#0082, RET Z si impair --
        ; execute 1 frame sur 2), sinon melange bit6 de var_pseudo_random_acc
        ; (#006D) dans off_flags (scintillement pseudo-aleatoire), CALL
        ; fn_animation_cycle_4 (#1260), puis CALL #113F
        ; (fn_entity_apply_decor_state_flags) et JP #1F7B.
        call    loc_1D9E
        ld    a,(var_entity_update_counter)
        and    #01
        ret    z
        ld    a,(var_pseudo_random_acc)
        and    #40
        xor    (ix+off_flags)
        ld    (ix+off_flags),a
        call    fn_animation_cycle_4
loc_1139:
        call    fn_entity_apply_decor_state_flags
        jp    loc_1F7B
fn_entity_apply_decor_state_flags:
        ; Petit helper partage: LD A,(ix+off_state_flags_2) / OR #A0 (pose bits 5
        ; et 7) / LD (ix+off_state_flags_2),A / RET. Appele (via "call #113F") par
        ; fn_toad_statue_logic (#108C), fn_ceiling_spike_ball_logic (#1092) et
        ; fn_spike_logic (#10CE) -- role exact des bits 5/7 non confirme
        ; (hypothese: marqueur "entite decorative calibree/reglee"), mais la
        ; structure et les 3 appelants sont confirmes par desassemblage direct.
        ld    a,(ix+off_state_flags_2)
        or    #A0
        ld    (ix+off_state_flags_2),a
        ret
fn_bouncing_ball_logic:
        ; Logique des types d'entité 0xB2/0xB3 (balle rebondissante) — oscille
        ; verticalement entre deux bornes (haute = grid_z_initial+0x20, basse =
        ; grid_z_initial, via var_room_reset_flag_3 0x0083), déplacement appliqué
        ; par RST 10, joue un son de rebond à chaque changement de sens
        ; (fn_sound_arm_channel_0, séquence 0x09AC). "la balle rebondit en
        ; continu, son contact fait perdre une vie". Prototype de la catégorie
        ; "mouvement régulier/mécanique".
        call    loc_1D9E
        ld    a,(var_room_reset_flag_3)
        and    a
        jr    nz,#1159
        ld    a,(ix+off_grid_z_or_offset)
        add    a,#20
        ld    (var_room_reset_flag_3),a
        call    fn_animation_cycle_4
        call    fn_position_pitch_sound_arm
        bit    2,(ix+off_state_flags_2)
        jr    nz,fn_bouncing_ball_logic_tail
        rst    #10
        bit    2,(ix+off_cooldown_or_collision_flags)
        jr    z,loc_1173
        set    2,(ix+off_state_flags_2)
        call    fn_sound_trigger_bounce
loc_1173:
        jr    loc_1139
fn_bouncing_ball_logic_tail:
        ; Cible de "jr nz,#1175" (#1163) dans fn_bouncing_ball_logic: LD
        ; (ix+0B),3, RST 10 (chute plus ample), compare var_room_reset_flag_3
        ; (#0083) a off_grid_z_or_offset; si NC, JR #1173 (rejoint le CALL
        ; fn_sound_trigger_bounce/exit); sinon RES 2,(ix+off_state_flags_2) puis
        ; JR #1173 (meme cible, sans le son).
        ld    (ix+#0B),#03
        rst    #10
        ld    a,(var_room_reset_flag_3)
        cp    (ix+off_grid_z_or_offset)
        jr    nc,loc_1173
        res    2,(ix+off_state_flags_2)
        jr    loc_1173
fn_melkhior_room_spawn_check:
        ; Appelée chaque frame depuis fn_arm_room_transition_flag_and_wait, mais
        ; RET immédiat sauf cas précis: si la room courante est #88 (salle de
        ; Melkhior) ET le slot3 (#012B) est vide ET var_special_input_mode_1 est
        ; nul, copie un template fixe de 18 octets (#11A7: type #A0 = poltergeist
        ; au repos, position centrale [#80,#80,#80], bbox [5,5,#0C]) dans le slot3
        ; — spawn conditionnel d'un poltergeist dans la salle de Melkhior. Détail
        ; non expliqué: le champ room du template vaut #B4, pas #88 — piste
        ; ouverte, lien avec le sprite jamais confirmé visuellement 0x96/0x97 pas
        ; établi avec certitude
        ld    a,(var_player_room_number)
        cp    #88
        ret    nz
        ld    de,#012B
        ld    a,(de)
        and    a
        ret    nz
        ld    a,(var_special_input_mode_1)
        and    a
        ret    nz
        ld    hl,tbl_melkhior_spawn_template
        ld    bc,#0012
        push    de
        pop    ix
        ldir
        jp    loc_1D84
tbl_melkhior_spawn_template:
        ; Template fixe de 18 octets copie par fn_melkhior_room_spawn_check
        ; (#1188, LDIR depuis cette adresse) dans le slot3 -- type=#A0
        ; (poltergeist au repos), grid=[#80,#80,#80], bbox=[5,5,#0C], flags=#10,
        ; room=#B4 (anomalie deja notee: pas #88), puis 4 octets a 0,
        ; type_mirror_plus_10=#A0, 4 octets a 0. Deja decrit en prose dans le
        ; commentaire existant de fn_melkhior_room_spawn_check -- adresse et
        ; extent desormais formalisees.
        defb #A0,#80,#80,#80,#05,#05,#0C,#10,#B4,#00,#00,#00,#00,#A0,#00,#00
        defb #00,#00
fn_poltergeist_logic:
        ; Logique par-frame du type d'entite #A0 (poltergeist, voir
        ; tbl_melkhior_spawn_template #11A7), placee juste apres son template de
        ; spawn -- meme convention de colocation que les autres paires
        ; spawn/logique du fichier. CALL #1D84 (calibration), teste (#010F, slot
        ; d'entite 2): si occupe, JP NZ vers la queue de
        ; fn_pusher_enemy_logic_tail (#1239, partage le meme code de
        ; transformation de fin de vecteur); sinon SET 1,(ix+off_flags), RST 10
        ; (application vecteur), CALL fn_animation_cycle_4_tail, compare
        ; off_grid_z_or_offset a #A0 pour choisir (ix+0B)=1 ou 2, teste un seuil
        ; derive de (#00D7) et la phase d'animation (ix+00)&3 pour eventuellement
        ; CALL #1B14 (hors-perimetre) et recombiner le type via OR #A8, sinon
        ; branche vers fn_poltergeist_logic_branch_a (#11F6) ou
        ; fn_poltergeist_logic_branch_b (#1200).
        call    loc_1D84
        ld    a,(#010F)
        and    a
        jp    nz,loc_1239
        set    1,(ix+off_flags)
        rst    #10
        call    fn_animation_cycle_4_tail
        ld    a,(ix+off_grid_z_or_offset)
        cp    #A0
        ld    (ix+#0B),#02
        jr    c,loc_11F3
        ld    (ix+#0B),#01
        ld    a,(struct_entities_base)
        sub    #30
        cp    #10
        jr    c,fn_poltergeist_logic_branch_a
        ld    a,(ix+off_type)
        and    #03
        jr    nz,loc_11F3
        call    fn_pickup_sequence_lookup
        ld    a,(hl)
        or    #A8
        ld    (ix+off_type),a
loc_11F3:
        jp    loc_1F7B
fn_poltergeist_logic_branch_a:
        ; Cible de "jr c,#11F6" dans fn_poltergeist_logic (#11E1): SET
        ; 2,(ix+off_type), RES 1,(ix+off_flags), puis JR #11F3 (rejoint le JP
        ; #1F7B de fn_poltergeist_logic).
        set    2,(ix+off_type)
        res    1,(ix+off_flags)
        jr    loc_11F3
fn_poltergeist_logic_branch_b:
        ; Bloc final de fn_poltergeist_logic (apres RES 1,(ix+off_flags)/JR #11FE
        ; de fn_poltergeist_logic_branch_a): CALL #1D84 (recalibration), LD
        ; (ix+off_type),#A0 (retour a l'etat de repos), JR #11F3 -- remet le
        ; poltergeist a son type de base.
        call    loc_1D84
        ld    (ix+off_type),#A0
        jr    loc_11F3
fn_pusher_enemy_logic:
        ; Logique des types d'entité 0xA4-0xA7 (ennemi "poussoir", inoffensif) —
        ; calcule un vecteur unitaire vers la position du joueur en cache
        ; ((0x00D8)/(0x00D9), fn_vector_toward_player 0x1240) et s'y déplace via
        ; RST 10. "attiré par le joueur pour le pousser, son contact n'est pas
        ; dangereux". Partage le pointeur de sprite 0x518B avec le type 0x85 de
        ; fn_hostile_patrol_logic (0x0E4A, jusqu'ici jamais identifié
        ; visuellement) — même famille visuelle, logiques de comportement
        ; différentes (poussoir vs agressif/mortel). États voisins: 0xA0-0xA3
        ; (logique 0x11B9, "repos"), 0xA8-0xAF. MAJEURE: ces 8 types pointent,
        ; dans tbl_sprite_dispatch, EXACTEMENT vers les 8 sprites du catalogue
        ; d'objets, DANS L'ORDRE — 0xA8=rubis (#4687), 0xA9=poison (#4600),
        ; 0xAA=botte (#446B), 0xAB=calice (#4702), 0xAC=tasse (#4795),
        ; 0xAD=bouteille (#456D), 0xAE=boule de cristal (#44EC), 0xAF=vie bonus
        ; (#4424). CE N'EST PAS UNE "TRANSITION" MAIS L'AFFICHAGE D'INDICE DU
        ; PUZZLE DE MELKHIOR: ce poltergeist (voir fn_melkhior_room_spawn_check
        ; #1188) affiche brièvement le sprite de l'objet à déposer ensuite dans le
        ; chaudron, avant que le handler 0x1200 (calibration + force retour à
        ; (ix+00)=0xA0) ne le remette à l'état de repos — CONFIRMÉ EMPIRIQUEMENT
        ; ("le poltergeist indique quel objet déposer ensuite" quand on entre en
        ; salle 0x88 en forme explorateur). Ceci relie très probablement ce
        ; mécanisme au puzzle de collecte en ordre déjà documenté
        ; (fn_treasure_settle_and_sequence_check #1A93, tbl_pickup_sequence_order
        ; #1B1D) — le dépôt d'un objet dans le chaudron de Melkhior est
        ; vraisemblablement le déclencheur (jusqu'ici non localisé) qui crée une
        ; entité de la famille 0x68-0x6E "jamais rencontrée en jeu" — À VÉRIFIER.
        call    loc_1D84
        ld    a,(ix+off_room_number)
        cp    #88
        jr    z,fn_pusher_enemy_logic_tail
        ld    a,(#00DE)
        bit    0,a
        jr    z,fn_pusher_enemy_logic_tail
        ld    bc,#0101
        jr    loc_1222
fn_pusher_enemy_logic_tail:
        ; Cible de "jr nz,#121F"/"jr z,#121F" (#1211/#1218) dans
        ; fn_pusher_enemy_logic: LD BC,#0404 (vecteur plus large que le cas #121A
        ; ld bc,#0101), CALL fn_vector_toward_player (#1240), RST 10, CALL
        ; fn_animation_cycle_4 (via #1267, queue de fn_animation_cycle_4 --
        ; confirme que ce sous-bloc EST partage), teste room_number==#88 (salle de
        ; Melkhior) et un seuil sur var_newgame_random_seed-derive (0x00D7) pour
        ; forcer (ix+off_type)=1 (transformation ?), puis JP #1AD2 (non identifiee
        ; dans ce fichier, hors-perimetre).
        ld    bc,#0404
loc_1222:
        call    fn_vector_toward_player
        rst    #10
        call    fn_animation_cycle_4_tail
        ld    a,(ix+off_room_number)
        cp    #88
        jr    nz,#123D
        ld    a,(struct_entities_base)
        sub    #10
        cp    #40
        jr    c,#123D
loc_1239:
        ld    (ix+off_type),#01
        jp    loc_1AD2
fn_vector_toward_player:
        ; Calcule un vecteur unitaire (±1 par axe) vers la position du joueur en
        ; cache (0x00D8)/(0x00D9) — même paire de variables utilisée par
        ; fn_player_proximity_death (0x0EA0), confirmant qu'il s'agit d'une
        ; primitive de position joueur globale, recalculée une fois par frame et
        ; consultée par plusieurs types d'entités.
        ld    hl,#00D8
        ld    a,(ix+off_grid_x)
        sub    (hl)
        inc    hl
        ld    a,c
        jp    m,#124E
        neg
        ld    (ix+#09),a
        ld    a,(ix+off_grid_y)
        sub    (hl)
        inc    hl
        ld    a,b
        jp    m,#125C
        neg
        ld    (ix+#0A),a
        ret
fn_animation_cycle_4:
        ; Pattern générique: nouveau type = (type & 0xFC) \| ((type+1) & 0x03) —
        ; cycle d'animation à 4 phases encodées dans les 2 bits bas du type.
        ; Potentiellement réutilisé par d'autres entités animées
        ld    a,(ix+off_type)
        xor    #01
        jr    loc_1273
fn_animation_cycle_4_tail:
        ; Cible de "jr #1273" (#1265) dans fn_animation_cycle_4: calcule et stocke
        ; (ix+off_type)=(type&0xFC)|((type+1)&3) -- la combinaison finale du cycle
        ; 4 phases -- puis RET. Egalement atteint directement via CALL #1267
        ; depuis fn_pusher_enemy_logic_tail (#1226).
        ld    a,(ix+off_type)
        ld    c,a
        and    #FC
        ld    b,a
        ld    a,c
        inc    a
        and    #03
        or    b
loc_1273:
        ld    (ix+off_type),a
        ret
fn_cauldron_logic:
        jp    loc_1DB2
fn_cauldron_icon_logic:
        ; Desassemblage direct confirme l'adresse exacte. #0CE8 tombe dans la zone
        ; des programmes sonores (voisine de #0C36-#0C55 deja documentes) --
        ; hypothese: selectionne/prepare l'icone affichee (crane='poison' observe)
        ; via un mecanisme encore non identifie, PAS confirme.
        ld    hl,#0CE8
        jp    loc_1FEB
fn_guard_patrol_logic:
        ; Logique du type d'entité 0x1E (gardien en patrouille) — résout un
        ; vecteur de déplacement (±2 sur un axe) selon une direction 0-3 stockée
        ; dans (ix+0D)&3 via fn_resolve_patrol_vector (0x12A5), l'applique via RST
        ; 10, appelle fn_guard_walk_animation_toggle (0x1055), puis sauvegarde
        ; position dans pending_grid_x/y (+1D/+1E, mêmes champs que
        ; fn_room_transition). Le gardien change de direction 4 fois par ronde
        ; complète. ET CONFIRMÉ AU MAXIMUM: le changement de direction est bien
        ; déclenché PAR COLLISION (bit 0/1 de (ix+0C)) — confirmé par
        ; désassemblage + test empirique isolé (table contre un mur) + test
        ; empirique combiné (impact gardien/table synchronisé, table poussée d'un
        ; cran à chaque demi-tour du gardien).
        call    loc_1DBC
        rst    #10
        call    fn_resolve_patrol_vector
        ld    (ix+#09),l
        ld    (ix+#25),l
        ld    (ix+#0A),h
        ld    (ix+#26),h
        ld    a,(ix+off_grid_x)
        ld    (ix+off_pending_grid_x),a
        ld    a,(ix+off_grid_y)
        ld    (ix+off_pending_grid_y),a
        call    fn_guard_walk_animation_toggle
        jp    loc_1139
fn_resolve_patrol_vector:
        ; RST 28 dispatch (table 0x12B1, 4 entrées) sur direction (ix+0D)&3 ->
        ; vecteur fixe (±2,0) ou (0,±2) selon l'axe. Chaque entrée teste AUSSI un
        ; bit de collision sur (ix+0C) (bit 0 pour les directions 0/2, bit 1 pour
        ; les directions 1/3) — si le bit est posé (collision détectée sur cet
        ; axe), incrémente la direction de 1 (mod 4) AVANT de résoudre le vecteur;
        ; sinon continue tout droit. C'est LE mécanisme "le gardien tourne après
        ; une collision" décrit.
        ld    bc,tbl_guard_patrol_vector_dispatch
        ld    a,(ix+off_state_flags_2)
        and    #03
        ld    l,a
        jp    rst_dispatch_table
tbl_guard_patrol_vector_dispatch:
        ; 4 pointeurs word (index = code d'orientation 0-3, bits0-1 de
        ; off_state_flags_2), vers fn_guard_patrol_vector_o0..o3 -- meme motif RST
        ; 28 (rst_dispatch_table #0028) que tbl_player_forward_vector_dispatch
        ; (#22E4, asm/code/doors_and_player_logic.asm), utilise par
        ; fn_resolve_patrol_vector (#12A5). Resout le vecteur de patrouille par
        ; defaut ET, sur collision, le vecteur de demi-tour + la rotation de
        ; state_flags_2.
        defw #12B9
        defw #12D4
        defw #12E1
        defw #12EE
fn_guard_patrol_vector_o0:
        ; Entree 0 de tbl_guard_patrol_vector_dispatch : vecteur fixe (+2,0) ou
        ; (0,+2) selon l'axe associe a cette orientation.
        ld    hl,#00FE
        bit    0,(ix+off_cooldown_or_collision_flags)
        ret    z
        ld    hl,#0200
loc_12C4:
        ld    a,(ix+off_state_flags_2)
        ld    c,a
        inc    a
        and    #03
        ld    b,a
        ld    a,c
        and    #FC
        or    b
        ld    (ix+off_state_flags_2),a
        ret
fn_guard_patrol_vector_o1:
        ; Entree 1 de tbl_guard_patrol_vector_dispatch : vecteur fixe pour cette
        ; orientation.
        ld    hl,#0200
        bit    1,(ix+off_cooldown_or_collision_flags)
        ret    z
        ld    hl,#0002
        jr    loc_12C4
fn_guard_patrol_vector_o2:
        ; Entree 2 de tbl_guard_patrol_vector_dispatch : vecteur fixe pour cette
        ; orientation.
        ld    hl,#0002
        bit    0,(ix+off_cooldown_or_collision_flags)
        ret    z
        ld    hl,#FE00
        jr    loc_12C4
fn_guard_patrol_vector_o3:
        ; Entree 3 de tbl_guard_patrol_vector_dispatch : vecteur fixe pour cette
        ; orientation.
        ld    hl,#FE00
        bit    1,(ix+off_cooldown_or_collision_flags)
        ret    z
        ld    hl,#00FE
        jr    loc_12C4
fn_game_over_or_daycycle_end:
        ; Point de sortie commun atteint par 2 chemins: jour 40 (var_day_counter)
        ; ET var_life_counter négatif (0x29CA, ex-"var_room_countdown"). Écran de
        ; fin de partie
        ld    a,(var_special_input_mode_1)
        and    a
        jp    nz,fn_game_over_screen_sequence
loc_1302:
        call    fn_clear_intermediate_buffer
        call    fn_clear_screen
        ld    de,#1431
        exx
        ld    hl,#1437
        ld    de,#1443
        ld    b,#06
        call    loc_176B
        ld    a,#FF
        ld    (#172C),a
        ld    (#173C),a
        ld    de,var_pickup_sequence_counter
        ld    a,(de)
        sub    #0A
        jr    c,#132A
        or    #10
        ld    (de),a
        ld    hl,#A3EE
        ld    b,#01
        call    fn_hud_render_bcd_digits
        ld    hl,#AFDE
        ld    de,var_day_counter
        ld    b,#01
        call    fn_hud_render_bcd_digits
        call    fn_pickup_progress_display_calc
        ld    a,(#008B)
        rlca
        and    #C0
        ld    c,a
        ld    a,(var_special_input_mode_1)
        and    #01
        or    c
        rlca
        rlca
        rlca
        and    #0E
        ld    l,a
        ld    h,#00
        ld    bc,tbl_game_over_screen_message_ptrs
        add    hl,bc
        ld    e,(hl)
        inc    hl
        ld    d,(hl)
        ld    hl,loc_2758
        call    fn_menu_draw_string_de_attribute
        call    fn_game_over_border_draw
        call    fn_copy_screen_rect
        xor    a
        ld    hl,tbl_wait_any_key_all_rows
        call    fn_read_joystick_table
        jr    nz,#1368
        ld    hl,tbl_sound_program_ptrs_gameover
        call    fn_sound_program_play_blocking
        call    fn_wait_input_release_with_timeout
        jp    fn_restart_from_menu
fn_wait_input_release_with_timeout:
        ; Boucle avec compteur HL=#2000 decroissant, appelle
        ; fn_read_joystick_table (HL=tbl_wait_any_key_all_rows) a chaque iteration
        ; et sort par RET NZ si une touche/direction est active, sinon decremente
        ; HL et boucle jusqu'a expiration. Utilisee aussi comme entree alternative
        ; directe via un jump qui saute cette attente.
        ld    hl,#2000
        push    hl
        ld    hl,tbl_wait_any_key_all_rows
        call    fn_read_joystick_table
        pop    hl
        ret    nz
        dec    hl
        ld    a,h
        or    l
        jr    nz,#1380
        ret
fn_game_over_screen_sequence:
        ; Corps principal de l'ecran de fin de partie/bilan de journee (suite de
        ; fn_game_over_or_daycycle_end): efface le buffer intermediaire et l'ecran
        ; (fn_clear_intermediate_buffer/fn_clear_screen), CALL #2B3B, prepare 3
        ; paires de pointeurs (DE=#13B7 via echange EXX, HL=#13BD, DE=#13C9 --
        ; voir tbl_game_over_screen_strings_a) et B=6, CALL #176B (hors-perimetre,
        ; non desassemble ici), remet a #FF deux compteurs d'animation
        ; (#172C/#173C), met a jour var_pickup_sequence_counter (#0081, plafonne a
        ; 9 puis pose bit4), affiche 2 compteurs BCD via fn_hud_render_bcd_digits
        ; (#1571: var_pickup_sequence_counter puis var_day_counter), CALL
        ; fn_pickup_progress_display_calc (#14F5), calcule un index 0-14 combinant
        ; (008B)/var_special_input_mode_1 pour choisir un pointeur dans
        ; tbl_game_over_screen_message_ptrs (#149C), affiche le message choisi via
        ; fn_menu_draw_string_reset_font (#16EA, HL=#2758), CALL #2B3B,
        ; fn_copy_screen_rect, boucle d'attente input (fn_read_joystick_table),
        ; joue le jingle de fin (#0C49, fn_sound_program_play_blocking), rappelle
        ; fn_wait_input_release_with_timeout (#137D) puis JP fn_restart_from_menu.
        call    fn_clear_intermediate_buffer
        call    fn_clear_screen
        call    fn_game_over_border_draw
        ld    de,tbl_game_over_screen_strings_a
        exx
        ld    hl,#13BD
        ld    de,#13C9
        ld    b,#06
        xor    a
        ld    (#007E),a
        call    loc_176B
        ld    hl,tbl_sound_program_ptrs_unused_b
        call    fn_sound_program_channel_setup
        call    fn_wait_input_release_with_timeout
        jp    loc_1302
tbl_game_over_screen_strings_a:
        ; [hypothesis] Bloc de donnees encodees (PAS du code -- desassemblage
        ; lineaire y produit des instructions absurdes/incoherentes, signal
        ; classique de donnees, cf. DE=#13B7, HL=#13BD, DE=#13C9, ces 3 adresses
        ; tombent bien a l'interieur de ce bloc). Structure CONFIRMEE: suite de
        ; segments termines par un octet >=0x80 (meme convention que
        ; fn_menu_draw_string "terminateur bit7"), valeurs de contenu
        ; majoritairement dans 0x0A-0x26 (indices de glyphes, PAS de l'ASCII brut)
        ; avec l'octet 0x26 tres frequent (probable separateur/espace) et quelques
        ; runs de 0x0F/0xFF/0xF0 (probables separateurs visuels entre messages,
        ; pas du texte). HYPOTHESE (non decodee caractere par caractere, aucune
        ; table glyphe->caractere confirmee dans ce projet): messages de l'ecran
        ; de fin de partie/bilan de journee (rendus via
        ; fn_menu_draw_string_reset_font #16DA avec tbl_menu_font #3294, asm).
        ; Extent CONFIRMEE par adjacence: se termine exactement ou commence
        ; tbl_game_over_screen_message_ptrs (#149C).
        defb #0F,#0F,#F0,#F0,#FF,#FF,#40,#87,#40,#77,#30,#67,#30,#57,#50,#47
        defb #30,#37,#1D,#11,#0E,#26,#19,#18,#1D,#12,#18,#17,#26,#0C,#0A,#1C
        defb #1D,#9C,#12,#1D,#1C,#26,#16,#0A,#10,#12,#0C,#26,#1C,#1D,#1B,#18
        defb #17,#90,#0A,#15,#15,#26,#0E,#1F,#12,#15,#26,#16,#1E,#1C,#1D,#26
        defb #0B,#0E,#20,#0A,#1B,#8E,#1D,#11,#0E,#26,#1C,#19,#0E,#15,#15,#26
        defb #11,#0A,#1C,#26,#0B,#1B,#18,#14,#0E,#97,#22,#18,#1E,#26,#0A,#1B
        defb #0E,#26,#0F,#1B,#0E,#8E,#10,#18,#26,#0F,#18,#1B,#1D,#11,#26,#1D
        defb #18,#26,#16,#12,#1B,#0E,#16,#0A,#1B,#8E,#0F,#FF,#FF,#FF,#FF,#0F
        defb #58,#9F,#50,#7F,#30,#6F,#40,#5F,#30,#4F,#48,#37,#10,#0A,#16,#0E
        defb #26,#26,#18,#1F,#0E,#9B,#1D,#12,#16,#0E,#26,#26,#26,#26,#0D,#0A
        defb #22,#9C,#19,#0E,#1B,#0C,#0E,#17,#1D,#0A,#10,#0E,#26,#18,#0F,#26
        defb #1A,#1E,#0E,#1C,#9D,#0C,#18,#16,#19,#15,#0E,#1D,#0E,#0D,#26,#26
        defb #26,#26,#26,#A7,#0C,#11,#0A,#1B,#16,#1C,#26,#0C,#18,#15,#15,#0E
        defb #0C,#1D,#0E,#0D,#26,#26,#A6,#18,#1F,#0E,#1B,#0A,#15,#15,#26,#1B
        defb #0A,#1D,#12,#17,#90
tbl_game_over_screen_message_ptrs:
        ; Index 0-14 pair calcule par fn_game_over_screen_sequence a partir de
        ; var_special_input_mode_1 et d'un compteur. Les 8 valeurs tombent
        ; exactement sur les frontieres de segment (terminateur bit7) de
        ; tbl_game_over_screen_strings_b.
        defw #14AC
        defw #14B4
        defw #14BD
        defw #14C5
        defw #14CD
        defw #14D7
        defw #14E2
        defw #14EA
tbl_game_over_screen_strings_b:
        ; [hypothesis] 8 messages encodes (meme encodage/convention que
        ; tbl_game_over_screen_strings_a), pointes individuellement par les 8
        ; entrees de tbl_game_over_screen_message_ptrs (#149C) -- selection
        ; confirmee par calcul (voir cette table). Segmentation bit7 CONFIRMEE en
        ; exactement 8 segments correspondant aux 8 pointeurs. Semantique (quel
        ; message precis) NON decodee -- hypothese seulement: variantes du message
        ; de fin de partie/bilan selon (008B) (jour/nuit ?) et
        ; var_special_input_mode_1 (mode de controle ?).
        defb #0F,#26,#26,#26,#19,#18,#18,#9B,#0F,#26,#0A,#1F,#0E,#1B,#0A,#10
        defb #8E,#0F,#26,#26,#26,#0F,#0A,#12,#9B,#0F,#26,#26,#26,#10,#18,#18
        defb #8D,#0F,#0E,#21,#0C,#0E,#15,#15,#0E,#17,#9D,#0F,#16,#0A,#1B,#1F
        defb #0E,#15,#15,#18,#1E,#9C,#0F,#26,#26,#26,#11,#0E,#1B,#98,#0F,#0A
        defb #0D,#1F,#0E,#17,#1D,#1E,#1B,#0E,#9B
fn_pickup_progress_display_calc:
        ; CALL cible de fn_game_over_screen_sequence. Compte les bits a 1 sur 32
        ; octets/256 bits a partir de (#00B7=var_room_visited_bitmap), combine ce
        ; compte avec var_pickup_sequence_counter (#0081, SLA puis ADD), puis
        ; calcule 2 octets BCD (via ADD HL,BC repete + ADC/DAA, BC=#A41A puis
        ; +#0028) ecrits a (#008F)/(#008E). HYPOTHESE sur le role exact (nom
        ; provisoire): tally de progression du puzzle de collecte affiche sur
        ; l'ecran de fin de partie -- structure de calcul confirmee par
        ; desassemblage direct, semantique non verifiee par test comportemental.
        ld    e,#00
        ld    bc,#0820
        ld    hl,var_room_visited_bitmap
        push    bc
        ld    a,(hl)
        inc    hl
loc_1500:
        rrca
        jr    nc,#1504
        inc    e
        djnz    loc_1500
        pop    bc
        dec    c
        jr    nz,#14FD
        ld    a,e
        dec    a
        ld    (#008B),a
        ld    a,(var_pickup_sequence_counter)
        sla    a
        add    a,e
        ld    e,a
        ld    bc,#A41A
        ld    hl,fn_cold_boot_entry
        xor    a
        add    hl,bc
        adc    a,#00
        daa
        dec    e
        jr    nz,#151D
        ld    bc,rst_dispatch_table
        add    hl,bc
        adc    a,#00
        daa
        ld    (#008F),a
        ld    a,#00
        adc    a,#00
        daa
        ld    (#008E),a
        ld    hl,#A7E6
        ld    de,#008E
        ld    b,#01
        ld    a,(de)
        and    a
        jr    z,fn_pickup_progress_display_calc_zero_case
        inc    b
        jp    loc_1583
fn_pickup_progress_display_calc_zero_case:
        ; Cible de "jr z,#1546" (#1540) dans fn_pickup_progress_display_calc: cas
        ; ou le compte de bits est nul -- INC HL / INC DE puis JP
        ; fn_hud_render_bcd_digits (#1571), sans passer par l'increment de
        ; compteur B fait dans le cas general.
        inc    hl
        inc    de
        jp    fn_hud_render_bcd_digits
fn_hud_render_day_counter:
        ; Arme (#172C)/(#173C)=#FF (compteurs d'animation, meme paire que
        ; fn_game_over_screen_sequence), DE=var_day_counter (#007F), B=1, HL=#91DE
        ; (position ecran), puis JP fn_hud_render_bcd_digits.
        ld    a,#FF
        ld    (#172C),a
        ld    (#173C),a
        ld    hl,#91DE
        ld    de,var_day_counter
        ld    b,#01
        jp    fn_hud_render_bcd_digits
fn_hud_render_secondary_counter:
        ; Meme structure que fn_hud_render_day_counter mais DE=#0080 (variable non
        ; nommee, valeur initialisee a 5 au boot d'apres fn_boot_init_and_new_game
        ; -- hypothese: compteur de vies) et HL=#99C8 (autre position ecran).
        ; Semantique de (#0080) non confirmee ici.
        ld    a,#FF
        ld    (#172C),a
        ld    (#173C),a
        ld    de,var_life_counter
        ld    b,#01
        ld    hl,#99C8
        jp    fn_hud_render_bcd_digits
fn_hud_render_bcd_digits:
        ; Helper partage: force (#008C)=tbl_menu_font (#3294), puis pour B
        ; iterations lit un octet a (DE), affiche son nibble haut PUIS son nibble
        ; bas via fn_menu_glyph_unpack (#170D) a la position HL courante
        ; (incrementee par le glyph-unpack lui-meme), avance DE. Rend un octet
        ; comme 2 chiffres/glyphes -- routine d'affichage BCD generique. Appelants
        ; CONFIRMES: fn_game_over_or_daycycle_end (#132F avec
        ; var_pickup_sequence_counter, #133A avec var_day_counter -- code deja
        ; existant dans ce fichier), fn_pickup_progress_display_calc_zero_case
        ; (#1546), fn_hud_render_day_counter (#154B),
        ; fn_hud_render_secondary_counter (#155E).
        push    hl
        ld    hl,tbl_menu_font
        ld    (var_glyph_table_base),hl
        pop    hl
loc_1579:
        ld    a,(de)
        rrca
        rrca
        rrca
        rrca
        and    #0F
        call    fn_menu_glyph_unpack
loc_1583:
        ld    a,(de)
        and    #0F
        call    fn_menu_glyph_unpack
        inc    de
        djnz    loc_1579
        ret
fn_hud_render_minifont_message:
        ; Force (#008C)=tbl_hud_minifont_glyphs (#15A2, police locale dediee, PAS
        ; tbl_menu_font), DE=tbl_hud_minifont_message_text (#159D, chaine fixe de
        ; 5 octets), HL=#0F70 (position ecran), PUSH HL puis JP #16F1 (entre au
        ; milieu de la queue de rendu partagee fn_menu_draw_string_reset_font, en
        ; reutilisant la police deja posee au lieu de la reinitialiser a
        ; tbl_menu_font). Role exact du message affiche non confirme (chaine tres
        ; courte).
        ld    hl,tbl_hud_minifont_glyphs
        ld    (var_glyph_table_base),hl
        ld    de,tbl_hud_minifont_message_text
        ld    hl,#0F70
        push    hl
        jp    loc_16F1
tbl_hud_minifont_message_text:
        ; [hypothesis] Chaine fixe de 5 octets (#FF,#00,#01,#02,#83) terminee par
        ; un octet bit7 (#83, meme convention que tbl_game_over_screen_strings_a),
        ; source de fn_hud_render_minifont_message (#158D). Contenu tres court
        ; (2-3 glyphes utiles) -- hypothese: un statut/indicateur numerique court
        ; plutot qu'un vrai mot, semantique non confirmee.
        defb #FF,#00,#01,#02,#83
tbl_hud_minifont_glyphs:
        ; [hypothesis] 32 octets poses comme police locale (#008C) par
        ; fn_hud_render_minifont_message (#158D) -- distincte de tbl_menu_font
        ; (#3294). Contenu (07,06,06,06,0F,00,01,82,C6,64,6C,6D,C6,C8,C6,E1,60,60,
        ; E0,64,63,60,60,60,E0,60,40,C0,80,...) compatible avec un en-tete de
        ; dimensions (largeur/hauteur) suivi de lignes de bitmap (motifs
        ; 0x60/0xC0/0xE0 typiques de segments de trait), mais format exact et jeu
        ; de glyphes couverts NON confirmes (aucun mecanisme de rendu de police
        ; alternative documente ailleurs dans ce projet pour verifier le
        ; decoupage).
        defb #06,#07,#06,#06,#06,#06,#06,#0F,#00,#01,#82,#C6,#64,#6C,#6D,#C6
        defb #C8,#C6,#E1,#60,#60,#E0,#64,#63,#60,#60,#60,#E0,#60,#40,#C0,#80
fn_control_mode_menu:
        ; Efface buffer/ecran, remplit #167C-167E via
        ; fn_control_mode_menu_palette_indicator_update, configure le Gate Array
        ; (fn_gate_array_config_stream, HL=#0055), joue un jingle
        ; (fn_sound_program_play_blocking). Lit les lignes clavier 7 et 8 pour
        ; mettre a jour bit1 et bit3 de var_input_mode_flag (mode
        ; clavier/joystick). Boucle sur la lecture clavier ligne 4 (validation) et
        ; var_newgame_random_seed (pour l'animation) avant de relancer la boucle.
        xor    a
        ld    (#007E),a
        ld    hl,#167C
        ld    b,#03
loc_15CB:
        ld    (hl),#0F
        inc    hl
        djnz    loc_15CB
        call    fn_clear_intermediate_buffer
        call    fn_game_over_border_draw
        call    fn_control_mode_menu_palette_indicator_update
        ld    hl,tbl_ga_config_stream_boot
        call    fn_gate_array_config_stream
        call    loc_175F
        ld    hl,tbl_sound_program_ptrs_control_menu
        call    fn_sound_program_play_blocking
loc_15E8:
        ld    hl,tbl_ga_config_stream_boot
        call    fn_gate_array_config_stream
        call    loc_175F
        ld    a,#08
        call    fn_read_keyboard_line
        ld    e,a
        ld    a,(var_input_mode_flag)
        ld    (#006E),a
        bit    0,e
        jr    z,#1603
        res    1,a
        bit    1,e
        jr    z,#1609
        or    #02
        ld    (var_input_mode_flag),a
        ld    a,#07
        call    fn_read_keyboard_line
        ld    hl,#0096
        bit    1,a
        jr    z,fn_control_mode_menu_branch_a
        bit    0,(hl)
        jr    nz,loc_1626
        set    0,(hl)
        ld    a,(var_input_mode_flag)
        xor    #08
        ld    (var_input_mode_flag),a
loc_1626:
        ld    a,(var_input_mode_flag)
        ld    hl,#006E
        cp    (hl)
        jr    z,#1639
        xor    a
        ld    (#007E),a
        ld    hl,tbl_sound_program_ptrs_unused_c
        call    fn_sound_program_channel_setup
        ld    a,#04
        call    fn_read_keyboard_line
        bit    0,a
        ret    nz
        ld    hl,var_newgame_random_seed
        inc    (hl)
        ld    a,(hl)
        and    #07
        jr    nz,loc_1654
        ld    hl,#005F
        ld    a,(hl)
        cp    #4B
        jr    nz,fn_control_mode_menu_branch_b
        ld    (hl),#55
loc_1654:
        call    fn_control_mode_menu_palette_indicator_update
        jp    loc_15E8
fn_control_mode_menu_branch_a:
        ; Cible de "jr z,#165A" (#1616) dans fn_control_mode_menu: RES 0,(HL)
        ; (HL=#0096) puis JR #1626 -- rejoint la comparaison (#006C) vs (#006E).
        res    0,(hl)
        jr    loc_1626
fn_control_mode_menu_branch_b:
        ; Cible de "jr nz,#165E" (#1650) dans fn_control_mode_menu: LD (HL),#4B
        ; (HL=#005F) puis JR #1654 -- rejoint le CALL
        ; fn_control_mode_menu_palette_indicator_update / JP #15E8.
        ld    (hl),#4B
        jr    loc_1654
fn_control_mode_menu_palette_indicator_update:
        ; CALL cible de fn_control_mode_menu (#15D6, #1654). Ecrit #0F (par
        ; defaut) puis, si bit3 de var_input_mode_flag (#006C) pose, #FF, dans
        ; l'octet a (#167C) -- octet qui se trouve au milieu de
        ; tbl_menu_or_status_data (#167B), voir cette entree pour la remarque sur
        ; ce chevauchement variable-mutable/donnee-statique. Appelle aussi #174F
        ; (hors-perimetre, corps de fn_menu_glyph_unpack #170D probablement).
        ld    hl,#167C
        ld    a,(var_input_mode_flag)
        rrca
        and    #01
        ld    b,#02
        call    loc_174F
        ld    (hl),#0F
        ld    a,(var_input_mode_flag)
        and    #08
        ret    z
        ld    (hl),#FF
        ret
tbl_menu_or_status_data:
        ; [hypothesis] Desassemblage lineaire incoherent (valeurs 0x0A-0x26
        ; dominantes, 0x26 frequent, segments termines par un octet >=0x80) --
        ; signature de donnees, pas de code. L'octet a #167C (2e octet du bloc)
        ; est aussi reutilise comme variable mutable par
        ; fn_control_mode_menu_palette_indicator_update (valeurs #0F/#FF).
        ; Hypothese sur le contenu : messages courts du menu, meme encodage que
        ; tbl_game_over_screen_strings_a. Extent confirmee par adjacence avec
        ; fn_menu_draw_string_reset_font.
        defb #F0,#FF,#0F,#0F,#0F,#0F,#58,#9F,#30,#87,#30,#77,#30,#5F,#30,#3F
        defb #50,#27,#14,#17,#12,#10,#11,#1D,#26,#15,#18,#1B,#8E,#01,#26,#14
        defb #0E,#22,#0B,#18,#0A,#1B,#8D,#02,#26,#13,#18,#22,#1C,#1D,#12,#0C
        defb #94,#03,#26,#0D,#12,#1B,#0E,#0C,#1D,#12,#18,#17,#0A,#15,#26,#0C
        defb #18,#17,#1D,#1B,#18,#95,#00,#26,#1C,#1D,#0A,#1B,#1D,#26,#10,#0A
        defb #16,#8E,#25,#26,#01,#09,#08,#04,#26,#0A,#24,#0C,#24,#10,#A4
fn_menu_draw_string_reset_font:
        ; Variante de fn_menu_draw_string (#16E5): force explicitement
        ; (#008C)=tbl_menu_font (#3294) et calcule l'adresse ecran via
        ; fn_buffer_addr_from_vram (#3186), PUIS tombe (fall-through, pas de saut)
        ; dans le corps propre de fn_menu_draw_string a #16E5 -- donc DE (pointeur
        ; chaine) doit deja etre pose par l'appelant, et l'octet d'attribut vient
        ; de (#007C) comme dans fn_menu_draw_string. Distinct de
        ; fn_menu_draw_string_de_attribute (#16EA), qui prend son octet d'attribut
        ; directement dans la chaine (DE) plutot que dans (#007C).
        push    hl
        ld    hl,tbl_menu_font
        ld    (var_glyph_table_base),hl
        pop    hl
        call    fn_buffer_addr_from_vram
fn_menu_draw_string:
        ; Menu seulement: affiche une chaîne (terminateur bit7) via
        ; fn_menu_glyph_unpack
        ld    a,(#007C)
        jr    loc_16F7
fn_menu_draw_string_de_attribute:
        ; CALL cible CONFIRMEE, deja presente dans le code existant de
        ; fn_game_over_screen_sequence (#135F, "call #16EA") -- desassemblage
        ; direct resout cette citation. Variante de fn_menu_draw_string (#16E5):
        ; force (#008C)=tbl_menu_font (#3294), calcule l'adresse ecran
        ; (fn_buffer_addr_from_vram #3186), puis lit le PREMIER octet de la chaine
        ; (DE) comme octet d'attribut (stocke dans #172C/#173C, meme paire de
        ; compteurs d'animation que fn_hud_render_day_counter), avant de boucler
        ; sur les caracteres suivants (bit7 = terminateur, rendu via
        ; fn_menu_glyph_unpack #170D) -- rejoint le meme point de sortie que
        ; fn_menu_draw_string (#170A/#170D).
        push    hl
        ld    hl,tbl_menu_font
        ld    (var_glyph_table_base),hl
loc_16F1:
        pop    hl
        call    fn_buffer_addr_from_vram
        ld    a,(de)
        inc    de
loc_16F7:
        ld    (#172C),a
        ld    (#173C),a
loc_16FD:
        ld    a,(de)
        inc    de
        bit    7,a
        jr    nz,fn_menu_draw_string_de_attribute_last_char
        call    fn_menu_glyph_unpack
        jr    loc_16FD
fn_menu_draw_string_de_attribute_last_char:
        ; Cible de "jr nz,#1708" (#1701) dans fn_menu_draw_string_de_attribute:
        ; dernier caractere de la chaine (bit7 pose) -- AND #7F (masque le bit7)
        ; puis JP fn_menu_glyph_unpack (#170D), tail-call qui rend le dernier
        ; glyphe et retourne directement chez l'appelant original.
        and    #7F
        jp    fn_menu_glyph_unpack
fn_menu_glyph_unpack:
        ; Menu seulement: déballe un glyphe 4bpp→2bpp vers buffer de travail
        push    bc
        push    de
        push    hl
        ld    l,a
        ld    h,#00
        add    hl,hl
        add    hl,hl
        add    hl,hl
        ld    de,(var_glyph_table_base)
        add    hl,de
        ex    de,hl
        pop    hl
        ld    b,#08
loc_171F:
        ld    a,(de)
        rrca
        rrca
        rrca
        rrca
        and    #0F
        ld    c,a
        ld    a,(de)
        and    #F0
        or    c
        and    #0F
        ld    (hl),a
        inc    hl
        ld    a,(de)
        and    #0F
        ld    c,a
        ld    a,(de)
        rlca
        rlca
        rlca
        rlca
        and    #F0
        or    c
        and    #0F
        ld    (hl),a
        dec    hl
        inc    de
        push    bc
        ld    bc,#FFC0
        add    hl,bc
        pop    bc
        djnz    loc_171F
        pop    de
        ld    bc,#0202
        add    hl,bc
        pop    bc
        ret
loc_174F:
        and    a
        jr    nz,#1759
        ld    (hl),#FF
        jr    loc_175B
loc_1756:
        dec    a
        jr    z,#1752
        ld    (hl),#0F
loc_175B:
        inc    hl
        djnz    loc_1756
        ret
loc_175F:
        ld    de,tbl_menu_or_status_data
        exx
        ld    hl,#1681
        ld    de,#168D
        ld    b,#06
loc_176B:
        exx
        ld    a,(de)
        ld    (#007C),a
        inc    de
        exx
        push    bc
        ld    a,(hl)
        inc    hl
        inc    hl
        push    hl
        dec    hl
        ld    h,(hl)
        ld    l,a
        call    fn_menu_draw_string_reset_font
        pop    hl
        pop    bc
        djnz    loc_176B
        ld    a,(#007E)
        and    a
        ret    nz
        inc    a
        ld    (#007E),a
        jp    fn_copy_screen_rect
loc_178D:
        push    bc
        push    de
        push    hl
        call    loc_2F2B
        pop    hl
        pop    de
        pop    bc
        ld    a,(ix+off_screen_x)
        add    a,e
        ld    (ix+off_screen_x),a
        ld    a,(ix+off_screen_y)
        add    a,d
        ld    (ix+off_screen_y),a
        djnz    loc_178D
        ret
fn_player_materialize_anim_b:
        ; Logique des types 0x78-0x7E: identique à 0x17DC (incrémente (ix+00)
        ; toutes les 2 frames) — 2e moitié de la séquence de (dé)matérialisation.
        call    loc_1D84
        ld    a,(var_frame_counter)
        cpl
        and    #01
        ret    nz
        inc    (ix+off_type)
        ld    a,(ix+off_type)
        rrca
        rrca
        rrca
        jr    loc_17E2
fn_player_materialize_anim_end:
        ; Logique du type 0x7F (fin de la séquence de matérialisation) — restaure
        ; le type stable du joueur depuis (ix+10) (déjà connu, mémorise le type
        ; "normal" jour/nuit), efface le bit 6 de (ix+0D), puis jp 0x05D4 (reprise
        ; NORMALE de la boucle de jeu, PAS un restart complet).
        call    loc_1D84
        res    6,(ix+off_state_flags_2)
        ld    a,(ix+off_transform_step_counter)
        ld    (ix+off_type),a
        jp    fn_main_loop_entity_dispatch
loc_17CC:
        ld    (ix+off_type),#70
        set    1,(ix+off_flags)
        jr    loc_17E2
loc_17D6:
        ld    hl,tbl_sound_descriptor_noise_decay
        call    fn_sound_arm_channel_0
fn_player_materialize_anim_a:
        ; Logique des types 0x70-0x76: incrémente (ix+00) toutes les 2 frames
        ; (throttle via var_frame_counter 0x006A) — 1re moitié de la séquence de
        ; (dé)matérialisation du joueur. Voir 0x17A7/0x17FC/0x17BC pour la suite.
        ; Proposé et confirmé: "animation pour faire disparaître/rematérialiser le
        ; joueur, la même au lancement du jeu et après une perte de vie". Type
        ; 0x78 observé au tout premier lancement de partie ET lors du reset après
        ; mort.
        call    loc_1D84
        inc    (ix+off_type)
loc_17E2:
        ld    a,(ix+off_type)
        rrca
        rrca
        rrca
        cpl
        and    #E0
        ld    l,a
        ld    h,#00
        call    loc_0A14
        jp    loc_1F7B
fn_pickup_catalog_ptr_clear_and_idle:
        ; RESOUT les 2 derniers types sans logique tracee de
        ; tbl_entity_logic_dispatch (audit complet 2026-08-14 des 188 entrees) :
        ; 0xB9 (etape intermediaire de la sequence d'eveil du bloc dormant
        ; 0xB8->0xB9->..., type_dormant_block_awake_base) et 0xBB
        ; (type_collision_transformed, resultat de fn_collision_effect sur un
        ; objet ramasse 0x60-0x67). Ecrit 0x00 a travers le pointeur
        ; (ix+0x10)/(ix+0x11) -- meme champ reutilise comme pointeur catalogue que
        ; dans fn_treasure_pickup_sequence_advance (#1AE5) -- ce qui a pour effet
        ; d'invalider l'entree tbl_object_catalog correspondante
        ; (fn_object_catalog_writeback, #1E67, ne resynchronisera plus cet objet).
        ; Enchaine ensuite SANS saut (fall-through) dans
        ; fn_player_materialize_anim_pivot (#17FC) : calibration de projection
        ; puis jp #1239 (idle generique). Pour 0xB9, ceci confirme que la sequence
        ; d'eveil du bloc dormant s'arrete definitivement a cette etape (se
        ; stabilise en idle) plutot que de continuer a s'auto-incrementer
        ; indefiniment.
        ld    l,(ix+off_transform_step_counter)
        ld    h,(ix+#11)
        ld    (hl),#00
fn_player_materialize_anim_pivot:
        ; Logique du type 0x77 (point de bascule entre les deux moitiés de la
        ; séquence 0x70-0x7F) — calibration projection puis jp 0x1239 (remet
        ; (ix+00)=1, état générique).
        call    loc_1D84
        jp    loc_1239
fn_hud_slot_notification:
        ; Si var_object_notify_flag (#007A) est nul, RET immediat. Sinon l'efface,
        ; et pour 3 slots HUD (tbl_hud_slot_icons a #1877) : calcule la position
        ; ecran du slot, efface l'ancienne icone dans le buffer intermediaire,
        ; dessine la nouvelle si un type est present dans le slot.
        ld    a,(var_object_notify_flag)
        and    a
        ret    z
        xor    a
        ld    (var_object_notify_flag),a
loc_180B:
        push    ix
        ld    ix,#1877
        ld    b,#03
        ld    hl,tbl_hud_slot_icons
loc_1816:
        push    bc
        push    hl
        ld    a,b
        neg
        add    a,#03
        sla    a
        sla    a
        sla    a
        ld    c,a
        sla    a
        add    a,c
        add    a,#10
        ld    (ix+off_screen_x),a
        ld    (ix+off_screen_y),#00
        push    hl
        ld    l,(ix+off_screen_x)
        ld    a,(ix+off_screen_y)
        add    a,#17
        ld    h,a
        call    fn_buffer_addr_from_vram
        ld    bc,fn_render_workload_pacing_delay
        xor    a
        call    fn_fill_rect
        pop    hl
        ld    a,(hl)
        and    a
        jr    z,#184F
        ld    (ix+off_type),a
        call    loc_2F2B
        ld    c,(ix+off_screen_x)
        ld    a,(ix+off_screen_y)
        add    a,#17
        ld    b,a
        call    fn_screen_addr_from_bc
        ld    l,c
        ld    h,b
        call    fn_buffer_addr_from_vram
        ld    bc,#1806
        ld    a,(var_render_disabled_flag)
        and    a
        jr    nz,#186C
        call    fn_blit_copy_line
        pop    hl
        pop    bc
        inc    hl
        inc    hl
        inc    hl
        inc    hl
        djnz    loc_1816
        pop    ix
        ret
        ; non désassemblé
        defb #5D,#0D,#F0,#07,#00,#5B,#0D,#EF,#0C,#00,#00,#02,#C5,#0C,#C4,#0C
        defb #3A,#00,#02,#61,#0C,#01,#E8,#A0,#00,#00,#00,#00,#00,#00,#00,#00
fn_read_use_object_button:
        ; Teste un bit dédié de var_input_result (0x007B) pour le bouton "utiliser
        ; objet" — selon var_input_mode_flag bit1/bit3 (clavier vs joystick),
        ; applique ou non une rotation avant de tester bit4, pour compenser la
        ; différence d'agencement des bits entre scan clavier et scan joystick
        ld    hl,var_input_mode_flag
        ld    a,(hl)
        and    #02
        ld    a,(var_input_result)
        jr    z,#18A7
        bit    3,(hl)
        jr    z,#18A7
        rrca
        and    #10
        ret
fn_player_use_held_object:
        ; Teste var_transform_flag_and_saved_type puis fn_read_use_object_button ;
        ; si le bouton est presse et les gardes de collision/etat sont
        ; satisfaites, declenche l'usage de l'objet actuellement tenu (boost de
        ; hauteur ou depot, selon le contexte).
        ld    a,(#0079)
        and    a
        jp    nz,#1948
        call    fn_read_use_object_button
        ret    z
        call    fn_player_in_view_bounds
        ret    nc
        bit    3,(ix+off_cooldown_or_collision_flags)
        ret    nz
        bit    2,(ix+off_cooldown_or_collision_flags)
        ret    z
        xor    a
        ld    (#0097),a
        ld    a,(ix+off_grid_z_or_offset)
        ld    b,a
        add    a,#0C
        ld    (ix+off_grid_z_or_offset),a
        call    fn_probe_solid_support
        ld    (ix+off_grid_z_or_offset),b
        jr    nc,#18DD
        ld    a,#01
        ld    (#0097),a
        ld    hl,#0040
        call    loc_0A14
        ld    a,#01
        ld    (#0079),a
        ld    (var_object_notify_flag),a
        ld    b,#02
        ld    l,(ix+off_bbox_w)
        ld    a,l
        add    a,#04
        ld    (ix+off_bbox_w),a
        ld    h,(ix+off_bbox_h)
        ld    a,h
        add    a,#04
        ld    (ix+off_bbox_h),a
        push    hl
        ld    l,(ix+off_bbox_d)
        ld    a,l
        add    a,#04
        ld    (ix+off_bbox_d),a
        push    hl
        ld    iy,#010F
loc_190E:
        call    loc_1A11
        jp    c,#19E0
        ld    de,#001C
        add    iy,de
        djnz    loc_190E
        call    fn_read_use_object_button
        jr    z,loc_193C
        ld    b,#02
        ld    a,(ix+off_room_number)
        cp    #88
        jr    nz,#192B
        ld    b,#01
        ld    iy,#010F
        ld    de,#001C
loc_1932:
        ld    a,(iy+off_type)
        and    a
        jr    z,#1951
        add    iy,de
        djnz    loc_1932
loc_193C:
        pop    hl
        ld    (ix+off_bbox_d),l
        pop    hl
        ld    (ix+off_bbox_w),l
        ld    (ix+off_bbox_h),h
        ret
        call    fn_read_use_object_button
        ret    nz
        xor    a
        ld    (#0079),a
        ret
        ld    hl,#00B3
        ld    a,(hl)
        inc    hl
        and    a
        jr    z,#19CA
        ld    a,(#0097)
        and    a
        jr    nz,loc_193C
        dec    hl
        ld    a,(hl)
        inc    hl
        ld    (iy+off_type),a
        ld    a,(ix+off_room_number)
        cp    #88
        jr    nz,#197C
        ld    a,(ix+off_grid_z_or_offset)
        cp    #98
        jr    c,#197C
        set    3,(iy+off_type)
        ld    a,#01
        ld    (var_special_input_mode_2),a
        push    hl
        ld    bc,#0003
        push    ix
        pop    hl
        push    iy
        pop    de
        inc    de
        inc    hl
        ldir
        ld    a,(ix+off_grid_z_or_offset)
        add    a,#0C
        ld    (ix+off_grid_z_or_offset),a
        ld    a,(ix+off_room_transition_extra)
        add    a,#0C
        ld    (ix+off_room_transition_extra),a
        push    ix
        push    iy
        pop    ix
        call    fn_isometric_project
        pop    ix
loc_19A5:
        ld    (iy+off_bbox_w),#05
        ld    (iy+off_bbox_h),#05
        ld    (iy+off_bbox_d),#0C
        pop    hl
        ld    a,(hl)
        inc    hl
        ld    (iy+off_flags),a
        ld    a,(ix+off_room_number)
        ld    (iy+off_room_number),a
        ld    a,(hl)
        inc    hl
        ld    (iy+off_transform_step_counter),a
        ld    a,(hl)
        ld    (iy+#11),a
        set    0,(iy+off_state_flags_2)
        ld    hl,#00B2
        ld    de,#00B6
        ld    bc,#000C
        lddr
        ld    de,#00A7
        ld    b,#04
        call    fn_zero_fill_de
        jp    loc_193C
        ld    hl,#00A7
        xor    a
        ld    (var_room_reset_flag_5),a
        ld    a,(iy+off_type)
        ld    (hl),a
        inc    hl
        ld    a,(iy+off_flags)
        ld    (hl),a
        inc    hl
        ld    e,(iy+off_transform_step_counter)
        ld    d,(iy+#11)
        xor    a
        ld    (de),a
        ld    (hl),e
        inc    hl
        ld    (hl),d
        call    fn_herse_trigger_other
        ld    (iy+off_type),#01
        ld    hl,#00B3
        ld    a,(hl)
        inc    hl
        and    a
        jr    z,#19CA
        ld    (iy+off_type),a
        push    hl
        jr    loc_19A5
loc_1A11:
        ld    a,(iy+off_type)
        sub    #60
        cp    #07
        ret    nc
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
        jr    nc,#1A3E
        call    fn_aabb_axis_gap_y
        jr    nc,#1A3E
        ld    a,(ix+off_grid_z_or_offset)
        sub    #04
        ld    (ix+off_grid_z_or_offset),a
        call    fn_aabb_axis_gap_z
        push    af
        ld    a,(ix+off_grid_z_or_offset)
        add    a,#04
        ld    (ix+off_grid_z_or_offset),a
        pop    af
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
        jr    nc,#1A90
        set    3,(ix+off_type)
        call    loc_1D84
        ld    l,(ix+off_transform_step_counter)
        ld    h,(ix+#11)
        ld    (hl),#00
        ld    hl,var_life_counter
        inc    (hl)
        xor    a
        ld    (var_room_reset_flag_5),a
        ld    hl,#0040
        call    loc_0A14
        call    fn_hud_render_secondary_counter
        ld    bc,buf_visible_entities
        call    fn_hud_icon_redraw_8x4
        jp    loc_1D74
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
        call    loc_1D84
        ld    a,(ix+off_grid_x)
        sub    #80
        jr    z,#1AA4
        ld    a,#01
        jp    m,#1AA4
        neg
        ld    (ix+#09),a
        ld    a,(ix+off_grid_y)
        sub    #80
        jr    z,#1AB5
        ld    a,#01
        jp    m,#1AB5
        neg
        ld    (ix+#0A),a
        ld    a,(ix+off_grid_x)
        cp    #80
        jr    nz,#1AC4
        xor    (ix+off_grid_y)
        jr    z,fn_treasure_settle_ground_check
        ld    a,(ix+off_grid_z_or_offset)
        cp    #98
        ld    a,#01
        jr    nc,#1ACE
        inc    a
        ld    (ix+#0B),a
loc_1AD1:
        rst    #10
loc_1AD2:
        call    fn_position_pitch_sound_arm
        jp    loc_1F7B
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
        jr    nz,#1B05
        ld    hl,var_pickup_sequence_counter
        inc    (hl)
        call    fn_pickup_sequence_jingle
        ld    a,(var_pickup_sequence_counter)
        cp    #0E
        jr    nz,#1B05
        call    fn_pickup_sequence_complete_transform
        xor    a
        ld    (var_special_input_mode_2),a
        ld    l,(ix+off_transform_step_counter)
        ld    h,(ix+#11)
        ld    (hl),#00
        jp    loc_1239
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
        call    loc_1D84
        rst    #10
        bit    0,(ix+off_state_flags_2)
        jr    nz,#1B39
        call    fn_pending_vector_zero_test
        ret    z
        res    0,(ix+off_state_flags_2)
        call    loc_22A5
        jp    loc_1AD2
fn_pickup_sequence_jingle:
        ; Joue le flash de couleur Gate Array synchronise avec le son via
        ; fn_gate_array_config_stream, appelee a chaque etape validee du puzzle de
        ; collecte.
        ld    iy,struct_sound_channel_slot
        call    fn_sound_toggle_mixer_bit_b
        ld    d,#18
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
        dec    bc
        ld    a,b
        or    c
        jr    nz,#1B6B
        dec    d
        jr    nz,#1B4C
        jp    loc_0914
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
        call    loc_1F7B
        pop    de
        pop    bc
        ld    (ix+off_type),#01
        add    ix,de
        djnz    loc_1B86
        ld    bc,fn_boot_init_and_new_game
        ld    a,(ix+off_type)
        cp    #07
        jr    nz,#1BA3
        ld    (ix+off_type),#83
        add    ix,de
        push    ix
        pop    hl
        and    a
        sbc    hl,bc
        jr    c,#1B98
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
        call    loc_1F7B
        pop    ix
        call    loc_1D99
        jr    loc_1C04
fn_player_transform_tick:
        ; Dispatch logique des 4 types transitoires 0x5C-0x5F
        ; (tbl_entity_logic_dispatch). Choisit à chaque tick (throttlé 1 frame/4)
        ; un type transitoire pseudo-aléatoire parmi 0x5C-0x5F (jamais le même 2
        ; fois de suite), bascule bit 6 de (ix+07) (tremblement visuel),
        ; décrémente (ix+10); à 0, saute vers la complétion (0x1C24).
        call    loc_1D99
        bit    6,(ix+off_state_flags_2)
        jr    z,fn_player_transform_tick_pick_type
        ld    a,(var_special_input_mode_1)
        and    a
        jr    nz,fn_player_transform_tick_pick_type
        jp    loc_17CC
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
        jr    nz,#1C16
        xor    #01
        ld    (ix+off_type),a
        ld    a,(ix+off_flags)
        xor    #40
        ld    (ix+off_flags),a
        jp    loc_1F7B
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
        call    loc_1D89
        bit    5,(ix+off_type)
        jr    z,#1C41
        dec    (ix+off_proj_offset_y)
        jp    loc_1F7B
fn_hud_day_night_cycle:
        ; Anime le HUD soleil/lune (cycle jour/nuit), incrémente var_day_counter
        ; (0x007F) quand le cycle boucle.
        ld    a,(var_frame_counter)
        and    #07
        ret    nz
        ld    ix,var_day_night_flag
        inc    (ix+off_screen_x)
loc_1C51:
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
        call    loc_2F2B
        ld    ix,#1877
        ld    (ix+off_flags),#00
        ld    (ix+off_type),#5A
        ld    (ix+off_screen_x),#B0
        ld    (ix+off_screen_y),#00
        call    loc_2F2B
        ld    (ix+off_screen_x),#D0
        ld    (ix+off_type),#BA
        call    loc_2F2B
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
fn_catalog_randomize_types:
        ; LE VRAI randomiseur d'objets à ramasser (piste ouverte depuis plusieurs
        ; sessions). Pour chacune des 32 entrées de tbl_object_catalog: réécrit le
        ; TYPE (+0) avec 0x60 \| ((R + (0x0068) + i) & 7) (i = index d'entrée,
        ; rotation continue, pas un nouveau tirage R par entrée), PUIS copie le
        ; template figé (+1..+4: grid_x/y/z/room) vers la copie de travail
        ; (+5..+8, celle lue par fn_instantiate_room_objects). Appelée UNE FOIS
        ; par partie, juste après fn_init_room_selection (séquence de restart
        ; 0x0599-0x05A5).
        ld    hl,tbl_object_catalog
        ld    a,(var_newgame_random_seed)
        ld    e,a
        ld    a,r
        add    a,e
        ld    e,a
        ld    a,e
        and    #07
        or    #60
        ld    (hl),a
        inc    hl
        inc    e
        push    de
        ex    de,hl
        ld    hl,#0004
        add    hl,de
        ex    de,hl
        ld    bc,#0004
        ldir
        ex    de,hl
        push    hl
        ld    bc,tbl_sprite_dispatch
        and    a
        sbc    hl,bc
        pop    hl
        pop    de
        jr    c,#1D32
        ret
fn_pushable_block_logic:
        ; (salle 0xBB): logique du type d'entité 0x3E — "bloc poussable".
        ; Réutilise la calibration de projection du bloc statique 0x1D8F (même
        ; sprite EXACT que le type 0x07, 0x59DB), applique le vecteur de
        ; déplacement (RST 10) après avoir appelé 0x22A5 (arrêt net dès la fin du
        ; contact — même mécanisme que fn_pushable_table_logic/0x54), arme un son
        ; dont la hauteur dépend de la position (fn_position_pitch_sound_arm
        ; 0x0A07) si un vecteur est en cours. Confirmé visuellement ("blocs", 2
        ; instances empilées — delta grid_z=+0x0C, exactement l'élévation "sur la
        ; table" déjà confirmée ailleurs).
        call    loc_1D8F
        call    loc_22A5
        rst    #10
        call    fn_pending_vector_zero_test
        jp    z,loc_1F7B
        call    fn_position_pitch_sound_arm
        jp    loc_1F7B
fn_sliding_chest_logic:
        ; Logique des types d'entité 0x54 (table) et 0x55 (coffre) — TOUTES DEUX
        ; appliquent le déplacement courant via RST 10 SANS résoudre elles-mêmes
        ; un vecteur (le vecteur est rempli par le moteur de collision GÉNÉRIQUE
        ; suite à un contact avec le joueur). DIFFÉRENCE CLÉ (confirmée
        ; empiriquement room 0x6C): 0x54 (table) appelle ENSUITE CALL 0x22A5 qui
        ; annule immédiatement le vecteur — la table s'arrête dès que le contact
        ; cesse. 0x55 (coffre) N'appelle PAS 0x22A5 — le vecteur persiste, le
        ; coffre CONTINUE à glisser après la poussée, exactement "ils glissent
        ; tout seuls quand on les pousse, à la différence des tables". Une seule
        ; instruction de différence explique tout le comportement observé.
        call    loc_1D8F
        rst    #10
        call    fn_pending_vector_zero_test
        ret    z
        jp    loc_1AD2
fn_pushable_table_logic:
        ; Logique des types d'entité 0x54 (table) et 0x55 (coffre) — TOUTES DEUX
        ; appliquent le déplacement courant via RST 10 SANS résoudre elles-mêmes
        ; un vecteur (le vecteur est rempli par le moteur de collision GÉNÉRIQUE
        ; suite à un contact avec le joueur). DIFFÉRENCE CLÉ (confirmée
        ; empiriquement room 0x6C): 0x54 (table) appelle ENSUITE CALL 0x22A5 qui
        ; annule immédiatement le vecteur — la table s'arrête dès que le contact
        ; cesse. 0x55 (coffre) N'appelle PAS 0x22A5 — le vecteur persiste, le
        ; coffre CONTINUE à glisser après la poussée, exactement "ils glissent
        ; tout seuls quand on les pousse, à la différence des tables". Une seule
        ; instruction de différence explique tout le comportement observé.
        call    loc_1D8F
loc_1D74:
        rst    #10
        call    fn_pending_vector_zero_test
        ret    z
        call    loc_22A5
        jp    loc_1AD2
fn_static_calib_vector_table:
        ; RESOUT le dernier type sans logique tracee de tbl_entity_logic_dispatch
        ; (audit complet 2026-08-14 des 188 entrees). 13 mini-routines
        ; consecutives de forme LD HL,nn / JR #1D8C (le tail commun, qui ecrit HL
        ; dans off_proj_offset_x/off_proj_offset_y via la meme queue que
        ; fn_door_post_type_A/B, #1FEB) -- exactement le meme mecanisme de
        ; calibration statique deja identifie pour les portes et les blocs. Type
        ; 0x80 (type_wall_segment) dispatche sur la toute PREMIERE entree (#1D7F
        ; elle-meme) ; les entrees suivantes (#1D84..#1DBC) sont reutilisees par
        ; d'autres dispatchs deja nommes ailleurs (blocs statiques 0x0A-0x0F,
        ; blocs poussables/table via #1D8F, etc.) OU par le HUD jour/nuit (voir
        ; #1DB2, meme table, 11e entree). Se termine juste avant fn_fill_rect
        ; (#1DC1).
        ld    hl,#FEF8
        jr    loc_1D8C
loc_1D84:
        ld    hl,#FCF4
        jr    loc_1D8C
loc_1D89:
        ld    hl,#FAF4
loc_1D8C:
        jp    loc_1FEB
loc_1D8F:
        ld    hl,#F8F0
        jr    loc_1D8C
        ld    hl,#FFEC
        jr    loc_1D8C
loc_1D99:
        ld    hl,#FEF4
        jr    loc_1D8C
loc_1D9E:
        ld    hl,#FCF8
        jr    loc_1D8C
loc_1DA3:
        ld    hl,#F8F4
        jr    loc_1D8C
loc_1DA8:
        ld    hl,#F9F4
        jr    loc_1D8C
loc_1DAD:
        ld    hl,#F4F4
        jr    loc_1D8C
loc_1DB2:
        ld    hl,#F4F0
        jr    loc_1D8C
loc_1DB7:
        ld    hl,#07F4
        jr    loc_1D8C
loc_1DBC:
        ld    hl,#03F4
        jr    loc_1D8C
fn_fill_rect:
        ; Effacement/remplissage rectangulaire par loop unrolling
        push    af
        ld    a,b
        neg
        and    #0F
        add    a,a
        ld    (#1DD6),a
        ld    a,#40
        add    a,b
        neg
        ld    e,a
        ld    d,#FF
        ld    b,c
        pop    af
loc_1DD5:
        jr    loc_1DD5
        ld    (hl),a
        inc    hl
        ld    (hl),a
        inc    hl
        ld    (hl),a
        inc    hl
        ld    (hl),a
        inc    hl
        ld    (hl),a
        inc    hl
        ld    (hl),a
        inc    hl
        ld    (hl),a
        inc    hl
        ld    (hl),a
        inc    hl
        ld    (hl),a
        inc    hl
        ld    (hl),a
        inc    hl
        ld    (hl),a
        inc    hl
        ld    (hl),a
        inc    hl
        ld    (hl),a
        inc    hl
        ld    (hl),a
        inc    hl
        ld    (hl),a
        inc    hl
        ld    (hl),a
        inc    hl
        add    hl,de
        djnz    loc_1DD5
        ret
fn_instantiate_room_objects:
        ; (était hypothesis): scanne tbl_object_catalog (32 entrées), instancie
        ; dans les slots d'entité 2 et 3 (0x010F/0x012B, juste après les 2
        ; templates joueur/compagnon) chaque entrée dont le champ room (+8, copie
        ; de travail) correspond à la salle courante. Au plus 2 objets par salle
        ; (place limitée entre 0x010F et 0x0147 = tbl_room_connections).
        ld    de,#010F
        exx
        ld    iy,tbl_object_catalog
        ld    b,(ix+off_room_number)
        ld    a,(iy+off_type)
        and    a
        jr    z,#1E48
        ld    a,(iy+off_room_number)
        cp    b
        jr    nz,#1E48
        push    iy
        exx
        pop    hl
        push    hl
        ld    a,(hl)
        inc    hl
        ld    (de),a
        inc    de
        inc    hl
        inc    hl
        inc    hl
        inc    hl
        ld    bc,#0003
        ldir
        ex    de,hl
        ld    (hl),#05
        inc    hl
        ld    (hl),#05
        inc    hl
        ld    (hl),#0C
        inc    hl
        ld    (hl),#14
        inc    hl
        ex    de,hl
        ld    a,(hl)
        inc    hl
        ld    (de),a
        inc    de
        ld    b,#07
        call    fn_zero_fill_de
        pop    bc
        ld    a,c
        ld    (de),a
        inc    de
        ld    a,b
        ld    (de),a
        inc    de
        ld    b,#0A
        call    fn_zero_fill_de
        exx
        ld    de,#0009
        add    iy,de
        push    iy
        pop    hl
        ld    de,tbl_sprite_dispatch
        and    a
        sbc    hl,de
        jr    c,#1E06
        exx
loc_1E59:
        ld    hl,tbl_room_connections
        and    a
        sbc    hl,de
        ret    z
        ld    b,#1C
        call    fn_zero_fill_de
        jr    loc_1E59
fn_object_catalog_writeback:
        ; Appelée depuis fn_init_room (#2A68) UNIQUEMENT si
        ; var_room_transition_flag (#0078) != 0 (donc jamais au tout premier
        ; lancement, seulement lors d'une transition/réinit de salle). Parcourt
        ; les slots d'entité 2 et 3 (#010F/#012B): si le type courant (iy+00) est
        ; dans [#60,#66] (famille pickup "boule de cristal", PAS #BB collecté ni
        ; #67 bonus vie), écrit en retour, via le pointeur (iy+10)/(iy+11) — qui
        ; pour CES slots contient l'adresse de LEUR PROPRE entrée dans
        ; tbl_object_catalog, posée par fn_instantiate_room_objects (#1DFB,
        ; #1E3B-#1E41) — le type courant (offset+0), puis grid_x/grid_y/grid_z
        ; courants (iy+1..3 → catalogue+5..7), puis le champ room (iy+08 →
        ; catalogue+8). Effet: si l'objet est TOUJOURS non ramassé au moment de
        ; quitter la salle, son état courant est resynchronisé dans la copie de
        ; travail du catalogue; s'il est déjà ramassé (type devenu #BB via
        ; fn_collision_effect), il est SAUTÉ — donc le catalogue garde le dernier
        ; état synchronisé AVANT ramassage, pas après. Conséquence testable non
        ; vérifiée en jeu: revisiter une salle après avoir ramassé un objet
        ; #60-#66 ferait probablement réapparaître l'objet (aucune écriture ne
        ; persiste l'état "ramassé" vers le catalogue) — hypothèse dérivée de ce
        ; désassemblage, pas encore confirmée empiriquement. Confirme au passage
        ; le double rôle de off_transform_step_counter (+0x10/+0x11): pour
        ; l'entité 0 (joueur), compteur de sous-étapes de transformation; pour les
        ; entités objets (slots 2/3), pointeur 16 bits vers leur propre entrée
        ; tbl_object_catalog. Voir include/entity_struct.equ.asm.
        ld    iy,#010F
        ld    a,(iy+off_type)
        sub    #60
        cp    #07
        jr    nc,#1E90
        ld    e,(iy+off_transform_step_counter)
        ld    d,(iy+#11)
        ld    a,(iy+off_type)
        ld    (de),a
        inc    de
        inc    de
        inc    de
        inc    de
        inc    de
        push    iy
        pop    hl
        inc    hl
        ld    bc,#0003
        ldir
        ld    a,(iy+off_room_number)
        ld    (de),a
        ld    bc,#001C
        add    iy,bc
        push    iy
        pop    hl
        ld    bc,tbl_room_connections
        and    a
        sbc    hl,bc
        jr    c,#1E6B
        ret
fn_ghost_wander_logic:
        ; Logique des types d'entité 0x50-0x53 (fantôme) — déplacement ALÉATOIRE
        ; (PAS un rebond déterministe comme les autres entités mobiles): quand le
        ; vecteur (ix+09)/(ix+0A) est épuisé OU qu'une collision est détectée sur
        ; (ix+0C)&3, tire un NOUVEAU vecteur aléatoire, puis appelle
        ; fn_ghost_orientation_toggle. "un fantôme" avec déplacement erratique
        ; observé par poll RAM (changements de vecteur fréquents et
        ; imprévisibles). DU CYCLE JOUR/NUIT: aucune référence à (0x1CFA) ou
        ; (0x00D7) dans le code de la routine, ET comportement/cadence/apparence
        ; identiques observés sous forme jour (joueur type 0x12) et nuit (type
        ; 0x32). Complète la taxonomie des ennemis mobiles (3e catégorie:
        ; "déplacement aléatoire").
        call    loc_1D89
        rst    #10
        ld    a,(ix+#09)
        or    (ix+#0A)
        jr    z,#1EB4
        ld    a,(ix+off_cooldown_or_collision_flags)
        and    #03
        jr    z,#1ED4
        ld    a,(var_pseudo_random_acc)
        and    #03
        add    a,#04
        call    fn_signed_step_lookup
        ld    (ix+#09),a
        ld    a,(var_frame_counter)
        and    #03
        add    a,#04
        call    fn_signed_step_lookup
        ld    (ix+#0A),a
        call    fn_ghost_orientation_toggle
        call    fn_position_pitch_sound_arm
        call    fn_animation_cycle_4
        jp    loc_1139
fn_ghost_orientation_toggle:
        ; Appelee par fn_ghost_wander_logic (#1ECE). Compare |vecteur X| et
        ; |vecteur Y| (ix+09/0A), prend l'axe dominant, et selon son signe bascule
        ; bit1 du type (0x50<->0x51 ou 0x52<->0x53) ET bit6 des flags
        ; (orientation, voir fn_get_orientation_code) -- oriente visuellement le
        ; fantome selon sa direction de deplacement aleatoire.
        ld    a,(ix+#09)
        and    a
        jp    p,#1EE3
        neg
        ld    c,a
        ld    a,(ix+#0A)
        and    a
        jp    p,#1EED
        neg
        cp    c
        jr    nc,fn_ghost_orientation_toggle_y
        ld    a,(ix+#09)
        and    a
        jp    m,fn_ghost_orientation_toggle_negx
        res    1,(ix+off_type)
loc_1EFB:
        set    6,(ix+off_flags)
        ret
fn_ghost_orientation_toggle_negx:
        ; Branche axe X dominant et negatif de fn_ghost_orientation_toggle
        ; (#1EDA): SET bit1 du type, rejoint la queue commune (#1EFB, SET bit6 des
        ; flags).
        set    1,(ix+off_type)
        jr    loc_1EFB
fn_ghost_orientation_toggle_y:
        ; Branche axe Y dominant de fn_ghost_orientation_toggle (#1EDA): selon le
        ; signe, SET ou RES bit1 du type, rejoint la queue commune RES bit6 des
        ; flags (#1F11).
        ld    a,(ix+#0A)
        and    a
        jp    m,fn_ghost_orientation_toggle_negy
        set    1,(ix+off_type)
loc_1F11:
        res    6,(ix+off_flags)
        ret
fn_ghost_orientation_toggle_negy:
        ; Sous-branche negative de fn_ghost_orientation_toggle_y (#1F06): RES bit1
        ; du type, rejoint la queue RES bit6 des flags (#1F11).
        res    1,(ix+off_type)
        jr    loc_1F11
fn_signed_step_lookup:
        ; BC=tbl_signed_step_pairs (#1F25), HL=BC+A, retourne (HL) -- petit helper
        ; de lookup, utilise par fn_ghost_wander_logic pour convertir
        ; (pseudo_random_acc&3)+4 ou (frame_counter&3)+4 en une valeur signee via
        ; la table adjacente.
        ld    bc,tbl_signed_step_pairs
        ld    l,a
        ld    h,#00
        add    hl,bc
        ld    a,(hl)
        ret
tbl_signed_step_pairs:
        ; 8 paires de vecteurs signes (dx,dy), indexees par fn_signed_step_lookup
        ; pour un deplacement aleatoire (fantomes).
        defb #FF,#01,#FE,#02,#FD,#03,#FC,#04,#FB,#05,#FA,#06,#F9,#07,#F8,#08
fn_herse_type08_logic:
        ; RÉSOUT le type d'entité 0x08, qui partage le sprite de la herse 0x09
        ; mais dont la logique n'avait jamais été localisée avant. Calibration
        ; puis, si un flag de collision est posé, nettoie
        ; cooldown_or_collision_flags et arme un son (fn_sound_arm_channel_0).
        ; Puis piège à déclenchement pseudo-aléatoire (~3%/tick, même famille que
        ; fn_ceiling_spike_ball_logic) verrouillé par var_room_reset_flag_1 ("un
        ; seul à la fois", même rôle que var_room_reset_flag_4 pour les boules à
        ; pics): selon que l'entité est proche du sol ou nettement au-dessus,
        ; déclenche directement (fn_herse_type08_ground_trigger #1F96) ou accumule
        ; dans var_room_reset_flag_2 (comparé à 4) avant de tirer. Au succès: bit0
        ; du type posé, (ix+0B) = direction de "chute" (±1), bits4/5 des flags
        ; posés, verrou var_room_reset_flag_1 incrémenté, puis JP #25FF
        ; (mouvement/animation, hors zone). Fn_herse_trigger_other (#1F86) permet
        ; de déclencher cet effet sur une entité IY différente de l'entité
        ; courante.
        call    loc_1D89
        ld    a,(ix+off_cooldown_or_collision_flags)
        bit    2,a
        jr    z,#1F4A
        and    #F8
        ld    (ix+off_cooldown_or_collision_flags),a
        ld    hl,tbl_sound_descriptor_noise_decay
        call    fn_sound_arm_channel_0
        ld    hl,var_room_reset_flag_1
        ld    a,(hl)
        and    a
        ret    nz
        ld    a,(var_room_data_field_2)
        cp    (ix+off_grid_z_or_offset)
        jr    z,fn_herse_type08_ground_trigger
        add    a,#1F
        cp    (ix+off_grid_z_or_offset)
        jr    nc,fn_herse_type08_ground_trigger
        ld    a,(var_room_reset_flag_2)
        cp    #04
        jr    c,#1F6E
        ld    a,(var_pseudo_random_acc)
        and    #1F
        ret    nz
        or    #80
        inc    a
        ld    (var_room_reset_flag_2),a
        set    0,(ix+off_type)
        ld    (ix+#0B),#FF
loc_1F7A:
        inc    (hl)
loc_1F7B:
        ld    a,(ix+off_flags)
        or    #30
        ld    (ix+off_flags),a
        jp    fn_entity_fall_and_mark_overlap
fn_herse_trigger_other:
        ; Echange IX/IY (IY devient la cible), CALL #1F7B (queue commune de
        ; declenchement de chute de fn_herse_type08_logic), restaure IX/IY --
        ; permet a une autre routine de declencher l'effet de chute sur une ENTITE
        ; DIFFERENTE de celle courante (IY), sans dupliquer le code.
        push    iy
        push    ix
        push    iy
        pop    ix
        call    loc_1F7B
        pop    ix
        pop    iy
        ret
fn_herse_type08_ground_trigger:
        ; Branche 'pres du sol' de fn_herse_type08_logic (#1F35, atteinte via jr
        ; z/jr nc depuis #1F56/#1F5D): tire immediatement (1/32 via
        ; var_pseudo_random_acc&0x1F, sans passer par le compteur
        ; var_room_reset_flag_2); au succes, (ix+0B)=1 (chute vers le HAUT, signe
        ; oppose de la branche #1F6E qui utilise 0xFF) puis rejoint la queue
        ; commune #1F7A.
        ld    a,(var_pseudo_random_acc)
        and    #1F
        ret    nz
        set    0,(ix+off_type)
        ld    (ix+#0B),#01
        jr    loc_1F7A
fn_moving_grate_logic:
        ; Logique du type d'entité 0x09 (grille mobile qui monte/descend) —
        ; oscille via un compteur de phase (ix+0B) signé (positif/négatif),
        ; déplacement appliqué par RST 10 (rst_apply_movement_vector). Bornes de
        ; l'oscillation déterminées par (0x0074)+0x1F comparé à grid_z_or_offset
        ; (ix+03). "une grille au milieu qui monte et descend".
        call    loc_1D89
        set    7,(ix+off_state_flags_2)
        ld    a,(#00E3)
        and    #F0
        ret    nz
        ld    a,(ix+#0B)
        and    a
        jp    p,#1FCE
        dec    (ix+#0B)
        rst    #10
        bit    2,(ix+off_cooldown_or_collision_flags)
        jr    z,loc_1F7B
loc_1FC4:
        xor    a
        ld    (var_room_reset_flag_1),a
        res    0,(ix+off_type)
        jr    loc_1F7B
        ld    (ix+#0B),#02
        call    fn_position_pitch_sound_arm
        rst    #10
        ld    a,(var_room_data_field_2)
        add    a,#1F
        cp    (ix+off_grid_z_or_offset)
        jr    nc,loc_1F7B
        jr    loc_1FC4
fn_door_post_type_B:
        ; Logique des types d'entité 0x02/0x03 (montants de porte) — quasi-
        ; identiques (variante A/B pour les deux montants d'une même porte).
        ; Recalibrent les offsets de projection selon l'orientation courante (bit
        ; 6 de ix+07), calculent un point de test décalé (±13 unités selon
        ; l'axe/orientation), puis appellent fn_door_proximity_test (0x208F) et
        ; fn_door_proximity_test_2 (0x2045).
        bit    6,(ix+off_flags)
        jr    nz,fn_door_post_type_B_flag_variant
        ld    hl,#FDF7
loc_1FEB:
        ld    (ix+off_proj_offset_x),l
        ld    (ix+off_proj_offset_y),h
        ret
fn_door_post_type_B_flag_variant:
        ; Branche de fn_door_post_type_B (#1FE2) prise quand bit6 de flags est
        ; ACTIF (jr nz,#1FF2 en #1FE6): LD HL,#FEF9 puis JR vers la queue commune
        ; d'ecriture proj_offset_x/y (#1FEB, deja disassemblee dans
        ; fn_door_post_type_B) -- meme mecanisme que la branche par defaut
        ; (HL=#FDF7) mais avec un decalage de calibration different.
        ld    hl,#FEF9
        jr    loc_1FEB
fn_door_post_type_A_type4_variant:
        ; Variante de fn_door_post_type_A specifique au type d'entite 4 (flag
        ; different pose sur l'entite).
        ld    hl,#FD01
        jr    loc_200C
fn_door_post_type_A:
        ; Logique des types d'entité 0x02/0x03 (montants de porte) — quasi-
        ; identiques (variante A/B pour les deux montants d'une même porte).
        ; Recalibrent les offsets de projection selon l'orientation courante (bit
        ; 6 de ix+07), calculent un point de test décalé (±13 unités selon
        ; l'axe/orientation), puis appellent fn_door_proximity_test (0x208F) et
        ; fn_door_proximity_test_2 (0x2045).
        bit    6,(ix+off_flags)
        jr    nz,fn_door_post_type_A_flag_variant
        ld    a,(ix+off_type)
        cp    #04
        jr    z,fn_door_post_type_A_type4_variant
        ld    hl,#FDF9
loc_200C:
        call    loc_1FEB
        ld    a,(ix+off_grid_y)
        add    a,#0D
        ld    (ix+#0A),a
        ld    a,(ix+off_grid_x)
        ld    (ix+#09),a
        ld    hl,#060F
loc_2020:
        ld    a,(ix+off_grid_z_or_offset)
        ld    (ix+#0B),a
        call    fn_door_proximity_test
        jp    fn_door_proximity_test_2
fn_door_post_type_A_flag_variant:
        ; Variante de poteau de porte (type A) qui pose un flag different selon le
        ; contexte d'appel.
        ld    hl,#FEEF
        call    loc_1FEB
        ld    a,(ix+off_grid_x)
        sub    #0D
        ld    (ix+#09),a
        ld    a,(ix+off_grid_y)
        ld    (ix+#0A),a
        ld    hl,#0F06
        jr    loc_2020
fn_door_proximity_test_2:
        ; Second test de proximité joueur (même garde IY=0x00D7), dispatch par
        ; orientation (table 0x2061, via fn_get_orientation_code) pour ajuster
        ; finement (iy+0E)/(iy+0F) du joueur — raffinement du glissement à travers
        ; l'ouverture.
        ld    hl,#0F0F
        ld    iy,struct_entities_base
        ld    a,(iy+off_type)
        and    a
        ret    z
        bit    3,(iy+off_flags)
        ret    z
        call    fn_aabb_distance_test
        ret    nc
        push    bc
        ld    bc,tbl_door_proximity_fine_adjust_dispatch
        jp    loc_22C9
tbl_door_proximity_fine_adjust_dispatch:
        ; 4 entrees word, dispatch par axe/sens vers fn_door_fine_adjust_x/y.
        defw #2069
        defw #2069
        defw #207C
        defw #207C
fn_door_fine_adjust_y:
        ; Corrige la position Y de l'entite pour l'aligner avec le passage de
        ; porte avant le franchissement.
        ld    a,(ix+#0A)
        cp    (iy+off_grid_y)
        jr    z,loc_208D
        ld    a,#01
        jr    nc,#2077
        neg
        ld    (iy+#0F),a
        jr    loc_208D
fn_door_fine_adjust_x:
        ; Corrige la position X de l'entite pour l'aligner avec le passage de
        ; porte avant le franchissement.
        ld    a,(ix+#09)
        cp    (iy+off_grid_x)
        jr    z,loc_208D
        ld    a,#01
        jr    nc,#208A
        neg
        ld    (iy+#0E),a
loc_208D:
        pop    bc
        ret
fn_door_proximity_test:
        ; IY fixé en dur à 0x00D7 (= le JOUEUR, pas une boucle générique). Teste
        ; si le joueur est dans la bbox de test AABB (3 axes, seuil <4, via
        ; fn_aabb_distance_test 0x20A6); si oui, POSE le bit 0 des flags DU JOUEUR
        ; (ix+07) — signal "porte franchie" consommé par fn_player_door_transition
        ; (0x2322).
        ld    iy,struct_entities_base
        ld    a,(iy+off_type)
        and    a
        ret    z
        bit    3,(iy+off_flags)
        ret    z
        call    fn_aabb_distance_test
        ret    nc
        set    0,(iy+off_flags)
        ret
fn_aabb_distance_test:
        ; Test de distance générique 3 axes entre (ix+09/0A/0B) [point de test
        ; d'une porte] et (iy+01/02/03) [position d'une entité, ici toujours le
        ; joueur] — |dx|<L, |dy|<H, |dz|<4.
        ld    a,(ix+#09)
        sub    (iy+off_grid_x)
        jr    nc,#20B0
        neg
        cp    l
        ret    nc
        ld    a,(ix+#0A)
        sub    (iy+off_grid_y)
        jr    nc,#20BC
        neg
        cp    h
        ret    nc
        ld    a,(ix+#0B)
        sub    (iy+off_grid_z_or_offset)
        jr    nc,#20C8
        neg
        cp    #04
        ret
fn_player_logic:
        ; Entrée JOUR/HÉROS (types 0x12/0x14, vérifié par lecture directe de
        ; tbl_entity_logic_dispatch[0x12]=tbl_entity_logic_dispatch[0x14]=#20CB):
        ; CALL #1D89 (calibration proj_offset_x/y, une des stubs de la famille
        ; "calibration seule" déjà connue via fn_door_post_type_A/B/0x1FEB —
        ; CORROBORE, sans la résoudre à elle seule, l'hypothèse déjà posée sur les
        ; types murs 0x0A-0x0F: même famille de stub générique LD HL,offset / JP
        ; #1FEB, réutilisée ici pour le joueur) puis JR #20D3 vers le corps
        ; partagé — voir fn_player_logic_night (#20D0) pour l'entrée NUIT/LOUP-
        ; GAROU qui y tombe par fall-through. Corps partagé (logique complète du
        ; joueur, une fois par frame): si bit6 de state_flags_2 posé (et
        ; var_special_input_mode_1 #0089 nul) → jump direct vers la séquence de
        ; matérialisation (#17CC, pose bit6 des flags de l'entité jambes companion
        ; via (ix+0x29) = entité[1]+0x0D); sinon CALL fn_player_transform_trigger,
        ; fn_read_input, fn_player_use_held_object, fn_player_read_input
        ; (rotation), fn_player_jump_trigger (#21F0),
        ; fn_player_walk_animation_cycle (#2214), fn_player_in_view_bounds
        ; (culling); si dans le champ: busy_flag bit1 posé autour de CALL
        ; fn_player_gravity_and_door_dispatch (#2253), puis décrémente
        ; cooldown_timer par pas de 0x10; enchaîne sur JP #1F7B (calibration
        ; partagée générique).
        call    loc_1D89
        jr    loc_20D3
fn_player_logic_night:
        ; Entrée NUIT/LOUP-GAROU (types 0x32/0x34,
        ; tbl_entity_logic_dispatch[0x32]=tbl_entity_logic_dispatch[0x34]=#20D0)
        ; de fn_player_logic: CALL #1DA8 (calibration différente pour la forme
        ; nocturne) puis fall-through direct dans le corps partagé #20D3 — voir
        ; #20CB pour le détail complet du corps partagé
        call    loc_1DA8
loc_20D3:
        bit    6,(ix+off_state_flags_2)
        jr    z,fn_player_logic_active_body
        ld    a,(var_special_input_mode_1)
        and    a
        jr    nz,fn_player_logic_active_body
        set    6,(ix+#29)
        jp    loc_17CC
fn_player_logic_active_body:
        ; Corps partage de fn_player_logic/fn_player_logic_night (#20CB/#20D0)
        ; quand PAS de materialisation en cours (cible des deux JR/JR NZ vers
        ; #20E6 en #20D7/#20DD): CALL fn_player_transform_trigger (#1BB0),
        ; fn_read_input (#28B7), fn_player_use_held_object (#18AA),
        ; fn_player_read_input (#2147, rotation/avance), fn_player_jump_trigger
        ; (#21F0), fn_player_walk_animation_cycle (#2214), puis
        ; fn_player_in_view_bounds (#2122). Contrairement a ce qui etait suppose,
        ; fn_player_gravity_and_door_dispatch (#2253) est TOUJOURS appelee, meme
        ; hors-champ (JR NC,#2115 ne 'saute' pas la gravite/porte, il route juste
        ; vers un traitement different du compteur de chute (ix+0B) avant de la
        ; meme facon poser busy_flag bit1 (#20FD) autour du CALL #2253): si le
        ; joueur est hors-champ ET n'est pas deja en train de tomber ((ix+0B) non
        ; negatif), le compteur de chute est force a 0 (#211C-#211F) avant de
        ; rejoindre #20FD; s'il est deja negatif (en chute), #20FD est rejoint
        ; directement SANS toucher au compteur. Dans tous les cas: busy_flag bit1
        ; pose, CALL #2253, busy_flag bit1 efface, (ix+0C) -= #10 (sans
        ; souscription si carry), puis JP #1F7B (calibration partagee generique).
        call    fn_player_transform_trigger
        call    fn_read_input
        call    fn_player_use_held_object
        call    fn_player_read_input
        call    fn_player_jump_trigger
        call    fn_player_walk_animation_cycle
        call    fn_player_in_view_bounds
        jr    nc,fn_player_logic_view_bounds_tail
loc_20FD:
        set    1,(ix+off_busy_flag)
        call    fn_player_gravity_and_door_dispatch
        res    1,(ix+off_busy_flag)
        ld    a,(ix+off_cooldown_or_collision_flags)
        sub    #10
        jr    c,#2112
        ld    (ix+off_cooldown_or_collision_flags),a
        jp    loc_1F7B
fn_player_logic_view_bounds_tail:
        ; Cible de JR NC,#2115 dans fn_player_logic_active_body (#20E6, quand
        ; fn_player_in_view_bounds #2122 retourne 'hors champ'): si
        ; (ix+off_cooldown_or_collision_flags interprete comme compteur signe,
        ; ix+0B) est deja negatif (en chute), rejoint #20FD SANS y toucher; sinon
        ; le force a 0 avant de rejoindre #20FD (busy_flag bit1, CALL
        ; fn_player_gravity_and_door_dispatch #2253, etc -- voir
        ; fn_player_logic_active_body).
        ld    a,(ix+#0B)
        and    a
        jp    m,loc_20FD
        xor    a
        ld    (ix+#0B),a
        jr    loc_20FD
fn_player_in_view_bounds:
        ; Teste si (grid_x,grid_y) - bbox_w/h reste dans
        ; [var_camera_reference..+0xFF] sur les 2 axes (comparaison signée via NEG
        ; après soustraction de 0x80) — retourne CARRY clear si hors champ.
        ; Consommée par fn_player_logic pour sauter la logique de porte/gravité
        ; quand le joueur est hors-vue
        ld    hl,(var_camera_reference)
        ld    a,l
        sub    (ix+off_bbox_w)
        ld    l,a
        ld    a,h
        sub    (ix+off_bbox_h)
        ld    h,a
        ld    a,(ix+off_grid_x)
        sub    #80
        jp    p,#2139
        neg
        cp    l
        ret    nc
        ld    a,(ix+off_grid_y)
        sub    #80
        jp    p,#2145
        neg
        cp    h
        ret
fn_player_read_input:
        ; Lit var_input_result (#007B), resout la direction en vecteur via un
        ; cooldown base sur cooldown_timer.
        ld    hl,var_input_mode_flag
        ld    a,(hl)
        and    #02
        jr    z,fn_player_rotate_or_advance_tail
        bit    3,(hl)
        jr    z,fn_player_rotate_or_advance_tail
        ld    a,(ix+off_cooldown_or_collision_flags)
        and    #F0
        ret    nz
        bit    2,(ix+off_cooldown_or_collision_flags)
        ret    z
        bit    0,c
        jr    nz,#2166
        bit    2,c
        jr    nz,fn_player_orient_dispatch_bit2
        bit    1,c
        jr    nz,fn_player_orient_dispatch_bit1
        bit    4,c
        jr    nz,fn_player_orient_dispatch_bit4
        bit    0,c
        jr    nz,fn_player_orient_dispatch_bit0
        res    2,c
        ret
fn_player_orient_dispatch_bit2:
        ; Sous-branche de fn_player_read_input (#2147), atteinte si bit2 de C (une
        ; des 4 directions pressees, resultat de fn_read_input) est actif. CALL
        ; fn_get_orientation_code (#22D0); CP #02; si egal -> JR Z vers
        ; fn_player_orient_aligned_exit (#2197, deja face a cette direction).
        ; Sinon CPL puis AND #01 (isole un bit de 'sens de rotation' a partir du
        ; code d'orientation complemente), puis JR vers le milieu de
        ; fn_player_rotate_or_advance_tail (#21C7) pour appliquer la rotation.
        ; Design tres dense: les branches soeurs (#2181/#2188/#2191) sautent au
        ; MILIEU de cette meme instruction JR Z (#217A) ou de l'AND #01 (#217D)
        ; pour reutiliser le flag Z/le calcul deja fait par LEUR PROPRE CP --
        ; verifie octet par octet hors-ligne + contre RAM live.
        call    fn_get_orientation_code
        cp    #02
loc_217A:
        jr    z,fn_player_orient_aligned_exit
        cpl
loc_217D:
        and    #01
        jr    loc_21C7
fn_player_orient_dispatch_bit1:
        ; Sous-branche de fn_player_read_input, atteinte si bit1 de C est actif.
        ; CALL fn_get_orientation_code; CP #01; JR vers #217A (l'instruction JR Z
        ; partagee de fn_player_orient_dispatch_bit2, #2175) qui teste le flag Z
        ; issu de CETTE comparaison -- egal -> aligne (#2197), sinon tombe dans le
        ; CPL/AND1/JR partage (#217C).
        call    fn_get_orientation_code
        cp    #01
        jr    loc_217A
fn_player_orient_dispatch_bit4:
        ; Sous-branche de fn_player_read_input, atteinte si bit4 de C est actif.
        ; CALL fn_get_orientation_code; CP #03; JR Z vers
        ; fn_player_orient_aligned_exit (#2197) si egal; sinon JR vers #217D
        ; (version SANS CPL, juste AND #01, partagee avec
        ; fn_player_orient_dispatch_bit0 #2191) puis rejoint la queue de rotation
        ; (#21C7).
        call    fn_get_orientation_code
        cp    #03
loc_218D:
        jr    z,fn_player_orient_aligned_exit
        jr    loc_217D
fn_player_orient_dispatch_bit0:
        ; Sous-branche de fn_player_read_input, atteinte si bit0 de C est actif
        ; (teste en second, apres bit2 -- meme bit que
        ; fn_player_orient_dispatch_bit2 mais chemin d'entree different, cf le
        ; chainage de BIT/JR NZ juste avant #2175 dans fn_player_read_input). CALL
        ; fn_get_orientation_code; AND A (compare implicitement a 0); JR vers
        ; #218D (l'instruction JR Z partagee de fn_player_orient_dispatch_bit4,
        ; #2188) qui reteste ce meme flag Z -- egal -> aligne (#2197), sinon tombe
        ; dans #218F puis #217D (AND1 partage).
        call    fn_get_orientation_code
        and    a
        jr    loc_218D
fn_player_orient_aligned_exit:
        ; Sortie commune aux 4 branches fn_player_orient_dispatch_bit0/1/2/4 quand
        ; la direction pressee correspond DEJA a l'orientation courante du joueur
        ; (code retourne par fn_get_orientation_code egal a la valeur attendue par
        ; la branche): SET bit2,C puis RET -- signale a l'appelant
        ; (fn_player_logic, via le retour de C) qu'il faut avancer tout droit,
        ; sans repasser par une rotation.
        set    2,c
        ret
fn_player_rotate_or_advance_tail:
        ; Point d'entree direct depuis le tout debut de fn_player_read_input
        ; (#214D/#2151, jr #219A) quand var_input_mode_flag bit1 OU bit3 est a 0:
        ; decremente le cooldown de rotation state_flags_2&7 (ix+0D) tant qu'il
        ; est non nul (RET immediat); une fois a 0, tombe dans
        ; fn_player_rotate_apply (#21A5).
        ld    a,(ix+off_state_flags_2)
        and    #07
        jr    z,fn_player_rotate_apply
        dec    (ix+off_state_flags_2)
        ret
fn_player_rotate_apply:
        ; Corps commun de la logique de rotation, avec DEUX points d'entree. (1)
        ; Fallthrough depuis fn_player_rotate_or_advance_tail (#219A, cooldown
        ; ix+0D ecoule): teste C&3 (RET si aucun des 2 bits bas actif), puis re-
        ; gate sur cooldown_or_collision_flags (ix+0C, bits4-7 et bit3, RET si
        ; occupe). (2) Entree en plein milieu (#21C7) depuis les branches
        ; fn_player_orient_dispatch_* (#2175-#2191) quand bit1 ET bit3 de
        ; var_input_mode_flag sont actifs mais que la direction pressee NE
        ; correspond PAS a l'orientation courante -- ce chemin court-circuite
        ; entierement le cooldown (ix+0D) et le re-gate (ix+0C) de l'entree (1).
        ; Partie commune aux deux entrees (#21B4 pour l'entree 1, #21C7 pour
        ; l'entree 2): teste bit2,C -- si absent, arme un son de pas/rotation
        ; (CALL fn_sound_trigger_click_and_advance #09BD); pose bit1 de
        ; state_flags_2 (OR #02); teste bit1,C pour choisir entre les deux moities
        ; miroir de la bascule d'animation (fallthrough #21C9 ou saut vers
        ; fn_player_rotate_toggle_mirror #21E8): bascule bit6 de (ix+07 flags) via
        ; XOR #40, et (uniquement si bit6 de flags etait clair au moment du test)
        ; bascule bit3 du type (ix+00) via XOR #08; recalcule enfin
        ; type_mirror_plus_10 = type+#10 (ix+1C). Dans les deux cas RET final.
        ld    a,c
        and    #03
        ret    z
        ld    a,(ix+off_cooldown_or_collision_flags)
        and    #F0
        ret    nz
        bit    3,(ix+off_cooldown_or_collision_flags)
        ret    nz
        bit    2,c
        jr    nz,#21BD
        push    bc
        call    fn_sound_trigger_click_and_advance
        pop    bc
        ld    a,(ix+off_state_flags_2)
        or    #02
        ld    (ix+off_state_flags_2),a
        bit    1,c
loc_21C7:
        jr    nz,fn_player_rotate_toggle_mirror
        bit    6,(ix+off_flags)
        jr    nz,loc_21D7
        ld    a,(ix+off_type)
        xor    #08
        ld    (ix+off_type),a
loc_21D7:
        ld    a,(ix+off_flags)
        xor    #40
        ld    (ix+off_flags),a
        ld    a,(ix+off_type)
        add    a,#10
        ld    (ix+off_type_mirror_plus_10),a
        ret
fn_player_rotate_toggle_mirror:
        ; Moitie miroir de la bascule d'animation de
        ; fn_player_rotate_or_advance_tail (#219A), choisie quand bit1,C est
        ; actif: reteste bit6 de flags (ix+07) puis rejoint soit #21CF (bascule
        ; bit3 du type) soit directement #21D7 (juste XOR #40 sur flags + recalcul
        ; de type_mirror_plus_10), selon le meme motif que la moitie non-miroir.
        bit    6,(ix+off_flags)
        jr    nz,#21CF
        jr    loc_21D7
fn_player_jump_trigger:
        ; Sur bit3 de C (bouton action/saut, résultat de fn_read_input) et si
        ; cooldown_timer/collision_flags libres: si le compteur signé (ix+0B)
        ; n'est pas déjà très négatif (pas déjà en chute), pose bit3 de
        ; cooldown_or_collision_flags (état "en l'air"), (ix+0B)=8 (compteur
        ; initial), arme un son de saut (fn_sound_arm_channel_1 via HL=#0A5A).
        ; Mécanisme de SAUT du joueur, jamais identifié avant
        bit    3,c
        ret    z
        ld    a,(ix+off_cooldown_or_collision_flags)
        and    #F0
        ret    nz
        bit    3,(ix+off_cooldown_or_collision_flags)
        ret    nz
        ld    a,(ix+#0B)
        inc    a
        ret    m
        set    3,(ix+off_cooldown_or_collision_flags)
        ld    (ix+#0B),#08
        push    bc
        ld    hl,tbl_sound_descriptor_sweep_scrambled
        call    fn_sound_arm_channel_1
        pop    bc
        ret
fn_player_walk_animation_cycle:
        ; Si le joueur avance dans sa direction courante (bit2 de C, voir
        ; fn_player_read_input) et cooldown libre: arme un son de pas
        ; (fn_sound_trigger_click_and_advance #09BD) si (ix+00) bit0 clair, puis
        ; fait avancer un cycle 5 phases (valeurs 0-5, sautant 6→0) dans les 3
        ; bits bas du type — anime la marche. RÉSOUT probablement les plages
        ; encore hypothesis 0x20-0x2F (sprite_hero_up1..12) / 0x40-0x4F
        ; (sprite_werewulf...): ce sont vraisemblablement les valeurs traversées
        ; par ce cycle (à confirmer empiriquement: dumper le type du joueur en
        ; mouvement et vérifier la séquence 5-phases)
        ld    a,(ix+off_cooldown_or_collision_flags)
        and    #F0
        jr    nz,#2225
        bit    3,(ix+off_cooldown_or_collision_flags)
        jr    nz,#2225
        bit    2,c
        jr    z,fn_player_walk_animation_no_advance
        push    bc
        ld    a,(ix+off_type)
        and    #01
        jr    nz,#2230
        call    fn_sound_trigger_click_and_advance
        pop    bc
loc_2231:
        ld    a,(ix+off_type)
        ld    e,a
        inc    a
        and    #07
        cp    #06
        jr    nz,#223D
        xor    a
        ld    d,a
        ld    a,e
        and    #F8
        or    d
        ld    (ix+off_type),a
        ret
fn_player_walk_animation_no_advance:
        ; Branche de fn_player_walk_animation_cycle (#2214) prise quand le joueur
        ; N'avance PAS (jr z,#2246 en #2223, bit2,c clair): si (ix+off_type)&7
        ; vaut #02 ou #04, RET immediat (pas de recyclage sur ces 2 frames
        ; precises du cycle de marche); sinon JR #2231 (rejoint en plein milieu de
        ; fn_player_walk_animation_cycle: incremente/recycle quand meme le cycle
        ; 5-phases).
        ld    a,(ix+off_type)
        and    #07
        cp    #02
        ret    z
        cp    #04
        ret    z
        jr    loc_2231
fn_player_gravity_and_door_dispatch:
        ; Orchestre gravité+porte pour le joueur, appelée depuis fn_player_logic
        ; (busy_flag bit1 posé autour). Si var_special_input_mode_2 (#008A) non-
        ; nul: force (ix+0B)=2. Si conditions de cooldown/direction (bit2 de C):
        ; CALL fn_resolve_forward_vector (#22AD). Puis fait converger (ix+0B)
        ; (compteur signé saut/chute) vers 0 par pas de 1 ou 2, copie la valeur
        ; dans (0087) (nouvelle variable — cache pris avant l'appel à
        ; fn_player_door_transition, qui peut réinitialiser le contexte de
        ; l'entité via son mécanisme de checkpoint), arme un son de
        ; position/hauteur (fn_sound_arm_position_pitch_ch1 #0A22) si encore très
        ; négatif (chute), CALL fn_entity_movement_vector_resolve, CALL
        ; fn_player_door_transition (#2322) — CONFIRME PAR DÉSASSEMBLAGE DIRECT le
        ; site d'appel #228E déjà documenté en prose depuis, CALL #0016
        ; (application directe du vecteur de déplacement, même corps que
        ; rst_apply_movement_vector MAIS SANS son prélude DEC(ix+0B)/CALL #23F7
        ; déjà fait ici — confirme numériquement le "piège potentiel" déjà noté
        ; pour rst_apply_movement_vector), puis si atterri: RES bit3 de
        ; cooldown_or_collision_flags. Remet le vecteur (ix+09)/(ix+0A) à 0 une
        ; fois consommé
        ld    a,(var_special_input_mode_2)
        and    a
        jr    z,#225D
        ld    (ix+#0B),#02
        bit    3,(ix+off_cooldown_or_collision_flags)
        jr    nz,#226E
        ld    a,(ix+off_cooldown_or_collision_flags)
        and    #F0
        jr    nz,#226E
        bit    2,c
        jr    z,#2273
        push    bc
        call    fn_resolve_forward_vector
        pop    bc
        ld    a,(ix+#0B)
        and    a
        jp    m,#227E
        bit    3,c
        jr    nz,#227F
        dec    a
        dec    a
        ld    (ix+#0B),a
        ld    (#0087),a
        add    a,#02
        call    m,fn_sound_arm_position_pitch_ch1
        call    fn_entity_movement_vector_resolve
        call    fn_player_door_transition
        call    loc_0016
        bit    2,(ix+off_cooldown_or_collision_flags)
        jr    z,loc_22A5
        ld    a,(#0087)
        and    a
        jp    p,loc_22A5
        res    3,(ix+off_cooldown_or_collision_flags)
loc_22A5:
        xor    a
        ld    (ix+#09),a
        ld    (ix+#0A),a
        ret
fn_resolve_forward_vector:
        ; (ix+09)+=(ix+0E), (ix+0A)+=(ix+0F) (applique un vecteur en attente),
        ; remet +0x0E/+0x0F a 0, puis dispatch (RST 28, table
        ; tbl_player_forward_vector_dispatch) selon fn_get_orientation_code un pas
        ; d'avance +-3 vers (ix+09)/(ix+0A). Meme motif que
        ; fn_resolve_patrol_vector mais pour le joueur, amplitude 3 au lieu de 2.
        ld    a,(ix+#09)
        add    a,(ix+#0E)
        ld    (ix+#09),a
        ld    a,(ix+#0A)
        add    a,(ix+#0F)
        ld    (ix+#0A),a
        xor    a
        ld    (ix+#0E),a
        ld    (ix+#0F),a
        ld    bc,tbl_player_forward_vector_dispatch
loc_22C9:
        call    fn_get_orientation_code
        ld    l,a
        jp    rst_dispatch_table
fn_get_orientation_code:
        ; Combine bit6 de (ix+07) + bit3 de (ix+00) -> code d'orientation 0-3
        ; ATTENTION : le `and #10` teste bit4, mais APRES les deux rrca -- il
        ; porte donc sur le bit6 D'ORIGINE. Le commentaire disait "bit4" avant
        ; le 2026-09-04, ce qui a fait chercher en vain la routine ecrivant un
        ; bit4 de flags : elle n'existe pas. bit6 est ecrit par le xor #40 de
        ; fn_player_rotate_apply.
        ld    a,(ix+off_flags)
        rrca
        rrca
        and    #10
        ld    l,a
        ld    a,(ix+off_type)
        and    #08
        or    l
        rrca
        rrca
        rrca
        and    #03
        ret
tbl_player_forward_vector_dispatch:
        ; 4 entrees, vecteur fixe (+-3,0) ou (0,+-3) selon l'orientation du
        ; joueur.
        defw #22EC
        defw #22F5
        defw #22FC
        defw #2305
fn_player_forward_step_o0:
        ; Orientation 0: (ix+09) -= 3 (vecteur X). Voir
        ; tbl_player_forward_vector_dispatch (#22E4).
        ld    a,(ix+#09)
        add    a,#FD
loc_22F1:
        ld    (ix+#09),a
        ret
fn_player_forward_step_o1:
        ; Orientation 1: (ix+09) += 3 (vecteur X) -- rejoint la queue de stockage
        ; de fn_player_forward_step_o0 (#22F1). Voir
        ; tbl_player_forward_vector_dispatch (#22E4).
        ld    a,(ix+#09)
        add    a,#03
        jr    loc_22F1
fn_player_forward_step_o2:
        ; Orientation 2: (ix+0A) += 3 (vecteur Y). Voir
        ; tbl_player_forward_vector_dispatch (#22E4).
        ld    a,(ix+#0A)
        add    a,#03
loc_2301:
        ld    (ix+#0A),a
        ret
fn_player_forward_step_o3:
        ; Orientation 3: (ix+0A) -= 3 (vecteur Y) -- rejoint la queue de stockage
        ; de fn_player_forward_step_o2 (#2301). Voir
        ; tbl_player_forward_vector_dispatch (#22E4).
        ld    a,(ix+#0A)
        add    a,#FD
        jr    loc_2301
fn_entity_clamp_pending_z:
        ; Appelées par fn_entity_movement_vector_resolve (#23F7): réduisent pas à
        ; pas (fn_step_toward_zero #233B) le delta en attente sur leur axe jusqu'à
        ; ce que la position résultante reste dans une borne
        ; (var_room_data_field_2 #0074 pour Z, var_camera_reference/_y #0071/#0072
        ; pour X/Y), posant le bit de collision correspondant de
        ; cooldown_or_collision_flags à chaque pas. HYPOTHÈSE: empêche le vecteur
        ; de déplacement de sortir de la salle courante/de traverser le plafond
        ; avant même le scan de collision solide
        ld    a,(var_room_data_field_2)
        ld    d,a
        ld    a,(ix+off_grid_z_or_offset)
        add    a,h
        cp    d
        ret    nc
        set    2,(ix+off_cooldown_or_collision_flags)
        ld    a,h
        call    fn_step_toward_zero
        ld    h,a
        jr    nz,#2310
        ret
fn_player_door_transition:
        ; MAJEURE: appelée chaque frame depuis fn_player_logic (0x228E). Si le bit
        ; 0 des flags du joueur est posé (par une porte proche, voir
        ; fn_door_proximity_test) ET le cooldown (ix+0C nibble haut) est écoulé:
        ; consomme le flag, dispatch via tbl_door_direction_dispatch (0x2344, 4
        ; pointeurs) selon l'orientation (fn_get_orientation_code) vers un des 4
        ; gestionnaires par axe/sens — fn_door_cross_x_min/fn_door_cross_x_max
        ; (0x234C/0x23A5) et fn_door_cross_y_max/fn_door_cross_y_min
        ; (0x23C0/0x23DB), DÉSASSEMBLÉS INTÉGRALEMENT (précédemment défb bruts).
        ; Les 4 gestionnaires convergent vers une queue commune (incluse dans le
        ; corps de fn_door_cross_x_min, 0x236C+) qui arme le cooldown (bits 4-5 de
        ; ix+0C) puis, SI (ix+00) [type de l'entité] est dans [0x10,0x4F]
        ; (TOUJOURS vrai pour le joueur vivant, hero ou loup-garou): déclenche le
        ; mécanisme de CHECKPOINT décrit à tbl_init_entities_template (0x29EB) ci-
        ; dessous, puis jp 0x05A5 (relance fn_init_room SEUL, sans repasser par
        ; fn_init_room_entities ni décrémenter var_life_counter). IMPORTANTE: ce
        ; chemin de reset s'exécute pour TOUT franchissement de porte normal (le
        ; garde type∈[0x10,0x4F] est quasi toujours vrai en jeu), PAS seulement
        ; pour la mort — voir l'entrée dédiée ci-dessous qui révise l'ancienne
        ; caractérisation "mort douce".
        ld    a,(ix+off_cooldown_or_collision_flags)
        and    #F0
        ret    nz
        bit    0,(ix+off_flags)
        ret    z
        res    0,(ix+off_flags)
        ld    bc,tbl_door_direction_dispatch
        ld    hl,(var_camera_reference)
        push    hl
        jp    loc_22C9
fn_step_toward_zero:
        ; Utilitaire générique: rapproche A de 0 d'un pas (A-1 si positif, A+1 si
        ; négatif, inchangé si nul), Z reflète le nouveau A. Utilisé par les
        ; clamps/scans d'axe ci-dessus
        and    a
        ret    z
        jp    p,#2342
        inc    a
        inc    a
        dec    a
        ret
tbl_door_direction_dispatch:
        ; 4 pointeurs word (index = code d'orientation 0-3,
        ; fn_get_orientation_code), vers les 4 gestionnaires de franchissement de
        ; porte par axe/sens
        defw #234C
        defw #23A5
        defw #23C0
        defw #23DB
fn_door_cross_x_min:
        ; Franchissement de porte cote grid_x min: si (ix+01)+(ix+09)+(ix+04) <
        ; 0x80-camera_x, force (ix+01)=0x00 puis enchaine (fallthrough) dans la
        ; queue commune de reset/checkpoint (voir description generale a
        ; #2322/#29EB) qui decremente le nibble bas de (ix+08) (room_number), OR
        ; 0x30 dans (ix+0C), puis SI (ix+00) dans [0x10,0x4F] (TOUJOURS vrai pour
        ; le joueur vivant): copie 56 octets de struct_entities_base vers
        ; tbl_init_entities_template, force son octet type a 0x78 (sentinelle
        ; materialisation) pour les 2 entites, puis jp #05A5 (relance fn_init_room
        ; SANS repasser par fn_init_room_entities ni decrementer var_life_counter
        ; — ceci N'EST PAS le mecanisme de mort, voir note dediee)
        pop    hl
        ld    a,#80
        sub    l
        ld    l,a
        ld    a,(ix+off_grid_x)
        add    a,(ix+#09)
        add    a,(ix+off_bbox_w)
        cp    l
        ret    nc
        ld    (ix+off_grid_x),#00
        ld    a,(ix+off_room_number)
        ld    l,a
        dec    a
loc_2365:
        and    #0F
        ld    h,a
        ld    a,l
        and    #F0
        or    h
loc_236C:
        ld    (ix+off_room_number),a
        ld    a,(ix+off_cooldown_or_collision_flags)
        or    #30
        ld    (ix+off_cooldown_or_collision_flags),a
        ld    a,(ix+off_type)
        sub    #10
        cp    #40
        ret    nc
        inc    sp
        inc    sp
        inc    sp
        inc    sp
        push    ix
        pop    hl
        ld    de,tbl_init_entities_template
        ld    bc,fn_im1_interrupt_handler
        ldir
        ld    a,(tbl_init_entities_template)
        ld    (#29FB),a
        ld    a,(#2A07)
        ld    (#2A17),a
        ld    a,#78
        ld    (tbl_init_entities_template),a
        ld    (#2A07),a
        jp    loc_05A5
fn_door_cross_x_max:
        ; Franchissement de porte cote grid_x max: si (ix+01)+(ix+09)-(ix+04) >=
        ; camera_x+0x80, force (ix+01)=0xFF puis incremente le nibble bas de
        ; (ix+08), rejoint la queue commune (voir #234C)
        pop    hl
        ld    a,l
        add    a,#80
        ld    l,a
        ld    a,(ix+off_grid_x)
        add    a,(ix+#09)
        sub    (ix+off_bbox_w)
        cp    l
        ret    c
        ld    (ix+off_grid_x),#FF
        ld    a,(ix+off_room_number)
        ld    l,a
        inc    a
        jr    loc_2365
fn_door_cross_y_max:
        ; Franchissement de porte cote grid_y max: si (ix+02)+(ix+0A)-(ix+05) >=
        ; camera_y+0x80, force (ix+02)=0xFF puis (ix+08)+=0x10 (nibble haut),
        ; rejoint la queue commune (voir #234C)
        pop    hl
        ld    a,h
        add    a,#80
        ld    h,a
        ld    a,(ix+off_grid_y)
        add    a,(ix+#0A)
        sub    (ix+off_bbox_h)
        cp    h
        ret    c
        ld    (ix+off_grid_y),#FF
        ld    a,(ix+off_room_number)
        add    a,#10
        jr    loc_236C
fn_door_cross_y_min:
        ; Franchissement de porte cote grid_y min: si (ix+02)+(ix+0A)+(ix+05) <
        ; 0x80-camera_y, force (ix+02)=0x00 puis (ix+08)-=0x10 (nibble haut),
        ; rejoint la queue commune (voir #234C)
        pop    hl
        ld    a,#80
        sub    h
        ld    h,a
        ld    a,(ix+off_grid_y)
        add    a,(ix+#0A)
        add    a,(ix+off_bbox_h)
        cp    h
        ret    nc
        ld    (ix+off_grid_y),#00
        ld    a,(ix+off_room_number)
        sub    #10
        jp    loc_236C
fn_entity_movement_vector_resolve:
        ; Corps GÉNÉRIQUE (pas spécifique au joueur) de résolution du vecteur de
        ; déplacement en attente (ix+09/0A/0B) = deltas X/Y/Z, partagé par
        ; rst_apply_movement_vector (#0010) ET directement appelé par
        ; fn_player_gravity_and_door_dispatch (#2253). Pour chaque axe, DANS
        ; L'ORDRE Z puis X puis Y: si le delta courant est non-nul, clampe-le
        ; contre les bornes de la salle/caméra (fn_entity_clamp_pending_z/x/y
        ; #230C/#258F/#25BA) puis, s'il reste non-nul, scanne les 40 entités pour
        ; une collision solide bloquante sur cet axe (fn_entity_collide_axis_z/x/y
        ; #24EA/#244C/#249B) — chaque scan pouvant en plus PROPAGER le delta vers
        ; l'entité heurtée si elle est "poussable" (bit2 de ses flags), même motif
        ; que les objets/tables poussables. Utilise fn_step_toward_zero (#233B)
        ; pour réduire progressivement un delta bloqué. Une caractérisation
        ; précédente (dans fn_player_gravity_and_door_dispatch) qui la qualifiait
        ; de simple "queue de fn_player_door_transition".
        bit    1,(ix+off_flags)
        ret    nz
        set    1,(ix+off_flags)
        ld    a,(ix+off_cooldown_or_collision_flags)
        and    #F8
        ld    (ix+off_cooldown_or_collision_flags),a
        ld    l,#00
        ld    c,l
        ld    a,(ix+#0B)
        and    a
        ld    h,a
        jr    z,#241C
        call    fn_entity_clamp_pending_z
        ld    a,h
        and    a
        jr    z,#241C
        call    fn_entity_collide_axis_z
        ld    a,(ix+#09)
        and    a
        ld    c,a
        jr    z,#242D
        call    fn_entity_clamp_pending_x
        ld    a,c
        and    a
        jr    z,#242D
        call    fn_entity_collide_axis_x
        ld    a,(ix+#0A)
        and    a
        ld    l,a
        jr    z,#243E
        call    fn_entity_clamp_pending_y
        ld    a,l
        and    a
        jr    z,#243E
        call    fn_entity_collide_axis_y
        ld    (ix+#09),c
        ld    (ix+#0A),l
        ld    (ix+#0B),h
        res    1,(ix+off_flags)
        ret
fn_entity_collide_axis_x:
        ; Scans de collision solide par axe, appelés par
        ; fn_entity_movement_vector_resolve (#23F7): bouclent sur les 40 entités
        ; (fn_probe_entity_is_active_other #0E1C), testent le chevauchement sur
        ; les 2 AUTRES axes (via fn_aabb_axis_gap_*, en utilisant les deltas déjà
        ; résolus pour les axes précédents et 0 pour ceux pas encore traités —
        ; explique pourquoi l'ordre Z→X→Y compte), puis sur leur propre axe; si
        ; blocage: pose le bit de collision, synchronise un bit de state_flags_2
        ; entre les 2 entités, propage le delta vers l'entité candidate si
        ; "poussable", et réduit le delta d'un pas (fn_step_toward_zero) en boucle
        ld    iy,struct_entities_base
        ld    b,#28
loc_2452:
        call    fn_probe_entity_is_active_other
        jr    z,fn_entity_collide_axis_x_next
        call    fn_aabb_axis_gap_y
        jr    nc,fn_entity_collide_axis_x_next
        call    fn_aabb_axis_gap_z
        jr    nc,fn_entity_collide_axis_x_next
loc_2461:
        call    fn_aabb_axis_gap_x
        jr    nc,fn_entity_collide_axis_x_next
        set    0,(ix+off_cooldown_or_collision_flags)
        ld    a,(ix+off_state_flags_2)
        rrca
        and    #40
        or    (iy+off_state_flags_2)
        ld    (iy+off_state_flags_2),a
        rlca
        and    #40
        or    (ix+off_state_flags_2)
        ld    (ix+off_state_flags_2),a
        bit    2,(iy+off_flags)
        jr    z,#248B
        ld    a,(ix+#09)
        ld    (iy+#09),a
        ld    a,c
        call    fn_step_toward_zero
        ld    c,a
        ret    z
        jr    loc_2461
fn_entity_collide_axis_x_next:
        ; Queue de boucle de fn_entity_collide_axis_x (#244C): IY += #001C (taille
        ; d'une structure entite), DJNZ vers #2452 (entite suivante), puis RET
        ; quand les 40 slots sont epuises.
        ld    de,#001C
        add    iy,de
        djnz    loc_2452
        ret
fn_entity_collide_axis_y:
        ; Scans de collision solide par axe, appelés par
        ; fn_entity_movement_vector_resolve (#23F7): bouclent sur les 40 entités
        ; (fn_probe_entity_is_active_other #0E1C), testent le chevauchement sur
        ; les 2 AUTRES axes (via fn_aabb_axis_gap_*, en utilisant les deltas déjà
        ; résolus pour les axes précédents et 0 pour ceux pas encore traités —
        ; explique pourquoi l'ordre Z→X→Y compte), puis sur leur propre axe; si
        ; blocage: pose le bit de collision, synchronise un bit de state_flags_2
        ; entre les 2 entités, propage le delta vers l'entité candidate si
        ; "poussable", et réduit le delta d'un pas (fn_step_toward_zero) en boucle
        ld    iy,struct_entities_base
        ld    b,#28
loc_24A1:
        call    fn_probe_entity_is_active_other
        jr    z,fn_entity_collide_axis_y_next
        call    fn_aabb_axis_gap_x
        jr    nc,fn_entity_collide_axis_y_next
        call    fn_aabb_axis_gap_z
        jr    nc,fn_entity_collide_axis_y_next
loc_24B0:
        call    fn_aabb_axis_gap_y
        jr    nc,fn_entity_collide_axis_y_next
        set    1,(ix+off_cooldown_or_collision_flags)
        ld    a,(ix+off_state_flags_2)
        rrca
        and    #40
        or    (iy+off_state_flags_2)
        ld    (iy+off_state_flags_2),a
        rlca
        and    #40
        or    (ix+off_state_flags_2)
        ld    (ix+off_state_flags_2),a
        bit    2,(iy+off_flags)
        jr    z,#24DA
        ld    a,(ix+#0A)
        ld    (iy+#0A),a
        ld    a,l
        call    fn_step_toward_zero
        ld    l,a
        ret    z
        jr    loc_24B0
fn_entity_collide_axis_y_next:
        ; Queue de boucle de fn_entity_collide_axis_y (#249B): IY += #001C, DJNZ
        ; vers #24A1, RET.
        ld    de,#001C
        add    iy,de
        djnz    loc_24A1
        ret
fn_entity_collide_axis_z:
        ; Scans de collision solide par axe, appelés par
        ; fn_entity_movement_vector_resolve (#23F7): bouclent sur les 40 entités
        ; (fn_probe_entity_is_active_other #0E1C), testent le chevauchement sur
        ; les 2 AUTRES axes (via fn_aabb_axis_gap_*, en utilisant les deltas déjà
        ; résolus pour les axes précédents et 0 pour ceux pas encore traités —
        ; explique pourquoi l'ordre Z→X→Y compte), puis sur leur propre axe; si
        ; blocage: pose le bit de collision, synchronise un bit de state_flags_2
        ; entre les 2 entités, propage le delta vers l'entité candidate si
        ; "poussable", et réduit le delta d'un pas (fn_step_toward_zero) en boucle
        ld    iy,struct_entities_base
        ld    b,#28
loc_24F0:
        call    fn_probe_entity_is_active_other
        jr    z,fn_entity_collide_axis_z_next
        call    fn_aabb_axis_gap_x
        jr    nc,fn_entity_collide_axis_z_next
        call    fn_aabb_axis_gap_y
        jr    nc,fn_entity_collide_axis_z_next
loc_24FF:
        call    fn_aabb_axis_gap_z
        jr    nc,fn_entity_collide_axis_z_next
        set    2,(ix+off_cooldown_or_collision_flags)
        ld    a,(ix+off_state_flags_2)
        rrca
        and    #40
        or    (iy+off_state_flags_2)
        ld    (iy+off_state_flags_2),a
        rlca
        and    #40
        or    (ix+off_state_flags_2)
        ld    (ix+off_state_flags_2),a
        set    3,(iy+off_state_flags_2)
        bit    2,(ix+off_flags)
        jr    z,#253F
        ld    a,(ix+#09)
        and    a
        jr    nz,#2533
        ld    a,(iy+#09)
        ld    (ix+#09),a
        ld    a,(ix+#0A)
        and    a
        jr    nz,#253F
        ld    a,(iy+#0A)
        ld    (ix+#0A),a
        ld    a,h
        call    fn_step_toward_zero
        ld    h,a
        ret    z
        jr    loc_24FF
fn_entity_collide_axis_z_next:
        ; Queue de boucle de fn_entity_collide_axis_z (#24EA): IY += #001C, DJNZ
        ; vers #24F0, RET.
        ld    de,#001C
        add    iy,de
        djnz    loc_24F0
        ret
fn_aabb_axis_gap_x:
        ; Primitives génériques de test de chevauchement AABB, un axe chacune:
        ; retournent CARRY SET si chevauchement. X/Y sont SYMÉTRIQUES (somme des
        ; deux demi-étendues bbox_w/bbox_h). Z EST ASYMÉTRIQUE (découverte
        ; notable): selon le signe de l'écart de position, utilise SOIT la
        ; profondeur (bbox_d) de l'entité candidate (si elle est au-dessus, cible
        ; fn_aabb_axis_gap_z_other_extent #258A) SOIT la sienne propre (si en-
        ; dessous) — cohérent avec une sémantique "gravité" (atterrir sur / cogner
        ; par-dessous ne sont pas symétriques). Utilisées par
        ; fn_probe_solid_support (#0DE1), rst_apply_movement_vector (via #23F7),
        ; et les scans de collision fn_entity_collide_axis_*
        ld    a,(ix+off_bbox_w)
        add    a,(iy+off_bbox_w)
        ld    d,a
        ld    a,(ix+off_grid_x)
        add    a,c
        sub    (iy+off_grid_x)
        jp    p,#2562
        neg
        sub    d
        ret
fn_aabb_axis_gap_y:
        ; Primitives génériques de test de chevauchement AABB, un axe chacune:
        ; retournent CARRY SET si chevauchement. X/Y sont SYMÉTRIQUES (somme des
        ; deux demi-étendues bbox_w/bbox_h). Z EST ASYMÉTRIQUE (découverte
        ; notable): selon le signe de l'écart de position, utilise SOIT la
        ; profondeur (bbox_d) de l'entité candidate (si elle est au-dessus, cible
        ; fn_aabb_axis_gap_z_other_extent #258A) SOIT la sienne propre (si en-
        ; dessous) — cohérent avec une sémantique "gravité" (atterrir sur / cogner
        ; par-dessous ne sont pas symétriques). Utilisées par
        ; fn_probe_solid_support (#0DE1), rst_apply_movement_vector (via #23F7),
        ; et les scans de collision fn_entity_collide_axis_*
        ld    a,(ix+off_bbox_h)
        add    a,(iy+off_bbox_h)
        ld    d,a
        ld    a,(ix+off_grid_y)
        add    a,l
        sub    (iy+off_grid_y)
        jp    p,#2577
        neg
        sub    d
        ret
fn_aabb_axis_gap_z:
        ; Primitives génériques de test de chevauchement AABB, un axe chacune:
        ; retournent CARRY SET si chevauchement. X/Y sont SYMÉTRIQUES (somme des
        ; deux demi-étendues bbox_w/bbox_h). Z EST ASYMÉTRIQUE (découverte
        ; notable): selon le signe de l'écart de position, utilise SOIT la
        ; profondeur (bbox_d) de l'entité candidate (si elle est au-dessus, cible
        ; fn_aabb_axis_gap_z_other_extent #258A) SOIT la sienne propre (si en-
        ; dessous) — cohérent avec une sémantique "gravité" (atterrir sur / cogner
        ; par-dessous ne sont pas symétriques). Utilisées par
        ; fn_probe_solid_support (#0DE1), rst_apply_movement_vector (via #23F7),
        ; et les scans de collision fn_entity_collide_axis_*
        ld    a,(ix+off_grid_z_or_offset)
        add    a,h
        sub    (iy+off_grid_z_or_offset)
        jp    p,fn_aabb_axis_gap_z_other_extent
        neg
        ld    d,(ix+off_bbox_d)
loc_2588:
        sub    d
        ret
fn_aabb_axis_gap_z_other_extent:
        ; Queue de fn_aabb_axis_gap_z (#2579, cible du JP P,#258A quand l'ecart Z
        ; est positif): D=(iy+off_bbox_d) (profondeur de l'AUTRE entite, pas la
        ; sienne) puis rejoint #2588 (SUB D; RET) au milieu de fn_aabb_axis_gap_z.
        ld    d,(iy+off_bbox_d)
        jr    loc_2588
fn_entity_clamp_pending_x:
        ; Appelées par fn_entity_movement_vector_resolve (#23F7): réduisent pas à
        ; pas (fn_step_toward_zero #233B) le delta en attente sur leur axe jusqu'à
        ; ce que la position résultante reste dans une borne
        ; (var_room_data_field_2 #0074 pour Z, var_camera_reference/_y #0071/#0072
        ; pour X/Y), posant le bit de collision correspondant de
        ; cooldown_or_collision_flags à chaque pas. HYPOTHÈSE: empêche le vecteur
        ; de déplacement de sortir de la salle courante/de traverser le plafond
        ; avant même le scan de collision solide
        ld    a,(ix+off_cooldown_or_collision_flags)
        and    #F0
        ret    nz
        bit    0,(ix+off_flags)
        ret    nz
        ld    a,(var_camera_reference)
        ld    b,a
        ld    a,(ix+off_grid_x)
        add    a,c
        sub    #80
        jr    nc,#25A8
        neg
        add    a,(ix+off_bbox_w)
        cp    b
        jr    c,#25B9
        set    0,(ix+off_cooldown_or_collision_flags)
        ld    a,c
        call    fn_step_toward_zero
        ld    c,a
        jr    nz,#259E
        ret
fn_entity_clamp_pending_y:
        ; Appelées par fn_entity_movement_vector_resolve (#23F7): réduisent pas à
        ; pas (fn_step_toward_zero #233B) le delta en attente sur leur axe jusqu'à
        ; ce que la position résultante reste dans une borne
        ; (var_room_data_field_2 #0074 pour Z, var_camera_reference/_y #0071/#0072
        ; pour X/Y), posant le bit de collision correspondant de
        ; cooldown_or_collision_flags à chaque pas. HYPOTHÈSE: empêche le vecteur
        ; de déplacement de sortir de la salle courante/de traverser le plafond
        ; avant même le scan de collision solide
        ld    a,(ix+off_cooldown_or_collision_flags)
        and    #F0
        ret    nz
        bit    0,(ix+off_flags)
        ret    nz
        ld    a,(var_camera_reference_y)
        ld    b,a
        ld    a,(ix+off_grid_y)
        add    a,l
        sub    #80
        jr    nc,#25D3
        neg
        add    a,(ix+off_bbox_h)
        cp    b
        jr    c,#25E4
        set    1,(ix+off_cooldown_or_collision_flags)
        ld    a,l
        call    fn_step_toward_zero
        ld    l,a
        jr    nz,#25C9
        ret
fn_entity_recompute_screen_bbox:
        ; Reprojette IX (fn_isometric_project #2EDC + fn_resolve_sprite_shape
        ; #2F02) et en dérive screen_w/screen_h (+0x14/+0x15)
        call    fn_isometric_project
        call    fn_resolve_sprite_shape
        ld    a,(ix+off_screen_x)
        and    #07
        ld    a,(de)
        inc    de
        jr    z,#25F5
        inc    a
        and    #0F
        ld    (ix+off_screen_w),a
        ld    a,(de)
        ld    (ix+off_screen_h),a
        ret
fn_entity_fall_and_mark_overlap:
        ; Tick générique réutilisé par plusieurs types d'entités (ex. Type 0x08
        ; "herse", JP direct depuis asm/code/objects_and_rooms_setup.asm #1F83, ET
        ; les 31 entrées de tbl_entity_logic_dispatch pointant vers
        ; fn_entity_materialize_dispatch_a/b #2689/#268E qui y rebouclent):
        ; recalcule sa propre bbox écran (fn_entity_recompute_screen_bbox #25E5)
        ; puis scanne les 40 entités et pose bit4 de leurs flags si leur empreinte
        ; ÉCRAN (pas grille) chevauche celle de IX. HYPOTHÈSE (rôle exact non
        ; confirmé par test comportemental): marquage "à retraiter"/détection de
        ; support visuel
        ld    iy,struct_entities_base
        call    fn_entity_recompute_screen_bbox
        ld    b,#28
        ld    a,(ix+off_screen_x)
        rrca
        rrca
        and    #3F
        ld    l,a
        ld    a,(ix+off_screen_x_prev)
        rrca
        rrca
        and    #3F
        ld    h,a
        cp    l
        jr    c,#261C
        ld    a,l
        ld    e,a
        ld    a,l
        add    a,(ix+off_screen_w)
        ld    l,a
        ld    a,h
        add    a,(ix+off_screen_w_prev)
        cp    l
        jr    nc,#262A
        ld    a,l
        sub    e
        ld    d,a
        ld    a,(ix+off_screen_y)
        cp    (ix+off_screen_y_prev)
        jr    c,#2637
        ld    a,(ix+off_screen_y_prev)
        ld    l,a
        ld    a,(ix+off_screen_y)
        add    a,(ix+off_screen_h)
        ld    h,a
        ld    a,(ix+off_screen_y_prev)
        add    a,(ix+off_screen_h_prev)
        cp    h
        jr    nc,#2649
        ld    a,h
        sub    l
        ld    h,a
loc_264B:
        ld    a,(iy+off_type)
        and    a
        jr    z,#2671
        bit    4,(iy+off_flags)
        jr    nz,#2671
        ld    a,(iy+off_screen_x)
        rrca
        rrca
        and    #3F
        sub    e
        jr    c,fn_entity_mark_overlap_x_tail
        cp    d
loc_2662:
        jr    nc,#2671
        ld    a,(iy+off_screen_y)
        sub    l
        jr    c,fn_entity_mark_overlap_y_tail
        cp    h
loc_266B:
        jr    nc,#2671
        set    4,(iy+off_flags)
        exx
        ld    de,#001C
        add    iy,de
        exx
        djnz    loc_264B
        ret
fn_entity_mark_overlap_x_tail:
        ; Queue de fn_entity_fall_and_mark_overlap (#25FF, cible d'un JR C quand
        ; l'ecart X entre bornes est negatif): NEG puis CP (iy+off_screen_w) et
        ; rejoint #2662 au milieu de la boucle.
        neg
        cp    (iy+off_screen_w)
        jr    loc_2662
fn_entity_mark_overlap_y_tail:
        ; Symetrique de fn_entity_mark_overlap_x_tail (#267B) pour l'axe Y: NEG,
        ; CP (iy+off_screen_h), rejoint #266B.
        neg
        cp    (iy+off_screen_h)
        jr    loc_266B
fn_entity_materialize_dispatch_a:
        ; 2 points d'entrée de tbl_entity_logic_dispatch (16+15 entrées,
        ; asm/code/dispatch_and_sound.asm #06B6-#06D4/#06F6-#0714), variante
        ; calibration #1DA3/#1DAD (même motif que
        ; fn_player_logic/fn_player_logic_night). Corps partagé: si pas de
        ; matérialisation en cours, copie 7 octets (grid_x..flags) DEPUIS le slot
        ; d'entité PRÉCÉDENT (IX-0x1C) vers IX (synchronisation sur un
        ; "partenaire" de slot adjacent), puis fn_entity_materialize_pick_subtype
        ; (#26C3) choisit le sous-type final avant de reboucler sur
        ; fn_entity_fall_and_mark_overlap (#25FF). HYPOTHÈSE (mécanisme complet
        ; non vérifié en direct): semble gérer une paire d'entités adjacentes en
        ; mémoire qui se synchronise et choisit son sous-type au moment de
        ; matérialiser — piste ouverte
        call    loc_1DA3
        jr    loc_2691
fn_entity_materialize_dispatch_b:
        ; 2 points d'entrée de tbl_entity_logic_dispatch (16+15 entrées,
        ; asm/code/dispatch_and_sound.asm #06B6-#06D4/#06F6-#0714), variante
        ; calibration #1DA3/#1DAD (même motif que
        ; fn_player_logic/fn_player_logic_night). Corps partagé: si pas de
        ; matérialisation en cours, copie 7 octets (grid_x..flags) DEPUIS le slot
        ; d'entité PRÉCÉDENT (IX-0x1C) vers IX (synchronisation sur un
        ; "partenaire" de slot adjacent), puis fn_entity_materialize_pick_subtype
        ; (#26C3) choisit le sous-type final avant de reboucler sur
        ; fn_entity_fall_and_mark_overlap (#25FF). HYPOTHÈSE (mécanisme complet
        ; non vérifié en direct): semble gérer une paire d'entités adjacentes en
        ; mémoire qui se synchronise et choisit son sous-type au moment de
        ; matérialiser — piste ouverte
        call    loc_1DAD
loc_2691:
        ld    a,(var_special_input_mode_1)
        and    a
        jr    nz,#269E
        bit    6,(ix+off_state_flags_2)
        jp    nz,loc_17CC
        push    ix
        pop    de
        ld    hl,#FFE4
        add    hl,de
        push    hl
        pop    iy
        inc    de
        inc    hl
        ld    bc,#0007
        ldir
        ld    (ix+off_bbox_d),#00
        set    1,(ix+off_flags)
        ld    a,(ix+off_state_flags_2)
        and    #0F
        jr    z,fn_entity_materialize_pick_subtype
        dec    (ix+off_state_flags_2)
        jr    loc_26D6
fn_entity_materialize_pick_subtype:
        ; Choix du sous-type final au moment de materialiser (voir
        ; fn_entity_materialize_dispatch_b #268E): A = var_pseudo_random_acc
        ; (#006D). Si A<2 -> fn_entity_materialize_subtype_low (#26E1, ~0.8% des
        ; tirages). Si A>=#FE -> fn_entity_materialize_subtype_high (#26EE,
        ; ~0.8%). Sinon (cas ecrasant, ~98.4%): (ix+off_type) = (iy+off_type)+#10
        ; (type du partenaire +#10, meme famille que off_type_mirror_plus_10) puis
        ; rejoint la queue commune #26D6 ((ix+off_grid_z_or_offset) =
        ; (iy+off_grid_z_or_offset)+#0C, JP fn_entity_fall_and_mark_overlap).
        ld    a,(var_pseudo_random_acc)
        cp    #02
        jr    c,fn_entity_materialize_subtype_low
        cp    #FE
        jr    nc,fn_entity_materialize_subtype_high
        ld    a,(iy+off_type)
loc_26D1:
        add    a,#10
        ld    (ix+off_type),a
loc_26D6:
        ld    a,(iy+off_grid_z_or_offset)
        add    a,#0C
        ld    (ix+off_grid_z_or_offset),a
        jp    fn_entity_fall_and_mark_overlap
fn_entity_materialize_subtype_low:
        ; Branche rare (var_pseudo_random_acc<2) de
        ; fn_entity_materialize_pick_subtype (#26C3): (ix+off_type) =
        ; ((iy+off_type)&#F8)|#06 (force les 3 bits bas du type du partenaire a
        ; #06), (ix+off_state_flags_2)=#08, puis rejoint #26D1 (ADD A,#10; LD
        ; (ix+off_type),A -- ecrase la valeur precedente avec +#10 en plus).
        ld    a,(iy+off_type)
        and    #F8
        or    #06
loc_26E8:
        ld    (ix+off_state_flags_2),#08
        jr    loc_26D1
fn_entity_materialize_subtype_high:
        ; Branche rare (var_pseudo_random_acc>=#FE) de
        ; fn_entity_materialize_pick_subtype (#26C3): identique a
        ; fn_entity_materialize_subtype_low (#26E1) mais force les 3 bits bas a
        ; #07 au lieu de #06, puis rejoint #26E8 (state_flags_2=#08) et #26D1.
        ld    a,(iy+off_type)
        and    #F8
        or    #07
        jr    loc_26E8
fn_cull_entities:
        ; Filtre 40 entités (type≠0 ET flag actif) -> buffer 0x2720
        push    ix
        ld    b,#28
        ld    de,#001C
        ld    ix,struct_entities_base
        ld    hl,buf_visible_entities
        ld    c,#00
loc_2707:
        ld    a,(ix+off_type)
        and    a
        jr    z,#2715
        bit    4,(ix+off_flags)
        jr    z,#2715
        ld    (hl),c
        inc    hl
        inc    c
        add    ix,de
        djnz    loc_2707
        ld    a,#FF
        ld    (hl),a
        pop    ix
        ret
buf_visible_entities:
        ; Buffer PAR FRAME (pas statique): index des entites actives/visibles,
        ; termine par #FF
        ds #0030
fn_check_collisions:
        ; Boucle imbriquée AABB 3D sur buffer 0x2720 (curseur externe IX via
        ; (0x0092), curseur interne IY via (0x0094)), dispatch par code de
        ; collision (RST 28, tbl_collision_dispatch 0x27FE, 27 entrées selon code
        ; d'overlap 0-26 calculé à 0x27F7 — corrige "28 entrées 0-27" précédemment
        ; documenté, décompte vérifié par lecture RAM directe: la 28e "entrée"
        ; tomberait sur le premier octet de code réel de
        ; fn_collision_dispatch_handlers). Remet (0x0084)=0 en tête (effet de bord
        ; nécessaire). Point clé (résout un ancien "reste à élucider"): quand le
        ; curseur interne IY a épuisé tous les candidats pour l'IX courant (DE
        ; sentinelle 0xFF, saut à #2895), la routine marque l'entité comme traitée
        ; (set 7,(hl) sur son octet de type dans le buffer 0x2720 — c'est ce bit7
        ; que le test bit 7,a en tête de boucle externe/interne, #2762/#2777,
        ; ignore pour sauter les entités déjà vues), incrémente (0x0084) de 1
        ; (compteur d'entités traitées ce passage, DISTINCT de son rôle de +=
        ; (0x0070) fait plus tard par l'appelant), puis appelle
        ; fn_sprite_pipeline_setup (call #2F17 à #28A4) — donc chaque entité est
        ; dessinée (projection isométrique + blit) au moment précis où son test de
        ; collision contre toutes les autres se termine, pas dans une passe
        ; séparée. Boucle externe relancée ensuite (jp #2758) jusqu'à épuisement
        ; du buffer (sentinelle 0xFF), puis ret. Voir 0x2DE2 pour la place de
        ; cette routine dans le pipeline complet
        xor    a
        ld    (var_blit_stack_accumulator),a
        push    ix
        push    iy
loc_2758:
        ld    de,buf_visible_entities
        ld    a,(de)
        inc    de
        cp    #FF
        jp    z,#28AA
        bit    7,a
        jr    nz,#275B
        call    fn_entity_index_to_ptr
        ld    (var_collision_ix_cursor),de
        push    hl
        pop    ix
loc_2770:
        ld    a,(de)
        inc    de
        cp    #FF
        jp    z,#2895
        bit    7,a
        jr    nz,loc_2770
        call    fn_entity_index_to_ptr
        ld    (var_collision_iy_cursor),de
        push    hl
        pop    iy
        push    ix
        pop    bc
        and    a
        sbc    hl,bc
        jr    z,loc_2770
        ld    c,#00
        ld    a,(iy+off_grid_z_or_offset)
        add    a,(iy+off_bbox_d)
        ld    l,a
        ld    a,(ix+off_grid_z_or_offset)
        sub    l
        jr    nc,#27AB
        ld    a,(ix+off_grid_z_or_offset)
        add    a,(ix+off_bbox_d)
        ld    l,a
        ld    a,(iy+off_grid_z_or_offset)
        sub    l
        jr    c,#27AA
        inc    c
        inc    c
        ld    a,(iy+off_grid_y)
        add    a,(iy+off_bbox_h)
        ld    l,a
        ld    a,(ix+off_grid_y)
        sub    (ix+off_bbox_h)
        sub    l
        jr    nc,#27D1
        ld    a,(ix+off_grid_y)
        add    a,(ix+off_bbox_h)
        ld    l,a
        ld    a,(iy+off_grid_y)
        sub    (iy+off_bbox_h)
        sub    l
        ld    a,c
        jr    c,#27CE
        add    a,#03
        add    a,#03
        ld    c,a
        ld    a,(iy+off_grid_x)
        add    a,(iy+off_bbox_w)
        ld    l,a
        ld    a,(ix+off_grid_x)
        sub    (ix+off_bbox_w)
        sub    l
        jr    nc,#27F7
        ld    a,(ix+off_grid_x)
        add    a,(ix+off_bbox_w)
        ld    l,a
        ld    a,(iy+off_grid_x)
        sub    (iy+off_bbox_w)
        sub    l
        ld    a,c
        jr    c,#27F4
        add    a,#09
        add    a,#09
        ld    c,a
        ld    l,c
        ld    bc,tbl_collision_dispatch
        jp    rst_dispatch_table
tbl_collision_dispatch:
        ; Table RST 28 de fn_check_collisions, 27 entrées word (index = code
        ; d'overlap AABB 0-26), toutes les valeurs vérifiées par lecture RAM
        ; directe: pointent vers l'un des 3 gestionnaires de
        ; fn_collision_dispatch_handlers (0x2834/0x2837/0x283A). Occupe exactement
        ; 0x27FE-0x2834 (54 octets) — le code des gestionnaires commence
        ; immédiatement après, sans octet de séparation
        defw #2834
        defw #2834
        defw #2834
        defw #283A
        defw #283A
        defw #2834
        defw #283A
        defw #283A
        defw #2834
        defw #2834
        defw #2837
        defw #2837
        defw #283A
        defw #2876
        defw #2837
        defw #283A
        defw #283A
        defw #2834
        defw #2834
        defw #2837
        defw #2837
        defw #2834
        defw #2837
        defw #2837
        defw #2834
        defw #2834
        defw #2834
fn_collision_dispatch_handlers:
        ; 3 gestionnaires atteints via tbl_collision_dispatch: 0x2834/0x2837 sont
        ; deux jp #2770 identiques (réentrée directe de la boucle, overlap non
        ; retenu); 0x283A teste si la paire IX/IY courante est déjà dans
        ; tbl_collision_pending — absente: l'y ajoute puis jp #2770; présente
        ; (suite à 0x2863): cherche IY dans buf_visible_entities et rebranche sur
        ; 0x2898 (collision confirmée) ou 0x2758 (buffer épuisé, relance la boucle
        ; externe)
        jp    loc_2770
        jp    loc_2770
        ld    hl,(var_collision_iy_cursor)
        dec    hl
        ld    c,(hl)
        ld    de,tbl_collision_pending
loc_2842:
        ld    a,(de)
        cp    #FF
        jr    z,#284D
        cp    c
        jr    z,#2863
        inc    de
        jr    loc_2842
        ld    a,c
        ld    (de),a
        inc    de
        ld    a,#FF
        ld    (de),a
        push    iy
        pop    ix
        ld    hl,(var_collision_iy_cursor)
        ld    (var_collision_ix_cursor),hl
        ld    de,buf_visible_entities
        jp    loc_2770
        ld    hl,buf_visible_entities
        ld    a,(hl)
        inc    hl
        cp    #FF
        jp    z,loc_2758
        cp    c
        jr    nz,#2866
        push    iy
        pop    ix
        jr    loc_2898
fn_collision_effect:
        ; Si (ix+00)-0x60 < 7 OU (iy+00)-0x60 < 7 (l'un ou l'autre membre de la
        ; paire en collision courante de fn_check_collisions est un pickup
        ; 0x60-0x66): force CE côté (pas les deux) à type=0xBB (ramassé). PUIS JP
        ; #2770 — reprise du corps de boucle de fn_check_collisions, PAS un simple
        ; retour à l'appelant: effet de bord intégré au flot normal de la boucle
        ; de collision, pas une routine autonome
        ld    a,(ix+off_type)
        sub    #60
        cp    #07
        jr    nc,#2885
        ld    (ix+off_type),#BB
        jr    loc_2892
        ld    a,(iy+off_type)
        sub    #60
        cp    #07
        jr    nc,loc_2892
        ld    (iy+off_type),#BB
loc_2892:
        jp    loc_2770
        ld    hl,(var_collision_ix_cursor)
loc_2898:
        dec    hl
        set    7,(hl)
        ld    a,#FF
        ld    (tbl_collision_pending),a
        ld    hl,var_blit_stack_accumulator
        inc    (hl)
        call    fn_sprite_pipeline_setup
        jp    loc_2758
        pop    iy
        pop    ix
        ret
tbl_collision_pending:
        ; Table des paires de collision "en attente de confirmation" (index
        ; d'entité, terminée par 0xFF), 8 octets exactement (0x28AF-0x28B7)
        defb #FF,#FF,#FF,#FF,#FF,#FF,#FF,#FF
fn_read_input:
        ; LA vraie routine de scan input (clavier ou joystick), résultat ->
        ; (0x007B)
        ld    a,(var_special_input_mode_1)
        ld    c,a
        ld    a,(var_special_input_mode_2)
        or    c
        ld    c,#00
        jp    nz,loc_2901
        ld    a,(var_input_mode_flag)
        and    #02
        jr    z,#2912
        ld    a,#06
        call    fn_read_keyboard_line
        ld    c,a
        push    bc
        ld    a,#09
        call    fn_read_keyboard_line
        pop    bc
        or    c
        ld    c,#00
        bit    0,a
        jr    z,#28E1
        set    2,c
        bit    1,a
        jr    z,#28E7
        set    4,c
        bit    2,a
        jr    z,#28ED
        set    0,c
        bit    3,a
        jr    z,#28F3
        set    1,c
        bit    4,a
        jr    z,#28F9
        set    3,c
        bit    5,a
        jr    z,#28FF
        set    5,c
        jr    loc_2901
loc_2901:
        ld    a,#05
        push    bc
        call    fn_read_keyboard_line
        pop    bc
        rrca
        rrca
        and    #20
        or    c
        ld    c,a
        ld    (var_input_result),a
        ret
        ld    hl,tbl_joystick_mask_0
        call    fn_read_joystick_table
        jr    z,#291C
        set    0,c
        ld    hl,tbl_joystick_mask_1
        call    fn_read_joystick_table
        jr    z,#2926
        set    1,c
        ld    hl,tbl_joystick_mask_2
        call    fn_read_joystick_table
        jr    z,#2930
        set    2,c
        ld    hl,tbl_joystick_mask_3
        call    fn_read_joystick_table
        jr    z,#293A
        set    3,c
        ld    hl,tbl_joystick_mask_4
        call    fn_read_joystick_table
        jr    z,#2944
        set    4,c
        jr    loc_2901
fn_read_joystick_table:
        ; Teste une table (ligne,masque) terminée par 0xFF, utilisée par
        ; fn_read_input
        ld    b,#00
loc_2948:
        ld    a,(hl)
        inc    hl
        cp    #FF
        jr    z,#2959
        push    bc
        call    fn_read_keyboard_line
        pop    bc
        and    (hl)
        inc    hl
        or    b
        ld    b,a
        jr    loc_2948
        ld    a,b
        and    a
        ret
tbl_joystick_mask_0:
        ; 5 tables (ligne clavier, masque bit) pour la lecture joystick, terminées
        ; par 0xFF. Tbl_joystick_mask_4 était précédemment placée à 0x2988 par
        ; erreur, ce qui coupait tbl_joystick_mask_3 en deux avant sa vraie fin
        ; (0x2983-0x2992, 15 octets) — confirmé par lecture directe des appels de
        ; fn_read_input (ld hl,#2992 à 0x293A, jamais 0x2988)
        defb #08,#80,#07,#40,#06,#40,#04,#40,#03,#80,#02,#40,#FF
tbl_joystick_mask_1:
        ; 5 tables (ligne clavier, masque bit) pour la lecture joystick, terminées
        ; par 0xFF. Tbl_joystick_mask_4 était précédemment placée à 0x2988 par
        ; erreur, ce qui coupait tbl_joystick_mask_3 en deux avant sa vraie fin
        ; (0x2983-0x2992, 15 octets) — confirmé par lecture directe des appels de
        ; fn_read_input (ld hl,#2992 à 0x293A, jamais 0x2988)
        defb #07,#80,#06,#80,#05,#40,#04,#80,#03,#40,#FF
tbl_joystick_mask_2:
        ; 5 tables (ligne clavier, masque bit) pour la lecture joystick, terminées
        ; par 0xFF. Tbl_joystick_mask_4 était précédemment placée à 0x2988 par
        ; erreur, ce qui coupait tbl_joystick_mask_3 en deux avant sa vraie fin
        ; (0x2983-0x2992, 15 octets) — confirmé par lecture directe des appels de
        ; fn_read_input (ld hl,#2992 à 0x293A, jamais 0x2988)
        defb #08,#20,#07,#30,#06,#30,#05,#30,#04,#30,#03,#30,#02,#08,#FF
tbl_joystick_mask_3:
        ; 5 tables (ligne clavier, masque bit) pour la lecture joystick, terminées
        ; par 0xFF. Tbl_joystick_mask_4 était précédemment placée à 0x2988 par
        ; erreur, ce qui coupait tbl_joystick_mask_3 en deux avant sa vraie fin
        ; (0x2983-0x2992, 15 octets) — confirmé par lecture directe des appels de
        ; fn_read_input (ld hl,#2992 à 0x293A, jamais 0x2988)
        defb #08,#08,#07,#0C,#06,#0C,#05,#0C,#04,#0C,#03,#0C,#02,#02,#FF
tbl_joystick_mask_4:
        ; 5 tables (ligne clavier, masque bit) pour la lecture joystick, terminées
        ; par 0xFF. Tbl_joystick_mask_4 était précédemment placée à 0x2988 par
        ; erreur, ce qui coupait tbl_joystick_mask_3 en deux avant sa vraie fin
        ; (0x2983-0x2992, 15 octets) — confirmé par lecture directe des appels de
        ; fn_read_input (ld hl,#2992 à 0x293A, jamais 0x2988)
        defb #08,#03,#07,#03,#06,#03,#05,#03,#04,#03,#03,#03,#02,#01,#FF
tbl_wait_any_key_all_rows:
        ; Table (ligne clavier, masque) pour fn_read_joystick_table, meme format
        ; que tbl_joystick_mask_0..4, mais utilisee pour detecter N'IMPORTE QUELLE
        ; touche: 9 paires (ligne 0-8, masque #FF) puis terminateur #FF. PAS
        ; appelee par fn_read_input -- 3 appelants trouves par recherche statique
        ; (#0AFC dans fn_sound_program_step, #1369/#1381 dans une routine
        ; d'attente non nommee entre #1369-#1391, elle-meme appelee depuis
        ; fn_game_over_or_daycycle_end #1377/#13B1): boucle d'attente 'relachement
        ; ou timeout' avant de continuer, teste TOUTE touche/direction active via
        ; ce masque generique plutot qu'une touche precise.
        defb #00,#FF,#01,#FF,#02,#FF,#03,#FF,#04,#FF,#05,#FF,#06,#FF,#07,#FF
        defb #08,#FF,#FF
fn_init_room_entities:
        ; Copie un template de 2 entités (56 octets) vers 0x00D7
        ld    hl,tbl_init_entities_template
        ld    de,struct_entities_base
        push    de
        pop    ix
        ld    bc,fn_im1_interrupt_handler
        ldir
        xor    a
        ld    (var_transform_flag_and_saved_type),a
        ld    hl,var_life_counter
        dec    (hl)
        jp    m,fn_game_over_or_daycycle_end
        ld    a,(var_day_night_flag)
        rrca
        rrca
        rrca
        and    #20
        ld    c,a
        ld    a,(ix+off_transform_step_counter)
        and    #1F
        add    a,c
        ld    (ix+off_transform_step_counter),a
        ld    a,(ix+#2C)
        and    #0F
        add    a,c
        add    a,#20
        ld    (ix+#2C),a
        ret
tbl_init_entities_template:
        ; Template de 56 octets (2×28, joueur + entité "jambes" compagne) copié
        ; vers struct_entities_base (0x00D7) par fn_init_room_entities (0x29B4) —
        ; mais PAS uniquement une donnée ROM figée: c'est aussi la DESTINATION
        ; d'un checkpoint écrit à chaque franchissement de porte par la queue
        ; commune de fn_player_door_transition (#2383-#23A2, voir 0x2322 extension
        ; ci-dessus) — LDIR de struct_entities_base VERS
        ; tbl_init_entities_template, puis type forcé à #78 (sentinelle
        ; matérialisation). Reste ouvert: lien exact avec le mécanisme de perte de
        ; vie (voir 0x2322 extension) et confirmation empirique en jeu (test en
        ; direct: franchir une porte puis lire 0x29EB et vérifier qu'elle
        ; correspond à la position au moment du franchissement — pas fait,
        ; uniquement dérivé du désassemblage).
        defb #00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00
        defb #00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00
        defb #00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00
        defb #00,#00,#00,#00,#00,#00,#00,#00
tbl_room_selection_entity_template_a:
        ; Octets 0-7 (type/grid_x/grid_y/grid_z/bbox_w/bbox_h/bbox_d/flags, cf
        ; off_* de struct_entities_base) copies par LDIR (BC=8, litteralement
        ; l'adresse de rst_add_hl_a #0008 reutilisee comme constante numerique)
        ; vers tbl_init_entities_template (#29EB, template joueur) au debut de
        ; fn_init_room_selection (#2A33) -- remet grid_x/y/z au centre
        ; (#80,#80,#80) avant que room_number/etc. Ne soient ecrits juste apres
        ; par la meme routine.
        defb #78,#80,#80,#80,#05,#05,#17,#1C
tbl_room_selection_entity_template_b:
        ; Suite immediate de tbl_room_selection_entity_template_a: memes 8 octets
        ; (type/grid_x/grid_y/grid_z/bbox_w/bbox_h/bbox_d/flags) pour le 2e
        ; template d'entite (#2A07, compagnon), copies par le 2e LDIR de
        ; fn_init_room_selection (#2A33).
        defb #78,#80,#80,#8C,#05,#05,#00,#1E
fn_init_room_selection:
        ; (proposée et confirmée: "la pièce de démarrage est aléatoire parmi une
        ; sélection"). Copie les templates statiques d'entités vers 0x29EB/0x2A07,
        ; puis choisit la salle de départ parmi EXACTEMENT 4 valeurs fixes (table
        ; tbl_start_room_choices, 0x2A64) via l'index (0x0068)&3. Écrit le choix
        ; dans les 2 templates (0x29F3 et 0x2A0F).
        ld    hl,tbl_room_selection_entity_template_a
        ld    de,tbl_init_entities_template
        ld    bc,rst_add_hl_a
        ldir
        ld    de,#2A07
        ld    bc,rst_add_hl_a
        ldir
        ld    a,#12
        ld    (#29FB),a
        ld    a,#22
        ld    (#2A17),a
        ld    a,(var_newgame_random_seed)
        and    #03
        ld    l,a
        ld    h,#00
        ld    bc,tbl_start_room_choices
        add    hl,bc
        ld    a,(hl)
        ld    (#29F3),a
        ld    (#2A0F),a
        ret
tbl_start_room_choices:
        ; Renommée (était "tbl_room_variant_4", hypothèse imprécise). 4 octets:
        ; les 4 salles de départ possibles au lancement d'une partie — 0x2F, 0x44,
        ; 0xB3, 0x8F. Sélectionnées via (0x0068)&3 dans fn_init_room_selection
        ; (0x2A33). Confirme et résout la proposition: "la pièce de démarrage est
        ; aléatoire (parmi une sélection)".
        defb #2F,#44,#B3,#8F
fn_init_room:
        ; Reset room/niveau: si var_room_transition_flag≠0, resynchronise le
        ; catalogue (fn_object_catalog_writeback #1E67), efface le buffer de rendu
        ; intermédiaire 0x9000-0xBFFF, charge la salle (fn_load_room_data #2C3A),
        ; instancie les objets (fn_instantiate_room_objects #1DFB) puis les
        ; jonctions porte/mur (fn_room_transition #2B8D), remet à 0
        ; var_room_reset_flag_1/2/3/4, positionne var_render_disabled_flag=1,
        ; calcule var_room_reset_flag_5 depuis bit0 de (0x00DF). Corrige un octet
        ; mal transcrit: (0x2AB5) est CB,C6 (SET 0,(HL)), pas CB,E6 comme
        ; précédemment dans asm/code/room_init_and_nav.asm. La suite (#2A9A+) est
        ; désassemblée — voir fn_init_room_mark_room_visited (#2A9A) ci-dessous.
        ; Elle n'est en fait qu'une simple queue directe du jp inconditionnel de
        ; fin; le module décor/HUD qui la suit en mémoire (#2AB8-#2B8D) est une
        ; famille de routines de dessin générique partagée avec d'autres appelants
        ; (low_ram_and_boot.asm #0638, entity_logic_mechanical.asm game-over
        ; #1362/#1395/#15D3), PAS spécifique à fn_init_room
        ld    a,(var_room_transition_flag)
        and    a
        jr    z,#2A71
        call    fn_object_catalog_writeback
        call    fn_clear_intermediate_buffer
        call    fn_load_room_data
        call    fn_instantiate_room_objects
        call    fn_room_transition
        xor    a
        ld    (var_room_reset_flag_1),a
        ld    (var_room_reset_flag_2),a
        ld    (var_room_reset_flag_3),a
        ld    (var_room_reset_flag_4),a
        ld    a,#01
        ld    (var_render_disabled_flag),a
        ld    a,(var_player_room_number)
        and    #01
        ld    (var_room_reset_flag_5),a
        jp    fn_init_room_mark_room_visited
fn_init_room_mark_room_visited:
        ; Queue directe de fn_init_room (cible de son jp inconditionnel de fin,
        ; pas un point d'entrée externe). Calcule L=A>>3 et n=A&7 où
        ; A=var_player_room_number (0x00DF), construit dynamiquement l'opcode SET
        ; n,(HL) (auto-modification à 0x2AB6), puis l'exécute sur (0x00B7+L).
        ; HYPOTHÈSE (structure certaine, sémantique déduite): positionne le bit
        ; var_player_room_number & 7 de l'octet
        ; var_room_visited_bitmap+(var_player_room_number/8) — bitmap 32
        ; octets/256 bits se terminant pile à struct_entities_base (0x00D7), dont
        ; le nombre de bits à 1 est ensuite compté par
        ; fn_pickup_progress_display_calc (#14F5) pour le score de fin de partie.
        ; Marque donc la salle courante comme visitée à chaque (re)chargement de
        ; salle
        ld    a,(var_player_room_number)
        ld    c,a
        rrca
        rrca
        rrca
        and    #1F
        ld    l,a
        ld    h,#00
        ld    a,c
        rlca
        rlca
        rlca
        and    #38
        or    #C6
        ld    (#2AB6),a
        ld    bc,var_room_visited_bitmap
        add    hl,bc
        set    0,(hl)
        ret
fn_hud_record_load_fields:
        ; Lit 4 octets à (HL) → (ix+type)/(ix+flags)/(ix+screen_x)/(ix+screen_y),
        ; avance HL de 4. Helper générique pour parcourir une table
        ; d'enregistrements de dessin HUD (type/flags/position écran)
        ld    a,(hl)
        inc    hl
        ld    (ix+off_type),a
        ld    a,(hl)
        inc    hl
        ld    (ix+off_flags),a
        ld    a,(hl)
        inc    hl
        ld    (ix+off_screen_x),a
        ld    a,(hl)
        inc    hl
        ld    (ix+off_screen_y),a
        ret
fn_hud_icon_draw_from_table:
        ; CALL fn_hud_record_load_fields puis CALL fn_sprite_pipeline_setup
        ; (#2F2B) — dessine une icône/tuile depuis un enregistrement de table et
        ; avance au suivant. Brique de base de fn_hud_decor_calibration et
        ; fn_game_over_border_draw
        call    fn_hud_record_load_fields
        push    hl
        call    loc_2F2B
        pop    hl
        ret
fn_hud_decor_calibration:
        ; IX=#1877 (scratch), HL=tbl_hud_decor_calibration_records (#2B0F). Deux
        ; appels à fn_hud_decor_calibration_group avec DE=#F810 puis DE=#0810
        ; (diagonales miroir), puis JP fn_hud_icon_draw_from_table (icône finale
        ; isolée)
        ld    ix,#1877
        ld    hl,tbl_hud_decor_calibration_records
        ld    de,#F810
        call    fn_hud_decor_calibration_group
        ld    de,#0810
        call    fn_hud_decor_calibration_group
        jp    fn_hud_icon_draw_from_table
fn_hud_decor_calibration_group:
        ; Consomme 5 enregistrements de tbl_hud_decor_calibration_records: 1 icône
        ; en diagonale répétée 5x (pas DE fourni par l'appelant, via #178D dans
        ; menu_and_materialize.asm), 2 icônes directes (fn_hud_icon_draw_loop), 1
        ; barre verticale de 36 pas de 1px, 1 icône finale
        call    fn_hud_record_load_fields
        ld    b,#05
        call    loc_178D
        ld    b,#02
        call    fn_hud_icon_draw_loop
        call    fn_hud_record_load_fields
        ld    de,#0100
        ld    b,#24
        call    loc_178D
        jp    fn_hud_icon_draw_from_table
fn_hud_icon_draw_loop:
        ; PUSH BC / CALL fn_hud_icon_draw_from_table / POP BC / DJNZ — dessine B
        ; icônes consécutives sans déplacement, contrairement à #178D
        push    bc
        call    fn_hud_icon_draw_from_table
        pop    bc
        djnz    fn_hud_icon_draw_loop
        ret
tbl_hud_decor_calibration_records:
        ; 11 enregistrements de 4 octets (type,flags,screen_x,screen_y), consommés
        ; exactement par fn_hud_decor_calibration (fin pile à #2B3B). Types
        ; observés #86/#87/#88/#C0/#C1 (x2 groupes miroir flags #00/#40) + #8C
        ; final
        defb #86,#00,#10,#34,#87,#00,#F0,#00,#88,#00,#90,#04,#C0,#00,#F0,#0A
        defb #C1,#00,#F0,#2E,#86,#40,#A0,#14,#87,#40,#00,#00,#88,#40,#60,#04
        defb #C0,#40,#00,#0A,#C1,#40,#00,#2E,#8C,#00,#10,#20
fn_game_over_border_draw:
        ; IX=#1877, HL=tbl_game_over_border_records (#2B6D). 4 icônes directes
        ; (coins) + 2 lignes horizontales de 24 icônes espacées de 8px + 2 lignes
        ; verticales de 128 icônes espacées de 1px — dessine le cadre/bordure de
        ; l'écran de fin de partie via le pipeline sprite générique
        ld    ix,#1877
        ld    hl,tbl_game_over_border_records
        ld    b,#04
        call    fn_hud_icon_draw_loop
        call    fn_hud_record_load_fields
        ld    de,rst_add_hl_a
        ld    b,#18
        call    loc_178D
        call    fn_hud_record_load_fields
        ld    b,#18
        call    loc_178D
        call    fn_hud_record_load_fields
        ld    de,#0100
        ld    b,#80
        call    loc_178D
        call    fn_hud_record_load_fields
        ld    b,#80
        jp    loc_178D
tbl_game_over_border_records:
        ; 8 enregistrements de 4 octets, consommés exactement par
        ; fn_game_over_border_draw (fin pile à #2B8D = fn_room_transition, déjà
        ; confirmée). Types observés #89 (x4, coins) puis #8B/#8B/#8A/#8A (bords)
        defb #89,#00,#00,#A0,#89,#40,#E0,#A0,#89,#C0,#E0,#02,#89,#80,#00,#02
        defb #8B,#00,#20,#A8,#8B,#00,#20,#00,#8A,#00,#00,#20,#8A,#00,#E8,#20
fn_room_transition:
        ; Voir plus haut — appelée dans fn_init_room ET lors du mouvement du
        ; joueur
        ld    a,(var_camera_reference)
        sub    #02
        ld    l,a
        ld    a,(var_camera_reference_y)
        sub    #02
        ld    h,a
        ld    a,(ix+off_grid_x)
        and    a
        jr    z,fn_room_transition_edge_x_min
        inc    a
        jr    z,fn_room_transition_edge_x_max
        ld    a,(ix+off_grid_y)
        and    a
        jr    z,fn_room_transition_edge_y_min
        inc    a
        jr    z,fn_room_transition_edge_y_max
        ret
fn_room_transition_edge_y_max:
        ; Bord grid_y au MAX (0xFF): C=0xC8, CALL fn_resolve_neighbor_room,
        ; nouveau grid_y = 0x80 - H - bbox_h (repositionne au bord oppose de la
        ; salle voisine), SET bit4 de flags ET de busy_flag (retraitement +
        ; verrou), sauvegarde pending_grid_x/y = (ix+01)/(ix+02) courants.
        ld    c,#C8
        call    fn_resolve_neighbor_room
        ld    a,#80
        sub    h
        sub    (ix+off_bbox_h)
loc_2BB7:
        ld    (ix+off_grid_y),a
loc_2BBA:
        set    4,(ix+off_flags)
        set    4,(ix+off_busy_flag)
        ld    a,(ix+off_grid_x)
        ld    (ix+off_pending_grid_x),a
        ld    a,(ix+off_grid_y)
        ld    (ix+off_pending_grid_y),a
        ret
fn_room_transition_edge_y_min:
        ; Bord grid_y au MIN (0): C=0x51, CALL fn_resolve_neighbor_room, nouveau
        ; grid_y = H + 0x80 + bbox_h, rejoint la queue de stockage de
        ; fn_room_transition_edge_y_max (#2BB7).
        ld    c,#51
        call    fn_resolve_neighbor_room
        ld    a,h
        add    a,#80
        add    a,(ix+off_bbox_h)
        jr    loc_2BB7
fn_room_transition_edge_x_max:
        ; Bord grid_x au MAX (0xFF): C=0xAE, CALL fn_resolve_neighbor_room,
        ; nouveau grid_x = 0x80 - L - bbox_w, rejoint la queue commune de
        ; flags/pending (#2BBA, partagee avec l'axe Y).
        ld    c,#AE
        call    fn_resolve_neighbor_room
        ld    a,#80
        sub    l
        sub    (ix+off_bbox_w)
loc_2BE7:
        ld    (ix+off_grid_x),a
        jr    loc_2BBA
fn_room_transition_edge_x_min:
        ; Bord grid_x au MIN (0): C=0x37, CALL fn_resolve_neighbor_room, nouveau
        ; grid_x = L + 0x80 + bbox_w, rejoint la queue de stockage de
        ; fn_room_transition_edge_x_max (#2BE7).
        ld    c,#37
        call    fn_resolve_neighbor_room
        ld    a,l
        add    a,#80
        add    a,(ix+off_bbox_w)
        jr    loc_2BE7
fn_resolve_neighbor_room:
        ; Voir fn_resolve_neighbor_room_apply pour la suite — RÉVISE une
        ; hypothèse: la queue (+0x1F=room_transition_extra) lit (iy+03) de
        ; l'entrée trouvée, qui d'après le format déjà confirmé de
        ; tbl_room_connection_detail_*/tbl_room_junction_entity_template_* est une
        ; CONSTANTE d'élévation 0x80 (pas un numéro de room) — donc
        ; room_transition_extra vaut très probablement toujours 0x8C, PAS "nouveau
        ; numéro de room+0x0C" comme précédemment supposé.
        ld    iy,tbl_room_connections
        ld    de,fn_im1_interrupt_handler
        ld    b,#04
loc_2C02:
        ld    a,(iy+off_type)
        cp    #06
        ret    nc
        ld    a,(iy+off_grid_x)
        add    a,(iy+off_grid_y)
        cp    c
        jr    z,fn_resolve_neighbor_room_apply
        add    iy,de
        djnz    loc_2C02
        ret
fn_resolve_neighbor_room_apply:
        ; Queue de fn_resolve_neighbor_room, DESASSEMBLEE (etait defb): A=(iy+03)
        ; [grid_z_or_offset de l'entree de connexion trouvee -- CONSTANT 0x80
        ; d'apres le format deja confirme de
        ; tbl_room_connection_detail_*/tbl_room_junction_entity_template_*, PAS un
        ; numero de room], ecrit dans (ix+03) [grid_z_or_offset de l'entite en
        ; transition], puis A+=0x0C, ecrit dans (ix+1F) [room_transition_extra].
        ; L'hypothese precedente: la valeur source (iy+03) etant une constante
        ; d'elevation (0x80), (ix+1F) vaut tres probablement toujours 0x8C -- la
        ; meme constante d'elevation deja confirmee ailleurs ('sur la table'), pas
        ; un numero de room. Role exact de room_transition_extra reste donc UNE
        ; HYPOTHESE REVISEE, a confirmer empiriquement (dumper ix+1F pendant un
        ; franchissement de bord reel).
        ld    a,(iy+off_grid_z_or_offset)
        ld    (ix+off_grid_z_or_offset),a
        add    a,#0C
        ld    (ix+off_room_transition_extra),a
        ret
fn_entity_index_to_ptr:
        ; HL = (ID & 0x7F) × 28 + 0x00D7 — résout index -> pointeur structure
        ; entité
        push    bc
        and    #7F
        ld    l,a
        ld    h,#00
        add    hl,hl
        add    hl,hl
        add    hl,hl
        ld    c,l
        ld    b,h
        add    hl,hl
        add    hl,bc
        srl    b
        rr    c
        add    hl,bc
        ld    bc,struct_entities_base
        add    hl,bc
        pop    bc
        ret
fn_load_room_data:
        ; Recherche linéaire dans tbl_room_master_index (0x33DD): (HL)=room_id,
        ; compare à (ix+08); si non trouvé, A=(HL)=skip_len, RST 08 (HL+=A) avance
        ; à l'entrée suivante (donc longueur totale d'entrée = 1+skip_len, voir
        ; tbl_room_master_index). Une fois trouvé: lit field_byte (bits0-2 ->
        ; (0x0073)), résout un octet du payload en index *3 vers
        ; tbl_room_master_coords (0x33D4), copie ses 3 octets vers
        ; (0x0071)/(0x0072)/(0x0074), PUIS pour chaque octet suivant du payload
        ; jusqu'à 0xFF: le traite comme index DIRECT *2 dans tbl_room_index_ptrs
        ; (0x3E6E), lit le pointeur, et copie (LDIR, BC=8) le bloc de connexion
        ; pointé dans tbl_room_connections (0x0147) -- voir
        ; tbl_room_connection_detail_* pour le format de ce bloc. Ecrit aussi
        ; (ix+08) courant en 9e octet de l'entree, puis 19 octets a zero
        ; (fn_zero_fill_de, #0031). Boucle jusqu'a 0xFF (ou B=0 via DJNZ #2C8C,
        ; max 4 entrees). La suite (#2CBA-#2D5D) — déjà décrite en prose depuis
        ; l'analyse de
        ; tbl_room_connection_ptrs/tbl_room_junction_entity_template_* — est la
        ; PHASE 2, TOUJOURS exécutée (le 0xFF ne marque que la fin de la phase 1,
        ; pas un chemin alternatif), qui construit les entités de jonction
        ; porte/mur dans tbl_room_connections à partir de tbl_room_connection_ptrs
        ; (0x3D5D) et tbl_room_junction_entity_template_* (0x3D97). DÉSASSEMBLAGE
        ; BYTE-EXACT TERMINÉ: le générateur mécanique s'arrêtait au premier jr/jp
        ; inconditionnel; 4 sous-symboles ont été posés pour couvrir chaque
        ; continuation (fn_load_room_data_clear_remaining_slots #2C54,
        ; fn_load_room_data_found_and_scan #2C62, fn_load_room_data_phase2 #2CBA,
        ; fn_load_room_data_phase2_tail #2D56, voir leurs entrées ci-dessous) —
        ; asm/code/room_init_and_nav.asm n'a plus aucun defb non expliqué sur
        ; toute sa plage. La PHASE 2 CONSTRUIT SES CHAMPS
        ; grid_x/grid_y/grid_z_or_offset PAR CALCUL, PAS PAR COPIE DIRECTE
        ; contrairement à la PHASE 1 (tbl_room_connection_detail_*, copie brute) —
        ; voir fn_load_room_data_phase2 pour le détail, ceci révise/précise
        ; fn_resolve_neighbor_room_apply (#2C16) qui documentait
        ; grid_z_or_offset=CONSTANTE 0x80 uniquement pour les entrées de PHASE 1.
        ld    de,tbl_room_connections
        ld    bc,tbl_room_connection_ptrs
        ld    hl,tbl_room_master_index
loc_2C43:
        ld    a,(hl)
        inc    hl
        cp    (ix+off_room_number)
        jr    z,fn_load_room_data_found_and_scan
        ld    a,(hl)
        rst    #08
        and    a
        sbc    hl,bc
        jr    nc,fn_load_room_data_clear_remaining_slots
        add    hl,bc
        jr    loc_2C43
fn_load_room_data_clear_remaining_slots:
        ; Sous-routine partagée de fn_load_room_data, point de sortie commun
        ; atteint depuis 3 endroits (recherche room_id épuisée, fin de phase 1,
        ; fin de phase 2): zéro-remplit (via fn_zero_fill_de #0031, 28
        ; octets/appel = taille d'un slot entité) les slots restants à partir de
        ; DE jusqu'à #0537. #0537 == fn_boot_init_and_new_game PAR PURE
        ; COÏNCIDENCE D'ADRESSE: c'est en réalité la borne haute de la table
        ; d'entités (struct_entities_base 0x00D7 + 40 slots × 28 octets = 0x0537),
        ; le code suivant démarrant sans octet de séparation — donc révèle que la
        ; table d'entités contient exactement 40 slots.
        ld    hl,fn_boot_init_and_new_game
        and    a
        sbc    hl,de
        ret    z
        ld    b,#1C
        call    fn_zero_fill_de
        jr    fn_load_room_data_clear_remaining_slots
fn_load_room_data_found_and_scan:
        ; Suite de fn_load_room_data une fois le room_id trouvé: décode l'octet de
        ; longueur, bits0-2 du suivant → var_sparkle_and_jingle_phase, résout un
        ; index vers tbl_room_master_coords et copie 3 octets vers
        ; var_camera_reference/var_camera_reference_y/var_room_data_field_2, puis
        ; exécute la PHASE 1 (déjà décrite en prose ci-dessus, désormais
        ; désassemblée byte-exact): jusqu'à 4 blocs de connexion de 28 octets
        ; chacun (8 copiés + room_number + 19 zéro), jusqu'à l'octet #FF ou 4
        ; blocs.
        ld    b,(hl)
        inc    hl
        ld    a,(hl)
        and    #07
        ld    (var_sparkle_and_jingle_phase),a
        push    de
        ex    de,hl
        ld    a,(de)
        inc    de
        rrca
        rrca
        rrca
        and    #1F
        ld    c,a
        add    a,a
        add    a,c
        ld    hl,tbl_room_master_coords
        rst    #08
        ld    a,(hl)
        inc    hl
        ld    (var_camera_reference),a
        ld    a,(hl)
        inc    hl
        ld    (var_camera_reference_y),a
        ld    a,(hl)
        ld    (var_room_data_field_2),a
        dec    b
        dec    b
        ex    de,hl
        pop    de
loc_2C8C:
        ld    a,(hl)
        inc    hl
        cp    #FF
        jr    z,fn_load_room_data_phase2
        push    bc
        push    hl
        ld    l,a
        ld    h,#00
        add    hl,hl
        ld    bc,tbl_room_index_ptrs
        add    hl,bc
        ld    a,(hl)
        inc    hl
        ld    h,(hl)
        ld    l,a
        ld    bc,rst_add_hl_a
        ldir
        ld    a,(ix+off_room_number)
        ld    (de),a
        inc    de
        ld    b,#13
        call    fn_zero_fill_de
        ld    a,(hl)
        and    a
        jr    nz,#2CA0
        pop    hl
        pop    bc
        djnz    loc_2C8C
        jp    fn_load_room_data_clear_remaining_slots
fn_load_room_data_phase2:
        ; Toujours executee. IY=DE (curseur d'ecriture dans tbl_room_connections,
        ; continue ou la phase 1 s'est arretee). C=((HL)&7)+1 (nombre d'entites de
        ; jonction pour cette connexion). Boucle : lit un index vers
        ; tbl_room_connection_ptrs, resout un pointeur vers un
        ; tbl_room_junction_entity_template_*, copie type/+4/+5/+6/flags (5 octets
        ; directs, PAS grid_x/y/z) vers l'entite, room_number courant -> +8 ;
        ; CALCULE (au lieu de copier) grid_x/grid_y/grid_z_or_offset a partir d'un
        ; 6e octet du template, du code de direction (registre D) et de
        ; var_room_data_field_2 (#0074) -- contrairement a la PHASE 1
        ; (tbl_room_connection_detail_*, copie brute avec grid_z_or_offset
        ; constant #80), la phase 2 calcule ce champ. Avance IY de 9 puis zero-
        ; remplit 19 octets de plus (28 au total, meme taille de slot qu'en phase
        ; 1). Si le 7e octet du template (relu) est non-nul, reboucle pour un 2e
        ; sous-bloc de 6 octets dans le meme enregistrement (explique les
        ; templates de 13 octets = 7+6, vs 7 pour les autres). Puis decompte B
        ; (bloc de connexion suivant) et C (entite suivante de cette connexion).
        dec    b
        push    iy
        push    de
        pop    iy
        ld    a,(hl)
        and    #07
        inc    a
        ld    c,a
        ld    a,(hl)
        inc    hl
        dec    b
        ld    d,(hl)
        inc    hl
        push    hl
        rrca
        rrca
        and    #3E
        ld    hl,tbl_room_connection_ptrs
        rst    #08
        ld    a,(hl)
        inc    hl
        ld    h,(hl)
        ld    l,a
loc_2CD7:
        push    hl
        ld    a,(hl)
        inc    hl
        ld    (iy+off_type),a
        ld    a,(hl)
        inc    hl
        ld    (iy+off_bbox_w),a
        ld    a,(hl)
        inc    hl
        ld    (iy+off_bbox_h),a
        ld    a,(hl)
        inc    hl
        ld    (iy+off_bbox_d),a
        ld    a,(hl)
        inc    hl
        ld    (iy+off_flags),a
        ld    a,(ix+off_room_number)
        ld    (iy+off_room_number),a
        ld    a,(hl)
        rlca
        rlca
        rlca
        and    #08
        ld    e,a
        ld    a,d
        rlca
        rlca
        rlca
        rlca
        and    #70
        add    a,e
        add    a,#48
        ld    (iy+off_grid_x),a
        ld    a,(hl)
        rlca
        rlca
        and    #08
        ld    e,a
        ld    a,d
        rlca
        and    #70
        add    a,e
        add    a,#48
        ld    (iy+off_grid_y),a
        ld    a,d
        rlca
        rlca
        and    #03
        add    a,a
        add    a,a
        ld    e,a
        add    a,a
        add    a,e
        add    a,(hl)
        inc    hl
        and    #FC
        ld    e,a
        ld    a,(var_room_data_field_2)
        add    a,e
        ld    (iy+off_grid_z_or_offset),a
        push    bc
        ld    bc,#0009
        add    iy,bc
        ld    b,#13
loc_2D39:
        ld    (iy+off_type),#00
        inc    iy
        djnz    loc_2D39
        pop    bc
        ld    a,(hl)
        and    a
        jr    nz,#2CD8
        pop    de
        pop    hl
        dec    b
        jr    z,fn_load_room_data_phase2_tail
        dec    c
        jp    z,#2CC0
        ld    a,(hl)
        inc    hl
        push    hl
        ex    de,hl
        ld    d,a
        jr    loc_2CD7
fn_load_room_data_phase2_tail:
        ; Fin de fn_load_room_data_phase2: DE=IY (position d'écriture courante),
        ; JP fn_load_room_data_clear_remaining_slots — nettoyage final, point de
        ; sortie de tout fn_load_room_data.
        push    iy
        pop    de
        pop    iy
        jp    fn_load_room_data_clear_remaining_slots
fn_mul8x16:
        ; HL = A × DE, multiplication shift-and-add
        push    bc
        ld    hl,fn_cold_boot_entry
        ld    b,#08
loc_2D64:
        add    hl,hl
        rlca
        jr    nc,#2D69
        add    hl,de
        djnz    loc_2D64
        pop    bc
        ret
fn_wait_keyboard_sync:
        ; Lit la ligne clavier 2 (fn_read_keyboard_line), teste bit5 du résultat.
        ; Si absent au premier test: RET immédiat. Sinon: attend le relâchement,
        ; puis un nouvel appui, puis un nouveau relâchement, avant de RET — un
        ; cycle complet appui+relâche, PAS une simple synchro PSG générique
        ; (l'ancienne hypothèse était trop vague). Rôle exact ouvert: quelle
        ; touche correspond à bit5/ligne2, et pourquoi ce test est fait (semble-t-
        ; il) chaque frame depuis fn_main_loop — non identifié
        ld    a,#02
        call    fn_read_keyboard_line
        bit    5,a
        ret    z
        ld    a,#02
        call    fn_read_keyboard_line
        bit    5,a
        jr    nz,#2D75
        ld    a,#02
        call    fn_read_keyboard_line
        bit    5,a
        jr    z,#2D7E
        ld    a,#02
        call    fn_read_keyboard_line
        bit    5,a
        jr    nz,#2D87
        ret
fn_mem_fill_simple:
        ; LD (HL),E / INC HL / DEC BC en boucle — remplissage mémoire générique
        ld    e,#00
        ld    (hl),e
        inc    hl
        dec    bc
        ld    a,b
        or    c
        jr    nz,#2D93
        ret
fn_clear_screen:
        ; Efface l'écran complet 0xC000, gère l'entrelacement CRTC
        ld    hl,VRAM_BASE
        ld    c,#19
        ld    b,#50
        push    hl
loc_2DA3:
        ld    (hl),#00
        inc    hl
        djnz    loc_2DA3
        pop    hl
        ld    de,#0800
        add    hl,de
        jr    nc,#2DA0
        ld    de,#C050
        add    hl,de
        dec    c
        jr    nz,#2DA0
        ret
fn_clear_intermediate_buffer:
        ; LD BC,#3000 / LD HL,#9000 / JR fn_mem_fill_simple (l'entrée #2D91 force
        ; E=0) — efface entièrement le buffer de rendu intermédiaire 0x9000-0xBFFF
        ; (voir fn_buffer_addr_from_vram #3186). Seul appelant trouvé:
        ; fn_init_room (#2A71), juste avant fn_load_room_data — cohérent avec un
        ; nettoyage complet du buffer de travail à chaque (re)chargement de salle
        ld    bc,#3000
        ld    hl,BUF_PRERENDER_BASE
        jr    fn_mem_fill_simple
fn_copy_screen_rect:
        ; Copie rectangulaire écran→écran via LDIR
        ld    hl,#BFC0
        ld    de,#C008
        ld    b,#C0
loc_2DC7:
        push    bc
        push    hl
        ld    bc,#0040
        ldir
        ld    hl,#07C0
        add    hl,de
        jr    nc,#2DD8
        ld    de,#C050
        add    hl,de
        ex    de,hl
        pop    hl
        ld    bc,#FFC0
        add    hl,bc
        pop    bc
        djnz    loc_2DC7
        ret
fn_render_entities:
        ; Orchestre TOUT le rendu d'une frame en 3 étapes imbriquées (pas 2 passes
        ; séparées comme documenté précédemment): (1) #2DF5-#2E97 — pour chaque
        ; entité du buffer filtré (0x2720) avec bit5 de (ix+07) actif ("à
        ; retraiter"): résout le pointeur struct (0x2C22), calcule le rectangle
        ; sale = UNION des bbox écran précédente (ix+18..1B) et courante
        ; (ix+14..17), convertit en adresses VRAM (0x3195) + buffer intermédiaire
        ; (0x3186) via fn_stage_blit_and_clear (0x2E6C) qui empile BC/DE/HL
        ; (params pour le blit final différé) et incrémente var_blit_stack_counter
        ; (0x0070), PUIS efface immédiatement ce rectangle DANS LE BUFFER
        ; INTERMÉDIAIRE (0x1DC1) pour retirer les pixels de l'ancienne position
        ; avant redessin. (2) #2E97 — appelle fn_check_collisions (0x2750), qui
        ; teste toutes les paires AABB ET, une fois qu'une entité a fini d'être
        ; testée contre toutes les autres, appelle elle-même
        ; fn_sprite_pipeline_setup (0x2F17, call à #28A4) pour la DESSINER
        ; (projection isométrique + blit masqué) à sa position courante dans le
        ; buffer intermédiaire — la logique de collision et le dessin sont donc
        ; imbriqués dans la même boucle, pas séquentiels. (3) retour de
        ; fn_check_collisions: call 1C44 (HUD jour/nuit), call 1802 (HUD
        ; notification), (0x0084) += (0x0070), puis la boucle différée #2EAA-#2EBB
        ; dépile chaque triple BC/DE/HL staged à l'étape (1) et appelle
        ; fn_blit_copy_line (0x2EC0) pour copier chaque rectangle sale du buffer
        ; intermédiaire (maintenant à jour) vers la VRAM réelle. Voir aussi
        ; 0x0070/0x0084/0x2750/0x2F17
        xor    a
        ld    (var_blit_stack_counter),a
        push    ix
        ld    a,(var_render_disabled_flag)
        and    a
        jp    nz,#2E97
        ld    hl,buf_visible_entities
        ld    (var_entity_list_cursor),hl
loc_2DF5:
        ld    hl,(var_entity_list_cursor)
        ld    a,(hl)
        inc    hl
        ld    (var_entity_list_cursor),hl
        cp    #FF
        jp    z,#2E97
        call    fn_entity_index_to_ptr
        push    hl
        pop    ix
        bit    5,(ix+off_flags)
        jr    z,loc_2DF5
        res    5,(ix+off_flags)
        ld    a,(ix+off_screen_x)
        sub    (ix+off_screen_x_prev)
        jp    c,#2E8D
        ld    c,(ix+off_screen_x_prev)
loc_2E1E:
        ld    a,(ix+off_screen_x_prev)
        rrca
        rrca
        and    #3F
        add    a,(ix+off_screen_w_prev)
        ld    e,a
        ld    a,(ix+off_screen_x)
        rrca
        rrca
        and    #3F
        add    a,(ix+off_screen_w)
        cp    e
        jr    c,#2E37
        ld    e,a
        ld    a,c
        rrca
        rrca
        and    #3F
        ld    b,a
        ld    a,e
        sub    b
        ld    h,a
        ld    a,(ix+off_screen_y)
        sub    (ix+off_screen_y_prev)
        jr    c,#2E92
        ld    b,(ix+off_screen_y_prev)
loc_2E4B:
        ld    a,(ix+off_screen_y_prev)
        add    a,(ix+off_screen_h_prev)
        ld    e,a
        ld    a,(ix+off_screen_y)
        add    a,(ix+off_screen_h)
        cp    e
        jr    nc,#2E5C
        ld    a,e
        sub    b
        ld    l,a
        ld    a,b
        cp    #C0
        jr    nc,loc_2DF5
        add    a,l
        sub    #C0
        jr    c,fn_stage_blit_and_clear
        neg
        add    a,l
        ld    l,a
fn_stage_blit_and_clear:
        ; Appelée depuis fn_render_entities (0x2DE2, passe 1) avec BC/HL =
        ; rectangle "sale" (union bbox écran précédente ix+18..1B ∪ courante
        ; ix+14..17). Calcule adresse VRAM (0x3195) + adresse buffer intermédiaire
        ; (0x3186), empile BC/DE/HL (params conservés pour le blit différé final
        ; vers la VRAM, dépilés par la boucle 0x2EAA-0x2EBB), incrémente
        ; var_blit_stack_counter (0x0070), PUIS efface immédiatement ce rectangle
        ; dans le buffer intermédiaire (0x1DC1, PAS directement l'écran) pour
        ; retirer les pixels de l'ancienne position avant que fn_check_collisions
        ; ne déclenche le redessin de chaque entité à sa position courante
        ld    a,b
        add    a,l
        dec    a
        ld    b,a
        call    fn_screen_addr_from_bc
        ld    a,c
        ld    c,l
        ld    l,a
        ld    a,b
        ld    b,h
        ld    h,a
        call    fn_buffer_addr_from_vram
        ld    a,(var_blit_stack_counter)
        inc    a
        ld    (var_blit_stack_counter),a
        push    bc
        push    de
        push    hl
        xor    a
        call    fn_fill_rect
        jp    loc_2DF5
        ld    c,(ix+off_screen_x)
        jr    loc_2E1E
        ld    b,(ix+off_screen_y)
        jr    loc_2E4B
        call    fn_check_collisions
        call    fn_hud_day_night_cycle
        call    fn_hud_slot_notification
        ld    hl,var_blit_stack_counter
        ld    a,(var_blit_stack_accumulator)
        add    a,(hl)
        ld    (var_blit_stack_accumulator),a
loc_2EAA:
        ld    hl,var_blit_stack_counter
        ld    a,(hl)
        and    a
        jr    z,#2EBD
        dec    (hl)
        pop    hl
        pop    de
        pop    bc
        ld    a,b
        ld    b,c
        ld    c,a
        call    fn_blit_copy_line
        jr    loc_2EAA
        pop    ix
        ret
fn_blit_copy_line:
        ; Copie une ligne source→écran (LDIR), gère l'entrelacement CRTC. Source
        ; (buffer intermédiaire 0x9000+) recule de 64 octets/ligne (flip
        ; vertical), destination (VRAM) avance normalement +0x0800/+0xC050
        push    bc
        push    hl
        push    de
        ld    b,#00
        ldir
        pop    de
        ld    hl,#0800
        add    hl,de
        jr    nc,#2ED2
        ld    de,#C050
        add    hl,de
        ex    de,hl
        pop    hl
        ld    bc,#FFC0
        add    hl,bc
        pop    bc
        djnz    fn_blit_copy_line
        ret
fn_isometric_project:
        ; Projection isometrique (grid_x,grid_y) -> (screen_x,screen_y), verifiee
        ; par calcul numerique exact contre des valeurs reelles observees.
        ld    a,(ix+off_grid_x)
        add    a,(ix+off_grid_y)
        sub    #80
        add    a,(ix+off_proj_offset_x)
        ld    (ix+off_screen_x),a
        ld    a,(ix+off_grid_y)
        sub    (ix+off_grid_x)
        add    a,#80
        srl    a
        add    a,(ix+off_grid_z_or_offset)
        sub    #68
        add    a,(ix+off_proj_offset_y)
        ld    (ix+off_screen_y),a
        cp    #C0
        ret
fn_resolve_sprite_shape:
        ; (ix+00)*2 -> pointeur de forme via tbl_sprite_dispatch. Si premier octet
        ; de la forme == 0, double RET (rien a dessiner). Sinon saute dans
        ; fn_flip_sprite_shape. En-tete de struct_sprite_shape (3 octets) : octet
        ; 0 = #00 sentinelle OU bits0-5 = V (largeur en octets/ligne), bit6/bit7 =
        ; etat de flip ; octet 1 = hauteur en lignes ; octet 2 = non utilise comme
        ; pixel (peek pour un ajustement de decalage sub-octet). Le payload reel
        ; commence a addr+3. Bitmap : 2 bits/pixel, 4 pixels/octet, V octets/ligne
        ; (row_bytes = V directement).
        ld    l,(ix+off_type)
        ld    h,#00
        add    hl,hl
        ld    bc,tbl_sprite_dispatch
        add    hl,bc
        ld    e,(hl)
        inc    hl
        ld    d,(hl)
        ld    a,(de)
        and    a
        jp    nz,fn_flip_sprite_shape
        inc    sp
        inc    sp
        ret
fn_sprite_pipeline_setup:
        ; Suite du pipeline après projection+forme: (1) si (ix+00)==1, tue
        ; l'entité (met 0) et sort — sentinelle; (2) res 4,(ix+07) (consomme le
        ; flag "à retraiter"); (3) call 2EDC (fn_isometric_project) puis ret nc
        ; (entité hors-champ, culling par CARRY); (4) call 2F02
        ; (fn_resolve_sprite_shape); (5) calcule la largeur d'un pas de patch
        ; depuis l'octet de forme ((de) and 3F) et l'écrit dans l'opérande self-
        ; modifiant à 0x30AF (utilisé par la variante "aligné-octet", voir
        ; 0x30BB); (6) teste (ix+16) and 03 (2 bits bas de screen_x = décalage
        ; sub-octet): si 0 -> variante alignée-octet (jp z,30BB, unité de boucle
        ; 10 octets/colonne); sinon -> variante décalée (unité de boucle 18
        ; octets/colonne, famille 0x2F8D), le décalage exact (1-3) est conservé
        ; dans AF' via ex af,af'; dans les deux cas, l'indice de largeur (second
        ; octet de forme, and 3F) est multiplié par la taille de l'unité (10 ou
        ; 18) et ajouté à la base de la famille choisie (0x2F8D ou 0x30E3), puis
        ; écrit à l'adresse 0x2F8B — l'opérande du JP situé à 0x2F8A (initialement
        ; JP #311F, valeur factice écrasée à chaque appel). C'est la "sélection
        ; dynamique de variante de blit (patch de code)": un unique JP auto-
        ; modifiant choisit, par largeur ET par alignement sub-octet, le point
        ; d'entrée exact dans fn_blit_masked. (7) calcule l'adresse buffer via
        ; 0x3186 (HL = screen_x/screen_y = (ix+16)/(ix+17)) puis jp 311F — qui,
        ; une fois patché à l'étape (6), saute réellement dans fn_blit_masked au
        ; bon point d'entrée.
        ld    a,(ix+off_type)
        cp    #01
        jr    nz,#2F23
        ld    (ix+off_type),#00
        ret
        res    4,(ix+off_flags)
        call    fn_isometric_project
        ret    nc
loc_2F2B:
        call    fn_resolve_sprite_shape
        ld    a,(de)
        and    #3F
        cpl
        add    a,#41
        ld    (#30AF),a
        ld    a,(ix+off_screen_x)
        and    #03
        jp    z,#30BB
        sla    a
        sla    a
        ex    af,af'
        ld    a,(de)
        inc    de
        and    #3F
        inc    a
        ld    (ix+off_screen_w),a
        dec    a
        neg
        and    #0F
        ld    l,a
        ld    h,#00
        add    hl,hl
        ld    c,l
        ld    b,h
        add    hl,hl
        add    hl,hl
        add    hl,hl
        add    hl,bc
        ld    bc,fn_blit_masked
loc_2F5E:
        add    hl,bc
        ld    (#2F8B),hl
        ld    a,(de)
        inc    de
        ld    (ix+off_screen_h),a
        add    a,(ix+off_screen_y)
        sub    #C0
        jr    c,#2F76
        neg
        add    a,(ix+off_screen_h)
        ld    (ix+off_screen_h),a
        ld    l,(ix+off_screen_x)
        ld    h,(ix+off_screen_y)
        call    fn_buffer_addr_from_vram
        ld    b,h
        ld    c,l
        ex    af,af'
        inc    de
        add    a,#80
        ld    h,a
        ld    a,(ix+off_screen_h)
        ex    af,af'
        jp    loc_3147
fn_blit_masked:
        ; Blit "mask-then-or" (écran = fond&masque \| couleur), en fait DEUX
        ; familles de variantes juxtaposées en mémoire, chacune une série
        ; d'entrées espacées régulièrement (indexées par largeur, voir 0x2F17):
        ; (a) 0x2F8D-0x30BA, unité de 18 octets/entrée, variante "décalage sub-
        ; octet" (lit 1 octet, AND/OR sur 2 octets écran adjacents décalés); (b)
        ; 0x30BB-0x31E8 (via l'entrée alternative 0x30E3+), unité de 10
        ; octets/entrée, variante "aligné-octet" (lit 1 octet, AND/OR sur 1 seul
        ; octet écran, plus simple car pas de répartition inter-octets). Chaque
        ; famille boucle sur ses colonnes (compteur dans AF'), avance le pointeur
        ; écran de +0x36 (54) par colonne, jusqu'à épuisement, puis ret. RÉSOUT le
        ; rôle des tables #8200-#8FFF (voir #0829): juste avant d'entrer dans la
        ; variante patchée (#2F81-#2F8A, code commun aux deux familles), H est
        ; calculé comme #80 + shift où shift = 2 (variante alignée, posé à #30BD)
        ; ou (screen_x&3)*4 = 4/8/12 (variante décalée, posé à #2F43) — donc H ∈
        ; {#82, #84, #88, #8C}. Le corps de boucle lit ensuite A=(bc) (octet écran
        ; courant), AND (HL) [table page H, index = octet de forme lu dans (de)] =
        ; masque, INC H; OR (HL) [page H+1] = couleur, écrit (bc)=A. Pour la
        ; variante décalée, une 2e paire est utilisée pour l'octet écran adjacent:
        ; INC H (page H+2, 2e masque), INC H (page H+3, 2e couleur), puis DEC H ×3
        ; pour revenir à H avant l'octet de forme suivant. Donc #82xx/#83xx =
        ; paire masque/couleur "alignée" (pas de décalage), et
        ; #84-#87/#88-#8B/#8C-#8F = triplets de paires
        ; masque1/couleur1/masque2/couleur2 pour les décalages sub-octet 1/2/3
        ; pixels — exactement les tables construites par
        ; fn_build_pixel_bitscatter_tables (#0829). Seule #8100 (nibble dupliqué)
        ; n'est PAS référencée par cette routine — rôle encore non tracé, piste
        ; ouverte
        ld    a,(de)
        inc    de
        ld    l,a
        ld    a,(bc)
        and    (hl)
        inc    h
        or    (hl)
        inc    h
        ld    (bc),a
        inc    c
        ld    a,(bc)
        and    (hl)
        inc    h
        or    (hl)
        ld    (bc),a
        dec    h
        dec    h
        dec    h
        ld    a,(de)
        inc    de
        ld    l,a
        ld    a,(bc)
        and    (hl)
        inc    h
        or    (hl)
        inc    h
        ld    (bc),a
        inc    c
        ld    a,(bc)
        and    (hl)
        inc    h
        or    (hl)
        ld    (bc),a
        dec    h
        dec    h
        dec    h
        ld    a,(de)
        inc    de
        ld    l,a
        ld    a,(bc)
        and    (hl)
        inc    h
        or    (hl)
        inc    h
        ld    (bc),a
        inc    c
        ld    a,(bc)
        and    (hl)
        inc    h
        or    (hl)
        ld    (bc),a
        dec    h
        dec    h
        dec    h
        ld    a,(de)
        inc    de
        ld    l,a
        ld    a,(bc)
        and    (hl)
        inc    h
        or    (hl)
        inc    h
        ld    (bc),a
        inc    c
        ld    a,(bc)
        and    (hl)
        inc    h
        or    (hl)
        ld    (bc),a
        dec    h
        dec    h
        dec    h
        ld    a,(de)
        inc    de
        ld    l,a
        ld    a,(bc)
        and    (hl)
        inc    h
        or    (hl)
        inc    h
        ld    (bc),a
        inc    c
        ld    a,(bc)
        and    (hl)
        inc    h
        or    (hl)
        ld    (bc),a
        dec    h
        dec    h
        dec    h
        ld    a,(de)
        inc    de
        ld    l,a
        ld    a,(bc)
        and    (hl)
        inc    h
        or    (hl)
        inc    h
        ld    (bc),a
        inc    c
        ld    a,(bc)
        and    (hl)
        inc    h
        or    (hl)
        ld    (bc),a
        dec    h
        dec    h
        dec    h
        ld    a,(de)
        inc    de
        ld    l,a
        ld    a,(bc)
        and    (hl)
        inc    h
        or    (hl)
        inc    h
        ld    (bc),a
        inc    c
        ld    a,(bc)
        and    (hl)
        inc    h
        or    (hl)
        ld    (bc),a
        dec    h
        dec    h
        dec    h
        ld    a,(de)
        inc    de
        ld    l,a
        ld    a,(bc)
        and    (hl)
        inc    h
        or    (hl)
        inc    h
        ld    (bc),a
        inc    c
        ld    a,(bc)
        and    (hl)
        inc    h
        or    (hl)
        ld    (bc),a
        dec    h
        dec    h
        dec    h
        ld    a,(de)
        inc    de
        ld    l,a
        ld    a,(bc)
        and    (hl)
        inc    h
        or    (hl)
        inc    h
        ld    (bc),a
        inc    c
        ld    a,(bc)
        and    (hl)
        inc    h
        or    (hl)
        ld    (bc),a
        dec    h
        dec    h
        dec    h
        ld    a,(de)
        inc    de
        ld    l,a
        ld    a,(bc)
        and    (hl)
        inc    h
        or    (hl)
        inc    h
        ld    (bc),a
        inc    c
        ld    a,(bc)
        and    (hl)
        inc    h
        or    (hl)
        ld    (bc),a
        dec    h
        dec    h
        dec    h
        ld    a,(de)
        inc    de
        ld    l,a
        ld    a,(bc)
        and    (hl)
        inc    h
        or    (hl)
        inc    h
        ld    (bc),a
        inc    c
        ld    a,(bc)
        and    (hl)
        inc    h
        or    (hl)
        ld    (bc),a
        dec    h
        dec    h
        dec    h
        ld    a,(de)
        inc    de
        ld    l,a
        ld    a,(bc)
        and    (hl)
        inc    h
        or    (hl)
        inc    h
        ld    (bc),a
        inc    c
        ld    a,(bc)
        and    (hl)
        inc    h
        or    (hl)
        ld    (bc),a
        dec    h
        dec    h
        dec    h
        ld    a,(de)
        inc    de
        ld    l,a
        ld    a,(bc)
        and    (hl)
        inc    h
        or    (hl)
        inc    h
        ld    (bc),a
        inc    c
        ld    a,(bc)
        and    (hl)
        inc    h
        or    (hl)
        ld    (bc),a
        dec    h
        dec    h
        dec    h
        ld    a,(de)
        inc    de
        ld    l,a
        ld    a,(bc)
        and    (hl)
        inc    h
        or    (hl)
        inc    h
        ld    (bc),a
        inc    c
        ld    a,(bc)
        and    (hl)
        inc    h
        or    (hl)
        ld    (bc),a
        dec    h
        dec    h
        dec    h
        ld    a,(de)
        inc    de
        ld    l,a
        ld    a,(bc)
        and    (hl)
        inc    h
        or    (hl)
        inc    h
        ld    (bc),a
        inc    c
        ld    a,(bc)
        and    (hl)
        inc    h
        or    (hl)
        ld    (bc),a
        dec    h
        dec    h
        dec    h
        ld    a,(de)
        inc    de
        ld    l,a
        ld    a,(bc)
        and    (hl)
        inc    h
        or    (hl)
        inc    h
        ld    (bc),a
        inc    c
        ld    a,(bc)
        and    (hl)
        inc    h
        or    (hl)
        ld    (bc),a
        dec    h
        dec    h
        dec    h
loc_30AD:
        ld    a,c
        add    a,#3A
        ld    c,a
        ld    a,b
        adc    a,#00
        ld    b,a
        ex    af,af'
        dec    a
        jp    nz,#2F89
        ret
        add    a,#02
        ex    af,af'
        ld    a,(de)
        and    #3F
        inc    de
        ld    (ix+off_screen_w),a
        neg
        and    #0F
        ld    l,a
        ld    h,#00
        add    hl,hl
        ld    c,l
        ld    b,h
        add    hl,hl
        add    hl,hl
        add    hl,bc
        ld    bc,#30E3
        inc    de
        ld    a,(de)
        dec    de
        and    a
        jp    z,loc_2F5E
        ex    af,af'
        sub    #02
        ex    af,af'
        jp    loc_2F5E
        ld    a,(de)
        inc    de
        ld    l,a
        ld    a,(bc)
        and    (hl)
        inc    h
        or    (hl)
        dec    h
        ld    (bc),a
        inc    c
        ld    a,(de)
        inc    de
        ld    l,a
        ld    a,(bc)
        and    (hl)
        inc    h
        or    (hl)
        dec    h
        ld    (bc),a
        inc    c
        ld    a,(de)
        inc    de
        ld    l,a
        ld    a,(bc)
        and    (hl)
        inc    h
        or    (hl)
        dec    h
        ld    (bc),a
        inc    c
        ld    a,(de)
        inc    de
        ld    l,a
        ld    a,(bc)
        and    (hl)
        inc    h
        or    (hl)
        dec    h
        ld    (bc),a
        inc    c
        ld    a,(de)
        inc    de
        ld    l,a
        ld    a,(bc)
        and    (hl)
        inc    h
        or    (hl)
        dec    h
        ld    (bc),a
        inc    c
        ld    a,(de)
        inc    de
        ld    l,a
        ld    a,(bc)
        and    (hl)
        inc    h
        or    (hl)
        dec    h
        ld    (bc),a
        inc    c
        ld    a,(de)
        inc    de
        ld    l,a
        ld    a,(bc)
        and    (hl)
        inc    h
        or    (hl)
        dec    h
        ld    (bc),a
        inc    c
        ld    a,(de)
        inc    de
        ld    l,a
        ld    a,(bc)
        and    (hl)
        inc    h
        or    (hl)
        dec    h
        ld    (bc),a
        inc    c
        ld    a,(de)
        inc    de
        ld    l,a
        ld    a,(bc)
        and    (hl)
        inc    h
        or    (hl)
        dec    h
        ld    (bc),a
        inc    c
        ld    a,(de)
        inc    de
        ld    l,a
        ld    a,(bc)
        and    (hl)
        inc    h
        or    (hl)
        dec    h
        ld    (bc),a
        inc    c
loc_3147:
        ld    a,(de)
        inc    de
        ld    l,a
        ld    a,(bc)
        and    (hl)
        inc    h
        or    (hl)
        dec    h
        ld    (bc),a
        inc    c
        ld    a,(de)
        inc    de
        ld    l,a
        ld    a,(bc)
        and    (hl)
        inc    h
        or    (hl)
        dec    h
        ld    (bc),a
        inc    c
        ld    a,(de)
        inc    de
        ld    l,a
        ld    a,(bc)
        and    (hl)
        inc    h
        or    (hl)
        dec    h
        ld    (bc),a
        inc    c
        ld    a,(de)
        inc    de
        ld    l,a
        ld    a,(bc)
        and    (hl)
        inc    h
        or    (hl)
        dec    h
        ld    (bc),a
        inc    c
        ld    a,(de)
        inc    de
        ld    l,a
        ld    a,(bc)
        and    (hl)
        inc    h
        or    (hl)
        dec    h
        ld    (bc),a
        inc    c
        ld    a,(de)
        inc    de
        ld    l,a
        ld    a,(bc)
        and    (hl)
        inc    h
        or    (hl)
        dec    h
        ld    (bc),a
        inc    bc
        jp    loc_30AD
fn_buffer_addr_from_vram:
        ; HL_dest = (HL_vram >> 2) + 0x9000 — convertit une adresse VRAM en
        ; pointeur buffer intermédiaire (même routine réutilisée pour le menu,
        ; calcul identique)
        push    bc
        srl    h
        rr    l
        srl    h
        rr    l
        ld    bc,BUF_PRERENDER_BASE
        add    hl,bc
        pop    bc
        ret
fn_screen_addr_from_bc:
        ; (B,C) -> adresse VRAM CPC complète (table de correspondance ligne +
        ; calcul colonne)
        push    hl
        ld    a,b
        rrca
        rrca
        and    #3E
        ld    hl,tbl_screen_line_base
        rst    #08
        ld    a,(hl)
        inc    hl
        ld    h,(hl)
        ld    l,a
        ld    a,b
        cpl
        rlca
        rlca
        rlca
        and    #38
        or    h
        or    #C0
        ld    h,a
        ld    a,c
        srl    a
        srl    a
        add    a,#08
        rst    #08
        ex    de,hl
        pop    hl
        ret
tbl_screen_line_base:
        ; 24 entrées word, base d'adresse écran par bande de 8 lignes (pas -0x50)
        defw #0730
        defw #06E0
        defw #0690
        defw #0640
        defw #05F0
        defw #05A0
        defw #0550
        defw #0500
        defw #04B0
        defw #0460
        defw #0410
        defw #03C0
        defw #0370
        defw #0320
        defw #02D0
        defw #0280
        defw #0230
        defw #01E0
        defw #0190
        defw #0140
        defw #00F0
        defw #00A0
        defw #0050
        defw #0000
fn_flip_sprite_shape:
        ; Bit7 = flip VERTICAL (echange de lignes entieres du bitmap) ; bit6 =
        ; flip HORIZONTAL reel (echange d'octets + fn_mirror_byte_bits par
        ; nibble). Si le bit teste differe de l'orientation courante (marqueur
        ; stocke dans l'octet0 de la forme), inverse ce bit ET mute le bitmap en
        ; place -- economie de memoire cle, une seule forme de base par sprite.
        push    de
        ld    a,(de)
        xor    (ix+off_flags)
        and    #80
        jr    z,#3220
        ld    a,(de)
        xor    #80
        ld    (de),a
        and    #3F
        ld    b,a
        inc    de
        ld    a,(de)
        ld    c,a
        inc    de
        inc    de
        push    de
        ld    e,b
        ld    d,#00
        call    fn_mul8x16
        pop    de
        add    hl,de
        ex    de,hl
        ld    a,b
        rst    #08
        dec    de
        dec    hl
        srl    c
        push    bc
loc_320F:
        ld    a,(de)
        ld    c,(hl)
        ld    (hl),a
        ld    a,c
        ld    (de),a
        dec    hl
        dec    de
        djnz    loc_320F
        pop    bc
        ld    a,b
        sla    a
        rst    #08
        dec    c
        jr    nz,#320E
        pop    de
        push    de
        ld    a,(de)
        xor    (ix+off_flags)
        and    #40
        jr    z,#3263
        ld    a,(de)
        xor    #40
        ld    (de),a
        inc    de
        and    #3F
        ld    (#3259),a
        ld    l,a
        ld    h,#00
        add    hl,de
        inc    hl
        inc    a
        srl    a
        ld    b,a
        ld    a,(de)
        inc    de
        inc    de
        ld    c,a
        push    bc
        push    de
        push    hl
loc_3244:
        push    bc
        ld    a,(de)
        ld    b,a
        call    fn_mirror_byte_bits
        ld    b,(hl)
        ld    (hl),a
        ld    a,b
        call    fn_mirror_byte_bits
        ld    (de),a
        inc    de
        dec    hl
        pop    bc
        djnz    loc_3244
        pop    hl
        pop    de
        ld    bc,rst_add_hl_a
        add    hl,bc
        ex    de,hl
        add    hl,bc
        ex    de,hl
        pop    bc
        dec    c
        jr    nz,#3241
        pop    de
        ret
fn_mirror_byte_bits:
        ; (etait en defb, jamais nommee malgre la mention 'fn_bit_rotate' dans la
        ; desc de fn_flip_sprite_shape qui l'appelle 2x, #3247/#324D): inverse
        ; l'ordre des 8 bits d'un octet (A/B en entree, A en sortie) par 4 paires
        ; rotate+AND+OR sur les nibbles (masques #11/#88 puis #22/#44) -- utilisee
        ; pour le flip HORIZONTAL des sprites (miroir bit a bit d'une ligne de
        ; pixels 1bpp). Verifie octet par octet contre la RAM live. Se termine
        ; juste avant la chaine ASCII 'COPYRIGHT 1984 A.C.G.' -- explique enfin
        ; les quelques octets de code qui la precedaient et n'avaient jamais ete
        ; rattaches a une routine nommee.
        rrca
        rrca
        rrca
        and    #11
        ld    c,a
        ld    a,b
        rlca
        rlca
        rlca
        and    #88
        or    c
        ld    c,a
        ld    a,b
        rrca
        and    #22
        or    c
        ld    c,a
        ld    a,b
        rlca
        and    #44
        or    c
        ret
str_copyright_notice:
        ; Chaine ASCII 'COPYRIGHT 1984 A.C.G.' (21 octets, pas de terminateur
        ; explicite -- tbl_menu_font suit immediatement a #3294). Deja identifiee
        ; via recherche de chaine en RAM (premiere identification du jeu), jamais
        ; donnee de symbole propre jusqu'ici.
        defb #43,#4F,#50,#59,#52,#49,#47,#48,#54,#20,#31,#39,#38,#34,#20,#41
        defb #2E,#43,#2E,#47,#2E
tbl_menu_font:
        ; Police de caractères 4bpp du menu (utilisée par fn_menu_glyph_unpack)
        defb #38,#6C,#D6,#D6,#D6,#D6,#6C,#38,#18,#38,#58,#18,#18,#18,#18,#7C
        defb #38,#4C,#0C,#3C,#60,#C2,#C2,#FE,#38,#4C,#0C,#3C,#0E,#86,#86,#FC
        defb #18,#38,#58,#9A,#FE,#1A,#18,#7C,#FE,#C2,#C0,#FC,#06,#06,#86,#7C
        defb #1E,#32,#60,#7C,#C6,#C6,#C6,#7C,#7E,#46,#4C,#0C,#18,#18,#30,#F8
        defb #38,#6C,#6C,#7C,#FE,#C6,#C6,#7C,#7C,#C6,#C6,#C6,#7C,#0C,#98,#F0
        defb #0C,#1C,#2E,#66,#46,#CE,#DB,#66,#F8,#6C,#6C,#78,#6C,#66,#66,#FC
        defb #0E,#32,#60,#40,#C0,#C2,#E6,#7C,#60,#70,#68,#6C,#66,#66,#66,#FC
        defb #FE,#60,#64,#7C,#64,#60,#7A,#C6,#C6,#7A,#60,#64,#7C,#64,#60,#60
        defb #0E,#30,#60,#C6,#CE,#F6,#66,#0E,#EE,#C6,#C6,#FE,#C6,#C6,#C6,#EE
        defb #7C,#18,#18,#18,#18,#18,#18,#7C,#1E,#06,#06,#86,#86,#C6,#7E,#1C
        defb #E4,#68,#70,#78,#6C,#64,#64,#F6,#E0,#60,#60,#60,#60,#60,#62,#FE
        defb #C6,#EE,#EE,#D6,#D6,#D6,#C6,#EE,#CC,#D6,#D6,#E6,#E4,#C4,#C8,#DE
        defb #38,#6C,#C6,#C6,#C6,#C6,#6C,#38,#F8,#6C,#66,#76,#6E,#60,#60,#F0
        defb #38,#6C,#C6,#C6,#C6,#D6,#6C,#3A,#F8,#6C,#66,#76,#7E,#78,#6C,#E6
        defb #38,#64,#60,#3C,#06,#86,#C6,#7C,#FE,#9A,#98,#18,#18,#18,#18,#18
        defb #F6,#26,#46,#4E,#CE,#D6,#D6,#66,#E2,#62,#64,#64,#68,#68,#70,#60
        defb #EE,#C6,#D6,#D6,#D6,#EE,#EE,#C6,#C6,#C6,#6C,#38,#38,#6C,#C6,#C6
        defb #86,#66,#16,#0E,#06,#04,#4C,#38,#7E,#46,#0C,#18,#30,#62,#C2,#FE
        defb #00,#00,#00,#00,#00,#18,#18,#00,#3C,#42,#99,#A1,#A1,#99,#42,#3C
        defb #00,#00,#00,#00,#00,#00,#00,#00,#00,#62,#64,#08,#10,#26,#46,#00
tbl_room_master_coords:
        ; Selectionnees par field_byte>>3&0x1F (1er octet du payload de
        ; tbl_room_master_index) dans fn_load_room_data, copiees vers
        ; var_camera_reference/var_camera_reference_y (#0071/#0072) +
        ; var_room_data_field_2 (#0074). Entree 0 = (#40,#40,#80)
        ; defaut/symetrique ; entree 1 = (#20,#40,#80) ref. X divisee par 2,
        ; salles plus hautes que larges ; entree 2 = (#40,#20,#80) ref. Y divisee
        ; par 2, salles plus larges que hautes. Le 3e octet (#80, constant)
        ; correspond a grid_z_or_offset 'au sol'.
        defb #40,#40,#80,#20,#40,#80,#40,#20,#80
tbl_room_master_index:
        ; 128 entrées [room_id][skip_len][payload], couvre EXACTEMENT
        ; 0x33DD-0x3D5D sans reste. Longueur totale d'une entrée = 1+skip_len.
        ; Payload = field_byte puis liste d'octets. Chaque octet non-0xFF est un
        ; index DIRECT vers tbl_room_index_ptrs (0x3E6E) — chemin par défaut. Un
        ; octet 0xFF déclenche le chemin alternatif via tbl_room_connection_ptrs
        ; (0x3D5D). Vérifié empiriquement sur transition réelle 0x44→0x43, mais le
        ; champ exact de destination dans l'entrée résolue reste à identifier
        defb #00,#19,#03,#00,#01,#0C,#FF,#07,#10,#50,#90,#11,#51,#91,#0A,#4A
        defb #06,#8A,#02,#42,#82,#C8,#C1,#C0,#A8,#C9,#01,#14,#14,#01,#03,#0D
        defb #FF,#03,#2B,#2C,#13,#14,#23,#6B,#6C,#53,#54,#40,#1C,#48,#28,#02
        defb #06,#03,#00,#01,#03,#0C,#03,#1A,#16,#01,#03,#0D,#FF,#03,#22,#1A
        defb #25,#1D,#2B,#23,#1B,#24,#1C,#93,#2B,#2C,#13,#14,#B3,#63,#64,#5B
        defb #5C,#04,#13,#05,#00,#03,#0C,#FF,#2B,#23,#1A,#1C,#13,#B2,#5A,#5C
        defb #53,#02,#63,#9B,#DB,#08,#1A,#03,#04,#05,#0F,#10,#FF,#1B,#1B,#5B
        defb #9B,#DB,#2B,#23,#1A,#1C,#13,#93,#63,#5A,#5C,#53,#B8,#09,#80,#49
        defb #09,#0B,#06,#05,#07,#0F,#11,#09,#0B,#FF,#48,#23,#0A,#19,#03,#05
        defb #07,#0F,#11,#FF,#1D,#22,#62,#A2,#24,#64,#A4,#2F,#2A,#2B,#6B,#2C
        defb #1A,#1B,#5B,#1C,#38,#0E,#0B,#06,#06,#05,#07,#0F,#11,#0C,#17,#03
        defb #05,#07,#0F,#11,#FF,#2F,#3D,#32,#28,#2C,#2F,#22,#1C,#10,#2B,#12
        defb #17,#0D,#04,#B8,#24,#0D,#06,#04,#00,#01,#03,#0C,#0E,#0B,#15,#01
        defb #03,#0D,#FF,#53,#12,#1D,#2C,#23,#0F,#1C,#04,#00,#03,#0C,#FF,#07
        defb #23,#25,#13,#15,#63,#64,#65,#5B,#04,#5D,#53,#54,#55,#1C,#9B,#A4
        defb #9B,#9D,#94,#B0,#9C,#10,#18,#0D,#00,#15,#17,#0E,#FF,#01,#C3,#C4
        defb #5B,#05,#0C,#0B,#0A,#9B,#45,#4C,#4B,#4A,#A8,#C2,#50,#5A,#12,#18
        defb #0C,#00,#02,#0E,#FF,#97,#FA,#FD,#F3,#F4,#EB,#EC,#E3,#E4,#97,#DB
        defb #DC,#D3,#D4,#CB,#CC,#C2,#C5,#14,#1A,#0E,#00,#15,#17,#0E,#FF,#01
        defb #C3,#C4,#AD,#C2,#CA,#D2,#DA,#DB,#DC,#AC,#DD,#E5,#AD,#75,#3D,#29
        defb #0B,#0C,#18,#11,#0D,#00,#02,#0E,#FF,#2F,#2A,#2B,#2C,#2D,#12,#13
        defb #14,#15,#B8,#1B,#1D,#1B,#0E,#00,#15,#17,#0E,#FF,#07,#C3,#C4,#0C
        defb #4C,#8C,#CC,#24,#64,#02,#2C,#6C,#34,#29,#14,#1C,#58,#0C,#78,#54
        defb #1F,#17,#0B,#00,#02,#0E,#FF,#03,#12,#15,#2A,#2D,#2F,#52,#13,#14
        defb #55,#6A,#2B,#2C,#6D,#E1,#93,#6B,#20,#12,#03,#00,#01,#15,#17,#0C
        defb #FF,#02,#18,#C3,#C4,#AA,#50,#88,#C0,#28,#02,#21,#1C,#16,#14,#16
        defb #03,#0D,#FF,#07,#21,#61,#A2,#A3,#24,#64,#25,#65,#03,#26,#66,#E7
        defb #DF,#29,#A4,#A6,#30,#E2,#C0,#A5,#22,#1A,#03,#02,#03,#0C,#FF,#03
        defb #30,#78,#B9,#FA,#2F,#39,#3A,#3D,#3E,#3F,#33,#2B,#23,#2A,#34,#2C
        defb #24,#A8,#FB,#24,#18,#03,#00,#02,#0C,#FF,#2F,#02,#05,#0A,#0F,#10
        defb #15,#19,#1B,#2F,#1C,#1F,#28,#2A,#2C,#2E,#3A,#3D,#27,#0F,#06,#00
        defb #0C,#FF,#03,#1B,#1C,#23,#24,#4B,#12,#15,#2A,#2D,#28,#10,#0E,#00
        defb #15,#0E,#17,#FF,#39,#23,#63,#29,#0B,#0C,#01,#C3,#C4,#2D,#17,#04
        defb #14,#02,#16,#0C,#FF,#07,#DF,#E7,#13,#1B,#23,#5B,#63,#A3,#2B,#1E
        defb #26,#22,#24,#70,#E3,#2E,#11,#15,#01,#03,#0D,#FF,#2F,#2B,#2C,#22
        defb #25,#1A,#1D,#13,#14,#68,#23,#2F,#06,#04,#00,#02,#03,#0C,#30,#16
        defb #0D,#00,#02,#0E,#FF,#2F,#33,#34,#2A,#2D,#22,#25,#1A,#1D,#2B,#12
        defb #15,#0B,#0C,#B8,#1B,#34,#18,#0E,#00,#02,#0E,#FF,#3F,#1A,#1B,#1C
        defb #1D,#5A,#5B,#5C,#5D,#97,#9A,#9B,#9C,#9D,#DA,#DB,#DC,#DD,#37,#0D
        defb #0D,#00,#02,#0E,#FF,#78,#14,#00,#2C,#49,#25,#1A,#38,#19,#0B,#00
        defb #15,#17,#0E,#FF,#05,#7A,#F2,#DA,#C2,#C3,#C4,#B3,#EA,#E2,#D2,#CA
        defb #2C,#2A,#22,#1A,#12,#0A,#3F,#19,#03,#04,#06,#0F,#10,#FF,#1F,#18
        defb #19,#1A,#5A,#1D,#5D,#1E,#1F,#2D,#58,#59,#9A,#9D,#5E,#5F,#D0,#1B
        defb #40,#13,#06,#14,#15,#16,#17,#0C,#FF,#05,#3F,#06,#C3,#C4,#DF,#E7
        defb #68,#38,#80,#B8,#41,#17,#14,#01,#03,#0D,#FF,#05,#12,#14,#16,#2A
        defb #2C,#2E,#25,#52,#54,#56,#6A,#6C,#6E,#51,#15,#2B,#42,#15,#05,#01
        defb #03,#0C,#FF,#01,#1B,#DC,#A9,#63,#A4,#2F,#12,#1A,#22,#2B,#2C,#25
        defb #1D,#14,#43,#1B,#16,#01,#03,#0D,#FF,#07,#1E,#26,#5D,#65,#19,#21
        defb #5A,#62,#03,#2B,#2C,#13,#14,#2B,#6B,#6C,#53,#54,#60,#1B,#44,#07
        defb #04,#00,#01,#02,#03,#0C,#45,#1D,#05,#01,#03,#0C,#FF,#07,#23,#25
        defb #13,#15,#63,#64,#65,#5B,#03,#5D,#53,#54,#55,#9B,#A4,#9B,#9D,#94
        defb #B0,#9C,#28,#1C,#46,#1C,#16,#01,#03,#0D,#FF,#07,#23,#1B,#2C,#6C
        defb #14,#54,#25,#1D,#23,#65,#5D,#63,#5B,#91,#24,#1C,#B3,#A4,#E4,#9C
        defb #DC,#47,#06,#03,#00,#02,#03,#0C,#48,#17,#0E,#00,#15,#17,#0E,#FF
        defb #07,#C3,#C4,#CC,#2C,#2D,#25,#6C,#6D,#00,#AC,#29,#0B,#14,#78,#8C
        defb #4F,#15,#06,#04,#06,#0F,#10,#FF,#9F,#D8,#D9,#DA,#DB,#DC,#DD,#DE
        defb #DF,#9B,#C3,#C4,#FB,#FC,#54,#16,#0D,#00,#02,#0E,#FF,#01,#0C,#33
        defb #2B,#1A,#5A,#25,#65,#93,#13,#0B,#2C,#24,#79,#14,#23,#57,#14,#0D
        defb #00,#02,#0E,#FF,#07,#2D,#6D,#AD,#24,#64,#A4,#1B,#5B,#03,#9B,#12
        defb #52,#92,#58,#0B,#0D,#00,#15,#17,#0E,#FF,#48,#1D,#80,#5D,#5E,#12
        defb #06,#04,#05,#0F,#10,#FF,#1F,#32,#35,#29,#2E,#11,#16,#0A,#0D,#C8
        defb #2D,#5F,#06,#03,#04,#06,#07,#0F,#64,#12,#0E,#00,#15,#17,#0E,#FF
        defb #07,#03,#04,#0B,#0C,#23,#24,#2B,#2C,#30,#63,#67,#12,#0C,#00,#02
        defb #0E,#FF,#01,#2A,#2D,#2B,#6A,#6D,#1A,#1D,#D0,#2B,#68,#25,#68,#19
        defb #0B,#00,#02,#0E,#FF,#07,#3A,#7A,#BA,#FA,#3D,#7D,#BD,#FD,#03,#32
        defb #33,#34,#35,#29,#72,#75,#60,#A3,#6A,#05,#06,#00,#01,#0C,#6B,#11
        defb #14,#14,#03,#16,#0D,#FF,#05,#24,#1C,#64,#5C,#E7,#DF,#51,#D6,#ED
        defb #6C,#18,#13,#01,#03,#0D,#FF,#37,#2B,#23,#1B,#13,#6B,#63,#5B,#53
        defb #9F,#AB,#A3,#9B,#93,#EB,#E3,#DB,#D3,#6D,#17,#06,#05,#07,#0F,#11
        defb #FF,#1F,#14,#2C,#54,#6C,#94,#9C,#A4,#AC,#21,#D4,#EC,#38,#09,#40
        defb #1E,#6E,#07,#03,#05,#06,#07,#0F,#11,#6F,#14,#06,#06,#07,#0F,#11
        defb #FF,#1A,#2D,#2E,#2F,#22,#6D,#6E,#6F,#9B,#3D,#35,#7D,#75,#74,#18
        defb #04,#01,#02,#0C,#FF,#2A,#39,#30,#31,#07,#3A,#7A,#32,#72,#28,#68
        defb #29,#69,#B3,#B8,#B9,#B0,#B1,#75,#0E,#13,#01,#03,#0D,#FF,#01,#23
        defb #1C,#29,#24,#1B,#C8,#2B,#76,#16,#16,#14,#03,#16,#0D,#FF,#06,#DF
        defb #E7,#EF,#AE,#6D,#2C,#D7,#2D,#16,#1E,#26,#15,#1D,#25,#77,#07,#03
        defb #00,#01,#02,#03,#0C,#78,#19,#04,#00,#01,#02,#03,#0C,#FF,#2F,#39
        defb #3F,#35,#28,#2C,#2F,#23,#1D,#2C,#11,#13,#0A,#0D,#0E,#68,#17,#79
        defb #16,#13,#01,#03,#0D,#FF,#B3,#22,#1A,#25,#1D,#2F,#2B,#2C,#23,#24
        defb #1B,#1C,#13,#14,#60,#DB,#7A,#16,#05,#02,#03,#0C,#FF,#04,#28,#70
        defb #B8,#B9,#FF,#2D,#BA,#BC,#BE,#37,#2F,#27,#A9,#FB,#FD,#83,#05,#06
        defb #00,#01,#0C,#84,#17,#15,#01,#03,#0D,#FF,#07,#2A,#6A,#2D,#6D,#12
        defb #52,#15,#55,#23,#AA,#AD,#92,#95,#11,#1D,#9A,#85,#19,#14,#14,#03
        defb #16,#0D,#FF,#05,#28,#69,#AA,#EB,#E7,#DF,#2F,#1B,#23,#1C,#24,#1D
        defb #25,#1E,#26,#78,#DB,#86,#0B,#13,#14,#03,#16,#0D,#FF,#80,#63,#B8
        defb #23,#87,#18,#05,#00,#01,#02,#03,#0C,#FF,#03,#2A,#2D,#12,#15,#2B
        defb #6A,#6D,#52,#55,#D1,#2B,#13,#D9,#1A,#1D,#88,#13,#06,#00,#01,#02
        defb #03,#12,#13,#0C,#FF,#07,#32,#29,#35,#2E,#16,#0D,#11,#0A,#89,#14
        defb #15,#01,#03,#0D,#FF,#07,#2C,#6C,#AC,#24,#1C,#14,#54,#94,#21,#EC
        defb #D4,#50,#64,#8A,#18,#13,#01,#03,#0D,#FF,#5F,#2A,#22,#1A,#12,#2D
        defb #25,#1D,#15,#97,#EA,#E2,#DA,#D2,#ED,#E5,#DD,#D5,#8B,#06,#05,#00
        defb #01,#03,#0C,#8C,#19,#14,#01,#03,#0D,#FF,#07,#2A,#6A,#2D,#6D,#12
        defb #52,#15,#55,#2B,#AA,#AD,#92,#95,#D9,#1A,#1D,#40,#1B,#8D,#1A,#05
        defb #01,#03,#0C,#FF,#07,#34,#74,#6C,#B4,#BC,#FB,#FD,#F3,#03,#FC,#F5
        defb #EB,#ED,#58,#3C,#28,#24,#10,#E4,#8E,#0C,#13,#14,#03,#16,#0D,#FF
        defb #39,#23,#63,#48,#2B,#8F,#05,#06,#00,#03,#0C,#93,#14,#0C,#00,#02
        defb #0E,#FF,#07,#1A,#1B,#1C,#1D,#5A,#9A,#5D,#9D,#21,#DA,#DD,#A0,#5B
        defb #97,#10,#0C,#00,#02,#0E,#FF,#03,#1A,#1B,#1C,#1D,#23,#5A,#5B,#5C
        defb #5D,#98,#1A,#0B,#00,#02,#0E,#FF,#01,#33,#0C,#A9,#6B,#54,#2F,#22
        defb #23,#24,#25,#1A,#1B,#1C,#1D,#B3,#A3,#A4,#9B,#9C,#9B,#17,#0B,#00
        defb #15,#17,#0E,#FF,#07,#3D,#7D,#35,#75,#B5,#F5,#C3,#C4,#78,#DD,#70
        defb #DB,#29,#1C,#1D,#9F,#18,#0D,#00,#02,#0E,#FF,#07,#1A,#1B,#1C,#1D
        defb #5A,#5B,#5C,#5D,#03,#9A,#9B,#9C,#9D,#2A,#DB,#DC,#DD,#A3,#1C,#0B
        defb #00,#15,#17,#0E,#FF,#05,#3D,#7D,#34,#74,#C3,#C4,#2B,#12,#14,#23
        defb #25,#93,#52,#54,#63,#65,#B8,#35,#80,#75,#A7,#05,#03,#00,#02,#0C
        defb #A8,#18,#06,#02,#0C,#FF,#07,#2A,#6A,#32,#72,#B2,#F2,#36,#76,#05
        defb #B6,#F6,#16,#56,#96,#D6,#29,#35,#1E,#AA,#18,#03,#00,#01,#0C,#FF
        defb #07,#00,#48,#90,#18,#58,#98,#D8,#21,#02,#61,#28,#68,#29,#A8,#A1
        defb #A8,#E0,#AB,#06,#04,#00,#02,#03,#0C,#AF,#0E,#0C,#00,#15,#17,#0E
        defb #FF,#03,#1B,#1C,#33,#34,#30,#74,#B3,#06,#06,#00,#01,#02,#0C,#B4
        defb #13,#04,#03,#0C,#FF,#07,#13,#14,#15,#1B,#23,#63,#A3,#E3,#30,#55
        defb #39,#2E,#6E,#B7,#0E,#0C,#00,#02,#0E,#FF,#03,#33,#34,#0B,#0C,#49
        defb #23,#1C,#BA,#19,#05,#01,#02,#0C,#FF,#05,#2B,#6B,#AB,#1B,#5B,#9B
        defb #2F,#2A,#22,#62,#A2,#1A,#2C,#24,#64,#29,#A4,#1C,#BB,#0B,#06,#02
        defb #03,#0C,#FF,#48,#24,#81,#64,#A4,#BF,#1D,#03,#00,#15,#17,#0C,#FF
        defb #04,#3D,#7E,#BE,#C3,#C4,#2F,#3F,#37,#2F,#2E,#2D,#25,#1D,#15,#29
        defb #14,#0C,#B8,#7F,#80,#BF,#C3,#14,#0B,#00,#02,#0E,#FF,#07,#1A,#1B
        defb #1C,#1D,#5A,#5B,#5C,#5D,#03,#9A,#9B,#9C,#9D,#C7,#0B,#05,#00,#15
        defb #17,#0C,#FF,#80,#5B,#48,#1B,#CF,#0A,#0C,#00,#02,#08,#0A,#0E,#FF
        defb #48,#1C,#D0,#19,#05,#00,#01,#0C,#FF,#07,#03,#42,#81,#C0,#C8,#D0
        defb #D8,#E0,#03,#1C,#5C,#9C,#DC,#2B,#1B,#24,#1D,#14,#D1,#11,#14,#01
        defb #03,#0D,#FF,#68,#16,#2F,#1E,#26,#1B,#1C,#23,#24,#19,#21,#D2,#15
        defb #05,#00,#03,#0C,#FF,#07,#03,#27,#44,#5F,#85,#97,#C6,#CF,#01,#CE
        defb #C7,#99,#0F,#06,#D3,#12,#0D,#00,#02,#0E,#FF,#01,#2A,#2D,#2B,#6A
        defb #6D,#1A,#1D,#D0,#2B,#68,#25,#D6,#15,#06,#04,#05,#0F,#10,#FF,#1F
        defb #2C,#6C,#AC,#EC,#24,#1C,#14,#54,#18,#94,#11,#5D,#1B,#D7,#0E,#03
        defb #04,#05,#06,#07,#0F,#FF,#51,#1B,#24,#A1,#23,#1C,#D8,#06,#03,#04
        defb #05,#07,#0F,#D9,#05,#06,#04,#07,#0F,#DD,#14,#06,#00,#14,#16,#0C
        defb #FF,#01,#E7,#DF,#5B,#2F,#26,#1E,#17,#3B,#1A,#5A,#9A,#DA,#DE,#05
        defb #13,#01,#03,#0D,#DF,#16,#06,#00,#02,#03,#0C,#FF,#04,#1B,#5B,#9B
        defb #DB,#E2,#2B,#13,#1C,#23,#1A,#B2,#12,#54,#A4,#E0,#11,#0E,#00,#02
        defb #0E,#FF,#2F,#3A,#3D,#2B,#2C,#13,#14,#02,#05,#C8,#24,#E2,#16,#0E
        defb #00,#02,#0E,#FF,#97,#05,#0A,#0C,#13,#15,#1A,#1C,#23,#95,#25,#2A
        defb #2C,#33,#35,#3A,#E3,#1B,#0E,#00,#02,#0E,#FF,#AF,#02,#05,#4A,#4D
        defb #92,#95,#AA,#AD,#AB,#72,#75,#3A,#3D,#B3,#DA,#DD,#E2,#E5,#60,#1B
        defb #E6,#07,#03,#04,#05,#06,#0F,#10,#E7,#11,#06,#04,#05,#06,#07,#0F
        defb #FF,#2F,#33,#34,#21,#19,#26,#1E,#0B,#0C,#E8,#16,#06,#04,#05,#06
        defb #07,#0F,#FF,#1F,#33,#21,#23,#63,#A3,#E3,#25,#13,#2B,#2B,#24,#1B
        defb #22,#E9,#06,#03,#04,#06,#07,#0F,#ED,#14,#0C,#00,#02,#0E,#FF,#07
        defb #1A,#1B,#1C,#1D,#5A,#5B,#5C,#5D,#03,#9A,#9B,#9C,#9D,#EF,#05,#0D
        defb #00,#02,#0E,#F0,#1B,#05,#14,#15,#16,#17,#0C,#FF,#07,#DF,#E7,#FF
        defb #FE,#78,#A8,#D0,#C0,#03,#C1,#C2,#C3,#C4,#29,#39,#3B,#70,#FB,#F1
        defb #0A,#13,#01,#03,#09,#0B,#0D,#FF,#B8,#23,#F2,#06,#05,#01,#02,#03
        defb #0C,#F3,#17,#03,#02,#03,#0C,#FF,#07,#32,#3A,#72,#7A,#34,#3C,#74
        defb #7C,#01,#B3,#BB,#48,#33,#31,#2B,#6B,#F6,#13,#06,#05,#06,#0F,#10
        defb #11,#FF,#1B,#1B,#5B,#9B,#DB,#B0,#1C,#30,#12,#38,#34,#F7,#15,#03
        defb #05,#06,#07,#0F,#11,#FF,#1F,#22,#23,#24,#1A,#1C,#12,#13,#14,#B8
        defb #1B,#30,#5B,#F8,#07,#03,#05,#06,#07,#0F,#11,#F9,#13,#06,#06,#07
        defb #0F,#11,#FF,#9F,#FF,#FE,#F6,#F7,#FD,#EF,#C3,#C4,#99,#D8,#E0,#FD
        defb #11,#06,#01,#02,#0C,#FF,#07,#28,#29,#2A,#32,#3A,#70,#71,#79,#00
        defb #B8,#FE,#12,#13,#01,#03,#0D,#FF,#2B,#25,#1D,#22,#1A,#23,#2B,#2C
        defb #13,#14,#60,#5B,#FF,#0B,#06,#02,#03,#0C,#FF,#2B,#2E,#35,#37,#3E
tbl_room_connection_ptrs:
        ; Table de pointeurs word. Ce n'est PAS un chemin alternatif rarement
        ; déclenché par un octet 0xFF comme précédemment documenté — désassemblage
        ; direct de fn_load_room_data (0x2CBA-0x2D0D) montre que c'est la PHASE 2,
        ; TOUJOURS exécutée, du traitement du payload, juste après la phase 1
        ; (liste d'index directs vers tbl_room_index_ptrs, qui se TERMINE par 0xFF
        ; — le 0xFF n'active rien d'"alternatif", il marque simplement la fin de
        ; la phase 1). L'octet du payload juste après le 0xFF encode un compteur
        ; (bits0-2, +1) ET, après rotation/masquage (rrca,rrca; and 0x3E),
        ; l'index×2 dans cette table. EXTENT CONFIRMÉE: exactement 29 entrées
        ; (0x3D5D-0x3D97, 58 octets) — les 29 pointeurs uniques, triés,
        ; s'enchaînent PARFAITEMENT jusqu'à tbl_room_index_ptrs (0x3E6E). Chaque
        ; pointeur mène à un tbl_room_junction_entity_template_XXXX (voir ci-
        ; dessous).
        defw #3D97
        defw #3DC8
        defw #3DCF
        defw #3DF2
        defw #3DF9
        defw #3E00
        defw #3E1C
        defw #3E23
        defw #3E2A
        defw #3E44
        defw #3E4B
        defw #3D9E
        defw #3DD6
        defw #3E37
        defw #3DA5
        defw #3DAC
        defw #3DB3
        defw #3E07
        defw #3E0E
        defw #3E15
        defw #3E52
        defw #3DBA
        defw #3DC1
        defw #3DEB
        defw #3DDD
        defw #3E59
        defw #3E60
        defw #3E67
        defw #3DE4
tbl_room_junction_entity_template_3D97:
        ; Template d'entite de decor de jonction entre 2 salles (poteau de porte
        ; type #02/#03, ou segment de mur #0A-#0F, etc.), copie via
        ; tbl_room_connections dans le tableau d'entites actives par
        ; fn_instantiate_room_objects. Format : octet0=type d'entite,
        ; octet1=grid_x, octet2=grid_y, octet3=#80 constant (grid_z_or_offset, PAS
        ; un numero de room), octets4-6=bbox/autres champs, octet7=flags (egal au
        ; champ flags de l'entite reelle), octet8=numero de room courant.
        defb #07,#08,#08,#0C,#10,#00,#00
tbl_room_junction_entity_template_3D9E:
        ; Template d'entite de decor de jonction entre 2 salles (poteau de porte
        ; type #02/#03, ou segment de mur #0A-#0F, etc.), copie via
        ; tbl_room_connections dans le tableau d'entites actives par
        ; fn_instantiate_room_objects. Format : octet0=type d'entite,
        ; octet1=grid_x, octet2=grid_y, octet3=#80 constant (grid_z_or_offset, PAS
        ; un numero de room), octets4-6=bbox/autres champs, octet7=flags (egal au
        ; champ flags de l'entite reelle), octet8=numero de room courant.
        defb #07,#08,#08,#0C,#10,#30,#00
tbl_room_junction_entity_template_3DA5:
        ; Template d'entite de decor de jonction entre 2 salles (poteau de porte
        ; type #02/#03, ou segment de mur #0A-#0F, etc.), copie via
        ; tbl_room_connections dans le tableau d'entites actives par
        ; fn_instantiate_room_objects. Format : octet0=type d'entite,
        ; octet1=grid_x, octet2=grid_y, octet3=#80 constant (grid_z_or_offset, PAS
        ; un numero de room), octets4-6=bbox/autres champs, octet7=flags (egal au
        ; champ flags de l'entite reelle), octet8=numero de room courant.
        defb #36,#08,#08,#0C,#10,#00,#00
tbl_room_junction_entity_template_3DAC:
        ; Template d'entite de decor de jonction entre 2 salles (poteau de porte
        ; type #02/#03, ou segment de mur #0A-#0F, etc.), copie via
        ; tbl_room_connections dans le tableau d'entites actives par
        ; fn_instantiate_room_objects. Format : octet0=type d'entite,
        ; octet1=grid_x, octet2=grid_y, octet3=#80 constant (grid_z_or_offset, PAS
        ; un numero de room), octets4-6=bbox/autres champs, octet7=flags (egal au
        ; champ flags de l'entite reelle), octet8=numero de room courant.
        defb #37,#08,#08,#0C,#10,#00,#00
tbl_room_junction_entity_template_3DB3:
        ; Template d'entite de decor de jonction entre 2 salles (poteau de porte
        ; type #02/#03, ou segment de mur #0A-#0F, etc.), copie via
        ; tbl_room_connections dans le tableau d'entites actives par
        ; fn_instantiate_room_objects. Format : octet0=type d'entite,
        ; octet1=grid_x, octet2=grid_y, octet3=#80 constant (grid_z_or_offset, PAS
        ; un numero de room), octets4-6=bbox/autres champs, octet7=flags (egal au
        ; champ flags de l'entite reelle), octet8=numero de room courant.
        defb #3E,#08,#08,#0C,#14,#00,#00
tbl_room_junction_entity_template_3DBA:
        ; Template d'entite de decor de jonction entre 2 salles (poteau de porte
        ; type #02/#03, ou segment de mur #0A-#0F, etc.), copie via
        ; tbl_room_connections dans le tableau d'entites actives par
        ; fn_instantiate_room_objects. Format : octet0=type d'entite,
        ; octet1=grid_x, octet2=grid_y, octet3=#80 constant (grid_z_or_offset, PAS
        ; un numero de room), octets4-6=bbox/autres champs, octet7=flags (egal au
        ; champ flags de l'entite reelle), octet8=numero de room courant.
        defb #5B,#08,#08,#0C,#10,#00,#00
tbl_room_junction_entity_template_3DC1:
        ; Template d'entite de decor de jonction entre 2 salles (poteau de porte
        ; type #02/#03, ou segment de mur #0A-#0F, etc.), copie via
        ; tbl_room_connections dans le tableau d'entites actives par
        ; fn_instantiate_room_objects. Format : octet0=type d'entite,
        ; octet1=grid_x, octet2=grid_y, octet3=#80 constant (grid_z_or_offset, PAS
        ; un numero de room), octets4-6=bbox/autres champs, octet7=flags (egal au
        ; champ flags de l'entite reelle), octet8=numero de room courant.
        defb #8F,#08,#08,#0C,#10,#00,#00
tbl_room_junction_entity_template_3DC8:
        ; Template d'entite de decor de jonction entre 2 salles (poteau de porte
        ; type #02/#03, ou segment de mur #0A-#0F, etc.), copie via
        ; tbl_room_connections dans le tableau d'entites actives par
        ; fn_instantiate_room_objects. Format : octet0=type d'entite,
        ; octet1=grid_x, octet2=grid_y, octet3=#80 constant (grid_z_or_offset, PAS
        ; un numero de room), octets4-6=bbox/autres champs, octet7=flags (egal au
        ; champ flags de l'entite reelle), octet8=numero de room courant.
        defb #B0,#06,#06,#0C,#10,#00,#00
tbl_room_junction_entity_template_3DCF:
        ; Template d'entite de decor de jonction entre 2 salles (poteau de porte
        ; type #02/#03, ou segment de mur #0A-#0F, etc.), copie via
        ; tbl_room_connections dans le tableau d'entites actives par
        ; fn_instantiate_room_objects. Format : octet0=type d'entite,
        ; octet1=grid_x, octet2=grid_y, octet3=#80 constant (grid_z_or_offset, PAS
        ; un numero de room), octets4-6=bbox/autres champs, octet7=flags (egal au
        ; champ flags de l'entite reelle), octet8=numero de room courant.
        defb #B2,#07,#07,#0C,#10,#02,#00
tbl_room_junction_entity_template_3DD6:
        ; Template d'entite de decor de jonction entre 2 salles (poteau de porte
        ; type #02/#03, ou segment de mur #0A-#0F, etc.), copie via
        ; tbl_room_connections dans le tableau d'entites actives par
        ; fn_instantiate_room_objects. Format : octet0=type d'entite,
        ; octet1=grid_x, octet2=grid_y, octet3=#80 constant (grid_z_or_offset, PAS
        ; un numero de room), octets4-6=bbox/autres champs, octet7=flags (egal au
        ; champ flags de l'entite reelle), octet8=numero de room courant.
        defb #B2,#07,#07,#0C,#10,#03,#00
tbl_room_junction_entity_template_3DDD:
        ; Template d'entite de decor de jonction entre 2 salles (poteau de porte
        ; type #02/#03, ou segment de mur #0A-#0F, etc.), copie via
        ; tbl_room_connections dans le tableau d'entites actives par
        ; fn_instantiate_room_objects. Format : octet0=type d'entite,
        ; octet1=grid_x, octet2=grid_y, octet3=#80 constant (grid_z_or_offset, PAS
        ; un numero de room), octets4-6=bbox/autres champs, octet7=flags (egal au
        ; champ flags de l'entite reelle), octet8=numero de room courant.
        defb #B2,#07,#07,#0C,#10,#00,#00
tbl_room_junction_entity_template_3DE4:
        ; Template d'entite de decor de jonction entre 2 salles (poteau de porte
        ; type #02/#03, ou segment de mur #0A-#0F, etc.), copie via
        ; tbl_room_connections dans le tableau d'entites actives par
        ; fn_instantiate_room_objects. Format : octet0=type d'entite,
        ; octet1=grid_x, octet2=grid_y, octet3=#80 constant (grid_z_or_offset, PAS
        ; un numero de room), octets4-6=bbox/autres champs, octet7=flags (egal au
        ; champ flags de l'entite reelle), octet8=numero de room courant.
        defb #B2,#07,#07,#0C,#10,#01,#00
tbl_room_junction_entity_template_3DEB:
        ; Template d'entite de decor de jonction entre 2 salles (poteau de porte
        ; type #02/#03, ou segment de mur #0A-#0F, etc.), copie via
        ; tbl_room_connections dans le tableau d'entites actives par
        ; fn_instantiate_room_objects. Format : octet0=type d'entite,
        ; octet1=grid_x, octet2=grid_y, octet3=#80 constant (grid_z_or_offset, PAS
        ; un numero de room), octets4-6=bbox/autres champs, octet7=flags (egal au
        ; champ flags de l'entite reelle), octet8=numero de room courant.
        defb #B6,#07,#07,#0C,#10,#00,#00
tbl_room_junction_entity_template_3DF2:
        ; Template d'entite de decor de jonction entre 2 salles (poteau de porte
        ; type #02/#03, ou segment de mur #0A-#0F, etc.), copie via
        ; tbl_room_connections dans le tableau d'entites actives par
        ; fn_instantiate_room_objects. Format : octet0=type d'entite,
        ; octet1=grid_x, octet2=grid_y, octet3=#80 constant (grid_z_or_offset, PAS
        ; un numero de room), octets4-6=bbox/autres champs, octet7=flags (egal au
        ; champ flags de l'entite reelle), octet8=numero de room courant.
        defb #06,#08,#08,#0C,#10,#00,#00
tbl_room_junction_entity_template_3DF9:
        ; Template d'entite de decor de jonction entre 2 salles (poteau de porte
        ; type #02/#03, ou segment de mur #0A-#0F, etc.), copie via
        ; tbl_room_connections dans le tableau d'entites actives par
        ; fn_instantiate_room_objects. Format : octet0=type d'entite,
        ; octet1=grid_x, octet2=grid_y, octet3=#80 constant (grid_z_or_offset, PAS
        ; un numero de room), octets4-6=bbox/autres champs, octet7=flags (egal au
        ; champ flags de l'entite reelle), octet8=numero de room courant.
        defb #16,#06,#06,#0C,#10,#00,#00
tbl_room_junction_entity_template_3E00:
        ; Template d'entite de decor de jonction entre 2 salles (poteau de porte
        ; type #02/#03, ou segment de mur #0A-#0F, etc.), copie via
        ; tbl_room_connections dans le tableau d'entites actives par
        ; fn_instantiate_room_objects. Format : octet0=type d'entite,
        ; octet1=grid_x, octet2=grid_y, octet3=#80 constant (grid_z_or_offset, PAS
        ; un numero de room), octets4-6=bbox/autres champs, octet7=flags (egal au
        ; champ flags de l'entite reelle), octet8=numero de room courant.
        defb #17,#06,#06,#0C,#50,#00,#00
tbl_room_junction_entity_template_3E07:
        ; Template d'entite de decor de jonction entre 2 salles (poteau de porte
        ; type #02/#03, ou segment de mur #0A-#0F, etc.), copie via
        ; tbl_room_connections dans le tableau d'entites actives par
        ; fn_instantiate_room_objects. Format : octet0=type d'entite,
        ; octet1=grid_x, octet2=grid_y, octet3=#80 constant (grid_z_or_offset, PAS
        ; un numero de room), octets4-6=bbox/autres champs, octet7=flags (egal au
        ; champ flags de l'entite reelle), octet8=numero de room courant.
        defb #17,#06,#06,#0C,#50,#30,#00
tbl_room_junction_entity_template_3E0E:
        ; Template d'entite de decor de jonction entre 2 salles (poteau de porte
        ; type #02/#03, ou segment de mur #0A-#0F, etc.), copie via
        ; tbl_room_connections dans le tableau d'entites actives par
        ; fn_instantiate_room_objects. Format : octet0=type d'entite,
        ; octet1=grid_x, octet2=grid_y, octet3=#80 constant (grid_z_or_offset, PAS
        ; un numero de room), octets4-6=bbox/autres champs, octet7=flags (egal au
        ; champ flags de l'entite reelle), octet8=numero de room courant.
        defb #3F,#06,#06,#0C,#10,#00,#00
tbl_room_junction_entity_template_3E15:
        ; Template d'entite de decor de jonction entre 2 salles (poteau de porte
        ; type #02/#03, ou segment de mur #0A-#0F, etc.), copie via
        ; tbl_room_connections dans le tableau d'entites actives par
        ; fn_instantiate_room_objects. Format : octet0=type d'entite,
        ; octet1=grid_x, octet2=grid_y, octet3=#80 constant (grid_z_or_offset, PAS
        ; un numero de room), octets4-6=bbox/autres champs, octet7=flags (egal au
        ; champ flags de l'entite reelle), octet8=numero de room courant.
        defb #3F,#06,#06,#0C,#10,#30,#00
tbl_room_junction_entity_template_3E1C:
        ; Template d'entite de decor de jonction entre 2 salles (poteau de porte
        ; type #02/#03, ou segment de mur #0A-#0F, etc.), copie via
        ; tbl_room_connections dans le tableau d'entites actives par
        ; fn_instantiate_room_objects. Format : octet0=type d'entite,
        ; octet1=grid_x, octet2=grid_y, octet3=#80 constant (grid_z_or_offset, PAS
        ; un numero de room), octets4-6=bbox/autres champs, octet7=flags (egal au
        ; champ flags de l'entite reelle), octet8=numero de room courant.
        defb #55,#09,#06,#0C,#14,#00,#00
tbl_room_junction_entity_template_3E23:
        ; Template d'entite de decor de jonction entre 2 salles (poteau de porte
        ; type #02/#03, ou segment de mur #0A-#0F, etc.), copie via
        ; tbl_room_connections dans le tableau d'entites actives par
        ; fn_instantiate_room_objects. Format : octet0=type d'entite,
        ; octet1=grid_x, octet2=grid_y, octet3=#80 constant (grid_z_or_offset, PAS
        ; un numero de room), octets4-6=bbox/autres champs, octet7=flags (egal au
        ; champ flags de l'entite reelle), octet8=numero de room courant.
        defb #54,#06,#0A,#0C,#14,#00,#00
tbl_room_junction_entity_template_3E2A:
        ; Template d'entite de decor de jonction entre 2 salles (poteau de porte
        ; type #02/#03, ou segment de mur #0A-#0F, etc.), copie via
        ; tbl_room_connections dans le tableau d'entites actives par
        ; fn_instantiate_room_objects. Format : octet0=type d'entite,
        ; octet1=grid_x, octet2=grid_y, octet3=#80 constant (grid_z_or_offset, PAS
        ; un numero de room), octets4-6=bbox/autres champs, octet7=flags (egal au
        ; champ flags de l'entite reelle), octet8=numero de room courant.
        defb #96,#06,#06,#18,#10,#02,#90,#06,#06,#00,#12,#02,#00
tbl_room_junction_entity_template_3E37:
        ; Template d'entite de decor de jonction entre 2 salles (poteau de porte
        ; type #02/#03, ou segment de mur #0A-#0F, etc.), copie via
        ; tbl_room_connections dans le tableau d'entites actives par
        ; fn_instantiate_room_objects. Format : octet0=type d'entite,
        ; octet1=grid_x, octet2=grid_y, octet3=#80 constant (grid_z_or_offset, PAS
        ; un numero de room), octets4-6=bbox/autres champs, octet7=flags (egal au
        ; champ flags de l'entite reelle), octet8=numero de room courant.
        defb #1E,#06,#06,#18,#10,#00,#90,#06,#06,#00,#12,#00,#00
tbl_room_junction_entity_template_3E44:
        ; Template d'entite de decor de jonction entre 2 salles (poteau de porte
        ; type #02/#03, ou segment de mur #0A-#0F, etc.), copie via
        ; tbl_room_connections dans le tableau d'entites actives par
        ; fn_instantiate_room_objects. Format : octet0=type d'entite,
        ; octet1=grid_x, octet2=grid_y, octet3=#80 constant (grid_z_or_offset, PAS
        ; un numero de room), octets4-6=bbox/autres champs, octet7=flags (egal au
        ; champ flags de l'entite reelle), octet8=numero de room courant.
        defb #52,#06,#06,#0C,#10,#00,#00
tbl_room_junction_entity_template_3E4B:
        ; Template d'entite de decor de jonction entre 2 salles (poteau de porte
        ; type #02/#03, ou segment de mur #0A-#0F, etc.), copie via
        ; tbl_room_connections dans le tableau d'entites actives par
        ; fn_instantiate_room_objects. Format : octet0=type d'entite,
        ; octet1=grid_x, octet2=grid_y, octet3=#80 constant (grid_z_or_offset, PAS
        ; un numero de room), octets4-6=bbox/autres champs, octet7=flags (egal au
        ; champ flags de l'entite reelle), octet8=numero de room courant.
        defb #B5,#06,#06,#0C,#10,#00,#00
tbl_room_junction_entity_template_3E52:
        ; Template d'entite de decor de jonction entre 2 salles (poteau de porte
        ; type #02/#03, ou segment de mur #0A-#0F, etc.), copie via
        ; tbl_room_connections dans le tableau d'entites actives par
        ; fn_instantiate_room_objects. Format : octet0=type d'entite,
        ; octet1=grid_x, octet2=grid_y, octet3=#80 constant (grid_z_or_offset, PAS
        ; un numero de room), octets4-6=bbox/autres champs, octet7=flags (egal au
        ; champ flags de l'entite reelle), octet8=numero de room courant.
        defb #56,#06,#06,#0C,#10,#00,#00
tbl_room_junction_entity_template_3E59:
        ; Template d'entite de decor de jonction entre 2 salles (poteau de porte
        ; type #02/#03, ou segment de mur #0A-#0F, etc.), copie via
        ; tbl_room_connections dans le tableau d'entites actives par
        ; fn_instantiate_room_objects. Format : octet0=type d'entite,
        ; octet1=grid_x, octet2=grid_y, octet3=#80 constant (grid_z_or_offset, PAS
        ; un numero de room), octets4-6=bbox/autres champs, octet7=flags (egal au
        ; champ flags de l'entite reelle), octet8=numero de room courant.
        defb #A4,#05,#05,#0C,#10,#00,#00
tbl_room_junction_entity_template_3E60:
        ; Template d'entite de decor de jonction entre 2 salles (poteau de porte
        ; type #02/#03, ou segment de mur #0A-#0F, etc.), copie via
        ; tbl_room_connections dans le tableau d'entites actives par
        ; fn_instantiate_room_objects. Format : octet0=type d'entite,
        ; octet1=grid_x, octet2=grid_y, octet3=#80 constant (grid_z_or_offset, PAS
        ; un numero de room), octets4-6=bbox/autres champs, octet7=flags (egal au
        ; champ flags de l'entite reelle), octet8=numero de room courant.
        defb #08,#0C,#01,#20,#50,#01,#00
tbl_room_junction_entity_template_3E67:
        ; Template d'entite de decor de jonction entre 2 salles (poteau de porte
        ; type #02/#03, ou segment de mur #0A-#0F, etc.), copie via
        ; tbl_room_connections dans le tableau d'entites actives par
        ; fn_instantiate_room_objects. Format : octet0=type d'entite,
        ; octet1=grid_x, octet2=grid_y, octet3=#80 constant (grid_z_or_offset, PAS
        ; un numero de room), octets4-6=bbox/autres champs, octet7=flags (egal au
        ; champ flags de l'entite reelle), octet8=numero de room courant.
        defb #08,#01,#0C,#20,#10,#02,#00
tbl_room_index_ptrs:
        ; Table de pointeurs word, indexée DIRECTEMENT par l'octet du payload de
        ; tbl_room_master_index (chemin par défaut). EXTENT CONFIRMÉE: exactement
        ; 24 entrées (0x3E6E-0x3E9E, 48 octets) — au-delà, les mots décodés
        ; cessent de ressembler à des pointeurs plausibles. Chaque pointeur mène à
        ; un bloc tbl_room_connection_detail_XXXX (voir ci-dessous)
        defw #3E9E
        defw #3EAF
        defw #3ED1
        defw #3EF3
        defw #3F04
        defw #3F15
        defw #3F26
        defw #3F37
        defw #3F48
        defw #3F51
        defw #3F5A
        defw #3F63
        defw #3F6C
        defw #3FD5
        defw #4046
        defw #40B7
        defw #4118
        defw #4129
        defw #413A
        defw #414B
        defw #3EC0
        defw #3EE2
        defw #415C
        defw #416D
tbl_room_connection_detail_3E9E:
        ; Template d'entite de decor de jonction entre 2 salles : 8 octets copies
        ; tels quels dans tbl_room_connections (sans calcul), correspondant
        ; exactement aux 8 premiers offsets de struct_entities_base (+0=type,
        ; +1=grid_x, +2=grid_y, +3=grid_z_or_offset, +4=bbox_w, +5=bbox_h,
        ; +6=bbox_d, +7=flags). Le numero de room (+8 de l'entite) est ajoute
        ; separement par fn_load_room_data. N chunks concatenes par bloc, termine
        ; par un chunk dont le 1er octet est #00 (non copie).
        defb #02,#8D,#C4,#80,#03,#05,#28,#50,#03,#73,#C4,#80,#03,#05,#28,#50
        defb #00
tbl_room_connection_detail_3EAF:
        ; Template d'entite de decor de jonction entre 2 salles : 8 octets copies
        ; tels quels dans tbl_room_connections (sans calcul), correspondant
        ; exactement aux 8 premiers offsets de struct_entities_base (+0=type,
        ; +1=grid_x, +2=grid_y, +3=grid_z_or_offset, +4=bbox_w, +5=bbox_h,
        ; +6=bbox_d, +7=flags). Le numero de room (+8 de l'entite) est ajoute
        ; separement par fn_load_room_data. N chunks concatenes par bloc, termine
        ; par un chunk dont le 1er octet est #00 (non copie).
        defb #02,#C4,#73,#80,#05,#03,#28,#10,#03,#C4,#8D,#80,#05,#03,#28,#10
        defb #00
tbl_room_connection_detail_3EC0:
        ; Template d'entite de decor de jonction entre 2 salles : 8 octets copies
        ; tels quels dans tbl_room_connections (sans calcul), correspondant
        ; exactement aux 8 premiers offsets de struct_entities_base (+0=type,
        ; +1=grid_x, +2=grid_y, +3=grid_z_or_offset, +4=bbox_w, +5=bbox_h,
        ; +6=bbox_d, +7=flags). Le numero de room (+8 de l'entite) est ajoute
        ; separement par fn_load_room_data. N chunks concatenes par bloc, termine
        ; par un chunk dont le 1er octet est #00 (non copie).
        defb #02,#C4,#73,#B0,#05,#03,#28,#10,#03,#C4,#8D,#B0,#05,#03,#28,#10
        defb #00
tbl_room_connection_detail_3ED1:
        ; Template d'entite de decor de jonction entre 2 salles : 8 octets copies
        ; tels quels dans tbl_room_connections (sans calcul), correspondant
        ; exactement aux 8 premiers offsets de struct_entities_base (+0=type,
        ; +1=grid_x, +2=grid_y, +3=grid_z_or_offset, +4=bbox_w, +5=bbox_h,
        ; +6=bbox_d, +7=flags). Le numero de room (+8 de l'entite) est ajoute
        ; separement par fn_load_room_data. N chunks concatenes par bloc, termine
        ; par un chunk dont le 1er octet est #00 (non copie).
        defb #02,#8D,#3B,#80,#03,#05,#28,#50,#03,#73,#3B,#80,#03,#05,#28,#50
        defb #00
tbl_room_connection_detail_3EE2:
        ; Template d'entite de decor de jonction entre 2 salles : 8 octets copies
        ; tels quels dans tbl_room_connections (sans calcul), correspondant
        ; exactement aux 8 premiers offsets de struct_entities_base (+0=type,
        ; +1=grid_x, +2=grid_y, +3=grid_z_or_offset, +4=bbox_w, +5=bbox_h,
        ; +6=bbox_d, +7=flags). Le numero de room (+8 de l'entite) est ajoute
        ; separement par fn_load_room_data. N chunks concatenes par bloc, termine
        ; par un chunk dont le 1er octet est #00 (non copie).
        defb #02,#8D,#3B,#B0,#03,#05,#28,#50,#03,#73,#3B,#B0,#03,#05,#28,#50
        defb #00
tbl_room_connection_detail_3EF3:
        ; Template d'entite de decor de jonction entre 2 salles : 8 octets copies
        ; tels quels dans tbl_room_connections (sans calcul), correspondant
        ; exactement aux 8 premiers offsets de struct_entities_base (+0=type,
        ; +1=grid_x, +2=grid_y, +3=grid_z_or_offset, +4=bbox_w, +5=bbox_h,
        ; +6=bbox_d, +7=flags). Le numero de room (+8 de l'entite) est ajoute
        ; separement par fn_load_room_data. N chunks concatenes par bloc, termine
        ; par un chunk dont le 1er octet est #00 (non copie).
        defb #02,#3B,#73,#80,#05,#03,#28,#10,#03,#3B,#8D,#80,#05,#03,#28,#10
        defb #00
tbl_room_connection_detail_3F04:
        ; Template d'entite de decor de jonction entre 2 salles : 8 octets copies
        ; tels quels dans tbl_room_connections (sans calcul), correspondant
        ; exactement aux 8 premiers offsets de struct_entities_base (+0=type,
        ; +1=grid_x, +2=grid_y, +3=grid_z_or_offset, +4=bbox_w, +5=bbox_h,
        ; +6=bbox_d, +7=flags). Le numero de room (+8 de l'entite) est ajoute
        ; separement par fn_load_room_data. N chunks concatenes par bloc, termine
        ; par un chunk dont le 1er octet est #00 (non copie).
        defb #04,#8D,#C4,#80,#03,#05,#28,#50,#05,#73,#C4,#80,#03,#05,#28,#50
        defb #00
tbl_room_connection_detail_3F15:
        ; Template d'entite de decor de jonction entre 2 salles : 8 octets copies
        ; tels quels dans tbl_room_connections (sans calcul), correspondant
        ; exactement aux 8 premiers offsets de struct_entities_base (+0=type,
        ; +1=grid_x, +2=grid_y, +3=grid_z_or_offset, +4=bbox_w, +5=bbox_h,
        ; +6=bbox_d, +7=flags). Le numero de room (+8 de l'entite) est ajoute
        ; separement par fn_load_room_data. N chunks concatenes par bloc, termine
        ; par un chunk dont le 1er octet est #00 (non copie).
        defb #04,#C4,#73,#80,#05,#03,#28,#10,#05,#C4,#8D,#80,#05,#03,#28,#10
        defb #00
tbl_room_connection_detail_3F26:
        ; Template d'entite de decor de jonction entre 2 salles : 8 octets copies
        ; tels quels dans tbl_room_connections (sans calcul), correspondant
        ; exactement aux 8 premiers offsets de struct_entities_base (+0=type,
        ; +1=grid_x, +2=grid_y, +3=grid_z_or_offset, +4=bbox_w, +5=bbox_h,
        ; +6=bbox_d, +7=flags). Le numero de room (+8 de l'entite) est ajoute
        ; separement par fn_load_room_data. N chunks concatenes par bloc, termine
        ; par un chunk dont le 1er octet est #00 (non copie).
        defb #04,#8D,#3B,#80,#03,#05,#28,#50,#05,#73,#3B,#80,#03,#05,#28,#50
        defb #00
tbl_room_connection_detail_3F37:
        ; Template d'entite de decor de jonction entre 2 salles : 8 octets copies
        ; tels quels dans tbl_room_connections (sans calcul), correspondant
        ; exactement aux 8 premiers offsets de struct_entities_base (+0=type,
        ; +1=grid_x, +2=grid_y, +3=grid_z_or_offset, +4=bbox_w, +5=bbox_h,
        ; +6=bbox_d, +7=flags). Le numero de room (+8 de l'entite) est ajoute
        ; separement par fn_load_room_data. N chunks concatenes par bloc, termine
        ; par un chunk dont le 1er octet est #00 (non copie).
        defb #04,#3B,#73,#80,#05,#03,#28,#10,#05,#3B,#8D,#80,#05,#03,#28,#10
        defb #00
tbl_room_connection_detail_3F48:
        ; Template d'entite de decor de jonction entre 2 salles : 8 octets copies
        ; tels quels dans tbl_room_connections (sans calcul), correspondant
        ; exactement aux 8 premiers offsets de struct_entities_base (+0=type,
        ; +1=grid_x, +2=grid_y, +3=grid_z_or_offset, +4=bbox_w, +5=bbox_h,
        ; +6=bbox_d, +7=flags). Le numero de room (+8 de l'entite) est ajoute
        ; separement par fn_load_room_data. N chunks concatenes par bloc, termine
        ; par un chunk dont le 1er octet est #00 (non copie).
        defb #08,#80,#BE,#A0,#0C,#01,#20,#50,#00
tbl_room_connection_detail_3F51:
        ; Template d'entite de decor de jonction entre 2 salles : 8 octets copies
        ; tels quels dans tbl_room_connections (sans calcul), correspondant
        ; exactement aux 8 premiers offsets de struct_entities_base (+0=type,
        ; +1=grid_x, +2=grid_y, +3=grid_z_or_offset, +4=bbox_w, +5=bbox_h,
        ; +6=bbox_d, +7=flags). Le numero de room (+8 de l'entite) est ajoute
        ; separement par fn_load_room_data. N chunks concatenes par bloc, termine
        ; par un chunk dont le 1er octet est #00 (non copie).
        defb #08,#BE,#80,#A0,#01,#0C,#20,#10,#00
tbl_room_connection_detail_3F5A:
        ; Template d'entite de decor de jonction entre 2 salles : 8 octets copies
        ; tels quels dans tbl_room_connections (sans calcul), correspondant
        ; exactement aux 8 premiers offsets de struct_entities_base (+0=type,
        ; +1=grid_x, +2=grid_y, +3=grid_z_or_offset, +4=bbox_w, +5=bbox_h,
        ; +6=bbox_d, +7=flags). Le numero de room (+8 de l'entite) est ajoute
        ; separement par fn_load_room_data. N chunks concatenes par bloc, termine
        ; par un chunk dont le 1er octet est #00 (non copie).
        defb #08,#80,#41,#A0,#0C,#01,#20,#50,#00
tbl_room_connection_detail_3F63:
        ; Template d'entite de decor de jonction entre 2 salles : 8 octets copies
        ; tels quels dans tbl_room_connections (sans calcul), correspondant
        ; exactement aux 8 premiers offsets de struct_entities_base (+0=type,
        ; +1=grid_x, +2=grid_y, +3=grid_z_or_offset, +4=bbox_w, +5=bbox_h,
        ; +6=bbox_d, +7=flags). Le numero de room (+8 de l'entite) est ajoute
        ; separement par fn_load_room_data. N chunks concatenes par bloc, termine
        ; par un chunk dont le 1er octet est #00 (non copie).
        defb #08,#41,#80,#A0,#01,#0C,#20,#10,#00
tbl_room_connection_detail_3F6C:
        ; Template d'entite de decor de jonction entre 2 salles : 8 octets copies
        ; tels quels dans tbl_room_connections (sans calcul), correspondant
        ; exactement aux 8 premiers offsets de struct_entities_base (+0=type,
        ; +1=grid_x, +2=grid_y, +3=grid_z_or_offset, +4=bbox_w, +5=bbox_h,
        ; +6=bbox_d, +7=flags). Le numero de room (+8 de l'entite) est ajoute
        ; separement par fn_load_room_data. N chunks concatenes par bloc, termine
        ; par un chunk dont le 1er octet est #00 (non copie).
        defb #0D,#3F,#B8,#80,#00,#08,#28,#10,#0E,#47,#C0,#80,#08,#00,#28,#10
        defb #0F,#3F,#49,#80,#00,#08,#2C,#10,#0F,#B8,#C0,#80,#08,#00,#2C,#50
        defb #0F,#3F,#49,#AC,#00,#08,#2C,#10,#0F,#B8,#C0,#AC,#08,#00,#2C,#50
        defb #0A,#5C,#C0,#80,#14,#00,#14,#50,#0B,#3F,#5C,#96,#00,#0C,#14,#10
        defb #0C,#3F,#9C,#96,#00,#0C,#0C,#10,#0B,#A4,#C0,#96,#0C,#00,#14,#50
        defb #0A,#3F,#6D,#B1,#00,#14,#14,#10,#0C,#60,#C0,#A0,#0C,#00,#0C,#50
        defb #0A,#90,#C0,#B0,#14,#00,#14,#50,#00
tbl_room_connection_detail_3FD5:
        ; Template d'entite de decor de jonction entre 2 salles : 8 octets copies
        ; tels quels dans tbl_room_connections (sans calcul), correspondant
        ; exactement aux 8 premiers offsets de struct_entities_base (+0=type,
        ; +1=grid_x, +2=grid_y, +3=grid_z_or_offset, +4=bbox_w, +5=bbox_h,
        ; +6=bbox_d, +7=flags). Le numero de room (+8 de l'entite) est ajoute
        ; separement par fn_load_room_data. N chunks concatenes par bloc, termine
        ; par un chunk dont le 1er octet est #00 (non copie).
        defb #0D,#3F,#98,#80,#00,#08,#28,#10,#0E,#47,#A0,#80,#08,#00,#28,#10
        defb #0F,#3F,#63,#80,#00,#08,#2C,#10,#0F,#B8,#A0,#80,#08,#00,#2C,#50
        defb #0F,#3F,#63,#AC,#00,#08,#2C,#10,#0F,#B8,#A0,#AC,#08,#00,#2C,#50
        defb #0D,#3F,#98,#A8,#00,#08,#28,#10,#0E,#47,#A0,#A8,#08,#00,#28,#10
        defb #0F,#B8,#A0,#D0,#08,#00,#2C,#50,#0A,#80,#A0,#80,#14,#00,#14,#50
        defb #0A,#3F,#7E,#B0,#00,#14,#14,#10,#0B,#60,#A0,#90,#0C,#00,#14,#50
        defb #0A,#60,#A0,#B8,#14,#00,#14,#50,#0C,#A0,#A0,#B0,#0C,#00,#0C,#50
        defb #00
tbl_room_connection_detail_4046:
        ; Template d'entite de decor de jonction entre 2 salles : 8 octets copies
        ; tels quels dans tbl_room_connections (sans calcul), correspondant
        ; exactement aux 8 premiers offsets de struct_entities_base (+0=type,
        ; +1=grid_x, +2=grid_y, +3=grid_z_or_offset, +4=bbox_w, +5=bbox_h,
        ; +6=bbox_d, +7=flags). Le numero de room (+8 de l'entite) est ajoute
        ; separement par fn_load_room_data. N chunks concatenes par bloc, termine
        ; par un chunk dont le 1er octet est #00 (non copie).
        defb #0D,#5F,#B8,#80,#00,#08,#28,#10,#0E,#67,#C0,#80,#08,#00,#28,#10
        defb #0F,#5F,#48,#80,#00,#08,#2C,#10,#0F,#9D,#C0,#80,#08,#00,#2C,#50
        defb #0D,#5F,#B8,#A8,#00,#08,#28,#10,#0E,#67,#C0,#A8,#08,#00,#28,#10
        defb #0F,#5F,#48,#AC,#00,#08,#2C,#10,#0F,#9D,#C0,#AC,#08,#00,#2C,#50
        defb #0F,#5F,#48,#D0,#00,#08,#2C,#10,#0A,#5F,#90,#80,#00,#14,#14,#10
        defb #0A,#84,#C0,#B0,#14,#00,#14,#50,#0B,#5F,#60,#90,#00,#0C,#14,#10
        defb #0A,#5F,#68,#B8,#00,#14,#14,#10,#0C,#5F,#A0,#B0,#00,#0C,#0C,#10
        defb #00
tbl_room_connection_detail_40B7:
        ; Template d'entite de decor de jonction entre 2 salles : 8 octets copies
        ; tels quels dans tbl_room_connections (sans calcul), correspondant
        ; exactement aux 8 premiers offsets de struct_entities_base (+0=type,
        ; +1=grid_x, +2=grid_y, +3=grid_z_or_offset, +4=bbox_w, +5=bbox_h,
        ; +6=bbox_d, +7=flags). Le numero de room (+8 de l'entite) est ajoute
        ; separement par fn_load_room_data. N chunks concatenes par bloc, termine
        ; par un chunk dont le 1er octet est #00 (non copie).
        defb #80,#3F,#49,#80,#00,#08,#2C,#10,#80,#3F,#58,#80,#00,#08,#2C,#D0
        defb #80,#3F,#68,#80,#00,#08,#2C,#10,#80,#3F,#98,#80,#00,#08,#2C,#D0
        defb #80,#3F,#A8,#80,#00,#08,#2C,#10,#80,#3F,#B8,#80,#00,#08,#2C,#D0
        defb #80,#48,#C0,#80,#08,#00,#2C,#50,#80,#58,#C0,#80,#08,#00,#2C,#90
        defb #80,#68,#C0,#80,#08,#00,#2C,#50,#80,#98,#C0,#80,#08,#00,#2C,#90
        defb #80,#A8,#C0,#80,#08,#00,#2C,#50,#80,#B8,#C0,#80,#08,#00,#2C,#90
        defb #00
tbl_room_connection_detail_4118:
        ; Template d'entite de decor de jonction entre 2 salles : 8 octets copies
        ; tels quels dans tbl_room_connections (sans calcul), correspondant
        ; exactement aux 8 premiers offsets de struct_entities_base (+0=type,
        ; +1=grid_x, +2=grid_y, +3=grid_z_or_offset, +4=bbox_w, +5=bbox_h,
        ; +6=bbox_d, +7=flags). Le numero de room (+8 de l'entite) est ajoute
        ; separement par fn_load_room_data. N chunks concatenes par bloc, termine
        ; par un chunk dont le 1er octet est #00 (non copie).
        defb #80,#3F,#78,#80,#00,#08,#2C,#10,#80,#3F,#88,#80,#00,#08,#2C,#D0
        defb #00
tbl_room_connection_detail_4129:
        ; Template d'entite de decor de jonction entre 2 salles : 8 octets copies
        ; tels quels dans tbl_room_connections (sans calcul), correspondant
        ; exactement aux 8 premiers offsets de struct_entities_base (+0=type,
        ; +1=grid_x, +2=grid_y, +3=grid_z_or_offset, +4=bbox_w, +5=bbox_h,
        ; +6=bbox_d, +7=flags). Le numero de room (+8 de l'entite) est ajoute
        ; separement par fn_load_room_data. N chunks concatenes par bloc, termine
        ; par un chunk dont le 1er octet est #00 (non copie).
        defb #80,#78,#C0,#80,#08,#00,#2C,#50,#80,#88,#C0,#80,#08,#00,#2C,#90
        defb #00
tbl_room_connection_detail_413A:
        ; Template d'entite de decor de jonction entre 2 salles : 8 octets copies
        ; tels quels dans tbl_room_connections (sans calcul), correspondant
        ; exactement aux 8 premiers offsets de struct_entities_base (+0=type,
        ; +1=grid_x, +2=grid_y, +3=grid_z_or_offset, +4=bbox_w, +5=bbox_h,
        ; +6=bbox_d, +7=flags). Le numero de room (+8 de l'entite) est ajoute
        ; separement par fn_load_room_data. N chunks concatenes par bloc, termine
        ; par un chunk dont le 1er octet est #00 (non copie).
        defb #9E,#98,#68,#80,#05,#05,#18,#10,#90,#A0,#60,#80,#05,#05,#00,#12
        defb #00
tbl_room_connection_detail_414B:
        ; Template d'entite de decor de jonction entre 2 salles : 8 octets copies
        ; tels quels dans tbl_room_connections (sans calcul), correspondant
        ; exactement aux 8 premiers offsets de struct_entities_base (+0=type,
        ; +1=grid_x, +2=grid_y, +3=grid_z_or_offset, +4=bbox_w, +5=bbox_h,
        ; +6=bbox_d, +7=flags). Le numero de room (+8 de l'entite) est ajoute
        ; separement par fn_load_room_data. N chunks concatenes par bloc, termine
        ; par un chunk dont le 1er octet est #00 (non copie).
        defb #8D,#80,#80,#80,#0A,#0A,#18,#10,#8E,#80,#88,#80,#00,#00,#00,#12
        defb #00
tbl_room_connection_detail_415C:
        ; Template d'entite de decor de jonction entre 2 salles : 8 octets copies
        ; tels quels dans tbl_room_connections (sans calcul), correspondant
        ; exactement aux 8 premiers offsets de struct_entities_base (+0=type,
        ; +1=grid_x, +2=grid_y, +3=grid_z_or_offset, +4=bbox_w, +5=bbox_h,
        ; +6=bbox_d, +7=flags). Le numero de room (+8 de l'entite) est ajoute
        ; separement par fn_load_room_data. N chunks concatenes par bloc, termine
        ; par un chunk dont le 1er octet est #00 (non copie).
        defb #07,#C8,#78,#A4,#08,#08,#0C,#10,#07,#C8,#88,#A4,#08,#08,#0C,#10
        defb #00
tbl_room_connection_detail_416D:
        ; Template d'entite de decor de jonction entre 2 salles : 8 octets copies
        ; tels quels dans tbl_room_connections (sans calcul), correspondant
        ; exactement aux 8 premiers offsets de struct_entities_base (+0=type,
        ; +1=grid_x, +2=grid_y, +3=grid_z_or_offset, +4=bbox_w, +5=bbox_h,
        ; +6=bbox_d, +7=flags). Le numero de room (+8 de l'entite) est ajoute
        ; separement par fn_load_room_data. N chunks concatenes par bloc, termine
        ; par un chunk dont le 1er octet est #00 (non copie).
        defb #07,#78,#38,#A4,#08,#08,#0C,#10,#07,#88,#38,#A4,#08,#08,#0C,#10
        defb #00
tbl_object_catalog:
        ; 32 entrées de 9 octets (0x417E-0x429E exactement). Layout réel: +0=TYPE
        ; (RÉÉCRIT chaque partie par fn_catalog_randomize_types, valeur
        ; 0x60-0x67), +1..+4=template FIXE (grid_x/y/z/room, jamais modifié),
        ; +5..+8=copie de travail (RÉÉCRITE depuis +1..+4 chaque partie, lue par
        ; fn_instantiate_room_objects).
        defb #00,#88,#80,#A4,#6D,#00,#00,#00,#00,#00,#80,#80,#8C,#27,#00,#00
        defb #00,#00,#00,#88,#78,#B0,#D0,#00,#00,#00,#00,#00,#78,#88,#80,#0A
        defb #00,#00,#00,#00,#00,#78,#88,#80,#BA,#00,#00,#00,#00,#00,#88,#78
        defb #B0,#42,#00,#00,#00,#00,#00,#88,#B8,#BC,#8D,#00,#00,#00,#00,#00
        defb #A8,#A8,#80,#FF,#00,#00,#00,#00,#00,#80,#80,#80,#87,#00,#00,#00
        defb #00,#00,#78,#B8,#80,#F3,#00,#00,#00,#00,#00,#A8,#68,#B0,#A8,#00
        defb #00,#00,#00,#00,#B8,#48,#B0,#D2,#00,#00,#00,#00,#00,#48,#48,#80
        defb #00,#00,#00,#00,#00,#00,#88,#B8,#80,#22,#00,#00,#00,#00,#00,#B8
        defb #B8,#B0,#7A,#00,#00,#00,#00,#00,#B8,#B8,#80,#F9,#00,#00,#00,#00
        defb #00,#88,#98,#B0,#D6,#00,#00,#00,#00,#00,#78,#88,#B0,#E8,#00,#00
        defb #00,#00,#00,#78,#78,#B0,#F6,#00,#00,#00,#00,#00,#88,#78,#8C,#0F
        defb #00,#00,#00,#00,#00,#B8,#B8,#80,#6F,#00,#00,#00,#00,#00,#48,#B8
        defb #A4,#FD,#00,#00,#00,#00,#00,#78,#78,#B0,#08,#00,#00,#00,#00,#00
        defb #88,#88,#A4,#BB,#00,#00,#00,#00,#00,#78,#78,#B0,#DF,#00,#00,#00
        defb #00,#00,#80,#80,#80,#5E,#00,#00,#00,#00,#00,#78,#88,#B0,#B4,#00
        defb #00,#00,#00,#00,#78,#78,#B0,#04,#00,#00,#00,#00,#00,#48,#B8,#80
        defb #74,#00,#00,#00,#00,#00,#80,#80,#80,#40,#00,#00,#00,#00,#00,#68
        defb #78,#B0,#38,#00,#00,#00,#00,#00,#48,#B8,#98,#F0,#00,#00,#00,#00
tbl_sprite_dispatch:
        ; Table de pointeurs word vers les données de forme, indexée par (ix+00).
        ; EXTENT CONFIRMÉE: exactement 194 entrées (#429E-#4421, types #00-#C1) —
        ; même méthode que pour tbl_entity_logic_dispatch (vérification que chaque
        ; mot pointe dans la zone RESSOURCES #4000-#7FFF; l'entrée 194 sort de
        ; cette plage, ET l'entrée 0 pointe exactement sur #4422, l'octet qui suit
        ; la dernière entrée valide — double confirmation). Légèrement plus large
        ; que tbl_entity_logic_dispatch (188 entrées, types #00-#BB), cohérent
        ; avec quelques types render-only sans logique IA dédiée (#BC-#C1)
        defw #4422
        defw #4422
        defw #5AC6
        defw #5C01
        defw #6197
        defw #6286
        defw #5678
        defw #59DB
        defw #7BD7
        defw #7BD7
        defw #5ED5
        defw #5FD2
        defw #6065
        defw #5C90
        defw #5D4F
        defw #5E12
        defw #6BC0
        defw #6C23
        defw #6C86
        defw #6CE9
        defw #6C86
        defw #6C23
        defw #7DB9
        defw #5595
        defw #6D4C
        defw #6DB5
        defw #6E1E
        defw #6E87
        defw #6E1E
        defw #6DB5
        defw #4BA0
        defw #4C2D
        defw #6684
        defw #6717
        defw #642C
        defw #65F1
        defw #642C
        defw #6717
        defw #6558
        defw #69FB
        defw #6830
        defw #64BF
        defw #6962
        defw #68C9
        defw #6962
        defw #64BF
        defw #6B27
        defw #6A8E
        defw #788F
        defw #78F2
        defw #7955
        defw #79B8
        defw #7955
        defw #78F2
        defw #59DB
        defw #59DB
        defw #7A1B
        defw #7A8A
        defw #7AF9
        defw #7B68
        defw #7AF9
        defw #7A8A
        defw #59DB
        defw #7E4C
        defw #701F
        defw #70D0
        defw #7181
        defw #7232
        defw #7181
        defw #70D0
        defw #75BF
        defw #7670
        defw #7508
        defw #7451
        defw #739A
        defw #72E3
        defw #739A
        defw #7451
        defw #7721
        defw #77D8
        defw #4804
        defw #487F
        defw #48F4
        defw #496F
        defw #7CD6
        defw #54AA
        defw #5763
        defw #57A2
        defw #67AA
        defw #67ED
        defw #57E5
        defw #59DB
        defw #4CBA
        defw #4D7D
        defw #4E46
        defw #4F2D
        defw #4687
        defw #4600
        defw #446B
        defw #4702
        defw #4795
        defw #456D
        defw #44EC
        defw #4424
        defw #4687
        defw #4600
        defw #446B
        defw #4702
        defw #4795
        defw #456D
        defw #44EC
        defw #52B1
        defw #52B1
        defw #521E
        defw #52B1
        defw #521E
        defw #518B
        defw #50FE
        defw #507D
        defw #5002
        defw #5002
        defw #507D
        defw #50FE
        defw #518B
        defw #521E
        defw #52B1
        defw #521E
        defw #52B1
        defw #60D4
        defw #4422
        defw #4422
        defw #52B1
        defw #521E
        defw #518B
        defw #6349
        defw #63AF
        defw #636C
        defw #6F2C
        defw #6F23
        defw #6EF0
        defw #4424
        defw #5344
        defw #544F
        defw #59DB
        defw #6BC0
        defw #6C23
        defw #6C86
        defw #6CE9
        defw #6C86
        defw #6C23
        defw #4BA0
        defw #4C2D
        defw #6D4C
        defw #6DB5
        defw #6E1E
        defw #6E87
        defw #6E1E
        defw #6DB5
        defw #4AD7
        defw #49EA
        defw #52B1
        defw #521E
        defw #518B
        defw #521E
        defw #52B1
        defw #521E
        defw #518B
        defw #521E
        defw #4687
        defw #4600
        defw #446B
        defw #4702
        defw #4795
        defw #456D
        defw #44EC
        defw #4424
        defw #5763
        defw #57A2
        defw #7F17
        defw #7F8C
        defw #5763
        defw #57A2
        defw #7F17
        defw #7F8C
        defw #52B1
        defw #521E
        defw #58E0
        defw #52B1
        defw #59DB
        defw #59DB
        defw #59DB
        defw #59DB
        defw #63DA
        defw #63E1
sprite_shape_none:
        ; Octet #00, teste par fn_resolve_sprite_shape qui fait un double RET
        ; (rien a dessiner). Pointeur par defaut de tbl_sprite_dispatch pour les
        ; types non implementes/reserves.
        defb #00
        ; non désassemblé
        defb #00
sprite_life_4424:
        ; Sprite "life" (4x17 octets/ligne, 68 octets de bitmap). Type(s) d'entite
        ; associe(s) via tbl_sprite_dispatch : 67,8C,AF.
        defb #04,#11,#00,#00,#EE,#33,#88,#11,#F1,#74,#C4,#11,#F4,#F8,#C4,#00
        defb #FA,#F8,#88,#00,#74,#F9,#00,#00,#FC,#F1,#88,#11,#F2,#F0,#C4,#11
        defb #F2,#F0,#C4,#11,#F2,#F0,#C4,#11,#F2,#F0,#C4,#11,#F1,#FC,#C4,#00
        defb #FA,#F2,#88,#00,#75,#F1,#00,#00,#75,#F1,#00,#00,#75,#F1,#00,#00
        defb #32,#EA,#00,#00,#11,#CC,#00
sprite_boot_446B:
        ; Sprite "boot" (6x21 octets/ligne, 126 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 62,6A,AA.
        defb #06,#15,#00,#00,#33,#EE,#00,#00,#00,#00,#47,#1F,#00,#00,#00,#00
        defb #8F,#0F,#88,#00,#00,#11,#3F,#EF,#4C,#00,#00,#11,#7C,#F1,#AE,#77
        defb #00,#11,#F8,#F0,#D7,#8F,#88,#11,#F0,#F0,#E3,#0F,#4C,#11,#F6,#F0
        defb #F1,#EF,#4C,#11,#F3,#F1,#F0,#F1,#4C,#00,#F9,#F2,#F0,#F8,#88,#00
        defb #74,#F4,#F4,#F4,#C4,#00,#33,#BA,#F0,#F4,#88,#00,#00,#11,#F4,#F2
        defb #88,#00,#00,#11,#F0,#F1,#00,#00,#00,#11,#F4,#F1,#00,#00,#00,#11
        defb #F3,#FE,#88,#00,#00,#32,#F7,#FF,#C4,#00,#00,#32,#FF,#FF,#C4,#00
        defb #00,#11,#F7,#FC,#88,#00,#00,#00,#F8,#F3,#00,#00,#00,#00,#77,#CC
        defb #00
sprite_crystal_ball_44EC:
        ; Sprite "crystal_ball" (6x21 octets/ligne, 126 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 66,6E,AE.
        defb #06,#15,#00,#00,#00,#FF,#FF,#00,#00,#00,#33,#0F,#0F,#CC,#00,#00
        defb #47,#0F,#0F,#2E,#00,#00,#8F,#7F,#EF,#1F,#00,#11,#1F,#F8,#F1,#8F
        defb #88,#00,#BE,#F0,#F0,#D7,#00,#00,#74,#F0,#F0,#E2,#00,#00,#F8,#F0
        defb #F0,#F1,#00,#00,#F8,#F0,#F0,#F1,#00,#11,#F0,#F0,#F0,#F0,#88,#11
        defb #F0,#F0,#F0,#F0,#88,#11,#F0,#F0,#F0,#F0,#88,#11,#F3,#F8,#F0,#F0
        defb #88,#11,#F3,#F8,#F0,#F0,#88,#11,#F3,#FC,#F0,#F0,#88,#11,#F9,#FF
        defb #F0,#F1,#00,#00,#F8,#FF,#F0,#F1,#00,#00,#74,#F7,#F0,#E2,#00,#00
        defb #32,#F0,#F0,#C4,#00,#00,#11,#F8,#F1,#88,#00,#00,#00,#77,#EE,#00
        defb #00
sprite_bottle_456D:
        ; Sprite "bottle" (6x24 octets/ligne, 144 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 65,6D,AD.
        defb #06,#18,#00,#00,#00,#FF,#EE,#00,#00,#00,#33,#F0,#F1,#88,#00,#00
        defb #75,#F0,#F0,#C4,#00,#00,#FB,#FF,#FC,#E2,#00,#00,#FB,#F0,#F4,#E2
        defb #00,#00,#FF,#F0,#F4,#E2,#00,#00,#FB,#F0,#F4,#E2,#00,#00,#FB,#F0
        defb #F4,#E2,#00,#00,#FB,#F0,#F4,#E2,#00,#00,#FB,#FF,#FC,#E2,#00,#00
        defb #FB,#F0,#F0,#E2,#00,#00,#FD,#F0,#F0,#E2,#00,#00,#F9,#F0,#F0,#E2
        defb #00,#00,#74,#F8,#F0,#C4,#00,#00,#74,#F4,#F0,#C4,#00,#00,#32,#F4
        defb #F0,#88,#00,#00,#11,#F2,#F1,#00,#00,#00,#00,#FA,#E2,#00,#00,#00
        defb #00,#FA,#E2,#00,#00,#00,#00,#FB,#EA,#00,#00,#00,#11,#C7,#7D,#00
        defb #00,#00,#00,#8F,#2E,#00,#00,#00,#00,#47,#4C,#00,#00,#00,#00,#33
        defb #88,#00,#00
sprite_poison_4600:
        ; Sprite "poison" (6x22 octets/ligne, 132 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 61,69,A9.
        defb #06,#16,#00,#00,#00,#FF,#FF,#00,#00,#00,#77,#F0,#F0,#EE,#00,#11
        defb #F8,#F0,#F0,#F1,#88,#32,#E1,#78,#E1,#78,#C4,#74,#E1,#96,#96,#78
        defb #E2,#74,#F0,#E1,#78,#F0,#E2,#F8,#F0,#96,#96,#F0,#F1,#F8,#E1,#69
        defb #69,#78,#F1,#F8,#E1,#69,#69,#78,#F1,#F8,#F0,#C3,#3C,#F0,#F1,#74
        defb #F0,#C3,#3C,#F0,#E2,#74,#F1,#E1,#78,#F8,#E2,#32,#F0,#F8,#F1,#F0
        defb #C4,#11,#F8,#F8,#F1,#F1,#88,#00,#77,#F8,#F1,#EE,#00,#00,#00,#F8
        defb #F1,#00,#00,#00,#00,#F8,#F1,#00,#00,#00,#00,#FB,#FD,#00,#00,#00
        defb #11,#F4,#F2,#88,#00,#00,#00,#F8,#F1,#00,#00,#00,#00,#FC,#E2,#00
        defb #00,#00,#00,#33,#CC,#00,#00
sprite_ruby_4687:
        ; Sprite "ruby" (6x20 octets/ligne, 120 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 60,68,A8.
        defb #06,#14,#00,#00,#00,#00,#88,#00,#00,#00,#00,#77,#FF,#00,#00,#00
        defb #00,#FA,#F2,#88,#00,#00,#11,#F2,#F2,#C4,#00,#00,#32,#F4,#F1,#E2
        defb #00,#00,#32,#F4,#F1,#E2,#00,#00,#74,#F8,#F0,#F9,#00,#00,#F8,#F8
        defb #F0,#F8,#88,#00,#F9,#F0,#F0,#F4,#88,#11,#F1,#F0,#F0,#F4,#C4,#32
        defb #F2,#FF,#FF,#FA,#E2,#32,#F5,#F0,#F0,#F5,#E2,#74,#F8,#F8,#F0,#F8
        defb #F9,#75,#F0,#F8,#F0,#F8,#F5,#32,#F1,#F7,#FF,#F4,#E2,#11,#F2,#F0
        defb #F0,#F2,#C4,#00,#FC,#F0,#F0,#F1,#88,#00,#32,#F0,#F0,#E2,#00,#00
        defb #11,#F0,#F0,#C4,#00,#00,#00,#FF,#FF,#88,#00
sprite_chalice_4702:
        ; Sprite "chalice" (6x24 octets/ligne, 144 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 63,6B,AB.
        defb #06,#18,#00,#00,#00,#77,#EE,#00,#00,#00,#33,#F8,#F1,#CC,#00,#00
        defb #76,#F0,#F0,#E2,#00,#00,#FE,#F1,#F8,#F1,#00,#11,#F3,#F2,#F4,#F0
        defb #88,#00,#F9,#FC,#F2,#F1,#00,#00,#74,#F7,#FE,#E2,#00,#00,#33,#FF
        defb #FF,#CC,#00,#00,#33,#FA,#F1,#CC,#00,#00,#32,#F4,#F0,#C4,#00,#00
        defb #74,#F8,#F0,#E2,#00,#00,#F9,#FF,#FF,#F1,#00,#11,#F7,#F0,#F0,#FE
        defb #88,#11,#FA,#F0,#F0,#F1,#88,#11,#F6,#FF,#FF,#F0,#CC,#32,#F7,#F0
        defb #F0,#FE,#C4,#32,#F8,#FF,#FF,#F1,#C4,#33,#F7,#FF,#FF,#FE,#CC,#32
        defb #FF,#FF,#FF,#FF,#C4,#32,#FF,#FF,#FF,#FF,#C4,#11,#F7,#FF,#FF,#FE
        defb #88,#00,#F8,#FF,#FF,#F1,#00,#00,#77,#F0,#F0,#EE,#00,#00,#00,#FF
        defb #FF,#00,#00
sprite_cup_4795:
        ; Sprite "cup" (6x18 octets/ligne, 108 octets de bitmap). Type(s) d'entite
        ; associe(s) via tbl_sprite_dispatch : 64,6C,AC.
        defb #06,#12,#00,#00,#77,#FF,#CC,#00,#00,#00,#F8,#F0,#E2,#00,#00,#11
        defb #F8,#FF,#F1,#00,#00,#11,#F6,#F0,#FD,#00,#00,#00,#F8,#F0,#F3,#FF
        defb #88,#11,#F0,#F0,#F1,#F0,#C4,#32,#F0,#F0,#F0,#F8,#E2,#74,#F0,#F0
        defb #F0,#F7,#E2,#74,#F1,#FF,#F0,#F7,#F9,#F8,#FE,#F0,#FE,#F3,#F9,#FB
        defb #F1,#FF,#F1,#FB,#F9,#FC,#FF,#FF,#FE,#F7,#F9,#FB,#FF,#FF,#FF,#FA
        defb #E2,#FB,#FF,#FF,#FF,#FA,#C4,#74,#FF,#FF,#FE,#D5,#88,#33,#F1,#FF
        defb #F1,#88,#00,#00,#FE,#F0,#EE,#00,#00,#00,#11,#FF,#00,#00,#00
sprite_ghost1_4804:
        ; Sprite "ghost1" (6x20 octets/ligne, 120 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 50.
        defb #06,#14,#00,#00,#00,#11,#EE,#00,#00,#00,#00,#23,#1F,#00,#00,#00
        defb #11,#CF,#0F,#88,#00,#00,#23,#0F,#0F,#88,#00,#00,#23,#0F,#1F,#EE
        defb #66,#77,#CF,#0F,#0F,#9F,#9F,#8F,#0F,#0F,#0F,#0F,#1F,#8F,#0F,#0F
        defb #0F,#0F,#1F,#47,#0F,#0F,#0F,#0F,#2E,#23,#0F,#0F,#0F,#0F,#2E,#11
        defb #0F,#1F,#8F,#0F,#4C,#00,#8F,#FF,#4F,#0F,#88,#00,#9F,#6F,#4F,#0F
        defb #88,#00,#57,#3F,#8F,#1F,#00,#00,#47,#CF,#0F,#1F,#00,#00,#23,#0F
        defb #0F,#2E,#00,#00,#23,#0F,#0F,#4C,#00,#00,#11,#0F,#0F,#88,#00,#00
        defb #00,#CF,#3F,#00,#00,#00,#00,#33,#CC,#00,#00
sprite_ghost3_487F:
        ; Sprite "ghost3" (6x19 octets/ligne, 114 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 51.
        defb #06,#13,#00,#00,#00,#11,#CC,#00,#00,#00,#00,#23,#2E,#00,#00,#00
        defb #77,#23,#1F,#33,#88,#00,#8F,#CF,#0F,#CF,#4C,#11,#0F,#0F,#0F,#0F
        defb #4C,#00,#8F,#0F,#0F,#0F,#6E,#77,#8F,#0F,#0F,#0F,#1F,#8F,#0F,#0F
        defb #0F,#0F,#1F,#8F,#0F,#0F,#0F,#0F,#1F,#47,#0F,#0F,#0F,#0F,#2E,#23
        defb #0F,#1F,#8F,#0F,#4C,#11,#0F,#FF,#4F,#0F,#4C,#00,#9F,#6F,#4F,#0F
        defb #88,#00,#9F,#3F,#8F,#0F,#88,#00,#8F,#CF,#0F,#0F,#88,#00,#47,#0F
        defb #0F,#1F,#00,#00,#23,#0F,#0F,#6E,#00,#00,#11,#CF,#3F,#88,#00,#00
        defb #00,#33,#CC,#00,#00
sprite_ghost4_48F4:
        ; Sprite "ghost4" (6x20 octets/ligne, 120 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 52.
        defb #06,#14,#00,#00,#00,#00,#66,#00,#00,#00,#33,#11,#9F,#00,#00,#00
        defb #47,#EF,#0F,#FF,#00,#00,#8F,#0F,#0F,#0F,#88,#33,#0F,#0F,#0F,#0F
        defb #88,#47,#0F,#0F,#0F,#0F,#CC,#8F,#0F,#0F,#0F,#0F,#2E,#8F,#0F,#0F
        defb #0F,#0F,#1F,#47,#0F,#0F,#0F,#0F,#1F,#23,#0F,#0F,#0F,#0F,#2E,#11
        defb #0F,#0F,#0F,#0F,#4C,#00,#8F,#0F,#0F,#9F,#4C,#00,#8F,#0F,#0F,#AF
        defb #88,#00,#47,#0F,#0F,#DF,#00,#00,#47,#0F,#0F,#DF,#00,#00,#23,#0F
        defb #0F,#2E,#00,#00,#23,#0F,#0F,#4C,#00,#00,#11,#0F,#0F,#88,#00,#00
        defb #00,#CF,#3F,#00,#00,#00,#00,#33,#CC,#00,#00
sprite_ghost2_496F:
        ; Sprite "ghost2" (6x20 octets/ligne, 120 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 53.
        defb #06,#14,#00,#00,#00,#11,#EE,#00,#00,#00,#00,#23,#1F,#00,#00,#11
        defb #EE,#47,#0F,#FF,#00,#23,#1F,#47,#0F,#CF,#88,#11,#0F,#CF,#0F,#0F
        defb #4C,#33,#0F,#0F,#0F,#0F,#4C,#47,#0F,#0F,#0F,#0F,#2E,#8F,#0F,#0F
        defb #0F,#0F,#1F,#47,#0F,#0F,#0F,#0F,#1F,#23,#0F,#0F,#0F,#0F,#2E,#11
        defb #0F,#0F,#0F,#0F,#4C,#00,#8F,#0F,#0F,#6F,#4C,#00,#8F,#0F,#0F,#AF
        defb #88,#00,#47,#0F,#0F,#DF,#00,#00,#47,#0F,#0F,#DF,#00,#00,#23,#0F
        defb #0F,#2E,#00,#00,#23,#0F,#0F,#4C,#00,#00,#11,#0F,#0F,#88,#00,#00
        defb #00,#CF,#3F,#00,#00,#00,#00,#33,#CC,#00,#00
sprite_melkhior_up2_49EA:
        ; Sprite "melkhior_up2" (6x39 octets/ligne, 234 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 9F.
        defb #06,#27,#00,#00,#00,#88,#00,#00,#00,#00,#11,#4C,#00,#00,#00,#00
        defb #23,#4C,#00,#00,#44,#00,#57,#4C,#00,#00,#AE,#00,#9F,#4C,#00,#00
        defb #AE,#00,#9F,#4C,#00,#11,#5F,#11,#1F,#BF,#FF,#11,#5F,#11,#3F,#AF
        defb #0F,#AB,#5F,#11,#3F,#AF,#0F,#6F,#DF,#11,#3F,#AF,#0F,#4F,#DF,#23
        defb #1F,#AF,#0F,#4F,#DF,#23,#1F,#4F,#2F,#4F,#DF,#23,#0F,#8F,#5F,#4F
        defb #DF,#23,#1F,#0F,#DF,#4F,#DF,#23,#1F,#1F,#5F,#4F,#2E,#23,#1F,#3F
        defb #5F,#0F,#4C,#11,#0F,#5F,#0F,#8F,#88,#11,#0F,#5F,#0F,#9F,#00,#00
        defb #8F,#4F,#0F,#9F,#00,#00,#47,#4F,#0F,#EE,#00,#00,#23,#8F,#0F,#EA
        defb #00,#00,#75,#9F,#BF,#7D,#00,#00,#75,#BF,#FF,#FD,#00,#00,#75,#EF
        defb #4F,#FD,#00,#00,#74,#DF,#FF,#7D,#00,#00,#74,#F3,#FF,#EA,#00,#00
        defb #74,#F0,#F0,#C4,#00,#00,#74,#F0,#F0,#88,#00,#00,#74,#F7,#F0,#88
        defb #00,#00,#74,#FE,#F9,#00,#00,#00,#74,#FC,#E2,#00,#00,#00,#32,#F8
        defb #C4,#00,#00,#00,#32,#F8,#88,#00,#00,#00,#32,#F0,#88,#00,#00,#00
        defb #32,#F1,#00,#00,#00,#00,#32,#E2,#00,#00,#00,#00,#32,#C4,#00,#00
        defb #00,#00,#32,#88,#00,#00,#00,#00,#11,#00,#00,#00,#00
sprite_melkhior_up1_4AD7:
        ; Sprite "melkhior_up1" (6x33 octets/ligne, 198 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 9E.
        defb #06,#21,#00,#22,#00,#00,#00,#00,#00,#57,#00,#00,#00,#00,#00,#47
        defb #88,#00,#00,#00,#00,#47,#4C,#77,#FF,#11,#00,#47,#2E,#8F,#0F,#AB
        defb #88,#47,#1F,#0F,#0F,#4F,#88,#8F,#0F,#8F,#0F,#4F,#4C,#8F,#0F,#4F
        defb #0F,#4F,#4C,#8F,#0F,#2F,#0F,#4F,#2E,#8F,#0F,#2F,#0F,#8F,#2E,#8F
        defb #0F,#1F,#0F,#8F,#2E,#8F,#0F,#0F,#0F,#0F,#2E,#8F,#0F,#0F,#0F,#0F
        defb #4C,#77,#8F,#0F,#0F,#0F,#88,#00,#67,#0F,#0F,#1F,#00,#00,#11,#8F
        defb #3F,#EE,#00,#00,#00,#CF,#FC,#F1,#00,#00,#11,#3F,#F0,#F0,#88,#00
        defb #11,#3E,#F0,#F0,#88,#00,#00,#FC,#F1,#F8,#88,#00,#00,#74,#F3,#F0
        defb #88,#00,#00,#F8,#F6,#F0,#C4,#00,#00,#F8,#F6,#F0,#C4,#00,#00,#F8
        defb #F7,#F0,#C4,#00,#00,#F8,#F7,#F0,#C4,#00,#00,#74,#F3,#F8,#E2,#00
        defb #00,#33,#F0,#F0,#E2,#00,#00,#00,#FC,#F0,#E2,#00,#00,#00,#33,#F0
        defb #E2,#00,#00,#00,#00,#FC,#F1,#00,#00,#00,#00,#33,#F1,#00,#00,#00
        defb #00,#00,#FD,#00,#00,#00,#00,#00,#22
sprite_knight_up1_4BA0:
        ; Sprite "knight_up1" (6x23 octets/ligne, 138 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 1E,96.
        defb #06,#17,#00,#00,#11,#88,#00,#00,#00,#00,#23,#7F,#FF,#00,#00,#00
        defb #47,#4F,#0F,#EE,#00,#00,#CF,#8F,#0F,#1F,#00,#11,#4F,#8F,#0F,#0F
        defb #88,#11,#4F,#4F,#0F,#0F,#88,#00,#AF,#4F,#0F,#1F,#00,#00,#AF,#7F
        defb #EF,#1F,#00,#00,#77,#F8,#F1,#AE,#00,#00,#FE,#F0,#F0,#C4,#00,#11
        defb #3E,#F3,#FD,#EA,#00,#11,#3E,#F4,#F3,#F9,#00,#11,#3E,#F4,#F1,#FD
        defb #00,#00,#BE,#F4,#F1,#FB,#00,#00,#74,#F4,#F3,#F1,#00,#00,#F8,#F8
        defb #F3,#E2,#00,#00,#F9,#F0,#F3,#E2,#00,#00,#76,#F0,#F2,#C4,#00,#00
        defb #32,#F0,#F6,#C4,#00,#00,#11,#F0,#F4,#88,#00,#00,#00,#F8,#F9,#00
        defb #00,#00,#00,#74,#E6,#00,#00,#00,#00,#33,#88,#00,#00
sprite_knight_up2_4C2D:
        ; Sprite "knight_up2" (6x23 octets/ligne, 138 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 1F,97.
        defb #06,#17,#00,#00,#33,#77,#FF,#00,#00,#00,#47,#CF,#0F,#EE,#00,#00
        defb #8F,#8F,#0F,#1F,#00,#00,#CF,#8F,#0F,#0F,#88,#11,#4F,#8F,#0F,#0F
        defb #88,#11,#4F,#8F,#0F,#1F,#00,#00,#AF,#FF,#EF,#1F,#00,#00,#9F,#F9
        defb #FF,#DF,#00,#00,#BE,#F0,#FF,#FF,#00,#00,#74,#F4,#FF,#3F,#88,#00
        defb #74,#FC,#DF,#3F,#C4,#00,#F9,#F4,#C7,#DF,#C4,#00,#FA,#FA,#F3,#9F
        defb #C4,#00,#74,#FD,#F0,#F6,#88,#00,#74,#FC,#FC,#F0,#88,#00,#74,#FC
        defb #F3,#F9,#00,#00,#32,#F4,#F0,#F5,#00,#00,#32,#F6,#F0,#E2,#00,#00
        defb #11,#F2,#F0,#E2,#00,#00,#00,#F9,#F0,#C4,#00,#00,#00,#74,#F8,#88
        defb #00,#00,#00,#32,#F3,#00,#00,#00,#00,#11,#CC,#00,#00
sprite_transform1_4CBA:
        ; Sprite "transform1" (6x32 octets/ligne, 192 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 5C.
        defb #06,#20,#00,#00,#00,#00,#00,#00,#22,#44,#00,#00,#00,#00,#DF,#BF
        defb #00,#00,#00,#33,#1F,#8F,#CC,#00,#00,#CF,#1F,#8F,#3F,#00,#11,#0F
        defb #6E,#47,#0F,#88,#11,#1F,#88,#33,#0F,#88,#11,#9F,#00,#00,#9F,#E6
        defb #76,#8F,#88,#11,#1F,#F1,#F8,#CF,#88,#11,#3E,#F0,#F0,#E7,#4C,#23
        defb #3E,#F0,#F0,#C7,#4C,#23,#7C,#F0,#F0,#E3,#4C,#23,#7C,#F0,#F0,#F3
        defb #88,#11,#FC,#FF,#FF,#E2,#00,#11,#3F,#8F,#0F,#CC,#00,#11,#1F,#8F
        defb #0F,#4C,#66,#23,#2F,#4F,#0F,#4C,#9F,#23,#2F,#0F,#0F,#4C,#9F,#47
        defb #6F,#0F,#0F,#2E,#9F,#47,#AB,#3F,#CF,#1F,#1F,#8F,#AB,#CF,#3F,#1F
        defb #2E,#9F,#33,#0F,#0F,#DF,#2E,#66,#47,#0F,#0F,#2F,#2E,#00,#8F,#7F
        defb #EF,#1F,#2E,#11,#1F,#8F,#1F,#8F,#CC,#11,#2F,#4F,#2F,#4F,#88,#11
        defb #2F,#4F,#2F,#4F,#88,#00,#AF,#4F,#2F,#5F,#00,#00,#57,#2F,#4F,#AE
        defb #00,#00,#22,#AF,#5F,#44,#00,#00,#00,#57,#AE,#00,#00,#00,#00,#33
        defb #CC,#00,#00
sprite_transform2_4D7D:
        ; Sprite "transform2" (6x33 octets/ligne, 198 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 5D.
        defb #06,#21,#00,#00,#00,#00,#77,#FF,#00,#11,#88,#00,#8F,#0F,#88,#23
        defb #4C,#00,#CF,#0F,#88,#23,#2E,#77,#FF,#CF,#4C,#11,#1F,#8F,#5D,#CF
        defb #4C,#11,#1F,#0F,#FE,#FF,#2E,#00,#8F,#3F,#F0,#F8,#EE,#33,#47,#FC
        defb #F0,#F8,#F1,#47,#BB,#32,#F0,#F0,#F1,#8F,#4C,#32,#F0,#F0,#E2,#AF
        defb #2E,#11,#F0,#F0,#D7,#55,#1F,#AB,#FC,#F0,#AE,#11,#2F,#6F,#3F,#F1
        defb #4C,#11,#4F,#2F,#0F,#FD,#2E,#00,#8F,#0F,#0F,#3F,#2E,#00,#8F,#0F
        defb #0F,#1F,#9F,#00,#47,#0F,#0F,#3F,#9F,#00,#23,#7F,#0F,#4F,#9F,#00
        defb #33,#FF,#EF,#0F,#9F,#00,#47,#CF,#FF,#8F,#5F,#00,#BF,#8F,#3F,#CF
        defb #6E,#00,#BF,#DF,#0F,#BF,#88,#00,#BF,#FF,#CF,#DF,#00,#00,#BF,#FF
        defb #7F,#DF,#00,#00,#BF,#CF,#CF,#EF,#88,#00,#57,#CF,#8F,#EF,#88,#00
        defb #47,#FF,#8F,#EF,#88,#00,#57,#7F,#FF,#EF,#88,#00,#47,#9F,#FF,#EF
        defb #88,#00,#23,#6F,#1F,#9F,#00,#00,#11,#1F,#AF,#6E,#00,#00,#00,#0F
        defb #7F,#88,#00,#00,#00,#77,#88,#00,#00
sprite_transform3_4E46:
        ; Sprite "transform3" (6x38 octets/ligne, 228 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 5E.
        defb #06,#26,#00,#00,#00,#00,#77,#EE,#00,#00,#77,#AA,#8F,#1F,#00,#00
        defb #9F,#5F,#47,#EE,#00,#11,#0F,#DF,#47,#4C,#00,#11,#4F,#CF,#23,#3F
        defb #00,#00,#8F,#6F,#11,#0F,#88,#00,#8F,#2F,#00,#8F,#88,#11,#0F,#0F
        defb #11,#5F,#00,#11,#4F,#9F,#6F,#3F,#00,#00,#9F,#8F,#2F,#0F,#88,#00
        defb #8F,#0F,#2F,#0F,#88,#00,#8F,#0F,#4F,#1F,#00,#00,#8F,#0F,#8F,#2E
        defb #00,#11,#0F,#0F,#8F,#4C,#00,#11,#3F,#9F,#0F,#2E,#00,#00,#CF,#8F
        defb #0F,#1F,#00,#11,#0F,#AF,#0F,#1F,#00,#23,#8F,#AF,#0F,#0F,#88,#23
        defb #47,#EF,#0F,#3F,#00,#23,#5F,#23,#1F,#FC,#88,#23,#6E,#11,#FE,#F0
        defb #C4,#23,#4C,#11,#F0,#F0,#C4,#23,#4C,#32,#F0,#F0,#E2,#11,#88,#32
        defb #F2,#F0,#F1,#00,#33,#74,#F2,#F0,#F1,#00,#CF,#FC,#F1,#F0,#E6,#33
        defb #0F,#FE,#F1,#F3,#88,#47,#0F,#5F,#F9,#CF,#88,#8F,#1F,#0F,#7F,#8F
        defb #88,#8F,#7F,#0F,#FF,#0F,#88,#77,#88,#FF,#EF,#1F,#00,#00,#00,#33
        defb #2F,#2E,#00,#00,#00,#23,#3F,#CC,#00,#00,#00,#23,#4C,#00,#00,#00
        defb #00,#47,#4C,#00,#00,#00,#00,#47,#88,#00,#00,#00,#00,#47,#88,#00
        defb #00,#00,#00,#33,#00,#00,#00
sprite_transform4_4F2D:
        ; Sprite "transform4" (6x35 octets/ligne, 210 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 5F.
        defb #06,#23,#00,#00,#33,#00,#00,#CC,#00,#00,#CF,#88,#11,#3F,#00,#33
        defb #0F,#4C,#11,#0F,#CC,#47,#0F,#88,#00,#8F,#2E,#8F,#3F,#00,#00,#67
        defb #1F,#8F,#CC,#00,#00,#33,#1F,#47,#3F,#00,#00,#CF,#1F,#23,#0F,#BB
        defb #33,#0F,#6E,#11,#0F,#FC,#FC,#DF,#88,#00,#DF,#F0,#F8,#F3,#00,#00
        defb #32,#F0,#F8,#F0,#88,#00,#74,#F0,#F0,#F0,#88,#00,#74,#F0,#F0,#F1
        defb #00,#00,#32,#F0,#F0,#E2,#00,#00,#11,#FF,#F0,#C4,#00,#00,#11,#0F
        defb #FF,#88,#00,#00,#11,#0F,#0F,#88,#00,#00,#23,#0F,#0F,#88,#00,#00
        defb #23,#0F,#0F,#88,#00,#00,#67,#0F,#0F,#88,#00,#00,#8F,#0F,#0F,#4C
        defb #00,#11,#0F,#3F,#8F,#3F,#00,#23,#8F,#4F,#4F,#0F,#88,#57,#CF,#CF
        defb #2F,#1F,#00,#AF,#7F,#0F,#1F,#2F,#88,#AF,#0F,#0F,#1F,#AF,#4C,#BF
        defb #8F,#8F,#1F,#47,#2E,#9F,#FF,#0F,#1F,#33,#2E,#9F,#4F,#0F,#1F,#99
        defb #2E,#77,#0F,#4F,#3F,#5D,#2E,#23,#0F,#CF,#1F,#5D,#2E,#23,#8F,#1F
        defb #1F,#2E,#CC,#11,#3F,#EE,#9F,#1F,#00,#00,#CC,#00,#57,#EE,#00,#00
        defb #00,#00,#22,#00,#00
sprite_poltergeist6_5002:
        ; Sprite "poltergeist6" (6x20 octets/ligne, 120 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 77,78.
        defb #06,#14,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00
        defb #88,#00,#00,#00,#00,#11,#C4,#00,#00,#00,#00,#00,#88,#00,#00,#00
        defb #00,#00,#00,#00,#00,#22,#00,#00,#00,#00,#00,#75,#00,#00,#00,#00
        defb #00,#22,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#11
        defb #00,#00,#00,#00,#00,#32,#88,#00,#00,#88,#00,#11,#00,#11,#11,#C4
        defb #00,#00,#00,#32,#88,#88,#00,#00,#00,#74,#C4,#00,#00,#00,#00,#32
        defb #88,#00,#00,#00,#00,#11,#00,#00,#00,#00,#11,#00,#00,#00,#00,#00
        defb #32,#88,#00,#00,#00,#00,#11,#00,#00,#00,#00
sprite_poltergeist4_507D:
        ; Sprite "poltergeist4" (6x21 octets/ligne, 126 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 76,79.
        defb #06,#15,#00,#00,#00,#00,#00,#00,#00,#00,#88,#00,#00,#00,#00,#11
        defb #C4,#00,#00,#00,#00,#32,#E2,#00,#00,#00,#00,#11,#C4,#00,#88,#22
        defb #00,#00,#88,#11,#C4,#75,#00,#00,#00,#32,#E2,#F8,#88,#00,#11,#11
        defb #C4,#75,#00,#00,#32,#88,#88,#22,#00,#11,#11,#00,#00,#00,#00,#32
        defb #88,#00,#00,#88,#00,#74,#C4,#11,#11,#C4,#00,#32,#88,#32,#BA,#E2
        defb #00,#11,#00,#74,#D5,#C4,#00,#00,#00,#F8,#E2,#88,#00,#00,#00,#74
        defb #C4,#00,#00,#00,#11,#32,#88,#00,#00,#00,#32,#99,#00,#00,#00,#00
        defb #74,#C4,#00,#00,#00,#00,#32,#88,#00,#00,#00,#00,#11,#00,#00,#00
        defb #00
sprite_poltergeist1_50FE:
        ; Sprite "poltergeist1" (6x23 octets/ligne, 138 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 75,7A.
        defb #06,#17,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00
        defb #88,#00,#00,#00,#00,#11,#C4,#00,#88,#00,#00,#00,#88,#11,#C4,#00
        defb #00,#00,#00,#32,#E2,#22,#00,#00,#11,#74,#F1,#75,#00,#00,#32,#BA
        defb #E2,#22,#00,#11,#74,#D5,#C4,#00,#00,#32,#BA,#88,#88,#88,#00,#74
        defb #D5,#11,#11,#C4,#00,#F8,#E2,#32,#BA,#E2,#00,#74,#C4,#74,#F4,#F1
        defb #00,#32,#88,#F8,#F2,#E2,#00,#11,#11,#F0,#F1,#C4,#00,#00,#00,#F8
        defb #E2,#88,#00,#00,#00,#74,#C4,#00,#00,#00,#11,#32,#88,#00,#00,#00
        defb #32,#99,#00,#00,#00,#00,#11,#00,#00,#00,#00,#00,#00,#00,#00,#88
        defb #00,#00,#00,#00,#11,#C4,#00,#00,#00,#00,#00,#88,#00
sprite_poltergeist2_518B:
        ; Sprite "poltergeist2" (6x24 octets/ligne, 144 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 74,7B,85,A2,A6.
        defb #06,#18,#00,#00,#00,#00,#00,#00,#00,#00,#88,#00,#00,#00,#00,#11
        defb #C4,#00,#88,#00,#00,#32,#E2,#11,#C4,#00,#00,#11,#C4,#32,#E2,#22
        defb #00,#00,#99,#74,#F1,#75,#00,#00,#32,#F8,#F0,#F8,#88,#11,#74,#F4
        defb #F1,#75,#00,#32,#F8,#F2,#E2,#22,#00,#74,#F4,#D5,#C4,#00,#00,#F8
        defb #F2,#88,#88,#88,#00,#F0,#F1,#00,#11,#C4,#00,#F8,#E2,#11,#32,#E2
        defb #00,#74,#C4,#32,#99,#C4,#88,#32,#88,#74,#C4,#99,#C4,#11,#00,#32
        defb #88,#00,#88,#00,#11,#11,#00,#00,#00,#00,#32,#88,#00,#00,#00,#00
        defb #74,#C4,#00,#00,#00,#00,#32,#88,#00,#88,#00,#00,#11,#00,#99,#C4
        defb #00,#00,#00,#11,#F6,#E2,#00,#00,#00,#00,#99,#C4,#00,#00,#00,#00
        defb #00,#88,#00
sprite_poltergeist5_521E:
        ; Sprite "poltergeist5" (6x24 octets/ligne, 144 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch :
        ; 71,73,7C,7E,84,A1,A3,A5,A7,B9.
        defb #06,#18,#00,#00,#88,#75,#00,#00,#00,#11,#C4,#F8,#88,#00,#88,#32
        defb #F3,#F0,#C4,#33,#C4,#74,#F9,#F8,#88,#75,#88,#32,#E2,#75,#88,#F8
        defb #88,#11,#C4,#33,#D5,#F0,#C4,#00,#88,#32,#F2,#F0,#E2,#00,#11,#11
        defb #D5,#F0,#C4,#11,#32,#CC,#88,#F8,#88,#32,#99,#EA,#00,#75,#00,#74
        defb #C4,#55,#00,#22,#00,#F8,#E2,#32,#88,#88,#00,#74,#F5,#74,#D5,#C4
        defb #88,#32,#AA,#F8,#E2,#99,#C4,#11,#11,#F0,#F1,#32,#E2,#00,#11,#F8
        defb #F3,#11,#C4,#00,#32,#FC,#F6,#88,#88,#00,#74,#F6,#99,#00,#00,#00
        defb #F8,#F3,#00,#88,#00,#00,#74,#C4,#11,#C4,#00,#00,#32,#88,#BA,#E2
        defb #00,#00,#11,#11,#F4,#F1,#00,#00,#00,#00,#BA,#E2,#00,#00,#00,#00
        defb #11,#C4,#00
sprite_poltergeist3_52B1:
        ; Sprite "poltergeist3" (6x24 octets/ligne, 144 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch :
        ; 6F,70,72,7D,7F,83,A0,A4,B8,BB.
        defb #06,#18,#00,#11,#C4,#00,#00,#00,#88,#32,#E2,#22,#00,#11,#C4,#74
        defb #F1,#75,#88,#32,#E2,#F8,#F0,#BB,#C4,#11,#C4,#74,#F1,#32,#E2,#22
        defb #88,#32,#F3,#74,#F1,#75,#00,#11,#F6,#F8,#F0,#F8,#88,#00,#FC,#F4
        defb #F1,#75,#00,#00,#F8,#F2,#E2,#AA,#00,#00,#74,#D5,#D5,#C4,#00,#11
        defb #32,#88,#BA,#E2,#00,#32,#BB,#00,#74,#F1,#88,#11,#75,#11,#32,#F3
        defb #C4,#00,#F8,#BA,#99,#F6,#E2,#00,#75,#74,#D5,#FC,#F1,#00,#32,#BA
        defb #BA,#BA,#E2,#00,#74,#D5,#74,#D5,#C4,#00,#F8,#E2,#32,#88,#88,#11
        defb #F0,#F1,#99,#00,#00,#00,#F8,#F3,#C4,#88,#00,#00,#74,#F6,#F3,#C4
        defb #00,#00,#32,#FC,#F0,#E2,#00,#00,#11,#32,#F3,#C4,#00,#00,#00,#11
        defb #C4,#88,#00
sprite_cauldron_down_5344:
        ; Sprite "cauldron_down" (8x33 octets/ligne, 264 octets de bitmap).
        ; Type(s) d'entite associe(s) via tbl_sprite_dispatch : 8D.
        defb #08,#21,#00,#00,#11,#CC,#00,#00,#00,#00,#00,#00,#32,#E2,#11,#CC
        defb #00,#00,#00,#00,#74,#F1,#32,#E2,#77,#00,#00,#00,#74,#F1,#FC,#E2
        defb #F8,#99,#88,#00,#32,#F2,#FC,#F3,#F0,#F6,#C4,#33,#BA,#FE,#F8,#FA
        defb #F0,#F4,#E2,#74,#F7,#F6,#F7,#F5,#F8,#F8,#E2,#F8,#F3,#FA,#FE,#BF
        defb #FD,#F4,#E6,#F8,#F1,#FF,#FF,#FF,#FA,#F9,#FD,#74,#F7,#8F,#0F,#0F
        defb #1F,#FF,#F1,#75,#CF,#0F,#0F,#0F,#0F,#3F,#F1,#33,#0F,#0F,#0F,#0F
        defb #0F,#0F,#F9,#23,#0F,#EF,#0F,#0F,#0F,#0F,#6E,#47,#1F,#EF,#0F,#0F
        defb #0F,#0F,#2E,#47,#3F,#CF,#0F,#0F,#0F,#0F,#2E,#8F,#3F,#8F,#0F,#0F
        defb #0F,#0F,#1F,#8F,#7F,#8F,#0F,#0F,#0F,#0F,#1F,#8F,#7F,#0F,#0F,#0F
        defb #0F,#0F,#1F,#8F,#7F,#0F,#0F,#0F,#0F,#0F,#1F,#47,#7F,#0F,#0F,#1F
        defb #FF,#CF,#2E,#47,#7F,#8F,#0F,#EF,#0F,#3F,#2E,#23,#3F,#8F,#3F,#0F
        defb #0F,#0F,#CC,#23,#1F,#8F,#4F,#0F,#0F,#0F,#2E,#11,#0F,#0F,#8F,#0F
        defb #0F,#0F,#AE,#00,#8F,#1F,#0F,#0F,#0F,#1F,#57,#00,#47,#2F,#0F,#0F
        defb #0F,#2E,#57,#00,#47,#6F,#0F,#0F,#0F,#2E,#57,#00,#47,#6F,#0F,#0F
        defb #0F,#2E,#57,#00,#47,#0F,#00,#00,#0F,#2E,#AE,#00,#8F,#00,#00,#00
        defb #00,#1F,#AE,#11,#0C,#00,#00,#00,#00,#03,#4C,#11,#08,#00,#00,#00
        defb #00,#01,#88,#11,#00,#00,#00,#00,#00,#00,#88
sprite_cauldron_up_544F:
        ; Sprite "cauldron_up" (8x11 octets/ligne, 88 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 8E.
        defb #08,#0B,#00,#00,#00,#00,#FF,#FF,#00,#00,#00,#00,#00,#FF,#AF,#AF
        defb #FF,#00,#00,#00,#33,#9F,#3F,#DF,#EF,#CC,#00,#00,#57,#6F,#DF,#6F
        defb #EF,#6E,#00,#00,#8F,#0F,#2F,#AF,#EF,#9F,#00,#11,#2F,#CF,#AF,#1F
        defb #FF,#0F,#88,#00,#9F,#0F,#4F,#8F,#7F,#9F,#00,#00,#47,#2F,#2F,#0F
        defb #7F,#2E,#00,#00,#33,#0F,#0F,#0F,#0F,#CC,#00,#00,#00,#FF,#0F,#0F
        defb #FF,#00,#00,#00,#00,#00,#FF,#FF,#00,#00,#00
sprite_chest_54AA:
        ; Sprite "chest" (8x29 octets/ligne, 232 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 55.
        defb #08,#1D,#00,#00,#00,#00,#00,#33,#88,#00,#00,#00,#00,#00,#00,#CF
        defb #6E,#00,#00,#00,#00,#00,#33,#2D,#5B,#88,#00,#00,#00,#00,#CF,#A5
        defb #87,#6E,#00,#00,#00,#33,#0F,#78,#0F,#1F,#88,#00,#00,#CF,#C3,#2F
        defb #0F,#0F,#6E,#00,#33,#0F,#C3,#2F,#0F,#0F,#97,#00,#CF,#0F,#C3,#2F
        defb #0F,#0F,#5B,#33,#2D,#0F,#C3,#2F,#0F,#0F,#3D,#47,#69,#0F,#C3,#2F
        defb #0F,#0F,#1F,#AD,#69,#0F,#C3,#2F,#0F,#0F,#1F,#AD,#69,#4F,#C3,#2F
        defb #0F,#0F,#1F,#CB,#69,#6F,#C3,#FF,#8F,#0F,#1F,#8F,#69,#EF,#3F,#4F
        defb #6F,#0F,#1F,#8F,#69,#8F,#CF,#4F,#1F,#8F,#1F,#8F,#69,#3F,#0F,#2F
        defb #0F,#6F,#1F,#8F,#4B,#CF,#C3,#6F,#0F,#1F,#9F,#8F,#3F,#0F,#F1,#9F
        defb #0F,#0F,#5F,#8F,#CF,#0F,#6F,#3F,#8F,#0F,#1F,#BF,#2D,#1F,#F8,#CF
        defb #6F,#0F,#2E,#CF,#78,#6F,#3F,#8F,#1F,#CF,#CC,#47,#3D,#0F,#DE,#C3
        defb #0F,#3F,#00,#47,#7E,#F3,#0F,#F0,#0F,#CC,#00,#23,#9E,#CF,#0F,#3C
        defb #B7,#00,#00,#23,#3F,#E1,#0F,#0F,#CC,#00,#00,#11,#4F,#78,#87,#3F
        defb #00,#00,#00,#00,#8F,#1E,#C3,#CC,#00,#00,#00,#00,#67,#0F,#3F,#00
        defb #00,#00,#00,#00,#11,#FF,#CC,#00,#00,#00,#00
sprite_nail_mat_5595:
        ; Sprite "nail_mat" (8x28 octets/ligne, 224 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 17.
        defb #08,#1C,#00,#00,#00,#00,#11,#88,#00,#00,#00,#00,#00,#00,#67,#6E
        defb #00,#00,#00,#00,#00,#11,#8F,#1F,#88,#00,#00,#00,#00,#67,#1F,#8F
        defb #6E,#00,#00,#00,#11,#8F,#6F,#6F,#1F,#88,#00,#00,#67,#1F,#8F,#1F
        defb #8F,#6E,#00,#11,#8F,#6F,#3E,#C3,#6F,#1F,#88,#67,#1F,#8F,#3E,#C7
        defb #1F,#8F,#6E,#8F,#6F,#79,#3E,#D7,#E3,#6F,#1F,#9F,#8F,#F9,#3E,#D7
        defb #E3,#1F,#9F,#EF,#0F,#F9,#3E,#D7,#E3,#0F,#7F,#8F,#0F,#7D,#3E,#9F
        defb #C7,#0F,#1F,#BE,#E3,#7D,#3E,#9F,#C7,#7C,#D7,#76,#E3,#2F,#3E,#9F
        defb #C7,#7C,#E6,#11,#E3,#0F,#3E,#8F,#8F,#7C,#C4,#11,#E3,#F9,#1F,#0F
        defb #1F,#7C,#C4,#11,#E3,#F9,#0F,#0F,#F9,#7C,#88,#11,#D5,#F9,#3E,#C7
        defb #F9,#FC,#88,#11,#C4,#F9,#3E,#C7,#F9,#32,#88,#11,#C4,#F9,#BE,#D7
        defb #F9,#32,#88,#11,#C4,#EA,#76,#EA,#F9,#32,#88,#11,#C4,#EA,#32,#C4
        defb #75,#11,#00,#00,#88,#EA,#11,#C4,#75,#00,#00,#00,#00,#EA,#11,#C4
        defb #75,#00,#00,#00,#00,#44,#11,#C4,#22,#00,#00,#00,#00,#00,#11,#C4
        defb #00,#00,#00,#00,#00,#00,#11,#C4,#00,#00,#00,#00,#00,#00,#00,#88
        defb #00,#00,#00
sprite_wood_block_5678:
        ; Sprite "wood_block" (8x29 octets/ligne, 232 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 06.
        defb #08,#1D,#00,#00,#00,#33,#88,#77,#00,#00,#00,#00,#00,#47,#7F,#8F
        defb #CC,#00,#00,#00,#00,#FF,#BF,#1F,#66,#00,#00,#00,#11,#7F,#8F,#3F
        defb #1F,#00,#00,#00,#11,#1F,#8F,#3F,#1F,#88,#00,#00,#23,#BF,#8F,#3F
        defb #1F,#6E,#00,#00,#67,#9F,#9F,#EF,#5F,#9F,#88,#33,#9F,#9F,#9F,#EF
        defb #4F,#8F,#4C,#47,#3F,#CF,#DF,#CF,#2F,#CF,#2E,#67,#DF,#8F,#CF,#CF
        defb #3F,#CF,#2E,#9F,#DF,#1F,#8F,#EF,#3F,#CF,#DF,#9F,#DF,#9F,#2F,#EF
        defb #1F,#CF,#DF,#8F,#9F,#BF,#2F,#2F,#1F,#CF,#DF,#DF,#BF,#BF,#0F,#0F
        defb #1F,#9F,#9F,#9F,#3F,#8F,#0F,#0F,#1F,#9F,#9F,#9F,#3F,#0F,#0F,#0F
        defb #0F,#9F,#AE,#8F,#DF,#0F,#0F,#0F,#0F,#1F,#AE,#8F,#CF,#0F,#0F,#0F
        defb #0F,#0F,#AE,#8F,#0F,#0F,#0F,#0F,#0F,#0F,#5F,#47,#0F,#0F,#0F,#0F
        defb #0F,#0F,#1F,#47,#0F,#0F,#0F,#0F,#0F,#0F,#1F,#23,#0F,#0F,#0F,#0F
        defb #0F,#0F,#2E,#11,#0F,#0F,#0F,#0F,#0F,#0F,#2E,#00,#8F,#0F,#0F,#0F
        defb #0F,#0F,#4C,#00,#47,#8F,#0F,#0F,#0F,#1F,#88,#00,#33,#8F,#0F,#0F
        defb #0F,#EE,#00,#00,#00,#47,#8F,#0F,#1F,#00,#00,#00,#00,#33,#47,#3F
        defb #EE,#00,#00,#00,#00,#00,#33,#CC,#00,#00,#00
sprite_firebug1_5763:
        ; Sprite "firebug1" (4x15 octets/ligne, 60 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 56,B0,B4.
        defb #04,#0F,#00,#00,#33,#FF,#00,#00,#47,#C3,#88,#00,#CB,#0F,#4C,#11
        defb #87,#9E,#2E,#33,#97,#1E,#A6,#75,#6B,#CB,#E2,#75,#6B,#F9,#E2,#57
        defb #EB,#BD,#C4,#23,#EB,#F9,#C4,#23,#31,#7B,#AE,#11,#31,#7E,#CC,#11
        defb #F7,#7E,#88,#11,#D5,#DF,#00,#00,#BA,#DF,#00,#00,#11,#22,#00
sprite_firebug2_57A2:
        ; Sprite "firebug2" (4x16 octets/ligne, 64 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 57,B1,B5.
        defb #04,#10,#00,#00,#33,#CC,#00,#00,#47,#3F,#88,#00,#8F,#87,#4C,#00
        defb #AF,#4B,#2E,#11,#3F,#E3,#2E,#55,#3F,#E7,#2E,#FB,#5D,#D5,#6E,#EA
        defb #FB,#D5,#FB,#AE,#EA,#DF,#F9,#57,#F1,#17,#E2,#33,#F1,#17,#E2,#23
        defb #F9,#17,#EA,#23,#FD,#17,#EA,#23,#FD,#AE,#75,#11,#7E,#AE,#75,#00
        defb #99,#44,#22
sprite_hud_day_right_57E5:
        ; Sprite "hud_day_right" (8x31 octets/ligne, 248 octets de bitmap).
        ; Type(s) d'entite associe(s) via tbl_sprite_dispatch : 5A.
        defb #08,#1F,#00,#FF,#FF,#EF,#0F,#FF,#FF,#FF,#FF,#FF,#FF,#CF,#EF,#3F
        defb #FF,#FF,#FF,#FF,#FF,#DF,#0F,#0F,#FF,#FF,#FF,#FF,#FF,#CF,#8F,#0F
        defb #1F,#FF,#FF,#FF,#FF,#EF,#0F,#CF,#0F,#1F,#FF,#FF,#FF,#FF,#8F,#BB
        defb #0F,#0F,#0F,#FF,#FF,#FF,#8F,#88,#CF,#0F,#0F,#FF,#FF,#FF,#8F,#88
        defb #33,#CF,#0F,#FF,#FF,#FF,#8F,#88,#00,#33,#FF,#FF,#FF,#FF,#0F,#88
        defb #00,#00,#00,#FF,#FF,#EF,#2F,#88,#00,#00,#00,#FF,#FF,#CF,#0F,#88
        defb #00,#00,#00,#FF,#FF,#DF,#8F,#88,#00,#00,#00,#FF,#FF,#FF,#8F,#88
        defb #00,#00,#00,#FF,#FF,#DF,#8F,#88,#00,#00,#00,#FF,#FF,#CF,#0F,#88
        defb #00,#00,#00,#FF,#FF,#EF,#2F,#88,#00,#00,#00,#FF,#FF,#FF,#0F,#88
        defb #00,#00,#00,#FF,#FF,#FF,#8F,#88,#00,#00,#00,#FF,#FF,#FF,#8F,#88
        defb #00,#00,#00,#FF,#FF,#EF,#0F,#88,#00,#00,#00,#FF,#FF,#CF,#CF,#88
        defb #00,#00,#00,#FF,#FF,#DF,#0F,#88,#00,#00,#00,#FF,#FF,#CF,#8F,#CC
        defb #00,#00,#00,#00,#00,#01,#6F,#3F,#00,#00,#00,#00,#00,#00,#0F,#0F
        defb #EE,#00,#00,#00,#00,#00,#03,#0F,#1F,#EE,#00,#00,#00,#00,#00,#0F
        defb #0F,#1F,#FF,#00,#00,#00,#00,#01,#0F,#0F,#0F,#00,#00,#00,#00,#00
        defb #03,#0F,#0F,#00,#00,#00,#00,#00,#00,#03,#0F
sprite_hud_day_left_58E0:
        ; Sprite "hud_day_left" (8x31 octets/ligne, 248 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : BA.
        defb #08,#1F,#00,#FF,#FF,#FF,#FF,#0F,#7F,#FF,#FF,#FF,#FF,#FF,#CF,#7F
        defb #3F,#FF,#FF,#FF,#FF,#FF,#0F,#0F,#BF,#FF,#FF,#FF,#FF,#8F,#0F,#1F
        defb #3F,#FF,#FF,#FF,#8F,#0F,#3F,#0F,#7F,#FF,#FF,#0F,#0F,#0F,#DD,#1F
        defb #FF,#FF,#FF,#0F,#0F,#3F,#11,#1F,#FF,#FF,#FF,#0F,#3F,#CC,#11,#1F
        defb #FF,#FF,#FF,#FF,#CC,#00,#11,#1F,#FF,#FF,#FF,#00,#00,#00,#11,#0F
        defb #FF,#FF,#FF,#00,#00,#00,#11,#2F,#7F,#FF,#FF,#00,#00,#00,#11,#0F
        defb #3F,#FF,#FF,#00,#00,#00,#11,#1F,#BF,#FF,#FF,#00,#00,#00,#11,#1F
        defb #FF,#FF,#FF,#00,#00,#00,#11,#1F,#BF,#FF,#FF,#00,#00,#00,#11,#0F
        defb #3F,#FF,#FF,#00,#00,#00,#11,#2F,#7F,#FF,#FF,#00,#00,#00,#11,#0F
        defb #FF,#FF,#FF,#00,#00,#00,#11,#1F,#FF,#FF,#FF,#00,#00,#00,#11,#1F
        defb #FF,#FF,#FF,#00,#00,#00,#11,#0F,#7F,#FF,#FF,#00,#00,#00,#11,#3F
        defb #3F,#FF,#FF,#00,#00,#00,#11,#0F,#BF,#FF,#FF,#00,#00,#00,#33,#1F
        defb #3F,#FF,#FF,#00,#00,#00,#CF,#6F,#08,#00,#00,#00,#00,#77,#0F,#0F
        defb #00,#00,#00,#00,#77,#8F,#0F,#0C,#00,#00,#00,#FF,#8F,#0F,#0F,#00
        defb #00,#00,#00,#0F,#0F,#0F,#08,#00,#00,#00,#00,#0F,#0F,#0C,#00,#00
        defb #00,#00,#00,#0F,#0C,#00,#00,#00,#00,#00,#00
sprite_small_block_59DB:
        ; Sprite "small_block" (8x29 octets/ligne, 232 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch :
        ; 07,36,37,3E,5B,8F,BC,BD,BE,BF.
        defb #08,#1D,#00,#00,#00,#00,#11,#88,#00,#00,#00,#00,#00,#00,#76,#E6
        defb #00,#00,#00,#00,#00,#11,#BD,#F1,#88,#00,#00,#00,#00,#76,#5B,#F0
        defb #E6,#00,#00,#00,#11,#AD,#B5,#F0,#F1,#88,#00,#00,#76,#5A,#5B,#F0
        defb #F0,#E6,#00,#11,#AD,#A5,#B5,#F0,#F0,#F1,#88,#76,#5A,#5A,#5B,#F0
        defb #F0,#F0,#E6,#AD,#A5,#A5,#B5,#F0,#F0,#F0,#F1,#DA,#5A,#5A,#5B,#F0
        defb #F0,#F0,#F1,#AD,#A5,#A5,#B5,#F0,#F0,#F0,#F1,#DA,#5A,#5A,#5B,#F0
        defb #F0,#F0,#F1,#AD,#A5,#A5,#B5,#F8,#F0,#F0,#F1,#DA,#5A,#5A,#6F,#7E
        defb #F0,#F0,#F1,#AD,#A5,#B5,#8F,#1F,#F8,#F0,#F1,#DA,#5A,#6F,#0F,#0F
        defb #7E,#F0,#F1,#AD,#B5,#8F,#0F,#0F,#1F,#F8,#F1,#DA,#6F,#0F,#0F,#0F
        defb #0F,#7E,#F1,#BD,#8F,#0F,#0F,#0F,#0F,#1F,#F9,#EF,#0F,#0F,#0F,#0F
        defb #0F,#0F,#7F,#8F,#0F,#0F,#0F,#0F,#0F,#0F,#1F,#67,#0F,#0F,#0F,#0F
        defb #0F,#0F,#6E,#11,#8F,#0F,#0F,#0F,#0F,#1F,#88,#00,#67,#0F,#0F,#0F
        defb #0F,#6E,#00,#00,#11,#8F,#0F,#0F,#1F,#88,#00,#00,#00,#67,#0F,#0F
        defb #6E,#00,#00,#00,#00,#11,#8F,#1F,#88,#00,#00,#00,#00,#00,#67,#6E
        defb #00,#00,#00,#00,#00,#00,#11,#88,#00,#00,#00
sprite_door2_5AC6:
        ; Sprite "door2" (6x52 octets/ligne, 312 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 02.
        defb #06,#34,#00,#00,#11,#3F,#00,#00,#00,#00,#76,#8F,#88,#00,#00,#11
        defb #F8,#8F,#4C,#00,#00,#76,#F0,#8F,#4C,#00,#00,#F8,#F0,#8F,#4C,#00
        defb #00,#F8,#F0,#8F,#4C,#00,#00,#F8,#F0,#8F,#4C,#00,#00,#F8,#F1,#CF
        defb #4C,#00,#00,#F8,#F6,#BF,#4C,#00,#00,#F9,#F8,#8F,#CC,#00,#00,#FE
        defb #F0,#8F,#4C,#00,#00,#F8,#F0,#8F,#4C,#00,#00,#F8,#F0,#8F,#4C,#00
        defb #00,#F8,#F0,#8F,#4C,#00,#00,#F8,#F1,#8F,#4C,#00,#00,#F8,#F6,#CF
        defb #CC,#00,#00,#F9,#F8,#8F,#4C,#00,#00,#FE,#F0,#8F,#4C,#00,#00,#F8
        defb #F0,#8F,#4C,#00,#00,#F8,#F0,#8F,#4C,#00,#00,#F8,#F0,#8F,#4C,#00
        defb #00,#F8,#F0,#EF,#4C,#00,#00,#F8,#F3,#D7,#CC,#00,#00,#F8,#FC,#C7
        defb #2E,#00,#00,#77,#F0,#C7,#2E,#00,#00,#74,#F0,#C7,#2E,#00,#00,#74
        defb #F0,#C7,#1F,#00,#00,#74,#F0,#E3,#1F,#00,#00,#74,#F0,#F7,#FF,#00
        defb #00,#74,#F1,#EB,#0F,#88,#00,#32,#F6,#F1,#0F,#88,#00,#33,#F8,#F1
        defb #0F,#88,#00,#32,#F0,#F1,#0F,#4C,#00,#11,#F0,#F0,#8F,#4C,#00,#11
        defb #F0,#F0,#8F,#EE,#00,#11,#F0,#F0,#F7,#1F,#00,#00,#F8,#F0,#CF,#1F
        defb #00,#00,#F8,#F3,#E3,#0F,#88,#00,#74,#FC,#F1,#0F,#4C,#00,#77,#F0
        defb #F1,#0F,#AE,#00,#32,#F0,#F0,#9F,#2E,#00,#11,#F0,#F0,#E7,#1F,#00
        defb #11,#F0,#F1,#EB,#0F,#00,#00,#F8,#F6,#F1,#0F,#00,#00,#75,#F8,#F0
        defb #8F,#00,#00,#32,#F0,#F0,#C7,#00,#00,#11,#F0,#F0,#E3,#00,#00,#00
        defb #F8,#F0,#F7,#00,#00,#00,#74,#F1,#FC,#00,#00,#00,#32,#F7,#F3,#00
        defb #00,#00,#11,#FC,#CC,#00,#00,#00,#00,#33,#00
sprite_door1_5C01:
        ; Sprite "door1" (4x35 octets/ligne, 140 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 03.
        defb #04,#23,#00,#00,#00,#33,#CC,#00,#00,#FD,#6E,#00,#33,#F1,#1F,#00
        defb #FC,#F1,#1F,#11,#F0,#F1,#1F,#11,#F0,#F1,#1F,#11,#F0,#F1,#1F,#11
        defb #F0,#F1,#1F,#11,#F0,#F3,#DF,#11,#F0,#FD,#3F,#11,#F3,#F1,#1F,#11
        defb #FC,#F1,#1F,#11,#F0,#F1,#1F,#11,#F0,#F3,#DF,#11,#F0,#FD,#3F,#11
        defb #F3,#F1,#1F,#11,#FC,#F1,#1F,#11,#F0,#F1,#9F,#11,#F0,#EF,#7F,#11
        defb #F3,#E3,#1F,#11,#FC,#E3,#2E,#32,#F0,#C7,#2E,#32,#F0,#FF,#2E,#32
        defb #F3,#8F,#CC,#74,#FC,#8F,#4C,#77,#F1,#0F,#88,#F8,#F3,#0F,#88,#F8
        defb #CF,#9F,#00,#F3,#0F,#6E,#00,#CF,#8F,#4C,#00,#8F,#8F,#88,#00,#8F
        defb #5F,#00,#00,#8F,#6E,#00,#00,#9F,#88,#00,#00,#EE,#00,#00,#00
sprite_wall1_5C90:
        ; Sprite "wall1" (4x47 octets/ligne, 188 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 0D.
        defb #04,#2F,#00,#44,#00,#00,#00,#BF,#00,#00,#00,#8F,#CC,#00,#00,#8F
        defb #2E,#00,#00,#8F,#1F,#CC,#00,#8F,#1F,#3F,#00,#8F,#1F,#0F,#CC,#8F
        defb #1F,#0F,#3F,#47,#9F,#0F,#1F,#33,#77,#0F,#1F,#00,#9F,#CF,#1F,#00
        defb #8F,#7F,#1F,#00,#8F,#1F,#DF,#00,#47,#0F,#7F,#00,#47,#0F,#1F,#00
        defb #47,#0F,#0F,#00,#47,#0F,#0F,#00,#8F,#0F,#0F,#00,#8F,#0F,#0F,#00
        defb #8F,#0F,#0F,#66,#67,#0F,#0F,#9F,#99,#8F,#0F,#8F,#6E,#EF,#0F,#8F
        defb #1F,#9F,#8F,#8F,#1F,#0F,#7F,#67,#1F,#0F,#1F,#11,#9F,#0F,#1F,#00
        defb #77,#0F,#1F,#00,#11,#0F,#1F,#00,#00,#0F,#1F,#00,#66,#77,#1F,#00
        defb #9F,#47,#FF,#11,#1F,#CF,#3F,#11,#0F,#6F,#1F,#00,#8F,#1F,#9F,#00
        defb #67,#0F,#7F,#00,#57,#8F,#0F,#00,#47,#6F,#0F,#00,#47,#1F,#8F,#00
        defb #23,#0F,#6F,#00,#33,#0F,#1F,#00,#47,#CF,#0F,#00,#47,#3F,#0F,#00
        defb #47,#0F,#8F,#00,#33,#0F,#8F,#00,#00,#CF,#CF,#00,#00,#33,#BB
sprite_wall2_5D4F:
        ; Sprite "wall2" (4x48 octets/ligne, 192 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 0E.
        defb #04,#30,#00,#00,#00,#00,#22,#00,#00,#00,#DF,#00,#00,#11,#1F,#00
        defb #00,#FF,#1F,#00,#33,#2F,#1F,#00,#CF,#2F,#1F,#33,#0F,#2F,#1F,#CF
        defb #0F,#2F,#6E,#0F,#0F,#1F,#88,#0F,#0F,#2E,#00,#0F,#0F,#CC,#00,#0F
        defb #3F,#2E,#00,#0F,#CF,#2E,#CC,#3F,#0F,#7F,#2E,#CF,#0F,#CF,#2E,#8F
        defb #3F,#0F,#2E,#8F,#CF,#0F,#2E,#BF,#0F,#0F,#CC,#CF,#0F,#3F,#00,#8F
        defb #0F,#CC,#00,#8F,#3F,#4C,#00,#8F,#CF,#4C,#00,#BF,#0F,#4C,#00,#CF
        defb #0F,#88,#00,#8F,#3F,#00,#22,#0F,#4F,#88,#DF,#1F,#8F,#7F,#1F,#6F
        defb #0F,#4F,#1F,#8F,#0F,#4F,#2E,#0F,#0F,#4F,#CC,#0F,#0F,#7F,#00,#0F
        defb #0F,#CF,#88,#0F,#3F,#8F,#4C,#0F,#EF,#0F,#4C,#BF,#6F,#0F,#4C,#CF
        defb #2F,#0F,#88,#8F,#2F,#1F,#00,#8F,#2F,#7F,#00,#8F,#3F,#DF,#00,#8F
        defb #7F,#0F,#88,#8F,#CF,#0F,#88,#BF,#0F,#0F,#88,#CF,#0F,#0F,#00,#8F
        defb #0F,#1F,#00,#8F,#1F,#6E,#00,#8F,#6E,#88,#00,#9F,#88,#00,#00,#66
        defb #00,#00,#00
sprite_wall3_5E12:
        ; Sprite "wall3" (4x48 octets/ligne, 192 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 0F.
        defb #04,#30,#00,#CC,#00,#00,#00,#3F,#00,#00,#00,#0F,#CC,#00,#00,#0F
        defb #3F,#00,#00,#0F,#0F,#CC,#00,#0F,#0F,#3F,#00,#0F,#0F,#0F,#CC,#0F
        defb #0F,#0F,#2E,#CF,#0F,#0F,#1F,#3F,#0F,#0F,#1F,#1F,#CF,#0F,#1F,#1F
        defb #3F,#0F,#1F,#1F,#0F,#CF,#2E,#1F,#0F,#3F,#2E,#FF,#0F,#1F,#CC,#9F
        defb #8F,#1F,#00,#0F,#6F,#1F,#00,#0F,#1F,#9F,#00,#0F,#0F,#6E,#00,#0F
        defb #0F,#1F,#00,#0F,#0F,#0F,#88,#0F,#0F,#0F,#88,#0F,#0F,#0F,#88,#8F
        defb #0F,#0F,#88,#EF,#0F,#0F,#88,#9F,#8F,#0F,#88,#8F,#6F,#0F,#4C,#8F
        defb #1F,#8F,#2E,#8F,#0F,#EF,#2E,#EF,#0F,#99,#AE,#1F,#8F,#88,#44,#0F
        defb #6F,#88,#00,#0F,#1F,#00,#00,#0F,#0F,#EE,#00,#0F,#0F,#5F,#88,#0F
        defb #0F,#4F,#4C,#CF,#0F,#2F,#2E,#3F,#0F,#2F,#2E,#0F,#CF,#2F,#2E,#0F
        defb #3F,#2F,#1F,#0F,#0F,#EF,#1F,#0F,#0F,#99,#1F,#0F,#0F,#88,#DF,#0F
        defb #0F,#88,#22,#CF,#0F,#88,#00,#33,#0F,#88,#00,#00,#CF,#88,#00,#00
        defb #33,#00,#00
sprite_wall4_5ED5:
        ; Sprite "wall4" (10x25 octets/ligne, 250 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 0A.
        defb #0A,#19,#00,#00,#00,#CC,#00,#00,#00,#00,#00,#00,#00,#00,#11,#3F
        defb #11,#88,#00,#00,#00,#00,#00,#00,#11,#0F,#AB,#6E,#00,#00,#00,#00
        defb #00,#00,#11,#0F,#6F,#1F,#88,#00,#00,#00,#00,#00,#11,#0F,#6F,#0F
        defb #6E,#66,#00,#00,#00,#77,#11,#0F,#7F,#8F,#1F,#9F,#88,#00,#00,#8F
        defb #DD,#0F,#6F,#6F,#0F,#8F,#6E,#00,#00,#8F,#3F,#0F,#4F,#1F,#8F,#8F
        defb #1F,#88,#00,#8F,#0F,#CF,#4F,#0F,#6F,#8F,#0F,#6E,#00,#8F,#0F,#3F
        defb #4F,#0F,#1F,#8F,#0F,#1F,#88,#47,#0F,#0F,#CF,#0F,#0F,#6F,#0F,#0F
        defb #6E,#33,#0F,#0F,#3F,#0F,#0F,#3F,#8F,#0F,#1F,#00,#CF,#0F,#0F,#CF
        defb #0F,#1F,#6F,#0F,#1F,#00,#33,#0F,#0F,#7F,#0F,#1F,#1F,#8F,#1F,#00
        defb #00,#CF,#0F,#4C,#CF,#1F,#0F,#6F,#1F,#00,#00,#BF,#0F,#4C,#33,#1F
        defb #0F,#3F,#9F,#00,#00,#8F,#CF,#4C,#00,#DF,#0F,#2E,#66,#00,#00,#8F
        defb #3F,#4C,#00,#33,#0F,#2E,#00,#00,#00,#47,#0F,#CC,#00,#11,#0F,#2E
        defb #00,#00,#00,#33,#0F,#3F,#00,#11,#0F,#2E,#00,#00,#00,#00,#CF,#0F
        defb #88,#00,#8F,#2E,#00,#00,#00,#00,#33,#0F,#4C,#00,#67,#2E,#00,#00
        defb #00,#00,#00,#CF,#4C,#00,#11,#AE,#00,#00,#00,#00,#00,#33,#4C,#00
        defb #00,#44,#00,#00,#00,#00,#00,#00,#88,#00,#00,#00,#00
sprite_wall5_5FD2:
        ; Sprite "wall5" (6x24 octets/ligne, 144 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 0B.
        defb #06,#18,#00,#00,#11,#88,#00,#00,#00,#00,#23,#6E,#00,#00,#00,#00
        defb #23,#1F,#88,#00,#00,#00,#23,#0F,#6E,#00,#00,#00,#11,#0F,#1F,#88
        defb #00,#00,#00,#8F,#0F,#4C,#00,#00,#88,#8F,#0F,#6E,#00,#11,#6E,#47
        defb #0F,#5F,#88,#23,#1F,#CF,#0F,#4F,#4C,#23,#0F,#4F,#0F,#4F,#4C,#11
        defb #0F,#4F,#0F,#4F,#4C,#11,#0F,#6F,#0F,#4F,#4C,#77,#0F,#5F,#8F,#6F
        defb #4C,#9F,#8F,#4F,#6F,#5D,#88,#8F,#6F,#4F,#1F,#CC,#00,#8F,#1F,#CF
        defb #0F,#6E,#00,#47,#0F,#6F,#0F,#1F,#88,#33,#0F,#1F,#8F,#0F,#6E,#00
        defb #CF,#0F,#6F,#0F,#1F,#00,#33,#0F,#2F,#0F,#1F,#00,#00,#CF,#2F,#0F
        defb #1F,#00,#00,#33,#3F,#8F,#1F,#00,#00,#00,#CC,#67,#2E,#00,#00,#00
        defb #00,#11,#CC
sprite_wall6_6065:
        ; Sprite "wall6" (6x18 octets/ligne, 108 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 0C.
        defb #06,#12,#00,#44,#00,#00,#00,#00,#00,#BF,#00,#00,#00,#00,#00,#8F
        defb #CC,#00,#00,#00,#00,#8F,#3F,#00,#00,#00,#00,#8F,#0F,#CC,#33,#00
        defb #00,#8F,#0F,#3F,#47,#CC,#00,#47,#CF,#0F,#CF,#3F,#00,#23,#BF,#0F
        defb #4F,#0F,#CC,#11,#8F,#CF,#4F,#0F,#2E,#00,#8F,#3F,#4F,#0F,#1F,#00
        defb #8F,#0F,#CF,#0F,#1F,#00,#67,#0F,#3F,#0F,#1F,#00,#11,#8F,#0F,#CF
        defb #1F,#00,#00,#67,#0F,#3F,#1F,#00,#00,#11,#8F,#1F,#DF,#00,#00,#00
        defb #67,#1F,#22,#00,#00,#00,#11,#9F,#00,#00,#00,#00,#00,#66,#00
sprite_wood_wall_60D4:
        ; Sprite "wood_wall" (4x48 octets/ligne, 192 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 80.
        defb #04,#30,#00,#FF,#CC,#00,#00,#8F,#2E,#00,#00,#8F,#1F,#77,#00,#CF
        defb #2F,#8F,#88,#CF,#3F,#4F,#CC,#CF,#3F,#CF,#2E,#CF,#2F,#EF,#5F,#EF
        defb #2F,#EF,#4F,#EF,#2F,#EF,#7F,#EF,#2F,#CF,#7F,#EF,#2F,#CF,#3F,#EF
        defb #6F,#4F,#FF,#CF,#6F,#4F,#FF,#CF,#EF,#5F,#FF,#8F,#EF,#0F,#FF,#8F
        defb #FF,#0F,#FF,#8F,#FF,#0F,#FF,#8F,#7F,#0F,#DF,#9F,#3F,#8F,#EF,#8F
        defb #BF,#AF,#6F,#8F,#DF,#8F,#AF,#CF,#6F,#8F,#EF,#CF,#6F,#5F,#DF,#CF
        defb #6F,#3F,#DF,#CF,#7F,#3F,#BF,#CF,#3F,#1F,#BF,#CF,#3F,#1F,#9F,#CF
        defb #3F,#1F,#9F,#EF,#3F,#9F,#9F,#EF,#3F,#8F,#DF,#EF,#1F,#8F,#DF,#FF
        defb #1F,#CF,#DF,#FF,#1F,#CF,#DF,#FF,#1F,#CF,#5F,#FF,#1F,#EF,#5F,#FF
        defb #1F,#6F,#6F,#FF,#3F,#AF,#6F,#FF,#3F,#AF,#7F,#EF,#7F,#BF,#7F,#EF
        defb #7F,#9F,#3F,#EF,#FF,#3F,#BF,#EF,#EF,#7F,#BF,#EF,#EF,#7F,#BF,#DF
        defb #CF,#FF,#BF,#DF,#CF,#FF,#DF,#FF,#DF,#FF,#DF,#FF,#DF,#FF,#DF,#FF
        defb #FF,#FF,#DF
sprite_wood_door2_6197:
        ; Sprite "wood_door2" (4x59 octets/ligne, 236 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 04.
        defb #04,#3B,#00,#CC,#00,#00,#00,#3F,#00,#00,#00,#0F,#88,#00,#00,#1F
        defb #00,#00,#00,#AE,#00,#00,#00,#9F,#00,#00,#00,#9F,#00,#00,#00,#9F
        defb #00,#00,#00,#8F,#88,#00,#00,#CF,#88,#00,#00,#CF,#88,#00,#00,#8F
        defb #88,#00,#00,#9F,#00,#00,#00,#9F,#00,#00,#00,#2E,#00,#00,#00,#2E
        defb #00,#00,#00,#2E,#00,#00,#00,#1F,#00,#00,#00,#8F,#88,#00,#00,#8F
        defb #88,#00,#00,#8F,#4C,#00,#00,#4F,#4C,#00,#00,#4F,#4C,#00,#00,#4F
        defb #4C,#00,#00,#23,#4C,#00,#00,#23,#4C,#00,#00,#23,#4C,#00,#00,#33
        defb #4C,#00,#00,#33,#2E,#00,#00,#23,#2E,#00,#00,#23,#2E,#00,#00,#23
        defb #4C,#00,#00,#47,#6E,#00,#00,#AF,#1F,#00,#00,#BF,#0F,#4C,#00,#9F
        defb #8F,#6E,#00,#9F,#CF,#5F,#00,#8F,#8F,#DF,#00,#0F,#8F,#CF,#88,#9F
        defb #0F,#EF,#5D,#9F,#0F,#EF,#3F,#AF,#1F,#BF,#1F,#AF,#1F,#BF,#9F,#AF
        defb #3F,#9F,#9F,#AF,#3F,#DF,#CF,#BF,#3F,#CF,#CF,#57,#3F,#EF,#EF,#57
        defb #3F,#EF,#7F,#57,#3F,#CF,#EF,#57,#BF,#CF,#EF,#33,#BF,#47,#FF,#11
        defb #AE,#47,#FF,#00,#AE,#57,#BB,#00,#66,#57,#BB,#00,#00,#57,#99,#00
        defb #00,#23,#88,#00,#00,#23,#88,#00,#00,#23,#88,#00,#00,#11,#00
sprite_wood_door1_6286:
        ; Sprite "wood_door1" (4x48 octets/ligne, 192 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 05.
        defb #04,#30,#00,#00,#00,#66,#00,#00,#00,#9F,#88,#00,#33,#2F,#6E,#00
        defb #CF,#8F,#1F,#11,#3F,#3F,#2F,#11,#5F,#7F,#2F,#11,#5F,#3F,#AF,#11
        defb #6F,#3F,#4F,#11,#6F,#1F,#CF,#11,#2F,#5F,#9F,#00,#AF,#5F,#9F,#00
        defb #BF,#5F,#3F,#11,#7F,#5F,#9F,#11,#3F,#1F,#DF,#00,#AF,#1F,#5F,#00
        defb #AF,#1F,#5F,#11,#3F,#1F,#4F,#11,#3F,#9F,#6F,#11,#1F,#AF,#5F,#11
        defb #3F,#2F,#9F,#11,#2F,#5F,#9F,#11,#2F,#AF,#9F,#23,#2F,#6F,#9F,#23
        defb #6F,#5F,#1F,#23,#CF,#DF,#1F,#57,#9F,#BF,#9F,#BF,#3F,#7F,#9F,#7F
        defb #6F,#7F,#9F,#EF,#CF,#FF,#1F,#9F,#8F,#FF,#1F,#3F,#9F,#FF,#1F,#3F
        defb #1F,#FF,#2E,#7F,#1F,#BF,#2E,#7F,#1F,#BF,#1F,#7F,#1F,#BF,#1F,#7F
        defb #1F,#9F,#9F,#7F,#1F,#9F,#9F,#7F,#1F,#8F,#DF,#7F,#0F,#CF,#DF,#3F
        defb #8F,#EF,#5F,#3F,#8F,#6F,#5F,#BF,#47,#6F,#6F,#9F,#22,#3F,#4C,#DF
        defb #11,#3F,#4C,#77,#00,#BF,#4C,#22,#00,#57,#4C,#00,#00,#33,#4C,#00
        defb #00,#00,#88
sprite_hud2_6349:
        ; Sprite "hud2" (4x8 octets/ligne, 32 octets de bitmap). Type(s) d'entite
        ; associe(s) via tbl_sprite_dispatch : 86.
        defb #04,#08,#01,#00,#00,#00,#03,#00,#00,#00,#0C,#00,#00,#03,#00,#00
        defb #00,#0C,#00,#00,#03,#00,#00,#00,#0C,#00,#00,#03,#00,#00,#00,#0C
        defb #00,#00,#00
sprite_scroll2_636C:
        ; Sprite "scroll2" (4x16 octets/ligne, 64 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 88.
        defb #04,#10,#01,#00,#03,#0C,#03,#00,#04,#02,#0C,#00,#08,#01,#00,#00
        defb #08,#01,#00,#00,#04,#01,#00,#00,#07,#09,#00,#00,#0D,#07,#00,#00
        defb #09,#01,#00,#00,#09,#01,#00,#00,#09,#0E,#00,#00,#04,#00,#00,#00
        defb #02,#00,#00,#00,#01,#08,#00,#00,#00,#07,#00,#00,#00,#00,#0C,#00
        defb #00,#00,#03
sprite_hud1_63AF:
        ; Sprite "hud1" (4x10 octets/ligne, 40 octets de bitmap). Type(s) d'entite
        ; associe(s) via tbl_sprite_dispatch : 87.
        defb #04,#0A,#01,#08,#07,#0F,#00,#05,#08,#00,#0C,#02,#00,#00,#02,#04
        defb #00,#00,#01,#04,#00,#00,#01,#04,#00,#00,#01,#04,#00,#00,#01,#02
        defb #00,#00,#02,#02,#00,#00,#02,#02,#00,#00,#02
sprite_menu4_63DA:
        ; Sprite "menu4" (4x1 octets/ligne, 4 octets de bitmap). Type(s) d'entite
        ; associe(s) via tbl_sprite_dispatch : C0.
        defb #04,#01,#01,#01,#00,#00,#04
sprite_scroll1_63E1:
        ; Sprite "scroll1" (4x18 octets/ligne, 72 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : C1.
        defb #04,#12,#01,#02,#00,#00,#04,#02,#00,#00,#02,#02,#00,#00,#02,#02
        defb #00,#00,#02,#04,#00,#00,#02,#04,#07,#08,#02,#05,#08,#0F,#02,#06
        defb #00,#08,#09,#04,#00,#08,#05,#04,#00,#08,#03,#02,#00,#08,#01,#01
        defb #08,#08,#01,#00,#07,#08,#01,#0C,#00,#00,#01,#06,#00,#00,#02,#01
        defb #00,#00,#04,#00,#0E,#01,#08,#00,#01,#0E,#00
sprite_hero_up8_642C:
        ; Sprite "hero_up8" (6x24 octets/ligne, 144 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 22,24.
        defb #06,#18,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00
        defb #00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#EE,#00
        defb #00,#00,#EE,#33,#1F,#DF,#88,#33,#1F,#CF,#0F,#4F,#4C,#47,#2F,#2F
        defb #0F,#7F,#4C,#8F,#4F,#2F,#0F,#2F,#88,#9F,#CF,#0F,#0F,#0F,#4C,#66
        defb #23,#0F,#0F,#7F,#88,#00,#11,#0F,#3F,#F8,#88,#00,#00,#8F,#FC,#F0
        defb #C4,#00,#11,#3F,#F0,#F0,#E2,#00,#11,#3E,#F0,#F7,#E2,#00,#00,#FC
        defb #F1,#F8,#C4,#00,#00,#F8,#F6,#F8,#88,#00,#11,#F0,#F8,#F4,#C4,#00
        defb #32,#F1,#F8,#F4,#88,#00,#32,#F1,#F4,#F5,#88,#00,#11,#F1,#F3,#FA
        defb #88,#00,#00,#F9,#F0,#F5,#00,#00,#00,#66,#F8,#EE,#00,#00,#00,#00
        defb #77,#00,#00
sprite_hero_up3_64BF:
        ; Sprite "hero_up3" (6x25 octets/ligne, 150 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 29,2D.
        defb #06,#19,#00,#00,#33,#00,#00,#00,#00,#00,#47,#88,#00,#00,#00,#00
        defb #8F,#88,#00,#00,#00,#00,#8F,#88,#00,#00,#00,#11,#1F,#33,#88,#00
        defb #44,#11,#1F,#CF,#7F,#00,#AE,#23,#7F,#0F,#0F,#99,#1F,#23,#8F,#8F
        defb #0F,#EF,#2E,#11,#0F,#8F,#1F,#1F,#4C,#11,#0F,#0F,#1F,#1F,#88,#00
        defb #8F,#0F,#0F,#2E,#00,#00,#47,#0F,#EF,#2E,#00,#00,#EB,#3F,#FF,#C4
        defb #00,#11,#F7,#BF,#9F,#EA,#00,#11,#F7,#FF,#9F,#FD,#00,#00,#FB,#EF
        defb #AF,#FE,#88,#00,#75,#EF,#4F,#FF,#C4,#00,#FA,#F7,#FF,#FF,#C4,#00
        defb #F9,#F9,#FF,#FC,#88,#00,#75,#F6,#F0,#F3,#00,#00,#75,#F1,#FF,#CC
        defb #00,#00,#32,#F8,#F8,#88,#00,#00,#11,#F5,#F1,#00,#00,#00,#00,#FA
        defb #E6,#00,#00,#00,#00,#77,#88,#00,#00
sprite_hero_up6_6558:
        ; Sprite "hero_up6" (6x25 octets/ligne, 150 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 26.
        defb #06,#19,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00
        defb #00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#FF,#00,#EE,#22
        defb #00,#33,#0F,#BB,#1F,#DF,#00,#47,#1F,#4F,#0F,#5F,#00,#47,#AF,#2F
        defb #0F,#4F,#88,#33,#CF,#2F,#0F,#3F,#4C,#00,#47,#0F,#0F,#0F,#88,#00
        defb #33,#0F,#0F,#0F,#88,#00,#11,#CF,#0F,#1F,#CC,#00,#23,#3F,#8F,#7E
        defb #E2,#00,#23,#4F,#FF,#F8,#F1,#00,#11,#8F,#FE,#F0,#F1,#00,#00,#9F
        defb #F8,#F3,#EA,#00,#00,#76,#F1,#FC,#C4,#00,#00,#F8,#F6,#F4,#E2,#00
        defb #11,#F0,#F8,#F4,#E2,#00,#32,#F1,#F4,#F4,#C4,#00,#32,#F2,#F3,#F2
        defb #C4,#00,#11,#F2,#F1,#FA,#88,#00,#00,#FE,#F0,#F5,#00,#00,#00,#11
        defb #F8,#E2,#00,#00,#00,#00,#77,#CC,#00
sprite_hero_up4_65F1:
        ; Sprite "hero_up4" (6x24 octets/ligne, 144 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 23.
        defb #06,#18,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00
        defb #00,#00,#00,#00,#00,#00,#00,#00,#00,#11,#CC,#00,#00,#00,#EE,#67
        defb #2E,#11,#88,#77,#1F,#8F,#2E,#23,#5D,#8F,#0F,#5F,#6E,#23,#2F,#4F
        defb #0F,#7F,#AE,#47,#4F,#2F,#0F,#2F,#4C,#47,#8F,#0F,#0F,#0F,#4C,#9F
        defb #47,#0F,#0F,#7F,#88,#9F,#23,#0F,#3F,#F8,#88,#66,#11,#8F,#FC,#F0
        defb #C4,#00,#11,#3F,#F0,#F0,#E2,#00,#11,#3E,#F0,#F7,#E2,#00,#00,#FC
        defb #F1,#F8,#C4,#00,#00,#F8,#F6,#F8,#88,#00,#11,#F0,#F8,#F4,#C4,#00
        defb #32,#F1,#F8,#F4,#88,#00,#32,#F1,#F4,#F5,#88,#00,#11,#F1,#F3,#FA
        defb #88,#00,#00,#F9,#F0,#F5,#00,#00,#00,#66,#F8,#EE,#00,#00,#00,#00
        defb #77,#00,#00
sprite_hero_up9_6684:
        ; Sprite "hero_up9" (6x24 octets/ligne, 144 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 20.
        defb #06,#18,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00
        defb #00,#00,#00,#00,#00,#00,#33,#88,#00,#00,#00,#00,#CF,#4C,#EE,#00
        defb #00,#11,#0F,#7F,#1F,#88,#00,#23,#3F,#9F,#0F,#4C,#00,#23,#EF,#1F
        defb #0F,#2E,#00,#11,#23,#1F,#0F,#1F,#00,#00,#11,#0F,#0F,#1F,#00,#00
        defb #11,#0F,#0F,#7F,#00,#00,#00,#8F,#3F,#F8,#88,#00,#00,#8F,#FC,#F0
        defb #C4,#00,#11,#3F,#F0,#F0,#E2,#00,#11,#3E,#F0,#F7,#E2,#00,#00,#FC
        defb #F1,#F8,#C4,#00,#00,#F8,#F6,#F8,#88,#00,#11,#F0,#F8,#F4,#C4,#00
        defb #32,#F1,#F8,#F4,#88,#00,#32,#F1,#F4,#F5,#88,#00,#11,#F1,#F3,#FA
        defb #88,#00,#00,#F9,#F0,#F5,#00,#00,#00,#66,#F8,#EE,#00,#00,#00,#00
        defb #77,#00,#00
sprite_hero_up10_6717:
        ; Sprite "hero_up10" (6x24 octets/ligne, 144 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 21,25.
        defb #06,#18,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00
        defb #00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#77,#00,#EE,#66
        defb #00,#11,#8F,#DD,#1F,#9F,#00,#23,#1F,#AF,#0F,#5F,#00,#47,#6F,#2F
        defb #0F,#6F,#88,#57,#CF,#2F,#0F,#1F,#00,#22,#23,#0F,#0F,#0F,#88,#00
        defb #11,#0F,#0F,#7F,#00,#00,#11,#0F,#3F,#F8,#88,#00,#00,#8F,#FC,#F0
        defb #C4,#00,#11,#3F,#F0,#F0,#E2,#00,#11,#3E,#F0,#F7,#E2,#00,#00,#FC
        defb #F1,#F8,#C4,#00,#00,#F8,#F6,#F8,#88,#00,#11,#F0,#F8,#F4,#C4,#00
        defb #32,#F1,#F8,#F4,#88,#00,#32,#F1,#F4,#F5,#88,#00,#11,#F1,#F3,#FA
        defb #88,#00,#00,#F9,#F0,#F5,#00,#00,#00,#66,#F8,#EE,#00,#00,#00,#00
        defb #77,#00,#00
sprite_conkers2_67AA:
        ; Sprite "conkers2" (4x16 octets/ligne, 64 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 58.
        defb #04,#10,#00,#00,#32,#88,#00,#22,#32,#88,#44,#75,#77,#CC,#EA,#32
        defb #FC,#F3,#C4,#11,#F8,#F1,#88,#11,#F0,#F0,#88,#32,#F0,#F0,#F7,#FE
        defb #F0,#F0,#F4,#F2,#F0,#F0,#F7,#FE,#F0,#F0,#C4,#33,#F0,#F0,#88,#11
        defb #F8,#F1,#88,#32,#FC,#F3,#C4,#75,#33,#CC,#EA,#22,#11,#C4,#44,#00
        defb #11,#C4,#00
sprite_sphere_67ED:
        ; Sprite "sphere" (4x16 octets/ligne, 64 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 59.
        defb #04,#10,#00,#00,#33,#CC,#00,#00,#FC,#F3,#00,#11,#F0,#F2,#88,#32
        defb #F0,#FC,#C4,#74,#F1,#F0,#E2,#74,#F2,#F0,#E2,#F8,#F1,#FC,#F1,#F8
        defb #F0,#F4,#F1,#F8,#F0,#F4,#F1,#F8,#F1,#F8,#F1,#74,#FA,#F1,#E2,#74
        defb #FD,#F3,#E2,#32,#F1,#F0,#C4,#11,#F0,#FC,#88,#00,#FC,#F3,#00,#00
        defb #33,#CC,#00
sprite_hero_up11_6830:
        ; Sprite "hero_up11" (6x25 octets/ligne, 150 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 28.
        defb #06,#19,#00,#00,#11,#CC,#00,#00,#00,#00,#23,#2E,#00,#00,#00,#00
        defb #47,#4C,#00,#00,#00,#00,#8F,#88,#00,#00,#00,#00,#8F,#BB,#88,#00
        defb #00,#11,#0F,#CF,#7F,#00,#88,#11,#3F,#8F,#0F,#99,#4C,#00,#CF,#4F
        defb #0F,#AB,#2E,#11,#0F,#4F,#1F,#4F,#4C,#11,#0F,#0F,#1F,#2F,#88,#00
        defb #8F,#0F,#0F,#3F,#00,#00,#47,#0F,#EF,#2E,#00,#00,#EB,#3F,#FF,#C4
        defb #00,#11,#F7,#BF,#9F,#EA,#00,#11,#F7,#FF,#9F,#FD,#00,#00,#FB,#EF
        defb #AF,#FE,#88,#00,#75,#EF,#4F,#FF,#C4,#00,#FA,#F7,#FF,#FF,#C4,#00
        defb #F9,#F9,#FF,#FC,#88,#00,#75,#F6,#F0,#F3,#00,#00,#75,#F1,#FF,#CC
        defb #00,#00,#32,#F8,#F8,#88,#00,#00,#11,#F5,#F1,#00,#00,#00,#00,#FA
        defb #E6,#00,#00,#00,#00,#77,#88,#00,#00
sprite_hero_up5_68C9:
        ; Sprite "hero_up5" (6x25 octets/ligne, 150 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 2B.
        defb #06,#19,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00
        defb #CC,#00,#00,#00,#00,#11,#2E,#00,#00,#00,#66,#23,#2E,#33,#88,#00
        defb #9F,#23,#6E,#CF,#7F,#33,#1F,#47,#7F,#0F,#0F,#CF,#2E,#47,#8F,#0F
        defb #0F,#AF,#4C,#57,#0F,#8F,#1F,#1F,#88,#23,#0F,#0F,#1F,#0F,#88,#23
        defb #0F,#0F,#0F,#1F,#00,#11,#8F,#0F,#EF,#2E,#00,#00,#4F,#3F,#FF,#C4
        defb #00,#11,#F7,#BF,#9F,#EA,#00,#11,#F7,#FF,#9F,#FD,#00,#00,#FB,#EF
        defb #AF,#FE,#88,#00,#75,#EF,#4F,#FF,#C4,#00,#FA,#F7,#FF,#FF,#C4,#00
        defb #F9,#F9,#FF,#FC,#88,#00,#75,#F6,#F0,#F3,#00,#00,#75,#F1,#FF,#CC
        defb #00,#00,#32,#F8,#F8,#88,#00,#00,#11,#F5,#F1,#00,#00,#00,#00,#FA
        defb #E6,#00,#00,#00,#00,#77,#88,#00,#00
sprite_hero_up12_6962:
        ; Sprite "hero_up12" (6x25 octets/ligne, 150 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 2A,2C.
        defb #06,#19,#00,#00,#00,#00,#00,#00,#00,#00,#66,#00,#00,#00,#00,#00
        defb #9F,#00,#00,#00,#00,#11,#1F,#00,#00,#00,#66,#23,#2E,#33,#88,#11
        defb #9F,#23,#2E,#CF,#7F,#23,#1F,#23,#7F,#0F,#0F,#CF,#1F,#47,#9F,#0F
        defb #0F,#AF,#6E,#33,#0F,#8F,#1F,#1F,#88,#23,#0F,#0F,#1F,#0F,#88,#11
        defb #0F,#0F,#0F,#1F,#00,#00,#8F,#0F,#EF,#2E,#00,#00,#EB,#3F,#FF,#C4
        defb #00,#11,#F7,#BF,#9F,#EA,#00,#11,#F7,#FF,#9F,#FD,#00,#00,#FB,#EF
        defb #AF,#FE,#88,#00,#75,#EF,#4F,#FF,#C4,#00,#FA,#F7,#FF,#FF,#C4,#00
        defb #F9,#F9,#FF,#FC,#88,#00,#75,#F6,#F0,#F3,#00,#00,#75,#F1,#FF,#CC
        defb #00,#00,#32,#F8,#F8,#88,#00,#00,#11,#F5,#F1,#00,#00,#00,#00,#FA
        defb #E6,#00,#00,#00,#00,#77,#88,#00,#00
sprite_hero_up7_69FB:
        ; Sprite "hero_up7" (6x24 octets/ligne, 144 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 27.
        defb #06,#18,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00
        defb #00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#EE,#22
        defb #00,#00,#EE,#33,#1F,#DF,#88,#33,#1F,#CF,#0F,#4F,#4C,#47,#2F,#2F
        defb #0F,#7F,#4C,#8F,#4F,#2F,#0F,#2F,#88,#9F,#CF,#3F,#CF,#0F,#4C,#66
        defb #23,#7F,#FF,#CF,#88,#00,#11,#F8,#F0,#D7,#00,#00,#11,#F3,#F8,#E2
        defb #00,#00,#11,#F4,#FE,#F1,#00,#00,#11,#F8,#F9,#F0,#88,#00,#11,#F1
        defb #F0,#F8,#C4,#00,#11,#F2,#F1,#F4,#C4,#00,#11,#F2,#F2,#F4,#E2,#00
        defb #11,#F0,#F4,#F2,#E2,#00,#00,#FA,#F8,#F2,#E2,#00,#00,#FB,#F1,#F2
        defb #E2,#00,#00,#75,#F6,#FC,#C4,#00,#00,#32,#F1,#F0,#88,#00,#00,#11
        defb #FF,#FF,#00
sprite_hero_up1_6A8E:
        ; Sprite "hero_up1" (6x25 octets/ligne, 150 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 2F.
        defb #06,#19,#00,#00,#00,#00,#00,#00,#00,#00,#33,#00,#00,#00,#00,#00
        defb #47,#88,#00,#00,#00,#00,#8F,#88,#00,#00,#00,#11,#1F,#33,#88,#00
        defb #44,#11,#1F,#CF,#7F,#00,#AE,#23,#7F,#0F,#0F,#99,#1F,#23,#8F,#8F
        defb #0F,#EF,#2E,#11,#0F,#8F,#1F,#1F,#4C,#11,#0F,#0F,#1F,#1F,#88,#00
        defb #8F,#0F,#0F,#3F,#00,#00,#47,#0F,#EF,#3E,#88,#00,#EB,#3F,#FF,#7E
        defb #88,#11,#F7,#FF,#FF,#FE,#88,#32,#FF,#7F,#FF,#FD,#00,#75,#DF,#5F
        defb #FF,#FA,#88,#75,#CF,#9F,#FF,#F4,#88,#75,#FF,#FF,#FC,#F8,#88,#32
        defb #FF,#FE,#F3,#F4,#88,#11,#F0,#F1,#FC,#F5,#00,#00,#FD,#FE,#F2,#EA
        defb #00,#00,#32,#F3,#F1,#C4,#00,#00,#11,#F0,#FC,#88,#00,#00,#00,#FC
        defb #F2,#00,#00,#00,#00,#33,#CC,#00,#00
sprite_hero_up2_6B27:
        ; Sprite "hero_up2" (6x25 octets/ligne, 150 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 2E.
        defb #06,#19,#00,#00,#00,#00,#00,#00,#00,#00,#33,#00,#00,#00,#00,#00
        defb #47,#88,#00,#00,#00,#00,#8F,#88,#00,#00,#00,#11,#1F,#33,#88,#00
        defb #00,#23,#1F,#CF,#7F,#11,#88,#23,#EF,#8F,#0F,#EF,#4C,#33,#0F,#8F
        defb #0F,#8F,#2E,#23,#0F,#4F,#1F,#4F,#4C,#11,#0F,#0F,#1F,#3F,#88,#00
        defb #CF,#0F,#0F,#2E,#00,#11,#E7,#0F,#EF,#4C,#00,#11,#F7,#0F,#FF,#CC
        defb #00,#00,#FB,#9F,#FF,#FF,#00,#00,#75,#FF,#FF,#8F,#88,#00,#FA,#FF
        defb #FF,#4F,#88,#00,#F9,#F3,#FF,#3F,#C4,#00,#F8,#FC,#F7,#FF,#C4,#00
        defb #F8,#F3,#F8,#F7,#C4,#00,#75,#F1,#F7,#F8,#88,#00,#75,#F2,#F2,#F7
        defb #00,#00,#32,#FA,#FC,#88,#00,#00,#11,#F7,#F1,#00,#00,#00,#00,#F8
        defb #E6,#00,#00,#00,#00,#77,#88,#00,#00
sprite_feet1_6BC0:
        ; Sprite "feet1" (6x16 octets/ligne, 96 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 10,90.
        defb #06,#10,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00
        defb #00,#00,#00,#EE,#00,#00,#00,#00,#33,#1F,#00,#00,#66,#00,#CF,#1F
        defb #00,#33,#9F,#11,#0F,#1F,#00,#47,#0F,#99,#1F,#FF,#00,#8F,#0F,#99
        defb #2F,#2E,#00,#8F,#7F,#33,#EF,#4C,#00,#47,#9F,#74,#BB,#88,#00,#33
        defb #9F,#F8,#F4,#E6,#00,#00,#9F,#F0,#F2,#F1,#00,#00,#BE,#F0,#F1,#F1
        defb #00,#00,#56,#F0,#F1,#E2,#00,#00,#33,#F0,#F0,#E2,#00,#00,#00,#FC
        defb #10,#E2,#00
sprite_feet2_6C23:
        ; Sprite "feet2" (6x16 octets/ligne, 96 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 11,15,91,95.
        defb #06,#10,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00
        defb #00,#CC,#00,#00,#00,#00,#77,#2E,#33,#88,#00,#00,#8F,#1F,#CF,#4C
        defb #00,#11,#0F,#1F,#0F,#4C,#00,#11,#0F,#EF,#0F,#4C,#00,#00,#9F,#2F
        defb #8F,#88,#00,#00,#77,#3F,#E7,#88,#00,#00,#11,#3E,#F3,#88,#00,#00
        defb #11,#7C,#F2,#C4,#00,#00,#11,#F8,#F1,#E2,#00,#00,#32,#F0,#F1,#E2
        defb #00,#00,#11,#F0,#F1,#E2,#00,#00,#00,#F8,#F0,#E2,#00,#00,#00,#74
        defb #10,#E2,#00
sprite_feet3_6C86:
        ; Sprite "feet3" (6x16 octets/ligne, 96 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 12,14,92,94.
        defb #06,#10,#00,#00,#00,#00,#00,#00,#00,#00,#00,#11,#88,#00,#00,#00
        defb #00,#EF,#4C,#00,#00,#00,#11,#0F,#2E,#00,#00,#00,#23,#0F,#2E,#00
        defb #00,#00,#23,#1F,#DF,#00,#00,#00,#11,#2F,#5F,#00,#00,#00,#11,#CF
        defb #9F,#00,#00,#00,#23,#9F,#EE,#00,#00,#00,#23,#BF,#F1,#88,#00,#00
        defb #11,#FC,#F0,#CC,#00,#00,#11,#F8,#F0,#EA,#00,#00,#11,#F0,#F0,#EA
        defb #00,#00,#00,#F8,#F0,#EA,#00,#00,#00,#F8,#F0,#E2,#00,#00,#00,#74
        defb #10,#E2,#00
sprite_feet4_6CE9:
        ; Sprite "feet4" (6x16 octets/ligne, 96 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 13,93.
        defb #06,#10,#00,#00,#00,#00,#66,#00,#00,#00,#00,#11,#9F,#00,#00,#00
        defb #00,#67,#0F,#88,#00,#00,#00,#8F,#4F,#88,#00,#00,#00,#8F,#FF,#00
        defb #00,#00,#00,#77,#9F,#00,#00,#00,#00,#FF,#2E,#00,#00,#00,#33,#2F
        defb #4C,#00,#00,#00,#47,#2F,#FF,#00,#00,#00,#47,#7F,#F8,#88,#00,#00
        defb #33,#BE,#F0,#CC,#00,#00,#11,#7C,#F0,#EA,#00,#00,#11,#78,#F0,#EA
        defb #00,#00,#32,#F8,#F0,#EA,#00,#00,#32,#F8,#F0,#E6,#00,#00,#11,#F4
        defb #10,#E2,#00
sprite_feet5_6D4C:
        ; Sprite "feet5" (6x17 octets/ligne, 102 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 18,98.
        defb #06,#11,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00
        defb #00,#00,#00,#33,#88,#00,#00,#00,#00,#CF,#4C,#00,#77,#00,#33,#0F
        defb #4C,#11,#8F,#88,#47,#0F,#4C,#23,#0F,#88,#8F,#2F,#88,#47,#1F,#00
        defb #47,#DD,#00,#8F,#FF,#00,#23,#4C,#00,#9F,#0F,#EE,#FF,#2E,#00,#67
        defb #3F,#F9,#F1,#DF,#00,#11,#FC,#F1,#F0,#E2,#00,#11,#F0,#F0,#F8,#E2
        defb #00,#00,#F8,#F0,#F8,#C4,#00,#00,#F8,#F0,#F8,#C4,#00,#00,#74,#F0
        defb #F0,#88,#00,#00,#32,#C0,#70,#88,#00
sprite_feet6_6DB5:
        ; Sprite "feet6" (6x17 octets/ligne, 102 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 19,1D,99,9D.
        defb #06,#11,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00
        defb #00,#00,#00,#00,#00,#00,#00,#EE,#00,#EE,#00,#00,#33,#1F,#33,#1F
        defb #00,#00,#47,#1F,#CF,#1F,#00,#00,#8F,#3F,#0F,#1F,#00,#11,#0F,#DD
        defb #0F,#EE,#00,#11,#3F,#88,#FF,#00,#00,#00,#CF,#7F,#9F,#00,#00,#00
        defb #23,#FC,#FE,#88,#00,#00,#77,#F0,#F8,#C4,#00,#00,#F8,#F0,#F8,#C4
        defb #00,#00,#74,#F0,#F8,#88,#00,#00,#74,#F0,#F8,#88,#00,#00,#32,#F0
        defb #F0,#88,#00,#00,#32,#C0,#70,#88,#00
sprite_feet7_6E1E:
        ; Sprite "feet7" (6x17 octets/ligne, 102 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 1A,1C,9A,9C.
        defb #06,#11,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00
        defb #00,#33,#00,#00,#00,#00,#00,#CF,#88,#00,#00,#00,#33,#0F,#7F,#88
        defb #00,#00,#47,#0F,#4F,#4C,#00,#00,#47,#3F,#8F,#4C,#00,#00,#57,#CF
        defb #2F,#4C,#00,#00,#23,#4F,#7F,#88,#00,#00,#23,#7F,#AE,#00,#00,#00
        defb #11,#FC,#EE,#00,#00,#00,#32,#F0,#F9,#00,#00,#00,#74,#F0,#F9,#00
        defb #00,#00,#74,#F0,#F8,#88,#00,#00,#74,#F0,#F8,#88,#00,#00,#32,#F0
        defb #F0,#88,#00,#00,#32,#C0,#70,#88,#00
sprite_feet8_6E87:
        ; Sprite "feet8" (6x17 octets/ligne, 102 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 1B,9B.
        defb #06,#11,#00,#00,#00,#00,#66,#00,#00,#00,#00,#11,#9F,#00,#00,#00
        defb #00,#67,#0F,#88,#00,#00,#00,#8F,#0F,#88,#00,#00,#11,#0F,#1F,#00
        defb #00,#00,#11,#1F,#EE,#00,#00,#00,#00,#AF,#88,#00,#00,#00,#33,#4F
        defb #4C,#00,#00,#00,#47,#2F,#4C,#00,#00,#00,#47,#FF,#2E,#00,#00,#00
        defb #57,#F0,#CC,#00,#00,#00,#32,#F0,#E2,#00,#00,#00,#32,#F0,#F5,#00
        defb #00,#00,#74,#F0,#F5,#00,#00,#00,#74,#F0,#F8,#88,#00,#00,#74,#F0
        defb #F0,#88,#00,#00,#32,#C0,#70,#88,#00
sprite_menu1_6EF0:
        ; Sprite "menu1" (2x24 octets/ligne, 48 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 8B.
        defb #02,#18,#00,#00,#00,#00,#00,#0F,#0F,#0F,#0F,#0F,#0F,#0F,#0F,#00
        defb #00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00
        defb #00,#00,#00,#00,#00,#00,#00,#0F,#0F,#0F,#0F,#0F,#0F,#0F,#0F,#00
        defb #00,#00,#00
sprite_menu3_6F23:
        ; Sprite "menu3" (6x1 octets/ligne, 6 octets de bitmap). Type(s) d'entite
        ; associe(s) via tbl_sprite_dispatch : 8A.
        defb #06,#01,#00,#03,#0C,#00,#00,#03,#0C
sprite_menu2_6F2C:
        ; Sprite "menu2" (8x30 octets/ligne, 240 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 89.
        defb #88,#1E,#00,#00,#00,#01,#0F,#00,#00,#00,#03,#00,#00,#03,#0F,#08
        defb #00,#00,#07,#00,#00,#07,#0F,#0C,#00,#00,#0F,#00,#00,#0F,#0B,#0E
        defb #00,#01,#0F,#00,#01,#0F,#01,#0F,#00,#03,#0E,#00,#03,#0E,#00,#0F
        defb #08,#07,#0C,#00,#07,#0C,#00,#07,#0C,#0F,#08,#00,#0F,#08,#00,#03
        defb #0D,#0F,#00,#01,#0F,#00,#00,#01,#0B,#0E,#00,#03,#0E,#00,#00,#00
        defb #07,#0C,#00,#03,#0C,#00,#00,#00,#0F,#08,#00,#03,#08,#00,#00,#01
        defb #0F,#06,#00,#03,#0C,#00,#00,#03,#0E,#0F,#00,#03,#0E,#00,#00,#07
        defb #0C,#0F,#08,#01,#0F,#00,#00,#0F,#08,#07,#0C,#00,#0F,#08,#01,#0F
        defb #00,#03,#0E,#00,#07,#0C,#03,#0E,#00,#01,#0F,#00,#03,#0E,#07,#0C
        defb #00,#00,#0F,#00,#01,#0F,#07,#08,#00,#00,#07,#00,#00,#0F,#0B,#00
        defb #00,#00,#03,#00,#00,#07,#0C,#00,#00,#00,#00,#00,#00,#03,#0E,#00
        defb #00,#00,#00,#00,#00,#0D,#0F,#00,#00,#00,#00,#00,#01,#0E,#0F,#08
        defb #00,#00,#00,#00,#03,#0E,#07,#0C,#00,#00,#00,#00,#07,#0C,#03,#0E
        defb #00,#00,#00,#00,#0F,#08,#01,#0F,#00,#00,#00,#01,#0F,#00,#00,#0F
        defb #08,#00,#00,#03,#0E,#00,#00,#07,#0C,#00,#00,#03,#0C,#00,#00,#03
        defb #0C,#00,#00
sprite_werewulf_up6_701F:
        ; Sprite "werewulf_up6" (6x29 octets/ligne, 174 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 40.
        defb #06,#1D,#00,#00,#00,#11,#88,#00,#00,#00,#00,#32,#C4,#00,#00,#00
        defb #00,#74,#EA,#00,#00,#00,#00,#75,#44,#00,#00,#00,#00,#F9,#00,#00
        defb #00,#00,#00,#F8,#88,#00,#00,#00,#00,#F8,#88,#00,#00,#00,#00,#74
        defb #C4,#00,#00,#00,#00,#74,#E2,#00,#00,#00,#00,#32,#F2,#E2,#00,#00
        defb #00,#74,#F2,#E2,#00,#00,#00,#F8,#F4,#E2,#00,#00,#11,#F0,#F8,#F3
        defb #00,#00,#11,#F1,#F0,#F2,#00,#00,#32,#F0,#F0,#F0,#C4,#00,#32,#F0
        defb #F0,#F0,#C4,#00,#11,#F8,#F0,#F0,#C4,#00,#11,#F7,#F0,#F1,#88,#00
        defb #11,#F6,#F0,#F0,#88,#00,#32,#F0,#F8,#F0,#88,#00,#32,#F2,#F8,#F0
        defb #88,#00,#11,#F4,#F4,#F0,#88,#00,#00,#F8,#F4,#F0,#88,#00,#00,#F8
        defb #F8,#F0,#88,#00,#11,#F1,#F0,#F1,#00,#00,#11,#E2,#FF,#F1,#00,#00
        defb #00,#CC,#11,#E2,#00,#00,#00,#00,#11,#C4,#00,#00,#00,#00,#00,#88
        defb #00
sprite_werewulf1_70D0:
        ; Sprite "werewulf1" (6x29 octets/ligne, 174 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 41,45.
        defb #06,#1D,#00,#00,#00,#33,#00,#00,#00,#00,#00,#74,#88,#00,#00,#00
        defb #00,#F9,#C4,#00,#00,#00,#00,#F9,#88,#00,#00,#00,#11,#F1,#00,#00
        defb #00,#00,#11,#F1,#00,#00,#00,#00,#11,#F0,#88,#00,#00,#00,#00,#F8
        defb #88,#00,#00,#00,#00,#F8,#C4,#00,#00,#00,#00,#F8,#F4,#E2,#00,#00
        defb #00,#F8,#F4,#F3,#00,#00,#00,#F8,#F8,#F2,#88,#00,#11,#F1,#F0,#F2
        defb #88,#00,#11,#F0,#F0,#F2,#C4,#00,#32,#F0,#F0,#F0,#C4,#00,#32,#F0
        defb #F0,#F0,#C4,#00,#11,#F8,#F0,#F0,#C4,#00,#11,#F7,#F0,#F1,#88,#00
        defb #11,#F6,#F0,#F0,#88,#00,#32,#F0,#F8,#F0,#88,#00,#32,#F2,#F8,#F0
        defb #88,#00,#11,#F4,#F4,#F0,#88,#00,#00,#F8,#F4,#F0,#88,#00,#00,#F8
        defb #F8,#F0,#88,#00,#11,#F1,#F0,#F1,#00,#00,#11,#E2,#FF,#F1,#00,#00
        defb #00,#CC,#11,#E2,#00,#00,#00,#00,#11,#C4,#00,#00,#00,#00,#00,#88
        defb #00
sprite_werewulf_up2_7181:
        ; Sprite "werewulf_up2" (6x29 octets/ligne, 174 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 42,44.
        defb #06,#1D,#00,#00,#00,#00,#00,#00,#00,#00,#33,#00,#00,#00,#00,#00
        defb #74,#88,#00,#00,#00,#00,#F9,#C4,#00,#00,#00,#00,#F9,#88,#00,#00
        defb #00,#00,#F9,#00,#00,#00,#00,#00,#F8,#CC,#00,#00,#00,#00,#74,#E2
        defb #00,#00,#00,#00,#32,#F1,#00,#00,#00,#00,#11,#F0,#F8,#F2,#88,#00
        defb #11,#F0,#F8,#F2,#C4,#00,#11,#F1,#F0,#F2,#C4,#00,#11,#F1,#F0,#F2
        defb #C4,#00,#11,#F0,#F0,#F1,#C4,#00,#32,#F0,#F0,#F0,#C4,#00,#32,#F0
        defb #F0,#F0,#C4,#00,#11,#F8,#F0,#F0,#C4,#00,#11,#F7,#F0,#F1,#88,#00
        defb #11,#F6,#F0,#F0,#88,#00,#32,#F0,#F8,#F0,#88,#00,#32,#F2,#F8,#F0
        defb #88,#00,#11,#F4,#F4,#F0,#88,#00,#00,#F8,#F4,#F0,#88,#00,#00,#F8
        defb #F8,#F0,#88,#00,#11,#F1,#F0,#F1,#00,#00,#11,#E2,#FF,#F1,#00,#00
        defb #00,#CC,#11,#E2,#00,#00,#00,#00,#11,#C4,#00,#00,#00,#00,#00,#88
        defb #00
sprite_werewulf_up8_7232:
        ; Sprite "werewulf_up8" (6x29 octets/ligne, 174 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 43.
        defb #06,#1D,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00
        defb #00,#00,#00,#00,#00,#11,#00,#00,#00,#00,#00,#32,#88,#00,#00,#00
        defb #00,#75,#00,#00,#00,#00,#00,#F9,#CC,#00,#00,#00,#00,#F8,#F3,#CC
        defb #00,#00,#CC,#74,#F0,#E2,#00,#11,#E2,#33,#F0,#F1,#F0,#F2,#F1,#00
        defb #FE,#F1,#F0,#F2,#F9,#00,#32,#F2,#F0,#F3,#F9,#00,#32,#F2,#F0,#F1
        defb #F1,#00,#32,#F0,#F0,#F1,#E2,#00,#32,#F0,#F0,#F0,#E2,#00,#33,#F0
        defb #F0,#F0,#E2,#00,#11,#F8,#F0,#F0,#C4,#00,#11,#F7,#F0,#F1,#88,#00
        defb #11,#F6,#F0,#F0,#88,#00,#32,#F0,#F8,#F0,#88,#00,#32,#F2,#F8,#F0
        defb #88,#00,#11,#F4,#F4,#F0,#88,#00,#00,#F8,#F4,#F0,#88,#00,#00,#F8
        defb #F8,#F0,#88,#00,#11,#F1,#F0,#F1,#00,#00,#11,#E2,#FF,#F1,#00,#00
        defb #00,#CC,#11,#E2,#00,#00,#00,#00,#11,#C4,#00,#00,#00,#00,#00,#88
        defb #00
sprite_werewulf_up3_72E3:
        ; Sprite "werewulf_up3" (6x30 octets/ligne, 180 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 4B.
        defb #06,#1E,#00,#00,#00,#00,#00,#00,#00,#00,#00,#22,#00,#00,#00,#00
        defb #00,#75,#00,#00,#00,#00,#00,#74,#88,#00,#00,#00,#00,#FC,#88,#00
        defb #00,#00,#11,#F0,#88,#00,#00,#00,#32,#F1,#00,#11,#00,#00,#74,#E2
        defb #00,#32,#88,#00,#F8,#C4,#00,#32,#C4,#11,#F0,#F8,#F0,#F6,#C4,#11
        defb #F0,#F8,#F0,#F4,#C4,#11,#F0,#F8,#F0,#F4,#88,#00,#F8,#F8,#F0,#F5
        defb #00,#00,#F8,#F8,#F0,#E6,#00,#00,#F8,#F0,#F1,#CC,#00,#00,#F8,#F0
        defb #FE,#E2,#00,#00,#F8,#F1,#F5,#E6,#00,#00,#75,#FE,#F5,#FD,#00,#00
        defb #32,#F0,#F4,#F1,#00,#00,#32,#F0,#F9,#F5,#00,#00,#32,#F0,#F0,#F1
        defb #00,#00,#32,#F8,#F0,#E2,#00,#00,#11,#F0,#F8,#EA,#00,#00,#11,#F0
        defb #FD,#F9,#00,#00,#32,#F0,#F0,#F2,#88,#00,#32,#F0,#F0,#F4,#88,#00
        defb #74,#F2,#F0,#F8,#88,#00,#74,#DD,#FF,#74,#88,#00,#FB,#00,#00,#33
        defb #C4,#00,#44,#00,#00,#00,#88
sprite_werewulf_up7_739A:
        ; Sprite "werewulf_up7" (6x30 octets/ligne, 180 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 4A,4C.
        defb #06,#1E,#00,#00,#00,#00,#00,#00,#00,#00,#00,#88,#00,#00,#00,#00
        defb #11,#C4,#00,#00,#00,#00,#00,#EA,#00,#00,#00,#00,#00,#F9,#00,#00
        defb #00,#00,#11,#F1,#00,#00,#00,#00,#76,#E2,#00,#11,#00,#00,#F8,#C4
        defb #00,#32,#88,#11,#F0,#88,#00,#33,#C4,#32,#F1,#F0,#F0,#F7,#E2,#74
        defb #F1,#F0,#F0,#F6,#E2,#32,#F1,#F0,#F0,#F4,#C4,#32,#F0,#F8,#F0,#F4
        defb #88,#32,#F0,#F8,#F0,#F7,#00,#11,#F0,#F0,#F1,#CC,#00,#11,#F0,#F0
        defb #FE,#E2,#00,#11,#F0,#F1,#F5,#E6,#00,#00,#F9,#FE,#F5,#FD,#00,#00
        defb #76,#F0,#F4,#F1,#00,#00,#32,#F0,#F9,#F5,#00,#00,#32,#F0,#F0,#F1
        defb #00,#00,#32,#F8,#F0,#E2,#00,#00,#11,#F0,#F8,#EA,#00,#00,#11,#F0
        defb #FD,#F9,#00,#00,#32,#F0,#F0,#F2,#88,#00,#32,#F0,#F0,#F4,#88,#00
        defb #74,#F2,#F0,#F8,#88,#00,#74,#DD,#FF,#74,#88,#00,#FB,#00,#00,#33
        defb #C4,#00,#44,#00,#00,#00,#88
sprite_werewulf_up9_7451:
        ; Sprite "werewulf_up9" (6x30 octets/ligne, 180 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 49,4D.
        defb #06,#1E,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00
        defb #33,#00,#00,#00,#00,#00,#74,#88,#00,#00,#00,#00,#32,#C4,#00,#00
        defb #00,#00,#32,#C4,#00,#00,#88,#00,#32,#C4,#00,#11,#C4,#00,#74,#C4
        defb #00,#00,#EA,#00,#F8,#88,#00,#00,#EA,#11,#F1,#F0,#F0,#F7,#E2,#32
        defb #F3,#F0,#F0,#F4,#E2,#74,#F3,#F0,#F0,#F4,#C4,#74,#F1,#F8,#F0,#F4
        defb #88,#32,#F0,#F8,#F0,#F7,#00,#32,#F0,#F0,#F1,#CC,#00,#11,#F0,#F0
        defb #FE,#E2,#00,#00,#F8,#F1,#F5,#E6,#00,#00,#75,#FE,#F5,#FD,#00,#00
        defb #32,#F0,#F4,#F1,#00,#00,#32,#F0,#F9,#F5,#00,#00,#32,#F0,#F0,#F1
        defb #00,#00,#32,#F8,#F0,#E2,#00,#00,#11,#F0,#F8,#EA,#00,#00,#11,#F0
        defb #FD,#F9,#00,#00,#32,#F0,#F0,#F2,#88,#00,#32,#F0,#F0,#F4,#88,#00
        defb #74,#F2,#F0,#F8,#88,#00,#74,#DD,#FF,#74,#88,#00,#FB,#00,#00,#33
        defb #C4,#00,#44,#00,#00,#00,#88
sprite_werewulf_up10_7508:
        ; Sprite "werewulf_up10" (6x30 octets/ligne, 180 octets de bitmap).
        ; Type(s) d'entite associe(s) via tbl_sprite_dispatch : 48.
        defb #06,#1E,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00
        defb #00,#00,#00,#00,#00,#00,#66,#00,#00,#00,#CC,#00,#F9,#00,#00,#11
        defb #E2,#00,#74,#88,#00,#00,#F9,#00,#74,#88,#00,#00,#F9,#00,#74,#88
        defb #00,#11,#F1,#00,#F9,#00,#00,#32,#E2,#00,#F9,#F0,#F0,#F4,#C4,#11
        defb #F2,#F0,#F0,#F4,#C4,#11,#F2,#F0,#F0,#F4,#88,#32,#F1,#F0,#F0,#F4
        defb #88,#32,#F0,#F8,#F0,#F4,#88,#32,#F0,#F0,#F1,#FD,#00,#11,#F0,#F0
        defb #FE,#E2,#00,#00,#F8,#F1,#F5,#E6,#00,#00,#75,#FE,#F5,#FD,#00,#00
        defb #32,#F0,#F4,#F1,#00,#00,#32,#F0,#F9,#F5,#00,#00,#32,#F0,#F0,#F1
        defb #00,#00,#32,#F8,#F0,#E2,#00,#00,#11,#F0,#F8,#EA,#00,#00,#11,#F0
        defb #FD,#F9,#00,#00,#32,#F0,#F0,#F2,#88,#00,#32,#F0,#F0,#F4,#88,#00
        defb #74,#F2,#F0,#F8,#88,#00,#74,#DD,#FF,#74,#88,#00,#FB,#00,#00,#33
        defb #C4,#00,#44,#00,#00,#00,#88
sprite_werewulf_up4_75BF:
        ; Sprite "werewulf_up4" (6x29 octets/ligne, 174 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 46.
        defb #06,#1D,#00,#00,#00,#00,#00,#00,#00,#00,#33,#00,#00,#00,#00,#00
        defb #74,#88,#00,#00,#00,#00,#F9,#C4,#00,#00,#00,#00,#F9,#88,#00,#00
        defb #00,#00,#F9,#88,#00,#00,#00,#00,#74,#E6,#00,#00,#00,#00,#32,#F1
        defb #00,#00,#00,#00,#11,#F0,#88,#00,#00,#00,#00,#F8,#F8,#F3,#00,#00
        defb #00,#F8,#F8,#F2,#88,#00,#11,#F0,#F8,#F2,#88,#00,#11,#F0,#F8,#F2
        defb #C4,#00,#11,#F0,#F0,#F1,#C4,#00,#11,#F0,#F0,#F0,#C4,#00,#33,#F0
        defb #F0,#F0,#C4,#00,#74,#FC,#F0,#F0,#88,#00,#74,#F0,#F0,#F3,#00,#00
        defb #77,#FC,#F0,#F1,#00,#00,#EA,#F8,#F0,#F1,#00,#00,#F9,#F1,#F0,#F1
        defb #00,#11,#F0,#F2,#F0,#F1,#00,#11,#F4,#F2,#F0,#F1,#00,#00,#F9,#FC
        defb #F0,#F1,#00,#00,#66,#74,#F0,#E2,#00,#00,#00,#74,#FC,#C4,#00,#00
        defb #00,#75,#74,#C4,#00,#00,#00,#22,#74,#88,#00,#00,#00,#00,#33,#00
        defb #00
sprite_werewulf_up11_7670:
        ; Sprite "werewulf_up11" (6x29 octets/ligne, 174 octets de bitmap).
        ; Type(s) d'entite associe(s) via tbl_sprite_dispatch : 47.
        defb #06,#1D,#00,#00,#00,#00,#00,#00,#00,#00,#33,#00,#00,#00,#00,#00
        defb #74,#88,#00,#00,#00,#00,#F9,#C4,#00,#00,#00,#00,#F9,#88,#00,#00
        defb #00,#00,#F9,#00,#00,#00,#00,#00,#F9,#00,#00,#00,#00,#00,#F8,#88
        defb #00,#00,#00,#00,#F8,#C4,#00,#00,#00,#00,#74,#F2,#F0,#F2,#88,#00
        defb #32,#F2,#F0,#F2,#C4,#00,#32,#F2,#F0,#F2,#C4,#00,#32,#F2,#F0,#F2
        defb #E2,#00,#32,#F2,#F0,#F0,#E2,#00,#32,#F0,#F0,#F0,#E2,#00,#11,#F0
        defb #F0,#F0,#E2,#00,#11,#F0,#F0,#F0,#C4,#00,#00,#FE,#F0,#F1,#CC,#00
        defb #00,#74,#F0,#F0,#E2,#00,#00,#74,#F0,#F0,#F1,#00,#00,#74,#F0,#F0
        defb #E6,#00,#00,#74,#F0,#F0,#F1,#00,#00,#74,#F0,#F0,#F1,#00,#00,#74
        defb #F0,#F0,#E6,#00,#00,#74,#F0,#F0,#88,#00,#00,#74,#7F,#F8,#88,#00
        defb #00,#32,#C4,#F8,#88,#00,#00,#11,#C4,#75,#00,#00,#00,#00,#88,#11
        defb #00
sprite_werewulf_up12_7721:
        ; Sprite "werewulf_up12" (6x30 octets/ligne, 180 octets de bitmap).
        ; Type(s) d'entite associe(s) via tbl_sprite_dispatch : 4E.
        defb #06,#1E,#00,#00,#00,#00,#00,#00,#00,#00,#00,#22,#00,#00,#00,#00
        defb #00,#75,#00,#00,#00,#00,#00,#74,#88,#00,#00,#00,#00,#FC,#88,#00
        defb #00,#00,#11,#F0,#88,#00,#00,#00,#32,#F1,#00,#11,#00,#00,#74,#E2
        defb #00,#32,#88,#00,#F8,#C4,#00,#32,#C4,#11,#F0,#F8,#F0,#F6,#C4,#11
        defb #F0,#F8,#F0,#F4,#C4,#11,#F0,#F8,#F0,#F4,#88,#00,#F8,#F8,#F0,#F1
        defb #00,#00,#F8,#F0,#F0,#F1,#00,#00,#74,#F0,#F0,#F7,#CC,#00,#74,#F0
        defb #F0,#F8,#E2,#00,#74,#F0,#F3,#F3,#EE,#00,#32,#FF,#FC,#F6,#FD,#00
        defb #11,#F0,#F0,#F6,#FD,#00,#11,#F0,#F1,#F8,#F1,#00,#11,#F0,#F0,#F1
        defb #F5,#00,#11,#F0,#F0,#F0,#E2,#00,#00,#F8,#F2,#F0,#CC,#00,#00,#F8
        defb #F3,#F5,#00,#00,#11,#F0,#F0,#F1,#00,#00,#11,#F0,#F0,#F1,#00,#00
        defb #11,#F0,#F8,#F1,#00,#00,#11,#F1,#FF,#F1,#00,#00,#32,#E6,#00,#FC
        defb #88,#00,#11,#88,#00,#33,#00
sprite_werewulf_up5_77D8:
        ; Sprite "werewulf_up5" (6x30 octets/ligne, 180 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 4F.
        defb #06,#1E,#00,#00,#00,#00,#00,#00,#00,#00,#00,#88,#00,#00,#00,#00
        defb #11,#C4,#00,#00,#00,#00,#00,#EA,#00,#00,#00,#00,#00,#EA,#00,#00
        defb #00,#00,#11,#E2,#00,#00,#00,#00,#32,#E2,#00,#11,#00,#00,#74,#C4
        defb #00,#32,#88,#00,#F8,#88,#00,#32,#C4,#11,#F1,#F0,#F0,#F2,#C4,#11
        defb #F1,#F0,#F0,#F2,#C4,#11,#F1,#F0,#F0,#F2,#C4,#32,#F1,#F0,#F0,#F4
        defb #C4,#32,#F0,#F0,#F0,#F0,#C4,#32,#F0,#FC,#F0,#F0,#88,#32,#F3,#F3
        defb #F0,#F0,#88,#11,#F5,#FE,#FB,#F1,#00,#00,#FC,#F0,#FC,#EE,#00,#00
        defb #74,#F0,#F4,#E2,#00,#00,#74,#FA,#F0,#E2,#00,#00,#32,#F0,#F0,#E2
        defb #00,#00,#32,#F0,#F0,#E2,#00,#00,#11,#F4,#F4,#E2,#00,#00,#11,#F6
        defb #FC,#E2,#00,#00,#11,#F0,#F0,#C4,#00,#00,#32,#F0,#F0,#E2,#00,#00
        defb #32,#F0,#F0,#E2,#00,#00,#32,#F1,#FE,#E2,#00,#00,#32,#E6,#11,#F9
        defb #00,#00,#11,#88,#00,#66,#00
sprite_werewulf_feet8_788F:
        ; Sprite "werewulf_feet8" (6x16 octets/ligne, 96 octets de bitmap).
        ; Type(s) d'entite associe(s) via tbl_sprite_dispatch : 30.
        defb #06,#10,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00
        defb #00,#00,#00,#66,#00,#00,#00,#00,#99,#F9,#00,#00,#33,#11,#F6,#F0
        defb #88,#22,#74,#99,#F0,#F0,#88,#75,#F8,#C4,#F8,#F9,#00,#74,#F0,#C4
        defb #77,#F1,#00,#74,#F2,#C4,#11,#E2,#00,#32,#F4,#88,#DD,#E2,#00,#11
        defb #FC,#BB,#F2,#E2,#00,#00,#74,#FC,#F1,#F1,#00,#00,#74,#F0,#F0,#F8
        defb #88,#00,#32,#F0,#F0,#F8,#88,#00,#11,#F8,#F0,#F1,#00,#00,#00,#74
        defb #F0,#F1,#00
sprite_werewulf_feet6_78F2:
        ; Sprite "werewulf_feet6" (6x16 octets/ligne, 96 octets de bitmap).
        ; Type(s) d'entite associe(s) via tbl_sprite_dispatch : 31,35.
        defb #06,#10,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00
        defb #00,#CC,#00,#00,#00,#00,#99,#E2,#33,#88,#00,#11,#F6,#F1,#FC,#C4
        defb #00,#11,#F0,#F1,#F0,#C4,#00,#11,#F0,#FA,#F0,#C4,#00,#00,#F9,#F2
        defb #F6,#88,#00,#00,#77,#F3,#FC,#88,#00,#00,#11,#F0,#F4,#88,#00,#00
        defb #11,#F0,#F2,#C4,#00,#00,#11,#F0,#F1,#E2,#00,#00,#11,#F0,#F1,#E2
        defb #00,#00,#00,#F8,#F1,#E2,#00,#00,#00,#F8,#F0,#E2,#00,#00,#00,#74
        defb #F0,#E2,#00
sprite_werewulf_feet9_7955:
        ; Sprite "werewulf_feet9" (6x16 octets/ligne, 96 octets de bitmap).
        ; Type(s) d'entite associe(s) via tbl_sprite_dispatch : 32,34.
        defb #06,#10,#00,#00,#00,#00,#00,#00,#00,#00,#00,#11,#88,#00,#00,#00
        defb #11,#32,#C4,#00,#00,#00,#32,#FC,#E2,#00,#00,#00,#32,#F0,#E2,#00
        defb #00,#00,#32,#F1,#E2,#00,#00,#00,#11,#F2,#F5,#00,#00,#00,#32,#FC
        defb #F9,#00,#00,#00,#32,#F4,#EA,#00,#00,#00,#32,#F8,#F5,#00,#00,#00
        defb #11,#F8,#F3,#00,#00,#00,#00,#F8,#F1,#00,#00,#00,#00,#74,#F0,#CC
        defb #00,#00,#00,#F8,#F0,#EA,#00,#00,#00,#F8,#F0,#E2,#00,#00,#00,#74
        defb #F0,#E2,#00
sprite_werewulf_feet7_79B8:
        ; Sprite "werewulf_feet7" (6x16 octets/ligne, 96 octets de bitmap).
        ; Type(s) d'entite associe(s) via tbl_sprite_dispatch : 33.
        defb #06,#10,#00,#00,#00,#00,#66,#00,#00,#00,#00,#55,#F9,#00,#00,#00
        defb #00,#FA,#F0,#88,#00,#00,#00,#F8,#F4,#88,#00,#00,#00,#74,#F8,#88
        defb #00,#00,#22,#77,#F9,#00,#00,#00,#75,#F9,#F1,#00,#00,#00,#74,#F1
        defb #E2,#00,#00,#00,#74,#F2,#E2,#00,#00,#00,#33,#FA,#F1,#00,#00,#00
        defb #00,#FA,#F0,#88,#00,#00,#11,#F2,#F0,#88,#00,#00,#11,#F4,#F0,#C4
        defb #00,#00,#32,#F4,#F0,#C4,#00,#00,#32,#F4,#F0,#C4,#00,#00,#11,#F4
        defb #F0,#C4,#00
sprite_werewulf_feet1_7A1B:
        ; Sprite "werewulf_feet1" (6x18 octets/ligne, 108 octets de bitmap).
        ; Type(s) d'entite associe(s) via tbl_sprite_dispatch : 38.
        defb #06,#12,#00,#00,#00,#00,#11,#00,#00,#00,#00,#00,#76,#88,#00,#00
        defb #00,#11,#F8,#88,#00,#00,#00,#76,#F0,#00,#00,#00,#00,#F8,#F3,#00
        defb #00,#00,#11,#F0,#CC,#00,#00,#00,#00,#F9,#EA,#00,#00,#00,#00,#F8
        defb #EA,#00,#00,#00,#33,#F4,#C4,#00,#00,#00,#74,#F4,#E2,#00,#00,#00
        defb #74,#F8,#E2,#00,#00,#00,#75,#F0,#E2,#00,#00,#00,#32,#F0,#F5,#00
        defb #00,#00,#74,#F0,#F5,#00,#00,#00,#74,#F0,#F9,#00,#00,#00,#74,#F0
        defb #F0,#88,#00,#00,#74,#F0,#F0,#88,#00,#00,#32,#F0,#F0,#88,#00
sprite_werewulf_feet2_7A8A:
        ; Sprite "werewulf_feet2" (6x18 octets/ligne, 108 octets de bitmap).
        ; Type(s) d'entite associe(s) via tbl_sprite_dispatch : 39,3D.
        defb #06,#12,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00
        defb #00,#00,#88,#00,#00,#00,#00,#33,#C4,#88,#00,#00,#00,#FC,#F7,#C4
        defb #00,#00,#33,#F0,#F4,#C4,#00,#00,#74,#F0,#F8,#C4,#00,#00,#F8,#F3
        defb #F1,#88,#00,#00,#74,#FC,#E2,#00,#00,#00,#74,#F4,#C4,#00,#00,#00
        defb #32,#F2,#C4,#00,#00,#00,#32,#F1,#E2,#00,#00,#00,#11,#F1,#F1,#00
        defb #00,#00,#11,#F0,#F8,#88,#00,#00,#32,#F0,#F8,#88,#00,#00,#32,#F0
        defb #F0,#88,#00,#00,#32,#F0,#F0,#88,#00,#00,#32,#F0,#F0,#88,#00
sprite_werewulf_feet4_7AF9:
        ; Sprite "werewulf_feet4" (6x18 octets/ligne, 108 octets de bitmap).
        ; Type(s) d'entite associe(s) via tbl_sprite_dispatch : 3A,3C.
        defb #06,#12,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00
        defb #00,#00,#00,#00,#00,#00,#00,#22,#00,#22,#00,#00,#00,#FD,#11,#FD
        defb #00,#00,#33,#F1,#76,#F1,#00,#00,#FC,#F1,#F8,#F1,#00,#11,#F0,#F2
        defb #F0,#E6,#00,#32,#F0,#FE,#F1,#88,#00,#11,#F1,#99,#E2,#00,#00,#00
        defb #F8,#F7,#F1,#00,#00,#00,#76,#F1,#F0,#88,#00,#00,#11,#F0,#F8,#88
        defb #00,#00,#11,#F0,#F8,#C4,#00,#00,#32,#F0,#F8,#C4,#00,#00,#32,#F0
        defb #F0,#88,#00,#00,#32,#F0,#F0,#88,#00,#00,#32,#F0,#F0,#88,#00
sprite_werewulf_feet5_7B68:
        ; Sprite "werewulf_feet5" (6x18 octets/ligne, 108 octets de bitmap).
        ; Type(s) d'entite associe(s) via tbl_sprite_dispatch : 3B.
        defb #06,#12,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00
        defb #00,#00,#00,#00,#88,#00,#00,#00,#00,#33,#C4,#00,#11,#00,#00,#FC
        defb #C4,#00,#76,#88,#33,#F0,#C4,#11,#F8,#88,#74,#F1,#88,#32,#F0,#88
        defb #F8,#E6,#00,#74,#F3,#00,#74,#88,#00,#F8,#FF,#00,#32,#C4,#00,#F8
        defb #F0,#88,#32,#E2,#00,#74,#F0,#C4,#74,#E2,#00,#33,#F8,#E2,#F8,#E2
        defb #00,#00,#74,#F1,#F0,#E2,#00,#00,#74,#F1,#F0,#C4,#00,#00,#74,#F0
        defb #F0,#C4,#00,#00,#74,#F0,#F0,#88,#00,#00,#32,#F0,#F0,#88,#00
sprite_herse_7BD7:
        ; Sprite "herse" (6x42 octets/ligne, 252 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 08,09.
        defb #06,#2A,#00,#33,#00,#00,#00,#00,#00,#74,#88,#00,#00,#00,#00,#F8
        defb #88,#00,#00,#00,#00,#76,#C4,#CC,#00,#00,#00,#75,#99,#E2,#00,#00
        defb #00,#74,#BA,#E2,#00,#00,#00,#F8,#99,#F9,#33,#00,#00,#F8,#F7,#E6
        defb #74,#88,#00,#74,#F1,#E2,#F8,#88,#00,#74,#F8,#E2,#76,#C4,#CC,#74
        defb #FE,#F1,#FD,#99,#E2,#F8,#99,#F0,#F4,#BA,#E2,#F8,#F7,#F2,#F0,#99
        defb #F9,#74,#F1,#F3,#F8,#F7,#E6,#74,#F8,#E2,#74,#F1,#E2,#74,#FE,#F1
        defb #FC,#F8,#E2,#F8,#99,#F0,#F4,#FE,#F1,#F8,#F7,#F2,#F0,#99,#F1,#74
        defb #F1,#F3,#F8,#F7,#E2,#74,#F8,#E2,#74,#F1,#E2,#74,#FE,#F1,#FC,#F8
        defb #E2,#F8,#99,#F0,#F4,#FE,#F1,#F8,#F7,#F2,#F0,#99,#F1,#74,#F1,#F3
        defb #F8,#F7,#E2,#74,#F8,#E2,#74,#F1,#E2,#74,#FE,#F1,#FC,#F8,#E2,#F8
        defb #99,#F0,#F4,#FE,#F1,#F8,#F7,#F2,#F0,#99,#F1,#74,#F1,#F3,#F8,#F7
        defb #E2,#74,#F8,#E2,#74,#F1,#E2,#74,#FE,#F1,#FC,#F8,#E2,#74,#99,#F0
        defb #F4,#FE,#F1,#32,#11,#F2,#F0,#99,#F1,#11,#11,#F3,#F8,#F7,#E2,#00
        defb #00,#E2,#74,#F1,#E2,#00,#00,#E6,#74,#F8,#E2,#00,#00,#44,#74,#FE
        defb #F1,#00,#00,#00,#74,#99,#F1,#00,#00,#00,#32,#99,#E2,#00,#00,#00
        defb #11,#11,#E2,#00,#00,#00,#00,#00,#EA,#00,#00,#00,#00,#00,#88
sprite_table_7CD6:
        ; Sprite "table" (8x28 octets/ligne, 224 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 54.
        defb #08,#1C,#00,#00,#00,#00,#CC,#00,#00,#00,#00,#00,#00,#11,#E2,#00
        defb #00,#00,#00,#00,#00,#32,#EA,#00,#00,#00,#00,#00,#00,#32,#EA,#00
        defb #00,#00,#00,#00,#CC,#32,#EA,#00,#00,#00,#00,#11,#E2,#32,#EA,#00
        defb #00,#00,#00,#32,#EA,#32,#EA,#00,#00,#33,#00,#32,#EA,#32,#EA,#00
        defb #00,#74,#88,#32,#EA,#32,#EA,#00,#00,#75,#C4,#32,#EA,#33,#EA,#00
        defb #00,#75,#C4,#32,#EA,#67,#6E,#11,#88,#75,#C4,#32,#FB,#9F,#9F,#BA
        defb #C4,#75,#C4,#32,#EF,#6F,#6F,#7F,#C4,#75,#C4,#33,#9F,#8F,#1F,#9F
        defb #CC,#75,#C4,#67,#6F,#0F,#0F,#6F,#6E,#75,#C4,#9F,#8F,#0F,#0F,#1F
        defb #9F,#FD,#C4,#AF,#0F,#0F,#0F,#0F,#6F,#7F,#C4,#8F,#0F,#0F,#0F,#0F
        defb #1F,#9F,#CC,#67,#0F,#0F,#0F,#0F,#0F,#6F,#6E,#11,#8F,#0F,#0F,#0F
        defb #0F,#1F,#9F,#00,#67,#0F,#0F,#0F,#0F,#0F,#5F,#00,#11,#8F,#0F,#0F
        defb #0F,#0F,#1F,#00,#00,#67,#0F,#0F,#0F,#0F,#6E,#00,#00,#11,#8F,#0F
        defb #0F,#1F,#88,#00,#00,#00,#67,#0F,#0F,#6E,#00,#00,#00,#00,#11,#8F
        defb #1F,#88,#00,#00,#00,#00,#00,#67,#6E,#00,#00,#00,#00,#00,#00,#11
        defb #88,#00,#00
sprite_frog_statue_7DB9:
        ; Sprite "frog_statue" (6x24 octets/ligne, 144 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 16.
        defb #06,#18,#00,#00,#00,#11,#00,#00,#00,#00,#00,#76,#CC,#00,#00,#00
        defb #11,#F8,#F3,#00,#00,#00,#76,#F0,#F0,#CC,#00,#11,#F8,#F1,#F8,#F3
        defb #00,#76,#F0,#F6,#F6,#F0,#CC,#F8,#F1,#F9,#FF,#F8,#E2,#74,#F6,#E7
        defb #3F,#FE,#F1,#33,#F8,#8F,#4F,#7D,#EA,#11,#F1,#0F,#8F,#7C,#CC,#00
        defb #FB,#0F,#3F,#F9,#00,#00,#47,#CF,#1F,#E6,#00,#00,#8F,#2F,#1F,#CC
        defb #00,#00,#8F,#0F,#2F,#2E,#00,#00,#47,#0F,#8F,#9F,#00,#00,#33,#0F
        defb #3F,#5F,#00,#00,#00,#CF,#7F,#6F,#88,#00,#00,#47,#8F,#0F,#88,#00
        defb #00,#47,#0F,#1F,#00,#00,#00,#47,#CF,#2E,#00,#00,#00,#8F,#CF,#4C
        defb #00,#00,#00,#8F,#0F,#2E,#00,#00,#00,#9F,#EF,#2E,#00,#00,#00,#66
        defb #11,#CC,#00
sprite_conkers1_7E4C:
        ; Sprite "conkers1" (8x25 octets/ligne, 200 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 3F.
        defb #08,#19,#00,#00,#00,#00,#00,#88,#00,#00,#00,#00,#00,#00,#11,#C4
        defb #00,#00,#00,#00,#00,#00,#77,#E6,#22,#00,#00,#00,#00,#33,#8F,#1F
        defb #75,#00,#00,#00,#33,#75,#0F,#0F,#FB,#00,#00,#00,#74,#FE,#CF,#0F
        defb #EA,#00,#00,#00,#32,#9F,#E3,#1F,#D7,#00,#00,#00,#11,#1F,#E3,#0F
        defb #8F,#88,#00,#00,#11,#0F,#CF,#0F,#0F,#EE,#00,#00,#FF,#8F,#0F,#0F
        defb #3F,#F9,#00,#11,#F0,#C7,#0F,#0F,#7C,#E6,#00,#00,#FF,#8F,#3F,#0F
        defb #F9,#CC,#00,#00,#23,#0F,#7C,#0F,#6F,#7F,#00,#00,#23,#0F,#3F,#0F
        defb #0F,#78,#88,#00,#67,#0F,#0F,#0F,#0F,#7F,#00,#00,#F9,#0F,#0F,#0F
        defb #8F,#88,#00,#11,#F7,#3F,#0F,#1F,#C7,#88,#00,#00,#88,#FC,#8F,#0F
        defb #FB,#00,#00,#00,#00,#F9,#0F,#0F,#7D,#00,#00,#00,#11,#E7,#1F,#0F
        defb #7E,#88,#00,#00,#00,#99,#BE,#9F,#99,#00,#00,#00,#00,#11,#F6,#FE
        defb #88,#00,#00,#00,#00,#11,#F6,#99,#C4,#00,#00,#00,#00,#00,#BA,#88
        defb #88,#00,#00,#00,#00,#00,#11,#00,#00,#00,#00
sprite_volcanic_bubble2_7F17:
        ; Sprite "volcanic_bubble2" (6x19 octets/ligne, 114 octets de bitmap).
        ; Type(s) d'entite associe(s) via tbl_sprite_dispatch : B2,B6.
        defb #06,#13,#00,#00,#00,#33,#EE,#00,#00,#00,#00,#FC,#F1,#88,#00,#00
        defb #11,#F0,#F0,#C4,#00,#00,#32,#F0,#F0,#E2,#00,#00,#74,#F0,#F0,#F1
        defb #00,#00,#F8,#F0,#F0,#F0,#88,#00,#F8,#F0,#F0,#F0,#88,#11,#F0,#F0
        defb #F0,#F0,#C4,#11,#F0,#F0,#F0,#F0,#C4,#11,#F3,#F0,#F0,#F0,#C4,#11
        defb #F3,#F0,#F0,#F0,#C4,#11,#F3,#F8,#F0,#F0,#C4,#00,#F9,#FC,#F0,#F0
        defb #88,#00,#F8,#FE,#F0,#F0,#88,#00,#74,#F7,#F8,#F1,#00,#00,#32,#F3
        defb #F8,#E2,#00,#00,#11,#F0,#F0,#C4,#00,#00,#00,#FC,#F1,#88,#00,#00
        defb #00,#33,#EE,#00,#00
sprite_volcanic_bubble1_7F8C:
        ; Sprite "volcanic_bubble1" (6x18 octets/ligne, 108 octets de bitmap).
        ; Type(s) d'entite associe(s) via tbl_sprite_dispatch : B3,B7.
        defb #06,#12,#00,#00,#00,#33,#EE,#00,#00,#00,#11,#FC,#F1,#CC,#00,#00
        defb #32,#F0,#F0,#E2,#00,#00,#74,#F0,#F0,#F1,#00,#00,#F8,#F0,#F0,#F0
        defb #88,#11,#F0,#F0,#F0,#F0,#C4,#11,#F0,#F0,#F0,#F0,#C4,#32,#F0,#F0
        defb #F0,#F0,#E2,#32,#F6,#F0,#F0,#F0,#E2,#32,#F6,#F0,#F0,#F0,#E2,#32
        defb #F3,#F0,#F0,#F0,#E2,#11,#F3,#F8,#F0,#F0,#C4,#11,#F1,#FC,#F0,#F0
        defb #C4,#00,#F8,#FF,#F8,#F0,#88,#00,#74,#F3,#F8,#F1,#00,#00,#32,#F0
        defb #F0,#E2,#00,#00,#11,#FC,#F1,#CC,#00,#00,#00,#33,#EE,#00,#00
        ; non désassemblé
        defb #00,#00,#00,#00,#00,#6E,#47,#0F,#5F,#88,#23,#1F,#CF,#0F,#4F,#4C
        defb #23,#0F,#4F,#0F,#4F,#4C,#11,#0F,#4F,#0F,#4F,#4C,#11,#0F,#6F,#0F
        defb #4F,#4C,#77,#0F,#5F,#8F,#6F,#4C,#9F,#8F,#4F,#6F,#5D,#88,#8F,#6F
        defb #4F,#1F,#CC,#00,#8F,#1F,#CF,#0F,#6E,#00,#47,#0F,#6F,#0F,#1F,#88
        defb #33,#0F,#1F,#8F,#0F,#6E,#00,#CF,#0F,#6F,#0F,#1F,#00,#33,#0F,#2F
        defb #0F,#1F,#00,#00,#CF,#2F,#0F,#1F,#00,#00,#33,#3F,#8F,#1F,#00,#00
        defb #00,#CC,#67,#2E,#00,#00,#00,#00,#11,#CC,#06,#12,#00,#44,#00,#00
        defb #00,#00,#00,#BF,#00,#00,#00,#00,#00,#8F,#CC,#00,#00,#00,#00,#8F
        defb #3F,#00,#00,#00,#00,#8F,#0F,#CC,#33,#00,#00,#8F,#0F,#3F,#47,#CC
        defb #00,#47,#CF,#0F,#CF,#3F,#00,#23,#BF,#0F,#4F,#0F,#CC,#11,#8F,#CF
        defb #4F,#0F,#2E,#00,#8F,#3F,#4F,#0F,#1F,#00,#8F,#0F,#CF,#0F,#1F,#00
        defb #67,#0F,#3F,#0F,#1F,#00,#11,#8F,#0F,#CF,#1F,#00,#00,#67,#0F,#3F
        defb #1F,#00,#00,#11,#8F,#1F,#DF,#00,#00,#00,#67,#1F,#22,#00,#00,#00
        defb #11,#9F,#00,#00,#00,#00,#00,#66,#00,#04,#30,#A7,#00,#41,#00,#00
        defb #00,#1C,#70,#A7,#00,#A7,#00,#41,#00,#00,#00,#A3,#98,#A7,#00,#41
        defb #00,#00,#00,#08,#08,#C0,#16,#00,#03,#06,#17,#7D,#17,#89,#16,#00
        defb #03,#F1,#15,#90,#05,#00,#11,#22,#33,#44,#55,#66,#77,#88,#99,#AA
        defb #BB,#CC,#DD,#EE,#FF,#11,#00,#33,#22,#55,#44,#77,#66,#99,#88,#BB
        defb #AA,#DD,#CC,#FF,#EE,#22,#33,#00,#11,#66,#77,#44,#55,#AA,#BB,#88
        defb #99,#EE,#FF,#CC,#DD,#33,#22,#11,#00,#77,#66,#55,#44,#BB,#AA,#99
        defb #88,#FF,#EE,#DD,#CC,#44,#55,#66,#77,#00,#11,#22,#33,#CC,#DD,#EE
        defb #FF,#88,#99,#AA,#BB,#55,#44,#77,#66,#11,#00,#33,#22,#DD,#CC,#FF
        defb #EE,#99,#88,#BB,#AA,#66,#77,#44,#55,#22,#33,#00,#11,#EE,#FF,#CC
        defb #DD,#AA,#BB,#88,#99,#77,#66,#55,#44,#33,#22,#11,#00,#FF,#EE,#DD
        defb #CC,#BB,#AA,#99,#88,#88,#99,#AA,#BB,#CC,#DD,#EE,#FF,#00,#11,#22
        defb #33,#44,#55,#66,#77,#99,#88,#BB,#AA,#DD,#CC,#FF,#EE,#11,#00,#33
        defb #22,#55,#44,#77,#66,#AA,#BB,#88,#99,#EE,#FF,#CC,#DD,#22,#33,#00
        defb #11,#66,#77,#44,#55,#BB,#AA,#99,#88,#FF,#EE,#DD,#CC,#33,#22,#11
        defb #00,#77,#66,#55,#44,#CC,#DD,#EE,#FF,#88,#99,#AA,#BB,#44,#55,#66
        defb #77,#00,#11,#22,#33,#DD,#CC,#FF,#EE,#99,#88,#BB,#AA,#55,#44,#77
        defb #66,#11,#00,#33,#22,#EE,#FF,#CC,#DD,#AA,#BB,#88,#99,#66,#77,#44
        defb #55,#22,#33,#00,#11,#FF,#EE,#DD,#CC,#BB,#AA,#99,#88,#77,#66,#55
        defb #44,#33,#22,#11,#00,#FF,#EE,#DD,#CC,#BB,#AA,#99,#88,#77,#66,#55
        defb #44,#33,#22,#11,#00,#EE,#EE,#CC,#CC,#AA,#AA,#88,#88,#66,#66,#44
        defb #44,#22,#22,#00,#00,#DD,#CC,#DD,#CC,#99,#88,#99,#88,#55,#44,#55
        defb #44,#11,#00,#11,#00,#CC,#CC,#CC,#CC,#88,#88,#88,#88,#44,#44,#44
        defb #44,#00,#00,#00,#00,#BB,#AA,#99,#88,#BB,#AA,#99,#88,#33,#22,#11
        defb #00,#33,#22,#11,#00,#AA,#AA,#88,#88,#AA,#AA,#88,#88,#22,#22,#00
        defb #00,#22,#22,#00,#00,#99,#88,#99,#88,#99,#88,#99,#88,#11,#00,#11
        defb #00,#11,#00,#11,#00,#88,#88,#88,#88,#88,#88,#88,#88,#00,#00,#00
        defb #00,#00,#00,#00,#00,#77,#66,#55,#44,#33,#22,#11,#00,#77,#66,#55
        defb #44,#33,#22,#11,#00,#66,#66,#44,#44,#22,#22,#00,#00,#66,#66,#44
        defb #44,#22,#22,#00,#00,#55,#44,#55,#44,#11,#00,#11,#00,#55,#44,#55
        defb #44,#11,#00,#11,#00,#44,#44,#44,#44,#00,#00,#00,#00,#44,#44,#44
        defb #44,#00,#00,#00,#00,#33,#22,#11,#00,#33,#22,#11,#00,#33,#22,#11
        defb #00,#33,#22,#11,#00,#22,#22,#00,#00,#22,#22,#00,#00,#22,#22,#00
        defb #00,#22,#22,#00,#00,#11,#00,#11,#00,#11,#00,#11,#00,#11,#00,#11
        defb #00,#11,#00,#11,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00
        defb #00,#00,#00,#00,#00,#00,#10,#20,#30,#40,#50,#60,#70,#80,#90,#A0
        defb #B0,#C0,#D0,#E0,#F0,#01,#00,#21,#20,#41,#40,#61,#60,#81,#80,#A1
        defb #A0,#C1,#C0,#E1,#E0,#02,#12,#00,#10,#42,#52,#40,#50,#82,#92,#80
        defb #90,#C2,#D2,#C0,#D0,#03,#02,#01,#00,#43,#42,#41,#40,#83,#82,#81
        defb #80,#C3,#C2,#C1,#C0,#04,#14,#24,#34,#00,#10,#20,#30,#84,#94,#A4
        defb #B4,#80,#90,#A0,#B0,#05,#04,#25,#24,#01,#00,#21,#20,#85,#84,#A5
        defb #A4,#81,#80,#A1,#A0,#06,#16,#04,#14,#02,#12,#00,#10,#86,#96,#84
        defb #94,#82,#92,#80,#90,#07,#06,#05,#04,#03,#02,#01,#00,#87,#86,#85
        defb #84,#83,#82,#81,#80,#08,#18,#28,#38,#48,#58,#68,#78,#00,#10,#20
        defb #30,#40,#50,#60,#70,#09,#08,#29,#28,#49,#48,#69,#68,#01,#00,#21
        defb #20,#41,#40,#61,#60,#0A,#1A,#08,#18,#4A,#5A,#48,#58,#02,#12,#00
        defb #10,#42,#52,#40,#50,#0B,#0A,#09,#08,#4B,#4A,#49,#48,#03,#02,#01
        defb #00,#43,#42,#41,#40,#0C,#1C,#2C,#3C,#08,#18,#28,#38,#04,#14,#24
        defb #34,#00,#10,#20,#30,#0D,#0C,#2D,#2C,#09,#08,#29,#28,#05,#04,#25
        defb #24,#01,#00,#21,#20,#0E,#1E,#0C,#1C,#0A,#1A,#08,#18,#06,#16,#04
        defb #14,#02,#12,#00,#10,#0F,#0E,#0D,#0C,#0B,#0A,#09,#08,#07,#06,#05
        defb #04,#03,#02,#01,#00,#FF,#FF,#EE,#EE,#DD,#DD,#CC,#CC,#BB,#BB,#AA
        defb #AA,#99,#99,#88,#88,#FF,#FF,#EE,#EE,#DD,#DD,#CC,#CC,#BB,#BB,#AA
        defb #AA,#99,#99,#88,#88,#EE,#EE,#EE,#EE,#CC,#CC,#CC,#CC,#AA,#AA,#AA
        defb #AA,#88,#88,#88,#88,#EE,#EE,#EE,#EE,#CC,#CC,#CC,#CC,#AA,#AA,#AA
        defb #AA,#88,#88,#88,#88,#DD,#DD,#CC,#CC,#DD,#DD,#CC,#CC,#99,#99,#88
        defb #88,#99,#99,#88,#88,#DD,#DD,#CC,#CC,#DD,#DD,#CC,#CC,#99,#99,#88
        defb #88,#99,#99,#88,#88,#CC,#CC,#CC,#CC,#CC,#CC,#CC,#CC,#88,#88,#88
        defb #88,#88,#88,#88,#88,#CC,#CC,#CC,#CC,#CC,#CC,#CC,#CC,#88,#88,#88
        defb #88,#88,#88,#88,#88,#BB,#BB,#AA,#AA,#99,#99,#88,#88,#BB,#BB,#AA
        defb #AA,#99,#99,#88,#88,#BB,#BB,#AA,#AA,#99,#99,#88,#88,#BB,#BB,#AA
        defb #AA,#99,#99,#88,#88,#AA,#AA,#AA,#AA,#88,#88,#88,#88,#AA,#AA,#AA
        defb #AA,#88,#88,#88,#88,#AA,#AA,#AA,#AA,#88,#88,#88,#88,#AA,#AA,#AA
        defb #AA,#88,#88,#88,#88,#99,#99,#88,#88,#99,#99,#88,#88,#99,#99,#88
        defb #88,#99,#99,#88,#88,#99,#99,#88,#88,#99,#99,#88,#88,#99,#99,#88
        defb #88,#99,#99,#88,#88,#88,#88,#88,#88,#88,#88,#88,#88,#88,#88,#88
        defb #88,#88,#88,#88,#88,#88,#88,#88,#88,#88,#88,#88,#88,#88,#88,#88
        defb #88,#88,#88,#88,#88,#00,#00,#10,#10,#20,#20,#30,#30,#40,#40,#50
        defb #50,#60,#60,#70,#70,#00,#00,#10,#10,#20,#20,#30,#30,#40,#40,#50
        defb #50,#60,#60,#70,#70,#01,#01,#00,#00,#21,#21,#20,#20,#41,#41,#40
        defb #40,#61,#61,#60,#60,#01,#01,#00,#00,#21,#21,#20,#20,#41,#41,#40
        defb #40,#61,#61,#60,#60,#02,#02,#12,#12,#00,#00,#10,#10,#42,#42,#52
        defb #52,#40,#40,#50,#50,#02,#02,#12,#12,#00,#00,#10,#10,#42,#42,#52
        defb #52,#40,#40,#50,#50,#03,#03,#02,#02,#01,#01,#00,#00,#43,#43,#42
        defb #42,#41,#41,#40,#40,#03,#03,#02,#02,#01,#01,#00,#00,#43,#43,#42
        defb #42,#41,#41,#40,#40,#04,#04,#14,#14,#24,#24,#34,#34,#00,#00,#10
        defb #10,#20,#20,#30,#30,#04,#04,#14,#14,#24,#24,#34,#34,#00,#00,#10
        defb #10,#20,#20,#30,#30,#05,#05,#04,#04,#25,#25,#24,#24,#01,#01,#00
        defb #00,#21,#21,#20,#20,#05,#05,#04,#04,#25,#25,#24,#24,#01,#01,#00
        defb #00,#21,#21,#20,#20,#06,#06,#16,#16,#04,#04,#14,#14,#02,#02,#12
        defb #12,#00,#00,#10,#10,#06,#06,#16,#16,#04,#04,#14,#14,#02,#02,#12
        defb #12,#00,#00,#10,#10,#07,#07,#06,#06,#05,#05,#04,#04,#03,#03,#02
        defb #02,#01,#01,#00,#00,#07,#07,#06,#06,#05,#05,#04,#04,#03,#03,#02
        defb #02,#01,#01,#00,#00,#FF,#77,#FF,#77,#FF,#77,#FF,#77,#FF,#77,#FF
        defb #77,#FF,#77,#FF,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
        defb #77,#77,#77,#77,#77,#FF,#77,#FF,#77,#FF,#77,#FF,#77,#FF,#77,#FF
        defb #77,#FF,#77,#FF,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
        defb #77,#77,#77,#77,#77,#FF,#77,#FF,#77,#FF,#77,#FF,#77,#FF,#77,#FF
        defb #77,#FF,#77,#FF,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
        defb #77,#77,#77,#77,#77,#FF,#77,#FF,#77,#FF,#77,#FF,#77,#FF,#77,#FF
        defb #77,#FF,#77,#FF,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
        defb #77,#77,#77,#77,#77,#FF,#77,#FF,#77,#FF,#77,#FF,#77,#FF,#77,#FF
        defb #77,#FF,#77,#FF,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
        defb #77,#77,#77,#77,#77,#FF,#77,#FF,#77,#FF,#77,#FF,#77,#FF,#77,#FF
        defb #77,#FF,#77,#FF,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
        defb #77,#77,#77,#77,#77,#FF,#77,#FF,#77,#FF,#77,#FF,#77,#FF,#77,#FF
        defb #77,#FF,#77,#FF,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
        defb #77,#77,#77,#77,#77,#FF,#77,#FF,#77,#FF,#77,#FF,#77,#FF,#77,#FF
        defb #77,#FF,#77,#FF,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77,#77
        defb #77,#77,#77,#77,#77,#00,#80,#00,#80,#00,#80,#00,#80,#00,#80,#00
        defb #80,#00,#80,#00,#80,#08,#00,#08,#00,#08,#00,#08,#00,#08,#00,#08
        defb #00,#08,#00,#08,#00,#00,#80,#00,#80,#00,#80,#00,#80,#00,#80,#00
        defb #80,#00,#80,#00,#80,#08,#00,#08,#00,#08,#00,#08,#00,#08,#00,#08
        defb #00,#08,#00,#08,#00,#00,#80,#00,#80,#00,#80,#00,#80,#00,#80,#00
        defb #80,#00,#80,#00,#80,#08,#00,#08,#00,#08,#00,#08,#00,#08,#00,#08
        defb #00,#08,#00,#08,#00,#00,#80,#00,#80,#00,#80,#00,#80,#00,#80,#00
        defb #80,#00,#80,#00,#80,#08,#00,#08,#00,#08,#00,#08,#00,#08,#00,#08
        defb #00,#08,#00,#08,#00,#00,#80,#00,#80,#00,#80,#00,#80,#00,#80,#00
        defb #80,#00,#80,#00,#80,#08,#00,#08,#00,#08,#00,#08,#00,#08,#00,#08
        defb #00,#08,#00,#08,#00,#00,#80,#00,#80,#00,#80,#00,#80,#00,#80,#00
        defb #80,#00,#80,#00,#80,#08,#00,#08,#00,#08,#00,#08,#00,#08,#00,#08
        defb #00,#08,#00,#08,#00,#00,#80,#00,#80,#00,#80,#00,#80,#00,#80,#00
        defb #80,#00,#80,#00,#80,#08,#00,#08,#00,#08,#00,#08,#00,#08,#00,#08
        defb #00,#08,#00,#08,#00,#00,#80,#00,#80,#00,#80,#00,#80,#00,#80,#00
        defb #80,#00,#80,#00,#80,#08,#00,#08,#00,#08,#00,#08,#00,#08,#00,#08
        defb #00,#08,#00,#08,#00,#FF,#FF,#FF,#FF,#EE,#EE,#EE,#EE,#DD,#DD,#DD
        defb #DD,#CC,#CC,#CC,#CC,#FF,#FF,#FF,#FF,#EE,#EE,#EE,#EE,#DD,#DD,#DD
        defb #DD,#CC,#CC,#CC,#CC,#FF,#FF,#FF,#FF,#EE,#EE,#EE,#EE,#DD,#DD,#DD
        defb #DD,#CC,#CC,#CC,#CC,#FF,#FF,#FF,#FF,#EE,#EE,#EE,#EE,#DD,#DD,#DD
        defb #DD,#CC,#CC,#CC,#CC,#EE,#EE,#EE,#EE,#EE,#EE,#EE,#EE,#CC,#CC,#CC
        defb #CC,#CC,#CC,#CC,#CC,#EE,#EE,#EE,#EE,#EE,#EE,#EE,#EE,#CC,#CC,#CC
        defb #CC,#CC,#CC,#CC,#CC,#EE,#EE,#EE,#EE,#EE,#EE,#EE,#EE,#CC,#CC,#CC
        defb #CC,#CC,#CC,#CC,#CC,#EE,#EE,#EE,#EE,#EE,#EE,#EE,#EE,#CC,#CC,#CC
        defb #CC,#CC,#CC,#CC,#CC,#DD,#DD,#DD,#DD,#CC,#CC,#CC,#CC,#DD,#DD,#DD
        defb #DD,#CC,#CC,#CC,#CC,#DD,#DD,#DD,#DD,#CC,#CC,#CC,#CC,#DD,#DD,#DD
        defb #DD,#CC,#CC,#CC,#CC,#DD,#DD,#DD,#DD,#CC,#CC,#CC,#CC,#DD,#DD,#DD
        defb #DD,#CC,#CC,#CC,#CC,#DD,#DD,#DD,#DD,#CC,#CC,#CC,#CC,#DD,#DD,#DD
        defb #DD,#CC,#CC,#CC,#CC,#CC,#CC,#CC,#CC,#CC,#CC,#CC,#CC,#CC,#CC,#CC
        defb #CC,#CC,#CC,#CC,#CC,#CC,#CC,#CC,#CC,#CC,#CC,#CC,#CC,#CC,#CC,#CC
        defb #CC,#CC,#CC,#CC,#CC,#CC,#CC,#CC,#CC,#CC,#CC,#CC,#CC,#CC,#CC,#CC
        defb #CC,#CC,#CC,#CC,#CC,#CC,#CC,#CC,#CC,#CC,#CC,#CC,#CC,#CC,#CC,#CC
        defb #CC,#CC,#CC,#CC,#CC,#00,#00,#00,#00,#10,#10,#10,#10,#20,#20,#20
        defb #20,#30,#30,#30,#30,#00,#00,#00,#00,#10,#10,#10,#10,#20,#20,#20
        defb #20,#30,#30,#30,#30,#00,#00,#00,#00,#10,#10,#10,#10,#20,#20,#20
        defb #20,#30,#30,#30,#30,#00,#00,#00,#00,#10,#10,#10,#10,#20,#20,#20
        defb #20,#30,#30,#30,#30,#01,#01,#01,#01,#00,#00,#00,#00,#21,#21,#21
        defb #21,#20,#20,#20,#20,#01,#01,#01,#01,#00,#00,#00,#00,#21,#21,#21
        defb #21,#20,#20,#20,#20,#01,#01,#01,#01,#00,#00,#00,#00,#21,#21,#21
        defb #21,#20,#20,#20,#20,#01,#01,#01,#01,#00,#00,#00,#00,#21,#21,#21
        defb #21,#20,#20,#20,#20,#02,#02,#02,#02,#12,#12,#12,#12,#00,#00,#00
        defb #00,#10,#10,#10,#10,#02,#02,#02,#02,#12,#12,#12,#12,#00,#00,#00
        defb #00,#10,#10,#10,#10,#02,#02,#02,#02,#12,#12,#12,#12,#00,#00,#00
        defb #00,#10,#10,#10,#10,#02,#02,#02,#02,#12,#12,#12,#12,#00,#00,#00
        defb #00,#10,#10,#10,#10,#03,#03,#03,#03,#02,#02,#02,#02,#01,#01,#01
        defb #01,#00,#00,#00,#00,#03,#03,#03,#03,#02,#02,#02,#02,#01,#01,#01
        defb #01,#00,#00,#00,#00,#03,#03,#03,#03,#02,#02,#02,#02,#01,#01,#01
        defb #01,#00,#00,#00,#00,#03,#03,#03,#03,#02,#02,#02,#02,#01,#01,#01
        defb #01,#00,#00,#00,#00,#FF,#BB,#77,#33,#FF,#BB,#77,#33,#FF,#BB,#77
        defb #33,#FF,#BB,#77,#33,#BB,#BB,#33,#33,#BB,#BB,#33,#33,#BB,#BB,#33
        defb #33,#BB,#BB,#33,#33,#77,#33,#77,#33,#77,#33,#77,#33,#77,#33,#77
        defb #33,#77,#33,#77,#33,#33,#33,#33,#33,#33,#33,#33,#33,#33,#33,#33
        defb #33,#33,#33,#33,#33,#FF,#BB,#77,#33,#FF,#BB,#77,#33,#FF,#BB,#77
        defb #33,#FF,#BB,#77,#33,#BB,#BB,#33,#33,#BB,#BB,#33,#33,#BB,#BB,#33
        defb #33,#BB,#BB,#33,#33,#77,#33,#77,#33,#77,#33,#77,#33,#77,#33,#77
        defb #33,#77,#33,#77,#33,#33,#33,#33,#33,#33,#33,#33,#33,#33,#33,#33
        defb #33,#33,#33,#33,#33,#FF,#BB,#77,#33,#FF,#BB,#77,#33,#FF,#BB,#77
        defb #33,#FF,#BB,#77,#33,#BB,#BB,#33,#33,#BB,#BB,#33,#33,#BB,#BB,#33
        defb #33,#BB,#BB,#33,#33,#77,#33,#77,#33,#77,#33,#77,#33,#77,#33,#77
        defb #33,#77,#33,#77,#33,#33,#33,#33,#33,#33,#33,#33,#33,#33,#33,#33
        defb #33,#33,#33,#33,#33,#FF,#BB,#77,#33,#FF,#BB,#77,#33,#FF,#BB,#77
        defb #33,#FF,#BB,#77,#33,#BB,#BB,#33,#33,#BB,#BB,#33,#33,#BB,#BB,#33
        defb #33,#BB,#BB,#33,#33,#77,#33,#77,#33,#77,#33,#77,#33,#77,#33,#77
        defb #33,#77,#33,#77,#33,#33,#33,#33,#33,#33,#33,#33,#33,#33,#33,#33
        defb #33,#33,#33,#33,#33,#00,#40,#80,#C0,#00,#40,#80,#C0,#00,#40,#80
        defb #C0,#00,#40,#80,#C0,#04,#00,#84,#80,#04,#00,#84,#80,#04,#00,#84
        defb #80,#04,#00,#84,#80,#08,#48,#00,#40,#08,#48,#00,#40,#08,#48,#00
        defb #40,#08,#48,#00,#40,#0C,#08,#04,#00,#0C,#08,#04,#00,#0C,#08,#04
        defb #00,#0C,#08,#04,#00,#00,#40,#80,#C0,#00,#40,#80,#C0,#00,#40,#80
        defb #C0,#00,#40,#80,#C0,#04,#00,#84,#80,#04,#00,#84,#80,#04,#00,#84
        defb #80,#04,#00,#84,#80,#08,#48,#00,#40,#08,#48,#00,#40,#08,#48,#00
        defb #40,#08,#48,#00,#40,#0C,#08,#04,#00,#0C,#08,#04,#00,#0C,#08,#04
        defb #00,#0C,#08,#04,#00,#00,#40,#80,#C0,#00,#40,#80,#C0,#00,#40,#80
        defb #C0,#00,#40,#80,#C0,#04,#00,#84,#80,#04,#00,#84,#80,#04,#00,#84
        defb #80,#04,#00,#84,#80,#08,#48,#00,#40,#08,#48,#00,#40,#08,#48,#00
        defb #40,#08,#48,#00,#40,#0C,#08,#04,#00,#0C,#08,#04,#00,#0C,#08,#04
        defb #00,#0C,#08,#04,#00,#00,#40,#80,#C0,#00,#40,#80,#C0,#00,#40,#80
        defb #C0,#00,#40,#80,#C0,#04,#00,#84,#80,#04,#00,#84,#80,#04,#00,#84
        defb #80,#04,#00,#84,#80,#08,#48,#00,#40,#08,#48,#00,#40,#08,#48,#00
        defb #40,#08,#48,#00,#40,#0C,#08,#04,#00,#0C,#08,#04,#00,#0C,#08,#04
        defb #00,#0C,#08,#04,#00,#FF,#FF,#FF,#FF,#FF,#FF,#FF,#FF,#EE,#EE,#EE
        defb #EE,#EE,#EE,#EE,#EE,#FF,#FF,#FF,#FF,#FF,#FF,#FF,#FF,#EE,#EE,#EE
        defb #EE,#EE,#EE,#EE,#EE,#FF,#FF,#FF,#FF,#FF,#FF,#FF,#FF,#EE,#EE,#EE
        defb #EE,#EE,#EE,#EE,#EE,#FF,#FF,#FF,#FF,#FF,#FF,#FF,#FF,#EE,#EE,#EE
        defb #EE,#EE,#EE,#EE,#EE,#FF,#FF,#FF,#FF,#FF,#FF,#FF,#FF,#EE,#EE,#EE
        defb #EE,#EE,#EE,#EE,#EE,#FF,#FF,#FF,#FF,#FF,#FF,#FF,#FF,#EE,#EE,#EE
        defb #EE,#EE,#EE,#EE,#EE,#FF,#FF,#FF,#FF,#FF,#FF,#FF,#FF,#EE,#EE,#EE
        defb #EE,#EE,#EE,#EE,#EE,#FF,#FF,#FF,#FF,#FF,#FF,#FF,#FF,#EE,#EE,#EE
        defb #EE,#EE,#EE,#EE,#EE,#EE,#EE,#EE,#EE,#EE,#EE,#EE,#EE,#EE,#EE,#EE
        defb #EE,#EE,#EE,#EE,#EE,#EE,#EE,#EE,#EE,#EE,#EE,#EE,#EE,#EE,#EE,#EE
        defb #EE,#EE,#EE,#EE,#EE,#EE,#EE,#EE,#EE,#EE,#EE,#EE,#EE,#EE,#EE,#EE
        defb #EE,#EE,#EE,#EE,#EE,#EE,#EE,#EE,#EE,#EE,#EE,#EE,#EE,#EE,#EE,#EE
        defb #EE,#EE,#EE,#EE,#EE,#EE,#EE,#EE,#EE,#EE,#EE,#EE,#EE,#EE,#EE,#EE
        defb #EE,#EE,#EE,#EE,#EE,#EE,#EE,#EE,#EE,#EE,#EE,#EE,#EE,#EE,#EE,#EE
        defb #EE,#EE,#EE,#EE,#EE,#EE,#EE,#EE,#EE,#EE,#EE,#EE,#EE,#EE,#EE,#EE
        defb #EE,#EE,#EE,#EE,#EE,#EE,#EE,#EE,#EE,#EE,#EE,#EE,#EE,#EE,#EE,#EE
        defb #EE,#EE,#EE,#EE,#EE,#00,#00,#00,#00,#00,#00,#00,#00,#10,#10,#10
        defb #10,#10,#10,#10,#10,#00,#00,#00,#00,#00,#00,#00,#00,#10,#10,#10
        defb #10,#10,#10,#10,#10,#00,#00,#00,#00,#00,#00,#00,#00,#10,#10,#10
        defb #10,#10,#10,#10,#10,#00,#00,#00,#00,#00,#00,#00,#00,#10,#10,#10
        defb #10,#10,#10,#10,#10,#00,#00,#00,#00,#00,#00,#00,#00,#10,#10,#10
        defb #10,#10,#10,#10,#10,#00,#00,#00,#00,#00,#00,#00,#00,#10,#10,#10
        defb #10,#10,#10,#10,#10,#00,#00,#00,#00,#00,#00,#00,#00,#10,#10,#10
        defb #10,#10,#10,#10,#10,#00,#00,#00,#00,#00,#00,#00,#00,#10,#10,#10
        defb #10,#10,#10,#10,#10,#01,#01,#01,#01,#01,#01,#01,#01,#00,#00,#00
        defb #00,#00,#00,#00,#00,#01,#01,#01,#01,#01,#01,#01,#01,#00,#00,#00
        defb #00,#00,#00,#00,#00,#01,#01,#01,#01,#01,#01,#01,#01,#00,#00,#00
        defb #00,#00,#00,#00,#00,#01,#01,#01,#01,#01,#01,#01,#01,#00,#00,#00
        defb #00,#00,#00,#00,#00,#01,#01,#01,#01,#01,#01,#01,#01,#00,#00,#00
        defb #00,#00,#00,#00,#00,#01,#01,#01,#01,#01,#01,#01,#01,#00,#00,#00
        defb #00,#00,#00,#00,#00,#01,#01,#01,#01,#01,#01,#01,#01,#00,#00,#00
        defb #00,#00,#00,#00,#00,#01,#01,#01,#01,#01,#01,#01,#01,#00,#00,#00
        defb #00,#00,#00,#00,#00,#FF,#DD,#BB,#99,#77,#55,#33,#11,#FF,#DD,#BB
        defb #99,#77,#55,#33,#11,#DD,#DD,#99,#99,#55,#55,#11,#11,#DD,#DD,#99
        defb #99,#55,#55,#11,#11,#BB,#99,#BB,#99,#33,#11,#33,#11,#BB,#99,#BB
        defb #99,#33,#11,#33,#11,#99,#99,#99,#99,#11,#11,#11,#11,#99,#99,#99
        defb #99,#11,#11,#11,#11,#77,#55,#33,#11,#77,#55,#33,#11,#77,#55,#33
        defb #11,#77,#55,#33,#11,#55,#55,#11,#11,#55,#55,#11,#11,#55,#55,#11
        defb #11,#55,#55,#11,#11,#33,#11,#33,#11,#33,#11,#33,#11,#33,#11,#33
        defb #11,#33,#11,#33,#11,#11,#11,#11,#11,#11,#11,#11,#11,#11,#11,#11
        defb #11,#11,#11,#11,#11,#FF,#DD,#BB,#99,#77,#55,#33,#11,#FF,#DD,#BB
        defb #99,#77,#55,#33,#11,#DD,#DD,#99,#99,#55,#55,#11,#11,#DD,#DD,#99
        defb #99,#55,#55,#11,#11,#BB,#99,#BB,#99,#33,#11,#33,#11,#BB,#99,#BB
        defb #99,#33,#11,#33,#11,#99,#99,#99,#99,#11,#11,#11,#11,#99,#99,#99
        defb #99,#11,#11,#11,#11,#77,#55,#33,#11,#77,#55,#33,#11,#77,#55,#33
        defb #11,#77,#55,#33,#11,#55,#55,#11,#11,#55,#55,#11,#11,#55,#55,#11
        defb #11,#55,#55,#11,#11,#33,#11,#33,#11,#33,#11,#33,#11,#33,#11,#33
        defb #11,#33,#11,#33,#11,#11,#11,#11,#11,#11,#11,#11,#11,#11,#11,#11
        defb #11,#11,#11,#11,#11,#00,#20,#40,#60,#80,#A0,#C0,#E0,#00,#20,#40
        defb #60,#80,#A0,#C0,#E0,#02,#00,#42,#40,#82,#80,#C2,#C0,#02,#00,#42
        defb #40,#82,#80,#C2,#C0,#04,#24,#00,#20,#84,#A4,#80,#A0,#04,#24,#00
        defb #20,#84,#A4,#80,#A0,#06,#04,#02,#00,#86,#84,#82,#80,#06,#04,#02
        defb #00,#86,#84,#82,#80,#08,#28,#48,#68,#00,#20,#40,#60,#08,#28,#48
        defb #68,#00,#20,#40,#60,#0A,#08,#4A,#48,#02,#00,#42,#40,#0A,#08,#4A
        defb #48,#02,#00,#42,#40,#0C,#2C,#08,#28,#04,#24,#00,#20,#0C,#2C,#08
        defb #28,#04,#24,#00,#20,#0E,#0C,#0A,#08,#06,#04,#02,#00,#0E,#0C,#0A
        defb #08,#06,#04,#02,#00,#00,#20,#40,#60,#80,#A0,#C0,#E0,#00,#20,#40
        defb #60,#80,#A0,#C0,#E0,#02,#00,#42,#40,#82,#80,#C2,#C0,#02,#00,#42
        defb #40,#82,#80,#C2,#C0,#04,#24,#00,#20,#84,#A4,#80,#A0,#04,#24,#00
        defb #20,#84,#A4,#80,#A0,#06,#04,#02,#00,#86,#84,#82,#80,#06,#04,#02
        defb #00,#86,#84,#82,#80,#08,#28,#48,#68,#00,#20,#40,#60,#08,#28,#48
        defb #68,#00,#20,#40,#60,#0A,#08,#4A,#48,#02,#00,#42,#40,#0A,#08,#4A
        defb #48,#02,#00,#42,#40,#0C,#2C,#08,#28,#04,#24,#00,#20,#0C,#2C,#08
        defb #28,#04,#24,#00,#20,#0E,#0C,#0A,#08,#06,#04,#02,#00,#0E,#0C,#0A
        defb #08,#06,#04,#02,#00
