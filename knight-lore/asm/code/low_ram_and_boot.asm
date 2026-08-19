; ============================================================
; low_ram_and_boot.asm -- genere par tools/gen_asm.py, plage #0000-#0676
; Genere mecaniquement depuis la RAM live + asm/symbols.json.
; Ne pas editer les blocs de code a la main : relancer le generateur.
; ============================================================
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
loc_05A2:
        call    fn_init_room_entities
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
        ; [vram-direct 2026-08-19] fn_mark_closure_then_cull a ete branchee
        ; ici puis DEBRANCHEE : mesure en jeu, la fermeture du marquage
        ; cascade jusqu'a toute la scene des qu'un rectangle sale existe
        ; (les blocs de decor se touchent tous, la fermeture transitive est
        ; donc la salle entiere). Voir code/vram_direct_rendering.asm.
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
loc_0628:
        dec    hl
        ld    a,l
        or    h
        jr    nz,loc_0628
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
        jr    z,loc_0654
        call    #180B
        call    fn_hud_decor_calibration
        ld    ix,var_day_night_flag
        call    #1C51
        call    fn_hud_render_minifont_message
        call    fn_hud_render_day_counter
        call    fn_hud_render_secondary_counter
        call    fn_vram_merge_buffer_to_screen
        call    fn_gate_array_palette_cycle
        call    fn_reset_all_entity_processing_flag
loc_0654:
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
        jp    z,loc_05A2
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
