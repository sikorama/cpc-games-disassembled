; ============================================================
; vram_direct_rendering.asm -- code NEUF, PAS issu du desassemblage.
; Experimentation "piste 3" de docs/OPTIMISATION.md (branche
; vram-direct-experiment) : dessin direct en VRAM, suppression du
; buffer intermediaire BUF_PRERENDER_BASE (#9000-#BFFF).
;
; EMPLACEMENT (2026-08-18, revise) : org #8100, PAS #9000. Premiere
; tentative (#9000-#90FF, meme en reduisant la plage effacee par
; fn_clear_intermediate_buffer) a plante en jeu reel -- voir
; notes/2026-08-18-vram-direct-patch-plan.md, "tentative de branchement".
; #8100-#81FF est un bien meilleur choix : table CONFIRMEE construite
; UNE SEULE FOIS au boot (fn_build_pixel_bitscatter_tables,
; code/dispatch_and_sound.asm #0854-#086E, neutralisee en nop) et jamais
; lue par aucun code (voir docs/SYMBOLS.md #0829/#2F8D) -- contrairement
; a #9000-#BFFF (buffer intermediaire), rien n'y ecrit plus une fois le
; boot termine, donc le code y reste intact en permanence.
;
; STATUT (2026-08-18) :
; - fn_vram_advance_line : extrait de fn_blit_copy_line (#2EC0,
;   code/rendering_pipeline.asm), CONFIRMED -- le mecanisme
;   +0x0800/+0xC050 sur carry est deja utilise a l'identique par
;   fn_clear_screen (#2D9A) ET fn_blit_copy_line, donc pas une
;   hypothese. fn_blit_copy_line a ete refactorisee pour l'appeler
;   (comportement inchange, juste factorise -- voir OPTIMISATION.md
;   §4 "factoriser cette macro d'avance de ligne").
; - fn_vram_fill_rect : avance avec fn_vram_advance_line (+0x800), ce qui
;   MONTE l'écran (confirmé par calcul à la main de deux B consécutifs,
;   #FB45 pour B=104 vs #F345 pour B=105, donc -0x800 quand on descend
;   d'une ligne -- voir le correctif du 2026-08-18 après-midi dans
;   fn_stage_clear_vram_and_buffer_addr ci-dessous, une 1re version avait
;   conclu l'inverse et provoqué des rectangles effacés trop bas en jeu
;   réel). Doit donc recevoir le coin BAS du rectangle en entrée, pas le
;   haut -- exactement ce que fn_screen_addr_from_bc produit déjà dans
;   l'appelant, aucun recalcul necessaire.
; - fn_stage_clear_vram_and_buffer_addr : NOUVEAU, branché dans
;   fn_stage_blit_and_clear (code/rendering_pipeline.asm) à la place des
;   9 octets originaux (swap BC<->HL + call fn_buffer_addr_from_vram) --
;   reproduit ce même calcul PLUS le clear direct VRAM. Ce clear direct
;   est pour l'instant REDONDANT (fn_blit_masked dessine encore dans le
;   buffer intermédiaire, donc la copie différée fn_blit_copy_line écrase
;   de toute façon ce qu'on vient d'écrire en VRAM) -- objectif de cette
;   étape : valider fn_vram_fill_rect/fn_vram_advance_line en conditions
;   réelles sans rien casser, avant de retirer le chemin buffer. Prochaine
;   étape : migrer fn_sprite_pipeline_setup/fn_blit_masked (voir plan).
; ============================================================
        org #8100

fn_vram_advance_line:
        ; Avance une adresse VRAM d'une ligne (raster), gere
        ; l'entrelacement CRTC. IN/OUT: HL=adresse. Mecanisme identique
        ; a celui de fn_clear_screen (#2D9A) et de l'ancien
        ; fn_blit_copy_line (#2EC0) : +0x0800 systematique, correction
        ; +0xC050 quand cet ajout deborde 0xFFFF (le decoupage VRAM en
        ; blocs de 0x4000 = 8x0x0800 fait que ce debordement survient
        ; exactement tous les 8 lignes -- pas une coincidence).
        ld    de,#0800
        add    hl,de
        ret    nc
        ld    de,#C050
        add    hl,de
        ret

fn_vram_fill_rect:
        ; Variante VRAM-directe de fn_fill_rect (#1DC1, voir
        ; code/objects_and_rooms_setup.asm) : remplit un rectangle
        ; directement en VRAM au lieu du buffer intermediaire, meme
        ; convention d'entree qu'a l'origine (A=octet de remplissage,
        ; B=largeur en octets 1-16, C=hauteur en lignes, HL=adresse de
        ; depart) sauf que HL est ici une adresse VRAM reelle et
        ; l'avance de ligne passe par fn_vram_advance_line (avance vers
        ; le bas de l'ecran) au lieu de -64/ligne (artefact axe Y
        ; inverse du buffer, qui n'a plus lieu d'etre ici).
        ;
        ; NE PAS BRANCHER tant que le sens (haut/bas de rect) de
        ; l'adresse d'entree n'est pas confirme -- voir statut en tete
        ; de fichier.
        push    af
        ld    a,b
        neg
        and    #0F
        add    a,a
        ld    (fn_vram_fill_rect_jr_disp),a
        ld    b,c
        pop    af
fn_vram_fill_rect_row:
        push    hl
        push    bc
fn_vram_fill_rect_jr:
        jr    fn_vram_fill_rect_half2
fn_vram_fill_rect_jr_disp equ fn_vram_fill_rect_jr+1
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
fn_vram_fill_rect_half2:
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
        pop    bc
        pop    hl
        call    fn_vram_advance_line
        djnz    fn_vram_fill_rect_row
        ret

fn_stage_clear_vram_and_buffer_addr:
        ; Appelee depuis fn_stage_blit_and_clear (#2E6C,
        ; code/rendering_pipeline.asm) juste apres son premier
        ; fn_screen_addr_from_bc (coin BAS du rectangle, voir statut en
        ; tete de fichier). Remplace 9 octets originaux (swap BC<->HL +
        ; call fn_buffer_addr_from_vram) -- reproduit ce calcul A
        ; L'IDENTIQUE (meme etat BC/DE/HL en sortie qu'avant, l'appelant
        ; continue sans savoir que ce clear existe), plus le nouveau clear
        ; direct VRAM avant.
        ;
        ; Entree : BC=(B_used=bas du rect,C=screen_x), DE=adresse VRAM du
        ; coin BAS (issue du 1er fn_screen_addr_from_bc), HL=(width,height)
        ; intact depuis l'entree de fn_stage_blit_and_clear.
        ;
        ; CORRECTION 2026-08-18 (apres glitchs visuels constates en jeu --
        ; rectangles effaces trop bas) : la version precedente recalculait
        ; un pretendu "coin haut" via un 2e appel a fn_screen_addr_from_bc,
        ; en supposant +0x800 = descendre l'ecran. FAUX -- reverifie a la
        ; main (B=104 vs B=105, meme colonne : #FB45 vs #F345, soit
        ; -0x800 quand on descend d'une ligne) : +0x800 = MONTER l'ecran.
        ; fn_blit_copy_line (l'original, prouve fonctionnel) part deja du
        ; coin BAS (le seul DE calcule par l'appelant) et avance avec
        ; +0x800 -- donc vers le haut, en miroir du buffer source dont
        ; l'axe Y est deja inverse (-64/ligne). Pas besoin de recalculer
        ; quoi que ce soit : reutiliser directement ce DE existant, comme
        ; le fait deja fn_blit_copy_line.
        push    bc
        push    de
        push    hl
        ld    b,h
        ld    c,l
        xor    a
        ex    de,hl
        call    fn_vram_fill_rect
        pop    hl
        pop    de
        pop    bc
        ; --- fin clear VRAM direct -- logique originale reprend ici ---
        ld    a,c
        ld    c,l
        ld    l,a
        ld    a,b
        ld    b,h
        ld    h,a
        call    fn_buffer_addr_from_vram
        ret
