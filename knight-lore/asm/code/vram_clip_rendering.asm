; ============================================================
; vram_clip_rendering.asm -- code NEUF (branche vram-direct-experiment).
;
; ECRETAGE DU BLIT AUX RECTANGLES SALES -- option 3 du 2026-08-19.
;
; POURQUOI. Le buffer intermediaire d'origine ne servait pas seulement a
; composer l'image : la copie differee ne publiait vers la VRAM que les
; RECTANGLES SALES. C'etait donc aussi une FENETRE DE PUBLICATION, et elle
; autorisait le plan de composition a etre localement faux hors de ces
; rectangles (un bloc de decor redessine y ecrasait les pixels d'un objet
; devant lui, sans consequence, et la zone etait reparee avant de devenir
; publiable). Le dessin direct supprime cette fenetre : chaque sprite
; publie toute son etendue, la corruption devient visible.
;
; Les deux autres reparations ont ete eliminees par la mesure :
;   - fermeture transitive du marquage : CASCADE, le decor d'une salle est
;     un maillage connexe donc la fermeture est la salle entiere ;
;   - tout redessiner chaque frame : 4 a 8x le travail de blit.
; Reste a reproduire la fenetre de publication, c'est-a-dire ECRETER le
; dessin aux rectangles sales. C'est ce que fait ce fichier.
;
; CE QUI REND CA POSSIBLE. La reecriture de fn_blit_masked en vraies
; boucles (2026-08-19 matin) : les familles deroulees d'origine encodaient
; la largeur dans le point d'entree, on ne pouvait pas y faire varier le
; debut et la longueur ligne par ligne.
;
; CE QUI REND CA SIMPLE. Le blit masque est IDEMPOTENT (ecran =
; ecran & masque | couleur, masque et couleur ne dependant que de l'octet
; de forme). Dessiner une entite ecretee au rectangle R1 puis au rectangle
; R2 equivaut donc a un ecretage a R1 u R2 : on ecrete a UN SEUL rectangle
; a la fois, et les recouvrements sont sans effet. Pas de decoupage
; d'intervalles contre N rectangles par ligne.
;
; ECRETAGE EXACT DE LA VARIANTE DECALEE. Une colonne de donnees y ecrit 2
; octets ecran adjacents (col0+i et col0+i+1), donc la colonne de bord de
; fenetre deborderait d'un octet (4 pixels). Constate en jeu : un lisere de
; 4 pixels a droite du rectangle sale du joueur, sur le cube voisin. Les
; colonnes de bord ont donc leur propre corps :
;   - 1re colonne rognee a gauche  -> 2e octet seulement (pages H+2/H+3) ;
;   - derniere colonne rognee a droite -> 1er octet seulement (pages H/H+1).
; Les deux ne peuvent pas etre demandes sur une meme colonne unique (le
; rognage gauche implique col0+d_last+1 = c_start <= c_end, donc pas de
; rognage droit).
;
; EMPLACEMENT. #9000-#BFFF, verifie totalement libre depuis la migration
; du chemin glyphes (plus une seule reference a BUF_PRERENDER_BASE dans
; asm/code/, 0 octet non nul dans le .sna). La contrainte de longueur des
; fichiers #0000-#3FFF ne s'applique pas ici.
; ============================================================
        org #9000

tbl_dirty_rects:
        ; 40 entrees de 4 octets : ytop (y MAX du rectangle, cf. la
        ; convention de fn_stage_blit_and_clear), hauteur, colonne de
        ; gauche (screen_x/4), largeur en colonnes.
        ; L'original portait cette liste SUR LA PILE (les push bc/de/hl de
        ; fn_stage_blit_and_clear, depiles par la boucle de blits
        ; differes) -- c'est exactement ce que la migration a neutralise,
        ; on la reconstitue ici en table.
        ds #00A0

; --- etat du sprite courant (pose par fn_blit_clip_driver) ---
clip_cols:          defb #00    ; largeur EN COLONNES ECRAN (w, +1 si decale)
clip_w_data:        defb #00    ; largeur en octets de donnees de forme (w)
clip_h:             defb #00    ; hauteur, deja ecretee a y < 192
clip_shift:         defb #00    ; decalage sub-octet (screen_x & 3)
clip_page:          defb #00    ; page de tables masque/couleur (#82 ou #80+shift*4)
clip_col0:          defb #00    ; colonne gauche du sprite
clip_addr0:         defw #0000  ; adresse VRAM de l'origine (ligne du BAS)
clip_shape:         defw #0000  ; pointeur payload de la forme

