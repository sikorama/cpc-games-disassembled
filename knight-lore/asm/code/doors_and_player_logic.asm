; ============================================================
; doors_and_player_logic.asm -- genere par tools/gen_asm.py, plage #1FE2-#26F7
; Genere mecaniquement depuis la RAM live + asm/symbols.json.
; Ne pas editer les blocs de code a la main : relancer le generateur.
; ============================================================
        org #1FE2
fn_door_post_type_B:
        ; Logique des types d'entité 0x02/0x03 (montants de porte) — quasi-
        ; identiques (variante A/B pour les deux montants d'une même porte).
        ; Recalibrent les offsets de projection selon l'orientation courante (bit
        ; 6 de ix+07), calculent un point de test décalé (±13 unités selon
        ; l'axe/orientation), puis appellent fn_door_proximity_test (0x208F) et
        ; fn_door_proximity_test_2 (0x2045).
        bit    6,(ix+off_flags)
        jr    nz,fn_door_post_type_B_flag_variant
        ld    hl,#FDF7
loc_1FEB:
        ld    (ix+off_proj_offset_x),l
        ld    (ix+off_proj_offset_y),h
        ret
fn_door_post_type_B_flag_variant:
        ; Branche de fn_door_post_type_B (#1FE2) prise quand bit6 de flags est
        ; ACTIF (jr nz,#1FF2 en #1FE6): LD HL,#FEF9 puis JR vers la queue commune
        ; d'ecriture proj_offset_x/y (#1FEB, deja disassemblee dans
        ; fn_door_post_type_B) -- meme mecanisme que la branche par defaut
        ; (HL=#FDF7) mais avec un decalage de calibration different.
        ld    hl,#FEF9
        jr    loc_1FEB
fn_door_post_type_A_type4_variant:
        ; Variante de fn_door_post_type_A specifique au type d'entite 4 (flag
        ; different pose sur l'entite).
        ld    hl,#FD01
        jr    loc_200C
fn_door_post_type_A:
        ; Logique des types d'entité 0x02/0x03 (montants de porte) — quasi-
        ; identiques (variante A/B pour les deux montants d'une même porte).
        ; Recalibrent les offsets de projection selon l'orientation courante (bit
        ; 6 de ix+07), calculent un point de test décalé (±13 unités selon
        ; l'axe/orientation), puis appellent fn_door_proximity_test (0x208F) et
        ; fn_door_proximity_test_2 (0x2045).
        bit    6,(ix+off_flags)
        jr    nz,fn_door_post_type_A_flag_variant
        ld    a,(ix+off_type)
        cp    #04
        jr    z,fn_door_post_type_A_type4_variant
        ld    hl,#FDF9
loc_200C:
        call    loc_1FEB
        ld    a,(ix+off_grid_y)
        add    a,#0D
        ld    (ix+#0A),a
        ld    a,(ix+off_grid_x)
        ld    (ix+#09),a
        ld    hl,#060F
loc_2020:
        ld    a,(ix+off_grid_z_or_offset)
        ld    (ix+#0B),a
        call    fn_door_proximity_test
        jp    fn_door_proximity_test_2
fn_door_post_type_A_flag_variant:
        ; Variante de poteau de porte (type A) qui pose un flag different selon le
        ; contexte d'appel.
        ld    hl,#FEEF
        call    loc_1FEB
        ld    a,(ix+off_grid_x)
        sub    #0D
        ld    (ix+#09),a
        ld    a,(ix+off_grid_y)
        ld    (ix+#0A),a
        ld    hl,#0F06
        jr    loc_2020
fn_door_proximity_test_2:
        ; Second test de proximité joueur (même garde IY=0x00D7), dispatch par
        ; orientation (table 0x2061, via fn_get_orientation_code) pour ajuster
        ; finement (iy+0E)/(iy+0F) du joueur — raffinement du glissement à travers
        ; l'ouverture.
        ld    hl,#0F0F
        ld    iy,struct_entities_base
        ld    a,(iy+off_type)
        and    a
        ret    z
        bit    3,(iy+off_flags)
        ret    z
        call    fn_aabb_distance_test
        ret    nc
        push    bc
        ld    bc,tbl_door_proximity_fine_adjust_dispatch
        jp    loc_22C9
tbl_door_proximity_fine_adjust_dispatch:
        ; 4 entrees word, dispatch par axe/sens vers fn_door_fine_adjust_x/y.
        defw #2069
        defw #2069
        defw #207C
        defw #207C
fn_door_fine_adjust_y:
        ; Corrige la position Y de l'entite pour l'aligner avec le passage de
        ; porte avant le franchissement.
        ld    a,(ix+#0A)
        cp    (iy+off_grid_y)
        jr    z,loc_208D
        ld    a,#01
        jr    nc,loc_2077
        neg
loc_2077:
        ld    (iy+#0F),a
        jr    loc_208D
fn_door_fine_adjust_x:
        ; Corrige la position X de l'entite pour l'aligner avec le passage de
        ; porte avant le franchissement.
        ld    a,(ix+#09)
        cp    (iy+off_grid_x)
        jr    z,loc_208D
        ld    a,#01
        jr    nc,loc_208A
        neg
loc_208A:
        ld    (iy+#0E),a
loc_208D:
        pop    bc
        ret
fn_door_proximity_test:
        ; IY fixé en dur à 0x00D7 (= le JOUEUR, pas une boucle générique). Teste
        ; si le joueur est dans la bbox de test AABB (3 axes, seuil <4, via
        ; fn_aabb_distance_test 0x20A6); si oui, POSE le bit 0 des flags DU JOUEUR
        ; (ix+07) — signal "porte franchie" consommé par fn_player_door_transition
        ; (0x2322).
        ld    iy,struct_entities_base
        ld    a,(iy+off_type)
        and    a
        ret    z
        bit    3,(iy+off_flags)
        ret    z
        call    fn_aabb_distance_test
        ret    nc
        set    0,(iy+off_flags)
        ret
fn_aabb_distance_test:
        ; Test de distance générique 3 axes entre (ix+09/0A/0B) [point de test
        ; d'une porte] et (iy+01/02/03) [position d'une entité, ici toujours le
        ; joueur] — |dx|<L, |dy|<H, |dz|<4.
        ld    a,(ix+#09)
        sub    (iy+off_grid_x)
        jr    nc,loc_20B0
        neg
loc_20B0:
        cp    l
        ret    nc
        ld    a,(ix+#0A)
        sub    (iy+off_grid_y)
        jr    nc,loc_20BC
        neg
loc_20BC:
        cp    h
        ret    nc
        ld    a,(ix+#0B)
        sub    (iy+off_grid_z_or_offset)
        jr    nc,loc_20C8
        neg
loc_20C8:
        cp    #04
        ret
fn_player_logic:
        ; Entrée JOUR/HÉROS (types 0x12/0x14, vérifié par lecture directe de
        ; tbl_entity_logic_dispatch[0x12]=tbl_entity_logic_dispatch[0x14]=#20CB):
        ; CALL #1D89 (calibration proj_offset_x/y, une des stubs de la famille
        ; "calibration seule" déjà connue via fn_door_post_type_A/B/0x1FEB —
        ; CORROBORE, sans la résoudre à elle seule, l'hypothèse déjà posée sur les
        ; types murs 0x0A-0x0F: même famille de stub générique LD HL,offset / JP
        ; #1FEB, réutilisée ici pour le joueur) puis JR #20D3 vers le corps
        ; partagé — voir fn_player_logic_night (#20D0) pour l'entrée NUIT/LOUP-
        ; GAROU qui y tombe par fall-through. Corps partagé (logique complète du
        ; joueur, une fois par frame): si bit6 de state_flags_2 posé (et
        ; var_special_input_mode_1 #0089 nul) → jump direct vers la séquence de
        ; matérialisation (#17CC, pose bit6 des flags de l'entité jambes companion
        ; via (ix+0x29) = entité[1]+0x0D); sinon CALL fn_player_transform_trigger,
        ; fn_read_input, fn_player_use_held_object, fn_player_read_input
        ; (rotation), fn_player_jump_trigger (#21F0),
        ; fn_player_walk_animation_cycle (#2214), fn_player_in_view_bounds
        ; (culling); si dans le champ: busy_flag bit1 posé autour de CALL
        ; fn_player_gravity_and_door_dispatch (#2253), puis décrémente
        ; cooldown_timer par pas de 0x10; enchaîne sur JP #1F7B (calibration
        ; partagée générique).
        call    #1D89
        jr    loc_20D3
fn_player_logic_night:
        ; Entrée NUIT/LOUP-GAROU (types 0x32/0x34,
        ; tbl_entity_logic_dispatch[0x32]=tbl_entity_logic_dispatch[0x34]=#20D0)
        ; de fn_player_logic: CALL #1DA8 (calibration différente pour la forme
        ; nocturne) puis fall-through direct dans le corps partagé #20D3 — voir
        ; #20CB pour le détail complet du corps partagé
        call    #1DA8
loc_20D3:
        bit    6,(ix+off_state_flags_2)
        jr    z,fn_player_logic_active_body
        ld    a,(var_special_input_mode_1)
        and    a
        jr    nz,fn_player_logic_active_body
        set    6,(ix+#29)
        jp    #17CC
fn_player_logic_active_body:
        ; Corps partage de fn_player_logic/fn_player_logic_night (#20CB/#20D0)
        ; quand PAS de materialisation en cours (cible des deux JR/JR NZ vers
        ; #20E6 en #20D7/#20DD): CALL fn_player_transform_trigger (#1BB0),
        ; fn_read_input (#28B7), fn_player_use_held_object (#18AA),
        ; fn_player_read_input (#2147, rotation/avance), fn_player_jump_trigger
        ; (#21F0), fn_player_walk_animation_cycle (#2214), puis
        ; fn_player_in_view_bounds (#2122). Contrairement a ce qui etait suppose,
        ; fn_player_gravity_and_door_dispatch (#2253) est TOUJOURS appelee, meme
        ; hors-champ (JR NC,#2115 ne 'saute' pas la gravite/porte, il route juste
        ; vers un traitement different du compteur de chute (ix+0B) avant de la
        ; meme facon poser busy_flag bit1 (#20FD) autour du CALL #2253): si le
        ; joueur est hors-champ ET n'est pas deja en train de tomber ((ix+0B) non
        ; negatif), le compteur de chute est force a 0 (#211C-#211F) avant de
        ; rejoindre #20FD; s'il est deja negatif (en chute), #20FD est rejoint
        ; directement SANS toucher au compteur. Dans tous les cas: busy_flag bit1
        ; pose, CALL #2253, busy_flag bit1 efface, (ix+0C) -= #10 (sans
        ; souscription si carry), puis JP #1F7B (calibration partagee generique).
        call    fn_player_transform_trigger
        call    fn_read_input
        call    fn_player_use_held_object
        call    fn_player_read_input
        call    fn_player_jump_trigger
        call    fn_player_walk_animation_cycle
        call    fn_player_in_view_bounds
        jr    nc,fn_player_logic_view_bounds_tail
loc_20FD:
        set    1,(ix+off_busy_flag)
        call    fn_player_gravity_and_door_dispatch
        res    1,(ix+off_busy_flag)
        ld    a,(ix+off_cooldown_or_collision_flags)
        sub    #10
        jr    c,loc_2112
        ld    (ix+off_cooldown_or_collision_flags),a
loc_2112:
        jp    #1F7B
fn_player_logic_view_bounds_tail:
        ; Cible de JR NC,#2115 dans fn_player_logic_active_body (#20E6, quand
        ; fn_player_in_view_bounds #2122 retourne 'hors champ'): si
        ; (ix+off_cooldown_or_collision_flags interprete comme compteur signe,
        ; ix+0B) est deja negatif (en chute), rejoint #20FD SANS y toucher; sinon
        ; le force a 0 avant de rejoindre #20FD (busy_flag bit1, CALL
        ; fn_player_gravity_and_door_dispatch #2253, etc -- voir
        ; fn_player_logic_active_body).
        ld    a,(ix+#0B)
        and    a
        jp    m,loc_20FD
        xor    a
        ld    (ix+#0B),a
        jr    loc_20FD
fn_player_in_view_bounds:
        ; Teste si (grid_x,grid_y) - bbox_w/h reste dans
        ; [var_camera_reference..+0xFF] sur les 2 axes (comparaison signée via NEG
        ; après soustraction de 0x80) — retourne CARRY clear si hors champ.
        ; Consommée par fn_player_logic pour sauter la logique de porte/gravité
        ; quand le joueur est hors-vue
        ld    hl,(var_camera_reference)
        ld    a,l
        sub    (ix+off_bbox_w)
        ld    l,a
        ld    a,h
        sub    (ix+off_bbox_h)
        ld    h,a
        ld    a,(ix+off_grid_x)
        sub    #80
        jp    p,loc_2139
        neg
loc_2139:
        cp    l
        ret    nc
        ld    a,(ix+off_grid_y)
        sub    #80
        jp    p,loc_2145
        neg
loc_2145:
        cp    h
        ret
fn_player_read_input:
        ; Lit var_input_result (#007B), resout la direction en vecteur via un
        ; cooldown base sur cooldown_timer.
        ld    hl,var_input_mode_flag
        ld    a,(hl)
        and    #02
        jr    z,fn_player_rotate_or_advance_tail
        bit    3,(hl)
        jr    z,fn_player_rotate_or_advance_tail
        ld    a,(ix+off_cooldown_or_collision_flags)
        and    #F0
        ret    nz
        bit    2,(ix+off_cooldown_or_collision_flags)
        ret    z
        bit    0,c
        jr    nz,loc_2166
        bit    2,c
        jr    nz,fn_player_orient_dispatch_bit2
loc_2166:
        bit    1,c
        jr    nz,fn_player_orient_dispatch_bit1
        bit    4,c
        jr    nz,fn_player_orient_dispatch_bit4
        bit    0,c
        jr    nz,fn_player_orient_dispatch_bit0
        res    2,c
        ret
fn_player_orient_dispatch_bit2:
        ; Sous-branche de fn_player_read_input (#2147), atteinte si bit2 de C (une
        ; des 4 directions pressees, resultat de fn_read_input) est actif. CALL
        ; fn_get_orientation_code (#22D0); CP #02; si egal -> JR Z vers
        ; fn_player_orient_aligned_exit (#2197, deja face a cette direction).
        ; Sinon CPL puis AND #01 (isole un bit de 'sens de rotation' a partir du
        ; code d'orientation complemente), puis JR vers le milieu de
        ; fn_player_rotate_or_advance_tail (#21C7) pour appliquer la rotation.
        ; Design tres dense: les branches soeurs (#2181/#2188/#2191) sautent au
        ; MILIEU de cette meme instruction JR Z (#217A) ou de l'AND #01 (#217D)
        ; pour reutiliser le flag Z/le calcul deja fait par LEUR PROPRE CP --
        ; verifie octet par octet hors-ligne + contre RAM live.
        call    fn_get_orientation_code
        cp    #02
loc_217A:
        jr    z,fn_player_orient_aligned_exit
        cpl
loc_217D:
        and    #01
        jr    loc_21C7
fn_player_orient_dispatch_bit1:
        ; Sous-branche de fn_player_read_input, atteinte si bit1 de C est actif.
        ; CALL fn_get_orientation_code; CP #01; JR vers #217A (l'instruction JR Z
        ; partagee de fn_player_orient_dispatch_bit2, #2175) qui teste le flag Z
        ; issu de CETTE comparaison -- egal -> aligne (#2197), sinon tombe dans le
        ; CPL/AND1/JR partage (#217C).
        call    fn_get_orientation_code
        cp    #01
        jr    loc_217A
fn_player_orient_dispatch_bit4:
        ; Sous-branche de fn_player_read_input, atteinte si bit4 de C est actif.
        ; CALL fn_get_orientation_code; CP #03; JR Z vers
        ; fn_player_orient_aligned_exit (#2197) si egal; sinon JR vers #217D
        ; (version SANS CPL, juste AND #01, partagee avec
        ; fn_player_orient_dispatch_bit0 #2191) puis rejoint la queue de rotation
        ; (#21C7).
        call    fn_get_orientation_code
        cp    #03
loc_218D:
        jr    z,fn_player_orient_aligned_exit
        jr    loc_217D
fn_player_orient_dispatch_bit0:
        ; Sous-branche de fn_player_read_input, atteinte si bit0 de C est actif
        ; (teste en second, apres bit2 -- meme bit que
        ; fn_player_orient_dispatch_bit2 mais chemin d'entree different, cf le
        ; chainage de BIT/JR NZ juste avant #2175 dans fn_player_read_input). CALL
        ; fn_get_orientation_code; AND A (compare implicitement a 0); JR vers
        ; #218D (l'instruction JR Z partagee de fn_player_orient_dispatch_bit4,
        ; #2188) qui reteste ce meme flag Z -- egal -> aligne (#2197), sinon tombe
        ; dans #218F puis #217D (AND1 partage).
        call    fn_get_orientation_code
        and    a
        jr    loc_218D
fn_player_orient_aligned_exit:
        ; Sortie commune aux 4 branches fn_player_orient_dispatch_bit0/1/2/4 quand
        ; la direction pressee correspond DEJA a l'orientation courante du joueur
        ; (code retourne par fn_get_orientation_code egal a la valeur attendue par
        ; la branche): SET bit2,C puis RET -- signale a l'appelant
        ; (fn_player_logic, via le retour de C) qu'il faut avancer tout droit,
        ; sans repasser par une rotation.
        set    2,c
        ret
fn_player_rotate_or_advance_tail:
        ; Point d'entree direct depuis le tout debut de fn_player_read_input
        ; (#214D/#2151, jr #219A) quand var_input_mode_flag bit1 OU bit3 est a 0:
        ; decremente le cooldown de rotation state_flags_2&7 (ix+0D) tant qu'il
        ; est non nul (RET immediat); une fois a 0, tombe dans
        ; fn_player_rotate_apply (#21A5).
        ld    a,(ix+off_state_flags_2)
        and    #07
        jr    z,fn_player_rotate_apply
        dec    (ix+off_state_flags_2)
        ret
fn_player_rotate_apply:
        ; Corps commun de la logique de rotation, avec DEUX points d'entree. (1)
        ; Fallthrough depuis fn_player_rotate_or_advance_tail (#219A, cooldown
        ; ix+0D ecoule): teste C&3 (RET si aucun des 2 bits bas actif), puis re-
        ; gate sur cooldown_or_collision_flags (ix+0C, bits4-7 et bit3, RET si
        ; occupe). (2) Entree en plein milieu (#21C7) depuis les branches
        ; fn_player_orient_dispatch_* (#2175-#2191) quand bit1 ET bit3 de
        ; var_input_mode_flag sont actifs mais que la direction pressee NE
        ; correspond PAS a l'orientation courante -- ce chemin court-circuite
        ; entierement le cooldown (ix+0D) et le re-gate (ix+0C) de l'entree (1).
        ; Partie commune aux deux entrees (#21B4 pour l'entree 1, #21C7 pour
        ; l'entree 2): teste bit2,C -- si absent, arme un son de pas/rotation
        ; (CALL fn_sound_trigger_click_and_advance #09BD); pose bit1 de
        ; state_flags_2 (OR #02); teste bit1,C pour choisir entre les deux moities
        ; miroir de la bascule d'animation (fallthrough #21C9 ou saut vers
        ; fn_player_rotate_toggle_mirror #21E8): bascule bit6 de (ix+07 flags) via
        ; XOR #40, et (uniquement si bit6 de flags etait clair au moment du test)
        ; bascule bit3 du type (ix+00) via XOR #08; recalcule enfin
        ; type_mirror_plus_10 = type+#10 (ix+1C). Dans les deux cas RET final.
        ld    a,c
        and    #03
        ret    z
        ld    a,(ix+off_cooldown_or_collision_flags)
        and    #F0
        ret    nz
        bit    3,(ix+off_cooldown_or_collision_flags)
        ret    nz
        bit    2,c
        jr    nz,loc_21BD
        push    bc
        call    fn_sound_trigger_click_and_advance
        pop    bc
loc_21BD:
        ld    a,(ix+off_state_flags_2)
        or    #02
        ld    (ix+off_state_flags_2),a
        bit    1,c
loc_21C7:
        jr    nz,fn_player_rotate_toggle_mirror
        bit    6,(ix+off_flags)
        jr    nz,loc_21D7
loc_21CF:
        ld    a,(ix+off_type)
        xor    #08
        ld    (ix+off_type),a
loc_21D7:
        ld    a,(ix+off_flags)
        xor    #40
        ld    (ix+off_flags),a
        ld    a,(ix+off_type)
        add    a,#10
        ld    (ix+off_type_mirror_plus_10),a
        ret
fn_player_rotate_toggle_mirror:
        ; Moitie miroir de la bascule d'animation de
        ; fn_player_rotate_or_advance_tail (#219A), choisie quand bit1,C est
        ; actif: reteste bit6 de flags (ix+07) puis rejoint soit #21CF (bascule
        ; bit3 du type) soit directement #21D7 (juste XOR #40 sur flags + recalcul
        ; de type_mirror_plus_10), selon le meme motif que la moitie non-miroir.
        bit    6,(ix+off_flags)
        jr    nz,loc_21CF
        jr    loc_21D7
fn_player_jump_trigger:
        ; Sur bit3 de C (bouton action/saut, résultat de fn_read_input) et si
        ; cooldown_timer/collision_flags libres: si le compteur signé (ix+0B)
        ; n'est pas déjà très négatif (pas déjà en chute), pose bit3 de
        ; cooldown_or_collision_flags (état "en l'air"), (ix+0B)=8 (compteur
        ; initial), arme un son de saut (fn_sound_arm_channel_1 via HL=#0A5A).
        ; Mécanisme de SAUT du joueur, jamais identifié avant
        bit    3,c
        ret    z
        ld    a,(ix+off_cooldown_or_collision_flags)
        and    #F0
        ret    nz
        bit    3,(ix+off_cooldown_or_collision_flags)
        ret    nz
        ld    a,(ix+#0B)
        inc    a
        ret    m
        set    3,(ix+off_cooldown_or_collision_flags)
        ld    (ix+#0B),#08
        push    bc
        ld    hl,tbl_sound_descriptor_sweep_scrambled
        call    fn_sound_arm_channel_1
        pop    bc
        ret
fn_player_walk_animation_cycle:
        ; Si le joueur avance dans sa direction courante (bit2 de C, voir
        ; fn_player_read_input) et cooldown libre: arme un son de pas
        ; (fn_sound_trigger_click_and_advance #09BD) si (ix+00) bit0 clair, puis
        ; fait avancer un cycle 5 phases (valeurs 0-5, sautant 6→0) dans les 3
        ; bits bas du type — anime la marche. RÉSOUT probablement les plages
        ; encore hypothesis 0x20-0x2F (sprite_hero_up1..12) / 0x40-0x4F
        ; (sprite_werewulf...): ce sont vraisemblablement les valeurs traversées
        ; par ce cycle (à confirmer empiriquement: dumper le type du joueur en
        ; mouvement et vérifier la séquence 5-phases)
        ld    a,(ix+off_cooldown_or_collision_flags)
        and    #F0
        jr    nz,loc_2225
        bit    3,(ix+off_cooldown_or_collision_flags)
        jr    nz,loc_2225
        bit    2,c
        jr    z,fn_player_walk_animation_no_advance
loc_2225:
        push    bc
        ld    a,(ix+off_type)
        and    #01
        jr    nz,loc_2230
        call    fn_sound_trigger_click_and_advance
loc_2230:
        pop    bc
loc_2231:
        ld    a,(ix+off_type)
        ld    e,a
        inc    a
        and    #07
        cp    #06
        jr    nz,loc_223D
        xor    a
loc_223D:
        ld    d,a
        ld    a,e
        and    #F8
        or    d
        ld    (ix+off_type),a
        ret
fn_player_walk_animation_no_advance:
        ; Branche de fn_player_walk_animation_cycle (#2214) prise quand le joueur
        ; N'avance PAS (jr z,#2246 en #2223, bit2,c clair): si (ix+off_type)&7
        ; vaut #02 ou #04, RET immediat (pas de recyclage sur ces 2 frames
        ; precises du cycle de marche); sinon JR #2231 (rejoint en plein milieu de
        ; fn_player_walk_animation_cycle: incremente/recycle quand meme le cycle
        ; 5-phases).
        ld    a,(ix+off_type)
        and    #07
        cp    #02
        ret    z
        cp    #04
        ret    z
        jr    loc_2231
fn_player_gravity_and_door_dispatch:
        ; Orchestre gravité+porte pour le joueur, appelée depuis fn_player_logic
        ; (busy_flag bit1 posé autour). Si var_special_input_mode_2 (#008A) non-
        ; nul: force (ix+0B)=2. Si conditions de cooldown/direction (bit2 de C):
        ; CALL fn_resolve_forward_vector (#22AD). Puis fait converger (ix+0B)
        ; (compteur signé saut/chute) vers 0 par pas de 1 ou 2, copie la valeur
        ; dans (0087) (nouvelle variable — cache pris avant l'appel à
        ; fn_player_door_transition, qui peut réinitialiser le contexte de
        ; l'entité via son mécanisme de checkpoint), arme un son de
        ; position/hauteur (fn_sound_arm_position_pitch_ch1 #0A22) si encore très
        ; négatif (chute), CALL fn_entity_movement_vector_resolve, CALL
        ; fn_player_door_transition (#2322) — CONFIRME PAR DÉSASSEMBLAGE DIRECT le
        ; site d'appel #228E déjà documenté en prose depuis, CALL #0016
        ; (application directe du vecteur de déplacement, même corps que
        ; rst_apply_movement_vector MAIS SANS son prélude DEC(ix+0B)/CALL #23F7
        ; déjà fait ici — confirme numériquement le "piège potentiel" déjà noté
        ; pour rst_apply_movement_vector), puis si atterri: RES bit3 de
        ; cooldown_or_collision_flags. Remet le vecteur (ix+09)/(ix+0A) à 0 une
        ; fois consommé
        ld    a,(var_special_input_mode_2)
        and    a
        jr    z,loc_225D
        ld    (ix+#0B),#02
loc_225D:
        bit    3,(ix+off_cooldown_or_collision_flags)
        jr    nz,loc_226E
        ld    a,(ix+off_cooldown_or_collision_flags)
        and    #F0
        jr    nz,loc_226E
        bit    2,c
        jr    z,loc_2273
loc_226E:
        push    bc
        call    fn_resolve_forward_vector
        pop    bc
loc_2273:
        ld    a,(ix+#0B)
        and    a
        jp    m,loc_227E
        bit    3,c
        jr    nz,loc_227F
loc_227E:
        dec    a
loc_227F:
        dec    a
        ld    (ix+#0B),a
        ld    (#0087),a
        add    a,#02
        call    m,fn_sound_arm_position_pitch_ch1
        call    fn_entity_movement_vector_resolve
        call    fn_player_door_transition
        call    #0016
        bit    2,(ix+off_cooldown_or_collision_flags)
        jr    z,loc_22A5
        ld    a,(#0087)
        and    a
        jp    p,loc_22A5
        res    3,(ix+off_cooldown_or_collision_flags)
loc_22A5:
        xor    a
        ld    (ix+#09),a
        ld    (ix+#0A),a
        ret
fn_resolve_forward_vector:
        ; (ix+09)+=(ix+0E), (ix+0A)+=(ix+0F) (applique un vecteur en attente),
        ; remet +0x0E/+0x0F a 0, puis dispatch (RST 28, table
        ; tbl_player_forward_vector_dispatch) selon fn_get_orientation_code un pas
        ; d'avance +-3 vers (ix+09)/(ix+0A). Meme motif que
        ; fn_resolve_patrol_vector mais pour le joueur, amplitude 3 au lieu de 2.
        ld    a,(ix+#09)
        add    a,(ix+#0E)
        ld    (ix+#09),a
        ld    a,(ix+#0A)
        add    a,(ix+#0F)
        ld    (ix+#0A),a
        xor    a
        ld    (ix+#0E),a
        ld    (ix+#0F),a
        ld    bc,tbl_player_forward_vector_dispatch
loc_22C9:
        call    fn_get_orientation_code
        ld    l,a
        jp    rst_dispatch_table
fn_get_orientation_code:
        ; Combine bit4 de (ix+07) + bit3 de (ix+00) -> code d'orientation 0-3
        ld    a,(ix+off_flags)
        rrca
        rrca
        and    #10
        ld    l,a
        ld    a,(ix+off_type)
        and    #08
        or    l
        rrca
        rrca
        rrca
        and    #03
        ret
tbl_player_forward_vector_dispatch:
        ; 4 entrees, vecteur fixe (+-3,0) ou (0,+-3) selon l'orientation du
        ; joueur.
        defw #22EC
        defw #22F5
        defw #22FC
        defw #2305
fn_player_forward_step_o0:
        ; Orientation 0: (ix+09) -= 3 (vecteur X). Voir
        ; tbl_player_forward_vector_dispatch (#22E4).
        ld    a,(ix+#09)
        add    a,#FD
loc_22F1:
        ld    (ix+#09),a
        ret
fn_player_forward_step_o1:
        ; Orientation 1: (ix+09) += 3 (vecteur X) -- rejoint la queue de stockage
        ; de fn_player_forward_step_o0 (#22F1). Voir
        ; tbl_player_forward_vector_dispatch (#22E4).
        ld    a,(ix+#09)
        add    a,#03
        jr    loc_22F1
fn_player_forward_step_o2:
        ; Orientation 2: (ix+0A) += 3 (vecteur Y). Voir
        ; tbl_player_forward_vector_dispatch (#22E4).
        ld    a,(ix+#0A)
        add    a,#03
loc_2301:
        ld    (ix+#0A),a
        ret
fn_player_forward_step_o3:
        ; Orientation 3: (ix+0A) -= 3 (vecteur Y) -- rejoint la queue de stockage
        ; de fn_player_forward_step_o2 (#2301). Voir
        ; tbl_player_forward_vector_dispatch (#22E4).
        ld    a,(ix+#0A)
        add    a,#FD
        jr    loc_2301
fn_entity_clamp_pending_z:
        ; Appelées par fn_entity_movement_vector_resolve (#23F7): réduisent pas à
        ; pas (fn_step_toward_zero #233B) le delta en attente sur leur axe jusqu'à
        ; ce que la position résultante reste dans une borne
        ; (var_room_data_field_2 #0074 pour Z, var_camera_reference/_y #0071/#0072
        ; pour X/Y), posant le bit de collision correspondant de
        ; cooldown_or_collision_flags à chaque pas. HYPOTHÈSE: empêche le vecteur
        ; de déplacement de sortir de la salle courante/de traverser le plafond
        ; avant même le scan de collision solide
        ld    a,(var_room_data_field_2)
        ld    d,a
loc_2310:
        ld    a,(ix+off_grid_z_or_offset)
        add    a,h
        cp    d
        ret    nc
        set    2,(ix+off_cooldown_or_collision_flags)
        ld    a,h
        call    fn_step_toward_zero
        ld    h,a
        jr    nz,loc_2310
        ret
fn_player_door_transition:
        ; MAJEURE: appelée chaque frame depuis fn_player_logic (0x228E). Si le bit
        ; 0 des flags du joueur est posé (par une porte proche, voir
        ; fn_door_proximity_test) ET le cooldown (ix+0C nibble haut) est écoulé:
        ; consomme le flag, dispatch via tbl_door_direction_dispatch (0x2344, 4
        ; pointeurs) selon l'orientation (fn_get_orientation_code) vers un des 4
        ; gestionnaires par axe/sens — fn_door_cross_x_min/fn_door_cross_x_max
        ; (0x234C/0x23A5) et fn_door_cross_y_max/fn_door_cross_y_min
        ; (0x23C0/0x23DB), DÉSASSEMBLÉS INTÉGRALEMENT (précédemment défb bruts).
        ; Les 4 gestionnaires convergent vers une queue commune (incluse dans le
        ; corps de fn_door_cross_x_min, 0x236C+) qui arme le cooldown (bits 4-5 de
        ; ix+0C) puis, SI (ix+00) [type de l'entité] est dans [0x10,0x4F]
        ; (TOUJOURS vrai pour le joueur vivant, hero ou loup-garou): déclenche le
        ; mécanisme de CHECKPOINT décrit à tbl_init_entities_template (0x29EB) ci-
        ; dessous, puis jp 0x05A5 (relance fn_init_room SEUL, sans repasser par
        ; fn_init_room_entities ni décrémenter var_life_counter). IMPORTANTE: ce
        ; chemin de reset s'exécute pour TOUT franchissement de porte normal (le
        ; garde type∈[0x10,0x4F] est quasi toujours vrai en jeu), PAS seulement
        ; pour la mort — voir l'entrée dédiée ci-dessous qui révise l'ancienne
        ; caractérisation "mort douce".
        ld    a,(ix+off_cooldown_or_collision_flags)
        and    #F0
        ret    nz
        bit    0,(ix+off_flags)
        ret    z
        res    0,(ix+off_flags)
        ld    bc,tbl_door_direction_dispatch
        ld    hl,(var_camera_reference)
        push    hl
        jp    loc_22C9
fn_step_toward_zero:
        ; Utilitaire générique: rapproche A de 0 d'un pas (A-1 si positif, A+1 si
        ; négatif, inchangé si nul), Z reflète le nouveau A. Utilisé par les
        ; clamps/scans d'axe ci-dessus
        and    a
        ret    z
        jp    p,loc_2342
        inc    a
        inc    a
loc_2342:
        dec    a
        ret
tbl_door_direction_dispatch:
        ; 4 pointeurs word (index = code d'orientation 0-3,
        ; fn_get_orientation_code), vers les 4 gestionnaires de franchissement de
        ; porte par axe/sens
        defw #234C
        defw #23A5
        defw #23C0
        defw #23DB
fn_door_cross_x_min:
        ; Franchissement de porte cote grid_x min: si (ix+01)+(ix+09)+(ix+04) <
        ; 0x80-camera_x, force (ix+01)=0x00 puis enchaine (fallthrough) dans la
        ; queue commune de reset/checkpoint (voir description generale a
        ; #2322/#29EB) qui decremente le nibble bas de (ix+08) (room_number), OR
        ; 0x30 dans (ix+0C), puis SI (ix+00) dans [0x10,0x4F] (TOUJOURS vrai pour
        ; le joueur vivant): copie 56 octets de struct_entities_base vers
        ; tbl_init_entities_template, force son octet type a 0x78 (sentinelle
        ; materialisation) pour les 2 entites, puis jp #05A5 (relance fn_init_room
        ; SANS repasser par fn_init_room_entities ni decrementer var_life_counter
        ; — ceci N'EST PAS le mecanisme de mort, voir note dediee)
        pop    hl
        ld    a,#80
        sub    l
        ld    l,a
        ld    a,(ix+off_grid_x)
        add    a,(ix+#09)
        add    a,(ix+off_bbox_w)
        cp    l
        ret    nc
        ld    (ix+off_grid_x),#00
        ld    a,(ix+off_room_number)
        ld    l,a
        dec    a
loc_2365:
        and    #0F
        ld    h,a
        ld    a,l
        and    #F0
        or    h
loc_236C:
        ld    (ix+off_room_number),a
        ld    a,(ix+off_cooldown_or_collision_flags)
        or    #30
        ld    (ix+off_cooldown_or_collision_flags),a
        ld    a,(ix+off_type)
        sub    #10
        cp    #40
        ret    nc
        inc    sp
        inc    sp
        inc    sp
        inc    sp
        push    ix
        pop    hl
        ld    de,tbl_init_entities_template
        ld    bc,fn_im1_interrupt_handler
        ldir
        ld    a,(tbl_init_entities_template)
        ld    (#29FB),a
        ld    a,(#2A07)
        ld    (#2A17),a
        ld    a,#78
        ld    (tbl_init_entities_template),a
        ld    (#2A07),a
        jp    #05A5
fn_door_cross_x_max:
        ; Franchissement de porte cote grid_x max: si (ix+01)+(ix+09)-(ix+04) >=
        ; camera_x+0x80, force (ix+01)=0xFF puis incremente le nibble bas de
        ; (ix+08), rejoint la queue commune (voir #234C)
        pop    hl
        ld    a,l
        add    a,#80
        ld    l,a
        ld    a,(ix+off_grid_x)
        add    a,(ix+#09)
        sub    (ix+off_bbox_w)
        cp    l
        ret    c
        ld    (ix+off_grid_x),#FF
        ld    a,(ix+off_room_number)
        ld    l,a
        inc    a
        jr    loc_2365
fn_door_cross_y_max:
        ; Franchissement de porte cote grid_y max: si (ix+02)+(ix+0A)-(ix+05) >=
        ; camera_y+0x80, force (ix+02)=0xFF puis (ix+08)+=0x10 (nibble haut),
        ; rejoint la queue commune (voir #234C)
        pop    hl
        ld    a,h
        add    a,#80
        ld    h,a
        ld    a,(ix+off_grid_y)
        add    a,(ix+#0A)
        sub    (ix+off_bbox_h)
        cp    h
        ret    c
        ld    (ix+off_grid_y),#FF
        ld    a,(ix+off_room_number)
        add    a,#10
        jr    loc_236C
fn_door_cross_y_min:
        ; Franchissement de porte cote grid_y min: si (ix+02)+(ix+0A)+(ix+05) <
        ; 0x80-camera_y, force (ix+02)=0x00 puis (ix+08)-=0x10 (nibble haut),
        ; rejoint la queue commune (voir #234C)
        pop    hl
        ld    a,#80
        sub    h
        ld    h,a
        ld    a,(ix+off_grid_y)
        add    a,(ix+#0A)
        add    a,(ix+off_bbox_h)
        cp    h
        ret    nc
        ld    (ix+off_grid_y),#00
        ld    a,(ix+off_room_number)
        sub    #10
        jp    loc_236C
fn_entity_movement_vector_resolve:
        ; Corps GÉNÉRIQUE (pas spécifique au joueur) de résolution du vecteur de
        ; déplacement en attente (ix+09/0A/0B) = deltas X/Y/Z, partagé par
        ; rst_apply_movement_vector (#0010) ET directement appelé par
        ; fn_player_gravity_and_door_dispatch (#2253). Pour chaque axe, DANS
        ; L'ORDRE Z puis X puis Y: si le delta courant est non-nul, clampe-le
        ; contre les bornes de la salle/caméra (fn_entity_clamp_pending_z/x/y
        ; #230C/#258F/#25BA) puis, s'il reste non-nul, scanne les 40 entités pour
        ; une collision solide bloquante sur cet axe (fn_entity_collide_axis_z/x/y
        ; #24EA/#244C/#249B) — chaque scan pouvant en plus PROPAGER le delta vers
        ; l'entité heurtée si elle est "poussable" (bit2 de ses flags), même motif
        ; que les objets/tables poussables. Utilise fn_step_toward_zero (#233B)
        ; pour réduire progressivement un delta bloqué. Une caractérisation
        ; précédente (dans fn_player_gravity_and_door_dispatch) qui la qualifiait
        ; de simple "queue de fn_player_door_transition".
        bit    1,(ix+off_flags)
        ret    nz
        set    1,(ix+off_flags)
        ld    a,(ix+off_cooldown_or_collision_flags)
        and    #F8
        ld    (ix+off_cooldown_or_collision_flags),a
        ld    l,#00
        ld    c,l
        ld    a,(ix+#0B)
        and    a
        ld    h,a
        jr    z,loc_241C
        call    fn_entity_clamp_pending_z
        ld    a,h
        and    a
        jr    z,loc_241C
        call    fn_entity_collide_axis_z
loc_241C:
        ld    a,(ix+#09)
        and    a
        ld    c,a
        jr    z,loc_242D
        call    fn_entity_clamp_pending_x
        ld    a,c
        and    a
        jr    z,loc_242D
        call    fn_entity_collide_axis_x
loc_242D:
        ld    a,(ix+#0A)
        and    a
        ld    l,a
        jr    z,loc_243E
        call    fn_entity_clamp_pending_y
        ld    a,l
        and    a
        jr    z,loc_243E
        call    fn_entity_collide_axis_y
loc_243E:
        ld    (ix+#09),c
        ld    (ix+#0A),l
        ld    (ix+#0B),h
        res    1,(ix+off_flags)
        ret
fn_entity_collide_axis_x:
        ; Scans de collision solide par axe, appelés par
        ; fn_entity_movement_vector_resolve (#23F7): bouclent sur les 40 entités
        ; (fn_probe_entity_is_active_other #0E1C), testent le chevauchement sur
        ; les 2 AUTRES axes (via fn_aabb_axis_gap_*, en utilisant les deltas déjà
        ; résolus pour les axes précédents et 0 pour ceux pas encore traités —
        ; explique pourquoi l'ordre Z→X→Y compte), puis sur leur propre axe; si
        ; blocage: pose le bit de collision, synchronise un bit de state_flags_2
        ; entre les 2 entités, propage le delta vers l'entité candidate si
        ; "poussable", et réduit le delta d'un pas (fn_step_toward_zero) en boucle
        ld    iy,struct_entities_base
        ld    b,#28
loc_2452:
        call    fn_probe_entity_is_active_other
        jr    z,fn_entity_collide_axis_x_next
        call    fn_aabb_axis_gap_y
        jr    nc,fn_entity_collide_axis_x_next
        call    fn_aabb_axis_gap_z
        jr    nc,fn_entity_collide_axis_x_next
loc_2461:
        call    fn_aabb_axis_gap_x
        jr    nc,fn_entity_collide_axis_x_next
        set    0,(ix+off_cooldown_or_collision_flags)
        ld    a,(ix+off_state_flags_2)
        rrca
        and    #40
        or    (iy+off_state_flags_2)
        ld    (iy+off_state_flags_2),a
        rlca
        and    #40
        or    (ix+off_state_flags_2)
        ld    (ix+off_state_flags_2),a
        bit    2,(iy+off_flags)
        jr    z,loc_248B
        ld    a,(ix+#09)
        ld    (iy+#09),a
loc_248B:
        ld    a,c
        call    fn_step_toward_zero
        ld    c,a
        ret    z
        jr    loc_2461
fn_entity_collide_axis_x_next:
        ; Queue de boucle de fn_entity_collide_axis_x (#244C): IY += #001C (taille
        ; d'une structure entite), DJNZ vers #2452 (entite suivante), puis RET
        ; quand les 40 slots sont epuises.
        ld    de,#001C
        add    iy,de
        djnz    loc_2452
        ret
fn_entity_collide_axis_y:
        ; Scans de collision solide par axe, appelés par
        ; fn_entity_movement_vector_resolve (#23F7): bouclent sur les 40 entités
        ; (fn_probe_entity_is_active_other #0E1C), testent le chevauchement sur
        ; les 2 AUTRES axes (via fn_aabb_axis_gap_*, en utilisant les deltas déjà
        ; résolus pour les axes précédents et 0 pour ceux pas encore traités —
        ; explique pourquoi l'ordre Z→X→Y compte), puis sur leur propre axe; si
        ; blocage: pose le bit de collision, synchronise un bit de state_flags_2
        ; entre les 2 entités, propage le delta vers l'entité candidate si
        ; "poussable", et réduit le delta d'un pas (fn_step_toward_zero) en boucle
        ld    iy,struct_entities_base
        ld    b,#28
loc_24A1:
        call    fn_probe_entity_is_active_other
        jr    z,fn_entity_collide_axis_y_next
        call    fn_aabb_axis_gap_x
        jr    nc,fn_entity_collide_axis_y_next
        call    fn_aabb_axis_gap_z
        jr    nc,fn_entity_collide_axis_y_next
loc_24B0:
        call    fn_aabb_axis_gap_y
        jr    nc,fn_entity_collide_axis_y_next
        set    1,(ix+off_cooldown_or_collision_flags)
        ld    a,(ix+off_state_flags_2)
        rrca
        and    #40
        or    (iy+off_state_flags_2)
        ld    (iy+off_state_flags_2),a
        rlca
        and    #40
        or    (ix+off_state_flags_2)
        ld    (ix+off_state_flags_2),a
        bit    2,(iy+off_flags)
        jr    z,loc_24DA
        ld    a,(ix+#0A)
        ld    (iy+#0A),a
loc_24DA:
        ld    a,l
        call    fn_step_toward_zero
        ld    l,a
        ret    z
        jr    loc_24B0
fn_entity_collide_axis_y_next:
        ; Queue de boucle de fn_entity_collide_axis_y (#249B): IY += #001C, DJNZ
        ; vers #24A1, RET.
        ld    de,#001C
        add    iy,de
        djnz    loc_24A1
        ret
fn_entity_collide_axis_z:
        ; Scans de collision solide par axe, appelés par
        ; fn_entity_movement_vector_resolve (#23F7): bouclent sur les 40 entités
        ; (fn_probe_entity_is_active_other #0E1C), testent le chevauchement sur
        ; les 2 AUTRES axes (via fn_aabb_axis_gap_*, en utilisant les deltas déjà
        ; résolus pour les axes précédents et 0 pour ceux pas encore traités —
        ; explique pourquoi l'ordre Z→X→Y compte), puis sur leur propre axe; si
        ; blocage: pose le bit de collision, synchronise un bit de state_flags_2
        ; entre les 2 entités, propage le delta vers l'entité candidate si
        ; "poussable", et réduit le delta d'un pas (fn_step_toward_zero) en boucle
        ld    iy,struct_entities_base
        ld    b,#28
loc_24F0:
        call    fn_probe_entity_is_active_other
        jr    z,fn_entity_collide_axis_z_next
        call    fn_aabb_axis_gap_x
        jr    nc,fn_entity_collide_axis_z_next
        call    fn_aabb_axis_gap_y
        jr    nc,fn_entity_collide_axis_z_next
loc_24FF:
        call    fn_aabb_axis_gap_z
        jr    nc,fn_entity_collide_axis_z_next
        set    2,(ix+off_cooldown_or_collision_flags)
        ld    a,(ix+off_state_flags_2)
        rrca
        and    #40
        or    (iy+off_state_flags_2)
        ld    (iy+off_state_flags_2),a
        rlca
        and    #40
        or    (ix+off_state_flags_2)
        ld    (ix+off_state_flags_2),a
        set    3,(iy+off_state_flags_2)
        bit    2,(ix+off_flags)
        jr    z,loc_253F
        ld    a,(ix+#09)
        and    a
        jr    nz,loc_2533
        ld    a,(iy+#09)
        ld    (ix+#09),a
loc_2533:
        ld    a,(ix+#0A)
        and    a
        jr    nz,loc_253F
        ld    a,(iy+#0A)
        ld    (ix+#0A),a
loc_253F:
        ld    a,h
        call    fn_step_toward_zero
        ld    h,a
        ret    z
        jr    loc_24FF
fn_entity_collide_axis_z_next:
        ; Queue de boucle de fn_entity_collide_axis_z (#24EA): IY += #001C, DJNZ
        ; vers #24F0, RET.
        ld    de,#001C
        add    iy,de
        djnz    loc_24F0
        ret
fn_aabb_axis_gap_x:
        ; Primitives génériques de test de chevauchement AABB, un axe chacune:
        ; retournent CARRY SET si chevauchement. X/Y sont SYMÉTRIQUES (somme des
        ; deux demi-étendues bbox_w/bbox_h). Z EST ASYMÉTRIQUE (découverte
        ; notable): selon le signe de l'écart de position, utilise SOIT la
        ; profondeur (bbox_d) de l'entité candidate (si elle est au-dessus, cible
        ; fn_aabb_axis_gap_z_other_extent #258A) SOIT la sienne propre (si en-
        ; dessous) — cohérent avec une sémantique "gravité" (atterrir sur / cogner
        ; par-dessous ne sont pas symétriques). Utilisées par
        ; fn_probe_solid_support (#0DE1), rst_apply_movement_vector (via #23F7),
        ; et les scans de collision fn_entity_collide_axis_*
        ld    a,(ix+off_bbox_w)
        add    a,(iy+off_bbox_w)
        ld    d,a
        ld    a,(ix+off_grid_x)
        add    a,c
        sub    (iy+off_grid_x)
        jp    p,loc_2562
        neg
loc_2562:
        sub    d
        ret
fn_aabb_axis_gap_y:
        ; Primitives génériques de test de chevauchement AABB, un axe chacune:
        ; retournent CARRY SET si chevauchement. X/Y sont SYMÉTRIQUES (somme des
        ; deux demi-étendues bbox_w/bbox_h). Z EST ASYMÉTRIQUE (découverte
        ; notable): selon le signe de l'écart de position, utilise SOIT la
        ; profondeur (bbox_d) de l'entité candidate (si elle est au-dessus, cible
        ; fn_aabb_axis_gap_z_other_extent #258A) SOIT la sienne propre (si en-
        ; dessous) — cohérent avec une sémantique "gravité" (atterrir sur / cogner
        ; par-dessous ne sont pas symétriques). Utilisées par
        ; fn_probe_solid_support (#0DE1), rst_apply_movement_vector (via #23F7),
        ; et les scans de collision fn_entity_collide_axis_*
        ld    a,(ix+off_bbox_h)
        add    a,(iy+off_bbox_h)
        ld    d,a
        ld    a,(ix+off_grid_y)
        add    a,l
        sub    (iy+off_grid_y)
        jp    p,loc_2577
        neg
loc_2577:
        sub    d
        ret
fn_aabb_axis_gap_z:
        ; Primitives génériques de test de chevauchement AABB, un axe chacune:
        ; retournent CARRY SET si chevauchement. X/Y sont SYMÉTRIQUES (somme des
        ; deux demi-étendues bbox_w/bbox_h). Z EST ASYMÉTRIQUE (découverte
        ; notable): selon le signe de l'écart de position, utilise SOIT la
        ; profondeur (bbox_d) de l'entité candidate (si elle est au-dessus, cible
        ; fn_aabb_axis_gap_z_other_extent #258A) SOIT la sienne propre (si en-
        ; dessous) — cohérent avec une sémantique "gravité" (atterrir sur / cogner
        ; par-dessous ne sont pas symétriques). Utilisées par
        ; fn_probe_solid_support (#0DE1), rst_apply_movement_vector (via #23F7),
        ; et les scans de collision fn_entity_collide_axis_*
        ld    a,(ix+off_grid_z_or_offset)
        add    a,h
        sub    (iy+off_grid_z_or_offset)
        jp    p,fn_aabb_axis_gap_z_other_extent
        neg
        ld    d,(ix+off_bbox_d)
loc_2588:
        sub    d
        ret
fn_aabb_axis_gap_z_other_extent:
        ; Queue de fn_aabb_axis_gap_z (#2579, cible du JP P,#258A quand l'ecart Z
        ; est positif): D=(iy+off_bbox_d) (profondeur de l'AUTRE entite, pas la
        ; sienne) puis rejoint #2588 (SUB D; RET) au milieu de fn_aabb_axis_gap_z.
        ld    d,(iy+off_bbox_d)
        jr    loc_2588
fn_entity_clamp_pending_x:
        ; Appelées par fn_entity_movement_vector_resolve (#23F7): réduisent pas à
        ; pas (fn_step_toward_zero #233B) le delta en attente sur leur axe jusqu'à
        ; ce que la position résultante reste dans une borne
        ; (var_room_data_field_2 #0074 pour Z, var_camera_reference/_y #0071/#0072
        ; pour X/Y), posant le bit de collision correspondant de
        ; cooldown_or_collision_flags à chaque pas. HYPOTHÈSE: empêche le vecteur
        ; de déplacement de sortir de la salle courante/de traverser le plafond
        ; avant même le scan de collision solide
        ld    a,(ix+off_cooldown_or_collision_flags)
        and    #F0
        ret    nz
        bit    0,(ix+off_flags)
        ret    nz
        ld    a,(var_camera_reference)
        ld    b,a
loc_259E:
        ld    a,(ix+off_grid_x)
        add    a,c
        sub    #80
        jr    nc,loc_25A8
        neg
loc_25A8:
        add    a,(ix+off_bbox_w)
        cp    b
        jr    c,loc_25B9
        set    0,(ix+off_cooldown_or_collision_flags)
        ld    a,c
        call    fn_step_toward_zero
        ld    c,a
        jr    nz,loc_259E
loc_25B9:
        ret
fn_entity_clamp_pending_y:
        ; Appelées par fn_entity_movement_vector_resolve (#23F7): réduisent pas à
        ; pas (fn_step_toward_zero #233B) le delta en attente sur leur axe jusqu'à
        ; ce que la position résultante reste dans une borne
        ; (var_room_data_field_2 #0074 pour Z, var_camera_reference/_y #0071/#0072
        ; pour X/Y), posant le bit de collision correspondant de
        ; cooldown_or_collision_flags à chaque pas. HYPOTHÈSE: empêche le vecteur
        ; de déplacement de sortir de la salle courante/de traverser le plafond
        ; avant même le scan de collision solide
        ld    a,(ix+off_cooldown_or_collision_flags)
        and    #F0
        ret    nz
        bit    0,(ix+off_flags)
        ret    nz
        ld    a,(var_camera_reference_y)
        ld    b,a
loc_25C9:
        ld    a,(ix+off_grid_y)
        add    a,l
        sub    #80
        jr    nc,loc_25D3
        neg
loc_25D3:
        add    a,(ix+off_bbox_h)
        cp    b
        jr    c,loc_25E4
        set    1,(ix+off_cooldown_or_collision_flags)
        ld    a,l
        call    fn_step_toward_zero
        ld    l,a
        jr    nz,loc_25C9
loc_25E4:
        ret
fn_entity_recompute_screen_bbox:
        ; Reprojette IX (fn_isometric_project #2EDC + fn_resolve_sprite_shape
        ; #2F02) et en dérive screen_w/screen_h (+0x14/+0x15)
        call    fn_isometric_project
        call    fn_resolve_sprite_shape
        ld    a,(ix+off_screen_x)
        and    #07
        ld    a,(de)
        inc    de
        jr    z,loc_25F5
        inc    a
loc_25F5:
        and    #0F
        ld    (ix+off_screen_w),a
        ld    a,(de)
        ld    (ix+off_screen_h),a
        ret
fn_entity_fall_and_mark_overlap:
        ; Tick générique réutilisé par plusieurs types d'entités (ex. Type 0x08
        ; "herse", JP direct depuis asm/code/objects_and_rooms_setup.asm #1F83, ET
        ; les 31 entrées de tbl_entity_logic_dispatch pointant vers
        ; fn_entity_materialize_dispatch_a/b #2689/#268E qui y rebouclent):
        ; recalcule sa propre bbox écran (fn_entity_recompute_screen_bbox #25E5)
        ; puis scanne les 40 entités et pose bit4 de leurs flags si leur empreinte
        ; ÉCRAN (pas grille) chevauche celle de IX. HYPOTHÈSE (rôle exact non
        ; confirmé par test comportemental): marquage "à retraiter"/détection de
        ; support visuel
        ld    iy,struct_entities_base
        call    fn_entity_recompute_screen_bbox
        ld    b,#28
        ld    a,(ix+off_screen_x)
        rrca
        rrca
        and    #3F
        ld    l,a
        ld    a,(ix+off_screen_x_prev)
        rrca
        rrca
        and    #3F
        ld    h,a
        cp    l
        jr    c,loc_261C
        ld    a,l
loc_261C:
        ld    e,a
        ld    a,l
        add    a,(ix+off_screen_w)
        ld    l,a
        ld    a,h
        add    a,(ix+off_screen_w_prev)
        cp    l
        jr    nc,loc_262A
        ld    a,l
loc_262A:
        sub    e
        ld    d,a
        ld    a,(ix+off_screen_y)
        cp    (ix+off_screen_y_prev)
        jr    c,loc_2637
        ld    a,(ix+off_screen_y_prev)
loc_2637:
        ld    l,a
        ld    a,(ix+off_screen_y)
        add    a,(ix+off_screen_h)
        ld    h,a
        ld    a,(ix+off_screen_y_prev)
        add    a,(ix+off_screen_h_prev)
        cp    h
        jr    nc,loc_2649
        ld    a,h
loc_2649:
        sub    l
        ld    h,a
loc_264B:
        ld    a,(iy+off_type)
        and    a
        jr    z,loc_2671
        bit    4,(iy+off_flags)
        jr    nz,loc_2671
        ld    a,(iy+off_screen_x)
        rrca
        rrca
        and    #3F
        sub    e
        jr    c,fn_entity_mark_overlap_x_tail
        cp    d
loc_2662:
        jr    nc,loc_2671
        ld    a,(iy+off_screen_y)
        sub    l
        jr    c,fn_entity_mark_overlap_y_tail
        cp    h
loc_266B:
        jr    nc,loc_2671
        set    4,(iy+off_flags)
loc_2671:
        exx
        ld    de,#001C
        add    iy,de
        exx
        djnz    loc_264B
        ret
fn_entity_mark_overlap_x_tail:
        ; Queue de fn_entity_fall_and_mark_overlap (#25FF, cible d'un JR C quand
        ; l'ecart X entre bornes est negatif): NEG puis CP (iy+off_screen_w) et
        ; rejoint #2662 au milieu de la boucle.
        neg
        cp    (iy+off_screen_w)
        jr    loc_2662
fn_entity_mark_overlap_y_tail:
        ; Symetrique de fn_entity_mark_overlap_x_tail (#267B) pour l'axe Y: NEG,
        ; CP (iy+off_screen_h), rejoint #266B.
        neg
        cp    (iy+off_screen_h)
        jr    loc_266B
fn_entity_materialize_dispatch_a:
        ; 2 points d'entrée de tbl_entity_logic_dispatch (16+15 entrées,
        ; asm/code/dispatch_and_sound.asm #06B6-#06D4/#06F6-#0714), variante
        ; calibration #1DA3/#1DAD (même motif que
        ; fn_player_logic/fn_player_logic_night). Corps partagé: si pas de
        ; matérialisation en cours, copie 7 octets (grid_x..flags) DEPUIS le slot
        ; d'entité PRÉCÉDENT (IX-0x1C) vers IX (synchronisation sur un
        ; "partenaire" de slot adjacent), puis fn_entity_materialize_pick_subtype
        ; (#26C3) choisit le sous-type final avant de reboucler sur
        ; fn_entity_fall_and_mark_overlap (#25FF). HYPOTHÈSE (mécanisme complet
        ; non vérifié en direct): semble gérer une paire d'entités adjacentes en
        ; mémoire qui se synchronise et choisit son sous-type au moment de
        ; matérialiser — piste ouverte
        call    #1DA3
        jr    loc_2691
fn_entity_materialize_dispatch_b:
        ; 2 points d'entrée de tbl_entity_logic_dispatch (16+15 entrées,
        ; asm/code/dispatch_and_sound.asm #06B6-#06D4/#06F6-#0714), variante
        ; calibration #1DA3/#1DAD (même motif que
        ; fn_player_logic/fn_player_logic_night). Corps partagé: si pas de
        ; matérialisation en cours, copie 7 octets (grid_x..flags) DEPUIS le slot
        ; d'entité PRÉCÉDENT (IX-0x1C) vers IX (synchronisation sur un
        ; "partenaire" de slot adjacent), puis fn_entity_materialize_pick_subtype
        ; (#26C3) choisit le sous-type final avant de reboucler sur
        ; fn_entity_fall_and_mark_overlap (#25FF). HYPOTHÈSE (mécanisme complet
        ; non vérifié en direct): semble gérer une paire d'entités adjacentes en
        ; mémoire qui se synchronise et choisit son sous-type au moment de
        ; matérialiser — piste ouverte
        call    #1DAD
loc_2691:
        ld    a,(var_special_input_mode_1)
        and    a
        jr    nz,loc_269E
        bit    6,(ix+off_state_flags_2)
        jp    nz,#17CC
loc_269E:
        push    ix
        pop    de
        ld    hl,#FFE4
        add    hl,de
        push    hl
        pop    iy
        inc    de
        inc    hl
        ld    bc,#0007
        ldir
        ld    (ix+off_bbox_d),#00
        set    1,(ix+off_flags)
        ld    a,(ix+off_state_flags_2)
        and    #0F
        jr    z,fn_entity_materialize_pick_subtype
        dec    (ix+off_state_flags_2)
        jr    loc_26D6
fn_entity_materialize_pick_subtype:
        ; Choix du sous-type final au moment de materialiser (voir
        ; fn_entity_materialize_dispatch_b #268E): A = var_pseudo_random_acc
        ; (#006D). Si A<2 -> fn_entity_materialize_subtype_low (#26E1, ~0.8% des
        ; tirages). Si A>=#FE -> fn_entity_materialize_subtype_high (#26EE,
        ; ~0.8%). Sinon (cas ecrasant, ~98.4%): (ix+off_type) = (iy+off_type)+#10
        ; (type du partenaire +#10, meme famille que off_type_mirror_plus_10) puis
        ; rejoint la queue commune #26D6 ((ix+off_grid_z_or_offset) =
        ; (iy+off_grid_z_or_offset)+#0C, JP fn_entity_fall_and_mark_overlap).
        ld    a,(var_pseudo_random_acc)
        cp    #02
        jr    c,fn_entity_materialize_subtype_low
        cp    #FE
        jr    nc,fn_entity_materialize_subtype_high
        ld    a,(iy+off_type)
loc_26D1:
        add    a,#10
        ld    (ix+off_type),a
loc_26D6:
        ld    a,(iy+off_grid_z_or_offset)
        add    a,#0C
        ld    (ix+off_grid_z_or_offset),a
        jp    fn_entity_fall_and_mark_overlap
fn_entity_materialize_subtype_low:
        ; Branche rare (var_pseudo_random_acc<2) de
        ; fn_entity_materialize_pick_subtype (#26C3): (ix+off_type) =
        ; ((iy+off_type)&#F8)|#06 (force les 3 bits bas du type du partenaire a
        ; #06), (ix+off_state_flags_2)=#08, puis rejoint #26D1 (ADD A,#10; LD
        ; (ix+off_type),A -- ecrase la valeur precedente avec +#10 en plus).
        ld    a,(iy+off_type)
        and    #F8
        or    #06
loc_26E8:
        ld    (ix+off_state_flags_2),#08
        jr    loc_26D1
fn_entity_materialize_subtype_high:
        ; Branche rare (var_pseudo_random_acc>=#FE) de
        ; fn_entity_materialize_pick_subtype (#26C3): identique a
        ; fn_entity_materialize_subtype_low (#26E1) mais force les 3 bits bas a
        ; #07 au lieu de #06, puis rejoint #26E8 (state_flags_2=#08) et #26D1.
        ld    a,(iy+off_type)
        and    #F8
        or    #07
        jr    loc_26E8
