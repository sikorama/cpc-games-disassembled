; ============================================================
; vram_direct_rendering.asm -- code NEUF, PAS issu du desassemblage.
; Experimentation "piste 3" de docs/OPTIMISATION.md (branche
; vram-direct-experiment) : dessin direct en VRAM, suppression du
; buffer intermediaire BUF_PRERENDER_BASE (#9000-#BFFF), afin de
; liberer cette zone pour ce fichier. org #9000 choisi en connaissance
; de cause : au moment ou ce fichier est inclus, plus rien ne doit
; encore utiliser le buffer comme buffer -- voir statut plus bas.
;
; STATUT (2026-08-18) :
; - fn_vram_advance_line : extrait de fn_blit_copy_line (#2EC0,
;   code/rendering_pipeline.asm), CONFIRMED -- le mecanisme
;   +0x0800/+0xC050 sur carry est deja utilise a l'identique par
;   fn_clear_screen (#2D9A) ET fn_blit_copy_line, donc pas une
;   hypothese. fn_blit_copy_line a ete refactorisee pour l'appeler
;   (comportement inchange, juste factorise -- voir OPTIMISATION.md
;   §4 "factoriser cette macro d'avance de ligne").
; - fn_vram_fill_rect : NOUVELLE routine, PAS ENCORE BRANCHEE dans le
;   pipeline de rendu. Reprend la structure exacte de fn_fill_rect
;   (#1DC1, loop-unrolling par largeur 1-16 via jr auto-modifiant) mais
;   avance par fn_vram_advance_line au lieu de -64/ligne (buffer,
;   axe Y inverse). Ce qui reste a confirmer AVANT de la brancher : le
;   sens exact (coin haut ou bas du rectangle) de l'adresse VRAM
;   produite par fn_stage_blit_and_clear (#2E6C) pour l'appel a
;   fn_screen_addr_from_bc -- pas resolu par simple lecture statique,
;   necessite une trace live (emulateur). Voir
;   notes/2026-08-18-vram-direct-patch-plan.md.
; ============================================================
        org #9000

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
