; ============================================================
; dispatch_and_sound.asm -- genere par tools/gen_asm.py, plage #0676-#0FD8
; Genere mecaniquement depuis la RAM live + asm/symbols.json.
; Ne pas editer les blocs de code a la main : relancer le generateur.
; ============================================================
        org #0676
tbl_entity_logic_dispatch:
        ; Table de pointeurs word, dispatch logique par type d'entité. EXTENT
        ; CONFIRMÉE: exactement 188 entrées (#0676-#07ED), types #00-#BB — vérifié
        ; en décodant chaque mot comme pointeur et en confirmant qu'il tombe dans
        ; #0000-#3FFF (zone code) jusqu'à l'entrée 187 incluse (type 0xBB, celui
        ; produit par fn_collision_effect, pointe vers #17F4); l'entrée 188
        ; (#07EE) sort de la plage code car ce n'est pas une entrée de table mais
        ; le début de la routine suivante (voir ci-dessous) — AUDIT COMPLET
        ; 2026-08-14 : sur les 51 cibles distinctes referencees par les 188
        ; entrees, les 3 dernieres jamais desassemblees/nommees (#1DB2 types
        ; 0x58/0x59/0x5A, #1D7F type 0x80, #17F4 types 0xB9/0xBB) sont maintenant
        ; resolues -- voir fn_static_calib_vector_table et
        ; fn_pickup_catalog_ptr_clear_and_idle. tbl_entity_logic_dispatch est donc
        ; 188/188 traite (aucune entree restant a l'etat brut/non-desassemble ;
        ; quelques types restent 'hypothesis' sur l'identification VISUELLE seule,
        ; pas sur la logique).
        defw #0895
        defw #0895
        defw #1FFC
        defw #1FE2
        defw #1FFC
        defw #1FE2
        defw #1D8F
        defw #1D8F
        defw #1F35
        defw #1FA6
        defw #1D94
        defw #1D99
        defw #1D9E
        defw #1D9E
        defw #1D9E
        defw #1D9E
        defw #20CB
        defw #20CB
        defw #20CB
        defw #20CB
        defw #20CB
        defw #20CB
        defw #108C
        defw #10CE
        defw #20CB
        defw #20CB
        defw #20CB
        defw #20CB
        defw #20CB
        defw #20CB
        defw #1280
        defw #1280
        defw #2689
        defw #2689
        defw #2689
        defw #2689
        defw #2689
        defw #2689
        defw #2689
        defw #2689
        defw #2689
        defw #2689
        defw #2689
        defw #2689
        defw #2689
        defw #2689
        defw #2689
        defw #2689
        defw #20D0
        defw #20D0
        defw #20D0
        defw #20D0
        defw #20D0
        defw #20D0
        defw #0F98
        defw #0F93
        defw #20D0
        defw #20D0
        defw #20D0
        defw #20D0
        defw #20D0
        defw #20D0
        defw #1D53
        defw #1092
        defw #268E
        defw #268E
        defw #268E
        defw #268E
        defw #268E
        defw #268E
        defw #268E
        defw #268E
        defw #268E
        defw #268E
        defw #268E
        defw #268E
        defw #268E
        defw #268E
        defw #268E
        defw #268E
        defw #1EA1
        defw #1EA1
        defw #1EA1
        defw #1EA1
        defw #1D71
        defw #1D66
        defw #10D4
        defw #10D4
        defw #1DB2
        defw #1DB2
        defw #1DB2
        defw #0F67
        defw #1BE1
        defw #1BE1
        defw #1BE1
        defw #1BE1
        defw #1B2B
        defw #1B2B
        defw #1B2B
        defw #1B2B
        defw #1B2B
        defw #1B2B
        defw #1B2B
        defw #1A4A
        defw #1A93
        defw #1A93
        defw #1A93
        defw #1A93
        defw #1A93
        defw #1A93
        defw #1A93
        defw #1239
        defw #17DC
        defw #17DC
        defw #17DC
        defw #17DC
        defw #17DC
        defw #17DC
        defw #17DC
        defw #17FC
        defw #17A7
        defw #17A7
        defw #17A7
        defw #17A7
        defw #17A7
        defw #17A7
        defw #17A7
        defw #17BC
        defw #1D7F
        defw #0895
        defw #0895
        defw #0E4A
        defw #0E4A
        defw #0E4A
        defw #0895
        defw #0895
        defw #0895
        defw #0895
        defw #0895
        defw #0895
        defw #0895
        defw #1277
        defw #127A
        defw #0F84
        defw #0FD8
        defw #0FD8
        defw #0FD8
        defw #0FD8
        defw #0FD8
        defw #0FD8
        defw #1027
        defw #1027
        defw #0FD8
        defw #0FD8
        defw #0FD8
        defw #0FD8
        defw #0FD8
        defw #0FD8
        defw #1280
        defw #1280
        defw #11B9
        defw #11B9
        defw #11B9
        defw #11B9
        defw #1209
        defw #1209
        defw #1209
        defw #1209
        defw #1200
        defw #1200
        defw #1200
        defw #1200
        defw #1200
        defw #1200
        defw #1200
        defw #1200
        defw #1122
        defw #1122
        defw #1148
        defw #1148
        defw #10F4
        defw #10F4
        defw #0EE5
        defw #0EE5
        defw #17D6
        defw #17F4
        defw #0895
        defw #17F4
fn_gate_array_palette_cycle:
        ; Routine immédiatement adjacente à la fin de tbl_entity_logic_dispatch
        ; (trouvée en en vérifiant l'extent). Lit var_sparkle_and_jingle_phase
        ; (#0073, compteur 0-7, ex-var_room_data_field — renommé, voir plus bas),
        ; le double et va chercher un pointeur dans tbl_palette_stream_ptrs
        ; (#07FD), puis JP (pas CALL) dans fn_gate_array_config_stream (#0049)
        ; avec HL = flux choisi. Appelée depuis fn_pickup_sequence_jingle (#1B43,
        ; qui incrémente #0073 mod 8 puis appelle #07EE 24 fois dans sa boucle) ET
        ; depuis la séquence boot/restart
        ; (fn_boot_init_and_new_game/fn_restart_from_menu, vers #0649) pour
        ; réinitialiser la palette.
        ld    a,(var_sparkle_and_jingle_phase)
        ld    hl,tbl_palette_stream_ptrs
        add    a,a
        rst    #08
        ld    a,(hl)
        inc    hl
        ld    h,(hl)
        ld    l,a
        jp    fn_gate_array_config_stream
tbl_palette_stream_ptrs:
        ; 8 pointeurs word (mais 4 flux distincts seulement, chacun répété 2×)
        ; vers des flux de configuration Gate Array consommés par
        ; fn_gate_array_config_stream via fn_gate_array_palette_cycle: #0814,
        ; #081B, #0822, #080D (puis répétition). Chaque flux est une séquence de 3
        ; paires (registre-ink, couleur) terminée par 0xFF, ex. #080D: 01 4E 02 4A
        ; 03 4B FF. Occupe #07FD-#080C; les flux eux-mêmes (#080D-#0828) suivent
        ; immédiatement.
        defw #0814
        defw #081B
        defw #0822
        defw #080D
        defw #0814
        defw #081B
        defw #0822
        defw #080D
tbl_palette_stream_phase3:
        ; Flux GA phase 3 de tbl_palette_stream_ptrs (#07FD, entrees 3 et 7) --
        ; meme format, deja cite comme exemple dans la description de
        ; fn_gate_array_palette_cycle (#07EE): ink1=#4E,ink2=#4A,ink3=#4B.
        defb #01,#4E,#02,#4A,#03,#4B,#FF
tbl_palette_stream_phase0:
        ; Flux GA phase 0 de tbl_palette_stream_ptrs (#07FD, entrees 0 et 4, index
        ; pair depuis var_sparkle_and_jingle_phase double) -- 3 paires (registre-
        ; ink,couleur) terminees #FF, consommees par fn_gate_array_config_stream
        ; (#0049) via fn_gate_array_palette_cycle (#07EE):
        ; ink1=#52,ink2=#53,ink3=#4D.
        defb #01,#52,#02,#53,#03,#4D,#FF
tbl_palette_stream_phase1:
        ; Flux GA phase 1 de tbl_palette_stream_ptrs (#07FD, entrees 1 et 5) --
        ; meme format (voir tbl_palette_stream_phase0 #0814):
        ; ink1=#55,ink2=#53,ink3=#4A.
        defb #01,#55,#02,#53,#03,#4A,#FF
tbl_palette_stream_phase2:
        ; Flux GA phase 2 de tbl_palette_stream_ptrs (#07FD, entrees 2 et 6) --
        ; meme format: ink1=#4C,ink2=#4A,ink3=#4B.
        defb #01,#4C,#02,#4A,#03,#4B,#FF
fn_build_pixel_bitscatter_tables:
        ; Appelée depuis fn_boot_init_and_new_game/fn_restart_from_menu (#057F) —
        ; PAS le menu (ancienne hypothèse fausse, jamais vérifiée par
        ; désassemblage direct jusqu'ici). Désassemblage direct (tools/disasm.py
        ; 0829 - 0900): construit, au boot, un jeu de tables de conversion "bit-
        ; scatter" (256 octets chacune) à #8200/#8300 (motif tournant
        ; #11/#22/#44/#88, AND/OR/XOR accumulés sur l'index), puis (#0854) une 3e
        ; table à #8100 à partir de #8300 (motif vérifié en dump live:
        ; 00,11,22,...,FF, nibble dupliqué), puis (#086E) une 4e passe combinant
        ; #8200/#8300 via deux sous-routines de rotation de bits
        ; (fn_pixel_bit_scatter_lo #0896, fn_pixel_bit_scatter_hi #08A9).
        ; Vérification live déterminante: dump/diff répété de #8100-#8FFF (100
        ; échantillons cumulés sur plusieurs runs, ~44s, y compris une transition
        ; de salle) montre un contenu totalement statique — cohérent avec un
        ; calcul fait UNE SEULE FOIS au boot, jamais recalculé en jeu. Rôle
        ; CONFIRMÉ pour 14 des 15 tables: fn_blit_masked utilise #8200-#8FFF comme
        ; paires masque/couleur (une paire pour l'alignement byte, 3 triplets
        ; masque/couleur ×2-octets-écran pour les décalages sub-octet 1/2/3).
        ; Seule #8100 (nibble dupliqué) reste sans usage tracé — piste ouverte
        ; mineure.
        ld    hl,#8200
loc_082C:
        ld    bc,fn_cold_boot_entry
        ld    e,#11
        ld    d,#04
loc_0833:
        ld    a,l
        and    e
        ld    a,b
        jr    nz,loc_083A
        or    e
        ld    b,a
loc_083A:
        rlc    e
        dec    d
        jr    nz,loc_0833
        ld    d,#04
loc_0841:
        ld    a,l
        and    e
        jr    z,loc_0846
        xor    e
loc_0846:
        or    c
        ld    c,a
        rlc    e
        dec    d
        jr    nz,loc_0841
        ld    (hl),b
        inc    h
        ld    (hl),a
        dec    h
        inc    l
        jr    nz,loc_082C
        ; [branche vram-direct-experiment] Les 26 octets originaux ici
        ; construisaient la table #8100-#81FF ("nibble dupliqué",
        ; 00,11,22,...,FF) -- CONFIRMÉE sans aucun lecteur dans tout le
        ; jeu (voir docs/SYMBOLS.md #0829/#2F8D, dump/diff live répété
        ; montrant cette zone statique). Neutralisés en nop (longueur
        ; identique, aucun décalage d'adresse pour tout ce qui suit) pour
        ; libérer #8100-#81FF EN PERMANENCE au profit de
        ; code/vram_direct_rendering.asm -- contrairement à
        ; #9000-#BFFF (buffer intermédiaire), rien d'autre n'écrit ici,
        ; ni au chargement de salle ni pendant le rendu. Voir
        ; notes/2026-08-18-vram-direct-patch-plan.md.
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        ld    hl,#8200
loc_0871:
        ld    d,(hl)
        inc    h
        ld    b,(hl)
        inc    h
        ld    c,#00
        ld    e,#FF
        ld    a,#03
loc_087B:
        ex    af,af'
        call    fn_pixel_bit_scatter_lo
        call    fn_pixel_bit_scatter_hi
        ld    (hl),d
        inc    h
        ld    (hl),b
        inc    h
        ld    (hl),e
        inc    h
        ld    (hl),c
        inc    h
        ex    af,af'
        dec    a
        jr    nz,loc_087B
        ld    a,h
        sub    #0E
        ld    h,a
        inc    l
        jr    nz,loc_0871
fn_sound_state_idle:
        ; Etat 0 de tbl_sound_dispatch: canal inactif, RET immediat (rien a jouer)
        ret
fn_pixel_bit_scatter_lo:
        ; Sous-routine de rotation de bits utilisee par
        ; fn_build_pixel_bitscatter_tables (#0829) pour construire les tables
        ; #8200/#8300 au boot -- deja decrite en prose dans cette entree,
        ; formalisee ici. Purement liee au rendu graphique, sans rapport avec le
        ; moteur son malgre sa position physique entre deux routines son
        ; (fn_sound_arm_channel_2/0 #08BE/#08C3 et fn_sound_engine_tick #08CC)
        ld    a,e
        rrca
        and    #77
        ld    e,a
        ld    a,d
        rlca
        rlca
        rlca
        and    #88
        or    e
        ld    e,a
        ld    a,d
        rrca
        or    #88
        ld    d,a
        ret
fn_pixel_bit_scatter_hi:
        ; Variante haute de fn_pixel_bit_scatter_lo (#0896), meme contexte
        ; (fn_build_pixel_bitscatter_tables #0829)
        srl    c
        ld    a,b
        rlca
        rlca
        rlca
        and    #88
        or    c
        ld    c,a
        ld    a,b
        rrca
        and    #77
        ld    b,a
        ret
fn_sound_arm_channel_1:
        ; 3e point d'entree d'armement de canal (troisieme, apres
        ; fn_sound_arm_channel_2 #08BE et fn_sound_arm_channel_0 #08C3, jamais
        ; repere avant ): DE=#009F (canal 1), LDIR 4 octets depuis HL
        ; (descripteur) vers le slot. Utilise par fn_sound_effect_click_positional
        ; (#09CB, via #09BD) et fn_position_pitch_sound_arm (#0A07) / son variant
        ; #0A22
        ld    de,#009F
        jr    loc_08C6
fn_sound_arm_channel_2:
        ; Copie (LDIR 4 octets) un descripteur de séquence sonore (HL=pointeur,
        ; passé par l'appelant) vers le slot du canal 2 (0x00A3) ou canal 0
        ; (0x009B) — arme un effet sonore. Appelée par fn_player_transform_tick
        ; (0x1BFC) avec HL=0x0A6E (canal 2) à chaque tick de l'animation de
        ; transformation.
        ld    de,#00A3
        jr    loc_08C6
fn_sound_arm_channel_0:
        ; Copie (LDIR 4 octets) un descripteur de séquence sonore (HL=pointeur,
        ; passé par l'appelant) vers le slot du canal 2 (0x00A3) ou canal 0
        ; (0x009B) — arme un effet sonore. Appelée par fn_player_transform_tick
        ; (0x1BFC) avec HL=0x0A6E (canal 2) à chaque tick de l'animation de
        ; transformation.
        ld    de,struct_sound_channel_slot
loc_08C6:
        ld    bc,#0004
        ldir
        ret
fn_sound_engine_tick:
        ; Boucle de tick des 3 canaux du moteur d'effets sonores, appelée PAR
        ; L'INTERRUPTION IM1 (0x0038, 300Hz, PAS la boucle de jeu) — dispatch
        ; chaque canal (struct_sound_channel_slot, 4 octets
        ; [état][compteur][paramA][paramB], base 0x009B/0x009F/0x00A3) via
        ; tbl_sound_dispatch (0x08E8) selon son octet d'état (0-7). 8
        ; gestionnaires d'état intégralement décodés: 0=idle (0x0895), 1=bruit à
        ; volume+hauteur décroissants (fn_sound_effect_noise_decay 0x0992,
        ; matérialisation), 2=glissando linéaire volume max
        ; (fn_sound_effect_sweep_linear 0x09B0, son de rebond confirmé), 3=clic
        ; positionnel (fn_sound_effect_click_positional 0x09CB, réutilise
        ; tbl_sound_chromatic_periods 0x0BA8 partagée avec le lecteur de jingle
        ; 0x0A97), 4=note fixe décroissante (fn_sound_effect_note_fixed_decay
        ; 0x0A33), 5=glissando "brouillé" (fn_sound_effect_sweep_scrambled
        ; 0x0A5E), 6=glissando nibble-swap (fn_sound_effect_sweep_nibble_swap
        ; 0x0A72, son de transformation confirmé), 7=ton fixe exact
        ; (fn_sound_effect_tone_fixed 0x0A4B, utilisé par
        ; fn_pushable_block_logic/fn_position_pitch_sound_arm 0x0A07). Bonus: 3e
        ; point d'armement fn_sound_arm_channel_1 (0x08B9) jamais repéré avant,
        ; formalisation de fn_pixel_bit_scatter_lo/_hi.
        ld    iy,struct_sound_channel_slot
loc_08D0:
        ld    l,(iy+off_type)
        ld    bc,tbl_sound_dispatch
        rst    #28
        ld    de,#0004
        add    iy,de
        push    iy
        pop    hl
        ld    de,#00A7
        and    a
        sbc    hl,de
        jr    c,loc_08D0
        ret
tbl_sound_dispatch:
        ; Table de dispatch (word, 8 entrées) indexée par l'octet d'état de chaque
        ; canal son (struct_sound_channel_slot).
        defw #0895
        defw #0992
        defw #09B0
        defw #09CB
        defw #0A33
        defw #0A5E
        defw #0A72
        defw #0A4B
fn_sound_channel_index:
        ; HL=IY-#009B, puis /4 (SRL x2) +1 -> A = numero de canal courant (1,2,3)
        ; depuis le pointeur IY d'un slot struct_sound_channel_slot. Utilise par
        ; de nombreux gestionnaires d'etat pour calculer le registre PSG
        ; (frequence = (canal-1)*2, volume = canal+7)
        push    iy
        pop    hl
        ld    bc,struct_sound_channel_slot
        and    a
        sbc    hl,bc
        ld    a,l
        srl    a
        srl    a
        inc    a
        ret
fn_sound_tick_channel:
        ; Routine de tick partagee par les etats 2-7: bascule un bit du mixer PSG
        ; pour ce canal (fn_sound_toggle_mixer_bit_b #096B), decremente (iy+1)
        ; (compteur de duree). Si non-nul, RET normalement (A=compteur decremente,
        ; consomme par l'appelant -- meme mecanisme (a partir de #090B) utilise
        ; seul par l'etat 1 (fn_sound_effect_noise_decay #0992, sans le bascule-
        ; mixer de tete)). Si le compteur atteint 0: coupe le volume PSG de ce
        ; canal (silence), pose des bits dans var_sound_mixer_mask (#0098) selon
        ; le numero de canal (signalisation de fin d'effet), PUIS ecrase (iy+0)=0
        ; (retour a l'etat idle) et fait un double-RET (INC SP x2) pour sortir
        ; directement JUSQU'A l'appelant de fn_sound_engine_tick (#08CC) -- saute
        ; le reste du gestionnaire d'etat appelant
        call    fn_sound_toggle_mixer_bit_b
loc_090B:
        dec    (iy+off_grid_x)
        ld    a,(iy+off_grid_x)
        ret    nz
        inc    sp
        inc    sp
        ld    (iy+off_type),#00
        call    fn_sound_channel_index
        push    af
        add    a,#07
        ld    e,a
        ld    d,#00
        call    fn_psg_write_period_low
        ld    e,#00
        call    fn_psg_write_period_full
        pop    af
        ld    hl,var_sound_mixer_mask
        cp    #01
        jr    z,fn_sound_mixer_signal_ch1
        cp    #02
        jr    z,fn_sound_mixer_signal_ch2
        ld    a,#24
loc_0937:
        or    (hl)
        ld    (hl),a
        ret
fn_sound_mixer_signal_ch1:
        ; Queue alternative de fn_sound_tick_channel (#0908), atteinte par 'jr
        ; z,#093A' (#092F) quand le numero de canal (A, calcule par
        ; fn_sound_channel_index #08F8) vaut 1: pose A=#09 (bits mixer tone+bruit
        ; du canal 1, #0100+#1000... Motif #001001) puis rejoint la queue commune
        ; a #0937 (OR (HL) / LD (HL),A / RET) qui accumule ce bit dans
        ; var_sound_mixer_mask (#0098) -- signale la fin d'effet pour ce canal
        ; specifique.
        ld    a,#09
        jr    loc_0937
fn_sound_mixer_signal_ch2:
        ; Queue alternative de fn_sound_tick_channel (#0908), atteinte par 'jr
        ; z,#093E' (#0933) quand le canal vaut 2: pose A=#12 (motif bits mixer du
        ; canal 2) puis rejoint #0937 (meme queue que fn_sound_mixer_signal_ch1
        ; #093A). Le cas canal 3 (ni #01 ni #02) tombe directement dans le code
        ; existant a #0935 (A=#24).
        ld    a,#12
        jr    loc_0937
fn_sound_write_noise_period:
        ; Ecrit A comme periode du generateur de bruit PSG (registre 6, seul et
        ; unique par puce -- PAS par canal). Utilise par
        ; fn_sound_effect_noise_decay (#0992, etat 1)
        push    af
        ld    de,#0006
        call    fn_psg_write_period_low
        pop    af
        ld    e,a
        jp    fn_psg_write_period_full
fn_sound_toggle_mixer_bit_a:
        ; Variante A du bascule-bit mixer (voir fn_sound_toggle_mixer_bit_b #096B,
        ; quasi-identique): calcule le bit du registre mixer PSG (7) correspondant
        ; a ce canal (position derivee du numero de canal, ajustee si canal==3),
        ; l'efface dans var_sound_mixer_mask (#0098) (ET logique -- ACTIVE le
        ; bruit/ton pour ce canal), puis ecrit le masque complet au registre
        ; mixer. Utilise par fn_sound_effect_noise_decay (#0992, etat 1)
        ld    de,#0007
        call    fn_psg_write_period_low
        call    fn_sound_channel_index
        cp    #03
        jr    nz,loc_095C
        inc    a
loc_095C:
        rlca
        rlca
        rlca
        and    #38
loc_0961:
        cpl
        ld    hl,var_sound_mixer_mask
        and    (hl)
        ld    (hl),a
        ld    e,a
        jp    fn_psg_write_period_full
fn_sound_toggle_mixer_bit_b:
        ; Variante B du bascule-bit mixer, memes calculs que
        ; fn_sound_toggle_mixer_bit_a (#094E) mais point d'entree legerement
        ; different (saute le premier calcul redondant) -- rejoint la meme queue
        ; partagee (#0961). Utilise par fn_sound_tick_channel (#0908, donc par les
        ; etats 2-7)
        ld    de,#0007
        call    fn_psg_write_period_low
        call    fn_sound_channel_index
        cp    #03
        jr    nz,loc_0979
        inc    a
loc_0979:
        jr    loc_0961
fn_sound_set_volume_max:
        ; A=#0F (15, volume max) puis tombe dans fn_sound_write_volume (#097D).
        ; Utilise en fin des etats 2 (sweep lineaire), 5 (sweep scramble) et 6
        ; (sweep nibble-swap) -- ces 3 etats jouent donc toujours a volume fixe
        ; max, seule la hauteur varie
        ld    a,#0F
fn_sound_write_volume:
        ; Ecrit A comme volume PSG du canal courant (registre canal+7, calcule via
        ; fn_sound_channel_index #08F8). Utilise par fn_sound_set_volume_max
        ; (#097B, A=15 fixe) et par les etats 1/4 (volume decroissant calcule
        ; depuis le compteur de duree)
        push    af
        call    fn_sound_channel_index
        add    a,#07
        ld    e,a
        ld    d,#00
        call    fn_psg_write_period_low
        pop    af
        ld    e,a
        jp    fn_psg_write_period_full
tbl_sound_descriptor_noise_decay:
        ; Descripteur [etat1,compteur#1F,0,0] du gestionnaire
        ; fn_sound_effect_noise_decay (#0992) -- Arme par
        ; fn_player_materialize_anim (#17D6) et par #1F44.
        defb #01,#1F,#00,#00
fn_sound_effect_noise_decay:
        ; Gestionnaire d'etat 1 de tbl_sound_dispatch: effet de BRUIT a volume ET
        ; hauteur DECROISSANTS (bascule le mixer via fn_sound_toggle_mixer_bit_a
        ; #094E, decremente la duree via fn_sound_decrement_and_check #090B,
        ; volume=compteur/2, periode de bruit=complement(compteur)&#1F via
        ; fn_sound_write_noise_period #0942) -- typique d'un effet d'IMPACT/THUD
        ; qui s'eteint progressivement. Descripteur connu: #098E (etat1,
        ; compteur#1F), arme par fn_player_materialize_anim (#17D6, sequence de
        ; (dis/re)materialisation du joueur) et par une 2e routine non identifiee
        ; (#1F44, test bit2 de (ix+0C))
        call    fn_sound_toggle_mixer_bit_a
        call    loc_090B
        srl    a
        call    fn_sound_write_volume
        ld    a,(iy+off_grid_x)
        cpl
        and    #1F
        jp    fn_sound_write_noise_period
fn_sound_trigger_bounce:
        ; Arme le canal 0 (fn_sound_arm_channel_0 #08C3) avec le descripteur #09AC
        ; (etat2, compteur#1F) -- LE son de rebond generique. Appele par
        ; fn_bouncing_ball_logic et par fn_ball_chase_flee_logic (#0EE5, via #0F30
        ; -- meme famille 'bulle volcanique') et fn_will_o_wisp_logic (#10F4, via
        ; #111A -- deja documentee comme rebondissant selon le meme schema que la
        ; balle)
        ld    hl,tbl_sound_descriptor_bounce
        jp    fn_sound_arm_channel_0
tbl_sound_descriptor_bounce:
        ; Descripteur [etat2,compteur#1F,0,0] de fn_sound_effect_sweep_linear
        ; (#09B0) -- LE son de rebond generique, arme par fn_sound_trigger_bounce
        ; (#09A6).
        defb #02,#1F,#00,#00
fn_sound_effect_sweep_linear:
        ; Gestionnaire d'etat 2: effet de GLISSANDO lineaire a volume fixe max
        ; (fn_sound_set_volume_max #097B) -- periode PSG = #0100 + compteur*2
        ; (decroit lineairement avec la duree, via fn_sound_write_period_hl
        ; #0A7B), donne un "boing" descendant classique. Descripteur #09AC, armee
        ; par fn_sound_trigger_bounce (#09A6) -- LE son de rebond de balle/entite
        call    fn_sound_tick_channel
        rlca
        ld    l,a
        ld    h,#01
        call    fn_sound_write_period_hl
        jp    fn_sound_set_volume_max
fn_sound_trigger_click_and_advance:
        ; Sous-etape de fn_sound_effect_click_positional : avance l'index de
        ; lecture dans tbl_sound_chromatic_periods et arme le canal suivant.
        ld    hl,var_sound_click_pitch_index
        inc    (hl)
        ld    hl,tbl_sound_descriptor_click
        jp    fn_sound_arm_channel_2
tbl_sound_descriptor_click:
        ; Descripteur [etat3,compteur#17,0,0] de fn_sound_effect_click_positional
        ; (#09CB) -- arme par fn_sound_trigger_click_and_advance (#09BD).
        defb #03,#17,#00,#00
fn_sound_effect_click_positional:
        ; Gestionnaire d'etat 3: CLIC dont le VOLUME depend de la position du
        ; joueur en cache (var #00D8/#00D9, combinaison rotative -> volume 8-15)
        ; et dont la HAUTEUR est choisie dans tbl_sound_click_pitch_palette
        ; (#09FF, 8 entrees) indexee par var_sound_click_pitch_index (#009A) mod
        ; 8, elle-meme un INDEX vers tbl_sound_chromatic_periods (#0BA8) --
        ; Descripteur #09C7, armee par fn_sound_trigger_click_and_advance (#09BD)
        call    fn_sound_tick_channel
        ld    a,(#00D8)
        srl    a
        ld    c,a
        ld    a,(#00D9)
        neg
        srl    a
        add    a,c
        rrca
        rrca
        rrca
        rrca
        rrca
        and    #07
        add    a,#08
        call    fn_sound_write_volume
        ld    a,(var_sound_click_pitch_index)
        and    #07
        ld    hl,tbl_sound_click_pitch_palette
        rst    #08
        ld    a,(hl)
        sla    a
        ld    hl,tbl_sound_opcode_dispatch
        rst    #08
        ld    a,(hl)
        inc    hl
        ld    h,(hl)
        ld    l,a
        jp    fn_sound_write_period_hl
tbl_sound_click_pitch_palette:
        ; 8 index (octet) dans tbl_sound_chromatic_periods (#0BA8, meme table que
        ; le lecteur de jingle bloquant #0A97): #25,#27,#28,#2A,#28,#27,#25,#23 --
        ; un petit motif de vibrato (monte puis redescend de qq demi-tons) utilise
        ; par fn_sound_effect_click_positional (#09CB), selectionne via
        ; var_sound_click_pitch_index (#009A) mod 8
        defb #25,#27,#28,#2A,#28,#27,#25,#23
fn_position_pitch_sound_arm:
        ; Calcule complément(grid_x+grid_y+grid_z) de l'entité et l'écrit comme
        ; octet bas de la période PSG dans le descripteur #0A47 (état 7 =
        ; fn_sound_effect_tone_fixed 0x0A4B, compteur court #07), puis arme le
        ; canal 1 (fn_sound_arm_channel_1 0x0A07→0x08B9) — un BLIP répété de
        ; hauteur dérivée de la position (confirme le "son de déplacement à
        ; hauteur variable" déjà supposé). Mêmes adresses #0A49/#0A4A réutilisées
        ; par fn_bonus_life_pickup_logic/0x0A14 (autre appelant, écrit le même
        ; descripteur avec un paramètre différent). Utilisé par
        ; fn_pushable_block_logic, ET par fn_will_o_wisp_logic (0x10F4/0x1108) et
        ; fn_moving_block_logic (0x0F98/0x0FA6).
        ld    a,(ix+off_grid_x)
        add    a,(ix+off_grid_y)
        add    a,(ix+off_grid_z_or_offset)
        cpl
        ld    l,a
        ld    h,#00
        ld    a,l
        ld    (#0A4A),a
        ld    a,h
        ld    (#0A49),a
        ld    hl,tbl_sound_descriptor_tone_fixed
        jp    fn_sound_arm_channel_1
fn_sound_arm_position_pitch_ch1:
        ; Variante de fn_position_pitch_sound_arm (#0A07) utilisant SEULEMENT
        ; complement((ix+03)) (pas la somme des 3 axes) comme parametre de
        ; hauteur, ecrit dans le descripteur #0A2F (etat 4,
        ; fn_sound_effect_note_fixed_decay #0A33, compteur#1F -- note a volume
        ; DECROISSANT, pas un blip repete comme #0A07), arme le canal 1.
        ; Appelants: fn_sinking_cube_logic (#0F67, via #0F7E -- clic de descente
        ; du cube-piege) et fn_ceiling_spike_ball_logic (#1092, via #10BD -- clic
        ; de contact des pics)
        ld    a,(ix+off_grid_z_or_offset)
        cpl
        ld    (#0A32),a
        ld    hl,tbl_sound_descriptor_note_fixed_decay
        jp    fn_sound_arm_channel_1
tbl_sound_descriptor_note_fixed_decay:
        ; Descripteur [etat4,compteur#1F,0,param] de
        ; fn_sound_effect_note_fixed_decay (#0A33) -- param (octet+3) ecrit
        ; dynamiquement par fn_sound_arm_position_pitch_ch1 (#0A22, a #0A32) avant
        ; chaque armement; #7F est la valeur figee au moment du dump RAM (reliquat
        ; du dernier armement), pas une constante.
        defb #04,#1F,#00,#7F
fn_sound_effect_note_fixed_decay:
        ; Gestionnaire d'etat 4: NOTE a hauteur FIXE (lue directement depuis
        ; (iy+03) du descripteur, ecrite via fn_sound_write_period_hl #0A7B) et
        ; VOLUME DECROISSANT (rotation-droite(compteur)&#0F, via
        ; fn_sound_write_volume #097D) -- une note "pincee" classique qui
        ; s'eteint. Descripteur #0A2F, armee par fn_sound_arm_position_pitch_ch1
        ; (#0A22)
        call    fn_sound_tick_channel
        ld    l,(iy+off_grid_z_or_offset)
        ld    h,#00
        call    fn_sound_write_period_hl
        ld    a,(iy+off_grid_x)
        rrca
        and    #0F
        jp    fn_sound_write_volume
tbl_sound_descriptor_tone_fixed:
        ; Descripteur [etat7,compteur#07,paramA,paramB] de
        ; fn_sound_effect_tone_fixed (#0A4B) -- paramA/paramB (octets+2/+3) ecrits
        ; dynamiquement par fn_position_pitch_sound_arm (#0A07, a #0A49/#0A4A)
        ; avant chaque armement; #00/#40 sont les valeurs figees au moment du dump
        ; RAM (reliquat du dernier armement).
        defb #07,#07,#00,#40
fn_sound_effect_tone_fixed:
        ; Gestionnaire d'etat 7: TON a periode 16 bits FIXE lue directement depuis
        ; (iy+02)/(iy+03) du descripteur (via fn_sound_write_period_hl #0A7B) et
        ; volume fixe max (fn_sound_set_volume_max #097B) -- le commande de ton la
        ; plus "directe" (frequence exacte specifiee par l'appelant, pas de
        ; calcul). Descripteur #0A47, armee par fn_position_pitch_sound_arm
        ; (#0A07)
        call    fn_sound_tick_channel
        ld    l,(iy+off_grid_z_or_offset)
        ld    h,(iy+off_grid_y)
        call    fn_sound_write_period_hl
        jp    fn_sound_set_volume_max
tbl_sound_descriptor_sweep_scrambled:
        ; Descripteur [etat5,compteur#1F,0,0] de fn_sound_effect_sweep_scrambled
        ; (#0A5E) --
        defb #05,#1F,#00,#00
fn_sound_effect_sweep_scrambled:
        ; Gestionnaire d'etat 5: glissando a volume fixe max
        ; (fn_sound_set_volume_max #097B), periode = ROL2(compteur) XOR #A0 --
        ; variante "brouillee" du sweep de fn_sound_effect_sweep_linear (#09B0),
        ; effet plus dissonant/glitch. Descripteur #0A5A (compteur #1F) arme
        ; directement par fn_sound_arm_channel_1 (#08B9) depuis une routine de
        ; reaction de collision generique non identifiee precisement (#220C, entre
        ; fn_player_read_input #2147 et fn_get_orientation_code #22D0 -- voir
        ; #09BD ci-dessous pour le meme voisinage)
        call    fn_sound_tick_channel
        rlca
        rlca
        xor    #A0
loc_0A65:
        ld    l,a
        ld    h,#00
        call    fn_sound_write_period_hl
        jp    fn_sound_set_volume_max
tbl_sound_descriptor_sweep_nibble_swap:
        ; Descripteur [etat6,compteur#1F,0,0] de fn_sound_effect_sweep_nibble_swap
        ; (#0A72) --
        defb #06,#1F,#00,#00
fn_sound_effect_sweep_nibble_swap:
        ; Gestionnaire d'etat 6: periode = ROL4(compteur) (= echange des nibbles),
        ; PUIS tombe directement dans le corps de fn_sound_effect_sweep_scrambled
        ; (#0A5E, a partir du XOR #A0) -- partage entierement sa queue (ecriture
        ; periode + volume max). Descripteur #0A6E, armee par
        ; fn_player_transform_tick (#1BFC) --
        call    fn_sound_tick_channel
        rlca
        rlca
        rlca
        rlca
        jr    loc_0A65
fn_sound_write_period_hl:
        ; Ecrit HL comme periode PSG 16 bits (fine+coarse) du canal courant
        ; (registres (canal-1)*2 / +1, canal calcule via fn_sound_channel_index
        ; #08F8). Utilisee par tous les gestionnaires d'etat qui jouent un ton
        ; (2,3,4,5,6,7)
        push    hl
        call    fn_sound_channel_index
        dec    a
        sla    a
        ld    e,a
        ld    d,#00
        call    fn_psg_write_period_low
        pop    hl
        push    de
        ld    e,l
        call    fn_psg_write_period_full
        pop    de
        inc    e
        call    fn_psg_write_period_low
        ld    e,h
        jp    fn_psg_write_period_full
fn_sound_program_play_blocking:
        ; Lecteur de programme sonore PSG 3 canaux, BLOQUANT (busy-wait,
        ; contrairement a fn_sound_engine_tick qui est tickee par IM1). Appelee
        ; pour jouer le jingle de fin de partie. Init : DI,
        ; fn_psg_register_init_stream (HL=#0C36), charge 3 canaux dans des slots
        ; de 7 octets a #1877 (+0/+1=pointeur programme, +2/+3=compteur de duree,
        ; +4=mode de volume courant, +5/+6=copie du pointeur de depart pour LOOP).
        ; Boucle round-robin sur les 3 canaux : decompte +2/+3, et a 0 appelle
        ; fn_sound_program_step.
        ld    a,#01
        jr    loc_0A9C
fn_sound_program_channel_setup:
        ; Charge un canal du lecteur de jingle bloquant (slot de 7 octets a #1877
        ; + offset canal) depuis un pointeur programme fourni par l'appelant.
        xor    a
loc_0A9C:
        ld    (#0099),a
        call    fn_disarm_interrupt_flag
        push    hl
        ld    hl,tbl_psg_init_stream_default
        call    fn_psg_register_init_stream
        pop    hl
        ld    iy,#1877
        ld    de,#0007
        ld    b,#03
loc_0AB3:
        ld    a,(hl)
        inc    hl
        ld    (iy+off_type),a
        ld    (iy+off_bbox_h),a
        ld    a,(hl)
        inc    hl
        ld    (iy+off_grid_x),a
        ld    (iy+off_bbox_d),a
        xor    a
        ld    (iy+off_grid_y),a
        ld    (iy+off_grid_z_or_offset),a
        add    iy,de
        djnz    loc_0AB3
loc_0ACE:
        ld    iy,#1877
        ld    a,#03
loc_0AD4:
        ex    af,af'
        ld    l,(iy+off_grid_y)
        ld    h,(iy+off_grid_z_or_offset)
        ld    a,l
        or    h
        jr    z,fn_sound_program_step
        dec    hl
        ld    (iy+off_grid_y),l
        ld    (iy+off_grid_z_or_offset),h
loc_0AE6:
        ld    de,#0007
        add    iy,de
        ex    af,af'
        dec    a
        jp    nz,loc_0AD4
        jp    loc_0ACE
fn_sound_program_step:
        ; Appelee quand le compteur de duree d'un canal atteint 0. Sonde clavier
        ; (fn_read_keyboard_row_raw) + joystick (fn_read_joystick_table) pour
        ; permettre d'ecourter le jingle, lit l'octet suivant du programme du
        ; canal, dispatch commande (RST 28 via tbl_sound_opcode_dispatch) ou note
        ; (fn_sound_note_apply).
        ld    a,(#0099)
        and    a
        jr    z,loc_0B05
        call    fn_read_keyboard_row_raw
        ld    hl,tbl_wait_any_key_all_rows
        call    fn_read_joystick_table
        jp    nz,loc_0C20
loc_0B05:
        ld    l,(iy+off_type)
        ld    h,(iy+off_grid_x)
        ld    a,(hl)
        inc    hl
        ld    (iy+off_type),l
        ld    (iy+off_grid_x),h
        push    af
        cp    #08
        jr    nc,fn_sound_note_apply
        ld    l,a
        ld    bc,tbl_sound_opcode_dispatch
        jp    rst_dispatch_table
fn_sound_note_apply:
        ; Décode un octet de programme >=8 comme une NOTE (bits7-6=durée,
        ; bits5-0=hauteur, voir 0x0A97), écrit la période PSG correspondante,
        ; applique le mode de volume courant (tbl_sound_volume_mode_dispatch
        ; 0x0B5D). Octets #38-#3F (et alias) invalides — sortiraient de
        ; tbl_sound_chromatic_periods, jamais utilisés en pratique
        rlca
        rlca
        rlca
        and    #06
        ld    hl,tbl_sound_note_durations
        rst    #08
        ld    a,(hl)
        inc    hl
        ld    (iy+off_grid_y),a
        ld    a,(hl)
        ld    (iy+off_grid_z_or_offset),a
        pop    af
        rlca
        and    #7E
        ld    hl,tbl_sound_opcode_dispatch
        rst    #08
        ld    d,#00
        ex    af,af'
        ld    e,a
        ex    af,af'
        dec    e
        sla    e
        push    de
        call    fn_psg_write_period_low
        ld    e,(hl)
        inc    hl
        call    fn_psg_write_period_full
        pop    de
        inc    e
        call    fn_psg_write_period_low
        ld    e,(hl)
        call    fn_psg_write_period_full
        ld    l,(iy+off_bbox_w)
        ld    bc,tbl_sound_volume_mode_dispatch
        rst    #28
        jp    loc_0AE6
tbl_sound_volume_mode_dispatch:
        ; 4 entrées (word), indexées par +4 du canal: fn_sound_volume_mute
        ; (0x0B65, volume 0), fn_sound_volume_mid (0x0B77, volume 7),
        ; fn_sound_volume_max (0x0B7C, volume #0F), fn_sound_volume_envelope
        ; (0x0B81, mode enveloppe matérielle + reset forme d'enveloppe). Seules 4
        ; entrées existent — un +4=4 ou 5 (accepté sans erreur par
        ; tbl_sound_opcode_dispatch) ferait sauter hors table vers #0011 (adresse
        ; invalide), jamais déclenché par les données réelles
        defw #0B65
        defw #0B77
        defw #0B7C
        defw #0B81
fn_sound_volume_mute:
        ; Mode de volume 0: ecrit 0 (silence) dans le registre volume PSG du canal
        ; courant (8/9/10 pour canal A/B/C, calcule depuis le compteur de canal
        ; via af'). Pose par la commande de programme sonore #00 -- artefact du
        ; generateur: le 'LD DE,fn_cold_boot_entry' affiche dans l'asm genere est
        ; une COINCIDENCE NUMERIQUE (l'immediat charge est bien la valeur 0, pas
        ; un appel au boot -- gen_asm.py substitue tout operande #0000 par le nom
        ; du symbole a cette adresse, sans distinguer adresse de donnee immediate)
        ld    de,fn_cold_boot_entry
loc_0B68:
        push    de
        ex    af,af'
        ld    e,a
        ex    af,af'
        ld    a,e
        add    a,#07
        ld    e,a
        call    fn_psg_write_period_low
        pop    de
        jp    fn_psg_write_period_full
fn_sound_volume_mid:
        ; Mode de volume 1: ecrit 7 (volume moyen fixe) dans le registre volume
        ; PSG du canal courant. Pose par la commande de programme sonore #01
        ld    de,#0007
        jr    loc_0B68
fn_sound_volume_max:
        ; Mode de volume 2: ecrit #0F (15, volume max fixe) dans le registre
        ; volume PSG du canal courant. Pose par la commande de programme sonore
        ; #02
        ld    de,#000F
        jr    loc_0B68
fn_sound_volume_envelope:
        ; Mode de volume 3: ecrit #10 (bit4=1, mode enveloppe materielle PSG) dans
        ; le registre volume du canal courant, PUIS reinitialise le registre de
        ; forme d'enveloppe (13) a 0 via fn_psg_register_init_stream (#0D67,
        ; donnees #0B8D: #0D,#00,#FF). Pose par la commande de programme sonore
        ; #03 -- typique d'un son perussif/pluck (enveloppe materielle plutot que
        ; volume fixe) -- artefact du generateur: le 'LD
        ; DE,rst_apply_movement_vector' affiche est une COINCIDENCE NUMERIQUE
        ; (l'immediat charge est bien la valeur #0010=16, pas un appel a RST 10 --
        ; meme limitation de substitution que #0B65)
        ld    de,rst_apply_movement_vector
        call    loc_0B68
        ld    hl,tbl_psg_envelope_shape_reset
        jp    fn_psg_register_init_stream
tbl_psg_envelope_shape_reset:
        ; Flux fn_psg_register_init_stream (#0D67) de 1 registre: reg13(forme
        ; d'enveloppe)=0, terminateur #FF. Utilise par fn_sound_volume_envelope
        ; (#0B81, mode de volume 3).
        defb #0D,#00,#FF
tbl_sound_note_durations:
        ; 4 durées de note (word LE), indexées par les bits 7-6 d'un octet de note
        ; (AND #06 après rotation) dans fn_sound_note_apply (0x0B1F): #0400,
        ; #0800, #0C00, #1000 — progression linéaire (×1,×2,×3,×4 d'une unité de
        ; base)
        defw #0400
        defw #0800
        defw #0C00
        defw #1000
tbl_sound_opcode_dispatch:
        ; Octet de programme sonore <8 = commande (via fn_sound_program_step) :
        ; #00-#05 -> fn_sound_cmd_store_param (stocke la valeur brute 0-5 dans
        ; (iy+4) comme mode de volume courant, seuls 0-3 sont surs, voir
        ; tbl_sound_volume_mode_dispatch) ; #06 -> fn_sound_cmd_loop ; #07 ->
        ; fn_sound_cmd_end.
        defw #0C18
        defw #0C18
        defw #0C18
        defw #0C18
        defw #0C18
        defw #0C18
        defw #0C26
        defw #0C1F
tbl_sound_chromatic_periods:
        ; 56 périodes PSG (word LE), gamme chromatique D2→A6 (voir 0x0A97 pour la
        ; validation par calcul de fréquence). Indexée par octet_programme AND
        ; #3F. Extent (56, pas 64) confirmée: les 8 index suivants tomberaient
        ; dans le code des gestionnaires de commande
        defw #0353
        defw #0324
        defw #02F6
        defw #02CC
        defw #02A4
        defw #027E
        defw #025A
        defw #0238
        defw #0218
        defw #01FA
        defw #01DE
        defw #01C3
        defw #01AA
        defw #0192
        defw #017B
        defw #0166
        defw #0152
        defw #013F
        defw #012D
        defw #011C
        defw #010C
        defw #00FD
        defw #00EF
        defw #00E1
        defw #00D5
        defw #00C9
        defw #00BE
        defw #00B3
        defw #00A9
        defw #009F
        defw #0096
        defw #008E
        defw #0086
        defw #007F
        defw #0077
        defw #0071
        defw #006A
        defw #0064
        defw #005F
        defw #0059
        defw #0054
        defw #0050
        defw #004B
        defw #0047
        defw #0043
        defw #003F
        defw #003C
        defw #0038
        defw #0035
        defw #0032
        defw #002F
        defw #002D
        defw #002A
        defw #0028
        defw #0026
        defw #0024
fn_sound_cmd_store_param:
        ; Commande de programme sonore #00-#05: stocke la valeur brute de l'octet
        ; (0-5) dans (iy+4) du canal courant -- mode de volume/instrument qui sera
        ; applique par la PROCHAINE note (voir tbl_sound_volume_mode_dispatch
        ; #0B5D). Revient a fn_sound_program_step (#0AF3, verif abandon + octet
        ; suivant)
        pop    af
        ld    (iy+off_bbox_w),a
        jp    fn_sound_program_step
fn_sound_cmd_end:
        ; Commande de programme sonore #07: FIN du programme sonore. Coupe le
        ; mixer PSG (registre 7 = #3F, tons+bruit desactives sur les 3 canaux) et
        ; remet les 3 volumes a 0 via fn_psg_register_init_stream (#0D67, donnees
        ; #0D5E). Comme cette routine finit par RET, cela deroule la pile jusqu'a
        ; l'appelant ORIGINAL de fn_sound_program_play_blocking (#0A97) -- END
        ; termine tout le jingle des qu'UN SEUL canal l'atteint, pas seulement ce
        ; canal
        pop    af
loc_0C20:
        ld    hl,tbl_psg_reset_stream
        jp    fn_psg_register_init_stream
fn_sound_cmd_loop:
        ; Commande de programme sonore #06: LOOP -- recopie le pointeur de depart
        ; sauvegarde (iy+5)/(iy+6) dans le pointeur de programme courant
        ; (iy+0)/(iy+1), fait donc rejouer le canal depuis le debut indefiniment.
        ; Revient a fn_sound_program_step (#0AF3)
        pop    af
        ld    a,(iy+off_bbox_h)
        ld    (iy+off_type),a
        ld    a,(iy+off_bbox_d)
        ld    (iy+off_grid_x),a
        jp    fn_sound_program_step
tbl_psg_init_stream_default:
        ; Flux fn_psg_register_init_stream (#0D67) fixe, HL=#0C36 code en dur dans
        ; fn_sound_program_play_blocking (#0A97): reg8/9/10(volumes A/B/C)=0
        ; (silence), reg7(mixer)=#38 (tons ON / bruit OFF sur les 3 canaux),
        ; reg11/12(periode d'enveloppe fine/coarse)=0/#08, terminateur #FF. Decode
        ; octet-par-octet, verifie coherent de bout en bout (17 segments contigus,
        ; aucun octet residuel).
        defb #08,#00,#09,#00,#0A,#00,#07,#38,#0B,#00,#0C,#08,#FF
tbl_sound_program_ptrs_unused_a:
        ; [hypothesis] Reliquat inutilise ou appelant non encore identifie.
        ; Ch2/ch3 pointent vers des programmes reels et coherents
        ; (tbl_sound_program_unused_a_ch2/_ch3), donc pas des octets aleatoires.
        defw #0D5B
        defw #0D01
        defw #0CF5
tbl_sound_program_ptrs_gameover:
        ; Triplet de pointeurs canal (word LE) [ch1=#0D5B,ch2=#0D2D,ch3=#0D0B] --
        ; jingle de l'ECRAN DE GAME OVER, parametre HL de l'appel
        ; fn_sound_program_play_blocking (#0A97) depuis
        ; fn_game_over_or_daycycle_end (#1374,
        ; asm/code/entity_logic_mechanical.asm).
        defw #0D5B
        defw #0D2D
        defw #0D0B
tbl_sound_program_ptrs_unused_b:
        ; [hypothesis] Triplet de pointeurs canal (word LE)
        ; [ch1=#0D5B,ch2=#0D51,ch3=#0D37], meme format que
        ; tbl_sound_program_ptrs_gameover (#0C49) -- AUCUN appelant trouve par
        ; recherche statique dans les fichiers.asm actuellement generes. Ch2/ch3
        ; pointent vers des programmes reels et coherents
        ; (tbl_sound_program_unused_b_ch2/_ch3) -- candidat pour identification
        ; empirique (jingle non repere par recherche de HL=#0C4F dans le code).
        defw #0D5B
        defw #0D51
        defw #0D37
tbl_sound_program_ptrs_control_menu:
        ; Triplet de pointeurs canal (word LE) [ch1=#0D5B,ch2=#0CC5,ch3=#0C61] --
        ; jingle de l'ECRAN DE SELECTION DU MODE DE CONTROLE, parametre HL de
        ; l'appel fn_sound_program_play_blocking (#0A97) depuis
        ; fn_control_mode_menu (#15E5, asm/code/entity_logic_mechanical.asm).
        ; Fn_sound_program_play_blocking (#0A97) citait ce site comme 'day-cycle-
        ; end' par proximite de code avec fn_game_over_or_daycycle_end --
        ; verification directe de l'appelant (#15E5) montre qu'il s'agit en
        ; realite de fn_control_mode_menu (ecran affiche au demarrage/redemarrage
        ; pour choisir JOYSTICK vs DIRECTIONAL CONTROL), sans rapport avec le
        ; cycle jour/nuit.
        defw #0D5B
        defw #0CC5
        defw #0C61
tbl_sound_program_ptrs_unused_c:
        ; [hypothesis] Triplet de pointeurs canal (word LE)
        ; [ch1=#0D5B,ch2=#0D5B,ch3=#0CEF] (ch1 ET ch2 identiques -- les 2 seraient
        ; silencieux/en boucle) -- AUCUN appelant trouve par recherche statique.
        ; Ch3 pointe vers un court programme reel (tbl_sound_program_unused_c_ch3,
        ; arpege chromatique D6-D#6-E6-F6 en mode enveloppe).
        defw #0D5B
        defw #0D5B
        defw #0CEF
tbl_sound_program_control_menu_ch3:
        ; Programme sonore du canal 3 du jingle ecran de selection de mode
        ; (tbl_sound_program_ptrs_control_menu #0C55): cmd2(volume max) puis 99
        ; notes courtes (duree0) formant une melodie rapide repetee 2x (motif
        ; F4/F5/G#5/C6 puis C4/D#5/D5/C5 x2, puis C#4/C6 x4, D#4/C6 x4, F4/C6 x6),
        ; cmd7(FIN). 100 octets, #0C61-#0CC4.
        defb #02,#1B,#27,#1B,#27,#1B,#2A,#2E,#1B,#27,#1B,#27,#1B,#2A,#1B,#2E
        defb #16,#25,#16,#24,#16,#22,#16,#22,#16,#25,#16,#24,#16,#22,#16,#22
        defb #16,#22,#1B,#27,#1B,#27,#1B,#2A,#2E,#1B,#27,#1B,#27,#1B,#2A,#1B
        defb #2E,#16,#25,#16,#24,#16,#22,#16,#22,#16,#25,#16,#24,#16,#22,#16
        defb #22,#16,#22,#17,#2E,#17,#2E,#17,#2E,#17,#2E,#19,#2E,#19,#2E,#19
        defb #2E,#19,#2E,#1B,#2E,#1B,#2E,#1B,#2E,#1B,#2E,#1B,#2E,#1B,#2E,#1B
        defb #2E,#1B,#2E,#07
tbl_sound_program_control_menu_ch2:
        ; Programme sonore du canal 2 du jingle ecran de selection de mode
        ; (tbl_sound_program_ptrs_control_menu #0C55): cmd2(volume max) puis motif
        ; F3-G#3 repete avec ornements D#3-F3-G3 et notes tenues, cmd7(FIN). 42
        ; octets, #0CC5-#0CEE.
        defb #02,#CF,#D2,#CF,#D2,#0D,#0F,#11,#4D,#8A,#0D,#0F,#11,#4D,#8A,#0A
        defb #CF,#D2,#CF,#D2,#0D,#0F,#11,#4D,#8A,#0D,#0F,#11,#4D,#8A,#0A,#CF
        defb #CF,#4F,#52,#51,#4D,#CF,#CF,#CF,#CF,#07
tbl_sound_program_unused_c_ch3:
        ; [hypothesis] Programme sonore du canal 3 pointe par
        ; tbl_sound_program_ptrs_unused_c (#0C5B, aucun appelant trouve):
        ; cmd3(mode enveloppe) puis arpege chromatique montant D6-D#6-E6-F6
        ; (durees courtes), cmd7(FIN). 6 octets, #0CEF-#0CF4.
        defb #03,#30,#31,#32,#33,#07
tbl_sound_program_unused_a_ch3:
        ; [hypothesis] Programme sonore du canal 3 pointe par
        ; tbl_sound_program_ptrs_unused_a (#0C43, aucun appelant trouve):
        ; cmd2(volume max) puis notes D6-F6-E6-A5-D6-C6-A5-C6-D6-D6(longue),
        ; cmd7(FIN). 12 octets, #0CF5-#0D00.
        defb #02,#70,#73,#72,#6B,#30,#2E,#2B,#2E,#30,#B0,#07
tbl_sound_program_unused_a_ch2:
        ; [hypothesis] Programme sonore du canal 2 pointe par
        ; tbl_sound_program_ptrs_unused_a (#0C43, aucun appelant trouve):
        ; cmd2(volume max) puis notes D5-D5-E5-E5-F5-G5-D5-D5, cmd7(FIN). 10
        ; octets, #0D01-#0D0A.
        defb #02,#64,#64,#66,#66,#67,#69,#64,#64,#07
tbl_sound_program_gameover_ch3:
        ; Programme sonore du canal 3 (arpege decoratif) du jingle game over
        ; (tbl_sound_program_ptrs_gameover #0C49): cmd3(mode enveloppe) puis 33
        ; notes courtes (duree0) en boucle de motifs de 4 (C6-C#4-F5-C#4, puis
        ; variantes montant en hauteur), cmd7(FIN). 34 octets, #0D0B-#0D2C.
        defb #03,#2E,#17,#27,#17,#2E,#17,#27,#17,#2C,#19,#27,#19,#2C,#19,#27
        defb #19,#2A,#1B,#27,#1B,#2A,#1B,#27,#1B,#2A,#1B,#27,#1B,#2A,#1B,#27
        defb #1B,#07
tbl_sound_program_gameover_ch2:
        ; Programme sonore du canal 2 (melodie principale) du jingle game over
        ; (tbl_sound_program_ptrs_gameover #0C49): cmd2(volume max) puis
        ; C#3-C#3-D#3-D#3-F3-F3-F3-F3 (notes longues, duree3), cmd7(FIN). 10
        ; octets, #0D2D-#0D36.
        defb #02,#CB,#CB,#CD,#CD,#CF,#CF,#CF,#CF,#07
tbl_sound_program_unused_b_ch3:
        ; [hypothesis] Programme sonore du canal 3 pointe par
        ; tbl_sound_program_ptrs_unused_b (#0C4F, aucun appelant trouve): 26 notes
        ; courtes (duree0) sans commande de volume initiale (mode herite du canal
        ; precedent), motif ascendant/descendant F5-G5-G#5..., derniere note
        ; duree2. #0D37-#0D50.
        defb #27,#29,#2A,#27,#29,#2A,#2C,#29,#2A,#2C,#2E,#2A,#29,#2A,#2C,#29
        defb #27,#29,#2A,#27,#26,#27,#29,#26,#A7,#07
tbl_sound_program_unused_b_ch2:
        ; [hypothesis] Programme sonore du canal 2 pointe par
        ; tbl_sound_program_ptrs_unused_b (#0C4F, aucun appelant trouve): 9 notes
        ; duree2 (F4-C4-D#4-A#3-F4-C4-G#3-G#3-G#3, sans commande de volume
        ; initiale), cmd7(FIN). 10 octets, #0D51-#0D5A.
        defb #9B,#96,#99,#94,#9B,#96,#92,#92,#92,#07
tbl_sound_program_ch1_silent:
        ; Programme du canal 1, PARTAGE par les 5 triplets de pointeurs de ce bloc
        ; (tbl_sound_program_ptrs_gameover/_control_menu/_unused_a/_b/_c):
        ; cmd0(volume=0, silence) puis 1 note D2 duree3 (jouee a volume nul, donc
        ; inaudible), cmd6(LOOP). 3 octets, #0D5B-#0D5D --
        defb #00,#C0,#06
tbl_psg_reset_stream:
        ; Flux fn_psg_register_init_stream (#0D67) utilise par fn_sound_cmd_end
        ; (#0C1F, commande #07/FIN): reg7(mixer)=#3F (tons+bruit OFF sur les 3
        ; canaux), reg8/9/10(volumes)=0, terminateur #FF. 9 octets, #0D5E-#0D66
        ; (le #FF final est le dernier octet du sous-bloc de donnees #0C36-#0D66,
        ; immediatement suivi par fn_psg_register_init_stream #0D67 en code).
        defb #07,#3F,#08,#00,#09,#00,#0A,#00,#FF
fn_psg_register_init_stream:
        ; Flux d'initialisation de registres PSG: lit (HL)=registre,
        ; (HL+1)=période, écrit via fn_psg_write_period_low/full (0x0D8C/0x0DA7),
        ; avance HL de 2, jusqu'à l'octet terminal #FF. Même motif générique que
        ; fn_gate_array_config_stream (0x0049) mais pour le PSG. Appelé par
        ; fn_sound_program_play_blocking (0x0A97) avec HL=#0C36
        ld    d,#00
loc_0D69:
        ld    a,(hl)
        inc    hl
        cp    #FF
        ret    z
        ld    e,a
        call    fn_psg_write_period_low
        ld    e,(hl)
        inc    hl
        call    fn_psg_write_period_full
        jr    loc_0D69
fn_arm_interrupt_flag:
        ; EI + (0x006F)=1 puis RET — signal "synchro prête" consommé par
        ; fn_check_interrupt_flag (0x0D84). Appelée depuis
        ; fn_boot_init_and_new_game/fn_restart_from_menu (0x054B) ET depuis
        ; fn_main_loop (0x05B5, tout début de chaque frame) — donc réarmée
        ; systématiquement une fois par frame, pas juste au boot. Voir
        ; 0x0D80/0x0D84
        ei
        ld    a,#01
loc_0D7C:
        ld    (var_interrupt_sync_flag),a
        ret
fn_disarm_interrupt_flag:
        ; Point d'entree alternatif partageant la queue de fn_arm_interrupt_flag
        ; (memes 2 derniers octets) : DI puis XOR A (au lieu de EI/LD A,1) avant
        ; de rejoindre var_interrupt_sync_flag=A ; RET -- donc
        ; var_interrupt_sync_flag=0 avec interruptions coupees, l'inverse exact de
        ; fn_arm_interrupt_flag. Seul appelant : fn_sound_program_play_blocking.
        di
        xor    a
        jr    loc_0D7C
fn_check_interrupt_flag:
        ; DI, teste (0x006F): si zéro, RET directement (laisse les interruptions
        ; coupées); si non-nul, EI puis RET. Utilisé en fin de
        ; fn_read_keyboard_line (0x0ED3, via 0x0ED8) — encadre le scan clavier
        ; dans une section critique DI, ne réautorisant les interruptions qu'après
        ; coup ET seulement si le flag de synchro était posé. Voir 0x0D79
        di
        ld    a,(var_interrupt_sync_flag)
        and    a
        ret    z
        ei
        ret
fn_psg_write_period_low:
        ; (était hypothesis "PSG/CRTC" vague): sélectionnent le registre PSG
        ; "période canal" via port 0xF700 (select) + 0xF400 (data) + 0xF600 (latch
        ; haut), écrivent la fréquence (DE) — cœur du moteur d'effets sonores
        ; (fn_sound_engine_tick 0x08CC / tbl_sound_dispatch 0x08E8). Les mêmes
        ; ports sont réutilisés par le scan clavier (multiplexage classique CPC).
        ld    bc,PORT_PSG_SELECT
        ld    a,#82
        out    (c),a
        ld    bc,PORT_PSG_DATA
        out    (c),e
        ld    bc,PORT_PSG_LATCH
        ld    a,d
        and    #3F
        or    #C0
loc_0DA0:
        out    (c),a
        and    #3F
        out    (c),a
        ret
fn_psg_write_period_full:
        ; (était hypothesis "PSG/CRTC" vague): sélectionnent le registre PSG
        ; "période canal" via port 0xF700 (select) + 0xF400 (data) + 0xF600 (latch
        ; haut), écrivent la fréquence (DE) — cœur du moteur d'effets sonores
        ; (fn_sound_engine_tick 0x08CC / tbl_sound_dispatch 0x08E8). Les mêmes
        ; ports sont réutilisés par le scan clavier (multiplexage classique CPC).
        ld    bc,PORT_PSG_SELECT
        ld    a,#82
        out    (c),a
        ld    bc,PORT_PSG_DATA
        out    (c),e
        ld    bc,PORT_PSG_LATCH
        ld    a,d
        and    #3F
        or    #80
        jr    loc_0DA0
fn_psg_select_and_read:
        ; CALL 0x0D8C (arme la période bas + haut&0xC0 du registre 14/I-O port A
        ; via E/D), PUIS reconfigure le registre 14 en MODE LECTURE
        ; ((D&0x3F)\|0x40 écrit au port 0xF600, bit6 = sens lecture du port PSG
        ; I/O A) et lit la valeur en retour via IN A,(0xF400) — remet ensuite le
        ; registre en mode écriture (D&0x3F sans le bit6) avant de RET avec le
        ; résultat en A. Confirme le mécanisme matériel exact du scan clavier CPC:
        ; le clavier n'est PAS lu par un port dédié mais MULTIPLEXÉ sur le port
        ; I/O du PSG (sélection de ligne = écriture du n° de ligne au port PSG en
        ; mode écriture, lecture de la ligne = même registre repassé en mode
        ; lecture) — cohérent avec fn_read_keyboard_line (0x0ED3, voir 0x0EDD) qui
        ; l'utilise ainsi.
        call    fn_psg_write_period_low
        ld    bc,PORT_PSG_SELECT
        ld    a,#92
        out    (c),a
        ld    bc,PORT_PSG_LATCH
        ld    a,d
        and    #3F
        or    #40
        out    (c),a
        ld    bc,PORT_PSG_DATA
        in    a,(c)
        push    af
        ld    bc,PORT_PSG_LATCH
        ld    a,d
        and    #3F
        out    (c),a
        pop    af
        ret
fn_probe_solid_support:
        ; Reutilise les 3 primitives AABB de fn_check_collisions
        ; (#254F/#2564/#2579), boucle sur les 40 slots (filtre actif + pas soi-
        ; meme), retourne CARRY si trouve. Utilisee par fn_player_use_held_object
        ; (grid_z temporairement +0x0C) pour valider si un boost de hauteur
        ; atterrirait sur un support solide.
        push    bc
        push    de
        push    hl
        push    iy
        ld    iy,struct_entities_base
        ld    b,#28
        ld    c,#00
        ld    l,c
        ld    h,c
        set    1,(ix+off_flags)
loc_0DF4:
        call    fn_probe_entity_is_active_other
        jr    z,fn_probe_solid_support_next
        call    fn_aabb_axis_gap_x
        jr    nc,fn_probe_solid_support_next
        call    fn_aabb_axis_gap_y
        jr    nc,fn_probe_solid_support_next
        call    fn_aabb_axis_gap_z
        jr    nc,fn_probe_solid_support_next
loc_0E08:
        pop    iy
        pop    hl
        pop    de
        pop    bc
        res    1,(ix+off_flags)
        ret
fn_probe_solid_support_next:
        ; Queue de boucle de fn_probe_solid_support (#0DE1): avance IY de 28
        ; octets, DJNZ vers #0DF4 pour l'entite suivante; boucle epuisee -> AND A
        ; (carry clear) puis rejoint la queue de sortie #0E08.
        ld    de,#001C
        add    iy,de
        djnz    loc_0DF4
        and    a
        jr    loc_0E08
fn_probe_entity_is_active_other:
        ; Helper de fn_probe_solid_support (#0DE1) -- retourne Z (a ignorer) si
        ; (iy+00)==0 (slot inactif) OU si bit1 de (iy+07) est CLEAR-avant-
        ; complement (teste en fait si CE slot est celui qui vient d'avoir son
        ; bit1 pose, i.e. L'entite appelante elle-meme) -- filtre 'actif et pas
        ; moi'.
        ld    a,(iy+off_type)
        and    a
        ret    z
        ld    a,(iy+off_flags)
        cpl
        and    #02
        ret
fn_shuffle_pickup_sequence_order:
        ; Appelée une fois au lancement d'une partie (#0596, dans
        ; fn_boot_init_and_new_game), fait tourner circulairement les 14 octets de
        ; tbl_pickup_sequence_order d'un nombre pseudo-aléatoire de positions
        ; (4-7) — l'ordre du puzzle de collecte est donc mélangé chaque partie
        ld    a,(var_newgame_random_seed)
        and    #03
        or    #04
        ld    c,a
loc_0E30:
        ld    b,#0D
        ld    iy,tbl_pickup_sequence_order
        ld    e,(iy+off_type)
loc_0E39:
        ld    a,(iy+off_grid_x)
        ld    (iy+off_type),a
        inc    iy
        djnz    loc_0E39
        ld    (iy+off_type),e
        dec    c
        jr    nz,loc_0E30
        ret
fn_hostile_patrol_logic:
        ; Logique des types d'entité 0x83-0x85 (0x82 utilise une logique
        ; différente, 0x0895, probable état "au repos"). Si grid_z_or_offset <
        ; 0xA4: mouvement de patrouille (vecteur dérivé de position propre, RST
        ; 10) + variante pseudo-aléatoire du type. Teste TOUJOURS la mort du
        ; joueur via fn_player_proximity_death (0x0EA0). PAS liée aux statues de
        ; crapaud (0x16), qui sont confirmées immobiles — le vrai élément visuel
        ; correspondant à 0x83-0x85 reste à identifier en jeu.
        call    #1D84
        ld    a,(ix+off_grid_z_or_offset)
        cp    #A4
        jr    nc,fn_player_proximity_death
        ld    (ix+#0B),#03
        ld    a,(ix+off_grid_x)
        rlca
        and    #01
        ld    l,a
        ld    a,(ix+off_grid_y)
        and    #80
        or    l
        rlca
        and    #03
        ld    l,a
        ld    bc,tbl_hostile_patrol_diag_dispatch
        jp    rst_dispatch_table
tbl_hostile_patrol_diag_dispatch:
        ; Table de dispatch (word, 4 entrees) indexee par un code 2 bits (parite
        ; de grid_x combinee au signe/bit7 de grid_y) dans fn_hostile_patrol_logic
        ; (#0E4A, via rst_dispatch_table #0028) -- choisit un des 4 vecteurs de
        ; deplacement en diagonale (fn_hostile_patrol_diag0..3,
        ; #0E77/#0E91/#0E96/#0E9B).
        defw #0E77
        defw #0E91
        defw #0E96
        defw #0E9B
fn_hostile_patrol_diag0:
        ; Variante diagonale 0 de la logique de patrouille ennemie -- meme famille
        ; que fn_hostile_patrol_logic, direction fixee.
        ld    hl,#04FC
loc_0E7A:
        ld    (ix+#09),l
        ld    (ix+#0A),h
        ld    a,(var_pseudo_random_acc)
        and    #03
        jr    nz,loc_0E88
        inc    a
loc_0E88:
        add    a,#82
        ld    (ix+off_type),a
loc_0E8D:
        rst    #10
        jp    #1F7B
fn_hostile_patrol_diag1:
        ; Diagonale 1: HL=#0404 puis JR vers la queue commune de
        ; fn_hostile_patrol_diag0 (#0E7A, stockage vecteur + suite).
        ld    hl,#0404
        jr    loc_0E7A
fn_hostile_patrol_diag2:
        ; Diagonale 2: HL=#FCFC puis JR vers la queue commune de
        ; fn_hostile_patrol_diag0 (#0E7A).
        ld    hl,#FCFC
        jr    loc_0E7A
fn_hostile_patrol_diag3:
        ; Diagonale 3: HL=#FC04 puis JR vers la queue commune de
        ; fn_hostile_patrol_diag0 (#0E7A) -- boucle complete des 4 diagonales
        ; (#04FC/#0404/#FCFC/#FC04, cf. Les 4 orientations cardinales de
        ; fn_guard_patrol_vector_o0..o3 #12A9-#12F9 mais ici en diagonale).
        ld    hl,#FC04
        jr    loc_0E7A
fn_player_proximity_death:
        ; Test de proximité 2D joueur/entité (PAS le AABB 3D générique de
        ; fn_check_collisions): si |player_x-ix+01|<6 ET |player_y-ix+02|<6
        ; (utilise (0x00D8)/(0x00D9), position joueur potentiellement mise en
        ; cache), saut direct vers 0x12FB (fn_game_over_or_daycycle_end, retour
        ; COMPLET au menu). Une mort réelle observée en direct (perte de vie avec
        ; vies restantes) n'a PAS emprunté ce chemin (0x12FB jamais atteint, salle
        ; restée inchangée) — le vrai mécanisme de "mort douce" est
        ; fn_player_door_transition (voir ci-dessous). Le rôle exact de
        ; fn_player_proximity_death reste à élucider (peut-être réservé à la toute
        ; dernière vie, ou à un contact avec un type d'ennemi spécifique non
        ; encore rencontré).
        ld    a,(#00D8)
        sub    (ix+off_grid_x)
        jp    p,loc_0EAB
        neg
loc_0EAB:
        cp    #06
        jr    nc,loc_0EBF
        ld    a,(#00D9)
        sub    (ix+off_grid_y)
        jp    p,loc_0EBA
        neg
loc_0EBA:
        cp    #06
        jp    c,fn_game_over_or_daycycle_end
loc_0EBF:
        set    7,(ix+off_state_flags_2)
        set    1,(ix+off_flags)
        ld    (ix+#0B),#01
        ld    bc,#0404
        call    fn_vector_toward_player
        jr    loc_0E8D
fn_read_keyboard_line:
        ; Lit une ligne de la matrice clavier CPC (A=n° de ligne), retour dans A
        di
        call    fn_read_keyboard_row_raw
        push    af
        call    fn_check_interrupt_flag
        pop    af
        ret
fn_read_keyboard_row_raw:
        ; Petit helper appelé par fn_read_keyboard_line (0x0ED3→0x0ED4): D=A
        ; (numéro de ligne demandé), E=0x0E (registre PSG 14 = port I/O A), CALL
        ; 0x0DBD (fn_psg_select_and_read), puis CPL (complémente le résultat — la
        ; matrice clavier CPC est active-bas, donc ce complément rend les bits "1
        ; = touche pressée") et RET. Second appelant: 0x0AF9, DANS
        ; fn_sound_program_play_blocking (0x0A97) — utilisé là pour sonder une
        ; touche et permettre d'écourter le jingle de game-over, PAS un second
        ; chemin de scan clavier générique (voir 0x0A97/0x0D80)
        ld    d,a
        ld    e,#0E
        call    fn_psg_select_and_read
        cpl
        ret
fn_ball_chase_flee_logic:
        ; (salle 0x08, type 0xB6) — voir la table des constantes ci-dessous pour
        ; le détail complet (patch d'opcode JR NC/JR C selon la forme jour/nuit du
        ; joueur). Formalisée en symbole/asm: joue fn_sound_trigger_bounce
        ; (0x09A6) sur collision.
        call    #1D9E
        ld    l,(ix+#09)
        ld    h,(ix+#0A)
        push    hl
        ld    a,(ix+#0B)
        ld    (#0088),a
        rst    #10
        pop    hl
        ld    (ix+#09),l
        ld    (ix+#0A),h
        ld    a,(struct_entities_base)
        sub    #10
        cp    #20
        ld    a,#30
        jr    nc,loc_0F0A
        add    a,#08
loc_0F0A:
        ld    (#0F41),a
        ld    (#0F5A),a
        ld    a,(var_player_room_number)
        and    #01
        ld    a,#04
        jr    z,loc_0F20
        ld    b,a
        ld    a,(var_pseudo_random_acc)
        and    #03
        add    a,b
loc_0F20:
        bit    2,(ix+off_cooldown_or_collision_flags)
        jr    z,loc_0F4C
        ld    (ix+#0B),a
        ld    a,(#0088)
        and    a
        jp    p,loc_0F33
        call    fn_sound_trigger_bounce
loc_0F33:
        ld    a,r
        and    #01
        jr    z,fn_ball_chase_flee_alt_vector
        ld    a,(#00D9)
        cp    (ix+off_grid_y)
        ld    a,#02
        jr    nc,loc_0F45
        neg
loc_0F45:
        ld    (ix+#0A),a
        ld    (ix+#09),#00
loc_0F4C:
        call    fn_animation_cycle_4
        jp    #1139
fn_ball_chase_flee_alt_vector:
        ; Branche alternative de calcul de vecteur de fn_ball_chase_flee_logic
        ; (#0EE5), deja annoncee en prose dans sa description ('queue partagee
        ; avec une branche alternative de calcul de vecteur #0F52-#0F66'). Compare
        ; (#00D8) (position joueur) a (ix+01) (grid_x entite) pour choisir +2/-2
        ; en (ix+09), pose (ix+0A)=0, puis JR vers #0F4C (fn_animation_cycle_4 +
        ; JP #1139) -- rejoint la queue normale de la routine.
        ld    a,(#00D8)
        cp    (ix+off_grid_x)
        ld    a,#02
        jr    nc,loc_0F5E
        neg
loc_0F5E:
        ld    (ix+#09),a
        ld    (ix+#0A),#00
        jr    loc_0F4C
fn_sinking_cube_logic:
        ; Formalisée en symbole/asm. Flag bit3 de (ix+0D) déclenché une fois puis
        ; consommé (RES), applique le vecteur (RST 10), arme
        ; fn_sound_arm_position_pitch_ch1 (0x0A22, hauteur dérivée de grid_z) sur
        ; collision. Mécanisme exact de la descente (grid_z) toujours pas trouvé
        ; dans cette routine — piste ouverte.
        call    #1D8F
        bit    3,(ix+off_state_flags_2)
        ret    z
        res    3,(ix+off_state_flags_2)
        ld    (ix+#0B),#00
        rst    #10
        bit    2,(ix+off_cooldown_or_collision_flags)
        jr    nz,loc_0F81
        call    fn_sound_arm_position_pitch_ch1
loc_0F81:
        jp    #1F7B
fn_dormant_block_transform:
        ; Formalisée en symbole/asm. Si le flag bit3 de (ix+0D) est posé: force le
        ; type à 0xB8 et saute dans fn_player_materialize_anim (0x17D6) —
        ; réutilise la séquence d'animation par étapes du joueur
        call    #1D8F
        bit    3,(ix+off_state_flags_2)
        ret    z
        ld    (ix+off_type),#B8
        jp    #17D6
fn_moving_block_logic_type37:
        ; Formalisées en symbole/asm. Même corps partagé (paramètre HL différent:
        ; #020A pour 0x37 via 0x0F93→JR, #0109 pour 0x36 via 0x0F98 direct —
        ; corrige une transcription antérieure #0A02 pour 0x37, probablement des
        ; octets inversés). Arme fn_position_pitch_sound_arm (0x0A07) — son de
        ; déplacement à hauteur dépendant de la position, calcule un vecteur
        ; cyclique via var_frame_counter
        ld    hl,#020A
        jr    loc_0F9B
fn_moving_block_logic:
        ; Formalisées en symbole/asm. Même corps partagé (paramètre HL différent:
        ; #020A pour 0x37 via 0x0F93→JR, #0109 pour 0x36 via 0x0F98 direct —
        ; corrige une transcription antérieure #0A02 pour 0x37, probablement des
        ; octets inversés). Arme fn_position_pitch_sound_arm (0x0A07) — son de
        ; déplacement à hauteur dépendant de la position, calcule un vecteur
        ; cyclique via var_frame_counter
        ld    hl,#0109
loc_0F9B:
        ld    a,h
        ld    (#0FBF),a
        ld    a,l
        ld    (#0FD0),a
        call    #1D8F
        call    fn_position_pitch_sound_arm
        push    ix
        pop    bc
        ld    a,c
        rrca
        and    #10
        ld    c,a
        ld    a,(var_frame_counter)
        add    a,c
        bit    4,a
        jr    z,loc_0FBA
        cpl
loc_0FBA:
        and    #0F
        ld    c,a
        ld    a,(ix+off_grid_x)
        add    a,#08
        and    #0F
        cp    c
        jp    z,#1F7B
        ld    a,#01
        jr    c,loc_0FCE
        neg
loc_0FCE:
        ld    (ix+#09),a
        ld    (ix+#0B),#01
        jp    loc_0E8D
