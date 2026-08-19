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
; ============================================================
; ZONE DE PILE (branche vram-direct-experiment, 2026-08-19)
;
; 71 octets, #2D9B-#2DE1, immediatement SOUS fn_render_entities (#2DE2)
; qui suit : la pile part de #2DE2 et descend, elle n'ecrit donc jamais
; dans du code vivant tant qu'elle ne depasse pas 71 octets.
;
; POURQUOI ICI : l'objectif est de liberer #8000-#BFFF (double buffer),
; or SP etait initialise a #8100 avec une pile active descendant jusqu'a
; #80D6 (usage observe) voire #8010 (borne calculee). Il fallait 64
; octets contigus sous #8000 -- il n'y en avait aucun de libre, ils ont
; ete FABRIQUES ici en supprimant trois routines devenues mortes ou
; deplacees :
;   - fn_clear_screen (28o) : encore vivante, relogee telle quelle dans
;     code/vram_direct_rendering.asm (appelants symboliques, rien a
;     changer chez eux) ;
;   - fn_clear_intermediate_buffer (8o) et fn_copy_screen_rect (35o) :
;     n'etaient plus que des `jp` de redirection vers
;     fn_vram_clear_playfield_and_buffer / fn_vram_merge_buffer_to_screen
;     depuis le correctif du 2026-08-19 -- leurs appelants pointent
;     desormais directement sur les cibles, les tremplins disparaissent.
;
; POURQUOI 71 OCTETS SUFFISENT : le gros consommateur de pile etait la
; FILE DE BLITS DIFFERES (fn_stage_blit_and_clear empilait BC/DE/HL par
; entite sale, soit jusqu'a 40x6 = 240 octets -- c'est exactement d'ou
; venait la borne #8010). Cette file est supprimee ci-dessous (le blit
; differe fn_blit_copy_line est mort : le dessin va directement en VRAM).
; Ne reste que l'imbrication d'appels + les push des routines, tres
; en-dessous de 71 octets.
;
; SI CA DEBORDE : le bloc libre de 46 octets laisse a #2EAE (voir
; ex-loc_2EAA plus bas) est le candidat naturel pour agrandir la zone,
; mais il n'est PAS contigu -- il faudrait d'abord y reloger
; fn_isometric_project ou equivalent. Verification empirique
; recommandee : remplir la zone d'un motif temoin au boot et relire la
; borne basse atteinte apres quelques minutes de jeu.
;
; La taille est EXACTEMENT 71 (#0047) pour que fn_render_entities reste
; a #2DE2 -- contrainte generale de ce fichier, voir l'operande
; auto-modifie #2F8B plus bas.
; ============================================================
zone_stack:
        ds #0047
zone_stack_top:
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
        ; [branche vram-direct-experiment] remplace les 9 octets originaux
        ; (swap BC<->HL + call fn_buffer_addr_from_vram) par un appel vers
        ; code/vram_direct_rendering.asm qui fait exactement la même chose
        ; PLUS le nouveau clear direct VRAM -- padding nop pour garder la
        ; taille de fn_stage_blit_and_clear identique (voir
        ; notes/2026-08-18-vram-direct-patch-plan.md).
        call    fn_stage_clear_vram_and_buffer_addr
        ; [vram-direct 2026-08-19] enregistre le rectangle sale dans
        ; tbl_dirty_rects, la fenetre de publication que la copie differee
        ; assurait avant (elle portait cette liste sur la pile, via les
        ; push neutralises plus bas). Consomme 3 des 6 nop de bourrage.
        call    fn_dirty_rect_store
        nop
        nop
        nop
        ld    a,(var_blit_stack_counter)
        inc    a
        ld    (var_blit_stack_counter),a
        ; [vram-direct 2026-08-19] 7 octets neutralises. Ils empilaient
        ; BC/DE/HL (parametres du blit differe buffer->VRAM, depile par
        ; l'ex-boucle loc_2EAA) puis effacaient le rectangle sale DANS LE
        ; BUFFER. Les deux sont sans objet : le rectangle est deja efface
        ; directement en VRAM par fn_stage_clear_vram_and_buffer_addr
        ; juste au-dessus, et fn_blit_copy_line est morte.
        ;
        ; C'est aussi ce qui rend la nouvelle zone de pile de 71 octets
        ; suffisante : ces 6 octets par entite sale etaient le seul
        ; consommateur de pile non borne du jeu (jusqu'a 40x6 = 240).
        ; var_blit_stack_counter continue d'etre incremente juste
        ; au-dessus : c'est la mesure de charge lue par
        ; fn_render_workload_pacing_delay, le calage de frame est donc
        ; inchange.
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        jp    loc_2DF5
loc_2E8D:
        ld    c,(ix+off_screen_x)
        jr    loc_2E1E
loc_2E92:
        ld    b,(ix+off_screen_y)
        jr    loc_2E4B
loc_2E97:
        ; [vram-direct 2026-08-19] etait `call fn_check_collisions`.
        ; L'enveloppe active l'ecretage aux rectangles sales le temps de la
        ; passe de dessin des entites, et le desactive ensuite : les
        ; appels HUD juste en dessous, la materialisation et les ecrans de
        ; menu / game over continuent de dessiner en entier. Meme longueur.
        call    fn_collide_clipped
        call    fn_hud_day_night_cycle
        call    fn_hud_slot_notification
        ld    hl,var_blit_stack_counter
        ld    a,(var_blit_stack_accumulator)
        add    a,(hl)
        ld    (var_blit_stack_accumulator),a
; ============================================================
; [vram-direct 2026-08-19] Les 50 octets #2EAA-#2EDB contenaient la
; boucle de blits differes (19o), sa sortie loc_2EBD (3o) et
; fn_blit_copy_line (28o). Tout est mort : le dessin va directement en
; VRAM, il n'y a plus rien a recopier depuis le buffer.
; Nouveau contenu, meme longueur totale (50) pour ne pas decaler
; l'operande auto-modifie #2F8B :
;   3o  fin de frame (ex-loc_2EBD, remontee ici)
;   1o  fn_blit_copy_line -> un simple `ret`, pour que ses appelants
;       encore presents (fn_hud_icon_redraw_8x4, loc_1C6E,
;       fn_hud_slot_notification) restent assemblables sans les toucher
;   46o bloc LIBRE
; ============================================================
        pop    ix
        ret
fn_blit_copy_line:
        ; [vram-direct] Vidée : `ret` seul. Le corps d'origine (copie
        ; ligne buffer->VRAM avec entrelacement CRTC) n'a plus d'objet.
        ret
fn_mark_count:
        ; [vram-direct 2026-08-19] Loge dans les 46 octets libres #2EAE-#2EDB
        ; (ex-boucle de blits differes). Compte les entites actives portant
        ; le bit4 « a redessiner ». Sert de detecteur de point fixe a
        ; fn_mark_closure_then_cull (code/vram_direct_rendering.asm) : le
        ; marquage ne fait qu'AJOUTER des bits, donc le compte est monotone
        ; et son invariance signale la convergence.
        ;
        ; OUT : C = nombre d'entites marquees. Detruit A/B/DE/IY.
        ld    iy,struct_entities_base
        ld    b,#28
        ld    c,#00
fn_mark_count_loop:
        ld    a,(iy+off_type)
        and    a
        jr    z,fn_mark_count_next
        bit    4,(iy+off_flags)
        jr    z,fn_mark_count_next
        inc    c
fn_mark_count_next:
        ld    de,#001C
        add    iy,de
        djnz    fn_mark_count_loop
        ret

zone_free_2EAE:
        ; Reste des 46 octets libres sous #8000.
        ds #002E - (zone_free_2EAE - fn_mark_count)
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
        ; [vram-direct 2026-08-19] #2F2B -- egalement le POINT D'ENTREE
        ; ALTERNATIF du pipeline sprite (HUD, bordures : ils posent
        ; screen_x/y a la main et sautent projection et culling). Les 3
        ; octets `call fn_resolve_sprite_shape` deviennent un `jp` vers le
        ; driver ecretant, qui commence par ce meme appel. Tout le corps
        ; qui suit jusqu'a #2F8A devient MORT (laisse en place : la
        ; longueur du fichier est contrainte, voir plus bas).
        jp    fn_blit_clip_driver
        ; [vram-direct] 9 octets neutralises. Ils calculaient le stride
        ; (64-w, puis -w) et le pokaient dans l'operande #30AF. Les
        ; familles deroulees ayant ete remplacees par de vraies boucles,
        ; la largeur est desormais portee par var_blit_width, pose par le
        ; stub d'entree -- plus aucun code auto-modifiant ici.
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
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
        ; [vram-direct] x18 -> x4 : les entrees deroulees de 18 octets
        ; sont devenues des stubs de 4 octets. 5 nop pour preserver la
        ; longueur (contrainte #2F8B).
        add    hl,hl
        add    hl,hl
        nop
        nop
        nop
        nop
        nop
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
        ; [vram-direct] les 11 octets d'origine calculaient l'adresse dans
        ; le buffer intermediaire ; ils sont remplaces par un appel qui
        ; calcule l'adresse VRAM reelle (code/vram_direct_rendering.asm),
        ; padding nop pour conserver les 11 octets.
        call    fn_vram_sprite_addr
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        ex    af,af'
        inc    de
        add    a,#80
        ld    h,a
        ld    a,(ix+off_screen_h)
loc_2F89:
        ex    af,af'
        ; Cible factice : cet operande (#2F8B) est ecrase a chaque appel par
        ; fn_sprite_pipeline_setup avec le stub de largeur voulu. Pointait
        ; sur loc_3147 (une entree du deroulement aligne, disparue avec la
        ; mise en boucle) ; pointe desormais sur la base de la famille
        ; decalee, tout aussi arbitraire mais valide.
        jp    fn_blit_masked
fn_blit_masked:
        ; ============================================================
        ; [vram-direct-experiment, 2026-08-19] REECRITURE EN BOUCLES.
        ;
        ; A l'origine : deux familles "duff device" de 16 entrees
        ; deroulees chacune (18 o/entree pour la variante a decalage
        ; sub-octet, 10 o/entree pour la variante alignee-octet), soit
        ; ~450 octets, le point d'entree encodant la largeur.
        ;
        ; Desormais : chaque entree est un STUB de 4 octets qui charge la
        ; largeur dans A et saute au corps de boucle unique de sa famille.
        ; Le mecanisme de dispatch d'origine est INCHANGE (JP auto-modifie
        ; en #2F8A, adresse = base + index x taille_unite) -- seule la
        ; taille d'unite passe de 18/10 a 4, ajustee dans les deux
        ; multiplicateurs de fn_sprite_pipeline_setup.
        ;
        ; POURQUOI : liberer de la place DANS la zone de code pour y loger
        ; les routines VRAM-directes. #8100 s'est revele inutilisable --
        ; c'est STACK_TOP_INIT (voir include/memory_map.equ.asm:65) et la
        ; zone est ecrasee en cours de jeu (constat direct, voir
        ; notes/2026-08-18-vram-direct-patch-plan.md). La zone de code,
        ; elle, n'est atteignable par aucun debordement de donnees.
        ;
        ; COUT : une boucle par colonne au lieu d'un deroulement, donc plus
        ; lent. Re-deroulable plus tard comme passe d'optimisation separee.
        ;
        ; Index d'entree j = (-w) & 15, donc la largeur vaut 16-j pour
        ; j=0..15 -- c'est la constante portee par chaque stub. Le cas
        ; degenere w=0 donne j=0 donc 16 colonnes, exactement comme le
        ; deroulement d'origine (entree 0 = les 16 unites).
        ; ============================================================
blit_shift_e00:
        ld    a,#10
        jr    blit_shift_run
blit_shift_e01:
        ld    a,#0F
        jr    blit_shift_run
blit_shift_e02:
        ld    a,#0E
        jr    blit_shift_run
blit_shift_e03:
        ld    a,#0D
        jr    blit_shift_run
blit_shift_e04:
        ld    a,#0C
        jr    blit_shift_run
blit_shift_e05:
        ld    a,#0B
        jr    blit_shift_run
blit_shift_e06:
        ld    a,#0A
        jr    blit_shift_run
blit_shift_e07:
        ld    a,#09
        jr    blit_shift_run
blit_shift_e08:
        ld    a,#08
        jr    blit_shift_run
blit_shift_e09:
        ld    a,#07
        jr    blit_shift_run
blit_shift_e10:
        ld    a,#06
        jr    blit_shift_run
blit_shift_e11:
        ld    a,#05
        jr    blit_shift_run
blit_shift_e12:
        ld    a,#04
        jr    blit_shift_run
blit_shift_e13:
        ld    a,#03
        jr    blit_shift_run
blit_shift_e14:
        ld    a,#02
        jr    blit_shift_run
blit_shift_e15:
        ld    a,#01
        jr    blit_shift_run
blit_shift_run:
        ld    (var_blit_cols),a
        ld    (var_blit_width),a
blit_shift_col:
        ; corps identique a l'unite deroulee d'origine (18 octets), sauf
        ; `inc c` -> `inc bc` : l'original ne propageait pas la retenue
        ; dans B, ce qui repliait l'ecriture 256 octets plus bas quand une
        ; ligne franchissait une frontiere de page. Inoffensif ou non dans
        ; le buffer, c'est faux en VRAM ou les debuts de ligne ne sont pas
        ; alignes. Meme avance nette (+1/colonne).
        ld    a,(de)
        inc    de
        ld    l,a
        ld    a,(bc)
        and    (hl)
        inc    h
        or    (hl)
        inc    h
        ld    (bc),a
        inc    bc
        ld    a,(bc)
        and    (hl)
        inc    h
        or    (hl)
        ld    (bc),a
        dec    h
        dec    h
        dec    h
        ld    a,(var_blit_cols)
        dec    a
        ld    (var_blit_cols),a
        jr    nz,blit_shift_col
        jp    blit_row_end

loc_30BB:
        ; Mise en place de la famille alignee-octet (inchangee sauf le
        ; multiplicateur x10 -> x4 et la base, desormais symbolique).
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
        add    hl,hl
        ld    bc,blit_aligned
        inc    de
        ld    a,(de)
        dec    de
        and    a
        jp    z,loc_2F5E
        ex    af,af'
        sub    #02
        ex    af,af'
        jp    loc_2F5E

blit_aligned:
blit_al_e00:
        ld    a,#10
        jr    blit_al_run
blit_al_e01:
        ld    a,#0F
        jr    blit_al_run
blit_al_e02:
        ld    a,#0E
        jr    blit_al_run
blit_al_e03:
        ld    a,#0D
        jr    blit_al_run
blit_al_e04:
        ld    a,#0C
        jr    blit_al_run
blit_al_e05:
        ld    a,#0B
        jr    blit_al_run
blit_al_e06:
        ld    a,#0A
        jr    blit_al_run
blit_al_e07:
        ld    a,#09
        jr    blit_al_run
blit_al_e08:
        ld    a,#08
        jr    blit_al_run
blit_al_e09:
        ld    a,#07
        jr    blit_al_run
blit_al_e10:
        ld    a,#06
        jr    blit_al_run
blit_al_e11:
        ld    a,#05
        jr    blit_al_run
blit_al_e12:
        ld    a,#04
        jr    blit_al_run
blit_al_e13:
        ld    a,#03
        jr    blit_al_run
blit_al_e14:
        ld    a,#02
        jr    blit_al_run
blit_al_e15:
        ld    a,#01
        jr    blit_al_run
blit_al_run:
        ld    (var_blit_cols),a
        ld    (var_blit_width),a
blit_al_col:
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
        ld    a,(var_blit_cols)
        dec    a
        ld    (var_blit_cols),a
        jr    nz,blit_al_col
        jp    blit_row_end

blit_row_end:
        ; Fin de ligne, commune aux deux familles (ex-loc_30AD + ex-
        ; fn_vram_next_row, desormais fusionnees et sans code auto-modifie).
        ; 1) revenir au debut de la ligne : BC -= largeur
        ld    a,(var_blit_width)
        neg
        add    a,c
        ld    c,a
        ld    a,b
        adc    a,#FF
        ld    b,a
        ; 2) avance raster CRTC-aware vers screen_y + 1, soit -0x800 (et
        ;    +0x37B0 aux franchissements de bande). C'est l'INVERSE de
        ;    fn_vram_advance_line (+0x800 = screen_y - 1), qui convient au
        ;    clear mais pas au blit. Le CARRY n'est pas discriminant ici
        ;    (B >= #C0 pour toute adresse VRAM), d'ou le test du bit 6.
        ld    a,b
        sub    #08
        ld    b,a
        bit    6,b
        jr    nz,blit_row_next
        ld    a,c
        add    a,#B0
        ld    c,a
        ld    a,b
        adc    a,#3F
        ld    b,a
blit_row_next:
        ; 3) boucle de lignes (compteur dans AF'), inchangee
        ex    af,af'
        dec    a
        jp    nz,loc_2F89
        ret

var_blit_cols:
        defb  #00                  ; compteur de colonnes de la ligne courante
var_blit_width:
        defb  #00                  ; largeur du sprite (colonnes), pose par le stub

blit_vram_free:
        ; Debut de la place liberee par la mise en boucle -- accueille
        ; code/vram_direct_rendering.asm (org blit_vram_free).
