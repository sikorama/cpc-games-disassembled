; ============================================================
; collision_and_input.asm -- genere par tools/gen_asm.py, plage #26F7-#2A33
; Genere mecaniquement depuis la RAM live + asm/symbols.json.
; Ne pas editer les blocs de code a la main : relancer le generateur.
; ============================================================
        org #26F7
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
        jr    z,loc_2715
        bit    4,(ix+off_flags)
        jr    z,loc_2715
        ld    (hl),c
        inc    hl
loc_2715:
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
loc_275B:
        ld    a,(de)
        inc    de
        cp    #FF
        jp    z,loc_28AA
        bit    7,a
        jr    nz,loc_275B
        call    fn_entity_index_to_ptr
        ld    (var_collision_ix_cursor),de
        push    hl
        pop    ix
loc_2770:
        ld    a,(de)
        inc    de
        cp    #FF
        jp    z,loc_2895
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
        jr    nc,loc_27AB
        ld    a,(ix+off_grid_z_or_offset)
        add    a,(ix+off_bbox_d)
        ld    l,a
        ld    a,(iy+off_grid_z_or_offset)
        sub    l
        jr    c,loc_27AA
        inc    c
loc_27AA:
        inc    c
loc_27AB:
        ld    a,(iy+off_grid_y)
        add    a,(iy+off_bbox_h)
        ld    l,a
        ld    a,(ix+off_grid_y)
        sub    (ix+off_bbox_h)
        sub    l
        jr    nc,loc_27D1
        ld    a,(ix+off_grid_y)
        add    a,(ix+off_bbox_h)
        ld    l,a
        ld    a,(iy+off_grid_y)
        sub    (iy+off_bbox_h)
        sub    l
        ld    a,c
        jr    c,loc_27CE
        add    a,#03
loc_27CE:
        add    a,#03
        ld    c,a
loc_27D1:
        ld    a,(iy+off_grid_x)
        add    a,(iy+off_bbox_w)
        ld    l,a
        ld    a,(ix+off_grid_x)
        sub    (ix+off_bbox_w)
        sub    l
        jr    nc,loc_27F7
        ld    a,(ix+off_grid_x)
        add    a,(ix+off_bbox_w)
        ld    l,a
        ld    a,(iy+off_grid_x)
        sub    (iy+off_bbox_w)
        sub    l
        ld    a,c
        jr    c,loc_27F4
        add    a,#09
loc_27F4:
        add    a,#09
        ld    c,a
loc_27F7:
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
        jr    z,loc_284D
        cp    c
        jr    z,loc_2863
        inc    de
        jr    loc_2842
loc_284D:
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
loc_2863:
        ld    hl,buf_visible_entities
loc_2866:
        ld    a,(hl)
        inc    hl
        cp    #FF
        jp    z,loc_2758
        cp    c
        jr    nz,loc_2866
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
        jr    nc,loc_2885
        ld    (ix+off_type),#BB
        jr    loc_2892
loc_2885:
        ld    a,(iy+off_type)
        sub    #60
        cp    #07
        jr    nc,loc_2892
        ld    (iy+off_type),#BB
loc_2892:
        jp    loc_2770
loc_2895:
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
loc_28AA:
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
        jr    z,loc_2912
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
        jr    z,loc_28E1
        set    2,c
loc_28E1:
        bit    1,a
        jr    z,loc_28E7
        set    4,c
loc_28E7:
        bit    2,a
        jr    z,loc_28ED
        set    0,c
loc_28ED:
        bit    3,a
        jr    z,loc_28F3
        set    1,c
loc_28F3:
        bit    4,a
        jr    z,loc_28F9
        set    3,c
loc_28F9:
        bit    5,a
        jr    z,loc_28FF
        set    5,c
loc_28FF:
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
loc_2912:
        ld    hl,tbl_joystick_mask_0
        call    fn_read_joystick_table
        jr    z,loc_291C
        set    0,c
loc_291C:
        ld    hl,tbl_joystick_mask_1
        call    fn_read_joystick_table
        jr    z,loc_2926
        set    1,c
loc_2926:
        ld    hl,tbl_joystick_mask_2
        call    fn_read_joystick_table
        jr    z,loc_2930
        set    2,c
loc_2930:
        ld    hl,tbl_joystick_mask_3
        call    fn_read_joystick_table
        jr    z,loc_293A
        set    3,c
loc_293A:
        ld    hl,tbl_joystick_mask_4
        call    fn_read_joystick_table
        jr    z,loc_2944
        set    4,c
loc_2944:
        jr    loc_2901
fn_read_joystick_table:
        ; Teste une table (ligne,masque) terminée par 0xFF, utilisée par
        ; fn_read_input
        ld    b,#00
loc_2948:
        ld    a,(hl)
        inc    hl
        cp    #FF
        jr    z,loc_2959
        push    bc
        call    fn_read_keyboard_line
        pop    bc
        and    (hl)
        inc    hl
        or    b
        ld    b,a
        jr    loc_2948
loc_2959:
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
        defb #78,#80,#80,#80,#05,#05,#17,#1C,#2F,#00,#00,#00,#00,#00,#00,#00
        defb #12,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#78,#80,#80,#8C
        defb #05,#05,#00,#1E,#2F,#00,#00,#00,#00,#00,#00,#00,#22,#00,#00,#00
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
