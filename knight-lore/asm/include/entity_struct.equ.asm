; ============================================================
; entity_struct.equ.asm -- structure d'entite (struct_entities_base,
; 28 octets/entite, tableau ACTIF de 40 entites #00D7-#0536).
; Source : docs/SYMBOLS.md, section "Structure d'entite".
; Offsets en hexadecimal (#), prefixe off_ pour ne pas les confondre
; avec les labels d'adresse (fn_/tbl_/var_/struct_).
; ============================================================

; struct_entities_base (#00D7) N'EST PAS declare ici en EQU : c'est un
; label reel emis par le generateur dans asm/code/low_ram_and_boot.asm
; (debut de la zone reservee du tableau d'entites). Le declarer aussi en
; EQU ici causerait une double definition du meme symbole.
struct_entity_size     equ     #1C     ; 28 octets par entite
struct_entity_count    equ     #28     ; 40 slots actifs (0x0537-0x00D7)/0x1C

off_type                equ     #00     ; type/ID de sprite -- indexe tbl_sprite_dispatch ET tbl_entity_logic_dispatch
off_grid_x              equ     #01     ; coordonnee de grille, axe combine par somme
off_grid_y              equ     #02     ; coordonnee de grille, axe combine par somme/difference
off_grid_z_or_offset    equ     #03     ; offset additif du 2e axe projete (hauteur)
off_bbox_w              equ     #04     ; dimension bbox (hypothesis)
off_bbox_h              equ     #05     ; dimension bbox (hypothesis)
off_bbox_d              equ     #06     ; dimension bbox (hypothesis)
off_flags               equ     #07     ; bit4 a retraiter, bit5 en cours, bit6 orientation
off_room_number         equ     #08     ; numero de room courant (confirmed -- nibble bas=grid_x, nibble haut=grid_y, voir fn_player_door_transition)
; +09..+0B : inconnus (vus a 0 sur l'entite joueur), sauf usage ponctuel
; comme vecteur de deplacement pour rst_apply_movement_vector (+09/+0A/+0B)
off_cooldown_or_collision_flags equ #0C ; cooldown d'action (joueur) OU bits0/1=flags de collision (entites mobiles)
off_state_flags_2       equ     #0D     ; bits testes dans fn_player_logic
off_transform_step_counter equ  #10     ; DOUBLE ROLE selon l'entite (voir docs/SYMBOLS.md #1E67) :
                                        ; - entite 0 (joueur) : compteur de sous-etapes de transformation
                                        ; - entites objet (slots 2/3, #010F/#012B) : pointeur 16 bits
                                        ;   (+10=lo, +11=hi) vers leur propre entree tbl_object_catalog,
                                        ;   pose par fn_instantiate_room_objects (#1DFB), relu par
                                        ;   fn_object_catalog_writeback (#1E67)
off_proj_offset_x       equ     #12     ; offset de calibration projection isometrique
off_proj_offset_y       equ     #13     ; offset de calibration projection isometrique
off_screen_w            equ     #14     ; bbox ecran courante (largeur)
off_screen_h            equ     #15     ; bbox ecran courante (hauteur)
off_screen_x            equ     #16     ; position ecran projetee courante (X)
off_screen_y            equ     #17     ; position ecran projetee courante (Y)
off_screen_w_prev       equ     #18     ; copie frame precedente (pour effacement)
off_screen_h_prev       equ     #19
off_screen_x_prev       equ     #1A
off_screen_y_prev       equ     #1B
off_type_mirror_plus_10 equ     #1C     ; = type_final + #10, ecrit par fn_player_transform_complete
off_pending_grid_x      equ     #1D     ; sauvegarde grid_x pendant une transition de room
off_pending_grid_y      equ     #1E     ; sauvegarde grid_y pendant une transition de room
off_room_transition_extra equ   #1F     ; = nouveau numero de room + #0C
off_busy_flag           equ     #23     ; bit1 verrou temporaire, bit4 pose par fn_room_transition
; +2C : champ de la DEUXIEME entite du template (= entite[1].+0x10)
