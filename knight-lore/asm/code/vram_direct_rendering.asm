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
; EMPLACEMENT (2026-08-19, 2e revision) : blit_vram_free, dans la place
; liberee en remplacant les familles deroulees de fn_blit_masked par de
; vraies boucles. #8100 avait ete choisi le 2026-08-18 comme "zone libre"
; -- FAUX : c'est STACK_TOP_INIT et la zone est ecrasee en cours de jeu
; (constat direct, voir le journal de branche). La zone de code, elle,
; n'est atteignable par aucun debordement de donnees.
        org blit_vram_free

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
        ; [2026-08-19, revision] La queue d'origine (echange BC<->HL puis
        ; call fn_buffer_addr_from_vram) produisait l'adresse BUFFER du
        ; rectangle, consommee par la file de blits differes -- file
        ; supprimee depuis (voir zone_stack, code/rendering_pipeline.asm).
        ; Ses sorties n'etaient plus lues par personne : retiree. Cette
        ; routine ne fait donc plus que le clear VRAM, une fois par
        ; rectangle sale et par frame.
        ret

; ============================================================
; 2026-08-19 -- migration de fn_blit_masked vers le dessin direct VRAM.
; Voir notes/2026-08-18-vram-direct-patch-plan.md, sections "RESOLU
; (2026-08-19)" et "Validation du point 2".
; ============================================================

fn_vram_sprite_addr:
        ; Remplace le bloc #2F76-#2F80 de fn_sprite_pipeline_setup (11
        ; octets : ld l,(ix+16) / ld h,(ix+17) / call
        ; fn_buffer_addr_from_vram / ld b,h / ld c,l), qui produisait
        ; l'adresse dans le BUFFER intermediaire. Produit maintenant
        ; l'adresse VRAM REELLE du meme point.
        ;
        ; IN  : IX = entite courante.
        ; OUT : BC = adresse VRAM de (screen_x, screen_y).
        ; Preserve DE (pointeur donnees de forme, vivant) et HL. AF' n'est
        ; pas touche (il transporte le decalage sub-octet a cet instant).
        ;
        ; NB : fn_screen_addr_from_bc ajoute +8 a l'index de colonne la ou
        ; fn_buffer_addr_from_vram ne l'ajoutait pas -- ce n'est pas un
        ; oubli, les deux conventions d'origine differaient deja ainsi et
        ; se compensaient dans fn_blit_copy_line (qui appariait une adresse
        ; VRAM avec +8 et une adresse buffer sans). En dessinant
        ; directement en VRAM, c'est la convention VRAM qui s'applique.
        push    de
        push    hl
        ld    b,(ix+off_screen_y)
        ld    c,(ix+off_screen_x)
        call    fn_screen_addr_from_bc     ; -> DE = adresse VRAM
        ld    b,d
        ld    c,e
        pop    hl
        pop    de
        ret

; fn_vram_next_row a ete SUPPRIMEE : son role (avance raster vers
; screen_y+1 puis boucle de lignes) est desormais inline dans
; blit_row_end, code/rendering_pipeline.asm.

; ============================================================
; 2026-08-19 (2) -- correctif de la regression "plus rien ne s'efface au
; changement de salle" + "au menu on ne voit que le decor, plus le
; texte". Les deux ont la MEME cause : fn_copy_screen_rect (#2DBF),
; neutralisee le matin, ne faisait pas que "copier le buffer" --
; c'etait aussi (a) le seul effacement plein ecran du chargement de
; salle et (b) le seul chemin par lequel tout ce qui se dessine via
; fn_buffer_addr_from_vram (texte de menu / game over via
; fn_menu_glyph_unpack, compteurs HUD) atteignait la VRAM.
;
; Ces deux roles sont maintenant separes et remis chacun au bon endroit
; du cycle de frame -- c'etait la vraie erreur d'origine, pas la copie
; elle-meme : elle arrivait APRES fn_render_entities (voir l'ordre dans
; fn_main_loop, low_ram_and_boot.asm) et ecrasait donc le decor qui
; venait d'etre dessine.
;   - effacement -> fn_vram_clear_playfield, appele depuis
;     fn_clear_intermediate_buffer, donc AVANT le dessin de la salle.
;   - poussee du buffer -> fn_vram_merge_buffer_to_screen, qui reste a
;     sa place (fn_copy_screen_rect) mais ne detruit plus rien : elle
;     saute les octets nuls du buffer.
; ============================================================

