; ============================================================
; menu_and_materialize.asm -- genere par tools/gen_asm.py, plage #170D-#1A19
; Genere mecaniquement depuis la RAM live + asm/symbols.json.
; Ne pas editer les blocs de code a la main : relancer le generateur.
; ============================================================
        org #170D
fn_menu_glyph_unpack:
        ; Deballe un glyphe 4bpp->2bpp (8 lignes x 2 octets) a l'adresse HL,
        ; et rend HL avance de +2 (glyphe suivant, meme ligne) -- contrat
        ; inchange pour tous les appelants.
        ;
        ; ATTENTION, DEUX OCTETS AUTO-MODIFIES : les operandes des `and`
        ; ci-dessous (glyph_attr_mask_left / _right) sont l'OCTET
        ; D'ATTRIBUT DE COULEUR, ecrase a chaque appel par l'appelant
        ; (fn_menu_draw_string #16E5, fn_hud_render_day_counter,
        ; fn_hud_render_secondary_counter, fn_game_over_or_daycycle_end).
        ; Le #FF ecrit ici n'est qu'une valeur au repos : ce ne sont PAS
        ; des `and #FF` inutiles. Les appelants les designaient par
        ; adresse litterale (#172C / #173C) ; ils utilisent desormais ces
        ; deux labels, pour que toute reecriture de cette routine soit
        ; suivie automatiquement par l'assembleur.
        ;
        ; [vram-direct 2026-08-19] Destination migree du BUFFER vers la
        ; VRAM. Deux seuls changements de fond :
        ;  1) l'avance de ligne. Le buffer est LINEAIRE (#9000 + y*64), donc
        ;     -64 = y-1. La VRAM est ENTRELACEE : y-1 = +#0800, avec la
        ;     correction +#C050 au franchissement de bande -- exactement le
        ;     mecanisme de fn_clear_screen et de fn_vram_advance_line. On ne
        ;     peut pas appeler fn_vram_advance_line ici : elle passe par DE,
        ;     qui porte le pointeur de donnees du glyphe (vivant). Le calcul
        ;     est donc inline via BC, deja sauvegarde/restaure a cet endroit
        ;     dans le code d'origine.
        ;  2) le retour a HL+2. L'original y arrivait par arithmetique
        ;     (8 x -64 puis +#0202) ; en VRAM l'avance n'est pas lineaire,
        ;     donc l'adresse de depart est simplement empilee et redepilee.
        ;
        ; Budget des 66 octets d'origine (#174F et la suite -- #175F, #176B,
        ; #178D -- sont appeles par adresse litterale depuis d'autres
        ; fichiers, la longueur est donc contrainte) : le `dec hl` de fin de
        ; ligne disparait (l'avance part de HL+1 avec #07FF au lieu de HL
        ; avec #0800 : meme somme, meme carry) et le calcul de nibbles est
        ; reordonne -- masque d'abord, rotation ensuite -- pour un resultat
        ; strictement identique en 3 octets de moins par moitie. Total 65,
        ; complete par 1 nop.
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
        push    hl                   ; adresse de depart, relue a la fin
        ld    b,#08
glyph_row:
        ; octet gauche : nibble haut duplique sur les 2 nibbles
        ld    a,(de)
        and    #F0
        ld    c,a
        rrca
        rrca
        rrca
        rrca
        or    c
        and    #FF                   ; <- operande auto-modifiee (attribut)
glyph_attr_mask_left equ $-1
        ld    (hl),a
        inc    hl
        ; octet droit : nibble bas duplique sur les 2 nibbles
        ld    a,(de)
        and    #0F
        ld    c,a
        rlca
        rlca
        rlca
        rlca
        or    c
        and    #FF                   ; <- operande auto-modifiee (attribut)
glyph_attr_mask_right equ $-1
        ld    (hl),a
        ; ligne suivante vers le bas de l'ecran (screen_y - 1) ; HL est a
        ; depart+1, d'ou #07FF et non #0800
        inc    de
        push    bc
        ld    bc,#07FF
        add    hl,bc
        jr    nc,glyph_row_next
        ld    bc,#C050
        add    hl,bc
glyph_row_next:
        pop    bc
        djnz    glyph_row
        pop    hl
        inc    hl
        inc    hl
        pop    de
        pop    bc
        ret
        nop
        ASSERT $ - fn_menu_glyph_unpack == #42   ; 66 octets, #174F preserve
        and    a
        jr    nz,loc_1759
loc_1752:
        ld    (hl),#FF
        jr    loc_175B
loc_1756:
        dec    a
        jr    z,loc_1752
loc_1759:
        ld    (hl),#0F
loc_175B:
        inc    hl
        djnz    loc_1756
        ret
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
        jp    fn_vram_merge_buffer_to_screen
loc_178D:
        push    bc
        push    de
        push    hl
        call    #2F2B
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
        call    #1D84
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
        call    #1D84
        res    6,(ix+off_state_flags_2)
        ld    a,(ix+off_transform_step_counter)
        ld    (ix+off_type),a
        jp    fn_main_loop_entity_dispatch
        ld    (ix+off_type),#70
        set    1,(ix+off_flags)
        jr    loc_17E2
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
        call    #1D84
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
        call    #0A14
        jp    #1F7B
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
        call    #1D84
        jp    #1239
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
        ; [vram-direct] fn_vram_addr_from_yx rend maintenant une adresse
        ; VRAM : l'effacement doit donc passer par fn_vram_fill_rect
        ; (avance +#0800/ligne) et non fn_fill_rect (-64/ligne, buffer).
        ; Meme sens de parcours (screen_y - 1), meme longueur d'appel.
        ; BC = #0618 (la resolution symbolique du generateur est fortuite,
        ; c'est une constante largeur/hauteur : B=6 octets, C=24 lignes).
        call    fn_vram_addr_from_yx
        ld    bc,fn_render_workload_pacing_delay
        xor    a
        call    fn_vram_fill_rect
        pop    hl
        ld    a,(hl)
        and    a
        jr    z,loc_184F
        ld    (ix+off_type),a
        call    #2F2B
loc_184F:
        ld    c,(ix+off_screen_x)
        ld    a,(ix+off_screen_y)
        add    a,#17
        ld    b,a
        call    fn_screen_addr_from_bc
        ld    l,c
        ld    h,b
        call    fn_vram_addr_from_yx
        ld    bc,#1806
        ld    a,(var_render_disabled_flag)
        and    a
        jr    nz,loc_186C
        call    fn_blit_copy_line
loc_186C:
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
        defb #BA,#0D,#FC,#0F,#00,#5B,#0D,#00,#0D,#00,#00,#02,#01,#0D,#00,#0D
        defb #02,#00,#02,#F5,#08,#1F,#D0,#00,#00,#00,#00,#00,#00,#00,#00,#00
fn_read_use_object_button:
        ; Teste un bit dédié de var_input_result (0x007B) pour le bouton "utiliser
        ; objet" — selon var_input_mode_flag bit1/bit3 (clavier vs joystick),
        ; applique ou non une rotation avant de tester bit4, pour compenser la
        ; différence d'agencement des bits entre scan clavier et scan joystick
        ld    hl,var_input_mode_flag
        ld    a,(hl)
        and    #02
        ld    a,(var_input_result)
        jr    z,loc_18A7
        bit    3,(hl)
        jr    z,loc_18A7
        rrca
loc_18A7:
        and    #10
        ret
fn_player_use_held_object:
        ; Teste var_transform_flag_and_saved_type puis fn_read_use_object_button ;
        ; si le bouton est presse et les gardes de collision/etat sont
        ; satisfaites, declenche l'usage de l'objet actuellement tenu (boost de
        ; hauteur ou depot, selon le contexte).
        ld    a,(#0079)
        and    a
        jp    nz,loc_1948
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
        jr    nc,loc_18DD
        ld    a,#01
        ld    (#0097),a
loc_18DD:
        ld    hl,#0040
        call    #0A14
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
        jp    c,loc_19E0
        ld    de,#001C
        add    iy,de
        djnz    loc_190E
        call    fn_read_use_object_button
        jr    z,loc_193C
        ld    b,#02
        ld    a,(ix+off_room_number)
        cp    #88
        jr    nz,loc_192B
        ld    b,#01
loc_192B:
        ld    iy,#010F
        ld    de,#001C
loc_1932:
        ld    a,(iy+off_type)
        and    a
        jr    z,loc_1951
        add    iy,de
        djnz    loc_1932
loc_193C:
        pop    hl
        ld    (ix+off_bbox_d),l
        pop    hl
        ld    (ix+off_bbox_w),l
        ld    (ix+off_bbox_h),h
        ret
loc_1948:
        call    fn_read_use_object_button
        ret    nz
        xor    a
        ld    (#0079),a
        ret
loc_1951:
        ld    hl,#00B3
        ld    a,(hl)
        inc    hl
        and    a
        jr    z,loc_19CA
        ld    a,(#0097)
        and    a
        jr    nz,loc_193C
        dec    hl
        ld    a,(hl)
        inc    hl
        ld    (iy+off_type),a
        ld    a,(ix+off_room_number)
        cp    #88
        jr    nz,loc_197C
        ld    a,(ix+off_grid_z_or_offset)
        cp    #98
        jr    c,loc_197C
        set    3,(iy+off_type)
        ld    a,#01
        ld    (var_special_input_mode_2),a
loc_197C:
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
loc_19CA:
        ld    hl,#00B2
        ld    de,#00B6
        ld    bc,#000C
        lddr
        ld    de,#00A7
        ld    b,#04
        call    fn_zero_fill_de
        jp    loc_193C
loc_19E0:
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
        jr    z,loc_19CA
        ld    (iy+off_type),a
        push    hl
        jr    loc_19A5
loc_1A11:
        ld    a,(iy+off_type)
        sub    #60
        cp    #07
        ret    nc
