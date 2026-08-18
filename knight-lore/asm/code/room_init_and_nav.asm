; ============================================================
; room_init_and_nav.asm -- genere par tools/gen_asm.py, plage #2A33-#2D5E
; Genere mecaniquement depuis la RAM live + asm/symbols.json.
; Ne pas editer les blocs de code a la main : relancer le generateur.
; ============================================================
        org #2A33
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
        jr    z,loc_2A71
        call    fn_object_catalog_writeback
loc_2A71:
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
        call    #2F2B
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
        call    #178D
        ld    b,#02
        call    fn_hud_icon_draw_loop
        call    fn_hud_record_load_fields
        ld    de,#0100
        ld    b,#24
        call    #178D
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
        call    #178D
        call    fn_hud_record_load_fields
        ld    b,#18
        call    #178D
        call    fn_hud_record_load_fields
        ld    de,#0100
        ld    b,#80
        call    #178D
        call    fn_hud_record_load_fields
        ld    b,#80
        jp    #178D
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
loc_2CA0:
        ld    bc,rst_add_hl_a
        ldir
        ld    a,(ix+off_room_number)
        ld    (de),a
        inc    de
        ld    b,#13
        call    fn_zero_fill_de
        ld    a,(hl)
        and    a
        jr    nz,loc_2CA0
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
loc_2CC0:
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
loc_2CD8:
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
        jr    nz,loc_2CD8
        pop    de
        pop    hl
        dec    b
        jr    z,fn_load_room_data_phase2_tail
        dec    c
        jp    z,loc_2CC0
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
