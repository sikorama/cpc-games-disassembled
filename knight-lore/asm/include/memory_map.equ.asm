; ============================================================
; memory_map.equ.asm -- variables RAM basse (var_*) et zones haute
; memoire de reference (buffer de pre-rendu, VRAM).
;
; N'APPARAISSENT PAS ici les symboles qui sont deja des LABELS reels
; emis par le generateur dans asm/code/*.asm (struct_entities_base,
; buf_visible_entities, tbl_entity_logic_dispatch, tbl_sound_dispatch,
; tbl_object_catalog, etc.) -- les redeclarer ici en EQU causerait une
; double definition du meme symbole. Ce fichier ne contient QUE les
; adresses qui n'ont pas de label propre (variables zero-page isolees
; dans la zone reservee #0055-#00D6, tbl_room_connections/
; tbl_hud_slot_icons/struct_sound_channel_slot dans la meme zone) et les
; zones #8000+ qui n'ont ni code ni donnees chargees (RAM d'execution
; pure -- demande explicite de l'utilisateur).
;
; Source : docs/SYMBOLS.md, section "Variables RAM basse".
; ============================================================

; --- Variables RAM basse (dans zone_var_ram_basse, #0055-#00D6) ---
var_newgame_random_seed        equ     #0068   ; confirmed -- graine de hasard de lancement de partie
var_frame_counter              equ     #006A   ; hypothesis -- compteur global incremente 1x/frame
var_input_mode_flag            equ     #006C   ; confirmed -- bit1 = selecteur clavier/joystick
var_pseudo_random_acc          equ     #006D   ; hypothesis -- accumulateur pseudo-aleatoire (melange avec R)
var_interrupt_sync_flag        equ     #006F   ; confirmed -- flag interruptions permises/synchro prete (voir fn_arm/disarm/check_interrupt_flag)
var_blit_stack_counter         equ     #0070   ; confirmed -- nb de bandes de blit empilees ce tour
var_camera_reference           equ     #0071   ; confirmed -- position de reference room (X)
var_camera_reference_y         equ     #0072   ; confirmed -- position de reference room (Y)
var_sparkle_and_jingle_phase   equ     #0073   ; confirmed (2026-08-10) -- compteur cyclique 0-7, ex-var_room_data_field
var_room_data_field_2          equ     #0074   ; hypothesis -- 3e octet de tbl_room_master_coords
var_room_reset_flag_1          equ     #0075   ; hypothesis -- remis a 0 par fn_init_room
var_room_reset_flag_2          equ     #0076   ; hypothesis -- remis a 0 par fn_init_room
var_transform_flag_and_saved_type equ  #0077   ; confirmed -- double role : flag de demande PUIS type sauvegarde
var_room_transition_flag       equ     #0078   ; confirmed (2026-08-10) -- teste en tete de fn_init_room, appelle fn_object_catalog_writeback si non-nul
var_object_notify_flag         equ     #007A   ; hypothesis -- "objet vient d'etre obtenu"
var_sound_mixer_mask            equ     #0098   ; confirmed (2026-08-10) -- masque accumule du registre mixer PSG (7), un bit par canal x tons/bruit
var_sound_click_pitch_index     equ     #009A   ; confirmed (2026-08-10) -- index rotatif (mod 8) dans tbl_sound_click_pitch_palette (#09FF)
var_input_result                equ     #007B   ; confirmed -- resultat final du scan input
var_render_disabled_flag       equ     #007D   ; confirmed -- si non-zero, fn_render_entities sort immediatement
var_day_counter                 equ     #007F   ; confirmed -- compteur de jours (BCD)
var_life_counter                 equ     #0080   ; confirmed -- compteur de vies du joueur (valeur pleine 4)
var_pickup_sequence_counter     equ     #0081   ; hypothesis -- compteur 0-14 (puzzle de collecte hypothetique)
var_entity_update_counter       equ     #0082   ; hypothesis -- incremente dans la boucle update par-entite
var_room_reset_flag_3           equ     #0083   ; hypothesis -- verrou "une seule boule a pics active" a l'usage
var_blit_stack_accumulator      equ     #0084   ; confirmed -- accumulateur cumulatif du nb de bandes de blit
var_room_reset_flag_4           equ     #0085   ; hypothesis -- verrou actif pendant le jeu (voir fn_ceiling_spike_ball_logic)
var_room_reset_flag_5           equ     #0086   ; hypothesis -- garde globale, role exact incertain
var_special_input_mode_1        equ     #0089   ; hypothesis -- garde testee en tete de fn_read_input
var_special_input_mode_2        equ     #008A   ; hypothesis -- garde testee en tete de fn_read_input
var_glyph_table_base            equ     #008C   ; confirmed -- base de la table de police active (menu)
var_entity_list_cursor          equ     #0090   ; confirmed -- curseur de parcours de buf_visible_entities
var_collision_ix_cursor         equ     #0092   ; confirmed -- curseur de parcours externe (fn_check_collisions)
var_collision_iy_cursor         equ     #0094   ; confirmed -- curseur de parcours interne (fn_check_collisions)
struct_sound_channel_slot       equ     #009B   ; confirmed -- 3 slots de 4 octets (canaux 0/1/2 du moteur son)
tbl_hud_slot_icons              equ     #00AB   ; hypothesis -- 3 octets, un par slot HUD

; --- Table dans la zone reservee du tableau d'entites (#00D7-#0536) ---
tbl_room_connections            equ     #0147   ; confirmed -- connexions de la room courante (jusqu'a 4 x 56 octets)
var_room_visited_bitmap         equ     #00B7   ; hypothesis (structure certaine) -- 32 octets/256 bits, bit (room_number&7) de l'octet (00B7+room_number/8), pose par fn_init_room_mark_room_visited #2A9A
var_player_room_number          equ     #00DF   ; confirmed -- struct_entities_base+off_room_number pour l'entite 0 (joueur)

; --- Variable isolee, hors zero-page (dans le CODE zone, jamais executee) ---
var_day_night_flag              equ     #1CFA   ; hypothesis (multi-bits) -- bit0 = jour/nuit, bit2 = role distinct

; --- Constantes de boot ---
; [branche vram-direct-experiment, 2026-08-19] STACK_TOP_INIT n'est plus
; #8100 : l'objectif est de liberer tout #8000-#BFFF pour un double
; buffer, la pile est donc descendue dans zone_stack (#2D9B-#2DE1, 71
; octets fabriques dans la zone de code -- voir le commentaire de
; zone_stack dans code/rendering_pipeline.asm). C'est un LABEL, pas un
; EQU : la valeur suit automatiquement le decoupage du fichier.
STACK_TOP_INIT                   equ     zone_stack_top
TBL_BITSCATTER_BASE              equ     #8100   ; base des tables masque/couleur construites au boot par fn_build_pixel_bitscatter_tables (ex-usage de STACK_TOP_INIT comme adresse de donnees, sans rapport avec la pile)

; --- Zones haute memoire de reference SEULEMENT (aucun org/donnees) ---
; Ni le buffer de pre-rendu ni la VRAM ne contiennent de contenu charge
; depuis le support d'origine : ce sont des zones de RAM d'execution
; pure (reconstruites/dessinees a chaque frame). Demande explicite de
; l'utilisateur : les referencer par symbole, ne jamais tenter d'y
; mettre du code ou des donnees dans ce fichier source.
BUF_PRERENDER_BASE               equ     #9000   ; buffer intermediaire pre-rendu -- CONFIRMED a partir d'ici (image pre-rendue de la salle, largeur 64 octets)
VRAM_BASE                        equ     #C000   ; ecran physique CPC (RAM bank 3, confirme via CRTC R12/R13)

; #8000-#8FFF : statut CONFIRMED (2026-08-09, verification live +
; desassemblage direct) -- ne pas confondre avec BUF_PRERENDER_BASE
; ci-dessus, role different. SP init a #8100 = STACK_TOP_INIT (confirmed,
; fn_cold_boot_entry/#0001) : la pile Z80 active occupe #80D6-#8100.
; #8100-#8FFF = 15 tables de 256 octets CALCULEES AU BOOT (une seule
; fois, jamais recalculees en jeu) par fn_build_pixel_bitscatter_tables
; (#0829, code deja present dans #0000-#3FFF -- voir
; code/dispatch_and_sound.asm) -- pas une donnee chargee depuis le
; support d'origine, pas de la RAM inutilisee non plus, juste du contenu
; RECONSTRUIT par du code qu'on a deja. Voir
; notes/2026-08-09-zone-8000-9000-gap.md pour le detail complet.
; STACK_LOW_WATERMARK (#8010) SUPPRIME : cette borne etait la
; consequence de la file de blits differes (40 entites x 6 octets = 240,
; soit #8100-#8010 pile). Cette file est supprimee sur cette branche, la
; pile ne consomme plus que l'imbrication d'appels.