fn_vram_clear_playfield:
        ; Efface la zone de jeu en VRAM : 192 lignes de 64 octets a partir
        ; de #C008 -- EXACTEMENT le rectangle que l'ancienne
        ; fn_copy_screen_rect ecrivait, meme ancre et meme parcours raster
        ; (+0x800, correction +0xC050 sur carry), donc meme couverture au
        ; pixel pres. A la difference de fn_clear_screen (#2D9A) qui prend
        ; tout l'ecran (25 x 80 octets), on epargne les 8 octets de marge
        ; de chaque cote, comme le faisait l'original.
        ;
        ; N'utilise PAS fn_vram_advance_line : celle-ci travaille sur HL et
        ; on a besoin de DE ici ; le mecanisme est identique, recopie sur
        ; place pour eviter un echange HL<->DE par ligne.
        ld    de,#C008
        ld    b,#C0
fn_vram_clear_playfield_row:
        push    bc
        push    de
        ld    b,#40
        xor    a
fn_vram_clear_playfield_byte:
        ld    (de),a
        inc    de
        djnz    fn_vram_clear_playfield_byte
        pop    de
        ld    hl,#0800
        add    hl,de
        jr    nc,fn_vram_clear_playfield_next
        ld    bc,#C050
        add    hl,bc
fn_vram_clear_playfield_next:
        ex    de,hl
        pop    bc
        djnz    fn_vram_clear_playfield_row
        ret

fn_vram_clear_playfield_and_buffer:
        ; Remplace le corps de fn_clear_intermediate_buffer (#2DB7), qui
        ; n'effacait que le buffer intermediaire. Ses 4 sites d'appel
        ; pointent maintenant directement ici.
        ;
        ; [2026-08-19, revision] Le memset #9000-#BFFF a ete SUPPRIME : le
        ; chemin glyphes (fn_vram_addr_from_yx + fn_menu_glyph_unpack) etant
        ; migre a son tour, plus AUCUN code n'ecrit ni ne lit le buffer
        ; intermediaire. Le nom garde "_and_buffer" par continuite des
        ; appelants ; il n'efface plus que la VRAM. 12 Ko de memset
        ; economises a chaque chargement de salle.
        jp    fn_vram_clear_playfield

fn_vram_merge_buffer_to_screen:
        ; Remplacait fn_copy_screen_rect (#2DBF). Faisait la copie
        ; buffer -> VRAM en sautant les octets nuls, pour que le texte et
        ; les compteurs -- encore dessines dans le buffer -- atteignent
        ; l'ecran sans effacer le decor dessine en VRAM.
        ;
        ; [2026-08-19, revision] VIDEE : `ret` seul. Le chemin glyphes est
        ; migre (fn_vram_addr_from_yx rend une adresse VRAM,
        ; fn_menu_glyph_unpack avance en entrelace), donc le buffer est
        ; vide en permanence et cette fusion ne pouvait plus rien apporter.
        ; C'etait la derniere recopie #9000 -> #C000 du jeu.
        ;
        ; Conservee comme stub plutot que supprimee : ses 3 appelants
        ; (low_ram_and_boot.asm:321 pendant la materialisation,
        ; menu_and_materialize.asm:102, entity_logic_mechanical.asm:662
        ; game over) restent assemblables sans etre touches.
        ret

fn_clear_screen:
        ; RELOGEE ici le 2026-08-19 (etait a #2D9B) : ses 28 octets font
        ; partie des 71 rendus a zone_stack (voir le gros commentaire dans
        ; code/rendering_pipeline.asm). Corps INCHANGE, copie a
        ; l'identique -- ce n'est pas une reecriture, juste un
        ; deplacement. Tous ses appelants (low_ram_and_boot.asm:179,
        ; entity_logic_mechanical.asm:616,708) l'appellent par symbole,
        ; donc rien a changer chez eux.
        ;
        ; Efface l'ecran COMPLET (#C000, 25 x 80 octets, marges incluses),
        ; a ne pas confondre avec fn_vram_clear_playfield ci-dessus qui se
        ; limite a la zone de jeu 192 x 64 a partir de #C008.
        ld    hl,VRAM_BASE
        ld    c,#19
fn_clear_screen_band:
        ld    b,#50
        push    hl
fn_clear_screen_byte:
        ld    (hl),#00
        inc    hl
        djnz    fn_clear_screen_byte
        pop    hl
        ld    de,#0800
        add    hl,de
        jr    nc,fn_clear_screen_band
        ld    de,#C050
        add    hl,de
        dec    c
        jr    nz,fn_clear_screen_band
        ret

; ============================================================
; NON BRANCHEE (mesure du 2026-08-19 au soir) -- conservee comme resultat
; d'experience. Branchee, elle corrige bien le defaut, mais elle CASCADE :
; les blocs de decor d'une salle se touchent tous, donc la fermeture
; transitive du chevauchement est la salle entiere des qu'un seul
; rectangle sale existe. Le jeu devient extremement lent, et le resultat
; est equivalent a « tout redessiner chaque frame » avec le cout du
; balayage en plus. L'analyse ci-dessous reste valide ; c'est la
; PROPRIETE GEOMETRIQUE de la scene (decor connexe) qui rend l'approche
; inutilisable, pas l'implementation.
; Conclusion : seule l'option 3 (ecreter le blit aux rectangles sales)
; peut fonctionner. Voir notes/2026-08-18-vram-direct-patch-plan.md.
; ============================================================
; 2026-08-19 (soir) -- FERMETURE DU MARQUAGE « a redessiner ».
;
; POURQUOI. Le buffer intermediaire ne servait pas seulement a composer
; l'image : la copie differee ne publiait vers la VRAM que les
; RECTANGLES SALES. Le buffer avait donc le droit d'etre localement FAUX
; hors de ces rectangles -- un bloc de decor redessine y ecrasait les
; pixels d'un objet situe devant lui, sans consequence puisque cette zone
; n'etait pas publiee, et la zone etait de toute facon reparee (toutes les
; entites qui la chevauchent remarquees et redessinees dans l'ordre de
; profondeur) avant de devenir publiable. Schema paresseux.
;
; Le dessin direct supprime cette fenetre de publication : chaque sprite
; redessine publie TOUTE son etendue immediatement, donc la corruption
; devient visible. Symptome observe : en room 0x4F, une boule a pics au
; plafond disparait au profit du mur quand le joueur descend (le
; rectangle sale s'etend vers le bas, n'atteint pas la boule, donc la
; boule n'est pas remarquee ; le bloc de mur derriere le joueur l'est, et
; se redessine en entier par-dessus la boule). En montant, le rectangle
; atteint la boule, qui est remarquee et redessinee apres le mur : pas de
; defaut. La dependance au SENS de deplacement est la signature du
; mecanisme.
;
; CE QUI EST REQUIS. Invariant d'origine : le composite n'a besoin d'etre
; juste que DANS les rectangles publies. Invariant en dessin direct : si
; une entite E est redessinee, toute entite chevauchant E doit l'etre
; aussi, TRANSITIVEMENT. Le marquage du jeu
; (fn_entity_fall_and_mark_overlap #25FF, appelee par loc_1F7B) ne fait
; que le premier anneau, a partir du rectangle sale du seul mobile.
;
; CE QUE FAIT CETTE ROUTINE. Elle calcule le point fixe de ce marquage,
; en reutilisant telle quelle la routine du jeu : pour chaque entite
; portant bit4, remarquer celles qui chevauchent SA bbox ecran, et
; recommencer tant que le nombre d'entites marquees augmente.
; fn_entity_fall_and_mark_overlap convient sans modification -- pour une
; entite statique, bbox precedente == courante, donc l'union qu'elle
; utilise EST sa bbox ; et son fn_entity_recompute_screen_bbox (#25E5) est
; pur (reprojection + screen_w/h) et donne la hauteur NON ecretee, ce qui
; est justement ce qu'il faut pour un test de chevauchement.
;
; L'ensemble redessine est ainsi exactement celui qui etait corrompu :
; minimal et correct, l'optimisation par rectangles sales est conservee.
;
; PLACEMENT DANS LA FRAME : AVANT fn_cull_entities, qui figera
; buf_visible_entities pour la frame -- d'ou le tail-call. Le point
; d'appel (low_ram_and_boot.asm) passe de `call fn_cull_entities` a
; `call fn_mark_closure_then_cull`, meme longueur.
;
; On ne pose QUE bit4 (« a redessiner »), jamais bit5 (« effacer
; l'ancienne position ») : ces entites n'ont pas bouge.
;
; BORNE : 4 passes maximum. La convergence naturelle demande 2 a 3 passes
; (un anneau de sprites de taille comparable) ; la borne evite qu'une
; scene chargee ne coute un temps non borne. Une entite marquee est
; re-etendue a chaque passe (pas de marqueur « deja etendu » faute de
; place sous #8000) -- sans effet puisque ses voisines portent deja bit4,
; mais cela coute un balayage de 40 entites.
;
; RISQUE A SURVEILLER : plus d'entites redessinees = plus de paires
; traitees par le tri en profondeur, donc plus de pression sur
; tbl_collision_pending (#28AF), qui fait 8 octets et deborde SANS
; controle de borne au-dela de 7 reports simultanes (bug latent du moteur
; d'origine, voir la note de session).
; ============================================================

fn_mark_closure_then_cull:
        push    ix
        push    iy
        ld    a,#04                  ; borne de passes
fn_mark_closure_pass:
        ld    (fn_mark_closure_budget),a
        call    fn_mark_count        ; C = compte avant la passe
        push    bc
        ld    ix,struct_entities_base
        ld    b,#28
fn_mark_closure_outer:
        ld    a,(ix+off_type)
        and    a
        jr    z,fn_mark_closure_next
        bit    4,(ix+off_flags)
        jr    z,fn_mark_closure_next
        push    bc
        push    ix
        call    fn_entity_fall_and_mark_overlap
        pop    ix
        pop    bc
fn_mark_closure_next:
        ld    de,#001C
        add    ix,de
        djnz    fn_mark_closure_outer
        call    fn_mark_count        ; C = compte apres la passe
        pop    de                    ; E = compte avant
        ld    a,c
        cp    e
        jr    z,fn_mark_closure_done ; point fixe atteint
        ld    a,(fn_mark_closure_budget)
        dec    a
        jr    nz,fn_mark_closure_pass
fn_mark_closure_done:
        pop    iy
        pop    ix
        jp    fn_cull_entities       ; tail-call : remplace l'appel d'origine

fn_mark_closure_budget:
        defb  #00

fn_vram_direct_end:
