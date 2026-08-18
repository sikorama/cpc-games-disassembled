        BANKSET 0
        BUILDSNA V2
        RUN #0000
        snaset GA_ROMCFG,#8C
        snaset ROM_UP,#FF
; ============================================================
; Knight Lore (Amstrad CPC, 1984 Ultimate Play The Game) -- premier
; essai de desassemblage annote et reassemblable.
;
; Point d'entree machine : #0000 (fn_cold_boot_entry, voir
; code/low_ram_and_boot.asm). Le "menu" au sens large (attente de
; selection clavier/joystick + lancement d'une partie) est enchaine
; depuis fn_boot_init_and_new_game (#0537) ; le retour au menu apres un
; game over utilise le point d'entree alternatif fn_restart_from_menu
; (#0542), qui rejoint le meme code -- voir asm/README.md et
; docs/SYMBOLS.md pour le detail du desassemblage qui a etabli ceci.
;
; Etat de ce premier essai, portee et limites : voir asm/README.md.
; Genere mecaniquement par tools/gen_asm.py depuis asm/symbols.json
; (table de symboles a jour, sans narration -- docs/SYMBOLS.md reste le
; journal d'investigation detaille, potentiellement en retard).
; ============================================================

; --- Definitions (EQU), aucun org/code ---
        include "include/memory_map.equ.asm"
        include "include/entity_struct.equ.asm"
        include "include/entity_types.equ.asm"
        include "include/ports.equ.asm"

; --- Code, dans l'ordre d'adresse (#0000-#3FFF, zone confirmee
; executee par codemap) ---
        include "code/low_ram_and_boot.asm"              ; #0000-#0675
        include "code/dispatch_and_sound.asm"             ; #0676-#0FD7
        include "code/entity_logic_mechanical.asm"        ; #0FD8-#170C
        include "code/menu_and_materialize.asm"           ; #170D-#1A18
        include "code/pickups_and_transform.asm"          ; #1A19-#1D26
        include "code/objects_and_rooms_setup.asm"        ; #1D27-#1FE1
        include "code/doors_and_player_logic.asm"         ; #1FE2-#26F6
        include "code/collision_and_input.asm"            ; #26F7-#2A32
        include "code/room_init_and_nav.asm"              ; #2A33-#2D5D
        include "code/rendering_pipeline.asm"             ; #2D5E-#3185
        include "code/screen_addressing_and_tables.asm"   ; #3186-#4045 (deborde sur la zone RESSOURCES : tbl_room_connection_detail_3FD5 straddle #3FFF/#4000)

; --- Ressources (#4000+, zone jamais executee -- codemap) : seules les
; tables a extent confirmee sont transcrites, voir asm/README.md ---
        include "data/resources_zone.asm"                 ; #4046-#7FFF

; --- #8000-#80FF (source original / branche main) : AUCUN org/donnees.
; Pile Z80 active dans #80D6-#8100 (confirmed, SP init #8100) -- RAM
; d'execution pure, jamais du contenu charge depuis le support d'origine.

; --- BRANCHE vram-direct-experiment UNIQUEMENT : code NEUF (pas issu du
; desassemblage) a #8100, dans la table que fn_build_pixel_bitscatter_tables
; construisait avant neutralisation de ce sous-bloc (voir
; code/dispatch_and_sound.asm, #0854-#086E) -- CONFIRMEE sans lecteur dans
; tout le jeu, donc reellement libre en permanence (pas de buffer
; intermediaire ecrasant cette zone, contrairement a #9000+). Voir statut
; en tete de code/vram_direct_rendering.asm et
; notes/2026-08-18-vram-direct-patch-plan.md.
        include "code/vram_direct_rendering.asm"          ; #8100-#81FF (NEUF)

; --- #8200-#8FFF (source original / branche main) : AUCUN org/donnees
; ci-dessous -- 14 tables de 256 octets CALCULEES AU BOOT (une seule fois,
; jamais recalculees en jeu) par fn_build_pixel_bitscatter_tables (#0829,
; voir code/dispatch_and_sound.asm), utilisees par fn_blit_masked comme
; paires masque/couleur -- RAM d'execution pure, jamais du contenu charge
; depuis le support d'origine.
;
; --- #9000+ (source original / branche main) : AUCUN org/donnees
; ci-dessous. Le buffer de pre-rendu (BUF_PRERENDER_BASE, #9000,
; CONFIRMED) et la VRAM (VRAM_BASE, #C000) sont de la RAM d'execution
; pure (reconstruite/dessinee chaque frame), pas du contenu charge
; depuis le support d'origine -- ils n'existent dans ce source QUE
; comme symboles EQU (include/memory_map.equ.asm), demande explicite de
; l'utilisateur. Voir notes/2026-08-18-vram-direct-patch-plan.md pour
; pourquoi cette zone reste hors d'atteinte pour du code neuf tant que
; fn_blit_masked/fn_clear_intermediate_buffer ne sont pas migres.