; --- fenetre d'ecretage courante ---
clip_rect_ymin:     defb #00
clip_rect_ymax:     defb #00
clip_col_skip:      defb #00    ; colonnes a sauter en debut de ligne
clip_col_n:         defb #00    ; colonnes a dessiner
clip_col_after:     defb #00    ; colonnes a sauter en fin de ligne
clip_c_end:         defb #00    ; derniere colonne ecran de la fenetre
clip_trim_first:    defb #00    ; != 0 : 1re colonne, n'ecrire que son 2e octet
clip_trim_last:     defb #00    ; != 0 : derniere colonne, n'ecrire que son 1er

; --- travail ---
clip_col_cnt:       defb #00
clip_cur_y:         defb #00
clip_rows_left:     defb #00
clip_rect_left:     defb #00
clip_rect_ptr:      defw #0000
clip_enable:        defb #00    ; != 0 : ecretage actif (uniquement pendant
                                ; fn_collide_clipped, voir plus bas)
drs_slot:           ds 4        ; tampon de recopie de fn_dirty_rect_store

; ============================================================
fn_dirty_rect_store:
        ; Appelee depuis fn_stage_blit_and_clear (passe 1 de
        ; fn_render_entities), juste apres l'effacement du rectangle et
        ; AVANT l'increment de var_blit_stack_counter -- le compteur donne
        ; donc directement l'index du slot a remplir.
        ;
        ; IN : B = ytop (y max du rect), L = hauteur, H = largeur en
        ;      colonnes, C = screen_x brut minimal.
        ; Preserve tous les registres.
        push    af
        push    bc
        push    de
        push    hl
        ld    a,b
        ld    (drs_slot+0),a          ; ytop
        ld    a,l
        ld    (drs_slot+1),a          ; hauteur
        ld    a,c
        rrca
        rrca
        and    #3F
        ld    (drs_slot+2),a          ; colonne gauche
        ld    a,h
        ld    (drs_slot+3),a          ; largeur en colonnes
        ld    a,(var_blit_stack_counter)
        cp    #28
        jr    nc,fn_dirty_rect_store_end
        add    a,a
        add    a,a
        ld    l,a
        ld    h,#00
        ld    de,tbl_dirty_rects
        add    hl,de
        ex    de,hl                   ; DE = slot destination
        ld    hl,drs_slot
        ld    bc,#0004
        ldir
fn_dirty_rect_store_end:
        pop    hl
        pop    de
        pop    bc
        pop    af
        ret

