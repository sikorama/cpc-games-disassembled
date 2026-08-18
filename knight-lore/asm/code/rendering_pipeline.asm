; ============================================================
; rendering_pipeline.asm -- genere par tools/gen_asm.py, plage #2D5E-#3186
; Genere mecaniquement depuis la RAM live + asm/symbols.json.
; Ne pas editer les blocs de code a la main : relancer le generateur.
; ============================================================
        org #2D5E
fn_mul8x16:
        ; HL = A × DE, multiplication shift-and-add
        push    bc
        ld    hl,fn_cold_boot_entry
        ld    b,#08
loc_2D64:
        add    hl,hl
        rlca
        jr    nc,loc_2D69
        add    hl,de
loc_2D69:
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
loc_2D75:
        ld    a,#02
        call    fn_read_keyboard_line
        bit    5,a
        jr    nz,loc_2D75
loc_2D7E:
        ld    a,#02
        call    fn_read_keyboard_line
        bit    5,a
        jr    z,loc_2D7E
loc_2D87:
        ld    a,#02
        call    fn_read_keyboard_line
        bit    5,a
        jr    nz,loc_2D87
        ret
fn_mem_fill_simple:
        ; LD (HL),E / INC HL / DEC BC en boucle — remplissage mémoire générique
        ld    e,#00
loc_2D93:
        ld    (hl),e
        inc    hl
        dec    bc
        ld    a,b
        or    c
        jr    nz,loc_2D93
        ret
fn_clear_screen:
        ; Efface l'écran complet 0xC000, gère l'entrelacement CRTC
        ld    hl,VRAM_BASE
        ld    c,#19
loc_2DA0:
        ld    b,#50
        push    hl
loc_2DA3:
        ld    (hl),#00
        inc    hl
        djnz    loc_2DA3
        pop    hl
        ld    de,#0800
        add    hl,de
        jr    nc,loc_2DA0
        ld    de,#C050
        add    hl,de
        dec    c
        jr    nz,loc_2DA0
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
        jr    nc,loc_2DD8
        ld    de,#C050
        add    hl,de
loc_2DD8:
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
        jp    nz,loc_2E97
        ld    hl,buf_visible_entities
        ld    (var_entity_list_cursor),hl
loc_2DF5:
        ld    hl,(var_entity_list_cursor)
        ld    a,(hl)
        inc    hl
        ld    (var_entity_list_cursor),hl
        cp    #FF
        jp    z,loc_2E97
        call    fn_entity_index_to_ptr
        push    hl
        pop    ix
        bit    5,(ix+off_flags)
        jr    z,loc_2DF5
        res    5,(ix+off_flags)
        ld    a,(ix+off_screen_x)
        sub    (ix+off_screen_x_prev)
        jp    c,loc_2E8D
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
        jr    c,loc_2E37
        ld    e,a
loc_2E37:
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
        jr    c,loc_2E92
        ld    b,(ix+off_screen_y_prev)
loc_2E4B:
        ld    a,(ix+off_screen_y_prev)
        add    a,(ix+off_screen_h_prev)
        ld    e,a
        ld    a,(ix+off_screen_y)
        add    a,(ix+off_screen_h)
        cp    e
        jr    nc,loc_2E5C
        ld    a,e
loc_2E5C:
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
loc_2E8D:
        ld    c,(ix+off_screen_x)
        jr    loc_2E1E
loc_2E92:
        ld    b,(ix+off_screen_y)
        jr    loc_2E4B
loc_2E97:
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
        jr    z,loc_2EBD
        dec    (hl)
        pop    hl
        pop    de
        pop    bc
        ld    a,b
        ld    b,c
        ld    c,a
        call    fn_blit_copy_line
        jr    loc_2EAA
loc_2EBD:
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
        jr    nc,loc_2ED2
        ld    de,#C050
        add    hl,de
loc_2ED2:
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
        jr    nz,loc_2F23
        ld    (ix+off_type),#00
        ret
loc_2F23:
        res    4,(ix+off_flags)
        call    fn_isometric_project
        ret    nc
        call    fn_resolve_sprite_shape
        ld    a,(de)
        and    #3F
        cpl
        add    a,#41
        ld    (#30AF),a
        ld    a,(ix+off_screen_x)
        and    #03
        jp    z,loc_30BB
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
        jr    c,loc_2F76
        neg
        add    a,(ix+off_screen_h)
        ld    (ix+off_screen_h),a
loc_2F76:
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
loc_2F89:
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
        jp    nz,loc_2F89
        ret
loc_30BB:
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