; ============================================================
fn_collide_clipped:
        ; Enveloppe posee a la place de `call fn_check_collisions` dans
        ; fn_render_entities (meme longueur d'appel).
        ;
        ; L'ecretage est actif UNIQUEMENT pendant cette passe. Partout
        ; ailleurs, le dessin reste complet, exactement comme avant :
        ;   - les routines HUD (jour/nuit, notification de slot) gerent
        ;     leur propre effacement, hors du mecanisme de rectangles sales
        ;     des entites -- les ecreter les ferait disparaitre ;
        ;   - fn_render_disabled_one_time_setup, les ecrans de menu et de
        ;     game over dessinent via le point d'entree alternatif #2F2B
        ;     APRES la passe entites, alors que var_blit_stack_counter
        ;     porte encore le compte de la frame : un test sur le seul
        ;     compteur les aurait ecretes a tort. D'ou un drapeau explicite
        ;     plutot qu'une heuristique.
        ld    a,#01
        ld    (clip_enable),a
        call    fn_check_collisions
        xor    a
        ld    (clip_enable),a
        ret

; ============================================================
fn_blit_clip_driver:
        ; Remplace les 3 octets `call fn_resolve_sprite_shape` a #2F2B --
        ; qui est AUSSI le point d'entree alternatif du pipeline sprite
        ; (utilise par le HUD et les bordures, qui posent screen_x/y a la
        ; main et sautent la projection). L'entree se fait par `jp`, donc
        ; le RET d'ici rend bien a l'appelant d'origine.
        ;
        ; IN : IX = entite, screen_x/screen_y a jour.
        ; Dessine l'entite une fois par rectangle sale reellement
        ; chevauche, ecretee a ce rectangle.
        call    fn_resolve_sprite_shape   ; DE -> en-tete de forme
                                          ; (double RET si forme vide : sort
                                          ; d'ici ET de l'appelant, comme
                                          ; dans le pipeline d'origine)
        ; ---- en-tete de forme : octet0 = largeur|flip, octet1 = hauteur ----
        ld    a,(de)
        and    #3F
        jr    nz,clip_setup_w_ok
        ld    a,#10                   ; w=0 degenere : l'entree 0 du
                                      ; deroulement d'origine dessinait 16
                                      ; colonnes, on reproduit
clip_setup_w_ok:
        ld    (clip_w_data),a
        ld    b,a
        ld    a,(ix+off_screen_x)
        and    #03
        ld    (clip_shift),a
        jr    z,clip_setup_aligned
        ; variante decalee : 1 colonne ecran de plus, page #80 + shift*4
        inc    b
        add    a,a
        add    a,a
        add    a,#80
        jr    clip_setup_page
clip_setup_aligned:
        ld    a,#82
clip_setup_page:
        ld    (clip_page),a
        ld    a,b
        ld    (clip_cols),a
        ld    (ix+off_screen_w),a
        ; ---- hauteur, ecretee au bord haut de l'ecran (y < 192) ----
        inc    de
        ld    a,(de)
        ld    b,a
        add    a,(ix+off_screen_y)
        jr    c,clip_setup_clip_h         ; debordement 8 bits => a ecreter
        cp    #C0
        jr    c,clip_setup_h_ok
clip_setup_clip_h:
        ld    a,#C0
        sub    (ix+off_screen_y)
        ret    c                      ; screen_y > 192 : possible par le
                                      ; point d'entree alternatif #2F2B, qui
                                      ; saute le culling. L'original
                                      ; dessinait du bruit ; on sort.
        ld    b,a
clip_setup_h_ok:
        ld    a,b
        ld    (clip_h),a
        ld    (ix+off_screen_h),a
        and    a
        ret    z                          ; rien a dessiner
        ; ---- payload de la forme (en-tete de 3 octets) ----
        inc    de
        inc    de
        ld    (clip_shape),de
        ; ---- colonne gauche et adresse VRAM de l'origine ----
        ld    a,(ix+off_screen_x)
        rrca
        rrca
        and    #3F
        ld    (clip_col0),a
        call    fn_vram_sprite_addr       ; BC = adresse VRAM de l'origine
        ld    (clip_addr0),bc
        ; ---- ecretage actif ? ----
        ld    a,(clip_enable)
        and    a
        jp    z,clip_draw_whole           ; hors passe entites : dessin complet
        ld    a,(var_blit_stack_counter)
        and    a
        jp    z,clip_draw_whole           ; aucun rectangle sale cette frame :
                                          ; rien n'a ete efface, donc rien a
                                          ; republier -- le dessin complet est
                                          ; idempotent, il repeint a l'identique
        cp    #29
        jr    c,clip_rect_count_ok
        ld    a,#28
clip_rect_count_ok:
        ld    (clip_rect_left),a
        ld    hl,tbl_dirty_rects
clip_rect_loop:
        ld    (clip_rect_ptr),hl
        ; ---- charger le rectangle ----
        ld    a,(hl)                      ; ytop
        ld    (clip_rect_ymax),a
        ld    d,a
        inc    hl
        sub    (hl)                       ; ytop - hauteur
        inc    a                          ; ymin
        ld    (clip_rect_ymin),a
        ld    e,a
        inc    hl
        ld    b,(hl)                      ; colonne gauche du rect
        inc    hl
        ld    c,(hl)                      ; largeur du rect
        ; ---- rejet en Y ----
        ld    a,d
        cp    (ix+off_screen_y)
        jr    c,clip_rect_next            ; rect_ymax < sprite_ymin
        ld    a,(clip_h)
        add    a,(ix+off_screen_y)
        dec    a                          ; sprite_ymax
        cp    e
        jr    c,clip_rect_next            ; sprite_ymax < rect_ymin
        ; ---- intersection en colonnes ----
        ; d = c_start = max(col0, rect_col)
        ld    a,(clip_col0)
        ld    e,a
        ld    a,b
        cp    e
        jr    nc,clip_cs_from_rect
        ld    a,e
clip_cs_from_rect:
        ld    d,a                         ; d = c_start
        ; c_end sprite = col0 + cols - 1
        ld    a,(clip_cols)
        add    a,e
        dec    a
        ld    l,a                         ; l = c_end sprite
        ; c_end rect = rect_col + rw - 1
        ld    a,b
        add    a,c
        dec    a
        cp    l
        jr    c,clip_ce_ok                ; rect plus a gauche -> il limite
        ld    a,l
clip_ce_ok:
        ld    l,a                         ; l = c_end
        cp    d
        jr    c,clip_rect_next            ; c_end < c_start : pas d'intersection
        ld    (clip_c_end),a
        xor    a
        ld    (clip_trim_first),a
        ld    (clip_trim_last),a
        ; ---- passage des colonnes ECRAN aux colonnes de DONNEES ----
        ; La variante decalee ecrit DEUX octets ecran par colonne de
        ; donnees (col0+i et col0+i+1), son etendue ecran vaut donc w+1
        ; alors que les donnees de forme font toujours w octets par ligne.
        ; La colonne de donnees i intersecte la fenetre si
        ; col0+i <= c_end ET col0+i+1 >= c_start, d'ou le -1 sur le debut
        ; et le plafonnement a w-1 sur la fin.
        ld    a,d
        sub    e
        ld    d,a                         ; d = c_start - col0
        ld    a,(clip_shift)
        and    a
        jr    z,clip_dfirst_ok            ; aligne : 1 octet par colonne
        ld    a,d
        and    a
        jr    z,clip_dfirst_ok
        dec    d                          ; decale : une colonne plus tot
        ld    a,#01
        ld    (clip_trim_first),a         ; son 1er octet tombe hors fenetre
clip_dfirst_ok:
        ld    a,d
        ld    (clip_col_skip),a
        ld    a,l
        sub    e                          ; c_end - col0
        ld    l,a
        ld    a,(clip_w_data)
        dec    a                          ; w-1
        cp    l
        jr    nc,clip_dlast_ok
        ld    l,a                         ; plafonne a la derniere colonne
clip_dlast_ok:
        ; La derniere colonne de donnees ecrit col0+d_last et col0+d_last+1 ;
        ; si le second tombe au-dela de c_end il faut le supprimer.
        ; B et C sont libres ici (rect_col / rect_width sont consommes).
        ld    a,(clip_shift)
        and    a
        jr    z,clip_trim_last_done
        ld    a,l
        inc    a
        add    a,e                        ; col0 + d_last + 1
        ld    b,a
        ld    a,(clip_c_end)
        cp    b
        jr    nc,clip_trim_last_done
        ld    a,#01
        ld    (clip_trim_last),a
clip_trim_last_done:
        ld    a,l
        sub    d
        inc    a                          ; n_data (>= 1, demontre en note)
        ld    (clip_col_n),a
        ld    c,a
        ld    a,(clip_w_data)
        sub    d
        sub    c
        ld    (clip_col_after),a
        ; ---- dessin ecrete ----
        call    clip_setup_unroll
        call    clip_blit
clip_rect_next:
        ld    hl,(clip_rect_ptr)
        ld    de,#0004
        add    hl,de
        ld    a,(clip_rect_left)
        dec    a
        ld    (clip_rect_left),a
        jp    nz,clip_rect_loop
        ret

clip_draw_whole:
        ; Fenetre d'ecretage "tout l'ecran" : une seule passe, sprite
        ; entier. Un seul chemin de dessin, donc un seul endroit ou une
        ; erreur peut se cacher.
        xor    a
        ld    (clip_rect_ymin),a
        ld    (clip_col_skip),a
        ld    (clip_col_after),a
        ld    (clip_trim_first),a
        ld    (clip_trim_last),a
        ld    a,#FF
        ld    (clip_rect_ymax),a
        ld    a,(clip_w_data)             ; colonnes de DONNEES (w), pas
                                          ; l'etendue ecran (w+1 si decale)
        ld    (clip_col_n),a
        call    clip_setup_unroll
        jp    clip_blit

clip_setup_unroll:
        ; Calcule le point d'entree dans le bloc deroule de la famille
        ; courante et le poke dans l'operande du `jp` de tete de ligne.
        ; Appelee UNE FOIS par (entite, rectangle), jamais par ligne.
        ;
        ; m = colonnes PLEINES = clip_col_n moins les colonnes de bord
        ; rognees, qui ont leur propre corps hors du bloc deroule.
        ; L'entree vaut base + (16 - m) * taille_unite ; pour m = 0 elle
        ; tombe donc pile sur la fin du bloc, ce qui saute le deroulement.
        ;
        ; m <= 16 est un invariant du moteur : les familles deroulees
        ; d'origine avaient exactement 16 entrees, et
        ; fn_entity_recompute_screen_bbox masque la largeur par #0F.
        ld    a,(clip_col_n)
        ld    b,a
        ld    a,(clip_trim_first)
        and    a
        jr    z,clip_su_no_tf
        dec    b
clip_su_no_tf:
        ld    a,(clip_trim_last)
        and    a
        jr    z,clip_su_no_tl
        dec    b
clip_su_no_tl:
        ld    a,#10
        sub    b                          ; 16 - m
        jr    nc,clip_su_index_ok
        xor    a                          ; m > 16 : hors invariant, on
                                          ; retombe sur l'entree 16 colonnes
clip_su_index_ok:
        ld    l,a
        ld    h,#00
        ld    a,(clip_shift)
        and    a
        jr    z,clip_su_aligned
        add    hl,hl                      ; x2
        ld    d,h
        ld    e,l
        add    hl,hl                      ; x4
        add    hl,hl                      ; x8
        add    hl,hl                      ; x16
        add    hl,de                      ; x18 = taille de l'unite decalee
        ld    de,clip_shift_unroll
        add    hl,de
        ld    (clip_shift_run_op),hl
        ret
clip_su_aligned:
        add    hl,hl                      ; x2
        ld    d,h
        ld    e,l
        add    hl,hl                      ; x4
        add    hl,hl                      ; x8
        add    hl,de                      ; x10 = taille de l'unite alignee
        ld    de,clip_aligned_unroll
        add    hl,de
        ld    (clip_align_run_op),hl
        ret

; ============================================================
clip_blit:
        ; Dessine le sprite courant, ecrete a [clip_rect_ymin,
        ; clip_rect_ymax] x [col0+clip_col_skip, +clip_col_n[.
        ;
        ; Les lignes montent l'ecran (screen_y + 1 par ligne, confirme :
        ; l'original avancait de +64 par ligne dans le buffer, dont
        ; l'adresse est #9000 + y*64). L'equivalent VRAM est -#0800, avec
        ; correction +#37B0 au franchissement de bande vers le haut,
        ; detecte par le passage de B sous #C0 (bit 6 retombe a 0).
        ;
        ; screen_y croissant, on peut donc SORTIR des qu'on depasse
        ; clip_rect_ymax : les lignes suivantes sont toutes au-dessus.
        ld    bc,(clip_addr0)
        ld    de,(clip_shape)
        ld    a,(clip_page)
        ld    h,a
        ld    a,(ix+off_screen_y)
        ld    (clip_cur_y),a
        ld    a,(clip_h)
        ld    (clip_rows_left),a
        ld    a,(clip_shift)
        and    a
        jp    z,clip_blit_aligned_row
        ; ================= variante a decalage sub-octet =================
clip_blit_shift_row:
        ld    a,(clip_cur_y)
        ld    l,a
        ld    a,(clip_rect_ymax)
        cp    l
        ret    c                          ; ymax < y : termine
        ld    a,(clip_rect_ymin)
        cp    l
        jr    z,clip_blit_shift_draw
        jr    c,clip_blit_shift_draw
        ; ligne sous la fenetre : sauter les donnees de la ligne
        ld    a,(clip_w_data)
        add    a,e
        ld    e,a
        ld    a,d
        adc    a,#00
        ld    d,a
        jp    clip_blit_shift_next
clip_blit_shift_draw:
        push    bc                        ; debut de ligne
        ld    a,(clip_col_skip)
        add    a,e
        ld    e,a
        ld    a,d
        adc    a,#00
        ld    d,a
        ld    a,(clip_col_skip)
        add    a,c
        ld    c,a
        ld    a,b
        adc    a,#00
        ld    b,a
        ; --- 1re colonne rognee a gauche ? (son 1er octet est hors fenetre) ---
        ld    a,(clip_trim_first)
        and    a
        jr    z,clip_blit_shift_col
        ld    a,(de)
        inc    de
        ld    l,a
        inc    bc                        ; sauter le 1er octet ecran
        inc    h
        inc    h
        ld    a,(bc)
        and    (hl)                      ; page H+2 = masque 2
        inc    h
        or    (hl)                       ; page H+3 = couleur 2
        ld    (bc),a
        dec    h
        dec    h
        dec    h
        ; pas de compteur : le cas "c'etait la seule colonne" (m = 0) est
        ; porte par l'entree du deroulement, qui pointe alors directement
        ; sur clip_blit_shift_after.
clip_blit_shift_col:
        ; [2026-08-19, deroulement] Saut vers le bloc deroule, a une entree
        ; qui depend du nombre de colonnes PLEINES a dessiner. L'operande
        ; est pokee une fois par (entite, rectangle) par clip_setup_unroll
        ; -- jamais par ligne. C'est le meme mecanisme "duff device" que les
        ; familles d'origine, avec deux differences : l'index vient du
        ; nombre de colonnes ECRETEES (et non de la largeur du sprite), et
        ; le bloc est unique au lieu d'etre duplique par largeur.
        jp    clip_shift_unroll
clip_shift_run_op equ $-2

clip_shift_unroll:
        ; 16 unites identiques a l'unite deroulee d'origine (18 octets),
        ; avec `inc bc` au lieu de `inc c` : l'original ne propageait pas la
        ; retenue, ce qui est faux en VRAM ou les debuts de ligne ne sont
        ; pas alignes sur une page.
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
        ASSERT $ - clip_shift_unroll == 16*18
clip_blit_shift_after:
        ; Cible du cas m = 0 (toutes les colonnes de la fenetre sont des
        ; colonnes de bord rognees) : le bloc deroule est simplement saute.
        ld    a,(clip_trim_last)
        and    a
        jp    z,clip_blit_shift_row_tail
        ; --- derniere colonne rognee a droite : 1er octet seulement ---
        ld    a,(de)
        inc    de
        ld    l,a
        ld    a,(bc)
        and    (hl)
        inc    h
        or    (hl)
        dec    h
        ld    (bc),a
        inc    bc                        ; 2e octet supprime
clip_blit_shift_row_tail:
        ld    a,(clip_col_after)
        add    a,e
        ld    e,a
        ld    a,d
        adc    a,#00
        ld    d,a
        pop    bc                         ; debut de ligne
clip_blit_shift_next:
        call    clip_next_row
        jp    nz,clip_blit_shift_row
        ret
        ; ================= variante alignee-octet =================
clip_blit_aligned_row:
        ld    a,(clip_cur_y)
        ld    l,a
        ld    a,(clip_rect_ymax)
        cp    l
        ret    c
        ld    a,(clip_rect_ymin)
        cp    l
        jr    z,clip_blit_aligned_draw
        jr    c,clip_blit_aligned_draw
        ld    a,(clip_w_data)
        add    a,e
        ld    e,a
        ld    a,d
        adc    a,#00
        ld    d,a
        jp    clip_blit_aligned_next
clip_blit_aligned_draw:
        push    bc
        ld    a,(clip_col_skip)
        add    a,e
        ld    e,a
        ld    a,d
        adc    a,#00
        ld    d,a
        ld    a,(clip_col_skip)
        add    a,c
        ld    c,a
        ld    a,b
        adc    a,#00
        ld    b,a
clip_blit_aligned_col:
        jp    clip_aligned_unroll
clip_align_run_op equ $-2

clip_aligned_unroll:
        ; 16 unites identiques a l'unite alignee d'origine (10 octets).
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
        ASSERT $ - clip_aligned_unroll == 16*10
clip_blit_aligned_after:
        ld    a,(clip_col_after)
        add    a,e
        ld    e,a
        ld    a,d
        adc    a,#00
        ld    d,a
        pop    bc
clip_blit_aligned_next:
        call    clip_next_row
        jp    nz,clip_blit_aligned_row
        ret

clip_next_row:
        ; BC : ligne suivante vers screen_y + 1 (-#0800, +#37B0 si on
        ; passe sous #C000). Incremente clip_cur_y, decremente
        ; clip_rows_left et rend Z = plus de lignes.
        ; Preserve DE et HL.
        ld    a,b
        sub    #08
        ld    b,a
        bit    6,b
        jr    nz,clip_next_row_no_wrap
        ld    a,c
        add    a,#B0
        ld    c,a
        ld    a,b
        adc    a,#3F
        ld    b,a
clip_next_row_no_wrap:
        ld    a,(clip_cur_y)
        inc    a
        ld    (clip_cur_y),a
        ld    a,(clip_rows_left)
        dec    a
        ld    (clip_rows_left),a
        ret

fn_vram_clip_end:
